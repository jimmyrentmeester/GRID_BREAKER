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

## App Store description (full · ~580 words)

```
GRID_BREAKER — netrunner reflex hack

A fast, focused reflex game. Decode the grid before your RAM runs out — then chase a better run.

── THE LOOP ──
Daemons spawn on a 3×3 grid and count down to expiry. Tap them before they expire: each decode refills your RAM and adds to your score. Let one expire and your RAM takes a hit. Let too many expire and the connection drops.

As your score climbs, the grid grows to 4×4, daemons get meaner, and armored targets take two taps. Chain 8 clean decodes in a row to trigger FEVER — ×2 score, golden nodes, hazards cleared.

── CAMPAIGN ──
4 chapters, 16 hand-tuned cores. Each chapter introduces one new mechanic, gives you room to learn it, then ends in a chapter boss — a brutal DAEMON SET or DMZ PURGE objective on top of the time-attack. Clear each core for ★; clear it flawless or fast for ★★; flawless and fast for ★★★. Pure skill.

── PROTOCOL ──
Objective-driven endurance. DAEMON SETs (tap numbered nodes in order) and DMZ PURGE zones (clear every intrusion before the overrun fills the board) alternate with no relief. No power-ups. A real fail state.

── DAILY HACK ──
One shared seed per day — everyone races the same board. Build a consecutive-day streak and share your result Wordle-style.

── CYBERDECK ──
Spend Credits on upgrades that change how you play: more RAM capacity, faster decodes, shield charges that absorb a single mistake. Then push further with run modifiers — harder challenges, bigger Credit multipliers.

── NO ADS. NO PAY-TO-WIN. ──
Free to play. Credits only buy upgrades and cosmetics — real money never touches your score or the leaderboard.

Game Center leaderboards + 13 achievements. Universal (iPhone + iPad).
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
