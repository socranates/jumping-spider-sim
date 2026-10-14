--!strict
-- The playable spider: a client-side, kinematic port of the Godot motor's core (scripts/movement/spider_motor.gd,
-- jump_controller.gd, jump_planner.gd, player_controller.gd at the frozen c87ce00). It walks on any attachable surface
-- (floor, walls, undersides, over edges), plans, aims and flies jumps solved by the shared JumpMath at a fixed 60 Hz tick,
-- trails a dragline, and drives the procedural SpiderRig. The camera is SpiderCamera (a port of camera_rig.gd).
--
-- Controls (as the Godot game, see SpiderInput): WASD walk relative to the view, mouse looks, Shift creeps.
-- Tap Space: a short hop. Hold Space (0.15 s): the spider holds still and the reticle aims at any surface; the landing patch
-- says Reachable / Blocked / Out of reach / Can't land there; release to leap, Q cancels. V spider-eye view, R recenter,
-- right mouse Focus (turn to look where the camera points), T slow motion, H controls card, Backspace back to the start.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SpiderInput = require(script.Parent.SpiderInput)
local SpiderCamera = require(script.Parent.SpiderCamera)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local JumpMath = require(Shared:WaitForChild("Movement"):WaitForChild("JumpMath"))
local SupportMath = require(Shared:WaitForChild("Movement"):WaitForChild("SupportMath"))
local Species = require(Shared:WaitForChild("Data"):WaitForChild("Species"))
local Surfaces = require(Shared:WaitForChild("Data"):WaitForChild("Surfaces"))
local Layout = require(Shared:WaitForChild("Habitat"):WaitForChild("WindowsillLayout"))
local SpiderRig = require(Shared:WaitForChild("Rig"):WaitForChild("SpiderRig"))

local profile = Species.phidippus_audax_prototype
local LOCO = profile.locomotion
local DT = 1 / 60
local G = Vector3.new(0, -LOCO.gravity_wu_s2, 0)
local HEIGHT = 0.31 -- body centre above the support plane: radius 0.3 + skin 0.01 (Godot seat distance)
local SWEEP_RADIUS = 0.303 -- body radius + JumpPlanner.SWEEP_MARGIN
local TURN_RATE = math.rad(540)
local FOCUS_RATE = math.rad(180) -- Godot FOCUS_TURN_FALLBACK_DEG_S
local HOLD_TICKS = 9 -- JumpController.HOLD_SECONDS 0.15 at 60 Hz: a shorter press is a hop
local AIM_RANGE = 60
local HOP_DISTANCE = 1.5
local HOP_PROBE_UP, HOP_PROBE_DOWN = 0.5, 1.2
local MAX_DRIFT = 0.15
local CONTACT_EXTRA_STEPS = 8
local FLASH_TICKS = 60
local SLOW_SPEED = 0.5
local MAX_DRAGLINES = 12
local STAND_COS = math.cos(math.rad(JumpMath.STAND_MAX_DEG)) - 1e-6

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local sill = Workspace:WaitForChild("Windowsill")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { sill }

local UIS = game:GetService("UserInputService")
-- Touch-only devices get the lighter fuzz until a real tablet frame-time check (ROBLOX_PORT.md).
local rig = SpiderRig.new(Workspace, sill, nil, if UIS.TouchEnabled and not UIS.KeyboardEnabled then "low" else "full")
local cam: any = nil

type Mode = "attached" | "air"
type Phase = "idle" | "pressed" | "aiming"
local state = {
	mode = "attached" :: Mode,
	pos = Layout.SPAWN + Vector3.new(0, HEIGHT, 0),
	up = Vector3.yAxis,
	heading = Layout.SPAWN_HEADING,
	vel = Vector3.zero,
	drawnUp = Vector3.yAxis,
	moving = false,
	phase = "idle" :: Phase,
	heldTicks = 0,
	plan = nil :: any,
	planKey = "",
	flash = nil :: any,
	flashLeft = 0,
	lineAnchor = nil :: Vector3?,
	eyeTurning = false,
	slow = false,
}
local events: { string } = {}

local function profileOf(inst: Instance?): any
	if not inst then return nil end
	local id = inst:GetAttribute("ProfileId")
	return if typeof(id) == "string" then Surfaces[id] else nil
end

local function attachable(hit: RaycastResult?): boolean
	if not hit then return false end
	local p = profileOf(hit.Instance)
	return p ~= nil and p.attachable == true
end

-- SurfaceProfile.supports: an attachable surface, or any floor flat enough to stand on.
local function supports(p: any, normal: Vector3): boolean
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

local function setSupport(hit: RaycastResult)
	local turn = rotationBetween(state.up, hit.Normal)
	state.heading = SupportMath.tangentDir(turn * state.heading, hit.Normal)
	if state.heading == Vector3.zero then state.heading = SupportMath.anyPerpendicular(hit.Normal) end
	state.up = hit.Normal
	state.pos = hit.Position + hit.Normal * HEIGHT
end

-- ---------------------------------------------------------------- HUD: reticle, aim feedback, status, controls card
local hud = Instance.new("ScreenGui")
hud.Name = "SpiderHud"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.Parent = player:WaitForChild("PlayerGui")
local function label(name: string, pos: UDim2, anchor: Vector2, size: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.45
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextWrapped = false -- lines are broken by hand; wrapping with automatic size would collapse the label
	l.AnchorPoint = anchor
	l.Position = pos
	l.Size = size
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
	pad.Parent = l
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = l
	l.Parent = hud
	return l
end
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(6, 6)
reticle.BackgroundColor3 = Color3.new(1, 1, 1)
reticle.Visible = false
local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(1, 0)
rc.Parent = reticle
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(0, 0, 0)
stroke.Thickness = 1.5
stroke.Parent = reticle
reticle.Parent = hud
local ticks: { Frame } = {}
for i, off in { Vector2.new(-16, 0), Vector2.new(16, 0), Vector2.new(0, -16), Vector2.new(0, 16) } do
	local t = Instance.new("Frame")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.new(0.5, off.X, 0.5, off.Y)
	t.Size = if i <= 2 then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8)
	t.BackgroundColor3 = Color3.new(1, 1, 1)
	t.BorderSizePixel = 0
	t.Visible = false
	t.Parent = hud
	ticks[i] = t
end
local aimLabel = label("AimFeedback", UDim2.new(0.5, 0, 0.5, 28), Vector2.new(0.5, 0), UDim2.fromOffset(0, 0), 17)
local statusLabel = label("Status", UDim2.new(0.5, 0, 0, 58), Vector2.new(0.5, 0), UDim2.fromOffset(0, 0), 16)
local help = label("Controls", UDim2.new(0, 14, 1, -14), Vector2.new(0, 1), UDim2.fromOffset(0, 0), 15)
help.TextXAlignment = Enum.TextXAlignment.Left
help.Text = table.concat({
	"WASD walk   Mouse look   Shift creep",
	"Tap Space hop   Hold Space aim, release to leap   Q cancel",
	"V spider-eye view   R recenter   Right mouse focus   T slow motion",
	"Wheel zoom   Backspace back to start   G gait   H hide this",
	"Controller: sticks, A jump, B cancel, Y eye view, LB creep, LT focus, RT slow",
}, "\n")
help.Visible = true
local helpUntil = os.clock() + 20

local TITLES = { reachable = "Reachable", obstructed = "Blocked", unreachable = "Out of reach", ineligible = "Can't land there", none = "No surface in view" }
local REASONS = {
	ok = "", no_target = "no surface in view", ineligible_surface = "the spider cannot hold on there", too_far = "too far or too high",
	no_launch = "no way to leave this surface toward there", no_arrival = "it can't land from that angle", no_durations = "out of range",
	no_room = "no room to land", path_blocked = "something is in the way", graze = "it would only graze the surface",
	hop_blocked = "something is in the way", no_ground = "nothing to land on ahead",
}
local COLORS = {
	reachable = Color3.new(0.25, 0.92, 0.38), obstructed = Color3.new(1.0, 0.72, 0.1),
	unreachable = Color3.new(1.0, 0.32, 0.28), ineligible = Color3.new(0.72, 0.45, 1.0), none = Color3.new(0.8, 0.8, 0.8),
}

-- ---------------------------------------------------------------- dragline (drawn only)
local lines = Instance.new("Folder")
lines.Name = "Draglines"
lines.Parent = Workspace
local liveLine: Part? = nil

local function strand(a: Vector3, b: Vector3, p: Part)
	local len = math.max((b - a).Magnitude, 0.01)
	p.Size = Vector3.new(0.012, 0.012, len)
	p.CFrame = CFrame.lookAt((a + b) * 0.5, b)
end

local function newStrand(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(236, 232, 214)
	p.Transparency = 0.35
	p.Parent = lines
	local kids = lines:GetChildren()
	if #kids > MAX_DRAGLINES then kids[1]:Destroy() end
	return p
end

-- ---------------------------------------------------------------- jump preview: arc and landing patch
local arc = Instance.new("Folder")
arc.Name = "JumpArc"
arc.Parent = Workspace
local dots: { Part } = {}
local function display(p: Part)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Parent = arc
end
for i = 1, 28 do
	local d = Instance.new("Part")
	d.Name = "Dot" .. i
	d.Shape = Enum.PartType.Ball
	d.Size = Vector3.one * 0.07
	display(d)
	dots[i] = d
end
local patch = Instance.new("Part")
patch.Name = "LandingPatch"
patch.Shape = Enum.PartType.Cylinder
patch.Size = Vector3.new(0.02, 0.9, 0.9)
display(patch)
local ring = Instance.new("Part")
ring.Name = "LandingRing"
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.012, 1.15, 1.15)
display(ring)
local cross = Instance.new("Part")
cross.Name = "BlockedMark"
cross.Size = Vector3.new(0.5, 0.05, 0.05)
display(cross)

local function hidePreview()
	for _, d in dots do d.Transparency = 1 end
	patch.Transparency, ring.Transparency, cross.Transparency = 1, 1, 1
end

local function showPlan(plan: any)
	hidePreview()
	if not plan or plan.kind == "none" then return end
	local color = COLORS[plan.kind]
	local face = CFrame.lookAt(plan.point + plan.normal * 0.012, plan.point + plan.normal * 2) * CFrame.Angles(0, math.pi / 2, 0)
	patch.Color, ring.Color = color, color
	patch.CFrame = face
	ring.CFrame = face * CFrame.new(-0.004, 0, 0)
	patch.Transparency = if plan.kind == "reachable" then 0.55 else 0.75
	ring.Transparency = 0.25
	local path = plan.path
	if path and #path > 1 then
		for i, d in dots do
			local k = math.floor((i - 1) / (#dots - 1) * (#path - 1)) + 1
			d.Position = path[k]
			d.Color = color
			d.Transparency = 0.2
		end
	end
	if plan.blockedAt then
		cross.Color = color
		cross.CFrame = CFrame.lookAt(plan.blockedAt, camera.CFrame.Position) * CFrame.Angles(0, 0, math.rad(45))
		cross.Transparency = 0.1
	end
end

-- ---------------------------------------------------------------- the planner (port of jump_planner.gd)
local fitBall = Instance.new("Part")
fitBall.Shape = Enum.PartType.Ball
fitBall.Size = Vector3.one * (SWEEP_RADIUS * 2)
fitBall.Anchored = true
fitBall.CanCollide = false
fitBall.CanQuery = false
fitBall.CanTouch = false
fitBall.Transparency = 1
fitBall.Name = "RoomProbe"
fitBall.Parent = arc

local function sweep(a: Vector3, b: Vector3): Vector3?
	local d = b - a
	if d.Magnitude < 1e-6 then return nil end
	local hit = Workspace:Spherecast(a, SWEEP_RADIUS, d, params)
	return if hit then a + d.Unit * hit.Distance else nil
end

local function fits(center: Vector3): boolean
	fitBall.CFrame = CFrame.new(center)
	return #Workspace:GetPartsInPart(fitBall, overlap) == 0
end

local function tryCandidate(origin: Vector3, seat: Vector3, c: any): (boolean, string, { Vector3 }, Vector3?)
	local pts = JumpMath.path(origin, c.velocity, G, DT, c.steps)
	for k = 2, #pts do
		local at = sweep(pts[k - 1], pts[k])
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
		local at = sweep(p, nextP)
		if at then
			if (at - seat).Magnitude <= MAX_DRIFT then return true, "ok", pts, nil end
			return false, "graze", pts, at
		end
		p = nextP
	end
	return false, "graze", pts, seat
end

-- target: the surface point, its normal and the part it belongs to (nil inst: no surface).
local function planJump(point: Vector3?, normal: Vector3?, inst: Instance?): any
	if not point or not normal then return { kind = "none", reason = "no_target" } end
	local plan: any = { point = point, normal = normal, seat = point + normal * HEIGHT, kind = "unreachable", reason = "" }
	if not supports(profileOf(inst), normal) then
		plan.kind, plan.reason = "ineligible", "ineligible_surface"
		return plan
	end
	local solved = JumpMath.solve(state.pos, plan.seat, state.up, normal, G, DT, LOCO.flight_time_min_s, LOCO.flight_time_max_s, LOCO.max_launch_speed_wu_s)
	if #solved.valid == 0 then
		plan.reason = solved.reason
		return plan
	end
	if not fits(plan.seat) then
		plan.kind, plan.reason = "obstructed", "no_room"
		plan.path = JumpMath.path(state.pos, solved.valid[1].velocity, G, DT, solved.valid[1].steps)
		plan.blockedAt = plan.seat
		return plan
	end
	local firstPath, firstAt, anyBlocked = nil, nil, false
	for _, c in solved.valid do
		local ok, why, path, at = tryCandidate(state.pos, plan.seat, c)
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

-- The aim: whatever the screen-centre ray meets (no target magnet). Re-planned only when the aim or the spider moves.
local function aimPlan(): any
	local origin, dir = cam:aimRay()
	local hit = Workspace:Raycast(origin, dir * AIM_RANGE, params)
	local key = if hit
		then string.format("%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", hit.Position.X, hit.Position.Y, hit.Position.Z, hit.Normal.X, hit.Normal.Y, hit.Normal.Z, state.pos.X, state.pos.Y, state.pos.Z)
		else "none"
	if key ~= state.planKey or not state.plan then
		state.planKey = key
		state.plan = if hit then planJump(hit.Position, hit.Normal, hit.Instance) else planJump(nil, nil, nil)
	end
	return state.plan
end

-- JumpMotor.plan_hop: the ground HOP_DISTANCE ahead, planned and checked exactly like an aimed jump.
local function hopPlan(): any
	local n = state.up
	local h = SupportMath.tangentDir(state.heading, n)
	if h == Vector3.zero then h = SupportMath.anyPerpendicular(n) end
	local ahead = Workspace:Raycast(state.pos, h * (HOP_DISTANCE + HEIGHT), params)
	if ahead then
		return { kind = "obstructed", reason = "hop_blocked", point = ahead.Position, normal = ahead.Normal }
	end
	local finish = state.pos + h * HOP_DISTANCE
	local ground = Workspace:Raycast(finish + n * HOP_PROBE_UP, -n * (HOP_PROBE_UP + HOP_PROBE_DOWN), params)
	if not ground then
		return { kind = "unreachable", reason = "no_ground", point = finish - n * HEIGHT, normal = n }
	end
	return planJump(ground.Position, ground.Normal, ground.Instance)
end

local function feedback(plan: any)
	state.flash = plan
	state.flashLeft = FLASH_TICKS
end

local function launch(velocity: Vector3)
	local floorHit = Workspace:Raycast(state.pos, -state.up * (HEIGHT + 0.1), params)
	local fromSurface = if floorHit then profileOf(floorHit.Instance) else nil
	state.lineAnchor = if fromSurface and fromSurface.silk_anchor_allowed then state.pos - state.up * HEIGHT else nil
	if state.lineAnchor then liveLine = newStrand() end
	state.vel = velocity
	state.mode = "air"
	hidePreview()
end

local function endAim()
	state.phase = "idle"
	state.heldTicks = 0
	state.plan = nil
	state.planKey = ""
	cam:setAiming(false)
	hidePreview()
end

-- Jump input events are applied at the start of the next tick, so timing is counted in ticks.
local function applyJumpEvents()
	for _, e in events do
		if e == "press" then
			if state.mode == "attached" then
				state.phase, state.heldTicks = "pressed", 0
			end
		elseif e == "release" then
			if state.phase == "pressed" and state.mode == "attached" then
				local plan = hopPlan()
				if plan.kind == "reachable" then launch(plan.velocity) else feedback(plan) end
				state.phase = "idle"
			elseif state.phase == "aiming" then
				local plan = aimPlan()
				local attached = (state.mode :: string) == "attached"
				endAim()
				if plan.kind == "reachable" and attached then launch(plan.velocity) else feedback(plan) end
			else
				state.phase = "idle"
			end
		elseif e == "cancel" then
			if state.phase == "aiming" then
				endAim()
				feedback({ kind = "none", reason = "cancelled" })
			end
			state.phase = "idle"
		elseif e == "drop" then
			endAim()
		end
	end
	table.clear(events)
end

local function respawn()
	state.mode = "attached"
	state.pos = Layout.SPAWN + Vector3.new(0, HEIGHT, 0)
	state.up = Vector3.yAxis
	state.drawnUp = Vector3.yAxis
	state.heading = Layout.SPAWN_HEADING
	state.vel = Vector3.zero
	state.lineAnchor = nil
	liveLine = nil
	endAim()
	cam:snap()
end

-- ---------------------------------------------------------------- the fixed tick
local controls: any = nil

local function wish(): Vector3
	local r, f = controls:axes()
	if f == 0 and r == 0 then return Vector3.zero end
	local d = cam:mapStick(r, f, state.up)
	return if d.Magnitude > 1e-6 then d.Unit else Vector3.zero
end

local function turnToward(dir: Vector3, rate: number)
	local t = SupportMath.tangentDir(dir, state.up)
	if t ~= Vector3.zero then
		state.heading = SupportMath.tangentDir(SupportMath.rotateToward(state.heading, t, rate * DT), state.up)
	end
end

-- Focus (PlayerController.focus_direction) and the spider-eye turn: standing still, the body turns to look.
local function lookTurns(stickIdle: boolean)
	if controls.held.Focus then
		local origin, dir = cam:aimRay()
		local hit = Workspace:Raycast(origin, dir * 60, params)
		local eye = state.pos + state.heading * 0.45
		local to = if hit then hit.Position - eye else dir
		turnToward(if to.Magnitude > 0.2 then to else dir, FOCUS_RATE)
		state.eyeTurning = false
		return
	end
	if not cam.eyeView or not stickIdle then
		state.eyeTurning = false
		return
	end
	local look = SupportMath.tangentDir(cam.gaze, state.up)
	if look == Vector3.zero then return end
	local off = math.deg(SupportMath.angleTo(state.heading, look))
	if not state.eyeTurning and off > 30 then
		state.eyeTurning = true
	elseif state.eyeTurning and off < 4 then
		state.eyeTurning = false
	end
	if state.eyeTurning then turnToward(look, FOCUS_RATE) end
end

local function tickAttached()
	local preparing = state.phase == "aiming"
	local dir = if preparing then Vector3.zero else wish()
	state.moving = dir ~= Vector3.zero
	if not preparing then lookTurns(not state.moving) end
	if not state.moving then
		-- Re-seat on the support so a vanished or moved surface is noticed.
		local below = Workspace:Raycast(state.pos + state.up * 0.1, -state.up * (HEIGHT + 0.35), params)
		if not attachable(below) and not (below and supports(profileOf(below.Instance), below.Normal)) then
			state.mode = "air"
			state.vel = Vector3.zero
			events = { "drop" }
		end
		return
	end
	local stalk = controls.held.Creep == true
	local speed = if stalk then LOCO.stalk_speed_wu_s else LOCO.walk_speed_wu_s
	state.heading = SupportMath.tangentDir(SupportMath.rotateToward(state.heading, dir, TURN_RATE * DT), state.up)
	local step = dir * speed * DT
	-- Concave corner: a wall (or a leaf's edge, a stem) ahead becomes the new support.
	local ahead = Workspace:Raycast(state.pos, dir * (HEIGHT + step.Magnitude + 0.02), params)
	if ahead and attachable(ahead) and SupportMath.angleTo(ahead.Normal, state.up) > math.rad(20) then
		setSupport(ahead)
		return
	end
	local nextPos = state.pos + step
	local below = Workspace:Raycast(nextPos + state.up * 0.25, -state.up * (HEIGHT + 0.5), params)
	if below and attachable(below) and SupportMath.angleTo(below.Normal, state.up) < math.rad(60) then
		local n = SupportMath.filterNormal(state.up, below.Normal, 2.0)
		state.up = n
		state.pos = below.Position + n * HEIGHT
		state.heading = SupportMath.tangentDir(state.heading, n)
		return
	end
	-- Convex edge: wrap over it onto the face beyond (sill edge, leaf rim, the top of a wall).
	local around = Workspace:Raycast(nextPos - state.up * (HEIGHT + 0.15), -dir * 1.0, params)
	if around and attachable(around) then
		setSupport(around)
		return
	end
	state.mode = "air"
	state.vel = dir * speed
end

local function tickAir()
	local from = state.pos
	state.vel += G * DT
	local to = from + state.vel * DT
	local travel = to - from
	local dir = if travel.Magnitude > 1e-6 then travel.Unit else -state.up
	local hit = Workspace:Raycast(from, dir * (travel.Magnitude + HEIGHT), params)
	if hit then
		local approach = -state.vel:Dot(hit.Normal)
		if supports(profileOf(hit.Instance), hit.Normal) and approach >= JumpMath.minApproach(hit.Normal) then
			local heading = SupportMath.tangentDir(state.vel, hit.Normal)
			setSupport(hit)
			if heading ~= Vector3.zero then state.heading = heading end
			state.vel = Vector3.zero
			state.mode = "attached"
			if liveLine and state.lineAnchor then
				strand(state.lineAnchor, rig:spinneretPoint(SupportMath.bodyCFrame(state.pos, state.up, state.heading)), liveLine)
			end
			liveLine = nil
			state.lineAnchor = nil
			return
		end
		-- Not landable here: slide along it.
		state.vel -= hit.Normal * math.min(0, state.vel:Dot(hit.Normal))
		to = hit.Position + hit.Normal * HEIGHT
	end
	state.pos = to
	-- The drawn body turns upright while falling.
	state.up = SupportMath.rotateToward(state.up, Vector3.yAxis, math.rad(240) * DT)
	local lo, hi = Layout.PLAY_BOUNDS_MIN, Layout.PLAY_BOUNDS_MAX
	if to.X < lo.X or to.Y < lo.Y or to.Z < lo.Z or to.X > hi.X or to.Y > hi.Y or to.Z > hi.Z then
		respawn()
	end
end

local function tick()
	applyJumpEvents()
	if state.mode == "attached" then
		if state.phase == "pressed" then
			state.heldTicks += 1
			if state.heldTicks >= HOLD_TICKS then
				state.phase = "aiming"
				state.plan = nil
				state.planKey = ""
				cam:setAiming(true)
			end
		end
		tickAttached()
	else
		if state.phase ~= "idle" then endAim() end
		tickAir()
	end
	if state.flashLeft > 0 then
		state.flashLeft -= 1
		if state.flashLeft == 0 then state.flash = nil end
	end
end

-- ---------------------------------------------------------------- camera and input
cam = SpiderCamera.new(camera, params, function()
	return { pos = state.pos, drawnUp = state.drawnUp, heading = state.heading }
end, function(on: boolean)
	rig:setEyeView(on)
end)
cam.hide = function(hidden: boolean)
	rig:setBodyHidden(hidden)
end

controls = SpiderInput.bind({
	jump = function(phase: string)
		table.insert(events, if phase == "begin" then "press" elseif phase == "end" then "release" else "cancel")
	end,
	cancel = function() table.insert(events, "cancel") end,
	reset = respawn,
	gait = function() rig.gaitMode = if rig.gaitMode == "Tetrapod" then "Unilateral" else "Tetrapod" end,
	eye = function() cam:toggleEyeView() end,
	recenter = function() cam:startRecenter() end,
	slow = function() state.slow = not state.slow end,
	touchLook = function(delta: Vector2) cam:touchLook(delta) end,
	help = function()
		help.Visible = not help.Visible
		helpUntil = math.huge
	end,
})

local function updateHud()
	local aiming = state.phase == "aiming"
	reticle.Visible = aiming or controls.held.Focus == true or cam.eyeView
	for _, t in ticks do t.Visible = controls.held.Focus == true end
	local shown = if aiming then state.plan else state.flash
	if shown then
		local title = TITLES[shown.kind] or ""
		local why = REASONS[shown.reason] or ""
		if shown.reason == "cancelled" then
			aimLabel.Text = "Jump cancelled"
		elseif aiming then
			local hint = if shown.kind == "reachable" then "release to leap   Q cancels" else "release to cancel"
			aimLabel.Text = (if why ~= "" and shown.kind ~= "reachable" then title .. ": " .. why else title) .. "\n" .. hint
		else
			aimLabel.Text = if why ~= "" then title .. ": " .. why else title
		end
		aimLabel.TextColor3 = COLORS[shown.kind] or COLORS.none
		aimLabel.Visible = true
	else
		aimLabel.Visible = false
	end
	if aiming then showPlan(state.plan) elseif state.flash and state.flash.point then showPlan(state.flash) else hidePreview() end
	local status = {}
	if cam.eyeView then table.insert(status, "SPIDER-EYE VIEW    V / Y: back") end
	if state.slow then table.insert(status, `SLOW MOTION {math.floor(SLOW_SPEED * 100)}%    T / RT: normal speed`) end
	statusLabel.Text = table.concat(status, "\n")
	statusLabel.Visible = #status > 0
	if os.clock() > helpUntil and help.Visible then help.Visible = false end
end

local accumulator = 0
RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)
	local simDt = frameDt * (if state.slow then SLOW_SPEED else 1)
	accumulator = math.min(accumulator + simDt, 0.25)
	while accumulator >= DT do
		accumulator -= DT
		tick()
		cam:tick(DT)
		if state.phase == "aiming" then aimPlan() end
	end
	-- Drawn frame: the up vector eases so walls and edges do not snap.
	state.drawnUp = state.drawnUp:Lerp(state.up, 1 - math.exp(-24 * simDt)).Unit
	local body = SupportMath.bodyCFrame(state.pos, state.drawnUp, state.heading)
	rig:update(body, simDt, state.mode == "attached", state.moving)
	if liveLine and state.lineAnchor then strand(state.lineAnchor, rig:spinneretPoint(body), liveLine) end
	-- Looking runs in real time, so slow motion never makes the camera sluggish.
	local lx, ly = controls:lookAxes()
	cam:render(frameDt, lx, ly)
	updateHud()
	local dof = Lighting:FindFirstChild("MacroDOF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		local focus = (camera.CFrame.Position - state.pos).Magnitude
		if cam.eyeView then
			local origin, dir = cam:aimRay()
			local hit = Workspace:Raycast(origin, dir * 40, params)
			focus = if hit then hit.Distance else 40
		end
		dof.FocusDistance = focus
	end
end)
