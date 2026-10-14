--!strict
-- The playable spider. Wires one control scheme (SpiderInput: keyboard and mouse, controller and touch together) to the
-- Godot jump controller's phases (Shared/Movement/JumpInput), the body (Shared/Movement/SpiderMotor: walking on any
-- surface, hops and aimed leaps, the safety line), the camera (SpiderCamera, a port of camera_rig.gd), the drawn spider
-- (SpiderRig) and the screen (SpiderHud, words from Shared/UI/ControlText for the device in use). Ports the frozen Godot
-- game at c87ce00: scripts/core/input_setup.gd, player_controller.gd, jump_controller.gd, tether_controller.gd.
--
-- Controls (README.md has the full table): WASD walk relative to the view, mouse looks, Shift creeps. Tap Space: a short
-- hop. Hold Space (0.15 s): the spider holds still and turns toward the centre dot; the landing patch says Reachable /
-- Blocked / Out of reach / Can't land there; release to leap, Q cancels. F lets down on silk (to the nearest edge first on
-- top of a leaf). On the line W reels in, S lowers and holding Q lets go. V spider-eye view, R recenter, right mouse Focus,
-- T slow motion, H controls card, Backspace back to the start, Esc the Roblox menu (the game waits).

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local SpiderInput = require(script.Parent.SpiderInput)
local SpiderCamera = require(script.Parent.SpiderCamera)
local SpiderHud = require(script.Parent.SpiderHud)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = Shared:WaitForChild("Movement")
local SupportMath = require(Movement:WaitForChild("SupportMath"))
local SpiderMotor = require(Movement:WaitForChild("SpiderMotor"))
local JumpInput = require(Movement:WaitForChild("JumpInput"))
local ControlText = require(Shared:WaitForChild("UI"):WaitForChild("ControlText"))
local Species = require(Shared:WaitForChild("Data"):WaitForChild("Species"))
local Surfaces = require(Shared:WaitForChild("Data"):WaitForChild("Surfaces"))
local Layout = require(Shared:WaitForChild("Habitat"):WaitForChild("WindowsillLayout"))
local SpiderRig = require(Shared:WaitForChild("Rig"):WaitForChild("SpiderRig"))

local DT = SpiderMotor.DT
local SLOW_SPEED = 0.5
local MAX_DRAGLINES = 24 -- two segments per one-bend line
local WALK_HINT_SECONDS = 60
local PATCH_GROW_FROM = 6 -- studs from the camera; beyond it the patch grows with distance (up to 4x), as in Godot
local COLORS = {
	reachable = Color3.new(0.25, 0.92, 0.38), obstructed = Color3.new(1.0, 0.72, 0.1),
	unreachable = Color3.new(1.0, 0.32, 0.28), ineligible = Color3.new(0.72, 0.45, 1.0), none = Color3.new(0.8, 0.8, 0.8),
}
local WARN_EVENTS = { drop_refused = true, snagged = true, lost = true, blocked = true }

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local sill = Workspace:WaitForChild("Windowsill")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }

local arc = Instance.new("Folder")
arc.Name = "JumpArc"
arc.Parent = Workspace
local motor: any = SpiderMotor.new({
	world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype,
	spawn = Layout.SPAWN, heading = Layout.SPAWN_HEADING,
	boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = arc,
})
local jump: any = JumpInput.new()
-- Touch-only devices get the lighter fuzz until a real tablet frame-time check (ROBLOX_PORT.md).
local rig = SpiderRig.new(Workspace, sill, nil, if UIS.TouchEnabled and not UIS.KeyboardEnabled then "low" else "full")
local hud = SpiderHud.new(player:WaitForChild("PlayerGui"))
local device: ControlText.Device = ControlText.initialDevice(UIS.TouchEnabled, UIS.KeyboardEnabled, UIS.GamepadEnabled)
local drawnUp = Vector3.yAxis
local slow = false
local helpVisible, helpUntil = true, os.clock() + 20
local started = os.clock()
local afterMiss, dropped = false, false
local lastFeedback: any = nil

-- ---------------------------------------------------------------- the safety line as drawn (mechanics in SilkController)
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
	if #kids > MAX_DRAGLINES then kids[1]:Destroy() end
	return p
end

local function beginStrands()
	liveLine = newStrand()
	local bend = newStrand()
	bend.Transparency = 1
	bendLine = bend
end

local function dropStrands(keep: boolean)
	if not keep then
		if liveLine then liveLine:Destroy() end
		if bendLine then bendLine:Destroy() end
	end
	liveLine, bendLine = nil, nil
end

-- ---------------------------------------------------------------- jump preview: arc and landing patch
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
display(patch)
local ring = Instance.new("Part")
ring.Name = "LandingRing"
ring.Shape = Enum.PartType.Cylinder
display(ring)
local cross = Instance.new("Part")
cross.Name = "BlockedMark"
display(cross)

local function hidePreview()
	for _, d in dots do d.Transparency = 1 end
	patch.Transparency, ring.Transparency, cross.Transparency = 1, 1, 1
end

local function showPlan(plan: any)
	hidePreview()
	if not plan or plan.kind == "none" or not plan.point then return end
	local color = COLORS[plan.kind] or COLORS.none
	-- Beyond 6 studs from the camera the whole patch grows with the distance (up to four times), so it stays readable;
	-- its centre is still the exact landing point.
	local grow = math.clamp((camera.CFrame.Position - plan.point).Magnitude / PATCH_GROW_FROM, 1, 4)
	patch.Size = Vector3.new(0.02, 0.9 * grow, 0.9 * grow)
	ring.Size = Vector3.new(0.012, 1.15 * grow, 1.15 * grow)
	cross.Size = Vector3.new(0.5 * grow, 0.05 * grow, 0.05 * grow)
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

-- ---------------------------------------------------------------- camera and input
local cam: any = SpiderCamera.new(camera, params, function()
	return {
		pos = motor.pos, drawnUp = drawnUp, heading = motor.heading,
		onLine = motor:onLine(), rest = motor:lineRestPoint(), lip = motor:lineLip(),
	}
end, function(on: boolean)
	rig:setEyeView(on)
end)
cam.hide = function(hidden: boolean)
	rig:setBodyHidden(hidden)
end
jump.onAim = function(on: boolean)
	cam:setAiming(on)
end

-- Everything held is dropped with no penalty and no message: focus loss, the Roblox menu, a text box, a lost controller.
local function dropAll()
	jump:drop(motor)
	local release = motor.silk.release
	release.down, release.counts, release.held, release.progress = true, false, 0, 0
	motor:cancelWalk()
end

local function backToStart()
	jump:drop(motor)
	motor:respawn()
	dropStrands(false)
	drawnUp = motor.up
	cam:snap()
end

local controls: any = SpiderInput.bind({
	jump = function(phase: string)
		if phase == "begin" then
			motor:cancelWalk() -- a jump press takes over from a walk to the edge
			jump:press()
		elseif phase == "end" then
			jump:release()
		else
			jump:cancel()
		end
	end,
	-- Q / B / touch Cancel (Let go on the line): the same button cancels an aim, stops a walk to the edge (and is nothing
	-- else's then) and, held on the line, lets go; SilkController counts only a fresh press after the 0.4 s grace, held 0.6 s.
	cancel = function(phase: string)
		if phase ~= "begin" then return end
		if motor:cancelWalk() then return end
		jump:cancel()
	end,
	drop = function() motor:requestDrop() end,
	clear = dropAll,
	reset = backToStart,
	gait = function() rig.gaitMode = if rig.gaitMode == "Tetrapod" then "Unilateral" else "Tetrapod" end,
	eye = function() cam:toggleEyeView() end,
	recenter = function() cam:startRecenter() end,
	slow = function() slow = not slow end,
	touchLook = function(delta: Vector2) cam:touchLook(delta) end,
	help = function()
		helpVisible = not helpVisible
		helpUntil = math.huge
	end,
	device = function(name: string)
		device = ControlText.deviceFor(name, device)
	end,
})

-- One fixed tick's intent from the controls, for the motor.
local function tickInput(): any
	local r, f = controls:axes()
	local wish = Vector3.zero
	if r ~= 0 or f ~= 0 then
		local d = cam:mapStick(r, f, motor.up)
		if d.Magnitude > 1e-6 then wish = d.Unit end
	end
	local focusPoint: Vector3? = nil
	if controls.held.Focus then
		local origin, dir = cam:aimRay()
		local hit = Workspace:Raycast(origin, dir * SpiderMotor.AIM_RANGE, params)
		focusPoint = if hit then hit.Position else origin + dir * SpiderMotor.AIM_RANGE
	end
	return {
		wish = wish, creep = controls.held.Creep == true, reel = f,
		dropHeld = controls.held.Drop == true, releaseHeld = controls.held.Cancel == true,
		focusPoint = focusPoint, gaze = if cam.eyeView then cam.gaze else nil,
	}
end

-- ---------------------------------------------------------------- the screen
local function handleEvents()
	for _, e in motor:drainEvents() do
		local kind = if e.kind == "landed" then "completed" else e.kind
		if kind == "locked" then afterMiss = true elseif kind == "dropped" then dropped = true end
		if kind == "anchored" or kind == "dropped" then beginStrands() end
		if kind == "completed" then dropStrands(true) end
		if kind == "released" or kind == "lost" or kind == "out_of_bounds" then dropStrands(false) end
		if kind == "out_of_bounds" then
			hud:toast(ControlText.toast("out_of_bounds", nil), true)
			drawnUp = motor.up
			cam:snap()
		else
			hud:toast(ControlText.lineToast(kind, e.detail, afterMiss, dropped, device), WARN_EVENTS[kind] == true)
		end
		if kind == "completed" or kind == "released" or kind == "lost" or kind == "anchored" then
			afterMiss, dropped = false, false
		end
	end
	local last = jump.last
	if last and last ~= lastFeedback then
		lastFeedback = last
		hud:toast(ControlText.toast(last.kind, last.plan), last.kind ~= "cancelled")
	end
end

local function updateHud(frameDt: number)
	handleEvents()
	local aiming = jump:isAiming()
	local view: any = {
		device = device, aiming = aiming, focus = controls.held.Focus == true, eyeView = cam.eyeView,
		status = {}, helpVisible = helpVisible, helpText = ControlText.helpCard(device),
	}
	if aiming then
		local plan = jump.plan
		local title, hint = ControlText.describe(plan, device)
		view.aimTitle, view.aimHint = title, hint
		view.aimColor = COLORS[if plan then plan.kind else "none"] or COLORS.none
		local reason = motor:anchorPreview(plan)
		view.anchorText, view.anchorOk = ControlText.anchorText(reason), reason == "ok"
		showPlan(plan)
	elseif jump.flash then
		showPlan(jump.flash)
	else
		hidePreview()
	end
	if cam.eyeView then table.insert(view.status, `SPIDER-EYE VIEW    {ControlText.name(device, "eye")}: back`) end
	if slow then
		local key = ControlText.name(device, "slow")
		table.insert(view.status, `SLOW MOTION {math.floor(SLOW_SPEED * 100)}%` .. (if key ~= "" then `    {key}: normal speed` else ""))
	end
	local silk = motor.silk
	local onLine = motor:onLine()
	if onLine then
		local _, f = controls:axes()
		local title, hint, cue = ControlText.linePanel({
			reeling = f > 0.2 and silk.block == "" and not silk.snagged,
			progress = silk.release.progress, snagged = silk.snagged, block = silk.block,
		}, device)
		view.prompt = { title = title, hint = hint, cue = cue }
	elseif silk.walk then
		view.prompt = { hint = ControlText.edgeWalkHint(device) }
	elseif motor.mode == "attached" and not aiming and (helpVisible or os.clock() - started < WALK_HINT_SECONDS) then
		view.prompt = { hint = ControlText.walkHint(device) }
	end
	if os.clock() > helpUntil and helpVisible then helpVisible = false end
	controls:setTouchLabel("Cancel", ControlText.touchCancelLabel(onLine))
	controls:setTouchVisible("Jump", not onLine)
	controls:setTouchVisible("Creep", not onLine)
	hud:update(view, frameDt)
end

-- ---------------------------------------------------------------- the frame
local accumulator = 0
RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)
	if GuiService.MenuIsOpen then
		accumulator = 0 -- the Roblox menu is Godot's pause: the world waits
	else
		local simDt = frameDt * (if slow then SLOW_SPEED else 1)
		accumulator = math.min(accumulator + simDt, 0.25)
		local origin, dir = cam:aimRay()
		motor:setAimRay(origin, dir)
		while accumulator >= DT do
			accumulator -= DT
			jump:step(motor)
			motor:tick(tickInput())
			cam:tick(DT)
		end
	end
	-- Drawn frame: the up vector eases so walls and edges do not snap.
	local simFrame = frameDt * (if slow then SLOW_SPEED else 1)
	drawnUp = drawnUp:Lerp(motor.up, 1 - math.exp(-24 * simFrame)).Unit
	local body = SupportMath.bodyCFrame(motor.pos, drawnUp, motor.heading)
	rig:update(body, simFrame, motor.mode == "attached", motor.moving)
	updateHud(frameDt)
	local silk = motor.silk
	local live, bend = liveLine, bendLine
	if live and bend and silk.mode ~= "none" then
		local tip = rig:spinneretPoint(body)
		strand(silk.anchor, silk.bend or tip, live)
		live.Transparency = 0.35
		if silk.bend then
			strand(silk.bend, tip, bend)
			bend.Transparency = 0.35
		else
			bend.Transparency = 1
		end
	end
	for _, line in lines:GetChildren() do
		if line ~= liveLine and line ~= bendLine and line:IsA("BasePart") then
			local born = line:GetAttribute("Born")
			local age = time() - (if typeof(born) == "number" then born else time())
			if age > 25 then line:Destroy() else line.Transparency = math.max(line.Transparency, 0.35 + 0.65 * age / 25) end
		end
	end
	-- Looking runs in real time, so slow motion never makes the camera sluggish.
	local lx, ly = controls:lookAxes()
	cam:render(frameDt, lx, ly)
	local dof = Lighting:FindFirstChild("MacroDOF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		local focus = (camera.CFrame.Position - motor.pos).Magnitude
		if cam.eyeView then
			local origin, dir = cam:aimRay()
			local hit = Workspace:Raycast(origin, dir * 40, params)
			focus = if hit then hit.Distance else 40
		end
		dof.FocusDistance = focus
	end
end)

-- The test-place-only module exercises this controller in Studio. Absent from the playable build.
local playback = script.Parent:FindFirstChild("SilkPlayback")
if RunService:IsStudio() and playback and playback:IsA("ModuleScript") then
	task.spawn(function()
		local run: any = (require :: any)(playback)
		run({
			input = controls,
			drop = function() motor:requestDrop() end,
			jump = jump,
			motor = motor,
			camera = cam,
			place = function(position: Vector3)
				controls:clear()
				jump:drop(motor)
				motor:place(position, Vector3.yAxis, Vector3.zAxis)
				dropStrands(false)
				drawnUp = motor.up
				cam:snap()
			end,
			get = function()
				return { mode = motor.mode, line = motor.silk.mode, taut = motor.silk.taut, position = motor.pos, walking = motor.silk.walk ~= nil }
			end,
		})
	end)
end
