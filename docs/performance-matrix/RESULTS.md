# Completed current full-tier workload

2026-10-24. Unpublished unbound Studio run1792823359752, model
423a27a2aedd23c3cdc2b6c4fe5b590c261ccb6e3a64f9bd777a451f67147e66.
Both276-source guards passed; native PASS and all nine workload samples were
collected without missing/truncated events. Ordinary creatures remained enabled.
Viewport1360x436. No UI snapshots or heavy local work ran during these samples.

This is one local current-candidate observation, not a before/after optimization
result or physical-phone measurement. Free-play fixtures fix the weather clock,
use authored arrivals, and warm each scene for5 action seconds before20 action
seconds of measurement. The traversal ends on entering the third region.

| Scene | Mean ms | p95 ms | Max ms | Frames >50 ms |
|---|---:|---:|---:|---:|
| sill_dawn | 16.85 | 19.03 | 26.93 | 0 |
| hut_lamp_night | 18.81 | 24.34 | 45.17 | 0 |
| garden_rain | 19.47 | 26.14 | 35.59 | 0 |
| meadow_wind | 20.96 | 27.94 | 56.29 | 1 |
| pond_active | 19.04 | 24.96 | 48.02 | 0 |
| can | 17.11 | 21.13 | 32.89 | 0 |
| doorway | 16.92 | 19.92 | 29.28 | 0 |
| bench_lamppost_night | 16.78 | 19.07 | 30.19 | 0 |
| three_region_walk | 17.20 | 21.71 | 36.14 | 0 |

The pond record proves an on-screen frog at5.010studs and one active damselfly.
The garden traversal crossed150.125studs, visiting garden_a1/a2/a3, finished
attached/live, and completed60.05 action seconds. Its loop checked liveness and
loading each Heartbeat, but did not record every intermediate motor mode.
Continuous support/fall logging therefore remains a separate coverage gap.
Save-fixture cleanup passed.
Only the windy-meadow workload had a frame over50ms (one56.29ms observation).

Startup is kept separate: five pre-render Heartbeat intervals summed to4.25s,
with a worst1.650s gap. It is not fixed or included in the steady-state range.
Lua heap deltas include collections; these short samples do not prove30-minute
memory stability or absence of leaks.

Zero CreatorErrors and eight CreatorWarnings were retained: four Studio style
warnings, two203785492 asset-type warnings, and two expected collision-loading
holds during the fixture's long-distance meadow/pond arrivals. Those holds
precede the warmed live samples. The original raw events retain the warnings.

The probe supports look-method timings, but this first complete fixture did not
mount that watcher (methods_instrumented=false). Per-system render callback rows,
engine/instance/network counters and heap deltas are retained. Subsequent formal
pairs explicitly mount the same watcher in all four models; do not compare
differently instrumented cohorts as a strict matched optimization result.

Full/low before/after native pairs and30-minute memory coverage remain pending.
The successful model was stopped, postguarded and closed without saving editor
state. No production build, normal source/export, online store or user save was
changed. See README.md for the retained failed pilots and pair1-builds.json for
the four statically qualified comparison models.
