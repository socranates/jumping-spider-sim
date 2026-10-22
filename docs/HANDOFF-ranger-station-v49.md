# Ranger station v49 — release candidate

**Not published yet.** The corrected preserve self-test host is running; publication waits for its terminal result.

Branch: `codex/v49-ranger-station` at `https://github.com/socranates/jumping-spider-sim.git`. Final source/test commit **5e2964d27309c4db5220ed0705e76cb9506b7a02**, rebuilt evidence **35bf178f68118c38**. Gameplay code is identical to `5938aac`; the later commits correct test expectations for the authored exit and new gear.

## What the player gets

- A **150 × 6 px wordless hunger reserve** and the requested **2 × 2 px manual jump-aim dot** from the beginning. No extra aim assistance, trajectory colours or automatic hints; the dot hides in modal interfaces, sleep, death and inspection.
- A five-cm crack in the back-room sash, with a real exterior sill, rough log descent and supported ground meeting the existing stone path. Glass above the gap remains solid/queryable but is transparent at both tiers; exterior casing no longer blocks the window.
- A cat that wakes after sustained nearby walking, uses its next authored departure instead of teleporting off the sill, notices at 125 cm and recovers in 12 s. Creeping does not wake it. Opaque cover blocks notice and interrupts attacks. Its seated sight origin and the window recess room classification are corrected.
- Ranger-station field gear: radio/antenna/display, rounded thermos, boots, pack and first-aid case. Physical support remains on low graphics. New floor gear is included in cat stalking obstacles.
- Three seeded floor-housefly groups, one live fly per occupied cell at either tier, using normal prey senses, capture, feeding and offscreen replacement rules.
- An ambient mouse travelling supported routes through both rooms, pausing and scurrying near danger. Sixteen non-queryable presentation parts; no new food or damage mechanic.

Accepted movement/camera/long jumps, green chelicerae, resident rival and wasp, seven whole flies for first moult, ten for second, earned L2 Run after first, and L1 creep/contextual earned lock after second remain. The back exit is physically available before Run; difficulty comes from threats, not an invisible progression wall. Props and mouse remain simple stylized art.

## Verification and its limits

- Final strict analysis clean; **209/209** modules compile. Rebuilt playable XML equals **209/209** source files after newline normalization. Stopped cloud Studio has the same 209 fingerprints, correct place/universe, and no diagnostic overrides/playback.
- Full predecessor CLI run on `1f81d7c`: **56 suites terminated, 53 passed, 3 failed**. Raw logs and summary are retained in `docs/verification/v49/cli-predecessor/`. Do not call this a 56/56 run on final source.
- Failure 1: low decoration 153 exceeded the existing cap of 150. Making only the three dark inset rug drawings full-detail-only retains the physical rug and full appearance, plus the new thermos and transparent pane. Cap unchanged. Final preserve rerun **1154/1154**.
- Failure 2: self-test host expected 232 regions; the authored `room_exit` makes 233 (182 authored + 51 infill). Expected count corrected, explicit landing assertion added. Its final rerun is still live in session **70225**, frozen source `v49-final-5e2964d/roblox_port`; raw `C:\Users\natha\claude-xfer\v49-final-5e2964d-selftest-preserve.txt`. Do not restart on quiet/buffered output.
- Failure 3: old route fingerprints for four intentionally changed regions (desk, shelf, floor gear, back window). Only those rows refreshed from the independent legacy synchronous graph; other **47 archived fingerprints unchanged**, incremental builder unchanged. Rerun **11971/11971**. Capture driver/output provenance is documented in the reference file.
- Final affected-client reruns: station debug **38/38**, minimal HUD **37/37**, world client/low streaming **30/30**. Those run against `5938aac`, byte-identical gameplay code to final commit.
- Native Studio full self-test on `1f81d7c`: **271 pass / 0 fail / 0 skip**, 562 seconds, `native-selftest-final.txt`. Final production change affects only low decorative rug insets; do not relabel the native run as a new full run on final commit.
- Final-gameplay low native replay: real creep leaves cat asleep, walking wakes it; three window/log/ground legs have **zero detached ticks**, reaching path x537; mouse moves across the floor. Marker `[CHET_V49_FINAL_LOW]` identifies `5938aac` / `542472fc2539e00f`, whose gameplay source matches final. Full/low props and glass reviewed and photographed. All three floor fly groups previously activated through actual proximity and drew one fly each at low detail.
- Actual world-ray cover fixture: zero notices behind opaque cover, one after removing it, zero swats. Its initial diagnostic target was inside the rug; correcting target height fixed the fixture, with no production workaround.
- Controlled paw-response comparison, 31 starting distances: ordinary walk hit in **17**, earned Run in **0**. This proves response margin, not universal escape safety or a completed Normal-mode hunt/escape playthrough.
- Foreground local Studio, normal rules, default game camera and live actors, no concurrent CLI job: full-tier floor sample **511 frames / 10.003 s**, mean **19.58 ms (~51 fps)**, p95 **30.89 ms**, worst **96.31 ms**, **2** frames >50 ms. Player stayed alive/attached and walked ~5.04 cm in the preceding two-second input sample. Controlled starting placement and synthetic keyboard inputs are diagnostic conveniences; this is not device-wide performance certification. Earlier self-test performance numbers overlapped CLI work and are not release claims.

## Source, artifacts and publication

Final immutable archive: `C:\Users\natha\claude-xfer\v49-final-5e2964d.zip`, SHA256 **cdd1e5b6e56111fd0207a3d4d6c0b2e65ad245ad5aee2e0978f6a3c682fbc825**. Rebuilt release copy: `C:\Users\natha\claude-xfer\v49-release-5e2964d\roblox_port`. Playable SHA256 **66200ccf3b206653385d5254f17f1954bb65aaf38665f81d4d76d5c08309870c**. BuildInfo in the test place contains final evidence. Tracked repository `.rbxlx` files are older: use rebuilt outputs or run `tools/build.py`.

Cloud source fingerprints at **2026-10-22T00:17:49.493Z**: **209/209**, `5e2964d`, `35bf178f68118c38`. Correct cloud target **place 120119801868085 / universe 10771103250**; it is stopped and disconnected from Rojo. Its reported PlaceVersion 134 is the old loaded draft, not the latest published version. Verify the actual new published-only row after publishing; never infer a version number.

The Windows helper interruption was recovered. Local diagnostics were stopped and removed, Workspace Cat/Wasp/TestTarget/Detail/SelfTest overrides cleared; do not rely on the earlier unknown-stop state. Recheck stopped identity and cleanliness immediately before publication. Local review file has PlaceId/GameId 0 and must never be used for Publish As. Cloud window was 4131012, local 36441252; refresh actual window objects.

Remaining gates: terminal corrected self-test-host result; final publication guard, File → Publish to existing place, Creator Dashboard published-only proof; final receipt, acceptance audit, bounded Roblox-only release ZIP and GitHub synchronization. Keep the full predecessor failure history and qualified rerun lineage.

Push only remote **github**, never the read-only OneDrive **origin**. Do not merge main or edit Claude's branch without a new request. `sources/`, synced project material and OneDrive clone remain read-only; Godot is frozen. No subagents requested.

Cloud Claude can clone the GitHub branch. Local C: paths alone do not transfer files. The older `Windowsill-v49-review-542472fc2539e00f.zip` is a historical review checkpoint, not this final test-evidence package or a published release. Diagnostic files under `docs/verification/v49/` must never ship as `Client/SilkPlayback`.
