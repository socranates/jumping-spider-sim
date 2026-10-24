# Full-detail frame observations

Two unpublished native Studio models use the exact224 production Sources from
`bd67582b5d53473f067244fc1e2e1f94adde173b`, plus one diagnostic playback module.
Normal Persistence is disabled; no storage or save implementation is measured.
Full detail and ordinary lighting remain enabled. The existing SilkPlayback
hook disables the cat; other creatures follow their normal diagnostic path.
This is consequently not a complete ordinary-game creature workload. The
diagnostic starts the existing FrameProfile and leaves the ordinary controller
running. Studio was activated for Play, with no other app input during samples.
This is a local laptop observation, not a device or published-server FPS claim.

| Sample | Duration | Frames | Render callback mean / worst | Largest whole frame | Frames >50ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Run1 Main home | 25s | 1497 | 4.862 /9.895ms | 46.740ms | 0 |
| Run2 startup | 12s | 464 | 8.332 /54.248ms | 1852.750ms | 7 |
| Run2 Main home | 25s | 1486 | 4.394 /13.552ms | 40.050ms | 0 |
| Run2 garden_a1 | 25s | 1486 | 4.821 /59.841ms | 74.033ms | 1 |

Both Main samples advanced simulation by25.017s without death or a loading hold.
The garden sample did too. Its one >50ms frame occurred70.7ms into the sample;
the look section reached45.092ms. That section includes streamed scenery/dew,
train and hut updates, so this does not yet identify a single method to change.
Steady Main's largest average section was the spider rig, about1.75–1.89ms.

Startup includes ordinary navigation preparation and the initial transition to
the menu; it is not entirely paused simulation. Navigation averaged6.944ms in
run2 and peaked17.051ms. The measured render callback does not explain the
1.85-second whole-frame gap: other scripts, rendering/physics, driver/asset work
and Studio scheduling remain outside this attribution. Do not label those gaps
fixed or attribute them to background throttling without stronger evidence.

Run1's diagnostic used the geographic zone `hut_garden` as a walkable region ID,
so it skipped its garden sample. Its receipt is deliberately **partial** despite
the old playback printing PASS. Run2 uses the actual `garden_a1` region and
requires all three samples. Both original outputs and model identities remain.

No performance code, scenery density, lighting, physics or creature behavior was
changed for these measurements, so no speedup is claimed. Normal-startup wiring
is being qualified separately under `../normal-startup`; its costs still need
measurement before a release performance conclusion.
