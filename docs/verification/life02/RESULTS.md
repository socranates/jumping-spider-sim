# LIFE round 2 - Windows verification, 2026-10-12

Game source: main **5ea6a45**. Windows full suite **600/600**, evidence **7c9539fd72c1**, matching Claude. No game-code changes in this round.

## Visual checks

Graphical Godot 4.7.2 Compatibility/OpenGL, Radeon integrated GPU, 1280 x 720. The excluded `check_laptop.gd --visual` fixture uses isolated APPDATA, autosave disabled for settings and a separate checkpoint directory. It places the clock at representative hours, then allows normal physics and lighting updates. This is a staged rendered check, not a full day of manual keyboard play. Native key automation's previously documented physical-key-code limitation remains.

- Morning 08:00: warm lit floor and clear silhouettes. Midday 13:00: shorter shadows. Dusk 19:36: lower light and longer shadows; no blank or broken surface observed in either camera view.
- Night 23:00: clearly dark. Sill boundary, planter and window silhouettes remain visible; the eye view preserves large navigation shapes but small ground seams and prey detail are harder to distinguish. Captions remain legible. This is a visual assessment of laptop-rendered captures, not a guarantee under glare or every display brightness. No brightness adjustment made.
- Actual retreat rest API accepted the settled spider at 19:00. The real tick-by-tick sleep advanced into day 2, woke around 07:00, kept a valid day-two checkpoint and displayed the morning notice. `visual-log.txt` records the sleeping and wake states; `sleeping.png` and `morning_after_sleep.png` show them.
- Abdomen visibly thins and fills. The real needs model receives a controlled 24-hour awake drain, then a named 0.90 energy fixture grant. Presentation receives its ordinary energy-change notifications and eases from condition 0 through 0.258 at the intermediate capture to about 0.899. Scale x/y grows from 0.84 to about 1.11. No direct body-scale writes. These closeups verify the display/needs link, not a captured fly meal or 24 hours of continuous play. Twitch stays active.

## Performance method

Separate graphical run with **no screenshots or frame readbacks** during timing. Plugged in, Balanced power plan, 720p, VSync on. Eight 30-second phases: morning, midday, dusk and night, each in orbit and eye view. Each phase starts at 08:00, 13:00, 19:36 or 23:00 and the normal life clock continues advancing; the sun angle is logged each frame. At full night solar energy is zero and its angle is clamped, as designed.

120 rendered warmup frames precede timing. The scripted spider walks between x=-22 and -10 at z=6, with normal prey, body animation and life updates. Controller input is disabled only for the repeatable route. Phase changes and first-use stalls remain included. No test suite, exports or other game runs overlap the timed run. The initial window activation is not excluded. This is one source/debug-runtime run, not release-executable timing, a human hunt, or an isolated measurement of shadow overhead versus a frozen sun. No causal comparison with the earlier shader A/B is claimed.

## Measured results

| Phase | Mean frame ms | Frame p95 ms | GPU p95 ms | Sun X start -> end degrees |
|---|---:|---:|---:|---|
| morning orbit | 16.694 | 17.380 | 6.042 | -34.054 -> -36.976 |
| morning eye | 16.676 | 17.262 | 6.260 | -34.054 -> -36.976 |
| midday orbit | 16.712 | 17.430 | 6.361 | -55.000 -> -54.851 |
| midday eye | 16.666 | 17.300 | 6.417 | -55.000 -> -54.851 |
| dusk orbit | 16.666 | 17.178 | 4.553 | -21.317 -> -18.002 |
| dusk eye | 16.666 | 17.219 | 5.558 | -21.317 -> -18.002 |
| night orbit | 16.666 | 17.245 | 4.606 | -18.000 -> -18.000 |
| night eye | 16.666 | 17.250 | 5.691 | -18.000 -> -18.000 |

14,391 frames in 240.009 seconds. Overall mean **16.677 ms (~60 fps)**, p95 **17.274 ms**, p99 **18.108 ms**, maximum **94.642 ms**. Three frames exceeded 33.3 ms, two exceeded 50 ms. All such frames were in the first three phases; no dusk or night frame exceeded 33.3 ms. The strict 16.7 ms p95 target remains missed; do not mark F01's budget clause passed.

Midday eye has the largest GPU p95 (6.417 ms); midday orbit has the largest frame p95 (17.430 ms). Night eye GPU p95 is 5.691 ms versus 4.606 ms in night orbit. This run shows no sustained night slowdown. A moving daylight sun is confirmed in the per-frame angles; absence of rotation at night is the existing clamp, not a disabled clock. This does not isolate the cost of changing shadows from camera framing, prey or other work.

Power endpoints both show BatteryStatus 2, charge 100%. Raw trace `frames.csv.gz`, `frame-summary.json`, `profile-log.txt`, `power-*.json`; analyzer uses nearest-rank percentiles. Run `check_laptop.gd` with the editor executable, without headless/fixed-fps flags, and separate APPDATA. `--visual` selects the independent screenshot/sleep/body run. Tests use fixed60 and are not performance evidence.

## Friend exports

Nathan requested both rebuilds. Windows x64 and single-threaded Web release exports use official Godot 4.7.2 templates and unchanged 5ea6a45 game code. Both export logs have no ERROR/WARNING matches. Excluded developer fixtures remain outside the game packages; notebook JSON is present. ZIPs include controls, caveats and Godot/third-party notices. CRC/layout checks and SHA-256 manifest are in `friend-builds.json`.

Windows executable launch/render smoke check: day-one morning, habitat, spider and shadows visible (`windows-release.png`). New isolated APPDATA. No new claim of physical keyboard/controller play; the existing native key-injection limitation remains.

Web release: day-one morning and green eye picture render; N opens/closes the sourced notebook, V changes views, W moves, T exits the previously saved 50% slow-motion preference, and arrow-key look turns the view. After being left running across a user pause, the browser reached day-four night with zero reserves; the final orbit capture shows the retreat silhouette, floor edge and silk still readable in dim light. This is an additional web-night observation, not a timed continuous playthrough or survival/death test. No gameplay time acceleration was applied in the browser.

The embedded browser reported `WrongDocumentError` for pointer lock and the known Chromium `UnknownError` (`web-console.json`). Keyboard controls worked despite these. Mouse-look is unverified; origin of these browser errors is unresolved. Sound needs listeners, and controller-only play needs hardware. Do not present these builds as all-gates-closed or fully validated on external browsers.

Delivery: Downloads/The-Windowsill-Playtest-2026-10-12-LIFE1. Windows ZIP extracts to TheWindowsill.exe plus its .pck. Web ZIP has index.html at root and needs HTTP/HTTPS hosting. Nothing published to itch.io. Filenames identify 5ea6a45 game source; the later evidence/handoff commit changes no gameplay.
