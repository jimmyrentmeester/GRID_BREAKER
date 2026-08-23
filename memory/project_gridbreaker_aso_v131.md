---
name: project_gridbreaker_aso_v131
description: "GRID_BREAKER v1.3.1 ASO metadata release — submitted 2026-08-07, measure impressions early Sept."
metadata: 
  node_type: memory
  type: project
  originSessionId: e15ba1d2-cd47-43d7-b56b-07356ba78cbb
  modified: 2026-08-07T20:06:54.263Z
---

GRID_BREAKER (iOS reflex game, `~/GRID_BREAKER`, live on App Store) shipped **v1.3.1**
(build 7) on **2026-08-07** — an ASO metadata overhaul, submitted for review. This version
also carries all the previously-staged content (Campaign 2.0, Cosmetics 2.0, the PROTOCOL
Fever fix). Driven by an ASO research doc + measured-funnel addendum: the app had a
**discovery/volume** problem (90-day baseline **883 impressions → 146 PDP views → 34
downloads**), not a conversion one — so no visual assets changed, only the 160 indexed chars.

Changes: App Store **name** `GRID_BREAKER` → `Grid Breaker: Neon Reflex Game` (on-device/icon
name STAYS `GRID_BREAKER`); **subtitle** → `Offline arcade, no ads or IAP`; **keywords** →
`cyberpunk,tap,reaction,speed,hacker,synthwave,retro,endless,combo,timing,score,skill,hard,daily`;
**category** Action → **Casual** (Apple retired the Arcade subcategory). Full record +
paste-ready values in `docs/appstoreconnect-v1.3.1.md` and `docs/store-copy.md`.

**Why / follow-up:** ASO takes weeks to re-index. **Measure ~early Sept 2026** in App
Analytics (Source Type = App Store Search) vs the 883/146/34 baseline — rising *impressions*
means the keyword change worked. **Rule for next time:** change only ONE metadata field per
iteration so the effect is attributable. See [[project_gridbreaker_site_deploy]].
**Also learned:** the claude-in-chrome MCP runs in a separate Chrome profile from the user's
logged-in session, so it could NOT drive App Store Connect (login wall, and entering the
Apple ID is prohibited) — ASC steps are 👤 hand-offs via a paste-ready checklist.
