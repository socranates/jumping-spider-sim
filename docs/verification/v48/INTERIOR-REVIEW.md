# Indoor detail, v48 work in progress

The native can review initially read as a flat green box from the drinking end. The two existing discarded cans now have exposed aluminium lids, an eight-segment rolled edge and an open four-piece pull tab. The stepped climbable shell, real drinking aperture, support IDs and positions are unchanged. Each can uses thirty decoration records, within the existing allowance; rim and tab remain at low detail. This is still a faceted prop, not a newly uploaded curved mesh.

The floor review also found a continuity bug: walking toward dust beside the station doorway could erase the close-detail layer because `hut_doorway` was not classified as floor. It now shares the same world-anchored scatter as adjoining floor regions. Dust uses overlapping low translucent clumps and joined, mostly horizontal fibres in place of the tall straight spikes. Its instance cost remains seven parts per full-detail clump and three at low detail.

## Evidence

- Living-world checks: **3,748 passed / 0 failed**, including both cans' visible apertures, low-tier rim/tab retention, existing support identities, the two renderer budgets and floor/doorway scatter continuity at both tiers. The CLI shim represents colours as tables, so colour checks compare components.
- Strict analysis: no diagnostics; **206/206** source files compile. Raw output is included beside this review.
- Native Studio: close frontal, wider frontal and oblique can views inspected; the actual rectangular aperture remains open. Before/after images retain the ordinary camera rather than a separate asset renderer.
- Native V2 doorway review: at `(148,-69.69,226)` in `hut_doorway`, the living renderer now has 291 parts rather than the previous 183 with no close floor layer. Dust remains visible on both sides of the doorway; the subsequent approach pose is recorded in `interior-native.txt` and `interior-doorway-dust.jpg`.
- The initial station-floor diagnostic showed one rendered flea near the can; the doorway's seeded positions showed none. The attempted final flea close-up had no visible candidate. These are not proof that ordinary play reliably notices fleas. Flea appearance/encounter review remains open.
- Studio was stopped and the temporary `SilkPlayback` instance and detail override removed, confirmed by `[CHET_INTERIOR_REVIEW_CLEAN]` at 2026-10-21T18:36:38Z.

No frame-time claim is made from this prop inspection: compile work overlapped parts of the native run. The full frozen regression, broader wildlife/weather playtest, final performance gates and publication remain outstanding.
