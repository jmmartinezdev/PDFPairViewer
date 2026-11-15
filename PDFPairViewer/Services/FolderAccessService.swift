import AppKit
import Foundation

@MainActor
final class FolderAccessService {
    private let defaults: UserDefaults
    private let bookmarkKey = "lastAuthorizedFolderBookmark"
    private(set) var isSelecting = false

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    static func url(from path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { throw FolderSelectionError.absolutePathRequired }
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    }

    func access(_ url: URL) throws -> FolderAccessSession {
        guard url.isFileURL else { throw FolderSelectionError.notDirectory }
        let session = FolderAccessSession(url: url)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw FolderSelectionError.notDirectory }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FolderSelectionError.inaccessible
        }
        return session
    }

    func chooseFolder(seed: URL? = nil, matching requested: URL? = nil) async throws -> FolderAccessSession? {
        guard !isSelecting else { return nil }
        isSelecting = true
        defer { isSelecting = false }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = String(localized: "Open Folder")
        panel.message = requested == nil
            ? String(localized: "Choose a folder containing single-page PDFs.")
            : String(localized: "Grant read access to the folder you requested.")
        panel.directoryURL = seed
        let response = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        guard response == .OK, let url = panel.url else { return nil }
        if let requested,
           url.resolvingSymlinksInPath().standardizedFileURL != requested.resolvingSymlinksInPath().standardizedFileURL {
            throw FolderSelectionError.wrongFolder
        }
        return try access(url)
    }

    func persist(_ session: FolderAccessSession) -> String? {
        do {
            let data = try session.url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil, relativeTo: nil
            )
            defaults.set(data, forKey: bookmarkKey)
            return nil
        } catch {
            return String(localized: "The folder is open, but its access could not be saved for next launch: \(error.localizedDescription)")
        }
    }

    func restore() throws -> (FolderAccessSession, String?)? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            let session = try access(url)
            return (session, stale ? persist(session) : nil)
        } catch {
            throw FolderSelectionError.restoreFailed
        }
    }
}
