--!strict
-- The world outside the glass (ROBLOX-95, docs/OPEN_WORLD_DESIGN.md W2): the generators of the three regions under the window, as pure data. Region asks here for every
-- kind that is not the sill; nothing here builds a part or knows the engine, so the server, the client and the CLI tests all get the same boxes from the same region.
--   outer_sill .. the stone slab the raised sash opens onto (top y 0, x -30..30, z -24..-13.5) and the window box's two halves that stand on it (Data/Flora's
--                 garden box, drawn by the sill's Decor and solid here); its look is worn paint over stone, moss in the corners, grit and rain streaks down its face.
--   house_wall ... the brick wall under it, face at z -24 from y 0 to the lawn at y -90.4, x -40..40: one box below the slab and two shoulders beside it, all
--                 drawn as brick courses over recessed mortar (the boxes turn invisible once the bricks exist), with the house going on above the outer sill
--                 around the window (drawn only).
--   bed .......... the soil under the window (top y -90, x -25..25, z -24..-74): soil mounds, three stones (one raised on two rests over a gap, the bed's
--                 retreat, World/WorldMap's bed_a_stone), two plants whose stems and leaves are boxes as the Pilea's are, and drawn soil, leaf litter, grass,
--                 twigs, pebbles, lichen and moss.
-- Everything placed is placed from the region's own seed (WorldMap.seed), by a Park-Miller stream of its own for each kind of thing, so the same region is the
-- same garden forever, and a drawn thing that the low tier drops (`full`) never moves what the low tier keeps. The physical pieces are the walkable world: the
-- motor walks their faces, RivalRoute builds the region's graph from them. A drawn record is one part (Habitat/Scenery.look builds them); the region's budget
-- (Region.budget) is a ceiling the placer keeps to at both tiers, and tests/world.luau holds the counts.
-- ROBLOX-96 (W3, garden life): the bed's life is placed here too, from the same seed: `prey(region)` is the bed's perch and vent list for a Prey/PreyDirector
-- (on the soil, the mounds' and stones' tops, under the dock's leaves for the gnats; on the plants' leaves and the dock's stem for the aphids, which only walk),
-- and `bugs(region)` the woodlice's starting places and the spots they hide in (under the big stone, at the other stones' feet, under the litter). The wall's look
-- gains the descent's dressing: lichen on the brick, a weathered course and cobweb strands in the corner under the outer sill.
-- ROBLOX-101 (W3b part A, the garden's bestiary): `bestiary(region)` is the list of the region's other prey, one spec per kind, each for a director of its own
-- (Prey/PreyWorld): springtails on the soil round the stones and the litter and leafhoppers on the dock's and the dandelion's stems and leaves in the bed; small
-- moths and crane flies on the house wall and on the outer sill (the slab by the window, the window box's fronts, the slab's front edge). From the same seed
-- by streams of their own, so W3's perches, vents and prey are what they were.
-- ROBLOX-103 (W3c, the look): a fourth kind, `wall_upper` (docs/WORLD_MAP_PLAN.md region 4: the house is a single story): the brick above the window up to the
-- eaves on the window's two jambs, the eaves' soffit, the fascia, the gutter hung on it (a walkable high perch) and the eave course of the roof; its look carries
-- the rest of the house as a backdrop (the back wall on either side to 5 m out, the roof over it all, the eaves and gutter along it, a downpipe, a window and the
-- back door), all drawn only until wall_west and wall_east are built. And more on the three built looks: drip stains and moss in the wall's joints, petals and
-- seeds on the outer sill, veins on the bed's leaves, seed heads on its grass and more kinds of litter, each from a stream of its own after what was placed
-- before, so nothing placed before moves.
local Flora = require(script.Parent.Parent.Data.Flora)
local WorldMap = require(script.Parent.WorldMap)

local Garden = {}

-- A physical box (WindowsillLayout.Piece) with the material it is drawn in when nothing draws it instead.
export type Piece = { id: string, lo: Vector3, hi: Vector3, profile: string, color: Color3, material: string? }
-- A drawn-only part: centred `at`, `size`, turned by `turn` (degrees about X, Y and Z, in that order, as CFrame.Angles), `shape` "Block" (the default),
-- "Ball", "Cylinder" (its axis along X) or "Ellipsoid" (a sphere mesh); `full`: the low tier drops it (FullOnly); `group`: the folder it is built into.
export type Drawn = {
	id: string, size: Vector3, at: Vector3, color: Color3, transparency: number?,
	material: string?, shape: string?, turn: Vector3?, full: boolean?, group: string?, shadow: boolean?,
}
export type Box = { min: Vector3, max: Vector3 }

local TAU = 2 * math.pi
local MOD = 2147483647

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
-- A Park-Miller stream from the region's seed and a salt for the kind of thing it places (the same stream as Habitat/Shapes.rng).
local function rng(seed: number, salt: number): () -> number
	local state = (seed + salt * 7919) % MOD
	if state <= 0 then state += MOD - 1 end
	return function(): number
		state = (state * 16807) % MOD
		return (state - 1) / (MOD - 1)
	end
end
local function between(rand: () -> number, a: number, b: number): number
	return a + (b - a) * rand()
end
local function pick<T>(list: { T }, rand: () -> number): T
	return list[1 + math.floor(rand() * #list)]
end
local function overlaps(a: Box, b: Box, margin: number): boolean
	return a.min.X < b.max.X + margin and a.max.X > b.min.X - margin and a.min.Z < b.max.Z + margin and a.max.Z > b.min.Z - margin
end

-- ---------------------------------------------------------------- the outer sill
Garden.OUTER = {
	slab = { lo = v(-30, -3, -24), hi = v(30, 0, -13.5), color = "ddd5c3", material = "Concrete" }, -- painted stone, the paint gone dull
	stone = { "a29d92", "948f85", "aaa497" }, -- where the paint has gone
	moss = { "5f7d3a", "6d8c45", "53703a", "7a9450" },
	grit = { "7d7466", "6a6358", "9b9284", "57514a", "b0a898" },
	streak = "8e8a80",
}

-- ---------------------------------------------------------------- the house wall
Garden.WALL = {
	face = -24, foot = -90.4, under = -3, top = 0, west = -40, east = 40, back = -13.5,
	brick = { length = 21.5, height = 6.5, joint = 1.0, depth = 0.6, recess = 0.28, gap = 0.02 },
	bricks = { "9c4a32", "a65538", "8f4430", "b0603e", "974d36", "a2573c", "7e3c2b" },
	burnt = "5e3428", pale = "c08a64", mortar = "b8b1a3", plaster = "efe8d8", coping = "c9c2b3",
	above = 30, window = { x0 = -31, x1 = 31, y1 = 14 }, -- the house above the outer sill goes up to y 30, round the window's frame
	brickMaterial = "Concrete", mortarMaterial = "Plaster",
}

-- ---------------------------------------------------------------- the wall above the window (ROBLOX-103)
-- Studs, the sill's frame. The brick goes on from the house_wall's drawing (which stops at y 30) to the eaves at `top`; the eaves box (the soffit underneath) runs
-- out to the fascia; the gutter hangs on the fascia, its floor at `gutter.floor`; the eave course of tiles over it. `house`: the rest of the house drawn round it.
Garden.UPPER = {
	face = -24, back = -13.5, west = -40, east = 40, jamb = 31, head = 14, top = 110, -- the jambs stand x 31..40 either side of the window, on the shoulders (y 0)
	eaves = { out = -54, top = 120, edge = 42 }, -- the soffit's box: from the wall out to z -54, y 110..120, x -42..42
	fascia = { out = -55.5, bottom = 106 },
	gutter = { floor = 108, thick = 1, lip = 115, out = -66, wall = 1, cap = 1, span = 40 }, -- floor y 108..109; the lip's inner face at z -66
	roof = { eave = -62, thick = 1.5, pitch = 35, ridge = 376, x = 500, color = "7b4a3d", tiles = { "8d4a3a", "7b4a3d", "934f3e", "6f4236" }, material = "Slate" },
	paint = "ece7dc", gutterColor = "3a3c3e", gutterMaterial = "Metal", houseMortar = "a8927e", -- (the long walls' mortar lines, toned toward the brick so they read as courses, not siding)
	-- (the kitchen's window is the sill's, 62 wide and 14 tall with its sill at y 0: the house's other window is drawn the same; the back door stands on a step)
	house = { x = 500, foot = -90.4, door = { x = 230, w = 85, h = 180, step = 14, color = "3f5b4a" }, window = { x = -260, w = 62, h = 14, sill = 0 }, pipe = { x = -50, d = 7 } },
	debris = { "6e4d2e", "8a6239", "5b4129", "a07445" },
}

-- ---------------------------------------------------------------- the bed
Garden.BED = {
	x0 = -25, x1 = 25, z0 = -74, z1 = -24, top = -90, bottom = -92,
	soil = "4a3a2c", soilMaterial = "Ground",
	landing = 5.0, -- the strip along the wall's foot kept flat for whatever comes down the wall
	mounds = { count = 6, w = { 4, 9 }, d = { 3, 7 }, h = { 0.4, 1.3 }, colors = { "4f3e2f", "574433", "45362a", "5c4a39" } },
	stones = { count = 2, w = { 3.2, 6.0 }, d = { 2.6, 4.8 }, h = { 1.0, 2.2 }, colors = { "8d8a83", "7e7b74", "9a968d" }, material = "Slate" },
	retreatStone = { over = 1.6, thick = 1.6, rest = 1.4, color = "85827a", rests = "77746d", material = "Slate" }, -- round the map's retreat box
	-- the plants: a dock seedling (one stem, three leaves along it) and a dandelion (a rosette of four leaves on the soil and a flower stalk)
	dock = { stem = 0.8, height = 18, leaves = { { y = 6, dir = "x+", l = 6.5, w = 4.4 }, { y = 11, dir = "z+", l = 5.5, w = 3.8 }, { y = 15, dir = "x-", l = 4.5, w = 3.2 } }, thick = 0.3 },
	dandelion = { leaf = { l = 4.6, w = 2.0, h = 0.25, gap = 0.75 }, stalk = 0.6, height = 12 }, -- (gap: the leaves start clear of the stalk and of each other)
	leaf = { top = "4d7a36", rim = "3c6630", under = "8fb36a", rib = "a7c98a", stem = "5d8a3e", material = "SmoothPlastic", rimOut = 0.12, underOut = 0.03, underThick = 0.1 },
	flower = { head = "f2c40c", disc = "d99a06", sepals = "4f7d35" },
	litter = { count = 70, size = { 0.9, 2.8 }, colors = { "8a6239", "a07445", "6e4d2e", "b88c52", "5b4129", "c4a061" }, lowEvery = 3 },
	grass = { tufts = 16, blades = 5, keep = 2, height = { 1.4, 3.2 }, colors = { "5c8a3a", "6f9a46", "4f7a33", "86a85a" }, dry = "b8a46a" },
	twigs = { count = 9, length = { 2, 6 }, width = 0.18, colors = { "5a4632", "6b5640", "4a3a2a" } },
	pebbles = { count = 24, size = { 0.25, 0.8 }, colors = { "a9a59c", "938f87", "bdb8ad", "7f7b74" } },
	mottle = { count = 12, size = { 3, 8 }, colors = { "3f3126", "54412f", "463729" } },
	-- ROBLOX-103: seed heads on the tufts (a stalk `over` the tuft's height, a head `length` long), grass clumps creeping in at the edges, and more kinds of litter
	seedHeads = { over = { 1.15, 1.45 }, length = 0.7, stalk = "9aa86a", colors = { "c8b47a", "b6a067", "d4c494", "a89060" } },
	clumps = { count = 6, blades = 5, height = { 1.8, 3.4 } },
	moreLitter = { count = 14, kinds = {
		{ size = { 1.4, 2.6 }, shape = 0.6, colors = { "d9c9a0", "cdbb8e" }, transparency = 0.35 }, -- skeleton leaves, gone to lace
		{ size = { 1.0, 2.2 }, shape = 0.55, colors = { "3d2c1e", "4a3524", "35271b" } }, -- dark, rotting
		{ size = { 0.6, 1.0 }, shape = 0.9, colors = { "c9a23d", "b58a2c", "a7792a" } }, -- small and round, yellow
		{ size = { 0.4, 0.7 }, shape = 0.45, colors = { "6b5232", "7d6240" } }, -- husks
	} :: { any } },
	-- ROBLOX-96: the bed's life. Perches: shelter and food as the sill's (0..1); `soil` perches are seeded free spots on the soil; the gnats' vents are two more
	-- (they come up out of the soil); the aphids' vents sit at the plants (an aphid appears on a free plant perch within `reach`). `target`: how many prey the bed holds.
	prey = {
		target = 6, soil = 8, vents = 2, ventNear = { 4, 9 }, -- (a gnat's vent lies 4 to 9 studs from some soil perch, so an entry flight of at least 4 exists)
		shelter = { soil = 0.2, mound = 0.15, stone = 0.1, under = 0.6, leaf = 0.3, stem = 0.35 },
		food = { soil = 0.1, mound = 0.1, stone = 0.05, under = 0.5, leaf = 0.5, stem = 0.5 }, -- (the plants are where the food is, as the sill's rim is: the gradient the fly model moves on)
		reach = { dock = 8, dandelion = 6 },
	},
	-- the woodlice: how many, and the litter they hide under (the first few of the litter kept at the low tier, so a hiding place is always drawn)
	woodlice = { count = 4, litterSpots = 3 },
}

-- ---------------------------------------------------------------- the back wall west of the window (ROBLOX-107, docs/WORLD_MAP_PLAN.md region 5, west half)
-- Studs, the sill's frame. The brick from x -120 to the house_wall's west end (x -40), face z -24, from the lawn to the eaves, in two regions split at y 0 (wall_west
-- below, wall_west_upper above, as house_wall and wall_upper are). The drainpipe: a column `d` square standing on the litter `gap` off the brick at `x`, up to the
-- swan neck under the eaves, out along the neck to under the gutter and up the outlet into the gutter's floor: the second way up to the gutter. Brackets every
-- 100 studs tie it to the brick (a tie behind it and a collar round it, `band` proud), so the pipe can be climbed onto from the wall. The eaves, the fascia, the
-- gutter (floor, lip, the west end cap) and the eave course go on from wall_upper's, which keeps its own end cap at x -41..-40 as the joint.
Garden.WEST = {
	west = -120, east = -40, face = -24, back = -13.5, foot = -90.4, rise = 0, top = 110,
	pipe = { x = -50, d = 7, gap = 1.2, foot = -90, neck = { y0 = 92, y1 = 99, out = -61 }, outlet = { w = 5, z0 = -61, z1 = -56 } },
	bracket = { at = { -40, 60 }, h = 1.5, band = 1, tie = 2 },
	color = "3a3c3e", material = "Metal", -- the pipe's paint, as the gutter's
	damp = { "2f2a22", "37301f" }, -- the damp patch at the drain's foot, on the litter and the brick
}

-- The drainpipe's footprint on the litter (a box from its foot up), for the life on the litter of a chunk that holds it to walk round, and the damp patch in front of
-- it where the woodlice gather (nil for a chunk that does not hold it).
local function pipeBox(): Box
	local P = Garden.WEST.pipe
	local z1 = Garden.WEST.face - P.gap
	return { min = v(P.x - P.d / 2, P.foot, z1 - P.d), max = v(P.x + P.d / 2, P.neck.y0, z1) }
end
local function holdsPipe(region: WorldMap.Region): boolean
	if region.kind ~= "shrub" then return false end
	local b, lo, hi = pipeBox(), region.bounds[1], region.bounds[2]
	return b.min.X >= lo.X and b.max.X <= hi.X and b.min.Z >= lo.Z and b.max.Z <= hi.Z
end
function Garden.standingFrom(region: WorldMap.Region): { Box }
	if not holdsPipe(region) then return {} end
	local b = pipeBox()
	return { { min = b.min, max = v(b.max.X, b.min.Y + 2, b.max.Z) } }
end
function Garden.drainFoot(region: WorldMap.Region): Vector3?
	if not holdsPipe(region) then return nil end
	local b = pipeBox()
	return v((b.min.X + b.max.X) / 2, Garden.WEST.pipe.foot, b.min.Z - 0.9)
end

-- ---------------------------------------------------------------- the bushes beside the bed (ROBLOX-107, docs/WORLD_MAP_PLAN.md region 6)
-- A chunk (WorldMap.SHRUB_CHUNKS) is a mat of deep leaf litter (top y -90, the bed's soil's, 2 deep) with two bushes to the ground on it, box and privet, `h` tall and
-- `w` across. A bush's frame is walkable boxes: `stems` stems from the litter, each with two `branch`es out from it at `at` of its height, a leaf `pad` (a cluster of
-- leaves, its top walkable) on each branch's end and a larger one on each stem's top; the first bush stands over the chunk's retreat, its stems clear of the dead leaf
-- and of its way in. The dead leaf over the retreat lies on two twigs (`leaf`: as the bed's stone, a gap the map's retreat box and a little more). A few heaps of litter
-- (`heaps`). The look draws the stems and branches as twigs, each pad as a hanging cluster of leaves whose top is the pad's, a skirt of foliage on the litter round each
-- bush and a crown over it (the clusters cast shadows: the shade under a bush is real), privet flowers, the dead leaf and its twigs, the heaps, damp patches, and the
-- litter itself, to the budget at both tiers.
Garden.SHRUB = {
	top = -90, bottom = -92, landing = 2, litter = "3b2e22", material = "Ground",
	bush = {
		h = { 44, 54 }, w = { 36, 48 },
		first = { r = 7, angles = { -90, 20, 160 } }, -- (the stems round the dead leaf, none in front of its way in: +z is toward the house)
		r = { 0.1, 0.16 }, stem = { 1.4, 1.8 }, stemH = { 0.62, 0.8 },
		branch = { at = { 0.45, 0.78 }, len = { 0.2, 0.32 }, thick = 0.9 },
		pad = { size = { 5, 7.5 }, thick = 0.6, crown = { 7, 9.5 } },
		-- (drawn) the outer mass: rings of clusters, `n` round at `y` of the height, `r` of the width out, each `w` of the width across and `h` of the height tall
		shell = { { n = 5, y = 0.18, r = 0.3, w = 0.4, h = 0.38 }, { n = 5, y = 0.5, r = 0.32, w = 0.4, h = 0.36 }, { n = 4, y = 0.78, r = 0.22, w = 0.38, h = 0.3 } },
	},
	leaf = { over = 1.6, thick = 0.5, rest = 1.2 },
	heaps = { count = 3, w = { 4, 8 }, d = { 3, 6 }, h = { 0.4, 1.0 } },
	bark = { "5a4632", "4e3c2b", "66503a" }, deadLeaf = { "8a6239", "a07445", "6e4d2e", "7d5a35" },
	foliage = { "3f6334", "4a6f3c", "35562c", "56804a" }, sunlit = { "6f9a52", "5f8a46" }, privet = { "f8f4ec", "efe9de", "fbfaf5" },
	litterColors = { "8a6239", "a07445", "6e4d2e", "b88c52", "5b4129", "c4a061", "4a3524", "3d2c1e" }, litterSize = { 0.9, 2.6 },
	mottle = { "2c241b", "33291f", "3f3126" },
	woodlice = { count = 4, litterSpots = 3 },
}

-- (ROBLOX-107) The ground a region's life walks on: the bed's soil, or the litter under the bushes (a chunk's own); its extent, its top, the strip along the
-- house's wall kept clear (`landing`) and the id of its box. For the bed these are the numbers the bed's placers always used, so its draws are what they were.
type Ground = { x0: number, x1: number, z0: number, z1: number, top: number, landing: number, soil: string }
local function groundOf(region: WorldMap.Region): Ground
	if region.kind == "shrub" then
		local lo, hi = region.bounds[1], region.bounds[2]
		return { x0 = lo.X, x1 = hi.X, z0 = lo.Z, z1 = hi.Z, top = Garden.SHRUB.top, landing = Garden.SHRUB.landing, soil = region.id .. "_soil" }
	end
	local B = Garden.BED
	return { x0 = B.x0, x1 = B.x1, z0 = B.z0, z1 = B.z1, top = B.top, landing = B.landing, soil = region.id .. "_soil" }
end

-- ---------------------------------------------------------------- the pieces
local function outerPieces(): { Piece }
	local O = Garden.OUTER
	local out: { Piece } = {
		{ id = "outer_sill_slab", lo = O.slab.lo, hi = O.slab.hi, profile = "brick_rough", color = hex(O.slab.color), material = O.slab.material },
	}
	local B = Flora.garden.box
	for _, half in B.boxes do
		table.insert(out, { id = half.id, lo = v(half.x0, B.bottom, B.z0), hi = v(half.x1, B.top, B.z1), profile = "painted_wood_dry", color = hex(B.color), material = "Wood" })
	end
	return out
end

local function wallPieces(): { Piece }
	local W = Garden.WALL
	local brick = hex(W.bricks[1])
	return {
		{ id = "house_wall", lo = v(W.west, W.foot, W.face), hi = v(W.east, W.under, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
		{ id = "house_wall_west", lo = v(W.west, W.under, W.face), hi = v(Garden.OUTER.slab.lo.X, W.top, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
		{ id = "house_wall_east", lo = v(Garden.OUTER.slab.hi.X, W.under, W.face), hi = v(W.east, W.top, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
	}
end

-- (ROBLOX-103) The wall above the window: the two jambs on the shoulders, the brick up to the eaves, the eaves' box, the fascia, the gutter (floor, lip, two end
-- caps) and the eave course of the roof over the eaves.
local function upperPieces(): { Piece }
	local U = Garden.UPPER
	local G, E, F, R = U.gutter, U.eaves, U.fascia, U.roof
	local brick = hex(Garden.WALL.bricks[1])
	local paint = hex(U.paint)
	local metal = hex(U.gutterColor)
	return {
		{ id = "wall_upper_west", lo = v(U.west, 0, U.face), hi = v(-U.jamb, U.head, U.back), profile = "brick_rough", color = brick, material = Garden.WALL.brickMaterial },
		{ id = "wall_upper_east", lo = v(U.jamb, 0, U.face), hi = v(U.east, U.head, U.back), profile = "brick_rough", color = brick, material = Garden.WALL.brickMaterial },
		{ id = "wall_upper_brick", lo = v(U.west, U.head, U.face), hi = v(U.east, U.top, U.back), profile = "brick_rough", color = brick, material = Garden.WALL.brickMaterial },
		{ id = "wall_upper_soffit", lo = v(-E.edge, U.top, E.out), hi = v(E.edge, E.top, U.back), profile = "painted_wood_dry", color = paint, material = "Wood" },
		{ id = "wall_upper_fascia", lo = v(-E.edge, F.bottom, F.out), hi = v(E.edge, E.top, E.out), profile = "painted_wood_dry", color = paint, material = "Wood" },
		{ id = "wall_upper_gutter", lo = v(-G.span, G.floor, G.out), hi = v(G.span, G.floor + G.thick, F.out), profile = "painted_wood_dry", color = metal, material = U.gutterMaterial },
		{ id = "wall_upper_gutter_lip", lo = v(-G.span, G.floor, G.out - G.wall), hi = v(G.span, G.lip, G.out), profile = "painted_wood_dry", color = metal, material = U.gutterMaterial },
		{ id = "wall_upper_gutter_west", lo = v(-G.span - G.cap, G.floor, G.out - G.wall), hi = v(-G.span, G.lip, F.out), profile = "painted_wood_dry", color = metal, material = U.gutterMaterial },
		{ id = "wall_upper_gutter_east", lo = v(G.span, G.floor, G.out - G.wall), hi = v(G.span + G.cap, G.lip, F.out), profile = "painted_wood_dry", color = metal, material = U.gutterMaterial },
		{ id = "wall_upper_roof", lo = v(-E.edge, E.top, R.eave), hi = v(E.edge, E.top + R.thick, U.back), profile = "brick_rough", color = hex(R.color), material = R.material },
	}
end

-- The bed's stone over its retreat: a slab on two rests, the gap between them the map's retreat box (WorldMap bed_a_stone) and a little more.
local function stoneOver(retreat: WorldMap.Retreat): { Piece }
	local S = Garden.BED.retreatStone
	local lo, hi = retreat.min, retreat.max
	local top = lo.Y + S.over
	local x0, x1 = lo.X - 0.2 - S.rest, hi.X + 0.2 + S.rest
	local z0, z1 = lo.Z - 0.8, hi.Z + 0.8
	return {
		{ id = "bed_a_stone_top", lo = v(x0, top, z0), hi = v(x1, top + S.thick, z1), profile = "brick_rough", color = hex(S.color), material = S.material },
		{ id = "bed_a_stone_west", lo = v(x0, lo.Y, z0), hi = v(x0 + S.rest, top, z1), profile = "brick_rough", color = hex(S.rests), material = S.material },
		{ id = "bed_a_stone_east", lo = v(x1 - S.rest, lo.Y, z0), hi = v(x1, top, z1), profile = "brick_rough", color = hex(S.rests), material = S.material },
	}
end

-- The bed: the soil, the stone over the retreat, then from the region's seed the two plants, two more stones and the mounds, each where it overlaps nothing
-- placed before it (a stride apart), off the landing strip under the wall and clear of the spawn.
local function bedPieces(region: WorldMap.Region): { Piece }
	local B = Garden.BED
	local out: { Piece } = {
		{ id = "bed_a_soil", lo = v(B.x0, B.bottom, B.z0), hi = v(B.x1, B.top, B.z1), profile = "brick_rough", color = hex(B.soil), material = B.soilMaterial },
	}
	local taken: { Box } = {}
	for _, t in region.retreats do
		for _, p in stoneOver(t) do table.insert(out, p) end
		table.insert(taken, { min = t.min - v(2.4, 0, 2.6), max = t.max + v(2.4, 0, 2.6) })
	end
	local spawn = region.spawn.pos
	table.insert(taken, { min = spawn - v(2.5, 0, 2.5), max = spawn + v(2.5, 0, 2.5) })
	-- somewhere free for a footprint w x d, or nil after sixty tries
	local function spot(rand: () -> number, w: number, d: number, margin: number): (number?, number?)
		for _ = 1, 60 do
			local x = between(rand, B.x0 + 1.5, B.x1 - 1.5 - w)
			local z = between(rand, B.z0 + 1.5, B.z1 - B.landing - d)
			local box = { min = v(x, 0, z), max = v(x + w, 0, z + d) }
			local free = true
			for _, other in taken do
				if overlaps(box, other, margin) then free = false; break end
			end
			if free then
				table.insert(taken, box)
				return x, z
			end
		end
		return nil, nil
	end
	-- the dock: a stem and three leaves along it, each leaf's underside on the stem's side (a spider climbing the stem meets it from below and walks out under it)
	local prand = rng(region.seed, 23)
	local D = B.dock
	local reachX, reachZ = 0.0, 0.0
	for _, leaf in D.leaves do
		if leaf.dir == "x+" or leaf.dir == "x-" then reachX = math.max(reachX, leaf.l) else reachZ = math.max(reachZ, leaf.l) end
	end
	local dx, dz = spot(prand, D.stem + 2 * reachX, D.stem + 2 * reachZ, 1.5)
	if dx ~= nil and dz ~= nil then
		local sx, sz = dx + reachX, dz + reachZ
		local s0, s1 = v(sx, B.top, sz), v(sx + D.stem, B.top + D.height, sz + D.stem)
		table.insert(out, { id = "bed_a_dock_stem", lo = s0, hi = s1, profile = "leaf_dry_prototype", color = hex(B.leaf.stem) })
		for i, leaf in D.leaves do
			local y0, y1 = B.top + leaf.y, B.top + leaf.y + D.thick
			local half = leaf.w / 2
			local mz, mx = sz + D.stem / 2, sx + D.stem / 2
			local lo, hi
			if leaf.dir == "x+" then lo, hi = v(s1.X, y0, mz - half), v(s1.X + leaf.l, y1, mz + half)
			elseif leaf.dir == "x-" then lo, hi = v(s0.X - leaf.l, y0, mz - half), v(s0.X, y1, mz + half)
			elseif leaf.dir == "z+" then lo, hi = v(mx - half, y0, s1.Z), v(mx + half, y1, s1.Z + leaf.l)
			else lo, hi = v(mx - half, y0, s0.Z - leaf.l), v(mx + half, y1, s0.Z) end
			table.insert(out, { id = `bed_a_dock_leaf_{i}`, lo = lo, hi = hi, profile = "leaf_dry_prototype", color = hex(B.leaf.top) })
		end
	end
	-- the dandelion: four leaves lying on the soil round a flower stalk
	local L = B.dandelion
	local span = 2 * (L.leaf.gap + L.leaf.l) + L.stalk
	local fx, fz = spot(prand, span, span, 1.2)
	if fx ~= nil and fz ~= nil then
		local cx, cz = fx + span / 2, fz + span / 2
		local h, r = L.stalk / 2, L.stalk / 2 + L.leaf.gap
		local w = L.leaf.w / 2
		table.insert(out, { id = "bed_a_dandelion_stalk", lo = v(cx - h, B.top, cz - h), hi = v(cx + h, B.top + L.height, cz + h), profile = "leaf_dry_prototype", color = hex(B.leaf.stem) })
		local y1 = B.top + L.leaf.h
		local rosette = {
			{ v(cx + r, B.top, cz - w), v(cx + r + L.leaf.l, y1, cz + w) },
			{ v(cx - w, B.top, cz + r), v(cx + w, y1, cz + r + L.leaf.l) },
			{ v(cx - r - L.leaf.l, B.top, cz - w), v(cx - r, y1, cz + w) },
			{ v(cx - w, B.top, cz - r - L.leaf.l), v(cx + w, y1, cz - r) },
		}
		for i, box in rosette do
			table.insert(out, { id = `bed_a_dandelion_leaf_{i}`, lo = box[1], hi = box[2], profile = "leaf_dry_prototype", color = hex(B.leaf.top) })
		end
	end
	-- two more stones
	local S = B.stones
	local srand = rng(region.seed, 11)
	for i = 1, S.count do
		local w, d, h = between(srand, S.w[1], S.w[2]), between(srand, S.d[1], S.d[2]), between(srand, S.h[1], S.h[2])
		local color = pick(S.colors, srand)
		local x, z = spot(srand, w, d, 1.2)
		if x ~= nil and z ~= nil then
			table.insert(out, { id = `bed_a_stone_{string.char(97 + i)}`, lo = v(x, B.top, z), hi = v(x + w, B.top + h, z + d), profile = "brick_rough", color = hex(color), material = S.material })
		end
	end
	-- the mounds: low heaps of soil
	local M = B.mounds
	local mrand = rng(region.seed, 37)
	for i = 1, M.count do
		local w, d, h = between(mrand, M.w[1], M.w[2]), between(mrand, M.d[1], M.d[2]), between(mrand, M.h[1], M.h[2])
		local color = pick(M.colors, mrand)
		local x, z = spot(mrand, w, d, 1.0)
		if x ~= nil and z ~= nil then
			table.insert(out, { id = `bed_a_mound_{i}`, lo = v(x, B.top, z), hi = v(x + w, B.top + h, z + d), profile = "brick_rough", color = hex(color), material = B.soilMaterial })
		end
	end
	return out
end

-- (ROBLOX-107) The drainpipe's brackets between two heights, `prefix` naming them: a tie from the pipe's back to the brick, and a collar round the pipe (a band in
-- front and one either side), each touching what it holds and overlapping nothing.
local function brackets(out: { Piece }, prefix: string, ylo: number, yhi: number)
	local W = Garden.WEST
	local P, K = W.pipe, W.bracket
	local metal = hex(W.color)
	local x0, x1 = P.x - P.d / 2, P.x + P.d / 2
	local z1 = W.face - P.gap
	local z0 = z1 - P.d
	for k, y in K.at do
		if y >= ylo and y + K.h <= yhi then
			local y1 = y + K.h
			local parts: { { name: string, lo: Vector3, hi: Vector3 } } = {
				{ name = "tie", lo = v(P.x - K.tie / 2, y, z1), hi = v(P.x + K.tie / 2, y1, W.face) },
				{ name = "front", lo = v(x0 - K.band, y, z0 - K.band), hi = v(x1 + K.band, y1, z0) },
				{ name = "west", lo = v(x0 - K.band, y, z0), hi = v(x0, y1, z1) },
				{ name = "east", lo = v(x1, y, z0), hi = v(x1 + K.band, y1, z1) },
			}
			for _, b in parts do
				table.insert(out, { id = `{prefix}_bracket{k}_{b.name}`, lo = b.lo, hi = b.hi, profile = "painted_metal_smooth", color = metal, material = W.material })
			end
		end
	end
end

-- (ROBLOX-107) The back wall west of the window, below y 0: the brick and the drainpipe's foot with its lower bracket.
local function westPieces(): { Piece }
	local W = Garden.WEST
	local P = W.pipe
	local z1 = W.face - P.gap
	local out: { Piece } = {
		{ id = "wall_west", lo = v(W.west, W.foot, W.face), hi = v(W.east, W.rise, W.back), profile = "brick_rough", color = hex(Garden.WALL.bricks[1]), material = Garden.WALL.brickMaterial },
		{ id = "wall_west_pipe", lo = v(P.x - P.d / 2, P.foot, z1 - P.d), hi = v(P.x + P.d / 2, W.rise, z1), profile = "painted_metal_smooth", color = hex(W.color), material = W.material },
	}
	brackets(out, "wall_west", P.foot, W.rise)
	return out
end

-- (ROBLOX-107) The same wall from y 0 to the eaves: the brick, the drainpipe's top, its swan neck out under the gutter and the outlet up into the gutter's floor, its
-- upper bracket, and the eaves, fascia, gutter (floor, lip, the west end cap) and eave course on west of wall_upper's.
local function westUpperPieces(): { Piece }
	local W, U = Garden.WEST, Garden.UPPER
	local P = W.pipe
	local G, E, F, R = U.gutter, U.eaves, U.fascia, U.roof
	local x0, x1 = P.x - P.d / 2, P.x + P.d / 2
	local z1 = W.face - P.gap
	local metal, paint = hex(W.color), hex(U.paint)
	local gutterMetal = hex(U.gutterColor)
	local joint = -G.span - G.cap -- the west face of wall_upper's own end cap
	local out: { Piece } = {
		{ id = "wall_west_upper", lo = v(W.west, W.rise, W.face), hi = v(W.east, W.top, W.back), profile = "brick_rough", color = hex(Garden.WALL.bricks[1]), material = Garden.WALL.brickMaterial },
		{ id = "wall_west_upper_pipe", lo = v(x0, W.rise, z1 - P.d), hi = v(x1, P.neck.y0, z1), profile = "painted_metal_smooth", color = metal, material = W.material },
		{ id = "wall_west_upper_neck", lo = v(x0, P.neck.y0, P.neck.out), hi = v(x1, P.neck.y1, z1), profile = "painted_metal_smooth", color = metal, material = W.material },
		{ id = "wall_west_upper_outlet", lo = v(P.x - P.outlet.w / 2, P.neck.y1, P.outlet.z0), hi = v(P.x + P.outlet.w / 2, G.floor, P.outlet.z1), profile = "painted_metal_smooth", color = metal, material = W.material },
		{ id = "wall_west_upper_soffit", lo = v(W.west, U.top, E.out), hi = v(-E.edge, E.top, U.back), profile = "painted_wood_dry", color = paint, material = "Wood" },
		{ id = "wall_west_upper_fascia", lo = v(W.west, F.bottom, F.out), hi = v(-E.edge, E.top, E.out), profile = "painted_wood_dry", color = paint, material = "Wood" },
		{ id = "wall_west_upper_gutter", lo = v(W.west, G.floor, G.out), hi = v(joint, G.floor + G.thick, F.out), profile = "painted_wood_dry", color = gutterMetal, material = U.gutterMaterial },
		{ id = "wall_west_upper_gutter_lip", lo = v(W.west, G.floor, G.out - G.wall), hi = v(joint, G.lip, G.out), profile = "painted_wood_dry", color = gutterMetal, material = U.gutterMaterial },
		{ id = "wall_west_upper_gutter_west", lo = v(W.west - G.cap, G.floor, G.out - G.wall), hi = v(W.west, G.lip, F.out), profile = "painted_wood_dry", color = gutterMetal, material = U.gutterMaterial },
		{ id = "wall_west_upper_roof", lo = v(W.west, E.top, R.eave), hi = v(-E.edge, E.top + R.thick, U.back), profile = "brick_rough", color = hex(R.color), material = R.material },
	}
	brackets(out, "wall_west_upper", W.rise, P.neck.y0)
	return out
end

-- (ROBLOX-107) The dead leaf over a chunk's retreat, lying on two twigs either side of the gap (the bed's stone's shape).
local function deadLeafOver(retreat: WorldMap.Retreat, prefix: string): { Piece }
	local S = Garden.SHRUB.leaf
	local lo, hi = retreat.min, retreat.max
	local top = lo.Y + S.over
	local x0, x1 = lo.X - 0.2 - S.rest, hi.X + 0.2 + S.rest
	local z0, z1 = lo.Z - 0.8, hi.Z + 0.8
	local leaf, twig = hex(Garden.SHRUB.deadLeaf[1]), hex(Garden.SHRUB.bark[1])
	return {
		{ id = prefix .. "_deadleaf", lo = v(x0, top, z0), hi = v(x1, top + S.thick, z1), profile = "leaf_dry_prototype", color = leaf, material = "Fabric" },
		{ id = prefix .. "_twig_west", lo = v(x0, lo.Y, z0), hi = v(x0 + S.rest, top, z1), profile = "bare_wood_rough", color = twig, material = "Wood" },
		{ id = prefix .. "_twig_east", lo = v(x1 - S.rest, lo.Y, z0), hi = v(x1, top, z1), profile = "bare_wood_rough", color = twig, material = "Wood" },
	}
end

-- (ROBLOX-107) A chunk of the bushes: the litter, the dead leaf over the retreat, two bushes whose frames are walkable twigs and leaf pads, and heaps of litter. Every
-- box inside the chunk, none overlapping another (each is tested against all placed before it and left out if it would), and nothing on the dead leaf's way in, the
-- spawn in front of it or the drainpipe's foot.
local function shrubPieces(region: WorldMap.Region): { Piece }
	local S = Garden.SHRUB
	local B = S.bush
	local G = groundOf(region)
	local top = G.top
	local id = region.id
	local out: { Piece } = {
		{ id = G.soil, lo = v(G.x0, S.bottom, G.z0), hi = v(G.x1, top, G.z1), profile = "brick_rough", color = hex(S.litter), material = S.material },
	}
	local solids: { Box } = {}
	local function clash(lo: Vector3, hi: Vector3, margin: number, skip: number?): boolean
		if lo.X < G.x0 + 0.5 or hi.X > G.x1 - 0.5 or lo.Z < G.z0 + 0.5 or hi.Z > G.z1 - G.landing then return true end
		for i, b in solids do
			if i ~= skip and lo.X < b.max.X + margin and hi.X > b.min.X - margin and lo.Y < b.max.Y + margin and hi.Y > b.min.Y - margin
				and lo.Z < b.max.Z + margin and hi.Z > b.min.Z - margin then return true end
		end
		return false
	end
	local function put(pid: string, lo: Vector3, hi: Vector3, profile: string, color: Color3, material: string?): number
		table.insert(out, { id = pid, lo = lo, hi = hi, profile = profile, color = color, material = material })
		table.insert(solids, { min = lo, max = hi })
		return #solids
	end
	-- the dead leaf over the retreat, then what must stay clear: its way in and the spawn in front of it, and the drainpipe's foot
	for _, t in region.retreats do
		for _, p in deadLeafOver(t, id) do put(p.id, p.lo, p.hi, p.profile, p.color, p.material) end
		table.insert(solids, { min = v(t.min.X - 2.5, top, t.max.Z), max = v(t.max.X + 2.5, top + 6, region.spawn.pos.Z + 2.5) })
	end
	for _, b in Garden.standingFrom(region) do table.insert(solids, { min = b.min - v(2, 0, 2), max = v(b.max.X + 2, top + 60, b.max.Z + 2) }) end
	-- the bushes
	local rand = rng(region.seed, 131)
	local centres: { Vector3 } = {}
	for i = 1, 2 do
		local h, w = between(rand, B.h[1], B.h[2]), between(rand, B.w[1], B.w[2])
		local c: Vector3? = nil
		local angles: { number }, r: number
		if i == 1 then
			local t = region.retreats[1]
			c = v((t.min.X + t.max.X) / 2, top, (t.min.Z + t.max.Z) / 2)
			angles, r = B.first.angles, B.first.r
		else
			local base = rand() * 360
			angles, r = { base, base + 120, base + 240 }, w * between(rand, B.r[1], B.r[2])
			for _ = 1, 60 do
				local try = v(between(rand, G.x0 + w / 2 + 3, G.x1 - w / 2 - 3), top, between(rand, G.z0 + w / 2 + 3, G.z1 - G.landing - w / 2 - 3))
				local far = true
				for _, o in centres do if (try - o).Magnitude < (w + 40) / 2 then far = false end end
				if far and not clash(try - v(r + 1, 0, r + 1), try + v(r + 1, h * 0.8, r + 1), 0.5) then c = try; break end
			end
		end
		if c ~= nil then
			table.insert(centres, c)
			local bark = hex(pick(S.bark, rand))
			local leaf = hex(pick(S.foliage, rand))
			for k, a in angles do
				local t, hs = between(rand, B.stem[1], B.stem[2]), h * between(rand, B.stemH[1], B.stemH[2])
				local sx, sz = c.X + math.cos(math.rad(a)) * r, c.Z + math.sin(math.rad(a)) * r
				local slo, shi = v(sx - t / 2, top, sz - t / 2), v(sx + t / 2, top + hs, sz + t / 2)
				local lens = { w * between(rand, B.branch.len[1], B.branch.len[2]), w * between(rand, B.branch.len[1], B.branch.len[2]) }
				local sizes = { between(rand, B.pad.size[1], B.pad.size[2]), between(rand, B.pad.size[1], B.pad.size[2]) }
				local crown = between(rand, B.pad.crown[1], B.pad.crown[2])
				if not clash(slo, shi, 0.3) then
					local stem = put(`{id}_bush{i}_stem{k}`, slo, shi, "bare_wood_rough", bark, "Wood")
					-- two branches, out along the axis nearest the stem's way out from the middle and along the other
					local ox, oz = math.cos(math.rad(a)), math.sin(math.rad(a))
					local dirs: { Vector3 } = if math.abs(ox) >= math.abs(oz)
						then { v(if ox >= 0 then 1 else -1, 0, 0), v(0, 0, if oz >= 0 then 1 else -1) }
						else { v(0, 0, if oz >= 0 then 1 else -1), v(if ox >= 0 then 1 else -1, 0, 0) }
					for j, d in dirs do
						local th = B.branch.thick
						local yb = top + hs * B.branch.at[j]
						local L = lens[j]
						local blo, bhi
						if d.X ~= 0 then
							local xa = if d.X > 0 then shi.X else slo.X - L
							blo, bhi = v(xa, yb, sz - th / 2), v(xa + L, yb + th, sz + th / 2)
						else
							local za = if d.Z > 0 then shi.Z else slo.Z - L
							blo, bhi = v(sx - th / 2, yb, za), v(sx + th / 2, yb + th, za + L)
						end
						if not clash(blo, bhi, 0.25, stem) then
							local branch = put(`{id}_bush{i}_branch{k}{j}`, blo, bhi, "bare_wood_rough", bark, "Wood")
							local P = sizes[j]
							local tip = (if d.X > 0 then v(bhi.X, 0, sz) elseif d.X < 0 then v(blo.X, 0, sz) elseif d.Z > 0 then v(sx, 0, bhi.Z) else v(sx, 0, blo.Z))
							local pc = tip - d * (P / 2 - 0.6)
							local plo, phi = v(pc.X - P / 2, bhi.Y, pc.Z - P / 2), v(pc.X + P / 2, bhi.Y + B.pad.thick, pc.Z + P / 2)
							if not clash(plo, phi, 0.2, branch) then put(`{id}_bush{i}_pad{k}{j}`, plo, phi, "leaf_dry_prototype", leaf) end
						end
					end
					local clo, chi = v(sx - crown / 2, shi.Y, sz - crown / 2), v(sx + crown / 2, shi.Y + B.pad.thick, sz + crown / 2)
					if not clash(clo, chi, 0.2, stem) then put(`{id}_bush{i}_crown{k}`, clo, chi, "leaf_dry_prototype", leaf) end
				end
			end
		end
	end
	-- heaps of litter
	local H = S.heaps
	local hrand = rng(region.seed, 137)
	for i = 1, H.count do
		local w, d, h = between(hrand, H.w[1], H.w[2]), between(hrand, H.d[1], H.d[2]), between(hrand, H.h[1], H.h[2])
		for _ = 1, 40 do
			local x, z = between(hrand, G.x0 + 2, G.x1 - 2 - w), between(hrand, G.z0 + 2, G.z1 - G.landing - 1 - d)
			if not clash(v(x, top, z), v(x + w, top + h, z + d), 1.0) then
				put(`{id}_heap_{i}`, v(x, top, z), v(x + w, top + h, z + d), "brick_rough", hex(S.litter), S.material)
				break
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the drawn look
-- A list of drawn records, and a ceiling for each tier: `add` keeps a record only while the tier it shows in has room (a full-only record counts against the
-- full ceiling, any other against both), so what is placed first is what a tight budget keeps.
local function sheet(budget: { full: number, low: number })
	local list: { Drawn } = {}
	local full, low = 0, 0
	local function add(d: Drawn): boolean
		if full + 1 > budget.full or (not d.full and low + 1 > budget.low) then return false end
		full += 1
		if not d.full then low += 1 end
		table.insert(list, d)
		return true
	end
	return list, add
end

-- A leaf over its box, the Pilea's way (Habitat/Plants): a blade with rounded ends whose top is the box's top, a darker rim band round it and a lighter
-- underside (full tier), and a midrib along it (full tier).
local function leafOver(add: (Drawn) -> boolean, name: string, lo: Vector3, hi: Vector3, group: string)
	local L = Garden.BED.leaf
	local function rounded(id: string, a: Vector3, b: Vector3, r: number, color: Color3, full: boolean)
		local width, depth, height = b.X - a.X, b.Z - a.Z, b.Y - a.Y
		local rr = math.min(r, width * 0.45, depth * 0.45)
		local c = (a + b) * 0.5
		add({ id = id .. "A", size = v(width, height, depth - 2 * rr), at = c, color = color, material = L.material, full = full, group = group, shadow = not full })
		add({ id = id .. "B", size = v(width - 2 * rr, height - 0.0008, depth), at = c - v(0, 0.0004, 0), color = color, material = L.material, full = full, group = group, shadow = not full })
		local dh = height - 0.0016
		for i, corner in { { a.X + rr, a.Z + rr }, { b.X - rr, a.Z + rr }, { a.X + rr, b.Z - rr }, { b.X - rr, b.Z - rr } } do
			add({ id = `{id}C{i}`, size = v(dh, 2 * rr, 2 * rr), at = v(corner[1], a.Y + dh / 2, corner[2]), color = color, material = L.material, shape = "Cylinder", turn = v(0, 0, 90), full = full, group = group })
		end
	end
	local r = math.min(hi.X - lo.X, hi.Z - lo.Z) * 0.45
	rounded(name .. "Blade", lo, hi, r, hex(L.top), false)
	rounded(name .. "Under", v(lo.X - L.underOut, lo.Y - 0.012, lo.Z - L.underOut), v(hi.X + L.underOut, lo.Y + L.underThick, hi.Z + L.underOut), r + L.underOut, hex(L.under), true)
	rounded(name .. "Rim", v(lo.X - L.rimOut, lo.Y + 0.05, lo.Z - L.rimOut), v(hi.X + L.rimOut, hi.Y - 0.06, hi.Z + L.rimOut), r + L.rimOut, hex(L.rim), true)
	local along = if hi.X - lo.X >= hi.Z - lo.Z then "x" else "z"
	local c = (lo + hi) * 0.5
	local length = (if along == "x" then hi.X - lo.X else hi.Z - lo.Z) * 0.82
	add({ id = name .. "Rib", size = if along == "x" then v(length, 0.008, 0.07) else v(0.07, 0.008, length), at = v(c.X, hi.Y + 0.004, c.Z), color = hex(L.rib), material = L.material, full = true, group = group })
	-- ROBLOX-103: side veins off the midrib, the Pilea's standard (full tier): four, alternating sides, angled toward the tip
	local half = (if along == "x" then hi.Z - lo.Z else hi.X - lo.X) * 0.5
	for i, f in { 0.28, 0.44, 0.6, 0.74 } do
		local side = if i % 2 == 0 then 1 else -1
		local t = (f - 0.5) * length / 0.82
		local veinLength = half * 0.85 / math.sin(math.rad(48))
		local out = half * 0.85 * 0.5
		local fwd = out / math.tan(math.rad(48))
		local at = if along == "x" then v(c.X + t + fwd, hi.Y + 0.004, c.Z + side * out) else v(c.X + side * out, hi.Y + 0.004, c.Z + t + fwd)
		local yaw = if along == "x" then -side * 48 else 90 + side * 48
		add({ id = `{name}Vein{i}`, size = v(veinLength, 0.008, 0.045), at = at, turn = v(0, yaw, 0), color = hex(L.rib), material = L.material, full = true, group = group })
	end
end

local function outerDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local O = Garden.OUTER
	local list, add = sheet(budget)
	local slab = O.slab
	local top, front = slab.hi.Y, slab.lo.Z
	-- where the paint has worn through to the stone: patches on the top, worst along the front edge (both tiers: it is the stone's look)
	local wrand = rng(region.seed, 3)
	for i = 1, 12 do
		local w, d = between(wrand, 1.2, 4.6), between(wrand, 0.7, 2.6)
		local x = between(wrand, slab.lo.X + w / 2 + 0.2, slab.hi.X - w / 2 - 0.2)
		local edge = i <= 5 -- along the front edge, square to it; the others anywhere, turned a little
		local z = if edge then front + d / 2 + 0.02 else between(wrand, front + 1.6, slab.hi.Z - 1.6)
		local turn = between(wrand, -25, 25)
		add({ id = "Worn" .. i, size = v(w, 0.008, d), at = v(x, top + 0.004, z), turn = v(0, if edge then 0 else turn, 0), color = hex(pick(O.stone, wrand)), material = "Concrete", group = "Weather" })
	end
	-- rain has run down the front face: dark streaks below the edge (a hair proud of the face, which is walkable)
	for i = 1, 6 do
		local x, w, l = between(wrand, slab.lo.X + 2, slab.hi.X - 2), between(wrand, 0.25, 0.7), between(wrand, 1.4, 2.9)
		add({ id = "Streak" .. i, size = v(w, l, 0.006), at = v(x, top - l / 2 - 0.05, front - 0.004), color = hex(O.streak), material = "Concrete", transparency = 0.35, group = "Weather" })
	end
	-- moss in the corners: where the slab meets the frame and the window box's ends, and at its front corners
	local mrand = rng(region.seed, 5)
	local corners = { { slab.lo.X + 0.9, slab.hi.Z - 0.8 }, { slab.hi.X - 0.9, slab.hi.Z - 0.8 }, { slab.lo.X + 0.9, front + 0.9 }, { slab.hi.X - 0.9, front + 0.9 },
		{ -9.1, -21.2 }, { 9.1, -21.2 } }
	for i, c in corners do
		for j = 1, 8 do
			local a, d = mrand() * TAU, 0.9 * math.sqrt(mrand())
			local size = between(mrand, 0.25, 0.7)
			add({ id = `Moss{i}_{j}`, size = v(size, size * 0.45, size * between(mrand, 0.7, 1.0)), at = v(c[1] + math.cos(a) * d, top + size * 0.09, c[2] + math.sin(a) * d),
				turn = v(0, mrand() * 360, 0), shape = "Ellipsoid", color = hex(pick(O.moss, mrand)), material = "Grass", full = j > 3, group = "Moss" })
		end
	end
	-- grit blown onto the stone
	local grand = rng(region.seed, 7)
	for i = 1, 28 do
		local s = between(grand, 0.07, 0.24)
		add({ id = "Grit" .. i, size = v(s, s * 0.6, s * between(grand, 0.6, 1.0)), at = v(between(grand, slab.lo.X + 0.5, slab.hi.X - 0.5), top + s * 0.25, between(grand, front + 0.4, slab.hi.Z - 0.4)),
			turn = v(between(grand, -20, 20), grand() * 360, 0), color = hex(pick(O.grit, grand)), material = "Pebble", full = true, group = "Grit" })
	end
	-- ROBLOX-103: what the window box lets fall on the stone (petals of its black-eyed Susans, browning at the edges, their seeds, a dry leaf; three petals at
	-- both tiers) and hairline cracks in the paint (full tier); a stream of its own, after everything placed before
	local frand = rng(region.seed, 107)
	local boxes = Flora.garden.box
	for i = 1, 10 do
		local half = boxes.boxes[1 + (i % 2)]
		local x = between(frand, half.x0 - 1.5, half.x1 + 1.5)
		local z = between(frand, front + 0.6, boxes.z0 - 0.4)
		local brown = frand() < 0.3
		add({ id = "Petal" .. i, size = v(between(frand, 0.9, 1.3), 0.03, between(frand, 0.35, 0.5)), at = v(x, top + 0.02, z), turn = v(between(frand, 0, 8), frand() * 360, 0),
			shape = "Ellipsoid", color = hex(if brown then "b5852a" else pick(Flora.garden.rudbeckia.petalColors, frand)), material = "SmoothPlastic", full = i > 3, group = "Fallen" })
	end
	for i = 1, 6 do
		add({ id = "Seed" .. i, size = v(0.16, 0.08, 0.32), at = v(between(frand, -24, 24), top + 0.04, between(frand, front + 0.6, boxes.z0 - 0.3)), turn = v(0, frand() * 360, 0),
			shape = "Ellipsoid", color = hex("2e231a"), material = "SmoothPlastic", full = true, group = "Fallen" })
	end
	for i = 1, 2 do
		local s = between(frand, 2.2, 3.2)
		add({ id = "DryLeaf" .. i, size = v(s, 0.04, s * 0.5), at = v(between(frand, slab.lo.X + 3, slab.hi.X - 3), top + 0.12, between(frand, front + 1.5, slab.hi.Z - 1.5)),
			turn = v(between(frand, 6, 16), frand() * 360, 0), shape = "Ellipsoid", color = hex(pick({ "a07445", "8a6239", "b88c52" }, frand)), material = "Fabric", full = true, group = "Fallen" })
	end
	for i = 1, 4 do
		local l = between(frand, 2, 6)
		add({ id = "Hairline" .. i, size = v(l, 0.006, 0.04), at = v(between(frand, slab.lo.X + 4, slab.hi.X - 4), top + 0.003, between(frand, front + 1, slab.hi.Z - 1)), turn = v(0, frand() * 360, 0),
			color = hex("6f6a60"), material = "Concrete", transparency = 0.3, full = true, group = "Weather" })
	end
	return list
end

local function wallDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local W = Garden.WALL
	local K = W.brick
	local list, add = sheet(budget)
	local face = W.face + K.gap -- the bricks' face, a hair behind the walkable face
	local mortarFace = W.face + K.recess
	local slab = Garden.OUTER.slab
	-- the mortar: the wall behind the bricks, recessed; under the slab only (the slab covers the top), up to the shoulders' tops beside it, and the house above
	add({ id = "Mortar", size = v(W.east - W.west, W.under - W.foot, W.back - mortarFace), at = v(0, (W.under + W.foot) / 2, (W.back + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Mortar" })
	for i, x in { { W.west, slab.lo.X }, { slab.hi.X, W.east } } do
		add({ id = "MortarShoulder" .. i, size = v(x[2] - x[1], W.top - 0.6 - W.under, W.back - mortarFace), at = v((x[1] + x[2]) / 2, (W.top - 0.6 + W.under) / 2, (W.back + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Mortar" })
		add({ id = "Coping" .. i, size = v(x[2] - x[1], 0.58, W.back - W.face - K.gap), at = v((x[1] + x[2]) / 2, W.top - 0.31, (W.back + W.face + K.gap) / 2), color = hex(W.coping), material = "Concrete", group = "Mortar" })
	end
	local win = W.window
	local skin = 1.0 -- the room's plaster on the inside of the house above the window
	for i, b in { { W.west, win.x0, W.top, W.above }, { win.x1, W.east, W.top, W.above }, { win.x0, win.x1, win.y1, W.above } } do
		add({ id = "Above" .. i, size = v(b[2] - b[1], b[4] - b[3], W.back - skin - mortarFace), at = v((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (W.back - skin + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Above" })
		add({ id = "AboveSkin" .. i, size = v(b[2] - b[1], b[4] - b[3], skin), at = v((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, W.back - skin / 2), color = hex(W.plaster), material = "Plaster", group = "Above" })
	end
	-- the courses: stretcher bond, a half brick's offset every other course, from under the coping down to the lawn and up round the window
	local brand = rng(region.seed, 13)
	local pitch, course = K.length + K.joint, K.height + K.joint
	local n = 0
	local spalled: { { at: Vector3, size: Vector3 } } = {}
	local function lay(y0: number, y1: number, x0: number, x1: number, offset: number, group: string)
		local x = W.west - offset
		while x < W.east do
			local a, b = math.max(x + K.joint / 2, x0), math.min(x + pitch - K.joint / 2, x1)
			if b - a >= 2.0 then
				n += 1
				local burnt, pale = brand() < 0.08, brand() < 0.06
				local color = if burnt then hex(W.burnt) elseif pale then hex(W.pale) else hex(pick(W.bricks, brand))
				local sink = brand() * 0.05
				local at = v((a + b) / 2, (y0 + y1) / 2, face + sink + K.depth / 2)
				local size = v(b - a, y1 - y0, K.depth)
				add({ id = "Brick" .. n, size = size, at = at, color = color, material = W.brickMaterial, group = group })
				if brand() < 0.1 then table.insert(spalled, { at = at, size = size }) end
			end
			x += pitch
		end
	end
	local c = 0
	local y = W.under - K.joint / 2
	while y - K.height > W.foot - K.height do -- below the slab
		local y0 = math.max(y - K.height, W.foot)
		lay(y0, y, W.west, W.east, (c % 2) * pitch / 2, "Bricks")
		y -= course
		c += 1
	end
	-- the shoulders beside the slab: a short course under the coping
	lay(W.under + K.joint / 2, W.top - 0.6 - K.joint / 2, W.west, slab.lo.X, pitch / 2, "Bricks")
	lay(W.under + K.joint / 2, W.top - 0.6 - K.joint / 2, slab.hi.X, W.east, pitch / 2, "Bricks")
	-- above the outer sill, round the window
	c = 1
	y = W.top + K.joint / 2
	while y + K.height <= W.above do
		local y1 = y + K.height
		if y1 <= win.y1 + 0.5 then
			lay(y, y1, W.west, win.x0, (c % 2) * pitch / 2, "Above")
			lay(y, y1, win.x1, W.east, (c % 2) * pitch / 2, "Above")
		elseif y >= win.y1 then
			lay(y, y1, W.west, W.east, (c % 2) * pitch / 2, "Above")
		else
			lay(y, y1, W.west, win.x0, (c % 2) * pitch / 2, "Above")
			lay(y, y1, win.x1, W.east, (c % 2) * pitch / 2, "Above")
		end
		y += course
		c += 1
	end
	-- weathering (full tier): salt bloom on a few bricks, green algae along the foot where the soil splashes, and the spalled faces
	local erand = rng(region.seed, 17)
	for i, s in spalled do
		add({ id = "Spall" .. i, size = v(s.size.X * between(erand, 0.3, 0.6), s.size.Y * between(erand, 0.3, 0.6), 0.006), at = v(s.at.X + between(erand, -3, 3), s.at.Y + between(erand, -1, 1), face - 0.002),
			color = hex(W.burnt), material = "Concrete", transparency = 0.25, full = true, group = "Weather" })
	end
	for i = 1, 8 do
		add({ id = "Bloom" .. i, size = v(between(erand, 2, 5), between(erand, 1, 2.5), 0.006), at = v(between(erand, W.west + 5, W.east - 5), between(erand, -60, -10), face - 0.002),
			color = hex("d9d2c4"), material = "Plaster", transparency = 0.78, full = true, group = "Weather" })
	end
	for i = 1, 10 do
		local w = between(erand, 4, 11)
		add({ id = "Algae" .. i, size = v(w, between(erand, 1.5, 5), 0.006), at = v(W.west + (i - 0.5) * (W.east - W.west) / 10 + between(erand, -2, 2), W.foot + between(erand, 1, 3), face - 0.002),
			color = hex("4f6a36"), material = "Grass", transparency = 0.4, full = true, group = "Weather" })
	end
	-- ROBLOX-96, the descent's dressing. Cobweb strands in the corner under the outer sill (both tiers for the two long ones: they are what the spider passes on
	-- its way down), lichen patches on the brick and one weathered course whose bricks have lost their faces (full tier).
	local drand = rng(region.seed, 19)
	local corner = if drand() < 0.5 then slab.lo.X else slab.hi.X
	local inward = if corner < 0 then 1 else -1
	local strands = {
		{ a = v(corner + inward * 0.2, W.under - 0.05, face - 0.35), b = v(corner + inward * between(drand, 2.4, 3.6), W.under - between(drand, 2.6, 3.8), face - 0.03), full = false },
		{ a = v(corner + inward * 0.1, W.under - 0.6, face - 0.03), b = v(corner + inward * between(drand, 1.6, 2.6), W.under - 0.05, face - between(drand, 0.5, 0.9)), full = false },
		{ a = v(corner + inward * between(drand, 0.8, 1.4), W.under - 0.05, face - 0.25), b = v(corner + inward * between(drand, 1.8, 2.4), W.under - between(drand, 1.2, 1.8), face - 0.04), full = true },
	}
	for i, s in strands do
		local d = s.b - s.a
		local yaw = math.deg(math.atan2(-d.Z, d.X))
		local tilt = math.deg(math.asin(math.clamp(d.Y / d.Magnitude, -1, 1)))
		add({ id = "Cobweb" .. i, size = v(d.Magnitude, 0.012, 0.012), at = (s.a + s.b) * 0.5, turn = v(0, yaw, tilt), shape = "Cylinder", color = hex("e8e4d8"), material = "Glass",
			transparency = 0.45, full = s.full, group = "Weather" })
	end
	for i = 1, 8 do
		local w = between(drand, 0.6, 1.8)
		add({ id = "Lichen" .. i, size = v(w, w * between(drand, 0.55, 0.9), 0.008), at = v(between(drand, W.west + 4, W.east - 4), between(drand, -72, -16), face - 0.003),
			turn = v(0, 0, drand() * 360), shape = "Ellipsoid", color = hex(pick({ "b9b78f", "c7c4a2", "9fa97d", "d0cdb2" }, drand)), material = "Plaster", full = true, group = "Weather" })
	end
	local weathered = W.under - K.joint / 2 - course * (6 + math.floor(drand() * 5)) -- the top of one course between the sixth and the tenth below the slab
	for i = 1, 6 do
		local w = between(drand, 3, 9)
		add({ id = "Erode" .. i, size = v(w, K.height * between(drand, 0.5, 0.9), 0.01), at = v(between(drand, W.west + 3, W.east - 3), weathered - K.height / 2, face - 0.004),
			color = hex(pick({ "6e3a2a", "7b4433", "8a5540" }, drand)), material = "Concrete", transparency = 0.15, full = true, group = "Weather" })
	end
	-- ROBLOX-103 (full tier, a stream of its own after the rest): rain off the outer sill's front edge leaves darker streaks down the brick under it; the mortar has
	-- weathered darker and deeper in places along the joints; moss grows in the joints near the foot, where the soil splashes
	local xrand = rng(region.seed, 109)
	for i = 1, 6 do
		local w, l = between(xrand, 1.5, 4), between(xrand, 8, 22)
		add({ id = "Drip" .. i, size = v(w, l, 0.006), at = v(between(xrand, slab.lo.X + 3, slab.hi.X - 3), W.under - l / 2 - 0.3, face - 0.0045), color = hex("5e3a2c"), material = "Concrete",
			transparency = 0.6, full = true, group = "Weather" })
	end
	for i = 1, 8 do
		local row = W.under - K.joint / 2 - course * math.floor(between(xrand, 1, 11))
		add({ id = "Joint" .. i, size = v(between(xrand, 6, 18), K.joint * 0.9, 0.01), at = v(between(xrand, W.west + 8, W.east - 8), row + K.joint / 2, mortarFace - 0.006),
			color = hex(pick({ "8f877a", "a39b8d", "7a7366" }, xrand)), material = W.mortarMaterial, full = true, group = "Mortar" })
	end
	for i = 1, 10 do
		local row = W.under - course * (10 + math.floor(xrand() * 2)) -- the middle of a joint near the foot (the courses' joints are at y -3 - 7.5k)
		local s = between(xrand, 0.5, 1.2)
		add({ id = "JointMoss" .. i, size = v(s * 1.6, s * 0.7, s * 0.6), at = v(between(xrand, W.west + 3, W.east - 3), row, face - 0.1), shape = "Ellipsoid",
			color = hex(pick(Garden.OUTER.moss, xrand)), material = "Grass", full = true, group = "Weather" })
	end
	return list
end

-- (ROBLOX-103) The wall above the window and the house round it. Both tiers: the brick courses from y 30 (where the house_wall's look stops) to the eaves over a
-- recessed mortar bed and the room's plaster behind, the soffit, the fascia, the gutter and the eave course of tiles over the pieces they stand in for, the roof's
-- slope from the eaves over the whole house to the ridge, the house's back wall on either side out to 5 m (x 40..500) with its eaves and gutter, and the downpipe.
-- Full tier: the tile joints, the gutter's rolled lip, mortar lines along the long walls, a window and the back door, the downpipe's brackets, leaves, moss and a
-- puddle in the gutter, dirt streaks under it where it overflows, lichen, and an old cobweb in the eaves' corner. Nothing here casts a shadow (no look does), so the
-- light through the window is the light it was.
local function upperDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local U, W = Garden.UPPER, Garden.WALL
	local K, G, E, F, R, H = W.brick, U.gutter, U.eaves, U.fascia, U.roof, U.house
	local list, add = sheet(budget)
	local face = U.face + K.gap
	local mortarFace = U.face + K.recess
	local skin = 1.0
	local gap = 0.02 -- a drawn board sits this far inside the walkable box it stands in for
	local function box(id: string, lo: Vector3, hi: Vector3, color: string, material: string, group: string, full: boolean?, transparency: number?)
		add({ id = id, size = hi - lo, at = (lo + hi) * 0.5, color = hex(color), material = material, group = group, full = full, transparency = transparency })
	end
	local function inside(id: string, lo: Vector3, hi: Vector3, color: string, material: string, group: string)
		box(id, lo + v(gap, gap, gap), hi - v(gap, gap, gap), color, material, group)
	end
	-- the mortar bed and the room's plaster behind, from y 30 to the eaves
	box("Mortar", v(U.west, W.above, mortarFace), v(U.east, U.top, U.back - skin), W.mortar, W.mortarMaterial, "Mortar")
	box("Skin", v(U.west, W.above, U.back - skin), v(U.east, U.top, U.back), W.plaster, "Plaster", "Mortar")
	-- the courses, on from the house_wall's (its courses above the outer sill start at y 0.5, one every brick and joint)
	local brand = rng(region.seed, 13)
	local pitch, course = K.length + K.joint, K.height + K.joint
	local n, c = 0, 0
	local y = W.top + K.joint / 2
	while y + K.height <= W.above do y += course; c += 1 end
	while y + K.height <= U.top - K.joint / 2 do
		local offset = ((c + 1) % 2) * pitch / 2
		local x = U.west - offset
		while x < U.east do
			local a, b = math.max(x + K.joint / 2, U.west), math.min(x + pitch - K.joint / 2, U.east)
			if b - a >= 2.0 then
				n += 1
				local burnt, pale = brand() < 0.08, brand() < 0.06
				local color = if burnt then hex(W.burnt) elseif pale then hex(W.pale) else hex(pick(W.bricks, brand))
				local sink = brand() * 0.05
				add({ id = "Brick" .. n, size = v(b - a, K.height, K.depth), at = v((a + b) / 2, y + K.height / 2, face + sink + K.depth / 2), color = color, material = W.brickMaterial, group = "Bricks" })
			end
			x += pitch
		end
		y += course
		c += 1
	end
	-- the eaves: the soffit, the fascia, the gutter, the eave course of tiles (over the pieces they stand in for)
	inside("Soffit", v(-E.edge, U.top, E.out), v(E.edge, E.top, U.back), U.paint, "Wood", "Eaves")
	inside("Fascia", v(-E.edge, F.bottom, F.out), v(E.edge, E.top, E.out), U.paint, "Wood", "Eaves")
	inside("GutterFloor", v(-G.span, G.floor, G.out), v(G.span, G.floor + G.thick, F.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("GutterLip", v(-G.span, G.floor, G.out - G.wall), v(G.span, G.lip, G.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("GutterWest", v(-G.span - G.cap, G.floor, G.out - G.wall), v(-G.span, G.lip, F.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("GutterEast", v(G.span, G.floor, G.out - G.wall), v(G.span + G.cap, G.lip, F.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("EaveCourse", v(-E.edge, E.top, R.eave), v(E.edge, E.top + R.thick, U.back), R.color, R.material, "Roof")
	-- the roof's slope from the eave over the whole house to the ridge
	local p = math.rad(R.pitch)
	local run = R.ridge - R.eave
	local length = run / math.cos(p)
	local eaveTop = E.top + R.thick
	add({ id = "RoofSlope", size = v(2 * R.x, 3, length), at = v(0, eaveTop + run * math.tan(p) / 2 + 1.5 / math.cos(p) - 0.2, R.eave + run / 2), turn = v(-R.pitch, 0, 0),
		color = hex(R.color), material = R.material, group = "Roof" })
	-- the house's back wall either side, with its eaves and gutter, and the downpipe
	-- (ROBLOX-107: the west side is drawn only beyond wall_west, which is walkable from x -120 to -40 with its own eaves, gutter and the drainpipe that was drawn here)
	local westEnd = Garden.WEST.west
	for _, side in { -1, 1 } do
		local x0, x1 = if side < 0 then -H.x else U.east, if side < 0 then westEnd else H.x
		local e0, e1 = if side < 0 then -H.x else E.edge, if side < 0 then westEnd else H.x
		local name = if side < 0 then "West" else "East"
		box("House" .. name, v(x0, H.foot, U.face + K.gap), v(x1, U.top, U.back), W.bricks[1], W.brickMaterial, "House")
		box("Eaves" .. name, v(e0, U.top, E.out), v(e1, E.top, U.back), U.paint, "Wood", "House")
		box("Fascia" .. name, v(e0, F.bottom, F.out), v(e1, E.top, E.out), U.paint, "Wood", "House")
		box("Gutter" .. name, v(if side < 0 then e0 else G.span + G.cap, G.floor, G.out - G.wall), v(if side < 0 then westEnd - G.cap else e1, G.lip, F.out), U.gutterColor, U.gutterMaterial, "House")
	end
	-- full tier: the tile joints, the gutter's rolled lip, the window and the back door, the downpipe's brackets and shoe
	local trand = rng(region.seed, 101)
	for k = 1, 7 do
		local x = -E.edge + (k - 0.5) * 2 * E.edge / 7 + between(trand, -2, 2)
		add({ id = "TileJoint" .. k, size = v(0.35, R.thick + 0.1, 0.4), at = v(x, E.top + R.thick / 2, R.eave - 0.1), color = hex("4a2a22"), material = R.material, full = true, group = "Roof" })
	end
	add({ id = "GutterBead", size = v(2 * G.span, 1.4, 1.4), at = v(0, G.lip, G.out - G.wall / 2), shape = "Cylinder", color = hex(U.gutterColor), material = U.gutterMaterial, full = true, group = "Gutter" })
	local D, Wn = H.door, H.window
	local stepTop = H.foot + D.step
	add({ id = "BackStep", size = v(D.w + 30, D.step, 30), at = v(D.x, H.foot + D.step / 2, U.face - 15), color = hex("a29d92"), material = "Concrete", full = true, group = "House" })
	add({ id = "BackDoorFrame", size = v(D.w + 8, D.h + 4, 1.2), at = v(D.x, stepTop + (D.h + 4) / 2, U.face - 0.4), color = hex(U.paint), material = "Wood", full = true, group = "House" })
	add({ id = "BackDoor", size = v(D.w, D.h, 1.6), at = v(D.x, stepTop + D.h / 2, U.face - 0.7), color = hex(D.color), material = "WoodPlanks", full = true, group = "House" })
	-- another window like the kitchen's (the sill's: from y 0 to 14, its glass 3 to 13), along the west wall
	add({ id = "WindowFrame", size = v(Wn.w + 2, Wn.h + 2, 1.2), at = v(Wn.x, Wn.sill + (Wn.h + 2) / 2, U.face - 0.4), color = hex(U.paint), material = "Wood", full = true, group = "House" })
	add({ id = "WindowGlass", size = v(Wn.w - 2, Wn.h - 2, 1.4), at = v(Wn.x, Wn.sill + 1 + Wn.h / 2, U.face - 0.6), color = hex("5d7480"), material = "Glass", transparency = 0.2, full = true, group = "House" })
	add({ id = "WindowSill", size = v(Wn.w + 6, 3, 10.5), at = v(Wn.x, Wn.sill - 1.5, U.face + 5.25 - 10.5), color = hex("ddd5c3"), material = "Concrete", full = true, group = "House" })
	-- full tier: what collects in a gutter, the dirt it leaves on the brick, lichen, an old cobweb in the eaves' corner
	local grand = rng(region.seed, 103)
	for k = 1, 8 do
		local s = between(grand, 1.2, 3.2)
		add({ id = "GutterLeaf" .. k, size = v(s, 0.08, s * between(grand, 0.45, 0.7)), at = v(between(grand, -G.span + 2, G.span - 2), G.floor + G.thick + 0.05, between(grand, G.out + 1.5, F.out - 1.5)),
			turn = v(between(grand, 0, 12), grand() * 360, 0), shape = "Ellipsoid", color = hex(pick(U.debris, grand)), material = "Fabric", full = true, group = "Gutter" })
	end
	for k = 1, 3 do
		local s = between(grand, 1.5, 3.0)
		add({ id = "GutterMoss" .. k, size = v(s, s * 0.45, s), at = v(between(grand, -G.span + 3, G.span - 3), G.floor + G.thick + s * 0.15, between(grand, G.out + 2, F.out - 2)),
			shape = "Ellipsoid", color = hex(pick(Garden.OUTER.moss, grand)), material = "Grass", full = true, group = "Gutter" })
	end
	add({ id = "GutterPuddle", size = v(between(grand, 8, 14), 0.06, 7), at = v(between(grand, -20, 20), G.floor + G.thick + 0.03, (G.out + F.out) / 2), shape = "Ellipsoid",
		color = hex("6d7a80"), material = "Glass", transparency = 0.45, full = true, group = "Gutter" })
	for k = 1, 5 do
		local w = between(grand, 3, 8)
		local l = between(grand, 10, 30)
		add({ id = "Streak" .. k, size = v(w, l, 0.006), at = v(between(grand, U.west + 4, U.east - 4), U.top - l / 2 - 0.5, face - 0.003), color = hex("4e4a3c"), material = "Concrete",
			transparency = 0.55, full = true, group = "Weather" })
	end
	for k = 1, 4 do
		local w = between(grand, 0.8, 2.0)
		add({ id = "Lichen" .. k, size = v(w, w * between(grand, 0.55, 0.9), 0.008), at = v(between(grand, U.west + 4, U.east - 4), between(grand, 40, 100), face - 0.003), turn = v(0, 0, grand() * 360),
			shape = "Ellipsoid", color = hex(pick({ "b9b78f", "c7c4a2", "9fa97d", "d0cdb2" }, grand)), material = "Plaster", full = true, group = "Weather" })
	end
	local corner = if grand() < 0.5 then -E.edge + 0.2 else E.edge - 0.2
	local inward = if corner < 0 then 1 else -1
	for k = 1, 3 do
		local a = v(corner, U.top - 0.05, U.face - between(grand, 1, 8))
		local b = v(corner + inward * between(grand, 3, 9), U.top - between(grand, 2, 6), U.face - 0.05)
		local d = b - a
		add({ id = "Cobweb" .. k, size = v(d.Magnitude, 0.012, 0.012), at = (a + b) * 0.5, turn = v(0, math.deg(math.atan2(-d.Z, d.X)), math.deg(math.asin(math.clamp(d.Y / d.Magnitude, -1, 1)))),
			shape = "Cylinder", color = hex("e8e4d8"), material = "Glass", transparency = 0.45, full = true, group = "Weather" })
	end
	-- full tier: mortar lines along the long walls either side, one a course, so they read as brick from the garden
	for i, side in { -1, 1 } do
		local x0, x1 = if side < 0 then -H.x else U.east, if side < 0 then westEnd else H.x
		local yy = W.under - K.joint / 2
		while yy > H.foot do yy -= course end
		yy += course
		local k = 0
		while yy < U.top do
			k += 1
			add({ id = `Course{i}_{k}`, size = v(x1 - x0, K.joint * 0.6, 0.02), at = v((x0 + x1) / 2, yy, U.face + K.gap - 0.012), color = hex(U.houseMortar), material = W.mortarMaterial, full = true, group = "House" })
			yy += course
		end
	end
	return list
end

local function bedDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local B = Garden.BED
	local list, add = sheet(budget)
	local pieces = Garden.pieces(region)
	local top = B.top
	-- what stands on the soil, so the litter, the grass and the pebbles go round it
	local standing: { Box } = {}
	for _, p in pieces do
		if p.lo.Y <= top + 0.01 and p.id ~= "bed_a_soil" then table.insert(standing, { min = p.lo, max = p.hi }) end
	end
	local function free(x: number, z: number, margin: number): boolean
		for _, b in standing do
			if x > b.min.X - margin and x < b.max.X + margin and z > b.min.Z - margin and z < b.max.Z + margin then return false end
		end
		return true
	end
	local function onSoil(rand: () -> number, margin: number): (number, number)
		local x, z = 0.0, 0.0
		for _ = 1, 30 do
			x, z = between(rand, B.x0 + 0.6, B.x1 - 0.6), between(rand, B.z0 + 0.6, B.z1 - 0.6)
			if free(x, z, margin) then break end
		end
		return x, z
	end
	-- the plants first (their leaves are what the spider walks on: the blades are kept at both tiers)
	for _, p in pieces do
		if string.find(p.id, "_leaf_", 1, true) ~= nil then
			leafOver(add, p.id, p.lo, p.hi, "Plants")
		elseif string.find(p.id, "_stem", 1, true) ~= nil or string.find(p.id, "_stalk", 1, true) ~= nil then
			local c = (p.lo + p.hi) * 0.5
			local d = math.min(p.hi.X - p.lo.X, p.hi.Z - p.lo.Z)
			add({ id = p.id .. "Rod", size = v(p.hi.Y - p.lo.Y, d, d), at = c, turn = v(0, 0, 90), shape = "Cylinder", color = hex(B.leaf.stem), material = B.leaf.material, group = "Plants", shadow = true })
			if string.find(p.id, "_stalk", 1, true) ~= nil then
				local F = B.flower
				local head = v(c.X, p.hi.Y + 0.35, c.Z)
				add({ id = "FlowerSepals", size = v(1.6, 0.5, 1.6), at = head - v(0, 0.3, 0), shape = "Ellipsoid", color = hex(F.sepals), material = "SmoothPlastic", group = "Plants" })
				add({ id = "FlowerHead", size = v(2.6, 0.9, 2.6), at = head, shape = "Ellipsoid", color = hex(F.head), material = "SmoothPlastic", group = "Plants" })
				add({ id = "FlowerDisc", size = v(1.3, 0.3, 1.3), at = head + v(0, 0.42, 0), shape = "Ellipsoid", color = hex(F.disc), material = "SmoothPlastic", full = true, group = "Plants" })
			end
		end
	end
	-- the mounds' slopes: a flattened heap of the same soil round each, rising to just under its top, so a mound reads as a heap (the walkable top is the box's)
	for _, p in pieces do
		if string.find(p.id, "mound", 1, true) ~= nil then
			local h = p.hi.Y - p.lo.Y
			add({ id = p.id .. "Slope", size = v((p.hi.X - p.lo.X) * 1.35, h * 1.9, (p.hi.Z - p.lo.Z) * 1.35), at = v((p.lo.X + p.hi.X) / 2, top, (p.lo.Z + p.hi.Z) / 2),
				shape = "Ellipsoid", color = p.color, material = B.soilMaterial, group = "Soil" })
		end
	end
	-- lichen on the stones and moss at their feet
	local lrand = rng(region.seed, 41)
	for _, p in pieces do
		if string.find(p.id, "stone", 1, true) ~= nil then
			for j = 1, 2 do
				local s = between(lrand, 0.5, 1.4)
				add({ id = `{p.id}Lichen{j}`, size = v(0.01, s, s * between(lrand, 0.6, 1.0)), at = v(between(lrand, p.lo.X + s, p.hi.X - s), p.hi.Y + 0.005, between(lrand, p.lo.Z + s, p.hi.Z - s)),
					turn = v(0, lrand() * 360, 90), shape = "Cylinder", color = hex(pick({ "b8b48a", "c9c3a0", "9aa77a" }, lrand)), material = "Plaster", full = true, group = "Stones" })
			end
			for j = 1, 3 do
				local side = lrand() < 0.5
				local x = if side then pick({ p.lo.X - 0.15, p.hi.X + 0.15 }, lrand) else between(lrand, p.lo.X, p.hi.X)
				local z = if side then between(lrand, p.lo.Z, p.hi.Z) else pick({ p.lo.Z - 0.15, p.hi.Z + 0.15 }, lrand)
				local s = between(lrand, 0.35, 0.8)
				add({ id = `{p.id}Moss{j}`, size = v(s, s * 0.5, s), at = v(x, top + s * 0.12, z), shape = "Ellipsoid", turn = v(0, lrand() * 360, 0), color = hex(pick(Garden.OUTER.moss, lrand)), material = "Grass", full = true, group = "Stones" })
			end
		end
	end
	-- the soil: damper and drier patches (full tier)
	local srand = rng(region.seed, 43)
	for i = 1, B.mottle.count do
		local x, z = onSoil(srand, 0.2)
		local w = between(srand, B.mottle.size[1], B.mottle.size[2])
		add({ id = "Mottle" .. i, size = v(w, 0.006, w * between(srand, 0.5, 0.9)), at = v(x, top + 0.003, z), turn = v(0, srand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(B.mottle.colors, srand)), material = B.soilMaterial, full = true, group = "Soil" })
	end
	-- the grass: tufts along the bed's edges and by the stones, each blade a long thin leaf leaning out from the tuft's foot
	local grand = rng(region.seed, 47)
	local G = B.grass
	local tufts: { { x: number, z: number, height: number } } = {} -- (ROBLOX-103: where each tuft stands, for its seed heads below)
	for i = 1, G.tufts do
		local x, z
		if i % 2 == 0 then
			local edge = math.floor(grand() * 3)
			x = if edge == 0 then B.x0 + between(grand, 0.4, 1.6) elseif edge == 1 then B.x1 - between(grand, 0.4, 1.6) else between(grand, B.x0 + 1, B.x1 - 1)
			z = if edge == 2 then B.z0 + between(grand, 0.4, 1.6) else between(grand, B.z0 + 1, B.z1 - B.landing)
		else
			x, z = onSoil(grand, 0.5)
		end
		local height = between(grand, G.height[1], G.height[2])
		table.insert(tufts, { x = x, z = z, height = height })
		for j = 1, G.blades do
			local a = grand() * TAU
			local lean = between(grand, 12, 34)
			local l = height * between(grand, 0.7, 1.0)
			local color = if grand() < 0.15 then hex(G.dry) else hex(pick(G.colors, grand))
			local foot = v(x + math.cos(a) * 0.12, top, z + math.sin(a) * 0.12)
			local out = math.sin(math.rad(lean)) * l / 2
			add({ id = `Tuft{i}Blade{j}`, size = v(0.05, l, between(grand, 0.14, 0.24)), at = foot + v(math.cos(a) * out, math.cos(math.rad(lean)) * l / 2, math.sin(a) * out),
				turn = v(0, -math.deg(a), -lean), shape = "Ellipsoid", color = color, material = "SmoothPlastic", full = j > G.keep, group = "Grass" })
		end
	end
	-- the leaf litter: fallen leaves, flat or a little curled, one in `lowEvery` kept at the low tier
	local frand = rng(region.seed, 53)
	local F = B.litter
	for i = 1, F.count do
		local x, z = onSoil(frand, 0.3)
		local s = between(frand, F.size[1], F.size[2])
		local curl = if frand() < 0.3 then between(frand, 8, 22) else between(frand, 0, 4)
		add({ id = "Litter" .. i, size = v(s, 0.04, s * between(frand, 0.45, 0.7)), at = v(x, top + 0.03 + math.sin(math.rad(curl)) * s * 0.2, z), turn = v(curl, frand() * 360, 0),
			shape = "Ellipsoid", color = hex(pick(F.colors, frand)), material = "SmoothPlastic", full = i % F.lowEvery ~= 0, group = "Litter" })
	end
	-- twigs and pebbles (full tier)
	local trand = rng(region.seed, 59)
	local T = B.twigs
	for i = 1, T.count do
		local x, z = onSoil(trand, 0.4)
		local l = between(trand, T.length[1], T.length[2])
		add({ id = "Twig" .. i, size = v(l, T.width, T.width), at = v(x, top + T.width / 2, z), turn = v(0, trand() * 360, 0), shape = "Cylinder", color = hex(pick(T.colors, trand)), material = "Wood", full = true, group = "Litter" })
	end
	local P = B.pebbles
	for i = 1, P.count do
		local x, z = onSoil(trand, 0.2)
		local s = between(trand, P.size[1], P.size[2])
		add({ id = "Pebble" .. i, size = v(s, s * 0.55, s * between(trand, 0.6, 0.9)), at = v(x, top + s * 0.18, z), turn = v(between(trand, -15, 15), trand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(P.colors, trand)), material = "Pebble", full = true, group = "Litter" })
	end
	-- ROBLOX-103 (W3c), each from a stream of its own after everything placed before, so nothing above moves (the woodlice's litter included):
	-- seed heads on every other tuft (a stalk from the tuft's foot past its blades and a head of seeds on it, full tier);
	local hrand = rng(region.seed, 111)
	local SH = B.seedHeads
	for i, t in tufts do
		if i % 2 == 0 then
			local a = hrand() * TAU
			local lean = between(hrand, 6, 18)
			local l = t.height * between(hrand, SH.over[1], SH.over[2])
			local tipOut = math.sin(math.rad(lean)) * l
			local foot = v(t.x, top, t.z)
			local tip = foot + v(math.cos(a) * tipOut, math.cos(math.rad(lean)) * l, math.sin(a) * tipOut)
			local d = tip - foot
			add({ id = `Tuft{i}Stalk`, size = v(l, 0.04, 0.04), at = (foot + tip) * 0.5, turn = v(0, math.deg(math.atan2(-d.Z, d.X)), math.deg(math.asin(math.clamp(d.Y / d.Magnitude, -1, 1)))),
				shape = "Cylinder", color = hex(SH.stalk), material = "SmoothPlastic", full = true, group = "Grass" })
			add({ id = `Tuft{i}Head`, size = v(0.16, SH.length, 0.16), at = tip + d.Unit * (SH.length * 0.4), turn = v(0, -math.deg(a), -lean), shape = "Ellipsoid",
				color = hex(pick(SH.colors, hrand)), material = "Fabric", full = true, group = "Grass" })
		end
	end
	-- grass clumps along the bed's edges, where the lawn creeps in (one blade of each kept at the low tier), each with a seed head on a stalk;
	local crand = rng(region.seed, 113)
	local C = B.clumps
	for i = 1, C.count do
		local edge = (i - 1) % 3
		local x = if edge == 0 then B.x0 + between(crand, 0.3, 1.0) elseif edge == 1 then B.x1 - between(crand, 0.3, 1.0) else between(crand, B.x0 + 2, B.x1 - 2)
		local z = if edge == 2 then B.z0 + between(crand, 0.3, 1.0) else between(crand, B.z0 + 2, B.z1 - B.landing - 1)
		local height = between(crand, C.height[1], C.height[2])
		for j = 1, C.blades do
			local a = crand() * TAU
			local lean = between(crand, 10, 30)
			local l = height * between(crand, 0.7, 1.0)
			local foot = v(x + math.cos(a) * 0.15, top, z + math.sin(a) * 0.15)
			local out = math.sin(math.rad(lean)) * l / 2
			add({ id = `Clump{i}Blade{j}`, size = v(0.05, l, between(crand, 0.14, 0.22)), at = foot + v(math.cos(a) * out, math.cos(math.rad(lean)) * l / 2, math.sin(a) * out),
				turn = v(0, -math.deg(a), -lean), shape = "Ellipsoid", color = hex(if crand() < 0.15 then B.grass.dry else pick(B.grass.colors, crand)), material = "SmoothPlastic", full = j > 1, group = "Grass" })
		end
		add({ id = `Clump{i}Stalk`, size = v(height * 1.25, 0.04, 0.04), at = v(x, top + height * 0.625, z), turn = v(0, 0, 90), shape = "Cylinder", color = hex(SH.stalk), material = "SmoothPlastic", full = true, group = "Grass" })
		add({ id = `Clump{i}Head`, size = v(0.16, SH.length, 0.16), at = v(x, top + height * 1.25 + SH.length * 0.4, z), shape = "Ellipsoid", color = hex(pick(SH.colors, crand)), material = "Fabric", full = true, group = "Grass" })
	end
	-- and more kinds of litter (full tier): skeleton leaves gone to lace, dark rotting ones, small round ones, husks, and an empty snail shell
	local morerand = rng(region.seed, 127)
	local X = B.moreLitter
	for i = 1, X.count do
		local x, z = onSoil(morerand, 0.3)
		local kind = X.kinds[1 + (i - 1) % #X.kinds]
		local s = between(morerand, kind.size[1], kind.size[2])
		add({ id = "MoreLitter" .. i, size = v(s, 0.035, s * kind.shape), at = v(x, top + 0.025, z), turn = v(between(morerand, 0, 10), morerand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(kind.colors, morerand)), material = "Fabric", transparency = kind.transparency, full = true, group = "Litter" })
	end
	local sx, sz = onSoil(morerand, 0.6)
	add({ id = "SnailShell", size = v(1.1, 0.95, 1.1), at = v(sx, top + 0.42, sz), turn = v(0, morerand() * 360, 70), shape = "Ellipsoid", color = hex("b59a6e"), material = "SmoothPlastic", full = true, group = "Litter" })
	add({ id = "SnailShellBand", size = v(1.12, 0.3, 1.12), at = v(sx, top + 0.42, sz), turn = v(0, 0, 70), shape = "Ellipsoid", color = hex("6b4e2e"), material = "SmoothPlastic", full = true, group = "Litter" })
	return list
end

-- (ROBLOX-107) The brick of the back wall west of the window, on the house_wall's and wall_upper's own grid (the same bond carries across x -40), between two heights:
-- courses below y -3 as the house_wall's, the course beside its shoulders from y -2.5, and from y 0.5 up as the wall above's.
local function westBricks(add: (Drawn) -> boolean, brand: () -> number, ylo: number, yhi: number, group: string): { { at: Vector3, size: Vector3 } }
	local W, K, H = Garden.WEST, Garden.WALL.brick, Garden.WALL
	local face = W.face + K.gap
	local pitch, course = K.length + K.joint, K.height + K.joint
	local laid: { { at: Vector3, size: Vector3 } } = {}
	local n = 0
	local function lay(y0: number, y1: number, offset: number)
		if y1 <= ylo or y0 >= yhi then return end
		local x = W.east - offset - 5 * pitch
		while x < W.east do
			local a, b = math.max(x + K.joint / 2, W.west), math.min(x + pitch - K.joint / 2, W.east)
			if b - a >= 2.0 then
				n += 1
				local burnt, pale = brand() < 0.08, brand() < 0.06
				local color = if burnt then hex(H.burnt) elseif pale then hex(H.pale) else hex(pick(H.bricks, brand))
				local sink = brand() * 0.05
				local at, size = v((a + b) / 2, (y0 + y1) / 2, face + sink + K.depth / 2), v(b - a, y1 - y0, K.depth)
				add({ id = "Brick" .. n, size = size, at = at, color = color, material = H.brickMaterial, group = group })
				table.insert(laid, { at = at, size = size })
			end
			x += pitch
		end
	end
	local c = 0
	local y = H.under - K.joint / 2
	while y - K.height > W.foot - K.height do
		lay(math.max(y - K.height, W.foot), y, (c % 2) * pitch / 2)
		y -= course
		c += 1
	end
	lay(H.under + K.joint / 2, W.rise - K.joint / 2, pitch / 2)
	c = 0
	y = W.rise + K.joint / 2
	while y + K.height <= W.top - K.joint / 2 do
		lay(y, y + K.height, ((c + 1) % 2) * pitch / 2)
		y += course
		c += 1
	end
	return laid
end

-- The drainpipe drawn over its boxes: a rod over each run, the neck out under the gutter and the outlet up into it, and the brackets' collars and ties (both tiers: they
-- stand in for walkable boxes).
local function pipeOver(add: (Drawn) -> boolean, pieces: { Piece })
	local W = Garden.WEST
	local metal = hex(W.color)
	for _, p in pieces do
		local size = p.hi - p.lo
		local c = (p.lo + p.hi) * 0.5
		if string.sub(p.id, -5) == "_pipe" then
			add({ id = "Pipe", size = v(size.Y, size.X, size.Z), at = c, turn = v(0, 0, 90), shape = "Cylinder", color = metal, material = W.material, group = "Drainpipe" })
		elseif string.sub(p.id, -5) == "_neck" then
			add({ id = "Neck", size = v(size.Z, size.X, size.Y), at = c, turn = v(0, 90, 0), shape = "Cylinder", color = metal, material = W.material, group = "Drainpipe" })
			add({ id = "NeckBend", size = v(size.X, size.X * 1.1, size.X * 1.1), at = v(c.X, c.Y, p.hi.Z - size.X / 2), shape = "Ball", color = metal, material = W.material, group = "Drainpipe" })
		elseif string.sub(p.id, -7) == "_outlet" then
			add({ id = "Outlet", size = v(size.Y, size.X, size.Z), at = c, turn = v(0, 0, 90), shape = "Cylinder", color = metal, material = W.material, group = "Drainpipe" })
		elseif string.find(p.id, "_bracket", 1, true) ~= nil then
			add({ id = "Bracket" .. string.sub(p.id, string.find(p.id, "_bracket", 1, true) :: number + 8), size = size - v(0.02, 0.02, 0.02), at = c, color = hex("2e3032"), material = W.material, group = "Drainpipe" })
		end
	end
end

-- (ROBLOX-107) The back wall west of the window, below y 0: the brick courses over a recessed mortar bed, the drainpipe and its lower bracket and the shoe at its foot
-- (both tiers), then at the full tier the damp patch where the drain runs out (darker brick and darker litter, moss), algae along the foot, salt bloom, an old cobweb
-- behind the pipe and lichen.
local function westDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local W, H, K = Garden.WEST, Garden.WALL, Garden.WALL.brick
	local P = W.pipe
	local list, add = sheet(budget)
	local face = W.face + K.gap
	local mortarFace = W.face + K.recess
	add({ id = "Mortar", size = v(W.east - W.west, W.rise - W.foot, W.back - mortarFace), at = v((W.west + W.east) / 2, (W.rise + W.foot) / 2, (W.back + mortarFace) / 2), color = hex(H.mortar), material = H.mortarMaterial, group = "Mortar" })
	local laid = westBricks(add, rng(region.seed, 13), W.foot, W.rise, "Bricks")
	pipeOver(add, Garden.pieces(region))
	local z1 = W.face - P.gap
	local metal = hex(W.color)
	-- the shoe: a socket round the pipe's foot, a little proud of the walkable column (the previews: a box 11 across stood out past the column, over the damp where
	-- the woodlice begin)
	add({ id = "PipeShoe", size = v(3, P.d + 0.6, P.d + 0.6), at = v(P.x, P.foot + 1.5, z1 - P.d / 2), turn = v(0, 0, 90), shape = "Cylinder", color = metal, material = W.material, group = "Drainpipe" })
	-- full tier: the damp at the drain's foot, on the litter and up the brick behind it
	local erand = rng(region.seed, 17)
	add({ id = "DampLitter", size = v(between(erand, 14, 18), 0.008, between(erand, 9, 12)), at = v(P.x, P.foot + 0.004, z1 - P.d - 3), shape = "Ellipsoid", color = hex(W.damp[1]),
		material = "Ground", transparency = 0.2, full = true, group = "Weather" })
	add({ id = "DampBrick", size = v(between(erand, 12, 16), between(erand, 10, 16), 0.006), at = v(P.x, P.foot + 5, face - 0.003), shape = "Ellipsoid", color = hex(W.damp[2]),
		material = "Concrete", transparency = 0.35, full = true, group = "Weather" })
	for i = 1, 5 do
		local s = between(erand, 0.6, 1.4)
		add({ id = "DampMoss" .. i, size = v(s * 1.6, s * 0.6, s), at = v(P.x + between(erand, -7, 7), P.foot + s * 0.2, z1 - P.d - between(erand, 0.5, 4)), shape = "Ellipsoid",
			color = hex(pick(Garden.OUTER.moss, erand)), material = "Grass", full = true, group = "Weather" })
	end
	for i = 1, 8 do
		local w = between(erand, 4, 11)
		add({ id = "Algae" .. i, size = v(w, between(erand, 1.5, 5), 0.006), at = v(W.west + (i - 0.5) * (W.east - W.west) / 8 + between(erand, -2, 2), W.foot + between(erand, 1, 3), face - 0.002),
			color = hex("4f6a36"), material = "Grass", transparency = 0.4, full = true, group = "Weather" })
	end
	for i = 1, 6 do
		add({ id = "Bloom" .. i, size = v(between(erand, 2, 5), between(erand, 1, 2.5), 0.006), at = v(between(erand, W.west + 5, W.east - 5), between(erand, -60, -10), face - 0.002),
			color = hex("d9d2c4"), material = "Plaster", transparency = 0.78, full = true, group = "Weather" })
	end
	for i = 1, 6 do
		local w = between(erand, 0.6, 1.8)
		add({ id = "Lichen" .. i, size = v(w, w * between(erand, 0.55, 0.9), 0.008), at = v(between(erand, W.west + 4, W.east - 4), between(erand, -72, -16), face - 0.003),
			turn = v(0, 0, erand() * 360), shape = "Ellipsoid", color = hex(pick({ "b9b78f", "c7c4a2", "9fa97d", "d0cdb2" }, erand)), material = "Plaster", full = true, group = "Weather" })
	end
	-- an old cobweb in the gap behind the pipe
	for k = 1, 3 do
		local a = v(P.x + between(erand, -3, 3), between(erand, -70, -20), W.face - 0.05)
		local b = a + v(between(erand, -2, 2), between(erand, -3, 3), -P.gap + 0.1)
		local d = b - a
		add({ id = "Cobweb" .. k, size = v(d.Magnitude, 0.012, 0.012), at = (a + b) * 0.5, turn = v(0, math.deg(math.atan2(-d.Z, d.X)), math.deg(math.asin(math.clamp(d.Y / d.Magnitude, -1, 1)))),
			shape = "Cylinder", color = hex("e8e4d8"), material = "Glass", transparency = 0.45, full = true, group = "Weather" })
	end
	local srand = rng(region.seed, 19)
	for i, s in laid do
		if srand() < 0.08 then
			add({ id = "Spall" .. i, size = v(s.size.X * between(srand, 0.3, 0.6), s.size.Y * between(srand, 0.3, 0.6), 0.006), at = v(s.at.X + between(srand, -3, 3), s.at.Y + between(srand, -1, 1), face - 0.002),
				color = hex(H.burnt), material = "Concrete", transparency = 0.25, full = true, group = "Weather" })
		end
	end
	return list
end

-- (ROBLOX-107) The same wall from y 0 to the eaves: the courses over the mortar, the eaves, fascia, gutter and eave course over their boxes, the drainpipe's top, neck,
-- outlet and upper bracket (both tiers), then at the full tier the gutter's rolled lip, leaves and moss in it, dirt streaks down the brick under it, and lichen.
local function westUpperDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local W, U, H, K = Garden.WEST, Garden.UPPER, Garden.WALL, Garden.WALL.brick
	local G, E, F, R = U.gutter, U.eaves, U.fascia, U.roof
	local list, add = sheet(budget)
	local face = W.face + K.gap
	local mortarFace = W.face + K.recess
	local gap = 0.02
	local function inside(id: string, lo: Vector3, hi: Vector3, color: string, material: string, group: string)
		add({ id = id, size = hi - lo - v(2 * gap, 2 * gap, 2 * gap), at = (lo + hi) * 0.5, color = hex(color), material = material, group = group })
	end
	add({ id = "Mortar", size = v(W.east - W.west, W.top - W.rise, W.back - mortarFace), at = v((W.west + W.east) / 2, (W.top + W.rise) / 2, (W.back + mortarFace) / 2), color = hex(H.mortar), material = H.mortarMaterial, group = "Mortar" })
	westBricks(add, rng(region.seed, 13), W.rise, W.top, "Bricks")
	local joint = -G.span - G.cap
	inside("Soffit", v(W.west, U.top, E.out), v(-E.edge, E.top, U.back), U.paint, "Wood", "Eaves")
	inside("Fascia", v(W.west, F.bottom, F.out), v(-E.edge, E.top, E.out), U.paint, "Wood", "Eaves")
	inside("GutterFloor", v(W.west, G.floor, G.out), v(joint, G.floor + G.thick, F.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("GutterLip", v(W.west, G.floor, G.out - G.wall), v(joint, G.lip, G.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("GutterWest", v(W.west - G.cap, G.floor, G.out - G.wall), v(W.west, G.lip, F.out), U.gutterColor, U.gutterMaterial, "Gutter")
	inside("EaveCourse", v(W.west, E.top, R.eave), v(-E.edge, E.top + R.thick, U.back), R.color, R.material, "Roof")
	pipeOver(add, Garden.pieces(region))
	-- full tier
	add({ id = "GutterBead", size = v(joint - W.west, 1.4, 1.4), at = v((W.west + joint) / 2, G.lip, G.out - G.wall / 2), shape = "Cylinder", color = hex(U.gutterColor), material = U.gutterMaterial, full = true, group = "Gutter" })
	local grand = rng(region.seed, 103)
	for k = 1, 6 do
		local s = between(grand, 1.2, 3.2)
		add({ id = "GutterLeaf" .. k, size = v(s, 0.08, s * between(grand, 0.45, 0.7)), at = v(between(grand, W.west + 2, joint - 2), G.floor + G.thick + 0.05, between(grand, G.out + 1.5, F.out - 1.5)),
			turn = v(between(grand, 0, 12), grand() * 360, 0), shape = "Ellipsoid", color = hex(pick(U.debris, grand)), material = "Fabric", full = true, group = "Gutter" })
	end
	for k = 1, 2 do
		local s = between(grand, 1.5, 3.0)
		add({ id = "GutterMoss" .. k, size = v(s, s * 0.45, s), at = v(between(grand, W.west + 3, joint - 3), G.floor + G.thick + s * 0.15, between(grand, G.out + 2, F.out - 2)),
			shape = "Ellipsoid", color = hex(pick(Garden.OUTER.moss, grand)), material = "Grass", full = true, group = "Gutter" })
	end
	for k = 1, 4 do
		local w, l = between(grand, 3, 8), between(grand, 10, 30)
		add({ id = "Streak" .. k, size = v(w, l, 0.006), at = v(between(grand, W.west + 4, W.east - 4), U.top - l / 2 - 0.5, face - 0.003), color = hex("4e4a3c"), material = "Concrete",
			transparency = 0.55, full = true, group = "Weather" })
	end
	for k = 1, 4 do
		local w = between(grand, 0.8, 2.0)
		add({ id = "Lichen" .. k, size = v(w, w * between(grand, 0.55, 0.9), 0.008), at = v(between(grand, W.west + 4, W.east - 4), between(grand, 20, 100), face - 0.003), turn = v(0, 0, grand() * 360),
			shape = "Ellipsoid", color = hex(pick({ "b9b78f", "c7c4a2", "9fa97d", "d0cdb2" }, grand)), material = "Plaster", full = true, group = "Weather" })
	end
	return list
end

-- (ROBLOX-107) A chunk of the bushes. Both tiers: the twigs over the stems and branches, each leaf pad as a hanging cluster of leaves with its top at the pad's (the
-- clusters cast shadows), a skirt of foliage on the litter round each bush, the dead leaf and its twigs, the heaps. Full tier: leaves lying on the pads, the crown
-- over each bush, privet flowers, damp patches on the litter. Then the litter itself, fallen leaves of the bushes and of the garden, to the budget: kept at the low tier
-- until its ceiling, then the full tier's (so both tiers are always at their budgets, and the first few the low tier keeps are where the woodlice hide).
local function shrubDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local S = Garden.SHRUB
	local G = groundOf(region)
	local top = G.top
	local list, add = sheet(budget)
	local pieces = Garden.pieces(region)
	local rand = rng(region.seed, 139)
	-- what stands on the litter, for the litter to go round; and each bush's stems, for its skirt and crown
	local standing: { Box } = {}
	local bushes: { [number]: { stems: { Vector3 }, top: number } } = {}
	for _, p in pieces do
		if p.lo.Y <= top + 0.01 and p.id ~= G.soil then table.insert(standing, { min = p.lo, max = p.hi }) end
		local i = tonumber(string.match(p.id, "_bush(%d)_"))
		if i ~= nil then
			local b: { stems: { Vector3 }, top: number } = bushes[i] or { stems = {} :: { Vector3 }, top = top }
			bushes[i] = b
			if string.find(p.id, "_stem", 1, true) ~= nil then table.insert(b.stems, (p.lo + p.hi) * 0.5) end
			b.top = math.max(b.top, p.hi.Y)
		end
	end
	for _, b in Garden.standingFrom(region) do table.insert(standing, b) end
	local function free(x: number, z: number, margin: number): boolean
		for _, b in standing do
			if x > b.min.X - margin and x < b.max.X + margin and z > b.min.Z - margin and z < b.max.Z + margin then return false end
		end
		return true
	end
	for _, p in pieces do
		local size, c = p.hi - p.lo, (p.lo + p.hi) * 0.5
		local bark = hex(pick(S.bark, rand))
		if string.find(p.id, "_stem", 1, true) ~= nil then
			add({ id = p.id .. "Twig", size = v(size.Y, size.X, size.Z), at = c, turn = v(0, 0, 90), shape = "Cylinder", color = bark, material = "Wood", group = "Twigs" })
		elseif string.find(p.id, "_branch", 1, true) ~= nil then
			local alongX = size.X >= size.Z
			add({ id = p.id .. "Twig", size = if alongX then v(size.X, size.Y, size.Z) else v(size.Z, size.Y, size.X), at = c, turn = if alongX then nil else v(0, 90, 0), shape = "Cylinder",
				color = bark, material = "Wood", group = "Twigs" })
		elseif string.find(p.id, "_pad", 1, true) ~= nil or string.find(p.id, "_crown", 1, true) ~= nil then
			local P = size.X
			add({ id = p.id .. "Cluster", size = v(P * 1.5, P * 0.9, P * 1.5), at = v(c.X, p.lo.Y + 0.05 - P * 0.45, c.Z), shape = "Ellipsoid", color = hex(pick(S.foliage, rand)),
				material = "LeafyGrass", shadow = true, group = "Leaves" })
			add({ id = p.id .. "Mat", size = v(P * 1.2, size.Y, P * 1.2), at = v(c.X, p.hi.Y - size.Y / 2, c.Z), shape = "Ellipsoid", color = hex(pick(S.sunlit, rand)), material = "LeafyGrass", group = "Leaves" })
		elseif string.find(p.id, "_deadleaf", 1, true) ~= nil then
			add({ id = "DeadLeaf", size = v(size.X * 1.08, size.Y * 1.6, size.Z * 1.08), at = v(c.X, p.hi.Y - size.Y * 0.8, c.Z), turn = v(0, 0, 0), shape = "Ellipsoid",
				color = hex(pick(S.deadLeaf, rand)), material = "Fabric", group = "Retreat" })
		elseif string.find(p.id, "_twig_", 1, true) ~= nil then
			local d = math.min(size.X, size.Y)
			add({ id = p.id .. "Rod", size = v(size.Z, d, d), at = v(c.X, p.lo.Y + d / 2, c.Z), turn = v(0, 90, 0), shape = "Cylinder", color = bark, material = "Wood", group = "Retreat" })
			add({ id = p.id .. "Under", size = v(size.Z * 0.9, size.Y - d / 2, size.X * 0.6), at = v(c.X, p.lo.Y + d / 2 + (size.Y - d / 2) / 2, c.Z), turn = v(0, 90, 0), shape = "Ellipsoid",
				color = hex(pick(S.deadLeaf, rand)), material = "Fabric", group = "Retreat" })
		elseif string.find(p.id, "_heap_", 1, true) ~= nil then
			add({ id = p.id .. "Heap", size = v(size.X * 1.35, size.Y * 1.9, size.Z * 1.35), at = v(c.X, top, c.Z), shape = "Ellipsoid", color = hex(pick(S.litterColors, rand)), material = "Fabric", group = "Litter" })
		end
	end
	-- each bush's skirt of foliage on the litter (two of four at the low tier), its crown over it and its privet flowers (full tier); the first bush's skirt leaves the dead
	-- leaf's way in open
	local brand = rng(region.seed, 149)
	for i = 1, 2 do
		local b = bushes[i]
		if b ~= nil and #b.stems > 0 then
			local mid = Vector3.zero
			for _, s in b.stems do mid += s end
			mid /= #b.stems
			local h = b.top - top
			local w = h * 0.9
			local angles: { number } = if i == 1 then { -150, -90, -30, 150 } else { brand() * 360, brand() * 360 + 90, brand() * 360 + 180, brand() * 360 + 270 }
			for k, a in angles do
				local r = w * between(brand, 0.28, 0.4)
				add({ id = `Bush{i}Skirt{k}`, size = v(w * 0.34, w * 0.2, w * 0.3), at = v(mid.X + math.cos(math.rad(a)) * r, top + w * 0.05, mid.Z + math.sin(math.rad(a)) * r), turn = v(0, -a, 0),
					shape = "Ellipsoid", color = hex(pick(S.foliage, brand)), material = "LeafyGrass", shadow = true, full = k > 2, group = "Leaves" })
			end
			-- (the previews: twigs and flat pads alone read as a stand of lollipops, not a bush, which is what ROBLOX-103 took away from the view) the bush's
			-- outer mass, three rings of leaf clusters from the litter up round the frame, so from outside it is a dense bush to the ground and from inside (the
			-- camera within a cluster sees out through it) the twigs and pads are the way through. Drawn only; at the low tier the first of the lowest two rings.
			-- None over the drainpipe's foot, past the chunk's edge or the house's wall, or (the first bush) in front of the dead leaf's way in.
			local srand = rng(region.seed, 167 + i)
			for ring, R in S.bush.shell do
				for k = 1, R.n do
					local a = (k - 1) * 360 / R.n + between(srand, -18, 18) + ring * 31
					local rr, size = w * R.r, v(w * R.w, h * R.h, w * R.w)
					local c = v(mid.X + math.cos(math.rad(a)) * rr, top + h * R.y, mid.Z + math.sin(math.rad(a)) * rr)
					local lo, hi = c - size * 0.5, c + size * 0.5
					local s = math.sin(math.rad(a))
					local ok = lo.X >= G.x0 and hi.X <= G.x1 and lo.Z >= G.z0 and hi.Z <= G.z1 - G.landing and not (i == 1 and ring == 1 and s > 0.5)
					for _, sb in Garden.standingFrom(region) do
						if lo.X < sb.max.X + 1 and hi.X > sb.min.X - 1 and lo.Z < sb.max.Z + 1 and hi.Z > sb.min.Z - 1 then ok = false end
					end
					if ok then
						add({ id = `Bush{i}Mass{ring}{k}`, size = size, at = c, turn = v(0, -a, 0), shape = "Ellipsoid", color = hex(pick(S.foliage, srand)), material = "LeafyGrass",
							shadow = true, full = not (ring <= 2 and k == 1), group = "Leaves" })
					end
				end
			end
			for k = 1, 3 do
				local a = k * 120 + brand() * 40
				local r = w * 0.16
				add({ id = `Bush{i}Crown{k}`, size = v(w * 0.36, w * 0.24, w * 0.36), at = v(mid.X + math.cos(math.rad(a)) * r, b.top + w * 0.1, mid.Z + math.sin(math.rad(a)) * r),
					shape = "Ellipsoid", color = hex(pick(S.sunlit, brand)), material = "LeafyGrass", shadow = true, full = true, group = "Leaves" })
			end
			for k = 1, 4 do
				local a = brand() * 360
				local r = w * between(brand, 0.25, 0.42)
				local s = between(brand, 1.6, 2.6)
				add({ id = `Bush{i}Flower{k}`, size = v(s, s * 1.4, s), at = v(mid.X + math.cos(math.rad(a)) * r, top + h * between(brand, 0.65, 0.95), mid.Z + math.sin(math.rad(a)) * r),
					shape = "Ellipsoid", color = hex(pick(S.privet, brand)), material = "SmoothPlastic", full = true, group = "Flowers" })
			end
		end
	end
	-- leaves lying on the pads (full tier)
	local lrand = rng(region.seed, 151)
	for _, p in pieces do
		if string.find(p.id, "_pad", 1, true) ~= nil or string.find(p.id, "_crown", 1, true) ~= nil then
			for k = 1, 3 do
				local s = between(lrand, 0.9, 1.4)
				add({ id = `{p.id}Leaf{k}`, size = v(s, 0.04, s * 0.5), at = v(between(lrand, p.lo.X + 0.6, p.hi.X - 0.6), p.hi.Y + 0.02, between(lrand, p.lo.Z + 0.6, p.hi.Z - 0.6)),
					turn = v(between(lrand, -6, 6), lrand() * 360, 0), shape = "Ellipsoid", color = hex(pick(S.foliage, lrand)), material = "SmoothPlastic", full = true, group = "Leaves" })
			end
		end
	end
	-- damp patches on the litter (full tier)
	local mrand = rng(region.seed, 157)
	for i = 1, 6 do
		local x, z = between(mrand, G.x0 + 3, G.x1 - 3), between(mrand, G.z0 + 3, G.z1 - 3)
		local w = between(mrand, 4, 10)
		add({ id = "Mottle" .. i, size = v(w, 0.006, w * between(mrand, 0.5, 0.9)), at = v(x, top + 0.003, z), turn = v(0, mrand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(S.mottle, mrand)), material = "Ground", full = true, group = "Litter" })
	end
	-- the litter, to the budget: the low tier's first, then the full tier's
	local frand = rng(region.seed, 163)
	local low = true
	local i = 0
	for _ = 1, 4000 do
		local x, z = 0.0, 0.0
		for _ = 1, 30 do
			x, z = between(frand, G.x0 + 0.6, G.x1 - 0.6), between(frand, G.z0 + 0.6, G.z1 - 0.6)
			if free(x, z, 0.3) then break end
		end
		local s = between(frand, S.litterSize[1], S.litterSize[2])
		local curl = if frand() < 0.3 then between(frand, 8, 22) else between(frand, 0, 4)
		local rec: Drawn = { id = "Litter" .. (i + 1), size = v(s, 0.04, s * between(frand, 0.45, 0.7)), at = v(x, top + 0.03 + math.sin(math.rad(curl)) * s * 0.2, z),
			turn = v(curl, frand() * 360, 0), shape = "Ellipsoid", color = hex(pick(S.litterColors, frand)), material = "SmoothPlastic", full = not low, group = "Litter" }
		if add(rec) then
			i += 1
		elseif low then
			low = false
		else
			break
		end
	end
	return list
end

-- ---------------------------------------------------------------- the questions Region asks
-- The budgets: the most drawn parts a region of the kind may carry at each tier. They are what the generators place now (tests/world.luau builds the looks and
-- holds each tier to them exactly, so a look that grows says so here); the placers stop at them (`sheet`), keeping what they place first. ROBLOX-96: the wall's
-- 93/73 became 110/75 with the descent's dressing. ROBLOX-103 (W3c, more detail): the outer sill 94/36 to 116/39 (fallen petals, seeds, dry leaves, hairline
-- cracks), the wall 110/75 to 134/75 (drip streaks, weathered joints, moss in the joints), the bed 364/107 to 466/113 (side veins on its seven leaves, seed heads,
-- six edge clumps, fourteen more pieces of litter and a snail shell), and the new wall_upper 154/59 (the brick to the eaves, the eaves and the gutter, the roof, the
-- rest of the house drawn round them). All four together are 870 parts at full and 286 at low, beside the sill's Decor (Region's BUDGETS).
Garden.BUDGETS = {
	outer_sill = { full = 116, low = 39 },
	house_wall = { full = 134, low = 75 },
	bed = { full = 466, low = 113 },
	wall_upper = { full = 150, low = 58 },
	wall_west = { full = 93, low = 59 },
	wall_west_upper = { full = 88, low = 71 },
	shrub = { full = 260, low = 80 },
} :: { [string]: { full: number, low: number } }

local piecesCache: { [string]: { Piece } } = {}
local decorCache: { [string]: { Drawn } } = {}

-- Whether a kind is one of the garden's.
function Garden.knows(kind: string): boolean
	return kind == "outer_sill" or kind == "house_wall" or kind == "bed" or kind == "wall_upper" or kind == "wall_west" or kind == "wall_west_upper" or kind == "shrub"
end

-- The physical boxes of a region of one of the garden's kinds (the same list for the same region; do not change it).
function Garden.pieces(region: WorldMap.Region): { Piece }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = piecesCache[key]
	if cached ~= nil then return cached end
	local out: { Piece }
	if region.kind == "outer_sill" then out = outerPieces()
	elseif region.kind == "house_wall" then out = wallPieces()
	elseif region.kind == "bed" then out = bedPieces(region)
	elseif region.kind == "wall_upper" then out = upperPieces()
	elseif region.kind == "wall_west" then out = westPieces()
	elseif region.kind == "wall_west_upper" then out = westUpperPieces()
	elseif region.kind == "shrub" then out = shrubPieces(region)
	else error("no generator for the region kind " .. region.kind) end
	piecesCache[key] = out
	return out
end

-- The drawn look of a region of one of the garden's kinds, at the full tier (the low tier is the records without `full`).
function Garden.decor(region: WorldMap.Region): { Drawn }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = decorCache[key]
	if cached ~= nil then return cached end
	local budget = Garden.BUDGETS[region.kind]
	local out: { Drawn }
	if region.kind == "outer_sill" then out = outerDecor(region, budget)
	elseif region.kind == "house_wall" then out = wallDecor(region, budget)
	elseif region.kind == "bed" then out = bedDecor(region, budget)
	elseif region.kind == "wall_upper" then out = upperDecor(region, budget)
	elseif region.kind == "wall_west" then out = westDecor(region, budget)
	elseif region.kind == "wall_west_upper" then out = westUpperDecor(region, budget)
	elseif region.kind == "shrub" then out = shrubDecor(region, budget)
	else error("no generator for the region kind " .. region.kind) end
	decorCache[key] = out
	return out
end

-- The drawn look of a region placed under another budget than its kind's (not kept): what a tighter ceiling leaves out, for the tests.
function Garden.decorWith(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	if region.kind == "outer_sill" then return outerDecor(region, budget) end
	if region.kind == "house_wall" then return wallDecor(region, budget) end
	if region.kind == "bed" then return bedDecor(region, budget) end
	if region.kind == "wall_upper" then return upperDecor(region, budget) end
	if region.kind == "wall_west" then return westDecor(region, budget) end
	if region.kind == "wall_west_upper" then return westUpperDecor(region, budget) end
	if region.kind == "shrub" then return shrubDecor(region, budget) end
	error("no generator for the region kind " .. region.kind)
end

-- The pieces of a region that its drawn look stands in for: those turn invisible (still solid) once the look is built. The wall's boxes are drawn as bricks and
-- the plants' as leaves and stems; the slab, the stones and the soil are their own look.
function Garden.drawnPieces(region: WorldMap.Region): { string }
	local out: { string } = {}
	for _, p in Garden.pieces(region) do
		if region.kind == "house_wall" or region.kind == "wall_upper" or region.kind == "wall_west" or region.kind == "wall_west_upper" or (region.kind == "shrub" and p.id ~= region.id .. "_soil") or string.find(p.id, "_leaf_", 1, true) ~= nil or string.find(p.id, "_stem", 1, true) ~= nil or string.find(p.id, "_stalk", 1, true) ~= nil then
			table.insert(out, p.id)
		end
	end
	return out
end

-- The pieces of a region that the sill's drawn world stands in for: the window box's halves on the outer sill, drawn with the flowers in them by the sill's Decor
-- (Habitat/Plants.garden), and solid here.
function Garden.drawnBySill(region: WorldMap.Region): { string }
	local out: { string } = {}
	if region.kind == "outer_sill" then
		for _, half in Flora.garden.box.boxes do table.insert(out, half.id) end
	end
	return out
end

-- ---------------------------------------------------------------- the bed's life (ROBLOX-96)
export type Perch = { id: string, position: Vector3, normal: Vector3, shelter: number, food: number, start: boolean, walker: boolean?, kind: string,
	hop: boolean?, behind: string?, round: Vector3? } -- (ROBLOX-101: a hopper's perch; the leafhopper's far side and the point it passes going round)
export type Vent = { id: string, position: Vector3, normal: Vector3, walker: boolean?, reach: number?, appear: boolean? }
export type PreySpec = { perches: { Perch }, vents: { Vent }, target: number, seed: number, prefix: string }
export type HideSpot = { pos: Vector3, kind: string }
-- (ROBLOX-107) `prefix`, when set, goes before each woodlouse's id: the bushes' chunks are many and two may run at once beside the bed, so theirs carry the chunk
-- ("shrub_west_a_louse_1"); the bed's have none and keep the ids they always had ("louse_1"), so a kept rest's woodlice are the same ones.
export type BugSpec = { woodlice: { { pos: Vector3, heading: Vector3 } }, hides: { HideSpot }, seed: number, prefix: string? }

local preyCache: { [string]: PreySpec } = {}
local bugsCache: { [string]: BugSpec } = {}

-- The standing boxes of the bed (everything on the soil but the soil), and a seeded free spot on the soil clear of them by `margin` (nil after forty tries).
local function standingOf(region: WorldMap.Region): { Box }
	local G = groundOf(region)
	local standing: { Box } = {}
	for _, p in Garden.pieces(region) do
		if p.lo.Y <= G.top + 0.01 and p.id ~= G.soil then table.insert(standing, { min = p.lo, max = p.hi }) end
	end
	for _, b in Garden.standingFrom(region) do table.insert(standing, b) end
	return standing
end
local function freeSpot(rand: () -> number, standing: { Box }, taken: { Vector3 }, margin: number, apart: number, ground: Ground?): Vector3?
	local B = ground or (Garden.BED :: any)
	for _ = 1, 40 do
		local x, z = between(rand, B.x0 + 2, B.x1 - 2), between(rand, B.z0 + 2, B.z1 - B.landing - 1)
		local ok = true
		for _, b in standing do
			if x > b.min.X - margin and x < b.max.X + margin and z > b.min.Z - margin and z < b.max.Z + margin then ok = false; break end
		end
		if ok then
			for _, t in taken do
				if (Vector3.new(x, 0, z) - Vector3.new(t.X, 0, t.Z)).Magnitude < apart then ok = false; break end
			end
		end
		if ok then
			local p = v(x, B.top, z)
			table.insert(taken, p)
			return p
		end
	end
	return nil
end

-- The bed's perches and vents for its prey director, from the region's own boxes and seed: the gnats' on the soil (seeded free spots), on every mound's and
-- stone's top and under the dock's leaves; the aphids' (walker perches) on the dock's leaves and stem and the dandelion's leaves; the gnats' vents two more spots
-- on the soil, the aphids' at the plants. Perches sit exactly on a box's face (the director's graph casts for the face and keeps only what it finds).
function Garden.prey(region: WorldMap.Region): PreySpec?
	if region.kind ~= "bed" then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = preyCache[key]
	if cached ~= nil then return cached end
	local B, P = Garden.BED, Garden.BED.prey
	local pieces = Garden.pieces(region)
	local byId: { [string]: Piece } = {}
	for _, p in pieces do byId[p.id] = p end
	local perches: { Perch } = {}
	local vents: { Vent } = {}
	local function perch(id: string, pos: Vector3, normal: Vector3, kind: string, start: boolean, walker: boolean?)
		table.insert(perches, { id = id, position = pos, normal = normal, shelter = P.shelter[kind], food = P.food[kind], start = start, walker = walker, kind = kind })
	end
	local standing = standingOf(region)
	local taken: { Vector3 } = {}
	local rand = rng(region.seed, 61)
	-- the soil: seeded free spots about three studs apart at least, the first two the gnats' starts
	local soilSpots: { Vector3 } = {}
	for i = 1, P.soil do
		local spot = freeSpot(rand, standing, taken, 0.8, 3)
		if spot then perch(`{region.id}_soil_{i}`, spot, Vector3.yAxis, "soil", i <= 2); table.insert(soilSpots, spot) end
	end
	-- the mounds' and the stones' tops
	for _, p in pieces do
		if string.find(p.id, "_mound_", 1, true) ~= nil then
			perch(p.id .. "_top", v((p.lo.X + p.hi.X) / 2, p.hi.Y, (p.lo.Z + p.hi.Z) / 2), Vector3.yAxis, "mound", false)
		elseif p.id == "bed_a_stone_top" or string.find(p.id, "_stone_%a$") ~= nil then
			perch(p.id .. "_top", v((p.lo.X + p.hi.X) / 2, p.hi.Y, (p.lo.Z + p.hi.Z) / 2), Vector3.yAxis, "stone", false)
		end
	end
	-- the dock: under each leaf for the gnats (the first a start), on each leaf and on the stem's side for the aphids (the first leaf and the stem starts)
	local stem = byId[region.id .. "_dock_stem"]
	if stem ~= nil then
		for i = 1, 3 do
			local leaf = byId[`{region.id}_dock_leaf_{i}`]
			if leaf ~= nil then
				local cx, cz = (leaf.lo.X + leaf.hi.X) / 2, (leaf.lo.Z + leaf.hi.Z) / 2
				perch(leaf.id .. "_under", v(cx, leaf.lo.Y, cz), -Vector3.yAxis, "under", i == 1)
				perch(leaf.id .. "_top", v(cx, leaf.hi.Y, cz), Vector3.yAxis, "leaf", i == 1, true)
			end
		end
		perch(stem.id .. "_side", v(stem.hi.X, B.top + 3.5, (stem.lo.Z + stem.hi.Z) / 2), Vector3.xAxis, "stem", true, true)
		table.insert(vents, { id = region.id .. "_vent_dock", position = v(stem.hi.X + 1.2, B.top, (stem.lo.Z + stem.hi.Z) / 2), normal = Vector3.yAxis, walker = true, reach = P.reach.dock })
	end
	-- the dandelion's rosette: walker perches, the first a start
	local stalk = byId[region.id .. "_dandelion_stalk"]
	if stalk ~= nil then
		for i = 1, 4 do
			local leaf = byId[`{region.id}_dandelion_leaf_{i}`]
			if leaf ~= nil then perch(leaf.id .. "_top", v((leaf.lo.X + leaf.hi.X) / 2, leaf.hi.Y, (leaf.lo.Z + leaf.hi.Z) / 2), Vector3.yAxis, "leaf", i == 1, true) end
		end
		table.insert(vents, { id = region.id .. "_vent_dandelion", position = v(stalk.hi.X + 0.3, B.top + 0.25, stalk.hi.Z + 0.3), normal = Vector3.yAxis, walker = true, reach = P.reach.dandelion })
	end
	-- the gnats' vents: two more spots on the soil within an entry flight of a soil perch, listed first and third so neither kind of entry always comes first
	for i = 1, P.vents do
		local spot: Vector3? = nil
		for _ = 1, 12 do
			local try = freeSpot(rand, standing, taken, 0.8, 2)
			if try == nil then break end
			for _, sp in soilSpots do
				local d = (sp - try).Magnitude
				if d >= P.ventNear[1] and d <= P.ventNear[2] then spot = try; break end
			end
			if spot ~= nil then break end
		end
		if spot then table.insert(vents, math.min(1 + (i - 1) * 2, #vents + 1), { id = `{region.id}_vent_soil_{i}`, position = spot, normal = Vector3.yAxis }) end
	end
	local out: PreySpec = { perches = perches, vents = vents, target = P.target, seed = region.seed, prefix = region.id .. "_fly_" }
	preyCache[key] = out
	return out
end

-- The bed's woodlice: their starting places on the soil (seeded free spots) and the spots they hide in: the mouth and the back of the gap under the big stone, the
-- foot of each other stone, and a few of the fallen leaves the low tier keeps.
-- (ROBLOX-107) Under the bushes: the mouth and the back of the gap under the dead leaf, the drainpipe's foot where its chunk holds it (a damp patch: the first
-- two lice start there), and the litter the low tier keeps.
local function shrubBugs(region: WorldMap.Region): BugSpec
	local S, L = Garden.SHRUB, Garden.SHRUB.woodlice
	local G = groundOf(region)
	local hides: { HideSpot } = {}
	local damp = Garden.drainFoot(region)
	if damp ~= nil then table.insert(hides, { pos = damp, kind = "drain" }) end
	for _, t in region.retreats do
		local cx = (t.min.X + t.max.X) / 2
		table.insert(hides, { pos = v(cx, S.top, t.max.Z + 0.6), kind = "leaf" })
		table.insert(hides, { pos = v(cx, S.top, t.min.Z - 0.6), kind = "leaf" })
	end
	local litter = 0
	for _, d in Garden.decor(region) do
		if litter < L.litterSpots and string.sub(d.id, 1, 6) == "Litter" and not d.full then
			litter += 1
			table.insert(hides, { pos = v(d.at.X, S.top, d.at.Z), kind = "litter" })
		end
	end
	local standing = standingOf(region)
	local taken: { Vector3 } = {}
	local rand = rng(region.seed, 67)
	local lice: { { pos: Vector3, heading: Vector3 } } = {}
	for i = 1, L.count do
		local spot: Vector3? = nil
		if damp ~= nil and i <= 2 then
			local a, d = rand() * TAU, between(rand, 0.8, 2.5)
			spot = v(damp.X + math.cos(a) * d, S.top, damp.Z - math.abs(math.sin(a)) * d)
			table.insert(taken, spot :: Vector3)
		else
			spot = freeSpot(rand, standing, taken, 1.0, 5, G)
		end
		if spot then
			local a = rand() * TAU
			table.insert(lice, { pos = spot, heading = v(math.cos(a), 0, math.sin(a)) })
		end
	end
	return { woodlice = lice, hides = hides, seed = region.seed, prefix = region.id .. "_" }
end

function Garden.bugs(region: WorldMap.Region): BugSpec?
	if region.kind ~= "bed" and region.kind ~= "shrub" then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = bugsCache[key]
	if cached ~= nil then return cached end
	if region.kind == "shrub" then
		local spec = shrubBugs(region)
		bugsCache[key] = spec
		return spec
	end
	local B, L = Garden.BED, Garden.BED.woodlice
	local hides: { HideSpot } = {}
	for _, t in region.retreats do
		local cx = (t.min.X + t.max.X) / 2
		table.insert(hides, { pos = v(cx, B.top, t.max.Z + 0.6), kind = "stone" })
		table.insert(hides, { pos = v(cx, B.top, t.min.Z - 0.6), kind = "stone" })
	end
	for _, p in Garden.pieces(region) do
		if string.find(p.id, "_stone_%a$") ~= nil then table.insert(hides, { pos = v((p.lo.X + p.hi.X) / 2, B.top, p.lo.Z - 0.4), kind = "stone" }) end
	end
	local litter = 0
	for _, d in Garden.decor(region) do
		if litter < L.litterSpots and string.sub(d.id, 1, 6) == "Litter" and not d.full then
			litter += 1
			table.insert(hides, { pos = v(d.at.X, B.top, d.at.Z), kind = "litter" })
		end
	end
	local standing = standingOf(region)
	local taken: { Vector3 } = {}
	local rand = rng(region.seed, 67)
	local lice: { { pos: Vector3, heading: Vector3 } } = {}
	for _ = 1, L.count do
		local spot = freeSpot(rand, standing, taken, 1.0, 5)
		if spot then
			local a = rand() * TAU
			table.insert(lice, { pos = spot, heading = v(math.cos(a), 0, math.sin(a)) })
		end
	end
	local out: BugSpec = { woodlice = lice, hides = hides, seed = region.seed }
	bugsCache[key] = out
	return out
end

-- ---------------------------------------------------------------- the bestiary's prey (ROBLOX-101)
-- How many of each kind a region holds at the full tier and the low one (the phone is the limit: the bed's prey stays at 12 at full with W3's six, 9 at low), the
-- streams' salts, and the perches' shelter and food (game values: the plants are the leafhoppers' food, the stones the springtails' cover, the wall a place to
-- sit still). `dusk`: the hours of the life clock from which (dusk) and until which (dawn) the moths and the crane flies fly (World/LifeClock: dusk at 19, the
-- evening from 18, dawn at 6).
Garden.BESTIARY = {
	bed = {
		{ kind = "springtail", full = 4, low = 2, salt = 71, perches = 12, near = { 0.7, 2.2 }, apart = 1.0, reach = 6, shelter = 0.5, food = 0.4 },
		{ kind = "leafhopper", full = 2, low = 1, salt = 73, reach = 14, shelter = 0.4, food = 0.6 },
	} :: { any },
	-- (ROBLOX-107) springtails in the litter under the bushes, round the dead leaf, the drain's foot and the litter the woodlice hide in
	shrub = {
		{ kind = "springtail", full = 4, low = 2, salt = 71, perches = 12, near = { 0.7, 2.2 }, apart = 1.0, reach = 6, shelter = 0.5, food = 0.4 },
	} :: { any },
	house_wall = {
		{ kind = "moth", full = 2, low = 1, salt = 79, perches = 8, x = { -30, 30 }, y = { -45, -6 }, apart = 5, reach = 30, shelter = 0.2, food = 0.1 },
		{ kind = "crane_fly", full = 1, low = 1, salt = 83, perches = 6, x = { -20, 20 }, y = { -86, -40 }, apart = 6, reach = 45, shelter = 0.2, food = 0.1 },
	} :: { any },
	outer_sill = {
		{ kind = "moth", full = 1, low = 1, salt = 89, reach = 40, shelter = 0.3, food = 0.1 },
		{ kind = "crane_fly", full = 1, low = 0, salt = 97, reach = 40, shelter = 0.3, food = 0.1 },
	} :: { any },
	dusk = { from = 18.0, to = 6.0 },
} :: any

export type KindSpec = PreySpec & { kind: string, profile: string, low: number, dusk: { from: number, to: number }? }
local bestiaryCache: { [string]: { KindSpec } } = {}

-- The springtails' spots: free soil within `near` of each hide spot the woodlice use (the big stone's mouth and back, the other stones' feet, the litter), clear
-- of every standing box and of the retreat, `apart` from each other.
local function springtailPerches(region: WorldMap.Region, row: any, rand: () -> number): { Perch }
	local B = groundOf(region)
	local standing = standingOf(region)
	for _, t in region.retreats do table.insert(standing, { min = t.min - v(0.5, 0, 0.5), max = t.max + v(0.5, 0, 0.5) }) end
	local hides = (Garden.bugs(region) :: BugSpec).hides
	local out: { Perch } = {}
	local taken: { Vector3 } = {}
	local i = 0
	for _ = 1, 3 do
		for _, h in hides do
			if #out >= row.perches then break end
			for _ = 1, 12 do
				local a, d = rand() * TAU, between(rand, row.near[1], row.near[2])
				local x, z = h.pos.X + math.cos(a) * d, h.pos.Z + math.sin(a) * d
				local ok = x > B.x0 + 1 and x < B.x1 - 1 and z > B.z0 + 1 and z < B.z1 - 1
				if ok then
					for _, b in standing do
						if x > b.min.X - 0.3 and x < b.max.X + 0.3 and z > b.min.Z - 0.3 and z < b.max.Z + 0.3 then ok = false; break end
					end
				end
				if ok then
					for _, t in taken do
						if (Vector3.new(x, 0, z) - Vector3.new(t.X, 0, t.Z)).Magnitude < row.apart then ok = false; break end
					end
				end
				if ok then
					i += 1
					local p = v(x, B.top, z)
					table.insert(taken, p)
					table.insert(out, { id = `{region.id}_springtail_{i}`, position = p, normal = Vector3.yAxis, shelter = row.shelter, food = row.food, start = i <= row.full, kind = "soil", hop = true })
					break
				end
			end
		end
		if #out >= row.perches then break end
	end
	return out
end

-- The leafhoppers' perches, in pairs either side of a stem, a stalk or a leaf (each the other's `behind`, with the point to pass going round): the dock's stem low
-- (east and west) and high (north and south), the dandelion's stalk (east and west), and each dock leaf's top and underside two thirds of the way to its tip.
local function leafhopperPerches(region: WorldMap.Region, row: any): { Perch }
	local B = Garden.BED
	local byId: { [string]: Piece } = {}
	for _, p in Garden.pieces(region) do byId[p.id] = p end
	local out: { Perch } = {}
	local n = 0
	local function pair(a: Vector3, na: Vector3, b: Vector3, nb: Vector3, round: Vector3, kind: string, start: boolean)
		n += 1
		local ia, ib = `{region.id}_leafhopper_{n}a`, `{region.id}_leafhopper_{n}b`
		table.insert(out, { id = ia, position = a, normal = na, shelter = row.shelter, food = row.food, start = start, kind = kind, hop = true, behind = ib, round = round })
		table.insert(out, { id = ib, position = b, normal = nb, shelter = row.shelter, food = row.food, start = false, kind = kind, hop = true, behind = ia, round = round })
	end
	local stem = byId[region.id .. "_dock_stem"]
	if stem ~= nil then
		local mx, mz = (stem.lo.X + stem.hi.X) / 2, (stem.lo.Z + stem.hi.Z) / 2
		local y1, y2 = B.top + 1.5, B.top + 9
		pair(v(stem.hi.X, y1, mz), Vector3.xAxis, v(stem.lo.X, y1, mz), -Vector3.xAxis, v(mx, y1, stem.hi.Z + 0.35), "stem", true)
		pair(v(mx, y2, stem.hi.Z), Vector3.zAxis, v(mx, y2, stem.lo.Z), -Vector3.zAxis, v(stem.hi.X + 0.35, y2, mz), "stem", false)
	end
	local stalk = byId[region.id .. "_dandelion_stalk"]
	if stalk ~= nil then
		local mx, mz = (stalk.lo.X + stalk.hi.X) / 2, (stalk.lo.Z + stalk.hi.Z) / 2
		local y = B.top + 5
		pair(v(stalk.hi.X, y, mz), Vector3.xAxis, v(stalk.lo.X, y, mz), -Vector3.xAxis, v(mx, y, stalk.hi.Z + 0.3), "stem", false)
	end
	for i, leaf in B.dock.leaves do
		local box = byId[`{region.id}_dock_leaf_{i}`]
		if box ~= nil then
			local cx, cz = (box.lo.X + box.hi.X) / 2, (box.lo.Z + box.hi.Z) / 2
			local my = (box.lo.Y + box.hi.Y) / 2
			local x, z, rx, rz = cx, cz, cx, cz
			if leaf.dir == "x+" then x = box.lo.X + (box.hi.X - box.lo.X) * 2 / 3; rx = box.hi.X + 0.35
			elseif leaf.dir == "x-" then x = box.hi.X - (box.hi.X - box.lo.X) * 2 / 3; rx = box.lo.X - 0.35
			elseif leaf.dir == "z+" then z = box.lo.Z + (box.hi.Z - box.lo.Z) * 2 / 3; rz = box.hi.Z + 0.35
			else z = box.hi.Z - (box.hi.Z - box.lo.Z) * 2 / 3; rz = box.lo.Z - 0.35 end
			if leaf.dir == "x+" or leaf.dir == "x-" then rz = z else rx = x end
			pair(v(x, box.hi.Y, z), Vector3.yAxis, v(x, box.lo.Y, z), -Vector3.yAxis, v(rx, my, rz), "leaf", i == 2)
		end
	end
	return out
end

-- Seeded spots on the house wall's face (z -24, facing the garden), `apart` from each other, inside `x` and between the heights `y`.
local function wallPerches(region: WorldMap.Region, row: any, rand: () -> number): { Perch }
	local W = Garden.WALL
	local out: { Perch } = {}
	local taken: { Vector3 } = {}
	for i = 1, row.perches do
		for _ = 1, 40 do
			local p = v(between(rand, row.x[1], row.x[2]), between(rand, row.y[1], row.y[2]), W.face)
			local ok = true
			for _, t in taken do if (t - p).Magnitude < row.apart then ok = false; break end end
			if ok then
				table.insert(taken, p)
				table.insert(out, { id = `{region.id}_{row.kind}_{i}`, position = p, normal = -Vector3.zAxis, shelter = row.shelter, food = row.food, start = i <= row.full, kind = "wall" })
				break
			end
		end
	end
	return out
end

-- The outer sill's: the moths by the window (the slab's ends against the frame, the window box's fronts, the slab's front edge either side of the way down), the
-- crane flies out at the slab's front corners and on the box's fronts beside them.
local function outerPerches(region: WorldMap.Region, row: any): { Perch }
	local O, Bx = Garden.OUTER, Flora.garden.box
	local top, front = O.slab.hi.Y, O.slab.lo.Z
	local boxFront, boxMid = Bx.z0, (Bx.top + Bx.bottom) / 2
	local spots: { { Vector3 | string } }
	if row.kind == "moth" then
		spots = {
			{ v(-27.5, top, -15.0), "slab" }, { v(27.5, top, -15.0), "slab" },
			{ v(-17.0, boxMid, boxFront), "box" }, { v(17.0, boxMid, boxFront), "box" },
			{ v(-4.0, -1.5, front), "edge" }, { v(4.0, -1.5, front), "edge" },
		}
	else
		spots = {
			{ v(-27.0, top, -22.0), "slab" }, { v(-20.0, boxMid, boxFront), "box" },
			{ v(27.0, top, -22.0), "slab" }, { v(20.0, boxMid, boxFront), "box" },
		}
	end
	local out: { Perch } = {}
	for i, s in spots do
		local pos, kind = s[1] :: Vector3, s[2] :: string
		table.insert(out, { id = `{region.id}_{row.kind}_{i}`, position = pos, normal = if kind == "slab" then Vector3.yAxis else -Vector3.zAxis, shelter = row.shelter,
			food = row.food, start = i <= math.max(row.full, 1), kind = kind })
	end
	return out
end

-- The region's bestiary prey: one spec per kind, in the order the directors run (nil for none). Each spec is a Prey/PreyDirector spec with its kind, the profile
-- it is made with (Data/Species, by name), the targets at the full and the low tier, its own seed (the region's mixed with the kind's salt) and its flies' prefix
-- (`bed_a_springtail_`...), and for the moths and the crane flies the hours they fly. Every vent is an `appear` vent: the prey comes on a free perch in reach,
-- out of sight.
function Garden.bestiary(region: WorldMap.Region): { KindSpec }?
	local rows = (Garden.BESTIARY :: any)[region.kind]
	if rows == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = bestiaryCache[key]
	if cached ~= nil then return cached end
	local out: { KindSpec } = {}
	for _, row in rows do
		local rand = rng(region.seed, row.salt)
		local perches: { Perch }
		local vents: { Vent } = {}
		if row.kind == "springtail" then
			perches = springtailPerches(region, row, rand)
			local hides = (Garden.bugs(region) :: BugSpec).hides
			for i = 1, math.min(2, #hides) do
				table.insert(vents, { id = `{region.id}_vent_springtail_{i}`, position = hides[i * 2 - 1].pos, normal = Vector3.yAxis, appear = true, reach = row.reach })
			end
		elseif row.kind == "leafhopper" then
			perches = leafhopperPerches(region, row)
			for _, p in Garden.pieces(region) do
				if p.id == region.id .. "_dock_stem" or p.id == region.id .. "_dandelion_stalk" then
					table.insert(vents, { id = `{p.id}_vent_leafhopper`, position = v((p.lo.X + p.hi.X) / 2, Garden.BED.top, p.lo.Z - 0.6), normal = Vector3.yAxis, appear = true, reach = row.reach })
				end
			end
		elseif region.kind == "house_wall" then
			perches = wallPerches(region, row, rand)
			local y = (row.y[1] + row.y[2]) / 2
			for i, x in { -20, 20 } do
				table.insert(vents, { id = `{region.id}_vent_{row.kind}_{i}`, position = v(x, y, Garden.WALL.face - 2), normal = -Vector3.zAxis, appear = true, reach = row.reach })
			end
		else
			perches = outerPerches(region, row)
			table.insert(vents, { id = `{region.id}_vent_{row.kind}`, position = v(0, 1, -20), normal = Vector3.yAxis, appear = true, reach = row.reach })
		end
		local seed = (region.seed + row.salt * 104729) % MOD
		table.insert(out, {
			kind = row.kind, profile = row.kind .. "_prototype", perches = perches, vents = vents, target = row.full, low = row.low, seed = seed,
			prefix = `{region.id}_{row.kind}_fly_`, dusk = if row.kind == "moth" or row.kind == "crane_fly" then Garden.BESTIARY.dusk else nil,
		})
	end
	bestiaryCache[key] = out
	return out
end

-- ---------------------------------------------------------------- the plants as paths (ROBLOX-105, W3b part B)
-- Each of the bed's plants as a set of walks over its own faces, for the things that walk a plant: an aphid going from one of its perches to another (Prey/PreyKinds
-- `creep`) and a ladybird (Prey/Ladybird). A plant has a `highway` (points on its faces, each { pos, normal }: the dock's stem's bare north face from its foot to
-- its top, which no leaf meets; the dandelion's ring of soil round its stalk, a `loop`) and `nodes`, each a `hub` (the highway point it leaves from) and a `route`
-- from there over the faces to the node, every point on a face or on the edge where two meet (its normal between theirs). A node named by a perch id stands
-- exactly on that perch (the aphids' walker perches); the others are places only the ladybird goes (the dock's top and foot, the dandelion's stalk).
export type PlantPoint = { pos: Vector3, normal: Vector3 }
export type Plant = { id: string, loop: boolean, highway: { PlantPoint }, nodes: { [string]: { hub: number, route: { PlantPoint } } }, order: { string } }
local plantsCache: { [string]: { [string]: Plant } } = {}
local plantOfPerch: { [string]: string } = {} -- perch id -> plant id, filled as plants are made

local function unit(a: Vector3, b: Vector3): Vector3
	return (a + b).Unit
end

function Garden.plants(region: WorldMap.Region): { [string]: Plant }?
	if region.kind ~= "bed" then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = plantsCache[key]
	if cached ~= nil then return cached end
	local B = Garden.BED
	local byId: { [string]: Piece } = {}
	for _, p in Garden.pieces(region) do byId[p.id] = p end
	local out: { [string]: Plant } = {}
	local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	local function pt(pos: Vector3, normal: Vector3): PlantPoint return { pos = pos, normal = normal } end
	-- the dock: the stem's north face (z lo) is the highway, its points at the heights the nodes leave it
	local stem = byId[region.id .. "_dock_stem"]
	if stem ~= nil then
		local s0, s1 = stem.lo, stem.hi
		local mx, mz = (s0.X + s1.X) / 2, (s0.Z + s1.Z) / 2
		local heights: { number } = {}
		local nodes: { [string]: { hub: number, route: { PlantPoint } } } = {}
		local order: { string } = {}
		local pending: { { id: string, y: number, route: { PlantPoint } } } = {}
		local function add(id: string, y: number, route: { PlantPoint })
			table.insert(pending, { id = id, y = y, route = route })
			if table.find(heights, y) == nil then table.insert(heights, y) end
		end
		add(region.id .. "_dock_foot", B.top + 0.5, {})
		add(region.id .. "_dock_stem_side", B.top + 3.5, { pt(v(s1.X, B.top + 3.5, s0.Z), unit(X, -Z)), pt(v(s1.X, B.top + 3.5, mz), X) })
		for i, leaf in B.dock.leaves do
			local box = byId[`{region.id}_dock_leaf_{i}`]
			if box ~= nil then
				local y1 = box.hi.Y
				local centre = pt(v((box.lo.X + box.hi.X) / 2, y1, (box.lo.Z + box.hi.Z) / 2), Y)
				local route: { PlantPoint }
				if leaf.dir == "x+" then
					route = { pt(v(s1.X, y1, s0.Z), unit(X, -Z)), pt(v(s1.X, y1, mz), unit(X, Y)), centre }
				elseif leaf.dir == "x-" then
					route = { pt(v(s0.X, y1, s0.Z), unit(-X, -Z)), pt(v(s0.X, y1, mz), unit(-X, Y)), centre }
				elseif leaf.dir == "z+" then
					route = { pt(v(s0.X, y1, s0.Z), unit(-X, -Z)), pt(v(s0.X, y1, s1.Z), unit(-X, Z)), pt(v(mx, y1, s1.Z), unit(Z, Y)), centre }
				else
					route = { pt(v(mx, y1, s0.Z), unit(-Z, Y)), centre }
				end
				add(box.id .. "_top", y1, route)
			end
		end
		add(region.id .. "_dock_top", s1.Y - 0.6, {})
		table.sort(heights)
		local highway: { PlantPoint } = {}
		for _, y in heights do table.insert(highway, pt(v(mx, y, s0.Z), -Z)) end
		for _, n in pending do
			nodes[n.id] = { hub = table.find(heights, n.y) :: number, route = n.route }
			table.insert(order, n.id)
			plantOfPerch[n.id] = "dock"
		end
		out.dock = { id = "dock", loop = false, highway = highway, nodes = nodes, order = order }
	end
	-- the dandelion: a ring of eight points on the soil round the stalk; each rosette leaf leaves from the ring point toward it, up its inner end and out to its
	-- middle; the stalk is climbed from the east point
	local stalk = byId[region.id .. "_dandelion_stalk"]
	if stalk ~= nil then
		local cx, cz = (stalk.lo.X + stalk.hi.X) / 2, (stalk.lo.Z + stalk.hi.Z) / 2
		local half = (stalk.hi.X - stalk.lo.X) / 2
		local L = B.dandelion
		local ring = half + 0.35
		local inner = half + L.leaf.gap
		local highway: { PlantPoint } = {}
		for k = 0, 7 do
			local a = k * math.pi / 4
			table.insert(highway, pt(v(cx + math.cos(a) * ring, B.top, cz + math.sin(a) * ring), Y))
		end
		local nodes: { [string]: { hub: number, route: { PlantPoint } } } = {}
		local order: { string } = {}
		local dirs = { X, Z, -X, -Z } -- the rosette's leaves 1..4 (Garden's bedPieces), on the ring's points 1, 3, 5, 7
		for i, d in dirs do
			local box = byId[`{region.id}_dandelion_leaf_{i}`]
			if box ~= nil then
				local y1 = box.hi.Y
				local foot = v(cx, B.top, cz) + d * inner
				local id = box.id .. "_top"
				nodes[id] = { hub = 2 * i - 1, route = {
					pt(foot, unit(Y, -d)), pt(foot + Y * (y1 - B.top), unit(Y, -d)),
					pt(v((box.lo.X + box.hi.X) / 2, y1, (box.lo.Z + box.hi.Z) / 2), Y),
				} }
				table.insert(order, id)
				plantOfPerch[id] = "dandelion"
			end
		end
		local up = region.id .. "_dandelion_stalk_up"
		nodes[up] = { hub = 1, route = { pt(v(stalk.hi.X, B.top, cz), unit(X, Y)), pt(v(stalk.hi.X, B.top + L.height * 0.75, cz), X) } }
		table.insert(order, up)
		out.dandelion = { id = "dandelion", loop = true, highway = highway, nodes = nodes, order = order }
	end
	plantsCache[key] = out
	return out
end

-- The plant a perch is on ("dock", "dandelion") and the bed's plants, or nil for a perch on no plant. Every bed of the map is made the first time it is asked.
function Garden.plantOf(perchId: string): (string?, { [string]: Plant }?)
	local name = plantOfPerch[perchId]
	if name == nil then
		for _, r in WorldMap.regions() do if r.kind == "bed" then Garden.plants(r) end end
		name = plantOfPerch[perchId]
	end
	if name == nil then return nil, nil end
	for _, r in WorldMap.regions() do
		if r.kind == "bed" then
			local plants = Garden.plants(r) :: { [string]: Plant }
			local plant = plants[name]
			if plant ~= nil and plant.nodes[perchId] ~= nil then return name, plants end
		end
	end
	return nil, nil
end

-- The walk over a plant from one node to another: a list of points, the first on the node left, the last on the node reached (nil when either is not the
-- plant's). Down the first node's route to the highway, along it (the shorter way round a loop), out along the second's route.
function Garden.plantPath(plant: Plant, from: string, to: string): { PlantPoint }?
	local a, b = plant.nodes[from], plant.nodes[to]
	if a == nil or b == nil then return nil end
	local out: { PlantPoint } = {}
	for i = #a.route, 1, -1 do table.insert(out, a.route[i]) end
	local n = #plant.highway
	table.insert(out, plant.highway[a.hub])
	if a.hub ~= b.hub then
		local step = if b.hub > a.hub then 1 else -1
		local count = math.abs(b.hub - a.hub)
		if plant.loop and count > n / 2 then step, count = -step, n - count end
		local k = a.hub
		for _ = 1, count do
			k = ((k - 1 + step) % n) + 1
			table.insert(out, plant.highway[k])
		end
	end
	for _, p in b.route do table.insert(out, p) end
	-- the node's own point first and last (a node whose route is empty is its hub)
	local first = if #a.route > 0 then a.route[#a.route] else plant.highway[a.hub]
	if out[1] ~= first then table.insert(out, 1, first) end
	return out
end

-- ---------------------------------------------------------------- the ambient bugs (ROBLOX-105, W3b part B)
-- The garden's other life that is not food (docs/GARDEN_BESTIARY.md's ambient table): how many of each kind a region holds at the full tier and the low one,
-- the streams' salts, and the parts the region's ambient bodies may cost at each tier (Client/BugBodies.partsOf; tests/garden_life.luau holds the sum under it).
-- The ladybirds walk the bed's plants among the aphids (one on the dock, one on the dandelion), the millipedes the soil and under the stones, the snail the
-- soil and the wall's foot, a harvestman the bed's litter and one the house wall, from dusk.
Garden.AMBIENT = {
	order = { "ladybird", "millipede", "snail", "harvestman" },
	bed = {
		ladybird = { full = 2, low = 1, salt = 101 },
		millipede = { full = 2, low = 1, salt = 103 },
		snail = { full = 1, low = 1, salt = 107 },
		harvestman = { full = 1, low = 1, salt = 109 },
	},
	house_wall = {
		harvestman = { full = 1, low = 1, salt = 113 },
	},
	budget = { bed = { full = 240, low = 110 }, house_wall = { full = 24, low = 24 } },
	-- the snail's piece of wall: the brick's foot over the bed (x, and y above the soil); the wall harvestman's walk on the brick and its corner by day
	wallFoot = { x = { -20, 20 }, y = { 1.5, 14 } },
	wall = { x = { -36, 36 }, y = { -84, -8 }, home = { -34, -82 } },
} :: any

export type AmbientSpec = { kind: string, seed: number, full: number, low: number, starts: { any }, prefix: string, hides: { HideSpot }?, home: Vector3?, surface: string?,
	rect: { x: { number }, y: { number } }? }
local ambientCache: { [string]: { AmbientSpec } } = {}

-- The region's ambient bugs: one spec per kind, in AMBIENT.order (nil for a region with none). Each has its own seed (the region's mixed with the kind's salt) and
-- its starting places for the full tier's count (the low tier takes the first `low`).
function Garden.ambient(region: WorldMap.Region): { AmbientSpec }?
	local rows = (Garden.AMBIENT :: any)[region.kind]
	if rows == nil or region.kind == "order" or region.kind == "budget" then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = ambientCache[key]
	if cached ~= nil then return cached end
	local A = Garden.AMBIENT
	local out: { AmbientSpec } = {}
	for _, kind in A.order do
		local row = rows[kind]
		if row ~= nil then
			local rand = rng(region.seed, row.salt)
			local seed = (region.seed + row.salt * 104729) % MOD
			local spec: AmbientSpec = { kind = kind, seed = seed, full = row.full, low = row.low, starts = {}, prefix = region.id .. "_" } -- (ids: bed_a_ladybird_1 ...)
			if region.kind == "bed" then
				local standing = standingOf(region)
				for _, t in region.retreats do table.insert(standing, { min = t.min - v(0.5, 0, 0.5), max = t.max + v(0.5, 0, 0.5) }) end
				local hides = (Garden.bugs(region) :: BugSpec).hides
				local taken: { Vector3 } = {}
				if kind == "ladybird" then
					local plants = Garden.plants(region) :: { [string]: Plant }
					local names = { "dock", "dandelion" }
					for i = 1, row.full do
						local plant = plants[names[(i - 1) % #names + 1]]
						if plant ~= nil then
							local node = plant.order[1 + math.floor(rand() * #plant.order)]
							table.insert(spec.starts, { plant = plant.id, node = node })
						end
					end
				else
					for _ = 1, row.full do
						local spot = freeSpot(rand, standing, taken, if kind == "snail" then 2.0 else 1.2, 6)
						if spot then
							local a = rand() * TAU
							table.insert(spec.starts, { pos = spot, heading = v(math.cos(a), 0, math.sin(a)) })
						end
					end
					local stones, litter = {}, {}
					for _, h in hides do if h.kind == "stone" then table.insert(stones, h) else table.insert(litter, h) end end
					if kind == "millipede" then spec.hides = stones end
					if kind == "harvestman" then spec.home = if #litter > 0 then litter[1].pos else hides[1].pos end
					if kind == "snail" then spec.rect = A.wallFoot end
				end
				spec.surface = "soil"
			else
				-- the house wall: a harvestman on the brick, its corner at the wall's foot by day
				local W = A.wall
				for _ = 1, row.full do
					local p = v(between(rand, W.x[1] + 6, W.x[2] - 6), between(rand, W.y[1] + 10, W.y[2] - 10), Garden.WALL.face)
					local a = rand() * TAU
					table.insert(spec.starts, { pos = p, heading = v(math.cos(a), math.sin(a), 0) })
				end
				spec.home = v(W.home[1], W.home[2], Garden.WALL.face)
				spec.rect = W
				spec.surface = "wall"
			end
			table.insert(out, spec)
		end
	end
	ambientCache[key] = out
	return out
end

-- The boxes a region's creatures keep out of: each retreat grown by half a stud (the sill's are its own, Region.keepOut).
function Garden.keepOut(region: WorldMap.Region): { Box }
	if not Garden.knows(region.kind) then error("no generator for the region kind " .. region.kind) end
	local out: { Box } = {}
	for _, t in region.retreats do
		table.insert(out, { min = t.min - v(0.5, 0.5, 0.5), max = t.max + v(0.5, 0.5, 0.5) })
	end
	return out
end

return table.freeze(Garden)
