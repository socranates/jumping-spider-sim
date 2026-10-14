# The Windowsill — active Roblox project

Open **TheWindowsill.rbxlx** in Roblox Studio and press **Play**. After updating Git, close/reopen the place so Studio reads the new file. Keep this folder name: `.gdignore` keeps the frozen Godot project from importing it. Scale remains 1 Godot WU = 1 stud; gravity is 35.

Controls follow the frozen Godot game (`scripts/core/input_setup.gd`). H shows or hides the controls card.

| Action | Keyboard/mouse | Gamepad | Touch |
|---|---|---|---|
| Walk relative to the view | WASD | Left stick or D-pad | Directional buttons |
| Look | Mouse (locked to the centre while playing), arrow keys | Right stick | Drag anywhere off the buttons |
| Creep | Hold Shift | Hold LB | Hold Creep |
| Hop | Tap Space | Tap A | Tap Jump |
| Aim a leap | Hold Space (0.15 s): the spider holds still, the centre dot picks any surface | Hold A | Hold Jump |
| Leap | Release Space (only on a green "Reachable" patch) | Release A | Release Jump |
| Cancel the jump, or a walk to the edge | Q | B | Cancel / Let go |
| Lower on silk | F (hold to keep lowering) | X | Silk |
| Reel in / lower while hanging | W / S | Stick or D-pad up/down | Up/down buttons |
| Deliberately let go of the line | Hold Q | Hold B | Hold Cancel / Let go |
| Spider-eye view | V | Y | Eye |
| Recenter the view | R or middle mouse | Right-stick click | — |
| Focus (turn the body to look where the view points) | Hold right mouse | Hold LT | — |
| Slow motion (50 %) | T | RT | — |
| Zoom | Wheel | — | — |
| Back to the start | Backspace | View (Select) | — |
| Compare gait | G | — | — |

While aiming, looking up or down tilts the view itself, so you can aim above the spider; the landing patch and text say Reachable (green), Blocked (amber), Out of reach (red) or Can't land there (violet), with the reason. A refused release launches nothing. Every leap from ground that holds silk pays out a safety line: a miss is caught, and on the line W/up reels in, S/down lowers and a deliberate hold of Q / B / Let go lets go (0.4 s grace after the catch, then a fresh 0.6 s hold; a press held from before cannot release). Input clears on window focus loss, text-box focus and controller disconnect. Real tablet/controller feel and accessibility/remapping remain acceptance work.

The spider is fuzzy: thin hairs lying back over the head and abdomen (white over the white markings), eyebrow tufts, hairy legs with a front-leg fringe, and two see-through fur shells. All of it is in `Appearances.fuzz`. Touch-only devices get a third of the hairs until a real tablet is measured.

The first appearance is `src/Shared/Data/Appearances.luau`, separate from species and physics. It keeps the selected black-and-white pattern at every recorded stage. The rig uses anchored noncolliding parts and one BulkMoveTo per frame. Growth, hunger/softness and full pose/twitch parity still need the LIFE port.

## Build and verify

- Pure checks: `python tests/run.py path/to/luau` (0.742 tested): **135/135** on Linux for the merge of Chet's silk (115/115 on Windows) and Perplexity's controls (63/63 on Linux), including the original 35 golden jump/support checks, the tether goldens and 11 camera/stick checks against `tests/camera_reference.json`, exported from the Godot rig by `tools/export_camera_reference.gd`.
- Build: `python tools/build.py path/to/rojo` (7.7.1 tested). Rebuilds the playable place and TheWindowsillTests.rbxlx and stamps an evidence ID from source/test/project bytes.
- Engine checks: open **TheWindowsillTests.rbxlx**, press Play, inspect Output for `PORT_TEST_REPORT`. The report also lives in TestService.PortTestReport. **18/18** on Windows Studio 0.742 before the merge (two suite-completion rows), plus **3/3** actual-client scripted checks; the merged suite adds Perplexity's two rig checks and has not been run in Studio yet. Collect matching rows/summary and PORT_CLIENT_REPORT with `python tools/collect_studio_report.py path/to/Studio.log ../docs/verification/<folder>`. Normal place excludes these scripts.
- A missing report or a failed row is not a pass. Preserve JSON and evidence under docs/verification. Pure CLI shims cannot validate engine contacts or rendering.
- Generate species/surface data with `python tools/json_to_luau.py`. Keep Godot tuning as the source; document any intentional design changes.
- Camera goldens: from the repository root, `godot --headless --path . -s roblox_port/tools/export_camera_reference.gd -- roblox_port/tests/camera_reference.json`, then `python tools/reference_to_luau.py tests/camera_reference.json` from `roblox_port/`.
- Look preview without Roblox: `python tools/preview/preview.py path/to/luau path/to/godot out_dir` runs the real rig code under preview stand-ins and renders its parts in Godot. A layout check only, not Roblox rendering.

Full inventory, test policy, server/filtering/save requirements and proposed order: [ROBLOX_PORT.md](../docs/ROBLOX_PORT.md). Current results: [roblox-silk](../docs/verification/roblox-silk/RESULTS.md) (Windows) and [roblox-controls-fuzz](../docs/verification/roblox-controls-fuzz/RESULTS.md) (Linux).

Core catch/hang/reel/lower/let-go and edge-first lowering are implemented. Recovery camera framing and physical-device acceptance are next; see [the silk handoff](../docs/HANDOFF-roblox-silk.md). Perception, flies, LIFE, wasp, notebook, menus/settings and saves remain to port. Initial publication uses solo servers (maximum players 1); that publishing setting has not been configured here. No experience was published by this build.
