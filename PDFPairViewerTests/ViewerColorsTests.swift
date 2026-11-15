import AppKit
import XCTest
@testable import PDFPairViewer

final class ViewerColorsTests: XCTestCase {
    func testCanvasPalettePreservesDarkAndProvidesLightBackground() throws {
        let light = try XCTUnwrap(NSColor.viewerCanvas(for: .light).usingColorSpace(.sRGB))
        let dark = try XCTUnwrap(NSColor.viewerCanvas(for: .dark).usingColorSpace(.sRGB))
        XCTAssertEqual(light.redComponent, 0.94, accuracy: 0.001)
        XCTAssertEqual(light.greenComponent, 0.94, accuracy: 0.001)
        XCTAssertEqual(light.blueComponent, 0.95, accuracy: 0.001)
        XCTAssertEqual(dark.redComponent, 0.085, accuracy: 0.001)
        XCTAssertEqual(dark.greenComponent, 0.085, accuracy: 0.001)
        XCTAssertEqual(dark.blueComponent, 0.09, accuracy: 0.001)
        XCTAssertEqual(light.alphaComponent, 1)
        XCTAssertEqual(dark.alphaComponent, 1)
    }

    func testDynamicCanvasMatchesPDFKitPaletteInAllAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua,
                     .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let expected = try XCTUnwrap(NSColor.viewerCanvas(for: isDark ? .dark : .light)
                .usingColorSpace(.sRGB))
            var resolved: NSColor?
            appearance.performAsCurrentDrawingAppearance {
                resolved = NSColor.viewerCanvas.usingColorSpace(.sRGB)
            }
            let actual = try XCTUnwrap(resolved)
            XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.001)
            XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.001)
            XCTAssertEqual(actual.blueComponent, expected.blueComponent, accuracy: 0.001)
        }
    }
}
