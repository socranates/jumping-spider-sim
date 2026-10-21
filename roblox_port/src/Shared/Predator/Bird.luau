--!strict
-- The robin of the open ground (ROBLOX-120, docs/PARK_WORLD_DESIGN.md sections 4 and 5: the bird is the danger of the hut garden, the meadow and the open ground
-- between; section 10 names the American robin at the feeder). An American robin (Turdus migratorius), at true size: 25 cm from bill to tail (the sources give 20 to
-- 28 cm), foraging on the ground as the sources describe it: it runs or hops a few steps, stops abruptly, stands still with its head cocked to one side looking at the
-- ground, and takes what it sees (earthworms most of all, and insects, snails and spiders). Pure: no engine, no drawing (Client/BirdBody draws it), so the client,
-- the self-test, the previewer and the CLI suites ask exactly the same bird.
--
-- Its day is a seeded schedule (`Bird.plan(seed, day)`: the world's seed through WorldMap.seed(914, "bird"), a Park-Miller stream per day): four to six visits between
-- 06:00 and 19:30, each to one of SITES (the hut garden's lawn west and east of the path, the bench patch's gravel by the path's end, the meadow's mown edge), so where
-- the robin is at an hour of a day is a pure function of the seed, the day and the hour, and a return to a rest finds it where the schedule says (restores never reroll;
-- nothing of it is saved). A visit, in seconds at the outdoors' pace (HOUR_PER_S: the garden's clock, 0.33 of the hut's):
--   approach ..... it flies in low over the ground from FLY_FROM studs off, gliding down onto the site's first point: its SHADOW sweeps over the ground ahead of it,
--                  and it calls ("pick, tut-tut-tut") as it comes in. This is how it is told first: a shadow and a call.
--   ground ....... it forages along the site's line, a stop (STOP seconds, its head cocked, now and then a peck at the ground) and a hop (HOP_LEN studs in HOP_S), over
--                  and back, for FORAGE seconds.
--   leave ........ it flies off up and away (its shadow again), calling.
--
-- What it does to a jumping spider (`step`): on the ground, a spider that MOVES in the open within NOTICE of its head catches its eye (`noticed`). It hops toward it
-- (never more than STALK_MAX off its line), and in REACH it stops dead with its head cocked at the spider for TELL seconds: the honest tell, a pause anyone watching
-- can see. If the spider is still moving in the open at the end of it, the robin strikes: in the standard rules a death with its own card (UI/BirdText, `struck`), in
-- the gentle rules (Easy, Free play) the bill misses (`missed`). The way out is cover or stillness: a spider in a retreat or resting (`hidden`), under something
-- (`Bird.covered`: a box over it within COVER_UP), low in the meadow's grass (`Bird.inGrass`), or keeping still for STILL_LOSE seconds, is lost (`lost`), and the
-- robin goes back to its foraging for COOLDOWN seconds before anything catches its eye again. It never reacts while it flies, and a spider high up (more than HIGH over
-- the ground it stands on) is not on its ground. Live state that is not saved: the reaction, how far it hopped off its line (eased back after).
-- Studs (a stud is a centimetre), the sill's frame (World/Preserve: +x east, -z north; the garden's ground World/Hut.GROUND).
local Bird = {}
Bird.__index = Bird

local GT = -84.6 -- the ground of the hut garden and the meadow (World/Hut.GROUND, World/Meadow.GROUND)
local v = Vector3.new

-- ---------------------------------------------------------------- the numbers (the game's, but the bird's size and its run-and-stop are the sources')
Bird.LENGTH = 25 -- studs, bill to tail
Bird.HEAD_Y = 13 -- its head over the ground, standing
Bird.HOUR_PER_S = 12.0 / (15.0 * 60.0) * 0.33 -- game hours a second at the outdoors' pace (Life/LifeClock.ACTIVE_HOURS_PER_S x the garden's clockScale)
Bird.APPROACH_S = 3.0 -- the flight in
Bird.LEAVE_S = 2.5 -- and off
Bird.FLY_FROM = 900 -- how far off (studs, in plan) the flight in starts
Bird.FLY_UP = 320 -- and how high over the ground
Bird.FORAGE = table.freeze({ 70.0, 150.0 }) -- seconds on the ground a visit
Bird.STOP = table.freeze({ 1.2, 3.6 }) -- a stop, head cocked
Bird.HOP_S = 0.3 -- a hop (a few quick steps: the "run")
Bird.HOP_LEN = table.freeze({ 10.0, 26.0 })
Bird.PECK = 0.35 -- a share of the stops end in a peck at the ground
Bird.VISITS = table.freeze({ 4, 6 })
Bird.DAY = table.freeze({ 6.0, 19.5 })
Bird.NOTICE = 70 -- how near (studs, in plan, from its head) a moving spider catches its eye
Bird.HIGH = 30 -- a spider more than this over the ground it stands on is not on its ground
Bird.REACH = 16 -- in plan from its bill's base: the dash and the stab
Bird.STALK_MAX = 90 -- how far it hops off its line toward what it saw
Bird.STALK_SPEED = 45 -- studs a second, hopping toward it
Bird.TELL = 0.85 -- the pause, head cocked at the spider, before the strike
Bird.STRIKE_S = 0.2 -- the stab
Bird.MOVING = 0.5 -- studs a second: slower than this, a spider is keeping still
Bird.STILL_LOSE = 1.2 -- seconds still and it loses the spider
Bird.COOLDOWN = 6.0 -- seconds after it lost one before anything catches its eye again
Bird.COVER_UP = 60 -- a box over the spider within this is cover from a bird's eye
Bird.GRASS_LOW = 25 -- in the meadow, lower than this over the ground is down in the grass
Bird.SHADOW_NEAR = 80 -- a shadow passing within this (in plan) of the spider is told
Bird.HEAR = 2500 -- studs: how far its call carries for the caption (25 m)
Bird.CALL_S = 2.5 -- it calls this long as it lands and as it leaves

-- The sites it forages, each a line on the ground it hops along (over and back): the hut garden's lawn either side of the path (clear of the trough, the stone and the
-- feeder's pole), the bench patch's gravel by the path's end (clear of the slab and the grate) and the meadow's mown edge along the gravel. `from`: the way it flies in
-- from (in plan), `zone` World/Preserve's.
export type Site = { id: string, zone: string, line: { Vector3 }, from: Vector3 }
local function site(id: string, zone: string, from: Vector3, pts: { { number } }): Site
	local line = {}
	for _, p in pts do table.insert(line, v(p[1], GT, p[2])) end
	return table.freeze({ id = id, zone = zone, line = table.freeze(line), from = from.Unit })
end
Bird.SITES = table.freeze({
	site("lawn_w", "hut_garden", v(-1, 0, -0.4), { { -185, -80 }, { -130, -115 }, { -70, -90 }, { -15, -125 } }),
	site("lawn_e", "hut_garden", v(1, 0, -0.3), { { 20, -130 }, { 80, -125 }, { 130, -100 }, { 185, -112 } }),
	site("gravel", "bench", v(0.4, 0, 1), { { -190, -850 }, { -100, -880 }, { -20, -845 }, { 70, -890 } }),
	site("edge", "meadow", v(-1, 0, 0.5), { { -290, -1126 }, { -180, -1122 }, { -60, -1127 }, { 60, -1123 }, { 170, -1126 } }),
}) :: { Site }
Bird.GROUND = GT

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

-- A move on the ground: a stop from t0 (head cocked; a peck from `peck` if it pecks) and a hop from t1 to t2 from `a` to `b`.
export type Move = { t0: number, t1: number, t2: number, a: Vector3, b: Vector3, heading: Vector3, peck: number? }
-- A visit: its start (hours), its site, its seconds (approach, ground, leave) and its moves on the ground.
export type Visit = { h0: number, h1: number, site: Site, forage: number, moves: { Move }, leaveFrom: Vector3, leaveTo: Vector3, cock: number }

-- The point `d` studs along a line walked over and back (a ping-pong), and the way it faces there.
local function along(line: { Vector3 }, d: number): (Vector3, Vector3)
	local total = 0
	for i = 2, #line do total += (line[i] - line[i - 1]).Magnitude end
	local s = d % (2 * total)
	local back = s > total
	if back then s = 2 * total - s end
	for i = 2, #line do
		local a, b = line[i - 1], line[i]
		local l = (b - a).Magnitude
		if s <= l or i == #line then
			local k = math.clamp(s / l, 0, 1)
			local dir = (b - a).Unit
			return a:Lerp(b, k), if back then -dir else dir
		end
		s -= l
	end
	return line[1], Vector3.xAxis
end

local planCache: { [string]: { Visit } } = {}
-- The robin's day: its visits, in order (none overlap).
function Bird.plan(seed: number, day: number): { Visit }
	local key = tostring(seed) .. "/" .. tostring(day)
	if planCache[key] then return planCache[key] end
	local rand = rng(seed, 2000 + day)
	local n = Bird.VISITS[1] + math.floor(rand() * (Bird.VISITS[2] - Bird.VISITS[1] + 1))
	local span = (Bird.DAY[2] - Bird.DAY[1]) / n
	local out: { Visit } = {}
	for i = 1, n do
		local s = Bird.SITES[1 + math.floor(rand() * #Bird.SITES) % #Bird.SITES]
		local forage = between(rand, Bird.FORAGE[1], Bird.FORAGE[2])
		local whole = (Bird.APPROACH_S + forage + Bird.LEAVE_S) * Bird.HOUR_PER_S
		local h0 = Bird.DAY[1] + (i - 1) * span + rand() * math.max(0, span - whole)
		-- the moves: from the line's first point, a stop and a hop, over and back
		local moves: { Move } = {}
		local t = 0.0
		local d = 0.0
		local here, heading = along(s.line, 0)
		while t < forage do
			local stop = between(rand, Bird.STOP[1], Bird.STOP[2])
			local peck = if rand() < Bird.PECK then t + stop * between(rand, 0.4, 0.75) else nil
			d += between(rand, Bird.HOP_LEN[1], Bird.HOP_LEN[2])
			local nextAt, nextHeading = along(s.line, d)
			local t1 = math.min(t + stop, forage)
			local t2 = math.min(t1 + Bird.HOP_S, forage)
			table.insert(moves, table.freeze({ t0 = t, t1 = t1, t2 = t2, a = here, b = if t2 > t1 then nextAt else here, heading = heading, peck = peck }))
			here, heading = (if t2 > t1 then nextAt else here), nextHeading
			t = t2
		end
		local up = Vector3.new(-s.from.X, 0, -s.from.Z)
		table.insert(out, table.freeze({
			h0 = h0, h1 = h0 + whole, site = s, forage = forage, moves = table.freeze(moves), leaveFrom = here,
			leaveTo = here + up * Bird.FLY_FROM + Vector3.yAxis * Bird.FLY_UP, cock = if rand() < 0.5 then -1 else 1,
		}))
	end
	planCache[key] = table.freeze(out)
	return out
end

-- Where the schedule has it at `hour` of `day`: nil when it is not here; else its place (pos: its feet, or its body in flight), heading, pose ("fly", "land",
-- "hop", "stand", "peck", "leave"), the shadow's place on the ground (nil while it stands: then the shadow is under it, drawn by the body), and whether it calls.
export type Place = { pos: Vector3, heading: Vector3, pose: string, shadow: Vector3?, calling: boolean, visit: Visit, secs: number, flying: boolean }
function Bird.at(seed: number, day: number, hour: number): Place?
	for _, visit in Bird.plan(seed, day) do
		if hour >= visit.h0 and hour < visit.h1 then
			local secs = (hour - visit.h0) / Bird.HOUR_PER_S
			local s = visit.site
			if secs < Bird.APPROACH_S then
				-- the glide in: from FLY_FROM off and FLY_UP up, down onto the line's first point, flattening out at the end
				local k = secs / Bird.APPROACH_S
				local land = s.line[1]
				local start = land + s.from * Bird.FLY_FROM + Vector3.yAxis * Bird.FLY_UP
				local e = 1 - (1 - k) * (1 - k)
				local flat = land:Lerp(start, 1 - k)
				local p = v(flat.X, land.Y + Bird.FLY_UP * (1 - e), flat.Z)
				local h = -s.from
				return { pos = p, heading = h, pose = if k > 0.85 then "land" else "fly", shadow = v(p.X, GT, p.Z), calling = true, visit = visit, secs = secs, flying = k <= 0.85 }
			end
			local g = secs - Bird.APPROACH_S
			if g < visit.forage then
				for _, m in visit.moves do
					if g < m.t2 or m == visit.moves[#visit.moves] then
						local calling = g < Bird.CALL_S
						if g < m.t1 then
							local pose = if m.peck ~= nil and g >= m.peck and g < m.peck + 0.4 then "peck" else "stand"
							return { pos = m.a, heading = m.heading, pose = pose, shadow = nil, calling = calling, visit = visit, secs = secs, flying = false }
						end
						local k = math.clamp((g - m.t1) / math.max(m.t2 - m.t1, 1e-6), 0, 1)
						local flat = m.b - m.a
						local hd = if flat.Magnitude > 1e-3 then v(flat.X, 0, flat.Z).Unit else m.heading
						return { pos = m.a:Lerp(m.b, k) + Vector3.yAxis * (math.sin(k * math.pi) * 3), heading = hd, pose = "hop", shadow = nil, calling = calling, visit = visit,
							secs = secs, flying = false }
					end
				end
			end
			-- off: up and away along the way it came, the other way
			local k = math.clamp((g - visit.forage) / Bird.LEAVE_S, 0, 1)
			local e = k * k
			local flat = visit.leaveFrom:Lerp(visit.leaveTo, e)
			local p = v(flat.X, GT + (visit.leaveTo.Y - GT) * e, flat.Z)
			local hd = v(visit.leaveTo.X - visit.leaveFrom.X, 0, visit.leaveTo.Z - visit.leaveFrom.Z).Unit
			return { pos = p, heading = hd, pose = "leave", shadow = v(p.X, GT, p.Z), calling = k < 0.6, visit = visit, secs = secs, flying = k > 0.08 }
		end
	end
	return nil
end

-- ---------------------------------------------------------------- cover (pure: the client hands in the region's boxes)
-- Whether a box of `pieces` is over a spider at `p`: its footprint over the point and its underside above it, within COVER_UP.
function Bird.covered(pieces: { any }, p: Vector3): boolean
	for _, b in pieces do
		local lo, hi = b.lo or b.min, b.hi or b.max
		if lo.Y > p.Y + 0.3 and lo.Y < p.Y + Bird.COVER_UP and p.X > lo.X - 0.2 and p.X < hi.X + 0.2 and p.Z > lo.Z - 0.2 and p.Z < hi.Z + 0.2 then return true end
	end
	return false
end
-- Whether a spider at `p` in a region of `kind` is down in the meadow's grass.
function Bird.inGrass(kind: string?, p: Vector3): boolean
	return kind == "meadow" and p.Y - GT < Bird.GRASS_LOW
end

-- ---------------------------------------------------------------- the live robin
export type Spider = { pos: Vector3, speed: number, hidden: boolean, covered: boolean }
export type Signal = { kind: string, at: Vector3? }

function Bird.new(seed: number): any
	return setmetatable({
		seed = seed, day = 1, hour = 0, here = false,
		pos = Vector3.zero, heading = Vector3.xAxis, pose = "away", shadow = nil :: Vector3?, calling = false, flying = false, site = nil :: string?,
		look = nil :: Vector3?, cock = 1, -- the point its cocked head looks at, and which side the head tips
		react = "none", reactS = 0, stillS = 0, cooldown = 0, offset = Vector3.zero, strikeAt = nil :: Vector3?, strikeS = -1,
		notices = 0, strikes = 0, misses = 0, losses = 0, shadows = 0, landings = 0, -- (this session's: the self-test reads them)
		gentle = false, enabled = true, signals = {} :: { Signal }, shadowNear = false, wasHere = false,
	}, Bird)
end

-- Its head (where it looks from) and its bill's base (where it strikes from).
function Bird.head(self: any): Vector3
	return self.pos + self.heading * 6 + Vector3.yAxis * Bird.HEAD_Y
end
function Bird.bill(self: any): Vector3
	return v(self.pos.X, GT, self.pos.Z) + self.heading * 9
end
local function flat(a: Vector3, b: Vector3): number
	return v(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function emit(self: any, kind: string, at: Vector3?)
	table.insert(self.signals, { kind = kind, at = at })
end

-- One step of `dt` seconds at the life clock's (day, hour), with the spider as it is now (nil while there is no life to touch). Signals: "landed" (it is on the
-- ground: told by its call), "shadow" (its shadow passed near the spider), "noticed", "lost", "struck" (standard rules), "missed" (gentle rules).
function Bird.step(self: any, dt: number, day: number, hour: number, spider: Spider?)
	self.day, self.hour = day, hour
	self.cooldown = math.max(0, self.cooldown - dt)
	if self.strikeS >= 0 then self.strikeS += dt; if self.strikeS > Bird.STRIKE_S + 0.3 then self.strikeS = -1 end end
	local place = Bird.at(self.seed, day, hour)
	if place == nil then
		self.here, self.pose, self.shadow, self.calling, self.flying, self.site = false, "away", nil, false, false, nil
		self.react, self.look, self.offset, self.wasHere = "none", nil, Vector3.zero, false
		return
	end
	self.here = true
	self.site = place.visit.site.id
	self.cock = place.visit.cock
	if not self.wasHere then self.wasHere = true end
	local onGround = not place.flying and place.pose ~= "fly" and place.pose ~= "leave" and place.pose ~= "land"
	if onGround and self.pose ~= "stand" and self.pose ~= "hop" and self.pose ~= "peck" and self.pose ~= "watch" and self.pose ~= "strike" then
		self.landings += 1
		emit(self, "landed", place.pos)
	end
	-- the stalk's offset eases back when it is not reacting, and is gone once it flies
	if not onGround then self.offset, self.react, self.look = Vector3.zero, "none", nil end
	if self.react == "none" and self.offset.Magnitude > 0 then
		local back = math.min(self.offset.Magnitude, Bird.STALK_SPEED * 0.5 * dt)
		self.offset -= self.offset.Unit * back
	end
	self.pos = place.pos + self.offset
	self.shadow, self.calling, self.flying = place.shadow, place.calling, place.flying
	if self.react == "none" then self.heading, self.pose, self.look = place.heading, place.pose, nil end
	-- the shadow passing over the spider (told once a pass)
	if spider ~= nil and place.shadow ~= nil then
		local near = flat(place.shadow, spider.pos) <= Bird.SHADOW_NEAR
		if near and not self.shadowNear then self.shadows += 1; emit(self, "shadow", place.shadow) end
		self.shadowNear = near
	else
		self.shadowNear = false
	end
	if not self.enabled or spider == nil or not onGround then return end
	local moving = spider.speed >= Bird.MOVING
	local open = not spider.hidden and not spider.covered and spider.pos.Y - GT <= Bird.HIGH
	if self.react == "none" then
		if self.cooldown <= 0 and moving and open and flat(Bird.head(self), spider.pos) <= Bird.NOTICE then
			self.react, self.reactS, self.stillS = "stalk", 0, 0
			self.notices += 1
			emit(self, "noticed", spider.pos)
		end
		return
	end
	-- a reaction under way: it faces the spider
	self.reactS += dt
	self.look = spider.pos
	local toward = v(spider.pos.X - self.pos.X, 0, spider.pos.Z - self.pos.Z)
	if toward.Magnitude > 0.5 then self.heading = toward.Unit end
	self.stillS = if moving then 0 else self.stillS + dt
	local function lose()
		self.react, self.cooldown, self.look = "none", Bird.COOLDOWN, nil
		self.losses += 1
		emit(self, "lost", spider.pos)
	end
	if not open or self.stillS >= Bird.STILL_LOSE or flat(Bird.head(self), spider.pos) > Bird.NOTICE * 1.4 then lose(); return end
	if self.react == "stalk" then
		if flat(Bird.bill(self), spider.pos) <= Bird.REACH then
			self.react, self.reactS, self.pose = "tell", 0, "watch"
			return
		end
		-- hop toward it, never far off its line
		self.pose = "hop"
		local step = toward.Unit * math.min(Bird.STALK_SPEED * dt, math.max(0, toward.Magnitude - Bird.REACH * 0.5))
		local nextOffset = self.offset + step
		if nextOffset.Magnitude <= Bird.STALK_MAX then self.offset = nextOffset; self.pos = place.pos + nextOffset else self.pose = "watch" end
		return
	end
	if self.react == "tell" then
		self.pose = "watch" -- (the head cocked at the spider, still: the tell)
		if self.reactS >= Bird.TELL then
			self.react, self.reactS, self.pose = "none", 0, "strike"
			self.strikeS, self.strikeAt = 0, spider.pos
			self.cooldown = Bird.COOLDOWN
			if flat(Bird.bill(self), spider.pos) <= Bird.REACH * 1.25 and moving then
				if self.gentle then
					self.misses += 1
					emit(self, "missed", spider.pos)
				else
					self.strikes += 1
					emit(self, "struck", spider.pos)
				end
			else
				self.losses += 1
				emit(self, "lost", spider.pos)
			end
		end
	end
end

-- Takes the signals since the last call.
function Bird.drainSignals(self: any): { Signal }
	local out = self.signals
	self.signals = {}
	return out
end

-- How loud its call is to a spider at `at` (0..1): while it calls, by distance.
function Bird.call(self: any, at: Vector3): number
	if not self.here or not self.calling then return 0 end
	return math.clamp(1 - (self.pos - at).Magnitude / Bird.HEAR, 0, 1)
end

-- Whether it is in the middle of something with the spider.
function Bird.reacting(self: any): boolean
	return self.react ~= "none"
end

-- The first visit of a day to a site (for the self-test and the previewer: a place and an hour where it is on the ground there), or nil.
function Bird.visitTo(seed: number, day: number, siteId: string): Visit?
	for _, visit in Bird.plan(seed, day) do
		if visit.site.id == siteId then return visit end
	end
	return nil
end
-- The hour `secs` seconds into a visit.
function Bird.hourOf(visit: Visit, secs: number): number
	return visit.h0 + secs * Bird.HOUR_PER_S
end

return Bird
