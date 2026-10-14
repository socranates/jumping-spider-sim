# Windows controls and recovery acceptance — 2026-10-14

Imported Claude's verified bundle at 156da67 and pushed claude/roblox-controls-recovery. Original evidence 80504bccb4e8651f rebuilt byte-identically on Windows. Original command-line suites: 182 pure, 15 box-world, 11 client smoke, 72 look, 71 world; all passed.

## Native findings and fixes

Studio 0.743.0.7431133 first returned 47/50, with all seven client playback rows and ten-miss recovery passing. Three failures:

- Lowering beside the back wall could enter the wall at a shallow contact. Separate sweep contacts along their normal; while lowering along a wall, maintain a 0.01-stud skin with a short face ray. Other surfaces retain swept landing/contact rules. The unchanged wall penetration assertion now passes. Broader contact correction was tested and rejected because it altered other landings.
- The landing endpoint used a 1e-6 tolerance against float32 Roblox Vector3 integration. Use 1e-4 stud (still far below the 0.01 contact skin), and include error magnitude in a failure. The solver is unchanged.
- Runtime scripts cannot read Lighting.Technology or MaterialService.Use2022Materials. Verify both authored values in the build tool; remove the inaccessible runtime row. This is why Studio now has 49 rather than 50 rows. Materials, light direction, decor isolation and graphics objects still have engine checks.

Final engine evidence **cf31cbabad2e9cad**: **49/49**, plus **7/7** actual client scripted checks. The ten misses recovered 10/10 on native queries. Same recovery scenarios pass **15/15** under CLI after the fix. Reports are stored alongside this file. No Godot gameplay, tuning, SPEC or tests changed. The added profiler is isolated from both delivered places.

## Device scope

Nathan confirmed no controller or tablet is available: physical gamepad triggers, physical multi-finger touch and low-end-device performance are **not run**. Emulation and simulated action holds are not substitutes for those checks. See the handoff for the remaining human play list.

## Reproduction

Run tests/run.py and tools/build.py as in the handoff. Collect native reports with tools/collect_studio_report.py. For timing, run `python tools/build_profile.py path/to/rojo output-directory`, open full.rbxlx or low.rbxlx and Play. The isolated place substitutes tools/profile_play.luau for the test playback, with no server test fixtures. It drives the real client motor/camera through the same ten misses in rendered time, records RenderStepped intervals, separates the first five seconds, and prints PORT_PROFILE and ten PORT_PROFILE_CASE rows. Do not take screenshots or change window focus until the report appears. This measures Studio with the surrounding applications open, not a standalone Roblox client or a phone.

## Full-detail timing

AC power (battery status 2, 98%), AMD Radeon(TM) Graphics, Studio viewport 821 x 473, one running simulation. Full tier: 1,767 measured route frames, median 16.674 ms, p95 19.637 ms, worst 74.624 ms; 10/10 rendered recoveries. The initial five-second period is separate in profile-full.json (only 16 delivered render callbacks during startup, so it is not a complete loading-time measurement). No screenshots or focus changes during the accepted timed route. An earlier window-focus-interrupted attempt was discarded. No claim of full-screen 1080p, standalone-client, or tablet performance. There is a tail hitch to investigate; this is not a claim that every frame meets 60 fps.

Low tier: 1,791 route frames, median 16.653 ms, p95 19.142 ms, worst 157.598 ms, 10/10 rendered recoveries. No render callbacks arrived during its initial five wall-clock seconds: this sample can include initial rendering cost and is **not a warmed steady-state comparison**. These runs do not prove low detail is faster. Keep startup/tail-hitch and physical low-end-device profiling open. The tool and raw summaries are committed so the follow-up can start its warm-up from the first rendered frame rather than elapsed load time.

Keyboard V switched to spider-eye view; Escape opened and resumed the Roblox menu. The native sun selection reported through-the-window (clock 10, latitude -40.7), with all graphics isolation/material/direction checks green. Native screenshots accompany this report. The stylised coat and banded legs render in both tiers; low detail is visibly smoother. This is a visual smoke check, not Nathan's aesthetic acceptance.

Studio's iPhone XR landscape emulator: dragging the open view rotated the camera, and tapping Eye switched to spider-eye view. Both are captured in touch-landscape.jpg and touch-eye.jpg. Controls stayed within the screen, but Creep, Cancel and Re-center wrap awkwardly; improve these short labels/layout in the next UI pass. Physical simultaneous touches and a full human held-aim feel check remain unverified; scripted client playback covers the action combinations.
