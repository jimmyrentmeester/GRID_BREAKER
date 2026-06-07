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
}

/// Things that happened during a tick/tap. The shell turns these into juice
/// (M2) — every flourish traces back to one of these real events (Part 2.5).
enum GameEvent: Sendable, Equatable {
    case nodeDecoded(NodeType, cell: Int)   // a daemon fully cleared
    case nodeBreached(cell: Int)            // armored daemon's shell cracked (1st tap)
    case nodeExpired(NodeType, cell: Int)   // a daemon timed out (penalty)
    case emptyMiss(cell: Int)               // tapped an empty cell (penalty)
    case missAbsorbed(cell: Int)            // a miss eaten by the Failsafe Shield
    case firewallExploded(cell: Int)        // bomb tapped → game over
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
    var isGameOver: Bool
    var gameOverReason: GameOverReason?

    var ramFraction: Double {
        guard ramCapacity > 0 else { return 0 }
        return min(1, max(0, ramRemaining / ramCapacity))
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

    private var rng: SeededRNG
    private var clock: TimeInterval = 0          // accumulated session seconds
    private var timeSinceLastSpawn: TimeInterval = 0

    private(set) var score: Int = 0
    private(set) var ramRemaining: TimeInterval
    private let ramCapacity: TimeInterval
    private(set) var shieldCharges: Int
    private(set) var nodes: [GridNode] = []
    private(set) var isGameOver = false
    private(set) var gameOverReason: GameOverReason?

    init(config: GameConfig = .default,
         deck: Cyberdeck = .starter,
         gridSize: GridSize = .threeByThree,
         seed: UInt64) {
        self.config = config
        self.gridSize = gridSize
        self.rng = SeededRNG(seed: seed)
        self.ramCapacity = config.ramCapacity(for: deck)
        self.ramRemaining = config.ramCapacity(for: deck)
        self.shieldCharges = deck.shieldLevel
    }

    var snapshot: SessionSnapshot {
        SessionSnapshot(
            gridSize: gridSize,
            nodes: nodes,
            score: score,
            ramRemaining: ramRemaining,
            ramCapacity: ramCapacity,
            shieldCharges: shieldCharges,
            isGameOver: isGameOver,
            gameOverReason: gameOverReason
        )
    }

    // MARK: Per-frame update

    /// Advance the simulation by `deltaTime` seconds. Returns the events that
    /// occurred (for the juice layer). Safe to call with any positive dt.
    mutating func tick(deltaTime: TimeInterval) -> [GameEvent] {
        guard !isGameOver, deltaTime > 0 else { return [] }
        var events: [GameEvent] = []
        clock += deltaTime

        // 1. Drain the RAM buffer.
        ramRemaining -= config.ramDrainPerSecond * deltaTime

        // 2. Expire timed-out nodes. Daemons penalize; bombs vanish safely.
        let expired = nodes.filter { clock >= $0.expiresAt }
        for node in expired {
            if node.type.isHarvestable {
                ramRemaining -= config.penaltyExpiredDaemon
                events.append(.nodeExpired(node.type, cell: node.cellIndex))
            }
        }
        if !expired.isEmpty {
            let goneIDs = Set(expired.map(\.id))
            nodes.removeAll { goneIDs.contains($0.id) }
        }

        // 3. Spawn new nodes on cadence, up to the score-scaled ceiling.
        timeSinceLastSpawn += deltaTime
        let interval = config.spawnInterval(atScore: score)
        let target = config.targetActiveNodes(atScore: score, gridSize: gridSize)
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
            ramRemaining -= config.penaltyMiss
            var events: [GameEvent] = [.emptyMiss(cell: cellIndex)]
            if ramRemaining <= 0 { ramRemaining = 0; events.append(endGame(.ramDepleted)) }
            return events
        }

        switch nodes[idx].type {
        case .firewallBomb:
            let cell = nodes[idx].cellIndex
            nodes.remove(at: idx)
            return [.firewallExploded(cell: cell), endGame(.firewallHit)]

        case .standardDaemon:
            return [decode(at: idx)]

        case .armoredDaemon:
            if nodes[idx].hitsRemaining > 1 {
                nodes[idx].hitsRemaining -= 1   // breach the shell
                return [.nodeBreached(cell: nodes[idx].cellIndex)]
            } else {
                return [decode(at: idx)]
            }
        }
    }

    // MARK: Helpers

    /// Fully clear the daemon at `idx`: award score + RAM time, remove it.
    private mutating func decode(at idx: Int) -> GameEvent {
        let node = nodes[idx]
        switch node.type {
        case .standardDaemon:
            score += config.scoreStandard
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusStandardDecode)
        case .armoredDaemon:
            score += config.scoreArmored
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusArmoredDecode)
        case .firewallBomb:
            break // never decoded
        }
        nodes.remove(at: idx)
        return .nodeDecoded(node.type, cell: node.cellIndex)
    }

    /// Procedurally pick a free cell + a node type (seeded). Nil if grid full.
    private mutating func spawnNode() -> GridNode? {
        let occupied = Set(nodes.map(\.cellIndex))
        let free = (0..<gridSize.cellCount).filter { !occupied.contains($0) }
        guard let cell = free.randomElement(using: &rng) else { return nil }

        let roll = Double.random(in: 0..<1, using: &rng)
        let type: NodeType
        if roll < config.firewallSpawnChance {
            type = .firewallBomb
        } else if roll < config.firewallSpawnChance + config.armoredSpawnChance {
            type = .armoredDaemon
        } else {
            type = .standardDaemon
        }

        return GridNode(cellIndex: cell,
                        type: type,
                        lifespan: config.nodeLifespan(atScore: score),
                        spawnedAt: clock)
    }

    private mutating func endGame(_ reason: GameOverReason) -> GameEvent {
        isGameOver = true
        gameOverReason = reason
        return .gameOver(reason)
    }
}
