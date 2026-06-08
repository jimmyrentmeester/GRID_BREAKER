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

// MARK: - Interactive tutorial

/// Hands-on, teach-by-doing tutorial: decode a daemon, breach an armored one,
/// avoid a firewall, then a short recap. Runs on first boot and from the menu.
struct TutorialView: View {
    let onDone: () -> Void

    @State private var step = 0          // 0 decode · 1 armored · 2 firewall · 3 recap
    @State private var armoredBreached = false
    @State private var wrongFirewall = false
    @State private var shakeAnim: CGFloat = 0
    @State private var flashCell: Int? = nil

    private let centerCell = 4
    private let firewallCell = 0
    private let totalSteps = 4

    private var prompt: String {
        switch step {
        case 0: return "Tap the glowing daemon to decode it."
        case 1: return armoredBreached ? "Shell breached — tap again to crack it!"
                                       : "Armored daemons take two taps. Tap it."
        case 2: return wrongFirewall ? "✕ That's a firewall — never tap it. Hit the cyan daemon."
                                     : "Tap the cyan daemon — but NEVER the red firewall."
        default: return "You're in. A few last things:"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("TUTORIAL")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? NeonTheme.cyan : Color.white.opacity(0.15))
                        .frame(width: i == step ? 18 : 8, height: 5)
                }
            }

            Text(prompt)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(wrongFirewall && step == 2 ? NeonTheme.danger : NeonTheme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(height: 40)

            if step < 3 { grid } else { recap }

            Spacer(minLength: 0)

            TerminalButton(title: step < 3 ? "SKIP" : "START HACKING",
                           color: step < 3 ? NeonTheme.magenta : NeonTheme.cyan,
                           action: onDone)
        }
        .padding(24)
    }

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
        .frame(maxHeight: 340)
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
        switch step {
        case 0 where idx == centerCell:
            sprite(NeonTheme.cyan, "circle.grid.cross.fill")
        case 1 where idx == centerCell:
            sprite(armoredBreached ? NeonTheme.gold : NeonTheme.magenta,
                   armoredBreached ? "lock.open.fill" : "lock.shield.fill", ringed: !armoredBreached)
        case 2 where idx == centerCell:
            sprite(NeonTheme.cyan, "circle.grid.cross.fill")
        case 2 where idx == firewallCell:
            sprite(NeonTheme.danger, "exclamationmark.triangle.fill")
        default:
            EmptyView()
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

    private func handle(_ idx: Int) {
        guard flashCell == nil else { return }
        switch step {
        case 0 where idx == centerCell:
            decode(idx, .decode) { step = 1 }
        case 1 where idx == centerCell:
            if !armoredBreached { armoredBreached = true; AudioEngine.shared.play(.breach) }
            else { decode(idx, .decodeBig) { armoredBreached = false; step = 2 } }
        case 2 where idx == firewallCell:
            wrongFirewall = true
            AudioEngine.shared.play(.bomb)
            shakeAnim = 0
            withAnimation(.easeOut(duration: 0.4)) { shakeAnim = 1 }
        case 2 where idx == centerCell:
            decode(idx, .decode) { step = 3 }
        default:
            break
        }
    }

    private func decode(_ idx: Int, _ sfx: AudioEngine.SFX, then: @escaping () -> Void) {
        AudioEngine.shared.play(sfx)
        flashCell = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            flashCell = nil
            withAnimation(.easeInOut(duration: 0.2)) { then() }
        }
    }

    private var recap: some View {
        VStack(spacing: 10) {
            recapRow("memorychip.fill", NeonTheme.cyan, "RAM is your clock",
                     "It drains over time — decoding tops it up, misses cost time.")
            recapRow("bolt.fill", NeonTheme.gold, "Chain a Fever",
                     "String clean hits for Fever: hazards vanish, score ×2.")
            recapRow("sparkles", NeonTheme.textPrimary, "Grab power-ups",
                     "Tap a white pickup for a burst: ❄ Freeze, ⚡ Overclock (×2), 🌀 Purge bombs.")
            recapRow("bitcoinsign.circle.fill", NeonTheme.gold, "Spend Credits",
                     "Upgrade your Cyberdeck and buy neon palettes.")
        }
    }

    private func recapRow(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(color)
                .neonGlow(color, radius: 4).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                Text(text).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1)))
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
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(SettingRowBackground())
        }
        .buttonStyle(TerminalButtonStyle())
    }
}
