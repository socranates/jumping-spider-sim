# Native scene performance

same route, normal camera, noon, 7s settle, 5s sample, no concurrent local regression/compiler jobs. observational before/after, warmup and system variance; not a phone benchmark or proof of causal FPS gain.

Times in milliseconds. Values are mean / p95 / worst. Lower is better.

| Detail | Scene | Before | After |
|---|---|---:|---:|
| full | sill | 32.96 / 39.05 / 43.54 | 21.31 / 32.60 / 37.65 |
| full | garden_b2 | 24.47 / 31.51 / 257.05 | 17.43 / 21.25 / 27.96 |
| full | meadow_a3 | 22.78 / 28.10 / 69.22 | 18.93 / 23.65 / 39.75 |
| full | deck_n2 | 19.55 / 27.02 / 63.67 | 19.43 / 28.17 / 33.20 |
| full | hut_doorway | 19.97 / 29.68 / 47.32 | 22.38 / 30.25 / 41.79 |
| low | sill | 19.25 / 24.78 / 36.83 | 24.20 / 33.14 / 47.21 |
| low | garden_b2 | 16.73 / 19.07 / 29.44 | 16.78 / 18.33 / 56.82 |
| low | meadow_a3 | 18.33 / 23.54 / 64.43 | 18.14 / 23.67 / 30.02 |
| low | deck_n2 | 17.07 / 20.62 / 67.24 | 16.67 / 18.56 / 26.61 |
| low | hut_doorway | 16.88 / 20.76 / 26.60 | 17.31 / 22.09 / 34.94 |

The pond bank is deck_n2. The initial pond_a2 underwater view is excluded.
Do not attribute the whole observational difference to the distant-cat cache.
Its separate paired comparison measures the allocation tradeoff without claiming a stable FPS improvement.
