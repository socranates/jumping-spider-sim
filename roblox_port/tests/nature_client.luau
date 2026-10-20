-- Nature's rules through the real client (ROBLOX-106, W4): walking costs energy in Normal and not in Free play, the cover factor the client hands the predators
-- (a leaf overhead, stillness, moving in the open), a night out in the bed that ends the life with the night's own card and Normal's words about the lost day, a
-- night that spares the spider and leaves a cold, slow morning, a night on the sill that is nothing, and a return to a rest that meets the same night again. On the
-- folders the server builds, as tests/world_client.luau runs them. A smoke test of the wiring on the shim's box world, not engine evidence.
-- Run with the other suites:  python3 tests/run.py path/to/luau nature_client.luau
local WorldMap = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local Nature = require("../src/Shared/Life/Nature")
local LifeText = require("../src/Shared/UI/LifeText")
local NeedsModel = require("../src/Shared/Life/NeedsModel")

local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL nature_client: " .. name .. "\n    " .. tostring(err)) end
end

workspace:ClearAllChildren()
local decorModel = Instance.new("Model")
decorModel.Name = "Decor"
decorModel.Parent = workspace
WorldBuild.world(workspace, WorldMap.SEED)
local focusRemote = Instance.new("RemoteEvent")
focusRemote.Name = "WorldFocus"
focusRemote.Parent = game:GetService("ReplicatedStorage")
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local KEYS = { Feed = "E", Forward = "W", Reset = "Backspace", Drop = "F" }
local function key(action: string, down: boolean)
	local fn = ClientStubs.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local OPEN = Vector3.new(10, 0.31, 8)
local UNDER_LEAF = Vector3.new(-15, 0.31, -1.5)
local BED = Vector3.new(0, -89.69, -40) -- the bed's soil, in the open, away from the stone

check("the client loads on the World folder and stands on the sill", function()
	assert(loaded, "SpiderClient did not load: " .. tostring(loadError))
	frames(60)
	assert(ClientStubs.driver ~= nil and ClientStubs.driver.nature ~= nil, "the driver is handed nature's state")
	assert(ClientStubs.driver.session.rules == "standard", "Normal")
end)

check("walking costs energy in Normal: two seconds of W cost 0.0008 more than two seconds standing", function()
	local d = ClientStubs.driver
	local needs = d.needs
	d.life.clock.hour = 12
	needs.energy = 0.9
	d.place(OPEN)
	frames(10)
	local e0 = needs.energy
	frames(120)
	local still = e0 - needs.energy
	d.place(OPEN)
	frames(10)
	local e1 = needs.energy
	key("Forward", true); frames(120); key("Forward", false)
	local walked = e1 - needs.energy
	assert(math.abs((walked - still) - 0.0004 * 2) < 0.00012, `walking cost {walked - still} more than standing (0.0008)`)
	assert(needs.moveCosts == true, "the reserve has the game's rules")
end)

check("the cover factor the predators are handed: still under a leaf a quarter, walking in the open double, still in the open a half", function()
	local d = ClientStubs.driver
	d.place(UNDER_LEAF)
	frames(20)
	assert(d.nature.cover == 0.25, `still under the west leaf: {d.nature.cover}`)
	d.place(OPEN)
	frames(20)
	assert(d.nature.cover == 0.5, `still in the open: {d.nature.cover}`)
	key("Forward", true); frames(20)
	assert(d.nature.cover == 2.0, `walking in the open: {d.nature.cover}`)
	key("Forward", false); frames(10)
end)

-- A night (the day it began) whose first pass finds, and one whose first pass spares.
local foundNight, coldNight
for night = 3, 60 do
	if foundNight == nil and Nature.found(914, night, 1) then foundNight = night end
	if coldNight == nil and not Nature.found(914, night, 1) then coldNight = night end
end

check("out in the bed after dark, the first pass of the night finds the spider: the night's card, and in Normal the words of the lost day", function()
	local d = ClientStubs.driver
	local life = d.life
	assert(foundNight ~= nil, "a night that finds")
	local hour = Nature.passHours(914, foundNight)[1]
	d.place(BED)
	frames(20)
	assert(d.world.region.id == "bed_a" and d.world:inRetreat(d.motor.pos) == nil, "in the open in the bed")
	life.clock.day, life.clock.hour = foundNight, hour - 0.02
	table.clear(d.nature.night)
	local n = 0
	while not d.caughtPanel:isShowing() and n < 60 * 20 do frames(1); n += 1 end
	assert(d.caughtPanel:isShowing() and d.session.ended and d.session.summary.cause == "night", `the life ended in the night ({d.session.summary and d.session.summary.cause})`)
	assert(d.caughtPanel.line.Text == LifeText.NIGHT_LINE and d.caughtPanel.sub.Text == LifeText.NIGHT_SUB, `the night's words: "{d.caughtPanel.line.Text}"`)
	assert(string.find(d.caughtPanel.summary.Text, LifeText.dayLost(d.currentStore():loadBest().ok), 1, true) ~= nil, `Normal's last line: "{d.caughtPanel.summary.Text}"`)
	assert(d.caughtPanel.choices[#d.caughtPanel.choices - 1].id == "Another", "another spider is offered")
	d.caughtPanel:update(5)
	assert(d.caughtPanel:choose("Another"), "another spider")
	frames(5)
	assert(not d.caughtPanel:isShowing() and not d.session.ended, "a new life")
end)

check("a night that spares the spider leaves it cold and slow until ten the next morning; on the sill the same night is nothing", function()
	local d = ClientStubs.driver
	local life = d.life
	assert(coldNight ~= nil, "a night that spares")
	local hour = Nature.passHours(914, coldNight)[1]
	-- On the sill: nothing.
	d.place(OPEN)
	frames(10)
	life.clock.day, life.clock.hour = coldNight, hour - 0.02
	table.clear(d.nature.night)
	frames(120)
	assert(life.cold_day == nil and not d.session.ended and d.nature.night.done >= 1, "on the sill the pass goes by")
	-- In the bed: the cold.
	d.place(BED)
	frames(5)
	life.clock.day, life.clock.hour = coldNight, hour - 0.02
	table.clear(d.nature.night)
	local n = 0
	while life.cold_day == nil and n < 60 * 10 do frames(1); n += 1 end
	assert(life.cold_day == coldNight + 1 and life.notice == LifeText.NIGHT_COLD and not d.session.ended, `spared, and cold: "{life.notice}"`)
	frames(2)
	assert(math.abs(d.motor.speedFactor - 0.6 * d.life.growth:speedFactor()) < 1e-9, `slow: {d.motor.speedFactor}`)
	life.clock.day, life.clock.hour = coldNight + 1, 10.01
	frames(2)
	assert(life.cold_day == nil and math.abs(d.motor.speedFactor - d.life.growth:speedFactor()) < 1e-9, "warm again after ten")
	life.clock.hour = 12
	d.place(OPEN)
	frames(5)
end)

check("in Free play nothing of it: walking is free, no cover factor, a night in the bed is only a night", function()
	local d = ClientStubs.driver
	assert(d.fresh("free", false), "Free play")
	frames(10)
	local needs = d.needs
	assert(needs.gentle, "gentle")
	d.life.clock.hour = 12
	needs.energy = 0.9
	d.place(OPEN)
	frames(10)
	local e0 = needs.energy
	frames(120)
	local still = e0 - needs.energy
	d.place(OPEN)
	frames(10)
	local e1 = needs.energy
	key("Forward", true); frames(120); key("Forward", false)
	-- (a frame's fixed ticks can number one more or fewer over the two windows, about 1 in 120 of the drain; walking's own cost would be 0.0008)
	assert(math.abs((e1 - needs.energy) - still) < 0.00005, `walking is free (walked {e1 - needs.energy}, stood {still}, gentle {tostring(needs.gentle)}, moveCosts {tostring(needs.moveCosts)}, hour {d.life.clock.hour})`)
	assert(d.nature.cover == nil, "no cover factor")
	d.place(BED)
	frames(5)
	d.life.clock.day, d.life.clock.hour = foundNight, Nature.passHours(914, foundNight)[1] - 0.02
	table.clear(d.nature.night)
	frames(120)
	assert(not d.caughtPanel:isShowing() and d.life.cold_day == nil, "the night passes over")
	d.life.clock.hour = 12
	d.place(OPEN)
	frames(5)
	assert(d.fresh("main", false), "back to Normal")
	frames(10)
end)

print(`NATURE_CLIENT passed={passed} failed={failed}`)
if failed > 0 then error("nature_client checks failed") end
