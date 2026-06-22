import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - View model (owns the engine, drives the frame loop)

/// Thin @MainActor bridge between the deterministic `GridEngine` (authority) and
/// SwiftUI. It advances the engine once per frame and republishes the snapshot;
/// it contains no game mechanics of its own (ground-truth Part 1.1 / 3.2).
@MainActor
@Observable
final class GameViewModel {
    private(set) var snapshot: SessionSnapshot
    /// Bumped whenever new visual effects are queued — the overlay drains on change.
    private(set) var effectSeq = 0
    /// Bumped to trigger a screen-shake (firewall hit).
    private(set) var shakeTrigger = 0
    /// The kind + a bump counter for the just-collected power-up (drives a flash).
    private(set) var powerUpFlashKind: PowerUpKind?
    private(set) var powerUpFlashSeq = 0
    /// Bumped when the grid expands 3×3 → 4×4 (drives a brief toast).
    private(set) var gridExpandedSeq = 0
    /// Bumped at a mid-streak milestone (drives a brief border pulse before Fever).
    private(set) var streakPulseSeq = 0
    /// Bumped on a negative event (mistap / daemon expiry) — drives a red screen-edge
    /// flash so a miss stays visible when the board is busy (issue #2).
    private(set) var errorFlashSeq = 0
    /// The just-reached score milestone + a bump counter (drives a landmark toast).
    private(set) var milestoneValue = 0
    private(set) var milestoneSeq = 0
    /// DAEMON SET toast (PROTOCOL): a short message + bump counter (spawn / cracked).
    private(set) var daemonSetMsg = ""
    private(set) var daemonSetSeq = 0
    /// Set by the view from the environment; gates motion-heavy juice.
    var reduceMotion = false
    /// Paused → the sim (and its RAM clock) is frozen until unpaused.
    private(set) var isPaused = false

    private var engine: GridEngine
    private let config: GameConfig
    private let deck: Cyberdeck
    private let gridSize: GridSize
    private let targetScore: Int?
    private let difficultyBias: Int
    private var lastDate: Date?
    private var freezeRemaining: TimeInterval = 0   // hit-stop budget
    /// Decode-chain length for audio: walks the decode arpeggio up; reset when the
    /// chain breaks (miss / expiry / bomb), mirroring the engine's combo.
    private var decodeRun = 0
    private var pendingEffects: [JuiceEffect] = []
    private let haptics = Haptics()
    private let audio = AudioEngine.shared

    init(config: GameConfig = .default,
         deck: Cyberdeck = .starter,
         gridSize: GridSize = .threeByThree,
         seed: UInt64,
         targetScore: Int? = nil,
         difficultyBias: Int = 0) {
        self.config = config
        self.deck = deck
        self.gridSize = gridSize
        self.targetScore = targetScore
        self.difficultyBias = difficultyBias
        let engine = GridEngine(config: config, deck: deck, gridSize: gridSize, seed: seed,
                                targetScore: targetScore, difficultyBias: difficultyBias)
        self.engine = engine
        self.snapshot = engine.snapshot
        haptics.prepare()
    }

    /// The overlay pulls queued effects (and clears them) on each `effectSeq` change.
    func drainEffects() -> [JuiceEffect] {
        let fx = pendingEffects
        pendingEffects.removeAll()
        return fx
    }

    func pause() { isPaused = true }
    func unpause() { isPaused = false; lastDate = nil }  // re-anchor so no time jumps

    /// Called every frame by the TimelineView with the current date.
    func advance(to date: Date) {
        guard !snapshot.isGameOver, !isPaused else { lastDate = date; return }
        defer { lastDate = date }
        guard let last = lastDate else { return }          // first frame: just anchor
        let dt = min(date.timeIntervalSince(last), 1.0 / 20.0)  // clamp big stalls
        guard dt > 0 else { return }
        if freezeRemaining > 0 { freezeRemaining -= dt; return }  // hit-stop: hold the sim
        process(engine.tick(deltaTime: dt))
        snapshot = engine.snapshot
    }

    func tap(cell: Int) {
        guard !snapshot.isGameOver, !isPaused else { return }
        process(engine.handleTap(cellIndex: cell))
        snapshot = engine.snapshot
    }

    func restart(seed: UInt64) {
        engine = GridEngine(config: config, deck: deck, gridSize: gridSize, seed: seed,
                            targetScore: targetScore, difficultyBias: difficultyBias)
        lastDate = nil
        freezeRemaining = 0
        decodeRun = 0
        pendingEffects.removeAll()
        snapshot = engine.snapshot
    }

    /// Translate deterministic engine events into presentation: effects, haptics,
    /// hit-stop and shake. The single place feel is wired to truth (skill §5).
    private func process(_ events: [GameEvent]) {
        guard !events.isEmpty else { return }
        var queued = false
        for event in events {
            switch event {
            case let .nodeDecoded(type, cell):
                // Streak "heat" 0…1: how deep into a clean-hit chain this decode is,
                // relative to the fever threshold. Drives haptic weight, burst density,
                // and the cyan→gold "heating up" pop color.
                let chain = decodeRun + 1
                let fever = snapshot.feverActive
                let threshold = snapshot.comboThreshold
                let heat = threshold > 0 ? min(1, Double(chain) / Double(threshold))
                                         : min(1, Double(chain) / 8)
                let points: Int
                let popColor: Color
                switch type {
                case .armoredDaemon: points = config.scoreArmored; popColor = NeonTheme.gold
                case .dataCache:     points = config.scoreCache;   popColor = NeonTheme.gold
                case .wormDaemon:    points = config.scoreWorm
                                     popColor = .blend(NeonTheme.worm, NeonTheme.gold, heat)
                default:             points = config.scoreStandard
                                     popColor = .blend(NeonTheme.cyan, NeonTheme.gold, heat)
                }
                pendingEffects.append(.init(cell: cell, style: .pop, color: popColor,
                                            points: points, intensity: heat))
                queued = true
                switch type {
                case .armoredDaemon:
                    haptics.impact(fever ? .rigid : .medium, intensity: fever ? 1.0 : 0.9)
                    audio.play(.decodeArmored)                    // rising "unlock!" above the breach
                    if !reduceMotion { freezeRemaining = 0.08 }   // hit-stop on the heavy kill
                case .dataCache:
                    haptics.impact(fever ? .rigid : .medium, intensity: fever ? 1.0 : 0.9)
                    audio.play(.decodeBig)                        // a weighty grab
                case .wormDaemon:
                    haptics.decodeStreak(chain, threshold: threshold, fever: fever)
                    audio.play(.decodeWorm)                       // its own squirming chirp
                default:                                          // standard daemon: nimble
                    haptics.decodeStreak(chain, threshold: threshold, fever: fever)
                    audio.play(.decode, step: decodeRun)
                }
                decodeRun += 1                                     // chain climbs the arpeggio
                // Mid-streak momentum pulse (before Fever owns the screen); skip the
                // exact fever-trigger hit so the pulse doesn't clash with the sting.
                if !fever && chain >= 4 && chain % 4 == 0 && chain != threshold {
                    streakPulseSeq += 1
                }
            case let .nodeBreached(cell):
                pendingEffects.append(.init(cell: cell, style: .breach, color: NeonTheme.magenta, points: nil))
                queued = true
                haptics.impact(.soft); audio.play(.breach)
            case let .emptyMiss(cell):
                decodeRun = 0
                pendingEffects.append(.init(cell: cell, style: .miss, color: NeonTheme.danger, points: nil))
                queued = true
                errorFlashSeq += 1
                haptics.impact(.rigid); audio.play(.miss)
            case let .nodeExpired(_, cell):
                decodeRun = 0
                pendingEffects.append(.init(cell: cell, style: .miss, color: NeonTheme.danger, points: nil))
                queued = true
                errorFlashSeq += 1
                haptics.impact(.rigid); audio.play(.miss)
            case let .missAbsorbed(cell):
                pendingEffects.append(.init(cell: cell, style: .shield, color: NeonTheme.gold, points: nil))
                queued = true
                haptics.impact(.soft); audio.play(.breach)
                GameCenterService.shared.report(.failsafe)
            case let .firewallDefused(cell):
                // Shield saved you — a bright gold "blocked" pop, no game over.
                pendingEffects.append(.init(cell: cell, style: .shield, color: NeonTheme.gold, points: nil))
                queued = true
                haptics.impact(.medium); audio.play(.decodeBig)
                GameCenterService.shared.report(.failsafe)
            case let .firewallExploded(cell):
                decodeRun = 0                  // chain broken → arpeggio resets
                pendingEffects.append(.init(cell: cell, style: .bomb, color: NeonTheme.danger, points: nil))
                queued = true
                if !reduceMotion { freezeRemaining = 0.06; shakeTrigger += 1 }
                haptics.error(); audio.play(.bomb)
            case .feverStarted:
                haptics.success(); audio.play(.fever)
                GameCenterService.shared.report(.firstFever)
            case .feverEnded:
                haptics.impact(.soft)
            case .ramCritical:
                haptics.impact(.rigid, intensity: 1.0)
                audio.play(.ramLow)
            case .gridExpanded:
                gridExpandedSeq += 1
                haptics.success(); audio.play(.fever)
                GameCenterService.shared.report(.gridExpanded)
            case let .powerUpCollected(kind):
                powerUpFlashKind = kind
                powerUpFlashSeq += 1
                haptics.success(); audio.play(.fever)
                GameCenterService.shared.report(.toolbelt)
            case let .milestoneReached(value):
                milestoneValue = value
                milestoneSeq += 1                        // drives the landmark toast
                haptics.success(); audio.play(.fever)
            case let .daemonSetSpawned(size):
                daemonSetMsg = "DAEMON SET ×\(size) — tap in order"
                daemonSetSeq += 1
                haptics.impact(.soft); audio.play(.breach)   // "new objective" cue
            case .daemonSetAdvanced:
                break                                    // the decode pop already covers it
            case let .daemonSetCompleted(cell):
                daemonSetMsg = "SET CRACKED — ×\(config.daemonSetReward) NEXT"
                daemonSetSeq += 1
                pendingEffects.append(.init(cell: cell, style: .pop, color: NeonTheme.gold, points: nil, intensity: 1))
                queued = true
                if !reduceMotion { freezeRemaining = 0.08 }   // hit-stop on the payoff
                haptics.impact(.rigid, intensity: 1.0); audio.play(.decodeBig)
            case let .daemonSetWrongOrder(cell):
                decodeRun = 0                            // chain broken → arpeggio resets
                pendingEffects.append(.init(cell: cell, style: .miss, color: NeonTheme.danger, points: nil))
                queued = true
                errorFlashSeq += 1
                haptics.impact(.rigid); audio.play(.miss)
            case let .dmzSpawned(cells):
                // A hostile incursion: announce the objective + a red pop-in on each zone cell.
                daemonSetMsg = "DMZ PURGE — clear the zone"
                daemonSetSeq += 1
                for cell in cells {
                    pendingEffects.append(.init(cell: cell, style: .breach, color: NeonTheme.danger, points: nil))
                }
                queued = true
                haptics.impact(.medium); audio.play(.breach)   // "new threat" cue
            case let .intrusionCleared(cell):
                // A defensive clear (outside the combo/fever system): a small red pop + light tick.
                pendingEffects.append(.init(cell: cell, style: .pop, color: NeonTheme.danger, points: nil, intensity: 0.4))
                queued = true
                haptics.impact(.light); audio.play(.decode)
            case let .dmzOverrunSpawned(cell):
                // The creep grows — a subtle threat pulse (soft, so the 1.6s cadence never spams).
                pendingEffects.append(.init(cell: cell, style: .breach, color: NeonTheme.danger, points: nil))
                queued = true
                haptics.impact(.soft); audio.play(.breach)
            case .dmzPurged:
                // The payoff: relief. Bright sting + a hit-stop on the moment.
                daemonSetMsg = "DMZ PURGED"
                daemonSetSeq += 1
                if !reduceMotion { freezeRemaining = 0.08 }
                haptics.success(); audio.play(.fever)
            case .gameOver:
                audio.play(.gameOver)
            }
        }
        if queued { effectSeq += 1 }
    }
}

// MARK: - Game screen

/// What a finished session yielded, for the game-over screen.
struct SessionOutcome: Equatable {
    let creditsEarned: Int
    let isHighScore: Bool
}

struct GameView: View {
    @State private var model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }   // iPad chrome scale
    @State private var shakeAnim: CGFloat = 0
    @State private var outcome: SessionOutcome?
    @State private var trailPoints: [TrailPoint] = []
    @State private var purgeTrigger = 0
    @State private var showGridExpanded = false
    @State private var showMilestone = false
    @State private var showDaemonSet = false
    @State private var showCodex = false            // rules reference, opened from pause
    @State private var streakPulse = false
    @State private var countdownValue: Int? = nil   // 3·2·1·0(GO); nil = not counting
    @State private var countdownTask: Task<Void, Never>?
    @State private var showBriefing: Bool
    let core: DataCore?                 // nil = endless mode
    let onExit: () -> Void
    /// Advance to the next campaign core (nil in endless / on the last core).
    let onNext: (() -> Void)?
    /// Persist the finished session exactly once; returns what it yielded.
    let recordSession: (_ score: Int, _ won: Bool) -> SessionOutcome

    /// PROTOCOL mode: objective-driven challenge (replaces Flow). Real fail state.
    let protocolMode: Bool
    /// Daily challenge: endless rules on a fixed, date-derived seed (everyone gets the
    /// same board). Replays reuse the seed so it stays "today's" board.
    let daily: Bool
    /// Player preference: render the RAM clock as a draining screen-edge containment
    /// frame on top of the slim top bar. See RAMPerimeterFrame.
    let ramBackground: Bool
    /// Fixed RNG seed (daily challenge). nil → a fresh seed each run/replay.
    let fixedSeed: UInt64?
    /// New-mechanic briefing to show before the run (nil = skip, e.g. already cleared).
    let briefing: CoreFeature?
    /// The score to beat (endless: top run; daily: today's best). 0 = no record yet —
    /// crossing it mid-run fires a one-shot "PERSONAL BEST" moment.
    let bestScore: Int
    @State private var showPB = false
    @State private var pbFired = false
    /// Best across replays this screen-visit, so a replay must beat the *new* record.
    @State private var sessionBest = 0

    init(core: DataCore? = nil,
         deck: Cyberdeck,
         protocolMode: Bool = false,
         seed: UInt64? = nil,
         daily: Bool = false,
         ramBackground: Bool = false,
         briefing: CoreFeature? = nil,
         bestScore: Int = 0,
         onExit: @escaping () -> Void,
         onNext: (() -> Void)? = nil,
         recordSession: @escaping (_ score: Int, _ won: Bool) -> SessionOutcome) {
        self.core = core
        self.protocolMode = protocolMode
        self.daily = daily
        self.ramBackground = ramBackground
        self.fixedSeed = seed
        self.briefing = briefing
        self.bestScore = bestScore
        self.onNext = onNext
        let model: GameViewModel
        if protocolMode {
            model = GameViewModel(config: .protocolMode(), deck: deck, seed: seed ?? GameView.freshSeed())
        } else if let core {
            model = GameViewModel(config: .campaign(for: core),
                                  deck: deck, seed: seed ?? GameView.freshSeed(),
                                  targetScore: core.targetScore, difficultyBias: core.difficultyBias)
        } else {
            // Endless (JACK IN) and the Daily challenge share the tuned endless config.
            model = GameViewModel(config: .endless(), deck: deck, seed: seed ?? GameView.freshSeed())
        }
        _model = State(initialValue: model)
        _showBriefing = State(initialValue: briefing != nil)
        self.onExit = onExit
        self.recordSession = recordSession
    }

    static func freshSeed() -> UInt64 {
        UInt64(bitPattern: Int64(Date().timeIntervalSince1970 * 1000))
    }

    /// True only on devices with a Dynamic Island / notch (a real top inset).
    /// On flat-top devices (e.g. SE) we keep score/RAM inline in the HUD instead
    /// of flanking the top, so nothing overlaps or is lost. Cached: `body`
    /// re-evaluates every frame during play, and the scene/key-window walk is
    /// not free (audit C3) — the inset can't change mid-session anyway.
    @State private var hasIslandOrNotch = false

    private static func detectIslandOrNotch() -> Bool {
        #if canImport(UIKit)
        let top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return top >= 40
        #else
        return false
        #endif
    }

    private var coreProgress: Double {
        let s = model.snapshot
        if s.feverActive { return s.feverFraction }
        return core != nil ? s.targetProgress : s.comboProgress
    }

    /// Run the pre-game "sync" countdown (every mode): hold the engine paused through
    /// 3·2·1, release it on GO. Each beat ticks an SFX + haptic. The task is stored
    /// and cancelled on disappear so a quit mid-countdown can't unpause a session
    /// that's leaving the screen (audit C4).
    private func startCountdown() {
        guard countdownValue == nil else { return }
        model.pause()
        let h = Haptics()
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for n in [3, 2, 1] {
                countdownValue = n
                AudioEngine.shared.play(.uiTap)
                h.impact(.light)
                do { try await Task.sleep(nanoseconds: 560_000_000) } catch { return }
            }
            countdownValue = 0                 // GO
            AudioEngine.shared.play(.fever)
            h.success()
            model.unpause()                    // the run begins on GO
            do { try await Task.sleep(nanoseconds: 450_000_000) } catch { return }
            countdownValue = nil
        }
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            FeverAtmosphere(active: model.snapshot.feverActive && !model.snapshot.isGameOver)
                .ignoresSafeArea().accessibilityHidden(true)
            if !model.snapshot.isGameOver {
                HeatVignette(level: min(1, Double(model.snapshot.score) / 100),
                             dampened: model.snapshot.feverActive)
                    .ignoresSafeArea().accessibilityHidden(true)
            }

            VStack(spacing: 0) {
                HUDView(snapshot: model.snapshot, coreName: core?.name)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Big score sits right above the Data Core (the score is what you
                // watch). The core fills the rest of the gap and keeps the grid down
                // in the thumb-reach zone (a flexible slot it sizes itself into).
                VStack(spacing: 6) {
                    BigScoreView(snapshot: model.snapshot)
                    // Endless clean-streak base multiplier — rewards long, clean survival.
                    // The slot reserves a constant height (endless/daily) so the badge
                    // appearing/disappearing can't resize the grid below it (layout shift).
                    if core == nil {
                        ZStack {
                            if model.snapshot.streakMultiplier > 1 && !model.snapshot.isGameOver {
                                StreakBadge(multiplier: model.snapshot.streakMultiplier, pulse: streakPulse)
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }
                        }
                        .frame(height: 26 * sc)
                    }
                    DataCoreView(progress: coreProgress,
                                 feverActive: model.snapshot.feverActive,
                                 label: model.snapshot.freezeActive ? "FREEZE"
                                       : model.snapshot.overclockActive ? "OVERCLOCK"
                                       : model.snapshot.feverActive ? "FEVER"
                                       : core != nil ? "DECRYPT" : "CHARGE",
                                 decodeToken: model.snapshot.score,
                                 reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .accessibilityHidden(true)   // decorative visualizer; state is in labels
                }
                .padding(.vertical, 8)
                .animation(.easeOut(duration: 0.25), value: model.snapshot.streakMultiplier > 1)

                GridBoard(snapshot: model.snapshot,
                          reduceMotion: reduceMotion,
                          effectSeq: model.effectSeq,
                          drainEffects: model.drainEffects,
                          onTap: { model.tap(cell: $0) })
                .overlay(
                    GridPowerFX(freeze: model.snapshot.freezeActive && !model.snapshot.isGameOver,
                                overclock: model.snapshot.overclockActive && !model.snapshot.isGameOver,
                                purgeTrigger: purgeTrigger,
                                reduceMotion: reduceMotion)
                        .accessibilityHidden(true)
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 12).frame(maxHeight: 96)
            }
            // Cap width so the layout stays coherent; no height cap so the game uses the
            // full screen. 760 pt exceeds every iPhone (max ~430 pt) so iPhone is unaffected;
            // on iPad the grid fills most of the screen. DataCoreView is capped separately
            // at 200 pt so it doesn't claim excessive vertical space when height is uncapped.
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(ShakeEffect(animatableData: shakeAnim))

            // Score + RAM time framing the Dynamic Island / notch. Only on devices
            // that have one — flat-top devices keep score/RAM inline in the HUD.
            if hasIslandOrNotch && !model.snapshot.isGameOver {
                IslandFrameRow(snapshot: model.snapshot)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
                    .ignoresSafeArea(.container, edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)   // visual notch framing; RAM is on the RAM bar
            }

            // Tap trail (over the grid, under the banners/overlays).
            TrailLayer(points: trailPoints, skin: TrailSkins.equipped, lifetime: 0.6)
                .accessibilityHidden(true)

            // Mid-streak momentum: a brief gold border pulse before Fever triggers.
            if !model.snapshot.isGameOver {
                StreakPulseBorder(trigger: model.streakPulseSeq, reduceMotion: reduceMotion)
                    .accessibilityHidden(true)
            }

            // Negative-event signal: a brief red screen-edge flash on a miss/expiry so
            // an error stays legible on a busy board (issue #2). Above the streak pulse.
            if !model.snapshot.isGameOver {
                ErrorFlashBorder(trigger: model.errorFlashSeq, reduceMotion: reduceMotion)
                    .accessibilityHidden(true)
            }

            // RAM-as-environment (optional): the screen-edge containment frame is the RAM
            // meter — it burns down as the clock drains, re-lights on decode, and pulses
            // red at critical (pairing with the existing audio double-pulse). On-theme and
            // out of the grid's way; the slim top bar stays as the precise readout.
            if ramBackground && !model.snapshot.isGameOver {
                RAMPerimeterFrame(fraction: model.snapshot.ramFraction,
                                  feverActive: model.snapshot.feverActive,
                                  reduceMotion: reduceMotion)
                    .accessibilityHidden(true)
            }

            // Fever / power-ups are shown diegetically: Fever surges the Data Core;
            // Freeze frosts the (already-stopped) grid; Overclock energizes it; Purge
            // sweeps it (see GridPowerFX). The Data Core label names the active state.

            // Brief "grid expanded" toast (positioned up by the core, clear of the grid).
            if showGridExpanded && !model.snapshot.isGameOver {
                Text("▦ GRID EXPANDED")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 8)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(NeonTheme.background.opacity(0.85))
                        .overlay(Capsule().stroke(NeonTheme.cyan.opacity(0.6), lineWidth: 1)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -130)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Personal-best moment (endless/daily): the run just became your best ever.
            // One-shot per run; sits above the milestone toast slot so they can't collide.
            if showPB && !model.snapshot.isGameOver {
                Text(daily ? "▲ DAILY BEST" : "▲ PERSONAL BEST")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .neonGlow(NeonTheme.gold, radius: 10)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(NeonTheme.background.opacity(0.85))
                        .overlay(Capsule().stroke(NeonTheme.gold.opacity(0.6), lineWidth: 1)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -176)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .accessibilityHidden(true)
            }

            // Score-milestone landmark toast (endless): a brief gold flash on 50/100/250…
            if showMilestone && !model.snapshot.isGameOver {
                Text("◆ \(model.milestoneValue) ◆")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .neonGlow(NeonTheme.gold, radius: 10)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(NeonTheme.background.opacity(0.85))
                        .overlay(Capsule().stroke(NeonTheme.gold.opacity(0.6), lineWidth: 1)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -130)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .accessibilityHidden(true)
            }

            // DAEMON SET objective toast (PROTOCOL): "set spawned" / "cracked ×4".
            if showDaemonSet && !model.snapshot.isGameOver {
                Text(model.daemonSetMsg)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 8)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(NeonTheme.background.opacity(0.85))
                        .overlay(Capsule().stroke(NeonTheme.cyan.opacity(0.6), lineWidth: 1)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -130)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .accessibilityHidden(true)
            }

            // Pause button (bottom-leading, out of the way of the grid).
            if !model.snapshot.isGameOver && !model.isPaused {
                Button { model.pause() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16 * sc, weight: .bold))
                        .foregroundStyle(NeonTheme.textDim)
                        .frame(width: 44 * sc, height: 44 * sc)
                        .background(Circle().stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(TerminalButtonStyle())
                .accessibilityLabel("Pause")
                .padding(.leading, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 760, maxHeight: .infinity, alignment: .bottomLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if model.isPaused && !showBriefing && countdownValue == nil && !showCodex {
                PauseOverlay(onResume: { model.unpause() },
                             onRestart: { outcome = nil; pbFired = false; showPB = false
                                          model.restart(seed: fixedSeed ?? GameView.freshSeed()); startCountdown() },
                             onCodex: { showCodex = true },
                             onQuit: onExit)
            }

            // Rules reference over a paused run — opaque backdrop so it reads clearly;
            // BACK returns to the pause menu (the run stays paused underneath).
            if showCodex {
                ZStack {
                    NeonTheme.background.ignoresSafeArea()
                    CodexView(onBack: { showCodex = false })
                }
                .transition(.opacity)
            }

            // In-theme "sync" countdown before the run starts (every mode).
            if let v = countdownValue, !model.snapshot.isGameOver {
                CountdownOverlay(value: v, reduceMotion: reduceMotion)
            }

            if showBriefing, let b = briefing {
                CoreBriefingOverlay(feature: b, coreName: core?.name ?? "DATA CORE",
                                    target: core?.targetScore ?? 0) {
                    showBriefing = false
                    startCountdown()
                }
            }

            if model.snapshot.isGameOver {
                GameOverOverlay(snapshot: model.snapshot,
                                core: core,
                                daily: daily,
                                outcome: outcome,
                                isFinalCore: core.map { $0.id >= Campaign.count } ?? false,
                                onReplay: { outcome = nil; pbFired = false; showPB = false
                                            model.restart(seed: fixedSeed ?? GameView.freshSeed()); startCountdown() },
                                onNext: (model.snapshot.didWin && onNext != nil) ? onNext : nil,
                                onExit: onExit)
            }

            // Per-frame driver — runs outside the render pass via onChange.
            TimelineView(.animation) { context in
                Color.clear
                    .onChange(of: context.date) { _, newDate in
                        model.advance(to: newDate)
                        if !trailPoints.isEmpty {       // fade/prune the tap trail
                            trailPoints.removeAll { newDate.timeIntervalSince($0.born) > 0.6 }
                        }
                    }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            hasIslandOrNotch = Self.detectIslandOrNotch()
            model.reduceMotion = reduceMotion
            model.pause()                       // hold the clock for the briefing / countdown
            if !showBriefing { startCountdown() }
        }
        .onDisappear { countdownTask?.cancel() }
        .onChange(of: reduceMotion) { _, new in model.reduceMotion = new }
        .onChange(of: model.snapshot.isGameOver) { _, over in
            if over, outcome == nil {
                outcome = recordSession(model.snapshot.score, model.snapshot.didWin)
                sessionBest = max(sessionBest, model.snapshot.score)
                // Game Center mirror (report-only): same funnel, same final
                // snapshot the recap renders. Flow is skipped inside.
                GameCenterService.shared.reportRunEnd(
                    model.snapshot,
                    mode: core != nil ? .campaign : daily ? .daily : protocolMode ? .protocolMode : .endless)
            }
        }
        .onChange(of: model.shakeTrigger) { _, _ in
            guard !reduceMotion else { return }
            shakeAnim = 0
            withAnimation(.easeOut(duration: 0.4)) { shakeAnim = 1 }
        }
        .onChange(of: model.powerUpFlashSeq) { _, _ in
            // Purge is instant → fire a one-shot grid shockwave. Freeze/Overclock are
            // duration effects shown via the grid overlay from the snapshot flags.
            if model.powerUpFlashKind == .purge { purgeTrigger += 1 }
        }
        .onChange(of: model.gridExpandedSeq) { _, _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { showGridExpanded = true }
            let seq = model.gridExpandedSeq
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                if model.gridExpandedSeq == seq {
                    withAnimation(.easeOut(duration: 0.3)) { showGridExpanded = false }
                }
            }
        }
        .onChange(of: model.milestoneSeq) { _, _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { showMilestone = true }
            let seq = model.milestoneSeq
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if model.milestoneSeq == seq {
                    withAnimation(.easeOut(duration: 0.3)) { showMilestone = false }
                }
            }
        }
        .onChange(of: model.daemonSetSeq) { _, _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { showDaemonSet = true }
            let seq = model.daemonSetSeq
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if model.daemonSetSeq == seq {
                    withAnimation(.easeOut(duration: 0.3)) { showDaemonSet = false }
                }
            }
        }
        .onChange(of: model.snapshot.score) { _, score in
            // Crossing your own record is a *moment* (ground truth 1.4): celebrate it
            // once per run, live — not just on the game-over screen.
            let toBeat = max(bestScore, sessionBest)
            guard !pbFired, toBeat > 0, score > toBeat, core == nil else { return }
            pbFired = true
            AudioEngine.shared.play(.fever)
            Haptics().success()
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { showPB = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeOut(duration: 0.3)) { showPB = false }
            }
        }
        .onChange(of: model.snapshot.streakMultiplier) { old, new in
            guard !reduceMotion, new > old else { return }   // pulse only on a tier-up
            streakPulse = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { streakPulse = false }
        }
        .animation(.easeInOut(duration: 0.3), value: model.snapshot.feverActive)
        .animation(.easeInOut(duration: 0.3), value: model.snapshot.freezeActive)
        .animation(.easeInOut(duration: 0.3), value: model.snapshot.overclockActive)
        // Trail follows the finger WITHOUT consuming taps (simultaneous, 0 distance).
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    guard !TrailSkins.equipped.isOff, !model.isPaused, !model.snapshot.isGameOver else { return }
                    trailPoints.append(TrailPoint(pos: v.location, born: Date()))
                    if trailPoints.count > 48 { trailPoints.removeFirst(trailPoints.count - 48) }
                }
        )
    }
}

// MARK: - Dynamic Island frame

/// SCORE (left) and RAM time (right) pinned to the very top, flanking the
/// Dynamic Island. On notch phones it frames the notch; on flat-top phones it's
/// a clean split readout in the (status-bar-hidden) top strip — same code, no
/// device gets a worse layout.
private struct IslandFrameRow: View {
    let snapshot: SessionSnapshot
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }

    private var ramColor: Color {
        snapshot.ramFraction > 0.5 ? NeonTheme.cyan
        : snapshot.ramFraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer(minLength: 100)
            VStack(alignment: .trailing, spacing: 0) {
                Text("RAM")
                    .font(.system(size: 9 * sc, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text("\(Int(ceil(max(0, snapshot.ramRemaining))))s")
                    .font(.system(size: 20 * sc, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ramColor)
                    .neonGlow(ramColor, radius: 6)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - Tap trail (finger-follow cosmetic)

struct TrailPoint: Identifiable, Equatable {
    let id = UUID()
    let pos: CGPoint
    let born: Date
}

/// Renders the equipped trail as a fading neon "data stream": each successive
/// tap/drag sample is connected to the previous one by a glowing beam, with a node
/// at each sample. Because consecutive *taps* are connected, a tap-only game still
/// leaves a real trail that jumps between the cells you hit. Non-interactive; fed by
/// a simultaneous drag on the game root so it never steals cell taps. Its own
/// TimelineView ticks the fade so the beam recedes smoothly between samples.
private struct TrailLayer: View {
    let points: [TrailPoint]
    let skin: TrailSkin
    let lifetime: TimeInterval

    var body: some View {
        if !skin.isOff {
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in draw(ctx, now: tl.date) }
                    .allowsHitTesting(false)
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, now: Date) {
        guard !points.isEmpty else { return }
        let color = skin.color()
        // Glow pass (blurred) then a crisp pass on top.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: max(2, skin.lineWidth * 0.9)))
            strokeBeam(layer, color: color, now: now, widthScale: 1.5)
            fillNodes(layer, color: color, now: now, sizeScale: 1.3)
        }
        strokeBeam(ctx, color: color, now: now, widthScale: 1.0)
        fillNodes(ctx, color: color, now: now, sizeScale: 1.0)
    }

    private func fade(_ p: TrailPoint, _ now: Date) -> CGFloat {
        CGFloat(max(0, 1 - now.timeIntervalSince(p.born) / lifetime))
    }

    /// Connect each sample to the previous one; segment opacity/width follow the
    /// newer endpoint's age, so the freshest part of the stream is brightest.
    private func strokeBeam(_ ctx: GraphicsContext, color: Color, now: Date, widthScale: CGFloat) {
        guard points.count >= 2 else { return }
        for i in 1..<points.count {
            let f = fade(points[i], now)
            guard f > 0.01 else { continue }
            var path = Path()
            path.move(to: points[i - 1].pos)
            path.addLine(to: points[i].pos)
            let w = skin.lineWidth * (0.35 + 0.65 * f) * widthScale
            ctx.stroke(path, with: .color(color.opacity(0.85 * Double(f))), style: skin.beamStyle(width: w))
        }
    }

    private func fillNodes(_ ctx: GraphicsContext, color: Color, now: Date, sizeScale: CGFloat) {
        for p in points {
            let f = fade(p, now)
            guard f > 0.01 else { continue }
            let sz = skin.size * (0.4 + 0.6 * f) * sizeScale
            ctx.fill(skin.dotPath(at: p.pos, size: sz), with: .color(color.opacity(0.9 * Double(f))))
        }
    }
}

// MARK: - Data Core (reactive centerpiece + ambient scanner)

/// Fills the space between the HUD and the grid: a neon "data core" you're cracking.
/// The progress arc tracks Fever charge (endless) or the target (campaign); it
/// pulses on each decode and surges gold during Fever. Two slow counter-rotating
/// dashed rings give the ambient "scanner is alive" feel. Sizes to its slot, so it
/// shrinks gracefully on small screens. Purely presentational.
private struct DataCoreView: View {
    let progress: Double        // 0…1 (fever charge or campaign target progress)
    let feverActive: Bool
    let label: String
    let decodeToken: Int        // changes per decode → pulse
    let reduceMotion: Bool

    @State private var spin: Double = 0
    @State private var pulse: CGFloat = 1
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }

    private var tint: Color { feverActive ? NeonTheme.gold : NeonTheme.cyan }

    var body: some View {
        GeometryReader { geo in
            let s = max(70, min(min(geo.size.width, geo.size.height) - 12, 180 * sc))
            ZStack {
                Circle()
                    .stroke(NeonTheme.gridLineDim.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 14]))
                    .frame(width: s, height: s)
                    .rotationEffect(.degrees(-spin * 0.6))
                Circle()
                    .stroke(tint.opacity(0.40), style: StrokeStyle(lineWidth: 1.5, dash: [4, 12]))
                    .frame(width: s * 0.86, height: s * 0.86)
                    .rotationEffect(.degrees(spin))
                Circle().stroke(tint.opacity(0.15), lineWidth: 3).frame(width: s * 0.6, height: s * 0.6)
                Circle()
                    .trim(from: 0, to: max(0.0001, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: s * 0.6, height: s * 0.6)
                    .rotationEffect(.degrees(-90))
                    .neonGlow(tint, radius: 5)
                    .animation(.easeOut(duration: 0.25), value: progress)
                VStack(spacing: 3) {
                    Image(systemName: feverActive ? "bolt.fill" : "hexagon")
                        .font(.system(size: s * 0.16, weight: .bold))
                        .foregroundStyle(tint).neonGlow(tint, radius: 6)
                    Text(label)
                        .font(.system(size: 8 * sc, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
                .scaleEffect(pulse)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .onAppear { spin = 360 }
        .animation(reduceMotion ? nil
                   : .linear(duration: feverActive ? 4 : 14).repeatForever(autoreverses: false),
                   value: spin)
        .onChange(of: decodeToken) { _, _ in
            guard !reduceMotion else { return }
            pulse = 1.16
            withAnimation(.easeOut(duration: 0.3)) { pulse = 1 }
        }
    }
}

// MARK: - Big score

/// The score, large and centered, sitting directly above the Data Core in every
/// mode (it's the number you actually watch). Rolls on change, shows the Fever
/// multiplier in gold, and carries the shield-charge indicator.
private struct BigScoreView: View {
    let snapshot: SessionSnapshot
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }   // iPad bumps chrome type

    var body: some View {
        VStack(spacing: 0) {
            Text("SCORE")
                .font(.system(size: 11 * sc, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .tracking(3)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(snapshot.score)")
                    .font(.system(size: 46 * sc, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 10)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                // The total ×N here shows only a *boost beyond* the streak base (Fever /
                // Overclock); the steady streak multiplier is shown by the STREAK badge.
                if snapshot.scoreMultiplier > max(1, snapshot.streakMultiplier) {
                    Text("×\(snapshot.scoreMultiplier)")
                        .font(.system(size: 22 * sc, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 7)
                }
            }
            // Reserved-height slot so a shield charge dropping to 0 (or appearing) can't
            // change the score block's height and shift the grid below it (layout shift).
            ZStack {
                if snapshot.shieldCharges > 0 {
                    Label("\(snapshot.shieldCharges)", systemImage: "shield.fill")
                        .font(.system(size: 12 * sc, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                }
            }
            .frame(height: 16 * sc)
            .padding(.top, 2)
            // Next landmark (endless/daily only — the engine reports nil elsewhere):
            // a quiet, always-true goal line so there's forever a "why am I here"
            // (ground truth 1.5) without shouting over the score.
            if let next = snapshot.nextMilestone, !snapshot.isGameOver {
                Text("NEXT ◆ \(next)")
                    .font(.system(size: 10 * sc, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                    .padding(.top, 1)
            }
        }
        .animation(.easeOut(duration: 0.25), value: snapshot.score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score")
        .accessibilityValue({
            var v = snapshot.scoreMultiplier > 1
                ? "\(snapshot.score), multiplier times \(snapshot.scoreMultiplier)"
                : "\(snapshot.score)"
            if let next = snapshot.nextMilestone { v += ", next milestone \(next)" }
            return v
        }())
    }
}

/// The endless clean-streak base multiplier badge. Appears at ×2 and climbs as the
/// clean-decode chain crosses tiers (pulses on a tier-up); vanishing = streak broken.
private struct StreakBadge: View {
    let multiplier: Int
    let pulse: Bool
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill").font(.system(size: 11 * sc, weight: .bold))
            Text("STREAK ×\(multiplier)")
                .font(.system(size: 12 * sc, weight: .heavy, design: .monospaced))
                .monospacedDigit()
        }
        .foregroundStyle(NeonTheme.gold)
        .neonGlow(NeonTheme.gold, radius: 4)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(NeonTheme.gold.opacity(0.12))
            .overlay(Capsule().stroke(NeonTheme.gold.opacity(0.5), lineWidth: 1)))
        .scaleEffect(pulse ? 1.18 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulse)
        .accessibilityLabel("Streak multiplier times \(multiplier)")
    }
}

// MARK: - HUD

private struct HUDView: View {
    let snapshot: SessionSnapshot
    var coreName: String? = nil
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }

    var body: some View {
        VStack(spacing: 8) {
            if let target = snapshot.targetScore {
                VStack(spacing: 4) {
                    HStack {
                        Text(coreName ?? "DATA CORE")
                            .font(.system(size: 12 * sc, weight: .bold, design: .monospaced))
                            .foregroundStyle(NeonTheme.gold)
                        Spacer()
                        Text("\(snapshot.score) / \(target)")
                            .font(.system(size: 12 * sc, weight: .bold, design: .monospaced))
                            .foregroundStyle(NeonTheme.gold)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(NeonTheme.gold)
                                .frame(width: max(0, geo.size.width * snapshot.targetProgress))
                                .neonGlow(NeonTheme.gold, radius: 5)
                                .animation(.easeOut(duration: 0.18), value: snapshot.targetProgress)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.bottom, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(coreName ?? "Data core")
                .accessibilityValue("\(snapshot.score) of \(target)")
            }
            RAMBar(fraction: snapshot.ramFraction)
        }
    }
}

/// The RAM time buffer — the core resource. Shifts cyan → red as it drains.
private struct RAMBar: View {
    let fraction: Double
    @Environment(\.horizontalSizeClass) private var hSize
    private var sc: CGFloat { hSize == .regular ? 1.4 : 1.0 }

    private var color: Color {
        fraction > 0.5 ? NeonTheme.cyan
        : fraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("RAM")
                .font(.system(size: 10 * sc, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))               // track
                    Capsule()                                              // ghost (slow trail)
                        .fill(color.opacity(0.32))
                        .frame(width: max(0, w * fraction))
                        .animation(.easeOut(duration: 0.6), value: fraction)
                    Capsule()                                              // live (fast)
                        .fill(color)
                        .frame(width: max(0, w * fraction))
                        .neonGlow(color, radius: 6)
                        .animation(.easeOut(duration: 0.18), value: fraction)
                }
            }
            .frame(height: 12 * sc)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RAM remaining")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

// MARK: - Grid board

private struct GridBoard: View {
    let snapshot: SessionSnapshot
    let reduceMotion: Bool
    let effectSeq: Int
    let drainEffects: () -> [JuiceEffect]
    let onTap: (Int) -> Void

    var body: some View {
        let cols = snapshot.gridSize.columns
        let nodesByCell = Dictionary(
            snapshot.nodes.map { ($0.cellIndex, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let spacing: CGFloat = 10
            let cell = (side - spacing * CGFloat(cols - 1)) / CGFloat(cols)

            ZStack {
                VStack(spacing: spacing) {
                    ForEach(0..<snapshot.gridSize.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<cols, id: \.self) { col in
                                let index = row * cols + col
                                CellView(node: nodesByCell[index], size: cell,
                                         feverActive: snapshot.feverActive,
                                         isZone: snapshot.dmzZone.contains(index))
                                    // Whole cell is tappable → hitbox is generously
                                    // larger than the sprite (brief §10.7 tolerance).
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(index) }
                            }
                        }
                    }
                }
                // Keyed on id+cell so a worm hop (same id, new cell) also transitions.
                .animation(.easeOut(duration: 0.12), value: snapshot.nodes.map { "\($0.id)@\($0.cellIndex)" })
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: snapshot.gridSize)

                EffectsLayer(cols: cols, cell: cell, spacing: spacing,
                             reduceMotion: reduceMotion, seq: effectSeq, drain: drainEffects)
                    .accessibilityHidden(true)
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CellView: View {
    let node: GridNode?
    let size: CGFloat
    let feverActive: Bool
    /// True when this cell is part of an active DMZ PURGE zone — draw a hostile outline
    /// (kept even after the cell is cleared, so the zone shows purge progress).
    var isZone: Bool = false

    var body: some View {
        ZStack {
            // Empty socket.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
            // DMZ zone marker: a glowing red containment outline + faint wash.
            if isZone {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.danger.opacity(0.10))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NeonTheme.danger.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .neonGlow(NeonTheme.danger, radius: 6)
            }
            if let node {
                NodeSprite(node: node, feverActive: feverActive, cell: size)
                    .padding(size * 0.16)   // sprite smaller than the tap cell
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .id(node.id)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(for: node, feverActive: feverActive))
        .accessibilityAddTraits(node == nil ? [] : .isButton)
    }

    /// A concise spoken description of a cell's contents (for VoiceOver exploration;
    /// the live game is a visual reflex challenge, but the board stays perceivable).
    private static func label(for node: GridNode?, feverActive: Bool) -> String {
        guard let node else { return "Empty cell" }
        if let order = node.setOrder, let n = node.setSize { return "Daemon set, tap position \(order) of \(n)" }
        if feverActive && node.type != .firewallBomb { return "Bonus node" }
        switch node.type {
        case .standardDaemon: return "Daemon"
        case .armoredDaemon:  return node.isBreached ? "Armored daemon, breached" : "Armored daemon"
        case .firewallBomb:   return "Firewall — do not tap"
        case .dataCache:      return "Data cache, bonus"
        case .wormDaemon:     return "Worm daemon"
        case .powerUp:        return "Power-up pickup"
        case .intrusion:      return "Intrusion — tap to clear"
        }
    }
}

/// Visual for one daemon/bomb. Mechanics live in the model — this only draws.
/// During fever, daemons render as golden bonus nodes (brief §10.2).
private struct NodeSprite: View {
    let node: GridNode
    let feverActive: Bool
    /// The cell size, so the glyph/number/pips/ring scale with the cell (the SF Symbol
    /// is otherwise a fixed point size → tiny inside the large iPad cells).
    var cell: CGFloat = 110

    /// Glyph point size ≈ 20% of the cell (matches the original 22pt on a ~110pt phone cell).
    private var glyph: CGFloat { cell * 0.20 }
    /// Ring stroke scales gently with the cell so it doesn't read as hairline on iPad.
    private var ring: CGFloat { max(2, cell * 0.022) }

    var body: some View {
        if let order = node.setOrder, let n = node.setSize {
            // DAEMON SET node: ordered chain — show its position (number + filled pips)
            // so the player knows the tap order. Rendered before the fever-gold path so
            // an objective never hides behind the bonus look.
            setSprite(order: order, of: n)
        } else if feverActive && node.type != .firewallBomb {
            // Golden bonus node during Fever Mode.
            sprite(color: NeonTheme.gold, symbol: "bolt.fill", ringed: true)
        } else {
            switch node.type {
            case .standardDaemon:
                sprite(color: NeonTheme.cyan, symbol: "circle.grid.cross.fill")
            case .armoredDaemon:
                sprite(color: node.isBreached ? NeonTheme.gold : NeonTheme.magenta,
                       symbol: node.isBreached ? "lock.open.fill" : "lock.shield.fill",
                       ringed: !node.isBreached)
            case .firewallBomb:
                sprite(color: NeonTheme.danger, symbol: "exclamationmark.triangle.fill")
            case .dataCache:
                // A bright golden prize — stacked data, ringed, to read as "grab me".
                sprite(color: NeonTheme.gold, symbol: "square.stack.3d.up.fill", ringed: true)
            case .wormDaemon:
                // Acid-green squiggle that visibly squirms — a distinct, moving target.
                WormNodeSprite(glyph: glyph, ring: ring)
            case .powerUp:
                // White "special pickup" — kind shown by its glyph.
                sprite(color: NeonTheme.textPrimary, symbol: Self.powerSymbol(node.powerKind), ringed: true)
            case .intrusion:
                // A hostile DMZ infestation — a solid red hex to scrub away. Distinct from the
                // firewall's warning triangle (and bombs never share the board with a DMZ).
                sprite(color: NeonTheme.danger, symbol: "hexagon.fill", ringed: true)
            }
        }
    }

    static func powerSymbol(_ kind: PowerUpKind?) -> String {
        switch kind {
        case .timeFreeze: return "snowflake"
        case .overclock:  return "bolt.fill"
        case .purge:      return "wind"
        case .none:       return "sparkles"
        }
    }

    private func sprite(color: Color, symbol: String, ringed: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ringed ? ring * 1.4 : ring)
                .neonGlow(color, radius: 8)
            Image(systemName: symbol)
                .font(.system(size: glyph, weight: .bold))
                .foregroundStyle(color)
                .neonGlow(color, radius: 4)
        }
    }

    /// A DAEMON SET node: its order number over a row of pips (first `order` of `n`
    /// filled) so the tap sequence reads at a glance. Colors resolve through the palette.
    private func setSprite(order: Int, of n: Int) -> some View {
        let color = NeonTheme.cyan
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ring * 1.25)
                .neonGlow(color, radius: 8)
            VStack(spacing: cell * 0.03) {
                Text("\(order)")
                    .font(.system(size: glyph * 0.95, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
                    .neonGlow(color, radius: 4)
                HStack(spacing: cell * 0.03) {
                    ForEach(0..<n, id: \.self) { i in
                        Circle()
                            .fill(i < order ? color : color.opacity(0.25))
                            .frame(width: cell * 0.045, height: cell * 0.045)
                    }
                }
            }
        }
    }
}

/// The worm daemon's sprite: the acid-green squiggle with a gentle, continuous
/// squirm (rotate + sway) so it reads as a living, moving target at a glance —
/// the visual counterpart to its distinct decode chirp. Snaps still for Reduce Motion.
private struct WormNodeSprite: View {
    var glyph: CGFloat = 22
    var ring: CGFloat = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NeonTheme.worm.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NeonTheme.worm, lineWidth: ring * 1.4)
                .neonGlow(NeonTheme.worm, radius: 8)
            Image(systemName: "scribble.variable")
                .font(.system(size: glyph, weight: .bold))
                .foregroundStyle(NeonTheme.worm)
                .neonGlow(NeonTheme.worm, radius: 4)
                .rotationEffect(.degrees(wiggle ? 7 : -7))
                .offset(x: wiggle ? 2.5 : -2.5)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) { wiggle = true }
        }
    }
}

// MARK: - Grid power-up FX (diegetic, scoped to the board)

/// Power-up feedback expressed *on the grid* instead of over it: Freeze frosts the
/// (already-stopped) board, Overclock energizes it with a pulsing gold edge, and Purge
/// fires a one-shot cyan shockwave. Non-interactive; never obscures the nodes.
private struct GridPowerFX: View {
    let freeze: Bool
    let overclock: Bool
    let purgeTrigger: Int
    let reduceMotion: Bool

    @State private var pulse = false
    @State private var purgeScale: CGFloat = 0
    @State private var purgeOpacity: Double = 0
    private let ice = Color(red: 0.6, green: 0.92, blue: 1.0)

    var body: some View {
        ZStack {
            if freeze {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [ice.opacity(0.22), ice.opacity(0.10)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ice.opacity(0.65), lineWidth: 2))
                    .neonGlow(ice, radius: 6)
                    .transition(.opacity)
            }
            if overclock {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NeonTheme.gold, lineWidth: pulse ? 4 : 2)
                    .neonGlow(NeonTheme.gold, radius: pulse ? 14 : 5)
                    .opacity(0.85)
                    .transition(.opacity)
            }
            Circle()
                .stroke(NeonTheme.cyan, lineWidth: 4)
                .neonGlow(NeonTheme.cyan, radius: 10)
                .scaleEffect(purgeScale)
                .opacity(purgeOpacity)
        }
        .allowsHitTesting(false)
        .onChange(of: overclock) { _, on in startPulse(on) }
        .onAppear { startPulse(overclock) }
        .onChange(of: purgeTrigger) { _, _ in
            guard !reduceMotion else { return }
            purgeScale = 0.15; purgeOpacity = 0.9
            withAnimation(.easeOut(duration: 0.55)) { purgeScale = 1.5; purgeOpacity = 0 }
        }
    }

    private func startPulse(_ on: Bool) {
        pulse = false
        guard on, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
    }
}

// MARK: - Core briefing (new-mechanic explainer)

/// Shown when a campaign core introduces a new mechanic — names it, explains it in a
/// line, and holds the RAM clock until the player taps JACK IN.
private struct CoreBriefingOverlay: View {
    let feature: CoreFeature
    let coreName: String
    let target: Int
    let onBegin: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("INCOMING · \(coreName.uppercased())")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text("NEW: \(feature.title)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                Image(systemName: feature.symbol)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 14)
                    .padding(.vertical, 4)
                Text(feature.detail)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("TARGET  \(target)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .padding(.top, 2)
                TerminalButton(title: "JACK IN", color: NeonTheme.cyan, action: onBegin)
                    .padding(.top, 6)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NeonTheme.background.opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(NeonTheme.cyan.opacity(0.5), lineWidth: 1.5))
            )
            .padding(32)
        }
    }
}

// MARK: - Game over

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    var onCodex: () -> Void = {}
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("CONNECTION SUSPENDED")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text("PAUSED")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 10)
                // Vertical stack: three actions read cleanly as full-width buttons
                // (RESUME / RESTART / QUIT) and stay legible on the smallest screens.
                VStack(spacing: 12) {
                    TerminalButton(title: "RESUME", color: NeonTheme.cyan, wide: true, action: onResume)
                    TerminalButton(title: "RESTART", color: NeonTheme.gold, wide: true, action: onRestart)
                    TerminalButton(title: "QUIT", color: NeonTheme.magenta, wide: true, action: onQuit)
                    // Secondary: re-read the rules without leaving the run.
                    Button(action: onCodex) {
                        Label("CODEX", systemImage: "book.closed.fill")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NeonTheme.textDim)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TerminalButtonStyle())
                    .accessibilityLabel("Codex, rules and targets reference")
                }
                .frame(maxWidth: 240)
                .padding(.top, 8)
            }
            .padding(32)
        }
    }
}

/// A compact, in-theme pre-run countdown: a "// SYNC" tag, a big mono 3·2·1 that snaps
/// in, a neon scanline sweeping across the screen each beat, then "BREACH" on GO.
private struct CountdownOverlay: View {
    let value: Int            // 3,2,1 or 0 = GO
    let reduceMotion: Bool
    @State private var pop = false
    @State private var sweep = false

    private var isGo: Bool { value <= 0 }
    private var color: Color { isGo ? NeonTheme.gold : NeonTheme.cyan }
    private var label: String { isGo ? "BREACH" : "\(value)" }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.22).ignoresSafeArea()
                // Scanline sweeping down across the screen on each beat.
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, color.opacity(0.6), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .neonGlow(color, radius: 6)
                    .position(x: geo.size.width / 2,
                              y: geo.size.height * (sweep ? 0.78 : 0.22))
                    .opacity(reduceMotion ? 0 : 0.85)

                VStack(spacing: 6) {
                    Text(isGo ? "// EXECUTE" : "// SYNC")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim).tracking(3)
                    Text(label)
                        .font(.system(size: isGo ? 50 : 74, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color)
                        .neonGlow(color, radius: 16)
                        .monospacedDigit()
                        .scaleEffect(pop ? 1.0 : 1.45)
                        .opacity(pop ? 1 : 0)
                }
            }
            .onAppear(perform: beat)
            .onChange(of: value) { _, _ in beat() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func beat() {
        guard !reduceMotion else { pop = true; return }
        pop = false; sweep = false
        withAnimation(.spring(response: 0.30, dampingFraction: 0.6)) { pop = true }
        withAnimation(.easeOut(duration: 0.52)) { sweep = true }
    }
}

private struct GameOverOverlay: View {
    let snapshot: SessionSnapshot
    let core: DataCore?
    var daily: Bool = false
    let outcome: SessionOutcome?
    let isFinalCore: Bool
    let onReplay: () -> Void
    let onNext: (() -> Void)?
    let onExit: () -> Void

    private var didWin: Bool { snapshot.didWin }
    /// Winning the last core = whole campaign cleared → a finale.
    private var isFinale: Bool { didWin && isFinalCore }

    private var headline: String {
        if isFinale { return "THE GRID IS YOURS" }
        if core != nil { return didWin ? "CORE CRACKED" : "INTRUSION FAILED" }
        switch snapshot.gameOverReason {
        case .firewallHit: return "FIREWALL TRIGGERED"
        case .ramDepleted: return "RAM DEPLETED"
        case .dmzOverrun:  return "DMZ OVERRUN"
        default:           return "CONNECTION LOST"
        }
    }
    private var headlineColor: Color {
        if isFinale { return NeonTheme.gold }
        return didWin ? NeonTheme.cyan : NeonTheme.danger
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(isFinale ? "CAMPAIGN COMPLETE"
                              : daily ? "DAILY CHALLENGE"
                              : (core != nil ? (core?.name.uppercased() ?? "") : "CONNECTION TERMINATED"))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text(headline)
                    .font(.system(size: isFinale ? 30 : 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(headlineColor)
                    .neonGlow(headlineColor, radius: isFinale ? 16 : 10)
                    .multilineTextAlignment(.center)

                if isFinale {
                    Text("◆ ALL 10 CORES CRACKED ◆")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.cyan)
                        .neonGlow(NeonTheme.cyan, radius: 8)
                } else if didWin {
                    Text("◆ DATA CORE DECRYPTED ◆")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 8)
                } else if outcome?.isHighScore == true {
                    Text(daily ? "◆ NEW DAILY BEST ◆" : "◆ NEW HIGH SCORE ◆")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 8)
                }

                Text(core != nil ? "DECODED: \(snapshot.score) / \(core?.targetScore ?? 0)"
                                 : "DATA DECODED: \(snapshot.score)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .padding(.top, 2)
                // Campaign win margin: how close was it? Makes a clear replay goal.
                if didWin, core != nil {
                    Text("\(Int(ceil(max(0, snapshot.ramRemaining))))s TO SPARE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold.opacity(0.85))
                }
                // Run recap (endless/daily): the story of the run in one line —
                // deaths sting less when you can see what you built (Part 1.4).
                if core == nil {
                    Text("\(Int(snapshot.elapsed))s ONLINE · STREAK \(snapshot.bestCleanStreak) · FEVER ×\(snapshot.feversTriggered)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                        .accessibilityLabel("Run lasted \(Int(snapshot.elapsed)) seconds, best streak \(snapshot.bestCleanStreak), \(snapshot.feversTriggered) fevers")
                }
                if let earned = outcome?.creditsEarned, earned > 0 {
                    Label("+\(earned) CR", systemImage: "bitcoinsign.circle.fill")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                }

                VStack(spacing: 12) {
                    if let onNext {
                        TerminalButton(title: "NEXT CORE", color: NeonTheme.gold, action: onNext)
                    }
                    HStack(spacing: 14) {
                        TerminalButton(title: core != nil ? "RETRY" : "RECONNECT",
                                       color: NeonTheme.cyan, action: onReplay)
                        TerminalButton(title: core != nil ? "CORES" : "JACK OUT",
                                       color: NeonTheme.magenta, action: onExit)
                    }
                }
                .padding(.top, 10)
            }
            .padding(32)
        }
    }
}

struct TerminalButton: View {
    let title: String
    let color: Color
    var wide: Bool = false        // fill the container width (uniform menu buttons)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
                )
                .neonGlow(color, radius: 6)
        }
        .buttonStyle(TerminalButtonStyle())
    }
}

#Preview {
    GameView(deck: .starter,
             onExit: {},
             recordSession: { _, _ in SessionOutcome(creditsEarned: 0, isHighScore: false) })
        .preferredColorScheme(.dark)
}
