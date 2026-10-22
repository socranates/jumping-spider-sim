# Controlled desktop performance measurements

These are diagnostics, not production gameplay changes. **Never publish the profiling places.** The frozen candidate is `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5`, evidence `1984fdd8e8dee0ad` (save-slot isolation). The production source did not change during profiling.

## Current result, 2026-10-22

The first v6b full/low baseline/candidate matrix completed in native Studio: four source-verified trials, 52 records, 44 timed samples, including four continuous three-region walks. No game script errors or benchmark failures were recorded. **The results are mixed; no general or causal speedup is established.** This is one desktop pair per tier, not phone evidence or a completed performance audit.

Read [RESULTS-v6-trial1.md](RESULTS-v6-trial1.md) for per-scene mean/p95/maximum frame times, hardware, script costs, engine warnings, environment caveats and remaining work. [matrix-receipt.json](matrix-receipt.json) records sources, runs and artifact hashes. The authoritative comparisons are `comparison-full-v6-trial1-reviewed.json` and `comparison-low-v6-trial1-reviewed.json`. The older full comparison is explicitly marked superseded because its actor-equality field was too broad.

Reconstruct the retained native evidence without running Studio:

```text
python docs/performance-pass/verify_matrix.py
python docs/performance-pass/test_collect.py
```

The first command checks all log chunk checksums, recomputes frame statistics, validates source guards/workloads/routes, compares retained JSON against reconstructed records, and regenerates both reviewed comparisons in temporary files. It writes a fresh matrix receipt. The second runs seven synthetic parser regressions; those are not native measurements.

## Reproducible inputs

`build.py` creates four isolated places from exact Git source: published v51 baseline `14e60991c785c4293c3560e6d8b7ecded7e7ac75` and the explicit `--candidate-ref FROZEN_COMMIT`, each at full and low detail. It verifies every production source blob and matching world/lighting configuration, including 22 unchanged geometry/environment/camera inputs. It refuses working-tree source differing from the frozen commit. The diagnostic driver is the sole extra module; a native source guard verifies the entire loaded script set and driver before Play.

The current v6b files are in `C:\Users\natha\claude-xfer\Windowsill-perf-3647a94-v6b`, with exact hashes in `manifest-v6.json`. Baseline guards verify 216/216 scripts; candidate guards 217/217. Editor saves were archived separately and the original manifest-hashed files restored after use. Select each new Studio log by creation/filename and verify its actual source guard; LastWriteTime can remain stale while a process holds its log open.

## Measurement design

`benchmark.luau` uses existing input, motor, streaming and ordinary camera. Seven static scenes each warm for 15 seconds and capture for 20: sill dawn, hut night, rainy garden, windy meadow, pond, doorway, lamppost night. Three additional short real-input crossings probe seams. Each sample records raw rendered-frame intervals, script callback timings, clock/weather, camera/FOV, position, active population, predator summary, instances, memory and look-part counts. Focus loss, viewport changes, missing geometry or detachment reject a sample.

The eighth audit scene holds ordinary Forward input from x=-60, z=-550 to z=-720 across pad_a2, pad_b2, pad_c2. It records approximately one-second poses and regions with no placement or fresh life during the roughly 68-second / 170-stud walk. Collection checks raw frame duration, required regions, path continuity, no resets and no teleport-like displacement. A shorter CLI feasibility check remains separately labelled as shim evidence. The originally proposed finish at z=-780 met an obstruction at z=-729.69, so the diagnostic stops earlier after entering all three regions; world geometry was not changed.

The driver explicitly enables Wasp, Cat, Bird and Frog; loading it as SilkPlayback would otherwise disable wasp/cat in the controller's test-place path. Collection checks their enabled flags before and after each sample. Free/gentle mode and the normal advancing clock are recorded; this is not Normal mortality or a worst-case predator encounter.

Records use small JSON-quoted chunks, byte counts and Adler32 checksums. `collect.py --run-id RUN` selects one trial and requires completion, all scenes, source guard, the continuous walk and enabled workloads. `compare.py` requires compatible tiers/configurations. Recorded actor summaries are compared explicitly, not assumed identical; they do not establish equality of every pose/RNG/route. Moving endpoint differences are reported, not hidden.

## Remaining audit work

The 30-minute memory session, client/server MicroProfiler, startup/playable timing, network behavior, emulator and physical-phone tests remain open. The optional old trace loop cycles regions using placements and lacks the strict trace-specific focus/activity/category-memory checks required for the new session; do not treat it as a completed memory gate or continuous walk. Introduce a separately fingerprinted diagnostic version for improvements rather than modifying the frozen v6 evidence.

The largest measured full-detail script slice is the spider rig, approximately 2.29-3.72 ms mean across scenes/trials. It already uses batched part movement. Isolate its internal costs before changing it. Do not remove dense close habitat, lighting, anatomy or movement quality to flatten the numbers.

## Historical attempts

The v5 smoke (`smoke-v5-final.json`) completed 11 records at one-second warmups / two-second captures, with wasp/cat disabled by the test marker. It is not comparative or full-workload evidence. `runs.json` is its historical registry, not the current matrix. A first full-length v5 baseline lost focus and was rejected. An initial v6b UI selection error was resolved by refreshing the computer-use session; all four v6b trials subsequently ran. An early low-detail editor bootstrap failed to load MaterialPicker before Play; its rejection receipt is retained separately.

The independent save-isolation native review passed 216/216 production fingerprints, preserve self-test 274/0/0 and nine native codec/session cases / 110 checks. Those correctness receipts live in `docs/save-slot-isolation/`; they do not establish performance, actual online disconnect/rejoin or publication readiness.
