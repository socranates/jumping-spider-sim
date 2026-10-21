# Close ground cover, v48 work in progress

The previous normal-camera dog review showed oversized, flat clover islands with a stretched terrain-grass texture, and little upright cover near the spider. This revision replaces those slabs with small three-leaf plants on stems and adds the approved curved grass mesh on supported soil.

## Scope and limits

- Clover leaflets use smooth material, varied height and radial orientation. The stem and leaflets are purely visual. The verge's local look ceilings become 60/28 parts (full/low); the existing global look limits remain unchanged.
- Eight clover plants and twenty grass clumps form the full-detail persistent regional layer over actual soil fragments. This continues beyond the small close-detail ring. Low keeps four clovers, four grass clumps and the structural litter. Both still fit their 60/28 part ceilings. Leaf yaw uses the renderer's degree convention.
- Close-detail cells are 12 cm instead of 24 cm, keeping the same bounded three-by-three neighbourhood. The existing overall living-world limits remain 420/150 parts. Full close detail remains capped at 150 parts; low close detail at 48. Smaller cells concentrate detail where the spider can see it, rather than increasing the far world's instance count without a bound.
- Both tiers reuse the uploaded grass-clump mesh and shared atlas: seven curved blades in one part, up to 36 nearby clumps at full detail (50,400 mesh triangles), nine at low (12,600). Low's primitive-blade trial was too sparse in native play, so the final fallback reduces clump count instead. Grass grows on actual verge soil and meadow grass, not metal lids or the structural litter roofs. Emerging grub patches use those same soft-ground checks.
- Wind rotates each close clump around its fixed ground pivot. Reduced Motion restores the unswayed frame. Structural litter looks are excluded from the decorative-leaf sway path, so they stay aligned with their colliders.
- This is visual ground cover plus revised population seeding. Grass parts have collision, query and touch disabled. All 98 shelter structures keep their existing colliders; player movement, camera, controls and capture/feeding rules retain their existing implementation.

## Verification status

Targeted CLI: verge litter 11,258 passed / 0 failed, including the existing 98 shelters and 388 litter colliders; living world 3,630/0; compact layout/save checks 294/0. The added checks cover ground support, rooted wind motion, Reduced Motion, hard-surface exclusion, cleanup, total renderer budgets and encounter coverage across a whole soil cell. Repeated per-object invariants contribute to these counts. A discovered hash correlation placed the original twenty background clumps in a narrow strip; a jittered 5 by 4 scatter now covers both axes, including the first four clumps retained at low detail. Coverage tests protect against that regression.

Strict analysis is clean and all 206 source files compile. The preserve regression passes 1,148/0 on final source, including the 1,500/500 full/low look limits; the earlier look regression passes 1,442/0. This is not a published build or proof that every habitat is rich enough.

## Final native V6 sample

An ordinary-camera 25 cm walk on actual soil was inspected at both detail tiers, without concurrent CLI benchmarks. The spider remained attached throughout. A rendered fly could be seen ahead on the approach in both tiers; this does not establish hunt enjoyment or encounter density across the whole map. The full tier used 36 nearby grass clumps and 246 living-detail parts; low used nine and 117. The regional background layer is additional and subject to the existing global look budget.

| Stage | Full frames | Full mean / worst ms | Low frames | Low mean / worst ms |
| --- | ---: | ---: | ---: | ---: |
| Standing, 5 seconds | 279 | 17.96 / 53.97 | 293 | 17.09 / 49.56 |
| Walking, 10 seconds | 557 | 17.95 / 49.84 | 589 | 16.98 / 59.18 |
| Arrived, 5 seconds | 301 | 16.67 / 24.38 | 287 | 17.47 / 265.76 |

Low detail is visibly sparser. Its arrival hitch remains unattributed, so these samples do not close the performance gate or establish phone performance. Normal-camera comparison images and filtered V6 output are included. The diagnostic driver and forced detail attribute were removed in stopped Studio, confirmed by `[CHET_GROUND_REVIEW_CLEAN]`.

## Nearby life

The ordinary 25 cm walk initially encountered no huntable insect within 25 cm. Native diagnostics confirmed five living prey, but their starts were 30 to 79 cm from the review's standing point. New soil populations now have six springtails and four houseflies at full detail, three of each at low detail. Start priority spans all three rows even at the low tier. Houseflies no longer start only in two opposite corners. The full/low limits are per active region, not per moving close-detail cell, and the existing activation/streaming radius is unchanged.

Perch IDs and positions stay stable. Saved directors retain their captured creatures/state; new directors use the revised initial population. No escape, capture, strike assistance or feeding code changed. The population amounts are authored encounter-density choices, not biological measurements.

`studio-ground-review.luau` samples the ordinary camera while standing, walking for ten seconds, and stopping. Its nearby-prey projection/raycast count is diagnostic evidence of candidates in view; it is not a substitute for looking at the actual rendered encounter. Keep the Studio-only `SilkPlayback` instance out of the playable build.
