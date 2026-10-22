-- The live place's self-test (ROBLOX-104, Client/SelfTest) run against the real client on the shim's box world: the folders the server builds (WorldBuild), the
-- client loaded with the Workspace attribute SelfTest set (the one line at its end starts it), and a host of this suite's (the run is a coroutine; each wait it asks
-- for is that many simulated frames of 1/60 s; the clock is the simulated one; its lines are kept and printed). It proves the run completes and prints END with
-- every check passing here, before it ever reaches Studio, and that nothing starts it outside Studio or without the attribute. Not evidence of streaming, the
-- engine's physics, sound or frame times (the shim has none: its frame-time line says so).
local WorldMap = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local SelfTest = require("../src/Client/SelfTest")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL selftest: " .. name .. "\n    " .. tostring(err)) end
end

-- ---------------------------------------------------------------- the host
local lines: { string } = {}
local co: thread? = nil
local simClock = 0.0
local sampled = 0.0 -- (the seconds the frame samples took: no heartbeat is said in them, the host's sample being one wait)
local deferredFolder: Instance? = nil
local deferredParent: Instance? = nil
local checkedWhileDistantAbsent = false
SelfTest.host = {
	spawn = function(fn: () -> ()) co = coroutine.create(fn) end,
	wait = function(seconds: number) coroutine.yield(seconds) end,
	clock = function(): number return simClock end,
	print = function(line: string)
		table.insert(lines, line); print(line)
		if string.find(line,"world folders",1,true) and deferredFolder then
			checkedWhileDistantAbsent=deferredFolder.Parent==nil and string.find(line,"PASS world folders",1,true)~=nil
			deferredFolder.Parent=deferredParent
		end
	end,
	sample = function(seconds: number): string
		sampled += seconds
		local t0 = simClock
		coroutine.yield(seconds)
		return string.format("shim: %d simulated frames of 1/60 s (no engine here: not a frame time)", math.floor((simClock - t0) * 60 + 0.5))
	end,
}

-- ---------------------------------------------------------------- the world and the client (as tests/world_client.luau builds them)
workspace:ClearAllChildren()
local decorModel = Instance.new("Model")
decorModel.Name = "Decor"
decorModel.Parent = workspace
WorldBuild.world(workspace, WorldMap.SEED)
-- Native streaming does not retain every far folder at the home pose. Restore
-- this one after the initial guard, so its later region visit still checks all
-- actual support pieces rather than being skipped.
workspace.StreamingEnabled=true
deferredParent=assert(workspace:FindFirstChild("World"))
deferredFolder=assert(deferredParent:FindFirstChild("shrub_west_j"))
deferredFolder.Parent=nil
local focusRemote = Instance.new("RemoteEvent")
focusRemote.Name = "WorldFocus"
focusRemote.Parent = game:GetService("ReplicatedStorage")
workspace:SetAttribute("SelfTest", true)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim

check("the client loads and its one line starts the self-test (Studio, the attribute set)", function()
	assert(loaded, "SpiderClient did not load: " .. tostring(loadError))
	assert(co ~= nil, "the self-test was not started")
end)

check("the self-test runs through the real client to END, every check passing here, in under three minutes of play", function()
	assert(co ~= nil, "no run")
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
	print(string.format("selftest: the run took %.1f s of play (%d frames)", simClock, frames))
	local last = lines[#lines]
	assert(last ~= nil and string.find(last, "[SELFTEST] END pass=", 1, true) == 1, "the last line is not END: " .. tostring(last))
	local fails, passes = 0, {}
	for _, line in lines do
		assert(string.find(line, "[SELFTEST] ", 1, true) == 1, "a line without the prefix: " .. line)
		if string.find(line, "[SELFTEST] FAIL", 1, true) == 1 then fails += 1 end
		local name = string.match(line, "^%[SELFTEST%] PASS (.+)$")
		if name then passes[name] = true end
	end
	assert(fails == 0, `{fails} checks failed here (see the FAIL lines above)`)
	local want = { "new life", "intro", "world folders", "walk on the sill", "the line", "prey on the sill", "lock", "prey in the bed", "woodlice", "frame time in the bed", "frame time in the bed, settled",
		"moths on the wall", "dusk: the moths fly", "notebook", "rest and checkpoint", "sound", "frame time on the sill", "part counts",
  "visible meal and contextual controls","Normal starvation reaches the life-ending handler" }
	for _, region in WorldMap.regions() do table.insert(want, "region " .. region.id) end
	for _, name in want do assert(passes[name], "no PASS for " .. name) end
	assert(last == `[SELFTEST] END pass={#want} fail=0 skip=0`, "the END line: " .. last)
	assert(simClock < 180, string.format("the run took %.0f s of play, more than three minutes", simClock))
end)

check("streaming defers distant folders but still visits and validates the missing-at-start region",function()
 assert(checkedWhileDistantAbsent,"the initial guard required a distant folder to remain loaded")
 assert(deferredFolder.Parent==deferredParent,"the distant region was not restored for its actual visit")
 local visited=false
 for _,line in lines do if line=="[SELFTEST] PASS region shrub_west_j" then visited=true end end
 assert(visited,"streaming must not skip the distant region's support/readiness check")
 workspace.StreamingEnabled=false
end)

check("a heartbeat while it waits, the measures as INFO lines, and the spider left standing where a life begins", function()
	local beats, infos = 0, {}
	for _, line in lines do
		if string.find(line, "[SELFTEST] ... ", 1, true) == 1 then beats += 1 end
		local what = string.match(line, "^%[SELFTEST%] INFO ([^:]+):")
		if what then infos[what] = true end
	end
	assert(beats >= math.floor((simClock - sampled) / SelfTest.HEARTBEAT_S) - 3, `{beats} heartbeats in {simClock} s ({sampled} s of it frame samples)`)
	for _, what in { "line", "frame time in the bed", "frame time on the sill", "sound", "woodlice", "walk",
		-- ROBLOX-111: the profiler's lines: the line's counts, each sample's profile and engine numbers, the census, the looks' settling and the bed's comparisons
		"line ticks", "profile on the line", "profile in the bed", "engine in the bed", "census in the bed", "looks settled in the bed", "frame time in the bed, settled",
		"profile in the bed, settled", "frame time in the bed without the looks", "frame time in the bed without shadows", "profile on the sill", "census on the sill" } do
		assert(infos[what], "no INFO line for " .. what)
	end
	local partsLine = false
	for _, line in lines do if string.find(line, "[SELFTEST] INFO parts at the ", 1, true) == 1 then partsLine = true end end
	assert(partsLine, "no part counts")
	local driver = ClientStubs.driver
	local home = WorldMap.region(WorldMap.HOME) :: any
	assert((driver.motor.pos - (home.spawn.pos + Vector3.new(0, 0.31, 0))).Magnitude < 0.3 and driver.world.region.id == "sill", "not back at the sill's spawn")
	assert(driver.life.clock.hour >= 12 and driver.life.clock.hour < 13, `the hour was not put back ({driver.life.clock.hour})`)
end)

check("it refuses outside Studio, and without the attribute, whatever is asked", function()
	local started = co
	ClientStubs.studio = false
	local outside = SelfTest.start(ClientStubs.driver)
	ClientStubs.studio = true
	workspace:SetAttribute("SelfTest", nil)
	local unset = SelfTest.start(ClientStubs.driver)
	workspace:SetAttribute("SelfTest", false)
	local off = SelfTest.start(ClientStubs.driver)
	assert(not outside and not unset and not off and co == started, "it started where it must not")
end)

print("SELFTEST passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("SELFTEST failed") end
