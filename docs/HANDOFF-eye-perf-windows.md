# Handoff - Chet, eye performance and friend rebuild, 2026-10-12

LIFE_DESIGN round 0 is complete. Started with update.bat/main fa32368; no game-code changes. Read `verification/eye-perf/WINDOWS-T13b.md` for full methods and limitations.

- Windows baseline **591/591**, evidence **2c7264139c03**, matching Claude.
- Plugged in, Balanced, Radeon integrated GPU, 720p. Five-minute old/new shader routes have no screenshot stalls. Normal-eye GPU p95 **7.878 -> 6.612 ms**; quarter-speed eye **7.768 -> 6.279 ms** (16-19% lower). Frame averages remain near 60 fps under VSync; overall p95 **18.036 -> 18.109 ms**, so strict 16.7 ms target remains missed. Both routes caught and subdued a fly.
- Frozen-view uncapped screen: picture-on frame **6.060 -> 4.823 ms**; mipmap candidate **5.120 ms**. Keep Claude's six-read shader. The tested candidate is an implementation of the idea, not his unpublished exact text.
- Rebuilt Windows/web friend ZIPs from fa32368 game code, now with notebook N. Downloads/The-Windowsill-Playtest-2026-10-12-T13b. SHA-256 manifest: `verification/eye-perf/friend-builds.json`. ZIP root layouts and CRCs checked.
- Web eye picture, V/W/T and notebook N verified; native executable launch/rendering checked. Browser Chromium UnknownError persists without blocking these checks. Physical controller/native keys and listening still require people. No public upload and no claim all gates are closed.
- Twitch, SimClock, movement, camera and game files unchanged. Developer profiling fixture gains --no-screenshots and --shader-file; new frozen-view fixture includes UID.

## Next, Claude

Continue LIFE_DESIGN round 1: clocks and hunger, using Nathan's LIFE-03 answers. Do not re-optimize the eye view from the battery/screenshot-heavy old trace; use the plugged-in evidence here. Shader first use and hunt setup still have outliers. Timing here is graphical source/debug runtime, not release-executable performance.

Finish this round on main, push and run Nathan's laptop update.bat. Actual final commit is confirmed in chat (this document cannot embed its own hash). Old handoffs remain historical.
