# Private original-archive reuse across save slots

An immutable original archive must outlive changes to the player's current lives. Previously the archive controller compared every current slot and the current progress payload to the initial source matrix. After recovering main, its current R was intentionally different, so importing an untouched free/easy original refused. Starting a fresh main life made the same mismatch permanent.

## Installation and authority

Set `recovery.pipeline.reuseCompleteOriginal=true` in the private Runtime dependencies. This activates complete-original reuse and read-only independent archive verification in the commit coordinator. The preceding strict controller/repair behavior remains the default for its earlier standalone callers. Production service/menu routing does not install this option yet.

Under the existing acknowledged owned P lease, the archive controller reads all five A1 publication records uncached and proves the complete original. The shared pure `RecoveryArchiveStorePrototype.checkPublished(owner, parts)` bounds every artifact and their aggregate, reconstructs the complete original matrix/checksum, and compares the exact anchor, all three entries and final complete index. Discovery now uses that same validator. Preparation is cooperative; no archive writes occur inside proof preparation.

For complete reuse, the controller freshly reads only the selected current R and requires it to match the archived original raw representation exactly, including its backup and metadata. It also checks the real selected primary/backup identity against the archive. Other current R slots are neither needed nor read by this controller phase. They may contain a recovered life, a fresh normal life or an unsupported record; their preservation does not depend on understanding them.

The commit coordinator independently rereads all five A1 records and validates them against the completed archive descriptor. It does not trust the preceding controller's descriptor as durability evidence and does not send no-op updates to original keys. Proposal insertion/readback, selected-R compare-and-swap, current P absorption, final witnesses, entry apply/grant, routine saves and departure keep their existing ownership/selection/request/deadline fences. Only the selected live R and owned merged P can change, plus insert-if-absent creation of that slot's own M1 proposal.

## First archive and partial publication

When the initial A1 anchor is absent, the controller follows the original bounded full-source collection/publication protocol. Its initial absence probe replaces the later redundant probe; insert-if-absent callbacks still refuse a concurrently occupied archive key. Every published part and the complete index must be verified before commit. The commit coordinator then independently reads the completed publication without updating it.

A missing final index cannot authorize selected-only reuse. That case returns to the preceding strict full-source repair path: every current original must still agree, apart from its permitted progress-lock metadata drift. A changed matrix refuses before repair writes. A corrupt completed publication or a missing part under an existing complete index refuses, rather than silently repairing or replacing an original.

## Lifetime and limits

The first complete A1 original remains immutable under its fixed per-user keys. Fresh lives and later-slot imports do not create another archive or prune the first one. Each recovered slot has its own immutable M1 proposal referring to that same original. Archive value/aggregate bounds and the three fixed mode slots keep this retention bounded; it does not grow with visits or generations. This preserves the full initial originals and backups, not an unlimited history of later checkpoints.

If the selected current raw R itself no longer matches its archived original, this route refuses. It cannot import a different later life into the fixed first-original archive or replay an earlier proposal over that newer live R. A supported fresh normal checkpoint follows normal Continue instead of this legacy-import route. Recovery of genuinely different later incompatible source snapshots would need a separately designed archive generation policy.

## Verification boundary

Final `archive-reuse-attempt-3-*` passes 19,110 new assertions plus 165,294 preceding assertions, 184,404 total with zero failures. Entry compilation and full strict analysis of all 33 candidates pass in `archive-reuse-types-2-*`. `verify-recovery-archive-reuse.py` binds current inputs, assembled bundle, outputs, type receipts and the unchanged narrow native budget-observer component evidence; `recovery-archive-reuse-verification.json` records its result. Attempt 1 detected the downstream commit coordinator still sending no-op A1 updates. Attempt 2 completed both later imports but caught an incorrect test comparison of a reason-string protection field with `true`. Both attempts remain historical evidence. The final future-slot test uses a newer-schema header and checks the actual `newer` protection reason. The new cohort includes a strict-path counterexample, main recovery followed by a fresh main life and later free/easy imports, preserved current settings/rare progress, untouched archive/existing proposal/other lives, changed selected raw data, corrupt/missing archive records, an unsupported unrelated current slot and revoked consent while an actual adapter read yields. The production adapters run against a fault-injected datastore facade, not online saves.

Trace assertions require zero A1 updates throughout successful later imports. The archive-controller trace also forbids reading unrelated current R keys. Each of the three successful reuse-controller traces uses eight requests and 63 simulated seconds. Printed request/timing figures cover that controller phase in the deterministic model, not player loading time or the full entry sequence.

This remains private. Actual SaveService/client/remotes/menu adoption, engine-native full lifecycle/compression, online datastore/rejoin, physical devices and release verification remain open. No production source, published game or normal player save is changed by this milestone.
