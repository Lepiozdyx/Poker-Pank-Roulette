import SwiftUI
import AVFoundation
import UIKit

enum Neon {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.075)
    static let panel = Color(red: 0.055, green: 0.07, blue: 0.13)
    static let lifted = Color(red: 0.09, green: 0.105, blue: 0.18)
    static let cyan = Color(red: 0.28, green: 0.96, blue: 0.94)
    static let pink = Color(red: 1, green: 0.27, blue: 0.66)
    static let amber = Color(red: 1, green: 0.76, blue: 0.38)
    static let text = Color(red: 0.92, green: 0.95, blue: 1)
    static let muted = Color(red: 0.59, green: 0.65, blue: 0.76)
    static let line = Color(red: 0.17, green: 0.22, blue: 0.32)
    static func family(_ value: Int) -> Color { [cyan, pink, amber][value % 3] }
}

struct CutPanel: Shape {
    var cut: CGFloat = 9
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: cut, y: 0)); p.addLine(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut)); p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: 0, y: rect.maxY)); p.addLine(to: CGPoint(x: 0, y: cut)); p.closeSubpath()
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    var primary = true
    var tint: Color = Neon.cyan
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .monospaced, weight: .bold))
            .padding(.horizontal, 16).padding(.vertical, 16).frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(primary ? Neon.background : tint)
            .background(CutPanel().fill(primary ? tint : Neon.panel))
            .overlay(CutPanel().stroke(tint.opacity(primary ? 0 : 0.45), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

struct SmallIconButton: View {
    var icon: String
    var label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44) }
            .foregroundStyle(Neon.text).background(Neon.panel, in: CutPanel(cut: 6))
            .accessibilityLabel(tr(label))
    }
}

struct Eyebrow: View {
    var text: String
    var color: Color = Neon.muted
    var body: some View {
        Text(text).font(.system(.caption2, design: .monospaced, weight: .semibold)).tracking(2).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
    }
}

struct SectionHeading: View {
    var title: String
    var trailing = ""
    var body: some View {
        HStack {
            Eyebrow(text: tr(title).uppercased())
            Rectangle().fill(Neon.line).frame(height: 1)
            if !trailing.isEmpty { Text(trailing).font(.system(.caption, design: .monospaced)).foregroundStyle(Neon.cyan) }
        }
    }
}

struct PortraitView: View {
    var asset: String
    var size: CGFloat = 52
    var body: some View {
        Image(asset).resizable().interpolation(.none).scaledToFill().frame(width: size, height: size)
            .clipShape(CutPanel(cut: 7)).overlay(CutPanel(cut: 7).stroke(Neon.line, lineWidth: 1)).accessibilityHidden(true)
    }
}

struct PlayingCardView: View {
    var card: PlayingCard?
    var selected = false
    var compact = false
    var finish = "cyan"
    private var accent: Color { finish == "magenta" ? Neon.pink : (finish == "gold" ? Neon.amber : Neon.cyan) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(card == nil ? Neon.lifted : Color(red: 0.91, green: 0.94, blue: 0.96))
            if let card {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Text(PlayingCard.rankLabel(card.rank)).font(.system(compact ? .caption : .headline, design: .monospaced, weight: .black)).lineLimit(1).minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text(card.suit.symbol).font(.system(size: compact ? 12 : 15))
                    }
                    Spacer(minLength: 2)
                    Text(card.suit.symbol).font(.system(size: compact ? 21 : 30, weight: .medium))
                    Spacer(minLength: 2)
                    HStack { Spacer(minLength: 0); Text(PlayingCard.rankLabel(card.rank)).font(.system(size: compact ? 11 : 13, weight: .bold, design: .monospaced)).rotationEffect(.degrees(180)) }
                }.padding(compact ? 5 : 7)
                    .foregroundStyle(card.suit.isRed ? Color(red: 0.68, green: 0.08, blue: 0.29) : Neon.background)
            } else {
                RoundedRectangle(cornerRadius: 2).stroke(accent.opacity(0.3), lineWidth: 1).padding(5)
                Text("♠").font(.system(size: compact ? 23 : 30)).foregroundStyle(accent.opacity(0.7))
            }
        }
        .aspectRatio(0.67, contentMode: .fit)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? accent : .clear, lineWidth: 3).padding(-3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card?.spoken ?? tr("Hidden card"))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct HackTile: View {
    var hack: Hack
    var disabled = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image("HackArtwork").resizable().interpolation(.none).scaledToFill().frame(height: 58).clipped()
                    .overlay(Neon.background.opacity(0.22))
                Image(systemName: hack.icon).font(.system(size: 22)).foregroundStyle(Neon.family(hack.family))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Neon.background.opacity(0.45))
                Text("\(hack.cost)").font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(Neon.background).padding(.horizontal, 7).padding(.vertical, 3).background(Neon.family(hack.family))
            }.frame(height: 58)
            Text(hack.title).font(.system(.caption, design: .monospaced, weight: .bold)).foregroundStyle(Neon.text)
                .lineLimit(2).frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            Text(tr(["SUIT", "RANK", "CONTROL"][hack.family])).font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1.3).foregroundStyle(Neon.family(hack.family))
        }.padding(8).background(Neon.panel, in: CutPanel(cut: 7))
            .overlay(CutPanel(cut: 7).stroke(Neon.family(hack.family).opacity(0.35), lineWidth: 1))
            .opacity(disabled ? 0.48 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(hack.title). \(tr("ENERGY")): \(hack.cost). \(hack.description)")
    }
}

struct SheetHeader: View {
    var title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack {
            Text(tr(title)).font(.system(.title2, design: .monospaced, weight: .bold))
            Spacer()
            SmallIconButton(icon: "xmark", label: "Close") { dismiss() }
        }.padding(.bottom, 12)
    }
}

extension View {
    func neonPanel() -> some View {
        self.padding(16).background(Neon.panel, in: CutPanel()).overlay(CutPanel().stroke(Neon.line, lineWidth: 1))
    }
    func gameSheet() -> some View { self.presentationDragIndicator(.visible).preferredColorScheme(.dark).tint(Neon.cyan) }
}

@MainActor
final class GameFeedback {
    static let shared = GameFeedback()
    private var player: AVAudioPlayer?
    func play(_ name: String, settings: GameSettings, success: Bool = false) {
        if settings.haptics {
            if success { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        guard settings.sound, let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.35; player?.play()
        } catch { /* Gameplay remains available when the audio route is unavailable. */ }
    }
    func stop() { player?.stop() }
}
