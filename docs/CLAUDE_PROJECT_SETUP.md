# Setting up GRID_BREAKER as a Claude Project

A "Project" lives in the Claude app sidebar (separate from the connected folder).
It holds custom instructions + a small knowledge base. This file has everything to paste.

## Steps (in the Claude desktop app)
1. Sidebar → **Projects** → **New project**.
2. Name: `GRID_BREAKER`. Description: `Neon-cyberpunk whack-a-mole for iOS (SwiftUI, solo).`
3. Open the project → **Set instructions** → paste the block below.
4. **Add to knowledge** → add the files listed under "Knowledge files".
5. (Optional) Connect the `GRID_BREAKER` folder so chats can read/write live code.

## Project instructions (paste into the instructions field)
---
GRID_BREAKER is a reflex-driven neon-cyberpunk whack-a-mole for iOS. Tap valid daemon
nodes on a glowing grid to harvest data and refill a draining RAM time buffer; never
touch firewall bombs. Clean combos trigger Fever Mode; Credits buy permanent Cyberdeck
upgrades. No AI/LLM — purely deterministic client logic.

Stack: iOS-first SwiftUI. Solo hobby project, ~€0 budget — the brief's team/budget/IAP
framing is aspirational padding; ignore unless explicitly revisited. Android/web out of scope.

Architecture rules (binding):
- Authority = the local engine. The view never computes score, RAM, spawns, or hit
  resolution — it renders a snapshot and forwards raw taps. Hits register with zero latency.
- Deterministic core, procedural spawns. Mechanics (lifespan, hit cost, payouts, upgrade
  scaling) are hardcoded in GameConfig/Cyberdeck; only spawn position & type are procedural
  via a seeded PRNG (replayable QA).
- Juice traces to real engine events — never guessed in the view.
- Spec is reusable, code is not. Keep balance numbers/rules in Core/ value types.

Structure: Core/ = shared platform-agnostic spec (Models, Engine/GridEngine the authority);
UI/ = SwiftUI shell + NeonTheme. GAME_GROUND_TRUTH.md is the constitution (Parts 0–7 binding,
Part 8/AI voided, Part 9 reference).

Conventions: group by feature; pure models in Core/Models, deterministic logic in Core/Engine.
Commits imperative + type-prefixed (e.g. `Feature (engine): …`, `Fix (ui): …`); never
`Run #N:` prefixes. One scoped vertical slice per session, ending in something watchable.
Update docs/LOG.md + docs/ROADMAP.md before committing. Verify visually — "builds green"
proves nothing about layout/feel/gestures.

Work with me in vibecode mode: opinionated sparring, name the trap, skip heavy PM rigor.
---

## Knowledge files (add these)
- CLAUDE.md — project hub
- GAME_GROUND_TRUTH.md — binding constitution
- docs/ROADMAP.md — milestones / what's next
- docs/DECISIONS.md — design & tech decisions + rationale
- docs/CONCEPTS.md — game-design vocabulary & mechanics
- docs/GRID_BREAKER_Brief.pdf — full design brief

Skip in knowledge (too volatile or large): docs/LOG.md, docs/UPDATES.md — let live
folder access cover those instead.
