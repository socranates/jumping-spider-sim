# One game clock, slow motion and the view switch: Claude, 2026-10-11 (T11a)

Built on Chet's T10b (`main` at 5789ca7). ROADMAP step 2, plus Nathan's "add a button that can easily swtch between first and 3rd person". Decisions CLOCK-01 … CLOCK-04.

## For the player

- **Slow motion.** Press **T** (controller **right trigger**), or tick it in the Esc menu. The whole world slows evenly: the spider, the flies and the jump. Looking around does not slow. Esc → Slow-motion speed picks 25, 50 or 75 %. While it is on, a line in the bottom-right corner says "SLOW MOTION 50%" and names the key to end it. The choice is saved.
- **Switching views.** **V** (controller **Y**) switches between first person (spider-eye view) and third person.
  - In third person, a line at the top right says "V / Y: first person (spider-eye view)".
  - In first person, the tag says "V / Y: third person".
  - The Esc menu has a "First person / Third person" button.
  - Both keys can be remapped.
- The field notes (H) list both.

## How it works

- `scripts/core/sim_clock.gd`: `HZ` (60) and `DT` (1/60 s) are the game's clock. Every system now counts in them instead of `Engine.physics_ticks_per_second`: the motor and its jump plans, the jump and line controllers, and the senses.
- `SimClock.set_speed(s)` sets the engine to 60 × s ticks a second and `time_scale` to s. Each tick's delta is therefore still exactly 1/60 s, and only the number of ticks per real second changes. That is why a hunt replays tick for tick.
- Camera controls use `SimClock.real_delta()`: stick look, recenter, the aim's return and the eye view's recenter. `real_delta` also handles a speed change in the middle of a frame; without that, the camera jumped by the speed ratio for one frame.
- `main.gd` applies the speed in played worlds only and puts it back to normal when a world ends. Test worlds never change it.
- New `scripts/presentation/slow_motion_hud.gd` handles the line and the key.
- The pause menu's button row now wraps (`HFlowContainer`), so the extra button fits at 150 % text.

## Verification

- **Evidence e530e2f0810d**: 553 / 553 (Linux headless, fixed 60 fps), including 5 new tests in `tests/integration/test_t11a_slow_motion.gd` (`docs/verification/t11a/full_report_t11a.txt`).
- The slow-motion, eye-view, retinal-scan, camera and controller tests pass at fixed 30 and 144 fps, 47 / 47 each.
- The determinism test matches every tick of a stalk and a strike at full and half speed within 1e-5 WU. A real V key press switches the view.
- The smoke run is clean.
- Stills: `t11a_slow_motion_third_person.png` (the slow-motion line and the view hint) and `t11a_pause_menu.png`.
- **Not run on Windows, and not played yet.**

## For the next owner

- Holding Space to aim counts game ticks, so in slow motion the hold to start aiming takes longer in real seconds, and a tap is easier. If that feels wrong in play, the hold could be measured in real time instead.
- Chet's retinal scan clock runs in game time, so the sweep slows in slow motion along with everything else.
