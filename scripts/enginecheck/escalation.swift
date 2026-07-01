import Foundation

// Standalone verification of grid escalation (3×3 → 4×4) interacting with the
// PROTOCOL objectives — The Monolith (core 16) is the one place both run at once.
// Guards two real bugs found in the 1.3 review:
//   (1) an active DMZ zone was NOT remapped on escalation → the zone's indices no
//       longer matched any intrusion node → the zone could never be purged, normal
//       spawns stayed paused, and the run soft-locked into a guaranteed loss;
//   (2) `clearIntrusion` never called checkTarget/checkGridEscalation → a boss-core
//       target crossed on an intrusion clear won a decode LATE (or not at all).
//
// Run from the repo root:  scripts/enginecheck/run.sh escalation

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}
func isDMZSpawned(_ e: [GameEvent]) -> Bool { e.contains { if case .dmzSpawned = $0 { return true }; return false } }
func isPurged(_ e: [GameEvent]) -> Bool { e.contains(.dmzPurged) }
func remap3to4(_ i: Int) -> Int { (i / 3) * 4 + (i % 3) }

/// A Monolith-shaped config: DMZ objective + grid escalation, no distractions
/// (no bombs/worms/power-ups, no RAM pressure) so the interaction is isolated.
func monolithConfig(escalateAt: Int, objectiveGap: TimeInterval = 0.1) -> GameConfig {
    var c = GameConfig.campaign(timeBudget: 100_000)
    c.dmzEnabled = true
    c.daemonSetEnabled = false        // isolate DMZ (no alternation)
    c.objectiveInterval = objectiveGap
    c.objectiveIntervalCompression = 0
    c.gridEscalationScore = escalateAt
    c.firewallSpawnChance = 0
    c.armoredSpawnChance = 0
    c.feverEnabled = false            // fever ×2 would skip scores past the threshold
    c.dmzOverrunInterval = 1000       // the creep never fires during the test
    c.dmzOverrunCompression = 0
    return c
}

/// Tick until a DMZ spawns; return the zone cells.
func spawnDMZ(_ engine: inout GridEngine) -> Set<Int> {
    for _ in 0..<1000 {
        if isDMZSpawned(engine.tick(deltaTime: 0.05)) { break }
    }
    return engine.snapshot.dmzZone
}

/// Decode plain daemons (never intrusions) until `score` ≥ `until`, ticking to spawn.
func decodeDaemons(_ engine: inout GridEngine, until: Int) {
    for _ in 0..<4000 {
        if engine.snapshot.score >= until || engine.snapshot.isGameOver { return }
        if let d = engine.snapshot.nodes.first(where: { $0.type == .standardDaemon && !$0.isSetMember }) {
            _ = engine.handleTap(cellIndex: d.cellIndex)
        } else {
            _ = engine.tick(deltaTime: 0.05)
        }
    }
}

// MARK: 1 — a DMZ active across the escalation is remapped and stays purgeable
do {
    // A wide objective gap: build the score to one-below-threshold on the normal
    // daemon stream FIRST (spawns pause while a DMZ is up), then let the zone land,
    // then decode one leftover daemon to cross the line mid-DMZ.
    let c = monolithConfig(escalateAt: 10, objectiveGap: 15)
    var engine = GridEngine(config: c, deck: .starter, seed: 42, targetScore: 1000)
    decodeDaemons(&engine, until: 9)
    check(engine.snapshot.score == 9, "score parked one below the threshold (got \(engine.snapshot.score))")
    let zone3 = spawnDMZ(&engine)
    check(!zone3.isEmpty, "a DMZ zone is active on the 3×3 grid (\(zone3.sorted()))")
    check(engine.snapshot.gridSize == .threeByThree, "grid is still 3×3 with the zone up")

    // Cross the escalation threshold by decoding a daemon that was already up.
    let live = engine.snapshot.nodes.first { $0.type == .standardDaemon && !$0.isSetMember }
    check(live != nil, "a pre-DMZ daemon is still live when the zone lands")
    guard let live else { exit(1) }
    _ = engine.handleTap(cellIndex: live.cellIndex)
    check(engine.snapshot.gridSize == .fourByFour, "grid escalated to 4×4 mid-DMZ (score \(engine.snapshot.score))")

    let zone4 = engine.snapshot.dmzZone
    check(zone4 == Set(zone3.map(remap3to4)), "the zone was remapped 3×3→4×4 (\(zone3.sorted()) → \(zone4.sorted()))")
    let intrusionCells = Set(engine.snapshot.nodes.filter { $0.type == .intrusion }.map(\.cellIndex))
    check(zone4.isSubset(of: intrusionCells), "every remapped zone cell still holds its intrusion node")
    check(zone4.allSatisfy { $0 < 16 }, "all zone indices are valid 4×4 cells")

    // The regression: the zone must still be purgeable after escalation.
    var purged = false
    for cell in zone4.sorted() {
        if isPurged(engine.handleTap(cellIndex: cell)) { purged = true }
    }
    check(purged, "clearing every remapped zone cell purges the DMZ (no soft-lock)")
    check(engine.snapshot.dmzZone.isEmpty, "the zone is dismissed after the post-escalation purge")
}

// MARK: 2 — crossing the boss target on an intrusion clear wins IMMEDIATELY
do {
    var c = monolithConfig(escalateAt: 1_000_000)   // no escalation in this test
    c.scoreIntrusion = 5                            // make an intrusion clear cross the line
    var engine = GridEngine(config: c, deck: .starter, seed: 7, targetScore: 1)
    let zone = spawnDMZ(&engine)
    check(!zone.isEmpty, "a DMZ zone is active")
    check(!engine.snapshot.isGameOver, "run is still live before the clear")
    let ev = engine.handleTap(cellIndex: zone.sorted()[0])
    check(ev.contains(.gameOver(.coreCracked)), "an intrusion clear crossing the target wins on the spot")
    check(engine.snapshot.didWin, "snapshot reports the win")
}

// MARK: 3 — an intrusion clear crossing the escalation threshold escalates too
do {
    var c = monolithConfig(escalateAt: 5)
    c.scoreIntrusion = 5
    var engine = GridEngine(config: c, deck: .starter, seed: 11, targetScore: 1000)
    let zone = spawnDMZ(&engine)
    check(engine.snapshot.score == 0 && !zone.isEmpty, "zone up at score 0")
    _ = engine.handleTap(cellIndex: zone.sorted()[0])
    check(engine.snapshot.gridSize == .fourByFour, "the escalation fires on the intrusion clear itself")
    // And the still-active zone was remapped in the same breath (fix 1 applies here
    // too). Note: dmzZone keeps ALL its cells until the purge — clearing one node
    // doesn't shrink the zone — so the whole original zone remaps.
    let zone4 = engine.snapshot.dmzZone
    check(zone4 == Set(zone.map(remap3to4)),
          "the still-active zone was remapped during that clear (\(zone.sorted()) → \(zone4.sorted()))")
}

print(failures == 0 ? "\n🎉 ALL ESCALATION CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
