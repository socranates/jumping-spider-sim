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
local Grip = require("../src/Shared/Predator/RivalGrip")
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
	for _, piece in { "sill_floor", "leaf_west", "leaf_east", "planter", "planter_rim", "back_frame_west", "back_frame_east", "back_frame_head", "left_frame", "right_frame", "stem_west", "garden_step" } do
		check(pieces[piece] == true, `{piece} has a place to patrol to`)
	end
	check(not pieces.crevice_south and not pieces.leaf_tip, "the crack and the dry leaf tip have none")
	-- ROBLOX-95: the open sash is the sill's second keep-out: no place to patrol to is in it (the rail and the cut through the wall are not the rival's)
	local inSash = 0
	for _, w in d.waypoints do
		if Route.inKeepOut(w.pos) or Route.inKeepOut(w.pos + w.up * Route.SEAT) then inSash += 1 end
	end
	check(inSash == 0 and not pieces.back_frame_rail, `no place to patrol to is in the open sash or on its rail ({inSash})`)
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
		{ "the back wall", waypointOn(d, "back_frame_west", function(w: any): boolean return w.up.Z > 0.9 end) },
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

case("it goes on toward the last place it saw the spider, for five seconds, and then gives up", function()
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
	for _ = 1, 150 do
		Rival.step(r, DT, s, function() return true end)
		Drive.update(d, r, DT, s)
	end
	check(Rules.rememberSeconds == 5.0 and r.state == "stalk", "and out of sight for 4 s it still is (it gave up after 3 before ROBLOX-73)")
	for _ = 1, 60 * 5 do
		Rival.step(r, DT, s, function() return true end)
		Drive.update(d, r, DT, s)
	end
	check(r.state == "patrol", "after the memory fades it patrols again")
end)

case("it presses harder (ROBLOX-73): the windup starts at 3.2 wu, and a strike at a rival that has seen the spider is a contest", function()
	local leaf: any
	for _, f in faces do
		if f.piece == "leaf_east" and f.normal.Y > 0.9 then leaf = f end
	end
	-- Two spiders of the leaf's own width apart: the windup begins inside 3.2 wu, and not at 3.4.
	local a, b = leaf.stand[1], leaf.stand[1]
	local bestGap = math.huge
	for _, p in leaf.stand do
		for _, q in leaf.stand do
			local gap = math.abs((p - q).Magnitude - 3.4)
			if gap < bestGap then a, b, bestGap = p, q, gap end
		end
	end
	local d, r = newRival(a, Vector3.yAxis, function() return false end)
	local s = snapshot()
	s.position, s.drive = b + Vector3.yAxis * Route.SEAT, d
	s.previous = s.position
	local from = (s.position - r.position).Magnitude
	check(from > 3.2 and from < 3.7, `the spider starts just beyond reach ({string.format("%.2f", from)} wu)`)
	local windupAt: number? = nil
	for _ = 1, 60 * 6 do
		Rival.step(r, DT, s, function() return false end)
		Drive.update(d, r, DT, s)
		if r.state == "windup" then windupAt = (s.position - r.position).Magnitude break end
	end
	check(windupAt ~= nil and windupAt > 2.6 and windupAt <= Rules.reachWu + 0.1, `it winds up from {string.format("%.2f", windupAt or -1)} wu, beyond the old 2.5`)
	-- The strike on a rival in its windup is a contest through the real drive: every one of the three outcomes happens over some days, each one is valid.
	local seen: { [string]: number } = {}
	for day = 1, 60 do
		local d2, r2 = newRival(a, Vector3.yAxis, function() return false end)
		r2.state, d2.prevState = "windup", "windup"
		local s2 = snapshot()
		s2.day, s2.seed = day, 914
		s2.position, s2.drive = r2.position + Vector3.xAxis * 0.2, d2
		s2.previous = s2.position
		s2.striking = true
		local event, amount = Rival.step(r2, DT, s2, function() return false end)
		Drive.update(d2, r2, DT, s2)
		seen[event] = (seen[event] or 0) + 1
		check(event == Rival.contest(914, day, 0), `day {day}: the outcome is the draw's ({event})`)
		if event == "captured" then
			check(r2.state == "captured", "caught: held")
		else
			check(r2.state == "recover" and r2.spared == true and Rival.valid(r2) and (event ~= "counter" or amount == Rules.counterCost), `day {day}: {event}: it recovers, and the cost is right`)
		end
	end
	check((seen.captured or 0) > 20 and (seen.sprang or 0) > 5 and (seen.counter or 0) > 3, `over sixty days: caught {seen.captured}, sprang clear {seen.sprang}, counter-bite {seen.counter}`)
	-- One that has not noticed is still caught outright, through the drive.
	local d3, r3 = newRival(a, Vector3.yAxis, function() return false end)
	local s3 = snapshot()
	s3.position, s3.drive, s3.striking = r3.position + Vector3.xAxis * 0.2, d3, true
	s3.previous = s3.position
	check(Rival.step(r3, DT, s3, function() return false end) == "captured" and r3.contests == 0, "an unaware patrolling rival is still caught outright, with no draw")
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
	-- ROBLOX-77: it fights the tapping grip first (the drive keeps it in the jaws meanwhile), and only a subdued rival is eaten.
	local grip, outcome, struggled = Grip.new(), "", 0.0
	for i = 1, 60 * 30 do
		local e = Rival.step(r3, DT, s3, function() return false end)
		if e ~= "struggling" and outcome == "" then outcome = "ate before the fight ended" end
		if i % 13 == 1 then Grip.tap(grip) end -- about 4.6 taps a second, from the first tick
		Drive.update(d3, r3, DT, s3)
		local ge = Grip.step(grip, r3, DT, s3)
		struggled += DT
		if ge == "subdued" or ge == "tore" then outcome = ge; break end
		if (r3.position - held).Magnitude > 0.01 then
			outcome = "left the jaws"
			break
		end
	end
	check(outcome == "subdued" and r3.food == Rival.FOOD and (r3.position - held).Magnitude < 0.01, `held in the jaws through a ~4.6-a-second fight of {struggled} s, nothing eaten until subdued ({outcome})`)
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
	local legs = { waypointOn(d, "leaf_west", function(w: any): boolean return w.up.Y > 0.9 end), waypointOn(d, "back_frame_west", function(w: any): boolean return w.up.Z > 0.9 end),
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

-- ---------------------------------------------------------------- ROBLOX-95: a graph per region, seams between them
case("a graph per region: the sill's is the module's, every region has its own from its own pieces", function()
	local sillGraph = Route.graph()
	check(Route.graph("sill") == sillGraph and Route.faces() == sillGraph:allFaces(), "the module's functions are the sill's graph's")
	check(#Route.waypoints() == #sillGraph:waypoints() and Route.faceAt(Vector3.new(25, 0.31, 8), Vector3.yAxis) == sillGraph:faceAt(Vector3.new(25, 0.31, 8), Vector3.yAxis), "and answer the same")
	local counts = {}
	for _, region in WorldMap.regions() do
		local g = Route.graph(region.id)
		local pieces = Region.pieces(region)
		check(#g:allFaces() == #pieces * 6, `{region.id}: every face of its {#pieces} boxes is a node, and only its own`)
		check(#pieces <= 60, `{region.id}: {#pieces} boxes, inside the design's 60 for a graph Dijkstra runs over`)
		local ids: { [string]: boolean } = {}
		for _, piece in pieces do ids[piece.id] = true end
		local strangers = 0
		for _, f in g:allFaces() do if not ids[f.piece] then strangers += 1 end end
		check(strangers == 0, `{region.id}: no face of another region's box`)
		counts[region.id] = #g:waypoints()
	end
	print(`RIVALNAV places to patrol to: sill {counts.sill}, outer_sill {counts.outer_sill}, house_wall {counts.house_wall}, bed_a {counts.bed_a}`)
	check(counts.bed_a >= 30 and counts.outer_sill >= 5 and counts.house_wall >= 5, "every region outside has places to stand")
	local bed = Route.graph("bed_a")
	local stone = (WorldMap.retreat("bed_a_stone") :: WorldMap.Retreat)
	local inStone = 0
	for _, w in bed:waypoints() do
		if bed:inKeepOut(w.pos) or (w.pos.X >= stone.min.X and w.pos.X <= stone.max.X and w.pos.Z >= stone.min.Z and w.pos.Z <= stone.max.Z and w.pos.Y <= stone.max.Y) then inStone += 1 end
	end
	check(inStone == 0, "the bed's places keep out of the gap under its stone")
	check(not pcall(Route.graph, "garden"), "a region that is not on the map has no graph")
end)

case("the bed's graph plans: from the soil up a stem and out onto a leaf, to the stone's top, and round the stone", function()
	local bed = Route.graph("bed_a")
	local up = Vector3.yAxis
	local soilAt = Vector3.new(-20, -90, -30)
	local soil = bed:faceAt(soilAt + up * Route.SEAT, up) :: number
	check(soil ~= nil and bed:allFaces()[soil].piece == "bed_a_soil", "a body on the soil is on the soil's top")
	local function topOf(id: string): (number?, Vector3)
		for _, region in WorldMap.regions() do
			for _, piece in Region.pieces(region) do
				if piece.id == id then
					local at = Vector3.new((piece.lo.X + piece.hi.X) / 2, piece.hi.Y, (piece.lo.Z + piece.hi.Z) / 2)
					return bed:faceAt(at + up * Route.SEAT, up), at
				end
			end
		end
		return nil, Vector3.zero
	end
	for _, id in { "bed_a_dock_leaf_1", "bed_a_dock_leaf_3", "bed_a_stone_top", "bed_a_dandelion_leaf_2", "bed_a_mound_1" } do
		local face, at = topOf(id)
		local hops = if face ~= nil then bed:plan(soil, soilAt, face, at) else nil
		check(hops ~= nil and #hops >= 1, `a way from the soil to the top of {id} ({if hops then #hops else "none"} hops)`)
	end
end)

case("seams: every seam the map declares joins the two regions' graphs along its line, both ways", function()
	for _, region in WorldMap.regions() do
		local g = Route.graph(region.id)
		for _, n in region.neighbors do
			local edges, off, samples = 0, 0, 0
			for _, s in g:allSeams() do
				if s.edge.region == n.id then
					edges += 1
					for _, p in s.edge.samples do
						samples += 1
						local ab = n.b - n.a
						local t0 = (p - n.a):Dot(ab) / ab:Dot(ab)
						if t0 < -1e-6 or t0 > 1 + 1e-6 or (n.a + ab * t0 - p).Magnitude > 0.06 then off += 1 end
					end
					local other = Route.graph(n.id)
					local back = false
					for _, e in other:seamsOf(s.edge.to) do
						if e.region == region.id and e.to == s.face then back = true end
					end
					check(back, `{region.id} to {n.id}: the edge from face {s.face} has one back`)
				end
			end
			check(edges >= 1 and samples >= 3, `{region.id} meets {n.id} along its seam ({edges} edges, {samples} places to cross)`)
			check(off == 0, `{region.id} to {n.id}: every place to cross is on the seam's line ({off} off it)`)
		end
	end
	-- what the seams are: the rail's outer face onto the stone (a corner), the stone's front face into the brick (flat), the wall's foot onto the soil (a corner)
	local function kinds(from: string, to: string): (boolean, boolean)
		local flat, corner = false, false
		for _, s in Route.graph(from):allSeams() do
			if s.edge.region == to then
				if s.edge.flat then flat = true else corner = true end
			end
		end
		return flat, corner
	end
	local f1, c1 = kinds("sill", "outer_sill")
	local f2, c2 = kinds("outer_sill", "house_wall")
	local f3, c3 = kinds("house_wall", "bed_a")
	check(c1 and not f1, "sill to outer sill: across the corner where the rail's outer face meets the stone")
	check(f2 and not c2, "outer sill to wall: flat, where the stone's front face goes on down as brick")
	check(c3 and not f3, "wall to bed: across the corner of the wall's foot and the soil")
	-- the sill's planner never crosses a seam: a plan stays on the sill's faces
	local sillGraph = Route.graph()
	local hops = sillGraph:plan(Route.faceAt(Vector3.new(0, 0.31, -10), Vector3.yAxis) :: number, Vector3.new(0, 0, -10),
		Route.faceAt(Vector3.new(25, 0.31, 8), Vector3.yAxis) :: number, Vector3.new(25, 0, 8))
	check(hops ~= nil, "a plan across the sill in front of the opening")
	local strays = 0
	for _, h in hops or {} do
		if h.face > #sillGraph:allFaces() or Route.inKeepOut(h.seam) then strays += 1 end
	end
	check(strays == 0, "and every hop of it is on the sill, outside the sash")
end)

case("the rival walks along the back wall's foot past the open sash and never goes into it", function()
	local d, r = newRival(Vector3.new(-14, 0, -11.8), Vector3.yAxis)
	local s = snapshot()
	local goal = { pos = Vector3.new(14, 0, -11.8), up = Vector3.yAxis, face = Route.faceAt(Vector3.new(14, 0.31, -11.8), Vector3.yAxis) :: number }
	d:_setGoal(goal, "patrol")
	local inSash, behind, arrived = 0, 0, false
	local before = d.stats.arrivals
	for _ = 1, 60 * 90 do
		Drive.update(d, r, DT, s)
		if Route.inKeepOut(d.motor.pos) then inSash += 1 end
		if d.motor.pos.Z < -12.5 then behind += 1 end
		if d.stats.arrivals > before then arrived = true; break end
	end
	check(arrived, "it gets past the opening")
	check(inSash == 0 and behind == 0, `never in the sash ({inSash} ticks) nor through the frame ({behind})`)
end)

-- ---------------------------------------------------------------- ROBLOX-117: the rival and the mate in the preserve's hut garden
case("the preserve: the rival arrives in the hut garden and roams its cells across their seams, never the hut, never a retreat; the mate too", function()
	local Hut = require("../src/Shared/World/Hut")
	local Mate = require("../src/Shared/Predator/Mate")
	local MateDrive = require("../src/Shared/Predator/MateDrive")
	WorldMap.use("preserve")
	local ok, err = pcall(function()
		-- the garden's boxes and what stands round it, as a box world
		local pieces = {}
		for _, r in WorldMap.regions() do
			-- (ROBLOX-119: the rival's roam goes on up the path to the bench patch and the meadow's edge: their boxes and the furniture's too)
			if Rival.PRESERVE_ROAM[r.id] or r.kind == "garden_pole" or r.id == "hut_bench" or r.id == "hut_butt" or r.kind == "hut_wall" or r.id == "path_e6"
				or r.kind == "park_bench" or r.kind == "park_bin" or r.id == "lamp_1" or r.id == "pad_b3" or r.id == "meadow_b2" or r.id == "meadow_b3" then
				for _, p in Region.pieces(r) do table.insert(pieces, p) end
			end
		end
		local garden = BoxWorld.folder("NavGarden", pieces)
		local list = {}
		for id in Rival.PRESERVE_ROAM do table.insert(list, WorldMap.region(id)) end
		local lo, hi = WorldMap.unionOf(list :: any)
		local function motorAt(at: Vector3): any
			return Motor.new({ world = garden, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = at, heading = Vector3.new(-1, 0, 0),
				boundsMin = lo, boundsMax = hi, probeParent = garden })
		end
		local r = Rival.new()
		check(r.region == "garden_d2" and (r.position - Hut.CREATURES.rival.at).Magnitude < 1e-6 and Rival.roam() == Rival.PRESERVE_ROAM, "a preserve rival arrives on the garden's path, its region kept")
		check(Rival.valid(r) and not Rival.misplaced(r), "and its record is good and of this world")
		local m = motorAt(r.position)
		local d = Drive.new(m, function() return true end, r.region, Rival.roam())
		r.state = "patrol"
		m:place(r.position, Vector3.yAxis, Vector3.new(-1, 0, 0))
		r.position, r.previous, r.origin = m.pos, m.pos, m.pos
		d.prevState = "patrol"
		local s = snapshot()
		s.position, s.previous, s.seed = Vector3.new(0, 0.31, 0), Vector3.new(0, 0.31, 0), 914 -- (the spider on the sill, in the hut: the rival never sees it)
		local visited: { [string]: boolean } = { [r.region] = true }
		local inHut, inRetreat, outside, mismatch, n = 0, 0, 0, 0, 0
		for _ = 1, 60 * 900 do
			Drive.update(d, r, DT, s)
			local p = d.motor.pos
			local here = WorldMap.at(p)
			if here ~= nil and Hut.knows(here.kind) and not Rival.PRESERVE_ROAM[here.id] and here.kind ~= "garden_pole" then inHut += 1 end
			if WorldMap.inRetreat(p) ~= nil then inRetreat += 1 end
			if p.X < lo.X - 0.5 or p.X > hi.X + 0.5 or p.Z < lo.Z - 0.5 or p.Z > hi.Z + 0.5 then outside += 1 end
			if here ~= nil and here.id ~= r.region and not WorldMap.inBounds(p, r.region) then mismatch += 1 end
			visited[r.region] = true
		end
		for _ in visited do n += 1 end
		print(`RIVALNAV the preserve: the rival in 15 minutes crossed {d.stats.crossings or 0} seams and walked {n} of its roam's regions (the garden's 16 cells, ROBLOX-119: and the path, the bench patch and the meadow's edge); {d.stats.arrivals} places reached`)
		check((d.stats.crossings or 0) >= 2 and n >= 3, `it crosses from cell to cell ({d.stats.crossings or 0} crossings, {n} cells)`)
		check(inHut == 0 and inRetreat == 0 and outside == 0, `never in the hut ({inHut} ticks), a retreat ({inRetreat}) or out of the garden ({outside})`)
		check(mismatch < 60 * 5, `its record's region is the one it stands in (out of it {mismatch} ticks, crossing)`)
		check(Rival.valid(r), "its record after a walk is good")
		-- the stalk follows the spider over a seam: the spider stands in the cell beside it, seen
		local start = Vector3.new(40, Hut.GROUND + 0.31, -121)
		local seen = Drive.new(motorAt(start), function() return nil end, "garden_b3", Rival.roam())
		local r2 = Rival.new()
		r2.state = "stalk"
		local other = WorldMap.region("garden_a3")
		local target = Vector3.new(40, Hut.GROUND + 0.31, -114.5)
		seen.motor:place(start, Vector3.yAxis, Vector3.zAxis)
		r2.position, r2.previous, r2.up, r2.heading, r2.origin, r2.region = seen.motor.pos, seen.motor.pos, seen.motor.up, Vector3.zAxis, seen.motor.pos, "garden_b3"
		seen.prevState = "stalk"
		local s2 = snapshot()
		s2.position, s2.previous, s2.seed = target, target, 914
		local crossed = false
		for _ = 1, 60 * 120 do
			seen:update(r2, DT, s2)
			if r2.region == (other :: WorldMap.Region).id then crossed = true; break end
		end
		check(crossed, "a stalk goes over the seam after the spider (garden_b3 to garden_a3)")
		-- (ROBLOX-119) on the meadow's edge: a rival in the grass by the bench patch walks the edge's cells and the gravel, never out of its roam
		do
			local a3 = WorldMap.region("meadow_a3") :: any
			local md = Drive.new(motorAt(a3.spawn.pos + Vector3.new(0, 0.31, 0)), function() return true end, "meadow_a3", Rival.roam())
			local r3 = Rival.new()
			r3.state = "patrol"
			md.motor:place(a3.spawn.pos + Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(1, 0, 0))
			r3.position, r3.previous, r3.origin, r3.region = md.motor.pos, md.motor.pos, md.motor.pos, "meadow_a3"
			md.prevState = "patrol"
			local s3 = snapshot()
			s3.position, s3.previous, s3.seed = Vector3.new(0, 0.31, 0), Vector3.new(0, 0.31, 0), 914
			local cells: { [string]: boolean } = {}
			local astray, start = 0, md.motor.pos
			for _ = 1, 60 * 600 do
				Drive.update(md, r3, DT, s3)
				cells[r3.region] = true
				local here = WorldMap.at(md.motor.pos)
				if here ~= nil and not Rival.PRESERVE_ROAM[here.id] and not WorldMap.inBounds(md.motor.pos, r3.region) then astray += 1 end
			end
			local nc = 0
			for _ in cells do nc += 1 end
			print(`RIVALNAV the meadow's edge: in 10 minutes the rival walked {nc} regions ({md.stats.crossings or 0} crossings), {string.format("%.0f", (md.motor.pos - start).Magnitude)} studs from where it began, in {tostring(r3.region)}, its record good {Rival.valid(r3)}`)
			check((md.motor.pos - start).Magnitude > 5 and astray < 60 * 5 and Rival.valid(r3) and Rival.PRESERVE_ROAM[r3.region], `a rival at the meadow's edge walks it, in its roam ({nc} regions, astray {astray} ticks)`)
		end
		-- the mate: arrives where it comes in from the path round the east end, roams, and its record keeps its region
		local mate = Mate.new()
		check(mate.region == "garden_b4" and (mate.position - Hut.CREATURES.mate.at).Magnitude < 1e-6 and (Mate.exitAt() - Hut.CREATURES.mate.exit).Magnitude < 1e-6,
			"a preserve mate comes in on the garden's path from the east, and leaves the same way")
		mate.state = "wander"
		local md = MateDrive.new(motorAt(mate.position), function() return true end, mate.region, Mate.roam())
		md.drive.motor:place(mate.position, Vector3.yAxis, Vector3.new(-1, 0, 0))
		mate.position = md.drive.motor.pos
		local mateCells: { [string]: boolean } = {}
		local ms = snapshot()
		ms.position, ms.seed = Vector3.new(0, 0.31, 0), 914
		for _ = 1, 60 * 600 do
			MateDrive.update(md, mate, DT, ms)
			mateCells[mate.region] = true
		end
		local mc = 0
		for _ in mateCells do mc += 1 end
		check(mc >= 2 and Mate.valid(mate), `the mate roams the garden too ({mc} cells) and its record is good`)
		-- another world's: a sill rival in the preserve is not here (a new one comes), and a preserve rival in the test garden
		local old = Rival.new()
		old.region = nil
		old.position = Vector3.new(25, 0.31, 8)
		check(Rival.misplaced(old) and Rival.valid(old), "a rival of the sill's kept in a rest is misplaced in the preserve (and a good record)")
		WorldMap.use("test_garden")
		check(Rival.misplaced(r) and Rival.valid(r) and not Rival.misplaced(Rival.new()) and Rival.new().region == nil, "a preserve rival is misplaced in the test garden, whose rivals have no region")
		local renewed = table.clone(r)
		renewed.state = "patrol"
		Rival.step(renewed, DT, snapshot(), function() return nil end)
		check(renewed.region == nil and (renewed.position - Rules.arriveAt).Magnitude < 0.1 and (renewed.contests or 0) == 0, `and a step there makes it the test garden's next rival, arriving at the sill's east end ({renewed.state})`)
		local mm = Mate.new()
		check(mm.region == nil and (mm.position - Vector3.new(26.0, 0.31, 3.0)).Magnitude < 1e-6, "the test garden's mate is as it was")
	end)
	WorldMap.use("test_garden")
	if not ok then error(err) end
end)

print(`RIVALNAV passed={passed} failed={failed}`)
if failed > 0 then error("RIVALNAV failed") end
