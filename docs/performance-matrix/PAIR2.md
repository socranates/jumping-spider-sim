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

before/full model SHA256:
49986365913bc74793c1a95487c68a004569e0bc97bbc5823c80deb252c287e5.
Studio PID 8796 is stopped and closed without saving temporary editor state;
the immutable file hash still matches. pair2/before-full retains the original
bounded output and collected data. The endpoint screenshot was taken only
after native PASS and is a selected view, not a matched-camera visual proof.

The remaining cohorts and the strict .01 camera comparison are not complete
yet. No end-to-end gain, physical-phone result, universal clipping or natural
life qualification follows. Endpoint attachment alone is not continuous
support proof. The ordinary source/export build is unchanged by this work.
