import SwiftUI

/// Top-level menu hub. Owns the persistent `GameStore` and routes between the
/// title, a session, the Cyberdeck upgrade screen and the high-score table
/// (ground-truth Part 1.5: always a clear way to begin, never an empty opening).
struct RootView: View {
    @State private var store = GameStore()
    @State private var screen: Screen = .menu
    @State private var pulse = false

    private enum Screen { case menu, game, cyberdeck, scores }

    private func tap() { AudioEngine.shared.play(.uiTap) }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()

            switch screen {
            case .menu:
                titleScreen.transition(.opacity)
            case .game:
                GameView(deck: store.cyberdeck,
                         onExit: { screen = .menu },
                         recordSession: { score in
                             let isHigh = store.isHighScore(score)
                             let earned = store.recordSession(score: score, on: Date())
                             return SessionOutcome(creditsEarned: earned, isHighScore: isHigh)
                         })
                    .transition(.opacity)
            case .cyberdeck:
                CyberdeckView(store: store, onBack: { screen = .menu }).transition(.opacity)
            case .scores:
                HighScoresView(scores: store.highScores, onBack: { screen = .menu }).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            AudioEngine.shared.enabled = store.soundEnabled
            AudioEngine.shared.start()
        }
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
                TerminalButton(title: "JACK IN", color: NeonTheme.cyan) { tap(); screen = .game }
                TerminalButton(title: "CYBERDECK", color: NeonTheme.gold) { tap(); screen = .cyberdeck }
                TerminalButton(title: "TOP RUNS", color: NeonTheme.magenta) { tap(); screen = .scores }

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
