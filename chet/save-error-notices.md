# Save-warning handoff

Source `fab75695ba918eeebe793e6768a08cabe99a70f3`, evidence `ed58c07d5b24c8ae`, branch `codex/save-error-notices`. Unpublished. The branch includes the pinned-toolchain work and completed memory receipts.

Operational save failures now survive the preserve's minimal HUD. They get a separate twelve-second warning that waits through menus/intro/sleep/death/inspection, and cannot be erased by gameplay toasts. The menu keeps the persistent detail. Routine saving remains quiet; only an acknowledged saved status announces recovery. Legacy worlds keep their existing toast display. Hunger, movement, camera, feeding, settings, menu code and save data are unchanged.

The identical actual-client failure probe fails on frozen source `3c8de801` and passes on this candidate. Five targeted suites pass 389 checks, all 216 modules compile at `-O0`, strict types are clean, and five runner regressions pass. Source-guarded native Studio run `1792668342799` passes 16 assertions with persistence disabled, including the actual callback-failure path, menu timing, normal/large desktop TextFits and expiry. No online rejoin or phone-comfort result is claimed.

Linux CI **39770144327** is now complete and successful: 64 suites / 443,522 passing checks, checksum installation, compilation/types and five runner regressions. Its actual logs and source-bound receipt are retained. Full Windows is still live in exec session **44707**. Revalidate that exact handle before concluding state; do not restart after a polling timeout. Current pending/full flags are in `docs/save-error-notices/receipt.json`. Require `verify.py --require-full` before promotion. The earlier successful 443,469-check Windows runs cover the predecessor, not this changed source.

The diagnostic place remains open in stopped Studio, with original bytes still verified. It must never be published. Its path/hash and safe close procedure are in the README.

The 30-minute memory trace is complete, not pending: `docs/memory-trace/RESULTS-v1b.md`. It flagged growth in engine allocation categories while matched live instance counts and client Lua heap low points stayed stable. Do not call that leak-free, erase the flag, or infer a cause from the counter names alone. The next performance step is an isolated stationary/churn comparison and retention analysis. Broader legacy-save, session-ownership UX, deterministic AI activation and native/device audit work remains open.
