import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = PDFPairViewModel()
    @FocusState private var pathIsFocused: Bool
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            FolderPickerView(path: $model.path, pathIsFocused: $pathIsFocused,
                             submit: model.submitPath, browse: model.browse)
                .padding()
            Divider()
            if let error = model.selectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    .background(.red.opacity(0.06))
            }
            ZStack {
                PDFPairView(model: model)
                if model.folder == nil || model.loadState == .empty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc").font(.system(size: 42)).foregroundStyle(.secondary)
                        Text(model.loadState == .empty ? "No eligible PDFs" : "Choose a folder to begin")
                            .font(.title2)
                        Text(model.loadState == .empty
                             ? "Only readable, unlocked, single-page PDFs in this folder are shown."
                             : "Paste a folder path above, use Browse, or drop one folder here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                    .allowsHitTesting(false)
                    .padding(.bottom, 48)
                }
                if model.loadState == .loading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Scanning folder…")
                    }
                    .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            if let summary = model.catalog.skipped.summary {
                Text(summary).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 6)
            }
            if let warning = model.persistenceWarning {
                Text(warning).font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 6)
            }
        }
        .overlay {
            if dropTargeted { RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 3).padding(3) }
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
    }
}
