#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct iPadContentView: View {
    @StateObject private var model = PDFPairViewModel()
    @State private var synchronization = PDFViewportSynchronization()
    @State private var showingStatus = false

    private var suspendsActions: Bool { showingStatus || model.showingFolderPicker }
    private var canZoom: Bool {
        !suspendsActions && (model.left?.document != nil || model.right?.document != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.selectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            ZStack {
                PDFPairView(model: model, synchronization: synchronization,
                            suspendsKeyboard: suspendsActions)
                if model.folder == nil || model.loadState == .empty {
                    ContentUnavailableView {
                        Label(model.loadState == .empty ? "No eligible PDFs" : "Choose a folder to begin",
                              systemImage: "doc.on.doc")
                    } description: {
                        Text("Choose a folder in Files containing readable, unlocked, single-page PDFs.")
                    } actions: {
                        Button("Choose Folder…", action: model.browse)
                            .buttonStyle(.glass).controlSize(.large)
                    }
                    .background(Color.viewerCanvas)
                }
                if model.loadState == .loading {
                    ProgressView("Scanning folder…").padding(20)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            // Keep navigation reachable even in a narrow multitasking window.
            HStack {
                Button(action: model.previous) {
                    Label("Previous pair", systemImage: "chevron.up")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!model.canGoPrevious || suspendsActions)
                .keyboardShortcut(.upArrow, modifiers: [])
                Spacer()
                Text(model.pairCount == 0 ? "No pairs" : "Pair \(model.pairIndex + 1) of \(model.pairCount)")
                    .font(.subheadline).monospacedDigit()
                Spacer()
                Button(action: model.next) {
                    Label("Next pair", systemImage: "chevron.down")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!model.canGoNext || suspendsActions)
                .keyboardShortcut(.downArrow, modifiers: [])
            }
            .labelStyle(.iconOnly).buttonStyle(.glass).padding()
        }
        .background(Color.viewerCanvas)
        .preferredColorScheme(.dark)
        .navigationTitle(model.folder?.lastPathComponent ?? "PDF Pair Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: model.browse) { Label("Choose folder", systemImage: "folder") }
                    .keyboardShortcut("o", modifiers: .command)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Zoom Out", systemImage: "minus.magnifyingglass", action: synchronization.zoomOut)
                        .keyboardShortcut("-", modifiers: .command)
                    Button("Fit to Page", systemImage: "arrow.down.right.and.arrow.up.left", action: synchronization.resetZoom)
                        .keyboardShortcut("0", modifiers: .command)
                    Button("Zoom In", systemImage: "plus.magnifyingglass", action: synchronization.zoomIn)
                        .keyboardShortcut("+", modifiers: .command)
                } label: {
                    Label("Zoom", systemImage: "magnifyingglass")
                }
                .disabled(!canZoom)
                if model.catalog.skipped.summary != nil || model.persistenceWarning != nil {
                    Button { showingStatus = true } label: {
                        Label("Folder status", systemImage: "info.circle")
                    }
                    .popover(isPresented: $showingStatus) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Folder status").font(.headline)
                            if let summary = model.catalog.skipped.summary { Text(summary) }
                            if let warning = model.persistenceWarning {
                                Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            }
                        }
                        .textSelection(.enabled).padding().frame(idealWidth: 320)
                    }
                }
            }
        }
        .fileImporter(isPresented: $model.showingFolderPicker, allowedContentTypes: [.folder],
                      allowsMultipleSelection: false, onCompletion: model.importFolder)
        .onAppear { model.restoreIfNeeded() }
    }
}
#endif
