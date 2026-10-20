--!strict
-- The map of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): what regions there are, where each one is, where a life begins in it, where
-- it can rest, and how fast its day runs. Pure data and pure questions about a point; nothing here builds a part or knows the engine, so the
-- server, the client and the CLI tests all ask the same thing. The sill is region 0 of one continuous garden: its numbers are the windowsill's
-- own (Habitat/WindowsillLayout, which stays the sill's data), and everything that used to read them from the layout asks here.
--
-- A region: `id`; `kind` (what generates its boxes: Region.pieces/Region.decor); `origin` (world studs; the sill is at the origin exactly as
-- it always was); `bounds` ({ min, max }, the volume a spider may be in while it is in this region: the motor's fall-off box, a checkpoint's
-- check); `seed` (the world's seed mixed with the region's id, for the region's placers: WorldMap.seed); `neighbors` (the seams to the regions
-- it meets: each the face line, `a` to `b`, where the two regions' walkable surfaces meet); `retreats` (box volumes where the spider can rest, edges
-- included: the sill's crack, the gap under the bed's stone); `spawn` (the support point and heading where a life begins here, and where a rest
-- from another revision of the world is put back); `clockScale` (how fast this region's day runs against the sill's, 1.0: LifeClock.game).
--
-- Regions are listed in priority order; bounds may touch or overlap where two regions meet, and a point in both belongs to the first region listed.
--
-- ROBLOX-95 (W2, beyond the glass): the lower sash is raised and the world outside exists. Four regions, from the window down:
--   sill ........ the windowsill, as it was but for the opening in its back frame (x -8..8, y 0.7..6); its bounds are still the layout's play bounds, whose
--                 margin reaches 2.5 studs out past the frame (to z -16), so the first steps onto the outer sill are still the sill's.
--   outer_sill .. the stone slab outside, top y 0, x -30..30, z -24..-13.5, with the window box's halves on it; it meets the sill along the opening's rail
--                 (z -13.5, x -8..8, where the rail's outer face meets the stone) and the wall where the stone's front face becomes brick (z -24, y -3).
--   house_wall .. the brick wall below, face at z -24 from y 0 to the lawn, x -40..40; the air 6 studs out from its face is the wall's down to y -89.
--   bed_a ....... the soil under the window, top y -90, x -25..25, z -24..-74, and the air over it; it meets the wall along the wall's foot (z -24, y -90,
--                 x -25..25). Its stone is the first garden home. Its day runs at a third of the sill's pace (Nathan's 0.33; W4 tunes it).
-- ROBLOX-103 (W3c, docs/WORLD_MAP_PLAN.md region 4): the house is a single story, so the wall above the window ends at the eaves.
--   wall_upper .. the brick above the window up to the eaves (face z -24, y 14..110, x -40..40), standing on the window's two jambs (x 31..40 either side, y 0..14,
--                 on the wall's shoulders), the eaves' soffit, the fascia board and the gutter hung on it (its floor y 109, 1.09 m above the sill: a high perch), and
--                 the first course of roof tiles over the gutter. It meets the wall where the jambs' faces go on up from the shoulders' (z -24, y 0, x 31..40 on the
--                 east; the west is the same and the map lists one line per pair, as it always has). Added somewhere new, so WorldMap.REVISION stays: nothing moved
--                 but the house_wall's spawn, which stood on the east shoulder's top where the east jamb now stands (a spawn is only where a rest from another
--                 revision goes back to, and nothing can rest on the wall). No retreat and no prey yet.
-- ROBLOX-107 (docs/WORLD_MAP_PLAN.md regions 5 and 6): the back wall west of the window with its drainpipe, and the bushes beside the bed. Added somewhere new, so
-- WorldMap.REVISION stays: no box of any region before moved.
--   wall_west ....... the back wall west of the house_wall, face z -24, x -120..-40, from the lawn to y 0, and the drainpipe's foot: a column standing on the litter
--                     1.2 studs off the brick at x -50, joined to the wall by brackets. It meets the house_wall where the brick goes on west (x -40), the wall above it
--                     at y 0, and the bushes' litter at its foot. The house's pace (1.0), no retreat.
--   wall_west_upper . the same wall from y 0 to the eaves, the drainpipe's top with its swan neck and outlet into the gutter, and the eaves, fascia, gutter and eave
--                     course on west of wall_upper's: the second way up to the gutter. (Split from wall_west at y 0, as house_wall and wall_upper are: one region
--                     from the lawn to the eaves would not be whole inside the streaming target radius from its foot.)
--   shrub_west_a..j . the bushes beside the bed (box and privet, 44 to 54 studs tall), on a mat of deep leaf litter whose top is the bed's soil's (y -90), from the
--                     bed's west edge and the house's wall out to x -500 and z -200, in ten chunks of 95 by 88, five columns westward each split at z -112 (each chunk
--                     whole inside the target radius from anywhere on it, and well under the 60 boxes a graph may carry). Each has two bushes whose twigs are walkable
--                     boxes and a retreat under the first: the gap under a curled dead leaf lying on two twigs in the litter. The garden's pace (0.33). The view's
--                     drawn bushes that stood in the strip moved out of it (Data/Flora).
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)

local WorldMap = {}

export type Retreat = { id: string, min: Vector3, max: Vector3, door: Vector3? } -- `door` (ROBLOX-96): the point outside its way in that the words near home are measured from
export type Spawn = { pos: Vector3, heading: Vector3 }
export type Neighbor = { id: string, a: Vector3, b: Vector3 }
export type Region = {
	id: string,
	kind: string,
	origin: Vector3,
	bounds: { Vector3 }, -- { min, max }
	seed: number,
	neighbors: { Neighbor },
	retreats: { Retreat },
	spawn: Spawn,
	clockScale: number,
}

-- The world's seed when nothing says otherwise: the same 914 the prey, the wasp and the rival draw from.
WorldMap.SEED = 914
-- Changes whenever any region's geometry moves in a way a saved position could no longer be trusted (Checkpoint's revision gate puts such a
-- rest back at its region's spawn). Adding a region somewhere new does not need it; moving, resizing or removing one does.
-- world-2 (ROBLOX-95): the sill's back frame was opened and the garden added, so a rest kept under world-1 (or before there was a record of the world) is put
-- back at its region's spawn.
WorldMap.REVISION = "world-2"
-- The revision a rest kept before there was a world record belongs to (Persistence/Checkpoint reads a record without one as this).
WorldMap.FIRST_REVISION = "world-1"
-- The region a new life begins in.
WorldMap.HOME = "sill"

local MOD = 2147483647 -- 2^31 - 1: the modulus of the placers' own streams (Shapes.rng, PreyRandom), so a region's seed is a good start for either

-- A region's seed from the world's seed and its id: stable forever (it decides every placer of the region), spread so neighbouring world seeds
-- and similar ids start unrelated streams, and in 1 .. 2^31 - 2. Every product stays below 2^53, so it is exact on every machine.
function WorldMap.seed(worldSeed: number, regionId: string): number
	assert(worldSeed == worldSeed and math.abs(worldSeed) ~= math.huge, "the world's seed is not a number")
	local h = math.floor(worldSeed) % MOD
	for i = 1, #regionId do
		h = (h * 16807 + string.byte(regionId, i) * 7919 + 1) % MOD
	end
	if h == 0 then h = 1 end
	for _ = 1, 3 do
		h = (h * 48271) % MOD
	end
	return h
end

local function freeze(region: Region): Region
	table.freeze(region.bounds)
	table.freeze(region.neighbors)
	for _, r in region.retreats do table.freeze(r) end
	table.freeze(region.retreats)
	table.freeze(region.spawn)
	return table.freeze(region)
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- The seams, each the line where two regions' walkable surfaces meet (both regions list it, `a` to `b`).
local SEAM_SASH = { a = v(-8, 0, -13.5), b = v(8, 0, -13.5) } -- the rail's outer face meets the stone
local SEAM_STONE = { a = v(-30, -3, -24), b = v(30, -3, -24) } -- the stone's front face goes on down as brick
local SEAM_FOOT = { a = v(-25, -90, -24), b = v(25, -90, -24) } -- the wall's foot meets the soil
local SEAM_JAMB = { a = v(31, 0, -24), b = v(40, 0, -24) } -- (ROBLOX-103) the east shoulder's face goes on up as the east jamb's
-- (ROBLOX-107) the back wall west of the window and the bushes beside the bed
local SEAM_WEST = { a = v(-40, -90, -24), b = v(-40, 0, -24) } -- the house_wall's brick goes on west as wall_west's
local SEAM_WEST_UP = { a = v(-40, 0, -24), b = v(-40, 60, -24) } -- the wall above the window's brick (and its west jamb) goes on west as wall_west_upper's. (Only to
-- y 60: the faces meet all the way to the eaves, but a line 110 long cannot have its far end's boxes inside the radius always sent from its near end; above y 60 the
-- rest of wall_upper is inside the target radius, tests/worldmap.luau's streaming case)
local SEAM_WEST_RISE = { a = v(-120, 0, -24), b = v(-40, 0, -24) } -- wall_west's brick goes on up as wall_west_upper's
local SEAM_WEST_FOOT = { a = v(-120, -90, -24), b = v(-40, -90, -24) } -- wall_west's foot meets the litter
local SEAM_HOUSE_LITTER = { a = v(-40, -90, -24), b = v(-25, -90, -24) } -- the house_wall's foot west of the bed meets the litter
local SEAM_BED_LITTER = { a = v(-25, -90, -24), b = v(-25, -90, -74) } -- the bed's west edge meets the litter, flat
local function seam(id: string, line: { a: Vector3, b: Vector3 }): Neighbor
	return table.freeze({ id = id, a = line.a, b = line.b })
end

-- (ROBLOX-107) The bushes' chunks: the strip beside the bed from x -25 to -500 and z -24 to -200 on the litter (top y -90), five columns of 95 studs from the bed
-- westward, each split at z -112 into a chunk by the house (north, toward it) and one by the lawn: `a` and `b` the first column's, `c` and `d` the next, to `i` and `j`.
-- Each chunk's retreat (the gap under a curled dead leaf, `rx`, `rz` its middle) lies under its first bush, toward one corner so the second bush has room in the
-- other (by the house: 27 studs in from its west side; by the lawn: 27 in from its east side; in alternate columns nearer or farther from the house).
-- World/Garden builds the leaf and the bushes round it.
local SHRUB_W, SHRUB_SPLIT = 95, -112
local SHRUB_IDS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
local chunks = {}
for col = 0, 4 do
	local x1 = -25 - SHRUB_W * col
	local x0 = x1 - SHRUB_W
	local odd = col % 2 == 1
	table.insert(chunks, table.freeze({ id = "shrub_west_" .. SHRUB_IDS[col * 2 + 1], col = col, row = 0, x0 = x0, x1 = x1, z0 = SHRUB_SPLIT, z1 = -24,
		rx = x0 + 27, rz = if odd then -55 else -86 }))
	table.insert(chunks, table.freeze({ id = "shrub_west_" .. SHRUB_IDS[col * 2 + 2], col = col, row = 1, x0 = x0, x1 = x1, z0 = -200, z1 = SHRUB_SPLIT,
		rx = x1 - 27, rz = if odd then -173 else -140 }))
end
WorldMap.SHRUB_CHUNKS = table.freeze(chunks)
WorldMap.LITTER_TOP = -90 -- the litter's top under the bushes, the bed's soil's
-- A chunk's seams: to the chunk across the split (the litter flat along z -112) and to those either side (flat along its west or east edge); the first column's
-- by the house also meets the bed's west edge, the house_wall's foot west of the bed and wall_west's foot.
local function shrubSeams(c: any): { Neighbor }
	local top = WorldMap.LITTER_TOP
	local out: { Neighbor } = {}
	if c.col == 0 and c.row == 0 then
		table.insert(out, seam("bed_a", SEAM_BED_LITTER))
		table.insert(out, seam("house_wall", SEAM_HOUSE_LITTER))
		table.insert(out, seam("wall_west", SEAM_WEST_FOOT))
	end
	for _, o in WorldMap.SHRUB_CHUNKS do
		if o.col == c.col and o.row ~= c.row then
			table.insert(out, seam(o.id, { a = v(c.x0, top, SHRUB_SPLIT), b = v(c.x1, top, SHRUB_SPLIT) }))
		elseif o.row == c.row and math.abs(o.col - c.col) == 1 then
			local x = if o.col > c.col then c.x0 else c.x1
			table.insert(out, seam(o.id, { a = v(x, top, c.z0), b = v(x, top, c.z1) }))
		end
	end
	return out
end
local function shrubChunk(worldSeed: number, c: any): Region
	local top = WorldMap.LITTER_TOP
	local neighbors = shrubSeams(c)
	-- the gap under the dead leaf: as the bed's stone's, 4.8 by 1.4 by 5.2, its mouth toward the house
	local min, max = v(c.rx - 2.4, top, c.rz - 2.6), v(c.rx + 2.4, top + 1.4, c.rz + 2.6)
	return freeze({
		id = c.id, kind = "shrub", origin = v((c.x0 + c.x1) / 2, top, (c.z0 + c.z1) / 2),
		bounds = { v(c.x0, -93, c.z0), v(c.x1, -10, c.z1) },
		seed = WorldMap.seed(worldSeed, c.id),
		neighbors = neighbors,
		retreats = { { id = c.id .. "_litter", min = min, max = max, door = v(c.rx, top + 0.5, max.Z + 0.9) } },
		spawn = { pos = v(c.rx, top, max.Z + 3.9), heading = v(0, 0, -1) }, -- in front of the leaf, facing its way in
		clockScale = 0.33,
	})
end

-- The authored regions, for a world seed (only each region's `seed` depends on it), in priority order.
local function author(worldSeed: number): { Region }
	local C = WorldMap.SHRUB_CHUNKS
	local list: { Region } = {
		freeze({
			id = "sill", kind = "sill", origin = Vector3.zero,
			bounds = { Layout.PLAY_BOUNDS_MIN, Layout.PLAY_BOUNDS_MAX },
			seed = WorldMap.seed(worldSeed, "sill"),
			neighbors = { seam("outer_sill", SEAM_SASH) },
			retreats = { { id = "sill_crevice", min = Layout.RETREAT_MIN, max = Layout.RETREAT_MAX, door = v(-24, 1, 6) } }, -- (the door: where the client has always measured "near home" from)
			spawn = { pos = Layout.SPAWN, heading = Layout.SPAWN_HEADING },
			clockScale = 1.0,
		}),
		freeze({
			id = "outer_sill", kind = "outer_sill", origin = v(0, 0, -18.75),
			bounds = { v(-33, -3, -25.5), v(33, 35, -13.5) },
			seed = WorldMap.seed(worldSeed, "outer_sill"),
			neighbors = { seam("sill", SEAM_SASH), seam("house_wall", SEAM_STONE) },
			retreats = {},
			spawn = { pos = v(0, 0, -18), heading = v(0, 0, -1) }, -- just outside the opening, facing the garden
			clockScale = 1.0,
		}),
		freeze({
			id = "house_wall", kind = "house_wall", origin = v(0, -45, -24),
			bounds = { v(-42, -89, -30), v(42, 35, -13.5) },
			seed = WorldMap.seed(worldSeed, "house_wall"),
			neighbors = { seam("outer_sill", SEAM_STONE), seam("bed_a", SEAM_FOOT), seam("wall_upper", SEAM_JAMB), seam("wall_west", SEAM_WEST), seam("shrub_west_a", SEAM_HOUSE_LITTER) },
			retreats = {},
			-- on the face of the east shoulder, heading up (ROBLOX-103: it was the shoulder's top, x 35, y 0, z -18.75, where the window's east jamb stands now)
			spawn = { pos = v(35, -1.5, -24), heading = v(0, 1, 0) },
			clockScale = 1.0,
		}),
		freeze({
			id = "bed_a", kind = "bed", origin = v(0, -90, -49),
			bounds = { v(-42, -93, -76), v(42, 35, -24) },
			seed = WorldMap.seed(worldSeed, "bed_a"),
			neighbors = { seam("house_wall", SEAM_FOOT), seam("shrub_west_a", SEAM_BED_LITTER) },
			-- the gap under the stone, raised on two rests (World/Garden builds the stone round it): the first garden home
			retreats = { { id = "bed_a_stone", min = v(8.6, -90, -52.6), max = v(13.4, -88.6, -47.4), door = v(11, -89.5, -46.5) } }, -- (the door: in front of the gap's mouth)
			spawn = { pos = v(11, -90, -43.5), heading = v(0, 0, -1) }, -- in front of the stone, facing its way in
			clockScale = 0.33,
		}),
		freeze({
			id = "wall_upper", kind = "wall_upper", origin = v(0, 60, -24),
			bounds = { v(-42, 0, -70), v(42, 130, -13.5) },
			seed = WorldMap.seed(worldSeed, "wall_upper"),
			neighbors = { seam("house_wall", SEAM_JAMB), seam("wall_west_upper", SEAM_WEST_UP) },
			retreats = {},
			spawn = { pos = v(0, 109, -61), heading = v(1, 0, 0) }, -- on the gutter's floor, along it
			clockScale = 1.0,
		}),
		freeze({
			id = "wall_west", kind = "wall_west", origin = v(-80, -45, -24),
			bounds = { v(-122, -89, -34), v(-40, 0, -13.5) }, -- its face and the drainpipe's foot, ten studs of air in front, down to y -89 (standing on the litter is the bushes')
			seed = WorldMap.seed(worldSeed, "wall_west"),
			neighbors = { seam("house_wall", SEAM_WEST), seam("wall_west_upper", SEAM_WEST_RISE), seam("shrub_west_a", SEAM_WEST_FOOT) },
			retreats = {},
			spawn = { pos = v(-80, -45, -24), heading = v(0, 1, 0) }, -- on the brick, heading up
			clockScale = 1.0,
		}),
		freeze({
			id = "wall_west_upper", kind = "wall_west_upper", origin = v(-80, 60, -24),
			bounds = { v(-122, 0, -70), v(-40, 130, -13.5) },
			seed = WorldMap.seed(worldSeed, "wall_west_upper"),
			neighbors = { seam("wall_upper", SEAM_WEST_UP), seam("wall_west", SEAM_WEST_RISE) },
			retreats = {},
			spawn = { pos = v(-80, 109, -61), heading = v(-1, 0, 0) }, -- on its gutter's floor, along it
			clockScale = 1.0,
		}),
	}
	for _, c in C do table.insert(list, shrubChunk(worldSeed, c)) end
	return list
end

local DEFAULT: { Region } = table.freeze(author(WorldMap.SEED))
local BY_ID: { [string]: Region } = {}
for _, r in DEFAULT do BY_ID[r.id] = r end

-- Whether the point is in the box, edges included (Godot's windowsill.gd in_retreat, which every box of the world keeps).
local function within(lo: Vector3, hi: Vector3, p: Vector3): boolean
	return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
end

-- The union box of some regions' bounds (their smallest common axis-aligned box), as `min, max`.
function WorldMap.unionOf(regions: { Region }): (Vector3, Vector3)
	local lo, hi = regions[1].bounds[1], regions[1].bounds[2]
	for i = 2, #regions do
		local a, b = regions[i].bounds[1], regions[i].bounds[2]
		lo = Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z))
		hi = Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z))
	end
	return lo, hi
end

local UNION_MIN, UNION_MAX = WorldMap.unionOf(DEFAULT)

-- Every region, in priority order, for a world seed (the default one: the shared, frozen list; do not rely on its identity). Nothing in a
-- region but its `seed` depends on the world's seed.
function WorldMap.regions(worldSeed: number?): { Region }
	if worldSeed == nil or worldSeed == WorldMap.SEED then return DEFAULT end
	return table.freeze(author(worldSeed))
end

-- The region with this id, or nil.
function WorldMap.region(id: string, worldSeed: number?): Region?
	if worldSeed == nil or worldSeed == WorldMap.SEED then return BY_ID[id] end
	for _, r in WorldMap.regions(worldSeed) do
		if r.id == id then return r end
	end
	return nil
end

-- The region whose bounds hold the point (the first listed), or nil outside every region.
function WorldMap.at(pos: Vector3): Region?
	for _, r in DEFAULT do
		if within(r.bounds[1], r.bounds[2], pos) then return r end
	end
	return nil
end

-- Whether the point is inside the bounds of the region (when an id is given) or of any region.
function WorldMap.inBounds(pos: Vector3, regionId: string?): boolean
	if regionId ~= nil then
		local r = BY_ID[regionId]
		return r ~= nil and within(r.bounds[1], r.bounds[2], pos)
	end
	return WorldMap.at(pos) ~= nil
end

-- The union box of every region: the motor's fall-off box, `min, max`.
function WorldMap.bounds(): (Vector3, Vector3)
	return UNION_MIN, UNION_MAX
end

-- The id of the retreat the point is inside (edges included) in the region (when an id is given) or in any region, or nil.
function WorldMap.inRetreat(pos: Vector3, regionId: string?): string?
	if regionId ~= nil then
		local r = BY_ID[regionId]
		if r ~= nil then
			for _, t in r.retreats do
				if within(t.min, t.max, pos) then return t.id end
			end
		end
		return nil
	end
	for _, r in DEFAULT do
		for _, t in r.retreats do
			if within(t.min, t.max, pos) then return t.id end
		end
	end
	return nil
end

-- The retreat with this id (in any region), or nil.
function WorldMap.retreat(id: string): Retreat?
	for _, r in DEFAULT do
		for _, t in r.retreats do
			if t.id == id then return t end
		end
	end
	return nil
end

return table.freeze(WorldMap)
