# GRID_BREAKER — Balance Audit + Code Review

Reviewed at commit `3bd8dee` (2026-06-09). Method: full read of `Core/`, `UI/`, `Audio/`, `Persistence/` (~4,350 lines + 1,169 Core), plus a Python mirror of `GridEngine`/`GameConfig` run with the D10 player model (reaction 0.20–0.36 s, taps most-urgent harvestable, never bombs, 10% worm-dodge mistap), 5 seeds per condition, 60 fps ticks. Sim scripts: `gb_sim.py`, `gb_tune.py`.

---

## Part 1 — Balance audit

### B1 · HIGH — Endless has no skill ceiling

The brief targets 60–120 s sessions with "a real ceiling" (D10 measured good play dying ~168 s — but that was the *old* config). The `endless()` retune (calmer ramp, milestone RAM top-ups, streak multiplier) removed the ceiling:

| Profile | Survival (5 seeds) | Score | Fever uptime |
|---|---|---|---|
| casual (0.36 s react) | 76–115 s, avg 95 s | ~338 | 23% |
| good (0.28 s) | **all hit the 1200 s sim cap** | ~8,578 | 31% |
| strong (0.20 s) | **all hit the 1200 s sim cap** | ~23,280 | 55% |

Two root causes, both at the difficulty *floor* (score ≥ ~600 where `minSpawnInterval`/`minNodeLifespan` bind):

1. **Refill outruns drain.** At the floor, a competent player decodes ~3+/s × 1.05 s refill ≈ 3.2 s/s of RAM vs a flat 1.0/s drain. Even 600+ expiries per run (good profile) don't dent it.
2. **Fever is self-sustaining.** Combo 8 is trivial on a dense board; fever removes all bombs → free clean chain → next fever. Strong play spends **55% of the run** in hazard-free ×2 gold mode — fever stops being a "moment" (ground truth Part 2.1, pillar 5).

**Levers tested** (sim, `gb_tune.py`): drain ramp with score, fever-threshold ramp per fever triggered, decode-refill decay with score.

| Tune | casual | good | strong |
|---|---|---|---|
| baseline | 95 s | ∞ | ∞ |
| T9: drain ×(1+0.0007·score) cap ×2.5, refill decay floor 75%, fever threshold +1/fever cap 12 | 83 s | ~3.3 min | ∞ |
| T8: drain cap ×2.6 steeper, refill floor 70%, fever ramp | 82 s | ~2 min | ~5.5 min |

Strong players are on a knife edge: their throughput at the spawn floor beats any drain ≤ ~×2.5, then a small step further collapses the skill gap (T6 in the script). Two defensible philosophies — pick one:

- **"Mastery = endless"** (recommend): ship T9-class numbers. Casual untouched, good gets a real 3–4 min ceiling, a genuinely strong player can still go on a legend run. Requires B2 + extending `milestoneScores` past 8000 (good players exhaust the list in ~20 min).
- **"Everyone dies"**: T8-class numbers — true ceiling for all, but the good-vs-casual gap narrows.

All three levers are one-line additions to `GameConfig` + 3 lines in `GridEngine` (drain multiplier in `tick`, threshold ramp in `checkFever`, refill factor in `decode`). Numbers above are starting points — the headless sim validates the *curve*, the feel pass on device picks the final values (Q3 precedent).

### B2 · HIGH — Economy explodes with unbounded runs

Full upgrade tree = **20,187 CR** (ram 6,989 + decodeSpeed 3,943 + shield 2,064 + feverCapacitor 3,239 + salvage 3,952). At baseline a good player banks ~8,600 CR in one capped run — the entire meta-progression collapses in ~2.5 sessions. With B1/T9 applied: good ≈ 1,300 CR per ~3 min run → ~15 runs to max, which restores a meaningful arc. No change needed beyond B1; just re-check this number after the retune.

### B3 · MED — Fever threshold ramp is worth it on its own

Independent of the ceiling question, `feverComboThreshold` ramping +1 per fever triggered (cap 12, reset per session) drops fever uptime from 31→16% (good) and 55→43% (strong) and barely touches casual (first fever still arrives at combo 8, ~6–9 s in — confirmed in sim). It restores "calm at rest, fierce on the moment."

### B4 · LOW — Daily challenge is the best credit farm

`recordDaily` pays full salvaged credits on every replay of the *same known seed* (replay reuses `fixedSeed`). Memorize the board, farm it. Consider full credits on the first daily run of the day, reduced (e.g. 25%) on replays — `dailyBestDay` already gives you the day key to gate on.

### B5 · LOW — Fever feels sparse after grid escalation

`feverActiveNodes = 4` is 4/9 cells pre-escalation but 4/16 on the 4×4 board. Scale with the grid (e.g. `gridSize == .fourByFour ? 7 : 4`) so late-game fever stays a gold flood.

### B6 · INFO — Campaign curve validated ✔

Starter deck, 5 seeds: casual clears cores 1–7 cleanly, 4/5 on core 8, walls at 9–10; good clears everything (4/5 on The Monolith); strong full-clears. That matches the documented intent ("casual ~core 7, good ~9–10, strong finishes") exactly. First fever 6.1–8.8 s across seeds (target ~5 s — close). Spawn-burst events (see C1) occurred 0–2 times per run — statistically negligible.

---

## Part 2 — Code review & hardening

### C1 · MED — Spawn accumulator can dump a burst

`GridEngine.tick` step 3: `timeSinceLastSpawn` keeps accumulating while the board is at `target` (or full), and is only decremented per spawn. After a long saturated stretch, freeing cells releases several spawns in one tick (nodes popping in simultaneously). Sim shows it's rare in practice, but it's latent — one line fixes it:

```swift
// after the spawn while-loop:
timeSinceLastSpawn = min(timeSinceLastSpawn, interval)
```

### C2 · LOW — `hitboxPadding` is dead config

`GameConfig.hitboxPadding = 1.20` is never read anywhere; the generous hitbox is actually implemented via the full-cell `contentShape` in `GridBoard`. Delete it (or wire it) — dead spec in the "single source of balance" file is the kind of drift the ground truth warns about. (Also the only `CGFloat` in Core — removing it makes Core import-clean for a future port.)

### C3 · LOW — `hasIslandOrNotch` walks UIKit scenes every body evaluation

`GameView.body` re-evaluates every frame during play (snapshot churn); each pass does the `connectedScenes` + `keyWindow` dance. Compute once into a `@State`/`static let` at appear.

### C4 · LOW — Countdown task outlives a quit

`startCountdown()`'s `Task` isn't stored or cancelled. Quitting mid-countdown (pause isn't reachable then, but `onExit` from game-over → replay → quit is) leaves the task running `unpause()` on a model that's leaving screen. Harmless today; store the task and cancel in `onDisappear` for hygiene.

### C5 · LOW — Audio arpeggio doesn't reset on fever start

`decodeRun` resets on miss/expiry/bomb, but when fever triggers the *engine* resets `combo` to 0 while `decodeRun` keeps climbing (clamped at the top step). During fever every decode plays the top note — possibly intended (fever = peak), but it diverges from the "mirrors the engine's combo" comment. One line in `case .feverStarted:` if you want the arpeggio to rebuild during fever.

### C6 · LOW — Music can stay silent if the last queued track is unreadable

`MusicPlayer.playCurrent`'s catch advances `index` and only retries `if index < queue.count` — failing on the final track leaves silence (self-heals on the next `resume()`). Wrap instead: `index += 1; playCurrent()` already handles the reshuffle at the top.

### C7 · LOW — Worm hop/tap race reads as player error

A tap committed to the worm's cell in the same frame it hops resolves as a full empty-cell miss: −1.5 s RAM + streak reset. With the streak multiplier now core to endless scoring, that's an expensive coin flip. Anti-frustration option in the brief's §10.7 spirit: in `handleTap`, treat a tap on a cell a worm vacated within the last ~80 ms as the worm hit (track `lastVacated: (cell, clock)` on hop).

### C8 · INFO — `process()` flavors juice from the previous snapshot

`GameViewModel.process` reads `snapshot.feverActive`/`comboThreshold` *before* the new snapshot is republished, so an event batch that starts fever flavors its own decode with pre-fever heat. One event of staleness, presentation-only — noting it so it doesn't surprise you later.

### C9 · INFO — Verified clean ✔

Checked and found correct: engine-only authority (no mechanics in any view; views forward raw taps and render snapshots), every flourish traced to a real `GameEvent`, single-payout discipline (`outcome == nil` guard + `isHighScore` checked *before* `insertScore`; campaign/daily/endless each pay in exactly one place), tolerant save decoding incl. the cosmetic-ID re-guarantees, reduced-motion gating on flash/particles/shake/hit-stop/countdown/boot, seeded determinism (one shared SplitMix64, UI randomness kept out of the engine), grid-escalation index remap math, dt clamp + pause re-anchoring (no time jumps), audio interruption self-heal with reentrancy guard, shield semantics matching its shop description.

---

## Suggested order of attack

1. B3 fever-threshold ramp (smallest change, pure win).
2. B1 drain ramp + refill decay at T9 numbers → re-run your headless sim → device feel pass.
3. Extend `milestoneScores` (e.g. continue ×2: 16,000, 32,000) and re-check B2 economy.
4. C1 one-liner, C2 deletion, C6 wrap fix — trivial batch.
5. C7 worm grace + B5 fever density — feel polish, test on device.
6. B4 daily-replay credits — only if you see farming in the wild.
