import AppKit
import PDFKit

final class FittingPDFView: PDFView {
    var windowChanged: ((NSWindow?) -> Void)?
    private weak var fittedDocument: PDFDocument?
    private var fittedSize: CGSize = .zero

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowChanged?(window)
    }

    override func layout() {
        super.layout()
        guard document != nil, bounds.width > 0, bounds.height > 0 else { return }
        let fit = scaleFactorForSizeToFit
        guard fit.isFinite, fit > 0 else { return }
        let needsFit = fittedDocument !== document || fittedSize != bounds.size
        fittedDocument = document
        fittedSize = bounds.size
        // Treat the whole-page fit as 100%, not PDFKit's physical-size scale of 1.
        // Recompute on resize so smaller panes can still show the entire page.
        if minScaleFactor != fit { minScaleFactor = fit }
        if needsFit, abs(scaleFactor - fit) > 0.001 { scaleFactor = fit }
    }
}
