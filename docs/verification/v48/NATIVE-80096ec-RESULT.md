# Native integrated client — 270 pass, zero fail, zero skip

The updated Studio 0.744 run completed at 2026-10-21T20:20:43Z after 552 real seconds. All **270** checks pass. Raw output is `native-80096ec-selftest.txt`.

Production source matches `80096ec` (the native run began before that exact source was committed). The place is the Rojo-built local review file, `PlaceId=0`/`GameId=0`, with streaming enabled and full detail. No SilkPlayback or Wasp override was present. This is native functional evidence, not publication or confirmation of the live experience's audio permissions.

## Coverage

Every mapped region is visited, waited on for complete streamed physical pieces, raycast at its supported spawn and held for stable attachment/region ownership. That includes the added off-path verge ground. The initial streaming-aware world-folder check and the previously failing hut_up_i visit pass. Continuous movement also passes on the sill, through the hut's inside, out through the sash and down to the garden, through the back-room doorway, up walls/onto the ceiling, along the eaves, across the bench patch and through the mown path/boardwalk links. All fifteen ballooning landing sites support a spider.

The garden check draws gnats, aphids, a ladybird, leafhoppers, springtails and woodlice; the meadow draws its leafhopper and six ants. Other checks cover the resident rival/garden mate, cat, crab spiders, robin, crickets, water/pond animals, frog, nursery/window, notebook, rest/checkpoint and sound playback state. Their exact setup and assertions are in SelfTest; these scripted checks do not replace an ordinary unassisted playtest or prove hunt enjoyment.

Normal-camera progress views are retained in `native-integration-garden-progress.jpg`, `native-integration-interior-progress.jpg` and `native-integration-complete.jpg`. They show actual client rendering, not an offline preview.

## Frame samples and limits

No heavy CLI job was running during these late frame samples. They remain Studio/PC measurements, not a phone benchmark or guarantee of a constant frame rate.

| Full-detail sill sample | Frames | Mean ms | Worst ms |
| --- | ---: | ---: | ---: |
| Normal scene | 258 | 19.4 | 178.9 |
| Far preserve temporarily removed | 166 | 19.3 | 228.6 |
| Shadows temporarily disabled | 159 | 19.3 | 128.8 |

Normal client render-step mean/worst is 7.00/26.7 ms; whole-frame timing includes engine work. Removing the far view/shadows barely changes the mean in these samples. The long whole-frame spikes remain unattributed and are not concealed by the functional PASS. Later ordinary-walk samples must be considered alongside them; this is not a universal performance acceptance claim.

At the final scene, the client reports 1,488 look records held of 1,488 planned; the workspace census has 6,247 BaseParts, including 2,437 World parts and 231 LivingHabitat parts. The raw WorldDecor census is 1,506. TrainPass also parents its separately bounded train-car pool there (up to nine cars, three parts each at full detail), outside the scenery planner's record count. The whole folder census and planner count therefore measure different things. Reported engine memory/instance totals are Studio-context values, unsuitable as a client-device memory budget.

## Cleanup and remaining work

Stopped Studio cleared SelfTest/Detail and emitted `[CHET_NATIVE_80096EC_CLEAN]` before installing the separate continuous mound-walk driver. That later driver has its own cleanup requirement. The native integrated run is terminal; do not wait for another END.

The earlier interrupted 0ca748a run remains incomplete evidence; this completed run supersedes its integrated gate, without claiming the old upper-region mismatch's cause was identified. Final-source CLI regression, the continuous mound/camera review, release preparation, live-place confirmation and handoff remain open. No v48 publication claim.
