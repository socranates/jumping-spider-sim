# Startup clock investigation

2026-10-24. The first three observations use ordinary game evidence
20f2200d79a9e448,273 sources. A subsequent optional-Decor startup fix is being
qualified separately below. Only unpublished, unbound diagnostic copies are
instrumented. No new upload, online save, chosen life, transported spider,
skipped intro or production edit occurs in this investigation.

The old private13 measurements remain unchanged. review-historical.py and
historical-clock-bounds.json show that at least1447.88ms of the1562.70ms
first interval and1744.79ms of the1868.82ms interval preceded the probe's
born timestamp. This prevents assigning the entire raw interval to observed
game code. It does not prove that earlier game/engine loading did not stall.

## Initial current full-detail observation

Run1792834719053, original bounded output/manifest in full-initial/.
Model efcd124efe027db1f34ed4f216dc2b1b963a2aee84b7cbc3ce27cc7fa5117450,
local stage C:/Users/natha/claude-xfer/Windowsill-startup-clock-full-attempt2.
All276 sources compile and type-check; preparation attempt1 was never played
and had two harness lint warnings corrected before attempt2.

Both276-source native guards pass. The observer completes normally, keeps
ordinary title/menu and finishes its synthetic memory scope without starting
a life. It records separate raw Heartbeat dt and wall-clock callback intervals.
First callback:599.75ms raw,420.06ms observed since begin, at least179.69ms
of the raw interval before the probe. Client hooks ready at2.536s and title/
navigation/save ready at10.884s; ten further seconds of ordinary title follow.

There are real post-begin gaps:2120.37ms wall interval (2103.21ms raw), then
1103.95ms wall (1106.24ms raw), then726.85ms wall. WorldClient require/new
together spans1701.73ms; rig54.91ms, initial streamLooks58.44ms, HUD15.43ms,
initial animal bodies27.00ms. These are wall spans, not proof of exclusive
CPU work or a causal assignment of the engine frame gap to one function.
The next probe will split import/construction and profile render parts.

No heavy CLI or other Studio was running. The first post-F5 state request
used unsupported false/false flags and was refused; F5 was not retried.
A text-only re-observation followed. No viewport screenshot was taken during
measurement; one text-only UI observation still means the idle-window maxima
are not a controlled performance benchmark. The initial constructor/title
timeline is retained, not silently restarted or replaced.

No FPS gain, standalone startup fix, physical-phone result or natural-life
qualification follows. After-first distributions span changing startup and
title phases, so their mean is not steady gameplay FPS. The existing Studio
style/asset warnings remain in the raw bounded output.

## Detailed current observation

Run1792835122806 is retained in full-deep1/. Model SHA256:
721c4ee2381b291535bd5867a5d0098bbaded2e030071a2e8123d2ca086ee00a.
Stage:C:/Users/natha/claude-xfer/Windowsill-startup-clock-full-deep1.
This diagnostic also times the server Main phases, splits WorldClient import
from construction, and enables the existing per-render-part profiler. The
game's normal profiler remains off in ordinary exports.

The import takes20.88ms; home/region/bounds selection is below1ms. The
construction block covering essential home/decor arrival spans2394.95ms.
It does not yet identify the particular missing child or optional Decor wait.
The server's physical-world call spans105.48ms and has already completed
before client entry. The hidden-piece plan spans6.40ms. These measured spans
do not support blaming the entire client delay on module imports or slow
server box construction.

The two largest callback intervals are2561.51ms and1106.66ms, both with zero
completed game render callbacks. The next750.37ms interval contains one
profiled frame whose navigation part is8.40ms. This does not establish an
engine root cause, but prevents assigning the whole long interval to the
navigation/render callback. A later readiness frame has several10–13ms parts
(looks, shadows, rig), rather than one1s Lua part.

Client hooks ready at2.945s; title/navigation/save ready at11.300s. Capture
finishes at21.394s with cleanup and both276-source guards passing, zero
CreatorErrors, and retained warnings. No viewport or accessibility snapshots
occurred after the initial text-only F5 refresh until capture completion.
This is a separate, more instrumented cohort, not a speed comparison with
the initial run. Next locate the exact required-child/decor wait and sample
engine counters at those gaps before deciding whether a game fix is justified.

## Exact optional wait, before the fix

Run1792835588227 is retained in full-deep2/. Model SHA256:
e242bd6d43ef04bed4d63f3da73e53b774116bae9096d3f8a9731793ae449c6c.
Stage:C:/Users/natha/claude-xfer/Windowsill-startup-clock-full-deep2.
The missing essential cover_bark_west arrives in69.96ms. All home pieces
are ready at0.484511s; the next optional Decor wait lasts4777.26ms.
Client hooks are ready at5.540715s and title/navigation/save at12.042469s.
Capture finishes normally at22.130495s with959 callbacks, both guards,
zero CreatorErrors and no life/save work started. The editor is stopped,
closed without saving temporary state, and the model hash remains unchanged.

The2260.89ms and1595.43ms callback gaps occur while waiting for Decor and
before a completed game render callback. The next811.81ms gap is in that
same phase. Engine counters are sampled at gaps and retained, including
zero/stale-looking early timings; these are not sufficient to identify an
engine root cause. Removing the optional yield is justified as a startup
dependency fix, not automatically as a cure for engine frame gaps.

## Nonblocking optional-visual candidate

WorldClient still requires every essential home piece under the original
shared30-second deadline. Missing/wrong collision still aborts construction.
Optional Decor is discovered without yielding, initially and each world frame.
The physical hut sash is created immediately, as before. Its two visual sash
parts reconcile with the existing open/closed state as they arrive, without
replaying the ranger, changing progress, or replacing physical collision.

Breakaway binds late leaf-tip descendants to their current fall state. It
retains original visual transforms across refreshes, restores/prunes removed
parts, and does not change left/elapsed/outcome state. Only the small tip
subtree is scanned, at most four times per second; Decor-root changes bind
immediately. No background tasks or streaming listeners are retained. The
render callback performs this visual binding before the simulation ticks,
including while a menu holds time. Persistence schemas and record methods,
seeds, geometry, lighting, movement, camera and controls are unchanged.

red-tests.txt is the completed old-source world_client run with the new
startup contract:42 passed/1 failed, specifically the unwanted Decor wait.
late-decor-red.txt runs three new visual-state regressions against052550ef:
0 passed/3 failed. late-decor-green.txt records3 passed/0 failed on the fix.
check-late-decor.py documents that bounded selection; the ordinary full suite
still includes these tests. fix-checks/ records the separate current Windows
qualification as it completes. No current native result or speed gain is
claimed until the subsequent guarded cohort is collected.
