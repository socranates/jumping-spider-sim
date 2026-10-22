# Owned save offers prepare across frames: source 8db0f6d

This unpublished source enables cooperative preparation for protocol3 network-owned offers, and avoids deep save checks merely to render the menu. Existing release XML/BuildInfo still represent an older source and must not be published as this build.

## Behavior and ownership

The actual OnClientEvent adapter transfers ownership of its decoded record tables to `receiveOwned`. The caller must keep transferred records stable; only read-only retained probe references are permitted. There is one production ToClient listener, in SaveClient. Ordinary borrowed `receive` remains synchronous and copies before returning. Do not use the owned adapter with mutable shared simulation tables or borrowed data.

Offer preparation runs one worker resume per frame, fairly across slots. Each slot retains at most one active observation and one coalesced replacement. Envelopes retain known scalar fields and the stable owned record, not arbitrary messages. The queue bounds retained observations, not the byte size of an unvalidated engine delivery; full type/node/size/mode/graph validation still runs before any offer becomes visible.

Independent status, decisions and receipts apply immediately while offers prepare. Publication rechecks epoch and accepted offer sequence; withdrawals cancel obsolete work. Repeated immutable ids retain their first accepted private record, including repeats queued before the first one finishes. A newer invalid observation cannot erase a prior validated offer. On read failure/timeout, the menu reports the problem and keeps the saved rest unchanged; a successful retry clears the problem. Closing saving for the visit cancels retained inputs and prevents later owned offers from queuing.

New/remote Continue choices wait for a pending slot to settle. A confirmed choice is still bound to its displayed id, not silently rebound after preparation. Current local rest availability is an advisory `hasKnownRest` hint established by a successful read/write. Rendering the menu no longer loads, hashes or decodes those records. Actual selection/load/restore still validates; the hint cannot make a corrupt rest loadable. The earlier private, cancellable Continue preparation remains enabled.

Fly, feeding, settings and HUD were not changed. Read/preparation text appears only in the menu.

## Completed current evidence

- **16 focused suites / 2,592 passed / zero failed**, 222/222 modules compile, clean strict analysis and five runner regressions. Root `../verify.py` binds committed source, every targeted input, compile hashes and native script fingerprints/receipts.
- SaveOffers 99, SaveRestore 24, SaveWork 39, checkpoint 565, real continuation menu 41. Covers ownership separation, delayed visibility, status ordering, immutable queued repeats, withdrawal, invalid replacement, stale epoch/sequence, queue bounds/fairness, pre-handshake delivery, timeout/retry, closed-worker cleanup, confirmation timing and advisory-cache corruption refusal.
- The first retained attempt has one failed menu assertion: it expected a confirmation to survive an earlier rejected click during pending work. The final fixture separately verifies pending rejection, a fresh explicit confirmation afterward, and a genuinely stale confirmation held across a completed observation. World/store/request assertions were strengthened; runtime was not weakened to satisfy it. See `attempt-1/`.
- Actual Studio run **1792696992730**: **20 assertions**, zero Creator errors, one asset-type warning. All 223 scripts fingerprinted; PlaceId0 and production Persistence disabled. Exercises the owned adapter, actual menu/Continue, private offers, cancellation by withdrawal, immediate authority change, unchanged installed rest and zero menu canonical encodes. Uses injected local transport, not a real RemoteEvent round trip or online store.
- Record: **1,501,296 canonical characters**. Initialization was attempted for 233 regions subject to existing readiness gates; resident/materialized region counts were not measured. This does not prove fully explored ecology coverage.

| Native synchronous call | Elapsed |
| --- | ---: |
| Initial owned receive, including callbacks | 17.978 ms |
| Replacement owned receive, populated local store | 4.656 ms |
| Populated menu render, zero save encodes | 6.584 ms |
| Five known immutable repeats | 10.131 ms |

| Native preparation | Frames/steps | Largest update | Total update CPU | Elapsed |
| --- | ---: | ---: | ---: | ---: |
| Initial offer | 219 | 30.678 ms | 526.026 ms | 3,670.128 ms |
| Actual Continue | 618 | 60.934 ms | 1,454.194 ms | 10,489.875 ms |
| Replacement offer | 219 | 13.567 ms | 490.271 ms | 3,677.623 ms |

The 2 ms budget is soft. These measurements prove deferral/correctness, not a hard frame budget, typical FPS or a controlled speedup against another run. Studio showed Low System Resources. No concurrent Windows full run was active during this native case. The large first Heartbeat gaps (520.759/471.678ms) include preceding synchronous probe capture/copy/canonical verification/selection work and cannot be attributed solely to worker updates. The replacement stage's gap was 61.068 ms. GC/native operations/atomic commit remain unpreemptible, and overall Continue latency is still substantial.

Playback stopped, diagnostic saved/closed, Studio exited and Studio-saved bytes archived separately; original guarded place restored exactly (`close.json`). Never publish this diagnostic.

## Full gates and next work

Current Windows full run is exec **95122**, an immutable Git archive of8db0f6d. Current Linux run **39839306311** is live. Poll those existing runs; do not restart them on observation timeout. No completed current full gate is claimed. Preceding 955d1eb completed Windows/Linux 70/444440/0;5aec1bc completed Linux 71/444474/0. Their receipts are historical. A separate 5aec Windows run was superseded by the current-source full run, since neither intermediate candidate was published.

Next: move local rest saving/queue preparation off the simulation frame with coherent immutable captures and truthful pending/success/failure; also address synchronous local Continue/Backspace/last-rest return. Profile redundant store/decode work and the remaining long updates/overall load latency, rather than calling soft budgets a performance guarantee. Preserve epoch/serial/credential/ticket receipts, independent slots, immutable choice and atomic graph/store commit. Current full gates, source-bound release artifacts, real network/rejoin, devices/phone performance, older-world restoration and the broader foundation audit remain open. Nothing published; overall goal active.
