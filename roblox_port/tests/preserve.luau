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

case("the worlds: the test garden and the preserve, the test garden the default until Phase B, any other value the default", function()
	check(Worlds.DEFAULT == "test_garden" and Worlds.ATTRIBUTE == "World" and #Worlds.IDS == 2 and Worlds.IDS[1] == "test_garden" and Worlds.IDS[2] == "preserve", "two worlds, the test garden first and the default")
	check(Worlds.choose(nil) == "test_garden" and Worlds.choose("preserve") == "preserve" and Worlds.choose("test_garden") == "test_garden" and Worlds.choose("Preserve") == "test_garden"
		and Worlds.choose(7) == "test_garden", "an attribute names a world exactly, anything else is the default")
	check(Worlds.get("test_garden").revision == WorldMap.REVISION and Worlds.get("preserve").revision == "preserve-1", "the test garden's revision is the map's, the preserve's its own")
	check(Worlds.get("test_garden").name == "The Test Garden" and Worlds.get("preserve").name == "The Preserve", "their names")
	check(not pcall(Worlds.get, "garden") and not pcall(WorldMap.use, "garden"), "no world by another name")
end)

case("the map answers for the active world: the preserve's one region is the sill, the same sill, with no neighbours; the test garden comes back whole", function()
	local before = #WorldMap.regions()
	local lo0, hi0 = WorldMap.bounds()
	check(WorldMap.world() == "test_garden" and before > 10 and #WorldMap.drawn() == 0 and WorldMap.drawnZone("hut") == nil, "the test garden is active: its regions, no drawn zones")
	local gardenSill = WorldMap.region("sill") :: WorldMap.Region
	check(WorldMap.use("preserve") == "test_garden" and WorldMap.world() == "preserve" and WorldMap.revision() == "preserve-1", "the preserve made active (the test garden was)")
	local regions = WorldMap.regions()
	local sill = regions[1]
	check(#regions == 1 and sill.id == "sill" and sill.kind == "sill" and #sill.neighbors == 0, "one region, the sill, with no seams")
	check(same(sill.bounds[1], Layout.PLAY_BOUNDS_MIN) and same(sill.bounds[2], Layout.PLAY_BOUNDS_MAX) and same(sill.spawn.pos, Layout.SPAWN) and same(sill.spawn.heading, Layout.SPAWN_HEADING)
		and sill.clockScale == 1.0 and sill.seed == gardenSill.seed and #sill.retreats == 1 and sill.retreats[1].id == "sill_crevice"
		and same(sill.retreats[1].min, Layout.RETREAT_MIN) and same(sill.retreats[1].max, Layout.RETREAT_MAX), "its numbers are the layout's, as the test garden's sill's")
	check(Region.pieces(sill) == Layout.PIECES and Region.decor(sill) == Layout.DECOR :: any, "its boxes are the layout's own tables, byte for byte")
	local lo, hi = WorldMap.bounds()
	check(same(lo, Layout.PLAY_BOUNDS_MIN) and same(hi, Layout.PLAY_BOUNDS_MAX), "the motor's fall-off box is the sill's")
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
	check(hutBox[1].X <= -175 and hutBox[2].X >= 175 and hutBox[1].Z <= -16 and hutBox[2].Z >= 284, "the hut's zone holds the hut (x -175..175, z -16..284)")
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
		check(plan.hut == top and plan.hut_garden == top and plan.ground == top, `{tier}: the hut, its garden and the ground at the tier's detail from the sill`)
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
		local path = { sill.spawn.pos, Preserve.at(45.5, 13, 0.01), Preserve.at(20, 20, 0.01), Preserve.at(20, 46, 0.01), Preserve.at(58, 49, 0.01), Preserve.at(70, 30, 0.4), Preserve.at(93, 30, 1.2),
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
	check(at(a.Position, keys[1].eye) and fa == keys[1].fov and at(b.Position, TitleShots.DRIFT[1].eye) and fb == TitleShots.DRIFT[1].fov
		and at(c.Position, TitleShots.DRIFT[1].eye), "the preserve's from its first key; nil and an unknown world are the test garden's")
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
	check(#TitleShots.preserveViews() == 3 and TitleShots.preserveViews()[1].name == "preserve_drift_0", "its three frames for the previewer")
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

print(`PRESERVE passed={passed} failed={failed}`)
if failed > 0 then error("PRESERVE failed") end
