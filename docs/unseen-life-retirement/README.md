# Refuse retirement of a previously unseen life

Branch `codex/unseen-life-retirement`, source `5760c67627449de61fc18801007a3739ff0cc75b`, based on `e066c6b`; evidence `3ef9d94e5cae48bf`. Unpublished. This follows the shadow-cleanup fix; its preceding native gate is still pending too.

A06 includes both the hidden Continue interface and safety after delayed ownership. This patch addresses a reproduced overwrite in the latter; it does **not** finish the Continue interface.

## Problem and result

A visitor finds the owner's live progress lease, so it cannot read the rest. It chooses New Life locally, queues a retirement, then eventually obtains the lease. `readRests` adopted the newly discovered life token and allowed that old intent to retire the stored rest. This happened both when the original rest stayed unchanged and when the owner started and saved a newer life before leaving.

`beginLife` now records whether the slot had been read at the moment of intent. If a later successful read discovers a foreign stored record for an unobserved intent, the session becomes read-only for the rest of this visit, with the existing other-session warning. It never acknowledges that retirement or writes the queued local life over the discovered one. There is no automatic retry that can later erase it. Local play can continue; returning in another visit loads the stored life. Missing slots can still acknowledge an early New Life. Own retirement markers retain the existing idempotent response path. This is a conservative safety response, not a new resume-consent protocol.

Only production `Shared/Persistence/SaveSession.luau` changes. No save format, schema, remote message, control, menu, settings, feeding, creature or lighting changes. The flag is session-local and never serialized into a rest.

## Evidence

The exact same expanded `state.luau` on the old module reports **733 passed / 8 failed**, exit 1. On the candidate it reports **741 passed / 0 failed**, exit 0. The new cases check the original stored bytes including backup after both immediate and delayed retries, no retirement acknowledgement, read-only conflict, the owner's newer life, and a genuinely empty slot. Existing lost-response, superseding-intent, stale-token, equal-timestamp, corrupted-slot, shutdown and randomized two-session tests remain in that suite. This is synthetic backend verification, not a live DataStore or client rejoin.

`baseline-process.json` and `candidate-process.json` fingerprint all 216 production inputs and the shared test file. `verify.py` checks that only SaveSession differs, the test hashes match, the candidate's actual worktree bytes match, compilation 216/216, strict analysis, five runner checks, production XML fingerprints and rejection of the test artifact. The rebuilt production XML SHA-256 is `d67463411894e09d3fe89ebf82f0c03696e0e2ccdaf656c32421e5268190c79e`.

Full Windows exec session **85596** and exact-source Linux CI **39781688244** are live pending gates. Poll the existing handles; do not restart on an observation timeout. Leave source/tests fixed until the Windows runner terminates. Expected full totals are 64 suites / 443,833 checks (17 more than the preceding source). Do not claim completion until actual output and exit agree. The native gate is unverified; no diagnostic was published and no production DataStore was touched.

## Next

Retain the complete full-run logs after terminal exit and fetch actual exact-source CI results. Continue the native shadow check once Studio has enough memory. A06 still needs a safe preview/Continue protocol: an immutable observed rest identity, explicit resume/new-life intent bound to it, revalidation after gaining the lease, and stale/delayed message tests before enabling writes. Simply reading rests during another owner's lease and adopting a later token can relabel a running snapshot and is not safe. No menu should expose that incomplete path yet.

Other open foundation work remains: legacy-world migration/archive policy, deterministic AI preparation/activation, startup failure handling and production/device/comfort/performance checks. The overall optimization goal remains active.

## Follow-up discovered during the full gate

The bounded `known-life-probe.luau` uses real SaveSession/MemoryBackend with valid retirement records. A visitor first owns and reads one life, lets its lease expire, another owner stores a different life, then the visitor chooses New Life before learning that it lost the lease. After delayed reacquisition, the present guard still allows it to retire that different life: `preserved=false ack=true state=active`, exit 1. This is distinct from the previously unread slot and is **not fixed by source 5760c67**. The source-bound output is `known-life-baseline.txt` / `known-life-baseline-process.json`. Its runner changes only the temporary bundle body, not source/default tests or the ongoing full-run inputs. A helper initially expected no trailing bundle newline and stopped before execution; its assertion was corrected to match the actual bundler before this result.

The next change must bind the intent to both observed life identity and stored revision, check that binding before adopting a newly read slot, preserve own ambiguous-response idempotency, and keep the atomic write-time checks against later changes. Add a failing default regression covering a real newer checkpoint, legacy nil identities with changed revisions, identical unchanged observations, and the existing empty/unknown/ambiguous cases. Wait for the currently live Windows handle to terminate before editing source/tests; its receipt remains useful for its exact intermediate source but cannot establish this follow-up as resolved. Publication remains refused.

## Linux full gate completed

CI **39781688244** completed successfully for source **5760c67627449de61fc18801007a3739ff0cc75b** at 2026-10-22T13:04:19Z: **64 suites / 443,833 passed / zero failed**, 216 compilations, strict types, all four download checksums and five runner regressions. Actual metadata and raw logs are retained as `ci-final.json` and `ci-*.txt`; the verifier confirms their source and hashes. Windows session **85596** remains live. This green intermediate source does not fix the separately retained known-life reproduction; its follow-up is source **6026d6c45fbad072c2bec14a3b893fb8e7abccc2**, branch `codex/observed-life-retirement`, with its own gates. No release claim.

## Windows gate terminal result

Exec session **85596** completed with exit zero: **64 suites / 443,833 passed / zero failed**. Its closed log was normalized to LF after termination and retained with the actual process receipt. `verify.py` confirms both full Windows and Linux gates for this intermediate source. It is still unpublished, lacks a native result, and retains the separately proven known-life overwrite; the stronger successor source is 6026d6c on `codex/observed-life-retirement`. Do not restart this completed handle or promote its green checks as proof of the successor.
