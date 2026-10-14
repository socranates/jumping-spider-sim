# Roblox first-spider Windows check — 2026-10-14

Source/test/project evidence: **5b14ae68fed28794** (tools/build.py; excludes its generated BuildInfo). Both Rojo places built with 7.7.1. Windows Studio **0.742.0.7421053**.

| Check | Result | Evidence / scope |
|---|---|---|
| Pure Luau | PASS 43/43 | luau-report.txt, Luau 0.742: 35 inherited golden jump/support checks + 8 appearance/input checks |
| Real Roblox engine | PASS 6/6 | studio-report.json: real-vector trajectory, raycast foot planting, stable white markings, display-only parts/budget, finite air/underside poses, suite completion |
| Syntax | PASS 17 files | syntax-report.txt; compiler only, no Roblox-aware strict type-check claim |
| Studio view | PASS limited smoke | studio-spider.jpg: first appearance, warm lighting and banded legs visible in native Play session |
| Keyboard tap hop | PASS limited smoke | Observed movement and newly drawn silk after Space; not full aimed-jump/edge acceptance |
| Actual touch/tablet | NOT RUN | Buttons/input state implemented; physical touch and low-end frame time remain |
| Physical controller | NOT RUN | Bindings implemented; focus/camera/feel require hardware |
| Full walls/undersides/edge traversal | NOT RUN | Finite-pose test is not traversal acceptance |
| Godot full suite this round | NOT RUN | Inherited Linux 644/644 at c87ce00, evidence 87c44d9c8206, remains separate |
| Publishing / max players / saving | NOT RUN | Local place only; solo publication setting and DataStore setup remain |

First Studio run: 5/6 engine checks, plus inherited server script stopped at Lighting.Technology (runtime capability error). Moved that setting into the authored place. Changed color assertion to allow <1/255 storage rounding while checking exact before/after stage color. Rebuilt and reran: 6/6 and no CreatorError in the corrected run's log at inspection. Color tolerance is not used to hide a stage recoloring.

No new Godot implementation changes after c87ce00; the default black/white art applies to Roblox only. The rig is still a procedural prototype, not final realism. No tablet-performance or complete controls-parity claim. See ROBLOX_PORT.md for remaining behavior and acceptance plan.
