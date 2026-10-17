# The field notebook - Claude, 2026-10-17

Branch `claude/roblox-notebook` (on top of origin/main: 272503b pages and model, d705793 watcher and retention, cc3d6c7 panel, 4bce4d2 layout, Studio spec and real-client check, then the docs and rebuilt places). Decisions ROBLOX-37 and ROBLOX-38. Session-only, like checkpoints and Easy: no DataStore.

## What was built

- **Pages as data.** tools/gen_notebook_pages.py turns data/notebook/pages.json into src/Shared/Data/NotebookPages.luau: 24 pages, ids, triggers, titles, texts and citations word for word (the test compares them with the JSON). Seven "In this game" lines are adapted to Roblox (bold_jumper, dragline, legs_push, green_uv, hungry_at_home, mud_dauber, what_the_wasp_does); Godot's line stays in `godotGame`. The documented observation and the game note stay separate.
- **Pure model** FieldNotebook (Learning/FieldNotebook.luau): reveal once, stable ids, nothing visible before the observation, sources kept, found order, tolerant `toRecord`/`load` for the later DataStore chunk.
- **Watcher** NotebookWatch, wired in SpiderClient to real events (not HUD text):

| Event | Pages |
|---|---|
| Start of the first frame | start |
| Hop, leap, and the distance of a leap (5 studs far, 8 long) | jump, jump_far, jump_long |
| Eye view on; time there (20 s, 60 s all told); a moving mark drawn | eye_view, eye_time_20, eye_time_60, shimmer |
| Sensor memory sees a fly-like prey category | fly_recognised |
| A capture; a meal; reserve at or under 0.25, at or over 0.85, starving | catch, meal, hungry, well_fed, starving |
| A fly takes off within 10 studs | buzz |
| Rest, wake, moult ready, moulted, adult | rest, sleep, moult_ready, moulted, adult |
| Wasp visit starts, leaves, catches | wasp, wasp_escaped, wasp_caught |
| Not wired: `felt` (the port has no vibration sense) | - |

  Opening a page the first time shows a six-second HUD note. The first state diff after a checkpoint return or a new spider only takes a baseline, so nothing opens twice and a restored world is not read as a new event.
- **Retention.** The book is outside the world checkpoint and LifeSession. Returning to a rest, Free play and an unrelated new spider all keep it. Lost when the session ends.
- **Panel** NotebookPanel + NotebookText + ControlText: modal at ContextActionService priority 4000; the world waits; side-by-side list and page on screens of at least 640 x 340 (scaled for large text), otherwise one pane; controls hint dropped on short screens; large text 1.5x; touch targets at least 44 px.

## Keys and entry points

| | Open | In the panel |
|---|---|---|
| Keyboard | N | Up/Down/W/S choose; Left/Right/A/D previous or next; Enter/Space/E open; PageUp/PageDown scroll; Q, B, Backspace back; N or M close |
| Controller / PlayStation | View / Touchpad (life menu), then Notebook | D-pad or left stick choose; L1/R1 previous or next; A (Cross) open; right stick scroll; B (Circle) back |
| Touch | Notebook button (top right), or Menu then Notebook | Tap a page; Back and Close buttons; drag to scroll |
| End screen | Notebook choice | closes back to the end screen |

The D-pad is the port's walking and no controller face button is free, so the controller route is the menu (the Godot D-pad-up binding is not used).

## Deviations and uncertainties

- **No count of pages left.** Godot's spec (item 4) forbids it; the handoff asked for a "not yet observed" count. The port follows the spec. Tell Claude if the count is wanted.
- No Godot goldens: the Godot binary was unavailable here, so the Godot test cases were ported by hand and the pages checked verbatim against the JSON.
- `felt` unwired; `buzz` mapped to fly take-off within 10 studs (Godot's hearing range).
- Eye time counts real seconds in the eye view only, not while a menu, the notebook or the Roblox menu is open; slow motion does not change it.

## Evidence (plain luau CLI, 0.742 build in this sandbox)

NOTEBOOK 793/0; SUMMARY 185/0; PERCEPTION 4669; SENSOR 507; PREY 1549; LIFE 20846; CHECKPOINT 156; WASP 15815; GAZE 67; PRESENTATION 11; BOXWORLD 15; CLIENT 23; PERCEPTION_CLIENT 1; LOOK 102; WORLD 230; FLIES 187; EYES 231; HUD 69; PEACOCK 80; CONTINUING 87; GROWTH 433. All failed=0; total 46,056. Strict analysis 0 diagnostics; 145/145 scripts compile. Places rebuilt with tools/build.py (BuildInfo regenerated).

## Chet: Studio checklist

1. Open TheWindowsillTests.rbxlx, Play, read PORT_TEST_REPORT: expect the new row "Notebook spec completes" (tests/studio/NotebookSpec.luau: every page measured with TextService on 8 screens at two text scales, list titles, buttons, controls line, HUD note) and the live-client row "NOTEBOOK: opens in the real client ..." in tests/client/SilkPlayback.luau (panel enabled, world clock unchanged while open, only found pages listed, no text wider than its box, closes). The CLI cannot measure real fonts, so these are the evidence for text fit.
2. Play TheWindowsill.rbxlx: press N at once (empty book says only that nothing is noticed yet), hop (a page and a note), press N, read it, scroll, close.
3. Emulate a phone (568 x 320) and a tablet: the Notebook button must not cover the Day/stage column or the Menu button; the page text must be readable and scroll.
4. Large text (the life menu's Text size choice, Player attribute LargeText): the list and page still fit.

## What Nathan should try

- Keyboard: play a minute (hop, leap, V for the eye view, catch a fly), press N, read a page, scroll with the mouse wheel or PageDown, close with N. Rest, return with Backspace: the pages are still there. Start a new spider after the end: the book carries over.
- PlayStation: Touchpad opens the menu, choose Notebook, pick a page with the D-pad, R1 for the next page, right stick to scroll, Circle to go back.
- Read the "In this game" lines and say whether any is wrong for the Roblox game.
