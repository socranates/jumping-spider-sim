# Persistent saves (DataStore) - 2026-10-17

Branch `claude/roblox-state` from main 2e36716. Decisions ROBLOX-39 to ROBLOX-46 in `DECISIONS.md`. Nothing here is published; the places were rebuilt and nothing has been run against a real DataStore yet (see Chet's checklist).

## What was built

- **Two records**, saved separately: PlayerProgress (notebook pages and eye time, To-try checklist, Easy unlock / adulthood reached, appearance, preferences) and WorldRests (last rest of Standard/main and of Free play).
- **Pure, CLI-tested modules** in `src/Shared/Persistence/`: `SaveEnvelope` (versioned envelope, FNV checksum over canonical JSON, one backup, migration table, lock), `SaveProgress` (default, sanitize, monotonic merge), `SaveRest` (bounded structure check, `Checkpoint.check` against a stub world), `SaveStores` (store name rule, DataStore error classes), `SaveScheduler` (dirty flags, debounce, backoff, request budget, heartbeat), `SaveSession` (the whole per-player state machine), `MemoryBackend` (in-memory store with injectable faults). Numbers and names: `src/Shared/Data/SaveRules.luau`.
- **Server**: `DataStoreBackend.luau` (thin, the only file that calls DataStoreService), `SaveService.luau` (validated remotes, rate limits, per-player sessions, heartbeat, leave and shutdown flush), `Persistence.server.luau` (starts it).
- **Client**: `SaveClient.luau` (hello, status, send only what changed), `UI/SaveText.luau` (the plain words), wiring in `SpiderClient.client.luau`: the start menu waits for the server's first reply, saved notebook and choices are applied before the menu, the menu shows "saved / saving / trouble / off and why", and a short toast announces changes.
- **Studio**: `tests/studio/StateSpec.luau` (+ `StateFixture.luau`, real captured rests) run by the Runner; checks that need DataStore access report as `not_run`/skipped in the report instead of passing.

Server owns all DataStore access. The simulation is still client-side, so the server validates shape and consistency (corruption safety), not truth. It is not anti-cheat: a solo game with no economy.

## Measured sizes

Measured from real rests produced by the checkpoint code (JSON of the envelope):

| Record | Size |
|---|---|
| Rest, early in a life | about 21.6 KB |
| Rest, long-life plateau | about 64 KB (grows with caught prey/ledger and old skins, then stops) |
| Progress, full notebook | about 1 KB |
| Cap for a rest | 262,144 characters (4x the plateau; 1/16 of the 4,194,304 DataStore limit) |
| Cap for progress | 16,384 characters |

Server CPU at 64 KB, CLI Luau: rest check about 15 ms, envelope open 33 to 68 ms. A rest is written at most once per 10 s and the check runs once per accepted message, so this is acceptable; Roblox's own Luau will differ (not measured).

## Evidence (CLI, Windows VM luau)

STATE 380, STATE_CLIENT 95, STATE_OFFLINE 8, all failed=0. The earlier baseline of 46,152 accepted checks is unchanged in every old suite (CHECKPOINT 156, CONTINUING 87, EYES 231, FLIES 187, GAZE 67, GROWTH 433, HUD 69, LIFE 20,846, LOOK 102, NOTEBOOK 889, PEACOCK 80, PERCEPTION 4,669, PERCEPTION_CLIENT 1, PRESENTATION 11, PREY 1,549, SENSOR 507, WASP 15,815, WORLD 230, SUMMARY 185, BOXWORLD 15, CLIENT 23). New total 46,635. `check.sh types` 0 diagnostics; `check.sh compile` 165/165 (was 142). Places rebuilt (`tools/build.py`); `BuildInfo.luau` restamped.

What the STATE suite covers: envelope open for every status, forward migration (and a regression that a migration cannot corrupt the stored copy), the lock (fresh, stale takeover, lost lock), monotonic merge under random operations with faults and two sessions (stored progress only ever grows, every stored value is a good save, nothing raises), a failed load never writing defaults, newer and corrupt records left byte for byte, write retry/backoff and the request budget, leave and shutdown flush, the server's rest check against damaged and hostile payloads, size caps, rate limits, store name rules, error classification. STATE_CLIENT drives the real client scripts against the real service and in-memory store: leave and rejoin, a real captured rest passing the server check, menu waiting and toasts. STATE_OFFLINE: no server at all.

## Chet's Studio checklist

1. Open the **test** place (`TheWindowsillTests.rbxlx`), save it to Roblox (File > Save to Roblox). Game Settings > Security > turn on **Enable Studio Access to API Services**. The test place must not be the production place.
2. Press Play (not Run) and read Workspace attribute **SaveStoreName**: it must be `WindowsillTest_v1`. If it says `Windowsill_v1`, stop.
3. Run the Runner. In the report (`not_run` and `skipped` lists) the state checks that need DataStore are named; with API access on there should be none skipped. Look at:
   - "a real DataStore round trip": save, leave, rejoin, rest and progress separate, the lock holds a second session out. This also confirms that numbers (times, floats) come back **exactly** after DataStore's JSON; the design assumes lossless doubles. If the checksum check fails here, that assumption is wrong: tell Claude.
   - "real DataStore error messages are classed as 'value'": the message patterns in `SaveStores.classify` are from Roblox's documented codes and are unverified against a live store. Paste any real message that falls in the wrong class.
4. Turn API access off and run again: the game must start, show "Saving is off for this visit..." with "Saving is not available here.", and the Runner's DataStore checks must show as skipped, not passed.
5. Run the default project (not the test project) in Studio with API access on: it uses the test store too. Rest in the crack, stop, press Play again, confirm "Back to your last rest" and the notebook pages. Test keys in the test place include a per-run tag, so repeat runs do not see each other.
6. Do **not** point Studio at `Windowsill_v1`. Publishing is a separate decision for Nathan: use the existing flow in the notebook handoff (Rojo sync of `default.project.json`, ordinary Publish).

## What Nathan should check (after Chet publishes)

Play, open the notebook and find a page, rest in the crack. Leave the game, join again. The menu should say your notebook and last rests are saved; the page is still there; "Back to your last rest" works; Free play keeps its own rest. Also: join from a second device while the first is open; the second copy should say plainly that the game is open elsewhere.

## Deliberately simplified or unverified

- No server copy of the simulation: stored rests are checked for shape and consistency only.
- One level of backup; corrupt or newer records are never repaired or overwritten (left for a person to look at).
- A rejected client message is dropped with no reply.
- Real DataStore behaviour (lossless numbers, error message wording, throttle limits, the cost of the transform in Roblox's Luau) is untested until Studio.
- The progress record has no deaths or lives history.
- A new life replaces the last rest only when the new spider first rests.
- `tests/state_client.luau` uses the Workspace attribute `SaveWait` to switch the menu wait on in the test place.
- The captured test fixture (`tests/studio/StateFixture.luau`) must be regenerated if the checkpoint format changes (the STATE suite has a structure check that fails when it goes stale).

## Commits

656db41 (model, envelope, session, scheduler, STATE), 4b67dd7 (server wiring), 778dac0 (client wiring), 9e8b814 (test-place keys, Studio spec), plus the docs and rebuilt places commit.
