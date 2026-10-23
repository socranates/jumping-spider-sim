# Discovery worker admission candidate

This continues the primitive qualification in [README.md](README.md). It adds an explicit override of the actual recovery offer reader, a provider-boundary bridge and a one-time import of existing request debt. **The ordinary game still uses the preceding adapters.** Other recovery workers, service-wide epoch ownership and a cooperative driver are not converted or installed. No native loading improvement, online save verification or publication is claimed.

## What changed

`reader.luau` is the existing `docs/save-slot-isolation/recovery-offer-reader-prototype.luau` with an optional `options.admission` path. Every rest/proposal/archive read and all validation/publication checks remain. Cold discovery still performs two uncached reads; pending discovery still performs seven. Without that option, the old aggregate scheduler remains the fallback.

The option supplies a trusted plain `{gate, scope}` record. `worker.luau` binds the physical account, epoch, backend, scheduler, counters and original job guard. It retains one facade operation across polls. Capacity denial does not touch the provider, attempts, scheduler history or failure/backoff state. Actual dispatch rechecks the job and routing after the platform allowance callback, then counts the attempt immediately before the captured backend method. Provider exceptions are converted to the existing backend failure tuple, preserving the reader's retry delay. Actual backend false/error tuples also remain intact.

Cancellation releases a pending operation. A started call remains charged and drains before the same physical actor can open another visit. A late result cannot publish an offer or authorize gameplay. The generic bridge checks lifetime before and after each update transform, including retries. A write already committed before cancellation remains in storage; dropping its acknowledgement neither rolls it back nor reports success.

`worker-facade.luau` differs from the earlier facade only by the explicit string-map annotation required by the full Roblox strict overlay. The earlier primitive receipt remains bound to its own unchanged files.

## Debt and ownership contract

`worker-admission.luau` extends the earlier gate with `importLegacy(scope, scheduler.started)` and `legacyReady(scope)`. Import must happen before this physical actor has typed requests or typed history. Its bounded plain dense array is validated in full before adoption; future/nonfinite/sparse values refuse. Recent legacy starts are conservatively charged against **both** read and write caps, including any departure overage. Expired starts are ignored. Import copies timestamps and cannot be repeated to reset debt. A replacement visit retains readiness and recent debt while its actor record survives.

The server service must own one gate across all participating accounts and epochs. A job owns only its operation. This candidate does not provide that service integration. **Do not turn on just the typed reader in the existing Runtime:** its lease, ordinary save, migration, entry, New and departure workers could otherwise start requests outside the shared gate. Switch every provider path together, under a closed/drained transition; refuse an invalid debt import rather than resetting it or manufacturing empty history. Existing lease/source/transform/currentness checks, per-key intervals and stored acknowledgement rules are still mandatory.

The test policy is deliberately explicit (40/40 per actor and80/80 server for reader fixtures); it is not an adopted production policy. The portable tests use additional configurations. These values do not establish platform or experience capacity.

## Qualification

`workers-qualified-2` runs the full preceding actual-menu recovery cohort with the reader override mounted, followed by eight typed-reader cases and six bridge cases: **211864 fixed checks /48 named groups /0** (211717 preceding,127 reader,20 bridge). The earlier tests exercise the fallback; the new cases explicitly supply the typed lane. All44 private overlay candidates compile and the complete production overlay is strict-clean. The overlay still includes the earlier WorldMap and Checkpoint replacements. These are CLI/memory/synthetic-clock results.

`bridge-qualified-2` independently passes4873 checks:4771 policy,82 around the actual production DataStoreBackend with injected providers/options, and20 bridge checks. These overlap the bridge checks above and must not be added to that total. `ledger-qualified-1` adds12215 comparisons over1200 interleaved steps against the preserved pre-optimization gate; both versions start the same13 providers. Existing portable tests cover yielding/reentrant callbacks as well.

`bridge-before-throw-fix-*` retains a failing test against the bridge from commit6aa8d72. A provider exception previously became terminal admission failure, skipping the actual worker's backoff. The passing counterpart includes that same test plus an actual reader throw/retry case. This is a private bridge defect, not evidence that the old normal game had this behavior.

`verify-workers.py` reconstructs both current bundles, binds source/inputs/outputs/type mounts to exact committed bytes, checks the failing counterpart, and records the installation/evidence boundaries in `worker-verification.json`. Prior development and qualified-1 logs are historical, superseded by qualified-2. The initial development harness exceeded Luau's local-register limit; the runner now injects helper modules in their own function scope. The failed bundle is retained as a zip. An early CPU harness run produced output but failed to write its receipt; it is not qualification evidence.

## Measured CPU cost

The original implementation rescanned all request history for each earlier queued item. A bounded stress fixture (64 actors,150 inherited starts per occupied actor,256 pending tickets,20 samples) exposed a roughly118ms median per reservation attempt. This is too expensive for a frame-driven service. The current gate builds a single synchronous totals snapshot per admission attempt, preserving the same reservation exclusions, in-flight headroom and fairness decisions. After the full regression job finished, a paired CLI run measured112.303ms before and2.121ms after (p95:115.611/2.721ms). The smaller16-actor/32-ticket fixture measured0.223/0.049ms. The before/after CPU receipts bind exact gate bytes and fixtures. These are CLI CPU samples, not Roblox FPS or end-to-end recovery timings.

The totals snapshot is rebuilt after the final clock/version fence. No callback or yield occurs while its fairness checks run, so it cannot outlive the admission state it represents. Started provider work still invalidates subsequent admission observations. Storage failure/cancellation never refunds rolling debt.

## Next integration

1. Convert the actual archive collector/controller, commit, pipeline, entry, read lease/idle, current/progress writers, New and departure paths to retained typed operations. Count caps/counters only at provider dispatch. Preserve job/owner deadlines and existing verification reads.
2. Install server-owned physical-account lanes across initial constructors, failed loads, removal/shutdown and replacements. Import unknown debt once and ensure no fallback provider can bypass the gate. Qualify concurrent actors, allowance loss, constructor cancellation, closed scopes and ambiguous writes through the actual service.
3. Add a bounded cooperative driver independently of admission. Keep the normal one-second Persistence poll from becoming the CPU-slice clock. Measure work at configured policy/capacity limits.
4. Run the complete current application cohort/strict overlay, then a real-clock native fixture with real RemoteEvents and engine codec. Verify isolated real-store leave/rejoin, then the remaining lifecycle/input/audio/device/sustained-performance release gates. Do not infer a game speedup from the synthetic admission or CPU fixtures.
