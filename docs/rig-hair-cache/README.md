# Cache fixed leg-hair turns — 2026-10-24

Candidate game evidence **032b5985ac17eeb2**, 273 ordinary sources,
source/test/export commit **dd21210557990e0c0040b8028a714201de12e9d2**.
Only `Shared/Rig/SpiderRig.luau` changes among ordinary game modules.
No new publication. Private test13 and production140 remain historical release
boundaries; their earlier authorization is already fulfilled.

## Change and cost

Each moving leg hair previously rebuilt a look-at CFrame from two translated
points every draw. Its direction is fixed in the leg segment's local frame.
The rig now constructs that local turn once and refreshes its half-length
offset only when growth scale changes. Draw still computes the current root
position and transforms it with the current segment frame. Ordinary hairs and
fringe use the same cache. Extra memory is one CFrame and one Vector3 per hair.

No geometry, part count, movement solver, update tolerance, batching policy,
lighting, controls, save schema or ecology change is intended. Existing cue
and movement suites supplement the explicit geometry comparison below.

## Regression evidence

`tests/rig_hair_reference.luau` is the byte-for-byte old rig from c5b61262,
not a reimplementation of its formula. The reusable studio check constructs
both actual modules with all seven appearances in full and low detail. It
compares every created BasePart over growth changes, floor/wall/ceiling,
walking, hanging/recovery, focus, feeding pulse, jump load/push, condition,
softness, grooming and alarm. It does not enumerate every possible special
dance/threat pose; related pre-existing suites cover additional behavior.

- Baseline `baseline-red.txt`: geometry28/0; operation-saving gate fails,
  47,280 lookAt calls on both sides, zero removed versus18,160 expected.
- Candidate `green.txt`:29/0,14 cases,560 frames,143,800 part comparisons.
  lookAt calls47,280→29,120:18,160 removed (38.4% of this rig fixture's
  lookAt calls, **not** 38.4% less frame time). Shim position/size differences
  zero; maximum axis-vector difference1.685e-15.
- `related-tests.txt`: LOOK1442, IDLE5719, PEACOCK272, ANTMIMIC89,
  TARANTULA86, BODIES3610:11,218/0. With the new29:11,247/0 local checks.
- `compile.json`:273/273 at O0. `strict.txt`:zero diagnostics.
  `runner.txt`:5/5 runner tests; missing-suite messages are intentional
  negative cases. `exports.txt`:both ordinary/source-exact exports pass.
- `red.txt` retains the earlier harness-loading failure, which was fixed by
  deferring the reference factory until module loaders exist. It is not the
  optimization's baseline regression result.

Full CI run40093189495 is dispatched for the exact source commit. Until its
receipt is added, all80-suite success remains pending; older79-suite success
does not qualify this change.

## Native engine geometry comparison

`prepare.py` derives a separate unpublished fixture with explicit pointer
release for native profiler UI work. Its278 sources are the273 game sources,
three memory-only diagnostics, frozen rig and comparison helper. All278
compile/type-check. `native.json` records run1792843345517:

- 28/0 native checks,14 cases,560 frames,143,800 actual part comparisons.
- Maximum position and size differences0; maximum axis-vector delta
  0.0000010264509455737426, within the unchanged0.0002 bound.
- Both278-source guards pass before/after Play. Zero CreatorErrors; six
  retained warnings include Studio CornerRadius casts and asset203785492's
  type mismatch. Cleanup is asserted before final fixture PASS.

Staged model SHA256:
`b0a761a85267ff5f6aa515fe58b31149a1270ca0136867a7d38b8adae0c86f7b`.
The editor was stopped and closed without saving, PID25460 exited, and the
original file hash still matches. The diagnostic is not in ordinary exports.

The preceding20-second rainy-garden sample has1200 frames, mean16.679ms,
p9518.141ms, max24.313ms and no frames>33ms at1360×441. It is one current
diagnostic workload, **not a matched before/after performance comparison**.
The fixture's startup sample still includes a3694.89ms interval; early startup
work remains unresolved.

## Fresh native profiler captures

After PASS, with the profiler visibly unpaused, the Developer Console Server
tab accepted60 frames/4 seconds, showed Recording, and created the new file
at12:09:06Z. A later Ctrl+P pause and legacy128-frame client dump created a
different file at12:13:25Z. `profiles.json` retains original paths/hashes;
curated viewer-exported summaries omit the raw machine inventory.

| Dump | Frames | CPU median/mean/max ms | GPU Scene maximum ms |
|---|---:|---:|---:|
| Later paused client |128|18.72 /20.61 /121.02|24.36|
| Fresh Server-tab request |60|24.04 /25.76 /120.97|24.36|

The fresh server request is now obtained, unlike the older failed attempt.
Frame summary values differ, but several scope totals/maxima repeat exactly
between files (including GPU Scene24.357019ms and Sleep247.118851ms maxima).
Aggregate independence remains unproved; file freshness alone is insufficient.
It still contains local render/GPU/client scopes in the same Studio process;
**isolated dedicated-server timing is not qualified**. The captures have
different frame windows, nearby console/profiler interaction and a larger
1360×549 draw area than the action sample. They are neither paired FPS proof
nor startup traces. Retain the long frames rather than declaring them solved.

Marker CSV exports each say `frames,60`, including the128-frame client dump:
their aggregate selection is60 frames. Do not use those values as averages
over all128 captured frames. Nested scopes overlap, aliased labels can repeat,
and Runtime::Sleep is not busy CPU; do not sum them or infer a bottleneck
inside an individual API solely from its label. The client selected window's
SpiderClient mean/max is5.618/7.344ms; it is not directly comparable to earlier
lap summaries. Raw HTML stays local. Temporary viewer tabs and the127.0.0.1
HTTP process11080 are closed.

## Remaining audit

The fixed calculation saving and native appearance equivalence are qualified.
This does not establish total FPS savings, hitch removal, complete world
clipping coverage, a natural full life, real-store rejoin, controller comfort,
physical-phone performance or broad audio/content correctness. Follow
`../audit/HEALTH-CURRENT.md`; pursue early startup attribution and dedicated
server/device coverage without repeating already completed matched runs.
