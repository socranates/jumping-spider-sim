# Next: opt-in client adoption, then native qualification

The service hook and private transport fixture are a foundation, not a recovery feature enabled in the game. Keep `Persistence.server.luau` on its existing default session until the following gates are met. The immutable original archive and every unselected live slot must remain intact.

## 1. Negotiate recovery explicitly

Add a bounded, versioned recovery capability to the protocol-3 hello and loaded handshake. The server must retain the accepted capability for the current player/session, and echo its decision. Only a client that implements deferred restore and recovery entry may advertise it. Generic protocol 3 alone is insufficient: cached clients already speak protocol 3 but do not implement this transport.

The server must gate entry publication and `recovery_applied` intake on both protocol and this capability. The owner must not discover/accept recovery merely because normal offers were enabled. Old peers retain ordinary supported saves and the existing protected, read-only legacy behavior. Malformed or unsupported capabilities must never enable recovery or access storage. Repeated hellos must not change the agreement after a recovery has begun. Rate limiting for entry receipts stays independent of Continue/refresh retries.

Acceptance cases: old server/new client; new server/old client; supported pair; malformed and future versions; duplicate hellos; reordered loaded/entry; session departure. Prove no unnegotiated recovery I/O, no restored legacy checkpoint, no synthetic writable decision, and no receipt-rate starvation.

## 2. Bind the selected profile and client lifecycle

The current private owner has one destination profile per visit. Supply the actual mode-specific destination template/context selected by the menu, with generation/revision fences. Do not reuse the main profile for Free or Easy. Preserve existing Easy eligibility. A newer menu choice must cancel the old job and fence every delayed callback before another owner can write.

On protected Continue, defer the existing `onRestore`: the observed legacy offer is evidence for consent, not the world to enter. The client waits for the current server entry, validates it using bounded work, and prepares the normal checkpoint restore. Reuse the actual `returnToCheckpoint` and store/model rebinding machinery in `SpiderClient.client.luau`; applying only a detached world table is inadequate. Keep simulation paused during preparation/adoption and until the actual matching writable decision. Only acknowledge after adoption succeeded. Cache a successful receipt per entry identity so resends do not reapply the checkpoint. Validation failure, cancellation, menu replacement, timeout and departure must not acknowledge or resume writes.

Acceptance cases must exercise the actual client loop and its stores, actors, controls, local variables and UI. Cover all three modes; latest progress/settings/rare history; changed selection during yielded validation; repeated entry; failed prepare/apply; delayed or lost receipt/grant; active and retired checkpoints. Preserve the existing local-return and normal Continue paths.

## 3. Make replacement a transport operation

The service currently refuses silent replacement of `owner.session`. Keep that refusal until an explicit handoff updates the service's session reference, epoch, sequence, client state and callbacks together. Drain/close the old owner, preserve pending progress, and verify lease release before creating one fresh owner. A packet from the retired epoch must never revive an old credential or overwrite the new life. The private fresh-life tests alone do not prove this service/client transition.

## 4. Bound the real entry transport cost

Measure plain and compressed current checkpoints at the native remote boundary, including largest supported preserves, and enforce a payload limit. Prefer a bounded resend policy/backoff or receipt/status exchange rather than indefinitely retransmitting a full checkpoint. The private five-second resend is a deterministic test mechanism, not a measured network budget. Keep nonce/revision/identity validation and idempotent client adoption regardless of transport policy.

## 5. Activate only after evidence

After the above code passes targeted adverse-order tests, run the full production suites and strict/compile/runner gates for that exact source. Then exercise whole recovery, checkpoint, quit/rejoin, retirement and new-life replacement in native Roblox. Test real datastore only on explicit isolated synthetic keys; never experiment on the player's originals. Record physical keyboard/controller/touch and frame/network costs separately from shim coverage. Publication needs a verified candidate, synchronized branch, exact receipts and a clear account of remaining limits.

Before editing the menu, tell the user which save/menu integration is about to change. Do not touch fly, feeding or settings behavior as incidental cleanup. The broader reliability/optimization goal remains open until the actual game and release evidence support it.
