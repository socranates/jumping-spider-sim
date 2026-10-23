# Superseded: recovery pacing and suspended-operation fences

Integration rejected candidate20f59026: the normal state suite reported1250 passed/2 failed because callbacks could deliver retained values from slots not yet re-read. The smaller callback harness threw assertions inside a protected callback, allowing those errors to be swallowed. Its earlier126-check native pass is execution evidence under that incomplete harness, not qualification for adoption. The uncommitted adoption was withdrawn and production restored exactly to fully verified f405359. The adoption script now refuses this candidate. A replacement adds a restLoaded guard and persistent callback-failure accounting; its new native/full qualification is pending. See docs/recovery-pacing-gates/initial-adoption-withdrawn.json and the corrected candidate's receipts.

Earlier status below is historical and superseded by this integration finding.

Private candidate20f59026a57a11bcdde02845963d51d6fb1657d58b72ff0510794d6ee35a32f1 supersedes the pacing-only candidate. Production still uses f405359. Adoption waits for its current Windows95443 full run and root verification; the prepared adoption script refuses an absent gate. Linux39886240490 has completed76 suites/468225 checks/0 failures, compile222, strict clean and runner5. Those are freshness-cohort results, not full results for this private candidate.

The pacing candidate already retained prior rests, delivered merged progress immediately and bounded periodic requests. Genuine coroutine suspension then reproduced a late rest callback after departure. The revised candidate assigns a generation to each load/demotion, checks it after yielding store operations, and refuses to apply or deliver results after closure, demotion or a newer load. The periodic worker also suppresses notifications from an obsolete acquisition. Reentrant worker calls remain refused while a request is pending.

Cancellation fences application and callbacks; it cannot undo a backend request already in flight. A lease update that finishes after departure can remain until its normal expiry. No extra unsafe unlock/write is used to disguise that limitation. Real service/rejoin behavior remains required before a durability claim.

Evidence, bound by verify-session-budget-yield.py:

- 82 pacing/retention/progress assertions, unchanged acceptance criteria.
- 44 additional assertions across suspended reads and lock acquisition, each interrupted by close, demotion or a superseding load.
- 1624 checks in seven unchanged save suites, zero failures; both module compilations, sourcemap and full strict analysis clean.
- 126 native server-context checks, all224 source fingerprints and zero CreatorErrors. MemoryBackend with actual coroutine suspension and frozen valid checkpoint fixtures; all production scripts disabled. No real DataStore or full game transport proof.

The native fixture initially omitted its SaveRules import and failed before its first assertion. Exact failed source, manifest, guard and error are retained. Correcting that fixture changed neither candidate bytes nor acceptance. An earlier builder preflight failed before opening Studio because its copied fixture-manifest path was renamed incorrectly; the initial builder source is retained. A UI set-value timeout was resolved by observing that the full guard was already present, then executing it once. No duplicate test run was started from that timeout.

Both opened places were stopped/saved/closed and the owned Studio window exited. The saved serializations were retained and original package bytes restored: failed fixture50cb0544... and successful fixture12ea81ed.... The pre-existing Studio window stayed untouched. Never publish either diagnostic package.

The prepared adoption changes only SaveSession and appends126 assertions to the existing state suite, keeping schemas and mechanics unchanged. It requires fresh full Windows/Linux gates afterward. Historical progress import/complete archive integration, actual service/rejoin, natural lifecycle/streaming/device/memory/performance and release work remain open. Goal active; nothing published.
