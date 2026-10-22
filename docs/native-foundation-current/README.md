# Current-source native foundation checks

Production source8e02b5ee5f443ab332cf7e70f5951a304cb89eea, branch codex/startup-world-readiness. No production files changed for these diagnostics. Unpublished.

Run1792679756682 passed **7 shadow cases/1513 assertions** and **8 save cases/45 assertions**, zero Creator errors. The pre-play guard verified217 script fingerprints and disabled production Persistence. Actual game bootstrap/controller ran with a Studio-only SilkPlayback diagnostic; this affects test-place behavior and is not an ordinary online-play proof.

Shadow cases use actual Roblox Instances: detached/replaced folders and children, repeated generations, separate bounded ignored/visible cleanup, moved-part ownership and excluded home. Save fixtures are captured from actual Normal, Free and Easy game roots, then validated and exercised against synthetic MemoryBackend sessions. They cover unread/changed foreign saves, unchanged observed consent, nil legacy life tokens, ambiguous own writes and equal-time revision/checksum conflicts. No online DataStore or live save was accessed. This does not prove live client rejoin, automatic network streaming, FPS improvement or the engine-memory category growth investigation resolved.

The first fixture run1792679629244 passed the shadow assertions but stopped before save cases: it incorrectly called fresh("easy",false,nil). The actual controller API represents Easy as fresh("main",true,nil), gated on completed Normal. The corrected diagnostic locally unlocks the existing fixture path and passes that signature. This is diagnostic state only; no shipped unlock/rule change. The failed output and original manifest are retained as fixture-v1-*; the successful v2 has a distinct place hash and all cases rerun. Historical diagnostics and receipts were not overwritten.

Prepared local place: C:/Users/natha/claude-xfer/Windowsill-observed-life-native-8e02-v2/Windowsill-observed-life-review.rbxlx. SHA256 f40dbf67dbbb442114a41122aa385a5f2e6a4b22e72d65d54b9325f743e51ee8. Do not publish. prepared-manifest.json, prepared-guard.luau, native-output.txt and receipt.json bind source, diagnostic and output. Creator-only collection excludes engine/account telemetry.

Build with build-native.py --source COMMIT --rojo PATH --out NEW_FOLDER; use the emitted guard in Studio edit mode before Play. collect.py LOG FOLDER checks the final guarded run. Full source gates remain in ../startup-world-readiness/receipt.json. Broader audit remains open in ../audit/CURRENT.md.

After terminal success the place was stopped, saved and closed. Studio serialization was archived locally and the guarded original restored with its manifest hash verified. verify.py independently checks all216 production scripts against Git and the worktree, the diagnostic hash, exact case totals and output hash.
