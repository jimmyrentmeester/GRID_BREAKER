#!/usr/bin/env python3
"""ASO-metadata voor GRID_BREAKER 1.3.3 (zie docs/ASO-audit-2026-10.md).

Eén bron van waarheid voor naam, ondertitel, keywords, promotional text, beschrijving
en What's New per locale. `python3 metadata.py` valideert Apple's limieten en
controleert dat keywords geen woorden uit naam/ondertitel herhalen; `--json`
schrijft metadata.json voor het uploaden.

Afspraak deze ronde (2026-10-04): en-US naam/ondertitel/keywords blijven ongewijzigd
(meetbaarheid v1.3.1); alleen nieuwe store-listings + promotietekst. App-UI blijft Engels.
"""
import json, re, sys
from pathlib import Path

HERE = Path(__file__).parent

# ---------------------------------------------------------------- beschrijvingen

EN_US_DESC = """GRID_BREAKER is a fast, neon reflex game. Jack into the grid, decode the daemons before they vanish, dodge the firewalls, and chain combos into Fever as the pace climbs.

Just thumbs. Pure reaction. No filler.

HOW IT PLAYS
• Tap glowing daemons to decode them and refill your RAM clock.
• Never tap a red firewall — let it expire.
• Crack armored shells, grab gold data caches, chase hopping worms.
• Chain clean hits to trigger FEVER: hazards clear and your score doubles.
• Grab power-ups — Freeze, Overclock, Purge — for a burst of control.
• Hold a clean streak to climb a rising score multiplier.

FOUR MODES
• ENDLESS — survive as long as your reflexes hold and chase the high score.
• CAMPAIGN — 16 hand-tuned data cores across 4 chapters, each teaching one new mechanic and ending in a chapter boss.
• PROTOCOL — objective-driven endurance. DAEMON SETs and DMZ PURGEs with no relief and no power-ups.
• DAILY HACK — one shared board per day; everyone races the same seed.

PROGRESS & STYLE
• Earn Credits every run and spend them in the CYBERDECK on permanent upgrades — more RAM, faster decoding, a failsafe shield, longer Fever, bigger payouts.
• Unlock COSMETICS — neon palettes that recolor the whole game and tap-trail styles that follow your finger.

BUILT RIGHT
• 100% on-device. No accounts, no ads, no analytics, no tracking — nothing is collected.
• Honors Reduce Motion; independent music & effects volume.
• All sound is generated in code — tactile, rewarding, no bloat.

Crack the grid. The Monolith is waiting."""

EN_GB_DESC = (EN_US_DESC
    .replace("armored", "armoured")
    .replace("recolor", "recolour")
    .replace("Honors", "Honours"))

NL_DESC = """GRID_BREAKER is een razendsnel neon reflexspel. Jack in op het grid, kraak de daemons voordat ze verdwijnen, ontwijk de firewalls en rijg combo's aaneen tot Fever terwijl het tempo oploopt.

Alleen je duimen. Pure reactie. Geen opvulling.

ZO SPEEL JE
• Tik op oplichtende daemons om ze te kraken en je RAM-klok bij te vullen.
• Tik nooit op een rode firewall — laat 'm verlopen.
• Breek gepantserde schillen, pak gouden datacaches, jaag op springende worms.
• Rijg foutloze tikken aaneen voor FEVER: gevaren verdwijnen en je score verdubbelt.
• Pak power-ups — Freeze, Overclock, Purge — voor een moment van controle.
• Houd een foutloze reeks vast en klim in een oplopende score-multiplier.

VIER MODI
• ENDLESS — overleef zolang je reflexen het houden en jaag op de highscore.
• CAMPAIGN — 16 zorgvuldig afgestelde datacores in 4 hoofdstukken, elk met een nieuwe mechaniek en een eindbaas per hoofdstuk.
• PROTOCOL — uithoudingsvermogen met doelen. DAEMON SETs en DMZ PURGEs, zonder adempauze en zonder power-ups.
• DAILY HACK — elke dag één gedeeld bord; iedereen speelt dezelfde seed.

VOORTGANG & STIJL
• Verdien Credits met elke run en besteed ze in de CYBERDECK aan permanente upgrades — meer RAM, sneller kraken, een failsafe-schild, langere Fever, hogere uitbetalingen.
• Ontgrendel COSMETICS — neonpaletten die het hele spel herkleuren en tap-trails die je vinger volgen.

GOED GEBOUWD
• 100% op je toestel. Geen account, geen reclame, geen analytics, geen tracking — er wordt niets verzameld.
• Respecteert Verminder beweging; aparte volumes voor muziek en effecten.
• Al het geluid wordt in code gegenereerd — tactiel en belonend, zonder ballast.

De app is Engelstalig.

Kraak het grid. De Monolith wacht."""

# ---------------------------------------------------------------- What's New 1.3.3

WHATS_NEW = {
    "en-US": "Stability fixes and polish.",
    "en-GB": "Stability fixes and polish.",
    "nl-NL": "Stabiliteitsverbeteringen en afwerking.",
}

# ---------------------------------------------------------------- per locale
# name/subtitle/keywords/description: None = ongewijzigd laten.

L = {
    "en-US": dict(
        name=None, subtitle=None, keywords=None, description=None,
        promo="Tap fast, chain combos into Fever, outlast the rising grid. Now with a 16-core boss campaign, stackable run modifiers & a daily streak. No ads, no tracking — pure skill."),
    "en-GB": dict(
        # Spatievorm i.p.v. GRID_BREAKER: 'grid' en 'breaker' als losse tokens (tokenizer-risico).
        name="Grid Breaker: Neon Reflex Game",
        subtitle="Offline arcade, no ads or IAP",
        keywords="cyberpunk,tap,reaction,speed,hacker,synthwave,retro,endless,combo,timing,score,whack,mole,daily",
        promo="Tap fast, chain combos into Fever, outlast the rising grid. Now with a 16-core boss campaign, stackable run modifiers & a daily streak. No ads, no tracking — pure skill.",
        description=EN_GB_DESC, new=True),
    "nl-NL": dict(
        # Engelse termen (cyberpunk, combo, hacker…) komen in NL al binnen via en-GB → hier alleen NL.
        name="Grid Breaker: Neon Reflex Spel",
        subtitle="Offline tikspel zonder reclame",
        keywords="spelletjes,reactie,snel,tikken,verslavend,dagelijks,mol,meppen,reflexen,uitdaging,moeilijk,highscore",
        promo="Tik snel, rijg combo's aaneen tot Fever en overleef het oplopende grid. Met een campaign van 16 cores, run-modifiers en een dagelijkse streak. Geen reclame, puur skill.",
        description=NL_DESC, new=True),
}

# Huidige naam/ondertitel van locales waar die ongewijzigd blijven (voor de dubbel-check).
CURRENT = {
    "en-US": ("GRID_BREAKER: Neon Reflex Game", "Offline arcade, no ads or IAP"),
}
CURRENT_KEYWORDS = {
    "en-US": "cyberpunk,tap,reaction,speed,hacker,synthwave,retro,endless,combo,timing,score,skill,hard,daily",
}


def words(s):
    return {w.lower() for w in re.findall(r"[^\W_]+", s or "")}


def validate():
    ok = True
    for loc, d in L.items():
        name = d["name"] or CURRENT.get(loc, ("", ""))[0]
        sub = d["subtitle"] or CURRENT.get(loc, ("", ""))[1]
        checks = [("name", d["name"], 30), ("subtitle", d["subtitle"], 30),
                  ("keywords", d["keywords"], 100), ("promo", d["promo"], 170),
                  ("description", d["description"], 4000), ("whatsNew", WHATS_NEW.get(loc), 4000)]
        parts = []
        for field, val, lim in checks:
            if val is None:
                continue
            n = len(val)
            flag = "" if n <= lim else "  <-- TE LANG"
            ok &= n <= lim
            parts.append(f"{field} {n}/{lim}{flag}")
        kws = d["keywords"] or CURRENT_KEYWORDS.get(loc)
        if kws:
            kw = kws.split(",")
            if any(" " in k or not k for k in kw):
                parts.append("SPATIE/LEEG IN KEYWORDS"); ok = False
            taken = words(name) | words(sub)
            dup = [k for k in kw if k.lower() in taken]
            if dup:
                parts.append(f"DUBBEL MET NAAM/ONDERTITEL: {dup}"); ok = False
            if len(set(kw)) != len(kw):
                parts.append("DUBBEL IN KEYWORDS"); ok = False
        print(f"{loc:6} {'NIEUW ' if d.get('new') else ''}" + " | ".join(parts))
    return ok


if __name__ == "__main__":
    good = validate()
    if "--json" in sys.argv:
        out = {loc: {**d, "whatsNew": WHATS_NEW.get(loc)} for loc, d in L.items()}
        (HERE / "metadata.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    sys.exit(0 if good else 1)
