--!strict
-- Builds the world: the windowsill (scripts/habitat/windowsill.gd) as region 0 of the map (World/WorldBuild, ROBLOX-94: every region's physical boxes under one `World`
-- folder), the drawn world around it (Habitat/Scenery, from Data/Graphics) and the lighting (Habitat/Lit). The spider itself is client-side
-- (StarterPlayerScripts/Client/SpiderClient): one player, one spider, nothing to replicate yet but where the server streams the world to (Server/WorldFocus).
-- Lighting Technology (Future), MaterialService.Use2022Materials and the Workspace's streaming settings are authored in the Rojo projects; runtime scripts cannot set them.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Habitat = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habitat")
local Scenery = require(Habitat:WaitForChild("Scenery"))
local Lit = require(Habitat:WaitForChild("Lit"))
local World = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World")
local WorldMap = require(World:WaitForChild("WorldMap"))
local WorldBuild = require(World:WaitForChild("WorldBuild"))
local WorldFocus = require(script.Parent.WorldFocus)

Players.CharacterAutoLoads = false
Workspace.Gravity = 35 -- species gravity_wu_s2; used by any unanchored props

-- The sill is what the game needs; the looks are best effort. If the lighting or the decor fails (nothing here has run in Roblox
-- Studio yet), the server says so and carries on with the old look: a visible back wall, the plain morning light.
-- Lighting first: the light shafts follow the sun it picks. The macro depth of field is on (full tier) unless the Workspace
-- attribute DepthOfField is false.
local litOk, sun = pcall(Lit.apply, Lighting, Workspace:FindFirstChild("Terrain"), { depthOfField = Workspace:GetAttribute("DepthOfField") ~= false })
if litOk then
	print("[Windowsill] sun: " .. (if sun.ok then "through the window, " else "fallback, ") .. sun.reason)
else
	warn("[Windowsill] lighting set-up failed: " .. tostring(sun))
end

local decorOk, decor, replaced = pcall(Scenery.decor, if litOk and sun.ok then sun.direction else nil)
if not decorOk then
	warn("[Windowsill] decor failed, the back wall and the Pilea's pieces stay as they were: " .. tostring(decor))
end

-- Only the pieces whose drawing exists turn invisible (still solid); if the decor failed nothing is hidden. The sill is region 0 of the world: its "Windowsill" folder, exactly
-- as it was, now inside the `World` folder with every other region's.
if decorOk then decor.Parent = Workspace end
WorldBuild.world(Workspace, WorldMap.SEED, if decorOk then replaced else {})

-- With instance streaming on (Workspace.StreamingEnabled, authored in default.project.json) the server sends a client what is near its replication focus, and a player here
-- has no character to be the focus: each gets a small invisible part, parked at the home region's spawn (Server/WorldFocus).
local foci = Instance.new("Folder")
foci.Name = "ReplicationFoci"
foci.Parent = Workspace
local home = WorldMap.region(WorldMap.HOME) :: WorldMap.Region
WorldFocus.watch(Players, foci, home.spawn.pos + Vector3.new(0, 0.31, 0))
