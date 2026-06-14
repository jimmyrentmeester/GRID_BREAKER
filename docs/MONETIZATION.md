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

## Implementation design — Phase 1 tip jar (the "how")

Strategy above is settled; this is the concrete build. Scoped to consumables only
(cosmetics/non-consumables + Restore come in Phase 2).

### Tech choice: StoreKit 2, no backend
Use **StoreKit 2** (async/await, `Product`/`Transaction`), not the legacy SKPaymentQueue.
For a **consumable** tip jar there is **no server and no entitlement store to maintain**:
StoreKit 2 verifies the transaction cryptographically on-device, you grant the thank-you,
then `finish()` it. Consumables are **not restorable** by design, so **no Restore button**
is needed in Phase 1 (it becomes required in Phase 2 when non-consumables ship). This stays
true to the local-authority, no-backend architecture.

### Product IDs (create as Consumable in App Store Connect)
| Product ID | In-fiction name | Suggested price |
| --- | --- | --- |
| `nl.gridbreaker.tip.energydrink` | ENERGY DRINK | €0.99 |
| `nl.gridbreaker.tip.ramstick` | RAM STICK | €2.99 |
| `nl.gridbreaker.tip.gpu` | GPU | €4.99 |
| `nl.gridbreaker.tip.quantumrig` | QUANTUM RIG | €9.99 |

Never hardcode prices in the UI — always render `product.displayPrice` (localized currency).

### Files to add / touch
- **`Services/TipStore.swift` (new)** — `@MainActor @Observable final class TipStore`,
  mirroring `GameStore`'s style. Responsibilities:
  - `products: [Product]` — loaded via `Product.products(for:)`, sorted by `price`.
  - `state` enum: `.idle / .loading / .purchasing(Product) / .thanks / .unavailable / .failed(String)`
    — note the failure carries an **in-world** message, never a raw error (see Game-feel rule).
  - `purchase(_:)` — the flow below.
  - A long-lived `Transaction.updates` listener `Task` (started in `init`, cancelled in
    `deinit`) to catch Ask-to-Buy approvals and interrupted purchases.
  - Injected callback `onTipped: () -> Void` (or a `GameStore` ref) to flip the flag.
- **`Core/Models/SaveData.swift`** — add `var hasTippedEver: Bool = false` (tolerant decode
  already defaults it, like the cosmetics fields).
- **`Persistence/GameStore.swift`** — `var hasTipped: Bool { save.hasTippedEver }` +
  `func markTipped() { guard !save.hasTippedEver else { return }; save.hasTippedEver = true; persist() }`.
- **`UI/TipJarView.swift` (new)** — a sheet: short honest blurb, the tiers (in-fiction name +
  `displayPrice`), purchasing spinner, an in-world thank-you state (reuse the Juice/confetti
  layer), graceful unavailable/offline state. Optional permanent `SPONSOR` tag on the menu.
- **`UI/MenuViews.swift` / hub** — one quiet `SUPPORT THE RUNNER` entry that presents the
  sheet. **Never** after game-over, never mid-session.
- **`Configuration/Products.storekit` (new)** — a StoreKit configuration file wired into the
  Run scheme so the whole flow is testable in the simulator with **no App Store Connect**.

### Purchase flow (StoreKit 2)
```
let result = try await product.purchase()
switch result {
case .success(let verification):
    guard case .verified(let txn) = verification else { state = .failed("…"); return }
    // consumable: grant immediately, persist the flag, then ALWAYS finish
    onTipped()                 // -> GameStore.markTipped()
    state = .thanks
    await txn.finish()         // not finishing => StoreKit re-delivers forever
case .userCancelled: state = .idle
case .pending:       state = .idle    // Ask-to-Buy: the updates listener delivers later
@unknown default:    state = .idle
}
```
The `Transaction.updates` listener runs the same `verified → markTipped → finish` path for
transactions that arrive outside this call (parental approval, retries).

### Correctness / edge cases (the easy-to-miss ones)
- **Always `finish()`** verified transactions, or they re-deliver on every launch.
- Gate on **`AppStore.canMakePayments`** (parental restrictions) → show disabled state.
- **Offline / products fail to load** → friendly "store unavailable" copy, not an error dump.
- **`.pending` (Ask to Buy)** → "waiting for approval"; the listener finishes it later.
- `hasTippedEver` is **idempotent**; tips remain **repeat-purchasable** (that's intended).
- **No raw errors in the UI** (Game-feel anti-pattern). Catch and reframe in-world; if you
  must surface a code, do it in a tiny non-diegetic strip, not over the art.

### Determinism & ethics guarantee
A tip grants **nothing in the engine** — only the render-layer `SPONSOR` tag, which *reads*
`hasTippedEver` and never writes `SessionSnapshot`. The headless determinism sim stays the
regression test (same seed → bit-identical snapshots, tipped or not).

### Testing
1. **`Products.storekit`** config file → test purchase, cancel, Ask-to-Buy, and refunds via
   Xcode's Transaction Manager, entirely offline.
2. **Sandbox** Apple ID on a device before release.
3. Optionally `SKTestSession` unit tests around `TipStore`.

### Maintainer checklist — what only you (👤) can do
Everything else (all the code, the product-ID/price values, the `.storekit` test file, and
the IAP review screenshot once the view exists) is 🤖 build work. The human-only parts:

1. **Agreements, Tax & Banking** in App Store Connect (the real blocker — start early, it can
   take days to verify; nothing sells until all three are green):
   - Accept the **Paid Apps Agreement** (the free-app agreement alone is **not** enough). ⏳ in progress
   - Add **Bank account** (IBAN) for payouts. ⏳ processing (2026-06-14)
   - Complete **Tax forms** — **US W-8BEN submitted ✓ (2026-06-14): Article 12, 0% rate,
     income from sale of applications, foreign TIN = BSN.** (Result: 0% US withholding
     instead of 30%.) Any local tax info / IAP tax category still to confirm.
   - Small Business Program: **already done ✓** (15% rate).
2. **Confirm the offer** — the 4 price points + in-fiction tier names (defaults suggested
   above; your call to change).
3. **Create the 4 Consumable IAPs** in ASC (I'll hand you the exact IDs/prices/names to
   paste, same as we did for Game Center) and attach the review screenshot of `TipJarView`.
4. **Submit the IAPs with an app version** — IAPs are reviewed alongside a build, not on
   their own.
5. **Create a Sandbox tester** (ASC → Users and Access → Sandbox) and **test a real purchase
   on your iPhone** with it — the one thing neither the `.storekit` file nor I can do for you
   (it needs your device + Apple ID). Test buy, cancel, and a refund.

Sequence: do **#1 early** (it gates everything and is slow), then #2 anytime. #3–#5 happen
once I've built the feature and you have a build to attach.

### What was missing from the earlier research (now closed)
The plan had the *strategy* but not: the StoreKit-2-vs-legacy choice + no-backend rationale,
concrete product IDs, the `Transaction.updates` listener (a correctness must), the
`finish()`/`.pending`/`canMakePayments` edge cases, the "no Restore needed for consumables"
clarification, and the `.storekit` test-file setup. All captured above.

## Expectations (honest numbers)

Tip conversion in free apps is typically a fraction of a percent of actives;
the rare public datapoints (e.g. Cameo's 15% tip rate) come from parasocial
contexts that don't transfer to games. With a hobby-scale audience, realistic
outcome is tens of euros per year — i.e. this plan *can* cover the dev fee if
the game finds even a modest audience, and won't if it doesn't. Phase 0
exists so no build effort is wasted finding that out.

## Sources

- [Apple — StoreKit 2 / In-App Purchase (Product, Transaction)](https://developer.apple.com/documentation/storekit/in-app_purchase)
- [Apple — Testing with a StoreKit configuration file](https://developer.apple.com/documentation/storekit/setting-up-storekit-testing-in-xcode)
- [RevenueCat — Building a tip jar feature](https://www.revenuecat.com/blog/engineering/building-a-tip-jar-feature-with-revenuecat/)
- [Apple — App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [RevenueCat — The 15% App Store fee guide](https://www.revenuecat.com/blog/engineering/small-business-program/)
- [Apple — Business models and monetization (IAP types)](https://developer.apple.com/app-store/business-models/)
- [Robert Baer — Apple vs. "Buy Me a Coffee" links](https://medium.com/@robert-baer/my-ongoing-battle-with-apple-over-a-buy-me-a-coffee-link-is-over-9c158df81c05)
- [Daydreamsoft — Ethical monetization system design](https://www.daydreamsoft.com/blog/ethical-monetization-system-design-earning-revenue-without-losing-player-trust)
- [Wayline — Ethical mobile game monetization](https://www.wayline.io/blog/ethical-mobile-game-monetization)
- [Meegle — Game monetization for cosmetics](https://www.meegle.com/en_us/topics/game-monetization/game-monetization-for-cosmetics)
- [PocketGamer.biz — premium iOS market context](https://www.pocketgamer.biz/mobile-mavens/70357/what-does-apple-arcade-mean-for-indie-developers/)
