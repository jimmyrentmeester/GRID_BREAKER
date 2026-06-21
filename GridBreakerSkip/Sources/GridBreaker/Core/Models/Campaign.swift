import Foundation

/// A short "what's new" briefing shown the first time a core introduces a mechanic.
struct CoreFeature: Sendable, Equatable {
    let title: String       // e.g. "ARMORED DAEMONS"
    let detail: String      // one-line how-to
    let symbol: String      // SF Symbol
}

/// One campaign "data core" — a hand-tuned **time-attack** level: reach
/// `targetScore` before the `timeBudget`-second RAM countdown runs out.
/// `difficultyBias` offsets the engine's difficulty scaling so later cores run at
/// a faster, busier pace. Mechanics are gated in **cumulatively** as the ladder
/// rises (each core adds roughly one), and a `briefing` explains the new one.
/// Pure data; the engine and UI read it.
struct DataCore: Identifiable, Sendable, Equatable {
    let id: Int            // 1-based core number / order
    let name: String
    let targetScore: Int
    let timeBudget: TimeInterval
    let difficultyBias: Int
    // Cumulative feature gates.
    var armored: Bool = false
    var bombs: Bool = false
    var fever: Bool = false
    var cache: Bool = false
    var worm: Bool = false
    var powerKinds: [PowerUpKind] = []
    var grid4x4: Bool = false
    /// What's newly introduced on this core (nil = nothing new to explain).
    var briefing: CoreFeature? = nil
}

enum Campaign {
    /// The tuned ladder. Mechanics are introduced one at a time and explained; targets
    /// rise and the per-core `difficultyBias` drives a deliberate, gradual difficulty
    /// curve. The campaign starts deliberately gentle — see `GameConfig.campaign` — with
    /// long ~1.1 s pauses between spawns and 2 s node lifespans, and the bias compresses
    /// both toward a ~0.30 s frantic finale (difficulty = spawn speed + board density +
    /// hazards, climbing together). Time budgets are generous so a real beginner has
    /// margin. Calibrated with the multi-skill headless sim (strong/good/casual reaction
    /// on a starter deck): casual clears ~core 7, good ~core 9–10, a strong player
    /// finishes; Cyberdeck upgrades make it more forgiving still. Human playtest pending.
    static let cores: [DataCore] = [
        DataCore(id: 1, name: "Sector-7 Cache", targetScore: 22, timeBudget: 52, difficultyBias: 0,
                 briefing: CoreFeature(title: "DECODE THE GRID",
                                       detail: "Tap glowing daemons before they expire. Hit the target before RAM runs out.",
                                       symbol: "circle.grid.cross.fill")),
        DataCore(id: 2, name: "Public Grid Relay", targetScore: 32, timeBudget: 57, difficultyBias: 15,
                 armored: true,
                 briefing: CoreFeature(title: "ARMORED DAEMONS",
                                       detail: "Magenta shells take two taps: crack the shell, then decode.",
                                       symbol: "lock.shield.fill")),
        DataCore(id: 3, name: "Cold Storage Node", targetScore: 42, timeBudget: 60, difficultyBias: 35,
                 armored: true, bombs: true,
                 briefing: CoreFeature(title: "FIREWALL BOMBS",
                                       detail: "Never tap a red firewall — it ends the run. Let it expire safely.",
                                       symbol: "exclamationmark.triangle.fill")),
        DataCore(id: 4, name: "Sentinel Subnet", targetScore: 54, timeBudget: 65, difficultyBias: 60,
                 armored: true, bombs: true, fever: true,
                 briefing: CoreFeature(title: "FEVER MODE",
                                       detail: "Chain 8 clean decodes to trigger Fever: ×2 score and golden nodes.",
                                       symbol: "bolt.fill")),
        DataCore(id: 5, name: "Ice Wall", targetScore: 68, timeBudget: 70, difficultyBias: 90,
                 armored: true, bombs: true, fever: true, cache: true,
                 briefing: CoreFeature(title: "DATA CACHE",
                                       detail: "Grab the gold cache fast — it's a big score spike. Missing it is harmless.",
                                       symbol: "square.stack.3d.up.fill")),
        DataCore(id: 6, name: "Black Market Ledger", targetScore: 84, timeBudget: 73, difficultyBias: 100,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 briefing: CoreFeature(title: "WORM DAEMON",
                                       detail: "The green worm hops to a nearby cell — catch it where it lands.",
                                       symbol: "scribble.variable")),
        DataCore(id: 7, name: "Daemon Foundry", targetScore: 100, timeBudget: 73, difficultyBias: 160,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze],
                 briefing: CoreFeature(title: "POWER-UP: FREEZE",
                                       detail: "Tap the ❄ pickup to freeze the RAM clock and the grid for a few seconds.",
                                       symbol: "snowflake")),
        DataCore(id: 8, name: "Quarantine Vault", targetScore: 120, timeBudget: 75, difficultyBias: 200,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge],
                 briefing: CoreFeature(title: "POWER-UPS: OVERCLOCK & PURGE",
                                       detail: "⚡ doubles your score for a while; 🌀 instantly clears every firewall.",
                                       symbol: "sparkles")),
        DataCore(id: 9, name: "Black ICE Core", targetScore: 145, timeBudget: 68, difficultyBias: 270,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge], grid4x4: true,
                 briefing: CoreFeature(title: "GRID EXPANSION",
                                       detail: "Reach the halfway mark and the grid grows to 4×4 — more targets, faster.",
                                       symbol: "square.grid.4x3.fill")),
        DataCore(id: 10, name: "The Monolith", targetScore: 180, timeBudget: 70, difficultyBias: 300,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge], grid4x4: true,
                 briefing: CoreFeature(title: "THE MONOLITH",
                                       detail: "Every system at once, at full tilt. Crack it and the grid is yours.",
                                       symbol: "crown.fill")),
    ]

    static func core(id: Int) -> DataCore? { cores.first { $0.id == id } }
    static var count: Int { cores.count }
}
