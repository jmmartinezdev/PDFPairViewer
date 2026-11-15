import Foundation

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
