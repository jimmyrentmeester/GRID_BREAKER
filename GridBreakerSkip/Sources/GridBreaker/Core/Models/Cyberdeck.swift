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
    /// Each level extends Fever Mode.
    var feverLevel: Int = 0
    /// Each level boosts Credits earned per run.
    var salvageLevel: Int = 0

    /// Spendable cryptocurrency earned by cracking data cores.
    var credits: Int = 0

    enum CodingKeys: String, CodingKey {
        case ramLevel, decodeSpeedLevel, shieldLevel, feverLevel, salvageLevel, credits
    }

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
    case feverCapacitor
    case salvage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ram:            return "RAM Buffer"
        case .decodeSpeed:    return "Decode Speed"
        case .shield:         return "Failsafe Shield"
        case .feverCapacitor: return "Fever Capacitor"
        case .salvage:        return "Salvage Protocol"
        }
    }

    /// Player-facing explanation of the effect. Uses the real `GameConfig` values
    /// so the description can't drift from the actual numbers.
    var detail: String {
        let c = GameConfig.default
        switch self {
        case .ram:
            return "Bigger time buffer — start each run with +\(Int(c.ramSecondsPerLevel))s of RAM per level."
        case .decodeSpeed:
            return "Each decode restores +\(String(format: "%g", c.decodeBonusPerLevel))s of RAM per level (your only refill in Campaign)."
        case .shield:
            return "Absorbs one mistake per level — a mis-tap OR a firewall bomb — no penalty."
        case .feverCapacitor:
            return "Fever Mode lasts +\(String(format: "%g", c.feverBonusPerLevel))s longer per level — more ×2 golden time."
        case .salvage:
            return "Earn +\(Int(c.salvageBonusPerLevel * 100))% Credits from every run, per level."
        }
    }

    /// The total effect bought *so far* at `level` — the cumulative bonus this
    /// upgrade currently contributes. Shown on the upgrade row so the player can
    /// see what their purchases add up to (not just what one more level does).
    /// Reads the real `GameConfig` values (like `detail`) so it can't drift from
    /// what the engine actually applies.
    func cumulativeEffect(at level: Int) -> String {
        let c = GameConfig.default
        switch self {
        case .ram:
            return "+\(Int(c.ramSecondsPerLevel) * level)s RAM buffer"
        case .decodeSpeed:
            return "+\(String(format: "%g", c.decodeBonusPerLevel * Double(level)))s per decode"
        case .shield:
            return level == 1 ? "1 mistake absorbed" : "\(level) mistakes absorbed"
        case .feverCapacitor:
            return "+\(String(format: "%g", c.feverBonusPerLevel * Double(level)))s Fever duration"
        case .salvage:
            return "+\(Int(c.salvageBonusPerLevel * 100) * level)% Credits per run"
        }
    }

    /// Highest level purchasable for this upgrade.
    var maxLevel: Int {
        switch self {
        case .ram:            return 8
        case .decodeSpeed:    return 6
        case .shield:         return 3
        case .feverCapacitor: return 4
        case .salvage:        return 5
        }
    }

    /// Deterministic cost to go from `currentLevel` to `currentLevel + 1`.
    func cost(atLevel currentLevel: Int) -> Int {
        let base: Int
        switch self {
        case .ram:            base = 100
        case .decodeSpeed:    base = 150
        case .shield:         base = 400
        case .feverCapacitor: base = 350
        case .salvage:        base = 250
        }
        // Geometric scaling: each level ~1.6x the previous.
        return Int(Double(base) * pow(1.6, Double(currentLevel)))
    }

    func currentLevel(in deck: Cyberdeck) -> Int {
        switch self {
        case .ram:            return deck.ramLevel
        case .decodeSpeed:    return deck.decodeSpeedLevel
        case .shield:         return deck.shieldLevel
        case .feverCapacitor: return deck.feverLevel
        case .salvage:        return deck.salvageLevel
        }
    }
}
