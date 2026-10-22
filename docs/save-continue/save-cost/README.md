# Save-cost measurements: encoding is the next target

Sourceab8ca9577129e3d9583a0a8ab6824dae1a8cd014 is pushed on codex/save-continue. No production optimization was adopted during this investigation; nothing is published. docs/save-continue/verify.py passes, binding current source/tests/workflow, raw logs, historical failures, corrected Windows checks and current native fingerprints. All measurement jobs are terminal.

## Verification

- Linux39852128734:75 suites/444664 checks/zero failures, compile222/222, strict clean, runner5. Built-in shim self-tests end41/0/0 and274/0/0.
- Historical Windows87216 on immutable4ee6aec:75/444661/3, matching Linux. All three outer failures are the fixed-delay self-test return assertions and their downstream sound check. Complete log, input hashes and summary are retained.
- Corrected Windows67331: selftest5/0 and selftest_preserve7/0, internal41/0/0 and274/0/0. Exact input hashes match currentab8ca95. The old full cohort plus these corrected cases cover75 suites/444664 checks with only SelfTest changed. This is combined evidence, not a fresh single current-source full Windows run.
- Current native1792704319579:10 assertions,223 exact fingerprints, zero CreatorErrors between successful guard and PASS, PlaceId0/production Persistence disabled, no online transport. The broader native lifecycle, physical-device, online/rejoin and release gates remain incomplete.

## CPU attribution

The CLI profiler runs the actual controller against shim services, paused for repeatable local snapshots. Rows are inclusive, nested rows overlap, instrumentation adds overhead, and descheduling can inflate individual timings. Never sum nested rows or call these FPS results.

| Fixture | Record chars | Capture ms | Preparation steps | Preparation CPU ms | Max update ms |
|---|---:|---:|---:|---:|---:|
| Small garden first |18201|2.507|9|16.661|2.116|
| Small garden replacement |18340|2.092|11|20.568|2.168|
| Preserve first |2281656|124.363|1118|2606.020|86.582|
| Preserve replacement |2281801|140.940|1479|3453.706|64.592|

The initial profile used the small21-region test habitat. It is retained as a small-fixture result, not large-save evidence. preserve-profile.luau explicitly builds the preserve, awaits TitleReady, attempts all233 region initializations and requires a record larger than1M characters. Its record differs from the streamed native fixture; do not compare their timings as a causal speedup.

Native first/rest replacement records were1503075/1503219characters. First capture123.060ms; preparation692steps/1603.768ms CPU/12988.403ms elapsed/max36.943ms. Replacement capture97.212ms; preparation1064steps/2579.373ms CPU/18009.843ms elapsed/max60.322ms. Maximum Heartbeat gaps1269.288/1179.185ms are wider engine-frame observations, not attributable solely to worker code. This does not prove smoothness or a hard2ms frame bound.

Native replacement preparation called canonical encoding five times, taking1904.682ms of inclusive CPU; copying six times took357.458ms. Temporary removal alone copied the discarded entry and took57.515ms. Large CLI replacement agrees: five encodes/2592.446ms out of3453.706ms preparation. The measured primary target is canonical encoding allocation/repetition. Preserve exact output bytes, checksums, diagnostics, complete graph validation and atomic publication. Coherent capture remains synchronous to retain a single simulation tick. Consider a privately measured streaming encoder before changing production; do not skip validation or trust mutable cache identity.

## Native artifact and safety

Diagnostic: C:/Users/natha/claude-xfer/Windowsill-save-cost-ab8ca95/Windowsill-save-cost-review.rbxlx. Original SHA256353bc3bc0cc01a1fbd92a89e72ddf7d16b6057f0384774a16517cdec8fe660db. The diagnostic was stopped, saved, closed and its window exited; Studio's serialization is archived and original bytes/hash restored. A pre-existing stopped rig window94504044 remains untouched. No heavy CLI ran concurrently. No new Low System Resources warning was observed, but this was not a controlled hardware/FPS trial.233 initialization attempts were streaming dependent; resident ecology was not measured.

Six preflight CreatorError lines are retained separately. An older lexical costGuard in the persistent Node session shadowed the globalThis assignment, staging a stale47241c guard; no Play occurred under that guard. Direct scoped file loading and explicit globalThis state staged the correctab8ca95 guard, which passed all223 fingerprints without weakening hashes. The builder's marker was also corrected from LOCAL_RETURN to SAVE_COST, and refusal messages now include actual/expected values. CRLF normalization was already correct; an attempted normalization patch asserted before changing anything. Use unique scoped locals or explicit globalThis references for future UI state. Never publish a diagnostic place.

native-output.txt contains only bounded guard/probe rows. native-receipt.json and native-close.json retain source, probe/output/place hashes and exact metrics. collect-native.py is a one-time collector and preserves both XML serializations. Full engine/account logs are not retained.

Raw Windows CLI line endings are preserved in windows-raw-cli-outputs.zip. Tracked text uses LF so its receipt hashes survive Git checkout; the verifier checks the raw hashes and exact CRLF-to-LF transformation too. Future profiler output is normalized before hashing.

## Duplicate rig candidate deferred

The unused new rig-candidate harness duplicated docs/rig-cost's earlier16-case native experiment and was removed, recoverable from Git. Current SpiderRig is byte-identical to that trial's reference, SHA2565e6ee4dbe6a767e8aee987a3806c5d2e0c25f809ec54b356ec4d6a9640e6ad20. The event hash and raw timing means were rechecked. Full player walk gained only0.097ms/3.7percent in that isolated trial, a male case regressed, and probe timings were mixed. That does not justify adoption. See rig-prior-evidence.json and docs/rig-cost/RESULTS-v1e-trial1.md. No rig, fly, feeding or settings code changed.

The original28-item foundation audit remains open. Lossless historical-world restore, actual online/rejoin/device coverage, whole-game native performance and release/laptop synchronization are not established by these measurements. Goal remains active.
