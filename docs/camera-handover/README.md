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

Native verification of the corrected handover is still pending. The old
performance runs are preserved with their actual FOVs; their comparison is
explicitly conditions_matched=false. No post-fix FPS improvement is claimed.
No publication, main merge or production/save access occurred.

## Prepared native follow-up

C:/Users/natha/claude-xfer/Windowsill-matrix-after-full-lens-trace30-r2/Windowsill-matrix.rbxlx

Model SHA256:df95c94a37f67d3d114ca3f1a3f5e6dc0a330f65f8a6bfa11faf9c93e457d717.
The normal matrix is followed by1800 wall seconds of actual Left/Right input
between garden_a1 and garden_a3. It observes every Heartbeat's mode, step,
height, liveness, loading and pause state; minute rows record heap/engine
memory, instances, route and focus events. It does not teleport, force GC,
disable AI or access any real store. Nonattached/large-step/low-height findings
include predator context and require review; duration alone does not prove no
fall, no leak or complete audit coverage. This model has NOT run natively yet.

Use fresh foreground Studio, same maximized viewport; source guard before and
after Play, original MATRIX_FRAME_PASS, then collect.py --require-methods.
The collector requires the complete long trace when its manifest requests it.
Verify native camera rows now show the configured65 and review every trace
finding, pause, focus event and memory trend before drawing conclusions.
The first trace build stopped at strict analysis on a fixture-only singleton
type comparison. The direction switch was corrected; its failed stage is kept
at the path without-r2. Neither stage was published or executed.
