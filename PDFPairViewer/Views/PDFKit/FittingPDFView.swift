#if os(macOS)
import AppKit
import PDFKit

final class FittingPDFView: PDFView {
    var windowChanged: ((NSWindow?) -> Void)?
    private weak var fittedDocument: PDFDocument?
    private var fittedSize: CGSize = .zero

    func layoutForViewport() { layoutSubtreeIfNeeded() }

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
#else
import UIKit
import PDFKit

final class FittingPDFView: PDFView {
    var viewportChanged: (() -> Void)?
    private weak var fittedDocument: PDFDocument?
    private var fittedSize: CGSize = .zero
    private weak var observedScroll: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?

    var viewportScrollView: UIScrollView? {
        func find(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap { find(in: $0) }.first
        }
        return find(in: self)
    }

    func layoutForViewport() { layoutIfNeeded() }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let scroll = viewportScrollView, observedScroll !== scroll {
            observedScroll = scroll
            scrollObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.viewportChanged?() }
            }
        }
        guard document != nil, bounds.width > 0, bounds.height > 0 else { return }
        let fit = scaleFactorForSizeToFit
        guard fit.isFinite, fit > 0 else { return }
        let needsFit = fittedDocument !== document || fittedSize != bounds.size
        fittedDocument = document
        fittedSize = bounds.size
        // PDFKit's fixed default maximum gives differently sized panes different
        // relative zoom limits. Use a common fit-relative range on iPad instead.
        let maximum = fit * 16
        if maxScaleFactor != maximum { maxScaleFactor = maximum }
        if minScaleFactor != fit { minScaleFactor = fit }
        if needsFit, abs(scaleFactor - fit) > 0.001 { scaleFactor = fit }
    }
}
#endif
