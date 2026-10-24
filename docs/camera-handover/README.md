# Restore the gameplay lens after the title

2026-10-24. The four native performance runs revealed that the title's lens
survived into gameplay: recorded FOVs were52.89-53.07 degrees instead of the
configured65. SpiderCamera.configure only wrote Camera.FieldOfView when the
setting changed. TitleCard writes the same Camera every title/intro frame, so
an unchanged player setting never reclaimed it. This also affected Skip,
completed intros, Resume and Continue; four added assertions reproduced those
paths before the fix (red.txt,21 checks with4 failing).

configure now restores the selected lens when the actual Camera differs, even
when the setting is unchanged. It does not write an already-correct lens and
does not claim the eye view's lens from SpiderEyes. Title rendering still
follows configure and owns its cinematic lens while active. Camera position,
movement, sensitivity, jumps, default65 and lighting are unchanged.

targeted.txt: TITLE21 + SETTINGS1164 + EYES231 + CLIENT27 =1443 passes,
zero failures, terminal exit0. The settings regression also restores a custom80
without toggling it; existing eye-view/Focus tests pass. Normal/test exports
rebuilt successfully, evidence66a9319760fa7c29. Both contain273 game sources.
The isolated long-trace model compiled277/277 and strict analysis passed;
that includes all273 normal sources plus its diagnostic fixture additions.
See receipt.json for exact source/test/output/build hashes.

Native verification completed: frame run1792826576539 emitted all nine camera
rows at65 degrees, all nine workload ENDs and authoritative PASS. Both277-source
guards passed. native-trace30/native.json and native-output.txt retain the
original bounded events; trace30-summary.json/.md describe trace1792826863197.
It completed1800.016 wall seconds /1800.017 simulation seconds,102888 attached
frames and44 turns across garden_a1/a2/a3, with0 findings,0 loading/menu/title/rest
pause frames and0 recorded focus events. MinimumY-84.29001; max frame step.37498.
No universal world/support/device conclusion follows. The old
performance runs are preserved with their actual FOVs; their comparison is
explicitly conditions_matched=false. No post-fix FPS improvement is claimed.
No publication, main merge or production/save access occurred.

Linux CI40073784522 onfcb8e18e subsequently completed successfully for all
configured checks: compilation, strict analysis, all suites, exports and runner
regressions. github-ci.json retains job/step status. No exact Linux assertion
counts are inferred from those API outcomes. Current5597fcf6 changes only raw
test-log preservation; game/test/project inputs match the checked source.

## Completed native follow-up

C:/Users/natha/claude-xfer/Windowsill-matrix-after-full-lens-trace30-r2/Windowsill-matrix.rbxlx

Model SHA256:df95c94a37f67d3d114ca3f1a3f5e6dc0a330f65f8a6bfa11faf9c93e457d717.
The normal matrix is followed by1800 wall seconds of actual Left/Right input
between garden_a1 and garden_a3. It observes every Heartbeat's mode, step,
height, liveness, loading and pause state; minute rows record heap/engine
memory, instances, route and focus events. It does not teleport, force GC,
disable AI or access any real store. Nonattached/large-step/low-height findings
include predator context and require review; duration alone does not prove no
fall, no leak or complete audit coverage. The static receipt's earlier
native=false flag describes preparation; the later native collection records
execution. StudioPID26956 stopped and closed without saving editor state;
the model's SHA256 is unchanged. No session remains running.
The pause counter observes menu/title/rest states. Detailed frame-time
percentiles belong to the short matrix, not the subsequent long trace.

Collection with --require-methods succeeded, including complete long-trace and
source-guard requirements.0 CreatorErrors and8 retained CreatorWarnings (same
style/asset/fixture-transport categories as prior cohorts). Short workload means
16.69-20.45ms; one frame>50ms (hut night51.175ms). No before/after FPS claim.
Lua heap ended2054KB below its start. Five-minute windows show fluctuating
heap and bounded instance counts rather than a steadily rising floor; final
engine memory386.49MB includes Studio overhead. See every window in the summary,
not just endpoints. The long trace has no frame-time percentiles and is not a
whole-game or physical-phone leak-free verdict. A documentation search around
minute2 returned~1.6MB unexpectedly; retain that operator-load caveat. No UI
snapshots occurred during the timed windows; the final live HUD was observed
after PASS (minimal meter and0/7 meal counter, no day/hunger prose).
The first trace build stopped at strict analysis on a fixture-only singleton
type comparison. The direction switch was corrected; its failed stage is kept
at the path without-r2. That failed stage was not executed; r2 completed above.
Neither stage was published.
