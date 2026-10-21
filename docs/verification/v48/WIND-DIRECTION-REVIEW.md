# Rooted grass follows the weather

The close grass previously swayed around two fixed axes, regardless of the weather's world wind vector. It could lean opposite the wind or continue on the same axis when the weather changed direction.

Grass now leans downwind around its existing planted root, with a phase-varying bend of at most 0.1 radians. Gusts change the amount of bend while preserving the direction. Calm air and Reduced Motion restore the upright base transform. This changes presentation only: no Instances, collision surfaces, save data, simulation rules or update frequency are added.

## Current-source checks

- The four-direction regression first fails eight cases across the two tiers. See `wind-direction-before.txt` (3,956 pass / eight fail).
- After the fix and an added calm-air case: **3,966 pass / zero fail** in the complete living-world suite. It covers both tiers, all four horizontal wind directions, planted roots, calm air and Reduced Motion. See `wind-direction-cli.txt`.
- Strict analysis has no diagnostics; **207/207** source modules compile. See `wind-direction-types.txt` and `wind-direction-compile.txt`.
- Reviewed production file SHA256: `6086B3227B2BC0A49110DEDD28C2B9081F8782D1F4B8761F87C7AEA8273FE37B` (`src/Client/LivingWorld.luau`).

Native directional-grass evidence is recorded separately in the subsequent weather-stream review. The earlier full-detail weather stream began on `52f1c03` and predates this wind change; do not count it as native directional-grass evidence. A final frozen full-source regression and native performance review remain required. No v48 publication is claimed.
