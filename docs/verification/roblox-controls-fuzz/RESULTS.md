# Roblox controls, camera and fuzz — 2026-10-14 (Perplexity Computer, Linux)

Source/test/project evidence: **db36b09b003a6b8d** (tools/build.py). Built with Rojo 7.7.1. **Not run in Roblox Studio**: this machine has no Roblox engine. Chet's next Windows Studio session should run TheWindowsillTests.rbxlx and play TheWindowsill.rbxlx.

| Check | Result | Evidence / scope |
|---|---|---|
| Pure Luau | PASS 63/63 | luau-report.txt (Luau CLI, Linux): 35 inherited jump/support goldens, 8 appearance/input, 11 camera/stick checks against Godot-exported tests/camera_reference.json, 3 look-input, 5 fuzz-layout, 1 recenter pair |
| Strict type check | PASS, 0 diagnostics | typecheck-report.txt: luau-lsp 1.70.1, Roblox definitions, all of src/ |
| Aim geometry | PASS (pure) | Default view (pitch 18 degrees, boom 5) aims 2.34 studs ahead; 10 degrees 4.31; 30 degrees 1.32: all solvable by JumpMath. Roblox's stock camera centred the body, so the old aim landed just past the feet (the "only hop" report) |
| Rig look preview | Layout only | front_three_quarter/side/above/play_distance.jpg: the real SpiderRig/Setae/Appearances code run under preview stand-ins (tools/preview) and drawn in Godot 4.7.2. Not Roblox rendering |
| Studio engine suite | NOT RUN | Spec.luau now also checks the fuzz budget (300 to 720 hair parts, body still at most 160), the eye-view hiding and low-detail fuzz |
| Mouse lock, Scriptable camera, CAS mouse buttons, Spherecast | NOT RUN | Written to Roblox's documented APIs; needs a Studio play check |
| Touch, controller, tablet frame time | NOT RUN | Touch-only devices get a third of the hairs until measured |

Godot's own suite was not run this round. Godot was used only to export the camera goldens (tools/export_camera_reference.gd, unchanged reference code) and to draw the preview.
