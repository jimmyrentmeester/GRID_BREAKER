# GRID_BREAKER — project hub (CLAUDE.md)

This is the always-on hub doc. Read this + the relevant `docs/*` file + the files
in play. Read narrowly; context is scarce.

## What this is
A reflex-driven **neon-cyberpunk whack-a-mole** for iOS. The player is an elite
netrunner cracking megacorp data cores under time pressure: tap valid *daemon*
nodes on a glowing grid to harvest data and top up a draining **RAM time buffer**,
while never touching **firewall bombs**. Clean combos trigger **Fever Mode**;
earned **Credits** buy permanent **Cyberdeck** upgrades. No AI/LLM — purely
deterministic client logic (brief §10.4). Full design: `docs/GRID_BREAKER_Brief.pdf`.

## Binding rules
`GAME_GROUND_TRUTH.md` (repo root) is the constitution — Parts 0–7 are universal
and **binding**; Part 8 (AI) is **voided** for this project (no LLM); Part 9 is a
reference blueprint. When a rule there conflicts with a quick hack, the rule wins.

Highest-leverage rules for this game:
- **Authority = the local engine** (Part 1.1). The view never computes score, RAM,
  spawns or hit-resolution — it renders a snapshot and forwards raw taps. Hits must
  register with zero network latency (brief §10.3).
- **Deterministic core, procedural spawns** (brief §10.3). Mechanics (lifespan, hit
  cost, payouts, upgrade scaling) are hardcoded in `GameConfig`/`Cyberdeck`; only
  spawn *position & type* are procedural via a **seeded** PRNG (→ replayable QA).
- **Juice is traced to real events** (Part 2.5). Every hit-flash, hit-pause,
  screen-shake and haptic fires from an engine event, never guessed in the view.
- **Spec is reusable, code is not** (Part 0). Keep balance numbers and rules in the
  `Core/` value types so a later Android/Skip or CMP port reuses the spec.

## Reality / scope (overrides the brief's framing)
Solo hobby project, ~€0 budget. The brief's €5k/sprint, €25k cap, 2-person team,
ads/IAP and backend-proxy are **aspirational padding** — ignore unless explicitly
revisited. iOS-first SwiftUI (chosen over the brief's Compose Multiplatform to match
the maintainer's Swift skillset); Android/web are out of scope for now.

## Structure
```
App/GRID_BREAKER.xcodeproj      hand-authored pbxproj (objectVersion 56, GB… ids)
App/GRID_BREAKER/
  GridBreakerApp.swift          @main entry
  Core/                         shared, platform-agnostic spec (reusable)
    Models/  NodeType, GridNode, Cyberdeck, GameConfig
    Engine/  GridEngine (stub → M1: tick/spawn/resolve, the authority)
  UI/                           SwiftUI shell (not reusable)
    NeonTheme.swift             neon design tokens (explicit colors, contrast-safe)
    RootView.swift              M0 placeholder title screen
  Assets.xcassets
docs/                           ROADMAP, LOG, DECISIONS, CONCEPTS, QUESTIONS, UPDATES
scripts/                        run_now.sh (manual session trigger) + next_task.md
GAME_GROUND_TRUTH.md            the binding constitution (vendored)
```

## Build & run
```
xcodebuild -project App/GRID_BREAKER.xcodeproj -scheme GRID_BREAKER \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```
Then `simctl install`/`launch` `nl.gridbreaker.app`. Verify visually — "builds green"
proves nothing about layout/feel/gestures (Part 0). Dev team `A652HSR4S9`.

## Conventions
- Group by feature; pure models in `Core/Models`, deterministic logic in `Core/Engine`.
- Commits: imperative, type-prefixed (`Feature (engine): …`, `Fix (ui): …`). Never
  `Run #N:` prefixes; `docs/LOG.md` is the sole record of completed runs.
- One scoped vertical slice per session; end each with something you can watch run.
- Update `docs/LOG.md` + `docs/ROADMAP.md` (+ relevant doc) before committing.

## Doc map
- `docs/ROADMAP.md` — milestones (M0…Mn), what's next.
- `docs/LOG.md` — append-only record of completed runs.
- `docs/DECISIONS.md` — design/tech decisions + rationale.
- `docs/CONCEPTS.md` — game-design vocabulary & mechanics reference.
- `docs/QUESTIONS.md` — open questions for the maintainer.
- `docs/UPDATES.md` — short changelog for the player/maintainer.
