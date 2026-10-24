# Current candidate authority and save boundaries

2026-10-23. Scoped source review of the same 273-source private candidate as
[DATA-CURRENT.md](DATA-CURRENT.md). The [source inventory](integrated-source/inventory.json)
binds its module bytes. This supplements the older SECURITY.md; neither report
is an adversarial native network-load test or an anti-cheat certification.

Life, movement, meals and discoveries remain client-authoritative in this solo
game. A modified client can fabricate a structurally valid life. Server save
checks protect record shape, slot identity, ownership and supported transitions;
they do not prove that a meal was earned. No server simulation rewrite is made.

## Reviewed boundaries

| Boundary / current modules | What the current code checks | Evidence boundary |
|---|---|---|
| Caller and store selection: Persistence, SaveStores, ReplacementService | Engine supplies the Player; production owner comes from UserId. Replacement carries the original physical account identity. Explicit store override is allowed only in Studio/test scope with a bounded WindowsillTest name | Source review and isolated ordinary-startup real-storage proof; never a client-selected arbitrary key |
| SaveService message handling | Table/string header, negotiated compatible protocol, per-family hello/progress/life/recovery/rest buckets, bounded serials and owner dispatch. Handler exceptions are counted/logged through protected calls | Standard CLI suites and owner protocol qualifications; not native malicious-remote fuzzing |
| ReplacementService transport | Explicit capability opt-in, closed small field sets, epoch/serial/transition identity, bounded progress, retry spacing on new replacement requests. Prior owner must be verifiably closed before a new entry is constructed; stale callbacks retain old leaving state | Session/replacement cohorts and actual ordinary mode replacement; no claim that every handler is globally rate-limited or flood-proof |
| Fresh life | New-life capability, known slot, bounded serial/token/progress and exact owner/epoch/mode/offer binding; pending request blocks ordinary intake | Owner policy and lifecycle protocol checks. Advertising a capability is not a fresh-life grant |
| Recovery observation: RecoveryOfferValidation | Current validation first; portable historical validation only for received explicitly protected observations. Bounded record, known slot/rules, no retired marker | Counterexamples and actual protected legacy Continue qualification. This function neither restores the world nor grants a life credential |
| Recovery entry and writers | Exact current session/load/intent/life binding, authenticated original archive/proposal and current rest; preparation/readback before writable entry; continuing rests retain provenance | Qualified native/real-test-store pipeline, ordinary startup and fresh-process rejoin; not arbitrary unknown historical records |
| Serialization: SaveRest, Checkpoint, ObjectRecord, RestCompression | Finite plain bounded input; named object/class/ref allowlists; fresh decode/world validation before commit; separate stored/expanded budgets and pre-decompression size checks | Save, codec, graph and current-format tests; checksums identify corruption, not a trusted client |
| Physical I/O: DataStoreBackend, RecoveryRawBackend, RequestAdmissionGate, account lifetimes | Shared physical account ledger, separate read/write allowance checks, fresh uncached verification, options cleanup, protected SDK callbacks and exact raw CAS where required | Real test-store SDK/ledger accounting and released owner scopes; no production records touched |
| Streaming focus: WorldFocus | Engine Vector3 (CLI shim alternative is local only), finite components, authored map bounds, minimum0.09s between accepted moves, caller's own named focus part | Source and standard tests; it still accepts the caller's claimed bounded position and can cause replication work |

The current SaveService accepts more than the old report's hello/progress/rest
list: life intent, offer refresh, recovery application and replacement/new-life
transport are explicit additional paths. The ordinary onMessage protected-call
boundary does not imply every operation in the outer replacement adapter is
wrapped by that same handler. Closed-field/state checks and protocol tests must
be assessed at each actual entry point.

## Kept constraints and remaining risks

- Old/future/invalid stored data is preserved and refused when it cannot be
  safely understood. Never fix a failed read by writing defaults over it.
- An archive checksum or successful parser result is not a durable storage
  receipt. Separate publication, exact raw readback and ownership fences remain
  necessary; Roblox does not provide the multi-key transaction this flow needs.
- A scene restore or client recovery-applied message alone must not grant
  writable entry. Server entry proof and current credential/epoch checks remain
  separate from client presentation.
- The current larger rest budgets are bounded but can still cause substantial
  CPU/memory work. Yielding and admission proofs do not establish safety under
  a sustained hostile native traffic workload. Treat multiplayer/economy work
  as a new authority and load-design decision.
- WorldFocus player removal destroys its part and clears lastReport. Its
  listeners intentionally live for the server lifetime; do not repeatedly call
  listen/watch in a reload path without explicit connection ownership.
- The ten warnings retained in the current native suite remain unexplained
  environment/runtime observations. They are not evidence of an exploit or a
  reason to hide future warnings. No new native security probe was run here.

The scoped source reconciliation found no additional confirmed corruption or
cross-player-write bug requiring a patch. That conclusion is bounded to the
reviewed paths above. Larger server authority changes, broad stress testing and
the remaining native/device audit rows stay open in [HEALTH-CURRENT.md](HEALTH-CURRENT.md).
