import Foundation

// Standalone verification of the DMZ PURGE objective (PROTOCOL phase 3, issue #4).
// Compiled with the Core engine/model files (pure value types, no SwiftUI) — the
// deterministic-core QA pattern (no simulator needed).
//
// Run from the repo root:  scripts/enginecheck/run.sh dmz
// (top-level code compiles only as main.swift, so the runner copies it into one)

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}
func has(_ e: [GameEvent], _ match: (GameEvent) -> Bool) -> Bool { e.contains(where: match) }
func isDMZSpawned(_ e: [GameEvent]) -> Bool { has(e) { if case .dmzSpawned = $0 { return true }; return false } }
func isOverrun(_ e: [GameEvent]) -> Bool { has(e) { if case .dmzOverrunSpawned = $0 { return true }; return false } }
func isCleared(_ e: [GameEvent]) -> Bool { has(e) { if case .intrusionCleared = $0 { return true }; return false } }
func isPurged(_ e: [GameEvent]) -> Bool { e.contains(.dmzPurged) }
func isOverrunGameOver(_ e: [GameEvent]) -> Bool { e.contains(.gameOver(.dmzOverrun)) }

/// A PROTOCOL config with only the DMZ objective enabled and no RAM pressure, so the
/// tests isolate DMZ mechanics from the daemon stream / clock.
func dmzConfig() -> GameConfig {
    var c = GameConfig.protocolMode()
    c.daemonSetEnabled = false        // isolate DMZ (no alternation)
    c.objectiveInterval = 0.1         // a zone appears almost immediately
    c.firewallSpawnChance = 0
    c.baseRAMSeconds = 100_000        // RAM never runs out during the test…
    c.ramDrainPerSecond = 1.0         // …but it dips below the cap, so relief is measurable
    return c
}

/// Tick until a DMZ spawns; return the zone cells.
func spawnDMZ(_ engine: inout GridEngine) -> Set<Int> {
    for _ in 0..<80 {
        let ev = engine.tick(deltaTime: 0.05)
        if isDMZSpawned(ev) { break }
    }
    return engine.snapshot.dmzZone
}

// MARK: 1 — spawn + structure
do {
    let c = dmzConfig()
    var engine = GridEngine(config: c, deck: .starter, seed: 42)
    let zone = spawnDMZ(&engine)
    let n = zone.count
    check(n >= c.dmzMinSize && n <= c.dmzMaxSize, "zone spawns with \(c.dmzMinSize)…\(c.dmzMaxSize) cells (got \(n))")
    let intrusionCells = Set(engine.snapshot.nodes.filter { $0.type == .intrusion }.map(\.cellIndex))
    check(intrusionCells == zone, "every zone cell holds an intrusion node, none outside (\(intrusionCells) vs \(zone))")
}

// MARK: 2 — the overrun creeps intrusion into a cell OUTSIDE the zone
do {
    let c = dmzConfig()
    var engine = GridEngine(config: c, deck: .starter, seed: 7)
    let zone = spawnDMZ(&engine)
    let before = engine.snapshot.nodes.count
    var sawOverrun = false
    for _ in 0..<Int(c.dmzOverrunInterval / 0.05) + 2 {
        if isOverrun(engine.tick(deltaTime: 0.05)) { sawOverrun = true; break }
    }
    check(sawOverrun, "an overrun creep fires after dmzOverrunInterval")
    let intrusions = engine.snapshot.nodes.filter { $0.type == .intrusion }
    check(intrusions.count == before + 1, "the creep added exactly one intrusion (\(before) → \(intrusions.count))")
    check(intrusions.contains { !zone.contains($0.cellIndex) }, "the creep landed outside the zone")
}

// MARK: 3 — tapping an overrun node clears it (buys time); the DMZ stays active
do {
    let c = dmzConfig()
    var engine = GridEngine(config: c, deck: .starter, seed: 7)
    let zone = spawnDMZ(&engine)
    for _ in 0..<Int(c.dmzOverrunInterval / 0.05) + 2 { if isOverrun(engine.tick(deltaTime: 0.05)) { break } }
    let outside = engine.snapshot.nodes.first { $0.type == .intrusion && !zone.contains($0.cellIndex) }!
    let countBefore = engine.snapshot.nodes.count
    let ev = engine.handleTap(cellIndex: outside.cellIndex)
    check(isCleared(ev) && !isPurged(ev), "clearing an overrun node is a clear, not a purge")
    check(engine.snapshot.nodes.count == countBefore - 1, "the overrun node is gone")
    check(engine.snapshot.dmzZone == zone, "the DMZ is still active after a defensive clear")
}

// MARK: 4 — clearing the whole zone purges: overrun swept, zone dismissed, RAM relief
do {
    let c = dmzConfig()
    var engine = GridEngine(config: c, deck: .starter, seed: 99)
    let zone = spawnDMZ(&engine)
    for _ in 0..<Int(c.dmzOverrunInterval / 0.05) + 2 { if isOverrun(engine.tick(deltaTime: 0.05)) { break } }
    check(engine.snapshot.nodes.contains { $0.type == .intrusion && !zone.contains($0.cellIndex) },
          "at least one overrun node exists before the purge")
    let ramBefore = engine.snapshot.ramRemaining
    let cells = zone.sorted()
    var purged = false
    for (i, cell) in cells.enumerated() {
        let ev = engine.handleTap(cellIndex: cell)
        if i < cells.count - 1 {
            check(!isPurged(ev), "clearing zone cell \(i + 1)/\(cells.count) does not yet purge")
        } else {
            purged = isPurged(ev)
        }
    }
    check(purged, "clearing the last zone cell purges the DMZ")
    check(engine.snapshot.dmzZone.isEmpty, "the zone is dismissed after a purge")
    check(!engine.snapshot.nodes.contains { $0.type == .intrusion }, "the overrun creep is swept on purge")
    check(engine.snapshot.ramRemaining > ramBefore, "a purge grants RAM relief")
}

// MARK: 5 — if the overrun fills the grid before the purge → game over
do {
    let c = dmzConfig()
    var engine = GridEngine(config: c, deck: .starter, seed: 123)
    let zone = spawnDMZ(&engine)
    // Never tap; let the creep fill every cell outside the zone, then one more.
    var gameOver = false
    for _ in 0..<400 {
        if isOverrunGameOver(engine.tick(deltaTime: 0.05)) { gameOver = true; break }
    }
    check(gameOver, "an unchecked overrun ends the run with .dmzOverrun")
    check(engine.snapshot.isGameOver && engine.snapshot.gameOverReason == .dmzOverrun,
          "game-over reason is .dmzOverrun")
    // Sanity: at the moment of overrun, the non-zone cells were all intrusion.
    _ = zone
}

// MARK: 6 — with both objectives on, they alternate (set first, then DMZ)
do {
    var c = GameConfig.protocolMode()   // both daemonSet + dmz enabled
    c.objectiveInterval = 0.1
    c.firewallSpawnChance = 0
    c.baseRAMSeconds = 100_000
    c.ramDrainPerSecond = 0
    var engine = GridEngine(config: c, deck: .starter, seed: 55)
    // First objective = DAEMON SET.
    var firstIsSet = false
    for _ in 0..<80 {
        let ev = engine.tick(deltaTime: 0.05)
        if ev.contains(where: { if case .daemonSetSpawned = $0 { return true }; return false }) { firstIsSet = true; break }
        if isDMZSpawned(ev) { break }   // wrong one first
    }
    check(firstIsSet, "first objective is a DAEMON SET")
    // Complete the set in order.
    while engine.snapshot.nodes.contains(where: { $0.isSetMember }) {
        let next = engine.snapshot.nodes.filter { $0.isSetMember }.min { ($0.setOrder ?? 0) < ($1.setOrder ?? 0) }!
        _ = engine.handleTap(cellIndex: next.cellIndex)
    }
    // Second objective = DMZ PURGE.
    var secondIsDMZ = false
    for _ in 0..<80 {
        let ev = engine.tick(deltaTime: 0.05)
        if isDMZSpawned(ev) { secondIsDMZ = true; break }
        if ev.contains(where: { if case .daemonSetSpawned = $0 { return true }; return false }) { break }
    }
    check(secondIsDMZ, "second objective alternates to a DMZ PURGE")
}

print(failures == 0 ? "\n🎉 ALL DMZ PURGE CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
