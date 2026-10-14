# A cuter, fuzzier spider and a prettier windowsill — verification, 2026-10-14 (Claude, Linux)

Nathan: the spider "needs to be cuter" and "we need fuzzy spider", plus better textures and graphics. Branch `claude/roblox-controls-recovery`, on top of fcfd1d9 (the controls and recovery-camera work). The first coat was at be2fa04; a reviewer found it read spiky, and **the coat's second pass (ROBLOX-15) is in code, tests and both places at 38d15ae**; the commit after it changes documents and pictures only. Source/test/project evidence **80504bccb4e8651f** (tools/build.py; it was 522744ec33d68fa0 with the first coat and 2a5c87b3843fbc0d before the look work). Luau CLI 0.742, luau-lsp 1.70.1, Rojo 7.7.1, Godot 4.7.2 (only to draw the preview images). **Roblox Studio was not run**: this machine has no Roblox engine. Nothing below says how the spider or the world looks in Roblox; every look, lighting and material claim is unverified until someone opens the place in Studio.

| Check | Result | Evidence and scope |
|---|---|---|
| Pure Luau | **PASS 182/182** | luau-report.txt. The count and the file are unchanged (tests/run.luau was not edited): the new rig and world broke no existing check |
| Box-world scenarios | **PASS 15/15** | luau-report.txt. Unchanged; the ten misses are still recovered |
| Client smoke | **PASS 11/11** | luau-report.txt. The real client now also chooses a detail tier and runs WorldDetail; unchanged checks still pass |
| Look checks | **PASS 72/72** (it was 54) | tests/look.luau on the real SpiderRig, Anatomy, Setae and Idle under the shim: the daughter's pattern pinned literally (colours, five spots, band, speckles, cheeks), every knob present in the appearance table, a bigger rounder head, big front eyes with one or two small catchlights each, no part named like a human feature, tufts and palp fluff, knobs that really change the rig, idle motion bounded and deterministic, part budgets at full and low detail (now 705 and 272), no idle motion in low detail or with reduced motion, planted feet and the root part untouched by the idle motion. **New with the second coat (the count goes from 54 to 72):** coat hairs short and thin, nearly all lying flat and combed toward the rear, only a few guard hairs standing, white hairs wholly inside the markings the rig draws, black hairs clear of every marking and of the pale cheeks, nothing grey or frosted in the coat, dark faint fur shells, no guard hairs in low detail, each tier keeping exactly the hairs its table says. Run against the first coat, 12 of them fail |
| World checks (new) | **PASS 71/71** | tests/world.luau on the real Graphics, Materials, SunPick, Scenery, Lit, Detail and WorldDetail under the shim: every material name is a real Roblox material, the sill's boxes keep geometry, colour, profile and solidity, the physical back wall is invisible but still hit by a ray at z = -12.5, every decor part is anchored, non-colliding, untouchable and invisible to rays, the drawn wall and glass leave no gap, the view is outside the wall and shows inside the glass, details stay low and clear of the spawn and silk spot, shafts follow an invented sun, lighting set-up is idempotent with depth of field opt-in, the low tier removes the optional parts and thins the dust once, the back wall stays visible if the drawn wall cannot be built, and an optional decor piece that fails is left out with a warning |
| Strict type check | **PASS, 0 diagnostics** | typecheck-report.txt: luau-lsp 1.70.1, Roblox definitions and a Rojo sourcemap; all 32 files of src/ are `--!strict` |
| Compile | **PASS 52/52** | compile-report.txt: every .luau under src, tests and tools |
| Places | Built | build-report.txt: both places rebuilt twice with identical bytes (SHA-256 recorded), evidence 80504bccb4e8651f |
| Coat on the pattern and outline | **MEASURED** (Godot-shim renders, not Roblox) | tools/preview/coat.py, coat-report.txt: see "The coat, second pass" below |
| Studio engine suite | **NOT RUN** | 50 rows expected: Spec 9, SilkSpec 11, RecoveryScenarios 14, PromptSpec 3, GraphicsSpec 8 (new), plus 5 completion rows. The Spec gained two rows (eyes and catchlights; idle motion) and changed one (low-detail parts under 300) |
| Studio client playback | **NOT RUN** | 7 rows expected, unchanged |
| How it looks in Roblox | **NOT SEEN** | see "Not verified" |
| Frame time on a phone or tablet | **NOT MEASURED** | the low tier exists to help; whether it is enough is unknown |

## The spider (ROBLOX-13)

The daughter's design is untouched and pinned by tests/look.luau: black body and legs, the pale band across the front of the abdomen, one large central white spot, two small elongated spots in front, two small ovals behind, fine white speckles, pale side patches on the head, black-and-white banded legs and palps. docs/SPEC.md (the spider is an animal, not a miniature person) still holds: no eyebrows, no mouth, no smile; a test fails if any part is named like a human feature.

- **Proportions.** Head volume is now about 1.07 times the abdomen's (it was 0.77): head radii 0.27 x 0.215 x 0.27 (were 0.245 x 0.18 x 0.255), a rounded muzzle under the eyes, plumper and slightly shorter, more crouched legs with round feet (full detail).
- **Eyes.** Two big glossy front eyes (0.20 stud across, Glass, reflective), a dark-grey rim so black reads on black, two small white catchlights on each (a larger one high on one side and a smaller one low on the other, the same on both eyes: one light and its reflection), and six smaller eyes.
- **Fuzz that can be seen from the game camera.** The camera sits 5 studs away and 1 stud is about 170 px on a 1080p screen. The old hairs were 0.022 to 0.042 stud long and 0.0065 wide: about a pixel wide and four to seven pixels long, too fine to show. The first coat answered with wide flat locks (0.05 to 0.085 long, 0.04 wide), guard hairs standing off the pelt and a stiff fringe, and it read spiky (see below). The coat is now: short thin locks lying nearly flat and combed toward the rear, a few short guard hairs, a short fringe at the sides, white hairs only on the white markings, four graded faint dark fur shells that make the soft edge, bold-jumper tufts (a fan of 10 hairs on each side at the upper sides of the head, behind the eyes, not over them), a pale ruff beside the jaws, fluffy palp clubs and hairs on the legs (black or dark, white over the pale bands). Hairs stay under 0.1 stud (an existing test bound) and do not cast shadows.
- **Measured at the game camera** (tools/preview/fringe.py, output in fringe-report.txt; a Godot-shim render at 1920x1080, FOV 65, 5 studs, legs left out): the coat extends past the bare body outline by an average of **1.77 px (faint threshold) and 1.35 px (strong threshold) for the second coat, against 1.73 and 1.12 px for the first coat and 1.27 and 1.03 px for the original rig**; the hairs alone reach 0.62 px (first coat 1.22) and the fur shells 1.46 px (1.23), so the outline is now soft from the shells and not ragged from the hairs. That is a modest gain in softness at the outline, not a dramatic one. Whether it reads as fuzzy in Roblox's own lighting is for Nathan's eye. If it does not, the knobs are `fuzz.locks`, `fuzz.fringe` and `fuzz.guard` (length, width, lift, counts), `fuzz.shells` and `fuzz.shellColor`, the tufts, all in `Appearances.fuzz`; the budget checks cap the total at 705 parts.
- **Idle motion** (drawn rig only, never the planted feet, the root part or anything that feeds movement): once the spider stands still it eases in over a second: the body breathes a little (the abdomen rises at most 0.016 stud and tips 2.4 degrees), the head tilts curiously (inside 7 degrees of roll, 6 of yaw, 3.5 of pitch, on slow overlapping cycles of 5 to 11 seconds) and the palps drum in short bursts (13 degrees, 3.2 Hz). It eases out within a quarter of a second of the spider moving, and it is off in the air, in low detail and with reduced motion.

## The coat, second pass (ROBLOX-15)

The reviewer's words on the first coat's contact sheet: the face is great; the coat reads spiky, not fuzzy; in the top view and at play distance the abdomen hairs stick straight out as pale rectangular shards (a hedgehog look) and cover the daughter's white spot pattern. One tuning pass on the coat only. Eyes, catchlights, head shape, palps, legs' shape, pattern and idle motion are as they were: in the face close-up the catchlights, palp clubs and tips and jaws are the same pixels as before, and one front eye differs only at a one-pixel rim (103 of 21,819 pixels, largest step 41/255).

| | First coat (be2fa04) | Second coat (38d15ae) |
|---|---|---|
| Locks: length, width | 0.050 to 0.085, 0.040 | 0.024 to 0.040, 0.018 |
| Locks: lie | leaning 46 to 48 degrees off the surface | 3 to 13 degrees off the surface, combed toward the rear |
| Guard hairs standing | 204, 0.060 to 0.097 long, 60 to 66 degrees | 32, 0.030 to 0.046 long, 50 to 75 degrees; none in low detail |
| Fringe | 49, 0.071 to 0.098, 66 to 73 degrees | 30, 0.026 to 0.040, lifted 14 to 31 degrees |
| Colour of a hair | 190 of the 370 coat hairs grey or frosted, 62 white, the rest dark | black (0.03) or dark (0.13) on the black, kept 0.006 stud off the markings and cheeks; white only inside the spots and the band |
| White hairs on the pattern | 62, placed up to 1.18 x the spots' radius and over the whole band stripe, standing | 24 lying on the discs, wholly inside their edge |
| Fur shells | grey 0.32, 1.05 to 1.23 x, 36 % tint | dark 0.08, 1.05 to 1.23 x, 26 % tint |
| Parts, full / low | 705 / 272 | 624 / 266 |

Measured on Godot-shim renders of the abdomen (tools/preview/coat.py; coat-report.txt has every number, for hairs alone, shells alone and both). **These are renders of the part list, not Roblox, and they were judged by pixel measurements and a text rendering of the pictures, not by eye: they compare the two coats, they do not say how fuzzy either looks.**

| Abdomen, hairs and shells together | First coat | Second coat |
|---|---|---|
| Top view: bright shard pixels on the black (hairs made 40/255 brighter than the bare body, away from the white) | 7,741 in 58 blobs | 107 in 6 blobs |
| Top view: black body lifted by the coat | +37.9 of 255 | +1.5 |
| Top view: share of the white pattern still as bright as designed (hairs alone: 91 % before, 100 % after) | 83 % | 87 % |
| Top view: reach of solid hairs past the bare outline: mean, 95th percentile, farthest | 5.6, 21.9, 27.9 px | 2.4, 9.6, 15.1 px |
| Top view: far spikes (blobs beyond 12 px) | 28 | 4 |
| Game camera: bright shard pixels | 1,033 | 25 |
| Game camera: solid reach, mean / farthest; spikes beyond 6 px | 2.4 / 12.9 px; 14 | 0.7 / 6.4 px; none |
| Game camera: the shells' soft halo (faint reach, shells alone) | 2.3 px | 2.4 px |

What is left of the shard pixels in the second coat are 107 mid-grey pixels where a dark hair catches the light (the brightest 127 of 255), not pale hairs. The white pattern's 13 % that is not at full brightness is the shells' faint tint over it; the hairs do not cover it. The picture files are in "Images" below.

## Part counts (the drawn spider, from tests/look.luau)

| | Parts | Hairs | Fur shells | Everything else |
|---|---|---|---|---|
| Original rig (full), before the look work | 772 | 639 | 4 | 129 |
| First coat, full / low | 705 / 272 | 556 / 151 | 8 / 2 | 141 / 119 |
| Second coat, **full detail** | **624** | 475 | 8 (4 per body part) | 141 |
| Second coat, **low detail** | **266** | 145 | 2 (1 per body part) | 119 |

The 475 hairs are 319 on the body (203 locks, 30 fringe, 32 guard, 24 white, 20 tuft, 10 ruff), 14 on the palps and 142 on the legs.

Low detail (touch-only devices, or the Workspace attribute `Detail` = "low") keeps the pattern, the eyes with their catchlights, the tufts and a thinner coat (one hair in two to four, no standing guard hairs), a single fur shell, and drops the eye rims, foot balls, half the speckles, the outline and all idle motion. The budgets are checked: full at most 705 parts with at most 160 non-hair parts, low at most 272 and under 45 % of full.

## The world (ROBLOX-14)

- **Materials.** Roblox's own, one per surface and looks only (a surface's grip stays its profile in Data/Surfaces): WoodPlanks floor, Wood lip and crevices, Plaster walls, Brick planter, LeafyGrass leaves, Grass stems, Ground soil, Glass. `MaterialService.Use2022Materials` is on in both Rojo projects, so they carry PBR textures. Colours are the old colours.
- **Lighting.** Future technology (authored in the Rojo projects), a soft warm sun, Atmosphere haze, a Sky, clouds, gentle Bloom and ColorCorrection, faint SunRays. No default depth of field (Workspace attribute `DepthOfField` = true adds it). `SunPick` scans the day (both signs of the latitude, because the sun's direction is not assumed) for a sun behind the window, 18 to 48 degrees high, within 65 degrees of straight out of the window, and records its choice in Lighting's attribute `SunPick` and in Output as `[Windowsill] sun: ...`; it falls back to the old morning light (ClockTime 9.6) if none exists. With an invented sun the pick is clock 9.75, 39 degrees high, 46 degrees off axis. What Roblox's sun does is unknown until Studio.
- **A window to look out of.** The back wall stays a solid, climbable box but is invisible; a plaster wall is drawn just behind its face with an opening for the glass, wooden trim flush with the face and two mullions. Beyond the glass are hills, seven houses with roofs and two chimneys, a tree on the left and a smaller one on the right, a ground plane and the sky. Everything is placed by where it should appear on the glass from the camera's usual eye, so it holds its place at any depth.
- **Small details** (full only): 12 paint chips, one crack with a branch, three crumbs, all under 0.25 stud high and away from the spawn and the silk spot so the landing patch, the silk lines and the prompts stay clear. **Dust motes** drift in the window light (7 per second; 2.8 in low). **Light shafts** (three faint stacked ribbons from each pane along the sun, full only).
- **Gameplay is untouched.** All decor is anchored, non-colliding, untouchable and not queryable, in a folder gameplay never filters in. Decor is 76 parts at full detail and 34 at low (the view is 31 items at full).
- **The looks are best effort.** None of this has run in Studio, so the server does not trust it: Server/Main wraps the lighting set-up and the decor in `pcall`, warns, and carries on with the old look; if the drawn wall cannot be built the solid back wall stays visible; inside the decor the dust, view, details and shafts are tried one by one and one that fails is left out. The wall itself and the sill are not optional.

## Images (Godot-shim renders, not Roblox)

All pictures in this folder come from tools/preview: the real rig code under the plain Luau CLI with preview stand-ins, drawn by Godot. They show layout, silhouette and proportions only. Roblox's materials, lighting, shadows, anti-aliasing, glass and glossy reflections are not in them, and the fur will look different in the engine.

- **contact_sheet.png**: rows are front three-quarter, top, face close-up and play distance; columns are before (**the first coat**, be2fa04, 705 parts), after (the second coat, full detail, 624 parts), after (low detail, 266) and after standing idle for 5 seconds, each with its part count.
- **game_camera_sheet.png**: the spider as the player sees it at the game camera (1080p, 5 studs), enlarged 2x: first coat, second coat, low detail.
- `before_*` (the first coat), `after_*` (the second coat), `low_*`, `idle_*`: the single renders (front three-quarter, top, face close-up, play distance, side, game camera); `original_*` the original rig before any of the look work (the pictures of the first version of this sheet); `*_counts.txt` the part counts; `before_parts.json` and `original_parts.json` the parts of those two so they can be redrawn after the old code is gone (`--parts`); `fringe-report.txt` the outline measurement above (original rig, first coat, second coat); `coat-report.txt` the coat measurement above (first and second coat).

## Not verified

Everything about looks and feel in Roblox Studio and on devices: the spider's face and proportions, whether the second coat reads as fuzzy at the game camera (and not as smooth, with flat dark hairs on a black body, or still as spiky; the numbers above compare two coats in a Godot-shim render, and nobody has yet looked at the new contact sheet by eye), the glossy eyes and catchlights, the PBR materials with `Use2022Materials`, the lighting values, the haze, clouds, bloom and sun rays, the dust, the light shafts, whether the window view composes (and that the trees, roofs and hills do not clip or float), the small details. Whether Roblox's sun can stand behind the window at all (the SunPick result is only an invented one here), and the patch of light through the glass. The Studio suite (50 rows) and the client playback (7 rows). The low tier's removal on a real client, and frame time on phones and tablets with either tier. The 8 new engine rows in GraphicsSpec have never run, and the fallback paths (a failing lighting set-up or decor) have only been exercised by CLI checks.

## Reproduce

From roblox_port: `python3 tests/run.py path/to/luau` (prints SUMMARY, BOXWORLD, CLIENT, LOOK and WORLD; name test files after the luau path, for example `look.luau world.luau`, to run only those; an unknown name fails), `python3 tools/build.py path/to/rojo`. Strict check: `rojo sourcemap default.project.json -o sourcemap.json`, then `luau-lsp analyze --platform roblox --definitions=globalTypes.d.luau --sourcemap sourcemap.json src`. Images: `python3 tools/preview/preview.py path/to/luau path/to/godot out_dir --prefix after_` (also `--detail low`, `--idle 5`, `--parts before_parts.json`), then `python3 tools/preview/contact_sheet.py out_dir`. The outline measurement: `python3 tools/preview/fringe.py path/to/godot parts.json work_dir`; the coat measurement: `python3 tools/preview/coat.py path/to/godot parts.json work_dir` (needs numpy, OpenCV and Pillow).
