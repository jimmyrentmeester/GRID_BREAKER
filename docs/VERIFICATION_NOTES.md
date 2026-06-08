# VERIFICATION NOTES — on-device (Simulator) checks

How to verify GRID_BREAKER reliably on the iOS Simulator, and a known tooling issue.

## Known issue: computer-use → Simulator input is flaky
Driving taps via the computer-use bridge degraded mid-session (it worked early, then
stopped delivering touches). Diagnosed concretely:
1. **`left_click` mis-maps Y** — a click aimed at `(x, 383)` lands at `(x, 0)`
   (confirmed via `cursor_position` after a click). `mouse_move` maps correctly.
2. **Synthetic clicks aren't converted to iOS touches** — even `mouse_move` (cursor
   verified on-target) + `left_mouse_down`/`up` doesn't register in the app, on small
   *or* large targets.
3. **Multiple booted simulators** → the Simulator window can show a *different* device
   than the one you `install`/`launch` to (e.g. window showed "iPhone 16 Plus" while the
   build was on "iPhone 16 Pro" `45DA7B07`). Clicks then hit the wrong device.

Tried and did NOT fix input: restarting Simulator.app, shutting down extra devices
(single-device), the move+down/up workaround. A full reset of the computer-use bridge
(or the Mac) would likely restore it.

## Reliable verification workflow (use this)
- **One device only.** Pick a UDID (e.g. `45DA7B07-FE43-462D-843A-7489E5089331`,
  iPhone 16 Pro / iOS 18.2). Shut down the others:
  `xcrun simctl shutdown <other-udid>`. Then the displayed window matches the target.
- **Visuals via simctl, not computer-use** — always correct device, no input needed:
  `xcrun simctl io <udid> screenshot /tmp/x.png` → Read the PNG.
- **Input-driven states via temporary in-code autoplay hooks** (a `.task` loop that
  calls `model.tap(...)`), plus config overrides (e.g. raise `baseRAMSeconds`, boost a
  spawn chance, lengthen a duration) to force a state, screenshot, then **revert the
  temp hooks before committing**. This is how every gameplay state in the log was
  captured (fever, power-ups, grid FX, etc.) — it doesn't depend on the input bridge.
- For pure **navigation** screens (menus/shops) when the bridge is down, there's no
  simctl input path; either fix the bridge or accept build-verification for trivial
  UI additions.

## Standing setup
- DEVELOPMENT_TEAM is configured; the app builds + installs + launches via `simctl`
  fine. The build/render path is healthy — only the *input* automation is unreliable.
