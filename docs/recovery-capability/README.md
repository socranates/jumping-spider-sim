# Explicit recovery negotiation and client transport

This step moves the optional recovery wire path into the real SaveClient rather than a test listener around it. It still does not install recovery in `Persistence.server.luau` or configure the actual SpiderClient menu. Older peers and ordinary supported saves retain their existing paths.

## Contract

Protocol 3 does not imply recovery support. A server accepts `hello.recovery = 1` only when its installed owner exposes both `enableRecovery` and `applyRecovery`. The first compatible hello freezes this decision for that session and loaded snapshots echo it. Entry emission and receipt intake require this agreement. Malformed, missing and future capability values do not enable recovery. Duplicate hellos cannot upgrade an old peer, disable active recovery or repeat activation.

SaveClient advertises support only through an explicit configuration with both `recovery.onSelected(mode, serial)` and `recovery.onEntry(offer, epoch, sequence)` callbacks plus normal continuation support. The first valid matching loaded handshake freezes the client agreement before its loaded callback. New clients do not infer support from an old server's protocol 3.

For a protected selected offer, the negotiated continuation calls `onSelected` without copying or retaining another legacy checkpoint for restoration. Normal offers and older peers keep the original restoration callback. The original validated offer is still retained as immutable selection evidence; the optimization removes the two additional copies during protected choice, not that evidence. A copy-counter regression pins this behavior.

Entry delivery requires a current explicit protected Continue, active mode, request identity, epoch, bounded header and a fresh sequence. The callback must validate/prepare the entire checkpoint, keep the game paused, rebind its real state and cache a successful receipt so resends do not apply twice. `sendRecoveryApplied` requires the same current selection and entry identity, and constructs only the bounded receipt shape. It does not grant permission or prove a durable save. Choosing another life, cancelling or superseding a selection prevents its late entries and receipts; reentrant callbacks cannot restore the outer choice's active slot.

The private owner enables discovery only after the service calls `enableRecovery`, separately from normal `enableOffers`. Its fixture now uses these actual SaveClient callbacks and receipt method for all three modes, with no recovery handling in an outer listener. Old offer clients are also exercised against the actual private owner: no discovery, archive/proposal publication or recovery activation occurs even after a later advertising hello and an unobserved intent.

## Verification status

The retained `focused-*` outputs are preliminary targeted runs before the source commit, not full production passes. The final targeted continuation run has 257 passing checks; the state run has 1,488. Private `capability-focused-*` outputs are focused cohorts, never complete recovery runs. Focused 2 caught a test mistake: Runtime initializes `accepted` to false, not nil; the assertion now checks that recovery was not accepted.

Full source-bound production and complete private gates will be recorded separately. The earlier `save-service-owner-final/` and `recovery-service-owner-verification.json` belong to source2170f99 and are historical for this change. Do not claim whole-game native recovery, online datastore, physical-device behavior or release from these transport checks.

## Remaining adoption work

Implement actual mode-specific destination profiles and the SpiderClient menu callbacks using its normal restore/model/store rebinding machinery. Keep simulation paused until the matching real writable decision and handle preparation failure, cancellation, timeout and grant loss. Add explicit session replacement/epoch handoff; the service still refuses silent session replacement. Measure and bound entry payload/resend costs. Then perform native full-lifecycle, isolated online rejoin, device/performance and release verification before enabling the owner in engine startup. The broader reliability/optimization goal remains active.
