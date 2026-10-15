# Roblox world and fly aesthetics (ROBLOX-21, ROBLOX-22): before and after

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

Tests: `python3 tests/run.py path/to/luau`: WORLD 230/230 (it was 71), FLIES 187/187 (a new suite, for the fly below), all other suites unchanged and green; strict analysis of `src`: 0 diagnostics.

## The fly (ROBLOX-22)

Files: `before_fly*.jpg` and `after_fly*.jpg`. `fly` is the game's distance (the standing fly in the sill's shade, the flying one against the window), `fly_a` the standing fly and `fly_b` the one in the air
at close range; `fly_top`, `fly_front` and `fly_side` are close-ups of the standing fly, `fly_b_top`, `fly_b_side` and `fly_b_front` of the one in the air; `before_after_fly_sheet.jpg` puts six pairs side by side
(before on the left). "Before" is the fly of commit 8630dad (three ellipsoids, two plates and six sticks, 13 parts) drawn by the same, current renderer, so the differences are the fly's. Now it is a house fly,
0.7 cm: two big glossy red-brown eyes and a pale silver face stripe, a grey thorax with four dark stripes, a grey-brown abdomen with a darker back stripe, a short proboscis, bristles, six two-segment legs, and thin
glass wings with a dark front vein and a faint iridescent film, folded in a shallow V; in the air each wing is a soft translucent blur and the legs tuck in. 39 parts a fly (13 before); the two-fly scene draws 75 parts
(26 before), 39 for the standing fly and 36 for the one in the air, whose two veins and shadow oval are invisible.

Same caveat as above: Godot with the shim's parts, not Roblox. Roblox's Glass material, reflectance and transparency sorting will make the wings, the film and the blur look different; nothing has been seen in Studio.
Reproduce, from `roblox_port/`: `python3 tools/preview/scene.py path/to/luau path/to/godot out_dir --prefix after_ --views fly,fly_a,fly_b,fly_top,fly_front,fly_side,fly_b_top,fly_b_side,fly_b_front`.
