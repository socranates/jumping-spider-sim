# Continue prepares across frames: source 5aec1bc

This unpublished source enables cooperative preparation in the actual Continue menu/controller. Local rest capture/queue and the first incoming offer are still synchronous. Existing release XML/BuildInfo represent an older build and must not be published as this source.

## Player-facing behavior

Choosing a saved spider opens a small preparation menu with Cancel. The current world and local rest remain until preparation finishes. Cancellation discards the private job and revokes only that request's upload path. Another selection, new life or local return supersedes pending preparation. Success installs the prepared graph once and swaps the private local store; later authority replies cannot restore it again. Failure retains the current world and offers another explicit selection.

The existing immutable offer/selection, independent slots, Easy unlock and protocol3 durable-receipt rules remain. A cancellation is bound to slot, serial and epoch so it cannot revoke another selection/session. Fly, feeding, settings and HUD were not changed.

## Implementation

`SaveRestore` holds one worker. It checks the selection before each step and again after preparation, retains results privately, cancels obsolete work and invokes the atomic commit outside the worker. The game supplies a private record copied by the existing continuation boundary. A private CheckpointStore is prepared first, then `Checkpoint.prepare` returns a single-use validated graph commit. Only the current selection can call it and install that store. `Checkpoint.restore` keeps its synchronous interface for existing callers. A prepared graph cannot be committed from inside a worker. CheckpointStore's recursive equality now has pulse points too.

No yielding capture of a changing live world was introduced. Menu-only work is not a solution to rest-capture, initial offer or upload-copy costs.

## Completed evidence

- **15 focused suites / 2,484 checks / zero failures**, 222/222 module compilation, clean strict analysis and five runner regressions. Source/test input hashes are checked by `verify.py` and root `../verify.py`.
- SaveRestore24 checks; checkpoint560; actual continuation menu37. They cover partial/private work, cancellation, obsolete results, reentrant current checks, refusal/error, single-use commit, current-world preservation, separate modes, failed load, stale serial and stale epoch cancellation. The menu fixture forces many resumes; it does not disable workers for tests.
- Actual Studio run **1792695682704**, **13 assertions**, zero Creator errors, one asset-type warning. All223 scripts fingerprinted, PlaceId0 and production Persistence disabled. Actual menu Continue/Cancel/retry and real CheckpointStore/graph/controller were exercised through injected local transport. No online store, physical input or network transfer proof.
- Selected record: **1,501,296 characters**. Initializing233 regions was attempted subject to existing readiness gates. Resident/materialized region counts were not measured; not proof of fully explored ecology.

| One native run | Result |
| --- | ---: |
| Initial offer receive, still synchronous | 822.738 ms |
| Second Continue selection/copies, still synchronous | 125.694 ms |
| Preparation/controller frames | 713 |
| Largest measured controller update, including final commit | 64.392 ms |
| Total controller update time | 1,663.482 ms |
| Elapsed preparation time across frames | 12,180.467 ms |
| Largest sampled Heartbeat gap | 138.837 ms |

This proves the actual frame-driven path and cancellation, not a hard2ms budget, typical FPS or a causal speedup. The requested worker budget is soft2ms; native operations, GC and the final atomic commit remain unpreemptible. The first Heartbeat gap can include preceding synchronous work. Studio showed a Low System Resources warning while the prior Windows full suite was also running. Timings from different runs are not controlled before/after benchmarks.

Playback stopped, place saved/closed, Studio exited, Studio-saved diagnostic archived and original guarded bytes restored (`close.json`). Never publish this diagnostic.

## Gates and next work

Current source Linux run **39836124046** is in progress. The previous source955d1eb completed Linux **70 suites/444440/0**; its Windows exec **30175** is still running. Poll that existing handle before starting current-source Windows full tests; `full.py` is ready but has not been launched. Earlier gates do not verify this new source. Expected totals are not completed evidence.

Next priorities: remove the synchronous first-offer validation/copy stall with stable private input and exact sequence/epoch checks; move local rest preparation/queue off the simulation frame with truthful pending/success/failure behavior and immutable coherent captures; profile the remaining long controller steps. Preserve atomic commit and do not write live storage from a cancellable job. Current full gates, real network/rejoin, physical-device/phone performance and the broader foundation audit remain open. Nothing published; overall goal active.
