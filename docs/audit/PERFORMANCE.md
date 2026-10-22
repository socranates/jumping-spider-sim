# Performance audit

Baseline: v51, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place 140, evidence `d9ddc5e0ed43d301`.
Candidate: `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`, branch `codex/foundation-audit`.

## Established result

The small optimization removes unnecessary geometry readiness scans for absent species. A deterministic regression executes 1,000 requests each for absent director/woodlouse specs: **zero readiness calls**, while existing populated-region gates still refuse incomplete geometry and later allow construction. This measures calls avoided, not elapsed engine time or FPS. Geometry, seeds, counts, controls, camera and lighting are unchanged.

Current generator inventory: **233 regions**, **2,461 walkable box records**, **8,855 full / 1,769 low draw records** summed over those regions. These exclude separate backdrop-zone generators and extra child/support instances made by presentation builders. They are not simultaneous on-screen or native instance counts; the older review's 1,410-box figure is not the current preserve total.

Prior v51 native receipts in `docs/verification/v51` are retained unchanged. Their long preserve traversal recorded about 36 ms mean total frame time at the sill afterward; a later stress sample reached about 74 ms mean. Neither is a matched before/after result for this patch. Short moth views were also uncontrolled across viewport size and background load and cannot establish an optimization gain.

## Required paired benchmark matrix

| Scene | Full before / after | Low before / after | State |
|---|---|---|---|
| Sill, dawn | pending | pending | fixed camera, settled stream |
| Hut, lamp at night | pending | pending | same day / hour / camera |
| Hut garden, rain | pending | pending | same seeded weather |
| Meadow, wind | pending | pending | same vegetation and view |
| Pond, frog / damselflies | pending | pending | compare active creatures |
| Can / doorway | pending | pending | collision and occlusion |
| Bench, lamppost at night | pending | pending | shadow cost |
| Three-region walk | pending | pending | instance churn and hitches |

The initial two native attempts crashed Studio while opening the saved local v51 review copy (RSL Manager fatal runtime error), before a benchmark ran. This is a verification interruption, not evidence of a gameplay regression. After closing completed audit Studio sessions, a clean candidate session opened and matched 215 source fingerprints. Its completed foreground self-test passed 274/0/0. Never turn pending cells into zeroes or claim a phone result from a desktop emulator.

The candidate's post-traversal sill sample was **285 frames, mean 17.6 ms (57 FPS), worst 32.3 ms, physics 60 FPS**. In that same run, removing the far preserve gave 21.1 ms and disabling shadows gave 17.8 ms. Those short sequential samples do not show that deleting scenery improves performance, nor establish a source-change gain over the old 36 ms sample: machine pressure and viewport were not controlled between builds. Preserve the raw data in `native-final.txt`; leave the paired matrix pending.

Measure total frame mean/p95/max, per-system render callback time, sampled heap growth, instance count, load time and network traffic. Warm the same scene for the same interval; compare identical camera viewport and input trace; record machine and tool versions. Capture a 30-minute memory trace and preserve raw profiler data. Keep desktop, emulator and physical phone rows separate.

## Next measured optimization candidates

1. LookStream builds required close looks atomically in one frame despite its ordinary 120-part budget. Stage complete models while retaining the old visible set, then swap; never remove walkable collision or expose gaps while building.
2. LivingWorld's 12-stud close-detail cell transitions can recreate many instances. Add hysteresis or reuse after measuring the rebuild cost at a boundary.
3. PondBodies reconstructs frog/darner pose specifications while active and moves absent rigs repeatedly. Throttle distant presentation and avoid repeated hidden writes only after verifying close breathing, tongue range and Reduced Motion.
4. Preserve minimal HUD still prepares strings it does not display. Extract a small view builder with a preserve integration test before bypassing logic.
5. Cache immutable species specifications and reuse draw arrays where profiles show allocation pressure. Do not cache readiness forever; streaming availability is mutable.
6. Evaluate merging **draw-only** static parts and using distance detail for hairs/grass. Keep collision boxes, material boundaries, close silhouettes and the dense spider-scale habitat.

The guide's Vercidium analogies are hypotheses for Roblox, not drop-in engine changes. The two supplied YouTube pages exposed titles but no usable transcript in the initial web read; no claim is made to have watched or independently verified their chapter advice. References: [When Your Game Is Bad But Your Optimisation Is Genius](https://www.youtube.com/watch?v=5zlfJW2VGLM), [I Optimised My Game Engine Up To 12000 FPS](https://www.youtube.com/watch?v=40JzyaOYJeY).

Persistent collision models never stream out; Atomic models stream as a unit. The current preserve deliberately keeps station/verge regions Persistent. Do not change these merely to reduce instance counts while fall-through investigation is open. [Roblox model streaming modes](https://create.roblox.com/docs/reference/engine/enums/ModelStreamingMode).
