#!/usr/bin/env python3
"""GRID_BREAKER — dark-cyberpunk SFX prototypes.

Python mirror of the synthesis that will go into AudioEngine.buildBuffers().
Renders 16-bit mono 44.1 kHz WAVs so the maintainer can audition before the
Swift rewrite. Formulas are kept transliterable 1:1 to Swift.

Design language ("donkere cyberpunk-synth"):
  - detuned dual-saw stabs through a CLOSING one-pole low-pass (analog pluck)
  - sub-sine layers an octave (or two) down for weight
  - soft-clip (tanh) for analog warmth
  - dark minor scale, fundamentals an octave lower than the old bell set
  - noise only as a short transient, never as the body
"""
import math, random, struct, wave, os

SR = 44100
rnd = random.Random(7)

def sine(f, t): return math.sin(2 * math.pi * f * t)
def saw(f, t):  return 2 * ((t * f) % 1.0) - 1
def square(f, t): return 1.0 if sine(f, t) >= 0 else -1.0
def env(t, tau): return math.exp(-t / tau)
def noise():    return rnd.uniform(-1, 1)
def softclip(x): return math.tanh(1.5 * x)
def detsaw(f, t, det=0.006):
    return (saw(f * (1 - det), t) + saw(f * (1 + det), t)) * 0.5

def fm_blip(f, t, glide, index, ratio, decay):
    fT = f * (1 + glide * env(t, 0.012))
    mod = sine(f * ratio, t) * env(t, decay * 0.6)
    return math.sin(2 * math.pi * fT * t + index * mod) * env(t, decay)

class LPF:
    """One-pole low-pass; cutoff may vary per sample."""
    def __init__(self): self.y = 0.0
    def step(self, x, cutoff):
        a = 1 - math.exp(-2 * math.pi * max(20.0, cutoff) / SR)
        self.y += a * (x - self.y)
        return self.y

def render(seconds, fill):
    n = max(1, int(SR * seconds))
    return [fill(i, i / SR) for i in range(n)]

# ---------------------------------------------------------------- recipes ---

# Dark minor run (A3 C4 D4 E4 G4 A4 C5 D5) — an octave below the old bell set.
DECODE_SCALE = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33]

def decode_step(step):
    f = DECODE_SCALE[step]
    lp = LPF()
    base_cut = 700 + 350 * step          # the chain opens the filter — brighter as combo climbs
    def fill(i, t):
        x = (detsaw(f, t) * env(t, 0.055) * 0.55
             + sine(f / 2, t) * env(t, 0.07) * 0.35
             + noise() * env(t, 0.004) * 0.25)
        cut = base_cut * (0.35 + 0.65 * env(t, 0.03))   # closing filter = dark pluck
        return softclip(lp.step(x, cut) * 1.6) * 0.6
    return render(0.16, fill)

def decode_worm():
    lp = LPF()
    def fill(i, t):
        wob = 1 + 0.06 * sine(28, t)                     # alive, squirming
        f = (180 + 140 * min(1, t / 0.10)) * wob         # dark upward slither
        x = detsaw(f, t) * env(t, 0.07) * 0.6 + noise() * env(t, 0.004) * 0.2
        return softclip(lp.step(x, 900 * (0.4 + 0.6 * env(t, 0.05))) * 1.6) * 0.55
    return render(0.18, fill)

def decode_big():        # data cache: heavy, dark "haul"
    lp = LPF()
    def fill(i, t):
        fsub = 55 + 45 * env(t, 0.05)                    # 100 → 55 Hz drop
        sub  = sine(fsub, t) * env(t, 0.16) * 0.5
        stab = detsaw(110, t) * env(t, 0.09) * 0.45
        ping = fm_blip(440, t, 0.05, 2.5, 1.5, 0.05) * 0.15
        x = sub + lp.step(stab, 1200 * (0.35 + 0.65 * env(t, 0.05))) + ping
        return softclip(x * 1.3) * 0.6
    return render(0.26, fill)

def breach():            # armored 1st tap: muted crack, SETS UP the kill
    lp = LPF()
    def fill(i, t):
        thunk = sine(185 * (1 + 0.3 * env(t, 0.010)), t) * env(t, 0.04) * 0.55
        snap  = noise() * env(t, 0.012) * 0.35
        return softclip(lp.step(thunk + snap, 2500 * env(t, 0.03) + 300) * 1.4) * 0.5
    return render(0.10, fill)

def decode_armored():    # armored kill: the dark "unlock" — opens UP above the breach
    lp = LPF()
    def fill(i, t):
        stab = detsaw(220, t) * env(t, 0.08) * 0.55
        sub  = sine(110, t) * env(t, 0.12) * 0.30
        tick = noise() * env(t, 0.003) * 0.2
        # filter sweeps OPEN then closes — a rising "zhwip" = resolution
        cut = 500 + 1700 * min(1, t / 0.06) * env(t, 0.10)
        return softclip(lp.step(stab + tick, cut) * 1.6 + sub) * 0.6
    return render(0.22, fill)

def miss():              # access denied: descending dark buzz
    lp = LPF()
    def fill(i, t):
        f = 98 * (2 ** (-t * 2))
        x = square(f, t) * env(t, 0.07) * 0.30 + noise() * env(t, 0.05) * 0.12
        return softclip(lp.step(x, 700) * 1.5) * 0.5
    return render(0.18, fill)

def bomb():              # firewall: sub boom + tritone saw crash through a closing filter
    lp = LPF()
    def fill(i, t):
        sub   = sine(48 + 50 * env(t, 0.12), t) * env(t, 0.32) * 0.5
        crash = (detsaw(130, t) * 0.35 + detsaw(184, t) * 0.25) * env(t, 0.20)
        blast = noise() * env(t, 0.14) * 0.35
        cut = 300 + 2700 * env(t, 0.12)
        x = sub + lp.step(crash + blast, cut)
        return softclip(x * 1.4) * 0.62 * min(1, t * 80)
    return render(0.60, fill)

def fever():             # dark riser: minor arp + opening filter — a surge, not a fanfare
    lp = LPF()
    steps = [220.0, 261.63, 329.63, 440.0]               # A3 C4 E4 A4
    def fill(i, t):
        idx = min(len(steps) - 1, int(t / 0.13))
        local = t - idx * 0.13
        f = steps[idx]
        stab = detsaw(f, t) * env(local, 0.09) * 0.5
        sub  = sine(110, t) * 0.18 * min(1, t / 0.55)    # swelling sub
        cut = 600 + 1800 * min(1, t / 0.55)              # opening = building energy
        return softclip(lp.step(stab, cut) * 1.5 + sub) * 0.5
    return render(0.55, fill)

def game_over():         # power-down: accelerating tape-stop fall
    lp = LPF()
    def fill(i, t):
        f = 196 * (2 ** (-2.2 * t * t))
        x = detsaw(f, t) * 0.5 + sine(f / 2, t) * 0.3 + noise() * env(t, 0.3) * 0.05
        cut = 1400 * (2 ** (-2 * t))
        return softclip(lp.step(x, cut) * 1.4) * env(t, 0.50) * 0.55
    return render(0.95, fill)

def ui_tap():            # quiet dark tick
    lp = LPF()
    def fill(i, t):
        x = sine(660, t) * env(t, 0.012) * 0.6 + noise() * env(t, 0.002) * 0.2
        return softclip(lp.step(x, 1800) * 1.4) * 0.30
    return render(0.05, fill)

def ram_low():           # low-RAM warning: two urgent low pulses, fires once per dip
    lp = LPF()
    def fill(i, t):
        lt = t if t < 0.11 else t - 0.11                 # pulse at 0 ms and 110 ms
        x = (detsaw(147, t) * env(lt, 0.035) * 0.6
             + sine(73.5, t) * env(lt, 0.05) * 0.3)
        cut = 900 * env(lt, 0.04) + 200
        return softclip(lp.step(x, cut) * 1.5) * 0.45
    return render(0.22, fill)

def purchase():          # transaction confirmed: two dark stabs, a fifth apart
    lp = LPF()
    def fill(i, t):
        out = 0.0
        for k, (f, start) in enumerate([(220.0, 0.0), (330.0, 0.18)]):
            if t >= start:
                lt = t - start
                out += detsaw(f, t) * env(lt, 0.10) * 0.45 + sine(f / 2, t) * env(lt, 0.12) * 0.25
        cut = 1500 * (0.4 + 0.6 * env(t % 0.18, 0.06))
        return softclip(lp.step(out, cut) * 1.4) * 0.5
    return render(0.45, fill)

# ---------------------------------------------------------------- output ----

def write_wav(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 0.95:                                       # clip guard only; keep design levels
        samples = [s * 0.95 / peak for s in samples]
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    return peak

def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sfx_preview")
    os.makedirs(out, exist_ok=True)
    sounds = {
        "01_decode_step1": decode_step(0),
        "02_decode_step8": decode_step(7),
        "03_decode_worm": decode_worm(),
        "04_decode_cache_big": decode_big(),
        "05_breach": breach(),
        "06_decode_armored": decode_armored(),
        "07_miss": miss(),
        "08_bomb": bomb(),
        "09_fever": fever(),
        "10_gameover": game_over(),
        "11_uitap": ui_tap(),
        "12_purchase": purchase(),
        "13_ramlow": ram_low(),
    }
    gap = [0.0] * int(SR * 0.45)
    demo = []
    for name, s in sounds.items():
        peak = write_wav(os.path.join(out, name + ".wav"), s)
        print(f"{name:<22} {len(s)/SR:5.2f}s  peak {peak:.2f}")
        demo += s + gap
    # combo run: the 8 decode steps in sequence, as they'd sound in a clean chain
    run = []
    for st in range(8):
        s = decode_step(st)
        run += s[:int(SR * 0.15)]
    write_wav(os.path.join(out, "00_decode_combo_run.wav"), run)
    write_wav(os.path.join(out, "00_demo_all.wav"), run + gap + demo)
    print("→", out)

if __name__ == "__main__":
    main()
