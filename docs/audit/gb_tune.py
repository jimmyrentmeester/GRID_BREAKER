#!/usr/bin/env python3
"""Diagnose the missing endless skill ceiling + test candidate tunes."""
import random
from gb_sim import Engine, Player, PROFILES, endless_config, replace

SEEDS = [42, 1337, 999999, 7, 2026]

class TunedEngine(Engine):
    """Engine with optional late-game pressure tunes."""
    def __init__(self, *a, drain_ramp=0.0, drain_cap=1.0, fever_ramp=0, fever_cap=99,
                 refill_decay=0.0, refill_floor=0.0, **kw):
        super().__init__(*a, **kw)
        self.drain_ramp = drain_ramp; self.drain_cap = drain_cap
        self.fever_ramp = fever_ramp; self.fever_cap_v = fever_cap
        self.refill_decay = refill_decay; self.refill_floor = refill_floor
        self.fever_time = 0.0

    def tick(self, dt):
        if self.fever and self.freeze <= 0: self.fever_time += dt
        # drain ramp: multiply cfg drain via temporary swap
        base = self.cfg.ramDrainPerSecond
        if self.drain_ramp:
            mult = min(self.drain_cap, 1 + self.score * self.drain_ramp)
            self.cfg = replace(self.cfg, ramDrainPerSecond=base * mult)
        ev = super().tick(dt)
        self.cfg = replace(self.cfg, ramDrainPerSecond=base)
        return ev

    def tap(self, cell):
        # fever threshold ramp: threshold grows with fevers already triggered
        if self.fever_ramp:
            th = min(self.fever_cap_v, 8 + self.fever_count * self.fever_ramp)
            self.cfg = replace(self.cfg, feverComboThreshold=th)
        # refill decay: decode RAM bonus shrinks with score
        if self.refill_decay:
            import math
            f = max(self.refill_floor, math.exp(-self.refill_decay * self.score))
            c = self.cfg
            self.cfg = replace(c, bonusStandardDecode=1.05 * f,
                               bonusArmoredDecode=1.8 * f, bonusCacheDecode=2.5 * f)
        return super().tap(cell)

def run(profile, seed, max_t=1200.0, **tunes):
    eng = TunedEngine(endless_config(), seed, **tunes)
    pl = Player(rng=random.Random(seed ^ 0xABCDEF), worm_dodge=0.10, **PROFILES[profile])
    dt = 1 / 60; t = 0.0
    while not eng.over and t < max_t:
        eng.tick(dt); t += dt
        if eng.over: break
        c = pl.act(eng, t)
        if c is not None: eng.tap(c)
    return eng, t

def report(name, **tunes):
    print(f"\n--- {name} ---")
    for prof in ("casual", "good", "strong"):
        ts, scores, fu = [], [], []
        for s in SEEDS:
            e, t = run(prof, s, **tunes)
            ts.append(t); scores.append(e.score); fu.append(e.fever_time / max(t, 1))
        capped = sum(1 for t in ts if t >= 1199)
        print(f"  {prof:<7} survival {min(ts):5.0f}-{max(ts):5.0f}s (avg {sum(ts)/5:5.0f}s, "
              f"{capped}/5 capped)  score avg {sum(scores)/5:6.0f}  feverUptime {sum(fu)/5:.0%}")

if __name__ == "__main__":
    report("BASELINE (current endless config)")
    report("T1: drain ramps with score  (+0.15%/pt, cap x2.4)",
           drain_ramp=0.0015, drain_cap=2.4)
    report("T2: fever threshold +1 per fever (cap 14)",
           fever_ramp=1, fever_cap=14)
    report("T3: decode refill decays with score (floor 45%)",
           refill_decay=0.0009, refill_floor=0.45)
    report("T4 = T1 mild + T2  (drain +0.10%/pt cap x2.0, fever +1 cap 12)",
           drain_ramp=0.0010, drain_cap=2.0, fever_ramp=1, fever_cap=12)
