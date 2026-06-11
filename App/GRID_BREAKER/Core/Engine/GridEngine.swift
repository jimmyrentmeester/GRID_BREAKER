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
    case ramCritical                        // RAM dipped below the danger line (once per dip)
    case gridExpanded                       // grid grew 3×3 → 4×4 (endless escalation)
    case powerUpCollected(PowerUpKind)      // a power-up pickup was tapped
    case milestoneReached(Int)              // score crossed a landmark (endless)
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
    var cleanStreak: Int               // current clean-decode chain (streak multiplier)
    var streakMultiplier: Int          // base ×N from the clean streak (1 = none)
    var feverActive: Bool
    var feverFraction: Double          // remaining fever window, 0…1
    var scoreMultiplier: Int           // combined fever × overclock multiplier
    var freezeActive: Bool             // time-freeze power-up running
    var overclockActive: Bool          // overclock power-up running
    var targetScore: Int?              // campaign goal (nil in endless)
    var isGameOver: Bool
    var gameOverReason: GameOverReason?
    var elapsed: TimeInterval          // session clock (run recap)
    var bestCleanStreak: Int           // longest clean chain this run (run recap)
    var feversTriggered: Int           // fevers this run (run recap)
    var nextMilestone: Int?            // next score landmark (nil = none/disabled)

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
    /// May grow 3×3 → 4×4 mid-session in endless (score-based escalation).
    private(set) var gridSize: GridSize
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
    private let feverDurationEff: TimeInterval   // base + Fever-Capacitor upgrade
    private(set) var nodes: [GridNode] = []
    private(set) var combo: Int = 0
    /// Clean-decode chain (resets on a miss/expiry) driving the base streak multiplier.
    private(set) var cleanStreak: Int = 0
    /// Longest clean chain this session (run recap).
    private(set) var bestCleanStreak: Int = 0
    /// Whether the low-RAM warning has fired for the current dip (hysteresis:
    /// re-arms once RAM recovers above the re-arm line, so it never spams).
    private var ramWarned = false
    /// Index of the next score milestone to award.
    private var nextMilestoneIndex = 0
    private(set) var feverActive = false
    private var feverRemaining: TimeInterval = 0
    /// Fevers triggered this session — drives the rising threshold (D23).
    private(set) var feversTriggered = 0
    /// The cell a worm most recently vacated (+ when, + which worm) — a tap landing
    /// there within `wormTapGrace` still counts as the worm hit (audit C7).
    private var lastWormVacated: (cell: Int, at: TimeInterval, nodeID: UUID)?
    private var powerFreezeRemaining: TimeInterval = 0     // time-freeze window
    private var powerOverclockRemaining: TimeInterval = 0  // bonus-multiplier window
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
        self.feverDurationEff = config.feverDuration(for: deck)
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
            comboThreshold: feverThresholdEff,
            cleanStreak: cleanStreak,
            streakMultiplier: streakMultiplier,
            feverActive: feverActive,
            feverFraction: feverActive && feverDurationEff > 0
                ? max(0, feverRemaining / feverDurationEff) : 0,
            scoreMultiplier: effectiveMultiplier,
            freezeActive: powerFreezeRemaining > 0,
            overclockActive: powerOverclockRemaining > 0,
            targetScore: targetScore,
            isGameOver: isGameOver,
            gameOverReason: gameOverReason,
            elapsed: clock,
            bestCleanStreak: bestCleanStreak,
            feversTriggered: feversTriggered,
            nextMilestone: nextMilestoneIndex < config.milestoneScores.count
                ? config.milestoneScores[nextMilestoneIndex] : nil
        )
    }

    /// Base multiplier from the clean-decode streak (×1, then +1 per tier crossed).
    var streakMultiplier: Int {
        guard !config.streakTierThresholds.isEmpty else { return 1 }
        return 1 + config.streakTierThresholds.reduce(0) { $0 + (cleanStreak >= $1 ? 1 : 0) }
    }

    /// Combined score multiplier: streak × fever × overclock (each ×N while active).
    private var effectiveMultiplier: Int {
        streakMultiplier
        * (feverActive ? config.feverScoreMultiplier : 1)
        * (powerOverclockRemaining > 0 ? config.overclockMultiplier : 1)
    }

    /// Score used for difficulty scaling (campaign cores can start faster).
    private var scaledScore: Int { score + difficultyBias }

    /// Effective fever threshold: rises per fever already triggered (D23), so a
    /// long run has to *earn* each successive fever. Static when the ramp is off.
    var feverThresholdEff: Int {
        guard config.feverThresholdRampPerFever > 0 else { return config.feverComboThreshold }
        return min(config.feverThresholdMax,
                   config.feverComboThreshold + feversTriggered * config.feverThresholdRampPerFever)
    }

    /// Effective RAM drain multiplier at the current score (1 when the ramp is off).
    private var drainMultiplier: Double {
        guard config.drainRampPerScore > 0 else { return 1 }
        return min(config.drainRampCap, 1 + Double(score) * config.drainRampPerScore)
    }

    /// Effective decode-refill factor at the current score (1 when decay is off).
    /// Applies to the per-node bonuses only — never to the Decode-Speed upgrade.
    private var refillFactor: Double {
        guard config.refillDecayPerScore > 0 else { return 1 }
        return max(config.refillDecayFloor, exp(-config.refillDecayPerScore * Double(score)))
    }

    // MARK: Per-frame update

    /// Advance the simulation by `deltaTime` seconds. Returns the events that
    /// occurred (for the juice layer). Safe to call with any positive dt.
    mutating func tick(deltaTime: TimeInterval) -> [GameEvent] {
        guard !isGameOver, deltaTime > 0 else { return [] }
        var events: [GameEvent] = []

        // Power-up timers run in real time. Time-freeze stops the simulation clock,
        // which pauses node expiry + worm hops automatically; RAM drain and the fever
        // countdown are paused explicitly below. Spawns continue → a safe burst window.
        let frozen = powerFreezeRemaining > 0
        if powerFreezeRemaining > 0 { powerFreezeRemaining = max(0, powerFreezeRemaining - deltaTime) }
        if powerOverclockRemaining > 0 { powerOverclockRemaining = max(0, powerOverclockRemaining - deltaTime) }
        if !frozen { clock += deltaTime }

        // 0. Fever window countdown (paused while frozen).
        if feverActive && !frozen {
            feverRemaining -= deltaTime
            if feverRemaining <= 0 {
                feverActive = false
                feverRemaining = 0
                combo = 0
                events.append(.feverEnded)
            }
        }

        // 1. Drain the RAM buffer (paused while frozen). The drain ramps with
        // score in endless (D23) so late-game survival is a real fight.
        if !frozen { ramRemaining -= config.ramDrainPerSecond * drainMultiplier * deltaTime }

        // 2. Expire timed-out nodes. Daemons penalize + break combo; bombs vanish safely.
        let expired = nodes.filter { clock >= $0.expiresAt }
        for node in expired where node.type.penalizesOnExpiry {
            ramRemaining -= config.penaltyExpiredDaemon
            combo = 0
            cleanStreak = 0       // falling behind breaks the streak multiplier
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
            ? min(gridSize.cellCount, config.feverActiveNodes(for: gridSize))
            : config.targetActiveNodes(atScore: scaledScore, gridSize: gridSize)
        while timeSinceLastSpawn >= interval, nodes.count < target,
              let node = spawnNode() {
            nodes.append(node)
            timeSinceLastSpawn -= interval
        }
        // Don't bank spawn debt while the board is at its ceiling — otherwise
        // freeing cells after a saturated stretch dumps a burst of simultaneous
        // spawns in one tick (audit C1).
        timeSinceLastSpawn = min(timeSinceLastSpawn, interval)

        // 3.5 Worms scuttle to an adjacent free cell on their hop timer.
        for i in nodes.indices where nodes[i].type == .wormDaemon {
            guard let next = nodes[i].nextHopAt, clock >= next else { continue }
            let occupied = Set(nodes.map(\.cellIndex))
            let dests = adjacentCells(nodes[i].cellIndex).filter { !occupied.contains($0) }
            if let dest = dests.randomElement(using: &rng) {
                // Remember the vacated cell briefly — a tap racing the hop still
                // lands (audit C7, brief §10.7 anti-frustration).
                lastWormVacated = (cell: nodes[i].cellIndex, at: clock, nodeID: nodes[i].id)
                nodes[i].cellIndex = dest
            }
            nodes[i].nextHopAt = clock + config.wormHopInterval   // reschedule even if boxed in
        }

        // 4. Low-RAM warning (once per dip), then depletion ends the run.
        events += checkRAMWarning()
        if ramRemaining <= 0 {
            ramRemaining = 0
            events.append(endGame(.ramDepleted))
        }
        return events
    }

    /// Fire `.ramCritical` once when RAM crosses below 25% of capacity, re-arming
    /// only after it recovers above 35% — a tension cue (Part 2.1: tension before
    /// reveal), never a spam. Inert in Flow (RAM never drains there).
    private mutating func checkRAMWarning() -> [GameEvent] {
        guard ramCapacity > 0, !isGameOver else { return [] }
        let fraction = ramRemaining / ramCapacity
        if ramWarned {
            if fraction >= 0.35 { ramWarned = false }   // recovered → re-arm
            return []
        }
        guard fraction <= 0.25, fraction > 0 else { return [] }
        ramWarned = true
        return [.ramCritical]
    }

    // MARK: Input

    /// Resolve a tap on a grid cell. Returns the resulting events.
    mutating func handleTap(cellIndex: Int) -> [GameEvent] {
        guard !isGameOver else { return [] }

        guard let idx = nodes.firstIndex(where: { $0.cellIndex == cellIndex }) else {
            // A tap racing a worm's hop: if the worm vacated this cell within the
            // grace window and is still alive, credit the hit (audit C7).
            if let v = lastWormVacated, v.cell == cellIndex,
               clock - v.at <= config.wormTapGrace,
               let wormIdx = nodes.firstIndex(where: { $0.id == v.nodeID }) {
                lastWormVacated = nil   // one redemption per hop
                return [decode(at: wormIdx)] + checkFever() + checkTarget() + checkGridEscalation() + checkMilestone()
            }
            // Empty cell — a miss, unless the shield absorbs it.
            if shieldCharges > 0 {
                shieldCharges -= 1
                return [.missAbsorbed(cell: cellIndex)]
            }
            combo = 0
            cleanStreak = 0       // a mistap breaks the streak multiplier
            ramRemaining -= config.penaltyMiss
            var events: [GameEvent] = [.emptyMiss(cell: cellIndex)]
            events += checkRAMWarning()
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

        case .standardDaemon, .dataCache, .wormDaemon:
            return [decode(at: idx)] + checkFever() + checkTarget() + checkGridEscalation() + checkMilestone()

        case .powerUp:
            let kind = nodes[idx].powerKind ?? .timeFreeze
            nodes.remove(at: idx)
            return applyPowerUp(kind)

        case .armoredDaemon:
            if nodes[idx].hitsRemaining > 1 {
                nodes[idx].hitsRemaining -= 1   // breach the shell
                return [.nodeBreached(cell: nodes[idx].cellIndex)]
            } else {
                return [decode(at: idx)] + checkFever() + checkTarget() + checkGridEscalation() + checkMilestone()
            }
        }
    }

    /// Endless: award score milestones (a small RAM top-up + a celebration event) as the
    /// score crosses each landmark. Disabled when `milestoneScores` is empty.
    private mutating func checkMilestone() -> [GameEvent] {
        guard !isGameOver else { return [] }
        var events: [GameEvent] = []
        while nextMilestoneIndex < config.milestoneScores.count,
              score >= config.milestoneScores[nextMilestoneIndex] {
            let value = config.milestoneScores[nextMilestoneIndex]
            ramRemaining = min(ramCapacity, ramRemaining + config.milestoneRAMBonus)
            events.append(.milestoneReached(value))
            nextMilestoneIndex += 1
        }
        return events
    }

    /// Apply a tapped power-up's effect. Pickups carry no score — the effect is the
    /// reward. (No combo/decode bump: a power-up isn't a daemon decode.)
    private mutating func applyPowerUp(_ kind: PowerUpKind) -> [GameEvent] {
        switch kind {
        case .timeFreeze: powerFreezeRemaining = config.freezeDuration
        case .overclock:  powerOverclockRemaining = config.overclockDuration
        case .purge:      nodes.removeAll { $0.type == .firewallBomb }
        }
        return [.powerUpCollected(kind)]
    }

    /// Campaign win: reaching the target score cracks the core.
    private mutating func checkTarget() -> [GameEvent] {
        guard !isGameOver, let target = targetScore, score >= target else { return [] }
        return [endGame(.coreCracked)]
    }

    /// Endless escalation: at the threshold, grow the grid 3×3 → 4×4. Existing nodes
    /// keep their top-left position (remapped to the larger grid) so they slide into
    /// place rather than jumping as a 4th column/row appears around them.
    private mutating func checkGridEscalation() -> [GameEvent] {
        guard !isGameOver, gridSize == .threeByThree,
              let threshold = config.gridEscalationScore, score >= threshold else { return [] }
        gridSize = .fourByFour
        for i in nodes.indices {                   // keep top-left layout as the grid grows
            nodes[i].cellIndex = (nodes[i].cellIndex / 3) * 4 + (nodes[i].cellIndex % 3)
        }
        return [.gridExpanded]
    }

    /// Start Fever Mode if a fresh decode pushed the combo to threshold.
    /// On trigger: hazards vanish (bombs removed safely), window resets, and the
    /// next threshold rises (D23) so fever stays a *moment*, not a steady state.
    private mutating func checkFever() -> [GameEvent] {
        guard config.feverEnabled, !feverActive, combo >= feverThresholdEff else { return [] }
        feverActive = true
        feverRemaining = feverDurationEff
        combo = 0
        feversTriggered += 1
        nodes.removeAll { $0.type == .firewallBomb }
        return [.feverStarted]
    }

    // MARK: Helpers

    /// Fully clear the daemon at `idx`: bump combo, award score (×fever) + RAM, remove.
    /// The per-node RAM bonus decays with score in endless (D23); the Decode-Speed
    /// upgrade's `decodeTimeBonus` never decays, so the upgrade stays meaningful late.
    private mutating func decode(at idx: Int) -> GameEvent {
        let node = nodes[idx]
        combo += 1
        cleanStreak += 1
        bestCleanStreak = max(bestCleanStreak, cleanStreak)
        let multiplier = effectiveMultiplier
        let refill = refillFactor
        switch node.type {
        case .standardDaemon:
            score += config.scoreStandard * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusStandardDecode * refill + decodeTimeBonus)
        case .armoredDaemon:
            score += config.scoreArmored * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusArmoredDecode * refill + decodeTimeBonus)
        case .dataCache:
            score += config.scoreCache * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusCacheDecode * refill + decodeTimeBonus)
        case .wormDaemon:
            score += config.scoreWorm * multiplier
            ramRemaining = min(ramCapacity, ramRemaining + config.bonusStandardDecode * refill + decodeTimeBonus)
        case .firewallBomb, .powerUp:
            break // never decoded (power-ups go through applyPowerUp)
        }
        nodes.remove(at: idx)
        return .nodeDecoded(node.type, cell: node.cellIndex)
    }

    /// Orthogonal in-bounds neighbors of a flattened cell index (for worm hops).
    private func adjacentCells(_ index: Int) -> [Int] {
        let cols = gridSize.columns, rows = gridSize.rows
        let r = index / cols, c = index % cols
        var out: [Int] = []
        if r > 0 { out.append(index - cols) }
        if r < rows - 1 { out.append(index + cols) }
        if c > 0 { out.append(index - 1) }
        if c < cols - 1 { out.append(index + 1) }
        return out
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
            } else if roll < config.firewallSpawnChance + config.armoredSpawnChance + config.cacheSpawnChance {
                type = .dataCache
            } else if roll < config.firewallSpawnChance + config.armoredSpawnChance + config.cacheSpawnChance + config.wormSpawnChance {
                type = .wormDaemon
            } else if roll < config.firewallSpawnChance + config.armoredSpawnChance + config.cacheSpawnChance + config.wormSpawnChance + config.powerUpSpawnChance {
                type = .powerUp
            } else {
                type = .standardDaemon
            }
        }

        // Cache + power-ups live briefly (grab fast); a worm lives a touch longer and
        // gets a hop schedule; a power-up carries a random kind.
        let baseLife = config.nodeLifespan(atScore: scaledScore)
        let lifespan: TimeInterval
        var nextHop: TimeInterval?
        var kind: PowerUpKind?
        switch type {
        case .dataCache:  lifespan = baseLife * config.cacheLifespanFactor
        case .wormDaemon: lifespan = baseLife * config.wormLifespanFactor;  nextHop = clock + config.wormHopInterval
        case .powerUp:    lifespan = baseLife * config.powerLifespanFactor; kind = config.powerUpKinds.randomElement(using: &rng) ?? .timeFreeze
        default:          lifespan = baseLife
        }
        return GridNode(cellIndex: cell,
                        type: type,
                        lifespan: lifespan,
                        spawnedAt: clock,
                        nextHopAt: nextHop,
                        powerKind: kind)
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
