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
check("a late 'carried off' word for a rival the wasp does not hold changes nothing (ROBLOX-91); for the one it holds, it is gone for the day", function()
	local driver = ClientStubs.driver
	local life, wasp = driver.life, driver.wasp
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	life.clock.hour = 9
	local r = life.rival
	assert(r and r.state ~= "dormant" and r.state ~= "consumed", "a rival to keep")
	r.state, r.elapsed, r.notice, r.fate, r.day = "patrol", 0, 0, nil, nil
	r.position = Vector3.new(-20, 0.31, -9)
	r.previous = r.position
	wasp:_signal({ kind = "rival_carried_off" })
	frames(2)
	assert(life.rival.state == "patrol" and life.rival.fate == nil, `a rival that was not taken is left alone: {life.rival.state} {tostring(life.rival.fate)}`)
	r.state = "taken"
	wasp:_signal({ kind = "rival_carried_off" })
	frames(2)
	assert(life.rival.state == "consumed" and life.rival.fate == "taken by the wasp", `the one that was taken is gone: {life.rival.state}`)
	-- Leave it as the other checks expect: a rival of today, patrolling.
	life.clock.day += 1
	life.clock.hour = 8
	frames(10)
	life.clock.hour = 9
	assert(life.rival.state == "patrol", `a new rival the next morning: {life.rival.state}`)
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
			while Rival.contest(914, life.clock.day, n, gentle) ~= want do n += 1 end
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
	assert(state == "recover" and notice == "It bit back! Jump away!" and math.abs(cost - 0.30) < 0.02 and count == 1, `counter-bite: {state} "{notice}" cost {cost}`)
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
check("a caught rival is a hard meal (ROBLOX-77): the Grip button and the grip bar work for it, it can be subdued and then eaten, or tear free to recover; gentle says it is safe", function()
	local driver = ClientStubs.driver
	local life, needs, prey = driver.life, driver.needs, driver.prey
	local Rival = require("../src/Shared/Predator/RivalSpider")
	local RivalText = require("../src/Shared/UI/RivalText")
	local Grip = require("../src/Shared/Predator/RivalGrip")
	local KEY = { Jump = "Space" }
	local function key(action: string, down: boolean)
		local fn = services.actions["Spider" .. action]
		fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
			{ KeyCode = Enum.KeyCode[KEY[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	end
	local function find(screen: string, name: string): any
		local g = gui:FindFirstChild(screen)
		for _, d in g:GetDescendants() do if d.Name == name then return d end end
		return nil
	end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	life.clock.hour = 9
	-- A rival of today that has not noticed the spider, caught by one strike (no draw); returns the rival.
	local function catch(): any
		local r = life.rival
		r.state, r.elapsed, r.notice, r.contests, r.spared, r.food, r.subdued, r.day, r.fate = "patrol", 0, 0, 0, nil, Rival.FOOD, nil, nil, nil
		r.position = driver.motor.pos + Vector3.new(0.2, 0, 0)
		r.previous = r.position
		life.notice, life.noticeSeconds = "", 0
		prey.strikeEnd = prey.tick + 1
		frames(1)
		return r
	end
	local function status(): string return find("SpiderPrompts", "Status").Text end
	needs.energy, needs.gentle = 0.2, false
	local r = catch()
	local home = driver.motor.pos
	assert(r.state == "captured" and r.subdued == false and Rival.struggling(r), `caught: {r.state}`)
	assert(life.notice == RivalText.CAPTURED, `the catch line: "{life.notice}"`)
	frames(3)
	assert(Grip.active(driver.rivalLegs.grip), "the grip is on")
	assert(string.find(status(), "Holding the rival — tap Space to keep your grip", 1, true), `the status line: "{status()}"`)
	assert(not string.find(status(), "Eating rival", 1, true), "it is not being eaten yet")
	assert(find("SpiderPrompts", "GripBar").Visible == true, "the grip bar shows for the rival")
	local gripFill = find("SpiderPrompts", "Grip")
	assert(gripFill.Size.X.Scale > 0 and gripFill.Size.X.Scale < 1, `the bar shows the grip ({gripFill.Size.X.Scale})`)
	-- Taps, about 5.5 a second: the jump button is the grip (the spider does not aim or leap), nothing is eaten, and in a few seconds it is subdued.
	local frameCount = 0
	while r.subdued == false and frameCount < 60 * 20 do
		if frameCount % 11 == 0 then key("Jump", true); frames(1); key("Jump", false) else frames(1) end
		frameCount += 1
		assert(r.state == "captured", `the rival left the jaws at frame {frameCount}: {r.state}`)
		assert(r.food == Rival.FOOD, "nothing is eaten while it fights")
		assert(not driver.jump:isBusy(), "a tap grips; it does not start a jump")
	end
	assert(r.subdued == true, "the tapping did not subdue the rival")
	assert((driver.motor.pos - home).Magnitude < 0.05, "the spider leapt while gripping")
	frames(1)
	assert(life.notice == RivalText.SUBDUED, `the subdued line: "{life.notice}"`)
	assert(find("SpiderPrompts", "GripBar").Visible == false, "the bar is gone once it is subdued")
	assert(string.find(status(), "Eating rival", 1, true) and string.find(status(), "(2 meals)", 1, true), `the status line, with what it is worth: "{status()}"`)
	-- Eaten, standing still: five seconds, 0.7 of food, the meal counted.
	local meals, e0 = prey.feeding.mealsFinished, needs.energy
	frames(60 * 6)
	assert(r.state == "consumed" and r.fate == "eaten" and prey.feeding.mealsFinished == meals + 1, `eaten: {r.state}`)
	assert(math.abs(needs.energy - e0 - 0.7) < 0.03, `0.7 of food (energy {e0} to {needs.energy})`)
	-- The next morning another; with no taps it tears free: recover, nothing lost, nothing harmed, the same rival.
	life.clock.day += 1
	life.clock.hour = 8
	frames(10)
	assert(life.rival.state == "patrol", `a new rival: {life.rival.state}`)
	needs.energy = 0.5
	r = catch()
	assert(r.state == "captured" and r.subdued == false, "caught again")
	local waited = 0
	while r.state == "captured" and waited < 60 * 6 do frames(1); waited += 1 end
	assert(r.state == "recover" and waited > 60 and waited < 60 * 4, `no taps: it tore free to recover after {waited / 60} s ({r.state})`)
	assert(r.subdued == nil and r.food == Rival.FOOD and r.day == nil and r.fate == nil, "and it is still a whole rival with its day")
	assert(life.notice == RivalText.TORE, `the tore-free line: "{life.notice}"`)
	assert(not Grip.active(driver.rivalLegs.grip) and find("SpiderPrompts", "GripBar").Visible == false, "the grip is gone")
	assert(life.cause == nil and math.abs(needs.energy - 0.5) < 0.03, "nothing harmed the spider")
	assert(workspace:FindFirstChild("RivalSpider") ~= nil, "and it is drawn again where it stands")
	-- Gentle: it is the house fly's struggle, and the line says it is safe.
	needs.gentle = true
	r = catch()
	waited = 0
	while r.state == "captured" and waited < 60 * 6 do frames(1); waited += 1 end
	assert(r.state == "recover" and waited < 60 * 2, `gentle, no taps: it tore free after {waited / 60} s ({r.state})`)
	assert(life.notice == RivalText.TORE_GENTLE, `the gentle tore-free line: "{life.notice}"`)
	assert(life.cause == nil, "and the spider is safe")
	needs.gentle = false
	-- Leave it as the other checks expect.
	needs.energy = 0.8
	life.rival.state, life.rival.contests, life.rival.subdued = "patrol", 0, nil
end)
check("the Eat key grips a caught rival too, like the Jump key; the touch Feed button says Grip for it (ROBLOX-92)", function()
	local driver = ClientStubs.driver
	local life, needs, prey = driver.life, driver.needs, driver.prey
	local Rival = require("../src/Shared/Predator/RivalSpider")
	local Grip = require("../src/Shared/Predator/RivalGrip")
	local function key(action: string, down: boolean)
		local fn = services.actions["Spider" .. action]
		fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
			{ KeyCode = Enum.KeyCode[if action == "Feed" then "E" else action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	life.clock.day += 1
	life.clock.hour = 9
	frames(10)
	needs.energy, needs.gentle = 0.3, false
	local r = life.rival
	r.state, r.elapsed, r.notice, r.contests, r.spared, r.food, r.subdued, r.day, r.fate = "patrol", 0, 0, 0, nil, Rival.FOOD, nil, nil, nil
	r.position = driver.motor.pos + Vector3.new(0.2, 0, 0)
	r.previous = r.position
	prey.strikeEnd = prey.tick + 1
	frames(3)
	assert(r.state == "captured" and r.subdued == false and Grip.active(driver.rivalLegs.grip), `caught: {r.state}`)
	local touch = gui:FindFirstChild("SpiderTouch")
	driver.setDevice("touch")
	frames(3)
	assert(touch:FindFirstChild("Feed").Visible ~= false and touch:FindFirstChild("Feed").Text == "Grip", `the Feed button says Grip: "{touch:FindFirstChild("Feed").Text}"`)
	assert(touch:FindFirstChild("Jump").Text == "Grip", "(and so does Jump)")
	driver.setDevice("keyboard")
	local before = Grip.level(driver.rivalLegs.grip)
	key("Feed", true); frames(1); key("Feed", false)
	assert(Grip.level(driver.rivalLegs.grip) > before, `one tap of E raised the grip ({before} to {Grip.level(driver.rivalLegs.grip)})`)
	local count = 0
	while r.subdued == false and count < 60 * 20 do
		if count % 11 == 0 then key("Feed", true); frames(1); key("Feed", false) else frames(1) end
		count += 1
		assert(r.state == "captured", `the rival left the jaws at frame {count}: {r.state}`)
		assert(not driver.jump:isBusy() and not driver.life.resting, "a tap of E grips: it does not rest or start a jump")
	end
	assert(r.subdued == true, "tapping E did not subdue the rival")
	frames(60 * 6)
	assert(r.state == "consumed", `and it was eaten: {r.state}`)
	needs.energy = 0.8
	life.rival.state, life.rival.contests, life.rival.subdued = "patrol", 0, nil
end)
print("CLIENT_RIVAL passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_RIVAL failed") end
