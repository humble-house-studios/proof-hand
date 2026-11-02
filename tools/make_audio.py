#!/usr/bin/env python3
"""Generates Proof Hand's sound effects into audio/ (stdlib only, WAV).
Re-run after editing: python3 tools/make_audio.py"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.85 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def tone(freq, dur, vol=1.0, decay=8.0, shape="sine", attack=0.004):
    out = []
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        ph = 2 * math.pi * freq * t
        if shape == "square":
            v = 1.0 if math.sin(ph) > 0 else -1.0
        elif shape == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:
            v = math.sin(ph)
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(v * env * vol)
    return out


def noise(dur, vol=1.0, decay=20.0, seed=1):
    rnd = random.Random(seed)
    return [rnd.uniform(-1, 1) * math.exp(-decay * i / RATE) * vol for i in range(int(RATE * dur))]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out


# Chalk tap: a short scratchy click.
write("select", mix(noise(0.06, 0.6, 60, 2), tone(1400, 0.05, 0.4, 60)))
write("deselect", mix(noise(0.05, 0.4, 70, 3), tone(900, 0.04, 0.3, 70)))
# Chips (blue) and Mult (red) ticks: rising blips; the UI shifts their pitch.
write("chip", tone(880, 0.09, 0.8, 30, "tri"))
write("mult", tone(1320, 0.1, 0.8, 26, "square"))
write("xmult", mix(tone(660, 0.22, 0.7, 10, "square"), tone(990, 0.22, 0.5, 10, "square")))
# The slam: chips × mult land.
write("slam", mix(noise(0.25, 0.9, 14, 4), tone(110, 0.35, 1.0, 9), tone(220, 0.3, 0.6, 10)))
# NOVEL stamp: a thump and a bright chime.
write("stamp", mix(noise(0.12, 1.0, 30, 5), tone(90, 0.2, 1.0, 16), seq([0.0] * int(RATE * 0.08), tone(1760, 0.5, 0.5, 6))))
# Coins at cash out, and buying.
write("coin", mix(tone(1568, 0.12, 0.6, 18, "square"), seq([0.0] * int(RATE * 0.06), tone(2093, 0.25, 0.6, 12, "square"))))
write("buy", seq(tone(784, 0.07, 0.7, 30, "tri"), tone(1175, 0.16, 0.7, 14, "tri")))
write("discard", noise(0.18, 0.7, 18, 6))
# Blind proven / refuted / run won.
write("proven", seq(*[tone(f, 0.12, 0.8, 10, "tri") for f in (523, 659, 784)], tone(1047, 0.45, 0.9, 5, "tri")))
write("refuted", seq(*[tone(f, 0.18, 0.8, 7, "tri") for f in (392, 349, 311)], tone(262, 0.6, 0.9, 4, "tri")))
write("qed", seq(*[tone(f, 0.1, 0.8, 10, "square") for f in (523, 659, 784, 1047, 784, 1047)], tone(1319, 0.8, 0.9, 3, "square")))
print("wrote", len(os.listdir(OUT)), "files to audio/")
