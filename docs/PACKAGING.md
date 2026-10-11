# Windows and web packaging

Use **Godot 4.7.2 standard**, Compatibility renderer, and matching official 4.7.2 export templates (Editor > Manage Export Templates). No project, gameplay, settings or menu edits are required by these presets.

Run from PowerShell, supplying your console executable:

```powershell
.\tools\export_builds.ps1 -Godot 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
```

Optional `-Target Windows` or `-Target Web`; optional `-OutputDirectory C:\Games\SpiderBuilds`. Outputs default to a sibling `builds` folder outside the source project. Existing files with the same output names are replaced by Godot; use a fresh output directory when preserving a release. The helper does not delete directories. Export via the editor is also supported: Project > Export > Windows Desktop / Web.

Windows: distribute `JumpingSpiderSim.exe` and `JumpingSpiderSim.pck` together. This prototype is unsigned. It targets x86_64. Save files stay in the user's normal Godot application-data directory; they are not shipped in the package.

Web: distribute the **entire generated web folder**, preserving names, with `index.html` as the entry point. Serve over HTTPS (or localhost for testing), not by opening the HTML as a local file. The preset uses a single thread, no extensions and no PWA. It does not require cross-origin isolation headers. The current game needs desktop keyboard/mouse or a controller; this is not a touch-control port. Browser saves depend on persistent browser storage and are not synchronized with the Windows game.

Only game resources and the JSON tuning data are packaged. Tests, evidence screenshots, handoff documents and the standalone leg prototype are excluded. Keep the renderer and physics settings unchanged; web performance, browser save recovery, pointer lock and controller behavior still require platform playtesting before distribution as a supported release.

Official references: [Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html), [web export and browser restrictions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## Leg prototype

Open `scenes/prototypes/legs_preview.tscn` in Godot and run the current scene (F6), or:

```powershell
& 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/prototypes/legs_preview.tscn
```

Right arrow selects a pose; Space toggles automatic cycling. Walking, stalking, preparation, airborne/hanging, idle, sideways and reduced motion are shown. The body stays in place on this bench so the gait can be examined.

`scripts/presentation/spider_legs.gd` owns sixteen mesh segments, eight feet and one cosmetic phase. Feed `advance_pose(delta, local_velocity, grounded, preparing, reduced_motion)` once per physics tick. Velocity must be in the visual body's local support frame (+Y up, -Z forward). `reset_pose()` handles teleport/load discontinuities. No globals, input or gameplay state are modified, and no gameplay random stream is consumed.

This is a prototype of alternating four-leg motion, not anatomical gait research or surface IK. It has no individual foot raycasts, turning-in-place steps, world-space foot planting or smooth transition blend. Stop/reduced-motion resets immediately to the neutral stance. These limits are deliberate until Nathan approves the look.

Future integration belongs under `spider_body.gd`'s cosmetic twitch layer: replace its existing static leg meshes, then feed this node the support-frame movement. Do not simply add it beside the existing legs (that would draw sixteen legs). Coordinate first before changing the body or any shared gameplay code; this branch does not attach the prototype to the game.
