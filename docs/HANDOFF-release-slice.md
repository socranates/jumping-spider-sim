# Chet handoff - The Windowsill friends slice, 2026-10-12

Started from main 48b84a0 after running the laptop updater. Read T13a and
shared workflow. Windows baseline **585/585**, evidence **db112e2fa006**,
matching Claude. No gameplay, SimClock, twitch, shader or control changes.

## Deliverables

Windows x64 and single-threaded Web release exports, Godot 4.7.2. Friend
instructions: `docs/FRIEND_PLAYTEST.md`. Engine/third-party notices accompany
each bundle. ZIP checksums identify exact artifacts in verification.
Local friend ZIPs are placed in Downloads/The-Windowsill-Playtest-2026-10-12.
The web ZIP is a hosting bundle, not a double-clickable HTML app. Nothing
was published to itch.io. RELEASE-01 remains the longer-term whole-life goal.

## Evidence

See `docs/verification/release-slice/GATES.md` for every spec gate, including
NOT RUN rather than invented human/controller/exhaustive graphical results.
Performance details and limitations are in `PERFORMANCE.md` in that folder.
The full baseline, logs, screenshots, raw compressed frame trace and summaries
are frozen there. Additional scripts are developer fixtures, excluded from
exports, with committed UIDs.

## Next agent

Review the friends' feedback before more scope. Do not describe the first
slice as 1.0 or all gates closed: M04's full graphical matrix, U01's physical
controller-only loop and E01/E02 human evidence remain open. S01 exact resume
was intentionally replaced by S01-C; do not silently reinstate it.
Keep the twitch, SimClock.DT timing, eye-view approximation labels and .uid
workflow. Prefer measured performance changes over speculative simplification.

## Export limitations and measured speed

Native and web eye shaders render. Browser walking/hop/V/T/pause and a
preference reload worked. Native physical-key automation is inconclusive
(tool emits the wrong physical code); sound needs a listener, controller
needs hardware. Browser Chromium UnknownError remains unexplained. See
`EXPORT-CHECKS.md` for precise scope; do not claim both complete human
playthroughs. These are labelled friend-test artifacts.

Five-minute source/debug rendered run on battery: 56.8 average fps,
21.448 ms p95 at 720p; normal eye view slowest, 51.6 fps / 23.534 ms p95.
Two real strike attempts and successful struggles, using an arranged
encounter and scripted control. F01 reporting clause satisfied; 16.7 ms
p95 budget missed. Screenshot/setup stalls remain in the trace.
