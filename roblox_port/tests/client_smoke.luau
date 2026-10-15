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
local KEYS = { Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Eye = "V", Recenter = "R", Creep = "LeftShift", Reset = "Backspace" }
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
	assert(workspace.CurrentCamera.FieldOfView == 80, "no eye-view field of view")
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


print(`CLIENT passed={passed} failed={failed}`)
if failed > 0 then error("client smoke failed") end
