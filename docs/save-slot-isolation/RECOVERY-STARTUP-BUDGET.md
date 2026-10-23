# Private recovery startup request budget

The returning-session path previously spent its ten-request gameplay allowance while proving the original archive and current checkpoint. This imposed a rolling-window wait even on a server with available Roblox budgets. This optional server owner supplies a bounded initial recovery allowance without removing any archive, lease, selection, client-apply or final-entry proof. It is not connected to production SaveService or the remote/menu flow.

## Installation and policy

Create one `RecoveryStartupBudgetPrototype.engine(serverClock)` per server and pass it as `recovery.startupBudget` to the private Runtime factory. Share that owner across users; creating an owner per player would defeat the shared cap. Runtime attaches it once before the first Session load and records `loading` around that load. Existing callers without the option retain their previous behavior.

The allowance admits at most 20 requests per initial session and 40 across that server in a rolling minute, expires after 45 seconds, and permits only one burst per user per rolling minute from its first spend. A ticket binds the actual session, scheduler, provider, user/key, intent owner, first load epoch and Runtime. It refuses clock reversal, replacement, departure, scope changes and already-writable lives. Observer calls never occur inside a cooperative SaveWork pulse.

Before every accelerated admission, both `StandardRead` and `StandardWrite` observations must have at least five requests remaining. Each admission conservatively debits one from both, retaining four of each. The shared observer caches for at most 0.25 seconds and deducts its own admissions. A missing API, thrown error, invalid number or yielding observer refuses acceleration. The engine observer only calls `GetRequestBudgetForRequestType`; it never accesses a datastore record, changes permissions or changes platform rate limits.

The scheduler's actual rolling request history remains intact. Startup requests are accounted in a separate bounded lane. Only verified playable entry closes that lane successfully; ordinary gameplay then has its existing ten-request allowance, debounce and checkpoint interval. Failed, cancelled, expired or dismissed startup transfers its spent requests into ordinary debt. While a ticket remains active but acceleration is unavailable, admission falls back to the original raw-history limit, so an exhausted startup loan cannot silently gain a second ordinary allowance. Existing initial-load/closed-flush forced requests remain the preceding scheduler exception, are counted separately, and do not occur in the healthy recovery fixture.

The observer is advisory. Another Roblox caller can spend budget after a sample, platform experience/key throughput limits still apply, and datastore calls can throttle or fail. This owner neither reserves native capacity atomically nor changes request retries or storage authority. Use one shared owner and retain all provider failure handling.

## Verification

`startup-attempt-2-*` is the current complete private cohort: 1,382 startup assertions plus 127,465 preceding assertions, 128,847 passing and zero failures. `startup-types-2-*` compiles the entry and checks all 33 candidate modules with a clean full strict pass. `verify-recovery-startup-budget.py` binds current sources, assembled test bundle, outputs and type receipts to their hashes. The prior rejoin verifier is historical because Runtime has changed; the current startup verifier includes its entire regression cohort.

| Deterministic case | Requests through entry | Simulated seconds | Startup requests |
| --- | ---: | ---: | ---: |
| Healthy budget | 19 | 17 | 19 |
| Low budget | 20 | 72 | 0 |
| Unknown budget | 20 | 72 | 0 |

The healthy case covers actual private factory load, discovery, entry proof/client apply, post-entry P/R saving and departure. The table measures entry, not the entire subsequent save/departure sequence. Earlier six returning-session fixtures without this option still pass at 20 requests/72 simulated seconds. These are deterministic model timings, not measured player loading times. The extra failed attempt is retained: a test incorrectly required an expired fallback ticket to report startup success, though entry recovered correctly; the final test checks successful loan closure only in the healthy case.

The installed Studio engine `0.744.0.7441077` also ran the exact current observer in an isolated, unbound local model (GameId and PlaceId both zero). Six assertions passed: modern enums resolve, both budgets are finite/nonnegative, and the observer returns without yielding. It reported 580 read/580 write at that instant. This is not the live game's budget or an online save test. The model includes only SaveRules, SaveWork, the budget module and its read-only probe. `startup-native-observer-build.json`, `startup-native-observer-output.txt` and `startup-native-observer-receipt.json` retain the hashes and filtered native result. Studio was stopped and closed; a separate editor copy preserves incidental local editor changes without changing the hashed original model.

## Remaining work

Production service/client/remotes/menu integration, real datastore recovery and full native rejoin remain open. Explicit retirement/New Life, later-slot archive reuse/lifetime, safe session replacement and current-backup recovery policy remain open. Post-entry proof-heavy saves can still exceed the ordinary ten-request window; this change does not qualify their latency. No published game or normal player save has been changed by this private milestone.

API references: [budget observer](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetRequestBudgetForRequestType), [datastore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits).


## Subsequent retirement milestone

Runtime/Writer/Loop now also implement the private durable retirement path in `RECOVERY-RETIREMENT.md`. Use `verify-recovery-retirement.py` for the current complete cohort and hashes (146100 checks). Startup attempt/type receipts above bind their historical source bytes; the unchanged observer retains its narrow component proof.
