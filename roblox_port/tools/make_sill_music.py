#!/usr/bin/env python3
"""Compose sill_music.wav: an original, very light ambient loop for The Windowsill.

64 s, mono, 22050 Hz, 16-bit, seamless loop. Four slow chords (Am9, Fmaj7, Cmaj7, Em7),
each held 16 s with 6 s equal-power crossfades computed circularly so bar 4 folds back
into bar 1 without a seam. Each chord is a soft additive pad (sine + quiet 2nd/3rd
partials, slow detune shimmer, slow amplitude breathing). Over it, seven sparse
music-box notes from A pentatonic, very quiet, placed off the grid so the loop does
not announce itself. Peak kept near -14 dBFS; the game's mix will play it quieter still.
"""
import numpy as np
import wave
import hashlib
import sys

SR = 22050
LOOP = 64.0
N = int(SR * LOOP)
t = np.arange(N) / SR
rng = np.random.default_rng(1018)

def pad_voice(freq, amp, phase):
    """A soft pad partial: sine + quiet octave and twelfth, two detuned copies, slow breathing."""
    out = np.zeros(N)
    for det, w in ((-0.9, 0.5), (0.9, 0.5)):
        f = freq * (1.0 + det / 1200.0)  # ±0.9 cents
        for mult, pw in ((1.0, 1.0), (2.0, 0.22), (3.0, 0.07)):
            # a whole number of cycles per loop, so every oscillator is exactly periodic
            fq = round(f * mult * LOOP) / LOOP
            out += pw * w * np.sin(2 * np.pi * fq * t + phase + mult)
    breathe = 1.0 + 0.12 * np.sin(2 * np.pi * t / 19.0 + phase)  # 19 s breathing, not loop-locked... 64/19 not integer
    # keep the breathing loop-safe: use periods that divide the loop
    breathe = 1.0 + 0.12 * np.sin(2 * np.pi * t * (2.0 / LOOP) + phase)  # 32 s period
    return amp * out * breathe

# Chords: (name, [(freq, amp), ...]) — intimate middle register, root doubled an octave down, color notes quiet.
A3, C4, E4, B4 = 220.00, 261.63, 329.63, 493.88
F3, G3, G4, D4, E3, B3 = 174.61, 196.00, 392.00, 293.66, 164.81, 246.94
C5 = 523.25
CHORDS = [
    [(A3 / 2, 0.30), (A3, 1.00), (C4, 0.55), (E4, 0.70), (B4, 0.18)],          # Am(add9)
    [(F3 / 2, 0.30), (F3, 1.00), (A3, 0.60), (C4, 0.55), (E4, 0.35)],          # Fmaj7
    [(C4 / 2, 0.30), (C4, 1.00), (E4, 0.60), (G4, 0.45), (B4, 0.16)],          # Cmaj7
    [(E3 / 2, 0.30), (E3, 1.00), (G3, 0.60), (B3, 0.55), (D4, 0.35)],          # Em7
]
SEG = LOOP / len(CHORDS)   # 16 s per chord
XF = 6.0                   # 6 s equal-power crossfade

def seg_env(i):
    """Circular equal-power envelope for chord i: rises over XF into its slot, falls over XF out of it."""
    start = i * SEG
    # phase position relative to this chord's slot, circularly
    rel = (t - start) % LOOP
    e = np.zeros(N)
    up = (rel < XF)
    e[up] = np.sin(0.5 * np.pi * rel[up] / XF) ** 2
    hold = (rel >= XF) & (rel < SEG)
    e[hold] = 1.0
    down = (rel >= SEG) & (rel < SEG + XF)
    e[down] = np.cos(0.5 * np.pi * (rel[down] - SEG) / XF) ** 2
    return e

pad = np.zeros(N)
for i, chord in enumerate(CHORDS):
    env = seg_env(i)
    voice = np.zeros(N)
    for j, (f, a) in enumerate(chord):
        voice += pad_voice(f, a, phase=1.7 * j + 0.9 * i)
    pad += env * voice
pad /= np.max(np.abs(pad))

# Sparse music-box notes: A pentatonic around the pad, soft sine with a gentle strike and long decay.
def note(freq, at, amp, dur=4.0):
    n0 = int(at * SR)
    ln = int(dur * SR)
    idx = (np.arange(ln) + n0) % N   # circular placement keeps the loop seamless
    tt = np.arange(ln) / SR
    env = (1 - np.exp(-tt / 0.012)) * np.exp(-tt / 1.4)
    tone = np.sin(2 * np.pi * freq * tt) + 0.18 * np.sin(2 * np.pi * freq * 2 * tt) * np.exp(-tt / 0.5)
    out = np.zeros(N)
    np.add.at(out, idx, amp * env * tone)
    return out

A4, E5, G4n, D5 = 440.0, 659.25, 392.0, 587.33
mel = np.zeros(N)
for f, at, a in [
    (E5, 3.5, 0.10), (C5, 9.0, 0.08), (A4, 21.0, 0.10), (G4n, 27.5, 0.07),
    (D5, 37.0, 0.09), (C5, 44.5, 0.07), (A4, 57.0, 0.09),
]:
    mel += note(f, at, a)

# Air: a whisper of noise, made exactly periodic by tiling the same period below.
noise = rng.standard_normal(N)

def onepole(x, hz):
    b = np.exp(-2 * np.pi * hz / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = b * acc + (1 - b) * x[i]
        y[i] = acc
    return y

# Every source is exactly periodic in LOOP (envelopes and notes are circular, the noise is
# tiled), so filtering two periods and keeping the SECOND gives a seamless loop: the filters'
# cold start decays inside the first period, and the second's end flows into its start.
air2 = onepole(np.tile(noise, 2), 900.0)
air2 /= np.max(np.abs(air2[N:]))
mix2 = 0.82 * np.tile(pad, 2) + np.tile(mel, 2) + 0.05 * air2
warm = onepole(mix2, 2800.0)[N:]
warm /= np.max(np.abs(warm))
warm *= 10 ** (-14 / 20)   # peak ~ -14 dBFS

pcm = np.clip(warm * 32767, -32768, 32767).astype('<i2')
out = sys.argv[1] if len(sys.argv) > 1 else 'sill_music.wav'
with wave.open(out, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())

# Report: seam continuity, levels
seam = abs(int(pcm[-1]) - int(pcm[0]))
rms = 20 * np.log10(np.sqrt(np.mean(warm ** 2)) + 1e-12)
peak = 20 * np.log10(np.max(np.abs(warm)))
print(f"wrote {out}: {len(pcm)*2+44} bytes, {LOOP}s, seam step {seam} LSB, peak {peak:.1f} dBFS, rms {rms:.1f} dBFS")
print("sha256", hashlib.sha256(open(out, 'rb').read()).hexdigest())
