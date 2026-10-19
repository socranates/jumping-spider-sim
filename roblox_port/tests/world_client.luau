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
	assert(outside > 0 and outside < 80, `some rays from the sill reach the world outside, most do not ({outside})`)
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

check("a spider in a region that has not arrived whole is warned about once for that region, in Output, and the game goes on", function()
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

check("the world's bounds: out of it is in no region, so a fall from the sill's room side ends where it always did and one from the outer sill goes on to the bed", function()
	workspace:ClearAllChildren()
	serverWorld()
	local c = WorldClient.new(workspace, player())
	assert(c:inBounds(Vector3.new(0, -4.9, 12.4)) and not c:inBounds(Vector3.new(0, -5.1, 12.4)), "in front of the sill (the room's side), y -5 is the floor of the world, as it was")
	assert(c:inBounds(Vector3.new(0, -50, -27)) and c:inBounds(Vector3.new(0, -89.69, -40)) and not c:inBounds(Vector3.new(0, -93.5, -40)), "out over the stone it goes on down past the wall to the bed")
	assert(not c:inBounds(Vector3.new(60, -50, -40)) and c.homeMin == sill.bounds[1] and c.homeMax == sill.bounds[2], "beside the garden, nothing; the rival's and the mate's bounds are the sill's")
	local lo, hi = WorldMap.bounds()
	assert(c.boundsMin == lo and c.boundsMax == hi and lo.Y == -93, "the motor's box is the union, down to just under the bed's soil")
	workspace:ClearAllChildren()
end)

-- ---------------------------------------------------------------- instance streaming: the sim begins on a whole sill
-- The late boxes come when the client asks for them (WaitForChild), as streaming brings them; `never` leaves them out for good.
local function streamed(never: boolean): ({ { name: string, timeout: number } }, { string }, any, { string })
	workspace:ClearAllChildren()
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
	workspace.StreamingEnabled = true
	local client: any = nil
	local seen = warnings(function() client = WorldClient.new(workspace, player()) end)
	workspace.StreamingEnabled = nil
	rawset(workspace, "WaitForChild", nil)
	return askedSill, askedWorkspace, client, seen
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

check("a box that never streams in is warned of by name, and the sim still begins", function()
	local askedSill, _, c, seen = streamed(true)
	assert(#askedSill == 3, `asked for {#askedSill} boxes`)
	assert(#seen == 3 and string.find(seen[1], Layout.PIECES[1].id, 1, true) ~= nil and string.find(seen[2], Layout.PIECES[12].id, 1, true) ~= nil and string.find(seen[3], Layout.PIECES[#Layout.PIECES].id, 1, true) ~= nil,
		`a warning for each box that did not come ({#seen})`)
	assert(c ~= nil and c.sill.Name == "Windowsill" and c.decor == nil, "the client is made, and says the drawn sill is not there")
	workspace:ClearAllChildren()
end)

check("without instance streaming (the test places, the box worlds) nothing is waited for", function()
	workspace:ClearAllChildren()
	local world = serverWorld()
	local sillFolder = world:FindFirstChild("Windowsill") :: Instance
	local missing = sillFolder:FindFirstChild(Layout.PIECES[1].id) :: Instance
	missing.Parent = nil
	local waits = 0
	rawset(sillFolder, "WaitForChild", function(self: Instance, name: string): Instance? waits += 1; return self:FindFirstChild(name) end)
	local c = WorldClient.new(workspace, player())
	assert(waits == 0 and c.decor == nil, `waited {waits} times`)
	workspace.StreamingEnabled = false
	WorldClient.new(workspace, player())
	workspace.StreamingEnabled = nil
	assert(waits == 0, "a place that says streaming is off is not waited on either")
	workspace:ClearAllChildren()
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
local KEYS = { Feed = "E", Forward = "W", Reset = "Backspace" }
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
	key("Reset", true); frames(1); key("Reset", false); frames(2) -- (no last rest yet: back to the start)
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
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "no rest: " .. tostring(life.notice))
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.region == "sill" and best.record.world_map.retreat == "sill_crevice" and best.record.world_map.revision == WorldMap.REVISION, "the rest carries the world it was in")
	-- Walk away, and come back: the same world puts the spider back in the crack.
	key("Forward", true); frames(90); key("Forward", false); frames(30)
	key("Reset", true); frames(1); key("Reset", false); frames(2)
	assert(driver.lifeSpider().inRetreat and life.resting, "not back resting in the crack")
	-- The same rest, kept by another revision of the world: the world has changed since, so the spider stands where a life begins.
	local other = Json.copy(best.record)
	other.world_map.revision = "world-0"
	local saved = driver.currentStore():save(other)
	assert(saved.ok, "the old revision's rest was not kept: " .. tostring(saved.message))
	key("Forward", true); frames(90); key("Forward", false); frames(30)
	key("Reset", true); frames(1); key("Reset", false); frames(2)
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
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "no rest under the stone: " .. tostring(life.notice))
	local best = driver.currentStore():loadBest()
	assert(best.ok and best.record.world_map.region == "bed_a" and best.record.world_map.retreat == "bed_a_stone" and best.record.player.retreat_id == "bed_a_stone"
		and best.record.world_map.revision == "world-2", "the rest carries the bed and its stone")
	-- walk out from under it, and come back
	driver.motor:place(Vector3.new(11, -89.69, -50), Vector3.yAxis, Vector3.new(0, 0, 1))
	driver.camera:snap()
	key("Forward", true); frames(120); key("Forward", false); frames(30)
	assert(driver.world:inRetreat(driver.motor.pos) == nil, "walked out from under the stone")
	key("Reset", true); frames(1); key("Reset", false); frames(2)
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

print("WORLD_CLIENT passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("WORLD_CLIENT failed") end
