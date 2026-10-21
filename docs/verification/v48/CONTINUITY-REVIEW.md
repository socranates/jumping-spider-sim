# Close habitat continuity review

Unpublished v48 working source, 2026-10-21. The floor-flea population now belongs to fixed world sites rather than the observer's current region. Ninety authored sites share the existing five/full or two/low rendered animals; no additional Instances or save fields are introduced. Valid nearby assignments survive doorway crossings. Missing floor support is retried after streaming, and unloading support releases its animal.

The close-detail rebuild key now uses the actual 12 cm cell width on both horizontal axes. The previous 24 cm key could leave the leading grass behind during an otherwise ordinary walk.

## Regression evidence

- Before the fix: 3,918 living-world checks pass, four fail (both tier seam cases, the low-tier can encounter and the leading grass).
- After: living world 3,936 pass / 0 fail; world client 30 pass / 0 fail. The cases also cover cold reconstruction, unique assignments, unload/reload and unsupported floors.
- Strict analysis has no diagnostics; all 207 source files compile. Raw files: `continuity-before.txt`, `continuity-cli.txt`, `continuity-types.txt`, `continuity-compile.txt`.

## Native Studio crossing

The driver in `studio-continuity-review.luau` uses a standard new life and the ordinary camera. It positions the spider at (140, -69.69, 238), waits for streaming, then backs across the actual floor/doorway seam to (148.293, -69.69, 238). It adds no animals or invulnerability. This isolates continuity rather than proving a full unassisted journey.

Both tiers retain `hut_floor_i_flea_5`, with an unchanged anchor at (128.860, -69.890, 238.588), while changing from `hut_floor_i` to `hut_doorway`. The animal is on screen in every sampled frame. The player remains attached and alive.

| Tier/sample | Frames | Mean frame ms | Worst frame ms | Close parts |
| --- | ---: | ---: | ---: | ---: |
| Full, backing | 195 | 17.05 | 34.57 | 338 |
| Full, arrived | 297 | 16.86 | 26.90 | 338 |
| Low, backing | 198 | 16.75 | 40.65 | 145 |
| Low, arrived | 300 | 16.72 | 46.67 | 145 |

These are local PC scene samples with CLI jobs finished, not whole-map or mobile performance acceptance. Screenshots: `continuity-full-doorway.jpg`, `continuity-low-doorway.jpg`. Raw telemetry: `continuity-native.txt`. Studio cleanup is confirmed by `[CHET_CONTINUITY_REVIEW_CLEAN]`: temporary playback removed and detail override cleared.

Weather transitions, broader ordinary traversal, the complete current-source regression and final native/release gates remain open. This review does not establish v48 publication.
