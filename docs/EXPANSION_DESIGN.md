# Expansion design: the garden, the field guide, and the long road to Steam

Nathan (2026-10-18): a second location/level; "all kinds of different bug species to learn about — isopods,
crickets, worms, birds and other animals too"; and eventually "a full steam game with everything included in one
price with massively expanded levels to explore." This is a design, not a build. The windowsill ships first and
keeps shipping; this is the map of what it grows into.

## The doorway is already built

ROBLOX-79/80 gave the game its ending: the eggs hatch and the spiderlings balloon away on silk. Ballooning is the
real way jumping spiders disperse, and it is the natural, honest doorway to every new place: **the hatch card gains
a second button — "Follow one" — and the camera rides a spiderling's thread down past the sill, out the open
window, into the garden.** The new generation starts there instead of the crack. Returning to the sill stays
possible (the notebook keeps both homes; a place-teleport in Roblox terms, one project per place, same universe,
same save envelope with a `location` field).

## Level 2: the garden

The sill looked out on it the whole time. Scale stays spider-true (the whole garden is a few square meters of bed,
path and wall — "massively expanded" at our size).

Zones, each a distinct movement and hunting problem:
- **The soil and leaf litter** under the window: tunnels and overhangs, the richest prey, the dampest danger.
- **The grass forest**: the sill's grass tufts at world scale; vertical stalk travel, jumps between blades, wind sway.
- **The flower heads**: pollinator traffic (watchable, mostly unhuntable), nectar-drinking flies (huntable), height.
- **The stone path**: open ground, heat shimmer at noon, nothing to anchor silk to mid-crossing — the risk crossing.
- **The shed wall**: the new cliff; frames and flashing like the sill's woodwork, a new retreat crack, the way up.

Weather joins the clock: wind (sways grass, bends jumps, carries ballooning), rain (worms surface, hunting pauses,
drops are physical), overcast light. Each is a sim rule with a notebook page, not a backdrop.

## The field guide grows: species roster

The game's identity is learn-by-living: every species is met in play first, then earns its sourced notebook page
with an honest game-note. Nathan's list, placed:

| Species | Role in play | What the page teaches |
| --- | --- | --- |
| **Isopods (woodlice)** | Armored walkers in the litter; too tough to bite, roll up when struck (the pill bugs); harmless company | Crustaceans on land; gills that need damp; the roll (conglobation) |
| **Crickets** | The big risky meal: hind-leg kick knocks the spider back, hearing makes stalking hard, worth three flies | Ears on their front legs; the chirp (wing stridulation, males); escape jump |
| **Earthworms** | After rain, on the path; NOT prey (far too big for a salticid) — watch the blackbird take one | Soil engineers; skin breathing (why rain brings them up); segments |
| **Ants** | A trail the ant mimic can walk beside (its page finally pays off in play); a swarm is a place you leave | Trail pheromones; why mimicry works; formic acid |
| **Aphids + ladybirds** | Aphid colonies on stems; ladybird as a walking tank the spider cannot hurt | Honeydew; farming by ants; warning colors |
| **Bees & butterflies** | Flower traffic, watch-only; a bee near the retreat is a wasp-grade alarm | Pollination; why a salticid leaves them alone |
| **Snail** | A moving landscape feature; its trail is a surface with its own grip | The foot, the trail, the shell's spiral |
| **Birds (robin, wren)** | The garden's wasp, scaled up: a shadow, an alarm, cover-or-die; takes the worm, the cricket, sometimes the rival | The real top of this food chain; shadow response in spiders |

Prey difficulty continues ROBLOX-77's rule: the struggle scales with the meal. Crickets sit above the rival;
aphids below the fruit fly. Every predator keeps the wasp's grammar: a warning you can learn, an escape that
always exists, gentle modes that stay gentle.

## New playable spiders (the pass shelf grows)

The garden naturally offers the **zebra spider** (Salticus scenicus, the wall specialist) and the **fencepost
jumper** (Marpissa muscosa, the shed's bark-colored giant) as future ~US$0.99 appearances beside the peacock, ant
mimic and tarantula pack — same rule as ROBLOX-66: cosmetic, free until Nathan wires sales, each with its pose and
its page.

## Roblox now, Steam later

- **Roblox (now)**: the garden is a second place in the existing universe; free like everything playable; passes
  stay cosmetic. The playtest loop with Chet publishing stays exactly as it is.
- **Steam (the long road)**: one price, everything included, no passes — the whole field guide as the pitch
  ("the nature documentary you play"). The frozen Godot project is not just our reference: it is the natural seed
  of the Steam build (same sim, same goldens, desktop rendering and controller support already half-real). Roadmap
  sketch, honestly far out: (1) the Roblox game reaches content-complete with the garden; (2) the Godot codebase is
  revived against the same golden tests the port already answers to; (3) Steam Early Access with sill + garden;
  (4) the "massively expanded levels" (the shed interior, the pond edge, night as its own world) land on Steam
  first, where one price pays for them. No dates. Momentum stays on Roblox until Nathan says otherwise.

## Build order (when Nathan calls for level 2)

1. The garden layout module + nav graph (the sill's `WindowsillLayout`/`RivalRoute` pattern at garden scale), empty
   but walkable; the ballooning transition and `location` in the save.
2. Litter zone + isopods + crickets (the new prey/danger grammar), their pages.
3. Birds (the scaled wasp), rain/wind, worms-after-rain, their pages.
4. Flowers/ants/aphids wave, the zebra spider, the garden retreat and full loop (mating works in the garden too).
Each step is a round with the usual: CLI suites, decisions, Chet's Studio pass, a playtest publish.
