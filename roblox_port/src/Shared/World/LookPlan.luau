--!strict
-- Which regions' drawn looks a client holds, and at what detail, from where the spider is (ROBLOX-108). Pure: a plan is a function of the place, the tier, the
-- region the spider was last in and what the client already holds (for the hysteresis), so the CLI tests ask exactly what a client asks. Client/LookStream
-- builds and destroys the looks to follow the plan; the looks themselves are the regions' own seeded generators (Region.decor), so a look built on a client
-- is part for part the one the server used to build and replicate.
--
-- Until ROBLOX-107 every region's look was a persistent model, on every client wherever the spider was: 3,647 parts outside the window at the full tier, 1,215 at
-- the low. Now a client holds at most BUDGET parts of looks at once (the sill's Decor, the home, is not counted: it is the server's and stays persistent):
--   1. the region the spider is in and every region it meets (its seams) at the tier's detail, always: no look pops in where the spider can step or look closely;
--   2. the house's shell (the brick walls, the roof and the eaves: FAR) at its far detail wherever the spider is, a handful of big parts, so the house never has a
--      hole in it seen from the far end of the garden (a wall's drawn bricks stand in for its boxes, which are invisible);
--   3. then the other regions, nearest first, within RADIUS of the spider, each at the tier's detail if it fits the budget, else (at the full tier) the low
--      detail if that fits, else as it is (far, or nothing). A region already held is reckoned KEEP studs nearer and RADIUS + KEEP away still counts, so a
--      spider walking along the edge of a radius does not build and destroy the same look over and over.
-- Levels: "full" (every record), "low" (the records without `full`, the low tier's look) and "far" (FAR's records, the walls' mortar beds drawn as brick).
-- A region with no look (the sill) is never in a plan. At the low tier there is no "full".
-- ROBLOX-115 (the preserve, World/Preserve and World/PreserveLook): the active world's drawn zones (WorldMap.drawn: the backdrop, none in the test garden) are
-- planned with the regions. Each is held far wherever the spider is (step 2, as the house's shell: its `far` records, the cheap masses, without the full tier's own
-- at the low tier), and within RADIUS at the tier's detail (step 3) as the budget allows. So a client holds the far preserve as masses and what is near whole.
local WorldMap = require(script.Parent.WorldMap)
local Region = require(script.Parent.Region)
local Garden = require(script.Parent.Garden)

local LookPlan = {}

export type Level = string -- "full" | "low" | "far"
export type Plan = { [string]: Level }

-- The most look parts outside the window a client holds at once, by tier (Data/Detail's "full" and "low").
LookPlan.BUDGET = table.freeze({ full = 1500, low = 500 })
-- How far (studs, from the spider to a region's bounds) an optional region is drawn, by tier.
LookPlan.RADIUS = table.freeze({ full = 260, low = 160 })
-- The hysteresis: a region already held is reckoned this many studs nearer, and is kept out to RADIUS + KEEP.
LookPlan.KEEP = 30
-- (ROBLOX-117) The patches (the preserve's near detail of the ground: World/Hut.patches, WorldMap.patches) are drawn only this near the spider (studs, from the
-- spider to a patch's bounds), by tier, nearest first right after what must be drawn and the far looks (step 2b below), at the tier's detail as the budget allows;
-- and at the full tier, out to PATCH_RING, at the low tier's detail (a few blades and stones); a patch already held is kept PATCH_KEEP further. So the blades,
-- chips and stones stand thick where the eye is, thin a little further off, and nowhere else.
LookPlan.PATCH_RADIUS = table.freeze({ full = 22, low = 20 })
LookPlan.PATCH_RING = 42
LookPlan.PATCH_KEEP = 8
-- (ROBLOX-117) The most parts of patches a plan holds, by tier: the rest of the budget is the garden's cells and the backdrop's (step 3).
LookPlan.PATCH_SHARE = table.freeze({ full = 700, low = 100 })

-- The house's shell, drawn far wherever the spider is: per kind, the ids of the records its far look keeps (the big ones a distant eye reads), in order.
-- The mortar beds behind the bricks (`Mortar`, the house_wall's `Above` beds round the window) are drawn in the first brick colour and the bricks' material,
-- as the drawn house beyond the walkable walls always is (`HouseWest`, `HouseEast`): from far off, a wall of brick.
LookPlan.FAR = table.freeze({
	house_wall = table.freeze({ "Mortar", "Above1", "Above2" }),
	-- (ROBLOX-112: the window's jambs; the eaves carry what wall_upper's look did above the head, the house round it among them)
	wall_upper = table.freeze({ "Jamb1", "Jamb2" }),
	-- (the room beyond the window, its ceiling and far wall, so the window does not show the sky through the house from afar; its floor is not seen from the garden)
	eaves = table.freeze({ "Mortar", "Soffit", "Fascia", "RoofSlope", "HouseWest", "HouseEast", "EavesWest", "EavesEast", "RoomCeiling", "RoomFar" }),
	wall_west = table.freeze({ "Mortar", "Pipe" }),
	wall_west_upper = table.freeze({ "Mortar", "Pipe" }), -- (the drainpipe's boxes are hidden under its drawing: far off it is drawn too)
	eaves_west = table.freeze({ "Mortar", "Soffit", "Pipe", "Neck" }),
})
local AS_BRICK: { [string]: boolean } = { Mortar = true, Above1 = true, Above2 = true, Jamb1 = true, Jamb2 = true }

local recordsCache: { [string]: { Garden.Drawn } } = {}

-- The drawn records of a region's look at a level (the same list for the same region and level; do not change it). `tier` ("full" or "low") matters only to a
-- backdrop zone's far look (ROBLOX-115), whose full-tier records the low tier leaves out.
function LookPlan.records(region: WorldMap.Region, level: Level, tier: string?): { Garden.Drawn }
	local backdrop = region.kind == "backdrop"
	local key = region.id .. "/" .. tostring(region.seed) .. "/" .. level .. (if backdrop and level == "far" and tier == "low" then "/low" else "")
	local cached = recordsCache[key]
	if cached ~= nil then return cached end
	-- All detail levels are read-only views of one seeded decoration list.
	-- Generating again for low/far wastes CPU and keeps duplicate record tables.
	local fullKey = region.id .. "/" .. tostring(region.seed) .. "/full"
	local all = recordsCache[fullKey]
	if all == nil and tier == "low" and level ~= "full" then
		-- The phone tier retains only its base records. Far low views use those
		-- same records; full detail is generated later only if actually requested.
		local lowKey = region.id .. "/" .. tostring(region.seed) .. "/low"
		all = recordsCache[lowKey]
		if all == nil then
			all = {}
			for _, d in Region.decor(region) do if not d.full then table.insert(all, d) end end
			recordsCache[lowKey] = all
		end
	elseif all == nil then
		all = Region.decor(region); recordsCache[fullKey] = all
	end
	local out: { Garden.Drawn } = {}
	if level == "full" then
		out = all
	elseif level == "low" then
		for _, d in all do if not d.full then table.insert(out, d) end end
	elseif level == "far" and backdrop then
		for _, d in all do if d.far and not (tier == "low" and d.full) then table.insert(out, d) end end
	elseif level == "far" then
		local keep = LookPlan.FAR[region.kind]
		if keep ~= nil then
			local brick = Color3.fromHex(Garden.WALL.bricks[1])
			for _, id in keep do
				for _, d in all do
					if d.id == id and not d.full then
						if AS_BRICK[id] then
							local c = table.clone(d)
							c.color, c.material = brick, Garden.WALL.brickMaterial
							table.insert(out, c)
						else
							table.insert(out, d)
						end
						break
					end
				end
			end
		end
	else
		error("no look level " .. level)
	end
	recordsCache[key] = out
	return out
end

-- How many parts a region's look is at a level (0 for none).
function LookPlan.count(region: WorldMap.Region, level: Level?, tier: string?): number
	if level == nil then return 0 end
	return #LookPlan.records(region, level, tier)
end

-- Whether a region (or a drawn zone) has a look the plan streams.
local function streamed(region: WorldMap.Region): boolean
	return Region.streamed(region.kind)
end

-- The active world's drawn zones from a map (none from a map that has no `drawn`, as the tests' stand-ins).
local function drawnOf(m: any): { WorldMap.Region }
	if m.drawn == nil then return {} end
	return m.drawn()
end

-- The active world's patches from a map (none from a map that has no `patches`).
local function patchesOf(m: any): { WorldMap.Region }
	if m.patches == nil then return {} end
	return m.patches()
end

-- A region, a drawn zone or (ROBLOX-117) a patch by id, from a map.
function LookPlan.lookup(m: any, id: string): WorldMap.Region?
	local r = m.region(id)
	if r == nil and m.drawnZone ~= nil then r = m.drawnZone(id) end
	if r == nil and m.patch ~= nil then r = m.patch(id) end
	return r
end

-- The distance from a point to a region's bounds (0 inside them).
function LookPlan.distance(region: WorldMap.Region, pos: Vector3): number
	local lo, hi = region.bounds[1], region.bounds[2]
	local dx = math.max(lo.X - pos.X, 0, pos.X - hi.X)
	local dy = math.max(lo.Y - pos.Y, 0, pos.Y - hi.Y)
	local dz = math.max(lo.Z - pos.Z, 0, pos.Z - hi.Z)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The plan at a place, for a tier ("full" or "low"): `here`, the region the spider was last in (where the place is in none); `held`, what the client holds now
-- (for the hysteresis). Returns the plan and its parts. `map`: WorldMap unless a test hands in another with the same functions.
function LookPlan.plan(pos: Vector3, tier: string, here: WorldMap.Region?, held: Plan?, map: any?): (Plan, number)
	local m: any = map or WorldMap
	local top: Level = if tier == "low" then "low" else "full"
	local budget = if tier == "low" then LookPlan.BUDGET.low else LookPlan.BUDGET.full
	local radius = if tier == "low" then LookPlan.RADIUS.low else LookPlan.RADIUS.full
	local regions: { WorldMap.Region } = m.regions()
	local zones = drawnOf(m)
	local own: WorldMap.Region = m.at(pos) or here or (m.region(m.HOME) :: WorldMap.Region)
	local plan: Plan = {}
	local total = 0
	local function has(region: WorldMap.Region): boolean
		return streamed(region)
	end
	local function count(region: WorldMap.Region, level: Level?): number
		return LookPlan.count(region, level, tier)
	end
	local function set(region: WorldMap.Region, level: Level?)
		total += count(region, level) - count(region, plan[region.id])
		plan[region.id] = level :: any
	end
	-- 1. the region the spider is in and the regions it meets, at the tier's detail
	local required: { [string]: boolean } = {}
	local near: { WorldMap.Region } = {}
	if has(own) then table.insert(near, own) end
	for _, n in own.neighbors do
		local r = m.region(n.id)
		if r ~= nil and has(r) and not required[r.id] then table.insert(near, r) end
		if r ~= nil then required[r.id] = true end
	end
	required[own.id] = true
	for _, r in near do set(r, top) end
	-- (never expected: if the region and its neighbours at the full tier's detail overrun the budget, the neighbours farthest away are drawn low)
	if total > budget and top == "full" then
		local order = table.clone(near)
		table.sort(order, function(a, b) return LookPlan.distance(a, pos) > LookPlan.distance(b, pos) end)
		for _, r in order do
			if total <= budget then break end
			if r ~= own then set(r, "low") end
		end
	end
	-- 2. the house's shell, far, wherever it is not drawn already, and (ROBLOX-115) every zone of the backdrop as its masses
	for _, r in regions do
		if plan[r.id] == nil and LookPlan.FAR[r.kind] ~= nil then set(r, "far") end
	end
	for _, r in zones do
		if plan[r.id] == nil then set(r, "far") end
	end
	-- 2b. (ROBLOX-117) the patches near the spider, nearest first, at the tier's detail as the budget allows
	local patches = patchesOf(m)
	if #patches > 0 then
		local pr = if tier == "low" then LookPlan.PATCH_RADIUS.low else LookPlan.PATCH_RADIUS.full
		local ring = if tier == "low" then pr else LookPlan.PATCH_RING
		local close: { { region: WorldMap.Region, d: number, i: number, level: Level } } = {}
		for i, r in patches do
			local d = LookPlan.distance(r, pos)
			local was = if held ~= nil then held[r.id] else nil
			local level: Level? = nil
			if d <= pr or (was == top and d <= pr + LookPlan.PATCH_KEEP) then level = top
			elseif d <= ring or (was ~= nil and d <= ring + LookPlan.PATCH_KEEP) then level = "low" end
			if level ~= nil then table.insert(close, { region = r, d = if was ~= nil then d - LookPlan.PATCH_KEEP else d, i = i, level = level :: Level }) end
		end
		table.sort(close, function(a, b)
			if a.d ~= b.d then return a.d < b.d end
			return a.i < b.i
		end)
		local share = if tier == "low" then LookPlan.PATCH_SHARE.low else LookPlan.PATCH_SHARE.full
		local used = 0
		for _, o in close do
			local c = count(o.region, o.level)
			if used + c <= share and total + c <= budget then
				set(o.region, o.level)
				used += c
			end
		end
	end
	-- 3. the others, nearest first, within the radius, as the budget allows
	local others: { { region: WorldMap.Region, d: number, i: number } } = {}
	local function consider(r: WorldMap.Region, i: number)
		if has(r) and not required[r.id] then
			local d = LookPlan.distance(r, pos)
			local kept = held ~= nil and held[r.id] ~= nil and held[r.id] ~= "far"
			if d <= radius or (kept and d <= radius + LookPlan.KEEP) then
				table.insert(others, { region = r, d = if kept then d - LookPlan.KEEP else d, i = i })
			end
		end
	end
	for i, r in regions do consider(r, i) end
	for i, r in zones do consider(r, #regions + i) end
	-- (ROBLOX-117: the walkable regions before the backdrop's zones, each nearest first: in the preserve's garden its cells' plants come before the zone round it.
	-- A map with no zones, the test garden's, is ordered as it always was)
	local nRegions = #regions
	table.sort(others, function(a, b)
		local ra = if a.region.kind == "verge" then 2 elseif a.i > nRegions then 1 else 0
		local rb = if b.region.kind == "verge" then 2 elseif b.i > nRegions then 1 else 0
		if ra ~= rb then return ra < rb end
		if a.d ~= b.d then return a.d < b.d end
		return a.i < b.i
	end)
	for _, o in others do
		local r = o.region
		local now = count(r, plan[r.id])
		if total - now + count(r, top) <= budget then
			set(r, top)
		elseif top == "full" and total - now + count(r, "low") <= budget and now < count(r, "low") then
			set(r, "low")
		end
	end
	return plan, total
end

-- The ids of the regions that must be drawn at a place (the one it is in and the ones it meets), for the tests and the client's order of work.
function LookPlan.required(pos: Vector3, here: WorldMap.Region?, map: any?): { [string]: boolean }
	local m: any = map or WorldMap
	local own: WorldMap.Region = m.at(pos) or here or (m.region(m.HOME) :: WorldMap.Region)
	local out: { [string]: boolean } = { [own.id] = true }
	for _, n in own.neighbors do out[n.id] = true end
	return out
end

return table.freeze(LookPlan)
