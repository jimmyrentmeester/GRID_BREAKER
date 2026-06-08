import SwiftUI

// MARK: - Confirm dialog (purchases)

/// Neon-styled confirmation overlay used before spending Credits.
struct ConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = "BUY"
    var confirmColor: Color = NeonTheme.gold
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text(message)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    TerminalButton(title: confirmLabel, color: confirmColor, action: onConfirm)
                    TerminalButton(title: "CANCEL", color: NeonTheme.magenta, action: onCancel)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NeonTheme.background.opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(confirmColor.opacity(0.6), lineWidth: 1.5))
            )
            .padding(40)
        }
    }
}

// MARK: - Purchase celebration (shared by the shops)

/// Fire the rewarding feedback for a completed purchase: a sound, a success haptic,
/// and a brief "ACQUIRED" flash (auto-dismissed). Shared by Cyberdeck + Cosmetics.
@MainActor
func celebratePurchase(_ bought: Binding<String?>, _ name: String) {
    AudioEngine.shared.play(.purchase)
    Haptics().success()
    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bought.wrappedValue = name }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
        withAnimation(.easeOut(duration: 0.3)) {
            if bought.wrappedValue == name { bought.wrappedValue = nil }
        }
    }
}

/// A brief gold "ACQUIRED" reward card shown over a shop on a completed buy.
struct PurchaseFlash: View {
    let name: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NeonTheme.gold).neonGlow(NeonTheme.gold, radius: 16)
            Text("ACQUIRED")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.gold).neonGlow(NeonTheme.gold, radius: 8)
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(NeonTheme.background.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(NeonTheme.gold.opacity(0.6), lineWidth: 1.5)))
        .neonGlow(NeonTheme.gold, radius: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

// MARK: - Cyberdeck upgrade screen

/// Spend Credits on permanent Cyberdeck upgrades. The store is the authority for
/// the purchase (deterministic cost/effect); this view only presents it.
struct CyberdeckView: View {
    @Bindable var store: GameStore
    let onBack: () -> Void
    @State private var pending: CyberdeckUpgrade?
    @State private var bought: String?

    var body: some View {
        ZStack {
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
                            pending = upgrade            // confirm before spending
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
                    .fixedSize(horizontal: false, vertical: true)
                // Level pips.
                HStack(spacing: 4) {
                    ForEach(0..<upgrade.maxLevel, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < level ? NeonTheme.cyan : Color.white.opacity(0.15))
                            .frame(width: 14, height: 5)
                    }
                }
                .accessibilityHidden(true)   // decorative; level is in the label below
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(upgrade.title), level \(level) of \(upgrade.maxLevel). \(upgrade.detail)")
            Button(action: onBuy) {
                Text(maxed ? "MAX" : "\(cost) CR")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(maxed ? NeonTheme.textDim : (affordable ? NeonTheme.gold : NeonTheme.textDim))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(affordable ? NeonTheme.gold : Color.white.opacity(0.15), lineWidth: 1.5)
                    )
                    .frame(minHeight: 44)          // ≥44pt tap target (Apple HIG)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TerminalButtonStyle())
            .disabled(!affordable)
            .accessibilityLabel(maxed ? "\(upgrade.title) fully upgraded"
                                      : "Upgrade \(upgrade.title), costs \(cost) credits")
            .accessibilityHint(affordable ? "" : maxed ? "" : "Not enough credits")
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
    @State private var pending: Palette?
    @State private var pendingTrail: TrailSkin?
    @State private var bought: String?

    private func sectionLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(NeonTheme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
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

                ScrollView {
                    VStack(spacing: 12) {
                        sectionLabel("NEON PALETTES")
                        ForEach(Palettes.all) { palette in
                            PaletteRow(palette: palette,
                                       owned: store.ownsPalette(palette.id),
                                       equipped: store.equippedPaletteID == palette.id,
                                       affordable: store.cyberdeck.credits >= palette.cost) {
                                tapped(palette)
                            }
                        }
                        sectionLabel("TAP TRAILS").padding(.top, 6)
                        ForEach(TrailSkins.all) { skin in
                            TrailRow(skin: skin,
                                     owned: store.ownsTrail(skin.id),
                                     equipped: store.equippedTrailID == skin.id,
                                     affordable: store.cyberdeck.credits >= skin.cost) {
                                tappedTrail(skin)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
            }
            .padding(24)

            if let p = pending {
                ConfirmDialog(title: "CONFIRM PURCHASE",
                              message: "\(p.name) palette\n\(p.cost) CR",
                              confirmLabel: "BUY & EQUIP",
                              onConfirm: { purchaseAndEquip(p); pending = nil },
                              onCancel: { pending = nil })
            }
            if let t = pendingTrail {
                ConfirmDialog(title: "CONFIRM PURCHASE",
                              message: "\(t.name) trail\n\(t.cost) CR",
                              confirmLabel: "BUY & EQUIP",
                              onConfirm: { purchaseAndEquipTrail(t); pendingTrail = nil },
                              onCancel: { pendingTrail = nil })
            }
            if let bought { PurchaseFlash(name: bought) }
        }
    }

    // MARK: Palettes
    private func tapped(_ palette: Palette) {
        if store.ownsPalette(palette.id) { equip(palette) }
        else if store.cyberdeck.credits >= palette.cost { pending = palette }
    }
    private func equip(_ palette: Palette) {
        NeonTheme.current = palette          // apply before the store mutation re-renders
        store.equipPalette(palette.id)
    }
    private func purchaseAndEquip(_ palette: Palette) {
        guard store.buyPalette(id: palette.id, cost: palette.cost) else { return }
        equip(palette)
        celebratePurchase($bought, "\(palette.name) palette")
    }

    // MARK: Tap trails
    private func tappedTrail(_ skin: TrailSkin) {
        if store.ownsTrail(skin.id) { equipTrail(skin) }
        else if store.cyberdeck.credits >= skin.cost { pendingTrail = skin }
    }
    private func equipTrail(_ skin: TrailSkin) {
        TrailSkins.equipped = skin
        store.equipTrail(skin.id)
    }
    private func purchaseAndEquipTrail(_ skin: TrailSkin) {
        guard store.buyTrail(id: skin.id, cost: skin.cost) else { return }
        equipTrail(skin)
        celebratePurchase($bought, "\(skin.name) trail")
    }
}

private struct TrailRow: View {
    let skin: TrailSkin
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                trailPreview
                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text(equipped ? "EQUIPPED" : (owned ? "Owned" : "\(skin.cost) CR"))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(equipped ? skin.color() : NeonTheme.textDim)
                }
                Spacer(minLength: 0)
                if equipped {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(skin.color())
                } else if owned {
                    Text("EQUIP").font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.cyan)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(NeonTheme.cyan, lineWidth: 1.5))
                } else {
                    Text("\(skin.cost) CR").font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(affordable ? NeonTheme.gold : NeonTheme.textDim)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .stroke(affordable ? NeonTheme.gold : Color.white.opacity(0.15), lineWidth: 1.5))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke((equipped ? skin.color() : NeonTheme.gridLineDim).opacity(equipped ? 0.9 : 0.4),
                            lineWidth: equipped ? 1.5 : 1)))
        }
        .buttonStyle(TerminalButtonStyle())
        .disabled(equipped || (!owned && !affordable))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(skin.name) trail")
        .accessibilityValue(equipped ? "Equipped" : owned ? "Owned, tap to equip"
                                                          : "Costs \(skin.cost) credits")
        .accessibilityAddTraits(equipped ? [.isButton, .isSelected] : .isButton)
    }

    // A clean mini "data stream": a fading beam through three nodes, in the skin's
    // own style — the same renderer the in-game trail uses.
    private var trailPreview: some View {
        Group {
            if skin.isOff {
                Image(systemName: "nosign")
                    .font(.system(size: 18))
                    .foregroundStyle(NeonTheme.textDim)
            } else {
                TrailSwatch(skin: skin)
            }
        }
        .frame(width: 58, height: 34, alignment: .center)
    }
}

/// Static preview of a trail skin: a left-to-right zig-zag beam with three nodes,
/// brightening toward the leading (right) end, drawn exactly like the live trail.
private struct TrailSwatch: View {
    let skin: TrailSkin

    var body: some View {
        Canvas { ctx, size in
            let c = skin.color()
            let pts = [
                CGPoint(x: 5, y: size.height * 0.72),
                CGPoint(x: size.width * 0.5, y: size.height * 0.28),
                CGPoint(x: size.width - 5, y: size.height * 0.6),
            ]
            // fade toward the trailing (left) end
            let fades: [CGFloat] = [0.5, 0.78, 1.0]
            func stroke(_ g: GraphicsContext, scale: CGFloat) {
                for i in 1..<pts.count {
                    var p = Path(); p.move(to: pts[i - 1]); p.addLine(to: pts[i])
                    let w = skin.lineWidth * (0.5 + 0.5 * fades[i]) * scale
                    g.stroke(p, with: .color(c.opacity(0.85 * Double(fades[i]))), style: skin.beamStyle(width: w))
                }
            }
            func nodes(_ g: GraphicsContext, scale: CGFloat) {
                for (i, p) in pts.enumerated() {
                    g.fill(skin.dotPath(at: p, size: skin.size * (0.7 + 0.3 * fades[i]) * scale),
                           with: .color(c.opacity(0.9 * Double(fades[i]))))
                }
            }
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: max(2, skin.lineWidth * 0.8)))
                stroke(l, scale: 1.4); nodes(l, scale: 1.3)
            }
            stroke(ctx, scale: 1.0); nodes(ctx, scale: 1.0)
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(palette.name) palette")
        .accessibilityValue(equipped ? "Equipped" : owned ? "Owned, tap to equip"
                                                          : "Costs \(palette.cost) credits")
        .accessibilityAddTraits(equipped ? [.isButton, .isSelected] : .isButton)
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

// MARK: - Onboarding (3 practice levels)

/// Hands-on first-time experience: three slow, no-fail practice levels that teach the
/// fundamentals one theme at a time (decode + RAM + firewall → armored + cache + worm →
/// fever + power-up), each opened by a short level card. Runs on first boot and from
/// Settings ▸ How to Play. The meta-loop tour (CR/Cyberdeck/Cosmetics) is surfaced
/// separately after the first real run (see ONBOARDING_PROPOSAL.md, Acts 1.5–2).
///
/// Beat map: 0 decode · 1 ram · 2 firewall | 3 armored · 4 cache · 5 worm | 6 fever ·
/// 7 power-up | 8 outro. Beats 0/3/6 open with a level card.
struct OnboardingView: View {
    /// First-launch shows the starter-CR "payday"; a Settings revisit does not.
    var showPayday: Bool = true
    var starterCredits: Int = GameStore.starterCredits
    /// Called once when the payday screen appears (persists the one-time grant).
    var onPayday: () -> Void = {}
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = 0
    @State private var showCard = true          // level-intro card gating
    @State private var paydayStarted = false
    @State private var creditsShown = 0
    @State private var armoredBreached = false
    @State private var wrongFirewall = false
    @State private var shakeAnim: CGFloat = 0
    @State private var flashCell: Int? = nil
    @State private var wormCell = 4
    @State private var ram: Double = 0.5         // beat 1: the RAM-clock demo bar
    @State private var feverHits = 0             // beat 6: chain progress
    @State private var feverCell = 4
    @State private var feverOn = false           // beat 6: celebration latch
    @State private var powerLabel: String? = nil // beat 7

    private let centerCell = 4
    private let firewallCell = 0
    private let feverTarget = 4

    /// Drives the worm's hops (beat 5 only).
    private let hopTimer = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    private var level: Int { beat <= 2 ? 1 : beat <= 5 ? 2 : 3 }   // 1…3 (outro stays 3)
    private var isOutro: Bool { beat == 8 }

    private var prompt: String {
        switch beat {
        case 0: return "Tap the glowing daemon to decode it."
        case 1: return "Decoding refills your RAM — your clock. Tap to decode."
        case 2: return wrongFirewall ? "✕ Firewall! Never tap red. Hit the cyan daemon."
                                     : "Decode the cyan daemon — but NEVER the red firewall."
        case 3: return armoredBreached ? "Shell breached — tap again to crack it!"
                                       : "Armored daemons take two taps. Tap it."
        case 4: return "Gold data cache — a big bonus. Grab it!"
        case 5: return "The green worm hops — tap it wherever it lands."
        case 6: return feverOn ? "FEVER! Hazards clear and your score doubles."
                               : "Chain decodes to charge Fever — keep tapping!"
        case 7: return powerLabel ?? "Grab the white power-up pickup for a burst."
        default: return ""
        }
    }

    private func neighbours(of idx: Int) -> [Int] {
        let r = idx / 3, c = idx % 3
        var out: [Int] = []
        if r > 0 { out.append(idx - 3) }
        if r < 2 { out.append(idx + 3) }
        if c > 0 { out.append(idx - 1) }
        if c < 2 { out.append(idx + 1) }
        return out
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("TRAINING")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            // Level progress (3 dots).
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { i in
                    Capsule()
                        .fill(i <= level ? NeonTheme.cyan : Color.white.opacity(0.15))
                        .frame(width: i == level && !isOutro ? 22 : 9, height: 5)
                }
            }

            if isOutro {
                if showPayday { payday } else { outro }
            } else if showCard {
                levelCard
            } else {
                Text(prompt)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(wrongFirewall && beat == 2 ? NeonTheme.danger
                                     : feverOn ? NeonTheme.gold : NeonTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(height: 40)

                if beat == 1 { ramBar }
                if beat == 6 { comboMeter }

                grid

                Spacer(minLength: 0)
            }

            if !isOutro {
                TerminalButton(title: "SKIP", color: NeonTheme.magenta, action: onDone)
            }
        }
        .padding(24)
        .onReceive(hopTimer) { _ in
            guard beat == 5, !showCard, flashCell == nil else { return }
            if let dest = neighbours(of: wormCell).randomElement() {
                withAnimation(.easeOut(duration: 0.12)) { wormCell = dest }
            }
        }
    }

    // MARK: Level intro card

    private var levelCard: some View {
        let (icon, title, blurb): (String, String, String) = {
            switch level {
            case 1: return ("hand.tap.fill", "First Contact",
                            "Decode daemons, watch your RAM clock, and dodge the firewall.")
            case 2: return ("square.grid.3x3.fill", "Read the Grid",
                            "Armored shells, gold caches, and worms that hop.")
            default: return ("bolt.fill", "Overload",
                             "Chain a Fever, then grab a power-up.")
            }
        }()
        return VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 10)
            Text("LEVEL \(level)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim).tracking(3)
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.textPrimary)
            Text(blurb)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
            TerminalButton(title: "BEGIN", color: NeonTheme.cyan, wide: true) {
                AudioEngine.shared.play(.uiTap)
                withAnimation(.easeInOut(duration: 0.25)) { showCard = false }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: RAM-clock + combo demos

    private var ramBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("RAM").font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(ram > 0.5 ? NeonTheme.cyan : NeonTheme.gold)
                        .frame(width: max(0, geo.size.width * ram))
                        .neonGlow(ram > 0.5 ? NeonTheme.cyan : NeonTheme.gold, radius: 5)
                        .animation(.easeOut(duration: 0.4), value: ram)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 4)
    }

    private var comboMeter: some View {
        HStack(spacing: 6) {
            ForEach(0..<feverTarget, id: \.self) { i in
                Capsule()
                    .fill(i < feverHits ? NeonTheme.gold : Color.white.opacity(0.15))
                    .frame(height: 6)
                    .neonGlow(i < feverHits ? NeonTheme.gold : .clear, radius: 3)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Grid

    private var grid: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let spacing: CGFloat = 10
            let cell = (side - spacing * 2) / 3
            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            cellView(idx, size: cell)
                                .contentShape(Rectangle())
                                .onTapGesture { handle(idx) }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(ShakeEffect(animatableData: shakeAnim))
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: 320)
    }

    private func cellView(_ idx: Int, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02)))
            node(idx).padding(size * 0.16)
            if flashCell == idx {
                RoundedRectangle(cornerRadius: 12).fill(.white).opacity(0.85).padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private func node(_ idx: Int) -> some View {
        // Fever celebration: the board lights up golden (brief §10.2 look).
        if feverOn && beat == 6 {
            if idx == feverCell || idx == 0 || idx == 8 {
                sprite(NeonTheme.gold, "bolt.fill", ringed: true)
            }
        } else {
            switch beat {
            case 0 where idx == centerCell, 1 where idx == centerCell:
                sprite(NeonTheme.cyan, "circle.grid.cross.fill")
            case 2 where idx == centerCell:
                sprite(NeonTheme.cyan, "circle.grid.cross.fill")
            case 2 where idx == firewallCell:
                sprite(NeonTheme.danger, "exclamationmark.triangle.fill")
            case 3 where idx == centerCell:
                sprite(armoredBreached ? NeonTheme.gold : NeonTheme.magenta,
                       armoredBreached ? "lock.open.fill" : "lock.shield.fill", ringed: !armoredBreached)
            case 4 where idx == centerCell:
                sprite(NeonTheme.gold, "square.stack.3d.up.fill", ringed: true)
            case 5 where idx == wormCell:
                sprite(NeonTheme.worm, "scribble.variable", ringed: true)
            case 6 where idx == feverCell:
                sprite(NeonTheme.cyan, "circle.grid.cross.fill")
            case 7 where idx == centerCell:
                sprite(NeonTheme.textPrimary, "snowflake", ringed: true)
            default:
                EmptyView()
            }
        }
    }

    private func sprite(_ color: Color, _ symbol: String, ringed: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ringed ? 3 : 2).neonGlow(color, radius: 8)
            Image(systemName: symbol).font(.system(size: 22, weight: .bold))
                .foregroundStyle(color).neonGlow(color, radius: 4)
        }
    }

    // MARK: Input

    private func handle(_ idx: Int) {
        guard flashCell == nil, !showCard, !feverOn else { return }
        switch beat {
        case 0 where idx == centerCell:
            decode(idx, .decode) { advance() }
        case 1 where idx == centerCell:
            ram = min(1, ram + 0.35)            // decoding tops up the RAM clock
            decode(idx, .decode) { advance() }
        case 2 where idx == firewallCell:
            wrongFirewall = true
            AudioEngine.shared.play(.bomb)
            shakeAnim = 0
            withAnimation(.easeOut(duration: 0.4)) { shakeAnim = 1 }
        case 2 where idx == centerCell:
            decode(idx, .decode) { advance() }
        case 3 where idx == centerCell:
            if !armoredBreached { armoredBreached = true; AudioEngine.shared.play(.breach) }
            else { decode(idx, .decodeBig) { armoredBreached = false; advance() } }
        case 4 where idx == centerCell:
            decode(idx, .decodeBig) { advance() }
        case 5 where idx == wormCell:
            decode(idx, .decodeWorm) { advance() }
        case 6 where idx == feverCell:
            feverHits += 1
            if feverHits >= feverTarget {
                decode(idx, .decode) {
                    AudioEngine.shared.play(.fever)
                    withAnimation(.easeInOut(duration: 0.3)) { feverOn = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { advance() }
                }
            } else {
                decode(idx, .decode) {
                    if let dest = neighbours(of: feverCell).randomElement() { feverCell = dest }
                }
            }
        case 7 where idx == centerCell:
            AudioEngine.shared.play(.fever)
            withAnimation(.easeInOut(duration: 0.2)) { powerLabel = "❄ FREEZE — the clock pauses!" }
            flashCell = idx
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                flashCell = nil; advance()
            }
        default:
            break
        }
    }

    /// Advance to the next beat; re-show the level card when a new level starts.
    private func advance() {
        beat += 1
        if beat == 3 || beat == 6 { showCard = true }
    }

    private func decode(_ idx: Int, _ sfx: AudioEngine.SFX, then: @escaping () -> Void) {
        AudioEngine.shared.play(sfx)
        flashCell = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            flashCell = nil
            withAnimation(.easeInOut(duration: 0.2)) { then() }
        }
    }

    // MARK: Outro

    private var outro: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(NeonTheme.gold)
                .neonGlow(NeonTheme.gold, radius: 12)
            Text("TRAINING COMPLETE")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)
            Text("You're ready to jack in. Every run banks CR to spend in the Cyberdeck and on Cosmetics — keep playing to grow your netrunner.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
            TerminalButton(title: "JACK IN", color: NeonTheme.cyan, wide: true, action: onDone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Act 1.5 — Payday: reveal the one-time starter CR with a count-up + chime, so the
    /// shops are concrete from the first menu visit.
    private var payday: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NeonTheme.gold)
                .neonGlow(NeonTheme.gold, radius: 12)
            Text("TRAINING COMPLETE")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)
            VStack(spacing: 4) {
                Text("STARTER FUNDS LOADED")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim).tracking(2)
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 24, weight: .bold)).foregroundStyle(NeonTheme.gold)
                    Text("\(creditsShown) CR")
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 22)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NeonTheme.gold.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NeonTheme.gold.opacity(0.5), lineWidth: 1)))
            Text("Every run banks more. Spend CR in the Cyberdeck on upgrades, and on Cosmetics to recolor the grid.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
            TerminalButton(title: "JACK IN", color: NeonTheme.cyan, wide: true, action: onDone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: startPayday)
    }

    private func startPayday() {
        guard !paydayStarted else { return }
        paydayStarted = true
        onPayday()                                   // persist the one-time grant
        AudioEngine.shared.play(.purchase)
        guard !reduceMotion else { creditsShown = starterCredits; return }
        Task { @MainActor in
            let steps = 16
            for i in 1...steps {
                withAnimation(.easeOut(duration: 0.05)) {
                    creditsShown = Int((Double(starterCredits) * Double(i) / Double(steps)).rounded())
                }
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            creditsShown = starterCredits
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.id), \(core.name)")
        .accessibilityValue(cleared ? "Cleared. Target \(core.targetScore), \(Int(core.timeBudget)) seconds. Tap to replay."
                            : unlocked ? "Target \(core.targetScore), \(Int(core.timeBudget)) seconds. Tap to play."
                                       : "Locked. Clear the previous core to unlock.")
        .accessibilityAddTraits(cleared ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - High scores

struct HighScoresView: View {
    let scores: [HighScoreEntry]
    var dailyBest: Int = 0
    var campaignProgress: Int = 0
    var campaignTotal: Int = 0
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("TOP RUNS")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            // Cross-mode stats.
            HStack(spacing: 10) {
                statBox("DAILY BEST", dailyBest > 0 ? "\(dailyBest)" : "—", NeonTheme.magenta)
                statBox("CAMPAIGN", "\(campaignProgress)/\(campaignTotal)", NeonTheme.gold)
            }

            Text("ENDLESS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim).tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Rank \(idx + 1), \(entry.score) points")
                        .accessibilityValue(Text(entry.date, format: .dateTime.day().month().hour().minute()))
                    }
                }
                Spacer()
            }

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }

    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(NeonTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - Settings / About

/// Preferences (sound, haptics), accessibility status, help, a guarded progress
/// reset, and an about/version block. Preferences persist via `GameStore`; the
/// reset wipes gameplay progress but keeps your preferences (see `resetProgress`).
struct SettingsView: View {
    @Bindable var store: GameStore
    let onTutorial: () -> Void
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingReset = false

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? "—"
        return "v\(v) (build \(b))"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 22) {
                    Text("SETTINGS")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.cyan)
                        .neonGlow(NeonTheme.cyan, radius: 8)

                    section("SYSTEM") {
                        SettingToggleRow(label: "SOUND",
                                         systemImage: store.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                         isOn: store.soundEnabled) {
                            let on = !store.soundEnabled
                            store.setSoundEnabled(on)
                            AudioEngine.shared.enabled = on
                            if on { AudioEngine.shared.play(.uiTap) }
                        }
                        SettingSliderRow(label: "MUSIC", systemImage: "music.note",
                                         value: store.musicVolume) { v in
                            store.setMusicVolume(v); AudioEngine.shared.musicVolume = v
                        }
                        SettingSliderRow(label: "EFFECTS", systemImage: "waveform",
                                         value: store.sfxVolume,
                                         onCommit: { AudioEngine.shared.play(.decode) }) { v in
                            store.setSfxVolume(v); AudioEngine.shared.sfxVolume = v
                        }
                        SettingToggleRow(label: "HAPTICS",
                                         systemImage: "iphone.radiowaves.left.and.right",
                                         isOn: store.hapticsEnabled) {
                            let on = !store.hapticsEnabled
                            store.setHapticsEnabled(on)
                            Haptics.enabled = on
                            if on { Haptics().impact(.light) }
                        }
                    }

                    section("ACCESSIBILITY") {
                        SettingInfoRow(label: "REDUCE MOTION",
                                       value: reduceMotion ? "ON" : "OFF",
                                       note: "follows iOS")
                    }

                    section("HELP") {
                        SettingActionRow(label: "HOW TO PLAY", systemImage: "graduationcap",
                                         color: NeonTheme.cyan, action: onTutorial)
                    }

                    section("DATA") {
                        SettingActionRow(label: "RESET PROGRESS", systemImage: "trash",
                                         color: NeonTheme.danger) { confirmingReset = true }
                    }

                    VStack(spacing: 4) {
                        Text("GRID_BREAKER")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundStyle(NeonTheme.magenta)
                            .neonGlow(NeonTheme.magenta, radius: 5)
                        Text(versionLine)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(NeonTheme.textDim)
                        Text("// netrunner reflex hack")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(NeonTheme.textDim)
                    }
                    .padding(.top, 8)

                    TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
                }
                .padding(24)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }

            if confirmingReset {
                ConfirmDialog(title: "RESET PROGRESS",
                              message: "Wipe all Credits, upgrades,\nhigh scores, cosmetics and\ncampaign progress?",
                              confirmLabel: "RESET",
                              confirmColor: NeonTheme.danger,
                              onConfirm: {
                                  store.resetProgress()
                                  // Re-apply cosmetics defaults globally (they were just wiped).
                                  NeonTheme.current = Palettes.byID(store.equippedPaletteID)
                                  TrailSkins.equipped = TrailSkins.byID(store.equippedTrailID)
                                  confirmingReset = false
                              },
                              onCancel: { confirmingReset = false })
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .tracking(2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shared neon background for a settings row.
private struct SettingRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1))
    }
}

/// A labelled ON/OFF preference toggle (tap to flip).
private struct SettingToggleRow: View {
    let label: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isOn ? NeonTheme.cyan : NeonTheme.textDim)
                    .frame(width: 46)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(isOn ? NeonTheme.cyan : NeonTheme.gridLineDim, lineWidth: 1.5))
                    .neonGlow(isOn ? NeonTheme.cyan : .clear, radius: isOn ? 5 : 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(SettingRowBackground())
        }
        .buttonStyle(TerminalButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double tap to turn \(isOn ? "off" : "on")")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A labelled 0–100% volume slider. Applies live via `onChange`; `onCommit` fires
/// when the drag ends (used to preview the new SFX level).
private struct SettingSliderRow: View {
    let label: String
    let systemImage: String
    var onCommit: (() -> Void)? = nil
    let onChange: (Double) -> Void
    @State private var live: Double

    init(label: String, systemImage: String, value: Double,
         onCommit: (() -> Void)? = nil, onChange: @escaping (Double) -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.onCommit = onCommit
        self.onChange = onChange
        _live = State(initialValue: value)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                Text("\(Int((live * 100).rounded()))%")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .frame(width: 52, alignment: .trailing)
            }
            Slider(value: $live, in: 0...1) { editing in if !editing { onCommit?() } }
                .tint(NeonTheme.cyan)
                .onChange(of: live) { _, v in onChange(v) }
                .accessibilityLabel("\(label) volume")
                .accessibilityValue("\(Int((live * 100).rounded())) percent")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(SettingRowBackground())
    }
}

/// A read-only status row (e.g. an OS-driven setting we only reflect).
private struct SettingInfoRow: View {
    let label: String
    let value: String
    let note: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.textPrimary)
            Spacer()
            Text(note)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(SettingRowBackground())
    }
}

/// A tappable action row (launches a flow / triggers a guarded action).
private struct SettingActionRow: View {
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(NeonTheme.textDim)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(SettingRowBackground())
        }
        .buttonStyle(TerminalButtonStyle())
        .accessibilityLabel(label)
    }
}
