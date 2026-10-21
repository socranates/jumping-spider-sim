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

case("the map answers for the active world: the preserve's sill is the same sill, now with the hut round it (ROBLOX-116); the test garden comes back whole", function()
	local before = #WorldMap.regions()
	local lo0, hi0 = WorldMap.bounds()
	check(WorldMap.world() == "test_garden" and before > 10 and #WorldMap.drawn() == 0 and WorldMap.drawnZone("hut") == nil, "the test garden is active: its regions, no drawn zones")
	local gardenSill = WorldMap.region("sill") :: WorldMap.Region
	check(WorldMap.use("preserve") == "test_garden" and WorldMap.world() == "preserve" and WorldMap.revision() == "preserve-1", "the preserve made active (the test garden was)")
	local regions = WorldMap.regions()
	local sill = regions[1]
	check(#regions == 48 and sill.id == "sill" and sill.kind == "sill" and #sill.neighbors == 5, `forty-eight regions (ROBLOX-117: and the path round the east end), the sill first with its five seams into the hut ({#regions}, {#sill.neighbors})`)
	check(same(sill.bounds[1], Layout.PLAY_BOUNDS_MIN) and same(sill.bounds[2], Layout.PLAY_BOUNDS_MAX) and same(sill.spawn.pos, Layout.SPAWN) and same(sill.spawn.heading, Layout.SPAWN_HEADING)
		and sill.clockScale == 1.0 and sill.seed == gardenSill.seed and #sill.retreats == 1 and sill.retreats[1].id == "sill_crevice"
		and same(sill.retreats[1].min, Layout.RETREAT_MIN) and same(sill.retreats[1].max, Layout.RETREAT_MAX), "its numbers are the layout's, as the test garden's sill's")
	check(Region.pieces(sill) == Layout.PIECES and Region.decor(sill) == Layout.DECOR :: any, "its boxes are the layout's own tables, byte for byte")
	local lo, hi = WorldMap.bounds()
	check(lo.X <= -200 and hi.X >= 200 and lo.Z <= -416 and hi.Z >= 340 and lo.Y <= -87 and hi.Y >= 113.5, "the motor's fall-off box holds the hut and its garden")
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

-- ---------------------------------------------------------------- ROBLOX-116: the ranger hut and its garden, walkable (World/Hut)
local Hut = require("../src/Shared/World/Hut")
local Garden = require("../src/Shared/World/Garden")
local Route = require("../src/Shared/Predator/RivalRoute")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Nursery = require("../src/Shared/Life/Nursery")
local Nature = require("../src/Shared/Life/Nature")
local LifeText = require("../src/Shared/UI/LifeText")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")

local HUT_IDS = "sill,hut_window,hut_outer_sill,hut_desk,hut_board,hut_shelf,hut_chair,hut_door,hut_floor_a,hut_floor_b,hut_floor_c,hut_floor_d,hut_floor_e,hut_floor_f,"
	.. "hut_floor_g,hut_floor_h,hut_floor_i,hut_wall_mid,hut_wall_w,hut_wall_e,hut_bench,hut_butt,garden_feeder,garden_pole,garden_a1,garden_a2,garden_a3,garden_a4,"
	.. "garden_b1,garden_b2,garden_b3,garden_b4,garden_c1,garden_c2,garden_c3,garden_c4,garden_d1,garden_d2,garden_d3,garden_d4,"
	.. "path_s1,path_s2,path_e1,path_e2,path_e3,path_e4,path_e5,path_e6" -- (ROBLOX-117: the path round the hut's east end)

case("the hut's regions: the sill, the hut's inside, the way out and the garden's core, in priority order, each with its seed, spawn, retreats and pace", function()
	WorldMap.use("preserve")
	local ids = {}
	for _, r in WorldMap.regions() do table.insert(ids, r.id) end
	check(table.concat(ids, ",") == HUT_IDS, `in priority order ({table.concat(ids, ",")})`)
	local seeds: { [number]: boolean } = {}
	local okAll, homes = true, {}
	for _, r in WorldMap.regions() do
		local fine = r.seed == WorldMap.seed(WorldMap.SEED, r.id) and not seeds[r.seed] and r.bounds[1].X < r.bounds[2].X and r.bounds[1].Y < r.bounds[2].Y
			and r.bounds[1].Z < r.bounds[2].Z and WorldMap.at(r.spawn.pos + Vector3.new(0, 0.31, 0)) == r and r.clockScale > 0 and r.clockScale <= 1
			and (r.kind == "sill" or Hut.knows(r.kind)) and table.isfrozen(r) and table.isfrozen(r.neighbors)
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
	check(table.concat(homes, ",") == "garden_a1_trough,garden_a3_stone,garden_d3_mulch,hut_board_gap,hut_desk_drawer,sill_crevice", `the homes: {table.concat(homes, ", ")}`)
	for _, id in homes do check(LifeText.HOMES[id] ~= nil, `{id} has its words`) end
	-- the inside keeps the sill's day, the garden the garden's; the night's hunters never come inside
	local inside, outside = true, true
	for _, r in WorldMap.regions() do
		local indoor = Nature.INDOORS[r.kind] == true
		if string.sub(r.id, 1, 9) == "hut_floor" or r.id == "hut_desk" or r.id == "hut_board" or r.id == "hut_shelf" or r.id == "hut_chair" or r.id == "hut_window" then
			if not indoor or r.clockScale ~= 1.0 or Nature.exposed(true, r.kind, false) then inside = false end
		elseif string.sub(r.id, 1, 7) == "garden_" or r.id == "hut_bench" or r.id == "hut_butt" then
			if indoor or r.clockScale ~= 0.33 or not Nature.exposed(true, r.kind, false) then outside = false end
		end
	end
	check(inside, "the hut's inside is indoors, at the sill's pace (1.0), and never exposed to the night")
	check(outside, "the bench, the butt and the garden are outdoors at the garden's pace (0.33)")
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
	check(count == 2 * 78 and lines, `{count / 2} seams, each both ways along one line at both regions' bounds`)
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
	local full, low = 0, 0
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
			full += f; low += l
		end
	end
	check(okAll, "every region's look within its kind's budget at both tiers, the same list each time, known materials")
	print(`preserve: the hut's looks: {full} records at full, {low} at low`)
	check(low <= 60, `the low tier draws little of the hut beyond its boxes ({low} records)`)
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
	check(fine and counts.prey == 2 and counts.kinds == 8 and counts.bugs == 2 and counts.ambient == 3,
		`gnats and aphids in 2 cells, the bestiary's kinds 8 times (ROBLOX-117: with the hoverflies on three cells' flowers, the fruit flies at the caddy, the moth at the lamp), woodlice in 2, ambient bugs in 3 (found {counts.prey}, {counts.kinds}, {counts.bugs}, {counts.ambient}), every perch on a face`)
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
	local chain = { "hut_door", "path_s1", "path_s2", "path_e1", "path_e2", "path_e3", "path_e4", "path_e5", "path_e6", "garden_b4" }
	local linked = true
	for i = 1, #chain - 1 do
		local a = WorldMap.region(chain[i]) :: WorldMap.Region
		local found = false
		for _, n in a.neighbors do if n.id == chain[i + 1] then found = true end end
		if not found then linked = false; print(`  {chain[i]} does not meet {chain[i + 1]}`) end
	end
	check(linked, "the door's gravel, eight lengths of path and the garden's own path meet seam to seam")
	local fine = true
	for _, w in Hut.WALK do
		local r = WorldMap.region(w.id) :: WorldMap.Region
		local pieces = Region.pieces(r)
		if r.kind ~= "hut_path" or r.clockScale ~= 0.33 or #pieces ~= 1 or pieces[1].material ~= "Pebble" or math.abs(pieces[1].hi.Y - Hut.GROUND) > 1e-6 then fine = false end
		if w.x0 < 178 - 1e-6 and w.z0 < 287 - 1e-6 then fine = false; print("  " .. w.id .. " in the hut") end
	end
	check(fine, "each a length of gravel at the garden's ground, outdoors at the garden's pace, clear of the hut's logs and base")
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
	check(#patches >= cells * 16 and #patches < 400, `{#patches} patches over the garden's {cells} cells and the path's {paths} lengths`)
	local fine, dews, worstFull, worstLow = true, 0, 0, 0
	local B = Region.budget("patch", "full") :: number
	for _, p in patches do
		local parent = Hut.patchParent(p) :: any
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
	local florets, midribs = 0, 0
	for _, d in c3 do
		if string.sub(d.id, 1, 6) == "Floret" then florets += 1 end
		if string.sub(d.id, 1, 6) == "Midrib" then midribs += 1 end
	end
	check(florets >= 30 and midribs >= 12, `the milkweed's umbels ({florets} florets) and its leaves' pale midribs ({midribs})`)
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

print(`PRESERVE passed={passed} failed={failed}`)
if failed > 0 then error("PRESERVE failed") end
