# Open world design: one continuous garden

Nathan (2026-10-19): "I want to begin developing a huge open world sandbox for this game." Shape: **one continuous
garden** — the sill stays the home, the window opens onto a seamless world streamed around the spider. Sandbox means
**all four**: free-roam survival everywhere, building and territory, a shared world with other players, and a creative
mode. This document is the architecture and the road; the rounds that build it are listed at the end. The first round
(ROBLOX-94..96) is the world core and the first garden chunk you can walk into from the sill.

## Scale, in the game's own units

1 stud = 1 cm (Godot WU = cm, kept in the port). The sill is 60 × 25 cm. A garden bed under a window, the grass beside
it, a stone path and the shed wall at the end is **about 3 × 4 m = 300 × 400 studs**, roughly eighty sills. To a
one-centimetre spider that is a continent, and it is still authored and knowable, which is why it beats endless terrain
for this game: every retreat, stone and flower head can be a place with a name in the notebook.

Part cost is the constraint. The sill carries about 1,150 decor parts on 1,500 cm²; the garden at that density would be
~70,000 parts. So the world is **regions** with their own budgets, built once, and **streamed** around the player.

## Architecture

### Regions (`Shared/World/`)

- **`WorldMap`**: an authored list of regions. A region: `id`, `kind` (sill, outer_sill, house_wall, bed, grass,
  path, flower, shed_wall, pond_edge — the kinds grow), `origin` and `bounds` (world studs, the sill at the origin
  exactly as today), `seed` (world seed ⊕ region id), `neighbors` with the **seam** between them (the face line where
  one region's walkable surface meets the next), `retreats` (box volumes: the sill's crevice, a gap under a stone, a
  curled leaf, bark), `spawn` (where a life starts in this region, used when a save says so).
- **Generators**: `World.pieces(region)` and `World.decor(region)` are **pure and deterministic** from the region's
  seed: the same seed gives the same boxes forever, on the server and on any client. The sill's generator returns
  `WindowsillLayout.PIECES` and `DECOR` unchanged (byte-identical sill, every existing save valid). Every other kind
  is a seeded placer (soil mounds as boxes, litter leaves, grass tufts, stones, stems and leaves, a flower head) that
  respects a **per-region part budget** at full and low tier (the `Detail` tiers as today).
- **The world's solid surface is boxes.** The motor walks box faces (raycasts); the rival's route graph is built from
  boxes; prey perches sit on boxes. Roblox Terrain is tempting for soil and grass and may come later as a backdrop
  only — nothing the spider walks on, so the navigation stays exact.

### Building and streaming

- **The server builds every region at startup** from the seed (solid pieces under one `World` folder that the motor's
  raycast filter includes; decor beside it). Deterministic generation means a rebuilt server is the same world.
  Generation for the v1 map is a few seconds and ~30–60k parts in total.
- **Roblox `StreamingEnabled`** streams parts near the player: `ReplicationFocus` = the spider's root (there is no
  character), `StreamingMinRadius` large enough that everything the motor can raycast at is present (the active
  radius: the player's region and its neighbors), `StreamingTargetRadius` a region further for the camera. Low-tier
  devices get the same world with thinner decor (the regions' low budgets).
- **The client sim stays client-side** (life, prey, wasp, rival, mate), exactly as today; it reads the same seeded
  region data for navigation, never the parts. AI creatures are **bound to a region** (the rival and the mate to the
  player's home region unless they are following the player across a seam, which is a later round).
- **Why server-built:** it is the same world for every player in the server — the shared-world pillar needs that —
  and it keeps the client's part creation to the spiders and the flies.

### Navigation per region

- `RivalRoute` becomes **region-scoped**: a graph from that region's pieces, plus **seam edges** to the neighbor
  regions (the wall's foot meeting the bed; the outer sill's edge meeting the wall). A creature plans within its region
  and crosses a seam like any other edge. `PerchGraph` (prey) and the wasp's offsets are generated per region too.
- Graph size matters (Dijkstra per replan): regions are sized so a region holds ≤ ~60 boxes; big zones are several
  regions (the chunk grid, 50 × 50 studs in the bed).

### Retreats and homes

- `World.inRetreat(p)` replaces `Layout.inRetreat(p)`: any region's retreat volumes. A rest anywhere a retreat is;
  the **home** retreat is where the last rest was (the save records region + retreat id). The crevice is the first
  home; a stone in the bed is the first garden home.

### Persistence (the rule that keeps saves small and old saves alive)

- The checkpoint keeps capturing the **sim graph** (life, needs, growth, rival, mate, mating, wasp, prey, notebook) and
  the player's position — and gains `world = { seed, revision, region, retreat }` plus a **diff log**: the world is
  never saved; only what changed in it (a stone turned over, a silk retreat spun, a claimed territory, a creative
  placement). Validation: unknown region → refused like any bad record; absent `world` (every save before this) →
  the sill, seed 914, no diffs. The world revision gate: a save made on a different world revision restores at its
  region's spawn, not its position (geometry may have moved).

### Time runs slower out there

Nathan: "time should flow much slower in the big world." Every region carries a **`clockScale`**: the sill keeps its
brisk day (1.0, the tutorial pace Nathan tuned); the garden runs at **0.25**, so a garden day is four times longer in
real minutes. The life clock's own rates (awake, asleep, moult) are Godot's and stay golden; the scale is a game rule
(`LifeClock.game.clockScale`, set from the player's region each frame, never saved — hours are state, the rate is
not). Hunger, the wasp's windows, the rival's and the mate's arrivals, dew and dusk all run on game hours, so they
stretch with the day: an afternoon of exploring is an afternoon, not a race to the crack before dark. The dial is
per region in `WorldMap`, so a deeper zone can be slower still.

### Camera, motor, bounds

- Play bounds become the world's union (or per-region) — the motor's fall-off floor is the bed's soil, not the sill
  floor. `LineFraming`, the dragline, the jump planner, the eye view and Inspect are unchanged: they raycast.
- Far regions that are not streamed are simply not there; the camera's boom cast handles absence.

## The world map, v1

Coordinates continue the sill's frame (x across, y up, −z out of the window). The sill floor top is y = 0.

| Region | Where | What |
| --- | --- | --- |
| **sill** | as today | unchanged; the sash is now **raised 6 cm** (the back frame gets an opening x −8..8, y 0.7..6) |
| **outer_sill** | z −13.5..−24, y 0, x −30..30 | the stone outer sill, weathered paint, moss in the corners |
| **house_wall** | z −24, y 0 → −90, x −40..40 | brick courses with recessed mortar (climbable faces), a drainpipe later |
| **bed_a** | y −90, z −24..−74, x −25..25 | soil mounds, leaf litter, grass tufts, three stones (one a retreat), two plants |
| **bed_b, bed_c …** | the chunk grid outward | the grass forest, the stone path, the flower heads (rounds 2+) |
| **shed_wall** | z ≈ −400 | the far cliff; bark crevice retreats, the way up (round 3+) |

The **descent** is the set piece: the spider reaches the outer sill through the gap, finds the wall, and goes down
90 cm of brick on its dragline (the hang pose, the head-up climb back). The bed under the window is where the garden
starts; the rest is further out.

## Nathan's direction (2026-10-19), as rules

In his words: think to some extent RPG; minimal HUD; more prey, random bugs, environment details, more rival males and
other spider species; so serene you forget you are prey too, but not too long before you are reminded; eventually more
MMO; hunger always a major concern; movement expends more energy; if you die you lose everything from that day;
beautiful and scary like nature; sometimes you worry about starving because a wasp or other thing won't go away;
mating should not automatically be successful; Normal mode should feel like it doesn't want you to survive; no hand
holding. As design:

- **Normal mode is nature.** No mid-day saves, no hints after the first day, no softening. **Death loses the day**:
  you wake at the last rest with that day's meals, growth and sightings gone ("Back to last rest" is the only path;
  "another spider" is a true restart). Easy and Free keep ROBLOX-91's gentleness untouched.
- **Hunger is the engine.** Reserve drains with the clock as today *and with movement*: walking costs, jumps cost
  more, stillness costs least (a sit-and-wait hunter's economy, `NeedsModel.game.moveCost`). The garden's slow clock
  (0.33 in the bed, not 0.25, so hunger per real minute stays real) never makes food optional.
- **Pinned.** Threats can linger: a wasp that hunts the bed for hours, a rival that camps by the retreat. The choice
  between the risk outside and the bar draining inside is the game. Visit lengths and arrivals vary around their
  means from seeded streams so the cadence never reads as a schedule — calm long enough to forget, never so long that
  the reminder stops hurting.
- **Mating can fail.** The female may reject or drive off a thin or clumsy male (condition and courting quality set
  the odds), a rival may cut in during a court, a sac can be lost to a lingering predator in Normal. Nothing is
  automatic; the notebook tells the truth about it afterwards.
- **Breadth** (content rounds): prey — gnats, aphids, leafhoppers, moths at dusk, crickets; ambient bugs that are not
  food — ants, woodlice, beetles, ladybirds; several rival males at once; other spiders as neighbours and dangers (a
  wolf spider on the soil, an orb-weaver's web as a hazard, a crab spider in a flower, another jumper as a rival of
  a different species).
- **Light RPG, quiet HUD.** Moults are the levels, the species is the class (the peacock's dance, the ant's disguise,
  the tarantula's threat), the notebook is the journal and quest log, territory is the endgame — and none of it adds
  a widget: the HUD stays the hunger bar, the day line and a caption. Reminders come from the world.
- **MMO direction**: the server-built, seeded world is the groundwork; player spiders replicate in a later round.

## Nathan's direction, continued (2026-10-19, playing v30 on the PlayStation)

In his words, with two screenshots of a peacock on a leaf and a greenbottle hanging under the Pilea while the wasp works the planter and the
rival waits on its wall: "I should be worried about hunger and watching out for the predators"; "the beautiful scenery and imminence of
death"; "you should want to explore but have to truly weigh the cost"; "a rival spider after me while I'm slow from moulting is amazing";
"vulnerability and predation"; "being perched up high avoiding predators and hiding under leaves"; "scared I won't make it home at night";
"points of man I gotta catch this fly or I'm gonna die, trying to be patient watching your life drain"; "then you hear a wasp"; "that's
exploration you gotta earn"; "you get time to enjoy the scenery because you are desperately ensuring that predator doesn't sneak up on you";
"trap door or funnel web spiders"; and of the scene itself, "scenes like this but with beautiful rich detail". As design:

- **Cover and height are real** (W3/W4). Predators hunt by sight lines, as the wasp already does: the underside of a leaf is cover from the
  wasp and from anything above; a high perch is out of reach of the ground hunters and gives the earliest view of what is coming, at the
  price of exposure to the sky. The spider is hidden when no predator's line of sight reaches it; standing still halves the chance of
  being noticed, moving in the open doubles it (the rival's notice logic, generalised). Nothing on the HUD says "hidden": the spider's
  own senses (the rear eyes, the hum, the shadow) are the readout, and the notebook explains how a wasp sees.
- **Home before dark** (W4). Night in the garden is the garden's own danger: a spider still out at dusk must reach any retreat or pass the
  night exposed, and in Normal an exposed night is a real risk (a seeded draw against the ground hunters, the cold, a bird at dawn). Dusk
  is told by the light and the day line, nothing else. The sill's crack and the stone in the bed are the first two homes; a silk retreat
  spun where the spider rests three nights is the territory round's.
- **Ambush at ground level** (W3+). Trapdoor spiders under the soil and funnel-web spiders in the grass are the garden's traps: a burrow
  lid and a funnel sheet that the eye can learn to read, a lunge when stepped on or walked past within reach, an escape that exists (the
  jump, the line). They are regional, seeded, and never on the sill. Each gets its sourced page.
- **Several rivals** (W3/W4). A rival male per two or three regions, each with its own route and its own days; two may meet the player in
  one afternoon and one may follow across a seam. A rival that finds a moulting spider is the moment Nathan named: the soft-skin window is
  when the rival notices most.
- **The look: beautiful rich detail.** The scenes are composed right (hiding under a leaf, the wasp on the planter, the rival on the wall);
  what they lack is richness. The garden's generators are built for it from the start, within the part budgets: Roblox's own PBR
  materials for soil, bark, stone and terracotta instead of flat colour; real leaf shape (a drawn rim, veins, a curl, a lighter underside,
  as the Pilea has) for every plant; weathering and litter everywhere the eye rests; Terrain as the backdrop under the walkable boxes (soil,
  grass with its animated blades) where it costs no parts, never as a surface the motor walks; meshes from the Creator Store built on the
  server where `InsertService:CreateMeshPartAsync` allows, for stones and leaves that boxes cannot be; textures and sounds uploaded through
  Nathan's browser, the way the music was. The sill gets the same pass when the window opens (W2), so the old home is not the plain one.
  The previewer judges shape and placement only; richness is judged in Studio and on the television.
- **Quiet HUD, continued** (W5). In the screenshot three "lost sight" labels stack on the soil: the perception captions must not pile up
  (one at a time, the newest wins, gone in a breath), and nothing is added for the garden but the region's name on the day line.

## The four pillars, as rounds

1. **Free-roam survival everywhere** (this round and the next): regions, streaming, nav per region, retreats anywhere,
   prey per region, the clock and weather everywhere; the wasp and the rival follow later.
2. **Building and territory** (round 3): the diff log gains player-made things — a silk retreat spun where the spider
   rests three nights, an egg site, draglines left behind (others can follow them), a **territory** claimed by
   presence and defended against the rival. The world remembers what you made; the notebook maps it.
3. **Shared world** (rounds 4–5): the server-built world is already shared; player spiders replicate (the two-player
   design's referee grows into a world server: contested moments stamped by the server, each player's sim local).
   Neighbours, rivals, mates — other people.
4. **Creative mode** (round 6): a placement layer that writes region overrides into the diff log (plants, stones,
   prey, predators) with an in-game palette; play in what you shaped; share a world by its seed + diff.

## This round's plan (W1–W5)

1. **W1 — the world core** (ROBLOX-94): the sill as region 0, WorldMap/Region/WorldBuild/WorldClient, server build,
   streaming, the world record in the save, `clockScale`. The game plays identically. *(Done 2026-10-19: ROBLOX-94 in
   `docs/DECISIONS.md`, Chet's checklist in `docs/HANDOFF-roblox-world.md`; CLI only, not run in Studio.)*
2. **W2 — beyond the glass** (ROBLOX-95): the raised sash, the outer sill, the brick descent, bed_a, per-region nav. *(Done 2026-10-19: ROBLOX-95 in
   `docs/DECISIONS.md`, Chet's checklist appended to `docs/HANDOFF-roblox-world.md`; CLI only, not run in Studio.)*
3. **W3 — garden life** (ROBLOX-96): prey in the bed (gnats and aphids join the flies), woodlice as the first ambient
   bug, the stone retreat, the descent set piece, the page, saves across regions. *(Done 2026-10-19: ROBLOX-96 in
   `docs/DECISIONS.md`, Chet's checklist appended to `docs/HANDOFF-roblox-world.md`; CLI only, not run in Studio.)*
4. **W4 — nature's rules** (ROBLOX-97): movement cost, death loses the day in Normal, lingering threats, mating that
   can fail, the garden's slow clock. *(Done 2026-10-19 as ROBLOX-106, the number 97 never having been used: movement's cost, the
   lost day's words, the wasp's sliding and lingering visits, the rival's watch by the crack, courtship that can fail and the rival
   that cuts in, home before dark, cover; the bed's clock was already 0.33 (ROBLOX-96). In `docs/DECISIONS.md`, Chet's checklist in
   `docs/HANDOFF-roblox-world.md`; CLI only, not run in Studio. The footfall and the other rare things are still to come.)*
5. **W5 — no hand holding** (ROBLOX-98): the HUD and notice audit for Normal — hints only on day one, captions
   sparing, nothing added for the garden but a region name on the day line.
Then full suites, places, bundle, publish. *(Toward the publish, 2026-10-20, ROBLOX-109: the game's own splash, the start menu as a title card, the intro of a
new life, the cards in one typeface, and the store page's plan in `docs/STORE_PAGE.md`; CLI only, not run in Studio. ROBLOX-110: lock-on and the sidestep, the
spider keeping its prey in its principal eyes and sidling round it, taken only from what its senses have placed, and "Show what the spider notices" to turn the
perception HUD off, the lock's four faint ticks its only cue (W5's quiet HUD); CLI only, not run in Studio.)*

## Risks, named

- **Streaming with a custom focus** (no character): `ReplicationFocus` works, but the client's sim must never raycast
  into unstreamed space — the active radius must cover the player's region and neighbors, and AI stays regional.
- **Part budgets on PlayStation and phones**: per-region budgets, the low tier, and later impostors for far regions.
  *(2026-10-20, ROBLOX-108: the regions' looks are made on each client near its spider, at most 1,500 parts at full and 500 at low (3,647 and 1,215 were
  always there), the region and its neighbours always, the house's walls as far impostors (a few big brick-coloured parts), the rest nearest first within a
  radius; a PlayStation is the full tier; the house fly is lighter at low. Not run in Studio or on a device.)*
  *(2026-10-20, ROBLOX-111: v36's Studio self-test measured the bed at 22 fps and the sill at 60. The CLI finds no cause in the client's Lua; the self-test
  now times the client's frame by part and samples the bed again settled, without the looks and without shadows, so the next Studio run names the cost.)*
- **The 200-local client**: the world wiring is a new module (`Client/WorldClient`), not more lines in SpiderClient.
- **Save format**: `world` is optional and validated; the revision gate protects positions.
- **Nav graph size**: region sizing; seams are the only cross-region edges.
- **Nothing has run in Studio since main ce64498**: this round rides on the audit's green suites and the previewer.
  *(2026-10-19, ROBLOX-104: the live place now carries a self-test, `src/Client/SelfTest.luau`, that walks the regions, the line, the prey, the
  notebook, a rest and the sound inside a real Studio Play session and prints a verdict for `tools/studio/selftest.ps1` to read; the coordinator runs it at
  each publish. Not yet run in Studio.)* *(2026-10-20: run in Studio at v36, 33 of 34 passed; the line's let-down ran at 0.559 studs a second, the fix and its
  counts are ROBLOX-111, and the self-test is now also the frame's profiler.)*

### Nathan's direction (2026-10-19, evening): the peacock as the main spider, the whole life as the game, the world, Steam

In his words: "The peacock spider should be the main spider i think and the game designed to be the whole life cycle to mating but very
hard, not even mating is a guarantee if you find the mate, etc. Huge detailed world, eventual steam port." And on the web-slinger
(`docs/WEB_SLINGER_DESIGN.md`): "Only honest play through should even be allowed to purchase. Works everywhere." As design:

- **The peacock is the main spider.** *Maratus volans* becomes the default appearance and the life's protagonist: the spider the game
  opens on, the one the notebook follows, the one whose courtship is the ending. This reverses ROBLOX-48's plan to sell the peacock as a
  ~US$0.99 cosmetic: the peacock is the game, so it is free; the sale ideas move to the web-slinger pass and the tarantula pass. The
  first spider (the daughter's black-and-white reference) stays in the game, free, in the picker, with its own page; nothing is taken from
  it. What changes when this is built: `Appearances.default`, the title and the Begin-a-new-life text, the rig the HUD and Inspect open
  on, the eye view's colour (the peacock's sight is the best documented of the three), a save migration (a record with no appearance
  keeps the first spider, so old lives are not recoloured), and the notebook's first pages. The science goes with it: the peacock's
  display, its scale (about 5 mm, so 1 stud = 1 cm is unchanged) and its real female (mottled grey-brown, ROBLOX-93's correction).
  Confirmed by Nathan the same evening: the peacock **replaces** the first spider as the default; the first spider stays, free.
- **The game is the whole life, to mating, and it is hard.** Normal is a full life: hatch, hunt, moult, grow, find a mate, court. The
  courtship is the climax and it can fail: the female may not come, may reject the dance (she turns, she walks, she strikes), may eat a
  male that misreads her; a failed courtship is not death unless she makes it so, and the season gives few more chances. That is W4's
  "mating that can fail" written large, and the peacock's real courtship (the fan, the third-leg waving, the vibration, the female's
  rejection and cannibalism) is the sourced model for it. Hard is Nathan's Normal; Easy and Free play keep the kids.
- **Huge detailed world.** The open-world plan stands (W3–W5, then the pillars), and the bar is "scenes like this but with beautiful rich
  detail" everywhere the eye rests, with the later levers (Terrain backdrops, meshes, uploaded textures) when the budgets allow.
- **Eventual Steam port.** A build outside Roblox, later. What it asks of the code now: keep the sim in `Shared/` pure (it is: the shim
  runs it in the CLI), keep the Godot goldens the source of truth (the Godot project is the natural Steam build, frozen today), and keep
  every Roblox service behind a module (`Server/*`, `Client/*`, `Persistence/*`). No work on it until the Roblox game is public.

Nothing here is built. Order after W3: W4 (nature's rules, with the courtship that can fail designed against the peacock), W5 (no hand
holding), then the peacock-as-default round, then the web-slinger.

Later the same evening: "More more more bugs and types of bugs and information on them." The garden's life is to be broad: many kinds of
prey, ambient bugs and small threats, each with its own sourced notebook page. `docs/GARDEN_BESTIARY.md` is the list to build from; it
becomes a round of its own (W3b, the bestiary) straight after W3, on W3's pattern (a derived profile or a small ambient sim, a body under
the part cap, a generated page with named sources), before W4. *W3b is built (ROBLOX-101, part A: springtails, leafhoppers, small moths, crane
flies; ROBLOX-105, part B: ladybirds, millipedes, a garden snail, harvestmen, as ambient bugs that are not food, each with its page); and the map has begun to fill outward, ROBLOX-107: the bushes beside the bed (`shrub_west`, ten chunks)
and the back wall west of the window with its drainpipe to the gutter, woodlice and springtails in their litter.*

And: "there are tons of cool spiders we can add and sell and give away, maybe even be the wasp and keep expanding the world until you
can participate as anything you want." As design, a fifth pillar after the four in `docs/OPEN_WORLD_DESIGN.md`: **be anything**. The
spider picker grows into a cast: more jumping spiders (sold, given away, earned; each a costume on the one honest body, each with its
sourced page, the web-slinger the one that changes the rules), then other spiders whose rules differ (an orb weaver that builds, a crab
spider that waits in a flower, the trapdoor spider in its burrow: each a new motor or a new sim on the shared world), then the wasp
(the mud dauber as the player: hunt the spiders the world already runs, provision a nest; the predator's eye as the game's hardest honest
life), then the rest of the bestiary as the world fills. Every playable kind is a sim on the same server-built world, so what one
player is, another meets (the shared-world pillar). Pricing stays Nathan's: some sold, some given away, some earned; the first spider,
the peacock and the full game free. Order: the open-world rounds and the bestiary first (the world must be worth being something in),
then the cast, one kind a round, each with its decision, its page and its tests.

And: "Tons of detail, Easter eggs, stuff you want to get to if you weren't terrified of everything lol." As design, the world's reward
structure: **curiosity against fear**. Everywhere the eye rests there is something to find, and the finding costs exposure: a dropped
coin under the leaf, a child's lost toy in the bed, a snail shell to climb into, a bottle cap with rain in it, the carved initials on
the sash, a ladybird's shed skin, a shard of glass that shows the spider itself, the far side of the wall where a different plant
grows. Each is a seeded placed thing (the diff log's `world_map.diffs` records what was found, so it stays found), each has a notebook
line or a page when it earns one (a shell is a real thing with a real page; the initials are a story, and say so), and each sits where
getting to it means time in the open, a climb, a drop, a crossing at dusk: the player's own curiosity is the thing the predators use.
Nothing on the HUD points at them (W5's rule); the spider's own senses and the scenery's composition do. They belong to the detail pass
of every region (the look's bar: "scenes like this but with beautiful rich detail"), two or three a region, one hidden well, and the
generators place them so a seed and a diff name the same world for everyone.

And: "Weather patterns eventually." As design: **weather**, seeded like everything else (a day's weather drawn from the world seed and
the day number, so everyone's Tuesday rains), with the game's own consequences and no new HUD. Rain: the bed goes dark and wet, drops
hit leaves (a drop is a blow to a 1 cm spider: cover under a leaf is real), the silk holds worse on wet glass and stone, the worms and
the snails come out, the flies stay in, the puddle appears and brings the midges; the sill behind the sash stays dry and the spider that
is home before the rain learns why. Wind: the plants move, the line sways, a jump is blown, the wasp does not fly. Heat: the stone and
the wall warm (a basking spot the spider seeks, the clock of hunger runs faster), the aphids multiply, the afternoon is quiet. Cold and
overcast: everything slows, the flies are torpid and easy, the spider's own jumps shorten (the sources on temperature and salticid
activity decide the numbers; nothing invented). Dusk and night already exist; weather is the next layer on `Habitat/DayLight` and
`SunPick` (the sky, the light, the sun's warmth) and on `LifeClock`'s rates, with the same honesty: the notebook's weather page says what
spiders do in rain and cold, sourced, and "In this game" says what the game does. Order: after W4's rules (hunger's movement cost and the
night are the base weather builds on), as its own round, W6 or so; the water in the bed (the saucer, the puddle) comes with it.

And: "Born in the windowsill. Slowly the world outside the windowsill unfolds." As design, the shape of a life and of the whole game:
**the sill is the nursery, the world is earned.** A life begins on the sill (born there: the sac in the crack, the spiderling's first
days inside the glass, where the wasp is the only danger and the flies come to the light); the window is closed at first and opens
when the spider is ready (a moult, or the first day it comes home before dark), and what is outside unfolds one region at a time as the
spider grows: the outer sill, the wall, the bed; then, round by round, the lawn, the flowers, the fence, the shed, the pond, the next
garden. A region a player has never reached is not on the map in the notebook; the day line never names a place the spider has not
been. The unfolding is the spider's (its growth and its courage open the sash and the seams), not a menu's; and it is the game's too
(each round opens one more region for everyone, and a long-lived save finds the world larger than it was). W2's open sash from the
start is the current state and the exception: when the nursery is built (with the peacock-as-default round, since the sac and the
spiderling are its story), the sash starts shut and opens on the spider's first readiness. The pacing is the thing to get right: slow,
as he says; the sill must be a whole small life before the garden is a promise.

And: "Get stepped on by a random human or animal like 1 percent of the time at random." As design: **the big world passes through**, and
it does not look where it steps. A footfall (a person on the path by the bed, a cat on the sill, a dog in the garden, a child's hand on
the sash) is a seeded event, rare (Nathan's number: about one in a hundred, per day or per crossing of the open ground; W4 decides the
unit and the exact draw, in Normal only; Easy and Free play never), told the way the wasp is told, by the senses first: the ground's
thud through the feet (the spider's vibration sense, sourced), a shadow that covers everything, the hum of a voice; then the shoe. It is
not death by dice alone: the draw picks the moment and the place, and the spider that is under cover, on a vertical face, or already
moving has the honest escape a real one has (the jump, the drop on the line, the crack); a spider in the open on the flat, standing
still, is the one that is stepped on. It lands as the same recovery flow as the wasp's (Normal loses the day). The notebook's page says
what the sources say: that most jumping spiders die to predators, weather and people without ever being seen, and that the vibration
sense is the warning. In the nursery (the sill, behind the glass) the only footfall is the hand on the sash. Order: with W4's rules
(it is a lingering threat of the simplest kind), after the night and the home-before-dark draw exist.

And: "Low probability random chance stuff is amazing in games." As a rule for every round from here: **rare things happen**, seeded and
honest, so that a long life has days nobody else had. The footfall is one; the list to draw from (each a sourced thing that does happen
to real spiders, each with its page when it fires): a bird's shadow that is only a leaf; a hailstone; a lost ladybird on the sill; a
moth in the room at night; a dropped crumb that brings the ants; a gust that carries the spiderling on its own silk (ballooning: the
real way jumping spiders travel, and the one way the sill's nursery can empty); the mate who comes a day early; the rival who is
already dead under the stone; a wasp that misses; a fly that lands on the spider's own back; the sun through the glass that warms the
sill to the point the spider must move; a second spider of the player's own kind on the fence, which is another player (the shared
world). The rule of the draw: rare (one in fifty to one in a thousand a day, each named in `X.game`), from the seeded stream so a save
never rerolls, never on day one, never two in a day, never while a rest is kept, told by the senses before the thing, and always with a
real way out or a real gift. Nothing is a dice death and nothing is a dice win: the chance is in what the world does, the outcome is in
what the spider does about it. The notebook keeps the count ("things seen once"), nothing else on the HUD.
