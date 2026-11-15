import Foundation

// Immutable and safe to retain across the catalog worker boundary.
final class FolderAccessSession: @unchecked Sendable {
    let url: URL
    private let scoped: Bool

    init(url: URL) {
        // Preserve the exact URL carrying the sandbox extension for start/stop.
        self.url = url
        scoped = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if scoped { url.stopAccessingSecurityScopedResource() }
    }
}
