import Foundation

// Regression guard for the PROTOCOL "Fever never depletes" fix.
//
// A DAEMON SET completion that triggers Fever lengthens it by config.setFeverDurationMult.
// That was reusing daemonSetReward (×4): fine for rare campaign-boss sets, but in PROTOCOL
// (sets are the core loop) it chained near-permanent Fever. The fix decouples the two —
// PROTOCOL uses ×1, campaign keeps ×4. This check asserts the config values AND the actual
// measured Fever duration in each case.
//
// Run from the repo root:  scripts/enginecheck/run.sh feverdur

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}

// MARK: config values
check(GameConfig.default.setFeverDurationMult == 4, "campaign/default keeps the ×4 climactic set-Fever")
check(GameConfig.protocolMode().setFeverDurationMult == 1, "PROTOCOL uses ×1 (no set-Fever duration bonus)")

/// Measure the Fever duration (seconds) produced when a DAEMON SET *completion* triggers it.
/// Threshold is dropped to 2 and a 2-node set spawned, so tapping the set in order both
/// completes it and crosses the Fever threshold on the same decode → the bonus applies.
func measureSetFeverDuration(mult: Int) -> Double {
    var c = GameConfig.default
    c.feverEnabled = true
    c.feverComboThreshold = 2
    c.feverThresholdRampPerFever = 0
    c.feverDuration = 4.0
    c.daemonSetEnabled = true
    c.dmzEnabled = false
    c.setFeverDurationMult = mult
    c.objectiveInterval = 0.1
    c.objectiveIntervalCompression = 0
    c.baseRAMSeconds = 100_000        // never die during the measurement
    c.ramDrainPerSecond = 0
    c.firewallSpawnChance = 0
    c.armoredSpawnChance = 0
    c.daemonSetMinSize = 2
    c.daemonSetMaxSize = 2

    var engine = GridEngine(config: c, deck: .starter, seed: 4242)
    // Tick until a set spawns.
    for _ in 0..<2000 {
        let ev = engine.tick(deltaTime: 0.05)
        if ev.contains(where: { if case .daemonSetSpawned = $0 { return true }; return false }) { break }
    }
    // Complete the set in order — the final decode both completes it and triggers Fever.
    var triggered = false
    while engine.snapshot.nodes.contains(where: { $0.setOrder != nil }) {
        let next = engine.snapshot.nodes.filter { $0.setOrder != nil }.min { ($0.setOrder ?? 0) < ($1.setOrder ?? 0) }!
        let ev = engine.handleTap(cellIndex: next.cellIndex)
        if ev.contains(.feverStarted) { triggered = true }
    }
    guard triggered, engine.snapshot.feverActive else { return -1 }
    // Tick in fixed steps until Fever ends; count the elapsed time.
    var elapsed = 0.0
    let dt = 0.05
    for _ in 0..<2000 {
        let ev = engine.tick(deltaTime: dt)
        elapsed += dt
        if ev.contains(.feverEnded) { break }
    }
    return elapsed
}

let protoDur = measureSetFeverDuration(mult: 1)
let campDur  = measureSetFeverDuration(mult: 4)
print(String(format: "measured set-Fever: PROTOCOL ×1 = %.2fs, campaign ×4 = %.2fs", protoDur, campDur))

check(protoDur > 3.5 && protoDur < 5.0, "PROTOCOL set-Fever ≈ the base 4s window (got \(String(format: "%.2f", protoDur))s)")
check(campDur > 15.0 && campDur < 17.0, "campaign set-Fever ≈ 4×4 = 16s (got \(String(format: "%.2f", campDur))s)")
check(campDur > protoDur * 3, "the campaign set-Fever is clearly longer than PROTOCOL's (no more permanent PROTOCOL Fever)")

print(failures == 0 ? "\n🎉 ALL FEVER-DURATION CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
