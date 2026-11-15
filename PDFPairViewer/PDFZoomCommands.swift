import SwiftUI

struct PDFZoomActions {
    let zoomOut: () -> Void
    let resetZoom: () -> Void
    let zoomIn: () -> Void
}

private struct PDFZoomKey: FocusedValueKey {
    typealias Value = PDFZoomActions
}

extension FocusedValues {
    var pdfZoom: PDFZoomActions? {
        get { self[PDFZoomKey.self] }
        set { self[PDFZoomKey.self] = newValue }
    }
}

struct PDFZoomCommands: Commands {
    @FocusedValue(\.pdfZoom) private var zoom

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom Out") { zoom?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(zoom == nil)
            Button("Default Zoom") { zoom?.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(zoom == nil)
            Button("Zoom In") { zoom?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(zoom == nil)
            Divider()
        }
    }
}
