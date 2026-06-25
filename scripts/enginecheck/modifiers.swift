import Foundation

// Verifies the Endless run modifiers (slice 5): the credit-multiplier math and each
// modifier's GameConfig tweak. Deterministic-core QA pattern (no simulator).
//
//   scripts/enginecheck/run.sh modifiers

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}

// MARK: 1 — credit multiplier math
check(abs(RunModifier.creditMultiplier([]) - 1.0) < 0.0001, "no modifiers = ×1.00")
let all = RunModifier.allCases
let expected = 1.0 + all.reduce(0.0) { $0 + $1.creditBonus }
check(abs(RunModifier.creditMultiplier(all) - expected) < 0.0001,
      String(format: "all modifiers sum to ×%.2f", expected))

// MARK: 2 — each modifier tweaks the right config field
do {
    var c = GameConfig.endless()
    check(c.feverEnabled, "endless enables Fever by default")
    RunModifier.noFever.apply(to: &c)
    check(!c.feverEnabled, "No Fever disables Fever")
}
do {
    var c = GameConfig.endless(); let before = c.firewallSpawnChance
    RunModifier.doubleFirewalls.apply(to: &c)
    check(c.firewallSpawnChance > before, "Double Firewalls raises firewall chance (\(before)→\(c.firewallSpawnChance))")
    check(c.firewallSpawnChance <= 0.40 + 1e-9, "firewall chance capped at 0.40")
}
do {
    var c = GameConfig.endless(); let before = c.ramDrainPerSecond
    RunModifier.suddenDrain.apply(to: &c)
    check(c.ramDrainPerSecond > before, "Sudden Drain raises RAM drain (\(before)→\(c.ramDrainPerSecond))")
}
do {
    var c = GameConfig.endless(); let before = c.baseSpawnInterval
    RunModifier.blitz.apply(to: &c)
    check(c.baseSpawnInterval < before, "Blitz lowers spawn interval (\(before)→\(c.baseSpawnInterval))")
}

// MARK: 3 — stacking applies all
do {
    var c = GameConfig.endless()
    RunModifier.apply([.noFever, .blitz], to: &c)
    check(!c.feverEnabled && c.baseSpawnInterval < GameConfig.endless().baseSpawnInterval,
          "stacked modifiers both apply")
}

print(failures == 0 ? "\n🎉 all modifier checks passed" : "\n💥 \(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
