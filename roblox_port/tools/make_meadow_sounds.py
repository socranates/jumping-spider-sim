#!/usr/bin/env python3
"""Compose cricket_chirp.wav and robin_call.wav (ROBLOX-120): the field cricket's song and the robin's call (Client/BirdBody's voices).

cricket_chirp.wav: 2 s, a seamless loop of a field cricket's calling song: short chirps, between two and three a second (the notebook's page: the fall field
cricket's chirps two or three a second, each of a few pulses, a pulse a closing of the forewings), each chirp four pulses of a pure tone near 4.5 kHz (field crickets
sing at about 4 to 5 kHz; a game value) of about 15 ms with a quick rise and fall. robin_call.wav: 3 s, the robin's alarm-like call the Missouri field guide writes
"pick! tut-tut-tut": a sharp down-slurred note near 3 kHz, then three short lower notes, then quiet. Both mono, 22050 Hz, 16-bit, peak near -12 dBFS, seeded so the
files are the same on every run. Recordings made by this script, not of a cricket or a robin. Not uploaded yet: their roblox_asset_id in the manifest is empty until
Nathan uploads them (then Client/BirdBody.SOUNDS takes the ids).
"""
import hashlib
import json
import pathlib
import wave

import numpy as np

SR = 22050
rng = np.random.default_rng(120)
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


# the cricket: five chirps in two seconds (2.5 a second), four pulses each
CHIRP_S = 2.0
n = int(SR * CHIRP_S)
song = np.zeros(n)
for k in range(5):
    start = k * CHIRP_S / 5 + rng.uniform(0, 0.02)
    for j in range(4):
        p0 = int((start + j * 0.03) * SR)
        length = int(0.015 * SR)
        tt = np.arange(length) / SR
        env = np.sin(np.pi * tt / 0.015) ** 2
        f = 4500.0 * rng.uniform(0.995, 1.005)
        song[(p0 + np.arange(length)) % n] += rng.uniform(0.8, 1.0) * env * np.sin(2 * np.pi * f * tt)
write("cricket_chirp.wav", song, CHIRP_S)

# the robin: "pick!" then "tut-tut-tut"
CALL_S = 3.0
n = int(SR * CALL_S)
call = np.zeros(n)


def note(at, dur, f0, f1, amp):
    length = int(dur * SR)
    tt = np.arange(length) / SR
    freq = f0 + (f1 - f0) * tt / dur
    phase = 2 * np.pi * np.cumsum(freq) / SR
    env = (1 - np.exp(-tt / 0.004)) * np.exp(-tt / (dur * 0.5))
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    i0 = int(at * SR)
    call[i0:i0 + length] += amp * env * tone


note(0.10, 0.09, 3600.0, 2400.0, 1.0)
for k in range(3):
    note(0.45 + k * 0.16, 0.06, 2300.0, 2000.0, 0.7 * rng.uniform(0.9, 1.0))
write("robin_call.wav", call, CALL_S)
