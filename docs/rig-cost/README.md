# Isolated spider rig experiment

Status: **offline checks and one native pose/timing trial passed. Timing gains are modest and mixed; cache not promoted.** No production source changed, no gameplay build was published, and no performance gain is claimed.

The desktop matrix measured the `spider rig` callback at approximately 2.29-3.72 ms mean on full detail. That identifies a useful investigation target, not the cost of each internal operation. The existing production rig already batches part movement.

## What this experiment changes

`build.py` reads frozen source `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5` from Git into a new local archive. It does not overwrite game source. The local-only place contains the original shared modules, two extra rig copies and one standalone client driver. It loads no game controller, server/save service or online data API.

- `RigMeasured` adds timing probes for setup, pose, fixed body parts, body hairs, legs and engine batch movement. It also measures segment/body-hair calculations and raycasts inside the inclusive leg slice. Do not add inclusive and nested timings together. Compare its total CPU cost against the uninstrumented original to expose probe overhead.
- `RigCached` changes only the leg-hair transform: its local orientation is cached when the hair is created. Per-frame scale/position calculations, part count, anatomy, update thresholds and batch calls remain. This removes repeated construction of the same orientation with `CFrame.lookAt`; a mathematically equivalent expression can still differ at native floating-point precision, hence the native check.
- The driver alternates update order for original/cached/instrumented rigs in each rendered frame, with the same seeded living state and input. It compares the original/cached parts and records raw CPU timings. There are three visible rigs on a flat floor, without the preserve or game simulation: **these are isolated update timings, not rendered-game FPS.**

The source guard checks 176 exact script fingerprints before Play and verifies that no server/ReplicatedFirst payload is present. Production release preflight refuses the place. Never publish it.

## Offline evidence

`offline-receipt.json` and the seven `offline-*.txt` logs retain the actual v1c test process results:

| Check | Passed | Scope |
|---|---:|---|
| Differential original vs cached | 1,478,428 | 14 appearance/tier cases, 2,800 pose frames |
| Existing look suite | 1,442 | Anatomy, parts, appearance and pose checks |
| Existing idle suite | 5,719 | Living motion and idle behavior |
| Existing growth suite | 571 | Growth and visual scale wiring |
| Existing feeding suite | 88 | Existing feeding/survival checks with prototype rig |
| Existing rival client suite | 9 | Existing rival integration |
| Existing Inspect suite | 37 | Existing inspection behavior |

All seven processes exited zero. The differential test covers all seven appearances at full/low detail, floor/wall/ceiling poses, walking, growth stages and scale changes, condition, focus, grooming/alarm, hanging and feeding poses. It compares every drawn part and planted-foot anchors against the unmodified rig. Worst position and size errors were zero under the CLI shim; worst axis-component-vector error was approximately 1.59e-15. These are double-precision shim results, not native Roblox precision or visual review.

The build was then changed to use immutable archived Git input instead of the current worktree. `bundle-equivalence.json` proves all seven resulting v1d bundles are byte-identical to the tested v1c bundles while the worktree remained unchanged. The v1c and v1d place XMLs are also byte-identical. The separate guard now counts authored roots instead of the entire DataModel. Initial failed builder attempts are not native evidence. `compile-process.json` records the final three-source `-O0` compile and exact hashes. Run `python docs/rig-cost/verify.py` to verify the retained offline receipts; it deliberately leaves native and performance gates false.

## Run the native experiment

```text
python docs/rig-cost/build.py --rojo ABS_ROJO_EXE --out NEW_ABSOLUTE_DIRECTORY
python docs/rig-cost/offline.py --profile THAT_DIRECTORY --luau ABS_LUAU_EXE --out ANOTHER_NEW_DIRECTORY
```

The corrected place is `C:\Users\natha\claude-xfer\Windowsill-rig-cost-v1e\Windowsill-rig-experiment.rbxlx`, SHA-256 `572910b03a7afd768a92974ed425e0f1bb8a5c6cb53dbbbc84f21b69314d12a0`. **v1d is superseded:** its native guard correctly refused duplicate Rig folders before Play. v1e uses one Shared tree and rejects duplicate instance paths. All 176 script hashes are identical between packages; the frozen archive remains unchanged. `manifest-v1d.json` retains the old sources/builder, preserved as build-v1d.py; `manifest-v1e.json` records corrected packaging. Open only this diagnostic place, execute its sibling `guard.luau` in Edit mode, verify `[CHET_RIG_GUARD]` and 176 scripts in the correct new log, then Play. Keep focus and viewport steady. Require all 16 cases, `[CHET_RIG_DONE]`, no `[CHET_RIG_FAIL]` or CreatorErrors, and reconstruct/check all chunk checksums before interpreting timings. Do not change the frozen v6 desktop matrix driver.

Historical UI attempt before native validation: Studio selection/capture failed: after selecting its returned window, the helper captured Codex instead. Fresh selection and one retry returned the same mismatch. No native experiment started; no further UI input followed. `ui-attempt.json` records the boundary without retaining the unrelated app screenshot.

## Next gate

Native trial `1792662958290` now validates all 16 cases, raw chunk checksums, pose tolerances, focus and viewport. See `RESULTS-v1e-trial1.md`, `native-v1e-events.txt` and decoded `native-v1e.json`; `native.py` reconstructs the result. The older offline verifier deliberately keeps its own native flags false; it does not overwrite this separate native receipt. The player full-detail walking update improved by only about 0.10 ms in this trial and one male case was slower. Repeated isolated timings are required before treating the cache as an optimization. If useful, promote a small reviewed change, run the complete production tests/types/compile, then repeat matched whole-game trials and visual checks. Keep movement, camera, silk, lighting and dense habitat intact. The separate foundation audit still needs the 30-minute memory session, mobile/emulator and other outstanding correctness work.
