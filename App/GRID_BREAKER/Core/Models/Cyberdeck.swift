import Foundation

/// The player's persistent meta-progression: upgrade levels bought with Credits.
///
/// Pure value type, Codable for save/load. Per ground-truth Part 3.3, new
/// fields must decode tolerantly from old saves — keep defaults on every field.
struct Cyberdeck: Codable, Sendable, Equatable {
    /// Extends the base RAM time buffer (longer sessions).
    var ramLevel: Int = 0
    /// Increases decode payout / node responsiveness.
    var decodeSpeedLevel: Int = 0
    /// Each level absorbs one erroneous tap per session (passive shield).
    var shieldLevel: Int = 0

    /// Spendable cryptocurrency earned by cracking data cores.
    var credits: Int = 0

    enum CodingKeys: String, CodingKey { case ramLevel, decodeSpeedLevel, shieldLevel, credits }

    static let starter = Cyberdeck()
}

/// The upgradeable parameters and their deterministic cost/effect scaling.
///
/// Costs and effects are hardcoded (brief 10.3, "Deterministic"): identical
/// stats always yield identical baseline values. Kept as a separate spec type
/// so the upgrade screen and the engine read the same numbers.
enum CyberdeckUpgrade: String, CaseIterable, Identifiable, Sendable {
    case ram
    case decodeSpeed
    case shield

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ram:         return "RAM Buffer"
        case .decodeSpeed: return "Decode Speed"
        case .shield:      return "Failsafe Shield"
        }
    }

    /// Highest level purchasable for this upgrade.
    var maxLevel: Int {
        switch self {
        case .ram:         return 8
        case .decodeSpeed: return 6
        case .shield:      return 3
        }
    }

    /// Deterministic cost to go from `currentLevel` to `currentLevel + 1`.
    func cost(atLevel currentLevel: Int) -> Int {
        let base: Int
        switch self {
        case .ram:         base = 100
        case .decodeSpeed: base = 150
        case .shield:      base = 400
        }
        // Geometric scaling: each level ~1.6x the previous.
        return Int(Double(base) * pow(1.6, Double(currentLevel)))
    }

    func currentLevel(in deck: Cyberdeck) -> Int {
        switch self {
        case .ram:         return deck.ramLevel
        case .decodeSpeed: return deck.decodeSpeedLevel
        case .shield:      return deck.shieldLevel
        }
    }
}
