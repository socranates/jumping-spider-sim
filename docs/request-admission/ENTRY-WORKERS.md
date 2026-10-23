# Typed entry and read-lease workers

The subsequent [archive candidate](ARCHIVE-WORKERS.md) adds collection/publication/controller admission and bounded history cleanup in `worker-v3.luau`. The entry milestone below remains bound to its preserved v2 inputs; normal activation remains closed.

This extends [the discovery candidate](WORKERS.md) with explicit replacements for the actual schema3 entry worker and read-phase lease worker. All three can use the same physical-account gate and retained-operation bridge. The ordinary game and earlier Runtime factory remain unchanged. Archive/commit/save/New/departure paths, server-owned lane installation and the cooperative driver remain open. This is private CLI/memory verification, not native/online activation or a loading-speed claim.

## Entry

`entry.luau` preserves the original entry state machine, structural/provenance checks, exact client-applied acknowledgement and final rest/progress witnesses. A trusted `entryOptions.admission={gate,scope}` supplies the optional typed path. The worker creates its bridge only after validating the live entry scope. It retains one read across unavailable allowance, increments requests at provider dispatch and preserves the existing backend-failure/backoff path.

Cold entry still performs eight uncached reads before offering application and two final reads after the exact application receipt. A client receipt alone never grants a credential. Cancellation, expiry, route/provider/session changes or a closed gate end the operation and retain the enforcing hold. A changed final rest refuses entry; it is not overwritten. Successful completion clears the bridge before the coordinator notifies the actual intent decision.

## Read-phase lease

`lease.luau` accepts an optional fourth `admission` argument. Probe reads consume a read unit; renewals consume both read and write units. Original lock validation, exact acknowledgement comparison, lease expiry and ambiguous-write reprobe/backoff remain intact. Lease updates keep the same callback and its expected-result record across capacity waits. The callback resets rejection/expectation evidence on each provider invocation, including retries, and is still wrapped by the original held-baseline permission and backend fences.

The lease is a long-lived maintenance job; its cumulative request ceiling is the gate's bounded identity range, rather than an artificial short transaction cap. Rolling actor/server caps, current allowance, per-request lifetimes and actual lease expiry still constrain every start. A typed busy lease can be cancelled: the bridge revokes callback/result authority and the provider drains. A renewal already committed before cancellation remains committed and charged. A replacement scope cannot open over its pending provider. The old no-option cancellation behavior remains unchanged.

## Qualification and evidence boundary

`run-entry.py` mounts both replacements over the full preceding discovery/application cohort and uses `worker-v2.luau` for all three typed workers. It reuses the real Entry test fixture, actual Runtime coordinator, production session/baseline/intent objects and actual client application receipt path. The tests deliberately stop the old read lease at a quiescent `entry_required` boundary, import the scheduler's existing debt once, and install a shared lane for entry and its replacement lease. No other provider runs concurrently in that isolated test phase. This does not install account lanes in the actual service or demonstrate that the unconverted workers are typed.

The eight new case groups cover:

- Main, Free and Easy: zero-capacity waits, exact application and final storage verification, one real credential, unchanged archives/rest/progress and matching start counts.
- Cancellation, entry deadline, route change and closed visit while a read is queued.
- Stable renewal callback/expected-result evidence across repeated capacity waits.
- A committed renewal with a lost acknowledgement, backoff and fresh probe.
- Cancellation during an actually suspended committed renewal, provider drain and replacement exclusion.
- Lease expiry, changed route and closed visit before a pending provider starts.
- An80-second client application delay: lease renewal continues while entry stays read-only; final validation accepts an exact lease-only progress change.
- A final rest changed after application while capacity is unavailable: the fresh read refuses a credential and retains the changed stored value.

The final cohort passes **212214 checks /58 named groups /0**:211864 preceding,341 entry/lease and9 dispatch-guard checks. All44 candidates compile and the complete production overlay is strict-clean. Exact source hashes are in `entry-verification.json`. `verify-entry.py` reconstructs the current bundle, compares every preceding result with the qualified211864-check cohort, binds the eight new entry groups plus two dispatch-guard groups and all44 mounted candidates, verifies committed production bytes and records the remaining installation gaps. Use `entry-qualified-2` and `entry-types-qualified-2-*` for current qualification. Earlier runtime/type logs are historical: development has only six entry cases and inherited generic reader-only metadata; qualified-1 adds the other two cases but precedes the dispatch guard fix.

## Scheduler callback cancellation fix

Review found that the existing StartupBudget overrides `scheduler.begin` and may invoke its budget observer inside bookkeeping. The preceding bridge assumed bookkeeping had no external callbacks. A cancellation there could still start storage. Both `dispatch-before-fix-*` (controlled wrapper) and `startup-dispatch-before-fix-*` (the actual StartupBudget module) retain exact failing bundles against `worker.luau`.

`worker-v2.luau` checks lifetime and route identity again after `scheduler.begin` and immediately before provider counters/call. The current full cohort includes nine controlled-dispatch checks, including a genuinely suspended bookkeeping callback. A separate exact-module StartupBudget fixture adds four checks and confirms the real wrapper was exercised. Passing counterparts are bound by `verify-entry.py`. If bookkeeping already recorded a start before cancellation, the gate and scheduler retain conservative debt; no provider attempt/result is counted and no write occurs. This is an admitted dispatch ending during bookkeeping, distinct from a capacity-denied poll, which still spends no counters or debt.

## Next

Convert the actual archive/commit/pipeline and save/New/departure workers, including their raw-update adapters, to retained typed operations. Then bind one service-owned gate across all physical actors, constructors and replacement epochs. Prevent untyped providers from bypassing its accounting. The current Runtime's normal `startReadLease` still passes no lane; its later save factory also remains unconverted. Do not enable just these three workers in a live Runtime.

The next archive change has nested accounting: Controller currently reserves/counts before a child `wantsRead`, Collector increments `reads` before its raw call, and ArchiveStore increments `requests` and switches to `running` before its provider call. Waiting must retain the child operation without spending either counter or leaving a job stuck in `running`. Move both child and parent accounting to the same admitted dispatch. Keep CPU-only snapshot/comparison steps runnable while capacity is full. Repository updates also need stable transforms and acknowledgement evidence across polls, as the lease now does.

The raw-write route must retain its existing selected-key and held-baseline checks. Introduce an explicit trusted operation adapter for `updateRaw` rather than replacing `session.backend` to trick the generic bridge: that would invalidate the very route identities being protected. Pipeline totals already derive from global session starts, so avoid double charging them when children begin requests. Qualify those nested boundaries and total caps before attempting service installation.

Retire the old startup admission lane explicitly when switching to a service-owned typed lane. Its wrapper retains complete history through the original scheduler `begin`, so import that history conservatively, but do not leave two admission policies making independent decisions. The new callback fence protects cancellation during existing wrappers; it is not permission to keep competing schedulers installed. New integrations must use `worker-v2.luau`, not the earlier bridge preserved for its counterexamples.

Preserve all original archives, fresh witnesses, lease/source/currentness/transform guards, request caps, backoff and stored acknowledgements. After the complete actual-service cohort and bounded cooperative driver are qualified, repeat real-clock native attribution and isolated real-store leave/rejoin, then the remaining gameplay/device/input/audio/sustained-performance and release gates.
