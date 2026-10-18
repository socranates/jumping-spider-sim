-- (the ant-mimicking spider's part of that smoke run, in a file of its own: the whole smoke run is close to the time one check may take)
-- A smoke run of the client scripts themselves (SpiderClient, SpiderInput, SpiderHud, SpiderCamera, SpiderRig and the shared
-- modules) on the box world, with stub Roblox services (tests/shim.luau): keys are pressed through the same
-- ContextActionService callbacks the engine calls, frames through the bound render step. It catches wiring and runtime
-- errors anywhere in the client loop. Not evidence of rendering, input devices or the engine's physics.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL client_ant: " .. name .. "\n    " .. tostring(err)) end
end

local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local services = game:GetService("ContextActionService") and ClientStubs
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local KEYS = { Feed = "E", Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Eye = "V", Recenter = "R", Creep = "LeftShift", Reset = "Backspace", Choose = "C", Display = "X", Slow = "T" }
local function key(action: string, down: boolean)
	local fn = services.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function spider(): Vector3
	local model = workspace:FindFirstChild("Spider")
	return model:FindFirstChild("Root").Position
end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end

check("the client loads and runs 120 frames", function()
	assert(loaded, "SpiderClient did not load")
	frames(120)
end)
check("the ant-mimicking spider: C cycles to it, legs I rise when it stands and fall when it walks, the drawn walk wobbles, X raises the antennae higher; the motor never knows", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local player = game:GetService("Players").LocalPlayer
	local function words(screen: string, name: string): string
		local d = find(screen, name)
		return if d and d.Visible then d.Text else ""
	end
	-- How far the left foreleg's lower segment is above the head's centre (the world floor sits wherever the spawn is).
	local function legUp(): number
		local m = workspace:FindFirstChild("Spider")
		return m:FindFirstChild("Tarsus1").Position.Y - m:FindFirstChild("Cephalothorax").Position.Y
	end
	-- In the crack, resting awake: C cycles first spider, peacock spider, ant-mimicking spider.
	frames(120)
	game:GetService("Lighting").ClockTime = 9.75
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting and not life.asleep, "E did not rest")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "C: become the peacock spider", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "maratus_volans_male" and string.find(words("SpiderPrompts", "PromptHint"), "C: become the ant-mimicking spider", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "myrmarachne_formicaria_female" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "myrmarachne_formicaria_female", "C did not reach the ant-mimicking spider")
	assert(words("SpiderPrompts", "Toast") == "You are the ant-mimicking spider now", words("SpiderPrompts", "Toast"))
	assert(player:GetAttribute("Appearance") == "myrmarachne_formicaria_female", "the choice is not kept for the session")
	assert(life.resting, "changing spider ended the rest")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	-- In the crack, resting awake, the pose is not shown and the key still changes spider.
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(30)
	assert(life.resting and not life.asleep, "E did not rest")
	assert(driver.antPose().antennae == 0 and legUp() < 0, "the antennae are up while resting in the crack")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "C: become the first spider", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(not life.resting, "E did not end the rest")
	-- On the open sill: standing still raises legs I (no key), the words and the buttons say so for this spider only.
	driver.place(Layout.SPAWN)
	frames(20)
	assert(driver.antPose().antennae < 1 and driver.rig().ant ~= nil, "the pose is not given to the rig")
	local p0 = spider()
	frames(60)
	assert(driver.antPose().antennae > 0.999 and legUp() > 0.1, `legs I are not up after standing still ({legUp()})`)
	assert(driver.antPose().walking == false, "drawn as walking while standing")
	assert((spider() - p0).Magnitude < 1e-6 and (spider() - driver.motor.pos).Magnitude < 1e-6, "the antennae moved the spider")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: wave antennae", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(not string.find(words("SpiderPrompts", "PromptHint"), "courtship", 1, true), "the dance is mentioned for the ant mimic")
	local touch = gui:FindFirstChild("SpiderTouch")
	assert(touch:FindFirstChild("Display").Visible == true and touch:FindFirstChild("Display").Text == "Wave" and touch:FindFirstChild("Choose").Visible == false, "touch: Wave on the sill, Change only in the crack")
	-- X: higher and faster, with its words; X again or a step ends it.
	local calmUp = legUp()
	key("Display", true); frames(2); key("Display", false); frames(30)
	assert(driver.ant():displaying() and driver.antPose().high > 0.99, "X did not raise the antennae higher")
	assert(legUp() > calmUp - 0.03, "the display pose is lower than the calm one")
	assert(string.find(words("SpiderPrompts", "Status"), "ANTENNAE UP    X or move: stop", 1, true), words("SpiderPrompts", "Status"))
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: antennae down", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(touch:FindFirstChild("Display").Text == "Stop", "touch button does not say Stop")
	assert(not driver.dance().active, "the ant mimic started a dance")
	key("Display", true); frames(2); key("Display", false); frames(2)
	assert(not driver.ant():displaying(), "X again did not stop it")
	key("Display", true); frames(2); key("Display", false); frames(30)
	key("Cancel", true); frames(1); key("Cancel", false)
	assert(not driver.ant():displaying(), "Q did not stop it")
	frames(30)
	-- Walking: legs I are legs again within a moment, the body yaws and sways, and the spider goes exactly where the motor sends it.
	local start = spider()
	local peakYaw, peakLateral, minAntennae = 0, 0, 1
	key("Forward", true)
	for i = 1, 60 do
		frames(1)
		local pose = driver.antPose()
		peakYaw, peakLateral = math.max(peakYaw, math.abs(pose.yaw)), math.max(peakLateral, math.abs(pose.lateral))
		if i >= 15 then minAntennae = math.min(minAntennae, 1 - pose.antennae) end
	end
	key("Forward", false)
	local antWalk = (spider() - start).Magnitude
	assert(antWalk > 1.5, `moved {antWalk}`)
	assert(minAntennae == 1 and driver.antPose().antennae < 0.001, "legs I did not come down while walking")
	assert(peakYaw > math.rad(5) and peakLateral > 0.01, `the drawn body did not wobble (yaw {peakYaw}, sway {peakLateral})`)
	assert((spider() - driver.motor.pos).Magnitude < 1e-6, "the root is not at the collider")
	frames(2)
	-- A short stop is not drawn as a pause; a longer one is.
	key("Forward", true); frames(30); key("Forward", false); frames(4)
	assert(driver.antPose().walking == true and driver.antPose().antennae == 0, "a stop of 4 frames (67 ms) was drawn as a pause")
	frames(20)
	assert(driver.antPose().walking == false, "a longer stop was not drawn as one")
	-- Slow motion slows the pose as it slows everything; ReducedMotion is read from the player's attribute.
	key("Forward", true); frames(10); key("Forward", false)
	local still0 = driver.ant().still
	key("Slow", true); key("Slow", false); frames(120)
	local advanced = driver.ant().still - still0
	assert(advanced > 0.9 and advanced < 1.1, `slow motion: the pose advanced {advanced} s in 2 s`)
	key("Slow", true); key("Slow", false)
	frames(60)
	player:SetAttribute("ReducedMotion", true)
	frames(2)
	assert(driver.ant().reduced == true and driver.antPose().wave == 0 and driver.antPose().antennae > 0.999, "reduced motion: the waving stops and the legs stay up")
	player:SetAttribute("ReducedMotion", nil)
	frames(2)
	assert(driver.ant().reduced == false, "ReducedMotion not read")
	-- The same walk as the first spider covers the same ground: nothing about the motor, speed or path changed.
	driver.place(Layout.SPAWN); frames(60)
	local a0 = spider()
	key("Forward", true); frames(90); key("Forward", false); frames(2)
	local antGround = (spider() - a0).Magnitude
	driver.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "first_spider" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "first_spider", "C did not cycle back to the first spider")
	assert(driver.antPose() == nil and driver.rig().ant == nil, "the first spider has an ant pose")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	driver.place(Layout.SPAWN); frames(60)
	local f0 = spider()
	key("Forward", true); frames(90); key("Forward", false); frames(2)
	assert(math.abs((spider() - f0).Magnitude - antGround) < 1e-6, `the ant mimic walked {antGround}, the first spider {(spider() - f0).Magnitude}: the drawn wobble changed the path`)
	frames(2)
end)

print(`CLIENT_ANT passed={passed} failed={failed}`)
