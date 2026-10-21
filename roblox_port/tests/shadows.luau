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

print(`SHADOWS passed={passed} failed={failed}`)
if failed > 0 then error("SHADOWS failed") end
