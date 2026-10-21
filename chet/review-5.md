# Chet review 5 - v47 creatures, milkweed and controls

2026-10-21. This is a Roblox Studio review, with diagnostic fixtures clearly separated from encounters. Nathan approved green chelicerae and said he is satisfied with the existing mechanics.

## Build identity

Claude's creature v46, `7c36d975ee7b14d175de89c40d95fd2090620ddb` (evidence `7611085ba292923c`), and Chet's controls v46, `6ba1a3809503ec7814d21781daa239123f0dacb3`, were combined as **v47** at `6283a598fa1fcd3f3a286f4278763640811fa6d0` (evidence `eb473b6da5edf1dc`). Two follow-up commits fix four stale Focus-label expectations in three test suites: `f2afbb1`, then **`1447d6b74c9aa6b6b4725ad3bdaa6e30d972fd24`**. Final test evidence **`97cdf8a2827b4734`**.

The playable place is byte-for-byte unchanged by those test-only corrections: its Git blob is `a04e240347249bfff0aa8f118d01350b51a6f597` at all three revisions. BuildInfo and the generated test place changed; game source did not. The release includes v44's quieter HUD, v45's milkweed and v46's creatures, plus Nathan's controls. Those earlier builds are not separate releases.

## Controls

- **L1/LB held creeps.** Press also takes/releases the existing contextual nearby contact lock. No candidate means creep only. Release preserves the existing toggle lock; next press or Cancel releases it. Existing contact/memory loss still ends it. Locked movement faces/circles at stalking pace.
- **L2/LT held runs**, also Shift and a new touch Run button: twice ground walking speed. Creep/lock overrides Run. Gentle stick or Ctrl creeps. Growth/cold modifiers and automatic silk edge-walk pace remain.
- **R2/RT Focus** immediately; right mouse/touch Focus remain. Slow motion stays on T. L3 eats/rests, R3 recentres. No jump, silk-reeling, stamina or save-schema changes.

Native probe in Studio: walking **2.531 studs/s**, Run **4.960**, ratio **1.960**; creep **0.658**, Run+creep **0.643**. These are short render-frame samples, not exact fixed-step ratios. L1 with empty contact memory reported held creep=true and no lock=true. The native self-test also passed L1 acquire/release and existing facing/strafe checks. Controller hardware and phone feel remain Nathan's playtest.

## Visual findings

Screenshots are in `docs/verification/v47/images/`. Milkweed is actual streamed game scenery; creature close-ups use the game's actual drawers in a temporary Studio-only fixture, elevated above the garden. They establish engine rendering, not natural encounter pacing or live-client appearance. The fixture was removed before publication.

| Subject | Finding | Follow-up |
| --- | --- | --- |
| Player | Green highlights over nearly black chelicerae read well. Principal lenses stay dark, with strong white reflections; no milky covering seen in this view. Pale front-leg hairs are visible. | Keep the green. Dark amber behind the lenses is not separately distinguishable in this lighting; no lens-number change made. |
| Rival | Tan/orange face, white swollen palps, dark long front legs and raised spread make it distinct. Real low tier counted **211 parts**. | Eyes look substantially paler/blue-grey than the player's full-tier eyes. Review reflectance/low-tier eye treatment before changing anatomy. Abdomen chevrons at ordinary play distance still need a grounded encounter view. |
| Male mate | Larger green jaws and heavier/longer front legs are visible. Actual living low tier **270 parts**. | Front close-up clips the leg tips; not a side-by-side proof of abdomen proportions. |
| House fly | Transparent wings and dark vein lines are visible at close range. | Grooming timing and the brief pre-takeoff tell still need a continuous normal-camera playtest. Static images cannot settle whether the rub feels too fast. |
| Hoverfly | Wings appear as translucent grey discs. | Do not call a static screenshot proof that all fast-wing motion is flicker-free. Check mosquito/midge/damselfly and moth at dusk in the live client. |
| Cricket | Raised forewings render clearly. | Fixture close-up is cropped; song/hush response at normal distance remains a playtest. |
| Strider | Thin long middle legs and contact dimples draw, with changed oar positions between sampled views. | Needs the actual pond and continuous rowing observation for a final movement judgement. |
| Robin | Upright orange-breasted stance reads well; head turns between samples. | Normal forage/watch transitions remain a live encounter check. |
| Frog | Pink tongue renders at full diagnostic reach; throat/flanks render. | Full natural strike alignment and breathing cadence still need continuous pond observation. No attack timing/outcome changed. |

The rival's retreat is **presentation only**. Keep the tan species for this release. Real avoidance by smaller rivals is a separate design/AI change and was not added. Do not infer male-male biology proves the game's ritual with the female player; Claude already documents that adaptation.

## Milkweed and HUD

The live garden sample found **16** milkweed SpecialMeshes. Nearest: `Workspace.WorldDecor.garden_c3.Full.Leaf_2`, mesh `128470594939908`, size `(9.1, 0.9, 19.52)`, centre `(41.4, -52.2, -266)`, quarter-turn about Y, mesh scale `(1.3000, 0.423529, 1.001026)`. White part tint lets the green atlas show; the mesh has collision/query off as expected. Raised midrib/veins are visible and the leaf lies along the stem's horizontal tier. No obvious duplicate-surface flicker in the sampled views, but continuous/moving-camera coverage is incomplete.

**Art issue for Claude:** large rectangular green walk surfaces remain visible around/behind the organic leaves. The imported leaf does not yet replace that boxy silhouette visually. Before adding the coneflower, identify which rendered walk boxes should be hidden/re-skinned while preserving their collision geometry, coordinates and IDs. Chet did not edit World source or the colliders.

The quiet HUD does fade back strongly. Hunger stays legible, but the faded day/moult line is faint over bright scenery. The first-session help card still appears and clears; compare this with Nathan's normal saved session before changing the quiet-HUD design. No HUD readability fix made in this review.

## Performance

- Native self-test, full sill: **31.4 ms mean / 32 fps**, worst **140.0 ms** over 160 frames. Render-step mean **10.86 ms**; spider rig **4.49 ms**. Census **5,247 parts**, player **707**.
- Same route without far preserve: **42.1 ms / 24 fps**, worst **297 ms**. Without shadows: **25.1 ms / 40 fps**, worst **247.5 ms**. The non-monotonic samples are too short and noisy to claim a causal improvement.
- Focused actual milkweed garden view: **296 frames / 5 s**, **16.952 ms / 58.99 fps**, worst **30.93 ms**.

Studio viewport approximately 1096 x 473; a separate frozen CLI run was also using CPU. These are local Studio observations, not phone results, a comparable v45 benchmark, or a published-client performance claim. The sill result is lower than Claude's cited 45-49 fps; repeat in a clean live session before blaming the creature pass. Avoid adding more parts until that comparison is done.

## Verification

Native foreground route: **245 passed, 0 failed, 0 skipped**, **526 s**, including all streamed regions, L1 lock/strafe, rival/mate arrival, robin, frog, pond and save-related checks. `windows-studio.txt` contains the run beginning 13:21:11Z and ending 13:29:57Z. The intro test now restarts its own timer rather than assuming the existing intro is under two seconds old.

All **196 source modules compile**, and Luau-lsp exits **0** with no source diagnostics (definitions info and unsupported watcher registration notice only). Targeted controls checks were **1,340 passed**. Three corrected suites: SUMMARY **196/0**, EYES **231/0**, NOTEBOOK **1,499/0**. Their earlier four failures were assertions expecting L2/LT Focus; actual captions already correctly said R2/RT. Generic functions tested with an explicitly supplied LT string remain valid and were left alone.

Final CLI evidence combines **45 unchanged suites** from the full frozen `6283a59` run with **3 corrected-suite reruns**: **48 suites, 352,162 passed, 0 failed**. The original complete process exited 1 for the four obsolete label assertions; its raw report is retained, not relabeled as green. `cli-summary.json` names the provenance of every suite. Runtime source and playable bytes are unchanged by the three test-file corrections. The CLI preserve route itself also completed **245/245** (514 simulated seconds). Older partial CLI runs and the two v46 native 244/245 reports are not green release evidence.

## Priorities for the next handoff

1. Check the published build on Nathan's controller/phone: L2 Run, L1 held creep + contact lock, R2 Focus, and no stuck Run after menus/focus loss.
2. Review the milkweed silhouette and low-tier eye reflectance, then capture an ordinary rival encounter with all display phases. Keep outcomes unchanged.
3. Measure a clean live sill/garden/pond frame sample; only then continue the next mesh, one at a time. The remaining five approved mesh IDs are in `docs/MESHES.md`.
4. Cat, wasp and crab-spider art can follow; avoid fly, feeding, settings and menu edits without coordination. Preserve stable habitat IDs and saves.

## Final receipt

**Published v47 as Roblox place version 61**, existing place **120119801868085**, universe **10771103250**. Studio confirmed success at **2026-10-21T13:50:19Z**. Creator Dashboard's **Show published only** lists 61 first with its check mark; its 8:42 AM timestamp is the prior saved-version time, not the 8:50 AM publication time. Screenshot: `docs/verification/v47/images/published-version-61.png`.

Source commit **1447d6b74c9aa6b6b4725ad3bdaa6e30d972fd24**, test evidence **97cdf8a2827b4734**. Source is pushed to `claude/new-session-lqh973` and `codex/v47-creatures-controls`. PR #31 remains the existing review against main. No main merge, force push, OneDrive write or World-source edit.

Temporary driver and review fixtures were removed; SelfTest was nil; native guards confirmed correct place/universe and streaming enabled before Publish. Rojo was stopped. Generated playable also contains 196 scripts, RivalDisplay, and no SilkPlayback. Playable SHA-256: `cd2e31a8729cfdb53eff2a06828a31696588c26139442f91500601771372f787`.

A live launch was attempted after publication. The browser first offered Download Roblox. Launching the existing Player triggered its automatic updater; it finished and opened the signed-in Player home screen. Retrying Play from the in-app browser still left Player at home, so no game session was verified. No manual installer controls were used. This does **not** weaken the publication receipt, but the screenshots above remain Studio evidence. A transient Windows paging-file error occurred when starting a separate shell near the end; the existing test process still finished normally with the four known assertion failures, and its corrected suite reruns are retained.
