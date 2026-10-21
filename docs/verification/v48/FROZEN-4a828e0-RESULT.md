# Frozen baseline 4a828e0: completed, not a passing release gate

All 55 declared suites completed against the archived `4a828e0eaeed8834c62055f583a7772444b5f9c2` source: **52 suites passed; three failed**.

| Failed suite | Baseline result | Current-source repair |
| --- | --- | --- |
| `client_mating.luau` | 11 passed / 18 failed | MateDrive no longer applies rival-only courtship/scene sight suppression to its own partner; rerun 29/0. |
| `notebook.luau` | 1,496 passed / 3 failed | Fixtures now supply and expect the requested seven whole-fly equivalents; rerun 1,499/0. |
| `preserve.luau` | 1,147 passed / 1 failed | Low-detail dressing optimized to retain the original 150-record cap; rerun 1,148/0. |

The preserve self-test completes **270 pass / 0 fail / 0 skip**, with all seven outer checks passing. It takes 545.2 simulated seconds (32,682 frames), and the suite takes 465.16 seconds of wall time in this run. Its frame-time fields contain `?` because this is the CLI shim: it does not establish engine frame time, native shadows or memory measurements.

The JSON summary records every suite and exit code. Console output and the preserve self-test output accompany this receipt. The immutable snapshot lives at `C:\Users\natha\claude-xfer\v48-full-4a828e0\roblox_port`; archive SHA-256 is `7BB933B57FE67A29CE2EF77D479E726D0F8E2EBD3CC6CF008E600B54E521449E`.

The process is terminal and must not be treated as still running. Later colony changes, the regression repairs and flea changes are outside this snapshot. Their targeted reruns do not turn the baseline into a green release gate: freeze and run the complete current source after the remaining continuity repairs.
