# Persistent saves — Windows review and acceptance

Claude bundle `871b816` starts from published main `2e36716`. The existing private playtest is now published as v19.

## Review fixes

- A new notebook page received while UpdateAsync was yielding was replaced by the earlier reply. Merge the reply with current memory; preserve the scheduler's dirty version.
- Flush released the progress lock before writing rests. Hold ownership through rest completion, then release; never start a second write after waiting past the flush deadline.
- Failed rest reads could be bypassed by a leave-time write. Rest writes now require a successful read. Damaged/invalid/newer rest values remain intact, including values first encountered during a retry or write. Readable backups are only used in memory.
- Retry reads could starve a live lock's heartbeat. Progress writes (which renew ownership) and due heartbeat now precede rest read retries.
- An unavailable DataStore service no longer uses a memory backend that misleadingly reports Saved. Permanent value write failures report session-only rather than clearing dirty state and claiming success.
- The report collector preserves individual skipped-check reasons. Removed the accidentally tracked Python bytecode cache and ignored future caches.

`regressions-before.txt`: 380 passed, **13 failed**, reproducing the first five defects. `regressions-after.txt`: 392 passed, one existing coalescing assertion failed because heartbeat preceded a due progress write. Scheduling priority was corrected. `baseline.txt` then completed all 24 suites with **46,648 passing checks**, including STATE 393; earlier unchanged suites ran before the review fixes, affected state suites ran after them. `state-final.txt` exposed an old assertion expecting Saved after a permanent error. Corrected `state-accepted.txt`: STATE 395/395; client 95 and offline 8 passed separately, giving 46,650 accepted checks before the final shutdown regression. The Luau test programs print counts but do not consistently exit nonzero on assertion failure: printed failures were inspected explicitly.

Strict source analysis: `strict-final.txt`, no diagnostics. **160** source/test Luau scripts compiled (`compile.txt`). Claude's handoff claimed 165; the actual recursive file count here is 160. `strict-accepted.txt` is clean and `compile-accepted.txt` confirms 160/160.

## Native checks

`offline-initial/`, evidence `9f8c40cff99e5e90`: engine **104/104**, one cloud-store group **not run** in the unsaved local place. The engine's JSON/checksum round trip passed. Live client **22/23**: only the existing hum-stop assertion failed after two Heartbeats; audio is updated on render, so this test now waits up to one second for the real stop callback, matching its onset check. Production audio is unchanged. This initial run is not final acceptance.

## Isolated cloud test

Created **Windowsill Save Tests**, separate from The Windowsill. Nathan turned Data Sharing off himself. Nathan enabled Studio API access only on this test experience (universe 10771634917, place 109879630247781). Test code forces `WindowsillTest_v1`; the live production namespace is never used by Studio. `cloud-accepted/`, evidence **461991282cc6007c**: **106/106 engine**, zero skipped, and **23/23 live-client**. Real DataStore restores progress and both rests, refuses the competing session, preserves floating-point checksums and classifies actual value errors.

The normal-project restart preserved the discovered notebook page but exposed a shutdown race: PlayerRemoving removed its entry before yielding in flush, so BindToClose could finish before the departing write released its lock. SaveService now counts departing flushes (including a departure during load), and shutdown waits for those too. A coroutine regression reproduces the overlap. Final build after this fix: **881f5ba653b169fe**; final targeted and native restart results follow below.

Rojo leaves unknown service children when changing projects. For the normal test only, an untracked temporary project sets ServerScriptService.$ignoreUnknownInstances=false to remove PortTests; otherwise each run uses isolated test keys and cannot prove normal rejoin.

## Publication

Published **v19** to existing universe **10771103250**, place **120119801868085**. Studio confirmed success at 2026-10-18 04:10:24 UTC; Creator Dashboard with Show published only independently confirms v19 (`published-v19.png`). Normal default.project.json was synced; no automated client runner was published. Audience/privacy unchanged.

Final build **881f5ba653b169fe**: targeted STATE **397/397**, STATE_CLIENT **95/95**, STATE_OFFLINE **8/8** in `state-shutdown.txt`; accepted total **46,652** including the unchanged 46,152 baseline. `strict-shutdown.txt` clean, `compile-shutdown.txt` **160/160**. The earlier native 106/106 + 23/23 run preceded only the shutdown repair and its two regression assertions; that repair was checked by an actual immediate normal Studio restart. `rejoin-menu.png` shows Saved without an other-session warning, and `rejoin-notebook.png` shows the discovered hunter page retained before starting a new life.

Manual normal rest-and-rejoin was not completed: the desktop helper sends instantaneous movement taps, so no sustained walk into the crack was demonstrated in that manual session. Real-store automated main/free rest roundtrip passed separately. Physical PlayStation/tablet rejoin, settings and complete-life play remain Nathan's checks. This is not a physical-device acceptance or controlled F01 run.

References checked: [Roblox data stores](https://create.roblox.com/docs/cloud-services/data-stores), [session locking](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing), and [cache behavior](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching). Current saves are validated client-originated solo progress, not server-authoritative gameplay or an anti-cheat boundary.
