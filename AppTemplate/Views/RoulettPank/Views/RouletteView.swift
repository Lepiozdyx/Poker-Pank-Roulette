import SwiftUI

enum RouletteMotion {
    static let duration = 2.4
    static let completionDelay: Duration = .milliseconds(2450)
    // A fast release followed by a long, continuous coast to zero velocity.
    static let coast = Animation.timingCurve(0.16, 1, 0.3, 1, duration: duration)
}

struct WheelSlice: Shape {
    var start: Double
    var end: Double
    var inner: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), outer = min(rect.width, rect.height) / 2
        return Path { p in
            p.addArc(center: c, radius: outer, startAngle: .degrees(start + 0.6), endAngle: .degrees(end - 0.6), clockwise: false)
            p.addArc(center: c, radius: outer * inner, startAngle: .degrees(end - 0.6), endAngle: .degrees(start + 0.6), clockwise: true)
            p.closeSubpath()
        }
    }
}

struct RouletteView: View {
    var card: PlayingCard?
    var rankWeights: [Int] = Array(repeating: 4, count: 13)
    var suitWeights: [Int] = Array(repeating: 1, count: 4)
    var spinning = false
    var animate = true
    @State private var rankRotation = 0.0
    @State private var suitRotation = 0.0

    private func segments(_ weights: [Int]) -> [(Double, Double)] {
        let total = Double(max(weights.reduce(0, +), 1))
        var cursor = -90.0
        return weights.map { value in
            let start = cursor
            cursor += Double(value) / total * 360
            return (start, cursor)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Neon.line, style: StrokeStyle(lineWidth: 1, dash: [2, 6])).padding(1)
                Circle().stroke(Neon.cyan.opacity(0.24), lineWidth: 1).padding(7)
                ring(weights: rankWeights, labels: (2...14).map(PlayingCard.rankLabel), inner: 0.76, color: Neon.cyan)
                    .padding(13).rotationEffect(.degrees(rankRotation))
                ring(weights: suitWeights, labels: Suit.allCases.map(\.symbol), inner: 0.66, color: Neon.pink)
                    .padding(size * 0.22).rotationEffect(.degrees(suitRotation))
                Circle().fill(Neon.background).frame(width: size * 0.35, height: size * 0.35)
                    .overlay(Circle().stroke(Neon.line, lineWidth: 1))
                VStack(spacing: 0) {
                    Text(spinning ? "·" : card.map { PlayingCard.rankLabel($0.rank) } ?? "?")
                        .font(.system(size: size * 0.14, weight: .black, design: .monospaced)).foregroundStyle(Neon.text)
                    Text(spinning ? "·" : card?.suit.symbol ?? "♠")
                        .font(.system(size: size * 0.105)).foregroundStyle(card?.suit.isRed == true ? Neon.pink : Neon.cyan)
                }
                VStack { Rectangle().fill(Neon.amber).frame(width: 4, height: 13); Spacer() }
            }.frame(width: size, height: size).position(x: geo.size.width / 2, y: geo.size.height / 2)
                .onAppear { align() }
                .onChange(of: spinning) { _, value in if value { rotate() } }
                .onChange(of: card?.id) { _, _ in if !spinning { align() } }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(tr("Card roulette") + ". " + (spinning ? tr("Spinning") : card?.spoken ?? tr("Ready")))
    }

    private func desired(_ weights: [Int], index: Int) -> Double {
        let parts = segments(weights)
        guard parts.indices.contains(index) else { return 0 }
        return -90 - (parts[index].0 + parts[index].1) / 2
    }

    private func align() {
        guard let card else { return }
        rankRotation = desired(rankWeights, index: card.rank - 2)
        suitRotation = desired(suitWeights, index: card.suit.rawValue)
    }

    private func rotate() {
        guard let card else { return }
        let rankTarget = desired(rankWeights, index: card.rank - 2)
        let suitTarget = desired(suitWeights, index: card.suit.rawValue)
        guard animate else { align(); return }
        withAnimation(RouletteMotion.coast) {
            rankRotation += 1080 + (rankTarget - rankRotation.truncatingRemainder(dividingBy: 360))
            suitRotation -= 720 - (suitTarget - suitRotation.truncatingRemainder(dividingBy: 360))
        }
    }

    private func ring(weights: [Int], labels: [String], inner: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            let parts = segments(weights)
            let radius = min(geo.size.width, geo.size.height) * (1 + inner) / 4
            ZStack {
                ForEach(Array(parts.indices), id: \.self) { i in
                    let a = parts[i].0, b = parts[i].1, mid = (a + b) / 2
                    if b - a > 1.2 {
                        WheelSlice(start: a, end: b, inner: inner).fill(i % 2 == 0 ? color.opacity(0.19) : Neon.lifted)
                        WheelSlice(start: a, end: b, inner: inner).stroke(color.opacity(0.24), lineWidth: 0.6)
                        Text(labels[i]).font(.system(size: labels.count > 4 ? 11 : 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                            // Baseline tangent to the ring; glyph's vertical axis follows the sector radius.
                            .rotationEffect(.degrees(mid + 90))
                            .position(x: geo.size.width / 2 + cos(mid * .pi / 180) * radius,
                                      y: geo.size.height / 2 + sin(mid * .pi / 180) * radius)
                    }
                }
            }
        }
    }
}
