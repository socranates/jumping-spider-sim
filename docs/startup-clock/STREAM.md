# Native startup stream — 2026-10-24

The early startup interval is now retained in a real native MicroProfiler file,
instead of inferred solely from Heartbeat callbacks. This investigation changes
no ordinary game source. Current game evidence remains **032b5985ac17eeb2**,
source/test/export commit **dd212105**; its full 80-suite CI succeeds.

## Source and capture identity

`stream-full1/native.json` records run 1792844833876, ordinary title/readiness,
both 277-source guards, zero CreatorErrors and cleanup. No life starts, focus
losses are zero, and active save work/scopes finish at zero. The memory adapter
does not access a real store. All 273 original-source hashes match current game
sources. The four additional modules are the three existing startup diagnostics
and an unchanged official LibMP wrapper under Shared/Diagnostics.

The first staging attempt retained 277/277 compile success but failed strict
checking inside the generated third-party wrapper. The corrected builder's
relative glob excludes that wrapper from strict analysis: 276 game/diagnostic
sources pass strict; all 277 still compile. `sdk-strict-first.txt` retains the
failure. No game checking was weakened and ordinary CI checks all 273 sources.

The [official LibMP release](https://github.com/Roblox/libmp/releases) wrapper
digest matches the release API SHA256:
`236fea082f323facd08109f9fd6dab70350bd0cc69617e07cc194778415a0bb8`.
The [official API reference](https://github.com/Roblox/libmp/blob/23573b949ed027fdf8820f969bea525b96c357cc/docs/api-reference.md)
documents backend compatibility checks and experimental file streaming.
The native capability check reports accessible/compatible/ready, library and
data-format 65537. A failed capability check would have stopped this attempt.

The wrapper is loaded in **Edit before capture**, not by any game script.
The command requests 64 MiB profiler memory, enables capture and selects 256
rolling frames. File streaming starts before F5; it persists through Play and
stops after fixture PASS and stopping Play. This leaves extra Edit/Play
transition and post-PASS frames, which must not become gameplay FPS evidence.
The extra replicated SDK payload is another limitation of this diagnostic.

`capture.json` and `capture-output.txt` retain capability/start/stop events.
Stop reports Active true before stopping, 4884 recorded stream frames,
176359 KiB and 91684 ms. The finalized local file is 181119816 bytes:

`C:/Users/natha/AppData/Local/Roblox/logs/microprofile-20261024-072700-SillStart1.x.html`

SHA256 `800862de4768f5ca458cf39677a7bb4b873318196dd6dc9ab1e98db0a278abf1`.
It contains one Studio track and 20 segments. The raw trace stays local.
Studio PID 5220 exits; no editor changes are saved. Original staged model hash
still equals `e1cb3f9e98a5a41a7db04c383848f51c10cf265b7c944f8f97f57bd70356b6a2`.

## Game-clock observations

Home collision is ready at 0.4115 s; client hooks at 0.5738 s. The two long
callback intervals are 2260.77 and 1243.42 ms, with no game render callback yet.
The first early render callback is at 4.3155 s, late at 4.3248 s and PreRender
at 4.3266 s. Title/navigation/save readiness completes at 11.3410 s; the fixture
finishes at 21.4478 s after ten further seconds of ordinary title.

This preserves the previous dependency fix: optional Decor no longer blocks
home-collision readiness. It still does not establish a general load-time gain.

## What the native trace adds

`inspect-stream.py` reads the file through the verified official Python SDK and
isolated Wasmtime 38.0.0. `frame-index.json` indexes the first six segments/1536
frames. The UTC samples locate these in the recorded startup period. Native
frame boundaries and Heartbeat intervals are different measurements; do not
equate their durations or imply submillisecond alignment from UTC seconds.

`analyze-stream.py` inspects selected actual CPU scope exits, clips durations to
the frame, and retains stack underflow/overflow counts. Scope durations are
inclusive, can overlap/nest and include waits. They are never summed across
threads or presented as exclusive CPU. The targeted frames include:

| Native frame | Frame ms | Incomplete | Relevant retained scopes |
|---|---:|---|---|
|644|1246.49|false|Persistence369.72ms; Main206.72ms during server startup|
|649|533.27|false|GameLoad401.96ms, nested SpiderClient377.32ms|
|652|282.35|true|Parallel Studio LoadPlugin spans around150–164ms|
|653|2047.50|true|Plugin script315.71ms; LoadPlugin256.63ms; CoreScripts notification/settings work around239ms|
|654|1341.35|false|Write Marshalled724.23ms, nested Plugin script484.18ms; asset scripts255.01/190.85ms|
|655|527.82|false|Many worker Sleep scopes; retained Render Perform24.13ms|
|922|261.51|false|sessionTracking_ph2/HeapCategoryWalk260.90ms; concurrent render preparation around247ms|

These rows are evidence of substantial Studio/plugin work during the observed
startup period, not an exhaustive root-cause decomposition. Frames 652/653
are marked incomplete; selected frames have 15–40 underflowed exits. No stack
overflow steps were reported. Scopes crossing a frame without a captured exit
are not accounted for by this bounded closed-scope analysis. `--labels` found
no identifying labels on the long plugin scopes; no particular plugin is blamed
from those scopes alone.

The independent `studio-plugin-overlap.json` extracts actual Studio load-log
entries in the client-enter→first-render interval. Examples include Assistant
load spans 727 ms in PlayServer and 863 ms in PlayClient, Explorer 697/608 ms,
AttenuationCurveEditor 683/646 ms and several other built-in tools. These are
concurrent logged load spans, not additive exclusive CPU. The user Rojo plugin's
recorded 33.54 ms PlayServer load is also retained. No plugin was disabled.

## Consequence for the next fix

Do not remove creature detail, change lighting or rewrite navigation to explain
this entire pause. The ordinary game render callback had not started at the
large callback gaps, while the trace and Studio logs contain substantial editor
and built-in plugin startup work. That materially changes the next investigation:
separate Studio initialization from the actual standalone Player path before
changing game behavior. Existing private13 Player timing remains an older-source
cohort; it is not current-candidate performance proof. Its publication approval
was already fulfilled, and this stream grants no new release authority.

The current candidate remains unpublished. Dedicated server isolation, physical
phone/controller comfort, complete natural lives and broader world/content
checks remain in the foundation ledger. The startup issue is better localized,
not declared solved, and occasional gameplay hitches remain open.
