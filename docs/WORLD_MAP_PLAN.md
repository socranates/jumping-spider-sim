# The whole map: a single-story house and its back garden

Nathan, 2026-10-19 (playing v33): "maybe plan a full map to start filling in", with "shrubs should be bushes and the house a single story.
more realistic. still more detail ... more beauty". This is the map every later round fills in, so the world grows into a known shape
instead of outward one region at a time. It keeps every rule of `docs/OPEN_WORLD_DESIGN.md` (regions with seeded generators, server
build, streaming around the spider, per-region navigation, retreats, saves as seed + diff, a slower clock outside) and only adds the
layout. Nothing here is built beyond what the table marks as built.

## The place

A small single-story house with a back garden, the kind the sill already looks out on. The window the spider is born at is a kitchen
window at the back of the house, its sill 90 cm above the garden (true for a single story: sills are usually 80–100 cm up). Above the
window the wall goes up about 1.2 m more to the eaves and gutter; nothing above that. The garden is about **10 m wide and 14 m deep**
(1,000 × 1,400 studs), fenced, with a lawn in the middle and life around the edges. At 1 cm to a stud that is the size of a small
country to the spider, and every part of it is a real backyard place a person would recognise.

Coordinates continue the sill's frame: x across the back of the house (west −, east +), y up (the sill floor is 0, the garden soil is
−90), z out from the house (the wall face at −24, the garden running to about −1,420 at the back fence).

```
  z (out from the house) →
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
| 2 | **house_wall** | −42…42; −24; 0…−90 | brick below the window | moths, crane flies, the descent | built (W2/W3b) |
| 3 | **bed_a** | −25…25; −24…−74; −90 | bed under the window, the stone home | gnats, aphids, springtails, leafhoppers, woodlice | built (W3/W3b) |
| 4 | **wall_upper** | −42…42; −24; 0…130 | the wall above the window to the eaves (y 110) and gutter (floor y 109), on the window's jambs; its look draws the rest of the house | a house spider's web in the eaves corner, the gutter as a high perch | built (W3c: the boxes and the look; no retreat, no prey yet) |
| 5 | **wall_west / wall_east** | −500…−42, 42…500; −24; −90…120 | the rest of the back wall: the drainpipe (west, a climbable pipe to the gutter), the back door, its step and frame (east) | woodlice at the drain, an earwig in the door frame | next |
| 6 | **shrub_west** | −500…−25; −24…−200 | **bushes to the ground** (box, privet): dense twig lattice, leaf litter under, deep shade | the hidden world: the safest cover and the darkest place; a crab spider is not here, a ground beetle is | next |
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
3. **W4 (nature's rules)** and **W5 (no hand holding)** as planned, on the built regions.
4. Then fill outward in this order: `wall_west`/`wall_east` (the drainpipe and the door), `shrub_west`, `path`, the first lawn chunks,
   `patio_east`, `border_east`, `hedge_west`, the woodpile, the vegetable bed, the shed, the fence — each a round with its bugs and pages
   from `docs/GARDEN_BESTIARY.md`, weather when the patio's saucer and the lawn exist.
5. The peacock-as-default and the nursery (the sash shut until the spider is ready) can come at any point; the map does not depend on it.

## For Nathan

- Is this the garden you picture (size, the lawn in the middle, a shed at the back)? Anything you want in it — a tree, a pond, a
  vegetable patch, a sandpit, a washing line?
- Which corner should come first after the look round: the bushes, the drainpipe, or the lawn?
