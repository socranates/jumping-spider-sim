# Private session-progress rebind and readonly destination handoff

Storage verification alone leaves the live session holding its old progress snapshot. Replaying that complete snapshot can revert settings that the recovery transaction correctly preserved in P. This helper synchronizes the session after coordinated recovery using a tracked acknowledged baseline and a three-way choice merge. It does not enter the world, change rest authority or make migration playable.

## Acknowledged baseline

Install `RecoveryProgressBaselinePrototype` as the session's backend before loading it. The sidecar delegates the existing read/update/raw interfaces without extra requests or transformations. For P updates it observes only an exact positively acknowledged table result from the final callback. Failed/ambiguous writes and discarded callback candidates do not advance its baseline. Issued operation serials prevent a delayed older acknowledgement from replacing a newer one. Bounds apply before copying/freezing the acknowledged value.

Before recovery, hold that known baseline for this exact session/load/backend. Recovery's P writes and heartbeats continue normally and are observed separately, while the pre-recovery baseline stays unchanged. This is tracking, not a lock: the integration owner must pause ordinary session work during the transaction and retain that ownership on failure until it can safely recover or close. A held baseline must never be fabricated by copying whatever stale progress happens to remain in memory. Existing sessions without tracked acknowledgement history cannot silently retrofit one.

## Merge and atomic local adoption

Capture the exact original readonly Continue through the existing session fence, current progress reference/time, scheduler progress version and issued backend-operation serial. The caller supplies isolated fresh raw P and R observations after the coordinated storage result. These reads must be budgeted/fenced by the future integration owner; the pure helper makes no backend calls and is not a substitute for that orchestration.

Preparation verifies the pending packet, selected original checksum/time/life/kind, exact encoded R target, known P envelope/lock protocol, fresh owned P observation and semantic coverage of the pending global proposal. It normalizes the held baseline and current supported local progress without dropping fields. Monotonic notebook/rare/flag data merge losslessly under the existing capacity checks.

For appearance/settings, only values differing from the held acknowledged baseline are treated as locally authored choices. Unchanged stale fields do not replay over P. A newer stored choice wins over an older local choice; a genuinely changed local choice wins equal timestamps. This differs from blindly replaying the entire session snapshot, and from replaying the fixed import proposal with incoming-wins ties. A direct counterexample in the test shows the ordinary whole-snapshot merge reverting a newer stored setting when an unrelated local notebook event shares its clock tick; the three-way result preserves it.

Prepared plans remain private and can be consumed once. Application runs outside SaveWork and rechecks the session/load/intent, local progress reference/time/version, backend operation sequence and observation age. Official local progress updates replace the session progress through setProgress; integration must retain that API/stable-input contract during preparation. A change during or after preparation refuses without adopting a partial result or releasing the held baseline. A fresh explicit preparation can then include the later input.

On success, non-yielding assignments adopt the merged progress, its timestamp and the observed stored timestamp. Unpersisted local additions stay dirty; a fully covered unchanged snapshot acknowledges only the captured scheduler version. The sidecar adopts the verified stored P baseline and consumes its hold. No callback occurs halfway through the assignments. There is no remote write in application.

The returned checkpoint/entry-kind/life descriptor is a **readonly handoff** with requiresSchema3Entry=true and gameplayAuthorized=false. Existing protected rest state, selected observation and life credentials are not unlocked or replaced. Ordinary P resumption is exercised after successful adoption; ordinary rest entry/writing still requires the future schema-3/credential integration. On failure, callers must not simply resume old queued progress writes.

## Evidence and limits

1,373 focused assertions pass alongside the preceding 7,506 regressions (8,879 total); full strict analysis is clean with twenty-one private candidates. The fixture installs the sidecar before actual SaveSession.load, discovers a pending target through the real offer reader, selects its protected Continue, completes the actual post-archive coordinator, then supplies fresh raw observations to the rebind helper.

Tests cover held-baseline preservation through recovery writes; stale-snapshot counterexample; remote settings plus local notebook additions; same-tick authored settings/appearance; no extra adoption writes or rest credentials; successful subsequent ordinary P saving without reversion; covered-dirty acknowledgement; single-use plans; late local inputs and explicit recapture; foreign/expired/unknown/unabsorbed P; different target bytes; intervening P operations; lost acknowledgements; and reordered acknowledgements. Cooperative preparation rejects an input arriving while it is suspended, leaving that input and the baseline hold intact. An initial optional-payload strict error was retained and corrected with a nil guard.

This uses actual session/backend logic over MemoryBackend and the existing reversible codec fixture. It does not prove native latency, heap/FPS, real DataStore freshness/durability or a full production rejoin. Fresh read observations and local fences cannot make multi-key state atomic, and this helper deliberately grants no gameplay authority based on them.

## Remaining integration

The production session factory must install baseline tracking before load, and a single owner must coordinate discovery/archive/commit/rebind with total request/deadline limits, heartbeat priority, departure handling and guarded fresh observations. Complete schema-3 readers/writers and pending-proposal retention, protected-observation rebasing, durable life/intent credentials, and rest/mating/hatching/ended-life entry before opening gameplay. Native compression/callback/heap/frame testing, real-service interruption/takeover/rejoin, adopted full gates and release remain open. No production source or real saves changed; nothing was published.

The pure three-way merge now lives in `recovery-progress-reconcile-prototype.luau` for reuse by future lifecycle handling. Provider exception tests verify both ordinary and raw writes release their active-update count and do not advance the acknowledged baseline on error. The extraction does not connect migration to production.
