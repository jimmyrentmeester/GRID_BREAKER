import SwiftUI

/// Top-level menu hub. Owns the persistent `GameStore` and routes between the
/// title, a session, the Cyberdeck upgrade screen and the high-score table
/// (ground-truth Part 1.5: always a clear way to begin, never an empty opening).
struct RootView: View {
    @State private var store = GameStore()
    @State private var screen: Screen = .menu
    @State private var activeCore: DataCore?
    @State private var pulse = false

    private enum Screen { case menu, endless, daily, flow, campaign, core, cyberdeck, cosmetics, scores, tutorial, settings }

    private func tap() { AudioEngine.shared.play(.uiTap) }

    /// Today's deterministic daily challenge: a day key ("yyyy-MM-dd") shared by all
    /// players, and a seed derived from it (the engine's SplitMix64 mixes it well).
    private static func today() -> (key: String, seed: UInt64) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        return (String(format: "%04d-%02d-%02d", y, m, d), UInt64(y * 10000 + m * 100 + d))
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()

            switch screen {
            case .menu:
                titleScreen.transition(.opacity)
            case .endless:
                GameView(deck: store.cyberdeck,
                         onExit: { screen = .menu },
                         recordSession: { score, _ in
                             let isHigh = store.isHighScore(score)
                             let earned = store.recordSession(score: score, on: Date())
                             return SessionOutcome(creditsEarned: earned, isHighScore: isHigh)
                         })
                    .transition(.opacity)
            case .daily:
                // Daily challenge — endless rules on today's shared seed; its own best.
                let today = Self.today()
                GameView(deck: store.cyberdeck, seed: today.seed, daily: true,
                         onExit: { screen = .menu },
                         recordSession: { score, _ in store.recordDaily(score: score, day: today.key) })
                    .transition(.opacity)
            case .flow:
                // Chill mode — no clock, no fail, no economy; just play and leave.
                GameView(deck: store.cyberdeck, chill: true,
                         onExit: { screen = .menu },
                         recordSession: { _, _ in SessionOutcome(creditsEarned: 0, isHighScore: false) })
                    .transition(.opacity)
            case .campaign:
                CampaignView(store: store,
                             onPlay: { core in activeCore = core; screen = .core },
                             onBack: { screen = .menu })
                    .transition(.opacity)
            case .core:
                if let core = activeCore {
                    GameView(core: core, deck: store.cyberdeck,
                             briefing: store.isCleared(core) ? nil : core.briefing,
                             onExit: { screen = .campaign },
                             onNext: Campaign.core(id: core.id + 1).map { next in { activeCore = next } },
                             recordSession: { score, won in
                                 let earned = store.recordCore(core, won: won, score: score, on: Date())
                                 return SessionOutcome(creditsEarned: earned, isHighScore: false)
                             })
                        .id(core.id)          // fresh session when advancing cores
                        .transition(.opacity)
                }
            case .cyberdeck:
                CyberdeckView(store: store, onBack: { screen = .menu }).transition(.opacity)
            case .cosmetics:
                CosmeticsView(store: store, onBack: { screen = .menu }).transition(.opacity)
            case .scores:
                HighScoresView(scores: store.highScores, onBack: { screen = .menu }).transition(.opacity)
            case .tutorial:
                TutorialView(onDone: { store.markTutorialSeen(); screen = .menu }).transition(.opacity)
            case .settings:
                SettingsView(store: store,
                             onTutorial: { tap(); screen = .tutorial },
                             onBack: { screen = .menu }).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            NeonTheme.current = Palettes.byID(store.equippedPaletteID)   // apply cosmetics
            TrailSkins.equipped = TrailSkins.byID(store.equippedTrailID)
            Haptics.enabled = store.hapticsEnabled
            AudioEngine.shared.musicVolume = store.musicVolume
            AudioEngine.shared.sfxVolume = store.sfxVolume
            AudioEngine.shared.enabled = store.soundEnabled
            AudioEngine.shared.start()
            if !store.tutorialSeen { screen = .tutorial }   // first-launch onboarding
        }
        .onChange(of: screen) { _, _ in AudioEngine.shared.resume() }
    }

    private var titleScreen: some View {
        VStack(spacing: 14) {
            Text("GRID_BREAKER")
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: pulse ? 16 : 9)

            Text("// netrunner reflex hack")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.magenta)
                .neonGlow(NeonTheme.magenta, radius: 6)

            HStack(spacing: 16) {
                if let best = store.highScores.first {
                    Text("BEST  \(best.score)")
                        .foregroundStyle(NeonTheme.gold)
                }
                let db = store.dailyBest(forDay: Self.today().key)
                if db > 0 {
                    Text("DAILY  \(db)")
                        .foregroundStyle(NeonTheme.cyan)
                }
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .padding(.top, 4)

            VStack(spacing: 12) {
                TerminalButton(title: "JACK IN", color: NeonTheme.cyan, wide: true) { tap(); screen = .endless }
                TerminalButton(title: "DAILY HACK", color: NeonTheme.gold, wide: true) { tap(); screen = .daily }
                TerminalButton(title: "FLOW STATE", color: NeonTheme.gridLine, wide: true) { tap(); screen = .flow }
                TerminalButton(title: "CAMPAIGN", color: NeonTheme.magenta, wide: true) { tap(); screen = .campaign }
                TerminalButton(title: "CYBERDECK", color: NeonTheme.gold, wide: true) { tap(); screen = .cyberdeck }
                TerminalButton(title: "COSMETICS", color: NeonTheme.gridLine, wide: true) { tap(); screen = .cosmetics }
                TerminalButton(title: "TOP RUNS", color: NeonTheme.cyan, wide: true) { tap(); screen = .scores }

                Button { tap(); screen = .settings } label: {
                    Label("SETTINGS", systemImage: "gearshape")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
                .buttonStyle(TerminalButtonStyle())
                .padding(.top, 6)
            }
            .frame(maxWidth: 260)        // uniform button width
            .padding(.top, 22)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Static cyan/purple terminal grid behind the UI (decorative).
private struct GridBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let step: CGFloat = 44
            Path { p in
                var x: CGFloat = 0
                while x <= geo.size.width { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: geo.size.height)); x += step }
                var y: CGFloat = 0
                while y <= geo.size.height { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: geo.size.width, y: y)); y += step }
            }
            .stroke(NeonTheme.gridLineDim.opacity(0.18), lineWidth: 1)
        }
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
