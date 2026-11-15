#if os(iOS)
import UIKit
import PDFKit
import XCTest
@testable import PDFPairViewer

@MainActor
final class iPadPDFViewTests: XCTestCase {
    private func makeView(url: URL, width: CGFloat = 600, height: CGFloat = 800) throws -> FittingPDFView {
        let view = FittingPDFView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.displayMode = .singlePage
        view.displaysPageBreaks = false
        view.autoScales = true
        view.document = try XCTUnwrap(PDFDocument(url: url))
        view.layoutForViewport()
        return view
    }

    private func drainUpdates() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    func testFitMinimumAndResize() throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("page.pdf")
        try Fixtures.pdf(url)
        let view = try makeView(url: url)
        let initialFit = view.scaleFactorForSizeToFit
        XCTAssertGreaterThan(initialFit, 0)
        XCTAssertEqual(view.scaleFactor, initialFit, accuracy: 0.01)
        XCTAssertEqual(view.minScaleFactor, initialFit, accuracy: 0.01)
        view.scaleFactor = initialFit / 2
        XCTAssertEqual(view.scaleFactor, initialFit, accuracy: 0.01)
        view.scaleFactor = initialFit * 2
        view.layoutForViewport()
        XCTAssertEqual(view.scaleFactor, initialFit * 2, accuracy: 0.01)

        view.frame.size = CGSize(width: 300, height: 400)
        view.setNeedsLayout()
        view.layoutForViewport()
        XCTAssertLessThan(view.scaleFactorForSizeToFit, initialFit)
        XCTAssertEqual(view.scaleFactor, view.scaleFactorForSizeToFit, accuracy: 0.01)
        XCTAssertEqual(view.minScaleFactor, view.scaleFactorForSizeToFit, accuracy: 0.01)
    }

    func testZoomSynchronizationAndResetWithMissingPane() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("page.pdf")
        try Fixtures.pdf(url)
        let left = try makeView(url: url)
        let right = try makeView(url: url, width: 450, height: 600)
        let synchronization = PDFViewportSynchronization()
        synchronization.attach(left)
        synchronization.attach(right)
        defer {
            synchronization.detach(left)
            synchronization.detach(right)
        }
        func relativeZoom(_ view: FittingPDFView) -> CGFloat {
            view.scaleFactor / view.scaleFactorForSizeToFit
        }
        synchronization.zoomIn()
        XCTAssertGreaterThan(relativeZoom(left), 1)
        XCTAssertEqual(relativeZoom(left), relativeZoom(right), accuracy: 0.01)
        right.scaleFactor = right.scaleFactorForSizeToFit * 3
        await drainUpdates()
        XCTAssertEqual(relativeZoom(left), 3, accuracy: 0.01)
        synchronization.resetZoom()
        await drainUpdates()
        XCTAssertEqual(relativeZoom(left), 1, accuracy: 0.01)
        XCTAssertEqual(relativeZoom(right), 1, accuracy: 0.01)
        left.document = nil
        synchronization.zoomIn()
        XCTAssertGreaterThan(relativeZoom(right), 1)
        synchronization.resetZoom()
        XCTAssertEqual(relativeZoom(right), 1, accuracy: 0.01)
    }

    func testScrollSynchronizationInBothDirectionsAndDetach() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("page.pdf")
        try Fixtures.pdf(url)
        let left = try makeView(url: url)
        let right = try makeView(url: url, width: 450, height: 600)
        let synchronization = PDFViewportSynchronization()
        synchronization.attach(left)
        synchronization.attach(right)
        defer {
            synchronization.detach(left)
            synchronization.detach(right)
        }
        left.scaleFactor = left.scaleFactorForSizeToFit * 3
        left.layoutForViewport()
        await drainUpdates()

        func center(_ view: FittingPDFView) throws -> CGPoint {
            let page = try XCTUnwrap(view.document?.page(at: 0))
            return view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: page)
        }
        let leftScroll = try XCTUnwrap(left.viewportScrollView)
        leftScroll.setContentOffset(CGPoint(x: 200, y: 300), animated: false)
        await drainUpdates()
        XCTAssertEqual(try center(left).x, try center(right).x, accuracy: 1)
        XCTAssertEqual(try center(left).y, try center(right).y, accuracy: 1)

        let rightScroll = try XCTUnwrap(right.viewportScrollView)
        rightScroll.setContentOffset(CGPoint(x: 250, y: 350), animated: false)
        await drainUpdates()
        XCTAssertEqual(try center(left).x, try center(right).x, accuracy: 1)
        XCTAssertEqual(try center(left).y, try center(right).y, accuracy: 1)

        synchronization.detach(right)
        let oldOffset = rightScroll.contentOffset
        leftScroll.setContentOffset(CGPoint(x: 100, y: 100), animated: false)
        await drainUpdates()
        XCTAssertEqual(rightScroll.contentOffset, oldOffset)
    }

    func testDifferentPageProportionsAndDocumentReplacement() throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let portrait = folder.appendingPathComponent("portrait.pdf")
        let landscape = folder.appendingPathComponent("landscape.pdf")
        try Fixtures.pdf(portrait)
        try Fixtures.pdf(landscape, size: CGSize(width: 600, height: 300))
        let left = try makeView(url: portrait)
        let right = try makeView(url: landscape)
        let synchronization = PDFViewportSynchronization()
        left.scaleFactor = left.scaleFactorForSizeToFit * 4
        left.layoutForViewport()
        let scroll = try XCTUnwrap(left.viewportScrollView)
        // Keep the requested center inside both panes' scrollable ranges.
        scroll.setContentOffset(CGPoint(x: 500, y: 800), animated: false)
        synchronization.match(left, to: right)
        XCTAssertEqual(right.scaleFactor / right.scaleFactorForSizeToFit, 4, accuracy: 0.01)

        func relativeCenter(_ view: FittingPDFView) throws -> CGPoint {
            let page = try XCTUnwrap(view.document?.page(at: 0))
            let box = page.bounds(for: view.displayBox)
            let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: page)
            return CGPoint(x: (point.x - box.minX) / box.width, y: (point.y - box.minY) / box.height)
        }
        XCTAssertEqual(try relativeCenter(left).x, try relativeCenter(right).x, accuracy: 0.01)
        XCTAssertEqual(try relativeCenter(left).y, try relativeCenter(right).y, accuracy: 0.01)

        right.document = nil
        right.document = try XCTUnwrap(PDFDocument(url: portrait))
        right.autoScales = true
        right.setNeedsLayout()
        right.layoutForViewport()
        XCTAssertEqual(right.scaleFactor, right.scaleFactorForSizeToFit, accuracy: 0.01)
        XCTAssertEqual(right.minScaleFactor, right.scaleFactorForSizeToFit, accuracy: 0.01)
    }
}
#endif
