import SwiftUI

/// A scannable reference for every mechanic — node types, systems, PROTOCOL objectives,
/// Cyberdeck upgrades, and the modes (ported from iOS; same content for parity).
struct CodexView: View {
    let onBack: () -> Void

    private struct Entry: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let name: String
        let text: String
    }

    private var targets: [Entry] {
        [
            Entry(icon: "circle.grid.cross.fill", color: NeonTheme.cyan, name: "DAEMON",
                  text: "The basic target. One tap to decode — adds score and refills your RAM."),
            Entry(icon: "lock.shield.fill", color: NeonTheme.magenta, name: "ARMORED DAEMON",
                  text: "A security shell. First tap cracks it, second decodes it. Worth more."),
            Entry(icon: "square.stack.3d.up.fill", color: NeonTheme.gold, name: "DATA CACHE",
                  text: "Short-lived gold. One tap for a big score + RAM spike. Missing it is harmless."),
            Entry(icon: "scribble.variable", color: NeonTheme.worm, name: "WORM",
                  text: "Hops to a nearby cell on a timer. Tap it wherever it lands."),
            Entry(icon: "exclamationmark.triangle.fill", color: NeonTheme.danger, name: "FIREWALL",
                  text: "NEVER tap it — a tap ends the run. Left alone it expires safely."),
        ]
    }

    private var powerUps: [Entry] {
        [
            Entry(icon: "snowflake", color: NeonTheme.cyan, name: "FREEZE",
                  text: "Pauses the RAM clock and the whole grid for a few seconds — a safe window."),
            Entry(icon: "bolt.fill", color: NeonTheme.gold, name: "OVERCLOCK",
                  text: "Doubles your score for a few seconds (stacks with Fever)."),
            Entry(icon: "wind", color: NeonTheme.magenta, name: "PURGE",
                  text: "Instantly clears every firewall on the board."),
        ]
    }

    private var systems: [Entry] {
        [
            Entry(icon: "memorychip.fill", color: NeonTheme.cyan, name: "RAM CLOCK",
                  text: "Your time buffer. It drains constantly. Decoding refills it; mistaps and letting daemons expire drain it. Empty = disconnect."),
            Entry(icon: "bolt.fill", color: NeonTheme.gold, name: "FEVER",
                  text: "Chain 8 clean decodes to trigger Fever: ×2 score, golden nodes, and hazards clear. In PROTOCOL, completing a DAEMON SET can extend Fever ×4."),
            Entry(icon: "flame.fill", color: NeonTheme.magenta, name: "CLEAN STREAK",
                  text: "Long clean chains raise a score multiplier. A single miss resets it. Endless only."),
            Entry(icon: "square.grid.4x3.fill", color: NeonTheme.cyan, name: "GRID EXPANSION",
                  text: "As your score climbs the grid grows 3×3 → 4×4. Endless + later campaign cores. PROTOCOL stays 3×3."),
        ]
    }

    private var protocolObjectives: [Entry] {
        [
            Entry(icon: "list.number", color: NeonTheme.gold, name: "DAEMON SET",
                  text: "N daemons numbered 1→N appear on the grid. Tap them in order — wrong tap is a miss (the set stays). Completing it gives ×4 on your next decode, or extends Fever ×4 if it triggers one."),
            Entry(icon: "hexagon.fill", color: NeonTheme.danger, name: "INTRUSION NODE",
                  text: "Hostile node — one tap to clear it. Spawns inside the zone when a DMZ activates; can also creep outside the zone as an overrun. No combo credit — DMZ is defense, not offense."),
            Entry(icon: "square.dashed", color: NeonTheme.danger, name: "DMZ PURGE",
                  text: "A hostile zone spawns full of intrusion nodes. Clear every cell in the zone to purge it. While a DMZ is active, intrusions creep outside the zone on a timer — if they fill the board, the run ends."),
        ]
    }

    private var modes: [Entry] {
        [
            Entry(icon: "play.fill", color: NeonTheme.cyan, name: "ENDLESS (JACK IN)",
                  text: "Survive as long as your reflexes hold and chase the high score. Power-ups, grid expansion, clean streak multiplier."),
            Entry(icon: "flag.fill", color: NeonTheme.cyan, name: "CAMPAIGN",
                  text: "10 hand-tuned cores, each introducing one mechanic — the best place to learn."),
            Entry(icon: "scope", color: NeonTheme.magenta, name: "PROTOCOL",
                  text: "Objective-driven challenge. DAEMON SETs and DMZ PURGE objectives alternate — crack them or the grid fills. No power-ups. Real fail state."),
            Entry(icon: "calendar", color: NeonTheme.cyan, name: "DAILY HACK",
                  text: "Endless rules on one shared seed per day — everyone races the same board. Power-ups active."),
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("CODEX")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 8)
                Spacer()
                Image(systemName: sfSym("book.closed.fill"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(NeonTheme.textDim)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Decode daemons before they expire. Each decode refills your RAM clock; reach the target or survive as long as you can. Never tap a firewall.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)

                    section("// TARGETS", targets)
                    section("// POWER-UPS  ·  Endless + Daily", powerUps)
                    section("// SYSTEMS", systems)
                    section("// PROTOCOL OBJECTIVES", protocolObjectives)
                    cyberdeckSection
                    section("// MODES", modes)
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }

    private func section(_ title: String, _ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            ForEach(entries) { e in row(e) }
        }
    }

    private var cyberdeckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("// CYBERDECK")
            ForEach(CyberdeckUpgrade.allCases) { u in
                row(Entry(icon: "cpu.fill", color: NeonTheme.gold, name: u.title.uppercased(), text: u.detail))
            }
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(NeonTheme.gold).tracking(1.5)
    }

    private func row(_ e: Entry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: sfSym(e.icon))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(e.color)
                .frame(width: 26, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(e.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                Text(e.text)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
            }
            Spacer(minLength: 0)
        }
    }
}
