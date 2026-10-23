Current opt-in private schema3 entry is documented in `RECOVERY-ENTRY.md` and verified by `recovery-entry-verification.json`. The default gate remains read-only. The earlier routing evidence below is historical; the latest entry cohort binds the modified Runtime and all preceding tests. Production adoption remains open.

# Private session factory and routing

`RecoveryRuntimePrototype` composes the actual session, recorded-offer reader, accepted-intent pipeline, terminal-held maintenance and departure writer. Its constructor installs **and binds** the baseline sidecar before the first load. It copies configuration instead of changing the caller's backend. Normal healthy visits still use actual SaveSession stepping and flush; recovery phases never fall back to that whole-snapshot worker.

The server-only API is `new(sessionConfig, recoveryDependencies)`, `load`, `discover(mode, explicitPrimaryOrBackup)`, `accept(mode, serial, offerId)`, `cancelRecovery`, `dismiss`, `step`, `depart` and cooperative `flush(deadline)`. `accept` uses the actual session's selected Continue, not a synthetic offer bridge. Raw provider, codec, target template and validation context are server dependencies, never client-supplied save graphs. The factory requires explicit fresh/raw reads and cooperative clock/sleep. Offline provider construction still needs a production integration policy.

## Phases and ownership

- `normal`: the healthy session's existing worker and rest/progress flush.
- `discovering`, `offered`, `offer_refused`: only bounded reader work and a fresh metadata lease; no normal preview can withdraw/replace the protected observation. An unaccepted offer can be dismissed. Discovery pauses while unrelated rest/life work exists.
- `recovering`: the one accepted-intent owner runs archive/commit/readback/rebind under its existing total transaction limits.
- `held`: a cancellation/refusal retains the write barrier and uses the existing terminal lease helper. Explicit rediscovery/retry can resume an immutable pending proposal.
- `entry_required`: storage/local reconciliation succeeded, but a **new enforced baseline hold** blocks ordinary writes while the schema-3 entry remains unimplemented. The result still has `requiresSchema3Entry=true`, `gameplayAuthorized=false`; it is not a playable restore.
- `lost`: a changed/expired/foreign scope is fenced. No ordinary retry/load/flush is used to acquire authority by accident. Local progress is retained; safe fresh-session replacement is still separate work.
- `closed`: terminal shutdown outcome. A late provider cannot replace it with a held/lost/recovered outcome.

`RecoveryReadLeasePrototype` protects discovery, menu deliberation and the entry gate separately from accepted transaction accounting. It updates only existing fresh lock metadata, shares the rolling request allowance, probes uncertain writes uncached and rejects scope/clock/provider changes. Normal global payloads/backups and R/M1/A1 stay unchanged. This private lease helper intentionally keeps its scope separate from the already tested terminal owner; common metadata mechanics can be consolidated after the production entry contract is complete.

Every non-normal route pins the load serial, backend/provider, session/user/key, scheduler, observations/intents and allowed recovery owner. That pin is checked on departure **before** choosing the normal flush path, so a changed epoch cannot replay stale whole-progress choices merely because another tick has not noticed it yet. Tests include actual remote-choice contents that would be vulnerable to such a fallback.

## Departure and initial loading

The recovery-specific flush closes intake, drains providers, and preserves final global changes through the existing three-way write/release/readback sequence. An existing shared shutdown deadline is retained. Deadline expiry can end a stuck wait without pretending a save was verified; outstanding callbacks then fail their closed scope.

SaveSession's initial `load` does not use the ordinary worker's `busy` flag. The factory therefore drains its own load call before ordinary flush. The optional pre-load baseline binding checks session identity and closure inside each provider callback and again on acknowledgement. If loading cannot finish by the closing deadline, it cannot acquire an orphaned late progress lease. The explicit departure capability remains the sole exception for the bounded final P write after closure.

A retained regression reproduces a late recovery completion changing an already closed routing result; transition guards now preserve the terminal result. Additional tests found that a changed epoch must not be rebound opportunistically during refusal. Historical variants and failed logs remain alongside the final v4 cohort. The initial strict literal-narrowing diagnostic was corrected with an explicit post-helper string view; no test condition was relaxed.

## Current evidence and remaining work

`recovery-runtime-verification.json` binds **11,963 routing assertions + 38,782 preceding regressions = 50,745 passing checks**, entry compilation and full strict analysis with **26 private candidates**. Actual Session/MemoryBackend/discovery/pipeline paths cover compressed/uncompressed recovery, long offered/discovery waits, entry holds, cancellation and pending rediscovery, normal healthy saving, raw provider yields, shutdown deadlines, foreign/changed scopes, slow/lost acknowledgements, late responses and loading-time departure. Every checked routing step makes at most one request and shares the existing rolling quota.

Production source/test bytes remain unchanged at 441eaca; its separate full platform gates remain separate evidence. The earlier 22-assertion Studio helper fixture is historical for the preceding private baseline version. **This newly bound factory/coordinator has no native or real-service proof yet.** No production factory, SaveService, remotes, menus, schema-3 reader/writer or gameplay entry is connected.

Before adoption, route every SaveService load/tick/leave/shutdown path through this owner, including departure during loading and the common shutdown deadline. Add protected-recovery discovery/choice UI and explicit server protocol routing without bypassing existing message validation/rate limits. Complete schema-3 rest/mating/hatching/ended-life readers/writers, pending-proposal retention, life credentials and safe fresh-session replacement with local progress. Then qualify native full composition, actual storage interruption/rejoin, adopted regression gates, release/main/laptop synchronization and publication. This remains unfinished migration work; the broad optimization/reliability goal is active.
