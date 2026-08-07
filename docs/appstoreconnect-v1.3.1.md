# App Store Connect — v1.3.1 release (ASO metadata overhaul)

Paste-ready checklist for the 1.3.1 submission. Everything here is decided; the values are
final. Tag: 👤 = only you can do it (login / your Mac / a signature), 🤖 = already done in
the repo.

## Status
- 🤖 **Xcode ready:** `MARKETING_VERSION = 1.3.1`, `CURRENT_PROJECT_VERSION = 7` (committed +
  pushed, `6ee25cf`). Builds clean. On-device / icon / in-game name stays **GRID_BREAKER**.
- 👤 **Two blockers only I can't do for you:** (1) signing into App Store Connect; (2) the
  **Archive → Upload** of the build (needs your Mac + Apple ID signing). Everything else is
  paste-and-click below. *Once you're signed into ASC in Chrome, I can drive the metadata
  staging for you — just say so.*

---

## The final metadata (copy-paste)

| Field | Value |
|---|---|
| **App Name** (30/30) | `Grid Breaker: Neon Reflex Game` |
| **Subtitle** (30/30) | `Offline tapping, no ads or IAP` |
| **Keywords** (91/100) | `cyberpunk,reaction,speed,hacker,synthwave,retro,endless,combo,timing,score,skill,hard,daily` |
| **Promotional Text** (169/170) | `Tap fast, chain combos into Fever, outlast the rising grid. Now with a 16-core boss campaign, stackable run modifiers & a daily streak. No ads, no tracking — pure skill.` |
| **Primary Category** | Games → **Arcade** *(switch from Action)* |
| **Version** | `1.3.1` |

**What's New** (paste from `docs/RELEASE_NOTES_v1.3.md` — this build carries the whole staged
v1.3 + Cosmetics 2.0 + the PROTOCOL Fever fix, so use the full Campaign 2.0 / modifiers /
daily-streak notes there).

---

## Steps

### 1. 👤 Sign in
appstoreconnect.apple.com → your developer Apple ID. (Free-app agreement stays fine; no
banking needed — we're not enabling IAP in this release.)

### 2. Switch the category (App Information — not version-specific)
My Apps ▸ GRID_BREAKER ▸ **App Information** (left sidebar) ▸ **Primary Category → Arcade**.
Secondary can stay Action or move to Casual. Save.
- ⚠️ The measured benchmark shows the app currently surfaces as **"Action Apps"**, so today's
  live primary is Action. This is the switch. If ASC lets you save it now, great; if it says
  it applies with the next version, that's fine — the next version is 1.3.1 anyway.

### 3. Create the 1.3.1 version
**App Store** tab ▸ the **(+) Version or Platform** button (top-left of the version list) ▸
enter **1.3.1** ▸ Create. This opens an editable "Prepare for Submission" page.

### 4. Fill the version metadata (paste the table above)
On the 1.3.1 version page (English (U.S.) localization):
- **Promotional Text** → paste.
- **Keywords** → paste (no spaces after commas — it's already formatted).
- **Description** → keep the current one (or paste the corrected v1.3 description from
  RELEASE_NOTES; either is fine — description isn't indexed for search).
- **What's New in This Version** → paste from RELEASE_NOTES_v1.3.md.
- **App Name** + **Subtitle** (shown in the localized info block) → paste the new values.
- **Screenshots / App Preview** → leave as-is (the analysis says visuals aren't the problem).

### 5. 👤 Archive & upload the build
Xcode ▸ **Product → Archive** (scheme GRID_BREAKER, Release, "Any iOS Device") →
**Distribute App → App Store Connect → Upload**. Wait 5–60 min for processing.
Then on the 1.3.1 version page ▸ **Build** section ▸ select build **7 (1.3.1)**.
- Export compliance is pre-answered in the build (`ITSAppUsesNonExemptEncryption = NO`), so
  no encryption prompt.

### 6. Submit
Once the build is attached: **Add for Review → Submit for Review**. No pricing/IAP/Game
Center changes in this release, so there's nothing else to answer.

---

## What NOT to touch (from the ASO analysis)
- Don't change screenshots or the icon — the funnel proves visuals convert fine (16.5% imp
  → PDP, 23.3% PDP → install); the problem is **volume in**.
- Don't add "free"/"gratis" to name or subtitle — Apple rejects price references in metadata.
- Don't start Apple Search Ads campaigns or add a payment method just to see popularity
  scores — not worth it; ship and measure instead.
- Change **one field per iteration** after this. This release changes name + subtitle +
  keywords + category together *once*; then hold.

## Measurement baseline (record before you submit)
Re-check these in ~3–4 weeks in **App Analytics** (Source Type = App Store Search), same as
the addendum's 90-day nulmeting:
- **Impressions: 883 · Product Page Views: 146 · Downloads: 34** (9 May – 6 Aug 2026).
Rising impressions = the keyword change worked. Flat impressions but you now appear for the
right terms = give it another cycle.
