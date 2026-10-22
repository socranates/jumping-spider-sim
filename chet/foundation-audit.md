# Foundation audit: first findings and small fixes

Baseline: **v51, published place 140**, gameplay source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, evidence `d9ddc5e0ed43d301`.
Candidate: branch **`codex/foundation-audit`**, source `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence **`c7af2726574c44cc`**. **Not published**; v51 / place 140 remains the last verified release.

Nathan, the biggest problem is saving after substantial exploration. The game keeps the wildlife state of places you visit, and that can grow beyond the online save limit the game currently allows. I reproduced it without touching your saved game. I have made the game report that refusal honestly, but making those large saves fit safely is the next foundation job.

The ten findings, in priority order:

1. **Large explored-world rests are rejected.** The stress probe reached 2.28 million characters; the game's cap is 262 thousand. Raising it is insufficient because a full backup also needs room. The small fix reports the problem and preserves the previous online rest; the underlying size problem remains.
2. **Some tests could fail and still report success to CI.** Fixed the six missing failure exits, missing-file skips and temporary-file cleanup. The old v48 HUD expectations had already been corrected before this audit.
3. **Old garden saves can be rejected by the preserve.** A genuine old-world rest passed its original validator, then failed on the current map. That needs migration, not deletion or a guessed replacement.
4. **New Life is only local until a new rest reaches the server.** Leaving immediately can bring back the previous life. Decide whether starting over should retire it immediately; the implementation needs a safe online acknowledgement.
5. **An overlapping or abruptly disconnected session can temporarily hide Continue.** The previous session's lock protects the save, but the new session does not offer its rests while waiting. A normal clean exit does release the lock.
6. **Predator route preparation can affect timing across machines.** The graph is seeded, but readiness depends on real elapsed time and render frames. Fix this with deterministic activation and trace tests, rather than changing predator behavior casually.
7. **Performance needs measured follow-up.** Whole close-look construction and near-detail rebuilding are plausible hitch sources. Existing long-traversal receipts are not evidence of smooth frame rates. The eight matched benchmarks and long memory run remain to complete.
8. **Empty wildlife regions did unnecessary geometry searches.** Fixed. The regression avoids 2,000 scans while retaining the streaming safety gate for real populations. I am not claiming an FPS number from this check.
9. **CI did not explicitly enforce the unoptimized compiler guard.** Fixed; all 215 current source modules compile at `-O0` locally.
10. **Passing CLI tests cannot prove native controls, streaming, sound, phones or online persistence.** Those still need their own receipts. Studio initially crashed while the PC was almost out of virtual memory; after closing completed audit sessions, a clean session opened the candidate and matched all 215 source fingerprints.

The liked movement, camera, jumping, lighting, creatures, feeding rules, minimal HUD and seven/ten-fly moults are preserved. Only four game modules changed: PreyWorld, SaveSession, SaveRules and SaveText. There is no new rare creature in this round.

## Foundation health

| Area | Verdict |
|---|---|
| Correctness | Preserve regressions are valuable, but large/legacy saves need work before more content. |
| Performance | One unnecessary scan path removed; no measured FPS gain claimed. Benchmark/memory work remains. |
| Security | Reasonable corruption protection for the deliberate solo client simulation; no anti-cheat claim. |
| Code | Strict source with a clean dependency inventory, but twelve large modules and a large client orchestrator. |
| Tests | Windows and Linux each pass all 60 suites / 443,102 checks; all 215 source modules compile at -O0 and strict analysis has no source diagnostics. Foreground native self-test: 274 passed / 0 failed / 0 skipped, source fingerprints 215/215. |
| Content/accessibility | Standing design preserved; exhaustive native accessibility/audio/science review remains open. |
| Release process | Separate branch and source fingerprints; do not publish or merge while release gates are incomplete. |

## Next work and Claude handoff

Read `docs/audit/FINDINGS.md`, then `SECURITY.md` and `TESTS.md`. `MAP.md` indexes every source module and all 233 region generators; full details and raw logs are in `docs/audit/`.

Small commits:

* `ac231a1`: A03, absent-spec readiness scans.
* `65cb4bd`: A01/A09, test runner/failure exits and compiler guard.
* `5ee048a`: A02, rejected-rest status and regression tests.

The next coding chunk should compact the persisted ecology and introduce explicit legacy-world migration. Preserve every actor's seeded stream/state and existing checkpoint identity. Keep old readers/fixtures and prove round-trip continuation across the complete preserve. Avoid a multi-key DataStore redesign unless a compact single-value format cannot meet the measured bound. Do not silently discard visited wildlife, steal session locks, change player mechanics or overwrite unreadable/newer saves.

Keep main and historical branches untouched until integration is chosen. Do not split SpiderClient, replace the renderer, reduce lighting or add more rare content as an incidental optimization. The larger proposed changes are recorded for a separate decision, not performed by this patch.

Nathan also requested research into ray-traced audio. `docs/audit/RAY-TRACED-AUDIO.md` recommends a separate wasp-in-the-hut experiment using Roblox Acoustic Simulation, with explicit geometry, listener and device-performance checks. No audio code changed in this candidate.

This completes the first source audit and small-fix pass, not the exhaustive manual/performance matrix. Native's short sill sample averaged 17.6 ms (57 FPS); it is not a controlled comparison or a promise for the whole preserve. Eight paired scenes, long memory trace, physical devices and real online restore remain open. `docs/audit/receipt.json` records these boundaries separately from the passing correctness checks.
