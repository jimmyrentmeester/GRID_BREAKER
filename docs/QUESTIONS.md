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
- **Q1 — Modes** → all four shipped: Endless, Campaign (10 cores, granular intro
  D13/D21), Flow (D15), Daily challenge (D20). [Runs #7/#23/#33]

## Open
- **Q6 — Real-device audio listen:** SFX/music verified at engine+buffer level only;
  confirm they sound right (and balanced vs. game) on a physical device. Now covers
  the **new dark-cyberpunk SFX set (D24, Run #70)**: do the darker, lower hits still
  cut through the darksynth music in play (both live around A minor / the low-mids)?
  Preview WAVs from the prototyping session approximate the in-game sound.
- **Q7 — Endless late-game feel pass (D23, Run #69):** the new pressure curve
  (drain ramp, refill decay, fever threshold 8→12) is sim-validated but needs a
  human run on device: does a good ~3-minute run die in a way that feels *earned*
  (creeping tension) rather than sudden? Watch the RAM bar around score 500–1500.
  Also build-verify Run #69 — the sandbox couldn't run xcodebuild/sim this session.
