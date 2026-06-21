import SwiftUI

/// Cosmetics shop — neon palettes (recolor the whole game) + tap-trail skins (ported
/// from iOS). Palettes apply live via NeonTheme.current. NOTE: the in-game tap trail
/// itself is Canvas-based and not rendered on Android (SkipUI has no Canvas) — the shop
/// still lets you own/equip trails for cross-platform save parity.
struct CosmeticsView: View {
    @Bindable var store: GameStore
    let onBack: () -> Void
    @State private var pending: Palette? = nil
    @State private var pendingTrail: TrailSkin? = nil
    @State private var bought: String? = nil

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
                    Label("\(store.cyberdeck.credits) CR", systemImage: sfSym("bitcoinsign.circle.fill"))
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
                .frame(maxHeight: .infinity)

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

    private func tapped(_ palette: Palette) {
        if store.ownsPalette(palette.id) { equip(palette) }
        else if store.cyberdeck.credits >= palette.cost { pending = palette }
    }
    private func equip(_ palette: Palette) {
        NeonTheme.current = palette
        store.equipPalette(palette.id)
    }
    private func purchaseAndEquip(_ palette: Palette) {
        guard store.buyPalette(id: palette.id, cost: palette.cost) else { return }
        equip(palette)
        celebratePurchase($bought, "\(palette.name) palette")
    }

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
                    Image(systemName: sfSym("checkmark.circle.fill")).foregroundStyle(skin.color())
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
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke((equipped ? skin.color() : NeonTheme.gridLineDim).opacity(equipped ? 0.9 : 0.4),
                            lineWidth: equipped ? 1.5 : 1.0)))
        }
        .buttonStyle(.plain)
        .disabled(equipped || (!owned && !affordable))
    }

    // Canvas-free preview: 3 nodes in the skin's dot shape + color (the live Canvas trail
    // isn't rendered on Android, so this is an approximation for the shop).
    private var trailPreview: some View {
        Group {
            if skin.isOff {
                Image(systemName: sfSym("nosign"))
                    .font(.system(size: 18))
                    .foregroundStyle(NeonTheme.textDim)
            } else {
                HStack(spacing: 5) {
                    dot(0.5); dot(0.78); dot(1.0)
                }
            }
        }
        .frame(width: 58, height: 34, alignment: .center)
    }

    @ViewBuilder private func dot(_ fade: CGFloat) -> some View {
        let c = skin.color().opacity(0.9 * Double(fade))
        let s = max(7.0, skin.size * (0.7 + 0.3 * fade))
        // Fill inline per shape: `.fill` is a Shape method, not available on `some View`.
        switch skin.dot {
        case .square:
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(c)
                .frame(width: s, height: s).neonGlow(skin.color(), radius: 3)
        case .diamond:
            DiamondShape().fill(c)
                .frame(width: s, height: s).neonGlow(skin.color(), radius: 3)
        default:
            Circle().fill(c)
                .frame(width: s, height: s).neonGlow(skin.color(), radius: 3)
        }
    }
}

/// Diamond for the diamond-dot trail preview (Canvas-free).
private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
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
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke((equipped ? palette.primary : NeonTheme.gridLineDim).opacity(equipped ? 0.9 : 0.4),
                                lineWidth: equipped ? 1.5 : 1.0))
            )
        }
        .buttonStyle(.plain)
        .disabled(equipped || (!owned && !affordable))
    }

    @ViewBuilder private var trailing: some View {
        if equipped {
            Image(systemName: sfSym("checkmark.circle.fill")).foregroundStyle(palette.primary)
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
