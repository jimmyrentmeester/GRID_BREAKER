import Foundation

/// Optional self-imposed challenges for Endless. Each makes the run harder and, in return,
/// multiplies the **Credits** earned — a risk/reward depth layer built entirely from existing
/// systems (no new content). They deliberately do NOT touch the leaderboard score, so the
/// global board stays a fair, like-for-like comparison; the reward is Credits, which only
/// ever buy upgrades/cosmetics (never pay-to-win). Pure data over `GameConfig`.
enum RunModifier: String, CaseIterable, Identifiable, Sendable {
    case noFever, doubleFirewalls, suddenDrain, blitz

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noFever:         return "NO FEVER"
        case .doubleFirewalls: return "DOUBLE FIREWALLS"
        case .suddenDrain:     return "SUDDEN DRAIN"
        case .blitz:           return "BLITZ"
        }
    }

    var detail: String {
        switch self {
        case .noFever:         return "Fever never triggers — no relief, no ×2."
        case .doubleFirewalls: return "Twice as many firewall bombs on the board."
        case .suddenDrain:     return "Your RAM clock drains 40% faster."
        case .blitz:           return "Daemons spawn faster from the very first second."
        }
    }

    var symbol: String {
        switch self {
        case .noFever:         return "bolt.slash.fill"
        case .doubleFirewalls: return "exclamationmark.triangle.fill"
        case .suddenDrain:     return "hourglass.bottomhalf.filled"
        case .blitz:           return "hare.fill"
        }
    }

    /// Credit bonus this modifier adds to the run multiplier when it's on.
    var creditBonus: Double {
        switch self {
        case .noFever:         return 0.30
        case .doubleFirewalls: return 0.30
        case .suddenDrain:     return 0.40
        case .blitz:           return 0.25
        }
    }

    /// Apply this modifier's tweak to an (endless) config.
    func apply(to c: inout GameConfig) {
        switch self {
        case .noFever:         c.feverEnabled = false
        case .doubleFirewalls: c.firewallSpawnChance = min(0.40, c.firewallSpawnChance * 2)
        case .suddenDrain:     c.ramDrainPerSecond *= 1.40
        case .blitz:           c.baseSpawnInterval *= 0.70; c.minSpawnInterval *= 0.80
        }
    }

    static func from(ids: [String]) -> [RunModifier] { ids.compactMap { RunModifier(rawValue: $0) } }

    static func apply(_ mods: [RunModifier], to c: inout GameConfig) { for m in mods { m.apply(to: &c) } }

    /// Credit multiplier for a set of enabled modifiers (1.0 = none).
    static func creditMultiplier(_ mods: [RunModifier]) -> Double {
        1.0 + mods.reduce(0) { $0 + $1.creditBonus }
    }
}
