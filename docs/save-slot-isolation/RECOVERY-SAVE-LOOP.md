Current private returning-session discovery/entry is documented in `RECOVERY-REJOIN.md`. Its latest combined cohort binds the updated private reader/runtime/entry/format/writer; this preceding save-loop evidence is historical. Production, startup/native/service and release qualification remain open.

# Private recovered progress and checkpoint scheduling

`RecoverySaveLoopPrototype`, installed as the server-owned `recovery.saveFactory`, takes over the private Runtime's `recovered` phase. The default healthy worker and the opt-in entry-only tests retain their earlier behavior. Production SaveService, SaveClient, remotes and menus still do not install this factory.

The single owner schedules cooperative checkpoint preparation, debounced global progress, the authenticated current-rest writer, idle metadata leases and departure. It never invokes the ordinary whole-snapshot worker and never releases the enforced baseline hold for ordinary writes. All public admission pins the actual selected mode, intent serial, credential and life; load/session/provider/key/scheduler/request changes fence the owner. Runtime revokes a writable intent when that owner is lost.

## Routine progress

`RecoveryRoutineProgressPrototype` reserves an immutable copy of the acknowledged baseline and submitted local progress. Its guarded UpdateAsync callback rechecks the current envelope/lock and performs the existing three-way merge against the actual stored primary. It renews only its own fresh lease, observes shared quota/backoff, then requires uncached exact body readback before advancing the acknowledged baseline. Only fresh same-owner lock metadata may differ during this proof. No archive, proposal or rest is written by this worker.

After readback, cooperative preparation merges edits made since the submitted local snapshot into the proven stored result. A final non-yielding, version-checked adoption updates the held baseline, local progress/time and scheduler together. New edits during preparation cause recapture rather than being discarded. If later edits still need storage they remain dirty. The hold remains enforced throughout; a metadata-only lease renewal does not advance its progress baseline.

The snapshot reservation also solves an ambiguous-write departure case. If the player chooses A, then B, then A again while B's write is in flight, comparing only to the original A baseline would mistake the second A for an unchanged stale value. `Reconcile.pending` first replays the reserved submitted write, then applies only changes made since its local snapshot. Closed departure uses that same two-stage merge whether B committed, failed before writing, or lost its acknowledgement. A failed/cancelled worker retains this small reservation until departure resolves it; it cannot reopen an ordinary write path. Departure completion clears it.

The routine progress job has a 16-request/180-second bound including its lease helper's requests. Runtime and all child writers share the existing rolling ten-request allowance. The progress scheduler retains its 30-second debounce. Provider calls retain busy scope across native yields; no yielded callback may mutate storage after closure. The helper's slow/ambiguous lease observation is bounded by the actual candidate beat and still requires a fresh owned probe/readback.

## Checkpoints and handoffs

`Runtime:saveRecovered(mode, intentSerial, credential, life, restSerial, record)` admits one pending checkpoint at a time. Preparation uses the actual existing current writer's capture and frozen single-use plan. The server receiver transfers ownership of its stable message graph until preparation finishes; it must not retain or mutate that graph. A RemoteEvent naturally transfers a separate graph, but the eventual service handler must honor this ownership contract.

A checkpoint waits until progress through its **captured scheduler version** is proven durable. It does not wait for every unrelated later notebook/eye-view update: otherwise a stream of valid progress messages could starve a checkpoint indefinitely. Later progress remains dirty. The current writer independently checks that the stored rare ledger covers the checkpoint's actual generation/visit before writing. The eventual client protocol must send its required progress before the checkpoint; the server never invents missing rare history from a client checkpoint.

Each active child owns heartbeat work exclusively. Returning to idle starts a fresh metadata lease helper, avoiding a stale helper expiry after a slow save. After exact rest readback and final ownership proof, the loop adopts the current raw rest, per-slot observed metadata/checkpoint cache and Runtime result. It retains the original archive/proposal references. The rest interval remains ten seconds. Invalid checkpoint preparation emits refusal without consuming a stored serial or revoking an otherwise valid life; storage/ownership uncertainty fences the owner.

Flush closes checkpoint intake and spends at most the first half of the existing shared deadline draining routine work. It reserves the remaining half for the closed final-progress/release/readback path. A queued checkpoint is therefore **best effort within the deadline**; if it cannot finish, the last verified checkpoint remains intact, and no stored receipt is invented. Final global progress uses the pending snapshot merge even after routine cancellation. An in-flight provider that exceeds the hard shutdown deadline cannot be falsely reported as preserved. No cross-key atomicity or unlimited shutdown durability is claimed.

## Evidence

`recovery-save-loop-verification.json` binds final `save-loop-attempt-3-*` and `save-loop-types-3-*`: **22,489 new assertions + 62,276 preceding checks = 84,765 passing assertions**, entry compilation/full strict of 32 private candidates. Counts include per-step quota, request, busy and permit invariants, not that many distinct gameplay scenarios.

Normal, Free and unlocked Easy compose actual discovery/archive/rebind, client checkpoint application, real intent grant, a Mating/Rare next-generation transition, required global progress, current-rest storage/cache adoption, 145 idle ticks, invalid candidate refusal, later setting storage and departure. Additional cases verify ongoing notebook updates cannot starve a rest, newer progress remains dirty, A-B-A changes across failed/lost acknowledgements and unresolved departure, same-tick reversal, a native-style yielded provider resumed during flush, and foreign-owner refusal/revocation.

Review reproduced a separate data-loss counterexample: a new unknown outer field inserted after the lease probe could be discarded by the routine progress callback. `save-loop-envelope-counterexample-*` records the expected failing assertion. The callback now rechecks known envelope/lock fields before computing its candidate and refuses the unknown data unchanged. Final attempt3 covers that refusal and the later captured-version scheduling change. Attempts1/2 and their strict receipts are historical. All preceding dependency cohorts pass again in the final run; older individual bundle-hash verifiers remain pinned to their older private dependencies.

These are in-memory backend/shim results, with no native Roblox transport, real DataStore, phone, FPS or heap qualification. Production sources/tests remain unchanged at `441eaca`; nothing was published.

## Next adoption work

Implement fresh-session discovery/entry of an already continued schema-3 rest without replaying the immutable initial import target. Complete explicit retirement/new-life handling, later-slot reuse of original A1, original archive/proposal lifetime and safe replacement of lost sessions with locally authored progress. Then wire the real SaveService factory/load/tick/leave/shutdown and remote protocol/rate limits, client paused-world selection/error handling and schema-3 readers. Verify actual server/client compression, storage interruption/takeover/rejoin, native frame costs and broad regression/release gates before main integration/publication/laptop synchronization. The overall optimization/reliability goal remains active.
