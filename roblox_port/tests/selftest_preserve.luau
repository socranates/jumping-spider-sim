-- The live place's self-test (Client/SelfTest) in the preserve (ROBLOX-115): the same run as tests/selftest.luau, against the real client, but on the world a server
-- builds when the Workspace attribute World is "preserve" (Server/Main: the map made the preserve, the sill's Decor without the test garden's view, the World
-- folder with the sill alone). It proves the client reads the attribute and runs the preserve (its looks are the backdrop's zones, its trains run), that the
-- self-test's preserve checks pass here (the hut's sill, the backdrop near and far, the trains) in place of the garden's, and that a rest kept in the hut names
-- the preserve. Not evidence of streaming, the engine, sound or frame times (the shim has none).
local WorldMap = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local Scenery = require("../src/Shared/Habitat/Scenery")
local SelfTest = require("../src/Client/SelfTest")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL selftest_preserve: " .. name .. "\n    " .. tostring(err)) end
end

-- ---------------------------------------------------------------- the host (as tests/selftest.luau's)
local lines: { string } = {}
local co: thread? = nil
local simClock = 0.0
SelfTest.host = {
	spawn = function(fn: () -> ()) co = coroutine.create(fn) end,
	wait = function(seconds: number) coroutine.yield(seconds) end,
	clock = function(): number return simClock end,
	print = function(line: string) table.insert(lines, line); print(line) end,
	sample = function(seconds: number): string
		local t0 = simClock
		coroutine.yield(seconds)
		return string.format("shim: %d simulated frames of 1/60 s (no engine here: not a frame time)", math.floor((simClock - t0) * 60 + 0.5))
	end,
}

-- ---------------------------------------------------------------- the world as Server/Main builds the preserve, and the client
workspace:ClearAllChildren()
workspace:SetAttribute("World", "preserve")
WorldMap.use("preserve")
local decor, replaced = Scenery.decor(nil, "preserve")
decor.Parent = workspace
local hidden: { [string]: boolean } = {}
for id in replaced do hidden[id] = true end
WorldBuild.world(workspace, WorldMap.SEED, hidden)
local focusRemote = Instance.new("RemoteEvent")
focusRemote.Name = "WorldFocus"
focusRemote.Parent = game:GetService("ReplicatedStorage")
workspace:SetAttribute("SelfTest", true)
WorldMap.use("test_garden") -- (the client must make the preserve active itself, from the attribute)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim

check("the world the server built: the sill alone in World, a Decor without the test garden's view", function()
	local world = workspace:FindFirstChild("World")
	assert(world ~= nil and #world:GetChildren() == 1 and world:FindFirstChild("Windowsill") ~= nil, "World holds the sill alone")
	assert(decor:FindFirstChild("Wall") ~= nil and decor:FindFirstChild("View") == nil, "the Decor has its window wall and no view")
end)

check("the client reads the attribute: the preserve is its world, its looks the backdrop's zones, its trains running", function()
	assert(loaded, "SpiderClient did not load: " .. tostring(loadError))
	assert(WorldMap.world() == "preserve", "the client did not make the preserve the active world")
	local driver = ClientStubs.driver
	assert(driver.world.world == "preserve" and #WorldMap.regions() == 1, "the client's world is the preserve's")
	for _ = 1, 30 do frame(1 / 60); simClock += 1 / 60 end
	local looks = driver.world.looks
	assert(looks ~= nil and looks.plan.hut ~= nil and looks.plan.railway == "far", `the looks plan the backdrop (the hut {tostring(looks and looks.plan.hut)})`)
	assert(driver.world.train ~= nil, "no trains")
end)

check("the self-test runs to END in the preserve, its own checks in place of the garden's, every one passing here", function()
	assert(co ~= nil, "the self-test was not started")
	local thread = co :: thread
	local frames = 0
	while coroutine.status(thread) ~= "dead" do
		local ok, seconds = coroutine.resume(thread)
		assert(ok, "the run raised: " .. tostring(seconds))
		if coroutine.status(thread) == "dead" then break end
		local n = math.max(1, math.floor((tonumber(seconds) or 0) * 60 + 0.5))
		for _ = 1, n do
			frame(1 / 60)
			simClock += 1 / 60
		end
		frames += n
		assert(frames < 60 * 600, "the run went on for more than ten minutes of play")
	end
	print(string.format("selftest_preserve: the run took %.1f s of play (%d frames)", simClock, frames))
	local last = lines[#lines]
	assert(last ~= nil and string.find(last, "[SELFTEST] END pass=", 1, true) == 1, "the last line is not END: " .. tostring(last))
	local fails, passes, infos = 0, {}, {}
	for _, line in lines do
		if string.find(line, "[SELFTEST] FAIL", 1, true) == 1 then fails += 1 end
		local name = string.match(line, "^%[SELFTEST%] PASS (.+)$")
		if name then passes[name] = true end
		local what = string.match(line, "^%[SELFTEST%] INFO ([^:]+):")
		if what then infos[what] = true end
	end
	assert(fails == 0, `{fails} checks failed here (see the FAIL lines above)`)
	local want = { "new life", "intro", "world folders", "region sill", "walk on the sill", "prey on the sill", "lock", "the hut's sill", "the backdrop near and far", "the trains",
		"notebook", "rest and checkpoint", "sound", "frame time on the sill", "part counts" }
	for _, name in want do assert(passes[name], "no PASS for " .. name) end
	for _, garden in { "the line", "prey in the bed", "woodlice", "moths on the wall" } do assert(not passes[garden], "a garden check ran in the preserve: " .. garden) end
	assert(last == `[SELFTEST] END pass={#want} fail=0 skip=0`, "the END line: " .. last)
	for _, what in { "world", "the hut's sill", "backdrop", "trains", "lock" } do assert(infos[what], "no INFO line for " .. what) end
	local worldLine = false
	for _, line in lines do if line == "[SELFTEST] INFO world: preserve (revision preserve-1)" then worldLine = true end end
	assert(worldLine, "the world line names the preserve")
end)

check("a rest kept in the hut's crack names the preserve", function()
	local driver = ClientStubs.driver
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.world == "preserve" and best.record.world_map.revision == "preserve-1" and best.record.world_map.retreat == "sill_crevice",
		"the kept rest: " .. tostring(best.ok and best.record.world_map.world))
	local home = WorldMap.region(WorldMap.HOME) :: any
	assert((driver.motor.pos - (home.spawn.pos + Vector3.new(0, 0.31, 0))).Magnitude < 0.3 and driver.world.region.id == "sill", "back at the sill's spawn")
end)

print("SELFTEST_PRESERVE passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("SELFTEST_PRESERVE failed") end
