# Recovery delay attribution, 2026-10-23

The dominant delay in these trials is before client adoption. The server trace strongly points to the application's request-admission policy. It does not support prioritizing payload compression or client entry work as the remedy for this case.

Both native runs passed70 client+10 server checks, retained every original archive, stored new Main/Free/Easy lives, exercised failure/exit and stale-message handling, and cleaned up all GetOptions objects (221/221 and213/213). Models are unpublished, unbound Studio, memory-backed, with real RemoteEvents and the engine codec. Protocol time is accelerated10x. Reported seconds below are real elapsed measurements **in that diagnostic**, not production-clock or online-save predictions.

| Measurement | Trial1:20Hz service | Trial2:Heartbeat service |
|---|---:|---:|
| Run |1792783020948|1792783457829|
| Main choice to applied adoption |41.812s|37.160s|
| Server send to new client callback, median |34.8ms|34.7ms|
| Server send to new client callback, maximum |188.6ms|46.8ms|
| Matched new incoming packets |372|349|
| Main checkpoint preparation / stored ACK |0.166s /4.350s|0.167s /1.070s|
| Free checkpoint preparation / stored ACK |0.217s /2.786s|0.184s /1.019s|
| Easy checkpoint preparation / stored ACK |0.184s /3.568s|0.184s /5.452s|

Trial1 spent41.661s in the client-selected phase before its entry arrived, then0.147s in client preparation. Its largest first-message canonical sample was40108 bytes; the sampled recovery-entry message was16359 bytes. These are logical JSON sizes, not wire bytes or maxima across every message. Representative client/server copies cost5.65/3.92ms total. The one deliberately replayed old grant is excluded from delivery timing. No Internet latency or throughput claim follows.

Trial2 adds detailed server observation as well as changing cadence. It is not a controlled production speedup comparison. Increasing cadence did not remove the long Main wait, and Easy's stored ACK took longer. Keep both results rather than selecting only favorable numbers.

The second run's aggregated server states provide the useful distinction:

| Server state across the trial | Elapsed interval coverage | Time inside measured service calls | Calls observing a full application budget |
|---|---:|---:|---:|
| Recovering, archive |19.029s|0.167s|1111/1142|
| Recovering, commit |24.285s|0.437s|1366/1457|
| New retirement, rest discovery |29.215s|0.319s|1705/1753|

Coverage includes time between step starts, not just execution. Calls can yield for the injected provider, so the second column is not CPU accounting. The rolling budget is observed without calling its pruning/mutating budgetOk method. A full budget is a concurrent observed condition, not a precise count of seconds blocked exclusively by that cause. Source inspection confirms that request-taking phases check this gate. During Main's critical path, the owner's request counter rose from13 at archive start to70 at awaitApplied; its client preparation remained short. These observations justify investigating admission/request amplification next.

The source's aggregate cap is10 starts per rolling minute across request types, with debt intentionally carried through owner replacement. Keep those semantics until a tested replacement exists. Roblox's current [official limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) distinguish per-type server/experience limits; its [remaining server budget API](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetRequestBudgetForRequestType) is relevant to live admission. This documentation does not authorize treating a memory backend as an online quota test.

Next implementation work:

1. Trace each read/update in the archive/commit/entry path by phase and purpose. Distinguish necessary verification from repeated discovery, maintain lease freshness, and remove a request only with an independent proof that the same safety fact remains current.
2. Design bounded per-type admission with shared server headroom and per-player fairness, retaining rolling debt across replacement, request caps, cancellation fences, fresh verification reads and immutable originals. Exercise zero-budget, changing-budget, provider-yield, lost-reply and multi-owner cases before changing the conservative default.
3. Provide an explicit frame-driven cooperative worker when installing optional recovery. Ordinary production Persistence currently polls once per second; it must not inherit a many-slice job without a driver designed for it. Faster stepping must remain independent of permission to start I/O.
4. Repeat attribution with the real clock and isolated test store/leave/rejoin after the policy is qualified. Review the separately observed whole-frame gaps as well: trial1 had1.542s during initialization and0.434s in an Easy playing phase. The measured application/entry/save-client update calls do not explain those gaps; no representative FPS or complete frame-budget claim is made.

`verify.py` recomputes retained samples and model/source bindings. `native-attempt{1,2}.json` and `.txt` are authoritative raw/parsed receipts; prepared receipts identify every Source. Original artifact directories are under `C:/Users/natha/claude-xfer/Windowsill-recovery-native-cost-bd67582-attempt{1,2}`. Separate editor copies preserve Studio state. Production/private adapter bytes are unchanged; current default Windows/Linux proofs remain78/468967/0 each. No main merge or publication; optimization and activation remain open.
