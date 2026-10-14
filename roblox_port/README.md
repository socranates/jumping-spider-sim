# The Windowsill — active Roblox project

Open **TheWindowsill.rbxlx** in Roblox Studio and press **Play**. After updating Git, close/reopen the place so Studio reads the new file. Keep this folder name: `.gdignore` keeps the frozen Godot project from importing it. Scale remains 1 Godot WU = 1 stud; gravity is 35.

| Action | Keyboard/mouse | Gamepad | Touch |
|---|---|---|---|
| Walk relative to camera | WASD | Left stick or D-pad | Directional buttons |
| Creep | Hold Shift | Hold L1 | Hold Creep |
| Hop / aimed jump | Tap / hold Space, release | Tap / hold A, release | Tap / hold Jump, release |
| Camera | Right-drag, wheel | Roblox camera/right stick | Roblox camera drag/pinch |
| Reset prototype | R | Y | Not yet exposed |
| Compare gait | G | — | — |

Aimed jumps target the screen center. Input clears on window focus loss, text-box focus and controller disconnect. Basic bindings are implemented; real tablet/controller feel and accessibility/remapping remain acceptance work.

The first appearance is `src/Shared/Data/Appearances.luau`, separate from species and physics. It keeps the selected black-and-white pattern at every recorded stage. The rig uses anchored noncolliding parts and one BulkMoveTo per frame. Growth, hunger/softness and full pose/twitch parity still need the LIFE port.

## Build and verify

- Pure checks: `python tests/run.py path/to/luau` (0.742 tested): **43/43** on Windows, including the original 35 golden jump/support checks.
- Build: `python tools/build.py path/to/rojo` (7.7.1 tested). Rebuilds the playable place and TheWindowsillTests.rbxlx and stamps an evidence ID from source/test/project bytes.
- Engine checks: open **TheWindowsillTests.rbxlx**, press Play, inspect Output for `PORT_TEST_REPORT`. The report also lives in TestService.PortTestReport. **6/6** on Windows Studio 0.742; this count includes suite completion. Normal place excludes these scripts.
- A missing report or a failed row is not a pass. Preserve JSON and evidence under docs/verification. Pure CLI shims cannot validate engine contacts or rendering.
- Generate species/surface data with `python tools/json_to_luau.py`. Keep Godot tuning as the source; document any intentional design changes.

Full inventory, test policy, server/filtering/save requirements and proposed order: [ROBLOX_PORT.md](../docs/ROBLOX_PORT.md). Current results: [roblox-first](../docs/verification/roblox-first/RESULTS.md). No Roblox-aware strict type-check result is claimed for this revision.

The line is currently **drawn only**. Catch/hang/reel/lower/let-go are the recommended next chunk. Perception, flies, LIFE, wasp, notebook, menus/settings and saves remain to port. Initial publication uses solo servers (maximum players 1); that publishing setting has not been configured here. No experience was published by this build.
