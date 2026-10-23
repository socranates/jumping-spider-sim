# Private post-archive recovery coordinator

This coordinator assembles the previously isolated commit stages under actual SaveSession intent/observation guards, worker serialization, scheduler quota and heartbeat handling. It begins after the archive stage has produced its plan. It does not yet connect the archive controller automatically to a production legacy-save offer, enter a life or resume the ordinary save worker.

## Sequence

1. Capture the exact selected readonly Continue and require an acknowledged fresh owned P lease before network recovery work.
2. Reconstruct A1 from its stored anchor/parts and independently verify all publication keys through the immutable archive repository. The supplied plan's owner/checksum is an expected descriptor, never durability proof. Missing/incompatible artifacts refuse; original values are not overwritten.
3. Probe M1 uncached. Validate the selected archived primary/explicit backup against the captured observation after decoding its raw stored representation. When M1 already exists, validate and reuse it rather than recomputing a different packet/rare binding. Otherwise prepare from the archived original, owned session progress snapshot and a stable fresh Preserve template.
4. Publish/read back M1 through the existing immutable repository; prepare registered rest/progress writer handles cooperatively from the actual durable proposal.
5. Perform the exact raw selected-R compare-and-swap/readback, then absorb the pending global proposal under the current P lease.
6. Read the exact selected R target again and require a final protected P lease acknowledgement. Return `verified` with `requiresSessionRebind=true` and `gameplayAuthorized=false`.

The template and context must remain stable throughout preparation; a future caller must construct an owned fresh template rather than pass a live mutating checkpoint. Packet/writer traversal preparation runs under SaveWork. M1's opaque structure and session progress are bounded before copying during probing. The existing proposal-store preflight/readback validation is still synchronous; native profiling/cooperative integration remains required before release.

Each step admits at most one backend request under the session's rolling allowance. CPU-only preparation can proceed while quota is unavailable. Lease renewal has a separate retry timer and priority over data-stage backoff. Defaults cap the post-archive stage at 64 requests/900 seconds, including heartbeats. The existing archive controller has its own separate phase limits; these are not a new combined whole-migration bound. Reentrant ordinary worker calls are refused while an operation is in flight. Cancellation, request replacement, session closure and lost/expired lease observations revoke the staging handle; already durable records remain for a subsequent authorized resume.

## Late-lease counterexample

The first assembled version verified R after global readback and then returned a result using its local guard. A test transfers the actual P lock during that final R read: the local guard still looks current, so the earlier version incorrectly reports verified. Its exact failing source/test/output/receipt are retained as `late-lease-negative-*`. The corrected version adds a final owned-lease UpdateAsync acknowledgement and refuses that same case. An ambiguous final acknowledgement cannot report verified; it must retry under heartbeat backoff and acknowledge ownership. This is a verified lease observation, not multi-key atomicity or a promise that another server cannot take over later.

## Evidence and explicit boundary

The coordinator fixture passes 4,836 assertions, including per-step quota/request checks, plus the preceding 959 regressions (5,795 total). All fifteen private candidates pass full strict analysis in a disposable source tree. The normal post-archive path uses 31 requests and 186 simulated seconds. These are synthetic scheduler figures, not wall-clock service latency or FPS measurements.

Tests use actual SaveSession, observations, intents, scheduler, archive repository, packet/proposal and both writers over MemoryBackend. They cover successful composition, archive/unselected-save immutability, queued local progress retention, no credential issuance, lost acknowledgements at M1/R/P, same-session and new diagnostic-session resume after R replacement, superseded Continue, lease takeover, corrupt A1, request/deadline refusal, worker reentry, archive retry heartbeat priority and proposal pre-write retry. The two resumed sessions reuse the first exact M1 bytes and archived originals. Initial strict errors and a draft nil-probe refusal were preserved and corrected.

**Diagnostic offer bridge:** production currently cannot publish the archived Test Garden record as this protected recovery offer after a schema-3 interruption. The tests explicitly validate the recorded source and call the real observation/intent APIs to create that offer. This is an admission/fencing fixture, not evidence that production menus or real rejoin already expose recovery. No new synthetic restore is presented as a full playable life.

The older archive-only controller also assumes an uncompressed selected source in its admission comparison; its compressed-source path still needs integration with the recorded-source decoder. This coordinator decodes that archived comparison, but it does not automatically fix the preceding controller or connect both begin APIs.

## Required next work

Implement the real recorded-save/pending-M1 offer reader and cold/resume admission, connect the archive-to-commit phases under a combined deadline/request policy, and synchronize current session progress/observations before permitting the ordinary worker to resume. Then integrate schema-3 rest readers/writers without dropping pending proposals, issue the appropriate durable life/intent credential only after the full entry protocol, and handle mating/hatching/ended lives. Keeping the original readonly request after storage verification is intentional until that work exists; a future caller must not simply start gameplay or unpause queued writes.

Native compression/callback/heap/frame measurements, real DataStore takeover/interruption/rejoin, full regression gates and release remain open. No production source was changed, no real saves were touched and nothing was published.
