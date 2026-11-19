import AppKit
import SwiftUI

struct AppInformationCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About PDF Pair Viewer") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [
                    .credits: Self.aboutCredits()
                ])
            }
        }

        CommandGroup(replacing: .help) {
            Link("PDF Pair Viewer Support", destination: AppLinks.support)
            Divider()
            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        }
    }

    static func aboutCredits(bundle: Bundle = .main) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let credits = NSMutableAttributedString(string: "")
        credits.append(NSAttributedString(
            string: String(localized: "Support", bundle: bundle, comment: "Link to the support website in the About panel."),
            attributes: attributes.merging([.link: AppLinks.support]) { _, new in new }
        ))
        credits.append(NSAttributedString(string: " · ", attributes: attributes))
        credits.append(NSAttributedString(
            string: String(localized: "Privacy Policy", bundle: bundle),
            attributes: attributes.merging([.link: AppLinks.privacyPolicy]) { _, new in new }
        ))
        return credits
    }
}
