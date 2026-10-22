# Controlled desktop performance measurements

This directory contains diagnostics, not production gameplay changes. Never publish the profiling place files. The current frozen candidate is `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5`, evidence `1984fdd8e8dee0ad` (save-slot isolation). The older v5 artifacts below remain historical diagnostics.

## Reproducible inputs

`build.py` creates four isolated places from exact Git source: v51 baseline `14e60991c785c4293c3560e6d8b7ecded7e7ac75` and the candidate, each at full and low detail. It verifies every production source blob, matching world/lighting configuration, and 22 unchanged geometry, environment and camera inputs. The diagnostic driver is the sole extra module. A native source guard verifies the complete loaded module set and the driver hash before Play.

The v5 set is at `C:\Users\natha\claude-xfer\Windowsill-perf-5cf7b4c-v5`. Its manifest records file hashes. The initial baseline smoke used an earlier isolated wrapper with only its diagnostic driver and benchmark intervals updated; all baseline production modules and the final driver were checked in Studio. No profiling place has been published.

## Measurements

`benchmark.luau` runs seven scenes (sill dawn, hut night, rainy garden, windy meadow, pond, doorway and lamppost night), then three actual walking transitions. It uses the existing input, motor, streaming and ordinary camera. Free mode retains normal AI and the advancing day clock. Snapshots record the actual start/end positions, clock, weather, active actors, camera, instance count, memory and look-part count.

The comparative configuration warms each fixture for 15 seconds and samples for 20 seconds. Raw rendered-frame intervals and per-system callback timings are recorded. Focus loss or viewport changes reject a run. Geometry must arrive and the spider must remain attached. Actor state is recorded rather than assumed identical: the existing fresh-life hook does not reset every predator. Review those differences before interpreting comparisons.

Records are split into small JSON-quoted chunks with byte counts and Adler32 checksums to detect truncated Studio logs. `collect.py` verifies those records, recomputes statistics from raw frame intervals, and requires all scenes, all crossings, a completion marker and the matching native source/driver guard. `--run-id` selects a single trial. Short smoke intervals remain `comparison_config: false` even when the harness completes.

## Current status

The v5 smoke completed all 11 records with matching source guard and no failures (`smoke-v5-final.json`). It used one-second warmups and two-second static samples; it is **not comparative performance evidence**. Prior incomplete smokes exposed harness startup and viewport-settling problems; these were corrected only in diagnostics. Do not quote FPS gains from these smokes.

The first full-length baseline measurement started after the Windows test process exited, then was rejected when the desktop focus changed during the meadow sample (`baseline-full-focus-rejected.json`). It is incomplete and cannot support comparative claims. The four-way desktop comparison, eighth broader audit scene, 30-minute memory trace and physical phone measurements remain pending. Lighting, habitat density, collision and simulation rules have not been reduced to make benchmark numbers better.

The builder now requires `--candidate-ref FROZEN_COMMIT` rather than silently selecting the earlier candidate. For the verified adapter source use `dc1c4b8640014a5718b6dc17d31044aca070c6d7`. It still refuses any working-tree source that differs from that commit. The audit's eighth scene is a **long continuous walk across three regions**; the v5 smoke's three separate short seam probes do not fulfill that requirement. Add and verify a continuous trace before calling the full matrix complete.

## v6: the continuous audit walk

The four regenerated full/low baseline/candidate places are at `C:\Users\natha\claude-xfer\Windowsill-perf-3647a94-v6b`, with exact hashes and source fingerprints in `manifest-v6.json`. All 22 geometry, environment and camera dependencies still match. No runtime game module changed for this diagnostic update.

The eighth audit scene now holds ordinary Forward input continuously from x=-60, z=-550 to z=-720, through pad_a2, pad_b2 and pad_c2. It records a roughly one-second pose/region trace, never places or starts a fresh life during the walk, and refuses detachments, sideways drift, a stalled route or a duration under 60 seconds. A static collision feasibility probe completed 4,081 fixed ticks / 68.02 simulated seconds / 170.04 studs without detaching, through those three regions. This is feasibility evidence on the CLI shim, not native timing evidence. The original proposed finish at z=-780 met a physical obstruction at z=-729.69; the diagnostic endpoint stops earlier after all three regions have been entered. No world geometry was changed to clear the route.

`collect.py` checks the route, raw rendered-frame duration, pose continuity, required regions and absence of resets/placements. A v6 run missing or failing this scene cannot be complete. A legacy complete v5 smoke remains readable but has `audit_scenes_complete=false`; `compare.py` refuses it for the full audit comparison. Seven synthetic collector tests cover a valid record, a missing route, a teleport, a shortened capture, a reset, disabled-predator workload and the legacy distinction. They are parser tests, not benchmark measurements.

The v6 places have been built and the driver compiles; native route smoke and the four-way full-length matrix are still pending. Do not quote performance gains. Keep full/low viewport, focus and engine configuration matched, and do not run CPU-heavy tests while timing. The optional region-cycle trace uses placements between scenes and is separate from the eighth scene's uninterrupted walk; it does not by itself prove a continuous 30-minute player journey.

The v6 configuration explicitly enables Wasp, Cat, Bird and Frog. The SilkPlayback marker otherwise disables the wasp and cat in the production controller's test-place path, so the older v5 smoke must not be described as a full predator workload. Each timed record now includes predator enabled flags and states before and after; collection refuses missing/disabled workloads. Both roles still use the explicitly recorded Free/gentle mode, not Normal-mode mortality or a worst-case predator encounter.

### Native execution status after save verification

The separate save-isolation native review completed with 216/216 production fingerprints, 274/0/0 preserve checks and 9 native save cases / 110 checks. Its receipts are in `docs/save-slot-isolation/`. These are correctness results, not paired performance evidence.

The v6b baseline-full place opened in Studio, but selection/activation of the new Studio window failed with `foreground window did not report a process id`. Refreshing the window inventory and retrying once produced the same error; UI input stopped under the computer-use recovery rule. No v6b source guard or timed run was executed. The actual continuous route and the corrected enabled-predator workload still require native validation before the full matrix can be called complete. Do not infer a benchmark from the static route probe or synthetic collector tests.
