# Chet handoff: native save-adapter failure reporting

Runtime `dc1c4b8640014a5718b6dc17d31044aca070c6d7`, evidence `e50104232f063255`, branch `codex/save-adapter-errors`. Unpublished.

A12 is fixed in the adapter and verified against the isolated real Roblox test store: callback/codec failures now cancel inside UpdateAsync and report failure to SaveSession, retaining queued retirements and avoiding a false acknowledgement/Saved state. Ordinary cancellation and successful retries remain valid. The regression failed before the fix and passed afterward; 57 codec/backend checks and 572 state checks passed, strict clean, compile 216/216, runner regressions 5/5.

Read `docs/save-adapter-errors/README.md`, `online-store.json` and current receipts. The real-store gate passed with exact checkpoint/backup checks and no production-store access. Real player rejoin is still unverified. Linux passed 62 suites / 443,235 checks; the foreground native preserve self-test passed 274/0/0 with a matching source guard and no CreatorError/timeout. Windows exec 24276 also completed with exit 0 and 62 suites / 443,235 checks passed. `runs.json` gives their handles. Never publish the diagnostic review place.

Greedy merge feasibility was completed separately on `codex/greedy-merge` (80b396a), with no runtime changes: even the optimistic bound is below Nathan's 10% gate. The broader optimization goal continues beyond this save fix.
