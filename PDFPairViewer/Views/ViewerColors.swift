import SwiftUI

#if os(macOS)
import AppKit
extension NSColor {
    static let viewerCanvas = NSColor(srgbRed: 0.085, green: 0.085, blue: 0.09, alpha: 1)
}
#else
import UIKit
extension UIColor {
    static let viewerCanvas = UIColor(red: 0.085, green: 0.085, blue: 0.09, alpha: 1)
}
#endif

extension Color {
    static let viewerCanvas = Color(red: 0.085, green: 0.085, blue: 0.09)
}
