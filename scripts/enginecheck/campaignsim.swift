import Foundation

// Multi-skill headless campaign player-sim. Runs each of the 16 campaign cores with a
// reaction-time bot at three skill levels (strong/good/casual) on a starter deck, over
// several seeds, and reports cores cleared + win margins — validating the gentler 16-core
// curve (one new mechanic per chapter, sawtooth difficulty). Deterministic core, no sim.
//
//   scripts/enginecheck/run.sh campaignsim
//
// The bot taps only valid targets (never a firewall), gated by a per-skill reaction delay
// (it can act on a node only after it's been on screen `reaction` seconds) and a tap
// interval (min time between taps = tap speed). Falling behind → daemons expire → RAM
// drains + the clean-streak breaks, exactly the pressure the curve is meant to scale.

struct Skill { let name: String; let reaction: Double; let tap: Double }
let skills = [
    Skill(name: "STRONG", reaction: 0.16, tap: 0.11),
    Skill(name: "GOOD",   reaction: 0.26, tap: 0.16),
    Skill(name: "CASUAL", reaction: 0.40, tap: 0.24),
]
let seeds: [UInt64] = [1001, 2002, 3003, 4004, 5005, 6006]
let dt = 0.025

/// Pick the cell the bot taps this instant (nil = wait), given the board + skill reaction.
func chooseTarget(_ snap: SessionSnapshot, clock: Double, reaction: Double) -> Int? {
    let nodes = snap.nodes
    func reactable(_ n: GridNode) -> Bool { clock - n.spawnedAt >= reaction }
    // (a) DMZ PURGE active → clear intrusions inside the zone before the overrun fills the grid.
    if !snap.dmzZone.isEmpty {
        if let n = nodes.first(where: { $0.type == .intrusion && snap.dmzZone.contains($0.cellIndex) && reactable($0) }) {
            return n.cellIndex
        }
        return nil
    }
    // (b) DAEMON SET active → tap the required (lowest-order) node, in order, when reactable.
    let setNodes = nodes.filter { $0.setOrder != nil }
    if !setNodes.isEmpty {
        let lowest = setNodes.min { ($0.setOrder ?? 99) < ($1.setOrder ?? 99) }!
        return reactable(lowest) ? lowest.cellIndex : nil
    }
    // (c) Otherwise decode the most urgent (soonest-expiring) reactable daemon. Never a firewall.
    let targets = nodes.filter { reactable($0) && $0.type != .firewallBomb && $0.type != .intrusion }
    return targets.min(by: { $0.expiresAt < $1.expiresAt })?.cellIndex
}

/// Play one core once. Returns (won, score, ramRemaining at end, mistakes).
func play(core: DataCore, seed: UInt64, skill: Skill) -> (won: Bool, score: Int, spare: Double, mistakes: Int) {
    var engine = GridEngine(config: .campaign(for: core), deck: .starter, seed: seed,
                            targetScore: core.targetScore, difficultyBias: core.difficultyBias)
    var lastTap = -10.0
    var iter = 0
    while !engine.isGameOver && iter < 6000 {
        iter += 1
        _ = engine.tick(deltaTime: dt)
        if engine.isGameOver { break }
        let snap = engine.snapshot
        let clock = snap.elapsed
        if clock - lastTap >= skill.tap, let t = chooseTarget(snap, clock: clock, reaction: skill.reaction) {
            _ = engine.handleTap(cellIndex: t)
            lastTap = clock
        }
    }
    let s = engine.snapshot
    return (s.gameOverReason == .coreCracked, s.score, max(0, s.ramRemaining), s.mistakes)
}

// MARK: run
var failures = 0
func assert(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg); if !cond { failures += 1 }
}

print("=== CAMPAIGN PLAYER SIM · starter deck · \(seeds.count) seeds/core ===\n")
var wallBySkill: [String: Int] = [:]      // first core with <⅔ clear; cleared-through = wall-1

for skill in skills {
    print("\(skill.name)  (reaction \(skill.reaction)s · tap \(skill.tap)s)")
    var wall = Campaign.count + 1
    for core in Campaign.cores {
        var wins = 0, scoreSum = 0; var spareSum = 0.0
        for seed in seeds {
            let r = play(core: core, seed: seed, skill: skill)
            if r.won { wins += 1; scoreSum += r.score; spareSum += r.spare }
        }
        let rate = "\(wins)/\(seeds.count)"
        let avgScore = wins > 0 ? scoreSum / wins : 0
        let avgSpare = wins > 0 ? Int((spareSum / Double(wins)).rounded()) : 0
        let mark = wins >= 4 ? " " : "✗"
        let boss = core.isBoss ? "★" : " "
        let detail = wins > 0 ? "score \(avgScore)/\(core.targetScore)  spare \(avgSpare)s" : "—"
        func pad(_ s: String, _ w: Int) -> String { s.count >= w ? s : s + String(repeating: " ", count: w - s.count) }
        print(" ch\(core.chapter) C\(pad("\(core.id)", 2)) \(boss) \(pad(core.name, 20)) \(pad(rate, 4)) \(mark)  \(detail)")
        if wins < 4 && wall > Campaign.count { wall = core.id }
    }
    wallBySkill[skill.name] = wall
    let cleared = min(wall - 1, Campaign.count)
    print(" → clears through core \(cleared)\(cleared >= Campaign.count ? " (ALL)" : "")\n")
}

// MARK: design-intent assertions
let cw = wallBySkill["CASUAL"]!, gw = wallBySkill["GOOD"]!, sw = wallBySkill["STRONG"]!
print("SUMMARY  casual→core \(min(cw-1,Campaign.count)) · good→core \(min(gw-1,Campaign.count)) · strong→core \(min(sw-1,Campaign.count))\n")
assert(sw > Campaign.count, "a STRONG player clears all \(Campaign.count) cores")
assert(cw - 1 >= 3, "a CASUAL player clears at least chapter 1 (cores 1–3), got \(cw-1)")
assert(cw <= gw && gw <= sw, "difficulty is monotone (casual ≤ good ≤ strong walls: \(cw) ≤ \(gw) ≤ \(sw))")

print(failures == 0 ? "\n🎉 campaign curve validated" : "\n💥 \(failures) curve issue(s) — retune Campaign.cores")
exit(failures == 0 ? 0 : 1)
