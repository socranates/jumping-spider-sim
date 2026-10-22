# Native save/controller cost probe

Actual Studio run1792692875948 on production source47241c9 completed13 assertions with zero Creator errors. Production Persistence was disabled, PlaceId0 and all221 scripts fingerprinted before Play (220 production plus the diagnostic). Saving used an injected local transport, not actual SaveRemotes/DataStore. The source-bound current verifier also confirms current fbe4b56 has byte-identical production files and all native module fingerprints agree after the same CRLF-to-LF normalization used by the builder/guard.

The native record was1,501,296 canonical characters. The probe attempted initialization for233 regions, but the normal regionReady/streaming gate still applied; resident/materialized counts were not measured. **This is a large-save probe, not proof that every region's ecology was materialized.** The native record differs from the2,277,087-character CLI fixture, so do not compare their absolute timings as equivalent workloads.

| Actual native operation | Direct elapsed ms | Largest observed frame gap ms |
|---|---:|---:|
| Capture |105.888|115.359|
| Receive/validate offer |700.966|930.924|
| Five unchanged offer deliveries |0.020|45.334|
| Menu Continue/store/restore |1618.735|1629.077|
| Local rest capture/store/queue |2639.133|2660.579|
| Scripted grant/upload copy/local receipt |51.857|68.410|

Studio reported Low System Resources and the old Windows full CLI exec63820 was active concurrently. Only3-4 frames were sampled per operation. These observations locate real synchronous work; they are not typical FPS, a causal speedup, a clean baseline comparison, peak RSS, network transfer, physical-input, phone or online-rejoin evidence. The single retained Creator warning concerns asset203785492 being requested as the wrong type; its owner is not established here.

The13 assertions cover startup/fresh capture, loop count, valid native rest, accepted preview, explicit actual menu selection, correct local slot, initial read-only state, a retained local rest, no early upload, actual intent before the scripted grant, permission before injected receipt, and confirmed local ticket. They do not exercise the real server/DataStore backend or all failure/device modes.

Playback was stopped, the place was saved/closed, its Studio-serialized copy archived outside the repo, original guarded bytes restored/hash-checked, and Studio exited. close.json retains restoration hashes. No diagnostic or game was published. v1 was prepared but never executed; v2 is the executed place.

## Next implementation work

Prioritize responsive initial processing, local store and restoration; repeat-offer caching is already fast. Add phase-specific inclusive timings before changing hashing or graph semantics. A cooperative worker must preserve canonical bytes/checksums, full size/type/mode/graph validation, atomic live-world commit, immutable selected/candidate records, bounded retention, shared New/Continue supersession, current-credential receipts and save-close deadlines. Yielding preparation cannot allow an older packet or choice to publish after a newer one. Live-world capture must hold a coherent simulation boundary, and failed/cancelled preparation must retain the existing world and local rest. Re-measure with a readiness census and without concurrent test load before performance acceptance.
