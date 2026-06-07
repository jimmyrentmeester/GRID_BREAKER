import SwiftUI

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

    private var engine: GridEngine
    private let config: GameConfig
    private let deck: Cyberdeck
    private let gridSize: GridSize
    private var lastDate: Date?
    private var freezeRemaining: TimeInterval = 0   // hit-stop budget
    private var pendingEffects: [JuiceEffect] = []
    private let haptics = Haptics()

    init(config: GameConfig = .default,
         deck: Cyberdeck = .starter,
         gridSize: GridSize = .threeByThree,
         seed: UInt64) {
        self.config = config
        self.deck = deck
        self.gridSize = gridSize
        let engine = GridEngine(config: config, deck: deck, gridSize: gridSize, seed: seed)
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

    /// Called every frame by the TimelineView with the current date.
    func advance(to date: Date) {
        guard !snapshot.isGameOver else { lastDate = date; return }
        defer { lastDate = date }
        guard let last = lastDate else { return }          // first frame: just anchor
        let dt = min(date.timeIntervalSince(last), 1.0 / 20.0)  // clamp big stalls
        guard dt > 0 else { return }
        if freezeRemaining > 0 { freezeRemaining -= dt; return }  // hit-stop: hold the sim
        process(engine.tick(deltaTime: dt))
        snapshot = engine.snapshot
    }

    func tap(cell: Int) {
        guard !snapshot.isGameOver else { return }
        process(engine.handleTap(cellIndex: cell))
        snapshot = engine.snapshot
    }

    func restart(seed: UInt64) {
        engine = GridEngine(config: config, deck: deck, gridSize: gridSize, seed: seed)
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
                    haptics.impact(.medium)
                    if !reduceMotion { freezeRemaining = 0.08 }   // hit-stop on the heavy kill
                } else {
                    haptics.impact(.light)
                }
            case let .nodeBreached(cell):
                pendingEffects.append(.init(cell: cell, style: .breach, color: NeonTheme.magenta, points: nil))
                queued = true
                haptics.impact(.soft)
            case let .emptyMiss(cell):
                pendingEffects.append(.init(cell: cell, style: .miss, color: NeonTheme.danger, points: nil))
                queued = true
                haptics.impact(.rigid)
            case .nodeExpired:
                haptics.impact(.soft)
            case let .missAbsorbed(cell):
                pendingEffects.append(.init(cell: cell, style: .shield, color: NeonTheme.gold, points: nil))
                queued = true
                haptics.impact(.soft)
            case let .firewallExploded(cell):
                pendingEffects.append(.init(cell: cell, style: .bomb, color: NeonTheme.danger, points: nil))
                queued = true
                if !reduceMotion { freezeRemaining = 0.06; shakeTrigger += 1 }
                haptics.error()
            case .gameOver:
                break
            }
        }
        if queued { effectSeq += 1 }
    }
}

// MARK: - Game screen

struct GameView: View {
    @State private var model = GameViewModel(seed: GameView.freshSeed())
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeAnim: CGFloat = 0
    var onExit: () -> Void = {}

    static func freshSeed() -> UInt64 {
        UInt64(bitPattern: Int64(Date().timeIntervalSince1970 * 1000))
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                HUDView(snapshot: model.snapshot)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                GridBoard(snapshot: model.snapshot,
                          reduceMotion: reduceMotion,
                          effectSeq: model.effectSeq,
                          drainEffects: model.drainEffects,
                          onTap: { model.tap(cell: $0) })
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .modifier(ShakeEffect(animatableData: shakeAnim))

            if model.snapshot.isGameOver {
                GameOverOverlay(snapshot: model.snapshot,
                                onReconnect: { model.restart(seed: GameView.freshSeed()) },
                                onExit: onExit)
            }

            // Per-frame driver — runs outside the render pass via onChange.
            TimelineView(.animation) { context in
                Color.clear
                    .onChange(of: context.date) { _, newDate in
                        model.advance(to: newDate)
                    }
            }
            .allowsHitTesting(false)
        }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, new in model.reduceMotion = new }
        .onChange(of: model.shakeTrigger) { _, _ in
            guard !reduceMotion else { return }
            shakeAnim = 0
            withAnimation(.easeOut(duration: 0.4)) { shakeAnim = 1 }
        }
    }
}

// MARK: - HUD

private struct HUDView: View {
    let snapshot: SessionSnapshot

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SCORE")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text("\(snapshot.score)")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .neonGlow(NeonTheme.cyan, radius: 6)
                Spacer()
                if snapshot.shieldCharges > 0 {
                    Label("\(snapshot.shieldCharges)", systemImage: "shield.fill")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                }
            }
            RAMBar(fraction: snapshot.ramFraction)
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
                                CellView(node: nodesByCell[index], size: cell)
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
                NodeSprite(node: node)
                    .padding(size * 0.16)   // sprite smaller than the tap cell
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .id(node.id)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Visual for one daemon/bomb. Mechanics live in the model — this only draws.
private struct NodeSprite: View {
    let node: GridNode

    var body: some View {
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

private struct GameOverOverlay: View {
    let snapshot: SessionSnapshot
    let onReconnect: () -> Void
    let onExit: () -> Void

    private var message: String {
        switch snapshot.gameOverReason {
        case .firewallHit: return "FIREWALL TRIGGERED"
        case .ramDepleted: return "RAM DEPLETED"
        case .none:        return "CONNECTION LOST"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("CONNECTION TERMINATED")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text(message)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.danger)
                    .neonGlow(NeonTheme.danger, radius: 10)
                Text("DATA DECODED: \(snapshot.score)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.cyan)
                    .padding(.top, 4)

                HStack(spacing: 14) {
                    TerminalButton(title: "RECONNECT", color: NeonTheme.cyan, action: onReconnect)
                    TerminalButton(title: "JACK OUT", color: NeonTheme.magenta, action: onExit)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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
    GameView().preferredColorScheme(.dark)
}
