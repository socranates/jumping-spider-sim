# Handoff — VISUAL-01, the drawn spider and the Roblox scaffold (Perplexity Computer, 2026-10-14)

Nathan passed on a Gemini plan for a graphics upgrade and a Roblox port. This turn did the parts that fit the project's rules. Read DECISIONS **VISUAL-01**.

## What changed in the game (drawn only)

| Where | What |
|---|---|
| `scripts/presentation/spider_legs.gd` | Optional `detail_parent`: a thin distal segment and two joint bulbs per leg, stout front legs (`LEG_RADII`). Without it (preview, unit tests) nothing changes. `ankle_point()` is shared. |
| `scripts/presentation/surface_legs.gd` | Places the detail in world space on surfaces, folds it in `pose_seized`, and shows only the front pair's ends in the eye view. |
| `scripts/presentation/spider_body.gd` | Eye face, catchlights, chelicerae shader, palps (`_drum_palps`), basal band, `_apply_spot_colour()` by growth stage, rim materials. Softness tints the joints too. |
| `scripts/presentation/shaders/iridescent_chelicerae.gdshader` | View-angle green to blue. Compatibility-safe. |
| `scripts/presentation/sill_atmosphere.gd` | 70 CPU dust motes over the sill; `set_daylight()` fades them. |
| `scripts/habitat/windowsill.gd` | Filmic tone mapping (exposure 1.04, white 4), triplanar detail textures per surface profile, the atmosphere node. No collision change. |

Before and after stills: `docs/verification/visual01/` (`before_*.png`, `after_*.png`; `capture.gd` makes them, `-- --tag=after`). They were rendered with Mesa's software OpenGL under Xvfb, not a GPU.

## Tests

- Full suite **644 / 644**, evidence **87c44d9c8206** (Linux headless, fixed 60 fps, 1,742 s of frame time). Console: `docs/verification/visual01/full_console.txt`.
- `--files=legs,eye_view,growth,moult,wasp_body`: 36 / 36 at fixed 30 and 144 fps.
- Not run on Windows.

## For Chet (Windows)

1. Look at the spider close up in daylight, evening and night, and in the eye view. Rim light and catchlights were tuned on software GL; a GPU may show them stronger.
2. Frame time on battery with the extra ~40 drawn parts and the motes (F01 is open). If it costs too much, drop `radial_segments` or skip the joint bulbs first.
3. The wood grain shows faint streaks through the eye view's soft surround; lower `DETAIL_PROFILES` contrast (`lo` in `_detail_texture`) if Nathan dislikes it.

## Roblox port (`roblox_port/`)

See `roblox_port/README.md`. Built with Rojo 7.7.1 to `TheWindowsill.rbxlx`; strict type check clean against Roblox's API definitions (luau-lsp 1.70.1); `tests/run.py` 35 / 35 against `jump_reference.json` from Godot's `jump_math.gd`. **Not yet played in Roblox Studio** — the first Studio session should check the camera, edge wrapping and leg stepping.

## Next

LIFE round 6 is still Nathan's: he, his son and friends play a whole life. This turn did not touch mechanics.
