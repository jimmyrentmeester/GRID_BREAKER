import Foundation

/// Grid dimensions. Difficulty may step the grid up over a session.
enum GridSize: Int, Codable, Sendable {
    case threeByThree = 3
    case fourByFour = 4

    var columns: Int { rawValue }
    var rows: Int { rawValue }
    var cellCount: Int { rawValue * rawValue }
}

/// Central tuning table — every balance number in one deterministic place
/// (ground-truth Part 1.1 / Part 0 "spec is reusable"). The engine reads
/// these; nothing here depends on UI. Treat as the single source of balance.
struct GameConfig: Sendable {
    // MARK: RAM time buffer (the core resource, brief 10.3)
    /// Base RAM capacity in seconds before Cyberdeck upgrades.
    var baseRAMSeconds: TimeInterval = 20
    /// Extra seconds added per RAM upgrade level.
    var ramSecondsPerLevel: TimeInterval = 4
    /// Passive drain of the RAM buffer per second of play.
    var ramDrainPerSecond: TimeInterval = 1.0

    // MARK: Time bonuses / penalties
    var bonusStandardDecode: TimeInterval = 1.05
    var bonusArmoredDecode: TimeInterval = 1.8
    var bonusCacheDecode: TimeInterval = 2.5     // a data cache also refills more RAM
    /// Tapping an empty cell or letting a daemon expire costs buffer time.
    var penaltyMiss: TimeInterval = 1.5
    var penaltyExpiredDaemon: TimeInterval = 1.0

    // MARK: Node lifespan & difficulty scaling (brief 10.3)
    /// Initial display duration of an active node, in seconds.
    var baseNodeLifespan: TimeInterval = 1.35
    /// Compression coefficient: lifespan = base * exp(-k * score).
    /// Higher = more aggressive difficulty ramp.
    var lifespanCompression: Double = 0.0030
    /// Shortest a node lifespan may ever shrink to (fairness floor).
    var minNodeLifespan: TimeInterval = 0.50

    // MARK: Spawn cadence (how fast new nodes appear)
    /// Seconds between spawns at score 0.
    var baseSpawnInterval: TimeInterval = 0.50
    /// Spawn interval compresses with score (more frequent over time).
    var spawnCompression: Double = 0.0045
    /// Fastest the spawn cadence may ever get (fairness floor).
    var minSpawnInterval: TimeInterval = 0.20

    // MARK: Score payouts
    var scoreStandard: Int = 1
    var scoreArmored: Int = 2
    var scoreCache: Int = 5            // bonus "data cache" — a points spike

    // MARK: Meta progression
    /// Credits earned per point of decode score at session end.
    var creditsPerScore: Double = 1.0
    /// Extra RAM time per decode, per Decode-Speed upgrade level.
    var decodeBonusPerLevel: TimeInterval = 0.15

    // MARK: Fever mode (brief 10.2)
    /// Consecutive clean hits required to trigger Fever Mode.
    var feverComboThreshold: Int = 8
    var feverDuration: TimeInterval = 4.0
    var feverScoreMultiplier: Int = 2
    /// Whether Fever Mode can trigger at all (off in Flow/chill mode).
    var feverEnabled: Bool = true
    /// During fever: faster spawns + a fuller grid of golden bonus nodes.
    var feverSpawnInterval: TimeInterval = 0.34
    var feverActiveNodes: Int = 4

    /// If set, the active-node ceiling is fixed (no score-based escalation) — used
    /// by Flow mode to keep a flat, calm pace.
    var fixedActiveNodes: Int? = nil

    /// Endless only: once the score reaches this, the grid grows 3×3 → 4×4 for a
    /// late-game escalation (nil = never; disabled in campaign/Flow). brief §10.3 /
    /// QUESTIONS Q2.
    var gridEscalationScore: Int? = 40

    // MARK: Input tolerance (brief 10.7 risk mitigation)
    /// Hitbox is enlarged beyond the visual sprite for touch tolerance.
    var hitboxPadding: CGFloat = 1.20

    // MARK: Spawn mix (procedural selection, brief 10.3)
    var armoredSpawnChance: Double = 0.20
    var firewallSpawnChance: Double = 0.15
    /// Chance a spawn is a bonus data cache. It also lives a fraction of the normal
    /// lifespan (`cacheLifespanFactor`) so it's a quick reflex grab.
    var cacheSpawnChance: Double = 0.05
    var cacheLifespanFactor: Double = 0.65

    static let `default` = GameConfig()

    /// Config for a campaign core: a **time attack**. RAM is a true countdown of
    /// `timeBudget` seconds (extended by the RAM upgrade) — decodes do NOT refill
    /// it, so you race the clock to the target. The Decode-Speed upgrade is the one
    /// source of refill (`decodeBonusPerLevel`), so it stays meaningful. Misses
    /// still cost time and a firewall still ends the run.
    static func campaign(timeBudget: TimeInterval) -> GameConfig {
        var c = GameConfig.default
        c.baseRAMSeconds = timeBudget
        c.bonusStandardDecode = 0
        c.bonusArmoredDecode = 0
        c.bonusCacheDecode = 0
        c.cacheSpawnChance = 0           // cores are sim-tuned; no bonus caches
        c.gridEscalationScore = nil      // cores are hand-tuned for a fixed 3×3
        return c
    }

    /// Config for **Flow (chill) mode**: no failure, no clock, no hazards, a flat
    /// gentle pace. RAM never drains (no death), no firewall bombs, no miss
    /// penalties, no difficulty escalation, no Fever. Just a calm, endless tap
    /// rhythm you leave when you want.
    static func chill() -> GameConfig {
        var c = GameConfig.default
        c.ramDrainPerSecond = 0          // RAM never drains → can't fail
        c.penaltyMiss = 0
        c.penaltyExpiredDaemon = 0
        c.bonusStandardDecode = 0
        c.bonusArmoredDecode = 0
        c.firewallSpawnChance = 0        // no hazards
        c.armoredSpawnChance = 0.22      // light variety
        c.baseSpawnInterval = 0.9        // calm, constant cadence
        c.minSpawnInterval = 0.9
        c.spawnCompression = 0
        c.baseNodeLifespan = 2.2         // generous, constant
        c.minNodeLifespan = 2.2
        c.lifespanCompression = 0
        c.fixedActiveNodes = 3
        c.feverEnabled = false
        c.gridEscalationScore = nil      // Flow stays a calm, fixed 3×3
        return c
    }

    /// Deterministic effective RAM capacity for a given Cyberdeck.
    func ramCapacity(for deck: Cyberdeck) -> TimeInterval {
        baseRAMSeconds + ramSecondsPerLevel * TimeInterval(deck.ramLevel)
    }

    /// Extra RAM time added to each decode by the Decode-Speed upgrade.
    func decodeTimeBonus(for deck: Cyberdeck) -> TimeInterval {
        decodeBonusPerLevel * TimeInterval(deck.decodeSpeedLevel)
    }

    /// Credits awarded for a final score (deterministic, paid once on game over).
    func credits(forScore score: Int) -> Int {
        max(0, Int(Double(score) * creditsPerScore))
    }

    /// Deterministic node lifespan at a given score (exponential compression).
    func nodeLifespan(atScore score: Int) -> TimeInterval {
        let scaled = baseNodeLifespan * exp(-lifespanCompression * Double(score))
        return max(minNodeLifespan, scaled)
    }

    /// Deterministic spawn interval at a given score (exponential compression).
    func spawnInterval(atScore score: Int) -> TimeInterval {
        let scaled = baseSpawnInterval * exp(-spawnCompression * Double(score))
        return max(minSpawnInterval, scaled)
    }

    /// How many nodes may be active at once at a given score (brief §10.3:
    /// active-node ceiling grows with score). Starts at 2 so the board feels
    /// alive from the first second; always leaves one free cell.
    func targetActiveNodes(atScore score: Int, gridSize: GridSize) -> Int {
        if let fixed = fixedActiveNodes {
            return max(1, min(gridSize.cellCount - 1, fixed))
        }
        return max(2, min(gridSize.cellCount - 1, 2 + score / 8))
    }
}
