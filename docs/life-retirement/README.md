# New Life retirement — candidate verification

Branch `codex/life-retirement`; runtime source `5cf7b4c0f212082342574763aaf5b19e00c4e323`; evidence `b3b1a047e958d966`. Based on the verified, unpublished compression candidate. **Not published**. Last verified live baseline is v51 / place version 140; this candidate has not been published.

## Failure and behavior

Previously New Life cleared only the local checkpoint store. Quitting before the next rest could offer the old life again on rejoin. A queued older rest also had no life identity.

The client now sends a bounded, increasing `begin_life` intent for the selected slot, drops that slot's older unsent rest, and holds new rests until an acknowledgement arrives. The server writes a schema-2 retirement marker through its existing guarded UpdateAsync/backup path. It acknowledges only a confirmed write, including confirmation after a lost response. Retries are idempotent. A newer intent supersedes an earlier in-flight one. Status cannot claim Saved while the client waits for this acknowledgement.

Stored markers are `{save_retired=true,save_life=token}`. Normal stored checkpoints carry the same checksummed `save_life` metadata. The complete simulation record is retained. A retired slot offers no Continue, while other slots remain untouched. The previous checkpoint remains recoverable as the marker's backup; after a subsequent rest, the usual one-backup policy continues. Existing corrupt-record recovery remains read-only and may offer an earlier valid backup; this change does not erase recovery data.

The server refuses mismatched or unacknowledged life credentials before accepting a rest, rechecks stored identity inside the write callback, and keeps a session read-only if a different life won while ownership was unavailable. It never relabels an old queued world with a new identity after reacquiring a lock. Foreign locks and malformed, corrupt or future records retain existing protections. Client checkpoint messages cannot forge a retirement marker.

Schema-1 rest records migrate unchanged in memory. Older schema-1 readers refuse schema 2 as newer. The server-only compression format remains `zstd-base64-2`. Protocol 2 adds intent/ack and loaded life identities; legacy method callers retain the three-argument `setRest` API and cannot write across a later retirement boundary. The new service path uses `setRestForLife` explicitly. The pure SaveClient module is now included in the shared CLI bundle so the service integration test uses the actual transport implementation.

New Life / Another use the new boundary. Carry On / Follow continue the existing world and lineage under their existing checkpoint behavior. New Life confirmation wording now says that retirement happens when saving succeeds. No gameplay mechanics were rebalanced.

## Verification state

- Targeted exploratory run: **563 state checks, 154 client checks, 44 compression checks passed**. Earlier failing exploratory logs are retained and must not be presented as final acceptance evidence. The final guard also bounds root copying and refuses metatable roots before touching them. Full frozen-source results are recorded below.
- Latest strict analysis clean, with only tool startup/watched-file messages. Five Python runner regressions pass.
- Frozen source compilation: **216/216**, `-O0`, per-file hashes in `compile.json`.
- Full Windows run completed with exit **0**: **62 suites, 443,213 checks passed, 0 failed**. `cli-final.txt` and `cli-final-process.json` record its output and observed terminal exit.
- Linux run [39728136498](https://github.com/socranates/jumping-spider-sim/actions/runs/39728136498) completed successfully for exact runtime source: **62 suites, 443,213 checks passed**; compile/strict and runner checks passed. See `ci-final.json` and `ci-all-suites.txt`.
- Final local Studio review copy matched **216/216 source fingerprints** and evidence `b3b1a047e958d966` at 2026-10-22T05:30:20Z. The native codec/retirement probe passed at 2026-10-22T05:30:50Z using the 2,276,508-character actual-engine synthetic checkpoint and a local memory backend (227,282 native stored JSON characters after the new rest). The foreground preserve self-test passed **274 / 0 / 0** at 2026-10-22T05:40:09Z. `native-final.txt` preserves its source guard, readiness marker, codec probe, and full run. No CreatorError or script timeout was recorded. The earlier 814995d copy passed its native codec/retirement probe but its full preserve run was stopped for the boundary fix. `native-before-boundary.txt` is historical evidence only.
- The native probe uses the earlier actual-engine 233-region synthetic checkpoint with the real codec and SaveSession, backed by a local table adapter. It checks legacy read, durable marker/backup, quit/rejoin, stale rest refusal and exact simulation fields. It never accesses DataStoreService and is not online persistence evidence.

## Remaining release gates

All offline CLI/CI/native gates passed against unchanged source. `verify.py` recomputes the evidence hash and checks the receipts; `receipt.json` keeps publication readiness false. Verify real client/server persistence and larger played saves against an isolated online test namespace. Studio API access is still disabled. An Open Cloud key uses a separate external API and does not enable Studio permission; do not read keys from screenshots or paste them into handoffs.

The broader audit remains active: legacy-world transfer, overlapping-session Continue UX, deterministic route activation, caption projection, matched performance scenes and long memory/device traces. Native automated checks do not replace manual play and comfort/audio testing. Keep the rare-sightings expansion paused until the foundation is dependable.

## Local diagnostic boundary

`C:\Users\natha\claude-xfer\Windowsill-life-retirement-b3b1-native-review.rbxlx` contains a synthetic fixture and `ChetRetirementNativeSpec` outside the production source roots, with SelfTest/RetirementProbe enabled. **Never publish this review copy.** Release XML is generated independently by `roblox_port/tools/build.py`. Neither the fixture nor helper is part of the production source/build.

Reference: [Roblox Open Cloud DataStores](https://create.roblox.com/docs/cloud/guides/data-stores). The user mentioned an API key open on their laptop; no key was inspected or used.

## Interrupted and current runs

The initial 814995d Windows run (exec 67801) was intentionally stopped, exit -1, to validate stamped size limits and title-screen confirmation. Its log is `cli-before-boundary-fix.txt`. CI 39727205382 was intentionally cancelled (HTTP 202; subsequent API confirmed cancelled). Neither is final acceptance evidence. Final Windows exec **30676** exited 0 and CI **39728136498** succeeded; each covers runtime source 5cf7b4c and passed 62 suites / 443,213 checks.
