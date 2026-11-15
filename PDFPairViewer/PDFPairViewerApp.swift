import SwiftUI

@main
struct PDFPairViewerApp: App {
    var body: some Scene {
        Window("PDF Pair Viewer", id: "viewer") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 820)
        .commands { FolderCommands() }
    }
}
