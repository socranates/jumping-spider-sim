# T13b laptop comparison - 2026-10-12

Main at start: **fa32368**. Windows baseline: **591/591**, evidence
**2c7264139c03**, matching Claude. No gameplay changes in this round.

## Comparison setup

The production shader in **40aceee** (after) is compared with the shader
from **4c07efa** (before). Both run in the same current main scene with
the notebook. Git's code diff between those revisions is only the eye
overlay; current main's subsequent changes are documents. The fixture
substitutes only the old SHADER text; the extra new torsion_cs uniform
update is unused by the old shader. This isolates shader behavior without
switching branches or changing the player's installation.

Ryzen 3 7320U, integrated Radeon, 1280 x 720 viewport, Godot 4.7.2
Compatibility/OpenGL, Balanced power. Plugged-in status is recorded before
and after each run. One game at a time, no headless tests or exports in
parallel with GPU measurement. Ordinary desktop apps remain open.

The full runs use the same five-minute `profile_play.gd` route as the
previous handoff, now with `--no-screenshots`. No frame readback or PNG
write occurs during timing. VSync is on; 120 orbit frames warm up before
sampling. Both camera views, both quarter-speed views and an arranged live
hunt are included. Shader first use, phase switches, arranged hunt setup,
audio-buffer reads and ordinary OS scheduling remain in the raw timings;
this is not a pure shader microbenchmark or human playthrough.

## Supplementary frozen-view screen

`measure_laptop.gd`: same fixed eye view, no flies, VSync disabled, 120
warmup frames, three picture-off/on pairs of 240 frames each. Rounded
per-row means are preserved in the raw logs. The totals include the whole
frame, not an isolated GPU timer. Execution order: before, after, mipmap.

| Variant | Mean picture-on frame (ms) | Mean on-minus-off (ms) |
|---|---:|---:|
| Before: twelve full-resolution blur reads | 6.060 | 1.757 |
| T13b: six reads | 4.823 | 0.807 |
| Candidate: four mipmap reads | 5.120 | 1.213 |

The six-read T13b screen is about 20% faster in total picture-on frame
time. Its paired incremental cost is about 54% lower. These short-run
estimates are not a claim of a 54% whole-game FPS increase. The four-read
mipmap candidate is slower than six reads in all three on rows and in
every paired incremental result; keep Claude's six-read shader.

The candidate is a documented implementation of the four-mipmap-read
idea in results.txt, not a recovered copy of Claude's unpublished variant:
linear mip sampling at log2(blur_px), four diagonal taps at 0.35 radius.
Its exact text is in `mipmap-candidate.txt`. It is not shipping and no
visual-equivalence claim is made. Mipmap generation overhead is a plausible
explanation for its cost, not separately measured here.

## Reproduce

From the game root, using the editor executable and an isolated APPDATA:

```text
godot --path . --script res://docs/verification/release-slice/profile_play.gd -- --no-screenshots --shader-file=res://docs/verification/eye-perf/before-shader.txt
godot --path . --script res://docs/verification/release-slice/profile_play.gd -- --no-screenshots
```

Use distinct user-data directories and run sequentially. Do not pass
--fixed-fps or --headless. Supplementary screen uses measure_laptop.gd
and the same optional --shader-file argument. Candidate/reference text
files and measurement scripts are excluded from friend exports.

## Five-minute live route, no screenshots

Each row is 60 seconds. Frame p95 includes presentation/VSync and stalls; GPU p95 is the engine rendering counter, not a frame rate.

| Phase | Before frame p95 ms | T13b frame p95 ms | Before GPU p95 ms | T13b GPU p95 ms |
|---|---:|---:|---:|---:|
| Orbit | 17.214 | 17.290 | 6.240 | 6.356 |
| Eye | 17.326 | 17.261 | 7.878 | 6.612 |
| Eye at 25% | 18.221 | 18.163 | 7.768 | 6.279 |
| Orbit at 25% | 18.240 | 18.466 | 5.753 | 6.371 |
| Arranged hunt | 17.250 | 17.147 | 6.151 | 6.135 |

Normal-eye GPU p95 fell from 7.878 to 6.612 ms (16.1%); quarter-speed eye fell from 7.768 to 6.279 ms (19.2%). This agrees directionally with the frozen-view screen. Keep T13b; the mipmap candidate does not justify replacing it.

Whole-run frame means were 16.692 / 16.712 ms (about 60 fps both), p95 18.036 / 18.109 ms. T13b reduces GPU work but does not demonstrate a whole-game frame-rate gain under VSync. The strict 16.7 ms p95 goal is still missed. There were 4 / 9 frames above 33.3 ms, and 3 / 3 above 50 ms, including first eye use and hunt setup. Maximum frames were 324.309 / 263.034 ms. Phase switches/setup remain in the data; there were no screenshot readbacks or PNG files in either runtime.

Both runs completed one legal strike, capture and won struggle. Audio-buffer peaks were 0.89145 / 0.89161 (signal evidence, not listening). Power reports show plugged in (BatteryStatus 2) throughout the before/after endpoints; charge 87 -> 90 -> 93%. Raw CSVs are losslessly compressed as windows-live-*-frames.csv.gz, with logs, power records and nearest-rank summaries alongside.

These are rendered source/debug-engine runs, not release-executable timings. The controller is disabled for a repeatable scripted route, and live phase boundaries use wall time, so simulation ticks and trajectories can differ slightly. Only one live run per variant was taken. Short-run OS/scheduling variation is not attributed to the shader. The previous battery-powered, screenshot-producing run is not a valid causal A/B comparator.

## Friend builds and graphical checks

Rebuilt Windows x64 and single-threaded Web release exports from fa32368 game code (including notebook and T13b), official Godot 4.7.2 templates. Import and both exports succeeded with no ERROR/WARNING matches in the saved logs. Developer fixtures/reference shader text are excluded by docs/*; notebook JSON is included by data/**/*.json. ZIP CRCs verified; README and Godot/third-party notices included. Exact bytes and SHA-256: `friend-builds.json`. ZIP filenames identify the unchanged game-source commit; the later handoff commit contains documentation/measurement fixtures only.

- Windows executable launched with isolated APPDATA and rendered the habitat/spider; `windows-export.png` and `windows-export-log.txt`. This is a launch/render smoke check, not a new physical-input playthrough.
- Web served at localhost, in-app Chromium, 1280 x 720: green eye picture, soft surround, sharp scanning fields and prey marking render; V changes views; W walking changes the scene; T shows slow motion 50%; N opens and closes the naturalist notebook, with discovered pages and source text visible. Screenshots `web-eye.jpg`, `web-eye-slow.jpg`, `web-third-person.jpg`, `web-notebook.jpg`. This verifies rendering, not pixel equality to native or 25% browser timing.
- Browser console again reports nonfatal Chromium UnknownError (saved in `web-console.json`); no shader compiler error observed. Initial canvas click timed out during startup; after loading, direct canvas input worked. Existing site preferences selected eye view on entry.
- Native physical-key automation limitation from the previous round remains; listeners/controller users still need to check sound and controller play. Prior gate statuses in release-slice/GATES.md are not promoted to passes by this smoke test. F01 still misses 16.7 ms p95.

Nathan's Downloads folder: `The-Windowsill-Playtest-2026-10-12-T13b`, with Windows and web ZIPs plus manifest. Web ZIP is a hosting bundle (index.html at root), not a double-click desktop game. Nothing uploaded to itch.io.

Windows full-suite baseline: 591/591 at fixed 60 fps, evidence 2c7264139c03 (`windows-baseline-591.txt`). All changes this round are docs and excluded measurement fixtures; game/test bytes, twitch, SimClock and jump physics remain unchanged. New measure_laptop.gd UID is committed with its script. Raw exported logs and performance traces are developer evidence, not shipping assets.
