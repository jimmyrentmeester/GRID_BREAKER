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
                    .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Cosmetics (palettes)

struct CosmeticsView: View {
    @Bindable var store: GameStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("COSMETICS")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 8)
                Spacer()
                Label("\(store.cyberdeck.credits) CR", systemImage: "bitcoinsign.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
            }
            Text("NEON PALETTES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Palettes.all) { palette in
                        PaletteRow(palette: palette,
                                   owned: store.ownsPalette(palette.id),
                                   equipped: store.equippedPaletteID == palette.id,
                                   affordable: store.cyberdeck.credits >= palette.cost) {
                            select(palette)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }

    /// Equip if owned; otherwise buy (then equip). Applies the theme immediately.
    private func select(_ palette: Palette) {
        if !store.ownsPalette(palette.id) {
            guard store.buyPalette(id: palette.id, cost: palette.cost) else { return }
        }
        NeonTheme.current = palette          // apply before the store mutation re-renders
        store.equipPalette(palette.id)
    }
}

private struct PaletteRow: View {
    let palette: Palette
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Swatch preview.
                HStack(spacing: 4) {
                    swatch(palette.primary)
                    swatch(palette.secondary)
                    swatch(palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text(equipped ? "EQUIPPED" : (owned ? "Owned" : "\(palette.cost) CR"))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(equipped ? palette.primary : NeonTheme.textDim)
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke((equipped ? palette.primary : NeonTheme.gridLineDim).opacity(equipped ? 0.9 : 0.4),
                                lineWidth: equipped ? 1.5 : 1))
            )
        }
        .buttonStyle(TerminalButtonStyle())
        .disabled(equipped || (!owned && !affordable))
    }

    @ViewBuilder private var trailing: some View {
        if equipped {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.primary)
        } else if owned {
            Text("EQUIP")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(NeonTheme.cyan, lineWidth: 1.5))
        } else {
            Text("\(palette.cost) CR")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(affordable ? NeonTheme.gold : NeonTheme.textDim)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .stroke(affordable ? NeonTheme.gold : Color.white.opacity(0.15), lineWidth: 1.5))
        }
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: 16, height: 28)
            .neonGlow(color, radius: 3)
    }
}

// MARK: - How to play

struct HowToPlayView: View {
    let onDone: () -> Void

    private struct Rule: Identifiable { let id = UUID(); let symbol: String; let color: Color; let title: String; let text: String }
    private let rules: [Rule] = [
        .init(symbol: "circle.grid.cross.fill", color: NeonTheme.cyan, title: "Decode daemons",
              text: "Tap glowing nodes to harvest data. Cyan = 1 tap."),
        .init(symbol: "lock.shield.fill", color: NeonTheme.magenta, title: "Armored = 2 taps",
              text: "Magenta nodes take two taps — breach, then decode. Worth more."),
        .init(symbol: "exclamationmark.triangle.fill", color: NeonTheme.danger, title: "Avoid firewalls",
              text: "NEVER tap a red firewall — it ends the run. Left alone, it's harmless."),
        .init(symbol: "memorychip.fill", color: NeonTheme.cyan, title: "Watch your RAM",
              text: "RAM is your clock — it drains constantly. Decoding tops it up; misses cost time."),
        .init(symbol: "bolt.fill", color: NeonTheme.gold, title: "Chain a Fever",
              text: "String clean hits to trigger Fever: hazards vanish, golden nodes, score ×2."),
        .init(symbol: "bitcoinsign.circle.fill", color: NeonTheme.gold, title: "Upgrade your deck",
              text: "Earn Credits, then boost RAM, decode speed and shields in the Cyberdeck."),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("HOW TO HACK")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(rules) { rule in
                        HStack(spacing: 14) {
                            Image(systemName: rule.symbol)
                                .font(.system(size: 22))
                                .foregroundStyle(rule.color)
                                .neonGlow(rule.color, radius: 4)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.title)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(NeonTheme.textPrimary)
                                Text(rule.text)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundStyle(NeonTheme.textDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(rule.color.opacity(0.35), lineWidth: 1))
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            TerminalButton(title: "GOT IT", color: NeonTheme.cyan, action: onDone)
        }
        .padding(24)
    }
}

// MARK: - Campaign level select

struct CampaignView: View {
    @Bindable var store: GameStore
    let onPlay: (DataCore) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("CAMPAIGN")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.magenta)
                    .neonGlow(NeonTheme.magenta, radius: 8)
                Spacer()
                Text("\(store.campaignProgress)/\(Campaign.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Campaign.cores) { core in
                        CoreRow(core: core,
                                cleared: store.isCleared(core),
                                unlocked: store.isUnlocked(core),
                                action: { if store.isUnlocked(core) { onPlay(core) } })
                    }
                }
                .padding(.vertical, 2)
            }

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }
}

private struct CoreRow: View {
    let core: DataCore
    let cleared: Bool
    let unlocked: Bool
    let action: () -> Void

    private var accent: Color {
        cleared ? NeonTheme.gold : (unlocked ? NeonTheme.cyan : NeonTheme.textDim)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(accent, lineWidth: 1.5).frame(width: 30, height: 30)
                    if cleared {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
                    } else if unlocked {
                        Text("\(core.id)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(accent)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(core.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(unlocked ? NeonTheme.textPrimary : NeonTheme.textDim)
                    Text("TARGET \(core.targetScore)  ·  \(Int(core.timeBudget))s")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
                Spacer()
                if unlocked && !cleared {
                    Image(systemName: "play.fill").foregroundStyle(NeonTheme.cyan)
                } else if cleared {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundStyle(NeonTheme.textDim)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(unlocked ? 0.04 : 0.015))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(TerminalButtonStyle())
        .disabled(!unlocked)
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
