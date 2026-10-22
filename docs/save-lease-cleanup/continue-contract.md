# A06: read-only Continue contract

Source reviewed: `e315b3a048fddd1729461fb92502f73b7d8e2b94`. This is the implementation contract for the remaining feature, not a claim that the feature exists. Runtime/default tests remain frozen while Windows31770 runs.

## Current evidence and the missing boundary

SaveSession.load reads rests only after acquiring the progress lease. Its locked branch merges readable notebook progress but does not read the leased rest. SaveService.loadedMessage exposes snapshot.rests and snapshot.lives. SaveClient.receive accepts those life tokens as credentials; its pending New Life request prevents old loaded tokens from replacing a newer intent. SpiderClient.adoptRest declines to replace a life already begun or an existing local rest. Menu Continue restores from the selected local store immediately.

Therefore adding a read in the locked branch and publishing its tokens would conflate viewing a snapshot with permission to upload future rests. Passing a later loaded message through the current adoption guard also cannot implement a player choosing a newly discovered rest after starting a temporary life. A separate offer/intent boundary is required on both server and client.

## Player behavior

When a valid rest is available but another session owns saving, the menu offers **Continue without saving** for that specific rest. Explain the temporary status in the menu and existing save-failure notice; add no persistent gameplay HUD. The player can keep exploring immediately. Their local checkpoints work for the visit and are retained while saving is unavailable.

Ownership recovery must not silently load a different world or authorize a different life. If the stored rest is unchanged, the accepted continuation may become writable after server revalidation and acknowledgement. If it changed or was retired, keep the played life temporary. Offer an explicit menu choice to load the newly offered rest or keep this visit temporary; do not replace the running simulation automatically. Selecting a newer rest discards local visit progress only after a clear confirmation.

Normal/Easy/Free remain separate slots. Easy's existing unlock still applies. An unknown/newer/corrupt primary remains protected. A readable backup may be continued temporarily under that protection, but cannot implicitly authorize overwriting the primary. A checkpoint from an unsupported habitat must remain preserved and unavailable to restore until the separate lossless migration requirement is implemented.

## Authority and messages

1. **Offer:** A server-owned immutable observation contains slot, a bounded opaque offer id, the validated record, source kind (current/backup), life identity, raw envelope checksum and updatedAt, plus protection/write eligibility. Viewing it grants no write credential. Missing, invalid or unsupported records grant no writable offer. Do not transmit life tokens as a substitute for this distinction.
2. **Explicit intent:** Continue sends slot, increasing client intent serial and the displayed offer id. New Life confirmation must bind to the displayed observation too when it proposes retiring that rest. Neither request can bind retroactively to whatever a later backend read happens to discover.
3. **Decision:** The server replies for that exact slot/serial/offer with a monotonic decision revision and state: read-only, writable, or changed/refused. Only a writable acknowledgement carries a credential accepted for future rest submissions. Retrying the same intent is idempotent. A new intent supersedes earlier decisions; bounded serial/token validation and existing per-player rate limits remain mandatory.
4. **Recovery:** After acquiring the lease, reread and validate the selected stored value. Compare the full observed identity, including checksum and source kind, rather than only updatedAt or a possibly nil legacy life token. Only an unchanged, unprotected current rest can promote the accepted continuation. A changed record produces a new offer requiring a new explicit choice; it never rebases queued local rests or retirement markers. Use owned-lock cleanup when refusing a recovered conflict.
5. **Rest write:** Require the acknowledged continuation/new-life credential and current life identity. Preserve write-time revision checks inside every atomic callback. No queued read-only rest may cross a changed decision, new intent or retired life boundary. Notebook union/progress merging is separate from permission to replace an ecology checkpoint.

Offer ids and serials are corruption-safety boundaries for this player's session, not an anti-cheat claim. SaveService continues routing exclusively through the authenticated player entry. Never trust a client-supplied checksum or session name as proof that the server offered a record.

## Ordering, ownership and cost

Keep preview records separate from the owned rest base/revision and from client write credentials. A preview read must not set restLoaded or silently change the base used by an older queued intent. Keep one current offer per slot plus an accepted immutable observation if needed; discard superseded unselected offers. Do not retain unbounded whole-world copies. Copy at transport/callback boundaries so a consumer cannot mutate the private accepted observation.

Preview reads must consume the existing request budget, with at most one preview backend request per periodic step, bounded retry/backoff and no repeated three-slot scan on every failed lease retry. A lease-conflict preview is optional on read failure; a failed read cannot manufacture an empty rest or authorize replacing one. Do not add an additional backend ownership heartbeat from the preview path.

Client state needs a separate offer collection and selected intent for each slot. Older loaded/rest/status/decision deliveries must not override a newer selection, credential or writable-to-read-only transition. A message sequence must be assigned with a coherent session snapshot, not to an old snapshot after an unrelated yielding request. The server's busy guard and callback revalidation must cover preview reads as well as normal load/write steps. An accepted read-only life must not be fed through the ordinary unsolicited-rest adoption guard and then assumed to have loaded successfully.

Version the transport capability explicitly. Older clients/servers retain the existing conservative behavior when they do not negotiate offer-bound continuation. Never infer support from a status string, enable writes before acknowledgement, or break existing saved schemas to add transient transport state. Measure large-rest delivery and peak copies with real preserve records before claiming the new flow has an acceptable network/startup cost.

## Required regression matrix

- All three slots: locked preview, read-only Continue, unchanged recovery and acknowledged upload; Easy remains locked when appropriate.
- No writes/retirements/acknowledged credentials from simply viewing an offer, retrying a failed read or receiving loaded/status again.
- Foreign session saves another checkpoint of the same life; equal timestamp with changed checksum; legacy nil life identity; different life; retirement; missing slot; protected primary/readable backup.
- Explicit choice binds the displayed offer even if a later read finishes between click, server handling, lease acquisition and the atomic write callback.
- Permutations and duplicates of old/new offer, loaded, rest, status, read-only decision and writable decision; no stale decision restores permission after it was revoked.
- New Life supersedes Continue; Continue supersedes New Life only through a new deliberate selection; switching slots cannot cross credentials or queued rests.
- New ownership appears during a repeated atomic callback; a lost successful response is retried without duplicate backup/retirement or invented acknowledgement.
- Read-only local checkpoints survive backend failure; changed recovery never uploads them over a foreign revision or silently replaces the played world.
- Preview request budget, throttling, departure during a read, shutdown deadline, cancelled/stale read completion and bounded retained records.
- Older peer capability negotiation, malformed/oversized messages and bounded serial/token rejection.
- Actual menu choices, confirmation, save notices, local restore success/failure and delayed replies through the real controller, not only transport mocks.
- Native synthetic session cases, real online client rejoin, and measured preserve-record network/memory cost are distinct gates. CLI green alone cannot establish those results.

Implement the server offer/decision state and its paired regressions first, then transport and controller/menu integration on a new candidate after the frozen full gate terminates. Notify Nathan before editing menu code, as requested. Do not call A06 complete after only snapshot transport or only lock cleanup.
