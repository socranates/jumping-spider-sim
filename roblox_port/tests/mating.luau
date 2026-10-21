-- The mating cycle and the new generation (ROBLOX-79): Data/MatingRules, Predator/Mate (the mate's body and the courtship meter), Life/Mating (the cycle, the
-- guard days, the hatching and the next generation) and Predator/MateDrive (the mate's legs, on the rival's drive). Simulated in the life/rival tests' style:
-- a real LifeLoop and clock driven tick by tick through the nights, a synthetic player standing where the test puts it, the real checkpoint records. Not
-- engine evidence (no Studio): the drawing, the scene and the sounds are checked in tests/client_mating.luau and are not seen here.
-- Run with the other suites:  python3 tests/run.py path/to/luau mating.luau
local Rules = require("../src/Shared/Data/MatingRules")
local RivalRules = require("../src/Shared/Data/RivalRules")
local Mate = require("../src/Shared/Predator/Mate")
local Mating = require("../src/Shared/Life/Mating")
local Scene = require("../src/Shared/Life/MatingScene")
local Rival = require("../src/Shared/Predator/RivalSpider")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local Growth = require("../src/Shared/Life/Growth")
local LifeClock = require("../src/Shared/Life/LifeClock")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local Json = require("../src/Shared/Persistence/Json")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local Route = require("../src/Shared/Predator/RivalRoute")
local MateDrive = require("../src/Shared/Predator/MateDrive")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local ObjectRecord = require("../src/Shared/Persistence/ObjectRecord")

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
local function near(got: number, want: number, eps: number, what: string)
	check(math.abs(got - want) <= eps, `{what} (got {got}, wanted {want})`)
end

local DT = 1 / 60
local CRACK = Vector3.new(-25.5, 0.31, 6.0)
local OPEN = Vector3.new(10, 0.31, 8) -- the open floor, far from where the mate arrives

-- ---------------------------------------------------------------------------------------------------------- a small world
-- A life loop with the cycle wired as the client wires it: a rest first asks Mating.atRest (so the rest's checkpoint has it), the morning wake tells
-- Mating.woke, and every tick runs Mating.tick on a snapshot of the player before the loop's own step.
local function newWorld(): any
	local needs = NeedsModel.new(true, false)
	needs.energy = 0.8
	local life = LifeLoop.new(needs, nil)
	life.growth.stage = Growth.ADULT
	local w: any = {
		needs = needs, life = life, log = {}, wasp = false, dancing = false, needsDance = false, sex = "female", resting = false,
		player = { position = OPEN, previous = OPEN, heading = Vector3.xAxis, up = Vector3.yAxis, grounded = true, moving = false, airborne = false, onLine = false, striking = false, holding = false },
		saves = 0,
	}
	life.save = function()
		w.saves += 1
		Mating.atRest(life, life.clock.day, life.clock.hour)
		return { ok = true, message = "Checkpoint kept." }
	end
	return w
end

local function setClock(w: any, day: number, hour: number)
	w.life.clock.day, w.life.clock.hour, w.life.clock.sleeping = day, hour, false
end

local function snapshot(w: any): any
	local p, clock = w.player, w.life.clock
	return {
		position = p.position, previous = p.previous, heading = p.heading, up = p.up, grounded = p.grounded, moving = p.moving, airborne = p.airborne,
		onLine = p.onLine, striking = p.striking, holding = p.holding, safe = Layout.inRetreat(p.position),
		day = clock.day, hour = clock.hour, resting = w.life.resting, wasp = w.wasp, dancing = w.dancing, needsDance = w.needsDance, sex = w.sex, seed = 914,
		rivalThreat = w.rivalThreat == true,
	}
end

-- One tick in the client's order: the cycle on the snapshot, then the life loop (feed/cancel are this tick's presses), then the loop's events.
local function tick(w: any, feed: boolean?, cancel: boolean?): { string }
	local life = w.life
	local clock = life.clock
	local day, hour = clock.day, clock.hour
	local events = Mating.tick(life, DT, snapshot(w))
	for _, e in events do table.insert(w.log, { e = e, day = day, hour = hour }) end
	local inCrack = Layout.inRetreat(w.player.position)
	life:step(DT, { inRetreat = inCrack, attached = true, still = true, holding = false, feeding = false, position = w.player.position }, feed == true, cancel == true)
	for _, ev in life:drainEvents() do
		if ev.kind == "woke" then
			local r = Mating.woke(life, ev.day :: number)
			if r ~= "" then table.insert(w.log, { e = r, day = clock.day, hour = clock.hour }) end
		end
	end
	return events
end

local function count(w: any, name: string): number
	local n = 0
	for _, x in w.log do if x.e == name then n += 1 end end
	return n
end

local function last(w: any, name: string): any
	for i = #w.log, 1, -1 do if w.log[i].e == name then return w.log[i] end end
	return nil
end

local function run(w: any, seconds: number): { string }
	local all: { string } = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		for _, e in tick(w) do table.insert(all, e) end
	end
	return all
end

-- The player rests in the crack in the evening and sleeps until the morning (and then takes the first step out: the rest ends).
local function sleepThrough(w: any)
	w.player.position, w.player.previous = CRACK, CRACK
	tick(w, true)
	assert(w.life.resting, "the rest began")
	for _ = 1, 3000 do
		tick(w)
		if not w.life.asleep and w.life.clock.hour >= 7.0 and w.life.clock.hour < 8.0 then break end
	end
	tick(w, false, true)
end

local function standNear(w: any, mate: any, away: number, facing: boolean?)
	-- The mate stands `away` studs east of the player, and the player looks at it (or away from it).
	local at = Vector3.new(10, 0.31, 8)
	mate.position, mate.previous = at + Vector3.xAxis * away, at + Vector3.xAxis * away
	w.player.position, w.player.previous = at, at
	w.player.heading = if facing == false then -Vector3.xAxis else Vector3.xAxis
end

-- ----------------------------------------------------------------------------------------------------------------- the rules
case("the numbers", function()
	check(Rules.energyMin == 0.6 and Rules.firstDay == 2 and Rules.arriveHour == 7.0 and Rules.arriveDistance == 8.0, "eligibility and arrival: energy 0.6, not day 1, from 07:00, not within 8 wu")
	check(Rules.arriveHour == RivalRules.arriveHour and Rules.arriveDistance == RivalRules.arriveDistance and Rules.firstDay == RivalRules.firstDay, "the rival's arrival rules, shared")
	check(Rules.courtSeconds == 8.0 and Rules.decayPerSecond == 0.25 and Rules.visitsMax == 3 and Rules.guardDays == 2, "an 8 s meter, drained twice as fast, 3 mornings per mate, 2 guard days")
	check(Rules.leaveHour == LifeClock.EVENING_H, "the mate goes at the evening")
	check(Rules.scale.male < 1 and Rules.scale.female > 1, "a male mate smaller, a female mate larger")
	check(not Layout.inRetreat(Rules.arriveAt) and not Layout.inRetreat(Rules.exitAt), "it arrives and leaves outside the crack")
	check(Mating.sexOf("maratus_volans_male") == "male" and Mating.sexOf("myrmarachne_formicaria_female") == "female" and Mating.sexOf("first_spider") == "female", "the sexes of the three spiders")
	check(Mate.opposite("male") == "female" and Mate.opposite("female") == "male", "the opposite sex")
	for _, sex in { "male", "female" } do
		for n = 1, 60 do
			local k = Mate.scaleFor(914, n, sex)
			check(math.abs(k / Rules.scale[sex] - 1) <= Rules.scaleSpread + 1e-9, `mate {n} ({sex}) varies by at most 5% ({k})`)
			check(k == Mate.scaleFor(914, n, sex), "and is the same every time")
		end
	end
	check(Mate.scaleFor(914, 1, "male") ~= Mate.scaleFor(914, 2, "male"), "another mate, another size")
end)

-- ------------------------------------------------------------------------------------------------------------ eligibility
case("eligibility: full-grown and well fed, at a rest", function()
	local w = newWorld()
	local life = w.life
	life.growth.stage = Growth.ADULT - 1
	check(not Mating.eligible(life.growth, 1.0), "a subadult is not eligible however well fed")
	life.growth.stage = Growth.ADULT
	check(Mating.eligible(life.growth, 0.6) and Mating.eligible(life.growth, 1.0) and not Mating.eligible(life.growth, 0.59), "an adult with 0.6 energy is; with 0.59 it is not")
	-- not at a rest: nothing is set
	setClock(w, 3, 12)
	run(w, 2)
	check(life.mating.ready_day == 0, "awake in the open: not ready, however fed")
	-- the rest in the crack by day: the next morning is tomorrow's
	w.player.position, w.player.previous = CRACK, CRACK
	w.needs.energy = 0.59
	tick(w, true)
	check(life.resting and life.mating.ready_day == 0, "a rest at 0.59: the checkpoint is kept, no mate is wanted")
	tick(w, false, true)
	w.needs.energy = 0.6
	tick(w, true)
	check(life.mating.ready_day == 4, `a rest at 0.6 on day 3 at midday: a mate from the morning of day 4 ({life.mating.ready_day})`)
	-- it is never cleared or moved by the next rest
	tick(w, false, true)
	setClock(w, 3, 14)
	w.needs.energy = 0.2
	tick(w, true)
	check(life.mating.ready_day == 4 and w.saves == 3, "a later rest does not change it, even hungry")
	-- the small hours belong to the day before the morning: a rest at 03:00 on day 5 is for the morning of day 5
	local u = newWorld()
	setClock(u, 5, 3)
	u.player.position, u.player.previous = CRACK, CRACK
	tick(u, true)
	check(u.life.mating.ready_day == 5, "a rest at 03:00 on day 5 wants a mate at 07:00 the same day")
	-- a young spider never
	local y = newWorld()
	y.life.growth.stage = 1
	setClock(y, 6, 12)
	y.player.position, y.player.previous = CRACK, CRACK
	tick(y, true)
	check(y.life.mating.ready_day == 0 and y.life.mating.stage == "none", "a juvenile resting fed: nothing")
	-- not during a cycle already going
	local g = newWorld()
	g.life.mating = Mating.new()
	g.life.mating.stage = "mated"
	g.player.position, g.player.previous = CRACK, CRACK
	setClock(g, 6, 12)
	tick(g, true)
	check(g.life.mating.ready_day == 0, "a cycle going sets nothing")
end)

-- ---------------------------------------------------------------------------------------------------------------- arrival
case("arrival: the rival's rules, one mate at a time, ignored by the wasp's day", function()
	local function arrives(set: (any) -> ()): boolean
		local w = newWorld()
		w.life.mating = Mating.new()
		w.life.mating.ready_day = 3
		setClock(w, 3, 8)
		set(w)
		tick(w)
		return count(w, "arrived") == 1
	end
	check(arrives(function() end), "ready, day 3, 08:00, the spider far away: it arrives")
	check(not arrives(function(w) setClock(w, 2, 8) end), "the morning before ready_day: no")
	check(not arrives(function(w) setClock(w, 3, 6.9) end), "before 07:00: no")
	check(arrives(function(w) setClock(w, 3, 7.0) end), "at 07:00 exactly: yes")
	check(not arrives(function(w) setClock(w, 3, 16.0) end) and arrives(function(w) setClock(w, 3, 15.9) end), "not from 16:00: a visit not begun by then is for tomorrow")
	check(not arrives(function(w) w.wasp = true end), "not while the wasp visits")
	check(not arrives(function(w) w.player.position, w.player.previous = Rules.arriveAt + Vector3.new(-7.9, 0, 0), Rules.arriveAt + Vector3.new(-7.9, 0, 0) end), "not within 8 studs of the player")
	check(arrives(function(w) w.player.position, w.player.previous = Rules.arriveAt + Vector3.new(-8.1, 0, 0), Rules.arriveAt + Vector3.new(-8.1, 0, 0) end), "8.1 studs is far enough")
	check(not arrives(function(w) w.life.resting = true end), "not while the spider rests")
	check(not arrives(function(w) w.life.mating.ready_day = 0 end), "not unless a rest wanted it")
	check(not arrives(function(w) w.life.mating.stage = "mated" end) and not arrives(function(w) w.life.mating.stage = "sac" end), "not once the cycle has gone on")
	check(not arrives(function(w) w.life.mating.away_day = 3 end), "not the day it was driven off or left")
	-- day 1 is protected whatever else is set
	local w = newWorld()
	w.life.mating = Mating.new()
	w.life.mating.ready_day = 1
	setClock(w, 1, 9)
	run(w, 1)
	check(count(w, "arrived") == 0 and w.life.mate.state == "away", "day 1: no mate")
	-- the arrival
	local v = newWorld()
	v.life.mating = Mating.new()
	v.life.mating.ready_day = 3
	setClock(v, 3, 9)
	tick(v)
	local mate = v.life.mate
	check(mate.state == "wander" and (mate.position - Rules.arriveAt).Magnitude < 1e-9 and Mate.valid(mate) and Mate.present(mate), "it arrives at the east end, wandering")
	check(mate.sex == "male" and v.life.mating.mates == 1 and v.life.mating.visits == 1 and v.life.mating.visit_day == 3, "a male for the female first spider, mate 1, its first morning")
	check(count(v, "new_mate") == 1 and count(v, "arrived") == 1, "a new mate and an arrival are told")
	near(mate.scale, Mate.scaleFor(914, 1, "male"), 1e-12, "its size is the seeded one for mate 1")
	run(v, 5)
	check(count(v, "arrived") == 1 and v.life.mating.visits == 1, "one mate at a time: no second arrival while it is here")
	-- a male player gets a female mate, larger
	local f = newWorld()
	f.sex = "male"
	f.life.mating = Mating.new()
	f.life.mating.ready_day = 3
	setClock(f, 3, 9)
	tick(f)
	check(f.life.mate.sex == "female" and f.life.mate.scale > 1.0, "a male spider's mate is a female, larger")
	check(Mate.valid(nil) and Mate.valid(Mate.new()) and not Mate.percept(Mate.new()), "a mate not on the sill has no percept")
	check(Mate.percept(mate) ~= nil and Mate.percept(mate).maxCategory == "movement", "a mate on the sill is a moving thing to the senses")
end)

-- --------------------------------------------------------------------------------------------------------------- courtship
local function withMate(sex: string?, needsDance: boolean?): any
	local w = newWorld()
	w.sex = sex or "female"
	w.needsDance = needsDance == true
	w.life.mating = Mating.new()
	w.life.mating.ready_day = 3
	setClock(w, 3, 9)
	tick(w) -- it arrives
	assert(w.life.mate.state == "wander")
	return w
end

case("the meter fills over 8 seconds, decays when you move, and holds without the dance", function()
	local w = withMate()
	local mate = w.life.mate
	standNear(w, mate, 2.5)
	run(w, 4.0)
	near(mate.meter, 0.5, 0.01, "standing still, facing it, close: half full after 4 s")
	check(mate.state == "attend" or mate.state == "approach", `it has noticed the spider ({mate.state})`)
	check(count(w, "noticed") == 1, "once: it noticed")
	-- moving drains it at 0.25 a second
	w.player.moving = true
	run(w, 1.0)
	near(mate.meter, 0.25, 0.01, "moving for a second: 0.25 lost")
	w.player.moving = false
	-- facing away drains it too
	w.player.heading = -Vector3.xAxis
	run(w, 0.5)
	near(mate.meter, 0.125, 0.01, "looking away: it drains")
	w.player.heading = Vector3.xAxis
	-- too far
	standNear(w, mate, 3.5)
	run(w, 0.5)
	check(mate.meter < 0.01, "3.5 studs away: it empties")
	-- airborne
	standNear(w, mate, 2.5)
	run(w, 2)
	local m1 = mate.meter
	w.player.airborne = true
	w.player.striking = false
	standNear(w, mate, 2.5)
	w.player.airborne = false
	check(m1 > 0.2, "filling again")
	-- a clear line is needed: the retreat is private
	local c = withMate()
	c.player.position, c.player.previous = CRACK, CRACK
	c.life.mate.position = CRACK + Vector3.xAxis * 2
	run(c, 2)
	check(c.life.mate.meter == 0 and c.life.mate.state == "wander", "a spider in the crack is neither noticed nor courted")
	-- the peacock owes a dance
	local p = withMate("male", true)
	standNear(p, p.life.mate, 2.5)
	run(p, 3)
	check(p.life.mate.meter == 0, "a dancing spider's meter does not fill while it does not dance")
	p.dancing = true
	run(p, 4)
	near(p.life.mate.meter, 0.5, 0.01, "dancing: half full after 4 s")
	p.dancing = false
	run(p, 2)
	near(p.life.mate.meter, 0.5, 0.01, "stop dancing, stay still and facing: it holds")
	p.player.moving = true
	run(p, 1)
	near(p.life.mate.meter, 0.25, 0.01, "move: it drains")
	-- the wasp holds it all still
	local q = withMate()
	standNear(q, q.life.mate, 2.5)
	run(q, 2)
	local before = q.life.mate.meter
	q.wasp = true
	q.player.moving = true
	local pos = q.life.mate.position
	run(q, 3)
	check(q.life.mate.meter == before and q.life.mate.position == pos, "a wasp visit pauses the mate and the meter, as it pauses the rival")
end)

case("jumping at it or striking it drives it off for the day; it returns the next morning, three mornings, then a new mate", function()
	local w = withMate()
	local mate = w.life.mate
	standNear(w, mate, 2.5)
	run(w, 2)
	w.player.striking = true
	w.player.previous = mate.position + Vector3.new(-0.2, 0, 0)
	w.player.position = mate.position + Vector3.new(0.1, 0, 0)
	local ev = tick(w)
	check(ev[1] == "driven" and mate.state == "leaving" and mate.reason == "driven" and mate.meter == 0, "a strike through it: driven off, the meter gone")
	check(w.life.mating.drive_offs == 1 and w.life.mating.away_day == 3 and w.life.mating.stage == "none", "counted; away for day 3; the cycle has not moved")
	w.player.striking = false
	-- it is never caught: there is no capture, no food, no state of the rival's
	check(mate.state ~= "captured" and mate.food == nil, "never caught")
	mate.position = Rules.exitAt
	run(w, 0.1)
	check(mate.state == "away" and last(w, "gone") ~= nil, "gone at the edge")
	setClock(w, 3, 12)
	run(w, 2)
	check(w.life.mate.state == "away", "not back the same day")
	setClock(w, 4, 6.5)
	run(w, 1)
	check(w.life.mate.state == "away", "not before 07:00")
	setClock(w, 4, 7.2)
	run(w, 0.5)
	check(w.life.mate.state == "wander" and w.life.mating.visits == 2 and w.life.mating.mates == 1, "it returns the next morning: the same mate, its second morning")
	-- jumping at it
	standNear(w, w.life.mate, 1.8)
	w.player.airborne = true
	local e2 = tick(w)
	check(e2[1] == "driven" and w.life.mate.state == "leaving", "jumping at it within 2 studs drives it off too")
	w.player.airborne = false
	-- a jump far from it does nothing
	local far = withMate()
	standNear(far, far.life.mate, 5.0)
	far.player.airborne = true
	tick(far)
	check(far.life.mate.state ~= "leaving", "a jump 5 studs away is not a jump at it")
	-- the third morning is the last; the fourth is another mate
	w.life.mate.position = Rules.exitAt
	w.player.airborne = false
	run(w, 0.1)
	setClock(w, 5, 8)
	run(w, 0.5)
	check(w.life.mating.visits == 3 and w.life.mating.mates == 1 and w.life.mate.state == "wander", "day 5: its third morning")
	w.life.mate.state = "leaving"
	w.life.mate.position = Rules.exitAt
	w.life.mate.reason = "driven"
	run(w, 0.1)
	check(w.life.mate.state == "away", "gone again")
	setClock(w, 6, 8)
	run(w, 0.5)
	check(w.life.mating.mates == 2 and w.life.mating.visits == 1 and w.life.mate.state == "wander" and count(w, "new_mate") == 2, "day 6: a new mate")
	near(w.life.mate.scale, Mate.scaleFor(914, 2, "male"), 1e-12, "with its own size")
end)

-- ------------------------------------------------------------------------------------------------------------ the whole cycle
case("a whole cycle, day by day: rest, mate, court, mate, sac night, two guard days, hatch, the next generation", function()
	local w = newWorld()
	local life, needs = w.life, w.needs
	-- Day 2 evening: the first rest of a full-grown, fed spider.
	setClock(w, 2, 18.5)
	sleepThrough(w)
	check(life.clock.day == 3 and life.clock.hour >= 7.0 and life.clock.hour < 7.2, `morning of day 3 ({life.clock.day} {life.clock.hour})`)
	check(life.mating.ready_day == 3, `the rest wanted a mate from the morning of day 3 ({life.mating.ready_day})`)
	needs.energy = 0.8
	-- Day 3: the spider walks out; the mate comes.
	w.player.position, w.player.previous = OPEN, OPEN
	run(w, 0.5)
	local mate = life.mate
	check(mate.state ~= "away" and life.mating.mates == 1, "the mate is on the sill")
	local arrived = last(w, "arrived")
	check(arrived ~= nil and arrived.day == 3 and arrived.hour >= 7.0 and arrived.hour < 7.1, "it arrived at 07:00 on day 3")
	-- Courtship.
	standNear(w, mate, 2.5)
	run(w, 7.5)
	check(life.mating.stage == "none" and mate.meter > 0.8 and mate.meter < 1, `the meter is nearly full ({mate.meter})`)
	run(w, 1.0)
	check(life.mating.stage == "courted" and mate.state == "pair", "full after 8 s: courted, together")
	local courted = last(w, "courted")
	near(courted.hour - arrived.hour, 8.0 * LifeClock.ACTIVE_HOURS_PER_S + 0.5 * LifeClock.ACTIVE_HOURS_PER_S, 0.05, "a little over eight seconds of play after the first")
	run(w, 10.3)
	check(life.mating.stage == "courted", "the pause together is eleven seconds with a male mate (ROBLOX-89: it was five)")
	run(w, 0.4)
	check(life.mating.stage == "mated" and mate.state == "leaving" and mate.reason == "mated", "mated; the mate leaves")
	check(count(w, "mated") == 1, "once")
	mate.position = Rules.exitAt
	run(w, 0.1)
	check(mate.state == "away", "gone off the sill")
	run(w, 5)
	check(mate.state == "away" and life.mating.stage == "mated", "no mate is brought again")
	-- The sac night: day 3, in the evening. Sleep in the crack.
	setClock(w, 3, 18.5)
	needs.energy = 0.7
	sleepThrough(w)
	check(life.mating.stage == "sac" and life.mating.sac_day == 4 and life.mating.guard_day == 1, `the sac is made by the sleep; guard day 1 is day 4 ({life.mating.stage} {life.mating.sac_day})`)
	check(count(w, "sac") == 1, "once")
	-- Guard day 1 (day 4): nothing happens during the day.
	needs.energy = 0.8
	setClock(w, 4, 8)
	run(w, 2)
	check(life.mating.stage == "sac" and life.mate.state == "away", "day 4 by day: still the first guard day, no mate")
	setClock(w, 4, 18.5)
	sleepThrough(w)
	check(life.clock.day == 5 and life.mating.stage == "guarding" and life.mating.guard_day == 2, `day 5: the second guard day ({life.mating.stage})`)
	check(count(w, "guard_day") == 1, "told once")
	needs.energy = 0.8
	setClock(w, 5, 12)
	run(w, 2)
	check(life.mating.stage == "guarding", "day 5 by day")
	-- Hatch: the morning after the second guard day.
	setClock(w, 5, 18.5)
	sleepThrough(w)
	check(life.clock.day == 6 and life.mating.stage == "hatched", `day 6 morning: hatched ({life.mating.stage})`)
	check(life.mating.hatch_day == 6 and life.mating.hatch_hour >= 7.0 and life.mating.brood >= Rules.broodMin and life.mating.brood <= Rules.broodMax, `a brood of {life.mating.brood}`)
	check(Mating.problemsWith(life.mating, life.mate)[1] == nil, "a good record")
	check(Mating.hasSac(life.mating) and not Mating.hasSac(nil) and not Mating.hasSac(Mating.new()), "the sac is there from the sleep that made it to the carrying on")
	check(count(w, "hatched") == 1, "once")
	run(w, 3)
	check(count(w, "hatched") == 1 and life.mating.stage == "hatched", "waiting for the player: nothing else moves")
	-- Carry on: generation 1.
	life.growth.fedSinceMoult = 0.5
	needs.energy = 0.9
	local before = { day = life.clock.day, hour = life.clock.hour }
	local generation, hatchDay = Mating.carryOn(life, needs)
	check(generation == 1 and hatchDay == 6 and life.generation == 1, "generation 1, hatched on day 6")
	check(life.growth.stage == 0 and life.growth:stageName() == "young juvenile" and life.growth.fedSinceMoult == 0 and not life.growth.ready, "growth is the first stage again")
	check(needs.energy == Rules.freshEnergy and needs.starvingStreakH == 0 and needs.rest == 1.0, "a fresh energy and rest")
	check(life.clock.day == before.day and life.clock.hour == before.hour, "the day count goes on")
	check(life.mating.stage == "none" and life.mating.ready_day == 0 and life.mating.mates == 0 and life.mate.state == "away", "the cycle is none again")
	check(life.grantedSeen == needs.grantedTotal and not life.lifeOver, "the books are level")
	-- And it can happen again in the next generation.
	life.growth.stage = Growth.ADULT
	needs.energy = 0.9
	setClock(w, 8, 18.5)
	sleepThrough(w)
	check(life.mating.ready_day == 9, "generation 2's first rest as an adult: a mate wanted from day 9")
	needs.energy = 0.9
	w.player.position, w.player.previous = OPEN, OPEN
	run(w, 0.5)
	check(life.mate.state ~= "away", "and it comes")
end)

case("the brood is a seeded handful, not rerolled", function()
	local seen: { [number]: boolean } = {}
	for day = 4, 80 do
		local n = Mating.broodSize(914, 0, day)
		check(n >= Rules.broodMin and n <= Rules.broodMax and n == Mating.broodSize(914, 0, day), `day {day}: {n}`)
		seen[n] = true
	end
	local kinds = 0
	for _ in seen do kinds += 1 end
	check(kinds >= 4, `it varies ({kinds} sizes in 77 days)`)
	check(Mating.broodSize(914, 0, 6) ~= Mating.broodSize(914, 1, 6) or Mating.broodSize(914, 0, 7) ~= Mating.broodSize(914, 1, 7), "and by family")
end)

-- -------------------------------------------------------------------------------------------------- mid-cycle rests and the evening
case("rests and the evening: the mate goes, the cycle waits", function()
	-- a rest while it is courting sends it away for the day, unseen
	local w = withMate()
	standNear(w, w.life.mate, 2.5)
	run(w, 3)
	check(w.life.mate.meter > 0.3, "courting")
	w.player.position, w.player.previous = CRACK, CRACK
	tick(w, true)
	tick(w)
	check(w.life.mate.state == "away" and w.life.mate.meter == 0 and w.life.mating.away_day == 3 and w.life.mate.reason == "rest", "resting sends the mate away for the day; the meter starts again")
	check(w.life.mating.stage == "none", "no harm to the cycle")
	-- a rest during the pause together lets the mating finish
	local p = withMate()
	standNear(p, p.life.mate, 2.5)
	run(p, 8.5)
	check(p.life.mating.stage == "courted", "together")
	p.player.position, p.player.previous = CRACK, CRACK
	tick(p, true)
	tick(p)
	check(p.life.mating.stage == "mated", "a rest in the pause: the mating is not cut short")
	tick(p)
	check(p.life.mate.state == "away", "and the mate is gone")
	-- the evening
	local e = withMate()
	standNear(e, e.life.mate, 6.5)
	setClock(e, 3, 17.99)
	run(e, 1)
	check(e.life.mate.state == "leaving" and e.life.mate.reason == "dusk", "at 18:00 it leaves")
	e.life.mate.position = Rules.exitAt
	run(e, 0.1)
	check(e.life.mate.state == "away" and e.life.mating.away_day == 3, "gone")
	-- it walks off even when the edge is never reached
	local t = withMate()
	t.life.mate.state, t.life.mate.reason = "leaving", "driven"
	run(t, Rules.leaveSeconds - 1)
	check(t.life.mate.state == "leaving", "still on its way after 119 s")
	run(t, 2)
	check(t.life.mate.state == "away", "gone after 120 s")
	-- the played spider is changed to the mate's sex in the Settings: it leaves
	local s = withMate()
	s.sex = "male"
	tick(s)
	check(s.life.mate.state == "leaving" and s.life.mate.reason == "sex", "it has no business with its own sex")
	-- a rest through the whole of a morning: no arrival; the next morning
	local r = newWorld()
	r.life.mating = Mating.new()
	r.life.mating.ready_day = 3
	setClock(r, 3, 7.5)
	r.player.position, r.player.previous = CRACK, CRACK
	tick(r, true)
	check(r.life.resting, "resting in the crack")
	run(r, 1)
	check(r.life.resting and r.life.mate.state == "away", "no arrival during a rest")
end)

-- ------------------------------------------------------------------------------------- rival and wasp rules on days a mate is present
case("the rival and the wasp are unaffected on days a mate is present", function()
	local WaspDirector = require("../src/Shared/Predator/WaspDirector")
	local w = withMate()
	check(w.life.mate.state == "wander", "a mate on the sill on day 3")
	-- the rival arrives by its own rules, at the same time
	local rival = Rival.new()
	local s = { position = OPEN, previous = OPEN, heading = Vector3.xAxis, day = 3, hour = 9, meals = 1, resting = false, safe = false, wasp = false, gentle = false, grounded = true, moving = false, airborne = false, onLine = false, holding = false, striking = false }
	Rival.step(rival, DT, s, function() return false end)
	check(rival.state == "patrol", "the rival arrives with a mate present")
	-- the rival is not moved or affected by the mate: the mate never appears in its snapshot
	check(Rival.percept(rival) ~= nil and Rival.percept(rival).id == "rival_spider" and Mate.percept(w.life.mate).id == "mate_spider", "two different things to the senses")
	-- the wasp: a director given the game's rules visits on day 3 with the mate there; nothing about it takes the mate into account
	local director = WaspDirector.new({
		seed = 914, enabled = true,
		world = { ray = function(): boolean return false end, clear = function(): boolean return true end, inRetreat = Layout.inRetreat },
	})
	director:useGameRules()
	local spider: any = { position = CRACK, velocity = Vector3.zero, walkSpeed = 2.5, airborne = false, falling = false }
	local visits = 0
	local hour = 0.0
	while hour < 24.0 do
		director:step(DT, spider, { day = 3, hour = hour, resting = false, moulting = false, meals = 1 })
		if director:isVisiting() then
			visits += 1
			-- the mate stands still for it
			w.wasp = true
			local pos = w.life.mate.position
			run(w, 1)
			check(w.life.mate.position == pos and w.life.mate.state == "wander", "the mate pauses during the visit")
			w.wasp = false
			director:clearVisit()
		end
		hour += 0.05
	end
	check(visits == 2, `two wasp visits on day 3 as ever, mate or no mate ({visits})`)
	-- the wasp is handed the rival (RivalSpider.target) and never the mate: it has nothing to take it by
	check(Rival.target(rival) ~= nil and Rival.target(w.life.mate) == nil, "the wasp's target is the rival's; the mate is not a target")
end)


-- ------------------------------------------------------------------------------------------------------------- the mate's legs
-- The real SpiderMotor on the real boxes (tests/shim.luau's box world, as tests/rivalnav.luau): the mate wanders where the rival patrols, comes up to a
-- spider it sees and stops, stands facing it, walks to the exit when it leaves, and is never in the crack.
local sill = BoxWorld.folder("MateSill", Layout.PIECES)
local function legs(w: any): any
	local m = Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Rules.arriveAt, heading = Vector3.new(-1, 0, 0),
		boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = sill,
	})
	local d = MateDrive.new(m, function() return false end)
	w.legs = d
	return d
end
-- One tick of the world with the drive after the step (the client's order).
local function walkTick(w: any)
	local s = snapshot(w)
	s.courting, s.scene = Mate.courting(w.life.mate,w.player.position), Mate.sceneActive(w.life.mate)
	s.drive = w.legs
	local events = Mating.tick(w.life, DT, s)
	for _, e in events do table.insert(w.log, { e = e, day = s.day, hour = s.hour }) end
	w.legs:update(w.life.mate, DT, s)
	w.life:step(DT, { inRetreat = Layout.inRetreat(w.player.position), attached = true, still = true, holding = false, feeding = false, position = w.player.position }, false, false)
	w.life:drainEvents()
end

case("the mate sees its own courtship without removing rival protections or safety restrictions",function()
 local w=newWorld();local d=legs(w)
 local mate=Mate.new();mate.state="attend";mate.position=Vector3.new(-5,.31,-7.5);mate.previous=mate.position
 w.player.position=Vector3.new(-5,.31,-9);w.player.previous=w.player.position;w.player.heading=Vector3.zAxis
 local s=snapshot(w);s.courting=true;s.scene=true
 local blocked=false;d.drive.blocked=function() return blocked end
 local function advance() for _=1,20 do d:update(mate,DT,s) end end
 advance()
 check(d.sees,"mate can see the partner while rival-only courtship/scene guards are set")
 check(s.courting==true and s.scene==true,"adapter retains the caller's rival protections")
 for _,flag in {"safe","resting","wasp"} do
  s[flag]=true;advance();check(not d.sees,"mate still respects "..flag)
  s[flag]=false;advance();check(d.sees,"mate can see again after "..flag)
 end
 blocked=true;advance();check(not d.sees,"courtship does not see through a real obstruction")
 blocked=false;advance();check(d.sees,"unobstructed sight returns")
 d:destroy()
end)

case("the legs: it walks the sill, comes up to a spider it sees, stands facing it, leaves by the exit, never enters the crack", function()
	local w = newWorld()
	legs(w)
	w.life.mating = Mating.new()
	w.life.mating.ready_day = 3
	setClock(w, 3, 8)
	w.player.position, w.player.previous = Vector3.new(-18, 0.31, -9), Vector3.new(-18, 0.31, -9)
	walkTick(w)
	local mate = w.life.mate
	check(mate.state == "wander" and (w.legs.drive.motor.pos - Rules.arriveAt).Magnitude < 0.5, "arrived and standing at the east end")
	local start = mate.position
	local inCrack, moved = 0, 0.0
	for _ = 1, 60 * 20 do
		walkTick(w)
		if Layout.inRetreat(mate.position) then inCrack += 1 end
		if mate.state ~= "wander" then break end
	end
	moved = (mate.position - start).Magnitude
	check(moved > 4 or mate.state ~= "wander", `it walks (${string.format("%.1f", moved)} studs in 20 s, or it has found the spider)`)
	check(mate.up.Y > -1 and Mate.valid(mate), "and its record stays good")
	-- A spider in plain sight on the floor: it notices and comes
	local mover = newWorld()
	legs(mover)
	mover.life.mating = Mating.new()
	mover.life.mating.ready_day = 3
	setClock(mover, 3, 8)
	mover.player.position, mover.player.previous = Vector3.new(-18, 0.31, -9), Vector3.new(-18, 0.31, -9)
	walkTick(mover)
	local mm = mover.life.mate
	-- (it arrives with the spider far off; then the spider is in plain sight of it on the open floor, 6 studs west of it)
	local seenAt = Vector3.new(mm.position.X - 6, 0.31, mm.position.Z)
	mover.player.position, mover.player.previous = seenAt, seenAt
	local noticedAt: number? = nil
	local arrivedAt: number? = nil
	for k = 1, 60 * 90 do
		walkTick(mover)
		if noticedAt == nil and mm.state == "approach" then noticedAt = k end
		if mm.state == "attend" then arrivedAt = k; break end
	end
	check(noticedAt ~= nil, "it notices a spider within 8 studs in plain sight")
	check(arrivedAt ~= nil, "and walks up to it")
	local gap = (mm.position - mover.player.position).Magnitude
	check(gap <= Rules.attendWu + 0.4 and gap >= 1.0, `stopping about {Rules.attendWu} studs away ({string.format("%.2f", gap)})`)
	-- It stands and faces the spider.
	for _ = 1, 120 do walkTick(mover) end
	check(mm.state == "attend" or mm.state == "pair", "it stays")
	local toSpider = (mover.player.position - mm.position)
	local flat = Vector3.new(toSpider.X, 0, toSpider.Z).Unit
	check(mm.heading:Dot(flat) > 0.8, `facing the spider ({string.format("%.2f", mm.heading:Dot(flat))})`)
	-- Court it: the player stands facing the mate
	mover.player.heading = Vector3.new(flat.X, 0, flat.Z) * -1
	for _ = 1, 60 * 12 do walkTick(mover) end
	check(mover.life.mating.stage == "courted" or mover.life.mating.stage == "mated", `courted by standing still ({mover.life.mating.stage}, meter {string.format("%.2f", mm.meter)})`)
	for _ = 1, 60 * 12 do walkTick(mover) end
	check(mover.life.mating.stage == "mated" and mm.state == "leaving", "mated and leaving")
	-- It walks to the exit and is gone.
	local took = nil
	for k = 1, 60 * 125 do
		walkTick(mover)
		if Layout.inRetreat(mm.position) then inCrack += 1 end
		if mm.state == "away" then took = k * DT; break end
	end
	check(took ~= nil, `it is gone from the sill (${took and string.format("%.0f", took) or "never"} s)`)
	local atExit = (Vector3.new(mm.position.X, 0, mm.position.Z) - Vector3.new(Rules.exitAt.X, 0, Rules.exitAt.Z)).Magnitude
	check(atExit <= Rules.exitRadius + 0.5 or took == Rules.leaveSeconds, `at the exit, not just timed out ({string.format("%.1f", atExit)} studs from it)`)
	check(inCrack == 0, "never in the crack")
	-- Standing for a wasp visit.
	local pause = newWorld()
	legs(pause)
	pause.life.mating = Mating.new()
	pause.life.mating.ready_day = 3
	setClock(pause, 3, 8)
	pause.player.position, pause.player.previous = Vector3.new(-18, 0.31, -9), Vector3.new(-18, 0.31, -9)
	for _ = 1, 120 do walkTick(pause) end
	local at = pause.life.mate.position
	pause.wasp = true
	for _ = 1, 120 do walkTick(pause) end
	check((pause.life.mate.position - at).Magnitude < 0.05, "during a wasp visit the mate stands still")
	pause.wasp = false
	for _ = 1, 240 do walkTick(pause) end
	check((pause.life.mate.position - at).Magnitude > 0.5, "and walks on after it")
	-- A spider in the crack is not approached into it
	local priv = newWorld()
	legs(priv)
	priv.life.mating = Mating.new()
	priv.life.mating.ready_day = 3
	setClock(priv, 3, 8)
	priv.player.position, priv.player.previous = CRACK, CRACK
	walkTick(priv)
	check(priv.life.mate.state == "wander", "arrived")
	local deep = 0
	for _ = 1, 60 * 20 do
		walkTick(priv)
		if Layout.inRetreat(priv.life.mate.position) then deep += 1 end
		if priv.life.mate.state ~= "wander" then break end
	end
	check(deep == 0 and priv.life.mate.state == "wander" and priv.life.mate.meter == 0, "a spider in the crack: the mate neither notices it nor goes in")
end)


-- ----------------------------------------------------------------------------------------------------------- checkpoints
-- The real checkpoint of a whole world (as tests/checkpoint.luau builds it) with the cycle in it: the mate, the cycle's record and the generation are
-- kept at a rest and put back by a return; nothing is rerolled; an older record restores as nothing going on; a bad one is refused.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }
local cast = Sensor.workspaceCast(params)
local camera = { CFrame = CFrame.new(Vector3.new(0, 30, 40)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) }
local STILL = { wish = Vector3.zero, creep = false, reel = 0, dropHeld = false, releaseHeld = false }

local function fullWorld(): any
	local motor = Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX,
	})
	local prey = PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, false)
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, kept = {}, log = {}, visiting = false, sex = "female", dancing = false, needsDance = false }
	w.life = LifeLoop.new(needs, function()
		-- as the client's life.save: the cycle first (at a rest), then the checkpoint
		Mating.atRest(w.life, w.life.clock.day, w.life.clock.hour)
		local why = Checkpoint.boundaryProblem(w)
		if why ~= "" then return { ok = false, message = why } end
		local record, err = Checkpoint.capture(w, 0)
		if not record then return { ok = false, message = err :: string } end
		table.insert(w.kept, record)
		return { ok = true, message = "Checkpoint kept." }
	end)
	w.life.growth.stage = Growth.ADULT
	needs.energy = 0.8
	motor:place(CRACK, Vector3.yAxis, Vector3.new(1, 0, 0))
	return w
end

local function fullTick(w: any, feed: boolean?, cancel: boolean?)
	local life, clock = w.life, w.life.clock
	local day, hour = clock.day, clock.hour
	w.sensor:step(DT, w.motor:observer(), w.prey:percepts(), cast)
	w.prey:before(DT, w.motor.pos, w.motor:observer(), w.sensor, cast, camera)
	w.motor:tick(STILL)
	w.prey:after(DT, w.motor, w.sensor, cast)
	local s = {
		position = w.motor.pos, previous = w.motor.pos, heading = w.motor.heading, up = w.motor.up, grounded = true, moving = false, airborne = false, onLine = false,
		striking = false, holding = false, safe = Layout.inRetreat(w.motor.pos), day = day, hour = hour, resting = life.resting, wasp = w.visiting, dancing = w.dancing,
		needsDance = w.needsDance, sex = w.sex, seed = 914,
	}
	for _, e in Mating.tick(life, DT, s) do table.insert(w.log, e .. "@" .. string.format("%d/%.4f", day, hour)) end
	life:step(DT, { inRetreat = Layout.inRetreat(w.motor.pos), attached = true, still = true, holding = false, feeding = false }, feed == true, cancel == true)
	for _, ev in life:drainEvents() do
		if ev.kind == "woke" then
			local r = Mating.woke(life, ev.day :: number)
			if r ~= "" then table.insert(w.log, r .. "@" .. string.format("%d/%.4f", clock.day, clock.hour)) end
		end
	end
end

local function cycleText(w: any): string
	local rec = assert(ObjectRecord.capture({ mating = w.life.mating or {}, mate = w.life.mate or {}, extra = { generation = w.life.generation or 0, day = w.life.clock.day, hour = w.life.clock.hour } }, {}, {}))
	return (assert(Json.canonical(rec)))
end

case("a rest keeps the cycle; a return puts it back and repeats it exactly (nothing rerolled)", function()
	local w = fullWorld()
	-- A cycle partly gone: courted and mated that morning, the sac to be made by the coming sleep, a mate wandering for the next day's checks.
	setClock(w, 3, 17.0)
	w.life.mating = Mating.new()
	w.life.mating.stage, w.life.mating.mates, w.life.mating.visits, w.life.mating.visit_day = "mated", 1, 1, 3
	w.life.generation = 1
	fullTick(w, true) -- rests at 17:00 in the crack by day
	check(w.life.resting and #w.kept == 1, "the rest kept a checkpoint")
	local record = w.kept[1]
	check(#(Checkpoint.check(record, w)) == 0, "a good record")
	local first = {}
	local texts = {}
	-- A sleep that reaches the morning, then the hatch two mornings on: run the same ticks, note everything.
	local function runOn(n: number)
		for k = 1, n do
			fullTick(w)
			if k % 25 == 0 then table.insert(texts, cycleText(w)) end
		end
	end
	setClock(w, 3, 19.0)
	w.life.resting, w.life.asleep = true, false
	runOn(900)
	for _, e in w.log do table.insert(first, e) end
	local firstTexts = texts
	check(w.life.mating.stage == "sac" and w.life.mating.sac_day == 4, `slept through to the morning: the sac is made ({w.life.mating.stage})`)
	check(#first >= 1 and string.sub(first[#first], 1, 3) == "sac", `the log says so ({table.concat(first, ",")})`)
	-- Return to the rest.
	local ok, problems = Checkpoint.restore(record, w)
	check(ok, "restored: " .. table.concat(problems, "; "))
	check(w.life.mating.stage == "mated" and w.life.generation == 1 and w.life.mating.sac_day == 0, "the cycle and the generation went back with it")
	w.log = {}
	texts = {}
	setClock(w, 3, 19.0)
	w.life.resting, w.life.asleep = true, false
	runOn(900)
	local same = #w.log == #first
	for i, e in w.log do if first[i] ~= e then same = false end end
	check(same, `the same events at the same times ({table.concat(w.log, ",")})`)
	local diffs = 0
	for i, t in texts do if firstTexts[i] ~= t then diffs += 1 end end
	check(#texts == #firstTexts and diffs == 0, `and the cycle's records agree at every sample ({diffs} of {#texts} differ)`)
end)

case("a mate on the sill in a rest comes back as it was; the courtship meter and the day's bookkeeping with it", function()
	local w = fullWorld()
	w.life.mating = Mating.new()
	w.life.mating.ready_day = 3
	setClock(w, 3, 9.0)
	local at = Vector3.new(12, 0.31, 6)
	-- the mate is on the sill, a third of the way into the courtship, when the spider (in the crack) rests
	w.life.mate = Mate.new()
	w.life.mate.state, w.life.mate.position, w.life.mate.previous, w.life.mate.meter = "wander", at, at, 0.4
	w.life.mate.sex, w.life.mate.scale = "male", Mate.scaleFor(914, 1, "male")
	w.life.mating.mates, w.life.mating.visits, w.life.mating.visit_day = 1, 1, 3
	fullTick(w, true)
	check(#w.kept == 1, "kept")
	local rec = w.kept[1]
	fullTick(w) -- the rest has sent the mate away
	check(w.life.mate.state == "away", "(resting sends it away)")
	check(Checkpoint.restore(rec, w), "restored")
	check(w.life.mate.state == "wander" and math.abs(w.life.mate.meter - 0.4) < 0.01 and (w.life.mate.position - at).Magnitude < 1e-9 and w.life.mate.sex == "male", `the mate is as it was at the rest ({w.life.mate.state} {w.life.mate.meter})`)
	check(w.life.mating.mates == 1 and w.life.mating.visits == 1 and w.life.mating.visit_day == 3, "and the bookkeeping")
	check(w.life.mating.ready_day == 3, "ready_day is the same")
end)

case("an older record (none of the cycle's fields) restores as nothing going on, generation 0", function()
	local w = fullWorld()
	check(w.life.mating == nil and w.life.mate == nil and w.life.generation == nil, "a new life has none of the fields until the cycle first ticks (an older save never had them)")
	-- take a record that has none of the three fields: capture it from a life that never had them
	local u = fullWorld()
	for _ = 1, 5 do u.sensor:step(DT, u.motor:observer(), u.prey:percepts(), cast); u.motor:tick(STILL) end
	local oldRecord = assert(Checkpoint.capture(u, 0))
	check(oldRecord ~= nil, "an old-shaped record was made")
	local hasField = false
	for _, o in oldRecord.world.objects do
		for _, entry in o.e do
			if entry[1] == "mating" or entry[1] == "mate" or entry[1] == "generation" then hasField = true end
		end
	end
	check(not hasField, "it has no mate, mating or generation field")
	-- Put it into a world that has a cycle going on.
	local target = fullWorld()
	target.life.mating = Mating.new()
	target.life.mating.stage, target.life.mating.sac_day, target.life.mating.guard_day = "sac", 4, 1
	target.life.generation = 2
	local ok, problems = Checkpoint.restore(oldRecord, target)
	check(ok, "restored: " .. table.concat(problems, "; "))
	check(target.life.mating == nil and target.life.mate == nil and target.life.generation == nil, "the fields are gone: nothing going on")
	fullTick(target)
	check(target.life.mating.stage == "none" and Mating.generation(target.life) == 0 and target.life.mate.state == "away", "the next tick: stage none, generation 0, no mate")
end)

case("bad cycle records are refused, and a refusal changes nothing", function()
	local w = fullWorld()
	w.life.mating = Mating.new()
	for _ = 1, 10 do fullTick(w) end
	local good = assert(Checkpoint.capture(w, 0))
	check(#(Checkpoint.check(good, w)) == 0, "the good one")
	local function setField(record: any, root: string, key: string, value: any)
		-- the life object's entry for `key`, or the object it points at
		local lifeIndex = record.world.roots.life["$o"]
		local life = record.world.objects[lifeIndex]
		for _, entry in life.e do
			if entry[1] == key then entry[2] = value; return end
		end
		table.insert(life.e, { key, value })
	end
	local function refused(change: (any) -> (), what: string, expect: string)
		local r = Json.copy(good)
		change(r)
		local before = cycleText(w)
		local ok, problems = Checkpoint.restore(r, w)
		check(not ok and #problems > 0, `{what}: refused`)
		check(string.find(table.concat(problems, "; "), expect, 1, true) ~= nil, `{what}: says '{expect}' ({table.concat(problems, "; ")})`)
		check(cycleText(w) == before, `{what}: nothing changed`)
	end
	local function objectIndexOf(record: any, key: string): number?
		local lifeIndex = record.world.roots.life["$o"]
		for _, entry in record.world.objects[lifeIndex].e do
			if entry[1] == key and type(entry[2]) == "table" then return entry[2]["$o"] end
		end
		return nil
	end
	local function entryOf(record: any, obj: number, key: string): any
		for _, entry in record.world.objects[obj].e do if entry[1] == key then return entry end end
		return nil
	end
	refused(function(r) local i = objectIndexOf(r, "mating") :: number; entryOf(r, i, "stage")[2] = "wedding" end, "an unknown stage", "mating")
	refused(function(r) local i = objectIndexOf(r, "mating") :: number; entryOf(r, i, "visits")[2] = 9 end, "nine mornings for one mate", "mating")
	refused(function(r) local i = objectIndexOf(r, "mate") :: number; entryOf(r, i, "meter")[2] = 2 end, "a meter of 2", "mate")
	refused(function(r) local i = objectIndexOf(r, "mate") :: number; entryOf(r, i, "state")[2] = "dancing" end, "an unknown mate state", "mate")
	refused(function(r) setField(r, "life", "generation", -3) end, "a negative generation", "generation")
	refused(function(r) setField(r, "life", "generation", 0.5) end, "half a generation", "generation")
	refused(function(r) local i = objectIndexOf(r, "mating") :: number; entryOf(r, i, "stage")[2] = "courted" end, "courted, but the pair are not together", "not together")
	-- the hatching is not a place to rest
	local h = fullWorld()
	h.life.mating = Mating.new()
	h.life.mating.stage, h.life.mating.hatch_day, h.life.mating.brood = "hatched", 6, 9
	check(Checkpoint.boundaryProblem(h) == "the brood is hatching", "no rest while the brood is out")
	fullTick(h, true)
	check(h.life.resting and #h.kept == 0 and h.life.checkpointResult ~= nil and not h.life.checkpointResult.ok, "a rest there keeps nothing and says so")
	-- records in every stage restore
	for _, name in Mating.STAGES do
		local v = fullWorld()
		v.life.mating = Mating.new()
		v.life.mating.stage = name
		local mate = Mate.new()
		if name == "courted" then mate.state, mate.position, mate.previous = "pair", Vector3.new(12, 0.31, 6), Vector3.new(12, 0.31, 6) end
		if name == "sac" then v.life.mating.sac_day, v.life.mating.guard_day = 4, 1 end
		if name == "guarding" then v.life.mating.sac_day, v.life.mating.guard_day = 4, 2 end
		if name == "hatched" then v.life.mating.hatch_day, v.life.mating.brood = 6, 10 end
		v.life.mate = mate
		v.life.generation = 3
		local rec = assert(Checkpoint.capture(v, 0))
		check(#(Checkpoint.check(rec, v)) == 0, `a record in the stage {name} is good`)
		local x = fullWorld()
		check(Checkpoint.restore(rec, x) and x.life.mating.stage == name and x.life.generation == 3, `and restores in the stage {name}`)
	end
end)

-- ---------------------------------------------------------------------------------------------------------------- validation
case("records: validation, old records, bad records", function()
	check(#Mating.problems(nil) == 0 and #Mating.problems(Mating.new()) == 0 and #Mating.problems({}) == 0, "none, new, and empty are good (absent fields mean none)")
	for _, name in Mating.STAGES do
		local m = Mating.new()
		m.stage = name
		if name == "sac" then m.sac_day, m.guard_day = 4, 1 elseif name == "guarding" then m.sac_day, m.guard_day = 4, 2 elseif name == "hatched" then m.hatch_day, m.brood = 6, 9 end
		check(#Mating.problems(m) == 0, `stage {name} is good`)
	end
	local function bad(change: (any) -> (), what: string)
		local m = Mating.new()
		change(m)
		check(#Mating.problems(m) > 0, `refused: {what}`)
	end
	bad(function(m) m.stage = "wedding" end, "an unknown stage")
	bad(function(m) m.stage = 3 end, "a stage that is not a word")
	bad(function(m) m.ready_day = -1 end, "a negative day")
	bad(function(m) m.ready_day = 0.5 end, "a fractional day")
	bad(function(m) m.mates = 0 / 0 end, "a nan")
	bad(function(m) m.visits = 4 end, "four mornings for one mate")
	bad(function(m) m.guard_day = 3 end, "a third guard day")
	bad(function(m) m.hatch_hour = 24 end, "an hour of 24")
	bad(function(m) m.brood = 1000 end, "a brood of a thousand")
	bad(function(m) m.stage, m.sac_day, m.guard_day = "sac", 0, 1 end, "a sac with no morning")
	bad(function(m) m.stage, m.sac_day, m.guard_day = "guarding", 4, 1 end, "guarding on the first day")
	bad(function(m) m.stage, m.hatch_day, m.brood = "hatched", 6, 0 end, "a hatching with no brood")
	local m = Mating.new()
	m.stage = "courted"
	local mate = Mate.new()
	check(#Mating.problemsWith(m, mate) > 0, "courted with the mate away")
	mate.state, mate.position = "pair", Vector3.new(10, 0.31, 8)
	check(#Mating.problemsWith(m, mate) == 0, "courted with the pair together")
	m.stage = "none"
	check(#Mating.problemsWith(m, mate) > 0, "together but not courted")
	m.stage, m.sac_day, m.guard_day = "sac", 4, 1
	mate.state = "wander"
	check(#Mating.problemsWith(m, mate) > 0, "a mate on the sill during the guarding")
	-- the mate's record
	local function mbad(change: (any) -> (), what: string)
		local x = Mate.new()
		x.state, x.position = "wander", Vector3.new(10, 0.31, 8)
		change(x)
		check(not Mate.valid(x), `refused: {what}`)
	end
	local ok = Mate.new()
	ok.state, ok.position = "wander", Vector3.new(10, 0.31, 8)
	check(Mate.valid(ok), "a wandering mate is good")
	mbad(function(x) x.state = "flying" end, "an unknown state")
	mbad(function(x) x.meter = 1.5 end, "a meter above 1")
	mbad(function(x) x.meter = -0.1 end, "a negative meter")
	mbad(function(x) x.sex = "other" end, "an unknown sex")
	mbad(function(x) x.scale = 5 end, "a huge scale")
	mbad(function(x) x.reason = "boredom" end, "an unknown reason")
	mbad(function(x) x.elapsed = math.huge end, "an infinite time")
	mbad(function(x) x.leg = -2 end, "a negative leg")
	mbad(function(x) x.position = Vector3.new(0 / 0, 0, 0) end, "a position that is not a number")
	mbad(function(x) x.position = Vector3.new(500, 0, 0) end, "a position outside the sill")
	mbad(function(x) x.position = CRACK end, "a mate in the crack")
	mbad(function(x) x.up = Vector3.new(0, 3, 0) end, "an up that is not a unit")
end)

-- ----------------------------------------------------------------------------------------------------------- the mating scene (ROBLOX-89)
-- Life/MatingScene (the pure plan) and the simulation's side of the scene (Predator/Mate's scene flag, sceneTime and skip, Life/Mating.skip, the checkpoint's refusal).
-- The drawing (camera, cues, captions, locked controls, music) is checked in tests/client_mating.luau.
local function sameVec(a: Vector3, b: Vector3): boolean return (a - b).Magnitude < 1e-9 end

case("the scene's plan: beats, locks, skip, cues", function()
	check(Scene.SECONDS == 15 and Scene.SKIP_AFTER == 4 and Scene.EASE_SECONDS == 0.8 and Scene.ORBIT_DEG == 90, "fifteen seconds, a skip after four, an ease of 0.8 s, a quarter-orbit")
	check(Rules.sceneSeconds == 15 and Rules.pairSeconds == 11 and Rules.stayPairSeconds == 15 and Rules.skipAfter == 4, "the rules say the same: 11 s of pause with a male mate and 15 s with a female, whose walk-off is the rest")
	local want = { { -1, "" }, { 0, "turn" }, { 2.99, "turn" }, { 3, "touch" }, { 6.99, "touch" }, { 7, "settle" }, { 10.99, "settle" }, { 11, "depart" }, { 14.99, "depart" }, { 15, "over" }, { 40, "over" } }
	for _, x in want do check(Scene.beat(x[1] :: number) == x[2], `beat at {x[1]} s is '{x[2]}' (got '{Scene.beat(x[1] :: number)}')`) end
	check(not Scene.locked(-1) and Scene.locked(0) and Scene.locked(14.99) and not Scene.locked(15), "the controls are the scene's from 0 to 15 s")
	check(not Scene.canSkip(0) and not Scene.canSkip(3.99) and Scene.canSkip(4) and Scene.canSkip(14.99) and not Scene.canSkip(15), "a skip from 4 s until the end")
	local c = Scene.cues(2.9, 3.0)
	check(#c == 1 and c[1].name == "meet" and c[1].seconds.male == 4 and c[1].seconds.female == 4 and c[1].at == 3, "the touch cue falls due at 3 s, four seconds long, for both")
	c = Scene.cues(6.9, 7.0)
	check(#c == 1 and c[1].name == "settle" and c[1].seconds.male == 4 and c[1].seconds.female == 8, "the settle cue at 7 s: the male's four seconds (it rises and goes), the female's eight (she stays)")
	check(#Scene.cues(3.0, 7.0) == 1 and Scene.cues(3.0, 7.0)[1].name == "settle", "a cue falls due once: (from, to]")
	c = Scene.cues(-1, 15)
	check(#c == 2 and c[1].name == "meet" and c[2].name == "settle", "a scene entered late gives the cues already passed, in order")
	check(#Scene.cues(7.0, 14.0) == 0 and #Scene.cues(-1, 2.99) == 0, "none between")
end)

case("the scene's plan: seeded, varied, a slow quarter-orbit, static under Reduced Motion", function()
	local a, b = Scene.plan(914, 2, 5, "female"), Scene.plan(914, 2, 5, "female")
	local same = true
	for k, v in a :: any do if (b :: any)[k] ~= v then same = false end end
	check(same, "the same mate on the same day is the same scene")
	check(a.playerSex == "female" and a.mateSex == "male" and Scene.plan(914, 2, 5, "male").mateSex == "female", "the mate is the opposite sex")
	local dirs, sides, turns, jit, elevs, dists = {}, {}, {}, {}, {}, {}
	local inRange = true
	for n = 1, 60 do
		local p = Scene.plan(914, 1 + n % 3, n, "female")
		dirs[p.dir], sides[p.side], turns[p.turnSign] = true, true, true
		jit[math.floor(p.jitterDeg)], elevs[math.floor(p.elevationDeg)] = true, true
		dists[math.floor(p.distanceK * 100)] = true
		if math.abs(p.jitterDeg) > 8 or p.elevationDeg < 28 or p.elevationDeg > 36 or p.distanceK < 0.95 or p.distanceK > 1.05 then inRange = false end
	end
	check(inRange, "the draws stay in their ranges: a sweep within 8 degrees of the side view, 28 to 36 degrees up, a distance within 5%")
	check(dirs[1] and dirs[-1] and sides[1] and sides[-1] and turns[1] and turns[-1], "both ways round, both sides, both turns come up")
	local function size(t: any): number local n = 0; for _ in t do n += 1 end; return n end
	check(size(jit) >= 6 and size(elevs) >= 5 and size(dists) >= 6, "and the numbers vary scene to scene")
	check(Scene.plan(915, 2, 5, "female").jitterDeg ~= a.jitterDeg or Scene.plan(915, 2, 5, "female").dir ~= a.dir, "another world, another scene")
	-- the orbit
	local plan = a
	local centre = math.rad(plan.jitterDeg)
	near(Scene.orbit(plan, 0, false), centre - plan.dir * math.rad(45), 1e-9, "the sweep starts a quarter of a quarter before its centre")
	near(Scene.orbit(plan, 7.5, false), centre, 1e-9, "and is at its centre half way")
	near(Scene.orbit(plan, 15, false), centre + plan.dir * math.rad(45), 1e-9, "and ends the same distance after: ninety degrees in all")
	near(math.abs(Scene.orbit(plan, 15, false) - Scene.orbit(plan, 0, false)), math.rad(90), 1e-9, "a quarter-orbit")
	local mono = true
	local prev = Scene.orbit(plan, 0, false)
	for k = 1, 150 do
		local o = Scene.orbit(plan, k * 0.1, false)
		if (o - prev) * plan.dir < -1e-12 then mono = false end
		prev = o
	end
	check(mono, "it only ever goes one way")
	check(math.abs(Scene.orbit(plan, 0.5, false) - Scene.orbit(plan, 0, false)) < math.abs(Scene.orbit(plan, 8, false) - Scene.orbit(plan, 7.5, false)), "slow at the ends, quickest in the middle")
	local still = true
	for k = 0, 150 do if Scene.orbit(plan, k * 0.1, true) ~= centre then still = false end end
	check(still, "Reduced Motion: no orbit at all, the centre held")
	-- the turn away
	local male, female = Scene.plan(914, 1, 5, "female"), Scene.plan(914, 1, 5, "male")
	check(Scene.turnAway(male, 12.5, false) == 0 and Scene.turnAway(male, 14, true) == 0, "a male mate never turns away")
	check(Scene.turnAway(female, 10.9, false) == 0 and Scene.turnAway(female, 11, false) == 0, "a female mate has not turned before 11 s")
	near(Scene.turnAway(female, 11.75, false), 0.5, 1e-9, "she is half turned at 11.75 s")
	check(Scene.turnAway(female, 12.5, false) == 1 and Scene.turnAway(female, 15, false) == 1, "and has turned by 12.5 s")
	check(Scene.turnAway(female, 11.0, true) == 1 and Scene.turnAway(female, 10.99, true) == 0, "Reduced Motion: at once at 11 s")
	check(Scene.TURN_AWAY_DEG == 110 and Scene.TURN_AWAY_AT == 11 and Scene.TURN_AWAY_SECONDS == 1.5, "110 degrees at 11 s over 1.5 s")
	local pose = Scene.pose(female, 5, false)
	check(pose.beat == "touch" and pose.locked and pose.t == 5 and not pose.over and pose.canSkip, "a pose has the beat, the lock and the skip")
	check(Scene.pose(female, 15, false).over and not Scene.pose(female, 15, false).locked, "over at 15 s")
end)

case("the scene's two-shot: from slightly above, side on, wide enough for the pair", function()
	local plan = Scene.plan(914, 1, 4, "female")
	local a, b, up = Vector3.new(10, 0.31, 8), Vector3.new(12.5, 0.31, 8), Vector3.yAxis
	local s0 = Scene.shot(plan, 0, false, a, b, up)
	check(sameVec(s0.focus, Vector3.new(11.25, 0.31 + Scene.LIFT, 8)), "it looks at the middle of the pair, a little up from the floor")
	near(s0.dir.Magnitude, 1, 1e-9, "the direction from it to the camera is a unit")
	near(s0.dir:Dot(up), math.sin(math.rad(plan.elevationDeg)), 1e-9, "slightly above: the plan's elevation")
	check(s0.dir:Dot(up) > 0.45 and s0.dir:Dot(up) < 0.6, "between 28 and 36 degrees")
	check(s0.distance >= Scene.MIN_DISTANCE * 0.95 - 1e-9, `no nearer than {Scene.MIN_DISTANCE} (x the plan's 5%): {s0.distance}`)
	local wide = Scene.shot(plan, 0, false, a, a + Vector3.xAxis * 9, up)
	check(wide.distance > s0.distance + 5, "a wider pair, a further camera")
	-- side on: at the sweep's centre the camera is across the pair, never behind one
	local mid = Scene.shot(plan, 7.5, false, a, b, up)
	local flatDir = Vector3.new(mid.dir.X, 0, mid.dir.Z).Unit
	check(math.abs(flatDir:Dot(Vector3.xAxis)) <= math.sin(math.rad(8)) + 1e-6, `at the middle of the sweep the camera is across the pair ({flatDir:Dot(Vector3.xAxis)})`)
	local turned = Scene.shot(plan, 15, false, a, b, up)
	check(not sameVec(turned.dir, s0.dir) and math.abs(turned.dir:Dot(s0.dir)) < 1, "and over the scene it goes round")
	local r0, r1 = Scene.shot(plan, 0, true, a, b, up), Scene.shot(plan, 15, true, a, b, up)
	check(sameVec(r0.dir, r1.dir) and r0.distance == r1.distance and sameVec(r0.focus, r1.focus), "Reduced Motion: the same shot all through (static)")
	-- on a wall and with the pair on top of each other
	local wall = Scene.shot(plan, 3, false, Vector3.new(-30, 4, 5), Vector3.new(-30, 4, 7), Vector3.xAxis)
	near(wall.dir:Dot(Vector3.xAxis), math.sin(math.rad(plan.elevationDeg)), 1e-9, "on a wall 'above' is out from the wall")
	local together = Scene.shot(plan, 3, false, a, a, up)
	check(together.dir.Magnitude > 0.99 and together.distance >= 3.9, "two on one spot: still a shot")
	near(s0.up:Dot(up), 1, 1e-9, "and it keeps the floor's up")
end)

-- A world that has courted: the player stands near the mate, the meter fills, the pair are together. `sex` is the player's.
local function together(sex: string?): any
	local w = withMate(sex)
	standNear(w, w.life.mate, 2.5)
	run(w, 8.6)
	assert(w.life.mate.state == "pair", "together")
	return w
end

case("the scene in the simulation: its clock, the pause, the walk off, who stays", function()
	local w = together("female")
	local mate = w.life.mate
	check(mate.scene == true and mate.sex == "male" and Mate.pairLength(mate) == 11, "a male mate: the scene begins with the pair, the pause is 11 s")
	check(Mate.sceneTime(mate) ~= nil and (Mate.sceneTime(mate) :: number) < 1, `scene time starts at the pair ({Mate.sceneTime(mate)})`)
	near(Mate.sceneTime(mate) :: number, mate.elapsed, 1e-9, "and is the pair's own elapsed time while together")
	run(w, 5)
	near(Mate.sceneTime(mate) :: number, mate.elapsed, 1e-9, "(still)")
	local t5 = Mate.sceneTime(mate) :: number
	-- a wasp visit holds the scene as it holds the mate
	w.wasp = true
	run(w, 4)
	near(Mate.sceneTime(mate) :: number, t5, 1e-9, "a wasp visit holds the scene's clock")
	check(mate.state == "pair" and mate.meter == 1, "and the pair")
	w.wasp = false
	run(w, 5.0)
	check(mate.state == "pair", "just short of eleven seconds of scene")
	run(w, 1.0)
	check(mate.state == "leaving" and mate.reason == "mated" and w.life.mating.stage == "mated", "at 11 s of scene the pause ends: mated, the male leaves")
	check(mate.scene == true and Mate.sceneTime(mate) :: number >= 11 and (Mate.sceneTime(mate) :: number) < 12, `and the walk off is the scene's last beat ({Mate.sceneTime(mate)})`)
	check(Mate.valid(mate) and #Mating.problemsWith(w.life.mating, mate) == 0, "a good record there")
	run(w, 3.0)
	check(mate.scene == true, "still the scene at 14 s")
	run(w, 1.2)
	check(mate.scene == false and Mate.sceneTime(mate) == nil, "the scene is over at 15 s")
	check(mate.state == "leaving" or mate.state == "away", "(he is still walking, or gone)")
	-- the female mate (a male player): she stays, the pause is the whole scene
	local m = together("male")
	local fe = m.life.mate
	check(fe.sex == "female" and fe.scene == true and Mate.pairLength(fe) == 15, "a female mate: the pause is the whole fifteen seconds")
	run(m, 13.5)
	check(fe.state == "pair" and fe.scene == true, "together at about 14 s")
	run(m, 1.2)
	check(fe.state == "leaving" and fe.reason == "mated" and fe.scene == false and Mate.sceneTime(fe) == nil and m.life.mating.stage == "mated", "at 15 s the scene and the pause end together")
	-- the cycle after it is the same chain
	setClock(w, 3, 18.5)
	w.life.mate.position = Rules.exitAt
	run(w, 0.2)
	sleepThrough(w)
	check(w.life.mating.stage == "sac" and w.life.mating.sac_day == 4, "the sac is made by the night's sleep as before")
end)

case("skipping the scene: after four seconds, to the parting; a wasp may force it", function()
	local w = together("female")
	local mate = w.life.mate
	run(w, 3.0)
	check(#Mating.skip(w.life) == 0 and mate.state == "pair" and mate.scene == true and w.life.mating.stage == "courted", "a skip before 4 s is nothing")
	run(w, 1.2)
	check((Mate.sceneTime(mate) :: number) >= 4, `(scene time {Mate.sceneTime(mate)})`)
	local ev = Mating.skip(w.life)
	check(#ev == 1 and ev[1] == "mated" and w.life.mating.stage == "mated", "after 4 s it is the mating, at once")
	check(mate.state == "leaving" and mate.reason == "mated" and mate.scene == false and Mate.sceneTime(mate) == nil, "the mate walks off and the scene is over (the departure still happens)")
	check(#Mating.skip(w.life) == 0, "a second skip is nothing")
	mate.position = Rules.exitAt
	run(w, 0.2)
	check(mate.state == "away", "and he is gone off the sill")
	-- the same for the walk off at the end of the male's scene
	local u = together("female")
	run(u, 11.5)
	check(u.life.mate.state == "leaving" and u.life.mate.scene == true, "(in the last beat)")
	check(#Mating.skip(u.life) == 0 and u.life.mate.scene == false and u.life.mate.state == "leaving", "a skip there ends the scene and lets him walk on")
	-- a female mate
	local f = together("male")
	run(f, 6)
	check(#Mating.skip(f.life) == 1 and f.life.mate.state == "leaving" and f.life.mating.stage == "mated", "the same for a female mate")
	-- forced, for a wasp visit
	local x = together("female")
	run(x, 1.0)
	check(#Mating.skip(x.life) == 0 and #Mating.skip(x.life, false) == 0, "not before 4 s, asked nicely")
	check(#Mating.skip(x.life, true) == 1 and x.life.mate.state == "leaving" and x.life.mating.stage == "mated", "but a wasp's visit forces it at any time")
	-- nothing to skip
	local n = withMate()
	check(#Mating.skip(n.life, true) == 0 and #Mating.skip({}, true) == 0 and Mate.skip(nil) == "", "no scene, nothing to skip")
end)

case("the scene's record: validity and old records", function()
	local function mk(state: string, scene: any, reason: string?): any
		local m = Mate.new()
		m.state, m.position, m.previous, m.scene, m.reason = state, Vector3.new(12, 0.31, 6), Vector3.new(12, 0.31, 6), scene, reason or ""
		return m
	end
	check(Mate.valid(mk("pair", true)) and Mate.valid(mk("leaving", true, "mated")) and Mate.valid(mk("pair", false)) and Mate.valid(mk("wander", false)), "a scene in the pair, or in the walk off after the mating: good")
	check(not Mate.valid(mk("wander", true)) and not Mate.valid(mk("leaving", true, "driven")) and not Mate.valid(mk("attend", true)), "a scene in any other state is refused")
	check(not Mate.valid(mk("pair", "yes")) and not Mate.valid(mk("pair", 1)), "and a scene that is not a yes or a no")
	local old = mk("pair", nil)
	check(Mate.valid(old) and Mate.sceneTime(old) == nil, "a record from before the scene has none: good, and no scene")
	check(Mate.new().scene == false and Mate.sceneTime(Mate.new()) == nil, "a new mate has none")
	local m = Mating.new()
	m.stage = "none"
	check(#Mating.problemsWith(m, mk("pair", true)) > 0, "a scene with the cycle not courted or mated is refused")
	m.stage = "courted"
	check(#Mating.problemsWith(m, mk("pair", true)) == 0, "courted: good")
	m.stage = "mated"
	check(#Mating.problemsWith(m, mk("leaving", true, "mated")) == 0, "mated and walking off: good")
end)

case("a rest cannot land inside the scene; the record has no scene to restore into", function()
	local w = fullWorld()
	w.life.mating = Mating.new()
	w.life.mating.stage, w.life.mating.mates, w.life.mating.visits, w.life.mating.visit_day = "courted", 1, 1, 3
	local mate = Mate.new()
	mate.state, mate.position, mate.previous, mate.sex, mate.scene, mate.meter = "pair", Vector3.new(12, 0.31, 6), Vector3.new(12, 0.31, 6), "male", true, 1
	w.life.mate = mate
	check(Checkpoint.boundaryProblem(w) == "the two spiders are together", `a rest is refused while it plays ({Checkpoint.boundaryProblem(w)})`)
	fullTick(w, true)
	check(w.life.resting and #w.kept == 0 and w.life.checkpointResult ~= nil and not w.life.checkpointResult.ok and #w.kept == 0, "a rest there keeps nothing and says so")
	mate.state, mate.reason, mate.elapsed = "leaving", "mated", 0
	w.life.mating.stage = "mated"
	check(Checkpoint.boundaryProblem(w) == "the two spiders are together", "and in the male's walk off, which is the scene's last beat")
	mate.scene = false
	check(Checkpoint.boundaryProblem(w) == "", "when the scene is over a rest keeps its checkpoint again")
	-- a record without the field (all the records there have ever been) restores, with no scene
	mate.state, mate.reason = "pair", ""
	w.life.mating.stage = "courted"
	local rec = assert(Checkpoint.capture(w, 0))
	for _, o in rec.world.objects do
		local keep = {}
		for _, entry in o.e do if entry[1] ~= "scene" then table.insert(keep, entry) end end
		o.e = keep
	end
	local v = fullWorld()
	local ok, problems = Checkpoint.restore(rec, v)
	check(ok, "restored: " .. table.concat(problems, "; "))
	check(v.life.mate.state == "pair" and v.life.mate.scene == nil and Mate.sceneTime(v.life.mate) == nil, "the pair are together with no scene (an older record: the pause is what it was)")
	check(Checkpoint.boundaryProblem(v) == "", "and a rest is not refused for it")
	-- and the pause still ends on its own
	for _ = 1, 60 * 13 do fullTick(v) end
	check(v.life.mate.state ~= "pair", "which ends by its own clock")
end)

-- --------------------------------------------------------------------------------------------------- the audit, part one (ROBLOX-91)
local WaspDirector = require("../src/Shared/Predator/WaspDirector")
local WaspData = require("../src/Shared/Data/Wasp")

case("the eligibility gate says so when it is the hunger: tooHungry (the notice is the client's, with MateText.TOO_HUNGRY)", function()
	local w = newWorld()
	local life = w.life
	life.needs.energy = 0.59
	check(Mating.tooHungry(life), "a full-grown spider at 0.59 is too hungry for a visitor")
	life.needs.energy = 0.6
	check(not Mating.tooHungry(life), "at 0.6 it is not")
	life.needs.energy = 0.3
	life.growth.stage = Growth.ADULT - 1
	check(not Mating.tooHungry(life), "a subadult is not asked for a visitor at all, however hungry")
	life.growth.stage = Growth.ADULT
	life.mating = Mating.new()
	life.mating.ready_day = 4
	check(not Mating.tooHungry(life), "a mate already wanted: nothing to say")
	life.mating.ready_day = 0
	life.mating.stage = "sac"
	check(not Mating.tooHungry(life), "a cycle going: nothing to say")
	life.mating = nil
	check(Mating.tooHungry(life), "no cycle record yet: still hungry")
	-- the words
	local MateText = require("../src/Shared/UI/MateText")
	check(string.find(MateText.TOO_HUNGRY, "Too hungry for a visitor to come", 1, true) ~= nil, "the notice says it")
	-- at a rest by the player: the gate sets nothing, the hunger is reported, and a fed rest later still sets it
	setClock(w, 3, 12)
	w.player.position, w.player.previous = CRACK, CRACK
	life.needs.energy = 0.5
	tick(w, true)
	check(life.resting and life.mating.ready_day == 0 and Mating.tooHungry(life), "the rest at 0.5: no mate wanted, and tooHungry is true for the notice")
	tick(w, false, true)
	life.needs.energy = 0.9
	tick(w, true)
	check(life.mating.ready_day == 4 and not Mating.tooHungry(life), "the next rest, fed, wants the mate and says nothing")
end)

case("the rival keeps away from a courting pair: the scene, the courtship and the sac wait for a clear sill", function()
	local w = withMate()
	local mate = w.life.mate
	check(not Mate.sceneActive(mate) and not Mate.courting(mate, Vector3.new(0, 0.31, 0)), "far from the mate, nothing is going on")
	standNear(w, mate, 2.5)
	check(Mate.courting(mate, w.player.position), "within courting range of a mate that can be courted: courting")
	standNear(w, mate, 3.5)
	check(not Mate.courting(mate, w.player.position), "3.5 studs away with an empty meter: not")
	mate.meter = 0.3
	check(Mate.courting(mate, w.player.position), "a meter that is not empty: courting, even from further off (it decays at 0.25 a second)")
	mate.meter = 0
	standNear(w, mate, 2.5)
	run(w, 8.6)
	check(w.life.mating.stage == "courted" and Mate.sceneActive(mate) and not Mate.courting(mate, w.player.position), "the pair together are the scene, not courting")
	run(w, 11.5)
	check(mate.state == "leaving" and Mate.sceneActive(mate), "the male's walk off the sill is still the scene's last beat")
	run(w, 4.5)
	check(mate.state == "leaving" and mate.scene == false and not Mate.sceneActive(mate), "and when it is over, it is neither")
	check(not Mate.sceneActive(nil) and not Mate.courting(nil, Vector3.zero), "no mate: neither")
end)

case("the scene is skipped at once when the rival is already winding up or lunging as the meter fills", function()
	for _, threat in { false, true } do
		local w = withMate()
		local mate = w.life.mate
		standNear(w, mate, 2.5)
		w.rivalThreat = threat
		run(w, 8.6)
		local events = {}
		for _, x in w.log do table.insert(events, x.e) end
		if threat then
			check(count(w, "courted") == 1 and count(w, "mated") == 1, "the rival is about to strike: courted and mated in the same breath")
			check(w.life.mating.stage == "mated" and mate.state == "leaving" and mate.reason == "mated" and mate.scene == false, "the scene is not played: the pair part and the mate walks off")
			check(not Mate.sceneActive(mate), "no scene is left to hold the player")
			check(Mating.problemsWith(w.life.mating, mate)[1] == nil, "and the record is a good one")
		else
			check(count(w, "courted") == 1 and count(w, "mated") == 0 and mate.state == "pair" and mate.scene == true, "with no rival about, the scene plays as ever")
		end
	end
end)

case("a spiderling of the next generation has its own first day and first meal (grace), for the rival and the wasp", function()
	-- the first generation: the sill's own day and the meals so far
	local w = newWorld()
	local born0, meals0 = Mating.grace(w.life, 7)
	check(born0 == 0 and meals0 == 7, "generation 0: born 0 and every meal counts")
	-- carry on from a hatching on day 6 after nine meals
	w.life.mating = Mating.new()
	w.life.mating.stage, w.life.mating.hatch_day, w.life.mating.brood = "hatched", 6, 9
	Mating.carryOn(w.life, w.needs, 9)
	check(w.life.generation == 1 and w.life.born == 5 and w.life.mealsBase == 9, "carryOn: the generation began on day 6 (born 5) with nine meals already eaten")
	local born, meals = Mating.grace(w.life, 9)
	check(born == 5 and meals == 0, "no meal of its own yet")
	_, meals = Mating.grace(w.life, 11)
	check(meals == 2, "two since")
	local _, early = Mating.grace(w.life, 4)
	check(early == 0, "never below nothing")
	-- the rival: not on the hatching day, not before its first meal; from the second day with a meal
	local function rivalDormant(day: number, mealsEaten: number): boolean
		local r = Rival.new()
		local s = { position = Vector3.new(0, 0.31, 8), previous = Vector3.new(0, 0.31, 8), heading = Vector3.xAxis, day = day, hour = 12, meals = mealsEaten, born = born,
			resting = false, safe = false, wasp = false, gentle = false, grounded = true, moving = false, airborne = false, onLine = false, holding = false, striking = false }
		Rival.step(r, DT, s, function() return false end)
		return r.state == "dormant"
	end
	check(rivalDormant(6, 1), "the hatching day: protected, even with a meal (the sill's day counter says 6)")
	check(rivalDormant(7, 0), "the next day with no meal of its own: protected")
	check(not rivalDormant(7, 1), "the next day with a meal: the rival may come")
	-- the old way, for contrast: nothing in the record means the sill's own day and meals (generation 0)
	local r = Rival.new()
	local s0 = { position = Vector3.new(0, 0.31, 8), previous = Vector3.new(0, 0.31, 8), heading = Vector3.xAxis, day = 7, hour = 12, meals = 1, resting = false, safe = false, wasp = false, gentle = false,
		grounded = true, moving = false, airborne = false, onLine = false, holding = false, striking = false }
	Rival.step(r, DT, s0, function() return false end)
	check(r.state ~= "dormant", "a state with no `born` is the first generation's: no change")
	-- the wasp: Block.born and the block's meals
	local blocked = function(day: number, mealsEaten: number, b: number?): string
		return WaspDirector.blocked(nil, { day = day, hour = 12, resting = false, moulting = false, meals = mealsEaten, born = b })
	end
	check(blocked(6, 1, 5) == "the first day" and blocked(7, 0, 5) == "no meal yet" and blocked(7, 1, 5) == "", "the wasp: protected on the hatching day and before the first meal, then free")
	check(blocked(6, 1) == "" and blocked(1, 1) == "the first day", "and the first generation's rules are as before")
	check(WaspDirector.MAX_SLOTS == #WaspData.game.windows and WaspDirector.MAX_SLOTS == 2, "MAX_SLOTS is the game's windows (two)")
end)

case("the grace is in the checkpoint's life; bad values are refused and an older record has none", function()
	local w = fullWorld()
	w.life.mating = Mating.new()
	for _ = 1, 5 do fullTick(w) end
	w.life.born, w.life.mealsBase = 5, 9
	local good = assert(Checkpoint.capture(w, 0))
	check(#(Checkpoint.check(good, w)) == 0, "a generation's grace is a good record")
	local x = fullWorld()
	check(Checkpoint.restore(good, x) and x.life.born == 5 and x.life.mealsBase == 9, "and restores")
	for _, key in { "born", "mealsBase" } do
		for _, bad in { -1, 0.5, 2e9 } do
			local r = Json.copy(good)
			local life = r.world.objects[r.world.roots.life["$o"]]
			local found = false
			for _, entry in life.e do if entry[1] == key then entry[2] = bad; found = true end end
			check(found, `({key} is in the record)`)
			local problems = Checkpoint.check(r, w)
			check(#problems > 0 and string.find(table.concat(problems, "; "), "invalid " .. key, 1, true) ~= nil, `{key} of {bad} is refused`)
		end
	end
	local plain = fullWorld()
	for _ = 1, 5 do fullTick(plain) end
	local rec = assert(Checkpoint.capture(plain, 0))
	local life = rec.world.objects[rec.world.roots.life["$o"]]
	for _, entry in life.e do check(entry[1] ~= "born" and entry[1] ~= "mealsBase", "a first-generation record has neither") end
	check(#(Checkpoint.check(rec, plain)) == 0 and (select(2, Mating.grace(plain.life, 3))) == 3, "and means the sill's own")
end)

print(`MATING passed={passed} failed={failed}`)
if failed > 0 then error("mating checks failed") end
