# ROADMAP — GRID_BREAKER

Milestones end with a running, watchable artifact (ground-truth Part 4.5). One
scoped slice per session.

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

## 🚧 M3 — Fever Mode
combo tracking → fever trigger (hazards vanish, golden bonus nodes, score ×2),
shrinking display window, distinct audio/visual state.

## 📋 M4 — Meta progression
Credits payout on session end → upgrade screen (RAM / decode speed / shield),
deterministic cost scaling, back-compat persistence, local high-score leaderboard.

## 📋 M5 — Audio & polish
Synthwave/darksynth loop (120–150 BPM), sharp analog SFX (decode discharge, glitch
on error), boot/terminal transitions, app icon.

## Later (out of current scope)
Android (Skip or CMP rewrite), web-WASM demo + backend proxy for high-score sync,
cosmetics. Revisit only if the project graduates from hobby scope.
