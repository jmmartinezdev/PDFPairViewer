import AppKit
import XCTest
@testable import PDFPairViewer

final class AppInformationCommandsTests: XCTestCase {
    @MainActor
    func testSpanishAboutCreditsPreserveLinkDestinations() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "es", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let credits = AppInformationCommands.aboutCredits(bundle: bundle)
        let text = credits.string as NSString
        XCTAssertEqual(credits.string, "Soporte · Política de privacidad")
        for (label, url) in [("Soporte", AppLinks.support), ("Política de privacidad", AppLinks.privacyPolicy)] {
            let range = text.range(of: label)
            XCTAssertNotEqual(range.location, NSNotFound)
            guard range.location != NSNotFound else { continue }
            XCTAssertEqual(credits.attribute(.link, at: range.location, effectiveRange: nil) as? URL, url)
        }
        XCTAssertEqual(String(localized: "About PDF Pair Viewer", bundle: bundle), "Acerca de PDF Pair Viewer")
        XCTAssertEqual(String(localized: "PDF Pair Viewer Support", bundle: bundle), "Soporte de PDF Pair Viewer")
    }

    @MainActor
    func testAboutCreditsContainCenteredSupportAndPrivacyLinks() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let credits = AppInformationCommands.aboutCredits(bundle: bundle)
        let text = credits.string as NSString
        XCTAssertEqual(credits.string, "Support · Privacy Policy")
        XCTAssertEqual(
            credits.attribute(.link, at: text.range(of: "Support").location, effectiveRange: nil) as? URL,
            URL(string: "https://jmmartinezdev.github.io/pdfpairviewer-site/support/")
        )
        XCTAssertEqual(
            credits.attribute(.link, at: text.range(of: "Privacy Policy").location, effectiveRange: nil) as? URL,
            URL(string: "https://jmmartinezdev.github.io/pdfpairviewer-site/privacy/")
        )
        XCTAssertNil(credits.attribute(.link, at: text.range(of: " · ").location, effectiveRange: nil))
        XCTAssertEqual(
            (credits.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment,
            .center
        )
    }
}
