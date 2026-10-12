# Slice acceptance record - Windows, 2026-10-11

Game source main 48b84a0; evidence **db112e2fa006**. Full Windows fixed-60
suite: **585 passed, 0 failed**, in `windows-baseline.txt`. This report
separates regression coverage from physical-device and human playtests.
The frozen spec is unchanged; S01-C is its accepted checkpoint replacement.

| Gate | Status | Evidence and remaining scope |
|---|---|---|
| M01 | PASSED | `test_m01_route.gd`: twenty floor/wall/convex/underside runs, in full baseline. |
| M02 | PASSED | `test_m02_jumps.gd`: legal/invalid jump fixtures and landing error bounds, in baseline. |
| M03 | PASSED | `test_m03_tether.gd`: catch/reel/blockage and energy checks, in baseline. |
| M04 | NOT RUN (complete gate) | Camera regression suite passes; rendered source and export checks cover both views. Exhaustive aiming at every required jump at graphical 30/60/144 is not established by headless fixed-FPS tests. |
| P01 | PASSED | `test_p01_perception.gd`: occlusion, inspection and observation fixtures, baseline. |
| A01 | PASSED | `test_a01_fly_evidence.gd`: sensed evidence, transition trace, one capture; baseline. |
| L01 | PASSED | `test_l01_feeding.gd` plus checkpoint integration: interrupted feeding/ownership/energy; baseline. |
| S01 | NOT RUN (superseded) | Arbitrary-state exact resume was replaced by retreat checkpoints, A-001 / review 1 Q3. Do not call the original criterion passed. |
| S01-C | PASSED | `test_s01c_checkpoint.gd`: whole-world restoration, repeated loads and discarded in-progress states; baseline. |
| S02 | PASSED (tested failure model) | `test_s02_checkpoint_store.gd`: corrupt/truncated/newer-schema preservation and backup. Partial-write simulation is not an OS power-loss test. |
| U01 | NOT RUN (complete gate) | Remapping, assist, mute and persistence logic pass baseline. Physical controller-only full-loop play is still untested. |
| W01 | PASSED | `test_windowsill.gd` warning/collision/pause fixtures; native rendered shadow and captions observed; browser pause menu exercised. |
| F01 | PASSED (reporting clause) | Five-minute native rendered route, both views, quarter-speed, two strikes. **16.7 ms budget FAILED**; measured misses and reduction plan in `PERFORMANCE.md`. |
| E01 | NOT RUN | No five-person, ten-minute study. Nathan/son feedback is useful, not four-of-five evidence. |
| E02 | NOT RUN | No recorded player explanation of hunt cause/effect and looking-around observation. Friend questionnaire is in `docs/FRIEND_PLAYTEST.md`. |

These statuses permit a labelled friends playtest, not a claim that all
slice/release acceptance gates are closed. Whole-life play, production art,
a finished notebook and itch.io publication remain future work (RELEASE-01).
