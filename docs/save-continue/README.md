# Latest: pond drawing reuse adopted; full gates pending

The tested b2fdc562 renderer is now in production source, unpublished. Pond drawing component CPU decreased18.13/21.32 percent (full/low), with identical checked geometry. Default bodies3610/0 includes2702 frozen-reference regressions. Full Windows/Linux checks for this new source are pending; expected468114 is not a completed result. The older59146e1 save-validator source completed465412 on each platform and native20. Its proof remains historical and pinned. See docs/pond-drawing-reuse/README.md for scope and gates. No whole-game FPS claim; no publication. Legacy save migration is still pending. Broader goal remains active.

Earlier status below is historical.

# Current unpublished candidate: invalid fly-position refusal, 59146e1

Checkpoint now refuses NaN/infinite fly positions and plain tables masquerading as vectors before prepare/restore commits. Only save validation and its regressions changed; no hunting, feeding, settings, menu, schema or valid-save-format changes. Six current focused suites pass1783/0, all222 modules compile, strict clean, runner5 pass. Linux39872335932 completed76 suites/465412 checks/0 failures. Native20 actual-client refusal/atomicity assertions with all223 fingerprints and zero CreatorErrors pass. Windows58767 also completed76 suites/465412 checks/0 failures. Root source-bound verification passes for both platforms, compile/strict/runner and native refusal checks. All jobs in this source cohort are terminal.

Previous032926f full Windows7806 closed successfully: Windows/Linux both76/465388/0, native22/all225 pass; its historical verifier passes with current-workspace-match=false. Those results do not substitute for current59146e1 Windows coverage. Both current native diagnostic windows have stopped/saved/closed/exited and original archive bytes are restored. Pre-existing stopped rig94504044 remains untouched. Root verification confirms current59146e1 inputs and receipts; broader audit/release work remains open.

Older-world policy: import portable progress into the Preserve while keeping the complete original save in an untouched archive. The isolated map-view candidate passes167 assertions plus compile/full strict analysis in a disposable source copy, but remains outside production. Migration is not implemented. Its design and field/storage review are in docs/save-slot-isolation/migration-design.md. The new fly-position fix is targeted corruption protection, not proof of validation for every spatial field/class.

Current-source animal/audio attribution completed two full-detail playing scenes without heavy concurrent local CLI work. Sill711 frames:16.885ms observed interval/6.263ms Lua callback mean; garden575:20.877ms/6.619ms,1105x433 viewport. In the broad sound category, drawing dominates the Lua audio handlers: wasp0.330/0.368ms per frame, pond0.184/0.138, cat0.087/0.098; combined audio handlers about0.056ms in both. Pond drawing shows about24KB positive heap growth per frame in these samples. These instrumented observations do not prove a leak, allocation rate, engine mixer cost, paired FPS gain or physical-device performance. No presentation optimization adopted. Investigate reuse of invariant darner geometry before reducing animation fidelity or lighting.

Natural streaming/rearrival, full natural lifecycle, physical devices, online durability, broader memory/performance, release rebuilding/publication and laptop synchronization remain open. Nothing published; goal active.

Earlier status below is historical.

# Current unpublished milestone: canonical encoding verified, 068a878

[Current evidence and handoff](json-encoding/README.md). One private output buffer preserves exact canonical bytes and errors. Windows and Linux each pass76 suites/465380 checks/0 failures, compile222/strict/runner5; current-game Studio save/return passes32 assertions/225 fingerprints with production Persistence disabled. Paired isolated encoder CPU is40.27percent lower; whole-game FPS and hard frame budgets remain unproven. Root verify.py binds current source and receipts. Broader audit, synchronous capture, legacy-world restore, native lifecycle/device/online checks and release remain open. Nothing published.

Earlier milestones below are historical.

# Current unpublished milestone: local returns across frames, 4ee6aec

[Implementation and evidence](local-return/README.md). Local Continue/Free play, Backspace and end-screen Back prepare privately behind Cancel; world/store/revision fencing and exact backup/schema checks remain. Current27-suite focused matrix25,294/0,222 compile, strict clean/runner5; Studio22 assertions/all223 fingerprints/Persistence disabled. Large local choice3ms, return4.2s/maxupdate38ms in a bounded1.5M case. No hard budget/FPS claim. Current full Windows87216/Linux39849815798 pending; expected75/444664 unverified. Prior133aa60 full Windows/Linux failed5 timing fixtures, c4 Linux failed4; corrections and original failure receipts retained. Nothing published; release artifacts old; broader goal active.

Earlier status below is historical.

# Current milestone: local rests prepare across frames, c4bcc6a

[Implementation and evidence](async-rest/README.md). Coherent capture remains synchronous; validation/store/network preparation now runs privately across frames with atomic publication, revision/generation/token fencing, previous-rest backups and no early kept/Saved claim. Local saving survives network failure, and delayed completion preserves newer gameplay notices. Studio15 assertions/all223 fingerprints/Persistence disabled passed; source222 compiles with clean strict analysis and runner5. Focused23-suite matrix passed25,187/0; full Windows98692 and Linux39846269494 are active. Prior8db full Windows/Linux each72/444582/0 is terminal historical evidence. Large native replacement18.5s/maxupdate52.9ms; capture139.5ms. No hard frame-budget/typical-FPS claim. Nothing published; goal active.


Full-gate correction: Windows98692 and Linux39846269494 use133aa60 and retain the known outdated title fixture. Keep their terminal results, but do not claim them as current success. Corrected Linux run 39846956444 checks c4bcc6a. After Windows98692 closes, run async-rest/full-corrected.py once for the corrected source; never overwrite its existing archive receipt. No full current pass is claimed yet.

Earlier milestones below are historical.

# Current milestone: owned offers across frames, 8db0f6d

[Current implementation/evidence](async-offers/README.md). Protocol3 network-owned offers now validate privately across frames; status/authority remain immediate, and menu renders use advisory availability rather than decoding full local rests. Current proof:16 suites/2592,222 compilation/strict/runner5; actual Studio20 assertions/all223 fingerprints with production saving disabled.1.5M native initial receive18ms, replacement5ms, populated menu7ms; remaining update spikes/large Continue latency/local-save and local-return stalls remain. No hard-budget/typical-FPS claim. Nothing published; goal active. Root verify.py is current-source-bound.

Current full gates: Windows95122 (immutable8db archive), Linux39839306311. Prior955 completed both70/444440/0 and5aec Linux71/444474/0. A separate5aec Windows run was superseded by this newer full run. Older milestones below are historical.

# Current milestone: actual Continue across frames, 5aec1bc

See [current implementation and evidence](async-continue/README.md). Continue now prepares privately behind a Cancel menu, then commits once. Current proof:15 suites/2484 checks,222 compilation/strict/runner5, actual Studio13 assertions/all223 fingerprints with production saving disabled. Incoming offer and local rest work remain synchronous; the native controller still had64ms maximum updates. Nothing published, broader goal active. Root verify.py is current-source-bound.

Linux39836124046 is running on current source. Prior955d1eb Linux finished70/444440/0; Windows30175 remains live. Poll before launching a current-source Windows full run; no duplicate heavy run. Older milestones below are historical.

# Current save preparation milestone: 955d1eb

The new cooperative preparation foundation passes **14 suites / 2,450 checks**, 221 compilation, strict analysis and runner5. Actual Studio passed13 assertions on an owned1.5M-character record, with all222 scripts fingerprinted and production saving disabled. Byte/hash/graph identity, cancellation and private staging are verified. **Gameplay workers remain disabled**, and some individual native steps still reach81ms; save stalls are not resolved. Nothing published.

Start at [the current preparation notes](cooperative-stage/README.md); root verify.py checks exact source and receipts. Previous fbe4b56 completed both full Windows/Linux gates:69 suites/444391 passed/zero failed. New full gates for955d1eb are running as Windows30175 and Linux39834230975; poll existing runs. Current artifacts/BuildInfo remain old. Online/device/physical-input and broader audit work remain open.

Earlier milestone notes below are historical.

# Current milestone: native cost evidence and rare fixture protocol correction

Sourcefbe4b56 has identical production files to47241c9 and only fixes the rare-history mock reply's protocol fields; its original assertions are unchanged. **12 focused suites/1,856 checks pass**, with220 compilation/strict/runner5 proof bound to identical code. See [current receipt](rare-protocol/receipt.json) and run root verify.py. Older counts/source sections below remain historical.

The actual Studio controller probe completed13 assertions, zero Creator errors, through a large1.5M-character Normal checkpoint and local injected saving transport. Receiving took701ms, menu store/restore1619ms, local rest processing2639ms, and five unchanged repeats0.020ms in this one low-resource/concurrent-test run. Streaming/materialization completeness was not measured. See [native scope and next work](native-cost/README.md); these are not typical FPS/network/device or online-rejoin results. Initial/local-rest work is still a visible performance problem.

Both oldac898f4 full runs are terminal failures with only the two stale rare-fixture checks:69 suites/444365 pass/2 fail each. They are retained, not counted as success. New full gates on fbe4b56 are running: Windows71231, Linux39830933365/job120006543269. No completed current full gate is claimed. Artifacts/BuildInfo remain the prior snapshot; nothing published; overall goal active.

# Save/Continue: repeated-offer cost reduced; first-load cost still open

Active branch `codex/save-continue`, checkout `C:/Users/natha/windowsill-save-continue`, source `47241c994c7b2fbd4eb3fed0c4affd75ece88c10`. Actual game/menu use protocol3. Nothing published; runtime XML/BuildInfo are still the earlier snapshot and must not be published as this source.

Current source-bound focused proof: **11 suites/1,591 passed/zero failed**,220 compilation, strict analysis clean and runner5. Results: menu32, continuation125, intent57, observation50, state1013, older-peer client161, offline8, storage14, compression57, save notice53 and title21. `cost-reduction/receipt.json` and root `verify.py` verify committed source and exact snapshot inputs. The retained first failed fixture assumed nonnil callbacks for empty-slot withdrawals and reused an old offer id for a new retirement marker. The final fixture handles withdrawals and gives each new immutable observation a fresh id; production was not weakened to accept id redefinition.

The menu/controller behavior remains the explicit-choice flow described in `menu-ready/README.md`: displayed-id New/Continue selection, confirmed replacement of a running world, one-time restore, safe failed restore, separate slots/Easy unlock, correct temporary play on older peers, and exact-credential durable receipts. Fly, feeding and settings are outside these changes.

## Current optimization and paired evidence

- SaveRest.check optionally validates against the actual client world. The client now runs size/type/mode/full-graph validation once, rather than validating against a stand-in and then decoding the graph again against the real world. Server callers retain their original stand-in checks. All3 slots have valid/malformed/input-immutability coverage.
- Offer callbacks carry metadata or nil withdrawal, not an unused deep copy of the complete record. The full record is copied only for explicit consumers/restoration.
- Repeated delivery of the same immutable offer id keeps the previously validated private record, advances its channel watermark and does not revalidate/copy/repaint it. A changed repeat body cannot redefine the private world; conflicting protection cannot redefine the same id. A genuinely new observation still receives full validation and a private copy.

`cost-reduction/paired-cost.py` compares exact baselineac898f4 and candidate47241c9 through one identical233-region checkpoint (2,277,087 canonical characters), serially under the CLI. Raw source/test/probe/bundle hashes and outputs are retained. In one pair, receiving the initial snapshot measured716.6ms baseline/683.4ms candidate; queuing it748.0/699.5ms; outgoing deep copy58.6/52.2ms. These single-run small timing differences are not a causal frame-rate claim. The explicit Continue core sample was slower161.6/210.3ms, reinforcing the need for native profiling.

The decisive repeated-work result was5 unchanged full offers: baseline3,837.5ms and candidate0.0103ms, with validation calls7 to2 and nonempty callbacks6 to1. Both retain the same outgoing2,277,178-character candidate and pass all14 full-world storage checks. The receiver never swaps in the repeat's body; it keeps the previously accepted private observation. Metadata-only100-read loops still make zero full-world copies.

**First-offer and new-checkpoint validation still take roughly0.7s in these CLI samples.** No overall optimized/FPS/phone/network or peak-RSS claim. Heap readings vary with GC. Next profile the actual native offer/queue/restore path and the individual validation phases; investigate cooperative preparation without weakening immutability, message ordering, local checkpoint retention or server authority.

## Outstanding gates

Prior sourceac898f4 full Windows exec63820 and GitHub run39827147497/job119993315925 remain running at last verified poll; do not restart those existing handles on an observation timeout. Their immutable inputs cannot be changed by this newer source. The new47241c9 source has focused gates only; prior full results cannot certify it. Source-bound artifact rebuilding/BuildInfo, native current-feature controls and cost/network/streaming evidence, actual online rejoin, older-world restoration and the broader28-item audit/release/device/collision/audio requirements remain.

Historical menu integration receipts are in `menu-ready/`; the old stable predecessore315b3a has separate full65-suite/443946 Windows/Linux and native synthetic cleanup9-case/62-assertion receipts in `../save-lease-cleanup/`. Overall goal remains active.
