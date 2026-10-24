# Native performance matrix — in progress, 2026-10-24

This is an unpublished local Studio benchmark of the normal273-source integration
candidate. It retains ordinary presentation, lighting, cat and other creatures.
The three extra modules are the observer, timing probe and yielding in-memory
storage adapter. The normal persistence/composition route runs against that
adapter; there is no DataStoreService call, real key, old PortTests runner or
SilkPlayback. Every model refuses non-Studio or bound GameId/PlaceId execution.

The game sources in roblox_port and both normal exports are unchanged by this
work. build.py derives276-source test copies, compiles/strict-checks them,
checks exported source identity/enablement, and writes a model/source manifest
and a before/after native source guard. Never publish these models.

## Workload and limits

The fixture enters through the ordinary Free play choice, then makes new Free
play lives using the displayed offer identity. It places the spider at authored
spawns, fixes only the weather clock, warms each scene for5 action seconds,
and records20 action seconds. Simulation, movement, AI and animation keep
running. The final sample drives the real input state across three garden
regions without transport during measurement. A failed route is a failed case,
not silently substituted with teleports. This is a scripted workload; it does
not complete natural lives, manual traversal/comfort, online storage, physical
phones, or the separate30-minute memory requirement.

Scenes: dawn sill; night hut desk/lamp; rainy garden (day4/hour9); windy meadow
(day2/hour12); active pond; bin; doorway; night bench/lamppost; three-region walk.
The can/doorway row has two subscenes. Seed914, camera parameters, viewport,
actual support/region, live action duration and weather are recorded.

Full and low tiers need separate native runs. The eventual paired comparator
uses the exact same game sources, fixtures and authored settings except the
previously qualified LookPlan cache: before comes from bd67582b, after from
the current normal tree. No general gain follows from a single after sample.
Heap deltas include collections and cannot by themselves prove leaks. Local
network counters do not represent public-server traffic.

The probe records whole-frame mean/p95/p99/max, render callback parts, engine
counters, instance counts, Lua-heap deltas and network
counters where available. Unsupported counters are retained as unavailable.
The formal pair1 fixture also mounts look-method timings; the earlier complete
attempt3 did not mount that watcher. Collect formal pairs with --require-methods.
Rows are emitted separately so a long JSON message cannot silently truncate
an entire report. collect.py rejects malformed/truncated events and incomplete
scope unless explicitly collecting a labelled failed/partial attempt.

## Retained attempts

- Attempt1, after/full: model1d788da2041022c0114494e14dd25ae493b9307bdc293880085ff551af1a90d7,
  native run1792822314622. Both276-source guards passed. The dawn sill sample
  completed1190 frames/20.016s, mean16.820ms,p9519.066ms,max30.180ms,no frames
  over50ms. The fixture then timed out waiting for another new life. Its bare
  fresh() omitted the required displayed offer ID after an offer arrived.
  SaveContinuation.choose intentionally refuses that; save_continuation.luau
  already tests the rule. This is a retained fixture failure, not a completed
  matrix or evidence that a game restart is broken. The model/editor stopped,
  postguard passed, and the XML was closed without saving temporary editor
  state. attempt1/final-collected retains both guards, bounded events, warnings,
  failure and raw sample. Earlier attempt1/collected predates the postguard.
- Attempt2, after/full: model9ccffffb597006632d0f4c4d36fe1f17395a6ff88bb52a5cf5ea6abb5d753665,
  native run1792822796749.
  The fixture now reads the actual displayed offer ID and immediately asserts
  that a new intent was submitted. It refuses to bypass protected-New workflow.
  The new-life stall disappeared, confirming that the missing ID was a fixture
  mistake. All eight stationary20s samples completed, mean16.73–20.30ms,
  p9518.97–28.95ms. The90s walk covered222.306studs west through garden_a1,
  verge_-300_-116 and verge_-400_-116, ended attached/live and had0 frames over50ms
  (max48.423ms). It failed the intended eastward garden route assertion.
  place()/snap() recentered the view after the fixture assigned yaw, reversing
  the Right input. These pilot camera orientations were therefore not the
  intended views. The pond_a1 arrival was also too far from the actual frog
  seat for close-view coverage. Both276-source guards passed; Play stopped,
  the unmodified XML was closed without saving editor state. Original events,
  all ten sample summaries and the failure are in attempt2/collected. Snapshot
  observations occurred during this pilot, so its maxima may include observation
  overhead; no before/after gain is claimed.
- Attempt3, after/full: model423a27a2aedd23c3cdc2b6c4fe5b590c261ccb6e3a64f9bd777a451f67147e66.
  Camera assignment now follows placement/recenter, with actual camera rows.
  The pond arrival uses the frog's authored support piece, asserts a nearby
  on-screen frog and active damselflies, and emits a separate actor record.
  All276 sources compiled and strict passed. Native run1792823359752 completed
  PASS, all nine workload samples, both source guards and save cleanup. The
  original output and actor/camera data are in attempt3/collected; RESULTS.md
  contains the derived table and its limits. StudioPID18160 stopped and closed
  without saving temporary editor state. No UI snapshots or heavy local tools
  ran during the samples. Look-method watcher was not mounted in this cohort.

Attempt3 local model:
C:/Users/natha/claude-xfer/Windowsill-matrix-after-full-attempt3/Windowsill-matrix.rbxlx

Attempt3 log:
C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T062821Z_Studio_29E2D_last.log

## Formal paired models

pair1-builds.json qualifies four prepared models in claude-xfer:
Windowsill-matrix-{after,before}-{full,low}-pair1/Windowsill-matrix.rbxlx.
Each276-source model compiled and passed strict analysis. Before/after sources
differ only in Shared.World.LookPlan. Full/low sources are identical; the
authored Detail setting differs. Lighting/material settings are preserved.
Every model uses the same updated observer with the look-method watcher mounted.

These four models subsequently ran serially: all36 workload samples and
original PASS, both guards per run. See PAIR1.md and pair1-comparison.json/.md.
The comparator records conditions_matched=false because of18 actual FOV
deviations outside the original.01 tolerance. These descriptive observations
do not establish a general gain. The exposed camera handover defect and its
later targeted fix are in ../camera-handover; do not rewrite these old inputs.
The completed attempt3 remains a separate, differently instrumented cohort.

Full/low native coverage is complete for these pre-camera-fix fixtures. A
qualified matched-lens comparison,30-minute memory and broader device/comfort
checks remain pending. build.py --long-trace-seconds1800 prepares an unbound
follow-up; it adds one observer module and requires its complete trace in the
collector. It has compiled/strict-passed but has not executed natively yet.
No production publication or general optimization claim follows from this harness.
