# App Store screenshots — GRID_BREAKER

Captured on iPhone 16 Pro Max (native **1320×2868** = the App Store **6.9"** size). The
`iphone-6.5/` set is the same frames resized to **1242×2688** (6.5") for completeness —
6.9" is the primary required size; 6.5" is optional.

## The set (suggested order)
1. **01-menu** — the neon main menu (JACK IN, modes, terminal).
2. **02-fever** — gameplay mid-**Fever**: ×6 multiplier, 🔥 STREAK ×3, golden 4×4 board.
3. **03-campaign** — the 10-core campaign ladder.
4. **04-cyberdeck** — permanent upgrades (RAM, Decode, Shield, Fever, Salvage).
5. **05-cosmetics** — the 8 neon palettes.

## To upload (App Store Connect ▸ your app ▸ version ▸ Previews and Screenshots)
- Drag the five **iphone-6.9** PNGs into the **6.9"** slot, in order.
- (Optional) add the **iphone-6.5** set to the 6.5" slot.

## Re-capture
Plain device screenshots (no caption overlays). To regenerate: build with a temporary
endless-autoplay hook (see git history of GameView for the snippet), capture key states
with `xcrun simctl io <udid> screenshot`, then revert the hook. Captions/marketing frames
could be added later as an enhancement.
