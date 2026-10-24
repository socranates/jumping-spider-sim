# Current native profiler observations

2026-10-24. Ordinary evidence105c83862d500f43,273 sources, source/test
commitc8054893. No ordinary source/export changes or publication in this pass.
Full raw HTML and original CSV/JSON exports remain local; initial-captures.json
binds their hashes. Retained summaries omit the full device/driver inventory.
Roblox's embedded viewer produced the JSON through its Export menu, served
only on127.0.0.1, without uploading the raw captures to an external viewer.

## Initial client capture

After pair2/after-full PASS, Ctrl+P paused the profiler; its header showed
Unpause and unchanged timing values. client-paused-summary.json contains128
frames: CPU median20.69ms, mean24.00ms, max147.86ms. Script_SpiderClient has a
129.53ms maximum scope; GPU Scene max23.98ms, Depth of Field6.13ms. The viewer
classifies all128 frames as jobs-heavy. These are viewer results, not a proven
cause inside a specific module or an estimate of savings from lighting changes.

This is an active garden endpoint after the benchmark, with profiler UI/export
interaction in the surrounding period. It is not a startup capture, paired
benchmark, exclusive CPU sum or mobile result. Runtime Sleep is not busy CPU,
nested timers overlap, and aliased LuaBridge/Qt labels repeat identical values.
Do not sum them or blame every aliased API. The selected timeline also exposes
render/GPU work; that alone does not establish GPU saturation.

## Server request remains unqualified

The Developer Console Server tab accepted60 frames/4 seconds and produced
log_F1893_microprofile_20261024-060133.html. However, the native profiler was
still paused. Its60-frame summary repeats the exact client SpiderClient,
render, GPU and sleep maxima and includes local Studio rendering/GPU data.
Treat it as an overlapping/stale-buffer request, not independent server timing.
The summary and server-captured.jpg retain what happened; server_qualification
is false. A path appearing in the console is not proof of a fresh isolated trace.

## Fresh fixture, unsuccessful follow-up capture

prepare.py derives one rainy-garden fixture from the guarded current builder,
with ordinary Free play entry and yielding memory-only saves. All276 staged
sources compile/type-check. Model SHA256:
ebbcefdbfe71effe411dfc877e36dc82c9472eece675308c25851361ac9de5ce.

fresh-full1/native.json records run1792841330889, PASS, both source guards,
zero CreatorErrors, six retained warnings, and unchanged273 original sources.
The fixture asserts cleanup before PASS. It completed3353 frames/60.02 action
seconds, alive/attached: mean17.90ms, p9523.99ms, max57.11ms, three frames>50ms.
Render-step mean/worst5.67/20.63ms. The profiler was briefly opened during this
sample, so these are diagnostic results, excluded from pair2's36 samples.

Measured lap costs, mean/worst ms:

| Part | Mean | Worst |
|---|---:|---:|
| Spider rig | 2.200 | 6.581 |
| Sound | 0.660 | 5.636 |
| Light | 0.480 | 7.191 |
| HUD | 0.403 | 3.708 |
| Camera | 0.333 | 3.074 |
| Wasp | 0.257 | 7.733 |

The new process's profiler was visibly unpaused (fresh-unpaused.jpg). After
PASS, console mouse actions failed while the pointer recentered; keyboard
shortcuts worked. Opening Roblox's normal menu enabled native menu actions,
but resuming reintroduced the problem. The fixture sets cam.mouse=false for a
fixed view; SpiderCamera.render then stops writing MouseBehavior, potentially
leaving its earlier LockCenter state. This explanation fits code and recovery;
it is not a qualified bug in ordinary player controls.

A proposed delayed pointer-release command was not visibly entered and was
never executed. No MICROPROFILE_POINTER_RELEASED record exists. The original
guard remained in the field and passed after stopping. No fresh server dump
was obtained. The editor was stopped/closed without saving; model hash unchanged.

Next prepare a new separately hashed fixture that explicitly releases inherited
mouse lock when disabling mouse-look. Verify capture interval/context with an
unpaused buffer, preferably a separate server process before attributing local
Studio totals to server work. Inspect SpiderRig with the lap evidence before
changing budgets. Preserve appearance, movement, controls, lighting and ecology.
The startup callback gap still needs its own early capture.

The [official MicroProfiler guide](https://create.roblox.com/docs/performance-optimization/microprofiler)
describes finite dumps and server capture. It does not certify freshness or
isolation of a particular dump; that must come from the run's own evidence.
