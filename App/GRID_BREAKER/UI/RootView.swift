import SwiftUI

/// Title screen → game. The neon "terminal boot" identity (brief §10.6); tap
/// JACK IN to start a session (ground-truth Part 1.5: there's always a clear
/// way to begin, never an empty opening).
struct RootView: View {
    @State private var pulse = false
    @State private var inSession = false

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()

            if inSession {
                GameView(onExit: { inSession = false })
                    .transition(.opacity)
            } else {
                titleScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: inSession)
    }

    private var titleScreen: some View {
        VStack(spacing: 16) {
            Text("GRID_BREAKER")
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: pulse ? 16 : 9)

            Text("// netrunner reflex hack")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.magenta)
                .neonGlow(NeonTheme.magenta, radius: 6)

            TerminalButton(title: "JACK IN", color: NeonTheme.cyan) {
                inSession = true
            }
            .padding(.top, 18)
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
