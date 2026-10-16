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
local SpiderEyes = require(script.Parent.SpiderEyes)
local SpiderHud = require(script.Parent.SpiderHud)
local WorldDetail = require(script.Parent.WorldDetail)
local Soundscape = require(script.Parent.Soundscape)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = Shared:WaitForChild("Movement")
local SupportMath = require(Movement:WaitForChild("SupportMath"))
local SpiderMotor = require(Movement:WaitForChild("SpiderMotor"))
local JumpInput = require(Movement:WaitForChild("JumpInput"))
local StickCarry = require(Movement:WaitForChild("StickCarry"))
local ControlText = require(Shared:WaitForChild("UI"):WaitForChild("ControlText"))
local Species = require(Shared:WaitForChild("Data"):WaitForChild("Species"))
local Surfaces = require(Shared:WaitForChild("Data"):WaitForChild("Surfaces"))
local Detail = require(Shared:WaitForChild("Data"):WaitForChild("Detail"))
local Layout = require(Shared:WaitForChild("Habitat"):WaitForChild("WindowsillLayout"))
local SpiderRig = require(Shared:WaitForChild("Rig"):WaitForChild("SpiderRig"))

local Sensor = require(Shared.Perception.Sensor)
local ObservationMemory = require(Shared.Perception.ObservationMemory)
local FocusState = require(Shared.Movement.FocusState)
local PerceptionStage = require(script.Parent.PerceptionStage)
local PerceptionHud = require(script.Parent.PerceptionHud)
local PreyDirector = require(Shared.Prey.PreyDirector)
local FlyBodies = require(script.Parent.FlyBodies)
local NeedsModel = require(Shared.Life.NeedsModel)
local LifeLoop = require(Shared.Life.LifeLoop)
local LifeText = require(Shared.UI.LifeText)
local DayLight = require(Shared.Habitat.DayLight)
local Checkpoint = require(Shared.Persistence.Checkpoint)
local CheckpointStore = require(Shared.Persistence.CheckpointStore)
local focusState = FocusState.new()
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
local carry: any = StickCarry.new()
-- Touch-only devices (phones, tablets) run the low tier until a real tablet frame-time check (ROBLOX_PORT.md): lighter fuzz and
-- no idle extras on the spider, fewer optional parts in the world. Workspace attribute Detail = "low" or "full" overrides the guess.
local detail = Detail.choose(UIS.TouchEnabled and not UIS.KeyboardEnabled, Workspace:GetAttribute("Detail"))
local rig = SpiderRig.new(Workspace, sill, nil, detail)
task.spawn(function()
	local roots: { Instance } = { Lighting }
	local decor = Workspace:WaitForChild("Decor", 10)
	if decor then table.insert(roots, decor) end
	local terrain = Workspace:FindFirstChild("Terrain")
	if terrain then table.insert(roots, terrain) end
	WorldDetail.apply(detail, roots)
end)
local hud = SpiderHud.new(player:WaitForChild("PlayerGui"))
local device: ControlText.Device = ControlText.initialDevice(UIS.TouchEnabled, UIS.KeyboardEnabled, UIS.GamepadEnabled)
local memory = ObservationMemory.new()
local sensor = Sensor.new(memory)
sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local sightCast = Sensor.workspaceCast(params)
local perceptionHud = PerceptionHud.new(player:WaitForChild("PlayerGui"))
local stage = if Workspace:GetAttribute("TestTarget") == true or (Workspace:GetAttribute("TestTarget") ~= false and script.Parent:FindFirstChild("SilkPlayback")) then PerceptionStage.new(sill) else nil
local prey = PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4)
local flyBodies = FlyBodies.new(Workspace)
local soundscape = Soundscape.new(Workspace)
-- LIFE (ROBLOX-24): the windowsill runs the life clock, so hunger runs by its hours (NeedsModel life mode, Standard rules: the
-- port has no Easy mode yet). Feeding grants into the same model. The loop keeps the rest, sleep, daylight and the eyes' reach.
local needs = NeedsModel.new(true, false)
prey.feeding.needs = needs
local life = LifeLoop.new(needs, nil)
-- S01-C retreat checkpoints (ROBLOX-25): resting in the crack, and each morning, keeps one; Backspace / View returns to it. The
-- store is DataStore-shaped but in memory only: a checkpoint lasts the session. No live DataStore is written.
local checkpointWorld: Checkpoint.World = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life }
local checkpoints = CheckpointStore.new(CheckpointStore.MemoryDataStore.new(), function(r: any): { string }
	return (Checkpoint.check(r, checkpointWorld))
end)
life.save = function(): LifeLoop.CheckpointResult
	local why = Checkpoint.boundaryProblem(checkpointWorld)
	if why ~= "" then return { ok = false, message = why } end
	local record, err = Checkpoint.capture(checkpointWorld, os.time())
	if not record then
		warn("[Windowsill] checkpoint: " .. tostring(err))
		return { ok = false, message = "this moment could not be recorded" }
	end
	local r = checkpoints:save(record)
	if not r.ok then warn("[Windowsill] checkpoint: " .. r.message .. ": " .. table.concat(r.errors, "; ")) end
	return { ok = r.ok, message = r.message }
end
local feedPending, cancelPending = false, false -- this frame's presses, for the next fixed tick (Godot's just_pressed)
local lifeSpider: LifeLoop.Spider = { inRetreat = false, attached = true, still = true, holding = false, feeding = false }
local dayClock: number? = nil -- the daytime ClockTime (SunPick's choice, read once from the server's Lighting)
local lastLight: number? = nil
local gripPress = false
local function focusActive(): boolean
	return focusState:active(false, player:GetAttribute("FocusToggle") == true, motor.mode == "attached")
end
local drawnUp = motor.up
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
-- The spider-eye picture (ROBLOX-20): field of view, colour, blur, retina strips, movement rings, UV layer, vignette. Presentation only.
local eyes: any = SpiderEyes.new({ parent = player:WaitForChild("PlayerGui"), camera = camera, player = player, cam = cam, sensor = sensor, params = params })

-- Everything held is dropped with no penalty and no message: focus loss, the Roblox menu, a text box, a lost controller.
local function dropAll()
	focusState:clear()
	jump:drop(motor)
	local release = motor.silk.release
	release.down, release.counts, release.held, release.progress = true, false, 0, 0
	motor:cancelWalk()
end

local function backToStart()
	focusState:clear()
	sensor:reset()
	memory:clear()
	jump:drop(motor)
	motor:respawn()
	dropStrands(false)
	drawnUp = motor.up
	cam:snap()
end

local controls: any -- bound below (SpiderInput.bind)

-- Backspace / View: back to the retreat checkpoint (the whole sill as it was), or to the start when there is none yet.
local function returnToCheckpoint()
	local best = checkpoints:loadBest()
	if not best.ok then
		backToStart()
		hud:toast(if best.message == "no checkpoint to return to" then "No checkpoint yet: back to the start. Rest in the silk-lined crack to keep one." else "Back to the start: " .. best.message, true)
		return
	end
	jump:drop(motor)
	local ok, problems = Checkpoint.restore(best.record, checkpointWorld)
	if not ok then
		warn("[Windowsill] checkpoint refused: " .. table.concat(problems, "; "))
		hud:toast("The checkpoint could not be used: " .. (problems[1] or "unknown"), true)
		return
	end
	controls:clear()
	focusState:clear()
	dropStrands(false)
	drawnUp = motor.up
	cam:snap()
	lastLight = nil -- the hour may have changed: set the light again
	feedPending, cancelPending = false, false
end

controls = SpiderInput.bind({
	focus = function(phase: string)
		if phase == "begin" then focusState:press(player:GetAttribute("FocusToggle") == true, motor.mode == "attached")
		elseif phase == "cancel" then focusState:clear() end
	end,
	feed = function()
		prey.feeding:press()
		feedPending = true -- in the crack, with nothing to eat, the same button rests (Godot's interact)
	end,
	jump = function(phase: string)
		if phase == "begin" and prey.feeding.struggling then prey.feeding:press(); gripPress=true; return end
		if gripPress then if phase ~= "begin" then gripPress=false end; return end
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
		cancelPending = true -- also ends a rest
		prey.feeding:cancel()
		if motor:cancelWalk() then return end
		focusState:cancel(jump:isBusy() or #jump.events > 0 or motor:onLine())
		jump:cancel()
	end,
	drop = function() motor:requestDrop() end,
	clear = dropAll,
	reset = function() returnToCheckpoint() end,
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
		-- Over a sharp edge the stick keeps carrying the spider the way it was going (Godot's carry), so holding forward
		-- never walks it straight back when the camera's idea of forward flips from floor to wall.
		local d = carry:step(r, f, cam:mapStick(r, f, motor.up), motor.transitionSerial, motor.intent, false)
		if d.Magnitude > 1e-6 then wish = d.Unit end
	else
		carry:step(0, 0, Vector3.zero, motor.transitionSerial, motor.intent, false)
	end
	local focusPoint: Vector3? = nil
	if focusState:active(controls.held.Focus == true, player:GetAttribute("FocusToggle") == true, motor.mode == "attached") then
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
		device = device, aiming = aiming, focus = controls.held.Focus == true or focusActive(), eyeView = cam.eyeView,
		status = {}, helpVisible = helpVisible, helpText = ControlText.helpCard(device),
		caption = eyes:captionView(device),
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
	view.grip = if prey.feeding.struggling then prey.feeding.grip else nil
	if prey.feeding.struggling then
		table.insert(view.status, "Caught — tap " .. ControlText.name(device,"jump") .. " to keep your grip")
	elseif prey.feeding.feeding then table.insert(view.status, "Feeding — move to stop")
	elseif prey.feeding.held then table.insert(view.status, "Meal paused — " .. ControlText.name(device,"feed") .. " to eat") end
	local clock = life.clock
	view.day = LifeText.day(clock.day, clock:partOfDay())
	view.dayLine = LifeText.line(clock:partOfDay(), needs.energy, needs:isStarving(), needs.gentle, LifeLoop.HUNGRY_AT)
	view.notice = if life.noticeSeconds > 0 and life.notice ~= "" then life.notice else nil
	local canRest = life:canRest(lifeSpider)
	local restPrompt = LifeText.prompt(life.asleep, life.resting, canRest, clock:isSleepTime(), device)
	if focusState.latched then table.insert(view.status, "FOCUS ON    " .. ControlText.name(device,"focus") .. " again to stop" .. (if not jump:isBusy() and not motor:onLine() and not motor.silk.walk then " / " .. ControlText.name(device,"cancel") else "")) end
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
	elseif restPrompt and not aiming then
		view.prompt = { title = restPrompt.title, hint = restPrompt.hint }
	elseif motor.mode == "attached" and not aiming and (helpVisible or os.clock() - started < WALK_HINT_SECONDS) then
		view.prompt = { hint = ControlText.walkHint(device) }
	end
	if os.clock() > helpUntil and helpVisible then helpVisible = false end
	local restLabel = LifeText.touchLabel(life.asleep, life.resting, canRest, clock:isSleepTime())
	controls:setTouchVisible("Feed", prey.feeding.held ~= nil or restLabel ~= nil)
	controls:setTouchLabel("Feed", if prey.feeding.held ~= nil then "Eat" else restLabel or "Eat")
	controls:setTouchLabel("Jump", if prey.feeding.struggling then "Grip" else "Jump")
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
			local percepts = prey:percepts()
			if stage then
				local p = stage.target:percept()
				if p then table.insert(percepts,p) end
			end
			sensor:step(DT,motor:observer(),percepts,sightCast)
			prey:before(DT,motor.pos,motor:observer(),sensor,sightCast,camera)
			jump:step(motor)
			local input = tickInput()
			motor:tick(input)
			prey.feeding.auto = player:GetAttribute("AutomaticGrip") == true
			prey:after(DT,motor,sensor,sightCast)
			-- The life loop runs last in the tick (Godot's habitat loop, priority 12); the reach it sets is the next tick's.
			local holding = prey.feeding.held ~= nil
			lifeSpider = {
				inRetreat = Layout.inRetreat(motor.pos), attached = motor.mode == "attached" and not motor.preparing,
				still = input.wish.Magnitude < 0.01 and motor.vel.Magnitude < 0.15,
				holding = holding, feeding = holding and prey.feeding.feeding,
			}
			life:step(DT, lifeSpider, feedPending, cancelPending)
			feedPending, cancelPending = false, false
			sensor.core.rangeScale = life.rangeScale
			life:drainEvents() -- the screen reads the loop's state and notices; the events are for tests and later rounds
			if motor.mode ~= "attached" then focusState:clear() end
			if stage then stage.target:step(DT); stage.marker.Position = stage.target.position end
			cam:tick(DT)
		end
	end
	-- The light of the hour (DayLight; the eyes' reach comes from the clock, not from this). The daytime sun is the one the
	-- server picked, read once it has arrived (or after a few seconds without it).
	if dayClock == nil and (Lighting:GetAttribute("SunPick") ~= nil or os.clock() - started > 5) then dayClock = Lighting.ClockTime end
	local dc = dayClock
	if dc and DayLight.due(lastLight, life.daylight) then
		DayLight.apply(Lighting, DayLight.targets(life.daylight, dc), Workspace:FindFirstChild("Decor"))
		lastLight = life.daylight
	end
	-- Drawn frame: the up vector eases so walls and edges do not snap.
	local simFrame = frameDt * (if slow then SLOW_SPEED else 1)
	drawnUp = drawnUp:Lerp(motor.up, 1 - math.exp(-24 * simFrame)).Unit
	local body = SupportMath.bodyCFrame(motor.pos, drawnUp, motor.heading)
	rig:update(body, simFrame, motor.mode == "attached", motor.moving)
	updateHud(frameDt)
	flyBodies:draw(prey.flies,prey.now)
	soundscape:update(frameDt, prey, life.daylight, GuiService.MenuIsOpen, if slow then SLOW_SPEED else 1, player:GetAttribute("SoundMuted") == true)
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
	-- The Focus that feeds the perception HUD also decides how far the principal eyes are in use (the eye view's picture). The
	-- picture sets the field of view, so it comes before the HUD projects anything.
	local focusing = motor.mode == "attached" and (controls.held.Focus == true or focusActive())
	eyes:update(frameDt, focusing)
	perceptionHud:draw(memory,camera,sightCast,focusing,player:GetAttribute("ShowLastSeen") ~= false)
	-- Depth of field: on the spider in third person; in the eye view SpiderEyes owns it and focuses on what is looked at.
	local dof = Lighting:FindFirstChild("MacroDOF")
	if not cam.eyeView and dof and dof:IsA("DepthOfFieldEffect") then
		dof.FocusDistance = (camera.CFrame.Position - motor.pos).Magnitude
	end
end)

-- The test-place-only module exercises this controller in Studio. Absent from the playable build.
local playback = script.Parent:FindFirstChild("SilkPlayback")
if RunService:IsStudio() and playback and playback:IsA("ModuleScript") then
	task.spawn(function()
		local run: any = (require :: any)(playback)
		run({
			prey = prey, flyBodies = flyBodies, life = life, needs = needs, checkpoints = checkpoints, returnToCheckpoint = function() returnToCheckpoint() end, lifeSpider = function() return lifeSpider end, sensor = sensor, memory = memory, focusState = focusState, perceptionHud = perceptionHud, stage = stage,
			input = controls,
			drop = function() motor:requestDrop() end,
			jump = jump,
			motor = motor,
			camera = cam,
			sill = sill,
			setDevice = function(name: ControlText.Device) device = name end,
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
