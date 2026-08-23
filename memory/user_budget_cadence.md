---
name: User budget & cadence
description: Jimmy zit op Claude Pro €20/mo, geen API-budget — Sonnet default, korte runs, handmatig getriggerd
type: user
---
- **Plan:** Claude Pro €20/maand, geen apart API-budget.
- **Modelvoorkeur:** Sonnet standaard. Opus alleen als er expliciet om gevraagd wordt.
- **Run-plafond:** ~20 minuten effectief werk, dan afronden en stoppen.
- **Triggeren:** handmatig. Geen launchd, geen cron, geen scheduled tasks. Stel geen scheduling voor.
  Projecten met een eigen run-loop hebben `scripts/run_now.sh`; die roept Jimmy zelf aan.
- **Context-discipline:** lees smal, sweep nooit hele projectbomen. Gerichte greps/reads.
