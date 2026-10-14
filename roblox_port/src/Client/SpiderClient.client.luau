--!strict
-- The playable spider: a client-side, kinematic port of the Godot motor's core (scripts/movement/spider_motor.gd,
-- jump_controller.gd). It walks on any attachable surface (floor, walls, undersides, over edges), aims and flies jumps
-- solved by the shared JumpMath at a fixed 60 Hz tick, trails a dragline, and drives the procedural SpiderRig.
--
-- Controls: WASD walk (camera-relative), Shift creep, tap Space hop, hold Space to aim at the screen centre and release
-- to leap, G toggles the gait (alternating tetrapod / one side at a time), R respawns. Right mouse drag orbits, wheel zooms.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SpiderInput = require(script.Parent.SpiderInput)
local controls: any = nil

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
local HEIGHT = 0.31 -- body centre above the support plane (Godot spawn height)
local TURN_RATE = math.rad(540)
local AIM_HOLD_S = 0.18
local AIM_RANGE = 40
local HOP_DISTANCE = 1.6
local MAX_DRAGLINES = 24 -- two segments per one-bend line

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local sill = Workspace:WaitForChild("Windowsill")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }

local rig = SpiderRig.new(Workspace, sill)
local SilkController = require(Shared.Movement.SilkController)
local silk = SilkController.new(sill, Surfaces, profile.silk, LOCO.gravity_wu_s2)

type Mode = "attached" | "air"
local state = {
	mode = "attached" :: Mode,
	pos = Layout.SPAWN + Vector3.new(0, HEIGHT, 0),
	up = Vector3.yAxis,
	heading = Layout.SPAWN_HEADING,
	vel = Vector3.zero,
	drawnUp = Vector3.yAxis,
	moving = false,
	spaceDown = false,
	spaceTime = 0,
	aiming = false,
	plan = nil :: any,
	planFrom = Vector3.zero,
	flightTicks = 0,
	flightLimit = 0,
}

local function profileOf(hit: RaycastResult): any
	local id = hit.Instance:GetAttribute("ProfileId")
	return if typeof(id) == "string" then Surfaces[id] else nil
end

local function attachable(hit: RaycastResult?): boolean
	if not hit then
		return false
	end
	local p = profileOf(hit)
	return p ~= nil and p.attachable == true
end

-- The smallest rotation taking unit a onto unit b.
local function rotationBetween(a: Vector3, b: Vector3): CFrame
	local angle = SupportMath.angleTo(a, b)
	if angle < 1e-6 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if axis:Dot(axis) < 1e-12 then
		axis = SupportMath.anyPerpendicular(a)
	end
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

local function setSupport(hit: RaycastResult)
	local turn = rotationBetween(state.up, hit.Normal)
	state.heading = SupportMath.tangentDir(turn * state.heading, hit.Normal)
	if state.heading == Vector3.zero then
		state.heading = SupportMath.anyPerpendicular(hit.Normal)
	end
	state.up = hit.Normal
	state.pos = hit.Position + hit.Normal * HEIGHT
end

local function respawn()
	state.mode = "attached"
	state.pos = Layout.SPAWN + Vector3.new(0, HEIGHT, 0)
	state.up = Vector3.yAxis
	state.heading = Layout.SPAWN_HEADING
	state.vel = Vector3.zero
	state.aiming = false
	state.plan = nil
	silk:clear()
end

-- ---------------------------------------------------------------- safety-line rendering (mechanics in SilkController)
local lines = Instance.new("Folder")
lines.Name = "Draglines"
lines.Parent = Workspace
local liveLine: Part? = nil
local bendLine: Part? = nil

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
	p:SetAttribute("Born", time())
	p.Parent = lines
	local kids = lines:GetChildren()
	if #kids > MAX_DRAGLINES then
		kids[1]:Destroy()
	end
	return p
end

-- ---------------------------------------------------------------- jump preview
local arc = Instance.new("Folder")
arc.Name = "JumpArc"
arc.Parent = Workspace
local dots: { Part } = {}
for i = 1, 28 do
	local d = Instance.new("Part")
	d.Name = "Dot" .. i
	d.Shape = Enum.PartType.Ball
	d.Size = Vector3.one * 0.07
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.CastShadow = false
	d.Material = Enum.Material.Neon
	d.Transparency = 1
	d.Parent = arc
	dots[i] = d
end
local patch = Instance.new("Part")
patch.Name = "LandingPatch"
patch.Shape = Enum.PartType.Cylinder
patch.Size = Vector3.new(0.02, 1.0, 1.0)
patch.Anchored = true
patch.CanCollide = false
patch.CanQuery = false
patch.CanTouch = false
patch.CastShadow = false
patch.Material = Enum.Material.Neon
patch.Transparency = 1
patch.Parent = arc

local function hidePreview()
	for _, d in dots do
		d.Transparency = 1
	end
	patch.Transparency = 1
end

local function aim()
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
	state.plan = nil
	if not hit then
		hidePreview()
		return
	end
	local seat = hit.Position + hit.Normal * HEIGHT
	local ok = attachable(hit)
	local result = JumpMath.solve(state.pos, seat, state.up, hit.Normal, G, DT, LOCO.flight_time_min_s, LOCO.flight_time_max_s, LOCO.max_launch_speed_wu_s)
	local sol = if ok then result.valid[1] else nil
	local color = if sol then Color3.fromRGB(110, 230, 140) else Color3.fromRGB(235, 90, 70)
	patch.Color = color
	patch.Transparency = 0.45
	patch.CFrame = CFrame.lookAt(hit.Position + hit.Normal * 0.01, hit.Position + hit.Normal) * CFrame.Angles(0, math.pi / 2, 0)
	if sol then
		state.plan = sol
		state.planFrom = state.pos
		local pts = JumpMath.path(state.pos, sol.velocity, G, DT, sol.steps)
		for i, d in dots do
			local k = math.floor((i - 1) / (#dots - 1) * sol.steps) + 1
			d.Position = pts[k]
			d.Color = color
			d.Transparency = 0.2
		end
	else
		for _, d in dots do
			d.Transparency = 1
		end
	end
end

local function beginStrands()
	liveLine = newStrand()
	bendLine = newStrand()
	bendLine.Transparency = 1
end
local function launch(velocity: Vector3, steps: number)
	local floorHit = Workspace:Raycast(state.pos, -state.up * (HEIGHT + 0.1), params)
	if silk:anchorAt(floorHit, state.pos) then beginStrands() end
	state.flightTicks, state.flightLimit = 0, steps+4
	state.vel = velocity
	state.mode = "air"
	hidePreview()
end
local function beginDrop(push: Vector3): boolean
	if not silk:startDrop(state.pos, state.up, push) then return false end
	beginStrands()
	state.vel = push*0.6
	state.mode = "air"
	state.aiming=false; state.spaceDown=false; state.plan=nil
	hidePreview()
	return true
end
local function requestDrop()
	if state.mode ~= "attached" or state.aiming or silk.walk then return end
	local plan, message = silk:planDrop(state.pos,state.up,state.heading)
	if not plan then silk.message=message; return end
	if plan.direction.Magnitude<1e-6 then
		if beginDrop(state.up) then state.pos+=state.up*0.01 end
	else
		silk.walk={direction=plan.direction, ticks=math.ceil((plan.distance/LOCO.walk_speed_wu_s+1.5)*60)}
		silk.message="Walking to the edge — move or cancel to stop"
	end
end

local function hop()
	local seatGuess = state.pos + state.heading * HOP_DISTANCE
	local hit = Workspace:Raycast(seatGuess + state.up * 0.6, -state.up * 1.5, params)
	if not attachable(hit) then
		return
	end
	local h = hit :: RaycastResult
	local seat = h.Position + h.Normal * HEIGHT
	local g = if JumpMath.isStanding(state.up) then G else -state.up * LOCO.gravity_wu_s2
	local result = JumpMath.solve(state.pos, seat, state.up, h.Normal, g, DT, LOCO.flight_time_min_s, LOCO.flight_time_max_s, LOCO.max_launch_speed_wu_s)
	if result.valid[1] and g == G then
		launch(result.valid[1].velocity, result.valid[1].steps)
	end
end

-- ---------------------------------------------------------------- the fixed tick
local function wish(): Vector3
	local r, f = controls:axes()
	if f == 0 and r == 0 then
		return Vector3.zero
	end
	local cf = camera.CFrame
	local dir = SupportMath.tangentDir(cf.LookVector * f + cf.RightVector * r, state.up)
	if dir == Vector3.zero then
		dir = SupportMath.tangentDir(cf.UpVector * f + cf.RightVector * r, state.up)
	end
	return dir
end

local function tickAttached()
	local manual = wish()
	if silk.walk and manual.Magnitude>0 then silk.walk=nil; silk.message="Edge walk cancelled" end
	local dir = if state.aiming then Vector3.zero elseif silk.walk then silk.walk.direction else manual
	if silk.walk then
		silk.walk.ticks-=1
		if silk.walk.ticks<=0 then silk.walk=nil; silk.message="Edge walk stopped"; return end
	end
	state.moving = dir ~= Vector3.zero
	if not state.moving then
		-- Re-seat on the support so a vanished or moved surface is noticed.
		local below = Workspace:Raycast(state.pos + state.up * 0.1, -state.up * (HEIGHT + 0.35), params)
		if not attachable(below) then
			state.mode = "air"
			state.vel = Vector3.zero
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
	if silk.walk then
		if beginDrop(dir) then state.pos=nextPos+dir*(HEIGHT+0.02) end
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
	if silk.mode=="locked" then
		local _,forward=controls:axes()
		local intent=if controls.held.Drop then math.min(forward,0)-1 else forward
		local hit
		state.pos,state.vel,hit=silk:step(state.pos,state.vel,math.clamp(intent,-1,1),controls.held.Release==true)
		if hit then
			setSupport(hit); state.vel=Vector3.zero; state.mode="attached"
			silk:clear(); liveLine=nil; bendLine=nil
		end
		return
	end
	state.flightTicks+=1
	local from = state.pos
	state.vel += G * DT
	local to = from + state.vel * DT
	local travel = to - from
	local dir = if travel.Magnitude > 1e-6 then travel.Unit else -state.up
	local hit = Workspace:Raycast(from, dir * (travel.Magnitude + HEIGHT), params)
	if hit then
		local approach = -state.vel:Dot(hit.Normal)
		if attachable(hit) and approach >= JumpMath.minApproach(hit.Normal) then
			local heading = SupportMath.tangentDir(state.vel, hit.Normal)
			setSupport(hit)
			if heading ~= Vector3.zero then
				state.heading = heading
			end
			state.vel = Vector3.zero
			state.mode = "attached"
			liveLine=nil; bendLine=nil
			silk:clear()
			return
		end
		if silk.mode=="payout" then silk:lock(state.pos,0.25) end
		-- Not landable here: slide along it.
		state.vel -= hit.Normal * math.min(0, state.vel:Dot(hit.Normal))
		to = hit.Position + hit.Normal * HEIGHT
	end
	state.pos = to
	silk:payout(to)
	if silk.mode=="payout" and state.flightTicks>=state.flightLimit then silk:lock(to,0.25) end
	-- The drawn body turns upright while falling.
	state.up = SupportMath.rotateToward(state.up, Vector3.yAxis, math.rad(240) * DT)
	local lo, hi = Layout.PLAY_BOUNDS_MIN, Layout.PLAY_BOUNDS_MAX
	if to.X < lo.X or to.Y < lo.Y or to.Z < lo.Z or to.X > hi.X or to.Y > hi.Y or to.Z > hi.Z then
		respawn()
	end
end

local function tick()
	if state.mode == "attached" then
		if state.spaceDown then
			state.spaceTime += DT
			if state.spaceTime >= AIM_HOLD_S then
				state.aiming = true
				aim()
			end
		end
		tickAttached()
	else
		tickAir()
	end
end

controls = SpiderInput.bind(function(phase: string)
	if phase == "begin" then
		silk.walk=nil
		state.spaceDown = true
		state.spaceTime = 0
		return
	end
	state.spaceDown = false
	if phase == "end" and state.mode == "attached" then
		if state.aiming then
			local plan = state.plan
			if plan and (state.pos - state.planFrom).Magnitude < 1e-3 then launch(plan.velocity, plan.steps) end
		else hop() end
	end
	state.aiming = false
	state.plan = nil
	hidePreview()
end, function() silk.walk=nil; respawn() end, function()
	rig.gaitMode = if rig.gaitMode == "Tetrapod" then "Unilateral" else "Tetrapod"
end, function(action, phase)
	if action=="Drop" and phase=="begin" then requestDrop() end
	if action=="Release" and phase=="begin" then
		if silk.walk then silk.walk=nil; silk.message="Edge walk cancelled" end
		state.aiming=false; state.spaceDown=false; state.plan=nil; hidePreview()
	end
	if phase=="clear" then silk.release.down=true; silk.release.counts=false; silk.release.held=0; silk.release.progress=0; silk.walk=nil end
end)

-- ---------------------------------------------------------------- camera
player.CameraMinZoomDistance = 1.5
player.CameraMaxZoomDistance = 30
camera.CameraType = Enum.CameraType.Custom
camera.CameraSubject = rig.root
camera.FieldOfView = 60

local hud=Instance.new("ScreenGui")
hud.Name="SilkHUD"; hud.ResetOnSpawn=false; hud.Parent=player:WaitForChild("PlayerGui")
local status=Instance.new("TextLabel")
status.Name="SilkStatus"; status.Size=UDim2.new(1,-32,0,64); status.Position=UDim2.new(0,16,0,36)
status.BackgroundColor3=Color3.new(0.03,0.03,0.03); status.BackgroundTransparency=0.25
status.TextColor3=Color3.new(1,1,1); status.TextSize=17; status.TextWrapped=true; status.AutomaticSize=Enum.AutomaticSize.Y; status.Parent=hud
local accumulator = 0
RunService.RenderStepped:Connect(function(frameDt: number)
	accumulator = math.min(accumulator + frameDt, 0.25)
	while accumulator >= DT do
		accumulator -= DT
		tick()
	end
	-- Drawn frame: the up vector eases so walls and edges do not snap.
	state.drawnUp = state.drawnUp:Lerp(state.up, 1 - math.exp(-24 * frameDt)).Unit
	local body = SupportMath.bodyCFrame(state.pos, state.drawnUp, state.heading)
	rig:update(body, frameDt, state.mode == "attached", state.moving)
	if liveLine and bendLine and silk.mode~="none" then
		local tip=rig:spinneretPoint(body)
		strand(silk.anchor,silk.bend or tip,liveLine)
		liveLine.Transparency=0.35
		if silk.bend then strand(silk.bend,tip,bendLine); bendLine.Transparency=0.35 else bendLine.Transparency=1 end
	elseif liveLine then
		liveLine:Destroy(); liveLine=nil
		if bendLine then bendLine:Destroy(); bendLine=nil end
	end
	for _,line in lines:GetChildren() do
		if line~=liveLine and line~=bendLine then
			local age=time()-(line:GetAttribute("Born") or time())
			if age>25 then line:Destroy() else line.Transparency=math.max(line.Transparency,0.35+0.65*age/25) end
		end
	end
	local progress=silk.release.progress
	status.Text=if silk.mode=="locked" then silk.message.." | W / ↑: reel • S / ↓: lower • hold Q / B / Let go"..(if progress>0 then ` ({math.floor(progress*100)}%)` else "")
		elseif silk.walk then silk.message else (if silk.message~="" then silk.message.." | " else "").."F / X: lower on silk"

	local dof = Lighting:FindFirstChild("MacroDOF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.FocusDistance = (camera.CFrame.Position - state.pos).Magnitude
	end
end)

-- The test-place-only module exercises this controller in Studio. Absent from the playable build.
local playback=script.Parent:FindFirstChild("SilkPlayback")
if RunService:IsStudio() and playback then
    task.spawn(function()
        require(playback)({input=controls,drop=requestDrop,
            place=function(position)
                controls:clear(); respawn(); state.pos=position; state.up=Vector3.yAxis; state.heading=Vector3.zAxis
            end,
            get=function() return {mode=state.mode,line=silk.mode,taut=silk.taut,position=state.pos,walking=silk.walk~=nil} end})
    end)
end
