# Whole-life Windows check — Chet, 2026-10-13

Started from Claude's main 120abc5. Windows baseline: **640/640**, evidence **a4165eb2beb4**, matching Linux. Final: **644/644**, **2c1c789ef545**, Godot 4.7.2, Compatibility, Jolt; 1,742 seconds of fixed-frame time, watchdog 2,400. Related life/wasp/menu/leg tests: **27/27 at fixed 30, 60 and 144 fps**. Headless results are correctness evidence, not performance evidence.

## What changed

- Start menu is below the notebook. Accept activates its focused choice, including A/Space. Its height is bounded with focus-following vertical scrolling at large text sizes.
- Starting over requires a second press on the same mode. Easy confirmation no longer edits the Standard button or confirms a different mode. Short confirmation text stays in the panel.
- End-screen accept activates the focused button instead of silently choosing the default continuation. Three choices stack vertically; the summary width fits the scaled viewport.
- Notebook discovery toasts stay out of paused menus and end screens.
- The wasp body is drawn for two frames in a private 96 x 96 offscreen world at load. Headless runs skip it; the temporary viewport is freed, including if its owning wasp exits early. No director state, visibility to the spider, movement rules, jump physics, twitch or SimClock timing changed.

Four new regression tests first failed on the old code (`ui-before.txt`) and pass after the fixes. The first full rerun also found our new UI test left the tree paused, breaking later movement fixtures. The test now restores pause/text/window state in teardown; `test-isolation-failure.txt` records that superseded failure. The final full report contains zero failures. Every new script has its UID.

## Native play and release checks

These are staged graphical checks with isolated disposable saves, not an uninterrupted human whole-life playthrough. `check_life.gd` advances needs hours to reach starvation, starts the third moult from a staged subadult, and forces a predator visit in free play. `profile_arrival.gd` stages an actual Standard visit, inspection, strike and carry.

| Check | Result and evidence |
| --- | --- |
| Start menu keyboard/mouse | Windows release: Down moved focus to Free play, mouse opened Notebook, Escape returned focus, Enter reopened Notebook. `windows-notebook.png`. |
| Controller navigation | Injected Godot key/joy events: D-pad and left stick move focus, A activates Notebook on start/end screens. No connected controller (`CONTROLLERS []`); hardware play remains not run. |
| Large text | 1920 x 1080, 150% text: all-options menu fits a 456-high logical viewport region and scrolls; end summary and three choices fit. `all_options_large.png`, `wasp_three_choices_large.png`. Normal-size screenshots are also retained. |
| Starvation | Starving → weak warning → plain starvation end; another young juvenile starts elsewhere and keeps notebook pages. `native-large.txt`, `starved_large.png`. Fixture advances needs, not the calendar, hence its short life-summary duration. |
| Actual wasp catch → another | Strike/carry/end occur through director states. New spider at (-8, .31, -10), unrelated notice; all four discovered notebook pages retained. `native-catch.txt`, `caught_large.png`, `another_after_catch_large.png`. |
| Last rest | Retreat checkpoint kept; end screen offers Back; new world reports `RESTORED true ALIVE true`. `native-large.txt`, `last_rest_large.png`. |
| Adult → Easy | Third moult completes through habitat ticks, stage 3 and Easy true; menu shows Easy. `adult_large.png`, `all_options_large.png`. |
| Free play | Forced visit touches then leaves: spared true, seized false, life ended false, mode free. `free_touch_large.png`. |
| Web release | Local HTTP: Quit absent; mouse opens notebook above menu; Escape restores focus; Up/Enter starts Free play; V renders the eye shader. `web-menu.png`, `web-eye.png`. |

Early native fixtures with zero prey needed `ensure_ready()` after replacing the world; without it their checkpoint attempt correctly refused “world is still starting.” Corrected fixtures retain the successful real save/restore evidence, rather than treating the initial “another spider” fallback as a checkpoint pass.

Web still reports the embedded browser's pointer-lock `WrongDocumentError`; mouse-look is not cleared by this check. Keyboard navigation and rendering work. See `web-console.json`. Speaker listening and children's comfort require people. Live habitat HUD text can still crowd at maximum size; this round fixes the start/end panels, not all HUD wrapping. The adult summary still says “a adult,” a minor existing copy issue.

## First-arrival measurement

Nathan's laptop, AMD Radeon integrated graphics, Windows OpenGL Compatibility, 1920 x 1080, normal text, VSync, isolated APPDATA per run. BatteryStatus 2 / 80% (`power.json`, external power). No screenshot readback, audio capture, exports or test suite during these timings. Fresh Godot user shader caches; driver cache was not cleared. GPU query values were zero, so use measured wall-frame intervals, not GPU timings. Runs ordered before1, warm1, before2, warm2, production final.

| Run | Arrival mean ms | Arrival p95 ms | Arrival worst ms | Arrival frames >33.3 ms |
| --- | ---: | ---: | ---: | ---: |
| Before 1 | 16.842 | 17.334 | 112.815 | 1 |
| Before 2 | 16.807 | 17.440 | 107.593 | 1 |
| Experimental warm 1 | 16.666 | 17.612 | 19.923 | 0 |
| Experimental warm 2 | 16.666 | 17.679 | 21.622 | 0 |
| Warm at load, production | 16.667 | 17.338 | 19.848 | 0 |

The repeated disappearance of the arrival spike supports keeping prewarming. This is consistent with first-draw material work; no driver trace proves the precise cause. Prior 184 ms was on battery and is not a same-condition baseline. Warm-up moves work to loading; loading cost was not separately measured. Production measurement preceded only the lifetime-cleanup connection, which does not change the draw path.

The full measured production visit averages 16.669 ms (~60 fps), p95 17.361 ms, worst 37.753 ms during inspection/eye-view transition. **Strict F01 remains open.** Prewarming fixes this observed arrival hitch, not every frame-time excursion. `frame-summary.json` and all five raw CSVs/logs retain the evidence.

## Reproduce and next step

Run native fixtures with Godot `--path . --script res://docs/verification/life06-windows/check_life.gd -- --large` (omit `--large` for normal). Profile with `profile_arrival.gd -- --profile`; the experimental `--warm` flag adds a second explicit warm-up and is only for reconstructing the earlier baseline experiment. Current game already warms at load. Use isolated APPDATA; do not overwrite a player's saves.

Windows/Web release exports use official templates, include notebook JSON and exclude developer fixtures. Friend ZIP names, hashes and source commit are in `friend-builds.json`. Nothing is published to itch.io.

Next is LIFE round 6: Nathan, his son and friends play a whole life. Check controller hardware, actual laptop sound, comfort/fairness, whether a full life takes the intended time, and mouse-look in a normal hosted browser. Record reports in PLAYTEST.md before choosing further implementation.
