# Private returning-session recovery

A later schema-3 checkpoint must be read as the current rest. Replaying its immutable M1 initial target would rewind the spider to its original imported generation. The private Runtime now distinguishes a continuing save from an unfinished import, binds the actual current observation, and enters without running the original archive/commit pipeline again.

## Opt-in contract

Install all three server dependencies together: `currentFormat=RecoveryRestFormatPrototype`, `entryFactory=RecoveryEntryPrototype`, and `saveFactory=RecoverySaveLoopPrototype`, alongside the existing codec/raw store/template/context dependencies. The existing default reader remains compatible with its preceding legacy/pending-import behavior when `currentFormat` is absent. This is still private composition; production SaveService, SaveClient and remote/menu wiring do not install it yet.

Discovery reads the current R, M1 and all five original A1 publication records uncached. It rebuilds and validates the complete archive, checks the proposal binding, and opens the active initial/continued schema-3 payload through the current format. It publishes a protected view of the **current checkpoint and current primary identity**, independent of the original source being primary or backup. No gameplay credential or archive repair is issued during discovery.

After the real Session chooses that displayed Continue, Runtime rechecks the actual request/selected observation tuple after its notification callback, acquires an enforced acknowledged baseline hold and records a separate `continuedSelection`. It does not fabricate a migration job or call `Pipeline.begin`. The server-only verified archive transfers from that exact reader job into the bound selection; it is not a client message field. The entry owner pins that same selection and requires the freshly observed R checksum/time/life to match it, so a newer rest cannot silently replace an older selected view.

Entry reuses the owned immutable archive already fully fetched during discovery. It freshly checks M1 and the complete A1 index, revalidates the cached original archive in CPU preparation, then performs its current R/P proof and existing client-apply/final R/P handshake. The cached plan is retained by reference rather than keeping a second resulting archive copy. Original A1 parts are immutable under the existing publication protocol, and Runtime cannot resume this selection after losing its lease/session. As with the current writer's index-only checks after entry, arbitrary out-of-protocol archive mutation behind an unchanged index is not detected on every cached use; a fresh-session full discovery scans the parts again. No archive pruning or mutating writer is added here.

The initial packet, before any continued checkpoint has been written, also follows this entry-only path on a new visit. Current mating/hatching state is read independently from the original import's scene. The real entry-issued credential then works with the single routine progress/rest/idle/departure owner from `RECOVERY-SAVE-LOOP.md`. Normal, Free and already-unlocked Easy retain their actual rule gates.

## Refusal and compatibility

A corrupt/retired current rest, missing original publication/proposal, mismatched provenance, replaced selection or changed selected rest does not fall back to the original import target. Explicit `backup` on an already imported current save is refused until there is a separate current-backup policy; it must not accidentally select the archived pre-import backup. Importing an original backup remains supported, and its later current **primary** is a normal continued selection.

`RecoveryRestFormatPrototype.open` now checks the known current envelope/lock metadata before delegating to the payload validator. Discovery, entry and current writer use it, preventing a subsequent envelope rewrite from silently discarding unfamiliar outer fields. Reader and writer refusal of such fields are exercised; the entry owner uses that same header gate. Existing `spec` compatibility remains available for its prior format-only callers. This change does not claim a full audit of all future optional checkpoint graph fields.

Protected ordinary writes remain blocked throughout. Returning entry performs no non-P updates: it does not write R, M1 or A1. A rejected route leaves the current data untouched. New Life/retirement and explicit backup restoration remain distinct work, not shortcuts through the initial import.

## Evidence and loading cost

`recovery-rejoin-verification.json` binds final `rejoin-attempt-5-*` and `rejoin-types-4-*`: **42,700 rejoin assertions + 84,765 preceding checks = 127,465 passing assertions**. Entry compilation/full strict analysis cover the current 32 private candidates. Counts include per-step quota/busy/permit assertions, not that many independent gameplay scenarios.

Normal/Free/unlocked Easy each exercise both plain and compressed current R transport and three separate actual session factories over shared storage. Tests advance the actual Mating/Rare generation, persist settings and checkpoints, depart/rejoin without initial-target writes, then save and rejoin again. They check latest generation/elapsed/rare state and settings, unchanged originals, actual entry-issued credentials and zero non-P updates during returning entry. Additional cases cover an initial packet with no subsequent checkpoint, current mating/hatching scenes, backup-origin import/current primary, corrupt/retired/missing provenance, explicit backup refusal, changed current identity, replaced selection and unsupported current envelope fields.

The first working version fetched the archive twice and used **25 backend requests /126 simulated seconds** per measured returning visit. Reusing the already verified archive lowers all six measured cases to **20 requests /72 simulated seconds**, retaining the same rolling ten-request allowance. These are deterministic one-step/one-second model results with the in-memory backend, not real Roblox loading time or FPS measurements. The startup path remains too expensive to call release-qualified: profile and reduce its remaining load/proof/budget cost before production adoption.

Historical variants are retained. Attempt1's fixture expected cold migration to enter immediately instead of driving its existing pipeline. Attempt2 passed before archive reuse; attempt3 passed with reuse. Attempt4's new header test accidentally mutated the plain in-memory stored record through the codec's borrowed result, and the real rest CAS correctly refused that changed record. Attempt5 gives the test its own copy. The first strict receipt's shadow warning was renamed; the final strict cohort is clean. Earlier individual verifiers pin their older private dependency bytes; this final combined cohort is the current proof.

## Remaining work

Qualify startup latency and actual server/client transport/compression, then complete explicit retirement/new-life handling, later-slot reuse of original A1, original archive/proposal lifetime, and safe replacement of a lost session while preserving local edits. Wire all production service/protocol/client selection, paused-world, error, load/tick/leave/shutdown paths. Actual DataStore interruption/takeover/rejoin, native performance/phone/long-session checks and broad production release gates remain required before main integration/publication/laptop synchronization. Production sources/tests remain unchanged at `441eaca`; nothing was published and the overall optimization/reliability goal remains active.


## Subsequent startup admission milestone

Runtime now optionally installs the bounded startup owner described in `RECOVERY-STARTUP-BUDGET.md`. The current 128847-check cohort includes all rejoin assertions; use `verify-recovery-startup-budget.py` for current hashes. Rejoin receipts above remain historical evidence for their original bytes.
