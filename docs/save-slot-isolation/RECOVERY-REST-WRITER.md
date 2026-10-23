# Private exact selected-rest replacement

The writer implements one part of the agreed policy: replace only the selected original rest with its durable prepared Preserve packet, while retaining complete original saves/backups in A1. It is private and disconnected from production. It does not merge global progress, grant gameplay authority or prove remote ownership.

## Raw boundary

Ordinary DataStoreBackend.update decodes an R key before its callback and re-encodes its returned envelope. That interface cannot compare the original compressed storage representation exactly or retain the already-encoded M1 target byte-for-byte. `recovery-raw-backend-prototype.luau` constructs the production protected adapter without a rest codec, exposing explicit `updateRaw` and `readRawFresh`. It reuses the existing callback-error handling and uncached GetAsync boundary, rather than reimplementing them. Raw updates are restricted to valid owner/mode R keys; the wrapper rejects P/A1/M1 updates. No production adapter was edited.

## Preparation and protocol

Pure `Writer.prepare` validates the archive and packet, checks owner/archive/selected-source/progress descriptors, and owns/freeze-copies the complete expected raw rest and encoded target anchor. It can run under SaveWork with stable input; the returned opaque registered handle cannot be recreated by copying or fabricating a table. Registration is local provenance, not authentication, a durable archive receipt or a lease token.

The state machine reads back the complete M1 anchor uncached and requires exact equality with the prepared persisted proposal before attempting R. It then calls raw UpdateAsync. Its callback writes only when every field of the current stored rest equals the archived expected value, including the complete old backup, unknown fields, types and signed-zero distinctions. A checksum alone never authorizes replacement. If the exact encoded target already exists, it cancels the update and proceeds to verification. Every other value is left untouched. The callback rechecks the caller's synchronous fence on every invocation, has no compression/allocation/identity side effects, and makes no nested request.

Both a successful acknowledgement and an ambiguous failure require uncached raw R readback. Only exact target equality produces `restVerified`. If the original remains, the job requires explicit caller backoff/retry; a failed read is retryable, while missing/changed data refuses. Restart first verifies the same M1 again and may recognize an already-written target without rewriting it. Revocation/cancellation before, within and after requests prevents a local verification result; a write already committed remotely cannot be undone by cancelling the local job.

Each step makes at most one request. Caller integration must use the existing scheduler, maintain heartbeats, budget retries and enforce an overall deadline. Network work is refused inside SaveWork. Preparation traversal/copy/checksum/freezing can yield; the atomic compare callback itself cannot yield. Large uncompressed legacy records may make that callback expensive, so native latency measurement remains necessary.

## Evidence

117 writer/adapter assertions pass alongside 660 preceding checks (777 total), with full strict analysis across eleven private candidates. The actual DataStoreBackend boundary is exercised over a fault-injected in-memory DataStore facade and reversible codec fixture. It verifies UseCache=false reads, M1 publication composition, no normal rest codec calls, exact opaque target reuse, all three slots, compressed originals, explicit backup recovery, changed original/backup/metadata refusal, missing sources/proposals, competing jobs, repeated callbacks with a final concurrent change, lost acknowledgements, readback failure/retry, local revocation and reentrant cancellation. P and unselected R remain untouched. Callback errors report failure through the production protected boundary.

Cooperative preparation completes with 2,616 suspensions under the deliberately tiny synthetic budget and returns the same plan as synchronous preparation; cancellation exposes no handle. This count is a scheduler behavior check, not a frame-time/FPS result. Earlier 84/115-check fixture evidence is retained. `verify-recovery-rest-writer.py` rebuilds the current executed bundle and verifies input, output and compile/strict hashes against unchanged production runtime/test bytes.

## Authority and remaining transaction work

Archive.check validates a local plan, not durable A1 publication. The writer verifies M1 itself but currently relies on future controller integration for completed A1 fresh-readback proof, selected intent and actual lease management. A local guard is not an atomic check of the separate P-key lock inside an R update. The exact R CAS prevents overwriting a changed rest and repeated application of this proposal; it does not solve that cross-key ownership interval or provide a complete migration commit. Integration must define durable accepted intent and cross-session recovery, enforce ownership before granting gameplay, and test takeover/cancellation races explicitly.

Remaining: compose the controller/archive proof and request scheduler; losslessly absorb pending progress into current P under its timestamp/ownership rules; retain proposal data until absorption is verified; integrate schema-3 readers/writers and entry handling; verify native compression, callback latency, real-service interruption/rejoin and release. The selected-rest primitive does not make migration playable, and nothing has been published.
