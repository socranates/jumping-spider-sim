# Native isolated rig trial 1

Run `1792662958290`, engine `0.744.0.7441077`, viewport 1105 x 433, source `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5`. Native source guard verified all 176 scripts in corrected v1e packaging. All 16 cases completed; 17 chunked records were reconstructed with byte lengths and Adler checksums, raw CPU summaries recomputed, focus/viewport checks passed, and no CreatorErrors or runtime failure occurred. No screenshots were taken during timing. Old review windows and local test processes were closed first.

The first opening attempt hit a low-resource startup warning with four Studio instances. That attempt never entered Play. The old diagnostics were saved and closed, their original XML bytes restored after archiving Studio's serialization, and the final trial ran in a fresh Studio session. An unused startup-dialog process remained; this limits isolation. This is a laptop desktop experiment, not a controlled hardware benchmark or phone result.

| Case | Parts | Original mean ms | Cached mean ms | Instrumented mean ms | Cached reduction |
|---|---:|---:|---:|---:|---:|
| brachypelma_hamorii_full_walk | 146 | 1.185 | 1.119 | 1.170 | 5.5% |
| brachypelma_hamorii_low_walk | 84 | 0.484 | 0.419 | 0.454 | 13.5% |
| chromatopelma_cyaneopubescens_full_walk | 148 | 0.852 | 0.736 | 0.802 | 13.6% |
| chromatopelma_cyaneopubescens_low_walk | 84 | 0.436 | 0.368 | 0.413 | 15.6% |
| first_spider_full_walk | 707 | 2.578 | 2.481 | 2.286 | 3.7% |
| first_spider_low_walk | 265 | 1.167 | 1.109 | 1.135 | 5.0% |
| first_spider_male_full_walk | 711 | 2.538 | 2.654 | 2.293 | -4.6% |
| first_spider_male_low_walk | 270 | 1.030 | 0.967 | 0.986 | 6.1% |
| maratus_volans_male_full_walk | 119 | 0.684 | 0.619 | 0.670 | 9.6% |
| maratus_volans_male_low_walk | 80 | 0.439 | 0.375 | 0.441 | 14.6% |
| myrmarachne_formicaria_female_full_walk | 79 | 0.477 | 0.439 | 0.483 | 8.0% |
| myrmarachne_formicaria_female_low_walk | 69 | 0.514 | 0.447 | 0.481 | 13.0% |
| rival_spider_full_walk | 622 | 2.752 | 2.618 | 2.606 | 4.9% |
| rival_spider_low_walk | 211 | 0.930 | 0.906 | 0.934 | 2.6% |
| first_spider_full_stand | 707 | 2.624 | 2.608 | 2.330 | 0.6% |
| first_spider_full_growth_hang | 707 | 2.579 | 2.431 | 2.399 | 5.7% |

The player full-detail walk changed from 2.578 to 2.481 ms (0.097 ms / 3.7%) in this isolated run. One full-detail male case was slower; the instrumented variant was sometimes faster despite its probes. These mixed short samples do not establish a stable gain or whole-game improvement. Do not integrate the cache based on this one trial.

For the instrumented player walk, the inclusive batch/property-write slice averaged approximately 1.539 ms of a 2.286 ms update; legs averaged 0.441 ms, including nested segment/raycast measurements. Do not sum nested timings into their inclusive leg slice. Further profiling should separate property writes from the engine batch call before optimizing either.

Native cached/reference poses stayed within the predeclared tolerances in every case: maximum position error about 8.593e-5 studs, axis-vector error 8.520e-4, size error 6.557e-7. The largest position/axis differences occurred in the focused standing case; these are measured native floating-point differences, not exact equivalence. This run did not provide a frame-by-frame visual sign-off.

`native-v1e-events.txt` retains bounded raw events; `native-v1e.json` contains decoded samples and recomputed checks. Reproduce using `native.py --events ... --out ...`. The game still uses the original rig. No production source changed or diagnostic place was published. Repeated trials and matched whole-game visual/performance checks remain necessary before promotion.
