import SwiftUI

enum GameSheet: String, Identifiable {
    case collection, guide, settings, history, tutorial
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var store = GameStore()
    @State private var atTable = false
    @State private var sheet: GameSheet?
    @State private var confirmNew = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Neon.background.ignoresSafeArea()
            if atTable, let run = store.run {
                TournamentView(store: store, run: run, onHome: { atTable = false }, onGuide: { sheet = .guide })
            } else {
                HomeView(store: store, sheet: $sheet, onStart: start, onContinue: { atTable = true })
            }
        }
        .foregroundStyle(Neon.text).preferredColorScheme(.dark).tint(Neon.cyan)
        .environment(\.locale, Locale(identifier: L10n.resolved))
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .collection: CollectionView(store: store)
                case .guide: GuideView()
                case .settings: SettingsView(store: store)
                case .history: HistoryView(store: store)
                case .tutorial: TutorialView(store: store)
                }
            }.gameSheet()
        }
        .alert(tr("Start a new tournament?"), isPresented: $confirmNew) {
            Button(tr("Cancel"), role: .cancel) {}
            Button(tr("Start new"), role: .destructive) { begin() }
        } message: { Text(tr("Your current tournament will be replaced. Your collection and history will stay.")) }
        .alert(tr("Local save"), isPresented: Binding(get: { store.saveIssue != nil }, set: { if !$0 { store.saveIssue = nil } })) {
            if store.loadBlocked { Button(tr("Retry")) { store.retryLoad() } }
            Button(tr("OK"), role: .cancel) { store.saveIssue = nil }
        } message: { Text(store.saveIssue ?? "") }
        .onChange(of: store.archive.settings.language) { _, _ in sheet = nil }
        .onChange(of: store.archive.run?.id) { _, value in if value == nil { atTable = false } }
        .onChange(of: scenePhase) { _, value in if value != .active { GameFeedback.shared.stop() } }
    }

    private func start() {
        if store.run?.isActive == true { confirmNew = true }
        else { begin() }
    }
    private func begin() {
        store.newTournament()
        guard store.run?.isActive == true, store.saveIssue == nil else { return }
        atTable = true
        GameFeedback.shared.play("confirm", settings: store.settings)
        if !store.archive.tutorialCompleted { sheet = .tutorial }
    }
}

struct HomeView: View {
    @ObservedObject var store: GameStore
    @Binding var sheet: GameSheet?
    var onStart: () -> Void
    var onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        HStack(spacing: 7) {
                            Rectangle().fill(Neon.cyan).frame(width: 6, height: 6)
                            Eyebrow(text: tr("UNDERGROUND CIRCUIT"), color: Neon.cyan)
                        }
                        Spacer()
                        SmallIconButton(icon: "slider.horizontal.3", label: "Settings") { sheet = .settings }
                    }
                    VStack(alignment: .leading, spacing: -3) {
                        Text("Poker").foregroundStyle(Neon.text)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Punk").foregroundStyle(Neon.cyan)
                            Text("// 01").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Neon.muted)
                        }
                    }.font(.system(size: min(geo.size.width * 0.137, 62), weight: .black, design: .monospaced)).tracking(-2)
                    hero(height: min(geo.size.height * 0.32, 270))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Hack the hand.")).font(.system(.title2, design: .monospaced, weight: .bold))
                        Text(tr("Spin for cards. Build your hacks. Take down three rivals."))
                            .font(.subheadline).foregroundStyle(Neon.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 10) {
                        if store.run?.isActive == true {
                            Button(action: onContinue) {
                                HStack { Text(tr("Resume tournament")); Spacer(); Image(systemName: "arrow.right") }
                            }.buttonStyle(NeonButtonStyle()).accessibilityIdentifier("resumeTournament")
                            Button(tr("New tournament"), action: onStart).buttonStyle(NeonButtonStyle(primary: false))
                        } else {
                            Button(action: onStart) {
                                HStack { Text(tr("Enter tournament")); Spacer(); Image(systemName: "arrow.right") }
                            }.buttonStyle(NeonButtonStyle()).accessibilityIdentifier("startTournament")
                        }
                    }.disabled(store.loadBlocked)
                    HStack(spacing: 0) {
                        menuButton("square.stack", "Collection", .collection)
                        menuButton("play.rectangle", "Learn", .tutorial)
                        menuButton("clock.arrow.circlepath", "History", .history)
                    }.padding(.vertical, 6)
//                    HStack {
//                        Eyebrow(text: tr("OFFLINE · NO REAL MONEY"))
//                        Spacer()
//                        Text("v1.0").font(.system(size: 10, design: .monospaced)).foregroundStyle(Neon.muted)
//                    }.padding(.bottom, 10)
                }.padding(.horizontal, 24).padding(.top, 12).frame(minHeight: geo.size.height, alignment: .top)
            }.scrollIndicators(.hidden)
        }
    }

    private func hero(height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Image("ClubBackdrop").resizable().interpolation(.none).scaledToFill()
                    .frame(width: geo.size.width, height: height).clipped().accessibilityHidden(true)
            }
            LinearGradient(colors: [.clear, Neon.background.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: tr("TONIGHT'S LINEUP"), color: Neon.cyan)
                HStack(spacing: 12) {
                    ForEach(0..<3) { i in
                        VStack(alignment: .leading, spacing: 5) {
                            PortraitView(asset: Opponent.all[i].asset, size: 52)
                            Text(String(format: "%02d", i + 1)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Neon.muted)
                        }
                        if i < 2 { Rectangle().fill(Neon.cyan.opacity(0.4)).frame(maxWidth: 22).frame(height: 1) }
                    }
                }
            }.padding(18)
            VStack { HStack { Spacer(); Eyebrow(text: tr("3 DUELS"), color: Neon.text).padding(8).background(Neon.background.opacity(0.85)) }; Spacer() }.padding(12)
        }.frame(height: height).clipShape(CutPanel(cut: 14)).overlay(CutPanel(cut: 14).stroke(Neon.line, lineWidth: 1))
    }

    private func menuButton(_ icon: String, _ title: String, _ destination: GameSheet) -> some View {
        Button { sheet = destination } label: {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Neon.cyan)
                Text(tr(title)).font(.system(.caption, design: .monospaced)).foregroundStyle(Neon.muted)
            }.frame(maxWidth: .infinity, minHeight: 66)
        }.accessibilityIdentifier("menu_\(destination.rawValue)")
    }
}
