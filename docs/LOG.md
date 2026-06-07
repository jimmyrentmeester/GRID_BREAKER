# LOG — GRID_BREAKER

Append-only record of completed runs (newest first). This file — not commit
prefixes — is the sole record of what's done.

## Run #5 — Balance pass (2026-06-07)
- `Core/Models/GameConfig.swift` only (no logic change): retuned spawn cadence,
  node count, lifespan and RAM economy to fix the sparse early game (Q3). See D10
  for the exact before→after numbers.
- Method: deterministic headless sim with realistic-player models (reaction
  0.20/0.27/0.36 s) over 5 seeds × 180 s; iterated on avgNodes, first-fever time,
  session length and skill ceiling (ground-truth Part 5.3).
- **Verified:** clean build; sim shows first fever ~5 s, board density 1.8–2.4 for
  normal play, casual ~78 s, good play dies ~168 s (ceiling), within 60–120 s target.
  On-device launch confirms HUD/board render with the new config.
- Q3 resolved. Next: M4 — meta progression.

## Run #4 — M3 Fever Mode (2026-06-07)
- `Core/Engine/GridEngine.swift`: combo state + fever (trigger at threshold via
  `checkFever`, bomb-clear, gold-only dense spawn during fever, ×multiplier in
  `decode`, countdown+auto-end in `tick`, combo reset on miss/expiry). New events
  `feverStarted`/`feverEnded`; snapshot fields combo/comboThreshold/feverActive/
  feverFraction/scoreMultiplier + `comboProgress`.
- `Core/Models/GameConfig.swift`: `feverSpawnInterval`, `feverActiveNodes`.
- `UI/GameView.swift`: ComboMeter, HUD ×N badge, fever atmosphere+banner wired,
  gold node sprites during fever, fever events → success/soft haptics.
- `UI/Juice.swift`: `FeverAtmosphere`, `FeverBanner`, `Haptics.success()`.
- **Verified:** clean build (temp perfect-play demo added then reverted). Headless
  sim across 4 seeds: fever fires 4×/45 s, 4.0 s each, clean end, score ~130 (×2)
  vs ~87 baseline. On-device capture of full fever state (gold banner + ×2 + shrink
  bar + gold atmosphere + gold nodes + score burst to 261).
- Tuning note (Q3, reinforced): early-game spawn is sparse — combos take ~7 s to
  build at score 0; tighten base spawn/lifespan in a balance pass.
- Next: M4 — meta progression (Credits → Cyberdeck upgrades, persistence, high scores).

## Run #3 — M2 game feel & juice (2026-06-07)
- `UI/Juice.swift` (new): `Haptics` wrapper, `JuiceEffect` model, `EffectsLayer` +
  `EffectView` (hit-flash, neon particle burst, floating "+N"), `ShakeEffect`
  GeometryEffect, `TerminalButtonStyle` press-dip.
- `UI/GameView.swift`: `GameViewModel.process(_:)` translates each `GameEvent` →
  effect + haptic + hit-stop (`freezeRemaining`) + shake (`shakeTrigger`); exposes
  `effectSeq` + `drainEffects()`. GridBoard hosts EffectsLayer sharing cell
  geometry; RAM bar gains a ghost trail layer; shake applied to game content;
  reduced-motion wired from environment.
- Used skill `game-feel-and-juice` (every flourish traced to a real event; calm at
  rest; reduced-motion respected).
- **Verified:** clean build (temp demo/debug hooks added then fully reverted).
  On-device rapid capture caught an armored decode mid-burst — white flash, gold
  particle ring, floating "+2", score=2, RAM refilled, firewall bomb left untapped.
  Debug readout confirmed real tap→decode→score path (score climbed 0→1→2).
  Tuning note (Q3): early-game spawn cadence feels sparse — revisit in balancing.
- Next: M3 — Fever Mode (combo → hazards vanish, golden bonus nodes, score ×N).

## Run #2 — M1 playable grid engine (2026-06-07)
- `Core/Engine/GridEngine.swift`: rewrote stub → full deterministic authority.
  Added `SeededRNG` (SplitMix64), `SessionSnapshot`, `GameEvent`, `GameOverReason`.
  Spawn (seeded position+type), `tick(deltaTime:)` (RAM drain, expiry+penalty,
  cadence spawn up to score ceiling, RAM-depletion game-over), `handleTap`
  (decode/breach/miss/shield-absorb/bomb→instant death).
- `Core/Models/GameConfig.swift`: added spawn cadence + score-payout params and
  `spawnInterval`/`targetActiveNodes` helpers.
- `UI/GameView.swift` (new): `@Observable` `GameViewModel` driven by
  `TimelineView(.animation)`; grid board, node sprites, RAM HUD, game-over overlay,
  reusable `TerminalButton`. `UI/RootView.swift`: JACK IN → session, exit back.
- Project: added `GameView.swift` to pbxproj.
- **Verified:** `xcodebuild` BUILD SUCCEEDED; installed/launched on sim — grid +
  draining RAM bar + firewall-bomb sprite render (screenshot). Headless `swiftc`
  sim of pure Core: 3 seeds run a full 60 s with sane score/RAM; bomb-tap → instant
  `firewallHit`; same seed → identical sequence, different seed → different.
- Next: M2 — game feel & juice (hit-flash, hit-pause, screen-shake, haptics,
  particles, RAM-bar ghost). Events already exposed via `GameViewModel.lastEvents`.

## Run #1 — M0 scaffold + docs (2026-06-07)
- New project created at `~/GRID_BREAKER`, git initialized.
- Decisions with maintainer: **iOS-first SwiftUI** (over the brief's Compose
  Multiplatform), first run = **scaffold + docs**, folder `~/GRID_BREAKER`.
- Hand-authored Xcode project (objectVersion 56, `GB…` ids, iOS 17, portrait,
  dark, bundle `nl.gridbreaker.app`, team A652HSR4S9).
- Core value types: `NodeType`, `GridNode`, `Cyberdeck` + `CyberdeckUpgrade`,
  `GameConfig` + `GridSize`. `GridEngine` documented stub (M1 contract).
- `NeonTheme` design tokens + `RootView` placeholder title screen.
- Vendored `GAME_GROUND_TRUTH.md` (binding constitution) and the brief PDF
  (`docs/GRID_BREAKER_Brief.pdf`).
- **Verified:** `xcodebuild` BUILD SUCCEEDED; installed + launched on simulator;
  neon title screen renders (screenshot).
- Next: M1 — playable grid with the engine as authority (see ROADMAP).
