import XCTest
@testable import PDFPairViewer

private actor ControlledScanner: PDFCatalogScanning {
    private var continuations: [URL: CheckedContinuation<PDFCatalogResult, Error>] = [:]

    func scan(folder: URL, access: FolderAccessSession) async throws -> PDFCatalogResult {
        try await withCheckedThrowingContinuation { continuations[folder] = $0 }
    }

    func pending(_ url: URL) -> Bool { continuations[url] != nil }
    func finish(_ url: URL, result: Result<PDFCatalogResult, Error>) {
        continuations.removeValue(forKey: url)?.resume(with: result)
    }
}

@MainActor
final class PDFPairViewModelTests: XCTestCase {
    private func waitUntil(_ condition: @escaping @MainActor () async -> Bool) async throws {
        for _ in 0..<500 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous state")
    }

    private func model(scanner: any PDFCatalogScanning = PDFCatalog()) -> PDFPairViewModel {
        let defaults = UserDefaults(suiteName: "PDFPairViewerTests.\(UUID())")!
        return PDFPairViewModel(accessService: FolderAccessService(defaults: defaults), scanner: scanner)
    }

    func testSixPDFsNavigationAndClamping() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for n in 1...6 { try Fixtures.pdf(folder.appendingPathComponent("\(n).pdf")) }
        let model = model()
        defer { model.close() }
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .ready }
        XCTAssertEqual(model.pairCount, 3)
        XCTAssertEqual(model.left?.entry.filename, "1.pdf")
        XCTAssertEqual(model.right?.entry.filename, "2.pdf")
        model.previous()
        XCTAssertEqual(model.pairIndex, 0)
        XCTAssertFalse(model.canGoPrevious)
        model.next()
        XCTAssertEqual(model.left?.entry.filename, "3.pdf")
        model.next()
        XCTAssertEqual(model.left?.entry.filename, "5.pdf")
        XCTAssertEqual(model.right?.entry.filename, "6.pdf")
        model.next()
        XCTAssertEqual(model.pairIndex, 2)
        XCTAssertFalse(model.canGoNext)
        model.previous()
        XCTAssertEqual(model.left?.entry.filename, "3.pdf")
    }

    func testOddSingleAndEmptyCatalogs() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for n in 1...3 { try Fixtures.pdf(folder.appendingPathComponent("\(n).pdf")) }
        let model = model()
        defer { model.close() }
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .ready }
        model.next()
        XCTAssertEqual(model.left?.entry.filename, "3.pdf")
        XCTAssertNil(model.right)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("3.pdf"))
        try FileManager.default.removeItem(at: folder.appendingPathComponent("2.pdf"))
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .ready }
        XCTAssertEqual(model.pairIndex, 0)
        XCTAssertEqual(model.pairCount, 1)
        XCTAssertNotNil(model.left?.document)
        XCTAssertNil(model.right)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("1.pdf"))
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .empty }
        XCTAssertEqual(model.pairCount, 0)
        XCTAssertNil(model.left)
        XCTAssertFalse(model.canGoNext)
    }

    func testFailedScanPreservesLoadedFolder() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Fixtures.pdf(folder.appendingPathComponent("1.pdf"))
        let model = model()
        defer { model.close() }
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .ready }
        model.load(FolderAccessSession(url: folder.appendingPathComponent("missing")))
        try await waitUntil { model.selectionError != nil }
        XCTAssertEqual(model.folder, folder)
        XCTAssertEqual(model.left?.entry.filename, "1.pdf")
        XCTAssertEqual(model.loadState, .ready)
    }

    func testOlderScanCannotOverwriteNewerSelectionAndCloseDiscardsResults() async throws {
        let scanner = ControlledScanner()
        let model = model(scanner: scanner)
        let first = URL(fileURLWithPath: "/first")
        let second = URL(fileURLWithPath: "/second")
        model.load(FolderAccessSession(url: first))
        try await waitUntil { await scanner.pending(first) }
        model.load(FolderAccessSession(url: second))
        try await waitUntil { await scanner.pending(second) }
        await scanner.finish(second, result: .success(PDFCatalogResult()))
        try await waitUntil { model.folder == second }
        await scanner.finish(first, result: .success(PDFCatalogResult()))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(model.folder, second)
        model.load(FolderAccessSession(url: first))
        try await waitUntil { await scanner.pending(first) }
        model.close()
        await scanner.finish(first, result: .success(PDFCatalogResult()))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(model.folder)
        XCTAssertEqual(model.loadState, .initial)
    }

    func testFileDisappearsAfterScanKeepsNavigation() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for n in 1...4 { try Fixtures.pdf(folder.appendingPathComponent("\(n).pdf")) }
        let model = model()
        defer { model.close() }
        model.load(FolderAccessSession(url: folder))
        try await waitUntil { model.loadState == .ready }
        try FileManager.default.removeItem(at: folder.appendingPathComponent("3.pdf"))
        model.next()
        XCTAssertNotNil(model.left?.error)
        XCTAssertNil(model.left?.document)
        XCTAssertNotNil(model.right?.document)
        XCTAssertTrue(model.canGoPrevious)
    }

    func testPathValidationAndDroppedFile() throws {
        XCTAssertThrowsError(try FolderAccessService.url(from: "relative/path"))
        XCTAssertThrowsError(try FolderAccessService.url(from: "  \n"))
        XCTAssertEqual(try FolderAccessService.url(from: " /Users/example/../test \n").path, "/Users/test")
        XCTAssertTrue(try FolderAccessService.url(from: "~/Documents").path.hasPrefix("/"))
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("1.pdf")
        try Fixtures.pdf(file)
        XCTAssertThrowsError(try FolderAccessService().access(file))
    }

    func testDifferentFolderResetsPairAndBookmarkRestores() async throws {
        let first = try Fixtures.folder()
        let second = try Fixtures.folder()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        for n in 1...4 { try Fixtures.pdf(first.appendingPathComponent("\(n).pdf")) }
        try Fixtures.pdf(second.appendingPathComponent("new.pdf"))
        let suite = "PDFPairViewerTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = FolderAccessService(defaults: defaults)
        let model = PDFPairViewModel(accessService: service)
        defer { model.close() }
        model.load(try service.access(first))
        try await waitUntil { model.loadState == .ready }
        model.next()
        XCTAssertEqual(model.pairIndex, 1)
        model.load(try service.access(second))
        try await waitUntil { model.folder == second }
        XCTAssertEqual(model.pairIndex, 0)
        XCTAssertEqual(model.left?.entry.filename, "new.pdf")
        XCTAssertNil(model.persistenceWarning)
        let restored = PDFPairViewModel(accessService: FolderAccessService(defaults: defaults))
        defer { restored.close() }
        restored.restoreIfNeeded()
        try await waitUntil { restored.loadState == .ready }
        XCTAssertEqual(restored.folder?.resolvingSymlinksInPath(), second.resolvingSymlinksInPath())
        XCTAssertEqual(restored.pairIndex, 0)
        XCTAssertEqual(restored.left?.entry.filename, "new.pdf")
    }

    func testInvalidBookmarkReportsReselection() {
        let suite = "PDFPairViewerTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid bookmark".utf8), forKey: "lastAuthorizedFolderBookmark")
        let model = PDFPairViewModel(accessService: FolderAccessService(defaults: defaults))
        defer { model.close() }
        model.restoreIfNeeded()
        XCTAssertNotNil(model.selectionError)
        XCTAssertEqual(model.loadState, .initial)
        XCTAssertNil(model.folder)
    }

    #if os(iOS)
    func testFilesPickerImportCancellationAndFailurePreserveFolder() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Fixtures.pdf(folder.appendingPathComponent("1.pdf"))
        let model = model()
        defer { model.close() }
        model.browse()
        XCTAssertTrue(model.showingFolderPicker)
        model.showingFolderPicker = false
        model.importFolder(.success([folder]))
        try await waitUntil { model.loadState == .ready }
        XCTAssertEqual(model.folder, folder)
        model.importFolder(.failure(CocoaError(.userCancelled)))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(model.selectionError)
        XCTAssertEqual(model.folder, folder)
        model.importFolder(.success([folder.appendingPathComponent("1.pdf")]))
        try await waitUntil { model.selectionError != nil }
        XCTAssertEqual(model.folder, folder)
        XCTAssertNotNil(model.left?.document)
    }
    #endif
}
