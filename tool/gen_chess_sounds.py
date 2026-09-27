"""Generate chess sound effects as WAV files (16-bit mono 22050Hz)."""
import math
import os
import struct
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "chess")
os.makedirs(OUT, exist_ok=True)


def save(name, samples):
    samples = np.asarray(samples, dtype=np.float64)
    peak = np.max(np.abs(samples)) or 1.0
    samples = samples / peak * 0.92
    pcm = (samples * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name}: {len(samples)/SR*1000:.0f}ms")


def env(n, attack=0.004, release=0.05):
    """Linear attack / exponential release envelope."""
    a = max(1, min(n - 1, int(attack * SR)))
    r = max(1, min(n - a, int(release * SR)))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.exp(-np.linspace(0, 6, r))
    return e


def tone(freq, dur, attack=0.004, release=None, wave_fn=np.sin):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rel = release if release is not None else dur * 0.6
    return wave_fn(2 * np.pi * freq * t) * env(n, attack, rel)


def knock(dur=0.11, freq=180.0, thump=0.9):
    """Wooden knock: filtered noise burst + low sine thump."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = np.random.default_rng(7).standard_normal(n)
    # crude lowpass via cumulative smoothing
    k = 24
    noise = np.convolve(noise, np.ones(k) / k, mode="same")
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t * 55)
    return (noise * np.exp(-t * 90) * (1 - thump) + body * thump) * env(n, 0.002, 0.045)


def seq(notes, dur_each, gap=0.0, **kw):
    """Concatenate tones at given freqs (None = rest)."""
    parts = []
    step = int((dur_each + gap) * SR)
    total = step * len(notes) + int(0.1 * SR)
    out = np.zeros(total)
    for i, f in enumerate(notes):
        if f is None:
            continue
        s = tone(f, dur_each, **kw)
        out[i * step: i * step + len(s)] += s
    return out[:total]


def pad(n, v):
    out = np.zeros(n)
    out[: min(n, len(v))] = v[:n]
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


# ── select: soft high tick ──────────────────────────────
save("select.wav", mix(tone(1400, 0.045, release=0.03) * 0.5,
                       tone(2100, 0.03, release=0.02) * 0.2))

# ── move: single wooden knock ───────────────────────────
save("move.wav", knock(0.11, 190, 0.85))

# ── capture: heavier double-layer thud ──────────────────
cap = knock(0.16, 130, 0.95)
cap += pad(len(cap), np.concatenate([np.zeros(int(0.028 * SR)),
                                     knock(0.09, 240, 0.5) * 0.5]))
save("capture.wav", cap)

# ── castle: two quick knocks ────────────────────────────
c1 = knock(0.09, 170, 0.85)
c2 = pad(int(0.3 * SR), np.concatenate([np.zeros(int(0.11 * SR)),
                                        knock(0.09, 150, 0.9)]))
castle = pad(len(c2), c1) + c2
save("castle.wav", castle)

# ── check: bright two-tone chime ────────────────────────
chk = seq([1318.5, None, 987.8], 0.14, gap=0.02, release=0.3)
chk += pad(len(chk), tone(2637, 0.3, release=0.28) * 0.25)
save("check.wav", chk)

# ── illegal: low dull buzz ──────────────────────────────
ill = tone(140, 0.16, release=0.1, wave_fn=lambda x: np.sign(np.sin(x)) * 0.6)
save("illegal.wav", ill * 0.6)

# ── promote: rising sparkle ─────────────────────────────
save("promote.wav", seq([523.3, 659.3, 784.0, 1046.5], 0.09,
                        gap=-0.01, release=0.16) * 0.7)

# ── game_start: ascending arpeggio ──────────────────────
save("game_start.wav", seq([392, 523.3, 659.3, 784.0], 0.11,
                           gap=-0.01, release=0.2) * 0.8)

# ── win: victory jingle ─────────────────────────────────
win = seq([523.3, 659.3, 784.0, 1046.5, None, 1046.5], 0.13,
          gap=0.0, release=0.25)
win += pad(len(win), seq([None, None, None, None, 1568, None], 0.13,
                         release=0.4) * 0.4)
save("win.wav", win)

# ── lose: descending somber ─────────────────────────────
save("lose.wav", seq([440, 349.2, 293.7, 220], 0.18, gap=0.0,
                     release=0.3) * 0.7)

# ── draw: neutral two-tone ──────────────────────────────
save("draw.wav", seq([523.3, 523.3], 0.15, gap=0.08, release=0.2) * 0.6)

# ── low_time: urgent tick ───────────────────────────────
save("low_time.wav", tone(2000, 0.05, release=0.04) * 0.55)

print("done ->", os.path.abspath(OUT))
