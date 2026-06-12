# App Store screenshots — GRID_BREAKER

Captured on the iPhone 17 Pro Max simulator (native **1320×2868** = the App Store
**6.9"** size), re-shot for 1.0 (Run #74) so they show the current build: campaign
BEST scores, the NEXT ◆ milestone hint, STREAK ×5 and a ×10 Fever. The
`iphone-6.5/` set is the same frames resized to **1242×2688** (6.5") for completeness —
6.9" is the primary required size; 6.5" is optional.

## The set (suggested order)
1. **01-menu** — the neon main menu (JACK IN, modes, terminal, stat chips).
2. **02-fever** — gameplay mid-**Fever**: ×10 multiplier, 🔥 STREAK ×5, 4×4 board.
3. **03-campaign** — the 10-core campaign ladder (6/10 cleared, per-core BEST scores).
4. **04-cyberdeck** — permanent upgrades (RAM, Decode, Shield, Fever, Salvage).
5. **05-cosmetics** — the 8 neon palettes + tap trails.

## To upload (App Store Connect ▸ your app ▸ version ▸ Previews and Screenshots)
- Drag the five **iphone-6.9** PNGs into the **6.9"** slot, in order.
- (Optional) add the **iphone-6.5** set to the 6.5" slot.
- Use either the plain sets or the `-marketing` (captioned) sets — not a mix.

## Re-capture (Run #74 workflow)
Temporary in-code hooks (a screen-tour `.task` in RootView, a perfect-play autoplay
bot in the GameViewModel, a demo-save seed so shops/campaign look lived-in, and a
longer fever window — all marked TEMP and reverted before commit), then
**Simulator ▸ File ▸ Save Screen (Cmd+S)** at each state — saves land on the Desktop
at native device pixels, no input bridge needed (VERIFICATION_NOTES workflow). The
6.5" resizes and the captioned `-marketing` frames are regenerated from the plain
set with `scripts/make_marketing_screens.py`.
