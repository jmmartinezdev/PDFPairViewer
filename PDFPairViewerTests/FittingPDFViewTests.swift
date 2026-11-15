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
}
