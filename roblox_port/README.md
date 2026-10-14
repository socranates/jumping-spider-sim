# The Windowsill — Roblox port (scaffold)

A Roblox Studio (Luau) port of the Godot game, started 2026-10-14 (DECISIONS VISUAL-01). Godot ignores this folder (`.gdignore`).

**Scale:** 1 Godot WU = 1 cm = **1 stud**. Every number in `data/*.json` and in the windowsill layout is copied unchanged; the spider is about 1 stud long and `Workspace.Gravity` is 35.

## Play it in Studio

1. Open `TheWindowsill.rbxlx` (built by `rojo build default.project.json -o TheWindowsill.rbxlx`) in Roblox Studio, or install [Rojo](https://rojo.space) and run `rojo serve` with the Rojo Studio plugin to live-sync.
2. Press **Play**.

| Key | Does |
|---|---|
| W A S D | walk, relative to the camera, on the floor, walls, undersides and over edges |
| Shift | creep (0.65 studs/s instead of 2.5) |
| Space (tap) | short hop forward |
| Space (hold, aim, release) | leap to the surface at the screen centre; green arc = it will land, red = it cannot |
| G | gait: alternating tetrapod (real) / one side at a time |
| R | back to the start |
| Right mouse drag, wheel | orbit and zoom (Roblox's camera; it never rolls, like the Godot camera) |

## Layout

| Roblox | From Godot | Notes |
|---|---|---|
| `src/Shared/Data/Species.luau`, `Surfaces.luau` | `data/species/*.json`, `data/surfaces/*.json` | **Generated**: `python3 tools/json_to_luau.py`. A part's `ProfileId` attribute names its surface. |
| `src/Shared/Movement/JumpMath.luau` | `scripts/movement/jump_math.gd` | Line-for-line. Discrete 60 Hz tick solve, the same filters and failure reasons. |
| `src/Shared/Movement/SupportMath.luau` | `scripts/movement/support_math.gd` | Tangents, normal hysteresis, turning, the body frame. |
| `src/Shared/Habitat/WindowsillLayout.luau` | `scripts/habitat/windowsill.gd` | Every box, profile and colour of `windowsill-v1`. |
| `src/Shared/Rig/SpiderRig.luau` | `spider_body.gd`, `surface_legs.gd` | The VISUAL-01 spider in anchored parts, moved with one `BulkMoveTo` a frame. Raycast footholds, alternating step groups, three-segment legs, drumming palps, spots by growth stage. |
| `src/Server/Main.server.luau` | — | Builds the sill, Future lighting, colour grade, bloom, sun rays, a macro depth of field, dust motes. No characters. |
| `src/Client/SpiderClient.client.luau` | `spider_motor.gd`, `jump_controller.gd` (core only) | Kinematic surface walking (concave corners, convex edge wrap, falling), hop, aimed leap with arc preview, a dragline, camera focus. |

## Checks

- `python3 tests/run.py path/to/luau` — the Luau `JumpMath` against `tests/jump_reference.json`, written by Godot 4.7.2 running the game's own `jump_math.gd`: same reasons, solution counts and tick counts; speeds to float32 rounding. 35 / 35 on 2026-10-14.
- `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --platform roblox --definitions=globalTypes.d.luau --sourcemap sourcemap.json src` — clean in `--!strict`.
- **Not yet played in Roblox Studio.** First session: does the camera follow, does the spider wrap the sill's front edge and climb the planter, do the legs step cleanly.

## Not ported yet (in order)

1. The safety line catching a missed leap (`tether.gd`, `tether_controller.gd`) — the dragline is drawn only.
2. The fly (`scripts/prey/`) and the strike, struggle and meal (`feeding_controller.gd`).
3. Senses and memory (`scripts/perception/`), and the spider-eye view (a `ColorCorrectionEffect` plus a vignette).
4. The life: clock, hunger, moulting and growth, the wasp, checkpoints (DataStore).
5. Multiplayer: the spider is client-side; a server-owned root with client prediction comes later.
6. Proper meshes: a Blender-made spider with `SurfaceAppearance` (normal, roughness, metalness maps) would replace the primitive parts.
