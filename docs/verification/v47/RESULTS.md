# v47 verification receipt

Published as **Roblox place version 61**, place **120119801868085**, universe **10771103250**, **2026-10-21T13:50:19Z**. Dashboard's published-only filter confirms it. Source **1447d6b74c9aa6b6b4725ad3bdaa6e30d972fd24**, evidence **97cdf8a2827b4734**.

- `cli-summary.json`: **352,162 passed / 0 failed**, 48 suite results. Full original `6283a59` run completed all 48 suites and exited 1 for four stale button-label assertions (SUMMARY 1, EYES 1, NOTEBOOK 2). `controller-labels-corrected.txt` and `notebook-corrected.txt` replace those three suite results. The 45 other suites and all runtime code are unchanged. This is not a claim that the original full process exited 0.
- `full-cli-original.txt`: unmodified full report, including CLI preserve 245/245 and BODIES 908/0.
- `windows-studio.txt`: actual foreground engine run **245/245**, no skips, 526 s.
- `compile.txt`: **196 modules / 0 failures**. `types.txt`: exit **0**, no source diagnostics; watcher-registration warning is informational.
- `native-review-probes.txt`: actual movement speed, streamed milkweed metadata, camera-view frame sample and cleanup markers.
- `playable-identity.json`: generated playable SHA-256 and absence of the temporary playback module. Final test corrections changed only test expectations/BuildInfo/test place, not the playable bytes.
- `images/`: milkweed is streamed scenery; creature close-ups are temporary fixtures using real Roblox renderers. `published-version-61.png` is the Dashboard receipt. These are not live-client encounter screenshots.
- `studio-review-playback.luau`: temporary diagnostic driver for reproducing the camera/fixtures. It is evidence tooling, not part of either published project. In Studio only, insert as Client/SilkPlayback marked ChetTemporaryReview=true with SelfTest unset; stop and remove it before any publication. Its ChetReviewCommand BindableEvent accepts the fixture names in the file.
- `release-receipt.json`: machine-readable release details and limits.

Review: `chet/review-5.md`. Handoff: `docs/HANDOFF-chet-v47.md`.

## Limits

Actual controller/phone feel, continuous motion at ordinary play distance and published-client performance remain manual checks. The existing Player automatically updated and reached its signed-in home screen, but the in-app browser did not hand off the game session. No live session verified; no manual installer controls used. Studio's local sill sample was 32 fps; focused milkweed garden 59 fps. Do not infer regression or causal improvements from these short, differently framed samples.

Historical `docs/verification/v46/` reports contain earlier 244/245 native failures (obsolete L2 check, then aged-intro setup) and targeted checks. They are not final release passes.
