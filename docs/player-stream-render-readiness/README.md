# Player collision hold and render cadence

Current production source: `695e772d9d1ece490dd32132c655ac60c226c7b8` on `codex/save-continue`. Nothing published or merged to main.

The actual-client baseline at `257e1a4` proved that removing already-arrived collision lets the supported player fall and advances life/needs clocks. The first fix, `bf94f9d`, adds fresh collision checks at the current point and each fixed tick's projected destination. It retains pose, velocity and simulation objects until complete authored collision returns; optional decoration and ordinary off-map falls are not gates.

Native testing found a second defect in that first fix. The per-render check knew only the current point, so it cleared `playerLoading` between fixed ticks even when the projected destination remained absent. The native diagnostic measured exactly zero position, velocity, life or needs-clock change, but `loading=false`. This was a waiting-flag defect, not the airborne motion claimed by the original combined assertion's generic failure text. Both failed native attempts and their exact probes are retained under `../player-stream-readiness/`.

The current correction passes the same pending destination to the per-render readiness check. It does not change the motor, trajectory, input or camera. The test exercises twelve renders at one quarter of a fixed tick; it retains the previous hold/partial return/resume/repeat disappearance cases.

## Verified now

- Focused actual-client box-world suite: 43/0, including `PLAYER_STREAM_RENDER_WAIT`. The behavioral run started before a final comment-only source edit; immutable whole-suite gates qualify the committed source separately.
- Current source: 222 compiles, clean strict analysis, five test-runner regressions. See `checks.json`.
- Current source: 34 private recovery candidates compile/type-check clean. The executable recovery component bundle and all its explicit inputs are byte-identical to the earlier 187,257/0 execution at `257e1a4`; `private-unchanged.json` proves component evidence reuse. This is not a new whole-game recovery run.
- Actual Studio client, full detail: 60 passing checks, 223 checked script fingerprints (222 exact production scripts plus one private probe), saving disabled and unbound PlaceId 0. Covers scripted collision disappearance, partial return, complete return to the same objects, repeated disappearance, menus while waiting, projected airborne refusal and thirty stable follow-up frames. Also covers the prior HUD/controlled-animal presentation checks. See `native-full-receipt.json` and `native-full-output.txt`.

## Full gates in progress

Windows unified exec handle **95994**, immutable source snapshot; `windows-full-start.json` is the input manifest. Expected 76 suites / 468,866 checks / zero failures. Poll the existing handle; do not start another run.

Linux existing push run **39957397842**: <https://github.com/socranates/jumping-spider-sim/actions/runs/39957397842>. `fetch-ci.py` collects only this run and never dispatches a replacement.

Once both gates are terminal successful, run `verify-gates.py`, then `build-production.py`. The latter creates a separate diagnostic-free exact-source candidate; it does not publish. Preserve historical evidence and the unrelated three save-cost outputs and production sourcemap.

## Limits and next work

This fixture deliberately removes local collision folders; it does not simulate Roblox's real server/network streaming pressure. Its projected airborne velocity is artificial and checks pause semantics, not jump feel or the whole swept path. Low-detail/native natural traversal, real network reappearance, physical devices, sustained frame-time measurements and ordinary whole-life gameplay remain separate work. It does not qualify recovery menu/profile/model adoption, replacement epochs, online DataStore/rejoin or release. Actual recovery remains uninstalled in the production engine/menu. The broad optimization and correctness goal stays active.

Studio's tested model is unchanged. An editor copy was saved separately before closing Studio to free memory for the Windows gate. Do not load a diagnostic fixture into a published game.
