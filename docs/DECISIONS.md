# DECISIONS — GRID_BREAKER

Design & tech decisions with rationale. Append new ones; don't rewrite history.

## D1 — Stack: iOS-first SwiftUI (not Compose Multiplatform)
**2026-06-07.** The brief recommends Compose Multiplatform (Kotlin). Overridden in
favor of native SwiftUI because the maintainer's skillset and other projects are
Swift, the budget is €0/solo, and CMP would mean learning a new language+toolchain.
Cross-platform stays possible later (Skip keeps Swift; CMP would be a rewrite) — the
`Core/` spec is kept platform-agnostic so a port reuses it (ground-truth Part 0/4).

## D2 — Brief's commercial framing treated as aspirational
**2026-06-07.** €5k/sprint, €25k cap, 2-person team, ads/IAP, marketing web demo,
backend proxy = AI-generated padding in the brief. Build at real hobby scale; revisit
only on explicit request.

## D3 — Authority is the local client engine
Per brief §10.3 and ground-truth Part 1.1: reflex gameplay can't tolerate network
latency on hit registration, so the device engine is the single source of truth. No
server in the gameplay loop. (A future web build would add a proxy only for high-score
sync — out of scope now.)

## D4 — Deterministic mechanics, seeded-procedural spawns
Mechanical properties + upgrade scaling are hardcoded for fairness/repeatability;
spawn position & type use a difficulty-seeded PRNG (brief §10.3). A seed → identical
replay, which enables free deterministic QA later (ground-truth Part 5.1).

## D5 — Firewall bombs explode only on touch
Natural expiry is always safe (brief §10.3 anti-frustration rule). Encoded in
`NodeType.firewallBomb` (requiredTaps 0, not harvestable).

## D7 — Frame loop via TimelineView(.animation), not CADisplayLink
**2026-06-07 (M1).** The engine is advanced once per frame from
`TimelineView(.animation)`'s date via `onChange` (runs outside the render pass, so
no "modifying state during update"). Chosen over a `CADisplayLink`/NSObject driver
to avoid UIKit plumbing and keep the loop pure-SwiftUI. dt is clamped to ≤1/20 s so
a stall can't teleport the simulation. Revisit only if frame pacing proves jittery.

## D8 — Generous hitbox = whole cell tappable
**2026-06-07 (M1).** Instead of a 1.2× sprite-sized hitbox, the entire grid cell is
the tap target and the sprite is drawn inset (~0.7×). Same effect as brief §10.7
(forgiving touch) with simpler, drift-free hit-testing. `GameConfig.hitboxPadding`
is retained for any future precise hit-testing.

## D9 — Juice fed only from engine events, queued via effectSeq
**2026-06-07 (M2).** All visual/haptic feedback is produced in
`GameViewModel.process(_:)` from the engine's `GameEvent` stream — never guessed in
the view (skill §5 / Part 2.5). Effects are queued and the overlay drains them on an
`effectSeq` counter change (avoids unbounded array growth and view/VM write races).
Hit-stop lives in the VM (it owns the frame loop); particles/flash/shake are pure
view. Reduced-motion snaps the motion-heavy parts off.

## D10 — Balance pass (data-driven via headless sim)
**2026-06-07.** Fixed the sparse early game (Q3) using the deterministic headless
sim with realistic-player models (reaction 0.20–0.36 s, taps most-urgent harvestable,
never bombs) over 5 seeds × 180 s (ground-truth Part 5.3). Changes in `GameConfig`:
- Spawn cadence: `baseSpawnInterval` 0.85→0.50, `minSpawnInterval` 0.30→0.20,
  `spawnCompression` 0.0035→0.0045.
- Node count: `targetActiveNodes` start 1→**2** (`max(2, min(cells-1, 2 + score/8))`).
- Lifespan: `baseNodeLifespan` 1.6→1.35, `minNodeLifespan` 0.45→0.50,
  `lifespanCompression` 0.0025→0.0030.
- Economy (skill ceiling): `bonusStandardDecode` 1.2→1.05, `bonusArmoredDecode`
  2.0→1.8.

Result: first fever ~5 s (was never reachable in casual screenshots), board density
avgNodes 1.8–2.4 for normal play (was 0.5–1.2), casual session ~78 s and good play
dies ~168 s (a real ceiling), within the brief's 60–120 s target. A perfectly
metronomic 0.20 s player still survives — acceptable (no human sustains that).

## D11 — Persistence: UserDefaults JSON + tolerant decode
**2026-06-07 (M4).** Save data (Cyberdeck + high scores) persists as JSON in
UserDefaults via `GameStore` (the meta-state authority). Not abstracted behind a
protocol seam yet — pragmatic for a single local store; revisit if a second backend
(e.g. iCloud/web sync) appears. **Gotcha:** Swift's synthesized `Codable` does NOT
apply property defaults for missing keys — an old save lacking a newer field would
fail to decode and (via `try?`) wipe progress. Fixed with custom `init(from:)` (in
extensions, to keep memberwise inits) + `CodingKeys` declared in the type body
(declaring `CodingKeys` inside the extension crashed the compiler). Verified by
decoding an old partial save → missing fields default correctly.

## D12 — Audio: synth SFX engine + MP3 music, shared singleton
**2026-06-07 (M5; music revised same day).** `AudioEngine.shared` (singleton —
audio is a global service) with `.ambient` session (respects silent switch, mixes
politely) and fully defensive start (game plays on silently on failure).
- **SFX:** synthesized into PCM buffers at launch, played via AVAudioEngine + a
  6-node pool. Asset-free (€0 ethos).
- **Music:** the player's own **MP3 files**, dropped into the bundled `Music/`
  folder (a folder *reference* in the project → any `.mp3` inside is bundled with
  no code/project change). `MusicPlayer` (AVAudioPlayer + delegate) shuffles the
  tracks on launch (random first) and advances to the next on finish, reshuffling
  after the last. (Replaced the original synth music loop on user request.)
**Caveat:** simulator speaker output can't be captured via CLI — engine start,
non-silent SFX buffers, mp3 load/play and the shuffle/advance loop are verified
programmatically; final mix quality is a human device-listen (Q6).

## D13 — Campaign is a time-attack (RAM-as-countdown), not grind
**2026-06-07.** Per the brief ("reach a target score within the time limit") and
the user's "consult ground truth" steer. First tried RAM-as-clock WITH the normal
decode refill → the headless sim showed 100% wins on every core even on a starter
deck (a competent player refills faster than RAM drains → immortal → any target is
grindable). So campaign cores use `GameConfig.campaign(timeBudget:)`: RAM is a true
countdown (no decode refill; the Decode-Speed upgrade is the only refill, keeping it
meaningful), and you race to the target. Picked over a separate second countdown
clock because two depleting bars split attention in a reflex game (game-feel: one
dominant gauge; ground-truth Part 1.4 visible-growth clarity). Difficulty per core =
`difficultyBias` (faster pace) + target + time budget, sim-tuned. Shared economy
(Credits + upgrades apply in both modes) per ground-truth's visible-growth/direction
emphasis; cores pay Credits win or lose so progress never hard-stalls.

## D14 — Dynamic Island: frame it, don't render into it
**2026-06-07.** Researched using the Dynamic Island for live score/time. Finding:
**you cannot draw app content inside the Island pill while your app is in the
foreground** — a Live Activity's compact Island presentation only appears once the
app is backgrounded (ActivityKit; Apple HIG). So live score-in-the-pill during play
is impossible. Chosen approach: lay the HUD out to *frame* the Island — SCORE (left)
and RAM time (right) pinned to the top, flanking the pill (status bar is hidden
in-game so the strip is free). Detect a real top inset (`safeAreaInsets.top >= 40`,
via the key window) → only flank on Island/notch devices; flat-top devices (e.g. SE)
keep score/RAM inline in the HUD so nothing overlaps or is lost. A between-runs Live
Activity (Option B) was considered but deferred (needs a widget extension +
entitlement, and only shows when not playing — awkward for a reflex/time-attack game).

## D15 — Flow (chill) mode: failure-free, flat-pace, calm presentation
**2026-06-07.** Designed for flow (the channel between anxiety and boredom). Removed
every anxiety source (RAM never drains → no death; no firewall bombs; no miss
penalties; no difficulty escalation; no Fever spikes) but kept engagement (3 nodes
always present, armored for variety, full juice/audio + a gentle score). No win/lose
→ you leave via pause→QUIT (time-distortion / play-as-long-as-you-like). Decoupled
from the economy (no Credits, no leaderboard) to keep it pure. Implemented entirely
via `GameConfig.chill()` + two engine hooks (`feverEnabled`, `fixedActiveNodes`) and
a `chill` UI flag (calm HUD, soft misses, slow `ChillAtmosphere`). Reuses the whole
engine — no separate game loop.

## D16 — Cosmetics: palettes via NeonTheme.current (Credit sink)
**2026-06-07.** Added buyable neon palettes to give Credits a use after upgrades cap
out. Implemented by making `NeonTheme`'s colors read from an equipped `Palette`
(`NeonTheme.current`) — every existing `NeonTheme.cyan/...` call site recolors for
free, no refactor. Palette swaps are infrequent and the screens are recreated on
navigation, so a non-observed static is fine (no Environment plumbing). `danger` and
text stay fixed (firewall must always read red). `GameStore` stays color-agnostic
(buy/equip by id+cost); the colour catalog lives in the UI (`Palettes`). Tap-trail
skins deferred — the system is extensible if wanted.

## D17 — Tap trail tracks touches via a simultaneous gesture
**2026-06-07.** The tap-trail cosmetic follows the finger via
`.simultaneousGesture(DragGesture(minimumDistance: 0))` on the GameView root. This
is the key choice: a simultaneous gesture recognizes ALONGSIDE the cells'
`.onTapGesture`, so it feeds the trail without consuming taps (verified on-device —
real taps still register with the gesture active). A `.gesture` (non-simultaneous)
drag would have stolen taps. Trail points fade over 0.45 s, pruned in the existing
frame loop; the layer is non-interactive. Skins live in the UI (`TrailSkins`), colors
resolve through the equipped palette, and `TrailSkins.equipped` is a static set at
launch + on equip (same pattern as `NeonTheme.current`, D16).
**Addendum (Run #24):** the renderer changed from isolated fading dots to a `Canvas`
beam that *connects* consecutive samples (tap→tap) into a fading "data stream" — in a
tap game, lone dots didn't read as a trail. The gesture/no-tap-stealing design above
is unchanged; only the drawing + per-skin style (`lineWidth`/`dashed`) evolved.

## D18 — Settings hub; reset wipes progress, not preferences
**2026-06-07.** Consolidated the loose menu buttons (SOUND, TUTORIAL) into a single
SETTINGS screen so the title stays clean and there's an obvious home for new options.
`resetProgress()` deliberately distinguishes **progress** (Credits, upgrades, scores,
cosmetics, campaign — wiped) from **preferences** (sound/haptics) and onboarding
state (`tutorialSeen`), which it preserves: a "reset progress" shouldn't silently
flip your audio off or re-show the tutorial. Guarded by the existing `ConfirmDialog`
(destructive, red). Haptics gained an on/off switch via a `Haptics.enabled` static —
the same shared-singleton/global pattern already used for audio (D12) and cosmetics
(`NeonTheme.current` D16 / `TrailSkins.equipped` D17), set at launch + on toggle.

## D19 — Endless grid escalates 3×3 → 4×4 mid-session (Q2)
**2026-06-08.** Endless steps the grid up once score ≥ `gridEscalationScore`
(default 40), rather than picking a size per session — the run gets a visible
late-game gear shift while the opening stays approachable (brief §10.3 "ceiling
grows with score"). Scoped to endless: campaign cores are hand-tuned for a fixed
3×3 (escalation would break their target/time tuning) and Flow stays a calm fixed
3×3 — both set `gridEscalationScore = nil`. Live nodes are **remapped** to the same
top-left cells (`old/3*4 + old%3`, preserving `id`+`hitsRemaining`) so they slide
into place as the grid grows instead of jumping; `gridSize` became `private(set) var`
and the change is a real `GameEvent` (`gridExpanded`) so the juice layer (haptic +
sting + animated resize) traces to engine truth, not a guess. Threshold lives in
`GameConfig` (one tunable place); verified via the deterministic headless sim + an
on-device visual check.

## D20 — Daily challenge: one shared seed per day, separate best
**2026-06-08.** The daily challenge is normal endless rules (all mechanics incl. the
new node types/power-ups) run on a **date-derived seed** (`y*10000+m*100+d`, mixed by
the engine's SplitMix64), so every player gets the identical board on a given day and
scores are comparable — leaning on the existing deterministic engine (D4) rather than
any backend. Tracked with its own best (`dailyBestScore` + `dailyBestDay`); a new day
resets the comparison. Replays reuse the day's seed (still "today's" board). It pays
Credits like endless (shared economy) but is kept **out of the TOP RUNS leaderboard**
(separate `recordDaily`, its own best) so the daily stays a distinct challenge. No
server needed now; a future cross-device leaderboard could sync `dailyBestScore` by
day key.

## D21 — Campaign: granular mechanic introduction + briefings (amends D13)
**2026-06-08.** Reworked the 10-core campaign so mechanics are introduced **one at a
time** up the ladder instead of all-at-once: each `DataCore` carries cumulative
feature gates (armored / bombs / fever / cache / worm / power-up kinds / 4×4) and
`GameConfig.campaign(for:)` builds the engine config from them (still the D13
time-attack base). Schedule: 1 standard → 2 armored → 3 bombs → 4 fever → 5 cache →
6 worm → 7 freeze → 8 overclock+purge → 9 grid-expansion → 10 finale. A `CoreFeature`
**briefing** explains the new mechanic before the run (the RAM clock is held until
JACK IN), shown only while the core is **uncleared** (uses `campaignProgress`, no new
persistence) so it's "explained when new," not every replay. Per the maintainer's
steer, levels are lengthened **mostly via targets** (25→200 vs the old 15→130) with
budgets sized so a realistic strong player clears within the clock — verified by the
headless gating+winnability sim (each core spawns only its unlocked types; all 10
clearable). Power-up kinds are gated via new `GameConfig.powerUpKinds`.

## D22 — Main menu information architecture
**2026-06-08.** Replaced the wall of 7 equal-weight, rainbow-colored buttons with a
hierarchy + grouping (menu best practices): a single prominent **JACK IN** primary CTA;
a **MODES** group (Campaign/Flow/Daily) and a **TERMINAL** shop group
(Cyberdeck/Cosmetics) as icon tiles; **TOP RUNS/SETTINGS** demoted to small dim utility
icons; and at-a-glance **stat chips** (Best/Daily/Credits). Color is restrained and
*meaningful* — cyan = play, gold = spend Credits, dim = utility — instead of a different
hue per button. One primary action, clear groups, less visual noise.

## D23 — Endless late-game pressure ("mastery = endless")
**2026-06-11.** A balance audit with a Python mirror of the engine (D10 player model,
5 seeds, 60 fps) found endless had **no skill ceiling**: good play (0.28 s reaction)
survived a 20-minute sim cap on every seed (~8.6k score), strong play ~23k, because
(a) decode refill at the difficulty floor (~3/s × 1.05 s) outruns the flat 1.0/s
drain, and (b) fever is self-sustaining — bombs vanish during fever, making the next
8-chain trivial (55% fever uptime for strong play). That also collapsed the economy:
one good run ≈ 8.6k CR vs the 20.2k CR full upgrade tree.

Fix: three deterministic levers in `GameConfig`, **endless-only** (campaign/Flow
keep them off):
- **Drain ramp** — RAM drain × min(2.5, 1 + 0.0007·score).
- **Refill decay** — per-node RAM bonus × max(0.75, exp(-0.0003·score)); the
  Decode-Speed upgrade's bonus never decays (upgrade stays meaningful late).
- **Fever threshold ramp** — +1 combo per fever triggered, capped at 12.

Philosophy chosen: **"mastery = endless"** — sim'd result: casual ~83 s (intent:
barely changed), good ~3.3 min (a real ceiling), a truly strong player can still go
on a legend run (sim-unbounded). The alternative ("everyone dies", harsher numbers
T8 in the audit) narrowed the casual↔good gap and was rejected. Milestones extended
to 16k/32k so long runs keep landmarks. Full audit + sim scripts vendored in
`docs/audit/`. Campaign curve re-validated unchanged: casual
walls at core 9, good clears all, strong full-clears — matches D13/D21 intent.
**Numbers are sim-validated, device feel-pass pending (Q7).**

## D24 — SFX redesigned: dark-cyberpunk synth family (amends D12)
**2026-06-11.** The maintainer judged the original FM/bell SFX set "too musical
arcade, not hacker" (the deferred Q6 real-device listen). Replaced all 11 SFX with a
**dark-cyberpunk synth family**, still 100% synthesized (€0/asset-free ethos, Q4):
detuned dual-saw stabs through a *closing* one-pole low-pass (the signature "dark
pluck"), sub-sine weight, tanh soft-clip warmth, dark minor fundamentals an octave
below the old set; noise only as attack transient. Functional contracts preserved:
decode still climbs 8 steps with the combo (now also opening the filter per step),
breach still resolves *upward* into the armored kill, fever is a riser not a
fanfare, game-over is a tape-stop power-down. Workflow: recipes were prototyped in
Python (`scripts/sfx_prototype.py`) and rendered to WAV for the maintainer's ears
*before* the Swift rewrite — synthesis math is 1:1 transliterable, so future SFX
iterations can be auditioned the same way. API unchanged
(`SFX` enum, `decodeSteps`, `play(_:step:)`).

## D6 — Hand-authored pbxproj
Mirrors the maintainer's PeuterGames convention (explicit file refs, `GB…` hex ids,
objectVersion 56) rather than file-system-synchronized groups, for predictable diffs.

## D25 — Game Center: report-only, optional, replaces the web backend idea
**2026-06-12 (Run #75).** Global leaderboards + achievements via GameKit instead of
the brief's web high-score backend (out of hobby scope since the vertical slice):
Apple-hosted, €0, no server, no accounts. Constraints that make it fit the
constitution: the service is **report-only** (observes finished snapshots + the
verified `GameEvent` stream; never feeds anything back into a session — engine
authority, Part 1.1, untouched); **auth is optional** (declining changes nothing;
the local top-5 in `GameStore` stays the offline truth); **Flow reports nothing**
(stake-free by design); achievements are earnable-only, never purchasable
(MONETIZATION.md hard rule). Score landmarks are endless/daily only — campaign
targets are hand-tuned, so its "score" isn't comparable. Known trade-off: scores
are client-reported and technically spoofable; with zero rewards attached this is
acceptable at hobby scope. `GKAccessPoint` shows on the menu hub only — nothing
may overlay the grid mid-run (Part 2.5 discipline applies to overlays too).
