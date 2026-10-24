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
still includes these tests. fix-checks/ records the completed separate current
Windows qualification. Subsequent guarded engine cohorts are recorded below.

### Current Windows qualification

fix-checks/receipt.json completes all four affected suites: world_client46/0,
world355/0, checkpoint594/0, client_smoke27/0; total1022/0. All273 game
sources compile, strict checking exits0 with only tool-registration notices,
five runner checks pass, and both source-exact enabled exports are produced.
Current ordinary evidence is105c83862d500f43. This is a targeted Windows
run; the independent full Linux CI and native cohorts are separate.

### First fixed-source ordinary startup

Run1792836499548 is retained in full-late1/, SHA256:
d8b5da9ec05b60fd6afa180a50ffe7ed38a041f98950ffce9ad0255c96517c37.
Stage:C:/Users/natha/claude-xfer/Windowsill-startup-clock-full-late1.
It was built before the source commit; its original-source hashes are the
four-module fix subsequently committed atc8054893, not unchanged052550ef
despite that preparation revision in the manifest. Native guards check all
276 actual staged sources rather than relying on that revision label.

Home collision is ready at0.373797s; construction ends at0.373990s and
client hooks at0.524820s. There is no Decor wait. Title/navigation/save is
ready at11.282828s, then ten seconds of ordinary title complete normally.
Both source guards pass, zero CreatorErrors, six retained warnings, no focus
loss, life or active save work. Editor18096 is stopped and closed without
saving temporary state; the original file hash is unchanged.

The engine still has2458.55ms and1236.70ms callback intervals before a
completed game render callback, now after the client hooks were installed.
The next615.74ms interval has only one completed game frame. The fix removes
the proven optional dependency but does not cure these pauses. Neither the
constructor reduction nor the varying end-to-end title timings establish a
general startup-speed percentage or steady gameplay FPS improvement.

Separate exercise-decor fixtures deliberately stream out/replace optional
visuals through the actual render binding while title holds the life. They
are functional engine checks, not performance measurements. full1 was never
played: a harmless embedded-directive warning and native float comparison
were corrected in preparation full2/low1 before execution.

### Completed native visual-binding qualification

| Cohort | Run | Restored original leaf pieces | Source guards | Script errors | Retained warnings |
|---|---|---:|---:|---:|---:|
| decor-full2 | 1792836687456 | 12 | 2 | 0 | 10 |
| decor-low1 | 1792836910420 | 6 | 2 | 0 | 6 |

Both fixtures complete ordinary startup, keep the life paused at title, then
remove/replace only optional Decor. The actual game render binding discovers
the missing root, late Pilea, leaf-tip descendants and sash parts. A saved
fall is maintained, an open window does not replay, the original transforms
are restored without drift, and the original closed window/ready collision
returns before completion. The original 12/6 leaf pieces also show the normal
full/low detail distinction was retained in these arrivals. This does not
qualify every optional low-tier effect under an arbitrarily delayed/replaced
root; the existing asynchronous WorldDetail arrival policy is unchanged.

Each fixture finishes with no life started, no focus loss, and zero active
save work/scopes. All 276 sources compile/type-check, native pre/post guards
pass and immutable file hashes match after closing both editors without
saving temporary state. PID 25456 and 16796 are no longer live. Full2 model:
4c501f0584964eb79c5703d24342a09955987dbb82eebda9d7c3931f0b01ea2b.
Low1 model:
eecee83a9eec5d1d960e8ae576084facec0a3a781f80b4d6de336b913b349ab4.
Warnings are the retained Studio CornerRadius style-cast warnings and
asset 203785492 type mismatch, including pre-Play occurrences. No warnings
are silently reclassified as script failures or erased.

### Completed source CI and handoff boundary

GitHub run 40084424435, job 120844312920, succeeds at exact source/test commit
c80548933395eed5f7ccdd227af70210d49cd03f on 2026-10-24T10:16:47Z. All 79
suites, compile, strict types, exports and runner checks pass. github-ci.json
retains primary API metadata; no Linux assertion count is inferred. The later
evidence/export commit contains no further game-source or test changes.
summarize.py checks matching 273 original-source hashes across all three
current native cohorts and retains qualification.json. All 269 game modules
outside the four changed modules match the deep2 baseline exactly after
newline normalization. Schemas, geometry, ecology and controls are preserved.

This candidate is pushed on codex/verified-integration and remains unpublished.
Private test 13 and production 140 retain their previous release evidence; the
earlier private-test authorization was fulfilled. Current standalone Player,
real-store rejoin, physical-phone, every natural life, whole-map clipping and
matched-view FPS proof are not inferred. The engine startup gaps remain open.
