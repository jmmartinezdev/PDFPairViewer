import Foundation

struct PDFSkipCounts: Equatable, Sendable {
    var unreadable = 0
    var locked = 0
    var nonSinglePage = 0

    var summary: String? {
        var parts: [String] = []
        if unreadable > 0 {
            parts.append(String(localized: "\(unreadable) unreadable"))
        }
        if locked > 0 {
            parts.append(String(localized: "\(locked) locked"))
        }
        if nonSinglePage > 0 {
            parts.append(String(localized: "\(nonSinglePage) not single-page"))
        }
        guard !parts.isEmpty else { return nil }
        let list = parts.joined(separator: String(localized: ", "))
        return String(localized: "Skipped PDFs: \(list).")
    }
}

struct PDFCatalogResult: Equatable, Sendable {
    var entries: [PDFEntry] = []
    var skipped = PDFSkipCounts()
}
