local awaitRest=require("./studio/AwaitRest")
local awaitReturn=require("./studio/AwaitReturn")
-- The client's world (ROBLOX-94, Client/WorldClient): where the boxes are (the server's World folder, or a sill straight in the workspace as the box worlds have it), which region
-- the spider is in and the pace of its day, the streaming focus, and what the sim does about instance streaming; then the real client on the folders the server really builds
-- (Shared/World/WorldBuild, with the drawn sill beside them): the spider stands and walks, its rays include the World folder and nothing else, the rival and the flies find their
-- boxes, the focus follows the drawn spider, and a rest from another revision of the world is put back at the sill's spawn. A smoke test of wiring on the shim's box world:
-- not evidence of streaming (the engine decides what is sent), of rendering or of the engine's physics.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local WorldClient = require("../src/Client/WorldClient")
local LifeClock = require("../src/Shared/Life/LifeClock")
local Json = require("../src/Shared/Persistence/Json")
local Species = require("../src/Shared/Data/Species")

local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL world_client: " .. name .. "\n    " .. tostring(err)) end
end

-- ---------------------------------------------------------------- stand-ins
local sill = WorldMap.region("sill") :: WorldMap.Region
-- An invented second region beside the sill, for the questions the sill alone cannot answer: its west face is the sill's east face (x = 33), and its day runs at a quarter.
local garden: WorldMap.Region = {
	id = "garden", kind = "bed", origin = Vector3.new(66, 0, 0),
	bounds = { Vector3.new(33, -5, -16), Vector3.new(99, 35, 16) },
	seed = WorldMap.seed(914, "garden"), neighbors = {},
	retreats = { { id = "garden_hollow", min = Vector3.new(50, 0, 0), max = Vector3.new(52, 1, 2) } },
	spawn = { pos = Vector3.new(40, 0, 0), heading = Vector3.new(1, 0, 0) },
	clockScale = 0.25,
}
local function within(lo: Vector3, hi: Vector3, p: Vector3): boolean
	return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
end
-- A map with the same functions as WorldMap's, over the regions given (the first listed wins a shared face).
local function mapOf(list: { WorldMap.Region }): any
	local lo, hi = WorldMap.unionOf(list)
	return {
		HOME = "sill",
		region = function(id: string): WorldMap.Region?
			for _, r in list do if r.id == id then return r end end
			return nil
		end,
		bounds = function(): (Vector3, Vector3) return lo, hi end,
		at = function(pos: Vector3): WorldMap.Region?
			for _, r in list do if within(r.bounds[1], r.bounds[2], pos) then return r end end
			return nil
		end,
		inRetreat = function(pos: Vector3): string?
			for _, r in list do
				for _, t in r.retreats do if within(t.min, t.max, pos) then return t.id end end
			end
			return nil
		end,
	}
end
-- The old places: the sill straight in the workspace, as the box worlds of the other client tests have it.
local function flatWorld(): Instance
	local pieces = {}
	for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
	return BoxWorld.folder("Windowsill", pieces)
end
-- What the server builds: the World folder with a folder for each region.
local function serverWorld(): Instance
	return WorldBuild.world(workspace)
end
local function player(): any
	return Instance.new("Player")
end
-- Runs `fn` with `warn` collecting its messages (the plain Luau CLI has none; the engine always does); the messages, in order.
local function warnings(fn: () -> ()): { string }
	local seen: { string } = {}
	local before = warn
	warn = function(message: string) table.insert(seen, message) end
	local ok, err = pcall(fn)
	warn = before
	if not ok then error(err, 0) end
	return seen
end

-- ---------------------------------------------------------------- where the boxes are
check("a sill straight in the workspace (the box worlds, the old places) is both the root of every ray and the sill", function()
	workspace:ClearAllChildren()
	local flat = flatWorld()
	local c = WorldClient.new(workspace, player())
	assert(c.root == flat and c.sill == flat, "the folder is the root and the sill")
	assert(c.decor == nil, "no drawn sill here")
	assert(c.home == "sill" and c.region == sill, "the sill is the home region and the region the spider begins in")
	local lo, hi = WorldMap.bounds()
	assert(c.boundsMin == lo and c.boundsMax == hi, "the map's bounds")
	assert(c.spawnPos == Layout.SPAWN and c.spawnHeading == Layout.SPAWN_HEADING, "the layout's own spawn and heading")
	workspace:ClearAllChildren()
end)

check("the server's World folder is found: its Windowsill is the sill, World is the root of every ray, the Decor beside it is the decor", function()
	workspace:ClearAllChildren()
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.Parent = workspace
	local world = serverWorld()
	local c = WorldClient.new(workspace, player())
	assert(world.Name == "World" and world.Parent == workspace and c.root == world, "the root is the World folder in the workspace")
	assert(c.sill.Name == "Windowsill" and c.sill.Parent == world and c.sill ~= world, "the sill is the region's folder inside it")
	assert(#c.sill:GetChildren() == #Layout.PIECES, "all of the sill's boxes")
	for _, spec in Layout.PIECES do
		local p = c.sill:FindFirstChild(spec.id)
		assert(p ~= nil and p:IsDescendantOf(c.root), `{spec.id} is a box of the root`)
	end
	assert(c.decor == decor, "the drawn sill")
	assert(c.home == "sill" and c.region == sill and c.spawnPos == Layout.SPAWN and c.spawnHeading == Layout.SPAWN_HEADING, "the same map answers")
	workspace:ClearAllChildren()
end)

check("the same rays hit the same boxes at the same places whether the sill stands in the workspace or inside the World folder", function()
	local function rays(root: Instance): { { text: string, name: string, dist: number } }
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { root }
		local state = 914
		local function rnd(): number
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end
		local out = {}
		for _ = 1, 400 do
			local origin = Vector3.new(-33 + 66 * rnd(), -2 + 30 * rnd(), -16 + 32 * rnd())
			local direction = Vector3.new(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).Unit * 40
			local hit = workspace:Raycast(origin, direction, params)
			table.insert(out, if hit then { text = string.format("%s %.6f %.6f %.6f n(%d,%d,%d)", hit.Instance.Name, hit.Position.X, hit.Position.Y, hit.Position.Z, hit.Normal.X, hit.Normal.Y, hit.Normal.Z),
				name = hit.Instance.Name, dist = (hit.Position - origin).Magnitude } else { text = "-", name = "", dist = math.huge })
		end
		return out
	end
	workspace:ClearAllChildren()
	local a = rays(flatWorld())
	workspace:ClearAllChildren()
	local b = rays(serverWorld())
	local sillIds: { [string]: boolean } = {}
	for _, p in Layout.PIECES do sillIds[p.id] = true end
	local hits, outside = 0, 0
	for i = 1, #a do
		-- (ROBLOX-95: World holds the regions outside the window too. A ray that leaves the sill may meet one of their boxes first, where the sill alone has nothing
		-- nearer; every ray that ends on a box of the sill ends exactly where it always did.)
		if b[i].name ~= "" and not sillIds[b[i].name] then
			outside += 1
			assert(a[i].dist > b[i].dist, `ray {i}: {a[i].text} in the workspace, {b[i].text} in the World folder`)
		else
			assert(a[i].text == b[i].text, `ray {i}: {a[i].text} in the workspace, {b[i].text} in the World folder`)
		end
		if a[i].text ~= "-" then hits += 1 end
	end
	assert(hits >= 100, `the rays hit something often enough to mean something ({hits} of {#a})`)
	-- (ROBLOX-112: the window's glass above the back frame, its reveal, the room's wall beside it and the counter in front of the sill are other regions' boxes now, all
	-- round the sill: 124 of the 400 rays meet one of them first, under 80 before)
	assert(outside > 0 and outside < 160, `some rays from the sill reach the world round it, most do not ({outside})`)
	workspace:ClearAllChildren()
end)

-- ---------------------------------------------------------------- the region the spider is in, and the pace of its day
check("the region the spider is in sets the pace of its day, each frame; between regions it keeps the last; a shared face is the first region's", function()
	workspace:ClearAllChildren()
	serverWorld()
	local c = WorldClient.new(workspace, player(), mapOf({ sill, garden }))
	local ok, err = pcall(function()
		assert(c.region == sill and LifeClock.game.clockScale == 1.0, "begins in the sill")
		c:update(Vector3.new(-22, 0.31, 6), nil)
		assert(c.region == sill and LifeClock.game.clockScale == 1.0 and c:isActive("sill") and not c:isActive("garden"), "in the sill: a day as brisk as the sill's")
		c:update(Vector3.new(60, 0.31, 0), nil)
		assert(c.region == garden and LifeClock.game.clockScale == 0.25 and c:isActive("garden") and not c:isActive("sill"), "in the garden: a quarter")
		assert(LifeClock.currentScale() == 0.25, "and LifeClock runs at it")
		c:update(Vector3.new(400, 0.31, 0), nil)
		assert(c.region == garden and LifeClock.game.clockScale == 0.25, "in no region at all (a frame on the way back from outside the bounds): the last one's pace")
		assert(c:regionAt(Vector3.new(400, 0, 0)) == garden and c:regionAt(Vector3.new(-22, 0.31, 6)) == sill and c:regionAt(Vector3.new(60, 0.31, 0)) == garden, "regionAt asks without moving anything")
		c:update(Vector3.new(33, 0.31, 0), nil)
		assert(c.region == sill and LifeClock.game.clockScale == 1.0, "on the face the two share: the first region listed")
		c:update(Vector3.new(33.001, 0.31, 0), nil)
		assert(c.region == garden and LifeClock.game.clockScale == 0.25, "and a hair past it, the next")
	end)
	LifeClock.game.clockScale = 1.0
	assert(ok, tostring(err))
	workspace:ClearAllChildren()
end)

check("a retreat is a retreat in any region, and with the real map the layout's own answer", function()
	workspace:ClearAllChildren()
	serverWorld()
	local two = WorldClient.new(workspace, player(), mapOf({ sill, garden }))
	assert(two:inRetreat(Vector3.new(-25, 0.5, 6)) == "sill_crevice" and two:inRetreat(Vector3.new(51, 0.5, 1)) == "garden_hollow" and two:inRetreat(Vector3.new(0, 0.5, 0)) == nil, "the crack and the hollow")
	local real = WorldClient.new(workspace, player())
	local state = 99
	local function rnd(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	local inside = 0
	for _ = 1, 3000 do
		local p = Vector3.new(-30 + 12 * rnd(), -1 + 4 * rnd(), 1 + 10 * rnd())
		local answer = real:inRetreat(p)
		assert((answer ~= nil) == Layout.inRetreat(p), `{p.X}, {p.Y}, {p.Z}: the map says {tostring(answer)}, the layout {tostring(Layout.inRetreat(p))}`)
		if answer ~= nil then inside += 1 end
	end
	assert(inside > 50, `a share of the points are inside ({inside})`)
	workspace:ClearAllChildren()
end)

-- ---------------------------------------------------------------- the streaming focus
check("the focus follows the drawn spider: set when its rig is first seen, again after a refocus or a new rig, and never let go for want of one", function()
	workspace:ClearAllChildren()
	serverWorld()
	local p = player()
	local c = WorldClient.new(workspace, p)
	local a, b = Instance.new("Part"), Instance.new("Part")
	local here = Vector3.new(-22, 0.31, 6)
	c:update(here, nil)
	assert(p.ReplicationFocus == nil and c.focused == nil, "no rig yet: nothing to focus on")
	c:update(here, a)
	assert(p.ReplicationFocus == a and c.focused == a, "the rig's root is the focus")
	p.ReplicationFocus = nil
	c:update(here, a)
	assert(p.ReplicationFocus == nil, "a steady frame does not write it again")
	c:refocus()
	c:update(here, a)
	assert(p.ReplicationFocus == a, "after a respawn or a return to a rest it is set again at the next frame")
	c:update(here, b)
	assert(p.ReplicationFocus == b and c.focused == b, "a new rig (a changed spider, a new life) takes it")
	c:update(here, nil)
	assert(p.ReplicationFocus == b, "a frame with no rig is not a reason to let go")
	workspace:ClearAllChildren()
end)

check("a refused write of the focus is warned about once and the game goes on", function()
	workspace:ClearAllChildren()
	serverWorld()
	local refusing = setmetatable({}, { __newindex = function() error("The current thread cannot write 'ReplicationFocus' (lacking capability Plugin)") end })
	local c = WorldClient.new(workspace, refusing :: any)
	local part = Instance.new("Part")
	local seen = warnings(function()
		c:update(Vector3.new(-22, 0.31, 6), part)
		c:refocus()
		c:update(Vector3.new(-22, 0.31, 6), part)
		c:focus(Instance.new("Part"))
	end)
	assert(#seen == 1, `warned {#seen} times`)
	assert(string.find(seen[1], "replication focus", 1, true) ~= nil and string.find(seen[1], "lacking capability", 1, true) ~= nil, seen[1])
	assert(c.focusWarned and c.focused ~= nil, "it is remembered as tried, so the frames are not spent trying")
	workspace:ClearAllChildren()
end)

-- ---------------------------------------------------------------- ROBLOX-95: the regions outside, whole or not, the focus report, the world's bounds
check("a region is ready when its folder holds every one of its boxes; a place with only the sill has only the sill", function()
	workspace:ClearAllChildren()
	local world = serverWorld()
	local c = WorldClient.new(workspace, player())
	for _, r in WorldMap.regions() do
		assert(c:regionReady(r.id), `{r.id} is whole as the server builds it`)
	end
	assert(not c:regionReady("garden") and not c:regionReady(""), "a region that is not on the map is never ready")
	local bed = world:FindFirstChild("bed_a") :: Instance
	local stone = bed:FindFirstChild("bed_a_stone_top") :: Instance
	stone.Parent = nil
	assert(not c:regionReady("bed_a") and c:regionReady("house_wall"), "one box of the bed missing: the bed is not ready, the wall still is")
	stone.Parent = bed
	assert(c:regionReady("bed_a"), "and it is again when the box arrives")
	local folder = world:FindFirstChild("outer_sill") :: Instance
	folder.Parent = nil
	assert(not c:regionReady("outer_sill"), "a region whose folder has not arrived is not ready")
	workspace:ClearAllChildren()
	flatWorld()
	local flat = WorldClient.new(workspace, player())
	assert(flat:regionReady("sill") and not flat:regionReady("bed_a"), "in a sill-only place the sill is ready and nothing else")
	workspace:ClearAllChildren()
end)

check("world updates stay nonblocking and warn once for incomplete collision", function()
	workspace:ClearAllChildren()
	local world = serverWorld()
	local c = WorldClient.new(workspace, player())
	local bed = world:FindFirstChild("bed_a") :: Instance
	local mound = bed:FindFirstChild("bed_a_mound_3") :: Instance
	mound.Parent = nil
	local inBed, onSill, onWall = Vector3.new(0, -89.69, -50), Vector3.new(-22, 0.31, 6), Vector3.new(0, -40, -24.31)
	local seen = warnings(function()
		c:update(onSill, nil, 10)
		c:update(inBed, nil, 11)
		c:update(inBed, nil, 12)
		c:update(onWall, nil, 13)
		c:update(inBed, nil, 14)
	end)
	assert(#seen == 1 and string.find(seen[1], "bed_a", 1, true) ~= nil and string.find(seen[1], "not arrived whole", 1, true) ~= nil, `warned {#seen} times: {seen[1]}`)
	assert(c.region.id == "bed_a" and c.whole.sill and c.whole.house_wall and not c.whole.bed_a, "the regions found whole are remembered; the bed is not one of them")
	mound.Parent = bed
	local after = warnings(function() c:update(inBed, nil, 15) end)
	assert(#after == 0 and c.whole.bed_a, "when the box arrives the bed is whole, and nothing more is said")
	-- and without warn at all (the plain CLI), nothing breaks
	mound.Parent = nil
	local fresh = WorldClient.new(workspace, player())
	fresh:update(inBed, nil, 1)
	assert(fresh.warned.bed_a, "the CLI has no warn, and the client goes on")
	workspace:ClearAllChildren()
end)

check("the focus is reported when the spider has moved more than 8 studs from the last report or 2 seconds have passed, and not otherwise", function()
	workspace:ClearAllChildren()
	serverWorld()
	local storage = game:GetService("ReplicatedStorage")
	local had = storage:FindFirstChild("WorldFocus")
	if had then had.Parent = nil end
	local c = WorldClient.new(workspace, player())
	assert(not c:report(Vector3.new(0, 0.31, 0), 0) and c.reports == 0, "without the server's remote nothing is sent")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "WorldFocus"
	remote.Parent = storage
	local function sent(): number return #(rawget(remote, "fired") or {}) end
	local p0 = Vector3.new(0, 0.31, 0)
	assert(c:report(p0, 1.0) and sent() == 1 and rawget(remote, "fired")[1][1] == p0, "the first report goes at once, with the spider's place")
	assert(not c:report(p0 + Vector3.new(7.9, 0, 0), 1.5) and sent() == 1, "7.9 studs on, half a second later: nothing")
	assert(c:report(p0 + Vector3.new(8.1, 0, 0), 1.6) and sent() == 2, "8.1 studs on: reported")
	assert(not c:report(p0 + Vector3.new(8.1, 0, 0), 3.5) and c:report(p0 + Vector3.new(8.1, 0, 0), 3.6) and sent() == 3, "standing still: again after 2 seconds")
	assert(not c:report(p0 + Vector3.new(8.1, -0.5, 0), 3.7) and sent() == 3, "and not before")
	-- update reports too, on os.clock unless given a clock
	c:update(Vector3.new(0, -40, -24.31), nil, 3.8)
	assert(sent() == 4 and c.reported == Vector3.new(0, -40, -24.31), "update sends the report when it is due")
	remote.Parent = nil
	if had then had.Parent = storage end
	workspace:ClearAllChildren()
end)

check("the world's bounds: out of it is in no region, so a fall from the sill's room side lands on the counter and one from the outer sill goes on to the bed", function()
	workspace:ClearAllChildren()
	serverWorld()
	local c = WorldClient.new(workspace, player())
	-- (ROBLOX-112: in front of the sill is the kitchen's counter, 4 cm down: a fall off the sill's front edge lands on its worktop; under the sill board is the wall)
	assert(c:inBounds(Vector3.new(0, -4.9, 12.4)) and c:inBounds(Vector3.new(0, -5.1, 12.4)) and c:inBounds(Vector3.new(0, -3.69, 40)) and not c:inBounds(Vector3.new(0, -5.1, 0)),
		"in front of the sill (the room's side) the counter's air goes on down; under the sill board, nothing")
	assert(c:inBounds(Vector3.new(0, -50, -27)) and c:inBounds(Vector3.new(0, -89.69, -40)) and not c:inBounds(Vector3.new(0, -93.5, -40)), "out over the stone it goes on down past the wall to the bed")
	assert(not c:inBounds(Vector3.new(60, -50, -40)) and c.homeMin == sill.bounds[1] and c.homeMax == sill.bounds[2], "beside the garden, nothing; the rival's and the mate's bounds are the sill's")
	local lo, hi = WorldMap.bounds()
	assert(c.boundsMin == lo and c.boundsMax == hi and lo.Y == -93, "the motor's box is the union, down to just under the bed's soil")
	workspace:ClearAllChildren()
end)

-- ---------------------------------------------------------------- instance streaming: the sim begins on a whole sill
-- The late boxes come when the client asks for them (WaitForChild), as streaming brings them; `never` leaves them out for good.
local function streamed(never: boolean, streaming: boolean?): any
	workspace:ClearAllChildren()
 local named=workspace:GetAttribute("World")
 workspace:SetAttribute("World",WorldMap.world())
	local world = serverWorld()
	local sillFolder = world:FindFirstChild("Windowsill") :: Instance
	local late = { Layout.PIECES[1].id, Layout.PIECES[12].id, Layout.PIECES[#Layout.PIECES].id }
	local held: { [string]: Instance } = {}
	for _, id in late do
		local piece = sillFolder:FindFirstChild(id) :: Instance
		held[id] = piece
		piece.Parent = nil
	end
	local askedSill: { { name: string, timeout: number } } = {}
	rawset(sillFolder, "WaitForChild", function(self: Instance, name: string, timeout: number?): Instance?
		table.insert(askedSill, { name = name, timeout = timeout or 0 })
		local piece = held[name]
		if piece ~= nil and not never then piece.Parent = self; held[name] = nil end
		return self:FindFirstChild(name)
	end)
	local askedWorkspace: { string } = {}
	rawset(workspace, "WaitForChild", function(self: Instance, name: string, timeout: number?): Instance?
		table.insert(askedWorkspace, name)
		local found = self:FindFirstChild(name)
		if found == nil and name == "Decor" and not never then
			local decor = Instance.new("Model")
			decor.Name = "Decor"
			decor.Parent = self
			found = decor
		end
		return found
	end)
	workspace.StreamingEnabled = streaming ~= false
 local client,problem=nil,nil
 local p=player()
 local seen=warnings(function()
  local ok,err=pcall(function() client=WorldClient.new(workspace,p) end)
  if not ok then problem=tostring(err) end
 end)
	workspace.StreamingEnabled = nil
	rawset(workspace, "WaitForChild", nil)
	workspace:SetAttribute("World",named)
 return askedSill, askedWorkspace, client, seen, problem, p
end

check("with instance streaming on, the client waits for every box of the sill that is not there yet, and for the Decor, before the sim begins", function()
	local askedSill, askedWorkspace, c, seen = streamed(false)
	local late = { Layout.PIECES[1].id, Layout.PIECES[12].id, Layout.PIECES[#Layout.PIECES].id }
	assert(#askedSill == #late, `asked the sill for {#askedSill} boxes`)
	for i, id in late do
		assert(askedSill[i].name == id, `box {i}: asked for {askedSill[i].name}, not {id}`)
		assert(askedSill[i].timeout > 0 and askedSill[i].timeout <= WorldClient.PIECES_WAIT, `{id}: a wait of {askedSill[i].timeout} seconds`)
		assert(c.sill:FindFirstChild(id) ~= nil, `{id} has arrived`)
	end
	assert(#c.sill:GetChildren() == #Layout.PIECES, "the sill is whole")
	assert(table.find(askedWorkspace, "Decor") ~= nil and c.decor ~= nil and c.decor.Name == "Decor", "the drawn sill was waited for and is there")
	assert(#seen == 0, "nothing to say when everything came")
	workspace:ClearAllChildren()
end)

check("missing streamed home collision aborts startup instead of admitting a partial world",function()
 local asked,_,c,_,problem,p=streamed(true)
 assert(c==nil and problem~=nil,"a partially collidable home must not reach the controller")
 assert(#asked==1 and asked[1].timeout>0 and asked[1].timeout<=WorldClient.PIECES_WAIT,"one bounded essential wait, not per-piece extended budgets")
 assert(string.find(problem,Layout.PIECES[1].id,1,true),"diagnostic identifies the missing collision piece")
 assert(p:GetAttribute("WorldStartupFailed")==true,"loading screen receives failure")
 workspace:ClearAllChildren()
end)
check("server-layout home collision is required even without instance streaming",function()
 local _,_,c,_,problem,p=streamed(true,false)
 assert(c==nil and problem and p:GetAttribute("WorldStartupFailed")==true,"non-streaming server layout cannot silently admit a missing surface")
 workspace:ClearAllChildren()
end)
check("legacy flat box-world fixtures remain immediate without streaming",function()
 workspace:ClearAllChildren();local root=flatWorld();local p=player()
 local missing=root:FindFirstChild(Layout.PIECES[1].id);missing.Parent=nil
 local waits=0
 rawset(root,"WaitForChild",function(self,name) waits+=1;return self:FindFirstChild(name) end)
 workspace.StreamingEnabled=false
 local c=WorldClient.new(workspace,p)
 workspace.StreamingEnabled=nil
 assert(c.root==root and waits==0,"explicit legacy flat fixture remains compatible")
 workspace:ClearAllChildren()
end)
check("missing World and home folders have bounded waits and publish startup failure",function()
 for _,missingHome in {false,true} do
  local ws=Instance.new("Folder");ws.Name="FixtureWorkspace"
  local parent=ws
  if missingHome then parent=Instance.new("Folder");parent.Name="World";parent.Parent=ws end
  local timeout=nil
  rawset(parent,"WaitForChild",function(_,_,seconds) timeout=seconds;return nil end)
  local p=player();local c=nil
  local ok,err=pcall(function() c=WorldClient.new(ws,p,mapOf({sill})) end)
  assert(not ok and c==nil and p:GetAttribute("WorldStartupFailed")==true,"missing essentials fail explicitly")
  assert(timeout and timeout>0 and timeout<=WorldClient.PIECES_WAIT,"essential folder wait has a deadline")
  assert(string.find(tostring(err),if missingHome then "Windowsill" else "World",1,true),"diagnostic names the missing folder")
  ws:Destroy()
 end
end)
check("streaming never guesses a default map when the server identity is missing or unknown",function()
 for _,named in {false,"not_a_world"} do
  local ws=Instance.new("Folder");ws.StreamingEnabled=true;ws:SetAttribute("World",if named==false then nil else named)
  local p=player();local before=WorldMap.world();local c=nil
  local ok=pcall(function() c=WorldClient.new(ws,p) end)
  local unchanged=WorldMap.world()==before
  WorldMap.use(before);ws:Destroy() -- isolate even a failing predecessor from later cases
  assert(not ok and c==nil and p:GetAttribute("WorldStartupFailed")==true,"unknown replicated identity is not a playable default")
  assert(unchanged,"failure does not switch the active map")
 end
end)

-- ---------------------------------------------------------------- the real client on the folders the server builds
-- (The drawn sill itself is left out, as it is in the other client tests: its thousand parts would be scanned by every ray of the shim. A bare Decor stands for it.)
workspace:ClearAllChildren()
local decorModel = Instance.new("Model")
decorModel.Name = "Decor"
decorModel.Parent = workspace
local serverFolder = WorldBuild.world(workspace, WorldMap.SEED)
-- (ROBLOX-95: the remote the server makes for the focus reports, Server/WorldFocus.listen; the shim's RemoteEvent keeps what is fired on it)
local focusRemote = Instance.new("RemoteEvent")
focusRemote.Name = "WorldFocus"
focusRemote.Parent = game:GetService("ReplicatedStorage")
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function settleRest()
 local d=ClientStubs.driver
 if d.life.checkpointResult then awaitRest(d.life.checkpointResult,function() frame(0) end) end
 frame(0)
end
local KEYS = { Feed = "E", Forward = "W", Reset = "Backspace", Drop = "F" }
local function key(action: string, down: boolean)
	local fn = ClientStubs.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local localPlayer: any = game:GetService("Players").LocalPlayer
local function drawnRoot(): Instance
	return (workspace:FindFirstChild("Spider") :: Instance):FindFirstChild("Root") :: Instance
end

check("the client loads on the World folder, runs 120 frames, and the spider stands on the sill", function()
	assert(loaded, "SpiderClient did not load: " .. tostring(loadError))
	assert(frame ~= nil, "no render step bound")
	frames(120)
	local at = drawnRoot().Position
	assert(math.abs(at.Y - 0.31) < 0.05, `the spider is at {at} (not standing on the sill)`)
	assert(ClientStubs.driver ~= nil and ClientStubs.driver.world ~= nil, "the test-place driver is handed the world")
end)

check("the sim's world is the server's: its sill is Windowsill inside World, and the motor's rays include World", function()
	local driver = ClientStubs.driver
	local world = driver.world
	assert(world.root == serverFolder and world.root.Name == "World" and world.root.Parent == workspace, "the root is the server's World folder")
	assert(world.sill == driver.sill and driver.sill.Name == "Windowsill" and driver.sill.Parent == world.root, "the sill the client works with is region 0's folder")
	assert(world.decor == decorModel, "the drawn sill is the Decor beside it")
	local filter = driver.motor.params.FilterDescendantsInstances
	assert(#filter == 1 and filter[1] == world.root and driver.motor.config.world == world.root, "the motor's rays include the World folder, and only that")
	assert(#driver.motor.overlap.FilterDescendantsInstances == 1 and driver.motor.overlap.FilterDescendantsInstances[1] == world.root, "and its overlap queries")
	local lo, hi = WorldMap.bounds()
	assert(driver.motor.config.boundsMin == lo and driver.motor.config.boundsMax == hi, "its fall-off box is the map's")
	local inside = driver.motor.config.inBounds
	assert(inside ~= nil, "the motor has no inBounds")
	assert(inside(Vector3.new(0, -50, -27)) and not inside(Vector3.new(0, -6, 10)),
		"and out of it is where no region holds the spider (ROBLOX-95)")
	assert(driver.motor.config.spawn == sill.spawn.pos and driver.motor.config.heading == sill.spawn.heading, "it begins where the sill's life begins")
	assert(#driver.prey.flies >= 1, "the flies found their perches among the boxes of World")
end)

check("W walks the spider along the sill, standing on the floor all the way", function()
	local p0 = drawnRoot().Position
	local lowest, highest = p0.Y, p0.Y
	key("Forward", true)
	for _ = 1, 60 do
		frames(1)
		local y = drawnRoot().Position.Y
		lowest, highest = math.min(lowest, y), math.max(highest, y)
	end
	key("Forward", false)
	frames(2)
	assert((drawnRoot().Position - p0).Magnitude > 1.5, `moved {(drawnRoot().Position - p0).Magnitude}`)
	assert(lowest > 0.2 and highest < 0.45, `off the floor: between {lowest} and {highest}`)
end)

check("the drawn spider's root is the replication focus, set again after a return to the start and after a new life", function()
	local driver = ClientStubs.driver
	assert(localPlayer.ReplicationFocus == drawnRoot(), "the focus is on the drawn spider")
	localPlayer.ReplicationFocus = nil
	frames(3)
	assert(localPlayer.ReplicationFocus == nil, "a steady frame does not write it again")
	key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end); frames(2) -- (no last rest yet: back to the start)
	assert(localPlayer.ReplicationFocus == drawnRoot(), "after Backspace it is set again")
	localPlayer.ReplicationFocus = nil
	assert(driver.fresh("main", false, nil), "a new life begins")
	frames(2)
	assert(localPlayer.ReplicationFocus == drawnRoot(), "and after a new life")
	frames(170) -- (the toast of the return to the start is kept its 2.6 seconds, ROBLOX-92)
end)

check("a region's clock scale is the pace of the day through the real client, and the dial is back on 1.0 in the sill", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local function hoursOver(n: number): number
		local before = (life.clock.day - 1) * 24 + life.clock.hour
		frames(n)
		return (life.clock.day - 1) * 24 + life.clock.hour - before
	end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(30)
	life.clock.hour = 9
	assert(LifeClock.game.clockScale == 1.0, "the sill's pace")
	local brisk = hoursOver(300)
	assert(brisk > 0.05 and brisk < 0.1, `the sill's day over five seconds: {brisk} hours`)
	local real = driver.world.map
	local slow = table.clone(sill)
	slow.clockScale = 0.25
	driver.world.map = mapOf({ slow })
	local ok, err = pcall(function()
		frames(2)
		assert(LifeClock.game.clockScale == 0.25, "the region's pace is on the dial")
		local quarter = hoursOver(300)
		assert(math.abs(quarter / brisk - 0.25) < 0.01, `a quarter of the day passes in the same time ({quarter} against {brisk} hours)`)
	end)
	driver.world.map = real
	frames(2)
	LifeClock.game.clockScale = 1.0
	assert(ok, tostring(err))
	assert(LifeClock.game.clockScale == 1.0 and driver.world.region == sill, "back in the sill")
end)

check("a rest from another revision of the world is put back at the sill's spawn, with the reason; the same revision puts the spider back in the crack", function()
	local driver = ClientStubs.driver
	local life = driver.life
	-- A rest in the crack keeps a checkpoint.
	driver.place(Vector3.new(-25.5, 0.31, 6.0))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2); settleRest()
	assert(life.resting, "no rest: " .. tostring(life.notice))
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.region == "sill" and best.record.world_map.retreat == "sill_crevice" and best.record.world_map.revision == WorldMap.REVISION, "the rest carries the world it was in")
	-- Walk away, and come back: the same world puts the spider back in the crack.
	key("Forward", true); frames(90); key("Forward", false); frames(30)
	key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end); frames(2)
	assert(driver.lifeSpider().inRetreat and life.resting, "not back resting in the crack")
	-- The same rest, kept by another revision of the world: the world has changed since, so the spider stands where a life begins.
	local other = Json.copy(best.record)
	other.world_map.revision = "world-0"
	local saved = driver.currentStore():save(other)
	assert(saved.ok, "the old revision's rest was not kept: " .. tostring(saved.message))
	key("Forward", true); frames(90); key("Forward", false); frames(30)
	key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end); frames(2)
	local at = drawnRoot().Position
	assert((at - (sill.spawn.pos + Vector3.new(0, 0.31, 0))).Magnitude < 0.5, `at {at}, not at the sill's spawn {sill.spawn.pos}`)
	assert(not driver.lifeSpider().inRetreat, "put back in the crack of a world that has changed")
	assert(string.find(life.notice, "the world has changed", 1, true) ~= nil, "the reason: " .. tostring(life.notice))
	assert(localPlayer.ReplicationFocus == drawnRoot(), "the focus follows the spider to where it stands")
end)

-- ---------------------------------------------------------------- ROBLOX-95: out through the raised sash and down to the bed, through the real client
check("the real client walks out through the raised sash onto the outer sill, over its edge and down the brick to the bed: the region and the dial follow, the focus is reported", function()
	local driver = ClientStubs.driver
	local motor = driver.motor
	local fired = function(): { any } return rawget(focusRemote, "fired") or {} end
	local before = #fired()
	driver.place(Vector3.new(0, 0.31, -9))
	motor:place(Vector3.new(0, 0.31, -9), Vector3.yAxis, Vector3.new(0, 0, -1))
	driver.camera:snap()
	frames(5)
	local seen: { string } = {}
	local scales: { [string]: number } = {}
	local function note()
		local id = driver.world.region.id
		if seen[#seen] ~= id then table.insert(seen, id) end
		scales[id] = LifeClock.game.clockScale
	end
	key("Forward", true)
	for _ = 1, 60 * 90 do
		frames(1)
		note()
		if driver.world.region.id == "bed_a" and motor.mode == "attached" and motor.up.Y > 0.9 then break end
	end
	key("Forward", false)
	frames(2)
	print(`world_client: walked through {table.concat(seen, " > ")}, now at {motor.pos}, mode {motor.mode}`)
	assert(seen[1] == "sill" and table.find(seen, "outer_sill") ~= nil and table.find(seen, "house_wall") ~= nil and seen[#seen] == "bed_a", `the regions in order: {table.concat(seen, " > ")}`)
	assert((table.find(seen, "outer_sill") :: number) < (table.find(seen, "house_wall") :: number), "out over the stone before down the wall")
	assert(math.abs(motor.pos.Y - (-90 + 0.31)) < 0.1 and motor.up.Y > 0.9, `standing on the bed's soil ({motor.pos})`)
	assert(scales.sill == 1.0 and scales.outer_sill == 1.0 and scales.house_wall == 1.0 and scales.bed_a == 0.33 and LifeClock.game.clockScale == 0.33, "the dial: the sill's pace to the foot of the wall, a third of it in the bed")
	local reports = fired()
	assert(#reports - before >= 10, `the focus was reported on the way ({#reports - before} reports for about 100 studs)`)
	local last = reports[#reports][1]
	assert(typeof(last) == "Vector3" or type(last) == "table", "a report is a point")
	assert((last - motor.pos).Magnitude <= 8 + 1e-6, `the last report is within 8 studs of the spider ({(last - motor.pos).Magnitude})`)
	local gaps = 0
	for i = before + 2, #reports do
		if (reports[i][1] - reports[i - 1][1]).Magnitude > 8.5 then gaps += 1 end
	end
	assert(gaps == 0, "no stretch of more than 8 studs went unreported")
	assert(driver.world:regionReady("bed_a") and driver.world:regionReady("house_wall") and driver.world:regionReady("outer_sill"), "every region it passed through was whole")
end)

check("a rest under the bed's stone keeps the world it was in (bed_a, bed_a_stone) and a return to it comes back under the stone", function()
	local driver = ClientStubs.driver
	local life = driver.life
	driver.place(Vector3.new(11, -89.69, -50))
	frames(30)
	assert(driver.world.region.id == "bed_a" and driver.world:inRetreat(driver.motor.pos) == "bed_a_stone", "under the stone")
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2); settleRest()
	assert(life.resting, "no rest under the stone: " .. tostring(life.notice))
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.region == "bed_a" and best.record.world_map.retreat == "bed_a_stone" and best.record.player.retreat_id == "bed_a_stone"
		and best.record.world_map.revision == "world-3", "the rest carries the bed and its stone")
	-- walk out from under it, and come back
	driver.motor:place(Vector3.new(11, -89.69, -50), Vector3.yAxis, Vector3.new(0, 0, 1))
	driver.camera:snap()
	key("Forward", true); frames(120); key("Forward", false); frames(30)
	assert(driver.world:inRetreat(driver.motor.pos) == nil, "walked out from under the stone")
	key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end); frames(2)
	assert(driver.lifeSpider().inRetreat and life.resting and driver.world:inRetreat(driver.motor.pos) == "bed_a_stone", "back resting under the stone")
	assert(driver.world.region.id == "bed_a" and LifeClock.game.clockScale == 0.33 and string.find(life.notice, "the world has changed", 1, true) == nil, "in the bed, at its pace, with no word of a changed world")
	-- home again, for the checks that follow
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	assert(driver.world.region.id == "sill" and LifeClock.game.clockScale == 1.0, "back on the sill")
end)

check("the roaming rival's legs belong to the sill region and keep out of its crack, on the folders the server builds", function()
	local driver = ClientStubs.driver
	local life = driver.life
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(30)
	life.clock.day = 2
	life.clock.hour = 9
	driver.prey.feeding.mealsFinished = 1
	frames(10)
	assert(life.rival and life.rival.state == "patrol", "the rival did not arrive: " .. tostring(life.rival and life.rival.state))
	local drive = driver.rivalLegs.drive
	assert(drive ~= nil and drive.region == "sill", "the rival's legs are made for the sill")
	assert(drive.motor.config.boundsMin == sill.bounds[1] and drive.motor.config.boundsMax == sill.bounds[2] and drive.motor.config.inBounds == nil, "and keep to the sill's bounds (ROBLOX-95)")
	local filter = drive.motor.params.FilterDescendantsInstances
	assert(#filter == 1 and filter[1] == driver.world.root, "and walk on the World folder's boxes")
	local at, moved, crack = life.rival.position, 0.0, 0
	for _ = 1, 10 do
		frames(30)
		moved = math.max(moved, (life.rival.position - at).Magnitude)
		if WorldMap.inRetreat(life.rival.position) ~= nil then crack += 1 end
		life.clock.hour = 9
	end
	assert(moved > 2, `the rival did not walk ({moved})`)
	assert(crack == 0, "the rival entered the retreat")
end)

-- ---------------------------------------------------------------- ROBLOX-96 (W3): the garden's life through the real client
check("prey runs only in the spider's region: on the sill the sill's flies alone; in the bed, once it is whole, the bed's gnats, aphids and woodlice, drawn", function()
	local driver = ClientStubs.driver
	local pw = driver.world.prey
	local garden = driver.world.garden
	assert(pw ~= nil and garden ~= nil and driver.world.bugs ~= nil, "the client made the world's prey and the drawn bugs")
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	assert(#pw.active == 1 and pw.active[1] == "sill", `on the sill only the sill's prey runs ({table.concat(pw.active, ",")})`)
	assert(#pw:flies() == #driver.prey.flies and #pw:flies() >= 1, "the drawn flies are the sill's")
	-- (the walk of ROBLOX-95's check above already took the spider into the bed and made its director: taken away here, as if it had never been made, for the gate)
	garden.bed_a = nil
	pw.made = 0
	local flyFolder = workspace:FindFirstChild("Flies") :: Instance
	for _, f in flyFolder:GetChildren() do assert(string.sub(f.Name, 1, 4) == "fly_", "a drawn fly of the sill: " .. f.Name) end
	-- the bed, not whole: a box taken away before the spider arrives
	local bedFolder = (driver.world.root :: Instance):FindFirstChild("bed_a") :: Instance
	local taken = bedFolder:FindFirstChild("bed_a_mound_1") :: Instance
	taken.Parent = nil
	driver.world.whole.bed_a = nil
	driver.world.warned.bed_a = nil
	local seen = warnings(function()
		driver.place(Vector3.new(-20, -89.69, -30))
		frames(10)
	end)
	local bedFlies = 0
	for _, f in pw:flies() do if string.find(f.id, "bed_a_", 1, true) == 1 then bedFlies += 1 end end
	assert(driver.world.region.id == "bed_a" and garden.bed_a == nil and bedFlies == 0, "a bed that is not whole has no prey, however long the spider stands in it (ROBLOX-101: the whole wall beside it may run its own)")
	assert(#seen == 1 and string.find(seen[1], "bed_a", 1, true) ~= nil and string.find(seen[1], "not arrived whole", 1, true) ~= nil, "and the once-per-region warning says so: " .. table.concat(seen, " | "))
	taken.Parent = bedFolder
	seen = warnings(function() frames(10) end)
	assert(#seen == 0, "whole again: no more warnings")
	assert(garden.bed_a ~= nil and garden.bed_a.prey ~= nil and garden.bed_a.bugs ~= nil, "the bed's prey and woodlice are made once it is whole")
	assert(pw.active[1] == "bed_a" and table.find(pw.active, "sill") == nil, `in the bed the bed's prey runs (and, ROBLOX-101, the wall's beside it when its perches are near), never the sill's ({table.concat(pw.active, ",")})`)
	local d = garden.bed_a.prey
	assert(#d.flies == 6 and d.feeding == driver.prey.feeding, "six prey, eating with the sill's jaws")
	local gnats, aphids = 0, 0
	for _, f in flyFolder:GetChildren() do
		if string.sub(f.Name, 1, 4) ~= "fly_" and string.find(f.Name, "bed_a_fly_", 1, true) == nil then
			-- (ROBLOX-101: the bestiary's, the bed's springtails and leafhoppers and, when near, the wall's moths and crane fly; ROBLOX-107: and, this near the bed's
			-- west edge, the springtails of the bushes' first chunk beside it)
			assert(string.find(f.Name, "bed_a_", 1, true) == 1 or string.find(f.Name, "house_wall_", 1, true) == 1 or string.find(f.Name, "shrub_west_a_", 1, true) == 1,
				"a drawn prey of the garden: " .. f.Name)
		elseif string.find(f.Name, "bed_a_fly_", 1, true) then
			local kind = (workspace:FindFirstChild("Flies") :: Instance) ~= nil and f:FindFirstChild("Cornicle") == nil and f:FindFirstChild("RightWing") ~= nil
			if f:FindFirstChild("RightCornicle") then aphids += 1 elseif f:FindFirstChild("RightWing") then gnats += 1 end
		else
			error("a sill fly drawn in the bed: " .. f.Name)
		end
	end
	assert(gnats == 3 and aphids == 3, `drawn: {gnats} gnats and {aphids} aphids`)
	local bugs = workspace:FindFirstChild("Bugs") :: Instance
	local lice, ambient = 0, 0
	for _, w in bugs:GetChildren() do
		if string.find(w.Name, "louse_", 1, true) == 1 then lice += 1; assert(#w:GetChildren() == 24, "a woodlouse is 24 parts")
		elseif string.find(w.Name, "bed_a_", 1, true) == 1 then ambient += 1 end
	end
	-- (ROBLOX-105: the bed's ambient bugs are drawn beside them: two ladybirds, two millipedes, a snail and a harvestman at the full tier)
	assert(bugs ~= nil and lice == 4 and ambient == 6, `four woodlice drawn, and the bed's six ambient bugs ({lice}, {ambient})`)
	assert(driver.world:regionReady("bed_a"), "the bed is whole")
end)

check("crossing a seam rerolls nothing: the bed's prey waits while the spider is on the wall and takes up where it was", function()
	local driver = ClientStubs.driver
	local pw, garden = driver.world.prey, driver.world.garden
	driver.place(Vector3.new(-20, -89.69, -30))
	frames(120)
	local d = garden.bed_a.prey
	local before = {}
	for i, f in d.flies do before[i] = { id = f.id, pos = f.position, rng = f.rng.state } end
	local made, now = pw.made, d.now
	driver.place(Vector3.new(36, -1.69, -24.31), Vector3.new(0, 0, -1)) -- (on the face of the wall's east shoulder, by the wall's own spawn: the sill no neighbour, the bed's farthest perch beyond 96; ROBLOX-103: the shoulder's top is under the window's east jamb now)
	frames(60)
	assert(driver.world.region.id == "house_wall" and table.find(pw.active, "bed_a") == nil and d.now == now, `high on the wall the bed's prey does not run and its clock has stopped ({driver.world.region.id}: {table.concat(pw.active, ",")})`)
	local drawnBed = 0
	for _, f in (workspace:FindFirstChild("Flies") :: Instance):GetChildren() do if string.find(f.Name, "bed_a_", 1, true) == 1 then drawnBed += 1 end end
	for _, b in (workspace:FindFirstChild("Bugs") :: Instance):GetChildren() do
		if string.find(b.Name, "louse_", 1, true) == 1 or string.find(b.Name, "bed_a_", 1, true) == 1 then drawnBed += 1 end
	end
	assert(drawnBed == 0, "nothing of the bed drawn there (ROBLOX-101: the wall's own moths and crane fly may be; ROBLOX-105: and its harvestman)")
	driver.place(Vector3.new(-20, -89.69, -30))
	frames(1)
	assert(garden.bed_a.prey == d and pw.made == made, "the same director, not another")
	for i, f in d.flies do
		local b = before[i]
		assert(b ~= nil and b.id == f.id and (b.pos - f.prevPosition).Magnitude < 1e-9, `{f.id} took up where it was`)
	end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	assert(#pw.active == 1 and pw.active[1] == "sill" and garden.bed_a.prey == d, "home: the sill's prey runs again and the bed's director is kept")
end)

check("the descent: from the slab's front edge the spider lets itself down the wall on its line at 0.75 studs a second, lands on the soil, releases the line, and is in bed_a with its focus reported", function()
	local driver = ClientStubs.driver
	local motor = driver.motor
	local fired = function(): { any } return rawget(focusRemote, "fired") or {} end
	assert(motor.silk.maximum == 100 and motor.silk.lowerSpeed == 0.75, `the game's line: 100 studs at most, let down at 0.75 ({motor.silk.maximum}, {motor.silk.lowerSpeed})`)
	driver.place(Vector3.new(2, 0.31, -23.2))
	motor:place(Vector3.new(2, 0.31, -23.2), Vector3.yAxis, Vector3.new(0, 0, -1))
	driver.camera:snap()
	frames(5)
	assert(driver.world.region.id == "outer_sill", "on the outer sill, at its front edge")
	local seen = warnings(function()
		key("Drop", true)
		local dropped, lowest, landedAt = false, 0.31, nil
		local lowerRate = 0
		for i = 1, 60 * 150 do
			frames(1)
			if motor:onLine() then dropped = true end
			lowest = math.min(lowest, motor.pos.Y)
			if dropped and i % 600 == 0 and motor:onLine() and motor.pos.Y > -80 then
				local y0 = motor.pos.Y
				frames(60)
				lowerRate = y0 - motor.pos.Y
			end
			if dropped and motor.mode == "attached" and driver.world.region.id == "bed_a" then landedAt = i; break end
		end
		key("Drop", false)
		frames(2)
		assert(dropped, "the spider never let itself down")
		assert(landedAt ~= nil, `the spider did not land on the bed within 150 s (at {motor.pos}, mode {motor.mode}, line {motor.silk.mode}, lowest {lowest})`)
		print(`world_client: the descent took {landedAt / 60} s; lowering measured at {lowerRate} studs a second`)
		assert(lowerRate > 0.6 and lowerRate < 0.9, `let down at about 0.75 studs a second ({lowerRate})`)
		assert(landedAt / 60 > 100 and landedAt / 60 < 150, `about two minutes for the 90 studs ({landedAt / 60} s)`)
	end)
	assert(#seen == 0, "no world warning on the way down: " .. table.concat(seen, " | "))
	assert(motor.mode == "attached" and motor.up.Y > 0.9 and math.abs(motor.pos.Y - (-90 + 0.31)) < 0.1, `standing on the soil ({motor.pos}, up {motor.up})`)
	assert(motor.silk.mode == "none" and not motor:onLine(), "the line is released")
	assert(driver.world.region.id == "bed_a" and LifeClock.game.clockScale == 0.33, "in the bed, at its pace")
	local reports = fired()
	local last = reports[#reports][1]
	assert((last - motor.pos).Magnitude <= 8 + 1e-6, `the focus report followed ({(last - motor.pos).Magnitude} studs behind)`)
	assert(driver.world.garden.bed_a ~= nil and driver.world.prey.active[1] == "bed_a", "and the bed's prey runs")
end)

check("the stone is a home in the words: near it the line says so, under it the prompt and a kept rest say under the stone; the crack's words are as they were", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local hud = driver.hud
	-- (ROBLOX-113: the way home and the rest's how-to are the first day's words in Normal; read here on a first day, the day put back after)
	local day = life.clock.day
	life.clock.day = 1
	driver.place(Vector3.new(11, -89.69, -44))
	frames(5)
	assert(driver.world:homeRetreat(driver.motor.pos) == "bed_a_stone" and driver.world.lastRetreat == "bed_a_stone", "in the bed the home is the stone")
	assert(hud.promptTitle.Text == "Home: under the stone" and string.find(hud.promptHint.Text, "gap under the big stone", 1, true) ~= nil, `near the stone: "{hud.promptTitle.Text}" / "{hud.promptHint.Text}"`)
	driver.place(Vector3.new(11, -89.69, -50))
	frames(5)
	assert(hud.promptTitle.Text == "Under the stone", `under it, able to rest: "{hud.promptTitle.Text}"`)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2); settleRest()
	assert(life.resting and life.notice == "Last rest kept, under the stone.", `the kept rest says where: "{life.notice}"`)
	assert(hud.promptTitle.Text == "Resting under the stone", `resting: "{hud.promptTitle.Text}"`)
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world.roots.garden ~= nil, "the rest records the garden's prey")
	-- home: the crack's words, word for word
	driver.place(Vector3.new(-20, 0.31, 6))
	frames(5)
	assert(driver.world:homeRetreat(driver.motor.pos) == "sill_crevice", "on the sill the home is the crack")
	assert(hud.promptTitle.Text == "Home: the silk-lined crack" and hud.promptHint.Text == "Walk through the silk-framed opening under the wooden roof, then stop to rest.", `near the crack: "{hud.promptTitle.Text}" / "{hud.promptHint.Text}"`)
	driver.place(Vector3.new(-25.5, 0.31, 6))
	frames(5)
	assert(hud.promptTitle.Text == "The silk-lined crack", `in the crack: "{hud.promptTitle.Text}"`)
	key("Feed", true); frames(2); key("Feed", false); frames(2); settleRest()
	assert(life.resting and life.notice == "Last rest kept." and hud.promptTitle.Text == "Resting in the silk-lined crack", `the crack's rest: "{life.notice}" / "{hud.promptTitle.Text}"`)
	life.clock.day = day
end)

check("a return to a rest under the stone puts the bed's prey back where it was", function()
	local driver = ClientStubs.driver
	local life = driver.life
	local garden = driver.world.garden
	driver.place(Vector3.new(-5, 0.31, -9)) -- (out of the crack first: the rest the check above left going ends)
	frames(5)
	assert(not life.resting, "the crack's rest has ended")
	driver.place(Vector3.new(11, -89.69, -50))
	frames(30)
	life.clock.hour = 12
	key("Feed", true); frames(2); key("Feed", false); frames(2); settleRest()
	assert(life.resting, "resting under the stone: " .. tostring(life.notice))
	local d = garden.bed_a.prey
	local keptTick = d.tick
	local kept = {}
	for i, f in d.flies do kept[i] = { id = f.id, pos = f.position, nutrition = f.nutrition, profile = f.profile } end
	local lice = {}
	for i, l in garden.bed_a.bugs.lice do lice[i] = l.position end
	-- the garden goes on without the spider for a while, then the rest is returned to
	driver.motor:place(Vector3.new(11, -89.69, -50), Vector3.yAxis, Vector3.new(0, 0, 1))
	driver.camera:snap()
	key("Forward", true); frames(300); key("Forward", false); frames(300)
	local moved = false
	for i, f in d.flies do if kept[i] == nil or kept[i].id ~= f.id or (kept[i].pos - f.position).Magnitude > 0.01 then moved = true end end
	assert(moved, "the prey moved on meanwhile")
	key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end)
	-- The original synchronous reset advanced three simulation ticks before this
	-- comparison. Preparation advances none; retain those exact three ticks.
	frames(3)
	assert(life.resting and driver.world:inRetreat(driver.motor.pos) == "bed_a_stone", "back under the stone")
	local d2 = garden.bed_a.prey
	assert(d2.tick == keptTick, "restored ecology is compared at the same simulation tick")
	assert(d2 ~= nil and #d2.flies == #kept, "the bed's prey is back")
	for i, f in d2.flies do
		local k = kept[i]
		assert(k.id == f.id and (k.pos - f.position).Magnitude < 1e-9 and k.nutrition == f.nutrition and k.profile == f.profile, `{f.id} is where it was, as it was`)
	end
	assert(d2.feeding == driver.prey.feeding, "and still eats with the sill's jaws")
	for i, l in garden.bed_a.bugs.lice do assert((lice[i] - l.position).Magnitude < 1e-9, "the woodlice are where they were") end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
end)

-- ---------------------------------------------------------------- ROBLOX-101 (W3b part A): the bestiary through the real client
check("the bestiary through the real client: the bed's springtails and leafhoppers made and drawn at the client's tier, the wall's moths flying from dusk by the life clock's hour, the sill's prey alone on the sill", function()
	local driver = ClientStubs.driver
	local pw, garden, life = driver.world.prey, driver.world.garden, driver.life
	assert(pw.tier == "full" or pw.tier == "low", `the client gave the world's prey its tier ({pw.tier})`)
	driver.place(Vector3.new(-20, -89.69, -30))
	life.clock.hour = 12
	frames(10)
	local kinds = garden.bed_a.kinds
	assert(kinds ~= nil and kinds.springtail ~= nil and kinds.leafhopper ~= nil, "the bed's springtails and leafhoppers are made")
	local want = if pw.tier == "low" then { 2, 1 } else { 4, 2 }
	assert(#kinds.springtail.flies == want[1] and #kinds.leafhopper.flies == want[2], `{#kinds.springtail.flies} springtails and {#kinds.leafhopper.flies} leafhoppers at the {pw.tier} tier`)
	assert(kinds.springtail.feeding == driver.prey.feeding and kinds.leafhopper.feeding == driver.prey.feeding, "eating with the sill's jaws")
	local springtails, leafhoppers = 0, 0
	for _, f in (workspace:FindFirstChild("Flies") :: Instance):GetChildren() do
		if string.find(f.Name, "bed_a_springtail_fly_", 1, true) == 1 then springtails += 1; assert(f:FindFirstChild("Thorax") ~= nil, "a springtail's body") end
		if string.find(f.Name, "bed_a_leafhopper_fly_", 1, true) == 1 then leafhoppers += 1; assert(f:FindFirstChild("Pronotum") ~= nil, "a leafhopper's body") end
	end
	assert(springtails == want[1] and leafhoppers == want[2], `drawn: {springtails} springtails, {leafhoppers} leafhoppers`)
	-- on the wall at noon its moths keep the day's profile; at 20:00 the dusk's
	driver.place(Vector3.new(36, -1.69, -24.31), Vector3.new(0, 0, -1))
	life.clock.hour = 12
	frames(5)
	local wall = garden.house_wall
	assert(wall ~= nil and wall.kinds ~= nil and wall.kinds.moth ~= nil and wall.kinds.moth.p == Species.moth_prototype, "the wall's moths, by day")
	life.clock.hour = 20
	frames(5)
	assert(wall.kinds.moth.p == Species.moth_dusk_prototype and wall.kinds.crane_fly.p == Species.crane_fly_dusk_prototype, "from dusk, the dusk's (the client hands the prey the life clock's hour)")
	life.clock.hour = 12
	frames(2)
	-- home: the sill's prey alone
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(5)
	assert(#pw.active == 1 and pw.active[1] == "sill", "on the sill the sill's prey alone, though the outer sill has its own")
	for _, f in (workspace:FindFirstChild("Flies") :: Instance):GetChildren() do assert(string.sub(f.Name, 1, 4) == "fly_", "only the sill's flies drawn on the sill: " .. f.Name) end
end)


check("the looks outside the window are this client's own and follow the spider (ROBLOX-108): within the budget, its region and neighbours drawn, spread over frames, at both tiers", function()
	local LookPlan = require("../src/Shared/World/LookPlan")
	local LookStream = require("../src/Client/LookStream")
	local Scenery = require("../src/Shared/Habitat/Scenery")
	local driver = ClientStubs.driver
	local looks = driver.world.looks
	assert(looks ~= nil and looks.tier == "full" and looks.folder.Parent == workspace and looks.folder.Name == Region.LOOKS_FOLDER, "the client's looks, in WorldDecor, at its tier")
	local function partsIn(root: Instance): number
		local n = 0
		for _, d in root:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
		return n
	end
	local function drawn(stream: any, id: string): string?
		local look = stream.looks[id]
		if look == nil then return nil end
		if look.sets.Base ~= nil then return if look.sets.Full ~= nil then "full" else "low" end
		if look.sets.Far ~= nil then return "far" end
		return nil
	end
	-- the real client: placed in seven regions (ROBLOX-112: the kitchen too), the looks it holds once they are made
	for _, at in { Vector3.new(-5, 0.31, -9), Vector3.new(0, 0.31, -18), Vector3.new(11, -89.69, -43.5), Vector3.new(0, 149.31, -71), Vector3.new(-70, -89.69, -60), Vector3.new(-450, -89.69, -150),
		Vector3.new(-45, -3.69, 41) } do
		driver.place(at)
		frames(2)
		looks:finish()
		frames(1)
		local here = WorldMap.at(at) :: WorldMap.Region
		local n = partsIn(looks.folder)
		assert(n == looks:parts() and n == looks.planned and n <= LookPlan.BUDGET.full, `at {at} ({here.id}): {n} parts of looks held, planned {looks.planned}`)
		if here.kind ~= "sill" then assert(drawn(looks, here.id) == "full", `at {here.id}: its own look at full`) end
		for _, nb in here.neighbors do
			if nb.id ~= "sill" then assert(drawn(looks, nb.id) == "full", `at {here.id}: its neighbour {nb.id} at full ({tostring(drawn(looks, nb.id))})`) end
		end
		for id, level in looks.plan do assert(drawn(looks, id) == level, `at {here.id}: {id} drawn as planned ({level})`) end
		print(string.format("world_client: at %s the client holds %d parts of looks", here.id, n))
	end
	driver.place(Vector3.new(-5, 0.31, -9))
	frames(2)
	-- the work is spread: a new stream at the bed makes its region and neighbours whole at once and the rest at most PARTS_PER_FRAME a frame, within the budget
	local holder = Instance.new("Folder")
	holder.Parent = workspace
	local bedAt = Vector3.new(11, -89.69, -43.5)
	local fresh = LookStream.new(holder, "full", serverFolder)
	local first = fresh:update(bedAt, WorldMap.at(bedAt))
	local urgent = LookPlan.count(WorldMap.region("bed_a") :: any, "low") + LookPlan.count(WorldMap.region("house_wall") :: any, "low") + LookPlan.count(WorldMap.region("shrub_west_a") :: any, "low")
	assert(first <= urgent + LookStream.PARTS_PER_FRAME and drawn(fresh, "bed_a") ~= nil and drawn(fresh, "house_wall") ~= nil and drawn(fresh, "shrub_west_a") ~= nil,
		`the first frame made {first} parts: the bed, the wall and the first bushes whole (their base looks), at most {LookStream.PARTS_PER_FRAME} more`)
	local frameCount, worst = 1, first
	while #fresh.jobs > 0 do
		local made = fresh:update(bedAt, WorldMap.at(bedAt))
		worst = math.max(worst, made)
		assert(made <= LookStream.PARTS_PER_FRAME, `a later frame made {made} parts`)
		assert(fresh:parts() <= LookPlan.BUDGET.full, "never more than the budget held")
		frameCount += 1
		assert(frameCount < 100, "the looks are made in a few frames")
	end
	assert(fresh:parts() == fresh.planned, "then the plan is held whole")
	print(string.format("world_client: a new stream at the bed: %d parts the first frame, %d frames to %d parts", first, frameCount, fresh:parts()))
	holder:Destroy()
	-- the low tier, at the twelve places of tests/worldmap.luau: within 500 parts, nothing only the full tier draws
	local low = LookStream.new(holder, "low", serverFolder)
	holder.Parent = workspace
	for _, at in { Vector3.new(-5, 0.31, -9), Vector3.new(0, 0.31, -18), Vector3.new(0, -45, -24.3), Vector3.new(-20, -88, -24.3), Vector3.new(11, -89.69, -43.5), Vector3.new(0, 149.3, -71),
		Vector3.new(-80, -45, -24.3), Vector3.new(-50, 132, -40), Vector3.new(-30, -89.7, -30), Vector3.new(-120, -89.7, -112), Vector3.new(-262, -89.7, -112), Vector3.new(-495, -89.7, -195) } do
		low:update(at, WorldMap.at(at))
		low:finish()
		local n = partsIn(holder)
		assert(n == low.planned and n <= LookPlan.BUDGET.low, `low, at {at}: {n} parts`)
		for _, d in holder:GetDescendants() do assert(d:GetAttribute("FullOnly") ~= true, "low: a part only the full tier draws: " .. d.Name) end
	end
	print(string.format("world_client: the low tier's stream: %d parts made and %d destroyed over twelve places", low.made, low.destroyed))
	holder:Destroy()
	-- a look that fails is warned about once, its drawn pieces shown on this client, and never tried again
	local said: { string } = {}
	local realWarn = warn
	local realLook = Scenery.look
	local bad = LookPlan.records(WorldMap.region("house_wall") :: any, "low")
	warn = function(m: string) table.insert(said, m) end
	Scenery.look = function(parent: Instance, list: { any }, a: number?, b: number?, g: any?): number
		if list == bad then error("boom") end
		return realLook(parent, list, a, b, g)
	end
	local broken = LookStream.new(workspace, "full", serverFolder)
	local ok, err = pcall(function()
		broken:update(Vector3.new(0, 0.31, -18), WorldMap.region("outer_sill"))
		broken:finish()
	end)
	Scenery.look = realLook
	warn = realWarn
	assert(ok, tostring(err))
	local wallFolder = serverFolder:FindFirstChild("house_wall") :: Instance
	local shown = true
	for _, id in Region.drawnPieces(WorldMap.region("house_wall") :: any) do
		local p = wallFolder:FindFirstChild(id) :: any
		if p ~= nil and p.Transparency ~= 0 then shown = false end
	end
	assert(#said == 1 and string.find(said[1], "house_wall", 1, true) ~= nil and broken.looks.house_wall == nil and broken.failed.house_wall and shown and drawn(broken, "outer_sill") == "full",
		`a failed look: {#said} warnings, its bricks shown, the others drawn`)
	broken.folder:Destroy()
	for _, id in Region.drawnPieces(WorldMap.region("house_wall") :: any) do
		local p = wallFolder:FindFirstChild(id) :: any
		if p ~= nil then p.Transparency = 1 end
	end
end)

check("actual player holds pose and clocks through collision disappearance and partial return",function()
 local d=assert(ClientStubs.driver);local folder,parent,part;local oldStreaming=workspace.StreamingEnabled
 local ok,problem=xpcall(function()
  assert(d.fresh("free",false,nil));d.place(Vector3.new(11,-89.69,-50));frames(5)
  local bed=assert(WorldMap.region("bed_a"));folder=assert(d.world:folderOf(bed));parent=folder.Parent
  local at,vel,mode=d.motor.pos,d.motor.vel,d.motor.mode
  local elapsed,needsTime,preyTime=d.life.elapsed,d.needs.elapsedS,d.world.prey.clock
  local life,motor=d.life,d.motor
  assert(mode=="attached" and d.world:regionReady(bed.id) and d.world.whole.bed_a,"fixture needs a previously complete floor")
  workspace.StreamingEnabled=true;folder.Parent=nil
  frame(.25);frames(30)
  assert(d.world.playerLoading and d.motor.pos==at and d.motor.vel==vel and d.motor.mode==mode,"missing collision changed the player's physics")
  assert(d.life.elapsed==elapsed and d.needs.elapsedS==needsTime and d.world.prey.clock==preyTime,"life/needs/prey advanced while collision was absent")
  part=assert(folder:FindFirstChild(Region.pieces(bed)[1].id));part.Parent=nil;folder.Parent=parent
  frames(10)
  assert(d.world.playerLoading and d.motor.pos==at and d.life.elapsed==elapsed,"partial collision arrival released the player")
  part.Parent=folder;frames(2)
  assert(not d.world.playerLoading and d.motor.mode=="attached" and d.life.elapsed>elapsed,"complete collision did not resume the same player")
  assert(d.life==life and d.motor==motor,"resume replaced the simulation objects")
  local again=d.motor.pos;elapsed=d.life.elapsed;folder.Parent=nil;frames(3)
  assert(d.world.playerLoading and d.motor.pos==again and d.life.elapsed==elapsed,"cached first arrival hid a second stream-out")
  print("PLAYER_STREAM_HOLD disappeared_pose_retained=true clocks_frozen=true partial_refused=true resumed_same_objects=true second_stream_out_held=true")
 end,debug.traceback)
 if part and folder then part.Parent=folder end;if folder then folder.Parent=parent end
 workspace.StreamingEnabled=oldStreaming;frames(1)
 assert(ok,problem)
end)
check("fixed tick refuses a prospective airborne step into absent authored collision",function()
 local d=assert(ClientStubs.driver);local folder,parent
 local ok,problem=xpcall(function()
  assert(d.fresh("free",false,nil));frames(2)
  local bed=assert(WorldMap.region("bed_a"));folder=assert(d.world:folderOf(bed));parent=folder.Parent;folder.Parent=nil
  local at=d.motor.pos;d.motor.mode="air";d.motor.vel=(bed.spawn.pos-at)/(1/60)
  local vel=d.motor.vel;local elapsed,needsTime=d.life.elapsed,d.needs.elapsedS
  frame(.25)
  assert(d.world.playerLoading and d.motor.pos==at and d.motor.vel==vel and d.motor.mode=="air","fixed tick entered missing collision or discarded airborne state")
  assert(d.life.elapsed==elapsed and d.needs.elapsedS==needsTime,"fixed tick advanced clocks before its readiness gate")
  print("PLAYER_STREAM_NEXT_TICK refused=true velocity_retained=true clocks_frozen=true")
 end,debug.traceback)
 if folder then folder.Parent=parent end
 assert(d.fresh("free",false,nil));frames(1)
 assert(ok,problem)
end)

-- First-arrival readiness must not survive missing collision. Engine streaming has separate native evidence.
local function readyBed()
 workspace:ClearAllChildren();WorldMap.use("test_garden")
 local root=WorldBuild.world(workspace)
 local client=WorldClient.new(workspace,Instance.new("Player"),WorldMap)
 local bed=assert(WorldMap.region("bed_a"));client.region=bed
 local folder=assert(client:folderOf(bed))
 assert(client:creatureLive("bed_a") and client.whole.bed_a,"fixture was not first ready")
 return client,folder,root
end
check("stream-out: atomic folder leaves after first arrival",function()
 local client,folder=readyBed();folder.Parent=nil
 assert(not client:regionReady("bed_a"),"fixture has not left")
 assert(not client:creatureLive("bed_a"),"resident still simulates on streamed-out geometry")
 workspace:ClearAllChildren()
end)
check("stream-out: one collision piece leaves after first arrival",function()
 local client,folder=readyBed();folder:GetChildren()[1].Parent=nil
 assert(not client:regionReady("bed_a"),"fixture is not partial")
 assert(not client:creatureLive("bed_a"),"resident still simulates on partial geometry")
 workspace:ClearAllChildren()
end)
check("stream-out: partial rearrival refuses then resumes same creature gate",function()
 local client,folder,root=readyBed();folder.Parent=nil
 local part=folder:GetChildren()[1];part.Parent=nil;folder.Parent=root
 assert(not client:creatureLive("bed_a"),"partial replacement treated as ready")
 part.Parent=folder
 assert(client:creatureLive("bed_a"),"complete geometry did not resume")
 workspace:ClearAllChildren()
end)
check("player readiness rereads current collision and permits a complete rearrival",function()
 local client,folder,root=readyBed();local at=assert(WorldMap.region("bed_a")).spawn.pos
 assert(client:playerCanAdvance(at) and not client.playerLoading)
 folder.Parent=nil;assert(not client:playerCanAdvance(at) and client.playerLoading)
 local part=folder:GetChildren()[1];part.Parent=nil;folder.Parent=root
 assert(not client:playerCanAdvance(at),"partial player region was admitted")
 part.Parent=folder;assert(client:playerCanAdvance(at) and not client.playerLoading)
 workspace:ClearAllChildren()
end)
check("player readiness gates the known destination but leaves ordinary void falls alone",function()
 local client,folder=readyBed();local at=assert(WorldMap.region("house_wall")).spawn.pos;local target=assert(WorldMap.region("bed_a")).spawn.pos
 assert(client:playerCanAdvance(at,target));folder.Parent=nil
 assert(not client:playerCanAdvance(at,target) and client.playerLoading,"missing airborne destination was admitted")
 assert(client:playerCanAdvance(Vector3.new(1e6,1e6,1e6)) and not client.playerLoading,"ordinary off-map fall was frozen")
 workspace:ClearAllChildren()
end)
check("cached home pointer cannot admit collision detached from its actual world",function()
 local client=readyBed();local home=assert(WorldMap.region("sill"));local parent=client.sill.Parent
 client.sill.Parent=nil;assert(not client:playerCanAdvance(home.spawn.pos),"detached home collision was admitted")
 client.sill.Parent=parent;assert(client:playerCanAdvance(home.spawn.pos))
 workspace:ClearAllChildren()
end)
check("player collision readiness does not wait for optional decor",function()
 local client=readyBed();client.decor=nil
 assert(client:playerCanAdvance(assert(WorldMap.region("bed_a")).spawn.pos),"optional looks blocked physics")
 workspace:ClearAllChildren()
end)
check("flat legacy worlds retain their original jump and fall scope",function()
 workspace:ClearAllChildren();local old=workspace.StreamingEnabled;workspace.StreamingEnabled=false
 local flat=flatWorld();local client=WorldClient.new(workspace,Instance.new("Player"),WorldMap)
 assert(client.root==flat and client:playerCanAdvance(assert(WorldMap.region("bed_a")).spawn.pos) and not client.playerLoading)
 workspace.StreamingEnabled=old;workspace:ClearAllChildren()
end)

print("WORLD_CLIENT passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("WORLD_CLIENT failed") end
