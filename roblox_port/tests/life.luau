-- LIFE checks: the life clock, the needs and the rest-and-sleep loop of the port against the frozen Godot code.
-- tests/life_reference.json is made by tools/export_life_reference.gd, which runs Godot's own LifeClock, NeedsModel and habitat
-- loop (on a stand-in world); this file replays the same calls through Shared/Life and compares every value. Then the cases of
-- Godot's tests/integration/test_life01_clock_hunger.gd that need no world, ported by hand.
-- Run with the other suites:  python3 tests/run.py path/to/luau life.luau
local LifeClock = require("../src/Shared/Life/LifeClock")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local Growth = require("../src/Shared/Life/Growth")
local DayLight = require("../src/Shared/Habitat/DayLight")
local LifeText = require("../src/Shared/UI/LifeText")
local Graphics = require("../src/Shared/Data/Graphics")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
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

-- ------------------------------------------------------------------------------------------------------------- light, words
case("full daylight is exactly the daytime look", function()
	local t = DayLight.targets(1, 9.75)
	local L, A = Graphics.lighting, Graphics.atmosphere
	check(t.clock == 9.75 and t.brightness == L.brightness and t.exposure == L.exposureCompensation, "sun, brightness, exposure")
	for i = 1, 3 do
		check(t.ambient[i] == L.ambient[i] and t.outdoorAmbient[i] == L.outdoorAmbient[i] and t.colorShiftTop[i] == L.colorShiftTop[i], `light colours {i}`)
		check(t.atmosphereColor[i] == A.color[i] and t.atmosphereDecay[i] == A.decay[i], `haze colours {i}`)
	end
	check(t.sunRays == Graphics.sunRays.intensity and t.shafts == 1 and t.motes == 1, "rays, shafts, motes")
	local hour9 = LifeClock.new() -- the game starts at 9 in the morning: full day
	check(hour9:daylight() == 1, "the start of the game is full day")
end)

case("night is dim and blue, never black, with the sun below the horizon", function()
	local N = Graphics.dayNight
	local t = DayLight.targets(0, 9.75)
	check(t.clock == N.nightClock and t.brightness == N.brightness and t.exposure == N.exposureCompensation, "night values")
	check(t.sunRays == 0 and t.shafts == 0 and t.motes == N.motesAtNight, "no rays or shafts, faint motes")
	check(t.ambient[3] > t.ambient[1] and t.outdoorAmbient[3] > t.outdoorAmbient[1], "blue")
	check(t.ambient[1] + t.ambient[2] + t.ambient[3] > 60 and t.outdoorAmbient[1] + t.outdoorAmbient[2] + t.outdoorAmbient[3] > 120, "not black")
	check(N.nightClock < 5.5, "the night clock is before Roblox's sunrise (about 6)")
	-- Dusk: everything moves one way as daylight falls; the sun sinks before the last light goes.
	local last = DayLight.targets(1, 9.75)
	for k = 39, 0, -1 do
		local d = k / 40
		local cur = DayLight.targets(d, 9.75)
		check(cur.clock <= last.clock and cur.brightness <= last.brightness and cur.ambient[1] <= last.ambient[1] and cur.sunRays <= last.sunRays, `dusk at {d}`)
		last = cur
	end
	check(DayLight.targets(0.3, 9.75).clock < 6, "below the horizon by daylight 0.3")
	check(DayLight.targets(0 / 0, 9.75).daylight == 1 and DayLight.targets(-1, 9.75).daylight == 0 and DayLight.targets(2, 9.75).daylight == 1, "nonsense is clamped")
	-- A low sun is warmer.
	check(DayLight.targets(0.2, 9.75).colorShiftTop[3] < Graphics.lighting.colorShiftTop[3], "a low sun is warm")
end)

case("the light is set again only when it has changed enough", function()
	check(DayLight.due(nil, 1), "first time")
	check(not DayLight.due(1, 1) and not DayLight.due(0.5, 0.5 + Graphics.dayNight.applyStep / 2), "not for a small change")
	check(DayLight.due(0.5, 0.5 + Graphics.dayNight.applyStep), "for a step")
	check(DayLight.due(0.9995, 1) and DayLight.due(0.0005, 0), "always on reaching day or night")
end)

case("DayLight.apply sets only what it owns", function()
	local function node(class: string, name: string): any
		local n: any = { ClassName = class, Name = name, children = {} }
		function n.IsA(self: any, c: string) return self.ClassName == c end
		function n.FindFirstChild(self: any, nm: string, deep: boolean?)
			for _, c in self.children do
				if c.Name == nm then return c end
				if deep then local f = c:FindFirstChild(nm, true); if f then return f end end
			end
			return nil
		end
		function n.GetDescendants(self: any)
			local out = {}
			for _, c in self.children do table.insert(out, c); for _, d in c:GetDescendants() do table.insert(out, d) end end
			return out
		end
		return n
	end
	local lighting = node("Lighting", "Lighting")
	local atm, rays, eyeGrade, dof, grade = node("Atmosphere", "Atmosphere"), node("SunRaysEffect", "SunRays"), node("ColorCorrectionEffect", "EyeGrade"), node("DepthOfFieldEffect", "MacroDOF"), node("ColorCorrectionEffect", "Grade")
	eyeGrade.Saturation, dof.FocusDistance, grade.Brightness = 0.25, 3, 0
	lighting.children = { atm, rays, eyeGrade, dof, grade }
	local decor = node("Folder", "Decor")
	local shafts, anchor, beam = node("Folder", "Shafts"), node("Part", "ShaftAnchor1"), node("Beam", "Shaft1_1")
	local dust, motes = node("Part", "Dust"), node("ParticleEmitter", "Motes")
	anchor.children = { beam }; shafts.children = { anchor }; dust.children = { motes }; decor.children = { shafts, dust }
	DayLight.apply(lighting, DayLight.targets(0, 9.75), decor)
	check(lighting.ClockTime == Graphics.dayNight.nightClock and lighting.Brightness == Graphics.dayNight.brightness, "the sun and its strength")
	check(lighting.Ambient ~= nil and lighting.OutdoorAmbient ~= nil and lighting.ColorShift_Top ~= nil and lighting.ExposureCompensation ~= nil, "the room's light")
	check(atm.Color ~= nil and atm.Decay ~= nil and rays.Intensity == 0, "haze and rays")
	check(beam.Enabled == false and beam.Brightness == 0 and motes.Brightness == Graphics.dayNight.motesAtNight, "shafts off, motes faint")
	check(eyeGrade.Saturation == 0.25 and dof.FocusDistance == 3 and grade.Brightness == 0, "the eye view's effects and the grade untouched")
	DayLight.apply(lighting, DayLight.targets(1, 9.75), nil)
	check(lighting.ClockTime == 9.75 and lighting.Brightness == Graphics.lighting.brightness, "back to day")
	local bare = node("Lighting", "Lighting")
	DayLight.apply(bare, DayLight.targets(0.5, 9.75), nil) -- the low tier: no rays, no shafts; nothing to fail on
	check(bare.ClockTime ~= nil, "a lighting without the extras")
end)

case("the words for the day and the retreat", function()
	check(LifeText.day(2, "evening") == "Day 2, evening", "the day")
	check(LifeText.line("midday", 0.5, false, false, 0.25) == nil, "nothing to say at midday")
	check(LifeText.line("evening", 0.5, false, false, 0.25) == "Evening. Jumping spiders go into their silk retreat before dark.", "evening")
	check(string.find(LifeText.line("night", 0.5, false, false, 0.25) or "", "dark", 1, true) ~= nil, "night")
	check(LifeText.line("night", 0.2, false, false, 0.25) == "Hungry: time to hunt.", "hunger before the time of day")
	check(string.find(LifeText.line("night", 0, true, false, 0.25) or "", "Starving", 1, true) ~= nil, "starving first")
	check(LifeText.line("midday", 0.05, true, true, 0.25) == "Hungry: time to hunt.", "gentle rules never say starving")
	local p = LifeText.prompt(false, false, true, false, "keyboard")
	check(p ~= nil and p.hint == "E: rest", "rest by day")
	p = LifeText.prompt(false, false, true, true, "gamepad")
	check(p ~= nil and p.hint == "Left-stick click: sleep until morning", "sleep, on a controller")
	p = LifeText.prompt(true, true, true, true, "keyboard")
	check(p ~= nil and p.title == "Asleep in the silk-lined crack" and string.find(p.hint, "E or Q to wake", 1, true) ~= nil, "asleep")
	p = LifeText.prompt(false, true, true, false, "touch")
	check(p ~= nil and string.find(p.hint, "Eat or Cancel to leave", 1, true) ~= nil, "resting, on touch")
	check(LifeText.prompt(false, false, false, true, "keyboard") == nil, "nothing outside the crack")
	check(LifeText.touchLabel(false, false, true, false) == "Rest" and LifeText.touchLabel(false, false, true, true) == "Sleep", "touch: rest, sleep")
	check(LifeText.touchLabel(true, true, true, true) == "Wake" and LifeText.touchLabel(false, true, true, false) == "Leave", "touch: wake, leave")
	check(LifeText.touchLabel(false, false, false, false) == nil, "touch: not the retreat's")
end)

case("the silk-lined crack", function()
	check(Layout.inRetreat(Vector3.new(-25.5, 0.31, 6)), "the middle of the crack")
	check(Layout.inRetreat(Layout.RETREAT_MIN) and Layout.inRetreat(Layout.RETREAT_MAX), "its edges")
	check(not Layout.inRetreat(Vector3.new(-20, 0.31, 6)) and not Layout.inRetreat(Vector3.new(-25.5, 2, 6)), "not the open sill, not above it")
	check(not Layout.inRetreat(Layout.SPAWN), "the spawn is not in the crack")
end)

case("the game's hunger factor (ROBLOX-78, ROBLOX-88): 1.9, a day costs about 0.61 of the reserve, in every mode, and Godot's defaults are untouched",function()
 check(NeedsModel.game.drain==1.9 and NeedsModel.PLAY_DRAIN==1.9,"the factor is 1.9 (it was 1.55, 1.1 before that)")
 -- Worked from the constants: 11 waking hours at 0.021 and 13 asleep at 0.007 cost 0.322 at factor 1.
 local base=11*NeedsModel.LIFE_DRAIN_AWAKE_PER_H+13*NeedsModel.LIFE_DRAIN_ASLEEP_PER_H
 check(math.abs(base-0.322)<1e-12,"a day at factor 1 costs 0.322")
 check(math.abs(base*NeedsModel.game.drain-0.612)<0.001,"a day at the game's factor costs 0.612 ("..string.format("%.4f",base*NeedsModel.game.drain)..")")
 check(math.abs(base*1.55-0.499)<0.001,"it was 0.499 at 1.55")
 check(math.abs(11*NeedsModel.LIFE_DRAIN_AWAKE_PER_H*1.9-0.439)<0.001 and math.abs(13*NeedsModel.LIFE_DRAIN_ASLEEP_PER_H*1.9-0.173)<0.001,"0.439 awake and 0.173 asleep")
 check(math.abs(base*1.1-0.354)<0.001,"it was 0.354 at 1.1")
 local g=NeedsModel.new(true,false);local d=NeedsModel.new(true,false)
 check(d.drainScale==nil and g.drainScale==nil,"a model starts with Godot's rules")
 g:useGameRules()
 check(g.drainScale==NeedsModel.game.drain and d.drainScale==nil,"useGameRules gives only that model the game's factor")
 for _,gentle in {false,true} do
  for _,asleep in {false,true} do
   local old=NeedsModel.new(true,gentle);local tuned=NeedsModel.new(true,gentle)
   tuned:useGameRules()
   old:addHours(10,asleep);tuned:addHours(10,asleep)
   for _=1,2 do old:advance(.25,false);tuned:advance(.25,false) end
   -- (ROBLOX-91: the gentle modes have their own factor, 1.1, instead of 1.9)
   check(math.abs((.55-tuned.energy)/(.55-old.energy)-(if gentle then 1.1 else 1.9))<1e-8,`{if gentle then "1.1" else "1.9"} times the drain, awake or asleep, {if gentle then "gentle" else "standard"}`)
  end
 end
 -- A whole simulated day: 11 hours awake, 13 asleep, from a full reserve.
 local n=NeedsModel.new(true,false);n:useGameRules();n.energy=1
 for _=1,11 do n:addHours(1,false);for _=1,2 do n:advance(.25,false) end end
 for _=1,13 do n:addHours(1,true);for _=1,2 do n:advance(.25,false) end end
 check(math.abs((1-n.energy)-0.612)<0.002,"a played day takes about 0.61 ("..string.format("%.4f",1-n.energy)..")")
 check(math.abs(1/(1-n.energy)-1.63)<0.01,"a full reserve lasts about 1.63 days")
 -- The pace is two meals a day just to hold steady: a housefly gives 0.35, a fruit fly 0.175, and a daily rival 0.7 is about a day (1.14) and a surplus of 0.09.
 local day=1-n.energy
 check(2*0.35>=day and 0.35<day and 0.7>day and 0.7<2*day,"two house flies cover a day (0.7 against 0.61); one does not; the rival is about a day and 1/7")
 check(0.7-day>0 and 0.7-day<0.1,"the daily rival leaves a surplus of under 0.1 ("..string.format("%.3f",0.7-day)..") and the flies for growth must come on top")
end)
case("the gentle modes' own hunger (ROBLOX-91): 1.1 instead of 1.9, about 0.177 a day as ROBLOX-61 had it, whichever order the rules and the flag are set",function()
 check(NeedsModel.game.gentleDrain==1.1 and NeedsModel.GENTLE_DRAIN==0.5 and NeedsModel.game.drain==1.9,"the numbers: gentle 1.1 (x 0.5), standard 1.9")
 local base=11*NeedsModel.LIFE_DRAIN_AWAKE_PER_H+13*NeedsModel.LIFE_DRAIN_ASLEEP_PER_H
 local function played(n:any):number
  n.energy=1
  for _=1,11 do n:addHours(1,false);for _=1,2 do n:advance(.25,false) end end
  for _=1,13 do n:addHours(1,true);for _=1,2 do n:advance(.25,false) end end
  return 1-n.energy
 end
 local table_={}
 for _,c in {{"standard",false,0.612},{"gentle",true,0.177}} do
  local n=NeedsModel.new(true,c[2]);n:useGameRules()
  local d=played(n);table_[c[1]]=d
  check(math.abs(d-c[3])<0.002,`{c[1]}: a played day takes {string.format("%.4f",d)} (about {c[3]})`)
 end
 check(math.abs(base*1.1*0.5-0.177)<0.0005 and math.abs(base*1.9-0.612)<0.001,"worked from the constants: 0.322 x 1.1 x 0.5 and 0.322 x 1.9")
 check(table_.gentle<table_.standard/3 and table_.gentle>0.15,"a gentle day is under a third of a standard one (ROBLOX-61's pace, not the half of ROBLOX-88's 0.306)")
 -- the flag set after the rules, and before (the client sets both, in either order)
 local a=NeedsModel.new(true,false);a:useGameRules();a.gentle=true
 local b=NeedsModel.new(true,true);b:useGameRules()
 check(math.abs(played(a)-played(b))<1e-12 and a:drainFactor()==1.1 and b:drainFactor()==1.1,"set after the rules or before: the same gentle factor")
 a.gentle=false;check(a:drainFactor()==1.9,"and back to the standard one")
 check(NeedsModel.new(true,true):drainFactor()==1 and NeedsModel.new(true,false):drainFactor()==1,"a model never given the rules is Godot's (factor 1) in both modes")
 -- gentle still has its floor and never starves
 local g=NeedsModel.new(true,true);g:useGameRules();g:addHours(400,false);for _=1,4 do g:advance(.25,false) end
 check(math.abs(g.energy-NeedsModel.GENTLE_FLOOR)<1e-9 and g.starvingHours==0,"gentle keeps its floor of 0.1 and starves no hours")
end)
case("the starving streak (ROBLOX-91): Godot's rule resets it at any meal; the game's eases it by the hours a meal covers",function()
 local function starving(game:boolean):any
  local n=NeedsModel.new(true,false);if game then n:useGameRules() end
  n:configure({energy=0.001});n:addHours(40,false);for _=1,2 do n:advance(.25,false) end
  return n
 end
 local godot=starving(false)
 check(godot.starvingStreakH>36 and godot.energy==0,`starving at 0% for hours ({godot.starvingStreakH})`)
 check(godot:grantEnergy(0.01,"a")>0 and godot.starvingStreakH==0,"Godot's rule, the default: the tiniest meal ends the streak")
 local n=starving(true)
 local before=n.starvingStreakH
 local rate=NeedsModel.LIFE_DRAIN_AWAKE_PER_H*1.9
 check(before>4*0.9 and n.energy==0,`the same, with the game's hunger: {before} hours`)
 local added=n:grantEnergy(0.05,"b")
 check(math.abs(added-0.05)<1e-12 and math.abs(n.starvingStreakH-(before-0.05/rate))<1e-9,`a tiny meal (0.05) at 0% covers {0.05/rate} hours: the streak {before} becomes {n.starvingStreakH}`)
 check(n.energy<0.1 and n.starvingStreakH>0,"the reserve is still under 0.1: the streak goes on")
 -- one tiny catch a day at 0% energy does not keep it alive for ever: the streak climbs to 24 (too weak to sleep) and 48 (starved)
 local m=NeedsModel.new(true,false);m:useGameRules();m:configure({energy=0.001})
 local died,day=nil,0
 local loop=LifeLoop.new(m)
 for d=1,10 do
  day=d
  m:addHours(11,false);m:addHours(13,true);for _=1,2 do m:advance(.25,false) end -- (a day with nothing)
  m:grantEnergy(0.04,`tiny{d}`)
  if loop:starved() then died=d break end
 end
 check(died~=nil and died<=4,`a spider fed one tiny catch (0.04) a day at 0% starves anyway (day {tostring(died)})`)
 -- a real meal ends it altogether: the reserve is above 0.1
 local k=starving(true);local was=k.starvingStreakH
 check(k:grantEnergy(0.35,"fly")>0 and k.starvingStreakH==0 and was>0,"a housefly (0.35) ends it")
 local j=starving(true)
 j:grantEnergy(0.095,"just under");check(j.starvingStreakH>0,"0.095 does not")
 j:grantEnergy(0.02,"over");check(j.energy>0.1 and j.starvingStreakH==0,"and rising above 0.1 does")
 -- it never goes negative
 local z=starving(true);z.starvingStreakH=0.2;z:grantEnergy(0.05,"z");check(z.starvingStreakH==0,"a small streak is eased to nothing, never below it")
 -- the rule is not part of the record, and a model without it replays Godot (the reference fixtures hold: tests above)
 local rec=starving(true):toRecord()
 local back=NeedsModel.new(true,false);check(back:load(rec) and back.streakDecay==nil,"a model restored by record is Godot's until the rules are given again")
end)
case("the hunger bar's words (ROBLOX-78): full when fed, 'Hunger', hungry and starving, gentle",function()
 check(LifeText.hunger(1,false)=="Hunger 100%" and LifeText.hunger(0.55,false)=="Hunger 55%","fed: Hunger and the percent")
 check(LifeText.hunger(0.25,false)=="Hunger 25% · hungry" and LifeText.hunger(0.26,false)=="Hunger 26%","hungry at a quarter")
 check(LifeText.hunger(0,false)=="Hunger 0% · starving" and LifeText.hunger(0,true)=="Hunger 0% · gentle","starving; gentle never says it")
 check(LifeText.hunger(1.5,false)=="Hunger 100%" and LifeText.hunger(-1,false)=="Hunger 0% · starving","clamped")
 for _,v in {1,0.5,0.2,0} do
  local t=LifeText.hunger(v,false);check(not string.find(string.lower(t),"food") and not string.find(string.lower(t),"energy"),"no 'food' or 'energy' on the bar")
 end
 local g:any=Growth.new();g.stage=Growth.ADULT
 check(not string.find(string.lower(LifeText.growth(g,0.9,0.35)),"food reserves"),"the adult line says hunger")
end)
case("meal credit is consumed food, even with full energy",function()
 for _,portion in {.3,.15} do
  local needs=NeedsModel.new(true);needs.energy=1
  local l=LifeLoop.new(needs)
  local n=math.floor(.9/portion+.5)
  for i=1,n do
   l.mealFood=portion;l:_stepLife(1/60,Vector3.zero)
   check(l.growth.ready==(i==n),"exact three houseflies or six small prey")
  end
  check(needs.grantedTotal==0,"growth does not invent energy grants")
 end
end)
print(`LIFE passed={passed} failed={failed}`)
if failed > 0 then error("LIFE failed") end
