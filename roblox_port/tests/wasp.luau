-- WASP checks: the mud dauber wasp's rules (Shared/Predator/WaspDirector, Shared/Data/Wasp) against the frozen Godot director.
-- tests/wasp_reference.json is made by tools/export_wasp_reference.gd, which runs Godot's own WaspDirector on a stand-in world (a floor,
-- sometimes a low wall, a scripted spider); this file replays the same spider through the port on an analytic copy of that world
-- and compares every event, phase change and sampled state. Godot's random draws cannot be reproduced in Luau, so the replay is fed the
-- draws Godot made (read back from the state they left), in the order the director asks for them. Then Godot's hand-written
-- expectations (tests/integration/test_life04_wasp.gd) that need no engine world, on the port's own random stream.
-- Run with the other suites:  python3 tests/run.py path/to/luau wasp.luau
local Data = require("../src/Shared/Data/Wasp")
local WaspDirector = require("../src/Shared/Predator/WaspDirector")
local ref = require("./wasp_reference")

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
local function v3(a: { number }): Vector3 return Vector3.new(a[1], a[2], a[3]) end
local PLACE_EPS = 1e-5 -- Godot keeps its vectors in single precision
local function close(a: Vector3, b: Vector3, eps: number): boolean return (a - b).Magnitude <= eps end

-- ------------------------------------------------------------------------------------------------------- the analytic world
-- Axis-aligned boxes: a ray hits one when the segment enters it; a sphere sweep when the segment enters the box grown by the radius
-- (rounded corners ignored; the scenarios keep their paths away from corners). A sweep that starts inside the grown box is clear, as
-- Godot's cast_motion reported for the walking wasp, which stands 0.35 above a floor under a 0.55 sphere.
type Box = { min: Vector3, max: Vector3 }
local function segmentEnters(a: Vector3, b: Vector3, lo: Vector3, hi: Vector3): boolean
	local t0, t1 = 0.0, 1.0
	for _, axis in { "X", "Y", "Z" } do
		local o, d = (a :: any)[axis], (b :: any)[axis] - (a :: any)[axis]
		local mn, mx = (lo :: any)[axis], (hi :: any)[axis]
		if math.abs(d) < 1e-12 then
			if o < mn or o > mx then return false end
		else
			local u, w = (mn - o) / d, (mx - o) / d
			if u > w then u, w = w, u end
			t0, t1 = math.max(t0, u), math.min(t1, w)
			if t0 > t1 then return false end
		end
	end
	return true
end
local function makeWorld(boxes: { Box }, retreat: { number })
	local lo, hi = v3({ retreat[1], retreat[2], retreat[3] }), v3({ retreat[4], retreat[5], retreat[6] })
	return {
		ray = function(a: Vector3, b: Vector3): boolean
			for _, box in boxes do
				if segmentEnters(a, b, box.min, box.max) then return true end
			end
			return false
		end,
		clear = function(a: Vector3, b: Vector3, r: number): boolean
			local g = Vector3.new(r, r, r)
			for _, box in boxes do
				local gl, gh = box.min - g, box.max + g
				local inside = a.X >= gl.X and a.X <= gh.X and a.Y >= gl.Y and a.Y <= gh.Y and a.Z >= gl.Z and a.Z <= gh.Z
				if not inside and segmentEnters(a, b, gl, gh) then return false end
			end
			return true
		end,
		inRetreat = function(p: Vector3): boolean
			return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
		end,
	}
end
local FLOOR: Box = { min = Vector3.new(-60, -2, -30), max = Vector3.new(60, 0, 30) }
local WALL: Box = { min = Vector3.new(3.0, 0, -20), max = Vector3.new(3.4, 2.5, 20) }

-- A scripted random stream: the draws Godot made, in order. Every call says which kind of draw it is, and the replay checks it.
local KIND_OF_CALL = { range = { hover = true, angle = true }, unit = { chance = true }, int = { pick = true } }
local function scriptedRng(draws: { any }, problems: { string })
	local nextDraw = 1
	local function take(call: string, lo: number?): number
		local d = draws[nextDraw]
		nextDraw += 1
		if d == nil then table.insert(problems, `a draw ({call}) beyond Godot's {#draws}`) return 0 end
		if not KIND_OF_CALL[call][d.kind] then table.insert(problems, `draw {nextDraw - 1}: the port asked for a {call}, Godot drew a {d.kind}`) end
		return d.value + (lo or 0)
	end
	return {
		range = function(_, _lo: number, _hi: number): number return take("range") end,
		unit = function(): number return take("unit") end,
		int = function(_, lo: number, _hi: number): number return take("int", lo) end,
		used = function(): number return nextDraw - 1 end,
	}
end

local DT = ref.dt
local WALK = ref.walk
local MODE = { [0] = "flying", [1] = "walking", [2] = "holding" }

-- The scripted spider: the same program, run the same way, as tools/export_wasp_reference.gd.
local function runProgram(director: any, program: { any }, maxTicks: number, onTick: ((number, any) -> ())?): (number, any)
	local spider = {
		position = Vector3.new(2, 0.31, 6), velocity = Vector3.zero, walkSpeed = WALK, airborne = false, falling = false,
	}
	local block = { day = 2, hour = 12.0, resting = false, moulting = false, meals = 1 }
	local segI, segTick, tick = 1, 0, 0
	while tick < maxTicks do
		while segI <= #program do
			local u = program[segI]["until"]
			local done = false
			if u.ticks ~= nil then done = segTick >= u.ticks
			elseif u.phase ~= nil then done = director.phase == u.phase
			elseif u.away ~= nil then done = not director:isVisiting() end
			if not done then break end
			segI += 1
			segTick = 0
		end
		if segI > #program then break end
		local seg = program[segI]
		if segTick == 0 then
			if seg.pos then spider.position = v3(seg.pos) end
			spider.airborne, spider.falling = seg.state == "airborne", seg.state == "falling"
		end
		if not director.holding then
			local vel = Vector3.zero
			if seg.axis then
				local flip = seg.flip or 30
				local sign = if (segTick // flip) % 2 == 0 then 1.0 else -1.0
				vel = v3(seg.axis) * sign * WALK * (seg.speed or 1.0)
			end
			spider.velocity = vel
			spider.position += vel * DT
		end
		segTick += 1
		director:step(DT, spider, block)
		tick += 1
		if director.heldAt then spider.position = director.heldAt end
		if onTick then onTick(tick, spider) end
		if director.phase == "away" and director.visitS > 0 then break end
	end
	return tick, spider
end

-- ------------------------------------------------------------------------------------------------------- the numbers
case("constants and the fifteen places are Godot's", function()
	local c = ref.constants
	local pairsToCheck = {
		{ Data.firstDay, c.first_day }, { Data.visitChance, c.visit_chance }, { Data.windowFromH, c.window_from }, { Data.windowToH, c.window_to },
		{ Data.arriveS, c.arrive_s }, { Data.searchS, c.search_s }, { Data.leaveS, c.leave_s }, { Data.carryS, c.carry_s }, { Data.cruiseY, c.cruise_y },
		{ Data.flySpeed, c.fly_speed }, { Data.radius, c.radius }, { Data.hoverS[1], c.hover_s[1] }, { Data.hoverS[2], c.hover_s[2] },
		{ Data.scanDegS, c.scan_deg_s }, { Data.landChance, c.land_chance }, { Data.landS, c.land_s }, { Data.walkS, c.walk_s },
		{ Data.walkSpeed, c.walk_speed }, { Data.stepEveryS, c.step_every_s }, { Data.sightWu, c.sight_wu }, { Data.noticeStill, c.notice_still },
		{ Data.noticeMoving, c.notice_moving }, { Data.noticeDecay, c.notice_decay }, { Data.confuseS, c.confuse_s },
		{ Data.afterLossNotice, c.after_loss_notice }, { Data.loseUnseenS, c.lose_unseen_s }, { Data.farFromLossWu, c.far_from_loss_wu },
		{ Data.standoffWu, c.standoff_wu }, { Data.inspectSpeed, c.inspect_speed }, { Data.inspectS, c.inspect_s },
		{ Data.inspectGiveUpS, c.inspect_give_up_s }, { Data.strikeS, c.strike_s }, { Data.catchWu, c.catch_wu }, { Data.holdBelow, c.hold_below },
		{ Data.eyeAhead, c.eye_ahead }, { Data.sensedRadius, c.sensed_radius },
	}
	for i, p in pairsToCheck do near(p[1], p[2], 1e-6, `constant {i}`) end
	check(close(Data.entry, v3(c.entry), PLACE_EPS) and close(Data.over, v3(c.over), PLACE_EPS), "entry and over the frame")
	check(#Data.points == #c.points, `{#c.points} places`)
	for i, p in c.points do
		local mine = Data.points[i]
		check(mine.id == p.id and close(mine.hover, v3(p.hover), PLACE_EPS), `place {i} {p.id}`)
		check((mine.land == nil) == (p.land == nil) and (p.land == nil or close(mine.land, v3(p.land), PLACE_EPS)), `{p.id}: where it may land`)
		check(WaspDirector.pointIndex(p.id) == i, `{p.id}: its index`)
	end
	check(WaspDirector.pointIndex("nowhere") == nil, "an unknown place")
end)

case("why a visit cannot begin", function()
	local d = WaspDirector.new({ seed = 1, world = makeWorld({}, ref.retreat), enabled = false })
	for _, row in ref.blocked do
		check(d:blocked({ day = row.day, hour = 12, resting = row.resting, moulting = row.moulting, meals = row.meals }) == row.blocked,
			`day {row.day}, {row.meals} meals, resting {row.resting}, moulting {row.moulting}: {row.blocked}`)
	end
end)

case("the record and its checks", function()
	for i, row in ref.records do
		local mine = WaspDirector.problems(row.record)
		check(#mine == #row.problems, `record {i}: {#mine} problems, Godot {#row.problems}`)
		for k, text in row.problems do check(mine[k] == text, `record {i}: "{mine[k]}" against "{text}"`) end
	end
	local d = WaspDirector.new({ seed = 1, world = makeWorld({}, ref.retreat) })
	d.lastVisitDay, d.visits, d.escapes = 4, 3, 2
	local rec = d:toRecord()
	check(rec.last_visit_day == 4 and rec.visits == 3 and rec.escapes == 2, "the record keeps the day, the visits and the escapes")
	check(#WaspDirector.problems(rec) == 0, "and is valid")
	local fresh = WaspDirector.new({ seed = 1, world = makeWorld({}, ref.retreat) })
	fresh:load(rec)
	check(fresh.lastVisitDay == 4 and fresh.visits == 3 and fresh.escapes == 2, "and comes back")
	local def = WaspDirector.defaultRecord()
	check(def.last_visit_day == 0 and def.visits == 0 and def.escapes == 0 and #WaspDirector.problems(def) == 0, "the record of a life not yet visited")
end)

-- ------------------------------------------------------------------------------------------------------- Godot's scenarios
for _, sc in ref.scenarios do
	case(`scenario {sc.name}`, function()
		local problems: { string } = {}
		local rng = scriptedRng(sc.draws, problems)
		local boxes = { FLOOR }
		if sc.wall then table.insert(boxes, WALL) end
		local world = makeWorld(boxes, ref.retreat)
		local director = WaspDirector.new({ seed = 1234, world = world, enabled = false, makeRng = function() return rng :: any end })
		director:force(2, sc.point)
		-- The signals' shakes, and the samples as the replay passes them.
		local sampleI, phaseI = 1, 1
		local seenPhases: { { tick: number, phase: string, sub: string } } = {}
		local lastPhase, lastSub = "", ""
		local shakes: { any } = {}
		local worst = { pos = 0.0, heading = 0.0, notice = 0.0, other = 0.0 }
		local lastSample = 0
		local ticks = runProgram(director, sc.program, sc.max_ticks, function(tick: number, spider: any)
			for _, s in director:drainSignals() do
				if s.kind == "shake" then table.insert(shakes, s) end
			end
			if director.phase ~= lastPhase or (director.phase == "searching" and director.sub ~= lastSub) then
				table.insert(seenPhases, { tick = tick, phase = director.phase, sub = if director.phase == "searching" then director.sub else "" })
				lastPhase, lastSub = director.phase, director.sub
			end
			local s = sc.samples[sampleI]
			if s ~= nil and s.tick == tick then
				sampleI += 1
				lastSample = tick
				local w = director.wasp
				check(s.phase == director.phase, `tick {tick}: phase {director.phase}, Godot {s.phase}`)
				if director.phase == "away" then return end
				check(s.sub == director.sub or director.phase ~= "searching", `tick {tick}: sub {director.sub}, Godot {s.sub}`)
				worst.pos = math.max(worst.pos, (w.position - v3(s.pos)).Magnitude)
				worst.heading = math.max(worst.heading, (w.heading - v3(s.heading)).Magnitude)
				worst.notice = math.max(worst.notice, math.abs(director.notice - s.notice), math.abs(director.confusedS - s.confused), math.abs(director.searchLeft - s.search_left))
				worst.other = math.max(worst.other, (w.velocity - v3(s.velocity)).Magnitude * 0.0, math.abs(w.search - s.search))
				check(MODE[s.mode] == w.mode, `tick {tick}: mode {w.mode}, Godot {MODE[s.mode]}`)
				check(Data.points[director.point].id == s.point, `tick {tick}: looking at {Data.points[director.point].id}, Godot {s.point}`)
				check(director:canSeeSpider() == s.sees, `tick {tick}: sees the spider {director:canSeeSpider()}, Godot {s.sees}`)
				check(close(spider.position, v3(s.spider), 1e-3), `tick {tick}: the spider is where Godot has it ({spider.position} against {v3(s.spider)})`)
				check(w.visible == s.visible, `tick {tick}: visible`)
				check(director.holding == s.seized, `tick {tick}: held ({director.holding}) as Godot's seized ({s.seized})`)
			end
		end)
		check(ticks == sc.ticks, `the visit lasts {ticks} ticks, Godot {sc.ticks}`)
		-- Events: the same kinds in the same order, the times to within a tick and a half.
		check(#director.events == #sc.events, `{#director.events} events, Godot {#sc.events}`)
		for i, e in sc.events do
			local mine = director.events[i]
			if mine == nil then check(false, `event {i} {e.kind} is missing`) break end
			check(mine.kind == e.kind, `event {i}: {mine.kind}, Godot {e.kind}`)
			near(mine.t, e.t, DT * 1.5, `event {i} {e.kind} time`)
		end
		-- Phase changes: the same ones in the same order, each within a tick of Godot's.
		check(#seenPhases == #sc.phases, `{#seenPhases} phase changes, Godot {#sc.phases}`)
		for i, p in sc.phases do
			local mine = seenPhases[i]
			if mine == nil then break end
			check(mine.phase == p.phase and mine.sub == p.sub, `phase change {i}: {mine.phase}/{mine.sub}, Godot {p.phase}/{p.sub}`)
			check(math.abs(mine.tick - p.tick) <= 1, `phase change {i} ({p.phase}/{p.sub}) at tick {mine.tick}, Godot {p.tick}`)
		end
		-- The sampled state: positions within a thousandth of a WU (Godot keeps its vectors in single precision).
		check(sampleI == #sc.samples + 1 or director.phase == "away", `{sampleI - 1} of {#sc.samples} samples compared`)
		check(worst.pos < 2e-3, `positions within 2e-3 of Godot's (worst {worst.pos})`)
		check(worst.heading < 2e-3, `headings within 2e-3 (worst {worst.heading})`)
		check(worst.notice < 2e-3, `notice, confusion and the search clock within 2e-3 (worst {worst.notice})`)
		check(worst.other < 1e-9, "the antennae's busyness is Godot's")
		-- The draws: every one Godot made was asked for, in order, and no more.
		check(rng.used() == #sc.draws, `{rng.used()} draws asked for, Godot made {#sc.draws}`)
		for _, p in problems do check(false, p) end
		-- Landings and footsteps that shake the surface.
		check(#shakes == #sc.shakes, `{#shakes} shakes, Godot {#sc.shakes}`)
		for i, s in sc.shakes do
			local mine = shakes[i]
			if mine == nil then break end
			check(mine.shake == s.kind and close(mine.at, v3(s.at), 2e-3), `shake {i}: {mine.shake} at {mine.at}, Godot {s.kind} at {v3(s.at)}`)
		end
		local rec = director:toRecord()
		check(rec.visits == sc.record.visits and rec.escapes == sc.record.escapes and rec.last_visit_day == sc.record.last_visit_day,
			`the record at the end: {rec.visits} visits, {rec.escapes} escapes; Godot {sc.record.visits}, {sc.record.escapes}`)
		check(director.noticedThisVisit == sc.noticed, "noticed this visit")
	end)
end

-- ------------------------------------------------------------------------------------------------------- Godot's own expectations
-- tests/integration/test_life04_wasp.gd, the cases that need no engine world, on the port's own random stream.
local function newDirector(boxes: { Box }?, enabled: boolean?): any
	return WaspDirector.new({ seed = 77, world = makeWorld(boxes or { FLOOR }, ref.retreat), enabled = enabled })
end
local OPEN = Vector3.new(2, 0.31, 6)
local CRACK = Vector3.new(-25, 0.31, 6)
local function spiderAt(p: Vector3): any
	return { position = p, velocity = Vector3.zero, walkSpeed = WALK, airborne = false, falling = false }
end
local BLOCK = { day = 2, hour = 12.0, resting = false, moulting = false, meals = 1 }
local function kindTime(d: any, kind: string): number
	for _, e in d.events do
		if string.sub(e.kind, 1, #kind) == kind then return e.t end
	end
	return -1.0
end
local function kinds(d: any): string
	local out = {}
	for _, e in d.events do table.insert(out, string.format("%s@%.1f", e.kind, e.t)) end
	return table.concat(out, ", ")
end
-- Paces the spider to and fro along `axis` until `untilFn` is true or the ticks run out; then it stands still.
local function pace(d: any, spider: any, axis: Vector3, untilFn: () -> boolean, maxTicks: number): boolean
	local n = 0
	local ok = false
	while n < maxTicks do
		n += 1
		spider.velocity = axis * (if (n // 30) % 2 == 0 then 1.0 else -1.0) * WALK
		spider.position += spider.velocity * DT
		d:step(DT, spider, BLOCK)
		if untilFn() then ok = true break end
	end
	spider.velocity = Vector3.zero
	return ok
end
local function runOn(d: any, spider: any, untilFn: () -> boolean, maxTicks: number): boolean
	for _ = 1, maxTicks do
		d:step(DT, spider, BLOCK)
		if d.heldAt and d.holding then spider.position = d.heldAt end
		if untilFn() then return true end
	end
	return false
end

case("when it comes (LIFE-14)", function()
	local d = newDirector()
	check(d:plannedHour(1) == -1.0, "never on the first day")
	local daysWith = 0
	for day = 2, 41 do
		local h = d:plannedHour(day)
		if h >= 0 then
			daysWith += 1
			check(h >= Data.windowFromH and h < Data.windowToH, `day {day}: by day ({h} h)`)
		end
		check(d:plannedHour(day) == h, `the same world, the same wasp (day {day})`)
	end
	check(daysWith >= 14 and daysWith <= 34, `on some days, not all: {daysWith} of 40`)
	local other = newDirector()
	other.seed = 78
	local differ = false
	for day = 2, 41 do if other:plannedHour(day) ~= d:plannedHour(day) then differ = true end end
	check(differ, "another world has other days")
	check(d:blocked({ day = 1, hour = 12, resting = false, moulting = false, meals = 0 }) == "the first day", "the first day is for learning")
	local day = 2
	while d:plannedHour(day) < 0 do day += 1 end
	check(d:blocked({ day = day, hour = 12, resting = false, moulting = false, meals = 0 }) == "no meal yet", "not before the first meal")
	check(d:blocked({ day = day, hour = 12, resting = true, moulting = false, meals = 1 }) == "resting", "not while resting")
	check(d:blocked({ day = day, hour = 12, resting = false, moulting = true, meals = 1 }) == "resting", "not while moulting")
	check(d:blocked({ day = day, hour = 12, resting = false, moulting = false, meals = 1 }) == "", "otherwise nothing stands in its way")
	-- On its day and hour it comes by itself, once.
	local s = spiderAt(CRACK)
	local b = { day = day, hour = d:plannedHour(day) - 0.05, resting = false, moulting = false, meals = 1 }
	d:step(DT, s, b)
	check(not d:isVisiting(), "before its hour it does not come")
	b.hour = d:plannedHour(day) + 0.05
	d:step(DT, s, b)
	check(d:isVisiting(), `then, on its day and hour, it comes: {d.phase}`)
	check(d.lastVisitDay == day, "and that is the day's visit")
	d:clearVisit()
	d:step(DT, s, b)
	check(not d:isVisiting(), "once a day")
	-- Not while resting, not past the window, not before its hour.
	local e = newDirector()
	local day2 = day
	local b2 = { day = day2, hour = e:plannedHour(day2) + 0.05, resting = true, moulting = false, meals = 1 }
	e:step(DT, s, b2)
	check(not e:isVisiting(), "not while the spider rests")
	b2.resting, b2.hour = false, Data.windowToH + 0.1
	e:step(DT, s, b2)
	check(not e:isVisiting(), "not after the window")
	local f = newDirector(nil, false)
	b2.hour = f:plannedHour(day2) + 0.05
	f:step(DT, s, b2)
	check(not f:isVisiting(), "disabled, it never comes by itself")
	check(f:force(day2, "floor_middle") and f:isVisiting(), "though a forced visit brings it")
	check(not f:force(day2, "floor_middle"), "and not twice at once")
end)

case("it is heard before it can look (LIFE-15)", function()
	local d = newDirector()
	local spider = spiderAt(OPEN)
	check(d:force(2, "floor_middle"), "a visit")
	check(kindTime(d, "warning") == 0.0, "the warning is the visit's first moment")
	check((d.wasp.position - spider.position).Magnitude > Data.sightWu * 3.0, "it starts far outside, over the frame")
	local early = false
	pace(d, spider, Vector3.new(1, 0, 0), function()
		if d.phase == "arriving" and d.notice > 0 then early = true end
		return d.phase ~= "arriving"
	end, 60 * 20)
	check(not early, "it looks for nothing while it arrives")
	check(kindTime(d, "searching") >= Data.arriveS - 0.05, `and searches only after {Data.arriveS} s: {kinds(d)}`)
	check(close(d.wasp.position, Data.points[WaspDirector.pointIndex("floor_middle") :: number].hover, 0.05), "at the first place it looks")
	local signals = d:drainSignals()
	check(signals[1].kind == "visit_started" and signals[1].first == true, "the first visit is announced as the first")
end)

case("a moving spider in the open is found, looked at and caught (LIFE-15, LIFE-16)", function()
	local d = newDirector()
	local spider = spiderAt(OPEN)
	d:force(2, "floor_middle")
	check(pace(d, spider, Vector3.new(1, 0, 0), function() return d.phase == "inspecting" end, 60 * 20), `moving in the open, it is found: {kinds(d)}`)
	check(kindTime(d, "noticed") - kindTime(d, "searching") < 2.5, `and quickly ({kindTime(d, "noticed") - kindTime(d, "searching")} s)`)
	check(runOn(d, spider, function() return d.holding end, 60 * 6), `keeping still now, close by, it is caught: {kinds(d)}`)
	check(kindTime(d, "caught") - kindTime(d, "noticed") >= Data.inspectS + Data.strikeS - 0.02, "only after the wasp came and looked")
	check(kindTime(d, "caught") - kindTime(d, "warning") >= Data.arriveS + Data.inspectS, "and long after it was first heard")
	check(d.heldAt ~= nil, "the spider goes still: the wasp holds it")
	check(runOn(d, spider, function() return d.phase == "away" end, 60 * 6), "the wasp carries it away")
	check(close(spider.position, d.wasp.position + Vector3.new(0, -Data.holdBelow, 0), 0.05), "held under the wasp")
	check(spider.position.Y > 10.0, `up and away over the frame: {spider.position}`)
	local sig = d:drainSignals()
	local sawCaught, sawOff = false, false
	for _, s in sig do
		if s.kind == "caught" then sawCaught = true elseif s.kind == "carried_off" then sawOff = true end
	end
	check(sawCaught and sawOff, "caught and carried off are both announced")
	check(not d.wasp.visible, "and then it is gone")
	-- Nothing of a gentle kind in Roblox yet: with the flag it touches the spider and leaves.
	local g = newDirector()
	g.gentle = true
	local gs = spiderAt(OPEN)
	g:force(2, "floor_middle")
	pace(g, gs, Vector3.new(1, 0, 0), function() return g.phase == "inspecting" end, 60 * 20)
	runOn(g, gs, function() return g.phase == "leaving" end, 60 * 6)
	check(g.sparedThisVisit and not g.holding and kindTime(g, "caught") < 0, "gentle rules: it spares the spider and leaves")
end)

case("a still spider is found slowly and the crack never (LIFE-15, LIFE-16)", function()
	local d = newDirector()
	local spider = spiderAt(OPEN)
	d:force(2, "floor_middle")
	runOn(d, spider, function() return d.phase == "searching" end, 60 * 12)
	check(d:canSeeSpider(), "it can see the spider in the open")
	local still = d:noticeRate()
	spider.velocity = Vector3.new(WALK, 0, 0)
	local moving = d:noticeRate()
	spider.velocity = Vector3.zero
	check(moving > still * 5.0, `moving is noticed far faster than keeping still ({moving} against {still} per s)`)
	check(still * Data.hoverS[2] < 1.0, "a still spider outlasts one look from close by")
	spider.airborne = true
	near(d:noticeRate(), (Data.noticeStill + Data.noticeMoving * 1.5) * math.max(1 - (d:eyePosition() - spider.position).Magnitude / Data.sightWu, 0), 1e-12, "a spider in the air is as plain as one running")
	spider.airborne = false
	-- In the crack: never seen, never close.
	local c = newDirector()
	local cs = spiderAt(CRACK)
	check(c.world.inRetreat(cs.position), "at home in the crack")
	local ever = false
	local escaped = true
	c:force(2, "crack_mouth")
	pace(c, cs, Vector3.new(0, 0, 1), function()
		if c.notice > 0 or c:canSeeSpider() then ever = true end
		for _, s in c:drainSignals() do
			if s.kind == "left" then escaped = s.escaped end
		end
		return c.phase == "away"
	end, 60 * 80)
	check(c.phase == "away", `it gives up and leaves: {kinds(c)}`)
	check(not ever, "never once seeing the spider moving about in the crack")
	check(not escaped, "and it was never close")
	check(kindTime(c, "left") >= Data.arriveS + Data.searchS - 0.1, `after its whole search: {kinds(c)}`)
	check(c.escapes == 0, "no escape counted")
end)

case("a drop or a jump breaks its approach (LIFE-16)", function()
	for _, how in { "dropped", "jumped" } do
		local d = newDirector()
		local spider = spiderAt(OPEN)
		d:force(2, "floor_middle")
		check(pace(d, spider, Vector3.new(1, 0, 0), function() return d.phase == "inspecting" end, 60 * 20), `{how}: seen on the floor`)
		if how == "dropped" then spider.falling = true else spider.airborne = true end
		d:step(DT, spider, BLOCK)
		check(kindTime(d, "lost:" .. how) > 0, `{how}: the wasp loses it: {kinds(d)}`)
		check(d.confusedS > 0 and d.phase == "searching", "and is confused for a while")
		spider.falling, spider.airborne = false, false
		runOn(d, spider, function() return false end, 60 * 3)
		check(kindTime(d, "caught") < 0, "no catch")
		check(d.lossPos ~= nil and d.notice <= Data.afterLossNotice + 1e-9, "it remembers where it lost it, and only half-notices")
		-- It searches somewhere at least FAR_FROM_LOSS_WU away.
		local far = (Data.points[d.point].hover - (d.lossPos :: Vector3)).Magnitude
		check(far >= Data.farFromLossWu - 1e-9, `{how}: the next place is {far} WU from where it lost the spider`)
	end
end)

case("a spider that hides in the crack, or that is gone from the lunge, is not caught (LIFE-16)", function()
	local d = newDirector()
	local spider = spiderAt(Vector3.new(-13, 0.31, 6))
	d:force(2, "floor_west")
	check(pace(d, spider, Vector3.new(1, 0, 0), function() return d.phase == "inspecting" end, 60 * 20), "seen")
	spider.position = CRACK
	d:step(DT, spider, BLOCK)
	check(kindTime(d, "lost:hid") > 0, `it loses a spider that hides in the crack: {kinds(d)}`)
	local m = newDirector()
	local ms = spiderAt(OPEN)
	m:force(2, "floor_middle")
	pace(m, ms, Vector3.new(1, 0, 0), function() return m.phase == "inspecting" end, 60 * 20)
	check(runOn(m, ms, function() return m.phase == "striking" end, 60 * 6), "keeping still, the lunge begins")
	ms.position = ms.position + Vector3.new(0, 0, 3.5)
	runOn(m, ms, function() return m.phase ~= "striking" end, 60)
	check(kindTime(m, "lost:missed") > 0 and kindTime(m, "caught") < 0, `a spider that moves off during the lunge is missed: {kinds(m)}`)
end)

case("what the spider senses of it (LIFE-15)", function()
	local d = newDirector()
	check(d:percept() == nil, "away, there is nothing to sense")
	d:force(2, "floor_middle")
	d:step(DT, spiderAt(OPEN), BLOCK)
	local p = d:percept()
	check(p ~= nil and p.maxCategory == "movement", "to the spider it is movement, never prey")
	check(p ~= nil and p.radius == Data.sensedRadius and p.id == "wasp", "its size and name")
	check(p ~= nil and close(p.position, d.wasp.position, 0), "and where it is")
	check(close(d:eyePosition(), d.wasp.position + d.wasp.heading * Data.eyeAhead, 1e-12), "its eyes are ahead of its centre")
end)

case("its landing shakes the surface (LIFE-15)", function()
	local d = newDirector()
	local spider = spiderAt(CRACK)
	d:force(2, "floor_middle")
	local landed = false
	local shook = false
	for _ = 1, 60 * 70 do
		d:step(DT, spider, BLOCK)
		for _, s in d:drainSignals() do
			if s.kind == "landed" then landed = true end
			if s.kind == "shake" and s.shake == "heavy landing" then shook = true end
		end
		if landed or not d:isVisiting() then break end
	end
	-- Landing is by chance, place by place; the whole of one visit searches many places, so over a handful of visits it lands.
	local tries = 0
	while not landed and tries < 12 do
		tries += 1
		d:clearVisit()
		d:force(2 + tries, "floor_middle")
		for _ = 1, 60 * 70 do
			d:step(DT, spider, BLOCK)
			for _, s in d:drainSignals() do
				if s.kind == "landed" then landed = true end
				if s.kind == "shake" and s.shake == "heavy landing" then shook = true end
			end
			if landed or not d:isVisiting() then break end
		end
	end
	check(landed and shook, `on some visit it lands somewhere and the surface shakes: {kinds(d)}`)
end)

print(`WASP passed={passed} failed={failed}`)
