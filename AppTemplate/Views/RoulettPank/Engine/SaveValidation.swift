import Foundation

/// Validation of the existing v1 format. Never repairs or rewrites a rejected save.
enum SaveValidation {
    static func accepts(_ archive: GameArchive) -> Bool {
        let hacks = Set(Hack.all.map(\.id)), implants = Set(Implant.all.map(\.id))
        func unique(_ ids: [String], in known: Set<String>) -> Bool {
            Set(ids).count == ids.count && ids.allSatisfy(known.contains)
        }
        let finishes: Set<String> = ["cyan", "magenta", "gold"]
        guard archive.version == 1,
              unique(archive.seenHacks, in: hacks), unique(archive.seenImplants, in: implants),
              Set(Hack.starterIDs).isSubset(of: Set(archive.seenHacks)),
              unique(archive.unlockedFinishes, in: finishes), archive.unlockedFinishes.contains("cyan"),
              archive.unlockedFinishes.contains(archive.settings.finish),
              ["system", "en", "es"].contains(archive.settings.language),
              archive.records.count <= 30, Set(archive.records.map(\.id)).count == archive.records.count,
              archive.records.allSatisfy({ validRecord($0) }) else { return false }
        guard let run = archive.run else { return true }
        guard (0...2).contains(run.stage), run.implants.count == run.stage,
              (0...2).contains(run.wins), (0...2).contains(run.losses),
              run.totalWins == run.stage * 2 + run.wins,
              (0...(run.stage + 2)).contains(run.totalLosses),
              (0...run.stage).contains(run.totalLosses - run.losses),
              (-1...1).contains(run.outcome), (1..<Int.max).contains(run.handNumber),
              run.hand.count == 5, run.opponentHand.count == 5,
              unique(run.deck, in: hacks), Set(Hack.starterIDs).isSubset(of: Set(run.deck)),
              Set(run.deck).isSubset(of: Set(archive.seenHacks)),
              unique(run.implants, in: implants), Set(run.implants).isSubset(of: Set(archive.seenImplants)),
              unique(run.hacks, in: Set(run.deck)), unique(run.playedHacks, in: Set(run.deck)),
              Set(run.hacks).isDisjoint(with: Set(run.playedHacks)), run.playedHacks.count <= 3,
              run.botLog.count <= 2, run.botLog.allSatisfy(hacks.contains),
              let last = run.lastCard, run.hand.contains(last), run.started.timeIntervalSince1970.isFinite else { return false }
        let cards = run.hand + run.opponentHand + run.reserve + run.discarded
        guard cards.count == 52, Set(cards) == Set(PlayingCard.fullDeck) else { return false }
        let initialEnergy = 2 + (run.implants.contains("energy") ? 1 : 0)
        let expectedEnergy = initialEnergy - run.playedHacks.reduce(0) { $0 + Hack.find($1).cost } + (run.playedHacks.contains("coolant") ? 1 : 0)
        let grantedSpins = 2 + (run.stage == 2 ? 1 : 0) + (run.implants.contains("spin") ? 1 : 0)
            + run.playedHacks.filter { $0 == "pulse" || $0 == "cycle" }.count
        guard run.energy == expectedEnergy, run.energy >= 0, (0...grantedSpins).contains(run.spins),
              Set(run.biases.map(\.source)).count == run.biases.count,
              run.biases.allSatisfy({ validBias($0, played: run.playedHacks) }) else { return false }
        let draws = grantedSpins - run.spins
        let open = run.phase == .playing || run.phase == .buffer
        guard run.handNumber >= run.totalWins + run.totalLosses + (open ? 1 : 0) else { return false }
        if open {
            guard run.discarded.count == draws, run.wins < 2, run.losses < 2,
                  run.rewardOptions.isEmpty, run.botLog.isEmpty, !run.champion else { return false }
        } else {
            let botDraws = run.discarded.count - draws
            guard (0...(run.stage == 2 ? 3 : 2)).contains(botDraws) else { return false }
            let ours = PokerValue.evaluate(run.hand), theirs = PokerValue.evaluate(run.opponentHand)
            let outcome = ours == theirs ? 0 : (ours > theirs ? 1 : -1)
            guard run.outcome == outcome,
                  run.wins < 2 || outcome == 1, run.losses < 2 || outcome == -1,
                  !(run.wins == 2 && run.losses == 2) else { return false }
        }
        switch run.phase {
        case .buffer:
            guard run.implants.contains("buffer"), run.hacks.count == 4, run.playedHacks.isEmpty, draws == 0 else { return false }
        case .playing:
            guard run.hacks.count + run.playedHacks.count == 3 else { return false }
        case .showdown:
            guard run.rewardOptions.isEmpty, run.hacks.count + run.playedHacks.count == 3 else { return false }
        case .reward:
            let available = hacks.subtracting(run.deck)
            guard run.outcome == 1, run.losses < 2, !(run.stage == 2 && run.wins == 2),
                  unique(run.rewardOptions, in: available), run.rewardOptions.count == min(3, available.count),
                  !run.rewardOptions.isEmpty else { return false }
        case .implant:
            let available = implants.subtracting(run.implants)
            guard run.stage < 2, run.wins == 2, run.outcome == 1,
                  unique(run.rewardOptions, in: available), run.rewardOptions.count == min(3, available.count) else { return false }
        case .finished:
            guard run.rewardOptions.isEmpty,
                  run.champion ? (run.stage == 2 && run.wins == 2 && run.losses < 2) : run.losses == 2,
                  let record = archive.records.first(where: { $0.id == run.id }),
                  record.won == run.champion, record.stage == run.stage,
                  record.wins == run.totalWins, record.losses == run.totalLosses, record.hacks == run.deck.count else { return false }
        }
        if run.phase != .finished {
            guard !run.champion, !archive.records.contains(where: { $0.id == run.id }) else { return false }
        }
        return true
    }

    private static func validRecord(_ record: TournamentRecord) -> Bool {
        guard (0...2).contains(record.stage), (6...18).contains(record.hacks), record.date.timeIntervalSince1970.isFinite else { return false }
        if record.won { return record.stage == 2 && record.wins == 6 && (0...3).contains(record.losses) }
        return (record.stage * 2...(record.stage * 2 + 1)).contains(record.wins)
            && (2...(record.stage + 2)).contains(record.losses)
    }

    private static func validBias(_ bias: CardBias, played: [String]) -> Bool {
        guard played.contains(bias.source), bias.ranks.allSatisfy({ (2...14).contains($0) }),
              Set(bias.ranks).count == bias.ranks.count, Set(bias.suits).count == bias.suits.count else { return false }
        let hack = Hack.find(bias.source)
        guard let expected = hack.bias(rank: bias.ranks.first, suit: bias.suits.first) else { return false }
        return bias.multiplier == expected.multiplier && bias.ranks == expected.ranks && bias.suits == expected.suits
            && (!hack.choosesRank || bias.ranks.count == 1) && (!hack.choosesSuit || bias.suits.count == 1)
    }
}
