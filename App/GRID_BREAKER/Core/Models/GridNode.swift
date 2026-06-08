import Foundation

/// A live entity occupying one cell of the grid for a bounded lifespan.
///
/// Pure value type. The engine (next milestone) owns spawning/expiry; this
/// model only describes a node's current state so any shell can render it.
struct GridNode: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    /// Flattened grid position: `row * columns + column`. Mutable: a worm hops cells
    /// and the grid escalation remaps positions.
    var cellIndex: Int
    let type: NodeType

    /// Remaining taps before the node is cleared (armored starts at 2).
    var hitsRemaining: Int

    /// Seconds this node stays active before it expires on its own.
    let lifespan: TimeInterval
    /// Session clock value (seconds) at which this node became active.
    let spawnedAt: TimeInterval
    /// For a worm: the next clock value at which it hops to an adjacent cell.
    var nextHopAt: TimeInterval?

    init(id: UUID = UUID(),
         cellIndex: Int,
         type: NodeType,
         lifespan: TimeInterval,
         spawnedAt: TimeInterval,
         nextHopAt: TimeInterval? = nil) {
        self.id = id
        self.cellIndex = cellIndex
        self.type = type
        self.hitsRemaining = type.requiredTaps
        self.lifespan = lifespan
        self.spawnedAt = spawnedAt
        self.nextHopAt = nextHopAt
    }

    /// True once an armored daemon's shell has been breached (1 hit taken).
    var isBreached: Bool { type == .armoredDaemon && hitsRemaining == 1 }

    /// Session clock value at which this node expires if untouched.
    var expiresAt: TimeInterval { spawnedAt + lifespan }
}
