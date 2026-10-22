# Controlled desktop performance measurements

This directory contains diagnostics, not production gameplay changes. Never publish the profiling place files. The production candidate remains runtime `5cf7b4c0f212082342574763aaf5b19e00c4e323`, evidence `b3b1a047e958d966`; its source is frozen.

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
