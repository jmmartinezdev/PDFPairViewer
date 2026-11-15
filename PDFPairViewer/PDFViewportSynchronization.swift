import AppKit
import PDFKit

/// Window-local, bidirectional synchronization in page-relative coordinates.
@MainActor
final class PDFViewportSynchronization {
    private weak var left: FittingPDFView?
    private weak var right: FittingPDFView?
    private var observers: [ObjectIdentifier: [NSObjectProtocol]] = [:]
    private weak var pendingSource: FittingPDFView?
    private var updateScheduled = false
    private var applying = false

    func attach(_ view: FittingPDFView) {
        guard observers[ObjectIdentifier(view)] == nil else { return }
        if left == nil { left = view } else { right = view }
        let center = NotificationCenter.default
        let scale = center.addObserver(forName: .PDFViewScaleChanged, object: view, queue: .main) {
            [weak self, weak view] _ in
            MainActor.assumeIsolated {
                if let view { self?.changed(view) }
            }
        }
        let scroll = center.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: .main) {
            [weak self, weak view] notification in
            guard let clip = notification.object as? NSClipView else { return }
            MainActor.assumeIsolated {
                guard let view, clip.isDescendant(of: view) else { return }
                self?.changed(view)
            }
        }
        observers[ObjectIdentifier(view)] = [scale, scroll]
    }

    func detach(_ view: FittingPDFView) {
        for observer in observers.removeValue(forKey: ObjectIdentifier(view)) ?? [] {
            NotificationCenter.default.removeObserver(observer)
        }
        if left === view { left = nil }
        if right === view { right = nil }
        if pendingSource === view { pendingSource = nil }
    }

    private func changed(_ view: FittingPDFView) {
        guard !applying else { return }
        pendingSource = view
        guard !updateScheduled else { return }
        updateScheduled = true
        // PDFKit updates scale and scroll geometry separately during a gesture.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            guard let source = self.pendingSource else { return }
            self.pendingSource = nil
            guard let target = source === self.left ? self.right : self.left else { return }
            self.applying = true
            self.match(source, to: target)
            self.applying = false
        }
    }

    func match(_ source: FittingPDFView, to target: FittingPDFView) {
        guard let sourcePage = source.document?.page(at: 0),
              let targetPage = target.document?.page(at: 0),
              let sourceDocumentView = source.documentView,
              let sourceClip = sourceDocumentView.enclosingScrollView?.contentView,
              let targetDocumentView = target.documentView,
              let targetScroll = targetDocumentView.enclosingScrollView else { return }
        let sourceFit = source.scaleFactorForSizeToFit
        let targetFit = target.scaleFactorForSizeToFit
        guard sourceFit.isFinite, sourceFit > 0, targetFit.isFinite, targetFit > 0 else { return }

        let sourceBox = sourcePage.bounds(for: source.displayBox)
        let targetBox = targetPage.bounds(for: target.displayBox)
        guard sourceBox.width > 0, sourceBox.height > 0,
              targetBox.width > 0, targetBox.height > 0 else { return }
        let visibleCenter = source.convert(
            NSPoint(x: sourceClip.bounds.midX, y: sourceClip.bounds.midY), from: sourceClip)
        let pageCenter = source.convert(visibleCenter, to: sourcePage)
        let relativeX = (pageCenter.x - sourceBox.minX) / sourceBox.width
        let relativeY = (pageCenter.y - sourceBox.minY) / sourceBox.height

        let scale = max(1, source.scaleFactor / sourceFit) * targetFit
        if abs(target.scaleFactor - scale) > 0.001 { target.scaleFactor = scale }
        target.layoutSubtreeIfNeeded()
        let point = NSPoint(x: targetBox.minX + relativeX * targetBox.width,
                            y: targetBox.minY + relativeY * targetBox.height)
        let viewPoint = target.convert(point, from: targetPage)
        let documentPoint = targetDocumentView.convert(viewPoint, from: target)
        let clip = targetScroll.contentView
        let origin = NSPoint(x: documentPoint.x - clip.bounds.width / 2,
                             y: documentPoint.y - clip.bounds.height / 2)
        if abs(clip.bounds.origin.x - origin.x) > 0.5 || abs(clip.bounds.origin.y - origin.y) > 0.5 {
            clip.scroll(to: origin)
            targetScroll.reflectScrolledClipView(clip)
        }
    }
}
