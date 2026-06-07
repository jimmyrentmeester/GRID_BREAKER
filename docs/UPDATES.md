# UPDATES — GRID_BREAKER changelog

Short, human-readable changelog (newest first).

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
