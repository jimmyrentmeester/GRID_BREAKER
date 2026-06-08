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
- [x] **A1 🤖 Final code/QA sweep** (Run #67) — clean build; no temp/debug residue;
      version 1.0 / build 1; invariant fuzz **1,440 runs** (60 seeds × starter+maxed deck ×
      endless + 10 cores + flow) → **0 violations**. Balance was sim-validated when last
      tuned and is unchanged since.
- [ ] **A2 👤 On-device playthrough** (real iPhone) — the one thing the sim can't judge:
      audio/SFX mix + haptics feel; full onboarding (3 levels → payday → guided shops);
      the 3·2·1 countdown; streak multiplier + milestones; new cosmetics/cyberdeck;
      boot splash; every mode end-to-end. Jot down anything that feels off.
- [ ] **A3 👤 Accessibility pass with VoiceOver ON** (device) — menus/shops/settings/HUD
      navigable; Reduce Motion respected. 🤖 fixes any gaps found.
- [ ] **A4 🤖 Apply A2/A3 feedback** — any feel/tuning/bug tweaks you flag.
- [ ] **A5 🤖 Version freeze** — keep `MARKETING_VERSION 1.0`; bump
      `CURRENT_PROJECT_VERSION` (build) for each new archive upload.

## Phase B — Legal & accounts (👤 blockers; 🤖 assists)
- [~] **B1 👤 Apple Developer Program** — maintainer **approved** the €99/yr enrollment;
      action: enroll at developer.apple.com.
- [x] **B2 👤 Music rights** — maintainer decision: keep the Gemini-generated tracks
      as-is. (Risk noted: verify the tool's terms allow commercial distribution before
      submit; swap is drop-in if ever needed.)
- [~] **B3 🤖→👤 Privacy policy** — written: `docs/site/privacy.html` ("Data Not
      Collected"). 👤 to: set the contact email + host (see `docs/site/README.md`) → URL.
- [~] **B4 🤖→👤 Support page** — written: `docs/site/support.html` (+ `index.html`
      landing). 👤 to: set email + host → Support URL.

## Phase C — Store listing content (🤖 produces, 👤 reviews)
- [ ] **C1 🤖 Screenshots** — required iPhone sizes **6.9"** (iPhone 16 Pro Max) and
      **6.5"/6.7"** (older Plus/Pro Max). Capture polished frames: menu, gameplay+Fever,
      a streak/milestone moment, campaign briefing, cosmetics. (Use temp state hooks +
      `simctl io` per the verification workflow.)
- [ ] **C2 🤖 (optional) App Preview video** — a 15–30s gameplay capture.
- [ ] **C3 🤖 Store copy** — app name, subtitle (≤30 chars), promotional text, full
      description, keywords (100 chars), what's-new. 👤 tweaks voice.
- [x] **C4 App icon** — new neon "breached grid" icon shipped (Run #65).

## Phase D — App Store Connect setup (👤, using C content)
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
