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

-- The house's shell, drawn far wherever the spider is: per kind, the ids of the records its far look keeps (the big ones a distant eye reads), in order.
-- The mortar beds behind the bricks (`Mortar`, the house_wall's `Above` beds round the window) are drawn in the first brick colour and the bricks' material,
-- as the drawn house beyond the walkable walls always is (`HouseWest`, `HouseEast`): from far off, a wall of brick.
LookPlan.FAR = table.freeze({
	house_wall = table.freeze({ "Mortar", "Above1", "Above2", "Above3" }),
	wall_upper = table.freeze({ "Mortar", "Soffit", "Fascia", "RoofSlope", "HouseWest", "HouseEast", "EavesWest", "EavesEast" }),
	wall_west = table.freeze({ "Mortar", "Pipe" }),
	wall_west_upper = table.freeze({ "Mortar", "Soffit", "Pipe", "Neck" }), -- (the drainpipe's boxes are hidden under its drawing: far off it is drawn too)
})
local AS_BRICK: { [string]: boolean } = { Mortar = true, Above1 = true, Above2 = true, Above3 = true }

local recordsCache: { [string]: { Garden.Drawn } } = {}

-- The drawn records of a region's look at a level (the same list for the same region and level; do not change it).
function LookPlan.records(region: WorldMap.Region, level: Level): { Garden.Drawn }
	local key = region.id .. "/" .. tostring(region.seed) .. "/" .. level
	local cached = recordsCache[key]
	if cached ~= nil then return cached end
	local all = Region.decor(region)
	local out: { Garden.Drawn } = {}
	if level == "full" then
		out = all
	elseif level == "low" then
		for _, d in all do if not d.full then table.insert(out, d) end end
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
function LookPlan.count(region: WorldMap.Region, level: Level?): number
	if level == nil then return 0 end
	return #LookPlan.records(region, level)
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
	local own: WorldMap.Region = m.at(pos) or here or (m.region(m.HOME) :: WorldMap.Region)
	local plan: Plan = {}
	local total = 0
	local function has(region: WorldMap.Region): boolean
		return Garden.knows(region.kind)
	end
	local function set(region: WorldMap.Region, level: Level?)
		total += LookPlan.count(region, level) - LookPlan.count(region, plan[region.id])
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
	-- 2. the house's shell, far, wherever it is not drawn already
	for _, r in regions do
		if plan[r.id] == nil and LookPlan.FAR[r.kind] ~= nil then set(r, "far") end
	end
	-- 3. the others, nearest first, within the radius, as the budget allows
	local others: { { region: WorldMap.Region, d: number, i: number } } = {}
	for i, r in regions do
		if has(r) and not required[r.id] then
			local d = LookPlan.distance(r, pos)
			local kept = held ~= nil and held[r.id] ~= nil and held[r.id] ~= "far"
			if d <= radius or (kept and d <= radius + LookPlan.KEEP) then
				table.insert(others, { region = r, d = if kept then d - LookPlan.KEEP else d, i = i })
			end
		end
	end
	table.sort(others, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		return a.i < b.i
	end)
	for _, o in others do
		local r = o.region
		local now = LookPlan.count(r, plan[r.id])
		if total - now + LookPlan.count(r, top) <= budget then
			set(r, top)
		elseif top == "full" and total - now + LookPlan.count(r, "low") <= budget and now < LookPlan.count(r, "low") then
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
