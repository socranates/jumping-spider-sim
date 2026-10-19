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
local function seam(id: string, line: { a: Vector3, b: Vector3 }): Neighbor
	return table.freeze({ id = id, a = line.a, b = line.b })
end

-- The authored regions, for a world seed (only each region's `seed` depends on it), in priority order.
local function author(worldSeed: number): { Region }
	return {
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
			neighbors = { seam("outer_sill", SEAM_STONE), seam("bed_a", SEAM_FOOT) },
			retreats = {},
			spawn = { pos = v(35, 0, -18.75), heading = v(-1, 0, 0) }, -- the top of the wall's east shoulder, beside the outer sill
			clockScale = 1.0,
		}),
		freeze({
			id = "bed_a", kind = "bed", origin = v(0, -90, -49),
			bounds = { v(-42, -93, -76), v(42, 35, -24) },
			seed = WorldMap.seed(worldSeed, "bed_a"),
			neighbors = { seam("house_wall", SEAM_FOOT) },
			-- the gap under the stone, raised on two rests (World/Garden builds the stone round it): the first garden home
			retreats = { { id = "bed_a_stone", min = v(8.6, -90, -52.6), max = v(13.4, -88.6, -47.4), door = v(11, -89.5, -46.5) } }, -- (the door: in front of the gap's mouth)
			spawn = { pos = v(11, -90, -43.5), heading = v(0, 0, -1) }, -- in front of the stone, facing its way in
			clockScale = 0.33,
		}),
	}
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
