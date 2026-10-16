-- LIFE checks: the life clock, the needs and the rest-and-sleep loop of the port against the frozen Godot code.
-- tests/life_reference.json is made by tools/export_life_reference.gd, which runs Godot's own LifeClock, NeedsModel and habitat
-- loop (on a stand-in world); this file replays the same calls through Shared/Life and compares every value. Then the cases of
-- Godot's tests/integration/test_life01_clock_hunger.gd that need no world, ported by hand.
-- Run with the other suites:  python3 tests/run.py path/to/luau life.luau
local LifeClock = require("../src/Shared/Life/LifeClock")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local ref = require("./life_reference")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function near(got: number, want: number, eps: number, what: string)
	check(math.abs(got - want) <= eps, `{what} (got {got}, wanted {want})`)
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function num(x: any): number
	if x == "nan" then return 0 / 0 end
	if x == "inf" then return math.huge end
	if x == "-inf" then return -math.huge end
	return x
end
local EPS = 1e-9

-- ------------------------------------------------------------------------------------------------------------- the clock
case("clock constants", function()
	local c = ref.clock.constants
	near(LifeClock.WAKE_H, c.wake, 0, "wake")
	near(LifeClock.DAWN_H, c.dawn, 0, "dawn")
	near(LifeClock.DUSK_H, c.dusk, 0, "dusk")
	near(LifeClock.NIGHT_H, c.night, 0, "night")
	near(LifeClock.EVENING_H, c.evening, 0, "evening")
	near(LifeClock.START_DAY, c.start_day, 0, "start day")
	near(LifeClock.START_H, c.start_hour, 0, "start hour")
	near(LifeClock.ACTIVE_HOURS_PER_S, c.active_rate, 1e-15, "active rate")
	near(LifeClock.SLEEP_HOURS_PER_S, c.sleep_rate, 0, "sleep rate")
	near(LifeLoop.NIGHT_SIGHT, ref.night_sight, 0, "night sight")
end)

case("clock over the day", function()
	for _, g in ref.clock.grid do
		local c = LifeClock.new()
		c.hour = g.hour
		near(c:daylight(), g.daylight, EPS, `daylight at {g.hour}`)
		check(c:partOfDay() == g.part, `words at {g.hour}: {c:partOfDay()} against {g.part}`)
		check(c:isSleepTime() == g.sleep_time, `sleep time at {g.hour}`)
		near(c:hoursUntil(LifeClock.WAKE_H), g.until_wake, EPS, `hours until waking at {g.hour}`)
		near(c:hoursUntil(LifeClock.DUSK_H), g.until_dusk, EPS, `hours until dusk at {g.hour}`)
	end
end)

case("clock sequences", function()
	for n, seq in ref.clock.sequences do
		local c = LifeClock.new()
		c.day, c.hour = seq.day, seq.hour
		for i, st in seq.steps do
			local s = num(st.seconds)
			local h = if st.op == "m" then c:advanceMoult(s) else c:advance(s, st.asleep)
			local at = `sequence {n} step {i}`
			near(h, st.hours, EPS, `{at}: hours passed`)
			check(c.day == st.day, `{at}: day {c.day} against {st.day}`)
			near(c.hour, st.hour, EPS, `{at}: hour`)
			check(c.sleeping == st.sleeping, `{at}: sleeping`)
			near(c:daylight(), st.daylight, EPS, `{at}: daylight`)
			check(c:partOfDay() == st.part, `{at}: words`)
			check(c:isSleepTime() == st.sleep_time, `{at}: sleep time`)
			near(c:hoursUntil(LifeClock.WAKE_H), st.until_wake, EPS, `{at}: until waking`)
		end
	end
end)

case("a night of sleep tick by tick", function()
	local g = ref.clock.night
	local c = LifeClock.new()
	c.hour = 19.0
	local largest, ticks = 0, 0
	local last = c.hour + 24 * c.day
	while ticks < 5000 do
		c:advance(ref.dt, true)
		ticks += 1
		local now = c.hour + 24 * c.day
		largest = math.max(largest, now - last)
		last = now
		if not c.sleeping then break end
	end
	check(ticks == g.ticks, `ticks {ticks} against {g.ticks}`)
	near(largest, g.largest, EPS, "the largest step")
	check(largest <= LifeClock.SLEEP_HOURS_PER_S * ref.dt + 1e-6, "never more than a tick's worth at a time")
	check(c.day == g.day and math.abs(c.hour - g.hour) < EPS and c.sleeping == g.sleeping, "wakes when Godot does")
end)

case("clock records", function()
	for i, r in ref.clock.records do
		local c = LifeClock.new()
		c.day, c.hour = 5, 12.5
		local got = LifeClock.problems(r.record)
		check(#got == #r.problems, `record {i}: {#got} problems against {#r.problems}`)
		for j, p in r.problems do
			check(got[j] == p, `record {i}: '{tostring(got[j])}' against '{p}'`)
		end
		local loaded = if type(r.record) == "table" then c:load(r.record) else false
		check(loaded == r.loaded, `record {i}: loaded`)
		check(c.day == r.day and c.hour == r.hour and c.sleeping == r.sleeping, `record {i}: the clock after`)
	end
end)

-- ------------------------------------------------------------------------------------------------------------- the needs
local function needsMatch(n: any, g: any, at: string)
	near(n.energy, g.energy, EPS, `{at}: energy`)
	near(n.rest, g.rest, EPS, `{at}: rest`)
	near(n.elapsedS, g.elapsed, EPS, `{at}: elapsed`)
	near(n.grantedTotal, g.granted_total, EPS, `{at}: granted`)
	check(n.grantsMade == g.grants_made and n.grantsRefused == g.grants_refused, `{at}: grants made {n.grantsMade}/{g.grants_made}, refused {n.grantsRefused}/{g.grants_refused}`)
	near(n.starvingHours, g.starving_hours, EPS, `{at}: starving hours`)
	near(n.starvingStreakH, g.streak, EPS, `{at}: starving streak`)
	check(n:isStarving() == g.starving, `{at}: starving`)
	check(n:isFull() == g.full, `{at}: full`)
	near(n:room(), g.room, EPS, `{at}: room`)
	local rec = n:toRecord()
	near(rec.update_accumulator[1], g.acc[1], EPS, `{at}: active accumulator`)
	near(rec.update_accumulator[2], g.acc[2], EPS, `{at}: still accumulator`)
	near(rec.hour_accumulator[1], g.hour_acc[1], EPS, `{at}: waking hours accumulator`)
	near(rec.hour_accumulator[2], g.hour_acc[2], EPS, `{at}: sleeping hours accumulator`)
end

case("needs constants", function()
	local c = ref.needs.constants
	for k, v in {
		max = NeedsModel.ENERGY_MAX, start = NeedsModel.ENERGY_START, drain = NeedsModel.ENERGY_DRAIN_PER_S, floor = NeedsModel.ENERGY_FLOOR,
		rest_start = NeedsModel.REST_START, rest_drain = NeedsModel.REST_DRAIN_PER_S, rest_recover = NeedsModel.REST_RECOVER_PER_S,
		period = NeedsModel.UPDATE_PERIOD_S, max_step = NeedsModel.MAX_STEP_S, full_at = NeedsModel.FULL_AT,
		awake_per_h = NeedsModel.LIFE_DRAIN_AWAKE_PER_H, asleep_per_h = NeedsModel.LIFE_DRAIN_ASLEEP_PER_H,
		gentle_drain = NeedsModel.GENTLE_DRAIN, gentle_floor = NeedsModel.GENTLE_FLOOR,
	} do
		near(v, c[k], 0, k)
	end
end)

case("needs sequences", function()
	for n, seq in ref.needs.sequences do
		local m = NeedsModel.new(seq.life, seq.gentle)
		for i, st in seq.steps do
			local v = num(st.value)
			local ret = 0
			if st.op == "adv" then m:advance(v, st.flag)
			elseif st.op == "hrs" then m:addHours(v, st.flag)
			elseif st.op == "grant" then ret = m:grantEnergy(v, st.flag)
			elseif st.op == "rest" then m:restoreRest(v)
			elseif st.op == "cfg" then m:configure({ energy = v, rest = num(st.flag) }) end
			local at = `sequence {n} step {i} ({st.op})`
			near(ret, st.returned, EPS, `{at}: returned`)
			needsMatch(m, st, at)
		end
	end
end)

case("needs at 60 ticks a second", function()
	local m = NeedsModel.new()
	local k = 0
	for i = 0, 599 do
		m:advance(ref.dt, (i // 45) % 2 == 0)
		if i % 30 == 29 then
			k += 1
			needsMatch(m, ref.needs.ticks[k], `tick {i}`)
		end
	end
	check(k == #ref.needs.ticks, "every sample compared")
end)

case("needs records", function()
	for _, r in ref.needs.records do
		local m = NeedsModel.new()
		local ok = m:load(r.record)
		check(ok == r.loaded, `{r.name}: loaded {ok} against {r.loaded}`)
		needsMatch(m, r.after, r.name)
		check(m.lifeMode == r.life, `{r.name}: life mode`)
	end
	-- And what the port writes, the port reads back exactly.
	local a = NeedsModel.new(true)
	a:configure({ energy = 0.4, rest = 0.7 })
	a:grantEnergy(0.1, "x")
	a:advance(0.2, true)
	a:addHours(1.5, false)
	local b = NeedsModel.new()
	check(b:load(a:toRecord()), "a written record loads")
	check(b.energy == a.energy and b.rest == a.rest and b.lifeMode and b:grantedFrom("x") == a:grantedFrom("x"), "with the same numbers")
	a:advance(0.3, false)
	b:advance(0.3, false)
	check(a.energy == b.energy and a.rest == b.rest, "and goes on the same way")
end)

-- ------------------------------------------------------------------------------------------------------------- the loop
case("the loop against Godot's habitat loop", function()
	for _, sc in ref.loops do
		current = sc.name
		local needs = NeedsModel.new(true)
		needs:configure({ energy = sc.energy })
		local saved = 0
		local loop = LifeLoop.new(needs, function()
			saved += 1
			return { ok = true, message = "Checkpoint kept." }
		end)
		loop.clock.day, loop.clock.hour = sc.day, sc.hour
		for _, g in sc.ticks do
			local s = { inRetreat = g.inside, attached = not g.airborne, still = not g.moving, holding = g.held, feeding = g.feeding }
			local active = g.airborne or g.moving
			needs:advance(ref.dt, active)
			local before = loop.notice
			loop:step(ref.dt, s, g.interact, g.cancel)
			local at = `tick {g.t}`
			check(loop.clock.day == g.day, `{at}: day {loop.clock.day} against {g.day}`)
			near(loop.clock.hour, g.hour, EPS, `{at}: hour`)
			check(loop.clock.sleeping == g.sleeping, `{at}: clock sleeping`)
			check(loop.asleep == g.asleep, `{at}: asleep {loop.asleep} against {g.asleep}`)
			check(loop.resting == g.resting, `{at}: resting {loop.resting} against {g.resting}`)
			near(loop.restSeconds, g.rest_seconds, EPS, `{at}: rest seconds`)
			near(needs.energy, g.energy, EPS, `{at}: energy`)
			near(needs.rest, g.rest, EPS, `{at}: rest`)
			near(loop.rangeScale, g.range, EPS, `{at}: reach of the eyes`)
			near(loop.daylight, g.light, EPS, `{at}: daylight`)
			check(saved == g.checkpoints and loop.checkpoints == g.checkpoints, `{at}: checkpoints {saved} against {g.checkpoints}`)
			-- Godot's record names the notice when it changed (and on the first tick of each phase); otherwise it stayed.
			if g.notice ~= "" then
				check(loop.notice == g.notice, `{at}: notice '{loop.notice}' against '{g.notice}'`)
			else
				check(loop.notice == before, `{at}: the notice changed to '{loop.notice}' where Godot's did not`)
			end
			near(loop.noticeSeconds, g.notice_seconds, EPS, `{at}: notice time`)
			check(loop:canRest(s) == g.can_rest, `{at}: can rest`)
		end
	end
end)

-- ------------------------------------------------------------------------------------------------------------- by hand
-- The cases of Godot's test_life01_clock_hunger.gd that need no world.
case("the day passes with action time", function()
	local c = LifeClock.new()
	check(c.day == 1 and c.hour == 9.0, "day 1, 9 in the morning")
	near(c:advance(60, false), 60 * LifeClock.ACTIVE_HOURS_PER_S, 1e-12, "a minute of play")
	check(c:advance(-1, false) == 0 and c:advance(0 / 0, false) == 0, "no time from nonsense")
	c.hour = 23.9
	c:advance(0.2 / LifeClock.ACTIVE_HOURS_PER_S, false)
	check(c.day == 2 and c.hour < 0.2, "midnight turns the day")
	-- 120 ticks: the same game time at any frame rate (the client always steps whole fixed ticks).
	local l = LifeLoop.new(NeedsModel.new(true))
	local start = l.clock.hour
	local away = { inRetreat = false, attached = true, still = true, holding = false, feeding = false }
	for _ = 1, 120 do l:step(1 / 60, away, false, false) end
	near(l.clock.hour - start, 120 / 60 * LifeClock.ACTIVE_HOURS_PER_S, 1e-9, "120 ticks")
end)

case("daylight and the words for the day", function()
	local c = LifeClock.new()
	c.hour = 12
	check(c:daylight() == 1 and c:partOfDay() == "midday", "noon")
	c.hour = 0.5
	check(c:daylight() == 0 and c:partOfDay() == "night", "past midnight")
	c.hour = 19.75
	check(c:daylight() > 0.05 and c:daylight() < 0.95 and c:partOfDay() == "evening", "dusk")
	c.hour = 6.5
	check(c:daylight() > 0 and c:daylight() < 0.5 and c:isSleepTime(), "dawn, still sleep time")
	c.hour = 10
	check(not c:isSleepTime(), "10 is not sleep time")
end)

case("hunger runs by the hour and can run out", function()
	local function period(n: any)
		n:advance(NeedsModel.MAX_STEP_S, false)
		n:advance(NeedsModel.UPDATE_PERIOD_S - NeedsModel.MAX_STEP_S, false)
	end
	local n = NeedsModel.new(true)
	n:configure({ energy = 0.6 })
	n:addHours(10, false)
	period(n)
	near(n.energy, 0.6 - 10 * NeedsModel.LIFE_DRAIN_AWAKE_PER_H, 1e-9, "ten waking hours")
	local e = n.energy
	n:addHours(10, true)
	period(n)
	near(n.energy, e - 10 * NeedsModel.LIFE_DRAIN_ASLEEP_PER_H, 1e-9, "ten hours asleep use a third as much")
	n:addHours(100, false)
	period(n)
	check(n.energy == 0 and n:isStarving() and n.starvingHours > 50, "the reserve can run out, and the hours are counted")
	check(n:grantEnergy(0.35, "fly_1") > 0 and not n:isStarving() and n.starvingStreakH == 0, "a meal ends it")
	local legacy = NeedsModel.new()
	legacy:addHours(100, false)
	period(legacy)
	check(legacy.energy > NeedsModel.ENERGY_START - 0.01, "without life mode the old slow drain is unchanged")
end)

case("the reach of the eyes follows the hour", function()
	local l = LifeLoop.new(NeedsModel.new(true))
	l.clock.hour = 12
	l:applyLight()
	near(l.rangeScale, 1, 1e-12, "full range at noon")
	l.clock.hour = 23
	l:applyLight()
	near(l.rangeScale, LifeLoop.NIGHT_SIGHT, 1e-12, "a third at night")
	l.clock.hour = 19.75
	l:applyLight()
	check(l.rangeScale > LifeLoop.NIGHT_SIGHT and l.rangeScale < 1, "between at dusk")
end)

case("loop records", function()
	local needs = NeedsModel.new(true)
	local l = LifeLoop.new(needs, function() return { ok = true, message = "kept" } end)
	l.clock.day, l.clock.hour = 3, 15.25
	local home = { inRetreat = true, attached = true, still = true, holding = false, feeding = false }
	l:step(1 / 60, home, true, false)
	local r = l:toRecord()
	check(#LifeLoop.problems(r) == 0, "a written record is good")
	local m = LifeLoop.new(NeedsModel.new(true))
	check(m:load(r), "and loads")
	check(m.clock.day == 3 and math.abs(m.clock.hour - 15.25) < 0.01 and m.resting, "day 3, a quarter past three, still resting")
	check(m.notice:find("checkpoint recovery") ~= nil, "the screen says it is checkpoint recovery, not an exact resume")
	-- The restored rest is not ended while the spider takes hold again (Godot's grace).
	m:step(1 / 60, { inRetreat = true, attached = false, still = true, holding = false, feeding = false }, false, false)
	check(m.resting, "the rest survives the first ticks after a restore")
	local bad = table.clone(r)
	bad.life = { day = 3, hour = 30, sleeping = false }
	check(#LifeLoop.problems(bad) > 0 and not m:load(bad), "an impossible hour is refused")
	check(m.clock.day == 3, "and changes nothing")
	check(#LifeLoop.problems("nope") > 0 and #LifeLoop.problems({}) > 0, "nothing else is a record")
	local noSave = LifeLoop.new(NeedsModel.new(true))
	noSave:step(1 / 60, home, true, false)
	check(noSave.resting and noSave.checkpoints == 0 and noSave.notice:find("not kept") ~= nil, "without a store the rest still begins, and says no checkpoint was kept")
end)

print(`LIFE passed={passed} failed={failed}`)
if failed > 0 then error("LIFE failed") end
