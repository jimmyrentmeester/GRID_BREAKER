import Foundation

// Verifies the Campaign 2.0 star/mastery layer (slice 3): the pure star rating function
// and the engine's mistakes counter. Deterministic-core QA pattern (no simulator).
//
//   scripts/enginecheck/run.sh stars

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}

let core = Campaign.core(id: 5)!   // mid core, timeBudget 60s

// MARK: 1 — pure star rating (cumulative: clear / flawless-or-fast / flawless-and-fast)
check(core.stars(ramRemaining: core.timeBudget, mistakes: 0, won: true) == 3, "flawless + fast = 3★")
check(core.stars(ramRemaining: 0,               mistakes: 0, won: true) == 2, "flawless only  = 2★")
check(core.stars(ramRemaining: core.timeBudget, mistakes: 4, won: true) == 2, "fast only      = 2★")
check(core.stars(ramRemaining: 0,               mistakes: 4, won: true) == 1, "clear only     = 1★")
check(core.stars(ramRemaining: core.timeBudget, mistakes: 0, won: false) == 0, "not won        = 0★")

// MARK: 2 — a mistap increments the engine mistakes counter
do {
    var engine = GridEngine(config: GameConfig.campaign(for: core), deck: .starter, seed: 7)
    _ = engine.tick(deltaTime: 0.2)
    let occupied = Set(engine.snapshot.nodes.map { $0.cellIndex })
    let empty = (0..<9).first { !occupied.contains($0) } ?? 0
    let before = engine.snapshot.mistakes
    _ = engine.handleTap(cellIndex: empty)
    check(engine.snapshot.mistakes == before + 1, "a mistap increments mistakes (\(before)→\(engine.snapshot.mistakes))")
}

// MARK: 3 — an expired daemon increments the mistakes counter
do {
    var engine = GridEngine(config: GameConfig.campaign(for: core), deck: .starter, seed: 7)
    for _ in 0..<60 where !engine.snapshot.isGameOver { _ = engine.tick(deltaTime: 0.2) }
    check(engine.snapshot.mistakes >= 1, "an expired daemon increments mistakes (got \(engine.snapshot.mistakes))")
}

print(failures == 0 ? "\n🎉 all star checks passed" : "\n💥 \(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
