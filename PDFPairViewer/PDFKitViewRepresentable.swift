import AppKit
import PDFKit
import SwiftUI

struct PDFKitViewRepresentable: NSViewRepresentable {
    var display: DisplayPDF?
    let synchronization: PDFViewportSynchronization
    let routesKeys: Bool
    let focusRequest: UUID
    let previous: () -> Void
    let next: () -> Void
    let isSelecting: () -> Bool
    let close: () -> Void

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.routesKeys = routesKeys
        return coordinator
    }

    func makeNSView(context: Context) -> FittingPDFView {
        let view = FittingPDFView()
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.displaysPageBreaks = false
        view.pageBreakMargins = .init(top: 0, left: 0, bottom: 0, right: 0)
        view.pageShadowsEnabled = false
        view.autoScales = true
        view.backgroundColor = .viewerCanvas
        view.windowChanged = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.view = view
        context.coordinator.synchronization = synchronization
        synchronization.attach(view)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FittingPDFView,
                      context: Context) -> CGSize? {
        // PDFKit's intrinsic document size must not enlarge its SwiftUI pane.
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return nil }
        return CGSize(width: max(0, width), height: max(0, height))
    }

    func updateNSView(_ view: FittingPDFView, context: Context) {
        let coordinator = context.coordinator
        coordinator.routesKeys = routesKeys
        coordinator.previous = previous
        coordinator.next = next
        coordinator.isSelecting = isSelecting
        coordinator.close = close
        // Display snapshots change only on pair navigation or an explicit scan,
        // never on ordinary SwiftUI updates. A rescan must also refresh a file
        // that was replaced or became readable again at the same URL.
        if coordinator.display !== display {
            // Clear PDFKit's reference before releasing the corresponding access lease.
            view.document = nil
            coordinator.display = nil
            coordinator.display = display
            view.document = display?.document
            view.autoScales = true
            view.needsLayout = true
        }
        coordinator.attach(to: view.window)
        if coordinator.lastFocusRequest != focusRequest {
            coordinator.lastFocusRequest = focusRequest
            if routesKeys, display != nil {
                DispatchQueue.main.async { [weak view, weak coordinator] in
                    guard let view, coordinator?.isSelecting?() != true,
                          view.window?.attachedSheet == nil else { return }
                    view.window?.makeFirstResponder(view)
                }
            }
        }
    }

    static func dismantleNSView(_ view: FittingPDFView, coordinator: Coordinator) {
        view.document = nil
        coordinator.display = nil
        view.windowChanged = nil
        coordinator.synchronization?.detach(view)
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        weak var view: FittingPDFView?
        var synchronization: PDFViewportSynchronization?
        weak var window: NSWindow?
        var display: DisplayPDF?
        var lastFocusRequest: UUID?
        var routesKeys = false
        var previous: (() -> Void)?
        var next: (() -> Void)?
        var isSelecting: (() -> Bool)?
        var close: (() -> Void)?
        private var monitor: Any?
        private var closeObserver: NSObjectProtocol?

        func attach(to window: NSWindow?) {
            guard self.window !== window else { return }
            detach()
            self.window = window
            guard let window else { return }
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.view?.document = nil
                    self.display = nil
                    if self.routesKeys { self.close?() }
                    self.detach()
                }
            }
            guard routesKeys else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self, let window = self.window, event.window === window,
                          window.isKeyWindow, window.attachedSheet == nil, NSApp.modalWindow == nil,
                          self.isSelecting?() != true,
                          event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                          event.keyCode == 125 || event.keyCode == 126 else { return false }
                    // PDFKit's internal views can own focus. Text editing must retain arrow behavior.
                    if window.firstResponder is NSTextView || window.firstResponder is NSTextField {
                        return false
                    }
                    // SwiftUI toolbar controls may use hosting views rather than NSButton.
                    // Route within this window, but never while a sheet/popover is editing.
                    guard window.firstResponder is NSView else { return false }
                    if !event.isARepeat {
                        if event.keyCode == 125 { self.next?() } else { self.previous?() }
                    }
                    return true
                }
                return consumed ? nil : event
            }
        }

        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
            monitor = nil
            closeObserver = nil
            window = nil
        }
    }
}

extension NSColor {
    static let viewerCanvas = NSColor(srgbRed: 0.085, green: 0.085, blue: 0.09, alpha: 1)
}

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
