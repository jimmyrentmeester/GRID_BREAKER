# ROADMAP — GRID_BREAKER

Milestones end with a running, watchable artifact (ground-truth Part 4.5). One
scoped slice per session.

## ✅ v1.2 — LIVE on the App Store (2026-06-22)
Shipped: PROTOCOL mode (Runs #88–95, `docs/PROTOCOL_MODE.md`), the in-game Codex, iPad
full-screen scaling, and post-launch fixes. **Game Center is fully working in v1.2**
(leaderboards + the 13 achievements verified live). Universal iPhone + iPad build.

PROTOCOL ramp numbers on main (tune in `GameConfig.protocolMode()` if play reveals issues):
- Objective gap: 5.5 s → 2.5 s floor (compression 0.010). At score 30 ≈ 4.1 s, 60 ≈ 3.0 s.
- Overrun cadence: 1.6 s → 0.75 s floor (compression 0.008). At score 50 ≈ 1.07 s.
- DAEMON SET size: always 2 at score 0; 2–3 at score 15; 2–4 at score 30.
- DMZ zone size: always 2 at score 0; 2–3 at score 20; 2–4 at score 40.

## ▶ NEXT — Campaign 2.0 + growth (planning, 2026-06-24)
Two strategy docs drive the next phase:
- **`docs/CAMPAIGN_REDESIGN.md`** — chapters + slower mechanic pacing + PROTOCOL-as-boss +
  star/mastery objectives + retention features (the campaign feedback: "introduces new
  things too fast").
- **`docs/GROWTH_AND_INCOME.md`** — marketing plan (ASO, short-form video, daily-share
  hook, Apple featuring) + the cosmetic-only path to a real side income. Installs are
  dipping; this is the priority lever.

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
cached notch check, cancellable countdown, music-queue wrap). Shipped + live since v1.2.

## ✅ Game Center — global boards + achievements (LIVE in v1.2)
Report-only GameKit layer (`Services/GameCenterService.swift`, Run #75): optional auth,
endless + daily leaderboards, 13 achievements from the verified `GameEvent` stream.
**Configured in App Store Connect and verified working live in v1.2** (auth sheet,
access point, leaderboards, achievement banners).

## ✅ iPad layout — fixed in v1.2
The phone-width-column problem is resolved: the regular size class now scales content to
the full iPad canvas (GeometryReader + scaleEffect), and the App Store iPad screenshots
(`docs/screenshots/ipad-13/`) were re-shot full-screen. Universal build shipping in v1.2.

## ✅ RAM-as-environment: screen-edge containment frame (merged to main, Runs #96–100)
Optional RAM visualisation: a draining screen-edge "containment frame" that follows the
device's rounded corners — lit at full RAM, burns down by splitting at top-centre and
descending both sides to meet at the bottom at 0 (colour cyan→gold→red), re-lights a segment
on each decode, with an upward bottom glow (gold→red) from ~⅔ through the gold band and a red
pulse at critical. Toggle: SETTINGS ▸ DISPLAY ▸ "RAM BACKGROUND" (default on); the slim top
bar stays as the precise readout. Also fixed a score-block layout shift that could resize the
grid. **Pending (maintainer):** on-device feel pass + decide whether it stays default-on for
the next App Store version.

## 🔶 Android port — done (not published)
Skip (skip.tools) transpiled port at `~/GRID_BREAKER/GridBreakerSkip`, full parity within
Skip's limits (see `docs/ANDROID_PORT.md`): deterministic engine, all screens, audio +
haptics, Canvas-free tap-trails/particles. Signed release APK/AAB build. **Pending
(maintainer):** Play Store Developer account + listing + on-device audio listen before
publishing. Keystore is local + gitignored — back it up off-repo.

## Monetization (planned — see docs/MONETIZATION.md + docs/GROWTH_AND_INCOME.md)
Free, **no ads**, no pay-to-win ever. **Small Business Program: already enrolled** (15%
commission locked in before the first sale). Phase 1: in-fiction tip jar (consumable IAPs).
Phase 2: cosmetic theme packs (non-consumable, render-layer only). Build the store only
once installs/retention justify it — the growth plan comes first.

## Later (out of current scope)
Web-WASM demo + backend proxy for high-score sync. Optional balance follow-up: reduced
credits on daily-challenge replays (B4 — only if seed-farming shows up in the wild).
