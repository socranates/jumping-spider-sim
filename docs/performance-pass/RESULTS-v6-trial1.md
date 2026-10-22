# Desktop performance review, 2026-10-22

**Result: four verified native Studio trials; no general or causal speedup established.** This closes the first desktop full/low measurement matrix. It does not close the broader performance audit or establish publication readiness. No production source changed during collection and nothing was published.

## Exact inputs

- Published v51 baseline: `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place version 140, evidence `d9ddc5e0ed43d301`.
- Unpublished save-slot-isolation candidate: `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5`, evidence `1984fdd8e8dee0ad`.
- Diagnostic manifest: `manifest-v6.json`, generated v6b places. Driver SHA-256 `f72b78df9353a6521b62392ac096ae876980ea8ce694ee416d2fe5c304b7bc73`.
- Native guards: baseline 216/216 and candidate 217/217 loaded scripts, including the diagnostic driver. All 22 geometry, environment and camera dependencies match. Original place files were preserved, editor saves archived separately, and manifest hashes restored.
- Laptop: Ryzen 3 7320U, 4 cores / 8 threads, integrated AMD Radeon, approximately 7.25 GiB physical RAM, Windows 11 Home build 26200. Full hardware/driver record: `host.json`.
- Engine `0.744.0.7441077`, viewport 1105 x 433, foreground, Free/gentle mode, normal advancing clock; Wasp/Cat/Bird/Frog explicitly enabled. Not Normal mortality or a worst-case predator encounter.
- Seven static scenes: 15-second warmup / 20-second capture each. Three additional real-input short crossings. Eighth audit scene: approximately 68 seconds / 170 studs of continuous real-input walking across pad_a2, pad_b2, pad_c2, with no placements or fresh-life resets during it.

## Frame times

Milliseconds; lower is better. Each cell lists baseline / candidate. Each tier has one pair, in baseline-then-candidate order. Do not interpret a single delta as an optimization effect. Raw frame intervals and callback timing rows remain in the JSON/log artifacts.

### Full detail

| Scene | Mean ms B / C | p95 ms B / C | Maximum ms B / C |
|---|---:|---:|---:|
| sill_dawn | 19.34 / 18.06 | 27.95 / 23.94 | 128.40 / 60.96 |
| hut_lamp_night | 22.58 / 21.88 | 29.94 / 29.87 | 40.82 / 45.78 |
| garden_rain | 20.50 / 19.13 | 28.96 / 24.77 | 42.77 / 33.17 |
| meadow_wind | 20.42 / 19.57 | 26.67 / 26.53 | 40.88 / 35.67 |
| pond | 20.71 / 19.37 | 28.42 / 25.73 | 38.40 / 72.56 |
| can_doorway | 18.84 / 19.76 | 26.35 / 26.84 | 36.68 / 49.33 |
| lamppost_night | 18.12 / 20.55 | 22.74 / 25.88 | 37.11 / 38.47 |
| walk_1 | 20.73 / 21.72 | 25.93 / 26.06 | 32.49 / 31.76 |
| walk_2 | 19.09 / 20.62 | 24.60 / 26.97 | 32.28 / 35.85 |
| walk_3 | 20.88 / 26.52 | 25.90 / 33.68 | 34.87 / 37.64 |
| walk_continuous | 21.28 / 22.91 | 30.77 / 32.65 | 90.78 / 59.76 |

### Low detail

| Scene | Mean ms B / C | p95 ms B / C | Maximum ms B / C |
|---|---:|---:|---:|
| sill_dawn | 16.78 / 18.28 | 18.88 / 23.46 | 41.68 / 39.72 |
| hut_lamp_night | 17.75 / 18.38 | 23.46 / 24.42 | 33.04 / 58.60 |
| garden_rain | 16.67 / 18.50 | 18.26 / 24.36 | 22.54 / 41.07 |
| meadow_wind | 16.67 / 16.67 | 18.02 / 18.29 | 26.10 / 29.96 |
| pond | 17.06 / 17.28 | 20.52 / 21.36 | 45.04 / 100.36 |
| can_doorway | 16.66 / 16.82 | 18.02 / 18.78 | 23.89 / 31.15 |
| lamppost_night | 16.67 / 16.68 | 18.02 / 18.27 | 23.19 / 23.35 |
| walk_1 | 16.72 / 17.27 | 18.22 / 22.06 | 23.87 / 29.58 |
| walk_2 | 16.66 / 16.67 | 17.87 / 18.44 | 19.09 / 32.95 |
| walk_3 | 16.73 / 16.66 | 18.41 / 18.09 | 21.13 / 23.31 |
| walk_continuous | 17.56 / 17.42 | 23.40 / 23.32 | 35.75 / 60.52 |

## Interpretation

Full detail improves in some static samples and worsens in others and in the walking samples. The low-detail continuous walk is nearly unchanged (17.56 / 17.42 ms mean; 23.40 / 23.32 ms p95). Low detail is near the 60 Hz frame interval in many scenes, so an apparent tie there does not prove equal spare rendering capacity. The 128.40 ms baseline-full maximum and 100.36 ms candidate-low maximum are isolated observed hitches, not explained causes. No promise of smoother play follows from this pair.

The `spider rig` script timing slice is the largest full-detail callback component: approximately 2.29-3.72 ms mean per scene across the full-detail trials, versus 0.41-1.48 ms on low detail. Sound and camera are also material components. These are script callback slices, not GPU timings, and they do not attribute all of a rendered frame. The rig source already uses two reusable `BulkMoveTo` batches and small movement thresholds. Adding batching again would not be a new optimization. Next isolate pose math, foothold raycasts, hair transforms and engine batch movement before choosing a change. Keep hair density, anatomical poses, movement, camera and lighting intact.

Both pairs match the recorded actor summaries: region, active-population IDs, species counts, predator enabled flags and state labels. They do **not** prove identical actor poses, RNG state or internal routes. Static camera matrices, spider positions, FOV and look-part counts match; the moving endpoint differences are at most 0.08338 studs on full and 0.04169 on low (a few fixed ticks). Reviewed comparison files record these deltas explicitly. The older full comparison with the overly broad `all_actor_states_match` field is retained and marked superseded.

## Evidence and environment limits

- `verify_matrix.py` reconstructs all four trials from bounded native logs, verifies snapshot hashes, checks all 52 records / 44 timed samples, and regenerates both reviewed comparisons. `matrix-receipt.json` records artifact hashes and the deliberately false speedup/release claims. Seven synthetic collector regression tests also pass; they are parser tests, not additional native runs.
- No screenshots, CPU-heavy tests, compression or deliberate focus changes during timed samples. Each trial kept the same one stopped native-review Studio window in the background.
- Studio emitted plugin-update lock contention during all four runs (7, 7, 7 and 6 engine error entries for baseline-full, candidate-full, baseline-low and candidate-low respectively). These are retained as categorized counts/times, separate from game script errors; no CreatorError or script timeout was recorded in these process logs.
- Other engine Error entries occurred outside the timed interval, including startup service failures, one denied asset ID 203785492, redundant feature flags and save-dialog shutdown messages. That asset ID was not found in production source; its owner was not established. Do not equate a clean game-script result with a clean engine process.
- A sponsored Adobe Express overlay was visible at candidate-full startup and end; its state during samples is unknown. Thermal state, cache order, Studio overhead and changing host load are uncontrolled. A read-only between-run OS check showed little free physical memory, but this does not establish the cause of any hitch.
- An earlier low editor bootstrap failed to load built-in MaterialPicker before Play. It was excluded, retained in `baseline-low-v6-bootstrap-rejected.json`, then retried in a fresh editor. No timed trial was silently restarted.
- Instance/Lua/engine memory snapshots exist, but these roughly seven-minute sequences with fresh-life fixture resets are not a 30-minute leak test. Engine memory varies with cache/GC; a decreasing number does not prove absence of leaks.
- No MicroProfiler client/server capture, network profiling, emulator, physical phone, startup first-frame/playable measurement or actual online client disconnect/rejoin is supplied by this matrix. It is desktop Studio evidence only.

## Next bounded work

1. Separate diagnostic instrumentation for the measured rig slices; do not modify this frozen v6 driver or retrospectively reuse its hashes for new instrumentation.
2. A source-bound 30-minute lifecycle/memory session with no fresh-life resets, per-category memory, instances/connections where observable, live frame activity and strict focus/viewport tracking. Region placements may test lifecycle churn, but must be disclosed and never called uninterrupted walking.
3. Repeated paired trials for any actual optimization; inspect MicroProfiler CPU/GPU/streaming hitches. Phone/tablet emulator must be labelled emulator; a real phone remains unverified.
4. Continue correctness work: explicit legacy-world save migration, foreign-lease Continue behavior, deterministic route activation and opt-in caption/error visibility. Preserve the current source-bound save receipts and do not publish profiling/test places.
