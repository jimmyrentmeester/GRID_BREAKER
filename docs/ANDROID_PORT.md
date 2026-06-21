# GRID_BREAKER → Android (Play Store) — port-plan

Onderzoek + inventarisatie 2026-06-20. Doel: dezelfde GRID_BREAKER-game als
Android-app in de **Google Play Store**, met zoveel mogelijk feature- en
feel-pariteit t.o.v. de iOS-build. Gekozen route: **Skip.tools (Skip Lite,
transpiled)** — SwiftUI → Jetpack Compose, Swift → Kotlin.

> **Learnings hergebruikt** uit de eerdere, voltooide Android-port van **Eldor
> (AIDM)** via Skip (M1–M9, 100% pariteit). Zie
> `~/Claude Projects/AIDM/docs/android-port.md` en
> `android-feature-parity-plan.md` — die bevatten de **~47-punts
> Skip-pitfall-catalogus** die hieronder per mijlpaal wordt toegepast i.p.v.
> herhaald. Lees die catalogus vóór elke port-sessie.

---

## STATUS / voortgang

| Fase | Status | Bewijs |
|---|---|---|
| P0 — Toolchain | ✅ | `skip checkup` kern-groen (skip 1.8.16, AGP 9.2.0, Kotlin 2.3.0). Test-Kotlin-harness faalt cosmetisch (JUnit-naamparse), niet de build. |
| P1 — Scaffold + APK | ✅ | `skip init --transpiled-app` → `GridBreakerSkip/`. `skip export --debug` → `GridBreaker-debug.apk` 84,6 MB + `.aab` 24 MB. |
| **M2a — RENDER-SPIKE** | ✅ **GO** | Live op emulator (Android 16). Zie hieronder. |
| **M1 — Engine + models + persistence** | ✅ | Hele deterministische kern (GridEngine 771 + alle models + GameStore) transpileert + draait live: RAM-drain, node-spawn, tick (real-dt), tap→score/combo/refill, armored 2-taps — allemaal correct op de emulator. |
| **M2 — Speelbare grid** | ✅ | Skip-native `GameView`: 3×3 grid uit snapshot, getypte glow-sprites (circle/diamond/hex/square via Shape), HUD (score/RAM-bar/combo/fever/streak), real-dt loop, tap→decode→score live bevestigd, game-over + RECONNECT. Neon-look intact. |
| **Release-AAB (M6-kern)** | ✅ vroeg geverifieerd | `skip export --release` → `GridBreaker-release.aab` **12,4 MB** + APK 14,5 MB (R8/ProGuard, van 24 MB debug). Geïnstalleerd + draait identiek — minificatie strip niets fataals. De-riskt de Play-Store-build. |
| **M5 — Leaderboards** | ✅ by construction | `GameCenterService` (GameKit) is bewust **niet** mee-geport naar de Skip-target → er zijn op Android geen leaderboard-calls. Lokale high-scores werken al via `GameStore` (M1). Play Games Services = los later traject. |
| **M4 — Menu's & meta** | ✅ | Alle iOS-views geport (parity), live-geverifieerd op emulator: menu-hub + router, **CYBERDECK**, **CAMPAIGN** (level-select), **COSMETICS** (palettes + trails), **TOP RUNS**, **CODEX**, **SETTINGS** (incl. Slider). Volledige `NeonTheme` palette-systeem. GameView-visuals gelijkgetrokken met iOS (RAM-bar, SCORE/NEXT, **DataCore CHARGE-ring**, ring-sprite-tegels). |
| **M3 — Audio + haptics** | ✅ build+runtime-verified | iOS-synth (12 SFX, sine/saw/LPF/FM/soft-clip) verbatim geport → 16-bit PCM `[Int16]` → Android `AudioTrack` (MODE_STATIC per shot). Haptics → `Vibrator`/`VibrationEffect` via `ProcessInfo.processInfo.androidContext`. Alle events gewired (decode/breach/miss/bomb/fever/…). VIBRATE-permissie toegevoegd. Draait runtime zonder crash; **echt geluid/trilling vereist een fysiek toestel** (emulator is geluidloos). Muziek (speler-MP3's) niet geport — geen gebundelde tracks. |

> **🎉 Volledige pariteit bereikt (M1–M6).** De Android-build matcht de iOS-versie in
> functionaliteit en uiterlijk, binnen de Skip/platform-grenzen. Resterend = alleen
> device-checks (audio-listen + trail/particle-visuals) + een Play-Store-keystore (M6 §7).

### Tap-trails + particles — Canvas-vrij herbouwd

De iOS tap-trail + decode-particles gebruiken Canvas (afwezig in Skip). Omdat je trail-
skins in de shop **koopt**, moeten ze écht werken — dus herbouwd met SwiftUI:
- **Tap-trail**: een `Path`-Shape-polyline door de recente tap-cel-centra (glow- + crisp-
  pass) + een node per punt (cirkel/vierkant/ruit per skin), fadend via de game-loop-klok;
  de staart trekt weg doordat punten op leeftijd worden gesnoeid. Per skin: kleur/vorm/
  dikte/dash uit `TrailSkin`. Gevoed door cel-taps ("springt tussen de cellen die je raakt").
- **Particles**: een decode-burst = 6 dots die naar buiten vliegen + faden (offset/opacity
  per progress), per event gekleurd. Canvas-vrij.
- **Perf**: caps (12 trail-punten, 3 bursts × 6 dots) zodat het licht blijft op zwakke GPU's.
  Twee echte fixes na een ANR op de software-emulator: (1) deze caps, (2) de SFX-synth
  (`renderAll`, ~500k DSP-samples) van de main-thread naar `Task.detached` — blokkeerde
  anders de eerste paint bij launch. Build- + runtime-stabiel (app blijft ALIVE in-game);
  de transiente visual zelf vereist een echt toestel (emulator te traag om 'm te vangen).

> **Icon-pariteit (fundamentele platform-grens):** SF Symbols zijn Apple-only en mogen
> niet op Android worden gebundeld. `IconCompat.sfSym(_:)` mapt elk gebruikt symbool naar
> een ondersteund Material-substituut (66 SF-namen mappen in SkipUI; de rest = driehoek).
> Iconen zijn dus semantisch gelijk, niet pixel-identiek; echte glyph-pariteit zou eigen,
> from-scratch getekende icon-assets vereisen (een aparte ontwerp-taak). De in-game node-
> sprites gebruiken Shapes + (gemapte) glyphs.

> **Emulator-prestatie:** de software-GPU-emulator (swiftshader) is traag — cold-start
> ~20s, en na langdurig gebruik komt een Android-"System UI isn't responding"-dialoog op
> (emulator, niet de app). Verificatie gebeurt per verse boot → snel screenshot.

### Pitfalls uit M4 (menu's)

61. **`ButtonStyle` is in SkipUI een concrete `RawRepresentable`-type, geen protocol** —
    een custom `struct X: ButtonStyle { makeBody(configuration:) }` compileert niet
    ("Configuration/isPressed/label unresolved"). Gebruik `.buttonStyle(.plain)` (plain
    label, geen Material-chrome); de press-dip vervalt.
62. **Mutable `static var` globals** (themakleuren, equipped skin) → Swift-6 strict
    concurrency weigert ze. Markeer `nonisolated(unsafe) static var` (single-writer op de
    main thread).
63. **`Animation`-shorthands niet inferbaar in een ButtonStyle/los-modifier-context** —
    `.spring(...)`/`.easeOut(...)` → "owning type"-fout; schrijf `Animation.easeOut(...)`
    voltuit, of vermijd `.spring` (niet ondersteund) → `.easeOut`.
64. **SF Symbols: alleen ~66 namen mappen naar Material-icons** (skip-ui
    `Components/Image.swift`); de rest rendert als waarschuwingsdriehoek. Een `sfSym(_:)`-
    mapper (`IconCompat.swift`) vertaalt de gebruikte namen naar ondersteunde, semantisch-
    nabije Material-icons (flag→location, cpu→wrench, scope→plus.circle, paintpalette→star,
    trophy→list.bullet, book→info.circle, bitcoinsign→plus.circle). Pixel-exacte icon-
    pariteit zou gebundelde custom-assets vereisen (latere polish). De in-game node-sprites
    gebruiken Shapes (geen SF Symbols) → ongemoeid.
65. **`.onTapGesture(perform:)`** matcht niet — gebruik de closure-vorm `.onTapGesture { … }`.
66. **`ForEach(collection.indices, id: \.self)`** faalt — gebruik de kale
    `ForEach(0..<count) { i in }` (Skip's Range-overload neemt geen `id:`, #40).

### Omgevings-blocker (deze sessie)

> **Schijfruimte.** De Mac liep tijdens het emulator-testen naar **~0,7 GB vrij (95% vol)**.
> De AVD boot wel maar zijn groeiende image vreet de ruimte → de emulator gaat na ~1 min
> offline. Daardoor moet live-verificatie in één snelle boot→screenshot→kill-cyclus.
> Veilig opgeruimd (regenereerbaar): Xcode DerivedData, Homebrew/SwiftPM-caches. **Voor vlot
> doorwerken** (en de iOS-archivering) is meer vrije ruimte nodig — `~/.gradle` (6,6 GB,
> regenereert vanzelf) is de grootste veilige kandidaat.

### M2a render-spike — uitslag (2026-06-21): **GO**

De spike testte de drie unieke risico's live. Twee kernprimitieven van de
iOS-app zijn **hard afwezig** in SkipUI 1.8.16, maar beide hebben een **bewezen,
mooi-renderende workaround**:

1. **`TimelineView` — NIET geïmplementeerd** (`Timeline.swift` is volledig een
   `/* */`-stub). De 60fps game-loop-driver bestaat niet.
   → **Workaround (bewezen):** een `.task { while !cancelled { Task.sleep(~16ms);
   clock += dt } }`-loop die `@State` muteert; Compose recomposeert per tick.
   Animeert vloeiend op de emulator. **LET OP:** de naïeve vaste-accumulator
   liep trager dan real-time → de echte game **moet `dt` uit echte timestamps
   (`Date`) berekenen**, ands is de speelsnelheid framerate-afhankelijk.
2. **`Canvas` / `GraphicsContext` — NIET geïmplementeerd** (beide `/* */`-stubs).
   Alle beams/trails/particles die de iOS-app via Canvas tekent.
   → **Workaround (bewezen):** `Path` + `Shape` ZIJN geïmplementeerd. De beam
   herbouwd als een `Shape` met `.stroke` + `.blur` + glow — rendert perfect.
3. **`neonGlow` (dubbele `.shadow`) — WERKT** (`.shadow(color:radius:)` is
   geïmplementeerd). De hele neon-glow-signatuur (70 callsites) overleeft de port
   ongewijzigd. Live bevestigd: titel, nodes én beam gloeien correct.

Ook geïmplementeerd & bevestigd: `.blur`, `.offset`, `.scaleEffect`, `.opacity`,
`Color(red:green:blue:)`, `Path`, `Shape`. Escape-hatch `ComposeView {}` bestaat
voor als een effect later tóch native Compose nodig heeft.

### Nieuwe pitfalls (deze sessie — aanvulling op de Eldor-catalogus)

48. **`TimelineView` bestaat niet in SkipUI** — vervang door een `Task.sleep`-loop
    die `@State`/`@Observable` muteert (en bereken `dt` uit `Date`).
49. **`Canvas`/`GraphicsContext` bestaan niet** — herbouw tekenwerk met `Path`/
    `Shape`-views + `.blur`/`.shadow`, of `ComposeView` voor complexe gevallen.
50. **`Double.truncatingRemainder(dividingBy:)` zit niet in SkipLib** — gebruik
    `Int`-modulo of `fmod`-equivalent.
51. **Scaffold-drift skip 1.8.16 (Gradle):** `Android/app/build.gradle.kts` ships
    twee stale regels die AGP 9.x weigert: (a) `alias(libs.plugins.kotlin.android)`
    — bestaat niet meer in de catalog (AGP 9.x heeft ingebouwde Kotlin-support),
    verwijderen; (b) `getDefaultProguardFile("proguard-android.txt")` →
    `"proguard-android-optimize.txt"`. Beide eenmalig gefixt in dit project.
52. **App start niet via `monkey -c LAUNCHER`** (result -5); start met
    `adb shell am start -n nl.gridbreaker.app/grid.breaker.MainActivity`.

### Pitfalls uit M1 (engine + models)

53. **Seeded-RNG met `UInt64`:** (a) `&+=` (compound) wordt niet vertaald → gebruik
    `state = state &+ X`; `&*` → Kotlin `*` werkt (ULong wrapt). (b) Hex-literals >2^63
    overflowen Kotlin's signed `Long` ("value out of range") — Skip zet geen `uL`-suffix;
    bouw de constant uit 16-bit chunks via `UInt64(0x….) << n | …`. (c) `Double.random`,
    `Int.random(in:using:)`, `randomElement(using:)`, `shuffle(using:)` werken niet met een
    custom generator → schrijf eigen helpers op de RNG (`uniform()`, `int(inRange:)`, een
    index-helper + concrete `shuffledInts`).
54. **`min`/`max` widen overal** (ook `Double,Double`) naar een boxed `Number & Comparable`
    → concrete `dmin/dmax/imin/imax` (ternary) of expliciete `if`-clamps. Idem elke
    gemengde ternary: `cond ? 0.20 : 0` moet `: 0.0`; `cond ? Double(x) : 1` moet `: 1.0`.
55. **`range.filter { }` levert een Kotlin `List`**, niet een Skip `Array` → `.count`,
    indexing en doorgeven aan een `[Int]`-param falen. Bouw de array met een expliciete
    `for … where … { append }`-loop.
56. **Enum-case als constructor-arg met weggelaten default-params** → "unable to determine
    owning type for member '.x'"; schrijf het type voltuit: `type: NodeType.intrusion`.
57. **`ClosedRange<Int>` → Kotlin `IntRange`** heeft geen `.lowerBound`/`.upperBound`;
    geef geen `ClosedRange` terug uit gedeelde code — gebruik een eigen `struct {lo, hi}`.
58. **`TimeInterval.infinity` / `.infinity`** resolvet niet → gebruik een grote eindige
    waarde (de persistente nodes slaan expiry sowieso over).
59. **`@Observable` vereist `import Observation`** in een bestand dat alleen Foundation importeert.
60. **`Double.truncatingRemainder` ontbreekt** (zie #50) — `Int`-modulo of `fmod`.

> **Determinisme-caveat:** de RNG-helpers houden Android intern deterministisch (zelfde
> seed → zelfde run). De uniform/int-afleiding wijkt af van Swifts stdlib, dus een Daily-
> seed kan een ándere board geven dan iOS. Voor cross-platform Daily-pariteit moeten beide
> platforms dezelfde helpers gebruiken (later, indien gewenst).

---

## 0. Waarom Skip (en niet Flutter/Compose-MP/web)

Identiek aan de Eldor-afweging — voor *één* extra platform (Android) is Skip
veruit het minste werk:

- **~70–80% van de Swift/SwiftUI-codebase blijft staan**: de hele
  deterministische engine + models + de meeste SwiftUI-views.
- **Géén backend nodig**: GRID_BREAKER heeft geen API-keys, geen netwerk, geen
  secrets. (Eldor had Keychain + LLM-proxy-overwegingen; hier niet — dat scheelt
  een hele klasse werk.)
- **Eén artefact om te distribueren**: de `.aab` (Android App Bundle).
- Web/Windows vallen buiten scope; dáárvoor zou een volledige TS/Dart-herschrijving
  nodig zijn (zie de cross-platform-skill).

**Toolchain staat al** (van de Eldor-port, op deze Mac): `skip` 1.8.16,
JDK 17, Android SDK/cmdline-tools. Elke sessie:
`source "/Users/jimmyrentmeester/Claude Projects/AIDM/Tools/android-env.sh"`
(of kopieer die naar deze repo). `skip checkup` is eerder volledig groen geweest.

---

## 1. Het spec/code-split (wat overleeft, wat herschreven wordt)

GRID_BREAKER is **architectonisch ideaal** voor een port: de game-logica zit al
volledig in een deterministische, SwiftUI-vrije kern (de "engine is de
authority"-conventie). Dat is precies wat de port-skill als gouden standaard
noemt.

### Herbruikbaar — porteert vrijwel verbatim (pure value types / Foundation)

| Bestand | LOC | Risico | Noot |
|---|---|---|---|
| `Core/Engine/GridEngine.swift` | 771 | **Laag** | `@MainActor` struct, `SeededRNG`, `tick()→[GameEvent]`. Pure logica. Dé kern. |
| `Core/Models/GameConfig.swift` | 402 | Laag | Balansgetallen + factory-methods + `exp()`-accessors. Let op float-literals (#1, #29). |
| `Core/Models/*` (GridNode, NodeType, Cyberdeck, Campaign) | ~360 | Laag | Enums + structs. |
| `Core/Models/SaveData.swift` | 127 | **Midden** | Heeft tolerant `init(from:)` met `decodeIfPresent` → **pitfall #19** (transpileert slecht). Android heeft geen oude saves → drop de custom decoder, gebruik synthesized Codable. |
| `Persistence/GameStore.swift` | 246 | Laag | `@Observable` + `UserDefaults` + JSON. SkipFoundation dekt UserDefaults; `@Observable` werkt. |

### Per-platform herschrijven (UI + services)

| Bestand | LOC | Risico | Aanpak |
|---|---|---|---|
| `UI/GameView.swift` | 1622 | **Hoog** | De in-session view: `TimelineView(.animation)` game-loop + `Canvas`-beams + glow + `GeometryEffect` shake. Zie §2. |
| `UI/MenuViews.swift` | 1673 | Midden | Menu/Cyberdeck/Codex/HighScores/Campaign-select. Veel `.sheet`/grids → pitfalls #45/#46 (full-screen swaps, handmatige rijen). |
| `UI/Juice.swift` | 356 | **Hoog** | Particles (Canvas + `.blur`), haptics-wrapper, hit-flash. Canvas-risico (#13) + haptics-shim. |
| `UI/NeonTheme.swift` | 179 | **Hoog** | `neonGlow` = dubbele `.shadow`; node-shapes voor Canvas. De hele neon-look hangt hieraan. Zie §2. |
| `UI/RootView.swift` | 448 | Midden | Router + menu-tiles. `.blendMode(.screen)` (#?), `isPad`-logica. |
| `Audio/AudioEngine.swift` | 451 | **Zeer hoog** | `AVAudioEngine` + `AVAudioPCMBuffer` real-time synth. Skip dekt dit níét → volledige AudioTrack-herschrijving. Zie §3. |
| `Services/GameCenterService.swift` | 222 | **Hoog** | GameKit bestaat niet op Android. Stub of Play Games Services (apart traject). Zie §4. |

**Totaal: ~6.870 LOC** (vergelijkbaar met Eldor's ~7.400). Maar: GRID_BREAKER
mist Eldor's zwaarste brok (de 1.000+ LOC LLM-service met streaming + function
calling). Daar staat tegenover dat GRID_BREAKER drie *nieuwe* risico's heeft die
Eldor niet had (game-loop, Canvas-neon, audio-synth — §2/§3).

---

## 2. Risico #1 (uniek): real-time render & het neon-uiterlijk

Eldor was turn-based chat. GRID_BREAKER draait een **60fps reflex-loop met een
zwaar Canvas/glow-uiterlijk**. Dit is het make-or-break-gebied en moet als
**allereerste spike** geverifieerd worden, vóór er volledig geport wordt.

1. **`TimelineView(.animation)`** drijft de hele tick-loop (`GameView.swift:623,
   781`). Onbekend of Skip dit op frame-tempo soepel naar Compose bridge't.
   *Spike:* een minimale `TimelineView(.animation)` die een teller op het scherm
   ophoogt — meet of het ~60fps haalt op de emulator. Als het hapert/niet
   tickt: fallback naar een Kotlin-side `withFrameNanos`-loop achter `#if SKIP`,
   of een timer-gedreven model.
2. **`Canvas` + `GraphicsContext.addFilter(.blur)`** (beams in GameView:782,
   trails in MenuViews:633/656, particles in Juice). **Pitfall #13**: Skip's
   Canvas is beperkt; `addFilter(.blur)` ín een Canvas is een groot vraagteken.
   *Plan B:* effecten downgraden naar gewone SwiftUI-shapes met `.blur`, of
   accepteren dat trails/beams op Android simpeler zijn.
3. **`neonGlow` = dubbele `.shadow(color:radius:)`** (NeonTheme:166) — **70
   callsites**. Dit ís het uiterlijk. Of `.shadow` met kleur+radius naar een
   Compose-glow mapt is onzeker. *Plan B:* een Compose-shadow/elevation-equivalent
   of een statische glow-laag. Zonder glow ziet de game er fundamenteel anders uit
   → dit weegt zwaar mee in de "is de port de moeite waard"-beslissing.
4. **`GeometryEffect` (ShakeEffect)** — **pitfall #27**, niet in SkipUI. Wrap
   `#if !SKIP`; Android-shake later via `Modifier.offset`-animatie.
5. **`.blendMode(.screen)`** (RootView:356) — verifiëren; mogelijk `#if !SKIP`.

**Conclusie:** de eerste sessie ná de scaffold is een **render-spike** (M2a):
één levende grid-cel + één glow + één Canvas-effect op de emulator. Pas als dat
acceptabel oogt, is de rest van de UI-port zinvol. Dit is de grootste go/no-go.

---

## 3. Risico #2 (uniek): audio-synth herschrijven

`AudioEngine.swift` synthetiseert **alle SFX als PCM-buffers** en speelt ze via
`AVAudioEngine` + `AVAudioPlayerNode.scheduleBuffer`. SkipAV ondersteunt
`AVAudioPlayer` (file-playback, dat deed Eldor) maar **niet** `AVAudioEngine` /
`AVAudioPCMBuffer` / een player-node-pool.

- **Herbruikbaar**: de synth-*wiskunde* (de `buffer(seconds:fill:)`-closures die
  golfvormen berekenen — saw/sub/arp, de discharge/detonation-envelopes). Dat is
  pure `Float`-math.
- **Herschrijven**: de afspeel-laag. Op Android: render dezelfde samples naar een
  `ShortArray`/`ByteArray` en speel via **`AudioTrack`** (raw PCM, low-latency
  mode) met een eigen kleine voice-pool voor overlap. De darksynth-loop wordt een
  langere buffer in loop-mode.
- Achter `#if SKIP` / een `AudioBackend`-protocol met twee implementaties.
- `AVAudioSession` (regels 58/102/124) → `#if os(iOS)` (pitfall #4). Android
  audio-focus is optioneel voor een ambient game.

Schatting: 1–2 sessies. Het is de zwaarste shim. *Fallback bij tijdgebrek:*
SFX tijdelijk uit op Android (de game is speelbaar zonder), audio als latere
mijlpaal — maar feel lijdt eronder (de skill noemt audio first-class).

---

## 4. Risico #3: leaderboards (Game Center → ?)

`GameCenterService.swift` gebruikt GameKit (`GKLocalPlayer`, `GKLeaderboard`,
`GKAchievement`, `GKAccessPoint`). **Niets daarvan bestaat op Android.**

Drie opties, in volgorde van werk:

1. **Stub op Android** (`#if !SKIP` om het hele service-gebruik) — snelste pad
   naar een speelbare APK. Achievements/leaderboards zijn dan iOS-only. De
   service is al "report-only" en declining is al een no-op, dus dit is schoon.
   **Aanbevolen voor de eerste release.**
2. **Lokale leaderboards op Android** — high-scores tonen we al lokaal
   (`GameStore` + `HighScoresView`); die werken cross-platform zonder netwerk.
3. **Google Play Games Services** — de echte Android-tegenhanger (cloud
   leaderboards + achievements). Compleet andere SDK, een apart integratie-traject
   (zoals Eldor zijn Speech/Play-onderdelen parkeerde). Pas oppakken als Android-
   tractie het rechtvaardigt.

---

## 5. Platform-shims (de kern van het werk) — samenvatting

| Service | iOS-API | Android-shim | Bron-learning |
|---|---|---|---|
| Audio | `AVAudioEngine`+PCM | **`AudioTrack`** raw-PCM voice-pool | nieuw (zwaarder dan Eldor's ExoPlayer) |
| Haptics | `UIImpactFeedbackGenerator` | **`Vibrator`** + `VibrationEffect` via `ProcessInfo.processInfo.androidContext` | Eldor M9-haptics ✅ (kant-en-klaar patroon) |
| Persistence | `UserDefaults` | SkipFoundation `UserDefaults` (transpileert) | Eldor #15/#41 ✅ |
| Leaderboards | GameKit | stub → later Play Games | nieuw (zie §4) |
| Glow/Canvas | `.shadow`/`Canvas` | Compose-equivalent of downgrade | nieuw (zie §2) |

Géén Keychain-shim nodig (geen secrets) — een hele Eldor-shim valt weg.

---

## 6. Fase-/mijlpaal-plan

Elke mijlpaal eindigt met een **werkende APK + emulator-screenshot** als bewijs
(verified-by-construction vs live-verified onderscheiden). Per sessie ~300–500
LOC inclusief rebuild-cycli.

| Fase | Doel | Effort | Go/no-go |
|---|---|---|---|
| **P0 — Toolchain** | Bevestig `skip checkup` groen op deze Mac; `android-env.sh` naar repo kopiëren; AVD (Android 16/API 36, 1080×1920) aanmaken. | 0.5 sessie | — |
| **P1 — Scaffold** | `skip init --transpiled-app` in `GridBreakerSkip/`; minimale neon-splash; eerste `skip export --debug` → APK; sideload + screenshot. | 1 sessie | APK draait |
| **M2a — RENDER-SPIKE** ⚠️ | **Cruciaal.** Eén `TimelineView(.animation)`-loop + één `neonGlow` + één `Canvas`-effect live op de emulator. Meet fps + glow-look. | 1 sessie | **Beslis hier of de port zinvol is** |
| **M1 — Engine + models + persistence** | `GridEngine`, alle `Core/Models/*`, `GameStore`. SaveData-decoder droppen (#19). Test-view die score/RAM toont. | 1.5 sessie | engine tickt headless-correct |
| **M2 — Speelbare grid** | Volledige `GameView` (HUD, DataCore, GridBoard, tap→tick), glow/Canvas zoals besloten in M2a, shake `#if !SKIP`. | 2 sessies | een ronde is speelbaar |
| **M3 — Audio** | `AudioTrack`-backend + synth-math hergebruikt; haptics-shim (Eldor-patroon). | 1.5 sessie | SFX + tril op device |
| **M4 — Menu's & meta** | RootView-router, Cyberdeck-shop, Codex, HighScores, Campaign-select, PROTOCOL-tile. Grids/sheets → #45/#46. | 2 sessies | hele app navigeerbaar |
| **M5 — Leaderboards** | GameCenter stub `#if !SKIP`; lokale scores blijven werken. (Play Games = later.) | 0.5 sessie | geen crash, scores lokaal |
| **M6 — Polish + Play-release** | Android launcher-icoon (uit het 1024²-icoon), SF-Symbol → Material (#44, `IconCompat`-patroon van Eldor), theme-check, `skip export --release` → signed `.aab`. | 1.5 sessie | installeerbare release-`.aab` |

**Realistisch totaal: ~11–13 focus-sessies** (à ~20 min) ná P0, mits M2a groen
is. Reservebudget 2–3 sessies voor audio + Canvas-tegenvallers.

---

## 7. Google Play Store-specifiek (eindbestemming)

Skip levert via `skip export --release` een `.aab` (Android App Bundle — Play's
vereiste formaat) + APK. Voor de Store zelf (een apart, deels 👤-traject):

- **👤 Google Play Developer-account**: eenmalig **$25** (geen jaarlijkse fee,
  i.t.t. Apple). Verificatie kan dagen duren → vroeg starten (zelfde principe als
  de Apple-blokkers in de app-store-release-skill).
- **Signing**: gebruik **Play App Signing** (Google bewaart de app-signing-key;
  jij houdt een *upload key*). De keystore is een geheim dat de eigenaar zelf
  aanmaakt/bewaart (`keytool`-stappen staan in Eldor's `android-port.md`).
  `.gitignore` moet `*.keystore`/`*.jks`/`keystore.properties` weren.
- **Target SDK**: Play eist een recente `targetSdk` (controleer de actuele eis bij
  submission; Skip default volgt meestal). 
- **Verplichte Store-assets/forms** (👤, in Play Console):
  - Privacy-policy-URL + (her)gebruik het `github.io`-patroon uit de
    app-store-release-skill — kan dezelfde support-site als iOS zijn.
  - **Data safety**-formulier (Android-tegenhanger van Apple's privacy-labels):
    GRID_BREAKER verzamelt geen data → eenvoudig in te vullen.
  - **Content rating**-questionnaire (IARC).
  - Feature graphic (1024×500) + phone-screenshots + icoon — code-genereren
    zoals de iOS-assets (de asset-generatie-scripts zijn herbruikbaar).
- **Geen IAP** in scope (vrij, geen ads) → geen merchant/tax-setup nodig voor v1
  (i.t.t. Apple's Paid-Apps-stack pas bij verkoop).

---

## 8. Aanbevolen eerste stap

**P0 + P1 + M2a in één blok**, want M2a is de beslissende go/no-go:

1. `source` de Eldor-`android-env.sh`, draai `skip checkup`.
2. `skip init --transpiled-app GridBreakerSkip` + neon-splash + eerste APK.
3. **Render-spike**: `TimelineView(.animation)` + `neonGlow` + één `Canvas`-effect
   op de emulator — beoordeel fps én of de neon-look overeind blijft.

Pas als de spike acceptabel oogt, is de volle M1–M6-port de moeite waard. Valt de
glow/Canvas tegen, dan is de afweging: een visueel *soberder* Android-build
accepteren, of de port heroverwegen. Die beslissing hoort vóór M1, niet erna.

---

## Buiten scope (bewust)

- **Web/Windows** — andere route (TS-herschrijving), niet Skip.
- **Google Play Games Services** — cloud-leaderboards; pas bij Android-tractie.
- **iOS-feature-drift** — elke nieuwe iOS-feature na de port moet in de
  gedeelde *engine* landen (niet in de shell) om pariteit te bewaren (skill §4).
