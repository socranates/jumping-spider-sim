# The world: a nature preserve in the middle of a city

Nathan, 2026-10-20: "the current level can be test only. Instead of trying to make this map work completely redesign the main level as a
nature preserve or park in the middle of a city. design the layout and expansion plan before coding anything. This will be the proper world
we want for the full game. So start from scratch and think it through."

This is that design. Nothing in it is built. The windowsill, the garden, the bushes, the house walls and the kitchen built in ROBLOX-94..114
become the **test level** (kept, playable from a developer menu, used by the self-test); the game's real world is laid out here.

## 1. The idea in one paragraph

A small nature preserve survives in the middle of a city: a few acres of meadow, pond, scrub and old trees held between a railway embankment,
a canal towpath and the backs of apartment blocks. People made it, fence it, mow paths through it and run a volunteer ranger hut at its gate.
To a one-centimetre spider it is a continent. The game is a life (or a lineage of lives) inside it: born on the ranger hut's windowsill, learning
to hunt behind glass, stepping out into a world that is beautiful, wild and indifferent, and full of the traces of the city around it. The
preserve is the honest home for everything the game already is (a sourced field guide, real behaviour, true scale, death that means something)
and for everything Nathan has asked for since (a huge open world, many species, rare events, a shed, a pond, a tree, a cat, a game room, MMO,
Steam). It also gives the game its quiet theme: wildness that lasts because people decided to let it, and a small life that does not know that.

## 2. Why a city preserve, and what it fixes

- **It is true.** Urban nature reserves are real and common (railway-side reserves, canal-side wildlife gardens, cemetery meadows, pocket
  parks). Jumping spiders thrive in exactly these edges: sunny walls, fence posts, benches, tree bark, flower heads. Every habitat below exists
  in a few acres of a real one.
- **It is varied in a small space.** Meadow, pond, woodland edge, dead wood, dry stone wall, scrub, mown path, human structures: each is a
  different movement and hunting problem and a different cast of prey and predators, within a footprint Roblox can hold at 1 stud = 1 cm.
- **It keeps the windowsill.** The ranger hut's window is the nursery: the tutorial behind glass, the sash opened when the spider is ready
  (Nathan's "born on the sill, the sash shut until ready"). The house problem goes away: no house to make roamable, no 90 cm descent from a
  bungalow window; the hut is low (the sill ~70 cm above the ground, a bench and a water butt under it as steps).
- **It lets the city in on purpose.** The human world is part of the ecology: a lamppost that draws moths at night, a bench, a litter bin,
  an information board, a bike rack, a drain, the railway's vibration, a dog walker's footfall, a pigeon, the hum of the city. It is honest
  and it is a theme: the spider lives inside a human system without knowing it.
- **It grows naturally.** The preserve has edges to expand across (the canal, the railway bank, the apartment balconies and window boxes,
  rooftops, a cemetery next door) and the game already has the honest way to cross them: spiderlings balloon on silk (ROBLOX-79/80).

## 3. Scale and the shape of the world

At 1 stud = 1 cm, a 100 m preserve is 10,000 studs across. Roblox places positions in 32-bit floats; at 5,000 studs from the origin the
precision is about 0.0005 studs (5 µm), far below the smallest part the game draws, so a preserve of about **100 × 60 m centred near the
origin** is safe (the far corners about 5,800 studs out). The preserve is that size.

It is not built at spider detail everywhere: that would be millions of parts. The world has three levels of detail:

1. **Home ranges** (the playable cores): patches about **3 × 3 m to 5 × 5 m** built at full spider detail (every blade, stone and stem the
   spider walks on), the size a real jumping spider lives its life in. Each is a set of 100 × 100 regions (the existing region engine).
2. **Corridors** between home ranges: walkable at a coarser detail (paths, fence lines, the boardwalk, a wall top, a hedge base), so the
   spider can actually walk from one home range to another; long, risky journeys of game days.
3. **The backdrop**: everything else drawn only (terrain, trees and grass at a distance, the city beyond), streamed by distance.

Lives and generations move through it: a life is mostly lived in one home range; the next generation balloons (a wind-dependent, seeded,
honest dispersal) to another; a strong spider can walk a corridor. So the world is huge, and each life is intimate.

## 4. The layout (metres; x east, z north; the gate at the south)

```
 z 60 ┌──────────────────────────── RAILWAY EMBANKMENT (fenced; trains every few minutes) ────────────────────────────┐
      │  BRAMBLE & SCRUB (z 50–60)   blackthorn, bramble tangle, ivy on the fence; birds nest                           │
 z 50 │     ┌───────────┐                                                                                               │
      │     │ VETERAN   │   WILDFLOWER MEADOW (x 25–70, z 18–48)                    ┌─────── POND (x 62–78, z 30–44) ─┐   │
      │ W   │ OAK (x14, │   tall grass, knapweed, ox-eye daisy, yarrow; mown path   │ reedbed, lilies, dipping        │ S │
      │ O   │  z 42)    │   loops through it; bee hotel; ant hills                  │ platform, damselflies, frog     │ T │
      │ O   └───────────┘                                                           └────────── boardwalk ────────────┘ O │
      │ D   LOG PILE (x 8–12, z 28–31)                                                                                  N │
      │ L   leaf litter, bark                         ● bench, bin, lamppost (x 40, z 16)                                E │
      │ A                                                                                                               │
      │ N   ┌──────────┐   HUT GARDEN (x 38–52, z 6–14): herb border,                  DRY STONE WALL (x 92–94, z 5–55)  │ W │
      │ D   │COMPOST & │   bird feeder, water butt, pallet planters                    sunny west face: the jumping      │ A │
      │     │SHED (x2–8│                                                               spiders' city                    │ L │
 z 5  │     │, z 3–9)  │      ┌─RANGER HUT─┐ (x 44–47.5, z 2–5)   info board, bike rack                               │ L │
 z 0  └─────┴──────────┴──────┴──GATE─────┴─────────────── CITY STREET & RAILINGS (z 0) ─────────────────────────────────┘
      x 0                                  x 45                                                                    x 100
           west boundary: CANAL TOWPATH beyond a hedge (x < 0)          east boundary: backs of APARTMENT BLOCKS (x > 100)
```

The ranger hut sits just inside the gate, its window facing north into the preserve: the sill looks out over the hut garden and the meadow,
with the pond's reeds and the railway bank on the horizon and the city's roofs behind. The world origin (0,0,0 in studs) is the windowsill,
so the code's coordinates keep the sill where it has always been; the preserve's metres above are shifted so the sill is at the origin.

### The zones (each a home range at full detail, joined by corridors)

| # | Zone | Size of its core | What it is to a spider | Prey | Danger | Notebook |
|---|---|---|---|---|---|---|
| 1 | **Ranger hut** (start) | the sill + the hut's inside (desk, notice board, specimen jars, a kettle) + its outside walls | the nursery behind glass; the tutorial; the sash opened when ready | fruit flies, a house fly, a moth at the lamp | the ranger's hand, a house spider in the corner | the first pages |
| 2 | **Hut garden** | 4 × 4 m | herbs, a pallet planter, the water butt, the bird feeder's spill, the hut's sunny wall | aphids, gnats, hoverflies, leafhoppers | the wasp, the robin, the rival | the garden's pages (the bestiary exists) |
| 3 | **Meadow** | 5 × 5 m | a forest of grass and flower stems; height is safety and sight | leafhoppers, flies on flowers, moths at dusk, crickets | crab spider in a flower, wasp, bird, ants | meadow life |
| 4 | **Pond edge** | 4 × 4 m | reeds, lily pads, the dipping platform's planks, wet stones | midges, mosquitoes, damselflies (too big?), mayflies | water (drowning), a frog's tongue, pond skaters, fishing spider | the pond |
| 5 | **Log pile & woodland floor** | 4 × 4 m | bark, crevices, leaf litter, fungus, shade, damp | springtails, woodlice (ambient), gnats | centipede, ground beetle, wolf spider | dead wood |
| 6 | **Veteran oak** | the trunk's base and first 3 m of bark | bark plates, lichen, the root flare; a vertical world | bark lice, aphids, small moths | bird (treecreeper), a crab spider, the fall | the old tree |
| 7 | **Dry stone wall** | 5 m of wall face | sun-warmed stone, gaps, moss, the jumping spiders' own city: other jumpers (zebra spiders) | flies basking on stone | other jumping spiders (rivals of other species), wasps | the wall |
| 8 | **The bench, bin and lamppost** | a 3 × 3 m patch | human things: painted wood, steel, a crisp packet, the lamp drawing moths at night | moths at the lamp, flies at the bin | footfall, a dog, the lamp's heat | the city's edge |
| 9 | **Bramble & railway bank** | 4 × 4 m | thorns, leaves, the fence wire, the trains' tremor | many flying insects | birds nesting, the tremor | scrub |
| 10 | **Compost & tool shed** | the shed's wall and the compost bays | warmth, rot, a cobwebbed shed window (Nathan's shed idea lives here) | fruit flies, gnats, springtails | rats? (seen, honest), centipede | decay |

Corridors: the gravel/mown paths, the boardwalk, the hedge base along the canal, the wall top, the fence rail along the railway, and the
hut's drainpipe and gutter. A corridor journey crosses open ground where birds and footfall happen (Nathan's "you should want to explore but
have to truly weigh the cost").

## 5. How the game uses the world

- **A life**: born (hatched) on the ranger hut's sill; the sash shut until the spider has grown and fed enough (the nursery); then the hut
  garden and whatever the spider dares. The life clock, hunger, moulting, rivals and the wasp as now; W4's nature rules everywhere outdoors.
- **Home**: any retreat in any zone can be home; the notebook remembers places.
- **Lineage and dispersal**: a mating that succeeds ends in a sac and a hatch; the spiderlings balloon. The player chooses one to follow:
  where it lands is drawn from the wind (seeded, honest: mostly nearby zones, rarely far), and the next life starts in that zone. This is the
  main expansion mechanic: each new zone is a place a lineage can land.
- **Time and seasons**: each life is one season's worth (spring hatch to autumn); seasons change the preserve (flowers, prey, weather).
  Clock scale: the hut 1.0 (the tutorial pace), outdoors slower (0.33 as now).
- **Night**: the lamppost and the hut's lit window draw moths; the meadow is cold and dangerous; home before dark.
- **Rare things** (Nathan's ~1 in 100): a hedgehog at night, a fox, a heron at the pond, a train's sparks, a child's hand, a balloon of
  spiderlings from elsewhere, an aurora of mayflies; seeded and honest.
- **The city as a sound**: traffic, trains, church bells, voices on the path; quiet at dawn.
- **Multiplayer later**: the preserve is the shared world (each player a lineage; meet at the wall, contest a flower).
- **Playable cast later**: the zebra spider at the wall, the fencepost jumper on the oak, the crab spider, the wolf spider; "be anything"
  up to the wasp (the cosmetic passes stay free until Nathan wires sales).

## 6. The test level

The current world (the windowsill at the house, the bed, the bushes, the drainpipe, the kitchen) stays as **"The Test Garden"**: reachable
from Settings (Studio and developer mode) and used by the self-test and the CLI suites; nothing new is added to it. Its code (the region
engine, generators, streaming, look stream, nature rules, prey and bug sims) is the engine the preserve is built on.

## 7. The expansion plan (each phase ends in a publish; each zone round follows the established pattern: design → build in a worktree →
CLI suites → previews → Studio self-test → publish)

**Phase A — the preserve's skeleton (2 rounds).** The world plan in code: a `World/Preserve` map of zones and corridors with their metre
layout, the shift that puts the sill at the origin; the **backdrop** of the whole preserve (terrain, trees, the pond's surface, the city's
blocks, the railway and its trains as sound and silhouette) drawn at distance only; a developer world-switch between the Test Garden and
the Preserve; the self-test learns zones. Nothing new walkable except the hut.
*Round 1 built (ROBLOX-115, 2026-10-20, not yet run in Studio):* the world switch (`World/Worlds`, the Workspace attribute `World`; the test garden stays the
default), the map in code (`World/Preserve`: the zones, home ranges and corridors in metres, the hut's window at the origin), the whole backdrop drawn and
streamed by distance (`World/PreserveLook`, 15 zones; 797 parts from the sill at the full tier, 476 at the low), the trains (`World/PreserveTrain`), the
preserve's drift, the self-test's preserve checks, and lock-on to L2. Round 2: what the first Studio look says (the haze, the hut, the view), then Phase B.

*Round 2 was taken straight into Phase B* (Nathan's go-ahead after ROBLOX-115), the haze and the first Studio look folded into Phase B's Studio checklists.

**Phase B — the vertical slice (3–4 rounds).** Zone 1 (the ranger hut: inside, the sill moved into the hut's window frame with its own
redrawn window and view, the sash/nursery rule) and zone 2 (the hut garden) at full detail, with their prey, the wasp, the rival and the
existing life; the title/intro reshot for the preserve; this becomes the published game, replacing the test level for players.
*Round 1 built (ROBLOX-116, 2026-10-20, not yet run in Studio):* the hut's inside walkable (nine floor cells, the desk with its drawer, lamp, notebook, mug,
jars and hand lens, the notice board, a bookcase of field guides, the chair, the door with its gap; homes under the drawer and behind the board), the window
over the sill, the nursery rule (`Life/Nursery`: the sash shut until the first moult has hardened, then the ranger props it on a morning, kept in the save),
the way out (the outer sill, the logs, the bench a short line drop below, its leg to the ground; the water butt and a trough), and the hut garden's core
(home range 2 moved to x 43.75..47.75, z 5..9 m, right under the window: sixteen cells of lawn, gravel path, a raised pollinator bed of milkweed,
coneflower, bee balm and goldenrod under mulch, a herb bed, the feeder on its pole; gnats and aphids, springtails, leafhoppers, woodlice, a ladybird, a
millipede and a harvestman; homes under the trough, a stone and a bark chip). Round 2: the corridor round the hut's east end and the path on to the meadow's
edge, the rival walking the garden, the hut's own prey (the fruit flies and the moth at the lamp), the published default; round 3: the volunteers' back room
and the cat (a doorway in the hut's east wall, `docs/HANDOFF-roblox-world.md`).
*Round 2 built (ROBLOX-117, 2026-10-20, not yet run in Studio):* the hut garden rich at the spider's eye (patches of near detail drawn only round the spider: grass blades
at true size in tufts, layered bark mulch, gravel, husks and a feather under the feeder, petals, the dew; a second of each of the bed's plants and every plant drawn
whole), the rival and the mate coming into the garden and roaming its cells (never the hut), the hoverfly with its page, the fruit flies at a compost caddy by the door
and the moth at the lamp, the gravel path round the hut's east end to the door's gap, the low tier's far looks thinner. Left for round 3 with the back room and the cat:
the path on to the meadow's edge and the published default.

*Round 3 built (ROBLOX-118, 2026-10-20, not yet run in Studio):* the hut's ceiling on joists and its walls to it (nothing puts the spider back), the north face outside to the
soffit, fascia and gutter, the volunteers' back room through a doorway in the east wall (a sofa with the darkest home under it, a television and a games console, board games, a rug,
a radiator under the window, cables), the ranger's cat living in the two rooms on a seeded day (heard by its bell, noticing what moves, patting; a death in Normal, a knock aside in the
gentle rules) with its notebook page, the path round the back room's east end (preserve-2) and a gravel path on north toward the meadow, and **the preserve as the default world**
(the test garden by the attribute), its drift, an intro that opens inside the hut, the title card's line and the store page. Phase B's game is built; its Studio pass is next.

**Phase C — the meadow and the path (3 rounds).** Zone 3 and the first corridor (the mown path, the bench/bin/lamppost patch, zone 8),
crab spider and the lamppost moths, ballooning as the generation's choice.

*Round 1 built (ROBLOX-119, 2026-10-20, not yet run in Studio):* the bench patch (home range 8, moved to where the garden's path comes out: x 43.65..46.65, z 13..16 m) with its
bench, litter bin, lamppost (lit at dusk, moths at its lantern) and drain grate, and the meadow's edge (home range 3 at its near edge: x 42.65..47.65, z 16..21 m), big and
little bluestem, black-eyed Susan, yarrow, milkweed, coneflower, bergamot and goldenrod at true size, an ant hill and a curled leaf; their life (leafhoppers, house flies,
hoverflies, moths, ants), the goldenrod crab spider with its page, the rival roaming the edge. Left for round 2: the bird's shadow over open ground, a cricket, more of the meadow
and the mown loop as a corridor; round 3: ballooning as the generation's choice.

**Phase D — water (2–3 rounds).** Zone 4 (the pond edge and the boardwalk), water as a surface, the frog, damselflies, midges; weather
(rain makes worms and stops hunting).

**Phase E — dead wood and the old tree (3 rounds).** Zones 5 and 6, the centipede and the ground beetle as threats, bark as a vertical world,
the bird.

**Phase F — the wall and other jumpers (2–3 rounds).** Zone 7, other jumping spider species as neighbours and rivals, the first playable
extra species.

**Phase G — the edges (ongoing).** Zones 9 and 10, seasons, rare events, the cast, multiplayer in the shared preserve; beyond the fence for
the Steam edition (the canal, the apartment balconies and window boxes, a rooftop garden, the cemetery next door).

## 8. Performance and engine rules the design keeps

- Home ranges are built from the region engine (≤ ~60 boxes per 100 × 100 region, budgets per tier); the look stream keeps only the
  spider's region and its neighbours at full detail; corridors at coarse detail; the backdrop drawn by distance (and later meshes/impostors).
- The preserve stays within about ±6,000 studs of the origin (float precision).
- True scale everywhere (`docs/SCALE_AUDIT.md`); every species sourced before it ships (`docs/NOTEBOOK_SOURCES.md`).
- Meshes made in Blender (Nathan has it) for things boxes cannot be (the oak's bark, stones, leaves, the frog, the cat later), uploaded
  through Nathan's Studio or the Creator Dashboard, are a tool for Phases B onward.

## 9. Questions for Nathan before Phase A

1. The preserve's flavour: an English-style nature reserve (stone wall, oak, bramble, robin) or an American city one (fence posts, maples,
   cardinals, *Phidippus audax* at home)? The first spider is the North American *Phidippus audax*; an American preserve keeps it native.
2. The size: 100 × 60 m as above, or smaller and denser to start?
3. Should the ranger hut be the start for every life, or only the first (later lives start where the ballooning lands)?
4. The cat and the game room were for the house. In the preserve, the hut could have a cat (the ranger's), and the "game room" could be the
   hut's back room (a volunteers' room with a sofa, a games console, board games). Keep them that way?

## 10. Decided (Nathan, 2026-10-20: "I trust your judgements")

1. **An American preserve.** The first spider, *Phidippus audax*, is native to North America, so the preserve is an American city's: split-rail
   and chain-link fences, a stone retaining wall in place of the English dry stone wall (zone 7 stays a sunny stone wall), a bur oak as the
   veteran tree, maples and a black cherry at the woodland edge, milkweed, goldenrod, coneflower and big bluestem in the meadow, cattails in the
   pond, a cardinal and a robin at the feeder. Every species page is sourced for North America.
2. **100 × 60 m**, as designed; only the home ranges are built at full detail, so the size costs nothing until a zone is built.
3. **The first life starts in the ranger hut.** Later lives start where the spiderlings land (the ballooning choice); a "return to the hut"
   start stays available from the menu.
4. **The cat and the game room live in the hut**: the ranger's cat (the hut's danger, heard by its collar bell first) and a volunteers' back
   room with a sofa, a games console and board games, built in Phase B with the hut.
5. Lock-on moves to **L2** on controllers (Nathan, 2026-10-20), in Phase A's first round.

## 11. Progress

- **ROBLOX-119 (Phase C, round 1)**: the bench patch and the meadow's edge walkable (`World/Meadow`), their life (`Prey/Ant`), the crab spider (`Predator/CrabSpider`, `Client/CrabBody`,
  `UI/CrabText`), the lamppost's light, the rival's roam to the meadow's edge; fixed the flights that never left the sill's band (`Prey/PerchGraph`'s band per spec) and the
  hoverfly's probe. 146 regions, 244 seams. Decisions taken in the build: home ranges 3 and 8 moved to where the garden's path comes out (the plan's places were nowhere near the
  hut); the bench patch at 3 by 3 m in nine cells, the meadow in twenty-five; two crab spiders, each on one of two flowers by the day; the bird left for round 2.
  `docs/DECISIONS.md` ROBLOX-119; `docs/HANDOFF-roblox-world.md` has the Studio checklist.

- **ROBLOX-118 (Phase B, round 3)**: the ceiling and the walls to it, the eaves outside, the back room and the cat (`Predator/Cat`, `Rig/CatPose`, `Client/CatBody`, `UI/CatText`),
  the path round the back room and on toward the meadow, the preserve the default world. 105 regions, 180 seams. Decisions taken in the build: the back room east of the hut (the path
  moved round it, preserve-2); the upper walls and the ceiling in nine regions a room (streaming); the roof's slope drawn only, its gutter the walkable edge; the cat's day a pure function
  of the seed, the day and the hour, its reaction live and never saved; it keeps to the floor, the sofa, the chair and the window sill; the house spider drawn, not a hazard.
  `docs/DECISIONS.md` ROBLOX-118; `docs/HANDOFF-roblox-world.md` has the Studio checklist.

- **ROBLOX-117 (Phase B, round 2)**: the hut garden rich at the spider's eye (354 patches of near detail, World/LookPlan's step 2b), the plants' seconds and their drawing,
  the dew on the looks, the rival and the mate in the garden (`Hut.CREATURES`, `Hut.ROAM`, RivalDrive's `roam`), the hoverfly, the fruit flies' caddy and the lamp's moth,
  the path round the east end (eight regions), the low tier's far looks thinner; 48 regions, 332 boxes, 78 seams. Decisions taken in the build: near detail as patches
  planned by distance rather than a denser look per region; the rival and the mate simulated only beside the spider's cell; the hut never theirs.
  `docs/DECISIONS.md` ROBLOX-117; `docs/HANDOFF-roblox-world.md` has the Studio checklist.

- **ROBLOX-116 (Phase B, round 1)**: the ranger hut walkable and its way out, the nursery rule, the hut garden's core and its life; 40 regions in the preserve
  (the sill and 39 new: 285 boxes, 69 seams), the backdrop's hut and garden drawn a hair behind the walkable boxes where both are. Decisions taken in the build:
  the nursery ends at the first moult hardened, not after a number of days; home range 2 sits right under the north window (z 5..9 m, not 8..12); the hut's
  walls are walkable to 1.3 m inside and 1.15 m outside (the regions' ceilings), the door's leaf to 1 m; the outside drop is 85 cm as built, taken by the logs
  or a 40 cm line onto the bench. `docs/DECISIONS.md` ROBLOX-116; `docs/HANDOFF-roblox-world.md` has the Studio checklist.
- **ROBLOX-115 (Phase A, round 1)**: two worlds in one engine; the preserve's map, backdrop, trains and drift; the hut's sill the only walkable place; L2 is
  the lock on controllers (a tap; held, Focus) and R3 recentres. Decisions taken in the build: the sill 85 cm over the ground outside and 70 over the hut's
  floor; the hut a 3.5 by 3 m log hut with walls 28.5 cm (the sill's reveal) and a 35-degree gable roof; covered ways at both ends of the railway so trains
  never appear at the world's edge; the city's towers impostors at the edge (the precision rule). `docs/DECISIONS.md` ROBLOX-115;
  `docs/HANDOFF-roblox-world.md` has the Studio checklist.
