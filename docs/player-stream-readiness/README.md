# Player collision disappearance: reproduced gap

Source `257e1a43ae00076a6e59f284c0f2ca0ff09f72e9` passes both ordinary full production suites, 76/468,859/0. This additional condition is not covered by that pass.

`run-probe.py baseline-1` bundles the existing actual SpiderClient box-world fixture and inserts `probe.luau` before its cleanup. It begins Free play, places the spider attached to the already-complete bed floor, removes that region's actual collision folder, sets the shim streaming flag, and runs 60 frames. It restores the removed folder even on failure.

The negative result is retained in `baseline-1-output.txt` and `baseline-1-receipt.json`:

- Position changes from `(11, -89.69, -50)` to `(11, -89.835833, -50)`, 0.145833 studs downward.
- Motor state changes from attached to air.
- Life elapsed time and `NeedsModel.elapsedS` each advance one second.
- The new assertion fails because the player was not held when known-region collision disappeared.

This fixture uses Free play to avoid unrelated danger, so it proves advancement of the needs clock, not hunger-energy loss or death. It is the real client code running under the CLI box-world shim, not native Roblox streaming pressure or a reproduction of a particular published-game fall. The existing warning-only `WorldClient.update` and the absence of a player collision gate explain the observed path. Both source and assembled-bundle/output hashes are retained.

The initial Python invocation stopped before launching Luau due to an invalid encoding alias; it was corrected to `utf-8-sig`. Baseline1 is the actual terminal Luau run, former exec40452, with the expected failure.

Next add a live player collision gate, preserving position, velocity, state and simulation clocks while known geometry is absent, then resume when it returns. Cover full removal, partial return, second removal after a prior ready result, fixed ticks and prospective airborne seam crossing. Keep normal off-map jumps/falls and intentionally flat legacy fixtures working. Gate on collision, not optional decorations; avoid caching a prior ready result as current authority. Prove it with actual-client checks and a native current-source probe before claiming the user-facing issue fixed.
