--!strict
-- The ranger's cat (ROBLOX-118, docs/PARK_WORLD_DESIGN.md section 10: "the cat and the game room live in the hut"): a house cat that lives in the ranger hut's
-- two rooms and never leaves them. Pure: no engine, no drawing (Rig/CatPose draws it, Client/CatBody puts the parts in the world), so the client, the self-test
-- and the CLI suites ask exactly the same cat.
--
-- Its day is a seeded schedule (`Cat.plan(seed, day)`: the world's seed through WorldMap.seed(914, "cat"), a Park-Miller stream per day), so where the cat is at
-- an hour of a day is a pure function of the seed, the day and the hour, and a return to a rest finds it where the schedule says (restores never reroll): it
-- sleeps on the back room's sofa or on the chair at the desk by the sill through much of the day, as cats do (they sleep twelve hours or more, most of it in
-- naps); it is up at dawn and dusk and for a while in the night, and then it walks the two rooms through the doorway, eats at its bowls by the door, grooms
-- on the rug, waits by the door for the ranger, and sits on the back room's deep window sill looking out. Every day begins and ends asleep on the sofa.
--
-- It is heard before it is seen: the bell on its collar rings with every step (a small bell carries a few metres), and it purrs as it settles to rest
-- (`sound`). It notices a small thing that moves near it (`step`): it stops, its head follows the thing, and if the thing keeps moving and is in reach it
-- crouches and pats at it with a forepaw, fast. What saves a spider is what saves any small thing from a cat: being out of its reach (up high: the desk, the
-- lamp, the bookcase's top, a wall), in a gap it cannot get a paw into (a home, the gap under the sofa), or keeping still until it loses interest. In Normal a
-- pat that lands kills the spider (`struck`); in the gentle rules (Easy, Free play) it only knocks it aside (`nudged`).
--
-- Live state that is not saved: the reaction under way, how far the cat has stepped off its schedule to stalk, and how far behind its schedule watching left it
-- (`lag`: it then runs its schedule a little faster until it has caught up). A return to a rest ends a reaction and puts the cat where its schedule says. Saved
-- (`toRecord`, Persistence/Checkpoint's optional `cat`): the day it last swatted and this life's notices, pats that missed and pats that landed.
--
-- Studs (a stud is a centimetre), the sill's frame (World/Hut: +x east, -z north, the hut's floor at y -70). True size: a domestic cat about 46 cm long without
-- its tail, 23 to 25 cm at the shoulder (Rig/CatPose has the body).
local Cat = {}
Cat.__index = Cat

local FL = -70 -- the floor (World/Hut.FLOOR)
local v = Vector3.new

-- ---------------------------------------------------------------- the numbers
Cat.WALK_SPEED = 60 -- studs a second: a cat's unhurried walk, 0.6 m/s
Cat.JUMP_S = 0.55 -- seconds a jump up or down takes
Cat.NOTICE = 125 -- how near (studs, in plan, from its head) a moving thing catches its eye
Cat.NOTICE_UP = 130 -- and how high over the surface it stands on (it watches what moves on a wall)
Cat.REACH = 24 -- how far its pat reaches in plan from its chest
Cat.REACH_UP = 50 -- and how high over its surface (up on its hind legs)
Cat.MOVING = 0.5 -- studs a second: slower than this, a spider is keeping still
Cat.WAKE_SPEED = 1.1 -- creeping can pass a sleeping cat; sustained walking wakes it
Cat.WAKE_S = 2 -- seconds of nearby roaming before it gets up
Cat.STILL_LOSE = 2.5 -- seconds of stillness and it loses interest
Cat.HIGH_LOSE = 5.0 -- seconds staring at what it cannot reach and it gives up
Cat.WATCH = table.freeze({ 1.2, 3.0 }) -- seconds it watches before it moves on what it watches (a draw per notice)
Cat.CROUCH_S = 0.6 -- the crouch and the wiggle before the pat
Cat.SWAT_S = 0.25 -- the pat itself (the paw is at the far end of its reach halfway through)
Cat.STALK_SPEED = 20 -- studs a second, low and slow toward the thing
Cat.STALK_MAX = 80 -- the farthest it steps off its schedule's place to stalk
Cat.COOLDOWN = 12 -- seconds after it gives up before anything catches its eye again
Cat.MISSES = 2 -- pats that miss before it gives up
Cat.CATCH_UP = 0.5 -- after a reaction its schedule runs this much faster until it has caught up
Cat.HEAR_BELL = 350 -- studs: how far the bell is heard (about 3.5 m)
Cat.HEAR_PURR = 70 -- and the purr (under a metre)
Cat.PURR_H = 0.4 -- hours of purring as it settles to a rest
local HOUR_PER_S = 12.0 / (15.0 * 60.0) -- Life/LifeClock.ACTIVE_HOURS_PER_S: game hours a second at the hut's pace (1.0)
Cat.HOUR_PER_S = HOUR_PER_S

-- Where it rests and sits, the surface it is on, which way it faces, and the floor point it jumps up from (or walks to).
export type Spot = { pos: Vector3, heading: Vector3, kind: string, node: string, up: boolean }
Cat.SPOTS = table.freeze({
	sofa = table.freeze({ pos = v(300, -25, 205), heading = v(1, 0, 0), kind = "rest", node = "sofa_front", up = true }), -- on the sofa's seat (World/Hut.SOFA)
	chair = table.freeze({ pos = v(86, -24, 108), heading = v(0, 0, -1), kind = "rest", node = "chair_side", up = true }), -- on the chair at the desk by the sill
	window = table.freeze({ pos = v(437, 0, 134), heading = v(1, 0, 0), kind = "sit", node = "window_floor", up = true }), -- on the back room's window sill
	bowls = table.freeze({ pos = v(-87, FL, 220), heading = v(0, 0, 1), kind = "eat", node = "bowls", up = false }), -- at its bowls by the door
	door = table.freeze({ pos = v(0, FL, 228), heading = v(0, 0, 1), kind = "sit", node = "door", up = false }), -- waiting by the door
	rug = table.freeze({ pos = v(315, FL + 1, 130), heading = v(1, 0, 0.3).Unit, kind = "groom", node = "rug", up = false }), -- grooming on the rug
}) :: { [string]: Spot }
Cat.SPOT_ORDER = table.freeze({ "sofa", "chair", "window", "bowls", "door", "rug" })
-- The floor's ways through the two rooms (clear of the furniture: the sofa, the television's unit, the shelves, the caddy, the radiator), and the doorway.
Cat.NODES = table.freeze({
	hut_mid = v(0, FL, 160), chair_side = v(45, FL, 108), bowls = v(-87, FL, 220), door = v(0, FL, 228),
	doorway_w = v(125, FL, 215), doorway_e = v(195, FL, 215), room_w = v(205, FL, 140), rug = v(315, FL + 1, 130),
	sofa_front = v(300, FL, 152), window_floor = v(405, FL, 134),
}) :: { [string]: Vector3 }
local EDGES = {
	{ "hut_mid", "chair_side" }, { "hut_mid", "bowls" }, { "hut_mid", "door" }, { "bowls", "door" }, { "hut_mid", "doorway_w" }, { "doorway_w", "doorway_e" },
	{ "doorway_e", "room_w" }, { "room_w", "rug" }, { "room_w", "sofa_front" }, { "rug", "sofa_front" }, { "rug", "window_floor" }, { "sofa_front", "window_floor" },
}
Cat.EDGES = EDGES
-- The two rooms in plan (it notices only what is in the room it is in; the doorway is both), and what its body cannot go into when it stalks.
Cat.ROOMS = table.freeze({ hut = table.freeze({ -146.5, 146.5 }), back = table.freeze({ 175, 445 }) }) :: { [string]: { number } }
local BLOCKS = {
	{ 225, 425, 165.5, 254 }, { 185, 275, 14, 52.5 }, { 360, 440, 14, 44 }, { 425, 441, 100, 163 }, -- the sofa, the television's unit, the games, the radiator
	{ -146.5, -118.5, 116, 204 }, { 68, 90, 228, 246 }, -- the bookcase, the caddy
	{ -101, -73, 38, 66 }, { -140.4, -120, 59, 81 }, -- station boots and field pack
}
Cat.BLOCKS = BLOCKS

-- ---------------------------------------------------------------- the schedule
local MOD = 2147483647
local function rng(seed: number, salt: number): () -> number
	local state = (seed + salt * 7919) % MOD
	if state <= 0 then state += MOD - 1 end
	return function(): number
		state = (state * 16807) % MOD
		return (state - 1) / (MOD - 1)
	end
end
local function between(rand: () -> number, a: number, b: number): number
	return a + (b - a) * rand()
end

-- The shortest way over the floor between two nodes (Dijkstra over the few edges), as points.
local routeCache: { [string]: { Vector3 } } = {}
local function route(a: string, b: string): { Vector3 }
	local key = a .. ">" .. b
	if routeCache[key] then return routeCache[key] end
	local N = Cat.NODES
	local dist: { [string]: number } = { [a] = 0 }
	local prev: { [string]: string } = {}
	local done: { [string]: boolean } = {}
	while true do
		local best, bd = nil :: string?, math.huge
		for n, d in dist do if not done[n] and d < bd then best, bd = n, d end end
		if best == nil or best == b then break end
		done[best] = true
		for _, e in EDGES do
			local other = if e[1] == best then e[2] elseif e[2] == best then e[1] else nil
			if other ~= nil and not done[other] then
				local d = bd + (N[best] - N[other]).Magnitude
				if dist[other] == nil or d < dist[other] then dist[other] = d; prev[other] = best end
			end
		end
	end
	local out = {}
	local n: string? = b
	while n ~= nil do
		table.insert(out, 1, N[n])
		n = if n == a then nil else prev[n]
	end
	routeCache[key] = out
	return out
end
Cat.route = route

export type Segment = { t0: number, t1: number, kind: string, spot: string, from: string?, path: { Vector3 }?, length: number?, up: number?, down: number? }

-- The way from one spot to another: down from the first (when it is up on something), over the floor, up onto the second; its points, its length on the
-- floor, and the seconds of its jumps.
local function walkBetween(a: string, b: string): ({ Vector3 }, number, number, number)
	local A, B = Cat.SPOTS[a], Cat.SPOTS[b]
	local pts: { Vector3 } = {}
	if A.up then table.insert(pts, A.pos) end
	local floor = route(A.node, B.node)
	for _, p in floor do table.insert(pts, p) end
	if B.up then table.insert(pts, B.pos) end
	local length = 0 -- (on the floor only: the jumps take their own time)
	for i = 2, #floor do length += (floor[i] - floor[i - 1]).Magnitude end
	return pts, length, if B.up then Cat.JUMP_S else 0, if A.up then Cat.JUMP_S else 0
end

-- How long each kind of stop lasts (hours), by the part of the day.
local function partOf(h: number): string
	if (h >= 5 and h < 8.5) or (h >= 17 and h < 21) then return "crepuscular" end
	if h >= 8.5 and h < 17 then return "day" end
	return "night"
end
local WEIGHTS: { [string]: { [string]: number } } = {
	crepuscular = { bowls = 0.22, window = 0.28, rug = 0.2, door = 0.12, chair = 0.06, sofa = 0.12 },
	day = { sofa = 0.36, chair = 0.3, window = 0.14, rug = 0.1, bowls = 0.05, door = 0.05 },
	night = { sofa = 0.55, rug = 0.15, bowls = 0.12, window = 0.18 },
}
local function stay(spot: string, part: string, rand: () -> number): number
	local kind = Cat.SPOTS[spot].kind
	if kind == "rest" then return if part == "day" then between(rand, 1.4, 3.2) else between(rand, 0.5, 1.4) end
	if spot == "window" then return between(rand, 0.3, 1.0) end
	if kind == "eat" then return between(rand, 0.08, 0.16) end
	if kind == "groom" then return between(rand, 0.15, 0.4) end
	return between(rand, 0.1, 0.3) -- (by the door)
end

local planCache: { [string]: { Segment } } = {}
-- The cat's day: its segments from 0 to 24 hours, each a stop at a spot or a walk between two (the walk's points, its floor length and its jumps).
function Cat.plan(seed: number, day: number): { Segment }
	local key = tostring(seed) .. "/" .. tostring(day)
	if planCache[key] then return planCache[key] end
	local rand = rng(seed, 1000 + day)
	local out: { Segment } = {}
	local spot = "sofa"
	local t = between(rand, 4.5, 5.5)
	table.insert(out, { t0 = 0, t1 = t, kind = "rest", spot = "sofa" })
	local function go(to: string)
		local pts, length, up, down = walkBetween(spot, to)
		local dur = (length / Cat.WALK_SPEED + up + down) * HOUR_PER_S
		table.insert(out, { t0 = t, t1 = t + dur, kind = "walk", spot = to, from = spot, path = pts, length = length, up = up, down = down })
		t += dur
		spot = to
	end
	while t < 22.5 do
		local part = partOf(t)
		local w = WEIGHTS[part]
		local total = 0
		for _, name in Cat.SPOT_ORDER do if name ~= spot then total += w[name] or 0 end end
		local x = rand() * total
		local pick = "sofa"
		for _, name in Cat.SPOT_ORDER do
			if name ~= spot and (w[name] or 0) > 0 then
				x -= w[name]
				if x <= 0 then pick = name; break end
			end
		end
		go(pick)
		local d = stay(pick, part, rand)
		local t1 = math.min(t + d, 23.2)
		table.insert(out, { t0 = t, t1 = t1, kind = Cat.SPOTS[pick].kind, spot = pick })
		t = t1
	end
	if spot ~= "sofa" then go("sofa") end
	table.insert(out, { t0 = t, t1 = 24, kind = "rest", spot = "sofa" })
	for _, s in out do table.freeze(s) end
	planCache[key] = table.freeze(out)
	return out
end

-- Where the schedule has the cat at `hour` of `day`: its position (on the surface it stands on), heading, pose ("walk", "jump", "sit", "rest", "sleep", "eat",
-- "groom"), the surface's height, and whether it is purring.
export type Place = { pos: Vector3, heading: Vector3, pose: string, surface: number, purring: boolean, spot: string, segment: Segment }
function Cat.at(seed: number, day: number, hour: number): Place
	local plan = Cat.plan(seed, day)
	local h = math.clamp(hour, 0, 24 - 1e-9)
	local seg = plan[#plan]
	for _, s in plan do
		if h < s.t1 then seg = s; break end
	end
	if seg.kind ~= "walk" then
		local S = Cat.SPOTS[seg.spot]
		local pose = seg.kind
		local purring = false
		if seg.kind == "rest" then
			purring = h - seg.t0 < Cat.PURR_H and seg.t0 > 0
			pose = if purring then "rest" else "sleep"
		end
		return { pos = S.pos, heading = S.heading, pose = pose, surface = S.pos.Y, purring = purring, spot = seg.spot, segment = seg }
	end
	-- a walk: down from where it was (a jump), along the floor, up onto where it is going (a jump), each at its own pace
	local secs = (h - seg.t0) / HOUR_PER_S
	local pts = seg.path :: { Vector3 }
	local down, up, length = seg.down or 0, seg.up or 0, seg.length or 0
	local first, last = 1, #pts
	local function jump(a: Vector3, b: Vector3, k: number): Place
		local p = a:Lerp(b, k) + v(0, math.sin(k * math.pi) * 18, 0)
		local flat = v(b.X - a.X, 0, b.Z - a.Z)
		local hd = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		return { pos = p, heading = hd, pose = "jump", surface = p.Y, purring = false, spot = seg.spot, segment = seg }
	end
	if down > 0 then
		if secs < down then return jump(pts[1], pts[2], secs / down) end
		secs -= down
		first = 2
	end
	local floorEnd = if up > 0 then last - 1 else last
	local walkS = length / Cat.WALK_SPEED
	if secs >= walkS and up > 0 then return jump(pts[floorEnd], pts[last], math.clamp((secs - walkS) / up, 0, 1)) end
	-- along the floor's points from `first` to `floorEnd`
	local d = math.clamp(secs, 0, walkS) * Cat.WALK_SPEED
	for i = first, floorEnd - 1 do
		local a, b = pts[i], pts[i + 1]
		local l = (b - a).Magnitude
		if d <= l or i == floorEnd - 1 then
			local k = if l > 1e-6 then math.clamp(d / l, 0, 1) else 1
			local flat = v(b.X - a.X, 0, b.Z - a.Z)
			return { pos = a:Lerp(b, k), heading = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis, pose = "walk", surface = a.Y + (b.Y - a.Y) * k,
				purring = false, spot = seg.spot, segment = seg }
		end
		d -= l
	end
	local p = pts[floorEnd]
	return { pos = p, heading = Vector3.zAxis, pose = "walk", surface = p.Y, purring = false, spot = seg.spot, segment = seg }
end

-- ---------------------------------------------------------------- the live cat
export type Spider = { pos: Vector3, speed: number, hidden: boolean, visible: boolean? }
export type Signal = { kind: string, at: Vector3?, away: Vector3? }

-- A new cat for a world seed (WorldMap.seed(914, "cat")).
function Cat.new(seed: number): any
	local self = setmetatable({
		seed = seed, day = 1, hour = 0,
		-- where it is and what it is doing, as drawn
		pos = Cat.SPOTS.sofa.pos, heading = Cat.SPOTS.sofa.heading, pose = "sleep", surface = Cat.SPOTS.sofa.pos.Y, purring = false, spot = "sofa",
		look = nil :: Vector3?, -- the point its head follows, while it watches something
		-- the live reaction (never saved)
		react = "none", reactS = 0, watchS = 0, stillS = 0, highS = 0, misses = 0, cooldown = 0, lag = 0, offset = Vector3.zero, pawAt = nil :: Vector3?, swatHit = false,
		-- this life's record (saved)
		notices = 0, pats = 0, swats = 0, lastSwatDay = 0,
		gentle = false, enabled = true, wakeS = 0, advance = 0,
		signals = {} :: { Signal },
	}, Cat)
	return self
end

-- The room a point is in, in plan ("hut", "back", or "doorway" for the doorway between, which is both).
function Cat.roomOf(p: Vector3): string?
	if p.X >= 146.5 and p.X <= 175 and p.Z >= 180 and p.Z <= 250 then return "doorway" end
	-- The window recess belongs to the room up to the pane. Otherwise both
	-- a spider on the sill and the seated cat's eyes were classified outside.
	if p.X > 445 and p.X < 459 and p.Z >= 98 and p.Z <= 170 then return "back" end
	for name, r in Cat.ROOMS do if p.X >= r[1] - 1 and p.X <= r[2] + 1 and p.Z >= 12.5 - 30 and p.Z <= 255.5 + 1 then return name end end
	return nil
end
local function sameRoom(a: Vector3, b: Vector3): boolean
	local ra, rb = Cat.roomOf(a), Cat.roomOf(b)
	if ra == nil or rb == nil then return false end
	return ra == rb or ra == "doorway" or rb == "doorway"
end
-- Whether its body can step to (x, z) on the floor when it stalks.
function Cat.free(x: number, z: number): boolean
	if x > 120 and x < 200 and z > 188 and z < 242 then return true end -- (through the doorway, x 146.5..175, z 180..250, and either side of it)
	for _, b in BLOCKS do if x > b[1] - 10 and x < b[2] + 10 and z > b[3] - 10 and z < b[4] + 10 then return false end end
	local r = Cat.roomOf(v(x, FL, z))
	if r == "hut" then return x > -146.5 + 12 and x < 146.5 - 12 and z > 12.5 + 12 and z < 255.5 - 12 end
	if r == "back" then return x > 175 + 12 and x < 445 - 12 and z > 12.5 + 12 and z < 255.5 - 12 end
	return r == "doorway"
end

-- Whether a spider at `p` is under the sofa (in the dark under its frame, where no paw reaches: World/Hut.SOFA's footprint, under its frame's 8 cm).
function Cat.under(p: Vector3): boolean
	local b = BLOCKS[1]
	return p.X > b[1] + 4 and p.X < b[2] - 4 and p.Z > b[3] + 4 and p.Z < b[4] - 4 and p.Y < -62
end

-- Its head and its chest, where it looks from and pats from.
function Cat.head(self: any): Vector3
	local seated = self.pose == "sit" or self.pose == "groom"
		or (self.pose == "watch" and (self.spot == "window" or self.surface > -60))
	-- Match CatPose's seated head, not its standing head outside the glass.
	if seated then return self.pos + self.heading * 12.5 + v(0,29,0) end
	return self.pos + self.heading * 24 + v(0, if self.pose == "sleep" or self.pose == "rest" then 8 else 22, 0)
end
function Cat.chest(self: any): Vector3
	return self.pos + self.heading * 14
end

local function flat(a: Vector3, b: Vector3): number
	return v(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Whether a spider at `p` is in its paw's reach: near its chest in plan, and no higher over its surface than it can rise to.
function Cat.inReach(self: any, p: Vector3): boolean
	return flat(Cat.chest(self), p) <= Cat.REACH and p.Y - self.surface <= Cat.REACH_UP and p.Y >= self.surface - 3
end

local function emit(self: any, kind: string, at: Vector3?, away: Vector3?)
	table.insert(self.signals, { kind = kind, at = at, away = away })
end

-- A draw for this notice (its watch's length), from the seed and how many it has made: the same for the same notice after a return to a rest.
local function draw(self: any, salt: number): number
	return rng(self.seed, 5000 + self.notices * 13 + salt)()
end

-- One step of `dt` seconds at the life clock's (day, hour), with the spider as it is now (`spider`: its body's position, its speed, whether it is hidden: in a
-- home, under the sofa). Puts the cat where its schedule (and any reaction) has it, and reacts. Signals: "noticed", "pat" (a pat that missed), "struck" (a pat
-- that landed in the standard rules), "nudged" (in the gentle rules: knocked aside, `away` the push's direction), "gave_up".
function Cat.step(self: any, dt: number, day: number, hour: number, spider: Spider?)
	self.day, self.hour = day, hour
	-- the schedule's place at its own time (behind by its lag while it caught up after a reaction)
	if self.react == "none" and self.lag > 0 then self.lag = math.max(0, self.lag - dt * Cat.CATCH_UP * HOUR_PER_S) end
	if self.react ~= "none" then self.lag += dt * HOUR_PER_S end
	local h = hour - self.lag + self.advance
	local dd = day
	while h < 0 do h += 24; dd -= 1 end
	while h >= 24 do h -= 24; dd += 1 end
	local place = Cat.at(self.seed, math.max(dd, 1), h)
	-- Movement can disturb a nap. Skip the remaining rest, not the trip off the
	-- furniture: the next authored walk begins at precisely the same perch.
	local resting = place.pose == "sleep" or place.pose == "rest"
	local disturbing = self.enabled and spider ~= nil and not spider.hidden
		and spider.speed >= Cat.WAKE_SPEED and sameRoom(place.pos, spider.pos)
		and flat(place.pos, spider.pos) <= Cat.NOTICE and math.abs(spider.pos.Y - place.surface) <= Cat.NOTICE_UP
	self.wakeS = if resting and disturbing then self.wakeS + dt else math.max(0, self.wakeS - dt * 2)
	if self.react == "none" and resting and self.cooldown <= 0 and self.wakeS >= Cat.WAKE_S then
		local departure: Segment? = nil
		local departureDay = math.max(dd, 1)
		for _, seg in Cat.plan(self.seed, departureDay) do
			if seg.kind == "walk" and seg.from == place.spot and seg.t0 >= h then departure = seg; break end
		end
		-- The final rest is on the sofa; its next departure is tomorrow morning.
		if departure == nil and place.spot == "sofa" then
			departureDay += 1
			departure = Cat.plan(self.seed, departureDay)[2]
		end
		if departure ~= nil then
			self.advance += (departureDay - math.max(dd, 1)) * 24 + departure.t0 - h
			place = Cat.at(self.seed, departureDay, departure.t0)
			self.wakeS = 0
			emit(self, "woke", place.pos)
		end
	end
	-- the stalk's offset comes back to nothing when it is not stalking
	if self.react == "none" and self.offset.Magnitude > 0 then
		local back = math.min(self.offset.Magnitude, Cat.WALK_SPEED * dt)
		self.offset -= self.offset.Unit * back
	end
	self.pos = place.pos + self.offset
	self.surface = place.surface
	self.spot = place.spot
	if self.react == "none" then
		self.heading, self.pose, self.purring = place.heading, (if self.offset.Magnitude > 0.5 then "walk" else place.pose), place.purring
		self.look = nil
	end
	self.cooldown = math.max(0, self.cooldown - dt)
	if not self.enabled or spider == nil then return end
	local awake = place.pose ~= "sleep" and place.pose ~= "jump"
	local moving = spider.speed >= Cat.MOVING
	if self.react == "none" then
		if awake and self.cooldown <= 0 and moving and not spider.hidden and spider.visible ~= false and sameRoom(Cat.head(self), spider.pos)
			and flat(Cat.head(self), spider.pos) <= Cat.NOTICE and spider.pos.Y - self.surface <= Cat.NOTICE_UP and spider.pos.Y >= self.surface - 5 then
			self.react, self.reactS, self.stillS, self.highS, self.misses = "watch", 0, 0, 0, 0
			self.watchS = Cat.WATCH[1] + (Cat.WATCH[2] - Cat.WATCH[1]) * draw(self, 1)
			self.notices += 1
			self.pose, self.purring = "watch", false
			emit(self, "noticed", spider.pos)
		end
		return
	end
	-- a reaction under way: it faces the thing and follows it with its head
	self.reactS += dt
	self.look = spider.pos
	local toward = v(spider.pos.X - self.pos.X, 0, spider.pos.Z - self.pos.Z)
	if toward.Magnitude > 1 and self.react ~= "swat" then
		local want = toward.Unit
		local turned = self.heading:Lerp(want, math.clamp(dt * 6, 0, 1))
		self.heading = if turned.Magnitude > 1e-3 then turned.Unit else want
	end
	local function giveUp()
		self.react, self.cooldown, self.look = "none", Cat.COOLDOWN, nil
		emit(self, "gave_up", spider.pos)
	end
	-- Losing sight behind a prop stops tracking immediately, including a pat.
	-- Hearing may wake the cat, but never supplies a target through a wall.
	if spider.hidden or spider.visible == false then giveUp(); return end
	self.stillS = if moving then 0 else self.stillS + dt
	local high = spider.pos.Y - self.surface > Cat.REACH_UP
	self.highS = if high then self.highS + dt else 0
	if self.react == "watch" or self.react == "stalk" then
		if self.stillS >= Cat.STILL_LOSE or self.highS >= Cat.HIGH_LOSE or not sameRoom(Cat.head(self), spider.pos) or flat(Cat.head(self), spider.pos) > Cat.NOTICE * 1.5 then
			giveUp()
			return
		end
		if Cat.inReach(self, spider.pos) and self.reactS >= self.watchS and self.stillS < 0.5 then -- (it pounces on what moves)
			self.react, self.reactS, self.pose = "crouch", 0, "crouch"
			return
		end
		-- not in reach: on the floor it creeps nearer (never off its own floor, never into the furniture, never far from its schedule's place)
		self.pose = "watch"
		if not high and self.surface <= FL + 2 and flat(Cat.chest(self), spider.pos) > Cat.REACH - 4 and self.reactS >= self.watchS * 0.5 then
			local step = toward.Unit * math.min(Cat.STALK_SPEED * dt, math.max(0, flat(Cat.chest(self), spider.pos) - (Cat.REACH - 6)))
			local next = self.offset + step
			local at = place.pos + next
			if next.Magnitude <= Cat.STALK_MAX and Cat.free(at.X, at.Z) then
				self.offset = next
				self.pos = at
				self.react, self.pose = "stalk", "stalk"
			end
		end
		return
	end
	if self.react == "crouch" then
		self.pose = "crouch"
		if self.reactS >= Cat.CROUCH_S then
			self.react, self.reactS, self.pose, self.swatHit = "swat", 0, "swat", false
			self.pawAt = spider.pos
		end
		return
	end
	if self.react == "swat" then
		self.pose = "swat"
		if not self.swatHit and self.reactS >= Cat.SWAT_S * 0.5 then
			self.swatHit = true
			if Cat.inReach(self, spider.pos) then
				self.swats += 1
				self.lastSwatDay = day
				local away = v(spider.pos.X - self.pos.X, 0, spider.pos.Z - self.pos.Z)
				away = if away.Magnitude > 1e-3 then away.Unit else self.heading
				if self.gentle then
					emit(self, "nudged", spider.pos, away)
					self.react, self.cooldown, self.look = "none", Cat.COOLDOWN, nil
				else
					emit(self, "struck", spider.pos, away)
					self.react, self.cooldown, self.look = "none", Cat.COOLDOWN, nil
				end
				return
			end
			self.pats += 1
			self.misses += 1
			emit(self, "pat", spider.pos)
		end
		if self.reactS >= Cat.SWAT_S then
			if self.misses >= Cat.MISSES then giveUp(); return end
			self.react, self.reactS, self.pose = "watch", 0, "watch"
			self.watchS = 0.6
		end
	end
end

-- Takes the signals since the last call.
function Cat.drainSignals(self: any): { Signal }
	local out = self.signals
	self.signals = {}
	return out
end

-- What a spider at `at` hears of it: the bell (0..1, while it walks, jumps, stalks or pats, by distance) and the purr (0..1, while it settles, close).
function Cat.sound(self: any, at: Vector3): (number, number)
	local d = (Cat.head(self) - at).Magnitude
	local moving = self.pose == "walk" or self.pose == "jump" or self.pose == "stalk" or self.pose == "swat" or self.pose == "crouch"
	local bell = if moving then math.clamp(1 - d / Cat.HEAR_BELL, 0, 1) else 0
	if self.pose == "stalk" or self.pose == "crouch" then bell *= 0.35 end -- (stalking, it moves so slowly the bell barely rings)
	local purr = if self.purring then math.clamp(1 - d / Cat.HEAR_PURR, 0, 1) else 0
	return bell, purr
end

-- Whether it is in the middle of something with the spider (a watch, a stalk, a crouch or a pat).
function Cat.reacting(self: any): boolean
	return self.react ~= "none"
end

-- ---------------------------------------------------------------- its record (Persistence/Checkpoint's optional `cat`)
export type Record = { notices: number, pats: number, swats: number, last_swat_day: number }
function Cat.defaultRecord(): Record
	return { notices = 0, pats = 0, swats = 0, last_swat_day = 0 }
end
function Cat.toRecord(self: any): Record
	return { notices = self.notices, pats = self.pats, swats = self.swats, last_swat_day = self.lastSwatDay }
end
local function count(x: any): boolean
	return type(x) == "number" and x == x and x >= 0 and x <= 1e6 and math.floor(x) == x
end
-- What is wrong with a record (none for a good one).
function Cat.problems(d: any): { string }
	local out: { string } = {}
	if type(d) ~= "table" then return { "cat: not a record" } end
	for _, k in { "notices", "pats", "swats", "last_swat_day" } do
		if not count(d[k]) then table.insert(out, `cat: {k} is not a count`) end
	end
	return out
end
-- Puts the record back (a good one; the caller checked it) and ends whatever it was doing: the next step puts it where its schedule says.
function Cat.load(self: any, d: Record)
	self.notices, self.pats, self.swats, self.lastSwatDay = d.notices, d.pats, d.swats, d.last_swat_day
	self.react, self.reactS, self.lag, self.offset, self.cooldown, self.look, self.misses = "none", 0, 0, Vector3.zero, 0, nil, 0
	self.wakeS, self.advance = 0, 0
	self.spiderPrevious = nil
	table.clear(self.signals)
end

return Cat
