# Windows aesthetics acceptance — 2026-10-15

Final evidence **ab5e92132d90a1da**, Studio 0.743.0.7431133.

- **69/69 native Studio checks; 11/11 live-client checks**, zero failures.
- **7,801 CLI checks passed** on imported code; after the window-material correction, affected WORLD **230/230** and EYES **231/231** rerun successfully.
- Strict analysis clean after the correction. **100/100** Luau files compiled on import; changed native GraphicsSpec recompiled after the correction. No new script added.
- Both places rebuilt. Frozen Godot source/data/SPEC unchanged.

## Findings and fixes

1. Depth-of-field assertion used exact equality against 0.3. Native storage returns 0.30000001192092896. A 1e-6 tolerance fixes the engine test without changing the effect.
2. A real visual failure: the Glass window concealed translucent UV petals. A fixed camera comparison showed they appear when the pane is hidden and when replaced by transparent SmoothPlastic. The final window keeps its tint, transparency and reflectance, but no longer refracts. Glass droplets remain. WORLD/native assertions guard this material choice. See ROBLOX-23 and NOTES.md for reproduction.

Native screenshots show green side-eye vision, motion rings, faint scanning strips, narrower principal-eye Focus, and restoration of third-person framing/grade. The leaf tops match the collision tops in native tests; painted sill, planter, flowers and flies were inspected at play distance. Flower UV comparisons used an explicitly staged camera through the actual window; these are rendering checks, not proof of player navigation to that position. The graded UV pattern reads cyan, despite the authored violet color. The close-up screenshot makes the pattern's visibility clear.

## Three/six-fly timing

Eight seconds per population, third-person client, no screenshots during timing; no camera override or attribute edits during the timed run. Final JSON preserves the measurements.

| Flies | Fixed ticks | Candidates/tick | Rays/tick | Sensor p50/p95 us | Frame p50/p95 ms |
|---|---:|---:|---:|---:|---:|
| 3 | 480 | 0.500 | 1.667 | 20 / 339 | 16.96 / 20.05 |
| 6 | 481 | 1.842 | 7.526 | 231 / 526 | 16.91 / 18.15 |

Original Glass build's six-fly p95 was 23.10 ms (before/prey-cost.json); the intermediate assertion-only build measured 21.97 ms. The final sample is near the prior fly milestone's 18.15 ms, but these short sequential samples do not isolate the material's GPU cost or establish a causal improvement. **F01 remains open**: this is not a representative five-minute CPU/GPU profile and does not meet/prove the 16.7 ms p95 target. The low tier and separate eye-view frame time need device measurement before release.

## Not run / remaining

Physical controller/tablet, multi-finger input and low-end-device profiling were not run (hardware unavailable). Prolonged comfort testing, manual foot contact at every rounded leaf corner, and a native close-up evaluation of wing-film detail remain for playtesting. No live publishing or DataStore access. LIFE clock/day-night, NeedsModel and in-memory retreat checkpoints remain the next feature chunk.
