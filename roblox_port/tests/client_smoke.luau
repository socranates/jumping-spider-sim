-- A smoke run of the client scripts themselves (SpiderClient, SpiderInput, SpiderHud, SpiderCamera, SpiderRig and the shared
-- modules) on the box world, with stub Roblox services (tests/shim.luau): keys are pressed through the same
-- ContextActionService callbacks the engine calls, frames through the bound render step. It catches wiring and runtime
-- errors anywhere in the client loop. Not evidence of rendering, input devices or the engine's physics.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL client: " .. name .. "\n    " .. tostring(err)) end
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
local KEYS = { Feed = "E", Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Eye = "V", Recenter = "R", Creep = "LeftShift", Reset = "Backspace" }
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

check("the client loads, binds every action and runs 120 frames", function()
	assert(loaded, "SpiderClient did not load")
	assert(frame ~= nil, "no render step bound")
	for _, a in { "Jump", "Cancel", "Drop", "Forward", "Eye", "Recenter", "Focus", "Slow", "Reset", "Help" } do assert(services.actions["Spider" .. a], a) end
	frames(120)
	assert(gui:FindFirstChild("SpiderHud") and gui:FindFirstChild("SpiderPrompts") and gui:FindFirstChild("SpiderTouch"), "HUD missing")
	assert(math.abs(spider().Y - 0.31) < 0.05, `spawned at {spider()}`)
end)
check("with no checkpoint yet, Backspace goes back to the start and says why", function()
	key("Reset", true); frames(1); key("Reset", false); frames(2)
	assert(string.find(find("SpiderPrompts", "Toast").Text, "No checkpoint yet", 1, true), find("SpiderPrompts", "Toast").Text)
	assert(math.abs(spider().Y - 0.31) < 0.05, `not at the start: {spider()}`)
end)
check("W walks the spider along the sill", function()
	local p0 = spider()
	key("Forward", true); frames(60); key("Forward", false); frames(2)
	assert((spider() - p0).Magnitude > 1.5, `moved {(spider() - p0).Magnitude}`)
end)
check("holding Space aims (reticle, patch words), Q cancels, the release does not leap", function()
	frames(10)
	local p0 = spider()
	key("Jump", true); frames(20)
	assert(find("SpiderHud", "Reticle").Visible == true, "no reticle while aiming")
	local title = find("SpiderHud", "AimTitle")
	assert(title.Visible and title.Text ~= "", "no patch words")
	assert(string.find(find("SpiderHud", "AimHint").Text, "Q: cancel the jump", 1, true), find("SpiderHud", "AimHint").Text)
	key("Cancel", true); frames(2); key("Cancel", false); key("Jump", false); frames(30)
	assert((spider() - p0).Magnitude < 0.05, "leapt after a cancel")
	assert(find("SpiderPrompts", "Toast").Text == "Jump cancelled", find("SpiderPrompts", "Toast").Text)
end)
check("a tap of Space hops", function()
	local p0 = spider()
	key("Jump", true); frames(1); key("Jump", false); frames(90)
	local d = (spider() - p0).Magnitude
	assert(d > 1.0 and d < 2.0, `hopped {d}`)
end)
check("F on the open sill floor says why it cannot let down", function()
	key("Drop", true); frames(2); key("Drop", false); frames(2)
	assert(find("SpiderPrompts", "Toast").Text == "Nothing below to let yourself down into from here", find("SpiderPrompts", "Toast").Text)
end)
check("V switches to the spider-eye view and back; the status names the key", function()
	key("Eye", true); key("Eye", false); frames(5)
	assert(workspace.CurrentCamera.FieldOfView == 90, "no eye-view field of view") -- the side eyes' 90 degrees (SpiderEyes, ROBLOX-20); the camera alone sets 80
	assert(string.find(find("SpiderPrompts", "Status").Text, "SPIDER-EYE VIEW    V: back", 1, true), find("SpiderPrompts", "Status").Text)
	key("Eye", true); key("Eye", false); frames(5)
	assert(workspace.CurrentCamera.FieldOfView == 65 and not find("SpiderPrompts", "Status").Visible, "did not leave the eye view")
end)
check("the Roblox menu drops held keys and the spider waits", function()
	local p0 = spider()
	key("Forward", true)
	local gs = game:GetService("GuiService")
	gs.MenuIsOpen = true; gs.MenuOpened:Fire(); frames(30)
	assert((spider() - p0).Magnitude < 0.05, "moved while the menu was open")
	gs.MenuIsOpen = false; frames(30)
	assert((spider() - p0).Magnitude < 0.05, "a key held into the menu kept walking after it closed")
	key("Forward", false)
end)
check("the words follow the device: a controller's input shows the controller's buttons", function()
	game:GetService("UserInputService").LastInputTypeChanged:Fire(Enum.UserInputType.Gamepad1)
	key("Help", true); key("Help", false); frames(2)
	if not find("SpiderPrompts", "Controls").Visible then key("Help", true); key("Help", false); frames(2) end
	assert(string.find(find("SpiderPrompts", "Controls").Text, "Hold A aim", 1, true), find("SpiderPrompts", "Controls").Text)
	game:GetService("UserInputService").LastInputTypeChanged:Fire(Enum.UserInputType.Keyboard)
	frames(2)
	assert(string.find(find("SpiderPrompts", "Controls").Text, "Hold Space aim", 1, true), "keyboard words did not come back")
end)
check("on a leaf: F walks to the edge and lets down; the line's prompts, touch Let go and a held Q let go", function()
	local driver = ClientStubs.driver
	assert(driver, "the client did not hand its test driver over")
	driver.place(Vector3.new(0.5, 4.51, -3.0))
	frames(5)
	key("Drop", true); frames(2)
	assert(find("SpiderPrompts", "Toast").Text == "To the edge, to let yourself down", find("SpiderPrompts", "Toast").Text)
	assert(string.find(find("SpiderPrompts", "PromptHint").Text, "Q or move: stop", 1, true), find("SpiderPrompts", "PromptHint").Text)
	frames(150)
	key("Drop", false)
	assert(driver.get().line == "locked", "not on the line")
	assert(find("SpiderPrompts", "PromptTitle").Text == "On your line", find("SpiderPrompts", "PromptTitle").Text)
	assert(find("SpiderPrompts", "PromptHint").Text == "W: reel in    S: lower    hold Q: let go", find("SpiderPrompts", "PromptHint").Text)
	local touch = gui:FindFirstChild("SpiderTouch")
	assert(touch:FindFirstChild("Cancel").Text == "Let go\n(hold)" and touch:FindFirstChild("Jump").Visible == false, "touch buttons not set for the line")
	frames(40)
	key("Cancel", true); frames(20)
	assert(driver.get().line == "locked" and string.find(find("SpiderPrompts", "PromptCue").Text, "Letting go...", 1, true), "no let-go progress shown")
	frames(25)
	key("Cancel", false); frames(2)
	assert(driver.get().line == "none" and find("SpiderPrompts", "Toast").Text == "You let go of the line", "a held Q did not let go")
	frames(120)
	assert(driver.get().mode == "attached" and touch:FindFirstChild("Cancel").Text == "Cancel" and touch:FindFirstChild("Jump").Visible, "touch buttons not restored")
end)
check("on the line, W reels back and the spider takes hold of the leaf", function()
	local driver = ClientStubs.driver
	driver.place(Vector3.new(0.5, 4.51, -3.0))
	frames(5)
	driver.drop(); frames(160)
	assert(driver.get().line == "locked", "not hanging")
	key("Forward", true); frames(600); key("Forward", false); frames(2)
	assert(driver.get().mode == "attached" and driver.get().position.Y > 3, `ended at {driver.get().position}`)
end)

check("holding W at a leaf's edge walks over it and along the underside, never back and forth", function()
	local driver = ClientStubs.driver
	driver.place(Vector3.new(0.5, 4.51, -0.5))
	frames(5)
	local motor = driver.motor
	local flips, lastY, under = 0, motor.up.Y, false
	key("Forward", true)
	for _ = 1, 120 do
		frames(1)
		if motor.up.Y < -0.9 then under = true end
		if lastY < 0.5 and motor.up.Y > 0.9 and not under then flips += 1 end
		lastY = motor.up.Y
	end
	key("Forward", false)
	assert(flips == 0 and under, `flips {flips}, underside {under}`)
end)

check("in the crack E rests; in the evening the spider sleeps until morning, the light and the eyes' reach follow, moving wakes", function()
	local driver = ClientStubs.driver
	local life, needs = driver.life, driver.needs
	-- The server's Lit.apply is not run here: give Lighting the daytime sun it would have picked.
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = 9.75, 2.6
	lighting:SetAttribute("SunPick", "ok: test")
	assert(life and needs and driver.prey.feeding.needs == needs, "the client did not hand over one life loop and NeedsModel, shared with feeding")
	assert(needs.lifeMode, "hunger by the hour on the windowsill")
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	assert(driver.lifeSpider().inRetreat, "the spider is not in the crack")
	life.clock.hour = 12
	frames(2)
	assert(string.find(find("SpiderPrompts", "PromptHint").Text, "E: rest", 1, true), "no rest prompt: " .. find("SpiderPrompts", "PromptHint").Text)
	assert(find("SpiderPrompts", "Day").Text == "Day 1, midday", find("SpiderPrompts", "Day").Text)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting and not life.asleep, "E did not rest")
	assert(string.find(find("SpiderPrompts", "PromptTitle").Text, "Resting", 1, true), find("SpiderPrompts", "PromptTitle").Text)
	assert(find("SpiderPrompts", "Notice").Visible, "no notice for the rest")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(not life.resting, "E again did not end the rest")
	-- Evening: rest becomes sleep; the night passes quickly and ends in the morning of day 2.
	life.clock.hour = 19.0
	frames(2)
	assert(string.find(find("SpiderPrompts", "PromptHint").Text, "sleep until morning", 1, true), find("SpiderPrompts", "PromptHint").Text)
	local dayClock = 9.75
	key("Feed", true); frames(2); key("Feed", false)
	frames(120)
	assert(life.asleep and life.clock.day == 1, `not asleep (hour {life.clock.hour})`)
	assert(math.abs(driver.sensor.core.rangeScale - life.rangeScale) < 1e-12 and life.rangeScale < 1, "the sensor's reach does not follow the hour")
	assert(lighting.ClockTime < dayClock and lighting.Brightness < 2.6, `the light did not dim at night (clock {lighting.ClockTime}, brightness {lighting.Brightness})`)
	frames(600)
	assert(life.clock.day == 2 and not life.asleep and life.resting and math.abs(life.clock.hour - 7) < 0.05, `no morning: day {life.clock.day}, {life.clock.hour}`)
	assert(string.find(find("SpiderPrompts", "Notice").Text, "Morning, day 2", 1, true), find("SpiderPrompts", "Notice").Text)
	-- Still resting after the morning: when evening comes again the rest becomes sleep by itself; walking wakes the spider.
	life.clock.hour = 21
	frames(30)
	assert(life.asleep, "not asleep the second night")
	key("Forward", true); frames(10); key("Forward", false); frames(2)
	assert(not life.asleep and not life.resting, "walking did not wake the spider")
	assert(string.find(life.notice, "Awake before morning", 1, true), life.notice)
end)

check("Backspace returns to the checkpoint kept by a rest, or to the start when there is none", function()
	local driver = ClientStubs.driver
	local life, needs, prey = driver.life, driver.needs, driver.prey
	assert(driver.checkpoints:loadBest().ok, "the rests above kept no checkpoint")
	-- A new rest at midday keeps a fresh checkpoint.
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting and life.notice == "Checkpoint kept.", "no checkpoint: " .. life.notice)
	local energy, hour, tick = needs.energy, life.clock.hour, prey.tick
	-- Walk away for a while: the world moves on.
	key("Forward", true); frames(90); key("Forward", false); frames(60)
	assert(not life.resting and prey.tick > tick + 100, "the world did not move on")
	key("Reset", true); frames(1); key("Reset", false); frames(2)
	assert(driver.lifeSpider().inRetreat and life.resting, "not back resting in the crack")
	assert(math.abs(life.clock.hour - hour) < 0.01 and prey.tick < tick + 10, `not the checkpoint's time (hour {life.clock.hour}, tick {prey.tick})`)
	assert(needs == driver.needs and prey.feeding.needs == needs and math.abs(needs.energy - energy) < 1e-6, "the reserves did not go back")
	assert(string.find(find("SpiderPrompts", "Notice").Text, "checkpoint recovery", 1, true), find("SpiderPrompts", "Notice").Text)
end)


check("sound pauses with the menu and respects mute", function()
	local root = workspace:FindFirstChild("WindowsillAudio")
	assert(root, "soundscape missing from client")
	local room = root:FindFirstChild("room")
	local gs = game:GetService("GuiService")
	gs.MenuIsOpen = false; frames(1); assert(room.Playing)
	gs.MenuIsOpen = true; frames(1); assert(not room.Playing)
	gs.MenuIsOpen = false; frames(1); assert(room.Playing)
	local p = game:GetService("Players").LocalPlayer
	p:SetAttribute("SoundMuted", true); frames(1); assert(not room.Playing)
	p:SetAttribute("SoundMuted", false); frames(1); assert(room.Playing)
end)
check("sound follows flight, struggle, night, slow motion and replacement flies", function()
	local Soundscape = require("../src/Client/Soundscape")
	local s = Soundscape.new(workspace)
	local f = { position = Vector3.new(3,4,5), flying = true }
	function f:airborne() return self.flying end
	local p = { flies = {f}, feeding = {held = nil, struggling = false} }
	s:update(0.1, p, 1, false, 0.5, false)
	assert(s.slots[1].buzz.Playing and s.slots[1].buzz.PlaybackSpeed == 0.5)
	assert(s.slots[1].part.Position == f.position)
	f.flying = false; s:update(0.1, p, 1, false, 1, false)
	assert(not s.slots[1].buzz.Playing)
	p.feeding.held = f; p.feeding.struggling = true
	s:update(0.1, p, 1, false, 1, false); assert(s.slots[1].buzz.Playing)
	p.feeding.struggling = false
	s:update(0.1, p, 1, false, 1, false); assert(not s.slots[1].buzz.Playing)
	s.nextBird = 0; s:update(0.1, p, 1, false, 1, false); assert(s.birds.Playing)
	s:update(0.1, p, 0, false, 1, false); assert(not s.birds.Playing)
	p.flies = {}; s:update(0.1, p, 1, false, 1, false); assert(next(s.slots) == nil)
	s:destroy(); assert(s.root.Parent == nil)
end)
print(`CLIENT passed={passed} failed={failed}`)
if failed > 0 then error("client smoke failed") end
