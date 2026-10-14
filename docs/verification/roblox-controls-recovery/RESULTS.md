# Roblox controls and recovery camera — verification, 2026-10-14 (Claude, Linux)

Branch `claude/roblox-controls-recovery`, based on main 432bc53 with Perplexity's 01fe0d1 merged. Source/test/project evidence **876253fd47783ce3** (tools/build.py). Luau CLI 0.742, luau-lsp 1.70.1, Rojo 7.7.1, Godot 4.7.2 (frozen reference c87ce00, only to export goldens). **Roblox Studio was not run**: this machine has no Roblox engine.

| Check | Result | Evidence and scope |
|---|---|---|
| Pure Luau | **PASS 182/182** | luau-report.txt. Chet's 115 and Perplexity's 20 (135 after the merge) plus 47 new: input sources (5), jump phases (11), device words (10), prompt layout (3), line framing against Godot (9), stick carry (9) |
| Godot goldens | PASS | tests/framing_reference.json is new, exported by tools/export_framing_reference.gd from the frozen camera_rig.gd/boom_math.gd (only `_good_view` replaced by a table). camera, framing and tether references were regenerated from Godot and came out byte-identical |
| Box-world scenarios | **PASS 15/15** | luau-report.txt. tests/studio/RecoveryScenarios.luau (14) run with the CLI's emulated raycasts and sphere casts against axis-aligned boxes, plus Chet's Studio silk spec unchanged (11 checks, 1 row) as a cross-check of the emulation. A smoke test of the real motor, silk, jump-input and camera code: **not** engine evidence |
| Client smoke | **PASS 11/11** | luau-report.txt. The real SpiderClient, SpiderInput, SpiderHud, SpiderCamera and SpiderRig on the box world with stub services; keys pressed through the bound ContextActionService callbacks, frames through the bound render step. Not rendering, devices or engine physics |
| Strict type check | **PASS, 0 diagnostics** | typecheck-report.txt: luau-lsp analyze with Roblox definitions and a Rojo sourcemap, all 23 files of src/ (all `--!strict`). The mode Perplexity used; Chet's silk modules needed type annotations only |
| Compile | **PASS 40/40** | compile-report.txt: every .luau under src, tests and tools |
| Places | Built | build-report.txt: both places rebuilt twice with identical bytes (SHA-256 recorded) |
| Studio engine suite | **NOT RUN** | 39 rows expected: Spec 7, SilkSpec 11, RecoveryScenarios 14, PromptSpec 3, plus 4 completion rows. Chet's 18/18 (d1a1cff5c06eafe3) is the last engine result |
| Studio client playback | **NOT RUN** | 7 rows expected (Chet's 3 plus: tap hop; Q cancels an aim; a key and a finger holding Cancel together; device-aware prompts on screen and a no-roll camera while hanging) |
| Physical controller, tablet touch, phone safe areas, frame time during catches | **NOT RUN** | Needs Nathan's or Chet's devices |

## The ten-miss sequence (box world)

All ten misses were caught and recovered: east leaf front and back, middle leaf front and back, west leaf front and west side, planter rim front (reeled back up), middle and east leaf front (lowered to the floor), west leaf front (let go after a deliberate hold, landed). Every tick: finite position and velocity, the body never inside the sill, the line never longer than its rest except on snagged ticks (as Godot's M03), the camera (fixtures 1 and 7 in the CLI, all ten in Studio) never rolled or entered the sill and never turned past 45 degrees. Before the ROBLOX-10 fix, five of the ten reels never took hold.

## The catch camera (box world)

A roofed canyon one stud wide, the spider hanging in it, no camera input. Player view across the canyon (yaw -90): no turn (a quarter turn is past the cap), boom 1.42, auto-pitch 60 degrees: as squeezed as without framing. 45 degrees off: turns exactly 45 (29 after 8 ticks), boom 4.44, smaller steps checked and refused. 30 off: turns 30. Along the canyon: no turn. No roll in any. A one-degree look, aiming, a recenter and the line ending each take the turn over with no jump.

## Found and fixed by the scenarios

- **ROBLOX-10:** SilkController set "shortest" whenever a reel could not shorten, including while snagged. A snag while the spider swung under a leaf then left reeling refused for good (the spider hung about 4 studs down showing "at the shortest line"). Godot sets it only in its not-snagged reel branch; the port now does too.
- **ROBLOX-11:** holding W at a leaf's edge flipped the spider between the top and the front face forever (on a wall, forward is up). Godot's stick carry is now ported.

## Reproduce

From roblox_port: `python3 tests/run.py path/to/luau` (prints SUMMARY, BOXWORLD and CLIENT), `python3 tools/build.py path/to/rojo`. Strict check: `rojo sourcemap default.project.json -o sourcemap.json`, then `luau-lsp analyze --platform roblox --definitions=globalTypes.d.luau --sourcemap sourcemap.json src` (definitions from the luau-lsp 1.70.1 repository's scripts folder). Goldens: from the repo root, `godot --headless --path . -s roblox_port/tools/export_framing_reference.gd -- roblox_port/tests/framing_reference.json`, then `python3 tools/reference_to_luau.py tests/framing_reference.json`.
