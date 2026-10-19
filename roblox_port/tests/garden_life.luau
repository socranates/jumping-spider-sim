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
	-- on the wall's top: the bed's farthest perch is beyond the radius; at its foot, inside it
	pw.world = worldAt("house_wall")
	step(Vector3.new(0, -2, -24.3))
	check(#pw.active == 0 and garden.bed_a == nil, "high on the wall nothing runs: the sill is no neighbour, the bed too far")
	step(Vector3.new(0, -80, -24.3))
	check(#pw.active == 1 and pw.active[1] == "bed_a" and garden.bed_a ~= nil and garden.bed_a.prey ~= nil and pw.made == 1, "near the wall's foot the bed's prey runs, made now")
	local d = garden.bed_a.prey
	check(d.feeding == home.feeding and d.graph.cast == home.graph.cast and d.probe == home.probe, "the bed's director eats with the sill's jaws and casts with its casts")
	check(#d.flies == 6 and garden.bed_a.bugs ~= nil and #garden.bed_a.bugs.lice == 4, "with its six prey and four woodlice")
	check(#pw:flies() == 6 and #pw:percepts() == 6 + 4 and #pw:woodlice() == 4, "the view: the bed's flies, and its woodlice as movement")
	-- in the bed, a while; then back to the wall's top (the bed waits), then back: the same director, its flies where they were
	pw.world = worldAt("bed_a")
	for _ = 1, 300 do step(Vector3.new(-20, -89.69, -30)) end
	local before = {}
	for i, f in d.flies do before[i] = { id = f.id, pos = f.position, state = f.state, rng = f.rng.state } end
	local now = d.now
	pw.world = worldAt("house_wall")
	for _ = 1, 120 do step(Vector3.new(0, -2, -24.3)) end
	check(#pw.active == 0 and d.now == now, "away, the bed's clock stops")
	pw.world = worldAt("bed_a")
	step(Vector3.new(-20, -89.69, -30))
	check(garden.bed_a.prey == d and pw.made == 1, "back in the bed, the same director")
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
	check(#pw2.active == 1 and garden2.bed_a == nil and pw2.made == 0 and #pw2:flies() == 0, "a bed that has not arrived whole has no prey and no woodlice")
	pw2.world = worldAt("bed_a")
	pw2:before(DT, Vector3.new(-20, -89.69, -30), observerAt(FAR), s, cast, cameraFar)
	check(garden2.bed_a ~= nil and garden2.bed_a.prey ~= nil and pw2.made == 1, "whole, it has them")
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

print(`GARDEN_LIFE passed={passed} failed={failed}`)
if failed > 0 then error("GARDEN_LIFE failed") end
