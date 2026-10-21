# Flea motion and close rendering, v48 work in progress

The old flea trajectory reset its horizontal offset at each jump. A new continuity regression failed on all five flea indices before the change: each animal snapped back toward its anchor before taking off again. A hop now begins at the previous clock-derived landing and travels to the next bounded landing, then rests there. Body heading follows the next hop. No saved state or gameplay feeding/capture rules change.

The laterally flattened body keeps its original dimensions. A separate head, four front/middle legs and two jointed hind legs replace the old single hind-leg blob. Each rig uses ten parts; full retains five pooled fleas and low retains two. Reduced Motion holds every body/head/leg transform still. The existing 420/150 living-detail limits remain unchanged.

## Verification

- Living-world checks: **3,917 passed / 0 failed**. New coverage samples hop boundaries, resting positions, clock reconstruction, actual resting hind-foot endpoints and whole-rig Reduced Motion at both detail tiers. Existing population, cleanup and instance-limit checks still pass. Repeated per-object assertions contribute to this count.
- Strict analysis: no diagnostics. **207/207** source files compile.
- Native Studio: the flea is visibly distinguishable in the ordinary camera ahead of the spider at both tiers, without markers, magnification or an added test animal. The driver relocates the observer near a real seeded floor flea; this is a close inspection, not a claim that every ordinary route encounters one.
- Native foreleg size is the authored `0.12 × 0.014 × 0.014` cm. Resting hind-foot endpoint gap is 0.00354 cm in both samples. The player remains alive and attached. Both native samples ran after CLI work finished.

| Native sample | Frames / 20 seconds | Mean / worst frame ms | Flea in viewport | Living-detail parts |
| --- | ---: | ---: | ---: | ---: |
| Full | 1,198 | 16.71 / 32.56 | 1,198 frames | 321 / 420 |
| Low | 1,199 | 16.69 / 57.17 | 1,199 frames | 145 / 150 |

Viewport counts supplement the rendered inspection; they alone do not prove visual clarity. These are local PC scene samples, not a whole-game or phone performance gate. The normal-camera images, filtered native output and Studio-only driver are included.

The inspection hook and detail override were removed in stopped Studio, confirmed by `[CHET_FLEA_REVIEW_CLEAN]` at 2026-10-21T19:18:00Z.

## Remaining continuity work

This fixes hop continuity within a floor patch. The current renderer still derives anchors from the current region, so nearby fleas can be reassigned when the observer crosses a floor-region boundary. That requires a separate continuity repair before a final validation freeze. Close-detail cell rebuilds also still use a 24 cm key despite the newer 12 cm cell size; review that lag at ordinary walking/run speeds. Weather transitions, broader native travel and final release gates remain open. No v48 publication.
