Latest instar/hunger candidate, 2026-10-24: game source 455dd28f; tests corrected at 78413065; ordinary export evidence 7c0bede90b301ac2 (273 sources), unpublished. Nathan approved the ladder, then explicitly chose Run after moult 2 and lock-on after moult 5. The live game now draws/saves maturity at instar 7 or 8, migrates old growth without losing credit/readiness/abilities, and draws each instar. Normal goals are 4/6/8/11/15/20, with the middle 11-goal omitted for an early maturer; gentle goals are lower. Hunger now appears as closing red edges, with a wordless bar fallback. Native 1792858219060 passed 17 synthetic-credit moults, three interrupted-moult returns, three adults and both hunger presentations, with two source guards, no CreatorErrors, six retained warnings and closed Studio. Full 82-suite CI 40110260962 SUCCEEDED on 78413065; the preceding run used one wrong Normal-counter test assertion. See [instar/hunger plan and limits](../instar-hunger/PLAN.md). Stage-sized prey/currency, retreat hazards, measured survival tuning and the broad optimization audit remain incomplete. The earlier mating-only growth-hold paragraphs below are historical, not the current approval state.

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

Latest correctness supplement,2026-10-24: source/test commit642af969,
ordinary export evidence597db4c421e47c5e,273 sources. docs/predator-endings/
records a major confirmed bug: LifeSession refused cat/crab/robin/frog/drowning
causes already requested by the client. The small allowlist fix retains unknown-
cause/duplicate refusal and both gentle modes. Corrected red regressions show
15 session assertions and5 client scenarios failing; green four related suites
29134/0. Unpublished native run1792848463523 verifies all5 actual ending cards,
Another/lineage and duplicate refusal; continuous120x hunger from fresh reserve
starves in Normal on day2, while Easy/Free each survive3 game days at0.1.
Both276-source guards, cleanup,0 CreatorErrors,6 retained warnings; Studio16336
closed and model hash unchanged. This does not prove natural strikes or feeding/
moults/mating/generation. Full80-suite Linux CI40098023022 SUCCEEDS at642af969: all suites,
compilation, strict types, exports and runner checks complete. The receipt and
source bindings are in docs/predator-endings/github-ci.json and qualification.json.
The ordinary exports are current and unpublished; private14 still has preceding
032b5985ac17eeb2. No new publication, production/main/OneDrive/Godot edits.
Broader goal ACTIVE. Qualification and exports are recorded for this candidate.
CI is complete; continue full-life/rest/save and collision/content gaps.
This is a qualified small fix, not clearance for the whole audit.

Latest private publication and Player supplement,2026-10-24: user explicitly
approved evidence032b5985ac17eeb2 / VerifiedPrivateCurrent.rbxl for existing
PRIVATE place109879630247781. docs/private-current/PLAYER.md records published
version14 in Dashboard and two actual Player runtime PlaceVersion14 arrivals.
Both274-source guards pass; each run completes a90s observer and six15s
windows (12 windows total), exact evidence/store, cleanup and0 script errors/focus losses. Ordinary
New Life reaches the playable sill with readable labels and0/7 meals. First
final30s stationary sample57.26 callbacks/s; fresh run53.14/s mixes intro/play,
so no matched FPS gain. Startup remains variable: observed callback maxima
240.17/638.26ms; first raw dt partly predates probe, not all game work. Both
players/Studio and owned tray children closed. Full80-suite CI remains qualified.
Production/main/OneDrive/Godot/synced sources unchanged. Broader audit ACTIVE;
prior private13-only pending-publication language below is historical. Next:
bounded current ordinary life/rest/save and remaining collision/content coverage,
plus hypothesis-driven startup attribution. Do not repeat completed arrival runs
without new evidence. New variants/production require their own release decision.

Latest startup attribution supplement: ../startup-clock/STREAM.md retains a
finalized native file stream covering the early pause, current273 ordinary
source hashes, both277-source guards, PASS/cleanup and0 CreatorErrors. It
shows substantial Studio/plugin initialization overlapping startup, including
built-in tools in the Studio log. Incomplete frames and underflowed scopes
prevent exhaustive attribution. No plugins disabled, no game behavior changed,
and no standalone Player or phone claim. Rig CI40093189495 now succeeds for
all 80 suites and all workflow steps at dd212105; receipt is in ../rig-hair-cache.

Latest rig optimization supplement, 2026-10-24: evidence032b5985ac17eeb2,
source/test/export commitdd212105. ../rig-hair-cache/README.md records fixed
leg-hair orientation caching:18,160 repeated lookAt calls removed in560 frames,
with143,800 part comparisons. Native28/0, both278-source guards, zero errors,
cleanup/closed editor/hash unchanged. Local11,247/0 related checks,273/273
compile, strict0, runner5/5, exact exports. Full80-suite CI40093189495 succeeds.
Fresh unpaused Server-tab and later paused client dumps are retained;
local Studio rendering/client scopes prevent dedicated-server claims. No paired
FPS gain or hitch resolution claimed. No new publication; broader audit active.
# Current foundation evidence and remaining work

Latest measurement supplement,2026-10-24: ordinary evidence remains
105c83862d500f43. ../performance-matrix/PAIR2.md now qualifies four current
native runs/36 workloads,8 source guards,0 CreatorErrors,cleanup and0 camera
mismatches at the unchanged.01 tolerance. Both variants keep current hut policy
and geometry; only base-record sharing differs.4805 equivalence checks pass.
Means are mixed, with no blanket FPS gain. ../startup-clock/phases-full1
locates initial gaps before render callbacks without identifying their internal
cause. ../microprofiler-current records an actual128-frame client dump,
rejects an overlapping paused-buffer Server-tab request as independent timing,
and retains a separate one-minute garden PASS/both guards/zero errors. Its
fresh server dump was not obtained. Startup/server isolation, device and broader
audit coverage remain open. No ordinary source change or new publication.

Latest supplement, 2026-10-24: ordinary candidate 105c83862d500f43, 273 sources,
source/test commit c8054893. ../startup-clock/README.md and qualification.json
record a proven 4,777 ms optional-Decor wait after essential home collision was
ready. Construction now returns without that cosmetic dependency; late leaf
and sash binding preserves current fall/open state and collision. The original
shared essential-collision deadline and startup failure policy are unchanged.
Windows targeted checks 1022/0, compile 273/273, strict 0, runner 5/5 and exact
exports pass. Full Linux CI 40084424435 succeeds: all 79 suites and all steps.
Three current native cohorts complete both 276-source guards and cleanup,
zero CreatorErrors. Full/low deliberate optional-visual replacement restores
12/6 original leaf pieces and the correct physical window. Source hashes
match the current candidate; all 269 other game modules match the prior cohort.
No new publication occurred. The dependency fix is qualified, while separate
2.46 s/1.24 s engine callback gaps before the first completed game frame remain
unresolved. No general startup/FPS gain, phone, whole-map or natural-life
qualification follows. The earlier cohorts below retain their exact scope.

2026-10-24. Integration line: codex/verified-integration. Normal roblox_port/src
now contains273 sources imported from the verified font candidate. A later
generator-driven notebook correction and subsequent camera lens handover fix
were the earlier game-source differences. The later unpublished hut-ground
candidate also changes Verge and LookPlan: current evidence20f2200d79a9e448,
273 sources. ../outdoor-seams/HUT-PERIMETER.md records four reproduced native
failures, additive ground, unchanged generated data for all233 old regions,
and the planner's retained-detail correction. Its first full Windows run
failed and stays failed; current focused/static checks are recorded separately.
Current full Linux CI40081320611 succeeds (all79 suites plus compile/types,
exports and runner checks). Current Windows targeted qualification is4623/0,
with nested Preserve self-test END307/0/0. Eight native full/low hut-edge
walks and eight hops pass through9960 attached walking frames; both guards
per cohort, zero CreatorErrors, warnings/readiness limits retained. These
are selected routes and not FPS/all-map/physical-phone proof. All receipts
are in ../outdoor-seams; no publication occurred.
The same notebook module also has the
later one-sentence HUD note correction,1600 focused passes/compile/strict and
then-current export evidence2b1c99cacf601b8f in ../notebook-hud-note.
Notebook biology evidence1ba4c21a1753e03d stays
in ../integration/notebook-receipt.json. The camera fix has1443 focused passes,
compile/strict and its export evidence66a9319760fa7c29 in
../camera-handover/receipt.json; later native-trace30 completes the corrected65
camera and bounded30-minute garden trace. The frozen
224-source proof checkout remains at c457af12. Private test13 is published;
this integration/font variant is not published or merged to main. Private13 has273 game sources and hashes in ../menu-overflow/README.md.
The subsequent font-only candidate also has273 sources, model SHA256
64a3ff7e865ce53d401569e8e12605ddff419028ccfd887d518e03e2514b0a6b;
../touch-labels records its verified native component layout. It is activated in this branch only, not published. Older audit reports retain their original evidence.

The requested foundation audit, small-fix scope and later optimization goal
remain open. The supplied audit prompt guides coverage; its old v48/v49 baseline
assumptions do not override later evidence or the user's decisions. Future Steam
Island work and new rare content are not being added during this foundation pass.

| Requirement | Authoritative current evidence | Status / remaining proof |
|---|---|---|
| Preserve liked movement, camera, jumps, lighting, seeds and ecology | Exact model/source manifests; scenery record-equivalence cohort in ../frame-ordinary; menu variant differs from its integrated predecessor in only CaughtPanel | Checked within those scopes; no claim about every visual angle |
| Old save recovery and safe Continue | ../normal-startup/ONLINE.md and real-test-store ordinary-startup/fresh-process schema3 rejoin qualification; unchanged persistence sources in current candidate | Qualified for explicit fixtures/scenarios; no universal historical-save claim |
| CLI, compilation and strict checking | current-cli-qualification.json: TWO private13 runs each78 suites/468967 top-level passes/0. ../integration/full-cli-receipt.json: normal Windows command on integrated/font273 sources,79 suites/468979 passes/0, terminal exit0; all273 compile/strict. github-ci.json: Linux integration CI40067737217 success for compile/strict/all suites/exports/runner regressions | Standard full checks completed; exact baseline cohort preserved at Git6dd5ac67. Later notebook-only change has1784 focused passes/0, compile/strict and new exports. Exact Linux assertion counts, native rendering, universal flake probability and later edits are not inferred |
| Foreground real-engine self-test | ../native-integrated: 274 passes / 0 failures / 0 skips, 591s; exact 274-source guard, local SelfTest copy, normal test-store adapter | Completed. Scripted Studio component/region tests; not standalone or full natural lifecycle. Ten CreatorWarning records retained |
| Published/standalone client startup and saves | ../private-player/qualification.json, publication screenshots and exact 274-source pre/post guards; private published version 13, access/reach Private; two complete standalone 90s probes and ordinary New Life entry | Publication and two arrivals verified. Normal test store/fresh owners; production and retired QA actors untouched. No direct runtime PlaceVersion query/download rehash or new full save/rest/rejoin loop |
| Natural life loop, all modes and predator endings | Deterministic life/feeding/predator suites and scripted self-test components | Scripted setup or isolated death check is not the requested complete natural life in every mode; broader native coverage remains |
| Camera, held prey, grapple, meshes and seams in both tiers | Collision/streaming suites, streamed-out holds, automated region/self-test checks; ../outdoor-seams verifies four repaired hut edges at both tiers,8 walks/8 hops through9960 attached walking frames | Selected hut edges qualified; whole-map close visual sweep, all meshes/grapple angles and every edge/rearrival remain unproved |
| Controls, switching and accessibility | Input/settings/menu suites; six native normal/large-text reflow/scroll cases; title clipping corrected; ../touch-labels/native-font.json:16 actual buttons and40 candidate native layout cases,0 failures versus13 Legacy failures | Font fix verified in unpublished candidate; private13 still has Legacy text. Ordinary New Life observed; actual touch controls were not enabled/forced in Studio. Complete controller/touch comfort and every accessibility path remain; no physical-phone result |
| Eight-scene full/low performance matrix | ../performance-matrix/PAIR2.md and pair2-comparison.json: four current runs/36 workloads,8 guards,0 CreatorErrors,cleanup,0 camera mismatches at.01; scene/actor/weather/viewport match within each tier, current-policy comparator and4805 equivalence checks. Older cohorts retain their scopes | Matched current pair completed. Full means -2.8% to +3.2%; low mostly near16.67ms with night hut+3.3%, including80.61ms hitch. One pair per tier with live actors/GC does not establish a causal/general gain or statistical non-regression. Physical-phone proof remains conditional on access |
| Startup/load and memory | Earlier Player startup probes remain; ../camera-handover/trace30-summary.md: completed1800s native garden route,102888 attached frames/44 turns,0 findings/loading/menu-rest pause/focus events; both277-source guards and native PASS,0 script errors. Five-minute heap/engine/instance windows retained | Bounded route memory evidence now complete: fluctuating heap, final2054KB below start; no steadily rising floor observed. Not universal leak freedom, natural lives, all seams or phone proof. Long trace has no frame-time percentiles. Earlier standalone startup gap remains unresolved |
| Module/runtime inventory | integrated-source/MAP.md and inventory.json index the pre-hut-repair273-source cohort:65161 lines,435 lexical runtime sites;13 files over800 lines. The later repair changes two existing modules; all273 current sources compile/type-check | Historical lexical index with the repair supplement above; semantic dependency/cadence/cleanup review not inferred |
| Code and authority review | SECURITY-CURRENT.md reconciles actual message/ownership boundaries; historical CODE-REVIEW.md, persistence qualification and current source index | Scoped boundary review complete; exhaustive module semantics and hostile native traffic remain unproved. Solo life remains client-authoritative; validation is not anti-cheat. Large architecture changes remain proposals |
| Data schema and world maps | DATA-CURRENT.md reconciles record families, fields/readers/writers, bounds, ownership and compatibility; integrated-world/MAP.md retains the pre-repair1404-record inventory. outdoor-seams/ground-equivalence.json supplements it with33 new regions and exact unchanged map/physics/decor data for all233 old regions | Record reconciliation and scoped additive-data proof; per-species graph semantics, exhaustive historical fixtures and native close visual/collision coverage remain |
| Biology, strings, audio and captions | CONTENT-CURRENT.md records50 pages/body-text bounds; Luna reconciliation; opened MDC account supports applied first-page chelicerae/size correction, generator repeatability and1784 focused checks | Correction applied on integration branch, not published; frozen originals retained. Other49 pages not fully re-audited; new notebook native layout, UI strings, audible balance, asset permission/playback and captions not all verified |
| Named audit deliverables | MAP.md, FINDINGS.md, PERFORMANCE.md, CODE-REVIEW.md, SECURITY.md, TESTS.md exist; current integrated map and this ledger supplement them | Presence is not current completeness. Historical content stays labelled; unfinished rows remain open |
| Release, main and laptop sync | Exact models/guards and private version13 publication receipt; post-publication read-only ../private-player/production-after.txt/.png still confirms production published140; chet/save-continue.md is the operational handoff | Private test only. Cloud production source bytes not identified by UI. Normal source activation is complete in the integration worktree; main/laptop synchronization, production release and final verdict remain |

The human's "Publish private test build" authorization has been fulfilled for
existing private Windowsill Save Tests, place109879630247781. Two standalone
arrivals completed with the bounded read-only probe. The second complete CLI
repeat finished exit0. The unpublished font candidate's local Studio check is
complete and editor4880 is closed. Before/after273-source guards passed;
40 candidate cases all fit. Unbound no-API/asset/style warnings remain recorded
in ../touch-labels; no FPS or physical-phone claim. Three/five CreatorWarning records in
the respective clients and the Studio asset warning remain documented. This
does not authorize production release, bypassing authentication/security,
publishing the separate SelfTest fixture, discarding old saves or declaring the
whole optimization/audit goal achieved.

Use this ledger and chet/save-continue.md to choose current work. Do not act on
an older "current" paragraph without checking its source and later evidence.
