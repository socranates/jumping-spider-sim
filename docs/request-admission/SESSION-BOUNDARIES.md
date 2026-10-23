# Ordinary Session admission boundary audit

The recovery workers are not the whole persistence service. The remaining ordinary `roblox_port/src/Shared/Persistence/SaveSession.luau` path still starts provider work without the shared typed gate. It must be converted before normal activation. The source and the factory-bound baseline sidecar are hashed in the two `session-boundaries-before-fix-1` receipts.

## Reproduced, still unfixed

`probe-session-boundaries.py` bundles the actual production Session and actual private factory baseline, with no recovery/WorldMap/Checkpoint override. Both tests intentionally fail their correctness assertions on the current source. They are counterexamples, not passing regression checks and not native latency measurements.

- **Initial acquisition can acknowledge an expired lock.** The provider delays its first progress callback by121 synthetic seconds. Session captured `now=100` before the provider started its callback, writes beat100, then reports `active` at221 and records scheduler beat221. The exact baseline ACK succeeds, but the stored lease is already expired. The failing assertion is `initial load reported active with an already expired stored lease`. New admission waits must not inherit this timestamp pattern.
- **A started initial rest read is missing from in-flight accounting.** A real MemoryBackend read increments its physical request count, then suspends before returning. At that point the provider has2 starts, while Session counters/history still contain only the1 progress acquisition. `readRests` charges after `readCurrent` returns. The failing assertion is `in-flight initial rest read is absent from request accounting`. A shared server gate must charge before the physical start, including reads that throw, yield or return after closure.

These issues are deliberately left visible while ordinary Session admission remains uninstalled. Fix them in the actual Session/provider path and rerun these exact correctness assertions against the replacement, then qualify the complete service. Do not call the broader game problem-free because the separate held-worker cohort is green.

## Provider and authority inventory

| Ordinary operation | Physical entry | Existing timing/authority to retain |
| --- | --- | --- |
| Initial/retry progress acquisition | `attemptLock` → `backend:update(P)` | Load serial and bound backend/account fences, schema/backup refusal, other-owner lock check, latest local merge; use callback/ACK time correctly. |
| Initial/deferred rest loads | `readRests` → `readCurrent(R)` | Uncached reads, cursor/fairness, load-generation checks, protected backups, life/revision bases and pending candidates. Charge at dispatch. |
| Preview refresh | `previewOne` → `readCurrent(R)` | Observation-only publication, no implicit write baseline, provider backoff and no invented empty rest. |
| Exact life intent validation | `validateIntent` → `readCurrent(R)` | Real selected observation/revision/life, New-missing-only and own retirement witnesses; never grant because capacity waited. |
| Progress/flush write | `writeProgress` → `backend:update(P)` | Monotonic progress merge, newer local changes during yield, versioned dirty/debounce state, exact ownership and release ordering. Audit captured times and ACK authority. |
| Ordinary checkpoint/retirement write | `writeRest` → `backend:update(R)` | Captured life/revision/credential/tag/serial, foreign conflict refusal, per-key interval, protected records and exact stored receipt. |
| Demoted-owner metadata release | `releaseOwnedLock` → `backend:update(P)` | Metadata-only, exact still-owned lock, dirty release retry and no payload replay. |
| Ordinary heartbeat | `heartbeat` → `backend:update(P)` | Lock-only, schema/owner refusal, fresh timing and bounded retry. |

There are five direct `backend:update` call sites and three `readCurrent` caller sites in this source. The read helper itself uses `readFresh` when available and otherwise a provider without a cache's existing read contract. Do not change the real backend's fresh-read behavior to make the tests fit.

## Service integration requirements

The current Runtime binds `RecoveryProgressBaselinePrototype` before initial `Session.load`, which protects callback lifetime and records exact positive progress ACKs. It does not itself admit requests or prove a lock is fresh. Existing replacement owners drain their old owner and copy ordinary scheduler debt; their64-entry inherited-debt bounds and reserved old-style load quota are not a typed account gate.

`RecoveryStartupBudgetPrototype.attach` replaces scheduler `budgetOk`/`begin`, owns additional startup/normal histories and may invoke its observer while bookkeeping. Closing a startup ticket is not the same as removing its wrappers or re-importing partial history. The complete `scheduler.started` history is retained; include failed/ambiguous starts and retire competing admission before switching. The shared typed gate must persist across failed constructors, cancellation, removal/shutdown and every account epoch. Do not reset debt or silently fall back to a new untyped Session.

A replacement must preserve all existing SaveSession APIs and their real stored acknowledgements, while exposing capacity wait separately from provider failure. A polled service tick must not block all actors on one player's capacity. Synchronous initial load may yield, but its pending authority, deadline, actual provider drain and late constructor return must remain owned. A later bounded cooperative driver needs to distinguish admission waiting from an actually suspended native request; never manually resume a native provider or let ordinary load/flush race it.

First implementation work: centralize those eight ordinary entry sites behind retained, correctly typed operations; charge only at dispatch; revalidate lifetime/source and callback time after waiting/bookkeeping; retain per-key timing/backoff/versions. Then wire Runtime/Profile/Replacement/Service factories to one service-owned gate and qualify actual multi-actor initial/retry/normal/closed/replacement lifetimes. The normal engine remains disabled for these private adapters, and all live/performance/release gates remain open.
