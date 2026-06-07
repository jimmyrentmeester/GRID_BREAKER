import SwiftUI

/// Top-level menu hub. Owns the persistent `GameStore` and routes between the
/// title, a session, the Cyberdeck upgrade screen and the high-score table
/// (ground-truth Part 1.5: always a clear way to begin, never an empty opening).
struct RootView: View {
    @State private var store = GameStore()
    @State private var screen: Screen = .menu
    @State private var activeCore: DataCore?
    @State private var pulse = false

    private enum Screen { case menu, endless, flow, campaign, core, cyberdeck, scores, help }

    private func tap() { AudioEngine.shared.play(.uiTap) }

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
            case .scores:
                HighScoresView(scores: store.highScores, onBack: { screen = .menu }).transition(.opacity)
            case .help:
                HowToPlayView(onDone: { store.markTutorialSeen(); screen = .menu }).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            AudioEngine.shared.enabled = store.soundEnabled
            AudioEngine.shared.start()
            if !store.tutorialSeen { screen = .help }   // first-launch onboarding
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

            if let best = store.highScores.first {
                Text("BEST  \(best.score)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                TerminalButton(title: "JACK IN", color: NeonTheme.cyan) { tap(); screen = .endless }
                TerminalButton(title: "FLOW STATE", color: NeonTheme.gridLine) { tap(); screen = .flow }
                TerminalButton(title: "CAMPAIGN", color: NeonTheme.magenta) { tap(); screen = .campaign }
                TerminalButton(title: "CYBERDECK", color: NeonTheme.gold) { tap(); screen = .cyberdeck }
                TerminalButton(title: "TOP RUNS", color: NeonTheme.cyan) { tap(); screen = .scores }

                HStack(spacing: 18) {
                    Button {
                        let on = !store.soundEnabled
                        store.setSoundEnabled(on)
                        AudioEngine.shared.enabled = on
                        if on { AudioEngine.shared.play(.uiTap) }
                    } label: {
                        Label(store.soundEnabled ? "SOUND ON" : "SOUND OFF",
                              systemImage: store.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NeonTheme.textDim)
                    }
                    .buttonStyle(TerminalButtonStyle())

                    Button { tap(); screen = .help } label: {
                        Label("HOW TO PLAY", systemImage: "questionmark.circle")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NeonTheme.textDim)
                    }
                    .buttonStyle(TerminalButtonStyle())
                }
                .padding(.top, 6)
            }
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
