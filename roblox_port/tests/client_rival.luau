-- (the roaming rival's part of the client smoke run, in a file of its own: the whole smoke run is close to the time one check may take)
-- A smoke run of the client scripts themselves (SpiderClient, SpiderInput, SpiderHud, SpiderCamera, SpiderRig and the shared
-- modules) on the box world, with stub Roblox services (tests/shim.luau): keys are pressed through the same
-- ContextActionService callbacks the engine calls, frames through the bound render step. It catches wiring and runtime
-- errors anywhere in the client loop. Not evidence of rendering, input devices or the engine's physics.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL client_rival: " .. name .. "\n    " .. tostring(err)) end
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

check("the client loads and runs 120 frames", function()
	assert(loaded, "SpiderClient did not load")
	frames(120)
end)
check("the rival comes on day 2 after a meal, walks on its own motor over the sill, is drawn where it stands, and never enters the retreat", function()
	local driver = ClientStubs.driver
	local life = driver.life
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(30)
	life.clock.day = 2
	life.clock.hour = 9
	driver.prey.feeding.mealsFinished = 1
	assert(life.rival == nil or life.rival.state == "dormant", "a rival before it should come")
	frames(10)
	assert(life.rival and life.rival.state == "patrol", "the rival did not arrive: " .. tostring(life.rival and life.rival.state))
	assert(driver.rivalLegs.drive ~= nil, "the rival has no legs")
	local rig = workspace:FindFirstChild("RivalSpider")
	assert(rig, "the rival is not drawn")
	local at = life.rival.position
	local moved = 0.0
	local crack = 0
	for _ = 1, 16 do
		frames(30)
		moved = math.max(moved, (life.rival.position - at).Magnitude)
		if Layout.inRetreat(life.rival.position) then crack += 1 end
		life.clock.hour = 9 -- (stay in the morning)
	end
	assert(moved > 2, "the rival did not walk (" .. tostring(moved) .. ")")
	assert(crack == 0, "the rival entered the retreat")
	assert(life.rival.up ~= nil and math.abs(life.rival.up.Magnitude - 1) < 1e-6, "the rival has no support direction")
	local root = rig:FindFirstChild("Root") or rig:FindFirstChildWhichIsA("BasePart")
	assert(root and (root.Position - life.rival.position).Magnitude < 1.0, "the drawn rival is not where the rival is")
end)
check("the wasp takes the rival (ROBLOX-70): it is drawn hanging under the wasp, the spider is not hunted, the rival is gone for the day and comes again next morning", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local wasp = driver.wasp
	wasp.enabled = true
	assert(life.rival and life.rival.state ~= "dormant" and life.rival.state ~= "consumed", "a rival to take")
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	life.clock.hour = 12
	assert(wasp:force(life.clock.day, "floor_middle"), "the wasp could not be brought")
	wasp.takeRival = true
	local phases, last, hungSeen, noticed = {}, "", false, false
	local rig = workspace:FindFirstChild("RivalSpider")
	for _ = 1, 60 * 45 do
		frame(1 / 60)
		life.clock.hour = 12
		if wasp.phase ~= last then table.insert(phases, wasp.phase); last = wasp.phase end
		if wasp.holdingRival then
			hungSeen = true
			assert(life.rival.state == "taken" and (life.rival.position - wasp.rivalHeldAt).Magnitude < 0.05, "the rival hangs under the wasp")
		end
		if wasp.noticedThisVisit or wasp.holding then noticed = true end
		if wasp.phase == "away" and wasp.visitS > 0 then break end
	end
	assert(not noticed, "the spider was hunted")
	assert(hungSeen and table.concat(phases, ",") == "arriving,taking,seizing,bearing,away", "the visit: " .. table.concat(phases, ","))
	assert(life.rival.state == "consumed" and life.rival.fate == "taken by the wasp" and life.rival.food == 0, "the rival is gone for the day: " .. tostring(life.rival.state))
	assert(life.cause == nil and not (driver.caughtPanel:isShowing()), "the spider is alive and free")
	frames(5)
	assert(workspace:FindFirstChild("RivalSpider") == nil, "its drawing is gone with it")
	-- The next morning a new one.
	life.clock.day += 1
	life.clock.hour = 8
	frames(10)
	assert(life.rival.state == "patrol" and life.rival.fate == nil, "a new rival the next morning: " .. tostring(life.rival.state))
	local _ = rig
end)
print("CLIENT_RIVAL passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_RIVAL failed") end
