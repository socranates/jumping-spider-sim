# Cooperative save preparation, source 955d1eb

This is an unpublished foundation for reducing save/Continue stalls. The actual game still uses synchronous saving. Do not publish the existing release XML or BuildInfo as this source.

`SaveWork` provides a coroutine worker with a soft time budget, bounded duration/resume count, cancellation and private results transferred once. JSON copy/encoding/hash, object graph capture/decode and the full checkpoint validation boundary now cooperate only inside that worker. Ordinary callers, including server storage callbacks, remain synchronous. Live graph commit has no yield points.

The worker does not freeze or own inputs automatically. A caller must supply an owned stable record, or hold a coherent simulation boundary for live capture. It does not make side effects transactional: storage work must use a private staging store, and the controller must validate its current intent before an atomic pointer/graph commit. Cancellation, timeout or obsolete work must leave the old world/rest in place and must never produce Saved.

## Evidence

- Fourteen focused suites: **2,450 passed, zero failed**; 221/221 module compilation, clean strict analysis and five runner regressions. `verify.py` checks exact committed source and snapshot hashes, including all test inputs.
- Worker suite: 39 checks. Checkpoint suite: 555 checks. Exercises cycles, aliases, class metatables, byte/hash equality, corruption refusal, private staging, cancellation, unexpected yields, time/resume limits, interleaving and yielding across validation pcall boundaries.
- Actual Studio run **1792694836637**: **13 assertions**, zero Creator errors, one unrelated asset-type warning. All 222 scripts fingerprinted; PlaceId zero and production Persistence disabled. No online store or live RemoteEvent transport used.
- Native record: 1,501,296 canonical characters. Initializing 233 regions was attempted subject to existing readiness gates; materialized/resident region counts were not measured. This does not prove fully explored ecology coverage.

| Native preparation | Worker steps | Largest measured step | Total elapsed |
| --- | ---: | ---: | ---: |
| Copy, encode and hash | 327 | 13.983 ms | 5.573 s |
| Full validation | 247 | 34.029 ms | 4.161 s |
| Private local store | 755 | 81.467 ms | 12.914 s |

The requested budget was 2 ms, and it is soft. These results prove yields and correctness, not a hard frame budget or smooth gameplay. Native operations, uninstrumented helpers and GC can still stall. The initial Heartbeat gap includes synchronous fixture capture/encoding performed before the worker; it cannot be attributed solely to its steps. Studio displayed a Low System Resources warning. These are not typical FPS, a controlled speedup comparison, phone performance or a resolved save-stall claim.

Studio playback was stopped, the place saved and closed, and Studio exited. Its saved diagnostic is archived separately and the original guarded place bytes restored; see `close.json`. Never publish this diagnostic.

## Full regression status and next work

The preceding source **fbe4b56** completed both full gates: **69 suites / 444,391 passed / zero failed**, Windows and Linux. Exact receipts are in `../rare-protocol/`; they do not verify this new worker source.

Current source full gates are running: Windows exec **30175** (immutable snapshot) and Linux run **39834230975**. Poll the existing processes; do not dispatch duplicates. Expected counts are not completed evidence. Targeted/type/native receipts above are complete.

Before enabling gameplay workers:

1. Profile the long remaining worker steps. In particular, CheckpointStore's recursive equality and graph/reference helper work still lack pulse points. Do not infer causality from a single 81 ms outlier.
2. Introduce a bounded preparation controller: at most one active job and bounded replacement work, exact epoch/sequence/intent checks after yields, stable owned records and explicit cancellation.
3. Keep capture coherent, incoming offers immutable, user selections frozen, and live graph/store changes atomic. Never yield through a live commit or server UpdateAsync transaction.
4. Connect one path at a time, starting with isolated offer validation/local store preparation; exercise stale/new selections, restore failures and cancelled rests through the real menu/controller.
5. Repeat native actual-controller/frame checks, then current full gates. Online rejoin, device controls, phone memory/performance and the broader audit remain open.

Fly, feeding and settings were not changed. The broader optimization goal remains active.
