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
-- The peacock spider (ROBLOX-31): resting in the crack, C (RB / R1, the touch Change button) turns the spider into the other one (the first
-- spider or the peacock spider, Maratus volans); as the peacock spider, standing still, X (RB / R1, Dance) starts its courtship dance and any move,
-- jump or Cancel stops it. The dance is a pose of the drawn rig only; the motor, senses, silk and the rest are the same for both.
-- The ant-mimicking spider (ROBLOX-64) is the third in the crack's cycle: standing still, legs I rise as antennae and wave by themselves, X (RB / R1,
-- Wave) makes them higher and faster; walking, its drawn body yaws and sways along the distance walked. Again drawn only: the motor never knows.
-- The naturalist's notebook (ROBLOX-37): N, the Notebook button beside Menu, or "Notebook" in the life menu and on the end screen opens it
-- and the world waits. The book is the player's: it lives here, outside the world and its checkpoints, so a return to a rest never erases a
-- page and a new, unrelated spider opens the same book. NotebookWatch opens pages from the events this loop already has.
-- Saving (ROBLOX-39): the server owns the DataStore. This script only says hello, applies what the server sends back (the notebook, an Easy
-- unlock, the chosen spider, the settings, the last rests) and sends its own progress and rests up (Client/SaveClient). With no server reply
-- it is the session-only game it was before, and the menu says saving is off.

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
local CaughtPanel = require(script.Parent.CaughtPanel)
local WorldDetail = require(script.Parent.WorldDetail)
local Soundscape = require(script.Parent.Soundscape)
local OldSkins = require(script.Parent.OldSkins)
local skins = OldSkins.new(Workspace)

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
local WaspBody = require(script.Parent.WaspBody)
local NeedsModel = require(Shared.Life.NeedsModel)
local LifeLoop = require(Shared.Life.LifeLoop)
local Growth = require(Shared.Life.Growth)
local LifeSession = require(Shared.Life.LifeSession)
local session = LifeSession.new()
local RivalSpider = require(Shared.Predator.RivalSpider)
local LifeText = require(Shared.UI.LifeText)
local DayLight = require(Shared.Habitat.DayLight)
local LifeClock = require(Shared.Life.LifeClock)
local WaspDirector = require(Shared.Predator.WaspDirector)
local WaspText = require(Shared.UI.WaspText)
local SpiderChoice = require(Shared.Rig.SpiderChoice)
local PeacockDance = require(Shared.Rig.PeacockDance)
local PeacockText = require(Shared.UI.PeacockText)
local NotebookPages = require(Shared.Data.NotebookPages)
local FieldNotebook = require(Shared.Learning.FieldNotebook)
local NotebookWatch = require(Shared.Learning.NotebookWatch)
local NotebookText = require(Shared.UI.NotebookText)
local NotebookPanel = require(script.Parent.NotebookPanel)
local HudLayout = require(Shared.UI.HudLayout)
local SettingsPanel = require(script.Parent.SettingsPanel)
local SettingsSpec = require(Shared.Data.SettingsSpec)
local Checkpoint = require(Shared.Persistence.Checkpoint)
local CheckpointStore = require(Shared.Persistence.CheckpointStore)
local SaveRules = require(Shared.Data.SaveRules)
local SaveProgress = require(Shared.Persistence.SaveProgress)
local SaveText = require(Shared.UI.SaveText)
local SettingsModel = require(Shared.UI.SettingsModel)
local SaveClient = require(script.Parent.SaveClient)
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
-- A setting's value now (ROBLOX-49): the Player attribute of its name if it holds a clean value, else the default. Every consumer below reads
-- its setting here each frame, so a change in the settings panel (or a saved one arriving) takes effect at once.
local function setting(id: string): any
	return SettingsModel.get(function(key: string): any return player:GetAttribute(key) end, id)
end
-- Solo windowsill: the default player list obscures the life-menu button on small screens.
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
local camera = Workspace.CurrentCamera
local sill = Workspace:WaitForChild("Windowsill")
local Breakaway = require(Shared.Habitat.Breakaway)
local breakaway = Breakaway.new(sill,Workspace:FindFirstChild("Decor"))
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
-- Which spider: the Player attribute Appearance (kept for the session), else the Workspace attribute Appearance, else the first spider.
local appearance = SpiderChoice.start(player:GetAttribute("Appearance"), Workspace:GetAttribute("Appearance"))
local rig = SpiderRig.new(Workspace, sill, appearance, detail)
-- The rival's legs (ROBLOX-69): its own SpiderMotor over the whole sill, made when it first arrives, and its drawn rig. One table: the client is at Luau's limit of 200 locals.
local rivalLegs: any = { drive = nil, rig = nil, Drive = require(Shared.Predator.RivalDrive) }
local dance = PeacockDance.new() -- the peacock spider's courtship dance (a pose for the rig; nothing else reads it)
local dancePose: any = nil
-- The ant-mimicking spider's antennae and drawn walk (a pose for the rig; nothing else reads it): the modules, the state, its latest pose, and where
-- the spider was last frame (the distance walked drives the drawn wobble). One table: the client is at Luau's limit of 200 locals.
local ant: any = { Pose = require(Shared.Rig.AntMimicPose), Text = require(Shared.UI.AntMimicText), state = nil, pose = nil, last = nil }
ant.state = ant.Pose.new()
local bodyHidden = false
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
-- PlayStation or Xbox button names (ControlText.setPadStyle): Roblox names ButtonA "ButtonCross" on a PlayStation controller.
local function refreshPadStyle()
	local ok, text = pcall(function() return UIS:GetStringForKeyCode(Enum.KeyCode.ButtonA) end)
	ControlText.setPadStyle(ControlText.padStyleFor(if ok then text else nil))
end
refreshPadStyle()
local memory = ObservationMemory.new()
local sensor = Sensor.new(memory)
-- The naturalist's notebook (ROBLOX-37): the player's own, never part of the world, a checkpoint or a life. The watcher opens its pages.
local book: any = FieldNotebook.new()
local watch: any = NotebookWatch.new(book)
memory.categoryChanged:connect(function(_contact: any, _old: string, new: string) watch:onCategory(new) end)
sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local sightCast = Sensor.workspaceCast(params)
local perceptionHud = PerceptionHud.new(player:WaitForChild("PlayerGui"))
local stage = if Workspace:GetAttribute("TestTarget") == true or (Workspace:GetAttribute("TestTarget") ~= false and script.Parent:FindFirstChild("SilkPlayback")) then PerceptionStage.new(sill) else nil
local prey = PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4, true)
local flyBodies = FlyBodies.new(Workspace)
local soundscape = Soundscape.new(Workspace)
local waspBody = WaspBody.new(Workspace)
-- LIFE (ROBLOX-24): the windowsill runs the life clock, so hunger runs by its hours (NeedsModel life mode, Standard rules: the
-- port has no Easy mode yet). Feeding grants into the same model. The loop keeps the rest, sleep, daylight and the eyes' reach.
local needs = NeedsModel.new(true, false)
needs.drainScale=NeedsModel.PLAY_DRAIN
prey.feeding.needs = needs
local life = LifeLoop.new(needs, nil)
-- The mud dauber wasp (ROBLOX-26): a port of Godot's wasp director (Shared/Predator/WaspDirector). It visits by day from the second day,
-- once the first meal is eaten, and not while the spider rests; it is heard (a caption with its direction) for 8 s before it can look.
-- It reads the sill through the same casts as the senses. In the test place it never comes by itself (Workspace attribute Wasp = true
-- allows it); the attribute WaspForce = a place id ("floor_middle") brings it at once, for Studio and playtests. There is no Gentle
-- mode in Roblox yet, so a catch is always a catch.
local testPlace = script.Parent:FindFirstChild("SilkPlayback") ~= nil
local wasp: any = WaspDirector.new({
	seed = 914, enabled = not testPlace,
	world = {
		ray = function(a: Vector3, b: Vector3): boolean return Workspace:Raycast(a, b - a, params) ~= nil end,
		clear = function(a: Vector3, b: Vector3, radius: number): boolean return Workspace:Spherecast(a, radius, b - a, params) == nil end,
		inRetreat = function(p: Vector3): boolean return Layout.inRetreat(p) end,
	},
})
local waspSpider: WaspDirector.Spider = { position = Vector3.zero, velocity = Vector3.zero, walkSpeed = Species.phidippus_audax_prototype.locomotion.walk_speed_wu_s, airborne = false, falling = false }
local menu: any = nil
local initialRecord: any = nil
local menuStarted = false
local panel: any = nil -- the catch screen, made below once returnToCheckpoint exists
local nbPanel: any = nil -- the notebook, made below with the menus
local settingsPanel: any = nil -- the settings (ROBLOX-49), made below with the menus
local saveClient: any = nil -- persistent saves (ROBLOX-39), made below with the menus
-- Whether a modal screen has the game: the world waits and the controls belong to it. At the very start the world also waits (a second or
-- so at most) for the server to say what is saved, so the start menu shows the right choices; not in the test place unless the Workspace attribute SaveWait is true.
local function modal(): boolean
	return panel:isShowing() or menu:isShowing() or nbPanel:isShowing() or settingsPanel:isShowing()
		or (not menuStarted and (not testPlace or Workspace:GetAttribute("SaveWait") == true) and saveClient ~= nil and saveClient:waiting() == true)
end
-- S01-C retreat checkpoints (ROBLOX-25): resting in the crack, and each morning, keeps one; Backspace / View returns to it. The
-- store is DataStore-shaped but in memory only: a checkpoint lasts the session. No live DataStore is written.
local checkpointWorld: Checkpoint.World = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life, wasp = wasp, breakaway = breakaway }
local function newStore(): any
	return CheckpointStore.new(CheckpointStore.MemoryDataStore.new(), function(r: any): { string } return (Checkpoint.check(r, checkpointWorld)) end)
end
local stores = {main=newStore(), free=newStore()}
local checkpoints = stores.main
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
	if r.ok and saveClient ~= nil then saveClient:sendRest(if checkpoints == stores.free then "free" else "main", record) end
	return { ok = r.ok, message = r.message }
end
local feedPending, cancelPending = false, false -- this frame's presses, for the next fixed tick (Godot's just_pressed)
local lifeSpider: LifeLoop.Spider = { inRetreat = false, attached = true, still = true, holding = false, feeding = false }
local dayClock: number? = nil -- the daytime ClockTime (SunPick's choice, read once from the server's Lighting)
local lastLight: number? = nil
local gripPress = false
local function focusActive(): boolean
	return focusState:active(false, setting("FocusToggle") == true, motor.mode == "attached")
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
  cameraScale = (rig._appearance.cameraScale or 1)*math.sqrt(rig._growth),
	}
end, function(on: boolean)
	rig:setEyeView(on)
end)
cam.hide = function(hidden: boolean)
	bodyHidden = hidden
	rig:setBodyHidden(hidden)
end
jump.onAim = function(on: boolean)
	cam:setAiming(on)
end
-- The spider-eye picture (ROBLOX-20): field of view, colour, blur, retina strips, movement rings, UV layer, vignette. Presentation only.
local eyes: any = SpiderEyes.new({ parent = player:WaitForChild("PlayerGui"), camera = camera, player = player, cam = cam, sensor = sensor, params = params })

-- The display key's pose (the peacock's dance, the ant mimic's raised antennae) ends at once: a step, a jump, a rest, a drop, a menu.
function ant.stopDisplay()
	dance:stop()
	ant.state:stop()
end

-- Everything held is dropped with no penalty and no message: focus loss, the Roblox menu, a text box, a lost controller.
local function dropAll()
	ant.stopDisplay()
	focusState:clear()
	jump:drop(motor)
	local release = motor.silk.release
	release.down, release.counts, release.held, release.progress = true, false, 0, 0
	motor:cancelWalk()
end

local function backToStart()
	ant.stopDisplay()
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
local camSettings: any = {} -- the camera's settings, filled each frame (see the render step)

-- Choosing the spider (ROBLOX-31): only while resting awake in the silk-lined crack. The drawn rig is built again with the other appearance;
-- the gait, the eye view and the hidden body carry over; the choice is kept in the Player attribute Appearance for the session.
local function canChange(): boolean
	return life.resting and not life.asleep and not life.growth:isMoulting()
end
local appearanceTouched = false -- the player chose a spider this visit (only then is the choice sent to be saved)
local function setAppearance(id: string)
	appearance = id
	player:SetAttribute("Appearance", appearance)
	dance:stop()
	dance = PeacockDance.new()
	dancePose = nil
	ant.state, ant.pose, ant.last = ant.Pose.new(), nil, nil
	local old = rig
	rig = SpiderRig.new(Workspace, sill, appearance, detail)
	rig.gaitMode = old.gaitMode
	rig:setEyeView(cam.eyeView)
	rig:setBodyHidden(bodyHidden)
	old:destroy()
end
local function changeSpider()
	if not canChange() then
		hud:toast(PeacockText.NOT_RESTING, false)
		return
	end
	setAppearance(SpiderChoice.next(appearance))
	appearanceTouched = true
	if saveClient ~= nil then saveClient:markDirty() end
	hud:toast(PeacockText.changed(appearance), false)
end
-- X / RB / the Dance (Wave) button: the peacock spider starts its courtship dance or ends it; the ant mimic raises its antennae higher or lets them
-- go. On a controller RB in the crack changes spider instead (one button for both, as the crack and the open sill never overlap). The first
-- spider has no display.
local function toggleDance()
	if life.resting then
		if device == "gamepad" and not life.asleep then changeSpider() end
		return
	end
	local kind = SpiderChoice.displayKind(appearance)
	if kind == nil then return end
	local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not jump:isBusy() and motor.silk.walk == nil
	if kind == "antennae" then
		if ant.state:displaying() then
			ant.state:stop()
		elseif not ant.state:start(standing, motor.moving) then
			hud:toast(ant.Text.STAND, false)
		end
		return
	end
	if dance:showing() and dance.active then
		dance:stop()
		return
	end
	if not dance:start(standing, motor.moving) then
		hud:toast(PeacockText.STAND, false)
	else
		book:notice("dance")
	end
end

-- Backspace / View: back to the retreat checkpoint (the whole sill as it was), or to the start when there is none yet.
local function returnToCheckpoint()
	local best = checkpoints:loadBest()
	if not best.ok then
		backToStart()
		hud:toast(if best.message == "no checkpoint to return to" then "No checkpoint yet: back to the start. Rest in the silk-lined crack to keep one." else "Back to the start: " .. best.message, true)
		return
	end
	jump:drop(motor)
	ant.stopDisplay()
	local ok, problems = Checkpoint.restore(best.record, checkpointWorld)
	if not ok then
		warn("[Windowsill] checkpoint refused: " .. table.concat(problems, "; "))
		hud:toast("The checkpoint could not be used: " .. (problems[1] or "unknown"), true)
		return
	end
	session.mode, session.rules, session.ended = life.mode or "main", life.rules or "standard", false
 needs.drainScale=NeedsModel.PLAY_DRAIN
 motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
 session:finishAdult(life.growth.stage)
	session.summary = nil
	controls:clear()
	focusState:clear()
	dropStrands(false)
	drawnUp = motor.up
	cam:snap()
	lastLight = nil -- the hour may have changed: set the light again
	feedPending, cancelPending = false, false
	watch:resync() -- the world changed under the watcher: it only takes a fresh look
end

-- Player progress is session-only and outside checkpoints. Modes have independent rest stores.
local function setHudShown(shown: boolean)
 hud.safe.Enabled=shown;hud.centre.Enabled=shown
 local touch=player:WaitForChild("PlayerGui"):FindFirstChild("SpiderTouch")
 if touch and touch:IsA("ScreenGui") then touch.Enabled=shown and UIS.TouchEnabled end
end
local function applyRules()
 life.mode,life.rules=session.mode,session.rules
 needs.drainScale=NeedsModel.PLAY_DRAIN
 needs.gentle=session.rules=="gentle";wasp.gentle=needs.gentle
end
local function closeScreens()
 panel:hide();menu:hide();setHudShown(true);controls:clear();dropAll()
end
local function fresh(mode: string, easy: boolean, position: Vector3?): boolean
 if not initialRecord or (easy and not session.finishedMain) then return false end
 local ok=Checkpoint.restore(initialRecord,checkpointWorld)
 if not ok then return false end
 session:begin(mode,easy);applyRules();motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
 sensor:reset();memory:clear()
 stores[mode]=newStore();checkpoints=stores[mode]
 life.resting=false;life.notice="";life.noticeSeconds=0;life.restoreGrace=0
 wasp:load(WaspDirector.defaultRecord());wasp.gentle=needs.gentle
 if position then motor:place(position,Vector3.yAxis,Layout.SPAWN_HEADING) end
 closeScreens();dropStrands(false);drawnUp=motor.up;cam:snap();lastLight=nil
 feedPending,cancelPending=false,false
 watch:resync()
 return true
end
local function continueAnother()
 local spot=session:another()
 if not spot then return end
 local mode,easy=session.mode,session.rules=="gentle"
 if fresh(mode,easy,spot) then
  life:showNotice("Another young spider, somewhere new on the sill. It is not related to the last.")
  life.noticeSeconds=12
 end
end
local function summaryRecord(cause: string): any
 return {cause=cause,hours=math.max((life.clock.day-1)*24+life.clock.hour-LifeClock.START_H,0),
  meals=prey.feeding.mealsFinished,wasp_visits=wasp.visits,wasp_escapes=wasp.escapes,stage=life.growth.stage}
end
local openNotebook: (string?) -> ()
local lastEnd: any=nil -- the summary of the life that just ended, while its end screen is up
panel=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Notebook" then openNotebook("end")
 elseif choice=="Another" then lastEnd=nil;continueAnother()
 elseif choice=="Back" then lastEnd=nil;closeScreens();wasp:clearVisit();returnToCheckpoint() end
end)
local function presentEnd(immediate: boolean)
 local rec=lastEnd
 if not rec then return end
 local cause=rec.cause
 local choices: {CaughtPanel.Choice}={}
 if checkpoints:loadBest().ok then table.insert(choices,{id="Back",text="Back to your last rest"}) end
 table.insert(choices,{id="Another",text="Continue as another spider"})
 table.insert(choices,{id="Notebook",text=NotebookText.MENU_CHOICE})
 panel:showChoices(if cause=="starved" then "The spider starved." elseif cause=="rival" then "The other spider caught you." else WaspText.LINE,
  if cause=="starved" then "It went too long without food." elseif cause=="rival" then "A hunter can become prey. You can return to your last rest." else WaspText.SUB,
  WaspText.summary(rec.hours,rec.meals,rec.wasp_visits,rec.wasp_escapes),choices,immediate)
 panel:setTextScale(if setting("LargeText")==true then 1.5 else 1)
end
local function endLife(cause: string)
 local rec=summaryRecord(cause)
 if not session:endLife(cause,rec) then return end
 controls:clear();dropAll();setHudShown(false)
 lastEnd=rec
 presentEnd(false)
end
local function showCaught() endLife("wasp") end
local openMenu: () -> ()
local openSettings: (string?) -> ()
local confirming: string?=nil
menu=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Notebook" then openNotebook("menu");return end
 if choice=="Notes" then player:SetAttribute("NotebookNotes",not setting("NotebookNotes"));openMenu();return end
 if choice=="Settings" then openSettings("menu");return end
 if choice=="Resume" then closeScreens();return end
 if choice=="Continue" then checkpoints=stores.main;closeScreens();returnToCheckpoint();return end
 if choice=="Free" then
  local saved=stores.free:loadBest()
  if saved.ok then checkpoints=stores.free;closeScreens();returnToCheckpoint()
  else fresh("free",false,nil) end
  return
 end
 if choice=="Large" then
  player:SetAttribute("LargeText",not setting("LargeText"));openMenu();return
 end
 if choice=="New" or choice=="Easy" then
  if session.started and confirming~=choice then
   confirming=choice
   menu:showChoices("Begin a new life?","This replaces the main life's last rest as soon as the new spider rests.","",
    {{id=choice :: string,text="Begin the new life"},{id="CancelNew",text="Keep this life"}},true)
   return
  end
  confirming=nil;session:archive();fresh("main",choice=="Easy",nil);return
 end
 confirming=nil;openMenu()
end,"SpiderLifeMenu")
-- The start menu's body: the saving line, then the Easy note. Also rewritten in place when the saving status changes under an open menu.
local function menuBody(): string
 return SaveText.menuLine(saveClient:status())..(if session.finishedMain then "" else "\nEasy is not available yet; choose Free play for gentle rules.")
end
openMenu=function()
 if panel:isShowing() or not initialRecord then return end
 controls:clear();dropAll();setHudShown(false)
 local choices: {CaughtPanel.Choice}={}
 if session.started then table.insert(choices,{id="Resume",text="Resume this spider"}) end
 if stores.main:loadBest().ok then table.insert(choices,{id="Continue",text="Continue from last rest"}) end
 table.insert(choices,{id="New",text="Begin a new life"})
 if session.finishedMain then table.insert(choices,{id="Easy",text="Begin a new life on Easy"}) end
 table.insert(choices,{id="Free",text="Free play - gentle rules"})
 table.insert(choices,{id="Notebook",text=NotebookText.MENU_CHOICE})
 table.insert(choices,{id="Notes",text=if setting("NotebookNotes") then "Discovery notes: on" else "Discovery notes: off"})
 table.insert(choices,{id="Settings",text=SettingsSpec.WORDS.menuChoice})
 table.insert(choices,{id="Large",text=if setting("LargeText")==true then "Text size: large" else "Text size: normal"})
 menu:showChoices("The Windowsill","A small life on a windowsill.",
  menuBody(),choices,true)
 menu:setTextScale(if setting("LargeText")==true then 1.5 else 1)
end
local menuButton=Instance.new("TextButton")
menuButton.Name="LifeMenu";menuButton.Text="Menu";menuButton.TextSize=18
menuButton.BackgroundColor3=Color3.new(.12,.12,.14);menuButton.TextColor3=Color3.new(1,1,1)
menuButton.Parent=hud.safe;menuButton.Activated:Connect(openMenu)

-- The naturalist's notebook (ROBLOX-37). Opened from the game (N, the button beside Menu), the life menu or the end screen; closing it
-- goes back to wherever it was opened from. The world waits while it is open (modal()).
local function noteScale(): number
 return if setting("LargeText")==true then NotebookText.LARGE else 1
end
nbPanel=NotebookPanel.new(player:WaitForChild("PlayerGui"),book,function(to: string?)
 if to=="menu" then openMenu()
 elseif to=="end" then presentEnd(true)
 else setHudShown(true) end
end)
openNotebook=function(to: string?)
 if nbPanel:isShowing() then return end
 if to=="menu" then menu:hide()
 elseif to=="end" then panel:hide()
 elseif modal() then return
 else controls:clear();dropAll();setHudShown(false) end
 hud:setNote("",0)
 nbPanel:open(to,device,noteScale())
end
book.pageOpened:connect(function(id: string)
 local page=book:view(id)
 if nbPanel:isShowing() then nbPanel:refresh() end
 if page and setting("NotebookNotes") then hud:setNote(NotebookText.note(page.title,device),NotebookPages.noteSeconds) end
end)
local notebookButton=Instance.new("TextButton")
notebookButton.Name="NotebookButton";notebookButton.Text=NotebookText.BUTTON;notebookButton.TextSize=16
notebookButton.BackgroundColor3=Color3.new(.12,.12,.14);notebookButton.TextColor3=Color3.new(1,1,1)
notebookButton.Parent=hud.safe;notebookButton.Activated:Connect(function() openNotebook("game") end)
-- Both buttons are touch targets (48 px tall) and clear of the status lines at every screen size (HudLayout.topLayout, tested).
local function placeTopButton(button: TextButton,r: HudLayout.Rect)
 button.Position=UDim2.fromOffset(r.x0,r.y0);button.Size=UDim2.fromOffset(r.x1-r.x0,r.y1-r.y0)
end
local function placeTopButtons()
 local size=hud.safe.AbsoluteSize
 local t=HudLayout.topLayout(size.X,size.Y)
 placeTopButton(menuButton,t.menu);placeTopButton(notebookButton,t.notebook)
end
hud.safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTopButtons)
placeTopButtons()

-- The settings (ROBLOX-49). Opened from the life menu or with O; closing it goes back to wherever it was opened from. The world waits while
-- it is open (modal()). The values live as Player attributes named by SettingsSpec ids (the panel asks setting(), tells player:SetAttribute),
-- so the saving that already watches them (below) keeps them and every consumer in this script reads them live.
settingsPanel=SettingsPanel.new(player:WaitForChild("PlayerGui"),{
 get=function(id: string): any return setting(id) end,
 set=function(id: string,value: any) player:SetAttribute(id,value) end,
 reset=function() for _,id in SettingsModel.ids() do player:SetAttribute(id,SettingsModel.default(id)) end end,
 status=function(): string? local status=saveClient:status();return status end,
},function(to: string?)
 if to=="menu" then openMenu() else setHudShown(true) end
end)
openSettings=function(to: string?)
 if settingsPanel:isShowing() then return end
 if to=="menu" then menu:hide()
 elseif modal() then return
 else controls:clear();dropAll();setHudShown(false) end
 hud:setNote("",0)
 settingsPanel:open(to,device,noteScale())
end

-- ---------------------------------------------------------------- persistent saves (ROBLOX-39)
-- What this visit changed is sent up (the notebook and an adult life always; the spider and the toggles only if the player changed them, so
-- a late reply can never be overwritten by defaults). What the server sends down is applied once, before the start menu, and again if a
-- retry succeeds later: the notebook and the adult life are only ever added to, the rest of the choices only if the player has not already
-- made their own this visit.
local prefTouched: { [string]: boolean } = {}
local applyingSaved = false
local savedStatus: string? = nil
local savedReason: string? = nil
local lastSig = ""
local lastEye = 0.0
local lastEyeCheck = os.clock()
local function refreshMenu()
	if menuStarted and menu:isShowing() and confirming == nil then openMenu() end
end
local function progressSnapshot(): any
	local settings: { [string]: any } = {}
	for key in prefTouched do settings[key] = player:GetAttribute(key) end -- (the snapshot sends only what is clean)
	return SaveProgress.snapshot(book:toRecord(), session.finishedMain, if appearanceTouched then appearance else nil, settings)
end
local function adoptRest(mode: string, record: any)
	if record == nil or (mode ~= "main" and mode ~= "free") then return end
	if session.started or stores[mode]:loadBest().ok then return end -- this visit has begun, or already has a rest of its own
	local r = stores[mode]:save(record)
	if not r.ok then warn("[Windowsill] saved " .. mode .. " rest not used: " .. r.message .. ": " .. table.concat(r.errors, "; ")) end
end
local function applySaved(msg: any)
	if type(msg) ~= "table" then return end
	local _, p = SaveProgress.sanitize(msg.progress)
	if p then
		local mine = book:toRecord()
		local ids: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, list in { mine.opened, p.notebook.opened } do
			for _, id in list do
				if not seen[id] then seen[id] = true; table.insert(ids, id) end
			end
		end
		book:load({ opened = ids, eye_seconds = math.max(mine.eye_seconds, p.notebook.eye_seconds) })
		if p.finished_main then session.finishedMain = true end
		applyingSaved = true
		for key, v in p.settings do
			if not prefTouched[key] then player:SetAttribute(key, v) end
		end
		applyingSaved = false
		if p.appearance ~= nil and not appearanceTouched and p.appearance ~= appearance and SpiderChoice.start(p.appearance, nil) == p.appearance then
			setAppearance(p.appearance)
		end
	end
	if type(msg.rests) == "table" then
		adoptRest("main", msg.rests.main)
		adoptRest("free", msg.rests.free)
	end
	lastSig = `{#book.opened}:{session.finishedMain}`
	lastEye = book.eyeSeconds
	if nbPanel:isShowing() then nbPanel:refresh() end
	if settingsPanel:isShowing() then settingsPanel:refresh() end
	if not setting("ControlHints") and helpUntil ~= math.huge then helpVisible = false end
	refreshMenu()
end
saveClient = SaveClient.new({
	rules = SaveRules, now = os.clock,
	findRemotes = function(): any
		local folder = ReplicatedStorage:FindFirstChild(SaveRules.REMOTES_NAME)
		if folder == nil then return nil end
		local toServer, toClient = folder:FindFirstChild("ToServer"), folder:FindFirstChild("ToClient")
		if toServer == nil or toClient == nil then return nil end
		return { server = toServer, client = toClient }
	end,
	onLoaded = applySaved,
	onRest = function(mode: string, record: any) adoptRest(mode, record) end,
	onStatus = function(_status: string, _reason: string?) end, -- (the status is read each frame below)
	build = progressSnapshot,
})
lastSig = `{#book.opened}:{session.finishedMain}`
for _, key in SettingsModel.ids() do
	player:GetAttributeChangedSignal(key):Connect(function()
		if applyingSaved then return end
		prefTouched[key] = true
		saveClient:markDirty()
	end)
end
-- Each frame: the connection, what changed, and the status (a toast when it changes, a fresh menu line).
local function updateSaves()
	saveClient:update()
	local sig = `{#book.opened}:{session.finishedMain}`
	if sig ~= lastSig then
		lastSig = sig
		saveClient:markDirty()
	end
	local t = os.clock()
	if t - lastEyeCheck >= SaveRules.CLIENT_EYE_GAP then
		lastEyeCheck = t
		if book.eyeSeconds ~= lastEye then
			lastEye = book.eyeSeconds
			saveClient:markDirty()
		end
	end
	local status, reason = saveClient:status()
	if status ~= nil and (status ~= savedStatus or reason ~= savedReason) then
		local text = SaveText.toast(savedStatus, savedReason, status, reason)
		savedStatus, savedReason = status, reason
		if text ~= "" then hud:toast(text, status == "session") end
		if menuStarted and menu:isShowing() and confirming == nil then menu.summary.Text = menuBody() end
	end
end

controls = SpiderInput.bind({
	blocked = modal,
	menu = function() if settingsPanel:isShowing() then settingsPanel:close() elseif nbPanel:isShowing() then nbPanel:close() elseif menu:isShowing() and session.started then closeScreens() else openMenu() end end,
	notebook = function() openNotebook("game") end,
	settings = function() openSettings("game") end,
	focus = function(phase: string)
		if phase == "begin" then focusState:press(setting("FocusToggle") == true, motor.mode == "attached")
		elseif phase == "cancel" then focusState:clear() end
	end,
	choose = function() changeSpider() end,
	display = function() toggleDance() end,
	feed = function()
		ant.stopDisplay()
		prey.feeding:press()
		feedPending = true -- in the crack, with nothing to eat, the same button rests (Godot's interact)
	end,
	jump = function(phase: string)
  if life.growth:isMoulting() then return end
		if phase == "begin" and prey.feeding.struggling then prey.feeding:press(); gripPress=true; return end
		if gripPress then if phase ~= "begin" then gripPress=false end; return end
		if phase == "begin" then
			ant.stopDisplay() -- a jump (a hop or an aim) ends the dance or the raised antennae
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
		ant.stopDisplay()
		cancelPending = true -- also ends a rest
		prey.feeding:cancel()
		if motor:cancelWalk() then return end
		focusState:cancel(jump:isBusy() or #jump.events > 0 or motor:onLine())
		jump:cancel()
	end,
	drop = function() if life.growth:isMoulting() then return end; ant.stopDisplay(); motor:requestDrop() end,
	clear = dropAll,
	reset = function() if not panel:isShowing() then returnToCheckpoint() end end, -- the catch screen has its own way back
	gait = function() rig.gaitMode = if rig.gaitMode == "Tetrapod" then "Unilateral" else "Tetrapod" end,
	eye = function() cam:toggleEyeView() end,
	recenter = function() cam:startRecenter() end,
	slow = function() slow = not slow end,
	touchLook = function(delta: Vector2) cam:touchLook(delta) end,
	help = function()
		helpVisible = not (helpVisible and (setting("ControlHints") or helpUntil == math.huge))
		helpUntil = math.huge
	end,
	device = function(name: string)
		device = ControlText.deviceFor(name, device)
		if device == "gamepad" then refreshPadStyle() end
		nbPanel:setDevice(device)
		settingsPanel:setDevice(device)
	end,
})

-- One fixed tick's intent from the controls, for the motor.
local function tickInput(): any
 if life.growth:isMoulting() then return SpiderMotor.idleInput() end
	local r, f = controls:axes()
	if jump:isAiming() then r, f = 0, 0 end -- left stick aims, never walks during the held jump
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
	if focusState:active(controls.held.Focus == true, setting("FocusToggle") == true, motor.mode == "attached") then
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
		if last.kind == "launched" and last.plan and last.plan.point and last.plan.origin then
			watch:onJump((last.plan.point - last.plan.origin).Magnitude) -- a committed leap, from take-off to the landing point
		end
		hud:toast(ControlText.toast(last.kind, last.plan), last.kind ~= "cancelled")
	end
end

local function updateHud(frameDt: number)
	handleEvents()
	local aiming = jump:isAiming()
	local view: any = {
		device = device, aiming = aiming, focus = controls.held.Focus == true or focusActive(), eyeView = cam.eyeView,
		status = {}, helpVisible = helpVisible, helpText = ControlText.helpCard(device) .. PeacockText.helpExtra(device, SpiderChoice.displayKind(appearance)),
		caption = eyes:captionView(device),
	}
	-- Captions for sounds and vibrations (ROBLOX-49): off, normal or large. The eye view's own explanation above is not a sound caption.
	local captionScale = SettingsSpec.CAPTION_SCALE[setting("Captions")] or 1
	view.captionScale = if captionScale > 0 then captionScale else 1
	local hints = setting("ControlHints")
	view.helpVisible = helpVisible and (hints or helpUntil == math.huge) -- (H asks for the card even when the hints are off)
	local rumble = if dancePose and captionScale > 0 then PeacockText.caption(dancePose.rumble) else nil -- felt through the feet; the wasp's hum below takes precedence
	if rumble then view.caption = rumble end
	if wasp:isVisiting() and captionScale > 0 then
		local direction = WaspText.directionWord(motor.pos, motor.heading, motor.up, wasp.wasp.position)
		local heard = WaspText.caption(wasp.phase, wasp.phaseS, direction)
		-- The wasp going for the rival male is told only to a spider that could hear or see it (ROBLOX-70).
		local forRival = wasp.phase == "taking" or wasp.phase == "seizing" or wasp.phase == "bearing"
		if forRival and not WaspText.heardRival((motor.pos - wasp.wasp.position).Magnitude, not sightCast(motor.pos, wasp.wasp.position)) then heard = nil end
		if heard then view.caption = heard end
	end
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
	local waspLine = WaspText.line(wasp.phase, wasp.confusedS > 0, wasp.visits, wasp.sparedThisVisit, device)
	if (wasp.phase == "taking" or wasp.phase == "seizing" or wasp.phase == "bearing")
		and not WaspText.heardRival((motor.pos - wasp.wasp.position).Magnitude, not sightCast(motor.pos, wasp.wasp.position)) then waspLine = nil end
	if waspLine then table.insert(view.status, waspLine) end
 if life.rival and life.rival.state=="captured" then table.insert(view.status,"Eating rival — stay still (2 meals)") end
	view.grip = if prey.feeding.struggling then prey.feeding.grip else nil
	if prey.feeding.struggling then
		table.insert(view.status, "Caught — tap " .. ControlText.name(device,"jump") .. " to keep your grip")
	elseif prey.feeding.feeding then table.insert(view.status, "Feeding — move to stop")
	elseif prey.feeding.held then table.insert(view.status, "Meal paused — " .. ControlText.name(device,"feed") .. " to eat") end
	local clock = life.clock
	view.day = LifeText.day(clock.day, clock:partOfDay()) .. " | " .. life.growth:stageName() .. (if session.mode=="free" then " | FREE PLAY" elseif session.rules=="gentle" then " | EASY" else "")
	view.food, view.foodGentle, view.largeText = needs.energy, needs.gentle, setting("LargeText") == true
	view.growth = LifeText.growth(life.growth, Growth.READY_FOOD, Species.fly_like_prototype.body.nutrition)
	view.dayLine = LifeText.line(clock:partOfDay(), needs.energy, needs:isStarving(), needs.gentle, LifeLoop.HUNGRY_AT, life:tooHungryToSleep())
 if life.growth.ready then view.dayLine=nil
 elseif life.growth:isSoft() then view.dayLine="Soft new skin: slower steps and shorter jumps until it hardens." end
 view.dayLine = view.growth .. (if view.dayLine then "\n" .. view.dayLine else "")
 view.notice = if life.noticeSeconds > 0 and life.notice ~= "" then life.notice else nil
	local canRest = life:canRest(lifeSpider)
	local restPrompt = LifeText.prompt(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep(), device, PeacockText.change(device, appearance))
 if life.growth:isMoulting() then
  restPrompt={title="Moulting in the silk-lined crack",hint="The spider pulls free of its old skin. Wait here while the hours pass."}
 elseif life.growth.ready and canRest and not life.resting then
  restPrompt={title="Ready to moult",hint=ControlText.name(device,"feed")..": rest and moult in the crack"}
 end
 if not restPrompt and (motor.pos-Vector3.new(-24,1,6)).Magnitude<7 and not prey.feeding.held then
  restPrompt={title="Home: the silk-lined crack",hint=if lifeSpider.inRetreat then "Keep still on a surface, then "..ControlText.name(device,"feed")..": rest" else "Walk through the silk-framed opening under the wooden roof, then stop to rest."}
 end
 local displayKind = SpiderChoice.displayKind(appearance)
	local displayOn = if displayKind == "antennae" then ant.state:displaying() else dance.active
	local displayHint = if displayKind == "antennae" then ant.Text.displayHint(device, displayOn) elseif displayKind == "dance" then PeacockText.displayHint(device, displayOn) else ""
	if restPrompt and not lifeSpider.inRetreat and displayKind ~= nil then restPrompt.hint ..= "    " .. displayHint end
	if displayKind ~= nil and displayOn then table.insert(view.status, if displayKind == "antennae" then ant.Text.statusLine(device) else PeacockText.dancingLine(device)) end
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
	elseif hints and motor.mode == "attached" and not aiming and (helpVisible or os.clock() - started < WALK_HINT_SECONDS) then
		view.prompt = { hint = ControlText.walkHint(device) .. (if displayKind ~= nil then "    " .. displayHint else "") }
	end
	if os.clock() > helpUntil and helpVisible then helpVisible = false end
	local restLabel = LifeText.touchLabel(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep())
	controls:setTouchVisible("Feed", (prey.feeding.held ~= nil or restLabel ~= nil) and not life.growth:isMoulting())
	controls:setTouchLabel("Feed", if prey.feeding.held ~= nil then "Eat" else restLabel or "Eat")
	controls:setTouchLabel("Jump", if prey.feeding.struggling then "Grip" else "Jump")
	controls:setTouchLabel("Cancel", ControlText.touchCancelLabel(onLine))
	controls:setTouchVisible("Jump", not onLine)
	controls:setTouchVisible("Creep", not onLine)
	-- The peacock spider's buttons: Change in the crack, Dance on the open sill (the peacock spider only).
	controls:setTouchVisible("Choose", canChange())
	controls:setTouchVisible("Display", displayKind ~= nil and not onLine and not life.resting and motor.mode == "attached")
	controls:setTouchLabel("Display", if displayKind == "antennae" then ant.Text.touchDisplay(displayOn) else PeacockText.touchDisplay(displayOn))
	hud:update(view, frameDt)
end

-- ---------------------------------------------------------------- the frame
local accumulator = 0
RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)
	updateSaves()
	if panel:isShowing() then panel:update(frameDt) end
	if nbPanel:isShowing() then nbPanel:update(frameDt) end
	if settingsPanel:isShowing() then settingsPanel:update(frameDt) end
	if GuiService.MenuIsOpen or modal() then
		accumulator = 0 -- the Roblox menu is Godot's pause (so is the catch screen): the world waits
	else
		local simDt = frameDt * (if slow then SLOW_SPEED else 1)
		accumulator = math.min(accumulator + simDt, 0.25)
		local origin, dir = cam:aimRay()
		motor:setAimRay(origin, dir)
		while accumulator >= DT do
			accumulator -= DT
			local percepts = prey:percepts()
            life.rival=life.rival or RivalSpider.new()
            local rivalPercept=RivalSpider.percept(life.rival)
            if rivalPercept then table.insert(percepts,rivalPercept) end
			if stage then
				local p = stage.target:percept()
				if p then table.insert(percepts,p) end
			end
			local waspPercept = wasp:percept() -- movement to the spider's senses, never prey
			if waspPercept then table.insert(percepts, waspPercept) end
			sensor:step(DT,motor:observer(),percepts,sightCast)
			prey:before(DT,motor.pos,motor:observer(),sensor,sightCast,camera)
			if life.growth:isMoulting() then jump:drop(motor);motor:cancelWalk() else jump:step(motor) end
			if breakaway:step(DT,if jump.last and jump.last.tick==jump.tick then jump.last else nil,motor.pos,setting("ReducedMotion")==true) then
    motor.planKey="";hud:toast("The dry leaf tip gave way. Your dragline catches the miss.",false)
   end
			local input = tickInput()
			motor:tick(input)
			-- The wasp runs after the spider has moved and before feeding (Godot: physics priority 8).
			wasp.enabled = not testPlace or Workspace:GetAttribute("Wasp") == true
            wasp:useGameRules()
			local forced = if testPlace then Workspace:GetAttribute("WaspForce") else nil
			if typeof(forced) == "string" and forced ~= "" then
				Workspace:SetAttribute("WaspForce", nil)
				wasp:force(life.clock.day, forced)
			end
			local fallingOnLine = motor:onLine() or (motor.mode == "air" and motor.dropped == true)
			waspSpider.position, waspSpider.velocity = motor.pos, motor.vel
			waspSpider.falling = fallingOnLine
			waspSpider.airborne = motor.mode == "air" and not fallingOnLine and not motor.seized
			wasp:step(DT, waspSpider, {
				day = life.clock.day, hour = life.clock.hour, resting = life.resting, moulting = life.growth:isMoulting(), meals = prey.feeding.mealsFinished,
				rival = RivalSpider.target(life.rival),
			})
			for _, signal in wasp:drainSignals() do
				watch:onWasp(signal.kind, signal.escaped)
				if signal.kind == "caught" then
					-- Stung: the spider lets go of everything and is carried (Godot SpiderMotor.seize).
					motor:seize()
					dropAll()
					dropStrands(false)
				elseif signal.kind == "carried_off" then
					showCaught()
				elseif signal.kind == "rival_seized" then
					-- The wasp has the rival male (ROBLOX-70): it hangs under the wasp; the spider is not hunted today.
					if RivalSpider.seize(life.rival) and WaspText.heardRival((motor.pos - signal.at).Magnitude, not sightCast(motor.pos, signal.at)) then
						life:showNotice(WaspText.RIVAL_TAKEN)
					end
				elseif signal.kind == "rival_carried_off" then
					RivalSpider.carried(life.rival, life.clock.day)
				end
			end
			if wasp.rivalHeldAt and life.rival.state == "taken" then life.rival.position = wasp.rivalHeldAt end
			if wasp.heldAt then motor:hold(wasp.heldAt) end
			prey.feeding.auto = setting("AutomaticGrip") == true
			local takenBefore = prey.feeding.taken
			prey:after(DT,motor,sensor,sightCast)
			-- Three houseflies or six small prey; credit food, not just spare energy capacity.
			life.mealFood = (life.mealFood or 0) + (prey.feeding.taken-takenBefore) * Growth.READY_FOOD / (3 * Species.fly_like_prototype.body.nutrition)
            local rivalState={
             position=motor.pos,previous=prey.previousPosition or motor.pos,heading=motor.heading,up=motor.up,
             day=life.clock.day,hour=life.clock.hour,meals=prey.feeding.mealsFinished,resting=life.resting,safe=Layout.inRetreat(motor.pos),
             wasp=wasp:isVisiting(),gentle=needs.gentle,grounded=motor.mode=="attached",moving=motor.moving,
             airborne=motor.mode=="air",onLine=motor:onLine(),holding=prey.feeding.held~=nil,
             striking=prey.tick<=prey.strikeEnd and not motor.seized,drive=rivalLegs.drive,taken=wasp.holdingRival,
            }
            local rivalEvent,rivalFood=RivalSpider.step(life.rival,DT,rivalState,sightCast)
            if life.rival.state~="dormant" and life.rival.state~="consumed" and rivalLegs.drive==nil then
             rivalLegs.drive=rivalLegs.Drive.new(SpiderMotor.new({
              world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype,
              spawn = life.rival.position, heading = life.rival.heading,
              boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = arc,
             }),sightCast)
            end
            if rivalLegs.drive then rivalLegs.drive:update(life.rival,DT,rivalState) end
            if rivalFood>0 then
             needs:grantEnergy(rivalFood,"rival_spider_meal")
             life.mealFood+=rivalFood*Growth.READY_FOOD/(3*Species.fly_like_prototype.body.nutrition)
            end
            if rivalEvent=="caught" then endLife("rival")
            elseif rivalEvent=="warning" then life:showNotice("The other spider crouches to jump. Dodge, drop or jump away!")
            elseif rivalEvent=="captured" then life:showNotice("Caught the rival. Stay still to eat; worth two housefly meals.")
            elseif rivalEvent=="eaten" then prey.feeding.mealsFinished+=1
            elseif rivalEvent=="touch" then life:showNotice("The rival touched you. You are safe in this mode.") end
			-- The life loop runs last in the tick (Godot's habitat loop, priority 12); the reach it sets is the next tick's.
			local holding = prey.feeding.held ~= nil or (life.rival~=nil and life.rival.state=="captured")
			lifeSpider = {
				inRetreat = Layout.inRetreat(motor.pos), attached = motor.mode == "attached" and not motor.preparing,
				still = input.wish.Magnitude < 0.01 and motor.vel.Magnitude < 0.15,
				holding = holding, feeding = holding and (prey.feeding.feeding or (life.rival~=nil and life.rival.state=="captured")), position = motor.pos,
			}
			life:step(DT, lifeSpider, feedPending, cancelPending)
			feedPending, cancelPending = false, false
			sensor.core.rangeScale = life.rangeScale
			motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
   for _,event in life:drainEvents() do
    watch:onLife(event.kind,life.growth.stage)
    if event.kind=="starved" then endLife("starved")
    elseif event.kind=="moult_started" then dropAll()
    elseif event.kind=="moulted" and session:finishAdult(life.growth.stage) then
     life:showNotice("Your spider is an adult! Easy is now available in the life menu for this session.")
     life.noticeSeconds=12
    end
   end
            if not initialRecord and Checkpoint.boundaryProblem(checkpointWorld)=="" then
             initialRecord=Checkpoint.capture(checkpointWorld,0)
             if initialRecord and not menuStarted then
              menuStarted=true
              if not testPlace then openMenu() else session.started=true end
             end
            end
            watch:step({
             started=session.started,captures=prey.captures,feeding=prey.feeding.feeding,taken=prey.feeding.taken,
             energy=needs.energy,gentle=needs.gentle,spider=motor.pos,flies=prey.flies,
            })
            if modal() then accumulator=0;break end
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
	-- The peacock spider's dance: a pose for the rig, stepped with the simulation's time (slow motion slows it, a menu or the catch screen
	-- holds it). Standing still on a surface; any walking intent, jump, line or rest ends it at once.
	if SpiderChoice.canDance(appearance) then
		dance.reduced = setting("ReducedMotion") == true
		local r, f = controls:axes()
	if jump:isAiming() then r, f = 0, 0 end -- left stick aims, never walks during the held jump
		local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not life.resting
		local paused = GuiService.MenuIsOpen or modal()
		dancePose = dance:step(if paused then 0 else simFrame, standing, motor.moving or r ~= 0 or f ~= 0)
		rig.dance = if dance:showing() then dancePose else nil
	else
		dancePose = nil
		rig.dance = nil
	end
	-- The ant-mimicking spider: legs I rise as antennae when it keeps still and its drawn body yaws and sways along the distance it walks. The
	-- same time and the same standing test as the dance; the distance is the spider's real movement since the last frame (a respawn is not a walk).
	do
		local here = motor.pos
		if SpiderChoice.hasAntennae(appearance) then
			ant.state.reduced = setting("ReducedMotion") == true
			ant.state.bodyLength = ant.Pose.BODY_LENGTH * rig._growth
			local r, f = controls:axes()
			local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not life.resting
			local paused = GuiService.MenuIsOpen or modal()
			local last = ant.last
			local moved = if last ~= nil and not paused then (here - last).Magnitude else 0
			ant.pose = ant.state:step(if paused then 0 else simFrame, standing, motor.moving or r ~= 0 or f ~= 0, moved)
			rig.ant = ant.pose
			if not paused then watch:antennae(ant.pose.shownSeconds) end
		else
			ant.pose = nil
			rig.ant = nil
		end
		ant.last = here
	end
 rig.reducedMotion=setting("ReducedMotion")==true
 rig:setGrowthStage(life.growth.stage)
 rig:setSoftness(life.growth:softness())
 rig:setCondition(needs.energy)
 rig.hangDirection=if motor:onLine() and motor.silk.taut and not motor.seized then motor.silk:pivot()-motor.pos else nil
 rig.jumpLoad=if motor.mode=="attached" and not motor.seized and jump:isBusy() then math.clamp(jump.heldTicks/JumpInput.HOLD_TICKS,0,1) else 0
 local recentJump=jump.last
 rig.jumpPush=if not motor.seized and motor.mode=="air" and recentJump and recentJump.kind=="launched" then math.clamp(1-(jump.tick-recentJump.tick)/8,0,1) else 0
 local paused=GuiService.MenuIsOpen or modal()
 rig:update(body, if paused then 0 else simFrame, motor.mode == "attached", motor.moving)
 skins:draw(life.growth.exuviae)
 if not paused then watch:frame(simFrame,cam.eyeView,eyes.moversShown) end
    local rival=life.rival
    if rival and rival.state~="dormant" and rival.state~="consumed" then
     if not rivalLegs.rig then rivalLegs.rig=SpiderRig.new(Workspace,sill,"rival_spider","low");rivalLegs.rig.model.Name="RivalSpider" end
     rivalLegs.rig.reducedMotion=setting("ReducedMotion")==true
     rivalLegs.rig.jumpLoad=if rival.state=="windup" then math.clamp(rival.elapsed,0,1) else 0
     rivalLegs.rig:update(SupportMath.bodyCFrame(rival.position,if rival.state=="taken" then Vector3.yAxis else (rival.up or Vector3.yAxis),rival.heading),if paused then 0 else simFrame,rival.state~="lunge" and rival.state~="taken",(rival.position-rival.previous).Magnitude>.001)
    elseif rivalLegs.rig then rivalLegs.rig:destroy();rivalLegs.rig=nil end
	updateHud(frameDt)
	flyBodies:draw(prey.flies,prey.now)
	local soundPaused = GuiService.MenuIsOpen or modal()
	local soundSpeed = if slow then SLOW_SPEED else 1
	local soundMuted = setting("SoundMuted") == true
	soundscape:setVolumes(setting("MasterVolume"), setting("AmbienceVolume"), setting("CreatureVolume"))
	soundscape:update(frameDt, prey, life.daylight, soundPaused, soundSpeed, soundMuted)
	soundscape:updateWasp(wasp, soundPaused, soundSpeed, soundMuted)
	waspBody:draw(wasp.wasp, prey.now)
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
	-- The camera's settings (ROBLOX-49), read each frame so a change in the panel shows at once.
	camSettings.mouse, camSettings.stick, camSettings.touch = setting("LookSensitivityMouse"), setting("LookSensitivityStick"), setting("LookSensitivityTouch")
	camSettings.invertX, camSettings.invertY = setting("InvertX"), setting("InvertY")
	camSettings.fov, camSettings.distance, camSettings.framing = setting("FieldOfView"), setting("CameraDistance"), setting("FrameLine")
	camSettings.levelHorizon = setting("EyeLevelHorizon")
	cam:configure(camSettings)
	-- Looking runs in real time, so slow motion never makes the camera sluggish.
	local lx, ly = controls:lookAxes(jump:isAiming())
	if not modal() then cam:render(frameDt, lx, ly) end
	-- The Focus that feeds the perception HUD also decides how far the principal eyes are in use (the eye view's picture). The
	-- picture sets the field of view, so it comes before the HUD projects anything.
	local focusing = motor.mode == "attached" and (controls.held.Focus == true or focusActive())
	eyes:update(frameDt, focusing)
	perceptionHud:draw(memory,camera,sightCast,focusing,setting("ShowLastSeen") == true)
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
			prey = prey, flyBodies = flyBodies, waspBody = waspBody, life = life, wasp = wasp, caughtPanel = panel, needs = needs, checkpoints = checkpoints, returnToCheckpoint = function() returnToCheckpoint() end, lifeSpider = function() return lifeSpider end, sensor = sensor, memory = memory, focusState = focusState, perceptionHud = perceptionHud, stage = stage,
			input = controls, rivalLegs = rivalLegs,
			notebook = book, notebookWatch = watch, notebookPanel = nbPanel, openNotebook = openNotebook, settingsPanel = settingsPanel, openSettings = openSettings, setting = setting, cam = cam, soundscape = soundscape, eyes = eyes,
			session=session, menu=menu, openMenu=openMenu, endLife=endLife, fresh=fresh, continueAnother=continueAnother, currentStore=function() return checkpoints end,
			changeSpider = function() changeSpider() end, dance = function() return dance end, ant = function() return ant.state end, antPose = function() return ant.pose end, appearance = function() return appearance end, rig = function() return rig end,
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
