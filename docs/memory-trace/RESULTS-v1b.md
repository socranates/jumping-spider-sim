# Thirty-minute native memory trace

Run `1792666028145` completed **1,800.080 seconds**, 121 interval/end samples, and 59 completed habitat visits (nine each at sill, desk and garden; eight each at meadow, pond, doorway and lamp). Source `3c8de801e5fab68598e1e5323e7f5e1c8151b0e6`; all 217 diagnostic-place scripts guarded; production persistence disabled. The complete record/checksum, source, habitat readiness, viewport, focus and simulation-activity gates pass. Simulation advanced 1,797.17 seconds. No focus loss or CreatorError was recorded. The trace is valid; its memory verdict is **investigate growth**.

## What grew

The predeclared matched comparison uses visits 3/4 versus each habitat's final two completed visits, taking medians of the observed within-visit lower envelopes. These are sparse sampled minima, not forced-GC readings or continuously observed true minima.

| Habitat | Total engine MB delta | Client Lua GC MiB delta | Instance-count delta | BaseParts tag MB delta |
| --- | ---: | ---: | ---: | ---: |
| Sill | -2.78 | -2.07 | -128 | +37.29 |
| Hut desk | -42.79 | +3.22 | 0 | +37.44 |
| Garden | +46.78 | +2.43 | 0 | +37.45 |
| Meadow | +38.75 | -0.70 | 0 | +29.88 |
| Pond | -32.36 | +4.52 | 0 | +29.91 |
| Hut doorway | **+111.14** | -0.80 | 0 | +29.91 |
| Lamp | +36.01 | +1.04 | -128 | +29.86 |

The doorway total crossed the predeclared 64 MB threshold. No matched client-GC or instance-count threshold was crossed, and regional population initialization had stopped expanding. These results must remain visible; do not relax thresholds retrospectively to call this green.

The category curves deserve more attention than the noisy total alone. Across successive doorway visits, BaseParts minima rose approximately **17.97 → 25.37 → 32.80 → 40.21 → 47.60 → 55.29 → 62.71 → 70.13 MB**. Instances-category allocation rose 102.59 → 108.17 MB and Signals 9.86 → 12.38 MB. The doorway's actual instance count returned to 58,893 on most visits; its drawn-look balance returned to 1,221 parts. Similar category slopes occur at the sill. This is a correlation with repeated creation/destruction, not proof of which allocator or retaining reference causes it.

At the final interval sample the look streamer reported 50,021 parts made / 48,521 destroyed, a 1,500-part balance. Its regional/live-set counts changed with the current habitat rather than increasing without bound. Ecology directors initialized five regions and remained there. Client Lua GC showed repeated rises/falls, while the engine LuaHeap tag stayed around its earlier range. Stable live counts and Lua low points do **not** rule out native allocation retention, caches or references to destroyed instances.

Total engine memory started at 871.46 MB, varied strongly thereafter, and finished at 391.59 MB. It is OS-reported and can exclude paged-out memory, so an endpoint decrease does not disprove the category growth or justify summing category counters into that total. See the [Stats API](https://create.roblox.com/docs/reference/engine/classes/Stats). A non-monotonic total also prevents attributing the doorway flag alone to a specific region leak.

## Boundaries and next experiment

This is desktop Studio at a fixed 1105 × 433 viewport, one Free/gentle newborn life, full detail, explicit placements and natural clocks. It is not walking, mature combat, physical-phone, standalone-client, real-save/rejoin or comparative FPS evidence. There was no forced GC or profiler toggling. Small documentation, Git/network and parser work continued on the host; no full CLI suite or screenshot/UI capture ran during the timed trace. External logs and Studio diagnostic machinery still have overhead. Category counters are not interchangeable with the client's `gcinfo()` heap; this trace does not attribute their growth among game code, Studio and engine caches. The unused small Studio startup process was disclosed in the origin metadata.

Next isolate **stationary versus repeated streamed-look churn** with the same native source, duration, memory counters and logging cadence, and inspect engine snapshots/retaining references. Keep asset loading and weather/time differences explicit. Determine whether category allocation plateaus, remains retained after quiet time, or tracks a specific destroyed-object reference. Do not integrate an unmeasured pool, strip lighting or reduce the dense habitat to make a graph smaller. Keep this original trace immutable and compare any fix against it.

`long-v1b-events.txt` is the bounded native log; `long-v1b.json` contains decoded records and byte hashes; `long-v1b-visits.csv` provides inspectable visit minima/counters. `verify.py` reconstructs the native receipt and still reports `growth_screen=investigate_growth`. The observer exited zero only because the requested trace completed; that is not a no-growth verdict. Studio Play was stopped after DONE and the original diagnostic file hash was verified. Nothing was published.
