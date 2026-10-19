# Handoff: the open world, round W1 (ROBLOX-94) — the sill as region 0 of one continuous garden

Claude → Chet, 2026-10-19. Still branch **claude/roblox-sill** (the one bundle, `claude-playtest/claude-sill.bundle`, carries everything up
to this commit). This is the first of the five world rounds planned in `docs/OPEN_WORLD_DESIGN.md` (W1–W5); **W2–W5 will be appended to this
handoff as they land**, each with its own checklist. CLI at the closing commit: strict clean, 142/142 modules compile (the client at -O0 and
-O1), all 37 suites green, 61,070 checks; the new suites are `worldmap` (87) and `world_client` (17), and the counts that moved are checkpoint
375, life 20,922, world 294 and state 491. **Nothing in this round has run in Studio**: the places committed in the repository are still the
audit round's (evidence `a83e0b69a7a331ce`, playtest v30) and need `tools/build.py` before the next publish. The game is meant to play
exactly as v30 does; the whole point of W1 is that nothing a player can see has changed yet.

**The bundle** is `claude-playtest/claude-sill.bundle` on Nathan's PC, overwritten each round so it always holds the whole branch. Names such as
`claude-sill-v30.bundle` exist only in the cloud outputs of the sessions that made them.

## What is in it (ROBLOX-94; `docs/DECISIONS.md` has the reasons)

- **The map.** `Shared/World/WorldMap` is the authored list of regions: one so far, `sill`, with the windowsill's own bounds, spawn, crevice
  and a `clockScale` of 1.0, at the origin exactly as it always was. `Shared/World/Region` is the generators: for the sill they return
  `WindowsillLayout.PIECES` and `DECOR` themselves (byte-identical, pinned), the rival's keep-out box, the folder name ("Windowsill") and the
  part budgets (1,156 full / 292 low, what the decor builds now). Every sim and client module that read bounds, the spawn or the crack from
  the layout now asks the map (`Checkpoint`, `RivalSpider`, `RivalDrive`, `RivalRoute`, `Mate`, `MateDrive`, `MateStage`, `SpiderClient`,
  the wasp's retreat callback); the drawing modules (`Scenery`, `Shapes`, `Plants`) still read the layout as the sill's own data.
- **The server builds the world.** `Shared/World/WorldBuild` builds every region's boxes under one `Workspace.World` folder; the sill's folder
  inside it is the very one `Scenery.sill` always made (same name, same 28 parts, same attributes, same hidden-but-solid pieces), only its
  parent changed. The drawn sill, `Workspace.Decor`, is now a **Model** with `ModelStreamingMode = Persistent` instead of a Folder.
- **Streaming.** `Workspace.StreamingEnabled = true`, `StreamingMinRadius 96`, `StreamingTargetRadius 160`, `StreamingIntegrityMode Disabled`,
  authored in **both** Rojo projects (`default.project.json` and `tests.project.json`). There is no character, so the server parks a small
  invisible part per player at the sill's spawn and makes it the player's `ReplicationFocus` (`Server/WorldFocus`, folder
  `Workspace.ReplicationFoci`); the farthest corner of the sill is 68.6 studs from it, inside the 96 that is always sent. The client
  (`Client/WorldClient`) raycasts only against `Workspace.World`, waits for every box of the sill (30 s at most) and for the Decor (10 s) before
  the sim starts, and points its own `ReplicationFocus` at the drawn spider's root as belt and braces.
- **The clock.** `LifeClock.game.clockScale` multiplies every advance of game hours; the client sets it each frame from the region the spider is
  in. The sill is 1.0, so nothing changes; Godot's rates and the life goldens are untouched.
- **The save.** A rest now records `world_map = { seed, revision, region, retreat, diffs }` beside the object graph (the world itself is never
  saved; `diffs` is empty until something in the world can change). Every save from before this round has none and restores as the sill of seed
  914 with no changes, at the spot it was kept. A rest from another `WorldMap.REVISION` or seed restores at its region's spawn with a notice
  ("the world has changed since you rested"). `SCHEMA_VERSION` (3) and `CONTENT_REVISION` are unchanged: the field is optional.

## Your Studio checklist (W1)

1. **Streaming is really on.** After the Rojo sync, in the command bar: `print(workspace.StreamingEnabled, workspace.StreamingMinRadius,
   workspace.StreamingTargetRadius, workspace.StreamingIntegrityMode)` → `true 96 160 Enum.StreamingIntegrityMode.Disabled`. Rojo has to apply
   the Workspace `$properties` for any of this round to take effect on the live place; if it prints `false`, set the four by hand in the
   Workspace properties (and tell us, so the build route is fixed). The built `.rbxlx` places carry them.
2. **The World folder.** In Play: `Workspace.World.Windowsill` holds the 28 sill parts (`Workspace.Windowsill` no longer exists);
   `Workspace.Decor` is a Model (Persistent); `Workspace.ReplicationFoci` holds one `ReplicationFocus_<UserId>` part per player, and in the
   server view `print(game.Players:GetPlayers()[1].ReplicationFocus)` names that part. Output should carry no `[Windowsill] world:` warnings
   (a box that never streamed in, or a refused focus write, is warned about by name).
3. **A full day plays as before.** From the spawn: walk the whole sill, every leaf, the wall, the undersides; a jump; a drop on the line; the
   crack and a rest; the night. Nothing should look or feel different from v30. If the spider ever falls through where a box should be, that is
   streaming (item 2's warning), not the motor.
4. **An old save restores.** A rest kept by v30 (no `world_map` in it) must come back exactly where it was kept, with no notice beyond the usual
   "Returned to your last rest". Then a rest kept by this build, walked away from and returned to.
5. **The rival and the mate still arrive** (day 2 after the first meal; the mate after an adult rest at 60%+): the rival walks every face and
   keeps out of the crack, the mate comes onto the east end, the scene plays. They are the same creatures bound to the sill region.
6. **Frame time unchanged** at both tiers (the detail handoff's item 2 still stands): streaming adds nothing to draw, but a persistent Model of
   1,156 parts arriving at join may show as a longer load; note the time from Play to the spider standing.
7. **On the PlayStation / a phone** (when you can): the same, with the low tier; streaming on a real client is the thing this round cannot see
   from here.

## Open for Nathan

- The garden's clock: 0.25 (the architecture) or 0.33 (your rules, so hunger per real minute stays real)? W4 sets it; W2 only adds the regions.
- The revision gate's notice words ("Returned to your last rest, but the world has changed since you rested, so you stand where a life begins
  in it. Everything else is as you left it.").
- Whether a rest in a retreat should remember the retreat as the home (it does: `world_map.retreat`), and whether the first garden home should be
  the stone in bed_a as the design says.

*(W2 — beyond the glass, W3 — garden life, W4 — nature's rules and W5 — no hand holding will be appended here as they land.)*
