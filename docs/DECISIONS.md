# DECISIONS — GRID_BREAKER

Design & tech decisions with rationale. Append new ones; don't rewrite history.

## D1 — Stack: iOS-first SwiftUI (not Compose Multiplatform)
**2026-06-07.** The brief recommends Compose Multiplatform (Kotlin). Overridden in
favor of native SwiftUI because the maintainer's skillset and other projects are
Swift, the budget is €0/solo, and CMP would mean learning a new language+toolchain.
Cross-platform stays possible later (Skip keeps Swift; CMP would be a rewrite) — the
`Core/` spec is kept platform-agnostic so a port reuses it (ground-truth Part 0/4).

## D2 — Brief's commercial framing treated as aspirational
**2026-06-07.** €5k/sprint, €25k cap, 2-person team, ads/IAP, marketing web demo,
backend proxy = AI-generated padding in the brief. Build at real hobby scale; revisit
only on explicit request.

## D3 — Authority is the local client engine
Per brief §10.3 and ground-truth Part 1.1: reflex gameplay can't tolerate network
latency on hit registration, so the device engine is the single source of truth. No
server in the gameplay loop. (A future web build would add a proxy only for high-score
sync — out of scope now.)

## D4 — Deterministic mechanics, seeded-procedural spawns
Mechanical properties + upgrade scaling are hardcoded for fairness/repeatability;
spawn position & type use a difficulty-seeded PRNG (brief §10.3). A seed → identical
replay, which enables free deterministic QA later (ground-truth Part 5.1).

## D5 — Firewall bombs explode only on touch
Natural expiry is always safe (brief §10.3 anti-frustration rule). Encoded in
`NodeType.firewallBomb` (requiredTaps 0, not harvestable).

## D7 — Frame loop via TimelineView(.animation), not CADisplayLink
**2026-06-07 (M1).** The engine is advanced once per frame from
`TimelineView(.animation)`'s date via `onChange` (runs outside the render pass, so
no "modifying state during update"). Chosen over a `CADisplayLink`/NSObject driver
to avoid UIKit plumbing and keep the loop pure-SwiftUI. dt is clamped to ≤1/20 s so
a stall can't teleport the simulation. Revisit only if frame pacing proves jittery.

## D8 — Generous hitbox = whole cell tappable
**2026-06-07 (M1).** Instead of a 1.2× sprite-sized hitbox, the entire grid cell is
the tap target and the sprite is drawn inset (~0.7×). Same effect as brief §10.7
(forgiving touch) with simpler, drift-free hit-testing. `GameConfig.hitboxPadding`
is retained for any future precise hit-testing.

## D9 — Juice fed only from engine events, queued via effectSeq
**2026-06-07 (M2).** All visual/haptic feedback is produced in
`GameViewModel.process(_:)` from the engine's `GameEvent` stream — never guessed in
the view (skill §5 / Part 2.5). Effects are queued and the overlay drains them on an
`effectSeq` counter change (avoids unbounded array growth and view/VM write races).
Hit-stop lives in the VM (it owns the frame loop); particles/flash/shake are pure
view. Reduced-motion snaps the motion-heavy parts off.

## D10 — Balance pass (data-driven via headless sim)
**2026-06-07.** Fixed the sparse early game (Q3) using the deterministic headless
sim with realistic-player models (reaction 0.20–0.36 s, taps most-urgent harvestable,
never bombs) over 5 seeds × 180 s (ground-truth Part 5.3). Changes in `GameConfig`:
- Spawn cadence: `baseSpawnInterval` 0.85→0.50, `minSpawnInterval` 0.30→0.20,
  `spawnCompression` 0.0035→0.0045.
- Node count: `targetActiveNodes` start 1→**2** (`max(2, min(cells-1, 2 + score/8))`).
- Lifespan: `baseNodeLifespan` 1.6→1.35, `minNodeLifespan` 0.45→0.50,
  `lifespanCompression` 0.0025→0.0030.
- Economy (skill ceiling): `bonusStandardDecode` 1.2→1.05, `bonusArmoredDecode`
  2.0→1.8.

Result: first fever ~5 s (was never reachable in casual screenshots), board density
avgNodes 1.8–2.4 for normal play (was 0.5–1.2), casual session ~78 s and good play
dies ~168 s (a real ceiling), within the brief's 60–120 s target. A perfectly
metronomic 0.20 s player still survives — acceptable (no human sustains that).

## D6 — Hand-authored pbxproj
Mirrors the maintainer's PeuterGames convention (explicit file refs, `GB…` hex ids,
objectVersion 56) rather than file-system-synchronized groups, for predictable diffs.
