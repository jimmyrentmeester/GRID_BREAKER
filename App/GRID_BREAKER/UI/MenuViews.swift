import SwiftUI

// MARK: - Cyberdeck upgrade screen

/// Spend Credits on permanent Cyberdeck upgrades. The store is the authority for
/// the purchase (deterministic cost/effect); this view only presents it.
struct CyberdeckView: View {
    @Bindable var store: GameStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("CYBERDECK")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 8)
                Spacer()
                Label("\(store.cyberdeck.credits) CR", systemImage: "bitcoinsign.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
            }

            VStack(spacing: 14) {
                ForEach(CyberdeckUpgrade.allCases) { upgrade in
                    UpgradeRow(upgrade: upgrade, deck: store.cyberdeck) {
                        store.purchase(upgrade)
                    }
                }
            }

            Spacer()
            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }
}

private struct UpgradeRow: View {
    let upgrade: CyberdeckUpgrade
    let deck: Cyberdeck
    let onBuy: () -> Void

    private var level: Int { upgrade.currentLevel(in: deck) }
    private var maxed: Bool { level >= upgrade.maxLevel }
    private var cost: Int { upgrade.cost(atLevel: level) }
    private var affordable: Bool { !maxed && deck.credits >= cost }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(upgrade.title)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                // Level pips.
                HStack(spacing: 4) {
                    ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < level ? NeonTheme.cyan : Color.white.opacity(0.15))
                            .frame(width: 14, height: 5)
                    }
                }
            }
            Spacer()
            Button(action: onBuy) {
                Text(maxed ? "MAX" : "\(cost) CR")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(maxed ? NeonTheme.textDim : (affordable ? NeonTheme.gold : NeonTheme.textDim))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(affordable ? NeonTheme.gold : Color.white.opacity(0.15), lineWidth: 1.5)
                    )
            }
            .buttonStyle(TerminalButtonStyle())
            .disabled(!affordable)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NeonTheme.gridLineDim.opacity(0.4), lineWidth: 1))
        )
    }
}

// MARK: - High scores

struct HighScoresView: View {
    let scores: [HighScoreEntry]
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("TOP RUNS")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            if scores.isEmpty {
                Spacer()
                Text("// no runs logged yet")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Spacer()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(scores.enumerated()), id: \.element.id) { idx, entry in
                        HStack {
                            Text("\(idx + 1).")
                                .foregroundStyle(NeonTheme.textDim)
                                .frame(width: 28, alignment: .leading)
                            Text("\(entry.score)")
                                .foregroundStyle(idx == 0 ? NeonTheme.gold : NeonTheme.cyan)
                            Spacer()
                            Text(entry.date, format: .dateTime.day().month().hour().minute())
                                .foregroundStyle(NeonTheme.textDim)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                        }
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                    }
                }
                Spacer()
            }

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }
}
