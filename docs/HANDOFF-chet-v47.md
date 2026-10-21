# Chet handoff - combined v47, 2026-10-21

## Resume here

The release combines Claude's creature v46 (7c36d975ee7b14d175de89c40d95fd2090620ddb) with Chet's Run/L1 controls (6ba1a3809503ec7814d21781daa239123f0dacb3). Both had used the v46 label independently. The combined source is **6283a598fa1fcd3f3a286f4278763640811fa6d0**, **v47**, merge evidence **eb473b6da5edf1dc**. Test-label follow-ups produce final source **1447d6b74c9aa6b6b4725ad3bdaa6e30d972fd24**, final test evidence **97cdf8a2827b4734**; the playable place bytes did not change. Do not publish either earlier v46 instead.

Use the GitHub branch `claude/new-session-lqh973`, also mirrored on Chet's `codex/v47-creatures-controls`. `origin` in Chet's checkout is the read-only OneDrive clone; push only the `github` remote. The active project is `roblox_port`. OneDrive and the project mirror's `sources/` remain read only. Do not edit the frozen Godot game.

## Decisions from Nathan

- Keep the player's green chelicerae.
- L1/LB **held** creeps; on press, it also toggles the existing contextual nearby-prey lock. Locked movement faces and strafes around the contact. No candidate means creep only. Lock persists after release, with existing loss/memory rules.
- L2/LT **held** runs. Shift on keyboard; new Run button on touch. Twice ground walking speed, with creep/lock taking priority. Gentle stick and Ctrl still creep.
- R2/RT is Focus; right mouse/touch Focus remain. Slow motion stays on T. No jump reach, reel/lower, save schema or stamina changes.
- Keep Claude's tan male rival and visual contest. Actual backing away instead of attacking has **not** been authorized or implemented. Do not confuse the drawn retreat with an outcome rule.

Decision numbering: Claude owns ROBLOX-127 (spiders), ROBLOX-128 (small lives). The control change is now **ROBLOX-129**, preserving all three entries.

## Merge and native-test corrections

- Rebuilt both places and BuildInfo from merged source; did not retain a conflicting generated place.
- Updated the Studio lock check from obsolete L2/PadLock behavior to L1's actual combined creep/lock action. This changed the test, not the controls.
- The intro check now calls `title:stop()` and starts a fresh forced intro before asserting that skipping before two seconds is refused. Previously it sometimes tested an intro already older than two seconds after loading. The refusal assertion and runtime TitleCard are unchanged.
- Older partial v45/v46 CLI runs and 244/245 native reports are historical evidence, not green release reports. See `chet/review-5.md` and `docs/verification/v47/` for final verification.

## Verification and release receipt

- **Published v47 / Roblox place version 61**, existing target only, at **2026-10-21T13:50:19Z**. Creator Dashboard confirmed 61 with Show published only. No Publish As.
- CLI: **48 suite results, 352,162 passed, 0 failed**, assembled transparently from the full frozen run's 45 unchanged suites plus three successful reruns after correcting four stale L2/LT Focus-label assertions to R2/RT. The original full run exited 1 and is preserved as-is. See `docs/verification/v47/cli-summary.json` and raw/corrected reports.
- Native foreground Studio: **245/245**, zero failures/skips, 526 s. CLI preserve route also 245/245. All **196 source modules compile**; type checker exit 0, no source diagnostics.
- Short native movement probe: Run 4.960 vs walk 2.531 studs/s; creep priority confirmed. Actual gamepad/phone feel remains a user playtest.
- Actual streamed garden milkweed plus Roblox-rendered creature fixtures photographed. Keep green; flag pale low-tier eyes, rectangular leaf walk surfaces, faint faded HUD text. Sill mean 32 fps vs focused garden 59 fps in Studio; do not call this a comparable clean live benchmark.
- Review fixtures removed, SelfTest nil, Rojo stopped before Publish. Source pushed to both branches. No main merge.
- Live-client launch verification remains incomplete: the existing Player automatically updated and opened home, but the in-app browser did not hand off the game session. No manual installer controls used. Do not describe fixture screenshots as published-client playtests.

The playable file's Git blob remains `a04e240347249bfff0aa8f118d01350b51a6f597`; SHA-256 `cd2e31a8729cfdb53eff2a06828a31696588c26139442f91500601771372f787`. Detailed findings and exact limits are in `chet/review-5.md`.

## Next work

Read `chet/review-5.md` for Roblox rendering findings and any remaining manual checks before extending the art. Keep the six approved mesh IDs from `docs/MESHES.md`; milkweed is the only mesh integrated by Claude so far. Add the next mesh one at a time, preserving walkable boxes and stable habitat/save IDs. The cat, wasp and crab spider were not part of the creature pass.

Check current GitHub history before coding, and coordinate before either agent changes fly, feeding, settings or menu code. Chet changed only settings **help text** for the revised shoulders and announced it beforehand. Do not roll back those labels to L2 lock.

Publish updates only to the existing private playtest **120119801868085**, universe **10771103250**. Never Publish As. Temporary Studio review fixtures and SelfTest attributes must be absent before publishing.
