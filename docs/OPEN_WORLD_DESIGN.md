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
   streaming, the world record in the save, `clockScale`. The game plays identically.
2. **W2 — beyond the glass** (ROBLOX-95): the raised sash, the outer sill, the brick descent, bed_a, per-region nav.
3. **W3 — garden life** (ROBLOX-96): prey in the bed (gnats and aphids join the flies), woodlice as the first ambient
   bug, the stone retreat, the descent set piece, the page, saves across regions.
4. **W4 — nature's rules** (ROBLOX-97): movement cost, death loses the day in Normal, lingering threats, mating that
   can fail, the garden's slow clock.
5. **W5 — no hand holding** (ROBLOX-98): the HUD and notice audit for Normal — hints only on day one, captions
   sparing, nothing added for the garden but a region name on the day line.
Then full suites, places, bundle, publish.

## Risks, named

- **Streaming with a custom focus** (no character): `ReplicationFocus` works, but the client's sim must never raycast
  into unstreamed space — the active radius must cover the player's region and neighbors, and AI stays regional.
- **Part budgets on PlayStation and phones**: per-region budgets, the low tier, and later impostors for far regions.
- **The 200-local client**: the world wiring is a new module (`Client/WorldClient`), not more lines in SpiderClient.
- **Save format**: `world` is optional and validated; the revision gate protects positions.
- **Nav graph size**: region sizing; seams are the only cross-region edges.
- **Nothing has run in Studio since main ce64498**: this round rides on the audit's green suites and the previewer.
