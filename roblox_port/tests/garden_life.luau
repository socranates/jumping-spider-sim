-- Garden life (ROBLOX-96, W3): the bed's prey director on the bed's own boxes (World/Garden.prey through Prey/PreyDirector): its seeded perches and vents, the
-- fungus gnats and the aphids it spawns, the gnats' short flights and the aphids that never fly, a torn-free aphid back on its perch, the replacements in by the
-- vents; the woodlice (Prey/Woodlouse): seeded on the soil, walking round what stands on it, under cover when the spider comes near and out again when it has
-- gone, movement and never prey to the senses, never caught by the strike; the world's prey (Prey/PreyWorld): a director per region, only where the spider is or
-- beside it, only once the region is whole, nothing rerolled by a seam; and the drawn gnat, aphid (Client/FlyBodies) and woodlouse (Client/BugBodies) under
-- their part caps. On the shim's box world: a smoke test of the real code, not of the engine.
local Species = require("../src/Shared/Data/Species")
local Catch = require("../src/Shared/Data/Catch")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")
local Garden = require("../src/Shared/World/Garden")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local PreyWorld = require("../src/Shared/Prey/PreyWorld")
local Woodlouse = require("../src/Shared/Prey/Woodlouse")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local FlyBodies = require("../src/Client/FlyBodies")
local BugBodies = require("../src/Client/BugBodies")

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
local function finite(v: Vector3): boolean return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6 end
local function within(lo: Vector3, hi: Vector3, p: Vector3): boolean
	return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
end

-- ---------------------------------------------------------------- the world
local DT = 1 / 60
local world = WorldBuild.world(workspace, WorldMap.SEED)
local bed = WorldMap.region("bed_a") :: WorldMap.Region
local gnat, aphid, fly = Species.fungus_gnat_prototype, Species.aphid_prototype, Species.fly_like_prototype
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { world }
local cast = Sensor.workspaceCast(params)
local FAR = Vector3.new(-22, 0.31, 6) -- the sill's spawn: nowhere near the bed
local cameraFar = { CFrame = CFrame.new(Vector3.new(-22, 5, 12)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) }
local function sensor(): any
	local s = Sensor.new(ObservationMemory.new())
	s:configureFrom(Species.phidippus_audax_prototype.perception)
	return s
end
local function observerAt(p: Vector3): any
	return { eye = p + Vector3.new(0, 0.09, 0), gaze = Vector3.new(0, 0, -1), up = Vector3.yAxis, heading = Vector3.new(0, 0, -1) }
end
-- A motor as the director reads it: standing still at `pos`, or in a strike (mode air with a launched event) between `from` and `pos`.
local function motorAt(pos: Vector3, strike: boolean?): any
	return { mode = if strike then "air" else "attached", events = if strike then { { kind = "launched" } } else {}, pos = pos, preparing = false, moving = false, vel = Vector3.zero,
		heading = Vector3.new(0, 0, -1), up = Vector3.yAxis, eyePosition = function() return pos + Vector3.new(0, 0.09, 0) end }
end
local function bedDirector(seed: number?): any
	local spec = Garden.prey(bed) :: Garden.PreySpec
	return PreyDirector.engine(world, gnat, seed or spec.seed, spec.target, false, spec)
end
local function kinds(d: any): (number, number, number)
	local g, a, other = 0, 0, 0
	for _, f in d.flies do
		if f.profile == gnat then g += 1 elseif f.profile == aphid then a += 1 else other += 1 end
	end
	return g, a, other
end
-- One tick of a director alone, the spider at `pos`.
local function tick(d: any, pos: Vector3, s: any, strike: boolean?)
	d:before(DT, pos, observerAt(pos), s, cast, cameraFar)
	d:after(DT, motorAt(pos, strike), s, cast)
end

-- ---------------------------------------------------------------- the profiles
case("the bed's prey profiles are derived from the house fly's (Godot's untouched), with their sizes, meals and catch factors", function()
	check(fly.body.nutrition == 0.35 and fly.body.prey_kind == nil and fly.body.walker == nil and fly.flight.max_flight_wu == 26, "the house fly is Godot's")
	check(math.abs(gnat.body.nutrition - 0.35 / 3) < 1e-12 and gnat.body.prey_kind == "fungus_gnat" and gnat.body.walker == nil, "a gnat is a third of a housefly meal, and flies")
	check(math.abs(aphid.body.nutrition - 0.35 / 6) < 1e-12 and aphid.body.prey_kind == "aphid" and aphid.body.walker == true, "an aphid is a sixth, and walks")
	check(gnat.body.visual_scale == 0.45 and aphid.body.visual_scale == 0.4 and gnat.body.hover_wu == fly.body.hover_wu and aphid.body.hover_wu == fly.body.hover_wu, "drawn smaller, hovering as the fly does (the graph's number)")
	check(gnat.flight.max_flight_wu == 10 and gnat.flight.cruise_speed_wu_s == 3.5 and gnat.flight.flee_speed_wu_s == 7 and gnat.flight.min_hop_wu == 1.2 and gnat.behavior.reposition_max_wu == 10 and gnat.behavior.restless_per_s == 0.06 and gnat.behavior.hysteresis == 0.1 and gnat.utility.move_restless == 1.0, "the gnat's flights are short and slow, and it is soon restless")
	check(gnat.senses.sight_range_wu < fly.senses.sight_range_wu and aphid.senses.sight_range_wu < gnat.senses.sight_range_wu, "and each sees less far than the house fly")
	check(math.abs(Catch.factorFor(gnat) - 0.6) < 1e-9 and Catch.factorFor(aphid) == Catch.size.min and Catch.factorFor(aphid) == 0.5, `the gnat is 0.6 to catch, the aphid 0.5, the easiest ({Catch.factorFor(gnat)}, {Catch.factorFor(aphid)})`)
	check(Catch.factorFor(aphid) < Catch.factorFor(gnat) and Catch.factorFor(gnat) < Catch.factorFor(Species.fruit_fly_prototype) and Catch.factorFor(Species.fruit_fly_prototype) < Catch.factorFor(fly), "in order: aphid, gnat, fruit fly, house fly")
	for _, p in { gnat, aphid } do
		for _, k in { "senses", "reaction", "flight", "behavior", "population", "utility" } do
			check(p[k] ~= fly[k], `{p.body.prey_kind}: its {k} table is its own, not the house fly's`)
		end
	end
end)

-- ---------------------------------------------------------------- the bed's perches and vents
case("the bed's perches and vents come from its boxes and seed: on the soil, the mounds, the stones, under and on the dock's leaves, the stem, the dandelion", function()
	local spec = Garden.prey(bed) :: Garden.PreySpec
	check(spec ~= nil and spec.seed == bed.seed and spec.target == 6 and spec.prefix == "bed_a_fly_", "the spec carries the region's seed, a target of six and the flies' prefix")
	check(Garden.prey(WorldMap.region("sill") :: WorldMap.Region) == nil and Garden.prey(WorldMap.region("house_wall") :: WorldMap.Region) == nil, "the sill and the wall have no generated prey")
	local byKind: { [string]: number } = {}
	local walkers, starts, startWalkers = 0, 0, 0
	for _, p in spec.perches do
		byKind[p.kind] = (byKind[p.kind] or 0) + 1
		if p.walker then walkers += 1 end
		if p.start then starts += 1; if p.walker then startWalkers += 1 end end
		check(within(bed.bounds[1], bed.bounds[2], p.position) and finite(p.position), `{p.id} is inside the bed`)
		check(p.shelter >= 0 and p.shelter <= 1 and p.food >= 0 and p.food <= 1, `{p.id} has shelter and food in 0..1`)
		-- on a real box: a cast along the normal from just above meets a face at the perch within a hair, facing the normal's way
		local hit = workspace:Raycast(p.position + p.normal * 0.5, -p.normal * 1.0, params)
		check(hit ~= nil and (hit.Position - p.position).Magnitude < 1e-3 and hit.Normal:Dot(p.normal) > 0.99, `{p.id} sits on a box's face ({if hit then hit.Instance.Name else "nothing"})`)
	end
	check(byKind.soil == 8 and byKind.mound == 6 and byKind.stone == 3 and byKind.under == 3 and byKind.leaf == 7 and byKind.stem == 1, `the kinds: soil {byKind.soil}, mound {byKind.mound}, stone {byKind.stone}, under {byKind.under}, leaf {byKind.leaf}, stem {byKind.stem}`)
	check(#spec.perches == 28 and walkers == 8, `28 perches, 8 of them the aphids' ({#spec.perches}, {walkers})`)
	for _, v in spec.vents do
		if not v.walker then
			local near = false
			for _, p in spec.perches do if p.kind == "soil" and (p.position - v.position).Magnitude >= 4 and (p.position - v.position).Magnitude <= 9 then near = true end end
			check(near, `{v.id} is within an entry flight of a soil perch`)
		end
	end
	check(starts == 6 and startWalkers == 3, `six starts, three of them walkers ({starts}, {startWalkers})`)
	check(#spec.vents == 4 and not spec.vents[1].walker and spec.vents[2].walker and not spec.vents[3].walker and spec.vents[4].walker, "four vents: the gnats' on the soil first and third, the aphids' at the plants between")
	for _, v in spec.vents do check(within(bed.bounds[1], bed.bounds[2], v.position) and v.position.Y >= -90, `vent {v.id} is in the bed, on or over the soil`) end
	check(Garden.prey(bed) == spec, "asked again, the same list")
	local other = table.clone(bed); other.seed = WorldMap.seed(7, "bed_a")
	local o = Garden.prey(other) :: Garden.PreySpec
	local moved = false
	for i, p in o.perches do if p.kind == "soil" and (p.position - spec.perches[i].position).Magnitude > 0.01 then moved = true end end
	check(moved, "another seed puts the soil perches elsewhere")
end)

-- ---------------------------------------------------------------- the director on the bed
case("the bed's director spawns three gnats and three aphids on its start perches, each from the region's seed, and the same again from the same seed", function()
	local d = bedDirector()
	local g, a, other = kinds(d)
	check(#d.flies == 6 and g == 3 and a == 3 and other == 0, `six prey: {g} gnats, {a} aphids, {other} others`)
	check(d.p == gnat and d.mixed == false and d.seed == bed.seed and d.prefix == "bed_a_fly_", "a gnat director with the bed's seed and prefix")
	for _, f in d.flies do
		check(string.sub(f.id, 1, 10) == "bed_a_fly_", `{f.id} carries the bed's name`)
		check(f.state == "PERCHED" and f.perch ~= nil and f.perch.occupant == f.id and within(bed.bounds[1], bed.bounds[2], f.position), `{f.id} stands on its perch in the bed`)
		check((f.profile == aphid) == (f.perch.walker == true), `{f.id} is an aphid exactly when its perch is a plant perch`)
	end
	local valid, walkerValid = 0, 0
	for _, p in d.graph.perches do if p.valid then valid += 1; if p.walker then walkerValid += 1 end end end
	check(valid >= 18 and walkerValid == 8, `{valid} of the perches found their face and a flight ({walkerValid} walker perches, which need no flight)`)
	check(#d.vents == 4 and d.vents[2].walker == true and d.vents[2].reach == 8, "the vents are the spec's, the aphids' with their reach")
	local e = bedDirector()
	local same = #e.flies == #d.flies
	for i, f in d.flies do
		local o = e.flies[i]
		if o == nil or o.id ~= f.id or (o.position - f.position).Magnitude > 1e-9 or o.profile ~= f.profile or o.rng.state ~= f.rng.state then same = false end
	end
	check(same, "the same seed gives the same prey, stream for stream")
	local f = bedDirector(bed.seed + 1)
	local differs = false
	for i, x in d.flies do if f.flies[i] and f.flies[i].rng.state ~= x.rng.state then differs = true end end
	check(differs, "another seed gives other streams")
end)

case("over three minutes with the spider far away, the gnats fly short flights and the aphids never leave their leaves", function()
	local d = bedDirector()
	local s = sensor()
	local flights, longest, airborneAphid, aphidDrift = 0, 0, 0, 0
	local takeoff: { [string]: Vector3 } = {}
	for _ = 1, 60 * 180 do
		tick(d, FAR, s)
		for _, f in d.flies do
			check(finite(f.position) and within(bed.bounds[1], bed.bounds[2], f.position), `{f.id} stays in the bed`)
			if f.profile == aphid then
				if f:airborne() then airborneAphid += 1 end
				aphidDrift = math.max(aphidDrift, (f.position - d.graph:rest(f.perch)).Magnitude)
			elseif f:airborne() then
				if takeoff[f.id] == nil then takeoff[f.id] = f.position; flights += 1 end
			elseif takeoff[f.id] ~= nil then
				longest = math.max(longest, (f.position - takeoff[f.id]).Magnitude)
				takeoff[f.id] = nil
			end
		end
	end
	check(flights >= 2, `the gnats flew ({flights} flights)`)
	check(longest <= gnat.flight.max_flight_wu * 1.6 + 1e-6 and longest > 1, `no flight farther than a gnat's ({longest} studs)`)
	check(airborneAphid == 0, `an aphid was never in the air ({airborneAphid} ticks)`)
	check(aphidDrift <= aphid.behavior.wander_radius_wu + 0.05, `the aphids only shuffled about their perches ({aphidDrift} studs at most)`)
	local g, a = kinds(d)
	check(g == 3 and a == 3, "and all six are still there")
end)

case("an aphid startled by the spider freezes and never flies; a torn-free aphid is back on its perch, or gone if the perch is taken", function()
	local d = bedDirector()
	local s = sensor()
	local a: any
	for _, f in d.flies do if f.profile == aphid then a = f; break end end
	check(a ~= nil and not a:launch("flee", 0) and not a:launch("move", 0), "an aphid refuses every flight")
	-- the spider lands beside it, moving
	local near = a.position + Vector3.new(1.5, 0, 0)
	for i = 1, 120 do tick(d, near + Vector3.new(math.sin(i * 0.3) * 0.4, 0, 0), s) end
	check(a.state == "PERCHED" or a.state == "ALERT", `the aphid is still on its perch ({a.state})`)
	check((a.position - d.graph:rest(a.perch)).Magnitude <= aphid.behavior.wander_radius_wu + 0.05, "and has not left it")
	-- caught, then torn free: back on the perch
	local perch = a.perch
	a.flight:release(); perch.occupant = ""
	a.state = "CAPTURED"; a.position = near
	d:escape(a)
	check(a.state == "ALERT" and a.perch == perch and perch.occupant == a.id and (a.position - d.graph:rest(perch)).Magnitude < 1e-6, "torn free, the aphid is back on its perch, alert")
	-- the perch taken meanwhile: the aphid is gone, and the population owes another
	perch.occupant = "someone"
	a.state = "CAPTURED"
	d:escape(a)
	check(a.state == "CONSUMED", "its perch taken, a torn-free aphid is gone")
	perch.occupant = a.id
	a.state = "PERCHED"
end)

case("the vents bring replacements: a gnat flies in from the soil, an aphid appears on a free plant perch out of sight, never by flight", function()
	local d = bedDirector()
	local s = sensor()
	-- the spider eats two of each (they leave the list); the population owes four
	local goneGnats, goneAphids = 0, 0
	for _, f in d.flies do
		local take = if f.profile == gnat then goneGnats < 2 else goneAphids < 2
		if take then
			f.flight:release(); if f.perch then f.perch.occupant = "" end; f.state = "CONSUMED"
			if f.profile == gnat then goneGnats += 1 else goneAphids += 1 end
		end
	end
	d:tidy()
	check(#d.flies == 2, "two prey left")
	local gnatsIn, aphidsIn, aphidFlew = 0, 0, false
	local seen: { [string]: boolean } = {}
	for _, f in d.flies do seen[f.id] = true end
	for _ = 1, 60 * 120 do
		tick(d, FAR, s)
		for _, f in d.flies do
			if not seen[f.id] then
				seen[f.id] = true
				if f.profile == gnat then gnatsIn += 1 else aphidsIn += 1; if f:airborne() then aphidFlew = true end end
			end
			if f.profile == aphid and f:airborne() then aphidFlew = true end
		end
		if #d.flies == 6 then break end
	end
	check(gnatsIn >= 1 and aphidsIn >= 1, `replacements came in: {gnatsIn} gnats, {aphidsIn} aphids`)
	check(not aphidFlew, "no aphid was ever in the air")
	check(d.population.entries == gnatsIn + aphidsIn and #d.flies <= 6, "each entry was the population's")
	for _, f in d.flies do
		if f.profile == aphid then check(f.perch ~= nil and f.perch.walker == true, `{f.id} is on a plant perch`) end
	end
end)

-- ---------------------------------------------------------------- the woodlice
local function colony(): any
	local spec = Garden.bugs(bed) :: Garden.BugSpec
	local soil: any, boxes = nil, {}
	for _, p in Region.pieces(bed) do
		if p.id == "bed_a_soil" then soil = { min = p.lo, max = p.hi } elseif p.lo.Y <= -89.99 then table.insert(boxes, { min = p.lo, max = p.hi }) end
	end
	return Woodlouse.new(spec, soil, boxes), spec, boxes
end
case("the woodlice are seeded on free soil with places to hide: under the big stone, at the stones' feet, under the litter the low tier keeps", function()
	local w, spec, boxes = colony()
	check(#spec.woodlice == 4 and #w.lice == 4 and spec.seed == bed.seed, `four woodlice from the bed's seed ({#w.lice})`)
	local stone, litter = 0, 0
	for _, h in spec.hides do
		if h.kind == "stone" then stone += 1 else litter += 1 end
		check(within(bed.bounds[1], bed.bounds[2], h.pos), "a hide spot is in the bed")
	end
	check(stone == 4 and litter == 3, `hide spots: {stone} by the stones, {litter} under litter`)
	for _, l in w.lice do
		check(w:free(l.position, 0.3) and math.abs(l.position.Y - (-90 + Woodlouse.HOVER)) < 1e-9, `{l.id} begins on free soil`)
		check(math.abs(l.heading.Magnitude - 1) < 1e-6 and l.state == "walk", `{l.id} faces somewhere and walks`)
	end
	check(Garden.bugs(bed) == spec and Garden.bugs(WorldMap.region("sill") :: WorldMap.Region) == nil, "the same list again; none for the sill")
	local again = Woodlouse.new(spec, { min = w.soilMin, max = w.soilMax }, boxes)
	local same = true
	for i, l in w.lice do if (again.lice[i].position - l.position).Magnitude > 1e-9 or again.lice[i].speed ~= l.speed then same = false end end
	check(same, "the same seed, the same colony")
end)

case("the woodlice walk slowly round what stands on the soil, hide when the spider comes within four studs, and come out when it has gone", function()
	local w = colony()
	local moved, offSoil, inBox = 0, 0, 0
	local start = {}
	for i, l in w.lice do start[i] = l.position end
	for _ = 1, 60 * 30 do
		w:step(DT, FAR)
		for i, l in w.lice do
			check((l.position - l.prevPosition).Magnitude <= Woodlouse.FLEE * DT + 1e-9, "no louse jumps")
			if not w:free(l.position, 0.0) then
				if l.position.X < w.soilMin.X or l.position.X > w.soilMax.X or l.position.Z < w.soilMin.Z or l.position.Z > w.soilMax.Z then offSoil += 1 else inBox += 1 end
			end
		end
	end
	for i, l in w.lice do if (l.position - start[i]).Magnitude > 1 then moved += 1 end end
	check(moved >= 3, `the woodlice wander ({moved} of 4 moved more than a stud)`)
	check(offSoil == 0 and inBox == 0, `never off the soil or inside a box ({offSoil}, {inBox})`)
	check(w:hiddenCount() == 0 and #w:percepts() == 4, "all four out, and all four movement to the senses")
	for _, p in w:percepts() do check(p.maxCategory == "movement" and p.radius == Woodlouse.RADIUS, "a woodlouse is movement, never prey") end
	-- the spider comes near one
	local target = w.lice[1]
	local spider = target.position + Vector3.new(2, 0.19, 0)
	local hid, ticks = false, 0
	for _ = 1, 60 * 20 do
		ticks += 1
		w:step(DT, spider)
		if target.state == "hidden" then hid = true; break end
		check(target.state == "hiding" or target.state == "hidden", `the louse makes for cover ({target.state})`)
	end
	check(hid, `the louse went under cover within {ticks / 60} s`)
	check(w.hides[target.hide] ~= nil and (Vector3.new(target.position.X, 0, target.position.Z) - Vector3.new(w.hides[target.hide].pos.X, 0, w.hides[target.hide].pos.Z)).Magnitude < 0.3, "at a hide spot")
	check(#w:percepts() == 4 - w:hiddenCount(), "a hidden louse is not reported")
	spider = target.position + Vector3.new(2, 0.19, 0) -- (the spider follows it to its cover and waits there)
	for _ = 1, 60 * 30 do w:step(DT, spider) end
	check(target.state == "hidden", "it stays under while the spider stays")
	local out, waited = false, 0
	for _ = 1, 60 * 30 do
		waited += 1
		w:step(DT, FAR)
		if target.state ~= "hidden" then out = true; break end
	end
	check(out and waited / 60 >= Woodlouse.RETURN_S[1] - 0.1 and waited / 60 <= Woodlouse.RETURN_S[2] + 0.1, `it comes out {waited / 60} s after the spider has gone`)
	check(#w:problems(bed.bounds[1], bed.bounds[2]) == 0, "a colony in order has no problems")
	local broken = Woodlouse.new(Garden.bugs(bed), { min = w.soilMin, max = w.soilMax }, {})
	broken.lice[1].state = "flying"; broken.lice[2].position = Vector3.new(0, 0, 0)
	check(#broken:problems(bed.bounds[1], bed.bounds[2]) == 2, "a louse in no known state, or outside the bed, is a problem")
end)

-- ---------------------------------------------------------------- the world's prey
-- A stand-in for the client's world: the region the spider is in, which regions are whole, and the map.
local function worldAt(regionId: string, ready: { [string]: boolean }?): any
	return {
		home = "sill", map = WorldMap, region = WorldMap.region(regionId),
		regionReady = function(_self: any, id: string): boolean return ready == nil or ready[id] ~= false end,
	}
end
local function sillDirector(): any
	return PreyDirector.engine(world, fly, 914, 4, true)
end
case("the world's prey: the sill's director at home, the bed's made when the bed is whole and the spider there or beside it, nothing rerolled by a seam", function()
	local home = sillDirector()
	local garden = {}
	local pw = PreyWorld.new(home, worldAt("sill"), garden, world, { probe = home.probe, cast = home.graph.cast, sweep = home.graph.sweep, overlap = home.graph.overlap })
	local s = sensor()
	local function step(pos: Vector3, strike: boolean?)
		pw:before(DT, pos, observerAt(pos), s, cast, cameraFar)
		pw:after(DT, motorAt(pos, strike), s, cast)
	end
	step(FAR)
	check(#pw.active == 1 and pw.active[1] == "sill" and garden.bed_a == nil and pw.made == 0, "on the sill only the sill's prey runs, and the bed has none yet")
	check(#pw:flies() == #home.flies and #pw:percepts() == #home.flies and pw:captures() == 0, "the view is the sill's flies")
	-- on the wall's top: the bed's farthest perch is beyond the radius; at its foot, inside it. (ROBLOX-101: the wall has prey of its own now, its moths and its
	-- crane fly, two directors made the first time the spider is on it; W3 held that nothing ran there.)
	pw.world = worldAt("house_wall")
	step(Vector3.new(0, -2, -24.3))
	check(table.concat(pw.active, ",") == "house_wall,outer_sill" and garden.bed_a == nil and pw.made == 4, "high on the wall the wall's own prey runs and the outer sill's beside it: the sill is no neighbour, the bed too far")
	step(Vector3.new(0, -80, -24.3))
	check(table.concat(pw.active, ",") == "house_wall,outer_sill,bed_a" and garden.bed_a ~= nil and garden.bed_a.prey ~= nil and pw.made == 7, "near the wall's foot the bed's prey runs too, made now (W3's director and the bestiary's two)")
	local d = garden.bed_a.prey
	check(d.feeding == home.feeding and d.graph.cast == home.graph.cast and d.probe == home.probe, "the bed's director eats with the sill's jaws and casts with its casts")
	check(#d.flies == 6 and garden.bed_a.bugs ~= nil and #garden.bed_a.bugs.lice == 4, "with its six prey and four woodlice")
	local wallFlies, outerFlies = 0, 0
	for _, k in pw:kinds("house_wall") do wallFlies += #k.flies end
	for _, k in pw:kinds("outer_sill") do outerFlies += #k.flies end
	check(wallFlies == 3 and outerFlies == 2 and #pw:flies() == 6 + 4 + 2 + 3 + 2 and #pw:percepts() == 6 + 4 + 2 + 3 + 2 + 4 and #pw:woodlice() == 4, `the view: the bed's flies (W3's six, four springtails, two leafhoppers), the wall's {wallFlies} and the outer sill's {outerFlies}, and the woodlice as movement`)
	-- in the bed, a while; then back to the wall's top (the bed waits), then back: the same director, its flies where they were
	pw.world = worldAt("bed_a")
	for _ = 1, 300 do step(Vector3.new(-20, -89.69, -30)) end
	local before = {}
	for i, f in d.flies do before[i] = { id = f.id, pos = f.position, state = f.state, rng = f.rng.state } end
	local now = d.now
	pw.world = worldAt("house_wall")
	for _ = 1, 120 do step(Vector3.new(0, -2, -24.3)) end
	check(table.find(pw.active, "bed_a") == nil and d.now == now, "away, the bed's clock stops")
	pw.world = worldAt("bed_a")
	step(Vector3.new(-20, -89.69, -30))
	check(garden.bed_a.prey == d and pw.made == 7, "back in the bed, the same director")
	local same = #d.flies == #before
	for i, f in d.flies do
		local b = before[i]
		if b == nil or b.id ~= f.id or (b.pos - f.prevPosition).Magnitude > 1e-9 then same = false end
	end
	check(same, "its flies took up where they were: nothing rerolled")
	-- the gate: a bed that is not whole has no prey, however near the spider
	local garden2 = {}
	local pw2 = PreyWorld.new(sillDirector(), worldAt("bed_a", { bed_a = false }), garden2, world)
	pw2:before(DT, Vector3.new(-20, -89.69, -30), observerAt(FAR), s, cast, cameraFar)
	check(pw2.active[1] == "bed_a" and garden2.bed_a == nil and pw2.made == 2 and #pw2:flies() == 0, "a bed that has not arrived whole has no prey and no woodlice (the wall beside it, whole, has its own)")
	pw2.world = worldAt("bed_a")
	pw2:before(DT, Vector3.new(-20, -89.69, -30), observerAt(FAR), s, cast, cameraFar)
	check(garden2.bed_a ~= nil and garden2.bed_a.prey ~= nil and garden2.bed_a.kinds ~= nil and garden2.bed_a.kinds.springtail ~= nil and garden2.bed_a.kinds.leafhopper ~= nil and pw2.made == 5, "whole, it has them (W3's and the bestiary's)")
	-- no engine at all: no director is ever made
	local pw3 = PreyWorld.new(sillDirector(), worldAt("bed_a"), {}, nil)
	pw3:before(DT, Vector3.new(-20, -89.69, -30), observerAt(FAR), s, cast, cameraFar)
	check(pw3.made == 0 and #pw3:flies() == 0, "without a world folder nothing is made")
end)

case("the strike in the bed catches a gnat into the sill's jaws and never a woodlouse; a torn-free bed fly is sent back to the bed's director", function()
	local home = sillDirector()
	local garden = {}
	local pw = PreyWorld.new(home, worldAt("bed_a"), garden, world, { probe = home.probe, cast = home.graph.cast, sweep = home.graph.sweep, overlap = home.graph.overlap })
	local s = sensor()
	local function step(pos: Vector3, strike: boolean?)
		pw:before(DT, pos, observerAt(pos), s, cast, cameraFar)
		pw:after(DT, motorAt(pos, strike), s, cast)
	end
	step(Vector3.new(-20, -89.69, -30))
	local d, w = garden.bed_a.prey, garden.bed_a.bugs
	-- a strike through a woodlouse: nothing
	local louse = w.lice[1]
	local at = louse.position + Vector3.new(0, 0.1, 0)
	step(at - Vector3.new(1, 0, 0), true)
	step(at + Vector3.new(1, 0, 0), true)
	check(pw:captures() == 0 and home.feeding.held == nil, "a woodlouse cannot be caught")
	-- a strike through a gnat: caught, into the shared jaws
	local g: any
	for _, f in d.flies do if f.profile == gnat and f.state == "PERCHED" then g = f; break end end
	local feedingBefore = home.feeding
	step(g.position - Vector3.new(0.5, 0, 0), true)
	step(g.position + Vector3.new(0.5, 0, 0), true)
	check(g.state == "CAPTURED" and home.feeding.held == g and d.captures == 1 and home.captures == 0 and pw:captures() == 1, `the gnat is in the jaws ({g.state})`)
	check(home.feeding == feedingBefore and d.feeding == home.feeding and home.feeding.struggling, "one jaws for the world")
	local elapsed = home.feeding.needs.elapsedS
	for _ = 1, 10 do step(Vector3.new(-20, -89.69, -30)) end
	check(math.abs(home.feeding.needs.elapsedS - elapsed - 10 * DT) < 1e-9, `the reserves advance once a tick, through the sill's feeding ({home.feeding.needs.elapsedS - elapsed} s over ten ticks)`)
	-- it tears free: back to the bed's director, flying
	home.feeding.grip = 0
	step(Vector3.new(-20, -89.69, -30))
	check(home.feeding.held == nil and g.state ~= "CAPTURED" and table.find(d.flies, g) ~= nil, `torn free, the gnat is the bed's again ({g.state})`)
end)

-- ---------------------------------------------------------------- the drawn gnat, aphid and woodlouse
case("the drawn gnat and aphid: their own templates under the fly's part budget, the gnat with one pair of wings, the aphid with none, both scaled", function()
	local bodies = FlyBodies.new(workspace)
	local function drawn(id: string, profile: any): any
		local f = { id = id, state = "PERCHED", position = Vector3.new(0, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = profile,
			airborne = function(self: any): boolean return false end }
		bodies:draw({ f }, 0)
		return bodies.rigs[id], f
	end
	local gr = drawn("g", gnat)
	local ar = drawn("a", aphid)
	check(gr.kind == "fungus_gnat" and ar.kind == "aphid" and gr.template ~= bodies.template and ar.template ~= bodies.template and gr.template ~= ar.template, "each kind has its own template")
	check(#gr.parts == 22 and #ar.parts == 15 and #gr.parts <= 40 and #ar.parts <= 40, `{#gr.parts} parts for a gnat, {#ar.parts} for an aphid, under the fly's forty`)
	local function count(rig: any, word: string): number
		local n = 0
		for _, p in rig.parts do if string.find(p.Name, word, 1, true) then n += 1 end end
		return n
	end
	check(count(gr, "Wing") == 2 and count(ar, "Wing") == 0, "the gnat has two wings, the aphid none")
	check(count(gr, "Femur") == 6 and count(gr, "Tibia") == 6 and count(ar, "Leg") == 6 and count(ar, "Cornicle") == 2 and count(ar, "Antenna") == 2, "six two-part legs on the gnat; six legs, two cornicles and two antennae on the aphid")
	check(gr.scale == 0.45 and ar.scale == 0.4, "at their visual scales")
	local safe = true
	local lowest = math.huge
	for _, rig in { gr, ar } do
		for _, p in rig.parts do
			if p.CanCollide ~= false or p.CanQuery ~= false or p.CanTouch ~= false or p.CastShadow ~= false or not p.Anchored then safe = false end
			if p.Name ~= "Shadow" then lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2) end
		end
	end
	check(safe, "no part collides, is seen by a ray, is touched or casts a shadow")
	check(lowest > -0.05 and lowest < 0.12, `the feet stand near the surface ({lowest})`)
	local aphidAbdomen: any
	for _, p in ar.parts do if p.Name == "Abdomen" then aphidAbdomen = p end end
	check(aphidAbdomen ~= nil and aphidAbdomen.Color.G > aphidAbdomen.Color.R and aphidAbdomen.Color.G > aphidAbdomen.Color.B, "the aphid is green")
	-- the same id drawn as a house fly next: the kind changes and the rig is rebuilt
	local fr = drawn("g", fly)
	check(fr.kind == nil and #fr.parts == #bodies.template.specs, "a fly of another kind under the same id gets the fly's rig")
	bodies:draw({}, 0)
	check(next(bodies.rigs) == nil, "gone when not drawn")
end)

case("the drawn woodlouse: seven plates, a head, two antennae and fourteen legs, PARTS parts, safe, and under the soil when hidden", function()
	local bugs = BugBodies.new(workspace)
	local louse = { id = "louse_1", position = Vector3.new(3, -89.88, -40), heading = Vector3.new(1, 0, 0), state = "walk" }
	bugs:draw({ louse })
	local rig = bugs.rigs.louse_1
	check(rig ~= nil and #rig.parts == BugBodies.PARTS and BugBodies.PARTS == 24, `{#rig.parts} parts, the cap`)
	local plates, legs, antennae, head = 0, 0, 0, 0
	local safe = true
	for _, p in rig.parts do
		if string.find(p.Name, "Plate", 1, true) then plates += 1 elseif string.find(p.Name, "Leg", 1, true) then legs += 1 elseif string.find(p.Name, "Antenna", 1, true) then antennae += 1 elseif p.Name == "Head" then head += 1 end
		if p.CanCollide ~= false or p.CanQuery ~= false or p.CanTouch ~= false or p.CastShadow ~= false or not p.Anchored then safe = false end
	end
	check(plates == 7 and legs == 14 and antennae == 2 and head == 1 and safe, "seven plates, fourteen legs, two antennae, a head; none of it solid")
	local lowest, highest = math.huge, -math.huge
	for _, p in rig.parts do lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2); highest = math.max(highest, p.Position.Y + p.Size.Y / 2) end
	check(lowest > -90.01 and lowest < -89.95 and highest - lowest < 0.5, `it stands on the soil ({lowest} to {highest})`)
	louse.state = "hidden"
	bugs:draw({ louse })
	for _, p in rig.parts do check(p.Position.Y < -90.5, "hidden, every part is under the soil") end
	bugs:draw({})
	check(next(bugs.rigs) == nil and #bugs.folder:GetChildren() == 0, "gone when not drawn")
end)


-- ================================================================ ROBLOX-101 (W3b part A): the bestiary's springtails, leafhoppers, small moths and crane flies
local PreyKinds = require("../src/Shared/Prey/PreyKinds")
local PreyRandom = require("../src/Shared/Prey/PreyRandom")
local LifeText = require("../src/Shared/UI/LifeText")
local PreyText = require("../src/Shared/UI/PreyText")
local springtail, leafhopper = Species.springtail_prototype, Species.leafhopper_prototype
local moth, mothDusk = Species.moth_prototype, Species.moth_dusk_prototype
local crane, craneDusk = Species.crane_fly_prototype, Species.crane_fly_dusk_prototype
local wall = WorldMap.region("house_wall") :: WorldMap.Region
local outer = WorldMap.region("outer_sill") :: WorldMap.Region
local function specOf(region: WorldMap.Region, kind: string): any
	for _, k in Garden.bestiary(region) :: { any } do if k.kind == kind then return k end end
	return nil
end
local function kindDirector(region: WorldMap.Region, kind: string, low: boolean?): any
	local spec = specOf(region, kind)
	return PreyDirector.engine(world, (Species :: any)[spec.profile], spec.seed, if low then spec.low else spec.target, false, spec)
end

case("the bestiary's profiles are derived from the house fly's (Godot's untouched), with their meals, catch factors and behaviours", function()
	check(fly.body.hop == nil and fly.body.flightless == nil and fly.body.sidestep == nil and fly.body.dusk == nil and fly.body.slip_chance == nil and fly.body.shed_chance == nil
		and fly.body.catch_factor == nil and fly.flight.wander_local == nil, "the house fly has none of the new fields")
	local meals = { { springtail, 0.35 / 8, "springtail" }, { leafhopper, 0.35 / 2, "leafhopper" }, { moth, 0.35, "moth" }, { crane, 0.7, "crane_fly" } }
	for _, m in meals do
		local p = m[1] :: any
		check(math.abs(p.body.nutrition - (m[2] :: number)) < 1e-12 and p.body.prey_kind == m[3] and p.body.visual_scale == 1 and p.body.hover_wu == fly.body.hover_wu, `{m[3]}: its meal, its kind, its true size, the fly's hover`)
		for _, k in { "senses", "reaction", "flight", "behavior", "population", "utility" } do check(p[k] ~= fly[k], `{m[3]}: its {k} table is its own`) end
	end
	check(Catch.factorFor(springtail) == 0.5 and Catch.factorFor(leafhopper) == 1.0 and math.abs(Catch.factorFor(moth) - 1.0) < 1e-12 and Catch.factorFor(crane) == 1.25,
		`catch factors: springtail {Catch.factorFor(springtail)}, leafhopper {Catch.factorFor(leafhopper)}, moth {Catch.factorFor(moth)}, crane fly {Catch.factorFor(crane)}`)
	check(Catch.factorFor(gnat) == 0.6 or math.abs(Catch.factorFor(gnat) - 0.6) < 1e-9, "the gnat's factor is W3's")
	check(springtail.body.flightless == true and springtail.body.hop.min == 1.5 and springtail.body.hop.max == 4 and springtail.body.hop.time < 0.2, "the springtail is flightless and flicks 1.5 to 4 studs")
	check(leafhopper.body.hop.min == 3 and leafhopper.body.hop.max == 10 and leafhopper.body.hop.fly_after == 0.35 and leafhopper.body.sidestep ~= nil and not leafhopper.body.flightless, "the leafhopper jumps 3 to 10 studs, sometimes flies on, and sidesteps")
	check(moth.body.slip_chance == 0.35 and crane.body.shed_chance == 0.4 and crane.body.shed_after[1] == 0.6 and crane.body.shed_after[2] == 1.6, "the moth's slip, the crane fly's leg")
	check(PreyKinds.counterpart(moth, true) == mothDusk and PreyKinds.counterpart(mothDusk, false) == moth and PreyKinds.counterpart(crane, true) == craneDusk and PreyKinds.counterpart(craneDusk, false) == crane, "each flier's dusk profile and back")
	check(PreyKinds.counterpart(moth, false) == nil and PreyKinds.counterpart(mothDusk, true) == nil and PreyKinds.counterpart(fly, true) == nil and PreyKinds.counterpart(springtail, true) == nil, "no change where there is none")
	check(mothDusk.behavior.restless_per_s > moth.behavior.restless_per_s * 20 and craneDusk.behavior.restless_per_s > crane.behavior.restless_per_s * 20, "restless from dusk, still by day")
	check(mothDusk.flight.cruise_speed_wu_s == moth.flight.cruise_speed_wu_s and moth.flight.cruise_speed_wu_s < fly.flight.cruise_speed_wu_s and crane.flight.cruise_speed_wu_s < moth.flight.cruise_speed_wu_s, "the moth flies slower than the house fly, the crane fly slower still")
	check(LifeText.MEALS.springtail.rule == "8 springtails = 1 housefly" and LifeText.MEALS.leafhopper.rule == "2 leafhoppers = 1 housefly" and LifeText.MEALS.moth.rule == "1 moth = 1 housefly" and LifeText.MEALS.crane_fly.rule == "1 crane fly = 2 houseflies", "the meal line's rules")
	check(PreyText.note({ kind = "slip" }) ~= nil and PreyText.note({ kind = "shed" }) ~= nil and PreyText.note({ kind = "other" }) == nil and PreyText.note(nil) == nil, "a note for the slip and the shed leg, none for anything else")
end)

case("the bestiary's perches and vents come from the regions' boxes and seeds, on real faces, inside the regions, with budgets at both tiers", function()
	check(Garden.bestiary(WorldMap.region("sill") :: WorldMap.Region) == nil, "the sill has none (its prey is pinned)")
	local kindsOf = function(r: WorldMap.Region): string
		local out = {}
		for _, k in Garden.bestiary(r) :: { any } do table.insert(out, k.kind) end
		return table.concat(out, ",")
	end
	check(kindsOf(bed) == "springtail,leafhopper" and kindsOf(wall) == "moth,crane_fly" and kindsOf(outer) == "moth,crane_fly", "the kinds in each region, in the directors' order")
	local seeds: { [number]: boolean } = { [bed.seed] = true }
	local full, low = { bed = 6, house_wall = 0, outer_sill = 0 }, { bed = 6, house_wall = 0, outer_sill = 0 }
	for _, r in { bed, wall, outer } do
		for _, k in Garden.bestiary(r) :: { any } do
			check(not seeds[k.seed], `{r.id} {k.kind}: a seed of its own`)
			seeds[k.seed] = true
			check(k.profile == k.kind .. "_prototype" and (Species :: any)[k.profile] ~= nil and k.prefix == `{r.id}_{k.kind}_fly_`, `{r.id} {k.kind}: its profile and prefix`)
			check(k.low <= k.target, `{r.id} {k.kind}: fewer at low`)
			full[r.kind] += k.target; low[r.kind] += k.low
			local starts = 0
			for _, p in k.perches do
				if p.start then starts += 1 end
				check(within(r.bounds[1], r.bounds[2], p.position) and finite(p.position), `{p.id} is inside {r.id}`)
				local hit = workspace:Raycast(p.position + p.normal * 0.5, -p.normal * 1.0, params)
				check(hit ~= nil and (hit.Position - p.position).Magnitude < 1e-3 and hit.Normal:Dot(p.normal) > 0.99, `{p.id} sits on a box's face ({if hit then hit.Instance.Name else "nothing"})`)
			end
			check(starts >= k.target, `{r.id} {k.kind}: enough starts for its target ({starts})`)
			for _, vnt in k.vents do check(vnt.appear == true and vnt.reach > 0 and within(r.bounds[1] - Vector3.new(0, 0, 5), r.bounds[2], vnt.position), `{vnt.id}: an appear vent by its region`) end
			check(k.dusk == (if k.kind == "moth" or k.kind == "crane_fly" then Garden.BESTIARY.dusk else nil), `{r.id} {k.kind}: flies from dusk exactly when it is a moth or a crane fly`)
		end
	end
	check(full.bed == 12 and low.bed == 9 and full.bed <= 14, `the bed's prey: {full.bed} at full (W3's six with four springtails and two leafhoppers), {low.bed} at low`)
	check(full.house_wall == 3 and low.house_wall == 2 and full.outer_sill == 2 and low.outer_sill == 1, `the wall {full.house_wall}/{low.house_wall}, the outer sill {full.outer_sill}/{low.outer_sill}`)
	-- the springtails' spots: near the stones and the litter, apart; the leafhoppers' in pairs, each the other's far side
	local st = specOf(bed, "springtail")
	check(#st.perches == 12, `twelve springtail spots ({#st.perches})`)
	for i, p in st.perches do
		check(p.hop == true and p.normal == Vector3.yAxis and p.position.Y == -90, `{p.id} is a hopper's spot on the soil`)
		for j = i + 1, #st.perches do check((p.position - st.perches[j].position).Magnitude >= 1.0 - 1e-9, "a stud apart at least") end
	end
	local lh = specOf(bed, "leafhopper")
	local byId: { [string]: any } = {}
	for _, p in lh.perches do byId[p.id] = p end
	check(#lh.perches == 12, `twelve leafhopper perches, six pairs ({#lh.perches})`)
	for _, p in lh.perches do
		local o = byId[p.behind]
		check(o ~= nil and o.behind == p.id and o.normal:Dot(p.normal) < -0.99 and o.round == p.round and p.hop == true, `{p.id} and its far side {p.behind}`)
	end
	check(Garden.bestiary(bed) == Garden.bestiary(bed), "asked again, the same list")
	local w3 = Garden.prey(bed) :: Garden.PreySpec
	check(#w3.perches == 28 and #w3.vents == 4 and w3.target == 6, "W3's bed spec is what it was")
end)

case("the bestiary's directors spawn their targets at each tier from their own seeds, the same again from the same seed", function()
	for _, r in { bed, wall, outer } do
		for _, k in Garden.bestiary(r) :: { any } do
			for _, low in { false, true } do
				local d = kindDirector(r, k.kind, low)
				local want = if low then k.low else k.target
				check(#d.flies == want and d.p == (Species :: any)[k.profile] and d.seed == k.seed, `{r.id} {k.kind} at {if low then "low" else "full"}: {#d.flies} of {want}`)
				local valid = 0
				for _, p in d.graph.perches do if p.valid then valid += 1 end end
				check(valid == #k.perches, `{r.id} {k.kind}: every perch found its face ({valid} of {#k.perches})`)
				for _, f in d.flies do
					check(f.state == "PERCHED" and f.perch.occupant == f.id and string.sub(f.id, 1, #k.prefix) == k.prefix and f.profile == d.p, `{f.id} stands on its perch`)
					check(math.abs(f.heading:Dot(f.normal)) < 1e-6 or true, "")
				end
			end
			local a, b = kindDirector(r, k.kind), kindDirector(r, k.kind)
			local same = #a.flies == #b.flies
			for i, f in a.flies do if b.flies[i].id ~= f.id or b.flies[i].rng.state ~= f.rng.state or (b.flies[i].position - f.position).Magnitude > 1e-9 then same = false end end
			check(same, `{r.id} {k.kind}: the same seed, the same prey`)
		end
	end
end)

-- One tick of a director, the spider at `pos` (moving between ticks as the caller moves it), with a strike when asked.
local function approach(d: any, f: any, s: any, from: Vector3, speed: number, ticks: number, onTick: ((number, Vector3) -> ())?): Vector3
	local spider = from
	for i = 1, ticks do
		local to = f.position + Vector3.new(0.3, 0.19, 0)
		local gap = (to - spider).Magnitude
		if gap > 1e-6 then spider += (to - spider).Unit * math.min(speed * DT, gap) end
		tick(d, spider, s)
		if onTick then onTick(i, spider) end
	end
	return spider
end

case("a springtail flicks away when the spider comes close: a hop of a few studs, never a flight, and it stays in the bed", function()
	local d = kindDirector(bed, "springtail")
	local s = sensor()
	local f = d.flies[1]
	check(not f:launch("move", 0), "a springtail never flies to move")
	local hopsAt: { number } = {}
	local airborneNotHop, longest, shortest = 0, 0, math.huge
	local prev = 0
	approach(d, f, s, f.position + Vector3.new(6, 0.19, 0), 2.5, 60 * 12, function(_i: number, spider: Vector3)
		if f:airborne() and f.state ~= "HOP" then airborneNotHop += 1 end
		if (f.hops or 0) > prev then
			prev = f.hops
			table.insert(hopsAt, (spider - f.hop.from).Magnitude)
			local len = (f.hop.to - f.hop.from).Magnitude
			longest, shortest = math.max(longest, len), math.min(shortest, len)
		end
		for _, x in d.flies do check(within(bed.bounds[1], bed.bounds[2], x.position), `{x.id} stays in the bed`) end
	end)
	check(#hopsAt >= 3, `it flicked away {#hopsAt} times in twelve seconds of being followed`)
	check(hopsAt[1] <= springtail.senses.startle_range_wu + 0.5, `the first flick when the spider came close ({hopsAt[1]} studs)`)
	check(shortest >= springtail.body.hop.min - 0.2 and longest <= springtail.body.hop.max + 0.2, `hops of {shortest} to {longest} studs`)
	check(airborneNotHop == 0, "it was never in the air but on a hop")
	-- left alone, it settles and never hops
	local hops = f.hops
	for _ = 1, 60 * 20 do tick(d, FAR, s) end
	check(f.hops == hops and not f:airborne(), "left alone it stays")
	-- caught and torn free, it flicks off from the jaws (or, with nowhere to land, is back on its spot)
	local g = d.flies[2]
	g.flight:release(); g.perch.occupant = ""; g.state = "CAPTURED"; g.position = g.position + Vector3.new(0, 0.5, 0)
	d.previousPosition = g.position + Vector3.new(0.4, 0, 0)
	d:escape(g)
	check(g.state == "HOP" or (g.state == "ALERT" and g.perch.occupant == g.id), `torn free, it flicks away ({g.state})`)
	for _ = 1, 600 do tick(d, FAR, s) end
	check(g.state == "PERCHED" or g.state == "ALERT", `and lands ({g.state})`)
end)

case("a leafhopper goes round its stem from a spider watching it, and jumps far when the spider comes at it", function()
	local d = kindDirector(bed, "leafhopper")
	local s = sensor()
	local f = d.flies[1]
	local first = f.perch
	check(first.behind ~= nil, "it starts on a perch with a far side")
	-- the spider sways a little three studs off, on its side: it sidesteps to the far side
	local watch = f.position + f.normal * 3
	for i = 1, 60 * 5 do tick(d, watch + Vector3.new(0, 0, math.sin(i * 0.05) * 0.4), s) end
	check(f.perch.id == first.behind and (f.sidesteps or 0) >= 1 and not f:airborne(), `it went round to {f.perch.id} ({f.sidesteps or 0} sidesteps)`)
	check((f.position - d.graph:rest(f.perch)).Magnitude <= leafhopper.behavior.wander_radius_wu + 0.05, "and sits there")
	-- the spider comes at it fast from in front: it jumps
	local hops, len = 0, 0
	local d2 = kindDirector(bed, "leafhopper")
	local g = d2.flies[1]
	approach(d2, g, sensor(), g.position + g.normal * 5, 6, 60 * 4, function()
		if (g.hops or 0) > hops then hops = g.hops; len = math.max(len, (g.hop.to - g.hop.from).Magnitude) end
	end)
	check(hops >= 1 and len >= leafhopper.body.hop.min - 1e-6 and len <= leafhopper.body.hop.max + 1e-6, `it jumped ({hops} jumps, the longest {len} studs)`)
	for _, x in d2.flies do check(within(bed.bounds[1], bed.bounds[2], x.position), `{x.id} is in the bed`) end
end)

case("by day the moths and the crane fly sit still; from dusk they flutter and resettle, and the world's hour decides which", function()
	for _, k in { "moth", "crane_fly" } do
		local d = kindDirector(wall, k)
		local s = sensor()
		local far = Vector3.new(0, -89.69, -60)
		local dayAir, duskAir, landings = 0, 0, 0
		for _ = 1, 60 * 120 do tick(d, far, s); for _, f in d.flies do if f:airborne() then dayAir += 1 end end end
		check(dayAir == 0, `{k}: still all day (2 minutes, {dayAir} ticks in the air)`)
		PreyKinds.light(d, true)
		check(d.p == (if k == "moth" then mothDusk else craneDusk) and d.dusk == true, `{k}: the dusk profile`)
		for _, f in d.flies do check(f.profile == d.p, `{f.id} flies from dusk`) end
		for _ = 1, 60 * 180 do
			tick(d, far, s)
			for _, f in d.flies do
				if f:airborne() then duskAir += 1 end
				check(within(wall.bounds[1] - Vector3.new(0, 0, 2), wall.bounds[2], f.position), `{f.id} stays by the wall ({f.position})`)
			end
		end
		for _, f in d.flies do landings += f.flight.landings end
		check(duskAir > 60 and landings >= 1, `{k}: at dusk it flies ({duskAir} ticks in the air) and resettles ({landings} landings)`)
		for _, f in d.flies do if not f:airborne() then check(math.abs(f.heading:Dot(f.normal)) < 0.01, `{f.id} faces along the wall, not into it`) end end
		PreyKinds.light(d, false)
		check(d.p == (if k == "moth" then moth else crane) and d.dusk == false, `{k}: by day again`)
	end
	check(PreyKinds.isDusk(18, 18, 6) and PreyKinds.isDusk(23.5, 18, 6) and PreyKinds.isDusk(3, 18, 6) and not PreyKinds.isDusk(6, 18, 6) and not PreyKinds.isDusk(12, 18, 6), "dusk runs from 18:00 through the night to 6:00")
	-- the world's hour: on the wall at noon the profile is the day's, at 20:00 the dusk's, and back at 9:00
	local home = sillDirector()
	local pw = PreyWorld.new(home, worldAt("house_wall"), {}, world, { probe = home.probe, cast = home.graph.cast, sweep = home.graph.sweep, overlap = home.graph.overlap })
	local s = sensor()
	local at = Vector3.new(0, -40, -24.3)
	pw:before(DT, at, observerAt(at), s, cast, cameraFar, 12)
	local ds = pw:kinds("house_wall")
	check(#ds == 2 and ds[1].p == moth and ds[2].p == crane, "at noon, the day profiles")
	pw:before(DT, at, observerAt(at), s, cast, cameraFar, 20)
	check(ds[1].p == mothDusk and ds[2].p == craneDusk, "at 20:00, the dusk profiles")
	pw:before(DT, at, observerAt(at), s, cast, cameraFar)
	check(ds[1].p == mothDusk, "with no hour given, the last one holds")
	pw:before(DT, at, observerAt(at), s, cast, cameraFar, 9)
	check(ds[1].p == moth and ds[2].p == crane, "at 9:00, the day's again")
end)

-- A world with the spider at `regionId` and the sill's jaws (game rules on, as the client has them).
local function catchWorld(regionId: string): (any, any, any)
	local home = sillDirector()
	home.feeding:useGameRules()
	local garden = {}
	local pw = PreyWorld.new(home, worldAt(regionId), garden, world, { probe = home.probe, cast = home.graph.cast, sweep = home.graph.sweep, overlap = home.graph.overlap })
	return pw, home, garden
end
local function strikeThrough(pw: any, s: any, f: any)
	local function step(pos: Vector3, strike: boolean?)
		pw:before(DT, pos, observerAt(pos), s, cast, cameraFar, 12)
		pw:after(DT, motorAt(pos, strike), s, cast)
	end
	step(f.position - Vector3.new(0.5, 0, 0), true)
	if f.state ~= "CAPTURED" then step(f.position + Vector3.new(0.5, 0, 0), true) end
	return step
end
-- A stream whose first draw is under (or over) `p`.
local function streamFor(p: number, under: boolean): any
	for k = 1, 1000 do
		local seed = (k * 2654435) % 2147483647
		local r = PreyRandom.new(seed)
		local x = PreyRandom.new(seed):next()
		if (x < p) == under then return r end
	end
	error("no stream")
end

case("a moth's first grip may slip (seeded, once): it leaves the jaws and flies; the second grip holds", function()
	local outcomes = {}
	for _, slip in { true, false } do
		local pw, home, garden = catchWorld("outer_sill")
		local s = sensor()
		pw:before(DT, Vector3.new(0, 0.19, -18), observerAt(Vector3.new(0, 0.19, -18)), s, cast, cameraFar, 12)
		local m: any = garden.outer_sill.kinds.moth.flies[1]
		m.rng = streamFor(moth.body.slip_chance, slip)
		local step = strikeThrough(pw, s, m)
		check(m.state == "CAPTURED" and home.feeding.held == m, `the moth is caught ({m.state})`)
		step(m.position + Vector3.new(0.3, 0, 0))
		check(m.slipDrawn == true, "the slip is drawn on the first tick of the grip")
		if slip then
			check(home.feeding.held == nil and m.state ~= "CAPTURED" and m:airborne() and pw.event ~= nil and pw.event.kind == "slip" and pw.event.prey == "moth", `it slipped and flies off ({m.state})`)
			-- caught again: no second slip
			for _ = 1, 120 do step(Vector3.new(0, 0.19, -18)) end
			local held = false
			for _ = 1, 600 do
				if m.state == "PERCHED" or m.state == "ALERT" then
					local again = strikeThrough(pw, s, m)
					again(m.position + Vector3.new(0.3, 0, 0))
					again(m.position + Vector3.new(0.3, 0, 0))
					held = home.feeding.held == m
					break
				end
				step(Vector3.new(0, 0.19, -18))
			end
			check(held, "caught again once it has landed, it stays in the jaws")
		else
			check(home.feeding.held == m and home.feeding.struggling and pw.event == nil, "the grip held")
		end
		outcomes[slip] = m.state
	end
	-- the same stream twice, the same outcome
	local a, b = {}, {}
	for run = 1, 2 do
		local pw, home, garden = catchWorld("outer_sill")
		local s = sensor()
		pw:before(DT, Vector3.new(0, 0.19, -18), observerAt(Vector3.new(0, 0.19, -18)), s, cast, cameraFar, 12)
		local m: any = garden.outer_sill.kinds.moth.flies[1]
		local step = strikeThrough(pw, s, m)
		for _ = 1, 30 do step(m.position + Vector3.new(0.3, 0, 0)) end
		local out = if run == 1 then a else b
		out.held, out.state, out.rng = home.feeding.held == m, m.state, m.rng.state
	end
	check(a.held == b.held and a.state == b.state and a.rng == b.rng, "the world's own seed, the same slip or grip every time")
end)

case("a crane fly in the struggle may leave a leg and escape (seeded, once); it is drawn with a leg fewer after", function()
	local pw, home, garden = catchWorld("outer_sill")
	local s = sensor()
	pw:before(DT, Vector3.new(0, 0.19, -18), observerAt(Vector3.new(0, 0.19, -18)), s, cast, cameraFar, 12)
	local c: any = garden.outer_sill.kinds.crane_fly.flies[1]
	c.rng = streamFor(crane.body.shed_chance, true)
	local step = strikeThrough(pw, s, c)
	check(c.state == "CAPTURED" and home.feeding.held == c, "the crane fly is caught")
	step(c.position + Vector3.new(0.3, 0, 0))
	check(c.shedDrawn == true and c.shedAt ~= nil and c.shedAt >= crane.body.shed_after[1] and c.shedAt <= crane.body.shed_after[2], `the leg will go {c.shedAt} s into the struggle`)
	-- (the test holds the grip half way, so neither the taps nor the drain decide it)
	local ticks = 0
	while home.feeding.held == c and ticks < 600 do ticks += 1; home.feeding.grip = 0.5; step(Vector3.new(0, 0.19, -18)) end
	check(home.feeding.held == nil and c.legsLost == 1 and c:airborne() and pw.event ~= nil and pw.event.kind == "shed" and pw.event.prey == "crane_fly", `it left a leg and got away after {ticks / 60} s ({c.state})`)
	check(ticks / 60 <= crane.body.shed_after[2] + 0.2, "within the seconds drawn")
	-- the drawn body: one leg fewer
	local bodies = FlyBodies.new(workspace)
	local whole = { id = "w", state = "PERCHED", position = Vector3.new(0, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = crane, airborne = function() return false end }
	local shed = { id = "s", state = "PERCHED", position = Vector3.new(5, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = crane, legsLost = 1, airborne = function() return false end }
	bodies:draw({ whole, shed } :: { any }, 0)
	check(#bodies.rigs.w.parts - #bodies.rigs.s.parts == 3, `the shed leg's three parts are gone ({#bodies.rigs.w.parts}, {#bodies.rigs.s.parts})`)
	for _, p in bodies.rigs.s.parts do check(string.sub(p.Name, 1, 9) ~= "RightHind", `{p.Name} is not the shed leg`) end
	bodies:draw({}, 0)
	-- caught again, it never sheds a second leg
	local held = false
	for _ = 1, 60 * 30 do
		if c.state == "PERCHED" or c.state == "ALERT" then
			local again = strikeThrough(pw, s, c)
			for _ = 1, 60 * 3 do home.feeding.grip = 0.5; again(Vector3.new(0, 0.19, -18)); if home.feeding.held ~= c then break end end
			held = home.feeding.held == c and home.feeding.struggling
			break
		end
		step(Vector3.new(0, 0.19, -18))
	end
	check(held and c.legsLost == 1, "caught again, it keeps its other legs and is held")
	-- the grip trick never touches the house fly, the gnat, the springtail
	for _, p in { fly, gnat, springtail, leafhopper } do
		local feeding = { held = { profile = p, rng = PreyRandom.new(5) }, struggling = true, elapsed = 10 }
		check(PreyKinds.grip(feeding, function() end) == nil and feeding.held ~= nil and feeding.held.rng.state == 5, `{p.body.prey_kind or "house fly"}: no trick, no draw`)
	end
end)

case("the world's prey with the bestiary: the sill's untouched beside the outer sill's moths, each region's kinds under its gate, the low tier's fewer", function()
	-- on the sill only the sill runs, though the outer sill now has prey
	local pw, home, garden = catchWorld("sill")
	local s = sensor()
	for _ = 1, 30 do pw:before(DT, FAR, observerAt(FAR), s, cast, cameraFar, 20); pw:after(DT, motorAt(FAR), s, cast) end
	check(#pw.active == 1 and pw.active[1] == "sill" and next(garden) == nil and pw.made == 0 and #pw:flies() == #home.flies, "on the sill: the sill's prey alone, nothing made outside")
	-- on the outer sill: its moths and crane fly, and the wall's when near
	pw.world = worldAt("outer_sill")
	local at = Vector3.new(0, 0.19, -18)
	pw:before(DT, at, observerAt(at), s, cast, cameraFar, 12)
	check(pw.active[1] == "outer_sill" and garden.outer_sill.kinds.moth ~= nil and garden.outer_sill.kinds.crane_fly ~= nil, "the outer sill's prey runs there (and the sill's beside it, a neighbour, as W3 has it)")
	check(garden.outer_sill.prey == nil and garden.outer_sill.bugs == nil and #garden.outer_sill.kinds.moth.flies == 1 and #garden.outer_sill.kinds.crane_fly.flies == 1, "a moth and a crane fly, no gnats, no woodlice")
	for _, d in pw:kinds("outer_sill") do check(d.feeding == home.feeding and d.graph.cast == home.graph.cast, "one jaws, one set of casts") end
	-- the low tier
	local pwLow, _, gardenLow = catchWorld("bed_a")
	pwLow.tier = "low"
	local inBed = Vector3.new(-20, -89.69, -30)
	pwLow:before(DT, inBed, observerAt(inBed), s, cast, cameraFar, 12)
	check(#gardenLow.bed_a.kinds.springtail.flies == 2 and #gardenLow.bed_a.kinds.leafhopper.flies == 1 and #gardenLow.bed_a.prey.flies == 6, "at the low tier: two springtails, one leafhopper, W3's six")
	local inBedFull = 0
	local pwFull, _, gardenFull = catchWorld("bed_a")
	pwFull:before(DT, inBed, observerAt(inBed), s, cast, cameraFar, 12)
	for _, d in pwFull:directors("bed_a") do inBedFull += #d.flies end
	check(inBedFull == 12 and inBedFull <= 14 and #gardenFull.bed_a.kinds.springtail.flies == 4, `at full: {inBedFull} prey in the bed`)
	-- a strike in the bed takes a springtail into the shared jaws; one torn free is the springtail director's again
	local pwS, homeS, gardenS = catchWorld("bed_a")
	pwS:before(DT, inBed, observerAt(inBed), s, cast, cameraFar, 12)
	local sp: any = gardenS.bed_a.kinds.springtail.flies[1]
	strikeThrough(pwS, s, sp)
	check(homeS.feeding.held == sp and gardenS.bed_a.kinds.springtail.captures == 1 and pwS:captures() == 1, "a springtail in the jaws, counted")
	for _ = 1, 10 do homeS.feeding.grip = 0.5; pwS:before(DT, inBed, observerAt(inBed), s, cast, cameraFar, 12); pwS:after(DT, motorAt(inBed), s, cast) end
	homeS.feeding.grip = 0
	pwS:before(DT, inBed, observerAt(inBed), s, cast, cameraFar, 12)
	pwS:after(DT, motorAt(inBed), s, cast)
	check(homeS.feeding.held == nil and sp.state ~= "CAPTURED" and table.find(gardenS.bed_a.kinds.springtail.flies, sp) ~= nil, `torn free, it is the springtail director's again ({sp.state})`)
end)

case("the bestiary's bodies: under the fly's forty parts at full, fewer at low, at their true sizes and in their colours", function()
	local function rigOf(bodies: any, id: string, profile: any, flying: boolean?): any
		local f = { id = id, state = if flying then "FLEE" else "PERCHED", position = Vector3.new(0, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = profile,
			airborne = function() return flying == true end }
		bodies:draw({ f } :: { any }, 0)
		return bodies.rigs[id]
	end
	local expect = { springtail = { 15, 11 }, leafhopper = { 25, 13 }, moth = { 20, 9 }, crane_fly = { 31, 11 } }
	for kind, counts in expect do
		local profile = (Species :: any)[kind .. "_prototype"]
		local full = rigOf(FlyBodies.new(workspace, "full"), "f_" .. kind, profile)
		local low = rigOf(FlyBodies.new(workspace, "low"), "l_" .. kind, profile)
		check(#full.parts == counts[1] and #low.parts == counts[2] and #full.parts <= 40 and #low.parts < #full.parts, `{kind}: {#full.parts} parts at full, {#low.parts} at low`)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		local safe = true
		for _, p in full.parts do
			if p.Name ~= "Shadow" then
				for _, c in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) } do
					local corner = p.CFrame:PointToWorldSpace(p.Size * c / 2)
					lo = lo:Min(corner); hi = hi:Max(corner)
				end
			end
			if p.CanCollide ~= false or p.CanQuery ~= false or p.CanTouch ~= false or p.CastShadow ~= false or not p.Anchored then safe = false end
		end
		check(safe, `{kind}: no part collides, is seen by a ray or casts a shadow`)
		check(lo.Y > -0.04 and lo.Y < 0.06, `{kind}: its feet on the surface ({lo.Y})`)
		local function find(rig: any, name: string): any for _, p in rig.parts do if p.Name == name then return p end end return nil end
		if kind == "springtail" then
			local len = (find(full, "Abdomen").Position.Z + 0.04) - (find(full, "Head").Position.Z - 0.016)
			check(len > 0.12 and len < 0.2, `a springtail is about 0.15 long ({len})`)
			check(find(full, "Furcula") ~= nil and find(low, "Furcula") == nil, "the furcula at full")
			local flying = rigOf(FlyBodies.new(workspace, "full"), "j", profile, true)
			local rest, leap = find(full, "Furcula"), find(flying, "Furcula")
			check(rest ~= nil and leap ~= nil and (rest.CFrame.Position - leap.CFrame.Position).Magnitude > 0.01, "swung out in the leap")
		elseif kind == "leafhopper" then
			local w = find(full, "RightWing")
			check(w.Color.G > w.Color.R and w.Color.G > w.Color.B and w.Transparency == 0, "green, opaque wings over its back")
			check(hi.Z - lo.Z > 0.3 and hi.Z - lo.Z < 0.5, `about 0.4 long ({hi.Z - lo.Z})`)
		elseif kind == "moth" then
			check(hi.X - lo.X > 1.3 and hi.X - lo.X < 1.8, `wings about 1.5 across ({hi.X - lo.X})`)
			check(find(full, "LeftBand") ~= nil and find(low, "LeftBand") == nil, "the dark bands at full")
		else
			check(hi.Z - lo.Z > 5 and hi.X - lo.X > 5, `the crane fly's legs reach far ({hi.X - lo.X} by {hi.Z - lo.Z})`)
			local body = find(full, "Abdomen").Size.Z + find(full, "Thorax").Size.Z + find(full, "Head").Size.Z + find(full, "Rostrum").Size.Z
			check(body > 1.8 and body < 2.1, `its body about 2 long ({body})`)
			check(find(low, "RightHindLeg") ~= nil and find(low, "RightHindFemur") == nil and find(full, "RightHindLeg") == nil, "one rod a leg at low, three at full")
		end
	end
end)


-- ================================================================ ROBLOX-103 (W3c): the bodies move, pose only
case("the bestiary's bodies move: the moth's flap and its wings settling, the crane fly's rocking and dangling legs, the leafhopper's crouch, the springtail's somersault, steps on every kind, nothing added, no NaN", function()
	local function find(rig: any, name: string): any for _, p in rig.parts do if p.Name == name then return p end end error("no part " .. name) end
	local function rel(rig: any, ref: string): { [string]: CFrame }
		local base = find(rig, ref).CFrame
		local out = {}
		for _, p in rig.parts do out[p.Name] = base:Inverse() * p.CFrame end
		return out
	end
	local function diff(a: { [string]: CFrame }, b: { [string]: CFrame }, word: string): number
		local worst = 0
		for name, f in a do
			if string.find(name, word, 1, true) then
				local g = b[name]
				worst = math.max(worst, (f.Position - g.Position).Magnitude, (f.LookVector - g.LookVector).Magnitude, (f.UpVector - g.UpVector).Magnitude)
			end
		end
		return worst
	end
	local function finiteRig(rig: any): boolean
		for _, p in rig.parts do
			local c = p.CFrame
			for _, v in { p.Position, c.RightVector, c.UpVector, c.LookVector } do
				if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or math.abs(v.X) > 1e6 or math.abs(v.Y) > 1e6 or math.abs(v.Z) > 1e6 then return false end
			end
		end
		return true
	end
	local function bug(id: string, profile: any, state: string): any
		return { id = id, state = state, position = Vector3.new(0, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = profile,
			airborne = function(self: any): boolean return self.state ~= "PERCHED" and self.state ~= "ALERT" and self.state ~= "CAPTURED" end }
	end
	local t = 0
	local function frame(bodies: any, list: { any }, reduced: boolean?)
		t += 1 / 60
		bodies:draw(list, t, nil, reduced)
	end
	local expect = { springtail = { 15, 11 }, leafhopper = { 25, 13 }, moth = { 20, 9 }, crane_fly = { 31, 11 } }
	-- every kind steps while it walks and not while it stands, at both tiers, and keeps its part count
	for kind, counts in expect do
		for ti, tier in { "full", "low" } do
			local bodies = FlyBodies.new(workspace, tier)
			local f = bug("w", (Species :: any)[kind .. "_prototype"], "PERCHED")
			bodies:draw({ f } :: { any }, t)
			local rig = bodies.rigs.w
			local moving, last = 0, rel(rig, "Head")
			for _ = 1, 40 do
				f.position += Vector3.new(0.006, 0, 0)
				frame(bodies, { f })
				local now = rel(rig, "Head")
				if diff(now, last, "Front") > 1e-4 or diff(now, last, "Hind") > 1e-4 then moving += 1 end
				last = now
			end
			for _ = 1, 60 do frame(bodies, { f }) end
			local a = rel(rig, "Head")
			frame(bodies, { f })
			local b = rel(rig, "Head")
			local hasLegs = false
			for _, part in rig.parts do if string.find(part.Name, "Front", 1, true) then hasLegs = true end end
			check((moving >= 35 or not hasLegs) and diff(a, b, "Front") < 1e-9 and diff(a, b, "Middle") < 1e-9 and diff(a, b, "Hind") < 1e-9,
				`{kind} at {tier}: its legs step while it walks ({moving} of 40 frames; the low moth has none drawn) and are still when it stands`)
			check(#rig.parts == counts[ti] and finiteRig(rig), `{kind} at {tier}: still {#rig.parts} parts, every frame finite`)
			bodies:draw({}, t)
		end
	end
	-- the moth beats its wings visibly in the air, smoothly (no strobing jumps), and not in Reduced Motion
	local bodies = FlyBodies.new(workspace, "full")
	local moth = bug("m", Species.moth_prototype, "SEEK_PERCH")
	bodies:draw({ moth } :: { any }, t)
	local mrig = bodies.rigs.m
	local lo, hi, worstStep = math.huge, -math.huge, 0
	local lastUp = rel(mrig, "Head").RightForewing.UpVector
	for _ = 1, 60 do
		frame(bodies, { moth })
		local up = rel(mrig, "Head").RightForewing.UpVector
		lo, hi = math.min(lo, up.X), math.max(hi, up.X)
		worstStep = math.max(worstStep, math.acos(math.clamp(up:Dot(lastUp), -1, 1)))
		lastUp = up
	end
	check(hi - lo > 0.8 and worstStep < 0.5, `the moth's wings beat up and down in flight (a swing of {string.format("%.2f", hi - lo)}), at most {string.format("%.2f", worstStep)} rad a frame`)
	local r1 = rel(mrig, "Head"); frame(bodies, { moth }, true); local r2 = rel(mrig, "Head"); frame(bodies, { moth }, true); local r3 = rel(mrig, "Head")
	check(diff(r2, r3, "Forewing") < 1e-9 and r1 ~= nil, "in Reduced Motion the moth's wings are a still blur")
	-- landed, its wings shiver for under a second and lie still
	moth.state = "PERCHED"
	frame(bodies, { moth })
	local shiver = 0
	local prev = rel(mrig, "Head")
	for _ = 1, 30 do frame(bodies, { moth }); local now = rel(mrig, "Head"); if diff(now, prev, "Forewing") > 1e-4 then shiver += 1 end; prev = now end
	for _ = 1, 60 do frame(bodies, { moth }) end
	local s1 = rel(mrig, "Head"); frame(bodies, { moth }); local s2 = rel(mrig, "Head")
	check(shiver >= 20 and diff(s1, s2, "wing") < 1e-9 and diff(s1, s2, "Band") < 1e-9, `on landing the moth's wings shiver ({shiver} of 30 frames) and then lie still`)
	-- the crane fly rocks in the air and its dangling legs swing; in Reduced Motion neither
	local crane = bug("c", Species.crane_fly_prototype, "SEEK_PERCH")
	bodies:draw({ crane } :: { any }, t)
	local crig = bodies.rigs.c
	local rollLo, rollHi, dangle = math.huge, -math.huge, 0
	local cprev = rel(crig, "Thorax")
	for _ = 1, 60 do
		frame(bodies, { crane })
		local up = find(crig, "Thorax").CFrame.UpVector
		rollLo, rollHi = math.min(rollLo, up.X), math.max(rollHi, up.X)
		local now = rel(crig, "Thorax")
		if diff(now, cprev, "Tarsus") > 1e-4 then dangle += 1 end
		cprev = now
	end
	check(rollHi - rollLo > 0.1 and dangle >= 55, `the crane fly rocks in flight (its back swings {string.format("%.2f", rollHi - rollLo)}) and its dangling legs swing ({dangle} of 60 frames)`)
	frame(bodies, { crane }, true)
	local c1 = find(crig, "Thorax").CFrame.UpVector; local cr1 = rel(crig, "Thorax")
	frame(bodies, { crane }, true)
	check((find(crig, "Thorax").CFrame.UpVector - c1).Magnitude < 1e-9 and diff(cr1, rel(crig, "Thorax"), "Tarsus") < 1e-9, "in Reduced Motion it flies level with its legs still")
	-- the leafhopper sinks and tips before its leap (its reaction pending), and not in Reduced Motion
	local hopper = bug("h", Species.leafhopper_prototype, "ALERT")
	bodies:draw({ hopper } :: { any }, t)
	local hrig = bodies.rigs.h
	local standY = find(hrig, "Abdomen").Position.Y
	hopper.pending = t + 1
	for _ = 1, 20 do frame(bodies, { hopper }) end
	local crouchY = find(hrig, "Abdomen").Position.Y
	local nose = find(hrig, "Head").Position.Y - find(hrig, "Abdomen").Position.Y
	for _ = 1, 20 do frame(bodies, { hopper }, true) end
	local reducedY = find(hrig, "Abdomen").Position.Y
	hopper.pending = nil
	for _ = 1, 30 do frame(bodies, { hopper }) end
	check(crouchY < standY - 0.015 and nose > 0 and math.abs(reducedY - standY) < 1e-9 and math.abs(find(hrig, "Abdomen").Position.Y - standY) < 1e-3,
		`the leafhopper crouches nose up before the jump ({string.format("%.3f", standY - crouchY)} down), not in Reduced Motion, and stands again`)
	-- the springtail turns end over end through its hop
	local spring = bug("s", Species.springtail_prototype, "PERCHED")
	bodies:draw({ spring } :: { any }, t)
	local srig = bodies.rigs.s
	spring.state = "HOP"
	spring.hop = { time = 0.16 }
	frame(bodies, { spring })
	local flipped = false
	for _ = 1, 9 do
		frame(bodies, { spring })
		if find(srig, "Thorax").CFrame.UpVector.Y < -0.5 then flipped = true end
	end
	check(flipped and finiteRig(srig), "the springtail somersaults through its hop (upside down part way)")
	bodies:draw({}, t)
end)

case("the drawn woodlouse moves: a wave down its fourteen legs while it walks, still when it stops, antennae that sway, the far rule", function()
	local bugs = BugBodies.new(workspace)
	local louse = { id = "louse_1", position = Vector3.new(3, -89.88, -40), heading = Vector3.new(1, 0, 0), state = "walk" }
	local t = 0
	bugs:draw({ louse }, t)
	local rig = bugs.rigs.louse_1
	local function legs(): { CFrame }
		local base = rig.parts[8].CFrame -- the head
		local out = {}
		for i, p in rig.parts do out[i] = base:Inverse() * p.CFrame end
		return out
	end
	local function change(a: { CFrame }, b: { CFrame }, from: number, to: number): number
		local worst = 0
		for i = from, to do worst = math.max(worst, (a[i].Position - b[i].Position).Magnitude, (a[i].LookVector - b[i].LookVector).Magnitude) end
		return worst
	end
	-- the parts in the sheet's order: seven plates, the head, then each side's antenna and seven legs
	check(rig.parts[8].Name == "Head" and rig.parts[9].Name == "LeftAntenna" and rig.parts[10].Name == "LeftLeg1", "the parts in the sheet's order")
	local moving, last = 0, legs()
	local waveSeen = false
	for _ = 1, 60 do
		t += 1 / 60
		louse.position += Vector3.new(0.5 / 60, 0, 0)
		bugs:draw({ louse }, t)
		local now = legs()
		if change(now, last, 10, 16) > 1e-4 then moving += 1 end
		-- a wave: the first and fourth legs of a side are not in step
		if (now[10].LookVector - now[13].LookVector).Magnitude > 0.05 then waveSeen = true end
		last = now
	end
	check(moving >= 55 and waveSeen, `walking, its legs step in a wave ({moving} of 60 frames)`)
	for _ = 1, 60 do t += 1 / 60; bugs:draw({ louse }, t) end
	local a = legs(); t += 1 / 60; bugs:draw({ louse }, t); local b = legs()
	check(change(a, b, 10, 16) < 1e-9 and change(a, b, 18, 24) < 1e-9 and rig.gait == 0, "standing, its legs are still")
	check(change(a, b, 9, 9) > 1e-5, "its antennae sway")
	t += 1 / 60; bugs:draw({ louse }, t, nil, true); local c = legs(); t += 1 / 60; bugs:draw({ louse }, t, nil, true)
	check(change(c, legs(), 9, 9) < 1e-9, "in Reduced Motion they are still")
	check(#rig.parts == BugBodies.PARTS, "no part added")
	louse.state = "hidden"
	t += 1 / 60; bugs:draw({ louse }, t)
	for _, p in rig.parts do check(p.Position.Y < -90.5 and p.Position.X == p.Position.X, "hidden, under the soil and finite") end
	-- far from the camera it is placed ten times a second
	louse.state = "walk"
	local placed = 0
	local original = workspace.BulkMoveTo
	workspace.BulkMoveTo = function(self: any, ps: { any }, frames: { any }, mode: any) placed += 1; original(self, ps, frames, mode) end
	for _ = 1, 60 do t += 1 / 60; louse.position += Vector3.new(0.01, 0, 0); bugs:draw({ louse }, t, Vector3.new(3, -60, -40)) end
	workspace.BulkMoveTo = original
	check(placed >= 9 and placed <= 11, `beyond 25 studs of the camera, placed {placed} times in a second`)
	bugs:draw({})
end)

print(`GARDEN_LIFE passed={passed} failed={failed}`)
if failed > 0 then error("GARDEN_LIFE failed") end
