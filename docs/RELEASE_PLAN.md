# RELEASE PLAN — GRID_BREAKER → App Store

The step-by-step plan we follow to ship 1.0. Owner tags: **👤 = maintainer**
(account/hardware/legal — can't be automated here), **🤖 = agent** (I can do this in a
run). Status: `[ ]` todo · `[~]` in progress · `[x]` done. The in-repo readiness from
RELEASE_CHECKLIST.md (opaque icon, v1.0, export compliance, iPhone-only, signing) stays
valid — this plan is the ordered path on top of it.

## Critical path (read first)
The whole release hinges on **two 👤 decisions**: **B1 (Apple Developer account, €99/yr)**
and **B2 (music rights)**. Nothing ships without B1. Everything else (final QA, privacy &
support pages, screenshots, store copy) can be **prepped in parallel now** so that the
moment B1 is done, we paste-and-submit. Suggested parallelism: you start B1+B2; I do
A1 + B3/B4 + C in the meantime.

---

## Phase A — Lock the build
- [~] **A1 🤖 Final code/QA sweep** — Run #67 was green, but Runs #69–72 changed the
      engine (D23 pressure curve, ramCritical, worm grace), all SFX (D24) and gameplay
      feedback since. **Redo before archiving:** clean build, no debug residue, and
      re-run the invariant fuzz across endless + 10 cores + flow.
- [~] **A2 👤 On-device playthrough** (real iPhone) — audio mix (Q6 ✓) and the endless
      curve (Q7 ✓) are approved on device. Still to walk once: the **new tutorial
      streak lesson (beat 7)**, PB-toast + run recap + low-RAM warning in play,
      campaign BEST scores on the level select, and a full onboarding → shops pass.
- [ ] **A3 👤 Accessibility pass with VoiceOver ON** (device) — menus/shops/settings/HUD
      navigable; Reduce Motion respected. 🤖 fixes any gaps found.
- [ ] **A4 🤖 Apply A2/A3 feedback** — any feel/tuning/bug tweaks you flag.
- [ ] **A5 🤖 Version freeze** — keep `MARKETING_VERSION 1.0`; bump
      `CURRENT_PROJECT_VERSION` (build) for each new archive upload.

## Phase B — Legal & accounts (👤 blockers; 🤖 assists)
- [x] **B1 👤 Apple Developer Program** — enrolled; paid developer account active.
- [x] **B2 👤 Music rights** — maintainer decision: keep the Gemini-generated tracks
      as-is. (Risk noted: verify the tool's terms allow commercial distribution before
      submit; swap is drop-in if ever needed.)
- [~] **B3 🤖→👤 Privacy policy** — written + email set (`docs/site/privacy.html`, "Data
      Not Collected"). 👤 to: host (see `docs/site/README.md`) → Privacy URL.
- [~] **B4 🤖→👤 Support page** — written + email set (`docs/site/support.html` + landing).
      👤 to: host → Support URL.

## Phase C — Store listing content (🤖 produces, 👤 reviews)
- [x] **C1 🤖 Screenshots** (Run #69) — 5 frames captured on iPhone 16 Pro Max at
      **1320×2868 (6.9")** + resized **1242×2688 (6.5")** set, in
      `docs/screenshots/{iphone-6.9,iphone-6.5}/`: menu, Fever gameplay (×6, streak),
      campaign ladder, cyberdeck, cosmetics. 👤 uploads in App Store Connect.
      **Re-shot on the current build (Run #74):** ×10 Fever + STREAK ×5, campaign
      BEST scores, NEXT ◆ hint — plain + marketing sets both refreshed.
- [x] **C2 🤖 App Preview video** — **upload `docs/preview/app-preview-promo-886x1920.mov`**
      (Run #73): the Run #69 capture rebuilt to the actual App Preview spec
      (**886×1920 portrait, 30 fps**, H.264 + AAC, 25.5 s, ~6 MB) with a subtle neon
      bloom/grade, eight timed caption beats (BREACH THE GRID → … → JACK IN NOW) and
      an Arcade_Fever music bed (the raw capture had **no audio track**). Reproducible
      via `scripts/make_preview_promo.sh` (needs ffmpeg). The original
      `app-preview-6.9.mov` (1320×2868 @ ~50 fps, silent) is kept as source — it does
      NOT meet the preview spec; don't upload it.
- [x] **C1b 🤖 Marketing (captioned) screenshots** — `docs/screenshots/iphone-6.9-marketing/`
      (+ 6.5"): neon headline + framed shot per state. Use either these or the plain set.
- [x] **C3 🤖 Store copy** — `docs/store-copy.md`: name, subtitle ("Neon reflex
      grid-hacking"), promo text, description, keywords, what's-new, metadata. 👤 review.
- [x] **C4 App icon** — new neon "breached grid" icon shipped (Run #65).

## Phase D — App Store Connect setup (👤, using C content)
> 📘 Click-by-click guide: **`docs/appstoreconnect-walkthrough.md`** (covers D + E).
- [ ] **D1 👤 Create app record** — bundle id `nl.gridbreaker.app`, name "GRID_BREAKER",
      primary category **Games**, secondary **Arcade** (or Action).
- [ ] **D2 👤 Age rating** — questionnaire → likely **9+** (mild/infrequent fantasy
      violence; no objectionable content).
- [ ] **D3 👤 Privacy** — "Data Not Collected"; paste the B3 Privacy URL.
- [ ] **D4 👤 Pricing & availability** — Free, all territories (suggested).
- [ ] **D5 👤 Upload listing** — paste C3 copy, upload C1 screenshots (+C2 video), icon.

## Phase E — Build, test, submit (👤; 🤖 preps)
- [ ] **E1 👤 Signing** — Automatic signing resolves a distribution profile for
      `nl.gridbreaker.app` under the new team.
- [ ] **E2 👤 Archive & upload** — Xcode ▸ Product ▸ Archive (Release) ▸ Distribute App ▸
      App Store Connect (or Transporter).
- [ ] **E3 👤 (optional) TestFlight** — internal install on your device; final smoke test.
- [ ] **E4 👤 Submit for review** — attach the build, export compliance = **No**, submit.
- [ ] **E5 🤖/👤 Handle review feedback** — fix any rejection (🤖 for code), bump build, resubmit.

## Phase F — Launch & post-launch
- [ ] **F1 👤 Release** — auto on approval, or manual.
- [ ] **F2 🤖/👤 Monitor** — crashes/reviews; hotfix → bump build → resubmit if needed.

---

## What I (🤖) can start on right now, in parallel with B1/B2
1. **A1** final QA sweep (confidence the build is submission-ready).
2. **B3 + B4** the privacy + support HTML pages (you just host them).
3. **C3** the store copy draft.
4. **C1** the screenshots.

Recommended first run: **A1 (final QA sweep)** + **B3/B4 (privacy + support pages)** — so
you can do the hosting while I move to copy + screenshots. Say the word and I'll start.
