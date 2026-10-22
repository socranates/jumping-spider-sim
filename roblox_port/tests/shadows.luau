-- The walkable boxes' shadows (ROBLOX-121, Client/WorldShadows): a box casts its shadow only while it is big enough at its distance from the spider for its shadow
-- to be seen (its middle extent at least WorldShadows.CAST of its distance); a box hidden under a drawing and the sill's own folder are never touched; the rule is
-- asked again when the spider has moved; boxes that arrive later (instance streaming) are taken in with the rule's answer, and a box streamed out and back is found.
-- On the World folder as Server/Main builds it, in the preserve and in the test garden. Not evidence of the engine's frame time (tests/selftest_preserve.luau runs
-- the client's self-test, whose Studio run measures it).
-- Run with the other suites:  python3 tests/run.py path/to/luau shadows.luau
local WorldMap = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local Region = require("../src/Shared/World/Region")
local Meadow = require("../src/Shared/World/Meadow")
local Scenery = require("../src/Shared/Habitat/Scenery")
local WorldShadows = require("../src/Client/WorldShadows")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	WorldMap.use("test_garden")
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end

-- The World folder as Server/Main builds it for a world: the sill's Decor's replaced pieces and every other region's drawn pieces hidden.
local function build(worldId: string): (Instance, Instance)
	local was = WorldMap.use(worldId)
	local ws = Instance.new("Folder")
	local _, replaced = Scenery.decor(nil, worldId)
	local hidden: { [string]: boolean } = {}
	for id in replaced do hidden[id] = true end
	for _, region in WorldMap.regions() do
		if region.kind ~= "sill" then for _, id in Region.drawnPieces(region) do hidden[id] = true end end
	end
	local world = WorldBuild.world(ws, WorldMap.SEED, hidden)
	WorldMap.use(was)
	return ws, world
end

local function casting(p: any): boolean return p.Transparency < 1 and p.CastShadow ~= false end
local function boxOf(p: any): (Vector3, Vector3, number)
	return p.Position - p.Size * 0.5, p.Position + p.Size * 0.5, WorldShadows.middle(p.Size)
end

case("the rule: the middle extent against the distance", function()
	check(WorldShadows.middle(Vector3.new(1, 40, 1)) == 1 and WorldShadows.middle(Vector3.new(164, 2, 10)) == 10 and WorldShadows.middle(Vector3.new(3, 3, 3)) == 3
		and WorldShadows.middle(Vector3.new(5, 2, 9)) == 5, "a culm's 1, a slat's 10, a cube's side, any order")
	local lo, hi = Vector3.new(0, 0, 0), Vector3.new(1, 40, 1)
	check(WorldShadows.distance(lo, hi, Vector3.new(0.5, 20, 0.5)) == 0 and WorldShadows.distance(lo, hi, Vector3.new(4, 44, 1)) == 5, "0 inside, to the nearest point outside")
	check(WorldShadows.CAST == 1 / 500, "a five-hundredth: under two pixels on a 1080p screen at the camera's 65 degrees")
	check(WorldShadows.casts(lo, hi, 1, Vector3.new(1 + 499, 20, 0.5)) and not WorldShadows.casts(lo, hi, 1, Vector3.new(1 + 501, 20, 0.5)), "a culm 1 stud across casts to 500 studs and not beyond")
	check(WorldShadows.casts(lo, hi, 1, Vector3.new(0.5, 20, 0.5)), "a box the spider is on always casts")
end)

case("the preserve from the sill: the far meadow's culms cast none, the bench and the hut cast, hidden boxes and the sill's folder untouched", function()
	local _, world = build("preserve")
	WorldMap.use("preserve")
	local sillFolder = world:FindFirstChild("Windowsill") :: Instance
	local sillBefore: { [Instance]: any } = {}
	for _, p in sillFolder:GetChildren() do sillBefore[p] = (p :: any).CastShadow end
	local visible, hiddenParts = 0, 0
	for _, f in world:GetChildren() do
		if f ~= sillFolder then
			for _, p in f:GetChildren() do if casting(p) then visible += 1 elseif (p :: any).Transparency >= 1 then hiddenParts += 1 end end
		end
	end
	local sh = WorldShadows.new(world, WorldMap, WorldMap.HOME)
	local spawn = (WorldMap.region(WorldMap.HOME) :: any).spawn.pos
	sh:update(spawn, 0)
	local kept, on = sh:counts()
	check(kept == visible and visible > 1300, `every visible box outside the sill kept ({kept} of {visible})`)
	check(sh.passes == 1 and sh.writes == kept - on, `one pass, a write for each box turned off ({sh.writes}, {kept - on} off)`)
	local right, wrong, culmsOff, culms, benchOn, bench = 0, 0, 0, 0, 0, 0
	for _, f in world:GetChildren() do
		if f ~= sillFolder then
			local region = WorldMap.region(f.Name)
			for _, p in f:GetChildren() do
				if (p :: any).Transparency >= 1 then
					if (p :: any).CastShadow ~= false then wrong += 1 end
				elseif region ~= nil then
					local lo, hi, mid = boxOf(p)
					local want = WorldShadows.casts(lo, hi, mid, spawn)
					if ((p :: any).CastShadow ~= false) == want then right += 1 else wrong += 1 end
					if region.kind == "meadow" then culms += 1; if (p :: any).CastShadow == false then culmsOff += 1 end end
					if region.kind == "park_bench" then bench += 1; if (p :: any).CastShadow ~= false then benchOn += 1 end end
				end
			end
		end
	end
	check(wrong == 0 and right == visible, `every box as the rule says, every hidden one still dark ({right} right, {wrong} wrong; {hiddenParts} hidden)`)
	check(kept - on >= 600 and on >= 700, `from the sill {kept - on} of {kept} cast none, {on} cast`)
	check(culms > 600 and culmsOff > culms * 0.8, `the meadow's edge, 12 to 16 m off: {culmsOff} of {culms} boxes cast none`)
	check(bench > 0 and benchOn > 0, `the bench's big boxes cast ({benchOn} of {bench})`)
	local same = true
	for p, v in sillBefore do if (p :: any).CastShadow ~= v then same = false end end
	check(same, "the sill's folder as the server built it")
	-- the hut's own boxes, a few studs to a few metres off, all cast
	local hutOn, hut = 0, 0
	for _, f in world:GetChildren() do
		local region = WorldMap.region(f.Name)
		if region ~= nil and string.sub(region.id, 1, 4) == "hut_" then
			for _, p in f:GetChildren() do if (p :: any).Transparency < 1 then hut += 1; if (p :: any).CastShadow ~= false then hutOn += 1 end end end
		end
	end
	check(hut > 100 and hutOn == hut, `the hut's boxes all cast ({hutOn} of {hut})`)
end)

case("the spider walks to the meadow: its culms cast, the hut's small things far behind cast none; a move under PASS_MOVE asks nothing", function()
	local _, world = build("preserve")
	WorldMap.use("preserve")
	local sh = WorldShadows.new(world, WorldMap, WorldMap.HOME)
	local spawn = (WorldMap.region(WorldMap.HOME) :: any).spawn.pos
	sh:update(spawn, 0)
	local _, onSill = sh:counts()
	local meadow = (WorldMap.region("meadow_c3") :: any).spawn.pos
	local writes0 = sh.writes
	sh:update(meadow, 0.1)
	local kept, on = sh:counts()
	check(sh.passes == 2 and sh.writes > writes0, `a second pass, with writes ({sh.writes - writes0})`)
	local here = WorldMap.region("meadow_c3") :: any
	local folder = world:FindFirstChild(Region.folderName(here)) :: Instance
	local allOn = true
	for _, p in folder:GetChildren() do if (p :: any).Transparency < 1 and (p :: any).CastShadow == false then allOn = false end end
	check(allOn, "every box of the cell the spider stands in casts")
	check(on ~= onSill and kept - on >= 100, `from the meadow {kept - on} of {kept} cast none, {on} cast`)
	local w = sh.writes
	sh:update(meadow + Vector3.new(10, 0, 0), 0.2)
	check(sh.passes == 2 and sh.writes == w, "ten studs on: no pass")
	sh:update(meadow + Vector3.new(WorldShadows.PASS_MOVE, 0, 0), 0.3)
	check(sh.passes == 3, "PASS_MOVE studs on: a pass")
	sh:pass(meadow + Vector3.new(WorldShadows.PASS_MOVE, 0, 0))
	check(sh.writes == sh.writes and sh:pass(meadow + Vector3.new(WorldShadows.PASS_MOVE, 0, 0)) == 0, "the same place again writes nothing")
end)

case("streaming: boxes that arrive later are taken in with the rule's answer; a box streamed out and back is found again", function()
	local _, world = build("preserve")
	WorldMap.use("preserve")
	local folder = world:FindFirstChild("meadow_c3") :: Instance
	local away: { Instance } = {}
	for i, p in folder:GetChildren() do if i <= 3 then table.insert(away, p); p.Parent = nil end end
	local gone = world:FindFirstChild("bench_e") :: Instance
	gone.Parent = nil
	local sh = WorldShadows.new(world, WorldMap, WorldMap.HOME)
	local spawn = (WorldMap.region(WorldMap.HOME) :: any).spawn.pos
	sh:update(spawn, 0)
	local kept0 = sh:counts()
	for _, p in away do p.Parent = folder end
	gone.Parent = world
	sh:update(spawn, 1)
	check((sh:counts()) == kept0, "not looked at again before BIND_EVERY")
	sh:update(spawn, 2)
	local kept1 = sh:counts()
	local benchVisible = 0
	for _, p in gone:GetChildren() do if (p :: any).Transparency < 1 then benchVisible += 1 end end
	check(kept1 == kept0 + 3 + benchVisible, `the three culms and the bench's folder taken in ({kept0} to {kept1})`)
	local ok = true
	for _, p in away do
		local lo, hi, mid = boxOf(p)
		if ((p :: any).CastShadow ~= false) ~= WorldShadows.casts(lo, hi, mid, spawn) then ok = false end
	end
	check(ok, "each given the rule's answer at once")
	-- streamed out and back: the old part leaves, a new one of the same box arrives
	local old: any = nil
	for _, p in away do
		local plo, phi, pmid = boxOf(p)
		if not WorldShadows.casts(plo, phi, pmid, spawn) then old = p end
	end
	assert(old ~= nil, "a culm that casts none from the sill")
	local new = Instance.new("Part") :: any
	new.Name, new.Size, new.Position, new.Transparency = old.Name, old.Size, old.Position, 0
	old.Parent = nil
	new.Parent = folder
	local t = 2
	for _ = 1, 30 do t += WorldShadows.BIND_EVERY; sh:update(spawn, t) end
	local lo, hi, mid = boxOf(new)
	local want = WorldShadows.casts(lo, hi, mid, spawn)
	check(not want and new.CastShadow == false and (sh:counts()) == kept1, `the new part found and given its answer (none), the old one let go ({(sh:counts())} of {kept1})`)
end)

case("the test garden from the sill: its few visible boxes (the rest are under their drawings) as the rule says, the wall under the window casting", function()
	local _, world = build("test_garden")
	local sh = WorldShadows.new(world, WorldMap, WorldMap.HOME)
	local spawn = (WorldMap.region(WorldMap.HOME) :: any).spawn.pos
	sh:update(spawn, 0)
	local kept, on = sh:counts()
	check(kept > 0 and on <= kept and sh.writes == kept - on, `{kept - on} of {kept} cast none from the sill`)
	local wall = world:FindFirstChild("house_wall") :: Instance
	local allOn = true
	for _, p in wall:GetChildren() do if (p :: any).Transparency < 1 and (p :: any).CastShadow == false then allOn = false end end
	check(allOn, "the wall under the window casts")
	print(`SHADOWS: the test garden from the sill, {kept - on} of {kept} visible boxes cast none`)
end)

-- Small real-region fixtures isolate lifecycle behavior without rebuilding the
-- preserve. Old Instance keys are retained by the test solely to inspect whether
-- the manager released them; this is not a GC or frame-rate measurement.
local function streamFixture()
	WorldMap.use("test_garden")
	local region = assert(WorldMap.region("outer_sill"))
	local root = Instance.new("Folder")
	local sh = WorldShadows.new(root, { regions = function() return { region } end }, nil)
	return root, region, sh
end
local function streamPart(folder: Instance, name: string, kind: string): any
	local p: any = Instance.new("Part")
	p.Name, p.Size, p.Position = name, Vector3.one, Vector3.zero
	p.Transparency = if kind == "hidden" or kind == "hidden_lit" then 1 else 0
	p.CastShadow = kind == "visible" or kind == "hidden_lit"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
	p.Parent = folder
	return p
end
local function streamBatch(root: Instance, region: any, kind: string): (Instance, { any })
	local f = Instance.new("Folder"); f.Name = Region.folderName(region); f.Parent = root
	local parts = {}
	local kinds = { "hidden", "off", "visible" }
	for i, piece in Region.pieces(region) do
		table.insert(parts, streamPart(f, piece.id, if kind == "mixed" then kinds[(i - 1) % #kinds + 1] else kind))
	end
	return f, parts
end
local STREAM_FAR = Vector3.new(20000, 0, 0)
case("hidden whole-folder stream-out releases bindings and accepts fresh visible arrivals", function()
	for _, kind in { "hidden", "off", "visible", "mixed" } do
	for _, removal in { "destroy", "unparent" } do
	local root, region, sh = streamFixture()
	local old, oldParts = streamBatch(root, region, kind)
	local eligible = 0; for _, p in oldParts do if p.Transparency < 1 and p.CastShadow then eligible += 1 end end
	sh:update(STREAM_FAR, 0)
	check(sh:counts() == eligible and sh.holders[1].count == #oldParts, "all bindings counted, only eligible parts enter visible rule")
	if removal == "destroy" then old:Destroy() else old.Parent = nil end
	local fresh, parts = streamBatch(root, region, "visible")
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
	for _, p in oldParts do check(sh.holders[1].bound[p] == nil, "obsolete hidden key released") end
	for _, p in parts do
		check(sh.holders[1].bound[p] == true and p.CastShadow == false, "fresh identity immediately receives the existing distance rule")
		check(p.Size == Vector3.one and p.Position == Vector3.zero and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch, "binding never changes physical properties")
	end
	check(sh.holders[1].count == #parts and sh:counts() == #parts, "only the current visible generation is counted")
	check(sh.holders[1].folder == fresh, "rearrival binds the current folder identity")
	old:Destroy(); fresh:Destroy(); root:Destroy()
	end
	end
end)

case("a detached folder's visible parts are released instead of written on a movement pass", function()
	local root, region, sh = streamFixture()
	local folder, parts = streamBatch(root, region, "visible")
	sh:update(STREAM_FAR, 0)
	folder.Parent = nil -- descendants still have the same immediate parent
	local writes = sh.writes
	sh:update(Vector3.zero, 0.1)
	check(sh:counts() == 0 and sh.holders[1].count == 0 and next(sh.holders[1].bound) == nil, "movement drops a folder that left the world")
	local unchanged = true; for _, p in parts do if p.CastShadow ~= false then unchanged = false end end
	check(unchanged and sh.writes == writes, "old detached parts are not toggled back on")
	folder:Destroy(); root:Destroy()
end)

case("hidden and permanently non-casting child replacements release once and preserve flags", function()
	for _, kind in { "hidden", "hidden_lit", "off", "visible" } do
		local root, region, sh = streamFixture()
		local f, parts = streamBatch(root, region, kind)
		sh:update(STREAM_FAR, 0)
		local old = parts[1]
		local name = old.Name; old:Destroy()
		local p = streamPart(f, name, kind)
		local transparency, shadow = p.Transparency, p.CastShadow
		sh:update(STREAM_FAR, WorldShadows.BIND_EVERY / 2)
		check(sh.holders[1].bound[old] == true and sh.holders[1].bound[p] == nil, "cleanup keeps its existing periodic cadence: " .. kind)
		sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
		check(sh.holders[1].bound[old] == nil and sh.holders[1].bound[p] == true, "only the replacement identity stays bound: " .. kind)
		check(sh.holders[1].count == #parts, "release/rebind keeps one count per part: " .. kind)
		check(p.Transparency == transparency and (if kind == "visible" then p.CastShadow == false else p.CastShadow == shadow), "hidden/off flags preserved, visible rule applied: " .. kind)
		sh:update(STREAM_FAR, 2 * WorldShadows.BIND_EVERY + 0.2)
		check(sh.holders[1].count == #parts, "later checks do not release an already-released identity twice: " .. kind)
		f:Destroy(); root:Destroy()
	end
end)

case("mixed repeated region arrivals do not accumulate obsolete generations", function()
	local root, region, sh = streamFixture()
	local folder: Instance? = nil
	local previous: { any } = {}
	local kinds = { "hidden", "off", "mixed", "visible", "hidden_lit" }
	for cycle = 1, 30 do
		if folder then folder:Destroy() end
		local f, parts = streamBatch(root, region, kinds[(cycle - 1) % #kinds + 1])
		folder = f
		sh:update(STREAM_FAR, (cycle - 1) * (WorldShadows.BIND_EVERY + 0.1))
		for _, p in previous do check(sh.holders[1].bound[p] == nil, "prior generation released on cycle " .. cycle) end
		local bound = 0; for _ in sh.holders[1].bound do bound += 1 end
		check(bound == #parts and sh.holders[1].count == #parts, "bound membership stays at current population on cycle " .. cycle)
		check(#sh.entries + #sh.ignored == #parts, "tracking lists stay at current population on cycle " .. cycle)
		previous = parts
	end
	assert(folder); folder:Destroy()
	sh:update(STREAM_FAR, 31 * (WorldShadows.BIND_EVERY + 0.1))
	check(sh.holders[1].count == 0 and next(sh.holders[1].bound) == nil and #sh.entries == 0 and #sh.ignored == 0, "empty final region releases all tracked references")
	root:Destroy()
end)

case("ignored cleanup has its own bounded budget without consuming visible checks", function()
	local root, region, sh = streamFixture()
	local f = Instance.new("Folder"); f.Name = Region.folderName(region); f.Parent = root
	for i = 1, 250 do streamPart(f, "hidden" .. i, "hidden"); streamPart(f, "visible" .. i, "visible") end
	sh:update(STREAM_FAR, 0)
	check(#sh.entries == 250 and #sh.ignored == 250, "both large populations are tracked")
	check(WorldShadows.CHECK_SLICE == 100 and WorldShadows.IGNORED_CHECK_SLICE == 100, "visible and ignored check budgets are each capped at one hundred")
	local writes = sh.writes
	f:Destroy()
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY / 2)
	check(#sh.entries == 250 and #sh.ignored == 250, "neither list is scanned before its next binding tick")
	for tick = 1, 3 do
		sh:update(STREAM_FAR, tick * (WorldShadows.BIND_EVERY + 0.1))
		local remain = math.max(0, 250 - 100 * tick)
		check(#sh.entries == remain and #sh.ignored == remain, "one tick releases at most each independent budget: " .. tick)
		check(sh.holders[1].count == remain * 2, "holder count matches both remaining populations: " .. tick)
	end
	check(sh.writes == writes and next(sh.holders[1].bound) == nil, "cleanup writes no dead-part properties and leaves no keys")
	root:Destroy()
end)

case("release belongs to the original holder when a part moves between region folders", function()
	WorldMap.use("test_garden")
	local a, b = assert(WorldMap.region("outer_sill")), assert(WorldMap.region("house_wall"))
	for _, kinds in { { "visible", "visible" }, { "hidden", "visible" }, { "visible", "off" }, { "off", "hidden_lit" } } do
	local root = Instance.new("Folder")
	local fa = Instance.new("Folder"); fa.Name = Region.folderName(a); fa.Parent = root
	local fb = Instance.new("Folder"); fb.Name = Region.folderName(b); fb.Parent = root
	-- New holder first: searching all holders would release its binding by mistake.
	local sh = WorldShadows.new(root, { regions = function() return { b, a } end }, nil)
	local p = streamPart(fa, "moving", kinds[1])
	sh:update(STREAM_FAR, 0)
	p.Parent = fb
	p.Transparency = if kinds[2] == "hidden_lit" then 1 else 0
	p.CastShadow = kinds[2] ~= "off"
	sh:bind()
	check(sh.holders[1].bound[p] and sh.holders[2].bound[p], "both generation bindings exist before the cleanup tick")
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
	check(sh.holders[2].bound[p] == nil and sh.holders[2].count == 0, "obsolete owner released")
	check(sh.holders[1].bound[p] and sh.holders[1].count == 1 and #sh.entries + #sh.ignored == 1, "new owner and its single tracked entry survive")
	check(sh:counts() == (if kinds[2] == "visible" then 1 else 0), "new owner's eligibility is preserved")
	root:Destroy()
	end
end)

case("home-region exclusion also excludes ignored tracking", function()
	local root, region = streamFixture()
	local f, parts = streamBatch(root, region, "visible")
	local sh = WorldShadows.new(root, { regions = function() return { region } end }, region.id)
	sh:update(STREAM_FAR, 0)
	check(#sh.holders == 0 and #sh.entries == 0 and #sh.ignored == 0, "home retains no shadow-manager bindings")
	local untouched = true; for _, p in parts do if not p.CastShadow then untouched = false end end
	check(untouched, "home parts retain their authored flags")
	f:Destroy(); root:Destroy()
end)

print(`SHADOWS passed={passed} failed={failed}`)
if failed > 0 then error("SHADOWS failed") end
