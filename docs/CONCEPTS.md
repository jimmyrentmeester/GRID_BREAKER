# CONCEPTS — GRID_BREAKER vocabulary & mechanics

The shared language for the design. Mirrors the brief (§10.2–10.3); the numbers
live in `Core/Models/GameConfig.swift`.

## Fantasy
An elite netrunner cracking megacorp data cores under time pressure — overloading
security daemons and bypassing firewalls before physical detection. Every
millisecond counts. Aesthetic: **Neon Cyberpunk Terminal** (jet-black field,
cyan/purple grid, magenta/cyan daemons).

## Core loop (~60–120 s sessions)
1. **Scan** the lighting 3×3 / 4×4 grid.
2. **Decode** — tap valid daemons (harvest data, top up RAM), avoid firewall bombs.
3. **Fever** — a clean combo streak triggers Fever Mode: hazards vanish, only golden
   bonus nodes spawn, score ×N, within a shrinking window.

## Entities (`NodeType`)
- **Standard Daemon** — 1 tap. +score, +RAM time.
- **Armored Daemon** — 2 taps; first tap *breaches* the shell (visual change), second
  eliminates. Bigger time bonus. Hit-pause on the kill (M2).
- **Firewall Bomb** — never tap. Explodes (instant death + screen-shake) only on
  active touch; natural expiry is safe.

## Resources
- **RAM time buffer** — central resource, drains continuously. Decodes add time;
  misses (empty-cell tap, expired daemon) subtract. Depletion = game over.
- **Credits** — earned per cracked core; spent on Cyberdeck upgrades.
- **Cyberdeck** — meta-progression: RAM Buffer, Decode Speed, Failsafe Shield
  (absorbs N erroneous taps). Deterministic cost/effect scaling.

## Difficulty model (brief §10.3)
- Node lifespan compresses exponentially with score:
  `lifespan = base · exp(−k · score)`, floored at `minNodeLifespan` (fairness).
- When score hits a multiple of 10, if active nodes < `score/10`, spawn another node
  with increased speed / higher pattern complexity.

## Win / loss
- **Win (campaign):** reach a target decode score within the time limit.
- **Loss (instant death):** RAM depleted, or an active firewall bomb is tapped.

## Touch tolerance
Hitbox = 1.2× the visual sprite (`GameConfig.hitboxPadding`) so near-misses at high
speed still register (brief §10.7 risk mitigation).
