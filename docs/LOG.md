# LOG — GRID_BREAKER

Append-only record of completed runs (newest first). This file — not commit
prefixes — is the sole record of what's done.

## Run #99 — RAM frame: earlier, bar-matched bottom glow (2026-06-22)
Maintainer tweak: start the bottom glow sooner (≈2/3 through the gold band, fraction ≈0.34 instead of
0.25) and let its colour follow the bar (gold→red) instead of always red. `UI/Juice.swift`
`RAMPerimeterFrame`: `glowStart = 0.34` and the glow `RadialGradient` now uses `tint` (so it's gold in
the gold band and shifts to red toward 0, animated with the existing `value: tint` colour transition).
Verified live on iPhone 16 sim: in the gold band the bottom glow now reads gold; builds clean.

## Run #98 — RAM frame: split-drain redesign + grid layout-shift fix (2026-06-22)
Two maintainer notes after the device pass: (1) when RAM is in the red the remaining lit bit sat at
the *top* (hard to read); (2) the grid "sometimes grows/shrinks slightly", suspected to be the new
frame.
- **Split-drain frame** (`UI/Juice.swift`): new `PerimeterDrain` Shape — the lit line now splits at
  top-centre and the two fronts descend evenly down both sides, meeting at the bottom-centre as RAM →
  0 (built from two symmetric arcs, each from the descending front `(1-fraction)·halfPerimeter` down
  to bottom-centre; animatable on fraction so it still glides + re-lights on decode). So remaining RAM
  always sits LOW (read "almost out" at the bottom, near the grid). Added an upward red glow rising
  from the bottom edge as 0 nears. Removed the layout-affecting `.padding(lineW/2)` — inset is built
  into the Shape, so the view is now structured exactly like the existing edge borders.
- **Grid layout-shift fix** (`GameView.swift`): root cause was NOT the RAM frame (measured: grid-top y
  identical across RAM levels). The grid uses `aspectRatio(.fit)` and takes leftover space above a
  `Spacer(maxHeight:96)` buffer; conditionally-inserted score-block rows — the endless STREAK badge
  and the shield-charge indicator — change the score block's height, and once the spacer buffer is
  exhausted (shorter devices / data-core at full height) the grid resizes. Fixed by reserving constant
  height for both (the badge in a `frame(height:26·sc)` slot, endless-only; the shield in a
  `frame(height:16·sc)` slot) so neither toggling can shift the grid. `×N` is height-safe (smaller
  than the score glyph); grid 3×3→4×4 keeps its outer square. The frame is also exonerated/isolated:
  no animated padding, drawn like the other borders.
- **Verified** (iPhone 16 sim): Debug build succeeds; the red frame now sits at the bottom with the
  upward glow (captured at ~1s/5s RAM); fronts descend symmetrically; game-over hides it; layout reads
  correctly. Cyan/gold tiers share the code path.
- Next (maintainer): on-device feel pass of the split-drain + the stabilised layout; tune to taste,
  then decide default + ship version.

## Run #97 — RAM background: pivot waterline → screen-edge containment frame (2026-06-22)
Maintainer feedback after the on-device pass: the draining waterline works but reads "battery/
tank", not netrunner — and asked about doing more with the screen edge. (We hadn't avoided the
edge for best-practice reasons; the opposite — we'd just scoped it to the critical alarm.) Chose
"rand-frame vervangt waterline".
- **`UI/Juice.swift`**: replaced `RAMBackdrop` (waterline) + `RAMCriticalEdge` (separate red alarm)
  with one `RAMPerimeterFrame` — a screen-edge "containment frame" that IS the meter: a dim full-
  perimeter rail + a lit `Rectangle().trim(0…ramFraction)` stroke that burns down as RAM drains,
  colour cyan→gold→red, glows, re-lights a segment on each decode, and folds the critical alarm in
  (intensify + breathing red pulse under 15%, static under Reduce Motion). Zero grid-interior cost.
- **`GameView.swift`**: dropped the behind-content waterline layer and the separate critical-edge
  layer; one `RAMPerimeterFrame` over the content (gated by `ramBackground` + `!isGameOver`). Doc
  comments + `SaveData.ramBackgroundEnabled` doc updated (no schema change — same toggle/key).
- **Verified** (iPhone 16 sim): Debug build succeeds; the gold near-full frame, the red frame, and
  the burn-down to a short top-left segment at ~1s RAM all captured live; game-over hides it; the
  SETTINGS ▸ DISPLAY toggle is unchanged. Cyan tier shares the code path.
- Next (maintainer): on-device feel pass of the frame; tune line weight / inset / corner radius to
  taste, then decide default + ship version.

## Run #96 — RAM-as-environment background (optional, Settings toggle) (2026-06-22)
Post-launch feedback: the top RAM bar is hard to track while focused on the grid. Built the
"RAM as draining background" idea, grounded in peripheral-vision best practices (perifeer zicht
pikt randen/beweging/helderheid op, geen dunne balk bovenin). On a feature branch
(`feature/ram-background`) so main stays clean while v1.2 is in review.
- **`UI/Juice.swift`**: `RAMBackdrop` — the play field fills from the bottom; a bright "waterline"
  recedes top→down with `ramFraction`, colour cyan→gold→red, body low-opacity (keeps the grid
  readable), rises on every decode (visible top-up). `RAMCriticalEdge` — a breathing red screen-edge
  alarm under ~15% RAM (static tint under Reduce Motion), pairing with the existing `.ramCritical`
  audio double-pulse. One continuous (waterline) + one late alarm (edge) → never two motions at once.
- **`GameView.swift`**: both layers gated by a new `ramBackground` init flag + `!isGameOver`; the slim
  top RAM bar stays as the precise readout (layered, not replaced).
- **Persistence**: `SaveData.ramBackgroundEnabled` (default true, tolerant-decoded, kept across
  `resetProgress` as a preference) + `GameStore.setRamBackgroundEnabled`. New SETTINGS ▸ DISPLAY ▸
  "RAM BACKGROUND" toggle. Passed from all four `GameView` call-sites in `RootView`.
- **Verified** (iPhone 16 sim): Debug build succeeds; waterline drains top→down with the gold and red
  tiers + the red critical edge captured live; the top bar persists; game-over hides the layer; the
  Settings toggle flips ON/OFF and persists. Cyan tier shares the same code path. Default-on for the
  on-device feel pass; flipping the default later is one line.
- Next (maintainer): play it on a real device, decide default + whether to ship in a future version.

## Run #95 — Flow/chill dead code cleanup (2026-06-20)
Removed all 37 unreachable `chill`/Flow references before merging PROTOCOL to main.
- **`GameView.swift`** (`GameViewModel` + `GameView`): removed `chill` field + init param from
  `GameViewModel`; removed `chill` field, init param, `self.chill = chill`, and `if chill { ... }`
  config branch from `GameView`; simplified `coreProgress` (dropped Flow combo-ring path); removed
  `ChillAtmosphere` usage + `if chill` body blocks; removed `chill:` from `HUDView` and
  `IslandFrameRow` call-sites; cleaned up the 8 `guard !chill` / `if !chill` conditionals in
  `process()` (all now fire unconditionally — chill's no-feedback overrides no longer exist).
- **`Juice.swift`**: removed `ChillAtmosphere` struct (Flow atmosphere, ~20 lines).
- **`GameCenterService.swift`**: removed `GCRunMode.flow`, its early-return guard, and the `.flow`
  case from the submit switch. `GameConfig.chill()` kept as a pure value-type archive (no callers).
- BUILD SUCCEEDED.

## Run #94 — PROTOCOL phase 4: difficulty ramp (2026-06-20)
Score-scaled objective difficulty: four new `GameConfig` accessors mirroring the existing
`spawnInterval`/`nodeLifespan` exponential pattern. `GridEngine` wired to all four call-sites.
- `objectiveGap(atScore:)` — objective gap shrinks from 5.5 s (base) to 2.5 s (floor) with
  compression 0.010. At score 30 ≈ 4.1 s, score 60 ≈ 3.0 s, score 100 ≈ 2.5 s (floored).
  Engine scheduler now calls `objectiveGap(atScore: scaledScore)` instead of the static field.
- `dmzOverrunPace(atScore:)` — overrun cadence shrinks from 1.6 s to 0.75 s (compression 0.008):
  score 50 ≈ 1.07 s, score 100 ≈ 0.75 s. Engine now calls `dmzOverrunPace(atScore: scaledScore)`.
- `daemonSetSizeRange(atScore:)` — starts 2…2 (score 0), steps to 2…3 (score 15), 2…4 (score 30).
  `spawnDaemonSet` now passes the score-derived range to the RNG draw.
- `dmzSizeRange(atScore:)` — starts 2…2, steps to 2…3 (score 20), 2…4 (score 40).
  `spawnDMZ` now passes the score-derived range.
- Also fixed a latent bug in `scripts/enginecheck/dmz.swift` check 2: `before` was capturing total
  node count but being compared against intrusion count (only correct when all nodes happened to be
  intrusions). Now correctly captures `intrusionsBefore`.
- **Verified:** 48/48 checks (15 daemonset + 18 dmz + 15 new ramp), `run.sh` default now covers all
  three. Debug BUILD SUCCEEDED (iPhone SE sim). Committed `413c0ca`, pushed to `feature/protocol-mode`.

## Run #93 — PROTOCOL phase 3: DMZ PURGE mechanic (2026-06-20)
The second objective (issue #4): a hostile zone you race to scrub before the overrun fills the grid.
- **Engine** (`NodeType`, `GridNode`, `GameConfig`, `GridEngine`): new `NodeType.intrusion` (one-tap,
  persistent — `GridNode.isPersistent` now also covers it, so the expiry sweep skips it). A zone model
  `dmzZone` (a contiguous free block — `candidateZones` enumerates 1×N / N×1 / 2×2 — spawned full of
  intrusion via `spawnDMZ`). An **overrun** creep in `tick` (`dmzOverrunInterval`: fills a random cell
  *outside* the zone; if none is free → `endGame(.dmzOverrun)`). `clearIntrusion` resolves taps: flat
  `scoreIntrusion` + small `dmzClearRefill`, deliberately **outside** the combo/fever system (DMZ is
  defense); clearing the last in-zone cell purges → sweeps the overrun + `dmzPurgeBonus` RAM relief.
  The normal daemon stream pauses while a DMZ is active. A minimal **objective scheduler**
  (`objectiveCursor` over enabled objectives, shared `objectiveInterval`) now alternates DAEMON SET ↔
  DMZ — replacing the set-only `daemonSetInterval`/`timeSinceLastSet`. New `GameEvent`s:
  `dmzSpawned`/`intrusionCleared`/`dmzOverrunSpawned`/`dmzPurged`; new `GameOverReason.dmzOverrun`;
  snapshot exposes `dmzZone`.
- **UI** (`GameView`): hostile red `hexagon.fill` intrusion sprite (distinct from the never-tap
  firewall — and bombs never share a DMZ board); a dashed red containment outline per zone cell
  (`CellView.isZone`, kept after a cell is cleared → shows purge progress); juice — red pop-in on
  spawn, light tick on clear, soft pulse on each overrun creep, success sting + hit-stop on purge,
  a "DMZ PURGE" / "DMZ PURGED" toast; `DMZ OVERRUN` game-over headline; VoiceOver label.
- **Verified:** 18/18 deterministic checks (`scripts/enginecheck/dmz.swift`: spawn structure, overrun
  lands outside the zone, defensive clear keeps the DMZ, full purge sweeps + relief, unchecked overrun
  → `.dmzOverrun`, and set↔DMZ alternation). 15/15 DAEMON SET checks still pass after the scheduler
  refactor. Added `scripts/enginecheck/run.sh` (checks need a `main.swift` filename to compile).
  `xcodebuild` Debug BUILD SUCCEEDED (iPhone 16 sim). Branch `feature/protocol-mode`.

## Run #92 — Verify DAEMON SET tap resolution (deterministic) (2026-06-19)
(On branch `feature/protocol-mode`. #90–91 are the parallel iPad/release track on main.)
- Wrote `scripts/enginecheck/daemonset.swift` — a standalone harness that compiles the Core
  engine/model files (pure value types, no SwiftUI) and asserts the DAEMON SET logic without a
  simulator (the deterministic-core QA pattern). 15/15 checks pass:
  spawn (2–4 nodes, orders 1…N, setSize); out-of-order tap → wrongOrder (node stays, no score,
  RAM penalty); in-order taps advance then complete and clear the board; completion arms a ×4
  next decode (one-shot, back to ×1 after); a completion that crosses the Fever threshold makes
  Fever last ×4 (feverFraction 4.00). Confirms phase 2 is correct before building phase 3.

## Run #91 — iPad 13" App Store screenshot set (2026-06-19)
The polished 5-screen iPad set for the v1.1 listing (the piece left open in Run #90).
- **5 screenshots at 2064×2752** (App Store 13" iPad) in `docs/screenshots/ipad-13/`: 01-menu,
  02-fever (×10, STREAK ×5, 4×4, Fever), 03-campaign (6/10), 04-cyberdeck (with cumulative
  values), 05-cosmetics. All show the universal iPad layout (centered play/chrome columns).
- **Workflow**: a demo save injected into the simulator's UserDefaults (lived-in shops/campaign:
  BEST 1287, 2480 CR, 6 cores cleared, owned palettes/trails) + temporary in-code hooks —
  launch-arg screen routing (`-shot -screen <name>`), a perfect-play autoplay bot + a fast-fever
  demo config (`-autoplay`), boot/Game-Center skips. All hooks reverted before commit (verified
  clean: no TEMP residue; Debug build passes). See `docs/screenshots/ipad-13/README.md`.
- Maintainer still does: drag the 5 PNGs into the iPad 13" slot in App Store Connect, then
  archive/upload/submit v1.1.

## Run #90 — Merge iPad support into main + bump to v1.1 (2026-06-19)
(Runs #88–89 are the PROTOCOL work on branch `feature/protocol-mode`, not yet on main; this is
the parallel iPad/release track, numbered #90 to avoid a clash when PROTOCOL lands.)
- **Merged `ipad-support` → `main`**: universal iPhone + iPad target, max-width play column for the
  chrome screens, cohesive phone-shaped play panel in GameView, adaptive launch storyboard,
  pause-button alignment. One conflict (Settings route) resolved to keep both main's `onCodex` and
  ipad's `.playColumn()`; the new Codex screen also got `.playColumn()` for iPad consistency.
- **Verified**: iPhone + iPad (13") Debug builds both succeed; iPad menu renders correctly at
  2064×2752 (play column centered over the neon backdrop; starter CR + START HERE badge present).
- **Bumped to v1.1**: `MARKETING_VERSION` 1.0→1.1, `CURRENT_PROJECT_VERSION` 2→3 (both configs).
- This v1.1 shipped everything on main (iPad + post-launch fixes) but NOT PROTOCOL (still on branch).

## Run #89 — PROTOCOL phase 2: DAEMON SET mechanic (2026-06-19)
The first objective (issue #3): an ordered daemon chain you tap in sequence for a big reward.
- **Engine** (`GridNode`, `GameConfig`, `GridEngine`): `GridNode.setOrder/setSize`; a seeded set
  spawner on a gap timer (`daemonSetInterval`, size 2–4) that fires only when no set is active and
  not mid-Fever; ordered tap resolution (`handleSetTap` — only the lowest remaining order is valid;
  wrong order = a miss, set unchanged); completion arms a one-shot ×4 on the next decode and, if it
  triggers Fever, a ×4 Fever duration. Set nodes don't expire (the RAM clock is the pressure). All
  deterministic (seeded RNG). New `GameEvent`s: spawned/advanced/completed/wrongOrder.
- **UI** (`GameView`): numbered set sprite with order pips (1→N filled), rendered before the
  fever-gold path; completion hit-stop + gold pop + rigid haptic; wrong-order red flash + error
  border; a "DAEMON SET ×N" / "SET CRACKED — ×4 NEXT" toast; VoiceOver label.
- Verified in the simulator: sets spawn and render correctly (numbered 1/2/3 with pips). Tap
  resolution + ×4 reward to confirm on device. Debug build passes. Branch `feature/protocol-mode`.

## Run #88 — PROTOCOL mode skeleton (replaces Flow) (2026-06-19)
Gamemode redesign phase 1 of 4 (see docs/PROTOCOL_MODE.md). Maintainer chose: replace Flow with a
new objective-driven mode (alternating DAEMON SET + DMZ PURGE objectives). This run lays the skeleton.
- **New PROTOCOL mode** replaces Flow's menu entry + routing: `GameConfig.protocolMode()` (challenge
  base built on endless, no chill, no endless landmarks, fixed 3×3 for DMZ zones); `RootView` menu tile
  FLOW→PROTOCOL ("scope" glyph) and `.flow`→`.protocolMode` routing; `GameView` gained a `protocolMode`
  flag selecting the config.
- **Economy**: `GameStore.recordProtocolRun(score:)` pays Credits but does NOT touch the Endless
  high-score list / leaderboard (PROTOCOL's score isn't comparable).
- **Game Center**: new `GCRunMode.protocolMode` — run achievements (fever/streak/grid) still earn, but
  no score submit and no score landmarks.
- Debug build passes. Branch `feature/protocol-mode`.

## Run #87 — Onboarding rework: practice optional, starter CR at first launch (2026-06-19)
Tutorial revision part 2 (maintainer choice: lean on Campaign as the learn route; practice optional).
- **First-launch flow** (`UI/RootView.swift`): replaced the forced practice tutorial with an
  up-front starter-CR grant. New players now land on the menu (Campaign = START HERE) with 150 CR;
  the practice tutorial is no longer auto-launched — it stays in Settings ▸ How to Play. Keyed off
  `starterCreditsGranted` (idempotent), so existing players are untouched and old-tutorial skippers
  finally get their 150 CR. `onboardingPayday` default flipped to false (CR no longer paid in-tutorial).
- **`GameStore.starterCreditsGranted`**: added a public accessor (mirrors `tutorialSeen`).
- Verified on a fresh simulator save: credits=150, starterCreditsGranted=true, tutorialSeen=true,
  campaignProgress=0 (so the START HERE badge shows). Debug build passes. (DECISIONS D29)
- Branch `feature/onboarding-rework`. Deliberately NOT done: relocating the guided shop tour, and
  reworking the practice scene content.

## Run #86 — Codex reachable from the pause menu (2026-06-19)
Small follow-up to Run #85: re-read the rules mid-run without quitting.
- `PauseOverlay` gained a subtle "CODEX" link under RESUME/RESTART/QUIT (`onCodex`).
- `GameView` shows `CodexView` over an opaque backdrop while paused; BACK returns to the pause
  menu and the run stays paused underneath. Reuses the existing CodexView (no duplication).
- Debug build passes. Branch `feature/codex-in-pause`.

## Run #85 — Codex (rules reference) + soft-steer new players to Campaign (2026-06-19)
Tutorial revision (post-launch feedback: too little explanation / no way to re-read the rules).
Maintainer chose **soft-steer, no gating** (the live app keeps free mode access); the deeper
"campaign replaces the practice tutorial" idea is a separate, careful follow-up (it depends on
the starter-credits payday currently living in the practice flow).
- **CodexView** (`UI/MenuViews.swift`): a scannable, always-available manual — TARGETS (the five
  node types, color-coded glyphs matching the real game), POWER-UPS, SYSTEMS (RAM clock, Fever,
  clean streak, grid growth), CYBERDECK (reuses `CyberdeckUpgrade.detail` so it can't drift), and
  MODES. Terminal styling, full accessibility labels. Reachable from the menu (new CODEX utility
  button) and Settings ▸ Help.
- **Soft-steer** (`UI/RootView.swift`): `MenuTile` gained a `highlight` mode (gold "START HERE"
  badge + border + glow); enabled on Campaign only while `campaignProgress == 0`, so brand-new
  players are drawn to the learn-by-doing route without anything being locked.
- Verified both screens in the simulator (Codex + menu screenshots); Debug build passes. Branch
  `feature/codex-and-soft-steering`.
- Follow-ups still open: full onboarding rework (campaign-as-tutorial + relocate the payday),
  optional Codex entry from the pause menu, and the gamemode redesign (Flow's future + DAEMON
  SET / DMZ PURGE).

## Run #84 — Cyberdeck shows cumulative upgrade values (2026-06-19)
Post-launch feature request: the Cyberdeck didn't show what your bought upgrades add up to.
- **`CyberdeckUpgrade.cumulativeEffect(at:)`** (`Core/Models/Cyberdeck.swift`): returns the
  total bonus owned at a given level, formatted per upgrade (e.g. "+12s RAM buffer",
  "+0.45s per decode", "3 mistakes absorbed", "+1.5s Fever duration", "+30% Credits per run").
  Reads the real `GameConfig.default` constants (like `detail` does), so it can't drift from
  what the engine applies. Shows the cumulative bonus the player *bought*, not the absolute
  total (which is mode-dependent for RAM/refill) — unambiguous and mode-independent.
- **`UpgradeRow`** (`UI/MenuViews.swift`): added a "▸ <cumulative>" line under the per-level
  detail, in cyan when owned and dimmed at level 0 (so the empty state still reads). Folded the
  value into the row's accessibility label too.
- Values verified against GameConfig (level 1/3 spot-check); Debug build passes. Visual placement
  to confirm on device. Branch `feature/cyberdeck-cumulative-values`.

## Run #83 — Post-launch fixes: Game Center diagnostics + pause restart (2026-06-19)
Two more from the post-launch list (Game Center bug + restart-button request).
- **Game Center leaderboards "not working" in production** (`Services/GameCenterService.swift`,
  `UI/RootView.swift`): code/entitlement/IDs verified correct, so the likely cause is App
  Store Connect config (boards not created/live under the exact IDs). Added: Debug-only
  `gcLog` tracing; `verifyLeaderboards()` that logs which board IDs ASC actually recognizes
  (surfaces the #1 cause); and `submitBacklog(endlessBest:dailyBest:)` — re-submits stored
  local bests on auth so prior scores appear **retroactively**. Logging is a no-op in Release;
  report-only behavior unchanged. Maintainer still needs to confirm the boards in ASC. (D28)
- **Pause menu restart button** (`UI/GameView.swift`): `PauseOverlay` now offers RESUME /
  RESTART / QUIT (was RESUME / QUIT). RESTART reuses the proven game-over "replay" flow
  (`model.restart(seed:)` + countdown), restarting the same mode/core without a trip to the
  menu. Switched the buttons to a full-width vertical stack so three actions stay legible on
  the smallest screens.
- Debug + Release builds verified. On branch `bugfix/post-launch-batch-1` (renamed from
  `bugfix/fever-spawn-and-error-feedback`; now holds Runs #82–83).

## Run #82 — Post-launch community bug fixes (fever spawn + error feedback) (2026-06-19)
First fixes from real player reports (GitHub issues #1, #2 by @brand0new), two days post-launch.
- **Bug #1 — Fever slowed spawns in Campaign** (`Core/Engine/GridEngine.swift`): Fever used the
  flat `feverSpawnInterval`/`feverActiveNodes`, which on difficulty-biased campaign cores were
  *slower/sparser* than the score-scaled pace already in effect — so Fever read as a slowdown.
  Now Fever takes the faster interval and fuller node ceiling of (fever constants, score-scaled),
  never the slower. No-op-or-better in endless/flow. (D26)
- **Bug #2 — No clear feedback on misses** (`UI/Juice.swift`, `UI/GameView.swift`): the per-cell
  miss flash was white (looked like a hit) and daemon expiry had no visual. Added: red per-cell
  flash for `.miss`/`.bomb`; a new `ErrorFlashBorder` red screen-edge pulse on every mistap/expiry;
  `nodeExpired` now gets the red cell flash + border + a rigid haptic (was soft). Gated by `!chill`
  + Reduce Motion. (D27)
- Branch `bugfix/post-launch-batch-1` off `main`. Debug build verified (simulator).
  Feel to be confirmed on device; ships in the next update.

## Run #81 — Launch & marketing prep (landing page, OG card, copy) (2026-06-14)
Built the launch kit while v1.0 sits in review.
- **Marketing landing page** (`docs/site/index.html`, deploys to `/gridbreaker/`): neon
  hero (icon + wordmark + tagline + App Store badge placeholder), 3 screenshots, four-mode
  + progress feature cards, "built right" (no ads/tracking), OG/Twitter meta tags, support/
  privacy footer. Replaced the old bare links page.
- **Web assets** (`docs/site/assets/`): 3 web-resized screenshots + 180px icon + a
  **1200×630 OG share card** (`scripts/makeog.swift` — chevron/cursor mark, wordmark,
  tagline, mode/no-tracking strip).
- **`docs/marketing/launch-copy.md`**: paste-ready X, Product Hunt (tagline + description +
  maker comment), Reddit, hashtags, and a launch-day checklist. All use an `APP_STORE_URL`
  placeholder to swap once the real link exists.
- **Deployed live** to https://jimmyrentmeester.github.io/gridbreaker/ — page + all 5
  image assets verified HTTP 200 (the broken images in the editor preview were just the
  sandbox not serving sibling files; they resolve on Pages). App Store badge is a "coming
  soon" placeholder until the app is live + the real URL is known (then a ~2-min swap).
- **Instagram cards** (`docs/marketing/social/`, `scripts/maketeaser.swift`): 1080×1080
  feed + 1080×1920 story, in four flavours — **COMING SOON** and **OUT NOW**, each in a
  clean type layout and a **key-art** layout (full-bleed Fever screenshot, dark scrims,
  neon frame). 8 PNGs total. **Tailored for a wide personal audience** (family/friends/
  colleagues, English): jargon dropped for warm lines — teaser `// something I've been
  building` (name shown + a **heavily blurred** glimpse so it stays partly a secret),
  out-now `// my new iPhone game` + `A FREE GAME FOR iPHONE · ON THE APP STORE` (clearly an
  iOS game). Blur via CoreImage; teaser screenshots blurred, out-now sharp.

## Run #82 — Social clip, Dutch listing, promo-channel list (2026-06-14)
More launch prep while in review.
- **Gameplay clip/GIF** (`scripts/makeclip.swift`, AVFoundation + ImageIO — no ffmpeg
  available): `docs/marketing/social/clip-story.mp4` (8 s vertical w/ audio, for
  Reels/Stories) + `clip-square.gif` (5 s, 540², center-cropped, autoplay — for feed/X/
  Slack). Cut from the promo video at the Fever moment (ring + ◆50 milestone + decode pop).
- **Dutch App Store localization** added to `docs/store-copy.md`: subtitle, promo text,
  keywords, full description, what's-new — to add as a Dutch (NL) locale for reach.
- **`docs/marketing/promo-channels.md`**: tiered launch channel list (personal/IG/LinkedIn,
  reddit, Product Hunt, the "I built this" HN/newsletter angle, clip platforms, press) with
  per-channel notes, a cadence, and etiquette do/don'ts.

## Run #80 — Submitted to the App Store (Phases D + E) (2026-06-14)
GRID_BREAKER 1.0 is in Apple's review queue. 🎉
- **E2 pre-flight:** `xcodebuild archive` (Release / generic iOS device) → **ARCHIVE
  SUCCEEDED**; verified v1.0 / build 1, bundle `nl.gridbreaker.app`, iPhone-only,
  automatic signing, export compliance `ITSAppUsesNonExemptEncryption=NO` (pre-answered).
- **D (App Store Connect), guided click-by-click:** app record created; App Information
  (subtitle, Games/Arcade, privacy URL); Age Rating → **4+**; Pricing **Free** / all
  territories; listing (6.9" screenshots + promo preview + copy + support/marketing URLs
  + copyright); **App Privacy "Data Not Collected"** published.
- **D6 Game Center:** 2 leaderboards (`lb.endless` Classic, `lb.daily` Recurring) + all
  **13 achievements** created with matching IDs, points, and the circular neon badges
  (reshaped from square after spotting GC's circular crop). Enabled on v1.0.
- **E (build & submit):** archived + uploaded in Xcode; build attached; cleared the two
  submit blockers (Game Center checkbox on the version + App Privacy publish);
  **Submitted for Review on 2026-06-14**, set to auto-release on approval.
- **Docs/badges:** circular badge frame (`scripts/makebadges.swift`); store-copy URLs
  filled; RELEASE_PLAN D/E marked done, F1 = Waiting for Review. Next: E5 if rejected.

## Run #79 — Rename site to jimmyrentmeester.github.io (2026-06-13)
Cleaned up the public URL before submission (auto-generated handle → real name).
- 👤 renamed the GitHub account `k6czwyxg8g-cmyk` → `jimmyrentmeester`; 🤖 renamed the
  repo to `jimmyrentmeester.github.io`, Pages rebuilt, re-verified all pages **200** at
  the new URLs, and swapped the username across every doc (RELEASE_PLAN, walkthrough
  D2/D5, site README, and the run #78 URLs below — now showing the final name).
- Final: `https://jimmyrentmeester.github.io/gridbreaker/{privacy,support}.html`.

## Run #78 — Privacy + Support pages hosted (B3/B4 done) (2026-06-13)
Published the two App-Store-required pages on GitHub Pages, future-proofed for more apps.
- **Setup:** created the **user-site repo** `jimmyrentmeester.github.io` (public) rather
  than a per-app repo, so every future app is just a new subfolder — one Pages site
  forever. GRID_BREAKER lives under `/gridbreaker/`; a small neon hub `index.html` at
  the root links to it.
- **Live & verified (HTTP 200, correct content + email):**
  privacy → https://jimmyrentmeester.github.io/gridbreaker/privacy.html ·
  support → https://jimmyrentmeester.github.io/gridbreaker/support.html ·
  hub → https://jimmyrentmeester.github.io/
- **Docs:** RELEASE_PLAN B3/B4 marked done with URLs; walkthrough D2/D5 now have the
  exact URLs to paste; `docs/site/README.md` documents the live setup + how to update /
  add future apps. `docs/site/` stays the source of truth (copy→push to deploy).

## Run #77 — Game Center achievement badge art (13 PNGs) (2026-06-13)
Closed the only D6 asset gap: the 13 required achievement images.
- **`scripts/makebadges.swift` (new):** CoreGraphics/CoreText generator (same neon
  language as the app icon) — dark radial card + accent frame + one glyph per badge,
  1024×1024 opaque PNG. Per-achievement accent (gold/cyan/magenta/worm-green) +
  bespoke glyphs (flame w/ hot core, ×3 flame, bolt+25, shield+check, power-up diamond,
  4×4 grid, big score numerals, numbered hexagons, rising MAX bars). Outputs a 4×4
  contact sheet for QA; visually verified + flame reshaped (droplet→flame).
- **`docs/gamecenter/achievements/`:** the 13 PNGs named by ID suffix + `_preview.png`
  + README mapping file→ID→title→points. Walkthrough D6 updated to point here.

## Run #76 — Game Center verification + ASC setup steps; B1 done (2026-06-13)
Verified the Run #75 Game Center layer end-to-end and prepped the App Store Connect side.
- **Build:** clean (`GameCenterService.swift` compiles; entitlement +
  `CODE_SIGN_ENTITLEMENTS` wired in both configs). All referenced engine/store APIs
  confirmed to exist (snapshot fields, `Campaign.count`, `CyberdeckUpgrade`
  `currentLevel/maxLevel/allCases`, store progress/deck); achievement hooks land on
  the real shield events (`.missAbsorbed` + `.firewallDefused`); mode routing uses
  real `GameView` props; Flow exempt.
- **Runtime (sim, no sandbox account):** auth fires at launch (`GC Activity: Starting
  Authentication…` logged), Apple's sign-in sheet presents correctly (the `present()`
  chain-walk works), app stays alive and the declined/unauth path is a clean no-op —
  exactly the report-only design. Full score/achievement landing still needs ASC config
  + a signed-in GC account on device (by design; can't be sim-tested).
- **`docs/appstoreconnect-walkthrough.md`:** new **D6 — Game Center** section: the two
  leaderboard IDs (endless classic, daily recurring) + all 13 achievement IDs with
  suggested titles/points (565/1000) + per-achievement requirements. Flags the 13
  achievement images as the only remaining asset gap.
- **B1 done:** paid Apple Developer account active (RELEASE_PLAN updated).

## Run #75 — Monetization plan + Game Center (leaderboards & achievements) (2026-06-12)
Monetization scoped, then the engagement layer it depends on was built.
- **`docs/MONETIZATION.md` (new):** free game, **no ads**, goal = cover costs.
  Phase 1 tip jar (consumable IAPs, in-fiction tiers) + Phase 2 cosmetic packs
  (palettes/skins/synths). Hard rule: real money never touches Credits/Cyberdeck —
  cosmetics stay render-layer only. Enroll in the App Store Small Business Program
  (15%) *before* first sale.
- **`Services/GameCenterService.swift` (new):** report-only GameKit bridge (the
  engine stays the authority). Optional auth (declining changes nothing; local
  save stays the offline truth), `GKAccessPoint` on the menu hub only, score
  submission, achievement reporting with launch-local dedupe.
- **Two leaderboards:** endless (classic) + daily (recurring) — replaces the
  out-of-scope web high-score backend with Apple-hosted boards.
- **13 achievements**, all earnable, never purchasable: run (first fever, fever ×3,
  streak 25, failsafe save, power-up, 4×4 grid), landmarks (100/250/500, endless +
  daily only), meta (cores 1/5/10, maxed deck track — synced idempotently from the
  save on menu return).
- **Wiring:** event-driven reports ride the verified `GameEvent` stream in
  `GameViewModel.process(_:)` (Part 2.5 — same funnel as juice/SFX); end-of-run
  reporting sits next to `recordSession` in GameView's game-over hook with the
  final snapshot; Flow reports nothing (stake-free by design).
- **Project:** Game Center entitlement (`GRID_BREAKER.entitlements` +
  `CODE_SIGN_ENTITLEMENTS`), new Services group, pbxproj refs (GB…106–108).
- **Pending (Q8):** Xcode build + on-device pass (auth sheet, access-point
  placement vs the menu layout, banner timing), and App Store Connect Game Center
  config — IDs are listed in `GameCenterService.swift` and must match exactly.

## Run #74 — App Store screenshots re-shot on the current build (2026-06-12)
All four sets regenerated (plain + marketing, 6.9" + 6.5") so the listing shows what
1.0 actually ships: campaign per-core BEST scores, the NEXT ◆ milestone hint, the
streak system (×5) and a ×10 Fever frame.
- **Capture:** iPhone 17 Pro Max simulator (the 16 Pro Max sim no longer exists
  locally; same 1320×2868 class), driven end-to-end without the input bridge:
  temporary hooks (screen-tour task, perfect-play autoplay bot, demo-save seed
  — BEST 327 / DAILY 198 / 484 CR / campaign 6/10 / deck levels — and an 8 s fever
  window) + Simulator Cmd+S saves to the Desktop. ~20 frames captured; best five
  chosen. All hooks reverted (working tree verified identical to HEAD before the
  image commit).
- **Sets:** `iphone-6.9` (native), `iphone-6.5` (1242×2688 resize), and the
  captioned `-marketing` variants rebuilt in the Run #69 style (same five
  headlines); generator vendored as `scripts/make_marketing_screens.py`, which can
  now regenerate marketing + 6.5" sets from the plain set alone.
- **Verified:** all PNGs exactly 1320×2868 / 1242×2688; contact-sheet review of
  plain + marketing sets; repo tree clean of temp captures.
- Note: ~20 `Simulator Screenshot…` PNGs remain on the maintainer's Desktop —
  safe to delete.

## Run #73 — Promo App Preview video + release-docs sweep (2026-06-11)
Pre-release pass: Q6 + Q7 resolved by the maintainer (device passes approved).
- **App Preview rebuilt as a promo** (`docs/preview/app-preview-promo-886x1920.mov`):
  the Run #69 capture didn't meet the App Preview spec (1320×2868 @ ~50 fps — that's
  the *screenshot* size) and had **no audio track**. Rebuilt with ffmpeg to
  886×1920 @ 30 fps H.264 + AAC (~6 MB): subtle neon bloom pass (screen-blend,
  opacity 0.16) + grade tuned to keep the deep blacks, eight timed neon caption
  beats matched to the footage (BREACH THE GRID → TAP·DECODE·SURVIVE → OVERCLOCK →
  CHAIN FEVER → STREAK → THE GRID GROWS → MULTIPLY EVERYTHING → JACK IN NOW), and an
  Arcade_Fever music bed (fade in/out). Reproducible: `scripts/make_preview_promo.sh`.
- **Release docs updated:** RELEASE_PLAN A1 reopened (fuzz re-run needed after
  #69–72), A2 narrowed to the remaining walkthrough items, C2 points at the promo
  file, C1 notes the optional screenshot recapture. QUESTIONS Q6/Q7 → Resolved.
- **Verified:** ffprobe confirms 886×1920 / 30 fps / H.264+AAC / 25.49 s; caption
  timing + grade checked against extracted frames (two-pass tune: first grade washed
  the blacks purple, corrected).

## Run #72 — Tutorial streak lesson + HUD milestone hint (2026-06-11)
The two deferred items from the Run #71 walkthrough, requested by the maintainer:
- **Tutorial beat 7 (new): the streak lesson.** Level 3 now runs fever → streak →
  power-ups (beats renumbered, outro = 9). The player chains five clean decodes on a
  daemon that hops a fixed path (4→0→8→2→6) while the decode arpeggio climbs —
  hearing the real chain sound — then the exact in-game STREAK ×2 badge lands with
  the lesson line ("a miss resets it"). Level-3 card blurb updated.
- **HUD milestone hint:** `SessionSnapshot.nextMilestone` (engine-computed; nil when
  `milestoneScores` is empty) renders as a quiet "NEXT ◆ n" under the big score —
  endless/daily get a permanent goal line (ground truth 1.5), campaign/Flow are
  automatically unaffected. VoiceOver score value includes the next milestone.
- **Verified:** static diff review; no engine mechanics touched beyond the read-only
  snapshot field. Device pass rides Q6/Q7.

## Run #71 — Gameplay feedback pass: PB moment, run recap, low-RAM warning, core bests (2026-06-11)
Walked the tutorial, campaign and endless flows as a player; applied the gaps found:
- **Personal-best moment (endless/daily):** crossing your own record mid-run now fires
  a one-shot gold "▲ PERSONAL BEST / DAILY BEST" toast + sting + haptic (view-level,
  derived from the engine score vs. the stored best passed in by RootView; replays
  must beat the *new* session best).
- **Run recap on game-over (endless/daily):** "(n)s ONLINE · STREAK n · FEVER ×n" —
  engine snapshot now exposes `elapsed`, `bestCleanStreak`, `feversTriggered`.
- **Low-RAM warning:** new engine event `.ramCritical` fires once when RAM crosses
  below 25% of capacity (re-arms above 35% — hysteresis, no spam) in every drained
  mode incl. campaign's countdown; juiced as a dark two-pulse `.ramLow` SFX (recipe
  also added to `scripts/sfx_prototype.py`) + rigid haptic. Inert in Flow.
- **Campaign replay value:** per-core best scores persisted (`SaveData.campaignBests`,
  tolerant decode) and shown on the level select ("BEST n"); CORE CRACKED now shows
  the win margin ("(n)s TO SPARE").
- **Tutorial:** beat 1 now warns that mistaps drain RAM (the costliest beginner
  mistake was untaught).
- **Verified:** static review of the full diff; deterministic engine changes are
  event-only (no RNG/balance change). Xcode build + device pass pending (Q6/Q7).

## Run #70 — SFX rebuilt as a dark-cyberpunk synth family (2026-06-11)
Maintainer verdict on the old set: too musical/bell-like for the theme (Q6). All 11
SFX redesigned (D24), still fully synthesized in `AudioEngine.buildBuffers()`:
- New synthesis kit: `detSaw` (detuned dual-saw), `softClip` (tanh) and a stateful
  `LowPass` (one-pole, per-sample cutoff) alongside the existing FM helpers.
- Decode chain: dark minor run A3→D5 (octave down), closing-filter pluck; the
  filter base opens per step so a clean chain audibly brightens. Worm = dark
  slither; cache = sub-drop haul; breach = muted crack → armored kill = opening
  "zhwip" (still rises); miss = low denied buzz; bomb = sub boom + tritone saw
  crash through a slamming filter; fever = minor-arp riser (not a fanfare);
  game-over = tape-stop power-down; UI/purchase = dark ticks/stabs.
- Workflow: prototyped in Python (`scripts/sfx_prototype.py`), rendered 13 preview
  WAVs for the maintainer to audition, then transliterated 1:1 to Swift. API untouched.
- **Verified:** preview WAVs rendered + peak-checked (0.24–0.59, in line with the
  old set); Swift mirrors the auditioned math. Xcode build + on-device listen
  pending (Q6 still covers the device check).

## Run #69 — Balance audit fixes: endless ceiling + hardening (2026-06-11)
Implemented the findings of the full balance audit + code review (see D23 and the
session report `GRID_BREAKER_audit.md`; audit IDs in parentheses).
- **Endless skill ceiling (B1/B2, D23):** `GameConfig` gains drain-ramp, refill-decay
  and fever-threshold-ramp levers; `endless()` sets them (drain ×≤2.5, refill floor
  0.75, threshold 8→12). Engine applies them in `tick`/`decode`/`checkFever`;
  snapshot `comboThreshold` now reports the effective threshold so the combo meter
  tracks it automatically. Milestones extended to 16k/32k.
- **Fever density on 4×4 (B5):** `feverActiveNodes4x4 = 7` via
  `config.feverActiveNodes(for:)` — the gold flood keeps its density after escalation.
- **Spawn-debt clamp (C1):** `timeSinceLastSpawn` no longer banks while the board is
  at its ceiling — frees no burst of simultaneous spawns.
- **Worm hop/tap grace (C7):** a tap on the cell a worm vacated ≤80 ms ago counts as
  the worm hit (engine-side, deterministic) instead of a 1.5 s + streak-reset miss.
- **Hardening:** dead `hitboxPadding` removed from `GameConfig` (C2; Core is now
  CGFloat-free). `hasIslandOrNotch` cached in a `@State` instead of walking UIKit
  scenes every body evaluation (C3). Pre-run countdown task stored + cancelled on
  disappear (C4). `MusicPlayer.playCurrent` wraps past an unreadable final track,
  with a one-full-pass guard (C6).
- **Verified:** T9 lever numbers validated in the Python mirror sim before
  implementation (casual ~83 s / good ~3.3 min / strong unbounded; campaign
  unchanged: casual walls at core 9, good clears all). Xcode build + on-device feel
  pass pending (sandbox had no disk space for further sim runs this session) — Q7.

## Run #68 — New terminal icon + cleaned splash (2026-06-08)
Maintainer disliked the grid icon (wants cyber/hacky, no grid) and still saw the old
static splash.
- **New app icon:** a neon **terminal prompt `>_`** — a cyan chevron + a magenta cursor
  block on a dark radial glow (no grid). Picked from 3 concepts (Hex Core / Glitch Bolt /
  Terminal); generator at `scripts/makeicon.swift`. On-device home-screen check passed.
- **Launch splash cleaned:** removed the grid `LaunchLogo` image from
  `LaunchScreen.storyboard` (and deleted the unused `LaunchLogo.imageset`) so the static
  launch screen is just the dark GRID_BREAKER wordmark — a seamless handoff to the
  animated BootSplash, no grid anywhere.
- **Verified:** clean build; new icon on the home screen; storyboard valid.

## Run #67 — Release prep: QA sweep + privacy/support pages (2026-06-08)
First release steps (RELEASE_PLAN A1 + B3/B4). Clean build, no debug residue, v1.0/build1;
invariant fuzz 1,440 runs (all modes × starter+maxed deck) → 0 violations. Wrote
`docs/site/{privacy,support,index}.html` (self-contained neon) for the App Store Privacy +
Support URLs, with a hosting README — maintainer to set the contact email + host.

## Run #66 — Fuller Cosmetics + Cyberdeck (2026-06-08)
Pre-release polish (#2): more interesting shop content.
- **Cosmetics — palettes 5→8:** added **Ultraviolet** (violet/pink/ice, 800), **Inferno**
  (orange/red/gold, 1000), **Wireframe** (stark white/steel mono, 1500).
- **Cosmetics — trails 5→8:** **Laser** (thin gold beam, 500), **Hexbits** (cyan dashed
  squares, 650), **Voidstream** (dashed cyan diamonds, 1000).
- **Cyberdeck — upgrades 3→5** (engine-wired, deck-aware like ram/decode/shield):
  - **Fever Capacitor** (max 4, 350 CR base): Fever lasts +0.5 s/level. Engine stores a
    `feverDurationEff = config.feverDuration(for: deck)` used by checkFever + feverFraction.
  - **Salvage Protocol** (max 5, 250 CR base): +10% Credits/run/level, applied in
    `GameStore.salvaged(forScore:)` (used by every record path + the HUD preview).
- **State:** `Cyberdeck` gains `feverLevel`/`salvageLevel` (+ tolerant decode); GameStore
  `purchase` + SaveData updated. Starter deck = unchanged behaviour, so prior balance/sims
  hold.
- **Verified:** clean build; on-device — Cyberdeck shows all 5 upgrades with correct
  descriptions/costs, Cosmetics shows all 8 palettes with their swatches.

## Run #65 — Cooler app icon + animated boot splash (2026-06-08)
Pre-release polish (#1 of the maintainer's two): a much cooler logo + splash.
- **New app icon** (`AppIcon/icon1024.png`, regenerated, opaque): a glowing neon 3×3 grid
  with a "breached" magenta center cell — a white-hot core with cracks shattering out
  through the grid. Drawn via a CoreGraphics generator (script in /tmp/makeicon.swift);
  on-brand "GRID_BREAKER", reads at small sizes. On-device home-screen check passed.
- **Animated boot splash** (`BootSplash` in RootView, shown on cold launch over the menu):
  the wordmark resolves out of an RGB-split glitch with a swelling neon glow, a scanline
  sweeps down, a "SYNCING GRID… → SYSTEM ONLINE" sync bar fills, then a flash hands off to
  the menu (~1.85 s, tap-to-skip, static under Reduce Motion). A uiTap on start + a fever
  sting on ONLINE.
- **Verified:** clean build; on-device — the boot splash renders (glowing wordmark +
  subtitle + scanline + sync bar) and the new icon shows on the home screen (temp hold for
  the splash screenshot, reverted).
- Note: the storyboard `LaunchScreen` (instant system placeholder) is unchanged; the
  animated splash plays right after it.

## Run #64 — Pre-run "sync" countdown (every mode) (2026-06-08)
Maintainer: every mode should open with a cool, small, in-theme countdown.
- **`CountdownOverlay`** + `startCountdown()` in GameView: holds the engine paused through
  a 3·2·1 beat and releases it on GO. Visual: a "// SYNC" tag, a big neon mono number that
  snaps in (spring), a neon scanline sweeping down across the screen each beat, then
  "// EXECUTE / BREACH" in gold on GO. Each beat ticks `.uiTap` + a light haptic; GO plays
  `.fever` + a success haptic. Reduce-Motion shows the number statically (no sweep).
- **Every mode + retry:** fires on entry for endless/flow/daily; for campaign it follows
  the core briefing's JACK IN; and on RETRY/RECONNECT after a restart. The model is paused
  for the whole count (RAM/clock held), pause-overlay suppressed meanwhile.
- **Verified:** clean build; on-device (temp-held) — the "// SYNC" overlay + neon number +
  scanline render over the frozen board (RAM held at 20 s = paused). GO uses the existing
  unpause path. Couldn't catch the live ~2 s sequence at tool latency.

## Run #63 — Armored two-tap now rises (rewarding resolution) (2026-06-08)
Maintainer: on the armored ("shield") daemon the 2nd tap sounded lower than the 1st —
the rewarding kill should resolve *higher*. It used `.breach` (high tick 1568 Hz) then
`.decodeBig` (low 330 Hz) → a descending, anticlimactic pair.
- **Breach (1st tap)** lowered to a tense G5 (784 Hz) "crack" that sets up the kill.
- **New `.decodeArmored` (2nd tap):** a brighter, higher C6 (1046 Hz) "unlock!" — FM
  pluck + a ringing 5th bell + sparkle, with a little C5 warmth for body. The armored
  kill now uses this (the heavy low `.decodeBig` stays for the single-tap cache grab).
- Net: the two taps **rise** G5 → C6 (and 0.30 → 0.68 in level) — tension then payoff.
- **Verified:** clean build; standalone peak check (armored 0.68, breach 0.30 — no
  clipping, kill clearly above the breach). Audition by ear on device.

## Run #62 — More rewarding hit-register sounds (2026-06-08)
Maintainer: make all hit-register SFX more rewarding, on-theme. Applied mobile-game
hit-feedback principles (layered transient + tonal body + consonant bell sweetener +
bright sparkle + short shimmer tail; rising pitch on a chain; sub for weight; short
envelopes) within the existing FM "decrypt" palette. All still 100% code-synth.
- **`.decode`** (standard, chain-climbing): reworked into 5 layers — click attack, FM
  pluck, an octave **bell ring**, a high data-bit sparkle, and a shimmer tail. The rising
  run is extended to **1.5 octaves** (8 notes) so a long clean chain climbs an ever-
  brighter melody.
- **`.decodeBig`** (armored/cache kill): sub thump + fat FM body + a consonant 12th bell
  ring + bright top → a weightier, more satisfying "big unlock".
- **`.decodeWorm`**: added a bell + sparkle so the catch feels rewarding (was a bare chirp).
- **`.breach`**: FM tick + a small ring, slightly louder — a crisper shell-crack.
- **Verified:** clean build; standalone peak-amplitude check of the new synthesis — no
  clipping and a sensible balance (decode 0.80, decodeBig 0.85, worm 0.64, breach 0.33).
  Audio can't be auditioned through the tooling — confirm by ear on device.

## Run #61 — Endless depth: streak multiplier + score milestones (2026-06-08)
Built the two maintainer-approved endless improvements (engine-first, view dresses it).
- **Clean-streak base multiplier:** engine tracks `cleanStreak` (decodes since the last
  miss/expiry); `streakMultiplier` steps ×2/×3/×4/×5 at `streakTierThresholds`
  [12,30,60,120] and folds into `effectiveMultiplier` (so it stacks with Fever/Overclock).
  A miss or an expiry resets it. Long clean survival is now exponentially rewarded — sim:
  strong's endless score ~3.4k → **~14k**. New `StreakBadge` ("🔥 STREAK ×N", pulses on
  tier-up, vanishes on break); the score's bare ×N now shows only a boost *beyond* the
  streak (Fever/Overclock) to avoid a redundant double number.
- **Score milestones:** at 50/100/250/500/1000/2000/4000/8000 the engine fires
  `.milestoneReached`, granting a small RAM top-up (+2.5 s, capped) and a gold "◆ N ◆"
  landmark toast + chime. Gives the flat loop progression beats.
- **Scope:** both gated via `GameConfig` (set only in `endless()`); campaign/flow get
  empty lists → unchanged. Snapshot gains `cleanStreak`/`streakMultiplier`.
- **Verified:** clean build; endless sim (streak boosts scores, milestones don't
  over-extend); on-device (temp autoplay, reverted) — STREAK ×3 badge + score ×6 during
  Fever, grid grows at 80, RAM held by milestone top-ups.

## Run #60 — Fix menu tile label alignment (2026-06-08)
Maintainer spotted the FLOW label sitting slightly higher than CAMPAIGN/DAILY. Cause:
the ∞ glyph is shorter than the flag/calendar icons, so the icon+label VStack was
shorter and the label drifted up. Fix: gave the `MenuTile` icon a fixed `height: 24`
box so all glyphs occupy the same vertical space and every tile's label lines up.
Verified on-device (labels now share a baseline).

## Run #59 — Endless mode fine-tune (calmer, longer, capped) (2026-06-08)
Maintainer: fine-tune endless (JACK IN) — calmer start, longer loop, grid grows later,
and (open question) maybe cap the acceleration so it stays hittable.
- **New `GameConfig.endless()`** (used by both Endless and Daily via the GameView else
  branch; isolated from campaign/flow): baseSpawnInterval 0.50→**0.72**, spawnCompression
  0.0045→**0.0032**, minSpawnInterval 0.20→**0.26**, baseNodeLifespan 1.35→**1.70**,
  lifespanCompression 0.0030→**0.0021**, minNodeLifespan 0.50→**0.62**, gridEscalation
  0.40→**80**.
- **Acceleration cap (answering the open question):** the higher floors (0.26 s spawn /
  0.62 s lifespan) plateau the difficulty at a still-hittable level. In the sim a focused
  player no longer hits an impossible wall — so a long run ends on *mistakes* (a stray
  bomb / mistap), not an unwinnable speed. That's the intended endless loop.
- **Validated via headless endless sim** (survival/score/grid@ per skill): default →
  endless() shifts casual 67s→**124s** (now reaches the grid at 80), good 141s→endurance-
  limited, strong already endurance-limited; calmer 0.72 s opening, grid at ~80 not ~40.
- **Verified:** clean build; computer-use input works (drove menu/JACK IN) but a reflex
  game still can't be *played* at tool latency (the 20 s RAM drains during round-trips),
  so the sim is the pacing tool. Other loop-improvement ideas proposed to the maintainer
  (not yet built).

## Run #58 — Campaign pacing rebuilt: gentle start, gradual ramp (2026-06-08)
Maintainer: campaign still felt as fast as before — wanted the pauses between clicks
much slower (~-50%) for beginners, ramping up gradually. Also asked me to re-test via
computer-use (the input bridge was down for many runs).
- **New campaign pace curve** (`GameConfig.campaign`): replaced the flat ×1.30 multiplier
  with explicit slow base values — `baseSpawnInterval 1.10`, `minSpawnInterval 0.30`,
  `baseNodeLifespan 2.00`, `minNodeLifespan 0.60`, slower worm/fever. The per-core
  `difficultyBias` compresses both toward the floors, so the spawn pause ramps **1.10 s
  (core 1) → 0.30 s (core 10)** — early cores ~2× slower than the other modes. Budgets +
  targets unchanged from Run #55.
- **Re-validated via multi-skill sim** (per-core start→end spawn pause printed): smooth
  ramp; casual clears ~core 7, good ~core 9–10, strong all; no crashes (~1,200 plays).
- **Computer-use input bridge is BACK:** drove the real app (skip onboarding → menu →
  campaign → core 1) — taps register again. Confirmed the new budgets display and the
  early board is calm (1–2 daemons). Caveat: a reflex game can't be *played* at tool
  latency (~10 s/round-trip ≫ 2 s node lifespan → the RAM clock drains before I can score),
  so the sim remains the tool for clearability/feel; computer-use is for input/visual checks.

## Run #57 — Power-up "press to continue" + streamlined finale (2026-06-08)
Two maintainer fixes to the tutorial close.
- **Read-before-advance power-ups:** beat 7 no longer auto-advances. Tapping a pickup
  reveals its effect and shows a **NEXT POWER-UP** button (GOT IT on the last); the player
  presses to move to the next one — so each of ❄/⚡/🌀 is actually read.
- **One coherent finale (no more "JACK IN → surprise popup"):** merged the payday and the
  separate `MetaIntroCard` into a single `finale` screen — TRAINING COMPLETE + the CR
  (count-up on first launch, current balance on a Settings replay) + the three routes
  **OPEN CYBERDECK / COSMETICS / LATER** straight into the guided tour. Removed the
  `.metaIntro` screen case and the `MetaIntroCard` view; `OnboardingView` gained
  `onOpenCyberdeck`/`onOpenCosmetics`/`credits`.
- **Verified:** clean build; on-device — the finale shows CR + the three spend buttons on
  one screen, and the power-up reveal shows the effect + a NEXT POWER-UP button (temp
  forces reverted).

## Run #56 — Tutorial covers all three power-ups (2026-06-08)
Maintainer: the white lightning-bolt (Overclock) power-up was missing from the tutorial.
The new OnboardingView's beat 7 only demoed Freeze (snowflake).
- **All three power-ups now taught in turn** (beat 7): ❄ Freeze → ⚡ Overclock → 🌀 Purge,
  each rendered as the real white pickup with its glyph; tapping names the effect, then
  the next pickup appears. Progress shown as "(n/3)". L3 card blurb updated to
  "grab all three power-ups".
- **Coverage now:** decode · RAM · firewall · armored · cache · worm · Fever (interactive)
  · all 3 power-ups → payday → guided Cyberdeck/Cosmetics. (Grid 3×3→4×4 is still taught
  in-context by campaign core 9's briefing — impractical to demo in the fixed-3×3
  practice grid.)
- **Verified:** clean build; on-device the Overclock ⚡ pickup renders at beat 7 step 2/3
  (temp force reverted).

## Run #55 — Campaign ~30% slower (friendlier) (2026-06-08)
Maintainer: tune the whole campaign ~30% slower so it's friendlier to new/starting
players. Campaign cores are time-attacks, so slowing the pace alone would *hurt*
clearability (fewer scoring chances) — so the clocks were extended to match.
- **Pace:** new `GameConfig.campaignPace = 1.30` scales the campaign's node lifespan +
  floor, spawn interval + floor, worm-hop interval, and fever spawn interval (×1.30) —
  nodes live ~30% longer and the board fills less frantically across every core.
- **Budgets:** each core's `timeBudget` extended ~30% (40→52 … 54→70) so the higher
  targets stay reachable at the calmer pace; targets + difficultyBias unchanged.
- **Verified via multi-skill headless sim** (strong/good/casual reaction, 40 seeds/core,
  starter deck): all cores clearable; casual now reaches ~core 6 (was ~5), good ~core 9,
  strong finishes — a friendlier curve, calmer clear times, no crashes across the run
  (≈1,200 core-plays). Clean app build.

## Run #54 — Make the tutorial Fever interactive (2026-06-08)
Maintainer: the Fever part should be interactive (tap the actual fever squares) before
moving on to the power-up — it was a static auto-advancing celebration.
- **Interactive Fever burst:** beat 6 is now two phases. Charge as before (tap the cyan
  daemon ×4 to fill the meter) → **FEVER**: the board fills with 5 golden bonus nodes
  (`feverGold = [0,2,4,6,8]`) that the player taps to clear; only when all are cleared
  does it advance to the power-up. Replaces the 1.4 s static flash + auto-advance.
- Dropped `!feverOn` from the input guard (Fever is now a play phase, not a lock); the
  handler splits beat 6 into `!feverOn` charge and `feverOn` burst cases.
- **Verified:** clean build; on-device temp autoplay (reverted) drove charge → cleared
  all gold nodes → power-up → Payday, which is only reachable by tapping the gold nodes —
  proving the burst is interactive and gates the advance.

## Run #53 — Onboarding: one continuous flow + opaque intro (2026-06-08)
Maintainer steered the timing (overriding the earlier "Hybrid" pick): the WHOLE tutorial
should be the first thing new players do, and Settings must replay all of it (without
re-granting CR). Also: the meta intro looked unclear as a translucent overlay.
- **One continuous first-launch flow:** practice L1–3 → payday → **meta intro → guided
  Cyberdeck buy → guided Cosmetics equip → menu**, all up front. The meta intro is now a
  real screen (`.metaIntro`) reached from the onboarding `onDone`, not a deferred
  post-first-run surface.
- **Opaque intro:** `MetaIntroCard` is a full opaque screen (app background + grid
  backdrop behind it) instead of a translucent overlay over the menu — no more bleed-through.
- **Settings replays everything, no extra CR:** Settings ▸ How to Play runs the same
  chain with `showPayday=false` (no payday screen, no grant); `grantStarterCredits` is
  idempotent as a second guard.
- **Removed the deferred path:** dropped `firstRealRunDone` / `metaIntroSeen` (SaveData +
  decoder + reset), and `markFirstRealRunDone` / `markMetaIntroSeen` / `shouldShowMetaIntro`
  / the post-run trigger and menu overlay. `starterCreditsGranted` stays (one-time CR guard).
- **Verified:** clean build; on-device — the meta intro renders as a clean opaque screen
  (150 CR, three routes), no menu bleed-through (temp force reverted).

## Run #52 — Fix onboarding Level 3 input lock (2026-06-08)
Maintainer hit a hard stop: "training breaks from the Fever onwards — can't click the
fevers, and can't click the white power-up." Two bugs in `OnboardingView.handle`:
- **Input stayed locked after Fever.** The final charge tap set `feverOn = true` (for the
  1.4 s celebration) but never reset it, and `handle`'s first guard is `!feverOn` — so
  every tap afterwards (the whole power-up beat) was swallowed. Fix: reset `feverOn =
  false` just before `advance()` to beat 7.
- **The fever daemon hopped on every tap.** Each charge tap moved it to a neighbour, so
  rapid taps landed on an empty cell and did nothing ("can't click the fever"). Fix: keep
  it stationary during charging — you just tap to fill the combo meter.
- **Verified:** clean build; on-device with a temp autoplay (reverted) that drove the L3
  taps end to end — it charged Fever, tapped the power-up, and reached the Payday screen,
  which is only reachable if beat 7 accepts input again.

## Run #51 — Onboarding Phase C: guided first buy + equip (2026-06-08)
Final slice of the onboarding proposal — turns the meta-loop intro's "open shop" paths
into an actual guided first purchase + first equip. Onboarding (Acts 1/1.5/2) now complete.
- **`GuidedHint` banner:** a reusable one-step coaching banner — a cyan prompt for the
  required action that flips to a gold "done" state with a forward button once completed.
- **Cyberdeck (guided):** `CyberdeckView(guided:onGuidedDone:)` shows "Buy your first
  upgrade — RAM Buffer is a great start"; on a successful purchase the banner flips to
  "Upgrade installed! …" with a **COSMETICS →** button.
- **Cosmetics (guided):** `CosmeticsView(guided:onGuidedDone:)` shows "Equip a palette to
  recolor the whole game"; equipping any palette/trail flips it to "Looking sharp!" with
  a **DONE** button.
- **Tour wiring (RootView):** new `GuidedStep` state (`none`/`cyberdeck`/`cosmetics`).
  The MetaIntroCard's OPEN CYBERDECK starts the tour → guided buy → COSMETICS → guided
  equip → DONE → menu (COSMETICS button starts it at the equip step). BACK or the menu
  tiles keep the shops un-guided (tour only starts from the intro card).
- **Verified:** clean build; on-device — entering the guided Cyberdeck shows the prompt
  banner above the upgrades with the 150 starter CR (RAM Buffer affordable). The "done"
  states + Cosmetics banner are symmetric and build-verified (a real purchase/equip needs
  device input the sim bridge can't drive). Temp hooks reverted.

## Run #50 — Onboarding Phase B: payday + meta-loop hook (2026-06-08)
Second slice of the onboarding proposal: the starter-CR "payday" after training and the
one-time meta-loop intro surfaced after the first real run.
- **Save state (`SaveData` + tolerant decoder):** added `starterCreditsGranted`,
  `firstRealRunDone`, `metaIntroSeen` (all default false, back-compat). `resetProgress`
  preserves them (onboarding state isn't gameplay progress).
- **GameStore API:** `grantStarterCredits()` (idempotent, +150 CR, returns amount),
  `markFirstRealRunDone()`, `markMetaIntroSeen()`, `shouldShowMetaIntro`
  (= firstRealRunDone && !metaIntroSeen). `static starterCredits = 150`.
- **Payday (Act 1.5):** the onboarding outro now reveals the starter CR with a count-up
  + purchase chime (Reduce-Motion snaps to the total), then "JACK IN" → menu. Only on
  first-launch onboarding (`showPayday`); a Settings ▸ How to Play revisit shows the
  plain "training complete" outro and grants nothing.
- **Meta-loop intro (Act 2 surfacing):** after the player finishes their first CR-earning
  run (endless/daily/campaign now call `markFirstRealRunDone()`), returning to the menu
  pops a one-time `MetaIntroCard` — "You're banking CR" with OPEN CYBERDECK / COSMETICS /
  LATER (each marks it seen). Flow doesn't count (earns no CR).
- **Scope note:** this is the *surfacing* + economy; the guided in-shop first-purchase /
  equip is Phase C.
- **Verified:** clean build; on-device — the Payday screen counts up to 150 CR and the
  MetaIntroCard renders over the menu with its routing buttons (temp hooks reverted).

## Run #49 — Onboarding Phase A: 3 practice levels (2026-06-08)
First slice of the onboarding proposal (docs/ONBOARDING_PROPOSAL.md). Replaced the old
single-grid `TutorialView` with a new **`OnboardingView`** — a paced, teach-by-doing
first-time experience structured as three practice levels, each opened by a level card.
- **Level 1 · First Contact:** decode a daemon; a RAM-clock demo bar tops up when you
  decode; dodge the firewall (red = never tap).
- **Level 2 · Read the Grid:** armored (2-tap), gold data cache, hopping worm.
- **Level 3 · Overload:** chain decodes to charge a combo meter → a Fever celebration
  (board goes golden, ×2); then grab a power-up pickup (❄ Freeze).
- **Coordinator:** a 9-beat state machine (0–8) grouped into the 3 levels + an outro
  ("Training complete" → JACK IN, foreshadowing the CR/Cyberdeck/Cosmetics tour). Level
  cards gate each level's start; 3-dot level progress; SKIP at every step.
- **Wiring:** `RootView` first-launch branch + Settings ▸ How to Play now show
  `OnboardingView`; completion still flips `tutorialSeen`. No save-schema change yet
  (Phase B adds `firstRealRunDone`/`metaIntroSeen` + the starter-CR payday).
- **Scope note:** practice scenes are scripted (deterministic teaching) per the
  proposal; the meta-loop tour (Acts 1.5–2) is Phases B/C, not in this run.
- **Verified:** clean build; on-device — fresh first launch shows the Level 1 card; a
  temp beat override (then reverted) confirmed the Fever beat renders its combo meter +
  grid correctly on iPhone 16 Pro.

## Run #48 — Streak-scaled haptics + visual density (2026-06-08)
Maintainer asked to improve haptic feedback levels and visual density "during streaks /
the longer you play". Both were flat: the decode audio already climbed an arpeggio with
the chain, but haptics and per-hit juice never moved, and the only atmospheres were
Chill/Fever. Drove everything off state the engine already exposes (`combo`,
`comboThreshold`, `decodeRun`, `score`). Maintainer picked "Everything".
- **Haptics ramp with the streak:** new `Haptics.impact(_:intensity:)` and
  `decodeStreak(streak:threshold:fever:)` — a nimble decode climbs generator *bands*
  (light → medium → rigid) as the chain nears the fever threshold (felt "notches") with
  a smooth intensity ramp inside each band; Fever decodes hit sharp + full; armored/cache
  also sharpen in Fever. Wired in `GameView.process`.
- **Bursts scale with the streak:** `JuiceEffect.intensity` (heat 0…1) grows the particle
  count (12→26, capped), flash peak, "+N" pop size + glow, and spread — so a long chain
  visibly throws more energy. Reduce-Motion still snaps it all off.
- **"Heating up" colour:** standard/worm pops blend cyan/green → gold as the chain nears
  fever (`Color.blend` helper), telegraphing the build-up.
- **Longevity ambience:** new `HeatVignette` warms the arena edges as score climbs
  (endless/daily; dampened during Fever); behind the grid + text, low opacity.
- **Mid-streak momentum:** new `StreakPulseBorder` gives a brief gold edge pulse at
  chain milestones (every 4, excluding the fever-trigger hit) — momentum you see building
  before Fever. Reduce-Motion → no pulse.
- **Verified:** clean build; on-device (temp autoplay hook + force-endless, then reverted)
  confirmed the scaled gold burst, "+N" pop, and heat vignette render correctly with no
  layout regression. Haptics aren't observable in the simulator — sound by construction,
  best felt on hardware.

## Run #47 — Accessibility pass (VoiceOver) (2026-06-08)
Added VoiceOver support across the navigable UI (the last code-quality gap before 1.0;
no Apple account needed). Reduce Motion was already honoured app-wide; this run covers
labels/values/traits and hides decorative layers.
- **Menus/shops/settings (fully VoiceOver-usable now):**
  - RootView: stat chips read "label: value"; MODES/TERMINAL tiles and utility buttons
    get explicit labels; decorative `GridBackdrop` hidden.
  - Cyberdeck `UpgradeRow`: description combined into one element; buy button reads
    "Upgrade X, costs N credits" / "X fully upgraded", with a "Not enough credits" hint;
    level pips hidden.
  - Cosmetics `PaletteRow`/`TrailRow` and campaign `CoreRow`: collapsed to one element
    each with name + a state value (Equipped/Owned/cost · Cleared/locked/target) and
    `.isSelected` when equipped/cleared.
  - `HighScoresView` rows read "Rank N, S points" + date; stat boxes read label+value.
  - Settings: toggles expose On/Off as a value + toggle hint + `.isSelected`; volume
    sliders are adjustable with a "N percent" value; action-row chevrons hidden.
- **In-game HUD:** SCORE and RAM are queryable status elements ("Score: N",
  "RAM remaining: N percent"); campaign target bar reads "core name: S of T". Decorative
  layers hidden from VoiceOver (Chill/Fever atmosphere, Data-Core visualizer, tap-trail,
  GridPowerFX, notch IslandFrameRow, EffectsLayer). Pause button labelled.
- **Grid cells:** each carries a concise label (Daemon / Armored daemon / Firewall — do
  not tap / Data cache / Worm daemon / Power-up / Bonus node / Empty) so the board is
  perceivable on exploration — though live play stays a visual reflex challenge by nature.
- **Verified:** clean build; fresh launch renders intact (no layout shift from the
  modifiers; tutorial now shows 5 step-dots). Modifiers are layout-neutral; full
  VoiceOver rotor confirmation is best done on-device with VoiceOver enabled.

## Run #46 — Worm distinction + power-ups taught separately (2026-06-08)
Maintainer flagged the green worm as "generic" — unsure it even works, and no
visual/auditory difference from standard daemons — and asked that every power-up be
explained separately in the tutorial.
- **Verified the worm works** (it was doubted): it's a `.wormDaemon`, not a power-up —
  every `wormHopInterval` (0.55 s) it hops to a random adjacent free cell, lives ×1.25
  longer, worth `scoreWorm`, one tap to decode wherever it lands. Headless sim (worm
  chance forced high, zero taps, 8 s) → **18 autonomous hops across 10 worms. PASS.**
- **Auditory distinction:** worm decode now plays a dedicated `AudioEngine.SFX.decodeWorm`
  — a wet, vibrato "slither" chirp that sweeps upward — instead of the standard `.decode`
  pentatonic blip. Wired in `GameView.process` (own `.wormDaemon` case). The tutorial
  worm step plays it too.
- **Visual distinction:** the worm sprite is now `WormNodeSprite` — the acid-green
  squiggle with a continuous gentle squirm (rotate ±7° + sway), Reduce-Motion-gated, so
  it reads as alive/moving at a glance vs. the static cyan daemon.
- **Tutorial — worm is now hands-on:** new interactive step (3 of 5) where a green worm
  actually hops between cells on a 0.7 s timer and you must tap it wherever it lands.
- **Tutorial — power-ups each get their own line:** the recap was two lumped rows; it's
  now a scrollable list with separate rows under a "POWER-UPS" divider — ❄ Freeze (pauses
  the RAM clock + decay), ⚡ Overclock (×2 score), 🌀 Purge (wipes all bombs) — plus
  separated Gold-data-cache and Green-worm rows.
- **Verified:** clean build; engine sim (above); on-device screenshot of the recap shows
  all rows + the divider rendering and scrolling correctly on iPhone 16 Pro.

## Run #35 — Campaign overhaul: granular mechanics + briefings + longer (2026-06-08)
Reworked the 10-core campaign (D21) per the maintainer's steer (keep 10 cores, longer
mostly via targets).
- **Per-core feature gates:** `DataCore` gains armored/bombs/fever/cache/worm/
  powerKinds/grid4x4 + a `CoreFeature` briefing. `GameConfig.campaign(for:)` builds the
  config from them (time-attack base, D13); new `GameConfig.powerUpKinds` gates which
  power-ups can spawn (engine spawn uses it). Schedule: 1 standard → 2 armored →
  3 bombs → 4 fever → 5 cache → 6 worm → 7 freeze → 8 overclock+purge → 9 grid 4×4 →
  10 finale.
- **Longer via targets:** targets 25→200 (was 15→130), budgets 40→70 s, sized so a
  strong player clears within the clock.
- **Briefings:** `CoreBriefingOverlay` explains the new mechanic before the run and
  **holds the RAM clock** until JACK IN (model paused; pause overlay suppressed while
  it's up). Shown only while the core is uncleared (via `campaignProgress`) → explained
  when new, not on every replay.
- **Verified:** clean build; headless sim — gating correct (each core spawns only its
  unlocked types; power-up kinds gated; 4×4 only from core 9) and all 10 cores
  clearable by a realistic strong player within budget; on-device — level select shows
  the new targets/times, core 1 briefing ("DECODE THE GRID", target 25) held the clock
  at 40 s, JACK IN started the run.

## Run #45 — Diagnose the Simulator-input issue (2026-06-08)
Investigated why computer-use taps stopped registering (blocking on-device verification
for several runs). Root causes found (none in the app):
1. **`left_click` mis-maps Y → 0** — a click at `(685, 383)` left the cursor at
   `(685, 0)` (verified via `cursor_position`); `mouse_move` maps correctly.
2. **Synthetic clicks aren't delivered as iOS touches** — even `mouse_move`
   (cursor verified on-target) + `left_mouse_down`/`up` doesn't register, on small or
   large targets. A degraded computer-use→Simulator input bridge.
3. **Multiple booted sims** — the window showed iPhone 16 Plus while builds targeted
   iPhone 16 Pro (`45DA7B07`); clicks hit the wrong device.
Tried and did not fix: Simulator.app restart, single-device, move+down/up. The app
itself is healthy (renders fine via `simctl io screenshot`; engine fuzz clean).
Wrote `docs/VERIFICATION_NOTES.md` with the reliable workflow (single device + simctl
screenshots + temporary in-code autoplay hooks).

## Run #44 — QA backlog: toast, tutorial, stats (2026-06-08)
Built the quick wins surfaced by the Run #43 audit.
- **GRID EXPANDED toast:** `GameViewModel.gridExpandedSeq` (bumped on `.gridExpanded`)
  drives a brief cyan pill toast in `GameView`, positioned up by the core (clear of the
  grid), ~1.6 s, reduce-motion aware — the 4×4 milestone now reads on-screen (was
  audio+haptic+animation only).
- **Tutorial:** added a "Special daemons" recap row (gold cache = bonus, green worm =
  hops) so the how-to covers the new node types too (power-ups were added in Run #41).
- **TOP RUNS stats:** `HighScoresView` gains a cross-mode header — DAILY BEST +
  CAMPAIGN x/N stat boxes above the endless leaderboard (was endless-only).
- **Skipped:** Flow session summary — a forced summary conflicts with Flow's
  leave-whenever, no-pressure design (D15).
- **Verified:** clean build. On-device visual confirmation still blocked by the
  computer-use→Simulator input quirk (taps not delivered, persists across boots — not
  the app); changes are standard SwiftUI overlays/rows.

## Run #43 — Full-mode QA pass (fuzz + review) (2026-06-08)
A "playthrough of all modes" done as a rigorous audit (live tap-through was blocked by
the same computer-use→Simulator input quirk).
- **Engine fuzz:** a chaotic player (random taps incl. bombs/empty/spam, power-up grabs)
  over endless + flow + all 10 campaign cores, ~thousands of steps × many seeds, with
  per-step invariants (cellIndex in range, no duplicate cells, nodes ≤ cells, RAM finite
  & ≤ capacity, score ≥ 0, multiplier ≥ 1, feverFraction ∈ [0,1]). **All held — no
  crashes, no violations.** Plus targeted checks: overclock×fever ⇒ ×4; Flow never ends,
  RAM never drains, no bombs.
- **Code review of every mode flow** (RootView routing, record-once on game-over,
  campaign NEXT-CORE advance + briefing gating, daily replay seed, restart resets,
  pause/briefing overlay gating): no functional bugs. Only 2 force-unwraps, both
  AVFoundation calls with known-valid inputs (safe).
- **Fix applied:** Cyberdeck upgrade buy-button now has a ≥44 pt tap target
  (`frame(minHeight: 44)` + `contentShape`), matching the Run #42 menu fix. (Cosmetics
  rows are already whole-row buttons.)
- **Improvement backlog (not done, noted for later):** explain worm/cache in the
  tutorial too (only power-ups added so far); an on-screen "GRID EXPANDED" toast for the
  4×4 milestone (currently audio+haptic+animation only); a unified stats view (TOP RUNS
  is endless-only); a Flow session summary.

## Run #42 — Utility buttons ≥44 pt tap target (2026-06-08)
The menu's TOP RUNS / SETTINGS utility icons had a sub-44 pt hit area (below Apple's
HIG minimum) — fiddly to tap. Gave `utilityButton` a `frame(minWidth: 72,
minHeight: 44)` + `contentShape(Rectangle())` so the whole padded area is tappable.
- **Verified:** clean build. On-device tap confirmation was blocked by a computer-use
  → Simulator input-delivery quirk (a fresh launch stopped responding to synthetic
  clicks even on the large primary button — a tooling issue, not the app: it renders
  fine and `start()` is unchanged). The fix is a standard frame/contentShape change.

## Run #41 — Audio freeze/music fix + tutorial power-ups (2026-06-08)
Two reported issues.
- **Freeze-on-button + music drops (fix):** `RootView` called `AudioEngine.resume()`
  on **every** screen navigation (`.onChange(of: screen)`), and `GameView.onAppear`
  again. `resume()` toggles the audio session and can restart the `AVAudioEngine` on
  the main thread — doing that per-tap caused the intermittent hang, and the engine
  restart interrupted the music player (whose `isPlaying` then read stale-true, so it
  never restarted → permanent silence). Removed both per-navigation calls; `resume()`
  now fires only from the three resilience observers (interruption-end / config-change
  / foreground). Added a reentrancy guard so a restart can't loop via the config-change
  notification. Made `MusicPlayer.resume()` robust: force `play()` (no-op if already
  playing) and recreate the player only if that fails — no longer trusts `isPlaying`.
- **Tutorial power-ups:** added a recap row — "Grab power-ups: ❄ Freeze, ⚡ Overclock
  (×2), 🌀 Purge bombs" — so the how-to covers them.
- **Verified:** clean build. The freeze was intermittent/device-specific (not
  reproducible on the simulator); the fix removes its trigger and is logic-only. The
  tutorial row is a trivial addition to the existing recap (on-device walkthrough not
  captured — the SETTINGS→tutorial path is gated behind a sub-44pt utility button that
  computer-use couldn't reliably tap).

## Run #40 — Campaign difficulty re-tune (2026-06-08)
Data-driven re-tune of the 10-core ladder via a **multi-skill** headless sim
(strong 0.20 / good 0.30 / casual 0.42 reaction, seed-averaged, starter deck).
- **Problem (old curve):** strong players coasted (won every core in 30–50% of the
  budget), yet a "good" player cleared only 4/10 and "casual" 2/10 — most players
  never reached the worm/power-up cores the campaign exists to teach. Late cores were
  pinned at the difficulty floor (bias ≤700 → 0.5 s lifespans) which slow players
  can't physically keep up with.
- **Fix:** much gentler early/mid pace (`difficultyBias` 20→700 ⇒ 0→300), moderately
  lower targets (25→200 ⇒ 22→180), and **tighter late budgets** for tension.
- **Result (sim):** everyone clears the intro (1–4); casual ~core 5, good ~7–8,
  strong finishes with the **finale a real test (~80%)**; clear times ramp 10s→29s.
  Cyberdeck upgrades (not in the sim) make it more forgiving in practice.
- **Verified:** clean build; multi-skill sim shows a smooth gradient (no
  impossible-for-everyone or trivial-for-all cores). Human playtest still pending.

## Run #39 — App Store readiness pass (2026-06-08)
Fixed the in-repo blockers; documented the account/store steps in
`docs/RELEASE_CHECKLIST.md`.
- **Icon opaque:** the 1024 app icon had an alpha channel (App Store rejects that) —
  flattened it over the dark bg via a CoreGraphics/ImageIO script (hasAlpha → no),
  identical appearance. Single-size 1024 → Xcode generates all sizes.
- **Version 1.0** (`MARKETING_VERSION` 0.14 → 1.0, build 1) — About screen reflects it.
- **Export compliance:** `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (verified
  `ITSAppUsesNonExemptEncryption: false` in the built Info.plist) → no per-submission
  prompt.
- **iPhone-only:** `TARGETED_DEVICE_FAMILY` "1,2" → "1" (the design is iPhone-portrait).
- Confirmed fine: launch screen, portrait/status-bar, iOS 17 target, bundle id,
  signing team set, no privacy-sensitive APIs.
- **Verified:** clean build; built Info.plist shows v1.0 + encryption=false + launch
  storyboard; icon generates from the opaque source.
- **Remaining (maintainer + Apple acct, see checklist):** €99 dev program, music
  licensing, App Store Connect record, privacy "data not collected" + policy URL,
  screenshots, store copy, pricing, archive & submit.

## Run #38 — Purchase reward feedback (2026-06-08)
Buying in a shop now feels rewarding on completion (visual + audio).
- New `.purchase` SFX: a bright ascending FM-bell arpeggio ("acquired").
- Shared `celebratePurchase(_:_:)` helper + `PurchaseFlash` overlay: a gold
  "ACQUIRED · <item>" card (checkmark seal, glow, scale-in), success haptic, and the
  chime — auto-dismissed (~1.3 s). Wired into Cyberdeck (upgrade Lv) and Cosmetics
  (palette/trail) on a *successful* buy only.
- **Verified:** clean build; on-device — buying a trail deducted Credits, equipped it,
  and showed the gold ACQUIRED flash (captured with a temporarily lengthened window;
  the live 1.3 s flash kept being missed by screenshot latency). Temp cosmetic
  price/flash-duration overrides reverted.

## Run #37 — Main menu redesign (hierarchy + grouping) (2026-06-08)
Reworked the menu from 7 equal rainbow buttons into a clear hierarchy (D22).
- **Primary CTA:** a large filled JACK IN (play icon + "ENDLESS").
- **Groups:** MODES (Campaign/Flow/Daily — cyan icon tiles) and TERMINAL
  (Cyberdeck/Cosmetics — gold icon tiles), each with a section label; TOP RUNS +
  SETTINGS demoted to small dim utility icons.
- **Stat chips:** BEST / DAILY (when set) / CREDITS at a glance.
- **Restrained, meaningful color:** cyan = play, gold = spend, dim = utility (was a
  different hue per button). New `MenuTile` + `sectionLabel`/`statChip`/`utilityButton`
  helpers.
- **Verified:** clean build; on-device — the new layout renders cleanly (JACK IN
  primary, MODES + TERMINAL tile groups, stat chips, utility icons), fits without
  scrolling.

## Run #36 — Power-up feedback reworked to be diegetic (2026-06-08)
The Run #34 centered banner overlapped the grid and got in the way. Replaced it with
feedback expressed **on the grid itself** (adds to play, never blocks it).
- **Removed** `PowerUpFlash` (the big banner) + the full-screen freeze tint.
- New `GridPowerFX` overlay scoped to the board: **Freeze** frosts it (icy fill +
  border + glow) while the nodes are already stopped; **Overclock** energizes it with a
  pulsing gold edge; **Purge** fires a one-shot cyan shockwave ring. Non-interactive,
  never covers the nodes. Duration effects read from `freezeActive`/`overclockActive`;
  purge is triggered one-shot from the collect event (`purgeTrigger`). Reduce-motion
  aware. The Data Core label (FREEZE/OVERCLOCK) stays as the unobtrusive name.
- **Verified:** clean build; on-device — collecting Overclock glowed a gold energized
  border around the grid (with ×2 score); Freeze froze the board (nodes held, RAM held,
  icy frost). Temp spawn/RAM/duration boosts + autoplay reverted.

## Run #34 — Power-up collect flash (2026-06-08)
Power-ups now announce their effect clearly the instant they're tapped.
- New `PowerUpFlash` overlay: a bold, color-coded burst (icon + name + effect) —
  ❄ TIME FREEZE "RAM + GRID FROZEN" (ice blue), ⚡ OVERCLOCK "SCORE ×2" (gold),
  🌀 PURGE "FIREWALLS CLEARED" (magenta). Centered, transient (~1.1 s), non-interactive,
  reduce-motion aware.
- Driven from the engine event: `GameViewModel` exposes `powerUpFlashKind` +
  `powerUpFlashSeq` (bumped on `.powerUpCollected`); the view shows the flash on the
  seq change and clears it after the window (guarded so a newer pickup supersedes).
  The ongoing core label (FREEZE/OVERCLOCK) + frost overlay remain as the during-effect
  indicators.
- **Verified:** clean build; on-device — collecting a power-up showed the OVERCLOCK /
  SCORE ×2 flash over the core (with the ×2 score + core label). Temp spawn/RAM/flash
  boosts + autoplay reverted.

## Run #33 — Daily challenge seed (gameplay 4/4) (2026-06-08)
The last of the four gameplay additions. A shared, deterministic daily run.
- **Seed:** `RootView.today()` → a "yyyy-MM-dd" key + a date-derived seed
  (`y*10000+m*100+d`); every player gets the same board on a given day (D20). Endless
  rules + all the new mechanics.
- **`GameView`** gained `seed:`/`daily:` params (endless path uses `seed ?? freshSeed`);
  replays reuse the fixed seed so it stays today's board. `GameOverOverlay` shows
  "DAILY CHALLENGE" + "NEW DAILY BEST".
- **Persistence:** `SaveData.dailyBestScore`/`dailyBestDay` (+ tolerant decode);
  `GameStore.recordDaily`/`dailyBest(forDay:)` — pays Credits (shared economy), tracks
  the day's best, but stays out of TOP RUNS. Resets with progress.
- **UI:** gold DAILY HACK menu button; the title shows "DAILY n" when today's best > 0.
- **Verified:** clean build; headless sim — same seed → identical board sequence,
  different day → different board; on-device — DAILY HACK launches the seeded run, menu
  button + best line render.

## Run #32 — Independent music/SFX volume (2026-06-08)
- **Per-channel volumes:** `AudioEngine.sfxVolume` (applied to the SFX player-node
  pool) and `musicVolume` (applied to `MusicPlayer` live + to each new track).
  SFX default 0.7 (a bit quieter than before, per request); music 0.85. The master
  SOUND toggle still gates everything.
- **Settings:** two new neon sliders (MUSIC, EFFECTS) with live % in the SYSTEM
  section (`SettingSliderRow`); EFFECTS previews a decode tick on release. Persisted
  via `SaveData.musicVolume`/`sfxVolume` (+ tolerant decode), applied at launch, and
  preserved across a progress reset.
- **Verified:** clean build; on-device — Settings shows MUSIC 85% / EFFECTS 70%
  sliders; dragging EFFECTS updated to 22% live (binding → store + engine).

## Run #31 — Power-up pickups (gameplay 3/4) (2026-06-08)
Rare power-up pickups, all three kinds. Modeled as one `.powerUp` NodeType carrying
a `PowerUpKind` (timeFreeze / overclock / purge), so the per-type switches stay thin.
- **Time-freeze:** freezing the *simulation clock* pauses node expiry + worm hops for
  free; RAM drain and the fever countdown are gated on it explicitly. Spawns continue
  → a safe scoring window. `freezeDuration` 3 s.
- **Overclock:** a timed extra ×N. `effectiveMultiplier` = fever × overclock, used by
  `decode()` and exposed as `snapshot.scoreMultiplier` (so the score "×N" reflects
  it). `overclockDuration` 4 s, `overclockMultiplier` 2.
- **Purge:** instantly clears all firewall bombs.
- Pickups carry no score and don't touch combo (handled via `applyPowerUp`, separate
  from `decode`). Short-lived; a missed one expires harmlessly. Spawn-rolled after
  worm (chance 0.04, random kind). Disabled in campaign + Flow.
- **Snapshot:** added `freezeActive`/`overclockActive`. **Juice:** white "special
  pickup" sprites (snowflake/bolt/wind), the Data Core label shows FREEZE/OVERCLOCK,
  a light frost overlay while frozen, success haptic + sting on pickup.
- **Verified:** clean build; headless sim — overclock ×2 (decode pays score·mult),
  freeze holds RAM constant with zero expiries, purge clears bombs → 0. On-device:
  white pickup sprites render distinctly; collecting showed the FREEZE label + "×2"
  score with RAM held. Temp spawn/RAM/duration boosts + autoplay reverted.

## Run #30 — Worm daemon (gameplay 2/4) (2026-06-08)
A moving target: a "worm" that scuttles to an adjacent free cell on a timer.
- **`NodeType.wormDaemon`** (1 tap, harvestable, penalizes on expiry like a daemon).
  `GridNode.cellIndex` is now `var` + new `var nextHopAt`; `GridEngine.gridSize`
  already mutable. (The 4×4 escalation remap was simplified to mutate `cellIndex`
  in place now that it's settable.)
- **Engine:** spawn roll adds worm (chance 0.08) with a slightly longer life
  (`wormLifespanFactor` 1.25) + a hop schedule; a new tick step relocates each worm
  to a random orthogonal free neighbor every `wormHopInterval` (0.55 s) via
  `adjacentCells(_:)`; one-tap decode pays `scoreWorm` (2). Disabled in
  campaign + Flow.
- **Juice:** fixed acid-green `NeonTheme.worm` + `scribble.variable` sprite (distinct
  from the other daemons); green "+2" pop, nimble standard decode sound. The grid
  transition is now keyed on id+cell so a hop animates (the worm dissolves to its
  new cell).
- **Verified:** clean build; headless sim — 43 hops, **every** one to an orthogonal
  neighbor; worm decodes in one tap for score 2. On-device: green worm sprites read
  distinctly and visibly relocated between frames. Temp spawn boost reverted.

## Run #29 — Bonus "data cache" node (gameplay 1/4) (2026-06-08)
First of four requested gameplay additions. A rare, short-lived golden bonus node.
- **`NodeType.dataCache`** (1 tap, harvestable). New `penalizesOnExpiry` property:
  only real daemons cost you on timeout — a bomb (always) and a **missed cache** now
  expire harmlessly (a missed bonus isn't a failure). Engine expiry loop uses it.
- **Config:** `scoreCache` (5), `bonusCacheDecode` (2.5 s RAM), `cacheSpawnChance`
  (0.05), `cacheLifespanFactor` (0.65 → a fast grab). Carved out of the spawn roll
  after firewall/armored. Disabled in campaign (`cacheSpawnChance`/`bonusCacheDecode`
  = 0 — cores are sim-tuned); allowed in endless + Flow.
- **Engine:** spawn roll + shorter cache lifespan; `decode()` pays cache score+RAM;
  one-tap clear via the standard path (counts toward combo).
- **Juice:** gold `square.stack.3d.up.fill` sprite (ringed "grab me"); decode shows
  the gold "+5" pop with the heavier `decodeBig` sound + medium haptic (no hit-stop).
- **Verified:** clean build; headless sim — cache payout exact (score == std·1 +
  cache·5) and a missed cache emits no `.nodeExpired`, no combo break, no RAM
  penalty; on-device the gold cache sprite reads as a distinct prize. Temp
  spawn/lifespan boost (for the screenshot) reverted.

## Run #28 — 4×4 grid escalation (Q2) (2026-06-08)
Endless now escalates 3×3 → 4×4 mid-session for a late-game difficulty step.
- **Config:** `GameConfig.gridEscalationScore` (default 40; nil in `campaign()` and
  `chill()` — those stay a fixed 3×3). Tunable in one place.
- **Engine:** `gridSize` is now `private(set) var`; `checkGridEscalation()` (run in
  the decode path alongside checkFever/checkTarget) grows the grid once score ≥
  threshold and **remaps live nodes** to the same top-left cells
  (`old/3*4 + old%3`) preserving `id` + `hitsRemaining`, so they slide into place as
  a 4th column/row appears rather than jumping. New `GameEvent.gridExpanded`.
- **Feel:** `gridExpanded` → success haptic + the fever sting; the board tweens its
  resize (`.animation(value: gridSize)`, reduce-motion aware). `targetActiveNodes`
  already scales with `cellCount`, so 4×4 naturally allows a fuller board.
- **Verified:** clean build; headless perfect-player sim — expanded at score 41,
  grew to 4×4, played on to 65; remap formula unit-checked = [0,1,2,4,5,6,8,9,10].
  On-device (temp low threshold + autoplay, both reverted): the 4×4 renders cleanly,
  16 square cells fit the board, HUD/score/Data Core intact.

## Run #27 — Full SFX set matched to the FM theme (2026-06-08)
Brought the remaining SFX into the Run #26 FM "decrypt" family (asset-free synth):
- **miss** = low downward-bending FM "denied" blip (G3, subharmonic ratio) + grit,
  replacing the dull square.
- **bomb** = sub-boom + a dissonant **tritone** metallic FM crash + noise blast —
  heavier/more digital than the old rumble.
- **fever** = bright ascending FM arpeggio (C5 F5 A5 C6) via `fmBlip`, the decrypt
  "breaking open."
- **gameOver** = slow descending FM minor fall (carrier + saw).
- **uiTap** = a clean, quiet member of the FM family (was a bare sine).
- decode/decodeBig/breach unchanged (Run #26). Shared FM timbre + A-minor tonality
  so the whole set sits together.
- **Verified:** clean build; headless render of the exact synth for the full set to a
  WAV demo (peak 0.805, no clip), auditioned by the maintainer. (On-device mix vs.
  music = a human listen per Q6.)

## Run #26 — Themed hit-register SFX + combo arpeggio (2026-06-08)
Redesigned the decode hit sounds (user: make them more appealing / on-theme). Still
asset-free synthesis (€0 ethos, D12) — no sourced clips.
- **New `fmBlip` synth helper**: a carrier phase-modulated by a sibling oscillator
  with a quick downward pitch-glide → a clean metallic/digital "decrypt" timbre,
  far more musical than the old raw chirp.
- **Standard decode** = click transient (tactility) + FM body + high sparkle.
  **Armored kill (`decodeBig`)** = sub-thump + fatter FM body + click (distinct
  weight). **Breach** = a clean metallic FM tick. Miss/bomb/fever/gameOver/uiTap
  left as-is.
- **Combo arpeggio:** `decode` is pre-rendered at a rising A-minor-pentatonic run
  (A4→A5); `AudioEngine.play(_:step:)` clamps to the top. `GameViewModel.decodeRun`
  advances per decode and resets on a broken chain (miss / expiry / bomb) and on
  restart — so a streak audibly climbs and resets exactly with the engine's combo
  (fed from real state, per the juice skill).
- **Verified:** clean build; headless render of the exact synth to a WAV demo
  (peak 0.797, no clip) auditioned by the maintainer and approved. (Final on-device
  mix still a human listen per Q6 — simulator audio isn't CLI-capturable.)

## Run #25 — Branded launch screen (ship-prep) (2026-06-07)
Replaced the blank auto-generated launch screen (a black flash) with a branded one.
- **`LaunchScreen.storyboard`**: dark background (0.02,0.02,0.05 — the Classic
  palette bg) with a centered vertical stack: the neon app-logo image, the cyan
  "GRID_BREAKER" wordmark (Menlo-Bold) and the magenta "// netrunner reflex hack"
  subtitle. Static (OS-rendered pre-launch), so no glow animation — the baked icon
  art carries the neon.
- **Reused art:** new `LaunchLogo.imageset` inside `Assets.xcassets` (a folder
  reference, so no project change) copies the existing `icon1024.png` — one source
  of truth for the mark.
- **Wiring:** added the storyboard fileRef/buildFile (ids `0104`/`0105`), to the
  group + Resources phase, and switched `INFOPLIST_KEY_UILaunchScreen_Generation`
  → `INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen` (both configs).
- **Verified on-device (iPhone 16 Pro sim):** captured the launch screen (held it via
  a temporary `Thread.sleep` in the App init, since it otherwise vanishes the instant
  the first frame renders) — icon + wordmark + subtitle centered on the dark bg, on
  brand. Temp delay reverted; final build clean.

## Run #24 — Tap trails reworked into connecting beams (2026-06-07)
The old trail dropped an isolated dot at each finger sample — in a tap game that
read as scattered dots, not a trail. Reworked into a neon "data stream".
- **`TrailLayer` is now a `Canvas`** that connects each successive tap/drag sample to
  the previous one with a fading beam (glow pass + crisp pass) and a node at each
  sample. Because consecutive *taps* are connected, a tap-only game leaves a real
  trail that jumps between the cells you hit (verified: a Z-beam across the grid).
  Drives its own `TimelineView(.animation)` so the beam recedes smoothly between
  samples (the old per-dot fade only updated when points were added/pruned). Lifetime
  0.45 → 0.6 s for better tap-to-tap connection.
- **Skins gained beam identity:** `TrailSkin` now has `lineWidth` + `dashed` (plus
  shared `beamStyle(width:)` and `dotPath(at:size:)` Canvas helpers). Comet = smooth
  cyan; Pixel Dust = segmented magenta; Spark = thin gold; Plasma = thick magenta.
- **Cosmetics preview rebuilt:** `TrailSwatch` draws a clean static mini-beam (3
  nodes, brightening toward the lead) with the *same* renderer/skin params instead of
  the old four fading dots — each skin now previews its real look.
- **Verified on-device (iPhone 16 Pro sim, computer-use):** all five previews render
  as distinct clean beams; in-game, five taps drew a connected glowing beam between
  the cells. Temp lifetime bump (for the screenshot) reverted.

## Run #23 — Settings / About screen (ship-prep) (2026-06-07)
First ship-prep slice: a real Settings hub, reachable from a new ⚙ SETTINGS menu
button (which replaces the loose SOUND + TUTORIAL menu buttons — consolidated).
- **`SettingsView`** (`MenuViews.swift`), neon-styled sections: SYSTEM (SOUND +
  new HAPTICS toggles), ACCESSIBILITY (REDUCE MOTION read-only status, "follows
  iOS"), HELP (HOW TO PLAY → tutorial), DATA (RESET PROGRESS, guarded by the
  existing `ConfirmDialog`), and an ABOUT block (title + version from the bundle +
  tagline). Reusable row views: `SettingToggleRow`/`SettingInfoRow`/
  `SettingActionRow` + shared `SettingRowBackground`.
- **Haptics toggle:** `Haptics.enabled` static gate (mirrors `AudioEngine.enabled`/
  `NeonTheme.current`), checked in `impact/error/success`; persisted via
  `SaveData.hapticsEnabled` (+ tolerant decode) and applied at launch in
  `RootView.onAppear`.
- **Reset progress:** `GameStore.resetProgress()` wipes gameplay state (Credits,
  upgrades, scores, cosmetics, campaign) to `.empty` but **keeps preferences**
  (sound/haptics) and `tutorialSeen`; the view re-applies palette/trail globals
  afterward so the look doesn't desync.
- **Version:** bumped `MARKETING_VERSION` 0.1 → 0.14 (both configs) to match the
  changelog; the About block reads it from `CFBundleShortVersionString`.
- **Verified on-device (iPhone 16 Pro sim, computer-use):** menu shows the single
  SETTINGS button; Settings renders all sections + "v0.14 (build 1)"; SOUND toggled
  ON→OFF (pill + icon update); RESET PROGRESS → red confirm → reset ran cleanly,
  preserved SOUND=OFF/HAPTICS=ON, and BACK returned to the menu with no tutorial
  re-trigger.

## Run #22 — Score/visualizer layout pass (2026-06-07)
Three requested adjustments:
- **Uniform menu buttons.** `TerminalButton` gained a `wide` flag (fills the
  container via `maxWidth: .infinity`); all six main-menu buttons use it inside a
  `maxWidth: 260` column, so they're one consistent width.
- **Flow uses the Data Core.** The centerpiece arc was previously blank in Flow.
  Removed the `!chill` guard so the arc renders there too, fed by a new
  `coreProgress`: a repeating "combo ring" (fills every `comboThreshold` decodes,
  shows full on completion, then resets) — the core now reacts to play even with no
  goal or Fever.
- **Big score above the visualizer (all modes).** New `BigScoreView` (SCORE label +
  ~46pt number with a numeric-roll transition + gold ×N + shield charge) sits
  directly above the Data Core. Removed the small top-left SCORE block from
  `IslandFrameRow` (now just RAM time / ⌁ FLOW flanking the Island) and the inline
  SCORE row from the flat-top HUD (`showInlineScore` param dropped).
- **Fever now lives in the core, not a banner.** The old `FeverBanner` overlapped
  the new centered score, so it's gone: during Fever the Data Core arc drains with
  the burst timer (`coreProgress` returns `feverFraction`) over its gold surge +
  bolt + "FEVER" label, and the score shows the gold ×N — one dominant moment, no
  collision. `FeverBanner` deleted (dead code).
- **Verified on-device (iPhone 16 Pro sim, computer-use):** menu buttons uniform;
  endless shows big score + CHARGE arc; Fever surges gold with a draining arc and
  gold ×2 score (no overlap); Flow shows the big score + a filling/cycling FLOW
  ring. Temp autoplay hook reverted.

## Run #21 — Tap-trail skins (2026-06-07)
- New cosmetic: a neon trail that follows the finger. `TrailSkin`/`TrailSkins`
  catalog (None, Comet free; Pixel Dust/Spark/Plasma 400–900 CR) — colors resolve
  through the equipped palette. `TrailSkins.equipped` static (set at launch + on
  equip, mirrors `NeonTheme.current`).
- `TrailLayer` renders a fading comet of dots (shape/color per skin) over the recent
  touch path; fed by a `.simultaneousGesture(DragGesture(minimumDistance:0))` on the
  GameView root so it tracks touches WITHOUT consuming cell taps. Points pruned/
  faded in the frame loop (0.45 s). Non-interactive.
- Persistence: `SaveData.ownedTrailIDs`/`equippedTrailID` (+ tolerant decode; None &
  Comet always owned). `GameStore` buyTrail/equipTrail/ownsTrail.
- Cosmetics gains a TAP TRAILS section (TrailRow with dot preview + buy/equip via the
  confirm dialog).
- **Verified on-device (computer-use):** real taps still register through the gesture
  (tap counter incremented; pause/menu taps worked); the Comet trail renders along a
  drag; Cosmetics shows both PALETTES + TAP TRAILS sections with previews/states.
  Temp tap-counter/lifetime hooks reverted, save cleared.

## Run #20 — Data Core (fills the HUD↔grid gap) (2026-06-07)
- New `DataCoreView` in the space between the top bars and the grid: a neon "data
  core" with a progress arc (Fever charge in endless, target in campaign), a decode
  pulse, a gold Fever surge, and two slow counter-rotating dashed scanner rings
  (the ambient layer). Sizes itself to the slot (shrinks on small screens),
  reduced-motion aware, non-interactive.
- Replaced the top spacer with the core (grid stays in the thumb zone). Removed the
  now-redundant `ComboMeter` from the HUD (the core shows Fever charge). In Flow the
  core is a calm decorative pulse.
- **Verified on-device:** core renders mid-session with the arc charging toward Fever
  and decode pulse; grid position preserved. Temp autoplay reverted, save cleared.

## Run #19 — Purchase confirmation dialogs (2026-06-07)
- Buying in the Cyberdeck or Cosmetics now asks first: reusable neon `ConfirmDialog`
  ("CONFIRM PURCHASE / <item> / <cost> CR", BUY/CANCEL). Cyberdeck buy → confirm;
  Cosmetics buy → confirm (equipping an already-owned palette stays instant/free —
  no spend, no confirm).
- Verified on-device (Cyberdeck confirm overlay). Temp triggers reverted, save cleared.
- Next: utilize the empty space between the top bars and the grid (see QUESTIONS).

## Run #18 — Interactive tutorial (2026-06-07)
- Replaced the static How-to-Play card with an interactive, teach-by-doing
  `TutorialView`: step 0 tap a daemon, step 1 armored two-tap (breach→crack), step 2
  tap the daemon / avoid the firewall (wrong-tap → shake + nudge, no fail), step 3
  recap (RAM / fever / credits). Real SFX on taps, progress dots, SKIP / START HACKING.
- Runs on first boot (reuses `tutorialSeen`) and from a menu **TUTORIAL** button
  (replaced HOW TO PLAY). RootView `.help` → `.tutorial`; `HowToPlayView` removed.
- **Verified on-device:** step 0 (decode) auto-shows on a fresh install; step 2
  (firewall + daemon) renders with the avoid prompt. Temp step override reverted,
  save cleared.

## Run #17 — Cosmetics: neon palettes (2026-06-07)
- New **COSMETICS** screen: 5 buyable/equippable neon palettes (Classic free +
  Sunset Drive / Toxic Leak / Glacier / Amber Terminal at 500–1200 CR) that recolor
  the whole game. Fixes the dead-Credits gap (nothing to buy after maxing upgrades).
- `NeonTheme` refactored to read colors from an equipped `Palette` (`NeonTheme.current`);
  call sites unchanged. `danger`/text stay fixed for firewall readability. Catalog
  `Palettes` in NeonTheme.swift.
- Persistence: `SaveData.ownedPaletteIDs`/`equippedPaletteID` (+ tolerant decode,
  classic always owned). `GameStore` `buyPalette(id:cost:)`/`equipPalette` (color-
  agnostic). RootView applies the equipped palette at launch.
- `CosmeticsView` (swatches + buy/equip in one tap, applies instantly).
- **Verified on-device:** cosmetics screen (swatches/costs/EQUIPPED) at 2000 CR;
  equipping Sunset recolors HUD/grid/bg/particles; equipped palette loads at launch.
  Temp seed/demo reverted, save cleared.
- Deferred: tap-trail skins (lower value, fuzzier) — palette system is extensible.

## Run #16 — Flow (chill) mode (2026-06-07)
- New **FLOW STATE** mode designed for flow (the channel between anxiety & boredom):
  strip anxiety (no RAM clock / no death, no firewall bombs, no penalties, no
  escalation, no Fever) while avoiding boredom (3 nodes always present, armored for
  variety, full satisfying juice/audio). Endless; leave via pause→QUIT.
- `GameConfig.chill()` (drain 0, penalties 0, firewall 0, flat spawn/lifespan,
  `fixedActiveNodes` 3, `feverEnabled` false). Engine: `checkFever` honors
  `feverEnabled`; `targetActiveNodes` honors `fixedActiveNodes`.
- UI: GameView/GameViewModel `chill` flag — hides RAM bar + combo meter, island
  row shows "⌁ FLOW" instead of RAM, softens misses (no red pop/haptic/sound), adds
  a slow `ChillAtmosphere` breath (reduced-motion aware). Menu FLOW STATE button +
  `.flow` route (no economy/leaderboard).
- **Verified:** clean build; headless (no death over 180s and 60s idle, 0 bombs,
  0 fevers); on-device (calm HUD, FLOW marker, soft atmosphere, no bombs). Temp
  hooks reverted, save cleared.

## Run #15 — Pause/quit + how-to-play (2026-06-07)
- **In-run pause/quit:** `GameViewModel.isPaused` (+ `pause()`/`unpause()`); `advance`
  and `tap` guard on it so the sim and RAM clock freeze while paused. Pause button
  (bottom-leading) + `PauseOverlay` (RESUME / QUIT-to-menu). Fills the gap where you
  could only leave a run by dying.
- **How-to-play:** `HowToPlayView` (6 rules: decode / armored / firewalls / RAM /
  fever / upgrades). Auto-shown once on first launch (`SaveData.tutorialSeen` +
  `GameStore.markTutorialSeen`), and revisitable via a HOW TO PLAY button on the menu.
- **Verified on-device:** how-to-play auto-shows on a fresh install; pause overlay
  shows with RAM frozen (19s held across two screenshots). Temp hooks reverted, save
  cleared.

## Run #14 — Dynamic Island framing (2026-06-07)
- Researched DI use (WebSearch/Apple): can't render into the pill while foreground
  (Live Activity Island view only shows when backgrounded). See D14.
- Implemented "frame the Island": `IslandFrameRow` (SCORE left, RAM-seconds right,
  +×mult/shield) pinned to the top safe area, flanking the pill. `GameView`
  detects a real top inset (`hasIslandOrNotch`, key-window `safeAreaInsets.top >= 40`):
  flank only on Island/notch devices; flat-top devices show score/RAM inline in
  `HUDView` (`showInlineScore`) — no overlap, nothing lost.
- **Verified on two devices:** iPhone (Dynamic Island) — SCORE/RAM flank the pill;
  iPhone SE (no notch) — inline HUD, no overlap. Temp hooks reverted, saves cleared.
- Deferred: a between-runs Live Activity (Option B) — needs a widget extension +
  entitlement and only shows outside the app.

## Run #13 — Polish pass: shield-vs-bomb, NEXT CORE, finale (2026-06-07)
- **Shield now absorbs a firewall-bomb tap** (not just empty-cell mis-taps): engine
  `firewallBomb` case consumes a shield charge → new `.firewallDefused` event (gold
  "blocked" pop + medium haptic), no game over. Shield description updated.
- **NEXT CORE** button on a campaign win (cores 1-9) → advances to the next core.
  `GameView` gains `onNext`; RootView passes it (nil on the last core) and `.id(core.id)`
  forces a fresh session when advancing.
- **Campaign finale**: winning core 10 shows "THE GRID IS YOURS / ALL 10 CORES
  CRACKED" (gold) instead of the normal CORE CRACKED, no NEXT button.
- **Verified:** clean build; headless (shield defuses bomb → no game over, charge
  consumed); on-device (NEXT CORE on a core-1 win; finale on a core-10 win with a
  strong deck). Temp hooks reverted, save cleared.

## Run #12 — Cyberdeck upgrade descriptions (2026-06-07)
- Upgrades didn't explain their effect. Added `CyberdeckUpgrade.detail` (built from
  real `GameConfig` values so it can't drift) and showed it in each `UpgradeRow`
  along with a `Lv x/max` indicator. RAM = +Ns RAM/level; Decode Speed = +Ns RAM
  per decode/level (the only Campaign refill); Shield = absorbs an empty-cell mis-tap.
- Verified on-device (descriptions render + wrap cleanly).
- Note: Shield currently only absorbs empty-cell mis-taps (not firewall bombs or
  expiries) — described accurately; could be made to also eat a bomb tap if desired.

## Run #11 — Bugfix: fever-at-game-over freeze + music not resuming (2026-06-07)
Reported: game "froze on fever" when finishing a campaign core during fever, and
music stopped and didn't resume.
- **Freeze (visual):** `GridEngine.endGame` set `isGameOver` but never cleared
  fever; `tick()` then returns early forever, leaving `feverActive` true → the
  full-screen fever atmosphere + banner stuck behind the result. Fix: `endGame`
  now clears `feverActive`/`feverRemaining`. View also gates fever atmosphere/banner
  on `!isGameOver` (defensive). Verified headless: 30/30 wins, fever-at-gameover=0;
  on-device the CORE CRACKED screen is clean (no gold).
- **Music:** there was NO audio-interruption handling — an AVAudioSession
  interruption / route or engine-config change paused the music `AVAudioPlayer`
  (and stopped the SFX engine) with nothing to resume it, while the game loop kept
  running. Fix: `AudioEngine` now observes `AVAudioEngineConfigurationChange`,
  `AVAudioSession.interruptionNotification` (.ended), and
  `UIApplication.didBecomeActiveNotification`, plus a `resume()` self-heal
  (reactivate session, restart engine if stopped, resume/continue music). `resume()`
  is also called on every screen change and on GameView appear.
- Verified: clean build; temp auto-win confirmed the clean overlay; reverted hooks.

## Run #10 — Campaign mode (2026-06-07)
- `Core/Models/Campaign.swift` (new): `DataCore` + 10-core ladder (target,
  timeBudget, difficultyBias). `GameConfig.campaign(timeBudget:)` = time-attack
  (RAM countdown, no decode refill). `SaveData.campaignProgress` (+ tolerant decode).
- `Core/Engine/GridEngine.swift`: `targetScore`/`difficultyBias` params, `.coreCracked`
  win, `scaledScore` for difficulty, `checkTarget()`; snapshot exposes target +
  `didWin`/`targetProgress`.
- `Persistence/GameStore.swift`: `isUnlocked`/`isCleared`/`recordCore` (pay Credits
  always, advance progress on a fresh win).
- `UI/GameView.swift`: campaign session (config/target/bias), target HUD bar,
  win/lose overlay (CORE CRACKED / INTRUSION FAILED, RETRY/CORES). `recordSession`
  now `(score, won)`. `UI/MenuViews.swift`: `CampaignView` level select.
  `UI/RootView.swift`: CAMPAIGN button + campaign/core routing.
- Design: chose **time-attack** (RAM-as-countdown) over RAM-with-refill because the
  latter made any target grindable (sim showed 100% wins) — see D13.
- **Verified:** clean build. Sim-tuned curve (starter clears 1-4, walls ~5-7;
  skilled reaches ~7-9; mid deck clears to 7-8; strong deck 100%). Headless:
  progression unlock/advance/replay + persistence + back-compat. On-device:
  campaign select (locks), in-session target HUD + RAM countdown, CORE CRACKED win
  with +15 CR. Temp hooks reverted, save cleared.

## Run #9 — Grid ergonomics (2026-06-07)
- `UI/GameView.swift`: moved the grid from the top third into the lower-middle
  thumb-reach zone. HUD stays pinned at top (read-only); a flexible Spacer above
  the grid biases it down, with a capped (≤96 pt) bottom gap so it doesn't glue to
  the edge. Verified on-device (screenshot) — grid now sits low/centered.
- Next: campaign mode.

## Run #8 — MP3 music (replaces synth loop) (2026-06-07)
- `Audio/AudioEngine.swift`: removed the synth music loop (`music` node,
  `musicBuffer`, `buildMusicLoop`, `startMusicIfNeeded`). Added `MusicPlayer`
  (NSObject/AVAudioPlayerDelegate): discovers `*.mp3` in the bundled `Music/`
  folder, shuffles on launch (random first track), advances to the next on finish,
  reshuffles after the last. SFX unchanged. `enabled`/SOUND toggle now drives the
  MusicPlayer.
- `App/GRID_BREAKER/Music/` (new) added to the project as a **folder reference**
  (Resources phase) so any `.mp3` dropped in is auto-bundled — no code/project
  edits needed. Includes a README explaining the drop-in workflow.
- User supplied 3 tracks: Cold_Iron_Handshake / Locked_in_Fever_Mode /
  Max_The_Score (~4 MB each), committed as game assets.
- **Verified:** clean build; folder reference bundles the mp3s (confirmed in the
  built .app); headless AVAudioPlayer test — shuffle gives a random start order,
  advances on each finish, reshuffles at the end; real mp3 loads & plays
  (Max_The_Score, 177.9 s). Temp test files removed. (Speaker output = device listen.)

## Run #7 — M5 audio & polish (2026-06-07)
- `Audio/AudioEngine.swift` (new): asset-free AVAudioEngine synth. Renders SFX PCM
  buffers (decode/decodeBig/breach/miss/bomb/fever/gameOver/uiTap) + a ~130 BPM
  darksynth loop; 6-node SFX pool; `.ambient` session; defensive (never throws into
  the game). Shared singleton.
- Wired SFX into `GameViewModel.process(_:)` next to haptics. UI blips on menu.
- Sound toggle persisted: `SaveData.soundEnabled` (+ tolerant decode), `GameStore`
  `setSoundEnabled`, menu SOUND ON/OFF button; engine started in `RootView.onAppear`.
- Generated neon app icon via CoreGraphics swift script (1024²) → AppIcon.appiconset.
- pbxproj: new Audio group + AudioEngine.swift (fixed an ID-collision — reused
  GB…0010 which was GridBreakerApp's build-file id; moved icon fileRef to GB…0100).
- **Verified:** clean build; on-device temp diagnostic showed engine `run=Y` and
  non-silent buffers (decode 0.42 / bomb 0.59 / music 0.19); menu SOUND toggle
  renders; app icon PNG generated + compiles into the catalog. Temp hooks reverted.
  Speaker output itself = human device listen (CLI can't capture sim audio).
- Q4 (audio sourcing) + Q5 (haptics) resolved. Vertical-slice DoD met.

## Run #6 — M4 meta progression (2026-06-07)
- `Core/Models/SaveData.swift` (new): `SaveData` + `HighScoreEntry`, leaderboard
  insert/cap/isHighScore, and tolerant `init(from:)` extensions (back-compat).
- `Core/Models/Cyberdeck.swift`: added body `CodingKeys`.
- `Core/Models/GameConfig.swift`: `creditsPerScore`, `decodeBonusPerLevel`,
  `decodeTimeBonus(for:)`, `credits(forScore:)`.
- `Core/Engine/GridEngine.swift`: applies `decodeTimeBonus` (decode-speed upgrade).
- `Persistence/GameStore.swift` (new): @Observable authority; UserDefaults JSON
  persistence; `recordSession` (pay credits once + leaderboard), `purchase`.
- `UI/MenuViews.swift` (new): `CyberdeckView`, `HighScoresView`. `UI/RootView.swift`:
  menu hub routing (menu/game/cyberdeck/scores) + BEST. `UI/GameView.swift`: injects
  deck, records session once on game-over, shows credits/NEW HIGH SCORE.
- Project: new Persistence group + 3 files in pbxproj.
- **Verified:** clean build; headless tests (economy, leaderboard, Codable
  round-trip, back-compat decode of an old partial save — defaults applied);
  on-device (Cyberdeck shows 800 CR + scores persisted across a 2nd launch;
  game-over "+1 CR" + NEW HIGH SCORE). All temp seed/demo hooks reverted + save cleared.
- Gotcha logged (D11): synthesized Codable doesn't apply defaults for missing keys.
- Next: M5 — audio & polish.

## Run #5 — Balance pass (2026-06-07)
- `Core/Models/GameConfig.swift` only (no logic change): retuned spawn cadence,
  node count, lifespan and RAM economy to fix the sparse early game (Q3). See D10
  for the exact before→after numbers.
- Method: deterministic headless sim with realistic-player models (reaction
  0.20/0.27/0.36 s) over 5 seeds × 180 s; iterated on avgNodes, first-fever time,
  session length and skill ceiling (ground-truth Part 5.3).
- **Verified:** clean build; sim shows first fever ~5 s, board density 1.8–2.4 for
  normal play, casual ~78 s, good play dies ~168 s (ceiling), within 60–120 s target.
  On-device launch confirms HUD/board render with the new config.
- Q3 resolved. Next: M4 — meta progression.

## Run #4 — M3 Fever Mode (2026-06-07)
- `Core/Engine/GridEngine.swift`: combo state + fever (trigger at threshold via
  `checkFever`, bomb-clear, gold-only dense spawn during fever, ×multiplier in
  `decode`, countdown+auto-end in `tick`, combo reset on miss/expiry). New events
  `feverStarted`/`feverEnded`; snapshot fields combo/comboThreshold/feverActive/
  feverFraction/scoreMultiplier + `comboProgress`.
- `Core/Models/GameConfig.swift`: `feverSpawnInterval`, `feverActiveNodes`.
- `UI/GameView.swift`: ComboMeter, HUD ×N badge, fever atmosphere+banner wired,
  gold node sprites during fever, fever events → success/soft haptics.
- `UI/Juice.swift`: `FeverAtmosphere`, `FeverBanner`, `Haptics.success()`.
- **Verified:** clean build (temp perfect-play demo added then reverted). Headless
  sim across 4 seeds: fever fires 4×/45 s, 4.0 s each, clean end, score ~130 (×2)
  vs ~87 baseline. On-device capture of full fever state (gold banner + ×2 + shrink
  bar + gold atmosphere + gold nodes + score burst to 261).
- Tuning note (Q3, reinforced): early-game spawn is sparse — combos take ~7 s to
  build at score 0; tighten base spawn/lifespan in a balance pass.
- Next: M4 — meta progression (Credits → Cyberdeck upgrades, persistence, high scores).

## Run #3 — M2 game feel & juice (2026-06-07)
- `UI/Juice.swift` (new): `Haptics` wrapper, `JuiceEffect` model, `EffectsLayer` +
  `EffectView` (hit-flash, neon particle burst, floating "+N"), `ShakeEffect`
  GeometryEffect, `TerminalButtonStyle` press-dip.
- `UI/GameView.swift`: `GameViewModel.process(_:)` translates each `GameEvent` →
  effect + haptic + hit-stop (`freezeRemaining`) + shake (`shakeTrigger`); exposes
  `effectSeq` + `drainEffects()`. GridBoard hosts EffectsLayer sharing cell
  geometry; RAM bar gains a ghost trail layer; shake applied to game content;
  reduced-motion wired from environment.
- Used skill `game-feel-and-juice` (every flourish traced to a real event; calm at
  rest; reduced-motion respected).
- **Verified:** clean build (temp demo/debug hooks added then fully reverted).
  On-device rapid capture caught an armored decode mid-burst — white flash, gold
  particle ring, floating "+2", score=2, RAM refilled, firewall bomb left untapped.
  Debug readout confirmed real tap→decode→score path (score climbed 0→1→2).
  Tuning note (Q3): early-game spawn cadence feels sparse — revisit in balancing.
- Next: M3 — Fever Mode (combo → hazards vanish, golden bonus nodes, score ×N).

## Run #2 — M1 playable grid engine (2026-06-07)
- `Core/Engine/GridEngine.swift`: rewrote stub → full deterministic authority.
  Added `SeededRNG` (SplitMix64), `SessionSnapshot`, `GameEvent`, `GameOverReason`.
  Spawn (seeded position+type), `tick(deltaTime:)` (RAM drain, expiry+penalty,
  cadence spawn up to score ceiling, RAM-depletion game-over), `handleTap`
  (decode/breach/miss/shield-absorb/bomb→instant death).
- `Core/Models/GameConfig.swift`: added spawn cadence + score-payout params and
  `spawnInterval`/`targetActiveNodes` helpers.
- `UI/GameView.swift` (new): `@Observable` `GameViewModel` driven by
  `TimelineView(.animation)`; grid board, node sprites, RAM HUD, game-over overlay,
  reusable `TerminalButton`. `UI/RootView.swift`: JACK IN → session, exit back.
- Project: added `GameView.swift` to pbxproj.
- **Verified:** `xcodebuild` BUILD SUCCEEDED; installed/launched on sim — grid +
  draining RAM bar + firewall-bomb sprite render (screenshot). Headless `swiftc`
  sim of pure Core: 3 seeds run a full 60 s with sane score/RAM; bomb-tap → instant
  `firewallHit`; same seed → identical sequence, different seed → different.
- Next: M2 — game feel & juice (hit-flash, hit-pause, screen-shake, haptics,
  particles, RAM-bar ghost). Events already exposed via `GameViewModel.lastEvents`.

## Run #1 — M0 scaffold + docs (2026-06-07)
- New project created at `~/GRID_BREAKER`, git initialized.
- Decisions with maintainer: **iOS-first SwiftUI** (over the brief's Compose
  Multiplatform), first run = **scaffold + docs**, folder `~/GRID_BREAKER`.
- Hand-authored Xcode project (objectVersion 56, `GB…` ids, iOS 17, portrait,
  dark, bundle `nl.gridbreaker.app`, team A652HSR4S9).
- Core value types: `NodeType`, `GridNode`, `Cyberdeck` + `CyberdeckUpgrade`,
  `GameConfig` + `GridSize`. `GridEngine` documented stub (M1 contract).
- `NeonTheme` design tokens + `RootView` placeholder title screen.
- Vendored `GAME_GROUND_TRUTH.md` (binding constitution) and the brief PDF
  (`docs/GRID_BREAKER_Brief.pdf`).
- **Verified:** `xcodebuild` BUILD SUCCEEDED; installed + launched on simulator;
  neon title screen renders (screenshot).
- Next: M1 — playable grid with the engine as authority (see ROADMAP).
