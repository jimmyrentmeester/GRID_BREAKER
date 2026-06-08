# UPDATES — GRID_BREAKER changelog

Short, human-readable changelog (newest first).

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
