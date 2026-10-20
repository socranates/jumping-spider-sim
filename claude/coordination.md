# Coordination between agents working on The Windowsill — read this first

Updated 2026-10-20 by the cloud session session_01Q7Bnq6qd1obxxCL9GcdoVt (the coordinator). Nathan has several agents working on the
game at once; this file is how they keep out of each other's way. Peer messaging between machines is not reliable, so this file and
GitHub are the channel.

## The rules

1. **One integration line**: `claude/new-session-lqh973` on GitHub (draft PR #31) is the game. Never push to it directly. Work on your
   own branch named `claude/<your-task>` cut from its latest head, open a draft PR **into `claude/new-session-lqh973`**, and say in it
   which files you touch. The coordinator reviews and merges.
2. **Claim before you start**: add a line under "Claims" below (task, branch, the modules and docs you will change) in your branch's
   first commit, and read the other claims. Two agents never own the same module in the same round; if you need one that is claimed,
   say so in your PR and wait.
3. **Shared files, edited by the coordinator only**: `docs/DECISIONS.md` numbering (ask for a ROBLOX number in your PR, write your entry
   in `docs/decisions-pending/<branch>.md`), `src/Shared/Data/NotebookPages.luau` (generated), `roblox_port/tests/run.py`'s suite list
   (say what to add), the `.rbxlx` places and `tests/studio/BuildInfo.luau` (built at merge), `README.md` counts, `SESSION_LOG.md`.
4. **Nathan's PC is single-tenant**: only the coordinator drives Studio, Rojo, the publish clone (`C:\Users\natha\windowsill-publish`),
   `claude-playtest/` and publishing. Others may read files on the PC, never write there. Nobody publishes but the coordinator.
5. **Green before review**: strict types clean (`bash roblox_port/tools/check.sh types`), every module compiles (`... compile`), the
   suites you touched and the full run (`python3 roblox_port/tests/run.py <luau>`). GitHub Actions (`roblox-port`) runs them on every
   push; a red PR is not reviewed.
6. **The project's rules hold for everyone**: Godot goldens bit-identical; seeded draws only (no `math.random`); words in
   `Shared/UI/*Text`; nothing claimed about Studio that was not run there; notebook sentences need a source that was opened.
   Nathan's standing rules: "Publish only the playtest place." "Never name the daughter." "Peacock and ant mimic stay free until
   Nathan says otherwise." "No git writes, deletes or tracked-file edits in the OneDrive mount." "Never handle or see API keys or
   passwords; Nathan logs in himself." "Use 'continue', not 'try again'." "No Publish As."

## Where the work is

The plan is `docs/OPEN_WORLD_DESIGN.md` (with Nathan's direction of 2026-10-19), `docs/GARDEN_BESTIARY.md`, `docs/WEB_SLINGER_DESIGN.md`;
the handoff `claude/CLOUD-SESSION-HANDOFF-2026-10-19b.md` has the toolchain. Live: playtest v33 (W3, garden life). Next rounds, which can
run in parallel if their files do not overlap: W3b the bestiary (prey and ambient bugs; `Shared/Prey/*`, `Client/BugBodies`, `FlyLook`,
`Species` derived profiles, the generator's ROBLOX_PAGES), W4 nature's rules (`LifeClock.game`, `NeedsModel` game tables, `Life/*`,
`Mating*`), W5 the HUD audit (`Client/SpiderHud`, `PerceptionHud`, `Shared/UI/*Text`), the peacock-as-default and nursery
(`Rig/SpiderChoice`, `Appearances`, `Persistence/SaveProgress`), weather (`Habitat/DayLight`, `SunPick`).

## Claims

- Coordinator (session_01Q7Bnq6qd1obxxCL9GcdoVt): integration, builds, Studio, publishing; nothing else claimed.
