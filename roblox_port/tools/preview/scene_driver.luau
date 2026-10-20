-- Preview-only driver for tools/preview/scene.py: builds the real sill and decor (Habitat/Scenery, as Server/Main does), the real
-- spider (Rig/SpiderRig, at the places scene.py asks for) and the real fly bodies (Client/FlyBodies) under the test shim, then prints
-- every visible part for scene.gd to draw. The shim is not Roblox: this is a layout and colour preview, never Roblox rendering.
-- scene.py puts these globals in front of the bundle: DETAIL ("full" or "low"), SUN_ELEVATION_DEG, SUN_AZIMUTH_DEG, SPIDERS (a list
-- of { name, x, z, hx, hz }), FLIES (a list of { id, x, y, z, hx, hy, hz, flying }), WASPS (a list of { id, x, y, z, hx, hz, mode, search, beat }).
local Scenery = require("../src/Shared/Habitat/Scenery")
local WorldMap = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local WorldDetail = require("../src/Client/WorldDetail")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local SpiderRig = require("../src/Shared/Rig/SpiderRig")
local FlyBodies = require("../src/Client/FlyBodies")
local WaspBody = require("../src/Client/WaspBody")
local BugBodies = require("../src/Client/BugBodies")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local PreyWorld = require("../src/Shared/Prey/PreyWorld")
local Garden = require("../src/Shared/World/Garden")
local Species = require("../src/Shared/Data/Species")

-- ---------------------------------------------------------------- the world, as Server/Main builds it
local el, az = math.rad(SUN_ELEVATION_DEG), math.rad(SUN_AZIMUTH_DEG)
local sun = Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)) -- unit vector toward the sun
local built, decor, drawn = pcall(Scenery.decor, sun)
assert(built, tostring(decor))
local sill = Scenery.sill(drawn)
decor.Parent = workspace
sill.Parent = workspace
if DETAIL == "low" then WorldDetail.apply("low", { decor }) end
-- ROBLOX-95 (scene.py --world): the regions outside the window too, their boxes and their looks, as Server/Main builds them
local outside = Instance.new("Folder")
outside.Name = "Outside"
if WORLD then
	local looks, looksDrawn = WorldBuild.looks(workspace, WorldMap.SEED)
	if DETAIL == "low" then WorldDetail.apply("low", { looks }) end
	local hide: { [string]: boolean } = {}
	for id in drawn do hide[id] = true end
	for id in looksDrawn do hide[id] = true end
	for _, region in WorldMap.regions() do
		if region.kind ~= "sill" then WorldBuild.region(region, outside, hide) end
	end
	outside.Parent = workspace
	looks.Parent = outside
end

-- ---------------------------------------------------------------- the spider, standing at each asked-for place
local rigs = {}
for _, s in SPIDERS do
	local rig = SpiderRig.new(workspace, if s.y ~= nil then outside else sill, nil, DETAIL) -- (the spiders outside stand on the outside's boxes)
	local up = if s.up then Vector3.new(s.up[1], s.up[2], s.up[3]) else Vector3.yAxis
	local body = SupportMath.bodyCFrame(Vector3.new(s.x, s.y or 0.31, s.z), up, Vector3.new(s.hx, s.hy or 0, s.hz))
	for _ = 1, 40 do rig:update(body, 1 / 60, true, false) end
	rigs[s.name] = rig
end

-- ---------------------------------------------------------------- flies
local flyFolder = Instance.new("Folder")
flyFolder.Name = "FlyHolder"
flyFolder.Parent = workspace
local bodies = FlyBodies.new(flyFolder)
local flies = {}
for _, f in FLIES do
	table.insert(flies, {
		id = f.id, position = Vector3.new(f.x, f.y, f.z), heading = Vector3.new(f.hx, f.hy, f.hz).Unit, normal = Vector3.yAxis,
		state = if f.flying then "FLYING" else "PERCHED",
		airborne = function(self: any): boolean return self.state ~= "PERCHED" end,
	})
end
bodies:draw(flies, 0.37)
-- ROBLOX-96 (--world): the bed's prey and woodlice where the seed puts them, through the real director and colony on the outside's boxes (the gnats and the aphids on
-- their start perches, the woodlice at their starting places), drawn with the flies
if WORLD then
	local bed = WorldMap.region("bed_a") :: any
	local spec = Garden.prey(bed)
	if spec ~= nil then
		local d = PreyDirector.engine(outside, Species.fungus_gnat_prototype, spec.seed, spec.target, false, spec)
		for _, f in d.flies do table.insert(flies, f) end
		bodies:draw(flies, 0.37)
		local pw = PreyWorld.new(d, { home = "sill", map = WorldMap, region = bed, regionReady = function() return true end }, {}, outside)
		local colony = pw:bugs("bed_a")
		if colony ~= nil then BugBodies.new(flyFolder):draw(colony.lice) end
	end
	-- ROBLOX-101: the bestiary's prey on their start perches (the bed's springtails and leafhoppers, the wall's and the outer sill's moths and crane flies), each
	-- turned the way the sim turns it on its first tick (a fly on the wall heads up it), drawn at the tier asked for
	local Prey = require("../src/Shared/Prey/PreyKinds")
	local tiered = FlyBodies.new(flyFolder, DETAIL)
	local all = {}
	for _, id in { "bed_a", "house_wall", "outer_sill" } do
		for _, k in Garden.bestiary(WorldMap.region(id) :: any) :: { any } do
			local d = PreyDirector.engine(outside, (Species :: any)[k.profile], k.seed, if DETAIL == "low" then k.low else k.target, false, k)
			for _, f in d.flies do
				if math.abs(f.heading:Dot(f.normal)) > 0.9 then Prey.upright(f) end
				table.insert(all, f)
			end
		end
	end
	-- and a specimen tray far off at x 200 on a grey plate: each of the four standing and in flight, and a crane fly with a leg gone
	local plate = Instance.new("Part")
	plate.Name = "SpecimenPlate"; plate.Size = Vector3.new(40, 0.2, 14); plate.CFrame = CFrame.new(212, -0.1, 0); plate.Color = Color3.fromRGB(150, 146, 138)
	plate.Anchored = true; plate.Parent = flyFolder
	local kinds = { "springtail", "leafhopper", "moth", "crane_fly" }
	local xs = { 200, 203, 208, 216 }
	for i, kind in kinds do
		local profile = (Species :: any)[kind .. "_prototype"]
		local function specimen(id: string, at: Vector3, flying: boolean, legsLost: number?)
			table.insert(all, { id = id, position = at, heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, profile = profile, legsLost = legsLost, state = if flying then "FLEE" else "PERCHED",
				airborne = function(self: any): boolean return self.state ~= "PERCHED" end })
		end
		specimen("spec_" .. kind, Vector3.new(xs[i], 0.16, 0), false)
		specimen("spec_" .. kind .. "_air", Vector3.new(xs[i], 0.16 + (if kind == "crane_fly" then 3 else 1), -5), true)
		if kind == "crane_fly" then specimen("spec_crane_fly_shed", Vector3.new(224, 0.16, 0), false, 1) end
	end
	-- ROBLOX-103: a second row at z 4 of the bed's own and the sill's (a gnat and an aphid at their scales, a house fly), and a woodlouse; then every standing
	-- specimen walks a quarter of its stride toward -Z over ten frames (sixtieths of a second) and every flier beats on, so the tray shows the bodies mid-stride and
	-- mid-wingbeat (the --world views spec_*). The walkers' strides are their sheets' own (Data/FlyLook motion).
	local FlyLook = require("../src/Shared/Data/FlyLook")
	for i, kind in { "fungus_gnat", "aphid", "fly_like" } do
		local profile = (Species :: any)[kind .. "_prototype"]
		table.insert(all, { id = "spec_" .. kind, position = Vector3.new(200 + (i - 1) * 3, 0.16, 4), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, profile = profile, state = "PERCHED",
			airborne = function(self: any): boolean return self.state ~= "PERCHED" end })
	end
	local louse = { id = "spec_woodlouse", position = Vector3.new(210, 0.12, 4), heading = Vector3.new(0, 0, -1), state = "walk" }
	local lice = BugBodies.new(flyFolder)
	local t = 0.37
	tiered:draw(all, t)
	lice:draw({ louse }, t)
	for _ = 1, 10 do
		t += 1 / 60
		for _, f in all do
			if string.sub(f.id, 1, 5) == "spec_" and f.state == "PERCHED" then
				local body = f.profile.body
				local sheet = FlyLook.small[body.prey_kind or ""]
				local motion = if sheet and sheet.motion then sheet.motion else FlyLook.motion
				f.position += Vector3.new(0, 0, -motion.gait.stride * (body.visual_scale or 1) / 4 / 10)
			end
		end
		louse.position += Vector3.new(0, 0, -BugBodies.look.motion.gait.stride / 4 / 10)
		tiered:draw(all, t)
		lice:draw({ louse }, t)
	end
end

AMBIENT_AT = {} :: { string } -- (ROBLOX-105: where the ambient bugs stand in place, written on the counts line for the views)
-- ROBLOX-105 (--world): the ambient bugs, in place and on the tray. In place: the bed's ladybirds, millipedes, snail and harvestman and the wall's harvestman from
-- their seeds, run for a minute and a half of an evening (21:00, so the harvestmen are out and the snail crawls and leaves a trail) through the real colonies, the
-- bed's aphids walking with them; on a third row of the tray at z 10: a ladybird walking and one bleeding, a millipede straight and one coiled, a snail with a
-- trail and one with its stalks drawn in, a harvestman, each a few frames into a walk.
if WORLD then
	local Region = require("../src/Shared/World/Region")
	local Ladybird = require("../src/Shared/Prey/Ladybird")
	local Millipede = require("../src/Shared/Prey/Millipede")
	local Snail = require("../src/Shared/Prey/Snail")
	local Harvestman = require("../src/Shared/Prey/Harvestman")
	local bed = WorldMap.region("bed_a") :: any
	local wall = WorldMap.region("house_wall") :: any
	local soil: any, boxes = nil, {}
	for _, p in Region.pieces(bed) do
		if p.id == "bed_a_soil" then soil = { min = p.lo, max = p.hi } elseif p.lo.Y <= -89.99 then table.insert(boxes, { min = p.lo, max = p.hi }) end
	end
	local specs = {}
	for _, a in Garden.ambient(bed) :: { any } do specs[a.kind] = a end
	local tierN = function(a: any): number return if DETAIL == "low" then a.low else a.full end
	local plants = Garden.plants(bed) :: any
	local cols = {
		Ladybird.new(specs.ladybird, tierN(specs.ladybird), plants), Millipede.new(specs.millipede, tierN(specs.millipede), soil, boxes),
		Snail.new(specs.snail, tierN(specs.snail), soil, boxes), Harvestman.new(specs.harvestman, tierN(specs.harvestman), soil, boxes),
		Harvestman.new((Garden.ambient(wall) :: any)[1], 1),
	}
	local spec = Garden.prey(bed) :: any
	local d = PreyDirector.engine(outside, Species.fungus_gnat_prototype, spec.seed, spec.target, false, spec)
	local far = Vector3.new(-22, 0.31, 6)
	local cam = { CFrame = CFrame.new(Vector3.new(-22, 5, 12)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) }
	local Sensor = require("../src/Shared/Perception/Sensor")
	local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
	local sensor = Sensor.new(ObservationMemory.new())
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { outside }
	local cast = Sensor.workspaceCast(params)
	local obs = { eye = far, gaze = Vector3.new(0, 0, -1), up = Vector3.yAxis, heading = Vector3.new(0, 0, -1) }
	for _ = 1, 60 * 90 do
		d:before(1 / 60, far, obs, sensor, cast, cam)
		for _, c in cols do c:step(1 / 60, far, { hour = 21, flies = d.flies, plants = plants }) end
	end
	local crawl = {}
	for _, c in cols do for _, b in c:creatures() do table.insert(crawl, b) end end
	local amb = BugBodies.new(flyFolder, DETAIL)
	amb:draw(crawl, 90)
	-- the aphids where they walked to (the gnats too), drawn with the bestiary's bodies
	FlyBodies.new(flyFolder, DETAIL):draw(d.flies, 90)
	-- the tray's third row
	local plate2 = Instance.new("Part")
	plate2.Name = "SpecimenPlate2"; plate2.Size = Vector3.new(40, 0.2, 8); plate2.CFrame = CFrame.new(216, -0.1, 11); plate2.Color = Color3.fromRGB(150, 146, 138)
	plate2.Anchored = true; plate2.Parent = flyFolder
	local trailM = {}
	for i = 1, 13 do table.insert(trailM, Vector3.new(204, 0.12, 10 + i * 0.19)) end
	local trailC = {}
	for i = 1, 13 do table.insert(trailC, Vector3.new(208, 0.12, 10 + i * 0.19)) end
	local sTrail = {}
	for i = 1, 20 do table.insert(sTrail, { p = Vector3.new(214 + 0.15 * math.sin(i * 0.4), 0, 10 + i * 0.5), n = Vector3.yAxis, t = 90 - i * 10 }) end
	local row = {
		{ id = "spec_ladybird", kind = "ladybird", position = Vector3.new(200, 0.17, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "walk", bleedUntil = -1, hidden = false },
		{ id = "spec_ladybird_bleed", kind = "ladybird", position = Vector3.new(201.2, 0.17, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "still", bleedUntil = 1e9, hidden = false },
		{ id = "spec_millipede", kind = "millipede", position = Vector3.new(204, 0.12, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "walk", coil = 0, trail = trailM, hidden = false },
		{ id = "spec_millipede_coil", kind = "millipede", position = Vector3.new(208, 0.12, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "coiled", coil = 1, trail = trailC, hidden = false },
		{ id = "spec_snail", kind = "snail", position = Vector3.new(214, 0, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "crawl", eyes = 1, trail = sTrail, hidden = false },
		{ id = "spec_snail_in", kind = "snail", position = Vector3.new(220, 0, 10), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "rest", eyes = 0, trail = {}, hidden = false },
		{ id = "spec_harvestman", kind = "harvestman", position = Vector3.new(228, 0.9, 11), heading = Vector3.new(0, 0, -1), normal = Vector3.yAxis, state = "walk", hidden = false },
	}
	local tray = BugBodies.new(flyFolder, DETAIL)
	local t = 0.37
	tray:draw(row, t)
	for _ = 1, 10 do
		t += 1 / 60
		for _, b in row do
			if b.state == "walk" or b.state == "crawl" then
				local stride = if b.kind == "ladybird" then 0.22 elseif b.kind == "millipede" then 0.25 elseif b.kind == "harvestman" then 1.1 else 0.4
				b.position += Vector3.new(0, 0, -stride / 4 / 10)
			end
		end
		tray:draw(row, t)
	end
	-- where the in-place bugs are, for the views
	for _, b in crawl do table.insert(AMBIENT_AT, string.format("%s(%.2f,%.2f,%.2f)%s", b.id, b.position.X, b.position.Y, b.position.Z, tostring(b.state))) end
end

-- ---------------------------------------------------------------- wasps (scene.py's WASPS: id, x, y, z, hx, hz, mode, search, beat)
local waspHolder = Instance.new("Folder")
waspHolder.Name = "WaspHolder"
waspHolder.Parent = workspace
for _, w in WASPS do
	local body = WaspBody.new(waspHolder)
	body.folder.Name = w.id
	body:draw({ position = Vector3.new(w.x, w.y, w.z), heading = Vector3.new(w.hx, 0, w.hz).Unit, mode = w.mode, search = w.search, visible = true }, w.beat)
end

-- ---------------------------------------------------------------- the dump
local function f5(x: number): string return string.format("%.5f", x) end
local function vec(a: any): string
	if a == nil then error("a part has no size or position") end
	return "[" .. f5(a.X) .. "," .. f5(a.Y) .. "," .. f5(a.Z) .. "]"
end
local function pathOf(o: any): string
	local names = {}
	local p = o
	while p and p ~= workspace do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, "/")
end
local function dump(root: any, group: string, rows: { string })
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and ((p.Transparency or 0) < 0.995 or p:GetAttribute("UVOpacity") ~= nil) then
			local c = p.CFrame
			if c == nil or p.Size == nil then error("part " .. pathOf(p) .. " has no CFrame or Size") end
			for _, axis in { "Position", "RightVector", "UpVector", "ZVector" } do
				if (c :: any)[axis] == nil then error("part " .. pathOf(p) .. " CFrame has no " .. axis) end
			end
			local mesh = nil
			for _, ch in p:GetChildren() do
				if ch.ClassName == "SpecialMesh" then mesh = ch end
			end
			local color = p.Color or Color3.fromRGB(163, 162, 165)
			local shape = if p.Shape then p.Shape.Name else "Block"
			local meshJson = ""
			if mesh then
				meshJson = string.format(',"mesh":"%s","ms":%s', if mesh.MeshType then mesh.MeshType.Name else "Brick", vec(mesh.Scale or Vector3.one))
			end
			local uv = p:GetAttribute("UVOpacity")
			table.insert(rows, string.format(
				'{"g":"%s","n":"%s","path":"%s","k":"%s","size":%s,"p":%s,"x":%s,"y":%s,"z":%s,"c":[%s,%s,%s],"m":"%s","r":%s,"t":%s,"cs":%s,"fo":%s,"uv":%s%s}',
				group, p.Name, pathOf(p), shape, vec(p.Size), vec(c.Position), vec(c.RightVector), vec(c.UpVector), vec(c.ZVector),
				f5(color.R), f5(color.G), f5(color.B), if p.Material then p.Material.Name else "Plastic", f5(p.Reflectance or 0), f5(p.Transparency or 0),
				tostring(p.CastShadow ~= false), tostring(p:GetAttribute("FullOnly") == true), if typeof(uv) == "number" then f5(uv) else "null", meshJson))
		end
	end
end
local rows: { string } = {}
dump(sill, "world", rows)
dump(decor, "world", rows)
dump(outside, "world", rows)
local counts = { world = #rows }
for name, rig in rigs do
	local before = #rows
	dump(rig.model, name, rows)
	counts[name] = #rows - before
end
local before = #rows
dump(flyFolder, "flies", rows)
counts.flies = #rows - before
before = #rows
dump(waspHolder, "wasps", rows)
counts.wasps = #rows - before
local keys = {}
for k in counts do table.insert(keys, k) end
table.sort(keys)
local summary = {}
for _, k in keys do table.insert(summary, k .. "=" .. counts[k]) end
print("parts " .. table.concat(summary, " ") .. " total=" .. #rows .. (if #AMBIENT_AT > 0 then " ambient=" .. table.concat(AMBIENT_AT, ";") else ""))
print("[" .. table.concat(rows, ",\n") .. "]")
