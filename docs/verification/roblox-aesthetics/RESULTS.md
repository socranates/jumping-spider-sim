# Roblox world aesthetics (ROBLOX-21): before and after

What this is: renders of the real `Scenery` (the sill and its decor), `SpiderRig` and `FlyBodies` under the test shim, drawn in Godot 4 by
`roblox_port/tools/preview/scene.py` (sun from behind the window, 30 degrees high, warm ambient light, filmic tonemap, soft shadows,
1280x720). The "before" pictures are the world at commit 1d16409 (d910d1e plus the preview tool) rendered with the same renderer
settings, so the differences are the world's. It is NOT Roblox rendering: no Roblox materials or PBR textures, no Future lighting, haze,
bloom or depth of field. Studio is the judge of the real look.

Files: `before_*.jpg` / `after_*.jpg` by view (`game` is the camera at the spawn, inside the retreat; `game_mid` mid-sill; `overview`,
`planter`, `leaves`, `window`, `window_uv` with the ultraviolet layer faded in, `retreat`, and close-ups `corner`, `lip`, `floor`, `glass`,
`drops`); `before_after_sheet.jpg` is eight of them side by side; `before_counts.txt` / `after_counts.txt` count the parts drawn.

Counts (shim): decor 76 -> 806 parts at full detail (budget 1,500), 34 -> 151 at low (budget 450). Reproduce, from `roblox_port/`:
`python3 tools/preview/scene.py path/to/luau path/to/godot out_dir --prefix after_ --views game,game_mid,overview,planter,leaves,window,retreat`
(add `--detail low` for the phone tier, `--uv` for the ultraviolet layer in every view).

Tests: `python3 tests/run.py path/to/luau`: WORLD 230/230 (it was 71), all other suites unchanged and green; strict analysis of `src`: 0 diagnostics.
