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
