# New Life consent follows the observed save

Branch `codex/observed-life-retirement`, source `6026d6c45fbad072c2bec14a3b893fb8e7abccc2`, evidence `95802440d548b8c2`. Isolated checkout `C:/Users/natha/windowsill-observed-life`; the predecessor's Windows runner remains in `C:/Users/natha/windowsill-publish`. Unpublished.

## Problem and resulting behaviour

The earlier unread-slot guard did not cover a visitor who remembered an old life, lost its lease, and chose New Life before learning that another owner had stored a different life. On reacquisition the session adopted the new token and retired the different save. The separate small reproduction on the predecessor reported `preserved=false ack=true state=active`, exit 1. The identical probe now reports `preserved=true ack=false state=session`, exit 0.

New Life now captures the slot's observed flag, life identity, timestamp and validated stored checksum. A later read must still match that observation before it can authorize retirement. A foreign record that differs makes this visit read-only with the existing other-session warning; its retirement is not acknowledged or automatically retried. Unread foreign slots remain protected. A genuinely empty slot and an unchanged observed slot can still proceed. An ambiguous earlier write from this same session can be acknowledged idempotently; a superseding local intent still supersedes an earlier one.

The atomic rest-write callback also compares the expected stored checksum before replacing a foreign envelope. This catches changed contents even when timestamps and legacy nil identity tokens match, including a change after the read. The existing life/time, malformed/newer-slot, ownership and backup guards remain. The checksum is the game's existing integrity identifier, not a new cryptographic ownership credential. The backend's synthetic cases are corruption/concurrency safety checks, not an anti-cheat guarantee.

The revision table contains at most one existing checksum string per save slot. It updates only after successful reads/writes. New comparisons use the already validated envelope's checksum and the already constructed write result; no new whole-checkpoint scan, per-frame work, save format or remote protocol was added. Only production `Shared/Persistence/SaveSession.luau` changes. Menus, controls, feeding, fly/creature rules, settings and lighting are unchanged.

## Verification

The same expanded default `state.luau` on predecessor production code reports **760 passed / 9 failed**, exit 1. The candidate reports **769 passed / 0 failed**, exit 0. Added cases cover all three save modes, a real newer checkpoint and its retained backup, changed legacy nil identities, unchanged consent, ambiguous own-write acknowledgement, equal-time changed payloads and the atomic callback after the original read. These regressions fail the default runner on error.

Client/server save integration: **162**, offline client **8**, rest storage **14**, compression **57**, all zero failures: **241 more checks / 1,010 across five targeted suites**. Compilation **216/216**, strict types and five runner regressions pass. The rebuilt production XML hash is `fc5ed3dd88a83705507dcb020910ba358b938a41fa666735282a1a7b1e954bd8`. `verify.py` binds these actual inputs to the committed source, checks the shared probe/test hashes, every compilation fingerprint and the release's exact 216 script fingerprints, and rejects the test artifact.

The `intermediate-time-only` directory retains an earlier uncommitted timestamp-only iteration (766 checks) and its source. It is not the final candidate evidence. Final receipts are the top-level baseline/candidate, integration, compile/type/build/runner and known-life-candidate outputs.

Linux CI **39783315341** is confirmed live for this exact source. Full Windows for this source has not started: run it after predecessor session **85596** reaches a terminal result, keeping local full runs serial on this memory-constrained host. Expected totals: **64 suites / 443,861 checks** (28 more than the immediate predecessor). The prior source's Windows session **85596** and CI **39781688244** must finish and be retained on their own branch; they cannot establish this changed-source gate. Do not restart a live job after an observation timeout. No native result, live DataStore verification, FPS benefit, publication or release readiness is claimed.

## Remaining scope

A06 is not complete: safe read-only Continue needs an immutable displayed rest identity, explicit user intent bound to that identity, revalidation after lease acquisition and stale/delayed response tests. This safety patch preserves data and local play while refusing an unseen/changed retirement; it does not introduce that interface. Returning in another visit can load the preserved save. A conflicted visit may leave its recently acquired lease to expire, as existing demotion does; this conservative delay is not a Continue UX fix.

Native shadow lifecycle and save-session verification remain pending while Studio has insufficient memory. The prepared shadow diagnostic belongs to its earlier source, not this candidate; never publish a diagnostic. Broader legacy-world migration/archive policy, deterministic AI activation, startup robustness, standalone/device/comfort and performance verification remain. The full optimization objective stays active.

## Combined native diagnostic prepared, not executed

`C:/Users/natha/claude-xfer/Windowsill-observed-life-native-v1/Windowsill-observed-life-review.rbxlx`, SHA-256 `7f127432ab6fcb470fb8dd68c8d7552b33c0693a7642fe404b681c7b9cc39282`. The builder verifies all 216 production blobs against source 6026d6c and adds one diagnostic module: 217 guarded fingerprints. Production Persistence is disabled. The manifest, pre-Play guard and unoptimized compile receipt are retained here as `prepared-native-*` and `native-compile*`; `verify.py` proves preparation only. Never publish the diagnostic.

The local test first runs seven real-Instance shadow lifecycle cases on this source. It then captures actual native preserve checkpoints for Normal, Free and Easy, without switching WorldMap, and runs the eight default retirement regression cases (45 assertions) against fresh synthetic MemoryBackend instances. It does not use an online DataStore. Neither this preparation nor those synthetic session cases establish automatic network streaming, an actual client rejoin, phone performance, frame time or accessibility comfort.

Once Studio has enough memory: open this exact local file, inspect its title, run `prepared-native-guard.luau` in the edit Command Bar, and confirm `[FOUNDATION_NATIVE_GUARD]` for this source /217/ persistence disabled before Play. Retain its actual seven SHADOW_CLEANUP_CASE markers and SHADOW_CLEANUP_DONE plus eight OBSERVED_LIFE_CASE markers and OBSERVED_LIFE_DONE with 45 checks, without FAIL/CreatorError, in `native-events.txt`. `verify.py` will only mark native execution verified after those actual records exist; `--require-full` additionally requires both full CLI gates. Stop Play afterward. If Studio serializes the review file, archive that serialization and restore the original bytes after closing; confirm its original hash. No native run has been claimed.

## Current full-run checkpoint

The predecessor's Windows session 85596 and Linux CI 39781688244 are now both terminal successes: 64 suites /443,833 passed /zero failed each. Their historical receipts have been brought onto this branch as documentation-only commits; production source and default tests did not change.

The full Windows run on current source 6026d6c has now started in **exec session 55171**, after the predecessor terminated. It writes `windows-full.txt`; the process receipt appears only after exit. Expected actual totals are 64 suites /443,861 checks. Poll this exact handle, do not restart on a timeout, and leave source/default tests fixed while it bundles its remaining suites. Current-source Linux CI **39783315341** is also live. Preparation of the combined native diagnostic is verified, execution remains unverified. No publication.

## Current-source Linux gate completed

CI **39783315341** completed successfully at 2026-10-22T13:11:14Z for exact source **6026d6c45fbad072c2bec14a3b893fb8e7abccc2**: **64 suites /443,861 passed /zero failed**, checksum verification for all four tool inputs, compilation216, strict analysis and runner5. Actual metadata/logs are retained in `ci-final.json` and `ci-*.txt` and checked by `verify.py`. Windows session **55171** remains live; native execution and publication remain unverified. The broader current audit scope is indexed in `docs/audit/CURRENT.md`; original audit counts are historical.

## Current-source Windows gate completed

Exec session **55171** terminated with exit zero: **64 suites / 443,861 passed / zero failed**, matching Linux CI39783315341 on source6026d6c. The complete closed log was normalized to LF after termination and retained with its actual process result. `verify.py` confirms both full CLI gates; no current full runner remains live and this handle must not be restarted. The source and default tests remained fixed throughout. Native execution, actual online rejoin, current device/performance verification, legacy-world restoration and safe foreign-lease Continue remain incomplete. No publication or overall-completion claim.
