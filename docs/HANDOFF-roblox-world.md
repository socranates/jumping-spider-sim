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
