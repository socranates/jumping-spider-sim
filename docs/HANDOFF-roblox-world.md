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

## W3b part A — the garden's bestiary: springtails, leafhoppers, small moths, crane flies (ROBLOX-101)

Claude → Chet, 2026-10-19, same branch. Four more prey from `docs/GARDEN_BESTIARY.md`, on W3's pattern: **springtails** on the soil round the big stone and the litter
(1.5 mm, four of them; they flick away with a hop of 1.5 to 4 studs when the spider comes close or moves fast beside them), **leafhoppers** on the dock's stem and leaves and
the dandelion's stalk (4 mm, green, two; watched from their side they slip round to the far side of the stem or leaf; come at them fast and they jump 3 to 10 studs, sometimes
flying on), **small moths** on the brick wall and the outer sill by the window (8 mm, wings 15 mm, grey-brown, resting flat; still by day, fluttering from 18:00 through the
night; the first grab at one may slip, once) and **crane flies** on the wall and the outer sill (2 cm with legs near 4 cm, bigger than the spider; still by day, a slow
wobbling flier from 18:00; two housefly meals and a harder struggle than a house fly; it may leave a leg in the fangs and get away, once, and is drawn a leg short after). Each kind is
its own director per region (`World/Garden.bestiary`, `Prey/PreyWorld`'s `kinds`), behaviours in the new `Shared/Prey/PreyKinds`, bodies in `Data/FlyLook.small` at full and
low tier, four notebook pages opened by the first close look (within 4 studs), and the rest's record keeps them per region. `docs/DECISIONS.md` ROBLOX-101 has the numbers and
the reasons. **Nothing of it has run in Studio.** The sill plays as it did: no prey outside it runs while the spider is on it.

What is in it:

- **The bed** holds 12 prey at full (W3's three gnats and three aphids, four springtails, two leafhoppers) and 9 at low; **the wall** two moths and a crane fly (one and one at
  low); **the outer sill** a moth and a crane fly (a moth alone at low). Replacements appear on a free perch of their kind in reach, out of sight.
- **The tier** (`PreyWorld.tier`) is the client's detail tier, read when a region's directors are made. Bodies: springtail 15 / 11 parts, leafhopper 25 / 13, moth 20 / 9,
  crane fly 31 / 11 (28 / 10 a leg short), all under the fly's 40.
- **The hour** reaches the prey through `PreyWorld.before`'s last argument (the client passes `life.clock.hour`).
- **New words**: the meal line's "8 springtails = 1 housefly", "2 leafhoppers = 1 housefly", "1 moth = 1 housefly", "1 crane fly = 2 houseflies"; the notes "The moth slipped
  free, leaving scales in your fangs." and "The crane fly left a leg in your fangs and got away." (`UI/PreyText`, four seconds).
- **Saves**: a region's entry in the record's `garden` root may hold `kinds`; a v33 rest (W3's bed alone) restores unchanged and the new kinds are made from their seeds when
  their region is next whole. `SCHEMA_VERSION`, `CONTENT_REVISION` and `WorldMap.REVISION` unchanged.
- **The ground-life page** was checked against the sources that could be opened this time: two sentences narrowed ("live in colonies", "glands on the sides of the body"), one
  date fixed, a sixth source added (`docs/NOTEBOOK_SOURCES.md`).

## Your Studio checklist (W3b part A)

1. **Springtails at the stone.** In the bed, walk slowly toward the big stone's gap: `workspace.Flies` should hold four `bed_a_springtail_fly_` rigs (two at low detail)
   on the soil near the stones and the litter. Can you see one at all from the game camera? Come within two or three studs: it should flick away a few studs in a low arc
   (a sixth of a second), never fly; follow it and it flicks again. Strike one: it is easy to hold ("8 springtails = 1 housefly").
2. **A leafhopper on the dock.** Find the green leafhopper on the dock's stem or a leaf (two of them, `bed_a_leafhopper_fly_`). Stand three studs off on its side and sway a
   little: it should slip round to the other side of the stem or leaf in half a second. Rush it: it should jump far (3 to 10 studs) in a fast arc and sometimes fly on.
   Caught, it should take a house fly's tapping ("2 leafhoppers = 1 housefly").
3. **Moths and the crane fly by day.** On the wall on the way down and on the outer sill near the window: two moths and a crane fly on the brick, a moth and a crane fly on
   the outer sill (the slab's ends, the window box's fronts, the slab's front edge). By day they should not move unless you come close; the moths head up the wall, wings
   flat; the crane fly's legs splay about four studs across.
4. **At dusk.** Stay out past 18:00: the moths and the crane fly should flutter between perches, the crane fly slow and
   wobbling, and settle again; back to day profiles at 6:00.
5. **The moth's slip.** Catch a moth several times across lives: about a third of first grabs should end at once with the note "The moth slipped free, leaving scales in your
   fangs." and the moth flying off; once caught again, it stays in the jaws.
6. **The crane fly's leg.** Catch a crane fly and keep tapping: about four times in ten it should get away 0.6 to 1.6 s into the struggle with "The crane fly left a leg in your
   fangs and got away."; the drawn crane fly should then have five legs (the right hind gone) for the rest of its life. A whole one is two housefly meals.
7. **The pages.** Come within four studs of each kind: "Springtails and the spring", "Leafhoppers: the sidestep and the jump", "Moths at the window", "Crane flies: legs to
   spare" open once each. "Life on the ground" reads "live in colonies" and "glands on the sides of the body".
8. **The sill is the sill.** On the sill nothing outside runs: `print(#workspace.Flies:GetChildren())` there is the sill's four flies, as in v33; the sill's flies behave as
   they always did.
9. **Rest and rejoin.** Rest under the stone, note where a springtail and a leafhopper are; leave, rejoin, return to the rest: the bed's prey (all six kinds) where they
   were. A rest made in v33 should restore with no `[Windowsill] checkpoint refused`, the new kinds appearing fresh.
10. **Parts and frame time** in the bed at both tiers on the PC and, when you can, a phone: the bed's living prey is about 221 parts at full (W3's was 111) plus the woodlice's
   96; the wall's prey 71 and the outer sill's 51 at full.

## Open for Nathan (W3b part A)

- Can a springtail be seen and hunted at all at 1.5 mm, or should it be drawn larger than life (the moth and the crane fly are true size; the gnats are too)?
- The numbers are first guesses: four springtails and two leafhoppers in the bed, the moth's 35% slip, the crane fly's 40% shed leg, dusk from 18:00 to 6:00.
- The crane fly does not rest on the glass: the glass belongs to the sill's region, whose prey is pinned. Say if it should, and the sill's pin can be renegotiated for it.
- Part B (the ladybird, millipede, snail and harvestman as ambient bugs) is next on the bestiary's list.

## W3c — the look: insects that walk and fly, bushes to the ground, a single-story house, more detail (ROBLOX-103)

Claude → Chet, 2026-10-19, branch `claude/w3c`. Nathan's v33 notes: "better animations for the new insects"; "no holes, shrubs should be bushes and the house a
single story. more realistic. still more detail. More beauty. Lighting is beautiful". The lighting is untouched and nothing added casts a shadow. `docs/DECISIONS.md`
ROBLOX-103 has the numbers and the reasons. **Nothing of it has run in Studio.** No prey, rule or save changed; `WorldMap.REVISION` stays `world-2`, so every v33 rest
comes back where it was.

What is in it:

- **The bodies move** (pose only, no part added; `Client/FlyBodies`, `Client/BugBodies`, `Data/FlyLook` `motion`): legs that step in two tripods while a body walks
  (a full cycle per stride of ground covered, so an aphid shuffles slowly, a leafhopper steps round its stem, a moth resettles, and a body that stops stops), a
  metachronal wave down the woodlouse's fourteen legs, legs that kick in the jaws, antennae that sway, the flight blur that trembles as the house fly's always has, the
  moth's visible flap (5 Hz) and its wings shivering as it lands, the crane fly rocking in the air with its legs dangling, the leafhopper sinking nose-up before its
  jump, the springtail's somersault through its hop. The woodlouse (*Porcellio scaber*) cannot roll, so it scurries. Reduced Motion keeps the steps and stills the
  rest; a body more than 25 studs from the camera is drawn ten times a second, as the rival is.
- **Bushes to the ground**: the view's eight shrubs on stems are ten flowering bushes standing in the garden itself (0.55 to 1.5 m tall), a hedge line west of the bed
  and two on the east border, each a rounded crown of leaf clusters (`LeafyGrass`) on stems from the lawn, blossoms toward the house.
- **A single-story house**: a new region, `wall_upper`: the brick above the window up to the eaves at y 110 (on two jambs beside the window, where brick was drawn
  that nothing held), the soffit (walkable upside down), the fascia, a gutter whose floor is 1.09 m above the sill (a high perch; its spawn is on it), and the eave
  course of tiles; its look draws the rest of the house round it as a backdrop: the back wall 5 m either way, the roof over the whole house, the eaves and gutter along
  it, a downpipe, a second window and the back door. No retreat and no prey there yet. The houses across the way are three bungalows beyond a back fence (one
  storey, one row of windows, pitched roofs), the garden has its back and side fences, the two trees are real trees in the neighbours' gardens, the hills are far.
- **More detail**: petals, seeds and hairline cracks on the outer sill; drip streaks, weathered joints and moss in the joints on the wall; veins on the bed's leaves,
  seed heads, grass clumps at the edges, more kinds of litter and a snail shell in the bed. Looks: outer sill 116/39, wall 134/75, bed 466/113, wall above 154/59
  parts (full/low); the sill's Decor 1,253/355.
- **The wall's spawn** moved from its east shoulder's top (under the new jamb) to the shoulder's face; nothing rests there, so no save is affected.

## Your Studio checklist (W3c)

1. **The light is the light.** From the sill's usual camera at the spawn and through the window: the sunlight on the sill, the shafts, the shadows, the evening and
   the night should look exactly as in v33. If anything darkens or a new shadow falls on the sill, say where (nothing added should cast one).
2. **Insects that walk.** In the bed, watch an aphid shuffle on its leaf and a gnat walk on the soil: the legs should step, not slide, and stop when the body stops.
   Watch a woodlouse walk and then hurry for cover: a wave down its legs, faster as it hurries; it never rolls. On the wall at dusk watch a moth land: its wings
   should shiver and settle flat.
3. **Insects that fly.** A gnat's and a house fly's wings are a soft trembling blur (no strobing); a moth's beat visibly and smoothly; a crane fly rocks and its legs
   dangle and swing. Turn Reduced Motion on: the blur is still, the moth's wings a still blur, the crane fly flies level, the legs still step.
4. **The leap.** Rush a leafhopper: just before it jumps it should sink and tip its nose up for a moment. Come at a springtail: it should flip over in its hop.
5. **Far bugs.** From more than 25 studs away (the camera, not the spider) a bug should still move, a little less smoothly (ten times a second). Say if it looks wrong.
6. **Bushes to the ground.** From the sill through the window, from the outer sill and from the bed: bushes, not balls on sticks; their crowns touch the lawn; how
   `LeafyGrass` looks on them at this scale.
7. **The single-story house.** From the bed and from the descent look up: the brick above the window goes up to the eaves, the soffit, fascia and gutter, the roof
   above; to either side the house's wall and roof go on, a downpipe, another window, the back door. Nothing above the eaves but the roof. Through the window: the
   bungalows' roofs low in the middle of the glass (are they too faint in Roblox's haze?), the fences, the trees, the hills.
8. **Climb to the gutter.** From the wall (the descent's route in reverse, or up from the outer sill's end) climb the brick past the window's head to the eaves, walk
   out along the soffit upside down to the fascia and into the gutter; walk along it. Output should carry no `[Windowsill] world:` warning on the way (`wall_upper`
   must arrive whole; tell us if "wall_upper ... has not arrived whole" appears and for how long).
9. **The wall's shoulders.** Beside the window the spider should no longer walk inside drawn brick over the shoulders: the jambs are solid now.
10. **Parts and frame time** at both tiers, on the PC and when you can on a phone or the PlayStation: the looks outside are about 300 parts more at full (870 in all)
    and 70 more at low (286), the sill's Decor 75 more at full and 41 at low.

## Open for Nathan (W3c)

- Do the bugs' steps and wings read as living on the television, or is any of it too busy (the gnat's blur, the crane fly's rocking)?
- The bushes: the right size and number, the right places (a hedge west of the bed, two on the east border)? Walkable twigs (`shrub_west`) were not begun this round.
- The bungalows are 14.6 m off beyond the back fence, so from the sill they are small and hazy: would you rather see them closer, or more of the garden?
- The gutter has no retreat yet; a leaf mat in its corner with a gap under it could be one, with the eaves' house spider (the map plan's region 4).
- From the lawn the laid bricks round the window show as a patch in a wall of plainer courses until `wall_west` and `wall_east` are built (the drainpipe, the door).

## W3b part B — the garden's ambient life: ladybirds, millipedes, a garden snail, harvestmen (ROBLOX-105)

Claude → Chet, 2026-10-19, branch `claude/w3b-b`. The bestiary's ambient four, none of them food, on the woodlouse's pattern: **ladybirds** walking the dock and the
dandelion among the aphids (6 mm, red, seven spots; now and then one stops over an aphid and eats it in view), **millipedes** on the soil and under the stones (2.4 cm, slow,
two pairs of legs a ring stepping in a wave; within 2.5 studs of you one coils), a **garden snail** on the soil and up the foot of the wall (a shell 3 cm across, about a
millimetre a second, mostly from dusk; its eye stalks draw in near you; it leaves a pale trail that fades in four minutes), and **harvestmen** in the bed's litter and on
the house wall from 18:00 to 6:00 (a small body high on legs about four studs across; they ignore you). Each is a seeded sim of its own (`Shared/Prey/Ladybird`, `Millipede`,
`Snail`, `Harvestman`, from `World/Garden.ambient`), drawn in `Client/BugBodies` with its own motion, kept with a rest per region, and has a notebook page opened by the first
close look (within 4 studs). Strike one and it is refused with a short note in the game's words; the woodlice too. And Nathan's two W3 calls, with defaults: the aphids now
walk their plant now and then, slowly, perch to perch over its faces; and the woodlice (and the new four) are no longer shown to the perception HUD at all, because the
perception pipeline has no "not food" it could show without changing the golden sensor. `docs/DECISIONS.md` ROBLOX-105 has the numbers and the reasons. **Nothing of it has
run in Studio.**

What is in it:

- **Where and how many**: the bed holds two ladybirds (one at low detail), two millipedes (one), a snail and a harvestman; the house wall a harvestman. Their bodies cost
  226 parts at full and 101 at low in the bed (budgets 240 and 110), 20 on the wall.
- **The aphids' walk**: every 40 to 110 s an aphid may walk to another free perch of its own plant at 0.12 to 0.25 studs a second (`Prey/PreyKinds.creep`, the plants as
  paths in `World/Garden.plants`); startled on the way it freezes; it never flies or leaves its plant.
- **The ladybird's meal**: when its appetite is back (50 to 120 s) it walks to an aphid, stops beside it and eats it over 8 to 14 s; the aphid is gone and the bed's own
  population brings another later.
- **New words** (`UI/PreyText.REFUSED`, four seconds on the note line): "A foul fluid wells from the ladybird's leg joints. You let it go.", "The millipede coils tight,
  armour out, and smells foul. You let it go.", "The snail is far too big, and it has drawn into its shell.", "The harvestman gives off a foul smell and stalks on. You let it
  go.", "The woodlouse's glands give off a secretion spiders avoid. You let it go."
- **Pages**: "Ladybirds: bright for a reason", "Millipedes: the coil", "Snails: eyes on stalks", "Harvestmen: not spiders" (37 pages in all).
- **Saves**: a region's entry may hold `ambient`; a v34 rest restores unchanged and the new bugs are made from their seeds when their region is next whole. `SCHEMA_VERSION`,
  `CONTENT_REVISION` and `WorldMap.REVISION` unchanged.

## Your Studio checklist (W3b part B)

1. **The perception HUD in the bed.** Walk among the woodlice: no movement ring should appear for a woodlouse, a ladybird, a millipede, the snail or a harvestman (the
   gnats, aphids and the rest of the prey still show as before). Say if you miss the woodlice's rings.
2. **Ladybirds on the plants.** `workspace.Bugs` should hold `bed_a_ladybird_1` and `_2` (one at low detail) beside the four `louse_` rigs. Watch the dock and the
   dandelion: a red beetle walking up and down the stem and out onto the leaves, its legs stepping. Wait a few minutes near (but not on) an aphid: a ladybird should come,
   stop beside it, its head working, and after about ten seconds the aphid is gone.
3. **The aphids walk.** Watch an aphid for two minutes: now and then one walks slowly round the stem to another leaf (or round the dandelion's stalk to another rosette leaf)
   and settles there. It never flies.
4. **Strike each one.** Leap at a ladybird, a millipede, the snail, a harvestman (after 18:00) and a woodlouse. Each time: no catch, the note for that bug for four
   seconds, and its answer: a yellow drop at the ladybird's front legs and it keeps still a few seconds; the millipede coils; the snail draws in and stays in its shell
   about half a minute; the woodlouse runs for cover; the harvestman walks on. A leap that lands nowhere near one should say nothing.
5. **The millipede.** Find one on the soil (two at full detail): a dark body of rings about 2.4 cm long, legs rippling down it as it walks, turning in arcs. Come within
   about two and a half studs: it coils, head in the middle; go away and wait about ten seconds: it uncoils and walks on. Now and then one goes under a stone and comes out
   later.
6. **The snail.** A brown shell 3 studs across on the soil or on the brick just above it. Watch it crawl (very slowly) and leave a pale trail that fades over a few minutes.
   Come within five studs: its eye stalks draw into its head and it stops; back off past seven and they come out. Is the trail visible on the soil and on the brick?
7. **Harvestmen at dusk.** Stay out past 18:00: one in the bed's litter and one on the brick wall, small bodies high on very long legs, walking about and ignoring you; they
   go back to their corners at 6:00 and are not seen by day.
8. **The pages.** Come within four studs of each: "Ladybirds: bright for a reason", "Millipedes: the coil", "Snails: eyes on stalks", "Harvestmen: not spiders" open once
   each.
9. **Rest and rejoin.** Rest under the stone with the snail in its shell or a millipede coiled; leave, rejoin, return to the rest: they are as they were. A rest made in v34
   restores with no `[Windowsill] checkpoint refused`, the new bugs appearing fresh.
10. **Parts and frame time** in the bed at both tiers on the PC and, when you can, a phone: the ambient bugs add about 226 parts at full and 101 at low.

## Open for Nathan (W3b part B)

- The woodlice and the new bugs are now invisible to the perception HUD (a "not food" label would need a new perception category). Keep it, or have them back as movement?
- The aphids walk their plant every minute or two; more, less, or not at all?
- A ladybird eats an aphid at most every 50 to 120 s, in view: too often (the spider's own food), or a nice thing to watch?
- The numbers are first guesses: two ladybirds, two millipedes, one snail, a harvestman in the bed and one on the wall; the snail's trail fading in four minutes (a real one
  lasts much longer); the harvestmen out from 18:00 to 6:00.
- Next on the bestiary's list: slugs and the earthworm (with W4's rain), bees, the ant trail, and the centipede at the stone with W4's rules.

*(W4 — nature's rules and W5 — no hand holding will be appended here as they land.)*

## The self-test of the live place (ROBLOX-104, 2026-10-19)

The live place carries a self-test (`roblox_port/src/Client/SelfTest.luau`) that plays the parts that matter inside a real Studio Play session and prints a verdict
to Output; `roblox_port/tools/studio/selftest.ps1` reads it from Studio's log. It runs only in Studio and only with the Workspace attribute `SelfTest` set; a player
can never reach it. It has not been run in Studio yet: the first run tests the test.

How to run it, at every publish:

1. Open `TheWindowsill.rbxlx` (the live place) in Studio.
2. In the command bar: `workspace:SetAttribute("SelfTest", true)`
3. Press **Play**. Click nothing: the test begins a new life itself, through the start menu's "Begin a new life" (the life it plays is Studio's own test save,
   `WindowsillTest_v1`, not the live game's).
4. In PowerShell, from the repository: `.\roblox_port\tools\studio\selftest.ps1` (options `-Timeout 400`, `-Minutes 15`, `-LogDir <folder>`, and `-New` to start it before pressing Play and wait only for a run that begins after). It finds the newest
   log under `%LOCALAPPDATA%\Roblox\logs` with a `[SELFTEST] BEGIN`, prints the run's lines without Studio's prefix as they come, and stops at END: exit 0 when
   fail=0, 1 with failures, 2 if no END came before the deadline. Output in Studio shows the same lines.
5. Stop Play. If the place will be saved, clear the attribute first: `workspace:SetAttribute("SelfTest", nil)` (left set it still does nothing outside Studio).

What it prints: `[SELFTEST] PASS <name>` or `FAIL <name>: <why>` (or `SKIP`) for 20 checks: new life, world folders, region sill / outer_sill / house_wall /
bed_a / wall_upper (every box streamed in with the spider held at the spawn, ground under it, still there a second later, the client's region right), walk on
the sill, the line (let down at about 0.75 studs a second, on the line throughout), prey on the sill, prey in the bed, woodlice, frame time in the bed, moths on
the wall, dusk: the moths fly, notebook, rest and checkpoint, sound (the music playing, the room tone silent), frame time on the sill, part counts. `INFO` lines
carry the numbers (the line's speed, the frame time in the bed and on the sill, the parts by folder), `...` lines are a heartbeat every 5 s, and the last line is
`[SELFTEST] END pass=<n> fail=<m> skip=<k>`. The run is about a minute and a half plus streaming; well under three minutes.

## Your Studio checklist (ROBLOX-104)

1. **Run it once as above** and send the whole printout (or the log). The answer we want first: does it reach END, and with how many FAILs.
2. **A FAIL**: read its reason. A region "not whole after 30 s" names the boxes that never came: say whether the game itself shows a hole there. "the start menu
   would not take Begin a new life" or "no start menu" means the start never offered one in 45 s: say what the screen showed.
3. **The numbers**: the frame time lines in the bed and on the sill, and the part count at the full tier, are the first frame-time measures of the world rounds.
   Keep them with the build number, so the next publish can be compared.
4. **While it runs** the camera jumps from region to region, the clock goes to dusk for half a minute and back, the notebook flashes open: all of it is the test.
   Do not touch the mouse or keys until END (a key held would be the test's own key too).
5. If a check fails that you think is the test's fault rather than the game's (a deadline too short on a slow machine, a moth that was simply slow to fly), say
   so: the deadlines are guesses until this first run.

## W4 — nature's rules (ROBLOX-106)

Claude → Chet, 2026-10-19, branch `claude/w4`. (The design called this round "ROBLOX-97"; that number was never used, so it is ROBLOX-106.) Six of Nathan's rules
for **Normal only**; Easy and Free play are exactly as they were. `docs/DECISIONS.md` ROBLOX-106 has the numbers and the reasons. **Nothing of it has run in Studio.**

- **Moving costs food.** Walking, letting down or reeling in on the line and every jump take a little from the reserve; standing still, hanging still and resting cost
  nothing extra. A still day costs about 2.2 house flies, a typical one 2.7, a restless one 3.5.
- **Death loses the day.** The end card's last line says so in Normal: back at the last rest, the meals, the growth and what you saw since then are gone; another spider is
  a new life.
- **Threats linger.** The wasp's two visits slide up to an hour either way day to day and last 43 to 108 s; about one visit in twelve lingers 3.6 to 6 minutes. The rival
  now and then (one patrol leg in seven) stands watch for one to three minutes on the floor just outside the crack's mouth.
- **Mating can fail.** On a full meter the mate decides: about 9 in 10 for a still, close, facing court by a well-fed spider; a thin spider or a halting court far less.
  Refused, it walks off for the day with words that say why (thin, the courtship faltered, or simply not interested); on a third of visits the rival may push in and the
  visitor flees for the day. The chain after a mating is as before.
- **Home before dark.** Outside the glass (the outer sill, the walls, the bed), out of every retreat after dark, three passes of the ground hunters each night; each finds
  an exposed spider one time in four (the night's own death card), or spares it with a cold, slow morning until 10:00. On the sill nothing changes. No notice warns of
  dusk: the light does.
- **Cover.** A leaf (anything solid within 6 studs straight up) halves the wasp's and the rival's notice, standing still halves it, walking in the open doubles it.

## Your Studio checklist (W4)

1. **Walking's cost.** In Normal, with a full-ish bar, walk about for a minute, then stand still for a minute: the bar should fall visibly faster while walking. In Free
   play the two minutes should look the same.
2. **The end card in Normal.** Let the wasp or the rival take the spider: the card's last line should read "In Normal a death loses the day: back at your last rest...".
   With large text on, is the card still readable? Choose "Back to your last rest": the day since the rest is gone.
3. **The wasp.** Over a few days note the wasp's arrival times: they should not keep to the clock. If you meet a long visit (several minutes), hide in the crack and say
   how it felt: pinned, or broken?
4. **The rival by the crack.** Now and then the rival should stand still on the floor just outside the crack's mouth for a minute or more, then patrol on. It must never
   step inside the crack. Does it look like waiting, or like being stuck?
5. **Courtship.** Court a visitor well fed, close, still and facing: it usually works. Court one thin (bar under half) or while stepping about: watch for the refusal and
   its words. Say whether the words read fairly.
6. **The night.** Stay out in the bed past dark, away from the stone: within a few game hours the night card ("The night found the spider.") or the cold message and a
   slower walk until 10:00. Then do the same on the sill behind the glass: nothing happens.
7. **Cover.** Sit under a big leaf while the wasp searches, and again out in the open: being under the leaf and still should get you noticed much less often.
8. **Old saves.** A rest made in v35 should restore with no `[Windowsill] checkpoint refused`.

## Open for Nathan (W4)

- Each number is a first guess: walking's cost (0.0004 a second), the jump's (0.002), the wasp's linger (one visit in twelve, three to five times as long), the rival's
  watch (one leg in seven, one to three minutes), the night's passes (three, each one in four), the cold (0.6 of the speed until 10:00). Harder or softer?
- The night counts on the outer sill and the walls too, not only the bed. Should the outer sill (just outside the glass) be safe?
- Courtship: about 9 in 10 for a perfect court, 1 in 2 at the least fed a visitor comes for. Too kind, or too harsh for the game's climax?
- The footfall (the "1 percent" step) and the evening section's other rare things are still to come, after this round as the design orders them.
## The line fixed, the bushes beside the bed and the drainpipe (ROBLOX-107, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/regions6`. Three things. **The line**: the v35 self-test's one failure in Studio ("left the line 2.0 s into the let-down,
at (2.00, -2.70, -24.07)") is reproduced on the CLI to within two hundredths of a stud and fixed in `Movement/SilkController` (a let-down now lands only where there is
ground under the body, and the body is pushed back out of any box it has slipped into). **`shrub_west`**: the strip beside the bed from x -25 to -500 and z -24 to -200
is ten walkable chunks of box and privet bushes to the ground on deep leaf litter, each with a retreat in the gap under a curled dead leaf, woodlice and springtails in the
litter. **`wall_west`**: the back wall west of the window from x -40 to -120, from the lawn to the eaves, with the **drainpipe**: a climbable column from the litter to a
swan neck under the gutter and up into it, brackets every 100 studs, the second way up to the gutter; two woodlice begin at its damp foot. `docs/DECISIONS.md` ROBLOX-107
has the numbers and the reasons. **Nothing of it has run in Studio.**

What is in it:

- **Regions**: 17 now (`wall_west`, `wall_west_upper`, `shrub_west_a` to `_j` added), 486 boxes outside the window (37 before). Each chunk 42 or 43 boxes (the nav
  graph's ceiling is 60); each region whole inside the streaming target radius from anywhere on it. `WorldMap.REVISION` still `world-2`: nothing that was there moved.
- **Looks**: a chunk 260 drawn parts at full, 80 at low; the wall west 93/59 below y 0 and 88/71 above; `wall_upper`'s look 150/58 (its drawn downpipe, brackets and shoe
  are gone: the walkable pipe replaces them). Four of the view's drawn bushes that stood in the strip moved out along the lawn's west edge (`Data/Flora`).
- **Life**: four woodlice per chunk (40 in all) and four springtails (two at low) in the litter; no gnats, aphids or ambient bugs there yet; the ground beetle later.
- **The self-test** picks the new regions up by itself: 32 checks now, not 20 (a "region ..." check for each of the 17).

## Your Studio checklist (ROBLOX-107)

1. **The self-test first** (as for ROBLOX-104): `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the printout. The one we want: `PASS the line`.
   If it still fails, the line says where the body left the line: send it, because it says whether the cause named in ROBLOX-107 was the right one. The twelve new
   "region ..." checks should pass too; one "not whole after 30 s" names the boxes that never came.
2. **The let-down by hand**: from the outer sill's front edge, hold the drop key and ride the line all the way to the soil. It should not stop on the brick a few studs
   down, nor stick to the brick; it should end on the bed.
3. **The drainpipe**: walk west along the wall from the window (or down the brick to the bed and west over the litter), find the grey pipe at x -50, climb it from the
   litter, past the brackets, out along the swan neck under the gutter and up into the gutter. Say if any step of it stops you, and if the pipe reads as a pipe.
4. **The bushes**: walk west from the bed into the bushes. Do they read as dense bushes to the ground from outside, and as a way through from inside (the camera in the
   leaves)? Is it shady enough under them? Find a dead leaf lying on two twigs under the first bush of a chunk and rest in the gap under it; leave and continue.
5. **Woodlice at the drain**: two should be on the dark damp patch at the pipe's foot when you first come there.
6. **The frame time**: the `INFO frame time` lines (the sill's and the bed's, against v35's). The regions' looks are persistent models, always on the client, so the
   ten chunks' looks are there wherever the spider is: the looks outside the window are 3,647 parts at full now (870 before) and 1,215 at low (286). If the frame time
   moved, or a phone struggles, say so: the looks can be made to stream with their regions (a choice for a later round, not made here).

## Performance for a real release (ROBLOX-108, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/perf`. For phones and the PlayStation. **The looks outside the window are made on each client near its spider**,
not by the server for everyone: the server no longer builds `WorldDecor`; each client builds the regions' looks itself from the same seeded generators
(`Client/LookStream` following `World/LookPlan`'s plan) into its own `Workspace.WorldDecor`, at most 1,500 parts at full and 500 at low (3,647 and 1,215 were
always there before): the region the spider is in and every region it meets at the tier's detail, the house's walls and roof far off as a few big brick-coloured
parts so the house never has a hole, the rest nearest first. At most 120 parts are made a frame, but a region the spider is in or beside that has nothing drawn
is made whole at once. **The rest's hitch**: the frame a rest begins encoded the rest's record (about 300,000 characters after a visit to the garden) four to six
times; now three to five, each pass cheaper, the same bytes stored. **The low tier**: the house fly is 29 parts at low (39 at full); a PlayStation is always the
full tier (`GuiService:IsTenFootInterface()`). **The CLI suite is fast**: the shim's queries are cached and gridded and its frames multiply without garbage, with
every answer as before. `docs/DECISIONS.md` ROBLOX-108 has the numbers. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-108)

1. **The self-test first**: `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the printout. All checks should pass as before. New: an
   `INFO looks outside the window: ...` line (how many look parts the client holds; at most 1,500 at full). Send the two `INFO frame time` lines: the sill's
   comes right after a rest, where the 129 ms frame was.
2. **Pop-in**: walk out of the window, down the brick to the bed and west into the bushes, and on to the far corner. Watch the edges of what you can see: do
   bushes or details appear or vanish where you are looking? (Bushes more than about 2.6 m off are not drawn; the house far off is a plain brick wall with its roof,
   eaves and drainpipe, and its bricks, window and door come in as you come near.)
3. **The house from far off**: from the far corner of the bushes (x -495), look back at the house. It should be whole: a brick wall to the eaves, the roof, the
   gutter line, the drainpipe. Does the plain brick read as the same wall as the bricks near you, in Roblox's light and haze?
4. **A rest and its return**: rest in the crack (and under the bed's stone), leave, return. Any hitch you feel at the moment the rest begins?
5. **On a phone** (low tier): the same walk; the house flies on the sill are a little plainer (no bristles, no wing sheen). Frame time and heat.
6. **On the PlayStation**: it should be the full tier (the spider's full fur). If a PlayStation 4 struggles, set `Workspace.Detail = "low"` to compare and say.
## The first minute: the splash, the title card and the intro (ROBLOX-109, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/intro`. Nathan asked for "a good splash page and intro". `docs/DECISIONS.md` ROBLOX-109 has the numbers and the
reasons; `docs/STORE_PAGE.md` is the store page's plan. **Nothing of it has run in Studio.**

- **The splash** (`src/First`, mapped to ReplicatedFirst in `default.project.json` only; the test place has none): Roblox's loading screen is removed; a black
  field fades up on the garden seen from outside, the camera drawing in toward the window, "The Windowsill" in Merriweather with its one line; a small dot only if
  the wait is long; it fades away over the title card when the client's start menu opens (the Player attribute `TitleReady`). It always ends: at 45 s whatever
  happened, and at once on any error (one `[Windowsill] splash:` line in Output).
- **The title card**: the start menu over the same slow camera, the music rising under it. Continue (when a rest exists), Begin a new life, Free play, Settings,
  the Notebook once it has pages; the saving note in small type. A controller moves with the D-pad or stick, chooses with Cross / A, and B / Circle is "back"
  where a screen has one (the confirmation, the life menu). The discovery-notes and text-size buttons are gone from the menu (both are in Settings).
- **The intro of a new life**, once per save (`intro_seen` in the progress record): about 14 s, the light through the glass, the sill to the crack, the spider
  walking out, three captions, then the game's camera and the controls. Skippable after 2 s (Space, Enter, E, Cross / A, or a tap). Reduced Motion: still shots
  and cuts.
- **The cards** (death, the ending, the life menu): the same typeface; words unchanged.
- **The self-test**: one check more, "intro" (33 now).

## Your Studio checklist (ROBLOX-109)

1. **The self-test first** (as for ROBLOX-104): `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the printout. New: `PASS intro` (its FAIL
   says which step: not holding, the skip refused or taken early, the spider still in the crack).
2. **The splash, from a cold start**: publish to a test place or use Team Test / a real client (Studio's Play loads too fast to see much). From the first frame:
   no grey Roblox screen, a black field, then the garden fading in with the title and its line; the camera moving slowly in toward the window; no bar. Does
   the title read? Is Merriweather the face shown (a serif; Gotham or Source Sans would mean the family was not found)?
3. **The hand-over**: when the menu appears, the splash fades away over it without the camera jumping. Say if there is a jump or a flash of the plain sill.
4. **The title card**: the camera keeps drifting and then breathing in front of the window; the music comes up from silence. Choose with the mouse, then with a
   PlayStation controller (D-pad down and up, Cross to choose, Circle on the "Begin a new life?" confirmation keeps the life), then on a phone (Studio's
   device emulator at a phone size): everything on the screen and readable?
5. **The intro**: it plays once per save, and the self-test's run marks Studio's test save as having seen it, so for looking at it set
   `workspace:SetAttribute("IntroAlways", true)` in the command bar before Play (Studio only: every new life from the menu then plays it). Watch it through
   once: does the spider walk out of the crack cleanly, do the captions read, does the ease into the game's camera land behind the spider without a lurch?
   Then begin another and skip it at about 3 s (Space; on a controller Cross). Turn on Reduced Motion in Settings and begin another: still shots, cuts. Clear
   the attribute before saving the place.
6. **Never twice**: after the intro, leave and come back (or begin another new life): no intro.
7. **The cards**: let the spider starve or be caught: the death card in the same face, words as before.
8. **The store page**: read `docs/STORE_PAGE.md`; take the icon and the thumbnails from the cameras listed if you like them, or say what to change.

## Open for Nathan (ROBLOX-109)

- The words: the title's line ("A small life on a windowsill.") and the three captions. The third, "It has not eaten. It must eat today.", is Normal's;
  in the gentle rules it says hunger is gentler. Too much, too little?
- The typeface: Merriweather (Light for the title). Another of Roblox's faces?
- The intro's length (about 14 s, skippable after 2) and whether it should also play for Free play's first life (it does now, once per save).
- The description and the icon's concept in `docs/STORE_PAGE.md`.

## Lock-on and the sidestep (ROBLOX-110, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/lock`. Nathan asked for "a lock on so you can track prey without the visual cues and the ability to side step".
`docs/DECISIONS.md` ROBLOX-110 has the numbers and the reasons. **Nothing of it has run in Studio.**

- **The lock** (`Shared/Movement/LockOn`, new): Recentre (R, middle mouse, the right-stick click / R3, the touch Recentre) locks onto what the spider has seen:
  the thing in its principal eyes nearest the middle of the view, else the nearest it has placed within 12 studs in front of it. With nothing to lock the same
  press recentres as before; a press while locked lets go (and recentres). Touch also has a small Lock button left of Cancel, shown only while something can
  be locked or a lock holds (Lock / Unlock). Only the sensor's memory is read: nothing unseen or hidden can be locked.
- **While locked**: the camera keeps it framed (third person and the eye view; Reduced Motion holds still and cuts at 25 degrees), the body faces it, a held
  jump aims at it. A / D (the stick's left and right, the touch arrows) sidestep round it at the creep at the distance it had; W / S close or open it.
- **It ends** on a second press, Cancel (when there is no aim, press, line or edge walk to cancel), when the spider's memory lets it go (6 s out of sight, the
  spot found empty, eaten) or beyond 16 studs.
- **The setting** "Show what the spider notices" (Comfort, on by default) hides the perception HUD's rings, marks, words and edge chevrons. The lock's only
  cue is four faint ticks round the locked thing; no words.
- **The controls card** names it on every device, still ten lines at most. **The self-test**: one check more, "lock" (34 now).

## Your Studio checklist (ROBLOX-110)

1. **The self-test first**: `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the printout. New: `PASS lock` and its `INFO lock:` line
   (how far the fly was, the facing, the sidestep in a second). Its SKIP says when no fly of the sill had a place in view of it.
2. **Lock a fly**: on the sill, walk to within a few studs of a fly, look at it, press R. The camera should turn to keep the fly in view (try looking away with
   the mouse: the view should come back to it), the spider should face it, and four small ticks should sit round the fly. Hold A, then D: the spider sidles
   round the fly slowly, staying at the same distance and facing it. W closes in, S backs off. Hold Space: the landing patch should be on or right behind the
   fly. Press R again: the lock goes and the camera recentres. Then press R with nothing seen near: it only recentres.
3. **Endings**: lock a fly and let it fly off (walk at it): the lock should end by itself within a few seconds of the fly leaving sight. Lock, then Q: it ends.
4. **Walls and undersides**: lock a fly from a wall or under a leaf of the Pilea and sidestep: the spider keeps to its surface and keeps facing the fly.
5. **The eye view** (V) while locked: the view should turn to the fly too.
6. **Show what the spider notices**: Settings, Comfort, turn it off: no rings or words over what the spider sees; lock a fly: the four ticks and the camera
   still follow it. Turn it back on.
7. **Reduced Motion** on, lock a fly and sidestep: the camera should hold still and cut back only when the fly is well off the middle.
8. **Controller and phone**: on a PlayStation controller R3 locks and unlocks and the stick circles; the controls card (H on a keyboard, the life menu's Controls
   on a controller) says so. In Studio's device emulator at a phone size: the Lock button appears beside Cancel only when a fly is in view, and says Unlock
   while locked.

## Open for Nathan (ROBLOX-110)

- The lock is on Recentre (R / R3 / the touch Recentre and a Lock button), not on a tap of Focus as the brief suggested: a tap and a hold of one button would
  have fought Focus's toggle setting and left the controller nothing free. Say if you would rather have the Focus tap (or another key).
- The numbers: 12 studs to lock, 16 to keep, the camera's follow at 5 a second, the creep at 0.65 studs a second while circling.
- The woodlice, ladybirds, millipedes, snail and harvestmen are not shown to the spider's senses (ROBLOX-105), so they cannot be locked yet.

## What the real engine said, and the self-test as a profiler (ROBLOX-111, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/prof`. The v36 self-test in Studio passed 33 of 34: every region, the intro, the lock, the prey, the dusk, the rest and
the sound. It failed the line (`let down at 0.559 studs a second, not about 0.75`) and measured the bed at 22 fps (mean 45.5 ms, worst 76.8) against the
sill's 60 (worst 23.0 ms: the 129 ms hitch v35 showed on the sill is gone). `docs/DECISIONS.md` ROBLOX-111 has the reasoning. **Nothing of it has run in Studio.**

- **The line**: the body hangs 0.31 off the brick face, moving along it; an engine sweep that reports a touch of a face the body is moving along stopped the
  tick's whole move. Such a touch is now let pass (`SilkController`'s `grazing`) and the skin kept by the push-out; the box world is unchanged. The check is
  now judged in the game's time (the ticks) with the clock's rate beside it, and it prints what the line did.
- **The bed**: not changed, instrumented. The CLI finds nothing in the client's Lua that explains it (no thrash, no build while still, nothing O(n²)); the
  bed differs from the sill by the bushes on screen and some 350 more moving body parts. The self-test now times the client's frame by part and compares the
  bed with the looks out and with the shadows off.

## Your Studio checklist (ROBLOX-111)

1. **The self-test**: `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the whole printout (35 checks now; it takes about 15 s longer). The
   new and changed lines to read, in order:
   - `INFO profile on the line:` the client's frame while it lets down (the render step's ms a frame by part, the worst frame).
   - `INFO line:` the rate in the game's time **and** by the clock. `PASS the line` now means the game's rate is 0.6 to 0.9.
   - `INFO line ticks:` the cause. Read: the ticks and the game's seconds against the clock's (much less game time than clock: frames over a quarter second
     lost time, cause 2); `the body fell ... (n% of it)` (about 100% is right; about 74% is v36's loss); `tangent touches let pass` (above 0 confirms cause 1,
     the fix doing its work); `sweeps stopped the body` and what they took off; `push-outs (... of it up)` (a large upward share is cause 3).
   - `INFO profile in the bed:` and `INFO engine in the bed:` after the bed's frame time; `INFO census in the bed:` (parts, see-through, casting shadows,
     meshed, by folder).
   - `INFO looks settled in the bed:` (yes or NOT, and how long after the spider came) and `INFO looks while settled:` (plans and parts made during the
     sample: anything above 0 is thrash).
   - `INFO frame time in the bed, settled:` with its profile and engine lines, then `INFO frame time in the bed without the looks:` and
     `INFO frame time in the bed without shadows:` with theirs. **The comparison that matters**: if the frame is near 16 ms without the looks, the looks
     are the cost; near 16 ms without shadows, their shadows are; neither, then the render step's parts (the profile) or the moving bodies are.
   - `INFO profile on the sill:`, `INFO engine on the sill:`, `INFO census on the sill:` to set against the bed's.
   - The render step's ms a frame is the client's own Lua; the frame time minus it is the engine's (rendering, physics, other scripts).
2. **By hand, the let-down**: from the outer sill's front edge, hold the drop key: the spider should go down the brick at an even pace (about 0.75 studs a
   second), never sticking against the wall, and land on the bed's soil.
3. **By hand, the bed**: walk in the bed by the bushes with Studio's frame rate showing (View, Stats, or Shift+F5): note the fps looking into the bushes and
   looking away from them.

## Open for Nathan (ROBLOX-111)

- Nothing to decide yet. If the next printout says the bushes' clusters or their shadows are what the bed pays for, the next round will propose a lighter
  bush (fewer, larger clusters, or shadows only near the spider) for you to look at before anything changes.

## No hand holding, and the frame's two costs (ROBLOX-113, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/w5`. W5 of the open-world plan and two costs v37's self-test named. `docs/DECISIONS.md` ROBLOX-113 has the
reasoning and `docs/HUD_AUDIT.md` the list of every string with its class. **Nothing of it has run in Studio.**

- **The quiet HUD** (`Shared/UI/QuietHud`, new). In Normal, after the life's first day (or a spiderling generation's), the screen keeps the hunger bar, the
  day line with the moult count, the sound captions, the answer to anything pressed, the rest's titles, the line's cue and a missing safety line; the
  how-to words (the walk's reminder, the card at the start, the line's panel, the crack's prompt and the way home, the aim's "release to leap", the feeding
  and grip lines, the eye view's and the dance's status lines, the meal rule, hungry and dusk under the day) are the first day's; the wasp's, the
  courtship's and the guard days' status lines and the soft skin's reminder are Easy's and Free play's only. Easy and Free play keep every word. The
  notices are filtered line by line ("Last rest kept." stays; the morning's own line goes). The day line names no region. H and Menu, Controls bring the
  card at any time.
- **The perception labels**: one to an area of the screen, the newest winning, "lost sight" gone in 1 s (every mode).
- **The camera on the line**: the overlap test is asked once per point a tick (123 a frame became 2 in the CLI), a squeezed pitch search and the line
  framing's search run at most every other tick while the rest point moves, the render reuses the tick's boom. What the camera does is the same.
- **The rig**: 26% fewer CFrames a frame (the first spider at full: 1,650 to 1,211 for its 693 parts), the frames the same to the bit.

## Your Studio checklist (ROBLOX-113)

1. **The self-test**: `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the whole printout (35 checks, as before). The lines that show
   the gains:
   - `INFO profile on the line:` the `camera` part's ms (v37: 7.87 mean, 17.5 worst) and, new on the `a frame:` list, `camera casts`, `camera overlaps`,
     `camera rays`, `framing searches` (the CLI: 10 casts and 2 overlaps a frame on the line, 3 and 2 elsewhere). The render step's ms (v37: 12.5).
   - `INFO profile on the sill:` and `in the bed:` the `allocated ... KB a frame` and the `spider rig` share of it (v37: about 100 KB a frame for the rig;
     the count says about three quarters of that now), and the new `spider parts placed` (693 at full for the first spider, as before).
2. **By hand, Normal's quiet** (a new life, the standard rules): on day 1 the walk's reminder, the controls card for 20 s, the crack's "E: rest", the aim's
   "release to leap" and the line's panel are there. Sleep to day 2 and check: none of those; the hunger bar still says hungry; the crack shows nothing until
   E rests, then only "Resting in the silk-lined crack" and "Last rest kept."; on the line only the cue ("Letting go... 40%"); a jump's aim shows its title and
   a missing safety line, nothing else; H (or Menu, Controls on a controller) still brings the card. When the wasp comes: its hum's caption with the
   direction, and no status line.
3. **By hand, Easy**: the same day 2 in Easy has every word it had (the wasp's line, the crack's prompt, "Hungry: time to hunt.").
4. **The labels**: lose sight of two or three flies close together on the soil: one "lost sight" at a time, fading in about a second.
5. **By hand, the line's camera**: let down from the outer sill's edge and reel back up: the view should behave as before (turning by its 15-degree steps
   when squeezed, the player's look taking over at once).

## Open for Nathan (ROBLOX-113)

- **The audit is a proposal you can change line by line** (`docs/HUD_AUDIT.md`): each kind's class is one word in `Shared/UI/QuietHud`. The calls most
  worth your eye: the courtship's "face it and keep still" is Easy's only (Normal learns it from the notebook's page); the wasp's status lines are Easy's
  only (Normal hears the hum); the rival's crouch warning is Easy's only; the weak starving line and "Last rest kept." stay in Normal.
- **No region name on the day line**, as decided here. If you would like the place named (say, only when the spider first reaches a region), it is one
  kind in the table.
## The house in true proportion, and the first of the inside (ROBLOX-112, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/house`. Nathan: "The house is still too tall or needs to be made into a whole house with rooms and everything".
The kitchen window is a real window now (62 wide, its glass 1.1 m tall, its head 1.125 m above the sill, a sash window with the lower sash raised 6 cm as
before), the eaves are 2.4 m above the lawn (the gutter's floor 1.49 m above the sill, 1.09 before), and the first two regions of the inside are built:
the kitchen's counter under the sill (the worktop 4 cm under the sill board, a sink, a tap, a toaster whose gap underneath is a home, a kettle) and the floor
in front of it with the cupboards. The rest of the inside is planned in `docs/WORLD_MAP_PLAN.md` ("The inside"). `docs/DECISIONS.md` ROBLOX-112 has the numbers.
`WorldMap.REVISION` is world-3: every rest saved before this comes back at its region's spawn with the notice "the world has changed since you rested".
**Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-112)

1. **The self-test**: `workspace:SetAttribute("SelfTest", true)`, Play, touch nothing, send the printout. It walks 21 regions now (17 before: the new ones are
   `eaves`, `eaves_west`, `kitchen_counter`, `kitchen_floor`; `wall_upper` is rebuilt), so 39 checks. Every `region` line should PASS.
2. **From the garden**: walk out to the lawn's edge (or fly the Studio camera there) and look at the back of the house: a tall sash window over the bed with
   its transom and mullions, its head well under the gutter, the house's other window the same size to the west, the back door about as tall as the window's
   head, the gutter 2.4 m up, the roof showing over it. Through the window a room (a pale ceiling and a far wall), not the sky. Screenshot it for Nathan.
3. **From the sill**: the view out of the window should be as it was low down (the panes, the raised sash, the shelf across); looking up, the glass goes on
   up to the frame's head. **The light on the sill should be exactly as it was** (the new glass is above where the sun comes in): say if it is brighter.
4. **Climb the window**: from the sill, walk up the back frame onto the glass and up to the head; from the outer sill, up the outside of the glass. Both faces
   should hold the spider; the shelf across the window should be walkable as before.
5. **Into the kitchen**: walk off the sill's front edge: the spider should land on the worktop 4 cm down. Walk to the toaster (west), into the gap under it, and
   rest (the prompt says "Under the toaster"); Backspace / the life menu's "Back to last rest" should bring it back there. Then walk to the worktop's front edge
   and down the cupboard doors to the floor, and under the doors into the dark kick space (the pea and the dust ball are there).
6. **The sink**: drop into the bowl and climb out up its steel side.
7. **An old save**: load a save from v37 or before: the spider should come back at its region's spawn with the notice, not where it rested.
8. **Phone tier**: in the device emulator at a phone size, stand in the bushes where four chunks meet (about x -120, z -112): the looks there are 499 of the
   low tier's 500 parts; say if the frame rate drops.

## Open for Nathan (ROBLOX-112)

- The inside's plan (`docs/WORLD_MAP_PLAN.md`, "The inside"): a kitchen behind the window, a bathroom west of it (the house's other window), a back hall with
  the back door east of it, a hallway across the middle, the living room and a bedroom at the front. Is that the house you picture? A cat or no cat? Which room
  after the kitchen?
- The window is the sill's width (62 cm), so it is a tall narrow sash window, not a wide one: the sill's pieces had to stay. Say if you want it wider (that
  means a wider sill, a new round).
- The worktop is 4 cm under the sill board, so walking off the sill's front edge lands on the counter. Say if you would rather the sill be the counter's back
  edge (level with it).

## Everything to scale (ROBLOX-114, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/scale`. Nathan: "make everything to scale". 1 stud = 1 cm; every object in the world and every creature was checked
against its real size, with a source or a standard for each, in `docs/SCALE_AUDIT.md` (a table: what the game has, the real size and where it comes from, the
verdict, the change). The creatures were measured as drawn: `tools/preview/scene.py --lineup` stands them all on a ruler of 1 cm ticks and writes what each
measures. Fixed: the back door (a British standard 81 by 198 cm leaf with a glazed panel, a lower panel and a handle; it was a blank 85 by 200 slab), the
bed's grass (5 to 12 cm, blades 3 to 4.5 mm: it was a seedling's 1.4 to 3.2 cm) and the dandelion's flower (3.6 cm), the trees' trunks beyond the fences
(33 and 24 cm, not 56 and 47), the bungalows across the way (21 m from this house's back wall, not 40 cm behind the fence; a second ground under them, and
the hills behind them, lower), the fruit fly drawn at 2.9 mm (its golden scale drew it 4.4), the peacock spider growing to its real 5 mm and the ant mimic to
6 mm (they reached 6.8 and 7.4 at the adult stage), and the mates (the first spider's male mate at most 13.3 mm, the peacock's female 5.5). No physical box
moved, so `WorldMap.REVISION` is still world-3 and no save is affected. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-114)

1. **From the garden**: stand on the lawn about 6 m from the house and look at the back door: it should read as an ordinary back door beside the window (a
   glazed top panel, a panel below, a handle), not a wide blank slab. Screenshot it for Nathan.
2. **The view**: from the lawn and from the sill, the bungalows across the way should stand well back beyond the back fence (with their own gardens' worth of
   grass in front of them), not on the fence; the hills behind them low, not a dome. Say if the far ground shows a seam where the two grounds meet (z -1748).
3. **The bed**: the grass at the bed's edges should stand a hand high with seed heads, and the dandelion's flower should be a proper dandelion's size.
4. **The peacock spider and the ant mimic**: choose each at the crack; they are smaller at the first stage now (3.4 and 4.1 mm). Say if the camera frames them
   too far off, and if the peacock's fan still reads in the dance.
5. **The fruit flies** should be clearly smaller than the house fly (about 3 mm against 7).
6. **The self-test** as before: nothing in it should move (no box moved).

## Open for Nathan (ROBLOX-114)

- The window box on the outer sill is a miniature (2.8 cm tall, its black-eyed Susans 5 to 8 cm tall with 3.4 cm heads; real ones are 15 to 20 cm and 30 to
  100 cm with heads to 10 cm). A true one would shade the sill, whose light you asked to keep. Keep it, or a real box hung below the sill on brackets?
- The window's glazing bars (0.7 cm) and the raised sash's bottom rail (0.8 cm) are thinner than real ones (about 2 and 5 to 8 cm); widening them changes the
  sun's pattern on the sill. Keep them, or widen them?
- The kitchen floor is at the lawn's level (a real one stands at least 15 cm higher), because the sill is 90 cm over the garden and the worktop 86 cm over the
  floor. The tap (14 cm) and the toaster (18.6 cm long) are small. The dandelion's leaves (4.6 cm) are shorter than any real one's (5 to 45). Each is a box
  something walks on; say which to change in a round of their own.
- Golden and left as Godot has it: the first spider's first stage is 10 mm, already an adult's size (a spiderling is a few millimetres); the Pilea's stalks
  are 1 cm boxes (real ones 2 to 4 mm); the planter is a 14 by 8 cm trough.

## The preserve's skeleton: two worlds, the backdrop, the trains, lock-on to L2 (ROBLOX-115, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-a`. Phase A, round 1 of `docs/PARK_WORLD_DESIGN.md`. The engine runs either of two worlds (`World/Worlds`):
the **Test Garden** (everything built in ROBLOX-94..114, unchanged, still the default and the published game) and the **Preserve**, chosen by the Workspace
attribute `World` = "preserve". In the preserve the only walkable thing is the same windowsill, now the north window of a log ranger hut; everything else is a
drawn backdrop of the whole 100 by 60 m preserve and the city round it (`World/Preserve`, `World/PreserveLook`), streamed on each client by distance (near
whole, the rest as its masses: 797 parts from the sill at the full tier, 476 at the low), with commuter and freight trains passing on the railway every few
minutes (`World/PreserveTrain`, `Client/TrainPass`; their rumble, `assets/audio/train.wav`, is not uploaded yet). On a controller **L2 / LT is the lock** (a
tap locks and lets go; held past 0.35 s it is Focus) and **R3 only recentres**. Saves kept in the preserve name their world; a test garden save is written
byte for byte as before. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-115)

1. **The test garden first, unchanged**: open the place as it is and press Play: Output says `[Windowsill] world: The Test Garden (test_garden)`; everything as
   at v38. Run the self-test as usual (`workspace:SetAttribute("SelfTest", true)`): its first INFO line is `world: test_garden (revision world-3)` and it should
   pass as before (39 checks, the lock's now also taken with an L2 tap).
2. **The preserve**: in Studio's command bar (edit mode) `workspace:SetAttribute("World", "preserve")`, then Play. Output says `world: The Preserve
   (preserve)`. The title drift comes in over the hut garden's herb beds to the hut's window; the intro is the sill's. On the sill, look out of the window:
   the hut garden, the bird feeder and the lamppost, the meadow's grasses beyond, the pond to the right, the railway bank and the towers on the horizon.
   Screenshot the view from the sill, the title drift and (from the camera with the spider anywhere) the hut from outside, for Nathan.
3. **The haze**: say how the far preserve reads in Roblox's own Atmosphere (density 0.30, as the lighting is): the meadow is 13 to 43 m out, the railway 55 to
   60 m. If it is lost in the haze, say so; the lighting is Nathan's to change, not ours.
4. **A train**: within about two minutes of joining one comes out of a covered way and runs along the bank behind the bramble (a silver commuter or a rust
   freight); another every two and a half to five and a half minutes. Say whether it moves smoothly, and the frame time while it passes.
5. **The self-test in the preserve**: with the World attribute still "preserve", `workspace:SetAttribute("SelfTest", true)` and Play: 15 checks, among them
   `the hut's sill`, `the backdrop near and far` and `the trains`; none of the garden's. Paste the INFO lines (the parts held, the census) for Nathan.
6. **Lock-on to L2** (a controller): look at a fly on the sill and tap LT / L2: the lock takes it (the four faint ticks); tap again: it lets go. Hold LT:
   after a moment the Focus view (the telephoto field); let go: back. Press the right stick: the camera recentres and a lock lets go; it never takes a lock.
   Open the controls card (the life menu's Controls): "Tap LT lock on (stick circles)   Hold LT focus   RT slow-mo". R and the middle mouse are as before.
7. **A rest in the hut**: rest in the crack in the preserve, then switch the attribute back to the test garden and Play: the rest comes back at the sill's
   spawn with "the world has changed since you rested" (and the other way round). Then set the attribute back to nil (or "test_garden") before publishing.
8. **The train's sound** (when Nathan wants it): upload `roblox_port/assets/audio/train.wav`, grant it to the experience, put its id in
   `Client/TrainPass.SOUND` ("rbxassetid://<id>") and in the manifest.

## Open for Nathan (ROBLOX-115)

- The sill in the hut stands 85 cm over the ground outside and 70 cm over the hut's floor (the hut on a 15 cm base); the eaves 2.4 m over the ground. Say if
  you want the sill lower outside (the design's "~70 cm above the ground").
- The raised sash still opens onto the hut's outer sill, which is drawn only: a spider that steps out falls to the spawn. The sash shut until the spider is
  ready (the nursery) is Phase B, with the hut's inside (the desk, the notice board, the cat, the volunteers' room).
- The city's towers are impostors at the edge of the world (the precision rule keeps everything within 60 m): right from the hut and the meadow, small and
  near from the railway bank. Keep them, or a skyline painted on the sky later?
- The train's rumble is a procedural recording; upload it (checklist 8) or ask for another.
- On a controller Focus now starts 0.35 s after L2 goes down (a tap is the lock). Say if you would rather have Focus on another button.

## The ranger hut, walkable: the nursery, the way out, the hut garden (ROBLOX-116, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-b1`. Phase B, round 1 of `docs/PARK_WORLD_DESIGN.md`. In the preserve (the Workspace attribute `World` =
"preserve"; the published default is still the test garden) the ranger hut is walkable round the sill: its floor, the desk under its lamp with a drawer to
hide under, the notice board with a gap behind it, a bookcase of field guides, the chair, the door with a 1.5 cm gap under it; the window over the sill is
**shut** in a new save, and the ranger props it (a hand outside the glass lifts the sash and wedges it) on the first morning after the spider's first moult
has hardened, and it stays open in that save. Out through the window: the outer sill, the logs, the bench under the window, its leg to the ground, and the
hut garden's core right under the window (lawn, gravel path, a raised pollinator bed of milkweed, coneflower, bee balm and goldenrod, a herb bed, a trough,
the bird feeder on its pole) with gnats, aphids, springtails, leafhoppers, woodlice, a ladybird, a millipede and a harvestman. 40 regions in the preserve.
**Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-116)

1. **The test garden, unchanged**: Play the place as it is: `world: The Test Garden`; the self-test as before (39 checks).
2. **The preserve, a new save**: `workspace:SetAttribute("World", "preserve")`, Play, begin a new life. On the sill look round: the room behind you (the desk
   to the right with its lamp, the board to the left, the bookcase, the chair, the door), and out of the window the hut garden right under it. Walk at the
   window's middle: the spider climbs the shut sash's glass and does not get out. Walk off the sill's front edge: down the wall to the floor. Screenshot the
   room from the sill, the desk, the board, and the view out of the window, for Nathan.
3. **The ranger's moment**: the quickest way is the self-test (checklist 6), which makes the rule true for a moment. To see it in play, feed the spider to
   its first moult (five houseflies' worth in Normal) and wait for it to harden (10 hours of its day) and for a morning (7:30 to 9:30): a hand comes up
   outside the glass, lifts the sash and wedges it, about six seconds. Say how it looks and whether it reads as a person (a sleeve, a forearm, a hand).
4. **The way out**: through the gap beside the wedge onto the outer sill; over the outer sill's front edge and down the logs to the bench's seat (or drop a
   line from the edge: 40 cm onto the seat); over the seat's edge and down its leg to the lawn. Try the door's gap from inside: the spider passes under the
   leaf onto the step and the gravel (beyond it the next round's path; walking off the gravel's edge puts it back).
5. **The garden from a spider's height**: walk into the pollinator bed (milkweed, coneflower, bee balm, goldenrod, under mulch); climb the milkweed; find the
   aphids on its leaves and the ladybird among them; the leafhoppers on the goldenrod; the springtails by the bark chip; the woodlice by the trough. Rest
   under the trough, the stone and the bark chip. Say what reads wrong at true scale.
6. **The self-test in the preserve**: `workspace:SetAttribute("SelfTest", true)` with World "preserve", Play: 62 checks (every region's, the nursery's two,
   the hut's inside, the way out, the hut garden, the homes, the lamp, the window put back). Its opening of the window is never saved. Paste the INFO lines.
7. **Streaming**: with the spider in the garden's far corner (the goldenrod) the hut's lower wall and the sill should still be drawn (the backdrop stands in
   for streamed-out boxes, a hair behind them); and from the sill, the garden's far beds' plants may not be there until the spider comes near (their boxes
   are the look). Say if anything pops or is missing, and the frame time in the bed and in the hut.
8. **The lamp**: at night (the clock past dusk) the desk lamp lights the desk. Say how it looks; the hut's light by day is Roblox's own through the windows.
9. Set the World attribute back before publishing (the published game stays the test garden until Phase B ends).

## Open for Nathan (ROBLOX-116)

- The nursery ends at the first moult hardened, on a morning, not after a number of days (`Life/Nursery`, `docs/DECISIONS.md` ROBLOX-116 says why). Say if you
  would rather it opened after a number of days too, for a spider that cannot feed.
- The hut garden's core sits right under the north window (4 by 4 m, z 5..9 m), not a metre further out as the plan had it, so the window looks onto it and the
  way down lands in it.
- The walls are walkable to 1.3 m inside and 1.15 m outside; above that the spider is put back. The ceiling, the upper walls and the volunteers' back room with
  the cat are round 3 (a doorway in the east wall).
- The rival and the mate still keep to the sill; the rival walking the garden, the corridor round the hut's east end and the hut's own prey (fruit flies, the
  moth at the lamp) are round 2. No hoverfly yet (it needs its page).
- The sash's sound and the ranger's footsteps: none (no recording yet). Say if you want them.

## The hut garden rich at the spider's eye, its life, the path round the east end (ROBLOX-117, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-b2`. Phase B, round 2 of `docs/PARK_WORLD_DESIGN.md`. In the preserve (the Workspace attribute `World` = "preserve"; the
published default is still the test garden) the hut garden is drawn at true size where the spider is: the ground near it is cut into patches (`World/Hut.patches`)
drawn only within about 20 studs at full detail and 42 thinner (`World/LookPlan`): tufts of grass blades with seed heads and clover on the lawn, layered shredded bark,
leaf bits, twigs and seeds on the bed, gravel stones on the paths, husks and a cardinal's feather under the feeder, petals under the flowers, dew in the morning. Each
of the bed's plants has a second beside it and every plant is drawn whole over its boxes (leaf blades, umbels, rays and cone, whorled heads, plumes). The rival and the
mate come into the garden (the rival on the gravel path from the north, the mate from round the hut's east end) and roam its cells across their seams, never the hut.
Hoverflies hover and dart over the flowers (a new page); fruit flies at a compost caddy by the door; a moth at the desk lamp from dusk. A gravel path now leads from the
door's gap round the hut's east end into the garden. The low tier's far looks are thinner, so both tiers stay in budget. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-117)

1. **The test garden, unchanged**: Play the place as it is: `world: The Test Garden`; the self-test as before (39 checks).
2. **The preserve, the garden at the spider's eye**: `workspace:SetAttribute("World", "preserve")`, Play; the quickest way into the garden is the self-test (checklist
   6) or a save with the window open. Walk the spider into the pollinator bed's mulch by the milkweed, onto the lawn by the stone, along the path, to the feeder's foot.
   Screenshot each from the game camera and from the eye view for Nathan. Say how the blades, the bark and the gravel read in Roblox's own materials (the previewer
   has none of their textures), and whether blades or chips pop in as the spider walks (they are built at most 120 a frame within about 20 studs).
3. **Frame time in the garden**: at the full tier the looks are at the 1,500-part budget there (about 650 of them the patches). Say the frame time standing in the
   mulch and walking across the lawn, and at the low tier.
4. **The dew**: set the clock to dawn (the self-test does: hour 6) and look at the blades by the spider; by noon the drops are gone.
5. **The path round the east end**: from inside, pass under the door's gap onto the gravel, turn east along the hut's south wall, round the corner and north along the
   east end into the garden's own path. Say if the gravel's edge or the lawn beside it reads wrong, and whether the backdrop's gravel shows through anywhere.
6. **The self-test in the preserve**: `workspace:SetAttribute("SelfTest", true)` with World "preserve", Play: 72 checks, among them the garden's near detail and the
   garden's rival and mate. Paste the INFO lines (the patches and parts held, the dew, where the rival and the mate went).
7. **The rival and the mate**: in a long life in the garden, the rival comes in on the gravel path from the north end of the garden (from day 2, after the first
   meal, from 07:00); a mate (when the spider is grown and well fed) comes in along the path from round the hut's east end. Say whether they cross from cell to cell
   smoothly at the seams, and whether either is ever seen standing in the air (a cell not streamed in).
8. **The hoverfly**: on the coneflowers and the goldenrod; it holds still in the air a moment and darts. Say whether the hover reads, and whether the notebook's
   hoverfly page opens at the first close look.
9. **The hut's prey**: the fruit flies at the green caddy by the door (east of the doorway on the floor), and at night (the clock past dusk) the moth at the desk
   lamp.
10. Set the World attribute back before publishing (the published game stays the test garden until Phase B ends).

## Open for Nathan (ROBLOX-117)

- The garden's near detail is a budget: about 90 parts for every 25-stud patch within 20 studs of the spider, 10 for those to 42, at most 700 parts at the full tier
  and 100 at the low. Say if you want it thicker (the cost is frame time on phones) or thinner.
- The rival and the mate roam only the sixteen cells of the hut garden, and only while the spider is in a cell beside theirs (elsewhere they wait where they are:
  their ground may not be streamed in). They never go into the hut, even after the window is open; say if the rival should follow the spider up the bench and the logs.
- The hoverfly does not yet make the spider hesitate for its bee look (the bestiary's idea); it is a meal like any fly. Say if you want the hesitation.
- The hut's own prey is fruit flies at a compost caddy and the moth at the lamp; the house flies at the window are the sill's, as before.

## The ceiling, the back room and the ranger's cat, the eaves, the meadow path; the preserve is the game (ROBLOX-118, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-b3`. Phase B, round 3 of `docs/PARK_WORLD_DESIGN.md`. **The preserve is now the default world**: a place that does not author the
Workspace attribute `World` runs the preserve; `workspace:SetAttribute("World", "test_garden")` before Play reaches the test garden. In the hut the walls are walkable to a ceiling of
boards on joists 2.2 m over the floor (nothing puts the spider back any more), with a house spider's web in the north-west corner (drawn); outside, the north face to the soffit,
the fascia and the gutter (the roof's slope is drawn only). Through a doorway in the hut's east wall is the volunteers' back room: a sofa (the gap under it a home), a television on a
low unit with a games console, the controller on the cushion, a shelf of board games, a rug, an oil-filled radiator under the east window, cables along the skirting; fruit flies
drift in from the caddy, a moth comes to its window at night. The ranger's cat lives in the two rooms on a seeded day: asleep on the sofa or the chair much of the day, about at dawn
and dusk, at its bowls, by the door, on the rug, sitting on the back room's window sill. Its bell is heard (as a caption; the recordings are not uploaded) before it is seen; it
notices what moves near it and pats at it; in Normal a pat that lands kills (its own card), on Easy and Free play it knocks the spider aside. The path round the hut now goes round the
back room's east end (the preserve's revision is preserve-2), and a gravel path goes on north from the garden toward the meadow. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-118)

1. **The default world**: open the place as it is (no World attribute) and Play: Output says `[Windowsill] world: The Preserve (preserve)`; the splash and the title card drift
   over the hut garden to the hut's window; the title card's line reads "A small life in a city's nature preserve." Begin a new life: the intro opens inside the hut, from the room
   over the sill, looking out of the window; then the sill and the spider stepping out of the crack. Screenshot the intro's first frame and the title card for Nathan.
2. **The test garden still**: `workspace:SetAttribute("World", "test_garden")` in the command bar before Play: everything as at ROBLOX-117 (its self-test 39 checks). Set it back to nil.
3. **An old save**: Continue a life whose last rest was kept in the test garden (any published save): it comes back at the hut's sill with "the world has changed since you rested".
4. **The ceiling**: walk the spider up a wall of the hut past 1.3 m (it is no longer put back) and round onto the ceiling; walk head down across the boards and the joists to the
   north-west corner (the house spider's web over the notice board). Say how the wall-to-ceiling corner reads to the motor and the camera, and the frame time up there.
5. **The back room**: walk from the hut's floor through the doorway in the east wall (the caddy's corner). Climb the sofa, the television's unit, the games' shelf and the
   radiator; go under the sofa and rest there (its home: "under the sofa"). Screenshot the room from the floor and from the sofa's arm. Say what reads wrong at true size.
6. **The cat**: from the start of a life it is asleep on the sofa; watch it over a day (or set `life.clock.hour` through a hook) walk to its bowls by the front door, the window,
   the rug, the chair at the desk. Turn Captions on: "[a small bell, ...]" while it walks near. Walk in front of it while it is awake: it stops, its head follows the spider, it
   crouches and pats. Get up on the desk, into a home, or keep still: it gives up. In Normal a pat that lands ends the life ("The cat's paw came down."); try it on Easy too (a
   knock aside and a notice). Screenshot it asleep, walking, at the window and close to its face; say how it moves (the walk's legs, the tail, the breathing, the slow blink), and the
   frame time with it on screen (62 parts moved each frame).
7. **The eaves**: from the outer sill climb the logs past the casing to the soffit, round onto the fascia and down into the gutter; walk the gutter its whole length (x -205 to 503.5).
8. **The paths**: from the door's gravel round the back room's east end to the garden; from the garden's north path north toward the meadow (4 m of gravel; off its edge the
   spider is put back, as on every path).
9. **The self-test in the preserve** (no attribute needed now): `workspace:SetAttribute("SelfTest", true)`, Play: 133 checks, among them `the ceiling and the upper walls`, `the back
   room`, `the eaves`, `the cat` and a region check for each of the 105 regions. Paste the INFO lines (the cat's notice, crouch and giving up, the bell's level).
10. **The cat's sounds** (when Nathan wants them): upload `roblox_port/assets/audio/cat_bell.wav` and `cat_purr.wav` (made by `tools/make_cat_sounds.py`, not recordings of a
    cat), grant them to the experience, put their ids in `Client/CatBody.SOUNDS` and the manifest.

## Open for Nathan (ROBLOX-118)

- The cat keeps to the floor, the sofa, the chair and the back room's window sill; it does not jump onto the desk or the bookcase (so they are the way out up high). Say if it should.
- Its pat in Normal kills at once. Real cats often bat a small thing about first; say if you want a first pat that only stuns.
- The roof's slope is drawn only (a box cannot be pitched at 35 degrees); its walkable edge is the fascia and the gutter. Say if you want the roof walkable (it needs a mesh or steps).
- The house spider in the ceiling's corner is drawn, not a hazard; a tangle web that catches a jumping spider would be its own round with its own page.
- The back room's window has no outer sill and its outside wall is not walkable (only the north face is); the cat never goes out.
- The bell and the purr are captions until the recordings are uploaded.

## The meadow's edge and the bench, bin and lamppost; the crab spider (ROBLOX-119, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-c1`. Phase C, round 1 of `docs/PARK_WORLD_DESIGN.md`. Where the garden's gravel path comes out (4 m north of the garden,
z 13 m) there is now a bench patch of fine gravel (3 by 3 m) with a park bench facing the path, a litter bin with a drinks can and a crisp packet by it, a lamppost whose lantern
lights at dusk, and a drain grate; north of it a 5 by 5 m edge of the wildflower meadow at true size: big and little bluestem clumps up to 1.1 m, black-eyed Susan, yarrow, milkweed,
coneflower, bergamot and goldenrod, an ant hill, a curled dead leaf. Every culm, leaf and flower head can be climbed. Homes: between the bench's seat slats, under the bin's lip,
under the curled leaf. Life: leafhoppers on the bluestem, house flies and hoverflies on the flowers and at the bin, moths on the grass heads and at the lantern from dusk, ants at
their hill (not food). Two goldenrod crab spiders sit on a goldenrod and a yarrow, legs open: walk or land within their reach and they grab (a death in Normal, a drop clear on Easy
and Free play). The rival now roams up the path to the meadow's edge. Fixed on the way: no hoverfly ever perched (here or in the hut garden), the moths at the desk lamp and the
back room's window never perched, and a spider on a coneflower's cone or a goldenrod's plume stood inside its drawing. **Nothing of it has run in Studio.**

## Your Studio checklist (ROBLOX-119)

1. **The way there**: from the hut garden walk north up the gravel path (4 m) onto the bench patch's gravel; across it to the meadow's edge. Say how long it takes and how the
   gravel and the mown edge read at the spider's eye; screenshot the meadow from the gravel, at the spider's height.
2. **The meadow**: walk in among the grass; climb a big bluestem culm to its turkey-foot head (about 1 m up), a coneflower to its cone (74 cm), a black-eyed Susan. Say how
   the motor takes the 5 mm culms and the bent blades, and what the spider can see from a flower head. Frame time in the grass (the patches and the clumps' blades).
3. **The crab spiders**: find the yellow one on a goldenrod's plume (it changes plume by the day) and the white one on a yarrow. Can you see it before you land? (its legs held
   open, its colour a shade off). Land beside it in Normal: "The crab spider's legs closed."; on Easy: a lunge, a drop clear and a notice. The first close look opens its
   notebook page. Screenshot each, close.
4. **The bench, bin and lamppost**: climb a bench leg to the seat (45 cm), rest between the seat slats (its home); rest under the bin's lip; climb the lamppost to the lantern
   (3.4 m); go down through the drain grate's slots into the pit. Screenshot the patch by day.
5. **Night**: set the clock to night (or wait): the lantern lights (a warm light reaching 60 cm round it) and moths come to its glass; the meadow's moths stir on the grass heads. Hunt
   at the lamp. Screenshot it; say whether the light reads and how far.
6. **The ants**: by day at the hill in the meadow (two metres east of the curled leaf) six ants wander and turn back to the hill; a strike at one is refused. By night they are gone.
7. **The rival**: it may come up the path to the meadow's edge now; say if it reads in the grass.
8. **The flies that never perched**: in the hut garden, hoverflies now settle on the flowers; at night a moth sits at the desk lamp and at the back room's window.
9. **The self-test** (`workspace:SetAttribute("SelfTest", true)`, Play): 177 checks, among them `the bench patch`, `the meadow's edge`, `the crab spiders` and a region check for
   each of the 146 regions. Paste the INFO lines and the frame and part counts.

## Open for Nathan (ROBLOX-119)

- The bird's shadow over open ground is not built (the wasp is the open-ground danger for now); a cricket is not built (no source opened yet). Next round, with ballooning?
- The crab spider never leaves its flower in a day and does not hunt the meadow's flies; it kills at once in Normal. Say if a near miss (it lunges, the spider escapes if it
  was moving) would be better.
- At the low graphics tier the meadow is its culms and its clumps' crowns only (the blades and the thatch are the full tier's); say how it reads on a phone.
- The bench patch moved from the plan's x 40, z 16 to where the path comes out (x 45, z 14.5), and the meadow's core from x 31, z 40 to its near edge (x 45, z 18.5).

## The robin, the field cricket and ballooning (ROBLOX-120, 2026-10-20)

Claude → Chet, 2026-10-20, branch `claude/preserve-c2`. Phase C, round 2 of `docs/PARK_WORLD_DESIGN.md`. An American robin, 25 cm from bill to tail, now visits the open ground
four to six times a day: the hut garden's lawn either side of the path, the bench patch's gravel and the meadow's mown edge. It is told first by its shadow, a bird's cross sweeping
over the ground as it glides in, and its call ("pick, tut-tut-tut", a caption); then it lands, hops and stops with its head cocked, pecking now and then. A spider that moves in the
open near it is seen: it hops closer, stops dead with its head cocked at the spider (the tell, under a second), and strikes. Normal: "The robin's bill came down."; Easy and Free:
it misses. Keeping still, a home, anything over the spider (a leaf, the flat stone, the bench) or the meadow's grass low down is the way out. Field crickets live in the meadow's
thatch (three cells) and the pollinator bed's mulch: they sing from dusk (a caption), fall silent and freeze when the spider moves within 30 cm, jump away when it comes close, are
worth three houseflies and kick hard in the jaws (about five taps a second to hold one). After a hatching in the preserve the card now offers "Follow one" (a twelve-second ride on a
spiderling's thread out of the window and over the garden on the wind, then the next generation begins where it comes down: the hut garden about three times in four, the
meadow's edge otherwise) or "Stay at the hut" (as before). Sounds made by `tools/make_meadow_sounds.py` (`robin_call.wav`, `cricket_chirp.wav`), not uploaded. **Nothing of it has
run in Studio.**

## Your Studio checklist (ROBLOX-120)

1. **The robin's shadow**: in the hut garden by day (from 06:00), stay on the lawn and watch for it: a shadow sweeping over, the caption "[a shadow sweeps over the ground]", its
   call; then it lands. Say whether the shadow reads (and whether Roblox's own light also casts one: the body casts none on purpose). Screenshot it coming in and on the lawn.
2. **The robin on the ground**: walk toward it in the open. It should hop at you, cock its head at you and pause, then strike: in Normal the card "The robin's bill came down.";
   on Easy "The robin stabbed at you and missed." and a jump aside. Try again keeping still when it cocks its head (it loses you), and again under the flat stone or a leaf, and in
   the meadow's grass. Say if the pause is long enough to see and react to, and if its reach feels fair.
3. **Its look**: close up, a grey-brown back, the rusty breast, a blackish head with the broken white eye ring, a yellow bill; screenshot it from the spider's eye.
4. **The crickets**: at night (22:00) in the meadow's thatch (cells b2, c5, d3) or the pollinator bed's mulch: the caption "[a cricket chirping, ...]". Walk toward it: it
   goes silent and still; come close and it jumps. Catch one: the struggle is long and it kicks (the grip jolts); say how many taps a second it takes on your device.
5. **Ballooning**: reach a hatching in the preserve (or restore a rest from one): the card says "Follow one" and "Stay at the hut". Follow one: the ride (12 s, the camera on the
   spiderling and its thread out of the window and over the garden), then the new spiderling stands where it landed with the notice "The thread came down in ...", the toast
   names the place, and the notebook's "Eggs, silk and wind" has the dated line. Say whether the ride reads and whether the world is streamed in where it lands.
6. **The self-test** (`workspace:SetAttribute("SelfTest", true)`, Play): 180 checks, among them `the robin`, `the field crickets` and `ballooning's landings`. Paste the INFO lines.

## Open for Nathan (ROBLOX-120)

- The robin's numbers are the game's: it notices a moving spider within 70 cm, reaches 16 cm, pauses 0.85 s, and loses one that keeps still for 1.2 s; four to six visits a day.
  Say if it should come more often or less, and whether a death without a near miss is too hard in Normal.
- The robin is the open ground's bird; the design's other birds (a treecreeper on the oak, the heron) wait for their zones.
- A mate still comes only to the hut garden, and the egg sac and the hatching are still drawn in the sill's crack wherever the spider rested: a lineage that ballooned to the meadow has its family at the hut. Say if the mate and the sac should follow the spider's home.
- Ballooning lands only in the hut garden and the meadow's edge (only built zones); the pond, the oak and the wall join as they are built.
