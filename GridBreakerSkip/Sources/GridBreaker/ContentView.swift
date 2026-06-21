import SwiftUI

// MARK: - Neon theme (subset)

enum Neon {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.05)
    static let cyan       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let magenta    = Color(red: 1.00, green: 0.20, blue: 0.80)
    static let gold       = Color(red: 1.00, green: 0.82, blue: 0.25)
    static let danger     = Color(red: 1.00, green: 0.25, blue: 0.30)
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.9), radius: radius)
            .shadow(color: color.opacity(0.5), radius: radius * 2)
    }
}

// MARK: - M1 verification view
//
// Drives the REAL ported GridEngine on Android — proves the deterministic core
// ticks, spawns, drains RAM, scores, and resolves taps. Real `dt` from Date
// timestamps (not a fixed accumulator) so speed is wall-clock-correct. The full
// grid UI is M2; this is the engine readout + a few live nodes you can tap.

struct ContentView: View {
    @State private var engine = GridEngine(config: GameConfig.endless(), seed: UInt64(20260621))
    @State private var snap: SessionSnapshot? = nil
    @State private var lastTickAt: Double = 0
    @State private var events: Int = 0

    var body: some View {
        let s = snap

        return ZStack {
            Neon.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Text("GRID_BREAKER")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Neon.cyan)
                    .neonGlow(Neon.cyan, radius: 9)
                Text("engine on android — M1")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(Neon.gold.opacity(0.7))

                if let s = s {
                    VStack(spacing: 10) {
                        readout("SCORE", "\(s.score)", Neon.gold)
                        readout("RAM", String(format: "%.1f / %.0f", s.ramRemaining, s.ramCapacity), Neon.cyan)
                        readout("NODES", "\(s.nodes.count)", Neon.magenta)
                        readout("COMBO", "\(s.combo) / \(s.comboThreshold)", Neon.cyan)
                        readout("FEVER", s.feverActive ? "ON" : "off", s.feverActive ? Neon.gold : Neon.cyan)
                        readout("ELAPSED", String(format: "%.1fs", s.elapsed), Neon.gold)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .stroke(Neon.cyan.opacity(0.35), lineWidth: 1))

                    // A live row of the actual spawned nodes — tap to decode the first.
                    HStack(spacing: 8) {
                        ForEach(s.nodes.prefix(6)) { node in
                            Circle()
                                .fill(color(for: node.type))
                                .frame(width: 26, height: 26)
                                .neonGlow(color(for: node.type), radius: 6)
                        }
                    }
                    .frame(height: 34)

                    if s.isGameOver {
                        Text("DISCONNECTED — \(reasonText(s.gameOverReason))")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Neon.danger)
                        Button("RECONNECT") { restart() }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Neon.background)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(Neon.cyan))
                    } else {
                        Button("DECODE FIRST NODE") { tapFirst() }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Neon.background)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(Neon.cyan))
                    }
                } else {
                    Text("booting engine…")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Neon.cyan)
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .task {
            snap = engine.snapshot
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)   // ~30fps tick
                step()
            }
        }
    }

    private func readout(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Neon.cyan.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(width: 220)
    }

    private func color(for type: NodeType) -> Color {
        switch type {
        case .firewallBomb: return Neon.danger
        case .armoredDaemon: return Neon.magenta
        case .dataCache: return Neon.gold
        default: return Neon.cyan
        }
    }

    private func reasonText(_ r: GameOverReason?) -> String {
        guard let r = r else { return "?" }
        switch r {
        case .ramDepleted: return "RAM"
        case .firewallHit: return "FIREWALL"
        case .coreCracked: return "CRACKED"
        case .dmzOverrun: return "DMZ"
        }
    }

    private func step() {
        let now = Date().timeIntervalSinceReferenceDate
        if lastTickAt == 0.0 { lastTickAt = now; return }
        let dt = now - lastTickAt
        lastTickAt = now
        let ev = engine.tick(deltaTime: dt)
        events += ev.count
        snap = engine.snapshot
    }

    private func tapFirst() {
        guard let first = engine.snapshot.nodes.first else { return }
        _ = engine.handleTap(cellIndex: first.cellIndex)
        snap = engine.snapshot
    }

    private func restart() {
        engine = GridEngine(config: GameConfig.endless(), seed: UInt64(20260621))
        lastTickAt = 0
        snap = engine.snapshot
    }
}
