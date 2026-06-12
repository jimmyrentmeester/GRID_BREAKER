# MONETIZATION — GRID_BREAKER

Plan for monetizing the game. Constraints set by the maintainer (2026-06-12):
**no ads of any kind** (no banners, interstitials, or rewarded video), **no
purchasable gameplay advantage**, goal = **cover costs + pocket money** (offset
the €99/yr dev fee; stay in hobby scope). Everything here is StoreKit-only —
no backend, no accounts, no analytics SDKs — consistent with the deterministic
local-authority architecture (CLAUDE.md, ground truth Part 1.1).

## The hard rule

**Real money never touches the gameplay economy.** Specifically:

- Never sell Credits, Cyberdeck upgrades, shield charges, RAM, continues,
  fever triggers, or campaign skips. Credits stay earned-only.
- Never gate difficulty, modes, or score potential behind purchase.
- Cosmetics are render-layer only: they read engine state, never write it.
  A purchased theme must produce bit-identical `SessionSnapshot`s for the
  same seed (the headless determinism sim is the regression test).
- No FOMO mechanics: no loot boxes, no expiring offers, no countdown-timer
  store, no dark-pattern prompts. Industry guidance on ethical monetization
  converges on transparency, optionality, and cosmetic-only fairness.

## Model: free game + supporter IAPs

Premium (paid-up-front) is rejected: paid iOS games are a shrinking single-digit
slice of store revenue, and a price tag kills the casual discovery a reflex
arcade game depends on. Free download, full game free forever, with two
optional IAP groups:

### 1. Tip jar — "Buy the dev a RAM stick" (Phase 1)

Consumable IAPs at 3–4 price points (e.g. €0.99 / €2.99 / €4.99 / €9.99),
themed in-fiction (ENERGY DRINK / RAM STICK / GPU / QUANTUM RIG). Offering
multiple amounts measurably shifts buyers toward higher tiers (RevenueCat's
tip-jar writeup). Repeat-purchasable by design. One thank-you screen, one
permanent cosmetic "SPONSOR" tag on the menu if desired — nothing else, so
tipping never reads as buying anything.

Placement: a single quiet `SUPPORT THE RUNNER` entry on the menu hub. Never
interrupt a session, never prompt after game-over (that's where desperation
monetization lives). Note: tips inside an app **must** go through Apple IAP —
"Buy Me a Coffee" links out of the app are rejected in review.

### 2. Cosmetic packs (Phase 2)

Non-consumable IAPs (~€1.99–2.99 each), purely visual/audio:

- **Theme packs**: alternate `NeonTheme` palettes — e.g. AMBER TERMINAL
  (retro phosphor), ICE (white/blue), BLOOD NET (red), VAPOR (pink/teal).
  Tokens are already centralized in `UI/NeonTheme.swift`, so a theme is a
  palette struct + a picker; contrast-safety rules still apply.
- **Node skin packs**: alternate daemon/bomb sprite sets (glyphs, runes,
  retro-LCD). Pure sprite swap; hitboxes and lifespans untouched.
- **Synth packs**: alternate `AudioEngine` music loops + SFX voicings
  (e.g. a chiptune set, a darker industrial set). Asset-free synth means
  no licensing cost.
- **Supporter bundle**: all current + future cosmetics, one price (~€6.99).
  The Path-of-Exile-style supporter pack is the accepted ethical pattern:
  cosmetic-only, priced as patronage.

One default theme stays free and complete — cosmetics are for people who
*want* to pay, not people who feel they have to. Tie new packs to update
moments, not to scarcity.

### Explicitly out

Ads (all forms), selling Credits/upgrades, subscriptions, battle pass,
loot boxes/gacha, timed exclusives, web high-score backend perks.

## Supporting engagement layer: Game Center (built — Run #75, D25)

Free cosmetics/tips only earn if people keep playing. Game Center supplies the
retention layer at €0: global endless + daily leaderboards (Apple-hosted — the
web backend the brief wanted, without a server) and 13 achievements. All of it
is earnable-only and report-only; nothing Game Center is ever for sale, and
declining auth changes nothing. See `Services/GameCenterService.swift`.

## Phases

**Phase 0 — ship free, instrument nothing.** Release with zero monetization.
Validate that anyone plays. Monetizing pre-audience costs effort and earns ~€0.

**Phase 1 — tip jar (1–2 sessions).** Paid Apps agreement + banking in App
Store Connect; **enroll in the App Store Small Business Program first** (15%
commission instead of 30% under $1M/yr — enrollment is not retroactive, so do
it before the first sale). StoreKit 2 consumables, a `TipJarView`, a `Store`
service alongside `GameStore`. Persist a `hasTippedEver` flag for the SPONSOR
tag. Test with StoreKit configuration files + sandbox.

**Phase 2 — first cosmetic pack (2–3 sessions).** Theme engine: make
`NeonTheme` instantiable per-palette, persist selection in `SaveData`
(tolerant decoding already handles new fields), `ThemePickerView`, one
non-consumable + restore-purchases flow (required by review). Ship one pack;
add more only if anything sells.

**Phase 3 — only if traction.** Supporter bundle, node skins, synth packs,
seasonal free theme drops as goodwill.

## Expectations (honest numbers)

Tip conversion in free apps is typically a fraction of a percent of actives;
the rare public datapoints (e.g. Cameo's 15% tip rate) come from parasocial
contexts that don't transfer to games. With a hobby-scale audience, realistic
outcome is tens of euros per year — i.e. this plan *can* cover the dev fee if
the game finds even a modest audience, and won't if it doesn't. Phase 0
exists so no build effort is wasted finding that out.

## Sources

- [RevenueCat — Building a tip jar feature](https://www.revenuecat.com/blog/engineering/building-a-tip-jar-feature-with-revenuecat/)
- [Apple — App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [RevenueCat — The 15% App Store fee guide](https://www.revenuecat.com/blog/engineering/small-business-program/)
- [Apple — Business models and monetization (IAP types)](https://developer.apple.com/app-store/business-models/)
- [Robert Baer — Apple vs. "Buy Me a Coffee" links](https://medium.com/@robert-baer/my-ongoing-battle-with-apple-over-a-buy-me-a-coffee-link-is-over-9c158df81c05)
- [Daydreamsoft — Ethical monetization system design](https://www.daydreamsoft.com/blog/ethical-monetization-system-design-earning-revenue-without-losing-player-trust)
- [Wayline — Ethical mobile game monetization](https://www.wayline.io/blog/ethical-mobile-game-monetization)
- [Meegle — Game monetization for cosmetics](https://www.meegle.com/en_us/topics/game-monetization/game-monetization-for-cosmetics)
- [PocketGamer.biz — premium iOS market context](https://www.pocketgamer.biz/mobile-mavens/70357/what-does-apple-arcade-mean-for-indie-developers/)
