# ONBOARDING PROPOSAL — GRID_BREAKER first-time experience

Status: **proposed** (awaiting go-ahead to implement). Authored from FTUE best
practices + the maintainer's brief. Decisions below are locked (maintainer-chosen).

## Goal
Turn the cold start into a paced, hands-on first-time experience that teaches the
core mechanics AND the earn → spend → customize loop that drives retention — without
trapping the player before real play.

## Principles (game FTUE best practice)
- Teach by doing, minimal text; one mechanic at a time; just-in-time over front-loading.
- Safe, no-fail, slow while learning. Hands on controls within seconds.
- Always skippable; revisitable later (already supported from Settings).
- Show the *loop*, not just mechanics — the meta-loop is the retention hook.
- Reward must be tangible and feel earned (a guided first purchase beats an empty tour).
- Don't trap the player: long forced onboarding before real play is the #1 drop-off cause.

## Locked decisions (maintainer)
1. **Loop timing = Hybrid.** Teach the 3 practice levels + CR reveal on first launch,
   then a short skippable pointer; surface the full Cyberdeck/Cosmetics tour again right
   after the player's first real run, when CR feels earned.
2. **Tangible = grant CR + guided first buy/equip.** Award ~150 starter CR on finishing
   practice; guide one real Cyberdeck purchase and one cosmetic equip.
3. **Vs. Campaign = practice teaches fundamentals; Campaign reinforces.** The 3 levels
   cover basics; Campaign's existing per-core briefings keep reinforcing deeper mechanics
   in real challenge (spaced repetition is intentional).

## The flow

### Act 1 — Learn the game (first launch): 3 slow, no-fail practice levels
Progress dots across the 3 levels; SKIP always available; calm pace; no real fail state.
- **L1 · First Contact (the loop):** tap cyan daemons to decode; decoding refills the
  **RAM clock** (drains constantly; empty = disconnect); **red firewall = never tap.**
- **L2 · Read the Grid (special targets):** **armored** (2 taps), **data cache** (gold,
  fast, big bonus), **worm** (green, hops — tap where it lands).
- **L3 · Overload (building power):** chain clean decodes into **Fever** (hazards clear,
  ×2); grab a **power-up** (Freeze / Overclock / Purge); note that score grows the grid
  3×3 → 4×4.

### Act 1.5 — Payday (first launch, immediately after L3)
- "Every run banks CR." Grant ~150 **starter CR** with a satisfying count-up + the
  existing purchase chime. Short skippable pointer: "Spend it in the Cyberdeck →".
- Then drop to the menu so the player can do a **real run** with what they learned.

### Act 2 — The meta-loop (after the player's FIRST real run)
Surfaced from the game-over screen (one-time), so CR is earned and motivated:
- **Cyberdeck:** explain RAM buffer / decode speed / failsafe shield; **guide one real
  first purchase** (RAM buffer is the natural pick).
- **Cosmetics:** palettes recolor the whole game, trail skins; **have them equip one**
  (instant visual payoff = the closer).
- **"You're jacked in":** return to menu, gently pointing at JACK IN / Campaign.

## UX details
- **Skippable & revisitable:** SKIP at every step; the practice levels stay available
  from Settings ▸ How to Play. Returning players (onboardingSeen) never see it again.
- **Reduced-motion / sound / haptics:** honour existing settings throughout.
- **No dead ends:** every step has a clear forward action; nothing blocks input > ~1s.

## Build approach (grounded in current code)
- **State (SaveData / GameStore):** add `onboardingSeen` (supersede/augment
  `tutorialSeen`), `metaIntroSeen` (post-first-run tour shown), and `firstRealRunDone`.
  Add a one-shot `grantStarterCredits(_:)` (guarded) — economy already lives in
  `GameStore`/`cyberdeck.credits`.
- **OnboardingFlow coordinator (new view):** sequences L1→L2→L3 → Payday, each skippable;
  on finish → `markOnboardingSeen()` + return to menu. Replaces the launch branch in
  `RootView` (currently `if !store.tutorialSeen { screen = .tutorial }`).
- **Practice scenes:** evolve the current scripted-grid `TutorialView` into 3 scripted
  scenes (deterministic teaching) for L1/L2; for L3, a short real-engine mini-run on a
  slow, no-fail config (Flow-like) so Fever/power-ups feel real. Tradeoff: scripted =
  precise but not "live"; real-engine = authentic but less controllable. Recommend the
  hybrid above.
- **Guided shop steps:** a lightweight `GuidedHint` banner over the existing Cyberdeck /
  Cosmetics views with a required-action target ("buy this one" / "equip one"),
  gated until the action completes. Avoids building a generic coachmark system.
- **Post-run hook:** on the first game-over, if `!metaIntroSeen`, route into the Act 2
  guided tour (or a one-tap prompt to start it).

## Suggested implementation phasing (fits the one-task-per-run cadence)
- **Phase A:** 3 practice levels + OnboardingFlow coordinator + state flags +
  skippable/revisitable. (Largest chunk.)
- **Phase B:** Payday starter-CR grant + count-up + post-first-run meta-loop surfacing.
- **Phase C:** Guided Cyberdeck purchase + Cosmetics equip (GuidedHint banners).

## Deferred / minor open questions
- Exact starter CR (150 is a placeholder — tune so the first RAM upgrade is affordable
  but not everything at once).
- Whether L3 mentions grid-growth or saves it for Campaign core 9's briefing.
- Whether to add a tiny "welcome" splash before L1 or jump straight into doing.
