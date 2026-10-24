# Native long-traversal observations

One Studio full-detail Free-play route at fixed clock in garden_a1/a2/a3, yielding-memory storage. Minute memory is sampled, modes/height/steps observed each Heartbeat. Paused frames mean menu/title/rest states, not all visual stutters; no long-trace frame-time percentiles were recorded. No forced GC. Stats engine memory includes Studio overhead; gcinfo is one Lua VM. Descriptive trend only, not proof of absence of leaks, every map seam, natural lives, real storage or physical-phone stability.

Requested 1800s; completed 1800.016s wall / 1800.017s simulation.
Frames 102888; turns 44; modes {'attached': 102888}.
Loading 0; paused 0; findings 0; focus losses 0.
Minimum Y -84.29001; maximum frame step 0.37498studs. All nine camera rows65: True.

| Minutes | Lua min/median/max KB | Engine min/median/max MB | Instance min/max |
|---|---:|---:|---:|
| 0-5 | 37207/40565/47834 | 340.1/582.2/749.0 | 58910/59168 |
| 5-10 | 31744/45201/52565 | 388.7/389.0/390.7 | 58654/58911 |
| 10-15 | 34604/40565/46523 | 386.5/388.9/391.9 | 58654/59158 |
| 15-20 | 35999/36259/47063 | 385.9/390.4/391.8 | 58910/59158 |
| 20-25 | 31692/35902/44593 | 385.4/385.9/386.8 | 58882/59158 |
| 25-30 | 32073/41282/46504 | 382.1/394.3/396.7 | 58882/58907 |

Review notes: No mode/pause/loading/focus/finding flags in this bounded route. This is not a universal stability verdict.
