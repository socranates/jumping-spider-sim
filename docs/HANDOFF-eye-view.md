# Spider-eye view — Claude, 2026-10-11

Nathan asked for "a first person spider eye mode so its more immersive", with "scientific realism in terms of vision and movement". Claude built it on top of Chet's live legs (`main` at f23f67d). Decisions EYE-01 … EYE-06 in `docs/DECISIONS.md`.

## How to play it

- Press **V** (controller **Y**), or tick **Spider-eye view** in the Esc menu. Press again to go back to the normal camera. The game remembers the choice.
- You see from the spider's front eyes. The mouse looks around, and W walks where you look.
- Only a small oval in the middle is sharp: that is where the two big front eyes point. The rest is soft and nearly colourless, like the six other eyes.
- Look up to about 30 degrees aside and the front eyes follow without the body moving. Look further while standing still and the spider turns to face it. The picture goes soft for a moment until it does.
- Look down and the spider tilts its head. Look sideways and you'll see its front legs.
- Aiming a jump is looking at where to land.
- On a wall or an underside the view turns with the spider, gently: about 0.4 s for a 90 degree edge.

## What changed (files)

- `scripts/movement/camera_rig.gd`: the eye mode (`set_eye_view`, `gaze`, `map_stick`, `principal_offset_deg`, the carried up and its 240 degrees a second limit). The orbit camera is untouched when the mode is off.
- `scripts/movement/spider_motor.gd`: `set_scan_direction` and `get_body_gaze_direction`. `get_gaze_direction` (the senses' axis) follows the scan within `PRINCIPAL_SCAN_DEG`, and the head tilts toward it.
- `scripts/movement/player_controller.gd`: walking through `camera_rig.map_stick`; in the eye view the scan direction is set each tick, and standing still the body turns to the gaze when it is out of reach (`is_eye_turning`).
- `scripts/presentation/eye_view_overlay.gd` (new): the shader and the words.
- `scripts/presentation/spider_body.gd`: `set_eye_view` hides everything but the legs.
- Input, settings, key names, pause menu and field notes gained `eye_view` (V / Y, remappable on both). The T09d test that remapped aiming to Y now uses the right shoulder, since Y is taken.
- Tests: `tests/integration/test_t10a_eye_view.gd` (8).

## Verification

- **Evidence 7169ecfd3663**: the full suite passes 544 / 544 (Linux headless, fixed 60 fps, Godot 4.7.2), including 8 new eye-view tests (`docs/verification/t10a/full_report_t10a.txt`).
- The eye-view, camera, Focus, T09d and U01 tests also pass at fixed 30 and 144 fps, 56 / 56 each (`fps30_eye_camera_tests.txt`, `fps144_eye_camera_tests.txt`).
- The main scene smoke run is clean.
- Stills come from the real windowsill in the Compatibility renderer under software OpenGL (`docs/verification/t10a/`):
  - `t10a_orbit_view_before.png`: the normal camera.
  - `t10a_hunting_view.png`: a fly and the cues through the eyes.
  - `t10a_turning_to_look_first_frame.png`: looking 70 degrees aside, with a front leg in view and the explanation on screen.
  - `t10a_turned_to_look.png`: the body has turned.
  - `t10a_head_tilted_down.png`: looking down; the head tilts and the window stays.
- **Not run on Windows, and no human has played it yet.** Nathan's judgement of the feel is the real test.

## For the next owner

- The picture is a first pass. Things to tune by playing: the window size (`SHARP_DEG`), the blur (`blur_px`, `grain_px`), the colour contrast, the 80 degree field, and the roll rate.
- Not done (EYE-06): depth from defocus, UV markings, a motion effect in the secondary eyes, a level-horizon option, a colour-free accessibility variant.
- Cross-device goal (PLATFORM-01): the view is plain Godot (a Camera3D and a canvas shader). It works with a controller (Y) and in the Compatibility renderer that the Web export uses.
