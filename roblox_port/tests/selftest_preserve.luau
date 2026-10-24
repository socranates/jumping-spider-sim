-- The live place's self-test (Client/SelfTest) in the preserve (ROBLOX-115): the same run as tests/selftest.luau, against the real client, but on the world a server
-- builds when the Workspace attribute World is "preserve" (Server/Main: the map made the preserve, the sill's Decor without the test garden's view, the World
-- folder with the sill and (ROBLOX-116) the ranger hut and its garden). It proves the client reads the attribute and runs the preserve (its looks are the
-- backdrop's zones and the hut's regions, its trains run), that the self-test's preserve checks pass here (the hut's sill, the backdrop near and far, the trains,
-- and ROBLOX-116's: the nursery's shut window and the ranger's moment, the hut's inside walked from the sill to the floor, the way out through the propped sash
-- and down the logs to the bench and the ground, the hut garden's life, its homes and the lamp) in place of the garden's, and that a rest kept in the hut names
-- the preserve and the self-test's opening of the window never reaches the progress record. Not evidence of streaming, the engine, sound or frame times (the
-- shim has none).
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
-- Loading is bounded work, not simulated ecology. Await actual TitleReady before
-- asserting drawn gameplay; fixed30-frame readiness was an obsolete assumption.
if frame and loaded then
 for _=1,5000 do
  frame(1/60)
  if game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true then break end
 end
 assert(game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true,"preserve startup did not complete")
end

local preserveRegions = (function() local was = WorldMap.use("preserve"); local n = #WorldMap.regions(); WorldMap.use(was); return n end)()
check("the world the server built: the sill and the hut's regions in World, a Decor without the test garden's view", function()
	local world = workspace:FindFirstChild("World")
	-- (the client adds its own HutLife folder: the window's sash and wedge)
	assert(world ~= nil and world:FindFirstChild("Windowsill") ~= nil and world:FindFirstChild("hut_desk") ~= nil and world:FindFirstChild("garden_d4") ~= nil
		and #world:GetChildren() == preserveRegions + 1 and world:FindFirstChild("HutLife") ~= nil, `World holds the sill, the hut and its garden ({#world:GetChildren()} of {preserveRegions} and the client's)`)
	assert(decor:FindFirstChild("Wall") ~= nil and decor:FindFirstChild("View") == nil, "the Decor has its window wall and no view")
end)

check("the client reads the attribute: the preserve is its world, its looks the backdrop's zones, its trains running", function()
	assert(loaded, "SpiderClient did not load: " .. tostring(loadError))
	assert(WorldMap.world() == "preserve", "the client did not make the preserve the active world")
	local driver = ClientStubs.driver
	assert(driver.world.world == "preserve" and #WorldMap.regions() == preserveRegions and preserveRegions == 266, `the client's world is the compact preserve ({#WorldMap.regions()} regions; 182 authored plus 84 infill)`)
	assert(WorldMap.region("room_exit") ~= nil, "the cracked back-room window has its authored outdoor landing")
	assert(driver.world.hut ~= nil and not driver.world.hut.open and driver.world.hut.sash ~= nil, "the hut's window is shut in a new save")
	for _ = 1, 30 do frame(1 / 60); simClock += 1 / 60 end
	local looks = driver.world.looks
	assert(looks ~= nil and looks.plan.hut ~= nil and looks.plan.railway == "far", `the looks plan the backdrop (the hut {tostring(looks and looks.plan.hut)})`)
	assert(driver.world.train ~= nil, "no trains")
	-- (ROBLOX-118) the ranger's cat lives in the preserve's hut: made, drawn, asleep on the sofa at the day's start
	local hooks = ClientStubs.driver
	assert(hooks.cat ~= nil and workspace:FindFirstChild("Cat") ~= nil, "no cat in the preserve, or not drawn")
	-- (ROBLOX-119) the crab spiders on the meadow's flowers: made, placed and drawn
	-- (ROBLOX-120) the robin of the open ground: made and drawn (its folder), away at the day's start
	assert(hooks.bird ~= nil and workspace:FindFirstChild("Robin") ~= nil and not hooks.bird.here, "no robin in the preserve, or not away at night")
	assert(hooks.crab ~= nil and #hooks.crab.crabs == 2 and workspace:FindFirstChild("CrabSpiders") ~= nil and #(workspace:FindFirstChild("CrabSpiders") :: Instance):GetChildren() == 2, "no crab spiders in the preserve, or not drawn")
	-- (ROBLOX-122) the pond's edge: the water and the green frog made, the frog on its seat and drawn
	assert(hooks.water ~= nil and hooks.frog ~= nil and hooks.frog.here and workspace:FindFirstChild("PondAnimals") ~= nil
		and (workspace:FindFirstChild("PondAnimals") :: Instance):FindFirstChild("GreenFrog") ~= nil, "no water or frog in the preserve, or the frog not drawn")
end)

check("the self-test runs to END in the preserve, its own checks in place of the garden's, every one passing here", function()
	assert(co ~= nil, "the self-test was not started")
	local thread = co :: thread
	local frames = 0
	-- Each additional regional visit holds attachment for1.2 s plus readiness.
	-- Keep the original global allowance and add2 s per new region. Individual
	-- readiness, save and return deadlines inside SelfTest stay unchanged.
	local maxPlaySeconds = 600 + math.max(0, preserveRegions - 233) * 2
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
		assert(frames < 60 * maxPlaySeconds, `the run exceeded its bounded {maxPlaySeconds} s allowance`)
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
	local want = { "new life", "intro", "world folders", "walk on the sill", "prey on the sill", "lock", "the hut's sill", "the backdrop near and far", "the trains",
		"the nursery: the window shut", "the nursery: the ranger props the window", "the hut's inside", "the way out", "the hut garden", "the garden's near detail", "the station's rival and garden's mate", "the hut's homes",
		"the hut by night: the lamp", "the ceiling and the upper walls", "the back room", "the eaves", "the cat", -- (ROBLOX-118)
		"the bench patch", "the meadow's edge", "the crab spiders", -- (ROBLOX-119)
		"the robin", "the field crickets", "ballooning's landings", -- (ROBLOX-120)
		"the mown path and the boardwalk", "the water", "the pond's life", "the green frog", -- (ROBLOX-122)
		"the nursery: the window put back", "notebook", "rest and checkpoint", "sound", "frame time on the sill", "part counts",
  "fallbacks clear the shelf books and station boots","visible meal and contextual controls","Normal starvation reaches the life-ending handler" }
	WorldMap.use("preserve")
	for _, region in WorldMap.regions() do table.insert(want, "region " .. region.id) end
	for _, name in want do assert(passes[name], "no PASS for " .. name) end
	for _, garden in { "the line", "prey in the bed", "woodlice", "moths on the wall" } do assert(not passes[garden], "a garden check ran in the preserve: " .. garden) end
	assert(last == `[SELFTEST] END pass={#want} fail=0 skip=0`, "the END line: " .. last)
	for _, what in { "world", "the hut's sill", "backdrop", "trains", "lock", "the nursery", "the hut's inside", "the way out", "the hut garden", "the garden's near detail", "the station's rival and garden's mate", "the hut's homes",
		"the ceiling", "the back room", "the eaves", "the cat", "the bench patch", "the meadow's edge", "the crab spiders",
		"the robin", "the field crickets", "ballooning's landings", "the mown path and the boardwalk", "the water", "the pond's life", "the green frog" } do assert(infos[what], "no INFO line for " .. what) end
	local worldLine = false
	for _, line in lines do if line == "[SELFTEST] INFO world: preserve (revision preserve-3)" then worldLine = true end end
	assert(worldLine, "the world line names the preserve")
end)

check("a rest kept in the hut's crack names the preserve", function()
	local driver = ClientStubs.driver
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.world == "preserve" and best.record.world_map.revision == "preserve-3" and best.record.world_map.retreat == "sill_crevice",
		"the kept rest: " .. tostring(best.ok and best.record.world_map.world))
	local home = WorldMap.region(WorldMap.HOME) :: any
	assert((driver.motor.pos - (home.spawn.pos + Vector3.new(0, 0.31, 0))).Magnitude < 0.3 and driver.world.region.id == "sill", "back at the sill's spawn")
end)

check("the self-test's opening of the window was put back and never kept: the progress says shut", function()
	local driver = ClientStubs.driver
	assert(driver.world.hut ~= nil and not driver.world.hut.open and driver.world.hut.sash ~= nil and not driver.world:hutOpen(), "the window is shut again")
	assert(driver.world.hut.opened == 1, `the window opened once this session ({driver.world.hut.opened})`)
end)

-- ROBLOX-121: the walkable boxes' shadows through the real client (Client/WorldShadows): the sill's line counts every visible box outside the sill, and from the sill
-- more than 600 of them cast none; the far preserve's comparison was sampled and everything it took out is back, the shadows on again.
check("the sill's shadows and the far preserve's comparison through the real client, everything put back", function()
	local driver = ClientStubs.driver
	local sh = driver.world.shadows
	assert(sh ~= nil and sh.at ~= nil, "the client keeps the boxes' shadows")
	local shadowLine, farLine = nil, nil
	for _, line in lines do
		if string.find(line, "[SELFTEST] INFO shadows on the sill: ", 1, true) == 1 then shadowLine = line end
		if string.find(line, "[SELFTEST] INFO the far preserve on the sill: ", 1, true) == 1 then farLine = line end
	end
	assert(shadowLine ~= nil and farLine ~= nil, "the shadows' line and the far preserve's line")
	local on, kept = string.match(shadowLine :: string, "INFO shadows on the sill: (%d+) of (%d+) visible walkable boxes cast")
	WorldMap.use("preserve")
	local world = workspace:FindFirstChild("World") :: Instance
	local entries = 0
	for _, f in world:GetChildren() do
		local region = WorldMap.region(f.Name)
		if f.Name ~= "Windowsill" and region ~= nil then
			for _, p in f:GetChildren() do if (p :: any).Transparency < 1 then entries += 1 end end
		end
	end
	assert(tonumber(kept) == entries and tonumber(on) ~= nil and (tonumber(on) :: number) < entries - 600, `the line: {on} of {kept} cast ({entries} visible boxes outside the sill)`)
	assert(string.find(farLine :: string, "without the far preserve (", 1, true) ~= nil and string.match(farLine :: string, "%((%d+) folders, (%d+) parts out%)") ~= nil, "the far preserve's line: " .. tostring(farLine))
	local folders, parts = string.match(farLine :: string, "%((%d+) folders, (%d+) parts out%)")
	assert((tonumber(folders) :: number) > 50 and (tonumber(parts) :: number) > 1000, `the far preserve's {folders} folders and {parts} parts`)
	assert(#world:GetChildren() == preserveRegions + 1, `every region's folder back in World ({#world:GetChildren()})`)
	assert(game:GetService("Lighting").GlobalShadows ~= false, "the shadows on again")
	for _, what in { "frame time on the sill without the far preserve", "profile on the sill without the far preserve", "frame time on the sill without shadows", "profile on the sill without shadows" } do
		local found = false
		for _, line in lines do if string.find(line, "[SELFTEST] INFO " .. what .. ":", 1, true) == 1 then found = true end end
		assert(found, "no INFO line: " .. what)
	end
end)

-- ROBLOX-120: ballooning through the real client: a brood hatched, the card's two ways on, "Follow one", the ride (the world waits, the camera on the rider), and the
-- next generation where the wind's draw set it down, its start kept in the rest it makes and in the notebook.
check("ballooning through the real client: the card offers Follow one and Stay at the hut; the ride; the next generation begins where the wind's draw lands it", function()
	local driver = ClientStubs.driver
	local Mating = require("../src/Shared/Life/Mating")
	local Ballooning = require("../src/Shared/Life/Ballooning")
	local life, mateLegs, panel = driver.life, driver.mateLegs, driver.caughtPanel
	driver.place(Vector3.new(-25.5, 0.31, 6.0), Vector3.yAxis)
	for _ = 1, 10 do frame(1 / 60) end
	local m = Mating.normalize(Mating.new())
	m.stage, m.hatch_day, m.hatch_hour, m.brood, m.mates, m.sac_day = "hatched", life.clock.day, 7.0, 9, 1, math.max(1, life.clock.day - 2)
	life.mating = m
	local generation = Mating.generation(life)
	local zone, region = Ballooning.land(914, generation, m.hatch_day)
	for _ = 1, 30 do frame(1 / 60); if panel:isShowing() then break end end
	assert(panel:isShowing() and mateLegs.phase == "card", `the ending card is up ({mateLegs.phase})`)
	local ids = {}
	for _, c in panel.choices or {} do table.insert(ids, c.id) end
	assert(table.concat(ids, ",") == "Follow,Carry", "the card's two ways on: " .. table.concat(ids, ","))
	local chose = false
	for _ = 1, 600 do if panel:choose("Follow") then chose = true; break end; frame(1 / 60) end
	assert(chose, "Follow one could not be chosen")
	assert(mateLegs.phase == "ride" and mateLegs.ride ~= nil and mateLegs.ride.zone == zone and mateLegs.ride.region == region, `the ride to {zone} / {region} began ({mateLegs.phase})`)
	local day = life.clock.day
	local riders = 0
	for _ = 1, 60 * 13 do
		frame(1 / 60)
		if workspace:FindFirstChild("Family") and (workspace:FindFirstChild("Family") :: Instance):FindFirstChild("Rider") then riders += 1 end
		if mateLegs.phase ~= "ride" then break end
	end
	assert(riders > 60 * 10, `the rider was drawn through the ride ({riders} frames)`)
	assert(life.clock.day == day, "the world waited through the ride")
	assert(mateLegs.phase == "" and Mating.generation(life) == generation + 1 and life.start_zone == zone and life.start_region == region, `the next generation began in {tostring(life.start_zone)} / {tostring(life.start_region)}`)
	local spawn = (WorldMap.region(region) :: any).spawn.pos + Vector3.new(0, 0.31, 0)
	for _ = 1, 30 do frame(1 / 60) end
	assert((driver.motor.pos - spawn).Magnitude < 1 and driver.world.region.id == region and driver.motor.mode == "attached", `it stands where it landed ({driver.world.region.id})`)
	assert(life.growth.stage == 0 and not life.lifeOver, "a spiderling, alive")
	local told = false
	for _, e in driver.notebook:entriesFor("eggs_and_wind") do if string.find(e.text, "the wind set it down", 1, true) then told = true end end
	assert(told, "the notebook's dated line says where the wind set it down")
end)

print("SELFTEST_PRESERVE passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("SELFTEST_PRESERVE failed") end
