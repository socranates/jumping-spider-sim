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
local LifeSession = require(Shared.Life.LifeSession)
local session = LifeSession.new()
local LifeText = require(Shared.UI.LifeText)
local DayLight = require(Shared.Habitat.DayLight)
local LifeClock = require(Shared.Life.LifeClock)
local WaspDirector = require(Shared.Predator.WaspDirector)
local WaspText = require(Shared.UI.WaspText)
local SpiderChoice = require(Shared.Rig.SpiderChoice)
local PeacockDance = require(Shared.Rig.PeacockDance)
local PeacockText = require(Shared.UI.PeacockText)
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
-- Solo windowsill: the default player list obscures the life-menu button on small screens.
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
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
-- Which spider: the Player attribute Appearance (kept for the session), else the Workspace attribute Appearance, else the first spider.
local appearance = SpiderChoice.start(player:GetAttribute("Appearance"), Workspace:GetAttribute("Appearance"))
local rig = SpiderRig.new(Workspace, sill, appearance, detail)
local dance = PeacockDance.new() -- the peacock spider's courtship dance (a pose for the rig; nothing else reads it)
local dancePose: any = nil
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
sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local sightCast = Sensor.workspaceCast(params)
local perceptionHud = PerceptionHud.new(player:WaitForChild("PlayerGui"))
local stage = if Workspace:GetAttribute("TestTarget") == true or (Workspace:GetAttribute("TestTarget") ~= false and script.Parent:FindFirstChild("SilkPlayback")) then PerceptionStage.new(sill) else nil
local prey = PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4)
local flyBodies = FlyBodies.new(Workspace)
local soundscape = Soundscape.new(Workspace)
local waspBody = WaspBody.new(Workspace)
-- LIFE (ROBLOX-24): the windowsill runs the life clock, so hunger runs by its hours (NeedsModel life mode, Standard rules: the
-- port has no Easy mode yet). Feeding grants into the same model. The loop keeps the rest, sleep, daylight and the eyes' reach.
local needs = NeedsModel.new(true, false)
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
-- S01-C retreat checkpoints (ROBLOX-25): resting in the crack, and each morning, keeps one; Backspace / View returns to it. The
-- store is DataStore-shaped but in memory only: a checkpoint lasts the session. No live DataStore is written.
local checkpointWorld: Checkpoint.World = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life, wasp = wasp }
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
	bodyHidden = hidden
	rig:setBodyHidden(hidden)
end
jump.onAim = function(on: boolean)
	cam:setAiming(on)
end
-- The spider-eye picture (ROBLOX-20): field of view, colour, blur, retina strips, movement rings, UV layer, vignette. Presentation only.
local eyes: any = SpiderEyes.new({ parent = player:WaitForChild("PlayerGui"), camera = camera, player = player, cam = cam, sensor = sensor, params = params })

-- Everything held is dropped with no penalty and no message: focus loss, the Roblox menu, a text box, a lost controller.
local function dropAll()
	dance:stop()
	focusState:clear()
	jump:drop(motor)
	local release = motor.silk.release
	release.down, release.counts, release.held, release.progress = true, false, 0, 0
	motor:cancelWalk()
end

local function backToStart()
	dance:stop()
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

-- Choosing the spider (ROBLOX-31): only while resting awake in the silk-lined crack. The drawn rig is built again with the other appearance;
-- the gait, the eye view and the hidden body carry over; the choice is kept in the Player attribute Appearance for the session.
local function canChange(): boolean
	return life.resting and not life.asleep
end
local function changeSpider()
	if not canChange() then
		hud:toast(PeacockText.NOT_RESTING, false)
		return
	end
	appearance = SpiderChoice.next(appearance)
	player:SetAttribute("Appearance", appearance)
	dance:stop()
	dance = PeacockDance.new()
	dancePose = nil
	local old = rig
	rig = SpiderRig.new(Workspace, sill, appearance, detail)
	rig.gaitMode = old.gaitMode
	rig:setEyeView(cam.eyeView)
	rig:setBodyHidden(bodyHidden)
	old:destroy()
	hud:toast(PeacockText.changed(appearance), false)
end
-- X / RB / the Dance button: start the courtship dance, or end it. On a controller RB in the crack changes spider instead (one button for
-- both, as the crack and the open sill never overlap). Not for the first spider: it has no dance.
local function toggleDance()
	if life.resting then
		if device == "gamepad" and not life.asleep then changeSpider() end
		return
	end
	if not SpiderChoice.canDance(appearance) then return end
	if dance:showing() and dance.active then
		dance:stop()
		return
	end
	local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not jump:isBusy() and motor.silk.walk == nil
	if not dance:start(standing, motor.moving) then
		hud:toast(PeacockText.STAND, false)
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
	dance:stop()
	local ok, problems = Checkpoint.restore(best.record, checkpointWorld)
	if not ok then
		warn("[Windowsill] checkpoint refused: " .. table.concat(problems, "; "))
		hud:toast("The checkpoint could not be used: " .. (problems[1] or "unknown"), true)
		return
	end
	session.mode, session.rules, session.ended = life.mode or "main", life.rules or "standard", false
	session.summary = nil
	controls:clear()
	focusState:clear()
	dropStrands(false)
	drawnUp = motor.up
	cam:snap()
	lastLight = nil -- the hour may have changed: set the light again
	feedPending, cancelPending = false, false
end

-- Player progress is session-only and outside checkpoints. Modes have independent rest stores.
local function setHudShown(shown: boolean)
 hud.safe.Enabled=shown;hud.centre.Enabled=shown
 local touch=player:WaitForChild("PlayerGui"):FindFirstChild("SpiderTouch")
 if touch and touch:IsA("ScreenGui") then touch.Enabled=shown and UIS.TouchEnabled end
end
local function applyRules()
 life.mode,life.rules=session.mode,session.rules
 needs.gentle=session.rules=="gentle";wasp.gentle=needs.gentle
end
local function closeScreens()
 panel:hide();menu:hide();setHudShown(true);controls:clear();dropAll()
end
local function fresh(mode: string, easy: boolean, position: Vector3?): boolean
 if not initialRecord or (easy and not session.finishedMain) then return false end
 local ok=Checkpoint.restore(initialRecord,checkpointWorld)
 if not ok then return false end
 session:begin(mode,easy);applyRules()
 sensor:reset();memory:clear()
 stores[mode]=newStore();checkpoints=stores[mode]
 life.resting=false;life.notice="";life.noticeSeconds=0;life.restoreGrace=0
 wasp:load(WaspDirector.defaultRecord());wasp.gentle=needs.gentle
 if position then motor:place(position,Vector3.yAxis,Layout.SPAWN_HEADING) end
 closeScreens();dropStrands(false);drawnUp=motor.up;cam:snap();lastLight=nil
 feedPending,cancelPending=false,false
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
  meals=prey.feeding.mealsFinished,wasp_visits=wasp.visits,wasp_escapes=wasp.escapes,stage=0}
end
panel=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Another" then continueAnother()
 elseif choice=="Back" then closeScreens();wasp:clearVisit();returnToCheckpoint() end
end)
local function endLife(cause: string)
 local rec=summaryRecord(cause)
 if not session:endLife(cause,rec) then return end
 controls:clear();dropAll();setHudShown(false)
 local choices: {CaughtPanel.Choice}={}
 if checkpoints:loadBest().ok then table.insert(choices,{id="Back",text="Back to your last rest"}) end
 table.insert(choices,{id="Another",text="Continue as another spider"})
 panel:showChoices(if cause=="starved" then "The spider starved." else WaspText.LINE,
  if cause=="starved" then "It went too long without food." else WaspText.SUB,
  WaspText.summary(rec.hours,rec.meals,rec.wasp_visits,rec.wasp_escapes),choices)
 panel:setTextScale(if player:GetAttribute("LargeText")==true then 1.5 else 1)
end
local function showCaught() endLife("wasp") end
local openMenu: () -> ()
local confirming: string?=nil
menu=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Resume" then closeScreens();return end
 if choice=="Continue" then checkpoints=stores.main;closeScreens();returnToCheckpoint();return end
 if choice=="Free" then
  local saved=stores.free:loadBest()
  if saved.ok then checkpoints=stores.free;closeScreens();returnToCheckpoint()
  else fresh("free",false,nil) end
  return
 end
 if choice=="Large" then
  player:SetAttribute("LargeText",player:GetAttribute("LargeText")~=true);openMenu();return
 end
 if choice=="New" or choice=="Easy" then
  if session.started and confirming~=choice then
   confirming=choice
   menu:showChoices("Begin a new life?","This replaces the main life's last rest for this session.","",
    {{id=choice :: string,text="Begin the new life"},{id="CancelNew",text="Keep this life"}},true)
   return
  end
  confirming=nil;session:archive();fresh("main",choice=="Easy",nil);return
 end
 confirming=nil;openMenu()
end,"SpiderLifeMenu")
openMenu=function()
 if panel:isShowing() or not initialRecord then return end
 controls:clear();dropAll();setHudShown(false)
 local choices: {CaughtPanel.Choice}={}
 if session.started then table.insert(choices,{id="Resume",text="Resume this spider"}) end
 if stores.main:loadBest().ok then table.insert(choices,{id="Continue",text="Continue from last rest"}) end
 table.insert(choices,{id="New",text="Begin a new life"})
 if session.finishedMain then table.insert(choices,{id="Easy",text="Begin a new life on Easy"}) end
 table.insert(choices,{id="Free",text="Free play - gentle rules"})
 table.insert(choices,{id="Large",text=if player:GetAttribute("LargeText")==true then "Text size: large" else "Text size: normal"})
 menu:showChoices("The Windowsill","A small life on a windowsill.",
  "Progress and rest checkpoints last for this play session."..(if session.finishedMain then "" else "\nEasy is not available yet; choose Free play for gentle rules."),choices,true)
 menu:setTextScale(if player:GetAttribute("LargeText")==true then 1.5 else 1)
end
local menuButton=Instance.new("TextButton")
menuButton.Name="LifeMenu";menuButton.Text="Menu";menuButton.Size=UDim2.fromOffset(72,36)
menuButton.Position=UDim2.new(1,-84,0,48);menuButton.TextSize=16
menuButton.BackgroundColor3=Color3.new(.12,.12,.14);menuButton.TextColor3=Color3.new(1,1,1)
menuButton.Parent=hud.safe;menuButton.Activated:Connect(openMenu)

controls = SpiderInput.bind({
	blocked = function() return panel:isShowing() or menu:isShowing() end,
	menu = function() if menu:isShowing() and session.started then closeScreens() else openMenu() end end,
	focus = function(phase: string)
		if phase == "begin" then focusState:press(player:GetAttribute("FocusToggle") == true, motor.mode == "attached")
		elseif phase == "cancel" then focusState:clear() end
	end,
	choose = function() changeSpider() end,
	display = function() toggleDance() end,
	feed = function()
		dance:stop()
		prey.feeding:press()
		feedPending = true -- in the crack, with nothing to eat, the same button rests (Godot's interact)
	end,
	jump = function(phase: string)
		if phase == "begin" and prey.feeding.struggling then prey.feeding:press(); gripPress=true; return end
		if gripPress then if phase ~= "begin" then gripPress=false end; return end
		if phase == "begin" then
			dance:stop() -- a jump (a hop or an aim) ends the dance
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
		dance:stop()
		cancelPending = true -- also ends a rest
		prey.feeding:cancel()
		if motor:cancelWalk() then return end
		focusState:cancel(jump:isBusy() or #jump.events > 0 or motor:onLine())
		jump:cancel()
	end,
	drop = function() dance:stop(); motor:requestDrop() end,
	clear = dropAll,
	reset = function() if not panel:isShowing() then returnToCheckpoint() end end, -- the catch screen has its own way back
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
		if device == "gamepad" then refreshPadStyle() end
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
		status = {}, helpVisible = helpVisible, helpText = ControlText.helpCard(device) .. PeacockText.helpExtra(device, SpiderChoice.canDance(appearance)),
		caption = eyes:captionView(device),
	}
	local rumble = if dancePose then PeacockText.caption(dancePose.rumble) else nil -- felt through the feet; the wasp's hum below takes precedence
	if rumble then view.caption = rumble end
	if wasp:isVisiting() then
		local direction = WaspText.directionWord(motor.pos, motor.heading, motor.up, wasp.wasp.position)
		local heard = WaspText.caption(wasp.phase, wasp.phaseS, direction)
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
	if waspLine then table.insert(view.status, waspLine) end
	view.grip = if prey.feeding.struggling then prey.feeding.grip else nil
	if prey.feeding.struggling then
		table.insert(view.status, "Caught — tap " .. ControlText.name(device,"jump") .. " to keep your grip")
	elseif prey.feeding.feeding then table.insert(view.status, "Feeding — move to stop")
	elseif prey.feeding.held then table.insert(view.status, "Meal paused — " .. ControlText.name(device,"feed") .. " to eat") end
	local clock = life.clock
	view.day = LifeText.day(clock.day, clock:partOfDay()) .. (if session.mode=="free" then " | FREE PLAY" elseif session.rules=="gentle" then " | EASY" else "")
	view.dayLine = LifeText.line(clock:partOfDay(), needs.energy, needs:isStarving(), needs.gentle, LifeLoop.HUNGRY_AT, life:tooHungryToSleep())
	view.notice = if life.noticeSeconds > 0 and life.notice ~= "" then life.notice else nil
	local canRest = life:canRest(lifeSpider)
	local restPrompt = LifeText.prompt(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep(), device, PeacockText.change(device, appearance))
	if not restPrompt and (motor.pos-Vector3.new(-24,1,6)).Magnitude<7 and not prey.feeding.held then
  restPrompt={title="Home: the silk-lined crack",hint=if lifeSpider.inRetreat then "Keep still on a surface, then "..ControlText.name(device,"feed")..": rest" else "Walk through the silk-framed opening under the wooden roof, then stop to rest."}
 end
 local canDance = SpiderChoice.canDance(appearance)
	if restPrompt and not lifeSpider.inRetreat and canDance then restPrompt.hint ..= "    " .. PeacockText.displayHint(device,dance.active) end
	if canDance and dance.active then table.insert(view.status, PeacockText.dancingLine(device)) end
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
		view.prompt = { hint = ControlText.walkHint(device) .. (if canDance then "    " .. PeacockText.displayHint(device, dance.active) else "") }
	end
	if os.clock() > helpUntil and helpVisible then helpVisible = false end
	local restLabel = LifeText.touchLabel(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep())
	controls:setTouchVisible("Feed", prey.feeding.held ~= nil or restLabel ~= nil)
	controls:setTouchLabel("Feed", if prey.feeding.held ~= nil then "Eat" else restLabel or "Eat")
	controls:setTouchLabel("Jump", if prey.feeding.struggling then "Grip" else "Jump")
	controls:setTouchLabel("Cancel", ControlText.touchCancelLabel(onLine))
	controls:setTouchVisible("Jump", not onLine)
	controls:setTouchVisible("Creep", not onLine)
	-- The peacock spider's buttons: Change in the crack, Dance on the open sill (the peacock spider only).
	controls:setTouchVisible("Choose", canChange())
	controls:setTouchVisible("Display", canDance and not onLine and not life.resting and motor.mode == "attached")
	controls:setTouchLabel("Display", PeacockText.touchDisplay(dance.active))
	hud:update(view, frameDt)
end

-- ---------------------------------------------------------------- the frame
local accumulator = 0
RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)
	if panel:isShowing() then panel:update(frameDt) end
	if GuiService.MenuIsOpen or panel:isShowing() or menu:isShowing() then
		accumulator = 0 -- the Roblox menu is Godot's pause (so is the catch screen): the world waits
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
			local waspPercept = wasp:percept() -- movement to the spider's senses, never prey
			if waspPercept then table.insert(percepts, waspPercept) end
			sensor:step(DT,motor:observer(),percepts,sightCast)
			prey:before(DT,motor.pos,motor:observer(),sensor,sightCast,camera)
			jump:step(motor)
			local input = tickInput()
			motor:tick(input)
			-- The wasp runs after the spider has moved and before feeding (Godot: physics priority 8).
			wasp.enabled = not testPlace or Workspace:GetAttribute("Wasp") == true
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
				day = life.clock.day, hour = life.clock.hour, resting = life.resting, moulting = false, meals = prey.feeding.mealsFinished,
			})
			for _, signal in wasp:drainSignals() do
				if signal.kind == "caught" then
					-- Stung: the spider lets go of everything and is carried (Godot SpiderMotor.seize).
					motor:seize()
					dropAll()
					dropStrands(false)
				elseif signal.kind == "carried_off" then
					showCaught()
				end
			end
			if wasp.heldAt then motor:hold(wasp.heldAt) end
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
			for _,event in life:drainEvents() do if event.kind=="starved" then endLife("starved") end end
            if not initialRecord and Checkpoint.boundaryProblem(checkpointWorld)=="" then
             initialRecord=Checkpoint.capture(checkpointWorld,0)
             if initialRecord and not menuStarted then
              menuStarted=true
              if not testPlace then openMenu() else session.started=true end
             end
            end
            if panel:isShowing() or menu:isShowing() then accumulator=0;break end
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
		dance.reduced = player:GetAttribute("ReducedMotion") == true
		local r, f = controls:axes()
		local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not life.resting
		local paused = GuiService.MenuIsOpen or panel:isShowing() or menu:isShowing()
		dancePose = dance:step(if paused then 0 else simFrame, standing, motor.moving or r ~= 0 or f ~= 0)
		rig.dance = if dance:showing() then dancePose else nil
	else
		dancePose = nil
		rig.dance = nil
	end
	rig:update(body, simFrame, motor.mode == "attached", motor.moving)
	updateHud(frameDt)
	flyBodies:draw(prey.flies,prey.now)
	local soundPaused = GuiService.MenuIsOpen or panel:isShowing() or menu:isShowing()
	local soundSpeed = if slow then SLOW_SPEED else 1
	local soundMuted = player:GetAttribute("SoundMuted") == true
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
	-- Looking runs in real time, so slow motion never makes the camera sluggish.
	local lx, ly = controls:lookAxes()
	if not panel:isShowing() and not menu:isShowing() then cam:render(frameDt, lx, ly) end
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
			prey = prey, flyBodies = flyBodies, waspBody = waspBody, life = life, wasp = wasp, caughtPanel = panel, needs = needs, checkpoints = checkpoints, returnToCheckpoint = function() returnToCheckpoint() end, lifeSpider = function() return lifeSpider end, sensor = sensor, memory = memory, focusState = focusState, perceptionHud = perceptionHud, stage = stage,
			input = controls,
			session=session, menu=menu, openMenu=openMenu, endLife=endLife, fresh=fresh, continueAnother=continueAnother, currentStore=function() return checkpoints end,
			changeSpider = function() changeSpider() end, dance = function() return dance end, appearance = function() return appearance end, rig = function() return rig end,
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
