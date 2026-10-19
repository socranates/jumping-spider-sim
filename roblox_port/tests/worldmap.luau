-- The world map (ROBLOX-94): the regions, the questions about a point, the seed of a region, and the sill's generator. Pure: no engine, no shim beyond Vector3.
-- The sill is region 0 of a world and must be exactly what it was before there was one: its bounds, retreat, spawn and boxes are the layout's own, every
-- question a point could be asked of the layout gets the same answer from the map, and the region lists a generator returns are byte-for-byte the layout's.
-- Run with the other suites:  python3 tests/run.py path/to/luau worldmap.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Rules = require("../src/Shared/Data/RivalRules")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")

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

case("the world has one region, the sill, with the layout's own numbers", function()
	local list = WorldMap.regions(WorldMap.SEED)
	check(#list == 1 and list[1] == sill, "one region, and region() finds it")
	check(sill.id == "sill" and sill.kind == "sill", "its id and kind")
	check(same(sill.origin, Vector3.zero), "at the origin, as the sill always was")
	check(same(sill.bounds[1], Layout.PLAY_BOUNDS_MIN) and same(sill.bounds[2], Layout.PLAY_BOUNDS_MAX) and #sill.bounds == 2, "its bounds are the layout's play bounds")
	check(#sill.neighbors == 0, "it meets no other region yet")
	check(#sill.retreats == 1 and sill.retreats[1].id == "sill_crevice", "one retreat, the crevice")
	check(same(sill.retreats[1].min, Layout.RETREAT_MIN) and same(sill.retreats[1].max, Layout.RETREAT_MAX), "its box is the layout's retreat")
	check(same(sill.spawn.pos, Layout.SPAWN) and same(sill.spawn.heading, Layout.SPAWN_HEADING), "a life begins where the layout's spawn is, facing the layout's heading")
	check(sill.clockScale == 1.0, "the sill keeps its brisk day (clockScale 1.0)")
	check(sill.seed == WorldMap.seed(914, "sill"), "its seed is the world's mixed with its id")
	check(WorldMap.SEED == 914 and WorldMap.HOME == "sill" and type(WorldMap.REVISION) == "string" and #WorldMap.REVISION > 0, "the default seed, the home region and a revision")
	check(WorldMap.region("garden") == nil and WorldMap.region("") == nil, "a region that is not on the map is nil")
	for _, r in WorldMap.regions() do
		check(r.clockScale > 0 and r.clockScale <= 1.0, `{r.id}: a clock scale in (0, 1]`)
		check(r.bounds[1].X < r.bounds[2].X and r.bounds[1].Y < r.bounds[2].Y and r.bounds[1].Z < r.bounds[2].Z, `{r.id}: bounds with some volume`)
		check(r.seed >= 1 and r.seed <= 2147483646 and r.seed % 1 == 0, `{r.id}: a whole seed a placer's stream can start from`)
	end
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
	check(#other == 1 and other[1].id == "sill" and other[1].seed == WorldMap.seed(1234, "sill") and other[1].seed ~= sill.seed, "the sill's seed follows the world's")
	local o = other[1]
	check(same(o.bounds[1], sill.bounds[1]) and same(o.bounds[2], sill.bounds[2]) and same(o.spawn.pos, sill.spawn.pos) and same(o.retreats[1].min, sill.retreats[1].min)
		and o.clockScale == sill.clockScale and o.kind == sill.kind, "and nothing else")
	check((WorldMap.region("sill", 1234) :: WorldMap.Region).seed == other[1].seed and (WorldMap.region("sill", 914) :: WorldMap.Region) == sill, "region() takes the seed too")
end)

case("seed: stable, spread, and in range", function()
	-- Pinned: a region's seed decides every placer of the region for ever; if this ever changes, every garden changes with it.
	check(WorldMap.seed(914, "sill") == 1883132339, `the sill's seed in the default world ({WorldMap.seed(914, "sill")})`)
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
	check(same(blo, lo) and same(bhi, hi), "the union of the one region is its bounds")
	check(WorldMap.at(Layout.SPAWN) == sill and WorldMap.at(Vector3.new(0, 10, 0)) == sill, "the spawn and the middle are in the sill")
	check(WorldMap.at(lo) == sill and WorldMap.at(hi) == sill and WorldMap.at(Vector3.new(lo.X, hi.Y, lo.Z)) == sill, "the edges are in it (inclusive)")
	check(WorldMap.at(Vector3.new(hi.X + 0.001, 0, 0)) == nil and WorldMap.at(Vector3.new(0, lo.Y - 0.001, 0)) == nil and WorldMap.at(Vector3.new(0, 0, hi.Z + 0.001)) == nil, "a hair outside is in no region")
	check(WorldMap.inBounds(Layout.SPAWN) and WorldMap.inBounds(Layout.SPAWN, "sill") and not WorldMap.inBounds(Layout.SPAWN, "garden"), "inBounds by region, and a region that is not there holds nothing")
	check(not WorldMap.inBounds(Vector3.new(900, 1, 1)) and not WorldMap.inBounds(Vector3.new(900, 1, 1), "sill"), "far away is out of both")
	-- Over thousands of points, at/inBounds say exactly what the layout's box says.
	local rand = stream(77)
	local wrong = 0
	for i = 1, 10000 do
		local p = Vector3.new((rand() - 0.5) * 90, (rand() - 0.2) * 60, (rand() - 0.5) * 50)
		local inside = p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
		if (WorldMap.at(p) ~= nil) ~= inside or WorldMap.inBounds(p) ~= inside or WorldMap.inBounds(p, "sill") ~= inside then wrong += 1 end
	end
	check(wrong == 0, `10000 random points: the map and the layout's box agree ({wrong} differ)`)
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
	check(crevice == sill.retreats[1] and WorldMap.retreat("stone") == nil, "retreat() finds the crevice and nothing else")
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
	check(not pcall(Region.pieces, { id = "bed_a", kind = "bed" } :: any) and not pcall(Region.decor, { id = "bed_a", kind = "bed" } :: any), "a kind with no generator is a mistake, not an empty region")
	check(Region.folderName(sill) == "Windowsill" and Region.folderName({ id = "bed_a", kind = "bed" } :: any) == "bed_a", "the sill's folder is still Windowsill, any other is named for its region")
end)

case("the keep-out boxes", function()
	local boxes = Region.keepOut(sill)
	check(#boxes == #sill.retreats, "one for each retreat")
	check(same(boxes[1].min, Rules.keepOutMin) and same(boxes[1].max, Rules.keepOutMax), "the sill's are the rival's rules' own")
	local crevice = sill.retreats[1]
	check(boxes[1].min.X <= crevice.min.X and boxes[1].min.Y <= crevice.min.Y and boxes[1].min.Z <= crevice.min.Z
		and boxes[1].max.X >= crevice.max.X and boxes[1].max.Y >= crevice.max.Y and boxes[1].max.Z >= crevice.max.Z, "and each holds its whole retreat")
	check(not pcall(Region.keepOut, { id = "bed_a", kind = "bed" } :: any), "a kind with no generator has none")
end)

case("part budgets", function()
	check(Region.budget("sill", "full") == 1156 and Region.budget("sill", "low") == 292, "the sill reports what its decor builds now")
	check((Region.budget("sill", "low") :: number) < (Region.budget("sill", "full") :: number) * 0.6, "the low tier is a good deal thinner")
	check(Region.budget("bed", "full") == nil and Region.budget("sill", "medium") == nil, "a kind with no budget yet, or a tier that is not one, has none")
end)

case("every region, and every box of it, lies inside the radius streaming always sends around the server's focus", function()
	-- With instance streaming on, the server sends each client what is near its replication focus, and always everything inside StreamingMinRadius of it (default.project.json). A player
	-- has no character, so the focus is a part of its own, parked at the home spawn (Server/Main, Server/WorldFocus) for as long as the world is the sill and the regions touching it. The
	-- client's rays (the motor, the senses, the flies, the rival) must never ask about a box that is not there: so all of the map must be inside that radius of the focus, or the round
	-- that adds a region farther out moves the focus with the spider first.
	local STREAMING_MIN_RADIUS = 96
	local home = WorldMap.region(WorldMap.HOME) :: WorldMap.Region
	local focus = home.spawn.pos + Vector3.new(0, 0.31, 0)
	local farthest, farthestBox = 0, 0
	for _, r in WorldMap.regions() do
		for _, x in { r.bounds[1].X, r.bounds[2].X } do
			for _, y in { r.bounds[1].Y, r.bounds[2].Y } do
				for _, z in { r.bounds[1].Z, r.bounds[2].Z } do
					farthest = math.max(farthest, (Vector3.new(x, y, z) - focus).Magnitude)
				end
			end
		end
		for _, piece in Region.pieces(r) do
			check(piece.lo.X >= r.bounds[1].X and piece.lo.Y >= r.bounds[1].Y and piece.lo.Z >= r.bounds[1].Z
				and piece.hi.X <= r.bounds[2].X and piece.hi.Y <= r.bounds[2].Y and piece.hi.Z <= r.bounds[2].Z, `{r.id}: {piece.id} is inside the region's bounds`)
			for _, c in { piece.lo, piece.hi } do farthestBox = math.max(farthestBox, (c - focus).Magnitude) end
		end
	end
	print(`worldmap: the farthest corner of the map is {string.format("%.1f", farthest)} studs from the focus, the farthest box corner {string.format("%.1f", farthestBox)} (always sent: {STREAMING_MIN_RADIUS})`)
	check(farthest < STREAMING_MIN_RADIUS, `a corner of the map is {string.format("%.1f", farthest)} studs from the focus, past the {STREAMING_MIN_RADIUS} always sent`)
	check(farthestBox <= farthest, "and no box is farther than its region's bounds")
end)

print(`WORLDMAP passed={passed} failed={failed}`)
if failed > 0 then error("WORLDMAP failed") end
