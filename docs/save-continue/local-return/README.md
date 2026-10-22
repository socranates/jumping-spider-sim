# Local saved-world returns prepare privately across frames

Runtime source07234ca; test verification source4ee6aec. Unpublished, on codex/save-continue. Release XML/BuildInfo still describe older code.

Local Continue, Free play, Backspace (when a rest exists) and the end-screen Back option now prepare behind a cancellable menu. Private copy-on-write store reads check checksums and select a valid current/backup candidate; each candidate is decoded only once. Atomic commit requires the same world generation, target store/revision and active store/revision. Until commit, the selected store and live simulation remain unchanged. Source revisions/new lives/superseding remote restores cancel obsolete preparation.

Cancellation restores the original end screen when appropriate; an ended spider is never revived early. Failed or newer-schema records leave current world and all stored bytes intact. A valid backup may recover a checksum-invalid current record without rewriting it. The local path keeps working even when network saving is broken. Empty in-memory stores retain the lightweight no-rest Backspace fallback. Menu routing and New confirmations use advisory availability hints; actual restoration still fully validates.

The protocol3 remote Continue path and durable receipt authority remain separate. Fly, feeding and settings logic is unchanged; this change is in save/return menu wiring. Local save snapshots still capture synchronously. Total preparation latency and long cooperative steps still require native measurement; no hard frame ceiling or FPS gain is assumed.

## Evidence boundaries

27 dedicated local-return checks pass on the actual client loop with shim services: delayed atomic visibility, cancellation, source/world fencing, failures, end-screen state, backup/newer-schema behavior, single decoding, independent local slots and offline return. The garden replay still compares insect/woodlouse positions at 1e-9 tolerance, plus identity/nutrition/profile, now explicitly at the same simulation tick. It passes33/0. Quiet HUD10/0 and client smoke27/0 pass after completion-boundary fixtures were adapted. The closed focused matrix and native receipts are detailed below; compiler final-check binds all222 source hashes with strict/runner5 success.

The earlier full Linux runs are terminal failures, retained under failed-ci-39846269494 (74 suites/444632 passed/5 failed) and failed-ci-39846956444 (74/444633/4). Their failures are the immediate-save garden/quiet fixtures, plus the original title fixture in the first run. They are not current full pass evidence. Windows98692 is the immutable133aa60 full archive; its terminal failure is retained below. The obsolete c4bcc6a Windows follow-up need not run: this current source supersedes it.

Physical devices, live online/rejoin, full native lifecycle/comfort, broad foundation audit, release publication and laptop synchronization remain open. Production DataStore is disabled in native diagnostics. Goal remains active.

## Closed focused and native proof

Current verification source4ee6aecc06f4753a85e40fc98a1487dc5126d27d, runtime source07234cae75b5a62b820dc6dda830dce7e503c36b. Focused matrix27 suites /25,294 passed /zero remaining failures. The original world replay fixture failure is retained in target.txt; its other26 suites passed. The corrected world replay independently passes33/0, comparing exactly the same simulation tick. verify.py checks both cohorts against current source and permits only that test-file difference. All222 source files compile; strict analysis and runner5 pass.

Native1792701458910 passed22 assertions with zero Creator errors and all223 script fingerprints matching. PlaceId0; production Persistence disabled. Local in-memory stores only, no injected or online transport. The diagnostic was stopped/saved/closed, Studio exited, and original place bytes/hash restored. No local CLI workload ran concurrently with the native measurement. Studio reported Low System Resources, so these are bounded observations rather than typical FPS/device claims.

A 1,501,336-character save: choosing local Continue took3.073ms and zero canonical encodes. Preparation took249 frames /4.210s elapsed /571.956ms total CPU, maximum update37.684ms. End-screen return took253 frames /4.241s /572.820ms CPU, maximum update37.884ms. Initial Heartbeat gap331.513ms includes preceding synchronous probe canonicalization and must not be attributed entirely to the worker; end-screen gap42.236ms. This does not prove a hard2ms budget or a causal speedup.233 initialization attempts were subject to streaming readiness; resident ecology counts were not measured.

The old133aa60 Windows run98692 is now terminal failure,74 suites/444632 passed/5 failed, matching its Linux result. Its archived input hashes and failure counts are verified in ../async-rest/windows-full-summary.json. The c4bcc6a Linux run also failed74/444633/4. Their garden/quiet/title timing fixtures have been corrected; neither old run is current full success evidence. The obsolete c4 Windows follow-up was skipped in favor of this newer source.

Current full Windows exec87216 uses an immutable4ee6aec Git archive. Linux39849815798 checks the same source. Expected75 suites/444664 remains an expectation until terminal receipts are collected. Keep the running Windows log untracked until its process receipt exists; do not restart a live run after an observation timeout.

Next performance work: large local-save preparation still takes18.5s in the prior bounded case, coherent capture139ms, and current cooperative commit steps can still reach38ms. Measure redundant encoding/copies/formatting before choosing further changes. Preserve all graph checks, dormant ecology, golden bytes, exact authority receipts and atomic commits. The broader28-item audit, lossless older-world restoration, actual online/rejoin/device tests and release synchronization remain open.
