-- Perception port checks, part 2 (the world half): Sensor.luau, Godot's SensorSystem rays and gaze, on the box world of tests/shim.luau.
-- The fixtures are Godot's own, with the same numbers: tests/sensor_rig_case.gd (an eye at the origin looking along -Z, walls that can be
-- raised and lowered, balls that stand for things, the species profile as shipped) with test_sensor_occlusion.gd (A-024, Chet's review 3),
-- test_sensor_association.gd (A-027, chunks 7A and 7B), and the rates, cues and cone of test_sensor.gd and test_t13a_motion_surround.gd.
-- Walls are boxes of the shim; a ray is the shim's (axis-aligned boxes, doubles) where Godot's was the physics server's, so a test that rests on
-- a margin uses the same margin. Not the engine's raycast: Studio runs tests/studio/PerceptionSpec for that.
-- Run with the other suites:  python3 tests/run.py path/to/luau sensor.luau
local shim = require("./shim")
_G.Vector3 = shim.Vector3
_G.CFrame = shim.CFrame
local Observation = require("../src/Shared/Perception/Observation")
local PerceptionMath = require("../src/Shared/Perception/PerceptionMath")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local SensorCore = require("../src/Shared/Perception/SensorCore")
local Sensor = require("../src/Shared/Perception/Sensor")
local Species = require("../src/Shared/Data/Species")

local Contact = ObservationMemory.Contact

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function eq(got: any, want: any, what: string)
	check(got == want, `{what} (got {tostring(got)}, wanted {tostring(want)})`)
end
local function near(got: number, want: number, eps: number, what: string)
	check(math.abs(got - want) <= eps, `{what} (got {got}, wanted {want})`)
end
local function vnear(a: Vector3, b: Vector3, eps: number, what: string)
	check((a - b).Magnitude <= eps, `{what} (off by {(a - b).Magnitude})`)
end
local function listEq(a: { string }, b: { string }, what: string)
	eq(table.concat(a, "\n"), table.concat(b, "\n"), what)
end
-- A fixture that raises an error counts as one failure and the rest go on.
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end

-- =============================================================================================== the rig (sensor_rig_case.gd)

local HZ = 60
local DT = 1 / HZ
local FAR_Z, BALL_RADIUS = -8.0, 0.25
local SCREEN_AT, SCREEN_SIZE = Vector3.new(0, 0, -4), Vector3.new(1, 4, 0.1)
local FORWARD, UP = Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)

local folder: any = nil
local params: any = nil
local cast: any = nil
local memory: any = nil
local sensor: any = nil
local ended: { string } = {}
local balls: { any } = {}
local observer: any = { eye = Vector3.zero, gaze = FORWARD, up = UP, heading = FORWARD }

-- Builds the rig: the eye (at `eye`, looking along `gaze`; the origin and -Z unless given), the sensor and the memory with the shipped species
-- numbers. Whatever an earlier rig left in the world goes first. Walls are added separately. The rays meet only the rig's own walls.
local function rig(eye: Vector3?, gaze: Vector3?)
	if folder ~= nil then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "SensorRig"
	folder.Parent = workspace
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	cast = Sensor.workspaceCast(params)
	memory = ObservationMemory.new()
	ended = {}
	memory.contactEnded:connect(function(c: any, why: string)
		table.insert(ended, `{c.trackId}:{why}`)
	end)
	sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	balls = {}
	observer = { eye = eye or Vector3.zero, gaze = gaze or FORWARD, up = UP, heading = gaze or FORWARD }
end

-- A wall of `size` centred at `centre`, in what the rays can meet. `on` false leaves it out of the world for now.
local function addWall(centre: Vector3, size: Vector3, on: boolean?): any
	local p = Instance.new("Part")
	p.Name = "Wall"
	p.Size = size
	p.Position = centre
	p.Anchored = true
	p.CanQuery = on ~= false
	p.Parent = folder
	return p
end
local function setWall(wall: any, on: boolean)
	wall.CanQuery = on
end

-- A thing the sensor can sense: a ball of `radius` at `at` that moves at `velocity` (the rig moves it, one tick at a time).
local function addBall(id: string, at: Vector3, radius: number?): any
	local b = { id = id, position = at, radius = radius or BALL_RADIUS, velocity = Vector3.zero, maxCategory = Observation.FLY_LIKE_PREY, enabled = true }
	table.insert(balls, b)
	return b
end
local function removeBall(ball: any)
	table.remove(balls, table.find(balls, ball))
end

local function perceptsNow(): { any }
	local out = {}
	for _, b in balls do
		if b.enabled then
			table.insert(out, { id = b.id, position = b.position, radius = b.radius, velocity = b.velocity, maxCategory = b.maxCategory })
		end
	end
	return out
end

-- Runs `count` ticks, moving each ball by its velocity before the sensor reads it (Godot's run()). Standing still is a velocity of zero.
local function run(count: number)
	for _ = 1, count do
		for _, b in balls do
			if b.enabled then
				b.position += b.velocity / HZ
			end
		end
		sensor:step(DT, observer, perceptsNow(), cast)
	end
end

-- The first thing of the world between two points, nil when there is nothing.
local function firstHit(from: Vector3, to: Vector3): Vector3?
	local r = workspace:Raycast(from, to - from, params)
	return if r ~= nil then r.Position else nil
end

-- The contact the sensor last filed a ball under, nil when it has none.
local function contactOfBall(ball: any): any
	local id: string = sensor:trackIdFor(ball.id)
	return if id == "" then nil else memory:getContact(id)
end
local function visiblePoints(id: string): number
	local c = sensor:lastCheck(id)
	return if c == nil or c.visiblePoints == nil then -1 else c.visiblePoints
end
local function isLive(c: any): boolean
	return Contact.isLive(c)
end
local function hasMark(c: any): boolean
	return Contact.hasMark(c)
end
local function inspectedNow(c: any): boolean
	return c ~= nil and Contact.isInspectedNow(c)
end

-- What a player could be shown of the memory: every contact's category, state, place and bearing, without any id of the world.
local function digest(): { string }
	local out: { string } = {}
	for _, c in memory:contacts() do
		local p, q = c.position, c.cueDirection
		table.insert(out, string.format("%s %s %s %s conf=%.9f pos=%s %.9f,%.9f,%.9f obs=%.0f ptick=%.0f lost=%.0f first=%.0f reacq=%.0f cues=%.0f cue=%.9f,%.9f,%.9f size=%.9f speed=%.9f",
			c.trackId, c.state, c.modality, c.category, c.confidence, tostring(c.hasPosition), p.X, p.Y, p.Z, c.observedTick, c.positionTick, c.lostTick,
			c.firstTick, c.reacquisitions, c.cueCount, q.X, q.Y, q.Z, c.sizeWu, c.speedWuS))
	end
	return out
end

-- =============================================================================================== A-024: line of sight against small things

local BARRIER_AT, BARRIER_SIZE = Vector3.new(0, 0, -0.97), Vector3.new(0.2, 0.2, 0.02)
local SPECK_AT, SPECK_RADIUS = Vector3.new(0, 0, -1), 0.01

case("occlusion: a speck wholly behind a thin barrier is not sensed", function()
	rig()
	addWall(BARRIER_AT, BARRIER_SIZE)
	local speck = addBall("speck", SPECK_AT, SPECK_RADIUS)
	run(3)
	local hit = firstHit(Vector3.zero, SPECK_AT)
	if check(hit ~= nil, "the barrier is in the world") and hit ~= nil then
		near(hit.Magnitude, 0.96, 1e-3, "the ray to the speck meets the barrier 0.96 WU out, 0.04 WU short of the speck")
	end
	local gap = SPECK_AT.Magnitude - 0.96
	check(gap > 3.0 * PerceptionMath.sightTolerance(SPECK_RADIUS, 1.0), `that is {gap} WU short, far more than the allowance`)
	run(60)
	eq(memory:count(), 0, "a full second on: the speck was not sensed (it was, with 5 visible points, before the fix)")
	eq(sensor.core.inspectionsMade, 0, "not inspected")
	eq(sensor.core.cuesMade, 0, "and no cue")
	eq(visiblePoints("speck"), 0, "none of its five sample points was seen")
	vnear(speck.position, SPECK_AT, 1e-9, "it stood where the arrangement put it")
end)

case("occlusion: the same speck with the barrier taken away is sensed and refined", function()
	rig()
	local wall = addWall(BARRIER_AT, BARRIER_SIZE, true)
	local speck = addBall("speck", SPECK_AT, SPECK_RADIUS)
	run(30)
	eq(memory:count(), 0, "hidden while the barrier stands")
	setWall(wall, false)
	run(100)
	local c = contactOfBall(speck)
	if not check(inspectedNow(c), "with the barrier gone it is inspected") then
		return
	end
	eq(visiblePoints("speck"), 5, "all five sample points are in view")
	vnear(c.position, SPECK_AT, 0.02, "at the place it stands")
	eq(c.category, Observation.POSSIBLE_PREY, "after 1.6 s it is refined to possible prey (a speck needs 2.6 times as long as an easy target)")
	run(110)
	eq(c.category, Observation.FLY_LIKE_PREY, "and after 3.4 s to fly-like prey, as before the fix")
end)

case("occlusion: a speck partly in view is sensed from the points that are", function()
	rig()
	-- The barrier ends at x = 0.004: the sample on the +x side of the speck (x = 0.008) is in view past its edge, the other four are behind it.
	addWall(Vector3.new(-0.098, 0, -0.97), Vector3.new(0.204, 0.2, 0.02))
	local speck = addBall("speck", SPECK_AT, SPECK_RADIUS)
	run(40)
	eq(visiblePoints("speck"), 1, "one of the five sample points is in view")
	local c = contactOfBall(speck)
	if not check(inspectedNow(c), "so it is inspected, from what can be seen") then
		return
	end
	check((c.position - SPECK_AT).Magnitude <= 0.01, `its place is the visible point's, within the speck: {(c.position - SPECK_AT).Magnitude} WU off`)
	check(c.confidence < 0.5, `with less confidence than a full view ({c.confidence})`)
end)

case("occlusion: what is hidden does not flicker at the edge of a barrier", function()
	-- Slide a speck's whole body behind the barrier's edge, a hair at a time: the number of visible points never rises as it goes in.
	rig()
	addWall(Vector3.new(-0.098, 0, -0.97), Vector3.new(0.204, 0.2, 0.02))
	local speck = addBall("speck", Vector3.new(0.05, 0, -1), SPECK_RADIUS)
	local last, rose = 99, 0
	for step = 0, 23 do
		speck.position = Vector3.new(0.05 - 0.0025 * step, 0, -1)
		run(2)
		local now = visiblePoints("speck")
		if now > last then
			rose += 1
		end
		last = now
	end
	eq(rose, 0, "going behind the barrier the visible points only fall")
	eq(last, 0, `and at the end none of them is seen (x = {speck.position.X})`)
end)

case("occlusion: a speck wholly behind a barrier is hidden whatever its size", function()
	-- The sphere stands just behind a barrier 0.02 thick, at every size from a speck to a ball 0.4 WU across: none of it is in view.
	for _, radius in { 0.005, 0.01, 0.02, 0.03, 0.05, 0.1, 0.2 } do
		rig()
		addWall(Vector3.new(0, 0, -0.97), Vector3.new(1, 1, 0.02))
		local ball = addBall("ball", Vector3.new(0, 0, -0.98 - radius - 0.001), radius)
		run(20)
		eq(visiblePoints("ball"), 0, `radius {radius}: none of its points is in view`)
		eq(memory:count(), 0, `radius {radius}: nothing was sensed`)
		check(contactOfBall(ball) == nil, `radius {radius}: it has no contact`)
	end
end)

case("occlusion: a thing resting in a surface keeps the points in the surface's skin", function()
	-- An ordinary thing (the 0.9 WU test marker) resting against a wall: its sample points lie a little inside the wall's face. Up to a
	-- tenth of its radius in, they still count as seen, as before; further in, they are behind the wall.
	rig()
	addWall(Vector3.new(0, 0, -2.05), Vector3.new(6, 6, 0.1)) -- front face at z = -2.0
	local ball = addBall("marker", Vector3.new(0, 0, -2.0), 0.45)
	for _, inside in { 0.0, 0.01, 0.03, 0.04 } do
		ball.position = Vector3.new(0, 0, -2.0 - inside)
		run(6)
		eq(visiblePoints("marker"), 5, `{inside} WU inside the face: all five points are seen`)
	end
	for _, inside in { 0.06, 0.08, 0.2 } do
		ball.position = Vector3.new(0, 0, -2.0 - inside)
		run(6)
		eq(visiblePoints("marker"), 0, `{inside} WU inside the face: none is seen`)
	end
end)

case("occlusion: a thing resting in a surface is not lost and found again by chance", function()
	rig()
	addWall(Vector3.new(0, 0, -2.05), Vector3.new(6, 6, 0.1))
	local ball = addBall("marker", Vector3.new(0, 0, -2.03), 0.45)
	local lost = 0
	memory.contactLost:connect(function()
		lost += 1
	end)
	run(180)
	local c = contactOfBall(ball)
	check(inspectedNow(c), "it is inspected the whole time")
	eq(lost, 0, "and never lost: the same arrangement gives the same answer every tick")
	eq(memory:count(), 1, "one contact")
	eq(c.category, Observation.FLY_LIKE_PREY, "which has been refined as an open one would be")
end)

case("occlusion: a spot behind the barrier is not called empty", function()
	-- A speck is seen and classified, the barrier goes up in front of it, and the speck goes away. Looking at a barrier does not show that
	-- the place behind it is empty: the mark stays until the memory lets go of it (6 s), as it would for any hidden place.
	rig()
	local wall = addWall(BARRIER_AT, BARRIER_SIZE, false)
	local speck = addBall("speck", SPECK_AT, SPECK_RADIUS)
	run(200)
	local c = contactOfBall(speck)
	if not check(c ~= nil and c.category == Observation.FLY_LIKE_PREY, "the speck was refined to fly-like prey in plain view") then
		return
	end
	setWall(wall, true)
	run(20)
	check(not isLive(c) and hasMark(c), "behind the barrier it is lost, with a mark")
	speck.enabled = false
	run(240)
	check(hasMark(c), "four seconds on, the place behind the barrier has not been called empty")
	eq(#ended, 0, "nothing ended the contact")
	run(180)
	listEq(ended, { `{c.trackId}:expired` }, "it went when the memory did: expired, not empty")
end)

case("occlusion: the same spot in plain view is called empty", function()
	-- The control of the test above: with no barrier, looking at the spot for the time an easy target needs shows that nothing is there.
	rig()
	local speck = addBall("speck", SPECK_AT, SPECK_RADIUS)
	run(200)
	local c = contactOfBall(speck)
	if not check(c ~= nil and c.category == Observation.FLY_LIKE_PREY, "the speck was refined to fly-like prey in plain view") then
		return
	end
	speck.enabled = false
	run(20)
	check(hasMark(c), "taken away, it is lost with a mark")
	run(60)
	eq(#memory:marks(), 0, "after looking at the empty spot, the mark is gone")
	listEq(ended, { `{c.trackId}:empty` }, "because the spot was empty")
end)

-- =============================================================================================== A-027: who is who (test_sensor_association.gd)
-- Balls of 0.25 WU radius 8 WU out, a narrow screen between, the species numbers as shipped (speed bound 2 WU/s, size ratio 1.5). A ball walks
-- at 0.8 WU/s, the pace of the test marker.

local WALK = 0.8

-- A wall that hides the far line around x (the shadow of a wall 4 WU out is twice its own span).
local function coverFor(x: number, on: boolean?): any
	return addWall(Vector3.new(x * 0.5, 0, -4.0), Vector3.new(1.0, 4.0, 0.1), on)
end

-- A ball standing at x on the far line, watched until it is refined to fly-like prey.
local function classified(id: string, x: number): any
	local b = addBall(id, Vector3.new(x, 0, FAR_Z))
	run(90)
	local c = contactOfBall(b)
	check(inspectedNow(c) and c.category == Observation.FLY_LIKE_PREY, `{id} is in view and refined to fly-like prey`)
	return b
end

-- Two look-alikes cross behind the screen from opposite sides, and are frozen as they come out into view on the far sides (tick 210). With
-- `swap` the fixture exchanges their world ids at tick 110, when both are hidden and have been lost. Returns what the memory holds then, as a
-- player could be shown it, and where the two stand.
local function bothCrossing(swap: boolean): { digest: { string }, ax: number, bx: number, swapped: boolean }
	rig()
	addWall(SCREEN_AT, SCREEN_SIZE)
	local a = classified("a", -1.8)
	local b = classified("b", 1.8)
	a.velocity = Vector3.new(WALK, 0, 0)
	b.velocity = Vector3.new(-WALK, 0, 0)
	run(110) -- both are behind the screen (hidden from tick 74) and were lost at tick 84
	local swapped = false
	if swap then
		local hiddenA, hiddenB = contactOfBall(a), contactOfBall(b)
		if check(hiddenA ~= nil and hiddenB ~= nil and not isLive(hiddenA) and not isLive(hiddenB), "both are lost behind the screen") then
			a.id, b.id = b.id, a.id
			swapped = true
		end
	end
	run(100) -- they come out on the far sides from tick 196
	a.velocity = Vector3.zero
	b.velocity = Vector3.zero
	run(1)
	return { digest = digest(), ax = a.position.X, bx = b.position.X, swapped = swapped }
end

case("association: two look-alikes cross behind cover and come out as new contacts", function()
	local r = bothCrossing(false)
	check(r.ax >= 0.95 and r.bx <= -0.95, `they have crossed and come out: a at {r.ax}, b at {r.bx}`)
	local live, marks = memory:liveContacts(), memory:marks()
	eq(#live, 2, "two live contacts, one for each thing in view")
	eq(#marks, 2, "and the two places they were last seen are still remembered")
	for _, c in live do
		eq(c.reacquisitions, 0, `{c.trackId}: nothing was reacquired: each thing could have been either, so neither is taken for either`)
		check(c.firstTick > 150, `{c.trackId}: it began when it came out (tick {c.firstTick}), not when its namesake was first seen`)
		check(Observation.rank(c.category) < Observation.rank(Observation.FLY_LIKE_PREY), `{c.trackId}: it is {c.category}, not fly-like prey: it has only just come out`)
	end
	for _, m in marks do
		check(not isLive(m) and hasMark(m), `{m.trackId}: still a mark, left where it was`)
		eq(m.category, Observation.FLY_LIKE_PREY, `{m.trackId}: what was learned stayed with the place`)
	end
	run(90)
	for _, c in memory:liveContacts() do
		eq(c.category, Observation.FLY_LIKE_PREY, `{c.trackId}: given time it is refined again, from nothing`)
	end
end)

case("association: swapping only the hidden world ids changes nothing the player could see", function()
	local plain = bothCrossing(false)
	local swapped = bothCrossing(true)
	check(swapped.swapped, "the ids were exchanged while both things were out of sight")
	near(swapped.ax, plain.ax, 1e-9, "with the very same evidence in front of the spider")
	eq(#swapped.digest, #plain.digest, "the same number of contacts")
	listEq(swapped.digest, plain.digest, "and the very same contacts: where, when, what and how sure, whatever the world called the things")
end)

case("association: a thing seen again where only it could be is the one remembered", function()
	rig()
	addWall(SCREEN_AT, SCREEN_SIZE)
	local a = classified("a", -1.8)
	local c = contactOfBall(a)
	local track = c.trackId
	a.velocity = Vector3.new(WALK, 0, 0)
	run(95) -- behind the screen from tick 74, lost at 84
	check(not isLive(c) and hasMark(c), "it was lost behind the screen, with a mark")
	local mark, markTick = c.position, c.positionTick
	run(110) -- and out on the far side from tick 196, 2 seconds after it was last seen
	check(a.position.X > 0.85, `it is out on the far side (x = {a.position.X})`)
	check(isLive(c) and c.reacquisitions == 1, "the one remembered place it could be is the contact: reacquired once")
	eq(memory:count(), 1, "and there is no other")
	check((c.position - mark).Magnitude > 1.5 and c.positionTick > markTick, `its place was updated by what was seen, {(c.position - mark).Magnitude} WU from the mark`)
	eq(c.category, Observation.FLY_LIKE_PREY, "and it is still known for what it was")
	eq(contactOfBall(a).trackId, track, "the same contact")
	eq(c.targetId, "a", "the live link to the world is made again, for interaction")
end)

case("association: the name does not make a distant thing the remembered one", function()
	rig()
	local cover = coverFor(-1.9, false)
	local a = classified("a", -1.9)
	local old = contactOfBall(a)
	local mark = old.position
	setWall(cover, true)
	run(18) -- hidden for 0.3 s; the memory lost it at tick 10
	check(hasMark(old), "it is lost, with a mark")
	a.position = Vector3.new(1.9, 0, FAR_Z) -- the same thing, with the same name, is 3.8 WU away when it is next in view
	run(8)
	local now = contactOfBall(a)
	check(now ~= nil and now ~= old and inspectedNow(now), "it is a new contact: nothing seen to move that fast could have come so far in 0.3 s")
	eq(now.reacquisitions, 0, "not a reacquisition")
	eq(now.category, Observation.MOVEMENT, "and it starts again at movement")
	check(hasMark(old) and old.position == mark, "the old mark is untouched, still where it was seen")
	eq(memory:count(), 2, "two contacts")
	run(80)
	eq(now.category, Observation.FLY_LIKE_PREY, "which is refined, from nothing, in the time it takes")
end)

case("association: the region a lost thing could have reached grows with the time", function()
	-- The same far sighting, 3.8 WU from the mark, is a stranger after 0.3 s and the remembered thing after 2.7 s (the speed bound is
	-- 2 WU/s): the region depends on the time and the bound, not on where the thing went.
	rig()
	local cover = coverFor(-1.9)
	setWall(cover, false)
	local a = classified("a", -1.9)
	local c = contactOfBall(a)
	setWall(cover, true)
	run(160) -- hidden for 2.7 s, lost at tick 10 and remembered
	check(not isLive(c) and hasMark(c), "it is lost behind the cover and remembered")
	a.position = Vector3.new(1.9, 0, FAR_Z) -- while it was hidden, wherever it went: this is the first anyone sees of it
	run(8)
	check(isLive(c) and c.reacquisitions == 1 and memory:count() == 1, "after 2.7 s a thing 3.8 WU away could be the one remembered, and it is the only one that could")
end)

case("association: the speed bound is the species number and not a guess in the code", function()
	-- The same two sightings with the bound turned down to a crawl: the thing 3.8 WU away after 2.7 s cannot be the remembered one.
	rig()
	local cover = coverFor(-1.9)
	setWall(cover, false)
	local a = classified("a", -1.9)
	local c = contactOfBall(a)
	near(sensor.core.contactSpeedBound, 2.0, 1e-9, "the bound is the species profile's")
	sensor.core.contactSpeedBound = 0.2
	setWall(cover, true)
	run(160)
	a.position = Vector3.new(1.9, 0, FAR_Z)
	run(8)
	local now = contactOfBall(a)
	check(now ~= nil and now ~= c and c.reacquisitions == 0, "with a bound of 0.2 WU/s it is a new contact")
	check(hasMark(c) and memory:count() == 2, "and the place it came from is still remembered")
end)

case("association: a thing that cannot look like what was learned is not the remembered one", function()
	rig()
	local cover = coverFor(-1.0, false)
	local a = classified("a", -1.0)
	local old = contactOfBall(a)
	setWall(cover, true)
	run(20)
	check(hasMark(old), "lost, with a mark")
	a.maxCategory = Observation.MOVEMENT -- the same place and size, but something that never looks like prey
	setWall(cover, false)
	run(20)
	local now = contactOfBall(a)
	check(now ~= nil and now ~= old, "a new contact: what was learned about the old one cannot be true of a thing that is only ever movement")
	eq(now.reacquisitions, 0, "not a reacquisition")
	check(hasMark(old), "and the old mark stays")
end)

case("association: a thing of another size is not the remembered one", function()
	rig()
	local cover = coverFor(-1.0, false)
	local a = classified("a", -1.0)
	local old = contactOfBall(a)
	setWall(cover, true)
	run(20)
	check(hasMark(old), "lost, with a mark")
	a.radius = 0.5 -- twice as big
	setWall(cover, false)
	run(20)
	local now = contactOfBall(a)
	check(now ~= nil and now ~= old, "a new contact: twice the size is not the same thing")
	check(hasMark(old) and old.reacquisitions == 0, "and the old mark stays")
end)

case("association: a brief gap keeps the contact and a long one does not", function()
	rig()
	local cover = coverFor(-1.0, false)
	local a = classified("a", -1.0)
	local c = contactOfBall(a)
	local track = c.trackId
	local lost = 0
	memory.contactLost:connect(function()
		lost += 1
	end)
	setWall(cover, true)
	run(6) -- hidden for 0.1 s, inside the 0.15 s the memory holds an inspection for
	setWall(cover, false)
	run(10)
	check(contactOfBall(a) == c and c.trackId == track and isLive(c), "after a gap of 6 ticks it is the same contact, still live")
	eq(lost, 0, "which was never lost")
	eq(c.reacquisitions, 0, "and not reacquired")
	eq(c.category, Observation.FLY_LIKE_PREY, "it is still known for what it was")
	setWall(cover, true)
	run(14) -- 0.23 s: past the hold
	setWall(cover, false)
	run(10)
	eq(lost, 1, "a longer gap loses it")
	check(isLive(c) and c.reacquisitions == 1 and memory:count() == 1, "and it is found again by the evidence (the one place it could be): reacquired once")
end)

case("association: a loss of sight never updates the remembered place", function()
	rig()
	addWall(SCREEN_AT, SCREEN_SIZE)
	local a = classified("a", -1.8)
	local c = contactOfBall(a)
	a.velocity = Vector3.new(WALK, 0, 0)
	run(95)
	check(not isLive(c) and hasMark(c), "behind the screen it is lost")
	local place, tick, speed, cat = c.position, c.positionTick, c.speedWuS, c.category
	run(30)
	a.id = "someone_else" -- and the world gives it another name while it is hidden
	run(30)
	check(a.position.X > -0.8 and a.position.X < 0.8, `it is still behind the screen (x = {a.position.X}), going on`)
	check(c.position == place and c.positionTick == tick and c.speedWuS == speed, "the remembered place is exactly where it was seen, with the tick and the speed it was seen at")
	eq(c.category, cat, "and the category is what it was")
	eq(c.targetId, "", "the contact holds no link to the world: there is nothing for the world to update")
	eq(c.reacquisitions, 0, "and it has not been reacquired")
end)

case("association: the live link to the world ends with the sight", function()
	rig()
	local a = classified("a", -1.0)
	local c = contactOfBall(a)
	eq(c.targetId, "a", "while it is in view and refined, the contact is linked to the world's id for it, for interaction")
	a.enabled = false
	run(20)
	check(not isLive(c), "lost")
	eq(c.targetId, "", "the link is gone with the sight")
end)

case("association: a mark is dropped when its place is seen empty and a hidden one is not", function()
	rig()
	local a = classified("a", -1.8) -- in plain view
	local c = contactOfBall(a)
	a.enabled = false
	run(120)
	eq(#memory:marks(), 0, "the place in plain view was seen empty for long enough: dropped")
	listEq(ended, { `{c.trackId}:empty` }, "because it was empty")
	-- The same, behind a cover: nothing can be said about a place that is hidden.
	local cover = coverFor(-1.8, false)
	local b = addBall("b", Vector3.new(-1.8, 0, FAR_Z))
	run(90)
	local d = contactOfBall(b)
	check(d ~= nil and d.category == Observation.FLY_LIKE_PREY, "another is refined in plain view")
	setWall(cover, true)
	run(20)
	check(not isLive(d) and hasMark(d), "behind the cover it is lost, with a mark")
	b.enabled = false
	run(150)
	check(hasMark(d), "two and a half seconds of looking at the cover: the place behind it is not called empty")
end)

case("association: a thing gone from the world is forgotten by the sensor but its mark expires on its own", function()
	rig()
	local cover = coverFor(-1.8, false)
	local a = classified("a", -1.8)
	local c = contactOfBall(a)
	check(sensor:getTrack("a") ~= nil, "the sensor keeps a track of the thing while it is there")
	setWall(cover, true)
	run(20)
	check(not isLive(c) and hasMark(c), "it is hidden and lost, with a mark")
	removeBall(a)
	run(2)
	check(sensor:getTrack("a") == nil and next(sensor.core._tracks) == nil, "the thing left the world: the sensor's track of it is gone (A-029)")
	check(sensor:lastCheck("a") == nil, "and so is what its last check found")
	check(hasMark(c) and memory:count() == 1, "the mark is not touched by that")
	run(300)
	check(hasMark(c), "it is still there after five seconds: it fades on the memory's clock, not the world's")
	run(80)
	listEq(ended, { `{c.trackId}:expired` }, "and expires when the memory lets go of it, after 6 s")
	local again = addBall("a", Vector3.new(-1.8, 0, FAR_Z)) -- a new thing that happens to have the old name
	setWall(cover, false)
	run(10)
	local fresh = contactOfBall(again)
	check(fresh ~= nil and fresh.firstTick > c.lostTick and fresh.category == Observation.MOVEMENT, "is a stranger: nothing of the old track is left to be carried over")
end)

case("association: a thing seen only in the periphery never joins a lost contact", function()
	-- A thing moving in the periphery is only a bearing. It never takes back a lost contact, whatever its name was.
	rig()
	local cover = coverFor(-1.8, false)
	local a = classified("a", -1.8)
	local old = contactOfBall(a)
	setWall(cover, true)
	run(20)
	check(not isLive(old) and hasMark(old), "hidden and lost, with a mark")
	local cues = old.cueCount
	a.position = Vector3.new(5, 0, -2) -- far outside the cone, in the periphery, and walking
	a.velocity = Vector3.new(0, 0, 1)
	run(70)
	local cued = contactOfBall(a)
	check(cued ~= nil and cued ~= old, "its movement made a contact of its own")
	check(not cued.hasPosition and cued.cueCount >= 1, "known from a bearing only")
	eq(old.cueCount, cues, "the lost contact received none of the cues")
	check(hasMark(old) and old.reacquisitions == 0, "and was not reacquired")
end)

-- ---------------------------------------------------------------- several sightings in one tick (chunk 7B, two flies)

-- What a player could be shown of the contacts, sorted by place, without the sensor's serial ids: the order the world lists things in shows
-- nowhere in it.
local function byPlace(): { string }
	local rows: { { x: number, text: string } } = {}
	for _, c in memory:contacts() do
		local x = math.floor(c.position.X / 0.001 + 0.5) * 0.001
		table.insert(rows, { x = x, text = string.format("%.3f %s %s %d %.0f", x, c.state, c.category, c.reacquisitions, c.firstTick) })
	end
	table.sort(rows, function(p, q)
		return p.x < q.x
	end)
	local out: { string } = {}
	for _, r in rows do
		table.insert(out, r.text)
	end
	return out
end

-- One remembered place, two look-alikes that come into view at once and either of which could be the thing: `first` is the one the world
-- lists first.
local function twoCouldBeIt(first: string): { string }
	rig()
	local cover = coverFor(-1.8, false)
	local a = classified("a", -1.8)
	local old = contactOfBall(a)
	setWall(cover, true)
	run(20)
	check(not isLive(old) and hasMark(old), "the thing is lost behind the cover, with a mark")
	a.enabled = false
	local where = { p = -1.4, q = -2.0 }
	local order = if first == "p" then { "p", "q" } else { "q", "p" }
	local made: { [string]: any } = {}
	for _, id in order do
		made[id] = addBall(id, Vector3.new(where[id], 0, FAR_Z))
	end
	setWall(cover, false)
	run(8)
	local p, q = contactOfBall(made.p), contactOfBall(made.q)
	check(p ~= nil and q ~= nil and p ~= q, "each look-alike is a contact")
	check(p ~= old and q ~= old, "and neither is the remembered one: either could have been it, so neither is taken for it")
	eq(p.reacquisitions + q.reacquisitions + old.reacquisitions, 0, "nothing was reacquired")
	check(hasMark(old), "the remembered place stays, left where it was seen")
	return byPlace()
end

case("association: two look-alikes that come into view together are strangers whatever order they are listed in", function()
	local pq = twoCouldBeIt("p")
	local qp = twoCouldBeIt("q")
	eq(#pq, 3, "three contacts: the old place and the two newcomers")
	listEq(qp, pq, "the very same contacts whichever of them the sensor handles first")
end)

case("association: a thing that fits one place alone still takes it while a stranger is in view", function()
	rig()
	local cover = coverFor(-1.8, false)
	local a = classified("a", -1.8)
	local old = contactOfBall(a)
	setWall(cover, true)
	run(20)
	a.enabled = false
	local nearBall = addBall("p", Vector3.new(-1.5, 0, FAR_Z))
	local farBall = addBall("q", Vector3.new(1.9, 0, FAR_Z)) -- 3.7 WU from the mark: farther than anything unseen for 0.3 s could have come
	setWall(cover, false)
	run(8)
	check(isLive(old) and old.reacquisitions == 1, "the one that could only be the remembered thing is it")
	check(contactOfBall(nearBall) == old, "filed under the old contact")
	local stranger = contactOfBall(farBall)
	check(stranger ~= nil and stranger ~= old and stranger.reacquisitions == 0, "the other, nowhere near, is a new contact")
end)

-- Two remembered places; one newcomer that fits only the first and one that fits both.
local function asymmetric(first: string): { string }
	rig()
	local coverA = coverFor(-1.8, false)
	local coverB = coverFor(1.8, false)
	local a = classified("a", -1.8)
	local b = classified("b", 1.8)
	setWall(coverA, true)
	setWall(coverB, true)
	run(44) -- about 0.75 s since either was last observed: the region each could have reached is about 2 WU wide
	check(#memory:marks() == 2, "both are lost, with marks")
	a.enabled = false
	b.enabled = false
	local where = { p = -1.6, q = 0.0 }
	local order = if first == "p" then { "p", "q" } else { "q", "p" }
	for _, id in order do
		addBall(id, Vector3.new(where[id], 0, FAR_Z))
	end
	setWall(coverA, false)
	setWall(coverB, false)
	run(6)
	local live = memory:liveContacts()
	eq(#live, 2, "two newcomers are in view")
	for _, c in live do
		eq(c.reacquisitions, 0, "nothing was reacquired: the one near the first place could be it, but so could the one between the two, and a place cannot be both")
	end
	eq(#memory:marks(), 2, "and both remembered places are still there")
	return byPlace()
end

case("association: a place two newcomers could each be is taken by neither in whatever order", function()
	local pq = asymmetric("p")
	local qp = asymmetric("q")
	listEq(qp, pq, "the same contacts whichever is handled first")
end)

-- =============================================================================================== the stage (test_sensor.gd, test_t13a_motion_surround.gd)
-- The lab's perception stage as boxes (traversal_lab.gd, A-010): the ledge to watch from and the screen in front of the marker's path. The
-- spider on the middle of the ledge looks from LEDGE_EYE; the places are all on the path (z = -7.9, y = 1.4). The marker is a ball of 0.45.

local LEDGE_LO, LEDGE_HI = Vector3.new(-26.5, 0.0, -4.2), Vector3.new(-22.5, 2.0, -1.2)
local SCREEN_LO, SCREEN_HI = Vector3.new(-25.6, 0.0, -6.3), Vector3.new(-23.4, 3.0, -5.8)
local LEDGE_EYE = Vector3.new(-24.5, 2.39, -2.88)
local WEST_VISIBLE = Vector3.new(-28.0, 1.4, -7.9)
local BEHIND_SCREEN = Vector3.new(-24.5, 1.4, -7.9)
-- A place the spider cannot sense at all while it faces north: behind it, in the 60 degree wedge the field leaves out.
local BEHIND_SPIDER = Vector3.new(-24.5, 1.4, 6.0)
local MARKER_RADIUS = 0.45
local MARKER_ID = "test_target"

local function stageRig(gaze: Vector3?)
	rig(LEDGE_EYE, gaze)
	addWall((LEDGE_LO + LEDGE_HI) / 2, LEDGE_HI - LEDGE_LO)
	addWall((SCREEN_LO + SCREEN_HI) / 2, SCREEN_HI - SCREEN_LO)
end
-- The horizontal gaze that makes the spider on the ledge face a point (Godot: heading_toward).
local function headingToward(p: Vector3): Vector3
	local d = p - LEDGE_EYE
	return Vector3.new(d.X, 0, d.Z).Unit
end
local function marker(at: Vector3, radius: number?): any
	return addBall(MARKER_ID, at, radius or MARKER_RADIUS)
end
-- Runs until the condition holds, at most `limit` ticks (Godot: wait_until).
local function runUntil(cond: () -> boolean, limit: number)
	for _ = 1, limit do
		if cond() then
			return
		end
		run(1)
	end
end
local function angleDeg(a: Vector3, b: Vector3): number
	return math.deg(PerceptionMath.angleTo(a, b))
end
-- True when the world stands between the eye and every one of the ball's sample points (it is hidden), by the test's own count of the points
-- (Godot: target_is_hidden): the allowance is the sensor's, so this agrees with what the sensor can see.
local function isHidden(ball: any): boolean
	local c, eye = ball.position, observer.eye
	local r = ball.radius * 0.8
	local d = (c - eye).Unit
	local side = d:Cross(UP).Unit
	for _, p in { c, c + side * r, c - side * r, c + UP * r, c - UP * r } do
		local hit = firstHit(eye, p)
		local length = (p - eye).Magnitude
		if hit == nil or (hit - eye).Magnitude >= length - PerceptionMath.sightTolerance(ball.radius, length) then
			return false
		end
	end
	return true
end

case("stage: a moving thing in the periphery gives a coarse cue and nothing else", function()
	stageRig()
	local m = marker(WEST_VISIBLE)
	run(20)
	eq(memory:count(), 0, "a standing marker, in plain view, outside the cone: no motion, no cue")
	m.velocity = Vector3.new(0.8, 0, 0)
	run(40)
	local c = contactOfBall(m)
	if not check(c ~= nil, "the moving marker was noticed") then
		return
	end
	eq(c.modality, Observation.PERIPHERAL, "by the peripheral channel")
	eq(c.category, Observation.MOVEMENT, "as movement and nothing finer")
	check(not c.hasPosition and not hasMark(c), "with no position to point at")
	eq(c.targetId, "", "and no target resolved")
	check(c.confidence >= 0.1 and c.confidence <= 0.3, `a weak cue ({c.confidence})`)
	local err = angleDeg(c.cueDirection, (m.position - LEDGE_EYE).Unit)
	check(err > 0.5 and err < 30.0, `the bearing is a sector and a band, not the truth: it is {err} degrees off`)
	eq(sensor.core.inspectionsMade, 0, "nothing was inspected")
	local off = angleDeg(observer.gaze, (m.position - LEDGE_EYE).Unit)
	check(off > 15.0, `because it is outside the 30 degree cone ({off} degrees off)`)
end)

case("stage: cues come at most once per cooldown", function()
	stageRig()
	local m = marker(Vector3.new(-29.5, 1.4, -7.9))
	m.velocity = Vector3.new(0.8, 0, 0)
	local ticks: { number } = {}
	sensor.core.cueEmitted:connect(function(o: any)
		table.insert(ticks, o.observedTick)
	end)
	for _ = 1, 60 * 4 do -- to and fro along the path's first stretch, never pausing
		if m.position.X >= -27.6 then
			m.velocity = Vector3.new(-0.8, 0, 0)
		elseif m.position.X <= -29.5 then
			m.velocity = Vector3.new(0.8, 0, 0)
		end
		run(1)
	end
	check(#ticks >= 4 and #ticks <= 5, `about one cue every 0.8 s over 4 s of constant motion: {#ticks}`)
	for i = 2, #ticks do
		check(ticks[i] - ticks[i - 1] >= 48, `cues {i - 1} and {i} are {ticks[i] - ticks[i - 1]} ticks apart (cooldown 48)`)
	end
end)

case("stage: broad queries run at ten hertz and close things are checked every tick", function()
	stageRig()
	local m = marker(BEHIND_SCREEN)
	run(3)
	local scans0, checks0 = sensor.broadScans, sensor.checksTotal
	run(120)
	local scans, checks = sensor.broadScans - scans0, sensor.checksTotal - checks0
	check(scans >= 19 and scans <= 21, `10 broad scans a second: {scans} in 2 s`)
	check(checks >= 19 and checks <= 21, `a far marker that is not being tracked is looked at on those scans only: {checks} checks`)
	m.position = LEDGE_EYE + Vector3.new(0, -0.5, -3)
	local c1 = sensor.checksTotal
	run(120)
	check(sensor.checksTotal - c1 >= 118, `a marker within 4 WU is checked every tick: {sensor.checksTotal - c1} in 120`)
	check(sensor.maxRaysInATick <= 20, `the rays in one tick stay few ({sensor.maxRaysInATick})`)
end)

case("stage: the cone refines a category with continuous exposure", function()
	stageRig(headingToward(WEST_VISIBLE))
	local m = marker(WEST_VISIBLE)
	run(3)
	local below = angleDeg(observer.gaze, (WEST_VISIBLE - LEDGE_EYE).Unit)
	check(below < 15.0, `the marker is {below} degrees below the gaze, inside the half cone`)
	local first, possibleAt, flyAt = -1, -1.0, -1.0
	for _ = 1, 75 do
		run(1)
		local c = contactOfBall(m)
		if c ~= nil and c.modality == Observation.INSPECTION then
			if first < 0 then
				first = c.firstTick
			end
			local at = (sensor.core.tick - first + 1) / 60
			if possibleAt < 0 and c.category ~= Observation.MOVEMENT then
				possibleAt = at
			end
			if flyAt < 0 and c.category == Observation.FLY_LIKE_PREY then
				flyAt = at
			end
		end
	end
	check(first >= 0, "it was inspected")
	check(possibleAt >= 0.39 and possibleAt <= 0.45, `possible prey after 0.4 s of continuous exposure (at {possibleAt} s)`)
	check(flyAt >= 0.99 and flyAt <= 1.06, `fly-like prey after 1.0 s (at {flyAt} s)`)
	local c = contactOfBall(m)
	eq(c.targetId, MARKER_ID, "the target is resolved once it is possible prey")
	check(c.confidence > 0.9, `and the confidence is high ({c.confidence})`)
	check(c.hasPosition and (c.position - m.position).Magnitude < 0.5, `at about where it is ({(c.position - m.position).Magnitude} WU off)`)
end)

case("stage: a marker that never looks like prey is never refined", function()
	stageRig(headingToward(WEST_VISIBLE))
	local m = marker(WEST_VISIBLE)
	m.maxCategory = Observation.MOVEMENT
	run(90)
	local c = contactOfBall(m)
	check(inspectedNow(c), "inspected for 1.5 s")
	eq(c.category, Observation.MOVEMENT, "and still only movement")
	eq(c.targetId, "", "with no target resolved")
end)

case("stage: a marker that looks too small is not inspected", function()
	-- 6.2 WU away: a radius of 0.03 looks 0.55 degrees across (under the 0.6 minimum), 0.05 looks 0.92.
	stageRig(headingToward(WEST_VISIBLE))
	local m = marker(WEST_VISIBLE, 0.03)
	run(90)
	local check1 = sensor:lastCheck(MARKER_ID)
	check(check1 ~= nil and check1.apparentDeg ~= nil and check1.apparentDeg < 0.6, `it looks under 0.6 degrees across ({check1 and check1.apparentDeg})`)
	eq(sensor.core.inspectionsMade, 0, "so it is not inspected, however long it is in the cone")
	stageRig(headingToward(WEST_VISIBLE))
	m = marker(WEST_VISIBLE, 0.05)
	runUntil(function() return contactOfBall(m) ~= nil end, 30)
	local c = contactOfBall(m)
	check(inspectedNow(c), "at 0.92 degrees it can be inspected")
	runUntil(function() return sensor.core.tick - c.firstTick >= 60 end, 120)
	local check2 = sensor:lastCheck(MARKER_ID)
	check(check2 ~= nil and check2.apparentDeg ~= nil and check2.apparentDeg >= 0.6, "it looks 0.92 degrees across")
	eq(c.category, Observation.MOVEMENT, "a thing that small needs 3.3 times as long to refine (1.3 s): after 1.0 s it is still movement")
	runUntil(function() return sensor.core.tick - c.firstTick >= 80 end, 120)
	eq(c.category, Observation.POSSIBLE_PREY, "after 1.3 s it is possible prey")
end)

case("stage: the world hides what it stands in front of", function()
	stageRig()
	local m = marker(Vector3.new(-25.2, 1.4, -7.9))
	for _ = 1, 90 do -- to and fro behind the screen, never pausing
		if m.position.X >= -23.8 then
			m.velocity = Vector3.new(-0.8, 0, 0)
		elseif m.position.X <= -25.2 then
			m.velocity = Vector3.new(0.8, 0, 0)
		end
		run(1)
		if not isHidden(m) then
			check(false, `the screen hides the marker from the ledge (tick {sensor.core.tick}, at {m.position.X})`)
			break
		end
	end
	check(isHidden(m), "still hidden while it walks about behind the screen")
	eq(sensor.core.cuesMade, 0, "it moves behind cover: no cue")
	eq(sensor.core.inspectionsMade, 0, "and it is dead ahead, in the cone: no inspection either")
	eq(memory:count(), 0, "the memory holds nothing")
	eq(sensor:trackIdFor(MARKER_ID), "", "and the sensor never gave it a track")
	eq(visiblePoints(MARKER_ID), 0, "no sample point could be seen")
end)

case("stage: a thing that is never sensed leaves no trace anywhere", function()
	stageRig()
	local m = marker(BEHIND_SPIDER)
	m.velocity = Vector3.new(0.8, 0, 0)
	run(180)
	check(m.velocity.Magnitude > 0.5, "the marker is moving, behind the spider")
	eq(memory:count(), 0, "no contact")
	eq(sensor.core.cuesMade + sensor.core.inspectionsMade, 0, "no evidence was made")
	eq(sensor:trackIdFor(MARKER_ID), "", "no track id was ever given")
	check(sensor:lastCheck(MARKER_ID) ~= nil and sensor:lastCheck(MARKER_ID).visiblePoints == nil, "and no ray was spent on it")
end)

case("stage: the sensor takes its numbers from the species profile", function()
	stageRig()
	marker(BEHIND_SCREEN)
	run(3)
	local p = Species.phidippus_audax_prototype.perception
	local core = sensor.core
	near(core.coneDeg, p.inspect_cone_degrees, 1e-9, "cone")
	near(core.peripheralConeDeg, p.peripheral_cone_degrees, 1e-9, "peripheral field")
	near(core.easyS, p.easy_target_inspection_s, 1e-9, "easy exposure")
	near(core.cueCooldownS, p.cue_cooldown_s, 1e-9, "cue cooldown")
	near(core.broadHz, p.broad_query_hz, 1e-9, "broad rate")
	near(core.rangeWu, p.sensor_range_wu, 1e-9, "range")
	near(core.closeRangeWu, p.close_check_range_wu, 1e-9, "close range")
	near(memory.decayS, p.memory_decay_s, 1e-9, "memory decay")
	near(memory.holdInspectionS, p.exposure_grace_s, 1e-9, "inspection hold")
	near(memory.holdPeripheralS, p.cue_cooldown_s + 0.2, 1e-9, "cue hold")
end)

case("stage: the sensor's axis is the observer's gaze, whatever else moves", function()
	stageRig(headingToward(WEST_VISIBLE))
	marker(WEST_VISIBLE)
	for i = 1, 30 do
		run(1)
		vnear(sensor.lastAxis, observer.gaze, 1e-12, `the sensor's axis is the observer's gaze (tick {i})`)
		vnear(sensor.lastEye, LEDGE_EYE, 1e-12, `and its eye the observer's (tick {i})`)
	end
end)

-- ---------------------------------------------------------------- T13a: the lateral eyes' motion sense

case("motion: the lateral eyes register motion, not stillness", function()
	stageRig()
	local m = marker(WEST_VISIBLE)
	run(20)
	check(next(sensor.motionSeen) == nil, "a standing marker in plain view: nothing moves")
	m.velocity = Vector3.new(0.8, 0, 0)
	run(20)
	local e = sensor.motionSeen[MARKER_ID]
	if not check(e ~= nil, "the moving marker is registered as motion") then
		return
	end
	local truth = (m.position - LEDGE_EYE).Unit
	check(angleDeg(e.direction, truth) < 6.0, `where it was seen ({angleDeg(e.direction, truth)} degrees off)`)
	near(e.distance, (m.position - LEDGE_EYE).Magnitude, 0.6, "at about its distance")
	check(e.tick == sensor.core.tick and e.apparent > 0, "stamped with the tick it was seen on, with how big it looked")
	m.velocity = Vector3.zero
	run(Sensor.MOTION_HOLD_TICKS)
	check(sensor.motionSeen[MARKER_ID] ~= nil, "it stays for the hold after the thing stops")
	run(1)
	check(sensor.motionSeen[MARKER_ID] == nil, "and once the hold is over it fades from the record")
end)

case("motion: a hidden moving thing is not registered", function()
	stageRig()
	local m = marker(BEHIND_SCREEN + Vector3.new(-0.3, 0, 0))
	for _ = 1, 60 do
		if m.position.X >= BEHIND_SCREEN.X + 0.3 then
			m.velocity = Vector3.new(-0.8, 0, 0)
		elseif m.position.X <= BEHIND_SCREEN.X - 0.3 then
			m.velocity = Vector3.new(0.8, 0, 0)
		end
		run(1)
		if not isHidden(m) then
			check(false, "the marker stayed behind the screen")
			break
		end
	end
	check(next(sensor.motionSeen) == nil, "moving out of sight: no motion registered")
end)

case("motion: the record forgets a thing that left the world", function()
	stageRig()
	local m = marker(WEST_VISIBLE)
	m.velocity = Vector3.new(0.8, 0, 0)
	run(20)
	check(sensor.motionSeen[MARKER_ID] ~= nil, "it moves in sight")
	m.enabled = false
	run(1)
	check(sensor.motionSeen[MARKER_ID] == nil, "and is gone from the record the tick it leaves")
end)

-- =============================================================================================== the sensor's own bookkeeping and questions

case("sensor: the broad scan comes on tick 1 and then every sixth tick; close things and watched things are checked every tick", function()
	rig()
	-- Behind the observer (180 degrees off, outside the 300 degree field): never sensed, so never watched; far enough to be left to the scans.
	addBall("far", Vector3.new(0, 0, 20))
	for tick = 1, 37 do
		run(1)
		eq(sensor.core.tick, tick, "the tick counts up first")
		eq(sensor.checksThisTick, if (tick - 1) % 6 == 0 then 1 else 0, `tick {tick}: the far thing is checked on the broad scans only`)
	end
	eq(sensor.broadScans, 7, "ticks 1, 7, 13, 19, 25, 31 and 37")
	eq(sensor.checksTotal, 7, "one check each")
	local nearBall = addBall("near", Vector3.new(0, 0, 3.5)) -- within 4 WU of the eye
	for tick = 38, 49 do
		run(1)
		eq(sensor.checksThisTick, if (tick - 1) % 6 == 0 then 2 else 1, `tick {tick}: the near thing is checked every tick, the far one on the scans`)
	end
	nearBall.position = Vector3.new(0, 0, 4.5)
	run(1)
	eq(sensor.checksThisTick, 0, "beyond 4 WU it is left to the scans again (tick 50)")
end)

case("sensor: a thing with a mark is watched every tick wherever it is", function()
	rig()
	local cover = coverFor(-1.8, false)
	local a = classified("a", -1.8)
	setWall(cover, true)
	run(20)
	check(hasMark(contactOfBall(a)), "hidden and lost, with a mark")
	local checked = 0
	for _ = 1, 30 do
		run(1)
		checked += sensor.checksThisTick
	end
	eq(checked, 30, "8 WU out and not in the broad scan's tick: still checked every one of the 30 ticks")
end)

case("sensor: a disabled sensor does nothing and its tick stands still", function()
	rig()
	addBall("a", Vector3.new(0, 0, -8))
	run(10)
	local tick, rays, checks = sensor.core.tick, sensor.raysTotal, sensor.checksTotal
	sensor.enabled = false
	run(5)
	eq(sensor.core.tick, tick, "no tick passed")
	eq(sensor.raysThisTick + sensor.checksThisTick, 0, "nothing was checked this tick")
	eq(sensor.raysTotal, rays, "no ray was cast")
	eq(sensor.checksTotal, checks, "no check was made")
	sensor.enabled = true
	run(1)
	eq(sensor.core.tick, tick + 1, "and it goes on from where it stopped")
end)

case("sensor: reset forgets the tracks and starts the broad scan again but not the tick", function()
	rig()
	local m = addBall("a", Vector3.new(0, 0, -8))
	m.velocity = Vector3.new(0.5, 0, 0)
	run(3)
	check(sensor:getTrack("a") ~= nil and sensor:lastCheck("a") ~= nil and next(sensor.motionSeen) ~= nil, "a track, a last check and a motion record")
	sensor:reset()
	check(sensor:getTrack("a") == nil and sensor:lastCheck("a") == nil and next(sensor.motionSeen) == nil, "all of it is gone")
	eq(sensor:trackIdFor("a"), "", "and so is the id it was filed under")
	local scans = sensor.broadScans
	run(1)
	eq(sensor.core.tick, 4, "the tick goes on")
	eq(sensor.broadScans, scans + 1, "and the very next tick is a broad scan")
end)

case("sensor: the observer's id goes into every observation", function()
	rig()
	sensor = Sensor.new(memory, "second_spider")
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local b = addBall("a", Vector3.new(0, 0, -8))
	run(5)
	local c = contactOfBall(b)
	check(c ~= nil, "it was sensed")
	eq(c.observerId, "second_spider", "by the observer that was named")
	eq(sensor.memory, memory, "and the sensor's memory is the one it was given")
end)

case("sensor: a thing out of range, too close, or outside the field is only checked", function()
	rig()
	local far = addBall("far", Vector3.new(0, 0, -41))
	local close = addBall("close", Vector3.new(0, 0, -0.03))
	local edgeIn = addBall("edge_in", Vector3.new(math.sin(math.rad(149.5)) * 10, 0, math.cos(math.rad(149.5)) * -10))
	local edgeOut = addBall("edge_out", Vector3.new(math.sin(math.rad(150.5)) * 10, 0, math.cos(math.rad(150.5)) * -10))
	run(1)
	local f = sensor:lastCheck("far")
	check(f ~= nil and not f.inRange and near(f.distance, 41, 1e-9, "41 WU away") == nil and f.offAxisDeg == nil, "41 WU is beyond the 40 WU reach: no angle, no rays")
	local c = sensor:lastCheck("close")
	check(c ~= nil and c.inRange and c.offAxisDeg == nil, "0.03 WU is under the minimum distance: in range but nothing more")
	local i, o = sensor:lastCheck("edge_in"), sensor:lastCheck("edge_out")
	check(i ~= nil and i.visiblePoints == 5, "149.5 degrees off the gaze is inside the 300 degree field and seen")
	check(o ~= nil and o.offAxisDeg ~= nil and o.visiblePoints == nil, "150.5 degrees is outside it: the angle is recorded and no ray is cast")
	eq(sensor.raysThisTick, 5, "the one thing in the field costs five rays, and nothing else cost any")
	sensor.core.rangeScale = 0.5 -- the life clock lowers the eyes' reach at night
	far.position = Vector3.new(0, 0, -25)
	run(6)
	local f2 = sensor:lastCheck("far")
	check(f2 ~= nil and not f2.inRange, "at half reach 25 WU is out of range")
	near(sensor.core:reachWu(), 20.0, 1e-9, "the reach")
	check(close ~= nil and edgeIn ~= nil and edgeOut ~= nil, "the fixtures stood")
end)

case("sensor: a thing moves fast enough to cue only from the species' minimum speed", function()
	rig()
	local slow = addBall("slow", Vector3.new(5, 0, -2)) -- in the periphery, far from the cone
	slow.velocity = Vector3.new(0, 0, 0.29)
	run(30)
	eq(sensor.core.cuesMade, 0, "0.29 WU/s is under the 0.3 minimum: no cue")
	check(next(sensor.motionSeen) == nil, "and no motion seen")
	slow.velocity = Vector3.new(0, 0, 0.31)
	run(10)
	check(sensor.core.cuesMade >= 1, "0.31 WU/s is a cue")
	check(sensor.motionSeen.slow ~= nil, "and motion seen")
end)

case("sensor: a cue's bearing is quantized about the observer's heading and up", function()
	rig()
	local b = addBall("a", Vector3.new(5, 0, -2))
	b.velocity = Vector3.new(0, 0, 0.5)
	run(1)
	local c = contactOfBall(b)
	check(c ~= nil and c.modality == Observation.PERIPHERAL, "a cue")
	local truth = (b.position - observer.eye).Unit
	local want = PerceptionMath.quantizeDirection(truth, observer.heading, UP, 22.5)
	vnear(c.cueDirection, want, 1e-9, "the bearing is the truth snapped to a 22.5 degree sector and a band, relative to the heading")
	-- The same thing seen by an observer that faces another way, with the same gaze: the sectors turn with the body.
	rig(Vector3.zero, FORWARD)
	local turned = math.rad(11.25) -- half a sector: a quarter turn would put the sectors back where they were
	observer.heading = Vector3.new(-math.sin(turned), 0, -math.cos(turned))
	local b2 = addBall("a", Vector3.new(5, 0, -2))
	b2.velocity = Vector3.new(0, 0, 0.5)
	run(1)
	local c2 = contactOfBall(b2)
	local want2 = PerceptionMath.quantizeDirection((b2.position - observer.eye).Unit, observer.heading, UP, 22.5)
	check(c2 ~= nil, "a cue again")
	vnear(c2.cueDirection, want2, 1e-9, "turned with the heading")
	check((c2.cueDirection - c.cueDirection).Magnitude > 1e-3, "and not the same as with the other heading")
end)

case("sensor: an inspection records how big the thing looked and the share of it in view", function()
	rig()
	local b = addBall("a", Vector3.new(0, 0, -8))
	run(3)
	local c = contactOfBall(b)
	local k = sensor:lastCheck("a")
	check(c ~= nil and k ~= nil, "inspected")
	near(k.apparentDeg, PerceptionMath.apparentSizeDeg(2 * BALL_RADIUS, 8), 1e-9, "the apparent size is that of its diameter at its distance")
	near(c.apparentSizeDeg, k.apparentDeg, 1e-9, "and the contact has it")
	near(c.sizeWu, 2 * BALL_RADIUS, 1e-9, "the size in WU is the diameter")
	eq(k.inCone, true, "in the cone")
	near(k.offAxisDeg, 0, 1e-9, "dead ahead")
end)

-- ---------------------------------------------------------------- rays

case("sensor: rays are counted, and a remembered spot's checks and rays are counted apart", function()
	rig()
	local b = addBall("a", Vector3.new(0, 0, -8))
	run(10)
	eq(sensor.raysThisTick, 5, "five rays for the one thing in view")
	eq(sensor.raysTotal, 50, "in ten ticks, fifty")
	eq(sensor.maxRaysInATick, 5, "never more than five in a tick")
	b.enabled = false
	run(12) -- the contact is held 0.15 s after the last inspection: then it is lost, with a mark
	check(#memory:marks() == 1, "the thing is gone: lost, with a mark")
	local checks0, rays0, total0 = sensor.core.spotChecksTotal, sensor.spotRaysTotal, sensor.raysTotal
	run(5)
	eq(sensor.core.spotChecksTotal - checks0, 5, "the empty spot is looked at on each of those ticks")
	eq(sensor.spotRaysTotal - rays0, 25, "with five rays each when all its points are in view")
	eq(sensor.raysTotal - total0, 25, "which are counted in the total")
	-- Behind a barrier the first ray ends the check.
	rig()
	addWall(Vector3.new(0, 0, -4), Vector3.new(4, 4, 0.1), false)
	local wall2 = folder:GetChildren()[1]
	local d = addBall("a", Vector3.new(0, 0, -8))
	run(90)
	setWall(wall2, true)
	run(20)
	d.enabled = false
	local checks0, rays0 = sensor.core.spotChecksTotal, sensor.spotRaysTotal
	run(10)
	check(sensor.core.spotChecksTotal - checks0 >= 9, "a hidden spot is still looked at")
	eq(sensor.spotRaysTotal - rays0, sensor.core.spotChecksTotal - checks0, "but one ray each: the first the barrier stops ends the check")
end)

case("sensor: the cast is the world's alone", function()
	rig()
	local wall = addWall(Vector3.new(0, 0, -4), Vector3.new(2, 2, 0.1))
	local drawnOnly = addWall(Vector3.new(0, 0, -2), Vector3.new(2, 2, 0.1))
	drawnOnly.CanQuery = false -- a part that is only drawn (the marker, the sign, the path)
	local other = Instance.new("Part") -- a part of something else, outside the filter
	other.Size = Vector3.new(2, 2, 0.1)
	other.Position = Vector3.new(0, 0, -3)
	other.Anchored = true
	other.Parent = workspace
	local hit = cast(Vector3.zero, Vector3.new(0, 0, -8))
	check(hit ~= nil, "the wall stops the segment")
	if hit ~= nil then
		vnear(hit, Vector3.new(0, 0, -3.95), 1e-9, "at its near face: not at the part that is only drawn and not at the part outside the filter")
	end
	check(cast(Vector3.zero, Vector3.new(0, 0, -3)) == nil, "a segment that ends short of everything is clear")
	check(cast(Vector3.new(5, 0, 0), Vector3.new(5, 0, -8)) == nil, "so is one that goes past")
	other:Destroy()
	setWall(wall, false)
	check(cast(Vector3.zero, Vector3.new(0, 0, -8)) == nil, "and with the wall out of the world nothing stops it")
end)

-- ---------------------------------------------------------------- sample points

case("sensor: the five sample points", function()
	local pts = Sensor.samplePoints(Vector3.zero, Vector3.new(0, 0, -10), 0.5, UP)
	eq(#pts, 5, "five")
	vnear(pts[1], Vector3.new(0, 0, -10), 1e-12, "the centre first")
	vnear(pts[2], Vector3.new(0.4, 0, -10), 1e-12, "then 0.8 of the radius to one side (d x up)")
	vnear(pts[3], Vector3.new(-0.4, 0, -10), 1e-12, "and the other")
	vnear(pts[4], Vector3.new(0, 0.4, -10), 1e-12, "then up")
	vnear(pts[5], Vector3.new(0, -0.4, -10), 1e-12, "and down")
	-- Straight above the eye the side vector has no direction of its own: the fallback is d x right.
	local up = Sensor.samplePoints(Vector3.zero, Vector3.new(0, 10, 0), 0.5, UP)
	vnear(up[2], Vector3.new(0, 10, -0.4), 1e-12, "straight above: across the line of sight along z")
	vnear(up[4], Vector3.new(0.4, 10, 0), 1e-12, "and along x")
	local atEye = Sensor.samplePoints(Vector3.new(1, 2, 3), Vector3.new(1, 2, 3), 0.5, UP)
	for i, p in atEye do
		check(p.X == p.X and p.Y == p.Y and p.Z == p.Z, `no NaN when the thing is at the eye (point {i})`)
	end
end)

-- ---------------------------------------------------------------- could_sense

case("sensor: couldSense asks the senses without changing them", function()
	rig()
	addWall(Vector3.new(2, 0, -4), Vector3.new(2, 4, 0.1)) -- hides the far line from x = 2 to 6
	local tick, count, rays = sensor.core.tick, memory:count(), sensor.raysTotal
	check(sensor:couldSense(observer, Vector3.new(0, 0, -10), 0.25, cast), "a thing in plain view ahead")
	eq(sensor.raysTotal - rays, 5, "costs its five rays")
	check(not sensor:couldSense(observer, Vector3.new(4, 0, -8), 0.25, cast), "a thing behind the wall: its points are all hidden")
	check(not sensor:couldSense(observer, Vector3.new(0, 0, 10), 0.25, cast), "a thing behind the observer, in the wedge the field leaves out")
	check(not sensor:couldSense(observer, Vector3.new(0, 0, -41), 0.25, cast), "a thing beyond the reach")
	check(sensor:couldSense(observer, Vector3.new(0, 0, -0.01), 0.25, cast), "a thing at the eye is always sensed")
	check(sensor:couldSense(observer, Vector3.new(5.9, 0, -8), 0.5, cast), "a thing out from behind the wall by one point: that is enough")
	eq(sensor.core.tick, tick, "the tick did not move")
	eq(memory:count(), count, "and the memory holds what it did")
	eq(sensor.checksTotal, 0, "no check was made")
end)

-- ---------------------------------------------------------------- developer view

case("sensor: describeTracks lists what the last check of each thing found, sorted by the world's id", function()
	rig()
	local b = addBall("b", Vector3.new(0, 0, -8))
	local a = addBall("a", Vector3.new(0, 0, -6))
	local side = addBall("c_side", Vector3.new(7, 0, -2)) -- 74 degrees off: in the field, outside the cone
	run(20)
	local rows = sensor:describeTracks()
	eq(#rows, 3, "three things")
	eq(rows[1].perceptId .. rows[2].perceptId .. rows[3].perceptId, "abc_side", "sorted by id")
	check(rows[1].trackId == sensor:trackIdFor("a") and rows[2].trackId == sensor:trackIdFor("b"), "each with the contact it is filed under")
	check(rows[1].exposureS > 0.3 and rows[2].exposureS > 0.3, `exposure so far ({rows[1].exposureS})`)
	check(rows[1].inCone == true and rows[1].visiblePoints == 5 and rows[1].inRange, "a: in the cone, five points")
	near(rows[1].distance or 0, 6, 1e-9, "at its distance")
	check(rows[3].inCone == false and rows[3].exposureS == 0 and rows[3].trackId == "", "c_side: seen, not in the cone, no exposure and no contact")
	a.enabled = false
	run(1)
	eq(#sensor:describeTracks(), 2, "a thing that is gone is gone from the list")
	b.enabled = false
	side.enabled = false
	a.enabled = true
	a.position = Vector3.new(0, 0, -40.5)
	run(6) -- a thing nothing is watching is looked at on the next broad scan
	local only = sensor:describeTracks()
	check(#only == 1 and only[1].inRange == false and only[1].offAxisDeg == nil, "out of range: just that")
	run(20)
	check(sensor:describeTracks()[1].exposureS == 0, "exposure shows 0 when the last inspection is older than the grace")
end)

case("sensor: the cost of the tick is measured and kept for percentiles", function()
	rig()
	eq(sensor:costPercentile(0.5), 0, "nothing measured yet")
	eq(sensor:costTicks(), 0, "no ticks")
	addBall("a", Vector3.new(0, 0, -8))
	run(100)
	eq(sensor:costTicks(), 100, "a hundred ticks measured")
	check(sensor:costPercentile(0.5) <= sensor:costPercentile(0.99) and sensor:costPercentile(0.99) <= sensor:costPercentile(1.0), "percentiles rise")
	eq(sensor:costPercentile(1.0), sensor.cpuUsMax, "the top one is the largest")
	check(sensor.cpuUsTotal >= sensor.cpuUsMax, "the total is at least the largest")
	sensor:resetCost()
	eq(sensor:costTicks(), 0, "a new window starts empty")
	eq(sensor:costPercentile(0.5), 0, "with nothing in it")
	eq(sensor.cpuUsTotal + sensor.cpuUsMax, 0, "and no total")
	run(10)
	eq(sensor:costTicks(), 10, "ten ticks since")
	run(Sensor.COST_RING + 50)
	eq(#sensor._ring, Sensor.COST_RING, "the ring keeps the latest 1200 and no more")
	eq(sensor:costTicks(), 10 + Sensor.COST_RING + 50, "the window counts every tick")
	check(sensor:costPercentile(1.0) >= 0, "and the percentile reads the ring")
end)

-- SECTIONS GO ABOVE THIS LINE
print(`SENSOR passed={passed} failed={failed}`)
if failed > 0 then error("sensor check failed") end
