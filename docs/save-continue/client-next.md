# Current status: game/menu connected

Source ac898f4 now supplies the actual validator/copy/restore callbacks and menu choices. The earlier next-step design below is retained as the contract, not a statement that every bullet is still unimplemented. Current results and remaining cost/native/network/full gates are in README.md and menu-ready/.

# Next: client protocol and controller integration

The server and opt-in SaveClient receiver/queue are implemented and tested. Actual SpiderClient still uses legacy protocol2. Source da111f7 adds the helper and scripted integration; the controller/menu is next. Do not change the game's preference to OFFER_PROTOCOL3 until the receiver, queue, callbacks and menu flow below are complete. Current runtime XML/BuildInfo still belong to the older release snapshot.

## Wire contract now implemented

Hello v1/v2 retains the old shape. Hello v3 enables bound offers/credentials; an established entry cannot downgrade or upgrade by sending another hello. Other messages before compatible hello are refused. Unsupported unnegotiated peers release only an owned lease and cannot keep renewing it. Offers are read with the existing budget, one eligible request per step; refresh_offer is rate limited and only queues work.

- loaded v3 contains progress, status/reason, protected slots, offers and decision snapshots. It contains no ordinary rests/lives write credentials.
- Every v3 reply has one epoch and an increasing sequence. Per-slot offer: kind=offer, mode, offer={id,record,protected}, or nil to withdraw. A primary retirement marker is an observable nonplayable value: Continue is forbidden, but an explicit New can bind its id.
- life_intent: intent=continue/new, mode, serial, offerId. Continue requires an actual displayed playable offer. New without offerId means physically missing only. Never retroactively bind an earlier local choice to a later offer.
- decision: decision={mode,kind,serial,offerId,revision,state,reason,credential,life}. Read-only/changed have no credential. Continue grants only after unchanged ownership revalidation. New grants only after durable retirement. Ownership loss revokes the credential; recovery issues a fresh one. A matching new grant must not restore the world a second time.
- rest v3: mode, record, life, serial, credential, restSerial. Each restSerial denotes one immutable candidate for the current grant. Duplicate queued tickets do not replace contents. Older uncommitted tickets cannot overwrite newer ones. A stored older retry may learn the latest stored ticket.
- stored: mode, serial, credential, restSerial, confirming actual durable/idempotent completion. Do not clear a newer queued candidate because an older ticket was stored. A lost/throttled reply can be retried without rewriting the backup.
- refused: the same identifying fields plus reason=invalid_checkpoint. Stop retrying only that offending ticket, not a later valid one.

## Receiver ordering: do not discard independent channels globally

One global last-sequence filter is insufficient. Example: status3 says ownership was lost, offer4 arrives first, and status3 arrives later. Dropping status3 because sequence4 was observed would retain a misleading Saved status. Use per-channel/per-slot watermarks and per-intent serial/revision guards; keep the epoch fixed to the established connection.

A loaded snapshot can provide floors for the status, offer and decision state that it actually includes. It does not include checkpoint receipts: do not discard an older stored/refused packet solely because a newer loaded packet arrived. Those packets must match the current intent, credential and known immutable ticket. Refuse unknown ticket numbers beyond what this client issued.

Bound pre-handshake buffering: offers/decisions may arrive before their loaded reply in a scripted/reordered delivery. Retain only the bounded latest needed entries; apply matching-epoch buffered events after establishing the loaded snapshot. Never let an unrelated epoch restore permission. Commit internal receiver state before invoking consumer callbacks; callbacks can be reentrant in the test transport.

## Client ownership and queues

Keep the selected private record separate from the latest offer. Validate/bound records and copy at callback boundaries. Only explicit user selection can restore a different rest. Apply a Continue restoration once per local intent; duplicate/read-only/recovered-writable decisions update save permission without rewinding gameplay.

Use one increasing local intent history per slot shared by New and Continue, plus monotonic immutable checkpoint tickets. On ownership loss hold the latest local candidate and clear its credential. After a fresh grant, resend the latest immutable candidate with the new credential; old acknowledgements must not clear it. Drop remote queues from a superseded intent while preserving the player's current local world/rests until they deliberately choose another life.

Retry unconfirmed tickets with a fair bounded sender matching server rest rate limits. Saved requires the current grant and storage confirmation for the latest outstanding ticket; sending a packet or receiving a generic Saved status is insufficient. Permanent refusal applies only to its ticket. Repeated unresolved validation is surfaced as saving/write_failed by the server, rather than falsely Saved.

Newer client with an older server must not pretend offer-bound revalidation exists. A safe fallback is temporary continuation from received legacy rests with rest/retirement writes disabled, while notebook progress can retain the existing bounded merge path. Give an accurate menu/save notice and do not silently retire an unseen legacy rest. Older clients talking to the new server keep their existing protocol2 route.

## Game integration and validation

The separate Client/SaveContinuation helper now keeps the legacy path readable. Inject actual checkpoint validation/copy functions instead of adding unbounded startup waits for shared modules. Then add protocol3 preference in SpiderClient only when callbacks and UI are ready. Controller/menu edits were already announced to Nathan; fly, feeding and settings remain outside scope.

Offer arrival may refresh menu choices, but must not recursively issue another refresh RPC from that refresh callback. Request refresh on deliberate menu opening/action; render-only updates remain local. Continue without saving loads the explicitly accepted snapshot. Changed recovery offers a confirmed choice to load the newer rest or keep this spider temporary. It must not auto-restore from loaded/offer callbacks once play has begun.

Required tests include delivery permutations/duplicates across all channels, old epochs, local supersession during callback reentrancy, immutable ticket retries/coalescing/refusals, throttling, lost storage replies, all modes/Easy unlock, older peer fallback, menu selection and one-time restoration through the real controller. Native engine/online rejoin, representative preserve-record copy/network cost and the broader audit remain distinct unverified gates. Do not claim A06 complete after only the server milestone.

## Current adapter API

Supply SaveClient.new cfg.continuation={copy,validate,onOffer,onDecision,onRestore} only after the game/menu is ready. validate(mode,record,allowRetired) must bound/check ordinary checkpoints and allow only a valid retirement marker when allowRetired is true. beginLife(mode,displayedOfferId) deliberately binds New; omitted id means physically missing only, never auto-latest. continueLife(mode,displayedOfferId) restores through onRestore immediately once after committing the choice. offer returns a private copy; refreshOffer queues bounded work. sendRest holds a private immutable candidate until a matching stored/refused response. Consumer restoration failures and menu confirmation still need game-level handling. Older-peer temporary fallback currently uses offline wording; refine it accurately in SaveText during menu integration.
