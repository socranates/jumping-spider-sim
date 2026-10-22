# Current handoff: encoding optimization verified, unpublished

Only production change: Shared/Persistence/Json.canonical uses one private output-fragment buffer. Exact bytes/errors/checksums, validation, backup/readback, authority and atomic publication remain. [Evidence and limitations](../docs/save-continue/json-encoding/README.md). Source068a87891770dbdf291ec3cab0e67480d14c0251, branch codex/save-continue.

Windows exec28618 and Linux39860574006 both closed successfully:76 suites/465380 checks/0 failures each; compile222/strict/runner5 pass. Root docs/save-continue/verify.py binds both full gates to exact committed inputs and verifies the native receipts. No jobs remain running in this stage.

Private paired native test20738 assertions/224 fingerprints passes:40.27percent lower encoder CPU on the same1.503M-character record across four alternating pairs. Separate current-game sequence1792707403197 passes all32 unchanged save/return checks with225 fingerprints, production Persistence disabled and zero CreatorErrors. Continue queues in1.830ms with no synchronous canonical encoding; local/end-screen returns take3.7s across frames. Save capture remains98–108ms synchronous; replacement preparation14.34s elapsed in this bounded case. Records differ between experiments, so no causal end-to-end percentage, FPS, heap or hard-budget claim.

Both diagnostics are stopped/saved/closed/exited and their original XML hashes restored. Current-game archive C:/Users/natha/claude-xfer/Windowsill-encoder-game-068a878/Windowsill-encoder-game-review.rbxlx is diagnostic only; never publish it. Pre-existing stopped rig window94504044 remains untouched. Use explicit globalThis/scoped unique locals in future UI work.

Next work is the broader28-item audit: prioritize lossless old-world restoration and native lifecycle/traversal review, retaining current save safety. Actual online/rejoin/physical devices, whole-game performance and final release/laptop synchronization remain open. Source release XML/BuildInfo remain old; nothing published. Fly, feeding and settings untouched. Goal active.

Earlier handoff below is historical.

# Current handoff: save-cost attribution complete, optimization next

Current runtime/tests sourceab8ca9577129e3d9583a0a8ab6824dae1a8cd014, branch codex/save-continue. [Measured results and safety details](../docs/save-continue/save-cost/README.md). All jobs are terminal. Linux39852128734 passes75 suites/444664/0 plus compile222/strict/runner5. Old Windows87216 closed75/444661/3; corrected Windows67331 self-tests5/0 and7/0, internal41/0/0 and274/0/0. Root verifier binds current inputs and both cohorts; combined Windows coverage is75/444664/0, not a fresh current-source full run.

Current native1792704319579 passed10 assertions with all223 fingerprints and zero CreatorErrors during the guarded run. PlaceId0/Persistence disabled, local stores only.1.503M-character replacement capture97ms; preparation1064frames/2.579s CPU/18.010s elapsed/max60.322ms. Five canonical encodes consumed1.905s inclusive CPU, six copies357ms, temporary-entry removal copied57.5ms. Large CLI2.282M record agrees: five encodes2.592s out of3.454s preparation. Small18K fixture retained separately. Native Heartbeat gaps1.18-1.27s remain unexplained wider-frame observations, not worker-only costs or FPS proof. Coherent capture123/97ms remains synchronous.

Next: prototype and measure an allocation-reducing canonical encoder while requiring byte-identical output/errors/checksums and all graph validation. A single output-fragment buffer is worth evaluating against the unchanged encoder; do not remove checksum/readback/backup validation or trust mutable-cache identity. Preserve private owned inputs, intent/revision/token fences, atomic commits and exact authority receipts. No product optimization adopted in this measurement round.

The new rig candidate duplicated the existing16-case native orientation-cache trial; removed unused copies. Current rig is byte-identical to its reference; modest/mixed prior gains do not justify integration. See rig-prior-evidence.json. Fly, feeding and settings remain unchanged.

Save-cost diagnostic was stopped/saved/closed; its window55576086 exited and original XML/hash restored. Pre-existing stopped rig window94504044 remains, do not close it as if it were ours. Six preflight errors came from a stale lexical costGuard shadowing globalThis; no Play until the direct scoped ab8ca95 guard passed. Use unique scoped locals/explicit globalThis for future UI work. Builder marker/error metadata corrected; source hashes unchanged. Prepared artifact C:/Users/natha/claude-xfer/Windowsill-save-cost-ab8ca95/Windowsill-save-cost-review.rbxlx must never be published. Native/CLI receipts and source-bound root verifier pass.

Broader28-item audit, lossless old-world restoration, online/rejoin/physical devices, whole-game native performance, publication and laptop synchronization remain open. Goal active, nothing published.

Earlier handoff below is historical.

# Current handoff: cancellable local returns, 4ee6aec

Branch github/codex/save-continue is pushed through verification source4ee6aecc06f4753a85e40fc98a1487dc5126d27d. Runtime source07234cae75b5a62b820dc6dda830dce7e503c36b. [Implementation and evidence](../docs/save-continue/local-return/README.md). Local Continue/Free play, nonempty-store Backspace and end-screen Back now read/check/decode privately across frames behind a Cancel menu. Each valid candidate decodes once. Publication checks world generation, target/active store pointers and revisions; no current world/store is replaced early. Cancellation returns to the original end screen when needed. Failures/newer-schema data preserve current spider and all stored bytes. Local returns still work after network failure. Empty-store Backspace fallback remains lightweight.

Current proof: focused matrix27 suites/25,294 passed/zero remaining failures; compile222/222, strict clean, runner5. Original world fixture failure retained; corrected33/0 replay uses the same simulation tick and keeps1e-9 position checks. Root docs/save-continue/verify.py verifies current hashes, both test cohorts, compile/types and native fingerprints. Historical async-rest verifier is pinned to its own source.

Native1792701458910 passed22 assertions/223 exact fingerprints, zero Creator errors, PlaceId0/Persistence disabled. Record1,501,336 chars; choice3.073ms/zero encodes. Local return249steps/4.210s/571.956ms CPU/max37.684ms; end return253steps/4.241s/572.820ms CPU/max37.884ms. Initial331ms gap includes preceding synchronous probe work; no hard frame budget/FPS/physical-device claim. Low System Resources warning.233 initialization attempts, resident counts unmeasured. No concurrent CLI run during native. Studio stopped/saved/closed/exited; diagnostic original bytes/hash restored.

Current full Windows exec87216 (immutable4ee6aec archive) and Linux39849815798 are active. Poll existing handles/jobs, never restart solely on timeout. Expected75/444664 is not a passed result. Do not stage docs/save-continue/local-return/windows-full.txt until windows-full-process.json exists. Old133aa60 Windows98692 and Linux39846269494 failed74/444632/5; c4bcc6a Linux39846956444 failed74/444633/4. Those fixtures are corrected now; old failures and full input hashes remain recorded. The obsolete c4 Windows follow-up was skipped, superseded by4ee6aec.

Next: improve total save preparation latency and remaining long steps without dropping validation or atomicity. Coherent capture still139ms; large local rest replacement previously18.5s. Consider measured cost of repeated encodes/copies/formatting. Broader28-item audit, lossless old-world restore, actual online/rejoin/physical controls/performance, publication and laptop sync remain open. Release XML/BuildInfo still old; nothing published. Goal active.

Earlier handoff below is historical.

# Current handoff: local rest preparation, c4bcc6a

Runtime/tests source133aa60342d03b534f9dbbf5f6399244714b9fc7 is pushed to github/codex/save-continue. [Implementation/evidence](../docs/save-continue/async-rest/README.md). Coherent capture is still synchronous. Private validation/encoding/store writes/network candidate preparation now span frames; commit swaps the store atomically. Retain generation/source/revision/token fences, exact request/epoch/ticket authority, copy-on-write current/backup separation, and no early success notices. Local rests still finish with broken network saving. New gameplay notices survive delayed successful completion; failed preparation remains visible.

Current source compiles222/222 with strict clean and runner5. Studio1792699532277 passed15 assertions,223 exact fingerprints/Persistence disabled/PlaceId0, zero Creator errors. The isolated place was stopped/saved/closed, Studio exited and original diagnostic hash restored. Large record1,501,336 chars: capture139.495ms; first rest693steps/11.691s/max40.284ms; replacement1091steps/18.515s/max52.894ms. Separate fresh-world running case proves prey/lifecycle advance during preparation.233 initialization attempts are subject to streaming readiness; resident counts unmeasured. Low System Resources warning; no typical FPS/hard frame-budget/device/network/rejoin proof.

Focused matrix:23 suites /25,187 passed /zero failures. Original22-suite successes retained; the title fixture now waits for completed storage and independently passes21/0. Root verify.py checks all current input hashes and the test-only correction. Runtime remains133aa60; verification source is c4bcc6a. Full Windows exec98692 uses immutable133aa60 archive; Linux39846269494 is active. Poll, never restart active runs. Expected74/444637 is not a pass until terminal. Prior8db full Windows and Linux each completed72/444582/0. Do not stage the current live windows-full.txt before its process receipt exists.

Next: reduce total preparation/long-step work; queue synchronous local Continue/Backspace/end-screen last-rest returns behind safe cancellable preparation. Coherent capture still139ms in this case. Keep all dormant ecology and save compatibility; do not turn cancellation into data loss or weaken durable receipts. Wider28-item audit remains open. Nothing published; release XML/BuildInfo still old; goal active.


Full-gate correction: Windows98692 and Linux39846269494 use133aa60 and retain the known outdated title fixture. Keep their terminal results, but do not claim them as current success. Corrected Linux run 39846956444 checks c4bcc6a. After Windows98692 closes, run async-rest/full-corrected.py once for the corrected source; never overwrite its existing archive receipt. No full current pass is claimed yet.

Earlier handoff below is historical.

# Current handoff: asynchronous owned offers, 8db0f6d

Branch `codex/save-continue`, checkout `C:/Users/natha/windowsill-save-continue`. Source8db0f6d is pushed. Read `docs/save-continue/async-offers/README.md`; root `docs/save-continue/verify.py` verifies exact committed source/target inputs, compile/strict/runner and native fingerprints/receipts.

Protocol3 network OnClientEvent uses receiveOwned: its record tables are transferred stable/read-only. Borrowed receive remains synchronous/copy-before-return. One incoming worker step/frame, fair slots, at most active+coalesced replacement per slot. New/remote Continue waits for validation; status/authority/receipts remain immediate. Stale epochs/sequences, withdrawals and queued immutable-id redefinitions are fenced out. Failed reads preserve the stored rest, report a menu retry message and can recover. Per-visit saving failure closes pending jobs. Menu availability now uses an advisory known-rest flag; actual load/restore still checks corruption. Earlier cancellable Continue worker remains enabled. Fly/feeding/settings/HUD untouched.

Current proof:16 suites/2592,222 compile, strict clean, runner5. Actual Studio 1792696992730:20 assertions, zero Creator errors,223 fingerprints/Persistence disabled/PlaceId0.1.5M record: initial receive17.978ms, replacement4.656ms, populated menu6.584ms with zero encodes; five repeats10.131ms. Offer work219steps/3.67s, maxupdate30.678ms (replacement13.567); Continue 618 steps/10.49s, max60.934ms. Low-resource warning; no controlled/typical FPS proof. First large Heartbeat gaps include earlier synchronous probe work.233 initialization attempts, resident region counts unmeasured. Studio closed; original diagnostic hash restored. Injected local transport only; no online/rejoin/device proof.

Current full gates: Windows exec95122 (immutable Git archive of8db0f6d), Linux39839306311. Poll existing handles, never restart on timeout. Prior955 Windows/Linux70/444440/0 are terminal success; prior5aec Linux71/444474/0 also succeeded.5aec Windows was superseded by the newer full run, not counted as passed. Old historical verifiers are pinned to their actual source.

Next priority: coherent/pending local rest save and queued checkpoint preparation; synchronous local Continue/Backspace/end-screen last-rest return also remains. Profile redundant preparation work, native long steps and overall 10 s large Continue latency. Preserve all authority/receipt/immutable-selection/atomic-commit invariants. Use only owned stable inputs or hold a coherent simulation boundary. Never let a cancelled job write live storage or report Saved early.

Release XML/BuildInfo still old; nothing published. Broader28-item audit, lossless older-world restoration, actual network/online rejoin, physical controls/device performance and release/laptop sync remain open. Goal remains active.
