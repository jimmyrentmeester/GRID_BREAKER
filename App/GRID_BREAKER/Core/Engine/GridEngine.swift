import Foundation

// MARK: - Deterministic RNG

/// SplitMix64 — a small, fast, seedable RNG. A given seed replays identically,
/// which is what makes spawn sequences reproducible for QA (ground-truth Part 5.1)
/// while keeping mechanics deterministic (brief §10.3).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Events & outcomes

/// Why a session ended.
enum GameOverReason: String, Sendable {
    case ramDepleted   // the RAM time buffer ran out
    case firewallHit   // the player tapped an active firewall bomb
    case coreCracked   // campaign: reached the target score (a WIN)
}

/// Things that happened during a tick/tap. The shell turns these into juice
/// (M2) — every flourish traces back to one of these real events (Part 2.5).
enum GameEvent: Sendable, Equatable {
    case nodeDecoded(NodeType, cell: Int)   // a daemon fully cleared
    case nodeBreached(cell: Int)            // armored daemon's shell cracked (1st tap)
    case nodeExpired(NodeType, cell: Int)   // a daemon timed out (penalty)
    case emptyMiss(cell: Int)               // tapped an empty cell (penalty)
    case missAbsorbed(cell: Int)            // a miss eaten by the Failsafe Shield
    case firewallDefused(cell: Int)         // bomb tapped but eaten by the Shield
    case firewallExploded(cell: Int)        // bomb tapped → game over
    case feverStarted                       // combo hit threshold → Fever Mode
    case feverEnded                         // Fever Mode window elapsed
    case gameOver(GameOverReason)
}

// MARK: - Snapshot (what the view renders)

/// Immutable view of the session at one instant. The view renders this and
/// nothing else — it never computes mechanics (ground-truth Part 1.1).
struct SessionSnapshot: Sendable {
    var gridSize: GridSize
    var nodes: [GridNode]
    var score: Int
    var ramRemaining: TimeInterval
    var ramCapacity: TimeInterval
    var shieldCharges: Int
    var combo: Int
    var comboThreshold: Int
    var feverActive: Bool
    var feverFraction: Double          // remaining fever window, 0…1
    var scoreMultiplier: Int           // 1, or feverScoreMultiplier during fever
    var targetScore: Int?              // campaign goal (nil in endless)
    var isGameOver: Bool
    var gameOverReason: GameOverReason?

    /// Campaign win.
    var didWin: Bool { gameOverReason == .coreCracked }

    /// Progress toward the campaign target, 0…1 (for the goal bar).
    var targetProgress: Double {
        guard let t = targetScore, t > 0 else { return 0 }
        return min(1, Double(score) / Double(t))
    }

    var ramFraction: Double {
        guard ramCapacity > 0 else { return 0 }
        return min(1, max(0, ramRemaining / ramCapacity))
    }

    /// Progress toward the next fever trigger, 0…1 (for the combo meter).
    var comboProgress: Double {
        guard comboThreshold > 0 else { return 0 }
        return min(1, Double(combo) / Double(comboThreshold))
    }
}

// MARK: - Engine (the authority)

/// Deterministic authority over a single play session.
///
/// Owns all mechanics: spawning, expiry, hit resolution, RAM, score, game-over.
/// The view forwards raw taps and renders `snapshot`; it never mutates state
/// directly (ground-truth Part 1.1). Hits register locally with no latency.
struct GridEngine {
    let config: GameConfig
    let gridSize: GridSize
    /// Campaign target score (nil = endless). Reaching it wins the core.
    let targetScore: Int?
    /// Difficulty offset: scaling is computed from `score + difficultyBias`, so a
    /// campaign core can start at a faster pace without inflating the score.
    let difficultyBias: Int

    private var rng: SeededRNG
    private var clock: TimeInterval = 0          // accumulated session seconds
    private var timeSinceLastSpawn: TimeInterval = 0

    private(set) var score: Int = 0
    private(set) var ramRemaining: TimeInterval
    private let ramCapacity: TimeInterval
    private(set) var shieldCharges: Int
    private let decodeTimeBonus: TimeInterval
    private(set) var nodes: [GridNode] = []
    private(set) var combo: Int = 0
    private(set) var feverActive = false
    private var feverRemaining: TimeInterval = 0
    private(set) var isGameOver = false
    private(set) var gameOverReason: GameOverReason?

    init(config: GameConfig = .default,
         deck: Cyberdeck = .starter,
         gridSize: GridSize = .threeByThree,
         seed: UInt64,
         targetScore: Int? = nil,
         difficultyBias: Int = 0) {
        self.config = config
        self.gridSize = gridSize
        self.targetScore = targetScore
        self.difficultyBias = difficultyBias
        self.rng = SeededRNG(seed: seed)
        self.ramCapacity = config.ramCapacity(for: deck)
        self.ramRemaining = config.ramCapacity(for: deck)
        self.shieldCharges = deck.shieldLevel
        self.decodeTimeBonus = config.decodeTimeBonus(for: deck)
    }

    var snapshot: SessionSnapshot {
        SessionSnapshot(
            gridSize: gridSize,
            nodes: nodes,
            score: score,
            ramRemaining: ramRemaining,
            ramCapacity: ramCapacity,
            shieldCharges: shieldCharges,
            combo: combo,
            comboThreshold: config.feverComboThreshold,
            feverActive: feverActive,
            feverFraction: feverActive && config.feverDuration > 0
                ? max(0, feverRemaining / config.feverDuration) : 0,
            scoreMultiplier: feverActive ? config.feverScoreMultiplier : 1,
            targetScore: targetScore,
            isGameOver: isGameOver,
            gameOverReason: gameOverReason
        )
    }

    /// Score used for difficulty scaling (campaign cores can start faster).
    private var scaledScore: Int { score + difficultyBias }

    // MARK: Per-frame update

    /// Advance the simulation by `deltaTime` seconds. Returns the events that
    /// occurred (for the juice layer). Safe to call with any positive dt.
    mutating func tick(deltaTime: TimeInterval) -> [GameEvent] {
        guard !isGameOver, deltaTime > 0 else { return [] }
        var events: [GameEvent] = []
        clock += deltaTime

        // 0. Fever window countdown.
        if feverActive {
            feverRemaining -= deltaTime
            if feverRemaining <= 0 {
                feverActive = false
                feverRemaining = 0
                combo = 0
                events.append(.feverEnded)
            }
        }

        // 1. Drain the RAM buffer.
        ramRemaining -= config.ramDrainPerSecond * deltaTime

        // 2. Expire timed-out nodes. Daemons penalize + break combo; bombs vanish safely.
        let expired = nodes.filter { clock >= $0.expiresAt }
        for node in expired where node.type.isHarvestable {
            ramRemaining -= config.penaltyExpiredDaemon
            combo = 0
            events.append(.nodeExpired(node.type, cell: node.cellIndex))
        }
        if !expired.isEmpty {
            let goneIDs = Set(expired.map(\.id))
            nodes.removeAll { goneIDs.contains($0.id) }
        }

        // 3. Spawn new nodes on cadence. Fever: faster + fuller, golden-only.
        timeSinceLastSpawn += deltaTime
        let interval = feverActive ? config.feverSpawnInterval : config.spawnInterval(atScore: scaledScore)
        let target = feverActive
            ? min(gridSize.cellCount, config.feverActiveNodes)
            : config.targetActiveNodes(atScore: scaledScore, gridSize: gridSize)
        while timeSinceLastSpawn >= interval, nodes.count < target,
              let node = spawnNode() {
            nodes.append(node)
            timeSinceLastSpawn -= interval
        }

        // 4. RAM depletion ends the run.
        if ramRemaining <= 0 {
            ramRemaining = 0
            events.append(endGame(.ramDepleted))
        }
        return events
    }

    // MARK: Input

    /// Resolve a tap on a grid cell. Returns the resulting events.
    mutating func handleTap(cellIndex: Int) -> [GameEvent] {
        guard !isGameOver else { return [] }

        guard let idx = nodes.firstIndex(where: { $0.cellIndex == cellIndex }) else {
            // Empty cell — a miss, unless the shield absorbs it.
            if shieldCharges > 0 {
                shieldCharges -= 1
                return [.missAbsorbed(cell: cellIndex)]
            }
            combo = 0
            ramRemaining -= config.penaltyMiss
            var events: [GameEvent] = [.emptyMiss(cell: cellIndex)]
            if ramRemaining <= 0 { ramRemaining = 0; events.append(endGame(.ramDepleted)) }
            return events
        }

        switch nodes[idx].type {
        case .firewallBomb:
            let cell = nodes[idx].cellIndex
            nodes.remove(at: idx)
            // The Failsafe Shield eats a bomb tap (your worst mistake), no game over.
            if shieldCharges > 0 {
                shieldCharges -= 1
                return [.firewallDefused(cell: cell)]
            }
            return [.firewallExploded(cell: cell), endGame(.firewallHit)]

        case .standardDaemon:
            return [decode(at: idx)] + checkFever() + checkTarget()

        case .armoredDaemon:
            if nodes[idx].hitsRemaining > 1 {
                nodes[idx].hitsRemaining -= 1   // breach the shell
                return [.nodeBreached(cell: nodes[idx].cellIndex)]
            } else {
                return [decode(at: idx)] + checkFever() + checkTarget()
            }
        }
    }

    /// Campaign win: reaching the target score cracks the core.
    private mutating func checkTarget() -> [GameEvent] {
        guard !isGameOver, let target = targetScore, score >= target else { return [] }
        return [endGame(.coreCracked)]
    }

    /// Start Fever Mode if a fresh decode pushed the combo to threshold.
    /// On trigger: hazards vanish (bombs removed safely), window resets.
    private mutating func checkFever() -> [GameEvent] {
        guard config.feverEnabled, !feverActive, combo >= config.feverComboThreshold else { return [] }
        feverActive = true
        feverRemaining = config.feverDuration
        combo = 0
        nodes.removeAll { $0.type == .firewallBomb }
        return [.feverStarted]
    }

    // MARK: Helpers

    /// Fully clear the daemon at `idx`: bump combo, award score (×fever) + RAM, remove.
    private mutating func decode(at idx: Int) -> GameEvent {
        let node = nodes[idx]
        combo += 1
        let multiplier = feverActive ? config.feverScoreMultiplier : 1
        switch node.type {
        case .standardDaemon:
            score += config.scoreStandard * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusStandardDecode + decodeTimeBonus)
        case .armoredDaemon:
            score += config.scoreArmored * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusArmoredDecode + decodeTimeBonus)
        case .firewallBomb:
            break // never decoded
        }
        nodes.remove(at: idx)
        return .nodeDecoded(node.type, cell: node.cellIndex)
    }

    /// Procedurally pick a free cell + a node type (seeded). Nil if grid full.
    /// During fever only golden bonus daemons (standard) spawn — no hazards.
    private mutating func spawnNode() -> GridNode? {
        let occupied = Set(nodes.map(\.cellIndex))
        let free = (0..<gridSize.cellCount).filter { !occupied.contains($0) }
        guard let cell = free.randomElement(using: &rng) else { return nil }

        let type: NodeType
        if feverActive {
            type = .standardDaemon
        } else {
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < config.firewallSpawnChance {
                type = .firewallBomb
            } else if roll < config.firewallSpawnChance + config.armoredSpawnChance {
                type = .armoredDaemon
            } else {
                type = .standardDaemon
            }
        }

        return GridNode(cellIndex: cell,
                        type: type,
                        lifespan: config.nodeLifespan(atScore: scaledScore),
                        spawnedAt: clock)
    }

    private mutating func endGame(_ reason: GameOverReason) -> GameEvent {
        isGameOver = true
        gameOverReason = reason
        // End fever too, so the fever atmosphere/banner doesn't stick on the
        // game-over screen (ending mid-fever otherwise froze the visuals — tick()
        // returns early once the game is over and never clears it).
        feverActive = false
        feverRemaining = 0
        return .gameOver(reason)
    }
}
