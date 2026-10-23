# Private ordinary Session admission

This candidate replaces ordinary SaveSession I/O behind its existing load, step and flush APIs. It extends the [held cohort](HELD-WORKERS.md). It is not installed in production or the account service. Runtime can receive one explicit lane before its first request; Profile, Replacement and service ownership still require integration and qualification.

## Requests and authority

`ordinary-session.luau` routes the five former direct update sites and three current-rest read callers through `ordinary-io.luau`. A retained Operation owns each exact method, key, transform and scope. Actual dispatch charges the shared gate, Session counter and bounded context counter before calling the captured backend. Capacity waiting consumes no provider attempt, failure, backoff or stored acknowledgement. Legacy no-lane APIs remain supported and now also count reads before dispatch.

The bridge checks account/epoch, load serial, backend, scheduler, counter and configuration identity at request boundaries and update callbacks. It refuses the former startup wrappers both at attachment and before dispatch. It retains the selected scheduler item/version while waiting; a newer local choice remains dirty after an older write completes. Per-key debounce, rest spacing, retry/backoff, schema/backup refusal, life/revision/credential fences and exact stored acknowledgements remain in the original Session operations.

Initial lock acquisition now timestamps each actual callback and resets expected evidence on replay. A successful response must acknowledge a fresh owned lock, and local scheduling uses that acknowledged beat. An expired result or a rest load that outlives ownership cannot grant active play. Current-rest operations refuse expired local progress ownership before dispatch and after provider return. Loss of ownership demotes the Session without inventing a provider failure.

## Cooperative execution

The private driver starts an owned coroutine only when work is due. A polled step resumes only the bridge's own opaque admission suspension. It never resumes a suspended provider, native request, observer or engine timer. Synchronous load/flush use the configured cooperative sleep and wait for external engine resumption. A pending provider retains busy ownership until it drains; another actor may still use an independent eligible resource through the same Gate.

Each driver context has a 180-second deadline and at most64 physical starts; every retained operation permits one start. Flush is bounded by the existing flush deadline and first cancels admission-only work or drains already-started provider work. Completed contexts are collected. A reentrant close during notification may run flush on the same owned stack; reentrant closure inside a provider revokes authority instead of starting overlapping I/O. These are private CLI proofs, not native scheduling certification.

Production uses integer `os.time`. Several25ms waits may therefore share a timestamp. The driver requires a valid monotonic total deadline, not advancement on every short sleep. The coarse-clock test waits eight times without starting a provider, then completes initial load with four exactly counted starts. Restoring the former per-sleep clock rejection reproduces the intended failure. The trusted sleep dependency must actually cooperate; this patch does not make a broken sleep implementation safe.

`runtime-ordinary.luau` copies caller options and sends the same lane to ordinary Session, reader, pipeline, entry, save-loop progress/rest children and lifecycle helpers. It refuses a conflicting lane or the old startup-budget owner. Main, Free and Easy tests supply the lane before construction, then run actual initial load, discovery, archive/commit, client entry, stored progress/rest acknowledgement and closed departure with exact A1/M1 retention. This does not prove Profile mode changes or service-owned replacement/removal/shutdown lifetimes.

## Evidence

Final `ordinary-qualified-2` passes **284075 fixed checks /138 named groups /0**:282370 preceding checks,583 ordinary Session checks in16 groups and1122 actual Runtime checks in3 groups. `verify-ordinary.py` reconstructs the full source bundle and every summary, the48-target/47-source compile and strict overlay, source-bound before/after loader probes, and separate unmodified STATE1488 and STATE_CLIENT161 checks. See `ordinary-verification.json` for the completed result and committed identity; these totals are not a release claim.

The two unchanged assertions in [the loader audit](SESSION-BOUNDARIES.md) intentionally fail on production and pass on this candidate. Delayed acquisition at221 stores and schedules beat221; the in-flight read has provider/Session/history counts2/2/2. Those original failing receipts remain intact. The interrupted `ordinary-qualified-1` output, receipt and exact compressed bundle remain explicitly incomplete. The final coarse-clock failure reconstruction changes only the old bridge, retaining the current test inputs.

Additional cases cover zero capacity, logical versions/newer choices, truly suspended MemoryBackend calls, preview/intent validation, retry nested in an existing step, credentialed checkpoint receipt, closure during admission/provider work, expired ownership, shared resource independence, reentrant notification closure, draining a write before saving the latest choice,120 quiet polls without new driver stacks, and startup-wrapper tampering. Allocation diagnostics do not establish CPU, FPS or loading gains.

All evidence uses memory providers and synthetic clocks. The full private cohort retains its declared WorldMap/Checkpoint overrides; the separate STATE and two loader probes do not add those overrides. Production source/tests remain byte-exact atbd67582b5d53473f067244fc1e2e1f94adde173b. No main merge, publication, engine activation or online save test occurred.

## Next work

1. Give the actual Profile/Replacement/Service factories one persistent physical-account Gate, from initial constructor admission through failed/cancelled construction, mode changes, removal, shutdown and replacement. Inspect option replacement at Profile mode changes; do not accidentally discard Runtime's cloned child lanes.
2. Retire competing startup admission and import complete prior debt once, including failed/ambiguous starts. Preserve debt across epochs and drain in-flight work before opening another epoch. Never use the present replacement guard as permission to fall back to untyped Session I/O.
3. Own cancellation during initial load. A native acquisition may already have committed when its result is revoked; drain it and verify safe cleanup rather than reopening a closed Session or fabricating an acknowledgement. Qualify the actual service with multiple actors and late constructor returns.
4. Qualify a bounded service driver and then native real-clock attribution, isolated synthetic test-store leave/rejoin, gameplay/input/audio/device/sustained-performance and release gates. The ordinary local driver is not the completed service driver. Normal startup and the overall optimization/stability goal remain open.
