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
	assert(string.find(words("SpiderPrompts", "PromptHint"), "C: become the Mexican redknee", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(not life.resting, "E did not end the rest")
	-- On the open sill: standing still raises legs I (no key), the words and the buttons say so for this spider only.
	driver.place(Layout.SPAWN)
	frames(20)
	assert(driver.antPose().antennae < 1 and driver.rig().ant ~= nil, "the pose is not given to the rig")
	assert(not driver.notebook:isOpen("walking_like_an_ant"), "the notebook page opened before the antennae had been up")
	local p0 = spider()
	frames(60)
	assert(driver.antPose().antennae > 0.999 and legUp() > 0.1, `legs I are not up after standing still ({legUp()})`)
	assert(driver.antPose().walking == false, "drawn as walking while standing")
	-- Standing still long enough with the antennae up opens the notebook page (and says so); walking alone never does.
	frames(60)
	assert(driver.ant().shown >= 1.0 and driver.notebook:isOpen("walking_like_an_ant"), `the notebook page did not open (antennae up {driver.ant().shown} s)`)
	local note = find("SpiderPrompts", "NotebookNote")
	assert(note ~= nil and note.Visible and string.find(note.Text, "Walking like an ant", 1, true), "no note says the page opened: " .. tostring(note and note.Text))
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
	for _, expected in { "brachypelma_hamorii", "chromatopelma_cyaneopubescens", "first_spider" } do -- the ant mimic is followed by the two tarantulas, then the first spider
		key("Choose", true); frames(2); key("Choose", false); frames(2)
		assert(driver.appearance() == expected and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == expected, `C did not cycle on to {expected}`)
	end
	assert(driver.antPose() == nil and driver.rig().ant == nil, "the first spider has an ant pose")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	driver.place(Layout.SPAWN); frames(60)
	local f0 = spider()
	key("Forward", true); frames(90); key("Forward", false); frames(2)
	assert(math.abs((spider() - f0).Magnitude - antGround) < 1e-6, `the ant mimic walked {antGround}, the first spider {(spider() - f0).Magnitude}: the drawn wobble changed the path`)
	frames(2)
end)
check("the tarantulas: C reaches them, X plays the threat display and silk mat, a step, a jump aim, Cancel or X again ends it at once; slow motion and reduced motion; the motor never knows", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local player = game:GetService("Players").LocalPlayer
	local function words(screen: string, name: string): string
		local d = find(screen, name)
		return if d and d.Visible then d.Text else ""
	end
	local function lift(): number -- how far the left foreleg's lower segment is above the head's centre
		local m = workspace:FindFirstChild("Spider")
		return m:FindFirstChild("Tarsus1").Position.Y - m:FindFirstChild("Cephalothorax").Position.Y
	end
	-- In the crack, resting awake: C cycles on from the first spider to the Mexican redknee (the peacock spider, the ant mimic, then the redknee).
	driver.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	life.clock.hour = 12
	if not life.resting then key("Feed", true); frames(2); key("Feed", false); frames(2) end
	assert(life.resting and not life.asleep, "E did not rest")
	for _, expected in { "maratus_volans_male", "myrmarachne_formicaria_female", "brachypelma_hamorii" } do
		key("Choose", true); frames(2); key("Choose", false); frames(2)
		assert(driver.appearance() == expected, `C did not reach {expected}`)
	end
	assert(words("SpiderPrompts", "Toast") == "You are the Mexican redknee now", words("SpiderPrompts", "Toast"))
	assert(string.find(words("SpiderPrompts", "PromptHint"), "C: become the Greenbottle blue", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(driver.threat() ~= nil and driver.rig().threat == nil and driver.rig().ant == nil and driver.rig().dance == nil, "the redknee starts with a pose given to its rig")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(not life.resting, "E did not end the rest")
	-- On the open sill: nothing is up by itself; the hint and the touch button offer the rear-up, and X starts it.
	driver.place(Layout.SPAWN); frames(60)
	local touch = gui:FindFirstChild("SpiderTouch")
	assert(not driver.threat():showing() and driver.rig().threat == nil, "the threat display shows by itself")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: rear up", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(not string.find(words("SpiderPrompts", "PromptHint"), "courtship", 1, true) and not string.find(words("SpiderPrompts", "PromptHint"), "antennae", 1, true), "another spider's display is mentioned")
	assert(touch:FindFirstChild("Display").Visible == true and touch:FindFirstChild("Display").Text == "Rear up" and touch:FindFirstChild("Choose").Visible == false, "touch: Rear up on the sill, Change only in the crack")
	local calm = lift()
	local p0 = spider()
	key("Display", true); frames(2); key("Display", false); frames(88)
	assert(driver.threat():displaying() and driver.threatPose().phase == "threat" and driver.threatPose().presence == 1, `X did not start the pose ({driver.threatPose().phase})`)
	assert(math.abs(driver.threatPose().rear - math.rad(32)) < 1e-6 and driver.rig().threat == driver.threatPose(), "the rig is not given the 32 degree rear")
	assert(lift() > calm + 0.12, `legs I are not up in the threat posture ({lift()} against {calm})`)
	assert(string.find(words("SpiderPrompts", "Status"), "THREAT DISPLAY    X or move: stop", 1, true), words("SpiderPrompts", "Status"))
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: stop", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(touch:FindFirstChild("Display").Text == "Stop", "touch button does not say Stop")
	assert(not driver.dance().active and not driver.ant():displaying(), "the tarantula started another spider's display")
	assert((spider() - p0).Magnitude < 1e-6 and (spider() - driver.motor.pos).Magnitude < 1e-6, "the pose moved the spider")
	-- The loop goes on to the turn and the mat, the body pivoting by the drawn yaw; the root does not turn.
	frames(130)
	assert(driver.threat():displaying() and (driver.threatPose().phase == "turn" or driver.threatPose().phase == "mat"), `the loop did not reach the turn ({driver.threatPose().phase})`)
	frames(60)
	assert(driver.threatPose().phase == "mat" or driver.threatPose().phase == "return", driver.threatPose().phase)
	assert((spider() - p0).Magnitude < 1e-6, "the turn moved the spider")
	-- X again ends it at once (it eases out over a quarter of a second and the legs go back to the motor).
	key("Display", true); frames(2); key("Display", false)
	assert(not driver.threat():displaying(), "X again did not stop it")
	frames(30)
	assert(not driver.threat():showing() and driver.rig().threat == nil and math.abs(lift() - calm) < 0.03, "the pose did not ease out")
	-- Cancel ends it; a step ends it the same frame; a jump aim (holding Space) ends it too.
	key("Display", true); frames(2); key("Display", false); frames(30)
	assert(driver.threat():displaying(), "X did not start it again")
	key("Cancel", true); frames(1); key("Cancel", false)
	assert(not driver.threat():displaying(), "Q did not stop it")
	frames(30)
	key("Display", true); frames(2); key("Display", false); frames(30)
	key("Forward", true); frames(1)
	assert(not driver.threat():displaying(), "walking did not stop it at once")
	frames(20); key("Forward", false); frames(30)
	key("Jump", true); frames(3)
	key("Display", true); frames(2); key("Display", false)
	assert(not driver.threat():displaying(), "X while aiming a jump started the pose")
	key("Jump", false); key("Cancel", true); frames(1); key("Cancel", false); frames(30)
	-- Walking: X is refused with its words, and the walk is the first spider's.
	key("Forward", true); frames(5)
	key("Display", true); frames(2); key("Display", false)
	assert(not driver.threat():displaying() and words("SpiderPrompts", "Toast") == "Stand still on a surface to rear up", words("SpiderPrompts", "Toast"))
	frames(60)
	local walk0 = spider()
	frames(30)
	key("Forward", false)
	assert((spider() - walk0).Magnitude > 0.2 and not driver.threat():showing() and driver.rig().threat == nil, "the redknee did not walk like the first spider")
	frames(40)
	-- Slow motion slows the pose as it slows everything; ReducedMotion is read from the player's attribute and halves the angles.
	key("Display", true); frames(2); key("Display", false)
	local t0 = driver.threat().t
	key("Slow", true); key("Slow", false); frames(120)
	local advanced = driver.threat().t - t0
	assert(advanced > 0.9 and advanced < 1.1, `slow motion: the pose advanced {advanced} s in 2 s`)
	key("Slow", true); key("Slow", false)
	player:SetAttribute("ReducedMotion", true)
	frames(2)
	assert(driver.threat().reduced == true, "ReducedMotion not read")
	key("Cancel", true); frames(1); key("Cancel", false); frames(30)
	driver.threat().t = 0
	key("Display", true); frames(2); key("Display", false); frames(90)
	assert(driver.threatPose().phase == "threat" and math.abs(driver.threatPose().rear - math.rad(16)) < 1e-6 and driver.threatPose().tremor == 0, `reduced motion: rear {driver.threatPose().rear}`)
	key("Cancel", true); frames(1); key("Cancel", false); frames(30)
	player:SetAttribute("ReducedMotion", nil)
	frames(2)
	assert(driver.threat().reduced == false, "ReducedMotion not cleared")
	-- C in the crack goes on to the Greenbottle blue, which has the same display, and then back to the first spider, which has none.
	driver.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "E did not rest")
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "chromatopelma_cyaneopubescens" and driver.threat() ~= nil, "C did not reach the Greenbottle blue")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	driver.place(Layout.SPAWN); frames(60)
	key("Display", true); frames(2); key("Display", false); frames(40)
	assert(driver.threat():displaying() and driver.rig().threat ~= nil, "X did not start the display for the Greenbottle blue")
	key("Display", true); frames(2); key("Display", false); frames(30)
	driver.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "first_spider" and driver.rig().threat == nil, "C did not go back to the first spider")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	driver.place(Layout.SPAWN); frames(60)
	key("Display", true); frames(2); key("Display", false); frames(40)
	assert(not driver.threat():showing() and driver.rig().threat == nil, "the first spider shows a threat pose")
	key("Cancel", true); frames(1); key("Cancel", false); frames(2)
end)

print(`CLIENT_ANT passed={passed} failed={failed}`)
