#if os(macOS)
import AppKit
#else
import UIKit
#endif
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

    func zoomIn() {
        changeZoom { $0.zoomIn(nil) }
    }

    func zoomOut() {
        changeZoom { $0.zoomOut(nil) }
    }

    func resetZoom() {
        pendingSource = nil
        applying = true
        defer { applying = false }
        for view in [left, right].compactMap({ $0 }) where view.document != nil {
            view.layoutForViewport()
            view.scaleFactor = view.scaleFactorForSizeToFit
            view.layoutForViewport()
        }
    }

    private func changeZoom(_ action: (FittingPDFView) -> Void) {
        let views = [left, right].compactMap { $0 }.filter { $0.document != nil }
        guard let source = pendingSource.flatMap({ pending in views.first { $0 === pending } })
                ?? views.first else { return }
        pendingSource = nil
        applying = true
        defer { applying = false }
        source.layoutForViewport()
        action(source)
        source.layoutForViewport()
        for target in views where target !== source {
            match(source, to: target)
        }
    }

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
        #if os(macOS)
        let scroll = center.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: .main) {
            [weak self, weak view] notification in
            guard let clip = notification.object as? NSClipView else { return }
            MainActor.assumeIsolated {
                guard let view, clip.isDescendant(of: view) else { return }
                self?.changed(view)
            }
        }
        observers[ObjectIdentifier(view)] = [scale, scroll]
        #else
        view.viewportChanged = { [weak self, weak view] in
            if let view { self?.changed(view) }
        }
        observers[ObjectIdentifier(view)] = [scale]
        #endif
    }

    func detach(_ view: FittingPDFView) {
        #if os(iOS)
        view.viewportChanged = nil
        #endif
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
              let targetPage = target.document?.page(at: 0) else { return }
        #if os(macOS)
        guard
              let sourceDocumentView = source.documentView,
              let sourceClip = sourceDocumentView.enclosingScrollView?.contentView,
              let targetDocumentView = target.documentView,
              let targetScroll = targetDocumentView.enclosingScrollView else { return }
        #else
        guard let targetScroll = target.viewportScrollView else { return }
        #endif
        let sourceFit = source.scaleFactorForSizeToFit
        let targetFit = target.scaleFactorForSizeToFit
        guard sourceFit.isFinite, sourceFit > 0, targetFit.isFinite, targetFit > 0 else { return }

        let sourceBox = sourcePage.bounds(for: source.displayBox)
        let targetBox = targetPage.bounds(for: target.displayBox)
        guard sourceBox.width > 0, sourceBox.height > 0,
              targetBox.width > 0, targetBox.height > 0 else { return }
        #if os(macOS)
        let visibleCenter = source.convert(
            NSPoint(x: sourceClip.bounds.midX, y: sourceClip.bounds.midY), from: sourceClip)
        #else
        let visibleCenter = CGPoint(x: source.bounds.midX, y: source.bounds.midY)
        #endif
        let pageCenter = source.convert(visibleCenter, to: sourcePage)
        let relativeX = (pageCenter.x - sourceBox.minX) / sourceBox.width
        let relativeY = (pageCenter.y - sourceBox.minY) / sourceBox.height

        let scale = max(1, source.scaleFactor / sourceFit) * targetFit
        if abs(target.scaleFactor - scale) > 0.001 { target.scaleFactor = scale }
        target.layoutForViewport()
        let point = CGPoint(x: targetBox.minX + relativeX * targetBox.width,
                            y: targetBox.minY + relativeY * targetBox.height)
        let viewPoint = target.convert(point, from: targetPage)
        #if os(macOS)
        let documentPoint = targetDocumentView.convert(viewPoint, from: target)
        let clip = targetScroll.contentView
        let origin = NSPoint(x: documentPoint.x - clip.bounds.width / 2,
                             y: documentPoint.y - clip.bounds.height / 2)
        if abs(clip.bounds.origin.x - origin.x) > 0.5 || abs(clip.bounds.origin.y - origin.y) > 0.5 {
            clip.scroll(to: origin)
            targetScroll.reflectScrolledClipView(clip)
        }
        #else
        // Translate the desired page center into a scroll delta, respecting PDFKit's insets.
        let inset = targetScroll.adjustedContentInset
        let maximumX = max(-inset.left, targetScroll.contentSize.width - targetScroll.bounds.width + inset.right)
        let maximumY = max(-inset.top, targetScroll.contentSize.height - targetScroll.bounds.height + inset.bottom)
        let origin = CGPoint(
            x: min(maximumX, max(-inset.left, targetScroll.contentOffset.x + viewPoint.x - target.bounds.midX)),
            y: min(maximumY, max(-inset.top, targetScroll.contentOffset.y + viewPoint.y - target.bounds.midY)))
        if abs(targetScroll.contentOffset.x - origin.x) > 0.5 || abs(targetScroll.contentOffset.y - origin.y) > 0.5 {
            targetScroll.setContentOffset(origin, animated: false)
        }
        #endif
    }
}
