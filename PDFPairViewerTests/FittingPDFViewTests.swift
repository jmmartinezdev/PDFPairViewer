import AppKit
import PDFKit
import XCTest
@testable import PDFPairViewer

final class FittingPDFViewTests: XCTestCase {
    @MainActor
    func testZoomCannotGoBelowFitAndMinimumUpdatesOnResize() throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("page.pdf")
        try Fixtures.pdf(url)

        let view = FittingPDFView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        view.displayMode = .singlePage
        view.displaysPageBreaks = false
        view.autoScales = true
        view.document = try XCTUnwrap(PDFDocument(url: url))
        view.layout()

        let initialFit = view.scaleFactorForSizeToFit
        XCTAssertGreaterThan(initialFit, 0)
        XCTAssertEqual(view.minScaleFactor, initialFit, accuracy: 0.001)
        view.scaleFactor = initialFit / 2
        XCTAssertEqual(view.scaleFactor, initialFit, accuracy: 0.001)
        view.zoomOut(nil)
        XCTAssertEqual(view.scaleFactor, initialFit, accuracy: 0.001)
        view.scaleFactor = initialFit * 1.5
        XCTAssertGreaterThan(view.scaleFactor, initialFit)
        view.layout()
        XCTAssertEqual(view.scaleFactor, initialFit * 1.5, accuracy: 0.001)

        view.frame.size = CGSize(width: 300, height: 400)
        view.layout()
        let smallerFit = view.scaleFactorForSizeToFit
        XCTAssertLessThan(smallerFit, initialFit)
        XCTAssertEqual(view.minScaleFactor, smallerFit, accuracy: 0.001)
        XCTAssertEqual(view.scaleFactor, smallerFit, accuracy: 0.001)

        view.frame.size = CGSize(width: 600, height: 800)
        view.layout()
        XCTAssertEqual(view.minScaleFactor, initialFit, accuracy: 0.001)
        view.scaleFactor = smallerFit
        XCTAssertEqual(view.scaleFactor, initialFit, accuracy: 0.001)
    }

    @MainActor
    func testMatchingZoomAndScrollInBothDirections() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("page.pdf")
        try Fixtures.pdf(url)
        func makeView(width: CGFloat, height: CGFloat) throws -> FittingPDFView {
            let view = FittingPDFView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            view.displayMode = .singlePage
            view.displaysPageBreaks = false
            view.autoScales = true
            view.document = try XCTUnwrap(PDFDocument(url: url))
            view.layoutSubtreeIfNeeded()
            view.layout()
            return view
        }
        let left = try makeView(width: 600, height: 800)
        let right = try makeView(width: 450, height: 600)
        let synchronization = PDFViewportSynchronization()
        left.scaleFactor = left.scaleFactorForSizeToFit * 2
        left.layoutSubtreeIfNeeded()
        let leftClip = try XCTUnwrap(left.documentView?.enclosingScrollView?.contentView)
        leftClip.scroll(to: NSPoint(x: 150, y: 200))
        synchronization.match(left, to: right)
        XCTAssertEqual(right.scaleFactor / right.scaleFactorForSizeToFit, 2, accuracy: 0.01)

        func center(_ view: FittingPDFView) throws -> NSPoint {
            let clip = try XCTUnwrap(view.documentView?.enclosingScrollView?.contentView)
            let page = try XCTUnwrap(view.document?.page(at: 0))
            return view.convert(view.convert(NSPoint(x: clip.bounds.midX, y: clip.bounds.midY),
                                             from: clip), to: page)
        }
        let leftCenter = try center(left)
        let rightCenter = try center(right)
        XCTAssertEqual(leftCenter.x, rightCenter.x, accuracy: 1)
        XCTAssertEqual(leftCenter.y, rightCenter.y, accuracy: 1)

        right.scaleFactor = right.scaleFactorForSizeToFit * 3
        right.layoutSubtreeIfNeeded()
        let rightClip = try XCTUnwrap(right.documentView?.enclosingScrollView?.contentView)
        rightClip.scroll(to: NSPoint(x: 250, y: 300))
        synchronization.match(right, to: left)
        XCTAssertEqual(left.scaleFactor / left.scaleFactorForSizeToFit, 3, accuracy: 0.01)
        XCTAssertEqual(try center(left).x, try center(right).x, accuracy: 1)
        XCTAssertEqual(try center(left).y, try center(right).y, accuracy: 1)

        synchronization.attach(left)
        synchronization.attach(right)
        defer {
            synchronization.detach(left)
            synchronization.detach(right)
        }
        left.scaleFactor = left.scaleFactorForSizeToFit * 2.5
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(right.scaleFactor / right.scaleFactorForSizeToFit, 2.5, accuracy: 0.01)
        let clip = try XCTUnwrap(right.documentView?.enclosingScrollView?.contentView)
        clip.scroll(to: NSPoint(x: 100, y: 180))
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(try center(left).x, try center(right).x, accuracy: 1)
        XCTAssertEqual(try center(left).y, try center(right).y, accuracy: 1)
    }
}
