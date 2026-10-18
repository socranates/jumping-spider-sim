--!strict
-- WaspDirector: the black-and-yellow mud dauber's visits to the sill, without the engine. A port of the frozen
-- scripts/predator/wasp_director.gd and its actor scripts/predator/wasp.gd (LIFE round 4; LIFE-03 the first predator; LIFE-01 death can
-- be real and jarring, not sensationalized; spec 2 no threat spawning behind the player and no unexplained death; spec 8.3 search,
-- inspect, approach, strike, disengage). Every number is in Data/Wasp.
--
-- When. At most one visit a day, in the warm middle of the day, never on the first day, never before the spider has finished its first
-- meal, and never while it rests or moults in the crack. Whether a day has a visit, and when, follows from the world's seed and the day
-- alone, so a return to a checkpoint meets the same wasp (the port's own hash: Godot's cannot be reproduced in Luau, so the same seed
-- does not give the same days as Godot).
--
-- Warned. The wasp is heard before it is near: it comes in over the window frame from outside for ARRIVE_S and does not search until it
-- is on the sill. When it lands the spider feels it. When it has seen the spider it turns toward it and comes to look (INSPECT_S at arm's
-- length) before it strikes.
--
-- Search by sight. It moves between authored places on the sill where a spider might be: it hovers and looks, and on open surfaces it may
-- land and walk, its antennae flicking. It knows nothing it has not seen. Each tick that it can see the spider (in range, a clear line,
-- not in the retreat) its notice grows, much faster when the spider moves than when it keeps still, and faster near than far. Out of
-- sight, notice fades. Full notice: it has found the spider.
--
-- Escapes. The silk-lined crack is safe. A jump, a drop on the line, or getting out of sight breaks its approach; then it is confused and
-- searches somewhere at least FAR_FROM_LOSS_WU away. Its strike is a short lunge at where the spider was: a spider that moves off quickly
-- is missed. After SEARCH_S of searching it gives up and flies away.
--
-- Caught. The wasp stings and the spider goes still; the wasp carries it up and away over the frame (`heldAt` is where the spider hangs).
-- The host presents that. The spider is paralysed by the sting, not killed (LIFE-03).
--
-- What is handed in. The director knows the world only through three functions (`ray`, `clear`, `inRetreat`), the spider only through the
-- Spider table of this tick and the life clock only through the Block table, so the plain Luau CLI replays it against Godot's goldens
-- (tests/wasp_reference.json, tools/export_wasp_reference.gd) on an analytic world, and the client gives it the real sill's casts.
-- Random draws come from `rng` (range, unit, int); the tests hand it a scripted one.
--
-- Not ported: Gentle rules (the wasp touches the spider and leaves; Godot's round 5 modes): the flag exists and the rule is here, but
-- Roblox has no mode choice yet, so it is never set. The sound is the host's (captions only; no audio assets).

local Data = require(script.Parent.Parent.Data.Wasp)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)

local WaspDirector = {}
WaspDirector.__index = WaspDirector

WaspDirector.PHASES = table.freeze({ "away", "arriving", "searching", "inspecting", "striking", "carrying", "leaving" })

export type Rng = {
	range: (Rng, number, number) -> number, -- a number in [lo, hi)
	unit: (Rng) -> number, -- a number in [0, 1)
	int: (Rng, number, number) -> number, -- a whole number in [lo, hi]
}
-- What the director asks of the world. `ray`: something solid between two points. `clear`: a sphere of that radius goes from a to b
-- without touching the world. `inRetreat`: inside the silk-lined crack.
export type World = {
	ray: (Vector3, Vector3) -> boolean,
	clear: (Vector3, Vector3, number) -> boolean,
	inRetreat: (Vector3) -> boolean,
}
-- The spider this tick.
export type Spider = {
	position: Vector3,
	velocity: Vector3,
	walkSpeed: number,
	airborne: boolean, -- in a jump
	falling: boolean, -- let down on its line (or fallen)
}
-- The life this tick (Godot: the habitat loop and the feeding controller).
export type Block = { day: number, hour: number, resting: boolean, moulting: boolean, meals: number }
export type Signal = { kind: string, [string]: any }

local UP = Vector3.new(0, 1, 0)
local DOWN = Vector3.new(0, -1, 0)
local FORWARD = Vector3.new(0, 0, -1)
local TAU = math.pi * 2

local function rotateY(v: Vector3, angle: number): Vector3
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end

local function pathLength(path: { Vector3 }): number
	local total = 0.0
	for i = 2, #path do total += (path[i - 1] - path[i]).Magnitude end
	return math.max(total, 1e-3)
end

-- The default random stream for a visit: the port's Park-Miller, mixed from the seed, the day and the visit.
local function makeStream(seed: number, a: number, b: number): Rng
	local r = PreyRandom.new((seed * 73856093 + a * 19349663 + b * 83492791 + 12345) % 2147483647)
	r:next()
	r:next()
	return {
		range = function(_, lo: number, hi: number): number return lo + (hi - lo) * r:next() end,
		unit = function(): number return r:next() end,
		int = function(_, lo: number, hi: number): number return lo + math.min(math.floor(r:next() * (hi - lo + 1)), hi - lo) end,
	} :: any
end

-- `config.seed`: the world's seed. `config.world`: the three functions. `config.enabled`: false and it never comes by itself (test worlds;
-- force still brings it). `config.makeRng(day, visit)`: the random stream of a visit (tests).
function WaspDirector.new(config: { seed: number, world: World, enabled: boolean?, makeRng: ((number, number) -> Rng)? }): any
	local self = setmetatable({
		world = config.world, enabled = config.enabled ~= false, seed = config.seed, makeRng = config.makeRng,
		-- The wasp as the spider's senses have it (wasp.gd).
		wasp = {
			position = Vector3.new(0, 0, 0), heading = FORWARD, velocity = Vector3.new(0, 0, 0), normal = UP,
			mode = "flying", search = 0.0, visible = false, prev = Vector3.new(0, 0, 0),
		},
		phase = "away", visitS = 0.0, phaseS = 0.0, searchLeft = 0.0, notice = 0.0, confusedS = 0.0,
		noticedThisVisit = false, sparedThisVisit = false, gentle = false,
		lastVisitDay = 0, visits = 0, escapes = 0,
		events = {} :: { { kind: string, t: number } },
		signals = {} :: { Signal },
		-- Where the spider hangs while it is carried (nil otherwise); the host moves the spider there each tick.
		heldAt = nil :: Vector3?, holding = false,
		-- The visit in progress.
		rng = nil :: Rng?, path = {} :: { Vector3 }, pathI = 1, speed = Data.flySpeed, point = 1, recent = {} :: { number },
		sub = "", subS = 0.0, walkDir = Vector3.new(0, 0, 0), stepS = 0.0, openPos = Vector3.new(0, 0, 0), lastSeen = Vector3.new(0, 0, 0),
		unseenS = 0.0, holdS = 0.0, lossPos = nil :: Vector3?, strikeFrom = Vector3.new(0, 0, 0), strikeTo = Vector3.new(0, 0, 0),
		dt = 1 / 60, spider = nil :: Spider?,
	}, WaspDirector)
	return self
end

function WaspDirector.isVisiting(self: any): boolean
	return self.phase ~= "away"
end

-- ---------------------------------------------------------------------------------------------------------------- when it comes

-- Whether day `day` has a visit, and at what hour: -1 when it has none. From the seed and the day alone.
function WaspDirector.plannedHour(self: any, day: number): number
	if day < Data.firstDay then return -1.0 end
	local r = makeStream(self.seed, day, 7)
	if r:unit() >= Data.visitChance then return -1.0 end
	return r:range(Data.windowFromH, Data.windowToH - 1.0)
end

-- Why a visit could not begin now ("" when it could), apart from the hour.
function WaspDirector.blocked(_self: any, block: Block): string
	if block.day < Data.firstDay then return "the first day" end
	if block.meals < 1 then return "no meal yet" end
	if block.resting or block.moulting then return "resting" end
	return ""
end

function WaspDirector._maybeBegin(self: any, block: Block)
	local day = block.day
	if day == self.lastVisitDay then return end
	local hour = self:plannedHour(day)
	if hour < 0.0 or block.hour < hour or block.hour >= Data.windowToH then return end
	if self:blocked(block) ~= "" then return end
	self:beginVisit(day)
end

-- The index of the search place with this id, nil when there is none.
function WaspDirector.pointIndex(id: string): number?
	for i, p in Data.points do
		if p.id == id then return i end
	end
	return nil
end

-- Brings the wasp now (tests, the test place's attribute). `at`: the id of the place it searches first (nil lets the visit choose). False
-- when it is already here.
function WaspDirector.force(self: any, day: number, at: string?): boolean
	if self.phase ~= "away" then return false end
	self:beginVisit(day, if at then WaspDirector.pointIndex(at) else nil)
	return true
end

function WaspDirector.beginVisit(self: any, day: number, first: number?)
	self.lastVisitDay = day
	self.visits += 1
	self.rng = if self.makeRng then self.makeRng(day, self.visits) else makeStream(self.seed, day * 1009 + 13, self.visits)
	self.events = {}
	self.visitS = 0.0
	self.notice = 0.0
	self.confusedS = 0.0
	self.noticedThisVisit = false
	self.sparedThisVisit = false
	self.searchLeft = Data.searchS * (self.searchScale or 1)
	self.recent = {}
	self.lossPos = nil
	self.holding = false
	self.heldAt = nil
	self.point = first or self.rng:int(1, #Data.points)
	local to: Vector3 = Data.points[self.point].hover
	self.path = { Data.entry, Data.over, Vector3.new(to.X, Data.cruiseY, to.Z), to }
	self.pathI = 2
	self.speed = pathLength(self.path) / Data.arriveS
	self:_place(Data.entry)
	self.wasp.mode = "flying"
	self.wasp.search = 0.0
	self.wasp.visible = true
	self:_setPhase("arriving")
	self:_log("warning")
	self:_signal({ kind = "visit_started", first = self.visits == 1, point = Data.points[self.point].id })
end

-- ---------------------------------------------------------------------------------------------------------------- the tick

-- One fixed tick, after the spider has moved. `spider`: this tick's spider; `block`: this tick's life. Nothing is read from the spider
-- while the wasp is away.
function WaspDirector.step(self: any, dt: number, spider: Spider, block: Block)
	self.dt = dt
	self.spider = spider
	local phase: string = self.phase
	if phase == "away" then
		if self.enabled then self:_maybeBegin(block) end
		return
	end
	self.visitS += dt
	self.phaseS += dt
	if phase == "arriving" then
		if self:_advance(dt) then
			self.openPos = self.wasp.position
			self:_setPhase("searching")
			self:_log("searching")
			self.sub = "hover"
			self.subS = self.rng:range(Data.hoverS[1], Data.hoverS[2])
		end
	elseif phase == "searching" then
		self.searchLeft -= dt
		self:_search(dt)
		self:_look(dt)
		if self.notice >= 1.0 then
			self:_beginInspecting()
		elseif self.searchLeft <= 0.0 and (self.sub == "hover" or self.sub == "fly") then
			self:_beginLeaving()
		end
	elseif phase == "inspecting" then
		self:_inspect(dt)
	elseif phase == "striking" then
		self:_strike(dt)
	elseif phase == "carrying" then
		local done = self:_advance(dt)
		self:_holdSpider()
		if done then
			self:_setPhase("away")
			self.wasp.visible = false
			self:_signal({ kind = "carried_off" })
		end
	elseif phase == "leaving" then
		if self:_advance(dt) then
			self.wasp.visible = false
			self:_setPhase("away")
			if self.noticedThisVisit then self.escapes += 1 end
			self:_log("left")
			self:_signal({ kind = "left", escaped = self.noticedThisVisit })
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------- searching

function WaspDirector._search(self: any, dt: number)
	local wasp = self.wasp
	local sub: string = self.sub
	if sub == "fly" then
		wasp.search = 0.3
		if self:_advance(dt) then
			self.openPos = wasp.position
			self.sub = "hover"
			self.subS = self.rng:range(Data.hoverS[1], Data.hoverS[2])
		end
	elseif sub == "hover" then
		wasp.mode = "flying"
		wasp.search = 0.8
		self:_moveTo(wasp.position, rotateY(wasp.heading, math.rad(Data.scanDegS) * dt), dt)
		self.subS -= dt
		if self.subS <= 0.0 then
			local p = Data.points[self.point]
			if p.land ~= nil and self.rng:unit() < Data.landChance and self.searchLeft > Data.landS + Data.walkS then
				self.sub = "land"
				self.path = { wasp.position, p.land }
				self.pathI = 2
				self.speed = (wasp.position - p.land).Magnitude / Data.landS
			else
				self:_nextPoint()
			end
		end
	elseif sub == "land" then
		if self:_advance(dt) then
			wasp.mode = "walking"
			wasp.normal = UP
			self.openPos = wasp.position
			self:_shake("heavy landing")
			self:_log("landed")
			self:_signal({ kind = "landed", at = wasp.position })
			self.sub = "walk"
			self.subS = Data.walkS
			self.stepS = Data.stepEveryS
			self.walkDir = rotateY(FORWARD, self.rng:range(0.0, TAU))
		end
	elseif sub == "walk" then
		wasp.search = 1.0
		self:_walk(dt)
		self.subS -= dt
		if self.subS <= 0.0 then
			self.sub = "takeoff"
			local up = wasp.position + UP * 1.2
			self.path = { wasp.position, up }
			self.pathI = 2
			self.speed = Data.flySpeed * 0.5
			wasp.mode = "flying"
		end
	elseif sub == "takeoff" then
		if self:_advance(dt) then
			self.openPos = wasp.position
			self:_nextPoint()
		end
	end
end

-- A few steps along the surface it stands on, turning back where it would step off.
function WaspDirector._walk(self: any, dt: number)
	local wasp = self.wasp
	local p: Vector3 = wasp.position
	local nxt = p + self.walkDir * Data.walkSpeed * dt
	if not self.world.ray(nxt + UP * 0.3, nxt + DOWN * 0.8) or not self:_clear(p, nxt, Data.walkRadius) then
		self.walkDir = -self.walkDir
		nxt = p
	end
	self:_moveTo(nxt, self.walkDir, dt)
	self.stepS -= dt
	if self.stepS <= 0.0 then
		self.stepS = Data.stepEveryS
		self:_shake("heavy footsteps")
	end
end

function WaspDirector._nextPoint(self: any)
	table.insert(self.recent, self.point)
	while #self.recent > 3 do table.remove(self.recent, 1) end
	local here: Vector3 = self.wasp.position
	local choices: { number } = {}
	for i, pt in Data.points do
		if table.find(self.recent, i) then continue end
		local hover: Vector3 = pt.hover
		local loss: Vector3? = self.lossPos
		if loss ~= nil and (hover - loss).Magnitude < Data.farFromLossWu then continue end
		table.insert(choices, i)
	end
	if #choices == 0 then table.insert(choices, (self.point % #Data.points) + 1) end
	-- A local search: the nearer half of the places it has not just looked at.
	table.sort(choices, function(a: number, b: number): boolean
		return (here - Data.points[a].hover).Magnitude < (here - Data.points[b].hover).Magnitude
	end)
	local count = math.max(1, (#choices + 1) // 2)
	self.point = choices[self.rng:int(1, count)]
	self:_flyTo(Data.points[self.point].hover, Data.flySpeed)
	self.sub = "fly"
end

-- ---------------------------------------------------------------------------------------------------------------- seeing the spider

-- Whether it can see the spider now: in range, nothing in the way, and not in the retreat.
function WaspDirector.canSeeSpider(self: any): boolean
	local s: Spider? = self.spider
	if s == nil or self.holding or not self.wasp.visible then return false end
	if self.world.inRetreat(s.position) then return false end
	local eye = self:eyePosition()
	if (eye - s.position).Magnitude > Data.sightWu then return false end
	return not self.world.ray(eye, s.position)
end

function WaspDirector.eyePosition(self: any): Vector3
	return self.wasp.position + self.wasp.heading * Data.eyeAhead
end

-- How fast notice grows now (per second) if it can see the spider.
function WaspDirector.noticeRate(self: any): number
	local s: Spider = self.spider
	local d = (self:eyePosition() - s.position).Magnitude
	local walk = math.max(s.walkSpeed, 0.1)
	local motion = math.clamp(s.velocity.Magnitude / walk, 0.0, 1.5)
	if s.airborne then motion = 1.5 end
	return (self.noticeScale or 1) * (Data.noticeStill + Data.noticeMoving * motion) * math.max(1.0 - d / Data.sightWu, 0.0)
end

function WaspDirector._look(self: any, dt: number)
	if self.confusedS > 0.0 then
		self.confusedS -= dt
		return
	end
	if self:canSeeSpider() then
		self.notice += self:noticeRate() * dt
		self.lastSeen = (self.spider :: Spider).position
	else
		self.notice = math.max(self.notice - Data.noticeDecay * dt, 0.0)
	end
end

function WaspDirector._beginInspecting(self: any)
	self.notice = 1.0
	self.noticedThisVisit = true
	self.unseenS = 0.0
	self.holdS = 0.0
	if self.wasp.mode == "walking" then self.wasp.mode = "flying" end
	self:_setPhase("inspecting")
	self:_log("noticed")
	self:_signal({ kind = "noticed", at = self.lastSeen })
end

-- Comes to look: to arm's length from where it last saw the spider, then holds there, antennae busy, for INSPECT_S, then strikes. A
-- jump, a drop, the retreat, or the spider out of sight for LOSE_UNSEEN_S, and it has lost it.
function WaspDirector._inspect(self: any, dt: number)
	local s: Spider = self.spider
	local wasp = self.wasp
	wasp.mode = "flying"
	wasp.search = 1.0
	if self.world.inRetreat(s.position) then
		self:_lose("hid")
		return
	end
	if s.airborne then
		self:_lose("jumped")
		return
	end
	if s.falling then
		self:_lose("dropped")
		return
	end
	if self:canSeeSpider() then
		self.unseenS = 0.0
		self.lastSeen = s.position
	else
		self.unseenS += dt
		if self.unseenS > Data.loseUnseenS then
			self:_lose("out of sight")
			return
		end
	end
	if self.phaseS > Data.inspectGiveUpS then
		self:_lose("out of reach")
		return
	end
	local away: Vector3 = wasp.position - self.lastSeen
	if away.Magnitude < 1e-3 then away = UP end
	local standoff = self.lastSeen + away.Unit * Data.standoffWu
	local to = standoff - wasp.position
	local step = Data.inspectSpeed * dt
	local face = self.lastSeen - wasp.position
	if to.Magnitude > 0.05 then
		local nxt = wasp.position + (if to.Magnitude > step then to.Unit * step else to)
		if self:_clear(wasp.position, nxt, Data.radius) then
			self:_moveTo(nxt, face, dt)
		else
			self:_moveTo(wasp.position, face, dt)
		end
		self.holdS = math.max(self.holdS - dt, 0.0)
	else
		self:_moveTo(wasp.position, face, dt)
		self.holdS += dt
		if self.holdS >= Data.inspectS * (self.inspectScale or 1) then
			self.strikeFrom = wasp.position
			self.strikeTo = s.position
			self:_setPhase("striking")
			self:_log("strike")
		end
	end
end

function WaspDirector._strike(self: any, dt: number)
	local k = math.clamp(self.phaseS / Data.strikeS, 0.0, 1.0)
	self:_moveTo(self.strikeFrom:Lerp(self.strikeTo, k), self.strikeTo - self.strikeFrom, dt)
	if k < 1.0 then return end
	local s: Spider = self.spider
	if (self.wasp.position - s.position).Magnitude <= Data.catchWu and not self.world.inRetreat(s.position) and not s.airborne then
		if self.gentle then self:_spare() else self:_catch() end
	else
		self:_lose("missed")
	end
end

-- Gentle rules (Godot round 5: Easy and free play): the wasp touches the spider with its antennae and gives up on it, and leaves. Roblox
-- has no such mode yet, so `gentle` is never set outside the tests.
function WaspDirector._spare(self: any)
	self.sparedThisVisit = true
	self:_log("spared")
	self:_signal({ kind = "lost", why = "spared" })
	self:_beginLeaving()
end

function WaspDirector._catch(self: any)
	local wasp = self.wasp
	self.holding = true
	wasp.mode = "holding"
	wasp.search = 0.0
	local p: Vector3 = wasp.position
	self.path = { p, p + UP * 2.5, Data.over }
	self.pathI = 2
	self.speed = pathLength(self.path) / Data.carryS
	self:_setPhase("carrying")
	self:_log("caught")
	self:_holdSpider()
	self:_signal({ kind = "caught" })
end

function WaspDirector._holdSpider(self: any)
	if self.holding then self.heldAt = self.wasp.position + DOWN * Data.holdBelow end
end

function WaspDirector._lose(self: any, why: string)
	self.lossPos = self.lastSeen
	self.notice = Data.afterLossNotice
	self.confusedS = Data.confuseS
	self:_setPhase("searching")
	self:_log("lost:" .. why)
	self:_signal({ kind = "lost", why = why })
	self:_nextPoint()
end

function WaspDirector._beginLeaving(self: any)
	local p: Vector3 = self.wasp.position
	local path = self:_route(p, Data.over)
	table.insert(path, Data.entry)
	self.path = path
	self.pathI = 2
	self.speed = pathLength(path) / Data.leaveS
	self.wasp.mode = "flying"
	self.wasp.search = 0.0
	self:_setPhase("leaving")
	self:_log("leaving")
end

-- ---------------------------------------------------------------------------------------------------------------- paths and the world

function WaspDirector._flyTo(self: any, to: Vector3, speed: number)
	self.path = self:_route(self.wasp.position, to)
	self.pathI = 2
	self.speed = speed
end

-- Up to cruising height (from somewhere open above it), across, and down to `to`.
function WaspDirector._route(self: any, from: Vector3, to: Vector3): { Vector3 }
	local path: { Vector3 } = { from }
	local start = from
	if from.Y < Data.cruiseY and not self:_clear(from, Vector3.new(from.X, Data.cruiseY, from.Z), Data.radius) then
		table.insert(path, self.openPos)
		start = self.openPos
	end
	if start.Y < Data.cruiseY then table.insert(path, Vector3.new(start.X, Data.cruiseY, start.Z)) end
	if to.Y < Data.cruiseY then table.insert(path, Vector3.new(to.X, Data.cruiseY, to.Z)) end
	table.insert(path, to)
	return path
end

-- Moves along the path at the current speed; true at its end.
function WaspDirector._advance(self: any, dt: number): boolean
	local wasp = self.wasp
	local p: Vector3 = wasp.position
	local left = self.speed * dt
	local path: { Vector3 } = self.path
	while self.pathI <= #path and left > 0.0 do
		local target = path[self.pathI]
		local d = (target - p).Magnitude
		if d <= left then
			p = target
			left -= d
			self.pathI += 1
		else
			p += (target - p) / d * left
			left = 0.0
		end
	end
	local dir = p - wasp.position
	self:_moveTo(p, if dir.Magnitude > 1e-5 then dir else wasp.heading, self.dt)
	return self.pathI > #path
end

-- True when a sphere of `radius` moves from `a` to `b` without touching the world.
function WaspDirector._clear(self: any, a: Vector3, b: Vector3, radius: number): boolean
	if (a - b).Magnitude < 1e-5 then return true end
	return self.world.clear(a, b, radius)
end

-- ---------------------------------------------------------------------------------------------------------------- the actor (wasp.gd)

-- Places it and faces it along `dir` (flattened), and works out its velocity from where it was.
function WaspDirector._moveTo(self: any, p: Vector3, dir: Vector3, dt: number)
	local wasp = self.wasp
	wasp.position = p
	wasp.velocity = if dt > 0.0 then (p - wasp.prev) / dt else Vector3.new(0, 0, 0)
	wasp.prev = p
	local flat = Vector3.new(dir.X, 0.0, dir.Z)
	if flat.Magnitude > 1e-4 then wasp.heading = flat.Unit end
end

-- Puts it somewhere without a velocity (its first appearance).
function WaspDirector._place(self: any, p: Vector3)
	self.wasp.position = p
	self.wasp.prev = p
	self.wasp.velocity = Vector3.new(0, 0, 0)
end

-- What the spider's senses get of it: movement, never prey (its percept is capped at movement, so no aim, capture or inspection ever
-- treats it as something to catch). Nil while it is away.
function WaspDirector.percept(self: any): any
	local w = self.wasp
	if not w.visible then return nil end
	return { id = "wasp", position = w.position, radius = Data.sensedRadius, velocity = w.velocity, maxCategory = "movement" }
end

function WaspDirector._shake(self: any, kind: string)
	self:_signal({ kind = "shake", shake = kind, at = self.wasp.position + DOWN * 0.35 })
end

function WaspDirector._setPhase(self: any, p: string)
	self.phase = p
	self.phaseS = 0.0
end

function WaspDirector._log(self: any, kind: string)
	table.insert(self.events, { kind = kind, t = self.visitS })
end

function WaspDirector._signal(self: any, s: Signal)
	table.insert(self.signals, s)
end

-- The signals since the last call, oldest first: visit_started, shake (a landing or a footstep), landed, noticed, lost, caught,
-- carried_off, left.
function WaspDirector.drainSignals(self: any): { Signal }
	local out = self.signals
	self.signals = {}
	return out
end

-- ---------------------------------------------------------------------------------------------------------------- checkpoints

-- Kept in checkpoints: the day of the last visit, and how many visits and escapes this life has had. A visit going on is not kept,
-- because the spider rests in the crack where the wasp cannot find it.
function WaspDirector.toRecord(self: any): { [string]: number }
	return { last_visit_day = self.lastVisitDay, visits = self.visits, escapes = self.escapes }
end

-- The record of a life the wasp has not yet visited.
function WaspDirector.defaultRecord(): { [string]: number }
	return { last_visit_day = 0, visits = 0, escapes = 0 }
end

-- Puts a record back and ends any visit going on (the wasp is away and the spider is no longer held).
function WaspDirector.load(self: any, d: any)
	self.lastVisitDay = math.floor(tonumber(d.last_visit_day) or 0)
	self.visits = math.floor(tonumber(d.visits) or 0)
	self.escapes = math.floor(tonumber(d.escapes) or 0)
	self:clearVisit()
end

-- Ends the visit, if any: away, hidden, nothing held. (A return to a rest, a new life.)
function WaspDirector.clearVisit(self: any)
	self.phase = "away"
	self.phaseS = 0.0
	self.visitS = 0.0
	self.notice = 0.0
	self.confusedS = 0.0
	self.holding = false
	self.heldAt = nil
	self.wasp.visible = false
	self.signals = {}
	self.events = {}
end

function WaspDirector.problems(d: any): { string }
	local out: { string } = {}
	if type(d) ~= "table" then
		table.insert(out, "wasp: not a record")
		return out
	end
	for _, key in { "last_visit_day", "visits", "escapes" } do
		local v = d[key]
		if type(v) ~= "number" or v ~= v or v < 0 or v ~= math.floor(v) then
			table.insert(out, `wasp: {key} must be a whole number, not negative`)
		end
	end
	if #out == 0 and d.escapes > d.visits then table.insert(out, "wasp: more escapes than visits") end
	return out
end

return WaspDirector
