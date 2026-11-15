import AppKit
import SwiftUI

extension NSColor {
    static let viewerCanvas = NSColor(name: nil) { appearance in
        viewerCanvas(for: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light)
    }

    static func viewerCanvas(for colorScheme: ColorScheme) -> NSColor {
        if colorScheme == .dark {
            return NSColor(srgbRed: 0.085, green: 0.085, blue: 0.09, alpha: 1)
        }
        return NSColor(srgbRed: 0.94, green: 0.94, blue: 0.95, alpha: 1)
    }
}
