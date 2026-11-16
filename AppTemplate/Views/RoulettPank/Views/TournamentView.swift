import SwiftUI
import UIKit

struct TournamentView: View {
    @ObservedObject var store: GameStore
    let run: TournamentRun
    var onHome: () -> Void
    var onGuide: () -> Void
    @State private var selectedSlot: Int?
    @State private var selectedHack: Hack?
    @State private var showRule = false
    @State private var showDeck = false
    @State private var spinning = false
    @State private var dealtCount = 5
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    private var compactScreen: Bool { UIScreen.main.bounds.height < 750 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SmallIconButton(icon: "chevron.left", label: "Save and return") { onHome() }
                VStack(alignment: .leading, spacing: 3) {
                    Text("PokerPunk").font(.system(.caption, design: .monospaced, weight: .black)).tracking(1)
                    Eyebrow(text: "\(run.stage + 1)/3 · \(run.roundTitle.uppercased())", color: Neon.cyan)
                }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Spacer(minLength: 0)
                SmallIconButton(icon: "square.stack", label: "Your build") { showDeck = true }
                SmallIconButton(icon: "questionmark", label: "How to play", action: onGuide)
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
            Rectangle().fill(Neon.line).frame(height: 1)
            ScrollView {
                VStack(spacing: 20) {
                    switch run.phase {
                    case .playing, .buffer: table
                    case .showdown: ShowdownView(run: run, settings: store.settings) { store.continueShowdown() }
                    case .reward: RewardView(run: run, implant: false) { store.chooseReward($0) }
                    case .implant: RewardView(run: run, implant: true) { store.chooseImplant($0) }
                    case .finished: FinishView(run: run, onHome: onHome) { store.newTournament() }
                    }
                }.padding(18).padding(.bottom, 12)
            }.scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if run.phase == .playing {
                actionArea.padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Neon.background)
                    .overlay(alignment: .top) { Rectangle().fill(Neon.line).frame(height: 1) }
            }
        }
        .sheet(item: $selectedHack) { hack in
            HackDetailView(hack: hack, run: run) { rank, suit in
                store.play(hack, rank: rank, suit: suit)
                if store.run?.playedHacks.contains(hack.id) == true {
                    selectedHack = nil
                    GameFeedback.shared.play("confirm", settings: store.settings)
                }
            }.gameSheet()
        }
        .sheet(isPresented: $showRule) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SheetHeader(title: "Table rules")
                    PortraitView(asset: run.opponent.asset, size: 120)
                    Text(run.opponent.name).font(.system(.title, design: .monospaced, weight: .bold))
                    Text(tr(run.opponent.rule)).foregroundStyle(Neon.muted)
                    if run.stage == 1 { Text(tr("Declared suit") + ": " + run.botTarget.symbol + " " + run.botTarget.name).foregroundStyle(Neon.cyan) }
                    Text(tr("First to two hands wins the duel. A tie awards no win. Losing a duel ends your tournament."))
                    Text(tr("Rivals use their own hands and public information. They cannot see your hidden cards."))
                        .font(.footnote).foregroundStyle(Neon.muted)
                }.padding(24)
            }.background(Neon.background).gameSheet()
        }
        .sheet(isPresented: $showDeck) { BuildView(run: run).gameSheet() }
        .onChange(of: run.handNumber) { _, _ in selectedSlot = nil }
        .onChange(of: run.phase) { _, phase in if phase != .playing { selectedSlot = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { animationTask?.cancel(); spinning = false } }
        .onDisappear { animationTask?.cancel(); spinning = false }
        .task(id: run.handNumber) {
            guard run.phase == .playing || run.phase == .buffer else { dealtCount = 5; return }
            guard !reduceMotion && !store.settings.reducedMotion else { dealtCount = 5; return }
            dealtCount = 0
            for count in 1...5 {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                dealtCount = count
            }
        }
    }

    private var table: some View {
        VStack(spacing: 18) {
            opponentHeader
            HStack(spacing: 10) {
                ForEach(0..<5) { _ in PlayingCardView(card: nil, compact: true, finish: store.settings.finish).frame(width: 26) }
                Spacer()
                Text(tr("HAND") + " \(run.handNumber)").font(.system(.caption2, design: .monospaced)).foregroundStyle(Neon.muted)
            }
            wheelArea
            handArea
            if run.phase == .buffer {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Expanded buffer", trailing: "4 → 3")
                    Text(tr("Discard one hack to keep the other three.")).font(.subheadline).foregroundStyle(Neon.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(run.hacks, id: \.self) { id in
                            Button { store.discardBufferedHack(id) } label: { HackTile(hack: Hack.find(id)) }
                                .buttonStyle(.plain).accessibilityHint(tr("Discard this hack"))
                        }
                    }
                }
            } else {
                hackArea
            }
        }
    }

    private var opponentHeader: some View {
        HStack(spacing: 12) {
            PortraitView(asset: run.opponent.asset)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(run.opponent.name).font(.system(.headline, design: .monospaced, weight: .bold))
                    if run.stage == 1 {
                        Text(run.botTarget.symbol + " ×2").font(.system(.caption, design: .monospaced, weight: .bold)).foregroundStyle(Neon.pink)
                            .accessibilityLabel(tr("Declared suit") + ": " + run.botTarget.name + " ×2")
                    }
                }
                Eyebrow(text: tr(run.opponent.subtitle), color: Neon.muted)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(run.wins) : \(run.losses)").font(.system(.title2, design: .monospaced, weight: .black)).foregroundStyle(Neon.cyan)
                Button(tr("Table rules")) { showRule = true }.font(.system(.caption2, design: .monospaced)).foregroundStyle(Neon.muted).frame(minHeight: 28)
            }
        }
    }

    private var publicBiases: [CardBias] { GameEngine.playerBiases(run, replacing: selectedSlot ?? 0) }
    private var publicCards: [PlayingCard] {
        let known = Set(run.hand + run.discarded)
        return PlayingCard.fullDeck.filter { !known.contains($0) }
    }

    private var wheelArea: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                stat("RESPINS", value: String(run.spins), icon: "arrow.clockwise", color: Neon.cyan)
                stat("ENERGY", value: String(run.energy), icon: "bolt.fill", color: Neon.amber)
            }.frame(width: 58, alignment: .leading)
            RouletteView(card: run.lastCard,
                         rankWeights: (2...14).map { rank in max(1, publicCards.filter { $0.rank == rank }.reduce(0) { $0 + GameEngine.weight($1, biases: publicBiases) }) },
                         suitWeights: Suit.allCases.map { suit in max(1, publicCards.filter { $0.suit == suit && $0.rank == (run.lastCard?.rank ?? 14) }.reduce(0) { $0 + GameEngine.weight($1, biases: publicBiases) }) },
                         spinning: spinning, animate: !reduceMotion && !store.settings.reducedMotion)
                .frame(height: compactScreen ? 170 : 230).frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 5) {
                Eyebrow(text: tr("RANK"), color: Neon.cyan)
                Rectangle().fill(Neon.line).frame(width: 20, height: 1)
                Eyebrow(text: tr("SUIT"), color: Neon.pink)
                if !run.biases.isEmpty { Image(systemName: "bolt.horizontal.fill").foregroundStyle(Neon.pink).padding(.top, 16) }
            }.frame(width: 42, alignment: .trailing)
        }
    }

    private func stat(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold))
            Text(tr(title)).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(Neon.muted)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(tr(title)): \(value)")
    }

    private var handArea: some View {
        VStack(spacing: 12) {
            HStack {
                Eyebrow(text: tr("YOUR HAND"))
                Spacer()
                Text(PokerValue.evaluate(run.hand).name).font(.system(.caption, design: .monospaced, weight: .bold)).foregroundStyle(Neon.cyan)
            }
            HStack(spacing: 9) {
                ForEach(Array(run.hand.enumerated()), id: \.offset) { i, card in
                    Button { selectedSlot = selectedSlot == i ? nil : i } label: {
                        PlayingCardView(card: (spinning && selectedSlot == i) || i >= dealtCount ? nil : card, selected: selectedSlot == i, finish: store.settings.finish)
                    }.buttonStyle(.plain).disabled(spinning || dealtCount < 5 || run.phase != .playing)
                        .accessibilityIdentifier("handSlot\(i)").accessibilityHint(tr("Select to replace this card"))
                }
            }.padding(.horizontal, 3)
            if !run.biases.isEmpty {
                Text(tr("Queued for next respin") + ": " + run.biases.map(\.queuedDescription).joined(separator: " + "))
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(Neon.pink).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: spin) {
                    if typeSize.isAccessibilitySize { Text(tr(spinning ? "Spinning" : "Respin")).lineLimit(1).minimumScaleFactor(0.6) }
                    else { Label(tr(spinning ? "Spinning" : "Respin"), systemImage: "arrow.clockwise") }
                }
                    .buttonStyle(NeonButtonStyle()).disabled(selectedSlot == nil || run.spins == 0 || spinning || dealtCount < 5).accessibilityIdentifier("respinButton")
                Button {
                    guard !spinning else { return }
                    store.showdown()
                    if store.run?.phase == .showdown { GameFeedback.shared.play("reveal", settings: store.settings, success: store.run?.outcome == 1) }
                } label: { Text(tr("Show hand")).lineLimit(1).minimumScaleFactor(0.6) }
                    .buttonStyle(NeonButtonStyle(primary: false)).disabled(spinning || dealtCount < 5).accessibilityIdentifier("showHandButton")
            }
            Text(tr(selectedSlot == nil ? "Tap a card to replace it, or show your hand." : "Selected card will be discarded before the new draw."))
                .font(.caption).foregroundStyle(Neon.muted).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hackArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Your hacks", trailing: "\(run.hacks.count)/3")
            if !run.hacks.isEmpty {
                HStack(alignment: .top, spacing: 9) {
                    ForEach(run.hacks, id: \.self) { id in
                        let hack = Hack.find(id)
                        Button { selectedHack = hack } label: { HackTile(hack: hack, disabled: !GameEngine.canApply(hack, run: run)) }
                            .buttonStyle(.plain).disabled(spinning).accessibilityIdentifier("hack_\(id)")
                    }
                    if run.hacks.count < 3 { Spacer(minLength: 0).frame(maxWidth: .infinity) }
                }
            } else {
                Text(tr("All hacks used. Your hand is in your hands.")).font(.subheadline).foregroundStyle(Neon.muted).padding(.vertical, 8)
            }
            Text(tr("Weights improve your odds. They never guarantee a card.")).font(.caption2).foregroundStyle(Neon.muted)
        }
    }

    private func spin() {
        guard let selectedSlot, !spinning else { return }
        let old = run.spins
        store.respin(slot: selectedSlot)
        guard store.run?.spins == old - 1 else { return }
        spinning = true
        GameFeedback.shared.play("spin", settings: store.settings)
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            try? await Task.sleep(for: reduceMotion || store.settings.reducedMotion ? .milliseconds(80) : RouletteMotion.completionDelay)
            guard !Task.isCancelled else { return }
            spinning = false
            GameFeedback.shared.play("confirm", settings: store.settings)
        }
    }
}

struct HackDetailView: View {
    let hack: Hack
    var run: TournamentRun?
    var onPlay: ((Int?, Suit?) -> Void)?
    @State private var suit: Suit = .spades
    @State private var rank = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Hack card")
                GeometryReader { geometry in
                    ZStack {
                        Image("HackArtwork").resizable().interpolation(.none).scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        Image(systemName: hack.icon).font(.system(size: 52)).foregroundStyle(Neon.family(hack.family))
                            .padding(22).background(Neon.background.opacity(0.8), in: CutPanel())
                    }.frame(width: geometry.size.width, height: geometry.size.height).clipShape(CutPanel())
                }.frame(height: 150).allowsHitTesting(false).accessibilityHidden(true)
                HStack {
                    Text(hack.title).font(.system(.title2, design: .monospaced, weight: .bold))
                    Spacer()
                    Label("\(hack.cost)", systemImage: "bolt.fill").foregroundStyle(Neon.amber)
                }
                Text(hack.description).font(.body).foregroundStyle(Neon.muted)
                if onPlay != nil, let run {
                    if hack.choosesSuit {
                        HStack {
                            ForEach(Suit.allCases) { value in
                                Button { suit = value } label: {
                                    Text(value.symbol).font(.system(size: 28)).frame(maxWidth: .infinity, minHeight: 54)
                                        .foregroundStyle(value == suit ? Neon.background : Neon.text)
                                        .background(value == suit ? Neon.cyan : Neon.lifted, in: CutPanel(cut: 5))
                                }.accessibilityLabel(value.name).accessibilityAddTraits(suit == value ? [.isSelected] : [])
                            }
                        }
                    }
                    if hack.choosesRank {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(2...14, id: \.self) { value in
                                Button { rank = value } label: {
                                    Text(PlayingCard.rankLabel(value)).font(.system(.headline, design: .monospaced))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(rank == value ? Neon.background : Neon.text)
                                        .background(rank == value ? Neon.cyan : Neon.lifted, in: CutPanel(cut: 5))
                                }.disabled(hack.id == "mirror" && !run.hand.contains { $0.rank == value })
                                    .accessibilityAddTraits(rank == value ? [.isSelected] : [])
                            }
                        }
                    }
                    let available = GameEngine.canApply(hack, run: run, rank: rank, suit: suit)
                    Button(tr("Play hack")) { onPlay?(rank, suit) }
                        .buttonStyle(NeonButtonStyle()).disabled(!available).accessibilityIdentifier("playHackButton")
                    if !available {
                        Text(GameEngine.unavailableReason(hack, run: run, rank: rank, suit: suit) ?? tr("This hack has no available target or respin."))
                            .font(.footnote).foregroundStyle(Neon.amber)
                    }
                }
                Text(tr("Boosts multiply and expire after the next draw. A weight multiplier is not a guaranteed result."))
                    .font(.caption).foregroundStyle(Neon.muted)
            }.padding(24)
        }.background(Neon.background).onAppear { if hack.id == "mirror" { rank = run?.hand.first?.rank ?? 14 } }
    }
}
