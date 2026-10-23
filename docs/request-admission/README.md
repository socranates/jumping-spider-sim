# Typed request admission candidate

Private implementation following the native delay attribution in `../recovery-native-cost/RESULTS.md`. **Not installed in production, the owner state machines, or the earlier native fixture.** It replaces neither storage verification nor lease/transaction authority. No end-to-end recovery speedup is claimed.

Current `qualified-2`: **30 named cases /4851 checks /0**:4769 policy checks and82 checks around the exact production DataStoreBackend from `bd67582`, with injected providers/options. Both candidate modules compile and are strict-clean in the standalone Luau analyzer. The production224-module/default Windows/Linux receipts remain unchanged. This qualification is CLI/synthetic, not native or online proof.

## Ownership and limits

Create one Admission gate for the participating server, with trusted `now()` and `available()` callbacks. `available()` returns current read/write allowances; it must not change platform rate settings. Limits are explicit constructor inputs: separate per-physical-actor and shared server read/write rolling caps. Examples in tests use30/10 per actor and60/30 per server, plus one spare platform unit. Those values are **candidate test configuration**, not an adopted production policy or a guarantee against platform throttling. UpdateAsync consumes both units; the typed facade chooses that classification itself.

`open(physicalActor, epoch)` returns an opaque frozen visit token. Only one visit per physical actor may be open. Closing it cancels queued/reserved tickets, retains spent rolling debt and leaves any started provider charged until it drains. A replacement visit cannot open while that provider is in flight. The gate serializes starts for the same physical actor. Empty expired actor records may be evicted; active/recent actors cannot be forgotten to bypass debt.

Request tokens are opaque and frozen. Cancelled, expired, forged or previously started handles cannot start a provider. Reserving does not spend a request; dispatch rechecks the live scope, current allowance and rolling caps. Reservations expire after a bounded lifetime and cannot be resurrected. Queued requests also have a finite total lifetime. Fairness prioritizes earlier eligible conflicting requests whose owners are polling; a stalled owner loses that priority after the reservation interval, so an abandoned poller cannot block a live owner for the entire ticket lifetime.

Allowance callbacks may fail, yield or reenter. Version and lifetime fences reject a stale lookup, and a second fence protects the final clock check. In-flight calls are conservatively subtracted from observed headroom; their rolling charge is never refunded on failure or cancellation. Backend failures and unknown clock/budget state remain distinct from successful admission. A clock rollback refuses starts without clearing history.

No timers or background tasks are created. Capacity, reservations, ticket lifetimes, identity space and actor retention are bounded. Callers must poll and explicitly cancel/close as their own state machines change. Actual performance at configured maximum sizes is still unmeasured.

## Typed backend facade

`Facade.new(gate, visit, backend)` captures `readFresh`, `readRawFresh` and `update`. `begin(method, key, transform?)` captures an operation and chooses its read/update cost. `step(handle)` returns `waiting` without calling the provider or pretending it failed when admission is unavailable. One operation handle is retained across polls. Concurrent/reentrant polls cannot start it twice.

On an update, the facade checks cancellation/scope before and after every transform callback, including provider retries. It composes with the existing backend's callback-error handling and its original save/lease/source fences; it does not replace them. Late results from cancelled operations or closed visits are withheld. An already committed write cannot be rolled back by dropping its acknowledgement: the ambiguous-ACK case retains the write, retains debt, drains the old provider, and exposes no successful result for the closed visit.

**`done` means the backend returned, not that saving succeeded.** Its packed result preserves the backend's boolean/value/error tuple. Callers must still verify writes, require stored acknowledgements and handle backend failure. No UI may display Saved merely because admission succeeded. The gate controls request starts only; preserve per-key intervals, byte/storage limits and backoff.

## Verification and counterexample

`run.py <new-prefix>` binds exact candidate/test/backend bytes, bundle/output hashes, compile and strict logs. Existing prefixes are never overwritten. `verify.py` reconstructs current and preserved historical bundles, checks the backend against its committed source and validates the retained failure and passing counterpart.

The final clock reentrancy case failed against the earlier candidate: an allowance lookup completed, then a reentrant clock callback consumed headroom through another actor before the original operation started. The old candidate admitted that stale operation. `clock-before-fix-*` retains its exact bundle and failure; the only runtime change between that candidate and current admission is the final version fence. Current tests exercise the same scenario successfully. `qualified-1-*` and `development-1-*` remain historical; their changed inputs are retained with hashes matching the original receipts.

Coverage includes zero/changing allowances, read/write separation, rolling boundary times, cross-epoch debt, pending capacity, expiry, fairness, abandoned pollers, same-actor serialization, provider yields, cancellation/closure during lookups and transforms, reentrant clock/budget callbacks, ambiguous writes, backend errors and bounded actor cleanup. An independent rolling-window oracle checks interleaved physical actors over600 ticks. Production fresh-read option cleanup is checked at the adapter boundary.

The mixed-workload example admits24 reads and6 updates at its synthetic initial time under the candidate configuration, while a10-start aggregate rolling cap waits120 simulated seconds for those same30 starts. Both perform the same operation count; this is **admission-only synthetic arithmetic**, not measured game loading or a native performance comparison.

## Required integration work

1. Keep the gate on the server service across epochs, keyed by the original physical account key. Use a closed/drained owner transition before a new visit token. Import any preexisting untyped debt conservatively; do not reset it when switching profiles or factories.
2. Convert actual recovery/entry/discovery/New workers to retain a typed operation while waiting. Increment provider request caps/counters and the relevant scheduler bookkeeping only at the admitted provider boundary, rather than on every denied poll. Preserve their original source/currentness fences and backoff semantics.
3. Qualify shared headroom, allowance failures, constructor/removal/shutdown, multiple actors, lost replies and session replacements through the actual service. The conservative aggregate scheduler must remain the fallback until this route is explicitly installed; do not simply raise REQUESTS_PER_MINUTE.
4. Install a cooperative driver independently of I/O admission. Then repeat the complete private application cohort, strict overlay, real-clock native attribution and isolated real-store leave/rejoin before normal engine activation or release.

Roblox's current [limits documentation](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) distinguishes per-type server and shared experience limits and recommends querying remaining allowance. The candidate does not call SetRateLimitForRequestType, access a real store or establish that server allowance also protects experience/per-key throughput. Existing provider checks and failure handling remain necessary.
