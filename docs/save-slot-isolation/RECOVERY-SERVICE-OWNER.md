# Recovery through the actual save service and client transport

The production SaveService now has an optional server-only `ownerFactory(config, emit)` hook. Without that option it still constructs a normal SaveSession. With it, one owner handles load, periodic work, progress/life/checkpoint intake, offer refresh, negotiation, demotion, departure and shutdown. Queries and transport stamps use the owner's actual session. A factory must return an unloaded session with the configured user/server identity and all required methods. An owner cannot silently replace that session; a future replacement requires an explicit transport handoff.

`emit` accepts only a recovery-entry packet, only for the current registered player after loaded protocol-3 negotiation and before departure. SaveService adds its own sequence and epoch. `recovery_applied` receipts are forwarded only to an installed owner after negotiation. The owner still performs the bounded exact nonce/epoch/slot/request/revision/identity checks; transport delivery is not a grant.

## Receipt starvation found and fixed

The first hook used the life-intent bucket for receipts too. The stronger reentrant-delivery test exposed a real starvation case: periodic readonly Continue retries consumed the available token whenever the server resent its entry offer. Valid receipts were repeatedly rate limited; the entry timed out and prepared another nonce. A queued manual receipt had hidden this timing problem.

Recovery receipts now have their own bucket with the existing life burst/rate limits. Intent/refresh traffic cannot spend it. Strict receipt validation and the one-time entry transition remain unchanged; accepting a receipt performs no datastore call itself. The production state suite explicitly exhausts the intent bucket and verifies that a receipt reaches the owner without consuming intent capacity. The transport case requires exactly one client apply despite entry resends and a reentrant successful receipt.

The generic hook was committed as `927e816`; the starvation fix and additional production regression are `2170f99`. The earlier CI/evidence directory is historical. Current production gates belong to `docs/save-service-owner-final/` and the exact committed source `2170f99e001c4c0a42e86454974f594820e86667`.

## Private adapter and test client

`RecoveryServiceOwnerPrototype` binds the qualified private Runtime to this hook. It discovers the configured protected slot, routes the actual displayed Continue into recovery, creates entry only after durable recovery/rejoin proof, and resends the same entry offer while awaiting its receipt. Ordinary checkpoints for a recovered credential go through the single authenticated save owner. The adapter stamps authoritative root life metadata, as normal Session intake does; the wire client supplies an ordinary captured checkpoint without that server token. Later choices revoke the old recovery fence and keep unsafe writes held. All work stays under the Runtime's worker/lease/request/deadline rules.

The test uses the real SaveClient, SaveContinuation and SaveService. Its explicit client configuration validates legacy observations without restoring them, defers the original `onRestore`, then uses `RecoveryEntryClientPrototype` to prepare/apply the server's current checkpoint. It caches the resulting receipt for a repeated entry ID and waits for the actual final server decision. It does not manually grant the server intent. The production datastore, raw and compression adapters run over the fault-injected memory facade.

The current complete cohort passes 2,745 service-owner assertions plus 184,404 preceding assertions, 187,149 total. Entry compilation and full strict analysis of all 34 private candidates pass in `service-owner-types-3-*`. Current full output is `service-owner-attempt-4-*`; `verify-recovery-service-owner.py` binds current sources, bundle, output and type hashes. All three modes cover actual entry/grant, checkpoint and stored receipt, original preservation, removal or shutdown. Invalid, pre-handshake and departed-player receipts do not access storage. Free uses reentrant entry delivery and receipt return; Easy uses actual service shutdown.

Attempt 1 mistakenly treated the expected legacy-world diagnostic as a service exception; the test now distinguishes normal validation logs from caught errors. Attempt 2 passed the queued-receipt path. Attempt 3 and focused diagnostics exposed starvation under reentrant receipt timing. Focused 3 and full attempt 4 pass after the separate bucket fix. Focused runs deliberately omit several preceding named check functions and are never reported as full-cohort results.

## Activation gates still open

Do not install the prototype in live engine startup yet. The committed engine script does not configure `ownerFactory`; no published game or normal player save has changed.

- The current adapter is bound to one recovery-slot destination profile for a visit. The actual menu must supply and fence the selected profile, including mode-specific template/context preparation and stale-menu handling.
- The test supplies deferred restore/entry callbacks. SpiderClient's real menu, simulation pause, model adoption, error/cancellation handling and post-grant resume must be wired and exercised. World-table application alone is not proof of the actual game loop.
- Explicit recovery capability negotiation is needed before enabling new entry transport for cached/older protocol-3 clients.
- Fresh-life session replacement works privately, but service/client epoch switching is not installed. The hook deliberately rejects silent owner-session replacement. Later choices remain held rather than falling back to unsafe normal writes.
- Entry payload size, retransmission cadence and native network costs must be measured/bounded before activation; the model resend interval is not a qualified production bandwidth budget.
- Full engine-native lifecycle/compression/remotes, real online datastore/rejoin and release checks remain open. The unchanged budget observer's narrow native proof does not cover this service path.

The production source's full Windows and Linux gates are separate from the private cohort. Inspect their terminal receipts before claiming a full production pass. The broader optimization/reliability goal remains active.
