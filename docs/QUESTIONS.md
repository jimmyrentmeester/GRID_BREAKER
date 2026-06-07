# QUESTIONS — open items for the maintainer

Resolved questions move to `DECISIONS.md`.

## Resolved (Run #1)
- Stack? → iOS-first SwiftUI (D1).
- First-run scope? → scaffold + docs.
- Folder? → `~/GRID_BREAKER`.

## Open
- **Q1 — Modes:** Endless high-score only, or also the brief's "campaign" (target
  score per data core)? Assumption for now: build endless first, campaign later.
- **Q2 — Grid progression:** Start 3×3 and step up to 4×4 mid-session by score, or
  pick per session? Assumption: start 3×3, escalate.
- **Q3 — Difficulty tuning:** `GameConfig` defaults are first guesses (RAM 20 s,
  base lifespan 1.6 s, compression 0.0025). Needs playtest tuning at M1/M2.
- **Q4 — Audio sourcing:** Synth SFX/music programmatically (AVAudioEngine, like
  PeuterGames) or licensed loops? Affects M5.
- **Q5 — Haptics fidelity:** Core Haptics patterns vs. simple `UIImpactFeedback`?
  Core Haptics is richer but more code; default to impact generators first.
