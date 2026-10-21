# The Windowsill — living habitat v48 candidate

## Resume here

Work from GitHub branch [`codex/v48-living-habitat`](https://github.com/socranates/jumping-spider-sim/tree/codex/v48-living-habitat), production source **1ba2eb3a2b296e72d3cb753e68740b6d62ea8e89**. This is an unpublished candidate, not a release receipt. The active game is `roblox_port`; Godot is frozen. Main and Claude's branch have not been changed.

For a cloud Claude session, clone that GitHub branch. Local `C:` links alone cannot transfer the project. The exact portable Roblox source archive is `C:\Users\natha\claude-xfer\v48-full-1ba2eb3.zip`, SHA256 `18FC46895BE6AF5D58FB3AC14D1B6F360861FF78F673C17A7F23C772A56E7E77`. It contains `roblox_port/`; the branch contains all review documents and raw evidence as well.

**Use the source, not an older generated place file in the checkout/archive.** Tracked generated places have not been replaced. A separate release copy was rebuilt at `C:\Users\natha\claude-xfer\v48-release-1ba2eb3\roblox_port`, evidence **06be0270d414ffc2**; all 207 playable XML script sources match the frozen archive byte-for-byte after line-ending normalization. See `docs/verification/v48/release-build-1ba2eb3.json`. Rebuild with `python tools/build.py <rojo>` in a separate copy when needed; retain the regression snapshot unchanged. The existing cloud editor receives reviewed source through Rojo.

A bounded portable candidate package is ready at `C:\Users\natha\claude-xfer\Windowsill-v48-06be0270d414ffc2-candidate.zip` (**16,378,079 bytes**, 596 entries, SHA256 **4ccc0ef4ae47c6919cc69dd616f5b72b0499425bd7ae857b93c7228e30786719**). It contains rebuilt playable/test places, source, assets, tests, tools, this handoff and v48 evidence through review commit 0841dfe. Its README explicitly labels it unpublished and awaiting final CLI acceptance. `candidate-package.json` records that immutable identity. The current branch may contain later receipt-only updates.

Nathan asked for a rich, lived-in tiny-spider world: dust bunnies, fleas, soda cans, ant hills, occasional emerging grubs, an outdoor dog, realistic moving sun, wind and weather. He also wants dense small habitats rather than empty distances, secure ground off the stone path and nearby insect life. Do not replace this with a decorative checklist: inspect the normal camera and ordinary connected travel.

## What changed

- Compact connected outdoor layout with physical off-path support, stable habitat IDs and migration for earlier saves. Garden, verge, meadow and pond are close enough to discover rather than long empty traversals.
- Pooled close litter: dust and joined fibres inside, floor fleas with continuous articulated hops and retained identity across region seams; cans have a real aperture, rims and climbable shells.
- Authored leaf/bark shelters; close curved grass with planted-root wind bending, clover and living prey along the verges. Garden lawn now uses Hut's existing surface classification, excluding gravel, herb beds and hard props. Part ceilings stay unchanged.
- Outdoor colony: supported mound, foragers that leave, search, carry crumbs home and shelter during heavy rain/night. Damp-ground grubs emerge only occasionally; they are ambient animals, not new meal credits.
- Dog with articulated planted paws and existing outdoor circuit; rain behavior finishes its route at a sniff stop near the station.
- Deterministic gradual weather fronts, cloud/rain/wetness, directional wind and astronomical solar direction. Rain discovers newly streamed roofs while the player stands still. Structural shelter does not sway with decorative leaves.
- Station-wide resident rival/wasp routing; a mate-drive visibility repair; growth and HUD changes requested by Nathan.

See `docs/LIVING-HABITAT-v48-WIP.md` for the implementation history and `docs/verification/v48/HABITAT-ACCEPTANCE.md` for the scope-to-evidence map. Later dated results supersede earlier live-job notes. Never infer current process state from an old document.

## Preserve Nathan's decisions

- Movement, camera and longer jumps are liked. Do not redesign them to accommodate scenery.
- First moult needs seven whole-fly equivalents; the second needs ten more. Partial feeding cannot award whole meals repeatedly. Run becomes available after the first; lock-on after the second. No advance unlock spoilers; explain the control only when earned.
- L1 held creeps and, once unlocked, its press can acquire/toggle a nearby visible prey lock. Locked movement faces and strafes around the contact. L2 runs; R2 Focus. Manual early aiming, no automatic target assistance before the unlock.
- Persistent gameplay HUD: only a steady, unlabelled 120-by-4 hunger bar. No hunger word, numbers, crosshair, target markers, routine messages or extra meters. Earned unlock notices, deliberately opened interfaces and usable touch controls are the agreed exceptions. Roblox system controls are separate.
- Discovery remains intentional. Do not add explanatory environmental overlays.
- Keep green player chelicerae and the existing creature presentation. A rival's drawn backing-off pose does not authorize a new avoidance rule.
- Announce before editing fly, feeding, settings or menu code; do not silently overwrite parallel Claude work.

## Verification so far

- Immutable older baseline `7236420`: **55/55 CLI suites pass**. Its wrapper session 38032 is terminal. Complete raw results are archived in `FROZEN-7236420-RESULT.md`; this baseline predates rain/wind/streaming/lawn follow-ups.
- Native Studio 0.744 on `80096ec`: **270 pass / zero fail / zero skip**, including every region's streaming/support/attachment checks and scripted continuous connections. This run is terminal. `NATIVE-80096ec-RESULT.md` retains scope, raw results and frame measurements.
- Current lawn source: living-world **3,978/0**, compact map/save **294/0**, strict analysis clean, **207/207** compile. Native full/low continuous mound crossings stay attached, with 32/8 close clumps at returned poses and unchanged ceilings. See `LAWN-COVER-REVIEW.md`.
- HUD: **32/0**. The current narrow check was rerun after source freeze.
- Final-source native functional gate in the **existing cloud place**: **270/0/0**, terminal at 2026-10-21T21:01:23.786Z. See `NATIVE-FINAL-1ba2eb3.md` and raw output. Its timings overlap the CLI and do not qualify as uncontended performance evidence.
- Broader normal-camera full/low station/garden/path-shoulder walks: **8,049 sampled frames, zero detached**, both DONE markers, all settled holds clear. Fleas and occasional grubs are recorded on the routes; see `HABITAT-JOURNEY-REVIEW.md` for exact scope, images and limits. Camera/movement unchanged.
- Final immutable `1ba2eb3` full CLI was started in exec session **70770**. Results: `C:\Users\natha\claude-xfer\v48-results-1ba2eb3`; console: `C:\Users\natha\claude-xfer\v48-console-1ba2eb3.txt`. It is not yet a green final gate. Observe that exact handle or actual process state; a quiet suite or observation timeout is not completion and does not justify restarting it.
- Full sill native sample averages 19.4 ms, with unattributed whole-frame spikes. Mound route averages vary around 16.6–20 ms; neither establishes constant 60 fps or phone performance. Do not measure native performance while the CPU-heavy CLI is running.

## Remaining acceptance and release

1. Finish the exact-source CLI run and archive all 55 outputs plus its terminal status. Fix findings before release; do not substitute the older passing run for current evidence.
2. Normal-camera station/garden/shoulder journeys and final native integration are complete with the limits above. Use those results alongside the dedicated dog, colony, weather and continuity reviews; do not describe controlled inspection as an unassisted playthrough.
3. Both native jobs are stopped and clean. Cloud cleanup `[CHET_FINAL_1BA2EB3_NATIVE_CLEAN]` at 21:02:14Z; local journey cleanup `[CHET_HABITAT_JOURNEY_CLEAN]` at 21:09:49Z. Neither place has SilkPlayback or SelfTest/Detail/TestTarget/Wasp overrides. Recheck before publishing after any further inspection.
4. Open the **existing cloud place** `120119801868085`, universe `10771103250`, verify both identities, synchronize the exact reviewed source and publish only after gates pass. The local review file has PlaceId/GameId **0** and is never a publication destination. Never Publish As or create another experience. Read live state/history before overwriting.
5. Confirm the actual new published version in Creator Dashboard, record source and evidence identity, then deliver the portable source/handoff. A freshly loaded Dashboard with **Show published only** confirms **61** as the latest published version. The latest saved draft was **134**; no v48 publication is claimed.

## Existing-place preparation, 2026-10-21T20:49Z

The cloud editor is open in Studio window **4131012**, distinct from local review window **36441252**. Read-only assertions confirm PlaceId `120119801868085`, GameId `10771103250` and saved draft version 134. That draft had `SelfTest=true`, no SilkPlayback, and all 207 script fingerprints matched older source `0ca748a`. Its only script differences from current `1ba2eb3` were Hut, LivingWorld and SelfTest. The earlier Dashboard view showing only 61 was stale for saved versions, but 61 remains the latest *published* version after a fresh published-only filter.

The existing-place editor then connected to Rojo **34872**, accepted the source sync, cleared `SelfTest`, `Detail`, `TestTarget` and `Wasp`, and asserted no SilkPlayback. Post-sync fingerprints match all **207/207** current scripts with no extras. Fingerprints use DJB2 modulo 2^32 after CRLF normalization: useful change detection, not a cryptographic proof. JSON manifests are in `docs/verification/v48/cloud-draft-134-comparison.json` and `cloud-sync-1ba2eb3.json`.

`[CHET_V48_CLOUD_SYNC_CLEAN]` at **2026-10-21T20:49:02.622Z** confirms target identities and count in Studio log `0.744.0.7441077_20261021T204424Z_Studio_B411D_last.log`. The later final native run is complete and clean as recorded above. The existing cloud editor is now **disconnected from Rojo**; its UI confirms "Disconnected from session". It remains stopped on the correct existing place, ready for final pre-publish assertions after CLI acceptance. No publication has occurred. Recheck actual debug state after any subsequent native test.

## Local working rules

Writable clone: `C:\Users\natha\windowsill-publish`. Push only remote `github` (`https://github.com/socranates/jumping-spider-sim.git`). Remote `origin` points to a read-only OneDrive clone; never push it. The OneDrive project and mirrored `sources/` are read-only. Do not merge main or change Claude's branch. No subagents requested.

Rojo is serving the writable clone on localhost **34872**. The local review editor remains connected; the cloud editor is deliberately disconnected after source sync/native acceptance. The post-sync manifest verifies its script changes; it does not prove publication. Keep cloud and local identities distinct.

Regression wrapper: `C:\Users\natha\claude-xfer\v48_frozen_regression.py`; it runs the snapshot's own 55 declared suites unchanged and writes per-suite raw output/progress/summary. The Python runtime is under `C:\Users\natha\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`; Luau tools are in this ChatGPT project's `roblox_tools/` directory. Preserve raw failed or interrupted evidence rather than rewriting it as a pass.
