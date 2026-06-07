# UPDATES — GRID_BREAKER changelog

Short, human-readable changelog (newest first).

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
