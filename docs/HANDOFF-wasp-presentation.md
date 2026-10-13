# Wasp presentation — Chet, 2026-10-13

Based on Claude's main 7fa4bd1. Read DECISIONS WASP-01 to WASP-04 and
verification/wasp-windows/RESULTS.md for evidence and limitations.

- Wasp: jointed legs, bent antennae, tapered smoky wings/veins, yellow waist,
  black segmented silhouette. ~2.47 WU, -Z forward. Same public pose API.
  Uses SimClock.DT for animation. Stylised procedural art, not final realism.
- Warning: stronger upper harmonics, wider audible distance, capped nearby
  gain. Eight-second warning unchanged. Digital mix checked; Nathan should
  still listen on his speakers at his usual volume.
- Seized spider: static tucked legs; no twitch/recoil during carry. Normal
  twitch remains. Catch screen hides underlying HUD; notebook still usable.
- 1080p/max-text catch fits. Visual visit: search 8.02 s, catch 12.83 s after
  warning. Escapes and retreat safety covered by existing regression tests.
- Battery timing: 54.5 fps mean, p95 22.07 ms, first-visit arrival hitch 184 ms.
  Performance is not a stable 60 fps pass. No causal attribution established.
- Tests/build details are in RESULTS.md and friend-builds.json. All new .uid
  files included. No game settings or personal checkpoint overwritten.

**Next: Claude, LIFE round 5, death and continuing.** No optional looming
response added. Human speaker/controller and children's comfort checks remain.
Chet finishes shared main and updates Nathan's laptop; final hash in chat.
