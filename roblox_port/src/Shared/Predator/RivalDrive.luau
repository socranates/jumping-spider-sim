--!strict
-- The rival spider's legs (ROBLOX-69): its own SpiderMotor, the player's proven surface-walking motor with the same collider, drives it over
-- every face of the windowsill. This module is the brain between RivalSpider's state (patrol, stalk, windup, ...) and that motor: it picks the
-- places to patrol to, plans the seams to cross (RivalRoute), and hands the motor an ordinary TickInput each tick. Decisions (sight, faces,
-- routes) run every Rules.thinkSeconds, not every tick; the motor itself steps every tick while it walks and every tenth while it stands.
-- The rival's plain state (RivalSpider) stays the one thing a checkpoint holds: the drive keeps only what can be made again from it. It does
-- not know the engine: the motor and a sight query are handed in, so the CLI runs it on the box world and Studio on the real sill.
local Route = require(script.Parent.RivalRoute)
local Rules = require(script.Parent.Parent.Data.RivalRules)
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)
local SupportMath = require(script.Parent.Parent.Movement.SupportMath)
local Motor = require(script.Parent.Parent.Movement.SpiderMotor)

local Drive = {}
Drive.__index = Drive

local SEAT = Route.SEAT
local IDLE_EVERY = 10 -- a standing rival re-checks its support every tenth tick

local function gcd(a: number, b: number): number
	while b ~= 0 do a, b = b, a % b end
	return a
end

-- `motor`: a SpiderMotor made for the rival (its own world query and probe). `blocked(a, b)`: something opaque between the points.
function Drive.new(motor: any, blocked: (Vector3, Vector3) -> any): any
	local waypoints = Route.waypoints()
	local stride = 7
	while gcd(stride, math.max(#waypoints, 1)) ~= 1 do stride += 1 end
	return setmetatable({
		motor = motor, blocked = blocked, waypoints = waypoints, stride = stride,
		ticks = 0, think = 0.0, face = nil :: number?, route = nil :: { any }?, hop = 1,
		goal = nil :: any, goalKey = "", prevState = "dormant",
		lastUp = Vector3.yAxis, sees = false, reach = false, remember = false, seen = nil :: Vector3?, seenUp = Vector3.yAxis, lost = 0.0,
		legT = 0.0, stuckT = 0.0, stuckAt = nil :: Vector3?, noFaceT = 0.0, safe = nil :: any,
		speed = 0.0, wish = Vector3.zero, stats = { thinks = 0, plans = 0, replans = 0, resets = 0, arrivals = 0 },
	}, Drive)
end

function Drive.destroy(self: any)
	self.motor:destroy()
end

local function surfacePointOf(center: Vector3, up: Vector3): Vector3
	return center - up * SEAT
end

local function goalFaceOf(self: any): number
	return if self.goal ~= nil then self.goal.face else -1
end

-- The patrol place for this leg: deterministic from the leg number, spread over every face by a stride that visits all.
function Drive._pickWaypoint(self: any, r: any): any
	local n = #self.waypoints
	if n == 0 then return nil end
	for attempt = 0, 6 do
		local leg = (r.leg or 0) + attempt
		local w = self.waypoints[((leg * self.stride) % n) + 1]
		if (w.pos + w.up * SEAT - self.motor.pos).Magnitude > 3.0 then
			if attempt > 0 then r.leg = leg end
			return w
		end
	end
	return nil
end

function Drive._setGoal(self: any, goal: any, key: string)
	self.goal, self.goalKey = goal, key
	self.route = nil
	self.hop = 1
	self.legT = 0.0
	self.stuckT = 0.0
	self.stuckAt = self.motor.pos
end

-- Plans the seams from here to the goal; false when there is no way (the caller drops that goal).
function Drive._plan(self: any): boolean
	local goal, motor = self.goal, self.motor
	if goal == nil or self.face == nil then return false end
	self.stats.plans += 1
	local hops = Route.plan(self.face, surfacePointOf(motor.pos, motor.up), goal.face, goal.pos)
	self.route, self.hop = hops, 1
	return hops ~= nil
end

-- The corners rounded: a `via` hop is done once the body is at it.
function Drive._rounded(self: any)
	local route = self.route :: { any }?
	if route == nil then return end
	while self.hop <= #route do
		local h = route[self.hop]
		if h.via and self.face == h.from and (h.aim - self.motor.pos).Magnitude < 0.4 then self.hop += 1 else break end
	end
end

-- The seams crossed: the face it stands on is the one a seam leads to (or a later one), or it has gone astray and the way is planned again.
-- Made at each think and at once when the support turns (a wall taken, an edge wrapped), so the next aim is always for the face it is on.
function Drive._hops(self: any)
	local route = self.route :: { any }?
	if route == nil or self.face == nil or self.goal == nil then return end
	self:_rounded()
	local here = route[self.hop]
	-- Still on the face the next hop leaves (a corner to round, or a seam to reach): nothing to change.
	if here ~= nil and self.face == here.from then return end
	for i = self.hop, #route do
		if not route[i].via and route[i].face == self.face then
			self.hop = i + 1
			self:_rounded()
			return
		end
	end
	local from = if self.hop <= #route then route[self.hop].from else goalFaceOf(self)
	if self.face ~= from then
		self.stats.replans += 1
		if self.log then self.log("replan", self.face, from, route, self.hop, self.goal) end
		self.route = nil
		if not self:_plan() then self.goal = nil end
	end
end

-- One decision: what it sees, where it is, where it is going. Cheap, and made ten times a second, not every tick.
function Drive._think(self: any, r: any, s: any)
	local motor = self.motor
	self.stats.thinks += 1
	local delta = s.position - r.position
	self.sees = delta.Magnitude < Rules.sightWu and not self.blocked(r.position, s.position)
	if self.sees then
		self.seen, self.seenUp, self.lost = s.position, s.up or Vector3.yAxis, 0.0
	else
		self.lost += Rules.thinkSeconds
	end
	self.remember = not self.sees and self.seen ~= nil and self.lost < Rules.rememberSeconds
	self.face = if motor.mode == "attached" then Route.faceAt(motor.pos, motor.up) else nil
	self.lastUp = motor.up
	local playerFace = if s.grounded ~= false and s.up ~= nil then Route.faceAt(s.position, s.up) else nil
	self.reach = Route.adjacent(self.face, playerFace)
	self.noFaceT = if self.face == nil and motor.mode == "attached" then self.noFaceT + Rules.thinkSeconds else 0.0

	local state = r.state
	if state ~= "patrol" and state ~= "stalk" then
		self.goal, self.route = nil, nil
		return
	end
	if self.face == nil then return end
	-- The goal: where it last saw the spider (stalk) or the patrol place of this leg.
	if state == "stalk" then
		local at = if self.sees then s.position else self.seen
		local up = if self.sees then (s.up or Vector3.yAxis) else self.seenUp
		if at == nil then return end
		local face = Route.faceAt(at, up)
		local key = "stalk"
		if face == nil then return end
		if self.goal == nil or self.goalKey ~= key or self.goal.face ~= face or (self.goal.pos - surfacePointOf(at, up)).Magnitude > 1.0 then
			self:_setGoal({ pos = surfacePointOf(at, up), up = up, face = face }, key)
		end
	else
		if self.goal == nil or self.goalKey ~= "patrol" then
			local w = self:_pickWaypoint(r)
			if w == nil then return end
			self:_setGoal(w, "patrol")
		end
	end
	if self.route == nil then
		if not self:_plan() then
			-- No way there: drop it (the next leg, or the next think of the stalk).
			if self.goalKey == "patrol" then r.leg = (r.leg or 0) + 1 end
			self.goal = nil
			return
		end
	end
	self:_hops()
	-- Progress: a leg that has taken too long, or no movement for a while, is dropped or planned again.
	self.legT += Rules.thinkSeconds
	self.stuckT += Rules.thinkSeconds
	if self.stuckT >= Rules.stuckSeconds then
		if self.stuckAt ~= nil and (motor.pos - self.stuckAt).Magnitude < 0.3 and self.goal ~= nil then
			self.stats.resets += 1
			self.route = nil
			if self.goalKey == "patrol" then r.leg = (r.leg or 0) + 1; self.goal = nil end
		end
		self.stuckT, self.stuckAt = 0.0, motor.pos
	end
	if self.goalKey == "patrol" and self.legT >= Rules.legSeconds then
		r.leg = (r.leg or 0) + 1
		self.goal = nil
	end
end

-- The motor's input for this tick: where to head. Nil wish: stand.
function Drive._wish(self: any, r: any, s: any): (Vector3, Vector3?)
	local motor = self.motor
	local state = r.state
	if state == "windup" then return Vector3.zero, s.position end
	if (state ~= "patrol" and state ~= "stalk") or self.goal == nil or self.route == nil then return Vector3.zero, nil end
	local route = self.route :: { any }
	local target: Vector3
	self:_rounded()
	if self.hop <= #route then
		target = route[self.hop].aim
	else
		target = self.goal.pos + self.goal.up * SEAT
		if (target - motor.pos).Magnitude < 0.6 then
			-- Arrived. A patrol takes the next place; a stalk stands where the spider was.
			self.stats.arrivals += 1
			if self.goalKey == "patrol" then r.leg = (r.leg or 0) + 1; self.goal = nil; self.route = nil end
			return Vector3.zero, nil
		end
	end
	target = Route.aroundKeepOut(motor.pos, target)
	return SupportMath.tangentDir(target - motor.pos, motor.up), if state == "stalk" and self.sees then s.position else nil
end

-- A rival that has just arrived or been restored: the motor stands where the state says.
function Drive._place(self: any, r: any)
	local motor = self.motor
	motor:place(r.position, r.up or Vector3.yAxis, r.heading)
	self.route, self.goal, self.face = nil, nil, nil
	self.stuckAt = motor.pos
	self.safe = { pos = motor.pos, up = motor.up, heading = motor.heading }
end

-- After a lunge it is somewhere in the air or inside the spider: back onto the face it lunged over, or back to where it started.
function Drive._reseat(self: any, r: any)
	local motor = self.motor
	local up = r.up or Vector3.yAxis
	local hit = workspace:Raycast(r.position + up * 0.3, -up * 1.2, motor.params)
	if hit ~= nil and motor:attachable(hit) and not Layout.inRetreat(hit.Position + hit.Normal * SEAT) then
		motor:place(hit.Position + hit.Normal * SEAT, hit.Normal, r.heading)
	else
		local at = r.origin
		motor:place(at, up, r.heading)
	end
	self.route, self.goal = nil, nil
	r.position, r.up, r.heading = motor.pos, motor.up, motor.heading
	self.safe = { pos = motor.pos, up = motor.up, heading = motor.heading }
end

-- One fixed tick, after RivalSpider.step. `s` is the same player snapshot step was given plus `up` (the player's support normal).
function Drive.update(self: any, r: any, dt: number, s: any)
	local motor = self.motor
	local state = r.state
	self.ticks += 1
	if r.up == nil then r.up = Vector3.yAxis end
	local prev = self.prevState
	self.prevState = state
	if state == "dormant" or state == "consumed" then
		self.route, self.goal = nil, nil
		return
	end
	if prev == "dormant" or prev == "consumed" then
		self:_place(r)
	end
	if state == "captured" then
		-- Held and eaten where the spider is: the state moves it.
		motor:place(r.position, r.up, r.heading)
		return
	end
	if state == "lunge" then return end
	if prev == "lunge" then
		self:_reseat(r)
	elseif (motor.pos - r.position).Magnitude > 0.05 or (r.up :: Vector3):Dot(motor.up) < 0.99 then
		-- A restored checkpoint, or anything else that moved it: stand where the state says.
		self.stats.resets += 1
		self:_place(r)
	end
	self.think -= dt
	if self.think <= 0 then
		self.think += Rules.thinkSeconds
		if self.think < 0 then self.think = 0 end
		self:_think(r, s)
	end
	local wish, focus = self:_wish(r, s)
	self.wish = wish
	local stalking = state == "stalk"
	local speed = if wish.Magnitude > 0 then (if stalking then Rules.stalkSpeed else Rules.patrolSpeed) else 0.0
	if speed > 0 then motor:setSpeedFactor(speed / motor.loco.walk_speed_wu_s) end
	if wish.Magnitude > 0 or focus ~= nil or motor.mode ~= "attached" or self.ticks % IDLE_EVERY == 0 then
		local input = Motor.idleInput()
		input.wish = wish
		input.focusPoint = focus
		motor:tick(input)
	end
	if motor.up:Dot(self.lastUp) < 0.99 then
		self.lastUp = motor.up
		self.face = if motor.mode == "attached" then Route.faceAt(motor.pos, motor.up) else nil
		self:_hops()
	end
	-- The crack is never entered: whatever happened, back to the last place outside it.
	if Layout.inRetreat(motor.pos) then
		local safe = self.safe
		motor:place(safe.pos, safe.up, safe.heading)
		self.route, self.goal = nil, nil
	elseif not Route.inKeepOut(motor.pos) and motor.mode == "attached" then
		self.safe = { pos = motor.pos, up = motor.up, heading = motor.heading }
	end
	r.position, r.up, r.heading = motor.pos, motor.up, motor.heading
end

return Drive
