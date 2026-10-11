# Live spider legs — Chet, 2026-10-10 (America/Chicago)

Nathan approved option 1: integrate the leg prototype into the real spider and keep the twitch he enjoys. Work started from `b8716b4`, then resumed after Claude's T09d controller remapping/presets and his playtest note merged. The integration was rebased onto `eacec52` without conflicts. Finish on `main`, and update Nathan's laptop as required by `SHARED_WORKFLOW.md`.

## What the player gets

- Eight animated legs replace the eight static legs; there is only one rig. Walking and stalking cycle with movement speed, preparation spreads the stance, flight/hanging folds the legs, and stopping restores the neutral stance.
- The rig is a child of the existing body model. Snap turns, walking lurches, idle flicks, struggle jolts and catch recoil are preserved. There is no smoothing added to the twitch layer.
- Reduced motion uses neutral legs and disables twitch/recoil. Enabling it during an active recoil now clears that recoil on the next physics tick.
- Original live leg material is preserved. Both Windows and Web exports include the rig; the standalone preview remains excluded.

## Implementation and regression coverage

`spider_body.gd` reads the motor's supported/preparing state and velocity after the motor update. It removes the support-normal velocity and converts world travel into the model's local frame. It advances `spider_legs.gd` once per physics tick. No input, RNG, collisions, forces, senses, camera or saved gameplay state are added to the rig.

Native visual inspection exposed a pre-existing prototype geometry bug: scaling a tilted cylinder along world Y left rods crossing at the knee. Segment length now scales its local Y basis column. A regression checks actual mesh endpoints at hip, knee and foot in five poses.

Five new live-world tests cover walk/stalk/stop, wall/underside movement and unchanged motor traces, preparation/flight/landing, runtime Reduced motion including active recoil, and checkpoint reconstruction. The existing three prototype tests remain. The joint geometry regression is the sixth added test overall.

## Verification

Final combined evidence: **cfdc7fac7ce0** (source `b62a1278`, settings `8b6707d4`, tests `2c47e7aa`). Engine Godot 4.7.2, Windows, Jolt. Reports in `docs/verification/live-legs/`.

- Full combined suite at accelerated fixed 60 fps: **536/536**, zero failures/skips (`windows-full60.txt`).
- `snapshot.bat` read back every file successfully for **cfdc7fac7ce0**; archive is local under `tests/reports/snapshots/2026-10-11_cfdc7fac7ce0.zip` (UTC date in filename). Console is frozen as `snapshot.txt`.
- Normal-speed combined checks: **28/28**, including all leg tests, supported locomotion/F4 and T09d controller/preset tests (`windows-normal-targeted.txt`). The full 536-test suite was not repeated at normal speed.
- Windows and Web release exports succeeded with the live rig included (`exports.txt`); final export log has no engine errors/warnings. The sandbox's initial safe-save/temp-file errors were resolved by rerunning the exporter outside the sandbox with a dedicated writable temporary directory. The final Windows package started headless for 180 frames, exit 0, with no engine errors (`windows-package-smoke.txt`). This is a startup check, not a complete packaged-game or browser playtest.

- Original `b8716b4` baseline: `run_tests.bat` on native Windows, headless at normal speed, **522/522**, evidence **27b60f6974e8**. F4 `test_support_view_toggles_with_f4_and_draws_the_normal` passes. Frozen report and console: `windows-baseline-normal.txt`, `windows-baseline-console.txt`.
- `update.bat` ran successfully in Nathan's laptop folder at session start. During the pause Nathan/Claude updated that folder to T09d. A subsequent `snapshot.bat` therefore captured **3fb300501a68**, not the earlier 522-test baseline; it verified every archived file. Do not relabel those as the same state.
- Native AMD Radeon Compatibility screenshots: `idle.png`, `walk.png`, `stalk.png`, `prepare.png`, `reduced-motion.png`. They show the corrected rig in the real windowsill; they are stills, not a human gait/performance approval. Reproduce with Godot `--path . --script res://docs/verification/live-legs/capture.gd` (graphical renderer required).
- Tests and visual runs used isolated application-data folders. Player saves/settings were not used.

## Remaining limits / next owner

This is the approved cosmetic alternating four-leg prototype, not individual surface-contact IK. Feet are not planted in world space, turning in place does not step, and pose transitions are immediate. Expect some cosmetic sliding or surface overlap near edges and during body twitch. Gameplay and collision remain authoritative. Nathan should judge the feel while walking, creeping, aiming, jumping and catching a fly.

T09d is retained. Global slow time, a separate survival-pressure setting, a Windows interrupted-write test and human U01/W01/E02/M04/F01 checks remain open. No new biological or sustained frame-rate claim is made. Web browser storage, pointer lock, controller play and a full hunt still need the prior platform playtest.
