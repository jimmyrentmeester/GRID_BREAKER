import Foundation

// MARK: - Deterministic RNG

/// SplitMix64 — a small, fast, seedable RNG. A given seed replays identically,
/// which is what makes spawn sequences reproducible for QA (ground-truth Part 5.1)
/// while keeping mechanics deterministic (brief §10.3).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    // SplitMix64 constants. Built from 16-bit chunks via explicit `UInt64(...)`
    // casts + shifts: Skip emits bare Kotlin literals (no `uL` suffix), so a >2^63
    // hex literal overflows Kotlin's signed Long ("value out of range"). Each chunk
    // ≤ 0xFFFF, wrapped in `UInt64(...)` so Skip emits ULong, then shifted/or'd.
    private static let golden: UInt64 =
        (UInt64(0x9E37) << 48) | (UInt64(0x79B9) << 32) | (UInt64(0x7F4A) << 16) | UInt64(0x7C15)
    private static let mix1: UInt64 =
        (UInt64(0xBF58) << 48) | (UInt64(0x476D) << 32) | (UInt64(0x1CE4) << 16) | UInt64(0xE5B9)
    private static let mix2: UInt64 =
        (UInt64(0x94D0) << 48) | (UInt64(0x49BB) << 32) | (UInt64(0x1331) << 16) | UInt64(0x11EB)

    mutating func next() -> UInt64 {
        // Non-compound `&+` (Skip mistranslates the compound `&+=`). On Kotlin ULong
        // `+`/`*` wrap silently, matching Swift's `&+`/`&*` overflow semantics.
        state = state &+ SeededRNG.golden
        var z = state
        z = (z ^ (z >> 30)) &* SeededRNG.mix1
        z = (z ^ (z >> 27)) &* SeededRNG.mix2
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1) — derived deterministically from the top 53 bits of
    /// `next()`. SkipLib lacks `Double.random(in:using:)`; this is pure arithmetic,
    /// identical on every platform given the same seed.
    mutating func uniform() -> Double {
        return Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)  // 2^53
    }

    /// Uniform Int in a half-open range [lower, upper). SkipLib's `Int.random(in:using:)`
    /// doesn't accept our generator, so we derive it from `next()`.
    mutating func int(inRange lower: Int, _ upper: Int) -> Int {
        let span = upper - lower
        guard span > 0 else { return lower }
        return lower + Int(next() % UInt64(span))
    }

    /// Uniform Int in a closed range [lower, upper].
    mutating func intClosed(_ lower: Int, _ upper: Int) -> Int {
        return int(inRange: lower, upper + 1)
    }

    /// A random valid index into a collection of `count` items, or nil if empty.
    /// Index-based (not generic): Skip's generic inference fails on `[T]`/List↔Array,
    /// so callers index into their own array instead of passing it through a generic.
    mutating func index(_ count: Int) -> Int? {
        guard count > 0 else { return nil }
        return int(inRange: 0, count)
    }

    /// A shuffled copy of an `[Int]` (Fisher–Yates) — concrete type, no generics.
    mutating func shuffledInts(_ items: [Int]) -> [Int] {
        var out = items
        var i = out.count - 1
        while i > 0 {
            let j = int(inRange: 0, i + 1)
            let tmp = out[i]; out[i] = out[j]; out[j] = tmp
            i -= 1
        }
        return out
    }
}

// MARK: - Concrete min/max (Skip number-widening workaround)
//
// Skip's generic `min`/`max` return a boxed `Number & Comparable` that Kotlin won't
// unbox back to Double/Int (pitfall #42). These concrete overloads use a ternary
// (two same-typed operands → a clean Double/Int) so clamps keep their type.
private func dmin(_ a: Double, _ b: Double) -> Double { a < b ? a : b }
private func dmax(_ a: Double, _ b: Double) -> Double { a > b ? a : b }
private func imin(_ a: Int, _ b: Int) -> Int { a < b ? a : b }
private func imax(_ a: Int, _ b: Int) -> Int { a > b ? a : b }

/// The cell a worm just vacated, for the hop/tap grace window. A struct instead of
/// a labeled tuple — Skip mistranslates labeled-tuple stored-property types (#9).
private struct WormVacated {
    let cell: Int
    let at: TimeInterval
    let nodeID: UUID
}

// MARK: - Events & outcomes

/// Why a session ended.
enum GameOverReason: String, Sendable {
    case ramDepleted   // the RAM time buffer ran out
    case firewallHit   // the player tapped an active firewall bomb
    case coreCracked   // campaign: reached the target score (a WIN)
    case dmzOverrun    // PROTOCOL: a DMZ PURGE creep filled the grid before the purge
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
    case daemonSetSpawned(size: Int)        // an ordered DAEMON SET chain appeared (PROTOCOL)
    case daemonSetAdvanced(cell: Int)       // correct next node in the set was decoded
    case daemonSetCompleted(cell: Int)      // whole set cleared → ×N reward armed
    case daemonSetWrongOrder(cell: Int)     // tapped a set node out of order (a miss)
    case dmzSpawned(cells: [Int])           // a DMZ PURGE zone appeared, full of intrusion
    case intrusionCleared(cell: Int)        // an intrusion node was tapped away
    case dmzOverrunSpawned(cell: Int)       // the creep added an intrusion outside the zone
    case dmzPurged                          // the whole zone was cleared → DMZ dismissed
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
    var dmzZone: Set<Int>              // PROTOCOL: cells outlined as the active DMZ (empty = none)

    /// Campaign win.
    var didWin: Bool { gameOverReason == .coreCracked }

    /// Progress toward the campaign target, 0…1 (for the goal bar).
    var targetProgress: Double {
        guard let t = targetScore, t > 0 else { return 0 }
        return dmin(1.0, Double(score) / Double(t))
    }

    var ramFraction: Double {
        guard ramCapacity > 0 else { return 0 }
        return dmin(1.0, dmax(0.0, ramRemaining / ramCapacity))
    }

    /// Progress toward the next fever trigger, 0…1 (for the combo meter).
    var comboProgress: Double {
        guard comboThreshold > 0 else { return 0 }
        return dmin(1.0, Double(combo) / Double(comboThreshold))
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
    /// PROTOCOL: gap timer between objectives (runs only while no objective is active).
    private var timeSinceLastObjective: TimeInterval = 0
    /// PROTOCOL: rotates through the enabled objectives so they alternate (set ↔ DMZ).
    private var objectiveCursor: Int = 0
    /// PROTOCOL: ×N multiplier armed for the *next* decode after a set completes (1 = none).
    private var nextDecodeBonus: Int = 1
    /// PROTOCOL: if the next Fever is triggered by a set completion, it lasts ×daemonSetReward.
    private var pendingFeverBonus = false
    /// PROTOCOL (DMZ PURGE): the cells of the active zone (empty = no DMZ active).
    private var dmzZone: Set<Int> = []
    /// PROTOCOL (DMZ PURGE): overrun creep timer (runs only while a DMZ is active).
    private var timeSinceLastOverrun: TimeInterval = 0

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
    private var lastWormVacated: WormVacated?
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
                ? dmax(0.0, feverRemaining / feverDurationEff) : 0.0,
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
                ? config.milestoneScores[nextMilestoneIndex] : nil,
            dmzZone: dmzZone
        )
    }

    /// PROTOCOL: the objectives enabled for this run, in alternation order.
    private enum Objective { case daemonSet, dmz }
    private var enabledObjectives: [Objective] {
        var out: [Objective] = []
        if config.daemonSetEnabled { out.append(.daemonSet) }
        if config.dmzEnabled { out.append(.dmz) }
        return out
    }
    /// PROTOCOL: true while any objective occupies the board (a set chain or a DMZ).
    private var objectiveActive: Bool {
        dmzZone.isEmpty == false || nodes.contains { $0.isSetMember }
    }

    /// Base multiplier from the clean-decode streak (×1, then +1 per tier crossed).
    var streakMultiplier: Int {
        guard !config.streakTierThresholds.isEmpty else { return 1 }
        // Explicit loop instead of reduce-with-$0/$1 (Skip closure-inference, #31).
        var tiers = 0
        for threshold in config.streakTierThresholds where cleanStreak >= threshold { tiers += 1 }
        return 1 + tiers
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
        let raised = config.feverComboThreshold + feversTriggered * config.feverThresholdRampPerFever
        return raised > config.feverThresholdMax ? config.feverThresholdMax : raised
    }

    /// Effective RAM drain multiplier at the current score (1 when the ramp is off).
    private var drainMultiplier: Double {
        guard config.drainRampPerScore > 0 else { return 1.0 }
        let ramped = 1.0 + Double(score) * config.drainRampPerScore
        return ramped > config.drainRampCap ? config.drainRampCap : ramped
    }

    /// Effective decode-refill factor at the current score (1 when decay is off).
    /// Applies to the per-node bonuses only — never to the Decode-Speed upgrade.
    private var refillFactor: Double {
        guard config.refillDecayPerScore > 0 else { return 1.0 }
        let decayed = exp(-config.refillDecayPerScore * Double(score))
        return decayed < config.refillDecayFloor ? config.refillDecayFloor : decayed
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
        if powerFreezeRemaining > 0 { powerFreezeRemaining = dmax(0.0, powerFreezeRemaining - deltaTime) }
        if powerOverclockRemaining > 0 { powerOverclockRemaining = dmax(0.0, powerOverclockRemaining - deltaTime) }
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
        let expired = nodes.filter { !$0.isPersistent && clock >= $0.expiresAt }   // set + intrusion nodes wait for the player
        for node in expired where node.type.penalizesOnExpiry {
            ramRemaining -= config.penaltyExpiredDaemon
            combo = 0
            cleanStreak = 0       // falling behind breaks the streak multiplier
            events.append(.nodeExpired(node.type, cell: node.cellIndex))
        }
        if !expired.isEmpty {
            let goneIDs = Set(expired.map { node in node.id })
            nodes.removeAll { goneIDs.contains($0.id) }
        }

        // 3. Spawn new nodes on cadence. Fever: faster + fuller, golden-only.
        // Fever must never spawn *slower* or *sparser* than the current non-fever
        // pace would. On difficulty-biased campaign cores the score-scaled cadence
        // is already faster (and the board fuller) than the fixed fever constants,
        // so taking the plain fever values made Fever read as a slowdown (issue #1).
        // Take the faster interval and the fuller node ceiling of the two.
        // The normal daemon stream pauses while a DMZ PURGE is active — the board
        // belongs entirely to the zone + its overrun creep then (§3.6).
        timeSinceLastSpawn += deltaTime
        let scaledInterval = config.spawnInterval(atScore: scaledScore)
        let scaledTarget = config.targetActiveNodes(atScore: scaledScore, gridSize: gridSize)
        let interval = feverActive ? dmin(config.feverSpawnInterval, scaledInterval) : scaledInterval
        let target = feverActive
            ? imin(gridSize.cellCount, imax(config.feverActiveNodes(for: gridSize), scaledTarget))
            : scaledTarget
        if dmzZone.isEmpty {
            while timeSinceLastSpawn >= interval, nodes.count < target,
                  let node = spawnNode() {
                nodes.append(node)
                timeSinceLastSpawn -= interval
            }
        }
        // Don't bank spawn debt while the board is at its ceiling — otherwise
        // freeing cells after a saturated stretch dumps a burst of simultaneous
        // spawns in one tick (audit C1).
        timeSinceLastSpawn = dmin(timeSinceLastSpawn, interval)

        // 3.4 PROTOCOL objective scheduler: on a gap timer, drop the next objective when
        // none is on the board. Enabled objectives alternate (DAEMON SET ↔ DMZ PURGE).
        // The timer only advances while no objective is active and not frozen, so the gap
        // is "time since the last objective cleared". No new objective starts mid-Fever.
        if !enabledObjectives.isEmpty && !frozen && !feverActive {
            if objectiveActive {
                timeSinceLastObjective = 0
            } else {
                timeSinceLastObjective += deltaTime
                if timeSinceLastObjective >= config.objectiveGap(atScore: scaledScore) {
                    let next = enabledObjectives[objectiveCursor % enabledObjectives.count]
                    let spawned = (next == .daemonSet) ? spawnDaemonSet() : spawnDMZ()
                    if !spawned.isEmpty {                 // retry next tick if no room
                        events += spawned
                        timeSinceLastObjective = 0
                        objectiveCursor += 1
                    }
                }
            }
        }

        // 3.6 DMZ PURGE overrun (PROTOCOL): while a zone is active, an intrusion node
        // creeps into a random free cell *outside* the zone on a cadence. If there's no
        // room left outside the zone when it fires, the system is overrun → game over.
        if !dmzZone.isEmpty && !frozen {
            timeSinceLastOverrun += deltaTime
            if timeSinceLastOverrun >= config.dmzOverrunPace(atScore: scaledScore) {
                timeSinceLastOverrun = 0
                let occupied = Set(nodes.map { node in node.cellIndex })
                // Explicit loop → a real [Int]; Skip types `range.filter{}` as a Kotlin
                // List that lacks `.count`/indexing/`shuffledInts` (Array) (#54).
                var freeOutside: [Int] = []
                for cell in 0..<gridSize.cellCount where !dmzZone.contains(cell) && !occupied.contains(cell) {
                    freeOutside.append(cell)
                }
                if let idx = rng.index(freeOutside.count) {
                    let cell = freeOutside[idx]
                    // lifespan large finite (Skip lacks .infinity); intrusion is persistent so expiry is skipped anyway.
                    nodes.append(GridNode(cellIndex: cell, type: NodeType.intrusion,
                                          lifespan: 1_000_000.0, spawnedAt: clock))
                    events.append(.dmzOverrunSpawned(cell: cell))
                } else {
                    events.append(endGame(.dmzOverrun))
                }
            }
        }

        // 3.5 Worms scuttle to an adjacent free cell on their hop timer.
        for i in nodes.indices where nodes[i].type == .wormDaemon {
            guard let next = nodes[i].nextHopAt, clock >= next else { continue }
            let occupied = Set(nodes.map { node in node.cellIndex })
            var dests: [Int] = []
            for cell in adjacentCells(nodes[i].cellIndex) where !occupied.contains(cell) { dests.append(cell) }
            if let destIdx = rng.index(dests.count) {
                let dest = dests[destIdx]
                // Remember the vacated cell briefly — a tap racing the hop still
                // lands (audit C7, brief §10.7 anti-frustration).
                lastWormVacated = WormVacated(cell: nodes[i].cellIndex, at: clock, nodeID: nodes[i].id)
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

        // DAEMON SET nodes (PROTOCOL) enforce tap order before normal resolution.
        if nodes[idx].isSetMember { return handleSetTap(at: idx) }

        switch nodes[idx].type {
        case .intrusion:
            // DMZ PURGE node (PROTOCOL): a defensive clear, outside the combo/fever system.
            return clearIntrusion(at: idx)

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

    /// Resolve a tap on a DAEMON SET node (PROTOCOL). Only the lowest remaining order is
    /// the valid next target. Correct → decode + advance; completing the chain arms a ×N
    /// bonus for the *next* decode (and a ×N-duration Fever if the completion triggers it).
    /// Out of order → a miss (RAM penalty + combo break); the set is unchanged, not failed.
    private mutating func handleSetTap(at idx: Int) -> [GameEvent] {
        let order = nodes[idx].setOrder ?? 1
        let required = nodes.compactMap { node in node.setOrder }.min() ?? order
        guard order == required else {
            let cell = nodes[idx].cellIndex
            combo = 0
            cleanStreak = 0
            ramRemaining -= config.penaltyMiss
            var events: [GameEvent] = [.daemonSetWrongOrder(cell: cell)]
            events += checkRAMWarning()
            if ramRemaining <= 0 { ramRemaining = 0; events.append(endGame(.ramDepleted)) }
            return events
        }
        // Correct next node → decode it (normal multiplier; the ×N reward is for AFTER the set).
        let cell = nodes[idx].cellIndex
        var events: [GameEvent] = [decode(at: idx)]
        let setComplete = !nodes.contains { $0.setOrder != nil }
        if setComplete {
            nextDecodeBonus = config.daemonSetReward    // ×N on the next decode
            pendingFeverBonus = true                    // ×N Fever if this completion triggers it
            events.append(.daemonSetCompleted(cell: cell))
        } else {
            events.append(.daemonSetAdvanced(cell: cell))
        }
        return events + checkFever() + checkTarget() + checkGridEscalation() + checkMilestone()
    }

    /// Spawn an ordered DAEMON SET chain of N (config range) on random free cells, orders
    /// 1…N. Returns no event (and spawns nothing) if the board lacks N free cells.
    private mutating func spawnDaemonSet() -> [GameEvent] {
        let sizeRange = config.daemonSetSizeRange(atScore: scaledScore)
        let n = rng.intClosed(sizeRange.lo, sizeRange.hi)
        let occupied = Set(nodes.map { node in node.cellIndex })
        var free: [Int] = []
        for cell in 0..<gridSize.cellCount where !occupied.contains(cell) { free.append(cell) }
        guard free.count >= n else { return [] }   // not enough room now; retry next tick
        let shuffled = rng.shuffledInts(free)
        let life = config.nodeLifespan(atScore: scaledScore)   // expiry is skipped for set nodes
        for order in 1...n {
            let cell = shuffled[order - 1]
            nodes.append(GridNode(cellIndex: cell, type: NodeType.standardDaemon,
                                  lifespan: life, spawnedAt: clock,
                                  setOrder: order, setSize: n))
        }
        return [.daemonSetSpawned(size: n)]
    }

    /// Spawn a DMZ PURGE zone (PROTOCOL, issue #4): a contiguous block of free cells,
    /// filled with `intrusion` nodes. The player must clear every cell in the zone before
    /// the overrun creep (§3.6 in tick) fills the rest of the grid. Returns no event (and
    /// spawns nothing) if no contiguous free block of the rolled size exists right now.
    private mutating func spawnDMZ() -> [GameEvent] {
        let sizeRange = config.dmzSizeRange(atScore: scaledScore)
        let size = rng.intClosed(sizeRange.lo, sizeRange.hi)
        let occupied = Set(nodes.map { node in node.cellIndex })
        var candidates: [[Int]] = []
        for zone in candidateZones(size: size) where zone.allSatisfy({ cell in !occupied.contains(cell) }) {
            candidates.append(zone)
        }
        guard let zoneIdx = rng.index(candidates.count) else { return [] }
        let zone = candidates[zoneIdx]
        dmzZone = Set(zone)
        timeSinceLastOverrun = 0
        for cell in zone {
            // lifespan large finite (Skip lacks .infinity); intrusion is persistent so expiry is skipped anyway.
            nodes.append(GridNode(cellIndex: cell, type: NodeType.intrusion,
                                  lifespan: 1_000_000.0, spawnedAt: clock))
        }
        return [.dmzSpawned(cells: zone)]
    }

    /// Resolve a tap on a DMZ PURGE `intrusion` node (PROTOCOL): clear it for a flat score +
    /// a little RAM (kept out of the combo/fever system — DMZ is defense, not a combo). When
    /// the last *in-zone* intrusion is cleared the zone is purged: the overrun is swept, the
    /// zone dismissed, and a RAM relief granted → back to the daemon stream.
    private mutating func clearIntrusion(at idx: Int) -> [GameEvent] {
        let cell = nodes[idx].cellIndex
        let inZone = dmzZone.contains(cell)
        score += config.scoreIntrusion
        ramRemaining = dmin(ramCapacity, ramRemaining + config.dmzClearRefill)
        nodes.remove(at: idx)
        var events: [GameEvent] = [.intrusionCleared(cell: cell)]
        if inZone {
            let zoneStillHeld = nodes.contains { $0.type == .intrusion && dmzZone.contains($0.cellIndex) }
            if !zoneStillHeld {
                nodes.removeAll { $0.type == .intrusion }   // sweep the overrun creep
                dmzZone = []
                ramRemaining = dmin(ramCapacity, ramRemaining + config.dmzPurgeBonus)
                events.append(.dmzPurged)
            }
        }
        return events
    }

    /// All axis-aligned rectangular cell blocks of `size` on the current grid (the shapes a
    /// DMZ zone can take): size 2 → 1×2 / 2×1, size 3 → 1×3 / 3×1, size 4 → 2×2 (plus 1×4 /
    /// 4×1 once the grid is wide enough). Deterministic enumeration; the caller filters to
    /// fully-free blocks and picks one with the seeded RNG.
    private func candidateZones(size: Int) -> [[Int]] {
        let cols = gridSize.columns, rows = gridSize.rows
        func cell(_ r: Int, _ c: Int) -> Int { r * cols + c }
        var out: [[Int]] = []
        // Horizontal 1×size and vertical size×1 runs.
        if size <= cols {
            for r in 0..<rows { for c in 0...(cols - size) {
                out.append((0..<size).map { cell(r, c + $0) })
            } }
        }
        if size <= rows {
            for c in 0..<cols { for r in 0...(rows - size) {
                out.append((0..<size).map { cell(r + $0, c) })
            } }
        }
        // Square 2×2 (size 4).
        if size == 4 {
            for r in 0...(rows - 2) { for c in 0...(cols - 2) {
                out.append([cell(r, c), cell(r, c + 1), cell(r + 1, c), cell(r + 1, c + 1)])
            } }
        }
        return out
    }

    /// Endless: award score milestones (a small RAM top-up + a celebration event) as the
    /// score crosses each landmark. Disabled when `milestoneScores` is empty.
    private mutating func checkMilestone() -> [GameEvent] {
        guard !isGameOver else { return [] }
        var events: [GameEvent] = []
        while nextMilestoneIndex < config.milestoneScores.count,
              score >= config.milestoneScores[nextMilestoneIndex] {
            let value = config.milestoneScores[nextMilestoneIndex]
            ramRemaining = dmin(ramCapacity, ramRemaining + config.milestoneRAMBonus)
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
        guard config.feverEnabled, !feverActive, combo >= feverThresholdEff else {
            pendingFeverBonus = false   // a DAEMON SET completion only boosts the Fever it triggers
            return []
        }
        feverActive = true
        // A set completion that triggers this Fever makes it last ×daemonSetReward (issue #3).
        let durationMult = pendingFeverBonus ? Double(config.daemonSetReward) : 1.0
        pendingFeverBonus = false
        feverRemaining = feverDurationEff * durationMult
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
        bestCleanStreak = imax(bestCleanStreak, cleanStreak)
        // A completed DAEMON SET arms a one-shot ×N bonus for this next decode (issue #3).
        let multiplier = effectiveMultiplier * nextDecodeBonus
        if nextDecodeBonus > 1 { nextDecodeBonus = 1 }   // consumed
        let refill = refillFactor
        switch node.type {
        case .standardDaemon:
            score += config.scoreStandard * multiplier
            ramRemaining = dmin(ramCapacity, ramRemaining + config.bonusStandardDecode * refill + decodeTimeBonus)
        case .armoredDaemon:
            score += config.scoreArmored * multiplier
            ramRemaining = dmin(ramCapacity, ramRemaining + config.bonusArmoredDecode * refill + decodeTimeBonus)
        case .dataCache:
            score += config.scoreCache * multiplier
            ramRemaining = dmin(ramCapacity, ramRemaining + config.bonusCacheDecode * refill + decodeTimeBonus)
        case .wormDaemon:
            score += config.scoreWorm * multiplier
            ramRemaining = dmin(ramCapacity, ramRemaining + config.bonusStandardDecode * refill + decodeTimeBonus)
        case .firewallBomb, .powerUp, .intrusion:
            break // never decoded (power-ups → applyPowerUp, intrusion → clearIntrusion)
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
        let occupied = Set(nodes.map { node in node.cellIndex })
        var free: [Int] = []
        for cell in 0..<gridSize.cellCount where !occupied.contains(cell) { free.append(cell) }
        guard let cellIdx = rng.index(free.count) else { return nil }
        let cell = free[cellIdx]

        let type: NodeType
        if feverActive {
            type = .standardDaemon
        } else {
            let roll = rng.uniform()
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
        case .powerUp:
            lifespan = baseLife * config.powerLifespanFactor
            if let kIdx = rng.index(config.powerUpKinds.count) { kind = config.powerUpKinds[kIdx] } else { kind = .timeFreeze }
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
        dmzZone = []           // drop the zone outline so it doesn't stick on game-over
        return .gameOver(reason)
    }
}
