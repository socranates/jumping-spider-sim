# Close life and cover on the station garden lawn

The low-detail mound return view still read as an open flat lawn. LivingWorld already drew close curved grass on verge/meadow soft ground, but its selector omitted the garden's own lawn. This follow-up fills that specific gap at both tiers.

Hut now exposes its existing `surfaceAt` classifier, already used by the garden patches. LivingWorld reuses it and verifies the actual Grass-material `garden_*_soil` support. This matters because the base slab also extends below the drawn gravel paths and raised beds. Lawn cover does not grow on those surfaces or on a hard prop above the lawn.

Existing pooled/close limits remain **420/150 total parts** and **150/48 close static parts**. Some previously allocated grains/litter become grass; no player collider, camera rule, prey/feeding rule or save field changes. Wind bends the new clumps about planted roots. The same soft-ground sites can also host the existing occasional damp-weather grubs; no new food or capture target is introduced.

## Targeted checks

- Before selector repair: living world **3,976 pass / two fail**, both missing-lawn cases (one at each tier).
- After: living world **3,978 pass / zero fail**, compact map/save **294/0** over 232 regions. The new cases check actual lawn support/classification, exclusion of gravel/herbs/metal and unchanged part ceilings.
- Strict analysis clean; **207/207** source compile.
- Raw files: `lawn-cover-before.txt`, `lawn-cover-cli.txt`, `lawn-cover-types.txt`, `lawn-cover-compile.txt`.

## Native current-source comparison

Both tiers repeat the same ordinary-control mound route as `MOUND-TRAVEL-REVIEW.md`, using `studio-mound-travel-review.luau`. This is a Free play inspection with initial placement and the normal camera, not an unassisted survival run. No heavy CLI work overlaps it.

At the returned pose there are **eight close clumps at low detail**, still **136 living parts**; full has **32 clumps and 295 parts**. Grass availability changes along the route as actual support changes near the mound and herb-bed wall. Those values prove the new garden selector is running rather than a stale preview.

| Phase | Full mean/worst frame ms | Low mean/worst frame ms |
| --- | --- | --- |
| Approach | 16.72 / 31.11 | 16.66 / 19.70 |
| Previous endpoint, stopped | 16.67 / 20.45 | 16.67 / 18.69 |
| Beyond mound | 16.75 / 37.56 | 16.75 / 56.38 |
| Return | 19.48 / 64.23 | 16.70 / 50.93 |
| Returned, stopped | 19.96 / 44.63 | 16.62 / 21.20 |

Every phase remains attached/alive. Both stationary holds have zero body-hidden/off-screen frames. Moving step transitions briefly hide the body, with consecutive durations at most 0.191 seconds/full and 0.185/low. No sampled physical camera-to-body ray is blocked beyond its endpoint tolerance. The camera implementation is retained.

Raw telemetry: `mound-travel-native-after-lawn.txt` (`CHET_MOUND_LAWN_*` prefix; the last two numeric fields are close-grass count and living-part count). Comparison views: `mound-travel-low-before-lawn.jpg`, `mound-travel-low-after-lawn.jpg`, `mound-travel-full-return.jpg`, `mound-travel-full-after-lawn.jpg`. They show the real native client. These are local PC samples, not proof of a fixed frame rate on every device.

`[CHET_MOUND_LAWN_CLEAN]` confirms stopped Studio has no SilkPlayback and no SelfTest/Detail/TestTarget/Wasp overrides. Source file working-copy hashes during review: LivingWorld `270664CCF742DBBEEFFE2944BFC8B583CAE33B7754837D2A02EBBE708C65D7D5`; Hut `1A9F244857166B664C80104A26CE986D77FF7148F659B0BD6A11A020ACACEE80`. The committed snapshot identity is authoritative for the final CLI run.

The earlier 270/0/0 native integration on 80096ec predates this small presentation follow-up. Its movement/physics checks remain relevant, and the affected current-source cover/traversal cases above are reviewed separately. Final frozen CLI regression and live-place release/verification remain outstanding. No v48 publication claim.
