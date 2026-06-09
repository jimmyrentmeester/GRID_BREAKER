# App Store Connect — step-by-step (Phase D + E)

Follow this once **B1 (Apple Developer Program)** is active and the **two pages are
hosted** (B3/B4). Everything to paste lives in `docs/store-copy.md`; screenshots in
`docs/screenshots/`. Times in parentheses are rough.

## 0. Sign in (2 min)
1. Go to **appstoreconnect.apple.com** → sign in with your developer Apple ID.
2. If prompted, accept the latest **Agreements, Tax, and Banking** (free apps still need
   the free-app agreement accepted; no banking needed for a free app).

## D1 — Create the app (3 min)
1. **My Apps ▸ + ▸ New App**.
2. Platform **iOS**; Name **`GRID_BREAKER`**; Primary language **English (U.S.)**.
3. **Bundle ID**: select `nl.gridbreaker.app` (it appears once Xcode has registered it —
   see E1 if it's not listed yet).
4. **SKU**: any unique string, e.g. `gridbreaker-001`. User Access: Full. **Create**.

## D2 — App information (4 min)
Left sidebar ▸ **App Information**:
- **Subtitle**: `Neon reflex grid-hacking` (from store-copy.md).
- **Category**: Primary **Games**, choose subcategory **Arcade**; Secondary **Action**.
- **Privacy Policy URL**: paste your hosted `…/privacy.html`.
- **Content Rights**: confirm it contains no third-party content (note your music
   decision, B2).
- Save.

## D3 — Age rating (3 min)
App Information ▸ **Age Rating ▸ Edit** → answer the questionnaire. The game has **no
violence, profanity, gambling, or objectionable content** → answer **None** to all → it
lands around **4+**. Save.

## D4 — Pricing & availability (2 min)
Left sidebar ▸ **Pricing and Availability**:
- **Price**: Free (price tier 0).
- **Availability**: all countries/regions (or pick).
- Save.

## D5 — Version listing (10 min)
Left sidebar ▸ **iOS App ▸ 1.0 Prepare for Submission**:
- **Screenshots** — drag the **6.9"** PNGs from
  `docs/screenshots/iphone-6.9-marketing/` (captioned) **or** `iphone-6.9/` (plain) into
  the **6.9" Display** slot, in order 01→05. (Optional: add the 6.5" set; optional: the
  App Preview video from C2 — drop the `.mov` into the same 6.9" slot.)
- **Promotional Text**, **Description**, **Keywords** — paste from store-copy.md.
- **Support URL**: your hosted `…/support.html`. **Marketing URL** (optional): the root.
- **Build**: attach after upload (E2). **What's New**: paste 1.0 note.
- **App Review Information**: your contact (name/phone/email = jimmy.rentmeester@gmail.com);
  Notes: "No login required; everything is offline." Sign-in not required.
- **Version Release**: "Automatically release after approval" (recommended) or manual.
- **Copyright**: `2026 Jimmy Rentmeester`.

## App Privacy (3 min)
Left sidebar ▸ **App Privacy ▸ Get Started/Edit** → **Data Not Collected** (the app
collects nothing). Publish.

---

## E — Build, upload, submit
### E1 — Signing (Xcode, 3 min)
1. Open `App/GRID_BREAKER.xcodeproj` in Xcode, select the **GRID_BREAKER** target ▸
   **Signing & Capabilities**.
2. Check **Automatically manage signing**; **Team** = your new developer team. Xcode
   registers `nl.gridbreaker.app` with your team (this makes it appear in D1).
3. Bump the build if resubmitting: **General ▸ Build** (currently 1).

### E2 — Archive & upload (10 min)
1. Toolbar device selector ▸ **Any iOS Device (arm64)** (not a simulator).
2. **Product ▸ Archive**. When it finishes, the **Organizer** opens.
3. Select the archive ▸ **Distribute App ▸ App Store Connect ▸ Upload** → follow prompts
   (automatic signing). Wait for "Upload successful".
4. The build appears in App Store Connect under the version after ~5–15 min of processing
   (you may get an email). Back in **D5 ▸ Build**, click **+** and select it.

### E3 — (optional) TestFlight (10 min)
Install the uploaded build on your iPhone via **TestFlight** for a final real-device
smoke test (covers plan A2/A3).

### E4 — Submit for review
In the version page, top-right **Add for Review ▸ Submit**. Export compliance question:
the app uses no non-exempt encryption → **No** (already declared via Info.plist). Submit.

### E5 — Review outcome
- **Rejected?** Read the resolution center note; if it's a code issue, send it to me and
  I'll fix it → bump build → re-archive (E2) → resubmit.
- **Approved?** It releases automatically (or click Release). 🎉

## F — Post-launch
Watch **App Analytics** + ratings/reviews. For a fix: change code → bump build → archive →
new version (e.g. 1.0.1) → submit.
