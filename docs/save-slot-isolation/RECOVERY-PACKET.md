# Private recovered-rest packet and immutable proposal

Policy: import portable spider progress into a fresh Preserve while retaining the complete original raw saves and backups in the unchanged A1 archive. This module prepares a proposed format; it does not call a store, replace a slot, grant gameplay authority or publish a migration.

## Commit shape

The selected rest contains one checksummed schema-3 envelope with the assembled checkpoint, lossless global-progress proposal, fixed choice timestamp, rare-life binding, entry kind and archive/source descriptors. Keeping these together avoids a half-written checkpoint/progress pair within that one key. Global progress is still a separate key: Roblox offers no multi-key atomic commit here. The rest must retain its pending proposal until the global record has absorbed it, with recovery through the immutable proposal if needed.

`Packet.prepare` validates the owned archive plan, explicitly selects primary or backup, verifies the original envelope before recorded-world validation, and composes the existing life, progress and destination preparers. It encodes once, verifies the logical round trip and returns a frozen `M1_<owner>_<slot>` proposal. M1 contains the encoded target plus bounded source/archive descriptors, not another complete raw archive. The original backup stays in A1 rather than being duplicated inside the first recovered rest. `Archive.check` proves local format/ownership consistency, not that those keys were durably published or read back. Checksums describe integrity, not authentication.

The proposed rest schema is 3. Production remains schema 2 and is unchanged. Existing readers refuse the new envelope as newer before validating its payload; a private schema-3 reader also accepts ordinary prior checkpoints and retirement markers. Compression uses the existing outer transport version 2 with innerSchema 3. Closed field sets, checkpoint validation, node/depth/storage budgets, source/binding consistency and explicit ended-life refusal apply. Primary corruption never silently selects the backup.

## Progress capacity

The proposed packet allows at most 32,768 canonical progress characters, within the existing node/cardinality bounds. The old declared 16,384-character progress constant is not currently enforced by production SaveProgress/SaveSession/SaveService. A legal union of 200 pages, 64 rare claims and 64 once flags occupies 19,363 characters in the fixture. Truncating it or adding a new 16K refusal would lose supported progress. This private explicit budget preserves that case and refuses oversized data. It changes no production constant. Provider/native compressed budgets still need qualification; the existing compressed rest limits remain enforced.

## Evidence

38 packet checks pass alongside 62 progress, 72 destination, 360 life and 49 meal regressions (581 total). Coverage includes all three mode slots, ordinary older rest compatibility, old-reader refusal, source immutability, explicit backup selection, malformed/future transports, corrupted payloads, closed fields, scope/binding/entry tampering, storage refusal and the wide legal progress fixture. Full strict analysis passes with eight private candidate modules in a disposable source tree. `verify-recovery-packet.py` rebuilds the exact bundle and checks input/output/type hashes.

The fixture exercises actual RestCompression code with a reversible in-memory codec adapter. Its compression deliberately returns different opaque bytes for the same logical input, demonstrating why retries must reuse the first persisted proposal. This is not native Zstandard, native heap/FPS evidence or a real DataStore test. Earlier 30-check packet evidence and pre-packet progress evidence remain preserved.

## Required next implementation

1. Verify the completed A1 archive through fresh raw readback and keep exact source/selected-intent/owner fences active.
2. Publish M1 immutably before replacing R. An existing compatible M1 must be reused byte-for-byte; never recompress and overwrite it. Refuse conflicts and unknown versions.
3. Replace only the selected original R with an exact raw-value compare-and-swap. The ordinary backend update decodes R before its transform, so it is not an exact raw CAS adapter. A local lease flag cannot atomically prove P ownership inside a different R-key update.
4. After an uncertain acknowledgement, perform uncached raw readback and resume the same proposal. Never allocate a new rare identity on retry.
5. Absorb the saved progress proposal into the latest global record using its fixed choice timestamp and lossless monotonic unions. Preserve later observations; refuse capacity overflow. Do not grant gameplay/write authority before the required verification completes.
6. Integrate schema-3 readers, later rest writers, scene-aware entry, ended-life handling and restart/rejoin tests. Later writers must preserve pending progress until its absorption is verified. Resolve archive/proposal lifetime and generation-mismatch binding explicitly.

Immutable publication, exact R CAS, P absorption, real ownership races, native compression/service/rejoin tests and production integration are not implemented by this packet module. Migration remains unavailable to players.
