# v1.3 Release — App Store copy

## What's New (App Store · max 4000 chars, keep it punchy)

```
CAMPAIGN 2.0 — now with chapters, bosses, and star mastery

The Campaign has been completely reworked:

• 4 CHAPTERS — each chapter introduces exactly one new mechanic (armored daemons, firewalls, data caches, power-ups) and gives you room to practise before the finale.
• 16 CORES — a longer, more measured ladder that ramps within each chapter rather than throwing everything at you at once.
• CHAPTER BOSSES — each chapter ends with a boss core: a brutal DAEMON SET or DMZ PURGE objective layered on top of the time-attack. Crack it and the next chapter opens.
• STAR MASTERY — every core now awards ★/★★/★★★. Clear it for 1 star; clear it flawless OR fast for 2; flawless AND fast for 3. Pure skill, no shield bypass.

ENDLESS RUN MODIFIERS — push your limits for more Credits

Before a run you can stack up to 4 optional challenges: No Fever, Double Firewalls, Sudden Drain, or Blitz. Each makes the run harder and multiplies Credits earned. The leaderboard stays a fair like-for-like — modifiers boost Credits only.

DAILY STREAK — come back every day

Complete the Daily Hack on consecutive days to build a streak. Share your result Wordle-style and compare with friends.

FEEL — crisper taps

Grid taps now fire on touch-down instead of touch-up, so decodes feel instant the moment your finger lands.

Bug fixes and performance improvements.
```

---

## App Store description (full)

```
GRID_BREAKER is a fast, neon reflex game. Jack into the grid, decode the daemons before they vanish, dodge the firewalls, and chain combos into Fever as the pace climbs.

Just thumbs. Pure reaction. No filler.

HOW IT PLAYS
• Tap glowing daemons to decode them and refill your RAM clock.
• Never tap a red firewall — let it expire.
• Crack armored shells, grab gold data caches, chase hopping worms.
• Chain clean hits to trigger FEVER: hazards clear and your score doubles.
• Grab power-ups — Freeze, Overclock, Purge — for a burst of control.
• Hold a clean streak to climb a rising score multiplier.

FOUR MODES
• ENDLESS — survive as long as your reflexes hold and chase the high score.
• CAMPAIGN — 16 hand-tuned data cores across 4 chapters, each teaching one new mechanic and ending in a chapter boss.
• PROTOCOL — objective-driven endurance. DAEMON SETs and DMZ PURGEs with no relief and no power-ups.
• DAILY HACK — one shared board per day; everyone races the same seed.

PROGRESS & STYLE
• Earn Credits every run and spend them in the CYBERDECK on permanent upgrades — more RAM, faster decoding, a failsafe shield, longer Fever, bigger payouts.
• Unlock COSMETICS — neon palettes that recolor the whole game and tap-trail styles that follow your finger.

BUILT RIGHT
• 100% on-device. No accounts, no ads, no analytics, no tracking — nothing is collected.
• Honors Reduce Motion; independent music & effects volume.
• All sound is generated in code — tactile, rewarding, no bloat.

Crack the grid. The Monolith is waiting.
```

---

## Checklist vóór submit (👤 = jij, 🤖 = al gedaan)

### 🤖 Gedaan
- [x] `MARKETING_VERSION = 1.3`, `CURRENT_PROJECT_VERSION = 6` in pbxproj
- [x] Codex bijgewerkt (16 cores / chapters / bosses / modifiers / streak)
- [x] Boss-briefing reframe (BOSS CORE rood, geen "NEW:")
- [x] Act-on-press grid-taps
- [x] Campaign-sim gevalideerd (STRONG/GOOD clearen alles, CASUAL t/m C15)
- [x] Build geslaagd; engine-checks groen

### 👤 Nog te doen
- [ ] **On-device feel pass** — tap-crispness, audio, haptics, boss-briefing visueel
- [ ] **Xcode archiveren** — Product → Archive → Distribute App → App Store Connect
  - Scheme: GRID_BREAKER | Configuration: Release | Generic iOS Device
- [ ] **App Store Connect** — nieuwe versie aanmaken, build koppelen, copy plakken:
  - What's New: tekst hierboven
  - Beschrijving: eventueel bijwerken
- [ ] **Screenshots** — minimaal de campaign-chapters en menu (zie `docs/screenshots/v1.3/`);
      nieuwe schermen schieten op je echte toestel voor de beste kwaliteit
      - Vereiste maat: 1320×2868 (6.9", Apple downscaalt automatisch)
- [ ] **Game Center** — geen nieuwe boards/achievements in v1.3, dus niets te wijzigen
- [ ] **Submit for review**

### Na goedkeuring
- [ ] `shareURL` in `GameStore.swift` vervangen door de directe App Store-link (nu nog de GitHub Pages URL)
- [ ] Featuring-nominatie indienen (App Store Connect → jouw app → "Nominate for featuring")
- [ ] Daily-share + short-form video live zodra de update live is
