--!strict
-- The rival spider's legs (ROBLOX-69): its own SpiderMotor, the player's proven surface-walking motor with the same collider, drives it over
-- every face of the windowsill. This module is the brain between RivalSpider's state (patrol, stalk, windup, ...) and that motor: it picks the
-- places to patrol to, plans the seams to cross (RivalRoute), and hands the motor an ordinary TickInput each tick. Decisions (sight, faces,
-- routes) run every Rules.thinkSeconds, not every tick; the motor itself steps every tick while it walks and every tenth while it stands.
-- The rival's plain state (RivalSpider) stays the one thing a checkpoint holds: the drive keeps only what can be made again from it. It does
-- not know the engine: the motor and a sight query are handed in, so the CLI runs it on the box world and Studio on the real sill.
-- ROBLOX-117 (the preserve's hut garden): a drive told its `roam` (a set of region ids: World/Hut.ROAM) walks from region to region across their flat seams. It walks one
-- region's graph at a time (RivalRoute.graph of `region`); now and then a patrol leg is a crossing (a seeded draw for the leg, `Drive.crossLeg`) to a seam's point
-- on the way to a neighbour of the roam, and when it stands there the region becomes the neighbour's (`r.region`, kept in the record) and it walks on in a couple of
-- studs before it plans again; a stalk follows the spider across a seam the same way. A record's `region` that differs from the drive's (a rest put back, a new
-- rival) makes the drive the record's. Without `roam` nothing of this happens: the sill's rival and mate are as they were.
local Route = require(script.Parent.RivalRoute)
local Rules = require(script.Parent.Parent.Data.RivalRules)
local WorldMap = require(script.Parent.Parent.World.WorldMap)
local SupportMath = require(script.Parent.Parent.Movement.SupportMath)
local Motor = require(script.Parent.Parent.Movement.SpiderMotor)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)
local Station = require(script.Parent.Parent.World.StationTerritory)

local Drive = {}
Drive.__index = Drive

local SEAT = Route.SEAT
local IDLE_EVERY = 10 -- a standing rival re-checks its support every tenth tick

local function gcd(a: number, b: number): number
	while b ~= 0 do a, b = b, a % b end
	return a
end

-- `motor`: a SpiderMotor made for the rival (its own world query and probe). `blocked(a, b)`: something opaque between the points. ROBLOX-94: `region` (the sill's unless
-- given) is the region it walks in, whose retreats it never enters.
function Drive.new(motor: any, blocked: (Vector3, Vector3) -> any, region: string?, roam: { [string]: boolean }?): any
	local id = region or WorldMap.HOME
	local g = Route.graph(id)
	local waypoints = g:waypoints()
	local stride = 7
	while gcd(stride, math.max(#waypoints, 1)) ~= 1 do stride += 1 end
	return setmetatable({
		motor = motor, blocked = blocked, region = id, g = g, waypoints = waypoints, stride = stride, roam = roam, crossing = nil :: any,
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

-- (ROBLOX-117) The drive walks this region's graph from now on: its waypoints, its stride.
function Drive.useRegion(self: any, id: string)
	if id == self.region and self.g ~= nil then return end
	self.region = id
	self.g = Route.graph(id)
	self.waypoints = self.g:waypoints()
	local stride = 7
	while gcd(stride, math.max(#self.waypoints, 1)) ~= 1 do stride += 1 end
	self.stride = stride
	self.campList = nil
	self.route, self.goal, self.face = nil, nil, nil
end

-- (ROBLOX-117) A crossing to a neighbour of the roam: the seam point of this region's graph nearest `toward` (or any) on a flat seam to a region of the roam (only
-- `only`, if given), as a goal { pos, up, face, cross = { to, aim } }; nil when there is none.
function Drive.crossTo(self: any, toward: Vector3?, only: string?): any
	if self.roam == nil then return nil end
	local best, bestD = nil, math.huge
	for _, pair in self.g:allSeams() do
		local e = pair.edge
		if (e.flat or Station.contains(self.region)) and self.roam[e.region] and (only == nil or e.region == only) and #e.samples > 0 then
			local face = self.g.faces[pair.face]
			for _, sp in e.samples do
				local d = if toward ~= nil then (sp - toward).Magnitude else 0
				if face ~= nil and (face.normal.Y > 0.9 or Station.contains(self.region)) and not self.g:inKeepOut(sp + face.normal * SEAT) and d < bestD then
					local nextFace=Route.graph(e.region).faces[e.to]
					local across=if e.flat then e.ahead elseif e.convex then -face.normal else face.normal
					best, bestD = { pos = sp, up = face.normal, face = pair.face, cross = {
						to = e.region, aim = sp + across * 2.5 + nextFace.normal * SEAT,
						ahead=if e.flat then nil else e.ahead, up=face.normal,
					} }, d
				end
			end
			if toward == nil and best ~= nil then break end
		end
	end
	return best
end

-- (ROBLOX-117) Whether patrol leg `leg` is a crossing to a neighbour (a stream of its own from the world's seed and the leg's number), and to which: the first of
-- the neighbours of the roam in a drawn order that has a flat seam.
Drive.CROSS_CHANCE = 0.4
function Drive.crossLeg(self: any, seed: number, leg: number): any
	if self.roam == nil then return nil end
	local g = PreyRandom.mixed(seed, leg, 89)
	if g:next() >= Drive.CROSS_CHANCE then return nil end
	local reg = WorldMap.region(self.region)
	if reg == nil then return nil end
	local options: { string } = {}
	for _, n in reg.neighbors do if self.roam[n.id] and table.find(options, n.id) == nil then table.insert(options, n.id) end end
	if #options == 0 then return nil end
	local start = 1 + math.floor(g:next() * #options)
	for k = 0, #options - 1 do
		local w = self:crossTo(nil, options[((start - 1 + k) % #options) + 1])
		if w ~= nil then return w end
	end
	return nil
end

local function surfacePointOf(center: Vector3, up: Vector3): Vector3
	return center - up * SEAT
end

local function goalFaceOf(self: any): number
	return if self.goal ~= nil then self.goal.face else -1
end

-- ROBLOX-106: the places to watch from (Rules.camp.spots on the floor round the crack's mouth), as goals on the sill's faces, outside the keep-out. Made once; none in a
-- region without a retreat.
function Drive.campPlaces(self: any): { any }
	if self.campList ~= nil then return self.campList end
	local list: { any } = {}
	local reg = WorldMap.region(self.region)
	if reg ~= nil and #reg.retreats > 0 and self.region == WorldMap.HOME then
		for _, p in Rules.camp.spots do
			local up = Vector3.yAxis
			local face = self.g:faceAt(p + up * SEAT, up)
			if face ~= nil and not self.g:inKeepOut(p + up * SEAT) and WorldMap.inRetreat(p + up * SEAT, self.region) == nil then
				table.insert(list, { pos = p, up = up, face = face })
			end
		end
	end
	self.campList = list
	return list
end

-- ROBLOX-106: whether patrol leg `leg` is a watch by the crack, and which place and for how long: a stream of its own from the world's seed and the leg's number.
function Drive.campLeg(self: any, seed: number, leg: number): (any, number)
	local places = self:campPlaces()
	if #places == 0 then return nil, 0 end
	local g = PreyRandom.mixed(seed, leg, 83)
	if g:next() >= Rules.camp.chance then return nil, 0 end
	local w = places[math.min(#places, 1 + math.floor(g:next() * #places))]
	local secs = Rules.camp.seconds
	return w, secs[1] + (secs[2] - secs[1]) * g:next()
end

-- The patrol place for this leg: deterministic from the leg number, spread over every face by a stride that visits all. ROBLOX-106: in the standard rules (`s.nature`, a
-- drive told it `camps`) a leg may be a watch by the crack instead (Drive.campLeg).
function Drive._pickWaypoint(self: any, r: any, s: any?): any
	local n = #self.waypoints
	if n == 0 then return nil end
	if self.camps == true and s ~= nil and s.nature == true then
		local w = self:campLeg(s.seed or 0, r.leg or 0)
		if w ~= nil then
			self.campHere = true
			return w
		end
	end
	self.campHere = false
	-- (ROBLOX-117: in a roam, a leg may be a crossing to a neighbour)
	if s ~= nil and self.roam ~= nil then
		local w = self:crossLeg(s.seed or 0, r.leg or 0)
		if w ~= nil then return w end
	end
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
	local hops = self.g:plan(self.face, surfacePointOf(motor.pos, motor.up), goal.face, goal.pos)
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
	self.sees = not (s.safe or s.resting or s.scene or s.courting or s.wasp) and delta.Magnitude < Rules.sightWu and not self.blocked(r.position, s.position)
	if self.sees then
		self.seen, self.seenUp, self.lost = s.position, s.up or Vector3.yAxis, 0.0
	else
		self.lost += Rules.thinkSeconds
	end
	self.remember = not self.sees and self.seen ~= nil and self.lost < Rules.rememberSeconds
	self.face = if motor.mode == "attached" then self.g:faceAt(motor.pos, motor.up) else nil
	self.lastUp = motor.up
	local playerFace = if s.grounded ~= false and s.up ~= nil then self.g:faceAt(s.position, s.up) else nil
	self.reach = self.g:adjacent(self.face, playerFace)
	self.noFaceT = if self.face == nil and motor.mode == "attached" then self.noFaceT + Rules.thinkSeconds else 0.0

	local state = r.state
	if state ~= "patrol" and state ~= "stalk" then
		self.goal, self.route, self.crossing = nil, nil, nil
		return
	end
	-- (ROBLOX-117) walking in over a seam just crossed: no plan until it stands on the new region's ground, a couple of studs in
	if self.crossing ~= nil then
		self.crossing.t += Rules.thinkSeconds
		if (self.face ~= nil and (motor.pos - self.crossing.aim).Magnitude < 0.8) or self.crossing.t > 4 then self.crossing = nil else return end
	end
	if self.face == nil then return end
	-- The goal: where it last saw the spider (stalk) or the patrol place of this leg.
	if state == "stalk" then
		local at = if self.sees then s.position else self.seen
		local up = if self.sees then (s.up or Vector3.yAxis) else self.seenUp
		if at == nil then return end
		local face = self.g:faceAt(at, up)
		local key = "stalk"
		if face == nil and self.roam ~= nil then
			-- (ROBLOX-117) the spider is over a seam in a neighbour of the roam: the crossing toward it is the goal
			local there = WorldMap.at(at)
			if there ~= nil and self.roam[there.id] then
				local w = self:crossTo(at, there.id)
				if w ~= nil and (self.goal == nil or self.goal.cross == nil or self.goal.cross.to ~= there.id) then self:_setGoal(w, "stalk") end
			end
			if self.goal == nil or self.goal.cross == nil then return end
		elseif face == nil then return end
		if self.goal ~= nil and self.goal.cross ~= nil and face == nil then
			-- (keep the crossing)
		elseif self.goal == nil or self.goalKey ~= key or self.goal.face ~= face or (self.goal.pos - surfacePointOf(at, up)).Magnitude > 1.0 then
			self:_setGoal({ pos = surfacePointOf(at, up), up = up, face = face }, key)
		end
	else
		if self.goal == nil or self.goalKey ~= "patrol" then
			local w = self:_pickWaypoint(r, s)
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
	-- ROBLOX-106: standing its watch is not being stuck, and the leg's time does not run out under it.
	if r.camp ~= nil and self.campHere == true and self.goal ~= nil and (self.goal.pos + self.goal.up * SEAT - motor.pos).Magnitude < 0.6 then
		self.stuckT, self.stuckAt, self.legT = 0.0, motor.pos, 0.0
	end
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
	if self.goalKey == "patrol" and self.legT >= Rules.legSeconds and r.camp == nil then
		r.leg = (r.leg or 0) + 1
		self.goal = nil
	end
end

-- The motor's input for this tick: where to head. Nil wish: stand.
function Drive._wish(self: any, r: any, s: any): (Vector3, Vector3?)
	local motor = self.motor
	local state = r.state
	if state == "windup" then return Vector3.zero, s.position end
	-- (ROBLOX-117) walking in over the seam it has crossed
	if (state == "patrol" or state == "stalk") and self.crossing ~= nil then
		if self.crossing.ahead and motor.up:Dot(self.crossing.up)>.9 then return SupportMath.tangentDir(self.crossing.ahead,motor.up),nil end
		return SupportMath.tangentDir(self.crossing.aim - motor.pos, motor.up), nil
	end
	if (state ~= "patrol" and state ~= "stalk") or self.goal == nil or self.route == nil then return Vector3.zero, nil end
	local route = self.route :: { any }
	local target: Vector3
	self:_rounded()
	if self.hop <= #route then
		target = route[self.hop].aim
	else
		target = self.goal.pos + self.goal.up * SEAT
		if (target - motor.pos).Magnitude < 0.6 and self.goal.cross ~= nil then
			-- (ROBLOX-117) at the seam: the neighbour's region is its own from here, and it walks in a little before it plans again
			local cross = self.goal.cross
			if self.goalKey == "patrol" then r.leg = (r.leg or 0) + 1 end
			self.stats.arrivals += 1
			self:useRegion(cross.to)
			r.region = cross.to
			self.crossing = { aim = cross.aim, t = 0, ahead=cross.ahead, up=cross.up }
			self.stats.crossings = (self.stats.crossings or 0) + 1
			return SupportMath.tangentDir(cross.aim - motor.pos, motor.up), nil
		end
		if (target - motor.pos).Magnitude < 0.6 then
			-- ROBLOX-106: at a watch by the crack it stands its time (Drive.update counts it down) before it takes the next place.
			if self.goalKey == "patrol" and self.campHere == true then
				if r.camp == nil then
					self.stats.arrivals += 1
					local _, secs = self:campLeg(s.seed or 0, r.leg or 0)
					r.camp = secs
				end
				if r.camp > 0 then return Vector3.zero, nil end
				r.camp = nil
				r.leg = (r.leg or 0) + 1; self.goal = nil; self.route = nil; self.campHere = false
				return Vector3.zero, nil
			end
			-- Arrived. A patrol takes the next place; a stalk stands where the spider was.
			self.stats.arrivals += 1
			if self.goalKey == "patrol" then r.leg = (r.leg or 0) + 1; self.goal = nil; self.route = nil end
			return Vector3.zero, nil
		end
	end
	target = self.g:aroundKeepOut(motor.pos, target)
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
	if hit ~= nil and motor:attachable(hit) and WorldMap.inRetreat(hit.Position + hit.Normal * SEAT, self.region) == nil then
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
	-- (ROBLOX-117) the record's region is the drive's (a rest put back, a new rival arrived somewhere else)
	if r.region ~= nil and r.region ~= self.region and WorldMap.region(r.region) ~= nil then
		self:useRegion(r.region)
		self.crossing = nil
	end
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
	if state == "lunge" or state == "taken" then return end
	if prev == "lunge" then
		self:_reseat(r)
	elseif (motor.pos - r.position).Magnitude > 0.05 or (r.up :: Vector3):Dot(motor.up) < 0.99 then
		-- A restored checkpoint, or anything else that moved it: stand where the state says.
		self.stats.resets += 1
		self:_place(r)
	end
	-- ROBLOX-106: a watch by the crack counts down while it patrols (stands there) or waits (the spider in the crack, a wasp's visit); a stalk does not use it up.
	if r.camp ~= nil and (state == "patrol" or state == "recover") then r.camp = math.max(0, r.camp - dt) end
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
		self.face = if motor.mode == "attached" then self.g:faceAt(motor.pos, motor.up) else nil
		self:_hops()
	end
	-- The crack is never entered: whatever happened, back to the last place outside it.
	if WorldMap.inRetreat(motor.pos, self.region) ~= nil then
		local safe = self.safe
		motor:place(safe.pos, safe.up, safe.heading)
		self.route, self.goal = nil, nil
	elseif not self.g:inKeepOut(motor.pos) and motor.mode == "attached" then
		self.safe = { pos = motor.pos, up = motor.up, heading = motor.heading }
	end
	r.position, r.up, r.heading = motor.pos, motor.up, motor.heading
end

return Drive
