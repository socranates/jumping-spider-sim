# Native integrated run — interrupted, not accepted

Source under review: `0ca748ad9aae995a6ed19e47152eb1d0dc7c9cc2`. The native self-test began at 2026-10-21T20:00:29Z after removing the weather playback, with `SelfTest=true` and `Detail=full`. Setup reported no forced wasp, and TestTarget false.

Studio exited at approximately 20:01:57Z, before the self-test printed END. The process is absent from both the process list and computer-use app inventory. The log shows document/application shutdown; this is not evidence of a game-code crash. Do not resume waiting on this native run or count its partial checks as a passing gate.

Two failures were recorded before shutdown:

1. **world folders:** numerous distant folders absent at the initial observer pose. The check in `SelfTest.luau` currently requires every region's client folder simultaneously, before its later per-region streaming visits. The place enables streaming. Investigate that global assumption while retaining the complete per-region support/readiness checks; do not conceal a genuinely unbuilt region by weakening them.
2. **region hut_up_i:** after the visit, the client reported `hut_up_h`. Reproduce the actual pose, support normal and region ownership in native Studio before deciding whether this is a spawn boundary/precision issue or a controller/world defect. The preceding upper regions and station floors passed their local support/attachment checks.

Raw bounded run output: `native-0ca748a-interrupted.txt`. No native performance acceptance: the independent CLI regression ran concurrently. Reopening/rebuilding Studio must verify debug attributes before further tests and clear them before any publication; cleanup of this interrupted integrated session has not been confirmed.

An immutable candidate archive exists at `C:\Users\natha\claude-xfer\v48-full-0ca748a.zip`, SHA256 `935CB903925578D2B23661B1355E952B57A45C9258AEA161B8B95E225D491170`, extracted under `v48-full-0ca748a`. No full CLI job was started on that candidate. The older 7236420 full run remains live in exec session 38032 (last observed in `selftest_preserve.luau`); continue observing that handle. Resolve native findings before treating any snapshot as final release source.
