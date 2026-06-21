import SwiftUI

// MARK: - Neon theme (subset, for the render spike)

enum Neon {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.05)
    static let cyan       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let magenta    = Color(red: 1.00, green: 0.20, blue: 0.80)
    static let gold       = Color(red: 1.00, green: 0.82, blue: 0.25)
    static let gridDim    = Color(red: 0.45, green: 0.25, blue: 0.85)
}

extension View {
    /// The neon glow signature: double-shadow halo. 70 callsites in the iOS app.
    /// `.shadow(color:radius:)` IS implemented in SkipUI → glow survives the port.
    func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.9), radius: radius)
            .shadow(color: color.opacity(0.5), radius: radius * 2)
    }
}

// MARK: - Beam shape (Canvas replacement)

/// SkipUI has NO Canvas/GraphicsContext. But `Path` + `Shape` ARE implemented,
/// so the beam/trail/particle rendering is rebuilt as a Shape with `.blur` + glow.
struct BeamShape: Shape {
    var phase: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.midY
        p.move(to: CGPoint(x: 0.0, y: mid))
        let steps = 60
        var i = 0
        while i <= steps {
            let fx = Double(i) / Double(steps)
            let x = fx * rect.width
            let y = mid + sin(phase * 3.0 + fx * 8.0) * 24.0
            p.addLine(to: CGPoint(x: x, y: y))
            i += 1
        }
        return p
    }
}

// MARK: - Render spike

/// M2a render spike — proves the PORTABLE rendering stack works on Android, after
/// the spike found TimelineView + Canvas are unavailable in SkipUI 1.8.16:
///   1. neonGlow (double .shadow) ✅ implemented
///   2. Game loop via a Task.sleep clock (TimelineView replacement)
///   3. Beam via Path/Shape + .blur (Canvas replacement)
struct ContentView: View {
    @State private var clock: Double = 0.0

    var body: some View {
        let pulse = 0.5 + 0.5 * sin(clock * 2.0)       // 0…1 breathing
        let drift = sin(clock * 1.3)                    // -1…1 horizontal drift

        ZStack {
            Neon.background.ignoresSafeArea()

            VStack(spacing: 44) {
                // RISK #1: glow on text
                Text("GRID_BREAKER")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Neon.cyan)
                    .neonGlow(Neon.cyan, radius: 10)

                // RISK #2: the game-loop clock drives a pulsing + drifting node
                ZStack {
                    Circle()
                        .fill(Neon.cyan)
                        .frame(width: 70, height: 70)
                        .scaleEffect(0.8 + 0.35 * pulse)
                        .neonGlow(Neon.cyan, radius: 14)

                    Circle()
                        .fill(Neon.magenta)
                        .frame(width: 26, height: 26)
                        .neonGlow(Neon.magenta, radius: 10)
                        .offset(x: drift * 90.0, y: 0.0)
                }
                .frame(height: 160)

                // RISK #3: Canvas replaced by Shape + blur + glow
                BeamShape(phase: clock)
                    .stroke(Neon.gold, lineWidth: 3.0)
                    .blur(radius: 2.0)
                    .neonGlow(Neon.gold, radius: 6)
                    .frame(height: 90)
                    .padding(.horizontal, 24)

                // NOTE: Double.truncatingRemainder(dividingBy:) is not in SkipLib → use Int modulo.
                Text("clock = \(Int(clock) % 1000)s")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Neon.gold.opacity(0.7))
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // The portable game loop: ~60fps tick. Replaces TimelineView(.animation).
            // The real engine will call engine.tick(dt) here with a Date-based dt.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                clock += 0.016
            }
        }
    }
}
