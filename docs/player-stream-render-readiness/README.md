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

## Full gates verified

Windows unified exec handle **95994** is terminal exit 0; Linux push run **39957397842** is terminal success. Each passed **76 suites / 468,866 checks / zero failures**. `full-verification.json` binds immutable Windows snapshot inputs, both output logs, compile/strict/runner evidence and the bounded native fixture. Both outputs include the new twelve-quarter-tick regression. Do not repeat these completed gates without a new source change or unresolved failure.

Linux run: <https://github.com/socranates/jumping-spider-sim/actions/runs/39957397842>.

`verify-gates.py` passed and `build-production.py` created `C:/Users/natha/claude-xfer/Windowsill-production-695e772/TheWindowsill-production-candidate.rbxlx`: 222 exact production scripts, no injected diagnostic, SHA256 `5fa12d465ace029007cd3585f7a545f1685a3266fef5e29c711e9001d1305ae1`. It is not published or verified as a normal online production-client session. Preserve historical evidence and the unrelated three save-cost outputs and production sourcemap.

An additional engine-streaming experiment is prepared separately (`engine-full-default-prepared.json`). It moves through the production WorldFocus remote from Atomic garden_b4 to distant deck_n4 and back, without reparenting collision. Default engine retention is recorded as not observed rather than falsely passing stream-out coverage. Its results are separate from the completed 60-check controlled fixture and do not affect the already-qualified source snapshot.

## Limits and next work

This fixture deliberately removes local collision folders; it does not simulate Roblox's real server/network streaming pressure. Its projected airborne velocity is artificial and checks pause semantics, not jump feel or the whole swept path. Low-detail/native natural traversal, real network reappearance, physical devices, sustained frame-time measurements and ordinary whole-life gameplay remain separate work. It does not qualify recovery menu/profile/model adoption, replacement epochs, online DataStore/rejoin or release. Actual recovery remains uninstalled in the production engine/menu. The broad optimization and correctness goal stays active.

Studio's tested model is unchanged. An editor copy was saved separately before closing Studio to free memory for the Windows gate. Do not load a diagnostic fixture into a published game.
