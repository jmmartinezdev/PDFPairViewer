import SwiftUI

@main
struct PDFPairViewerApp: App {
    var body: some Scene {
        WindowGroup("PDF Pair Viewer", id: "viewer") {
            #if os(macOS)
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
            #else
            NavigationStack {
                iPadContentView()
            }
            #endif
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 820)
        .commands {
            FolderCommands()
            PDFZoomCommands()
            PairNavigationCommands()
        }
        #endif
    }
}
