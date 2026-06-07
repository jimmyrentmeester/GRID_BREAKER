import SwiftUI

/// Placeholder title screen for the scaffold milestone (M0).
///
/// Renders the neon "terminal boot" identity so the project is watchable from
/// day one (ground-truth Part 0: every slice ends with something you can run).
/// The grid, HUD, gameplay and upgrade screen arrive in later milestones.
struct RootView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()

            VStack(spacing: 16) {
                Text("GRID_BREAKER")
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: pulse ? 16 : 9)

                Text("// netrunner reflex hack")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.magenta)
                    .neonGlow(NeonTheme.magenta, radius: 6)

                Text("SCAFFOLD ONLINE — M0")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                    .padding(.top, 8)
            }
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
