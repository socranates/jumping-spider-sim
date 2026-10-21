# Regression repairs after the frozen 4a828e0 run

The 55-suite frozen run found a real mating-client bug, stale notebook fixtures and a low-detail decoration overrun. These repairs retain the requested progression and presentation rules; they do not change the tests' decoration limits.

## Mate's sight during courtship

The client shares its player snapshot between the rival and mate. `courting` and `scene` correctly make the rival keep away, but the mate's adapter handed those same flags to its reused rival drive. That drive then reported no sight of the player's spider, preventing the courtship meter from filling. A diagnostic of a stationary, facing player 1.5 cm from the mate showed an unobstructed ray, no wasp, no retreat, and `driveSees=false`.

`MateDrive` now keeps a reused private player snapshot and removes only these two rival-specific flags before updating its own drive. The caller's table remains intact. Retreat privacy, rest, wasp interruption and actual occlusion still suppress sight. The movement implementation and rival drive are unchanged.

The leg-integration fixture now includes the client's real courtship/scene context. A focused regression checks sight, preservation of the caller's flags and all four restrictions. The complete real-client mating suite now passes, including courtship, egg guarding, hatching, scenes and generations.

## Moult fixtures and low-detail cost

- The notebook's reference-garden fixture expected five meals for the first moult. It now expects seven and supplies the missing four meals after the initial three. The active preserve's wordless HUD is unchanged.
- The cans draw each closed base once, through their rolled aluminium end, instead of a second hidden base plate. Their label, stain and small scuff are full-detail only. The rims and hollow pull tabs remain on low. Each can now uses 29 full / 25 low decoration records.
- Low-detail anthill dressing retains its mound, entrance and one ground food fragment. Extra grains and food scatter remain at full detail. All three low-tier workers and their carried fragments remain. Combined hut/garden decoration fits the existing 150-record low-tier limit; the world renderer remains capped at 1,500/500.

## Current-source results

| Suite | Passed | Failed |
| --- | ---: | ---: |
| Mate model and leg integration | 725 | 0 |
| Real-client mating | 29 | 0 |
| Notebook | 1,499 | 0 |
| Living-world rendering and ecology | 3,840 | 0 |
| Preserve geometry, looks and budgets | 1,148 | 0 |

Strict analysis has no diagnostics; 207/207 source files compile. The last two low-tier boolean refinements were subsequently recompiled and included in the final living/preserve rerun. Raw before/after output, the filtered sight trace and source hashes accompany this review. Repeated per-object assertions contribute to check counts; these are shim tests, not native rendering or performance evidence.

The full 55-suite run still uses its immutable 4a828e0 snapshot and is active in the preserve self-test at this review point. It neither includes the later colony changes nor these repairs. Do not restart it merely because its output pauses. Its result is not a passing final release gate. Current-source frozen regression and the outstanding native play/performance reviews remain required; no v48 publication has occurred.
