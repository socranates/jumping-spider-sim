# Station route preparation, v48 work in progress

The prior native litter review caught a 356.8 ms rival update. Surface graphs and neighbour seams were constructed lazily in a single update. This revision prepares complete graphs privately across frames, including their patrol waypoints, before an incremental drive may use them. It does not reduce the rival's territory, change colliders or simplify route geometry.

## Construction and movement

- Station jobs share one queue and a per-render-frame allowance of 2 ms or 2,048 work checkpoints, whichever is reached first. The time limit is cooperative, not a hard real-time guarantee: one operation, garbage collection or engine scheduling can overrun it.
- Work is held in coroutine-local graphs. Cancellation or changing worlds discards private work. A completed job publishes its graph and any fully built neighbour faces without yielding during publication. Partial seams and waypoint tables are never exposed to the incremental drive.
- The requested region is prioritised. A cold drive stands safely until its graph is ready. A patrol crossing waits for its selected destination and retains the seeded leg, rather than drawing another destination. Already prepared graphs remain usable while other jobs are queued.
- The legacy synchronous API remains for the frozen test garden and existing callers. This is an incremental preparation path, not a replacement pathfinding algorithm.

## Automated evidence

`route_preparation_reference.luau` was extracted from the archived pre-change station benchmark, not regenerated from this implementation. All 51 region fingerprints match: face geometry, standing samples, edges, neighbour seams, and waypoint order.

Targeted CLI run: route preparation 11,067/0; rival 2,843/0; rival navigation 581/0; station threats 32,883/0; world client 30/0. The preparation check count includes per-slice quota/success assertions and is not a count of distinct behaviours. Cold-drive waiting, cancellation, world change, duplicate requests, private work, pending crossing and resumption are covered explicitly.

Strict analysis is clean after regenerating the Rojo sourcemap. All 204 source files compile. Raw CLI and analysis output accompany this review. This is not the final full regression suite or a published build.

## Native evidence status

The first 70-second diagnostic used the earlier 512-checkpoint quota and overlapped CLI work, so it is diagnostic evidence, not an uncontended performance gate. All 51 jobs completed by its 40-second report, with no construction errors. Profiler: rival mean/worst 0.20/3.1 ms, surface routes 0.50/2.2 ms, total client render step 8.21/49.9 ms. Whole-frame timing included a 3,659 ms startup frame; it must not be silently excluded from the overall report.

The repeat used the production 2,048 quota with the CLI process confirmed terminal beforehand. All 51 jobs completed by the 20-second report, with no failures. Over 70 seconds the rival travelled 52.52 cm within `hut_floor_b`. After the first ten seconds, 3,078 frames averaged 19.55 ms, worst 61.57 ms. Including startup: 3,511 frames, mean 20.05 ms, worst 1,005.36 ms. The whole startup-inclusive route preparation counter recorded a 4.00 ms maximum slice, confirming the cooperative limit can overrun. The profiler started after the intro: surface routes 0.38/2.8 ms; rival 0.17/1.3 ms; total render step 6.86/22.4 ms (mean/worst).

This repeat supports removing the earlier synchronous construction spike in this scene. It does not establish a universal frame-time bound, every crossing in native play, or a low-device performance gate. The diagnostic source is `studio-route-review.luau`, installed only as Studio's `Client/SilkPlayback`.

The original full-detail shelter driver was then repeated without concurrent CLI work, with `LitterReviewStep=walk` and `LitterProfile=true`. The spider moved into the shelter, remained attached and reached the expected centre at the correct ground height. Approach: 244 frames, 20.55 ms mean, 149.43 ms worst. Under the roof: 298 frames, 16.78 ms mean, 49.07 ms worst. The short profiled under-roof segment had rival 0.14/0.6 ms and total render step 6.39/10.1 ms (mean/worst); the approach profiler had rival 0.17/0.6 ms. The approach's 149 ms frame falls outside those short profiling windows, so its source is unproven. Do not call the whole performance gate green. See `route-shelter-native.txt` and `route-shelter-under-full.jpg`.

Temporary diagnostics and the forced detail setting must be removed before publication; cleanup is recorded in the raw native receipt.

Remaining habitat work still includes ordinary traversal and hunt encounters, final dog motion and can appearance, current low-detail inspection, a frozen full CLI run, and publication verification. A stationary protected-spawn test cannot prove all-region behaviour or general performance.
