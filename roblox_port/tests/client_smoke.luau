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
	assert(workspace.CurrentCamera.FieldOfView == 65 and not string.find(find("SpiderPrompts", "Status").Text, "SPIDER-EYE VIEW", 1, true), "did not leave the eye view") -- a notebook discovery can still occupy the shared status line
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
	local feeding = driver.prey.feeding
	assert(feeding.startGrip == 0.5 and feeding.tapGain == 0.12 and feeding.jerkScale == 0.8, "the client did not give feeding the game's easier tap (Data/Catch.game, ROBLOX-72)")
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	assert(driver.lifeSpider().inRetreat, "the spider is not in the crack")
	life.clock.hour = 12
	frames(2)
	assert(string.find(find("SpiderPrompts", "PromptHint").Text, "E: rest", 1, true), "no rest prompt: " .. find("SpiderPrompts", "PromptHint").Text)
	assert(find("SpiderPrompts", "Day").Text == "Day 1, midday | young juvenile", find("SpiderPrompts", "Day").Text)
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
check("the wasp: heard with a direction, found, caught, carried off; the catch screen offers the way back and the world goes on", function()
	local driver = ClientStubs.driver
	local wasp, life, prey = driver.wasp, driver.life, driver.prey
	assert(wasp and driver.caughtPanel, "the client did not hand over the wasp and the catch screen")
	assert(not wasp.enabled, "the wasp comes by itself in the test place")
	driver.place(Vector3.new(2.0, 0.31, 6.0))
	life.clock.day, life.clock.hour = 3, 12.0
	prey.feeding.mealsFinished = 1
	frames(30)
	assert(not wasp:isVisiting(), "a visit began on its own")
	workspace:SetAttribute("WaspForce", "floor_middle")
	frames(30)
	assert(wasp:isVisiting() and wasp.phase == "arriving", `no visit: {wasp.phase}`)
	assert(workspace:GetAttribute("WaspForce") == nil, "the force attribute was not taken")
	local audioRoot = workspace:FindFirstChild("WindowsillAudio")
	local hum = audioRoot:FindFirstChild("wasp")
	assert(hum and hum.Playing and hum.SoundId == "rbxassetid://76049518783466", "arrival warning has no sound")
	local caption = find("SpiderPrompts", "Caption")
	assert(caption.Visible and string.find(caption.Text, "[a deep, heavy hum outside, ", 1, true) and string.find(caption.Text, "coming closer]", 1, true), "no heard caption: " .. tostring(caption.Text))
	local status = find("SpiderPrompts", "Status")
	assert(string.find(status.Text, "a wasp is coming", 1, true), "no warning line: " .. tostring(status.Text))
	assert(wasp:percept() ~= nil and wasp:percept().maxCategory == "movement", "the wasp is not movement to the senses")
	-- The 8 s of warning are Godot's numbers and the director suite's business; here they are skipped (the wasp flies at once).
	wasp.speed = 1e6
	frames(3)
	assert(wasp.phase == "searching", `still {wasp.phase}`)
	assert(hum.Parent == audioRoot:FindFirstChild("WaspAudio") and hum.Playing, "search hum did not become spatial")
	local seized = false
	local panel = driver.caughtPanel
	-- Finding a spider is the director suite's business (movement noticed fast, stillness slowly); here it has just found this one.
	wasp.notice, wasp.lastSeen = 1.0, driver.motor.pos
	frames(2)
	assert(wasp.phase == "inspecting", `not found: {wasp.phase}`)
	assert(string.find(find("SpiderPrompts", "Caption").Text, "[the deep hum turns toward you, ", 1, true), "no caption for the look: " .. find("SpiderPrompts", "Caption").Text)
	assert(string.find(find("SpiderPrompts", "Status").Text, "has seen you", 1, true), find("SpiderPrompts", "Status").Text)
	for _ = 1, 60 * 12 do
		frame(1 / 60)
		if driver.motor.seized then seized = true break end
	end
	assert(seized, `the spider was never caught: {wasp.phase}`)
	assert(string.find(find("SpiderPrompts", "Status").Text, "Stung", 1, true), find("SpiderPrompts", "Status").Text)
	wasp.speed = 1e6 -- the carry, skipped
	for _ = 1, 60 do
		frame(1 / 60)
		if panel:isShowing() then break end
	end
	assert(panel:isShowing() and wasp.phase == "away", "the catch screen did not come after the carry")
	assert(not hum.Playing and not audioRoot:FindFirstChild("room").Playing, "audio kept running under the catch screen")
	assert(driver.motor.pos.Y > 8, `not carried up and away: {driver.motor.pos}`)
	assert(find("SpiderCaught", "Line").Text == "A mud dauber wasp stung the spider and carried it away.", "the plain line")
	assert(not find("SpiderCaught", "Back").Visible, "the choices were up at once")
	local tick = prey.tick
	frames(30)
	panel:update(5.0) -- the screen's own seconds
	frames(2)
	assert(prey.tick == tick, "the game did not wait under the catch screen")
	assert(find("SpiderCaught", "Back").Visible and find("SpiderCaught", "Back").Text == "Back to your last rest", find("SpiderCaught", "Back").Text)
	key("Reset", true); frames(1); key("Reset", false)
	assert(panel:isShowing() and driver.motor.seized, "Backspace got past the catch screen")
	key("Jump", true); frames(2); key("Jump", false)
	assert(panel:isShowing() and driver.motor.seized, "Space got past the catch screen")
	services.actions["WindowsillChoiceSpiderCaught"]("WindowsillChoiceSpiderCaught", Enum.UserInputState.Begin, {})
	frames(3)
	assert(not panel:isShowing() and not driver.motor.seized and not wasp:isVisiting() and not wasp.holding, "the way back did not put the world right")
	assert(find("SpiderPrompts", "Day") ~= nil and find("SpiderHud", "Reticle") ~= nil, "the screen")
	local back = prey.tick
	frames(60)
	assert(prey.tick >= back + 55, "the game did not go on")
	-- The checkpoint kept the wasp's record as it was at the rest, before this visit: the same wasp can come again.
	assert(wasp.visits == 0 and wasp.escapes == 0 and wasp.lastVisitDay == 0, `the record: {wasp.visits} visits, {wasp.escapes} escapes, day {wasp.lastVisitDay}`)
end)

check("the peacock spider: C in the crack changes spider, X dances, any move, jump or Cancel stops it; the first spider never sees the dance", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local function words(screen: string, name: string): string
		local d = find(screen, name)
		return if d and d.Visible then d.Text else ""
	end
	driver.place(Layout.SPAWN)
	frames(60)
	assert(driver.appearance() == "first_spider" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "first_spider", "not the first spider at the start")
	key("Display", true); frames(2); key("Display", false); frames(30)
	assert(not driver.dance().active and driver.rig().dance == nil, "the first spider danced")
	assert(not string.find(words("SpiderPrompts", "PromptHint"), "dance", 1, true) and not string.find(words("SpiderPrompts", "Controls"), "courtship", 1, true), "the dance is mentioned for the first spider")
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(words("SpiderPrompts", "Toast") == "You can change spider while resting in the silk-lined crack", words("SpiderPrompts", "Toast"))
	assert(driver.appearance() == "first_spider", "changed spider outside the crack")
	-- In the crack, awake and resting: C turns the first spider into the peacock spider.
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 9.75
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	frames(2)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting and not life.asleep, "E did not rest")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "C: become the peacock spider", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(gui:FindFirstChild("SpiderTouch"):FindFirstChild("Choose").Visible == true, "no touch Change button in the crack")
	local oldModel = workspace:FindFirstChild("Spider")
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(driver.appearance() == "maratus_volans_male", "C did not change spider")
	local model = workspace:FindFirstChild("Spider")
	assert(model ~= oldModel and model:GetAttribute("AppearanceId") == "maratus_volans_male" and oldModel.Parent == nil, "the rig was not built again")
	assert(game:GetService("Players").LocalPlayer:GetAttribute("Appearance") == "maratus_volans_male", "the choice is not kept for the session")
	assert(words("SpiderPrompts", "Toast") == "You are the peacock spider now", words("SpiderPrompts", "Toast"))
	assert(life.resting, "changing spider ended the rest")
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(not life.resting, "E did not end the rest")
	-- On the open sill: X starts the dance, the status and the hint say so.
	driver.place(Layout.SPAWN)
	frames(60)
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: courtship dance", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(gui:FindFirstChild("SpiderTouch"):FindFirstChild("Display").Visible == true and gui:FindFirstChild("SpiderTouch"):FindFirstChild("Choose").Visible == false, "touch buttons: Dance on the sill, Change only in the crack")
	local p0 = spider()
	key("Display", true); frames(2); key("Display", false); frames(60)
	assert(driver.dance().active and driver.rig().dance ~= nil and driver.rig().dance.presence > 0.99, "X did not start the dance")
	assert(string.find(words("SpiderPrompts", "Status"), "COURTSHIP DANCE    X or move: stop", 1, true), words("SpiderPrompts", "Status"))
	assert(string.find(words("SpiderPrompts", "PromptHint"), "X: stop dancing", 1, true), words("SpiderPrompts", "PromptHint"))
	assert(gui:FindFirstChild("SpiderTouch"):FindFirstChild("Display").Text == "Stop", "touch button does not say Stop")
	assert(string.find(words("SpiderPrompts", "Caption"), "[a fine buzzing through your feet]", 1, true), "no felt caption in the rumble-rump: " .. words("SpiderPrompts", "Caption"))
	assert((spider() - p0).Magnitude < 0.02, "the dance moved the spider")
	frames(240)
	local fan = driver.rig()._fan
	assert(fan ~= nil and driver.rig().dance.fanOpen > 0.9 and fan.front[1].part.Size.X > 0.25, `the fan is not open at {driver.dance().t} s`)
	assert(string.find(words("SpiderPrompts", "Controls"), "courtship dance", 1, true) or not find("SpiderPrompts", "Controls").Visible, "the card")
	-- Walking stops it at once and the pose is gone 0.2 s later.
	key("Forward", true); frames(1)
	assert(not driver.dance().active, "walking did not stop the dance")
	frames(14); key("Forward", false); frames(2)
	assert(driver.rig().dance == nil and not driver.dance():showing(), "the pose did not fade out")
	-- A jump (Space) and Cancel (Q) stop it too; X again toggles it off.
	key("Display", true); frames(2); key("Display", false); frames(30)
	assert(driver.dance().active, "the dance did not restart")
	key("Jump", true); frames(1)
	assert(not driver.dance().active, "Space did not stop the dance")
	key("Jump", false); frames(60)
	key("Display", true); frames(2); key("Display", false); frames(30)
	assert(driver.dance().active, "the dance did not restart after the hop")
	key("Cancel", true); frames(1); key("Cancel", false)
	assert(not driver.dance().active, "Q did not stop the dance")
	frames(30)
	key("Display", true); frames(2); key("Display", false); frames(30)
	key("Display", true); frames(2); key("Display", false); frames(2)
	assert(not driver.dance().active, "X again did not stop the dance")
	frames(30)
	-- Slow motion slows the dance as it slows everything; reduced motion is read from the player's attribute.
	key("Display", true); frames(2); key("Display", false)
	local t0 = driver.dance().t
	key("Slow", true); key("Slow", false); frames(120)
	local advanced = driver.dance().t - t0
	assert(advanced > 0.9 and advanced < 1.1, `slow motion: the dance advanced {advanced} s in 2 s`)
	key("Slow", true); key("Slow", false)
	game:GetService("Players").LocalPlayer:SetAttribute("ReducedMotion", true)
	frames(2)
	assert(driver.dance().reduced == true, "ReducedMotion not read")
	game:GetService("Players").LocalPlayer:SetAttribute("ReducedMotion", nil)
	key("Display", true); frames(2); key("Display", false); frames(2)
	-- The eye view and the hidden body survive a change of spider; on a controller RB changes spider in the crack and dances elsewhere.
	game:GetService("UserInputService").LastInputTypeChanged:Fire(Enum.UserInputType.Gamepad1)
	frames(2)
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "no rest")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "RB: become the ant-mimicking spider", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Eye", true); key("Eye", false); frames(3)
	key("Display", true); frames(2); key("Display", false); frames(2)
	assert(driver.appearance() == "myrmarachne_formicaria_female" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "myrmarachne_formicaria_female", "RB in the crack did not change to the ant-mimicking spider")
	local anyVisible = false
	for _, d in workspace:FindFirstChild("Spider"):GetChildren() do
		if d:IsA("BasePart") and d.Name == "Cephalothorax" and d.LocalTransparencyModifier ~= 1 then anyVisible = true end
	end
	assert(not anyVisible, "the new rig did not keep the eye view")
	assert(string.find(words("SpiderPrompts", "PromptHint"), "RB: become the first spider", 1, true), words("SpiderPrompts", "PromptHint"))
	key("Display", true); frames(2); key("Display", false); frames(2)
	assert(driver.appearance() == "first_spider" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "first_spider", "RB in the crack did not come round to the first spider")
	key("Eye", true); key("Eye", false); frames(3)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	game:GetService("UserInputService").LastInputTypeChanged:Fire(Enum.UserInputType.Keyboard)
	frames(2)
end)

check("wasp hum lasts through arrival, pauses, follows slow motion and silences grounded/away states", function()
	local Soundscape = require("../src/Client/Soundscape")
	local s = Soundscape.new(workspace)
	local d = { phase = "arriving", wasp = { mode = "flying", position = Vector3.new(38,19,2) } }
	for _ = 1, 480 do
		s:updateWasp(d, false, 1, false)
		assert(s.waspHum.Playing and s.waspHum.Parent == s.root and s.waspHum.Volume >= 0.3)
	end
	s:updateWasp(d, true, 0.5, false); assert(not s.waspHum.Playing)
	s:updateWasp(d, false, 0.5, false); assert(s.waspHum.Playing and s.waspHum.PlaybackSpeed == 0.5)
	s:updateWasp(d, false, 1, true); assert(not s.waspHum.Playing)
	d.phase = "searching"; d.wasp.mode = "walking"
	s:updateWasp(d, false, 1, false); assert(not s.waspHum.Playing)
	d.wasp.mode = "flying"; s:updateWasp(d, false, 1, false)
	assert(s.waspHum.Playing and s.waspHum.Parent == s.waspEmitter and s.waspEmitter.Position == d.wasp.position)
	d.phase = "away"; s:updateWasp(d, false, 1, false); assert(not s.waspHum.Playing)
	s:destroy()
end)

check("walk through the crack entrance and rest, without teleporting inside",function()
 local d=ClientStubs.driver
 assert(d.fresh("main",false,nil))
 d.motor:place(Vector3.new(-22,.31,6),Vector3.yAxis,-Vector3.xAxis);d.camera:snap();frames(5)
 key("Forward",true)
 for _=1,180 do frames(1);if d.motor.pos.X < -24 then break end end
 key("Forward",false);frames(15)
 assert(d.lifeSpider().inRetreat,`could not walk into crack: {d.motor.pos}`)
 key("Feed",true);frames(1);key("Feed",false);frames(3)
 assert(d.life.resting,"rest did not begin after entering")
 assert(d.currentStore():loadBest().ok,"no checkpoint")
end)
check("starvation pauses once, last rest revives, another spider resets world and keeps cosmetic",function()
 local d=ClientStubs.driver
 local deaths=d.session.deaths
 d.needs.starvingStreakH=48;frames(2)
 assert(d.session.ended and d.caughtPanel:isShowing() and d.session.deaths==deaths+1)
 local hour=d.life.clock.hour;frames(300);assert(d.life.clock.hour==hour,"end did not pause")
 assert(d.caughtPanel:choose("Back"));frames(3)
 assert(not d.session.ended and d.needs.starvingStreakH<48,"rest did not revive")
 d.endLife("wasp");frames(300)
 local look=d.appearance()
 assert(d.caughtPanel:choose("Another"));assert(#d.memory:contacts()==0,"old memory retained");frames(3)
 assert(not d.session.ended and d.life.clock.day==1 and d.prey.feeding.mealsFinished==0)
 assert(not d.currentStore():loadBest().ok,"old life leaked")
 assert(d.appearance()==look and string.find(d.life.notice,"not related",1,true))
end)
check("life menu blocks movement, supports gamepad selection, Free play and new-life confirmation",function()
 local d=ClientStubs.driver;d.openMenu();assert(d.menu:isShowing())
 local before=d.motor.pos;key("Jump",true);key("Forward",true);frames(10);key("Forward",false);key("Jump",false)
 assert((d.motor.pos-before).Magnitude<.001,"modal input moved spider")
 local fn=services.actions["WindowsillChoiceSpiderLifeMenu"]
 fn("",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.DPadDown})
 assert(d.menu.selected==2,"D-pad focus did not move")
 assert(d.menu:choose("Free"));frames(3)
 assert(d.session.mode=="free" and d.needs.gentle and d.wasp.gentle)
 d.endLife("wasp");assert(not d.caughtPanel:isShowing(),"free ended")
 d.needs:addHours(400,false);frames(35);assert(d.needs.energy>=.1-1e-9 and not d.session.ended)
 d.openMenu();d.menu:choose("New");assert(d.menu:isShowing(),"no new-life confirmation")
 d.menu:choose("New");frames(3);assert(d.session.mode=="main" and not d.needs.gentle)
end)
check("main and free play keep independent last rests and restore their own rules",function()
 local d=ClientStubs.driver
 assert(d.fresh("main",false,nil));d.place(Vector3.new(-25.5,.31,6));frames(4)
 d.needs.energy=.7;key("Feed",true);frames(1);key("Feed",false);frames(2)
 local main=d.currentStore():loadBest();assert(main.ok)
 d.openMenu();assert(d.menu:choose("Free"));frames(3)
 d.place(Vector3.new(-25.5,.31,6));frames(4);d.needs.energy=.3
 key("Feed",true);frames(1);key("Feed",false);frames(2)
 assert(d.currentStore():loadBest().ok)
 d.openMenu();assert(d.menu:choose("Continue"));frames(3)
 assert(d.session.mode=="main" and not d.needs.gentle and d.needs.energy>.6)
 d.openMenu();assert(d.menu:choose("Free"));frames(3)
 assert(d.session.mode=="free" and d.needs.gentle and d.needs.energy<.4)
 assert(d.fresh("main",false,nil))
end)
print(`CLIENT passed={passed} failed={failed}`)
if failed > 0 then error("client smoke failed") end
