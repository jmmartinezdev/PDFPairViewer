import Foundation
import Combine
import PDFKit

@MainActor
final class PDFPairViewModel: ObservableObject {
    enum LoadState: Equatable { case initial, loading, ready, empty }

    @Published private(set) var folder: URL?
    @Published private(set) var catalog = PDFCatalogResult()
    @Published private(set) var pairIndex = 0
    @Published private(set) var loadState: LoadState = .initial
    @Published private(set) var selectionError: String?
    @Published private(set) var persistenceWarning: String?
    @Published private(set) var left: DisplayPDF?
    @Published private(set) var right: DisplayPDF?
    @Published private(set) var focusRequest = UUID()
    @Published var path = ""
    #if os(iOS)
    @Published var showingFolderPicker = false
    #endif

    let accessService: FolderAccessService
    private let scanner: any PDFCatalogScanning
    private var access: FolderAccessSession?
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private var didRestore = false
    private var closed = false

    init(accessService: FolderAccessService = FolderAccessService(), scanner: any PDFCatalogScanning = PDFCatalog()) {
        self.accessService = accessService
        self.scanner = scanner
    }

    // A dismissed iPad window releases its model. Do not close on view disappearance:
    // adaptive system pickers can temporarily cover the presenting interface.
    deinit { task?.cancel() }

    var pairCount: Int { (catalog.entries.count + 1) / 2 }
    var canGoPrevious: Bool { pairCount > 0 && pairIndex > 0 }
    var canGoNext: Bool { pairCount > 0 && pairIndex + 1 < pairCount }

    func previous() {
        guard canGoPrevious else { return }
        pairIndex -= 1
        updatePair()
    }

    func next() {
        guard canGoNext else { return }
        pairIndex += 1
        updatePair()
    }

    private func updatePair() {
        guard let access else { left = nil; right = nil; return }
        let leftIndex = 2 * pairIndex
        left = catalog.entries.indices.contains(leftIndex)
            ? DisplayPDF(entry: catalog.entries[leftIndex], access: access) : nil
        let rightIndex = leftIndex + 1
        right = catalog.entries.indices.contains(rightIndex)
            ? DisplayPDF(entry: catalog.entries[rightIndex], access: access) : nil
    }

    func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        closed = false
        do {
            if let (session, warning) = try accessService.restore() {
                load(session, persistenceWarning: warning)
            }
        } catch { selectionError = error.localizedDescription }
    }

    func browse() {
        #if os(macOS)
        select { try await self.accessService.chooseFolder(seed: self.folder) }
        #else
        showingFolderPicker = true
        #endif
    }

    #if os(macOS)
    func submitPath() {
        let submitted = path
        select {
            let url = try FolderAccessService.url(from: submitted)
            do { return try self.accessService.access(url) }
            catch FolderSelectionError.notDirectory { throw FolderSelectionError.notDirectory }
            catch { return try await self.accessService.chooseFolder(seed: url, matching: url) }
        }
    }

    func dropped(_ url: URL) {
        select {
            do { return try self.accessService.access(url) }
            catch FolderSelectionError.notDirectory { throw FolderSelectionError.notDirectory }
            catch { return try await self.accessService.chooseFolder(seed: url, matching: url) }
        }
    }
    #else
    func importFolder(_ result: Result<[URL], Error>) {
        select {
            do {
                guard let url = try result.get().first else { return nil }
                return try self.accessService.access(url)
            } catch let error as CocoaError where error.code == .userCancelled {
                return nil
            }
        }
    }
    #endif

    func reportInvalidDrop() { selectionError = FolderSelectionError.invalidDrop.localizedDescription }

    private func select(_ selection: @escaping @MainActor () async throws -> FolderAccessSession?) {
        guard !accessService.isSelecting, !closed else { return }
        // Invalidate any in-flight scan immediately, including while a panel is open.
        task?.cancel()
        let id = UUID()
        requestID = id
        loadState = folder == nil ? .initial : (catalog.entries.isEmpty ? .empty : .ready)
        task = Task { [weak self] in
            do {
                guard let session = try await selection(), let self,
                      !Task.isCancelled, self.requestID == id, !self.closed else { return }
                self.load(session)
            } catch {
                guard let self, self.requestID == id, !self.closed else { return }
                self.selectionError = error.localizedDescription
            }
        }
    }

    // Internal for deterministic testing without opening a system panel.
    func load(_ session: FolderAccessSession, persistenceWarning: String? = nil) {
        guard !closed else { return }
        task?.cancel()
        let id = UUID()
        requestID = id
        loadState = .loading
        selectionError = nil
        let scanner = scanner
        task = Task { [weak self] in
            do {
                let result = try await scanner.scan(folder: session.url, access: session)
                guard let self, !Task.isCancelled, self.requestID == id, !self.closed else { return }
                let isDifferent = self.folder != session.url
                self.folder = session.url
                self.path = session.url.path
                self.catalog = result
                self.pairIndex = isDifferent ? 0 : min(self.pairIndex, max(0, (result.entries.count + 1) / 2 - 1))
                // Old display objects retain old access until PDFKit has cleared them.
                self.access = session
                self.updatePair()
                self.persistenceWarning = persistenceWarning ?? self.accessService.persist(session)
                self.loadState = result.entries.isEmpty ? .empty : .ready
                self.focusRequest = UUID()
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id, !self.closed else { return }
                self.selectionError = "Could not scan the folder: \(error.localizedDescription)"
                self.loadState = self.folder == nil ? .initial : (self.catalog.entries.isEmpty ? .empty : .ready)
            }
        }
    }

    func close() {
        closed = true
        requestID = UUID()
        task?.cancel()
        task = nil
        left = nil
        right = nil
        access = nil
        catalog = PDFCatalogResult()
        folder = nil
        loadState = .initial
        didRestore = false
    }
}
