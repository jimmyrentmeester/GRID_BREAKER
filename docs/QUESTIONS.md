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
- **Q6 — Real-device audio listen** → done by the maintainer (2026-06-11), covering
  the dark-cyberpunk SFX set (D24), the mix vs. the darksynth music, volume sliders
  and the purchase chime. Approved.
- **Q7 — Endless late-game feel pass** → done by the maintainer (2026-06-11): the
  D23 pressure curve plays well on device; Run #69–72 build-verified. Approved.

## Open
- **Q9 — No open engineering task on ROADMAP.md (2026-09-09).** Resume-check found a
  clean-ish tree (only a stray untracked `CLAUDE.md.bak`, harmless — pre-edit copy of
  `CLAUDE.md` from the memory-file split, not project code) and every ROADMAP milestone
  through Cosmetics 2.0 marked ✅. The only remaining items are maintainer-only and
  money/account-gated: (1) on-device feel pass for Campaign 2.0 + Cosmetics 2.0 before
  the next store version, (2) Android Play Store account + listing to publish the
  already-built port, (3) Monetization Phase 1 (tip jar) — blocked on the DSA
  virtual-office address decision. Per memory, v1.3.1 ASO metadata was submitted
  2026-08-07; the impressions measurement (vs. baseline 883/146/34) is due around now.
  Nothing to build until one of these gets a maintainer decision — flagging instead of
  inventing a task.
- **Q8 — Game Center verification pass (Run #75).** Needs the maintainer's Mac +
  device: (1) Xcode build of the new `GameCenterService` + entitlement; (2) App
  Store Connect → Game Center: create 2 leaderboards + 13 achievements with the
  exact IDs listed in `Services/GameCenterService.swift` (daily board = recurring,
  daily reset); (3) on-device: auth sheet on first launch, `GKAccessPoint`
  placement vs the menu's top-trailing area (move to `.topLeading` if it crowds
  the stat chips), achievement banner timing during play, declined-auth path
  (game must behave identically).
