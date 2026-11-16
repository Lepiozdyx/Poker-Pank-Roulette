import SwiftUI

struct LegalSettingsSection: View {
    @State private var document: LegalDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Legal")
            Button(tr("Terms and Conditions")) { document = .terms }
                .buttonStyle(NeonButtonStyle(primary: false))
            Button(tr("Privacy Policy")) { document = .privacy }
                .buttonStyle(NeonButtonStyle(primary: false))
        }
        .sheet(item: $document) { LegalDocumentView(document: $0).gameSheet() }
    }
}

struct WebLegalSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "Settings")
                LegalSettingsSection()
            }
            .padding(24)
        }
        .background(Neon.background)
    }
}

private enum LegalDocument: String, Identifiable {
    case terms, privacy

    var id: Self { self }
    var title: String {
        switch self {
        case .terms: "Terms and Conditions"
        case .privacy: "Privacy Policy"
        }
    }
}

private struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: document.title)
                switch document {
                case .terms:
                    paragraph("Poker Pank Roulette", "The built-in game is a simulation for entertainment. It does not accept real-money wagers, pay cash prizes, or let you redeem game rewards for money or anything of value.")
                    paragraph("License", "Your use of the App Store app is governed by Apple’s Standard End User License Agreement.")
                    Link(tr("Apple Standard EULA"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .buttonStyle(NeonButtonStyle(primary: false))
                case .privacy:
                    paragraph("On this iPhone", "The built-in game saves progress, history, and preferences on this iPhone. Reset local data clears the active game save and keeps a local recovery copy. Deleting the app removes its local data from this iPhone.")
                    paragraph("Campaign measurement", "We use AppsFlyer to measure which campaigns lead to installs and app opens. AppsFlyer processes identifiers, device and network information, and install and launch activity. This can include the advertising identifier (IDFA) if you allow tracking in iOS.")
                    paragraph("Web content", "When requesting web content, the app may send the AppsFlyer identifier and campaign parameters. The web server does not retain the identifier.")
                    paragraph("Tracking and deletion", "You can change tracking permission in iOS Settings under Privacy & Security → Tracking. This does not delete data already sent. To request deletion of campaign data, contact the developer through App Support on the app’s App Store page.")
                    paragraph("AppsFlyer", "AppsFlyer processes campaign data on our behalf under its data protection terms. Its Services Privacy Policy describes its safeguards and retention, generally up to 24 months for end user data unless the customer directs otherwise or the law requires or allows longer retention.")
                    Link(tr("AppsFlyer Services Privacy Policy"), destination: URL(string: "https://www.appsflyer.com/legal/services-privacy-policy/")!)
                        .buttonStyle(NeonButtonStyle(primary: false))
                }
            }
            .padding(24)
        }
        .background(Neon.background)
    }

    private func paragraph(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(heading)).font(.headline).foregroundStyle(Neon.text)
            Text(tr(body)).font(.subheadline).foregroundStyle(Neon.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
