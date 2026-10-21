# Streaming-aware native test entry check

The interrupted native run on `0ca748a` failed its initial `world folders` assertion because distant regions were not retained on the streamed client. The test subsequently visits each region, waits for its full physical pieces, raycasts the spawn, checks stable attachment and verifies region ownership. The initial assertion was incorrectly requiring all those regions simultaneously before their visits.

The initial guard now requires the World root and current region folder when streaming is enabled. Nonstreamed worlds still require every folder immediately. All later per-region readiness, actual-support, attachment and ownership checks remain intact.

The real-client CLI self-test now starts with a distant `shrub_west_j` folder removed from the root. Its host restores that folder after the initial check, then requires its later full region visit to pass. Before repair the initial check fails and the integration suite reports three outer passes / two failures. After repair **all 39 inner checks pass, no skips; all five outer checks pass**, in 84.8 simulated seconds. Raw output: `selftest-stream-before.txt`, `selftest-stream-cli.txt`. These are shim results, not native streaming-latency or frame-time measurements.

Strict analysis is clean and the modified SelfTest source compiles. Raw files: `selftest-stream-types.txt`, `selftest-stream-compile.txt`.

## Upper-region investigation

The focused native reproduction on updated Studio 0.744 visits `hut_up_g`, `hut_up_h`, `hut_up_i` and `room_up_a`. Each resolves a +X support normal on the expected joist, remains attached, and reports the expected region both through WorldClient and direct map ownership. Specifically, the i spawn at (92.25, 143, 215) yields body centre (92.56, 143, 215), owned by `hut_up_i`. No death panel or ended life is present. Resident wasp is enabled, arriving during these short samples. This does not reproduce or explain the earlier full-sequence failure on Studio 0.743.

Exact driver and bounded telemetry: `studio-upper-region-review.luau`, `upper-region-native.txt`; ordinary camera capture: `upper-region-review.jpg`. Do not change movement/regions based on an unproven cause. Ownership failures now report actual pose/up, expected support, direct map ownership, death panel and life/session state to diagnose an interruption or true geometric error.

The focused driver and Wasp override were removed before starting a new integrated native sequence. That sequence is on the rebuilt **local** review file (`PlaceId=0`, `GameId=0`), with streaming enabled; it is not publication or an audio-permission check for the existing live experience. `SelfTest=true` and `Detail=full` are active until the sequence ends, and must be cleared afterward. Native integrated results remain pending.
