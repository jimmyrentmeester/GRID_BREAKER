# App Store screenshots — iPad 13"

Captured on the **iPad Pro 13-inch (M4)** simulator at native **2064×2752** (the App
Store **13" iPad** size, which also covers the 12.9"/11" slots). Run #91 — the same five
states as the iPhone set, now showing the universal iPad layout (the play column / chrome
columns centered over the neon backdrop).

## The set (suggested order)
1. **01-menu** — neon main menu, lived-in (BEST 1287, DAILY 612, 2480 CR).
2. **02-fever** — gameplay mid-**Fever**: ×10 multiplier, 🔥 STREAK ×5, 4×4 board.
3. **03-campaign** — the 10-core ladder (6/10 cleared, per-core BEST scores).
4. **04-cyberdeck** — permanent upgrades with their cumulative values (Run #84).
5. **05-cosmetics** — the neon palettes + tap trails.

## To upload (App Store Connect ▸ your app ▸ version ▸ Previews and Screenshots)
- Drag the five PNGs into the **iPad 13"** slot, in order. This size satisfies the iPad
  screenshot requirement for the universal app; no separate 11" set is required.

## Re-capture (Run #91 workflow)
A demo save injected into the simulator's UserDefaults (lived-in shops/campaign), plus
temporary in-code hooks — launch-arg screen routing (`-shot -screen <name>`), a perfect-play
autoplay bot + a demo config that races to a fever/4×4/streak state (`-autoplay`), and
boot/Game-Center skips — all reverted before commit. Then `xcrun simctl launch … --args …`
per screen + `simctl io … screenshot`. Captioned "marketing" frames (as in the iPhone set)
were not generated for iPad; the plain set is App-Store-compliant on its own.
