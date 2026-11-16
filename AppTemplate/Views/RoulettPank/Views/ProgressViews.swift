import SwiftUI

struct ShowdownView: View {
    let run: TournamentRun
    let settings: GameSettings
    var onContinue: () -> Void
    private var ours: PokerValue { PokerValue.evaluate(run.hand) }
    private var theirs: PokerValue { PokerValue.evaluate(run.opponentHand) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Eyebrow(text: tr("SHOWDOWN"), color: Neon.muted)
            Text(tr(run.outcome > 0 ? "Hand won." : (run.outcome < 0 ? "Rival wins." : "Dead heat.")))
                .font(.system(.largeTitle, design: .monospaced, weight: .black))
                .foregroundStyle(run.outcome > 0 ? Neon.cyan : (run.outcome < 0 ? Neon.pink : Neon.amber))
                .accessibilityIdentifier("showdownResult")
            HStack(spacing: 12) {
                PortraitView(asset: run.opponent.asset, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.opponent.name).font(.system(.subheadline, design: .monospaced, weight: .bold))
                    Text(theirs.name).font(.caption).foregroundStyle(Neon.pink)
                }
                Spacer()
                Text("\(run.wins) : \(run.losses)").font(.system(.title2, design: .monospaced, weight: .bold))
            }
            HStack(spacing: 9) { ForEach(run.opponentHand) { PlayingCardView(card: $0, finish: settings.finish) } }
            Rectangle().fill(Neon.line).frame(height: 1)
            HStack {
                Eyebrow(text: tr("YOUR HAND"))
                Spacer()
                Text(ours.name).font(.system(.subheadline, design: .monospaced, weight: .bold)).foregroundStyle(Neon.cyan)
            }
            HStack(spacing: 9) { ForEach(run.hand) { PlayingCardView(card: $0, finish: settings.finish) } }
            VStack(alignment: .leading, spacing: 10) {
                if run.outcome == 0 {
                    Text(tr("Same combination and kickers. Neither player scores; play another hand."))
                } else if ours.category != theirs.category {
                    Text((run.outcome > 0 ? ours.name : theirs.name) + " > " + (run.outcome > 0 ? theirs.name : ours.name))
                        .font(.system(.headline, design: .monospaced)).foregroundStyle(Neon.text)
                    Text(tr("The higher poker combination wins."))
                } else {
                    let first = zip(ours.ranks, theirs.ranks).first { $0.0 != $0.1 }
                    if let first {
                        Text(tr("Deciding rank") + ": " + PlayingCard.rankLabel(max(first.0, first.1)) + " > " + PlayingCard.rankLabel(min(first.0, first.1)))
                            .font(.system(.headline, design: .monospaced)).foregroundStyle(Neon.text)
                    }
                    Text(tr("Same combination: compare its ranks first, then kickers. Suits never break a tie."))
                }
            }.font(.subheadline).foregroundStyle(Neon.muted).neonPanel()
            if !run.botLog.isEmpty {
                Text(tr("Rival hacks") + ": " + run.botLog.map { Hack.find($0).title }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Neon.muted)
            }
            Button(tr(run.losses >= 2 || (run.wins >= 2 && run.stage == 2) ? "Tournament result" : (run.outcome > 0 ? "Choose your upgrade" : "Next hand")), action: onContinue)
                .buttonStyle(NeonButtonStyle()).accessibilityIdentifier("continueShowdown")
        }
    }
}

struct RewardView: View {
    let run: TournamentRun
    let implant: Bool
    var onChoose: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Eyebrow(text: tr(implant ? "DUEL COMPLETE" : "HAND REWARD"), color: Neon.cyan)
            Text(tr(implant ? "Upgrade your rig." : "Build your edge."))
                .font(.system(.largeTitle, design: .monospaced, weight: .black))
            Text(tr(implant ? "Choose one implant. It stays active for the rest of this tournament." : "Choose one hack to add to your deck. It can appear in your next hands."))
                .font(.subheadline).foregroundStyle(Neon.muted)
            ForEach(run.rewardOptions, id: \.self) { id in
                if implant {
                    let item = Implant.find(id)
                    Button { onChoose(id) } label: {
                        upgradeRow(name: item.title, description: item.description, icon: item.icon, color: Neon.cyan, tag: tr("IMPLANT"))
                    }.buttonStyle(.plain).accessibilityIdentifier("implant_\(id)")
                } else {
                    let item = Hack.find(id)
                    Button { onChoose(id) } label: {
                        upgradeRow(name: item.title, description: item.description, icon: item.icon, color: Neon.family(item.family), tag: tr("ENERGY") + ": \(item.cost)")
                    }.buttonStyle(.plain).accessibilityIdentifier("reward_\(id)")
                }
            }
            if implant {
                HStack(spacing: 12) {
                    PortraitView(asset: Opponent.all[min(run.stage + 1, 2)].asset)
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: tr("UP NEXT"))
                        Text(Opponent.all[min(run.stage + 1, 2)].name).font(.system(.headline, design: .monospaced))
                    }
                }.padding(.top, 8)
            }
        }
    }

    private func upgradeRow(name: String, description: String, icon: String, color: Color, tag: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(color)
                .frame(width: 44, height: 52).background(Neon.lifted, in: CutPanel(cut: 6))
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(name).font(.system(.headline, design: .monospaced, weight: .bold)).foregroundStyle(Neon.text)
                    Spacer(minLength: 0)
                    Image(systemName: "plus").foregroundStyle(color)
                }
                Text(description).font(.subheadline).foregroundStyle(Neon.muted).fixedSize(horizontal: false, vertical: true)
                Eyebrow(text: tag.uppercased(), color: color)
            }
        }.neonPanel().contentShape(Rectangle())
    }
}

struct FinishView: View {
    let run: TournamentRun
    var onHome: () -> Void
    var onRestart: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                Image("ClubBackdrop").resizable().interpolation(.none).scaledToFill().frame(height: 200).clipped().opacity(0.6).accessibilityHidden(true)
                Image(systemName: run.champion ? "crown.fill" : "bolt.slash.fill")
                    .font(.system(size: 64)).foregroundStyle(run.champion ? Neon.amber : Neon.pink)
            }.clipShape(CutPanel(cut: 14))
            Eyebrow(text: tr("TOURNAMENT COMPLETE"), color: Neon.cyan)
            Text(tr(run.champion ? "Circuit conquered." : "Signal lost."))
                .font(.system(.largeTitle, design: .monospaced, weight: .black))
            Text(tr(run.champion ? "Three rivals down. The underground is yours tonight." : "Your run ends here. A different build could change the next one."))
                .foregroundStyle(Neon.muted)
            HStack {
                resultStat("HANDS WON", "\(run.totalWins)")
                resultStat("HACKS", "\(run.deck.count)")
                resultStat("IMPLANTS", "\(run.implants.count)")
            }.neonPanel()
            Text(tr(run.champion ? "Gold card backs unlocked. Change your finish in Settings." : "Magenta card backs unlocked. Change your finish in Settings."))
                .font(.footnote).foregroundStyle(Neon.amber)
            Button(tr("Run it again"), action: onRestart).buttonStyle(NeonButtonStyle()).accessibilityIdentifier("restartTournament")
            Button(tr("Back to club"), action: onHome).buttonStyle(NeonButtonStyle(primary: false)).accessibilityIdentifier("backToClub")
        }
    }
    private func resultStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(.title, design: .monospaced, weight: .black)).foregroundStyle(Neon.cyan)
            Text(tr(title)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Neon.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BuildView: View {
    let run: TournamentRun
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Your build")
                Text(tr("Upgrades last for this tournament. Each new hand draws three hacks from your deck."))
                    .font(.subheadline).foregroundStyle(Neon.muted)
                if !run.implants.isEmpty {
                    SectionHeading(title: "Implants", trailing: "\(run.implants.count)/2")
                    ForEach(run.implants, id: \.self) { id in
                        let item = Implant.find(id)
                        Label { VStack(alignment: .leading, spacing: 6) { Text(item.title).bold(); Text(item.description).font(.caption).foregroundStyle(Neon.muted) } } icon: {
                            Image(systemName: item.icon).foregroundStyle(Neon.cyan)
                        }.neonPanel()
                    }
                }
                SectionHeading(title: "Hack deck", trailing: "\(run.deck.count)")
                ForEach(run.deck, id: \.self) { id in
                    let item = Hack.find(id)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon).foregroundStyle(Neon.family(item.family)).frame(width: 24)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.system(.subheadline, design: .monospaced, weight: .bold))
                            Text(item.description).font(.caption).foregroundStyle(Neon.muted)
                        }
                        Spacer(minLength: 0)
                        Text("\(item.cost)").foregroundStyle(Neon.amber)
                    }.padding(.vertical, 8)
                }
            }.padding(24)
        }.background(Neon.background)
    }
}
