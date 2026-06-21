import SwiftUI

/// Spend Credits on permanent Cyberdeck upgrades (ported from iOS). GameStore is the
/// authority for the deterministic purchase; this view only presents it.
struct CyberdeckView: View {
    @Bindable var store: GameStore
    let onBack: () -> Void
    @State private var pending: CyberdeckUpgrade? = nil
    @State private var bought: String? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                HStack {
                    Text("CYBERDECK")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.cyan)
                        .neonGlow(NeonTheme.cyan, radius: 8)
                    Spacer()
                    Label("\(store.cyberdeck.credits) CR", systemImage: sfSym("bitcoinsign.circle.fill"))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                }

                VStack(spacing: 14) {
                    ForEach(CyberdeckUpgrade.allCases) { upgrade in
                        UpgradeRow(upgrade: upgrade, deck: store.cyberdeck) {
                            pending = upgrade
                        }
                    }
                }

                Spacer()
                TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
            }
            .padding(24)

            if let p = pending {
                let lvl = p.currentLevel(in: store.cyberdeck)
                ConfirmDialog(title: "CONFIRM PURCHASE",
                              message: "\(p.title) → Lv \(lvl + 1)\n\(p.cost(atLevel: lvl)) CR",
                              onConfirm: {
                                  let ok = store.purchase(p)
                                  pending = nil
                                  if ok { celebratePurchase($bought, "\(p.title) Lv \(lvl + 1)") }
                              },
                              onCancel: { pending = nil })
            }
            if let bought { PurchaseFlash(name: bought) }
        }
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(upgrade.title)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text("Lv \(level)/\(upgrade.maxLevel)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
                Text(upgrade.detail)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text("▸ \(upgrade.cumulativeEffect(at: level))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(level > 0 ? NeonTheme.cyan : NeonTheme.textDim.opacity(0.6))
                // Level pips.
                HStack(spacing: 4) {
                    ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < level ? NeonTheme.cyan : Color.white.opacity(0.15))
                            .frame(width: 14, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onBuy) {
                Text(maxed ? "MAX" : "\(cost) CR")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(maxed ? NeonTheme.textDim : (affordable ? NeonTheme.gold : NeonTheme.textDim))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(affordable ? NeonTheme.gold : Color.white.opacity(0.15), lineWidth: 1.5)
                    )
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
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
