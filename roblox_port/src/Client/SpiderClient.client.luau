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
-- The two tarantulas (ROBLOX-81, ROBLOX-82) are the last two in the cycle: costumes on the first spider's body; standing still, X (RB / R1, Rear up) plays
-- a 6 second loop (the threat posture, then a turn about with the spinnerets sweeping like laying a silk mat) until it, a move, a jump or Cancel ends it.
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
local WaspDirector = require(Shared.Predator.WaspDirector)
local SpiderChoice = require(Shared.Rig.SpiderChoice)
local PeacockDance = require(Shared.Rig.PeacockDance)
local PeacockText = require(Shared.UI.PeacockText)
local NotebookPanel = require(script.Parent.NotebookPanel)
local Checkpoint = require(Shared.Persistence.Checkpoint)
local SaveClient = require(script.Parent.SaveClient)
-- The modules that are only used inside functions, in one table (the client is at Luau's limit of 200 locals, and a script must also compile unoptimised: ROBLOX-92).
local M = {
	SettingsPanel = require(script.Parent.SettingsPanel),
	SettingsSpec = require(Shared.Data.SettingsSpec),
	SettingsModel = require(Shared.UI.SettingsModel),
	SaveRules = require(Shared.Data.SaveRules),
	SaveProgress = require(Shared.Persistence.SaveProgress),
	SaveText = require(Shared.UI.SaveText),
	CheckpointStore = require(Shared.Persistence.CheckpointStore),
	NotebookPages = require(Shared.Data.NotebookPages),
	FieldNotebook = require(Shared.Learning.FieldNotebook),
	NotebookWatch = require(Shared.Learning.NotebookWatch),
	NotebookText = require(Shared.UI.NotebookText),
	WaspText = require(Shared.UI.WaspText),
	LifeText = require(Shared.UI.LifeText),
	DayLight = require(Shared.Habitat.DayLight),
	LifeClock = require(Shared.Life.LifeClock),
	HudLayout = require(Shared.UI.HudLayout),
	Heard = require(Shared.UI.Heard),
	-- The world (ROBLOX-94, Client/WorldClient): where the boxes are, which region the spider is in and how fast its day runs, the streaming focus. One instance, here for the same reason: the
	-- client is at Luau's limit of 200 locals.
	World = require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer),
	-- ROBLOX-96 (W3): the world's prey per region (Prey/PreyWorld, kept as M.World.prey) and the drawn woodlice (Client/BugBodies, M.World.bugs); here for the same reason.
	PreyWorld = require(Shared.Prey.PreyWorld),
	BugBodies = require(script.Parent.BugBodies),
	-- ROBLOX-101 (W3b part A): the words for a prey that gets out of the jaws by its own trick (a moth's scales, a crane fly's leg); here for the same reason.
	PreyText = require(Shared.UI.PreyText),
	-- ROBLOX-104: the hooks the Studio-only drivers are handed (the test place's playback, the live place's self-test), made at the end; here for the same reason.
	hooks = (nil :: any),
	-- ROBLOX-106 (W4): nature's rules in Normal (Shared/Life/Nature): what moved last tick, the night's passes counted (never saved), the cover factor this tick and the ray
	-- that finds a leaf overhead (made below, with the raycast params); here for the same reason.
	Nature = require(Shared.Life.Nature),
	nature = { move = {}, night = {}, cover = (nil :: number?), ray = (nil :: any) },
	-- ROBLOX-109: the title card's camera and the intro of a new life (Client/TitleCard, made below with the menus) and their words (UI/TitleText); here for the same reason.
	TitleCard = require(script.Parent.TitleCard),
	TitleText = require(Shared.UI.TitleText),
	title = (nil :: any),
}
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
	return M.SettingsModel.get(function(key: string): any return player:GetAttribute(key) end, id)
end
-- Solo windowsill: the default player list obscures the life-menu button on small screens.
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
local camera = Workspace.CurrentCamera
local sill = M.World.sill -- region 0's folder (ROBLOX-94): its own pieces, the leaf tip; every ray includes M.World.root, the folder of all the regions' boxes
local Breakaway = require(Shared.Habitat.Breakaway)
local breakaway = Breakaway.new(sill,M.World.decor)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { M.World.root }
M.nature.ray = function(from: Vector3, dir: Vector3): any return Workspace:Raycast(from, dir, params) end

local arc = Instance.new("Folder")
arc.Name = "JumpArc"
arc.Parent = Workspace
local motor: any = SpiderMotor.new({
	world = M.World.root, surfaces = Surfaces, profile = Species.phidippus_audax_prototype,
	spawn = M.World.spawnPos, heading = M.World.spawnHeading,
	boundsMin = M.World.boundsMin, boundsMax = M.World.boundsMax, probeParent = arc,
	inBounds = function(p: Vector3): boolean return M.World:inBounds(p) end, -- (ROBLOX-95: out of the world only where no region holds the spider)
})
local jump: any = JumpInput.new()
local carry: any = StickCarry.new()
-- Touch-only devices (phones, tablets) run the low tier until a real tablet frame-time check (ROBLOX_PORT.md): lighter fuzz and
-- no idle extras on the spider, fewer optional parts in the world. Workspace attribute Detail = "low" or "full" overrides the guess.
local detail = Detail.choose(UIS.TouchEnabled and not UIS.KeyboardEnabled, Workspace:GetAttribute("Detail"))
-- Which spider: the Player attribute Appearance (kept for the session), else the Workspace attribute Appearance, else the first spider.
local appearance = SpiderChoice.start(player:GetAttribute("Appearance"), Workspace:GetAttribute("Appearance"))
local rig = SpiderRig.new(Workspace, M.World.root, appearance, detail)
-- The rival's legs (ROBLOX-69): its own SpiderMotor over the whole sill, made when it first arrives, and its drawn rig; its words (ROBLOX-73); its grip once
-- caught (ROBLOX-77, `grip` made below with the reserves). One table: the client is at Luau's limit of 200 locals.
local rivalLegs: any = { drive = nil, rig = nil, Drive = require(Shared.Predator.RivalDrive), Text = require(Shared.UI.RivalText), Grip = require(Shared.Predator.RivalGrip), grip = nil }
-- The mating cycle (ROBLOX-80): its modules, the stage that draws it (the mate's rig, the egg sac, the hatching), the mate's legs, and where the ending is
-- ("" while none, "scene" while the spiderlings play, "card" while the ending card is up). One table: the client is at Luau's limit of 200 locals.
local mateLegs: any = { Mating = require(Shared.Life.Mating), Mate = require(Shared.Predator.Mate), Drive = require(Shared.Predator.MateDrive), Text = require(Shared.UI.MateText),
	Rules = require(Shared.Data.MatingRules), drive = nil, phase = "", pending = nil, state = {},
	-- The mating scene (ROBLOX-89): its pure plan module and its state here (the plan, the scene's seconds as the simulation counts them, the last frame's, the notice held
	-- until it is over, whether it was skipped and whose it was).
	Scene = require(Shared.Life.MatingScene), couple = { active = false, plan = nil, t = -1, prev = -1, notice = nil, skipped = false, mateSex = "" } }
mateLegs.stage = require(script.Parent.MateStage).new(Workspace, M.World.root, detail)
local dance = PeacockDance.new() -- the peacock spider's courtship dance (a pose for the rig; nothing else reads it)
local dancePose: any = nil
-- The ant-mimicking spider's antennae and drawn walk (a pose for the rig; nothing else reads it): the modules, the state, its latest pose, and where
-- the spider was last frame (the distance walked drives the drawn wobble). One table: the client is at Luau's limit of 200 locals.
local ant: any = { Pose = require(Shared.Rig.AntMimicPose), Text = require(Shared.UI.AntMimicText), state = nil, pose = nil, last = nil }
ant.state = ant.Pose.new()
-- The tarantulas' threat display and silk mat (ROBLOX-82), kept in the same table for the same reason: the modules, the state and its latest pose.
ant.Threat, ant.ThreatText = require(Shared.Rig.TarantulaPose), require(Shared.UI.TarantulaText)
ant.threat, ant.threatPose = ant.Threat.new(), nil
local bodyHidden = false
task.spawn(function()
	local roots: { Instance } = { Lighting }
	local decor = Workspace:WaitForChild("Decor", 10)
	if decor then table.insert(roots, decor) end
	local looks = M.World.looks or Workspace:WaitForChild("WorldDecor", 10) -- (ROBLOX-95: the looks of the regions outside the window)
	if looks then table.insert(roots, looks) end
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
local book: any = M.FieldNotebook.new()
local watch: any = M.NotebookWatch.new(book)
memory.categoryChanged:connect(function(_contact: any, _old: string, new: string) watch:onCategory(new) end)
sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local sightCast = Sensor.workspaceCast(params)
local perceptionHud = PerceptionHud.new(player:WaitForChild("PlayerGui"))
local stage = if Workspace:GetAttribute("TestTarget") == true or (Workspace:GetAttribute("TestTarget") ~= false and script.Parent:FindFirstChild("SilkPlayback")) then PerceptionStage.new(sill) else nil
local prey = PreyDirector.engine(M.World.root, Species.fly_like_prototype, 914, 4, true)
local flyBodies = FlyBodies.new(Workspace, detail) -- (ROBLOX-101: the bestiary's bodies draw fewer parts at the low tier)
local soundscape = Soundscape.new(Workspace)
local waspBody = WaspBody.new(Workspace)
-- LIFE (ROBLOX-24): the windowsill runs the life clock, so hunger runs by its hours (NeedsModel life mode, Standard rules to begin with; Easy and Free play
-- switch the model to the gentle rules in applyRules, ROBLOX-91). Feeding grants into the same model. The loop keeps the rest, sleep, daylight and the eyes' reach.
local needs = NeedsModel.new(true, false)
needs:useGameRules()
motor:useGameRules() -- the let-down on a line at half Godot's reel speed (ROBLOX-99, SilkController.game); reeling in keeps its speed
prey.feeding.needs = needs
prey.feeding:useGameRules() -- an easier tap on a struggling fly (ROBLOX-72, Data/Catch.game), scaled by the prey's size (ROBLOX-77); Godot's numbers stay Feeding's defaults
-- ROBLOX-96: the sill's director is the home of the world's prey; the bed's director and its woodlice are made when the bed has arrived whole and the spider is there or
-- beside it, in M.World.garden (what a rest records), sharing the sill director's jaws and casts.
M.World.garden = {}
M.World.prey = M.PreyWorld.new(prey, M.World, M.World.garden, M.World.root, { probe = prey.probe, cast = prey.graph.cast, sweep = prey.graph.sweep, overlap = prey.graph.overlap })
M.World.bugs = M.BugBodies.new(Workspace, detail) -- (ROBLOX-105: the ambient bugs' sheets at the detail tier)
M.World.prey.tier = detail -- (ROBLOX-101: how many of the bestiary's prey a region holds)
rivalLegs.grip = rivalLegs.Grip.new(needs) -- the grip on a caught rival (ROBLOX-77): its own controller, so the fly's is never disturbed
local life = LifeLoop.new(needs, nil)
life.growth:useGameRules(needs.gentle) -- five housefly-equivalents to a moult in the standard rules, not Godot's three; three in the gentle modes (ROBLOX-88/91, Growth.game)
-- The mud dauber wasp (ROBLOX-26): a port of Godot's wasp director (Shared/Predator/WaspDirector). It visits by day from the second day (twice a day in the
-- game, ROBLOX-75), once the first meal is eaten, and not while the spider rests; it is heard (a caption with its direction) for 8 s before it can look.
-- It reads the sill through the same casts as the senses. In the test place it never comes by itself (Workspace attribute Wasp = true
-- allows it); the attribute WaspForce = a place id ("floor_middle") brings it at once, for Studio and playtests. In Easy and Free play (`wasp.gentle`,
-- set with the rules in applyRules) a catch is a touch and the wasp leaves.
local testPlace = script.Parent:FindFirstChild("SilkPlayback") ~= nil
local wasp: any = WaspDirector.new({
	seed = 914, enabled = not testPlace,
	world = {
		ray = function(a: Vector3, b: Vector3): boolean return Workspace:Raycast(a, b - a, params) ~= nil end,
		clear = function(a: Vector3, b: Vector3, radius: number): boolean return Workspace:Spherecast(a, radius, b - a, params) == nil end,
		inRetreat = function(p: Vector3): boolean return M.World:inRetreat(p) ~= nil end,
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
-- The saving's state, in one table (the client is at Luau's limit of 200 locals): the settings the player touched this visit, whether a saved value is being applied (not a touch),
-- the last status and reason told, the last notebook signature and eye seconds sent, when the eye seconds were last looked at; `broken` (ROBLOX-92): the client's saving raised, so it
-- is off for the visit (the game goes on); `look`: a saved spider waiting for the spider to stand safely.
local saveState: any = { touched = {} :: { [string]: boolean }, applying = false, status = nil, reason = nil, sig = "", eye = 0.0, eyeCheck = os.clock(), broken = false, look = nil }
-- Whether a modal screen has the game: the world waits and the controls belong to it. At the very start the world also waits (a second or
-- so at most) for the server to say what is saved, so the start menu shows the right choices; not in the test place unless the Workspace attribute SaveWait is true.
local function modal(): boolean
	return panel:isShowing() or menu:isShowing() or nbPanel:isShowing() or settingsPanel:isShowing()
		or (not menuStarted and (not testPlace or Workspace:GetAttribute("SaveWait") == true) and saveClient ~= nil and saveClient:waiting() == true)
end
-- S01-C retreat checkpoints (ROBLOX-25): resting in the crack, and each morning, keeps one; Backspace / View returns to it. The
-- store is DataStore-shaped but in memory only: a checkpoint lasts the session. No live DataStore is written.
local checkpointWorld: Checkpoint.World = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life, wasp = wasp, breakaway = breakaway, garden = M.World.garden }
local function newStore(): any
	return M.CheckpointStore.new(M.CheckpointStore.MemoryDataStore.new(), function(r: any): { string } return (Checkpoint.check(r, checkpointWorld)) end)
end
-- One last rest for each slot (SaveRules.MODES, ROBLOX-91): the standard main life, the main life on Easy's gentle rules (it shared the main slot, so beginning Easy wiped the standard
-- rest), and free play.
local stores = {main=newStore(), free=newStore(), easy=newStore()}
local checkpoints = stores.main
life.save = function(): LifeLoop.CheckpointResult
	-- The mating cycle (ROBLOX-80): the night's sleep that reached this morning has made the sac, and a rest by a full-grown, well-fed spider makes a mate come, so
	-- this checkpoint keeps what the player has seen and a return to it never loses a night.
	for _, e in life.events do
		if e.kind == "woke" then mateLegs.Mating.woke(life, e.day) end
	end
	-- (ROBLOX-92: a rest that is refused is refused before it changes anything, so the mate's morning is not set by a rest that was not kept; the refusal is in the game's own words)
	local why = Checkpoint.boundaryProblem(checkpointWorld)
	if why ~= "" then return { ok = false, message = M.LifeText.restRefusal(why) } end
	-- (ROBLOX-91: a full-grown spider too hungry for a visitor is told so at its rest; the notice rides with the checkpoint's own words)
	local hungry = if mateLegs.Mating.tooHungry(life) then "\n" .. mateLegs.Text.TOO_HUNGRY else ""
	mateLegs.Mating.atRest(life, life.clock.day, life.clock.hour)
	local record, err = Checkpoint.capture(checkpointWorld, os.time())
	if not record then
		warn("[Windowsill] checkpoint: " .. tostring(err))
		return { ok = false, message = M.LifeText.KEEP_FAILED }
	end
	local r = checkpoints:save(record)
	if not r.ok then warn("[Windowsill] checkpoint: " .. r.message .. ": " .. table.concat(r.errors, "; ")) end
	if r.ok and saveClient ~= nil and not saveState.broken then
		local slot: string = "main" -- (the store this life rests in, by its name)
		for name, st in stores :: { [string]: any } do if st == checkpoints then slot = name end end
		local sent, problem = pcall(function() saveClient:sendRest(slot, record) end) -- (ROBLOX-92: a failing save never takes the rest with it)
		if not sent then saveState.fail(problem) end
	end
	return { ok = r.ok, message = (if r.ok then M.LifeText.restKept(record.world_map.retreat, r.message) else r.message) .. hungry } -- (ROBLOX-96: a rest under the stone says so)
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
  bodyLength = rig:bodyLength(), bodyDrop = rig._drop, -- (inspect mode measures its orbit in body-lengths about the drawn body: ROBLOX-90)
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

-- The display key's pose (the peacock's dance, the ant mimic's raised antennae, the tarantulas' threat display) ends at once: a step, a jump, a rest, a drop, a menu.
function ant.stopDisplay()
	dance:stop()
	ant.state:stop()
	ant.threat:stop()
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
	M.World:refocus() -- (the streaming focus is set on the drawn spider again)
	cam:snap()
end

local controls: any -- bound below (SpiderInput.bind)
local camSettings: any = {} -- the camera's settings, filled each frame (see the render step)

-- Choosing the spider (ROBLOX-31): only while resting awake in the silk-lined crack. The drawn rig is built again with the other appearance;
-- the gait, the eye view and the hidden body carry over; the choice is kept in the Player attribute Appearance for the session.
local function canChange(): boolean
	return life.resting and not life.asleep and not life.growth:isMoulting()
end
-- The spider pick (ROBLOX-71): whether the player chose a spider this visit (only then is the choice sent to be saved), and the one way a choice is
-- made, shared by the crack's key and the Settings row. One table: the client is at Luau's limit of 200 locals.
local spiderPick: any = { touched = false, inspecting = false, jumpSwallow = false, cancelSwallow = false, hold = nil, touchOn = false, Text = require(Shared.UI.InspectText), View = require(Shared.Movement.InspectView) }
local function setAppearance(id: string)
	appearance = id
	player:SetAttribute("Appearance", appearance)
	dance:stop()
	dance = PeacockDance.new()
	dancePose = nil
	ant.state, ant.pose, ant.last = ant.Pose.new(), nil, nil
	ant.threat, ant.threatPose = ant.Threat.new(), nil
	local old = rig
	rig = SpiderRig.new(Workspace, M.World.root, appearance, detail)
	rig.gaitMode = old.gaitMode
	rig:setEyeView(cam.eyeView)
	rig:setBodyHidden(bodyHidden)
	old:destroy()
end
function spiderPick.switch(id: string)
	setAppearance(id)
	spiderPick.touched = true
	if SpiderChoice.hasThreat(appearance) then book:notice("tarantula") end -- choosing a tarantula opens its notebook page (ROBLOX-83)
	if saveClient ~= nil then saveClient:markDirty() end
	hud:toast(PeacockText.changed(appearance), false)
end
local function changeSpider()
	if not canChange() then
		hud:toast(PeacockText.NOT_RESTING, false)
		return
	end
	spiderPick.switch(SpiderChoice.next(appearance))
end
-- A rest in the crack is not a change of spider, but the Settings row is allowed anywhere; the mating scene, the hatching, sleep, a wasp's visit and the rival's windup have the
-- spider, and neither the row nor the close look is allowed then (ROBLOX-92: the row was, in a scene).
function spiderPick.occupied(): boolean
	return mateLegs.couple.active or mateLegs.phase ~= "" or life.asleep or wasp:isVisiting() or spiderPick.rivalThreat()
end
-- The Settings row's side: standing safely (SpiderChoice.safeToChange) anywhere, not only in the crack, and not while something has the spider. Answers the line the panel shows.
function spiderPick.safe(): boolean
	if spiderPick.occupied() then return false end
	return SpiderChoice.safeToChange({
		mode = motor.mode, seized = motor.seized, preparing = motor.preparing, jumping = jump:isBusy(), onLine = motor:onLine(),
		moulting = life.growth:isMoulting(), struggling = prey.feeding.struggling or rivalLegs.Grip.active(rivalLegs.grip),
	})
end
-- The close look's side: the same standing, and the line allowed.
function spiderPick.safeLook(): boolean
	return SpiderChoice.safeToInspect({
		mode = motor.mode, seized = motor.seized, preparing = motor.preparing, jumping = jump:isBusy(), onLine = motor:onLine(),
		moulting = life.growth:isMoulting(), struggling = prey.feeding.struggling or rivalLegs.Grip.active(rivalLegs.grip),
	})
end
function spiderPick.fromSettings(id: any): string?
	if SpiderChoice.start(id, nil) ~= id or id == appearance then return nil end
	if SpiderChoice.locked(id :: string) then return nil end
	if not spiderPick.safe() then
		hud:toast(PeacockText.NOT_NOW, false)
		return PeacockText.NOT_NOW
	end
	spiderPick.switch(id :: string)
	return PeacockText.changed(appearance)
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
	if kind == "threat" then -- the tarantulas: the rear-up and the silk mat, a loop until the key again, a move, a jump or Cancel
		if ant.threat:displaying() then
			ant.threat:stop()
		elseif not ant.threat:start(standing, motor.moving) then
			hud:toast(ant.ThreatText.STAND, false)
		else
			book:notice("tarantula")
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

-- Inspect mode (ROBLOX-90): a slow, close look at the drawn spider. Entered from the Settings row (Inspect your spider) or by holding the choose key / button for
-- spiderPick.View.HOLD_SECONDS while resting awake in the crack (a tap still changes spider, now when it is let go), and only while the spider is standing or hanging on a
-- line safely (SpiderChoice.safeToInspect) and nothing else has the game. The camera does the rest (cam:beginInspect); here are the entry, the exit, the hold and the
-- lock: the controls are the look's (the motor gets the idle input, the buttons that act are nothing, Cancel and the choose key leave, Eye cycles the framings),
-- the simulation keeps running, and a wasp's warning or the rival's windup ends it at once. Nothing here is saved, and nothing reads the camera back.
function spiderPick.rivalThreat(): boolean
	local r = life.rival
	return r ~= nil and (r.state == "windup" or r.state == "lunge")
end
-- Why a close look cannot begin now (a line to say), or nil when it can.
function spiderPick.refusal(): string?
	if not session.started or panel:isShowing() or menu:isShowing() or nbPanel:isShowing() or spiderPick.occupied() or not spiderPick.safeLook() then
		return spiderPick.Text.NOT_NOW
	end
	return nil
end
function spiderPick.begin(): string?
	local why = spiderPick.refusal()
	if why ~= nil then
		hud:toast(why, false)
		return why
	end
	spiderPick.hold = nil
	controls:clear() -- (everything held is let go, with no penalty; dropAll is its clear handler)
	feedPending, cancelPending = false, false
	rig.focusPoint = nil
	if not cam:beginInspect() then return spiderPick.Text.NOT_NOW end
	spiderPick.inspecting = true
	hud:setNote("", 0)
	return nil
end
-- Ends it. `why`, if given, is told; `instant` cuts the camera back (a danger, a screen), otherwise it eases (0.8 s; a cut in Reduced Motion).
function spiderPick.finish(why: string?, instant: boolean)
	if not spiderPick.inspecting then return end
	spiderPick.inspecting = false
	cam:endInspect(instant)
	if why ~= nil then hud:toast(why, if why == spiderPick.Text.DANGER then "danger" else instant) end -- (a danger is kept on the screen until it has had its seconds: ROBLOX-92)
end
function spiderPick.inspectFromSettings(): string?
	local why = spiderPick.refusal()
	if why ~= nil then
		hud:toast(why, false)
		return why
	end
	settingsPanel.returnTo = "game" -- (even from the life menu: the close look is the game's)
	settingsPanel:close()
	return spiderPick.begin()
end
-- The choose key (C), or RB in the crack on a controller, or the touch Change button went down: a hold of HOLD_SECONDS starts the close look and a tap, let go sooner,
-- changes spider. In the look the same press leaves it. Anything else RB does (the dance, outside the crack) is as it was.
function spiderPick.press(action: string)
	if mateLegs.couple.active then return end
	if spiderPick.inspecting then
		spiderPick.finish(nil, false)
		spiderPick.hold = { action = action, t = 0, fired = true } -- (letting go of this press is nothing)
		return
	end
	if action == "Display" and not (life.resting and device == "gamepad" and not life.asleep) then
		toggleDance()
		return
	end
	if canChange() then spiderPick.hold = { action = action, t = 0, fired = false } else changeSpider() end
end
function spiderPick.release(action: string, cancelled: boolean?)
	local h = spiderPick.hold
	if h == nil or h.action ~= action then return end
	spiderPick.hold = nil
	if not h.fired and cancelled ~= true then changeSpider() end -- (a button hidden under the finger took the press away: nothing is changed, ROBLOX-92)
end
-- Each rendered frame, in real time: the hold's clock, and the reasons to leave the look (a danger first: the wasp, the rival's windup; then anything that makes the spider
-- unsafe to change, a scene or a screen that has the game).
function spiderPick.update(frameDt: number)
	local h = spiderPick.hold
	if h ~= nil then
		if controls.held[h.action] ~= true or modal() then
			spiderPick.hold = nil -- (let go by something else: focus lost, a menu, a hidden button; nothing changes)
		elseif not h.fired then
			h.t += frameDt
			if h.t >= spiderPick.View.HOLD_SECONDS then
				h.fired = true
				if canChange() then spiderPick.begin() end
			end
		end
	end
	if spiderPick.inspecting then
		if wasp:isVisiting() or spiderPick.rivalThreat() then
			spiderPick.finish(spiderPick.Text.DANGER, true)
		elseif modal() or GuiService.MenuIsOpen then
			spiderPick.finish(nil, true) -- (a menu, the notebook, the settings, the catch screen or Roblox's own menu has the game: the look is simply over)
		elseif mateLegs.couple.active or mateLegs.phase ~= "" or life.asleep or not spiderPick.safeLook() then
			spiderPick.finish(spiderPick.Text.ENDED, true)
		end
	end
end
-- The touch buttons while looking: only the arrows (zoom), Back (Cancel) and View (Eye); everything comes back when it ends. Called every frame.
function spiderPick.touchFrame()
	local on: boolean = spiderPick.inspecting
	if on then
		for _, a in { "Left", "Right", "Jump", "Creep", "Drop", "Recenter", "Focus", "Feed", "Choose", "Display" } do controls:setTouchVisible(a, false) end
		controls:setTouchLabel("Cancel", spiderPick.Text.TOUCH_BACK)
		controls:setTouchLabel("Eye", spiderPick.Text.TOUCH_VIEW)
	elseif spiderPick.touchOn then
		for _, a in { "Left", "Right", "Jump", "Creep", "Drop", "Recenter", "Focus", "Feed" } do controls:setTouchVisible(a, true) end
		controls:setTouchLabel("Eye", "Eye")
	end
	spiderPick.touchOn = on
end

-- Backspace / View: back to the retreat checkpoint (the whole sill as it was), or to the start when there is none yet.
local function returnToCheckpoint()
	spiderPick.finish(nil, true) -- (a close look does not survive a return to the last rest)
	local best = checkpoints:loadBest()
	if not best.ok then
		mateLegs.skip(true) -- (a scene is not left playing round a spider put back at the start: the pair part, ROBLOX-89)
		backToStart()
		hud:toast(if best.message == "no last rest to return to" then "No last rest yet: back to the start. Rest in the silk-lined crack to keep one." else "Back to the start: " .. best.message, true)
		return
	end
	jump:drop(motor)
	ant.stopDisplay()
	local ok, problems = Checkpoint.restore(best.record, checkpointWorld)
	if not ok then
		warn("[Windowsill] checkpoint refused: " .. table.concat(problems, "; "))
		hud:toast("The last rest could not be used: " .. (problems[1] or "unknown"), true)
		return
	end
	session.mode, session.rules, session.ended = life.mode or "main", life.rules or "standard", false
	session.started = true -- (ROBLOX-109: a life is running from a rest too: the title card is over, and the life menu offers Resume)
	table.clear(M.nature.night) -- (ROBLOX-106: the night's passes are counted again from the restored hour)
 mateLegs.reset()
 needs:useGameRules()
 prey.feeding:useGameRules() -- (always: a record from before, or one made by another build, may hold Godot's struggle)
 life.growth:useGameRules(needs.gentle) -- (a record from before has Godot's threshold; Checkpoint.restore has set the record's rules)
 motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
 session:finishAdult(life.growth.stage)
	session.summary = nil
	controls:clear()
	focusState:clear()
	dropStrands(false)
	drawnUp = motor.up
	M.World:refocus()
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
 needs.gentle=session.rules=="gentle";wasp.gentle=needs.gentle
 needs:useGameRules()
 prey.feeding:useGameRules()
 life.growth:useGameRules(needs.gentle)
end
local function closeScreens()
 panel:hide();menu:hide();setHudShown(true);controls:clear();dropAll()
 if M.title then M.title:stop() end -- (ROBLOX-109: a new life, a rest or Resume ends an intro that was playing)
end
local function fresh(mode: string, easy: boolean, position: Vector3?): boolean
 if not initialRecord or (easy and not session.finishedMain) then return false end
 spiderPick.finish(nil, true)
 local ok=Checkpoint.restore(initialRecord,checkpointWorld)
 if not ok then return false end
 mateLegs.reset()
 session:begin(mode,easy);applyRules();motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
 sensor:reset();memory:clear();table.clear(M.nature.night)
 local slot=M.SaveRules.slotOf(mode,session.rules)
 stores[slot]=newStore();checkpoints=stores[slot]
 life.resting=false;life.notice="";life.noticeSeconds=0;life.restoreGrace=0
 wasp:load(WaspDirector.defaultRecord());wasp.gentle=needs.gentle
 if position then motor:place(position,Vector3.yAxis,M.World.spawnHeading) end
 closeScreens();dropStrands(false);drawnUp=motor.up;M.World:refocus();cam:snap();lastLight=nil
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
 return {cause=cause,hours=math.max((life.clock.day-1)*24+life.clock.hour-M.LifeClock.START_H,0),
  meals=prey.feeding.mealsFinished,wasp_visits=wasp.visits,wasp_escapes=wasp.escapes,stage=life.growth.stage}
end
local openNotebook: (string?) -> ()
local lastEnd: any=nil -- the summary of the life that just ended, while its end screen is up
panel=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Notebook" then openNotebook("end")
 elseif choice=="Carry" then mateLegs.carryOn()
 elseif choice=="Another" then lastEnd=nil;continueAnother()
 elseif choice=="Back" then lastEnd=nil;closeScreens();wasp:clearVisit();returnToCheckpoint() end
end)
local function presentEnd(immediate: boolean)
 local rec=lastEnd
 if not rec then return end
 local cause=rec.cause
 local choices: {CaughtPanel.Choice}={}
 local hasRest=checkpoints:loadBest().ok
 if hasRest then table.insert(choices,{id="Back",text="Back to your last rest"}) end
 table.insert(choices,{id="Another",text=mateLegs.Text.another(mateLegs.Mating.hasSac(life.mating))}) -- (ROBLOX-91: a new life; the brood is left behind)
 table.insert(choices,{id="Notebook",text=M.NotebookText.MENU_CHOICE})
 -- (ROBLOX-106: in Normal the last line says what the way back costs, the day since the rest, and that another spider is a new life; the night has its own words)
 panel:showChoices(if cause=="starved" then "The spider starved." elseif cause=="rival" then "The other spider caught you." elseif cause=="night" then M.LifeText.NIGHT_LINE else M.WaspText.LINE,
  if cause=="starved" then "It went too long without food." elseif cause=="rival" then "A hunter can become prey. You can return to your last rest." elseif cause=="night" then M.LifeText.NIGHT_SUB else M.WaspText.SUB,
  M.WaspText.summary(rec.hours,rec.meals,rec.wasp_visits,rec.wasp_escapes)..(if session.rules=="standard" then "\n"..M.LifeText.dayLost(hasRest) else ""),choices,immediate)
 panel:setTextScale(if setting("LargeText")==true then 1.5 else 1)
end
local function endLife(cause: string)
 local rec=summaryRecord(cause)
 if not session:endLife(cause,rec) then return end
 mateLegs.coupleEnd(false)
 controls:clear();dropAll();setHudShown(false)
 lastEnd=rec
 presentEnd(false)
end
local function showCaught() endLife("wasp") end
-- ---------------------------------------------------------------- the mating cycle (ROBLOX-80)
-- Display and the player's side of Life/Mating (which is the cycle itself). The events Mating.tick reports become notices; the hatching plays as a scene in the
-- crack (about 26 s, the camera and the controls free); the ending card follows it, and Carry on makes the next generation.
function mateLegs.say(text: string?)
 if text ~= nil and text ~= "" then life:showNotice(text);life.noticeSeconds=8 end
end
-- Whether the spider could hear or see the mate where it is (ROBLOX-92: the rival's rule, UI/Heard): within earshot, or in clear sight and not too far.
function mateLegs.heard(mate: any): boolean
	local far=(mate.position-motor.pos).Magnitude
	return M.Heard.within(far,far<=M.Heard.farthest() and not sightCast(motor.pos,mate.position))
end
function mateLegs.event(e: string,ms: any)
 local mate=life.mate
 if e=="courted" then mateLegs.coupleBegin() end
 local text=mateLegs.Text.notice(e,{sex=if mate then mate.sex else nil,needsDance=ms.needsDance,device=device,reason=if mate then mate.reason else nil})
 -- A visitor far off and out of sight is not heard arriving, noticing the spider or going (ROBLOX-92). Its arrival is held and told when it first comes within earshot or sight; the rest is simply not told.
 if (e=="arrived" or e=="noticed" or e=="gone") and mate~=nil and not mateLegs.heard(mate) then
  if e=="arrived" then mateLegs.pending=text elseif e=="gone" then mateLegs.pending=nil end
  text=nil
 elseif e=="gone" or e=="arrived" then mateLegs.pending=nil end
 -- A male mate's walk off the sill is still the scene's last beat: its parting is told when the scene is over (a notice over the two-shot would be read for the captions).
 if e=="mated" and mateLegs.couple.active and mate~=nil and mate.scene==true then mateLegs.couple.notice=text else mateLegs.say(text) end
 if e=="hatched" then mateLegs.begin(true) end
end
-- The mating scene (ROBLOX-89). Its clock is the simulation's own (Predator/Mate.sceneTime: the pair's pause, then the male's walk off), so a wasp visit holds it as it holds the
-- mate, a menu holds it with everything and a rest cannot land inside it (Checkpoint.boundaryProblem). Here it is only drawn: the controls are the scene's (locked but for the
-- skip, tickInput and the handlers), the camera is the two-shot, both rigs take the cues, the captions, the music swells; Life/Mating owns the parting.
-- The scene and the hatching have the view (ROBLOX-92): a close look in progress ends first, and does not give the eye view back over them.
function mateLegs.takeView()
 cam:cancelEyeRestore()
 spiderPick.finish(nil,true)
end
function mateLegs.coupleBegin()
 local c,mate=mateLegs.couple,life.mate
 if c.active or mate==nil or mate.scene~=true then return end
 c.active,c.t,c.prev,c.notice,c.skipped,c.mateSex,c.turn,c.focus=true,-1,-1,nil,false,mate.sex,nil,nil
 c.plan=mateLegs.Scene.plan(914,if life.mating then life.mating.mates else 0,life.clock.day,mateLegs.Mating.sexOf(appearance))
 mateLegs.takeView();dropAll();cam:setEyeView(false);feedPending,cancelPending=false,false
 soundscape:setSwell(true)
end
-- The scene is over: the camera and the music go back, the rigs let go of their poses, the parting is told and (when it was seen to its end) the notebook gets its line.
-- `saw` is false when the world was reset under it (a rest returned to, a new life, the end of this one).
function mateLegs.coupleEnd(saw: boolean)
 local c=mateLegs.couple
 if not c.active then return end
 c.active=false
 cam:setShot(nil);soundscape:setSwell(false)
 rig.focusPoint=nil;rig:cue("release")
 if mateLegs.stage.rig~=nil then mateLegs.stage.rig:cue("release") end
 if not saw then c.notice,c.focus,c.turn=nil,nil,nil;return end
 mateLegs.say(c.notice);c.notice=nil
 if c.plan~=nil then book:addEntry("eggs_and_wind",c.plan.day,mateLegs.Text.entry(c.plan.day,c.mateSex)) end
end
-- A jump or cancel during the scene: a skip, allowed after Scene.SKIP_AFTER seconds of it (`force`: a wasp visit, which cannot wait). The pair part at once and the mate
-- walks off in play; the sac, the guard and the hatching are the same.
function mateLegs.skippable(mate: any): boolean
 local t=mateLegs.Mate.sceneTime(mate)
 return t~=nil and mateLegs.Scene.canSkip(t)
end
function mateLegs.skip(force: boolean)
 local c,mate=mateLegs.couple,life.mate
 if not c.active or mate==nil then return end
 local t=mateLegs.Mate.sceneTime(mate)
 if force~=true and (t==nil or not mateLegs.Scene.canSkip(t)) then return end
 local events=mateLegs.Mating.skip(life,force)
 if mate.scene==true then return end
 c.skipped=true
 for _,e in events do mateLegs.event(e,{}) end
 mateLegs.coupleEnd(true)
end
-- Each frame (before the rigs are drawn): the scene's seconds from the simulation, the cues that fell due, the camera's two-shot, who looks at whom and the female mate's turn away.
function mateLegs.coupleFrame(reduced: boolean,frameDt: number)
 local c,mate=mateLegs.couple,life.mate
 local t=if mate~=nil then mateLegs.Mate.sceneTime(mate) else nil
 if t==nil then
  mateLegs.coupleEnd(true)
  if c.turn~=nil then -- (a female mate turned away walks off: the drawn turn lets go over half a second rather than snapping)
   local step=math.rad(mateLegs.Scene.TURN_AWAY_DEG)/0.5*frameDt
   c.turn=if math.abs(c.turn)<=step then nil else c.turn-step*(if c.turn>0 then 1 else -1)
  end
  return
 end
 if not c.active then
  if session.ended then return end
  mateLegs.coupleBegin()
 end
 local plan=c.plan
 if plan==nil then return end
 c.prev,c.t=c.t,t
 local mine,mateRig=mateLegs.Mating.sexOf(appearance),mateLegs.stage.rig
 for _,q in mateLegs.Scene.cues(c.prev,t) do
  rig:cue(q.name,q.seconds[mine])
  if mateRig~=nil then mateRig:cue(q.name,q.seconds[mate.sex]) end
 end
 cam:setShot(mateLegs.Scene.shot(plan,t,reduced,motor.pos,mate.position,motor.up))
 rig.focusPoint=mate.position
 c.focus=if mate.state=="pair" then motor.pos else nil
 c.turn=mateLegs.Scene.turnAway(plan,t,reduced)*math.rad(mateLegs.Scene.TURN_AWAY_DEG)*plan.turnSign
end
-- The hatching begins: with its scene (the eggs hatch while the player is there), or, for a record restored into it, at the card at once.
function mateLegs.begin(scene: boolean)
 local m=life.mating
 if m==nil or m.stage~="hatched" then return end
 mateLegs.takeView()
 book:notice("hatched")
 if scene then
  mateLegs.stage:begin(914,mateLegs.Mating.generation(life),m.hatch_day,m.brood)
  mateLegs.phase="scene"
 else
  mateLegs.showCard(true)
 end
end
function mateLegs.showCard(immediate: boolean)
 local m=life.mating
 if m==nil then return end
 local title,sub,body=mateLegs.Text.card(m.brood,m.hatch_day,mateLegs.Mating.generation(life))
 controls:clear();dropAll();setHudShown(false)
 panel:showChoices(title,sub,body,{{id="Carry",text=mateLegs.Text.BUTTON}},immediate)
 panel:setTextScale(if setting("LargeText")==true then 1.5 else 1)
 mateLegs.phase="card"
end
-- A night's sleep reached the morning (LifeLoop's woke): after mating it made the sac (life.save may already have recorded it).
function mateLegs.woke(day: number)
 mateLegs.Mating.woke(life,day)
 local m=life.mating
 if m~=nil and m.stage=="sac" and m.sac_day==day then mateLegs.say(mateLegs.Text.SAC) end
end
-- Everything of the cycle that is only on the screen goes (a new life, a rest returned to).
function mateLegs.reset()
 mateLegs.coupleEnd(false)
 mateLegs.couple.focus,mateLegs.couple.turn=nil,nil
 mateLegs.phase,mateLegs.pending="",nil
 mateLegs.stage:reset()
end
-- Carry on: the next generation is a spiderling again in the crack, the days of the sill go on, the notebook and the look are the player's own.
function mateLegs.carryOn()
 local generation,day=mateLegs.Mating.carryOn(life,needs,prey.feeding.mealsFinished)
 lastEnd=nil
 closeScreens()
 mateLegs.reset()
 setAppearance(appearance) -- the rig is built again, at the first growth stage
 motor:place(Vector3.new(-25.5,0.31,6.0),Vector3.yAxis,M.World.spawnHeading)
 motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor())
 sensor:reset();memory:clear()
 dropStrands(false);drawnUp=motor.up;M.World:refocus();cam:snap();lastLight=nil
 feedPending,cancelPending=false,false
 watch:resync()
 hud:toast(mateLegs.Text.generationToast(generation,day),false)
 if saveClient~=nil then saveClient:markDirty() end
end
local openMenu: () -> ()
local openSettings: (string?) -> ()
local confirming: string?=nil
menu=CaughtPanel.new(player:WaitForChild("PlayerGui"),function(choice: string)
 if choice=="Notebook" then openNotebook("menu");return end
 if choice=="Settings" then openSettings("menu");return end
 if choice=="Resume" then closeScreens();return end
 if choice=="Controls" then closeScreens();helpVisible,helpUntil=true,math.huge;return end -- (the controls card, kept up until H puts it away: ROBLOX-92)
 if choice=="Continue" then checkpoints=stores.main;closeScreens();returnToCheckpoint();return end
 if choice=="ContinueEasy" then checkpoints=stores.easy;closeScreens();returnToCheckpoint();return end
 if choice=="Free" then
  local saved=stores.free:loadBest()
  if saved.ok then checkpoints=stores.free;closeScreens();returnToCheckpoint()
  elseif fresh("free",false,nil) then M.title:beginIntro(M.title.always(),needs.gentle) end -- (ROBLOX-109: the intro, once in a save)
  return
 end
 if choice=="New" or choice=="Easy" then
  if session.started and confirming~=choice then
   confirming=choice
   menu:showChoices("Begin a new life?",if choice=="Easy" then "This replaces the Easy life's last rest as soon as the new spider rests. The standard life's last rest is kept." else "This replaces the standard life's last rest as soon as the new spider rests. The Easy life's last rest is kept.","",
    {{id=choice :: string,text="Begin the new life"},{id="CancelNew",text="Keep this life"}},true,"CancelNew")
   return
  end
  confirming=nil;session:archive()
  if fresh("main",choice=="Easy",nil) then M.title:beginIntro(M.title.always(),needs.gentle) end -- (ROBLOX-109: the intro, once in a save)
  return
 end
 confirming=nil;openMenu()
end,"SpiderLifeMenu")
-- The start menu's body: the saving line, then the Easy note. Also rewritten in place when the saving status changes under an open menu.
local function menuBody(): string
 return (if saveState.broken then M.SaveText.brokenLine() else M.SaveText.menuLine(saveClient:status()))..(if session.finishedMain then "" else "\nEasy is not available yet; choose Free play for gentle rules.")
end
-- ROBLOX-109: before a life has begun this visit the start menu is the title card (CaughtPanel's "title" look over the drifting camera): Continue when a rest
-- exists, a new life, Free play, Settings, and the Notebook once it has pages, the saving note in small type under them. In a life it is the life menu
-- (the card look), with Resume (the back button's choice) and Controls first. The discovery notes and the text size are in Settings (ROBLOX-49).
openMenu=function()
 if panel:isShowing() or not initialRecord then return end
 controls:clear();dropAll();setHudShown(false)
 local started=session.started
 local choices: {CaughtPanel.Choice}={}
 local function add(id: string) table.insert(choices,{id=id,text=M.TitleText.choice(id,started)}) end
 if started then add("Resume");add("Controls") end
 if stores.main:loadBest().ok then add("Continue") end
 if stores.easy:loadBest().ok then add("ContinueEasy") end
 add("New")
 if session.finishedMain then add("Easy") end
 add("Free")
 table.insert(choices,{id="Settings",text=M.SettingsSpec.WORDS.menuChoice})
 if started or #book.opened>0 then table.insert(choices,{id="Notebook",text=M.NotebookText.MENU_CHOICE}) end
 menu:setLook(if started then "card" else "title")
 menu:showChoices(M.TitleText.TITLE,M.TitleText.SUBTITLE,menuBody(),choices,true,if started then "Resume" else nil)
 menu:setHint(M.TitleText.navHint(device))
 menu:setTextScale(if setting("LargeText")==true then 1.5 else 1)
end
local menuButton=Instance.new("TextButton")
menuButton.Name="LifeMenu";menuButton.Text="Menu";menuButton.TextSize=18
menuButton.BackgroundColor3=Color3.new(.12,.12,.14);menuButton.TextColor3=Color3.new(1,1,1)
menuButton.Parent=hud.safe;menuButton.Activated:Connect(openMenu)

-- The naturalist's notebook (ROBLOX-37). Opened from the game (N, the button beside Menu), the life menu or the end screen; closing it
-- goes back to wherever it was opened from. The world waits while it is open (modal()).
local function noteScale(): number
 return if setting("LargeText")==true then M.NotebookText.LARGE else 1
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
 if page and setting("NotebookNotes") then hud:setNote(M.NotebookText.note(page.title,device),M.NotebookPages.noteSeconds) end
end)
local notebookButton=Instance.new("TextButton")
notebookButton.Name="NotebookButton";notebookButton.Text=M.NotebookText.BUTTON;notebookButton.TextSize=16
notebookButton.BackgroundColor3=Color3.new(.12,.12,.14);notebookButton.TextColor3=Color3.new(1,1,1)
notebookButton.Parent=hud.safe;notebookButton.Activated:Connect(function() openNotebook("game") end)
-- Both buttons are touch targets (48 px tall) and clear of the status lines at every screen size (HudLayout.topLayout, tested).
local function placeTopButton(button: TextButton,r: { x0: number, y0: number, x1: number, y1: number })
 button.Position=UDim2.fromOffset(r.x0,r.y0);button.Size=UDim2.fromOffset(r.x1-r.x0,r.y1-r.y0)
end
local function placeTopButtons()
 local size=hud.safe.AbsoluteSize
 local t=M.HudLayout.topLayout(size.X,size.Y)
 placeTopButton(menuButton,t.menu);placeTopButton(notebookButton,t.notebook)
end
hud.safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTopButtons)
placeTopButtons()

-- The settings (ROBLOX-49). Opened from the life menu or with O; closing it goes back to wherever it was opened from. The world waits while
-- it is open (modal()). The values live as Player attributes named by SettingsSpec ids (the panel asks setting(), tells player:SetAttribute),
-- so the saving that already watches them (below) keeps them and every consumer in this script reads them live. The one exception is the Spider
-- row (ROBLOX-71, SettingsModel.live): it reads `appearance` and asks spiderPick, so the spider is kept in the save as before, not as a setting.
settingsPanel=M.SettingsPanel.new(player:WaitForChild("PlayerGui"),{
 get=function(id: string): any
  if M.SettingsModel.live(id) then return appearance end
  return setting(id)
 end,
 set=function(id: string,value: any): string?
  if id=="Inspect" then return spiderPick.inspectFromSettings() end -- (a button, ROBLOX-90: it closes the panel into the close look, or says why not)
  if M.SettingsModel.live(id) then return spiderPick.fromSettings(value) end
  player:SetAttribute(id,value)
  return nil
 end,
 reset=function() for _,id in M.SettingsModel.ids() do player:SetAttribute(id,M.SettingsModel.default(id)) end end,
 status=function(): string? if saveState.broken then return "session" end;local status=saveClient:status();return status end,
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

-- The title card's camera and the intro of a new life (ROBLOX-109, Client/TitleCard). The intro puts the spider in the crack and walks it out (tickInput),
-- has the controls (SpiderInput's blocked) and the camera (the render step) while it holds, and gives the controls card and the walking hint their time
-- afresh when it ends. Not in the test place, which has no start menu (the self-test plays the intro through its hook).
-- In Studio the Workspace attribute IntroAlways = true plays the intro for every new life from the menu, seen or not (for looking at it; nothing outside Studio reads it).
M.title = M.TitleCard.new({
 playerGui = player:WaitForChild("PlayerGui"), camera = camera, enabled = not testPlace, clock = time,
 reduced = function(): boolean return setting("ReducedMotion") == true end,
 device = function(): string return device end,
 spider = function(): Vector3 return motor.pos end,
 place = function(position: Vector3, heading: Vector3)
  controls:clear();jump:drop(motor)
  motor:place(position,Vector3.yAxis,heading)
  dropStrands(false);drawnUp=motor.up;cam:snap()
 end,
 gameCamera = function(dt: number): CFrame cam:render(dt,0,0);return camera.CFrame end,
 onBegin = function() controls:clear();dropAll();setHudShown(false) end,
 onEnd = function()
  setHudShown(true)
  if helpUntil ~= math.huge then helpVisible,helpUntil=true,os.clock()+20 end
  started=os.clock()
 end,
})
M.title.always = function(): boolean return RunService:IsStudio() and Workspace:GetAttribute("IntroAlways") == true end
-- ---------------------------------------------------------------- persistent saves (ROBLOX-39)
-- What this visit changed is sent up (the notebook and an adult life always; the spider and the toggles only if the player changed them, so
-- a late reply can never be overwritten by defaults). What the server sends down is applied once, before the start menu, and again if a
-- retry succeeds later: the notebook and the adult life are only ever added to, the rest of the choices only if the player has not already
-- made their own this visit.
local function refreshMenu()
	if menuStarted and menu:isShowing() and confirming == nil then openMenu() end
end
local function progressSnapshot(): any
	local settings: { [string]: any } = {}
	for key in saveState.touched do settings[key] = player:GetAttribute(key) end -- (the snapshot sends only what is clean)
	return M.SaveProgress.snapshot(book:toRecord(), session.finishedMain, if spiderPick.touched then appearance else nil, settings, M.title.seen) -- (ROBLOX-109: the intro seen)
end
local function adoptRest(mode: string, record: any)
	if record == nil or stores[mode] == nil then return end
	if session.started or stores[mode]:loadBest().ok then return end -- this visit has begun, or already has a rest of its own
	local r = stores[mode]:save(record)
	if not r.ok then warn("[Windowsill] saved " .. mode .. " rest not used: " .. r.message .. ": " .. table.concat(r.errors, "; ")) end
end
local function applySaved(msg: any)
	if type(msg) ~= "table" then return end
	local _, p = M.SaveProgress.sanitize(msg.progress)
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
		if p.intro_seen then M.title.seen = true end -- (ROBLOX-109: this save has seen the intro)
		saveState.applying = true
		for key, v in p.settings do
			if not saveState.touched[key] then player:SetAttribute(key, v) end
		end
		saveState.applying = false
		if p.appearance ~= nil and not spiderPick.touched and p.appearance ~= appearance and SpiderChoice.start(p.appearance, nil) == p.appearance then
			saveState.look = p.appearance -- (ROBLOX-92: the saved spider is put on when the spider stands safely, saveState.settleLook; at the start that is at once)
		end
	end
	if type(msg.rests) == "table" then
		adoptRest("main", msg.rests.main)
		adoptRest("free", msg.rests.free)
		adoptRest("easy", msg.rests.easy)
	end
	saveState.sig = `{#book.opened}:{session.finishedMain}:{M.title.seen}`
	saveState.eye = book.eyeSeconds
	if nbPanel:isShowing() then nbPanel:refresh() end
	if settingsPanel:isShowing() then settingsPanel:refresh() end
	if not setting("ControlHints") and helpUntil ~= math.huge then helpVisible = false end
	refreshMenu()
end
saveClient = SaveClient.new({
	rules = M.SaveRules, now = os.clock,
	findRemotes = function(): any
		local folder = ReplicatedStorage:FindFirstChild(M.SaveRules.REMOTES_NAME)
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
saveState.sig = `{#book.opened}:{session.finishedMain}:{M.title.seen}`
for _, key in M.SettingsModel.ids() do
	player:GetAttributeChangedSignal(key):Connect(function()
		if saveState.applying then return end
		saveState.touched[key] = true
		saveClient:markDirty()
	end)
end
-- Each frame: the connection, what changed, and the status (a toast when it changes, a fresh menu line).
local function updateSaves()
	saveClient:update()
	local sig = `{#book.opened}:{session.finishedMain}:{M.title.seen}`
	if sig ~= saveState.sig then
		saveState.sig = sig
		saveClient:markDirty()
	end
	local t = os.clock()
	if t - saveState.eyeCheck >= M.SaveRules.CLIENT_EYE_GAP then
		saveState.eyeCheck = t
		if book.eyeSeconds ~= saveState.eye then
			saveState.eye = book.eyeSeconds
			saveClient:markDirty()
		end
	end
	local status, reason = saveClient:status()
	if status ~= nil and (status ~= saveState.status or reason ~= saveState.reason) then
		local text = M.SaveText.toast(saveState.status, saveState.reason, status, reason)
		saveState.status, saveState.reason = status, reason
		if text ~= "" then hud:toast(text, status == "session") end
		if menuStarted and menu:isShowing() and confirming == nil then menu.summary.Text = menuBody() end
	end
end

-- A saved spider waiting to be put on (applySaved): dropped if the player has chosen one since; put on once the spider is standing safely (never in a scene, asleep or in a danger).
function saveState.settleLook()
	local want = saveState.look
	if want == nil then return end
	if spiderPick.touched or want == appearance then saveState.look = nil;return end
	if spiderPick.safe() then
		saveState.look = nil
		setAppearance(want)
	end
end
-- The saving broke (ROBLOX-92): it is off for the rest of the visit, said once on the status line and in the log; the game goes on.
function saveState.fail(err: any)
	if saveState.broken then return end
	saveState.broken = true
	warn("[Windowsill] saving is off for this visit: " .. tostring(err))
	hud:toast(M.SaveText.BROKEN, true)
	if menuStarted and menu:isShowing() and confirming == nil then menu.summary.Text = menuBody() end
end
-- The saving's part of each frame: nothing the saving does can stop the frame (and once it has failed, nothing more is tried).
function saveState.frame()
	saveState.settleLook()
	if saveState.broken then return end
	local ok, err = pcall(function(): any updateSaves(); return nil end)
	if not ok then saveState.fail(err) end
end

controls = SpiderInput.bind({
	blocked = function(): boolean return modal() or M.title:holding() end, -- (ROBLOX-109: the intro has the controls while it holds)
	menu = function() if settingsPanel:isShowing() then settingsPanel:close() elseif nbPanel:isShowing() then nbPanel:close() elseif menu:isShowing() and session.started then closeScreens() else openMenu() end end,
	notebook = function() openNotebook("game") end,
	settings = function() openSettings("game") end,
	focus = function(phase: string)
		if spiderPick.inspecting then return end
		if phase == "begin" then focusState:press(setting("FocusToggle") == true, motor.mode == "attached")
		elseif phase == "cancel" then focusState:clear() end
	end,
	choose = function() spiderPick.press("Choose") end,
	chooseEnd = function(cancelled: boolean?) spiderPick.release("Choose", cancelled) end,
	display = function() spiderPick.press("Display") end,
	displayEnd = function(cancelled: boolean?) spiderPick.release("Display", cancelled) end,
	feed = function()
		if mateLegs.couple.active or spiderPick.inspecting then return end
		ant.stopDisplay()
		prey.feeding:press()
		if rivalLegs.Grip.active(rivalLegs.grip) then rivalLegs.Grip.tap(rivalLegs.grip) end -- (the Eat key grips a caught rival too, like the Jump key: ROBLOX-92)
		feedPending = true -- in the crack, with nothing to eat, the same button rests (Godot's interact)
	end,
	jump = function(phase: string)
  if spiderPick.inspecting then -- the close look: a jump press leaves it (and is nothing else; what is left of the press is swallowed)
   if phase == "begin" then spiderPick.finish(nil, false);spiderPick.jumpSwallow = true end
   return
  end
  if spiderPick.jumpSwallow then if phase ~= "begin" then spiderPick.jumpSwallow = false;return end;spiderPick.jumpSwallow = false end
  if life.growth:isMoulting() then return end
  if mateLegs.couple.active then -- the mating scene (ROBLOX-89): the buttons are its skip, and what is left of a press is swallowed like a grip's
   if phase == "begin" then mateLegs.skip(false);gripPress=true elseif gripPress then gripPress=false end
   return
  end
		if phase == "begin" and (prey.feeding.struggling or rivalLegs.Grip.active(rivalLegs.grip)) then
			if prey.feeding.struggling then prey.feeding:press() end
			if rivalLegs.Grip.active(rivalLegs.grip) then rivalLegs.Grip.tap(rivalLegs.grip) end -- the same button grips a caught rival (ROBLOX-77)
			gripPress=true; return
		end
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
		if phase ~= "begin" then spiderPick.cancelSwallow = false;return end
		spiderPick.cancelSwallow = false
		if spiderPick.inspecting then spiderPick.finish(nil, false);spiderPick.cancelSwallow = true;return end -- (Cancel leaves the close look, and is nothing else; what is left of the press is swallowed, so a held Q never lets go of the line: ROBLOX-92)
		if mateLegs.couple.active then mateLegs.skip(false);return end
		ant.stopDisplay()
		cancelPending = true -- also ends a rest
		prey.feeding:cancel()
		if motor:cancelWalk() then return end
		focusState:cancel(jump:isBusy() or #jump.events > 0 or motor:onLine())
		jump:cancel()
	end,
	drop = function() if life.growth:isMoulting() or mateLegs.couple.active or spiderPick.inspecting then return end; ant.stopDisplay(); motor:requestDrop() end,
	clear = dropAll,
	reset = function() if not panel:isShowing() then returnToCheckpoint() end end, -- the catch screen has its own way back
	gait = function() if spiderPick.inspecting then return end; rig.gaitMode = if rig.gaitMode == "Tetrapod" then "Unilateral" else "Tetrapod" end,
	eye = function()
		if mateLegs.couple.active then return end
		if spiderPick.inspecting then -- the close look: the next framing (face, side, top)
			local id: string? = cam:inspectCycle()
			if id ~= nil then hud:toast(spiderPick.Text.framing(id), false) end
			return
		end
		cam:toggleEyeView()
	end,
	recenter = function() if not spiderPick.inspecting then cam:startRecenter() end end,
	slow = function() if not spiderPick.inspecting then slow = not slow end end,
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
 if M.title:holding() then local i=SpiderMotor.idleInput();i.wish=M.title:wish(motor.pos) or Vector3.zero;return i end -- (ROBLOX-109: the intro walks the spider out of the crack; nothing else moves it)
 if life.growth:isMoulting() or mateLegs.couple.active or spiderPick.inspecting then return SpiderMotor.idleInput() end -- (the close look: the spider stays where it is)
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
	rig.focusPoint = focusPoint -- (the drawn body turns a little toward it and the eyes glance at it: ROBLOX-87, display only)
	return {
		wish = wish, creep = controls.held.Creep == true, reel = f,
		dropHeld = controls.held.Drop == true, releaseHeld = controls.held.Cancel == true and not spiderPick.cancelSwallow,
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
		status = {}, helpVisible = helpVisible, helpText = PeacockText.card(device, SpiderChoice.displayKind(appearance)), -- (ROBLOX-92: one string, the one the Studio spec measures)
		caption = eyes:captionView(device),
	}
	-- Captions for sounds and vibrations (ROBLOX-49): off, normal or large. The eye view's own explanation above is not a sound caption.
	local captionScale = M.SettingsSpec.CAPTION_SCALE[setting("Captions")] or 1
	view.captionScale = if captionScale > 0 then captionScale else 1
	local hints = setting("ControlHints")
	view.helpVisible = helpVisible and (hints or helpUntil == math.huge) -- (H asks for the card even when the hints are off)
	local rumble = if dancePose and captionScale > 0 then PeacockText.caption(dancePose.rumble) else nil -- felt through the feet; the wasp's hum below takes precedence
	if rumble then view.caption = rumble end
	if wasp:isVisiting() and captionScale > 0 then
		local direction = M.WaspText.directionWord(motor.pos, motor.heading, motor.up, wasp.wasp.position)
		local heard = M.WaspText.caption(wasp.phase, wasp.phaseS, direction)
		-- The wasp going for the rival male is told only to a spider that could hear or see it (ROBLOX-70).
		local forRival = wasp.phase == "taking" or wasp.phase == "seizing" or wasp.phase == "bearing"
		if forRival and not M.WaspText.heardRival((motor.pos - wasp.wasp.position).Magnitude, not sightCast(motor.pos, wasp.wasp.position)) then heard = nil end
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
	local waspLine = M.WaspText.line(wasp.phase, wasp.confusedS > 0, wasp.visits, wasp.sparedThisVisit, device)
	if (wasp.phase == "taking" or wasp.phase == "seizing" or wasp.phase == "bearing")
		and not M.WaspText.heardRival((motor.pos - wasp.wasp.position).Magnitude, not sightCast(motor.pos, wasp.wasp.position)) then waspLine = nil end
	if waspLine then table.insert(view.status, waspLine) end
	if saveState.broken then table.insert(view.status, M.SaveText.BROKEN) end -- (ROBLOX-92: saving failed for this visit)
 do -- the courtship meter, the sac's guard days and the hatching's captions (ROBLOX-80)
  local mate,m=life.mate,life.mating
  if mate~=nil and mateLegs.Mate.courtable(mate) then
   local far=(mate.position-motor.pos).Magnitude
   local heard=mateLegs.heard(mate)
   if mateLegs.pending~=nil and heard and not life.asleep then mateLegs.say(mateLegs.pending);mateLegs.pending=nil end -- (the arrival that was too far to hear, told now that it is near: ROBLOX-92)
   if far<=mateLegs.Rules.loseWu or mate.meter>0 then view.court=mate.meter end
   if heard or mate.meter>0 then table.insert(view.status,mateLegs.Text.courtLine(device,far<=mateLegs.Rules.nearWu,SpiderChoice.canDance(appearance),dance.active,mate.meter)) end
  end
  if mateLegs.couple.active and mate~=nil and mateLegs.skippable(mate) then table.insert(view.status,mateLegs.Text.skipLine(device)) end -- (ROBLOX-92: what ends the scene, once it can; not a sound, so the Captions setting does not hide it)
  if mateLegs.couple.active and captionScale>0 and not wasp:isVisiting() then -- the mating scene's captions (ROBLOX-89)
   view.caption=mateLegs.Text.matingCaption(mateLegs.couple.t,mateLegs.Mating.sexOf(appearance)) or view.caption
  end
  if m~=nil and (m.stage=="sac" or m.stage=="guarding") then table.insert(view.status,mateLegs.Text.guardLine(m.guard_day,mateLegs.Rules.guardDays)) end
  if mateLegs.phase=="scene" and captionScale>0 then view.caption=mateLegs.Text.sceneCaption(mateLegs.stage.t) or view.caption end
 end
 if life.rival and life.rival.state=="captured" and not RivalSpider.struggling(life.rival) then table.insert(view.status,rivalLegs.Text.eating(Growth.mealsOf(RivalSpider.FOOD))) end
	view.grip = if prey.feeding.struggling then prey.feeding.grip else rivalLegs.Grip.level(rivalLegs.grip)
	if rivalLegs.Grip.active(rivalLegs.grip) then table.insert(view.status, rivalLegs.Text.struggle(ControlText.name(device,"jump"))) end
	if prey.feeding.struggling then
		table.insert(view.status, "Caught — tap " .. ControlText.name(device,"jump") .. " to keep your grip")
	elseif prey.feeding.feeding then table.insert(view.status, "Feeding — move to stop")
	elseif prey.feeding.held then table.insert(view.status, "Meal paused — " .. ControlText.name(device,"feed") .. " to eat") end
	local clock = life.clock
	view.day = M.LifeText.day(clock.day, clock:partOfDay()) .. " | " .. life.growth:stageName() .. (if session.mode=="free" then " | FREE PLAY" elseif session.rules=="gentle" then " | EASY" else "")
	view.day ..= mateLegs.Text.dayTag(mateLegs.Mating.generation(life))
	view.food, view.foodGentle, view.largeText = needs.energy, needs.gentle, setting("LargeText") == true
	view.growth = M.LifeText.growth(life.growth, Growth.READY_FOOD, Species.fly_like_prototype.body.nutrition, if prey.feeding.held then prey.feeding.held.profile.body.prey_kind else nil)
	view.dayLine = M.LifeText.line(clock:partOfDay(), needs.energy, needs:isStarving(), needs.gentle, LifeLoop.HUNGRY_AT, life:tooHungryToSleep())
 if life.growth.ready then view.dayLine=nil
 elseif life.growth:isSoft() then view.dayLine="Soft new skin: slower steps and shorter jumps until it hardens." end
 view.dayLine = view.growth .. (if view.dayLine then "\n" .. view.dayLine else "")
 view.notice = if life.noticeSeconds > 0 and life.notice ~= "" then life.notice else nil
	local canRest = life:canRest(lifeSpider)
	local restPrompt = M.LifeText.prompt(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep(), device, PeacockText.change(device, appearance) .. "    " .. spiderPick.Text.holdHint(device), M.World:homeRetreat(motor.pos))
 if life.growth:isMoulting() then
  restPrompt={title="Moulting in the silk-lined crack",hint="The spider pulls free of its old skin. Wait here while the hours pass."}
 elseif life.growth.ready and canRest and not life.resting then
  restPrompt={title="Ready to moult",hint=ControlText.name(device,"feed")..": rest and moult in the crack"}
 end
 if not restPrompt and M.World:nearRetreat(motor.pos,M.World.lastRetreat,7) and not prey.feeding.held then
  restPrompt=M.LifeText.homeLine(M.World.lastRetreat,lifeSpider.inRetreat,device) -- (ROBLOX-96: the crack's words as they were, or the stone's)
 end
 local displayKind = SpiderChoice.displayKind(appearance)
	local displayOn = if displayKind == "antennae" then ant.state:displaying() elseif displayKind == "threat" then ant.threat:displaying() else dance.active
	local displayHint = if displayKind == "antennae" then ant.Text.displayHint(device, displayOn) elseif displayKind == "threat" then ant.ThreatText.displayHint(device, displayOn) elseif displayKind == "dance" then PeacockText.displayHint(device, displayOn) else ""
	if restPrompt and not lifeSpider.inRetreat and displayKind ~= nil then restPrompt.hint ..= "    " .. displayHint end
	if displayKind ~= nil and displayOn then table.insert(view.status, if displayKind == "antennae" then ant.Text.statusLine(device) elseif displayKind == "threat" then ant.ThreatText.statusLine(device) else PeacockText.dancingLine(device)) end
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
	spiderPick.touchFrame()
	local restLabel = M.LifeText.touchLabel(life.asleep, life.resting, canRest, clock:isSleepTime() and not life:tooHungryToSleep())
	if not spiderPick.inspecting then
	local gripping = prey.feeding.struggling or rivalLegs.Grip.active(rivalLegs.grip)
	controls:setTouchVisible("Feed", (gripping or prey.feeding.held ~= nil or restLabel ~= nil) and not life.growth:isMoulting())
	controls:setTouchLabel("Feed", if gripping then "Grip" elseif prey.feeding.held ~= nil then "Eat" else restLabel or "Eat")
	controls:setTouchLabel("Jump", if prey.feeding.struggling or rivalLegs.Grip.active(rivalLegs.grip) then "Grip" elseif mateLegs.couple.active and life.mate ~= nil and mateLegs.skippable(life.mate) then mateLegs.Text.TOUCH_SKIP else "Jump")
	controls:setTouchLabel("Cancel", ControlText.touchCancelLabel(onLine))
	controls:setTouchVisible("Jump", not onLine)
	controls:setTouchVisible("Creep", not onLine)
	-- The peacock spider's buttons: Change in the crack, Dance on the open sill (the peacock spider only).
	controls:setTouchVisible("Choose", canChange())
	controls:setTouchVisible("Display", displayKind ~= nil and not onLine and not life.resting and motor.mode == "attached")
	controls:setTouchLabel("Display", if displayKind == "antennae" then ant.Text.touchDisplay(displayOn) elseif displayKind == "threat" then ant.ThreatText.touchDisplay(displayOn) else PeacockText.touchDisplay(displayOn))
	end
	if spiderPick.inspecting then -- the close look shows the spider's name and one line of controls, and nothing else (no hunger, no time, no notices or captions)
		view = { device = device, status = {}, helpVisible = view.helpVisible, helpText = view.helpText, largeText = view.largeText, captionScale = view.captionScale,
			prompt = { title = spiderPick.Text.nameLine(appearance), hint = spiderPick.Text.hint(device) } }
	end
	hud:update(view, frameDt)
end

-- ---------------------------------------------------------------- the frame
local accumulator = 0
RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)
	saveState.frame()
	spiderPick.update(frameDt) -- (the choose hold's clock and the close look's reasons to end)
	M.World:update(motor.pos, rig.root) -- (ROBLOX-94: the region the spider is in, the pace of its day, the streaming focus on the drawn spider)
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
			local percepts = M.World.prey:percepts() -- (ROBLOX-96: the active regions' flies; ROBLOX-105: the woodlice and the ambient bugs are not shown to the senses)
            life.rival=life.rival or RivalSpider.new()
            local rivalPercept=RivalSpider.percept(life.rival)
            if rivalPercept then table.insert(percepts,rivalPercept) end
            if life.mate then
             local matePercept=mateLegs.Mate.percept(life.mate) -- a moving thing on the sill, never prey (ROBLOX-80)
             if matePercept then table.insert(percepts,matePercept) end
            end
			if stage then
				local p = stage.target:percept()
				if p then table.insert(percepts,p) end
			end
			local waspPercept = wasp:percept() -- movement to the spider's senses, never prey
			if waspPercept then table.insert(percepts, waspPercept) end
			sensor:step(DT,motor:observer(),percepts,sightCast)
			M.World.prey:before(DT,motor.pos,motor:observer(),sensor,sightCast,camera,life.clock.hour) -- (ROBLOX-101: the moths and crane flies fly from dusk)
			if life.growth:isMoulting() then jump:drop(motor);motor:cancelWalk() else jump:step(motor) end
			if breakaway:step(DT,if jump.last and jump.last.tick==jump.tick then jump.last else nil,motor.pos,setting("ReducedMotion")==true) then
    motor.planKey="";hud:toast("The dry leaf tip gave way. Your dragline catches the miss.",false)
   end
			local input = tickInput()
			motor:tick(input)
			-- ROBLOX-106: moving costs energy (NeedsModel.move pays nothing in the gentle modes) and, in Normal, a leaf overhead and stillness hide the spider (Life/Nature).
			do
				local onLine = motor:onLine()
				local moved = M.Nature.moved(M.nature.move, motor.mode, motor.moving == true, motor.dropped == true, motor.seized == true, onLine, if onLine then motor.silk.rest else nil)
				if moved ~= "" then needs:move(moved, DT) end
				local walking = motor.mode == "attached" and motor.moving == true
				M.nature.cover = if needs.gentle then nil else M.Nature.cover(M.Nature.overhead(motor.pos, M.nature.ray), not walking and motor.vel.Magnitude < 0.15)
			end
			-- The wasp runs after the spider has moved and before feeding (Godot: physics priority 8).
			wasp.enabled = not testPlace or Workspace:GetAttribute("Wasp") == true
            wasp:useGameRules()
			wasp.nature = not needs.gentle -- (ROBLOX-106: the standard rules' wasp: its windows slide, its visits vary and sometimes linger)
			local forced = if testPlace then Workspace:GetAttribute("WaspForce") else nil
			if typeof(forced) == "string" and forced ~= "" then
				Workspace:SetAttribute("WaspForce", nil)
				wasp:force(life.clock.day, forced)
			end
			local fallingOnLine = motor:onLine() or (motor.mode == "air" and motor.dropped == true)
			waspSpider.position, waspSpider.velocity = motor.pos, motor.vel
			waspSpider.falling = fallingOnLine
			waspSpider.airborne = motor.mode == "air" and not fallingOnLine and not motor.seized
			waspSpider.cover = M.nature.cover
			-- (ROBLOX-91: the first day and first meal protect each generation: a spiderling's `born` and meals count from the hatching, not from the sill's first day)
			local born, genMeals = mateLegs.Mating.grace(life, prey.feeding.mealsFinished)
			wasp:step(DT, waspSpider, {
				day = life.clock.day, hour = life.clock.hour, resting = life.resting, moulting = life.growth:isMoulting(), meals = genMeals, born = born,
				rival = RivalSpider.target(life.rival),
			})
			for _, signal in wasp:drainSignals() do
				watch:onWasp(signal.kind, signal.escaped)
				if signal.kind == "visit_started" then rig:cue("alarm");spiderPick.finish(spiderPick.Text.DANGER, true) end -- the warning begins: legs I up and still for a moment (ROBLOX-87)
				if signal.kind == "caught" then
					-- Stung: the spider lets go of everything and is carried (Godot SpiderMotor.seize).
					motor:seize()
					dropAll()
					dropStrands(false)
				elseif signal.kind == "carried_off" then
					showCaught()
				elseif signal.kind == "rival_seized" then
					-- The wasp has the rival male (ROBLOX-70): it hangs under the wasp; the spider is not hunted today.
					if RivalSpider.seize(life.rival) and M.WaspText.heardRival((motor.pos - signal.at).Magnitude, not sightCast(motor.pos, signal.at)) then
						life:showNotice(M.WaspText.RIVAL_TAKEN)
					end
				elseif signal.kind == "rival_carried_off" and life.rival.state == "taken" then
					RivalSpider.carried(life.rival, life.clock.day, life.clock.hour)
				end
			end
			if wasp.rivalHeldAt and life.rival.state == "taken" then life.rival.position = wasp.rivalHeldAt end
			if wasp.heldAt then motor:hold(wasp.heldAt) end
			prey.feeding.auto = setting("AutomaticGrip") == true or mateLegs.couple.active -- (a meal in the legs is held for a player whose hands are the scene's: ROBLOX-89)
			if life.growth.gameRules ~= true then life.growth:useGameRules(needs.gentle) end -- (a family that carries on has a new growth)
			if prey.feeding.game ~= true then prey.feeding:useGameRules() end -- (a record restored from before the flag has none: the game's struggle again)
			local takenBefore = prey.feeding.taken
			M.World.prey:after(DT,motor,sensor,sightCast)
			if M.World.prey.event ~= nil then hud:setNote(M.PreyText.note(M.World.prey.event) or "",M.PreyText.SECONDS);M.World.prey.event=nil end -- (ROBLOX-101: a slip, a shed leg)
			-- Five houseflies or ten small prey (ROBLOX-88; Godot's three and six are Growth's defaults); credit food, not just spare energy capacity.
			life.mealFood = (life.mealFood or 0) + Growth.rivalCredit(prey.feeding.taken-takenBefore)
            local rivalState={
             position=motor.pos,previous=prey.previousPosition or motor.pos,heading=motor.heading,up=motor.up,
             day=life.clock.day,hour=life.clock.hour,meals=genMeals,born=born,resting=life.resting,safe=M.World:inRetreat(motor.pos)~=nil,
             -- the rival keeps away from a courting pair and from the mating scene (ROBLOX-91): it recovers, like for the wasp
             scene=mateLegs.Mate.sceneActive(life.mate),courting=mateLegs.Mate.courting(life.mate,motor.pos),
             wasp=wasp:isVisiting(),gentle=needs.gentle,grounded=motor.mode=="attached",moving=motor.moving,
             airborne=motor.mode=="air",onLine=motor:onLine(),holding=prey.feeding.held~=nil,
             striking=prey.tick<=prey.strikeEnd and not motor.seized,drive=rivalLegs.drive,taken=wasp.holdingRival,
             seed=914, -- the world's seed, as the prey's and the wasp's: the rival's contest draws from it (ROBLOX-73)
             noticeScale=M.nature.cover,nature=not needs.gentle, -- (ROBLOX-106: cover, and the watch by the crack)
            }
            local rivalEvent,rivalFood=RivalSpider.step(life.rival,DT,rivalState,sightCast)
            if life.rival.state~="dormant" and life.rival.state~="consumed" and rivalLegs.drive==nil then
             rivalLegs.drive=rivalLegs.Drive.new(SpiderMotor.new({
              world = M.World.root, surfaces = Surfaces, profile = Species.phidippus_audax_prototype,
              spawn = life.rival.position, heading = life.rival.heading,
              boundsMin = M.World.homeMin, boundsMax = M.World.homeMax, probeParent = arc, -- (ROBLOX-95: bound to the sill, its bounds)
             }),sightCast,M.World.home)
             rivalLegs.drive.camps=true -- (ROBLOX-106: in Normal a patrol leg may be a watch by the crack)
            end
            -- A caught rival fights the tapping grip before it can be eaten (ROBLOX-77); it is subdued, or it tears free and recovers (never a harm).
            local gripEvent=rivalLegs.Grip.step(rivalLegs.grip,life.rival,DT,{
             grounded=motor.mode=="attached" and not motor.preparing,gentle=needs.gentle,auto=setting("AutomaticGrip")==true or mateLegs.couple.active,seed=914,day=life.clock.day,
            })
            if gripEvent=="subdued" then life:showNotice(rivalLegs.Text.SUBDUED)
            elseif gripEvent=="tore" then life:showNotice(rivalLegs.Text.tore(needs.gentle)) end
            if rivalLegs.drive then rivalLegs.drive:update(life.rival,DT,rivalState) end
            if rivalFood>0 and rivalEvent~="counter" then -- (a counter-bite's number is what it costs, not what was eaten)
             needs:grantEnergy(rivalFood,"rival_spider_meal")
             life.mealFood+=Growth.rivalCredit(rivalFood)
            end
            if rivalEvent=="caught" then endLife("rival")
            elseif rivalEvent=="warning" then rig:cue("alarm");spiderPick.finish(spiderPick.Text.DANGER, true);life:showNotice("The other spider crouches to jump. Dodge, drop or jump away!")
            elseif rivalEvent=="captured" or rivalEvent=="sprang" then life:showNotice(rivalLegs.Text.strike(rivalEvent,needs.gentle) or "")
            elseif rivalEvent=="counter" then
             needs:injure(rivalFood) -- the bite costs energy (nothing in the gentle modes)
             life:showNotice(rivalLegs.Text.counter(needs.gentle))
            elseif rivalEvent=="eaten" then prey.feeding.mealsFinished+=1
            elseif rivalEvent=="touch" then life:showNotice("The rival touched you. You are safe in this mode.") end
            -- The mating cycle (ROBLOX-80): the mate and the courtship meter, the sac and the guard days, by the same snapshot of the spider the rival has.
            do
             local ms=mateLegs.state
             table.clear(ms)
             for k,v in rivalState do ms[k]=v end -- (ROBLOX-92: the one table, filled again, not a clone of the rival's every tick)
             ms.drive,ms.sex,ms.needsDance,ms.dancing,ms.blocked=mateLegs.drive,mateLegs.Mating.sexOf(appearance),SpiderChoice.canDance(appearance),dance.active,sightCast
             if mateLegs.couple.active and wasp:isVisiting() then mateLegs.skip(true) end -- (the controls are the player's again the moment the wasp comes)
             ms.rivalThreat=life.rival.state=="windup" or life.rival.state=="lunge" -- (a scene would not start under a lunge: Mating.tick skips it at once)
             ms.nature=ms.nature==true and mateLegs.Rules.game.on==true;ms.rival=RivalSpider.target(life.rival) -- (ROBLOX-106: courtship can fail, the rival can cut in)
             for _,e in mateLegs.Mating.tick(life,DT,ms) do mateLegs.event(e,ms) end
             local mate=life.mate
             if mate~=nil and mate.state~="away" and mateLegs.drive==nil then
              mateLegs.drive=mateLegs.Drive.new(SpiderMotor.new({
               world = M.World.root, surfaces = Surfaces, profile = Species.phidippus_audax_prototype,
               spawn = mate.position, heading = mate.heading,
               boundsMin = M.World.homeMin, boundsMax = M.World.homeMax, probeParent = arc, -- (ROBLOX-95: bound to the sill, its bounds)
              }),sightCast,M.World.home)
             end
             if mateLegs.drive~=nil and mate~=nil then mateLegs.drive:update(mate,DT,ms) end
             -- A record restored into the hatching (or a brood out while nothing is playing) goes straight to the ending.
             if life.mating~=nil and life.mating.stage=="hatched" and mateLegs.phase=="" and not panel:isShowing() then mateLegs.begin(false) end
            end
			-- The life loop runs last in the tick (Godot's habitat loop, priority 12); the reach it sets is the next tick's.
			local holding = prey.feeding.held ~= nil or (life.rival~=nil and life.rival.state=="captured")
			lifeSpider = {
				inRetreat = M.World:inRetreat(motor.pos) ~= nil, attached = motor.mode == "attached" and not motor.preparing,
				still = input.wish.Magnitude < 0.01 and motor.vel.Magnitude < 0.15,
				holding = holding, feeding = holding and (prey.feeding.feeding or (life.rival~=nil and life.rival.state=="captured")), position = motor.pos,
			}
			life:step(DT, lifeSpider, feedPending, cancelPending)
			feedPending, cancelPending = false, false
			sensor.core.rangeScale = life.rangeScale
			-- ROBLOX-106: home before dark. Out of every retreat after dark anywhere but the sill, in Normal, the ground hunters' passes are drawn against the spider.
			do
				local night = M.Nature.night(M.nature.night, life, { seed = 914, exposed = not life.lifeOver and M.Nature.exposed(not needs.gentle, M.World.region.kind, lifeSpider.inRetreat) })
				if night == "found" then endLife("night") elseif night == "cold" then life:showNotice(M.LifeText.NIGHT_COLD) end
			end
			motor:setReachFactor(life.growth:reachFactor());motor:setSpeedFactor(life.growth:speedFactor() * M.Nature.coldSpeed(life))
   for _,event in life:drainEvents() do
    watch:onLife(event.kind,life.growth.stage)
    if event.kind=="woke" then mateLegs.woke(event.day) end
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
              player:SetAttribute("TitleReady",true) -- (ROBLOX-109: the splash, First/SplashScreen, fades away over the title card)
             end
            end
            watch:step({
             started=session.started and not M.title:holding(),captures=M.World.prey:captures(),feeding=prey.feeding.feeding,taken=prey.feeding.taken,
             energy=needs.energy,gentle=needs.gentle,spider=motor.pos,flies=M.World.prey:flies(),region=M.World.region.kind,bugs=M.World.prey:crawlers(),
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
	if dc and M.DayLight.due(lastLight, life.daylight) then
		M.DayLight.apply(Lighting, M.DayLight.targets(life.daylight, dc), Workspace:FindFirstChild("Decor"))
		lastLight = life.daylight
	end
	-- The morning dew follows the hour, not the daylight (ROBLOX-74): it is drawn from the clock and keeps its last level on its own folder.
	M.DayLight.applyDew(Workspace:FindFirstChild("Decor"), life.clock.hour)
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
	-- The tarantulas' threat display and silk mat (ROBLOX-82): a loop of the drawn pose, stepped with the simulation's time (slow motion slows it, a
	-- menu or the catch screen holds it), on the same standing test as the dance; any walking intent, aim, jump, line or rest ends it at once.
	do
		if SpiderChoice.hasThreat(appearance) then
			ant.threat.reduced = setting("ReducedMotion") == true
			local r, f = controls:axes()
			if jump:isAiming() then r, f = 0, 0 end
			local standing = motor.mode == "attached" and not motor.preparing and not motor.seized and not motor:onLine() and not life.resting
			local paused = GuiService.MenuIsOpen or modal()
			ant.threatPose = ant.threat:step(if paused then 0 else simFrame, standing, motor.moving or r ~= 0 or f ~= 0)
			rig.threat = if ant.threat:showing() then ant.threatPose else nil
		else
			ant.threatPose = nil
			rig.threat = nil
		end
	end
 rig.reducedMotion=setting("ReducedMotion")==true
 mateLegs.coupleFrame(rig.reducedMotion,frameDt) -- (the mating scene's camera, cues and looks; before the rigs are drawn)
 rig:noteMeals(prey.feeding.mealsFinished) -- a meal ended: a longer cleaning once it stands still (ROBLOX-87)
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
     if not rivalLegs.rig then rivalLegs.rig=SpiderRig.new(Workspace,M.World.root,"rival_spider","low");rivalLegs.rig.model.Name="RivalSpider" end
     rivalLegs.rig.reducedMotion=setting("ReducedMotion")==true
     rivalLegs.rig.jumpLoad=if rival.state=="windup" then math.clamp(rival.elapsed,0,1) else 0
     -- (ROBLOX-93: drawn ten times a second when it is more than SpiderRig's FAR_STUDS from the camera, except in a windup, a lunge or when carried; the sim steps it every tick)
     local hurried=rival.state=="windup" or rival.state=="lunge" or rival.state=="taken"
     rivalLegs.rig:drawStep(SupportMath.bodyCFrame(rival.position,if rival.state=="taken" then Vector3.yAxis else (rival.up or Vector3.yAxis),rival.heading),if paused then 0 else simFrame,rival.state~="lunge" and rival.state~="taken",(rival.position-rival.previous).Magnitude>.001,if hurried then 0 else (camera.CFrame.Position-rival.position).Magnitude)
    elseif rivalLegs.rig then rivalLegs.rig:destroy();rivalLegs.rig=nil end
    -- The mate, the egg sac and the hatching (ROBLOX-80). The scene waits when a screen has the game; when it is over the ending card comes.
    mateLegs.stage:drawMate(life.mate,appearance,if paused then 0 else simFrame,setting("ReducedMotion")==true,mateLegs.couple.focus,mateLegs.couple.turn,camera.CFrame.Position)
    mateLegs.stage:drawSac(mateLegs.Mating.hasSac(life.mating))
    if mateLegs.phase=="scene" and not paused and not mateLegs.stage:step(simFrame,setting("ReducedMotion")==true) then mateLegs.showCard(false) end
	updateHud(frameDt)
	-- (ROBLOX-103: the bodies step, sway and beat by the prey's clock; far ones ten times a second; Reduced Motion stills all but the steps)
	flyBodies:draw(M.World.prey:flies(),M.World.prey.clock,camera.CFrame.Position,setting("ReducedMotion")==true)
	M.World.bugs:draw(M.World.prey:crawlers(),M.World.prey.clock,camera.CFrame.Position,setting("ReducedMotion")==true)
	local soundPaused = GuiService.MenuIsOpen or modal()
	local soundSpeed = if slow then SLOW_SPEED else 1
	local soundMuted = setting("SoundMuted") == true
	soundscape:setVolumes(setting("MasterVolume"), setting("AmbienceVolume"), setting("CreatureVolume"), setting("MusicVolume"))
	soundscape:setTitle(not testPlace and (not session.started or M.title:holding())) -- (ROBLOX-109: the music under the title card, rising the first time)
	soundscape:update(frameDt, M.World.prey.view, life.daylight, soundPaused, soundSpeed, soundMuted)
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
	camSettings.reducedMotion = setting("ReducedMotion") == true
	cam:configure(camSettings)
	-- Looking runs in real time, so slow motion never makes the camera sluggish.
	local lx, ly = controls:lookAxes(jump:isAiming())
	if M.title:frame(frameDt, session.started, modal()) then -- (ROBLOX-109: the title card's drift, or the intro, has the camera this frame)
	elseif not modal() then
		if spiderPick.inspecting then
			local _, zoom = controls:axes() -- the left stick, or W and S: forward is closer (the close look)
			cam:inspectZoom(zoom, frameDt)
		end
		cam:render(frameDt, lx, ly)
	end
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

-- The test-place-only module exercises this controller in Studio. Absent from the playable build. Its hooks are also the live place's self-test's (ROBLOX-104, below).
M.hooks = function(): any
	return {
			prey = prey, flyBodies = flyBodies, waspBody = waspBody, life = life, wasp = wasp, caughtPanel = panel, needs = needs, checkpoints = checkpoints, returnToCheckpoint = function() returnToCheckpoint() end, lifeSpider = function() return lifeSpider end, sensor = sensor, memory = memory, focusState = focusState, perceptionHud = perceptionHud, stage = stage,
			input = controls, rivalLegs = rivalLegs, mateLegs = mateLegs, spiderPick = spiderPick, saveState = saveState, hud = hud,
			notebook = book, notebookWatch = watch, notebookPanel = nbPanel, openNotebook = openNotebook, settingsPanel = settingsPanel, openSettings = openSettings, setting = setting, cam = cam, soundscape = soundscape, eyes = eyes,
			session=session, menu=menu, openMenu=openMenu, endLife=endLife, fresh=fresh, stores=stores, continueAnother=continueAnother, currentStore=function() return checkpoints end,
			changeSpider = function() changeSpider() end, dance = function() return dance end, ant = function() return ant.state end, antPose = function() return ant.pose end, threat = function() return ant.threat end, threatPose = function() return ant.threatPose end, appearance = function() return appearance end, rig = function() return rig end,
			drop = function() motor:requestDrop() end,
			jump = jump,
			motor = motor,
			camera = cam,
			sill = sill,
			world = M.World,
			setDevice = function(name: ControlText.Device) device = name end,
			place = function(position: Vector3, up: Vector3?) -- (ROBLOX-103: `up` for a place on a wall's face; the floor's by default)
				controls:clear()
				jump:drop(motor)
				motor:place(position, up or Vector3.yAxis, if up ~= nil and math.abs(up.Z) > 0.9 then Vector3.yAxis else Vector3.zAxis)
				dropStrands(false)
				drawnUp = motor.up
				cam:snap()
			end,
			get = function()
				return { mode = motor.mode, line = motor.silk.mode, taut = motor.silk.taut, position = motor.pos, walking = motor.silk.walk ~= nil }
			end,
			detail = detail, -- (ROBLOX-104: the tier the self-test reports its part counts at)
			title = M.title, -- (ROBLOX-109: the title card and the intro, for the self-test's intro check)
			nature = M.nature, -- (ROBLOX-106: nature's rules this tick: the cover factor, the night's passes)
	}
end
local playback = script.Parent:FindFirstChild("SilkPlayback")
if RunService:IsStudio() and playback and playback:IsA("ModuleScript") then
	task.spawn(function()
		local run: any = (require :: any)(playback)
		run(M.hooks())
	end)
end
-- The live place's self-test (ROBLOX-104, Client/SelfTest): only in Studio with the Workspace attribute SelfTest set true; nothing of it is loaded otherwise.
if RunService:IsStudio() and Workspace:GetAttribute("SelfTest") == true then require(script.Parent.SelfTest).start(M.hooks()) end
