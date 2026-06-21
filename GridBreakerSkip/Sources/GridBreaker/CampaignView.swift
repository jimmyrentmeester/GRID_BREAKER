import SwiftUI

/// Campaign level-select (ported from iOS): the 10 data cores, locked/cleared states.
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
                                best: store.bestScore(for: core),
                                action: { if store.isUnlocked(core) { onPlay(core) } })
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)   // bounded viewport so the ScrollView scrolls (#46)

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }
}

private struct CoreRow: View {
    let core: DataCore
    let cleared: Bool
    let unlocked: Bool
    var best: Int = 0
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
                        Image(systemName: sfSym("checkmark")).font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
                    } else if unlocked {
                        Text("\(core.id)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    } else {
                        Image(systemName: sfSym("lock.fill")).font(.system(size: 12)).foregroundStyle(accent)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(core.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(unlocked ? NeonTheme.textPrimary : NeonTheme.textDim)
                    Text("TARGET \(core.targetScore)  ·  \(Int(core.timeBudget))s"
                         + (best > 0 ? "  ·  BEST \(best)" : ""))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
                Spacer()
                if unlocked && !cleared {
                    Image(systemName: sfSym("play.fill")).foregroundStyle(NeonTheme.cyan)
                } else if cleared {
                    Image(systemName: sfSym("arrow.clockwise")).font(.system(size: 12)).foregroundStyle(NeonTheme.textDim)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(unlocked ? 0.04 : 0.015))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}
