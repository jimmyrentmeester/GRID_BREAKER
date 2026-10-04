# ASO-audit — oktober 2026

Ronde gestart 2026-10-04 (skill `aso-ronde`). Vorige ASO-iteratie: v1.3.1 (2026-08-07),
alleen metadata — zie `docs/appstoreconnect-v1.3.1.md`. Nulmeting toen (9 mei – 6 aug):
**883 impressies · 146 productpagina-views · 34 downloads** (90 dagen).

## Fase 0 — Inventaris (live listing, v1.3.2 READY_FOR_SALE)

| Onderdeel | Live waarde | Opmerking |
|---|---|---|
| App-UI-talen | `en` (+ Base) | Niet uitbreiden; extra store-listings mogen wel |
| Store-listings | **alleen en-US** | Geen enkele andere lokalisatie → nul cross-localization |
| Naam (30/30) | `GRID_BREAKER: Neon Reflex Game` | Wijkt af van het plan in v1.3.1-doc (`Grid Breaker: …`). `GRID_BREAKER` met underscore is waarschijnlijk één token → "grid" en "breaker" vindt Apple mogelijk niet los |
| Ondertitel (29/30) | `Offline arcade, no ads or IAP` | "no/or" zijn verspilde tekens |
| Keywords (95/100) | `cyberpunk,tap,reaction,speed,hacker,synthwave,retro,endless,combo,timing,score,skill,hard,daily` | Geen dubbelingen met naam/ondertitel. Ontbreekt: `whack`/`mole` (het genre!), `grid`, `breaker` |
| Promotietekst | **leeg** | Gratis conversieruimte (170 tekens, niet geïndexeerd, wel zichtbaar) |
| What's New | `Ready for iOS 27.` | |
| Marketing/support-URL | ingevuld (github.io) | ok |
| iPhone 6,9" shots | 4 — volgorde **04-modifiers, 03-campaign, 01-menu, 02-gameplay** | Gameplay staat **als laatste**; de eerste twee (in zoekresultaat naast de video zichtbaar) zijn modifiers + campaign. Geen captions-check gedaan |
| iPad 13" shots | 5 — volgorde 01-menu, 03-campaign, 02-fever, 05-cosmetics, 04-cyberdeck | |
| Previews | iPhone 6,9" (`app-preview-promo-886x1920.mov`) + iPad 13", beide COMPLETE, posterframe 00:00:05:01 | Zijn meegegaan naar 1.3.2 |
| Analytics-rapportverzoek | **geen** | Ophalen via API kan niet; eerste verzoek vergt Admin-key |

Overig:
- `docs/store-copy.md` bevat al een **NL-listing** (ondertitel, promo, keywords), maar die is
  nooit in App Store Connect gezet.
- De nameting van v1.3.1 (gepland begin sept, zie `QUESTIONS.md` Q9) is nog niet gedaan;
  dat valt samen met Fase 1 hieronder.

## Fase 1 — Data

Bron: screenshots van de App Store Connect-app (2026-10-04), top 10 per metriek.
**Periode staat niet in beeld** (navragen). Downloads = *Total Downloads* (incl. her-downloads),
niet First-Time. "≤1" = land valt buiten de top 10 van die metriek.

| Land | Impressies | Pagina-views | Imp→pagina | Downloads | Listing | Advies |
|---|---:|---:|---:|---:|---|---|
| VS | 2.986 | 41 | **1,4%** | 16 | en-US | Eerste beeld zwak (screenshotvolgorde!); es-MX = extra keyword-veld |
| VK | 267 | ≤1 | ≤0,4% | ≤1 | en-US (fallback) | **en-GB** |
| Australië | 149 | 1 | 0,7% | 2 | en-US (fallback) | profiteert van en-GB |
| Nederland | 137 | 19 | 13,9% | **48** | en-US | **nl-NL**; downloads > pagina-views → veel via directe links/netwerk |
| Japan | 126 | 3 | 2,4% | 4 | en-US | **ja** (eigen taal primair) |
| Maleisië | 68 | ≤1 | — | ≤1 | en-US | — |
| Canada | 47 | 4 | 8,5% | 1 | en-US | — |
| India | 40 | ≤1 | — | ≤1 | en-US | profiteert van en-GB |
| Turkije | 36 | ≤1 | — | ≤1 | en-US | — |
| Duitsland | 31 | 2 | 6,5% | 3 | en-US | te klein voor nu |

Lezing:
- **Volume is niet meer het probleem**: top 10 alleen al ≈ 3.890 impressies (nulmeting 883 in
  90 dagen). Hoeveel daarvan door v1.3.1 komt hangt af van de periode.
- **Het lek zit nu in impressie → pagina**: VS 1,4%, VK/AU < 1%. Dat is het eerste beeld
  (icoon, naam, video + eerste twee screenshots). Live staan modifiers + campaign vooraan en
  gameplay als laatste — de grootste hefboom, maar valt buiten de afgesproken scope.
- Nederland converteert wél (thuismarkt, directe links); een NL-listing helpt vooral het zoeken.

## Afspraak scope (2026-10-04)

Akkoord van Jimmy: deze ronde **alleen nieuwe store-listings + promotietekst**. en-US naam,
ondertitel, keywords en screenshots blijven ongewijzigd, zodat de v1.3.1-meting zuiver blijft;
die (incl. `whack,mole` en de screenshotvolgorde) volgen in de ronde daarna.

## Fase 2 — Titels en keywords (concept, nog niet geüpload)

Bron van waarheid: `docs/release/aso-1.3.3/metadata.py` (valideert; `--json` → `metadata.json`).

| Locale | Naam | Ondertitel | Keywords | Promo |
|---|---|---|---|---|
| en-US | ongewijzigd | ongewijzigd | ongewijzigd | **nieuw** (169) — kan direct op 1.3.2, zonder review |
| en-GB (nieuw) | `Grid Breaker: Neon Reflex Game` | = en-US | en-US − `skill,hard` + `whack,mole` (95) | = en-US |
| nl-NL (nieuw) | `Grid Breaker: Neon Reflex Spel` | `Offline tikspel zonder reclame` | alleen NL-termen (100) | NL (168) |

Keuzes:
- **en-GB** gebruikt de spatievorm van de naam: `GRID_BREAKER` is waarschijnlijk één token,
  zodat "grid"/"breaker" niet los gevonden worden. en-GB is daarmee meteen een natuurlijk
  experiment t.o.v. en-US.
- **nl-NL** bevat geen Engelse keywords meer (de oude draft in `store-copy.md` wel): in de
  NL-store telt en-GB al mee, dus `cyberpunk,combo,hacker,…` zouden dubbel zijn. `mol,meppen`
  = whack-a-mole in het Nederlands. Beschrijving is opnieuw vertaald vanaf de huidige EN-tekst
  (oude NL-draft noemde nog FLOW en 10 cores) en meldt dat de app Engelstalig is.
- Nieuwe locales vragen een **nieuwe versie (1.3.3)** en dus een build (Fase 5).

### Status App Store Connect (2026-10-04)

Akkoord Jimmy: versie 1.3.3 + en-GB/nl-NL + screenshotvolgorde. **Niet** akkoord gegeven
voor de en-US-promotietekst → en-US promo blijft leeg (audit meldt dat als enige gat).
ja en es-MX: niet gekozen, staan open voor een volgende ronde.

- ✅ Versie **1.3.3** aangemaakt (`c758d0b2-…`), `releaseType: MANUAL`; nieuwe appInfo `f8e0dbe5-…`.
- ✅ en-GB + nl-NL: naam/ondertitel/privacy-URL (appInfo) en beschrijving, keywords, promo,
  What's New, support- en marketing-URL (versie) — letterlijk uit `metadata.json`.
- ✅ en-US What's New: `Stability fixes and polish.` (naam/ondertitel/keywords ongewijzigd).
- ✅ `metadata_ai__audit_localizations`: enige bevinding = en-US promo leeg (bewust).

## Fase 3 — Screenshots

Geen nieuwe beelden deze ronde; alleen de **volgorde** in 1.3.3 (en-GB/nl-NL erven die):
- iPhone 6,9": 02-gameplay → 03-campaign → 04-modifiers → 01-menu (was: modifiers eerst, gameplay laatst)
- iPad 13": 02-fever → 03-campaign → 04-cyberdeck → 05-cosmetics → 01-menu
- Alles COMPLETE. Volgende ronde: captions met zoektermen, ja-captions als ja erbij komt.

## Fase 4 — Preview

Bestaande previews (iPhone + iPad) zijn meegegaan naar 1.3.3, beide COMPLETE. Geen nieuwe video.

## Fase 5 — Build

- `MARKETING_VERSION` 1.3.2 → **1.3.3**, `CURRENT_PROJECT_VERSION` 8 → **9** (beide configuraties).
- Wacht op commit + push → Xcode Cloud → build koppelen → preflight. Indienen alleen op verzoek.

## Fase 6 — Nameting

Plan: 2–4 weken na release van 1.3.3, per land impressies → pagina-views → downloads, vergeleken
met de tabel in Fase 1. Let vooral op imp→pagina in VS/VK/AU (screenshotvolgorde) en op
zoekverkeer in NL/VK (nieuwe listings).
