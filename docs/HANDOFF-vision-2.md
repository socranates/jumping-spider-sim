# Vision realism part 2 — Claude, 2026-10-11 (T13a)

ROADMAP step 5, after Chet's movement round (1d2fb44). Nathan: "chet just finished and its freakin amazing ... shall we continue?"

## What changed

- **Motion-sensitive surround** (`scripts/presentation/eye_view_overlay.gd`, `scripts/perception/sensor_system.gd`). The sensor now keeps `motion_seen`: each thing its sightline checks found moving (at or above the existing motion threshold), with the sensed direction, distance and apparent size. An entry lasts 15 ticks after the thing was last seen moving. Only the eye view reads it. There, each mover gets a pulsing ring (3 Hz) and a faint halo where it is drawn, as dark on pale ground and pale on dark ground. A mover is weaker, or missing, inside the sharp retinal fields. Up to 8 movers show at once, strongest first. Reduced motion holds the ring steady. The orbit view has none.
- **Comfort switches** (Esc menu, off by default):
  - `eye_level_horizon`: the eye camera's up is the world's up laid square to the gaze. Looking nearly straight up or down a wall, it holds the up it last had, so it never flips. With it on, mouse and stick turn the picture about the view's own up and right, so the controls match what's on screen. Aim, walking and senses still follow the gaze (`camera_rig.gd`: `view_up()`, `_look_eye()`).
  - `eye_colour_free`: the same green-weighted brightness, shown grey; the label says "(shown grey)" and still "UV not simulated".
- **Notice placement.** The eye view's 7-second opening notice moved from low on the screen, where it covered the sound captions, to just under the top lines.

## Deliberately not done

- **Depth from defocus** (EYE-13). A faithful version changes jump accuracy with light and distance, and so changes approved gameplay and the movement gates. It needs Nathan's decision. See VISION_RESEARCH.md.
- **UV** (EYE-14). See DECISIONS for what the evidence supports.

## Verification

- New tests: `tests/integration/test_t13a_motion_surround.gd` (5) and `tests/integration/test_t13a_eye_comfort.gd` (4).
- The eye, sensor, perception and sense tests pass 69/69 at fixed 30, 60 and 144 fps.
- Full-suite result and evidence: DECISIONS EYE-15.
- Stills: `docs/verification/t13a/`:
  - `eye_motion_shimmer.png`: a fly taking off in the surround;
  - `eye_grey.png`;
  - `eye_wall_rolls_with_body.png` and `eye_wall_level_horizon.png`: on the planter's side.
  - Reproduce with `--path . --script res://docs/verification/t13a/capture.gd`; it uses its own settings with autosave off.
- Linux headless and xvfb only. Not run on Windows, and not played by Nathan yet.

## Next

Nathan plays the eye view and judges the shimmer (too strong, too weak, distracting?) and the two comfort switches. He decides whether depth from defocus should make jumps less sure in poor light. ROADMAP step 6, handing back the slice, follows.
