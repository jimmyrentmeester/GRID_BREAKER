import SwiftUI

// MARK: - Playable grid (M2)
//
// A Skip-native rendering of a GRID_BREAKER session. The iOS GameView relies on
// Canvas + TimelineView (both absent in SkipUI), so this is rebuilt from the proven
// portable stack: a Task.sleep game-loop with real dt, the engine as the authority,
// and SwiftUI Shapes + neonGlow for the neon look.

struct GameView: View {
    let config: GameConfig
    let seed: UInt64
    let targetScore: Int?
    let difficultyBias: Int
    let modeLabel: String
    let onExit: () -> Void

    @State private var engine: GridEngine
    @State private var snap: SessionSnapshot
    @State private var lastTickAt: Double = 0
    @State private var flashCell: Int = -1
    @State private var flashSeq: Int = 0

    init(config: GameConfig, seed: UInt64, targetScore: Int? = nil, difficultyBias: Int = 0,
         modeLabel: String = "ENDLESS", onExit: @escaping () -> Void = {}) {
        self.config = config
        self.seed = seed
        self.targetScore = targetScore
        self.difficultyBias = difficultyBias
        self.modeLabel = modeLabel
        self.onExit = onExit
        let e = GridEngine(config: config, deck: .starter, gridSize: .threeByThree,
                           seed: seed, targetScore: targetScore, difficultyBias: difficultyBias)
        _engine = State(initialValue: e)
        _snap = State(initialValue: e.snapshot)
    }

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                hud
                Spacer(minLength: 8)
                grid
                Spacer(minLength: 8)
                footer
            }
            .padding(20)
            // No fixed `.frame(maxWidth: 560)`: on Skip a fixed maxWidth renders as a
            // FIXED width (#47), overflowing a phone. Full width + padding instead.
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if snap.isGameOver {
                gameOverOverlay
            }
        }
        .preferredColorScheme(.dark)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)   // ~30fps (real-dt keeps speed correct)
                step()
            }
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SCORE \(snap.score)")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.gold)
                    .neonGlow(NeonTheme.gold, radius: 6)
                Spacer()
                if snap.feverActive {
                    Text("FEVER ×\(snap.scoreMultiplier)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 8)
                } else if snap.streakMultiplier > 1 {
                    Text("STREAK ×\(snap.streakMultiplier)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.magenta)
                }
            }
            // RAM bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(NeonTheme.cyan.opacity(0.12))
                    Capsule()
                        .fill(ramColor)
                        .frame(width: dmaxW(geo.size.width * snap.ramFraction))
                        .neonGlow(ramColor, radius: 5)
                }
            }
            .frame(height: 12)
            // Combo meter
            Text("COMBO \(snap.combo)/\(snap.comboThreshold)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ramColor: Color {
        snap.ramFraction < 0.25 ? NeonTheme.danger : (snap.feverActive ? NeonTheme.gold : NeonTheme.cyan)
    }

    private func dmaxW(_ w: CGFloat) -> CGFloat { w < 0.0 ? 0.0 : w }

    // MARK: Grid

    private var grid: some View {
        let cols = snap.gridSize.columns
        let rows = snap.gridSize.rows
        var byCell: [Int: GridNode] = [:]
        for node in snap.nodes { byCell[node.cellIndex] = node }

        return GeometryReader { geo in
            let side = geo.size.width < geo.size.height ? geo.size.width : geo.size.height
            let spacing: CGFloat = 10
            let cell = (side - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            CellView(node: byCell[index],
                                     size: cell,
                                     isZone: snap.dmzZone.contains(index),
                                     flashing: flashCell == index)
                                .frame(width: cell, height: cell)
                                // No .contentShape (absent in Skip, #39); the cell's faint
                                // filled well (below) makes the whole frame tappable.
                                .onTapGesture { tap(index) }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("◂ MENU") { onExit() }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
            Spacer()
            Text(modeLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan.opacity(0.4))
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 18) {
            Text(snap.didWin ? "CORE CRACKED" : "DISCONNECTED")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(snap.didWin ? NeonTheme.gold : NeonTheme.danger)
                .neonGlow(snap.didWin ? NeonTheme.gold : NeonTheme.danger, radius: 10)
            Text("SCORE \(snap.score)")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
            HStack(spacing: 14) {
                Button("RECONNECT") { restart() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.background)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(NeonTheme.cyan))
                Button("JACK OUT") { onExit() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(NeonTheme.magenta)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().stroke(NeonTheme.magenta, lineWidth: 1.5))
            }
        }
        .padding(34)
        .background(RoundedRectangle(cornerRadius: 18).fill(NeonTheme.background.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(NeonTheme.cyan.opacity(0.4), lineWidth: 1)))
    }

    // MARK: Loop + input

    private func step() {
        guard !snap.isGameOver else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if lastTickAt == 0.0 { lastTickAt = now; return }
        let dt = now - lastTickAt
        lastTickAt = now
        _ = engine.tick(deltaTime: dt)
        snap = engine.snapshot
    }

    private func tap(_ index: Int) {
        guard !snap.isGameOver else { return }
        _ = engine.handleTap(cellIndex: index)
        flashCell = index
        flashSeq += 1
        snap = engine.snapshot
    }

    private func restart() {
        let e = GridEngine(config: config, deck: .starter, gridSize: .threeByThree,
                           seed: seed, targetScore: targetScore, difficultyBias: difficultyBias)
        engine = e
        snap = e.snapshot
        lastTickAt = 0
    }
}

// MARK: - Cell

private struct CellView: View {
    let node: GridNode?
    let size: CGFloat
    let isZone: Bool
    let flashing: Bool

    var body: some View {
        ZStack {
            // Empty cell well — a faint fill (so the whole cell is a tap target, since
            // SkipUI has no .contentShape) plus the terminal-grid outline.
            RoundedRectangle(cornerRadius: 10)
                .fill(NeonTheme.cyan.opacity(0.05))
            RoundedRectangle(cornerRadius: 10)
                .stroke(isZone ? NeonTheme.danger.opacity(0.8) : NeonTheme.cyan.opacity(0.12),
                        style: StrokeStyle(lineWidth: isZone ? 2.0 : 1.0,
                                           dash: isZone ? [5.0, 4.0] : [CGFloat]()))

            if let node = node {
                sprite(for: node)
            }
        }
    }

    @ViewBuilder
    private func sprite(for node: GridNode) -> some View {
        let d = size * 0.62
        switch node.type {
        case .firewallBomb:
            // never-tap hazard — hostile red diamond
            Diamond()
                .fill(NeonTheme.danger)
                .frame(width: d, height: d)
                .neonGlow(NeonTheme.danger, radius: 9)
        case .armoredDaemon:
            ZStack {
                Circle().fill(node.isBreached ? NeonTheme.magenta.opacity(0.4) : NeonTheme.magenta)
                    .frame(width: d, height: d)
                Circle().stroke(NeonTheme.magenta, lineWidth: 2).frame(width: d * 1.18, height: d * 1.18)
            }
            .neonGlow(NeonTheme.magenta, radius: 8)
        case .dataCache:
            RoundedRectangle(cornerRadius: 5)
                .fill(NeonTheme.gold)
                .frame(width: d, height: d)
                .neonGlow(NeonTheme.gold, radius: 9)
        case .intrusion:
            Hexagon()
                .fill(NeonTheme.danger)
                .frame(width: d, height: d)
                .neonGlow(NeonTheme.danger, radius: 7)
        case .powerUp:
            Circle().fill(NeonTheme.gold)
                .frame(width: d * 0.8, height: d * 0.8)
                .neonGlow(NeonTheme.gold, radius: 10)
        default:
            // standard + worm
            Circle()
                .fill(NeonTheme.cyan)
                .frame(width: d, height: d)
                .neonGlow(NeonTheme.cyan, radius: flashing ? 14.0 : 8.0)
                .overlay(node.isSetMember ? AnyView(setPip(node)) : AnyView(EmptyView()))
        }
    }

    private func setPip(_ node: GridNode) -> some View {
        Text("\(node.setOrder ?? 0)")
            .font(.system(size: size * 0.26, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.background)
    }
}

// MARK: - Shapes (Canvas-free)

private struct Diamond: Shape {
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

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX, cy = rect.midY
        let r = (w < h ? w : h) / 2.0
        var i = 0
        while i < 6 {
            let angle = Double.pi / 3.0 * Double(i) - Double.pi / 2.0
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            i += 1
        }
        p.closeSubpath()
        return p
    }
}
