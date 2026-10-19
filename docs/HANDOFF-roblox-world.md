# Handoff: the open world, round W1 (ROBLOX-94) — the sill as region 0 of one continuous garden

Claude → Chet, 2026-10-19. Still branch **claude/roblox-sill** (the one bundle, `claude-playtest/claude-sill.bundle`, carries everything up
to this commit). This is the first of the five world rounds planned in `docs/OPEN_WORLD_DESIGN.md` (W1–W5); **W2–W5 will be appended to this
handoff as they land**, each with its own checklist. CLI at the closing commit: strict clean, 142/142 modules compile (the client at -O0 and
-O1), all 37 suites green, 61,070 checks; the new suites are `worldmap` (87) and `world_client` (17), and the counts that moved are checkpoint
375, life 20,922, world 294 and state 491. **Nothing in this round has run in Studio** beyond the publish route's
spot checks. The places were rebuilt at the closing commit of W1 plus the two small decisions below (ROBLOX-99 and 100; 61,072 checks),
evidence `fb7a1858a2cdcca4`, and published to the playtest as **v31**. The game is meant to play exactly as v30 does but for the slower
let-down and the music; the whole point of W1 is that nothing a player can see has changed yet.

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

## Two small ones from the PlayStation (ROBLOX-99, ROBLOX-100), same bundle

- **ROBLOX-99 — the hang goes slower.** Nathan: "make the hang just go slower by default and the mechanic would work perfect". Letting down on
  the line now runs at half Godot's reel speed (`SilkController.game.lowerScale` = 0.5, so 0.75 studs a second; reeling in keeps 1.5). The dial
  is one number; Godot's defaults, the tether goldens and your silk spec are untouched. Feel it on a pad: a drop from the frame, the drop key
  held, the stick back, the climb back up.
- **ROBLOX-100 — the music plays again.** Nathan: "also i cant hear the music" (v30). The audit's gate on `Sound.IsLoaded` in `Soundscape`'s
  `playing()` helper is gone (the engine can leave `IsLoaded` false for audio that plays — devforum 2654049 — and the gate then never asked the
  music to play); the helper is v29's again. Two Output-only reports were added: a `ContentProvider:PreloadAsync` status for the music at
  startup (warns unless `Success`), and a one-time warning if the music has been asked to play for 20 s with `IsLoaded` still false. **Check in
  Studio and on the PC client**: Output after Play should carry no `[Windowsill] music:` line, and `workspace.WindowsillAudio.music.IsPlaying`
  should be true with `TimePosition` advancing. If a `did not load` line appears, the asset is the problem (moderation, the grant to universe
  10771103250), not the code.

## W2 — beyond the glass (ROBLOX-95)

Claude → Chet, 2026-10-19, same branch and bundle. The window opens: the middle lower sash is raised 6 cm and the spider can walk out through the gap
(x -8..8, y 0.7..6 in the back frame) onto the stone outer sill, over its front edge, down 90 cm of brick and onto the bed under the window, and back.
Nothing lives out there yet (W3); the rival and the mate stay on the sill. `docs/DECISIONS.md` ROBLOX-95 has the numbers and the reasons. CLI at the
closing commit: strict clean, 143/143 modules compile (the client at -O0, -O1 and -O2), all 37 suites green (see the README for the counts). **Nothing of
it has run in Studio** beyond the publish route's spot checks. The places were rebuilt at the closing commit (evidence `8b53da9e6a401c50`) and
published to the playtest as **v32**.

What is in it:

- **The sill's back frame** is four boxes round the opening (`back_frame_west`, `_east`, `_head`, `_rail`); the drawn window shows the raised sash (a
  sash rail across the top of the gap, jambs, the sill rail, no glass in the gap, the side panes and the raised pane as before). The window box outside
  is two halves standing on the stone, either side of the gap; the view's lawn is at the garden's level (y -90.4) and the shrubs stand on stems.
- **Three regions** in `Shared/World/WorldMap` (with the sill, four, in priority order): `outer_sill` (the slab, top y 0, x -30..30, z -24..-13.5),
  `house_wall` (face at z -24, y 0 down to the lawn, x -40..40, drawn as brick courses), `bed_a` (soil top y -90, x -25..25, z -24..-74: mounds,
  three stones, a dock and a dandelion, litter, grass). Their seeded generators are `Shared/World/Garden`; their looks are persistent models in
  `Workspace.WorldDecor` (about 550 parts at full, 216 at low); their boxes are folders in `Workspace.World` beside `Windowsill`.
- **The bed's stone** has a gap under it that is a retreat (`bed_a_stone`), the first garden home: a rest there is kept and returned to like the crack's.
- **The day runs at 0.33** in the bed (the sill's pace on the outer sill and the wall).
- **Streaming follows the spider**: the server makes `ReplicatedStorage.WorldFocus` (a RemoteEvent) at startup; the client fires it with the spider's
  place every 8 studs or 2 seconds; the server moves the player's `ReplicationFocus_<UserId>` part there (finite points inside the world, about ten a
  second at most). The client warns once per region in Output if the spider is in a region whose boxes have not all arrived.
- **Saves**: the world's revision is `world-2`. A rest kept by v30 or v31 comes back **at the sill's spawn** with "the world has changed since you rested"
  (intended: the back frame moved). Rests made by this build come back where they were kept.

## Your Studio checklist (W2)

1. **Walk out through the opening.** From the spawn, walk to the middle of the back wall (x 0) at floor level: the spider climbs the 0.7 cm rail, crosses
   it and steps down onto the stone. It should not snag at the rail or at the jambs; the rival should never follow it into the gap.
2. **The view through it**, from the sill's usual camera and from floor level in front of the gap: the stone outer sill and the garden beyond, the
   window box's halves either side, no glass in the gap, the raised sash's rail across its top, the upper panes as before, nothing drawn inside a
   backdrop. From the outer sill looking back: the window in its brick and plaster, the sill inside through the gap.
3. **Descend the wall on the line.** From the outer sill's front edge, let down on the dragline (the hang of ROBLOX-86 at the slower 0.75 studs a second
   of ROBLOX-99: about two minutes for the 90 cm; that is intended). Watch the camera's framing against the brick and the boom near the wall. Also walk
   down the brick face and back up it.
4. **The bed.** Walk the soil, the mounds, the stones, up the dock's stem and out under and over its leaves, the dandelion's leaves; the day line should
   run noticeably slower (0.33). A jump or a fall from the wall lands on the soil (no harm); a fall beside the garden puts the spider back on its last
   support.
5. **Rest under the stone.** Walk into the gap under the big stone (x 7..15, z -53..-47) and rest: it should be accepted as a rest. Walk away, use
   "Back to last rest": the spider is back under the stone.
6. **Come back up and home.** Climb the brick, cross the stone, step over the rail, rest in the crack; the day's pace is the sill's again.
7. **An old save** (a rest from v31 or v30) under the revision gate: it should come back at the sill's spawn with the "world has changed" notice,
   everything else as it was.
8. **The remote and the focus**, in the server view while walking out and down: `game.ReplicatedStorage.WorldFocus` exists, and
   `print(workspace.ReplicationFoci:GetChildren()[1].Position)` follows the spider (within about 8 studs).
9. **Output stays clean**: no `[Windowsill] world:` warnings (a region that has not arrived whole, a box that never streamed in) and no
   `[Windowsill] decor:` warnings (a look that failed) while going out, down and back.
10. **Frame time and parts** at both tiers, on the PC and when you can on the PlayStation or a phone: the looks outside add about 550 parts at full and 216
   at low, all persistent.

## Open for Nathan (W2)

- The garden's pace is 0.33 for now, as you said; W4 tunes it with the movement cost.
- The shrubs in the view now stand on stems (standards) because as floating balls they hung over the garden you can now walk into; say if you would
  rather they were bushes to the ground (they would hide more of the garden).
- The wall above the outer sill is drawn but not climbable this round; the outer sill's ends and the wall's shoulders are the edges of the world.

## W3 — garden life (ROBLOX-96)

Claude → Chet, 2026-10-19, same branch and bundle. The bed under the window has its first life: fungus gnats and aphids as prey (the gnats fly short flights, the aphids
only walk the dock's and the dandelion's leaves and stems), four woodlice that walk the soil and go under the big stone, the other stones' feet or the litter when the spider
comes within four studs (not prey: nothing can catch them, and the senses see them as movement only), the gap under the stone as a home in the words ("Home: under the
stone", "Resting under the stone", "Last rest kept, under the stone."), the wall dressed for the descent (lichen, one weathered course, cobweb strands in the corner under
the outer sill), the game's line long enough for the 90 cm let-down (`SilkController.game.maxLine` = 100 studs; Godot's 20 untouched as the default), a notebook page
("Life on the ground", opened by the first step onto the bed), and rests that keep the bed's prey and woodlice where they were. `docs/DECISIONS.md` ROBLOX-96 has the numbers
and the reasons. CLI at the closing commit: strict clean, 146/146 modules compile, all 38 suites green (the README has the counts; the new suite is `garden_life`). **Nothing
of it has run in Studio.** The sill plays as it did: its flies, their seeds and every sill golden are pinned unchanged.

What is in it:

- **Prey per region** (`Shared/Prey/PreyWorld`, kept as `M.World.prey` in the client): the sill's director is the one the client always had; the bed's is made from
  `Shared/World/Garden.prey(bed_a)` (28 perches on the soil, the mounds' and stones' tops, under and on the dock's leaves, the stem and the dandelion's rosette; four vents)
  with the bed's own seed, the first time the bed has arrived whole (`WorldClient:regionReady`) with the spider in it or near its foot on the wall, and it keeps its own
  random streams and its own clock ever after: leave and it waits, come back and it goes on. Six prey in the bed: three gnats, three aphids; the population replaces what is
  eaten (gnats fly in from the soil, aphids appear on a free plant perch out of sight). One jaws: every director eats with the sill's `Feeding`.
- **Woodlice** (`Shared/Prey/Woodlouse`, drawn by `Client/BugBodies`, 24 parts each, four in the bed): seeded on free soil, slow walkers that steer round the mounds, the
  stones and the plants, hide within four studs of the spider and come out 8 to 15 s after it is six studs away.
- **The wall's look** is 110 parts at full and 75 at low (93/73 before): three cobweb strands (two at both tiers), eight lichen patches and six eroded faces on one course.
  Nothing moved, so `WorldMap.REVISION` stays `world-2` and every v32 rest comes back where it was.
- **Saves**: the record gains an optional `garden` root (`{ bed_a = { prey, bugs } }`) beside the sill's `prey`, which is byte for byte what it was; a v32 record (no garden)
  restores unchanged and leaves the bed's live prey as it is. `SCHEMA_VERSION` and `CONTENT_REVISION` unchanged.

## Your Studio checklist (W3)

1. **Walk out and down** (the W2 route): out through the opening, over the stone, down the brick (walking) to the bed. Output should carry no `[Windowsill] world:` warning
   on the way; if "bed_a ... has not arrived whole" appears, the bed's prey will not exist until it does (that is the gate working; tell us how long it took).
2. **See a gnat and an aphid in the bed.** Gnats (dark, about 3 mm, one pair of wings) sit on the soil, the mounds and under the dock's leaves and flit short flights; aphids
   (green, pear-shaped, under 3 mm) sit on the dock's and the dandelion's leaves and the dock's stem and only shuffle. Watch for a minute: a gnat should fly at least once;
   no aphid should ever fly or leave its leaf. `print(#workspace.Flies:GetChildren())` in the bed should be 6 (their names begin `bed_a_fly_`).
3. **Catch each and read the meal line.** A gnat is easier than a fruit fly (fewer taps), an aphid easiest. While one is in the jaws the growth line should read
   "3 gnats = 1 housefly" or "6 aphids = 1 housefly" and count in tenths ("0.3 of 5 meals"); with nothing held, the old "2 small prey = 1 housefly" in halves.
4. **A woodlouse hides and returns.** `workspace.Bugs` holds four; walk up to one: within about four studs it makes for the big stone's gap, a stone's foot or a fallen leaf and
   goes under (it is drawn a stud and a half under the soil); wait six studs away and it comes back out within about fifteen seconds. A jump or a strike through one catches
   nothing, and the perception HUD may show it as movement, never as prey.
5. **Rest under the stone and read the home line.** Near the stone the line says "Home: under the stone" and how to get in; under it "Under the stone" / E: rest; resting
   "Resting under the stone"; the notice "Last rest kept, under the stone." On the sill every word is as it was.
6. **The descent on the line.** From the outer sill's front edge, F: the spider walks to the edge, drops, and with F held lets down at 0.75 studs a second past the cobwebbed
   corner and the lichened brick, about two minutes to the soil; it lands on the soil, the line is released, the day line runs at the bed's pace. Watch the camera against
   the wall on the way. If the hang stops short (20 studs down), the game's line length did not take: tell us.
7. **The page appears** on the first step onto the bed: "Life on the ground" in the notebook, once.
8. **Leave and rejoin.** Rest under the stone, note where a gnat and a woodlouse are, leave the game, rejoin and return to the rest: the bed's prey and woodlice should be where
   they were (not rerolled), the sill's flies as before.
9. **Output stays clean**: no `[Windowsill] world:` or `[Windowsill] decor:` warnings through all of it; no `[Windowsill] checkpoint refused` on the return.
10. **Parts and frame time** at both tiers, on the PC and when you can on the PlayStation or a phone: the bed adds at most 6 prey (22 or 15 parts each) and 4 woodlice (24 each),
    about 200 parts, and the wall's look 17 more at full; the sill's flies are not drawn while the spider is in the bed.

## Open for Nathan (W3)

- The bed's prey count (six: three gnats, three aphids) and the woodlice (four): more, fewer?
- The game's line length (100 studs) for the let-down: long enough for the wall and nothing else; say if the hang should stop part way and make the spider walk the rest.
- Whether the woodlice should show to the senses at all (they are movement now, as the wasp and the rival are) or be invisible to the perception HUD.
- The aphids only shuffle on one leaf (no walk from leaf to leaf); say if they should wander the plant.

*(W4 — nature's rules and W5 — no hand holding will be appended here as they land.)*
