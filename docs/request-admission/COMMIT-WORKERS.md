# Typed commit, writers and recovery pipeline

This extends [archive admission](ARCHIVE-WORKERS.md) with explicit replacements for immutable proposal publication, selected-rest CAS, global progress absorption, commit and the root recovery pipeline. Their optional typed route preserves the existing source, ownership, transform and readback rules. **Normal Runtime/startup still supplies no lane, other save/lifecycle workers remain unconverted, and no server-wide installation or publication is claimed.**

## What is connected

`pipeline.luau` passes the same trusted lane to its archive and commit children. Its own proposal-admission and final witness reads use retained operations. Separate renewal/read handles allow independently eligible work while an acknowledged, unexpired lease remains valid. Renewal candidates use the actual callback time. Any renewal after a rebind capture invalidates that capture and restarts its witnesses. Root totals derive from actual global starts; remaining request/time bounds pass to children without double charging attempted steps.

`commit.luau` independently verifies the stored archive, reads and validates an existing M1 or prepares an owned proposal, then runs the proposal/rest/progress writers. It retains the final fresh rest read and exact positively acknowledged lease check. A queued final lease does not advance the renewal serial or verify commit. A foreign owner appearing while it waits refuses commit without overwriting the foreign lock. Verified commit still requires local session rebind and grants no gameplay or life credential.

Each writer keeps its original protocol and gains an optional parent accounting context:

- `proposal.luau` retains read-first, insert-if-absent publication and fresh raw readback after success or ambiguous acknowledgement. A valid existing proposal in the same exact source/archive scope wins unchanged. A capacity-denied write does not set its attempted-write flag.
- `rest-writer.luau` retains the exact prepared-plan registry, fresh immutable M1 comparison, original-or-target CAS and fresh target readback. An explicit captured `updateRaw` binding calls the existing raw adapter; it never changes `session.backend`. Pipeline's selected-key and held-baseline permission checks still execute. Waiting for readback does not repeat CAS.
- `progress-writer.luau` retains immutable proposal/rest witnesses, exact owned fresh lease validation, monotonic merge, bounds and post-write coverage verification. Its transform and rejection evidence persist across capacity waits and reset for every provider callback/retry.

All three use the nested-operation bridge for session/parent/child accounting and enter `running` only when a provider starts. Stable callbacks prevent a later poll from losing callback evidence. Cancellation releases queued work and revokes callback/result authority while already started requests drain. A write committed before cancellation stays committed and charged; it cannot rebind the session or report a gameplay grant afterward. A complete A1/M1 remains available for a later explicit resume.

## Evidence

The final full cohort passes **217320 fixed checks /84 named groups /0**:213918 preceding,2980 commit/pipeline and422 Free/Easy Runtime profile checks. The46-target overlay (45 distinct sources, including two facade mounts) compiles and the complete production overlay is strict-clean. `commit-qualified-1`, the unchanged successful `commit-types-development-1` receipts, and `verify-commit.py` bind exact source, bundles, mounted code and output. `commit-verification.json` records scope and committed candidate identity. The earlier development runtime lacks the last queued-lease and profile cases.

Main cases cover raw/compressed originals and both archive policies, initial capacity denial, exact raw target storage, deferred readback, ambiguous committed M1/R/P writes, root cap/deadline cleanup, cancellation during an actually suspended committed raw write, exact M1/A1 reuse on resume, foreign final leases, changed deferred rebind witnesses and a foreign owner introduced during a queued final lease. Parent/global/provider counters are checked throughout. Ordinary writes remain barred by the held baseline on refusal/cancellation. The resume does not update A1 or M1.

The separate Free/Easy cases use the real Runtime, production session/baseline/intent objects and actual authored checkpoint fixture. They discover through the existing path, then import debt and supply the typed lane at a quiescent offered-to-accepted boundary. The recovery pipeline runs with all converted children and stops at `entry_required`; it does not run the still-unconverted post-entry save factory. They verify physical slot/target, counter agreement, archive completion and absence of a credential. This is additional mode coverage, not an installed service factory.

In the fixed-clock Main fixtures, the standard archive reconstruction path performs52 requests and the explicitly selected read-only complete-archive path performs43, for both encodings. Those are synthetic request counts. They do **not** measure native/player loading speed; no current code enables these policies in the normal engine.

## Remaining work

Convert recovered current-rest/progress reconciliation/save-loop, New/retirement and departure paths. Then cover synchronous initial load, failed/cancelled constructors, removal/shutdown and replacement epochs with one service-owned physical-account gate. Retire the old startup lane, import complete unknown debt once and prevent any untyped provider from bypassing the new route. The normal Runtime still does not provide a lane, and no cooperative service driver is installed.

Keep per-key timing/backoff, archive originals, fresh witnesses, source/lease/transform guards, stored acknowledgements and actual client holds. Qualify the complete service with multiple actors and real lifetimes before a bounded cooperative driver and real-clock native attribution. Isolated real-store leave/rejoin, actual lifecycle/input/audio/device/sustained-performance and release gates remain required. Production source and its existing Windows/Linux gates are unchanged; do not infer native or online coverage from this memory-backed CLI cohort.
