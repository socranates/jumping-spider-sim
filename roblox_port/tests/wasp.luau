-- WASP checks: the mud dauber wasp's rules (Shared/Predator/WaspDirector, Shared/Data/Wasp) against the frozen Godot director.
-- tests/wasp_reference.json is made by tools/export_wasp_reference.gd, which runs Godot's own WaspDirector on a stand-in world (a floor,
-- sometimes a low wall, a scripted spider); this file replays the same spider through the port on an analytic copy of that world
-- and compares every event, phase change and sampled state. Godot's random draws cannot be reproduced in Luau, so the replay is fed the
-- draws Godot made (read back from the state they left), in the order the director asks for them. Then Godot's hand-written
-- expectations (tests/integration/test_life04_wasp.gd) that need no engine world, on the port's own random stream.
-- Run with the other suites:  python3 tests/run.py path/to/luau wasp.luau
local Data = require("../src/Shared/Data/Wasp")
local WaspDirector = require("../src/Shared/Predator/WaspDirector")
local WaspText = require("../src/Shared/UI/WaspText")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local WaspLook = require("../src/Shared/Data/WaspLook")
local WaspBody = require("../src/Client/WaspBody")
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


-- ------------------------------------------------------------------------------------------------------- the real sill's boxes
-- Godot's test_what_the_spider_senses_of_it_and_where_it_flies: every place has room to hover, is open straight up to cruising height,
-- is reached from over the frame, and a landing has a clear way down and ground under it, here on the Roblox sill's own pieces as the
-- box world of tests/shim.luau has them (axis-aligned boxes; the engine's shapes are checked in tests/studio/WaspSpec).
case("every place is clear on the sill's pieces", function()
	local sill = BoxWorld.folder("WaspSill", Layout.PIECES)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { sill }
	local function clear(a: Vector3, b: Vector3, r: number): boolean
		return (a - b).Magnitude < 1e-5 or workspace:Spherecast(a, r, b - a, params) == nil
	end
	local up = Vector3.new(0, 1, 0)
	for _, p in Data.points do
		local hover: Vector3 = p.hover
		local top = Vector3.new(hover.X, Data.cruiseY, hover.Z)
		check(clear(hover + up * 0.01, hover, Data.radius), `{p.id}: room to hover`)
		check(clear(hover, top, Data.radius), `{p.id}: open straight up`)
		check(clear(Data.over, top, Data.radius), `{p.id}: reached from over the frame`)
		if p.land then
			local land: Vector3 = p.land
			check(clear(hover, land + up * 0.25, Data.radius), `{p.id}: a clear way down to land`)
			check(workspace:Raycast(land, Vector3.new(0, -0.5, 0), params) ~= nil, `{p.id}: ground under the landing`)
			check(clear(land, land + up * 1.2, Data.walkRadius), `{p.id}: room to take off`)
		end
	end
	check(clear(Data.entry, Data.over, Data.radius), "in over the frame without touching it")
end)

-- ------------------------------------------------------------------------------------------------------- the words
case("the captions say where the hum is", function()
	local at, heading, up = Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	local function word(p: Vector3): string return WaspText.directionWord(at, heading, up, p) end
	check(word(Vector3.new(5, 0, 0)) == "ahead", "ahead")
	check(word(Vector3.new(-5, 0, 0)) == "behind", "behind")
	-- Facing +X with +Y up, the left hand is toward -Z.
	check(word(Vector3.new(0, 0, -5)) == "left" and word(Vector3.new(0, 0, 5)) == "right", "left and right")
	check(word(Vector3.new(5, 0, -5)) == "ahead-left" and word(Vector3.new(5, 0, 5)) == "ahead-right", "the front diagonals")
	check(word(Vector3.new(-5, 0, -5)) == "behind-left" and word(Vector3.new(-5, 0, 5)) == "behind-right", "the back diagonals")
	check(word(Vector3.new(0, 5, 0)) == "above" and word(Vector3.new(5, 5, 5)) == "above, ahead-right" and word(Vector3.new(0, -5, 0)) == "below", "above and below")
	check(word(Vector3.new(5, 1, 0)) == "ahead", "a little up is still ahead")
	check(word(at) == "here", "on top of it")
	local a = WaspText.caption("arriving", 3, "ahead-left")
	check(a ~= nil and a.text == "[a deep, heavy hum outside, ahead-left, coming closer]" and a.alpha == 1, "arriving")
	local i = WaspText.caption("inspecting", 0, "behind")
	check(i ~= nil and i.text == "[the deep hum turns toward you, behind]", "it has turned toward you")
	check(WaspText.caption("striking", 0, "behind") ~= nil, "and while it strikes")
	local l = WaspText.caption("leaving", 0.5, "above")
	check(l ~= nil and l.text == "[the deep hum fades away, above]" and l.alpha == 1, "leaving")
	local fading = WaspText.caption("leaving", Data.captionTailS - 0.5 * Data.captionFadeS, "above")
	check(fading ~= nil and math.abs(fading.alpha - 0.5) < 1e-9, "and fades")
	check(WaspText.caption("leaving", Data.captionTailS, "above") == nil and WaspText.caption("searching", 1, "ahead") == nil and WaspText.caption("away", 0, "ahead") == nil, "otherwise none")
	for _, phase in WaspDirector.PHASES do
		local c = WaspText.caption(phase, 0, "ahead")
		check(c == nil or string.sub(c.text, 1, 8) ~= "[buzzing", "none begins [buzzing, which is the flies'")
	end
end)

case("the lines of the visit and the catch screen", function()
	local keyboard, pad = "keyboard", "gamepad"
	local first = WaspText.line("arriving", false, 1, false, keyboard :: any)
	check(first ~= nil and string.find(first, "wasps hunt spiders", 1, true) ~= nil and string.find(first, "(F)", 1, true) ~= nil, "the first visit says what wasps do and the way down")
	check(string.find(WaspText.line("arriving", false, 1, false, pad :: any) :: string, "(X)", 1, true) ~= nil, "named for the controller")
	check(WaspText.line("arriving", false, 2, false, keyboard :: any) == "A deep hum outside: a wasp is coming. Hide in the crack, keep still, or drop on your line.", "later visits are short")
	check(WaspText.line("searching", true, 1, false, keyboard :: any) == "The wasp has lost you. Get out of sight.", "lost")
	check(WaspText.line("searching", false, 1, false, keyboard :: any) == "A wasp is searching the sill. Keep still, keep out of sight, or get home to the crack.", "searching")
	check(WaspText.line("inspecting", false, 1, false, keyboard :: any) == "The wasp has seen you! Get away: jump, drop on your line, or reach the crack.", "seen")
	check(WaspText.line("striking", false, 1, false, keyboard :: any) == WaspText.line("inspecting", false, 1, false, keyboard :: any), "and striking")
	check(WaspText.line("carrying", false, 1, false, keyboard :: any) == "Stung, the spider cannot move. The wasp carries it away.", "carried")
	check(WaspText.line("leaving", false, 1, true, keyboard :: any) == "The wasp touched you with its antennae, gave up, and is leaving.", "spared")
	check(WaspText.line("leaving", false, 1, false, keyboard :: any) == "The wasp is leaving.", "leaving")
	check(WaspText.line("away", false, 1, false, keyboard :: any) == nil, "away, nothing")
	check(WaspText.LINE == "A mud dauber wasp stung the spider and carried it away." and WaspText.BACK == "Back to your last rest", "Godot's caught-panel words")
	check(WaspText.choice(true) == "Back to your last rest" and WaspText.choice(false) == "Back to the start", "the way on")
	check(WaspText.summary(5, 0, 0, 0) == "It lived less than a day.\nIt ate 0 meals.", "the life, briefly")
	check(WaspText.summary(24, 1, 1, 0) == "It lived 1 day.\nIt ate 1 meal.\nThe wasp came 1 time; it got away from it 0 times.", "singulars")
	check(WaspText.summary(80, 3, 3, 2) == "It lived 3 days.\nIt ate 3 meals.\nThe wasp came 3 times; it got away from it 2 times.", "and plurals")
	local quiet, line, choices = WaspText.panel(0), WaspText.panel(Data.caughtQuietS), WaspText.panel(Data.caughtQuietS + Data.caughtLineS)
	check(quiet.dim == 0 and not quiet.line and not quiet.choices, "dim and quiet first")
	check(line.line and not line.choices and math.abs(line.dim - Data.caughtDim) < 1e-12, "then the line alone")
	check(choices.line and choices.choices, "then the way on")
	check(math.abs(WaspText.panel(Data.caughtQuietS / 2).dim - Data.caughtDim / 2) < 1e-12, "the dimming is gradual")
end)

-- ------------------------------------------------------------------------------------------------------- the drawn wasp
-- A mud dauber about 2.5 cm: black body, very long thin petiole, yellow-banded legs, smoky dark wings, curled antennae; it never
-- collides, is never seen by a ray and casts no shadow (checked under the shim; the look itself is judged in the preview and in Studio).
case("the drawn wasp is a mud dauber", function()
	local holder = Instance.new("Folder")
	holder.Name = "WaspHolder"
	holder.Parent = workspace
	local body = WaspBody.new(holder)
	local count = #body.parts
	check(count >= 50 and count <= 70, `{count} parts (a fly has about 60)`)
	for _, part in body.parts do
		check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow, `{part.Name}: anchored, no collision, no ray, no touch, no shadow`)
	end
	local function frameOf(name: string): any return body.frames[body.index[name]] end
	local function sizeOf(name: string): Vector3 return body.sizes[body.index[name]] end
	local function colorOf(name: string): Color3 return body.parts[body.index[name]].Color end
	local function endOf(name: string, sign: number): Vector3 return frameOf(name) * Vector3.new(sign * sizeOf(name).X / 2, 0, 0) end
	-- its length: the front of the mandibles to the end of the abdomen
	local lo, hi = math.huge, -math.huge
	for _, item in WaspLook.body do
		lo = math.min(lo, item.at[3] - item.size[3] / 2)
		hi = math.max(hi, item.at[3] + item.size[3] / 2)
	end
	check(hi - lo > 2.3 and hi - lo < 2.7, `about 2.5 cm long ({hi - lo})`)
	-- black body, yellow collar, scutellum, mandibles and petiole
	for _, name in { "Head", "Thorax", "Gaster", "AbdomenTip" } do
		local c = colorOf(name)
		check(c.R < 0.2 and c.G < 0.2 and c.B < 0.2, `{name} is black`)
	end
	for _, name in { "Collar", "Scutellum", "MandibleL", "Petiole" } do
		local c = colorOf(name)
		check(c.R > 0.7 and c.G > 0.55 and c.B < 0.3, `{name} is yellow`)
	end
	-- the very long thin waist: longer than the thorax is wide, a fraction of the gaster's width, joining thorax to gaster
	body:pose("flying", 0, 0)
	local petiole = sizeOf("Petiole")
	check(petiole.X > 0.6 and petiole.Y < 0.08 and petiole.Y < sizeOf("Gaster").X * 0.2, `a long thin petiole ({petiole.X} long, {petiole.Y} thick)`)
	check(math.abs(endOf("Petiole", -1).Z - WaspLook.petiole.from[3]) < 1e-6 and math.abs(endOf("Petiole", 1).Z - WaspLook.petiole.to[3]) < 1e-6, "from the thorax to the gaster")
	-- six legs, black femurs, a yellow band at each knee, yellow tibias and feet
	local bands = 0
	for _, side in { "L", "R" } do
		for pair = 1, 3 do
			local femur, band = colorOf(`Leg{side}{pair}Femur`), colorOf(`Leg{side}{pair}Band`)
			check(femur.R < 0.2 and band.R > 0.7 and band.B < 0.3 and colorOf(`Leg{side}{pair}Tibia`).R > 0.7 and colorOf(`Leg{side}{pair}Tarsus`).R > 0.7, `leg {side}{pair}: black femur, yellow band, tibia and foot`)
			bands += 1
			-- the band sits at the knee end of the femur
			check((endOf(`Leg{side}{pair}Band`, 1) - endOf(`Leg{side}{pair}Femur`, 1)).Magnitude < 0.02, `leg {side}{pair}: the band is at the knee`)
		end
	end
	check(bands == 6, "six legs")
	-- smoky, dark, translucent wings, two each side
	for _, side in { "L", "R" } do
		for k = 1, 2 do
			local c, t = colorOf(`Wing{side}{k}`), body.transparency[body.index[`Wing{side}{k}`]]
			check(c.R < 0.35 and c.G < 0.3 and c.B < 0.25 and t > 0.3 and t < 0.8, `wing {side}{k} is smoky and translucent`)
		end
	end
	-- antennae curl: the last segment turns well away from the first
	for _, side in { "L", "R" } do
		local first, last = endOf(`Antenna{side}1`, 1) - endOf(`Antenna{side}1`, -1), endOf(`Antenna{side}4`, 1) - endOf(`Antenna{side}4`, -1)
		local angle = math.deg(math.acos(math.clamp(first.Unit:Dot(last.Unit), -1, 1)))
		check(angle > 25 and angle < 150, `antenna {side} curls ({angle} degrees)`)
	end
	-- the antennae flick only while it searches
	body:pose("flying", 0.1, 0)
	local still = endOf("AntennaR4", 1)
	body:pose("flying", 0.1, 1)
	local busy = endOf("AntennaR4", 1)
	check((still - busy).Magnitude > 0.02, "searching flicks the antennae")
	-- flying: the wing is a visible blur; on the ground the wings are folded and there is no blur
	body:pose("flying", 0.3, 0.5)
	check(body.transparency[body.index["WingR1Blur"]] < 0.95, "the blur shows in flight")
	local flightYaw = frameOf("WingR1").Position
	body:pose("walking", 0.3, 0.5)
	check(body.transparency[body.index["WingR1Blur"]] == 1, "no blur on the ground")
	check((frameOf("WingR1").Position - flightYaw).Magnitude < WaspLook.wing.length * 0.8, "the wing stays at its root, folded or spread")
	-- walking: the feet reach the surface 0.35 below the position at the bottom of every stride, and never go lower
	local lowest = math.huge
	local reached = 0
	for step = 0, 59 do
		body:pose("walking", step / 60, 1)
		local low = math.huge
		for _, side in { "L", "R" } do
			for pair = 1, 3 do low = math.min(low, endOf(`Leg{side}{pair}Tarsus`, 1).Y) end
		end
		lowest = math.min(lowest, low)
		if low < -0.34 then reached += 1 end
	end
	check(lowest > -0.37 and lowest < -0.33, `the feet touch the surface ({lowest})`)
	check(reached > 10, "and it strides")
	-- holding: the front legs clutch under the body
	body:pose("holding", 0, 0)
	local clutch = endOf("LegL1Tarsus", 1)
	body:pose("flying", 0, 0)
	check((clutch - endOf("LegL1Tarsus", 1)).Magnitude > 0.3 and clutch.Y < -0.6, "the front legs reach down to hold what hangs under it")
	-- drawn: placed where the director has it, hidden while it is away
	local dir = { position = Vector3.new(5, 3, 2), heading = Vector3.new(1, 0, 0), mode = "flying", search = 0.3, visible = true }
	body:draw(dir, 1.0)
	check(body.folder.Parent == holder, "shown while it is here")
	local head = body.parts[body.index["Head"]].Position
	check((head - Vector3.new(5, 3, 2)).Magnitude > 0.9 and head.X > 5.9 and head.X < 6.3, `the head is ahead of the position along the heading ({head})`)
	check(math.abs(body.parts[body.index["Gaster"]].Position.X - 5) > 0.5 and body.parts[body.index["Gaster"]].Position.X < 5, "and the gaster behind")
	dir.visible = false
	body:draw(dir, 1.1)
	check(body.folder.Parent == nil, "taken out of the world while it is away")
	body:destroy()
end)

case("live pressure tuning extends search without shortening warning",function()
 local w=WaspDirector.new({seed=914,world={ray=function() return false end,clear=function() return true end,inRetreat=function() return false end}})
 w.searchScale=1.6;w.noticeScale=1.2;w.inspectScale=.8
 w:force(2,"floor_middle")
 near(w.searchLeft,72,1e-8,"search lasts 72 seconds")
 near(Data.arriveS,8,0,"eight second warning preserved")
 w.spider={position=w:eyePosition()+Vector3.xAxis,velocity=Vector3.zero,walkSpeed=1,airborne=false,falling=false}
 local faster=w:noticeRate();w.noticeScale=1
 near(faster/w:noticeRate(),1.2,1e-8,"twenty percent quicker recognition")
end)
case("the game's wasp comes every day from the second, twice a day, by day, never in a rest (ROBLOX-67, ROBLOX-75); the Godot replay keeps its some-days rule", function()
	check(Data.visitChance == 0.6 and Data.firstDay == 2 and Data.game.visitChance == 1.0, "Godot's numbers stay; the game's chance is its own setting")
	check(Data.windowFromH == 10.0 and Data.windowToH == 15.5, "Godot's one warm window stays")
	local godot = newDirector()
	local skipped = 0
	for day = 2, 41 do if godot:plannedHour(day) < 0 then skipped += 1 end end
	check(skipped > 0, `an unconfigured director still skips days like Godot ({skipped} of 40)`)
	local d = newDirector()
	d:useGameRules()
	check(d.searchScale == 1.6 and d.noticeScale == 1.2 and d.inspectScale == 0.8, "Chet's live multipliers are still applied")
	check(d:plannedHour(1) == -1.0 and d:plannedHours(1)[1] == -1.0 and d:plannedHours(1)[2] == -1.0, "never on the first day")
	local hours, distinct = {}, 0
	for day = 2, 41 do
		local h = d:plannedHour(day)
		check(h >= Data.game.windows[1][1] and h < Data.game.windows[1][2] - 1.0 + 1e-9, `day {day}: a morning visit, in its window ({h} h)`)
		check(d:plannedHour(day) == h, `day {day}: the same world, the same hour`)
		if not hours[string.format("%.2f", h)] then hours[string.format("%.2f", h)] = true; distinct += 1 end
	end
	check(distinct >= 30, `the hour varies from day to day ({distinct} different hours in 40 days)`)
	-- A simulated ten days, hour by hour: two visits on each of days 2..10, none on day 1.
	local s = spiderAt(CRACK)
	local windows = Data.game.windows
	local function week(resting: (number, number) -> boolean, meals: number, gentle: boolean?): { [number]: { number } }
		local w = newDirector()
		w:useGameRules()
		w.gentle = gentle == true
		local started: { [number]: { number } } = {}
		for day = 1, 10 do
			started[day] = {}
			local hour = 0.0
			while hour < 24.0 do
				w:step(DT, s, { day = day, hour = hour, resting = resting(day, hour), moulting = false, meals = meals })
				if w:isVisiting() then
					local slot = w.lastVisitSlot
					table.insert(started[day], slot)
					check(not resting(day, hour), `day {day}: not begun during a rest`)
					check(hour >= windows[slot][1] and hour < windows[slot][2], `day {day}, visit {slot}: begun by day, in its window ({hour} h)`)
					local planned = w:plannedHours(day)[slot]
					check(hour >= planned and (resting(day, planned) or hour < planned + 0.06), `day {day}, visit {slot}: begun at its planned hour {planned} (or when the rest ended), not at {hour}`)
					w:clearVisit()
				end
				hour += 0.05
			end
		end
		return started
	end
	local function count(t: { [number]: { number } }, day: number, slot: number): number
		local n = 0
		for _, v in t[day] do if v == slot then n += 1 end end
		return n
	end
	local started = week(function() return false end, 1)
	check(#started[1] == 0, "day 1: no visit")
	for day = 2, 10 do check(#started[day] == 2 and started[day][1] == 1 and started[day][2] == 2, `day {day}: exactly two visits, the morning's and the afternoon's ({#started[day]})`) end
	local gentle = week(function() return false end, 1, true)
	for day = 2, 10 do check(#gentle[day] == 2, `day {day}: Easy and Free get both visits too`) end
	local none = week(function() return false end, 0)
	local any = false
	for day = 1, 10 do any = any or #none[day] > 0 end
	check(not any, "no visit in a life that has not finished a meal")
	-- A rest through the planned hour: that visit waits for the spider to come out, still inside its window, and never begins in the rest.
	local late = week(function(_: number, hour: number): boolean return hour < 11.5 end, 1)
	for day = 2, 10 do check(#late[day] == 2, `day {day}: a rest in the morning only delays the visit ({#late[day]} visits)`) end
	-- A rest through a whole window skips that visit and no other.
	local morningRest = week(function(_: number, hour: number): boolean return hour >= 9.0 and hour < 12.5 end, 1)
	local afternoonRest = week(function(_: number, hour: number): boolean return hour >= 13.0 and hour < 17.0 end, 1)
	local allDayRest = week(function(_: number, hour: number): boolean return hour >= 9.0 and hour < 17.0 end, 1)
	for day = 2, 10 do
		check(#morningRest[day] == 1 and morningRest[day][1] == 2, `day {day}: resting through the morning window skips the morning visit only`)
		check(#afternoonRest[day] == 1 and afternoonRest[day][1] == 1, `day {day}: resting through the afternoon window skips the afternoon visit only`)
		check(#allDayRest[day] == 0, `day {day}: resting through both windows means no visit that day`)
		check(count(morningRest, day, 1) == 0 and count(afternoonRest, day, 2) == 0, `day {day}: a skipped visit is not made up later`)
	end
end)

case("two visits a day: the windows, the hours, the gap, and what a return to a checkpoint keeps (ROBLOX-75)", function()
	local W = Data.game.windows
	check(#W == 2 and W[1][1] == 9.5 and W[1][2] == 12.0 and W[2][1] == 13.5 and W[2][2] == 16.5 and Data.game.minGapH == 2.0,
		"morning 09:30 to 12:00, afternoon 13:30 to 16:30, at least two hours between the planned hours")
	-- Godot's own director: one window, the same hours as before this change (pinned from the code before it).
	local godot = newDirector()
	local pinned = { -1.0, 13.102379009408, -1.0, -1.0, 10.685306863713, -1.0, 10.573925433249, 12.768234718017 }
	local same = true
	for day = 1, 8 do same = same and math.abs(godot:plannedHour(day) - pinned[day]) < 1e-9 and #godot:plannedHours(day) == 1 end
	check(same, "an unconfigured director has one window and the very hours it always had")
	-- The game's hours: in their windows, first part, a gap, and the same for the same seed and day.
	local d = newDirector()
	d:useGameRules()
	local minGap, mornings, afternoons = math.huge, {}, {}
	for day = 2, 201 do
		local h = d:plannedHours(day)
		check(#h == 2 and h[1] >= W[1][1] and h[1] <= W[1][2] - 1.0 + 1e-9 and h[2] >= W[2][1] and h[2] <= W[2][2] - 1.0 + 1e-9, `day {day}: hours {h[1]} and {h[2]} are in the first part of their windows`)
		minGap = math.min(minGap, h[2] - h[1])
		mornings[string.format("%.3f", h[1])] = true
		afternoons[string.format("%.3f", h[2])] = true
		local again = d:plannedHours(day)
		check(again[1] == h[1] and again[2] == h[2], `day {day}: the same hours again`)
	end
	check(minGap >= 2.0 and minGap < 8, `the afternoon visit is never planned less than two hours after the morning's (least {string.format("%.2f", minGap)} h in 200 days)`)
	local m, a = 0, 0
	for _ in mornings do m += 1 end
	for _ in afternoons do a += 1 end
	check(m >= 150 and a >= 150, `the hours vary from day to day ({m} morning hours and {a} afternoon hours in 200 days)`)
	local other = newDirector()
	other.seed = 78
	other:useGameRules()
	local differ = false
	for day = 2, 20 do differ = differ or other:plannedHours(day)[2] ~= d:plannedHours(day)[2] end
	check(differ, "another world has other hours")
	pinned = { 10.172703594515, 10.904140022771, 10.135576451028, 10.867012879284 }
	local game = WaspDirector.new({ seed = 914, world = makeWorld({ FLOOR }, ref.retreat) })
	game:useGameRules()
	same = true
	for i = 1, 4 do same = same and math.abs(game:plannedHour(i + 1) - pinned[i]) < 1e-9 end
	check(same, "the world's seed 914 gives these morning hours on days 2 to 5 (pinned)")
	-- The gap is enforced, not only a product of the windows: windows that overlap still give a visit two hours after the first.
	local close = newDirector()
	close:useGameRules()
	close.windowList = { { 10.0, 14.0 }, { 10.0, 14.0 } }
	local closest = math.huge
	for day = 2, 101 do
		local h = close:plannedHours(day)
		if h[2] >= 0 then closest = math.min(closest, h[2] - h[1]) end
	end
	check(closest >= 2.0 - 1e-9, `the gap is kept even when the windows would allow less ({string.format("%.2f", closest)} h)`)
	-- Chance applies to each visit of the day.
	local unlucky = newDirector()
	unlucky:useGameRules()
	unlucky.visitChance = 0.5
	local both, one, neither = 0, 0, 0
	for day = 2, 401 do
		local h = unlucky:plannedHours(day)
		local n = (if h[1] >= 0 then 1 else 0) + (if h[2] >= 0 then 1 else 0)
		if n == 2 then both += 1 elseif n == 1 then one += 1 else neither += 1 end
	end
	check(both > 60 and one > 120 and neither > 60, `a chance below 1 is drawn for each visit alone ({both} days with both, {one} with one, {neither} with none of 400)`)

	-- Protections: day 1 and the first meal, for either visit.
	local s = spiderAt(CRACK)
	local fresh = newDirector()
	fresh:useGameRules()
	fresh:step(DT, s, { day = 1, hour = 10.5, resting = false, moulting = false, meals = 1 })
	fresh:step(DT, s, { day = 1, hour = 14.5, resting = false, moulting = false, meals = 1 })
	check(not fresh:isVisiting() and fresh.visits == 0, "day 1: neither visit")
	check(fresh:blocked({ day = 2, hour = 11, resting = false, moulting = false, meals = 0 }) == "no meal yet" and fresh:blocked({ day = 1, hour = 14, resting = false, moulting = false, meals = 3 }) == "the first day",
		"the first-meal and first-day protections apply to every visit")
	for _, hour in { 11.9, 16.4 } do
		local e = newDirector()
		e:useGameRules()
		e:step(DT, s, { day = 2, hour = hour, resting = false, moulting = false, meals = 0 })
		check(not e:isVisiting() and e.lastVisitDay == 0, `day 2, ${hour}: before the first meal nothing comes`)
	end
	-- Each visit is a full visit: the warning first, then its own place and its own draw for the rival.
	local day2 = newDirector()
	day2:useGameRules()
	local b = { day = 2, hour = day2:plannedHours(2)[1] + 0.02, resting = false, moulting = false, meals = 1 }
	day2:step(DT, s, b)
	check(day2:isVisiting() and day2.phase == "arriving" and day2.lastVisitSlot == 1 and day2.visits == 1, "the morning visit begins with the warning")
	check(day2.searchLeft == Data.searchS * 1.6, "and has the whole game search")
	day2:clearVisit()
	b.hour = day2:plannedHours(2)[2] - 0.02
	day2:step(DT, s, b)
	check(not day2:isVisiting(), "between the two, quiet")
	b.hour = day2:plannedHours(2)[2] + 0.02
	day2:step(DT, s, b)
	check(day2:isVisiting() and day2.phase == "arriving" and day2.lastVisitSlot == 2 and day2.visits == 2, "the afternoon visit begins with the warning")
	day2:clearVisit()
	b.hour = 15.9
	day2:step(DT, s, b)
	check(not day2:isVisiting() and day2.lastVisitDay == 2 and day2.lastVisitSlot == 2, "and that is all for the day")
	b.day, b.hour = 3, day2:plannedHours(3)[1] + 0.02
	day2:step(DT, s, b)
	check(day2:isVisiting() and day2.lastVisitSlot == 1 and day2.lastVisitDay == 3, "the next day starts again with a morning visit")
	local differ = 0
	for day = 2, 40 do
		local p = newDirector(nil, false)
		p:useGameRules()
		p:force(day)
		local first = p.point
		p:clearVisit()
		p:force(day)
		if p.point ~= first then differ += 1 end
	end
	check(differ >= 25, `each visit draws its own first place ({differ} of 39 days search a different place in the afternoon than in the morning)`)

	-- The rival draw is per visit: about one in ten of all visits, and a morning that takes the rival does not decide the afternoon.
	local takenMorning, takenAfternoon, both2, total = 0, 0, 0, 3000
	for seed = 1, total do
		local g = newDirector(nil, false)
		g.seed = seed
		g:useGameRules()
		g:force(2, "floor_middle")
		local first = g.takeRival
		g:clearVisit()
		g:force(2, "floor_middle")
		local second = g.takeRival
		if first then takenMorning += 1 end
		if second then takenAfternoon += 1 end
		if first and second then both2 += 1 end
	end
	check(takenMorning / total > 0.085 and takenMorning / total < 0.115 and takenAfternoon / total > 0.085 and takenAfternoon / total < 0.115,
		`each visit takes the rival about one time in ten (morning {takenMorning}, afternoon {takenAfternoon} of {total})`)
	check(both2 < total * 0.03, `and the draws are independent ({both2} of {total} took it twice, about 1 in 100)`)

	-- A return to a checkpoint: nothing is repeated and nothing is rerolled.
	local w = newDirector()
	w:useGameRules()
	local plan = w:plannedHours(4)
	w.lastVisitDay, w.lastVisitSlot, w.visits = 3, 2, 6
	local early = w:toRecord()
	w:force(4, "floor_middle") -- the day's first visit
	check(w.lastVisitDay == 4 and w.lastVisitSlot == 1 and w.visits == 7, "the first visit of the day is the first slot")
	local after1 = w:toRecord()
	w:clearVisit()
	w:force(4, "floor_middle")
	check(w.lastVisitSlot == 2 and w.visits == 8, "the second is the second")
	local after2 = w:toRecord()
	check(after1.last_visit_day == 4 and after1.last_visit_slot == 1 and after2.last_visit_slot == 2, "the record says which visit of the day was the last")
	local function runDay(rec: { [string]: number }): { number }
		local r = newDirector()
		r:useGameRules()
		r:load(rec)
		local out = {}
		local hour = 6.0
		while hour < 20.0 do
			r:step(DT, s, { day = 4, hour = hour, resting = false, moulting = false, meals = 1 })
			if r:isVisiting() then
				table.insert(out, r.lastVisitSlot)
				table.insert(out, r.visits)
				r:clearVisit()
			end
			hour += 0.05
		end
		return out
	end
	local fromEarly, from1, from2 = runDay(early), runDay(after1), runDay(after2)
	check(#fromEarly == 4 and fromEarly[1] == 1 and fromEarly[3] == 2 and fromEarly[2] == 7 and fromEarly[4] == 8, "back to a rest before the day's visits: both come again, the same two (the same visit numbers, so the same draws)")
	check(#from1 == 2 and from1[1] == 2 and from1[2] == 8, "back to a rest after the morning visit: the afternoon visit still comes, once, and the morning's does not repeat")
	check(#from2 == 0, "back to a rest after both: none")
	check(plan[1] == w:plannedHours(4)[1] and plan[2] == w:plannedHours(4)[2], "the hours are the same every time")
	-- An older record has no slot: its last visit day counts as full, so a visit is never repeated; a new life has none.
	local old = newDirector()
	old:useGameRules()
	old:load({ last_visit_day = 4, visits = 3, escapes = 1 })
	check(old.lastVisitSlot == WaspDirector.MAX_SLOTS and #runDay({ last_visit_day = 4, visits = 3, escapes = 1 }) == 0, "a record from before two visits a day: that day's visit is counted as the last")
	check(#runDay({ last_visit_day = 3, visits = 3, escapes = 1 }) == 4, "and the day after it has both visits")
	local fresh2 = WaspDirector.defaultRecord()
	check(fresh2.last_visit_slot == 0 and #WaspDirector.problems(fresh2) == 0, "a life not yet visited has slot 0")
	-- The record is checked.
	for _, bad in { -1, 3, 0.5, "x", 1 / 0 } do
		local rec = { last_visit_day = 2, last_visit_slot = bad, visits = 1, escapes = 0 }
		check(#WaspDirector.problems(rec) == 1 and string.find(WaspDirector.problems(rec)[1], "last_visit_slot", 1, true) ~= nil, `a slot of {tostring(bad)} is refused`)
	end
	check(#WaspDirector.problems({ last_visit_day = 2, visits = 1, escapes = 0 }) == 0 and #WaspDirector.problems({ last_visit_day = 2, last_visit_slot = 2, visits = 1, escapes = 0 }) == 0, "a record without a slot, or with 2, is good")
	-- The Godot director's one window: a record of one visit that day ends the day, as it always did.
	local oneWindow = newDirector()
	oneWindow:load({ last_visit_day = 5, last_visit_slot = 1, visits = 2, escapes = 0 })
	oneWindow:step(DT, s, { day = 5, hour = 12.0, resting = false, moulting = false, meals = 1 })
	check(not oneWindow:isVisiting(), "Godot's director has one visit a day")
end)

-- ------------------------------------------------------------------------------------------------------- the rival male (ROBLOX-70)
local Rival = require("../src/Shared/Predator/RivalSpider")
local Route = require("../src/Shared/Predator/RivalRoute")
local function gameDirector(seed: number?, boxes: { Box }?): any
	local d = WaspDirector.new({ seed = seed or 77, world = makeWorld(boxes or { FLOOR }, ref.retreat), enabled = false })
	d:useGameRules()
	return d
end
-- The rival on the open floor, free and still (a wasp visit pauses it).
local function rivalAt(p: Vector3, up: Vector3?): any
	return { position = p, up = up or Vector3.yAxis, present = true }
end
local RIVAL_AT = Vector3.new(12, 0.31, 3)
-- Runs a visit: the phases it passes through, its signals, and whether it noticed the spider. `rival` may be a function of the tick.
local function visit(d: any, spider: any, rival: any, maxTicks: number): ({ string }, { string }, boolean)
	local phases, kindsSeen = {}, {}
	local last = ""
	for tick = 1, maxTicks do
		local r = if type(rival) == "function" then rival(tick, d) else rival
		d:step(DT, spider, { day = 2, hour = 12.0, resting = false, moulting = false, meals = 1, rival = r })
		if d.phase ~= last then table.insert(phases, d.phase); last = d.phase end
		for _, sig in d:drainSignals() do table.insert(kindsSeen, sig.kind) end
		if d.holding then spider.position = d.heldAt end
		if d.phase == "away" and d.visitS > 0 then break end
	end
	return phases, kindsSeen, d.noticedThisVisit
end
-- A seed whose visit on day 2 is for the rival (the draw is its own stream) / one whose visit is not.
local function seedWhere(flag: boolean): number
	for seed = 1, 400 do
		local d = gameDirector(seed)
		d:force(2, "floor_middle")
		if d.takeRival == flag then return seed end
	end
	error("no seed")
end

case("the wasp takes the rival male about one visit in ten, by a draw of its own that moves nothing else (ROBLOX-70)", function()
	check(Data.game.takesRival == 0.10, "the chance is a setting in Data/Wasp.game")
	local godot = newDirector()
	godot:force(2, "floor_middle")
	check(godot.takeRival == false and godot.rivalChance == nil, "the Godot replay's wasp never goes for a rival")
	local taken, visits = 0, 4000
	local same = true
	for i = 1, visits do
		local d = gameDirector(i)
		local plain = newDirector()
		plain.seed = i
		d:force(2, "floor_middle")
		plain:force(2, "floor_middle")
		if d.takeRival then taken += 1 end
		if d.point ~= plain.point or d.searchLeft ~= plain.searchLeft * 1.6 then same = false end
	end
	local rate = taken / visits
	check(rate >= 0.085 and rate <= 0.115, `about one visit in ten is for the rival ({taken} of {visits} = {string.format("%.3f", rate)})`)
	check(same, "the other draws of a visit (its first place, its length) are as without the rival")
	local a, b = gameDirector(5), gameDirector(5)
	a:force(2, "floor_middle"); b:force(2, "floor_middle")
	check(a.takeRival == b.takeRival, "the same world, the same day, the same visit: the same draw")
	-- Over visits the rival is really there for: the rate among visits that find one.
	local took = 0
	for i = 1, 600 do
		local d = gameDirector(i)
		d:force(2, "floor_middle")
		local spider = spiderAt(OPEN)
		local _, seen = visit(d, spider, rivalAt(RIVAL_AT), 60 * 40)
		if table.find(seen, "rival_seized") then took += 1 end
	end
	check(took >= 36 and took <= 84, `with a rival on the sill, about 10% of 600 visits take it ({took})`)
end)

case("a visit for the rival: it flies to it, hangs over it, strikes, carries it off; the spider is not hunted and not caught (ROBLOX-70)", function()
	local seed = seedWhere(true)
	local d = gameDirector(seed)
	d:force(2, "floor_middle")
	local spider = spiderAt(Vector3.new(14, 0.31, 3.5)) -- close to the rival, in the open, and moving
	spider.velocity = Vector3.new(WALK, 0, 0)
	local phases, seen, noticed = {}, {}, false
	local heldHigh, maxNotice = false, 0.0
	local last = ""
	local hung = nil :: Vector3?
	for tick = 1, 60 * 40 do
		spider.position += spider.velocity * DT * (if (tick // 30) % 2 == 0 then 1 else -1)
		d:step(DT, spider, { day = 2, hour = 12.0, resting = false, moulting = false, meals = 1, rival = rivalAt(RIVAL_AT) })
		if d.phase ~= last then table.insert(phases, d.phase); last = d.phase end
		maxNotice = math.max(maxNotice, d.notice)
		for _, sig in d:drainSignals() do table.insert(seen, sig.kind) end
		if d.holdingRival then
			hung = d.rivalHeldAt
			check(close(d.rivalHeldAt :: Vector3, d.wasp.position + Vector3.new(0, -Data.holdBelow, 0), 1e-6), "the rival hangs under the wasp like a held spider")
			if d.rivalHeldAt.Y > 10 then heldHigh = true end
		end
		if d.phase == "away" and d.visitS > 0 then break end
	end
	check(table.concat(phases, ",") == "arriving,taking,seizing,bearing,away", `arriving, taking, seizing, bearing: {table.concat(phases, ",")}`)
	check(table.concat(seen, ",") == "visit_started,rival_seized,rival_carried_off", `signals: {table.concat(seen, ",")}`)
	check(maxNotice == 0.0 and not d.noticedThisVisit and not d.holding and d.heldAt == nil and d.escapes == 0, "it never looked for the spider: no notice, no catch, no escape counted")
	check(heldHigh and hung ~= nil, "the rival is carried up and away over the frame")
	check(not d.wasp.visible and not d.holdingRival and d.rivalHeldAt == nil, "and then it is gone")
	check(d.visitS > Data.arriveS + Data.rival.hoverS + Data.rival.strikeS + Data.carryS - 0.5 and d.visitS < Data.arriveS + 25, `the visit is short ({string.format("%.1f", d.visitS)} s)`)
	check(d.lastVisitDay == 2 and d.visits == 1, "it counts as that day's visit: no second wasp today")
	d:step(DT, spider, { day = 2, hour = 13.0, resting = false, moulting = false, meals = 1, rival = rivalAt(RIVAL_AT) })
	check(not d:isVisiting(), "and none comes later the same day")
	-- Sat in plain sight right under it, still: not noticed either.
	local e = gameDirector(seed)
	e:force(2, "floor_middle")
	local still = spiderAt(RIVAL_AT + Vector3.new(1.0, 0, 0))
	local ph, sg, noticed2 = visit(e, still, rivalAt(RIVAL_AT), 60 * 40)
	check(not noticed2 and not table.find(ph, "inspecting") and not table.find(ph, "striking") and table.find(sg, "rival_seized") ~= nil, "a spider beside the rival is not hunted")
end)

case("no rival, no taking: with none on the sill, or in the retreat, or out of reach, the visit is the spider's as ever (ROBLOX-70)", function()
	local seed = seedWhere(true)
	for name, rival in {
		none = nil,
		absent = { position = RIVAL_AT, up = Vector3.yAxis, present = false },
		crack = rivalAt(Vector3.new(-25, 0.31, 6)),
	} do
		local d = gameDirector(seed)
		d:force(2, "floor_middle")
		local spider = spiderAt(OPEN)
		local ph, sg = visit(d, spider, rival, 60 * 30)
		check(table.find(ph, "taking") == nil and table.find(sg, "rival_seized") == nil, `{name}: it does not go for a rival`)
		check(table.find(ph, "searching") ~= nil, `{name}: it searches for the spider instead`)
	end
	-- A rival under a wide roof, out of reach from above and from the sides: the visit is the spider's.
	local roof: Box = { min = Vector3.new(-4, 1.0, -4), max = Vector3.new(28, 1.2, 14) }
	local d = gameDirector(seed, { FLOOR, roof })
	d:force(2, "floor_middle")
	local ph, sg = visit(d, spiderAt(Vector3.new(-30, 0.31, 6)), rivalAt(RIVAL_AT), 60 * 30)
	check(table.find(ph, "taking") == nil and table.find(sg, "rival_seized") == nil and table.find(ph, "searching") ~= nil, "under a roof it cannot get at, it searches")
	-- A visit not for the rival never looks at one.
	local other = seedWhere(false)
	local o = gameDirector(other)
	o:force(2, "floor_middle")
	local ph2, sg2 = visit(o, spiderAt(OPEN), rivalAt(RIVAL_AT), 60 * 30)
	check(table.find(ph2, "taking") == nil and table.find(sg2, "rival_seized") == nil, "a visit that is not for the rival leaves it alone")
	-- The rival is caught by the spider (or leaves) on the way: the wasp goes on searching, and can still find the spider.
	local c = gameDirector(seed)
	c:force(2, "floor_middle")
	local gone = false
	local ph3, sg3, noticed3 = visit(c, spiderAt(Vector3.new(2, 0.31, 6)), function(_: number, dir: any): any
		if dir.phase == "taking" then gone = true end
		return if gone then { position = RIVAL_AT, up = Vector3.yAxis, present = false } else rivalAt(RIVAL_AT)
	end, 60 * 60)
	check(gone and table.find(ph3, "taking") ~= nil and table.find(sg3, "rival_seized") == nil and table.find(ph3, "searching") ~= nil, "a rival that is gone before the strike is not taken; the search goes on")
	check(c.holdingRival == false and c.rivalHeldAt == nil, "and nothing is held")
	local _ = noticed3
end)

case("the wasp can get at most places the rival walks on (ROBLOX-70)", function()
	local boxes: { Box } = {}
	for _, piece in Layout.PIECES do table.insert(boxes, { min = piece.lo, max = piece.hi }) end
	local world = makeWorld(boxes, ref.retreat)
	world.inRetreat = function(p: Vector3): boolean return Layout.inRetreat(p) end
	local d = WaspDirector.new({ seed = 77, world = world, enabled = false })
	d:useGameRules()
	local drive = require("../src/Shared/Predator/RivalDrive").new({}, function() return true end)
	local reach, total = 0, 0
	for _, w in drive.waypoints do
		total += 1
		d:clearVisit()
		d.rivalNow = { position = w.pos + w.up * Route.SEAT, up = w.up, present = true }
		d.wasp.position = Data.points[1].hover
		d.openPos = d.wasp.position
		d.path, d.pathI = { d.wasp.position }, 2
		if d:_beginTaking() then reach += 1 end
	end
	print(string.format("WASP rival reach: %d of %d places the rival patrols to can be reached by the wasp", reach, total))
	check(total > 80 and reach / total >= 0.6, `the wasp can get at most of them ({reach} of {total})`)
end)

case("the rival's fate: seized, carried off, gone for today, a new one next morning; the record keeps why (ROBLOX-70)", function()
	local r = Rival.new()
	check(Rival.target(r) == nil and not Rival.seize(r), "a rival that has not arrived cannot be taken")
	r.state = "patrol"
	r.position = Vector3.new(12, 0.31, 3)
	check(Rival.target(r) ~= nil and Rival.target(r).present, "a free rival on the sill can")
	r.state = "lunge"
	check(Rival.target(r) == nil, "not in the air mid-lunge")
	r.state = "captured"
	check(Rival.target(r) == nil and not Rival.seize(r), "not while the spider has it")
	r.state = "recover"
	r.position = Vector3.new(-25, 0.31, 6)
	check(Rival.target(r) == nil, "not in the retreat")
	r.position = Vector3.new(12, 0.31, 3)
	check(Rival.seize(r) and r.state == "taken" and Rival.percept(r) == nil, "seized, it is not a percept")
	local s = { position = Vector3.new(11, 0.31, 3), previous = Vector3.new(11, 0.31, 3), heading = Vector3.xAxis, day = 3, hour = 13, meals = 2, resting = false,
		safe = false, wasp = true, gentle = false, grounded = true, moving = false, airborne = false, onLine = false, holding = false, striking = true, taken = true }
	local ev, food = Rival.step(r, DT, s, function() return false end)
	check(r.state == "taken" and ev == "" and food == 0, "held by the wasp, the spider's strike cannot catch it")
	r.position = Vector3.new(27, 16, 2) -- carried up over the frame: a valid record
	check(Rival.valid(r), "a rival hanging under the wasp, outside the play bounds, is a valid record")
	Rival.carried(r, 3)
	check(r.state == "consumed" and r.food == 0 and r.day == 3 and r.fate == "taken by the wasp" and Rival.valid(r), "carried off: gone, food for no one, the day and the reason kept")
	s.wasp, s.taken, s.striking = false, false, false
	local ev2, food2 = Rival.step(r, DT, s, function() return false end)
	check(r.state == "consumed" and ev2 == "" and food2 == 0, "the same day nothing new comes")
	s.day, s.hour = 4, 6.5
	Rival.step(r, DT, s, function() return false end)
	check(r.state == "consumed", "nor before the morning")
	s.hour = 7.2
	Rival.step(r, DT, s, function() return false end)
	check(r.state == "patrol" and r.day == nil and r.fate == nil and r.food == Rival.FOOD, "the next morning a new rival is on the sill")
	-- A record taken while the wasp held the rival: the wasp is gone after a return, so the rival is carried off.
	local held = Rival.new()
	held.state, held.position = "patrol", Vector3.new(12, 0.31, 3)
	Rival.seize(held)
	s.day, s.hour, s.taken = 5, 12, false
	local ev3 = Rival.step(held, DT, s, function() return false end)
	check(ev3 == "taken" and held.state == "consumed" and held.day == 5 and held.fate == "taken by the wasp", "a rival still held when the wasp is no longer there is gone")
	-- An eaten rival says so; a bad reason is refused.
	local eaten = Rival.new()
	eaten.state, eaten.position, eaten.food = "captured", Vector3.new(12, 0.31, 3), 0.001
	s.position, s.heading, s.moving, s.grounded = Vector3.new(12, 0.31, 3), Vector3.xAxis, false, true
	for _ = 1, 20 do Rival.step(eaten, DT, s, function() return false end) end
	check(eaten.state == "consumed" and eaten.fate == "eaten", "an eaten rival is marked eaten")
	for _, bad in { 3, true, "elf", "" } do
		eaten.fate = bad
		check(not Rival.valid(eaten), `a fate of {tostring(bad)} is refused`)
	end
	eaten.fate = nil
	check(Rival.valid(eaten), "and no fate at all (an older record) is fine")
end)

case("the words of the wasp taking the rival: captions and lines only for a spider that hears or sees (ROBLOX-70)", function()
	local seized = WaspText.caption("seizing", 0, "ahead-left")
	check(seized ~= nil and seized.text == "[the deep hum drops toward something on the sill, ahead-left]", "it drops toward something")
	check(WaspText.caption("taking", 0, "left") ~= nil, "and while it hangs over it")
	local bearing = WaspText.caption("bearing", 0, "above")
	check(bearing ~= nil and bearing.text == "[a short scuffle, then the deep hum rising away with something, above]", "and carries it off")
	for _, phase in { "taking", "seizing", "bearing" } do
		local c = WaspText.caption(phase, 0, "ahead") :: any
		check(string.sub(c.text, 1, 8) ~= "[buzzing" and string.find(c.text, "you", 1, true) == nil, "not the flies' words, and not about the spider")
		check(WaspText.line(phase, false, 1, false, "keyboard" :: any) ~= nil, `a status line for {phase}`)
	end
	check(WaspText.heardRival(Data.rival.earshotWu, false) and not WaspText.heardRival(Data.rival.earshotWu + 0.1, false), "heard within earshot")
	check(WaspText.heardRival(Data.rival.sightWu, true) and not WaspText.heardRival(Data.rival.sightWu + 0.1, true) and not WaspText.heardRival(Data.rival.sightWu, false), "or seen, further")
	check(string.find(WaspText.RIVAL_TAKEN, "other spider", 1, true) ~= nil, "the notice says what happened")
end)

print(`WASP passed={passed} failed={failed}`)
