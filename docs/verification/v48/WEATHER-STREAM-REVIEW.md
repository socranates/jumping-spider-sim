# Natural front and streamed shelter — native Studio

Unpublished v48 evidence, 2026-10-21. This extends the point-in-time samples in `WEATHER-REVIEW.md` with an actual advancing front and stationary support changes.

The observer begins a new Free play life at (-310, -84.29, -155), waits for streaming, then sets day 1 at noon once. The normal life clock advances thereafter. Outdoor time runs at one third of the windowsill rate, so 0.8 game hours takes about three real minutes. The initial one-minute fixture was corrected for this rate; its incomplete records are not accepted results.

## Completed runs

| Detail | One-second samples | Initial/final rain | Largest sampled rain change | Largest cloud change |
| --- | ---: | --- | ---: | ---: |
| Full | 180 | 0.000058 / 0.85 | 0.008030 | 0.004449 |
| Low | 180 | 0.000049 / 0.85 | 0.007952 | 0.004406 |

Both complete the gradual front with the spider alive and attached. A temporary invisible queryable roof is then added eight centimetres over the stationary spider to imitate streamed shelter. After 1.3 seconds every rain probe reports its top, -76.0400 cm, rather than the ground at -84.6000 cm. No visible streak centre is below the shelter cutoff. Removing the roof and waiting another 1.3 seconds restores every probe to the ground. Observer displacement is zero. Close part counts remain 294/full and 136/low.

This tests native ray/cache interaction with a newly arriving support, not network streaming latency on every device. Native performance is not assessed here: the full CLI regression was running concurrently.

## Source provenance and wind

- Full front/roof run: production source `52f1c0353bd3bbcff6679861a277e903385a5510`, including the rain-cache repair. Exact installed diagnostic archived as `studio-weather-stream-before-wind.luau`.
- Low run: subsequent directional-grass production source, `LivingWorld.luau` SHA256 `6086B3227B2BC0A49110DEDD28C2B9081F8782D1F4B8761F87C7AEA8273FE37B`, using `studio-weather-stream-review.luau`.
- Low additionally checks **1,620 grass observations**: none leans against the sampled wind; largest root displacement is **0.00003738 cm**. Four-direction and calm-air CLI checks cover both tiers. Do not count the earlier full run as native evidence for the later grass change.
- Raw telemetry: `weather-stream-native.txt`. Normal camera views: `weather-stream-full-approach.jpg`, `weather-stream-full-complete.jpg`, `weather-stream-low-complete.jpg`. The full approach includes an emerging grub; the final views show the roaming dog. These remain local encounters, not proof of world-wide density.

`[CHET_WEATHER_STREAM_CLEAN]` confirms removal of temporary playback and the weather detail override. Studio is subsequently configured with `SelfTest=true` and `Detail=full` for the broader native test; those attributes must be cleared after that run and before release.

Natural front/streamed shelter review is complete for these local full/low cases. Broader travel/hunting, mound camera framing, native integrated results, uncontended performance and final-source regression remain open. No v48 publication claim.
