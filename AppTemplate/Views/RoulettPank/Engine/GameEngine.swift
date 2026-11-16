import Foundation

enum GameEngine {
    static func deal(_ run: inout TournamentRun) {
        run.handNumber += 1
        run.reserve = run.random.shuffled(PlayingCard.fullDeck)
        run.hand = Array(run.reserve.prefix(5)); run.reserve.removeFirst(5)
        run.opponentHand = Array(run.reserve.prefix(5)); run.reserve.removeFirst(5)
        run.discarded = []
        run.hacks = Array(run.random.shuffled(run.deck).prefix(run.implants.contains("buffer") ? 4 : 3))
        run.playedHacks = []
        run.energy = 2 + (run.implants.contains("energy") ? 1 : 0)
        run.spins = 2 + (run.stage == 2 ? 1 : 0) + (run.implants.contains("spin") ? 1 : 0)
        run.biases = []; run.rewardOptions = []; run.botLog = []
        run.lastCard = run.hand.last
        run.botTarget = Suit.allCases.max { a, b in
            let ca = run.opponentHand.filter { $0.suit == a }.count
            let cb = run.opponentHand.filter { $0.suit == b }.count
            return ca == cb ? a.rawValue > b.rawValue : ca < cb
        } ?? .spades
        run.phase = run.hacks.count > 3 ? .buffer : .playing
    }

    static func resolvedBias(_ bias: CardBias, hand: [PlayingCard], replacing slot: Int) -> CardBias {
        var result = bias
        let remaining = hand.enumerated().filter { $0.offset != slot }.map(\.element)
        if bias.source == "echo" { result.ranks = Array(Set(remaining.map(\.rank))) }
        if bias.source == "bridge" {
            result.ranks = Array(Set(remaining.flatMap { [$0.rank - 1, $0.rank + 1] }.filter { (2...14).contains($0) }))
            if remaining.contains(where: { $0.rank == 14 }) { result.ranks.append(2) }
            if remaining.contains(where: { $0.rank == 2 }) { result.ranks.append(14) }
        }
        return result
    }

    static func weight(_ card: PlayingCard, biases: [CardBias]) -> Int {
        biases.reduce(1) { $0 * ($1.applies(to: card) ? $1.multiplier : 1) }
    }

    static func playerBiases(_ run: TournamentRun, replacing slot: Int) -> [CardBias] {
        var result: [CardBias] = []
        if run.implants.contains("spades") { result.append(CardBias(suits: [.spades], multiplier: 2)) }
        if run.implants.contains("hearts") { result.append(CardBias(suits: [.hearts], multiplier: 2)) }
        if run.implants.contains("echo") { result.append(CardBias(multiplier: 2, source: "echo")) }
        result += run.biases
        return result.map { resolvedBias($0, hand: run.hand, replacing: slot) }
    }

    static func draw(_ run: inout TournamentRun, biases: [CardBias]) -> PlayingCard? {
        guard !run.reserve.isEmpty else { return nil }
        // Select rank by summed card weights, then suit conditionally on that rank.
        let rankWeights = (2...14).map { rank in run.reserve.filter { $0.rank == rank }.reduce(0) { $0 + weight($1, biases: biases) } }
        var ticket = run.random.index(rankWeights.reduce(0, +))
        var selectedRank = 14
        for (offset, total) in rankWeights.enumerated() {
            if ticket < total { selectedRank = offset + 2; break }
            ticket -= total
        }
        let candidates = run.reserve.enumerated().filter { $0.element.rank == selectedRank }
        var suitTicket = run.random.index(candidates.reduce(0) { $0 + weight($1.element, biases: biases) })
        var chosen = candidates.last!.offset
        for item in candidates {
            let amount = weight(item.element, biases: biases)
            if suitTicket < amount { chosen = item.offset; break }
            suitTicket -= amount
        }
        return run.reserve.remove(at: chosen)
    }

    static func canApply(_ hack: Hack, run: TournamentRun, rank: Int? = nil, suit: Suit? = nil) -> Bool {
        guard run.phase == .playing, run.hacks.contains(hack.id), run.energy >= hack.cost else { return false }
        if ["pulse", "cycle", "coolant"].contains(hack.id) { return !run.reserve.isEmpty }
        guard run.spins > 0 else { return false }
        if hack.choosesSuit && suit == nil { return true }
        if hack.choosesRank && rank == nil { return true }
        if hack.id == "mirror" && !run.hand.contains(where: { $0.rank == rank }) { return false }
        guard let bias = hack.bias(rank: rank, suit: suit) else { return false }
        // Public availability only: an unavailable choice must not leak the hidden hand.
        // Hidden opponent cards remain plausible until showdown; only known cards are excluded.
        let known = Set(run.hand + run.discarded)
        let possible = PlayingCard.fullDeck.filter { !known.contains($0) }
        return run.hand.indices.contains { slot in
            let resolved = resolvedBias(bias, hand: run.hand, replacing: slot)
            return possible.contains { resolved.applies(to: $0) }
        }
    }

    static func unavailableReason(_ hack: Hack, run: TournamentRun, rank: Int? = nil, suit: Suit? = nil) -> String? {
        guard run.phase == .playing else { return tr("Finish choosing your hacks first.") }
        guard run.hacks.contains(hack.id) else { return tr("This hack has already been used.") }
        guard run.energy >= hack.cost else { return tr("Not enough energy.") }
        if !["pulse", "cycle", "coolant"].contains(hack.id) && run.spins == 0 {
            return tr("No respins left. Gain a respin before queuing a boost.")
        }
        if hack.id == "mirror", let rank, !run.hand.contains(where: { $0.rank == rank }) {
            return tr("Choose a rank in your hand.")
        }
        return canApply(hack, run: run, rank: rank, suit: suit) ? nil : tr("No unseen cards match this target.")
    }

    static func apply(_ hack: Hack, run: inout TournamentRun, rank: Int?, suit: Suit?) {
        guard canApply(hack, run: run, rank: rank, suit: suit) else { return }
        if hack.choosesSuit && suit == nil { return }
        if hack.choosesRank && rank == nil { return }
        run.energy -= hack.cost
        run.hacks.removeAll { $0 == hack.id }
        run.playedHacks.append(hack.id)
        switch hack.id {
        case "pulse", "cycle": run.spins += 1
        case "coolant": run.energy += 1
        default: if let bias = hack.bias(rank: rank, suit: suit) { run.biases.append(bias) }
        }
    }

    static func respin(_ run: inout TournamentRun, slot: Int) {
        guard run.phase == .playing, run.spins > 0, run.hand.indices.contains(slot), !run.reserve.isEmpty else { return }
        let biases = playerBiases(run, replacing: slot)
        run.discarded.append(run.hand[slot])
        guard let card = draw(&run, biases: biases) else { return }
        run.hand[slot] = card; run.lastCard = card
        run.spins -= 1; run.biases = []
    }

    private static func targetSequence(_ cards: [PlayingCard]) -> Set<Int> {
        let sets = [Set([14, 2, 3, 4, 5])] + (2...10).map { Set($0...($0 + 4)) }
        let ranks = Set(cards.map(\.rank))
        return sets.max { a, b in
            let ac = a.intersection(ranks).count, bc = b.intersection(ranks).count
            return ac == bc ? (a.max() ?? 0) < (b.max() ?? 0) : ac < bc
        } ?? Set(10...14)
    }

    /// Decisions depend only on the bot's own cards and declared specialization.
    private static func botChoice(hand: [PlayingCard], stage: Int, target: Suit) -> (Int, CardBias)? {
        let value = PokerValue.evaluate(hand)
        if value.category >= 4 { return nil }
        let counts = Dictionary(grouping: hand, by: \.rank).mapValues(\.count)
        let sequence = targetSequence(hand)
        let candidates = hand.indices.sorted { a, b in
            func score(_ card: PlayingCard) -> Int {
                switch stage {
                case 1: return (card.suit == target ? 1000 : 0) + (counts[card.rank, default: 0] > 1 ? 30 : 0) + card.rank
                case 2: return (sequence.contains(card.rank) ? 100 : 0) + (counts[card.rank, default: 0] == 1 ? 25 : 0) + card.rank
                default: return counts[card.rank, default: 0] * 100 + card.rank
                }
            }
            return score(hand[a]) == score(hand[b]) ? a < b : score(hand[a]) < score(hand[b])
        }
        guard let slot = candidates.first else { return nil }
        let remaining = hand.enumerated().filter { $0.offset != slot }.map(\.element)
        if stage == 1 { return (slot, CardBias(suits: [target], source: "magnet")) }
        if stage == 2 {
            let missing = sequence.subtracting(Set(remaining.map(\.rank)))
            return (slot, CardBias(ranks: missing.max().map { [$0] } ?? [], source: "ladder"))
        }
        return (slot, CardBias(ranks: Array(Set(remaining.map(\.rank))), source: "echo"))
    }

    static func showdown(_ run: inout TournamentRun) {
        guard run.phase == .playing else { return }
        var energy = 2
        for _ in 0..<(run.stage == 2 ? 3 : 2) {
            guard let (slot, bias) = botChoice(hand: run.opponentHand, stage: run.stage, target: run.botTarget) else { break }
            var effects: [CardBias] = []
            if run.stage == 1 { effects.append(CardBias(suits: [run.botTarget], multiplier: 2)) }
            if energy > 0 {
                var used = bias
                if run.botLog.contains(bias.source) {
                    if run.stage == 0 {
                        let counts = Dictionary(grouping: run.opponentHand.enumerated().filter { $0.offset != slot }.map(\.element), by: \.rank)
                        let best = counts.keys.sorted { left, right in
                            let lc = counts[left]?.count ?? 0, rc = counts[right]?.count ?? 0
                            return lc == rc ? left > right : lc > rc
                        }.first ?? 14
                        used = CardBias(ranks: [best], source: "ladder")
                    } else if run.stage == 1 {
                        used = CardBias(suits: run.botTarget.isRed ? [.hearts, .diamonds] : [.spades, .clubs], source: run.botTarget.isRed ? "red" : "black")
                    } else {
                        used = resolvedBias(CardBias(source: "bridge"), hand: run.opponentHand, replacing: slot)
                    }
                }
                effects.append(used); energy -= 1; run.botLog.append(used.source)
            }
            run.discarded.append(run.opponentHand[slot])
            if let replacement = draw(&run, biases: effects) { run.opponentHand[slot] = replacement }
        }
        let ours = PokerValue.evaluate(run.hand), theirs = PokerValue.evaluate(run.opponentHand)
        run.outcome = ours == theirs ? 0 : (ours > theirs ? 1 : -1)
        if run.outcome > 0 { run.wins += 1; run.totalWins += 1 }
        if run.outcome < 0 { run.losses += 1; run.totalLosses += 1 }
        run.phase = .showdown
    }
}
