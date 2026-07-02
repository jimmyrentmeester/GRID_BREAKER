import Foundation

// Standalone verification of the DAEMON SET tap resolution (PROTOCOL phase 2).
// Compiled together with the Core engine/model files (pure value types, no SwiftUI) —
// the deterministic-core QA pattern from VERIFICATION_NOTES (no simulator needed).
//
// Run from the repo root:  scripts/enginecheck/run.sh daemonset
// (top-level code compiles only as main.swift, so the runner copies it into one)

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}
func isSpawned(_ e: [GameEvent]) -> Bool { e.contains { if case .daemonSetSpawned = $0 { return true }; return false } }
func isAdvanced(_ e: [GameEvent]) -> Bool { e.contains { if case .daemonSetAdvanced = $0 { return true }; return false } }
func isCompleted(_ e: [GameEvent]) -> Bool { e.contains { if case .daemonSetCompleted = $0 { return true }; return false } }
func isWrong(_ e: [GameEvent]) -> Bool { e.contains { if case .daemonSetWrongOrder = $0 { return true }; return false } }

func spawnSet(_ engine: inout GridEngine) -> [GridNode] {
    for _ in 0..<80 {
        let ev = engine.tick(deltaTime: 0.15)
        if isSpawned(ev) { break }
    }
    return engine.snapshot.nodes.filter { $0.setOrder != nil }.sorted { $0.setOrder! < $1.setOrder! }
}

// MARK: 1 — spawn + structure
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1
    c.dmzEnabled = false        // isolate DAEMON SET (protocolMode also enables DMZ)
    c.firewallSpawnChance = 0
    var engine = GridEngine(config: c, deck: .starter, seed: 42)
    let set = spawnSet(&engine)
    let n = set.count
    check(n >= 2 && n <= 4, "set spawns with 2…4 nodes (got \(n))")
    check(set.map { $0.setOrder! } == Array(1...n), "orders are 1...\(n): \(set.map { $0.setOrder! })")
    check(set.allSatisfy { $0.setSize == n }, "every node carries setSize=\(n)")
}

// MARK: 2 — out-of-order tap is a miss, set unchanged
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1
    c.dmzEnabled = false        // isolate DAEMON SET (protocolMode also enables DMZ)
    c.firewallSpawnChance = 0
    var engine = GridEngine(config: c, deck: .starter, seed: 7)
    let set = spawnSet(&engine)
    let n = set.count
    if n >= 2 {
        let scoreBefore = engine.snapshot.score
        let ramBefore = engine.snapshot.ramRemaining
        let ev = engine.handleTap(cellIndex: set.last!.cellIndex)   // tap order n first
        check(isWrong(ev), "tapping order \(n) first → wrongOrder")
        check(engine.snapshot.nodes.contains { $0.setOrder == n }, "wrong-order node stays on the board")
        check(engine.snapshot.score == scoreBefore, "wrong-order tap scores nothing")
        check(engine.snapshot.ramRemaining < ramBefore, "wrong-order tap costs RAM (penalty)")
    } else { check(false, "needed a set of >=2 for the out-of-order test") }
}

// MARK: 3 — in-order taps advance then complete; board clears
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1
    c.dmzEnabled = false        // isolate DAEMON SET (protocolMode also enables DMZ)
    c.firewallSpawnChance = 0
    var engine = GridEngine(config: c, deck: .starter, seed: 99)
    let set = spawnSet(&engine)
    let n = set.count
    for k in 1...n {
        let node = engine.snapshot.nodes.first { $0.setOrder == k }!
        let ev = engine.handleTap(cellIndex: node.cellIndex)
        if k < n {
            check(isAdvanced(ev) && !isCompleted(ev), "in-order tap \(k)/\(n) advances")
        } else {
            check(isCompleted(ev), "in-order tap \(k)/\(n) completes the set")
        }
    }
    check(!engine.snapshot.nodes.contains { $0.setOrder != nil }, "no set nodes remain after completion")
}

// MARK: 4 — completion arms a ×4 next decode (isolate: no streak/fever, standard-only mix)
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1
    c.dmzEnabled = false        // isolate DAEMON SET (protocolMode also enables DMZ)
    c.firewallSpawnChance = 0; c.armoredSpawnChance = 0; c.cacheSpawnChance = 0
    c.wormSpawnChance = 0; c.powerUpSpawnChance = 0     // every spawn is a 1-tap standard daemon
    c.feverEnabled = false
    c.streakTierThresholds = []          // streakMultiplier stays 1
    c.daemonSetReward = 4
    var engine = GridEngine(config: c, deck: .starter, seed: 123)
    let set = spawnSet(&engine)
    let n = set.count
    for k in 1...n {                      // complete the set
        let node = engine.snapshot.nodes.first { $0.setOrder == k }!
        _ = engine.handleTap(cellIndex: node.cellIndex)
    }
    // Find the next tappable node (a fresh set's order-1, or a plain daemon) — ticks don't
    // decode, so the armed ×4 survives until the next actual decode.
    func nextTappable(_ e: inout GridEngine) -> Int? {
        for _ in 0..<60 {
            if let s = e.snapshot.nodes.filter({ $0.setOrder != nil }).min(by: { $0.setOrder! < $1.setOrder! }) { return s.cellIndex }
            if let nd = e.snapshot.nodes.first(where: { $0.setOrder == nil && $0.type == .standardDaemon }) { return nd.cellIndex }
            _ = e.tick(deltaTime: 0.1)
        }
        return nil
    }
    if let cell = nextTappable(&engine) {
        let before = engine.snapshot.score
        _ = engine.handleTap(cellIndex: cell)
        let gain = engine.snapshot.score - before
        check(gain == c.scoreStandard * 4, "first decode after the set gets ×4 (gain \(gain), expected \(c.scoreStandard * 4))")
        if let cell2 = nextTappable(&engine) {
            let b2 = engine.snapshot.score
            _ = engine.handleTap(cellIndex: cell2)
            check(engine.snapshot.score - b2 == c.scoreStandard, "the ×4 is one-shot (next decode back to ×1)")
        }
    } else { check(false, "needed a tappable node to test the ×4 reward") }
}

// MARK: 5 — in PROTOCOL, a set-triggered Fever is the BASE window, not ×4
// (the fever-never-depletes fix: setFeverDurationMult=1 in PROTOCOL because sets are
// the core loop; the ×4 climactic set-Fever lives on for campaign — see feverdur.swift).
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1
    c.dmzEnabled = false        // isolate DAEMON SET (protocolMode also enables DMZ)
    c.firewallSpawnChance = 0
    c.feverEnabled = true
    c.feverComboThreshold = 2
    c.feverThresholdRampPerFever = 0
    c.daemonSetMinSize = 2
    c.daemonSetMaxSize = 2               // a 2-set completes at combo 2 = the threshold
    c.daemonSetReward = 4                // still a ×4 SCORE reward on the next decode…
    var engine = GridEngine(config: c, deck: .starter, seed: 55)
    let set = spawnSet(&engine)
    let n = set.count
    check(n == 2, "forced a 2-node set (got \(n))")
    for k in 1...n {
        let node = engine.snapshot.nodes.first { $0.setOrder == k }!
        _ = engine.handleTap(cellIndex: node.cellIndex)
    }
    check(engine.snapshot.feverActive, "completing the set triggered Fever")
    // …but NOT a ×4 duration: PROTOCOL's set-Fever is the base window (fraction ≈ 1.0).
    check(engine.snapshot.feverFraction <= 1.05,
          "PROTOCOL set-Fever is the base window, not ×4 (fraction \(String(format: "%.2f", engine.snapshot.feverFraction)))")
}

print(failures == 0 ? "\n🎉 ALL DAEMON SET CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
