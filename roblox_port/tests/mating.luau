-- The mating cycle and the new generation (ROBLOX-79): Data/MatingRules, Predator/Mate (the mate's body and the courtship meter), Life/Mating (the cycle, the
-- guard days, the hatching and the next generation) and Predator/MateDrive (the mate's legs, on the rival's drive). Simulated in the life/rival tests' style:
-- a real LifeLoop and clock driven tick by tick through the nights, a synthetic player standing where the test puts it, the real checkpoint records. Not
-- engine evidence (no Studio): the drawing, the scene and the sounds are checked in tests/client_mating.luau and are not seen here.
-- Run with the other suites:  python3 tests/run.py path/to/luau mating.luau
local Rules = require("../src/Shared/Data/MatingRules")
local RivalRules = require("../src/Shared/Data/RivalRules")
local Mate = require("../src/Shared/Predator/Mate")
local Mating = require("../src/Shared/Life/Mating")
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
	run(w, 4.3)
	check(life.mating.stage == "courted", "the pause together is five seconds")
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
	s.drive = w.legs
	local events = Mating.tick(w.life, DT, s)
	for _, e in events do table.insert(w.log, { e = e, day = s.day, hour = s.hour }) end
	w.legs:update(w.life.mate, DT, s)
	w.life:step(DT, { inRetreat = Layout.inRetreat(w.player.position), attached = true, still = true, holding = false, feeding = false, position = w.player.position }, false, false)
	w.life:drainEvents()
end

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
	for _ = 1, 60 * 8 do walkTick(mover) end
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

print(`MATING passed={passed} failed={failed}`)
if failed > 0 then error("mating checks failed") end
