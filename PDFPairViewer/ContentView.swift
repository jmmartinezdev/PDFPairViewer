import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = PDFPairViewModel()
    @FocusState private var pathIsFocused: Bool
    @State private var dropTargeted = false
    @State private var showingPath = false
    @State private var showingStatus = false
    @State private var pathAction: PathAction?

    private enum PathAction { case submit, browse }

    private var hasStatus: Bool {
        model.catalog.skipped.summary != nil || model.persistenceWarning != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let error = model.selectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    .background(.red.opacity(0.08))
            }
            ZStack {
                PDFPairView(model: model, suspendsKeyboard: showingPath || showingStatus)
                if model.folder == nil || model.loadState == .empty {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 42)).foregroundStyle(.secondary)
                        Text(model.loadState == .empty ? "No eligible PDFs" : "Choose a folder to begin")
                            .font(.title2)
                        Text(model.loadState == .empty
                             ? "Only readable, unlocked, single-page PDFs in this folder are shown."
                             : "Choose a folder, enter its path, or drop one here.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Choose Folder…", action: model.browse)
                            .buttonStyle(.glass)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .viewerCanvas))
                }
                if model.loadState == .loading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Scanning folder…")
                    }
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .background(Color(nsColor: .viewerCanvas))
        .preferredColorScheme(.dark)
        .toolbar(removing: .title)
        .toolbarBackground(Color(nsColor: .viewerCanvas), for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.folder?.lastPathComponent ?? "PDF Pair Viewer")
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1).truncationMode(.middle)
                    Text(model.pairCount == 0 ? "No pairs" : "Pair \(model.pairIndex + 1) of \(model.pairCount)")
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: 400, alignment: .leading)
                .help(model.folder?.path ?? "Choose a folder to begin")
            }
            .sharedBackgroundVisibility(.hidden)
            // macOS places primary actions after navigation items unless a flexible
            // toolbar space explicitly pushes them to the trailing edge.
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                if hasStatus {
                    Button {
                        showingStatus.toggle()
                    } label: {
                        Label("Folder status", systemImage: model.persistenceWarning == nil
                              ? "info.circle" : "exclamationmark.triangle")
                    }
                    .popover(isPresented: $showingStatus) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Folder status").font(.headline)
                            if let summary = model.catalog.skipped.summary {
                                Text(summary)
                            }
                            if let warning = model.persistenceWarning {
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .textSelection(.enabled).padding(20).frame(width: 340)
                    }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: model.previous) {
                    Label("Previous pair", systemImage: "chevron.up")
                }
                .disabled(!model.canGoPrevious)
                .help("Previous pair (Up Arrow)")
                Button(action: model.next) {
                    Label("Next pair", systemImage: "chevron.down")
                }
                .disabled(!model.canGoNext)
                .help("Next pair (Down Arrow)")
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button(action: model.browse) {
                    Label("Choose folder", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Choose folder (⌘O)")
                .contextMenu {
                    Button("Open Folder by Path…") { showingPath = true }
                }
            }
        }
        .sheet(isPresented: $showingPath, onDismiss: {
            // Wait until the path sheet is gone before presenting authorization UI.
            let action = pathAction
            pathAction = nil
            switch action {
            case .submit: model.submitPath()
            case .browse: model.browse()
            case nil: break
            }
        }) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Open Folder by Path").font(.title2)
                FolderPickerView(path: $model.path, pathIsFocused: $pathIsFocused,
                                 submit: {
                                     pathAction = .submit
                                     showingPath = false
                                 }, browse: {
                                     pathAction = .browse
                                     showingPath = false
                                 })
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { showingPath = false }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(24).frame(width: 560)
            .onAppear { pathIsFocused = true }
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 3).padding(3)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            guard providers.count == 1, let provider = providers.first else {
                model.reportInvalidDrop()
                return false
            }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                let url = data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                Task { @MainActor in
                    guard let url, url.isFileURL else { model.reportInvalidDrop(); return }
                    model.dropped(url)
                }
            }
            return true
        }
        .onAppear { model.restoreIfNeeded() }
        .onChange(of: model.focusRequest) { _, _ in pathIsFocused = false }
        .focusedSceneValue(\.openFolderByPath, { showingPath = true })
    }
}

private struct OpenFolderByPathKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openFolderByPath: (() -> Void)? {
        get { self[OpenFolderByPathKey.self] }
        set { self[OpenFolderByPathKey.self] = newValue }
    }
}

struct FolderCommands: Commands {
    @FocusedValue(\.openFolderByPath) private var openFolderByPath

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder by Path…") { openFolderByPath?() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(openFolderByPath == nil)
        }
    }
}
