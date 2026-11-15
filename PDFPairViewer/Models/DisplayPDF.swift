import PDFKit

@MainActor
final class DisplayPDF {
    let entry: PDFEntry
    private(set) var document: PDFDocument?
    let error: String?
    // A displayed document always retains its corresponding access session.
    let access: FolderAccessSession

    init(entry: PDFEntry, access: FolderAccessSession) {
        self.entry = entry
        self.access = access
        if let document = PDFDocument(url: entry.url), !document.isLocked,
           document.pageCount == 1, document.page(at: 0) != nil {
            self.document = document
            error = nil
        } else {
            document = nil
            error = "This PDF is no longer readable as an unlocked, single-page document. Choose the folder again to rescan."
        }
    }

    isolated deinit { document = nil }
}
