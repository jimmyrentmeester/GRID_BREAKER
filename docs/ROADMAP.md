# ROADMAP — GRID_BREAKER

Milestones end with a running, watchable artifact (ground-truth Part 4.5). One
scoped slice per session.

## ✅ PROTOCOL mode — complete (Runs #88–95, merged 2026-06-20)
Branch `feature/protocol-mode` merged to main. All four phases built, verified, cleaned up.
See `docs/PROTOCOL_MODE.md`. **Pending: on-device feel pass + v1.2 App Store submission.**

Ramp numbers on main (tune in `GameConfig.protocolMode()` if play reveals issues):
- Objective gap: 5.5 s → 2.5 s floor (compression 0.010). At score 30 ≈ 4.1 s, 60 ≈ 3.0 s.
- Overrun cadence: 1.6 s → 0.75 s floor (compression 0.008). At score 50 ≈ 1.07 s.
- DAEMON SET size: always 2 at score 0; 2–3 at score 15; 2–4 at score 30.
- DMZ zone size: always 2 at score 0; 2–3 at score 20; 2–4 at score 40.

**Still to do (maintainer):**
1. On-device feel pass: play 2–3 PROTOCOL runs, confirm tap response / zone outline /
   overrun pulse / purge sting feel right. Tune balance numbers above if needed.
2. Bump version to v1.2 (`MARKETING_VERSION` in both project configs).
3. Archive from main → upload → submit in App Store Connect.

## ✅ M0 — Scaffold + docs (done)
- New repo, hand-authored Xcode project (iOS 17, portrait, dark).
- Core value types: `NodeType`, `GridNode`, `Cyberdeck`/`CyberdeckUpgrade`,
  `GameConfig`/`GridSize`. Engine stub with the M1 contract.
- Neon theme tokens + placeholder title screen. Builds + runs (screenshot verified).
- Vendored `GAME_GROUND_TRUTH.md` (binding) + the design brief PDF.

## ✅ M1 — Playable grid (the core loop, no juice yet) (done)
The vertical slice that proves the loop. **GridEngine is the authority.**
- `GridEngine` + `SeededRNG`: seeded spawn (position + type), per-frame
  `tick(deltaTime:)`, `handleTap(cellIndex:)`, expiry, RAM drain, score,
  exponential lifespan + spawn-cadence compression, active-node ceiling (§10.3).
- `SessionSnapshot` + `GameEvent` stream + `@MainActor @Observable` `GameViewModel`
  driven by `TimelineView(.animation)` (no UIKit display-link plumbing).
- Grid view (3×3), full-cell tap = generous hitbox; standard / armored (2-hit,
  breached state) / firewall bomb (explode-on-touch only). HUD: RAM bar + score.
  Game-over overlay (RECONNECT / JACK OUT). Title screen JACK IN → session.
- **Verified:** clean build; on-device grid + draining RAM bar + bomb sprite
  (screenshot); headless deterministic sim (seeds 42/1337/999999 run a full 60 s,
  bomb-tap → instant firewallHit, same-seed determinism confirmed).

## ✅ M2 — Game feel & juice (done)
All flourishes traced to a real `GameEvent` via `GameViewModel.process(_:)`:
- Hit-flash (white, ~2-frame) + neon particle burst on decode (cyan standard /
  gold armored); floating "+N" score pop. Breach/miss/shield/bomb each get a styled
  effect. `UI/Juice.swift`.
- Hit-stop (~80 ms) on armored kill, ~60 ms on bomb (engine advance frozen in VM).
- Screen-shake (`ShakeEffect` GeometryEffect) on firewall hit.
- Micro-haptics: light decode / medium+stop armored / rigid miss / soft breach /
  error notification on bomb+game-over.
- RAM bar ghost layer (slow trail behind fast live fill). Button press micro-dip.
- Reduced-motion gating (snaps off flash/particles/shake/hit-stop).
- **Verified:** clean build; on-device capture of an armored decode mid-burst
  (flash + gold particles + "+2", score=2, RAM refilled, bomb left untapped).
  Shake/hit-stop ride the same verified event pipeline.

## ✅ M3 — Fever Mode (done)
- Engine: combo tracking (decode +1, reset on miss/daemon-expiry), fever trigger at
  `feverComboThreshold` (8) → hazards vanish (bombs removed), golden-only dense
  spawns (`feverSpawnInterval`/`feverActiveNodes`), score ×`feverScoreMultiplier`
  (2), `feverDuration` (4 s) window then auto-end. New events `feverStarted`/
  `feverEnded`; snapshot exposes combo/threshold/feverActive/feverFraction/multiplier.
- UI: combo meter (COMBO n/8 → FEVER), HUD ×2 badge, gold `FeverAtmosphere` overlay,
  `FeverBanner` with shrinking window bar, golden bonus-node sprites, success haptic
  on fever start.
- **Verified:** clean build; headless sim (4 seeds: fever triggers 4×/45 s, each
  exactly 4.0 s, ends cleanly, ×2 lifts perfect-play score to ~130 vs ~87 baseline);
  on-device capture of full fever state (banner, ×2, gold atmosphere, gold nodes,
  score burst). No-bombs-during-fever enforced in `spawnNode`.

## ✅ Balance pass (done, between M3 and M4)
Data-driven retune of `GameConfig` (spawn cadence, node count, lifespan, RAM
economy) via the headless realistic-player sim. Fixed the sparse early game: first
fever ~5 s, lively board, ~1–2 min sessions with a skill ceiling. See D10 / Q3.

## ✅ M4 — Meta progression (done)
- `GameStore` (@Observable): authority for meta-state, persists JSON to UserDefaults.
  Credits paid once on game-over (`credits(forScore:)`), leaderboard (top 5),
  `purchase()` spends credits with deterministic geometric cost scaling.
- `SaveData`/`HighScoreEntry` with **tolerant decoding** (custom `init(from:)` +
  body `CodingKeys` → missing fields fall back to defaults; old saves survive).
- Upgrades applied to sessions: RAM capacity (ramLevel), shield charges
  (shieldLevel), extra decode time (decodeSpeedLevel → `decodeTimeBonus`).
- UI: menu hub (JACK IN / CYBERDECK / TOP RUNS + BEST), `CyberdeckView` (level pips,
  affordable/maxed buy buttons), `HighScoresView`, game-over screen shows credits
  earned + NEW HIGH SCORE.
- **Verified:** clean build; headless (economy, leaderboard cap, Codable round-trip,
  back-compat decode of an old partial save); on-device (Cyberdeck 800 CR + scores
  persisted across relaunch; game-over "+1 CR" / NEW HIGH SCORE). Temp seed/demo
  reverted.

## ✅ M5 — Audio & polish (done)
- `AudioEngine` (AVAudioEngine, asset-free synth): sharp analog SFX rendered into
  PCM buffers — decode discharge, heavier armored decode, breach tick, miss glitch,
  firewall detonation, fever sting, game-over descent, UI blip; played via a
  6-node pool so rapid hits overlap. Driving darksynth loop (~130 BPM, A-minor saw
  bass + sub + sparse arp), looped. `.ambient` session (respects silent switch).
- All SFX traced to the same `GameEvent` stream in `process(_:)` (alongside haptics).
- Persisted SOUND ON/OFF toggle (SaveData.soundEnabled, menu button); UI blips.
- Generated neon app icon (CoreGraphics 1024² — 2×2 grid, one glowing target node).
- **Verified:** clean build; engine starts on-device (`run=Y`) with non-silent
  buffers (decode/bomb/music peaks 0.42/0.59/0.19) via temp diagnostic (reverted);
  menu shows the SOUND toggle. NOTE: actual speaker output needs a human listen on
  a real device — simulator audio can't be captured via CLI.

## ✅ Vertical slice — Definition of Done
The brief's first-slice DoD is met (sans the planned web high-score backend, which
is out of hobby scope): one playable grid, 3 daemon types with distinct behavior,
HUD, fever, Credits→Cyberdeck upgrade loop, local high scores, full juice + audio.

## ✅ Campaign mode (done, post-slice)
10 hand-tuned **time-attack** data cores (reach target score before the RAM
countdown empties — decodes don't refill in campaign; the Decode-Speed upgrade is
the only refill). Difficulty scales via per-core `difficultyBias` (faster pace) +
rising targets, sim-tuned so early cores clear on a starter deck and late ones
need skill/upgrades. Shared economy (cores pay Credits; upgrades apply). Level
select with lock/clear states, in-session target HUD, CORE CRACKED / INTRUSION
FAILED screens, persisted progress. See D13.

## ✅ Balance audit + hardening (post-release-prep) (2026-06-11)
Full-codebase review + headless sim audit (D23, Run #69). Endless gains a real
late-game ceiling (drain ramp, refill decay, fever-threshold ramp — campaign/Flow
untouched), fever stays dense on the 4×4 grid, worm hop/tap races resolve in the
player's favor, plus small hardening fixes (spawn-debt clamp, dead config removed,
cached notch check, cancellable countdown, music-queue wrap). **Pending: Xcode
build + on-device feel pass of the new endless curve (Q7).**

## 🔶 Game Center — global boards + achievements (built, verification pending)
Report-only GameKit layer (`Services/GameCenterService.swift`, Run #75): optional
auth, endless + daily leaderboards (replaces the out-of-scope web backend),
13 achievements fired from the verified `GameEvent` stream + idempotent meta sync,
`GKAccessPoint` on the menu hub only. Engine authority untouched; Flow exempt.
**Pending (Q8):** Xcode build, App Store Connect Game Center config (IDs in the
service file), on-device pass (auth sheet, access-point placement, banners).

## 🔶 Backlog — iPad layout doesn't use the screen (blocks v1.1-with-iPad)
The universal build works on iPad, but the `playColumn` approach just **centers a
phone-width column (360–480pt)** on the big screen, leaving lots of black space — the
chrome screens and the play field both read as "empty" on a 13" iPad. The App Store
screenshots (`docs/screenshots/ipad-13/`) show this. **Must be fixed before submitting a
v1.1 with iPad enabled** (ASC requires iPad screenshots for a universal build, and these
aren't good enough). Options to explore: scale content up on the regular size-class, a
richer/2-column iPad layout, or a larger play field — not just a centered phone column. No
live impact until a universal build + iPad screenshots are actually submitted (v1.0 stays live).

## 🔶 RAM-as-environment: screen-edge containment frame (built on branch, feel pass pending)
Branch `feature/ram-background` (Runs #96–97). The RAM clock can now also render as a draining
screen-edge "containment frame": the perimeter is lit at full RAM and burns down as the clock drains
(colour cyan→gold→red), re-lighting a segment on each decode and pulsing red at critical. Optional via
SETTINGS ▸ DISPLAY ▸ "RAM BACKGROUND" (default on); the slim top bar stays as the precise readout.
Solves the "hard to track RAM while watching the grid" feedback (peripheral-vision best practice), and
is more on-theme than the first attempt (a draining "waterline", #96, which read battery/tank — pivoted
in #97). **Pending (maintainer):** on-device feel pass; tune line weight / inset / corner radius, then
decide default + ship version. Not merged to main (v1.2 is in review).

## Monetization (planned — see docs/MONETIZATION.md)
Free, **no ads**, no pay-to-win ever. Phase 0: ship free. Phase 1: in-fiction tip
jar (consumable IAPs; Small Business Program first). Phase 2: cosmetic theme packs
(non-consumable, render-layer only). Build only after release traction.

## Later (out of current scope)
Android (Skip or CMP rewrite), web-WASM demo + backend proxy for high-score sync.
Optional balance follow-ups from the audit: reduced credits on daily-challenge
replays (B4 — only if seed-farming shows up in the wild). Revisit only if the
project graduates from hobby scope.
