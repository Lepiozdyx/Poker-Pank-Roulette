import Foundation

struct Hack: Identifiable {
    let id: String
    let name: String
    let text: String
    let cost: Int
    let icon: String
    let family: Int
    var title: String { tr(name) }
    var description: String { tr(text) }
    static let starterIDs = ["magnet", "echo", "ladder", "pulse", "red", "black"]
    static let all: [Hack] = [
        Hack(id: "magnet", name: "Suit magnet", text: "Choose a suit. Its cards get ×3 weight on the next respin.", cost: 1, icon: "suit.spade.fill", family: 0),
        Hack(id: "echo", name: "Duplicate finder", text: "Ranks in your other four slots get ×3 weight on the next respin.", cost: 1, icon: "square.on.square", family: 1),
        Hack(id: "ladder", name: "Ladder", text: "Choose a rank. Its cards get ×3 weight on the next respin.", cost: 1, icon: "chart.line.uptrend.xyaxis", family: 2),
        Hack(id: "pulse", name: "Extra pulse", text: "Gain one extra respin this hand.", cost: 2, icon: "arrow.clockwise", family: 2),
        Hack(id: "red", name: "Red wire", text: "Hearts and diamonds get ×3 weight on the next respin.", cost: 1, icon: "suit.heart.fill", family: 0),
        Hack(id: "black", name: "Dark wire", text: "Spades and clubs get ×3 weight on the next respin.", cost: 1, icon: "suit.club.fill", family: 0),
        Hack(id: "high", name: "High voltage", text: "J, Q, K and A get ×3 weight on the next respin.", cost: 1, icon: "bolt.fill", family: 1),
        Hack(id: "low", name: "Low frequency", text: "Ranks 2–7 get ×3 weight on the next respin.", cost: 1, icon: "waveform", family: 2),
        Hack(id: "even", name: "Even signal", text: "Even ranks get ×3 weight on the next respin. Ace counts as 14.", cost: 1, icon: "circle.grid.2x2", family: 2),
        Hack(id: "odd", name: "Odd signal", text: "Odd ranks get ×3 weight on the next respin. Jack counts as 11.", cost: 1, icon: "circle.grid.3x1", family: 2),
        Hack(id: "royal", name: "Royal protocol", text: "Ranks 10–A get ×3 weight on the next respin.", cost: 1, icon: "crown.fill", family: 1),
        Hack(id: "anchor", name: "Rank anchor", text: "Choose a rank. Its cards get ×5 weight on the next respin.", cost: 2, icon: "scope", family: 1),
        Hack(id: "prism", name: "Prism", text: "Choose a suit. Its cards get ×5 weight on the next respin.", cost: 2, icon: "diamond.fill", family: 0),
        Hack(id: "bridge", name: "Bridge", text: "Ranks next to your other cards get ×3 weight on the next respin.", cost: 1, icon: "point.topleft.down.to.point.bottomright.curvepath", family: 2),
        Hack(id: "mirror", name: "Mirror", text: "Choose a rank in your hand. It gets ×3 weight on the next respin.", cost: 1, icon: "rectangle.on.rectangle", family: 1),
        Hack(id: "cycle", name: "Free cycle", text: "Gain one extra respin. Costs no energy.", cost: 0, icon: "arrow.clockwise", family: 2),
        Hack(id: "coolant", name: "Coolant", text: "Gain one energy this hand.", cost: 0, icon: "snowflake", family: 2),
        Hack(id: "surge", name: "Suit surge", text: "Choose a suit. Its cards get ×7 weight on the next respin.", cost: 2, icon: "sparkles", family: 0)
    ]
    static func find(_ id: String) -> Hack { all.first { $0.id == id } ?? all[0] }
    var choosesSuit: Bool { ["magnet", "prism", "surge"].contains(id) }
    var choosesRank: Bool { ["ladder", "anchor", "mirror"].contains(id) }
    func bias(rank: Int?, suit: Suit?) -> CardBias? {
        switch id {
        case "magnet", "prism", "surge": return CardBias(suits: suit.map { [$0] } ?? [], multiplier: id == "surge" ? 7 : (id == "prism" ? 5 : 3), source: id)
        case "ladder", "anchor", "mirror": return CardBias(ranks: rank.map { [$0] } ?? [], multiplier: id == "anchor" ? 5 : 3, source: id)
        case "echo", "bridge": return CardBias(source: id)
        case "red": return CardBias(suits: [.hearts, .diamonds], source: id)
        case "black": return CardBias(suits: [.spades, .clubs], source: id)
        case "high": return CardBias(ranks: Array(11...14), source: id)
        case "low": return CardBias(ranks: Array(2...7), source: id)
        case "even": return CardBias(ranks: (2...14).filter { $0 % 2 == 0 }, source: id)
        case "odd": return CardBias(ranks: (2...14).filter { $0 % 2 == 1 }, source: id)
        case "royal": return CardBias(ranks: Array(10...14), source: id)
        default: return nil
        }
    }
}

struct Implant: Identifiable {
    let id: String
    let name: String
    let text: String
    let icon: String
    var title: String { tr(name) }
    var description: String { tr(text) }
    static let all = [
        Implant(id: "buffer", name: "Expanded buffer", text: "See four hacks at the start of each hand. Keep three.", icon: "square.stack.3d.up"),
        Implant(id: "spin", name: "Auxiliary rotor", text: "Start every hand with one extra respin.", icon: "arrow.clockwise"),
        Implant(id: "energy", name: "Capacitor", text: "Start every hand with one extra energy.", icon: "bolt.fill"),
        Implant(id: "spades", name: "Spade circuit", text: "Spades get ×2 weight on all your respins.", icon: "suit.spade.fill"),
        Implant(id: "hearts", name: "Heart circuit", text: "Hearts get ×2 weight on all your respins.", icon: "suit.heart.fill"),
        Implant(id: "echo", name: "Echo chamber", text: "Ranks in your other four slots get ×2 weight on all your respins.", icon: "square.on.square")
    ]
    static func find(_ id: String) -> Implant { all.first { $0.id == id } ?? all[0] }
}

struct Opponent {
    let name: String
    let asset: String
    let subtitle: String
    let rule: String
    static let all = [
        Opponent(name: "Double", asset: "PortraitDouble", subtitle: "THE PAIR HUNTER", rule: "Double keeps matching ranks. Both players have two respins and two energy."),
        Opponent(name: "Spectra", asset: "PortraitSpectra", subtitle: "THE SUIT SPECIALIST", rule: "Spectra favors one suit. Her declared circuit gives it ×2 weight on her respins."),
        Opponent(name: "Dealer-0", asset: "PortraitDealer", subtitle: "THE FINAL PROTOCOL", rule: "Dealer-0 builds sequences. The final gives both players one extra respin.")
    ]
}
