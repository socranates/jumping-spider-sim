# Private authenticated continuation writer

`RecoveryCurrentWriterPrototype` implements a bounded writer for a later checkpoint in an already recovered, explicitly writable life. It does not grant that life, enter a scene, retire a life, or connect itself to production. The current Runtime remains in its enforced `entry_required` hold.

## Contract

Construct it with the actual factory-bound SaveSession, its matching physical raw store, codec and checkpoint context. `capture(mode, intentSerial, credential, life, restSerial)` requires a real writable Continue intent and fresh locally confirmed lease. Its opaque owned handle pins the session/load epoch, intent revision, progress/rest keys, backend, scheduler, original recovery owner and baseline hold. `prepare` validates the original full archive and proposal, the exact currently stored schema-3 rest, current checkpoint/life, original provenance and current rare-generation binding. It returns a frozen, single-use plan. No caller-supplied authorization callback can replace the actual intent check.

`begin(plan)` reserves the monotonic rest serial. Cancellation or refusal consumes that serial; a retry must use a newer one. Preparation performs no I/O and can cooperate through SaveWork; admission and provider work run outside preparation. This API is server-private. Checkpoint/template/archive inputs must be server-owned, never a replacement authentication mechanism for remote client data.

Each step makes at most one charged request, sharing SaveSession's ten-per-minute allowance. Each job has at most 16 requests and 180 seconds. The steps are:

1. Uncached exact M1 proposal read.
2. Uncached exact complete A1 archive-index read.
3. Renew only the existing fresh owned P lease. Its progress payload must already cover the immutable proposal and the current checkpoint's rare serial/visit. This writer cannot invent or merge missing progress. Lost lease acknowledgements trigger an uncached probe.
4. Update the selected R key only if its raw value still equals the prepared predecessor, or leave an already exact candidate alone. An unexpected rest is refused.
5. Read R uncached and require the exact candidate, including lost write acknowledgements. An unchanged predecessor retries under the same bounds.
6. Read P uncached again and require fresh ownership, covered progress and unchanged actual life credential before recording the stored serial and emitting one receipt.

The original archive and proposal are never written. Other R slots remain untouched. An unchanged continued payload preserves exact raw bytes and its existing backup; a changed checkpoint uses normal single-backup rotation while retaining the fixed original provenance.

## Evidence and limits

`recovery-current-writer-verification.json` verifies **1,127 new assertions + 50,827 preceding checks = 51,954 passing assertions**. Entry compilation and full strict analysis of 28 private candidates pass. The tests use the actual bound Runtime load/discovery/archive/recovery path, first assert that its read-only entry refuses capture, then explicitly call the actual intent owner's `grant` **inside the test fixture only**. This isolates the writer contract; it is not evidence of implemented gameplay entry or restored player authority.

Coverage includes successive actual checkpoint captures, no-op backup preservation, immutable artifacts, exact selected-rest comparison, lost acknowledgements, failed writes/reads, expired/foreign leases, uncovered rare progress, revoked intent, provider/load/request changes, clock reversal, cancellation, request/deadline limits, overlapping calls and provider suspension across close. A forced takeover after R commits suppresses success and does not attempt an unsafe rollback into another owner's data.

P and R are separate keys: no cross-key atomic transaction is claimed. Safety relies on legal owners honoring unexpired leases, callback checks, fresh readback and final ownership validation. The complete archive was validated for preparation and its published immutable index is checked each job; this writer does not reread every archive part on every rest. Full archive authentication belongs to entry, and immutable A1/M1 writers must retain their existing protocol.

The writer currently emits the stored receipt but does not adopt SaveSession rest caches/bases or change its hardcoded schema-2 worker. Production SaveService/remotes/menu, schema-3 scene application/credentials, retirement/fresh-life lifecycle, safe session replacement, later-slot reuse of original A1, native compression/frame costs and real DataStore interruption/rejoin remain open. The runtime must not be stepped concurrently as though the writer were already integrated. No FPS, native, real-service or release improvement is claimed. Production source remains `441eaca`; nothing was published.

## Next integration work

Implement a private schema-3 entry owner that validates the current fresh rest and original archive/proposal, prepares scene-specific restore, and applies it before issuing the actual life credential. It must keep the enforced hold on failure, bind the writer to that same owner, route lease/ordinary saves/departure through one coordinator, and update actual per-slot caches only after proof. Test close, cancellation and superseding selection across every yielded boundary before connecting production.
