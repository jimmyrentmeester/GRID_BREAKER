#!/usr/bin/env python3
"""Headless balance sim for GRID_BREAKER — Python mirror of GridEngine + GameConfig.

Mirrors App/GRID_BREAKER/Core/Engine/GridEngine.swift and Models/GameConfig.swift
as of commit 3bd8dee. Player model per docs/DECISIONS.md D10: reaction-limited,
taps most-urgent harvestable, never taps bombs.
"""
import math, random
from dataclasses import dataclass, field, replace
from typing import Optional

# ---------- Config (mirrors GameConfig defaults) ----------
@dataclass
class Config:
    baseRAMSeconds: float = 20; ramSecondsPerLevel: float = 4; ramDrainPerSecond: float = 1.0
    bonusStandardDecode: float = 1.05; bonusArmoredDecode: float = 1.8; bonusCacheDecode: float = 2.5
    penaltyMiss: float = 1.5; penaltyExpiredDaemon: float = 1.0
    baseNodeLifespan: float = 1.35; lifespanCompression: float = 0.0030; minNodeLifespan: float = 0.50
    baseSpawnInterval: float = 0.50; spawnCompression: float = 0.0045; minSpawnInterval: float = 0.20
    scoreStandard: int = 1; scoreArmored: int = 2; scoreCache: int = 5; scoreWorm: int = 2
    creditsPerScore: float = 1.0; decodeBonusPerLevel: float = 0.15
    feverBonusPerLevel: float = 0.5; salvageBonusPerLevel: float = 0.10
    feverComboThreshold: int = 8; feverDuration: float = 4.0; feverScoreMultiplier: int = 2
    feverEnabled: bool = True; feverSpawnInterval: float = 0.34; feverActiveNodes: int = 4
    milestoneScores: tuple = (); milestoneRAMBonus: float = 0
    streakTierThresholds: tuple = ()
    fixedActiveNodes: Optional[int] = None
    gridEscalationScore: Optional[int] = 40
    armoredSpawnChance: float = 0.20; firewallSpawnChance: float = 0.15
    cacheSpawnChance: float = 0.05; cacheLifespanFactor: float = 0.65
    wormSpawnChance: float = 0.08; wormHopInterval: float = 0.55; wormLifespanFactor: float = 1.25
    powerUpSpawnChance: float = 0.04; powerLifespanFactor: float = 0.8
    powerUpKinds: tuple = ("timeFreeze", "overclock", "purge")
    freezeDuration: float = 3.0; overclockDuration: float = 4.0; overclockMultiplier: int = 2

    def ramCapacity(self, ramLevel): return self.baseRAMSeconds + self.ramSecondsPerLevel * ramLevel
    def nodeLifespan(self, score):
        return max(self.minNodeLifespan, self.baseNodeLifespan * math.exp(-self.lifespanCompression * score))
    def spawnInterval(self, score):
        return max(self.minSpawnInterval, self.baseSpawnInterval * math.exp(-self.spawnCompression * score))
    def targetActiveNodes(self, score, cells):
        if self.fixedActiveNodes is not None:
            return max(1, min(cells - 1, self.fixedActiveNodes))
        return max(2, min(cells - 1, 2 + score // 8))

def endless_config():
    return replace(Config(),
        baseSpawnInterval=0.72, spawnCompression=0.0032, minSpawnInterval=0.26,
        baseNodeLifespan=1.70, lifespanCompression=0.0021, minNodeLifespan=0.62,
        gridEscalationScore=80,
        milestoneScores=(50, 100, 250, 500, 1000, 2000, 4000, 8000), milestoneRAMBonus=2.5,
        streakTierThresholds=(12, 30, 60, 120))

def campaign_base(timeBudget):
    return replace(Config(),
        baseRAMSeconds=timeBudget, bonusStandardDecode=0, bonusArmoredDecode=0, bonusCacheDecode=0,
        cacheSpawnChance=0, wormSpawnChance=0, powerUpSpawnChance=0, gridEscalationScore=None,
        baseSpawnInterval=1.10, minSpawnInterval=0.30, baseNodeLifespan=2.00, minNodeLifespan=0.60,
        wormHopInterval=0.75, feverSpawnInterval=0.55)

CORES = [  # id, name, target, budget, bias, armored, bombs, fever, cache, worm, nPower, grid4
    (1, "Sector-7 Cache", 22, 52, 0, 0, 0, 0, 0, 0, 0, 0),
    (2, "Public Grid Relay", 32, 57, 15, 1, 0, 0, 0, 0, 0, 0),
    (3, "Cold Storage Node", 42, 60, 35, 1, 1, 0, 0, 0, 0, 0),
    (4, "Sentinel Subnet", 54, 65, 60, 1, 1, 1, 0, 0, 0, 0),
    (5, "Ice Wall", 68, 70, 90, 1, 1, 1, 1, 0, 0, 0),
    (6, "Black Market Ledger", 84, 73, 100, 1, 1, 1, 1, 1, 0, 0),
    (7, "Daemon Foundry", 100, 73, 160, 1, 1, 1, 1, 1, 1, 0),
    (8, "Quarantine Vault", 120, 75, 200, 1, 1, 1, 1, 1, 3, 0),
    (9, "Black ICE Core", 145, 68, 270, 1, 1, 1, 1, 1, 3, 1),
    (10, "The Monolith", 180, 70, 300, 1, 1, 1, 1, 1, 3, 1),
]

def campaign_config(core):
    (_, _, target, budget, bias, armored, bombs, fever, cache, worm, npower, grid4) = core
    c = campaign_base(budget)
    c = replace(c,
        armoredSpawnChance=0.20 if armored else 0,
        firewallSpawnChance=0.15 if bombs else 0,
        feverEnabled=bool(fever),
        cacheSpawnChance=0.05 if cache else 0,
        wormSpawnChance=0.08 if worm else 0)
    if npower:
        c = replace(c, powerUpSpawnChance=0.05,
                    powerUpKinds=("timeFreeze", "overclock", "purge")[:npower])
    if grid4:
        c = replace(c, gridEscalationScore=max(1, target // 2))
    return c, target, bias

# ---------- Engine ----------
@dataclass
class Node:
    cell: int; type: str; lifespan: float; spawnedAt: float
    hits: int = 1; nextHop: Optional[float] = None; powerKind: Optional[str] = None
    @property
    def expiresAt(self): return self.spawnedAt + self.lifespan

class Engine:
    def __init__(self, cfg, seed, ramLevel=0, shieldLevel=0, decodeSpeedLevel=0, feverLevel=0,
                 target=None, bias=0, grid=3):
        self.cfg = cfg; self.rng = random.Random(seed)
        self.grid = grid; self.target = target; self.bias = bias
        self.clock = 0.0; self.tsls = 0.0
        self.score = 0
        self.ramCap = cfg.ramCapacity(ramLevel); self.ram = self.ramCap
        self.shield = shieldLevel
        self.decodeBonus = cfg.decodeBonusPerLevel * decodeSpeedLevel
        self.feverDur = cfg.feverDuration + cfg.feverBonusPerLevel * feverLevel
        self.nodes = []; self.combo = 0; self.streak = 0; self.nextMilestone = 0
        self.fever = False; self.feverRemaining = 0.0
        self.freeze = 0.0; self.overclock = 0.0
        self.over = False; self.reason = None
        # stats
        self.events = []; self.spawn_bursts = []; self.fever_count = 0; self.first_fever = None
        self.expired_daemons = 0; self.max_mult = 1

    @property
    def cells(self): return self.grid * self.grid

    def streakMult(self):
        t = self.cfg.streakTierThresholds
        return 1 + sum(1 for th in t if self.streak >= th) if t else 1

    def effMult(self):
        m = self.streakMult() * (self.cfg.feverScoreMultiplier if self.fever else 1) \
            * (self.cfg.overclockMultiplier if self.overclock > 0 else 1)
        self.max_mult = max(self.max_mult, m)
        return m

    @property
    def scaled(self): return self.score + self.bias

    def tick(self, dt):
        if self.over or dt <= 0: return []
        ev = []
        frozen = self.freeze > 0
        if self.freeze > 0: self.freeze = max(0, self.freeze - dt)
        if self.overclock > 0: self.overclock = max(0, self.overclock - dt)
        if not frozen: self.clock += dt
        if self.fever and not frozen:
            self.feverRemaining -= dt
            if self.feverRemaining <= 0:
                self.fever = False; self.feverRemaining = 0; self.combo = 0; ev.append("feverEnded")
        if not frozen: self.ram -= self.cfg.ramDrainPerSecond * dt
        expired = [n for n in self.nodes if self.clock >= n.expiresAt]
        for n in expired:
            if n.type in ("standard", "armored", "worm"):
                self.ram -= self.cfg.penaltyExpiredDaemon
                self.combo = 0; self.streak = 0; self.expired_daemons += 1
                ev.append("expired")
        if expired:
            ids = set(id(n) for n in expired)
            self.nodes = [n for n in self.nodes if id(n) not in ids]
        self.tsls += dt
        interval = self.cfg.feverSpawnInterval if self.fever else self.cfg.spawnInterval(self.scaled)
        tgt = min(self.cells, self.cfg.feverActiveNodes) if self.fever \
              else self.cfg.targetActiveNodes(self.scaled, self.cells)
        burst = 0
        while self.tsls >= interval and len(self.nodes) < tgt:
            n = self.spawn()
            if n is None: break
            self.nodes.append(n); self.tsls -= interval; burst += 1
        if burst > 1: self.spawn_bursts.append((self.clock, burst))
        for n in self.nodes:
            if n.type == "worm" and n.nextHop is not None and self.clock >= n.nextHop:
                occ = set(x.cell for x in self.nodes)
                dests = [d for d in self.adj(n.cell) if d not in occ]
                if dests: n.cell = self.rng.choice(dests)
                n.nextHop = self.clock + self.cfg.wormHopInterval
        if self.ram <= 0:
            self.ram = 0; self.end("ramDepleted"); ev.append("gameOver")
        return ev

    def adj(self, i):
        c = self.grid; r, col = divmod(i, c); out = []
        if r > 0: out.append(i - c)
        if r < c - 1: out.append(i + c)
        if col > 0: out.append(i - 1)
        if col < c - 1: out.append(i + 1)
        return out

    def spawn(self):
        occ = set(n.cell for n in self.nodes)
        free = [i for i in range(self.cells) if i not in occ]
        if not free: return None
        cell = self.rng.choice(free)
        cfg = self.cfg
        if self.fever:
            t = "standard"
        else:
            roll = self.rng.random()
            a, f2, ca, w, p = cfg.firewallSpawnChance, cfg.armoredSpawnChance, cfg.cacheSpawnChance, cfg.wormSpawnChance, cfg.powerUpSpawnChance
            if roll < a: t = "bomb"
            elif roll < a + f2: t = "armored"
            elif roll < a + f2 + ca: t = "cache"
            elif roll < a + f2 + ca + w: t = "worm"
            elif roll < a + f2 + ca + w + p: t = "power"
            else: t = "standard"
        base = cfg.nodeLifespan(self.scaled)
        hop = None; kind = None
        if t == "cache": life = base * cfg.cacheLifespanFactor
        elif t == "worm": life = base * cfg.wormLifespanFactor; hop = self.clock + cfg.wormHopInterval
        elif t == "power": life = base * cfg.powerLifespanFactor; kind = self.rng.choice(cfg.powerUpKinds)
        else: life = base
        return Node(cell, t, life, self.clock, hits=2 if t == "armored" else 1,
                    nextHop=hop, powerKind=kind)

    def tap(self, cell):
        if self.over: return []
        hit = next((n for n in self.nodes if n.cell == cell), None)
        if hit is None:
            if self.shield > 0: self.shield -= 1; return ["missAbsorbed"]
            self.combo = 0; self.streak = 0; self.ram -= self.cfg.penaltyMiss
            if self.ram <= 0: self.ram = 0; self.end("ramDepleted"); return ["miss", "gameOver"]
            return ["miss"]
        if hit.type == "bomb":
            self.nodes.remove(hit)
            if self.shield > 0: self.shield -= 1; return ["defused"]
            self.end("firewallHit"); return ["bombed", "gameOver"]
        if hit.type == "power":
            self.nodes.remove(hit)
            k = hit.powerKind
            if k == "timeFreeze": self.freeze = self.cfg.freezeDuration
            elif k == "overclock": self.overclock = self.cfg.overclockDuration
            elif k == "purge": self.nodes = [n for n in self.nodes if n.type != "bomb"]
            return ["power:" + (k or "")]
        if hit.type == "armored" and hit.hits > 1:
            hit.hits -= 1; return ["breached"]
        # decode
        self.combo += 1; self.streak += 1
        m = self.effMult(); cfg = self.cfg
        if hit.type == "standard":
            self.score += cfg.scoreStandard * m; gain = cfg.bonusStandardDecode
        elif hit.type == "armored":
            self.score += cfg.scoreArmored * m; gain = cfg.bonusArmoredDecode
        elif hit.type == "cache":
            self.score += cfg.scoreCache * m; gain = cfg.bonusCacheDecode
        else:
            self.score += cfg.scoreWorm * m; gain = cfg.bonusStandardDecode
        self.ram = min(self.ramCap, self.ram + gain + self.decodeBonus)
        self.nodes.remove(hit)
        ev = ["decoded"]
        # checkFever
        if cfg.feverEnabled and not self.fever and self.combo >= cfg.feverComboThreshold:
            self.fever = True; self.feverRemaining = self.feverDur; self.combo = 0
            self.nodes = [n for n in self.nodes if n.type != "bomb"]
            self.fever_count += 1
            if self.first_fever is None: self.first_fever = self.clock
            ev.append("feverStarted")
        # checkTarget
        if not self.over and self.target is not None and self.score >= self.target:
            self.end("coreCracked"); ev.append("gameOver"); return ev
        # escalation
        if (not self.over and self.grid == 3 and self.cfg.gridEscalationScore is not None
                and self.score >= self.cfg.gridEscalationScore):
            self.grid = 4
            for n in self.nodes: n.cell = (n.cell // 3) * 4 + (n.cell % 3)
        # milestones
        ms = self.cfg.milestoneScores
        while self.nextMilestone < len(ms) and self.score >= ms[self.nextMilestone]:
            self.ram = min(self.ramCap, self.ram + self.cfg.milestoneRAMBonus)
            self.nextMilestone += 1
            ev.append("milestone")
        return ev

    def end(self, reason):
        self.over = True; self.reason = reason; self.fever = False; self.feverRemaining = 0

# ---------- Player model (D10) ----------
class Player:
    """Taps most-urgent harvestable node; never taps bombs. Reaction-gated and
    tap-rate-limited. Optionally worm-dodge mistaps."""
    def __init__(self, reaction, tap_interval, rng, worm_dodge=0.0):
        self.reaction = reaction; self.tap_interval = tap_interval
        self.last_tap = -10.0; self.rng = rng; self.worm_dodge = worm_dodge

    def act(self, eng, now):
        if now - self.last_tap < self.tap_interval: return None
        cand = [n for n in eng.nodes
                if n.type != "bomb" and (now - n.spawnedAt) >= self.reaction]
        if not cand: return None
        # urgency: soonest expiry first; armored needs 2 taps -> slightly more urgent
        cand.sort(key=lambda n: n.expiresAt - (0.3 if (n.type == "armored" and n.hits > 1) else 0))
        n = cand[0]
        self.last_tap = now
        if n.type == "worm" and self.rng.random() < self.worm_dodge:
            # tapped where it was; it hopped -> likely empty cell
            occ = set(x.cell for x in eng.nodes)
            empt = [i for i in range(eng.cells) if i not in occ]
            return self.rng.choice(empt) if empt else n.cell
        return n.cell

PROFILES = {
    "strong": dict(reaction=0.20, tap_interval=0.22),
    "good":   dict(reaction=0.28, tap_interval=0.30),
    "casual": dict(reaction=0.36, tap_interval=0.42),
}

def run_endless(profile, seed, deck=(0, 0, 0, 0), max_t=1200.0, worm_dodge=0.10):
    cfg = endless_config()
    eng = Engine(cfg, seed, ramLevel=deck[0], shieldLevel=deck[1],
                 decodeSpeedLevel=deck[2], feverLevel=deck[3])
    pl = Player(rng=random.Random(seed ^ 0xABCDEF), worm_dodge=worm_dodge, **PROFILES[profile])
    dt = 1 / 60
    t = 0.0
    while not eng.over and t < max_t:
        eng.tick(dt); t += dt
        if eng.over: break
        c = pl.act(eng, t)
        if c is not None: eng.tap(c)
    return eng, t

def run_core(core, profile, seed, deck=(0, 0, 0, 0), worm_dodge=0.10):
    cfg, target, bias = campaign_config(core)
    eng = Engine(cfg, seed, ramLevel=deck[0], shieldLevel=deck[1],
                 decodeSpeedLevel=deck[2], feverLevel=deck[3], target=target, bias=bias)
    pl = Player(rng=random.Random(seed ^ 0xABCDEF), worm_dodge=worm_dodge, **PROFILES[profile])
    dt = 1 / 60; t = 0.0
    while not eng.over and t < 600:
        eng.tick(dt); t += dt
        if eng.over: break
        c = pl.act(eng, t)
        if c is not None: eng.tap(c)
    return eng, t

if __name__ == "__main__":
    SEEDS = [42, 1337, 999999, 7, 2026]
    print("=== ENDLESS (starter deck) ===")
    for prof in ("casual", "good", "strong"):
        rows = []
        for s in SEEDS:
            e, t = run_endless(prof, s)
            rows.append((t, e.score, e.reason or "SURVIVED-CAP", e.first_fever, e.fever_count,
                         e.max_mult, e.expired_daemons, len(e.spawn_bursts)))
        avg_t = sum(r[0] for r in rows) / len(rows)
        avg_sc = sum(r[1] for r in rows) / len(rows)
        print(f"\n{prof}: avg survival {avg_t:.0f}s, avg score {avg_sc:.0f}")
        for s, r in zip(SEEDS, rows):
            print(f"  seed {s:>7}: t={r[0]:6.1f}s score={r[1]:5d} end={r[2]:<12} "
                  f"firstFever={r[3] and f'{r[3]:.1f}s' or '-':>7} fevers={r[4]:2d} "
                  f"maxMult={r[5]:2d} expiries={r[6]:3d} bursts={r[7]}")

    print("\n=== CAMPAIGN (starter deck), 5 seeds each: cleared? ===")
    for core in CORES:
        line = f"core {core[0]:2d} {core[1]:<20} tgt {core[2]:3d}/{core[3]:.0f}s bias {core[4]:3d}: "
        for prof in ("casual", "good", "strong"):
            wins = scores = 0
            for s in SEEDS:
                e, t = run_core(core, prof, s)
                wins += (e.reason == "coreCracked"); scores += e.score
            line += f"{prof} {wins}/5 (avg {scores/5:.0f})  "
        print(line)

    print("\n=== ECONOMY ===")
    bases = {"ram": (100, 8), "decodeSpeed": (150, 6), "shield": (400, 3),
             "feverCapacitor": (350, 4), "salvage": (250, 5)}
    total = 0
    for k, (b, mx) in bases.items():
        c = sum(int(b * 1.6 ** l) for l in range(mx))
        total += c
        print(f"  {k:<15} maxLevel {mx}: total {c:,} CR")
    print(f"  ALL upgrades: {total:,} CR")
