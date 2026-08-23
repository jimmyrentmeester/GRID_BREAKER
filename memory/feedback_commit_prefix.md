---
name: Geen "Run #N:"-prefix op planning-commits
description: Alleen echte implementatie-runs gebruiken "Run #N:" — anders no-opt de volgende run
type: feedback
---
Commits die ik in de hoofdconversatie maak om een roadmap-taak te definiëren, een skill bij
te werken of process-fixes te doen, mogen **NOOIT** met "Run #N:" beginnen. Gebruik
`plan:`, `roadmap:`, `skill:`, `process:` of `fix:`.

**Waarom:** Op 2026-05-16 prefixte ik een roadmap-opzet-commit met "Run #21: …". De volgende
`run_now.sh`-run zag die commit, concludeerde via de resume-check dat Run #21 al gedaan was,
deed géén implementatie, hernummerde naar #22 en stopte. Een hele run-cyclus verbrand voor
niks — duur voor een budget-gebonden user.

**Hoe toe te passen:**
- Implementatie-runs via `scripts/run_now.sh`: commit begint met `Run #N:`.
- Alles wat ik zelf in gesprek commit: andere prefix, nooit `Run #N:`.
- `Run #N hotfix:` mag wel — verwijst naar een bestaande run.
- **`docs/LOG.md` is de enige completion-bron.** Commit-messages tellen niet mee voor
  "is de run af".
