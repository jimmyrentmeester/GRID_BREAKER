import Foundation

// Standalone verification of the PROTOCOL difficulty ramp (Phase 4).
// Tests the four score-scaled GameConfig accessors and verifies the engine
// reads them at the right call-sites (difficultyBias lets us inject a score
// without actually playing, since scaledScore = score + difficultyBias).
//
// Run from the repo root:  scripts/enginecheck/run.sh ramp

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}
func isSetSpawned(_ e: [GameEvent]) -> Bool {
    e.contains { if case .daemonSetSpawned = $0 { return true }; return false }
}
func isDMZSpawned(_ e: [GameEvent]) -> Bool {
    e.contains { if case .dmzSpawned = $0 { return true }; return false }
}
func isOverrun(_ e: [GameEvent]) -> Bool {
    e.contains { if case .dmzOverrunSpawned = $0 { return true }; return false }
}

// Tick until a DAEMON SET spawns; return the set nodes sorted by order.
func spawnSet(_ engine: inout GridEngine) -> [GridNode] {
    for _ in 0..<120 {
        let ev = engine.tick(deltaTime: 0.1)
        if isSetSpawned(ev) { break }
    }
    return engine.snapshot.nodes.filter { $0.setOrder != nil }.sorted { $0.setOrder! < $1.setOrder! }
}

// Tick until a DMZ spawns; return the zone cells.
func spawnDMZ(_ engine: inout GridEngine) -> Set<Int> {
    for _ in 0..<120 {
        let ev = engine.tick(deltaTime: 0.1)
        if isDMZSpawned(ev) { break }
    }
    return engine.snapshot.dmzZone
}

let proto = GameConfig.protocolMode()

// MARK: 1 — objective gap: base, floor, monotone
check(proto.objectiveGap(atScore: 0) == proto.objectiveInterval,
      "objectiveGap at score 0 == base interval (\(proto.objectiveInterval) s)")
check(proto.objectiveGap(atScore: 10_000) == proto.minObjectiveInterval,
      "objectiveGap at score 10000 == floor (\(proto.minObjectiveInterval) s)")
let gaps = [0, 10, 25, 50, 100, 200].map { proto.objectiveGap(atScore: $0) }
let gapsMonotone = zip(gaps, gaps.dropFirst()).allSatisfy { $0 >= $1 }
check(gapsMonotone, "objectiveGap is monotonically non-increasing with score (gaps: \(gaps.map { String(format: "%.2f", $0) }))")
check(proto.objectiveGap(atScore: 50) > proto.minObjectiveInterval
      && proto.objectiveGap(atScore: 50) < proto.objectiveInterval,
      "objectiveGap at score 50 is strictly between base and floor")

// MARK: 2 — DMZ overrun pace: base, floor, monotone
check(proto.dmzOverrunPace(atScore: 0) == proto.dmzOverrunInterval,
      "dmzOverrunPace at score 0 == base interval (\(proto.dmzOverrunInterval) s)")
check(proto.dmzOverrunPace(atScore: 10_000) == proto.minDmzOverrunInterval,
      "dmzOverrunPace at score 10000 == floor (\(proto.minDmzOverrunInterval) s)")
let paces = [0, 20, 50, 100, 200].map { proto.dmzOverrunPace(atScore: $0) }
let pacesMonotone = zip(paces, paces.dropFirst()).allSatisfy { $0 >= $1 }
check(pacesMonotone, "dmzOverrunPace is monotonically non-increasing with score (paces: \(paces.map { String(format: "%.2f", $0) }))")

// MARK: 3 — DAEMON SET size range: starts small, grows to full range
let setRange0 = proto.daemonSetSizeRange(atScore: 0)
check(setRange0 == proto.daemonSetMinSize...proto.daemonSetMinSize,
      "daemonSetSizeRange at score 0 is (min…min) = \(setRange0)")
let setRangeFull = proto.daemonSetSizeRange(atScore: proto.daemonSetSizeRampScore * (proto.daemonSetMaxSize - proto.daemonSetMinSize))
check(setRangeFull.upperBound == proto.daemonSetMaxSize,
      "daemonSetSizeRange at threshold score reaches full max (\(setRangeFull))")
// All intermediate ranges must be valid (lower ≤ upper)
for s in stride(from: 0, through: 100, by: 5) {
    let r = proto.daemonSetSizeRange(atScore: s)
    if r.lowerBound > r.upperBound {
        check(false, "daemonSetSizeRange at score \(s) is invalid: \(r)")
    }
}
check(true, "daemonSetSizeRange is valid at every score 0…100 (step 5)")

// MARK: 4 — DMZ zone size range: starts small, grows to full range
let dmzRange0 = proto.dmzSizeRange(atScore: 0)
check(dmzRange0 == proto.dmzMinSize...proto.dmzMinSize,
      "dmzSizeRange at score 0 is (min…min) = \(dmzRange0)")
let dmzRangeFull = proto.dmzSizeRange(atScore: proto.dmzSizeRampScore * (proto.dmzMaxSize - proto.dmzMinSize))
check(dmzRangeFull.upperBound == proto.dmzMaxSize,
      "dmzSizeRange at threshold score reaches full max (\(dmzRangeFull))")

// MARK: 5 — engine reads the set size range (difficultyBias injects scaledScore)

// At bias 0 (score 0), sets are always size 2.
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1; c.dmzEnabled = false; c.firewallSpawnChance = 0
    var engine = GridEngine(config: c, deck: .starter, seed: 42)
    let set = spawnSet(&engine)
    check(set.count == 2, "at scaledScore 0 the set spawns with n=2 (range is 2…2, got \(set.count))")
}

// At bias = sizeRampScore × 2 the full 2…4 range is unlocked; over 20 seeds we
// must see at least one set with n > 2 (P(never) ≈ (1/3)^20 < 0.001%).
do {
    var c = GameConfig.protocolMode()
    c.objectiveInterval = 0.1; c.dmzEnabled = false; c.firewallSpawnChance = 0
    let bias = c.daemonSetSizeRampScore * (c.daemonSetMaxSize - c.daemonSetMinSize)
    var sawLargeSet = false
    for seed in UInt64(0)..<20 {
        var e = GridEngine(config: c, deck: .starter, seed: seed, difficultyBias: bias)
        let s = spawnSet(&e)
        if s.count > 2 { sawLargeSet = true; break }
    }
    check(sawLargeSet, "with scaledScore at ramp threshold, sets can spawn with n > 2")
}

// MARK: 6 — engine reads the DMZ overrun pace (faster creep at high bias)
//
// Strategy: at bias 0 we measure how many ticks it takes for the first creep;
// at a high bias the pace accessor returns a shorter interval → fewer ticks.
do {
    func ticksToOverrun(bias: Int, seed: UInt64) -> Int {
        var c = GameConfig.protocolMode()
        c.objectiveInterval = 0.1; c.daemonSetEnabled = false; c.firewallSpawnChance = 0
        c.baseRAMSeconds = 100_000; c.ramDrainPerSecond = 0
        var engine = GridEngine(config: c, deck: .starter, seed: seed, difficultyBias: bias)
        // Wait for the zone to spawn.
        for _ in 0..<120 { if isDMZSpawned(engine.tick(deltaTime: 0.05)) { break } }
        // Count ticks until the first overrun creep.
        for i in 1...200 {
            if isOverrun(engine.tick(deltaTime: 0.05)) { return i }
        }
        return 200
    }
    let lowBias  = ticksToOverrun(bias: 0, seed: 7)
    let highBias = ticksToOverrun(bias: 200, seed: 7)
    check(highBias < lowBias,
          "overrun fires sooner at high scaledScore (\(highBias) ticks) than at low (\(lowBias) ticks)")
}

print(failures == 0 ? "\n🎉 ALL RAMP CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
