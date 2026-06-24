# Growth & income — the path to a real side income

GRID_BREAKER is free, **no ads, no subscriptions, no pay-to-win**. That's a deliberate,
honest product — but it has one consequence that drives this whole plan:

> With no ads/subs/p2w, revenue per player is **low and capped**. So the only lever that
> moves income is **reach** (installs) — multiplied by a small, tasteful cosmetic store.
> Income = a lot of players × a little each, *or* one breakout. Everything below optimises
> reach first, then conversion.

Installs are dipping. That's the priority. Builds on `docs/marketing/promo-channels.md`,
`docs/MONETIZATION.md`, and the `app-store-release` skill.

---

## 1. Reality check — what "side income" looks like here

Honest math, so the goal is concrete. Conservative cosmetic-store assumptions for a
no-ads/no-p2w arcade game:

- Buyer conversion: **1–3%** of active users ever buy a cosmetic; tip-jar lower but higher
  value. Call it **2% × ~€3 net** (after Apple's 15% Small Business rate — already enrolled).
- So **net ≈ installs × retention × 2% × €3.**

| Installs (lifetime) | Rough net/year | Reality |
|---|---|---|
| 5,000 | ~€150–300 | hobby / coffee money |
| 50,000 | ~€2k–4k | a real "nice side income" |
| 250,000+ | ~€10k–25k | a breakout (needs featuring or a viral hit) |

**Takeaway:** the difference between "coffee money" and "nice side income" is one order of
magnitude of *installs*, not a cleverer store. Spend ~80% of effort on reach, ~20% on the
store. Don't monetise a leaky bucket — fix retention to a decent bar first (below), then
the same installs are worth far more.

## 2. Instrument first (you're flying blind otherwise)

You can't grow what you can't see. The app collects nothing (a genuine selling point), but
you still get **aggregate, privacy-safe** signal:

- **App Store Connect ▸ Analytics** — impressions, product-page views, conversion rate,
  installs by source, retention (D1/D7/D28), crashes. Free, no SDK, no privacy cost. **This
  is your dashboard.** Check it weekly.
- Optionally add **anonymous, no-PII counters** (e.g., a privacy-respecting aggregate like
  app launches / mode picks via a self-hosted count or StoreKit/`MetricKit`) — only if a
  specific question needs it. Default: stay dark, lean on ASC. Never break the no-tracking
  promise; it's part of the brand.

Targets to beat before pouring fuel on acquisition: **D1 ≥ 35%, D7 ≥ 12%** for a casual
arcade game is healthy. The Campaign 2.0 + daily-streak work (`CAMPAIGN_REDESIGN.md`) is
what raises these.

## 3. The reach engine — proven channels, in priority order

### A. Apple featuring — the single biggest lever (free)
Apple editorial *loves* exactly this profile: a polished, original, **no-ads, no-tracking**
game with a strong identity. A feature ("New Games We Love," a theme story) is worth tens of
thousands of installs overnight, and games like Mini Metro, Alto's, Monument Valley rode
editorial hard.
- **Nominate it:** App Store Connect ▸ your app ▸ **"Nominate your app"** (the featuring
  request form). Pitch the angles: no ads/no tracking, generated-in-code audio/art, Game
  Center, accessibility (VoiceOver + Reduce Motion), iPad support. Time a nomination to a
  content drop (Campaign 2.0).
- Keep the product page feature-ready: great screenshots, an **app preview video**, the
  promo text fresh. Apple features pages that are already polished.

### B. Short-form video — the modern discovery channel
TikTok / Reels / YouTube Shorts is how arcade games get found in 2024+. The game is
*intrinsically* clippable: the **Fever surge**, the new **RAM containment frame burning
down**, a clean streak popping. 
- Post **short, satisfying-loop clips** consistently (3–5×/week). No "I made this with AI"
  framing — show the *game*. One clip can carry a launch.
- Repurpose the same clips to Reels + Shorts. Add the App Store link in bio + pinned comment.

### C. The daily challenge as a viral loop (build this)
The Wordle lesson: a **shareable daily result** is the cheapest, most durable growth loop
there is — players post their score card, friends click through. It's *acquisition and
retention in one feature*. This is why the daily-share card is top of the Campaign 2.0 build
order. Zero marginal cost per share.

### D. Reddit — done right this time
The earlier AI backlash was a framing problem, not an audience problem. Rules:
- **Lead with a gameplay clip**, never the AI origin. Let the game speak.
- Right communities: **r/iosgaming**, **r/playmygame**, **r/IndieGaming**, **r/AppHookup**
  (for a launch/sale beat). Read each sub's self-promo rules; participate, don't dr/spam.
- Frame as "I built a no-ads neon reflex game, would love feedback" + clip + link.

### E. One-time spikes + credibility
- **Product Hunt** launch (pick a Tuesday–Thursday; rally a few friends for early upvotes).
- **Indie press / newsletters**: AppAdvice, TouchArcade (declining but alive), indie-game
  newsletters. Lower yield than video now, but good for backlinks/credibility.
- A tiny **landing page** (already in `docs/site/`) with the preview video + OG cards for
  clean link unfurls everywhere.

### F. Compounding, low-effort
- **Localization for ASO**: each added language widens organic search reach. NL copy exists;
  add a few more high-volume locales (DE, FR, ES, PT-BR, JA) — cheap, compounds forever.
- **ASO iteration**: use **Product Page Optimization** (App Store Connect's built-in A/B
  test) on icon + first screenshot — the highest-leverage conversion knobs. Test one thing
  at a time.

## 4. The monetisation, once reach + retention are there

Order matters: **grow and retain first, then turn on the (gentle) store.** Plan
(`docs/MONETIZATION.md`), Small Business Program already enrolled (85% kept):

1. **Tip jar** — StoreKit 2 consumables, in-world framing ("buy the netrunner a coffee").
   Low conversion, high goodwill, zero design risk. Ships first.
2. **Cosmetic packs** — non-consumable palettes + tap-trails + (new) the RAM-frame styles.
   Render-layer only; a determinism test guards that money never touches gameplay. Keep the
   free set generous — generosity drives the goodwill that drives the rare purchase.
3. **Seasonal cosmetic drops** — a new themed palette/trail each month, tied to the daily.
   This is the no-subscription way to get *recurring* revenue: a steady reason to buy,
   without ever paywalling fun. (Crossy Road built a business on cosmetic-only; the model
   works when the cosmetics are desirable and the base game is free and complete.)

Never: loot boxes, FOMO timers, energy systems, post-game-over upsells, or selling anything
that affects score/difficulty. They'd contradict the brand that earns the goodwill.

## 5. The 90-day path (concrete)

- **Weeks 1–3 — see + retain.** Wire ASC Analytics into a weekly habit. Ship the
  **daily-share card + streak** (retention + viral loop). Refresh the product page (video,
  promo text). Submit an Apple **featuring nomination**.
- **Weeks 4–8 — reach.** Start the short-form video cadence (the Fever / RAM-frame clips).
  A clean Reddit + Product Hunt beat around the Campaign 2.0 / chapter update. Run one PPO
  A/B test on the first screenshot.
- **Weeks 9–12 — convert.** With retention proven and installs climbing, ship the **tip jar
  + first cosmetic pack**. Add localisation for 2–3 locales. Plan the first seasonal drop.

The honest summary: **this app's path to a nice side income runs through reach, not
monetisation tricks.** A daily-share viral loop + consistent short-form video + an Apple
feature, on top of the no-ads/no-tracking story Apple and players both reward, is the
realistic route from "coffee money" to "nice side income" — and it keeps the product clean.
