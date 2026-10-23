# Private recorded-save and pending-import offer reader

The reader discovers an actual legacy Test Garden save or an interrupted M1 import from uncached raw server-owned values, validates it, and publishes an ordinary **protected** SaveObservation through the real session API. It does not restore a world, allocate a life, take a lease, write a key or issue a credential. Production SaveService/menu routing is not yet wired to it.

## Discovery and validation

Cold discovery reads the selected R and M1 keys. With no M1, the requested primary is the default; backup recovery requires an explicit request. Header/schema/checksum validation precedes full recorded-world and portable-life field validation. Corrupt/newer/unreadable primaries never silently fall back. Ordinary Preserve saves stay on the normal reader; this is not an alternate ordinary Continue path.

With M1 present, the reader validates its packet and exact owner/slot, then reads all five A1 publication artifacts including the completion index. It reconstructs the original source matrix without writes/repairs, checks storage/structural/aggregate budgets, and compares every expected publication shape and descriptor. Current R must equal either the complete archived raw original or the exact encoded M1 target. A semantically equivalent but differently encoded target does not suffice. The pending packet's original primary/backup selection is retained; a conflicting explicit selection refuses. The original archived record is validated and offered with its original identity, never relabelled as Preserve terrain or substituted with the new checkpoint.

Missing/incompatible archive artifacts, foreign scopes and modified originals/targets refuse. Future/unrecognized M1 data blocks automatic legacy fallback. Input parts and server key scopes are checked before use. The reader retains only source descriptors from the pending decode rather than decoding the full packet a second time. A spy check requires exactly two codec calls on that path: pending packet plus original envelope.

The successful result owns/freezes its original record. Publication creates the existing session's protected observation and emits its onOffer callback only after staging is released. Public offer mutation cannot change the server observation. Reader jobs fence session/load/backend/key/scheduler/observation/intent identity before and after yielding operations; a newer intent, superseding load, closure or replaced offer cancels discovery. They serialize request calls with the ordinary worker and share the rolling session request allowance. Defaults cap discovery at 16 requests/300 seconds. Pure validation/copy/freezing can yield under SaveWork. Provider read results must be isolated/stable, as with the existing backend contract.

Discovery is a readonly snapshot, not a current remote lease or multi-key atomicity proof. It does not renew a lease and grants no authority; admission/commit still requires fresh acknowledged ownership. A normal caller must coordinate heartbeat servicing and keep template/context inputs stable. Structural/storage validation bounds the publication, but native peak memory/frame cost and the synchronous observation-publication copies are not measured by this fixture.

## Compressed original admission fix

The prior archive controller compared identity fields directly on the opaque raw R representation. A compressed original has no payload there. It now accepts an explicit `restCodec` option, decodes the selected source inside cooperative preparation and compares the same original checksum/time/life/kind. The archived bytes remain untouched. Existing callers without a codec preserve their previous path. The separate 2,621-assertion archive cohort, retained heartbeat counterexample and full strict analysis still pass with refreshed source-bound receipts.

## Evidence

The new reader cohort passes 1,711 assertions plus the preceding 5,795 regressions (7,506 total), with full strict analysis across eighteen private candidates. Its cold uncompressed and compressed paths each use 2 discovery requests, 22 archive-controller requests and 31 post-archive coordinator requests. These are separate phase counts in a synthetic scheduler, not an adopted combined limit or service/FPS measurements.

Unlike the older coordinator fixture's diagnostic offer bridge, the new paths obtain the original record through this reader, select its real protected offer, publish/verify the archive through the actual archive controller, then run the post-archive coordinator. The pending-target path discovers the stored M1/A1 record and resumes through the same real observation/intent APIs. No test manually publishes an original offer on those new paths. The older isolated coordinator tests remain unchanged as component regressions.

Tests also cover explicit backup/no automatic fallback; ordinary Preserve refusal; exact raw target comparison; foreign scopes; missing/corrupt A1 artifacts; nil archive containers; read retry; no reader writes or credentials; one request per step/shared quota; emitted callbacks; public-copy isolation; intent/load cancellation; worker reentry; and server key isolation. Cooperative pending preparation yields 4,388 times under the deliberately tiny synthetic budget and preserves the source/live map. The earlier 1,708-check fixture and source are retained. The lower suspension count after removing a duplicate decode is not a native performance benchmark.

## Remaining integration

Wire the reader and cold/resume choice into production SaveService/menu flow, compose discovery/archive/commit under a single overall bound and heartbeat owner, and rebind session progress/observations before ordinary writes resume. Complete schema-3 readers/writers, pending-proposal retention and the durable entry credential path, including mating/hatching/ended-life handling. Existing seed/history/schema limits still refuse unsupported sources without altering them; this reader does not make every historical variant migratable.

Native compression/latency/heap/frame qualification, actual DataStore interruption/takeover/rejoin, full adopted regression gates and release remain open. This is executable private recovery plumbing, not a playable or published migration. No production source or real saves changed.
