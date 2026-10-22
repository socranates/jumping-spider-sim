-- Diagnostic only: real Instance lifecycle on the exact guarded game module.
-- Cases mirror the new CLI regression; not a network streaming or FPS test.
local Run=game:GetService("RunService")
local WorldShadows=require(script.Parent.WorldShadows)
local Shared=game:GetService("ReplicatedStorage").Shared
local WorldMap=require(Shared.World.WorldMap)
local Region=require(Shared.World.Region)
return function(_d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("ShadowCleanupProbe")==true)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local checks,cases=0,0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function case(name,fn) fn();cases+=1;print("[SHADOW_CLEANUP_CASE]",run,cases,checks,name) end
 local ok,problem=pcall(function()
 task.wait(5)
-- Small real-region fixtures isolate lifecycle behavior without rebuilding the
-- preserve. Old Instance keys are retained by the test solely to inspect whether
-- the manager released them; this is not a GC or frame-rate measurement.
local function streamFixture()
	assert(WorldMap.world()=="preserve", "native fixture must not change the active map")
	local region = assert(WorldMap.region("hut_desk"))
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
	assert(WorldMap.world()=="preserve", "native fixture must not change the active map")
	local a, b = assert(WorldMap.region("hut_desk")), assert(WorldMap.region("hut_doorway"))
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


 assert(cases==7,"native regression cases missing")
 end)
 if ok then print("[SHADOW_CLEANUP_DONE]",run,cases,checks) else warn("[SHADOW_CLEANUP_FAIL]",run,tostring(problem)) end
 workspace:SetAttribute("ShadowCleanupFinished",true);workspace:SetAttribute("ShadowCleanupPassed",ok)
end
