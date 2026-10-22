# Authority and persistence review

Baseline: v51, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place 140, evidence `d9ddc5e0ed43d301`.
Candidate: `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`, branch `codex/foundation-audit`.

The solo simulation is client-authoritative. The client controls movement, meals, hunger, growth, difficulty, observation and deaths. Save validation establishes a sensible record, not that the player earned it. A modified client can alter its own life and notebook. This is an architectural choice in a solo game with no economy; this audit does not introduce a server simulation or claim anti-cheat protection.

## Boundaries checked in source

* `Server/SaveService`: server derives keys from the caller's UserId; no client-selected user key. `ToServer` accepts hello, progress and rest; `ToClient` sends loaded, status and rest. Token buckets limit requests. Handlers use protected calls. `SaveSession` validates bounded payloads before writes.
* `Server/WorldFocus`: reports move the caller's streaming focus; finite Vector3, map bounds and frequency checks. It does not grant changes to another player. Moving one's own focus can still request world replication; profile network/load costs rather than treating the location claim as authoritative gameplay.
* `Persistence/DataStoreBackend`: protected API calls; atomic UpdateAsync callbacks. Progress owns a session lease. Rest writes compare the prior update time and session before replacing. Shutdown retains ownership while pending writes flush.
* `SaveEnvelope`: canonical checksum and retained previous version; newer envelope schemas are read-only. The checksum detects corruption, not a malicious client's forged life.
* `SaveRest`: plain finite bounded values, graph/reference/actor validation, slot/rule agreement. The graph-size cap is meaningful security protection and must not simply be removed to fix A02.
* `SaveProgress`: sanitizes notebook IDs/counts, settings and optional rare ledger; merges monotonic discoveries. `MAX_PROGRESS_CHARS` is not currently enforced as a separate byte cap, though node/depth and field bounds do apply.

## Changes and remaining risks

A02 makes a refused known-slot rest visible through the existing status channel. It does not change authority, keys, leases, checksums, schemas or stored payloads. A valid subsequent rest clears only that slot's refusal; other slot failures stay visible. Earlier backend data must remain byte-identical on rejection.

The load-time quarantine problem (A04), new-life identity (A05), and overlapping-session Continue behavior (A06) need a coherent persistence design. Do not repair these by clearing corrupted records, stealing a live lease, or uploading local defaults after an unsuccessful read. Keep test-store isolation and legacy fixture coverage.

No production DataStore was edited for this audit. Live service throttling, live rejoin and a malicious native RemoteEvent exercise are not established by the CLI tests. See TESTS.md for the evidence boundary.

Roblox's documented per-key value limit is 4,194,304 characters. Two copies of the 2,277,087-character stress record already exceed it before envelope overhead. [Roblox data-store limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits).
