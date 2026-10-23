# Animal/audio attribution results

Historical attribution on59146e1 is below. A later exact-output pond reuse candidate met the declared native thresholds and was adopted inccc0abb; see [the adoption gates](../pond-drawing-reuse/README.md) and [the complete trial history](POND-TRIAL.md). The current full platform checks are running. No whole-game FPS gain or publication is claimed.

Completed on current source59146e1, run1792712719676, all223 source fingerprints matched, zero CreatorErrors. No production presentation optimization adopted. The broad FrameProfile sound category also includes WaspBody, CrabBody, StationMouseBody, PondBodies, BirdBody and CatBody drawing; treating its roughly1ms sample as mixer cost would misattribute work.

The private driver wraps nine non-overlapping top-level drawing/audio methods, records inclusive callback CPU and positive heap-growth observations, and samples two playing Free-mode scenes with the normal advancing clock and all predator systems enabled. It rejects focus loss, viewport changes, missing geometry or detachment. These are instrumented attribution samples, not a matched before/after speedup or heap-leak proof. Instrumentation itself adds overhead.

Measured223-script package: C:/Users/natha/claude-xfer/Windowsill-animal-cost-59146e1/Windowsill-animal-cost-review.rbxlx, SHA2564f7a67685d2d73798fbfe45f5f0fb9991d69eac06b93b686e9cd31cbe8e957fc. Prepared-current manifest/guard preserve its inputs. The driver observes RenderStepped delta separately from the FrameProfile Lua callback total. Windows7806 was terminal before Play, and no heavy local CLI job ran during these samples. PlaceId0, production Persistence disabled. Window101584660 stopped/saved/closed/exited, original archive bytes restored, prior stopped rig94504044 retained. Never publish diagnostics.

Both samples lasted12 seconds at1105x433 viewport, foreground with unchanged viewport/focus, Free mode advancing and all predators enabled:

| Observation | Sill,711 frames | Garden,575 frames |
| --- | ---: | ---: |
| Render interval mean / worst,ms | 16.885 /31.871 | 20.877 /47.192 |
| Lua callback mean / worst,ms | 6.263 /12.405 | 6.619 /17.784 |
| WaspBody.draw,ms per frame | .330 | .368 |
| PondBodies.draw,ms per frame | .184 | .138 |
| CatBody.draw,ms per frame | .087 | .098 |
| Three Lua Soundscape handlers combined,ms per frame | .056 | .056 |
| PondBodies positive heap growth,KB per frame | 24.114 | 24.179 |

These are instrumented observations, not a paired speedup or published-client/phone benchmark. Positive heap growth excludes collections; it is not an allocation-rate measurement or proof of a retained leak. Lua audio handlers do not measure the engine mixer/decoder/spatial-audio work or prove audibility. The separate scenes are not an A/B comparison. Raw markers and structured results are in native-output.txt/native-receipt.json.

Next bounded prototype: reuse the invariant PondBodies.darnerParts(true) recipe and give each pond rig its own reusable moved/frames buffers. Source inspection shows darner geometry rebuilt identically on each draw and place allocating two arrays per call. Test exact full/low geometry and transitions (frog throat/tongue, darner turns, hide/reappear, repeated calls), ownership and no stale entries; compare native callbacks/heap observations on the same inputs before adoption. Prefer that exact-output reuse before reducing animation rates. Wasp drawing remains the largest measured member of this category. The spider rig is separately2.23/2.74ms per frame; its earlier mixed orientation-cache result does not justify integration.

Old prepared archive C:/Users/natha/claude-xfer/Windowsill-animal-cost-e51c546/Windowsill-animal-cost-review.rbxlx has no native result. Hair/fur shadows were already disabled in SpiderRig, so that is not a new optimization opportunity. The earlier rig orientation-cache experiment was mixed and remains unadopted.
