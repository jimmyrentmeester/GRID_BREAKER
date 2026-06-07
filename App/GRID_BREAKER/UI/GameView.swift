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
    let chill: Bool
    private var lastDate: Date?
    private var freezeRemaining: TimeInterval = 0   // hit-stop budget
    private var pendingEffects: [JuiceEffect] = []
    private let haptics = Haptics()
    private let audio = AudioEngine.shared

    init(config: GameConfig = .default,
         deck: Cyberdeck = .starter,
         gridSize: GridSize = .threeByThree,
         seed: UInt64,
         targetScore: Int? = nil,
         difficultyBias: Int = 0,
         chill: Bool = false) {
        self.config = config
        self.deck = deck
        self.gridSize = gridSize
        self.targetScore = targetScore
        self.difficultyBias = difficultyBias
        self.chill = chill
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
                let points = type == .armoredDaemon ? config.scoreArmored : config.scoreStandard
                pendingEffects.append(.init(cell: cell, style: .pop,
                                            color: type == .armoredDaemon ? NeonTheme.gold : NeonTheme.cyan,
                                            points: points))
                queued = true
                if type == .armoredDaemon {
                    haptics.impact(.medium); audio.play(.decodeBig)
                    if !reduceMotion { freezeRemaining = 0.08 }   // hit-stop on the heavy kill
                } else {
                    haptics.impact(.light); audio.play(.decode)
                }
            case let .nodeBreached(cell):
                pendingEffects.append(.init(cell: cell, style: .breach, color: NeonTheme.magenta, points: nil))
                queued = true
                haptics.impact(.soft); audio.play(.breach)
            case let .emptyMiss(cell):
                guard !chill else { break }   // no punishing feedback in Flow
                pendingEffects.append(.init(cell: cell, style: .miss, color: NeonTheme.danger, points: nil))
                queued = true
                haptics.impact(.rigid); audio.play(.miss)
            case .nodeExpired:
                guard !chill else { break }   // nodes just fade quietly in Flow
                haptics.impact(.soft); audio.play(.miss)
            case let .missAbsorbed(cell):
                pendingEffects.append(.init(cell: cell, style: .shield, color: NeonTheme.gold, points: nil))
                queued = true
                haptics.impact(.soft); audio.play(.breach)
            case let .firewallDefused(cell):
                // Shield saved you — a bright gold "blocked" pop, no game over.
                pendingEffects.append(.init(cell: cell, style: .shield, color: NeonTheme.gold, points: nil))
                queued = true
                haptics.impact(.medium); audio.play(.decodeBig)
            case let .firewallExploded(cell):
                pendingEffects.append(.init(cell: cell, style: .bomb, color: NeonTheme.danger, points: nil))
                queued = true
                if !reduceMotion { freezeRemaining = 0.06; shakeTrigger += 1 }
                haptics.error(); audio.play(.bomb)
            case .feverStarted:
                haptics.success(); audio.play(.fever)
            case .feverEnded:
                haptics.impact(.soft)
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
    @State private var shakeAnim: CGFloat = 0
    @State private var outcome: SessionOutcome?
    @State private var trailPoints: [TrailPoint] = []
    let core: DataCore?                 // nil = endless mode
    let onExit: () -> Void
    /// Advance to the next campaign core (nil in endless / on the last core).
    let onNext: (() -> Void)?
    /// Persist the finished session exactly once; returns what it yielded.
    let recordSession: (_ score: Int, _ won: Bool) -> SessionOutcome

    /// Flow (chill) mode: no clock, no fail, calm pace + presentation.
    let chill: Bool

    init(core: DataCore? = nil,
         deck: Cyberdeck,
         chill: Bool = false,
         onExit: @escaping () -> Void,
         onNext: (() -> Void)? = nil,
         recordSession: @escaping (_ score: Int, _ won: Bool) -> SessionOutcome) {
        self.core = core
        self.chill = chill
        self.onNext = onNext
        let model: GameViewModel
        if chill {
            model = GameViewModel(config: .chill(), deck: deck, seed: GameView.freshSeed(), chill: true)
        } else if let core {
            model = GameViewModel(config: .campaign(timeBudget: core.timeBudget),
                                  deck: deck, seed: GameView.freshSeed(),
                                  targetScore: core.targetScore, difficultyBias: core.difficultyBias)
        } else {
            model = GameViewModel(deck: deck, seed: GameView.freshSeed())
        }
        _model = State(initialValue: model)
        self.onExit = onExit
        self.recordSession = recordSession
    }

    static func freshSeed() -> UInt64 {
        UInt64(bitPattern: Int64(Date().timeIntervalSince1970 * 1000))
    }

    /// True only on devices with a Dynamic Island / notch (a real top inset).
    /// On flat-top devices (e.g. SE) we keep score/RAM inline in the HUD instead
    /// of flanking the top, so nothing overlaps or is lost.
    private var hasIslandOrNotch: Bool {
        #if canImport(UIKit)
        let top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return top >= 40
        #else
        return false
        #endif
    }

    /// What the Data Core arc tracks. During Fever it drains with the burst timer
    /// (the core IS the Fever readout); otherwise campaign → target, endless →
    /// Fever charge, Flow → a repeating "combo ring" (fills every comboThreshold
    /// decodes, then resets) so the centerpiece reacts to play even without a goal.
    private var coreProgress: Double {
        let s = model.snapshot
        if s.feverActive { return s.feverFraction }
        guard chill else { return core != nil ? s.targetProgress : s.comboProgress }
        let t = max(1, s.comboThreshold)
        let cyc = s.combo % t
        return (s.combo > 0 && cyc == 0) ? 1 : Double(cyc) / Double(t)
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            if chill {
                ChillAtmosphere().ignoresSafeArea()
            }
            FeverAtmosphere(active: model.snapshot.feverActive && !model.snapshot.isGameOver).ignoresSafeArea()

            VStack(spacing: 0) {
                HUDView(snapshot: model.snapshot, coreName: core?.name, chill: chill)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Big score sits right above the Data Core (the score is what you
                // watch). The core fills the rest of the gap and keeps the grid down
                // in the thumb-reach zone (a flexible slot it sizes itself into).
                VStack(spacing: 6) {
                    BigScoreView(snapshot: model.snapshot)
                    DataCoreView(progress: coreProgress,
                                 feverActive: model.snapshot.feverActive,
                                 label: chill ? "FLOW"
                                       : model.snapshot.feverActive ? "FEVER"
                                       : core != nil ? "DECRYPT" : "CHARGE",
                                 decodeToken: model.snapshot.score,
                                 reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.vertical, 8)

                GridBoard(snapshot: model.snapshot,
                          reduceMotion: reduceMotion,
                          effectSeq: model.effectSeq,
                          drainEffects: model.drainEffects,
                          onTap: { model.tap(cell: $0) })
                .padding(.horizontal, 16)

                Spacer(minLength: 12).frame(maxHeight: 96)
            }
            .modifier(ShakeEffect(animatableData: shakeAnim))

            // Score + RAM time framing the Dynamic Island / notch. Only on devices
            // that have one — flat-top devices keep score/RAM inline in the HUD.
            if hasIslandOrNotch && !model.snapshot.isGameOver {
                IslandFrameRow(snapshot: model.snapshot, chill: chill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
                    .ignoresSafeArea(.container, edges: .top)
                    .allowsHitTesting(false)
            }

            // Tap trail (over the grid, under the banners/overlays).
            TrailLayer(points: trailPoints, skin: TrailSkins.equipped, lifetime: 0.45)

            // Fever is announced by the Data Core itself (gold surge + draining arc)
            // and the gold ×N on the score — no separate banner (it'd overlap them).

            // Pause button (bottom-leading, out of the way of the grid).
            if !model.snapshot.isGameOver && !model.isPaused {
                Button { model.pause() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NeonTheme.textDim)
                        .frame(width: 44, height: 44)
                        .background(Circle().stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(TerminalButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 24)
                .padding(.bottom, 28)
            }

            if model.isPaused {
                PauseOverlay(onResume: { model.unpause() }, onQuit: onExit)
            }

            if model.snapshot.isGameOver {
                GameOverOverlay(snapshot: model.snapshot,
                                core: core,
                                outcome: outcome,
                                isFinalCore: core.map { $0.id >= Campaign.count } ?? false,
                                onReplay: { outcome = nil; model.restart(seed: GameView.freshSeed()) },
                                onNext: (model.snapshot.didWin && onNext != nil) ? onNext : nil,
                                onExit: onExit)
            }

            // Per-frame driver — runs outside the render pass via onChange.
            TimelineView(.animation) { context in
                Color.clear
                    .onChange(of: context.date) { _, newDate in
                        model.advance(to: newDate)
                        if !trailPoints.isEmpty {       // fade/prune the tap trail
                            trailPoints.removeAll { newDate.timeIntervalSince($0.born) > 0.45 }
                        }
                    }
            }
            .allowsHitTesting(false)
        }
        .onAppear { model.reduceMotion = reduceMotion; AudioEngine.shared.resume() }
        .onChange(of: reduceMotion) { _, new in model.reduceMotion = new }
        .onChange(of: model.snapshot.isGameOver) { _, over in
            if over, outcome == nil {
                outcome = recordSession(model.snapshot.score, model.snapshot.didWin)
            }
        }
        .onChange(of: model.shakeTrigger) { _, _ in
            guard !reduceMotion else { return }
            shakeAnim = 0
            withAnimation(.easeOut(duration: 0.4)) { shakeAnim = 1 }
        }
        .animation(.easeInOut(duration: 0.3), value: model.snapshot.feverActive)
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
    var chill: Bool = false

    private var ramColor: Color {
        snapshot.ramFraction > 0.5 ? NeonTheme.cyan
        : snapshot.ramFraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer(minLength: 100)   // score now lives above the core; keep RAM by the Island
            if chill {
                // No clock in Flow — a calm marker instead of RAM time.
                VStack(alignment: .trailing, spacing: 0) {
                    Text("MODE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                    Text("⌁ FLOW")
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.magenta)
                        .neonGlow(NeonTheme.magenta, radius: 5)
                }
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("RAM")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                    Text("\(Int(ceil(max(0, snapshot.ramRemaining))))s")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(ramColor)
                        .neonGlow(ramColor, radius: 6)
                        .monospacedDigit()
                }
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

/// Renders the equipped tap-trail skin as a fading comet of dots along the recent
/// touch path. Non-interactive; fed by a simultaneous drag on the game root so it
/// never steals cell taps.
private struct TrailLayer: View {
    let points: [TrailPoint]
    let skin: TrailSkin
    let lifetime: TimeInterval

    var body: some View {
        if !skin.isOff {
            let color = skin.color()
            ZStack {
                ForEach(points) { p in
                    let fade = max(0, 1 - Date().timeIntervalSince(p.born) / lifetime)
                    dot(color: color, fade: CGFloat(fade)).position(p.pos)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func dot(color: Color, fade: CGFloat) -> some View {
        let sz = skin.size * (0.45 + 0.55 * fade)
        Group {
            switch skin.dot {
            case .circle:  Circle().fill(color)
            case .square:  RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color)
            case .diamond: Rectangle().fill(color).rotationEffect(.degrees(45))
            }
        }
        .frame(width: sz, height: sz)
        .opacity(Double(fade) * 0.9)
        .neonGlow(color, radius: 4)
    }
}

// MARK: - Data Core (reactive centerpiece + ambient scanner)

/// Fills the space between the HUD and the grid: a neon "data core" you're cracking.
/// The progress arc tracks Fever charge (endless) or the target (campaign); it
/// pulses on each decode and surges gold during Fever. Two slow counter-rotating
/// dashed rings give the ambient "scanner is alive" feel. Sizes to its slot, so it
/// shrinks gracefully on small screens. Purely presentational.
private struct DataCoreView: View {
    let progress: Double        // 0…1 (fever charge / target / Flow combo ring)
    let feverActive: Bool
    let label: String
    let decodeToken: Int        // changes per decode → pulse
    let reduceMotion: Bool

    @State private var spin: Double = 0
    @State private var pulse: CGFloat = 1

    private var tint: Color { feverActive ? NeonTheme.gold : NeonTheme.cyan }

    var body: some View {
        GeometryReader { geo in
            let s = max(70, min(min(geo.size.width, geo.size.height) - 12, 180))
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
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
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

    var body: some View {
        VStack(spacing: 0) {
            Text("SCORE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .tracking(3)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(snapshot.score)")
                    .font(.system(size: 46, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 10)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if snapshot.scoreMultiplier > 1 {
                    Text("×\(snapshot.scoreMultiplier)")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 7)
                }
            }
            if snapshot.shieldCharges > 0 {
                Label("\(snapshot.shieldCharges)", systemImage: "shield.fill")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .padding(.top, 2)
            }
        }
        .animation(.easeOut(duration: 0.25), value: snapshot.score)
    }
}

// MARK: - HUD

private struct HUDView: View {
    let snapshot: SessionSnapshot
    var coreName: String? = nil
    /// Flow mode hides the pressure HUD (RAM bar + combo meter).
    var chill: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if let target = snapshot.targetScore {
                VStack(spacing: 4) {
                    HStack {
                        Text(coreName ?? "DATA CORE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(NeonTheme.gold)
                        Spacer()
                        Text("\(snapshot.score) / \(target)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
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
            }
            // SCORE/RAM live in the IslandFrameRow up top; Fever charge now lives in
            // the Data Core. Here we keep just the RAM bar (hidden in Flow).
            if !chill {
                RAMBar(fraction: snapshot.ramFraction)
            }
        }
    }
}

/// The RAM time buffer — the core resource. Shifts cyan → red as it drains.
private struct RAMBar: View {
    let fraction: Double

    private var color: Color {
        fraction > 0.5 ? NeonTheme.cyan
        : fraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("RAM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
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
            .frame(height: 12)
        }
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
                                         feverActive: snapshot.feverActive)
                                    // Whole cell is tappable → hitbox is generously
                                    // larger than the sprite (brief §10.7 tolerance).
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(index) }
                            }
                        }
                    }
                }
                .animation(.easeOut(duration: 0.12), value: snapshot.nodes.map(\.id))

                EffectsLayer(cols: cols, cell: cell, spacing: spacing,
                             reduceMotion: reduceMotion, seq: effectSeq, drain: drainEffects)
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

    var body: some View {
        ZStack {
            // Empty socket.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
            if let node {
                NodeSprite(node: node, feverActive: feverActive)
                    .padding(size * 0.16)   // sprite smaller than the tap cell
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .id(node.id)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Visual for one daemon/bomb. Mechanics live in the model — this only draws.
/// During fever, daemons render as golden bonus nodes (brief §10.2).
private struct NodeSprite: View {
    let node: GridNode
    let feverActive: Bool

    var body: some View {
        if feverActive && node.type != .firewallBomb {
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
            }
        }
    }

    private func sprite(color: Color, symbol: String, ringed: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ringed ? 3 : 2)
                .neonGlow(color, radius: 8)
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .neonGlow(color, radius: 4)
        }
    }
}

// MARK: - Game over

private struct PauseOverlay: View {
    let onResume: () -> Void
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
                HStack(spacing: 14) {
                    TerminalButton(title: "RESUME", color: NeonTheme.cyan, action: onResume)
                    TerminalButton(title: "QUIT", color: NeonTheme.magenta, action: onQuit)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
    }
}

private struct GameOverOverlay: View {
    let snapshot: SessionSnapshot
    let core: DataCore?
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
                    Text("◆ NEW HIGH SCORE ◆")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 8)
                }

                Text(core != nil ? "DECODED: \(snapshot.score) / \(core?.targetScore ?? 0)"
                                 : "DATA DECODED: \(snapshot.score)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .padding(.top, 2)
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
