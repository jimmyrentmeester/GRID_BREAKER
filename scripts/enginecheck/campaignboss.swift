import Foundation

// Verifies the Campaign 2.0 PROTOCOL-boss wiring (slice 2): boss cores enable the right
// objective flags in their config, normal cores enable none, and a boss config actually
// spawns its objective in the engine. Deterministic-core QA pattern (no simulator).
//
//   scripts/enginecheck/run.sh campaignboss

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}
func hasDaemonSet(_ e: [GameEvent]) -> Bool { e.contains { if case .daemonSetSpawned = $0 { return true }; return false } }
func hasDMZ(_ e: [GameEvent]) -> Bool { e.contains { if case .dmzSpawned = $0 { return true }; return false } }
func core(_ id: Int) -> DataCore { Campaign.core(id: id)! }

// MARK: 1 — boss cores enable the right objective flags; normal cores enable none
do {
    let c4 = GameConfig.campaign(for: core(4))    // Lockchain → DAEMON SET
    check(c4.daemonSetEnabled && !c4.dmzEnabled, "core 4 (Lockchain) enables DAEMON SET only")
    let c8 = GameConfig.campaign(for: core(8))    // Trap Room → DMZ PURGE
    check(c8.dmzEnabled && !c8.daemonSetEnabled, "core 8 (Trap Room) enables DMZ only")
    let c16 = GameConfig.campaign(for: core(16))  // The Monolith → both
    check(c16.daemonSetEnabled && c16.dmzEnabled, "core 16 (Monolith) enables both objectives")
    let c3 = GameConfig.campaign(for: core(3))    // Sentinel Gate → normal core
    check(!c3.daemonSetEnabled && !c3.dmzEnabled, "core 3 (non-boss) enables no objectives")
}

// MARK: 2 — a DAEMON SET boss actually spawns the objective in-engine
do {
    var c = GameConfig.campaign(for: core(4))
    c.objectiveInterval = 0.1
    var engine = GridEngine(config: c, deck: .starter, seed: 42)
    var spawned = false
    for _ in 0..<120 where !spawned { if hasDaemonSet(engine.tick(deltaTime: 0.15)) { spawned = true } }
    check(spawned, "core 4 boss spawns a DAEMON SET in-engine")
}

// MARK: 3 — a DMZ boss actually spawns the zone in-engine
do {
    var c = GameConfig.campaign(for: core(8))
    c.objectiveInterval = 0.1
    var engine = GridEngine(config: c, deck: .starter, seed: 42)
    var spawned = false
    for _ in 0..<120 where !spawned { if hasDMZ(engine.tick(deltaTime: 0.15)) { spawned = true } }
    check(spawned, "core 8 boss spawns a DMZ zone in-engine")
}

print(failures == 0 ? "\n🎉 all campaign-boss checks passed" : "\n💥 \(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
