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

Compilation **217/217**, strict analysis and runner **5/5** pass. Evidence ID `b425324a7f0a8007`. Five integration suites now pass **1072 checks /zero failures**: state831, client162, offline8, storage14 and compression57. Native synthetic verification and full platform gates are still pending. Expected full totals after adding the 62 assertions: 65 suites /443946, not yet an actual full-gate result.

## Remaining work

Safe read-only Continue still needs an immutable displayed rest identity, explicit intent bound to that identity, revalidation after ownership acquisition, and delayed/stale response handling. This cleanup removes an unnecessary lock wait; it does not implement that interface or silently authorize a different life. Old-world ecology still must not be discarded or relabeled. Current device, collision, network, performance, audio, online rejoin and release checks remain in `docs/audit/current-source/requirements.json`.

No live DataStore access, publication, FPS improvement or overall completion is claimed.
