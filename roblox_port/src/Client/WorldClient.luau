--!strict
-- The client's side of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). The spider, the flies, the wasp, the rival and the mate are all simulated here, on this
-- client, as they always were; what this module knows is the world they live in:
--   where the boxes are ... `root`, the folder every ray of the sim includes (the motor, the senses, the flies' perches, the rig's feet): the server's `World` folder, with a folder
--                            for every region. `sill`, region 0's folder inside it, for what is the sill's alone (the leaf tip). A place with only the sill straight in the workspace
--                            (the test box worlds, the old places) still works: both are that folder.
--   which region we are in .. from the spider's place each frame, kept when it is momentarily in none (`region`); the pace of its day (`clockScale`, set on LifeClock's dial each
--                            frame); and `isActive`, which says whether a creature that belongs to a region is in the region the spider is in. The creatures are regional
--                            (Predator/RivalSpider, Mate and RivalDrive take their region, the sill's unless given); nothing is sent to sleep yet: the rival and the mate go on on the
--                            sill while the spider is outside (ROBLOX-95), and the regions outside have no creatures of their own until W3.
--   what to stream .......... with instance streaming on, the server sends what is near the player's replication focus. The server parks each player's (Server/WorldFocus): that
--                            is the focus streaming follows. This also points the player's own ReplicationFocus at the drawn spider's root, when it is made and again after a respawn
--                            or a return to a rest: a client's write of that property is not expected to reach the server (the docs say to set it there), so it is belt and braces,
--                            not the mechanism; a write that raises is warned about once and the game goes on. Real network-streaming behavior needs its own native verification.
-- The sim must never raycast beyond what is streamed in: StreamingMinRadius (96 studs around the focus) is always there, so a region and its neighbours must fit inside it, and a
-- creature is only simulated in the region the spider is in or beside.
-- Essential server-layout home collision must arrive before construction returns. Streamed world identity and essential folders/pieces have bounded waits; failure
-- sets WorldStartupFailed and stops startup. Decor is best effort. Legacy flat non-streaming box fixtures keep their immediate path.
-- ROBLOX-95 (W2): the window is open and three regions lie outside it (the outer sill, the brick wall, the bed 90 studs below), the bed farther from the sill's spawn than the
-- radius. So the focus follows the spider: `update` reports the spider's place to the server through the WorldFocus remote (Server/WorldFocus) whenever it has moved more than
-- REPORT_MOVE studs from the last report or REPORT_EVERY seconds have passed, and the server moves the player's focus part there. And the client knows whether a region it is
-- in has arrived whole (`regionReady`: its folder holds every piece of Region.pieces); a player in an incomplete known region waits with its simulation held, with a once-per-region
-- diagnostic in Output. (ROBLOX-108: the looks of the regions outside are this client's own, Client/LookStream, made near the spider by `streamLooks` and `update`;
-- nothing waits for them.) The player's motor is out of the
-- world only where no region holds it (`inBounds`); the rival's and the mate's are bound to the sill and keep its bounds (`homeMin`, `homeMax`).
-- ROBLOX-96 (W3): the garden has life. `prey` is the world's prey (Prey/PreyWorld: a director per region, run where the spider is and gated by `regionReady`) and
-- `bugs` the drawn woodlice (Client/BugBodies); both are made by the client once it has its sill director, and kept here so the client gains no local. `homeRetreat`
-- is the retreat the words call home: the one the spider is in, else the first of the region it is in, else the last one it was in (the crack to begin with).
-- ROBLOX-115 (two worlds, one engine): the world it is (`world`, World/Worlds) is the Workspace attribute World, made WorldMap's active one in `new`; in the preserve
-- the looks are its backdrop's zones too (World/LookPlan), and `train` (Client/TrainPass) runs the trains on the railway beyond the north fence.
-- ROBLOX-116 (the ranger hut, walkable): in the preserve `hut` (Client/HutLife) keeps the window's sash shut through the nursery and has the ranger prop it when the
-- spider is ready (Life/Nursery), and lights the desk lamp at night; `life` is the client's life loop (set by the client), which the rule reads each frame.
-- `hutOpen` says whether the window is open (the progress record keeps it), `openHut` opens it at once (a save that has it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local Worlds = require(Shared:WaitForChild("World"):WaitForChild("Worlds"))
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))
local LifeClock = require(Shared:WaitForChild("Life"):WaitForChild("LifeClock"))
local LookStream = require(script.Parent.LookStream)
local TrainPass = require(script.Parent.TrainPass)
local HutLife = require(script.Parent.HutLife)
local WorldShadows = require(script.Parent.WorldShadows)
local FrameProfile = require(script.Parent.FrameProfile)
local LivingWorld = require(script.Parent.LivingWorld)
local Station = require(Shared.World.StationTerritory)

local WorldClient = {}
WorldClient.__index = WorldClient

-- A line in Output (the engine's warn; the CLI tests that drive the client have none unless they collect them).
local function tell(message: string)
	local say: any = warn
	if say ~= nil then say(message) end
end

-- Shared essential-world arrival deadline; failure stops construction before any motor exists. Decor is best effort.
WorldClient.PIECES_WAIT = 30
-- The focus report (ROBLOX-95): sent when the spider is more than this many studs from where it last reported, or this many seconds after the last report.
WorldClient.REPORT_MOVE = 8
WorldClient.REPORT_EVERY = 2
-- The name of the remote the server makes for the reports (Server/WorldFocus.REMOTE).
WorldClient.REMOTE = "WorldFocus"

-- ROBLOX-115: the world the server runs (World/Worlds) is the Workspace attribute World, which the server writes at startup; with no map handed in, the client makes
-- that world WorldMap's active one before it asks anything (with streaming, it waits up to WORLD_WAIT seconds for a known identity and fails if absent/unknown; without it, an absent attribute is
-- the default world, as in every test place).
WorldClient.WORLD_WAIT = 10
WorldClient.FAIL_ATTRIBUTE = "WorldStartupFailed"

-- `ws`: the workspace; `player`: the local player; `map`: the world map (WorldMap, unless a test hands in another with the same functions).
function WorldClient.new(ws: Instance, player: Instance, map: any?): any
 local streaming=(ws :: any).StreamingEnabled==true
 local function unavailable(what: string)
  pcall(function() player:SetAttribute(WorldClient.FAIL_ATTRIBUTE,true) end)
  error(`[Windowsill] world startup: {what} did not arrive; the simulation was not started`,0)
 end
	if map == nil then
		local named = ws:GetAttribute(Worlds.ATTRIBUTE)
		if not Worlds.known(named) and streaming then
			local deadline = os.clock() + WorldClient.WORLD_WAIT
			local t: any = task
			while not Worlds.known(named) and os.clock() < deadline and t ~= nil do
				t.wait(0.1)
				named = ws:GetAttribute(Worlds.ATTRIBUTE)
			end
		end
  if streaming and not Worlds.known(named) then unavailable("server world identity") end
		WorldMap.use(Worlds.choose(named))
	end
	local m: any = map or WorldMap
	local home = m.region(m.HOME) :: WorldMap.Region
	local lo, hi = m.bounds()
	local name = Region.folderName(home)
 -- One shared budget for all essential folders/pieces, not a fresh timeout per child.
 local deadline=os.clock()+WorldClient.PIECES_WAIT
 local function required(parent: Instance,childName: string): Instance
  local child=parent:FindFirstChild(childName)
  if child==nil then
   local remaining=deadline-os.clock()
   if remaining>0 then child=parent:WaitForChild(childName,remaining) end
  end
  if child==nil or child.Name~=childName then unavailable(childName) end
  return child :: Instance
 end
	local flat = ws:FindFirstChild(name)
	local root: Instance, sill: Instance
	if flat ~= nil then
		root, sill = flat, flat
	else
		root = required(ws,Region.WORLD_FOLDER)
		sill = required(root,name)
	end
	local decor = ws:FindFirstChild("Decor")
 -- Legacy flat box-world fixtures intentionally supply only their own geometry.
 -- A server-layout world (and every streamed world) must have its whole home.
 if streaming or root~=sill then
  for _,piece in Region.pieces(home) do
   local part=required(sill,piece.id)
   if not part:IsA("BasePart") then unavailable(piece.id.." collision part") end
  end
 end
 -- Optional visuals arrive independently; only essential collision gates startup.
 pcall(function() player:SetAttribute(WorldClient.FAIL_ATTRIBUTE,false) end)

	return setmetatable({
		map = m, player = player, workspace = ws, root = root, sill = sill, decor = decor, looks = nil :: any, -- (`looks`: the LookStream, once `streamLooks` makes it)
		home = home.id, region = home,
		boundsMin = lo, boundsMax = hi, spawnPos = home.spawn.pos, spawnHeading = home.spawn.heading,
		homeMin = home.bounds[1], homeMax = home.bounds[2],
		focused = nil :: Instance?, focusWarned = false,
		-- the focus report: the remote (found when first needed), where and when the last report was, how many were sent
		remote = nil :: Instance?, reported = nil :: Vector3?, reportedAt = -math.huge, reports = 0,
		-- the readiness guard: regions found whole, and regions already warned about
		whole = {} :: { [string]: boolean }, warned = {} :: { [string]: boolean },
  streaming=streaming,playerLoading=false,
		-- ROBLOX-96: the world's prey and the drawn bugs (set by the client), and the last retreat the spider was in or beside
		prey = nil :: any, bugs = nil :: any, lastRetreat = if #home.retreats > 0 then home.retreats[1].id else nil,
		world = if m.world ~= nil then m.world() else Worlds.DEFAULT, train = nil :: any, -- (ROBLOX-115: the world it is, and the preserve's train once the looks are made)
		hut = nil :: any, life = nil :: any, hutPending = false, -- (ROBLOX-116: the hut's sash and lamp in the preserve, the life the nursery rule reads, a save's open window before the hut is made)
		shadows = nil :: any, -- (ROBLOX-121: the walkable boxes' shadows kept to those an eye at the spider could see, Client/WorldShadows; made at the first update)
	}, WorldClient)
end

-- The retreat the words call home at this place (ROBLOX-96): the retreat the spider is in; else the first retreat of the region it is in; else the last one it was in
-- or beside. Remembers what it answers.
function WorldClient.homeRetreat(self: any, pos: Vector3): string?
	local inside = self.map.inRetreat(pos)
	if inside ~= nil then self.lastRetreat = inside; return inside end
	local region = self:regionAt(pos)
	if #region.retreats > 0 then self.lastRetreat = region.retreats[1].id; return region.retreats[1].id end
	return self.lastRetreat
end

-- Whether the spider is within `near` studs of the retreat's door (WorldMap's `door`, the point the line near home has always been measured from; its box's centre
-- for a retreat without one), for the line near home.
function WorldClient.nearRetreat(self: any, pos: Vector3, retreat: string?, near: number): boolean
	if retreat == nil or self.map.retreat == nil then return false end
	local t = self.map.retreat(retreat)
	if t == nil then return false end
	local door: Vector3 = t.door or (t.min + t.max) * 0.5
	return (pos - door).Magnitude < near
end

-- Whether the point is inside some region's bounds: the player's motor is out of the world only where no region holds it (SpiderMotor's `inBounds`), so a fall from the
-- sill's room side ends where it always did and a fall from the outer sill goes on down to the bed.
function WorldClient.inBounds(self: any, pos: Vector3): boolean
	return self.map.at(pos) ~= nil
end

-- The folder of a region's physical boxes, or nil while it has not arrived (a place with only the sill straight in the workspace has only the sill's).
function WorldClient.folderOf(self: any, region: WorldMap.Region): Instance?
	if region.id == self.home then return self.sill end
	if self.root == self.sill then return nil end
	return self.root:FindFirstChild(Region.folderName(region))
end

-- Whether every box of the region is here: its folder holds every piece of Region.pieces(region). With instance streaming the folders arrive at once and their parts as the
-- server sends them, so a region can be here in part; the sim must not raycast into it until it is whole. False for a region that is not on the map.
function WorldClient.regionReady(self: any, id: string): boolean
	local region = self.map.region(id)
	if region == nil then return false end
	local folder = self:folderOf(region)
	if folder == nil then return false end
	for _, piece in Region.pieces(region) do
		if folder:FindFirstChild(piece.id) == nil then return false end
	end
	return true
end

-- Player physics is held on missing authored collision, not on optional looks.
-- A previous whole flag is not authority after stream-out. Points outside all
-- authored regions retain the normal jump/fall/silk rules; flat legacy fixtures
-- intentionally provide only their own sill rather than the server's world.
local function playerRegionReady(self:any,pos:Vector3):boolean
 if self.root==self.sill and not self.streaming then return true end
 local region=self.map.at(pos)
 if region==nil or region.kind=="patch" or region.kind=="backdrop" then return true end
 local folder=self:folderOf(region)
 if self.root.Parent==nil or folder==nil or (folder~=self.root and not folder:IsDescendantOf(self.root)) then return false end
 return self:regionReady(region.id)
end
function WorldClient.playerCanAdvance(self:any,pos:Vector3,nextPosition:Vector3?):boolean
 local ready=playerRegionReady(self,pos)
 if ready and nextPosition and (nextPosition-pos).Magnitude>1e-6 then ready=playerRegionReady(self,nextPosition) end
 self.playerLoading=not ready
 return ready
end

-- Sends the server where the spider is (the WorldFocus remote), when it has moved more than REPORT_MOVE studs from the last report or REPORT_EVERY seconds have passed. True
-- when it sent one. Without the remote (a place whose server has not made it, the box worlds) nothing is sent.
function WorldClient.report(self: any, pos: Vector3, now: number): boolean
	local last = self.reported
	if last ~= nil and (pos - last).Magnitude <= WorldClient.REPORT_MOVE and now - self.reportedAt < WorldClient.REPORT_EVERY then return false end
	if self.remote == nil then self.remote = ReplicatedStorage:FindFirstChild(WorldClient.REMOTE) end
	local remote = self.remote
	if remote == nil or not remote:IsA("RemoteEvent") then return false end
	(remote :: RemoteEvent):FireServer(pos)
	self.reported, self.reportedAt = pos, now
	self.reports += 1
	return true
end

-- The id of the retreat the point is in, in any region, or nil.
function WorldClient.inRetreat(self: any, pos: Vector3): string?
	return self.map.inRetreat(pos)
end

-- The region the spider is in at this place; where it is in none (a frame on the way back from outside the bounds) the region it was last in.
function WorldClient.regionAt(self: any, pos: Vector3): WorldMap.Region
	return self.map.at(pos) or self.region
end

-- Whether the spider is in this region: whether what belongs to the region is in play.
function WorldClient.isActive(self: any, regionId: string): boolean
	return self.region.id == regionId
end

-- (ROBLOX-117) Whether a creature in this region is simulated now: a region with no id (the sill's rival and mate, as they have always been) always; a region of the
-- preserve's roam when the spider is in it or in a region that meets it, and its boxes have arrived (a creature walks only on what is streamed in; elsewhere it
-- waits where it is until the spider comes near).
function WorldClient.creatureLive(self: any, regionId: string?): boolean
	if regionId == nil then return true end
	-- Residents can cross either room while the player shelters elsewhere in the
	-- station. Its physical models are persistent; wait for every one before
	-- allowing a resident to plan beyond the player's streamed neighbourhood.
	if Station.contains(regionId) then
		if not self.stationWhole then
			for id in Station.roam() do if not self:regionReady(id) then return false end end
			self.stationWhole=true
		end
		return true
	end
	local here = self.region
	local near = here.id == regionId
	if not near then
		for _, n in here.neighbors do if n.id == regionId then near = true; break end end
	end
	if not near then return false end
	-- Non-station models are Atomic, not Persistent: a previously whole region
	-- can stream out and return partially. First arrival is not current authority.
	local ready = self:regionReady(regionId)
	self.whole[regionId] = if ready then true else nil
	return ready
end

-- (ROBLOX-117) The box a creature's motor keeps to: the union of the roam's regions (the preserve's rival and mate walk the whole hut garden), else the sill's.
function WorldClient.rangeOf(self: any, roam: { [string]: boolean }?): (Vector3, Vector3)
	if roam == nil then return self.homeMin, self.homeMax end
	local list = {}
	for id in roam do
		local r = self.map.region(id)
		if r ~= nil then table.insert(list, r) end
	end
	if #list == 0 then return self.homeMin, self.homeMax end
	return WorldMap.unionOf(list)
end

-- Points the player's replication focus at this part (the drawn spider's root), and remembers it. A write that raises is warned about once.
function WorldClient.focus(self: any, part: Instance?)
	self.focused = part
	if part == nil then return end
	local ok, err = pcall(function() (self.player :: any).ReplicationFocus = part end)
	if not ok and not self.focusWarned then
		self.focusWarned = true
		warn("[Windowsill] world: could not set the replication focus: " .. tostring(err))
	end
end

-- After a respawn or a return to a rest: the focus is set again at the next frame.
function WorldClient.refocus(self: any)
	self.focused = nil
end

-- ROBLOX-108: the looks of the regions outside the window, made on this client at its tier ("full" or "low") near the spider from now on (Client/LookStream; each
-- `update` follows the spider). In a place with only the sill straight in the workspace (the box worlds) there is nothing to draw and nothing is made.
function WorldClient.streamLooks(self: any, ws: Instance, tier: string): any
	self.decor = ws:FindFirstChild("Decor")
	if self.root == self.sill then return nil end
	self.looks = LookStream.new(ws, tier, self.root, self.map)
	-- (ROBLOX-115) in the preserve, the trains beyond the north fence, with the looks
	if self.world == Worlds.PRESERVE then self.train = TrainPass.new(self.looks.folder, WorldMap.seed(WorldMap.SEED, "train"), tier) end
	-- (ROBLOX-116) and the hut's sash and lamp
	if self.world == Worlds.PRESERVE then
		self.hut = HutLife.new(self.root, self.decor, WorldMap.seed(WorldMap.SEED, "hut_window"), ws)
		self.living = LivingWorld.new(ws, self.root, tier, self.map)
		if self.hutPending then self.hut:restore(true) end
	end
	return self.looks
end

-- Each frame, before the sim's ticks (`dt`, ROBLOX-116: the frame's seconds, for the hut's own moment): the region the spider is in, the pace of its day, the focus on the drawn spider's root (`root`) when it is not set on it yet, the
-- report of where it is to the server (`now`: os.clock() unless a test gives a clock), the looks near it (ROBLOX-108), the boxes' shadows (ROBLOX-121), and whether
-- the region it is in has arrived whole (warned about once if not). `nextPosition`
-- keeps the fixed-tick destination hold live even on a render without a tick.
function WorldClient.update(self: any, pos: Vector3, root: Instance?, now: number?, dt: number?, nextPosition: Vector3?)
	self.decor = self.workspace:FindFirstChild("Decor")
	if self.hut ~= nil then self.hut:bindDecor(self.decor) end
	self.region = self.map.at(pos) or self.region
	-- A render can contain no fixed tick. Keep a refused destination waiting on
	-- those frames too, rather than clearing the hold just because here is ready.
	self:playerCanAdvance(pos, nextPosition)
	LifeClock.game.clockScale = self.region.clockScale
	if root ~= nil and root ~= self.focused then self:focus(root) end
	local clock = now or os.clock()
	self:report(pos, clock)
	FrameProfile.lap("world")
	if self.looks ~= nil then
		self.looks:update(pos, self.region)
		-- (ROBLOX-117: the morning's dew on the looks, by the life's hour)
		local life = self.life
		if life ~= nil and type(life.clock) == "table" and type(life.clock.hour) == "number" then self.looks:dew(life.clock.hour) end
	end
	if self.train ~= nil then self.train:update(clock) end
	-- (ROBLOX-116: the hut's moment runs on the frames' own time when the client gives it, so it keeps the sim's pace; else on the clock)
	self.hutClock = (self.hutClock or 0) + (if dt ~= nil then dt else 0)
	if self.hut ~= nil then self.hut:update(self.life, if dt ~= nil then self.hutClock else clock) end
	FrameProfile.lap("looks") -- (ROBLOX-111: the self-test's frame profile, Client/FrameProfile)
	-- (ROBLOX-121: a box's shadow only where it could be seen from the spider; not in a place with only the sill straight in the workspace)
	if self.shadows == nil and self.root ~= self.sill then self.shadows = WorldShadows.new(self.root, self.map, self.home) end
	if self.shadows ~= nil then self.shadows:update(pos, clock) end
	FrameProfile.lap("shadows")
	local id = self.region.id
	if not self.whole[id] then
		if self:regionReady(id) then
			self.whole[id] = true
		elseif not self.warned[id] then
			self.warned[id] = true
			tell(`[Windowsill] world: the spider is in {id}, which has not arrived whole; player physics waits for collision to return`)
		end
	end
end

-- (ROBLOX-116) Whether the hut's window is open (the preserve's progress: false in the test garden).
function WorldClient.hutOpen(self: any): boolean
	if self.hut ~= nil then return self.hut.open == true and not self.hut.trial end -- (the self-test's trial opening is never kept)
	return self.hutPending == true
end

-- (ROBLOX-116) The save says the hut's window is open: it opens now, without the ranger's moment (and when the hut is made, if it is not yet).
function WorldClient.openHut(self: any)
	self.hutPending = true
	if self.hut ~= nil then self.hut:restore(true) end
end

return WorldClient
