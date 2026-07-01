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

**The reinstall rule (2026-06-27).** Consumables are not restorable, so the
`hasTippedEver` flag (and the SPONSOR tag) is lost on a reinstall. For a tag
that's acceptable; for anything *permanent* it is not. Hard rule: **a tip
grants only the SPONSOR tag — anything lasting (palettes, trails, icons) must
be a restorable non-consumable** (the Phase 2 Supporter Pack). And the SPONSOR
tag shows on the **menu only, never on leaderboards** — otherwise it becomes a
status marker and thus soft pressure to buy.

### 2. One Supporter Pack, not loose packs (Phase 2 — revised 2026-06-27)

Loose €1.99 theme packs create exactly the shop dynamic to avoid: many SKUs,
per-drop buying pressure, FOMO-adjacent catalog churn. The honest pattern is
**patronage** — one purchase, everything in it:

> **SUPPORTER PACK — €4.99, non-consumable, one SKU.** Contents: 2–3
> exclusive palettes (their own family — e.g. animated "LIVING NEON"
> variants), 1 exclusive trail, the SPONSOR tag, and an alternate app icon.
> With a **Restore Purchases** button (required for non-consumables, and the
> fix for the reinstall problem above). Standing promise: future
> supporter-tier cosmetics land *inside* the pack — you buy patronage, not a
> product line.

Guardrails that keep it non-predatory:
- The free tier stays complete **and keeps growing** — every paid drop is
  paired with a free drop.
- Paid items are *different*, never *better* — the free tier gets the same
  glow/animation budget.
- Purchased and earned cosmetics are separate axes: the prestige unlocks
  (Cosmetics 2.0 below) can **only** be earned, never bought. Money buys
  patronage; skill buys prestige. Neither substitutes for the other.
- The determinism sim stays the regression test (same seed → bit-identical
  snapshots, pack owned or not).

Ideas that stay on the shelf until the pack proves demand: node glyph sets as
paid items (better as CR items — see below), synth voicing packs (chiptune /
industrial — the code-synth makes them licensing-free but they're real build
effort).

### Explicitly out

Ads (all forms), selling Credits/upgrades, subscriptions, battle pass,
loot boxes/gacha, timed exclusives, web high-score backend perks.
Also out: **rarity tiers/colors** on cosmetics ("epic/legendary") — that's
psychological pressure architecture. The catalog stays flat and honest:
price, preview, done.

## Cosmetics 2.0 — the free layer first (pre-monetization, 2026-06-27)

The current cosmetics layer is too thin to ever carry a paid tier — and too
thin as a retention layer, which is the prerequisite for *any* monetization.
Today: 7 purchasable palettes (pure color swaps, 500–1500 CR) and 6 trails
(parameter variants of one beam). Four upgrades, all free/CR-driven, all
render-layer only:

### 2.0a — Prestige cosmetics (the unfulfilled promise) ⭐ biggest impact
`Campaign.swift` already states: *"Stars only ever unlock cosmetics, never
access or power"* — but the 48 earnable stars unlock **nothing** today.
Proposal (earn-only, never purchasable):

| Achievement | Unlock |
|---|---|
| 12★ | **"Chrome"** trail |
| 24★ | **"Circuit"** palette |
| All 16 cores cleared | **"Monolith"** alternate app icon |
| 48★ (all flawless+fast) | **"Monolith Gold"** palette — animated, the rarest item in the game |
| 7-day Daily streak | **"Daybreak"** trail |

This gives the replay layer (stars, streak) a *visible* reward at zero cost,
and creates the honest contrast with the Supporter Pack later: earning and
buying are separate axes.

### 2.0b — Live preview (the biggest UX gap)
You currently buy blind off a ~30 pt swatch. Tapping an unowned palette
should re-theme the whole menu chrome temporarily (non-destructive, a
"PREVIEW" badge, until dismissed) — technically trivial: set
`NeonTheme.current` without `store.equipPalette`. Bonus fix: an
unaffordable row currently does *nothing* on tap (`MenuViews.swift`
`tapped(_:)` has no else branch) — show "NEED 240 MORE CR" feedback.

### 2.0c — New cosmetic surfaces
- **Node glyph sets** (daemon/bomb draw styles: "Runes", "Retro LCD",
  "Katakana") — a third CR category next to palettes/trails, 600–1000 CR,
  drawn in code like everything else. Hitboxes/lifespans untouched.
- **Alternate app icons** (`setAlternateIconName`) — cheap to build (the
  icon generator exists), high delight; partly tied to prestige (2.0a).
- **Synth voicing packs** — Phase 3 / Supporter Pack material (real effort).

### 2.0d — Shop UX
Tabs per category (PALETTES / TRAILS / GLYPHS / ICONS) once glyphs land;
"how to earn" shown transparently on prestige items (a goal, not a mystery).

**Sequencing:** Cosmetics 2.0 ships as a free update *before* any IAP — it
improves retention, strengthens a "New Content" featuring nomination, and
builds the catalog a Supporter Pack later slots into.

## Supporting engagement layer: Game Center (built — Run #75, D25)

Free cosmetics/tips only earn if people keep playing. Game Center supplies the
retention layer at €0: global endless + daily leaderboards (Apple-hosted — the
web backend the brief wanted, without a server) and 13 achievements. All of it
is earnable-only and report-only; nothing Game Center is ever for sale, and
declining auth changes nothing. See `Services/GameCenterService.swift`.

## Phases (revised 2026-06-27)

**Two hard gates before ANY IAP:**

1. **The DSA trader switch is a real cost, not a checkbox.** Enabling even one
   IAP requires switching non-trader → trader, which **publishes an address +
   phone + email on the product page permanently**. A virtual office runs
   €10–30/mo = **€120–360/yr**, while realistic hobby-scale tip revenue is
   *tens* of euros per year. Without a free address solution (e.g. a family
   business address, with informed consent), day-one monetization is
   **net-negative**. This gate — not the code — decides the timing.
2. **The featuring window.** The moment an IAP goes live, the "In-App
   Purchases" label appears on the product page — possibly right when Apple
   editorial is looking at the nomination. "Free, no ads, nothing leaves the
   device" is the stronger editorial story. **No IAP in or right after v1.3.**

**Phase 0 — ship free, instrument nothing.** Release with zero monetization.
Validate that anyone plays. Monetizing pre-audience costs effort and earns ~€0.

**Phase 0.5 — Cosmetics 2.0 (free update, right after release).** The
prestige unlocks + live preview + (optionally) glyph sets, per the section
above. Retention is the prerequisite for everything below — and it doubles as
a "New Content" featuring hook.

**Phase 1 — tip jar (1–2 sessions).** Gate: real actives (e.g. >100/week)
AND the trader-address question settled. The business stack is otherwise
ready (Paid Apps + banking + tax all Active; Small Business Program enrolled
2026-06-14). StoreKit 2 consumables, a `TipJarView`, a `TipStore` service
alongside `GameStore`. Persist a `hasTippedEver` flag for the SPONSOR tag
(menu only — see the reinstall rule above). Test with StoreKit configuration
files + sandbox.

**Phase 2 — the Supporter Pack (2–3 sessions).** Gate: tips show any signal.
One non-consumable SKU (€4.99) + the Restore Purchases flow (required by
review). Contents per the revised section above. Ship it once; grow it with
future supporter drops instead of adding SKUs.

**Phase 3 — only if real traction.** Synth voicing packs (into the Supporter
Pack), seasonal free theme drops as goodwill.

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

1. **Agreements, Tax & Banking** in App Store Connect — **DONE ✅ (all Active, 2026-06-14):**
   - **Paid Apps Agreement** — Active ✅
   - **Bank account** (Rabobank, EUR account / USD royalty currency) — Active ✅
   - **Tax forms** — both Active ✅: **U.S. W-8BEN** (Article 12, **0%** rate, income from
     sale of applications, foreign TIN = BSN → 0% US withholding) + **U.S. Certificate of
     Foreign Status** (individual/sole proprietor).
   - **DAC7** — Active ✅ (answered "No personal services" — a game isn't a DAC7 personal service).
   - Small Business Program — done ✅ (15% rate).
   - **EU DSA** — **declared & Active ✅ (2026-06-14)** as **non-trader** for the free launch
     (no public address required; app available in the EU/NL store). Honest answer while the
     app is free with no ads/IAP. **Switching to trader is required before monetizing — see step 2.**
2. **🔑 Switch EU DSA non-trader → trader** (App Store Connect → Business) **before enabling
   any IAP** — you cannot sell as a non-trader. This is when you provide the **public contact
   address** (address/phone/email shown on the product page). Decide the address then:
   - 🥇 **Virtual office / mail address service** (~€10–30/mo) — recommended, fully yours.
   - ✅ Friend/family **business street address** with informed consent (Apple may ask for
     proof; it becomes public).
   - ⚠️ Avoid a **PO box** (DSA leans to a geographical address).
   - Email → `madebyjire@icloud.com`.
3. **Confirm the offer** — the 4 price points + in-fiction tier names (defaults suggested
   above; your call to change).
4. **Create the 4 Consumable IAPs** in ASC (I'll hand you the exact IDs/prices/names to
   paste, same as we did for Game Center) and attach the review screenshot of `TipJarView`.
5. **Submit the IAPs with an app version** — IAPs are reviewed alongside a build, not on
   their own.
6. **Create a Sandbox tester** (ASC → Users and Access → Sandbox) and **test a real purchase
   on your iPhone** with it — the one thing neither the `.storekit` file nor I can do for you
   (it needs your device + Apple ID). Test buy, cancel, and a refund.

Sequence: #1 is **done**. The rest happens at monetization time: **#2 (switch to trader) +
#3 anytime**, then **#4–#6** once I've built the feature and you have a build to attach.

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
