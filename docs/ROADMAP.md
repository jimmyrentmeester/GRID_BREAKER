# ROADMAP — GRID_BREAKER

Milestones end with a running, watchable artifact (ground-truth Part 4.5). One
scoped slice per session.

## ✅ M0 — Scaffold + docs (done)
- New repo, hand-authored Xcode project (iOS 17, portrait, dark).
- Core value types: `NodeType`, `GridNode`, `Cyberdeck`/`CyberdeckUpgrade`,
  `GameConfig`/`GridSize`. Engine stub with the M1 contract.
- Neon theme tokens + placeholder title screen. Builds + runs (screenshot verified).
- Vendored `GAME_GROUND_TRUTH.md` (binding) + the design brief PDF.

## 🚧 M1 — Playable grid (the core loop, no juice yet)
The vertical slice that proves the loop. **GridEngine becomes the authority.**
- `GridEngine`: seeded spawn (position + type), per-frame `tick(deltaTime:)`,
  `handleTap(cellIndex:)`, expiry, RAM drain, score, exponential lifespan
  compression + active-node scaling (brief §10.3).
- `SessionSnapshot` + a `@MainActor @Observable` view-model driving the view.
- Grid view (3×3 → 4×4), tappable nodes with 1.2× hitbox padding; standard /
  armored (2-hit, breached state) / firewall bomb (explode-on-touch only).
- HUD: RAM buffer bar, score. Instant-death on bomb tap / RAM depletion.
- Verify: 60 fps feel, tap latency, screenshot.

## 📋 M2 — Game feel & juice
hit-flash (2 frames) · hit-pause (~16 ms on armored kill) · screen-shake on bomb ·
micro-haptics (light hit / heavy error) · neon particle burst on decode · RAM-bar
ghost layer. Each flourish traced to a `GameEvent` (Part 2.5). Respect reduced-motion.

## 📋 M3 — Fever Mode
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
