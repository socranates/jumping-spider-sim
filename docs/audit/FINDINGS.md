Latest mating-fix supplement, 2026-10-24: game source fdf88814 after 79dd87f2,
test correction 75ff806d (legacy male-egg expectation); evidence 88c68c98a0324e8a, 273 ordinary sources. docs/mating-fixes/ records
sex-bound reproduction (males never enter sac/guarding), female-rest identity,
sticky earned readiness, attached partner clearance and a supported Preserve exit.
Native 1792855445329 passed all four sex/ordinary/skip routes, 1,929 samples,
zero support losses/CreatorErrors, two exact source guards, closed Studio,
immutable model and operation cleanup. Six style/asset warnings are retained.
The failed initial departure fixture remains recorded; it exposed the distant
waypoint instead of the actual exit. Full 80-suite CI 40107325851 SUCCEEDED on test commit 75ff806d; qualification
binds unchanged native game sources, source/test, models, closed log and exports.
Moult design changed during review: the real instar ladder supersedes 7/15/20;
Nathan explicitly said "Still discussing; fix mating first." No goal/instar or
unlock tuning changed. Male continuation, pre-newborn-rest Carry/rejoin, contact
seams, broader natural/device/world/performance checks remain open. No publication.

Sex-path decision, 2026-10-24: the reproductive receipt below covers the default female in three difficulty modes, not both sexes. The male must not lay eggs or guard young. Nathan and Claude are discussing separate playthroughs; male progression remains an open design. Mating.woke currently has no sex gate, so the shared chain is a known male-route design gap.

Latest reproductive-route supplement, 2026-10-24: test commit 3f6ed486,
game sources identical to fa7367fb; ordinary evidence 5e9ac432e9933ed9,
273 sources. docs/generation-route/ qualifies native run 1792852025863:
Normal, Easy and Free each grow from fresh, court a live mate, mate, make an
egg sac, pass two guard days, hatch and continue as a new spider. Normal's
first seeded court was refused; the next was accepted with real rules active.
90 full flies consumed through input taps: 62 growth, 19 adult refuels, nine
newborn meals; nine moults/hardenings. Three guarded-family local returns
preserve seeded hatching; three newborn local returns preserve 3/7 meals.
Free's Follow-to-attached-newborn interval is 12.075 seconds. Both exact
276-source guards pass, 0 CreatorErrors, six retained style/asset warnings,
operation cleanup, Studio 21692 exited, immutable model unchanged. New full
80-suite CI 40102350037 SUCCEEDED, including compile, strict, exports and
runner cleanup. Qualification binds the current source/test, model/log and CI.
An apparent three-meal reset was a disproved observer hypothesis: Carry runs
between ticks, and existing fixed-tick code restores live rules before feeding.
The added client assertion passes without a game change (CLIENT_MATING 29/0).
The original stopped partial run and corrected analysis remain in the receipt.
Captures, approaches and facing are scripted; clocks accelerated. This is local
Studio/memory, not natural hunting/traversal, online storage/rejoin, physical
devices or FPS proof. Asset 203785492 metadata was checked; caller unresolved,
no occurrence in game sources. Warning evidence is retained, not erased.
Private published version 14 still has 032b5985ac17eeb2. No publication,
production/main/OneDrive/Godot/synced-source changes. Broader goal ACTIVE:
continue natural attack/collision/content/device gaps and measured startup work.

Latest feeding/progression supplement, 2026-10-24: source/test commit fa7367fb,
ordinary evidence 5e9ac432e9933ed9, 273 sources. docs/life-route/ records and
fixes a real input bug: the final Eat tap in the Crack also requested Rest,
starting a ready moult without a second press. Rest is now queued only when
the jaws were empty at input time (including the captured-rival context).
Focused regressions 713/0; full 80-suite CI 40099833793 SUCCEEDED, including
compile, strict types, exports and runner cleanup checks. Native run
1792850357913 passes 62 complete meals, nine moults/hardenings and three adult
lives (Normal, Easy, Free); exact 7/10 thresholds, unlocks, drawn stage and
retained local rests. Both 276-source guards, 0 CreatorErrors, six retained
style/asset warnings, operation cleanup; Studio 27420 exited, model unchanged.
Captures/safe Crack arrival are scripted and clocks accelerated; no forced
food, energy or growth counters. Not natural hunting, mating/eggs/generations,
online rest/rejoin, physical devices or FPS proof. Failed native1 exposed the
real input bug; native2 kept the identical driver and confirmed that fix but
hit an unnamed diagnostic-clock function at checkpoint capture. Both remain
preserved. Only the unpublished fixture clock was corrected for native3.
qualification.json binds sources, exports, native run and successful CI.
These ordinary exports supersede the older 597db4c421e47c5e cohort below;
that predator fix and its proof remain part of this candidate's history.
Private published version 14 still has 032b5985ac17eeb2. No new publication,
production/main/OneDrive/Godot/synced-source changes. Broader goal ACTIVE:
continue the remaining full reproductive route, natural strikes, whole-map
collision/content/device coverage and hypothesis-driven startup profiling.
This qualified progression subset does not close the entire foundation audit.

Latest major correctness finding,2026-10-24: [predator death gate](../predator-endings/README.md).
Source642af969 / evidence597db4c421e47c5e repairs five authored lethal outcomes
silently refused by LifeSession. Red/green real-client regressions, all5 native
cards/Another callbacks and continuous fast-clock hunger/gentle survival now pass.
Full80-suite CI40098023022 succeeds; this candidate is unpublished.
The detailed historical findings below retain their original cohort/status.

# Foundation findings

> Current candidate status: [CURRENT.md](CURRENT.md). This report retains its original named-source evidence.


Baseline: v51, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place **140**, evidence `d9ddc5e0ed43d301`.
Candidate: `codex/foundation-audit`, source `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`. Publication is not yet verified.

## Follow-up status, 2026-10-22

Later audit receipts: pinned Linux tools/checksums passed the full 63-suite / 443,469-check CI run `39767706811` on workflow source `2b7f4998` (`docs/ci-toolchain/`). The real 30-minute native memory trace on gameplay source `3c8de801` completed, with an **investigate-growth** result; engine BaseParts/Instances/Signals allocation categories rise despite stable matched live counts and client-GC low points (`docs/memory-trace/RESULTS-v1b.md`). An isolated one-script Studio control reproduces the broad category-growth pattern without Windowsill game scripts (`docs/native-part-churn/RESULTS-v1.md`); this narrows attribution, not a memory-clean or engine-bug verdict. Preserve save-error visibility (remaining A11 path) is addressed in unpublished source `fab75695`: 389 targeted checks, compilation/types, runner checks and 16 guarded native assertions pass, plus both full Windows/Linux gates at **64 suites / 443,522 checks / zero failures** (`docs/save-error-notices/receipt.json`). Separately, `docs/shadow-stream-retention/` reproduces stale hidden-part bindings; no fix or FPS claim yet. The historical findings table below must not be mistaken for the final state of these later candidates.

The table below records the initial foundation candidate, not the final status of every later branch. Lossless native compression (`codex/save-compaction`), acknowledged life retirement (`codex/life-retirement`) and native callback error propagation (`codex/save-adapter-errors`) have separate source-bound receipts. Read those receipts before treating A02, A05 or A12 as still unaddressed.

A04 is **partially addressed** in unpublished source `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5` (`codex/save-slot-isolation`, evidence `1984fdd8e8dee0ad`): unreadable rest slots remain untouched while progress and other slots can save. Corrupt/newer progress still disables all writes. The old-world ecology migration remains open. See `chet/save-slot-isolation.md` and `docs/save-slot-isolation/receipt.json` for implementation and completed versus outstanding gates. No native or publication result from an earlier candidate applies automatically to this changed source.

A08 is **partially measured**: the first v6b native desktop full/low baseline/candidate matrix completed on source `3647a94`, four trials / 52 records / 44 timed samples including the continuous three-region walk. Results are mixed; no general speedup is established. Read `docs/performance-pass/RESULTS-v6-trial1.md` for hardware, frame-time tables, script costs, engine warnings and limits. The 30-minute memory session, MicroProfiler, emulator/phone, network and startup measurements remain open. No profiling place was published.

A11 is **partially addressed** in unpublished source `a36789375dd75920c0eca59ac524644b8776477f` (`codex/preserve-captions`, evidence `b5550e7ed240b745`): sound/vibration captions selected as Normal/Large now survive the preserve HUD projection. Fresh/reset preserve settings remain Off; saved explicit choices are honored; the menu uses the same effective default. The real-client shim regression passes, including a forced wasp, sizes, device modes, Off and Reset. Native desktop caption run `1792662057872` passed 18 assertions with persistence disabled and all authored sources guarded. Normal was visually inspected; Large passed native TextFits. Phone/controller comfort and actual saves/rejoin remain unverified. Save-error toast visibility is still open; status remains available in the menu. See `chet/preserve-captions.md` and `docs/preserve-captions/`.

Outdoor encounter reset is addressed in unpublished source `3c8de801e5fab68598e1e5323e7f5e1c8151b0e6` (`codex/outdoor-life-reset`, evidence `d543592dddf4e621`): New Life and successful rest recovery reset frog/crab/robin reactions while preserving identities, seeds and enable flags. The frozen prior source fails 15 regression checks; the candidate passes 45, 29,166 targeted checks, compile/types, runner checks, and a guarded 46-assertion native in-session test with persistence disabled. Full Windows and CI gates remain separately tracked; no publication or online rejoin is implied. See `chet/outdoor-life-reset.md`.

This is a current-source audit of the supplied v48 review. A static finding is not a reproduced Studio defect. Tests, probes and remaining native work are distinguished below.

| Rank / ID | Severity | Current finding and evidence | Status / recommendation |
|---|---|---|---|
| 1 / A02 | Critical | A long explored ecology cannot be saved online. `roblox_port/src/Shared/Data/SaveRules.luau` caps rests at 262,144 characters / 120,000 nodes. `SaveRest.check` rejects larger records. The reproducible read-only probe initializes the actual preserve region populations: 100 regions = 476,859 characters; all 233 = 2,277,087, rejected. This is an initialization stress probe, not a timed player walk. | **Mitigation implemented**, not solved: `SaveSession.setRest/status` now reports a specific refusal, retains the previous online rest, and clears the rejection only after a valid replacement in that slot. Compact serialization needs a separate reviewed change. Never discard visited populations to make saves fit. |
| 2 / A01 | Major | Six CLI suites lacked failure exits; `tests/run.py` skipped missing default suites/modules. Reproduce on the baseline by forcing a check false: its summary can fail with exit 0. The v48 HUD pins were already repaired in v51; those old two failures should not be attributed to v51. | **Fixed**: all six suites raise on failure; missing inputs fail closed; temporary bundles are removed. Python infrastructure regressions cover missing default/named input, missing module, child failure and cleanup. |
| 3 / A04 | Major | `SaveSession.readRests` demotes the entire session without retry on a corrupt/invalid slot. `Checkpoint.checkWorld` validates garden ecology against the current map, which does not contain old test-garden `bed_a`. Progress and other valid slots can become read-only too. | **Open**: preserve damaged/newer data; implement explicit legacy-world migration and per-slot quarantine. Do not turn a failed validation into permission to overwrite. Probe records both original-world and preserve validation. |
| 4 / A05 | Major | `SpiderClient.fresh` replaces the local checkpoint store without a server tombstone. Starting a new life and leaving before the first rest can offer the prior life on the next visit. | **Open**: decide whether New Life immediately retires the online rest. If yes, add a versioned, acknowledged generation/tombstone protocol with concurrent-session tests. |
| 5 / A06 | Major | After an unclean exit or overlapping join, `SaveSession.load` sees a foreign progress lock, merges progress, but does not read the stored rests until the lock is acquired. `LOCK_STALE` is 120 seconds. A normal successful flush does release it. | **Open**: show a read-only Continue state while another session owns the lock; prevent an accidental new-life overwrite after delayed acquisition. This is not a claim that every rejoin waits two minutes. |
| 6 / A07 | Major | `RivalRoute.advance` budgets work by `os.clock` and units; the render callback advances preparation, while `RivalDrive.step` waits for routes. `StationAir` also builds incrementally. Seeded geometry does not guarantee identical AI start timing across frame rates and machines. | **Open**: separate asynchronous preparation from deterministic activation; compare identical input traces at 30/60/120 Hz before changing predator timing. No predator-rule change in this patch. |
| 7 / A08 | Major | Native performance needs controlled measurements. Existing v51 long-tour receipts show approximately 36 ms mean total frame time at the sill after traversal; a later stress sample was much worse. These are prior receipts, not new paired benchmarks. `LookStream` makes required close looks whole in one frame; `LivingWorld` rebuilds near detail at cell changes. | **Open**: capture the eight matched scenes and 30-minute memory trace. Do not promise FPS improvements from static reasoning. Keep lighting and dense close habitat. |
| 8 / A03 | Major, performance | `PreyWorld.director` and `bugs` checked collision readiness before finding that the region had no relevant population. `WorldClient.regionReady` searches for every piece. | **Fixed**: check the immutable region/spec first. No geometry readiness cache was introduced, so streaming gates remain live. `tests/foundation.luau` proves 2,000 absent-spec requests avoid scans and a real colony still waits for geometry. No measured FPS claim. |
| 9 / A09 | Minor, verification | `tools/check.sh` used the compiler's optimized default, despite the documented unoptimized local-variable guard. | **Fixed**: explicitly compile with `-O0`. All 215 current source files compiled locally. A large SpiderClient split remains a proposal, not an audit fix. |
| 10 / A10 | Major, verification | CLI shim cannot establish engine collision, streaming, native controller/touch comfort, real sound playback, DataStore rejoin or phone performance. Many suites deliberately use the test garden. CI uses moving Luau/LSP/definition downloads. | **Open**: retain the old-world tests; add preserve integration coverage rather than globally changing the shim. Record exact tool versions and pin a tested toolchain in a separate change. Current UI/native evidence belongs in TESTS.md, never inferred from CLI counts. |

Other confirmed source risks: frog/crab/robin state is not explicitly reset in `fresh` as the cat is; `SaveRest` envelope schema 1 can classify a future internal checkpoint schema as invalid rather than newer; `WorldClient` startup waits can hang if the server does not construct its folders. These need targeted regressions before changes. Shared save validators and object-graph internals still need a full adversarial review.

A11 (major accessibility, source-confirmed): `SpiderHud.minimalView` drops the sound caption field in preserve play. The captions setting therefore cannot establish equivalent audible threat information there. Save refusals are exposed in save status/the menu; the minimal HUD can suppress their toast. Reconcile these opt-in/error displays with the minimal design before claiming the game is fully accessible. No HUD rule was changed in this patch.

Already improved since the supplied review: v50 throttles distant cat poses; current v51 release files and README identify place 140; growth uses seven / ten fly equivalents in every mode; current native receipts exist. The audit does not repeat old v48 deficiencies as current facts.

Reproduction: from `roblox_port`, run `python tests/run.py path/to/luau ../../docs/audit/probe.luau`. `save-probe.txt` contains exact outputs. No live save or Roblox API is touched.

## A12 â€” startup readiness and false loading success (new source8e02b5e)

Major, reproduced. `Client/WorldClient.luau` construction waited without deadlines for World/home, guessed a default after missing streamed identity and admitted missing home collision after warning. `First/SplashScreen.luau` removed its loading veil on timeout/error although the controller might never be ready. The current [A12 report](../startup-world-readiness/README.md) retains failing-on-predecessor pairs (world4/title6) and passing candidate counterparts (world33/title21), client/preserve1181, compile216, strict and runner5. Source changes are small and isolated; Splash.client has a comment-only correction. Current full/native gates remain separate and pending. Shared imports, real network timing, current physical-device controls/legibility and broader clipping remain open. The original report above retains its original source/statuses; this section supersedes only the named startup finding.
