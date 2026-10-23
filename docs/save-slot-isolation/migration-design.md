# Historical-world recovery: implementation decision record

Status: policy selected; implementation pending. The user delegated this choice on 2026-10-22. Import portable spider progress into the Preserve while retaining the complete original save in an untouched archive. No schema or production behavior has changed yet; runtime032926f retains protected historical slots.

Subsequent private work onccc0abb: [recorded-world inspection](RECORDED-INSPECTION.md) validates a populated Test Garden fixture without changing the Preserve or enabling ordinary restore.33 checks,11 cooperative suspensions, both module compilations and full strict analysis pass. This is a preparation component, not an implemented archive or progress import.

Subsequent405e9df private [raw archive preparation](RECOVERY-ARCHIVE.md) passes73 CLI/82 native checks plus compile/strict. It preserves complete opaque source values under bounds and cancellation. Durable raw reads/publication and actual progress import are still unimplemented; ordinary Continue is not loosened.

Private publication/fresh-read components are now implemented and verified separately: [272+32 CLI/304 native checks](RECOVERY-PUBLICATION.md), including restart reconstruction, bounded per-step requests, real coroutine suspension, uncached verification and actual options-object cleanup. They remain outside production; actual server authority/raw collection, real DataStore durability and progress projection still need integration and proof.

## Selected recovery policy

The selected behavior is option 1:

1. Import portable spider progress into the current Preserve, keeping the entire original checkpoint as an immutable archive. This keeps the current habitat playable but does not promise that the original ecology can be resumed interactively.
2. Resume the original world separately. That requires a world-compatible launch path/server and routing, rather than applying its populations inside the Preserve. A separate published place is one possible implementation, not an authorized account change here.

The complete old checkpoint must remain intact. An archive is preservation, not proof that an old world is playable. The UI/handoff must describe the actual supported behavior. The user answered "whatever you think is fine"; Chet selected import plus an untouched complete archive and communicated that decision. Separate old-world play is not part of this implementation.

## Shared first step: explicit map views

Checkpoint.check currently decodes private objects but checkWorld resolves garden ids through the globally active WorldMap.region. A genuine test_garden bed_a population fails under the Preserve. Changing this lookup alone would be unsafe: apply commits the old garden into live roots, and capture then stamps the current world's name.

Introduce a lookup selected by the recorded world id, seed and supported revision. It must not call WorldMap.use during validation, including cooperative yields. Never pass an unknown id through Worlds.choose, whose default is the Preserve. Unsupported identities/revisions retain the original slot and return a reason. Existing support for unknown-world empty records needs an explicit compatibility decision; do not silently change its test contract as a side effect.

The view must supply consistent region, retreat, bounds, revision and seeded authoring data. A read-only method table alone is insufficient if it exposes mutable shared region tables. A view can own frozen copies with preserved internal aliases, or use an equally strong ownership contract. Keep default views bounded by known worlds. Do not globally cache every untrusted seed/revision and create an unbounded memory sink. Historical revisions that moved geometry may need versioned trusted map data; a current map is not a validator for every old revision.

Tests must interleave two worlds and suspended validation workers while an ordinary live map remains active. Assert that the live world id, regions, engine-root references and generated geometry never change. Include cancellation/error paths and unknown world/seed/revision refusal. This is shared work for either recovery policy, not completion of migration by itself.

Private prototype: map-view-prototype.luau is injected into an in-memory CLI bundle by run-map-view-prototype.py. It passed167 assertions: explicit Test Garden/Preserve lookups, owned frozen nested records, retained internal aliases, supported boundary seeds, unknown world/revision refusal, repeated coroutine suspension with interleaved readers, and cancellation without changing the active map. A disposable source copy also compiles and passes full strict analysis (map-view-types-receipt.json); production WorldMap remains untouched. It supports only the currently authored world-3/preserve-3 identities; it does not invent geometry for older revisions. Native checks, integration into Checkpoint validation and historical revision policy remain pending. This prototype neither loads an old save nor changes today's compatibility contract.

## Portable-state review before implementation

Source inspection of runtime032926f identifies the following boundaries. This is a review checklist, not an implemented field whitelist:

| Source | Destination requirement |
| --- | --- |
| Checkpoint.player and world_map | Reposition at a verified Preserve retreat/spawn; retain exact original pose, retreat, seed and revision in the archive. Do not carry old collision coordinates into the new habitat. |
| roots.needs | Preserve reserves and complete food/grant accounting, using NeedsModel's record checks. A completed meal must neither disappear nor become creditable twice. |
| roots.life.growth | Preserve stage, fedSinceMoult, ready status, moult/soft timers and tuning flags. Run/lock derive from stage; do not turn recovery into an extra moult or relock an earned ability. Exuviae positions are historical spatial data: archive them and decide their destination representation explicitly. |
| roots.life.clock and life_rules | Preserve age/day/hour and mode/rules, including gentle semantics; no rejuvenation or silent difficulty change. Preserve valid moult/rest timing while releasing incompatible spatial attachments. |
| roots.life.grantedSeen and meal bookkeeping | Keep the ledger cursor aligned with preserved needs/grantedTotal. Do not replay a feed event during import. Only supported rest boundaries are eligible; arbitrary held prey stays unsupported. |
| roots.life mating/rival/mate/nature/rare state | These are mixed history, counters and spatial actors. Enumerate actual serialized fields before projecting; do not copy the entire LifeLoop into fresh ecology or reset historical counters by constructing LifeLoop.new. |
| roots.prey and garden | Retain the entire source graph in the archive. Create destination populations from Preserve authoring, with explicit provenance and ownership. Home-prey graph compatibility and food/capture identities need proof too; matching region name sill alone is insufficient. |
| roots.sensor and memory | Clear transient geometry-dependent contacts in the destination. Preserve all source perception/memory in the original archive. Notebook discoveries are handled separately through progress. |
| Checkpoint wasp/cat/water/breakaway | Treat world-dependent actors, attachment and falling-leaf positions separately from lasting counters. Archive exact originals; explicitly specify destination initialization. |
| SaveProgress payload | Preserve notebook.opened, eye_seconds, finished_main, appearance, settings/settings_version, intro_seen, hut_window and rare high-water marks through existing sanitization/merge rules. Import must not reset the rare ledger and repeat a once-only sighting. |
| SaveRest/save_life, SaveSession and store metadata | Continue the same authorized life and source slot. Respect retirement, lease, revision and pending-intent fences; no Fresh call as a shortcut. Keep all modes' original rests/backups and progress records in the recovery archive, not just the selected checkpoint. |
| LifeSession deaths/lives/summary | These are currently session-only fields, outside durable Checkpoint/SaveProgress. Do not promise recovery of data the original save never stored. Preserve any session data present during an in-session conversion without silently claiming durable history exists. |

The selected policy says complete original save, so the archival unit includes original progress and every available rest/backup envelope, with per-slot status/provenance, rather than just a sanitized projection of the selected rest. Corrupt or newer slots must remain opaque exact bytes when available, never be silently sanitized into an apparently healthy archive. Import only independently validated compatible data. Missing source data must be described as missing, not manufactured.

Storage bounds remain real: SaveRules allows5,000,000 expanded rest characters/600,000 values/depth24; server compression separately caps the stored envelope including backup at1.5M characters and bounds expansion at12M. The archive format/location and lifetime require a tested bounded design. Do not just append a complete multi-slot archive to every checkpoint and assume it fits. Atomic conversion must retain originals when the archive cannot be durably preserved.

## If importing: preserve the whole source graph

The roots are not independent bags. The garden shares feeding/needs, captured-object references and observation references with other roots. Removing garden entries or copying only selected objects is not a lossless operation. The source must remain a complete validated checkpoint graph with its original world identity, payload checksum and format metadata.

A proposed archive should contain one complete immutable source checkpoint, not a recursively growing chain of successive current saves. Preserve exact source bytes or a demonstrably reversible representation. Keep source/schema/world/revision/seed provenance separate from the destination record. Repeated destination saves must retain the same source archive without rewrapping themselves. Cancellation, new life, deaths and backup recovery must never silently remove it.

The portable projection must be enumerated field by field before coding: spider/growth/reserves, clock/life rules, lineage/progress/notebook records and completed feeding ledgers. Identify which data lives outside Checkpoint in session/progress slots. Do not reset completed meals, grant meals twice, revive an ended life, reroll inherited appearance, mix identities between lives, or carry transient perception/targets into incompatible geometry. Retain any unavailable information in the original archive rather than discarding it.

Initialize destination ecology from the destination's own authors and rules. Never relabel source region ids as destination ids. State clearly whether destination home prey is restored compatibly or newly initialized, and prove the choice against graph references and meal de-duplication. Rest recovery must preserve existing life-token/lease authority; calling Fresh would durably retire the old life and is not a substitute for Continue.

Any new format needs an explicit schema migration. Older readers must refuse and preserve it safely. Do not reinterpret future schemas. A new archive must have bounded encoded/decoded sizes, object counts and nesting, and exact checksum validation. Respect online compressed-envelope and backup caps. Over-cap conversion must refuse atomically and retain the source, not truncate it. Validation must cooperate with SaveWork; immutable-string memoization, if considered later, needs bounded ownership and exact-content proof.

## Prepare/commit boundary

Prepare source validation, private archive, portable projection, destination ecology and candidate checkpoint off the live roots. Keep prior rest/backup visible until one successful commit. Use the existing intent, generation, store identity/revision, cancellation and life-token fences. Reuse decoded ownership carefully; do not decode once for validation then apply an unchecked second decode.

Before apply, verify the exact source slot is still current. On cancellation, refusal, stale authority, schema mismatch or disk/network error, leave live roots and source bytes unchanged. Do not report Saved, kept, migrated or restored before the corresponding operation succeeds. Local useful recovery and durable backend acknowledgement remain distinct.

## Minimum evidence before release

- A real historical fixture with populated ecology and cross-root references; not only an empty garden.
- Two-world/revision/seed interleaving with unchanged live-map identity.
- Field-by-field portable projection and exact archived-source round trip.
- Capture/restore/capture again without archive growth, relabelling, double feeding or loss of original bytes.
- Backup-only, corrupt/newer/oversized source, cancellation and stale intent/store/life tests.
- New-life/generation/retirement rules that explicitly describe archive lifetime.
- Native local Continue on actual engine objects, followed by isolated durable save/rejoin verification when user-enabled Studio API access permits it.
- Current full Windows/Linux, compile/strict and release preflight. Native test packages must not be published.

Keep this work separate from the current streaming fixes until their verification closes. The recovery policy is resolved; the evidence above is still required before calling migration implemented or safe to release.
