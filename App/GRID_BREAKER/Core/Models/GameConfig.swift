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
    var bonusStandardDecode: TimeInterval = 1.2
    var bonusArmoredDecode: TimeInterval = 2.0
    /// Tapping an empty cell or letting a daemon expire costs buffer time.
    var penaltyMiss: TimeInterval = 1.5
    var penaltyExpiredDaemon: TimeInterval = 1.0

    // MARK: Node lifespan & difficulty scaling (brief 10.3)
    /// Initial display duration of an active node, in seconds.
    var baseNodeLifespan: TimeInterval = 1.6
    /// Compression coefficient: lifespan = base * exp(-k * score).
    /// Higher = more aggressive difficulty ramp.
    var lifespanCompression: Double = 0.0025
    /// Shortest a node lifespan may ever shrink to (fairness floor).
    var minNodeLifespan: TimeInterval = 0.45

    // MARK: Fever mode (brief 10.2)
    /// Consecutive clean hits required to trigger Fever Mode.
    var feverComboThreshold: Int = 8
    var feverDuration: TimeInterval = 4.0
    var feverScoreMultiplier: Int = 2

    // MARK: Input tolerance (brief 10.7 risk mitigation)
    /// Hitbox is enlarged beyond the visual sprite for touch tolerance.
    var hitboxPadding: CGFloat = 1.20

    // MARK: Spawn mix (procedural selection, brief 10.3)
    var armoredSpawnChance: Double = 0.20
    var firewallSpawnChance: Double = 0.15

    static let `default` = GameConfig()

    /// Deterministic effective RAM capacity for a given Cyberdeck.
    func ramCapacity(for deck: Cyberdeck) -> TimeInterval {
        baseRAMSeconds + ramSecondsPerLevel * TimeInterval(deck.ramLevel)
    }

    /// Deterministic node lifespan at a given score (exponential compression).
    func nodeLifespan(atScore score: Int) -> TimeInterval {
        let scaled = baseNodeLifespan * exp(-lifespanCompression * Double(score))
        return max(minNodeLifespan, scaled)
    }
}
