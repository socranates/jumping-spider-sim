# Callback audit: production preserved, replacement privately verified

Production remains f4053597d03b99a61cb97e2eef1ec64ed174f22a. Its full Windows/Linux cohort is complete:76 suites/468225 checks/0 failures on each platform, compile222, strict clean and runner5. Windows95443 is terminal. No full job remains active and nothing was published.

The attempted20f59026 adoption was uncommitted. Its normal state suite recorded1250 passed/2 failed: the reload worker delivered retained, unverified slots together with the one newly read slot. It was withdrawn and both production files restored byte-for-byte. The unchanged integration test now passes1250/0 with the corrected private candidate8ad013b9; exact failing/passing logs, test/source hashes and withdrawal receipt are retained under docs/recovery-pacing-gates.

The earlier smaller callback tests used assertions inside callbacks. SaveSession deliberately catches callback errors, so those failures could disappear from their test totals. The stronger harness increments a persistent failure counter before throwing and verifies that counter outside the callback. It now rejects the superseded candidate with two swallowed failures. The earlier native126 result remains an execution result under an incomplete harness and is explicitly not adoption qualification. The old adoption script and prepared cohort verifier refuse the withdrawn candidate.

The corrected candidate adds an actual restLoaded condition before delivery. It retains the periodic request budget, round-robin fairness, prompt merged-progress notification, retained observations and post-yield generation/closed/authority fences. Its evidence is bound by verify-session-verified.py:

- 83 callback-aware pacing/retention checks, including the persistent error check.
- 44 genuine coroutine suspension checks.
- 1624 checks across seven unchanged save suites.
- The unchanged integration fixture that caught the defect:1250/0, against1250/2 for the withdrawn source.
- Both module compilations, sourcemap and full strict analysis clean.

Production has not adopted the corrected candidate. A new native package is built but unrun: C:/Users/natha/claude-xfer/Windowsill-session-verified-f405359/Windowsill-session-verified-review.rbxlx, hash f28948911faf123c257d131ffe492a9c307001f5acdefcf5f2c2e09ed670ad91,224 sources. Expected native checks127 is not an observed pass. It disables all production scripts and enables only the correctness probe; never publish it. Native requalification and new full gates are required before the replacement is qualified/adopted.

No actual service durability/rejoin/full-game transport or migration-completion claim. Progress-into-Preserve/complete archive integration, natural lifecycle/streaming/device/memory/performance and release work remain open. Goal active.
