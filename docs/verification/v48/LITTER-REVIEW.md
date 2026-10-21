# Close ground habitats — development review

Unpublished work after compact-habitat commit `89523eb`. This is one step toward a dense, lived-in environment, not a completed release.

## Gameplay and appearance

- 98 small shelters across 49 existing infill regions. Fallen leaf and bark roofs provide real overhead occlusion and surfaces the spider can climb; a clear passage runs beneath each. Adjacent fallen stems provide low footholds where the soil fragment is wide enough.
- Existing approved milkweed-leaf and bark-chip meshes provide the silhouettes and fine detail. Seeded width, depth, curl height and colours vary; their physical support boxes fit inside the existing soil fragments. Structural detail remains visible in the low tier.
- Clover now uses actual subtracted soil fragments rather than the region's larger bounding rectangle. It no longer gets placed across an excluded path, bed or hazard simply because that area lies inside the same region bounds.
- The centre spawn corridor remains clear. No new regions, retreat checkpoints, progression changes, HUD indicators, larger jump ranges or altered movement constants are introduced.
- The per-region rendering allowance is at most 46 records at full detail and 24 at low. The global look budgets remain 1,500/500. Collision supports remain present in both tiers; their rendering substitutes are explicitly registered so there are no duplicate visible boxes under the meshes.

## Verification

The dedicated `verge_litter.luau` suite checks every new piece for non-overlap, actual ground beneath it and low-detail visibility; tests stable motor positions on and beneath every roof; walks into both narrow and broad shelters; checks real overhead ray occlusion; keeps region spawns clear; and instantiates each region's springtails and houseflies at their full target populations. Clover silhouettes must fit over real soil.

Final targeted checks: litter **4,875/0**, compact layout/save migration **294/0**, living world **1,799/0**, preserve **1,148/0**. See [litter-regression.txt](litter-regression.txt). The shelters add **388 collision pieces**. Strict analysis has no diagnostics and all **204 source modules compile**; see [litter-types.txt](litter-types.txt) and [litter-compile.txt](litter-compile.txt).

Native checks use the archived [Studio-only driver](studio-litter-review.luau), with saving off and explicit source-synchronization assertions. The first primitive-roof prototype could be entered through normal movement input and remained attached underneath. Its full-detail under-roof sample was 31.89 ms mean while a separate CLI process was active; do not use that confounded sample as a final benchmark. The superseded low-detail primitive-roof approach measured 16.67 ms mean and a 2.49 ms mean script render step. Neither prototype proves final mesh appearance or performance.

The final varied mesh source was checked at full detail without a concurrent CLI workload. The spider walked from outside through the shelter's open end and remained attached at ground level. The approach sample had 299 frames, 16.78 ms mean and 28.78 ms worst. Under the roof: 232 frames, 21.67 ms mean and 68.19 ms worst. The later profiled segment caught a 356.8 ms worst rival update, so this is **not a passing final performance gate**. See [litter-native.txt](litter-native.txt) and [the native under-roof view](litter-final-under-full.jpg). Final mesh appearance at the low tier still needs native review; its structural visibility and budgets are covered by the CLI checks.

Studio is stopped. The temporary `Client/SilkPlayback` module and review attributes were removed at 2026-10-21T16:46:38Z. The `Detail` override was also removed, restoring the normal device-selected tier. Recheck these before any publication.

In particular, the presence of a roof and passing collision tests do not alone establish that ordinary travel encounters enough life or that the overall habitat is rich enough.

## Rival performance follow-up

The full-detail profile attributes its largest single-frame cost to the rival, while the under-roof camera averages 2.21 ms. Lazy route construction is a candidate: `RivalDrive.crossTo` calls `g:allSeams`, and `RivalRoute.buildSeams` can build neighbouring face graphs synchronously. `Drive.new` also asks for waypoints synchronously. Do not assume the roof renderer or camera caused the whole hitch.

[station-route-benchmark.luau](station-route-benchmark.luau) gives a repeatable fresh-process construction workload and fingerprints the faces, standing samples, edges, cross-region seams and waypoints of all 51 station graphs. The current baseline is [station-routes-baseline.txt](station-routes-baseline.txt): approximately 2.04 seconds aggregate CLI construction cost; the first requested graph and its dependencies take 277.8 ms. These are CLI CPU timings, not native frame times.

The next performance change should distribute expensive graph preparation without changing the rival's station territory, patrol/stalk rules, geometry or routes. Never expose a half-built graph: the current builders set `built` and `seamsBuilt` before construction ends, so simply inserting yields would be unsafe. Use explicit readiness and private construction state, preserve useful ongoing movement while future crossings prepare, compare the graph fingerprints, and test interrupted preparation/duplicate requests before a native recheck. No route behavior or construction change is included in this habitat commit.

## Remaining scope

This does not finish the living-world goal. Continue close visual work on the can opening/silhouette, dog locomotion and grounding, indoor fleas and dust, ant/grub encounters, weather and wind, and ordinary travel through the compact habitats. Keep final native and complete frozen-source regression gates, publication and synchronization pending until evidenced.
