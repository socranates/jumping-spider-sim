# Current cache-only native comparison

2026-10-24. Ordinary game source is unchanged evidence 105c83862d500f43,
273 sources, from source/test commit c8054893. Integration HEAD at preparation
is 28b5dff9. No upload, online save, lighting, camera, control or ecology edit.

The four unbound diagnostic models in pair2-builds.json differ only in the
shared base-record reuse block of LookPlan. Both versions retain the current
hut detail reservation, all current ground, per-level caching, budgets and
generators. This corrects a comparator problem: using the entire older
LookPlan would also reverse the newer home-detail policy. Historical pair1
data and its camera mismatches are unchanged and remain unqualified.

Preparation compiles/types all 276 sources in each model. The actual staged
variants pass 2431 full-view checks, 1800 low-view checks and 574 plan
comparisons: 4805 total. For 300 cold regions, full-view generation falls
from 900 calls to 300; all records and current render plans compare equal.
This proves the cache mechanism and output equivalence, not a general FPS gain.

Native order is before/full, after/full, after/low, before/low. Each run uses
ordinary live creatures, fixed authored weather, the corrected 65-degree
game camera, the same method observer, 5 action seconds of warmup and 20 of
measurement per stationary scene. The final measured input walk must cross
garden_a1, garden_a2 and garden_a3 without transport during measurement.
No UI snapshot or heavy local command runs during the timed samples.

## Completed cohorts

| Variant | Run | Status | Source guards | Notes |
|---|---|---|---:|---|
| before/full | 1792837930256 | PASS | 2 | All nine workloads and cleanup; walk 150.08 studs/60.03 action seconds, alive/attached endpoint |
| after/full | 1792838564863 | PASS | 2 | All nine workloads and cleanup; same walk distance and endpoint; profiler UI used only after PASS |
| after/low | 1792839907557 | PASS | 2 | All nine workloads and cleanup; walk 3602 frames, no frame over 50 ms |
| before/low | 1792840384575 | PASS | 2 | All nine workloads and cleanup; walk 3598 frames, no frame over 50 ms |

before/full model SHA256:
49986365913bc74793c1a95487c68a004569e0bc97bbc5823c80deb252c287e5.
Studio PID 8796 is stopped and closed without saving temporary editor state;
the immutable file hash still matches. pair2/before-full retains the original
bounded output and collected data. The endpoint screenshot was taken only
after native PASS and is a selected view, not a matched-camera visual proof.

All four cohorts are collected with --require-methods, two source guards each,
zero CreatorErrors, and complete memory-save fixture cleanup. Each editor was
stopped and closed without saving temporary state; all four immutable model
hashes match pair2-builds.json. Warning records remain in their bounded output.

pair2-comparison.json/.md pass --require-matched: zero camera mismatches at
the unchanged .01 tolerance. Scene positions, rain, wind, clocks, actors,
ordinary-live state and per-pair viewport dimensions also match. Full uses
1360x441; low uses 1360x436 after the command bar was reopened. This is a
within-tier comparison, not a claim that full/low viewport areas are identical.
All game cameras use FOV 65. Endpoint JPEGs are post-PASS selected views only.

Interpretation: full-tier means range from -2.8% to +3.2%; low-tier means are
mostly near the observed 16.67 ms cadence, with the night hut +3.3%. Its
80.61 ms candidate hitch is retained, as are all other adverse observations.
There is no uniform end-to-end speedup. Streaming-walk replan means are
2.7104/2.7077 ms before/after at full and 1.4909/1.4472 ms at low; low worst
replan is 5.65/7.09 ms. These are descriptive one-pair observations with live
actors and GC, not a causal estimate or statistical non-regression guarantee.
The 4805 equivalence checks and 900-to-300 cold-generation reduction remain
the direct mechanism/output evidence.

No physical-phone result, universal clipping or natural-life qualification
follows. Endpoint attachment alone is not continuous support proof. Startup
sample records have zero render frames/1x1 initial view and must not be used
as first-visible-frame or startup-FPS measurements. Ordinary source/export is
unchanged; the separate engine-phase probe and profiler scopes stay separate.
