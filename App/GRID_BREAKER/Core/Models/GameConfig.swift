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
    var scoreWorm: Int = 2             // a worm is harder to catch → worth a bit more

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
    /// Chance a spawn is a worm. It hops to an adjacent free cell every
    /// `wormHopInterval` seconds, and lives a touch longer (`wormLifespanFactor`)
    /// so it gets to move before timing out.
    var wormSpawnChance: Double = 0.08
    var wormHopInterval: TimeInterval = 0.55
    var wormLifespanFactor: Double = 1.25
    /// Chance a spawn is a power-up pickup (a random `PowerUpKind`). Short-lived.
    var powerUpSpawnChance: Double = 0.04
    var powerLifespanFactor: Double = 0.8
    /// Which power-up kinds may spawn (campaign gates these in gradually).
    var powerUpKinds: [PowerUpKind] = PowerUpKind.allCases

    // MARK: Power-up effects
    var freezeDuration: TimeInterval = 3.0      // time-freeze window
    var overclockDuration: TimeInterval = 4.0   // bonus-multiplier window
    var overclockMultiplier: Int = 2            // ×N during overclock (stacks w/ fever)

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
        c.wormSpawnChance = 0            // …and no worms (fixed mechanical mix)
        c.powerUpSpawnChance = 0         // …and no power-ups
        c.gridEscalationScore = nil      // cores are hand-tuned for a fixed 3×3
        // Beginner-friendly, gradually-ramping pace (the campaign's defining feel).
        // Early cores have a low `difficultyBias`, so they start with long, calm pauses
        // between spawns (~1.1 s — roughly half the speed of the other modes) and
        // long-lived nodes (2 s). The per-core `difficultyBias` then compresses BOTH the
        // spawn cadence and the lifespan toward the frantic finale (down to the floors
        // below). So difficulty rises smoothly via speed + board density as you climb.
        c.baseSpawnInterval = 1.10
        c.minSpawnInterval  = 0.30
        c.baseNodeLifespan  = 2.00
        c.minNodeLifespan   = 0.60
        c.wormHopInterval   = 0.75
        c.feverSpawnInterval = 0.55
        return c
    }

    /// Build a core's config from its feature gates (mechanics are introduced
    /// cumulatively up the ladder). Starts from the time-attack base, then enables
    /// only what this core has unlocked.
    static func campaign(for core: DataCore) -> GameConfig {
        var c = GameConfig.campaign(timeBudget: core.timeBudget)
        c.armoredSpawnChance = core.armored ? 0.20 : 0
        c.firewallSpawnChance = core.bombs ? 0.15 : 0
        c.feverEnabled = core.fever
        c.cacheSpawnChance = core.cache ? 0.05 : 0
        c.wormSpawnChance = core.worm ? 0.08 : 0
        if !core.powerKinds.isEmpty {
            c.powerUpSpawnChance = 0.05
            c.powerUpKinds = core.powerKinds
        }
        // Grid grows once you're halfway to the target (only on cores that unlock it).
        c.gridEscalationScore = core.grid4x4 ? max(1, core.targetScore / 2) : nil
        return c
    }

    /// Config for **Endless (JACK IN)** and the Daily challenge. A calmer opening, a
    /// longer and more gradual difficulty ramp, the grid grows later, and the
    /// acceleration plateaus at a still-hittable floor — so a long run is about endurance
    /// and avoiding mistakes (a stray bomb / mistap) rather than hitting an impossible
    /// wall. Isolated from the default so campaign/flow tuning is unaffected.
    static func endless() -> GameConfig {
        var c = GameConfig.default
        c.baseSpawnInterval   = 0.72   // calmer start (was 0.50)
        c.spawnCompression    = 0.0032 // gentler ramp (was 0.0045)
        c.minSpawnInterval    = 0.26   // higher floor → stays hittable (was 0.20)
        c.baseNodeLifespan    = 1.70   // more reaction time early (was 1.35)
        c.lifespanCompression = 0.0021 // gentler shrink (was 0.0030)
        c.minNodeLifespan     = 0.62   // higher floor (was 0.50)
        c.gridEscalationScore = 80     // grid grows later (was 40)
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
        c.wormSpawnChance = 0            // no chasing targets — Flow stays calm
        c.powerUpSpawnChance = 0         // no power-ups — Flow stays calm
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
