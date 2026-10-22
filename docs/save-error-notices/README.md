# Save failures in the minimal preserve HUD

Source `fab75695ba918eeebe793e6768a08cabe99a70f3`, evidence `ed58c07d5b24c8ae`, branch `codex/save-error-notices`. Unpublished.

The preserve's HUD erased every gameplay toast each frame, including saving failures. The candidate gives operational save warnings their own twelve-second display. It pauses and hides during modal screens, the intro, sleep, death and inspection; the existing menu keeps the persistent explanation. Repeated unchanged status does not restart the timer. Routine loading/saving/saved messages remain silent. Recovery is announced only after a saved acknowledgement, not merely when a retry starts. Gameplay messages cannot replace this notice. Legacy worlds retain their existing toast display without a duplicate save label.

No save format, backend, predator, movement, camera, feeding, settings or menu code changes. Hunger stays wordless; optional sound captions retain their separate path. This is a narrow operational-error exception to the minimal screen, not a return of routine status prose.

The same real-client failure probe fails on frozen source `3c8de801` with `broken=true visible=false` and passes on the candidate with `broken=true visible=true`. Both run exactly the same probe and current shim, with all production modules and the inline controller bound to each frozen Git source. The larger targeted run passes five suites / 389 checks. All 216 modules compile at `-O0`, strict analysis is clean, and five runner regressions pass.

Native Studio run `1792668342799` passed 16 assertions after a guard checked all 217 diagnostic-place scripts and disabled persistence. It exercises the actual callback-failure path, menu pause/resume, persistent menu explanation, normal/large desktop TextFits, notice replacement, independence from ordinary toasts and twelve-second expiry. Other transport transitions use the real client with scripted remotes in the CLI regression. This is not actual DataStore/rejoin, phone comfort or performance evidence. The native warning text was tested with TextFits; no claim of a manual visual review of every active message is made.

The first targeted run exposed a fixture omission: plain Luau has no Roblox `warn`. Its raw failed run is preserved in `targeted-initial.txt`. The fixture now provides and counts the expected diagnostic explicitly; the final targeted run exits zero. This was not a reproduced game-engine defect.

Full Windows execution is running in exec session **44707**, writing `windows-full.txt` and, only after exit, `windows-full-process.json`. Linux CI **39770144327** is separately running for the exact source above. These identifiers are historical start metadata; re-poll the same live handles/run before deciding status. An observer timeout does not justify restarting a suite. `fetch-ci.py` retains the actual completed Linux logs. `verify.py --require-full` must pass before considering these gates complete; earlier 443,469-check results do not cover this source. The new default is 64 suites / 443,522 expected checks.

Native diagnostic location: `C:\Users\natha\claude-xfer\Windowsill-save-notice-native-v1\Windowsill-save-notice-review.rbxlx`, SHA-256 `cce913a438d2977b0431ab5b73031700b23af96480ec2ebd456b74fc8f97a1a4`. It must never be published. Play was stopped after DONE; the review place remains open in Studio. Before closing/saving, preserve original bytes, archive Studio's serialization if necessary, then restore and verify the original package. No online save was used.

The prior full memory run is complete with an **investigate-growth** result. Read `docs/memory-trace/RESULTS-v1b.md`; neither this correctness fix nor green CI resolves its growing native allocation categories. The broader foundation goal remains active.
