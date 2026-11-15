#if os(iOS)
import PDFKit
import SwiftUI

struct PDFKitViewRepresentable: UIViewRepresentable {
    var display: DisplayPDF?
    let synchronization: PDFViewportSynchronization
    let routesKeys: Bool
    let focusRequest: UUID
    let previous: () -> Void
    let next: () -> Void
    let isSelecting: () -> Bool
    let close: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(synchronization: synchronization) }

    func makeUIView(context: Context) -> FittingPDFView {
        let view = FittingPDFView()
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.displaysPageBreaks = false
        view.pageBreakMargins = .zero
        view.pageShadowsEnabled = false
        view.autoScales = true
        view.backgroundColor = .viewerCanvas
        synchronization.attach(view)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FittingPDFView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return nil }
        return CGSize(width: max(0, width), height: max(0, height))
    }

    func updateUIView(_ view: FittingPDFView, context: Context) {
        guard context.coordinator.display !== display else { return }
        // Release the old access lease only after PDFKit releases the document.
        view.document = nil
        context.coordinator.display = display
        view.document = display?.document
        view.autoScales = true
        view.setNeedsLayout()
    }

    static func dismantleUIView(_ view: FittingPDFView, coordinator: Coordinator) {
        coordinator.synchronization.detach(view)
        view.document = nil
        coordinator.display = nil
    }

    @MainActor
    final class Coordinator {
        let synchronization: PDFViewportSynchronization
        var display: DisplayPDF?

        init(synchronization: PDFViewportSynchronization) { self.synchronization = synchronization }
    }
}
#endif
