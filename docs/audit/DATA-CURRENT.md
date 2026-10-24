# Current candidate save data and ownership

2026-10-23. This is a reconciliation of the private integrated candidate, not a
change to a save or a release declaration. The exact 273-source model is
`Windowsill-menu-overflow-attempt1/TheWindowsill-candidate.rbxlx`, SHA256
`bf77f6c885237f14fd274cf4c419300a88507d876c3cf780824b18d9ca2577d9`.
The [source inventory](integrated-source/inventory.json) binds every module hash.
Module names below refer to that staged tree, not the unactivated production
tree in this checkout. The earlier [DATA.md](DATA.md) remains historical.
The [current world map](integrated-world/MAP.md) and its inventory JSON replace
the historical generator-count table for this candidate, including backdrop
zones and near-detail patches as well as walkable regions.

## Important corrections to the historical report

- Base rest envelopes are schema **2**, not 1. Preserve's integrated reader and
  writers additionally understand schema **3** recovered and continued rests.
- The checkpoint inside an envelope has its own schema **3**. These version
  numbers belong to different records and must not be treated as one version.
- Compression is a separate outer schema **2**, encoding `zstd-base64-2`; its
  `innerSchema` identifies the logical envelope. Outer 2 can carry inner 3.
- Expanded checkpoint validation allows 5,000,000 canonical characters,
  600,000 values and depth 24. The stored compressed value, including backup,
  has a separate 1,500,000-character bound. The old 262,144/120,000 description
  is obsolete for this candidate.
- Legacy Test Garden recovery is integrated in this candidate. It imports
  portable spider progress into the Preserve and preserves original raw saves
  in an immutable archive; it does not recreate the old garden ecology.
- `MAX_PROGRESS_CHARS=16384` remains declared in SaveRules but is not a universal
  enforced limit. The packet/current recovery progress paths explicitly use
  32,768 characters. Do not introduce a 16K rejection as a documentation fix:
  the supported lossless union can exceed it.

## Engine and request ownership

`Server/Persistence.server.luau` is the sole engine save entry point. It owns
the remotes, player join/removal and shutdown hooks. For the Preserve it waits
for the authored collision world, builds RecoveryTemplates, then constructs
RecoveryStartup. The frozen Test Garden keeps BaseService's ordinary path.

RecoveryStartup owns one RequestAdmissionGate, RecoveryAccountLifetimes and
ReplacementService/ReplacementOwner composition for ordinary and recovered
Preserve sessions. Application rolling bounds are actor read/write 160 each,
server read/write 320 each, with two units of observed platform headroom. These
are application limits, not Roblox quotas. Actual StandardRead and
StandardWrite allowances are observed separately before dispatch.

Preserve's service is stepped on Heartbeat to advance bounded work and I/O;
the old Test Garden scheduler is stepped at most once a second. Shutdown
disconnects the loop, closes the template catalog and calls service shutdown.
The old report's blanket once-per-second description does not cover Preserve.

DataStoreBackend owns physical SDK calls and rest compression. Explicit fresh
reads use `DataStoreGetOptions.UseCache=false` and destroy the options even on
failure. Raw recovery reads preserve the stored representation before decoding.
RecoveryRawBackend is used for exact raw compare-and-swap; a logical decoded
comparison is insufficient for replacing an original source record.

## Persistent keys and transport

| Family | Contents and ownership | Readers / validation |
|---|---|---|
| `P_<owner>` | Global progress envelope and its session lock; ordinary and recovery progress coordinators | SaveEnvelope, SaveProgress, progress projection/reconciliation; owned lease and fresh readback before required acknowledgements |
| `R_<owner>_<slot>` | One rest per `main`, `easy`, `free`; active checkpoint or explicit retirement, possibly schema3 recovery wrapper | SaveRest base spec, RecoveryPacket/RecoveryRestFormat current spec, Checkpoint; slot, life identity, metadata, bounds and codec checks |
| `A1_<owner>_<slot>` | Immutable original raw `progress/main/free/easy` observations, including original backups and explicit missing records | RecoveryArchive/ArchiveStore verify owner, observation, checksums, exact descriptors and durable raw readback |
| `A1_<owner>_index` | Archive manifest identifying the complete four-slot source set | Pipeline and entry authenticate all required archive parts against it |
| `M1_<owner>_<slot>` | Immutable import proposal, exact encoded target and original archive/source binding | ProposalStore and RecoveryPacket.open; closed fields, checksums, codec and exact scope; retries reuse persisted bytes |

No multi-key transaction is implied. Durable archive, immutable proposal,
selected-rest replacement and progress absorption are separate operations with
uncached verification and owner/intent/session fences. An interrupted response
must resume the same proposal or refuse; it must not allocate another identity
or erase original data. A successful packet parse alone grants no play/write
authority.

The normal production store name is `Windowsill_v1`; Studio/test selection uses
`WindowsillTest_v1` or an allowed explicit test name. The pending private-player
candidate uses `WindowsillTest_player57_20261023a1` and fresh
`t<server os.time>_<UserId>` owners through the empty PortTests identity marker.
These names are different test scopes, not interchangeable evidence. The
terminal real-storage qualification actors must never be reset or replayed.

## Logical fields, writers and readers

| Record | Fields / meaning | Writer -> reader and checks |
|---|---|---|
| Envelope | `format, kind, schema, updatedAt, payload, checksum`; optional previous core `backup`, `lock(session,beat)`, `session` | SaveEnvelope.make/core and owned save writers -> SaveEnvelope.open/spec; canonical checksum covers kind/schema/time/payload, not lease metadata. Integrity checksum is not authentication |
| Progress schema2 | `notebook(opened,eye_seconds), finished_main, appearance, settings, settings_version`; optional `intro_seen, hut_window, rare` | SpiderClient progress snapshot -> SaveClient -> SaveProgress.sanitize and appropriate owned coordinator -> persisted envelope; client reads validated payload on handshake/Continue |
| Rare ledger | `serial, claimed[id]=serial, once[id]=true`, optional `blocked` | Life rare events / recovery binding -> RareLedger.clean/merge; at most64 entries per map, serial<=1e9. Merge overflow fails closed with blocked; it must not permit another sighting |
| Base rest schema2 | Ordinary checkpoint with optional `save_life`, or only `save_retired=true, save_life` | Authorized life/rest coordinator -> SaveRest.spec; schema1 migrates without altering its checkpoint, invalid/reserved retirement fields refused |
| Checkpoint schema3 | Identity/version/time/tick, `player`, `world_map`, `world`, `life_rules`; optional `breakaway, wasp, cat, water`; storage life token added by save path | Checkpoint.capture -> CheckpointStore / client save -> SaveRest or current format -> Checkpoint.check/decode -> prepared fresh world -> restore/commit only after accepted entry |
| Player pose | `position, normal, heading, gaze_pitch, retreat_id, state` | Attached retreat capture -> finite pose, known location/state and world checks before restored motor state |
| World map | `seed, revision, region, retreat, diffs`, optional explicit `world` | WorldMap at capture -> recorded-world validation or current-world check; map revision migration does not imply arbitrary habitat compatibility |
| Object graph | `format=object-record-1`, named `roots`, `objects(c?, e)`; tagged refs/vectors/special values | ObjectRecord.capture with Checkpoint class/ref allowlists -> decode fresh objects -> world invariants -> commit; maximum20,000 objects, shared references/cycles represented explicitly |
| Graph roots | `prey, sensor, memory, needs, life`, optional `garden` | Current world roots -> capture/decode; graph preserves simulation object identity, not Roblox Instances or executable callbacks |
| Initial recovered rest schema3 | `format,version,id,owner,slot,archive,source,binding,checkpoint,progress,progressTime,entryKind,save_life` | RecoveryPacket preparation composes archived portable life, lossless global proposal and current destination -> frozen M1 -> authenticated entry pipeline |
| Continued recovered rest schema3 | `format,version,slot,provenance,checkpoint,entryKind,save_life`; retirement replaces checkpoint/entry with `save_retired=true` | RecoveryRestFormat.fromProposal/advance/retire -> owned writer -> format/metadata, checkpoint/history, generation/token/scene consistency checks |
| Recovery provenance | `version,owner,slot,proposal,archive,source,originLife,originGeneration,originBinding,historyChecksum` | Immutable proposal binding retained on later rests -> exact archive/proposal names, original source identity, history checksum, life token and generation checks. Continued rests cannot masquerade as ordinary schema2 payloads |
| Archive entry / index | Entry contains format/version/owner/slot, original presence/raw value and checksum; index contains the observation, entry descriptors and manifest checksum | RecoveryArchive prepares owned copies -> ArchiveStore publishes/readbacks -> entry/pipeline verify original data unchanged |

Progress sanitization bounds page IDs, page count200, eye seconds1e9, setting
types/ranges/version and rare ledger. Pages and monotonic flags are unioned;
eye time takes the maximum. Ordinary merge chooses appearance/settings by
timestamp. RecoveryProgressReconcile additionally uses an acknowledged baseline
and changed-field delta so concurrent choices and B->A reversions survive an
uncertain write. It does not blindly overwrite the latest global progress with
an old import snapshot.

## Bounds and compatibility

| Layer | Current bound / behavior |
|---|---|
| Ordinary expanded rest | 5,000,000 canonical characters, 600,000 values, depth24; finite plain values, no shared raw table references/metatables before graph decoding |
| Progress input structure | 1,500 values, depth8 for the explicitly bounded progress paths; sanitizer also applies field/cardinality constraints |
| Rest compression | 1,500,000 stored characters including backup; 6,000,000 bytes per core; 12,000,000 combined expanded bytes; declared frame size checked before expansion |
| Recovery packet progress | 32,768 canonical characters plus existing progress structure/cardinality checks |
| Recovery archive | 3,900,000 canonical characters per entry; 12,000,000 total including manifest; 600,000 nodes/depth24 |
| Base protocol | SaveRules.PROTOCOL2, offer opt-in3, recovery opt-in1; advertising offers is not accepting recovery authority |
| Future records | Unknown/future envelopes/transports and unsupported metadata are preserved/refused rather than downgraded and overwritten |
| Backup selection | Original primary corruption does not silently authorize importing its backup; backup choice is explicit and bound to the proposal |

Checkpoint schemas1/2 can add missing growth/granted fields under explicit
legacy rules; current malformed checkpoints do not get that repair. Recorded
world validation precedes portable import; current Preserve destination is
prepared separately. After import, later checkpoints preserve recovery history
and provenance. Retiring a life is a persisted identity transition, not deleting
the whole slot or archive. Slot/rules checks keep old gentle-main records in
their original main slot while new Easy lives use the easy slot.

## Evidence and remaining limits

The source map, [ordinary startup/rejoin proof](../normal-startup/ONLINE.md),
[current native suite](../native-integrated/README.md) and separately retained
CLI/protocol qualifications establish different scopes. The online proof uses
fresh synthetic keys, actual normal Continue and PlayerRemoving, and another
Studio process to verify continued schema3 records. It is not every historical
save, standalone publication or physical-device coverage.

This document reconciles record families, principal fields, bounds, readers,
writers and ownership. It is not a field-by-field semantic review of every
species/ecology object inside the object graph, an exhaustive historical save
matrix, a new storage test, or a claim of server-authoritative gameplay. Life
simulation remains client-authoritative for this solo game; structural save
validation protects data integrity and ownership, not honest client behavior.
