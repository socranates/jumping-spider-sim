# Verification checkpoint — not published

## Latest correction and helper interruption

Production commit is now **5938aac41371ca005f73e4c21e7089404496b9a6**, rebuilt evidence **542472fc2539e00f**. Final strict clean; compile **209/209**; rebuilt XML/source comparison **209/209**. `playable-source-comparison.json` records current archive and playable hashes.

The continuing predecessor full run (session **18183**) found **one preserve assertion**: low station decoration 153 exceeded the unchanged 150 cap. Fixed by making the three dark inset rug drawings full-detail-only; continuous physical rug, full appearance, new thermos and transparent window are retained. Final-source preserve rerun **1154 pass / 0 fail**, station debug **38/38**, minimal HUD **37/37**. Final frozen affected-client run is session **45753**, raw `C:\Users\natha\claude-xfer\v49-final-5938aac-affected.txt` (world_client still running). Preserve raw rerun is `v49-low-budget-recheck.txt`. Neither run should be restarted merely because output is buffered.

Native self-test on `1f81d7c` completed at **2026-10-21T23:56:09.613Z**, **271 pass / 0 fail / 0 skip**, 562 seconds. Saved complete latest-run marker stream in `native-selftest-final.txt`. The final change only affects low decoration; do not relabel this as a native run on `5938aac`.

After completion, the Windows helper timed out on Shift+F5, then two lightweight window-list retries; after kernel reset and successful window listing, activation/state capture timed out again. **Stop outcome and current attributes are unknown.** No further Windows inputs issued after recovery failed. Recover fresh state before cleanup/publication. Local self-test overrides may remain. Cloud Studio remains disconnected on v48 unless reverified. No v49 publication claim.

Remaining: terminal full regression and affected-client results, final low-native check and ordinary station performance, source/debug cleanup, correct-cloud-place source comparison, publication/Dashboard proof and bounded final package. Earlier sections below are historical checkpoints.

## Current final-source verification

Final production commit is **`1f81d7c`**, rebuilt evidence **`5818d38f61841238`**. Frozen archive: `C:\Users\natha\claude-xfer\v49-final-1f81d7c.zip`, SHA256 `b487ace3b6fc18b39fac0b1dc06beb28e5513c6f38404f2f5044df9b1ef811ee`. Immutable extraction: `v49-final-1f81d7c\roblox_port`; separate rebuilt copy: `v49-release-1f81d7c\roblox_port`.

Full current-source **56-suite** CLI run is live in unified exec session **18183**, with results in `C:\Users\natha\claude-xfer\v49-final-1f81d7c-results`. The old **19772** baseline run was deliberately stopped after the window/sight fixes and is terminal exit 1; it is not a full pass and must not be resumed or restarted.

Final strict analysis is clean, final compile **209/209**. Rebuilt playable XML matches all **209/209** source files exactly after newline normalization (`playable-source-comparison.json`); native Studio source length/checksums also match **209/209**, logged at 23:30:35Z. Current rebuilt playable SHA256: `5dc6f27428555f2c26d8b94ae2c0060192b5109416e2f355e7585a96b891c1bb`.

Current-source native full-tier traversal/wake/HUD diagnostic passed at 23:31:41Z and 23:34:59Z. Live mouse observed and photographed; it moved from `(124.6,-68.2,215)` to `(-76.0,-68.2,215)` over the ten-second sample, with sixteen parts. Floor props and transparent window reviewed in full and low. These are controlled Free Play diagnostics, not a Normal-mode completion claim or performance benchmark.

Native cover check initially used the ordinary floor height while the spider was on the one-cm rug, embedding its sight target in the rug. The corrected fixture **passed at 23:41:03Z**: zero notices through cover, one notice after removing it, zero swats, explicit `NATIVE_COVER_END`. No production change was made for the fixture error.

Final low-tier replay passed at **23:44:17Z**, followed by all three floor-fly groups activating through normal proximity and drawing **one fly each, 29 parts per fly**, at **23:44:20–26Z**, explicit `FLOOR_LIFE_END`. Actual low-tier fly screenshot saved. Temporary playback was removed and diagnostic overrides cleared at **23:46:23Z**; local Studio is now starting the full native self-test (`SelfTest=true`, `Detail=full`). Wait for its new `[SELFTEST] END`; do not stop a live run based on a quiet log. All other diagnostic attributes are nil.

Remaining: current-source full CLI terminal result; final low native pass after the seated-head fix; native self-test; ordinary station floor-hunt/route and performance observations; remove diagnostic source/Workspace overrides, verify source in correct cloud place, publish and verify Dashboard; synchronize receipt/package/GitHub. The old sections below are historical baseline details.

## New findings after the first freeze

The `60b1c47` archive/rebuilt copy below is now a **baseline**, not final source. Low-tier native review found the back-room glass opaque; the working branch now draws transparent panes at both tiers. A related AI defect was found: standing-head coordinates placed the seated cat's sight origin outside the window, and the recess was incorrectly outside its room. Both are corrected, with dedicated regression checks. Make a new final source freeze/rebuild after the remaining visual review; do not publish the old `dba164426fa79a2b` candidate.

Current focused station suite: **38 passed, 0 failed**; HUD: **37 passed, 0 failed**. Controlled paw-response benchmark (`cat-escape-benchmark.luau`): 31 starting distances, ordinary walking struck in 17, earned Run struck in 0. This proves improved response margin in that fixture, not universal safety or a full escape playthrough.

Low-tier native station diagnostic completed again at 23:25:07Z with zero detached route ticks, after transparent glass but before the seated-head correction. The low gear and corrected window screenshots are saved here. Native full/low final-source checks, mouse visual review, source fingerprint comparison and native self-test remain required. The review driver now exposes `_G.ChetStation` for local diagnostic commands and supports `ChetStationView:Fire("mouse")`.

Scratch `v49-source-audit.luau` currently targets the **old baseline** and must be regenerated from the new release XML before use. Do not use it as proof of the final source.

## Baseline run and files

Production source commit: `60b1c47e5e9c9d021d99b7721db9f70b035ff757`, pushed to `github/codex/v49-ranger-station`.

Frozen input: `C:\Users\natha\claude-xfer\v49-full-60b1c47.zip`, SHA256 `4cb5aea1603bc5d3b9ba5a4186949de1785dfe612584cee6def287ce27b5f57b`.

Complete CLI regression in progress: 56 suites, immutable extraction `C:\Users\natha\claude-xfer\v49-full-60b1c47\roblox_port`. Results and progress in `C:\Users\natha\claude-xfer\v49-full-60b1c47-results`. Wait for terminal `summary.json`; do not infer completion from quiet output. Unified exec session `19772` is running the wrapper. No full-suite completion is claimed here.

Separate rebuilt release copy: `C:\Users\natha\claude-xfer\v49-release-60b1c47\roblox_port`. Evidence ID `dba164426fa79a2b`. Do not edit the immutable regression extraction.

First native full-tier diagnostic completed at 2026-10-21T23:16:56Z in the local place (PlaceId/GameId 0): HUD dimensions/dot, real creep/walk wake discrimination, all three exit route legs, zero detached ticks. Log: `C:\Users\natha\AppData\Local\Roblox\logs\0.744.0.7441077_20261021T200511Z_Studio_9837B_last.log`, markers `[CHET_V49_*]`. This pass predates the last thermos drawing and cat obstacle additions; final-source native verification still required.

Studio local window 36441252 is stopped, connected by Rojo 34872 to the writable clone. It still contains the temporary `Client/SilkPlayback` and diagnostic Workspace attributes. Remove them before any publication. Cloud window 4131012 remains disconnected and on the previous v48 release. Do not publish the local PlaceId 0 file.

The diagnostic driver in this directory now uses noon for visual review and .8 hours for the sleeping-cat checks. This documentation-only driver adjustment does not change the frozen production input. Full and low visual review, final source comparison, native self-test, final strict/compile and publication are pending.
