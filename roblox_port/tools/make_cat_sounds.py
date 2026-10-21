#!/usr/bin/env python3
"""Compose cat_bell.wav and cat_purr.wav (ROBLOX-118): the ranger's cat heard before it is seen (Client/CatBody's voices, Predator/Cat.sound's loudness).

cat_bell.wav: 2 s, a seamless loop of a small collar bell jingling with the steps of a cat's walk (about two steps a second): each jingle a few bright,
inharmonic partials (a small spherical bell rings near 4 to 7 kHz with partials that are not whole multiples) with a quick attack and a decay of a
tenth of a second or so, at slightly varied times and loudness. cat_purr.wav: 4 s, a seamless loop of a purr: a low buzz at about 25 pulses a second
(a cat's purr is around 25 Hz), the in-breath and out-breath alternating every second or so with a slightly different pitch and loudness, through a
gentle low-pass. Both mono, 22050 Hz, 16-bit, peak near -12 dBFS, seeded so the files are the same on every run. Recordings made by this script, not
of a cat. Not uploaded yet: their roblox_asset_id in the manifest is empty until Nathan uploads them (then Client/CatBody.SOUNDS takes the ids).
"""
import hashlib
import json
import pathlib
import wave

import numpy as np

SR = 22050
rng = np.random.default_rng(118)
OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "audio"


def write(name, mix, seconds):
    mix = mix * (10 ** (-12 / 20) / np.abs(mix).max())
    data = (mix * 32767).astype("<i2").tobytes()
    out = OUT / name
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    raw = out.read_bytes()
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    entry = {"file": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), "roblox_asset_id": "", "experience_access_saved": False}
    manifest["files"] = [f for f in manifest["files"] if f["file"] != name] + [entry]
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {out} ({len(raw)} bytes, {seconds:.0f} s)")


# the bell: jingles with the steps
BELL_S = 2.0
n = int(SR * BELL_S)
bell = np.zeros(n)
partials = [(4300.0, 1.0), (6100.0, 0.55), (7900.0, 0.3), (5200.0, 0.4)]
step = BELL_S / 4
for k in range(4):
    for j in range(rng.integers(2, 4)):
        start = int((k * step + rng.uniform(0, 0.08) + j * rng.uniform(0.02, 0.05)) * SR) % n
        length = int(0.25 * SR)
        idx = (start + np.arange(length)) % n
        tt = np.arange(length) / SR
        env = (1 - np.exp(-tt / 0.002)) * np.exp(-tt / rng.uniform(0.06, 0.12))
        amp = rng.uniform(0.5, 1.0)
        tone = sum(a * np.sin(2 * np.pi * f * rng.uniform(0.98, 1.02) * tt + rng.uniform(0, 6.28)) for f, a in partials)
        bell[idx] += amp * env * tone
write("cat_bell.wav", bell, BELL_S)

# the purr: a low buzz of pulses, in-breath and out-breath
PURR_S = 4.0
n = int(SR * PURR_S)
t = np.arange(n) / SR
breath = np.sin(np.pi * t / 1.0) ** 2  # (two breaths in the loop's four seconds: in and out, a second each)
rate = np.where((t % 2.0) < 1.0, 24.0, 26.5)
phase = 2 * np.pi * np.cumsum(rate) / SR
phase *= (2 * np.pi * round(phase[-1] / (2 * np.pi))) / phase[-1]  # (a whole number of pulses round the loop)
pulses = np.maximum(0, np.sin(phase)) ** 6
noise = rng.standard_normal(n)
a = np.exp(-2 * np.pi * 600 / SR)
low = np.zeros(n)
prev = 0.0
for _ in range(2):
    for i in range(n):
        prev = (1 - a) * noise[i] + a * prev
        low[i] = prev
purr = pulses * low * (0.35 + 0.65 * breath)
write("cat_purr.wav", purr, PURR_S)
