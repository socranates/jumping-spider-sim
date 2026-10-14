# Handoff — Roblox controls like Godot, the recovery camera, and a cuter spider with better graphics (Claude, 2026-10-14)

Nathan: "the controls are not as good on roblox, when jumping you can only hop, V doesnt change the view etc. They were perfect on the godot version." Then: the spider "needs to be cuter" and "we need fuzzy spider", and the textures and graphics should improve.

Branch **`claude/roblox-controls-recovery`**: main 432bc53 (Chet's safety silk) with Perplexity's 01fe0d1 (camera, jump aiming, controls, fuzz) merged, then Chet's acceptance chunk "recovery camera and control acceptance" (HANDOFF-roblox-silk.md). Then, on the same branch, a cuter and fuzzier spider and better graphics (section below). Roblox only; Godot and SPEC untouched. DECISIONS ROBLOX-06 to ROBLOX-15. Evidence **80504bccb4e8651f** (522744ec33d68fa0 with the first coat, 2a5c87b3843fbc0d before the look work). **Not run in Roblox Studio.**

## What changed

- **Merge.** Both branches survive: Chet's catch, hang, reel, lower, edge-first lowering, one bend/snag and deliberate let-go; Perplexity's Scriptable camera, held aim with the landing patch, eye view, Focus, recenter, slow motion and fuzz. Conflicts were in the client, input, tests, docs and the generated places; the places and BuildInfo were rebuilt, not hand-merged. Both branches had added ROBLOX-04/05: Chet's keep the numbers, Perplexity's became ROBLOX-06 (controls and camera) and ROBLOX-07 (fuzz).
- **One control scheme (ROBLOX-08).** `SpiderMotor` (the body: walking, planner, flight, line) and `JumpInput` (jump_controller.gd's phases) are now modules the client wires together. Keyboard, controller and touch hold the same action together. Q / B / touch Cancel follow Godot's context rules: cancel a press or an aim, stop a walk to the edge (and nothing else), and only a fresh held press lets go of the line. Esc / Menu open Roblox's menu, which drops every hold and pauses the spider. The words on screen name the device last used, wrap, and sit in the safe area clear of the touch buttons. Touch gains Recenter; Cancel reads "Let go (hold)" on the line, where Jump and Creep hide. While aiming, the body turns toward the centre dot, the patch grows past 6 studs and a line says whether a miss will be caught.
- **Recovery camera (ROBLOX-09).** `LineFraming`: while hanging with a squeezed view, the view turns by the smallest 15-degree step (never past 45) that sees the spider and the lip; any look, a recenter or aiming takes the turn over at once and nothing jumps; the view stays when the line ends. The decisions match values exported from the frozen Godot rig. A boom cast that starts in contact is blocked (Roblox's Spherecast would miss it), and no boom is trusted before the sill exists.
- **Fixes found by the new scenarios.** ROBLOX-10: a snag while swinging under a leaf left reeling refused for good ("shortest" was set by a reel that never ran). ROBLOX-11: holding W at a leaf's edge flipped between the top and the face forever; Godot's stick carry is ported.
- **Tests (ROBLOX-12).** `tests/studio/RecoveryScenarios.luau`: 14 deterministic scenarios run by Studio on real queries and by the CLI on a box-world emulation. `PromptSpec` checks wrapping with Roblox's text metrics. The client playback gains four rows. `tests/client_smoke.luau` runs the client scripts themselves in the CLI with stub services.

## Cuter spider and graphics

Nathan: the spider "needs to be cuter", "we need fuzzy spider", and the textures and graphics should get better. DECISIONS ROBLOX-13 (the spider), ROBLOX-15 (its coat, second pass) and ROBLOX-14 (the graphics); numbers and the tests: docs/verification/roblox-cute-graphics/RESULTS.md. **Every look below is unseen in Studio.**

- **The same spider, cuter.** The daughter's design (docs/art/first-spider-reference.jpg) is untouched and pinned by tests/look.luau; docs/SPEC.md rules out human features, so there are no eyebrows, mouth or smile. The head is about 1.07 times the abdomen (it was 0.77) and rounder; two big glossy front eyes have two small catchlights each and a dark-grey rim; a rounded muzzle; plump, slightly shorter legs with round feet; fluffy palps; a bold jumper's tufts behind the eyes. Every number is in `Appearances.luau`.
- **Fuzzier, sized for the real camera, then sleeker (second coat, ROBLOX-15).** The camera is 5 studs away (about 170 px per stud at 1080p) and the old hairs were about 1 px wide. The first coat used big hairs, and in the top view and at play distance they stood out of the abdomen like a hedgehog's and covered the white spots. The coat is now short (locks 0.024 to 0.040 stud, about half), thin, lying nearly flat and combed toward the rear; only 32 short guard hairs stand up (none in low detail); every hair takes the colour of the pattern it grows on (black on the black, white only inside the five spots and the band, kept clear of the cheeks); the softness comes from four faint dark fur shells and a short fringe at the sides; the legs have hairs, black over black and white over the pale bands. In Godot-shim renders (tools/preview/coat.py): pale shard pixels on the abdomen 7,741 to 107, the black body lifted +38 to +1.5 of 255, the farthest hair 28 px to 15 px past the body in the top view. If Studio says it is not fuzzy enough, the knobs are `fuzz.locks`, `fuzz.fringe`, `fuzz.shells` (alpha and scale) and `fuzz.guard`; the budget test allows 705 parts.
- **A little life.** Standing still, the spider eases into breathing, a slow head tilt (7 degrees at most) and bursts of palp drumming. Drawn rig only: the planted feet, the root part and movement never see it. Off while walking, in the air, with reducedMotion and in low detail.
- **The world.** Roblox materials per surface (PBR through `Use2022Materials`, set in both Rojo projects), Future lighting, a soft warm sun picked to shine in through the window (SunPick, falling back to the old morning light), Atmosphere haze, Sky, clouds, gentle bloom, colour grade and sun rays. The back wall stays solid and climbable but invisible; a drawn plaster wall has an opening with glass, trim and two mullions, and beyond it hills, houses with roofs and chimneys, trees and sky. Dust motes, faint light shafts, 12 paint chips, a crack and 3 crumbs, all low and away from the spawn and the silk spot. All decor is non-colliding, untouchable and invisible to rays. No depth of field unless the Workspace attribute `DepthOfField` is true. Everything is tuned in `Data/Graphics.luau`. The looks are best effort: if the lighting or the decor throws in Studio, the server warns in Output (`[Windowsill] ... failed`) and carries on with the old look, and the solid back wall stays visible if the drawn wall could not be built. A warning like that is the first thing to report.
- **Low detail.** Touch-only devices (or the Workspace attribute `Detail` set to "low"; "full" forces full) get a spider of 266 parts (145 hairs, 2 shells) instead of 624 (475 hairs, 8 shells), with no eye rims, foot balls, outline or idle motion; their client drops bloom, sun rays, clouds, shafts, details and the busier view (decor 34 parts instead of 76) and thins the dust. Not measured on any device.
- **Pictures** are in docs/verification/roblox-cute-graphics (contact_sheet.png: the first coat, the second coat, low detail, idling). They are **Godot-shim renders of the part list, not Roblox rendering.**

## Controls (full table: roblox_port/README.md)

| Action | Keyboard and mouse | Controller | Touch |
|---|---|---|---|
| Walk / look | WASD / mouse, arrows | Left stick / right stick | Arrows / drag |
| Stalk | Hold Shift | Hold LB | Hold Creep |
| Hop / aim / leap | Tap / hold / release Space | A | Jump |
| Cancel (aim, walk to the edge) | Q | B | Cancel |
| Let go of the line | Hold Q (0.4 s grace, 0.6 s hold) | Hold B | Hold Let go |
| Reel in / lower on the line | W / S | Stick up / down | ↑ / ↓ |
| Let down on a line | F (hold to lower) | X | Silk |
| Recenter / Focus | R or middle mouse / hold right mouse | Right-stick click / hold LT | Recenter / — |
| Spider-eye view / slow motion | V / T | Y / RT | Eye / — |
| Pause | Esc (Roblox menu) | Menu | Roblox menu |
| Port only | Backspace start, G gait, H card, wheel zoom | View start | — |

Deferred (no feature yet): interact (eat, rest: E / X), field notes, notebook, struggle grip, F3/F4 developer views, and the pause panel's settings (sensitivity, invert, FOV, distance, toggles, remapping, presets). The controller's X lowers on silk in the port (Godot's D-pad down); settle it against interact when feeding is ported.

## Verification (Linux)

Pure Luau **182/182**; box-world scenarios **15/15**; client smoke **11/11**; look checks **72/72**; world checks **71/71**; luau-lsp strict analysis of src **0 diagnostics**; **52/52** files compile; both places rebuild with identical bytes; camera, framing and tether goldens regenerate byte-identically from Godot. Ten-miss sequence: 10/10 recovered on the box world. Details: docs/verification/roblox-controls-recovery/RESULTS.md and docs/verification/roblox-cute-graphics/RESULTS.md.

**Only Studio or a device can confirm:** the Studio suite (50 rows) and client playback (7 rows); that the engine's Spherecast and raycasts agree with the box world in the scenarios; real mouse lock, controller triggers, touch multi-finger holds and Roblox's menu events; the prompts' look and safe areas on a phone or tablet; frame time during catches with about 624 rig parts (266 in low detail) and the framing's casts; how the spider and the world look (eyes, fuzz, materials, lighting, window view, whether the sun comes in through the window) and how the low tier does on a phone.

## Chet: please run (Windows)

1. Check out this branch, `python tests/run.py path/to/luau` (expect SUMMARY 182, BOXWORLD 15, CLIENT 11, LOOK 72, WORLD 71), `python tools/build.py path/to/rojo` (expect evidence 80504bccb4e8651f).
2. Open **TheWindowsillTests.rbxlx**, Play, wait for PORT_TEST_SUMMARY (50 rows) and PORT_CLIENT_REPORT (7 rows); `python tools/collect_studio_report.py path/to/Studio.log ../docs/verification/roblox-controls-recovery`. PORT_SCENARIO lines list the ten misses. A failed row is not a pass; if the engine disagrees with the box world, trust the engine and say which scenario.
3. Play **TheWindowsill.rbxlx** with keyboard and mouse, an Xbox-style controller and Studio's touch emulator: the list below. Then a real tablet if possible: touch and a drag at the same time, the Let go hold, prompt wrapping on a small screen.
4. Frame intervals during a catch and the ten-miss route (median/p95/worst, warm-up separate, no screenshot stalls).
5. Graphics: in Output look for `[Windowsill] sun:` and read Lighting's `SunPick` attribute (did a sun behind the window exist, or did it fall back?). From the spawn: does the window show a view without gaps or floating pieces, is there a patch of sun on the sill, do the landing patch, silk and prompts still read through the dust, haze and bloom? Set the Workspace attribute `Detail` to "low" before Play and compare, and time frames on a phone or tablet with each tier.
6. Merge to main when green, update the laptop, record results.

## Nathan: please try

- Hold Space and look up at a leaf: the patch turns green; let go to leap. Tap Space for a short hop. Q while aiming cancels.
- Walk off a leaf with W held: the spider goes over the edge and underneath, as in Godot.
- Leap off a leaf into the air: the line catches you. W climbs back, S lowers, hold Q to let go. F lets you down from anywhere.
- V for the spider's eyes, R to recenter, right mouse to turn the spider to look. The words on screen change if you pick up a controller or touch the screen.
- Zoom in on the spider (wheel): the eyes, the tufts, the fuzzy edge. Cute and fuzzy enough? Stand still for a few seconds and watch it breathe and look about. Tell us which knob to turn (head size, eye size, fuzz).
- Look out of the window: a nice view, warm soft light? Anything floating, clipped or too bright?
- Tell us anything that still feels worse than the Godot version.

## Next

After Chet's Studio pass: perception (observation/association/memory, inspection cone, peripheral cue, Focus), then flies, LIFE/wasp and DataStore saves (ROBLOX_PORT.md). Settings UI and remapping should come with the first chunk that needs them. No publishing or production saves.
