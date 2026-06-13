# Game Center achievement images — GRID_BREAKER

13 neon badges, **1024×1024 opaque PNG** (Apple's required achievement image size),
in the app's theme (dark radial card + accent frame + glyph). Regenerate any time with
`swift scripts/makebadges.swift <outDir>` (default `/tmp/badges`).

Upload each in **App Store Connect ▸ Services ▸ Game Center ▸ Achievements** under the
matching ID. `_preview.png` is a 4×4 contact sheet for a quick look — do **not** upload it.

| File | Achievement ID | Title | Pts |
| --- | --- | --- | --- |
| `firstfever.png` | `nl.gridbreaker.ach.firstfever` | First Fever | 10 |
| `feverloop.png`  | `nl.gridbreaker.ach.feverloop`  | Fever Loop (3 in a run) | 25 |
| `streak25.png`   | `nl.gridbreaker.ach.streak25`   | Clean Streak ×25 | 50 |
| `failsafe.png`   | `nl.gridbreaker.ach.failsafe`   | Failsafe | 10 |
| `toolbelt.png`   | `nl.gridbreaker.ach.toolbelt`   | Toolbelt (grab a power-up) | 10 |
| `grid4x4.png`    | `nl.gridbreaker.ach.grid4x4`    | Grid Expanded (4×4) | 25 |
| `score100.png`   | `nl.gridbreaker.ach.score100`   | Score 100 | 10 |
| `score250.png`   | `nl.gridbreaker.ach.score250`   | Score 250 | 25 |
| `score500.png`   | `nl.gridbreaker.ach.score500`   | Score 500 | 50 |
| `core1.png`      | `nl.gridbreaker.ach.core1`      | First Core | 25 |
| `core5.png`      | `nl.gridbreaker.ach.core5`      | Core Depth (core 5) | 75 |
| `core10.png`     | `nl.gridbreaker.ach.core10`     | The Monolith (all 10) | 150 |
| `maxtrack.png`   | `nl.gridbreaker.ach.maxtrack`   | Maxed Track | 100 |

IDs mirror `App/GRID_BREAKER/Services/GameCenterService.swift`. Total points 565 / 1000.
Leaderboards (`…lb.endless`, `…lb.daily`) take no image — name localization only.
