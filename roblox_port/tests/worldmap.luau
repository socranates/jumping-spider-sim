-- The world map (ROBLOX-94): the regions, the questions about a point, the seed of a region, and the sill's generator. Pure: no engine, no shim beyond Vector3.
-- The sill is region 0 of a world and is what it was before there was one: its bounds, retreat, spawn and boxes are the layout's own, every question a point
-- inside it could be asked of the layout gets the same answer from the map, and the region lists a generator returns are byte-for-byte the layout's.
-- ROBLOX-95 (W2): three regions outside the window (outer_sill, house_wall, bed_a) with their seams, the priority where their bounds meet, the union, the bed's
-- retreat, the garden's generators (deterministic from the seed, inside their regions, nothing overlapping, the stone round its retreat) and the streaming radius
-- as the focus follows the spider.
-- Run with the other suites:  python3 tests/run.py path/to/luau worldmap.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Rules = require("../src/Shared/Data/RivalRules")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")
local Garden = require("../src/Shared/World/Garden")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function same(a: Vector3, b: Vector3): boolean
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

-- A repeatable stream of points, so the checks over thousands of them are the same on every run.
local function stream(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

local sill = WorldMap.region("sill") :: WorldMap.Region

case("the world's regions: the sill with the layout's own numbers, the three under the window, the wall above it, the wall west of it and the bushes", function()
	local list = WorldMap.regions(WorldMap.SEED)
	check(#list == 17 and list[1] == sill, `seventeen regions, the sill first, and region() finds it ({#list})`)
	local ids = {}
	for _, r in list do table.insert(ids, r.id) end
	check(table.concat(ids, ",") == "sill,outer_sill,house_wall,bed_a,wall_upper,wall_west,wall_west_upper,shrub_west_a,shrub_west_b,shrub_west_c,shrub_west_d,shrub_west_e,shrub_west_f,shrub_west_g,shrub_west_h,shrub_west_i,shrub_west_j",
		`in priority order ({table.concat(ids, ",")})`)
	check(sill.id == "sill" and sill.kind == "sill", "the sill's id and kind")
	check(same(sill.origin, Vector3.zero), "at the origin, as the sill always was")
	check(same(sill.bounds[1], Layout.PLAY_BOUNDS_MIN) and same(sill.bounds[2], Layout.PLAY_BOUNDS_MAX) and #sill.bounds == 2, "its bounds are the layout's play bounds")
	check(#sill.retreats == 1 and sill.retreats[1].id == "sill_crevice", "one retreat, the crevice")
	check(same(sill.retreats[1].min, Layout.RETREAT_MIN) and same(sill.retreats[1].max, Layout.RETREAT_MAX), "its box is the layout's retreat")
	check(same(sill.spawn.pos, Layout.SPAWN) and same(sill.spawn.heading, Layout.SPAWN_HEADING), "a life begins where the layout's spawn is, facing the layout's heading")
	check(sill.clockScale == 1.0, "the sill keeps its brisk day (clockScale 1.0)")
	check(sill.seed == WorldMap.seed(914, "sill"), "its seed is the world's mixed with its id")
	check(WorldMap.SEED == 914 and WorldMap.HOME == "sill" and WorldMap.REVISION == "world-2" and WorldMap.FIRST_REVISION == "world-1", "the default seed, the home region, the revision (world-2) and the first one")
	check(WorldMap.region("garden") == nil and WorldMap.region("") == nil, "a region that is not on the map is nil")
	local outer = WorldMap.region("outer_sill") :: WorldMap.Region
	local wall = WorldMap.region("house_wall") :: WorldMap.Region
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	check(outer.kind == "outer_sill" and wall.kind == "house_wall" and bed.kind == "bed", "their kinds")
	check(same(outer.bounds[1], Vector3.new(-33, -3, -25.5)) and same(outer.bounds[2], Vector3.new(33, 35, -13.5)), "the outer sill's bounds")
	check(same(wall.bounds[1], Vector3.new(-42, -89, -30)) and same(wall.bounds[2], Vector3.new(42, 35, -13.5)), "the wall's: its face and six studs of air in front, down to y -89")
	check(same(bed.bounds[1], Vector3.new(-42, -93, -76)) and same(bed.bounds[2], Vector3.new(42, 35, -24)), "the bed's: the soil and the air over it")
	check(outer.clockScale == 1.0 and wall.clockScale == 1.0 and bed.clockScale == 0.33, "the outer sill and the wall at the sill's pace, the bed at a third (0.33)")
	check(#outer.retreats == 0 and #wall.retreats == 0 and #bed.retreats == 1 and bed.retreats[1].id == "bed_a_stone", "the bed has the one retreat outside, the gap under its stone")
	check(same(bed.retreats[1].min, Vector3.new(8.6, -90, -52.6)) and same(bed.retreats[1].max, Vector3.new(13.4, -88.6, -47.4)), "and its box")
	check(same(outer.spawn.pos, Vector3.new(0, 0, -18)) and same(outer.spawn.heading, Vector3.new(0, 0, -1)), "the outer sill's spawn is just outside the opening, facing out")
	check(same(bed.spawn.pos, Vector3.new(11, -90, -43.5)) and WorldMap.at(bed.spawn.pos + Vector3.new(0, 0.31, 0)) == bed, "the bed's is on its soil, in front of the stone")
	-- ROBLOX-103: the wall above the window, to the eaves and the gutter
	local upper = WorldMap.region("wall_upper") :: WorldMap.Region
	check(upper.kind == "wall_upper" and same(upper.bounds[1], Vector3.new(-42, 0, -70)) and same(upper.bounds[2], Vector3.new(42, 130, -13.5)), "the wall above: from the shoulders' tops to over the roof's edge, out past the gutter")
	check(upper.clockScale == 1.0 and #upper.retreats == 0 and same(upper.spawn.pos, Vector3.new(0, 109, -61)) and WorldMap.at(upper.spawn.pos + Vector3.new(0, 0.31, 0)) == upper,
		"at the sill's pace, no retreat yet, its spawn in the gutter")
	check(same(wall.spawn.pos, Vector3.new(35, -1.5, -24)) and same(wall.spawn.heading, Vector3.new(0, 1, 0)), "the wall's spawn is on its east shoulder's face now (its top is under the window's east jamb)")
	-- ROBLOX-107: the back wall west of the window (split at y 0 as house_wall and wall_upper are) and the bushes beside the bed, ten chunks of 95 by 88
	local west, westUp = WorldMap.region("wall_west") :: WorldMap.Region, WorldMap.region("wall_west_upper") :: WorldMap.Region
	check(west.kind == "wall_west" and same(west.bounds[1], Vector3.new(-122, -89, -34)) and same(west.bounds[2], Vector3.new(-40, 0, -13.5)) and west.clockScale == 1.0 and #west.retreats == 0,
		"the wall west of the window below y 0: its face, the drainpipe's foot and ten studs of air, at the sill's pace")
	check(westUp.kind == "wall_west_upper" and same(westUp.bounds[1], Vector3.new(-122, 0, -70)) and same(westUp.bounds[2], Vector3.new(-40, 130, -13.5)) and westUp.clockScale == 1.0
		and same(westUp.spawn.pos, Vector3.new(-80, 109, -61)), "and above y 0 to the eaves, its spawn in its gutter")
	local chunks = 0
	for col = 0, 4 do
		for row = 0, 1 do
			chunks += 1
			local r = WorldMap.region("shrub_west_" .. string.char(96 + chunks)) :: WorldMap.Region
			local x1 = -25 - 95 * col
			local z0, z1 = if row == 0 then -112 else -200, if row == 0 then -24 else -112
			check(r ~= nil and r.kind == "shrub" and same(r.bounds[1], Vector3.new(x1 - 95, -93, z0)) and same(r.bounds[2], Vector3.new(x1, -10, z1)) and r.clockScale == 0.33,
				`shrub_west_{string.char(96 + chunks)}: x {x1 - 95}..{x1}, z {z0}..{z1}, at the garden's pace`)
			check(#r.retreats == 1 and r.retreats[1].id == r.id .. "_litter" and r.retreats[1].min.Y == -90 and r.retreats[1].max.Y - r.retreats[1].min.Y >= 1.4
				and WorldMap.at(r.spawn.pos + Vector3.new(0, 0.31, 0)) == r, `{r.id}: one retreat in the litter, a spawn on its litter`)
		end
	end
	for _, r in WorldMap.regions() do
		check(r.clockScale > 0 and r.clockScale <= 1.0, `{r.id}: a clock scale in (0, 1]`)
		check(r.bounds[1].X < r.bounds[2].X and r.bounds[1].Y < r.bounds[2].Y and r.bounds[1].Z < r.bounds[2].Z, `{r.id}: bounds with some volume`)
		check(r.seed >= 1 and r.seed <= 2147483646 and r.seed % 1 == 0, `{r.id}: a whole seed a placer's stream can start from`)
		check(WorldMap.at(r.spawn.pos + Vector3.new(0, 0.31, 0)) == r, `{r.id}: a body standing on its spawn is in it`)
		for _, t in r.retreats do
			check(WorldMap.at((t.min + t.max) * 0.5) == r, `{r.id}: its retreat {t.id} is in it`)
		end
	end
end)

case("the seams: each region lists its neighbours, both ways, along the same line", function()
	local function seamOf(a: string, b: string): WorldMap.Neighbor?
		for _, n in (WorldMap.region(a) :: WorldMap.Region).neighbors do
			if n.id == b then return n end
		end
		return nil
	end
	local seams = {
		{ "sill", "outer_sill", Vector3.new(-8, 0, -13.5), Vector3.new(8, 0, -13.5) }, -- the rail's outer face meets the stone
		{ "outer_sill", "house_wall", Vector3.new(-30, -3, -24), Vector3.new(30, -3, -24) }, -- the stone's front face goes on down as brick
		{ "house_wall", "bed_a", Vector3.new(-25, -90, -24), Vector3.new(25, -90, -24) }, -- the wall's foot meets the soil
		{ "house_wall", "wall_upper", Vector3.new(31, 0, -24), Vector3.new(40, 0, -24) }, -- (ROBLOX-103) the east shoulder's face goes on up as the east jamb's
		-- (ROBLOX-107) the wall west of the window and the bushes
		{ "house_wall", "wall_west", Vector3.new(-40, -90, -24), Vector3.new(-40, 0, -24) }, -- the brick goes on west
		{ "wall_upper", "wall_west_upper", Vector3.new(-40, 0, -24), Vector3.new(-40, 60, -24) }, -- above the window too (the line to y 60)
		{ "wall_west", "wall_west_upper", Vector3.new(-120, 0, -24), Vector3.new(-40, 0, -24) }, -- the west wall goes on up
		{ "wall_west", "shrub_west_a", Vector3.new(-120, -90, -24), Vector3.new(-40, -90, -24) }, -- its foot meets the litter
		{ "house_wall", "shrub_west_a", Vector3.new(-40, -90, -24), Vector3.new(-25, -90, -24) }, -- the house_wall's foot west of the bed
		{ "bed_a", "shrub_west_a", Vector3.new(-25, -90, -24), Vector3.new(-25, -90, -74) }, -- the bed's west edge, flat
	}
	-- the chunks: across the split at z -112 in each column, and to the next column in each row, flat on the litter
	for col = 0, 4 do
		local north, south = "shrub_west_" .. string.char(97 + col * 2), "shrub_west_" .. string.char(98 + col * 2)
		local x1 = -25 - 95 * col
		table.insert(seams, { north, south, Vector3.new(x1 - 95, -90, -112), Vector3.new(x1, -90, -112) })
		if col < 4 then
			table.insert(seams, { north, "shrub_west_" .. string.char(99 + col * 2), Vector3.new(x1 - 95, -90, -112), Vector3.new(x1 - 95, -90, -24) })
			table.insert(seams, { south, "shrub_west_" .. string.char(100 + col * 2), Vector3.new(x1 - 95, -90, -200), Vector3.new(x1 - 95, -90, -112) })
		end
	end
	local count = 0
	for _, r in WorldMap.regions() do count += #r.neighbors end
	check(count == 2 * #seams and #seams == 23, `{#seams} seams, each listed by both regions ({count} listings)`)
	for _, pr in seams do
		local ab, ba = seamOf(pr[1], pr[2]), seamOf(pr[2], pr[1])
		check(ab ~= nil and ba ~= nil, `{pr[1]} and {pr[2]} list each other`)
		if ab and ba then
			check(same(ab.a, pr[3]) and same(ab.b, pr[4]) and same(ba.a, ab.a) and same(ba.b, ab.b), `{pr[1]}/{pr[2]}: the seam's line ({ab.a} to {ab.b})`)
			-- the line lies at both regions' bounds (within a body's height): a spider crossing it is in one of them all the way
			local mid = (ab.a + ab.b) * 0.5
			local function near(id: string): boolean
				local r = WorldMap.region(id) :: WorldMap.Region
				local lo, hi = r.bounds[1], r.bounds[2]
				local q = Vector3.new(math.clamp(mid.X, lo.X, hi.X), math.clamp(mid.Y, lo.Y, hi.Y), math.clamp(mid.Z, lo.Z, hi.Z))
				return (q - mid).Magnitude <= 1.0
			end
			check(near(pr[1]) and near(pr[2]), `{pr[1]}/{pr[2]}: the seam is at both regions' bounds`)
		end
	end
	check(seamOf("sill", "bed_a") == nil and seamOf("outer_sill", "bed_a") == nil, "and no region meets one it does not touch")
end)

case("the map is read-only", function()
	check(not pcall(function() (sill :: any).id = "other" end), "a region cannot be edited")
	check(not pcall(function() (sill.bounds :: any)[1] = Vector3.zero end), "nor its bounds")
	check(not pcall(function() (sill.retreats[1] :: any).id = "x" end), "nor a retreat")
	check(not pcall(function() (sill.spawn :: any).pos = Vector3.zero end), "nor its spawn")
	check(not pcall(function() (WorldMap :: any).REVISION = "x" end), "nor the module")
	check(not pcall(function() table.insert(WorldMap.regions(), sill) end), "nor the list")
end)

case("another world seed changes only the regions' seeds", function()
	local other = WorldMap.regions(1234)
	check(#other == #WorldMap.regions() and other[1].id == "sill" and other[1].seed == WorldMap.seed(1234, "sill") and other[1].seed ~= sill.seed, "the sill's seed follows the world's")
	for i, o in other do
		local d = WorldMap.regions()[i]
		check(o.id == d.id and o.seed == WorldMap.seed(1234, o.id) and o.seed ~= d.seed and same(o.bounds[1], d.bounds[1]) and same(o.bounds[2], d.bounds[2]) and same(o.spawn.pos, d.spawn.pos)
			and #o.retreats == #d.retreats and o.clockScale == d.clockScale and o.kind == d.kind and #o.neighbors == #d.neighbors, `{o.id}: only its seed changes`)
	end
	check((WorldMap.region("sill", 1234) :: WorldMap.Region).seed == other[1].seed and (WorldMap.region("sill", 914) :: WorldMap.Region) == sill, "region() takes the seed too")
end)

case("seed: stable, spread, and in range", function()
	-- Pinned: a region's seed decides every placer of the region for ever; if this ever changes, every garden changes with it.
	check(WorldMap.seed(914, "sill") == 1883132339, `the sill's seed in the default world ({WorldMap.seed(914, "sill")})`)
	check(WorldMap.seed(914, "outer_sill") == 1665906148 and WorldMap.seed(914, "house_wall") == 781001660 and WorldMap.seed(914, "bed_a") == 276332508,
		`the garden's seeds (outer_sill {WorldMap.seed(914, "outer_sill")}, house_wall {WorldMap.seed(914, "house_wall")}, bed_a {WorldMap.seed(914, "bed_a")}): every stone and leaf of them hangs on these`)
	check(WorldMap.seed(914, "sill") == WorldMap.seed(914, "sill") and WorldMap.seed(0, "bed_a") == WorldMap.seed(0, "bed_a"), "the same inputs give the same seed")
	local seen: { [number]: string } = {}
	local clash = 0
	local ids = { "sill", "outer_sill", "house_wall", "bed_a", "bed_b", "bed_c", "shed_wall", "path_1", "path_2", "grass_1", "flower_1", "pond_edge", "", "a", "b", "aa" }
	for world = 0, 40 do
		for _, id in ids do
			local s = WorldMap.seed(world * 37 + 914, id)
			if s < 1 or s > 2147483646 or s % 1 ~= 0 then clash += 1000 end
			local key = `{world * 37 + 914}/{id}`
			if seen[s] ~= nil then clash += 1; print("same seed for " .. seen[s] .. " and " .. key) end
			seen[s] = key
		end
	end
	check(clash == 0, `{41 * #ids} (world, region) pairs, every seed whole, in range and different ({clash} problems)`)
	check(WorldMap.seed(914, "bed_a") ~= WorldMap.seed(914, "bed_b") and WorldMap.seed(914, "bed_a") ~= WorldMap.seed(915, "bed_a"), "a neighbouring id or world seed starts another stream")
	check(WorldMap.seed(-5, "sill") >= 1 and WorldMap.seed(2 ^ 40, "sill") >= 1 and WorldMap.seed(3.7, "sill") == WorldMap.seed(3, "sill"), "negative, huge and fractional world seeds still give a seed")
	check(not pcall(WorldMap.seed, 0 / 0, "sill") and not pcall(WorldMap.seed, math.huge, "sill"), "a world seed that is not a number is refused")
end)

case("at, inBounds and bounds", function()
	local lo, hi = Layout.PLAY_BOUNDS_MIN, Layout.PLAY_BOUNDS_MAX
	local blo, bhi = WorldMap.bounds()
	check(same(blo, Vector3.new(-500, -93, -200)) and same(bhi, Vector3.new(42, 130, 16)), `the union of the regions' bounds ({blo}, {bhi})`)
	local ulo, uhi = WorldMap.unionOf(WorldMap.regions())
	check(same(ulo, blo) and same(uhi, bhi), "is unionOf the regions")
	check(WorldMap.at(Layout.SPAWN) == sill and WorldMap.at(Vector3.new(0, 10, 0)) == sill, "the spawn and the middle are in the sill")
	check(WorldMap.at(lo) == sill and WorldMap.at(hi) == sill and WorldMap.at(Vector3.new(lo.X, hi.Y, lo.Z)) == sill, "the edges are in it (inclusive)")
	check(WorldMap.at(Vector3.new(hi.X + 0.001, 0, 0)) == nil and WorldMap.at(Vector3.new(0, lo.Y - 0.001, 0)) == nil and WorldMap.at(Vector3.new(0, 0, hi.Z + 0.001)) == nil, "a hair outside the sill on its own sides is in no region")
	check(WorldMap.inBounds(Layout.SPAWN) and WorldMap.inBounds(Layout.SPAWN, "sill") and not WorldMap.inBounds(Layout.SPAWN, "garden"), "inBounds by region, and a region that is not there holds nothing")
	check(not WorldMap.inBounds(Vector3.new(900, 1, 1)) and not WorldMap.inBounds(Vector3.new(900, 1, 1), "sill"), "far away is out of both")
	-- Over thousands of points, the sill says exactly what the layout's box says: listed first, it is the region of every point in its box.
	local rand = stream(77)
	local wrong = 0
	for i = 1, 10000 do
		local p = Vector3.new((rand() - 0.5) * 90, (rand() - 0.2) * 60, (rand() - 0.5) * 50)
		local inside = p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
		if (WorldMap.at(p) == sill) ~= inside or WorldMap.inBounds(p, "sill") ~= inside then wrong += 1 end
		if p.Z > -13.5 and (WorldMap.at(p) ~= nil) ~= inside then wrong += 1 end -- (on the room's side of the frame, nothing but the sill)
	end
	check(wrong == 0, `10000 random points: the sill and the layout's box agree ({wrong} differ)`)
	-- Where the regions meet, the first listed wins.
	local outer = WorldMap.region("outer_sill")
	local wall = WorldMap.region("house_wall")
	local bed = WorldMap.region("bed_a")
	check(WorldMap.at(Vector3.new(0, 0.31, -16)) == sill and WorldMap.at(Vector3.new(0, 0.31, -16.001)) == outer, "the sill's margin reaches z -16 out over the stone; past it, the outer sill")
	check(WorldMap.at(Vector3.new(0, 0.31, -13.5)) == sill and WorldMap.inBounds(Vector3.new(0, 0.31, -13.5), "outer_sill"), "on the frame's outer face both hold the point: the sill, listed first")
	check(WorldMap.at(Vector3.new(0, -3, -24.31)) == outer and WorldMap.at(Vector3.new(0, -3.001, -24.31)) == wall, "on the stone's front face down to y -3 the outer sill, below it the wall")
	check(WorldMap.at(Vector3.new(35, 0.31, -18)) == wall and WorldMap.at(Vector3.new(32, 0.31, -18)) == outer, "beside the stone, on the wall's shoulders, the wall")
	check(WorldMap.at(Vector3.new(0, -89, -24.31)) == wall and WorldMap.at(Vector3.new(0, -89.001, -24.31)) == bed and WorldMap.at(Vector3.new(0, -89.69, -24.31)) == bed,
		"on the wall's face down to y -89 the wall; at the foot, standing on the soil, the bed")
	check(WorldMap.at(Vector3.new(0, -50, -30)) == wall and WorldMap.at(Vector3.new(0, -50, -30.001)) == bed, "in the air in front of the wall: six studs out the wall's, beyond it the bed's")
	check(WorldMap.at(Vector3.new(30, -89.69, -50)) == bed and WorldMap.at(Vector3.new(0, -93.001, -50)) == nil and WorldMap.at(Vector3.new(0, -50, -76.001)) == nil, "the bed's air reaches past its soil; under it, and beyond it, nothing")
	check(WorldMap.at(Vector3.new(0, 0.31, -50)) == bed and WorldMap.at(Vector3.new(0, 20, -20)) == outer, "high over the bed, the bed's; over the outer sill, the outer sill's")
	local upper = WorldMap.region("wall_upper")
	check(WorldMap.at(Vector3.new(0, 35, -24.31)) == outer and WorldMap.at(Vector3.new(0, 35.001, -24.31)) == upper and WorldMap.at(Vector3.new(36, 35.001, -24.31)) == upper
		and WorldMap.at(Vector3.new(36, 20, -24.31)) == wall and WorldMap.at(Vector3.new(0, 109.31, -61)) == upper and WorldMap.at(Vector3.new(0, 130.001, -61)) == nil,
		"(ROBLOX-103) up the brick past y 35, the wall above's; beside the window lower down, the wall's; in the gutter, the wall above's; over the roof, nothing")
end)

case("the union of several regions", function()
	local function box(id: string, a: Vector3, b: Vector3): WorldMap.Region
		return { id = id, kind = "sill", origin = Vector3.zero, bounds = { a, b }, seed = 1, neighbors = {}, retreats = {}, spawn = { pos = a, heading = Vector3.xAxis }, clockScale = 1.0 }
	end
	local lo, hi = WorldMap.unionOf({ box("a", Vector3.new(0, 0, 0), Vector3.new(10, 5, 5)), box("b", Vector3.new(-4, -2, 3), Vector3.new(6, 9, 20)), box("c", Vector3.new(2, 1, 1), Vector3.new(3, 2, 2)) })
	check(same(lo, Vector3.new(-4, -2, 0)) and same(hi, Vector3.new(10, 9, 20)), `the smallest box that holds them all ({lo}, {hi})`)
	local one = WorldMap.unionOf({ box("a", Vector3.new(1, 2, 3), Vector3.new(4, 5, 6)) })
	check(same(one, Vector3.new(1, 2, 3)), "one region is its own union")
end)

case("inRetreat is the layout's inRetreat", function()
	local lo, hi = Layout.RETREAT_MIN, Layout.RETREAT_MAX
	local rand = stream(4242)
	local differ, inside = 0, 0
	for i = 1, 10000 do
		-- Half of the points near the crack (so a good share are inside it), half over the whole sill.
		local p = if i % 2 == 0 then Vector3.new(lo.X - 1 + rand() * (hi.X - lo.X + 2), lo.Y - 0.5 + rand() * (hi.Y - lo.Y + 1), lo.Z - 1 + rand() * (hi.Z - lo.Z + 2))
			else Vector3.new((rand() - 0.5) * 70, (rand() - 0.3) * 40, (rand() - 0.5) * 30)
		local here = WorldMap.inRetreat(p)
		if (here ~= nil) ~= Layout.inRetreat(p) then differ += 1 end
		if here ~= nil then inside += 1 end
		if here ~= nil and here ~= "sill_crevice" then differ += 1 end
		if (WorldMap.inRetreat(p, "sill") ~= nil) ~= (here ~= nil) then differ += 1 end
		if WorldMap.inRetreat(p, "garden") ~= nil then differ += 1 end
	end
	check(differ == 0, `10000 random points: the same answer as Layout.inRetreat, and the crevice's id ({differ} differ)`)
	check(inside > 500 and inside < 9500, `and a real share of them are inside ({inside})`)
	-- The edges count (Godot's in_retreat is a closed box), corner by corner.
	local corners = 0
	for _, x in { lo.X, hi.X } do
		for _, y in { lo.Y, hi.Y } do
			for _, z in { lo.Z, hi.Z } do
				if WorldMap.inRetreat(Vector3.new(x, y, z)) == "sill_crevice" and Layout.inRetreat(Vector3.new(x, y, z)) then corners += 1 end
			end
		end
	end
	check(corners == 8, "all eight corners are inside, as in the layout")
	check(WorldMap.inRetreat(Vector3.new(lo.X - 1e-9, lo.Y, lo.Z)) == nil and WorldMap.inRetreat(Vector3.new(hi.X, hi.Y + 1e-9, hi.Z)) == nil, "a hair outside is not")
	check(WorldMap.inRetreat(Layout.SPAWN) == nil and WorldMap.inRetreat(Vector3.new(-25.5, 0.31, 6.0)) == "sill_crevice", "the spawn is outside the crack, the home spot inside it")
	local crevice = WorldMap.retreat("sill_crevice") :: WorldMap.Retreat
	check(crevice == sill.retreats[1] and WorldMap.retreat("stone") == nil, "retreat() finds the crevice and no stone that is not there")
	-- ROBLOX-95: the bed's stone, by id and by a point under it, in the bed and in no other region
	local stone = WorldMap.retreat("bed_a_stone") :: WorldMap.Retreat
	local under = (stone.min + stone.max) * 0.5
	check(stone ~= nil and WorldMap.inRetreat(under) == "bed_a_stone" and WorldMap.inRetreat(under, "bed_a") == "bed_a_stone" and WorldMap.inRetreat(under, "sill") == nil, "the gap under the bed's stone is a retreat of the bed")
	check(WorldMap.inRetreat(Vector3.new(11, -89.69, -50)) == "bed_a_stone" and WorldMap.inRetreat(Vector3.new(11, -89.69, -45)) == nil, "a spider under it is in it; in front of it, not")
end)

case("the sill's generator returns the layout's lists unchanged", function()
	-- Everything a box is, in one string: the order, the ids, the corners, the surface and the colour.
	local function pieceText(list: { Layout.Piece }): string
		local out: { string } = {}
		for _, p in list do
			table.insert(out, string.format("%s|%.17g,%.17g,%.17g|%.17g,%.17g,%.17g|%s|%.17g,%.17g,%.17g", p.id, p.lo.X, p.lo.Y, p.lo.Z, p.hi.X, p.hi.Y, p.hi.Z, p.profile, p.color.R, p.color.G, p.color.B))
		end
		return table.concat(out, "\n")
	end
	local function decorText(list: { Layout.Decor }): string
		local out: { string } = {}
		for _, d in list do
			table.insert(out, string.format("%s|%.17g,%.17g,%.17g|%.17g,%.17g,%.17g|%.17g,%.17g,%.17g|%s", d.id, d.size.X, d.size.Y, d.size.Z, d.at.X, d.at.Y, d.at.Z, d.color.R, d.color.G, d.color.B, tostring(d.transparency)))
		end
		return table.concat(out, "\n")
	end
	local pieces = Region.pieces(sill)
	check(#pieces == #Layout.PIECES and #pieces >= 28, `all {#pieces} boxes`)
	check(pieceText(pieces) == pieceText(Layout.PIECES), "byte for byte the layout's boxes, in the layout's order")
	check(decorText(Region.decor(sill)) == decorText(Layout.DECOR) and #Region.decor(sill) == #Layout.DECOR, "and the layout's drawn-only boxes")
	check(not pcall(Region.pieces, { id = "pond_1", kind = "pond", seed = 1, retreats = {} } :: any) and not pcall(Region.decor, { id = "pond_1", kind = "pond", seed = 1, retreats = {} } :: any), "a kind with no generator is a mistake, not an empty region")
	check(Region.folderName(sill) == "Windowsill" and Region.folderName(WorldMap.region("bed_a") :: WorldMap.Region) == "bed_a", "the sill's folder is still Windowsill, any other is named for its region")
	-- ROBLOX-95: the one change to the sill's boxes is the back frame, now four boxes round the opening
	local frame = {}
	for _, p in pieces do if string.sub(p.id, 1, 10) == "back_frame" then table.insert(frame, p.id) end end
	check(#pieces == 31 and table.concat(frame, ",") == "back_frame_west,back_frame_east,back_frame_head,back_frame_rail", `31 boxes: the back frame in four ({table.concat(frame, ",")})`)
end)

case("the keep-out boxes", function()
	local boxes = Region.keepOut(sill)
	check(#boxes == 2, "the sill's two: its crack and its open sash")
	check(same(boxes[1].min, Rules.keepOutMin) and same(boxes[1].max, Rules.keepOutMax), "the crack's are the rival's rules' own, first")
	local crevice = sill.retreats[1]
	check(boxes[1].min.X <= crevice.min.X and boxes[1].min.Y <= crevice.min.Y and boxes[1].min.Z <= crevice.min.Z
		and boxes[1].max.X >= crevice.max.X and boxes[1].max.Y >= crevice.max.Y and boxes[1].max.Z >= crevice.max.Z, "and it holds the whole retreat")
	check(same(boxes[2].min, Region.SASH_MIN) and same(boxes[2].max, Region.SASH_MAX) and boxes[2].min.X <= -8 and boxes[2].max.X >= 8 and boxes[2].max.Y >= 6 and boxes[2].max.Z < -12.4,
		"the sash's holds the opening, and none of the floor in front of it")
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	local stone = Region.keepOut(bed)
	check(#stone == 1 and stone[1].min.X < bed.retreats[1].min.X and stone[1].max.Y > bed.retreats[1].max.Y, "the bed's: its stone's gap and a margin")
	check(#Region.keepOut(WorldMap.region("outer_sill") :: WorldMap.Region) == 0 and #Region.keepOut(WorldMap.region("house_wall") :: WorldMap.Region) == 0, "the outer sill and the wall: none")
	local a = WorldMap.region("shrub_west_a") :: WorldMap.Region
	local leaf = Region.keepOut(a)
	check(#leaf == 1 and leaf[1].min.X < a.retreats[1].min.X and leaf[1].max.Y > a.retreats[1].max.Y and #Region.keepOut(WorldMap.region("wall_west") :: WorldMap.Region) == 0,
		"(ROBLOX-107) a chunk of the bushes: the gap under its dead leaf and a margin; the wall west of the window: none")
	check(not pcall(Region.keepOut, { id = "pond_1", kind = "pond", retreats = {} } :: any), "a kind with no generator has none")
end)

case("part budgets", function()
	check(Region.budget("sill", "full") == 1253 and Region.budget("sill", "low") == 355, "the sill reports what its decor builds now (ROBLOX-103: 1178 and 314 before the bushes, the bungalows and the fences)")
	check((Region.budget("sill", "low") :: number) < (Region.budget("sill", "full") :: number) * 0.6, "the low tier is a good deal thinner")
	check(Region.budget("pond", "full") == nil and Region.budget("sill", "medium") == nil, "a kind with no budget, or a tier that is not one, has none")
	for _, kind in { "outer_sill", "house_wall", "bed", "wall_upper", "wall_west", "wall_west_upper", "shrub" } do
		local full, low = Region.budget(kind, "full") :: number, Region.budget(kind, "low") :: number
		check(full == Garden.BUDGETS[kind].full and low == Garden.BUDGETS[kind].low and low <= full, `{kind}: {full} drawn parts at full, {low} at low`)
	end
end)

case("the garden's generators: the same from the same seed, inside their regions, nothing overlapping, the stone round its retreat", function()
	local function text(list: { any }): string
		local out = {}
		for _, d in list do
			table.insert(out, string.format("%s|%.9g,%.9g,%.9g|%.9g,%.9g,%.9g", d.id, (d.lo or d.at).X, (d.lo or d.at).Y, (d.lo or d.at).Z, (d.hi or d.size).X, (d.hi or d.size).Y, (d.hi or d.size).Z))
		end
		return table.concat(out, "\n")
	end
	for _, r in WorldMap.regions() do
		if r.kind ~= "sill" then
			local pieces, decor = Region.pieces(r), Region.decor(r)
			local again = WorldMap.regions(1234)
			local other: WorldMap.Region? = nil
			for _, o in again do if o.id == r.id then other = o end end
			check(text(pieces) == text(Garden.pieces(r)) and text(decor) == text(Garden.decor(r)), `{r.id}: the same boxes and the same look every time it is asked`)
			-- a fresh region with the same seed (not the cached one) gives the same garden
			local copy = table.clone(r)
			check(text(Garden.pieces(copy :: any)) == text(pieces) or Garden.pieces(copy :: any) == pieces, `{r.id}: from its seed alone`)
			if r.kind == "bed" and other then
				check(text(Region.pieces(other)) ~= text(pieces), "another world seed is another bed (the stones, the plants and the mounds move)")
			end
			local ids: { [string]: boolean } = {}
			local dup = 0
			for _, p in pieces do
				if ids[p.id] then dup += 1 end
				ids[p.id] = true
				check(p.lo.X < p.hi.X and p.lo.Y < p.hi.Y and p.lo.Z < p.hi.Z, `{r.id}: {p.id} is a box`)
			end
			check(dup == 0, `{r.id}: every piece has its own id`)
			local full, low = 0, 0
			for _, d in decor do
				full += 1
				if not d.full then low += 1 end
			end
			check(full <= (Region.budget(r.kind, "full") :: number) and low <= (Region.budget(r.kind, "low") :: number), `{r.id}: its look keeps to its budget ({full} full, {low} low)`)
			-- a tighter ceiling: the placer stops at it, keeping what it places first
			local tight = Garden.decorWith(r, { full = math.floor(full / 2), low = math.floor(low / 2) })
			local tf, tl = 0, 0
			for _, d in tight do tf += 1; if not d.full then tl += 1 end end
			check(tf <= math.floor(full / 2) and tl <= math.floor(low / 2) and tf > 0 and tight[1].id == decor[1].id, `{r.id}: under half its budget it places at most half ({tf}, {tl})`)
		end
	end
	-- no box outside the window overlaps another box (they may touch; the sill's hand-placed crevice boxes overlap each other, as they always have)
	local all: { { id: string, lo: Vector3, hi: Vector3, sill: boolean } } = {}
	for _, r in WorldMap.regions() do for _, p in Region.pieces(r) do table.insert(all, { id = p.id, lo = p.lo, hi = p.hi, sill = r.kind == "sill" }) end end
	local clash = {}
	for i = 1, #all do
		for j = i + 1, #all do
			local a, b = all[i], all[j]
			if not (a.sill and b.sill) and a.lo.X < b.hi.X - 1e-6 and a.hi.X > b.lo.X + 1e-6 and a.lo.Y < b.hi.Y - 1e-6 and a.hi.Y > b.lo.Y + 1e-6 and a.lo.Z < b.hi.Z - 1e-6 and a.hi.Z > b.lo.Z + 1e-6 then
				table.insert(clash, a.id .. "/" .. b.id)
			end
		end
	end
	check(#clash == 0, `no two of the world's {#all} boxes overlap ({table.concat(clash, ", ")})`)
	-- the bed: everything on its soil, off the landing strip under the wall, clear of its spawn; the stone over its retreat; leaves on their stems
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	local B = Garden.BED
	local byId: { [string]: any } = {}
	for _, p in Region.pieces(bed) do byId[p.id] = p end
	local stray = 0
	for _, p in Region.pieces(bed) do
		if p.id ~= "bed_a_soil" then
			if p.lo.X < B.x0 or p.hi.X > B.x1 or p.lo.Z < B.z0 or p.hi.Z > B.z1 or p.lo.Y < B.top - 1e-6 then stray += 1 end
			if p.hi.Z > B.z1 - B.landing + 1e-6 then stray += 1 end
		end
	end
	check(stray == 0, "every piece of the bed stands on its soil, off the strip under the wall")
	local kinds = { stone = 0, mound = 0, leaf = 0, stem = 0 }
	for id in byId do
		if string.find(id, "stone", 1, true) then kinds.stone += 1 end
		if string.find(id, "mound", 1, true) then kinds.mound += 1 end
		if string.find(id, "_leaf_", 1, true) then kinds.leaf += 1 end
		if string.find(id, "_stem", 1, true) or string.find(id, "_stalk", 1, true) then kinds.stem += 1 end
	end
	check(kinds.stone == 5 and kinds.mound == 6 and kinds.leaf == 7 and kinds.stem == 2, `three stones (the retreat's in three boxes), six mounds, two plants of seven leaves ({kinds.stone}, {kinds.mound}, {kinds.leaf}, {kinds.stem})`)
	local gap = bed.retreats[1]
	local top, w, e = byId.bed_a_stone_top, byId.bed_a_stone_west, byId.bed_a_stone_east
	check(top.lo.Y > gap.max.Y and w.hi.X <= gap.min.X and e.lo.X >= gap.max.X and top.lo.Z <= gap.min.Z and top.hi.Z >= gap.max.Z
		and math.abs(w.hi.Y - top.lo.Y) < 1e-9 and math.abs(e.hi.Y - top.lo.Y) < 1e-9, "the stone lies on its two rests over the gap the map calls bed_a_stone")
	check(top.lo.Y - gap.min.Y >= 1.4, `the gap is tall enough to sit in ({string.format("%.2f", top.lo.Y - gap.min.Y)} studs)`)
	local stem = byId.bed_a_dock_stem
	local touching = 0
	for i = 1, 3 do
		local leaf = byId["bed_a_dock_leaf_" .. i]
		local onX = math.abs(leaf.lo.X - stem.hi.X) < 1e-9 or math.abs(leaf.hi.X - stem.lo.X) < 1e-9
		local onZ = math.abs(leaf.lo.Z - stem.hi.Z) < 1e-9 or math.abs(leaf.hi.Z - stem.lo.Z) < 1e-9
		if (onX or onZ) and leaf.lo.Y > stem.lo.Y and leaf.hi.Y < stem.hi.Y then touching += 1 end
	end
	check(touching == 3, "the dock's three leaves grow from its stem's sides")
	-- the outer sill: the slab is the stone the brief gives (top y 0, x -30..30, z -24..-13.5); the window box's halves leave the opening's path clear
	local outer = WorldMap.region("outer_sill") :: WorldMap.Region
	local slab = Region.pieces(outer)[1]
	check(slab.id == "outer_sill_slab" and same(slab.hi, Vector3.new(30, 0, -13.5)) and slab.lo.X == -30 and slab.lo.Z == -24, "the slab")
	local clear = true
	for _, p in Region.pieces(outer) do
		if p.id ~= slab.id and p.lo.X < 8.5 and p.hi.X > -8.5 then clear = false end
	end
	check(clear, "nothing stands on the stone in front of the opening")
	local wall = Region.pieces(WorldMap.region("house_wall") :: WorldMap.Region)
	check(#wall == 3 and wall[1].lo.Z == -24 and wall[1].lo.Y <= -90 and wall[1].lo.X == -40 and wall[1].hi.X == 40, "the wall's face at z -24, x -40..40, down past the soil")
	-- ROBLOX-103: the wall above the window: the jambs stand on the shoulders beside the window's frame, the brick goes up from the window's head to the eaves, the
	-- gutter hangs on the fascia under the roof's edge with its floor 1.08 m above the sill and a lip to hold a spider in
	local upper: { [string]: any } = {}
	for _, piece in Region.pieces(WorldMap.region("wall_upper") :: WorldMap.Region) do upper[piece.id] = piece end
	local shoulderE, shoulderW = wall[3], wall[2]
	check(upper.wall_upper_east.lo.Y == shoulderE.hi.Y and upper.wall_upper_east.lo.X >= shoulderE.lo.X and upper.wall_upper_east.hi.X == shoulderE.hi.X
		and upper.wall_upper_west.lo.Y == shoulderW.hi.Y and upper.wall_upper_west.lo.X == shoulderW.lo.X and upper.wall_upper_east.lo.X == 31 and upper.wall_upper_west.hi.X == -31,
		"the jambs stand on the shoulders, either side of the window's frame (x 31)")
	check(upper.wall_upper_brick.lo.Y == 14 and upper.wall_upper_brick.lo.Z == -24 and upper.wall_upper_brick.hi.Y == upper.wall_upper_soffit.lo.Y
		and upper.wall_upper_brick.lo.Y == upper.wall_upper_east.hi.Y, "the brick from the window's head (y 14) to the eaves, on the jambs")
	local g, lip, fascia = upper.wall_upper_gutter, upper.wall_upper_gutter_lip, upper.wall_upper_fascia
	check(g.hi.Y == 109 and g.hi.Z == fascia.lo.Z and lip.hi.Z == g.lo.Z and lip.hi.Y - g.hi.Y >= 5 and upper.wall_upper_roof.lo.Y - g.hi.Y >= 10
		and upper.wall_upper_roof.lo.Z < g.hi.Z and upper.wall_upper_roof.lo.Z > lip.lo.Z, "the gutter on the fascia: its floor at y 109, a lip 6 high, the roof's edge over half of it with room under")
	check(#Region.pieces(WorldMap.region("wall_upper") :: WorldMap.Region) == 10 and #Garden.drawnPieces(WorldMap.region("wall_upper") :: WorldMap.Region) == 10, "ten boxes, all drawn by its look")
	-- ROBLOX-107: the wall west of the window and its drainpipe: a column of boxes from the litter to the swan neck, out under the gutter and up into its floor, with no
	-- gap a body would fall through; brackets every 100 studs, each a tie to the brick and a collar round the pipe; the gutter goes on west at wall_upper's floor
	local wp: { [string]: any } = {}
	for _, r in { "wall_west", "wall_west_upper" } do
		for _, piece in Region.pieces(WorldMap.region(r) :: WorldMap.Region) do wp[piece.id] = piece end
	end
	local pipe, upPipe, neck, outlet = wp.wall_west_pipe, wp.wall_west_upper_pipe, wp.wall_west_upper_neck, wp.wall_west_upper_outlet
	check(pipe.lo.Y == -90 and pipe.hi.Y == upPipe.lo.Y and upPipe.hi.Y == neck.lo.Y and neck.hi.Y == outlet.lo.Y and outlet.hi.Y == upper.wall_upper_gutter.hi.Y - 1
		and wp.wall_west_upper_gutter.lo.Y == outlet.hi.Y, "the drainpipe stands on the litter and runs unbroken to the swan neck, out and up the outlet into the gutter's floor")
	check(pipe.hi.Z < -24 and pipe.hi.Z > -26 and neck.hi.Z == pipe.hi.Z and neck.lo.Z <= outlet.lo.Z and outlet.hi.Z <= wp.wall_west_upper_gutter.hi.Z and outlet.lo.Z >= wp.wall_west_upper_gutter.lo.Z,
		"the pipe 1.2 off the brick, the neck out to the outlet, the outlet under the gutter's floor")
	local ties, heights = 0, {}
	for id, piece in wp do
		if string.find(id, "_tie", 1, true) then
			ties += 1
			table.insert(heights, piece.lo.Y)
			check(piece.hi.Z == -24 and piece.lo.Z == pipe.hi.Z, `{id}: from the pipe's back to the brick`)
		end
	end
	table.sort(heights)
	check(ties == 2 and heights[2] - heights[1] == 100, `brackets every 100 studs ({ties}, at {table.concat(heights, ", ")})`)
	check(wp.wall_west_upper_gutter.hi.Y == upper.wall_upper_gutter.hi.Y and wp.wall_west_upper_gutter.hi.X == upper.wall_upper_gutter.lo.X - 1 and wp.wall_west.hi.X == -40 and wp.wall_west.lo.X == -120,
		"the gutter goes on west at the same floor up to wall_upper's end cap; the brick from x -120 to -40")
	-- the bushes: every box of a chunk inside it, on its litter, off the strip by the house's wall; at most 60 boxes; two bushes of walkable twigs and leaf pads; the
	-- dead leaf over the retreat on its two twigs, a gap to sit in; nothing in front of its way in
	for _, c in WorldMap.SHRUB_CHUNKS do
		local r = WorldMap.region(c.id) :: WorldMap.Region
		local pieces = Region.pieces(r)
		local out, bushes, pads = 0, {}, 0
		local byId2: { [string]: any } = {}
		for _, piece in pieces do
			byId2[piece.id] = piece
			if piece.id ~= r.id .. "_soil" then
				if piece.lo.X < c.x0 or piece.hi.X > c.x1 or piece.lo.Z < c.z0 or piece.hi.Z > c.z1 - Garden.SHRUB.landing + 1e-6 or piece.lo.Y < -90 - 1e-6 or piece.hi.Y > r.bounds[2].Y then out += 1 end
			end
			local b = string.match(piece.id, "_bush(%d)_")
			if b then bushes[b] = true end
			if string.find(piece.id, "_pad", 1, true) or string.find(piece.id, "_crown", 1, true) then pads += 1 end
		end
		check(out == 0 and #pieces <= 60, `{r.id}: {#pieces} boxes, all on its litter inside it`)
		check(bushes["1"] and bushes["2"] and pads >= 8, `{r.id}: two bushes with {pads} leaf pads`)
		local gap = r.retreats[1]
		local deadleaf, tw, te = byId2[r.id .. "_deadleaf"], byId2[r.id .. "_twig_west"], byId2[r.id .. "_twig_east"]
		check(deadleaf.lo.Y - gap.min.Y >= 1.4 and tw.hi.X <= gap.min.X and te.lo.X >= gap.max.X and tw.hi.Y == deadleaf.lo.Y and deadleaf.lo.Z <= gap.min.Z and deadleaf.hi.Z >= gap.max.Z,
			`{r.id}: the dead leaf lies on its two twigs over the gap the map calls {gap.id}`)
		local blocked = 0
		for _, piece in pieces do
			if piece.id ~= r.id .. "_soil" and piece.lo.X < gap.max.X and piece.hi.X > gap.min.X and piece.lo.Z < r.spawn.pos.Z + 1 and piece.hi.Z > gap.max.Z + 0.01 and piece.lo.Y < gap.max.Y then blocked += 1 end
		end
		check(blocked == 0, `{r.id}: its way in, from the spawn to the gap, is open`)
	end
end)

case("streaming: the focus follows the spider, and what the spider can reach is inside the radius always sent", function()
	-- With instance streaming on, the server always sends what lies inside StreamingMinRadius (default.project.json) of the player's focus, a part of its own (no
	-- character): parked at the home spawn when the player joins (Server/WorldFocus.park), moved to wherever the client reports its spider (WorldFocus.report), and the
	-- client reports when it is more than REPORT_MOVE studs from its last report (Client/WorldClient). So the focus is never more than LAG studs from the spider, and a
	-- box is counted in only if its nearest point and its centre are both within RADIUS - LAG of every place the spider can stand: how the engine decides for a box
	-- larger than its grid cells is not something these tests can see.
	local RADIUS, LAG = 96, 8
	local Route = require("../src/Shared/Predator/RivalRoute")
	local function nearest(p: Vector3, lo: Vector3, hi: Vector3): number
		return (Vector3.new(math.clamp(p.X, lo.X, hi.X), math.clamp(p.Y, lo.Y, hi.Y), math.clamp(p.Z, lo.Z, hi.Z)) - p).Magnitude
	end
	local function reach(p: Vector3, piece: any): number
		return math.max(nearest(p, piece.lo, piece.hi), ((piece.lo + piece.hi) * 0.5 - p).Magnitude)
	end
	local function stands(r: WorldMap.Region): { Vector3 }
		local out = {}
		for _, f in Route.graph(r.id):allFaces() do
			if not f.forbidden then
				for _, s in f.stand do table.insert(out, s + f.normal * 0.31) end
			end
		end
		return out
	end
	-- 1. at join, before any report: the sill (W1's numbers) and the first steps out through the opening, from the parked focus
	local home = WorldMap.region(WorldMap.HOME) :: WorldMap.Region
	local parked = home.spawn.pos + Vector3.new(0, 0.31, 0)
	local farthestBox = 0
	for _, piece in Region.pieces(home) do
		for _, c in { piece.lo, piece.hi } do farthestBox = math.max(farthestBox, (c - parked).Magnitude) end
	end
	local outerFar = 0
	for _, piece in Region.pieces(WorldMap.region("outer_sill") :: WorldMap.Region) do
		for _, c in { piece.lo, piece.hi } do outerFar = math.max(outerFar, (c - parked).Magnitude) end
	end
	print(`worldmap: from the parked focus, the sill's farthest box corner is {string.format("%.1f", farthestBox)} studs, the outer sill's {string.format("%.1f", outerFar)} (always sent: {RADIUS})`)
	check(farthestBox < RADIUS and outerFar < RADIUS, "the sill and the outer sill are whole before the client has reported anything")
	-- 2. wherever the spider stands, its region is whole: every box of it inside the target radius (StreamingTargetRadius 160, sent as the server has the bandwidth, and
	--    what the client's readiness guard waits on), and every box within 20 studs of it (everything a step, a jump or a fall can meet next) inside the radius always sent
	local TARGET = 160
	for _, r in WorldMap.regions() do
		local worst, guaranteed = 0, 0
		for _, s in stands(r) do
			for _, piece in Region.pieces(r) do
				local d = reach(s, piece)
				worst = math.max(worst, d)
				if nearest(s, piece.lo, piece.hi) <= 20 then guaranteed = math.max(guaranteed, nearest(s, piece.lo, piece.hi)) end
			end
		end
		print(`worldmap: {r.id}: from anywhere on it, its farthest box is {string.format("%.1f", worst)} studs away (nearest point or centre, the farther), {string.format("%.1f", worst + LAG)} from a focus {LAG} behind`)
		check(worst + LAG <= TARGET, `{r.id}: whole inside the target radius from anywhere on it`)
		check(guaranteed + LAG <= RADIUS, `{r.id}: what is near is inside the radius always sent`)
	end
	-- 3. crossing a seam: within ten studs of a seam's line, the boxes on the other side that meet the line (what the spider steps onto) are inside the radius always sent,
	--    and the rest of that region inside the target radius
	local function toLine(p: Vector3, a: Vector3, b: Vector3): number
		local ab = b - a
		local t0 = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (a + ab * t0 - p).Magnitude
	end
	local function meets(piece: any, a: Vector3, b: Vector3): boolean
		for k = 0, 10 do
			local q = a + (b - a) * (k / 10)
			if nearest(q, piece.lo, piece.hi) < 1e-6 then return true end
		end
		return false
	end
	for _, r in WorldMap.regions() do
		for _, n in r.neighbors do
			local other = WorldMap.region(n.id) :: WorldMap.Region
			local onto, rest, near, touching = 0, 0, 0, 0
			for _, piece in Region.pieces(other) do if meets(piece, n.a, n.b) then touching += 1 end end
			for _, s in stands(r) do
				if toLine(s, n.a, n.b) <= 10 then
					near += 1
					for _, piece in Region.pieces(other) do
						if meets(piece, n.a, n.b) then onto = math.max(onto, reach(s, piece)) else rest = math.max(rest, reach(s, piece)) end
					end
				end
			end
			print(`worldmap: {r.id} to {n.id}: within 10 studs of the seam ({near} places), the {touching} boxes of {n.id} on the seam are at most {string.format("%.1f", onto)} studs away, the rest {string.format("%.1f", rest)}`)
			check(near > 0 and touching > 0 and onto + LAG <= RADIUS, `{r.id} to {n.id}: what the spider steps onto is there before it crosses`)
			check(rest + LAG <= TARGET, `{r.id} to {n.id}: and the rest of {n.id} inside the target radius`)
		end
	end
	-- 4. on the wall: the soil straight below the spider (where a fall lands) is in from the top; the whole bed from part way down (Nathan's descent: two minutes on
	--    the line at 0.75 studs a second, the focus reported every 8 studs of it)
	local wall = WorldMap.region("house_wall") :: WorldMap.Region
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	local soil = Region.pieces(bed)[1]
	local fallWorst, fromY = 0, math.huge
	for _, s in stands(wall) do
		if s.Z < -24 and s.X >= soil.lo.X and s.X <= soil.hi.X then -- on the face, over the bed
			fallWorst = math.max(fallWorst, (Vector3.new(s.X, soil.hi.Y, math.clamp(s.Z, soil.lo.Z, soil.hi.Z)) - s).Magnitude)
			local worst = 0
			for _, piece in Region.pieces(bed) do worst = math.max(worst, reach(s, piece)) end
			if worst + LAG > RADIUS then fromY = math.min(fromY, s.Y) end
		end
	end
	print(`worldmap: on the wall's face over the bed, the soil below is at most {string.format("%.1f", fallWorst)} studs down ({string.format("%.1f", fallWorst + LAG)} from a lagging focus); the whole bed is in everywhere below y {string.format("%.1f", fromY)}`)
	check(fallWorst + LAG <= RADIUS, "a fall from anywhere on the wall lands on soil that is there")
	check(fromY < 0 and fromY >= -45, `the whole bed is in from at most half way down the wall (below y {string.format("%.1f", fromY)}), long before a descent on the line reaches the soil`)
	-- the very top: a spider at the outer sill's front edge, or on the brick just under it, that lets go. Its focus is behind it on the stone (it walked out over
	-- the slab), so the soil straight under it is that far from the focus
	local edgeWorst = 0
	for x = soil.lo.X, soil.hi.X, 1 do
		for _, at in { Vector3.new(x, 0.31, -24.31), Vector3.new(x, -3.0, -24.31) } do
			local focus = Vector3.new(x, 0.31, -24.31 + LAG)
			edgeWorst = math.max(edgeWorst, (Vector3.new(x, soil.hi.Y, -24.31) - focus).Magnitude, (Vector3.new(x, soil.hi.Y, -24.31) - at).Magnitude)
		end
	end
	print(`worldmap: from the stone's front edge, the soil below is {string.format("%.1f", edgeWorst)} studs from the spider or from its focus {LAG} studs back over the stone`)
	check(edgeWorst <= RADIUS, "a drop from the edge of the outer sill lands on soil that is there")
	-- 5. what the client reports is a point the server accepts: every place a spider can stand is inside the world's bounds
	local lo, hi = WorldMap.bounds()
	local outside = 0
	for _, r in WorldMap.regions() do
		for _, s in stands(r) do
			if s.X < lo.X or s.Y < lo.Y or s.Z < lo.Z or s.X > hi.X or s.Y > hi.Y or s.Z > hi.Z or WorldMap.at(s) == nil then outside += 1 end
		end
	end
	check(outside == 0, `every place a spider can stand is in a region and inside the bounds the server checks reports against ({outside} are not)`)
end)

-- ---------------------------------------------------------------- ROBLOX-96: the bed's perches, vents and woodlice spots, from its boxes and seed; the retreats' doors
case("the bed's perch list lies inside the bed, each perch on a face of one of its real boxes, its vents and hide spots on the soil, all from the seed", function()
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	local spec = Garden.prey(bed) :: any
	local pieces = Garden.pieces(bed)
	local function onFace(pos: Vector3, normal: Vector3): string?
		for _, p in pieces do
			local insideXZ = pos.X >= p.lo.X - 1e-9 and pos.X <= p.hi.X + 1e-9 and pos.Z >= p.lo.Z - 1e-9 and pos.Z <= p.hi.Z + 1e-9
			local insideYZ = pos.Y >= p.lo.Y - 1e-9 and pos.Y <= p.hi.Y + 1e-9 and pos.Z >= p.lo.Z - 1e-9 and pos.Z <= p.hi.Z + 1e-9
			if normal.Y > 0.5 and insideXZ and math.abs(pos.Y - p.hi.Y) < 1e-9 then return p.id end
			if normal.Y < -0.5 and insideXZ and math.abs(pos.Y - p.lo.Y) < 1e-9 then return p.id end
			if normal.X > 0.5 and insideYZ and math.abs(pos.X - p.hi.X) < 1e-9 then return p.id end
		end
		return nil
	end
	check(spec ~= nil and #spec.perches == 28 and #spec.vents == 4 and spec.target == 6, `28 perches, 4 vents, six prey ({#spec.perches}, {#spec.vents})`)
	local ids: { [string]: boolean } = {}
	for _, p in spec.perches do
		check(not ids[p.id], `perch ids are unique ({p.id})`)
		ids[p.id] = true
		check(WorldMap.inBounds(p.position, "bed_a"), `{p.id} is inside the bed`)
		local face = onFace(p.position, p.normal)
		check(face ~= nil, `{p.id} lies on a face of a real box (its normal {p.normal})`)
		if p.walker then check(face ~= nil and (string.find(face, "_leaf_", 1, true) ~= nil or string.find(face, "_stem", 1, true) ~= nil), `{p.id}, a walker perch, is on a plant`) end
		if p.kind == "under" then check(p.normal.Y < 0 and p.position.Y > -90 + 5, `{p.id} hangs under a leaf well above the soil`) end
	end
	for _, v in spec.vents do
		check(WorldMap.inBounds(v.position, "bed_a") and (v.walker or onFace(v.position, Vector3.yAxis) == "bed_a_soil"), `vent {v.id} is in the bed, a gnat's on the soil`)
	end
	local bugs = Garden.bugs(bed) :: any
	check(#bugs.woodlice == 4 and #bugs.hides == 7, `four woodlice and seven hide spots ({#bugs.woodlice}, {#bugs.hides})`)
	for _, w in bugs.woodlice do check(onFace(w.pos, Vector3.yAxis) == "bed_a_soil", "a woodlouse starts on the soil") end
	for _, h in bugs.hides do check(WorldMap.inBounds(h.pos, "bed_a") and (h.kind == "stone" or h.kind == "litter"), "a hide spot is in the bed, by a stone or under litter") end
	-- the same from the same seed, other from another
	local other = table.clone(bed); other.seed = WorldMap.seed(2, "bed_a")
	local o = Garden.prey(other) :: any
	check(o ~= spec and (o.perches[1].position - spec.perches[1].position).Magnitude > 0.1, "another seed, other soil perches")
	check(Garden.prey(bed) == spec and Garden.bugs(bed) == bugs, "asked again, the same lists")
	-- the retreats' doors: where the words near home are measured from, outside each way in
	local crack = WorldMap.retreat("sill_crevice") :: any
	local stone = WorldMap.retreat("bed_a_stone") :: any
	check(same(crack.door, Vector3.new(-24, 1, 6)) and WorldMap.inRetreat(crack.door) == "sill_crevice" and crack.door.X > crack.min.X, "the crack's door is the point the client has always measured from, just inside its mouth")
	check(same(stone.door, Vector3.new(11, -89.5, -46.5)) and WorldMap.inRetreat(stone.door) == nil and stone.door.Z > stone.max.Z and WorldMap.at(stone.door) == bed, "the stone's door is in front of the gap's mouth, in the bed")
	check(Region.budget("house_wall", "full") == 134 and Region.budget("house_wall", "low") == 75, "the wall's budget carries the descent's dressing and ROBLOX-103's drips, joints and moss (93/73, then 110/75)")
end)

print(`WORLDMAP passed={passed} failed={failed}`)
if failed > 0 then error("WORLDMAP failed") end
