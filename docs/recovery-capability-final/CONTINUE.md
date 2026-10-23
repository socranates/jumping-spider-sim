# Resume the current verification, not a new run

Current source: `257e1a43ae00076a6e59f284c0f2ca0ff09f72e9`, pushed to `github/codex/save-continue`. Private current verifier is `docs/save-slot-isolation/verify-recovery-capability.py`; the previous service-owner verifier belongs to an older bundle.

At this checkpoint the following processes/jobs were confirmed live:

- Windows full production suite: unified exec session **83957**, `python docs/recovery-capability-final/full.py`. It uses an immutable Git archive and writes its terminal receipt only when finished. Resume that handle with `write_stdin`. Current partial stdout is `windows-full.txt`; do not restart from a start/lock file or an observation timeout. Expected terminal 76 suites / 468,859 passing / 0 failures, including STATE 1,488 and SAVE_CONTINUATION 260.
- Linux full production workflow: **39949272235**, exact source above. Use `python docs/recovery-capability-final/fetch-ci.py` to poll/collect the existing job. Exit3 with in-progress metadata means it is still running, not a failed gate. Never dispatch a duplicate. The earlier f205c4e job 39948872378 is historical and not the current gate.

All other processes from this step are terminal: targeted continuation checks; private focused and complete cohorts; production compile/strict/runner (former handle 64492); private final types (94145); full private run (32907); earlier f205c4e private/compile processes. Do not rerun them without a source change, new failure or unresolved concern.

## Already verified on the current source

`checks.json` records 222/222 compiled modules, clean strict analysis, five runner regressions and exit0 for each step. `private-type-inputs.json` binds the 34-candidate overlay check to 223 exact committed production/project inputs. `capability-attempt-2-*` passes 2,853 new service-owner checks plus 184,404 preceding checks, 187,257 total; `recovery-capability-verification.json` verifies the current source, bundle, inputs, output and types. No whole-engine or online-save claim follows from these tests.

## When both full platform gates finish

1. Collect the existing CI job logs with `fetch-ci.py`, then run `verify-gates.py`. Do not claim a full pass or create a candidate before its combined proof exists.
2. Run `build-production.py` once. It creates `C:/Users/natha/claude-xfer/Windowsill-production-257e1a4/TheWindowsill-production-candidate.rbxlx`, checks all 222 script fingerprints and records its manifest. It does not open Studio or publish. The earlier candidates remain untouched.
3. Update the handoff and requirements ledger with exact terminal status/counts/hashes. Preserve all historical handoff bytes using explicit UTF8 or raw-byte append/prepend. Update the current full-verified source from 2170f99 only after the new gates pass. Commit/push only our selected artifacts; verify the remote branch matches.
4. Proceed to actual mode-specific menu/profile/model/store adoption and pause/resume/cancellation handling, explicit replacement epochs, payload/retransmission limits, native whole lifecycle, isolated online rejoin and release verification. Tell the user before changing the actual menu. Keep engine owner installation and publication disabled until those gates pass.

The original OneDrive checkout, three preexisting `docs/save-continue/save-cost/` outputs and untracked `roblox_port/sourcemap.json` are preserved. Do not stage them. No Studio/browser session was opened for this step. The broad optimization/reliability goal remains active, with no complete-migration or release claim.
