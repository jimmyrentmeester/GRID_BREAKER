---
name: Gate/snelheid-tradeoff = Jimmy beslist, ik leg alleen voor
description: Bij validatie-gates de tradeoff expliciet voorleggen, dan de keuze respecteren zonder her-discussie
type: feedback
---
Bij beslissingen "eerst valideren (gate) vs. doorbouwen op aannames (snelheid)": leg de
tradeoff helder voor via één keuzevraag (inclusief het risico op herwerk), en respecteer
dan de keuze zonder opnieuw te bepleiten.

**Waarom:** De waarde zit in het *expliciet voorleggen*, niet in altijd gates afdwingen.
Jimmy wil zelf de regie, geïnformeerd. Twee keer in hetzelfde project koos hij verschillend
ná exact dezelfde uitleg — het is dus situationeel.

**Hoe toe te passen:**
- Eerste keer dat een specifieke validatie-gate dreigt te worden overgeslagen of runs
  gecombineerd: één AskUserQuestion met de eerlijke tradeoff. Daarna: uitvoeren zonder
  terug te komen op de keuze. Bouw wél een veiligheidsklep in en log de bewuste afwijking.

**Belangrijke correctie (een eerdere aanname was fout):** Jimmy DOET zijn tests zelf,
tussen runs door — hij rapporteert ze alleen terse. "Ziet er goed uit, we kunnen verder"
betekent doorgaans *de test ging goed, door*, NIET "gate overgeslagen".

- Behandel een terse "ziet er goed uit / verder" als mogelijk al gevalideerd. Niet nagelen
  over ongeteste aannames, geen herhaalde herwerk-risico-waarschuwing, geen schuld-framing.
- Vertrouw dat hij test; vraag hooguit neutraal "nog observaties uit het testen?" als het
  natuurlijk valt. Geen blokkerende vraag.
- Zorg dat elke run eindigt met een duidelijk testbaar increment (install + launch + wat te
  checken), zodat zíjn test makkelijk is. Dát is de bijdrage — niet hem eraan herinneren.
