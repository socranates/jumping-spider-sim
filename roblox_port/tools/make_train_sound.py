#!/usr/bin/env python3
"""Compose train.wav (ROBLOX-115): the rumble of a train passing on the railway beyond the preserve's north fence (Client/TrainPass).

12 s, mono, 22050 Hz, 16-bit, a seamless loop (the game plays it looped on the middle car while a train is out on the line; Roblox's distance roll-off makes
it swell and fade as the train passes). Brown noise low-passed into a deep rumble with a slow swell, a band of steel hiss from the wheels, and the
two-beat clack of a bogie's wheels over rail joints every 0.85 s (a 15 m car at about 50 km/h crosses a joint with each bogie in turn), each clack a
short damped thump. Seeded, so the file is the same on every run. Peak near -12 dBFS. Not uploaded yet: its roblox_asset_id in the manifest is empty
until Nathan uploads it (then Client/TrainPass.SOUND takes the id).
"""
import hashlib
import json
import pathlib
import wave

import numpy as np

SR = 22050
LOOP = 12.0
N = int(SR * LOOP)
t = np.arange(N) / SR
rng = np.random.default_rng(115)


def lowpass(x, cutoff):
    """A circular one-pole low-pass (run twice round so the loop has no seam)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for _ in range(2):
        for i in range(len(x)):
            prev = (1 - a) * x[i] + a * prev
            y[i] = prev
    return y


white = rng.standard_normal(N)
brown = np.cumsum(white)
brown -= np.linspace(0, brown[-1] - brown[0], N)  # (so it ends where it began)
brown -= brown.mean()
rumble = lowpass(brown / np.abs(brown).max(), 90.0)
rumble /= np.abs(rumble).max()
swell = 0.8 + 0.2 * np.sin(2 * np.pi * t / LOOP)
hiss = lowpass(rng.standard_normal(N), 2400.0) - lowpass(rng.standard_normal(N), 900.0)
hiss /= np.abs(hiss).max()
clacks = np.zeros(N)
period = LOOP / round(LOOP / 0.85)
k = 0
while k * period < LOOP:
    for offset, amp in ((0.0, 1.0), (0.11, 0.8)):
        start = int((k * period + offset) * SR) % N
        n = int(0.09 * SR)
        idx = (start + np.arange(n)) % N
        env = np.exp(-np.arange(n) / (0.018 * SR))
        clacks[idx] += amp * env * np.sin(2 * np.pi * 70 * np.arange(n) / SR)
    k += 1
mix = 0.55 * rumble * swell + 0.08 * hiss + 0.35 * clacks
mix *= 10 ** (-12 / 20) / np.abs(mix).max()
data = (mix * 32767).astype("<i2").tobytes()

out = pathlib.Path(__file__).resolve().parents[1] / "assets" / "audio" / "train.wav"
with wave.open(str(out), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data)
raw = out.read_bytes()
manifest_path = out.parent / "manifest.json"
manifest = json.loads(manifest_path.read_text())
entry = {"file": "train.wav", "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), "roblox_asset_id": "", "experience_access_saved": False}
manifest["files"] = [f for f in manifest["files"] if f["file"] != "train.wav"] + [entry]
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"wrote {out} ({len(raw)} bytes, {LOOP:.0f} s)")
