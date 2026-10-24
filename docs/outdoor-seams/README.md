# Native outdoor crossing exercise

2026-10-24, game-source cohort at863f188b/evidence2b1c99cacf601b8f.
Six independent authored arrivals, followed by actual movement through the
ordinary SpiderInput path and a short Jump press. Movement is not transported
after a route starts. Ordinary creatures remain enabled; Free-play rules and a
fixed weather clock keep this a bounded collision fixture, not a natural life.
No game source or published place changed.

| Route | Start region | Target coordinate | Crossing |
|---|---|---:|---|
| path_west | path_m1 | X=-115 | path to western soil infill and next soil cell |
| path_east | path_m2 | X=-5 | path to eastern soil shoulder |
| path_north | path_m4 | Z=-536 | path end to pad_a2 |
| pad_meadow | pad_c2,(-20,-84.29,-808) | Z=-838 | gravel pad to meadow_a3 |
| mown_north | mown_e1 | Z=-750 | mown corridor to northern soil |
| mown_south | mown_e1 | Z=-610 | mown corridor to southern soil cells |

Both full and low models compiled276/276 and passed strict checking. Their
source dictionaries are identical, with authored Detail differing. Neither
model has an online store path; the fresh synthetic QA key is in an unbound
yielding MemoryBackend. Sources are guarded before and after native Play.

| Detail | Native run | Walks/hops | Walking frames, all attached | Hop observation frames | Script errors/warnings |
|---|---|---|---:|---:|---|
| full |1792829521568|6/6 PASS|6836|89|0/8|
| low |1792829941365|6/6 PASS|7484|119|0/8|

All routes reached their target, remained alive, had zero loading frames and
finished attached. Minimum walkingY=-84.29001 throughout. All twelve tap jumps
freshly launched, showed air frames and landed attached, travelling about1.707
studs. Both source guards and save-fixture cleanup passed in each run. Both
completed native SEAM_END and MATRIX_FRAME_PASS, with zero focus-loss events.
full/ and low/ retain bounded original output, parsed rows and manifests.

Full model SHA256:8b18c9e30c5044fd78ef837396cf82be1391ebcfeffcc4427d2325462aed6b28.
Low model SHA256:b8aefcef2856e1215060d3006f195bfd396d83371a74611b62ac8d064dc5790a.
Local stages are C:/Users/natha/claude-xfer/Windowsill-outdoor-seams-{full,low}-attempt3.
Earlier preparation-only full attempts1/2 were not executed; the observer's
messages were split/bounded and a lint warning corrected before attempt3.
Both used editors stopped and closed without saving temporary editor state.

## Visual and evidence limits

Direct native observations included the full-detail soil beside the path and
mown approach, and the low-detail mown/soil crossing. No hole or fall appeared
at those observed views. This was not every frame/angle, wall, mesh, can or
grapple pose. UI snapshots occurred during this collision exercise; its frame
profiler output is not an FPS comparison and is intentionally excluded from
the collected results. Prey counts/projection are diagnostic telemetry, not
proof that every projected insect was visible through scenery or perceived.

This is12 selected route cases, not all233 walkable regions, physical input
comfort, natural lives or standalone network streaming. In particular, the
outer hut path south/east/north lies outside Verge's current infill rectangles;
those edges need a separate native reproduction. Do not use these passing
northern/pond routes to declare every reported off-path fall fixed.

## Reproduction

Build an isolated model with ../performance-matrix/build.py --tier full (or low)
--variant after --playback-source docs/outdoor-seams/playback.luau and a fresh
--out path. Guard before, Play, retain original completion, stop, refocus
commandbar and execute the postguard. collect.py requires both guards and the
six route/hop records. --allow-failure preserves a failed exercise without
reclassifying it as passed. Never publish these diagnostic models.
