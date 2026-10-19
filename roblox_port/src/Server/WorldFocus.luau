--!strict
-- Where the server streams the world to (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). With Workspace.StreamingEnabled the server sends each client only the instances around
-- that client's replication focus, and decides it on the server: Player.AddReplicationFocus is documented as server-only, and a property written by a client script is not heard
-- by the server. A player here has no character (CharacterAutoLoads is off; the spider is the client's own, SpiderRig), so there is no default focus to rely on: each player
-- gets a small invisible anchored part, the focus part, and the server makes it that player's ReplicationFocus. It is parked at the home region's spawn for as long as the
-- world is the sill and the regions around it (everything the spider can reach is inside StreamingMinRadius of it). The round that lets the spider leave the sill moves it with
-- the spider (the client reports where it is; WorldFocus.move). The client also points its own ReplicationFocus at the rig's root (Client/WorldClient), which can only help.
local WorldFocus = {}

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

-- Moves the player's focus part (nothing calls this yet: the spider does not leave the sill). False if the player has none.
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
	end)
end

return table.freeze(WorldFocus)
