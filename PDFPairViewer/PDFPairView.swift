import SwiftUI

struct PDFPairView: View {
    @ObservedObject var model: PDFPairViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                pane(model.left, missing: "No PDF", keyboardRoute: true)
                Divider()
                pane(model.right, missing: "No second PDF", keyboardRoute: false)
            }
            Divider()
            HStack {
                Button(action: model.previous) { Label("Previous", systemImage: "chevron.up") }
                    .disabled(!model.canGoPrevious)
                    .help("Previous pair (Up Arrow)")
                Spacer()
                Text(model.pairCount == 0 ? "No pairs" : "Pair \(model.pairIndex + 1) of \(model.pairCount)")
                    .monospacedDigit()
                Spacer()
                Button(action: model.next) { Label("Next", systemImage: "chevron.down") }
                    .disabled(!model.canGoNext)
                    .help("Next pair (Down Arrow)")
            }
            .padding(12)
        }
    }

    private func pane(_ display: DisplayPDF?, missing: String, keyboardRoute: Bool) -> some View {
        VStack(spacing: 0) {
            Text(display?.entry.filename ?? missing)
                .font(.headline).lineLimit(1).truncationMode(.middle)
                .help(display?.entry.url.path ?? missing)
                .frame(maxWidth: .infinity).padding(10)
                .background(.bar)
            ZStack {
                PDFKitViewRepresentable(
                    display: display, routesKeys: keyboardRoute, focusRequest: model.focusRequest,
                    previous: model.previous, next: model.next,
                    isSelecting: { model.accessService.isSelecting }, close: model.close
                )
                if let error = display?.error {
                    ContentUnavailableView("Cannot display PDF", systemImage: "exclamationmark.document",
                                           description: Text(error))
                } else if display == nil {
                    Text(missing).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
