# Actual client adoption notes from source 257e1a4

These are inspected call sites and constraints for the next implementation, not completed recovery integration. The current full platform runs must finish before another production change. A separate player streaming-readiness reproduction is prepared in `../player-stream-readiness/`; if it confirms the warning-only fall path, prioritize that player-facing defect before more migration work.

## Preserve the real restore path

`SpiderClient.client.luau` owns `checkpointWorld`, the mode stores and the active `checkpoints` local. `returnToCheckpoint(record, preparedCommit)` applies the normal checkpoint and rebinds session mode/rules, growth/reach/speed, creature rule state, controls, focus, strands, world replication focus, camera and notebook watcher. A detached `Checkpoint` world-table commit does not perform these steps. Use this function rather than duplicating its side effects in a new recovery controller.

`saveState.restore` already prepares a new local store and `Checkpoint.prepare` under `SaveRestore`, then commits through `returnToCheckpoint` and swaps `stores[mode]`/`checkpoints`. Its normal completion closes the screens immediately. Recovery instead needs a prepared/applied phase followed by an acknowledged, matching server-grant phase. Only the latter can resume gameplay; neither sending a receipt nor the local restore callback is permission.

`SaveRestore.update` clears its job before invoking the prepared commit. `returnToCheckpoint` cancels the normal restore and calls `saveState.invalidateRest`, which increments `worldGeneration`. An adoption guard must permit this one intentional generation transition after the atomic commit while still rejecting genuinely newer user/world choices. Do not simply reuse a pre-apply generation equality check after applying, or ignore generation changes altogether. Test cancellation during preparation and reentrant choices at adoption boundaries.

The file is already near Luau's top-level local limit. Keep related state on `saveState` or an extracted module rather than adding many new top-level locals. Compilation is a required gate.

## Pause independently of menu visibility

`modal()` gates physics, the life clock, needs and many render/input paths. It currently knows ordinary panels and startup waiting, not a recovery waiting-for-grant state. Add an explicit pending-recovery pause; a menu becoming hidden, Resume, notebook/settings changes or a cancellation route must not accidentally release the simulation while entry is incomplete.

`openMenu` currently shows CancelRestore only for the normal/local restore schedulers. The CancelRestore handler assumes one of those owns it. `closeScreens`, `fresh`, `saveState.beginLocalReturn`, failure handling and end/new-generation transitions also cancel those schedulers. Integrate recovery cancellation in all relevant entry/exit paths, with exact request/epoch/global-choice fences and a bounded timeout. Keep local last rests usable when network saving fails. A failed preparation must keep the current spider; a failure after adoption needs explicit retained/paused/error behavior rather than claiming the old world was never changed.

Keep preparation/copy/encoding work under the existing bounded `SaveWork`/`SaveRestore` scheduling. The new protected selection avoids two unused legacy graph copies; do not reintroduce them in menu glue.

## Validate the right record for the right purpose

The current game validates offers against `SaveRest.check(mode, record, checkpointWorld)` for restoration. A protected legacy offer is consent evidence, not a current world to restore. Any separate legacy-offer validation must remain bounded, mode-correct and capability-gated; it must never relax validation of a normal unprotected checkpoint or allow raw legacy application. The server must still freshly validate the exact chosen source before migration. The current recovered entry requires full current-world validation and an idempotent application/receipt cache.

The private recovery cohort overlays `recorded-map-candidate.luau` and `recorded-checkpoint-candidate.luau` for read-only old-world inspection. Production Checkpoint does not expose `inspectRecorded`. Its ordinary current-world check/prepare path is unchanged by that overlay. Do not mistake private old-world inspection qualification for its installation in the game. If promoted, retain ordinary validation behavior, source-context isolation and its full regression proof.

## Profiles and ownership are server choices

`RecoveryServiceOwnerPrototype.new` is currently scoped to one preconfigured mode per visit. The game has three displayed slots. Actual installation needs trusted mode-specific template/context selection, including Easy eligibility, discovery/selection fences and safe replacement. Do not accept a destination world template or arbitrary context from a remote client, substitute a main template for another mode, or construct a second independently writing session beside the owner.

Runtime creates its pipeline with its initial profile; merely changing `owner.mode` or `runtime.recovery.context` is insufficient. A switch must cancel/drain outstanding readers/work, preserve progress/lease ownership, bind the new immutable selection and keep the single-session/epoch rules. After accepted recovery or retirement, current private routes deliberately hold rather than silently resuming unsafe normal writes. Explicit fresh-life service/client epoch handoff remains open.

## Geometry and scenes need real-client evidence

`WorldClient.refocus` only schedules replication focus for the next frame. `regionReady` checks the actual collision pieces. Recovery cannot infer collision readiness from restored coordinates or a focus reset, especially for a returning checkpoint outside the station. Keep the player paused while the current target's collision is absent and test disappearance/rearrival, not just first arrival.

The ordinary mating renderer restarts a stored pair scene through `mateLegs.coupleFrame`; the fixed-tick mating path opens the restored hatching card when the recorded stage is hatched. Preserve those established behaviors rather than inventing a second scene system. Actual recovery must test rest, mating and hatching entries through those real paths, with no duplicate brood/progress, and only after the entry grant permits simulation.

The prepared normal-client Studio fixture uses the actual client and 223 fingerprints with persistence disabled. It covers normal/offline HUD and controlled animation regression only. It does not cover the new recovery callbacks, natural progression, real remotes, online data, physical controls, performance or publication.
