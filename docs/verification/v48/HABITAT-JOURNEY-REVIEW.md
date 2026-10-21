# Longer normal-camera habitat walks — both tiers

Source **1ba2eb3**, unchanged production code. The temporary `studio-habitat-journey-review.luau` runs three separate routes at full and low detail. Each begins with initial placement and twelve seconds for streaming, then uses the ordinary input, motor and camera continuously. No additional floor, animal or invulnerability is created. Free play and the playback hook make this a controlled inspection, not an unassisted survival/hunting playthrough; playback also suppresses the cat through the client's existing test setup.

## Route results

Every sampled frame stays attached on all six walks. Both tiers finish all three four-second holds with no body-hidden or off-screen frames. The garden's step onto a fallen leaf briefly hides the body during movement: at most **0.132 seconds/full**, **0.118/low**. Grass can still visually cross the body; the rig's hidden flag does not measure every pixel occluded by non-queryable foliage. Neither movement nor camera is changed.

| Route | Start and end | Result |
| --- | --- | --- |
| Station can to doorway | `(116,-69.69,234)` → `(156.04,-69.69,234)` | Both tiers cross hut_floor_i into hut_doorway. A nearby flea is on screen during the approach; dust and can remain visible in the normal-camera full-detail capture. |
| Garden west shoulder | `(-182,-84.29,-190)` → `(-251.43,-83.04,-190)` | Both leave garden_b1, cross onto verge_-300_-216 and climb its real fallen leaf. Close grass and litter remain available while crossing the boundary. |
| Path west shoulder to bench | `(-108,-84.29,-450)` → z `-518.20/full`, `-520.03/low` | Both traverse the shoulder outside the stone path and enter pad_a2 gravel. Full-detail walking view records an emerging grub among the close grass. The supported gravel opens into the bench area. |

Different real-time endpoint distances reflect the timed input and frame scheduling; they are not a change in movement rules. None of these legs is a teleport between the route's endpoints. The three initial route placements remain disclosed.

The live close layer stays inside the existing **420/full, 150/low** part ceilings throughout. Low detail visibly retains grass, litter and shelter landmarks, with fewer clumps than full. The raw screen-presence counts for fleas/grubs refer to their actual drawn rigs and camera projection. The last column only counts ambient rigs in `Workspace.Bugs`; it does **not** count catchable flies rendered in `Workspace.Flies`, nor establish visual line of sight or hunt availability. Dog/ant-cycle acceptance is in the earlier dedicated reviews, not inferred from this walk's counters.

## Evidence and cleanup

- Raw bounded telemetry: `habitat-journey-native.txt` — all READY, VIEW, LEG, DONE and cleanup rows for both tiers. No FAIL marker.
- Normal-camera captures: `journey-full-station-flea.jpg`, `journey-full-path-grub.jpg`, `journey-low-garden-start.jpg`, `journey-low-path-shoulder.jpg`.
- The final current-source native integration is separately **270/0/0** in the existing cloud place; see `NATIVE-FINAL-1ba2eb3.md`. It covers every region's streamed physical support and the longer window/ceiling/bench/boardwalk connections.
- This journey runs in the **local review file**, PlaceId/GameId **0**, not a published client. CPU-heavy CLI work overlaps it, so no uncontended frame-rate claim is made.
- After both DONE markers and Stop, `[CHET_HABITAT_JOURNEY_CLEAN]` at **2026-10-21T21:09:49.548Z** verifies no SilkPlayback and no SelfTest/Detail/TestTarget/Wasp overrides. Log: `0.744.0.7441077_20261021T200511Z_Studio_9837B_last.log`. Both native jobs are terminal/stopped.

These routes strengthen ordinary visual/travel acceptance for the interior litter and outdoor shoulders. They do not demonstrate that every possible route is obstruction-free or that an unassisted player will notice every occasional animal. Final frozen CLI completion, publication confirmation and delivery remain open.
