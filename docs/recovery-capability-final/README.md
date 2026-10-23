# Terminal verification update

Both Windows and Linux passed76 suites /468859 checks /0 failures for257e1a4; the combined source/log verifier passed and the exact222-script candidate was built. Native/online recovery and release remain unverified. A new actual-client shim counterexample in ../player-stream-readiness/ now confirms player motion and hunger continue after streamed collision disappears. That targeted failure is the next correctness fix; full CLI success does not cover it.

# Recovery handshake and client transport: final source gates

Source under review: `257e1a43ae00076a6e59f284c0f2ca0ff09f72e9` on `codex/save-continue`. The initial implementation is `f205c4e`; this follow-up keeps a missing restore callback absent and fences recovery against every later global life choice. It retains the original normal-Continue copy behavior while preventing old-mode entry during a reentrant normal restore callback.

The contract and preliminary counterexamples are in [recovery-capability/README.md](../recovery-capability/README.md). Current source adds explicit recovery negotiation to the actual SaveService, SaveContinuation and SaveClient, a deferred protected-selection hook, entry dispatch and a bounded receipt method. The actual SpiderClient menu does not configure these callbacks, and engine startup does not install the recovery owner. The gates do not enable migration or publish the game.

## Current verification

Inspect the terminal receipts rather than inferring completion from start files:

- `checks.json`: all 222 production modules compile, clean strict analysis and five runner regressions.
- `private-type-inputs.json` plus `../save-slot-isolation/capability-types-2-*`: entry compilation and full overlay strict analysis of 34 private candidate modules. The context receipt binds the exact 223 committed production/project inputs used by the overlay.
- `../save-slot-isolation/capability-attempt-2-*`: the complete private cohort for this source. Expected: 2,853 service-owner checks plus 184,404 preceding checks, 187,257 total with no failures. `capability-focused-*` are partial cohorts and not substitutes.
- `windows-full-process.json` and `windows-full.txt`: immutable Git archive of this production source/tests. Expected: 76 suites, 468,859 passing checks, zero failures, including STATE 1,488 and SAVE_CONTINUATION 260. The process receipt exists only after completion. `windows-full-start.json` intentionally retains its historical running status.
- `ci-final.json`: terminal metadata and log hashes from [Linux run39949272235](https://github.com/socranates/jumping-spider-sim/actions/runs/39949272235), the existing push job for this exact source. Expected: the same 76/468,859/0, 222 compiles, clean strict and five runner regressions. Do not dispatch duplicates.

The combined `full-verification.json` may be written only after both production platforms are terminal and successful. `verify-gates.py` verifies the exact archive hashes, summaries, compile/types/runner and CI logs, and asserts that the real startup/menu still omit recovery installation. `../save-slot-isolation/verify-recovery-capability.py` separately checks the current complete private cohort, bundle/input/output/type hashes and production overlay context.

The earlier `recovery-capability/` type/compile/private receipts belong to `f205c4e` and remain historical. Source2170f99 evidence belongs to the previous owner-hook step. Do not overwrite either set, or rerun finished suites without a new change/failure/concern.

## Open adoption gates

Mode-specific destination profiles, actual menu and store/model adoption, simulation pause/resume/error/cancel callbacks, explicit service/client replacement epochs, native payload/retransmission costs, full native lifecycle and real online save/rejoin remain open. A successful transport receipt is not a grant or a storage receipt. Native budget-observer evidence covers only that observer. Current CLI proof cannot establish physical-device comfort, native frame rate or release safety. The broad optimization/reliability goal remains active; nothing is published.
