--!strict
-- The client's side of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). The spider, the flies, the wasp, the rival and the mate are all simulated here, on this
-- client, as they always were; what this module knows is the world they live in:
--   where the boxes are ... `root`, the folder every ray of the sim includes (the motor, the senses, the flies' perches, the rig's feet): the server's `World` folder, with a folder
--                            for every region. `sill`, region 0's folder inside it, for what is the sill's alone (the leaf tip). A place with only the sill straight in the workspace
--                            (the test box worlds, the old places) still works: both are that folder.
--   which region we are in .. from the spider's place each frame, kept when it is momentarily in none (`region`); the pace of its day (`clockScale`, set on LifeClock's dial each
--                            frame); and `isActive`, which says whether a creature that belongs to a region is in the region the spider is in. The creatures are regional
--                            (Predator/RivalSpider, Mate and RivalDrive take their region, the sill's unless given); nothing is sent to sleep yet because there is nowhere else to go.
--   what to stream .......... with instance streaming on, the server sends what is near the player's replication focus. The server parks each player's (Server/WorldFocus): that
--                            is the focus streaming follows. This also points the player's own ReplicationFocus at the drawn spider's root, when it is made and again after a respawn
--                            or a return to a rest: a client's write of that property is not expected to reach the server (the docs say to set it there), so it is belt and braces,
--                            not the mechanism; a write that raises is warned about once and the game goes on. None of this has run in Studio yet.
-- The sim must never raycast beyond what is streamed in: StreamingMinRadius (96 studs around the focus) is always there, so a region and its neighbours must fit inside it, and a
-- creature is only simulated in the region the spider is in or beside. The sill, the only region now, is inside it from every spot on it.
-- With streaming, the sill's boxes and the drawn sill (the persistent Decor model) arrive after the folders do: `new` waits for every box of the sill and for the Decor, so the
-- sim begins on a whole sill. Without streaming (the test places, the box worlds) everything is there at once and nothing is waited for.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))
local LifeClock = require(Shared:WaitForChild("Life"):WaitForChild("LifeClock"))

local WorldClient = {}
WorldClient.__index = WorldClient

-- How long, in seconds, the sill may take to arrive under streaming before the sim begins without a missing piece (and says so), and the decor may.
WorldClient.PIECES_WAIT = 30
WorldClient.DECOR_WAIT = 10

-- `ws`: the workspace; `player`: the local player; `map`: the world map (WorldMap, unless a test hands in another with the same functions).
function WorldClient.new(ws: Instance, player: Instance, map: any?): any
	local m: any = map or WorldMap
	local home = m.region(m.HOME) :: WorldMap.Region
	local lo, hi = m.bounds()
	local name = Region.folderName(home)
	local flat = ws:FindFirstChild(name)
	local root: Instance, sill: Instance
	if flat ~= nil then
		root, sill = flat, flat
	else
		root = ws:WaitForChild(Region.WORLD_FOLDER)
		sill = root:WaitForChild(name)
	end
	local decor = ws:FindFirstChild("Decor")
	if (ws :: any).StreamingEnabled == true then
		local deadline = os.clock() + WorldClient.PIECES_WAIT
		for _, piece in Region.pieces(home) do
			if sill:FindFirstChild(piece.id) == nil and sill:WaitForChild(piece.id, math.max(0.1, deadline - os.clock())) == nil then
				warn(`[Windowsill] world: the sill's {piece.id} never streamed in; the spider may fall through where it should be`)
			end
		end
		if decor == nil then decor = ws:WaitForChild("Decor", WorldClient.DECOR_WAIT) end
	end
	return setmetatable({
		map = m, player = player, root = root, sill = sill, decor = decor,
		home = home.id, region = home,
		boundsMin = lo, boundsMax = hi, spawnPos = home.spawn.pos, spawnHeading = home.spawn.heading,
		focused = nil :: Instance?, focusWarned = false,
	}, WorldClient)
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

-- Each frame, before the sim's ticks: the region the spider is in, the pace of its day, and the focus on the drawn spider's root (`root`) when it is not set on it yet.
function WorldClient.update(self: any, pos: Vector3, root: Instance?)
	self.region = self.map.at(pos) or self.region
	LifeClock.game.clockScale = self.region.clockScale
	if root ~= nil and root ~= self.focused then self:focus(root) end
end

return WorldClient
