import Foundation

enum Suit: Int, Codable, CaseIterable, Identifiable {
    case spades, hearts, clubs, diamonds
    var id: Int { rawValue }
    var symbol: String { ["♠", "♥", "♣", "♦"][rawValue] }
    var name: String { tr(["Spades", "Hearts", "Clubs", "Diamonds"][rawValue]) }
    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct PlayingCard: Codable, Hashable, Identifiable {
    let rank: Int
    let suit: Suit
    var id: Int { suit.rawValue * 13 + rank - 2 }
    var label: String { Self.rankLabel(rank) + suit.symbol }
    var spoken: String { "\(Self.rankLabel(rank)) · \(suit.name)" }
    nonisolated static func rankLabel(_ rank: Int) -> String {
        switch rank { case 11: return "J"; case 12: return "Q"; case 13: return "K"; case 14: return "A"; default: return String(rank) }
    }
    static var fullDeck: [PlayingCard] {
        Suit.allCases.flatMap { suit in (2...14).map { PlayingCard(rank: $0, suit: suit) } }
    }
}

struct PokerValue: Comparable {
    let category: Int
    let ranks: [Int]
    static let names = ["High card", "One pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush"]
    var name: String { category == 8 && ranks.first == 14 ? tr("Royal flush") : tr(Self.names[category]) }
    var detail: String { ranks.map(PlayingCard.rankLabel).joined(separator: " · ") }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category ? lhs.ranks.lexicographicallyPrecedes(rhs.ranks) : lhs.category < rhs.category
    }
    static func evaluate(_ cards: [PlayingCard]) -> PokerValue {
        guard cards.count == 5 else { return PokerValue(category: 0, ranks: []) }
        let ordered = cards.map(\.rank).sorted(by: >)
        let groupedCards: [Int: [PlayingCard]] = Dictionary(grouping: cards, by: \.rank)
        var groups: [(rank: Int, count: Int)] = groupedCards.map { (rank: $0.key, count: $0.value.count) }
        groups.sort { left, right in
            if left.count == right.count { return left.rank > right.rank }
            return left.count > right.count
        }
        let flush = Set(cards.map(\.suit)).count == 1
        let unique = Array(Set(ordered)).sorted()
        let straight = unique == [2, 3, 4, 5, 14] ? 5 : (unique.count == 5 && unique[4] - unique[0] == 4 ? unique[4] : 0)
        if flush && straight > 0 { return PokerValue(category: 8, ranks: [straight]) }
        if groups[0].count == 4 { return PokerValue(category: 7, ranks: groups.map(\.rank)) }
        if groups[0].count == 3 && groups[1].count == 2 { return PokerValue(category: 6, ranks: groups.map(\.rank)) }
        if flush { return PokerValue(category: 5, ranks: ordered) }
        if straight > 0 { return PokerValue(category: 4, ranks: [straight]) }
        if groups[0].count == 3 { return PokerValue(category: 3, ranks: groups.map(\.rank)) }
        if groups[0].count == 2 && groups[1].count == 2 { return PokerValue(category: 2, ranks: groups.map(\.rank)) }
        if groups[0].count == 2 { return PokerValue(category: 1, ranks: groups.map(\.rank)) }
        return PokerValue(category: 0, ranks: ordered)
    }
}

/// Full generator state is saved along with the shuffled reserve and pending outcome.
struct GameRandom: Codable {
    var state: UInt64
    init() { state = UInt64.random(in: 1...UInt64.max) }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func index(_ upper: Int) -> Int {
        precondition(upper > 0)
        let bound = UInt64(upper), threshold = (0 &- bound) % bound
        var value = next()
        while value < threshold { value = next() }
        return Int(value % bound)
    }
    mutating func shuffled<T>(_ values: [T]) -> [T] {
        var result = values
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, through: 1, by: -1) { result.swapAt(i, index(i + 1)) }
        return result
    }
}

enum RunPhase: String, Codable { case buffer, playing, showdown, reward, implant, finished }

struct CardBias: Codable {
    var ranks: [Int] = []
    var suits: [Suit] = []
    var multiplier: Int = 3
    var source: String = ""
    var queuedDescription: String {
        let hack = Hack.find(source)
        var parts = [hack.title]
        if hack.choosesRank { parts.append(ranks.map(PlayingCard.rankLabel).joined(separator: "/")) }
        if hack.choosesSuit { parts.append(suits.map { $0.symbol + " " + $0.name }.joined(separator: "/")) }
        parts.append("×\(multiplier)")
        return parts.joined(separator: " · ")
    }
    func applies(to card: PlayingCard) -> Bool { ranks.contains(card.rank) || suits.contains(card.suit) }
}

struct TournamentRun: Codable, Identifiable {
    var id = UUID()
    var random = GameRandom()
    var stage = 0
    var wins = 0
    var losses = 0
    var handNumber = 0
    var phase: RunPhase = .playing
    var hand: [PlayingCard] = []
    var opponentHand: [PlayingCard] = []
    var reserve: [PlayingCard] = []
    var discarded: [PlayingCard] = []
    var deck = Hack.starterIDs
    var hacks: [String] = []
    var playedHacks: [String] = []
    var implants: [String] = []
    var energy = 2
    var spins = 2
    var biases: [CardBias] = []
    var rewardOptions: [String] = []
    var outcome = 0
    var lastCard: PlayingCard?
    var champion = false
    var started = Date()
    var totalWins = 0
    var totalLosses = 0
    var botLog: [String] = []
    var botTarget: Suit = .spades
    var roundTitle: String { tr(["Qualifier", "Semifinal", "Final"][min(stage, 2)]) }
    var opponent: Opponent { Opponent.all[min(stage, 2)] }
    var isActive: Bool { phase != .finished }
}

struct TournamentRecord: Codable, Identifiable {
    var id: UUID
    var date: Date
    var won: Bool
    var stage: Int
    var wins: Int
    var losses: Int
    var hacks: Int
}

struct GameSettings: Codable {
    var language = "system"
    var sound = true
    var haptics = true
    var reducedMotion = false
    var finish = "cyan"
}

struct GameArchive: Codable {
    var version = 1
    var settings = GameSettings()
    var run: TournamentRun?
    var seenHacks = Hack.starterIDs
    var seenImplants: [String] = []
    var records: [TournamentRecord] = []
    var unlockedFinishes = ["cyan"]
    var tutorialCompleted = false
}

enum L10n {
    static var language = "system"
    static var resolved: String {
        if language != "system" { return language }
        return Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
    }
}

func tr(_ key: String) -> String {
    guard let path = Bundle.main.path(forResource: L10n.resolved, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}
