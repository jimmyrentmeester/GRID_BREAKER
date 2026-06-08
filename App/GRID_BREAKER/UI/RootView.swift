import SwiftUI

/// Top-level menu hub. Owns the persistent `GameStore` and routes between the
/// title, a session, the Cyberdeck upgrade screen and the high-score table
/// (ground-truth Part 1.5: always a clear way to begin, never an empty opening).
struct RootView: View {
    @State private var store = GameStore()
    @State private var screen: Screen = .menu
    @State private var activeCore: DataCore?
    @State private var pulse = false
    @State private var onboardingPayday = true   // first-launch onboarding pays out CR
    @State private var guidedTour: GuidedStep = .none   // meta-loop guided shop tour

    private enum Screen { case menu, endless, daily, flow, campaign, core, cyberdeck, cosmetics, scores, tutorial, metaIntro, settings }
    /// The guided onboarding tour through the shops (Phase C): buy → equip → done.
    private enum GuidedStep { case none, cyberdeck, cosmetics }

    private func tap() { AudioEngine.shared.play(.uiTap) }

    /// Today's deterministic daily challenge: a day key ("yyyy-MM-dd") shared by all
    /// players, and a seed derived from it (the engine's SplitMix64 mixes it well).
    private static func today() -> (key: String, seed: UInt64) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        return (String(format: "%04d-%02d-%02d", y, m, d), UInt64(y * 10000 + m * 100 + d))
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea().accessibilityHidden(true)

            switch screen {
            case .menu:
                titleScreen.transition(.opacity)
            case .endless:
                GameView(deck: store.cyberdeck,
                         onExit: { screen = .menu },
                         recordSession: { score, _ in
                             let isHigh = store.isHighScore(score)
                             let earned = store.recordSession(score: score, on: Date())
                             return SessionOutcome(creditsEarned: earned, isHighScore: isHigh)
                         })
                    .transition(.opacity)
            case .daily:
                // Daily challenge — endless rules on today's shared seed; its own best.
                let today = Self.today()
                GameView(deck: store.cyberdeck, seed: today.seed, daily: true,
                         onExit: { screen = .menu },
                         recordSession: { score, _ in store.recordDaily(score: score, day: today.key) })
                    .transition(.opacity)
            case .flow:
                // Chill mode — no clock, no fail, no economy; just play and leave.
                GameView(deck: store.cyberdeck, chill: true,
                         onExit: { screen = .menu },
                         recordSession: { _, _ in SessionOutcome(creditsEarned: 0, isHighScore: false) })
                    .transition(.opacity)
            case .campaign:
                CampaignView(store: store,
                             onPlay: { core in activeCore = core; screen = .core },
                             onBack: { screen = .menu })
                    .transition(.opacity)
            case .core:
                if let core = activeCore {
                    GameView(core: core, deck: store.cyberdeck,
                             briefing: store.isCleared(core) ? nil : core.briefing,
                             onExit: { screen = .campaign },
                             onNext: Campaign.core(id: core.id + 1).map { next in { activeCore = next } },
                             recordSession: { score, won in
                                 let earned = store.recordCore(core, won: won, score: score, on: Date())
                                 return SessionOutcome(creditsEarned: earned, isHighScore: false)
                             })
                        .id(core.id)          // fresh session when advancing cores
                        .transition(.opacity)
                }
            case .cyberdeck:
                CyberdeckView(store: store,
                              guided: guidedTour == .cyberdeck,
                              onGuidedDone: { guidedTour = .cosmetics; screen = .cosmetics },
                              onBack: { guidedTour = .none; screen = .menu }).transition(.opacity)
            case .cosmetics:
                CosmeticsView(store: store,
                              guided: guidedTour == .cosmetics,
                              onGuidedDone: { guidedTour = .none; screen = .menu },
                              onBack: { guidedTour = .none; screen = .menu }).transition(.opacity)
            case .scores:
                HighScoresView(scores: store.highScores,
                               dailyBest: store.dailyBest(forDay: Self.today().key),
                               campaignProgress: store.campaignProgress,
                               campaignTotal: Campaign.count,
                               onBack: { screen = .menu }).transition(.opacity)
            case .tutorial:
                OnboardingView(showPayday: onboardingPayday,
                               onPayday: { store.grantStarterCredits() },
                               onDone: { store.markTutorialSeen(); screen = .metaIntro })
                    .transition(.opacity)
            case .metaIntro:
                // Final onboarding step: introduce the meta-loop, then guide the first
                // Cyberdeck buy + Cosmetics equip. Reached right after training (CR in hand).
                MetaIntroCard(
                    credits: store.cyberdeck.credits,
                    onOpenCyberdeck: { tap(); guidedTour = .cyberdeck; screen = .cyberdeck },
                    onOpenCosmetics: { tap(); guidedTour = .cosmetics; screen = .cosmetics },
                    onLater: { tap(); screen = .menu }
                ).transition(.opacity)
            case .settings:
                SettingsView(store: store,
                             onTutorial: { tap(); onboardingPayday = false; screen = .tutorial },
                             onBack: { screen = .menu }).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            NeonTheme.current = Palettes.byID(store.equippedPaletteID)   // apply cosmetics
            TrailSkins.equipped = TrailSkins.byID(store.equippedTrailID)
            Haptics.enabled = store.hapticsEnabled
            AudioEngine.shared.musicVolume = store.musicVolume
            AudioEngine.shared.sfxVolume = store.sfxVolume
            AudioEngine.shared.enabled = store.soundEnabled
            AudioEngine.shared.start()
            if !store.tutorialSeen { onboardingPayday = true; screen = .tutorial }   // first-launch onboarding
        }
    }

    private var titleScreen: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("GRID_BREAKER")
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: pulse ? 16 : 9)
                Text("// netrunner reflex hack")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.magenta)
                    .neonGlow(NeonTheme.magenta, radius: 5)
            }

            // Stat chips (at-a-glance progress).
            HStack(spacing: 10) {
                if let best = store.highScores.first { statChip("BEST", "\(best.score)", NeonTheme.cyan) }
                let db = store.dailyBest(forDay: Self.today().key)
                if db > 0 { statChip("DAILY", "\(db)", NeonTheme.magenta) }
                statChip("CREDITS", "\(store.cyberdeck.credits)", NeonTheme.gold)
            }

            // Primary call-to-action.
            Button { tap(); screen = .endless } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill").font(.system(size: 17, weight: .bold))
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
            .buttonStyle(TerminalButtonStyle())

            // Play modes.
            VStack(spacing: 8) {
                sectionLabel("MODES")
                HStack(spacing: 10) {
                    MenuTile(label: "CAMPAIGN", systemImage: "flag.fill", color: NeonTheme.cyan) { tap(); screen = .campaign }
                    MenuTile(label: "FLOW", systemImage: "infinity", color: NeonTheme.cyan) { tap(); screen = .flow }
                    MenuTile(label: "DAILY", systemImage: "calendar", color: NeonTheme.cyan) { tap(); screen = .daily }
                }
            }

            // Spend Credits.
            VStack(spacing: 8) {
                sectionLabel("TERMINAL")
                HStack(spacing: 10) {
                    MenuTile(label: "CYBERDECK", systemImage: "cpu.fill", color: NeonTheme.gold) { tap(); screen = .cyberdeck }
                    MenuTile(label: "COSMETICS", systemImage: "paintpalette.fill", color: NeonTheme.gold) { tap(); screen = .cosmetics }
                }
            }

            // Utility.
            HStack(spacing: 32) {
                utilityButton("TOP RUNS", "trophy.fill") { tap(); screen = .scores }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func utilityButton(_ label: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .bold))
                Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(NeonTheme.textDim)
            .frame(minWidth: 72, minHeight: 44)   // ≥44pt tap target (Apple HIG)
            .contentShape(Rectangle())
        }
        .buttonStyle(TerminalButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

/// A play-mode / shop tile: icon over a short label, color-coded by group.
private struct MenuTile: View {
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage).font(.system(size: 20, weight: .bold))
                Text(label).font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.7), lineWidth: 1.5)))
            .neonGlow(color, radius: 3)
        }
        .buttonStyle(TerminalButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

/// The final onboarding step: introduce the earn → spend → customize loop now that the
/// player has CR, then route into the guided Cyberdeck buy + Cosmetics equip. A full
/// (opaque) screen — the app background + grid backdrop sit behind it, nothing bleeds
/// through. "Later" drops to the menu.
private struct MetaIntroCard: View {
    let credits: Int
    let onOpenCyberdeck: () -> Void
    let onOpenCosmetics: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(NeonTheme.gold)
                .neonGlow(NeonTheme.gold, radius: 12)
            Text("YOU'RE BANKING CR")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)
            Text("You've got \(credits) CR. Spend it in the Cyberdeck on permanent upgrades, or on Cosmetics to recolor the grid. Want a look?")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            VStack(spacing: 12) {
                TerminalButton(title: "OPEN CYBERDECK", color: NeonTheme.gold, wide: true, action: onOpenCyberdeck)
                TerminalButton(title: "COSMETICS", color: NeonTheme.cyan, wide: true, action: onOpenCosmetics)
                TerminalButton(title: "LATER", color: NeonTheme.magenta, wide: true, action: onLater)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Static cyan/purple terminal grid behind the UI (decorative).
private struct GridBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let step: CGFloat = 44
            Path { p in
                var x: CGFloat = 0
                while x <= geo.size.width { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: geo.size.height)); x += step }
                var y: CGFloat = 0
                while y <= geo.size.height { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: geo.size.width, y: y)); y += step }
            }
            .stroke(NeonTheme.gridLineDim.opacity(0.18), lineWidth: 1)
        }
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
