import Foundation

struct PDFEntry: Identifiable, Equatable, Sendable {
    let url: URL
    var id: URL { url }
    var filename: String { url.lastPathComponent }
}
