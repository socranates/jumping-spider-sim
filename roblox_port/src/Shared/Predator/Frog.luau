--!strict
-- The green frog of the pond's edge (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "a frog's tongue"; the notebook's page "The green frog" says what is known of it).
-- A green frog (Lithobates clamitans), at true size: 7.8 cm from snout to vent (the sources: 5 to 10 cm), a sit-and-wait hunter at the water's edge that takes
-- whatever moving thing of a mouthful comes within reach, a spider among it. A frog's eye reacts to small things that move; one that keeps still is not food to it
-- (the sources: a frog surrounded by still food can starve). Its tongue is out and back in under 0.07 s.
--
-- Its day: it sits on one of two seats (World/Pond.FROG_SITES: the flat stone at the water's edge, the big lily pad), one a day by a seeded draw (a pure function
-- of the seed and the day, so a return to a rest finds it where it was; nothing of it is saved), facing the open margin. It sits still. That is the tell: a still
-- green shape at the edge, its eyes up, where a frog would be.
-- What it does (`step`): a spider that MOVES (faster than MOVING) within NOTICE of its head catches its eye: it turns to face it, a pivot of TURN_S seconds (it shifts
-- on its seat: the only movement it makes), and if the spider is still moving and within REACH of its mouth when it faces it, the tongue strikes: in the standard
-- rules a death with its own card (UI/FrogText, `struck`), in the gentle rules (Easy, Free play) it misses (`missed`) and the client knocks the spider aside. A spider
-- that keeps still for STILL_LOSE seconds, or is out of NOTICE, or hidden (a home, a rest) is lost to it, and it settles for COOLDOWN seconds. Its first close look
-- (SEEN) opens its page (`seen`). Live state that is not saved: its turn, its strike.
local Pond = require(script.Parent.Parent.World.Pond)
local WorldMap = require(script.Parent.Parent.World.WorldMap)

local Frog = {}
Frog.__index = Frog

Frog.LENGTH = 7.8 -- studs, snout to vent
Frog.NOTICE = 30 -- studs from its head: a moving spider within this catches its eye
Frog.REACH = 11 -- studs from its mouth: a lunge and the tongue
Frog.MOVING = 0.5 -- studs a second: slower than this, a spider is keeping still
Frog.TURN_S = 0.6 -- the pivot to face what moved
Frog.FACE = 0.85 -- the cosine within which it faces it
Frog.STILL_LOSE = 2.0 -- seconds still and it loses the spider
Frog.COOLDOWN = 5.0
Frog.SEEN = 40 -- the first close look
Frog.STRIKE_S = 0.07 -- the tongue, out and back
Frog.EYE_Y = 2.2 -- its eyes over its seat
Frog.MOUTH = 4.4 -- its mouth ahead of its middle
Frog.CAUSE = "frog"

local MOD = 2147483647
local function draw(seed: number, day: number, salt: number): number
	local s = (seed + day * 104729 + salt * 15485863) % MOD
	if s <= 0 then s += MOD - 1 end
	for _ = 1, 3 do s = (s * 48271) % MOD end
	return (s - 1) / (MOD - 1)
end

-- Which seat it sits on (1 or 2) on `day`, and the slight turn it sits at (degrees off the seat's facing).
function Frog.seatOf(seed: number, day: number): (number, number)
	return 1 + math.floor(draw(seed, day, 1) * #Pond.FROG_SITES), (draw(seed, day, 2) - 0.5) * 50
end

local seats: { [number]: any } = {}
function Frog.seatAt(i: number): Vector3?
	if seats[i] ~= nil then return seats[i] end
	local site = Pond.FROG_SITES[i]
	local r = WorldMap.region(site.region)
	if r == nil then return nil end
	local at = Pond.frogSeat(site, { r :: any })
	if at ~= nil then seats[i] = at end
	return at
end

function Frog.new(seed: number): any
	return setmetatable({
		seed = seed, gentle = false, enabled = true, day = -1, seat = 0, pos = Vector3.zero, heading = Vector3.xAxis, rest = Vector3.xAxis, state = "sit",
		t = 0, still = 0, cooldown = 0, strike = -1, met = false, signals = {}, strikes = 0, misses = 0, notices = 0, now = 0,
	}, Frog)
end

-- Start another life without invalidating references held by the client/presentation.
-- Seeded schedules and enable/rule configuration survive; reactions and signals do not.
function Frog.reset(self: any)
	local clean = Frog.new(self.seed)
	clean.enabled, clean.gentle = self.enabled, self.gentle
	table.clear(self)
	for key, value in clean do self[key] = value end
end

-- Puts it on its seat for `day`.
function Frog.place(self: any, day: number)
	self.day = day
	local i, turn = Frog.seatOf(self.seed, day)
	local at = Frog.seatAt(i)
	self.seat = i
	if at == nil then self.pos = Vector3.zero; self.here = false; return end
	self.here = true
	self.pos = at
	local f = Pond.FROG_SITES[i].facing
	local a = math.rad(turn)
	self.rest = Vector3.new(f.X * math.cos(a) - f.Z * math.sin(a), 0, f.X * math.sin(a) + f.Z * math.cos(a)).Unit
	self.heading = self.rest
	self.state, self.t, self.still, self.cooldown, self.strike = "sit", 0, 0, 0, -1
end

local function signal(self: any, kind: string, at: Vector3?)
	table.insert(self.signals, { kind = kind, at = at })
end

function Frog.head(self: any): Vector3
	return self.pos + Vector3.new(0, Frog.EYE_Y, 0) + self.heading * (Frog.MOUTH * 0.6)
end
function Frog.mouth(self: any): Vector3
	return self.pos + Vector3.new(0, 0.9, 0) + self.heading * Frog.MOUTH
end

-- One tick. `spider`: { pos, speed, hidden } or nil (no life to touch).
function Frog.step(self: any, dt: number, day: number, spider: any)
	self.now += dt
	if day ~= self.day then self:place(day) end
	if self.strike >= 0 then self.strike += dt; if self.strike > 0.4 then self.strike = -1 end end
	if self.cooldown > 0 then self.cooldown = math.max(0, self.cooldown - dt) end
	if not self.here then return end
	if spider == nil or not self.enabled then self.state = "sit"; return end
	local head = self:head()
	local toSpider = spider.pos - head
	local d = toSpider.Magnitude
	if d <= Frog.SEEN and not self.met then
		self.met = true
		signal(self, "seen", self.pos)
	end
	local flat = Vector3.new(spider.pos.X - self.pos.X, 0, spider.pos.Z - self.pos.Z)
	local moving = spider.speed > Frog.MOVING
	if self.state == "sit" then
		if self.cooldown <= 0 and not spider.hidden and moving and d <= Frog.NOTICE and flat.Magnitude > 1e-3 then
			self.state, self.t, self.still = "turn", 0, 0
			self.from = self.heading
			self.notices += 1
			signal(self, "noticed", spider.pos)
		else
			-- (back to how it sat, slowly)
			self.heading = self.heading:Lerp(self.rest, math.min(1, dt * 0.5)).Unit
		end
		return
	end
	-- turning or facing it: lost when hidden, out of notice, or still long enough
	if spider.hidden or d > Frog.NOTICE then self.state = "sit"; self.cooldown = Frog.COOLDOWN; signal(self, "lost", spider.pos); return end
	if moving then self.still = 0 else self.still += dt end
	if self.still >= Frog.STILL_LOSE then self.state = "sit"; self.cooldown = Frog.COOLDOWN; signal(self, "lost", spider.pos); return end
	local want = flat.Unit
	if self.state == "turn" then
		self.t += dt
		local k = math.clamp(self.t / Frog.TURN_S, 0, 1)
		self.heading = (self.from :: Vector3):Lerp(want, k)
		if self.heading.Magnitude < 1e-3 then self.heading = want end
		self.heading = self.heading.Unit
		if k >= 1 then self.state = "watch" end
		return
	end
	-- watching: it follows it with small shifts; a moving spider within reach in front of it is struck
	self.heading = self.heading:Lerp(want, math.min(1, dt * 4)).Unit
	local mouthTo = (spider.pos - self:mouth()).Magnitude
	if moving and mouthTo <= Frog.REACH and self.heading:Dot(want) >= Frog.FACE then
		self.strike = 0
		self.state = "sit"
		self.cooldown = Frog.COOLDOWN
		if self.gentle then
			self.misses += 1
			signal(self, "missed", spider.pos)
		else
			self.strikes += 1
			signal(self, "struck", spider.pos)
		end
	end
end

function Frog.drainSignals(self: any): { any }
	local out = self.signals
	self.signals = {}
	return out
end

-- Where the tongue's tip is, while it strikes (nil otherwise): out to the struck place and back in STRIKE_S.
function Frog.tongue(self: any, target: Vector3?): Vector3?
	if self.strike < 0 or self.strike > Frog.STRIKE_S then return nil end
	local m = self:mouth()
	local t = self.strike / Frog.STRIKE_S
	local out = if t < 0.5 then t * 2 else (1 - t) * 2
	return m:Lerp(target or (m + self.heading * Frog.REACH), out)
end

return Frog
