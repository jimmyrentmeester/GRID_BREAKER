---
name: Run-hygiëne — één taak per run
description: Strikte discipline per run — één taak, splits bij krappe context, niet over-implementeren
type: feedback
---
Eén taak per run, dan stoppen. Keten geen taken aan elkaar binnen dezelfde sessie, ook niet
als "ik zou de volgende ook nog wel even kunnen doen".

**Waarom:** Jimmy is budget-gebonden op Claude Pro. Lange sessies verbranden tokens snel,
vooral door reads. Werk over meerdere korte runs verdelen respecteert de €20/mo-cap.

**Hoe toe te passen:**
- Bij start: `tail -50 docs/LOG.md` + `cat docs/ROADMAP.md` (GRID_BREAKER) of
  `docs/PROJECTPLAN.md` §6 (BabyBeam). Dát is het contextbudget. Lees niet meer tenzij
  de gekozen taak het vereist.
- Bouw alleen wat de taak raakt, niet het hele project.
- Voelt de context halverwege krap: stop vroeg, schuif de rest door naar de roadmap.
  Liever onder-leveren en stoppen dan afraffelen.
- Stel geen refactors, opschoningen of "nu we hier toch zijn"-toevoegingen voor.
  Bugfix = alleen die bugfix.
- Niet-triviale beslissingen: log in `docs/DECISIONS.md` (GRID_BREAKER) of
  `docs/adr/` (BabyBeam), met 1-2 geraadpleegde expertrollen — nooit alle rollen, kies de relevante.
- Triviale keuzes (naamgeving, kleuren, kleine implementatiedetails): beslis en log, vraag niet.
- Beslissingen met blijvende impact, twee keer geblokkeerd, of iets dat geld/account vraagt:
  schrijf naar `docs/QUESTIONS.md` en stop.
