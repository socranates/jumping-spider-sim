-- The preserve (ROBLOX-115, docs/PARK_WORLD_DESIGN.md): two worlds, one engine. The worlds and the choice of one (World/Worlds), the map answering for the
-- active world (World/WorldMap: the preserve's one walkable region is the sill, byte for byte, with no neighbours; its backdrop is drawn only, never on the map),
-- the preserve's map in metres and its shift (World/Preserve: the hut's window at the origin, everything within LIMIT), the backdrop's looks (World/PreserveLook:
-- deterministic, within their budgets, every part inside LIMIT and under Roblox's 2,048 studs, known materials), the plan (World/LookPlan: near at the tier's
-- detail, the rest far, within the budget everywhere on a walk across the preserve), the drift (Movement/TitleShots' preserve keys, clear of the hut and its
-- garden) and the trains (World/PreserveTrain: a seeded timetable, every car inside the line). Pure: no engine, no client (tests/selftest_preserve.luau drives the
-- real client in the preserve).
-- Run with the other suites:  python3 tests/run.py path/to/luau preserve.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Worlds = require("../src/Shared/World/Worlds")
local Preserve = require("../src/Shared/World/Preserve")
local PreserveLook = require("../src/Shared/World/PreserveLook")
local PreserveTrain = require("../src/Shared/World/PreserveTrain")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")
local LookPlan = require("../src/Shared/World/LookPlan")
local Materials = require("../src/Shared/Habitat/Materials")
local TitleShots = require("../src/Shared/Movement/TitleShots")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	WorldMap.use("test_garden") -- (every case leaves the test garden active, whatever it did)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function same(a: Vector3, b: Vector3): boolean
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

case("the worlds: the test garden and the preserve, the preserve the default (ROBLOX-118), any other value the default", function()
	check(Worlds.DEFAULT == "preserve" and Worlds.ATTRIBUTE == "World" and #Worlds.IDS == 2 and Worlds.IDS[1] == "test_garden" and Worlds.IDS[2] == "preserve", "two worlds, the test garden first, the preserve the default")
	check(Worlds.choose(nil) == "preserve" and Worlds.choose("preserve") == "preserve" and Worlds.choose("test_garden") == "test_garden" and Worlds.choose("Preserve") == "preserve"
		and Worlds.choose(7) == "preserve", "an attribute names a world exactly, anything else is the default")
	check(WorldMap.world() == "test_garden", "the map starts on the test garden, the CLI suites' world, until a server or client chooses")
	check(Worlds.get("test_garden").revision == WorldMap.REVISION and Worlds.get("preserve").revision == "preserve-3", "the test garden's revision is the map's, the preserve's its own (ROBLOX-118: preserve-3)")
	check(Worlds.get("test_garden").name == "The Test Garden" and Worlds.get("preserve").name == "The Preserve", "their names")
	check(not pcall(Worlds.get, "garden") and not pcall(WorldMap.use, "garden"), "no world by another name")
end)

case("the map answers for the active world: the preserve's sill is the same sill, now with the hut round it (ROBLOX-116); the test garden comes back whole", function()
	local before = #WorldMap.regions()
	local lo0, hi0 = WorldMap.bounds()
	check(WorldMap.world() == "test_garden" and before > 10 and #WorldMap.drawn() == 0 and WorldMap.drawnZone("hut") == nil, "the test garden is active: its regions, no drawn zones")
	local gardenSill = WorldMap.region("sill") :: WorldMap.Region
	check(WorldMap.use("preserve") == "test_garden" and WorldMap.world() == "preserve" and WorldMap.revision() == "preserve-3", "the preserve made active (the test garden was)")
	local regions = WorldMap.regions()
	local sill = regions[1]
	local infill=0;for _,r in regions do if r.kind=="verge" then infill+=1 end end
	check(#regions == 181+infill and infill>0 and sill.id == "sill" and sill.kind == "sill" and #sill.neighbors == 5,
		`181 authored habitat regions plus compact infill (ROBLOX-118: the ceiling, the back room, the eaves, the path round the back room and on to the meadow, 105; ROBLOX-119: the bench patch and the meadow's edge, 41; ROBLOX-122: the mown path, the boardwalk and the pond's edge, 61), the sill first with its five seams into the hut ({#regions}, {#sill.neighbors})`)
	check(same(sill.bounds[1], Layout.PLAY_BOUNDS_MIN) and same(sill.bounds[2], Layout.PLAY_BOUNDS_MAX) and same(sill.spawn.pos, Layout.SPAWN) and same(sill.spawn.heading, Layout.SPAWN_HEADING)
		and sill.clockScale == 1.0 and sill.seed == gardenSill.seed and #sill.retreats == 1 and sill.retreats[1].id == "sill_crevice"
		and same(sill.retreats[1].min, Layout.RETREAT_MIN) and same(sill.retreats[1].max, Layout.RETREAT_MAX), "its numbers are the layout's, as the test garden's sill's")
	check(Region.pieces(sill) == Layout.PIECES and Region.decor(sill) == Layout.DECOR :: any, "its boxes are the layout's own tables, byte for byte")
	local lo, hi = WorldMap.bounds()
	check(lo.X <= -310 and hi.X >= 590 and lo.Z <= -1316 and hi.Z >= 340 and lo.Y <= -97 and hi.Y >= 299, "the motor's fall-off box holds the hut, its back room, its eaves, its garden, the paths, the bench patch with its lamppost and drain, and the meadow's edge")
	check(WorldMap.at(Vector3.new(0, 0.31, 0)) == sill and WorldMap.at(Vector3.new(0, -89.7, -30)) == nil and WorldMap.at(Preserve.at(31, 40, 0.5)) == nil, "a point on the sill is the sill's; the bed and the meadow are no region")
	check(WorldMap.inRetreat(Vector3.new(-25.5, 0.31, 6)) == "sill_crevice" and WorldMap.inRetreat(Vector3.new(11, -89.69, -50)) == nil and WorldMap.retreat("bed_a_stone") == nil, "the crack is a retreat; the bed's stone is not")
	check(WorldMap.region("bed_a") == nil and WorldMap.region("outer_sill") == nil and WorldMap.region("hut") == nil, "no garden regions, and a zone is not a region")
	-- the backdrop's zones: drawn only, region-shaped for the plan, never on the map
	local drawn = WorldMap.drawn()
	check(#drawn == #Preserve.ZONES and #drawn == 15, `{#drawn} drawn zones, one for each of World/Preserve's`)
	local seeds: { [number]: boolean } = {}
	local allOk = true
	for i, z in drawn do
		local zone = Preserve.ZONES[i]
		local lo2, hi2 = Preserve.zoneBox(zone)
		if z.id ~= zone.id or z.kind ~= "backdrop" or not same(z.bounds[1], lo2) or not same(z.bounds[2], hi2) or z.seed ~= WorldMap.seed(WorldMap.SEED, z.id) or seeds[z.seed]
			or #z.neighbors ~= 0 or #z.retreats ~= 0 or WorldMap.drawnZone(z.id) ~= z or not Region.streamed(z.kind) or #Region.pieces(z) ~= 0 or #Region.keepOut(z) ~= 0 then
			allOk = false
			print("  zone " .. z.id)
		end
		seeds[z.seed] = true
	end
	check(allOk, "each zone: kind backdrop, its box its bounds, its own seed, no seams, no retreats, no boxes, nothing to keep out of")
	check(WorldMap.drawn(915)[1].seed == WorldMap.seed(915, "hut") and WorldMap.drawn(915)[1].seed ~= drawn[1].seed, "another world seed, other seeds")
	WorldMap.use("test_garden")
	local lo3, hi3 = WorldMap.bounds()
	check(#WorldMap.regions() == before and WorldMap.region("sill") == gardenSill and same(lo3, lo0) and same(hi3, hi0) and WorldMap.at(Vector3.new(0, -89.7, -30)) ~= nil
		and #WorldMap.drawn() == 0 and WorldMap.revision() == WorldMap.REVISION, "the test garden active again: every region, its bounds, its revision, no drawn zones")
end)

case("the preserve's map: 100 by 60 m, the hut's window at the origin, north out of it, every zone, home range and corridor inside LIMIT", function()
	check(Preserve.SIZE.x == 100 and Preserve.SIZE.z == 60 and Preserve.LIMIT == 6000, "100 by 60 m, within 6,000 studs")
	local w = Preserve.at(Preserve.ORIGIN_X_M, Preserve.NORTH_FACE_M, 0)
	check(w.X == 0 and w.Z == Preserve.NORTH_FACE_Z and w.Y == Preserve.GROUND_Y and Preserve.NORTH_FACE_Z == -16, "the window's middle at x 0 on the hut's north face, z -16")
	check(Preserve.at(45.75, 15).Z < Preserve.at(45.75, 5).Z and Preserve.at(50, 5).X > 0, "north is -z (out of the window, as the sill always looked) and east is +x")
	local x, z, y = Preserve.metres(Preserve.at(70, 37, 1.5))
	check(math.abs(x - 70) < 1e-9 and math.abs(z - 37) < 1e-9 and math.abs(y - 1.5) < 1e-9, "metres and studs both ways")
	check(Preserve.GROUND_Y == -85 and Preserve.FLOOR_Y == -70 and Preserve.EAVES_Y - Preserve.GROUND_Y == 240, "the sill 85 cm over the ground outside and 70 over the hut's floor; the eaves 2.4 m up")
	local corners = { Preserve.at(0, 0), Preserve.at(100, 0), Preserve.at(0, 60), Preserve.at(100, 60) }
	local far = 0
	for _, c in corners do far = math.max(far, math.abs(c.X), math.abs(c.Z)) end
	check(far < Preserve.LIMIT and math.abs(Preserve.at(100, 60).X - 5425) < 1e-6 and math.abs(Preserve.at(100, 60).Z + 5516) < 1e-6, `the preserve's corners within {far} studs`)
	local inside = true
	for _, zn in Preserve.ZONES do
		local lo, hi = Preserve.zoneBox(zn)
		for _, v in { lo, hi } do
			if math.abs(v.X) > Preserve.LIMIT or math.abs(v.Y) > Preserve.LIMIT or math.abs(v.Z) > Preserve.LIMIT then inside = false; print("  zone outside: " .. zn.id) end
		end
	end
	check(inside, "every zone's box within LIMIT")
	local homes = true
	for i, h in Preserve.HOME_RANGES do
		if h.n ~= i or Preserve.zone(h.zone) == nil then homes = false end
	end
	check(#Preserve.HOME_RANGES == 10 and homes and Preserve.HOME_RANGES[1].id == "ranger_hut", "the ten home ranges in the design's order, each in a zone, the hut first")
	local hutBox = { Preserve.zoneBox(Preserve.zone("hut") :: any) }
	check(hutBox[1].X <= -205 and hutBox[2].X >= 503.5 and hutBox[1].Z <= -16 and hutBox[2].Z >= 284, "the hut's zone holds the hut and its back room under their roof (x -205..503.5, z -16..284)")
	local paths = true
	for _, c in Preserve.CORRIDORS do
		for _, p in c.points do
			local s = Preserve.at(p[1], p[2])
			if math.abs(s.X) > Preserve.LIMIT or math.abs(s.Z) > Preserve.LIMIT then paths = false end
		end
	end
	check(#Preserve.CORRIDORS >= 8 and paths, "the corridors inside LIMIT")
end)

-- The eight corners of a drawn record's box, turned as Scenery.look turns it (CFrame.Angles by `turn`, degrees).
local function corners(d: any): { Vector3 }
	local cf = CFrame.new(d.at)
	if d.turn ~= nil then cf = cf * CFrame.Angles(math.rad(d.turn.X), math.rad(d.turn.Y), math.rad(d.turn.Z)) end
	local out = {}
	for _, sx in { -0.5, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				table.insert(out, cf:PointToWorldSpace(Vector3.new(d.size.X * sx, d.size.Y * sy, d.size.Z * sz)))
			end
		end
	end
	return out
end

case("the backdrop's looks: the same forever from a zone's seed, within their budgets, every part inside LIMIT, none over 2,048 studs, known materials", function()
	WorldMap.use("preserve")
	local totals = { 0, 0, 0, 0 }
	for _, z in WorldMap.drawn() do
		local list = PreserveLook.records(z.id, z.seed)
		check(PreserveLook.records(z.id, z.seed) == list and Region.decor(z) == list :: any, `{z.id}: the same list each time, and the region's decor`)
		local other = PreserveLook.records(z.id, z.seed + 1)
		local f, l, fa, fl = PreserveLook.counts(z.id, z.seed)
		local B = PreserveLook.BUDGETS[z.id]
		check(B ~= nil and f <= B.full and l <= B.low and fa <= B.far and fl <= B.farLow and fa > 0, `{z.id}: {f}/{l} parts at full/low, {fa}/{fl} far, within {B.full}/{B.low}/{B.far}/{B.farLow}`)
		local moved = #other ~= #list
		for i = 1, math.min(#other, #list) do
			if not same(other[i].at, list[i].at) or not same(other[i].size, list[i].size) or other[i].color.R ~= list[i].color.R or other[i].color.G ~= list[i].color.G or other[i].color.B ~= list[i].color.B then moved = true end
		end
		local byHand = z.id == "hut" or z.id == "bench" or z.id == "compost" or z.id == "ground" or z.id == "railway"
		check(moved ~= byHand, `{z.id}: another seed places or colours its things otherwise ({if byHand then "not: it is placed by hand" else "it is placed from the seed"})`)
		totals[1] += f; totals[2] += l; totals[3] += fa; totals[4] += fl
		local ids: { [string]: boolean } = {}
		local bad: { string } = {}
		for _, d in list do
			if ids[d.id] then table.insert(bad, "twice " .. d.id) end
			ids[d.id] = true
			if not Materials.known(d.material or "SmoothPlastic") then table.insert(bad, "material " .. d.id) end
			if math.max(d.size.X, d.size.Y, d.size.Z) > 2048 or math.min(d.size.X, d.size.Y, d.size.Z) <= 0 then table.insert(bad, "size " .. d.id) end
			for _, c in corners(d) do
				if math.abs(c.X) > Preserve.LIMIT or math.abs(c.Y) > Preserve.LIMIT or math.abs(c.Z) > Preserve.LIMIT then table.insert(bad, "outside " .. d.id); break end
			end
			if d.shape ~= nil and d.shape ~= "Ellipsoid" and d.shape ~= "Cylinder" and d.shape ~= "Ball" then table.insert(bad, "shape " .. d.id) end
		end
		check(#bad == 0, `{z.id}: every record well made ({table.concat(bad, ", ")})`)
	end
	print(`preserve: the backdrop's records: {totals[1]} at full, {totals[2]} at low; the far look {totals[3]} at full, {totals[4]} at low`)
	check(totals[3] <= 600 and totals[4] <= 460, `the far preserve is cheap masses: {totals[3]} parts at the full tier, {totals[4]} at the low`)
	check(not PreserveLook.knows("bed_a") and not pcall(PreserveLook.records, "bed_a", 1), "no look for a zone the preserve does not have")
	-- the hut stands round the sill's frame without covering it: none of its records reaches into the sill's box where the spider walks
	local hut = WorldMap.drawnZone("hut") :: WorldMap.Region
	local intrude: { string } = {}
	for _, d in PreserveLook.records(hut.id, hut.seed) do
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, c in corners(d) do lo, hi = lo:Min(c), hi:Max(c) end
		-- the sill's walkable volume: its floor's top to its frame's top, inside the frames and in front of the back frame
		if lo.X < 29.99 and hi.X > -29.99 and lo.Y < 13.9 and hi.Y > 0.01 and lo.Z < 11.99 and hi.Z > -12.49 then table.insert(intrude, d.id) end
	end
	check(#intrude == 0, `no part of the hut in the sill's own volume ({table.concat(intrude, ", ")})`)
end)

case("the plan in the preserve: near the hut whole, the far preserve its masses, within the budget at both tiers everywhere", function()
	WorldMap.use("preserve")
	local sill = WorldMap.region("sill") :: WorldMap.Region
	for _, tier in { "full", "low" } do
		local top = if tier == "low" then "low" else "full"
		local plan, total = LookPlan.plan(sill.spawn.pos, tier, sill, nil)
		-- (ROBLOX-118: the hut's ceiling, back room and eaves are walkable regions near the sill now, planned before the backdrop's zones, so at the full tier the
		-- hut garden's backdrop beyond the walkable core may be held at the low tier's detail from the sill)
		check(plan.hut == top and (plan.hut_garden == top or (tier == "full" and plan.hut_garden == "low")) and plan.ground == top,
			`{tier}: the hut and the ground at the tier's detail from the sill, the hut garden at least the low tier's ({tostring(plan.hut_garden)})`)
		local farOk = true
		for _, id in { "meadow", "pond", "woodland", "railway", "city_east", "city_west", "towers", "scrub", "wall", "compost" } do
			if plan[id] ~= "far" then farOk = false; print(`  {id} {tostring(plan[id])}`) end
		end
		check(farOk and plan.sill == nil, `{tier}: the rest far, and the sill no look`)
		check(total <= LookPlan.BUDGET[tier], `{tier}: {total} parts from the sill, within {LookPlan.BUDGET[tier]}`)
		print(`preserve: from the sill at {tier}: {total} parts`)
		local crest = Preserve.at(50, Preserve.RAILWAY.crest + 0.5, Preserve.RAILWAY.height)
		local p2, t2 = LookPlan.plan(crest, tier, nil, nil)
		check(p2.railway == top and p2.hut == "far" and t2 <= LookPlan.BUDGET[tier], `{tier}: at the railway's crest the railway {tostring(p2.railway)}, the hut {tostring(p2.hut)}, {t2} parts`)
		-- a walk the length of the preserve and across it at a spider's height over the ground, a plan every metre: always within the budget
		-- (ROBLOX-119: on through the bench patch and up the meadow's edge first, the walkable home ranges 8 and 3)
		-- (ROBLOX-122: then east along the mown path, north to the boardwalk, along it to the pond's edge and down onto its bank)
		local path = { sill.spawn.pos, Preserve.at(45.5, 13, 0.01), Preserve.at(45.15, 14.6, 0.01), Preserve.at(45.15, 20.6, 0.01), Preserve.at(46.5, 14.64, 0.01),
			Preserve.at(61.15, 14.64, 0.01), Preserve.at(61.15, 29.2, 0.01), Preserve.at(61.2, 30, 0.41), Preserve.at(67.5, 30, 0.41), Preserve.at(64.5, 31.5, 0.01), Preserve.at(43, 17, 0.01), Preserve.at(20, 20, 0.01), Preserve.at(20, 46, 0.01), Preserve.at(58, 49, 0.01), Preserve.at(70, 30, 0.4), Preserve.at(93, 30, 1.2),
			Preserve.at(93, 55, 1.2), Preserve.at(50, 62.6, 3.0), Preserve.at(5, 6, 0.01) }
		local worst, changes, held = 0, 0, nil :: any
		local ok = true
		for k = 1, #path - 1 do
			local a, b = path[k], path[k + 1]
			local steps = math.max(1, math.ceil((b - a).Magnitude / 100))
			for i = 0, steps do
				local p = a:Lerp(b, i / steps)
				local now, tot = LookPlan.plan(p, tier, nil, held)
				worst = math.max(worst, tot)
				if tot > LookPlan.BUDGET[tier] then ok = false end
				if held ~= nil then
					for id, level in now do if held[id] ~= level then changes += 1 end end
				end
				held = now
			end
		end
		check(ok, `{tier}: a walk through the preserve stays within the budget (at most {worst})`)
		print(`preserve: the walk at {tier}: at most {worst} parts, {changes} changes`)
	end
	-- a zone's far look at the low tier leaves out its full-tier records; the test garden's far looks are as they were (the tier does not touch them)
	local meadow = WorldMap.drawnZone("meadow") :: WorldMap.Region
	check(LookPlan.count(meadow, "far", "low") < LookPlan.count(meadow, "far", "full"), "the meadow's far look is thinner at the low tier")
	WorldMap.use("test_garden")
	local eaves = WorldMap.region("eaves") :: WorldMap.Region
	check(LookPlan.records(eaves, "far", "low") == LookPlan.records(eaves, "far") and #LookPlan.records(eaves, "far") == #LookPlan.FAR.eaves, "the test garden's far looks are the same at both tiers")
end)

case("the preserve's drift: from over the hut garden to the window, clear of the hut, its fence and its beds", function()
	local keys = TitleShots.PRESERVE_DRIFT
	check(#keys == 3 and keys[3].t == TitleShots.DRIFT_S and TitleShots.DRIFTS.preserve == keys and TitleShots.DRIFTS.test_garden == TitleShots.DRIFT, "three keys, the last at DRIFT_S; each world its drift")
	local a, fa = TitleShots.drift(0, "preserve")
	local b, fb = TitleShots.drift(0, nil)
	local c = TitleShots.drift(0, "elsewhere")
	local function at(p: Vector3, q: Vector3): boolean return (p - q).Magnitude < 1e-6 end
	local g = TitleShots.drift(0, "test_garden")
	check(at(a.Position, keys[1].eye) and fa == keys[1].fov and at(b.Position, keys[1].eye) and fb == keys[1].fov and at(c.Position, keys[1].eye)
		and at(g.Position, TitleShots.DRIFT[1].eye) and TitleShots.DEFAULT_WORLD == Worlds.DEFAULT,
		"the preserve's from its first key; nil and an unknown world are the default world's, the preserve's (ROBLOX-118); the test garden's its own")
	local arrive = TitleShots.drift(TitleShots.DRIFT_S, "preserve")
	check((arrive.Position - keys[3].eye).Magnitude < 1e-6, "it arrives at its last key")
	-- the boxes it must stay clear of: every axis-aligned record of the hut and the hut garden, grown by 2 studs
	WorldMap.use("preserve")
	local boxes = {}
	for _, id in { "hut", "hut_garden", "bench" } do
		local z = WorldMap.drawnZone(id) :: WorldMap.Region
		for _, d in PreserveLook.records(z.id, z.seed) do
			local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, k in corners(d) do lo, hi = lo:Min(k), hi:Max(k) end
			table.insert(boxes, { id = d.id, lo = lo - Vector3.one * 2, hi = hi + Vector3.one * 2 })
		end
	end
	local hit: string? = nil
	for f = 0, 60 * 50 do
		local p = TitleShots.drift(f / 60, "preserve").Position
		for _, bx in boxes do
			if p.X > bx.lo.X and p.X < bx.hi.X and p.Y > bx.lo.Y and p.Y < bx.hi.Y and p.Z > bx.lo.Z and p.Z < bx.hi.Z then hit = `{bx.id} at {f / 60} s`; break end
		end
		if hit then break end
	end
	check(hit == nil, `the camera never enters a part of the hut, its garden or the bench ({tostring(hit)})`)
	check(#TitleShots.preserveViews() == 4 and TitleShots.preserveViews()[1].name == "preserve_drift_0" and TitleShots.preserveViews()[4].name == "preserve_intro_glass",
		"its three frames for the previewer, and (ROBLOX-118) the intro's first shot in the hut")
end)

case("the trains: a seeded timetable, a few minutes apart, every car drawn inside the line", function()
	local seed = WorldMap.seed(WorldMap.SEED, "train")
	local s1, s2 = PreserveTrain.schedule(seed), PreserveTrain.schedule(seed)
	local L = PreserveTrain.LINE
	check(L.x0 >= -Preserve.LIMIT and L.x1 <= Preserve.LIMIT and L.x1 - L.x0 > 10000, "the line runs nearly the width of the world, inside LIMIT")
	local okGaps, okSame, okCars = true, true, true
	local kinds: { [string]: number } = {}
	for k = 1, 60 do
		local p, q = s1.pass(k), s2.pass(k)
		if p.start ~= q.start or p.cars ~= q.cars or p.dir ~= q.dir or p.speed ~= q.speed then okSame = false end
		local gap = if k == 1 then p.start else p.start - s1.pass(k - 1).finish
		local range = if k == 1 then PreserveTrain.FIRST else PreserveTrain.GAP
		if gap < range[1] - 1e-9 or gap > range[2] + 1e-9 then okGaps = false end
		kinds[p.kind] = (kinds[p.kind] or 0) + 1
		local cr = PreserveTrain.CARS[p.kind]
		if p.cars < cr[1] or p.cars > cr[2] then okCars = false end
		for i = 0, 20 do
			local t = p.start + (p.finish - p.start) * i / 20
			local _, mids = PreserveTrain.cars(p, t)
			for _, m in mids do
				if m - PreserveTrain.CAR.length / 2 < L.x0 - 1e-6 or m + PreserveTrain.CAR.length / 2 > L.x1 + 1e-6 then okCars = false end
			end
		end
	end
	check(okSame, "the same seed, the same timetable")
	check(okGaps, "a pass every two and a half to five and a half minutes, the first within two minutes")
	check(okCars, "trains of their kind's length, every car drawn wholly inside the line")
	check((kinds.commuter or 0) > 0 and (kinds.freight or 0) > 0, `commuters and freights ({kinds.commuter} and {kinds.freight} in sixty)`)
	local first = s1.pass(1)
	check(s1.at(first.start - 1) == nil and s1.at(first.start + 1) == first and s1.at((first.finish + s1.pass(2).start) / 2) == nil and s1.at(s1.pass(5).start + 1) == s1.pass(5), "at(): a pass while one is under way, none between")
	local _, mid = PreserveTrain.cars(first, (first.start + first.finish) / 2)
	check(#mid == first.cars, "mid-pass every car is out on the line")
	local _, edge = PreserveTrain.cars(first, first.start + 0.01)
	check(#edge == 0, "as it comes out of the covered way no car is drawn yet")
	check(PreserveTrain.schedule(seed + 1).pass(1).start ~= first.start, "another seed, another timetable")
end)

case("the sill's Decor in the preserve: the same sill and window, without the test garden's view or its window box", function()
	local Scenery = require("../src/Shared/Habitat/Scenery")
	local function count(m: Instance): number
		local n = 0
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
		return n
	end
	local garden, gardenReplaced = Scenery.decor(nil)
	local hut, hutReplaced = Scenery.decor(nil, "preserve")
	check(garden:FindFirstChild("View") ~= nil and hut:FindFirstChild("View") == nil and hut:FindFirstChild("Wall") ~= nil and hut:FindFirstChild("UVLayer") ~= nil,
		"the preserve's has the window wall and the UV layer and no view")
	local gardenBox, hutBox = false, false
	for id in gardenReplaced do if string.find(id, "window_box", 1, true) then gardenBox = true end end
	for id in hutReplaced do if string.find(id, "window_box", 1, true) then hutBox = true end end
	check(gardenBox and not hutBox, "the window box is the test garden's (it stands on its outer sill)")
	for _, id in { "back_frame_west", "back_frame_east", "back_frame_head", "back_frame_rail" } do
		check(hutReplaced[id] == true, `the back frame's {id} is drawn by the window wall in the preserve too`)
	end
	local g, h = count(garden), count(hut)
	check(h < g, `fewer parts: {h} against the test garden's {g}`)
	print(`preserve: the sill's Decor: {h} parts (the test garden's {g})`)
end)

-- ---------------------------------------------------------------- ROBLOX-116: the ranger hut and its garden, walkable (World/Hut)
local Hut = require("../src/Shared/World/Hut")
local Meadow = require("../src/Shared/World/Meadow")
local Pond = require("../src/Shared/World/Pond")
local Garden = require("../src/Shared/World/Garden")
local Route = require("../src/Shared/Predator/RivalRoute")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Nursery = require("../src/Shared/Life/Nursery")
local Nature = require("../src/Shared/Life/Nature")
local LifeText = require("../src/Shared/UI/LifeText")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")

local SEAMS = 295 -- (ROBLOX-116: 69; ROBLOX-117: 78; ROBLOX-118: the ceiling's, the back room's, the eaves' and the new paths', 180; ROBLOX-119: the bench patch's and the meadow's, 64; ROBLOX-122: the mown path's, the boardwalk's and the pond's, 77)
local HUT_IDS = "sill,hut_window,hut_outer_sill,hut_desk,hut_board,hut_shelf,hut_chair,hut_door,"
	.. "hut_door_up,hut_doorway,hut_doorway_up,room_window,room_tv,room_games,room_sofa_w,room_sofa_e," -- (ROBLOX-118: the door's head, the doorway, the back room)
	.. "hut_floor_a,hut_floor_b,hut_floor_c,hut_floor_d,hut_floor_e,hut_floor_f,hut_floor_g,hut_floor_h,hut_floor_i,"
	.. "room_floor_a,room_floor_b,room_floor_c,room_floor_d,room_floor_e,room_floor_f,room_floor_g,room_floor_h,room_floor_i,"
	.. "hut_up_a,hut_up_b,hut_up_c,hut_up_d,hut_up_e,hut_up_f,hut_up_g,hut_up_h,hut_up_i,room_up_a,room_up_b,room_up_c,room_up_d,room_up_e,room_up_f,room_up_g,room_up_h,room_up_i,"
	.. "hut_wall_mid,hut_wall_w,hut_wall_e,hut_wall_x1,hut_wall_x2,hut_wall_x3,"
	.. "hut_eave_w2,hut_eave_w1,hut_eave_mid,hut_eave_e1,hut_eave_e2,hut_eave_x1,hut_eave_x2,hut_eave_x3,hut_eave_x4,"
	.. "hut_bench,hut_butt,garden_feeder,garden_pole,garden_a1,garden_a2,garden_a3,garden_a4,"
	.. "garden_b1,garden_b2,garden_b3,garden_b4,garden_c1,garden_c2,garden_c3,garden_c4,garden_d1,garden_d2,garden_d3,garden_d4,"
	.. "path_s1,path_s2,path_s3,path_s4,path_s5,path_e1,path_e2,path_e3,path_e4,path_e5,path_n3,path_n2,path_n1,path_e6," -- (ROBLOX-117/118: round the hut and the back room)
	.. "path_m1,path_m2,path_m3,path_m4," -- (ROBLOX-118: on toward the meadow)
	.. "bench_w,bench_e,bin,lamp_1,lamp_2,lamp_3,lamp_4,pad_a1,pad_a2,pad_a3,pad_b1,pad_b2,pad_b3,pad_c1,pad_c2,pad_c3," -- (ROBLOX-119: the bench patch)
	.. "meadow_a1,meadow_a2,meadow_a3,meadow_a4,meadow_a5,meadow_b1,meadow_b2,meadow_b3,meadow_b4,meadow_b5,meadow_c1,meadow_c2,meadow_c3,meadow_c4,meadow_c5,"
	.. "meadow_d1,meadow_d2,meadow_d3,meadow_d4,meadow_d5,meadow_e1,meadow_e2,meadow_e3,meadow_e4,meadow_e5," -- (ROBLOX-119: the meadow's edge)
	.. "cattail_1a,cattail_1b,cattail_2a,cattail_2b,walk_s1,walk_n1,walk_s2,walk_n2,walk_s3,walk_n3,walk_s4,walk_n4," -- (ROBLOX-122: the cattails up, the boardwalk)
	.. "deck_s1,deck_n1,deck_s2,deck_n2,deck_s3,deck_n3,deck_s4,deck_n4,pond_a1,pond_a2,pond_a3,pond_a4,pond_b1,pond_b2,pond_b3,pond_b4,pond_c1,pond_c2,pond_c3,pond_c4,"
	.. "mown_e1,mown_e2,mown_n1" -- The compact pond approach has three cells.

case("the hut's regions: the sill, the hut's inside, the way out and the garden's core, in priority order, each with its seed, spawn, retreats and pace", function()
	WorldMap.use("preserve")
	local ids = {}
	for _, r in WorldMap.regions() do if r.kind~="verge" then table.insert(ids, r.id) end end
	check(table.concat(ids, ",") == HUT_IDS, `in priority order ({table.concat(ids, ",")})`)
	local seeds: { [number]: boolean } = {}
	local okAll, homes = true, {}
	for _, r in WorldMap.regions() do
		local fine = r.seed == WorldMap.seed(WorldMap.SEED, r.id) and not seeds[r.seed] and r.bounds[1].X < r.bounds[2].X and r.bounds[1].Y < r.bounds[2].Y
			and r.bounds[1].Z < r.bounds[2].Z and WorldMap.at(r.spawn.pos + Vector3.new(0, 0.31, 0)) == r and r.clockScale > 0 and r.clockScale <= 1
			and (r.kind == "sill" or Hut.knows(r.kind) or Meadow.knows(r.kind) or Pond.knows(r.kind) or r.kind=="verge") and table.isfrozen(r) and table.isfrozen(r.neighbors)
		for _, t in r.retreats do
			if WorldMap.at((t.min + t.max) * 0.5) ~= r then fine = false end
			table.insert(homes, t.id)
		end
		for _, c in { r.bounds[1], r.bounds[2] } do if math.abs(c.X) > Preserve.LIMIT or math.abs(c.Y) > Preserve.LIMIT or math.abs(c.Z) > Preserve.LIMIT then fine = false end end
		if not fine then okAll = false; print("  region " .. r.id) end
		seeds[r.seed] = true
	end
	check(okAll, "each: its own seed, bounds with volume inside LIMIT, a body on its spawn in it, its retreats in it, a pace in (0, 1], frozen")
	table.sort(homes)
	check(table.concat(homes, ",") == "bench_slats,bin_lip,cattail_leaf,deck_gap,garden_a1_trough,garden_a3_stone,garden_d3_mulch,hut_board_gap,hut_desk_drawer,meadow_b2_leaf,pond_stone,room_sofa_under,sill_crevice",
		`the homes (ROBLOX-119: the bench's slats, the bin's lip, the meadow's curled leaf; ROBLOX-122: the boardwalk's gap, the flat stone, the cattail leaf): {table.concat(homes, ", ")}`)
	for _, id in homes do check(LifeText.HOMES[id] ~= nil, `{id} has its words`) end
	-- the inside keeps the sill's day, the garden the garden's; the night's hunters never come inside
	local inside, outside = true, true
	for _, r in WorldMap.regions() do
		local indoor = Nature.INDOORS[r.kind] == true
		if string.sub(r.id, 1, 9) == "hut_floor" or r.id == "hut_desk" or r.id == "hut_board" or r.id == "hut_shelf" or r.id == "hut_chair" or r.id == "hut_window"
			or string.sub(r.id, 1, 5) == "room_" or string.sub(r.id, 1, 7) == "hut_up_" or string.sub(r.id, 1, 11) == "hut_doorway" or r.id == "hut_door_up" then
			if not indoor or r.clockScale ~= 1.0 or Nature.exposed(true, r.kind, false) then inside = false end
		elseif string.sub(r.id, 1, 7) == "garden_" or r.id == "hut_bench" or r.id == "hut_butt" or Meadow.knows(r.kind) or Pond.knows(r.kind) then
			if indoor or r.clockScale ~= 0.33 or not Nature.exposed(true, r.kind, false) then outside = false end
		end
	end
	check(inside, "the hut's inside (ROBLOX-118: its ceiling, its doorway and its back room too) is indoors, at the sill's pace (1.0), and never exposed to the night")
	check(outside, "the bench, the butt and the garden (ROBLOX-119: and the meadow's edge and the bench patch) are outdoors at the garden's pace (0.33)")
	check(Hut.FLOOR == -70 and Hut.GROUND == -84.6 and Hut.WALL_TOP == 60 and Hut.DOOR_GAP == 1.5 and Hut.ROOM.x1 - Hut.ROOM.x0 == 293 and Hut.ROOM.z1 - Hut.ROOM.z0 == 243,
		"the floor 70 cm under the sill, the garden 84.6, the walls walkable 1.3 m up, the door's gap 1.5 cm, the room 2.93 by 2.43 m")
	local home = Preserve.HOME_RANGES[2]
	local lo, hi = Preserve.box(home.at[1] - home.size / 2, home.at[1] + home.size / 2, home.at[2] - home.size / 2, home.at[2] + home.size / 2, 0, 0)
	check(home.id == "hut_garden" and math.abs(lo.X - Hut.CORE.x0) < 1e-6 and math.abs(hi.X - Hut.CORE.x1) < 1e-6 and math.abs(lo.Z - Hut.CORE.z0) < 1e-6 and math.abs(hi.Z - Hut.CORE.z1) < 1e-6,
		"the garden's core is home range 2, 4 by 4 m in front of the north window")
end)

case("the hut's seams: each listed both ways along one line at both regions' bounds, and the rival's graphs joined along every one", function()
	WorldMap.use("preserve")
	local count, lines = 0, true
	for _, r in WorldMap.regions() do
		for _, n in r.neighbors do
			count += 1
			local other = WorldMap.region(n.id)
			local back = nil
			for _, m in (other :: any).neighbors do if m.id == r.id then back = m end end
			if back == nil or not same(back.a, n.a) or not same(back.b, n.b) then lines = false; print(`  {r.id} / {n.id}: not both ways`) end
			local mid = (n.a + n.b) * 0.5
			for _, x in { r, other :: any } do
				local blo, bhi = x.bounds[1], x.bounds[2]
				local q = Vector3.new(math.clamp(mid.X, blo.X, bhi.X), math.clamp(mid.Y, blo.Y, bhi.Y), math.clamp(mid.Z, blo.Z, bhi.Z))
				if (q - mid).Magnitude > 1.0 then lines = false; print(`  {r.id} / {n.id}: the seam is off {x.id}'s bounds`) end
			end
		end
	end
	check(count == 2 * SEAMS and lines, `{count / 2} seams, each both ways along one line at both regions' bounds`)
	local joined = true
	for _, region in WorldMap.regions() do
		local g = Route.graph(region.id)
		for _, n in region.neighbors do
			local edges, samples, off = 0, 0, 0
			for _, sm in g:allSeams() do
				if sm.edge.region == n.id then
					edges += 1
					for _, q in sm.edge.samples do
						samples += 1
						local ab = n.b - n.a
						local t0 = (q - n.a):Dot(ab) / ab:Dot(ab)
						if t0 < -1e-6 or t0 > 1 + 1e-6 or (n.a + ab * t0 - q).Magnitude > 0.06 then off += 1 end
					end
				end
			end
			if edges < 1 or samples < 3 or off > 0 then joined = false; print(`  {region.id} to {n.id}: {edges} edges, {samples} places, {off} off the line`) end
		end
	end
	check(joined, "every seam joins the two regions' graphs on its line (at least one edge and three places to cross)")
end)

case("the hut's boxes: the same forever, nothing overlapping anything, at most sixty a region, known surfaces and materials, inside LIMIT", function()
	WorldMap.use("preserve")
	local all = {}
	local okEach = true
	for _, r in WorldMap.regions() do
		local pieces = Region.pieces(r)
		if r.kind ~= "sill" then
			if Region.pieces(r) ~= pieces or #pieces > 60 or #pieces == 0 or not table.isfrozen(pieces) then okEach = false; print(`  {r.id}: {#pieces} boxes`) end
		end
		for _, p in pieces do
			table.insert(all, { r = r.id, p = p })
			if Surfaces[p.profile] == nil or not Materials.known((p :: any).material or "SmoothPlastic") then okEach = false; print("  surface " .. p.id) end
			if p.lo.X >= p.hi.X or p.lo.Y >= p.hi.Y or p.lo.Z >= p.hi.Z then okEach = false; print("  empty " .. p.id) end
		end
	end
	check(okEach, "each region's boxes: the same list each time, 1 to 60 of them (the sill's are the layout's), each a box with known surface and material")
	local E = 1e-6
	local overlaps, ids, dup = 0, {}, 0
	for i = 1, #all do
		local a = all[i].p
		if ids[a.id] then dup += 1 end
		ids[a.id] = true
		for j = i + 1, #all do
			local b = all[j].p
			if a.lo.X < b.hi.X - E and a.hi.X > b.lo.X + E and a.lo.Y < b.hi.Y - E and a.hi.Y > b.lo.Y + E and a.lo.Z < b.hi.Z - E and a.hi.Z > b.lo.Z + E
				and not (all[i].r == "sill" and all[j].r == "sill") then
				overlaps += 1
				print(`  {all[i].r} {a.id} overlaps {all[j].r} {b.id}`)
			end
		end
	end
	check(overlaps == 0 and dup == 0, `{#all} boxes in the preserve, none in another (the sill's crack is the layout's own), no id twice ({overlaps}, {dup})`)
	check(Region.drawnPieces(WorldMap.region("hut_window") :: any)[1] == "hut_window_glass" and #Region.drawnPieces(WorldMap.region("hut_desk") :: any) == 0,
		"the window's glass is drawn by the sill's Decor; the rest of the hut is its own look")
end)

case("the hut's looks: within their budgets at both tiers, the same each time, well made", function()
	WorldMap.use("preserve")
	local full, low, mfull, mlow, pfull, plow, pondCells = 0, 0, 0, 0, 0, 0, 0
	local okAll = true
	for _, r in WorldMap.regions() do
		if r.kind ~= "sill" then
			local list = Region.decor(r)
			local B = Region.budget(r.kind, "full")
			local f, l = #list, 0
			for _, d in list do
				if not d.full then l += 1 end
				if not Materials.known(d.material or "SmoothPlastic") or d.size.X <= 0 or d.size.Y <= 0 or d.size.Z <= 0 then okAll = false; print("  record " .. r.id .. " " .. d.id) end
			end
			if B == nil or f > B or l > (Region.budget(r.kind, "low") :: number) or Region.decor(r) ~= list then okAll = false; print(`  {r.id}: {f}/{l}`) end
			if Hut.knows(r.kind) then full += f; low += l elseif Pond.knows(r.kind) then pfull += f; plow += l; pondCells += 1 elseif r.kind~="verge" then mfull += f; mlow += l end
		end
	end
	check(okAll, "every region's look within its kind's budget at both tiers, the same list each time, known materials")
	print(`preserve: the hut's looks: {full} records at full, {low} at low; (ROBLOX-119) the meadow's and the bench patch's {mfull} at full, {mlow} at low`)
	-- (ROBLOX-118: 80, the paths round the back room and to the meadow each keep a tuft of the lawn's edge at the low tier)
	check(low <= 150, `the low tier draws little of the hut beyond its boxes ({low} records)`)
	-- (ROBLOX-119) the meadow's cells keep a mass a clump and the forb's colour at the low tier, the bench patch little more than its boxes
	check(mlow <= 130 and mfull > 2000, `the meadow and the bench patch: rich at full ({mfull} records), little at the low tier ({mlow})`)
	-- (ROBLOX-122) the pond's edge rich at full (its water, pads, stands, clumps, stones and the waterline), its corridor coarse; little at the low tier
	print(`preserve: (ROBLOX-122) the pond's, the boardwalk's and the mown path's looks: {pfull} at full, {plow} at low`)
	-- Count density rather than rewarding the 26 removed empty route cells.
	check(plow <= 200 and pondCells == 35 and pfull / pondCells > 30, `the compact pond and corridor: over 30 records per region ({pfull}/{pondCells}), little at the low tier ({plow})`)
end)

case("streaming: every hut region whole inside the target radius from anywhere on it, what is near inside the radius always sent, the way down there before it is taken", function()
	WorldMap.use("preserve")
	local RADIUS, LAG, TARGET = 96, 8, 160
	local function nearest(p: Vector3, lo: Vector3, hi: Vector3): number
		return (Vector3.new(math.clamp(p.X, lo.X, hi.X), math.clamp(p.Y, lo.Y, hi.Y), math.clamp(p.Z, lo.Z, hi.Z)) - p).Magnitude
	end
	local function reach(p: Vector3, piece: any): number
		return math.max(nearest(p, piece.lo, piece.hi), ((piece.lo + piece.hi) * 0.5 - p).Magnitude)
	end
	local function stands(r: any): { Vector3 }
		local out = {}
		for _, f in Route.graph(r.id):allFaces() do
			if not f.forbidden then for _, st in f.stand do table.insert(out, st + f.normal * 0.31) end end
		end
		return out
	end
	local whole, near, outside, worstAll = true, true, 0, 0
	for _, r in WorldMap.regions() do
		local worst, guaranteed = 0, 0
		for _, st in stands(r) do
			if WorldMap.at(st) == nil then outside += 1 end
			for _, piece in Region.pieces(r) do
				worst = math.max(worst, reach(st, piece))
				local d = nearest(st, piece.lo, piece.hi)
				if d <= 20 then guaranteed = math.max(guaranteed, d) end
			end
		end
		worstAll = math.max(worstAll, worst)
		if worst + LAG > TARGET then whole = false; print(`  {r.id}: its farthest box {worst}`) end
		if guaranteed + LAG > RADIUS then near = false end
	end
	print(`preserve: the hut's regions: from anywhere on one, its farthest box at most {string.format("%.1f", worstAll)} studs`)
	check(whole, "each region whole inside the target radius from anywhere on it")
	check(near, "what is near is inside the radius always sent")
	check(outside == 0, `every place a spider can stand is in a region ({outside} are not)`)
	-- crossing a seam: the boxes on the other side that meet the line are inside the radius always sent within ten studs of it
	local function toLine(p: Vector3, a: Vector3, b: Vector3): number
		local ab = b - a
		local t0 = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (a + ab * t0 - p).Magnitude
	end
	local crossing = true
	for _, r in WorldMap.regions() do
		for _, n in r.neighbors do
			local other = WorldMap.region(n.id) :: any
			local onto = 0
			for _, st in stands(r) do
				if toLine(st, n.a, n.b) <= 10 then
					for _, piece in Region.pieces(other) do
						for k = 0, 10 do
							if nearest(n.a + (n.b - n.a) * (k / 10), piece.lo, piece.hi) < 1e-6 then onto = math.max(onto, reach(st, piece)); break end
						end
					end
				end
			end
			if onto + LAG > RADIUS then crossing = false; print(`  {r.id} to {n.id}: {onto}`) end
		end
	end
	check(crossing, "crossing a seam, what the spider steps onto is there before it crosses")
	-- the line from the outer sill's front edge: the bench's seat below is inside the radius always sent from the spider and from its focus on the board
	local seat = Region.pieces(WorldMap.region("hut_bench") :: any)[1]
	local edgeWorst = 0
	for x = -30, 30, 2 do
		local at, focus = Vector3.new(x, 0.31, -22.31), Vector3.new(x, 0.31, -22.31 + LAG)
		local below = Vector3.new(x, seat.hi.Y, -22.31)
		edgeWorst = math.max(edgeWorst, (below - at).Magnitude, (below - focus).Magnitude)
	end
	check(seat.id == "hut_bench_seat" and seat.lo.Z <= -22.31 and seat.hi.Z >= -16 and edgeWorst <= RADIUS, `a line dropped from the outer sill's edge lands on the bench's seat, {string.format("%.1f", edgeWorst)} studs down from the focus`)
end)

case("the hut garden's life: its perches on its boxes' faces, its vents and hides on its ground, from the seed; the woodlice and ambient bugs where they belong", function()
	WorldMap.use("preserve")
	local function onFace(region: any, p: Vector3): boolean
		for _, piece in Region.pieces(region) do
			local lo, hi = piece.lo, piece.hi
			local inside = p.X >= lo.X - 1e-6 and p.X <= hi.X + 1e-6 and p.Y >= lo.Y - 1e-6 and p.Y <= hi.Y + 1e-6 and p.Z >= lo.Z - 1e-6 and p.Z <= hi.Z + 1e-6
			local onSurface = math.abs(p.X - lo.X) < 1e-6 or math.abs(p.X - hi.X) < 1e-6 or math.abs(p.Y - lo.Y) < 1e-6 or math.abs(p.Y - hi.Y) < 1e-6 or math.abs(p.Z - lo.Z) < 1e-6 or math.abs(p.Z - hi.Z) < 1e-6
			if inside and onSurface then return true end
		end
		return false
	end
	local counts = { prey = 0, kinds = 0, bugs = 0, ambient = 0 }
	local originalKinds=0
	local fine = true
	for _, r in WorldMap.regions() do
		local spec = Garden.prey(r)
		if spec ~= nil then
			counts.prey += 1
			if Garden.prey(r) ~= spec or spec.seed ~= r.seed or #spec.perches < 6 or #spec.vents < 2 then fine = false end
			local walkers = 0
			for _, p in spec.perches do
				if not onFace(r, p.position) or not WorldMap.inBounds(p.position + p.normal * 0.31, r.id) then fine = false; print("  perch " .. p.id) end
				if p.walker then walkers += 1 end
			end
			if r.id == "garden_c3" and walkers < 4 then fine = false; print("  the milkweed's aphids' perches") end
		end
		for _, k in Garden.bestiary(r) or {} do
			counts.kinds += 1
			if r.kind~="verge" and r.kind~="hut_path" and r.kind~="mown_path" and r.id~="garden_a3" then originalKinds+=1 end
			for _, p in k.perches do if not onFace(r, p.position) then fine = false; print("  " .. k.kind .. " perch " .. p.id) end end
			if #k.perches < 2 or #k.vents < 1 or k.target < 1 or k.low < 1 or k.low > k.target then fine = false end
		end
		local bugs = Garden.bugs(r)
		if bugs ~= nil then
			counts.bugs += 1
			for _, w in bugs.woodlice do if not WorldMap.inBounds(w.pos + Vector3.new(0, 0.3, 0), r.id) or math.abs(w.pos.Y - Hut.GROUND) > 1e-6 then fine = false end end
			if #bugs.woodlice < 2 or #bugs.hides < 2 then fine = false end
		end
		for _, a in Garden.ambient(r) or {} do
			counts.ambient += 1
			if #a.starts < 1 then fine = false; print("  ambient " .. a.kind .. " in " .. r.id) end
		end
	end
	check(fine and counts.prey == 2 and counts.kinds > 34 and originalKinds == 34 and counts.bugs == 2 and counts.ambient == 6,
		`gnats and aphids in 2 cells, the bestiary's kinds 10 times (ROBLOX-117: with the hoverflies on three cells' flowers, the fruit flies at the caddy, the moth at the lamp; ROBLOX-118: the caddy's flies in the back room, a moth at its window; ROBLOX-119: 25 with the meadow's leafhoppers, hoverflies, house flies and moths, the bin's flies and the lamp's moths; ROBLOX-120: 29 with the four crickets; ROBLOX-122: 34 with the pond's midges, mosquitoes and damselflies), woodlice in 2, ambient bugs in 4 (ROBLOX-119: the ants; ROBLOX-122: 6 with the water striders) (found {counts.prey}, {counts.kinds}, {counts.bugs}, {counts.ambient}), every perch on a face`)
	-- the milkweed as a plant the aphids and the ladybird walk: its nodes are the aphids' leaf perches
	local c3 = WorldMap.region("garden_c3") :: any
	local plants = Garden.plants(c3) :: any
	local name, of = Garden.plantOf("garden_c3_milkweed_leaf_1_top")
	check(plants ~= nil and plants.milkweed ~= nil and name == "milkweed" and of == plants, "the milkweed's leaves are a plant's nodes (Garden.plantOf)")
	local path = Garden.plantPath(plants.milkweed, "garden_c3_milkweed_leaf_1_top", "garden_c3_milkweed_leaf_4_top")
	check(path ~= nil and #path >= 4, "an aphid walks from one leaf to another by the stem")
	WorldMap.use("test_garden")
	check(Garden.plantOf("bed_a_dock_leaf_1_top") == "dock", "the test garden's plants are as they were")
end)

case("the nursery: the window shut until the spider is past its first moult and hard, then propped on a morning by a seeded hour that never rerolls", function()
	local seed = WorldMap.seed(WorldMap.SEED, "hut_window")
	local hours, inRange = {}, true
	for day = 1, 30 do
		local h = Nursery.arrival(seed, day)
		if h < Nursery.ARRIVAL[1] or h > Nursery.ARRIVAL[2] or h ~= Nursery.arrival(seed, day) then inRange = false end
		hours[h] = true
	end
	local distinct = 0
	for _ in hours do distinct += 1 end
	check(inRange and distinct >= 25, `the ranger comes between 7:30 and 9:30, the same hour for the same day, varying by day ({distinct} hours in 30 days)`)
	check(not Nursery.ready(0, false, false) and not Nursery.ready(1, true, false) and not Nursery.ready(1, false, true) and Nursery.ready(1, false, false) and Nursery.ready(3, false, false),
		"ready: past the first moult, not moulting, the cuticle hard")
	local h = Nursery.arrival(seed, 4)
	check(not Nursery.opens(seed, 1, false, false, 4, h - 0.01) and Nursery.opens(seed, 1, false, false, 4, h) and Nursery.opens(seed, 1, false, false, 4, 11.99)
		and not Nursery.opens(seed, 1, false, false, 4, 12) and not Nursery.opens(seed, 0, false, false, 4, 10) and not Nursery.opens(seed, 1, false, true, 4, 10),
		"propped from the ranger's hour until noon, for a ready spider only")
	-- the progress record keeps it, monotonic, optional (an old record has none)
	local _, clean = SaveProgress.sanitize({ notebook = { opened = {}, eye_seconds = 0 }, finished_main = false, settings = {}, settings_version = 1, hut_window = true })
	local problems = SaveProgress.sanitize({ notebook = { opened = {}, eye_seconds = 0 }, finished_main = false, settings = {}, settings_version = 1, hut_window = "yes" })
	local _, old = SaveProgress.sanitize({ notebook = { opened = {}, eye_seconds = 0 }, finished_main = false, settings = {}, settings_version = 1 })
	check(clean ~= nil and clean.hut_window == true and #problems == 1 and old ~= nil and old.hut_window == nil, "hut_window: kept when true, refused when not a boolean, absent in an old record")
	local merged = SaveProgress.merge(clean :: any, old :: any, 10, 20)
	check(merged.hut_window == true and not SaveProgress.same(clean :: any, old :: any), "a merge keeps the window open (it never shuts), and a record that has it differs")
	local snap = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, nil, {}, nil, true)
	local none = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, nil, {}, nil, nil)
	check(snap.hut_window == true and none.hut_window == nil, "the client's snapshot says it only when it is open")
end)

case("the plan in the hut and its garden: the region and its seams drawn, within the budget at both tiers", function()
	WorldMap.use("preserve")
	for _, tier in { "full", "low" } do
		local worst = 0
		local okAll = true
		for _, r in WorldMap.regions() do
			local p = r.spawn.pos + Vector3.new(0, 0.31, 0)
			local plan, total = LookPlan.plan(p, tier, r, nil)
			worst = math.max(worst, total)
			local need = LookPlan.required(p, r)
			for id in need do
				local reg = WorldMap.region(id) :: any
				if Region.streamed(reg.kind) and LookPlan.count(reg, "full") > 0 and plan[id] == nil then okAll = false; print(`  {r.id}: {id} not drawn`) end
			end
			if total > LookPlan.BUDGET[tier] then okAll = false; print(`  {r.id}: {total}`) end
		end
		check(okAll, `{tier}: from every region's spawn the region and its neighbours are drawn, within {LookPlan.BUDGET[tier]} (at most {worst})`)
		print(`preserve: the hut's regions at {tier}: at most {worst} parts`)
	end
end)

-- ---------------------------------------------------------------- ROBLOX-117: the garden rich at the spider's eye, the path round the east end, the garden's new life
case("the path round the hut's east end: from the door's gravel along the south wall, north past the east end and into the garden's path, gravel all the way", function()
	WorldMap.use("preserve")
	local chain = { "hut_door", "path_s1", "path_s2", "path_s3", "path_s4", "path_s5", "path_e1", "path_e2", "path_e3", "path_e4", "path_e5", "path_n3", "path_n2", "path_n1",
		"path_e6", "garden_b4", "garden_c4", "garden_d4", "garden_d3", "garden_d2", "path_m1", "path_m2", "path_m3", "path_m4" } -- (ROBLOX-118: round the back room, and on to the meadow)
	local linked = true
	for i = 1, #chain - 1 do
		local a = WorldMap.region(chain[i]) :: WorldMap.Region
		local found = false
		for _, n in a.neighbors do if n.id == chain[i + 1] then found = true end end
		if not found then linked = false; print(`  {chain[i]} does not meet {chain[i + 1]}`) end
	end
	check(linked, "the door's gravel, fourteen lengths of path round the hut and its back room, the garden's own cells and four lengths on toward the meadow meet seam to seam")
	local fine = true
	for _, w in Hut.WALK do
		local r = WorldMap.region(w.id) :: WorldMap.Region
		local pieces = Region.pieces(r)
		if r.kind ~= "hut_path" or r.clockScale ~= 0.33 or #pieces ~= 1 or pieces[1].material ~= "Pebble" or math.abs(pieces[1].hi.Y - Hut.GROUND) > 1e-6 then fine = false end
		if w.x0 < Hut.BUILDING.x1 + 9 and w.x1 > Hut.BUILDING.x0 - 9 and w.z1 > -25 and w.z0 < 287 - 1e-6 then fine = false; print("  " .. w.id .. " in the hut") end
	end
	check(fine, "each a length of gravel at the garden's ground, outdoors at the garden's pace, clear of the hut's and the back room's logs and base")
	check(Nature.exposed(true, "hut_path", false) == true, "the path is out in the night")
	-- the backdrop's gravel by the hut lies a hair under the walkable gravel, standing in for it
	local under = true
	for _, d in PreserveLook.records("ground", WorldMap.drawnZone("ground").seed) do
		if string.sub(d.id, 1, 4) == "Path" and d.material == "Pebble" and d.at.Y + d.size.Y / 2 > Hut.GROUND - 0.1 and d.at.Z > -500 then under = false; print("  " .. d.id) end
	end
	check(under, "the backdrop's gravel by the hut is under the walkable gravel")
end)

case("the patches: the near detail of the garden and the path, drawn only near the spider, within their budgets, deterministic, with the dew", function()
	WorldMap.use("preserve")
	local patches = WorldMap.patches()
	local cells, paths = 0, 0
	for _, r in WorldMap.regions() do
		if r.kind == "garden_bed" then cells += 1 elseif r.kind == "hut_path" then paths += 1 end
	end
	-- (ROBLOX-119: and the meadow's 25 cells and the bench patch's 9: 544 more; ROBLOX-122: and the pond's twelve cells, 160 more)
	check(#patches >= cells * 16 + 34 * 16 + 8 * 16 + 4 * 8 and #patches < 1200, `{#patches} patches over the garden's {cells} cells, the path's {paths} lengths, the meadow's and the bench patch's cells`)
	local fine, dews, worstFull, worstLow = true, 0, 0, 0
	local B = Region.budget("patch", "full") :: number
	for _, p in patches do
		local parent = (Hut.patchParent(p) or Meadow.patchParent(p) or Pond.patchParent(p)) :: any
		local plo, phi = p.bounds[1], p.bounds[2]
		if parent == nil or plo.X < parent.bounds[1].X - 1e-6 or phi.X > parent.bounds[2].X + 1e-6 or plo.Z < parent.bounds[1].Z - 1e-6 or phi.Z > parent.bounds[2].Z + 1e-6 then fine = false end
		if WorldMap.patch(p.id) ~= p or WorldMap.region(p.id) ~= nil or WorldMap.at(p.origin) == p then fine = false end
		local list = Region.decor(p)
		local low = 0
		for _, d in list do
			if not d.full then low += 1 end
			if not Materials.known(d.material or "SmoothPlastic") then fine = false end
			if d.dew ~= nil then
				dews += 1
				if d.group ~= "Dew" or not d.full or d.dew < 0 or d.dew >= 1 or (d.transparency or 0) <= 0 then fine = false end
			end
		end
		worstFull, worstLow = math.max(worstFull, #list), math.max(worstLow, low)
		if #list > B or low > (Region.budget("patch", "low") :: number) or Region.decor(p) ~= list then fine = false end
	end
	check(fine, "each inside its region's footprint, its own look within the patch's budget at both tiers, the same list each time, known materials, its dew in the Dew group")
	check(dews > 100, `the morning's dew on the blades and the chips ({dews} drops)`)
	print(`preserve: the patches: {#patches}, at most {worstFull} records at full and {worstLow} at low`)
	-- the plan: patches near the spider only, at the tier's detail close, thinner a little further at the full tier, within their share
	for _, tier in { "full", "low" } do
		local at = Vector3.new(22, Hut.GROUND + 10 + 0.31, -246) -- (in the pollinator bed's mulch by the milkweed)
		local plan, total = LookPlan.plan(at, tier, WorldMap.at(at), nil)
		local n, parts, far = 0, 0, 0
		for id, level in plan do
			local p = WorldMap.patch(id)
			if p ~= nil then
				n += 1
				parts += LookPlan.count(p, level, tier)
				local d = LookPlan.distance(p, at)
				if d > (if tier == "low" then LookPlan.PATCH_RADIUS.low else LookPlan.PATCH_RING) then far += 1 end
				if tier == "low" and level ~= "low" then far += 1 end
				if tier == "full" and level == "full" and d > LookPlan.PATCH_RADIUS.full then far += 1 end
			end
		end
		check(n > 0 and far == 0 and parts <= LookPlan.PATCH_SHARE[tier] and total <= LookPlan.BUDGET[tier], `{tier}: {n} patches drawn ({parts} parts), none beyond their radius, within the share and the budget ({total})`)
		print(`preserve: in the mulch at {tier}: {n} patches, {parts} parts of them, {total} in all`)
	end
	local inHut = LookPlan.plan(Vector3.new(0, Hut.FLOOR + 0.31, 120), "full", WorldMap.region("hut_floor_e"), nil)
	local none = true
	for id in inHut do if WorldMap.patch(id) ~= nil then none = false end end
	check(none, "in the hut, no patch is drawn")
	check(#WorldMap.patches() == #patches and (function() WorldMap.use("test_garden"); local z = #WorldMap.patches(); WorldMap.use("preserve"); return z == 0 end)(), "the test garden has none")
end)

case("the garden's plants drawn whole over their boxes, a second of each kind, and the bed's cells within their budgets", function()
	WorldMap.use("preserve")
	local fine = true
	for id, more in Hut.MORE_PLANTS do
		local r = WorldMap.region(id) :: WorldMap.Region
		local byId: { [string]: any } = {}
		for _, p in Region.pieces(r) do byId[p.id] = p end
		local stem = byId[`{id}_{more.kind}2_stem`]
		if stem == nil or not WorldMap.inBounds(stem.hi, id) then fine = false; print("  " .. id .. " second " .. more.kind) end
		local look = Region.decor(r)
		local leaves = 0
		for _, d in look do if string.sub(d.id, 1, 5) == "Leaf2" or string.sub(d.id, 1, 4) == "Ray2" or string.sub(d.id, 1, 5) == "Tube2" or string.sub(d.id, 1, 6) == "Spray2" or string.sub(d.id, 1, 8) == "Floret2_" then leaves += 1 end end
		if leaves < 5 then fine = false; print(`  {id}: the second plant drawn with {leaves}`) end
	end
	check(fine, "milkweed, coneflower, bee balm and goldenrod each a second, walkable, inside its cell, and drawn")
	local c3 = Region.decor(WorldMap.region("garden_c3") :: any)
	local florets, meshLeaves, midribs = 0, 0, 0
	for _, d in c3 do
		if string.sub(d.id, 1, 6) == "Floret" then florets += 1 end
		if string.sub(d.id, 1, 4) == "Leaf" and d.shape == "Mesh:milkweed_leaf" then meshLeaves += 1 end
		if string.sub(d.id, 1, 6) == "Midrib" then midribs += 1 end
	end
	-- (ROBLOX-126: the leaves are Chet's mesh, its midrib and veins in it, so no separate midrib)
	check(florets >= 30 and meshLeaves >= 12 and midribs == 0, `the milkweed's umbels ({florets} florets) and its leaves the mesh leaf ({meshLeaves}, {midribs} separate midribs)`)
	local rival, mate = Hut.CREATURES.rival, Hut.CREATURES.mate
	check(WorldMap.inBounds(rival.at, rival.region) and WorldMap.inBounds(mate.at, mate.region) and Hut.ROAM[rival.region] and Hut.ROAM[mate.region]
		and WorldMap.inRetreat(rival.at) == nil and WorldMap.inRetreat(mate.at) == nil, "the rival and the mate come into the garden on its path, in cells of their roam")
	local roam = 0
	for id in Hut.ROAM do
		roam += 1
		if not string.find(id, "^garden_") then fine = false end
	end
	check(roam == 16, "they roam the garden's sixteen cells and never the hut")
end)

-- ---------------------------------------------------------------- ROBLOX-118: the ceiling, the back room, the eaves, the cat, the meadow path
local Cat = require("../src/Shared/Predator/Cat")
local CatPose = require("../src/Shared/Rig/CatPose")
local CatText = require("../src/Shared/UI/CatText")

case("the ceiling and the walls to it, inside and out: nowhere a spider can climb is out of every region (the put-back above 1.3 m is gone)", function()
	WorldMap.use("preserve")
	local CE = Hut.CEIL
	local holes = {}
	local function at(p: Vector3, what: string)
		if WorldMap.at(p) == nil then table.insert(holes, `{what} {p}`) end
	end
	-- up every wall's lining, both rooms, from the floor to the ceiling, and over the whole ceiling's underside
	for _, room in { { x0 = Hut.ROOM.x0, x1 = Hut.ROOM.x1 }, { x0 = Hut.BACK.x0, x1 = Hut.BACK.x1 } } do
		for y = -69, CE - 1, 5 do
			for z = 20, 250, 23 do
				at(Vector3.new(room.x0 + 0.31, y, z), "west wall")
				at(Vector3.new(room.x1 - 0.31, y, z), "east wall")
			end
			for x = room.x0 + 5, room.x1 - 5, 24 do
				at(Vector3.new(x, y, Hut.ROOM.z0 + 0.31), "north wall")
				at(Vector3.new(x, y, Hut.ROOM.z1 - 0.31), "south wall")
			end
		end
		for x = room.x0 + 2, room.x1 - 2, 9 do
			for z = 14, 254, 9 do at(Vector3.new(x, CE - 0.31, z), "ceiling") end
		end
	end
	-- the north face outside from the logs' foot to the soffit, and along the gutter from end to end
	for x = -170, 470, 10 do
		for y = -60, Hut.EAVE.soffit - 1, 6 do at(Vector3.new(x, y, -16.31), "north face") end
		at(Vector3.new(x, Hut.EAVE.soffit - 0.31, -30), "soffit")
	end
	for x = Hut.EAVE.x0 + 1, Hut.EAVE.x1 - 1, 7 do at(Vector3.new(x, Hut.EAVE.gutter.floor + Hut.EAVE.gutter.thick + 0.31, -54), "gutter") end
	check(#holes == 0, `every wall to the ceiling and the north face to the gutter is in a region ({#holes} holes: {table.concat(holes, "; ", 1, math.min(#holes, 4))})`)
	-- the ceiling's boards cover both rooms, on joists 60 cm apart
	local area, joists = 0, 0
	for _, r in WorldMap.regions() do
		if r.kind == "hut_upper" then
			for _, p in Region.pieces(r) do
				if string.sub(p.id, -8) == "_ceiling" then area += (p.hi.X - p.lo.X) * (p.hi.Z - p.lo.Z) end
				if string.find(p.id, "_joist_", 1, true) then joists += 1; if math.abs(p.hi.Y - CE) > 1e-6 or p.hi.Y - p.lo.Y ~= Hut.JOISTS.d then joists -= 100 end end
			end
		end
	end
	local want = (Hut.ROOM.x1 - Hut.ROOM.x0 + Hut.BACK.x1 - Hut.BACK.x0) * (Hut.ROOM.z1 - Hut.ROOM.z0)
	check(math.abs(area - want) < 1e-3 and joists == 24, `the ceiling's boards over both rooms ({area} of {want} square studs), 24 joist lengths ({joists}) 2.2 m over the floor`)
	check(CE - Hut.FLOOR == 220 and Hut.EAVE.soffit - Preserve.GROUND_Y == 218, "the ceiling 2.2 m over the floor; the soffit 2.18 m over the ground outside")
	check(Hut.UPPER.hut_up_a ~= nil and #Region.decor(WorldMap.region("hut_up_a") :: any) >= 20, "the house spider's web drawn in the hut's north-west ceiling corner")
end)

case("the volunteers' back room: through the doorway, its furniture at true size, the gap under the sofa a home, the caddy's flies and a moth at its window", function()
	WorldMap.use("preserve")
	local doorway = WorldMap.region("hut_doorway") :: any
	local floorI, roomG = WorldMap.region("hut_floor_i") :: any, WorldMap.region("room_floor_g") :: any
	local linked = 0
	for _, n in doorway.neighbors do if n.id == "hut_floor_i" or n.id == "room_floor_g" then linked += 1 end end
	check(linked == 2 and floorI ~= nil and roomG ~= nil, "the doorway joins the hut's floor and the back room's")
	local DW = Hut.DOORWAY
	check(DW.z1 - DW.z0 == 70 and DW.head - Hut.FLOOR == 205, "the doorway 70 cm wide and 2.05 m high")
	local S0 = Hut.SOFA
	check(S0.x1 - S0.x0 == 200 and S0.seat - Hut.FLOOR == 45 and S0.back - Hut.FLOOR == 85 and S0.armTop - Hut.FLOOR == 70 and S0.leg - Hut.FLOOR == 8,
		"the sofa 2 m long, its seat 45 cm, back 85 cm, arms 70 cm, on 8 cm legs")
	local Sc = Hut.TV.screen
	check(Sc.x1 - Sc.x0 == 73 and Sc.y1 - Sc.y0 == 43 and Hut.GAMES.top - Hut.FLOOR == 120 and Hut.HEATER.top - Hut.FLOOR == 63, "a 32-inch screen (73 by 43 cm), the games' shelf 1.2 m, the radiator 63 cm")
	check(Hut.ROOM_WINDOW.glass - Hut.ROOM_WINDOW.sill == 30 and Hut.BACK.x1 - Hut.BACK.x0 == 270, "the window's sill 30 cm deep (a cat sits on it), the room 2.7 m across")
	check(WorldMap.inRetreat(Vector3.new(295, Hut.FLOOR + 0.31, 215)) == "room_sofa_under" and Cat.under(Vector3.new(295, Hut.FLOOR + 0.31, 215)), "the gap under the sofa is a home, and out of the cat's reach")
	local tv, controller = false, false
	for _, p in Region.pieces(WorldMap.region("room_tv") :: any) do if p.id == "room_tv_console" then tv = true end end
	for _, p in Region.pieces(WorldMap.region("room_sofa_w") :: any) do if p.id == "room_sofa_w_controller" and math.abs(p.lo.Y - S0.seat) < 1e-6 then controller = true end end
	check(tv and controller, "the games console on the unit's shelf, its controller on the sofa's cushion")
	local cables = 0
	for _, id in { "room_floor_a", "room_floor_f" } do for _, p in Region.pieces(WorldMap.region(id) :: any) do if string.find(p.id, "cable", 1, true) or string.find(p.id, "cord", 1, true) then cables += 1 end end end
	check(cables >= 5, `the cables along the skirting to their sockets ({cables})`)
	local fruit, moth = nil, nil
	for _, k in Garden.bestiary(roomG) or {} do if k.kind == "fruit_fly" then fruit = k end end
	for _, k in Garden.bestiary(WorldMap.region("room_window") :: any) or {} do if k.kind == "moth" then moth = k end end
	check(fruit ~= nil and moth ~= nil and moth.dusk ~= nil, "fruit flies by the doorway from the caddy, a moth at the window from dusk")
	check(Nature.INDOORS.room_floor and Nature.INDOORS.hut_upper and not Nature.INDOORS.hut_eave, "the back room and the ceiling indoors, the eaves out")
end)

case("the meadow path: the garden's own path goes on north out of the core toward the meadow, gravel at the garden's ground", function()
	WorldMap.use("preserve")
	local ok = true
	for i = 1, 4 do
		local r = WorldMap.region("path_m" .. i) :: any
		if r == nil or r.kind ~= "hut_path" or r.bounds[2].X - r.bounds[1].X ~= 60 then ok = false end
	end
	local last = WorldMap.region("path_m4") :: any
	local _, zm = Preserve.metres(Vector3.new(0, 0, last.bounds[1].Z))
	check(ok and math.abs(zm - 10) < 1e-6, `four lengths 60 cm wide to z {zm} m, where the compact meadow begins`)
end)

case("the cat's day: seeded, the same for the same day, every day from the sofa to the sofa, its stops on its spots and its walks on the floor's ways", function()
	local seed = WorldMap.seed(WorldMap.SEED, "cat")
	local fine, kinds, rested = true, {}, 0
	for day = 1, 12 do
		local plan = Cat.plan(seed, day)
		if plan ~= Cat.plan(seed, day) then fine = false end
		if plan[1].t0 ~= 0 or plan[#plan].t1 ~= 24 or plan[1].spot ~= "sofa" or plan[#plan].spot ~= "sofa" then fine = false end
		for i, s in plan do
			if i > 1 and math.abs(s.t0 - plan[i - 1].t1) > 1e-9 then fine = false end
			if s.t1 < s.t0 then fine = false end
			kinds[s.kind] = true
			if s.kind == "rest" and s.t0 < 17 and s.t1 > 8.5 then rested += math.min(s.t1, 17) - math.max(s.t0, 8.5) end
		end
		-- a place every few game minutes: in a room (or the doorway), never inside the furniture it walks round
		for h = 0, 23.99, 0.05 do
			local p = Cat.at(seed, day, h)
			local same = Cat.at(seed, day, h)
			if p.pos ~= same.pos or Cat.roomOf(p.pos) == nil then fine = false; print(`  day {day} at {h}: {p.pos}`) end
			if p.pose == "walk" and not Cat.free(p.pos.X, p.pos.Z) and (p.pos - Cat.NODES.rug).Magnitude > 1 then
				local onNode = false
				for _, n in Cat.NODES do if (n - p.pos).Magnitude < 12 then onNode = true end end
				if not onNode then fine = false; print(`  day {day} at {h}: walking through furniture at {p.pos}`) end
			end
		end
	end
	check(fine, "twelve days: contiguous from 0 to 24 hours, the sofa first and last, the same place for the same hour (a return to a rest finds it where it was), always in its rooms")
	check(kinds.rest and kinds.walk and kinds.sit and kinds.eat and kinds.groom, "it rests, walks, sits, eats and grooms")
	check(rested / (12 * 8.5) > 0.4, `it sleeps much of the day ({math.floor(100 * rested / (12 * 8.5))}% of 8:30 to 17:00 resting)`)
	check(Cat.plan(seed, 1) ~= Cat.plan(seed, 2) and Cat.plan(seed, 1)[2].t0 ~= Cat.plan(seed, 2)[2].t0, "another day, another schedule")
end)

case("the cat's reactions: a moving thing near it and awake, a pat in reach; still, hidden, out of reach or in the other room, it loses interest; the rules decide the pat", function()
	local seed = WorldMap.seed(WorldMap.SEED, "cat")
	-- a stop of its first day on the floor where it is awake
	local stop = nil
	for _, s in Cat.plan(seed, 1) do if (s.spot == "rug" or s.spot == "door" or s.spot == "bowls") and s.kind ~= "walk" then stop = s; break end end
	assert(stop ~= nil, "no stop on the floor")
	local h = (stop.t0 + stop.t1) / 2
	local function trial(gentle: boolean, spider: (any, number) -> any, seconds: number): (any, { [string]: number })
		local cat = Cat.new(seed)
		cat.gentle = gentle
		cat:step(1 / 60, 1, h, nil)
		local seen: { [string]: number } = {}
		for i = 1, math.floor(seconds * 60) do
			cat:step(1 / 60, 1, h, spider(cat, i))
			for _, s in cat:drainSignals() do seen[s.kind] = (seen[s.kind] or 0) + 1 end
		end
		return cat, seen
	end
	local function near(cat: any, i: number, dy: number?, speed: number?): any
		local c = Cat.chest(cat) + cat.heading * 8
		return { pos = Vector3.new(c.X + math.sin(i * 0.2), cat.surface + 0.31 + (dy or 0), c.Z), speed = speed or 2, hidden = false }
	end
	local _, s1 = trial(false, function(cat, i) return near(cat, i) end, 8)
	check(s1.noticed == 1 and s1.struck == 1, "standard rules: it notices a spider moving in front of it and its pat lands: a death")
	local _, s2 = trial(true, function(cat, i) return near(cat, i) end, 8)
	check(s2.noticed == 1 and s2.nudged == 1 and (s2.struck or 0) == 0, "gentle rules: the same pat only knocks the spider aside")
	local _, s3 = trial(false, function(cat, i) return near(cat, i, nil, 0) end, 8)
	check((s3.noticed or 0) == 0, "a spider keeping still is not noticed")
	local c4, s4 = trial(false, function(cat, i) local p = near(cat, i); p.hidden = i > 30; return p end, 8)
	check(s4.noticed == 1 and (s4.struck or 0) == 0 and s4.gave_up == 1 and c4.cooldown > 0, "one that gets into a gap: it gives up")
	local _, s5 = trial(false, function(cat, i) return near(cat, i, if i > 30 then 70 else 0) end, 10)
	check(s5.noticed == 1 and (s5.struck or 0) == 0 and s5.gave_up == 1, "one that gets up out of its reach (70 cm over its floor): it stares, then gives up")
	local _, s6 = trial(false, function(cat, i) local p = near(cat, i); if i > 30 then p.speed = 0 end; return p end, 8)
	check(s6.noticed == 1 and (s6.struck or 0) == 0 and s6.gave_up == 1, "one that keeps still once seen: it loses interest")
	local _, s7 = trial(false, function(cat, i) return { pos = Vector3.new(cat.pos.X + 60, -69.69, cat.pos.Z) * Vector3.new(1, 1, 1) + Vector3.new(if Cat.roomOf(cat.pos) == "hut" then 400 else -400, 0, 0), speed = 2, hidden = false } end, 4)
	check((s7.noticed or 0) == 0, "one in the other room is not noticed")
	-- a sleeping cat notices nothing
	local sleepH = nil
	for _, s in Cat.plan(seed, 1) do if s.kind == "rest" and s.t1 - s.t0 > 1 then sleepH = s.t0 + 0.8; break end end
	local sleeper = Cat.new(seed)
	sleeper:step(1 / 60, 1, sleepH :: number, nil)
	local seen = 0
	for i = 1, 300 do
		local c = Cat.chest(sleeper) + sleeper.heading * 8
		sleeper:step(1 / 60, 1, sleepH :: number, { pos = Vector3.new(c.X, sleeper.surface + 0.31, c.Z), speed = 2, hidden = false })
		seen += #sleeper:drainSignals()
		local _ = i
	end
	check(sleeper.pose == "sleep" and seen == 0, "asleep, it notices nothing")
	-- heard first: the bell while it walks, from metres off; the purr close, as it settles
	local walkH = nil
	for _, s in Cat.plan(seed, 1) do if s.kind == "walk" and s.t1 - s.t0 > 0.02 then walkH = (s.t0 + s.t1) / 2; break end end
	local walker = Cat.new(seed)
	walker:step(1 / 60, 1, walkH :: number, nil)
	local bell = walker:sound(walker.pos + Vector3.new(0, 0, 200))
	local far = walker:sound(walker.pos + Vector3.new(0, 0, 600))
	check(walker.pose == "walk" and bell > 0 and far == 0, `the bell heard 2 m off while it walks ({string.format("%.2f", bell)}), not 6 m off`)
	check(CatText.caption(bell, 0, "ahead", true) ~= nil and string.find((CatText.caption(bell, 0, "ahead", true) :: any).text, "bell", 1, true) ~= nil
		and CatText.caption(0, 0.5, "left", false) ~= nil and CatText.caption(0, 0, "left", false) == nil, "its captions: the bell, the purr, nothing when silent")
	-- the record
	check(#Cat.problems(Cat.defaultRecord()) == 0 and #Cat.problems({ notices = 1.5, pats = 0, swats = 0, last_swat_day = 0 }) == 1 and #Cat.problems(7) == 1, "its record: counts only")
end)

case("the cat drawn: a domestic cat at true size in every pose, the same parts in each, within its budget", function()
	local poses = { "walk", "jump", "sit", "rest", "sleep", "eat", "groom", "watch", "stalk", "crouch", "swat" }
	local first = CatPose.parts({ pose = "walk", t = 1.1, speed = 60 })
	local same, low = true, 0
	for _, p in first do if not p.full then low += 1 end end
	for _, pose in poses do
		local list = CatPose.parts({ pose = pose, t = 2.3, speed = 40, look = Vector3.new(10, 5, -40), paw = Vector3.new(3, 2, -34), swat = 0.5 })
		if #list ~= #first then same = false end
		for i, p in list do if p.name ~= first[i].name or p.size.X <= 0 then same = false end end
	end
	check(same and #first <= 70 and low <= 45, `{#first} parts in every pose, the same names; {low} at the low tier`)
	-- measured standing: the shoulder's top, the length from the nose's tip to the hips' back, the head's width
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local stand = CatPose.parts({ pose = "walk", t = 0, speed = 0 })
	local shoulder, nose, rump, headW = 0, 0, 0, 0
	for _, p in stand do
		local c = p.cf.Position
		if p.name == "Chest" then shoulder = c.Y + p.size.Y / 2 end
		if p.name == "Nose" then nose = c.Z - p.size.Z / 2 end
		if p.name == "Hips" then rump = c.Z + p.size.Z / 2 end
		if p.name == "Head" then headW = p.size.X end
		lo, hi = lo:Min(c), hi:Max(c)
	end
	check(shoulder >= 22 and shoulder <= 26 and rump - nose >= 42 and rump - nose <= 48.5 and headW >= 8.5 and headW <= 10.5,
		string.format("standing: %.1f cm at the shoulder, %.1f cm from the nose to the root of the tail, its head %.1f cm across (a house cat: 23 to 25, about 46)", shoulder, rump - nose, headW))
	-- it breathes and blinks: the chest swells; sitting, now and then the lids come down
	local a, b = CatPose.parts({ pose = "sit", t = 0.0 }), CatPose.parts({ pose = "sit", t = 0.6 })
	local shut = false
	for t = 0, 30, 0.05 do
		for _, p in CatPose.parts({ pose = "sit", t = t }) do if p.name == "LidL" and p.size.Y > 2 then shut = true end end
	end
	check(a[1].size.X ~= b[1].size.X and shut, "it breathes (the chest's size moves) and gives a slow blink sitting")
	check(CatText.LINE ~= "" and string.find(CatText.SUB, "keeping still", 1, true) ~= nil and CatText.CAUSE == "cat", "its death card says what would have saved the spider")
end)

-- ---------------------------------------------------------------- ROBLOX-119: the bench patch and the meadow's edge, their life and the crab spiders
local CrabSpider = require("../src/Shared/Predator/CrabSpider")
local CrabText = require("../src/Shared/UI/CrabText")
local Ant = require("../src/Shared/Prey/Ant")
local PreyText = require("../src/Shared/UI/PreyText")

case("the bench patch and the meadow's edge: home ranges 8 and 3 where the garden's path comes out, walkable at true size, seam to seam", function()
	WorldMap.use("preserve")
	local H3, H8 = Preserve.HOME_RANGES[3], Preserve.HOME_RANGES[8]
	local function box(h: any): (Vector3, Vector3)
		return Preserve.box(h.at[1] - h.size / 2, h.at[1] + h.size / 2, h.at[2] - h.size / 2, h.at[2] + h.size / 2, 0, 0)
	end
	local lo3, hi3 = box(H3)
	local lo8, hi8 = box(H8)
	local K, D = Meadow.CORE, Meadow.PAD
	check(H3.id == "meadow" and math.abs(lo3.X - K.x0) < 1e-6 and math.abs(hi3.X - K.x1) < 1e-6 and math.abs(lo3.Z - K.z0) < 1e-6 and math.abs(hi3.Z - K.z1) < 1e-6,
		"the meadow's edge is home range 3, 5 by 5 m (x 42.65..47.65, z 16..21 m)")
	check(H8.id == "bench" and math.abs(lo8.X - D.x0) < 1e-6 and math.abs(hi8.X - D.x1) < 1e-6 and math.abs(lo8.Z - D.z0) < 1e-6 and math.abs(hi8.Z - D.z1) < 1e-6
		and D.z1 == -516 and K.z1 == D.z0, "the bench patch is home range 8, 3 by 3 m, from the path's end at z 13 m to the meadow's edge at 16 m")
	-- the way: out of the garden, up the path, across the patch and into the meadow to its far side
	local chain = { "garden_d2", "path_m1", "path_m2", "path_m3", "path_m4", "pad_a2", "pad_b2", "pad_c2", "meadow_a3", "meadow_b3", "meadow_c3", "meadow_d3", "meadow_e3" }
	local linked = true
	for i = 1, #chain - 1 do
		local a = WorldMap.region(chain[i]) :: WorldMap.Region
		local found = false
		for _, n in a.neighbors do if n.id == chain[i + 1] then found = true end end
		if not found then linked = false; print(`  {chain[i]} does not meet {chain[i + 1]}`) end
	end
	check(linked, "from the hut garden up the gravel path, across the bench patch and through the meadow, seam to seam")
	local ids = {}
	for _, r in WorldMap.regions() do if Meadow.knows(r.kind) then table.insert(ids, r.id) end end
	check(#ids == 41, `41 regions: the bench in two, the bin, the lamppost in four, nine cells of the pad and twenty-five of the meadow ({#ids})`)
	-- true sizes
	local function piecesOf(id: string): { [string]: any }
		local out = {}
		for _, p in Region.pieces(WorldMap.region(id) :: any) do out[p.id] = p end
		return out
	end
	local bw, bin, l4, b3 = piecesOf("bench_w"), piecesOf("bin"), piecesOf("lamp_4"), piecesOf("pad_b3")
	local SL = Meadow.SLAB.top
	check(math.abs(bw.bench_w_slat_1.hi.Y - SL - 45) < 1e-6 and bw.bench_w_slat_2.lo.Z - bw.bench_w_slat_3.hi.Z >= 1.5 and bw.bench_w_back_3.hi.Y - SL >= 75,
		"the bench: its seat 45 cm over the slab, slats with a gap a spider fits in, its back to about 80 cm")
	check(math.abs(bin.bin_lid.hi.Y - SL - 88) < 1e-6 and math.abs(bin.bin_base.lo.Y - SL - 1.4) < 1e-6 and bin.bin_can ~= nil and bin.bin_packet ~= nil,
		"the bin: 88 cm to its lid, its base on feet 1.4 cm over the slab, a can and a crisp packet by it")
	check(l4.lamp_glass.lo.Y - Meadow.GROUND >= 340 and l4.lamp_cap ~= nil, "the lamppost's lantern 3.4 m and more over the ground")
	local bars, slot = 0, math.huge
	local list = {}
	for id, p in b3 do if string.find(id, "_bar_", 1, true) then bars += 1; table.insert(list, p) end end
	table.sort(list, function(a, b) return a.lo.Z < b.lo.Z end)
	for i = 1, #list - 1 do slot = math.min(slot, list[i + 1].lo.Z - list[i].hi.Z) end
	check(bars == 6 and slot >= 1.9 and b3.pad_b3_pit_floor.hi.Y <= Meadow.GROUND - 10, string.format("the drain grate: six bars with slots %.1f cm wide over a pit 12 cm deep", slot))
	-- the meadow: every cell's forb and clumps as its plan says, the grasses at true height, set well in from the cell's edges (so a cell is whole in the radius)
	local fine, tallest, littleMax, plants = true, 0, 0, 0
	for _, r in WorldMap.regions() do
		if r.kind == "meadow" then
			local plan = Meadow.PLAN[string.sub(r.id, 8)]
			local byId = piecesOf(r.id)
			if plan.forb ~= nil and byId[`{r.id}_{plan.forb}_head`] == nil then fine = false; print("  no " .. plan.forb .. " in " .. r.id) end
			for k, kind in plan.clumps do
				for i = 1, 4 do
					local culm = byId[`{r.id}_{kind}{k}_culm_{i}`]
					if culm == nil then fine = false; continue end
					local h = culm.hi.Y - Meadow.GROUND
					if kind == "big" then tallest = math.max(tallest, h) else littleMax = math.max(littleMax, h) end
					if culm.lo.X < r.bounds[1].X + 10 or culm.hi.X > r.bounds[2].X - 10 or culm.lo.Z < r.bounds[1].Z + 10 or culm.hi.Z > r.bounds[2].Z - 10 then fine = false; print("  " .. culm.id .. " by the edge") end
				end
				plants += 1
			end
			if plan.forb then plants += 1 end
		end
	end
	check(fine and tallest >= 95 and tallest <= 115 and littleMax >= 45 and littleMax <= 70, string.format("%d plants: big bluestem to %.0f cm, little bluestem to %.0f cm, every forb and clump of the plan, well in from the edges", plants, tallest, littleMax))
	-- the homes: under the curled leaf, between the slats, under the bin's lip
	local leaf = WorldMap.retreat("meadow_b2_leaf") :: any
	local slats = WorldMap.retreat("bench_slats") :: any
	local lip = WorldMap.retreat("bin_lip") :: any
	check(leaf ~= nil and slats ~= nil and lip ~= nil and WorldMap.inRetreat((leaf.min + leaf.max) * 0.5) == "meadow_b2_leaf" and WorldMap.inRetreat((lip.min + lip.max) * 0.5) == "bin_lip"
		and WorldMap.inRetreat((slats.min + slats.max) * 0.5) == "bench_slats" and slats.max.Z - slats.min.Z >= 1.5 and lip.max.Y - lip.min.Y >= 1.4, "the three homes, each a gap a spider fits in")
	-- the backdrop stands in for them a hair inside, and keeps its meadow's masses off the walkable edge
	local benchZone = WorldMap.drawnZone("bench") :: any
	local seat = nil
	for _, d in PreserveLook.records("bench", benchZone.seed) do if d.id == "Seat" then seat = d end end
	check(seat ~= nil and seat.at.Y + seat.size.Y / 2 < SL + 45 and math.abs(seat.at.X - (Meadow.BENCH.x0 + Meadow.BENCH.x1) / 2) < 1e-6, "the backdrop's bench a hair inside the walkable one")
	local meadowZone = WorldMap.drawnZone("meadow") :: any
	local over = 0
	for _, d in PreserveLook.records("meadow", meadowZone.seed) do
		if string.sub(d.id, 1, 5) == "Grass" or string.sub(d.id, 1, 5) == "Drift" or string.sub(d.id, 1, 9) == "EdgeGrass" then
			local hx, hz = d.size.X / 2, d.size.Z / 2
			if d.at.X + hx > K.x0 and d.at.X - hx < K.x1 and d.at.Z + hz > K.z0 and d.at.Z - hz < K.z1 then over += 1 end
		end
	end
	check(over == 0, `none of the backdrop's meadow masses over the walkable edge ({over})`)
	local ground = WorldMap.drawnZone("ground") :: any
	local paths = true
	for _, d in PreserveLook.records("ground", ground.seed) do
		if string.sub(d.id, 1, 4) == "Path" and d.at.Y + d.size.Y / 2 > Meadow.GROUND - 0.1 and d.at.X > D.x0 - 1 and d.at.X < D.x1 + 1 and d.at.Z > D.z0 - 1 and d.at.Z < D.z1 + 1 then paths = false; print("  " .. d.id) end
		if string.sub(d.id, 1, 11) == "MeadowFloor" and d.at.Y + d.size.Y / 2 >= Meadow.GROUND - 0.05 then paths = false; print("  " .. d.id) end
	end
	check(paths, "no mown strip of the backdrop's over the bench patch's gravel, and its meadow floor under the walkable one")
end)

case("the meadow's life: leafhoppers on the culms, flies on the flowers and at the bin, moths on the grass heads and at the lantern, the ants at their hill", function()
	WorldMap.use("preserve")
	local kinds: { [string]: number } = {}
	local fine = true
	for _, r in WorldMap.regions() do
		if Meadow.knows(r.kind) then
			local pieces = Region.pieces(r)
			for _, k in Garden.bestiary(r) or {} do
				kinds[k.kind] = (kinds[k.kind] or 0) + 1
				for _, p in k.perches do
					local on = false
					for _, piece in pieces do
						local lo, hi = piece.lo, piece.hi
						local inside = p.position.X >= lo.X - 1e-6 and p.position.X <= hi.X + 1e-6 and p.position.Y >= lo.Y - 1e-6 and p.position.Y <= hi.Y + 1e-6 and p.position.Z >= lo.Z - 1e-6 and p.position.Z <= hi.Z + 1e-6
						if inside then on = true end
					end
					if not on or not WorldMap.inBounds(p.position + p.normal * 0.31, r.id) then fine = false; print("  " .. p.id) end
				end
				if k.target < 1 or k.low < 1 or k.low > k.target or #k.perches < 2 then fine = false; print("  " .. r.id .. " " .. k.kind) end
			end
		end
	end
	check(fine and kinds.leafhopper == 4 and kinds.hoverfly == 4 and kinds.housefly == 4 and kinds.moth == 3, `leafhoppers in 4 cells, hoverflies 4, house flies 4 (one the bin), moths 3 (one the lantern), every perch on a box ({kinds.leafhopper}, {kinds.hoverfly}, {kinds.housefly}, {kinds.moth})`)
	local lamp = Garden.bestiary(WorldMap.region("lamp_4") :: any) :: any
	check(lamp[1].kind == "moth" and lamp[1].dusk ~= nil and lamp[1].perches[1].position.Y > Meadow.GROUND + 340, "the lantern's moths, from dusk, up at the light")
	-- every kind of the preserve's bestiary has a start perch with a clear flight from it, on the boxes as the server builds them (ROBLOX-119: the hoverflies' probe met
	-- their flowers, and the flights from the desk lamp, the back room's window and the flowers were sent down to the sill's 0 to 11 studs: none of their perches was good)
	do
		local WorldBuild = require("../src/Shared/World/WorldBuild")
		local PreyDirector = require("../src/Shared/Prey/PreyDirector")
		local Species = require("../src/Shared/Data/Species")
		local built = Instance.new("Folder")
		built.Parent = workspace
		for _, r in WorldMap.regions() do if r.kind ~= "sill" then WorldBuild.region(r :: any, built, {}) end end
		local idle: { string } = {}
		local n = 0
		for _, r in WorldMap.regions() do
			for _, k in Garden.bestiary(r) or {} do
				n += 1
				local d = PreyDirector.engine(built, (Species :: any)[k.profile], k.seed, k.target, false, k)
				if #d.flies < 1 then table.insert(idle, `{r.id} {k.kind}`) end
			end
		end
		built:Destroy()
		check(n >= 34 and #idle == 0, `each of the {n} kinds starts with a fly on a good perch (ROBLOX-122: 34 with the pond's) (none: {table.concat(idle, ", ")})`)
	end
	-- the ants: their colony on the meadow's floor round the hill; out by day within their range, in the nest by night, never in a box; a strike refused
	local b4 = WorldMap.region("meadow_b4") :: any
	local spec = (Garden.ambient(b4) :: any)[1]
	check(spec.kind == "ant" and #spec.starts == spec.full and spec.full == 6 and spec.low == 3 and Garden.ambient(b4) == Garden.ambient(b4), "six ants at the hill (three at the low tier), the same each time")
	local soil, boxes = nil, {}
	for _, p in Region.pieces(b4) do
		if p.id == "meadow_b4_soil" then soil = { min = p.lo, max = p.hi } elseif p.lo.Y <= Meadow.GROUND + 0.01 then table.insert(boxes, { min = p.lo, max = p.hi }) end
	end
	local ants = Ant.new(spec, spec.full, soil, boxes)
	local inside, far, moved = 0, 0, 0
	local start = ants.items[1].position
	for _ = 1, 60 * 30 do
		ants:step(1 / 60, Vector3.zero, { hour = 12 })
		for _, a in ants.items do
			for _, b in boxes do if a.surface.X > b.min.X and a.surface.X < b.max.X and a.surface.Z > b.min.Z and a.surface.Z < b.max.Z then inside += 1 end end
			if (Vector3.new(a.surface.X - spec.centre.X, 0, a.surface.Z - spec.centre.Z)).Magnitude > spec.range + 1 then far += 1 end
		end
	end
	moved = (ants.items[1].position - start).Magnitude
	check(inside == 0 and far == 0 and moved > 1 and #ants:targets() == 6, `half a minute of a day: they walk (the first {string.format("%.1f", moved)} studs off), never in a box or past their range ({inside}, {far})`)
	for _ = 1, 60 * 40 do ants:step(1 / 60, Vector3.zero, { hour = 22 }) end
	check(#ants:targets() == 0 and #ants:problems(b4.bounds[1], b4.bounds[2]) == 0, "by night all in the nest, none to strike; the colony well formed")
	check(PreyText.REFUSED.ant ~= nil and string.find(PreyText.REFUSED.ant, "let it go", 1, true) ~= nil, "a strike at an ant is refused with its own words")
end)

case("the crab spiders: on their flowers by a seeded day, still; what comes in reach is grabbed in the standard rules and knocked clear in the gentle ones", function()
	WorldMap.use("preserve")
	local seed = WorldMap.seed(WorldMap.SEED, "crab_spider")
	local days, both = {}, true
	for day = 1, 20 do
		local a = CrabSpider.siteOf(seed, 1, day)
		local b = CrabSpider.siteOf(seed, 2, day)
		days[a] = true
		if a ~= CrabSpider.siteOf(seed, 1, day) or b < 1 or b > 2 then both = false end
	end
	check(both and days[1] and days[2], "each sits on one of its two flowers a day, the same for the same day, both used")
	local crab = CrabSpider.new(seed)
	crab:step(1 / 60, 3, 12, nil)
	check(#crab.crabs == 2 and crab.crabs[1].form == "yellow" and crab.crabs[2].form == "white", "a yellow one on a goldenrod, a white one on a yarrow")
	local c = crab.crabs[1]
	local head = nil
	for _, p in Region.pieces(WorldMap.region(c.region) :: any) do if p.id == Meadow.CRAB_SITES[1][c.site].piece then head = p end end
	check(head ~= nil and math.abs(c.top.Y - head.hi.Y) < 1e-6 and c.pos.Y > head.hi.Y, "it sits on its flower's head")
	local function trial(gentle: boolean, at: Vector3, hidden: boolean): string?
		local t = CrabSpider.new(seed)
		t.gentle = gentle
		t:step(1 / 60, 3, 12, nil)
		local got = nil
		for _ = 1, 60 do
			t:step(1 / 60, 3, 12, { pos = at, hidden = hidden })
			for _, s in t:drainSignals() do if s.kind ~= "seen" then got = got or s.kind end end
		end
		return got
	end
	local onTop = c.top + Vector3.new(0.6, 0.31, 0)
	check(trial(false, onTop, false) == "struck" and trial(true, onTop, false) == "nudged", "a spider on its flower: grabbed in the standard rules, knocked clear in the gentle ones")
	check(trial(false, c.top + Vector3.new(0, 0.31, 0) - Vector3.yAxis * 12, false) == nil and trial(false, onTop, true) == nil, "out of reach down the stem, or hidden, nothing")
	local t = CrabSpider.new(seed)
	t:step(1 / 60, 3, 12, nil)
	local seen = 0
	for _ = 1, 30 do
		t:step(1 / 60, 3, 12, { pos = c.pos + Vector3.new(6, 0, 0), hidden = false })
		for _, s in t:drainSignals() do if s.kind == "seen" then seen += 1 end end
	end
	check(seen == 1, "a close look opens its page once")
	-- the gentle rules wait before lunging again
	local g = CrabSpider.new(seed)
	g.gentle = true
	g:step(1 / 60, 3, 12, nil)
	local lunges = 0
	for _ = 1, 60 * 5 do
		g:step(1 / 60, 3, 12, { pos = onTop, hidden = false })
		for _, s in g:drainSignals() do if s.kind == "nudged" then lunges += 1 end end
	end
	check(lunges == 1, `one lunge, then it waits ({lunges} in five seconds)`)
	check(CrabText.CAUSE == CrabSpider.CAUSE and string.find(CrabText.SUB, "careful look", 1, true) ~= nil and CrabText.NUDGED ~= "", "its death card says what would have saved the spider")
end)

-- ---------------------------------------------------------------- ROBLOX-120: the robin, the field cricket and ballooning
case("the robin's day: seeded, the same for the same day, four to six visits by day to its sites on the ground of the hut garden, the bench patch and the meadow's edge", function()
	local Bird = require("../src/Shared/Predator/Bird")
	WorldMap.use("preserve")
	local seed = WorldMap.seed(WorldMap.SEED, "bird")
	check(Bird.LENGTH == 25 and Bird.HOUR_PER_S > 0, "a robin 25 cm from bill to tail, its visits at the outdoors' pace")
	-- every site's line on the ground of a walkable region of the preserve, clear of its standing boxes
	for _, site in Bird.SITES do
		for i, pt in site.line do
			local r = WorldMap.at(pt + Vector3.new(0, 0.5, 0))
			check(r ~= nil and (r.kind == "garden_bed" or r.kind == "pad" or r.kind == "meadow" or r.kind == "mown_path"), `{site.id} point {i} lies in the hut garden, the bench patch, the meadow or (ROBLOX-122) on the mown path to the pond ({if r then r.id else "none"})`)
			local inside = false
			if r ~= nil then for _, b in Region.pieces(r) do if pt.X > b.lo.X and pt.X < b.hi.X and pt.Z > b.lo.Z and pt.Z < b.hi.Z and b.hi.Y > pt.Y + 1 then inside = true end end end
			check(not inside, `{site.id} point {i} is not inside a box`)
		end
	end
	local zones: { [string]: number } = {}
	for day = 1, 12 do
		local plan = Bird.plan(seed, day)
		check(plan == Bird.plan(seed, day) and #plan >= 4 and #plan <= 6, `day {day}: four to six visits, the same each time ({#plan})`)
		for i, visit in plan do
			zones[visit.site.zone] = (zones[visit.site.zone] or 0) + 1
			check(visit.h0 >= 6 and visit.h1 <= 19.5 + 1e-6 and (i == 1 or visit.h0 >= plan[i - 1].h1), `day {day} visit {i} by day, after the one before`)
			local a = Bird.at(seed, day, visit.h0 + 1e-6) :: any
			local mid = Bird.at(seed, day, Bird.hourOf(visit, Bird.APPROACH_S + visit.forage / 2)) :: any
			local off = Bird.at(seed, day, visit.h1 - 1e-6) :: any
			check(a ~= nil and a.pose == "fly" and a.shadow ~= nil and a.pos.Y > Bird.GROUND + 200 and a.calling, `day {day} visit {i}: it comes in high, calling, its shadow on the ground`)
			check(mid ~= nil and (mid.pose == "stand" or mid.pose == "hop" or mid.pose == "peck") and mid.pos.Y < Bird.GROUND + 4 and mid.shadow == nil, `day {day} visit {i}: on the ground in the middle of it`)
			check(off ~= nil and off.pose == "leave" and off.pos.Y > Bird.GROUND + 100, `day {day} visit {i}: off up and away at the end`)
		end
		check(Bird.at(seed, day, 5.5) == nil and Bird.at(seed, day, 21) == nil, `day {day}: not here at night`)
	end
	check((zones.hut_garden or 0) > 0 and (zones.meadow or 0) > 0 and (zones.bench or 0) > 0, `it visits the hut garden, the bench patch and the meadow's edge (in twelve days: {zones.hut_garden}, {zones.bench}, {zones.meadow})`)
	-- restores never reroll: two robins of the seed are where the schedule says, the same
	local a, b = Bird.new(seed), Bird.new(seed)
	local visit = Bird.plan(seed, 2)[1]
	local h = Bird.hourOf(visit, Bird.APPROACH_S + 20)
	a:step(1 / 60, 2, h, nil); b:step(1 / 60, 2, h, nil)
	check(a.here and b.here and a.pos == b.pos and a.pose == b.pose, "two robins of one seed at one hour are the same robin")
end)

case("the robin's reactions: a spider moving in the open near it is seen, hopped at, given the tell and struck in the standard rules (missed in the gentle ones); cover or stillness saves it", function()
	local Bird = require("../src/Shared/Predator/Bird")
	local BirdText = require("../src/Shared/UI/BirdText")
	WorldMap.use("preserve")
	local seed = WorldMap.seed(WorldMap.SEED, "bird")
	local day, visit = 1, nil :: any
	for d = 1, 20 do visit = Bird.visitTo(seed, d, "lawn_e"); if visit then day = d; break end end
	check(visit ~= nil, "a visit to the lawn east of the path in the first twenty days")
	local h0 = Bird.hourOf(visit, Bird.APPROACH_S + 5)
	-- `run` steps a robin from that hour with a spider `at` (relative to where the robin stands) moving or still, open or covered, and says what came of it
	local function run(gentle: boolean, moving: boolean, covered: boolean, hidden: boolean, dist: number, seconds: number?): ({ [string]: number }, any)
		local bird = Bird.new(seed)
		bird.gentle = gentle
		bird:step(1 / 60, day, h0, nil)
		local base = bird.pos
		local away = Vector3.new(bird.heading.X, 0, bird.heading.Z).Unit
		local pos = base + away * dist + Vector3.new(0, 0.31, 0)
		local seen: { [string]: number } = {}
		local hour = h0
		for i = 1, math.floor((seconds or 6) * 60) do
			hour += Bird.HOUR_PER_S / 60
			local wiggle = if moving then Vector3.new(math.sin(i * 0.2) * 0.05, 0, math.cos(i * 0.2) * 0.05) else Vector3.zero
			pos += wiggle
			bird:step(1 / 60, day, hour, { pos = pos, speed = if moving then 3 else 0, hidden = hidden, covered = covered })
			for _, sg in bird:drainSignals() do seen[sg.kind] = (seen[sg.kind] or 0) + 1 end
			if (seen.struck or 0) + (seen.missed or 0) > 0 then break end
		end
		return seen, bird
	end
	local s1, b1 = run(false, true, false, false, 40)
	check((s1.noticed or 0) == 1 and (s1.struck or 0) == 1 and (s1.missed or 0) == 0, `moving in the open 40 cm off: seen, hopped at and struck (noticed {s1.noticed}, struck {s1.struck}, lost {s1.lost})`)
	check(b1.offset.Magnitude > 5, `it hopped toward the spider ({string.format("%.0f", b1.offset.Magnitude)} studs off its line)`)
	local s2 = run(true, true, false, false, 40)
	check((s2.missed or 0) == 1 and (s2.struck or 0) == 0, "in the gentle rules the bill misses")
	local s3 = run(false, false, false, false, 20)
	check((s3.noticed or 0) == 0 and (s3.struck or 0) == 0, "a spider keeping still is never seen")
	local s4 = run(false, true, true, false, 20)
	check((s4.noticed or 0) == 0 and (s4.struck or 0) == 0, "a spider under cover is never seen")
	local s5 = run(false, true, false, true, 20)
	check((s5.noticed or 0) == 0, "nor one in a home")
	local s6 = run(false, true, false, false, 150)
	check((s6.noticed or 0) == 0, "nor one far off")
	-- seen, then still: the tell passes and it is lost
	do
		local bird = Bird.new(seed)
		bird:step(1 / 60, day, h0, nil)
		local away = Vector3.new(bird.heading.X, 0, bird.heading.Z).Unit
		local pos = bird.pos + away * 14 + Vector3.new(0, 0.31, 0)
		local hour = h0
		local seen: { [string]: number } = {}
		for i = 1, 60 * 4 do
			hour += Bird.HOUR_PER_S / 60
			local moving = i <= 6
			bird:step(1 / 60, day, hour, { pos = pos, speed = if moving then 3 else 0, hidden = false, covered = false })
			for _, sg in bird:drainSignals() do seen[sg.kind] = (seen[sg.kind] or 0) + 1 end
		end
		check((seen.noticed or 0) == 1 and (seen.struck or 0) == 0 and (seen.lost or 0) >= 1, `seen, then keeping still: lost, not struck (lost {seen.lost})`)
	end
	-- the approach: its shadow passes the spider, told once
	do
		local bird = Bird.new(seed)
		local land = visit.site.line[1]
		local hour = visit.h0
		local shadows = 0
		for _ = 1, 60 * 4 do
			hour += Bird.HOUR_PER_S / 60
			bird:step(1 / 60, day, hour, { pos = land + visit.site.from * 120 + Vector3.new(0, 0.31, 0), speed = 0, hidden = false, covered = false })
			for _, sg in bird:drainSignals() do if sg.kind == "shadow" then shadows += 1 end end
		end
		check(shadows == 1, `its shadow sweeps over a spider on its way in, told once ({shadows})`)
	end
	-- cover, from the region's boxes: under the hut garden's flat stone; low in the meadow's grass
	local a3 = WorldMap.region("garden_a3") :: any
	check(Bird.covered(Region.pieces(a3), Vector3.new(65, Bird.GROUND + 0.5, -88)) and not Bird.covered(Region.pieces(a3), Vector3.new(30, Bird.GROUND + 0.5, -110)), "under the flat stone is cover, the open lawn is not")
	check(Bird.inGrass("meadow", Vector3.new(0, Bird.GROUND + 3, -1300)) and not Bird.inGrass("meadow", Vector3.new(0, Bird.GROUND + 60, -1300)) and not Bird.inGrass("garden_bed", Vector3.new(0, Bird.GROUND + 3, -100)), "low in the meadow's grass is cover, up a stem or on the lawn it is not")
	check(BirdText.CAUSE == "bird" and string.find(BirdText.SUB, "keeping still", 1, true) ~= nil and BirdText.MISSED ~= "" and BirdText.caption(0.5, "ahead", nil) ~= nil and BirdText.caption(0, "ahead", 1) ~= nil and BirdText.caption(0, "ahead", nil) == nil, "its card says what would have saved the spider; its call and its shadow are captioned")
end)

case("the robin drawn: an American robin at true size in every pose, the same parts standing and in the air, within its budget", function()
	local BirdBody = require("../src/Client/BirdBody")
	for _, pose in { "stand", "hop", "peck", "watch", "strike", "fly", "land", "leave" } do
		local parts = BirdBody.parts(pose, 0.3, 1, 0.5)
		local lo, hi = math.huge, -math.huge
		local names: { [string]: boolean } = {}
		for _, p in parts do
			local c = p.frame.Position
			lo = math.min(lo, c.Z - p.size.Z / 2); hi = math.max(hi, c.Z + p.size.Z / 2)
			names[p.name] = true
		end
		check(#parts <= 30 and names.Head and names.Breast and names.Bill and names.Tail and names.WingL and names.WingR, `{pose}: {#parts} parts, its head, breast, bill, tail and wings`)
		if pose == "stand" then check(hi - lo > 22 and hi - lo < 29, `standing it is {string.format("%.1f", hi - lo)} cm from bill to tail (a robin is 20 to 28)`) end
	end
end)

case("the field crickets: in the hut garden's mulch and the meadow's thatch, three housefly meals, a hard struggle that kicks; it hears a spider move and hushes; it sings by night", function()
	local Species = require("../src/Shared/Data/Species")
	local Garden = require("../src/Shared/World/Garden")
	local Feeding = require("../src/Shared/Prey/Feeding")
	local PreyKinds = require("../src/Shared/Prey/PreyKinds")
	local PreyRandom = require("../src/Shared/Prey/PreyRandom")
	local Catch = require("../src/Shared/Data/Catch")
	local Fly = require("../src/Shared/Prey/Fly")
	local Graph = require("../src/Shared/Prey/PerchGraph")
	WorldMap.use("preserve")
	local c, n = Species.cricket_prototype, Species.cricket_night_prototype
	check(c.body.nutrition == Species.fly_like_prototype.body.nutrition * 3 and c.body.prey_kind == "cricket" and c.body.flightless and c.body.freeze and n.body.chirp and not c.body.chirp
		and c.body.dusk == "cricket_night_prototype" and n.body.day == "cricket_prototype", "three housefly meals, flightless, a jumper that freezes, singing by night")
	check(Catch.factorFor(c) == 1.15 and c.body.kick ~= nil, "a harder catch than a house fly, and it kicks")
	local cells: { string } = {}
	for _, r in WorldMap.regions() do
		for _, k in Garden.bestiary(r) or {} do
			if k.kind == "cricket" then
				table.insert(cells, r.id)
				check(#k.perches >= 4 and k.dusk ~= nil and k.target == 1, `{r.id}: a cricket of the night with {#k.perches} spots on the ground`)
				for _, pe in k.perches do
					check(math.abs(pe.position.Y - (if r.id == "garden_d3" then -74.6 else -84.6)) < 1e-6 and pe.hop, `{pe.id} lies on the ground it walks`)
				end
			end
		end
	end
	table.sort(cells)
	check(table.concat(cells, ",") == "garden_d3,meadow_b2,meadow_c5,meadow_d3", "in the pollinator bed's mulch and three of the meadow's cells: " .. table.concat(cells, ","))
	-- the struggle: 60 seeded crickets, a steady tapper at 4, 5 and 6 taps a second
	local function trial(rate: number, seed: number): (boolean, number, number)
		local fd = Feeding.new(); fd:useGameRules()
		fd.rng = PreyRandom.new(seed)
		local f: any = { profile = c, rng = PreyRandom.new(seed * 7919 + 104729), nutrition = c.body.nutrition }
		fd:capture(f)
		local escaped = false
		local every, nextTap, t = 1 / rate, 1 / rate, 0
		for _ = 1, 60 * 14 do
			t += 1 / 60
			if t >= nextTap then fd.tap = true; nextTap += every end
			PreyKinds.grip(fd, function() escaped = true end)
			fd:struggle(1 / 60, true, function() escaped = true end)
			if escaped or not fd.struggling then break end
		end
		return not escaped, t, f.kicks or 0
	end
	local wins: { [number]: number } = {}
	local kicks, time = 0, 0
	for _, rate in { 4, 5, 6 } do
		wins[rate] = 0
		for seed = 1, 60 do
			local won, t, k = trial(rate, seed)
			if won then wins[rate] += 1 end
			if rate == 5 then kicks += k; time += t end
		end
	end
	print(`preserve: the cricket's struggle: wins at 4, 5 and 6 taps a second {wins[4]}, {wins[5]}, {wins[6]} of 60; at 5 a second {string.format("%.1f", time / 60)} s, {string.format("%.1f", kicks / 60)} kicks`)
	check(wins[4] <= 10 and wins[5] >= 50 and wins[6] == 60 and kicks / 60 >= 3, "four taps a second mostly lose it, five mostly hold it, six always do, and it kicks all the while")
	-- the ear: a fly of the profile on a flat box, a spider walking near hushes it, standing still does not; it sings only unhushed, by night, perched
	local cast = function(a: Vector3, b: Vector3): any
		if a.Y > 0 and b.Y <= 0 then return { Position = Vector3.new(a.X, 0, a.Z), Normal = Vector3.yAxis } end
		return nil
	end
	local graph = Graph.new(cast, function() return false end, function() return false end, n)
	local perch = graph:add("p1", Vector3.new(0, 0, 0), Vector3.yAxis, 0.6, 0.3, true)
	local f = Fly.new("cricket_1", 1, 4242, perch, graph, n, 0)
	check(PreyKinds.chirping(f), "a cricket of the night, calm and perched, sings")
	local now, hushes = 0, 0
	local spider = Vector3.new(20, 0.3, 0)
	for i = 1, 60 do
		now += 1 / 60
		spider += Vector3.new(-0.05, 0, 0)
		PreyKinds.hear(f, now, 1 / 60, spider)
	end
	check(f.hushed == true and not PreyKinds.chirping(f) and (f.hushes or 0) == 1, "a spider walking within 30 cm hushes it: silent and still")
	for _ = 1, 60 * 7 do now += 1 / 60; PreyKinds.hear(f, now, 1 / 60, spider) end
	check(f.hushed == false and PreyKinds.chirping(f), "a spider standing still lets it sing again after its hold")
	local far = Fly.new("cricket_2", 1, 4243, graph:add("p2", Vector3.new(100, 0, 0), Vector3.yAxis, 0.6, 0.3, true), graph, n, 0)
	local sp2 = Vector3.new(160, 0.3, 0)
	for _ = 1, 60 do now += 1 / 60; sp2 += Vector3.new(-0.05, 0, 0); PreyKinds.hear(far, now, 1 / 60, sp2) end
	check(far.hushed == false, "one walking farther off does not")
	local day = Fly.new("cricket_3", 1, 4244, graph:add("p3", Vector3.new(-100, 0, 0), Vector3.yAxis, 0.6, 0.3, true), graph, c, 0)
	PreyKinds.hear(day, 0, 1 / 60, Vector3.new(500, 0, 0))
	check(not PreyKinds.chirping(day), "by day it does not sing")
	local even = Fly.new("cricket_4", 2, 4245, graph:add("p4", Vector3.new(-200, 0, 0), Vector3.yAxis, 0.6, 0.3, true), graph, n, 0)
	PreyKinds.hear(even, 0, 1 / 60, Vector3.new(500, 0, 0))
	check(not PreyKinds.chirping(even), "a female (an even number) does not sing")
end)

case("ballooning: the wind's draw, seeded, mostly the hut garden, sometimes the meadow's edge, only built zones; the ride from the sac out of the sash and down onto the landing", function()
	local Ballooning = require("../src/Shared/Life/Ballooning")
	local MateText = require("../src/Shared/UI/MateText")
	WorldMap.use("preserve")
	local counts: { [string]: number } = {}
	for gen = 0, 9 do
		for day = 5, 24 do
			local z, r = Ballooning.land(914, gen, day)
			local z2, r2 = Ballooning.land(914, gen, day)
			check(z == z2 and r == r2, "the same family and day, the same landing")
			counts[z] = (counts[z] or 0) + 1
			check(Ballooning.valid(z) and z ~= Ballooning.HUT and Ballooning.landsIn(z, r), `{z} is a built zone and {r} one of its landings`)
		end
	end
	local garden, meadow, pond = counts.hut_garden or 0, counts.meadow or 0, counts.pond_edge or 0
	print(`preserve: ballooning: of 200 families the hut garden {garden}, the meadow's edge {meadow}, the pond's edge {pond}`)
	check(garden + meadow + pond == 200 and garden > meadow and meadow > pond and pond > 0,
		"nearer destinations are more common; the relocated pond is now within a short drift")
	local totalWeight = 0
	for _, z in Ballooning.ZONES do totalWeight += Ballooning.weight(z) end
	for _, z in Ballooning.ZONES do
		if z.built then
			local expected = 200 * Ballooning.weight(z) / totalWeight
			check(math.abs((counts[z.zone] or 0) - expected) < 25, `{z.zone}: sampled landings agree with distance-weighted odds ({counts[z.zone] or 0}, expected {expected})`)
		end
	end
	for _, z in Ballooning.ZONES do
		check(z.built == (#z.landings > 0) and (Ballooning.weight(z) > 0) == z.built, `{z.zone}: landed in only when built`)
		for _, id in z.landings do
			local r = WorldMap.region(id)
			check(r ~= nil and Region.pieces(r :: any) ~= nil, `{id} is a region of the preserve`)
			if r ~= nil then
				local stands = false
				for _, b in Region.pieces(r) do
					local p = r.spawn.pos
					if p.X >= b.lo.X and p.X <= b.hi.X and p.Z >= b.lo.Z and p.Z <= b.hi.Z and math.abs(b.hi.Y - p.Y) < 0.05 then stands = true end
				end
				check(stands, `{id}'s spawn stands on a box`)
				local ride = Ballooning.ride(914, 1, 9, r.spawn.pos)
				local a, _ = Ballooning.at(ride, 0)
				local e, _ = Ballooning.at(ride, ride.seconds)
				local _, top = Ballooning.at(ride, ride.seconds * 0.5)
				local mid, _ = Ballooning.at(ride, ride.seconds * 0.5)
				local high = -math.huge
				local inside = true
				for t = 0, ride.seconds, 0.25 do
					local p = Ballooning.at(ride, t)
					high = math.max(high, p.Y)
					if math.abs(p.X) > Preserve.LIMIT or math.abs(p.Z) > Preserve.LIMIT then inside = false end
				end
				check((a - Ballooning.SAC).Magnitude < 1e-6 and (e - r.spawn.pos).Magnitude < 1e-3 and high > Preserve.GROUND_Y + 100 and inside and top.Y > mid.Y,
					`{id}: from the sac, up over the garden ({string.format("%.0f", high - Preserve.GROUND_Y)} cm), down onto the landing, its thread above it`)
			end
		end
	end
	local _, _, body = MateText.card(9, 12, 0, true)
	check(string.find(body, "Follow one of them on the wind", 1, true) ~= nil and MateText.FOLLOW == "Follow one" and MateText.STAY == "Stay at the hut"
		and MateText.generationToast(1, 12, "the meadow's edge") == "Generation 2 — hatched on day 12, landed in the meadow's edge" and MateText.generationToast(1, 12) == "Generation 2 — hatched on day 12"
		and string.find(MateText.landed("the hut garden"), "in the wild", 1, true) ~= nil, "the card, the choices, the toast and the landing say it")
	local _, _, plain = MateText.card(9, 12, 0)
	check(string.find(plain, "carry on as one of them", 1, true) ~= nil, "the test garden's card is as it was")
end)

-- ---------------------------------------------------------------- ROBLOX-122: the pond's edge, the boardwalk and the mown path to it; the water; the pond's life; the frog
case("the pond's edge and the boardwalk: home range 4 where the boardwalk meets the pond, the mown path from the meadow to it, walkable at true size, seam to seam", function()
	WorldMap.use("preserve")
	local H4 = Preserve.HOME_RANGES[4]
	local lo, hi = Preserve.box(H4.at[1] - H4.size / 2, H4.at[1] + H4.size / 2, H4.at[2] - H4.size / 2, H4.at[2] + H4.size / 2, 0, 0)
	local K = Pond.CORE
	check(H4.id == "pond_edge" and math.abs(lo.X - K.x0) < 1e-6 and math.abs(hi.X - K.x1) < 1e-6 and math.abs(lo.Z - K.z0) < 1e-6 and math.abs(hi.Z - K.z1) < 1e-6,
		"the pond's edge is home range 4, 4 by 4 m (x 64..68, z 29.25..33.25 m)")
	local ids = {}
	for _, r in WorldMap.regions() do if Pond.knows(r.kind) then table.insert(ids, r.id) end end
	check(#ids == 35, `35 regions: the mown path's 3 cells, the boardwalk's 16, the margin's 12 and the cattails' 4 up ({#ids})`)
	-- the way: from the bench patch's gravel east and north along the mown path, up the boardwalk's fascia, along it to the core and down to the margin
	local chain = { "pad_b3", "mown_e1" }
	for k = 2, Pond.PATH_E.n do table.insert(chain, `mown_e{k}`) end
	for k = 1, Pond.PATH_N.n do table.insert(chain, `mown_n{k}`) end
	for _, id in { "walk_s1", "walk_s2", "walk_s3", "walk_s4", "deck_s1", "deck_n1", "pond_a1", "pond_b1", "pond_b2", "pond_c2" } do table.insert(chain, id) end
	local linked = true
	for i = 1, #chain - 1 do
		local a = WorldMap.region(chain[i]) :: WorldMap.Region
		local found = false
		for _, n in a.neighbors do if n.id == chain[i + 1] then found = true end end
		if not found then linked = false; print(`  {chain[i]} does not meet {chain[i + 1]}`) end
	end
	check(linked, "from the bench patch along the mown path, up onto the boardwalk, along it into the pond's edge and down to the water, seam to seam")
	local function piecesOf(id: string): { [string]: any }
		local out = {}
		for _, p in Region.pieces(WorldMap.region(id) :: any) do out[p.id] = p end
		return out
	end
	-- true sizes: the boards, the deck's height, the posts, the kerb rail
	local s2, n1 = piecesOf("deck_s2"), piecesOf("deck_n1")
	local b1, b2 = s2.deck_s2_board_1, s2.deck_s2_board_2
	check(math.abs((b1.hi.Z - b1.lo.Z) - 14) < 1e-6 and b1.lo.Z - b2.hi.Z > 1.0 and b1.lo.Z - b2.hi.Z < 1.3 and math.abs(b1.hi.Y - Pond.DECK) < 1e-6
		and math.abs(Pond.DECK - Preserve.GROUND_Y - 40) < 1e-6, "the boards 14 cm wide with a gap of a centimetre and a bit, the deck 40 cm over the lawn")
	local gap = s2.deck_s2_board_3.lo.Z - s2.deck_s2_board_4.hi.Z
	check(gap >= 1.5 and WorldMap.inRetreat((WorldMap.retreat("deck_gap") :: any).min + Vector3.new(1, 1, 0.5)) == "deck_gap", string.format("the wide gap between two boards, %.1f cm, a home", gap))
	local post = n1.deck_n1_post
	check(post ~= nil and math.abs((post.hi.X - post.lo.X) - 10) < 1e-6 and post.hi.Y < Pond.DECK and n1.deck_n1_kerb.hi.Y - Pond.DECK == 10, "a post 10 cm square under the beam, the kerb rail 10 cm over the deck")
	-- the water: 6 cm under the lawn, no box on it; the bank's strips end at the waterline; the pads, stones and stems stand in it
	check(math.abs(Pond.WATER - (Pond.GROUND - 6)) < 1e-6 and Pond.BED < Pond.WATER, "the water 6 cm under the lawn, the bed under it")
	local surface, landOk, padSizes, stands = 0, true, {}, 0
	for _, r in WorldMap.regions() do
		if r.kind == "pond" or r.kind == "boardwalk" or r.kind == "cattail" then
			for _, p in Region.pieces(r) do
				if p.lo.Y < Pond.WATER - 0.05 and p.hi.Y > Pond.WATER + 0.05 and p.hi.X - p.lo.X > 60 and p.hi.Z - p.lo.Z > 60 then surface += 1 end -- (a box over open water)
				local band = string.match(p.id, "_(%a+)_%d+$")
				if band == "bank" or band == "damp" or band == "wet" then
					local zw = Pond.waterline((p.lo.X + p.hi.X) / 2)
					if zw ~= nil and p.lo.Z < zw - 1e-6 then landOk = false; print("  " .. p.id .. " in the water") end
				end
				if string.sub(p.id, -4) == "_mid" and string.find(p.id, "_pad_", 1, true) then table.insert(padSizes, (p.hi.X - p.lo.X) / 0.94) end
			end
		end
	end
	table.sort(padSizes)
	check(surface == 0 and landOk, "nothing lies on the open water to stand on, and the bank's land ends at the waterline")
	check(#padSizes >= 15 and padSizes[1] >= 15 - 1e-6 and padSizes[#padSizes] <= 30 + 1e-6, string.format("%d lily pads, %.0f to %.0f cm across (the sources' 15 to 30)", #padSizes, padSizes[1] or 0, padSizes[#padSizes] or 0))
	-- the cattails: leaves 1.5 cm wide and 1.5 to 2.2 m tall, the brown spike 18 cm long; their upper parts in their own regions
	local tallest, narrow, spike = 0, true, nil :: any
	for _, p in Pond.standPieces(1) do
		if string.find(p.id, "_leaf_", 1, true) then
			tallest = math.max(tallest, p.hi.Y - Pond.WATER)
			if math.max(p.hi.X - p.lo.X, p.hi.Z - p.lo.Z) > 2 then narrow = false end
		elseif string.sub(p.id, -6) == "_spike" then spike = p end
	end
	check(narrow and tallest >= 150 and tallest <= 250 and spike ~= nil and math.abs((spike.hi.Y - spike.lo.Y) - 18) < 1e-6, string.format("the cattails' leaves 1.5 cm wide to %.0f cm over the water, the spike 18 cm", tallest))
	local whole = true
	for k = 1, 2 do
		for _, p in Pond.standPieces(k) do
			local found = 0
			for _, id in { `pond_{Pond.STANDS[k].cell}`, `cattail_{k}a`, `cattail_{k}b` } do
				for _, q in Region.pieces(WorldMap.region(id) :: any) do
					if string.sub(q.id, 1, #p.id) == p.id then found += (q.hi.Y - q.lo.Y) end
				end
			end
			if math.abs(found - (p.hi.Y - p.lo.Y)) > 1e-6 then whole = false; print("  " .. p.id) end
		end
	end
	check(whole, "each stand's every box whole across its cell and its two regions up")
	-- in the water: under the surface over the water's plan; on a pad, a stone or the bank, out of it
	local a3 = piecesOf("pond_a3")
	local pad = a3.pond_a3_pad_1_mid
	local onPad = Vector3.new((pad.lo.X + pad.hi.X) / 2, pad.hi.Y + 0.31, (pad.lo.Z + pad.hi.Z) / 2)
	local stone = piecesOf("pond_a2").pond_a2_flat
	local onStone = Vector3.new((stone.lo.X + stone.hi.X) / 2, stone.hi.Y + 0.31, (stone.lo.Z + stone.hi.Z) / 2)
	local wet = Vector3.new(onPad.X, Pond.WATER - 0.5, pad.lo.Z - 6)
	check(Pond.inWater(wet) and not Pond.inWater(onPad) and not Pond.inWater(onStone) and not Pond.inWater(Vector3.new(540, Pond.GROUND + 0.31, -995))
		and not Pond.inWater(Vector3.new(300, Pond.DECK + 0.31, -855)), "in the water under its surface; on a pad, the flat stone, the bank or the boardwalk, not")
	-- the homes
	for _, id in { "deck_gap", "pond_stone", "cattail_leaf" } do
		local t = WorldMap.retreat(id) :: any
		check(t ~= nil and WorldMap.inRetreat((t.min + t.max) * 0.5) == id and t.max.Y - t.min.Y >= 1.3 and math.min(t.max.X - t.min.X, t.max.Z - t.min.Z) >= 1.5 and LifeText.HOMES[id] ~= nil,
			`{id}: a gap a spider fits in, with its words`)
	end
	-- the backdrop: no lawn over the pond's hole, its water lens a hair under the surface, its bank and its lilies never over the walkable core or the corridor's deck
	local ground = WorldMap.drawnZone("ground") :: any
	local over = 0
	for _, d in PreserveLook.records("ground", ground.seed) do
		if string.sub(d.id, 1, 5) == "Grass" or string.sub(d.id, 1, 11) == "MeadowFloor" then
			local hx, hz = d.size.X / 2, d.size.Z / 2
			local c0, c1 = Preserve.at(48, 13), Preserve.at(66, 28.75)
			if d.at.X + hx > c0.X + 1e-3 and d.at.X - hx < c1.X - 1e-3 and d.at.Z - hz < c0.Z - 1e-3 and d.at.Z + hz > c1.Z + 1e-3 then over += 1; print("  " .. d.id) end
		end
	end
	local pondZone = WorldMap.drawnZone("pond") :: any
	local water, onCore = nil :: any, 0
	local boardwalk = nil :: any
	for _, d in PreserveLook.records("pond", pondZone.seed) do
		if d.id == "Water" then water = d end
		if d.id == "Boardwalk" then boardwalk = d end
		if string.sub(d.id, 1, 4) == "Bank" or string.sub(d.id, 1, 4) == "Lily" then
			local hx, hz = d.size.X / 2, d.size.Z / 2
			if string.sub(d.id, 1, 4) == "Lily" then hx, hz = d.size.Y / 2, d.size.Z / 2 end
			if d.at.X + hx > K.x0 + 1e-3 and d.at.X - hx < K.x1 - 1e-3 and d.at.Z + hz > K.z0 + 1e-3 and d.at.Z - hz < K.z1 - 1e-3 then onCore += 1; print("  " .. d.id) end
		end
	end
	check(over == 0 and water ~= nil and math.abs(water.at.Y + water.size.Y / 2 - (Pond.WATER - 0.3)) < 1e-6 and onCore == 0,
		"no lawn over the pond, its water lens 3 mm under the surface, nothing of the backdrop's bank or lilies over the walkable core")
	check(boardwalk ~= nil and math.abs(boardwalk.at.X - boardwalk.size.X / 2 - Pond.WALK_X[1]) < 1e-6
		and math.abs(boardwalk.at.X + boardwalk.size.X / 2 - K.x1) < 1e-6,
		"the visible boardwalk ends at the authored collision, without an inviting unsupported continuation")
	local cross = nil :: any
	for _, c in Preserve.CORRIDORS do if c.id == "path_cross" then cross = c end end
	check(cross.points[1][1] == 46.65 and cross.points[3][2] == 13, "the mown path's corridor is the walkable one, from the bench patch to the boardwalk")
end)

case("the water: a spider in it struggles, then gets out onto what it can reach or drowns (Normal), and is always pulled out in the gentle rules; seeded, never rerolled", function()
	local Water = require("../src/Shared/Life/Water")
	local WaterText = require("../src/Shared/UI/WaterText")
	WorldMap.use("preserve")
	local boxes = {}
	for _, id in { "pond_a3", "pond_b3", "cattail_1a" } do for _, p in Region.pieces(WorldMap.region(id) :: any) do table.insert(boxes, p) end end
	local pad = nil :: any
	for _, p in boxes do if p.id == "pond_a3_pad_1_mid" then pad = p end end
	-- a way out: a pad 2 cm off; nothing near in the open water of pond_b3's middle
	local near = Vector3.new(pad.lo.X - 2, Pond.WATER, (pad.lo.Z + pad.hi.Z) / 2)
	local b, d, at, n = Water.wayOut(near, Pond.WATER, boxes, Water.REACH)
	check(b ~= nil and math.abs(d - 2) < 1e-6 and n == Vector3.yAxis and math.abs(at.Y - pad.hi.Y) < 1e-6, "a pad 2 cm off is a way out, onto its top")
	local open = Vector3.new(775, Pond.WATER, -1120)
	local none = Water.wayOut(open, Pond.WATER, boxes, Water.REACH)
	check(none == nil, "in the open water of the margin nothing is in reach")
	check(Water.chance(0, 0) == Water.NEAR_CHANCE and Water.chance(Water.REACH, 0) == Water.FAR_CHANCE and Water.chance(1, 30) < Water.chance(1, 5) and Water.chance(Water.REACH + 0.1, 0) == 0,
		"the chance falls with the distance, halves after a long fall, and is nothing out of reach")
	local function trial(gentle: boolean, from: Vector3, drop: number, seed: number, day: number): (string, any)
		local w = Water.new(seed)
		w.gentle = gentle
		w:fall(from, drop, day, boxes, Pond.WATER)
		local got, sig = "", nil
		for _ = 1, 60 * 4 do
			w:step(1 / 60)
			for _, s in w:drainSignals() do if s.kind ~= "fell" then got, sig = s.kind, s end end
		end
		return got, sig
	end
	local outs, drowned, pulled = 0, 0, 0
	for seed = 1, 60 do
		local k = trial(false, near, 0, seed, 3)
		if k == "out" then outs += 1 elseif k == "drowned" then drowned += 1 end
		if trial(true, near, 0, seed, 3) ~= "drowned" then pulled += 1 end
	end
	print(`preserve: the water: of 60 slips by a pad 2 cm off, {outs} got out and {drowned} drowned in Normal; {pulled} pulled out in the gentle rules`)
	check(outs > 30 and drowned > 0 and outs + drowned == 60 and pulled == 60, "near a pad most get out in Normal and some drown; the gentle rules always pull it out")
	local long = 0
	for seed = 1, 30 do if trial(false, open, 40, seed, 5) == "drowned" then long += 1 end end
	local kind, sig = trial(true, open, 40, 7, 5)
	check(long == 30 and kind == "pulled" and sig.to ~= nil, "a long fall into open water drowns in Normal, honestly; the gentle rules carry it to something to climb")
	local w1, w2 = Water.new(11), Water.new(11)
	local k1 = trial(false, near, 0, 11, 4)
	local k2 = trial(false, near, 0, 11, 4)
	check(k1 == k2 and Water.draw(11, 4, 1) == Water.draw(11, 4, 1) and Water.draw(11, 4, 1) ~= Water.draw(11, 4, 2), "the same fall of the same day draws the same; the next fall draws anew")
	w1.falls, w1.out = 3, 2
	w2:load(w1:toRecord())
	check(w2.falls == 3 and w2.out == 2 and #Water.problems(w1:toRecord()) == 0 and #Water.problems({ falls = 1, out = 2 }) == 1 and #Water.problems({ falls = -1, out = 0 }) == 1
		and #Water.problems("x") == 1, "its record (the falls counted) kept and put back, a bad one refused")
	local w = Water.new(1)
	w:fall(near, 0, 1, boxes, Pond.WATER)
	local held = w:heldAt() :: Vector3
	check(w:struggling() and math.abs(held.Y - Pond.WATER) < 0.2 and WaterText.LINE ~= "" and WaterText.CAUSE == Water.CAUSE and string.find(WaterText.SUB, "cannot walk on water", 1, true) ~= nil,
		"struggling it is held at the surface; its card and its words")
end)

case("the pond's life: midges and mosquitoes on the rushes and the cattails, swarming from dusk; damselflies on the cattails; water striders on the open water, drawn to ripples", function()
	local Species = require("../src/Shared/Data/Species")
	local Skater = require("../src/Shared/Prey/Skater")
	local PreyText = require("../src/Shared/UI/PreyText")
	WorldMap.use("preserve")
	local kinds: { [string]: number } = {}
	local fine = true
	for _, r in WorldMap.regions() do
		if Pond.knows(r.kind) then
			for _, k in Garden.bestiary(r) or {} do
				kinds[k.kind] = (kinds[k.kind] or 0) + 1
				for _, p in k.perches do
					if not WorldMap.inBounds(p.position + p.normal * 0.31, r.id) or p.position.Y < Pond.WATER + 5 then fine = false; print("  " .. p.id) end
				end
			end
		end
	end
	check(fine and kinds.midge == 2 and kinds.mosquito == 2 and kinds.damselfly == 1, `midges in 2 cells, mosquitoes 2, damselflies 1, every perch on a stem over the water ({kinds.midge}, {kinds.mosquito}, {kinds.damselfly})`)
	local midge, damsel = Species.midge_prototype, Species.damselfly_prototype
	check(midge.body.dusk == "midge_dusk_prototype" and Species.midge_dusk_prototype.body.hover ~= nil and Species.mosquito_dusk_prototype.body.hover ~= nil
		and math.abs(midge.body.nutrition - 0.35 / 3) < 1e-9 and damsel.body.catch_factor > 1.4 and damsel.body.kick ~= nil and math.abs(damsel.body.nutrition - 0.35 * 2.5) < 1e-9,
		"midges and mosquitoes a third of a housefly, restless and hovering from dusk; the damselfly two and a half, a hard catch that thrashes")
	-- the striders: on the open water of their cells, skating; by a struggling spider's ripples they come
	local b3 = WorldMap.region("pond_b3") :: any
	local spec = (Garden.ambient(b3) :: any)[1]
	local sk = Skater.new(spec, spec.full)
	local okStart = #sk.items == 4
	for _, a in sk.items do
		local zw = Pond.waterline(a.position.X)
		if zw == nil or a.position.Z >= zw or math.abs(a.position.Y - (Pond.WATER + Skater.HOVER)) > 1e-6 then okStart = false end
	end
	check(okStart, "four water striders on the open water of the margin, up on their legs")
	local ripple = Vector3.new(b3.origin.X, Pond.WATER, b3.origin.Z)
	local before = 0
	for _, a in sk.items do before += (a.surface - ripple).Magnitude end
	for _ = 1, 60 * 12 do sk:step(1 / 60, Vector3.zero, { hour = 12, ripple = ripple }) end
	local after, inside = 0, true
	for _, a in sk.items do
		after += (a.surface - ripple).Magnitude
		if not sk:free(a.surface) then inside = false end
	end
	check(after < before and inside and #sk:problems(b3.bounds[1], b3.bounds[2]) == 0, string.format("by the ripples they skate in (%.0f studs all told to %.0f), never onto a pad or a stem", before, after))
	check(PreyText.REFUSED.skater ~= nil, "a strike at a strider is refused with its own words")
end)

case("the green frog: on its stone or its pad by a seeded day, still; what moves near it is faced and struck in the standard rules (missed in the gentle ones); keeping still saves", function()
	local Frog = require("../src/Shared/Predator/Frog")
	local FrogText = require("../src/Shared/UI/FrogText")
	local PondBodies = require("../src/Client/PondBodies")
	WorldMap.use("preserve")
	local seed = WorldMap.seed(WorldMap.SEED, "frog")
	local used = {}
	for day = 1, 20 do
		local s = Frog.seatOf(seed, day)
		used[s] = true
		check(s == Frog.seatOf(seed, day), "the same seat for the same day")
	end
	check(used[1] and used[2], "both seats used over twenty days")
	local f = Frog.new(seed)
	f:step(1 / 60, 3, nil)
	check(f.here and (f.pos - (Frog.seatAt(f.seat) :: Vector3)).Magnitude < 1e-6, "it sits on its seat")
	local function trial(gentle: boolean, offset: Vector3, speed: number, hidden: boolean): string?
		local t = Frog.new(seed)
		t.gentle = gentle
		t:step(1 / 60, 3, nil)
		local got = nil
		for _ = 1, 60 * 3 do
			t:step(1 / 60, 3, { pos = t.pos + offset, speed = speed, hidden = hidden })
			for _, s in t:drainSignals() do if s.kind == "struck" or s.kind == "missed" then got = got or s.kind end end
		end
		return got
	end
	local close = f.rest * 8 + Vector3.new(0, 1, 0)
	check(trial(false, close, 3, false) == "struck" and trial(true, close, 3, false) == "missed", "a spider moving in front of it within reach: struck in the standard rules, missed in the gentle ones")
	check(trial(false, close, 0, false) == nil and trial(false, close, 3, true) == nil and trial(false, f.rest * 40, 3, false) == nil,
		"keeping still, hidden, or out of its reach, nothing")
	local side = Vector3.new(-f.rest.Z, 0, f.rest.X) * 8 + Vector3.new(0, 1, 0)
	check(trial(false, side, 3, false) == "struck", "beside it, it turns to face what moved first, then strikes")
	-- its drawing at true size
	local parts = PondBodies.frogParts(0.5, 0)
	local zmin, zmax = math.huge, -math.huge
	for _, s in parts do
		local c = s.frame.Position
		if s.name == "Body" or s.name == "Head" or s.name == "Snout" then zmin, zmax = math.min(zmin, c.Z - s.size.Z / 2), math.max(zmax, c.Z + s.size.Z / 2) end
	end
	check(zmax - zmin >= 6.5 and zmax - zmin <= 9.5 and #parts <= 60, string.format("a green frog %.1f cm from snout to vent (the sources' 5 to 10), %d parts", zmax - zmin, #parts))
	check(FrogText.CAUSE == Frog.CAUSE and FrogText.LINE ~= "" and string.find(FrogText.SUB, "Keeping still", 1, true) ~= nil, "its card and its words")
	-- the darner: by day over the open water, away by night
	local at = Pond.darner(914, 12.5, 12)
	local none = Pond.darner(914, 12.5, 22)
	local mx, mz = Preserve.metres(at :: Vector3)
	check(at ~= nil and none == nil and ((mx - Preserve.POND.x) / Preserve.POND.rx) ^ 2 + ((mz - Preserve.POND.z) / Preserve.POND.rz) ^ 2 < 1.2 and (at :: Vector3).Y > Pond.WATER + 60,
		"the green darner over the pond by day, a metre up; away by night")
end)

-- ---------------------------------------------------------------- ROBLOX-126: the first meshes
case("the meshes: Chet's six at their verified sizes; a mesh record drawn as a textured FileMesh scaled to its box, turned a quarter when its long axis lies the other way", function()
	local Meshes = require("../src/Shared/Data/Meshes")
	local Scenery = require("../src/Shared/Habitat/Scenery")
	local n = 0
	for _, m in Meshes.list do n += 1; check(string.match(m.id, "^rbxassetid://%d+$") ~= nil and m.size.X > 0 and m.triangles > 0, "a mesh id and its size") end
	check(n == 6 and Meshes.of("Mesh:milkweed_leaf") == Meshes.list.milkweed_leaf and Meshes.of("Ellipsoid") == nil and Meshes.of(nil) == nil, "six meshes, named by a record's shape")
	local leaf = Meshes.list.milkweed_leaf
	local turned, scale = Meshes.fit(leaf, Vector3.new(14, 2.125, 39)) -- long along z, as the leaf is: no turn
	check(not turned and math.abs(scale.X - 2) < 1e-9 and math.abs(scale.Y - 1) < 1e-9 and math.abs(scale.Z - 2) < 1e-9, "a box the leaf's way: scaled, not turned")
	turned, scale = Meshes.fit(leaf, Vector3.new(39, 1.0625, 14)) -- long along x: a quarter turn
	check(turned and math.abs(scale.X - 2) < 1e-9 and math.abs(scale.Y - 0.5) < 1e-9 and math.abs(scale.Z - 2) < 1e-9, "a box across: turned a quarter, then scaled")
	local folder = Instance.new("Folder")
	Scenery.look(folder, { { id = "MeshLeaf", size = Vector3.new(39, 2.125, 14), at = Vector3.new(1, 2, 3), color = Color3.new(0.2, 0.5, 0.2), shape = "Mesh:milkweed_leaf", full = true } } :: any)
	local p = folder:FindFirstChild("MeshLeaf") :: any
	local mesh = p and p:FindFirstChildWhichIsA("SpecialMesh")
	check(mesh ~= nil and mesh.MeshType == Enum.MeshType.FileMesh and mesh.MeshId == leaf.id and mesh.TextureId == Meshes.TEXTURE, "drawn with the leaf's mesh and the atlas")
	check(p ~= nil and same(p.Size, Vector3.new(14, 2.125, 39)) and p.Color.R == 1 and p.Color.G == 1 and p.Color.B == 1 and p.CanCollide == false and p:GetAttribute("FullOnly") == true,
		"the part's box turned with it, white under the texture, drawn only, the full tier's")
end)

print(`PRESERVE passed={passed} failed={failed}`)
if failed > 0 then error("PRESERVE failed") end
