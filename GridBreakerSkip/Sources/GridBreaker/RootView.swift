import SwiftUI

/// Top-level menu hub + router — ported from the iOS RootView for parity. Owns the
/// persistent GameStore and routes between the menu, a session, and the chrome screens.
struct RootView: View {
    @State private var store = GameStore()
    @State private var screen: Screen = .menu
    @State private var activeCore: DataCore? = nil
    @State private var pulse = false

    enum Screen { case menu, endless, daily, protocolMode, campaign, core, cyberdeck, cosmetics, scores, codex, settings }

    private func tap() { AudioEngine.shared.play(.uiTap) }

    /// Fresh seed for endless/protocol (Date-based; deterministic replays use a fixed seed).
    private func freshSeed() -> UInt64 { UInt64(Date().timeIntervalSince1970 * 1000.0) }

    /// Today's deterministic daily: a day key + a seed derived from it.
    private static func today() -> (key: String, seed: UInt64) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        return (String(format: "%04d-%02d-%02d", y, m, d), UInt64(y * 10000 + m * 100 + d))
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()

            switch screen {
            case .menu:
                titleScreen.playColumn()
            case .endless:
                GameView(config: GameConfig.endless(), seed: freshSeed(), modeLabel: "ENDLESS",
                         onExit: { recordAndExit() })
            case .daily:
                GameView(config: GameConfig.endless(), seed: Self.today().seed, modeLabel: "DAILY",
                         onExit: { recordAndExit() })
            case .protocolMode:
                GameView(config: GameConfig.protocolMode(), seed: freshSeed(), modeLabel: "PROTOCOL",
                         onExit: { recordAndExit() })
            case .core:
                if let core = activeCore {
                    GameView(config: GameConfig.campaign(for: core), seed: freshSeed(),
                             targetScore: core.targetScore, difficultyBias: core.difficultyBias,
                             modeLabel: core.name.uppercased(), onExit: { screen = .campaign })
                } else { placeholder("CAMPAIGN") { screen = .menu } }
            case .campaign:
                CampaignView(store: store,
                             onPlay: { core in activeCore = core; tap(); screen = .core },
                             onBack: { tap(); screen = .menu }).playColumn()
            case .cyberdeck:
                CyberdeckView(store: store, onBack: { tap(); screen = .menu }).playColumn()
            case .cosmetics:
                CosmeticsView(store: store, onBack: { tap(); screen = .menu }).playColumn()
            case .scores:
                HighScoresView(scores: store.highScores,
                               dailyBest: store.dailyBest(forDay: Self.today().key),
                               campaignProgress: store.campaignProgress,
                               campaignTotal: Campaign.count,
                               onBack: { tap(); screen = .menu }).playColumn()
            case .codex:
                CodexView(onBack: { tap(); screen = .menu }).playColumn()
            case .settings:
                SettingsView(store: store,
                             onCodex: { tap(); screen = .codex },
                             onBack: { tap(); screen = .menu }).playColumn()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            NeonTheme.current = Palettes.byID(store.equippedPaletteID)
            TrailSkins.equipped = TrailSkins.byID(store.equippedTrailID)
            Haptics.enabled = store.hapticsEnabled
            AudioEngine.shared.enabled = store.soundEnabled
            AudioEngine.shared.start()
            if !store.starterCreditsGranted {
                _ = store.grantStarterCredits()
                store.markTutorialSeen()
            }
        }
    }

    /// Returning to the menu from a run (score recording happens inside GameView's record
    /// callback in the full port; for now we just route back — local scores via GameStore later).
    private func recordAndExit() { tap(); screen = .menu }

    // MARK: - Menu hub (ported from iOS titleScreen)

    private var titleScreen: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("GRID_BREAKER")
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: pulse ? 16.0 : 9.0)
                Text("// netrunner reflex hack")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.magenta)
                    .neonGlow(NeonTheme.magenta, radius: 5)
            }

            HStack(spacing: 10) {
                if let best = store.highScores.first { statChip("BEST", "\(best.score)", NeonTheme.cyan) }
                let db = store.dailyBest(forDay: Self.today().key)
                if db > 0 { statChip("DAILY", "\(db)", NeonTheme.magenta) }
                statChip("CREDITS", "\(store.cyberdeck.credits)", NeonTheme.gold)
            }

            Button { tap(); screen = .endless } label: {
                HStack(spacing: 12) {
                    Image(systemName: sfSym("play.fill")).font(.system(size: 17, weight: .bold))
                    Text("JACK IN").font(.system(size: 20, weight: .heavy, design: .monospaced))
                    Spacer()
                    Text("ENDLESS").font(.system(size: 11, weight: .semibold, design: .monospaced)).opacity(0.65)
                }
                .foregroundStyle(NeonTheme.cyan)
                .padding(.horizontal, 20).padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(NeonTheme.cyan.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(NeonTheme.cyan, lineWidth: 2)))
                .neonGlow(NeonTheme.cyan, radius: 8)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                sectionLabel("MODES")
                HStack(spacing: 10) {
                    MenuTile(label: "CAMPAIGN", systemImage: "flag.fill", color: NeonTheme.cyan,
                             highlight: store.campaignProgress == 0) { tap(); screen = .campaign }
                    MenuTile(label: "PROTOCOL", systemImage: "scope", color: NeonTheme.cyan) { tap(); screen = .protocolMode }
                    MenuTile(label: "DAILY", systemImage: "calendar", color: NeonTheme.cyan) { tap(); screen = .daily }
                }
            }

            VStack(spacing: 8) {
                sectionLabel("TERMINAL")
                HStack(spacing: 10) {
                    MenuTile(label: "CYBERDECK", systemImage: "cpu.fill", color: NeonTheme.gold) { tap(); screen = .cyberdeck }
                    MenuTile(label: "COSMETICS", systemImage: "paintpalette.fill", color: NeonTheme.gold) { tap(); screen = .cosmetics }
                }
            }

            HStack(spacing: 22) {
                utilityButton("TOP RUNS", "trophy.fill") { tap(); screen = .scores }
                utilityButton("CODEX", "book.closed.fill") { tap(); screen = .codex }
                utilityButton("SETTINGS", "gearshape.fill") { tap(); screen = .settings }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(NeonTheme.textDim).tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .heavy, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(NeonTheme.textDim)
        }
        .frame(minWidth: 54)
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color.opacity(0.4), lineWidth: 1)))
    }

    private func utilityButton(_ label: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: sfSym(symbol)).font(.system(size: 18, weight: .bold))
                Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(NeonTheme.textDim)
            .frame(minWidth: 72, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    /// Temporary placeholder for chrome screens not yet ported (M4b/M4c).
    private func placeholder(_ title: String, onBack: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan).neonGlow(NeonTheme.cyan, radius: 8)
            Text("// porting in progress")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(NeonTheme.textDim)
            Button("◂ BACK") { tap(); onBack() }
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.magenta)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Capsule().stroke(NeonTheme.magenta, lineWidth: 1.5))
        }
        .playColumn()
    }
}

/// A play-mode / shop tile (ported from iOS): icon over a label, color-coded, with an
/// optional gold START HERE badge to steer a new player to Campaign.
private struct MenuTile: View {
    let label: String
    let systemImage: String
    let color: Color
    var highlight: Bool = false
    let action: () -> Void

    private var strokeColor: Color { highlight ? NeonTheme.gold : color.opacity(0.7) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: sfSym(systemImage)).font(.system(size: 20, weight: .bold))
                    .frame(height: 24)
                Text(label).font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(strokeColor, lineWidth: highlight ? 2.0 : 1.5)))
            .neonGlow(highlight ? NeonTheme.gold : color, radius: highlight ? 6.0 : 3.0)
            .overlay(alignment: .top) {
                if highlight {
                    Text("START HERE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(NeonTheme.gold))
                        .offset(y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        // Also fill on the Button itself (not just its label): in Skip a Button sizes to
        // content, so without this an HStack can give the first tile all the width and
        // squeeze its siblings to vertical slivers.
        .frame(maxWidth: .infinity)
    }
}

/// Static cyan/purple terminal grid behind the UI (decorative; Path-based, Skip-safe).
struct GridBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let step: CGFloat = 44
            Path { p in
                var x: CGFloat = 0
                while x <= geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += step }
                var y: CGFloat = 0
                while y <= geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += step }
            }
            .stroke(NeonTheme.gridLineDim.opacity(0.18), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// NOTE: the iOS `TerminalButtonStyle` (a custom `ButtonStyle` conformance for a press
// dip) can't port — in SkipUI `ButtonStyle` is a concrete RawRepresentable type, not a
// protocol you conform to. Buttons use `.buttonStyle(.plain)` instead (plain label, no
// Material chrome). The press-dip is dropped on Android.
