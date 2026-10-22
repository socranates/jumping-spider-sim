## Native cleanup verified, 2026-10-22

Guarded Studio run1792690283994 passed9 cases/62 assertions on exact production sourcee315b3a. The probe captured valid Normal/Free/Easy preserve checkpoints before exercising isolated MemoryBackend sessions. Production Persistence was disabled, PlaceId0 and all218 scripts fingerprinted before playback. Zero Creator errors; one asset-type warning for203785492 was retained without claiming its owner is known. This establishes native synthetic cleanup, not live DataStore/rejoin, physical devices, frame-rate improvement or publication.

The initial run1792690129203 stopped after6 cases/45 assertions: its helper tried to JSON-encode an intentionally missing backend value. `native-first-attempt/` retains the failure and original probe/guard/manifest. Only the probe helper changed to compare missing values explicitly; the production source and all9 case bodies stayed identical. The passing v2 place is0b5008273f6d694b5e3287bca950c109ec48e70dc941a978164c4b6717c3d712. Both full Windows/Linux gates remain65 suites/443946 each on sourcee315b3a.

The newer server milestone in `C:/Users/natha/windowsill-save-continue`, branch `codex/save-continue`, is source2d184ee with219 modules and1,319 focused checks. Its real client/menu integration is still unfinished; this native result does not verify that newer source. Earlier pending-status paragraphs below are historical.

# Release an abandoned save lease after a refused recovery

Branch `codex/save-lease-cleanup`, based on `4ed6375` (navigation startup release snapshot `bc77830`). Unpublished. This is one step in the active foundation audit; safe foreign-lease Continue and historical-world restoration remain open.

## Problem and resulting behavior

A visitor can choose New Life while another session owns the save. Later, after acquiring the lease, the visitor correctly refuses retirement of a life it never saw or that changed elsewhere. Previously that refusal also abandoned its newly acquired progress lock without releasing it. A subsequent visit could be prevented from loading for up to the existing 120-second lease expiry, even though the conflicted visit would never write again.

The session now queues a metadata-only cleanup when it demotes from owned to session-only. The next budgeted server step removes the progress lock only if the atomic callback still sees that exact session as owner. It preserves the raw progress payload, checksum, timestamp, backup and unknown envelope fields; it never merges pending local progress, writes a rest, or acknowledges a refused retirement. Another owner's lock remains intact even when stale. Successful deliberate reacquisition cancels obsolete cleanup. Callback retries recheck current ownership.

Cleanup uses the existing request budget and failure backoff. Departure/shutdown can attempt bounded cleanup within its existing deadline, including when demotion happened during that flush. An unreadable/future progress envelope is left unchanged. If cleanup cannot complete before departure or the raw record cannot safely be opened, the lock still expires normally; this does not promise immediate recovery through backend failure.

Production change: `Shared/Persistence/SaveSession.luau` only, still 217 modules. No save schema, protocol, gameplay, menu, input, settings, feeding, camera, lighting or map changes.

## Regression evidence

The same expanded state suite reports **805 passed /26 failed** on predecessor production and **831 passed /0 failed** on candidate production. All 769 pre-existing state checks remain, with 62 new checks across nine cases. This is 26 failing assertions, not 26 distinct independent bugs. Cases cover all three modes, immediate re-entry after a refused unseen retirement, preservation of complete stored records, foreign owners (including stale beats), repeated atomic callbacks, transient/ambiguous failures, request budget, newer/corrupt/missing values, deliberate reacquisition and departure deadlines.

The reusable case block is appended verbatim to the default `state.luau`; no separate optional runner is needed to enforce it. `exercise.py` snapshots every source/test file and runs the same expanded fixture against the predecessor and candidate. `first-attempt/` retains an earlier invalid fixture: it shared one payload table between current and backup values, which the canonical encoder rejects. The corrected fixture makes a storable deep copy and asserts that precondition. No production change was made to accommodate the invalid fixture.

Compilation **217/217**, strict analysis and runner **5/5** pass. Evidence ID `b425324a7f0a8007`. Five integration suites now pass **1072 checks /zero failures**: state831, client162, offline8, storage14 and compression57. Both full platforms now pass65 suites/443946 checks each. Native synthetic cleanup remains pending.

## Remaining work

Safe read-only Continue still needs an immutable displayed rest identity, explicit intent bound to that identity, revalidation after ownership acquisition, and delayed/stale response handling. This cleanup removes an unnecessary lock wait; it does not implement that interface or silently authorize a different life. Old-world ecology still must not be discarded or relabeled. Current device, collision, network, performance, audio, online rejoin and release checks remain in `docs/audit/current-source/requirements.json`.

No live DataStore access, publication, FPS improvement or overall completion is claimed.

## Linux full gate completed

CI39811082793 completed successfully on exact sourcee315b3a at2026-10-22T16:19:06Z:65 suites/443946 passed/0 failed,217 compilation, strict analysis, runner5 and all four pinned download checksums verified. Actual metadata and five logs are retained and independently hash-checked. Windows31770 is terminal success65/443946, zero failed; no native cleanup result is claimed. A separate checkout at C:/Users/natha/windowsill-save-continue is implementing the remaining offer-bound Continue protocol; it does not modify this tested source.

Both full gates are now complete on sourcee315b3a:65 suites/443946 passed/0 failed each. Windows31770 exited0; the closed log was normalized to LF before its final hash was recorded and verified. Linux39811082793 is verified terminal success. Native synthetic cleanup, actual online rejoin and broader release requirements remain open. The separate Continue worktree is a newer unfinished feature, not this verified release snapshot.
