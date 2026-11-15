import SwiftUI

struct PDFPairView: View {
    @ObservedObject var model: PDFPairViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let synchronization: PDFViewportSynchronization
    var suspendsKeyboard = false

    var body: some View {
        HStack(spacing: 0) {
            pane(model.left, missing: "No PDF", keyboardRoute: true)
            Rectangle()
                .fill((colorScheme == .dark ? Color.white : Color.black)
                    .opacity(contrast == .increased ? 0.5 : 0.12))
                .frame(width: 1)
            pane(model.right, missing: "No second PDF", keyboardRoute: false)
        }
    }

    private func pane(_ display: DisplayPDF?, missing: String, keyboardRoute: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                PDFKitViewRepresentable(
                    display: display, synchronization: synchronization,
                    routesKeys: keyboardRoute, focusRequest: model.focusRequest,
                    previous: model.previous, next: model.next,
                    isSelecting: { model.accessService.isSelecting || suspendsKeyboard }, close: model.close
                )
                if let error = display?.error {
                    ContentUnavailableView("Cannot display PDF", systemImage: "exclamationmark.document",
                                           description: Text(error))
                } else if display == nil {
                    Text(missing).foregroundStyle(.secondary)
                }
            }

            if let display {
                Text(display.entry.filename)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())
                    .help(display.entry.url.path)
                    .allowsHitTesting(false)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .viewerCanvas))
        .clipped()
        .help(display?.entry.url.path ?? missing)
    }
}
