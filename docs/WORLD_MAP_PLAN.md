# The whole map: a single-story house and its back garden

Nathan, 2026-10-19 (playing v33): "maybe plan a full map to start filling in", with "shrubs should be bushes and the house a single story.
more realistic. still more detail ... more beauty". This is the map every later round fills in, so the world grows into a known shape
instead of outward one region at a time. It keeps every rule of `docs/OPEN_WORLD_DESIGN.md` (regions with seeded generators, server
build, streaming around the spider, per-region navigation, retreats, saves as seed + diff, a slower clock outside) and only adds the
layout. Nothing here is built beyond what the table marks as built.

## The place

A small single-story house with a back garden, the kind the sill already looks out on. The window the spider is born at is a kitchen
window at the back of the house, its sill 90 cm above the garden (true for a single story: sills are usually 80–100 cm up). The window
is a real one (ROBLOX-112): 62 cm wide, its glass 1.1 m tall and its head 1.125 m above the sill, a sash window whose lower sash is
raised 6 cm. Above the head a lintel and a little more brick go up to the eaves, 1.5 m above the sill and 2.4 m above the lawn, the soffit
40 cm out and the gutter on the fascia; nothing above that but a roof at 35°. (Before ROBLOX-112 the window was a 10 cm slit and the eaves
1.1 m up, which made the house read too tall.) The garden is about **10 m wide and 14 m deep**
(1,000 × 1,400 studs), fenced, with a lawn in the middle and life around the edges. At 1 cm to a stud that is the size of a small
country to the spider, and every part of it is a real backyard place a person would recognise.

Coordinates continue the sill's frame: x across the back of the house (west −, east +), y up (the sill floor is 0, the garden soil is
−90), z out from the house (the wall face at −24, the garden running to about −1,420 at the back fence).

```
  z (out from the house) →
  ┌ inside (+z): the kitchen behind the window, the rooms of the house (see "The inside" below) ┐
  12.5 ─ the room's face of the back wall (the sill board's front edge; the counter runs along it)
  -24 ─ house wall ─────────────────────────────────────────────────────────────  (x -500 … +500)
        │ drainpipe │   window + sill (home)   │ back door + step │
  -24…-100   bed under the window (bed_a, built)  · shrub border west · patio slabs east
  -100…-200  path stones from the door ─────────────► lawn edge
  -200…-1000 THE LAWN (grass forest), a birdbath, a dandelion patch, molehill
  west edge: bushes to the ground (hedge line), the compost heap
  east edge: the flower border, a pot on a saucer, the woodpile
  -1000…-1300 the vegetable bed, the shed (wall, door gap, window, interior later)
  -1300…-1420 the back fence (planks, the gap at the bottom, the world beyond is drawn only)
```

## The regions (each a seeded generator with full and low budgets; ≤ ~60 solid boxes per region for the nav graph)

| # | Region | Where (x; z; y) | What it is | Danger / life | Status |
|---|---|---|---|---|---|
| 0 | **sill** | as built | home, the nursery | rival, wasp, flies | built |
| 1 | **outer_sill** | −30…30; −13.5…−24; 0 | stone outer sill | moths, crane flies | built (W2/W3b) |
| 2 | **house_wall** | −42…42; −24; 0…−90 | brick below the window | moths, crane flies, a harvestman from dusk, the descent | built (W2/W3b) |
| 3 | **bed_a** | −25…25; −24…−74; −90 | bed under the window, the stone home | gnats, aphids, springtails, leafhoppers, woodlice, ladybirds, millipedes, a snail, a harvestman | built (W3/W3b) |
| 4 | **wall_upper**, **eaves** | −64…64; −34…13; 0…112.5 (the window) and 112.5…165 (the eaves) | the window in true proportion (ROBLOX-112): the brick jambs, the window's glass and frame above the sill's back frame (climbable both sides), the room's reveal and its wall beside the window; then `eaves`: the lintel and brick to the eaves (y 150), the soffit 40 cm out, the fascia and the gutter (floor y 149); the eaves' look draws the rest of the house and the room beyond the window | a house spider's web in the eaves corner, the gutter as a high perch | built (W3c, rebuilt in ROBLOX-112; no retreat, no prey yet) |
| 5 | **wall_west / wall_east** | −500…−42, 42…500; −24; −90…150 | the rest of the back wall: the drainpipe (west, a climbable pipe to the gutter), the back door, its step and frame (east) | woodlice at the drain, an earwig in the door frame | west begun (ROBLOX-107: `wall_west` and `wall_west_upper`, x −120…−40, the drainpipe to the gutter; ROBLOX-112 split it again at the head, `eaves_west` above; on to −500 and the east still to come) |
| 6 | **shrub_west** | −500…−25; −24…−200 | **bushes to the ground** (box, privet): dense twig lattice, leaf litter under, deep shade | the hidden world: the safest cover and the darkest place; a crab spider is not here, a ground beetle is | built (ROBLOX-107: ten chunks `shrub_west_a`…`_j`, woodlice and springtails in the litter, a retreat under a dead leaf in each; the ground beetle later) |
| 7 | **patio_east** | 25…500; −24…−200 | patio slabs, a pot on a saucer (water), weeds in the cracks | open ground: heat at noon, the bird's hop, midges at the saucer | after |
| 8 | **path** | −40…40; −74…−300 | stepping stones from the door to the lawn | the crossing: nothing to hide under between stones | after |
| 9 | **lawn_n…** (chunks of 100 × 100) | −400…400; −200…−1000 | the grass forest: blades as walkable stems, clover, a dandelion patch, a molehill, the birdbath | leafhoppers, springtails, ants' trail, the bird at dawn, a wolf spider | the big fill |
| 10 | **border_east** | 400…500; −200…−1000 | the flower border: daisies, lavender, a rose | hoverflies, bees, the crab spider in a flower | after |
| 11 | **hedge_west** | −500…−400; −200…−1000 | the bushes continue along the fence; the compost heap at the far end | millipedes, woodlice, slugs, the centipede | after |
| 12 | **woodpile** | 300…500; −900…−1050 | logs and bark: a crevice city | the centipede, the earwig, bark retreats | after |
| 13 | **veg_bed** | −300…300; −1000…−1150 | the vegetable bed: lettuce, beans on canes (a climb), a slug trail | slugs, caterpillars, aphids, ladybirds | after |
| 14 | **shed** | −200…200; −1150…−1300 | the shed wall (the far cliff), its window, the door gap; inside is a later expansion | the orb weaver's web at the shed window, the fencepost jumper | after |
| 15 | **fence** | −500…500; −1300…−1420 | the back fence: planks, posts, the gap under | the end of the world; beyond is drawn only | last |

Rules for the fill: every region is reachable on foot or by line from its neighbour (the seams in `WorldMap`); every region has at least
one retreat; the garden's clock stays slow (0.33) everywhere outside the house's regions; distances are true, so crossing the lawn is
a journey of game days, not minutes, and the map is meant to be lived in a region at a time.

## The inside: the house the sill belongs to (ROBLOX-112)

Nathan, 2026-10-20: "The house is still too tall or needs to be made into a whole house with rooms and everything". The house is a single-story
bungalow 10 m wide (x −500…500) and 7.5 m deep inside; the rooms are the next world after the garden, and the sill is where both begin: the
garden through the window, the house behind the spider. Coordinates continue the sill's frame: x across (west −), y up (the sill board's top 0,
the floor −90, the ceiling 150: 2.4 m rooms), **+z into the house** (the back wall's room face at z 12.5, which is the sill board's front edge:
the wall is 36.5 cm thick and the sill sits in its deep reveal; the front wall's room face at about z 760). Every rule of the garden holds
inside (seeded regions of at most ~60 boxes, whole inside the streaming radius from anywhere on them, at least one retreat each, seams both
ways), and the house keeps the sill's pace: its clock is 1.0 everywhere inside, and the garden's night (its ground hunters and its cold) does not
reach in (`Nature.INDOORS`); the inside's own night is its house spiders and the moths at the lamp.

```
  z (into the house) →
  760 ─ front wall ──────────────────────────────────────────────────────────────────────
        │ BEDROOM  x −500…−50                  │ LIVING ROOM  x −50…500                      │
        │ bed (the underside, the dust), the   │ sofa (its underside: the darkest place),     │
        │ wardrobe's gap, the slipper           │ bookshelf, houseplant, radiator under the    │
  412.5 ──────────────────────────────────────────────────────── front window, the lamp ─
        │ HALLWAY  x −500…500, z 312.5…412.5: the skirting-board road, the doors off it, the  │
        │ front door at its east end (a side door), the draught under it                      │
  312.5 ──────────────────────────────────────────────────────────────────────────────────
        │ BATHROOM x −500…−150 │ KITCHEN  x −150…150 (behind the sill)  │ BACK HALL  x 150…500  │
        │ the bath, the basin, │ the counter under the window (built),  │ the back door (x 230), │
        │ the frosted window   │ the table and chairs, the fridge, the  │ shoes, coats, the mat  │
        │ (the house's other   │ bin, the fruit bowl                    │                        │
        │ window, x −260)      │                                        │                        │
  12.5 ─ back wall (room face) ─────────── the sill's window at x 0 ─────────────────────────
```

### The rooms as regions

| Region | Where (x; y; z) | What it is | Life | Danger | Status |
|---|---|---|---|---|---|
| **kitchen_counter** | −62…62; −26…30; 12…74 | the worktop 4 cm under the sill board (y −4) on a tiled upstand, 60 cm deep; the sink under the window (40 × 40, 20 deep), the tap beside it; a toaster west of the sink standing on two feet over the **retreat** (`kitchen_toaster`, the warm gap under it, full of crumbs); a jug kettle on its base east of it | (later) fruit flies from the bowl, a house fly at the window | the sink's water and its smooth steel, the kettle's steam, a cloth wiping the worktop | **built (ROBLOX-112)**: 19 boxes, the retreat and its words, no prey yet |
| **kitchen_floor** | −62…62; −93…−7; −14…94 | the floor 90 cm under the sill (lino tiles), the cupboard doors under the counter, the plinth recessed under them (the dark kick space: a dried pea, a dust ball), the run's end panels, the cupboards' insides | (later) crumbs that bring the ants | (later) the vacuum, the shoe | **built (ROBLOX-112)**: a strip 80 cm deep in front of the counter, 6 boxes, no retreat yet (the kick space is the next) |
| kitchen_floor_b… | −150…150; −90; 94…312.5, chunks of 100 × 100 | the rest of the kitchen floor; the **skirting-board road** along every wall (7 cm boards whose tops are a highway) | silverfish at night, ants to the crumbs | the vacuum (a seeded weekly sweep: the noise first, then the suction along the floor), a person's shoe | plan |
| kitchen_table | about −60…60; −90…−15; 180…260 | the table (top 75 cm up) on four legs, two chairs (legs, seats, the rails between), crumbs under it, the **fruit bowl** on it | **fruit flies** at the bowl (prey, all day), a wasp at the bowl in late summer | the hand that takes an apple; a chair pushed back | plan |
| kitchen_fridge | −150…−90; −90…90; 20…80 | the fridge against the west wall: its side, the **warm gap** behind it at the coils (a retreat), the gap under its front | a house spider's tangled web behind it | the motor's hum and its heat | plan |
| bathroom_a… | −500…−150; −90…150; 12.5…312.5 | the bath (its white walls too smooth for a house spider to climb out of; a jumping spider can), the basin, the frosted window (the house's other window, x −260), the bath mat | **silverfish** in the damp, a **house spider in the bath**, moth flies at the plughole | the shower's water, the damp | plan |
| back_hall | 150…500; −90…150; 12.5…312.5 | the back door (x 230) and the draught gap under it to the garden's step (the second way in from outside), shoes, coats on hooks, the mat | woodlice that came in under the door, a house spider in the coats | the shoe, the door opening | plan (its door is the seam to `wall_east`'s step) |
| hallway | −500…500; −90…150; 312.5…412.5, in chunks | the skirting-board road, the doors off it (gaps under them), the front door at the east end | a **daddy-long-legs** in the ceiling corner (*Pholcus*: a spider that hunts other spiders) | the vacuum, the shoe, the cat (if Nathan wants a cat) | plan |
| living_room_a… | −50…500; −90…150; 412.5…760 | the sofa (its underside the darkest place in the house), the bookshelf (books as a stepped cliff), a houseplant in its pot (a plant inside, the Pilea's cousin), the **radiator** under the front window (warm in the evening), the lamp | **moths at the lamp** after dark, a house fly, a house spider behind the books | the cat, the vacuum, being sat on | plan |
| bedroom_a… | −500…−50; −90…150; 412.5…760 | the bed (the underside and its dust), the wardrobe's gap, a slipper, the curtains | a house spider in the wardrobe, a lone moth | the vacuum, the slipper put on | plan |
| room shell | −150…150; −90…150; 12.5…312.5 | **drawn only** (the eaves' look, ROBLOX-112): the kitchen's ceiling, far wall, sides and floor beyond the walkable strip, so the window shows a room and the sill's view into the room has walls | | | drawn, until the rooms are built |

Rules for the inside: every room has at least one retreat (the gap under the toaster, behind the fridge, under the sofa, in the wardrobe, behind a
book); the skirting-board road joins every room (the gaps under the doors are the seams); the dangers are seeded and told by the senses first, as the
wasp is (the vacuum is heard rooms away before it comes; a shoe is a footfall's thud and a shadow), and each has a real way out (up a wall, under the
plinth, into a retreat). Prey inside is the house's own: fruit flies at the bowl, house flies and moths at the windows and the lamp. Each new kind gets
its sourced notebook page before it ships, as the garden's did.

### The order to build the inside

1. **The counter and the floor in front of it** (ROBLOX-112, done): the first steps from the sill into the house, the toaster's gap the first home
   inside, the room drawn round it.
2. **The kitchen's floor and its skirting road, the table with the fruit bowl** (fruit flies as the inside's first prey, crumbs, the ants' trail), the
   kick space under the cupboards as a second retreat.
3. **The fridge's warm gap and the back hall** (the back door's gap to the garden's step: the house and the garden joined on the ground as well as
   through the window), with `wall_east` outside.
4. **The bathroom** (the house spider in the bath, silverfish), then **the hallway** and its daddy-long-legs.
5. **The living room** (the sofa, the bookshelf, the houseplant, the radiator, the lamp's moths at night), then **the bedroom**.
6. The inside's dangers as their own round once two rooms are walkable: the vacuum, the shoe, and the cat if Nathan wants one.

## The look (Nathan: "more realistic, still more detail, more beauty; lighting is beautiful")

- The lighting stays as it is; the realism comes from shape, material and density. PBR materials for brick, stone, soil, bark, wood and
  terracotta; leaves with a drawn rim, veins, curl and a lighter underside everywhere (the Pilea's standard); grass as clumps of real
  blades with seed heads; litter and weathering where the eye rests.
- **Bushes to the ground**: the drawn shrubs become full bushes (a dense crown of leaf clusters on a branching twig frame that reaches
  the soil), and the near ones are walkable (twigs as boxes).
- **A single-story house**: the wall above the window stops at the eaves and gutter about 1.2 m up; the houses across the way read as
  bungalows; nothing in the view suggests a second floor.
- Budgets per region at full and low tier; Terrain only as backdrop under the walkable boxes; meshes and textures uploaded through
  Nathan's browser when a box cannot be the thing.
- (W3c) Until a region is built, the look of its neighbour may draw it as a backdrop, drawn only: `wall_upper`'s look draws the back wall
  out to x ±500, the roof over the whole house, a downpipe, a window and the back door, which `wall_west`/`wall_east` will make walkable.

## The order

1. **Now (W3c, the look):** better insect animation (legs that step, wings that beat, antennae), bushes to the ground in the view and
   `shrub_west` begun, the single-story house (`wall_upper` with eaves and gutter, the bungalows in the view), a detail and realism pass
   on the four built regions. *Done (ROBLOX-103, 2026-10-19), but for `shrub_west`, which was not begun: the bodies move (pose only), ten
   bushes to the ground stand round the garden's edges in the view, `wall_upper` is built with the rest of the house drawn round it, the
   houses across the way are bungalows beyond a back fence and side fences, and the outer sill, the wall, the bed and the view have more
   detail. The gutter's retreat and the eaves' house spider are still to come.*
2. *(Between the rounds, ROBLOX-104: a self-test of the live place in Studio, so every region built so far and every one to come is walked in the real
   engine at each publish: `src/Client/SelfTest.luau`, checklist in `docs/HANDOFF-roblox-world.md`. Not yet run in Studio.)*
3. **W4 (nature's rules)** and **W5 (no hand holding)** as planned, on the built regions. *(W4 built 2026-10-19 as ROBLOX-106; not run in Studio.)*
4. Then fill outward in this order: `wall_west`/`wall_east` (the drainpipe and the door), `shrub_west`, `path`, the first lawn chunks,
   `patio_east`, `border_east`, `hedge_west`, the woodpile, the vegetable bed, the shed, the fence — each a round with its bugs and pages
   from `docs/GARDEN_BESTIARY.md`, weather when the patio's saucer and the lawn exist. *(ROBLOX-107, 2026-10-19: `shrub_west` built and
   `wall_west` begun from x −120 to −40 with the drainpipe, the second way up to the gutter; the wall on west to −500 and `wall_east` with the door
   are next. Not run in Studio.)*
   *(Between the rounds, ROBLOX-108, 2026-10-20: performance for a release. Each region's look is made on the client near the spider within a part budget
   (`World/LookPlan`, `Client/LookStream`), so every region to come adds to the map without adding to what a phone holds at once; a new region kind with walls
   seen from afar gets a far look in `LookPlan.FAR`. Not run in Studio.)*
   *(ROBLOX-111, 2026-10-20: v36's Studio self-test had the bed at 22 fps beside the bushes; the self-test now profiles the frame and compares the bed
   without the looks and without shadows, so whether the bushes' look must be lighter is the next Studio run's to say.)*
5. The peacock-as-default and the nursery (the sash shut until the spider is ready) can come at any point; the map does not depend on it.
6. *(ROBLOX-112, 2026-10-20: the house in true proportion and the first of the inside. The window is a real one, 1.1 m of glass, and the eaves 2.4 m above
   the lawn, the brick above the window split from the window as `eaves` and `eaves_west`; `WorldMap.REVISION` is world-3. The inside is planned above
   ("The inside") and its first two regions are built: `kitchen_counter`, with the gap under the toaster as a home, and `kitchen_floor`. Not run in Studio.)*

## For Nathan

- Is this the garden you picture (size, the lawn in the middle, a shed at the back)? Anything you want in it — a tree, a pond, a
  vegetable patch, a sandpit, a washing line?
- Which corner should come first after the look round: the bushes, the drainpipe, or the lawn?
- (ROBLOX-112) The inside: is this the house you picture (a kitchen behind the window, a bathroom west of it, a back hall with the back door east of it,
  a hallway across the middle, the living room and a bedroom at the front)? A cat or no cat? Which room after the kitchen?
