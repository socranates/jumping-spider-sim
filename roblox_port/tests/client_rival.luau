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
	for _ = 1, 40 do
		frames(30)
		moved = math.max(moved, (life.rival.position - at).Magnitude)
		if Layout.inRetreat(life.rival.position) then crack += 1 end
		life.clock.hour = 9 -- (stay in the morning)
	end
	assert(moved > 3, "the rival did not walk (" .. tostring(moved) .. ")")
	assert(crack == 0, "the rival entered the retreat")
	assert(life.rival.up ~= nil and math.abs(life.rival.up.Magnitude - 1) < 1e-6, "the rival has no support direction")
	local root = rig:FindFirstChild("Root") or rig:FindFirstChildWhichIsA("BasePart")
	assert(root and (root.Position - life.rival.position).Magnitude < 1.0, "the drawn rival is not where the rival is")
end)
print("CLIENT_RIVAL passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_RIVAL failed") end
