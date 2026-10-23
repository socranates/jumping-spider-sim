# Protected New Life policy - private qualification

This directory tests a server policy for explicitly starting over when the selected save is protected by the legacy recovery rules. It is not installed in the ordinary game. The actual game menu still labels that choice as without saving; changing that label requires the complete application and server integration, not just this backend worker.

Qualified result: **32 groups /211595 fixed checks /0**, including **6695 protected-New checks** (`qualified-full-2`). All41 candidates compile and the complete overlay is strict-clean (`qualified-types-2`). All prior31 named groups retain their previous fixed totals; timing-dependent application read invariants are reported separately (192 in this run). `verification.json` is independently reconstructed by `verify.py`. The negative cancellation reproduction fails against the preserved old policy; the identical regression passes against the fix.

## Contract

1. Require the exact displayed observation and a real readonly **New** intent in a tracked, idle, preaccept session. Continue is not an alias for New. No client checkpoint supplies the retirement source.
2. Hold the existing save owner and physical store. Read the selected raw rest and import proposal without cache. Validate the complete source with cooperative preparation, including an explicitly observed schema3 retired source.
3. For a legacy source, write or reuse the complete original A1 archive through the existing guarded archive controller. For an already imported source, retain its verified A1/M1. Never substitute a later checkpoint or retirement marker for the original.
4. Preserve and verify local progress through the existing three-way progress worker. Re-read all five archive parts and the selected M1 before retirement. A missing or changed proof refuses the operation.
5. Compare-and-swap only the selected R to a normal schema2 retirement marker. Require the exact source bytes or the identical idempotent candidate. Read back without cache after either a success or a timeout; a concurrent R change is never overwritten.
6. The result grants no gameplay authority. Use the existing paused, acknowledged replacement protocol to close the old owner and retain final client progress. The fresh epoch observes the ordinary retired marker, then an explicit current-epoch New choice receives the real credential and can store a normal checkpoint.

Only the selected R is retired. Sibling rests, A1 originals and existing M1 proposals remain unchanged. An enforced hold never enables ordinary snapshot writes. The policy uses the same rolling request scheduler as other save work, with at most one provider call per service step. Preparation has the existing cooperative work bounds; pending policy work is additionally capped at 96 charged requests and 900 synthetic seconds. A refused/cancelled operation may maintain only its still-owned P lease while awaiting safe session replacement. That maintenance is separate from pending transaction work and cannot renew a foreign lease.

## Integration fixes

- The shared session fence can explicitly capture New; its default remains Continue. The archive controller passes that intent through rather than inventing a Continue or credential.
- The private profile owner publishes already-validated ordinary rests and retirement markers even when another slot holds background discovery in an offered state. Publication remains an observation, not permission to play or save.
- An explicit protected New binds its selected profile and stops optional background discovery. It retains the displayed source instead of launching a Continue read that cannot understand an interrupted retirement.
- The policy replaces the private runtime pipeline only inside its admitted session. Existing departure drains real outstanding provider work before releasing ownership. Refusal retains a closed write path and does not claim that a missing durability proof was verified.
- Replacement captures its final client progress through the explicit guarded preparation method even when ordinary intake is closed. It does not reopen general progress or checkpoint traffic.
- Cancellation revokes the exact retirement callback fence, including when the underlying write provider has yielded. A preserved pre-fix module and the same before/after regression reproduce the old failure and verify that it is fixed. A cancellation after an already completed write cannot undo that write; the session still requires a verified replacement rather than resuming the old life.

## Evidence and reproduction

Run `run.py <unique-prefix> --focused` for the new policy checks plus the earlier shared setup checks. Run without `--focused` for the complete prior application/replacement/recovery cohort and the new group. `check.py <unique-prefix>` compiles 41 candidates and analyzes their full production overlay. Both runners preserve prior output and hash inputs before and after execution. `verify.py` reconstructs the qualified bundle, binds production bytes to the committed source, and checks results and type logs.

The tests use the real SaveService, SaveSession, SaveClient and replacement adapters with a memory backend and synthetic time. They include all three slots, normal stored acknowledgements after replacement, current and retired imported sources, lost write acknowledgements, concurrent R changes, missing A1/changed M1, superseded intents, cancellation, account/provider/load/lease changes, request/deadline caps, final progress and an actually suspended provider read. This is not native Roblox networking, real DataStore leave/rejoin, player input, audio or performance evidence.

Earlier development failures are retained under their original prefixes. Only the exact receipts accepted by `verify.py` qualify current bytes. The earlier application receipt in `docs/recovery-application` remains historical after these private adapters changed. Default production platform results are verified separately by `docs/recovery-application/verify-default-platforms.py`.

## Next

Connect an optional trusted policy factory to the private service and application flow. Keep the current world paused, send final progress before intake closes, report bounded progress/errors, and obtain verified owner closure before any new world reset or fresh choice. Add a deliberate New-only discovery path for persisted schema3 retirement markers; never expose one as Continue. Then exercise the actual menus over real RemoteEvents in an unbound memory-backed Studio fixture. Normal recovery activation, online-store verification and publication remain separate gates.
