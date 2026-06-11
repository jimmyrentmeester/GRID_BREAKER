# UPDATES — GRID_BREAKER changelog

Short, human-readable changelog (newest first).

## 1.0.23 — A darker, meaner soundscape (2026-06-11)
- Every sound effect is rebuilt in a dark cyberpunk style: gritty detuned synth-stabs
  and sub-bass instead of bright bells. Decodes still climb in pitch as your combo
  grows — they just sound like cracking ice, not a music box.
- Firewall hits boom harder, Fever now *surges* in, and game-over winds down like the
  connection physically dying.

## 1.0.22 — Endless gets a real endgame (2026-06-11)
- Long endless runs are now a genuine fight: the RAM drain creeps up as your score
  climbs, decodes refill a little less at high scores, and each Fever raises the bar
  for the next one (8 → up to 12 clean hits). Short and casual runs feel the same.
- Two new score milestones — 16,000 and 32,000 — for the legends.
- Fever on the expanded 4×4 grid now floods more gold nodes, matching its 3×3 density.
- Tapping the cell a worm *just* hopped out of now counts as catching it — no more
  losing your streak to a coin-flip race.
- Under the hood: smoother spawn pacing after a full board, and a few stability fixes
  (countdown, music playlist edge case, performance during play).

## 1.0.21 — More cosmetics & cyberdeck upgrades (2026-06-08)
- Three new neon palettes — Ultraviolet, Inferno and Wireframe — and three new tap-trails:
  Laser, Hexbits and Voidstream.
- Two new Cyberdeck upgrades: Fever Capacitor (longer Fever Mode) and Salvage Protocol
  (earn more Credits per run).

## 1.0.20 — New icon + animated boot splash (2026-06-08)
- Fresh app icon: a glowing neon grid with a breached, white-hot center — properly on
  theme.
- Cold launches now open with a slick animated boot sequence: the GRID_BREAKER wordmark
  glitches in, a scanline sweeps, the grid "syncs online", then you're at the menu. Tap
  to skip.

## 1.0.19 — Pre-run countdown (2026-06-08)
- Every run now opens with a quick, in-theme "// SYNC" countdown — 3·2·1 with a neon
  number and a scanline sweeping across the screen, then BREACH and you're in. The clock
  is held until GO, so you start fair. Works in every mode and on retry.

## 1.0.18 — Armored kill resolves upward (2026-06-08)
- Cracking and decoding an armored daemon now sounds right: the first tap is a lower,
  tense "crack" and the second tap resolves on a brighter, higher "unlock!" — a rising,
  satisfying one-two instead of the previous high-then-low.

## 1.0.17 — Juicier hit sounds (2026-06-08)
- Every decode now sounds more rewarding: the hit SFX got richer and brighter (a punchy
  attack, a bell-like ring, a sparkle and a little shimmer tail), armored/cache kills hit
  with more weight, and a clean chain climbs a longer, brighter melody. Still 100%
  generated in code.

## 1.0.16 — Endless: streaks & milestones (2026-06-08)
- New clean-streak multiplier in Endless: keep decoding without a miss and your base score
  multiplier climbs (×2 → ×5), stacking on top of Fever — so long, clean runs are rewarded
  big. A "🔥 STREAK" badge shows it; one slip resets it.
- Score milestones (50, 100, 250, 500, 1000…) now land with a gold flash, a chime and a
  small RAM top-up — landmarks to chase on a long run.

## 1.0.15 — Endless mode re-paced (2026-06-08)
- JACK IN (Endless) now opens calmer and ramps up more gradually, the grid grows later
  in a run, and the top speed is capped so it stays possible to hit — a long run now ends
  because you slipped up, not because it became unplayably fast. Daily uses the same feel.

## 1.0.14 — Much gentler early campaign (2026-06-08)
- The campaign now starts a lot calmer — early cores leave roughly twice as long between
  daemons (and they linger longer), so beginners have real room to breathe. Each core
  then ramps up the speed and density gradually toward a frantic finale.

## 1.0.13 — Smoother end of training (2026-06-08)
- In training you now press CONTINUE after each power-up, so you can read what it does at
  your own pace instead of it skipping ahead.
- The end of training is now one clean screen: it shows your CR and lets you head straight
  into the Cyberdeck or Cosmetics (or Later) — no more pressing "Jack In" only to get a
  separate credits pop-up.

## 1.0.12 — Tutorial teaches every power-up (2026-06-08)
- The training now walks you through all three power-ups — ❄ Freeze, ⚡ Overclock and
  🌀 Purge — instead of only Freeze.

## 1.0.11 — Gentler campaign (2026-06-08)
- The whole campaign now plays about 30% slower and more forgiving — daemons linger
  longer, the board fills less frantically, and each core's clock is extended to match —
  so new players have more room to learn. Tuned and re-validated across skill levels.

## 1.0.10 — Onboarding is one full flow (2026-06-08)
- New players now go through the whole tutorial up front in one sitting: the three
  practice levels, the starter-CR payday, then a guided first Cyberdeck upgrade and a
  cosmetic equip — before hitting the menu.
- Re-running the tutorial from Settings replays the entire thing (no extra CR the second
  time). The "you're banking CR" screen is now a clean full screen instead of a faint
  pop-up over the menu.

## 1.0.9 — Guided first upgrade & look (2026-06-08)
- The "you're banking CR" intro now actually walks you through it: opening the Cyberdeck
  guides your first upgrade, then hands you to Cosmetics to equip a look — a quick, skippable
  first-purchase tour. Completes the new onboarding.

## 1.0.8 — Onboarding payday + CR intro (2026-06-08)
- Finishing training now pays out 150 starter CR with a satisfying count-up, so you can
  buy something straight away.
- After your first real run, the menu gives you a one-time heads-up that you're banking
  CR — with quick links into the Cyberdeck and Cosmetics.

## 1.0.7 — New onboarding: 3 practice levels (2026-06-08)
- First launch now walks you through three short, no-pressure training levels — Level 1
  teaches decoding, your RAM clock and the firewall; Level 2 covers armored daemons,
  gold caches and worms; Level 3 lets you charge a Fever and grab a power-up. Each opens
  with a quick level card, and you can skip anytime. (Replaces the old quick tutorial;
  still available from Settings ▸ How to Play.)

## 1.0.6 — Streaks feel bigger (2026-06-08)
- The deeper your decode streak runs, the more it builds: haptics ramp from a soft tick
  to a sharp punch as you near Fever, hits throw more sparks with a bigger "+N", and the
  pop colour warms cyan → gold. A brief gold border pulse marks streak milestones.
- The arena itself warms at the edges the higher your score climbs — calm early, dense
  late. All of it respects Reduce Motion.

## 1.0.5 — VoiceOver support (2026-06-08)
- The game now works with VoiceOver: every menu, shop, setting and the in-game HUD has
  proper spoken labels (e.g. "Glacier palette, equipped", "Music volume, 80 percent",
  "Score, 1240"), purely decorative neon/particle layers are skipped, and grid cells are
  described so the board is perceivable. Reduce Motion was already respected throughout.

## 1.0.4 — The worm bites back + clearer power-ups (2026-06-08)
- The green worm is now unmistakable: it visibly squirms in its cell, and decoding one
  plays its own wet "slither" chirp instead of the normal hit sound.
- The how-to-play now teaches the worm hands-on (it hops around — you chase it) and
  explains each power-up on its own line: ❄ Freeze, ⚡ Overclock, 🌀 Purge.

## 0.27 — Campaign reworked (2026-06-08)
- Campaign now teaches itself: each core introduces one new mechanic at a time
  (armored → bombs → fever → cache → worm → power-ups → grid expansion), with a quick
  briefing the first time you meet it. Levels run longer with higher score targets,
  ramping to the finale.

## 1.0.3 — Polish from a full-mode QA pass (2026-06-08)
- A "GRID EXPANDED" flash now marks the moment the board grows to 4×4.
- The how-to-play also explains the gold data caches and green worms.
- TOP RUNS now shows your daily best and campaign progress alongside the endless
  leaderboard.

## 1.0.2 — Audio hang fix + tutorial (2026-06-08)
- Fixed an intermittent freeze on a button tap that also stopped the music (and left
  it silent). Audio now only re-syncs on real interruptions, and the music reliably
  comes back.
- The how-to-play now explains power-ups.

## 1.0.1 — Campaign difficulty re-tuned (2026-06-08)
- Smoothed the campaign curve: gentler early/mid cores so you can actually progress
  through and learn each mechanic, with the late cores (and the finale) tightening
  into a real challenge. Tuned across player skill levels.

## 1.0 — App Store readiness (2026-06-08)
- Prepped for submission: opaque app icon (App Store requirement), version set to 1.0,
  export-compliance declared, and iPhone-only targeting. Remaining steps (Apple account,
  screenshots, store listing) are tracked in docs/RELEASE_CHECKLIST.md.

## 0.30 — Rewarding purchases (2026-06-08)
- Buying an upgrade or cosmetic now lands with a satisfying "ACQUIRED" flash, a bright
  confirm chime, and a success buzz.

## 0.29 — Redesigned main menu (2026-06-08)
- The main menu is cleaner and easier to read: a big JACK IN button up top, your
  modes and shop grouped into labelled tiles with icons, your best/credits at a glance,
  and tidy color coding instead of a stack of identical buttons.

## 0.28 — Power-up effects on the grid (2026-06-08)
- Power-ups now show their effect *on the grid* instead of a banner over it: Freeze
  frosts the (stopped) board, Overclock energises it with a gold glow, and Purge sweeps
  it with a shockwave. Clearer and out of the way of play.

## 0.26 — Clearer power-ups (2026-06-08)
- Grabbing a power-up now flashes a bold, colour-coded callout of exactly what it does
  (TIME FREEZE / OVERCLOCK ×2 / PURGE), so the effect is unmistakable.

## 0.25 — Daily Hack challenge (2026-06-08)
- New DAILY HACK: one shared board per day (everyone gets the same daemon sequence),
  with its own best score to beat. Comes back fresh every day. Replay as much as you
  like to top your run.

## 0.24 — Separate music & effects volume (2026-06-08)
- Settings now has independent MUSIC and EFFECTS volume sliders, so you can mix them
  to taste. Gameplay sounds are a touch quieter by default too.

## 0.23 — Power-up pickups (2026-06-08)
- Grab a rare white pickup for a burst of power: ❄ FREEZE (time stops draining your
  RAM for a few seconds), ⚡ OVERCLOCK (double score), or 🌀 PURGE (wipes every
  firewall bomb off the board). (Endless only.)

## 0.22 — Worm daemons (2026-06-08)
- A new green "worm" daemon scuttles across the grid — it hops to a neighbouring
  cell if you're too slow, so you have to chase it down. Worth a little extra.
  (Endless only; campaign & Flow are unchanged.)

## 0.21 — Bonus data caches (2026-06-08)
- Keep an eye out for golden data caches: a rare, fast-disappearing bonus worth a
  big score (and extra RAM). Grab it in time for a spike — or let it slip, no harm
  done. (Endless & Flow.)

## 0.20 — The grid grows (2026-06-08)
- Push your score far enough in an endless run and the grid expands from 3×3 to 4×4
  — more targets, faster hands, a real late-game gear shift. Your current daemons
  slide into place as the grid grows around them. (Campaign & Flow stay 3×3.)

## 0.19 — Full sound set matched (2026-06-08)
- The rest of the sound effects now match the new hit sounds: a darker "denied"
  miss, a heavier digital firewall blast, a brighter fever sting, a moody game-over
  fall, and a cleaner menu blip. The whole set finally feels like one instrument.

## 0.18 — Punchier hit sounds (2026-06-08)
- The decode hits got a glow-up: a crisp, digital "decrypt" blip with real punch,
  and a heavier version for armored kills. Best part — a decode streak now climbs a
  little melody and resets when you break the chain. Still 100% generated in code.

## 0.17 — Launch screen (2026-06-07)
- The app now opens on a branded neon launch screen (logo + GRID_BREAKER wordmark on
  the dark grid background) instead of a blank black flash.

## 0.16 — Tap trails are real trails now (2026-06-07)
- Tap trails now draw a glowing beam *between* your taps (a "data stream" that jumps
  across the grid) instead of leaving lone dots — so they actually look like trails.
- Each skin has its own beam: Comet (smooth), Pixel Dust (segmented), Spark (thin),
  Plasma (thick). The COSMETICS previews were redrawn to show the real look, cleanly.

## 0.15 — Settings screen (2026-06-07)
- New SETTINGS menu: toggle sound and (now) haptics, see whether Reduce Motion is
  on, jump to the how-to-play, and reset all progress (with a confirm) for a clean
  start. Plus an about/version line. Sound & tutorial moved here from the menu.

## 0.14 — Score & visualizer polish (2026-06-07)
- Your score is now big and centered, sitting right above the data core in every
  mode (it was a small readout tucked in the top-left).
- Flow mode's central core finally does something: a ring that fills as you build a
  decode streak, then resets — calm, satisfying feedback with no pressure.
- Fever now plays out on the core itself (it surges gold and the ring drains as the
  burst runs out) instead of a separate banner, so nothing overlaps the score.
- Main-menu buttons are all the same width now.

## 0.13 — Tap-trail skins (2026-06-07)
- Your finger now leaves a neon trail as you play. Buy and equip trail styles
  (Comet, Pixel Dust, Spark, Plasma) in COSMETICS — they take on your palette colors.

## 0.12 — Data Core + confirmations (2026-06-07)
- The space above the grid now holds a live "data core": a neon ring that charges
  toward Fever (or your target in Campaign), pulses on every decode, surges gold in
  Fever, with a slow scanner backdrop. Atmosphere + at-a-glance feedback in one.
- Buying in the Cyberdeck or Cosmetics now asks for confirmation first.

## 0.11 — Interactive tutorial (2026-06-07)
- The how-to is now hands-on: you actually decode a daemon, breach an armored one,
  and learn to dodge the firewall, with a short recap at the end. Runs on first
  launch and any time from the TUTORIAL button on the menu.

## 0.10 — Cosmetics (2026-06-07)
- Spend your Credits on looks: 5 neon palettes (Sunset Drive, Toxic Leak, Glacier,
  Amber Terminal + the free Classic) that recolor the whole game. Buy and equip from
  the new COSMETICS menu. Now there's always something to save up for.

## 0.9 — Flow (chill) mode (2026-06-07)
- New FLOW STATE: a calm, no-pressure mode with no clock, no failure and no firewall
  bombs — just a steady, satisfying tap rhythm with a soft living backdrop. Play to
  unwind for as long as you like; pause or quit whenever.

## 0.8 — Pause + how-to-play (2026-06-07)
- You can now pause mid-run (the RAM clock freezes) and quit back to the menu —
  no more having to die to leave a session.
- First-time players get a quick "How to Hack" explainer, and it's always available
  from the main menu.

## 0.7.2 — Dynamic Island framing (2026-06-07)
- On iPhones with a Dynamic Island (or notch), your SCORE and RAM time now sit on
  either side of it during play — the island becomes part of the cockpit. Devices
  without one keep the normal HUD, unchanged.

## 0.7.1 — Polish (2026-06-07)
- The Failsafe Shield now saves you from a firewall bomb too (not just stray taps) —
  worth buying now.
- Campaign: a NEXT CORE button after a win so you can keep going, and a proper
  finale ("THE GRID IS YOURS") when all 10 cores fall.

## 0.7 — Campaign mode (2026-06-07)
- New CAMPAIGN: 10 hand-tuned data cores, each a time attack — hit the target score
  before your RAM countdown runs out. Cores unlock as you clear them.
- It gets genuinely hard: early cores are doable cold, later ones reward Cyberdeck
  upgrades (Credits are shared between modes). Crack "The Monolith" if you can.
- Also: the in-game grid now sits lower for comfier one-handed play.

## 0.6.1 — Custom MP3 soundtrack (2026-06-07)
- Music is now your own MP3 files. Drop `.mp3` files into `App/GRID_BREAKER/Music/`
  and rebuild — a random track plays on launch and the rest follow as each finishes.
- Shipping with three tracks: Cold Iron Handshake, Locked in Fever Mode, Max The Score.

## 0.6 — Audio & polish (2026-06-07)
- The game has a voice now: sharp synth SFX for every hit, breach, miss and bomb,
  a fever sting, and a driving darksynth pulse underneath — all generated in code,
  no audio files. Toggle sound on/off from the menu.
- New neon app icon. This completes the first full vertical slice of GRID_BREAKER.

## 0.5 — Meta progression (2026-06-07)
- The loop closes: every run pays out Credits, which you spend in the CYBERDECK on
  permanent upgrades (bigger RAM buffer, faster decoding, a failsafe shield). Your
  high scores are saved in TOP RUNS, and everything persists between launches.
- New main menu ties it together: JACK IN / CYBERDECK / TOP RUNS.
- Next: sound & music (synthwave + sharp SFX) and final polish.

## 0.4.1 — Balance pass (2026-06-07)
- The opening is no longer sparse: ~2 nodes from the first second, faster cadence,
  so it feels like a reflex game immediately and your first Fever comes in ~5s.
- Tuned the difficulty curve so a session runs ~1–2 min and there's a real skill
  ceiling at high speed. Tuned from automated playtests, not guesswork.

## 0.4 — Fever Mode (2026-06-07)
- Chain 8 clean decodes to trigger FEVER: the firewall bombs vanish, the grid fills
  with golden bonus nodes, and your score doubles — a 4-second burst with a shrinking
  timer. A combo meter shows your progress toward it.
- Next: spend earned Credits on permanent Cyberdeck upgrades + a high-score table.

## 0.3 — Juice (2026-06-07)
- It feels alive now: decodes pop with a flash, neon particle burst and a floating
  "+N"; armored kills land with a hit-stop; firewall hits shake the screen; haptics
  on every tap (light hit / heavy error). The RAM bar trails when it drops.
- Honors Reduce Motion (snaps the flashy bits off).
- Next: Fever Mode — chain combos to blank the hazards and rain golden bonus nodes.

## 0.2 — Playable grid (2026-06-07)
- The core loop works: JACK IN, tap glowing daemons to score and refill your RAM
  buffer, dodge firewall bombs (one touch = game over). RAM drains in real time;
  out of RAM = game over. RECONNECT to retry.
- Difficulty already ramps with score (nodes appear faster and live shorter).
- Next: making it *feel* good — flashes, shake, haptics, particles.

## 0.1 — Scaffold (2026-06-07)
- Project born. Neon "GRID_BREAKER" boot screen runs on iOS.
- Foundations in place: daemon types, grid node model, Cyberdeck upgrades,
  balance config. Gameplay engine next.
