# LOG — GRID_BREAKER

Append-only record of completed runs (newest first). This file — not commit
prefixes — is the sole record of what's done.

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
