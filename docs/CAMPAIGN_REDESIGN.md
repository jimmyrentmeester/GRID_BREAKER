# Campaign 2.0 — chapters, pacing, PROTOCOL bosses & retention

Design doc for the next campaign iteration. Driven by two things: live feedback that the
campaign **introduces new mechanics too fast**, and the wish to **reuse the new PROTOCOL
mode** meaningfully. Plus a set of retention features to keep players past the campaign.

Engine stays the authority; everything here is content/structure + presentation, fed by
the deterministic `GridEngine` (no mechanics in the view — see `game-feel-and-juice`).

---

## 1. The core problem (and the proven fix)

Today the campaign is **10 flat cores** and a new mechanic lands on almost every one
(core 1 decode, 2 armored, 3 bombs, 4 fever, 5…, 6 cache, 7 worm, …). That's ~7 new ideas
in the first 7 levels — no room to *enjoy* a mechanic before the next arrives. New players
churn at the cognitive cliff; returning players have no mid-term goal.

The proven fix in level-based mobile games (Angry Birds, Cut the Rope, Monument Valley,
Two Dots) is the same shape every time:

> **Chapters (worlds). One new idea per chapter. 2–3 levels to enjoy it. A climax. A reward.**

This is the "teach → practice → test → reward" loop, stretched from per-level to
per-chapter so each idea gets breathing room.

## 2. Chapter structure

Regroup the existing mechanics into **4 chapters**, each introducing exactly **one** new
mechanic family, with 3 standard cores to master it and a **PROTOCOL boss** as the finale.
~16 cores total (up from 10) but a *gentler* curve, not a harder one.

| Chapter | Theme | New mechanic (taught once, at the chapter open) | Cores | Boss (PROTOCOL) |
|---|---|---|---|---|
| 1 · The Outer Net | first contact | decode basics → **armored** | 3 | DAEMON SET — "crack the lock chain" |
| 2 · Corporate ICE | danger + reward | **firewall bombs** → **Fever** | 3 | DMZ PURGE — "scrub the trap room" |
| 3 · Deep Systems | greed + the chase | **data caches** → **worms** | 3 | DAEMON SET on 4×4 — "the vault sequence" |
| 4 · The Core | mastery | **power-ups** → **grid 4×4** | 3 | The Monolith — mixed-objective finale |

Rules that make it slower *and* better:
- **A new mechanic only ever appears on the first core of a chapter**, with its briefing.
  Cores 2–3 reuse it (plus everything prior) with gently rising targets — the "practice"
  beat that's missing today.
- **Each chapter opens and closes with a short narrative card** (netrunner flavour, 1–2
  lines, skippable). Cheap to write, big for "sense of a journey" — the spine the campaign
  lacks. Example open: *"Sector 7. Low ICE, fat data. A good place to learn the trade."*
- **The boss core is a PROTOCOL objective**, themed to the chapter. This gives PROTOCOL a
  home in the campaign (its mechanics are already built + tuned), and every chapter ends on
  a distinct, memorable challenge instead of "another core, bigger number."
- Difficulty still rises via `difficultyBias`, but the **slope flattens within a chapter**
  and steps up between chapters — a staircase, not a ramp.

Implementation note: `DataCore` already has cumulative feature gates + a `briefing`. This is
mostly **content (the `Campaign.cores` table) + a `chapter` field + a chapter-grouped level
select + a boss flag that selects a PROTOCOL config**. No engine changes for chapters
themselves; the boss reuses `GameConfig.protocolMode()` with a campaign target.

## 3. Star / mastery objectives (the replay layer)

Every level-based hit ships a 3-tier rating because it turns "I cleared it" into "I want to
*master* it." Add per-core objectives:

- ★ Clear the core (reach target before RAM runs out) — unchanged.
- ★★ Clear with score ≥ a stretch target (or ≥ N seconds to spare).
- ★★★ Clear **flawless** (no mistap, no expired daemon) — the skill ceiling.

Stars are the **engagement currency**: a chapter unlocks its cosmetic reward at, say, 7/9
stars, and a "perfect chapter" (9/9) unlocks a prestige palette/trail. This is replay value
with **zero pay-to-win** — stars only ever buy cosmetics, never power, never the next level
(don't hard-gate progress behind stars; that frustrates — gate *rewards*, not *access*).

`SaveData.campaignBests` already stores a per-core best score; extend to per-core stars.

## 4. Creative expansion — keep it fun for the long tail

Prioritised; build top-down. Each is fed by the existing deterministic engine.

1. **Daily-result share card (highest ROI).** The Daily Hack already gives everyone the
   same seed. Add a Wordle-style **shareable result** ("GRID_BREAKER Daily ▦ 1,240 · 🔥×3 ·
   streak 9") + a **daily streak counter**. This is simultaneously the best *retention* hook
   (a reason to open the app every day) and the best *free acquisition* loop (see the growth
   doc). One feature, two wins.
2. **Run modifiers / mutators (roguelite depth, no content cost).** Optional toggles for
   endless: "No Fever," "Double Firewalls," "Tiny RAM," "Mirror Grid." Pick 1–2 before a
   run for a score multiplier. Vampire Survivors / Balatro proved that *modifiers* create
   enormous depth from existing systems. Pure presentation/config over the engine.
3. **Weekly challenge.** One rotating seeded board + modifier, its own leaderboard, resets
   weekly. A bigger beat than the daily, a reason to return on a slower cadence.
4. **Cosmetic unlock track earned by play.** A light "data fragments" currency from
   chapters/dailies that unlocks lore snippets + cosmetics — the no-p2w-friendly long-tail
   progression. (Distinct from Credits, which buy upgrades.)
5. **Endless "deep run" milestones / prestige.** Named tiers at score landmarks (the
   milestones already exist) with a one-time celebration + a profile badge — gives the
   endless grinders a ladder.

What to **skip** (scope discipline): new daemon types, a meta-map you walk, multiplayer.
They're content-heavy and don't address the actual feedback. Depth-from-existing-systems
(modifiers, stars, daily) beats more-content every time at hobby scale.

## 5. Recommended build order

1. **Chapter restructure + slower pacing + narrative cards** — directly answers the
   feedback; mostly the `Campaign.cores` table + a `chapter` field + chapter-grouped level
   select. Re-tune with the headless multi-skill sim (the existing tool).
2. **PROTOCOL bosses** — wire chapter finales to `protocolMode()` configs. Reuses built,
   tuned mechanics; high payoff per unit effort.
3. **Star objectives** — engine already exposes mistakes/score/time; add per-core stars +
   chapter cosmetic rewards.
4. **Daily share card + streak** — the retention/acquisition multiplier (also in the growth
   plan). Do this even before 1–3 if growth is the priority.
5. Modifiers → weekly → fragment track, as time allows.

Ship each as its own watchable slice (ground-truth Part 4.5), sim-tuned, behind a clean
build. Re-validate the curve with the headless sim before every campaign retune.
