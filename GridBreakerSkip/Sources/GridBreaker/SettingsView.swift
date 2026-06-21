import SwiftUI

/// Preferences (sound, music/sfx volume, haptics), accessibility status, help links,
/// a guarded progress reset, and an about block (ported from iOS).
struct SettingsView: View {
    @Bindable var store: GameStore
    var onCodex: () -> Void = {}
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingReset = false

    private var versionLine: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
        return "v\(v)"
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
                        }
                    }

                    section("ACCESSIBILITY") {
                        SettingInfoRow(label: "REDUCE MOTION",
                                       value: reduceMotion ? "ON" : "OFF",
                                       note: "follows OS")
                    }

                    section("HELP") {
                        SettingActionRow(label: "CODEX — RULES & TARGETS", systemImage: "book.closed.fill",
                                         color: NeonTheme.cyan, action: onCodex)
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
            }
            .frame(maxHeight: .infinity)

            if confirmingReset {
                ConfirmDialog(title: "RESET PROGRESS",
                              message: "Wipe all Credits, upgrades,\nhigh scores, cosmetics and\ncampaign progress?",
                              confirmLabel: "RESET",
                              confirmColor: NeonTheme.danger,
                              onConfirm: {
                                  store.resetProgress()
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

private struct SettingRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1))
    }
}

private struct SettingToggleRow: View {
    let label: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: sfSym(systemImage))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isOn ? NeonTheme.cyan : NeonTheme.textDim)
                    .frame(width: 46)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(isOn ? NeonTheme.cyan : NeonTheme.gridLineDim, lineWidth: 1.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(SettingRowBackground())
        }
        .buttonStyle(.plain)
    }
}

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
                Label(label, systemImage: sfSym(systemImage))
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

private struct SettingActionRow: View {
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: sfSym(systemImage))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: sfSym("chevron.right"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(NeonTheme.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(SettingRowBackground())
        }
        .buttonStyle(.plain)
    }
}
