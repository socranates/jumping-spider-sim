--!strict
-- The map of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): what regions there are, where each one is, where a life begins in it, where
-- it can rest, and how fast its day runs. Pure data and pure questions about a point; nothing here builds a part or knows the engine, so the
-- server, the client and the CLI tests all ask the same thing. The sill is region 0 of one continuous garden: its numbers are the windowsill's
-- own (Habitat/WindowsillLayout, which stays the sill's data), and everything that used to read them from the layout asks here.
--
-- A region: `id`; `kind` (what generates its boxes: Region.pieces/Region.decor); `origin` (world studs; the sill is at the origin exactly as
-- it always was); `bounds` ({ min, max }, the volume a spider may be in while it is in this region: the motor's fall-off box, a checkpoint's
-- check); `seed` (the world's seed mixed with the region's id, for the region's placers: WorldMap.seed); `neighbors` (the seams to the regions
-- it meets: none yet; each will carry the face line, `a` to `b`, where the two walkable surfaces meet); `retreats` (box volumes where the
-- spider can rest, edges included: the sill's crack); `spawn` (the support point and heading where a life begins here, and where a rest
-- from another revision of the world is put back); `clockScale` (how fast this region's day runs against the sill's, 1.0: LifeClock.game).
--
-- Regions are listed in priority order; bounds may touch at a seam, and a point on a shared edge belongs to the first region listed.
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)

local WorldMap = {}

export type Retreat = { id: string, min: Vector3, max: Vector3 }
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
WorldMap.REVISION = "world-1"
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

-- The authored regions, for a world seed (only each region's `seed` depends on it). One for now.
local function author(worldSeed: number): { Region }
	return {
		freeze({
			id = "sill", kind = "sill", origin = Vector3.zero,
			bounds = { Layout.PLAY_BOUNDS_MIN, Layout.PLAY_BOUNDS_MAX },
			seed = WorldMap.seed(worldSeed, "sill"),
			neighbors = {} :: { Neighbor },
			retreats = { { id = "sill_crevice", min = Layout.RETREAT_MIN, max = Layout.RETREAT_MAX } },
			spawn = { pos = Layout.SPAWN, heading = Layout.SPAWN_HEADING },
			clockScale = 1.0,
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
