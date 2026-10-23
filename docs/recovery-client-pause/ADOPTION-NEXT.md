# Next actual-client adoption work

Inspected against production `a97b0b54bfa7a49d8cec072cc4c0ebc1fd7ea8ff`. This is an implementation contract, not installed recovery behavior.

## Existing consumers

- `SpiderClient` owns `checkpointWorld`, local slot stores and the active `checkpoints`. Its `saveState.restore.cfg.prepare(record, stamp)` builds/validates a private local store and prepares the checkpoint, then returns the real adoption closure. That closure calls `returnToCheckpoint` before replacing `stores[stamp.mode]` and `checkpoints`.
- The actual closure intentionally increments `saveState.worldGeneration` once via `invalidateRest`, rebinds rules/controls/reach/speed, clears transient creatures/displays, resets replication focus/camera and resynchronizes the watcher. Raw `Checkpoint.prepare` against an exposed world table omits these effects.
- The normal scheduler's `completed` closes screens. Recovery must not use that completion callback as permission to resume. Its new `pauseRecovery` handle remains independent of menu visibility. Saving/transport frame processing stays live while the simulation is paused.
- `SaveClient` already negotiates the additional recovery capability, binds the active slot/request/epoch/global serial, validates entry identity and builds a bounded applied receipt. `sendRecoveryApplied` may trigger a reentrant final decision: cache the adopted identity/receipt before sending it.
- `RecoveryEntryClientPrototype` currently validates scene/life/slot and prepares a direct world-table commit. It must gain an explicit actual-adoption preparation callback or equivalent adapter before engine use. Keep its scene/record checks; do not replace them with trust in the callback.

## Required state and transitions

Hold one current job, one independently owned pause, selected request identity, server epoch, entry identity/revision, pre-apply generation and one cached applied receipt. These are bounded scalar identities plus a privately owned prepared record/closure, not additional full world copies.

1. Selecting a protected Continue acquires the pause before dispatch or any reentrant response. Capture the real choice/request/epoch, and cancel obsolete cooperative work without releasing a replacement hold.
2. Prepare under SaveWork; require the same choice, request, epoch, slot and pre-apply world generation on every publication boundary. Menus may change visibility without authorizing entry. Main/free/easy profiles are trusted server choices; Easy eligibility remains enforced.
3. Before commit check all identities plus `handle.held()`. Invoke the actual adoption closure exactly once outside an active cooperative Work pulse. It may increment generation by one and replace the selected store. Accept only that observed transition; a newer choice/generation must not be disguised as the expected increment.
4. Cache the exact resulting receipt and adopted state before sending. Duplicate same-identity entry packets resend the cached receipt without reapplying, rerolling or replacing the local store again. Different/reordered entry identities cannot reuse it.
5. Only the matching current writable server decision may call the current handle's single-use release. A local commit, successful send, server receipt intake, ordinary screen close, unrelated writable decision or stale handle is insufficient.
6. Before adoption, preparation failure/cancellation keeps the existing spider and store unchanged. After adoption, report that the adopted world remains held; do not claim rollback to the old world. Define a safe explicit exit/retry path before installing this feature.
7. Fresh life, other-slot choice, end/new-generation transitions, local Back/Continue, error/demotion, timeout and service/client replacement must cancel/drain the appropriate jobs and fence late callbacks. Mere mutation of owner.mode/context or silent session replacement is unsafe.

## Minimum next regression matrix

Use actual SpiderClient hooks and the real SaveClient/SaveService transport, not only detached world tables. Cover main/free/easy and rest/mating/hatching; cooperative cancellation before/after yield; entry resend; receipt-send reentrant grant; delayed old decision after a new choice; the intentional generation+1; an additional unexpected generation change; hidden/resumed/settings/notebook screens while held; target collision absent/partial/complete/repeatedly absent; local returns with broken network saving; failed commit and failed/timeout grant; explicit safe session replacement. Old/current saves and original archive bytes remain preserved.

Measure actual entry payload bytes and retransmission totals using the real encoded packet. Existing `MAX_REST_CHARS=5000000` bounds validation, not a qualified RemoteEvent bandwidth/latency budget. A five-second resend interval alone does not establish acceptable network cost. Keep a server-owned profile coordinator and explicit session/transport replacement as separate required work before activation.

Source-bound70-check native proof establishes the owned pause and actual ordinary adoption only. It does not close this matrix. No engine owner/client recovery callbacks are installed; no live data or published game changed.
