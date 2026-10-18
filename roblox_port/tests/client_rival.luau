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
check("striking a rival that has seen the spider is a contest (ROBLOX-73): each outcome has its notice, a counter-bite costs energy (none in the gentle modes), an unaware rival is still caught outright", function()
	local driver = ClientStubs.driver
	local life, needs, prey = driver.life, driver.needs, driver.prey
	local Rival = require("../src/Shared/Predator/RivalSpider")
	local RivalText = require("../src/Shared/UI/RivalText")
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	life.clock.hour = 9
	assert(life.rival and life.rival.state ~= "dormant" and life.rival.state ~= "consumed", "a rival to strike at")
	-- One strike at a rival in `state` (with `notice`) whose next draw is `want`. Returns the rival's state, the notice shown, the energy it cost and the draws made.
	local function strike(state: string, notice: number, want: string?, gentle: boolean): (string, string, number, number)
		local r = life.rival
		local n = 0
		if want ~= nil then
			while Rival.contest(914, life.clock.day, n) ~= want do n += 1 end
		end
		r.state, r.elapsed, r.notice, r.contests, r.spared = state, 0, notice, n, nil
		r.position = driver.motor.pos + Vector3.new(0.2, 0, 0)
		r.previous = r.position
		life.notice, life.noticeSeconds = "", 0
		needs.energy, needs.gentle = 0.8, gentle
		prey.strikeEnd = prey.tick + 1
		local before = needs.energy
		frames(1)
		local cost = before - needs.energy
		needs.gentle = false
		return r.state, life.notice, cost, r.contests - n
	end
	local state, notice, cost, count = strike("stalk", 0, "captured", false)
	assert(state == "captured" and notice == RivalText.CAPTURED and count == 1, `caught: {state} "{notice}"`)
	state, notice, cost, count = strike("windup", 0, "sprang", false)
	assert(state == "recover" and notice == "It sprang clear of your strike." and cost < 0.02 and count == 1, `sprang clear: {state} "{notice}" cost {cost}`)
	state, notice, cost, count = strike("patrol", 0.5, "counter", false)
	assert(state == "recover" and notice == "It bit back! Jump away!" and math.abs(cost - 0.25) < 0.02 and count == 1, `counter-bite: {state} "{notice}" cost {cost}`)
	assert(life.cause == nil, "a counter-bite does not end the life")
	state, notice, cost = strike("stalk", 0, "counter", true)
	assert(state == "recover" and notice == RivalText.COUNTER_GENTLE and cost < 0.02, `gentle counter-bite: {state} "{notice}" cost {cost}`)
	state, notice, cost, count = strike("patrol", 0, nil, false)
	assert(state == "captured" and notice == RivalText.CAPTURED and count == 0, `an unaware rival is caught outright: {state}, {count} draws`)
	state, notice, cost, count = strike("recover", 1, nil, false)
	assert(state == "captured" and count == 0, "and so is one that is recovering")
	-- Leave it as the other checks expect: a rival of today, patrolling, and the spider's reserves as they were.
	life.rival.state, life.rival.contests, life.rival.spared, life.rival.food = "patrol", 0, nil, Rival.FOOD
	needs.energy = 0.8
end)
print("CLIENT_RIVAL passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_RIVAL failed") end
