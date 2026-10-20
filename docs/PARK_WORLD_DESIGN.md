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

**Phase B — the vertical slice (3–4 rounds).** Zone 1 (the ranger hut: inside, the sill moved into the hut's window frame with its own
redrawn window and view, the sash/nursery rule) and zone 2 (the hut garden) at full detail, with their prey, the wasp, the rival and the
existing life; the title/intro reshot for the preserve; this becomes the published game, replacing the test level for players.

**Phase C — the meadow and the path (3 rounds).** Zone 3 and the first corridor (the mown path, the bench/bin/lamppost patch, zone 8),
crab spider and the lamppost moths, ballooning as the generation's choice.

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
