# F01 laptop performance - 2026-10-11

## Measured result

**The 16.7 ms p95 target is missed at 1280 x 720.** F01 itself passes its
alternative reporting clause: a five-minute representative run, measured
misses, and a concrete reduction plan. This is not a 1080p performance pass.

| Phase (60 wall seconds each) | Mean FPS | Frame p95 ms | GPU p95 ms | Physics p95 ms |
|---|---:|---:|---:|---:|
| Third person, normal | 57.4 | 20.221 | 10.012 | 6.343 |
| Eye view, normal | 51.6 | 23.534 | 13.754 | 5.274 |
| Eye view, 25% simulation | 58.2 | 20.119 | 11.740 | 2.685 |
| Third person, 25% simulation | 59.5 | 19.042 | 9.795 | 2.742 |
| Hunt, normal | 57.0 | 20.477 | 10.135 | 4.157 |

Overall: 17,025 frames / 300.006896 wall seconds; mean **17.622 ms**
(56.8 fps), p95 **21.448 ms**, p99 **23.935 ms**. Ten intervals exceeded
33.3 ms, nine exceeded 50 ms; largest 429.821 ms. No script errors.

## Method and limits

- Ryzen 3 7320U / integrated AMD Radeon, 7.25 GiB usable RAM, driver 32.0.21042.1001, 1366 x 768 display. **On battery (88%), Balanced** during the final run. Hardware and sampled process memory: `hardware.json`.
- Godot 4.7.2 native Compatibility/OpenGL, 1280 x 720 viewport, VSync on, after 120 warmup render frames. Source/debug runtime, not a release-executable benchmark. No fixed-FPS or headless timing. Browser game closed; ordinary desktop apps remained open. Window was visibly foreground when checked.
- `profile_play.gd` drives the actual interactive windowsill motor, cameras and fly systems for repeatability. This is automated rendered play, not human usability evidence. Seed 4242. Quarter-speed uses SimClock, with unchanged fixed DT. The fixture label indicates speed; settings HUD is not the clock authority.
- First four phases walk back and forth. At hunt start the fixture places the spider near a freshly spawned, normally sensing/moving fly; two real legal strikes occurred, a held fly was observed, and two struggles were won with scripted taps. This arranged encounter is not a natural hunt success-rate study. `captures_seen=1` is a boolean-ever-seen indicator, not a capture counter.
- Five PNG captures block the rendering thread around 2.14, 62.15, 128.04, 188.10 and 242.40 seconds. Their stalls are retained in the raw result. The largest stall occurs during hunt setup at 240.49 seconds (teleport/spawn/first-use work); do not attribute it solely to normal movement. The other spikes are unclassified. Instrumentation also reads the master audio buffer each frame.
- Native process peak working set at the 183-second sample: **458,162,176 bytes (~437 MiB)**. It is a sampled OS peak up to that point, not a guaranteed whole-run maximum. Godot static-byte counters are not whole-process memory.
- GPU/render CPU counters are viewport measurements; process_ms is the engine frame monitor, not an isolated CPU subsystem total. Physics monitor is not specifically collision-query cost. Load-time and full collision-query budgets were not isolated.
- Baseline six-fly headless CPU test: paired prey + sensor p95 **0.673 ms** against 2 ms (`t07_cost_report.txt`). This is separate evidence, not rendered frame pacing.
- Earlier plugged-in diagnostic averaged 59.9 fps, p95 18.126 ms, but had no legal hunt and was initially occluded. It is not the final representative run, and the different power/foreground/setup conditions prevent a causal battery A/B claim.

## What is slow and next reduction plan

The normal-speed eye phase is slowest: 51.6 average fps / 23.534 ms p95,
with 13.754 ms GPU p95 versus 10.012 ms in normal third person. Its full-screen
blur/retinal shader is the first GPU optimization candidate. These figures
show correlation, not proof that this one shader accounts for all missed frames.

1. Repeat a release-runtime, plugged-in A/B with PNG capture disabled and matching camera route. Separate warm-up/first-capture work from steady-state statistics; retain both.
2. Profile the eye overlay alone, then test a lower-resolution blur buffer or fewer blur samples while preserving the sharp retinal fields, motion rings and Reduced motion. Compare before/after image quality and p95 on this laptop.
3. Investigate normal-speed physics spikes (6.343 ms p95 in third person) with named subsystem timers. The separate 0.673 ms AI/sensor result does not establish a physics bottleneck. Avoid reducing fly sensing or simulation accuracy without a measured cause.
4. Prewarm first-use hunt/struggle rendering and measure natural hunt entry separately from fixture spawning. Target p95 <=16.7 ms and no recurring >33.3 ms stalls at 720p, then explicitly test the provisional 1080p target.

No speculative optimization or game tuning was applied in this packaging round.

## Reproduce

With Godot 4.7.2, isolated APPDATA, from the project root:

```text
godot --path . --script res://docs/verification/release-slice/profile_play.gd
python docs/verification/release-slice/analyze_profile.py <user-data>/profile_frames.csv
```

Do not add --headless or --fixed-fps. Run one game at a time. The shipping
release template ignores the external --script test entry; use the editor
runtime for this fixture. Trace: `frames.csv.gz`; summary:
`performance-summary.json`; phase screenshots and complete `profile.log`.
