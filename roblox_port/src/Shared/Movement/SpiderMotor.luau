--!strict
-- The spider's body on the windowsill: a kinematic port of the frozen Godot motor's core (scripts/movement/spider_motor.gd,
-- jump_planner.gd and the jump/line parts of player_controller.gd and tether_controller.gd, c87ce00). It walks on any
-- attachable surface (floor, walls, undersides, over edges), plans hops and aimed leaps with the shared JumpMath at a fixed
-- 60 Hz tick, flies them, pays out a safety line from silk-holding ground (SilkController: catch, hang, reel, lower,
-- edge-first lowering, deliberate let-go) and reports line events for the HUD.
--
-- No input devices, camera or drawing here: the client passes a TickInput each fixed tick and an aim ray, so Studio specs
-- (tests/studio/RecoverySpec.luau) run the same motor deterministically, tick by tick, against real geometry. Engine
-- queries only: Workspace raycasts, sphere casts and one overlap query (the room probe).
local JumpMath = require(script.Parent.JumpMath)
local SupportMath = require(script.Parent.SupportMath)
local SilkController = require(script.Parent.SilkController)

local Motor = {}
Motor.__index = Motor

local DT = 1 / 60
Motor.DT = DT
Motor.HEIGHT = 0.31 -- body centre above the support plane: radius 0.3 + skin 0.01 (Godot seat distance)
local HEIGHT = Motor.HEIGHT
local SWEEP_RADIUS = 0.303 -- body radius + JumpPlanner.SWEEP_MARGIN
local TURN_RATE = math.rad(540)
local FOCUS_RATE = math.rad(180) -- Godot FOCUS_TURN_FALLBACK_DEG_S
local PREPARE_TURN_RATE = math.rad(360) -- SpiderMotor.PREPARE_TURN_RATE_DEG_S: cosmetic turn toward the aim point
local AIM_RANGE = 60
Motor.AIM_RANGE = AIM_RANGE
local HOP_DISTANCE = 1.5
local HOP_PROBE_UP, HOP_PROBE_DOWN = 0.5, 1.2
local MAX_DRIFT = 0.15
local CONTACT_EXTRA_STEPS = 8
local EYE_TURN_START_DEG, EYE_TURN_STOP_DEG = 30, 4 -- CameraMath.PRINCIPAL_SCAN_DEG, EYE_SETTLE_DEG
local FREE_UP_RATE = math.rad(240) -- the drawn up turns to world up while falling or on the line (Godot VISUAL_TURN)

export type TickInput = {
	wish: Vector3, -- walking direction on the support plane (unit or zero), from the view
	creep: boolean,
	reel: number, -- on the line: +1 reels in, -1 lowers
	dropHeld: boolean, -- F / X / Silk held: lowers on the line
	releaseHeld: boolean, -- Q / B / Let go held: a deliberate let-go after the grace
	focusPoint: Vector3?, -- Focus held: the body turns toward this point
	gaze: Vector3?, -- spider-eye view: the body turns to face a gaze beyond 30 degrees
}

export type Config = {
	world: Instance,
	surfaces: any,
	profile: any,
	spawn: Vector3, -- the support point under the body
	heading: Vector3,
	boundsMin: Vector3,
	boundsMax: Vector3,
	probeParent: Instance?,
}

function Motor.idleInput(): TickInput
	return { wish = Vector3.zero, creep = false, reel = 0, dropHeld = false, releaseHeld = false }
end

function Motor.new(config: Config): any
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { config.world }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { config.world }
	local probe = Instance.new("Part")
	probe.Name = "RoomProbe"
	probe.Shape = Enum.PartType.Ball
	probe.Size = Vector3.one * (SWEEP_RADIUS * 2)
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Parent = config.probeParent or workspace
	local loco = config.profile.locomotion
	local self = setmetatable({
		config = config,
		surfaces = config.surfaces,
		loco = loco,
		gravity = Vector3.new(0, -loco.gravity_wu_s2, 0),
		params = params,
		overlap = overlap,
		probe = probe,
		silk = SilkController.new(config.world, config.surfaces, config.profile.silk, loco.gravity_wu_s2) :: any,
		mode = "attached",
		pos = config.spawn + Vector3.new(0, HEIGHT, 0),
		up = Vector3.yAxis,
		heading = config.heading,
		vel = Vector3.zero,
		moving = false,
		preparing = false,
		aimTarget = nil :: Vector3?,
		aimOrigin = Vector3.zero,
		aimDirection = -Vector3.zAxis,
		planKey = "",
		plan = nil :: any,
		flightTicks = 0,
		flightLimit = 0,
		eyeTurning = false,
		ticks = 0,
		lineSerial = 0, -- counts lines started, so the drawing knows a new one began
		afterMiss = false,
		dropped = false,
		caught = false,
		safe = { pos = config.spawn + Vector3.new(0, HEIGHT, 0), up = Vector3.yAxis, heading = config.heading },
		supportPart = nil :: Instance?, -- the part the spider last took hold of
		intent = Vector3.zero, -- the walking direction last used, turned with the support at an edge (StickCarry reads it)
		transitionSerial = 0, -- counts sharp support turns while walking (concave and convex edges)
		events = {} :: { { kind: string, detail: string } },
	}, Motor)
	return self
end

function Motor.destroy(self: any)
	self.probe:Destroy()
end

function Motor._event(self: any, kind: string, detail: string?)
	table.insert(self.events, { kind = kind, detail = detail or "" })
end

-- The line and jump events since the last call (for the HUD's toasts), oldest first.
function Motor.drainEvents(self: any): { { kind: string, detail: string } }
	local out = self.events
	self.events = {}
	return out
end

function Motor.profileOf(self: any, inst: Instance?): any
	if not inst then return nil end
	local id = inst:GetAttribute("ProfileId")
	return if typeof(id) == "string" then self.surfaces[id] else nil
end

function Motor.attachable(self: any, hit: RaycastResult?): boolean
	if not hit then return false end
	local p = self:profileOf(hit.Instance)
	return p ~= nil and p.attachable == true
end

-- SurfaceProfile.supports: an attachable surface, or any floor flat enough to stand on.
local STAND_COS = math.cos(math.rad(JumpMath.STAND_MAX_DEG)) - 1e-6
function Motor.supports(_self: any, p: any, normal: Vector3): boolean
	if p ~= nil and p.attachable then return true end
	return normal.Magnitude > 1e-5 and normal.Unit:Dot(Vector3.yAxis) >= STAND_COS
end

local function rotationBetween(a: Vector3, b: Vector3): CFrame
	local angle = SupportMath.angleTo(a, b)
	if angle < 1e-6 then return CFrame.identity end
	local axis = a:Cross(b)
	if axis:Dot(axis) < 1e-12 then axis = SupportMath.anyPerpendicular(a) end
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

function Motor._setSupport(self: any, hit: RaycastResult)
	local turn = rotationBetween(self.up, hit.Normal)
	self.heading = SupportMath.tangentDir(turn * self.heading, hit.Normal)
	if self.heading == Vector3.zero then self.heading = SupportMath.anyPerpendicular(hit.Normal) end
	self.up = hit.Normal
	self.pos = hit.Position + hit.Normal * HEIGHT
	self.supportPart = hit.Instance
end

-- A sharp turn of the support while walking (a wall ahead, an edge to wrap): the walking direction turns with it, as the
-- heading does, and the transition is counted so the controls can carry the stick's direction over the edge.
function Motor._transition(self: any, hit: RaycastResult)
	local turn = rotationBetween(self.up, hit.Normal)
	self.intent = SupportMath.tangentDir(turn * self.intent, hit.Normal)
	self:_setSupport(hit)
	self.transitionSerial += 1
end

function Motor._ray(self: any, from: Vector3, motion: Vector3): RaycastResult?
	return workspace:Raycast(from, motion, self.params)
end

-- Puts the spider somewhere (a reset, a test fixture). Every line, aim and walk ends.
function Motor.place(self: any, position: Vector3, up: Vector3?, heading: Vector3?)
	self.mode = "attached"
	self.pos = position
	self.up = up or Vector3.yAxis
	self.heading = SupportMath.tangentDir(heading or self.config.heading, self.up)
	if self.heading == Vector3.zero then self.heading = SupportMath.anyPerpendicular(self.up) end
	self.vel = Vector3.zero
	self.moving = false
	self.intent = Vector3.zero
	self.preparing = false
	self.aimTarget = nil
	self.plan = nil
	self.planKey = ""
	self.silk:clear()
	self.afterMiss, self.dropped, self.caught = false, false, false
	self.safe = { pos = self.pos, up = self.up, heading = self.heading }
end

function Motor.respawn(self: any)
	self:place(self.config.spawn + Vector3.new(0, HEIGHT, 0), Vector3.yAxis, self.config.heading)
end

-- ---------------------------------------------------------------- the planner (port of jump_planner.gd)
function Motor._sweep(self: any, a: Vector3, b: Vector3): Vector3?
	local d = b - a
	if d.Magnitude < 1e-6 then return nil end
	local hit = workspace:Spherecast(a, SWEEP_RADIUS, d, self.params)
	return if hit then a + d.Unit * hit.Distance else nil
end

function Motor._fits(self: any, center: Vector3): boolean
	self.probe.CFrame = CFrame.new(center)
	return #workspace:GetPartsInPart(self.probe, self.overlap) == 0
end

function Motor._tryCandidate(self: any, origin: Vector3, seat: Vector3, c: any): (boolean, string, { Vector3 }, Vector3?)
	local G = self.gravity
	local pts = JumpMath.path(origin, c.velocity, G, DT, c.steps)
	for k = 2, #pts do
		local at = self:_sweep(pts[k - 1], pts[k])
		if at then
			local cut = table.move(pts, 1, k - 1, 1, {})
			table.insert(cut, at)
			return false, "path_blocked", cut, at
		end
	end
	local v = JumpMath.velocityAfter(c.velocity, G, DT, c.steps)
	local p = pts[#pts]
	for _ = 1, CONTACT_EXTRA_STEPS do
		v += G * DT
		local nextP = p + v * DT
		local at = self:_sweep(p, nextP)
		if at then
			if (at - seat).Magnitude <= MAX_DRIFT then return true, "ok", pts, nil end
			return false, "graze", pts, at
		end
		p = nextP
	end
	return false, "graze", pts, seat
end

-- A plan for a target surface point (JumpPlanner.plan): kind reachable / obstructed / unreachable / ineligible / none, with
-- the reason, the drawn path and, when reachable, the launch velocity and ticks. origin is where the body was.
function Motor.planJump(self: any, point: Vector3?, normal: Vector3?, inst: Instance?): any
	if not point or not normal then return { kind = "none", reason = "no_target" } end
	local loco = self.loco
	local plan: any = { point = point, normal = normal, seat = point + normal * HEIGHT, kind = "unreachable", reason = "", origin = self.pos }
	if not self:supports(self:profileOf(inst), normal) then
		plan.kind, plan.reason = "ineligible", "ineligible_surface"
		return plan
	end
	local solved = JumpMath.solve(self.pos, plan.seat, self.up, normal, self.gravity, DT, loco.flight_time_min_s, loco.flight_time_max_s, loco.max_launch_speed_wu_s)
	if #solved.valid == 0 then
		plan.reason = solved.reason
		return plan
	end
	if not self:_fits(plan.seat) then
		plan.kind, plan.reason = "obstructed", "no_room"
		plan.path = JumpMath.path(self.pos, solved.valid[1].velocity, self.gravity, DT, solved.valid[1].steps)
		plan.blockedAt = plan.seat
		return plan
	end
	local firstPath, firstAt, anyBlocked = nil, nil, false
	for _, c in solved.valid do
		local ok, why, path, at = self:_tryCandidate(self.pos, plan.seat, c)
		if ok then
			plan.kind, plan.reason, plan.path, plan.velocity, plan.steps = "reachable", "ok", path, c.velocity, c.steps
			return plan
		end
		if not firstPath then firstPath, firstAt = path, at end
		if why == "path_blocked" then anyBlocked = true end
	end
	plan.path, plan.blockedAt = firstPath, firstAt
	plan.kind, plan.reason = if anyBlocked then "obstructed" else "unreachable", if anyBlocked then "path_blocked" else "graze"
	return plan
end

-- The aim ray the client last gave (the camera's centre ray).
function Motor.setAimRay(self: any, origin: Vector3, direction: Vector3)
	self.aimOrigin, self.aimDirection = origin, direction
end

-- The aim: whatever the centre ray meets (no target magnet). Re-planned only when the aim or the spider moves.
function Motor.aimPlan(self: any): any
	local hit = self:_ray(self.aimOrigin, self.aimDirection * AIM_RANGE)
	local key = if hit
		then string.format("%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", hit.Position.X, hit.Position.Y, hit.Position.Z, hit.Normal.X, hit.Normal.Y, hit.Normal.Z, self.pos.X, self.pos.Y, self.pos.Z, self.up.X, self.up.Y, self.up.Z)
		else "none"
	if key ~= self.planKey or not self.plan then
		self.planKey = key
		self.plan = if hit then self:planJump(hit.Position, hit.Normal, hit.Instance) else self:planJump(nil, nil, nil)
	end
	if self.preparing then
		self.aimTarget = if hit then hit.Position else nil
	end
	return self.plan
end

-- JumpMotor.plan_hop: the ground HOP_DISTANCE ahead, planned and checked exactly like an aimed jump.
function Motor.hopPlan(self: any): any
	local n = self.up
	local h = SupportMath.tangentDir(self.heading, n)
	if h == Vector3.zero then h = SupportMath.anyPerpendicular(n) end
	local ahead = self:_ray(self.pos, h * (HOP_DISTANCE + HEIGHT))
	if ahead then
		return { kind = "obstructed", reason = "hop_blocked", point = ahead.Position, normal = ahead.Normal, origin = self.pos }
	end
	local finish = self.pos + h * HOP_DISTANCE
	local ground = self:_ray(finish + n * HOP_PROBE_UP, -n * (HOP_PROBE_UP + HOP_PROBE_DOWN))
	if not ground then
		return { kind = "unreachable", reason = "no_ground", point = finish - n * HEIGHT, normal = n, origin = self.pos }
	end
	return self:planJump(ground.Position, ground.Normal, ground.Instance)
end

-- What a leap from here does with the line (SpiderMotor.get_anchor_preview): "ok", "no_silk", "too_long" or "no_support".
function Motor.anchorPreview(self: any, plan: any): string
	if self.mode ~= "attached" then return "no_support" end
	local hit = self:_ray(self.pos, -self.up * (HEIGHT + 0.1))
	local p = if hit then self:profileOf(hit.Instance) else nil
	if not p then return "no_support" end
	if not p.silk_anchor_allowed then return "no_silk" end
	if plan and plan.seat and (plan.seat - self.pos).Magnitude > self.silk.maximum then return "too_long" end
	return "ok"
end

-- ---------------------------------------------------------------- the jump controller's view of the motor (JumpInput)
-- Standing on a surface and not walking itself to an edge's drop: a press or an aim may start.
function Motor.canPrepare(self: any): boolean
	return self.mode == "attached"
end

-- ATTACHED to PREPARING: the spider holds still; a walk to the edge stops (the player took over).
function Motor.beginPrepare(self: any): boolean
	if not self:canPrepare() then return false end
	if self.silk.walk then self:cancelWalk() end
	self.preparing = true
	self.vel = Vector3.zero
	return true
end

function Motor.cancelPrepare(self: any)
	self.preparing = false
	self.aimTarget = nil
end

function Motor.isPreparing(self: any): boolean
	return self.preparing and self.mode == "attached"
end

function Motor.clearAimTarget(self: any)
	self.aimTarget = nil
end

-- Commits a reachable plan made from where the body is now. Anything else changes nothing.
function Motor.commit(self: any, plan: any): boolean
	if plan == nil or plan.kind ~= "reachable" or self.mode ~= "attached" then return false end
	if plan.origin and (plan.origin - self.pos).Magnitude > 1e-3 then return false end
	self:_launch(plan.velocity, plan.steps)
	return true
end

-- A committed leap anchors a safety line at takeoff where the ground holds silk (SilkController pays it out).
function Motor._launch(self: any, velocity: Vector3, steps: number)
	local floorHit = self:_ray(self.pos, -self.up * (HEIGHT + 0.1))
	self.afterMiss, self.dropped, self.caught = false, false, false
	if self.silk:anchorAt(floorHit, self.pos) then
		self.lineSerial += 1
		self:_event("anchored")
	end
	self.preparing = false
	self.aimTarget = nil
	self.flightTicks, self.flightLimit = 0, steps + 4
	self.vel = velocity
	self.mode = "air"
	self:_event("launched")
end

-- ---------------------------------------------------------------- letting down on a line (F / X / Silk)
function Motor._beginDrop(self: any, push: Vector3): boolean
	if not self.silk:startDrop(self.pos, self.up, push) then return false end
	self.lineSerial += 1
	self.afterMiss, self.dropped, self.caught = false, true, false
	self.vel = push * 0.6
	self.mode = "air"
	self.preparing = false
	self.aimTarget = nil
	self:_event("dropped")
	return true
end

-- Godot SpiderMotor.begin_drop: on a wall or underside let down at once; on top of a leaf, walk to the nearest usable
-- edge first. Returns whether something started; a refusal says why in an event.
function Motor.requestDrop(self: any): boolean
	if self.mode ~= "attached" or self.preparing or self.silk.walk then return false end
	local plan, message = self.silk:planDrop(self.pos, self.up, self.heading)
	if not plan then
		self.silk.message = message
		local reason = if message == "This surface cannot hold silk" then "no_silk" elseif message == "No supporting surface" then "no_support" else "no_edge"
		self:_event("drop_refused", reason)
		return false
	end
	if plan.direction.Magnitude < 1e-6 then
		if self:_beginDrop(self.up) then self.pos += self.up * 0.01 end
	else
		self.silk.walk = { direction = plan.direction, ticks = math.ceil((plan.distance / self.loco.walk_speed_wu_s + 1.5) * 60) }
		self.silk.message = "Walking to the edge — move or cancel to stop"
		self:_event("drop_walk")
	end
	return true
end

-- Stops a walk to the edge (the player moved, aimed or pressed cancel). False when there was none.
function Motor.cancelWalk(self: any): boolean
	if not self.silk.walk then return false end
	self.silk.walk = nil
	self.silk.message = "Edge walk cancelled"
	return true
end

-- True while hanging or reeling on a locked line (Godot is_on_line).
function Motor.onLine(self: any): boolean
	return self.mode == "air" and self.silk.mode == "locked"
end

-- Where the spider will hang (the line's rest point below its pivot) and the lip the line leaves its support at: the
-- camera frames the recovery from these (camera_rig._wanted_yaw_assist, A-017).
function Motor.lineRestPoint(self: any): Vector3
	if self.silk.mode ~= "locked" then return self.pos end
	local pivot = self.silk:pivot()
	return pivot - Vector3.yAxis * math.max(self.silk.rest - self.silk:prefix(), 0)
end

function Motor.lineLip(self: any): Vector3
	return self.silk.bend or (self.silk.anchor + self.silk.normal * 0.04)
end

-- ---------------------------------------------------------------- the fixed tick
function Motor._turnToward(self: any, dir: Vector3, rate: number)
	local t = SupportMath.tangentDir(dir, self.up)
	if t ~= Vector3.zero then
		self.heading = SupportMath.tangentDir(SupportMath.rotateToward(self.heading, t, rate * DT), self.up)
	end
end

-- Focus (PlayerController.focus_direction) and the spider-eye turn: standing still, the body turns to look.
function Motor._lookTurns(self: any, input: TickInput, stickIdle: boolean)
	if input.focusPoint then
		local eye = self.pos + self.heading * 0.45
		local to = input.focusPoint - eye
		if to.Magnitude > 0.2 then self:_turnToward(to, FOCUS_RATE) end
		self.eyeTurning = false
		return
	end
	if not input.gaze or not stickIdle then
		self.eyeTurning = false
		return
	end
	local look = SupportMath.tangentDir(input.gaze, self.up)
	if look == Vector3.zero then return end
	local off = math.deg(SupportMath.angleTo(self.heading, look))
	if not self.eyeTurning and off > EYE_TURN_START_DEG then
		self.eyeTurning = true
	elseif self.eyeTurning and off < EYE_TURN_STOP_DEG then
		self.eyeTurning = false
	end
	if self.eyeTurning then self:_turnToward(look, FOCUS_RATE) end
end

function Motor._outOfBounds(self: any, p: Vector3): boolean
	local lo, hi = self.config.boundsMin, self.config.boundsMax
	return p.X < lo.X or p.Y < lo.Y or p.Z < lo.Z or p.X > hi.X or p.Y > hi.Y or p.Z > hi.Z
end

-- Leaving the play area puts the spider back at its last supported spot (Godot _reset_out_of_bounds).
function Motor._backToSafety(self: any)
	local safe = self.safe
	self:place(safe.pos, safe.up, safe.heading)
	self:_event("out_of_bounds")
end

function Motor._tickAttached(self: any, input: TickInput)
	local silk = self.silk
	local preparing = self.preparing
	local manual = if preparing then Vector3.zero else input.wish
	if silk.walk and manual.Magnitude > 0 then self:cancelWalk() end
	local dir = if preparing then Vector3.zero elseif silk.walk then silk.walk.direction else manual
	if silk.walk then
		silk.walk.ticks -= 1
		if silk.walk.ticks <= 0 then
			silk.walk = nil
			silk.message = "Edge walk stopped"
			self:_event("drop_refused", "stuck")
			return
		end
	end
	self.moving = dir ~= Vector3.zero
	self.intent = dir
	if preparing then
		local target = self.aimTarget
		if target then self:_turnToward(target - self.pos, PREPARE_TURN_RATE) end
	elseif not silk.walk then
		self:_lookTurns(input, not self.moving)
	end
	if not self.moving then
		-- Re-seat on the support so a vanished or moved surface is noticed.
		local below = self:_ray(self.pos + self.up * 0.1, -self.up * (HEIGHT + 0.35))
		if not self:attachable(below) and not (below and self:supports(self:profileOf(below.Instance), below.Normal)) then
			self.mode = "air"
			self.vel = Vector3.zero
			self.preparing = false
			self.flightTicks, self.flightLimit = 0, 0
		else
			self.safe = { pos = self.pos, up = self.up, heading = self.heading }
		end
		return
	end
	local stalk = input.creep and not silk.walk
	local speed = if stalk then self.loco.stalk_speed_wu_s else self.loco.walk_speed_wu_s
	self.heading = SupportMath.tangentDir(SupportMath.rotateToward(self.heading, dir, TURN_RATE * DT), self.up)
	local step = dir * speed * DT
	-- Concave corner: a wall (or a leaf's edge, a stem) ahead becomes the new support.
	local ahead = self:_ray(self.pos, dir * (HEIGHT + step.Magnitude + 0.02))
	if ahead and self:attachable(ahead) and SupportMath.angleTo(ahead.Normal, self.up) > math.rad(20) then
		self:_transition(ahead)
		return
	end
	local nextPos = self.pos + step
	local below = self:_ray(nextPos + self.up * 0.25, -self.up * (HEIGHT + 0.5))
	if below and self:attachable(below) and SupportMath.angleTo(below.Normal, self.up) < math.rad(60) then
		local n = SupportMath.filterNormal(self.up, below.Normal, 2.0)
		self.up = n
		self.pos = below.Position + n * HEIGHT
		self.heading = SupportMath.tangentDir(self.heading, n)
		self.safe = { pos = self.pos, up = self.up, heading = self.heading }
		return
	end
	if silk.walk then
		-- The walk reached the edge: let down from here (edge-first lowering).
		if self:_beginDrop(dir) then self.pos = nextPos + dir * (HEIGHT + 0.02) end
		return
	end
	-- Convex edge: wrap over it onto the face beyond (sill edge, leaf rim, the top of a wall).
	local around = self:_ray(nextPos - self.up * (HEIGHT + 0.15), -dir * 1.0)
	if around and self:attachable(around) then
		self:_transition(around)
		return
	end
	self.mode = "air"
	self.vel = dir * speed
	self.flightTicks, self.flightLimit = 0, 0
end

function Motor._tickLine(self: any, input: TickInput)
	local silk = self.silk
	-- On the line (spec 17's context override): forward reels in, back lowers, F held lowers, a held Q lets go.
	local intent = if input.dropHeld then math.min(input.reel, 0) - 1 else input.reel
	local p, v, hit = silk:step(self.pos, self.vel, math.clamp(intent, -1, 1), input.releaseHeld == true)
	self.pos, self.vel = p, v
	if hit then
		self:_setSupport(hit)
		self.vel = Vector3.zero
		self.mode = "attached"
		silk:clear()
		self:_event("completed")
		self.safe = { pos = self.pos, up = self.up, heading = self.heading }
		return
	end
	if silk.mode == "none" then
		self:_event(if silk.message == "Silk anchor lost" then "lost" else "released")
		self.flightTicks, self.flightLimit = 0, 0
		return
	end
	if silk.taut and not self.caught then
		self.caught = true
		self:_event("caught")
	end
	if silk.snagged and not self.snagSeen then self:_event("snagged") end
	self.snagSeen = silk.snagged
	self.up = SupportMath.rotateToward(self.up, Vector3.yAxis, FREE_UP_RATE * DT)
	if self:_outOfBounds(self.pos) then self:_backToSafety() end
end

function Motor._lock(self: any, at: Vector3)
	self.silk:lock(at, 0.25)
	self.afterMiss = true
	self.caught = false
	self:_event("locked")
end

function Motor._tickAir(self: any, input: TickInput)
	local silk = self.silk
	if silk.mode == "locked" then
		self:_tickLine(input)
		return
	end
	self.flightTicks += 1
	local from = self.pos
	self.vel += self.gravity * DT
	local to = from + self.vel * DT
	local travel = to - from
	local dir = if travel.Magnitude > 1e-6 then travel.Unit else -self.up
	local hit = self:_ray(from, dir * (travel.Magnitude + HEIGHT))
	if hit then
		local approach = -self.vel:Dot(hit.Normal)
		if self:supports(self:profileOf(hit.Instance), hit.Normal) and approach >= JumpMath.minApproach(hit.Normal) then
			local heading = SupportMath.tangentDir(self.vel, hit.Normal)
			self:_setSupport(hit)
			if heading ~= Vector3.zero then self.heading = heading end
			self.vel = Vector3.zero
			self.mode = "attached"
			if silk.mode ~= "none" then self:_event("landed") end
			silk:clear()
			self.safe = { pos = self.pos, up = self.up, heading = self.heading }
			return
		end
		-- Not landable here: the line locks (a miss), and the body slides along it.
		if silk.mode == "payout" then self:_lock(self.pos) end
		self.vel -= hit.Normal * math.min(0, self.vel:Dot(hit.Normal))
		to = hit.Position + hit.Normal * HEIGHT
	end
	self.pos = to
	silk:payout(to)
	if silk.mode == "payout" and self.flightTicks >= self.flightLimit then self:_lock(to) end
	-- The drawn body turns upright while falling.
	self.up = SupportMath.rotateToward(self.up, Vector3.yAxis, FREE_UP_RATE * DT)
	if self:_outOfBounds(to) then self:_backToSafety() end
end

-- One fixed 1/60 s tick of the body.
function Motor.tick(self: any, input: TickInput)
	self.ticks += 1
	if self.mode == "attached" then
		self:_tickAttached(input)
	else
		self.preparing = false
		self:_tickAir(input)
	end
end

return Motor
