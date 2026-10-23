# Wasp pose reuse trial — private, not adopted

The previous exact-source native attribution measured WaspBody.draw as the largest individual method in the broad sound/drawing category (about 0.33–0.37 ms in those historical instrumented scenes). That does not establish the current cost or a whole-game speedup.

This candidate leaves all simulation and animation rates unchanged. Body/petiole geometry is initialized once per rig. Flying/holding legs are recomputed only on a pose-family transition; walking legs always step. Folded wings are reused while walking; flight wings and antennae still animate every draw. State is owned by each rig, with no shared mutable cached geometry. WaspLook is static authored configuration; live editing that data after rig construction is outside this cache contract.

The private runner compares the candidate against the current production renderer through repeated flight/holding/walking transitions, hidden/reappear states, direct pose calls, positions/headings, search intensity and interleaved independent rigs. It passes 110,742 geometry/appearance/ownership checks plus 16,884 existing wasp regressions. This is shim evidence, not native behavior or performance proof.

The prepared native scene uses both renderers on identical precomputed inputs: flying, holding, walking and alternating modes, with four pairs and alternating execution order. It checks exact native part transforms/appearance before measuring inclusive draw batches and positive heap growth. Batch CPU is a component observation, not FPS; positive heap growth excludes collections and is not an allocation-rate or leak measurement.

Before adoption: clean strict/compile checks; native geometry, unchanged viewport and no focus loss; no competing heavy CLI job during the native trial; at least 10% median component CPU reduction in flying and holding with all four pairs faster; no more than 5% median regression in walking or alternating modes. Preserve a failed or marginal trial rather than change these thresholds afterward. Re-run adopted production regressions and full platform gates after any adoption. Nothing here changes production or grants release readiness.
