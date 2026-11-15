import Foundation
import PDFKit

struct PDFEntry: Identifiable, Equatable, Sendable {
    let url: URL
    var id: URL { url }
    var filename: String { url.lastPathComponent }
}

struct PDFSkipCounts: Equatable, Sendable {
    var unreadable = 0
    var locked = 0
    var nonSinglePage = 0

    var summary: String? {
        var parts: [String] = []
        if unreadable > 0 { parts.append("\(unreadable) unreadable") }
        if locked > 0 { parts.append("\(locked) locked") }
        if nonSinglePage > 0 { parts.append("\(nonSinglePage) not single-page") }
        return parts.isEmpty ? nil : "Skipped PDFs: " + parts.joined(separator: ", ") + "."
    }
}

struct PDFCatalogResult: Equatable, Sendable {
    var entries: [PDFEntry] = []
    var skipped = PDFSkipCounts()
}

protocol PDFCatalogScanning: Sendable {
    func scan(folder: URL, access: FolderAccessSession) async throws -> PDFCatalogResult
}

struct PDFCatalog: PDFCatalogScanning {
    static func filenamePrecedes(_ lhs: String, _ rhs: String) -> Bool {
        orderedBefore(lhs, rhs, natural: lhs.localizedStandardCompare(rhs))
    }

    // Keep the fallback testable: localizedStandardCompare can itself force an
    // order for case/Unicode variants, depending on the OS and current locale.
    static func orderedBefore(_ lhs: String, _ rhs: String, natural: ComparisonResult) -> Bool {
        if natural != .orderedSame { return natural == .orderedAscending }
        return lhs.compare(rhs, options: .literal) == .orderedAscending
    }

    func scan(folder: URL, access: FolderAccessSession) async throws -> PDFCatalogResult {
        let worker = Task.detached(priority: .userInitiated) {
            // The worker owns access even if its awaiting UI task is cancelled.
            try withExtendedLifetime(access) {
                try Self.scanSynchronously(folder: folder)
            }
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func scanSynchronously(folder: URL) throws -> PDFCatalogResult {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        let children = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: []
        )
        var result = PDFCatalogResult()
        for url in children {
            try Task.checkCancellation()
            guard url.pathExtension.lowercased() == "pdf" else { continue }
            // Do not follow links outside the selected directory.
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                result.skipped.unreadable += 1
                continue
            }
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            autoreleasepool {
                guard FileManager.default.isReadableFile(atPath: url.path),
                      let document = PDFDocument(url: url) else {
                    result.skipped.unreadable += 1
                    return
                }
                guard !document.isLocked else {
                    result.skipped.locked += 1
                    return
                }
                guard document.pageCount == 1 else {
                    result.skipped.nonSinglePage += 1
                    return
                }
                guard document.page(at: 0) != nil else {
                    result.skipped.unreadable += 1
                    return
                }
                result.entries.append(PDFEntry(url: url))
            }
        }
        result.entries.sort { filenamePrecedes($0.filename, $1.filename) }
        return result
    }
}
