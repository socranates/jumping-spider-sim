# Field notebook — Chet, 2026-10-17

Nathan approved the next chunk after the peacock polish. Roblox remains active; Godot and SPEC remain frozen. Check `verification/roblox-notebook/RESULTS.md` for the final accepted evidence and published version.

## This round

- `Shared/Learning/FieldNotebook` ports discovery order, deduplication, long-jump and eye-time thresholds from Godot. `tools/export_notebook_reference.gd` executes the actual frozen notebook for 35 golden transitions. Player notes are outside world checkpoints and survive rest recovery, mode switches and unrelated new lives in this session.
- `NotebookWatch` observes life/wasp events and changes in actual capture, food-taken and energy counters. Rebase on checkpoint/new-life restoration prevents imported history from pretending to be a new event. Fly recognition uses the perception signal; jump pages use committed JumpInput feedback, never an aim preview. Eye time counts fixed simulation ticks only while playing. The peacock page requires a successful dance start.
- N or Menu > Field notebook opens a cream-paper, scrollable reading view with small vector spider sketches. Only discovered pages appear, in discovery order; it opens at the newest. No hidden-page count, checklist, reward or effect on the spider's senses. Close returns to whichever pause owner opened it. Large text, touch swiping, controller shoulders/left-right pages, D-pad/right-stick scrolling and B/Circle back are supported. The D-pad still walks outside the notebook.
- Facts, game simplifications and complete source citations are separate. `tools/notebook_pages.py` imports the frozen facts/citations and adapts obsolete game/control descriptions; it adds a sourced peacock courtship entry. Sources are readable citation text, with URLs retained where supplied, not an external browser-launch UI. No typed text or filtering surface was added.
- 25 authored pages, **23 currently reachable**. The inherited `felt` and `buzz` triggers stay dormant until a real surface-vibration/observed-buzz event exists in the Roblox port. Do not unlock those from a wasp footstep at any distance or simply from a Sound object's existence. Other pages are driven by actual play. Discovery notices can be disabled from the life menu.

Notes, unlocks and checkpoints are still **session-only**. No DataStore or monetization was introduced. The peacock stays free, the closer camera/quieter ambience and twitch/dance stay.

## Next chunk: persistent player and world records

Start with the ownership design and pure tests, then an isolated Studio/Roblox test environment before any production writes.

1. Version a player record containing notebook IDs/eye time, cosmetic choice, accessibility preferences and main-life completion; keep it separate from the last-rest world record and the Free-play rest. Define bounded fields, migrations, unknown-ID handling and newer-schema preservation. Do not add typed spider names yet.
2. Establish a server-owned source of truth before saving world state. The current simulation and discovery watcher are client-side. A RemoteEvent accepting an arbitrary client checkpoint is not an authority boundary. Plan a server copy of the necessary life/action state, or explicitly defer durable world recovery until that copy exists. Do not claim secure persistence from shape validation alone.
3. Use DataStoreService UpdateAsync with session ownership, bounded retries/backoff, load-before-save, write throttling and shutdown handling. A failed or unknown load must never overwrite an existing save with a blank life. Keep a last-good record and distinguish "saved", "saving" and "session only" in the UI.
4. Test reconnect, rapid device switch, old schema, unknown/new schema, corrupt payload, duplicate action, partial failure, throttling and shutdown. Notebook discoveries must be a monotonic union; returning to a rest must not roll them back. Main and Free play keep independent rest slots.
5. Chet checks real Studio behavior and publication. Nathan checks PlayStation/tablet. Preserve current privacy and Data Sharing choices; do not enable Studio access to live production DataStores as a convenience.

Publication uses the existing online place 120119801868085 / universe 10771103250, Rojo sync of `default.project.json`, then ordinary Publish. Never publish the test project; never use a new experience to work around Publish As.
