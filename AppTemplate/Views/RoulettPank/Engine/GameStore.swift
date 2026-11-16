import Foundation
import Combine

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var archive = GameArchive()
    @Published var saveIssue: String?
    @Published private(set) var loadBlocked = false
    private var file: URL?
    var run: TournamentRun? { archive.run }
    var settings: GameSettings { archive.settings }

    private var hadSaveFile = false

    init() { load() }

    private enum SaveError: Error { case unsupported, invalid, unavailable }

    private func resolveFile() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("RoulettPank", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let resolved = folder.appendingPathComponent("progress-v1.json")
        file = resolved
        return resolved
    }

    private func load() {
        do {
            let url = try resolveFile()
            let next: GameArchive
            if FileManager.default.fileExists(atPath: url.path) {
                hadSaveFile = true
                let raw = try Data(contentsOf: url)
                struct Header: Decodable { let version: Int }
                guard try JSONDecoder().decode(Header.self, from: raw).version == 1 else { throw SaveError.unsupported }
                next = try JSONDecoder().decode(GameArchive.self, from: raw)
                guard SaveValidation.accepts(next) else { throw SaveError.invalid }
            } else {
                guard !hadSaveFile else { throw SaveError.unavailable }
                next = GameArchive()
            }
            L10n.language = next.settings.language
            archive = next; loadBlocked = false; saveIssue = nil
        } catch {
            loadBlocked = true
            saveIssue = tr("Your save could not be opened. It has been kept untouched. Retry, or reset local data in Settings.")
        }
    }

    @discardableResult private func commit(_ updated: GameArchive) -> Bool {
        guard !loadBlocked else { return false }
        do {
            guard SaveValidation.accepts(updated) else { throw SaveError.invalid }
            let file = try resolveFile()
            let data = try JSONEncoder().encode(updated)
            try data.write(to: file, options: .atomic)
            hadSaveFile = true
            archive = updated
            L10n.language = updated.settings.language
            return true
        } catch {
            saveIssue = tr("Could not save your action. Nothing was changed. Free some space and try again.")
            return false
        }
    }

    private func changeRun(_ action: (inout TournamentRun) -> Void) {
        guard var current = archive.run, !loadBlocked else { return }
        action(&current)
        var updated = archive; updated.run = current
        commit(updated)
    }

    func newTournament() {
        var next = archive
        var run = TournamentRun()
        GameEngine.deal(&run)
        next.run = run
        commit(next)
    }

    func respin(slot: Int) { changeRun { GameEngine.respin(&$0, slot: slot) } }
    func play(_ hack: Hack, rank: Int? = nil, suit: Suit? = nil) { changeRun { GameEngine.apply(hack, run: &$0, rank: rank, suit: suit) } }
    func showdown() { changeRun { GameEngine.showdown(&$0) } }

    func discardBufferedHack(_ id: String) {
        changeRun { run in
            guard run.phase == .buffer, run.hacks.contains(id) else { return }
            run.hacks.removeAll { $0 == id }; run.phase = .playing
        }
    }

    private func finish(_ data: inout GameArchive, won: Bool) {
        guard var run = data.run else { return }
        run.champion = won; run.phase = .finished
        if !data.unlockedFinishes.contains("magenta") { data.unlockedFinishes.append("magenta") }
        if won && !data.unlockedFinishes.contains("gold") { data.unlockedFinishes.append("gold") }
        if !data.records.contains(where: { $0.id == run.id }) {
            data.records.insert(TournamentRecord(id: run.id, date: Date(), won: won, stage: run.stage, wins: run.totalWins, losses: run.totalLosses, hacks: run.deck.count), at: 0)
            data.records = Array(data.records.prefix(30))
        }
        data.run = run
    }

    private func advance(_ data: inout GameArchive) {
        guard var run = data.run else { return }
        if run.wins >= 2 {
            let available = Implant.all.map(\.id).filter { !run.implants.contains($0) }
            run.rewardOptions = Array(run.random.shuffled(available).prefix(3))
            run.phase = .implant
            data.seenImplants = Array(Set(data.seenImplants + run.rewardOptions)).sorted()
        } else { GameEngine.deal(&run) }
        data.run = run
    }

    func continueShowdown() {
        guard var run = archive.run, run.phase == .showdown else { return }
        var next = archive
        if run.losses >= 2 { finish(&next, won: false) }
        else if run.wins >= 2 && run.stage == 2 { finish(&next, won: true) }
        else if run.outcome > 0 {
            run.rewardOptions = Array(run.random.shuffled(Hack.all.map(\.id).filter { !run.deck.contains($0) }).prefix(3))
            run.phase = .reward
            next.seenHacks = Array(Set(next.seenHacks + run.rewardOptions)).sorted()
            next.run = run
            if run.rewardOptions.isEmpty { advance(&next) }
        } else { advance(&next) }
        commit(next)
    }

    func chooseReward(_ id: String) {
        guard var run = archive.run, run.phase == .reward, run.rewardOptions.contains(id), !run.deck.contains(id) else { return }
        run.deck.append(id); run.rewardOptions = []
        var next = archive; next.run = run
        advance(&next); commit(next)
    }

    func chooseImplant(_ id: String) {
        guard var run = archive.run, run.phase == .implant, run.rewardOptions.contains(id), !run.implants.contains(id), run.stage < 2 else { return }
        run.implants.append(id); run.stage += 1; run.wins = 0; run.losses = 0
        GameEngine.deal(&run)
        var next = archive; next.run = run; commit(next)
    }

    func updateSettings(_ action: (inout GameSettings) -> Void) {
        var next = archive; action(&next.settings); commit(next)
    }

    func finishTutorial() { var next = archive; next.tutorialCompleted = true; commit(next) }

    func retryLoad() { load() }

    func reset() {
        do {
            let file = try resolveFile()
            if FileManager.default.fileExists(atPath: file.path) {
                let backup = file.deletingLastPathComponent().appendingPathComponent("progress-backup-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: file, to: backup)
            }
            let next = GameArchive()
            try JSONEncoder().encode(next).write(to: file, options: .atomic)
            hadSaveFile = true
            archive = next; L10n.language = next.settings.language; loadBlocked = false; saveIssue = nil
        } catch { saveIssue = tr("Could not reset local data. Your existing save has been preserved.") }
    }
}
