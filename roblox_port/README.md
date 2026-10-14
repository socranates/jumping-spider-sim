# The Windowsill — active Roblox project

Open **TheWindowsill.rbxlx** in Roblox Studio and press **Play**. After updating Git, close/reopen the place so Studio reads the new file. Keep this folder name: `.gdignore` keeps the frozen Godot project from importing it. Scale remains 1 Godot WU = 1 stud; gravity is 35.

## Controls: one scheme, as in the Godot game

Every action of the frozen Godot game (`scripts/core/input_setup.gd` and its README) against the port. Keyboard and mouse, a controller and touch work together: an action is held while any of them holds it (ROBLOX-08). The words on screen name the device you used last. H shows or hides the controls card.

| Godot action | Keyboard and mouse | Controller | Touch | In the port |
|---|---|---|---|---|
| Walk (move_*) | WASD | Left stick (D-pad too) | Arrow buttons | Ported: relative to the view on floors, walls and undersides; holding the stick carries the spider over sharp edges instead of turning back (Godot's carry) |
| Look (look_*) | Mouse (locked to the centre), arrow keys | Right stick | Drag anywhere off the buttons | Ported |
| Stalk | Hold Shift | Hold LB | Hold Creep | Ported |
| Hop (prepare_jump, tap) | Tap Space | Tap A | Tap Jump | Ported: 1.5 forward, planned like a leap; refused with a reason |
| Aim a leap (prepare_jump, hold) | Hold Space 0.15 s | Hold A | Hold Jump | Ported: the spider holds still and turns to the centre dot; the patch says Reachable / Blocked / Out of reach / Can't land there; the safety-line note says whether a miss will be caught; vertical look tilts the view |
| Leap (release) | Release Space | Release A | Release Jump | Ported: only a green Reachable patch launches; anything else launches nothing and says why |
| Cancel | Q | B | Cancel | Ported, context rules as Godot: cancels a press or an aim with no penalty; stops a walk to the edge (and is nothing else's then) |
| Let go of the line (cancel, held) | Hold Q | Hold B | Hold Let go (the Cancel button, relabelled on the line) | Ported: counts only a fresh press 0.4 s after the catch, then a 0.6 s hold; a press held from before never lets go |
| Reel in (reel) | W | Stick up | ↑ | Ported, on the line only |
| Lower (lower) | S | Stick down | ↓ | Ported, on the line only |
| Let down on a line (drop_line) | F; hold to keep lowering | X (Godot: D-pad down) | Silk | Ported: on a wall or underside at once; on top of a leaf it walks to the nearest usable edge first |
| Recenter | R or middle mouse | Right-stick click | Recenter | Ported |
| Focus | Hold right mouse | Hold LT | — | Ported as the body turning toward where the view points; perception itself is not ported yet |
| Spider-eye view (eye_view) | V | Y | Eye | Ported: view at the principal eyes, walking relative to the gaze; no retinal/colour rendering yet |
| Slow motion | T | RT | — | Ported at 50 % for the spider (the whole world when more of it exists) |
| Pause | Esc | Menu | Roblox menu button | Roblox's own menu (reserved by Roblox): the game drops every press and hold and waits until it closes |
| Field notes (help) | H | View | — | Deferred (notebook not ported). H shows the port's controls card instead |
| Interact: eat, rest (interact) | E | X | — | Deferred: no prey or retreat yet. The controller's X is "let down on a line" in the port; settle that when feeding arrives |
| Notebook | N | D-pad up | — | Deferred (the port's D-pad walks) |
| Struggle grip (prepare_jump with prey) | Space | A | — | Deferred: no prey yet |
| Debug overlay, support view | F3, F4 | — | — | Deferred (developer views) |
| Settings in the pause panel | Esc | Menu | — | Deferred: sensitivity/invert, FOV, camera distance, stalk/aim/Focus toggles, jump arc, jump reach, hold-to-let-go switch, frame-the-line switch, remapping, assisted-play presets. The port uses Godot's defaults (hold to let go on, framing on, arc shown) |
| Back to the start (port only) | Backspace | View | — | Port only |
| Zoom (port only) | Wheel | — | — | Port only, 2 to 12 studs |
| Compare gait (port only) | G | — | — | Port only |

Input clears on window focus loss, text-box focus, the Roblox menu and controller disconnect. Real tablet/controller feel and accessibility/remapping remain acceptance work.

The spider is fuzzy: thin hairs lying back over the head and abdomen (white over the white markings), eyebrow tufts, hairy legs with a front-leg fringe, and two see-through fur shells. All of it is in `Appearances.fuzz`. Touch-only devices get a third of the hairs until a real tablet is measured.

The first appearance is `src/Shared/Data/Appearances.luau`, separate from species and physics. It keeps the selected black-and-white pattern at every recorded stage. The rig uses anchored noncolliding parts and one BulkMoveTo per frame. Growth, hunger/softness and full pose/twitch parity still need the LIFE port.

## Build and verify

- Pure and smoke checks: `python tests/run.py path/to/luau` (0.742 tested) prints three lines. **SUMMARY 182/182**: pure logic and Godot goldens (the original 35 jump/support checks, tether, camera and line-framing goldens, input, jump phases, device words, prompt layout, stick carry). **BOXWORLD 15/15**: the recovery scenarios (`tests/studio/RecoveryScenarios.luau`) and Chet's silk spec on an emulation of raycasts and sphere casts against axis-aligned boxes. **CLIENT 11/11**: the client scripts themselves with stub services and simulated keys. The last two are smoke tests, not engine evidence. Linux, branch claude/roblox-controls-recovery.
- Build: `python tools/build.py path/to/rojo` (7.7.1 tested). Rebuilds the playable place and TheWindowsillTests.rbxlx and stamps an evidence ID from source/test/project bytes (**2a5c87b3843fbc0d** for this branch).
- Engine checks: open **TheWindowsillTests.rbxlx**, press Play, inspect Output for `PORT_TEST_REPORT` (also in TestService.PortTestReport). This branch expects **39 rows** (Spec 7, SilkSpec 11, RecoveryScenarios 14, PromptSpec 3, four completion rows) and **7** client playback rows; **not run yet**. The last Windows result was 18/18 plus 3/3 before the merge. Collect matching rows/summary and PORT_CLIENT_REPORT with `python tools/collect_studio_report.py path/to/Studio.log ../docs/verification/<folder>`. Normal place excludes these scripts.
- Strict type check: `rojo sourcemap default.project.json -o sourcemap.json`, then `luau-lsp analyze --platform roblox --definitions=globalTypes.d.luau --sourcemap sourcemap.json src` (luau-lsp 1.70.1): 0 diagnostics.
- A missing report or a failed row is not a pass. Preserve JSON and evidence under docs/verification. Pure CLI shims cannot validate engine contacts or rendering.
- Generate species/surface data with `python tools/json_to_luau.py`. Keep Godot tuning as the source; document any intentional design changes.
- Goldens from the frozen Godot code (from the repository root), then `python tools/reference_to_luau.py tests/<name>.json` from `roblox_port/`: `godot --headless --path . -s roblox_port/tools/export_camera_reference.gd -- roblox_port/tests/camera_reference.json`, the same with `export_framing_reference.gd` and `framing_reference.json`; tether goldens with `python tools/export_tether_golden.py path/to/godot`.
- Look preview without Roblox: `python tools/preview/preview.py path/to/luau path/to/godot out_dir` runs the real rig code under preview stand-ins and renders its parts in Godot. A layout check only, not Roblox rendering.

Full inventory, test policy, server/filtering/save requirements and proposed order: [ROBLOX_PORT.md](../docs/ROBLOX_PORT.md). Current results: [roblox-controls-recovery](../docs/verification/roblox-controls-recovery/RESULTS.md) (Linux) and [roblox-silk](../docs/verification/roblox-silk/RESULTS.md) (the last Windows Studio run). Handoff: [HANDOFF-roblox-controls-recovery.md](../docs/HANDOFF-roblox-controls-recovery.md).

Core catch/hang/reel/lower/let-go, edge-first lowering, the capped catch camera and one control scheme are implemented; Studio and physical-device acceptance are next. Perception, flies, LIFE, wasp, notebook, menus/settings and saves remain to port. Initial publication uses solo servers (maximum players 1); that publishing setting has not been configured here. No experience was published by this build.
