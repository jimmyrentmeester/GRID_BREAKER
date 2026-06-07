# QUESTIONS — open items for the maintainer

Resolved questions move to `DECISIONS.md`.

## Resolved
- Stack? → iOS-first SwiftUI (D1). [Run #1]
- First-run scope? → scaffold + docs. [Run #1]
- Folder? → `~/GRID_BREAKER`. [Run #1]
- **Q3 — Difficulty tuning** → balance pass done (D10): denser/faster opening,
  first fever ~5 s, casual ~78 s, skill ceiling ~168 s. Numbers may still want a
  real-device feel check, but the curve is validated. [Run #5]

## Open
- **Q1 — Modes:** Endless high-score only, or also the brief's "campaign" (target
  score per data core)? Assumption for now: build endless first, campaign later.
- **Q2 — Grid progression:** Start 3×3 and step up to 4×4 mid-session by score, or
  pick per session? Assumption: start 3×3, escalate.
- **Q4 — Audio sourcing:** Synth SFX/music programmatically (AVAudioEngine, like
  PeuterGames) or licensed loops? Affects M5.
- **Q5 — Haptics fidelity:** Core Haptics patterns vs. simple `UIImpactFeedback`?
  Core Haptics is richer but more code; default to impact generators first.
