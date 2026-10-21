# Notebook integration and public-release preparation — 2026-10-17

Claude completed `claude/roblox-notebook` at 657ce9d from 31e32b9 while Chet independently built the notebook at 77ca385. Both are reconciled into this round. Consult `verification/roblox-notebook/merged/RESULTS.md` for final checks and publication. The earlier results describe the superseded reader, not the combined build.

**Published v18**, confirmed in Studio and Creator Dashboard. Evidence **3525b7b58f9afc70**: engine **98/98**, live client **23/23**, CLI **46,152**, strict clean and **142/142** compile. Physical PlayStation/tablet acceptance is pending Nathan's playtest.

## What ships

- Claude's validated page model, real-event watcher, responsive found-page list and reader, separate HUD discovery notices, keyboard N, touch Notebook button, controller menu entry, end-screen entry, and layout checks.
- Chet's peacock dance entry (25 pages total), real Godot-exported 35 transitions, finite-number rejection, integer font sizes, native input ownership fix, measured full-text heights on resize, optional notices, and retention/pause regressions.
- Nathan's requested optional checklist: **To try** in the notebook; C or Y/Triangle inside the book. Twelve low-pressure invitations get checked by actual discoveries. No hidden biology unlocked by viewing it, and no task to starve or get caught.
- 24 reachable pages (now 25 of 26 with the ant-mimic page, ROBLOX-64); only the surface-vibration page remains unwired. A nearby fly takeoff now counts as the audible event. Model and checklist survive rest recovery and new lives this session only.
- `gen_notebook_pages.py` is the data generator. `notebook_reference.*` is frozen content; `notebook_godot.*` is the executed Godot model's 35 transitions. Never regenerate expected decisions from the Roblox implementation.
- The adopted reader uses a text/list layout. The earlier Chet sketches are not displayed in this merged reader. No new graphics, physics, purchases, or audience settings.

## What Nathan should test on PlayStation

Rejoin to get the published version. Touchpad opens the life menu; choose Notebook. Triangle opens To try. D-pad/left stick navigates the page list; Cross opens on compact layouts; right stick scrolls, L1/R1 changes pages, Circle returns/closes. Confirm that movement is paused while reading and that closing a book opened from the end screen returns there. Try a meal, rest, moult and peacock dance, and check the corresponding invitations.

## Next chunk for Claude or Chet: persistence first

Start from updated main. Read `PUBLIC_RELEASE.md`. The current world simulation runs on the client. Do not expose an arbitrary client checkpoint upload and call it authoritative. Plan a trust boundary before a server save implementation.

1. Version a player record containing notebook IDs/eye time, cosmetic choice, accessibility preferences and main-life completion; keep it separate from the last-rest world record and the Free-play rest. Define bounded fields, migrations, unknown-ID handling and newer-schema preservation. Do not add typed spider names yet.
2. Establish a server-owned source of truth before saving world state. The current simulation and discovery watcher are client-side. A RemoteEvent accepting an arbitrary client checkpoint is not an authority boundary. Plan a server copy of the necessary life/action state, or explicitly defer durable world recovery until that copy exists. Do not claim secure persistence from shape validation alone.
3. Use DataStoreService UpdateAsync with session ownership, bounded retries/backoff, load-before-save, write throttling and shutdown handling. A failed or unknown load must never overwrite an existing save with a blank life. Keep a last-good record and distinguish "saved", "saving" and "session only" in the UI.
4. Test reconnect, rapid device switch, old schema, unknown/new schema, corrupt payload, duplicate action, partial failure, throttling and shutdown. Notebook discoveries must be a monotonic union; returning to a rest must not roll them back. Main and Free play keep independent rest slots.
5. Chet checks real Studio behavior and publication. Nathan checks PlayStation/tablet. Preserve current privacy and Data Sharing choices; do not enable Studio access to live production DataStores as a convenience.

Publication uses the existing online place 120119801868085 / universe 10771103250, Rojo sync of `default.project.json`, then ordinary Publish. Never publish the test project; never use a new experience to work around Publish As.
