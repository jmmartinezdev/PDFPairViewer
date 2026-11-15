import AppKit
import PDFKit
import XCTest
@testable import PDFPairViewer

enum Fixtures {
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func pdf(_ url: URL, pages: Int = 1, locked: Bool = false) throws {
        var box = CGRect(x: 0, y: 0, width: 300, height: 400)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 0.2, alpha: 1))
            context.fill(CGRect(x: 30, y: 30, width: 50, height: 50))
            context.endPDFPage()
        }
        context.closePDF()
        if locked {
            let document = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertTrue(document.write(to: url, withOptions: [
                .ownerPasswordOption: "owner-secret", .userPasswordOption: "reader-secret"
            ]))
        }
    }
}

final class PDFCatalogTests: XCTestCase {
    func testMixedFolderAndNaturalOrdering() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["10.pdf", "2.pdf", "1.PDF"] { try Fixtures.pdf(folder.appendingPathComponent(name)) }
        try Fixtures.pdf(folder.appendingPathComponent("multi.pdf"), pages: 2)
        try Fixtures.pdf(folder.appendingPathComponent("locked.pdf"), locked: true)
        try Data("not a PDF".utf8).write(to: folder.appendingPathComponent("broken.pdf"))
        try Data("ignore".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Fixtures.pdf(nested.appendingPathComponent("hidden.pdf"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("directory.pdf"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link.pdf"),
                                                 withDestinationURL: folder.appendingPathComponent("2.pdf"))
        let result = try await PDFCatalog().scan(folder: folder, access: FolderAccessSession(url: folder))
        XCTAssertEqual(result.entries.map(\.filename), ["1.PDF", "2.pdf", "10.pdf"])
        XCTAssertEqual(result.skipped, PDFSkipCounts(unreadable: 1, locked: 1, nonSinglePage: 1))
        XCTAssertNotNil(result.skipped.summary)
    }

    func testLiteralTieBreaker() {
        let names = ["a.pdf", "A.pdf", "file10.pdf", "file2.pdf", "á.pdf", "á.pdf"]
        let expected = names.sorted { lhs, rhs in
            let comparison = lhs.localizedStandardCompare(rhs)
            return comparison == .orderedSame
                ? lhs.compare(rhs, options: .literal) == .orderedAscending
                : comparison == .orderedAscending
        }
        XCTAssertEqual(names.sorted(by: PDFCatalog.filenamePrecedes), expected)
        XCTAssertLessThan(expected.firstIndex(of: "file2.pdf")!, expected.firstIndex(of: "file10.pdf")!)
        // Explicitly exercise a natural-comparison tie without depending on
        // the OS/locale's own forced ordering for case and Unicode variants.
        XCTAssertTrue(PDFCatalog.orderedBefore("A.pdf", "a.pdf", natural: .orderedSame))
        XCTAssertFalse(PDFCatalog.orderedBefore("a.pdf", "A.pdf", natural: .orderedSame))
        XCTAssertFalse(PDFCatalog.filenamePrecedes("same.pdf", "same.pdf"))
    }

    func testEmptyFolderAndEnumerationFailure() async throws {
        let folder = try Fixtures.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try await PDFCatalog().scan(folder: folder, access: FolderAccessSession(url: folder))
        XCTAssertEqual(result.entries, [])
        XCTAssertNil(result.skipped.summary)
        do {
            _ = try await PDFCatalog().scan(folder: folder.appendingPathComponent("missing"), access: FolderAccessSession(url: folder))
            XCTFail("Expected enumeration to fail")
        } catch { /* Expected. */ }
    }
}
