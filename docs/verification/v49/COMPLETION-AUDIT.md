# Ranger station acceptance — verification in progress

Production source: **5938aac**, rebuilt evidence **542472fc2539e00f**. Final strict clean, compile/source comparison **209/209**. Native predecessor self-test completed **271/0/0**. Final low-budget correction passes preserve **1154/0**, station **38/0**, HUD **37/0**. Full regression and affected-client jobs remain live. Windows helper recovery failed after the native test: stop outcome/debug cleanup are unknown. Publication, final low-native review and ordinary station performance remain unconfirmed. Latest details supersede table entries below; see `IN-PROGRESS.md`.

| Requested result | Current evidence | State |
| --- | --- | --- |
| Cat reacts to roaming | Real client: creeping leaves it asleep; sustained walking wakes it onto an authored departure route. Native `CREEP` / `WAKE` records. | Verified in isolated full/low playtests |
| Cat behaves fairly around station objects | Actual world-ray fixture: 0 notices behind opaque cover, 1 after its removal, 0 swats; seated sight origin/window-room regression. | Verified; broad native self-test pending |
| Cracked back-room window exit | Five-cm opening, exterior board/logs/ground to existing path; final-source full and low native motor traversal with 0 detached ticks. Transparent-pane and casing corrections observed. | Verified |
| More ranger-station objects | Radio, thermos, field pack, boots and first-aid case have physical support at both tiers. Full/low gear and floor-prop images. Cat obstacle bounds include the new floor gear. | Implemented and reviewed; simple faceted art |
| Slightly larger hunger meter without words | 150 × 6 px; 37 focused HUD checks; native HUD dimension/visibility records. | Verified |
| Very small starting jump aim dot | 2 × 2 px at screen centre; no added aim assistance or reach colours; hidden during sleep/death/modal interfaces. Focused HUD and native records. | Verified |
| A few random floor flies | Three seeded floor clusters, one live house fly per occupied cell at both tiers; supported perches and populated real directors pass focused station checks. All three activated through actual native proximity at low detail, one drawn fly and 29 parts each. | Verified |
| Difficult early escape; Run helps after first moult | Existing seven-whole-fly first moult and Run gate retained. Cat wake/notice pressure increased. Controlled paw-response benchmark: 17/31 walking hits versus 0/31 with earned Run. | Mechanical advantage verified; fixture is not a universal escape guarantee |
| Mouse running around | One real ambient actor, both-room authored floor route, seeded pauses and danger response. Native observed ten-second movement, sixteen non-queryable parts; screenshot saved. No food/damage interface. | Verified; simple stylized presentation |
| Focus on the station / preserve accepted mechanics | Production changes limited to the station, its necessary window landing, cat, mouse, floor prey and requested HUD additions. Existing movement/camera/jumps, 7/10 meals, L1 creep/earned lock and L2 Run preserved. | Source scope verified; full regression pending |
| Final release and handoff | Strict clean; 209/209 compile; rebuilt XML exact source comparison 209/209 and Studio source fingerprints 209/209. New 56-suite frozen run is live. | Self-test, performance review, cleanup, publication, receipt/package synchronization pending |

Initial failed cover diagnostic placed the spider inside the rug rather than on it. Correcting the diagnostic's height restored the expected sight result without changing production code. The superseded `60b1c47` regression was intentionally stopped after later window fixes; it is not counted as a completed suite.
