# LOG — GRID_BREAKER

Append-only record of completed runs (newest first). This file — not commit
prefixes — is the sole record of what's done.

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
