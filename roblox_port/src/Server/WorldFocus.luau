--!strict
-- Where the server streams the world to (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). With Workspace.StreamingEnabled the server sends each client only the instances around
-- that client's replication focus, and decides it on the server: Player.AddReplicationFocus is documented as server-only, and a property written by a client script is not heard
-- by the server. A player here has no character (CharacterAutoLoads is off; the spider is the client's own, SpiderRig), so there is no default focus to rely on: each player
-- gets a small invisible anchored part, the focus part, and the server makes it that player's ReplicationFocus. It is parked at the home region's spawn when the player joins.
-- ROBLOX-95: the spider can leave the sill, and the bed under the window is about 115 studs from that spawn, past StreamingMinRadius (96): so the part follows the spider. The
-- client reports where its spider is through a RemoteEvent the server makes at startup (ReplicatedStorage.WorldFocus, `listen`), when it has moved more than 8 studs since its
-- last report or 2 seconds have passed (Client/WorldClient); the server checks each report (`report`: a finite Vector3 inside the world's bounds, and no more than about ten
-- a second from a player; anything else is ignored) and moves the part there. The client also points its own ReplicationFocus at the rig's root, which can only help.
local WorldMap = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("World"):WaitForChild("WorldMap"))

local WorldFocus = {}

-- The name of the RemoteEvent in ReplicatedStorage the client reports on.
WorldFocus.REMOTE = "WorldFocus"
-- The fewest seconds between two reports of a player the server acts on (about ten a second); a report sooner than that after the last one acted on is ignored.
WorldFocus.MIN_INTERVAL = 0.09

local SIZE = 0.2

local function partName(player: Player): string
	return "ReplicationFocus_" .. tostring(player.UserId)
end

-- A focus part for the player under `parent`, at `at`, made the player's ReplicationFocus. Returns the part. A player who has one already keeps it where it is.
function WorldFocus.park(player: Player, parent: Instance, at: Vector3): Part
	local existing = parent:FindFirstChild(partName(player))
	if existing ~= nil and existing:IsA("Part") then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = partName(player)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * SIZE
	part.Position = at
	part.Parent = parent
	player.ReplicationFocus = part
	return part
end

-- Moves the player's focus part (a report that passed `report`'s checks). False if the player has none.
function WorldFocus.move(player: Player, parent: Instance, to: Vector3): boolean
	local part = parent:FindFirstChild(partName(player))
	if part == nil or not part:IsA("Part") then return false end
	part.Position = to
	return true
end

-- Takes the player's focus part away (the player has left).
function WorldFocus.release(player: Player, parent: Instance)
	local part = parent:FindFirstChild(partName(player))
	if part ~= nil then part:Destroy() end
end

-- Whether a reported value is a point the server may move a focus to: a Vector3 (the engine's own type; a table sent through the remote is not one), every
-- component finite, inside the world's bounds (WorldMap.bounds, edges included).
function WorldFocus.valid(at: any): boolean
	local meta: any = getmetatable
	if typeof(at) ~= "Vector3" and not (type(at) == "table" and meta(at) ~= nil and meta(at) == meta(Vector3.zero)) then return false end -- (the second: the CLI shim's Vector3)
	local x, y, z = at.X, at.Y, at.Z
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return false end
	if x ~= x or y ~= y or z ~= z or math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then return false end
	local lo, hi = WorldMap.bounds()
	return x >= lo.X and x <= hi.X and y >= lo.Y and y <= hi.Y and z >= lo.Z and z <= hi.Z
end

local lastReport: { [Player]: number } = {}

-- A report from a player's client: where its spider is. Moves the player's focus part there and returns true, or ignores it (false) if the value is not a point
-- inside the world or the player reported less than MIN_INTERVAL seconds ago (`now`: the server's clock, os.clock() unless a test gives one).
function WorldFocus.report(player: Player, parent: Instance, at: any, now: number?): boolean
	if not WorldFocus.valid(at) then return false end
	local t = now or os.clock()
	local last = lastReport[player]
	if last ~= nil and t - last < WorldFocus.MIN_INTERVAL then return false end
	if not WorldFocus.move(player, parent, at :: Vector3) then return false end
	lastReport[player] = t
	return true
end

-- Makes the RemoteEvent the clients report on (ReplicatedStorage.WorldFocus) and moves each player's focus part on its reports. Returns the remote.
function WorldFocus.listen(storage: Instance, parent: Instance): RemoteEvent
	local remote = storage:FindFirstChild(WorldFocus.REMOTE)
	if remote == nil or not remote:IsA("RemoteEvent") then
		local made = Instance.new("RemoteEvent")
		made.Name = WorldFocus.REMOTE
		made.Parent = storage
		remote = made
	end
	local event = remote :: RemoteEvent
	event.OnServerEvent:Connect(function(player: Player, at: any)
		WorldFocus.report(player, parent, at)
	end)
	return event
end

-- A focus for every player now in the game and every one who comes, and the part gone when one leaves. `players` is the Players service.
function WorldFocus.watch(players: Players, parent: Instance, at: Vector3)
	for _, player in players:GetPlayers() do
		WorldFocus.park(player, parent, at)
	end
	players.PlayerAdded:Connect(function(player: Player)
		WorldFocus.park(player, parent, at)
	end)
	players.PlayerRemoving:Connect(function(player: Player)
		WorldFocus.release(player, parent)
		lastReport[player] = nil
	end)
end

return table.freeze(WorldFocus)
