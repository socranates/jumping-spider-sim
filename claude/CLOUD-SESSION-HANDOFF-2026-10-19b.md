# The Windowsill — handoff to the next session (2026-10-19, evening)

Written by the cloud session session_01Q7Bnq6qd1obxxCL9GcdoVt as its credits ran out. Paste the PROMPT as the first message of the
next session; everything it needs is on GitHub now, no bundle required.

---

## PROMPT

You are continuing Claude's work on "The Windowsill" (Nathan's Roblox jumping-spider life sim). Read, in order: this file
(`claude/CLOUD-SESSION-HANDOFF-2026-10-19b.md` on the branch), `docs/OPEN_WORLD_DESIGN.md` (all of it, including "Nathan's direction
(2026-10-19, evening)"), `docs/GARDEN_BESTIARY.md`, `docs/WEB_SLINGER_DESIGN.md`, `docs/HANDOFF-roblox-world.md`, `docs/DECISIONS.md`
from "### ROBLOX-94" to the end, and `claude/coordination.md` if Nathan attaches it (the desktop session stood down; the cloud session
owns the work).

Your jobs, in order:
1. Restore: `git clone https://github.com/socranates/jumping-spider-sim` and check out `claude/new-session-lqh973` (head e092fc4 + the
   docs commit after it = playtest v32, published). Install the toolchain below. Verify `bash $HOME/p2_work/check.sh types` clean,
   `compile` 143/143, `python3 tests/run.py $HOME/luau/luau worldmap.luau` passes (191).
2. Finish W3 (garden life, ROBLOX-96). Its work in progress is on the branch `claude/w3-wip` (one WIP commit on top of e092fc4: the
   helper's uncommitted tree at the moment of the snapshot, mid-round: prey per region, the gnat and the aphid, the woodlouse, the
   stone home words, the descent case, the page, saves per region). Check it out on a fresh branch from the main line, read
   `docs/DECISIONS.md`'s ROBLOX-96 draft and the W3 handoff section in it, run the suites named in the brief, fix what is red, finish what
   is missing, then the whole suite, the records, one commit in the house style. The W3 brief is in this file's end.
3. Build, bundle, publish as v33 by the route below; then W3b (the bestiary), W4, W5 per the design.
4. Keep `claude/where-we-left-off.md` in Nathan's claude.ai Project current at every publish (give Nathan the text to paste).

Standing rules from Nathan, verbatim: "Publish only the playtest place." "Never name the daughter." "Peacock and ant mimic stay free
until Nathan says otherwise." "No git writes, deletes or tracked-file edits in the OneDrive mount." "Never handle or see API keys or
passwords; Nathan logs in himself." "Use 'continue', not 'try again'." "No Publish As." Chet (ChatGPT/Codex) is away; you publish.

---

## State at handoff

- GitHub `socranates/jumping-spider-sim`: branch `claude/new-session-lqh973` = the Roblox line (main ce64498 + 49 commits + this
  handoff's docs commit); draft PR #31 describes it. Branch `claude/w3-wip` = W3's unfinished tree. The old PC-bundle route still
  works (`claude-playtest/claude-sill.bundle` = e092fc4) but is no longer needed.
- Playtest is live at **v32** (Roblox's own counter reads v33; our numbering is one behind it). v31 and v32 both went out 2026-10-19.
- Nathan has not played v31 or v32 yet as of this handoff; the open questions for him are in `docs/HANDOFF-roblox-world.md` (W2) and
  in the direction section of the design.
- Tonight's direction (all recorded in `docs/OPEN_WORLD_DESIGN.md` "Nathan's direction (2026-10-19, evening)"): the peacock replaces
  the first spider as the default (the first spider stays, free); the whole life to a courtship that can fail; the sill as the nursery
  with the sash shut until the spider is ready, the world unfolding one region at a time; many more bugs with sourced pages
  (`docs/GARDEN_BESTIARY.md`, round W3b after W3); weather after W4; the footfall (about 1 in 100) and the rule that rare things happen,
  seeded and honest; hidden things worth the risk in every region's detail pass; the cast of playable kinds up to the wasp ("be
  anything"); the web-slinger (`docs/WEB_SLINGER_DESIGN.md`: bought only after an honest playthrough, works everywhere); an eventual
  Steam port. Order: W3, W3b, W4, W5, then the peacock-as-default (with the nursery), then the cast and the web-slinger, weather with
  or after W4.

## Toolchain (container is fresh each session)

- Luau: `https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip` → `$HOME/luau/{luau,luau-compile}`.
- luau-lsp: `.../JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip` → `$HOME/lsp/luau-lsp`;
  `$HOME/lsp/globalTypes.d.luau` from `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau`.
- Rojo 7.7.1: `.../rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip` → `$HOME/bin/rojo` (on PATH for `tools/build.py`).
- Godot 4.3: `.../godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip` → `$HOME/godot/`; xvfb is installed.
- `$HOME/p2_work/check.sh` (recreate): `types` = `rojo sourcemap default.project.json --output sourcemap.json` then
  `luau-lsp analyze --sourcemap=sourcemap.json --definitions=$HOME/lsp/globalTypes.d.luau --ignore="**/tests/**" --no-strict-dm-types src`;
  `compile` = `luau-compile --null` on every `src/**/*.luau` (expect 143/143). Add `roblox_port/sourcemap.json` to `.git/info/exclude`.
- Tests: `cd roblox_port && python3 tests/run.py $HOME/luau/luau [suite.luau]`; the full run ~25 min, background it with nohup.
- Build: `python3 tools/build.py $HOME/bin/rojo` (stamps `tests/studio/BuildInfo.luau`, rebuilds both .rbxlx).

## Publishing from Nathan's PC (the route that works, refined tonight)

Desktop Commander (connector `Remote_Desktop_Commander`, device "Soc"; Nathan must have the agent running: it showed offline until he
restarted it). Helper scripts are in `C:\Users\natha\claude-xfer\tools\`: `ui.ps1` (focus/click/dblclick/keys/clicktype/shot, refuses
to send keys unless Studio is the foreground window), `cmdbar.ps1` (pastes a .luau file into Studio's command bar and runs it with
Ctrl+Enter; run with `powershell -STA`), `drag.ps1`, `scroll.ps1`, `rawclick.ps1` (click without refocusing, for open menus).
Screenshots land at `C:\Users\natha\claude-xfer\shot.png`; read them with `read_file`. Read Studio's Output from the logs, not the
screen: `$env:LOCALAPPDATA\Roblox\logs\*.log` modified in the last minutes, `Select-String '\[Windowsill\]'`.

Steps: in `C:\Users\natha\windowsill-publish` (origin = the OneDrive clone; untouched) `git fetch https://github.com/socranates/jumping-spider-sim <branch>`
then `git reset --hard FETCH_HEAD` (HEAD is `claude/roblox-sill`, fine). `Start-Process` rojo (`C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\rojo\rojo.exe serve default.project.json`,
hidden, from `windowsill-publish\roblox_port`). Studio has "socranates's Place: 10152026_1" open (place 120119801868085); Plugins tab →
Rojo → if the panel shows the stale WebSocket error, double-click Okay; Connect. Verify with a `.Source:find(...)` print from the
command bar and read the result from the log. **Rojo serve does not carry Workspace `$properties`**: select Workspace (command bar
`game.Selection:Set({workspace})`), filter Properties for "Stream" and check StreamingEnabled on, StreamingIntegrityMode Disabled,
StreamingMinRadius 96, StreamingTargetRadius 160 (set them by clicking the value cell and typing; `^a` selects the Explorer, not the
text). Press F5 (click the viewport first), wait ~25 s, click "Begin a new life" (449,407 in the 1366×768 layout with the viewport at
285..893 × 165..540), wait ~35 s, grep the log for `[Windowsill]` lines: world:/decor:/music: print only on failure. Stop Play (188,61),
`Stop-Process` rojo, File (17,32) → Publish (44,353, via rawclick.ps1 since the menu is the foreground); the log then says "Add publish
notes to vN" and "Published new changes". Gotchas: the hidden Claude window steals focus (the scripts check for it); starting a second
PowerShell process moves keyboard focus, so click-and-type must happen in one process (`clicktype`); the Output pane is short, use the
log; "Publish" in the File menu is separate from "Publish As" (never that). After publishing: append to
`claude-playtest/README-sill.txt` (write_file append), refresh `claude-playtest/claude-sill.bundle`
(`git bundle create ... ce64498..claude/roblox-sill` from the publish clone) and `TheWindowsill-latest.rbxlx`; none of those is tracked
by git, so the OneDrive rule is kept.

---

## W3 BRIEF (as dispatched; the WIP branch is partway through it)

See the "W3 — garden life" section of `docs/HANDOFF-roblox-world.md` on `claude/w3-wip` for what the helper recorded, and
`docs/DECISIONS.md` ROBLOX-96 there. The brief's points: 1 prey per region (the sill pinned, `bed_a` its own seeded perches, prey only
in the spider's region and whole neighbours, no rerolls at seams); 2 the fungus gnat and the aphid as derived profiles (Godot goldens
untouched), bodies under the fly's part cap, catch factors, meal words in `Shared/UI/*Text`; 3 woodlice as the first ambient bug
(`Shared/Prey/Woodlouse.luau`, `Client/BugBodies.luau`), uncatchable, hide under the stone within ~4 studs; 4 the stone as a home in
`LifeText`; 5 the descent set piece (wall dressing within budget; a real-client let-down case from the slab's edge to the soil); 6 one
Roblox-only notebook page through `tools/gen_notebook_pages.py` ROBLOX_PAGES with sources in `docs/NOTEBOOK_SOURCES.md`, triggered by
the first step onto the bed; 7 saves per region (`Checkpoint` prey record per region, range checks per profile, old records unchanged,
`CONTENT_REVISION`/`SCHEMA_VERSION`/`WorldMap.REVISION` unchanged); 8 tests (prey/flies pinned for the sill, new cases, `tests/garden_life.luau`
in `CLIENT_TESTS`), strict clean, compile clean, the whole suite; 9 previews with `--world --views bed,stone,descent,wall`; records
(DECISIONS ROBLOX-96, the W3 handoff section with a Studio checklist, README counts, SESSION_LOG, the design's plan marked); one commit
ending with the two trailer lines the session uses. Rules: golden-data, `WindowsillLayout` untouched, words in `Shared/UI/*Text`, no
Studio claims, `NotebookPages.luau` only through its generator, the coordinator builds the places.
