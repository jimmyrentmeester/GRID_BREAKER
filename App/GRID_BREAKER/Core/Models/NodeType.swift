import Foundation

/// The three daemon/node archetypes that can occupy a grid cell.
///
/// Pure value type — no UI, no I/O (ground-truth Part 3.1, "Models").
/// Mechanical properties (lifespan, hit cost, score) live in `GameConfig`,
/// not here, so balancing stays in one deterministic place.
enum NodeType: String, Codable, CaseIterable, Sendable {
    /// Decodes in a single tap. Adds score + replenishes the RAM buffer.
    case standardDaemon

    /// "Security shell" — needs two taps. The first tap breaches the shell
    /// (visual change), the second eliminates it. Inspired by HardHat moles.
    case armoredDaemon

    /// Must NOT be touched. Explodes ONLY on active tap (ends the run);
    /// natural expiry is always safe (brief 10.3 — anti-frustration rule).
    case firewallBomb

    /// A rare, short-lived bonus "data cache": one tap for a big score (and RAM)
    /// spike — a tempting grab under time pressure. Harvestable like a daemon.
    case dataCache

    /// How many taps are required to fully clear this node.
    var requiredTaps: Int {
        switch self {
        case .standardDaemon: return 1
        case .armoredDaemon:  return 2
        case .firewallBomb:   return 0 // never a valid target
        case .dataCache:      return 1
        }
    }

    /// Whether tapping this node is a scoring action (vs. a mistake/hazard).
    var isHarvestable: Bool { self != .firewallBomb }

    /// Whether letting this node expire costs you (RAM + combo). Only real daemons
    /// punish a timeout — a bomb expires safely (brief 10.3) and a missed bonus
    /// cache is just a missed opportunity, not a failure.
    var penalizesOnExpiry: Bool { self == .standardDaemon || self == .armoredDaemon }
}
