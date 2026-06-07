# GRID_BREAKER

A neon-cyberpunk **whack-a-mole reflex game** for iOS. You're an elite netrunner
cracking megacorp data cores: tap glowing *daemon* nodes to harvest data and refill
a draining RAM time buffer, dodge firewall bombs, chain combos into Fever Mode, and
spend Credits on permanent Cyberdeck upgrades. Pure deterministic client logic — no AI.

> Status: **v0.1 — scaffold.** Neon title screen runs; gameplay engine is next.
> See [docs/ROADMAP.md](docs/ROADMAP.md).

## Build & run
```sh
xcodebuild -project App/GRID_BREAKER.xcodeproj -scheme GRID_BREAKER \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```
Or just open `App/GRID_BREAKER.xcodeproj` in Xcode and run on a simulator/device.

## Layout
- `App/GRID_BREAKER/Core/` — platform-agnostic spec (models + engine). Reusable.
- `App/GRID_BREAKER/UI/` — SwiftUI shell. Per-platform.
- `GAME_GROUND_TRUTH.md` — the binding build constitution.
- `docs/` — roadmap, log, decisions, concepts, questions, changelog.
- `scripts/run_now.sh` — manual trigger for a scoped Claude Code build session.

Solo hobby project. iOS-first SwiftUI. See [CLAUDE.md](CLAUDE.md) for conventions.
