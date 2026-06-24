import Foundation

/// A short "what's new" briefing shown the first time a core introduces a mechanic.
struct CoreFeature: Sendable, Equatable {
    let title: String       // e.g. "ARMORED DAEMONS"
    let detail: String      // one-line how-to
    let symbol: String      // SF Symbol
}

/// A campaign chapter — a themed group of cores that introduces ONE new mechanic
/// family and gives the player room to practise it before the next chapter. The
/// climax of each chapter is a `isBoss` core. Pure data; the level select reads it.
struct Chapter: Identifiable, Sendable, Equatable {
    let id: Int             // 1-based chapter number
    let title: String       // e.g. "The Outer Net"
    let tagline: String     // one-line netrunner flavour for the chapter header
}

/// One campaign "data core" — a hand-tuned **time-attack** level: reach
/// `targetScore` before the `timeBudget`-second RAM countdown runs out.
/// `difficultyBias` offsets the engine's difficulty scaling so later cores run at
/// a faster, busier pace. Mechanics are gated in **cumulatively**; a new one is
/// introduced only at the start of a chapter (with a `briefing`), then practised.
/// Pure data; the engine and UI read it.
struct DataCore: Identifiable, Sendable, Equatable {
    let id: Int            // 1-based core number / order
    let chapter: Int       // which chapter this core belongs to
    let name: String
    let targetScore: Int
    let timeBudget: TimeInterval
    let difficultyBias: Int
    /// Chapter finale — a tougher climax (wired to a PROTOCOL objective in a later slice).
    var isBoss: Bool = false
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
    /// The chapters. One new mechanic per chapter, then practice, then a boss — so a new
    /// idea always gets breathing room (fixes the "introduces new things too fast" feedback).
    static let chapters: [Chapter] = [
        Chapter(id: 1, title: "The Outer Net",
                tagline: "Low ICE, fat data. A good place to learn the trade."),
        Chapter(id: 2, title: "Corporate ICE",
                tagline: "Live firewalls now. Stay clean and the grid catches Fever."),
        Chapter(id: 3, title: "Deep Systems",
                tagline: "Caches worth a fortune, worms that won't sit still."),
        Chapter(id: 4, title: "The Core",
                tagline: "Every system, full tilt. Crack the Monolith."),
    ]

    /// The tuned ladder, grouped into 4 chapters (16 cores). A new mechanic appears only on
    /// a chapter's intro core (with a briefing); the next core(s) practise it before the
    /// chapter boss. Targets dip slightly at each chapter open (a breather to learn the new
    /// mechanic) then climb within the chapter — a gentle sawtooth, not a single steep ramp.
    /// `difficultyBias` (spawn speed + density + hazards) flattens within a chapter and steps
    /// up between chapters. Calibrate with the multi-skill headless sim before shipping.
    static let cores: [DataCore] = [
        // ── Chapter 1 · The Outer Net — new: armored ───────────────────────────────
        DataCore(id: 1, chapter: 1, name: "Sector-7 Cache", targetScore: 18, timeBudget: 55, difficultyBias: 0,
                 briefing: CoreFeature(title: "DECODE THE GRID",
                                       detail: "Tap glowing daemons before they expire. Hit the target before RAM runs out.",
                                       symbol: "circle.grid.cross.fill")),
        DataCore(id: 2, chapter: 1, name: "Open Relay", targetScore: 26, timeBudget: 55, difficultyBias: 10),
        DataCore(id: 3, chapter: 1, name: "Sentinel Gate", targetScore: 34, timeBudget: 58, difficultyBias: 25,
                 armored: true,
                 briefing: CoreFeature(title: "ARMORED DAEMONS",
                                       detail: "Magenta shells take two taps: crack the shell, then decode.",
                                       symbol: "lock.shield.fill")),
        DataCore(id: 4, chapter: 1, name: "Lockchain", targetScore: 44, timeBudget: 60, difficultyBias: 45,
                 isBoss: true, armored: true),
        // ── Chapter 2 · Corporate ICE — new: firewall bombs, Fever ──────────────────
        DataCore(id: 5, chapter: 2, name: "Cold Storage Node", targetScore: 40, timeBudget: 60, difficultyBias: 55,
                 armored: true, bombs: true,
                 briefing: CoreFeature(title: "FIREWALL BOMBS",
                                       detail: "Never tap a red firewall — it ends the run. Let it expire safely.",
                                       symbol: "exclamationmark.triangle.fill")),
        DataCore(id: 6, chapter: 2, name: "Minefield", targetScore: 52, timeBudget: 64, difficultyBias: 75,
                 armored: true, bombs: true),
        DataCore(id: 7, chapter: 2, name: "Overload", targetScore: 62, timeBudget: 66, difficultyBias: 95,
                 armored: true, bombs: true, fever: true,
                 briefing: CoreFeature(title: "FEVER MODE",
                                       detail: "Chain 8 clean decodes to trigger Fever: ×2 score and golden nodes.",
                                       symbol: "bolt.fill")),
        DataCore(id: 8, chapter: 2, name: "Trap Room", targetScore: 74, timeBudget: 68, difficultyBias: 120,
                 isBoss: true, armored: true, bombs: true, fever: true),
        // ── Chapter 3 · Deep Systems — new: data caches, worms ──────────────────────
        DataCore(id: 9, chapter: 3, name: "Data Vault", targetScore: 70, timeBudget: 68, difficultyBias: 130,
                 armored: true, bombs: true, fever: true, cache: true,
                 briefing: CoreFeature(title: "DATA CACHE",
                                       detail: "Grab the gold cache fast — it's a big score spike. Missing it is harmless.",
                                       symbol: "square.stack.3d.up.fill")),
        DataCore(id: 10, chapter: 3, name: "Black Market Ledger", targetScore: 84, timeBudget: 70, difficultyBias: 160,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 briefing: CoreFeature(title: "WORM DAEMON",
                                       detail: "The green worm hops to a nearby cell — catch it where it lands.",
                                       symbol: "scribble.variable")),
        DataCore(id: 11, chapter: 3, name: "Infestation", targetScore: 100, timeBudget: 70, difficultyBias: 195,
                 armored: true, bombs: true, fever: true, cache: true, worm: true),
        DataCore(id: 12, chapter: 3, name: "The Hunt", targetScore: 116, timeBudget: 72, difficultyBias: 225,
                 isBoss: true, armored: true, bombs: true, fever: true, cache: true, worm: true),
        // ── Chapter 4 · The Core — new: power-ups, grid 4×4 ─────────────────────────
        DataCore(id: 13, chapter: 4, name: "Daemon Foundry", targetScore: 110, timeBudget: 72, difficultyBias: 230,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze],
                 briefing: CoreFeature(title: "POWER-UP: FREEZE",
                                       detail: "Tap the ❄ pickup to freeze the RAM clock and the grid for a few seconds.",
                                       symbol: "snowflake")),
        DataCore(id: 14, chapter: 4, name: "Quarantine Vault", targetScore: 130, timeBudget: 74, difficultyBias: 260,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge],
                 briefing: CoreFeature(title: "POWER-UPS: OVERCLOCK & PURGE",
                                       detail: "⚡ doubles your score for a while; 🌀 instantly clears every firewall.",
                                       symbol: "sparkles")),
        DataCore(id: 15, chapter: 4, name: "Black ICE Core", targetScore: 150, timeBudget: 70, difficultyBias: 285,
                 armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge], grid4x4: true,
                 briefing: CoreFeature(title: "GRID EXPANSION",
                                       detail: "Reach the halfway mark and the grid grows to 4×4 — more targets, faster.",
                                       symbol: "square.grid.4x3.fill")),
        DataCore(id: 16, chapter: 4, name: "The Monolith", targetScore: 180, timeBudget: 72, difficultyBias: 310,
                 isBoss: true, armored: true, bombs: true, fever: true, cache: true, worm: true,
                 powerKinds: [.timeFreeze, .overclock, .purge], grid4x4: true,
                 briefing: CoreFeature(title: "THE MONOLITH",
                                       detail: "Every system at once, at full tilt. Crack it and the grid is yours.",
                                       symbol: "crown.fill")),
    ]

    static func core(id: Int) -> DataCore? { cores.first { $0.id == id } }
    static var count: Int { cores.count }

    /// Chapter lookup + the cores within a chapter (in order).
    static func chapter(id: Int) -> Chapter? { chapters.first { $0.id == id } }
    static func cores(inChapter chapterID: Int) -> [DataCore] { cores.filter { $0.chapter == chapterID } }
}
