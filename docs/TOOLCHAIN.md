# Toolchain

Pinned for chunk 2 (2026-10-05). Change a line here when the project changes it.

## Versions and settings

| Item | Value |
|---|---|
| Engine | Godot 4.7.2 stable, standard build, `4.7.2.stable.official.ed1daf0bf` |
| Renderer | Compatibility: `rendering/renderer/rendering_method` and `.mobile` = `gl_compatibility`; `config/features` = `4.7`, `GL Compatibility` |
| Physics | `physics/3d/physics_engine` = `Jolt Physics` |
| Tick rate | `physics/common/physics_ticks_per_second` = 60 |
| Interpolation | `physics/common/physics_interpolation` = true. The camera follows `get_global_transform_interpolated()`; `reset_physics_interpolation()` is called after spawns and teleports |
| Window | 1280 by 720, resizable, stretch `canvas_items`, aspect `expand` |
| Main scene | `res://scenes/main.tscn` |
| Autoloads | `Settings` (`scripts/presentation/settings.gd`), `InputSetup` (`scripts/core/input_setup.gd`) |
| Language | GDScript, typed. No `class_name`; scripts reference each other with `preload()` so a fresh copy works without editor caches |
| Units | 1 WU = 1 cm; reference body length 1 WU; gravity 35 WU/s^2 (tuned, not biological) |

The test `tests/unit/test_toolchain.gd` fails if the renderer, physics engine, tick rate, interpolation, main scene or Godot 4.7 changes.

Engine features used that older 4.x releases may lack (all present in 4.7.2): `OS.add_logger` and `Logger`, `Node3D.get_global_transform_interpolated`, `Node.reset_physics_interpolation`, `InputEventMouseMotion.screen_relative`.

## Windows (Nathan)

`play.bat` and `run_tests.bat` find the exe through `godot_path.txt` or a search of Downloads, Desktop, OneDrive\Desktop and OneDrive\Documents, and use the `_console` build for tests. Both launchers have been run on Nathan's PC (`play.bat` found Godot and the game started; `run_tests.bat` passed 103 of 103 for chunk 3; see `docs/SESSION_LOG.md`).

## Headless test setup used by Claude (Linux)

Claude runs tests inside the Cowork Linux VM on Nathan's PC, against a copy of the project. This is real Godot 4.7.2 and real Jolt, but it is Linux, headless (no window, no GPU), not the Windows build.

```
rm -rf $HOME/jss_test && mkdir -p $HOME/jss_test
cd <project folder> && tar --exclude=.godot --exclude=tests/reports -cf - . | tar -xf - -C $HOME/jss_test
cd $HOME/jss_test
$HOME/godot/godot --headless --import >/dev/null 2>&1
$HOME/godot/godot --headless --path . res://tests/test_runner.tscn
timeout 30 $HOME/godot/godot --headless --path . --quit-after 180 2>&1 | grep -iE "error|warning"
```

Godot is never run inside the mounted project folder, because it writes caches there. The last command runs the main scene for 180 frames; clean means no output.

Optional: with `xvfb-run` and Mesa software OpenGL, `godot --rendering-driver opengl3` renders the real Compatibility renderer, which is how the screenshots in `tests/reports/shots/` were made. That path is slow, and shows nothing about GPU behavior or speed. A short video can be made the same way with Movie Maker: `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . <scene> --write-movie out.avi --fixed-fps 30`, a throwaway scene script driving the real controllers, then `ffmpeg -i out.avi -an -c:v libx264 -crf 24 -pix_fmt yuv420p out.mp4`. It renders at about 0.2 s a frame in the VM (a 16 s video took 2 minutes; in chunk 6B a 22 s, 1280x720 video took about 0.18 s a frame; in chunk 7B a 21 s one took 107 s and a 16.6 s one 89 s, about 0.17 s a frame), so it must finish inside one 180 s call (keep a clip under about 900 frames); the video runs at the fixed frame rate, not in real time. A capture script can press the real input actions with `Input.action_press` and `action_release` (the stalk key, E), call `press()` and `release()` on the jump controller and set `stick_override` on the player controller, so a hunt is driven through the real controllers; to find out how a scripted clip ends without drawing it, run the same script with `RenderingServer.render_loop_enabled = false` and `--fixed-fps 60` (a second or two), which gives the same events tick for tick. Stills are best made the same way with `--fixed-fps 60` and the render loop off between shots, so that a picture costs only three drawn frames of simulation.

## Evidence identity and snapshots (A-020)

The runner report's header ties a result to what produced it:

- `source_hash_md5`: `scripts/`, `scenes/` and `data/` (`.gd`, `.tscn`, `.tres`, `.json`, `.gdshader`), path and bytes, in sorted order. The algorithm is unchanged since chunk 2 (chunk 5's value, `c4c8b725...`, is reproduced by the new code, and a unit test compares it with an independent copy of the old loop). Changing line endings changes it.
- `settings_hash_md5`: `project.godot`, so a changed renderer, physics or input setting shows.
- `tests_hash_md5`: the `.gd` and `.tscn` files under `tests/`, not `tests/reports`, so a changed test shows.
- `evidence_id`: the first 12 hex digits of the md5 of the three, so it changes when any of them does. The runner prints `evidence_id: ...` just before the SUMMARY line, and the four gate reports (`m01_report.txt`, `m02_report.txt`, `m03_report.txt`, `p01_report.txt`) carry the same line.

All of it is in `tests/evidence.gd` (hashing, the file lists, the archive writer), which `tests/test_runner.gd` and `tests/snapshot.gd` use.

**A snapshot** is a complete copy of the project as it was when a report was made, so the evidence can be looked at later: double-click `snapshot.bat`. It finds Godot the way `run_tests.bat` does and writes `tests\reports\snapshots\<UTC date>_<evidence id>.zip`. The archive holds every file except `.godot/` and `tests/reports/` (which also keeps archives out of archives); hidden files such as `.gitignore` are in; every entry sits under one top folder named like the zip, and `SNAPSHOT.txt` comes first with the three hashes, the engine and the file count. It is a standard zip, and Windows opens it directly (right click, Extract All). Before the exit code is 0 the file is read back and every entry is compared with the file it came from. Run `snapshot.bat` after `run_tests.bat` without changing anything in between and the file name carries the same id as `tests\reports\last_report.txt`.

By hand: `godot --headless --path . --script res://tests/snapshot.gd`, optionally `-- --out=<folder>`. The last line starts with `SNAPSHOT` and gives the path, the file count and the id. In the Linux VM, run it on the fresh copy (Godot is never run in the mounted folder) with `--out` pointing at the project's `tests/reports/snapshots`; the archive then also holds the `.uid` files the import made, which a copy back into the project folder makes the same anyway.

## Things to know

- Physics queries do not see bodies added in the current frame until the first physics tick. The camera rig handles this (see `snap_to_target` in `camera_rig.gd`); new code that queries right after building a scene must too. Chunk 6B found the other end of the same thing: a body added during a physics tick has its transform applied only when the engine next flushes transform notifications, so a cast made in that same tick finds an empty world, and "no hit" there means a full boom. The rig now trusts a boom cast only once the world can be seen (`is_world_ready()`: at once if the cast was made outside the physics step, after one completed physics tick if inside one). It was an intermittent failure of `test_camera.gd` on Windows (2026-10-07), reproduced here with `--fixed-fps 15` and `10`; `test_camera_ordering.gd` pins the ordering. The spider motor does: after a spawn or teleport it looks for support for up to three ticks, holding still, before it may fall (`ACQUIRE_TICKS` in `spider_motor.gd`).
- The full test suite takes about 981 s of real time in the Linux VM (chunk 7B: unit 1 s, integration 842 s, gates 138 s; chunk 7A took 676 s: unit 1 s, integration 589 s, gates 86 s; chunk 6B took 560 s: unit 1 s, integration 474 s, gates 85 s; chunk 6A took 345 s and chunk 5 265 s; the physics runs at 60 ticks per second, and most of the time is tests waiting in game time). The runner's watchdog is 1500 s (it was 900 s until chunk 7B, 600 s until chunk 6B and 420 s until chunk 6A; keep it well above the suite's time). A tool call in the VM is cut off at 180 s, so the final, real-time check is run in parts, each in its own call with `timeout 175`: `-- --only=unit`, `-- --only=integration --part=1/8` to `--part=8/8` (75, 59, 28, 7, 27, 81, 59 and 138 s in chunk 6B; the slices are contiguous runs of files by name, so the eighth, with the 22-test `test_tether.gd`, `test_test_target.gd` and `test_walking.gd`, is the longest, 37 s under the cap: if tests are added there use `--part=1/9` and so on, or `--files=`), and `-- --only=gates` (85 s, of which gate P01 is about 53 s). Sync and import the fresh copy in a call of its own first (about 10 s). **Chunk 7A:** 381 tests, 676 s of real time, in the unit part, eight integration parts (`--part=1/8` to `--part=8/8`; 77, 69, 28, 7, 74, 110, 78 and 146 s) and the gates part (86 s); the eighth part was the longest, 29 s under the cap. **Chunk 7B:** 469 tests, 981 s of real time, in the unit part (1 s), **twelve** integration parts (`--part=1/12` to `--part=12/12`; 75, 60, 24, 23, 8, 80, 25, 96, 116, 139, 59 and 137 s) and the gates part (138 s, of which A01 and L01 are about 27 s each and P01 about 53 s). The longest integration part (10/12) is 36 s under the cap and the gates part 37 s under: split before adding tests to either (`--part=1/13`, or `--files=`; `--only=gates` has no parts yet, so a new gate may need its own call: `--only=gates --files=a01`). The suite grew by 305 s for 88 tests because the fly tests wait in game time (a stalk is 6 s, a flight 1 to 3 s, a replacement 25 to 45 s unless a test shortens it); the watchdog was raised to 1500 s. The same suite takes 52 s at `--fixed-fps 60`, 46 s at 30 and 57 s at 144, in one call each.
- For quick iteration, `godot --headless --path . res://tests/test_runner.tscn --fixed-fps 60` runs the same suite in about 25 s (chunk 7B: about 50 s; frames are not paced to the clock). It is not the final check, but `--fixed-fps 30` and `--fixed-fps 144` are a cheap way to see whether a test depends on the render frame rate. Anything eased in `_process` (the aim tilt, recenter) must be waited for in physics ticks (`wait_until`, `physics_frames`), not in a fixed number of rendered frames: a headless run draws hundreds of frames a second.
- A headless run has no mouse, so mouse capture and mouse look are checked by calling the rig directly, not through a real device.
- A capture or test script that sets `rig.yaw` or `rig.elevation` itself to place the camera must also set `rig.line_framing = false` before a line is out: with it on (the default) the camera turns itself while the spider is on the line (A-017), and a scripted view would be fought over. The player's own look input always wins, so a real player is never fought.
- The catch camera check (`tests/integration/test_catch_camera.gd`, probe in `tests/catch_camera_probe.gd`) measures every physics tick with no camera input and writes `tests/reports/catch_camera_report.txt`. Its numbers move by a tick or two from run to run (the view is measured as the renderer interpolates it), so its bounds have a margin; it asserts the result, not the exact figure.
- The gate group is every file in `tests/integration/` named `test_m0*.gd`, `test_p0*.gd`, `test_a0*.gd` or `test_l0*.gd` (`--only=gates`): M01, M02, M03, from chunk 6B P01 (`test_p01_perception.gd`: eight fixtures with the labelled test target in the lab's stage) and from chunk 7B A01 (`test_a01_fly_evidence.gd`: five fixtures) and L01 (`test_l01_feeding.gd`: four fixtures, and a second test that reports "not run" for saving and loading until T09 gives the game a save system). Each writes its own report with the evidence line (`m01_report.txt`, `m02_report.txt`, `m03_report.txt`, `p01_report.txt`, `a01_report.txt`, `l01_report.txt`); the cost of six flies is written by `test_prey_cost.gd` to `t07_cost_report.txt` (not a gate). The prey tests build on `tests/prey_test_case.gd` (a world with the director ready, flies on named perches, a spider walked or stalked by its movement intent) and the gates on `tests/gate_fixture.gd`.
- Perception tests (`tests/integration/test_sensor.gd` and its neighbours) build on `tests/perception_test_case.gd`, which makes the world, the spider, the sensor and the memory and steps them in physics ticks. Tests that need exact geometry (a speck behind a barrier, two look-alikes crossing behind a screen) use `tests/sensor_rig_case.gd` instead: a bare observer at the origin, walls that can be raised and lowered, balls with ids the test may swap, and the real sensor and memory with the shipped species numbers. The sensor runs before the spider's motor (`process_physics_priority` -10), so anything that steps the world gets the same order as the game.
- Godot writes a `.uid` file beside every new script when it imports the project. It is never run in the mounted folder, so after adding scripts copy the new `.uid` files from the fresh copy into the project (chunk 6B added 23, chunk 7A four, chunk 7B the ones for the 14 new scripts and 15 new test files); the archive made on the fresh copy holds them either way.
- The report header identifies what produced it: `source_hash_md5`, `settings_hash_md5`, `tests_hash_md5` and `evidence_id` (the section above).
- `.gitattributes` forces LF for text files and CRLF for `*.bat`.
