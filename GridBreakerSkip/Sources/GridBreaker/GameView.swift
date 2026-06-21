import SwiftUI

// MARK: - Playable session (M2 + visual parity)
//
// Skip-native rendering of a GRID_BREAKER session, mirroring the iOS GameView layout
// (HUD → big score → DataCore charge ring → grid) as closely as Skip allows. The iOS
// version uses Canvas + TimelineView (both absent in SkipUI), so the loop is a
// Task.sleep clock with real dt, and Canvas effects are rebuilt with Shapes.

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
    @State private var decodeRun: Int = 0      // arpeggio step for chained decodes

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

            VStack(spacing: 0) {
                HUDView(snapshot: snap)
                    .padding(.horizontal, 20).padding(.top, 8)

                VStack(spacing: 6) {
                    BigScoreView(snapshot: snap)
                    if snap.targetScore == nil && snap.streakMultiplier > 1 && !snap.isGameOver {
                        StreakBadge(multiplier: snap.streakMultiplier)
                    }
                    DataCoreView(progress: coreProgress,
                                 feverActive: snap.feverActive,
                                 label: snap.freezeActive ? "FREEZE"
                                       : snap.overclockActive ? "OVERCLOCK"
                                       : snap.feverActive ? "FEVER"
                                       : snap.targetScore != nil ? "DECRYPT" : "CHARGE",
                                 decodeToken: snap.score)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                }
                .padding(.vertical, 8)

                grid.padding(.horizontal, 16)

                Spacer(minLength: 12).frame(maxHeight: 96)

                footer.padding(.horizontal, 20).padding(.bottom, 8)
            }

            if snap.isGameOver { gameOverOverlay }
        }
        .preferredColorScheme(.dark)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)   // ~30fps; real dt keeps speed correct
                step()
            }
        }
    }

    /// DataCore ring progress: campaign target progress, else fever charge.
    private var coreProgress: Double {
        snap.targetScore != nil ? snap.targetProgress : snap.comboProgress
    }

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
                ForEach(0..<rows) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols) { col in
                            let index = row * cols + col
                            CellView(node: byCell[index], size: cell,
                                     feverActive: snap.feverActive,
                                     isZone: snap.dmzZone.contains(index),
                                     flashing: flashCell == index)
                                .frame(width: cell, height: cell)
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

    private var footer: some View {
        HStack {
            Button("◂ MENU") { onExit() }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
                .buttonStyle(.plain)
            Spacer()
            Text(modeLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan.opacity(0.4))
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text(snap.didWin ? "CORE CRACKED" : "DISCONNECTED")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(snap.didWin ? NeonTheme.gold : NeonTheme.danger)
                .neonGlow(snap.didWin ? NeonTheme.gold : NeonTheme.danger, radius: 10)
            Text("SCORE \(snap.score)")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
            HStack(spacing: 14) {
                TerminalButton(title: "RECONNECT", color: NeonTheme.cyan) { restart() }
                TerminalButton(title: "JACK OUT", color: NeonTheme.magenta) { onExit() }
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
        let events = engine.tick(deltaTime: dt)
        process(events)
        snap = engine.snapshot
    }

    private func tap(_ index: Int) {
        guard !snap.isGameOver else { return }
        let events = engine.handleTap(cellIndex: index)
        flashCell = index
        process(events)
        snap = engine.snapshot
    }

    /// Map engine events to audio + haptics (mirrors the iOS juice layer).
    private func process(_ events: [GameEvent]) {
        for e in events {
            switch e {
            case let .nodeDecoded(type, _):
                switch type {
                case NodeType.armoredDaemon: Haptics.impact(.medium); AudioEngine.shared.play(.decodeArmored)
                case NodeType.dataCache:     Haptics.impact(.medium); AudioEngine.shared.play(.decodeBig)
                case NodeType.wormDaemon:    Haptics.impact(.light);  AudioEngine.shared.play(.decodeWorm)
                default:                     Haptics.impact(.light);  AudioEngine.shared.play(.decode, step: decodeRun)
                }
                decodeRun += 1
            case .nodeBreached:        Haptics.impact(.soft);  AudioEngine.shared.play(.breach)
            case .emptyMiss:           decodeRun = 0; Haptics.impact(.rigid); AudioEngine.shared.play(.miss)
            case .nodeExpired:         decodeRun = 0; Haptics.impact(.rigid); AudioEngine.shared.play(.miss)
            case .missAbsorbed:        Haptics.impact(.soft);  AudioEngine.shared.play(.breach)
            case .firewallDefused:     Haptics.impact(.medium); AudioEngine.shared.play(.decodeBig)
            case .firewallExploded:    decodeRun = 0; Haptics.error(); AudioEngine.shared.play(.bomb)
            case .feverStarted:        Haptics.success(); AudioEngine.shared.play(.fever)
            case .feverEnded:          Haptics.impact(.soft)
            case .ramCritical:         Haptics.impact(.rigid); AudioEngine.shared.play(.ramLow)
            case .gridExpanded:        Haptics.success(); AudioEngine.shared.play(.fever)
            case .powerUpCollected:    Haptics.success(); AudioEngine.shared.play(.fever)
            case .milestoneReached:    Haptics.success(); AudioEngine.shared.play(.fever)
            case .daemonSetSpawned:    Haptics.impact(.soft); AudioEngine.shared.play(.breach)
            case .daemonSetAdvanced:   break
            case .daemonSetCompleted:  Haptics.impact(.rigid); AudioEngine.shared.play(.decodeBig)
            case .daemonSetWrongOrder: decodeRun = 0; Haptics.impact(.rigid); AudioEngine.shared.play(.miss)
            case .dmzSpawned:          Haptics.impact(.medium); AudioEngine.shared.play(.breach)
            case .intrusionCleared:    Haptics.impact(.light); AudioEngine.shared.play(.decode)
            case .dmzOverrunSpawned:   Haptics.impact(.soft); AudioEngine.shared.play(.breach)
            case .dmzPurged:           Haptics.success(); AudioEngine.shared.play(.fever)
            case .gameOver:            Haptics.error(); AudioEngine.shared.play(.gameOver)
            }
        }
    }

    private func restart() {
        let e = GridEngine(config: config, deck: .starter, gridSize: .threeByThree,
                           seed: seed, targetScore: targetScore, difficultyBias: difficultyBias)
        engine = e
        snap = e.snapshot
        lastTickAt = 0
        decodeRun = 0
    }
}

// MARK: - HUD (RAM bar + campaign target bar)

private struct HUDView: View {
    let snapshot: SessionSnapshot

    var body: some View {
        VStack(spacing: 8) {
            if let target = snapshot.targetScore {
                VStack(spacing: 4) {
                    HStack {
                        Text("DATA CORE")
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
                                .frame(width: clampW(geo.size.width * snapshot.targetProgress))
                                .neonGlow(NeonTheme.gold, radius: 5)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.bottom, 2)
            }
            RAMBar(fraction: snapshot.ramFraction)
        }
    }
}

private struct RAMBar: View {
    let fraction: Double

    private var color: Color {
        fraction > 0.5 ? NeonTheme.cyan : (fraction > 0.25 ? NeonTheme.gold : NeonTheme.danger)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("RAM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: clampW(geo.size.width * fraction))
                        .neonGlow(color, radius: 6)
                }
            }
            .frame(height: 12)
        }
    }
}

private func clampW(_ w: CGFloat) -> CGFloat { w < 0.0 ? 0.0 : w }

// MARK: - Big score

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
                if snapshot.scoreMultiplier > imaxI(1, snapshot.streakMultiplier) {
                    Text("×\(snapshot.scoreMultiplier)")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NeonTheme.gold)
                        .neonGlow(NeonTheme.gold, radius: 7)
                }
            }
            if let next = snapshot.nextMilestone, !snapshot.isGameOver {
                Text("NEXT ◆ \(next)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                    .padding(.top, 1)
            }
        }
    }
}

private func imaxI(_ a: Int, _ b: Int) -> Int { a > b ? a : b }

private struct StreakBadge: View {
    let multiplier: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: sfSym("flame.fill")).font(.system(size: 11, weight: .bold))
            Text("STREAK ×\(multiplier)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(NeonTheme.gold)
        .neonGlow(NeonTheme.gold, radius: 4)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(NeonTheme.gold.opacity(0.12))
            .overlay(Capsule().stroke(NeonTheme.gold.opacity(0.5), lineWidth: 1)))
    }
}

// MARK: - DataCore charge ring (Canvas-free; spinning dashed rings + progress trim)

private struct DataCoreView: View {
    let progress: Double
    let feverActive: Bool
    let label: String
    let decodeToken: Int

    @State private var spin: Double = 0

    private var tint: Color { feverActive ? NeonTheme.gold : NeonTheme.cyan }

    var body: some View {
        GeometryReader { geo in
            let mn = geo.size.width < geo.size.height ? geo.size.width : geo.size.height
            let raw = mn - 12.0
            let s: CGFloat = raw < 70.0 ? 70.0 : (raw > 180.0 ? 180.0 : raw)
            ZStack {
                Circle()
                    .stroke(NeonTheme.gridLineDim.opacity(0.35), style: StrokeStyle(lineWidth: 1.0, dash: [2.0, 14.0]))
                    .frame(width: s, height: s)
                    .rotationEffect(.degrees(-spin * 0.6))
                Circle()
                    .stroke(tint.opacity(0.40), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 12.0]))
                    .frame(width: s * 0.86, height: s * 0.86)
                    .rotationEffect(.degrees(spin))
                Circle().stroke(tint.opacity(0.15), lineWidth: 3.0).frame(width: s * 0.6, height: s * 0.6)
                Circle()
                    .trim(from: 0, to: progressClamped)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
                    .frame(width: s * 0.6, height: s * 0.6)
                    .rotationEffect(.degrees(-90))
                    .neonGlow(tint, radius: 5)
                VStack(spacing: 3) {
                    Hexagon().stroke(tint, lineWidth: 2)
                        .frame(width: s * 0.18, height: s * 0.18)
                        .neonGlow(tint, radius: 6)
                    Text(label)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeonTheme.textDim)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = 360 } }
    }

    private var progressClamped: Double {
        let p = progress
        if p < 0.0001 { return 0.0001 }
        return p > 1.0 ? 1.0 : p
    }
}

// MARK: - Cell + node sprite (rounded-rect tile + ring + glyph, mirroring iOS NodeSprite)

private struct CellView: View {
    let node: GridNode?
    let size: CGFloat
    let feverActive: Bool
    let isZone: Bool
    let flashing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NeonTheme.gridLineDim.opacity(0.5), lineWidth: 1)
            if isZone {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NeonTheme.danger.opacity(0.10))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NeonTheme.danger.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6.0, 4.0]))
                    .neonGlow(NeonTheme.danger, radius: 6)
            }
            if let node = node {
                NodeSprite(node: node, feverActive: feverActive, cell: size)
                    .padding(size * 0.16)
            }
        }
    }
}

/// One node's sprite: a ringed rounded-rect tile + a glyph, matching the iOS NodeSprite
/// structure. Glyphs use sfSym (SF Symbols → Material substitutes on Android).
private struct NodeSprite: View {
    let node: GridNode
    let feverActive: Bool
    let cell: CGFloat

    private var glyph: CGFloat { cell * 0.22 }
    private var ring: CGFloat { cell * 0.022 < 2.0 ? 2.0 : cell * 0.022 }

    var body: some View {
        if let order = node.setOrder, let n = node.setSize {
            setSprite(order: order, of: n)
        } else if feverActive && node.type != .firewallBomb {
            tile(color: NeonTheme.gold, symbol: "bolt.fill", ringed: true)
        } else {
            switch node.type {
            case .standardDaemon: tile(color: NeonTheme.cyan, symbol: "circle.grid.cross.fill", ringed: false)
            case .armoredDaemon:  tile(color: node.isBreached ? NeonTheme.gold : NeonTheme.magenta,
                                       symbol: node.isBreached ? "lock.open.fill" : "lock.shield.fill", ringed: !node.isBreached)
            case .firewallBomb:   tile(color: NeonTheme.danger, symbol: "exclamationmark.triangle.fill", ringed: false)
            case .dataCache:      tile(color: NeonTheme.gold, symbol: "square.stack.3d.up.fill", ringed: true)
            case .wormDaemon:     tile(color: NeonTheme.worm, symbol: "scribble.variable", ringed: true)
            case .powerUp:        tile(color: NeonTheme.textPrimary, symbol: powerSymbol(node.powerKind), ringed: true)
            case .intrusion:      tile(color: NeonTheme.danger, symbol: "hexagon.fill", ringed: true)
            }
        }
    }

    private func powerSymbol(_ kind: PowerUpKind?) -> String {
        switch kind {
        case .timeFreeze: return "snowflake"
        case .overclock:  return "bolt.fill"
        case .purge:      return "wind"
        case nil:         return "sparkles"   // Skip: optional nil-case is `case nil`, not `.none`
        }
    }

    private func tile(color: Color, symbol: String, ringed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ringed ? ring * 1.4 : ring)
                .neonGlow(color, radius: 8)
            Image(systemName: sfSym(symbol))
                .font(.system(size: glyph, weight: .bold))
                .foregroundStyle(color)
                .neonGlow(color, radius: 4)
        }
    }

    private func setSprite(order: Int, of n: Int) -> some View {
        let color = NeonTheme.cyan
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color, lineWidth: ring * 1.25)
                .neonGlow(color, radius: 8)
            VStack(spacing: cell * 0.03) {
                Text("\(order)")
                    .font(.system(size: glyph * 0.95, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
                    .neonGlow(color, radius: 4)
                HStack(spacing: cell * 0.03) {
                    ForEach(0..<n) { i in
                        Circle()
                            .fill(i < order ? color : color.opacity(0.25))
                            .frame(width: cell * 0.045, height: cell * 0.045)
                    }
                }
            }
        }
    }
}

// MARK: - Hexagon shape (DataCore idle glyph)

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let r = (rect.width < rect.height ? rect.width : rect.height) / 2.0
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
