# QUESTIONS — open items for the maintainer

Resolved questions move to `DECISIONS.md`.

## Resolved
- Stack? → iOS-first SwiftUI (D1). [Run #1]
- First-run scope? → scaffold + docs. [Run #1]
- Folder? → `~/GRID_BREAKER`. [Run #1]
- **Q3 — Difficulty tuning** → balance pass done (D10): denser/faster opening,
  first fever ~5 s, casual ~78 s, skill ceiling ~168 s. Numbers may still want a
  real-device feel check, but the curve is validated. [Run #5]

- **Q4 — Audio sourcing** → programmatic AVAudioEngine synth (asset-free), per the
  €0 ethos. [Run #7]
- **Q5 — Haptics fidelity** → `UIImpactFeedback`/`UINotificationFeedback` generators
  (not Core Haptics) — enough fidelity, far less code. [Run #2/M2]
- **Q2 — Grid progression** → start 3×3, escalate to 4×4 mid-session at a score
  threshold (endless only; campaign/Flow stay 3×3) — D19. [Run #28]

## Open
- **Q1 — Modes:** Endless high-score only, or also the brief's "campaign" (target
  score per data core)? Assumption for now: build endless first, campaign later.
- **Q2 — Grid progression:** Start 3×3 and step up to 4×4 mid-session by score, or
  pick per session? Assumption: start 3×3, escalate. (Engine already supports 4×4.)
- **Q6 — Real-device audio listen:** SFX/music verified at engine+buffer level only;
  confirm they sound right (and balanced vs. game) on a physical device.
