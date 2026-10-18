-- The roaming rival (ROBLOX-69): RivalRoute (the graph of the sill's faces and the seams between them) and RivalDrive (the brain of the rival's own
-- SpiderMotor) on the box world of tests/shim.luau: the real motor walks the real boxes. It reaches patrol places on the floor, a leaf, the planter's
-- rim and the wall; never enters the retreat; stalks across a leaf and lunges from it; goes on toward the last place it saw the spider; pauses for a
-- wasp; is held where it was caught; accepts older records; and what it costs (rays per tick, decisions, plans). Not engine evidence: the motor's
-- raycasts here are the box world's. Run with the other suites:  python3 tests/run.py path/to/luau rivalnav.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local Route = require("../src/Shared/Predator/RivalRoute")
local Drive = require("../src/Shared/Predator/RivalDrive")
local Rival = require("../src/Shared/Predator/RivalSpider")
local Rules = require("../src/Shared/Data/RivalRules")

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

local DT = 1 / 60
local sill = BoxWorld.folder("NavSill", Layout.PIECES)
local faces = Route.faces()
local rays = 0
local rawRaycast = workspace.Raycast
workspace.Raycast = function(self: any, ...: any): any
	rays += 1
	return rawRaycast(self, ...)
end

local function newMotor(): any
	return Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Vector3.new(25, 0.31, 8),
		heading = Vector3.new(-1, 0, 0), boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = sill,
	})
end
-- A rival standing at a surface point on a face, patrolling; it cannot see the spider unless `sight` says so.
local function newRival(surface: Vector3, up: Vector3, sees: ((Vector3, Vector3) -> any)?): (any, any, any)
	local m = newMotor()
	local d = Drive.new(m, sees or function() return true end)
	local r = Rival.new()
	r.state = "patrol"
	m:place(surface + up * Route.SEAT, up, Vector3.new(-1, 0, 0))
	r.position, r.previous, r.up, r.heading, r.origin = m.pos, m.pos, m.up, m.heading, m.pos
	d.prevState = "patrol"
	return d, r, m
end
local function snapshot(): any
	return { position = Vector3.new(-25, 0.31, 6), previous = Vector3.new(-25, 0.31, 6), up = Vector3.yAxis, grounded = true, heading = Vector3.xAxis,
		day = 3, hour = 12, meals = 2, resting = false, safe = false, wasp = false, gentle = false, moving = false, airborne = false,
		onLine = false, holding = false, striking = false }
end
local function waypointOn(d: any, piece: string, pick: ((any) -> boolean)?): any
	for _, w in d.waypoints do
		local f = faces[w.face]
		if f.piece == piece and (pick == nil or pick(w)) then return w end
	end
	error("no waypoint on " .. piece)
end
-- Walks to a place: how long it took (sim seconds) or nil, and how many ticks it was in the retreat.
local function walkTo(d: any, r: any, s: any, w: any, maxSeconds: number): (number?, number)
	local before = d.stats.arrivals
	d:_setGoal(w, "patrol")
	local inCrack = 0
	for k = 1, math.floor(maxSeconds / DT) do
		Drive.update(d, r, DT, s)
		if Layout.inRetreat(d.motor.pos) then inCrack += 1 end
		if d.stats.arrivals > before then return k * DT, inCrack end
		if d.goal == nil then return nil, inCrack end
	end
	return nil, inCrack
end

local FLOOR = Vector3.new(25, 0, 8)
local rig = { Vector3.yAxis }

case("a graph of the sill: faces, seams, a few hundred places to patrol to, none in the crack", function()
	check(#faces == #Layout.PIECES * 6, "every face of every box is a node")
	local d = newRival(FLOOR, Vector3.yAxis)
	check(#d.waypoints >= 80, `places to patrol to are spread over the sill ({#d.waypoints})`)
	local pieces: { [string]: boolean } = {}
	for _, w in d.waypoints do
		pieces[faces[w.face].piece] = true
		check(not Layout.inRetreat(w.pos + w.up * Route.SEAT) and not Route.inKeepOut(w.pos), "no place to patrol to is in or beside the crack")
	end
	for _, piece in { "sill_floor", "leaf_west", "leaf_east", "planter", "planter_rim", "back_frame", "left_frame", "right_frame", "stem_west", "garden_step" } do
		check(pieces[piece] == true, `{piece} has a place to patrol to`)
	end
	check(not pieces.crevice_south and not pieces.leaf_tip, "the crack and the dry leaf tip have none")
	check(Route.faceAt(Vector3.new(25, 0.31, 8), Vector3.yAxis) ~= nil and Route.faceAt(Vector3.new(0, 20, 0), Vector3.yAxis) == nil, "a body on the floor is on a face, one in the air is on none")
	check(Route.inKeepOut(Vector3.new(-26, 0.31, 6)) and not Route.inKeepOut(Vector3.new(0, 0.31, 0)), "the keep-out box holds the crack and its margin")
end)

case("it walks to a place on the floor, a leaf, the planter's rim and the wall", function()
	local d, r = newRival(FLOOR, Vector3.yAxis)
	local s = snapshot()
	local targets = {
		{ "the floor", waypointOn(d, "sill_floor", function(w: any): boolean return w.pos.X < 0 and w.pos.Z < -2 end) },
		{ "a leaf top", waypointOn(d, "leaf_west", function(w: any): boolean return w.up.Y > 0.9 end) },
		{ "the planter's rim", waypointOn(d, "planter_rim", function(w: any): boolean return w.up.Y > 0.9 end) },
		{ "the back wall", waypointOn(d, "back_frame", function(w: any): boolean return w.up.Z > 0.9 end) },
		{ "a stem", waypointOn(d, "stem_east") },
	}
	for _, t in targets do
		local took, inCrack = walkTo(d, r, s, t[2], 200)
		check(took ~= nil, `reaches {t[1]}`)
		check(inCrack == 0, `on the way to {t[1]} it never enters the crack`)
		check(r.state == "patrol" and Rival.valid(r), "it stays a valid patrolling rival")
	end
	check(d.stats.arrivals == #targets, "every arrival counted once")
end)

case("the crack is never entered: along the wall beside it, across the floor in front of it, and on the way home", function()
	local d, r = newRival(Vector3.new(-29.7, 1.0, -9), Vector3.xAxis)
	local s = snapshot()
	local wall = waypointOn(d, "left_frame", function(w: any): boolean return w.up.X > 0.9 and w.pos.Z > 5 end)
	local took, inCrack = walkTo(d, r, s, wall, 260)
	check(took ~= nil and inCrack == 0, "from the south end of the left frame to its north end it goes round the crack")
	check(Route.inKeepOut(Vector3.new(-29.69, 1.0, 6)), "the stretch of wall it rounded is the crack's")
	-- The floor: from south of the crack to north of it.
	local floorFace = Route.faceAt(Vector3.new(-24, 0.31, -3), Vector3.yAxis)
	local north = { pos = Vector3.new(-24, 0, 11), up = Vector3.yAxis, face = Route.faceAt(Vector3.new(-24, 0.31, 11), Vector3.yAxis) :: number }
	local d2, r2 = newRival(Vector3.new(-24, 0, -3), Vector3.yAxis)
	check(floorFace ~= nil and north.face == floorFace, "both ends are floor")
	local took2, crack2 = walkTo(d2, r2, s, north, 200)
	check(took2 ~= nil and crack2 == 0, "across the floor in front of the crack it goes round")
	local min = math.huge
	local d3, r3 = newRival(Vector3.new(-24, 0, 11), Vector3.yAxis)
	d3:_setGoal({ pos = Vector3.new(-24, 0, -3), up = Vector3.yAxis, face = floorFace :: number }, "patrol")
	for _ = 1, 60 * 60 do
		Drive.update(d3, r3, DT, s)
		min = math.min(min, (d3.motor.pos - Vector3.new(-26.4, 0.31, 6)).Magnitude)
		if Layout.inRetreat(d3.motor.pos) then check(false, "walked into the crack on the way home") break end
	end
	check(min > 1.0, `it keeps clear of the crack ({string.format("%.2f", min)})`)
	-- However it is placed or thrown, the retreat is refused: whatever it did, it is back outside.
	local d4, r4, m4 = newRival(Vector3.new(-24, 0, 11), Vector3.yAxis)
	m4:place(Vector3.new(-26, 0.31, 6), Vector3.yAxis, Vector3.xAxis)
	Drive.update(d4, r4, DT, s)
	check(not Layout.inRetreat(m4.pos) and not Layout.inRetreat(r4.position), "a rival put in the crack is put back out of it")
end)

case("it stalks across a leaf: creeps toward the spider, winds up for a second, lunges, and the lunge lands from the leaf", function()
	local leaf: any
	for _, f in faces do
		if f.piece == "leaf_east" and f.normal.Y > 0.9 then leaf = f end
	end
	check(leaf ~= nil and #leaf.stand > 10, "the east leaf has a top to stand on")
	local a, b = leaf.stand[1], leaf.stand[1]
	local bestGap = math.huge
	for _, p in leaf.stand do
		for _, q in leaf.stand do
			local gap = math.abs((p - q).Magnitude - 4.5)
			if gap < bestGap then a, b, bestGap = p, q, gap end
		end
	end
	local d, r, m = newRival(a, Vector3.yAxis, function() return false end)
	local s = snapshot()
	s.position = b + Vector3.yAxis * Route.SEAT
	s.previous = s.position
	s.drive = d
	local start = (s.position - r.position).Magnitude
	check(start > 3.5, `the spider is a few wu away on the same leaf ({string.format("%.1f", start)})`)
	local events: { string } = {}
	local stalkStart, windupAt, closest = nil :: number?, nil :: number?, math.huge
	local sawStalk, sawWindup, sawLunge = false, false, false
	for k = 1, 60 * 30 do
		local event = Rival.step(r, DT, s, function() return false end)
		Drive.update(d, r, DT, s)
		if event ~= "" then table.insert(events, event) end
		if r.state == "stalk" then sawStalk = true; stalkStart = stalkStart or k end
		if r.state == "windup" and not sawWindup then sawWindup = true; windupAt = (s.position - r.position).Magnitude end
		if r.state == "lunge" then sawLunge = true end
		closest = math.min(closest, (s.position - r.position).Magnitude)
		if event == "caught" then break end
	end
	check(sawStalk and sawWindup and sawLunge, "patrol, stalk, windup, lunge, in that order")
	check(events[1] == "warning" and events[#events] == "caught", `the spider is warned, then caught ({table.concat(events, ",")})`)
	check(windupAt ~= nil and windupAt <= Rules.reachWu + 0.1, "it winds up within reach, not from across the leaf")
	check(closest < start - 1.5, "it crept toward the spider")
	check(r.up.Y > 0.99 and math.abs(r.position.Y - (leaf.plane + Route.SEAT)) < 0.35, "and stayed on the leaf")
	check(Rival.valid(r), "a valid rival throughout")
	-- The lunge in the air lands back on the leaf and the rival goes on patrolling from there.
	for _ = 1, 60 * 5 do
		s.position = Vector3.new(0, 30, 0)
		Rival.step(r, DT, s, function() return true end)
		Drive.update(d, r, DT, s)
	end
	check(r.state == "patrol" and m.mode == "attached" and Rival.valid(r), "after the miss or the catch it is back on its feet and patrols again")
end)

case("it goes on toward the last place it saw the spider, for three seconds, and then gives up", function()
	local leaf: any
	for _, f in faces do
		if f.piece == "leaf_east" and f.normal.Y > 0.9 then leaf = f end
	end
	local a, b = leaf.stand[1], leaf.stand[#leaf.stand]
	local seen = true
	local d, r = newRival(a, Vector3.yAxis, function() return not seen end)
	local s = snapshot()
	s.position = a + Vector3.yAxis * Route.SEAT + (b - a).Unit * 3.5
	s.previous = s.position
	s.drive = d
	local reachedStalk = false
	for _ = 1, 60 * 3 do
		Rival.step(r, DT, s, function() return false end)
		Drive.update(d, r, DT, s)
		if r.state == "stalk" then reachedStalk = true break end
	end
	check(reachedStalk, "it notices the spider")
	local mark = r.position
	seen = false
	for _ = 1, 90 do
		Rival.step(r, DT, s, function() return true end)
		Drive.update(d, r, DT, s)
	end
	check(r.state == "stalk" and (r.position - mark).Magnitude > 0.5, "out of sight for 1.5 s it is still stalking, toward where it saw the spider")
	for _ = 1, 60 * 5 do
		Rival.step(r, DT, s, function() return true end)
		Drive.update(d, r, DT, s)
	end
	check(r.state == "patrol", "after the memory fades it patrols again")
end)

case("a wasp visit pauses it; the retreat shelters the spider; held where it was caught; eaten once", function()
	local d, r = newRival(FLOOR, Vector3.yAxis, function() return false end)
	local s = snapshot()
	s.position = Vector3.new(20, 0.31, 8)
	s.previous = s.position
	s.drive = d
	for _ = 1, 60 do
		Rival.step(r, DT, s, function() return false end)
		Drive.update(d, r, DT, s)
	end
	s.wasp = true
	Rival.step(r, DT, s, function() return false end)
	Drive.update(d, r, DT, s)
	local at = r.position
	for _ = 1, 120 do
		Rival.step(r, DT, s, function() return false end)
		Drive.update(d, r, DT, s)
	end
	check(r.state == "recover" and (r.position - at).Magnitude < 0.05, "during a wasp visit it stands still")
	s.wasp = false
	-- Sheltered: the spider in the crack is never attacked and the rival never stalks to it.
	local d2, r2 = newRival(Vector3.new(-18, 0, 6), Vector3.yAxis, function() return false end)
	local s2 = snapshot()
	s2.position = Vector3.new(-26, 0.31, 6)
	s2.previous = s2.position
	s2.safe = true
	s2.drive = d2
	local worst = 0
	for _ = 1, 60 * 40 do
		local event = Rival.step(r2, DT, s2, function() return false end)
		Drive.update(d2, r2, DT, s2)
		if r2.state == "stalk" or r2.state == "windup" or r2.state == "lunge" or event ~= "" then worst += 1 end
		if Layout.inRetreat(d2.motor.pos) then worst += 1000 end
	end
	check(worst == 0, "the rival neither stalks, strikes nor enters while the spider is in the retreat")
	-- Caught by the spider on a leaf: held where it is, eaten for the full food, once.
	local d3, r3 = newRival(FLOOR, Vector3.yAxis, function() return false end)
	local s3 = snapshot()
	s3.position = r3.position
	s3.previous = s3.position
	s3.striking = true
	s3.drive = d3
	local event = Rival.step(r3, DT, s3, function() return false end)
	Drive.update(d3, r3, DT, s3)
	check(event == "captured", "the spider's jump catches it")
	s3.striking = false
	local held = s3.position + s3.heading * 0.4
	local food = 0.0
	for _ = 1, 400 do
		local _, n = Rival.step(r3, DT, s3, function() return false end)
		Drive.update(d3, r3, DT, s3)
		food += n
	end
	check(math.abs(food - Rival.FOOD) < 1e-8 and r3.state == "consumed" and (r3.position - held).Magnitude < 0.01, "held in the spider's jaws and eaten for exactly two housefly meals")
end)

case("an older record (no up, no leg) is accepted; a bad one is refused; a record that moved the rival moves its legs", function()
	local r = Rival.new()
	r.up, r.leg = nil, nil
	check(Rival.valid(r), "a record from before the roaming rival is valid")
	r.state, r.position = "patrol", Vector3.new(25, 0.31, 8)
	local d = Drive.new(newMotor(), function() return true end)
	Drive.update(d, r, DT, snapshot())
	check(r.up ~= nil and r.up.Y > 0.99, "and means the floor")
	local bad = Rival.new()
	bad.leg = -1
	check(not Rival.valid(bad), "a negative leg is refused")
	bad.leg = 1.5
	check(not Rival.valid(bad), "a fractional leg is refused")
	bad.leg = 3
	bad.up = Vector3.new(0, 3, 0)
	check(not Rival.valid(bad), "an up that is not a direction is refused")
	bad.up = Vector3.yAxis
	bad.state = "patrol"
	bad.position = Vector3.new(-26, 0.31, 6)
	check(not Rival.valid(bad), "a rival in the retreat is refused")
	bad.position = Vector3.new(0, 90, 0)
	check(not Rival.valid(bad), "a rival outside the sill is refused")
	bad.state = "captured"
	check(Rival.valid(bad), "(a rival the spider holds goes where the spider goes, even to the crack: not checked)")
	-- Restored elsewhere: the legs follow the state.
	local d2, r2, m2 = newRival(FLOOR, Vector3.yAxis)
	Drive.update(d2, r2, DT, snapshot())
	r2.position, r2.up = Vector3.new(0, 0.31, 0), Vector3.yAxis
	Drive.update(d2, r2, DT, snapshot())
	check((m2.pos - Vector3.new(0, 0.31, 0)).Magnitude < 0.5, "a restored rival stands where the record says")
end)

case("what it costs: rays per tick, decisions and plans", function()
	local d, r = newRival(FLOOR, Vector3.yAxis)
	local s = snapshot()
	local started = os.clock()
	rays = 0
	local ticks = 0
	-- A minute and a half of patrol over a floor, a wall and a leaf.
	local legs = { waypointOn(d, "leaf_west", function(w: any): boolean return w.up.Y > 0.9 end), waypointOn(d, "back_frame", function(w: any): boolean return w.up.Z > 0.9 end),
		waypointOn(d, "sill_floor", function(w: any): boolean return w.pos.X < 0 and w.pos.Z < -2 end) }
	for _, w in legs do
		d:_setGoal(w, "patrol")
		for _ = 1, 60 * 30 do
			Drive.update(d, r, DT, s)
			ticks += 1
		end
	end
	local elapsed = os.clock() - started
	local perTick = rays / ticks
	print(string.format("RIVALNAV perf: %d ticks, %.2f rays/tick, %.0f thinks, %d plans, %d replans, %d resets, %.0f ticks/s of CPU shim time", ticks, perTick,
		d.stats.thinks, d.stats.plans, d.stats.replans, d.stats.resets, ticks / math.max(elapsed, 1e-6)))
	check(perTick < 12, `rays per tick stay low ({string.format("%.2f", perTick)})`)
	check(d.stats.thinks <= ticks / 6 + 2, "decisions are made ten times a second, not every tick")
	check(d.stats.plans <= 40, `plans are rare ({d.stats.plans})`)
	-- A standing rival costs a ray or two a tenth of the ticks.
	rays = 0
	r.state = "recover"
	for _ = 1, 600 do Drive.update(d, r, DT, s) end
	check(rays / 600 < 1.5, `a standing rival costs almost nothing ({string.format("%.2f", rays / 600)} rays/tick)`)
end)

print(`RIVALNAV passed={passed} failed={failed}`)
if failed > 0 then error("RIVALNAV failed") end
