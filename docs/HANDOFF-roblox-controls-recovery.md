# Handoff — Roblox controls like Godot, and the recovery camera (Claude, 2026-10-14)

Nathan: "the controls are not as good on roblox, when jumping you can only hop, V doesnt change the view etc. They were perfect on the godot version."

Branch **`claude/roblox-controls-recovery`**: main 432bc53 (Chet's safety silk) with Perplexity's 01fe0d1 (camera, jump aiming, controls, fuzz) merged, then Chet's acceptance chunk "recovery camera and control acceptance" (HANDOFF-roblox-silk.md). Roblox only; Godot and SPEC untouched. DECISIONS ROBLOX-06 to ROBLOX-12. Evidence **876253fd47783ce3**. **Not run in Roblox Studio.**

## What changed

- **Merge.** Both branches survive: Chet's catch, hang, reel, lower, edge-first lowering, one bend/snag and deliberate let-go; Perplexity's Scriptable camera, held aim with the landing patch, eye view, Focus, recenter, slow motion and fuzz. Conflicts were in the client, input, tests, docs and the generated places; the places and BuildInfo were rebuilt, not hand-merged. Both branches had added ROBLOX-04/05: Chet's keep the numbers, Perplexity's became ROBLOX-06 (controls and camera) and ROBLOX-07 (fuzz).
- **One control scheme (ROBLOX-08).** `SpiderMotor` (the body: walking, planner, flight, line) and `JumpInput` (jump_controller.gd's phases) are now modules the client wires together. Keyboard, controller and touch hold the same action together. Q / B / touch Cancel follow Godot's context rules: cancel a press or an aim, stop a walk to the edge (and nothing else), and only a fresh held press lets go of the line. Esc / Menu open Roblox's menu, which drops every hold and pauses the spider. The words on screen name the device last used, wrap, and sit in the safe area clear of the touch buttons. Touch gains Recenter; Cancel reads "Let go (hold)" on the line, where Jump and Creep hide. While aiming, the body turns toward the centre dot, the patch grows past 6 studs and a line says whether a miss will be caught.
- **Recovery camera (ROBLOX-09).** `LineFraming`: while hanging with a squeezed view, the view turns by the smallest 15-degree step (never past 45) that sees the spider and the lip; any look, a recenter or aiming takes the turn over at once and nothing jumps; the view stays when the line ends. The decisions match values exported from the frozen Godot rig. A boom cast that starts in contact is blocked (Roblox's Spherecast would miss it), and no boom is trusted before the sill exists.
- **Fixes found by the new scenarios.** ROBLOX-10: a snag while swinging under a leaf left reeling refused for good ("shortest" was set by a reel that never ran). ROBLOX-11: holding W at a leaf's edge flipped between the top and the face forever; Godot's stick carry is ported.
- **Tests (ROBLOX-12).** `tests/studio/RecoveryScenarios.luau`: 14 deterministic scenarios run by Studio on real queries and by the CLI on a box-world emulation. `PromptSpec` checks wrapping with Roblox's text metrics. The client playback gains four rows. `tests/client_smoke.luau` runs the client scripts themselves in the CLI with stub services.

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

Pure Luau **182/182**; box-world scenarios **15/15**; client smoke **11/11**; luau-lsp strict analysis of src **0 diagnostics**; **40/40** files compile; both places rebuild with identical bytes; camera, framing and tether goldens regenerate byte-identically from Godot. Ten-miss sequence: 10/10 recovered on the box world. Details: docs/verification/roblox-controls-recovery/RESULTS.md.

**Only Studio or a device can confirm:** the Studio suite (39 rows) and client playback (7 rows); that the engine's Spherecast and raycasts agree with the box world in the scenarios; real mouse lock, controller triggers, touch multi-finger holds and Roblox's menu events; the prompts' look and safe areas on a phone or tablet; frame time during catches with about 770 rig parts and the framing's casts.

## Chet: please run (Windows)

1. Check out this branch, `python tests/run.py path/to/luau` (expect SUMMARY 182, BOXWORLD 15, CLIENT 11), `python tools/build.py path/to/rojo` (expect evidence 876253fd47783ce3).
2. Open **TheWindowsillTests.rbxlx**, Play, wait for PORT_TEST_SUMMARY (39 rows) and PORT_CLIENT_REPORT (7 rows); `python tools/collect_studio_report.py path/to/Studio.log ../docs/verification/roblox-controls-recovery`. PORT_SCENARIO lines list the ten misses. A failed row is not a pass; if the engine disagrees with the box world, trust the engine and say which scenario.
3. Play **TheWindowsill.rbxlx** with keyboard and mouse, an Xbox-style controller and Studio's touch emulator: the list below. Then a real tablet if possible: touch and a drag at the same time, the Let go hold, prompt wrapping on a small screen.
4. Frame intervals during a catch and the ten-miss route (median/p95/worst, warm-up separate, no screenshot stalls).
5. Merge to main when green, update the laptop, record results.

## Nathan: please try

- Hold Space and look up at a leaf: the patch turns green; let go to leap. Tap Space for a short hop. Q while aiming cancels.
- Walk off a leaf with W held: the spider goes over the edge and underneath, as in Godot.
- Leap off a leaf into the air: the line catches you. W climbs back, S lowers, hold Q to let go. F lets you down from anywhere.
- V for the spider's eyes, R to recenter, right mouse to turn the spider to look. The words on screen change if you pick up a controller or touch the screen.
- Tell us anything that still feels worse than the Godot version.

## Next

After Chet's Studio pass: perception (observation/association/memory, inspection cone, peripheral cue, Focus), then flies, LIFE/wasp and DataStore saves (ROBLOX_PORT.md). Settings UI and remapping should come with the first chunk that needs them. No publishing or production saves.
