# Startup clock investigation

2026-10-24. Ordinary game source remains evidence20f2200d79a9e448,273 sources.
Only unpublished, unbound diagnostic copies are instrumented. No upload,
online save, chosen life, transported spider, skipped intro or production edit.

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
