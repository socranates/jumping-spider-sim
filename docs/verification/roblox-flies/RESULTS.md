# Windows flies acceptance — 2026-10-15

Evidence **e3160a3f6e3f2782**, Roblox Studio 0.743.0.7431133, Windows laptop.

- Studio: **67/67**, live-client playback: **11/11**, zero failures. JSON reports contain individual results.
- CLI: SUMMARY 182, PERCEPTION 4669, SENSOR 507, PREY 1549, GAZE 67, PRESENTATION 11, BOXWORLD 15, CLIENT 11, PERCEPTION_CLIENT 1, LOOK 72, WORLD 71; all pass (7,155 checks).
- Strict analysis: no diagnostics; all **82/82** Luau sources compile. Logs retained here.
- PREY includes 128 seeded-input rows exported from frozen Godot prey_math (1,536 comparisons), senses fixtures and feeding/population cases. The port uses Park-Miller RNG, not Godot PCG: deterministic replay within the port, not identical random decision sequences across engines.
- Native tests cover validated perches, swept landing, blocked-flight stopping, unseen population delay, nutrition conservation, escape, interruption, ambiguous association, occluded capture and rejecting ordinary-fall capture. Client playback drives a hop, capture, grip and automatic feeding, alongside the existing recovery/Focus checks.

## A-029 live-client measurement

Eight seconds each, no screenshots during measurement, test target disabled. Sensor timing includes scheduled work; quiet ticks are included. Candidates are actual scheduled sensor checks per fixed tick, not the number of flies in the habitat. This is a measured scenario, not a worst-case guarantee.

| Flies | Ticks | Candidates/tick | Rays/tick | Sensor p50/p95 (us) | Frame p50/p95 (ms) |
|---|---:|---:|---:|---:|---:|
| 3 | 480 | 0.500 | 1.667 | 17 / 259 | 16.91 / 18.11 |
| 6 | 481 | 1.832 | 7.495 | 217 / 412 | 16.89 / 18.15 |

See prey-cost.json. The screenshot was taken after timing and shows the actual client identifying fly-like prey. Earlier exploratory runs are not substituted for this build's results.

Physical controller, tablet, multi-finger touch and low-end-device frame time: **not run**, no devices available. Device prompt/layout assertions are automated, not physical-device acceptance. Full Godot suite was not rerun: frozen game code/data/SPEC were not changed. LIFE, saving, wasp and fly sound are not included in this round.
