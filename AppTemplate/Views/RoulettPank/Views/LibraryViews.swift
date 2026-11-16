import SwiftUI

struct CollectionView: View {
    @ObservedObject var store: GameStore
    @State private var selected: Hack?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SheetHeader(title: "Collection")
                Text(tr("Learn every hack. Discover new cards through tournament rewards."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                SectionHeading(title: "Hacks encountered", trailing: "\(store.archive.seenHacks.count)/18")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Hack.all) { hack in
                        Button { selected = hack } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HackTile(hack: hack, disabled: !store.archive.seenHacks.contains(hack.id))
                                if !store.archive.seenHacks.contains(hack.id) {
                                    Text(tr("Not encountered")).font(.caption2).foregroundStyle(Neon.muted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                SectionHeading(title: "Implants encountered", trailing: "\(store.archive.seenImplants.count)/6")
                ForEach(Implant.all) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon).foregroundStyle(Neon.cyan).frame(width: 28)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(item.title).font(.system(.subheadline, design: .monospaced, weight: .bold))
                            Text(item.description).font(.caption).foregroundStyle(Neon.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: store.archive.seenImplants.contains(item.id) ? "checkmark" : "circle.dotted").foregroundStyle(Neon.muted)
                    }.neonPanel()
                }
            }.padding(24)
        }.background(Neon.background)
            .sheet(item: $selected) { HackDetailView(hack: $0).gameSheet() }
    }
}

struct SettingsView: View {
    @ObservedObject var store: GameStore
    @State private var confirmReset = false
    private var victories: Int { store.archive.records.filter(\.won).count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "Settings")
                SectionHeading(title: "Language")
                Picker(tr("Language"), selection: Binding(get: { store.settings.language }, set: { value in store.updateSettings { $0.language = value } })) {
                    Text(tr("System")).tag("system")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }.pickerStyle(.segmented).accessibilityIdentifier("languagePicker")
                SectionHeading(title: "Feedback")
                VStack(spacing: 20) {
                    Toggle(tr("Sound effects"), isOn: Binding(get: { store.settings.sound }, set: { value in store.updateSettings { $0.sound = value }; if !value { GameFeedback.shared.stop() } }))
                    Toggle(tr("Haptics"), isOn: Binding(get: { store.settings.haptics }, set: { value in store.updateSettings { $0.haptics = value } }))
                    Toggle(tr("Reduce motion"), isOn: Binding(get: { store.settings.reducedMotion }, set: { value in store.updateSettings { $0.reducedMotion = value } }))
                }.tint(Neon.cyan).neonPanel()
                Text(tr("The system Reduce Motion setting is always respected."))
                    .font(.caption).foregroundStyle(Neon.muted)
                SectionHeading(title: "Card backs")
                HStack(spacing: 12) {
                    finishChoice("cyan", "Cyan", unlocked: true)
                    finishChoice("magenta", "Magenta", unlocked: store.archive.unlockedFinishes.contains("magenta"))
                    finishChoice("gold", "Gold", unlocked: store.archive.unlockedFinishes.contains("gold"))
                }
                Text(tr("Finish a tournament to unlock Magenta. Win the circuit to unlock Gold."))
                    .font(.caption).foregroundStyle(Neon.muted)
                SectionHeading(title: "Local data")
                Text(tr("Game progress and preferences are saved on this iPhone."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                if store.loadBlocked {
                    Button(tr("Retry loading save")) { store.retryLoad() }.buttonStyle(NeonButtonStyle(primary: false))
                }
                Button(tr("Reset local data"), role: .destructive) { confirmReset = true }
                    .buttonStyle(NeonButtonStyle(primary: false, tint: Neon.pink)).accessibilityIdentifier("resetLocalData")
                LegalSettingsSection()
            }.padding(24)
        }.background(Neon.background)
            .alert(tr("Reset everything?"), isPresented: $confirmReset) {
                Button(tr("Cancel"), role: .cancel) {}
                Button(tr("Reset"), role: .destructive) { store.reset() }
            } message: { Text(tr("This clears your active tournament, collection, history and settings on this iPhone. A local recovery copy is kept.")) }
    }

    private func finishChoice(_ id: String, _ name: String, unlocked: Bool) -> some View {
        Button { store.updateSettings { $0.finish = id } } label: {
            VStack(spacing: 10) {
                PlayingCardView(card: nil, selected: store.settings.finish == id, finish: id).frame(height: 92)
                Text(tr(name)).font(.system(.caption, design: .monospaced)).foregroundStyle(Neon.text)
                if !unlocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(Neon.muted) }
            }.frame(maxWidth: .infinity).opacity(unlocked ? 1 : 0.4)
        }.buttonStyle(.plain).disabled(!unlocked).accessibilityAddTraits(store.settings.finish == id ? [.isSelected] : [])
    }
}

struct HistoryView: View {
    @ObservedObject var store: GameStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SheetHeader(title: "History")
                if store.archive.records.isEmpty {
                    Image(systemName: "flag.checkered").font(.system(size: 44)).foregroundStyle(Neon.cyan).padding(.top, 24)
                    Text(tr("Your circuit starts here.")).font(.system(.title2, design: .monospaced, weight: .bold))
                    Text(tr("Completed tournaments appear here. Your current run is saved separately."))
                        .foregroundStyle(Neon.muted)
                } else {
                    ForEach(store.archive.records) { record in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: record.won ? "crown.fill" : "bolt.slash.fill").foregroundStyle(record.won ? Neon.amber : Neon.pink)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(tr(record.won ? "Champion" : "Eliminated") + " · " + tr(["Qualifier", "Semifinal", "Final"][record.stage]))
                                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                Text(record.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Locale(identifier: L10n.resolved)))).font(.caption).foregroundStyle(Neon.muted)
                                Text("\(record.wins)–\(record.losses) · \(record.hacks) " + tr("hacks")).font(.caption).foregroundStyle(Neon.cyan)
                            }
                        }.neonPanel()
                    }
                }
            }.padding(24)
        }.background(Neon.background)
    }
}

struct GuideView: View {
    private let examples: [[PlayingCard]] = [
        [PlayingCard(rank: 14, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 9, suit: .clubs), PlayingCard(rank: 5, suit: .diamonds), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 9, suit: .clubs), PlayingCard(rank: 5, suit: .diamonds), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 9, suit: .clubs), PlayingCard(rank: 9, suit: .diamonds), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 11, suit: .clubs), PlayingCard(rank: 5, suit: .diamonds), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 6, suit: .spades), PlayingCard(rank: 7, suit: .hearts), PlayingCard(rank: 8, suit: .clubs), PlayingCard(rank: 9, suit: .diamonds), PlayingCard(rank: 10, suit: .spades)],
        [PlayingCard(rank: 14, suit: .spades), PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 9, suit: .spades), PlayingCard(rank: 5, suit: .spades), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 11, suit: .clubs), PlayingCard(rank: 5, suit: .diamonds), PlayingCard(rank: 5, suit: .spades)],
        [PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 11, suit: .hearts), PlayingCard(rank: 11, suit: .clubs), PlayingCard(rank: 11, suit: .diamonds), PlayingCard(rank: 2, suit: .spades)],
        [PlayingCard(rank: 8, suit: .spades), PlayingCard(rank: 9, suit: .spades), PlayingCard(rank: 10, suit: .spades), PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: 12, suit: .spades)]
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "How to play")
                Text(tr("Build the strongest five-card hand."))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                Text(tr("The rings choose rank and suit from one shared 52-card deck. Dealt and discarded cards cannot appear again this hand."))
                    .foregroundStyle(Neon.muted)
                Text(tr("Each respin replaces one selected card. Play hacks to change weights, gain energy or get another respin. You may show your hand at any time."))
                    .foregroundStyle(Neon.muted)
                Text(tr("First to two hands wins the duel. A tie awards no win. Losing a duel ends your tournament."))
                    .foregroundStyle(Neon.muted)
                SectionHeading(title: "Strongest to weakest")
                ForEach((0...8).reversed(), id: \.self) { i in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(String(format: "%02d", 9 - i)).font(.system(.caption, design: .monospaced)).foregroundStyle(Neon.muted)
                            Text(tr(PokerValue.names[i])).font(.system(.subheadline, design: .monospaced, weight: .bold))
                        }
                        HStack(spacing: 8) { ForEach(examples[i]) { PlayingCardView(card: $0, compact: true).frame(maxHeight: 85) } }
                    }.neonPanel()
                }
                Text(tr("Royal flush is an ace-high straight flush. Ace can be high or low in A–2–3–4–5. Q–K–A–2–3 is not a straight."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                Text(tr("Same combination: compare its ranks first, then kickers. Suits never break a tie."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                SectionHeading(title: "Reading the wheel")
                Text(tr("The wheel shows public weight boosts, not exact odds. Hidden rival cards remain hidden. Boosts expire after the next draw; passive implants stay active."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                Text(tr("The result is saved before the wheel stops. Leaving the app never rerolls a card."))
                    .font(.footnote).foregroundStyle(Neon.muted)
            }.padding(24)
        }.background(Neon.background)
    }
}

struct TutorialView: View {
    @ObservedObject var store: GameStore
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss
    private var cards: [PlayingCard] {
        [PlayingCard(rank: 8, suit: .spades), PlayingCard(rank: 9, suit: .spades), PlayingCard(rank: 10, suit: .spades), PlayingCard(rank: 11, suit: .spades), PlayingCard(rank: step >= 4 ? 12 : 11, suit: step >= 4 ? .spades : .diamonds)]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "Learn the circuit")
                Eyebrow(text: tr("GUIDED EXAMPLE"), color: Neon.cyan)
                Text(tr(["Make your own luck.", "Choose a card.", "Queue a hack.", "Spin the rings.", "Straight flush."][step]))
                    .font(.system(.largeTitle, design: .monospaced, weight: .black))
                RouletteView(card: cards.last).frame(height: 220)
                HStack(spacing: 9) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        Button { if step == 1 && i == 4 { step = 2 } } label: {
                            PlayingCardView(card: card, selected: i == 4 && step >= 2 && step <= 3)
                        }.buttonStyle(.plain).accessibilityIdentifier("tutorialSlot\(i)")
                    }
                }
                Text(tr([
                    "Your five cards make a poker hand. This example starts with a pair of jacks and four spades.",
                    "Tap the jack of diamonds. Replacing it risks your pair, but opens a path to a flush or straight.",
                    "Suit magnet spends one energy to give spades ×3 weight on your next draw.",
                    "A respin discards the selected card and draws a new one. Tap Respin to see this guided outcome.",
                    "Five spades in sequence: a straight flush. In a real hand, the hack improves your odds without guaranteeing the queen."
                ][step])).foregroundStyle(Neon.muted)
                if step == 0 { Button(tr("Try a hand")) { step = 1 }.buttonStyle(NeonButtonStyle()) }
                if step == 2 {
                    HStack { HackTile(hack: Hack.find("magnet")).frame(width: 120); Spacer(); Image(systemName: "arrow.right").foregroundStyle(Neon.cyan); Text("♠ ×3").font(.system(.title2, design: .monospaced)).foregroundStyle(Neon.cyan) }
                    Button(tr("Apply suit magnet")) { step = 3 }.buttonStyle(NeonButtonStyle())
                }
                if step == 3 {
                    Button(tr("Respin")) { step = 4; GameFeedback.shared.play("reveal", settings: store.settings, success: true) }
                        .buttonStyle(NeonButtonStyle())
                }
                if step == 4 {
                    Text(tr("Win two hands to beat a rival. Pick new hacks after wins and an implant between duels. Defeat all three rivals to win the circuit."))
                        .font(.subheadline).foregroundStyle(Neon.muted)
                    Button(tr("I'm ready")) { store.finishTutorial(); dismiss() }.buttonStyle(NeonButtonStyle()).accessibilityIdentifier("finishTutorial")
                }
                Text(tr("Tutorial outcomes are fixed for teaching. Your tournament and resources are not changed."))
                    .font(.caption).foregroundStyle(Neon.muted)
                if step < 4 { Button(tr("Skip tutorial")) { store.finishTutorial(); dismiss() }.font(.footnote).foregroundStyle(Neon.muted).frame(minHeight: 44) }
            }.padding(24)
        }.background(Neon.background)
    }
}
