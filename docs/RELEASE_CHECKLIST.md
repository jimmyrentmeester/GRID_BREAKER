# RELEASE CHECKLIST — GRID_BREAKER

Status of App Store readiness. The **code/config** side is done in-repo; the
**account / App Store Connect** side needs the maintainer + an Apple Developer account.

## ✅ Done in-repo (Run #39)
- **App icon is opaque** — flattened the 1024 icon (App Store rejects icons with an
  alpha channel). Single-size 1024 asset → Xcode generates all sizes.
- **Version 1.0 (build 1)** — `MARKETING_VERSION` 0.14 → 1.0; the About screen reads it.
- **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` (no encryption beyond
  OS defaults), so submissions skip the export-compliance prompt.
- **iPhone-only** — `TARGETED_DEVICE_FAMILY = 1` (the layout is iPhone-portrait; was
  universal). Revert to `"1,2"` only if you want to support iPad.
- Already in place: branded launch screen, portrait lock, status bar hidden,
  deployment target iOS 17, bundle id `nl.gridbreaker.app`, signing team configured
  (`Automatic`), no privacy-sensitive APIs used (no camera/mic/location/tracking).

## ⚠️ Needs the maintainer (cannot be automated here)
1. **Apple Developer Program** — €99/yr membership. NOTE: this is the one real cost vs.
   the project's €0/hobby ethos (D2) — a genuine go/no-go decision.
2. **Music licensing** — the bundled `Music/*.mp3` are your own files; confirm you hold
   distribution rights for any track shipped in a public build. (Swap to royalty-free
   /original tracks if unsure — drop-in via the `Music/` folder, no code change.)
3. **App Store Connect — create the app record**: bundle id `nl.gridbreaker.app`, name
   ("GRID_BREAKER"), subtitle, primary category **Games** (secondary: Arcade/Action),
   age rating questionnaire (likely 9+ for mild sci-fi action; no objectionable content).
4. **Privacy** — declare **"Data Not Collected"** (the app stores only local
   UserDefaults; no analytics, accounts, or network). Apple still requires a **Privacy
   Policy URL** for every app — host a short "no data collected" policy and link it.
5. **Screenshots** — required iPhone sizes: 6.9" (e.g. 16 Pro Max) and 6.5"/6.7".
   Capture from device/sim: menu, a fever moment, campaign briefing, cosmetics.
6. **Store copy** — description, keywords, promotional text, support URL (required),
   marketing URL (optional).
7. **Pricing & availability** — free / paid; territories.
8. **Upload & submit** — Xcode: Product ▸ Archive (Release) ▸ Distribute App ▸ App Store
   Connect (or Transporter). Then TestFlight (optional) → Submit for Review.

## Nice-to-have before 1.0 (optional)
- **Q6 real-device audio listen** — confirm the FM SFX set + music/effects mix + the
  purchase chime sound right on hardware (the only open QUESTIONS item).
- **Campaign feel-tune** — targets/budgets are sim-validated; a human playtest may
  want small tweaks (all in `Campaign.swift`).
- Accessibility once-over (VoiceOver labels on the menu/shop controls).
