--!strict
-- The trains on the railway beyond the preserve's north fence (ROBLOX-115, docs/PARK_WORLD_DESIGN.md: "the railway's vibration", "trains every few minutes").
-- Pure: when each train passes, which way, how fast, how long it is and what it is, drawn from the world's seed (WorldMap.seed(world seed, "train"), a
-- Park-Miller stream per pass), so the same world has the same timetable on every client and in the tests; nothing here draws from math.random. Client/TrainPass
-- draws the silhouette where `at` puts it and plays its sound.
--
-- A pass runs the length of the line between the covered ways at its two ends (World/PreserveLook's railway: 16 m each, where the line goes under the streets),
-- from one portal's far end to the other's, so a train is only ever seen coming out of one and going into the other, never at the edge of the world: every car
-- is drawn only while it lies wholly within the line's extent (World/Preserve.LIMIT). Between passes there are GAP seconds (two and a half to five and a half
-- minutes); the first comes FIRST seconds or so after the clock's zero, so a visit soon sees one.
local Preserve = require(script.Parent.Preserve)

local PreserveTrain = {}

export type Pass = { k: number, start: number, finish: number, dir: number, speed: number, cars: number, kind: string }

PreserveTrain.GAP = table.freeze({ 150, 330 }) -- seconds between one train's last car leaving and the next's front appearing
PreserveTrain.FIRST = table.freeze({ 40, 100 })
PreserveTrain.SPEED = table.freeze({ 1100, 1700 }) -- studs a second (40 to 60 km/h: a line through the city, slowing for a station)
PreserveTrain.CARS = table.freeze({ commuter = table.freeze({ 3, 5 }), freight = table.freeze({ 5, 9 }) })
-- A car (studs): 15 m long (so a car fits inside a covered way, 16 m), 3 m wide, its body's floor 1.1 m over the rail and its roof 4 m; the gap between cars.
PreserveTrain.CAR = table.freeze({ length = 1500, width = 300, floor = 110, height = 400, gap = 60 })

local R = Preserve.RAILWAY
local MOD = 2147483647

-- The line: the track's middle in studs (z), the rails' top (y) and its two ends (x), the covered ways' inner ends.
local lo = Preserve.at(R.x[1], R.track, R.height + 0.57)
local hi = Preserve.at(R.x[2], R.track, R.height + 0.57)
PreserveTrain.LINE = table.freeze({ z = lo.Z, y = lo.Y, x0 = lo.X, x1 = hi.X })

local function rng(seed: number): () -> number
	local state = seed % MOD
	if state <= 0 then state += MOD - 1 end
	return function(): number
		state = (state * 16807) % MOD
		return (state - 1) / (MOD - 1)
	end
end

-- The length of a train of `cars` cars, studs.
function PreserveTrain.length(cars: number): number
	local C = PreserveTrain.CAR
	return cars * C.length + (cars - 1) * C.gap
end

-- The timetable of a seed: `pass(k)` the k-th pass (1, 2, ...), `at(t)` the pass under way at time t (seconds on the client's clock) or nil.
function PreserveTrain.schedule(seed: number): any
	local passes: { Pass } = {}
	local span = PreserveTrain.LINE.x1 - PreserveTrain.LINE.x0
	local function make(k: number): Pass
		local rand = rng((seed + k * 104729) % MOD)
		local prevFinish = if k == 1 then 0 else passes[k - 1].finish
		local gapRange = if k == 1 then PreserveTrain.FIRST else PreserveTrain.GAP
		local start = prevFinish + gapRange[1] + (gapRange[2] - gapRange[1]) * rand()
		local kind = if rand() < 0.65 then "commuter" else "freight"
		local range = PreserveTrain.CARS[kind]
		local cars = range[1] + math.floor(rand() * (range[2] - range[1] + 1))
		local speed = PreserveTrain.SPEED[1] + (PreserveTrain.SPEED[2] - PreserveTrain.SPEED[1]) * rand()
		if kind == "freight" then speed *= 0.8 end
		local dir = if rand() < 0.5 then 1 else -1
		local finish = start + (span + PreserveTrain.length(cars)) / speed
		return table.freeze({ k = k, start = start, finish = finish, dir = dir, speed = speed, cars = cars, kind = kind })
	end
	local self = {}
	function self.pass(k: number): Pass
		for i = #passes + 1, k do passes[i] = make(i) end
		return passes[k]
	end
	local cursor = 1
	function self.at(t: number): Pass?
		if t < 0 then return nil end
		if cursor > 1 and self.pass(cursor - 1).start > t then cursor = 1 end -- (a clock that went back: from the start)
		while self.pass(cursor).finish < t do cursor += 1 end
		local p = self.pass(cursor)
		if t >= p.start then return p end
		return nil
	end
	return self
end

-- Where the front of a pass's train is at time t (studs along x), and the middle of each car, in order from the front. A car lies wholly inside the line or is
-- not listed.
function PreserveTrain.cars(p: Pass, t: number): (number, { number })
	local L = PreserveTrain.LINE
	local C = PreserveTrain.CAR
	local travelled = (t - p.start) * p.speed
	local front = if p.dir == 1 then L.x0 + travelled else L.x1 - travelled
	local out: { number } = {}
	for i = 1, p.cars do
		local back = (i - 1) * (C.length + C.gap) + C.length / 2
		local mid = front - p.dir * back
		if mid - C.length / 2 >= L.x0 and mid + C.length / 2 <= L.x1 then table.insert(out, mid) end
	end
	return front, out
end

return table.freeze(PreserveTrain)
