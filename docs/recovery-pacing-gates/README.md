# Initial recovery pacing adoption withdrawn

The first adoption was uncommitted and was withdrawn after the regular state suite reported1250 passed/2 failed: callbacks for retained, unverified slots were delivered alongside the one refreshed slot. Production was restored byte-for-byte to f405359, whose76 suites/468225 checks pass on both platforms. No new full run or publication started. The old adoption script is disabled by the withdrawal receipt.

A replacement candidate now requires restLoaded before delivery. The callback harness records failures before throwing, so protective callback error handling cannot hide them. The stronger harness rejects the superseded20f59026 candidate and passes83 checks against the replacement, whose44 yielding checks also pass. Corrected integration, seven save regressions, types and native requalification are tracked separately; do not use earlier native126 as qualification for the replacement.

The initially prepared runner/verifier below concern the withdrawn adoption and must be replaced before a new full cohort starts. Original planning below is historical.

The exact Studio-tested SaveSession20f59026 module has been adopted, with126 regression assertions added to state.luau. Periodic recovery makes at most one backend request per worker pass, fairly retries slots, promptly delivers merged progress and refuses late results after closure, demotion or a superseding load. Schemas and gameplay mechanics are unchanged.

The preceding f405359 freshness cohort is fully verified: both platforms76 suites/468225 checks/0 failures, compile222, strict and runner5. Its Windows95443 process is terminal. The new cohort expects76 suites/468351 checks/0 failures, including STATE1250/0; these expectations are not full gate results. The immutable full runner refuses a duplicate log and requires the prior cohort to be terminal. CI is the single exact-source push run, not a manual rerun.

Private candidate evidence:82 focused/44 yielding checks,1624 across7 unchanged save suites, compile/strict clean, and126 native/224 fingerprints/zero errors. Source-bound native diagnostics used MemoryBackend/frozen checkpoints and disabled all production scripts. They were stopped/saved/closed/exited and original bytes restored. Failed setup and previous counterexamples remain retained. No actual DataStore, rejoin, full game transport or migration-completion claim.

Current source/process/run metadata is recorded beside this document after commit/dispatch. Root verification refuses absent terminal receipts. Nothing published. Main/laptop integration and the broader historical migration/lifecycle/streaming/device/memory/performance/release work remain open.
