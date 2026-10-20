-- Nature's rules (ROBLOX-106, W4 of docs/OPEN_WORLD_DESIGN.md): movement costs energy (NeedsModel.game.moveCost, Life/Nature.moved), cover and stillness against
-- the wasp's and the rival's notice (Life/Nature.cover), the wasp's visits that slide and linger (Data/Wasp.game.nature), the rival's watch by the crack
-- (Data/RivalRules.camp, Predator/RivalDrive), courtship that can fail and the rival that cuts in (Data/MatingRules.game, Predator/Mate, Life/Mating), the night in
-- the garden (Life/Nature.night) and the end screen's words (UI/LifeText). Each is seeded, gated to the standard rules, and restore-stable; the real checkpoint
-- keeps the new optional fields and an old record has none. The real motor and the rival's drive walk the box world of tests/shim.luau. Not engine evidence.
-- Run with the other suites:  python3 tests/run.py path/to/luau nature.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local LifeSession = require("../src/Shared/Life/LifeSession")
local Growth = require("../src/Shared/Life/Growth")
local Nature = require("../src/Shared/Life/Nature")
local Wasp = require("../src/Shared/Data/Wasp")
local WaspDirector = require("../src/Shared/Predator/WaspDirector")
local RivalRules = require("../src/Shared/Data/RivalRules")
local Rival = require("../src/Shared/Predator/RivalSpider")
local Route = require("../src/Shared/Predator/RivalRoute")
local Drive = require("../src/Shared/Predator/RivalDrive")
local MatingRules = require("../src/Shared/Data/MatingRules")
local Mate = require("../src/Shared/Predator/Mate")
local Mating = require("../src/Shared/Life/Mating")
local MateText = require("../src/Shared/UI/MateText")
local LifeText = require("../src/Shared/UI/LifeText")
local WorldMap = require("../src/Shared/World/WorldMap")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local Json = require("../src/Shared/Persistence/Json")

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
local sill = BoxWorld.folder("NatureSill", Layout.PIECES)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }
local function ray(from: Vector3, dir: Vector3): any return workspace:Raycast(from, dir, params) end

local function newMotor(at: Vector3?, heading: Vector3?): any
	return Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = at or Layout.SPAWN,
		heading = heading or Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = sill,
	})
end

local PreyRandom = require("../src/Shared/Prey/PreyRandom")

case("W4's draws come from hashed streams: the same numbers give the same stream, and neighbouring days are not offsets of one another", function()
	local a, b = PreyRandom.mixed(914, 5, 3, 47), PreyRandom.mixed(914, 5, 3, 47)
	check(a:next() == b:next() and a:next() == b:next(), "the same numbers, the same draws")
	check(PreyRandom.mixed(914, 5, 3, 47):next() ~= PreyRandom.mixed(914, 6, 3, 47):next() and PreyRandom.mixed(914, 5, 3, 47):next() ~= PreyRandom.mixed(78, 5, 3, 47):next(),
		"another day or another world, another draw")
	local xs, n, sum = {}, 2000, 0
	for day = 1, n do xs[day] = PreyRandom.mixed(914, day, 1, 47):next(); sum += xs[day] end
	local mean = sum / n
	local num, den = 0, 0
	for i = 1, n do
		den += (xs[i] - mean) ^ 2
		if i < n then num += (xs[i] - mean) * (xs[i + 1] - mean) end
	end
	local lag = num / den
	-- The old linear mix, for comparison: its first draws step by a constant.
	local steps = {}
	local distinct = 0
	for day = 1, 200 do
		local r = PreyRandom.new((914 * 73856093 + (day * 1009 + 47) * 19349663 + 12345) % 2147483647)
		local r2 = PreyRandom.new((914 * 73856093 + ((day + 1) * 1009 + 47) * 19349663 + 12345) % 2147483647)
		local key = string.format("%.6f", (r2:next() - r:next()) % 1)
		if not steps[key] then steps[key] = true; distinct += 1 end
	end
	check(math.abs(mean - 0.5) < 0.03 and math.abs(lag) < 0.08, `the hashed first draws are even and unrelated day to day (mean {string.format("%.3f", mean)}, lag-one correlation {string.format("%.3f", lag)})`)
	check(distinct <= 2, `(the linear mix steps by a constant: {distinct} different steps in 200 days)`)
end)

-- ----------------------------------------------------------------------------------------------------------------- movement

case("movement costs energy in the standard rules: walking, the line, a jump; nothing standing; the three days' numbers", function()
	local c = NeedsModel.game.moveCost
	check(c.walkPerS == 0.0004 and c.linePerS == 0.0002 and c.jump == 0.002, "the game's numbers: 0.0004 a second walking, 0.0002 on the line, 0.002 a jump")
	check(NeedsModel.game.drain == 2.4 and NeedsModel.LIFE_DRAIN_AWAKE_PER_H == 0.021 and NeedsModel.LIFE_DRAIN_ASLEEP_PER_H == 0.007, "Godot's rates and ROBLOX-102's drain are untouched")
	local godot = NeedsModel.new(true, false)
	check(godot:moveCostOf("walk", DT) == 0 and godot:move("jump", DT) == 0 and godot.energy == NeedsModel.ENERGY_START, "a model never given the game's rules is Godot's: movement is free")
	local gentle = NeedsModel.new(true, true)
	gentle:useGameRules()
	check(gentle:move("walk", 1) == 0 and gentle:move("jump", 0) == 0 and gentle.energy == NeedsModel.ENERGY_START, "the gentle modes (Easy, Free play) pay nothing")
	local sandbox = NeedsModel.new(false, false)
	sandbox:useGameRules()
	check(sandbox:move("walk", 0.2) == 0, "nor does Godot's lab sandbox")
	local n = NeedsModel.new(true, false)
	n:useGameRules()
	check(n.moveCosts == true, "the game's rules turn it on (a flag, so a record carries no copy of the numbers)")
	near(n:moveCostOf("walk", DT), 0.0004 * DT, 1e-15, "a tick of walking")
	near(n:moveCostOf("line", DT), 0.0002 * DT, 1e-15, "a tick on the line")
	near(n:moveCostOf("jump", DT), 0.002, 1e-15, "a jump, once")
	check(n:moveCostOf("stand", DT) == 0 and n:moveCostOf("", DT) == 0 and n:moveCostOf("walk", 0) == 0 and n:moveCostOf("walk", 0 / 0) == 0, "standing, nothing, no time: free")
	near(n:moveCostOf("walk", 5), 0.0004 * NeedsModel.MAX_STEP_S, 1e-15, "a stall is a capped step")
	local before = n.energy
	local seen = 0
	n.onEnergyChanged = function() seen += 1 end
	check(math.abs(n:move("jump", DT) - 0.002) < 1e-15 and math.abs(before - n.energy - 0.002) < 1e-12 and seen == 1, "paid from the reserve at once, and told")
	-- The three days of the decision, from the model's own numbers: the drain's day, then the legs.
	local day = 11 * NeedsModel.LIFE_DRAIN_AWAKE_PER_H * 2.4 + 13 * NeedsModel.LIFE_DRAIN_ASLEEP_PER_H * 2.4
	local function legs(walkS: number, jumps: number, lineS: number): number
		local m = NeedsModel.new(true, false)
		m:useGameRules()
		local cost = 0
		for _ = 1, math.floor(walkS / 0.25 + 0.5) do cost += m:moveCostOf("walk", 0.25) end
		for _ = 1, jumps do cost += m:moveCostOf("jump", 0) end
		for _ = 1, math.floor(lineS / 0.25 + 0.5) do cost += m:moveCostOf("line", 0.25) end
		return cost
	end
	near(day, 0.7728, 1e-9, "a still day costs the drain's 0.773")
	near(day + legs(275, 30, 60), 0.9548, 1e-9, "a typical day (275 s walking, 30 jumps, a minute on the line) 0.955")
	near(day + legs(550, 100, 180), 1.2288, 1e-9, "a restless day (550 s walking, 100 jumps, three minutes on the line) 1.229")
	check((day + legs(275, 30, 60)) / 0.35 < 3 and (day + legs(550, 100, 180)) / 0.35 > 3.4, "a careful hunter keeps up on three houseflies a day; a restless one needs three and a half")
	-- What the reserve cannot pay is starving time at the awake rate.
	local s = NeedsModel.new(true, false)
	s:useGameRules()
	s.energy = 0.0005
	local paid = s:move("jump", 0)
	near(paid, 0.0005, 1e-15, "it pays what it has")
	check(s.energy == 0, "and is empty")
	near(s.starvingStreakH, 0.0015 / (0.021 * 2.4), 1e-12, "the rest is starving time")
	check(s:move("walk", 0.25) == 0 and s.starvingStreakH > 0.0015 / (0.021 * 2.4), "an empty spider that walks starves faster")
end)

case("what moved: the motor walks, hops and hangs, and each tick is one kind or none", function()
	local st = {}
	check(Nature.moved(st, "attached", false, false, false, false, nil) == "", "standing")
	check(Nature.moved(st, "attached", true, false, false, false, nil) == "walk", "walking")
	check(Nature.moved(st, "air", true, false, false, false, nil) == "jump", "leaving the surface by a jump")
	check(Nature.moved(st, "air", false, false, false, false, nil) == "", "in the air: nothing more")
	check(Nature.moved(st, "air", false, false, false, true, 3.0) == "", "caught on the line, first tick")
	check(Nature.moved(st, "air", false, false, false, true, 3.0) == "", "hanging still")
	check(Nature.moved(st, "air", false, false, false, true, 3.1) == "line", "letting down")
	check(Nature.moved(st, "air", false, false, false, true, 3.0) == "line", "reeling in")
	check(Nature.moved(st, "attached", false, false, false, false, nil) == "", "back on a surface")
	check(Nature.moved(st, "air", false, true, false, false, nil) == "", "a drop off an edge is not a jump")
	check(Nature.moved(st, "attached", true, false, true, false, nil) == "", "a seized spider does nothing")
	-- The real motor on the box sill: two seconds of walking, a hop, standing.
	local m = newMotor(Vector3.new(10, 0.31, 8), Vector3.xAxis)
	local needs = NeedsModel.new(true, false)
	needs:useGameRules()
	needs.energy = 0.9
	local mv = {}
	local counts = { walk = 0, jump = 0, line = 0 }
	local input = Motor.idleInput()
	input.wish = Vector3.new(-1, 0, 0)
	for _ = 1, 120 do
		m:tick(input)
		local k = Nature.moved(mv, m.mode, m.moving == true, m.dropped == true, m.seized == true, m:onLine(), if m:onLine() then m.silk.rest else nil)
		if k ~= "" then counts[k] += 1; needs:move(k, DT) end
	end
	check(counts.walk >= 110 and counts.jump == 0, `two seconds of walking are walking ({counts.walk} ticks)`)
	near(0.9 - needs.energy, counts.walk * 0.0004 * DT, 1e-12, "and cost what they say")
	local idle = Motor.idleInput()
	for _ = 1, 30 do m:tick(idle); Nature.moved(mv, m.mode, m.moving == true, m.dropped == true, m.seized == true, m:onLine(), nil) end
	local plan = m:hopPlan()
	check(plan ~= nil and plan.kind == "reachable" and m:commit(plan), "a hop")
	local jumps, after = 0, needs.energy
	for _ = 1, 90 do
		m:tick(idle)
		local k = Nature.moved(mv, m.mode, m.moving == true, m.dropped == true, m.seized == true, m:onLine(), if m:onLine() then m.silk.rest else nil)
		if k == "jump" then jumps += 1 end
		if k ~= "" then needs:move(k, DT) end
	end
	check(jumps == 1 and m.mode == "attached", `one jump, counted once as it left (and it landed: {m.mode})`)
	near(after - needs.energy, 0.002, 1e-12, "the hop cost 0.002")
	local still = needs.energy
	for _ = 1, 120 do
		m:tick(idle)
		local k = Nature.moved(mv, m.mode, m.moving == true, m.dropped == true, m.seized == true, m:onLine(), nil)
		if k ~= "" then needs:move(k, DT) end
	end
	check(needs.energy == still, "two seconds standing cost nothing extra")
end)

-- ----------------------------------------------------------------------------------------------------------------- cover

case("cover: a leaf overhead and stillness halve a predator's notice, moving in the open doubles it", function()
	local g = Nature.game
	check(g.covered == 0.5 and g.still == 0.5 and g.openMoving == 2.0 and g.coverWu == 6.0, "the numbers")
	check(Nature.cover(false, false) == 2.0 and Nature.cover(true, false) == 0.5 and Nature.cover(false, true) == 0.5 and Nature.cover(true, true) == 0.25,
		"moving in the open 2, under a leaf 0.5, still 0.5, still under a leaf 0.25")
	check(Nature.overhead(Vector3.new(-15, 0.31, -1.5), ray), "on the floor under the west leaf: covered")
	check(not Nature.overhead(Vector3.new(0, 0.31, 8), ray), "on the open floor at the front: not")
	check(not Nature.overhead(Vector3.new(-15, 4.35, -1.5), ray), "on top of the leaf: not (the sky)")
	-- The wasp: its notice rate times the factor, in the standard rules only.
	local function director(): any
		return WaspDirector.new({ seed = 914, world = { ray = function() return false end, clear = function() return true end, inRetreat = function() return false end } })
	end
	local w = director()
	w:useGameRules()
	w:force(2, "floor_middle")
	w.spider = { position = w:eyePosition() + Vector3.xAxis, velocity = Vector3.zero, walkSpeed = 1, airborne = false, falling = false }
	local base = w:noticeRate()
	w.spider.cover = 0.25
	check(w:noticeRate() == base, "a director not given nature's rules ignores the factor (Godot's and the old game's)")
	w.nature = true
	near(w:noticeRate() / base, 0.25, 1e-12, "with them, still under a leaf: a quarter")
	w.spider.cover = 2.0
	near(w:noticeRate() / base, 2.0, 1e-12, "moving in the open: double")
	w.gentle = true
	check(w:noticeRate() == base, "the gentle wasp: as it was")
	-- The rival: its notice grows at the factor while it sees the spider.
	local function noticeAfter(scale: number?): number
		local r = Rival.new()
		r.state, r.position, r.previous = "patrol", Vector3.new(20, 0.31, 8), Vector3.new(20, 0.31, 8)
		local s = { position = Vector3.new(24, 0.31, 8), previous = Vector3.new(24, 0.31, 8), heading = -Vector3.xAxis, day = 3, hour = 12, meals = 2, noticeScale = scale }
		for _ = 1, 12 do Rival.step(r, DT, s, function() return false end) end
		return r.notice
	end
	near(noticeAfter(nil), 12 * DT, 1e-12, "without a factor the rival's notice rises one a second")
	near(noticeAfter(0.5), 6 * DT, 1e-12, "halved")
	near(noticeAfter(2.0), 24 * DT, 1e-12, "doubled")
	near(noticeAfter(0.25) / noticeAfter(nil), 0.25, 1e-9, "a quarter")
	local r = Rival.new()
	r.state, r.position, r.previous = "patrol", Vector3.new(20, 0.31, 8), Vector3.new(20, 0.31, 8)
	local s = { position = Vector3.new(24, 0.31, 8), previous = Vector3.new(24, 0.31, 8), heading = -Vector3.xAxis, day = 3, hour = 12, meals = 2, noticeScale = 2.0 }
	local t = 0
	while r.state == "patrol" and t < 600 do Rival.step(r, DT, s, function() return false end); t += 1 end
	near(t * DT, RivalRules.stalkNotice / 2, 2 * DT, "moving in the open, it stalks in half the time")
end)

-- ----------------------------------------------------------------------------------------------------------------- the wasp

local function waspOf(seed: number?, natural: boolean?): any
	local w = WaspDirector.new({ seed = seed or 914, world = { ray = function() return false end, clear = function() return true end, inRetreat = function() return true end } })
	w:useGameRules()
	w.nature = natural ~= false
	return w
end

case("the wasp's windows slide from day to day and its visits vary and sometimes linger, from the seed, in the standard rules only", function()
	local n = Wasp.game.nature
	check(n.shiftH == 1.0 and n.visit[1] == 0.6 and n.visit[2] == 1.5 and n.lingerChance == 0.08 and n.linger[1] == 3.0 and n.linger[2] == 5.0, "the numbers")
	local plain = waspOf(914, false)
	local W = Wasp.game.windows
	for day = 2, 30 do
		local dw = plain:dayWindows(day)
		check(dw[1][1] == W[1][1] and dw[2][2] == W[2][2], "without nature's rules the windows are the game's")
	end
	check(plain:visitScale(5, 3) == 1.0, "and every visit is the whole search")
	local w = waspOf()
	local shifts, distinct = {}, 0
	local minGap, maxEnd = math.huge, -math.huge
	for day = 2, 401 do
		local dw = w:dayWindows(day)
		for slot = 1, 2 do
			local d = dw[slot][1] - W[slot][1]
			check(math.abs(d) <= 1.0 + 1e-9 and math.abs((dw[slot][2] - dw[slot][1]) - (W[slot][2] - W[slot][1])) < 1e-9, `day {day}: window {slot} slides by at most an hour ({d})`)
			local key = string.format("%.4f", d)
			if not shifts[key] then shifts[key] = true; distinct += 1 end
		end
		local h = w:plannedHours(day)
		check(h[1] >= dw[1][1] - 1e-9 and h[1] < dw[1][2] and h[2] >= dw[2][1] - 1e-9 and h[2] < dw[2][2], `day {day}: the planned hours are inside the day's windows`)
		minGap = math.min(minGap, h[2] - h[1])
		maxEnd = math.max(maxEnd, dw[2][2])
		local again = w:plannedHours(day)
		check(again[1] == h[1] and again[2] == h[2], "the same day, the same hours")
	end
	check(distinct > 300, `the windows do not keep to the clock ({distinct} different shifts in 800 windows)`)
	check(minGap >= 2.0 - 1e-9 and maxEnd <= 17.5 + 1e-9, `the gap still holds ({string.format("%.2f", minGap)} h) and nothing comes after 17:30`)
	-- The visits' lengths.
	local lingers, total, sum, count = 0, 4000, 0, 0
	local lo, hi = math.huge, -math.huge
	for k = 1, total do
		local day, visit = 2 + (k % 200), 1 + (k // 200)
		local scale, lingering = w:visitScale(day, visit)
		local again, also = w:visitScale(day, visit)
		check(again == scale and also == lingering, "the same visit, the same length")
		if lingering then
			lingers += 1
			check(scale >= 3.0 and scale < 5.0, "a lingering visit is three to five times as long")
		else
			sum += scale; count += 1
			lo, hi = math.min(lo, scale), math.max(hi, scale)
		end
	end
	check(lingers / total > 0.065 and lingers / total < 0.095, `about one visit in twelve lingers ({lingers} of {total})`)
	check(lo >= 0.6 and hi < 1.5 and math.abs(sum / count - 1.05) < 0.02, `the rest vary from 0.6 to 1.5 of the search, about 1.05 on average ({string.format("%.3f", sum / count)})`)
	local gentle = waspOf()
	gentle.gentle = true
	check(gentle:visitScale(5, 3) == 1.0 and gentle:dayWindows(5)[1][1] == W[1][1], "the gentle wasp keeps the game's windows and visits")
end)

case("a lingering visit searches for minutes, and a return to a rest meets the same visit again", function()
	-- Find the first lingering visit of seed 914 among the first days' visits.
	local w = waspOf()
	local day, visit
	for d = 2, 200 do
		for v = 1, 20 do
			local _, l = w:visitScale(d, v)
			if l and day == nil then day, visit = d, v end
		end
	end
	check(day ~= nil, "seed 914 has lingering visits")
	local scale = w:visitScale(day, visit)
	w:load({ last_visit_day = day - 1, last_visit_slot = 2, visits = visit - 1, escapes = 0 })
	w:force(day, "floor_middle")
	check(w.visits == visit and w.lingers == true, `visit {visit} of day {day} lingers`)
	near(w.searchLeft, Wasp.searchS * 1.6 * scale, 1e-9, "its search is the game's 72 s times the draw")
	local spider = { position = Vector3.new(-25.5, 0.31, 6), velocity = Vector3.zero, walkSpeed = 1, airborne = false, falling = false }
	local block = { day = day, hour = 12, resting = false, moulting = false, meals = 3 }
	local t = 0
	while w:isVisiting() and t < 60 * 600 do w:step(DT, spider, block); t += 1 end
	check(t * DT > 3 * 72 and t * DT < 5 * 72 + 30, `a spider in the crack waits it out: {string.format("%.0f", t * DT)} s of wasp`)
	-- The record keeps the day and the count; a return to it meets the same visit, as long.
	local rec = { last_visit_day = day - 1, last_visit_slot = 2, visits = visit - 1, escapes = 0 }
	local again = waspOf()
	again:load(rec)
	again:force(day, "floor_middle")
	check(again.searchLeft == Wasp.searchS * 1.6 * scale and again.lingers, "restored, the same lingering visit")
	local other = waspOf(78)
	other:load(rec)
	other:force(day, "floor_middle")
	check(other.searchLeft ~= again.searchLeft, "another world, another visit")
	check(#WaspDirector.problems(rec) == 0, "the wasp's record is as it was: nothing new in it")
end)

-- ----------------------------------------------------------------------------------------------------------------- the rival's watch

local function newRival(surface: Vector3, up: Vector3): (any, any, any)
	local m = newMotor(surface + up * Route.SEAT, Vector3.new(-1, 0, 0))
	local d = Drive.new(m, function() return false end)
	local r = Rival.new()
	r.state = "patrol"
	m:place(surface + up * Route.SEAT, up, Vector3.new(-1, 0, 0))
	r.position, r.previous, r.up, r.heading, r.origin = m.pos, m.pos, m.up, m.heading, m.pos
	d.prevState = "patrol"
	return d, r, m
end
local function snapshot(nature: boolean?): any
	return { position = Vector3.new(25, 0.31, -8), previous = Vector3.new(25, 0.31, -8), up = Vector3.yAxis, grounded = true, heading = Vector3.xAxis,
		day = 3, hour = 12, meals = 2, resting = false, safe = false, wasp = false, gentle = false, moving = false, airborne = false,
		onLine = false, holding = false, striking = false, seed = 914, nature = nature }
end

case("the rival's watch by the crack: some legs, near the door and outside the keep-out, for one to three minutes, from the seed", function()
	local c = RivalRules.camp
	check(c.chance == 0.15 and c.seconds[1] == 60 and c.seconds[2] == 180 and #c.spots == 4, "the numbers")
	local d = newRival(Vector3.new(20, 0, 8), Vector3.yAxis)
	local door = WorldMap.retreat("sill_crevice").door :: Vector3
	local places = d:campPlaces()
	check(#places == 4, `every spot is a place to watch from ({#places})`)
	for _, w in places do
		local dist = (w.pos - door).Magnitude
		local seat = w.pos + w.up * Route.SEAT
		local clear = math.min(seat.X - RivalRules.keepOutMax.X, if seat.Z > RivalRules.keepOutMax.Z then seat.Z - RivalRules.keepOutMax.Z else math.huge)
		check(dist >= 2.0 and dist <= 5.5 and not Route.inKeepOut(seat) and not Layout.inRetreat(seat) and (seat.X > RivalRules.keepOutMax.X + 1 - 1e-9 or seat.Z > RivalRules.keepOutMax.Z + 1 - 1e-9),
			`a watch place {string.format("%.1f", dist)} from the door, a stud or more outside the keep-out ({clear})`)
		check(w.face ~= nil and w.up == Vector3.yAxis, "on the floor's face")
	end
	local other = Drive.new(newMotor(), function() return false end, "bed_a")
	check(#other:campPlaces() == 0, "a drive in another region has none (the spots are the sill's)")
	local camps, total = 0, 3000
	for leg = 0, total - 1 do
		local w, secs = d:campLeg(914, leg)
		local w2, s2 = d:campLeg(914, leg)
		check(w == w2 and secs == s2, "the same leg, the same watch")
		if w ~= nil then
			camps += 1
			check(secs >= 60 and secs < 180, "one to three minutes")
		end
	end
	check(camps / total > 0.13 and camps / total < 0.17, `about one leg in seven is a watch ({camps} of {total})`)
	-- Without nature's rules (or without being told it camps) no leg is.
	local legsCamp = 0
	for leg = 0, 200 do
		local r = Rival.new()
		r.leg = leg
		d.camps = nil
		local w1 = d:_pickWaypoint(r, snapshot(true))
		d.camps = true
		local w2 = d:_pickWaypoint(r, snapshot(false))
		if d.campHere then legsCamp += 1 end
		check(w1 ~= nil and w2 ~= nil, "a patrol place")
	end
	check(legsCamp == 0, "no watch for a drive not told it camps, nor in the gentle modes")
end)

case("on a watch leg it walks to the crack's mouth, stands its time, never enters the keep-out, then patrols on; a restored watch goes on", function()
	local d, r = newRival(Vector3.new(20, 0, 8), Vector3.yAxis)
	d.camps = true
	local leg
	for l = 0, 200 do if leg == nil and d:campLeg(914, l) ~= nil then leg = l end end
	check(leg ~= nil, "a watch leg")
	r.leg = leg
	local w, secs = d:campLeg(914, leg)
	local s = snapshot(true)
	local arrived, inKeep, standing, start = nil, 0, 0, nil
	local snap: any = nil
	for k = 1, 60 * 400 do
		Drive.update(d, r, DT, s)
		if Route.inKeepOut(d.motor.pos) or Layout.inRetreat(d.motor.pos) then inKeep += 1 end
		if r.camp ~= nil and arrived == nil then arrived = k * DT; start = d.motor.pos end
		if arrived ~= nil and r.camp ~= nil then
			if (d.motor.pos - start).Magnitude < 0.05 then standing += 1 end
			if snap == nil and r.camp < secs / 2 then snap = { camp = r.camp, leg = r.leg, pos = r.position, up = r.up, heading = r.heading } end
		end
		if arrived ~= nil and r.camp == nil then break end
	end
	check(arrived ~= nil, `it reached its watch (in {arrived} s)`)
	check(start ~= nil and (start - (w.pos + w.up * Route.SEAT)).Magnitude < 0.7, "at the drawn place by the crack")
	check(inKeep == 0, "never in the crack or its keep-out")
	near(standing * DT, secs, 0.2, "it stood there its whole time")
	check(r.camp == nil and r.leg == leg + 1, `then patrols on to the next leg ({r.leg})`)
	check(Rival.valid(r), "a valid rival")
	-- A rest kept in the middle of the watch: the record has the time left; a new drive takes it back to its place and finishes it.
	check(snap ~= nil, "a watch half done")
	local d2, r2 = newRival(Vector3.new(20, 0, 8), Vector3.yAxis)
	d2.camps = true
	r2.leg, r2.camp, r2.position, r2.previous, r2.up, r2.heading = snap.leg, snap.camp, snap.pos, snap.pos, snap.up, snap.heading
	check(Rival.valid(r2), "the record with its watch is valid")
	local left = 0
	for _ = 1, 60 * 200 do
		Drive.update(d2, r2, DT, s)
		if r2.camp == nil then break end
		left += 1
	end
	near(left * DT, snap.camp, 0.2, "and the rest of the watch is stood out")
	check(r2.leg == leg + 1, "then the next leg")
	-- The record: optional, checked.
	local bad = Rival.new()
	bad.camp = -1
	check(not Rival.valid(bad), "a negative watch is refused")
	bad.camp = 0 / 0
	check(not Rival.valid(bad), "so is NaN")
	check(Rival.valid(Rival.new()), "a rival without one (every record before) is good")
	local renewed = Rival.new()
	renewed.camp = 30
	Rival.renew(renewed)
	check(renewed.camp == nil, "a new rival keeps no watch")
end)

-- ----------------------------------------------------------------------------------------------------------------- courtship

local OPEN = Vector3.new(10, 0.31, 8)
local function courtWorld(energy: number, seed: number?): any
	local needs = NeedsModel.new(true, false)
	needs.energy = energy
	local life = LifeLoop.new(needs, nil)
	life.growth.stage = Growth.ADULT
	life.mating = Mating.normalize({ stage = "none", ready_day = 2, mates = 1, visits = 1, visit_day = 3 })
	local mate = Mate.new()
	mate.sex, mate.scale, mate.state = "female", 1, "attend"
	mate.position, mate.previous = OPEN + Vector3.new(2, 0, 0), OPEN + Vector3.new(2, 0, 0)
	life.mate = mate
	return { life = life, needs = needs, seed = seed or 914 }
end
local function courtSnap(w: any, nature: boolean?, at: Vector3?, heading: Vector3?, moving: boolean?): any
	local p = at or OPEN
	return { position = p, previous = p, heading = heading or Vector3.xAxis, up = Vector3.yAxis, grounded = true, moving = moving == true, airborne = false, onLine = false,
		striking = false, holding = false, safe = false, day = 3, hour = 9, resting = false, wasp = false, sex = "male", seed = w.seed, nature = nature,
		blocked = function() return false end }
end
-- Courts until the mate decides (or 30 s pass): the events of the tick it decided, or {}.
local function court(w: any, nature: boolean?, shaky: number?): { string }
	local life = w.life
	for k = 1, 60 * 30 do
		local moving = shaky ~= nil and k % shaky == 0 and k < 60 * 6
		local ev = Mating.tick(life, DT, courtSnap(w, nature, nil, nil, moving))
		for _, e in ev do
			if e == "courted" or string.sub(e, 1, 9) == "rejected_" or e == "cut" then return ev end
		end
	end
	return {}
end

case("the quality of a court and the spider's condition set the odds; the numbers of the decision", function()
	local g = MatingRules.game
	check(g.on and g.base == 0.9 and g.energyLow == 0.35 and g.energyFull == 0.8 and g.conditionFloor == 0.3 and g.breakCost == 0.35 and g.farCost == 0.3 and g.awayCost == 0.5 and g.longFloor == 0.6, "the numbers")
	near(Mating.condition(0.85), 1, 1e-12, "well fed: 1")
	near(Mating.condition(0.6), 0.25 / 0.45, 1e-12, "at 0.6, the least a visitor comes for")
	near(Mating.condition(0.2), 0.3, 1e-12, "thin: the floor")
	local m = Mate.new()
	check(Mate.quality(m) == 1, "no record: 1")
	m.court_t, m.court_ok, m.court_near, m.court_away, m.court_breaks = 8, 8, 16, 0, 0
	near(Mate.quality(m), 1, 1e-12, "a still court at the mate's own distance, facing it, in eight seconds: 1")
	m.court_breaks = 2
	near(Mate.quality(m), 1 / 1.7, 1e-12, "two breaks")
	m.court_breaks, m.court_near = 0, 24
	near(Mate.quality(m), 0.7, 1e-12, "at the edge of courting range throughout")
	m.court_near, m.court_away, m.court_t = 16, 4, 8
	near(Mate.quality(m), 0.75, 1e-12, "half the court not facing it")
	m.court_away, m.court_t = 0, 24
	near(Mate.quality(m), 0.6, 1e-12, "a court three times as long: the floor")
	m.court_t, m.court_breaks = 8, 0
	local p = Mating.acceptChance(m, 0.85)
	near(p, 0.9, 1e-12, "the comment's numbers: a good court, well fed, 0.9")
	near((Mating.acceptChance(m, 0.6)), 0.5, 1e-12, "at 0.6, 0.5")
	near((Mating.acceptChance(m, 0.8)), 0.9, 1e-12, "at 0.8, full condition")
	m.court_breaks = 2
	near((Mating.acceptChance(m, 0.85)), 0.9 / 1.7, 1e-12, "two breaks, well fed, 0.53")
	local q, why = Mating.acceptChance(m, 0.6)
	near(q, 0.5 / 1.7, 1e-12, "thin and halting, 0.29")
	check(why == "thin", "the weaker factor names the refusal: here the condition (0.56 against 0.59)")
	check(select(2, Mating.acceptChance(m, 0.85)) == "clumsy", "well fed, the halting court")
	m.court_breaks = 0
	check(g.fairAt == 0.85 and select(2, Mating.acceptChance(m, 0.85)) == "choosy", "a good court, well fed: refused, it was the mate's own choice, not the spider's fault")
	m.court_near = 17.5 -- (a mean of 2.19 studs: quality 0.94, still fair)
	check(select(2, Mating.acceptChance(m, 0.85)) == "choosy" and select(2, Mating.acceptChance(m, 0.7)) == "thin", "fair down to 0.85 on both")
	m.court_near = 16
end)

case("a full meter is no longer a mating in the standard rules: the mate refuses at the odds, by its own draw, and the chain after an accepted court is the old one", function()
	-- The old game: without nature's rules every full meter is the pair.
	local plain = courtWorld(0.5)
	local ev = court(plain, nil)
	check(table.find(ev, "courted") ~= nil and plain.life.mating.stage == "courted", "without nature's rules a full meter is a mating, as before")
	check(plain.life.mating.courts == nil and plain.life.mate.court_t == nil, "and nothing new is written in the record")
	-- With them: a perfect court by a well-fed spider, over many worlds.
	local function share(energy: number, shaky: number?): (number, number)
		local yes, n = 0, 300
		for seed = 1, n do
			local w = courtWorld(energy, seed)
			local e = court(w, true, shaky)
			if table.find(e, "courted") then yes += 1 end
		end
		return yes / n, n
	end
	local good = share(0.85)
	check(good > 0.83 and good < 0.96, `a still, close, facing court, well fed: accepted {good} of the time (0.9)`)
	local thin = share(0.6)
	check(thin > 0.42 and thin < 0.58, `the same court at 0.6: {thin} (0.5)`)
	local halting = share(0.85, 50)
	check(halting < good - 0.1, `a halting court (stepping every 50 ticks for six seconds) is refused more ({halting})`)
	-- A refusal: the mate walks off for the day, the cycle waits for the next morning.
	local w
	for seed = 1, 200 do
		local t = courtWorld(0.6, seed)
		local e = court(t, true)
		if w == nil and table.find(e, "rejected_thin") then w = t end
	end
	check(w ~= nil, "a thin spider refused")
	local life = w.life
	check(life.mate.state == "leaving" and life.mate.reason == "rejected" and not life.mate.scene and life.mate.meter == 0, "refused: it walks off, no scene")
	check(life.mating.stage == "none" and life.mating.rejections == 1 and life.mating.courts == 1 and life.mating.away_day == 3, "the cycle is still waiting; the refusal and the court are counted; gone for today")
	check(life.mate.court_t == nil and life.mate.cut == nil, "the court's record is cleared")
	check(#Mating.problemsWith(life.mating, life.mate) == 0 and Mate.valid(life.mate), "a valid record")
	check(MateText.notice("rejected_thin", { sex = "female" }) == MateText.REJECTED_THIN.female and MateText.notice("rejected_clumsy", { sex = "male" }) == MateText.REJECTED_CLUMSY.male,
		"the words for each")
	check(MateText.gone("rejected") == nil and MateText.gone("cut") == nil, "and nothing more when it is gone")
	check(MateText.notice("rejected_choosy", { sex = "female" }) == MateText.REJECTED_CHOOSY.female and MateText.rejected("male", "choosy") == MateText.REJECTED_CHOOSY.male, "and when it was neither")
	for _, t in { MateText.REJECTED_CHOOSY.female, MateText.REJECTED_CHOOSY.male, MateText.REJECTED_THIN.female, MateText.REJECTED_THIN.male, MateText.REJECTED_CLUMSY.female, MateText.REJECTED_CLUMSY.male, MateText.CUT } do
		check(not string.find(t, "try again", 1, true) and #t < 140, "short, and no 'try again'")
	end
	-- The next morning one may come again.
	local s = courtSnap(w, true, Vector3.new(-10, 0.31, 8))
	s.day, s.hour = 4, 8
	life.mate.state = "away"
	local e2 = Mating.tick(life, DT, s)
	check(table.find(e2, "arrived") ~= nil and life.mating.visits == 2, "the next morning a visitor comes")
	-- The same world, the same decision; another seed, another.
	local a, b = courtWorld(0.7, 5), courtWorld(0.7, 5)
	check(table.concat(court(a, true), ",") == table.concat(court(b, true), ","), "the same world, the same decision")
	-- An accepted court goes on as it always did: the scene, the parting, the sac.
	local ok
	for seed = 1, 50 do
		local t = courtWorld(0.85, seed)
		if ok == nil and table.find(court(t, true), "courted") then ok = t end
	end
	check(ok ~= nil, "an accepted court")
	local L = ok.life
	check(L.mating.stage == "courted" and L.mate.state == "pair" and L.mate.scene == true and L.mating.courts == 1, "together: the scene")
	local mated = false
	for _ = 1, 60 * 20 do
		for _, e in Mating.tick(L, DT, courtSnap(ok, true)) do if e == "mated" then mated = true end end
		if mated then break end
	end
	check(mated and L.mating.stage == "mated", "then mated")
	check(Mating.woke(L, 4) == "sac" and L.mating.stage == "sac", "and the next morning's sleep makes the sac")
end)

case("the rival may cut in on a court: a seeded level of the meter, only if it is free and near the mate then", function()
	local g = MatingRules.game
	check(g.cutChance == 0.35 and g.cutLevel[1] == 0.35 and g.cutLevel[2] == 0.85 and g.cutWu == 10, "the numbers")
	local armed, n = 0, 2000
	for k = 1, n do
		local m = { mates = 1 + k // 3, visits = 1 + k % 3 }
		local level = Mating.cutLevel(914, m)
		if level ~= nil then
			armed += 1
			check(level >= 0.35 and level < 0.85, "a level of the meter")
		end
		check(Mating.cutLevel(914, m) == level, "the same visit, the same level")
	end
	check(armed / n > 0.31 and armed / n < 0.39, `about a third of the visits ({armed} of {n})`)
	-- Through an arrival: the level is drawn as the mate comes (nature's rules only).
	local function arrive(nature: boolean?): any
		local w = courtWorld(0.85)
		w.life.mate = Mate.new()
		w.life.mating = Mating.normalize({ stage = "none", ready_day = 2 })
		local s = courtSnap(w, nature, Vector3.new(-10, 0.31, 8))
		Mating.tick(w.life, DT, s)
		return w
	end
	check(arrive(nil).life.mate.cut == nil, "the old game draws nothing")
	local found
	for seed = 1, 100 do
		local w = courtWorld(0.85, seed)
		w.life.mate = Mate.new()
		w.life.mating = Mating.normalize({ stage = "none", ready_day = 2 })
		Mating.tick(w.life, DT, courtSnap(w, true, Vector3.new(-10, 0.31, 8)))
		if found == nil and w.life.mate.cut ~= nil then found = w end
	end
	check(found ~= nil and found.life.mate.state == "wander", "a visitor whose court the rival will cut in on")
	-- The court itself: with the rival free and near, the cut comes at its level; far, or gone, it does not.
	local function courtWith(rival: any): ({ string }, number)
		local w = courtWorld(0.85, found.seed)
		w.life.mate.cut = found.life.mate.cut
		for _ = 1, 60 * 30 do
			local s = courtSnap(w, true)
			s.rival = rival
			local ev = Mating.tick(w.life, DT, s)
			for _, e in ev do
				if e == "cut" or e == "courted" or string.sub(e, 1, 9) == "rejected_" then return ev, w.life.mating.cut_ins or 0 end
			end
		end
		return {}, 0
	end
	local ev, cuts = courtWith({ position = OPEN + Vector3.new(6, 0, 0), up = Vector3.yAxis, present = true })
	check(table.find(ev, "cut") ~= nil and cuts == 1, "near: it cuts in")
	ev = courtWith({ position = OPEN + Vector3.new(-14, 0, 0), up = Vector3.yAxis, present = true })
	check(table.find(ev, "cut") == nil, "far off: it does not")
	ev = courtWith(nil)
	check(table.find(ev, "cut") == nil, "eaten or taken by the wasp: nothing cuts in")
	check(MateText.notice("cut", {}) == MateText.CUT, "the words")
end)

-- ----------------------------------------------------------------------------------------------------------------- the night

local function nightLife(day: number, hour: number): any
	local needs = NeedsModel.new(true, false)
	local life = LifeLoop.new(needs, nil)
	life.clock.day, life.clock.hour = day, hour
	return life
end

case("the night in the garden: three passes of the ground hunters a night, from the seed; found or a cold, slow morning; never on the sill or in a retreat", function()
	local g = Nature.game
	check(g.foundChance == 0.25 and #g.passes == 3 and g.passes[1][1] == 20.5 and g.passes[3][2] == 29.5 and g.coldUntilH == 10 and g.coldSpeed == 0.6, "the numbers")
	check(Nature.nightOf(3, 12) == nil and Nature.nightOf(3, 18) == 3 and Nature.nightOf(4, 3) == 3 and select(2, Nature.nightOf(4, 3)) == 27, "the night of an hour")
	check(Nature.exposed(true, "bed", false) and Nature.exposed(true, "house_wall", false) and Nature.exposed(true, "outer_sill", false), "exposed: out in the garden's regions")
	check(not Nature.exposed(true, "sill", false) and not Nature.exposed(true, "bed", true) and not Nature.exposed(false, "bed", false), "not on the sill, not in a retreat, not in the gentle modes")
	check(not Nature.exposed(true, "counter", false) and not Nature.exposed(true, "kitchen_floor", false) and Nature.exposed(true, "eaves", false) and Nature.exposed(true, "wall_upper", false),
		"(ROBLOX-112) not inside the house, on the kitchen's counter or floor; out on the window's glass or in the gutter, exposed")
	local founds, n = 0, 4000
	for night = 1, n do
		local hours = Nature.passHours(914, night)
		for i, h in hours do
			check(h >= g.passes[i][1] and h < g.passes[i][2], "a pass in its window")
			if Nature.found(914, night, i) then founds += 1 end
		end
		local again = Nature.passHours(914, night)
		check(again[1] == hours[1] and again[3] == hours[3], "the same night, the same hours")
	end
	check(founds / (3 * n) > 0.23 and founds / (3 * n) < 0.27, `a pass finds an exposed spider about one time in four ({founds} of {3 * n})`)
	-- A whole night out: run the clock from 18:00 to 07:00.
	local function nightOut(night: number, exposedAt: ((number) -> boolean)?): (string, number?, any)
		local life = nightLife(night, 18.0)
		local st = {}
		local first = ""
		local at: number? = nil
		while true do
			local _, h = Nature.nightOf(life.clock.day, life.clock.hour)
			local e = Nature.night(st, life, { seed = 914, exposed = if exposedAt then exposedAt(h) else true })
			if e ~= "" and (first == "" or first == "cold") then
				if e == "found" or first == "" then first, at = e, h end
				if e == "found" then break end
			end
			life.clock:_addHours(0.05)
			if life.clock.day > night and life.clock.hour >= 7 then break end
		end
		return first, at, life
	end
	local died, cold = 0, 0
	for night = 1, 400 do
		local e, at, life = nightOut(night)
		if e == "found" then
			died += 1
			local hours = Nature.passHours(914, night)
			local which = 0
			for i = 1, 3 do if which == 0 and Nature.found(914, night, i) then which = i end end
			check(which > 0 and at ~= nil and math.abs(at - hours[which]) < 0.06, "found at the pass that drew it")
		else
			cold += 1
			check(e == "cold" and life.cold_day == night + 1, "spared: a cold morning")
		end
	end
	check(died / 400 > 0.5 and died / 400 < 0.66, `a whole night in the open is death {died} times in 400 (1 - 0.75^3 = 0.58)`)
	-- Home before the first pass: nothing. Home before the second: only the first was drawn.
	local e = nightOut(5, function() return false end)
	check(e == "", "in a retreat (or on the sill) the whole night: nothing happens")
	local hours = Nature.passHours(914, 5)
	local home = nightOut(5, function(h: number): boolean return h < (hours[1] + hours[2]) / 2 end)
	check(home == (if Nature.found(914, 5, 1) then "found" else "cold"), "home between the first and the second pass: only the first was drawn")
	-- The cold: slow until 10:00 the next day, then cleared.
	local life = nightLife(6, 23.0)
	life.cold_day = 7
	check(Nature.coldSpeed(life) == 0.6, "the rest of the night: slow")
	life.clock.day, life.clock.hour = 7, 9.9
	check(Nature.coldSpeed(life) == 0.6, "the morning: slow")
	life.clock.hour = 10.0
	check(Nature.coldSpeed(life) == 1 and life.cold_day == nil, "from 10:00, as before, and the cold is gone")
	check(Nature.validCold(nil) and Nature.validCold(7) and not Nature.validCold(0) and not Nature.validCold(2.5) and not Nature.validCold("7"), "the record's field")
end)

case("a return to a rest never rerolls the night: the passes behind the restored hour are behind it, those ahead are drawn again the same", function()
	local night = 9
	local hours = Nature.passHours(914, night)
	-- A night run on from 19:00 with the spider exposed: what happens, and when.
	local function run(st: any, life: any): { string }
		local out = {}
		for _ = 1, 400 do
			local e = Nature.night(st, life, { seed = 914, exposed = true })
			if e ~= "" then table.insert(out, e .. "@" .. string.format("%.2f", select(2, Nature.nightOf(life.clock.day, life.clock.hour)))) end
			if e == "found" then break end
			life.clock:_addHours(0.05)
		end
		return out
	end
	local a = run({}, nightLife(night, 19.0))
	local b = run({}, nightLife(night, 19.0))
	check(#a > 0 and table.concat(a, ",") == table.concat(b, ","), `the same night, the same events ({table.concat(a, ",")})`)
	-- Restored at an hour after the first pass (cleared state, as the client clears it): the first is not drawn again.
	local life = nightLife(night, 18.0)
	local st = {}
	life.clock:_addHours(hours[1] - 18.0 + 0.1)
	check(Nature.night(st, life, { seed = 914, exposed = true }) == "" and st.done == 1, "met after the first pass: it is behind it")
	-- Within one life, going on: the same state carries the count.
	local e = ""
	for _ = 1, 200 do
		life.clock:_addHours(0.05)
		local x = Nature.night(st, life, { seed = 914, exposed = true })
		if x ~= "" then e = x; break end
	end
	check(e == (if Nature.found(914, night, 2) then "found" else "cold"), "the second pass is the next drawn")
	-- By day the state lets go.
	local day = nightLife(night + 1, 12.0)
	check(Nature.night(st, day, { seed = 914, exposed = true }) == "" and st.night == nil, "by day nothing is held")
end)

-- ----------------------------------------------------------------------------------------------------------------- the end of a life

case("the end screen's words in Normal, and the night as a way to die", function()
	check(string.find(LifeText.DAY_LOST, "loses the day", 1, true) ~= nil and string.find(LifeText.DAY_LOST, "notebook keeps its pages", 1, true) ~= nil
		and string.find(LifeText.DAY_LOST, "new life from the start", 1, true) ~= nil, "what the way back costs, what is kept, what another spider is")
	check(LifeText.dayLost(true) == LifeText.DAY_LOST and LifeText.dayLost(false) == LifeText.NO_REST, "with no rest, only another spider")
	check(LifeText.NIGHT_LINE ~= "" and LifeText.NIGHT_SUB ~= "" and LifeText.NIGHT_COLD ~= "", "the night's words")
	for _, t in { LifeText.DAY_LOST, LifeText.NO_REST, LifeText.NIGHT_LINE, LifeText.NIGHT_SUB, LifeText.NIGHT_COLD } do
		check(not string.find(string.lower(t), "try again", 1, true), "no 'try again'")
	end
	local s = LifeSession.new()
	s:begin("main", false)
	check(s:endLife("night", { hours = 30 }) and s.summary.cause == "night", "the night ends a life in Normal")
	local e = LifeSession.new()
	e.finishedMain = true
	e:begin("main", true)
	check(not e:endLife("night", {}), "and never in the gentle modes (nothing there draws it)")
end)

-- ----------------------------------------------------------------------------------------------------------------- the checkpoint

local cast = Sensor.workspaceCast(params)
local function fullWorld(): any
	local motor = newMotor(Layout.SPAWN, Layout.SPAWN_HEADING)
	local prey = PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, false)
	needs:useGameRules()
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs }
	w.life = LifeLoop.new(needs, nil)
	motor:place(Vector3.new(-25.5, 0.31, 6), Vector3.yAxis, Vector3.xAxis)
	for _ = 1, 3 do sensor:step(DT, motor:observer(), prey:percepts(), cast); motor:tick(Motor.idleInput()) end
	return w
end

case("the checkpoint keeps the new optional fields, checks them, and an old record has none", function()
	local plain = fullWorld()
	local old = assert(Checkpoint.capture(plain, 0))
	check(#Checkpoint.check(old, plain) == 0, "a record with none of them is good")
	local text = assert(Json.canonical(old))
	for _, word in { "cold_day", "court_t", "\"camp\"", "rejections", "cut_ins" } do
		check(not string.find(text, word, 1, true), `a record of a life without them has no {word}`)
	end
	local w = fullWorld()
	w.life.cold_day = 4
	w.life.rival = Rival.new()
	w.life.rival.state, w.life.rival.camp = "patrol", 42.5
	w.life.rival.position, w.life.rival.previous = Vector3.new(-18, 0.31, 6), Vector3.new(-18, 0.31, 6)
	w.life.mate = Mate.new()
	w.life.mate.state, w.life.mate.position, w.life.mate.previous = "attend", Vector3.new(10, 0.31, 6), Vector3.new(10, 0.31, 6)
	w.life.mate.court_t, w.life.mate.court_ok, w.life.mate.court_near, w.life.mate.court_away, w.life.mate.court_breaks, w.life.mate.court_on, w.life.mate.cut = 3.5, 3, 6.2, 0.2, 1, true, 0.6
	w.life.mate.meter = 0.3
	w.life.mating = Mating.normalize({ stage = "none", ready_day = 2, mates = 1, visits = 2, visit_day = 3, courts = 2, rejections = 1, cut_ins = 1 })
	local rec = assert(Checkpoint.capture(w, 0))
	check(#Checkpoint.check(rec, w) == 0, "a record with all of them is good")
	local u = fullWorld()
	check(Checkpoint.restore(rec, u), "and restores")
	check(u.life.cold_day == 4 and u.life.rival.camp == 42.5 and u.life.mate.court_breaks == 1 and u.life.mate.cut == 0.6 and u.life.mate.court_on == true
		and u.life.mating.courts == 2 and u.life.mating.rejections == 1 and u.life.mating.cut_ins == 1, "every one as it was")
	-- Refusals.
	local function refused(edit: (any) -> (), what: string)
		local x = fullWorld()
		x.life.cold_day, x.life.rival, x.life.mate, x.life.mating = w.life.cold_day, table.clone(w.life.rival), table.clone(w.life.mate), table.clone(w.life.mating)
		edit(x.life)
		local r = Checkpoint.capture(x, 0)
		check(r ~= nil and #Checkpoint.check(r, x) > 0, what)
	end
	refused(function(l: any) l.cold_day = 0.5 end, "a cold morning that is not a day is refused")
	refused(function(l: any) l.rival.camp = -3 end, "a negative watch is refused")
	refused(function(l: any) l.mate.court_breaks = 1.5 end, "half a break is refused")
	refused(function(l: any) l.mate.cut = 2 end, "a level past the meter is refused")
	refused(function(l: any) l.mating.rejections = -1 end, "a negative count is refused")
end)

print(`NATURE passed={passed} failed={failed}`)
if failed > 0 then error("nature checks failed") end
