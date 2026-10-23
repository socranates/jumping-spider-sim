# Typed New, departure and recovered lifecycle

These private overrides extend [recovered saving](SAVING-WORKERS.md). They route protected New retirement, closed departure and selected Runtime lifecycle calls through a trusted account lane. Normal startup remains unmodified. Terminal-held `RecoveryIdlePrototype`, initial/normal Session I/O and service-owned constructor/removal/shutdown/replacement lanes remain open. These results do not qualify partial installation.

## New retirement

`new-policy.luau` takes `options.admission`. Its lease, archive and routine-progress children receive that same lane. Root request totals derive from actual global starts across all children; direct reads and the selected raw retirement write retain their operations across waits. The raw write uses the captured same-store `updateRaw` adapter and the existing selected-key, held permit, source/observation and original-or-marker comparison. It never replaces `session.backend`.

Complete originals and the exact immutable proposal are freshly verified before retirement. Ambiguous retirement acknowledgement always requires fresh raw readback. Queued polls do not count attempts/failures or move phases. Typed guards retain monotonic/deadline checks through yielding callbacks. Refusal/cancellation cancels queued work and revokes its fence; committed storage and request debt remain. Verified retirement grants neither a new life nor gameplay. The verified/refused owner may maintain its lease until closed or superseded.

## Closed departure

`departure.luau` takes `options.admission` and keeps the original immediately closed input scope. It drains the prior owner, cancels queued owner lease maintenance and only then captures final local progress. Its explicit bindings call the captured `departureUpdate`/`departureRead` methods with the exact sealed departure ticket and progress key. They do not reopen the Session or borrow ordinary write authority.

The three-way pending-progress reconciliation, bounded final snapshot, callback replay handling, exact uncached readback, owned retry rule and hard cap/deadline remain. Success is verified preservation plus lock release; a successful or ambiguous write alone is insufficient. No rest/archive/proposal key is changed. Expiry cancels the queued operation and finishes the closed scope. A request committed before expiry stays committed/charged, drains before replacement and cannot later report verified release.

The new `Departure.expire(job)` is the cleanup entry point for an external deadline. A driver must call it instead of directly mutating job state. It refuses premature calls and can revoke a suspended provider's result authority while that provider drains.

## Runtime plumbing and its boundary

`runtime-lifecycle.luau` accepts a trusted `recovery.lifecycleAdmission` for read-phase/retired maintenance leases, returning-retired fresh-writer creation and departure. Existing recovered save-loop options retain their separate explicit injection; the eventual service factory must supply the same lane consistently. A returning retired writer clones its options and rejects a conflicting lane.

Runtime cancels its old maintenance route before departure and calls `Departure.expire` at a flush deadline. Restoring the former direct state mutation reproduces a stranded queued departure handle in `lifecycle-timeout-negative-1`; the corrected branch passes that same test.

The direct `Runtime.replaceFreshLife` helper refuses typed replacement with `service-owned admission replacement required`. It cannot reuse the old epoch's lane or silently begin untyped I/O. This is an explicit private activation boundary, not a completed replacement implementation. Existing legacy behavior with no lane is unchanged. Complete service replacement must close/drain the old account epoch and construct its fresh lane while retaining request debt; it remains required work.

## Evidence

The full `lifecycle-qualified-1` result passes **272651 fixed checks /111 named groups /0**:254680 preceding,2846 New,2852 departure and12273 recovered lifecycle checks. Sixteen new named cases cover all Main/Free/Easy source and retirement variants, continued original/proposal reuse, queued writes/readbacks, ambiguous outcomes, cancellation of an actually suspended committed retirement, closed departure merge/release, callback replay, foreign ownership, caps/expiry, suspended committed departure, queued owner maintenance, unresolved A-B-A progress, returning-retired New-only discovery and Runtime timeout cleanup.

The46-target/45-source complete overlay is compile/strict-clean in `lifecycle-types-qualified-1`. `verify-lifecycle.py` reconstructs the exact current full bundle, compares all preceding summary totals, binds source/type/output hashes, reconstructs the failed timeout counterexample and checks production against its unchanged committed source. `lifecycle-verification.json` records committed identity and evidence boundaries. The first development failure was a test comparing rolling debt across24 seconds without allowing old imported starts to age out; its original failed harness is preserved in a hash-checked ZIP. The final assertion compares debt immediately before versus after cancellation at the same clock time.

The new fixtures enable lanes at explicit quiescent boundaries after real CLI load/discovery or recovered entry. They use actual private Runtime/Service/Session, intent and checkpoint data, plus memory-backed storage and synthetic clocks. Earlier load and replacement providers are not represented as typed. The cohort also contains the previously declared private WorldMap/Checkpoint replacements. No native, online, phone, sustained FPS or loading-speed claim follows from these checks. Production source/tests remain at bd67582b5d53473f067244fc1e2e1f94adde173b. No main merge, normal startup activation or publication.

## Next work

1. Convert `docs/save-slot-isolation/recovery-idle-prototype.luau` and Runtime's held/failure route. Its terminal job identity, held permit, fresh probe, lock-only renewal, exact acknowledgement, bounded ambiguous-write probe and `leaseLost` behavior must survive waits and cancellation.
2. Audit every initial/normal Session and owner/provider path. Install one service-owned physical-account gate across initial load, constructor failure/cancellation, protected New, entry, gameplay saving, departure, removal/shutdown and replacement. Import complete unknown request debt once; retain debt across epochs. Retire competing startup admission and prevent untyped bypass. Complete typed replacement instead of removing the guard or falling back to a fresh old-style Session.
3. Preserve per-key timing, source/fence/transform authority, originals, fresh witnesses, latest local progress and stored acknowledgements. Qualify actual multi-actor/service lifetimes before a bounded cooperative driver. Then repeat native real-clock attribution, isolated test-store leave/rejoin and remaining gameplay/input/audio/device/sustained-performance/release gates. The overall optimization/stability goal remains active.
