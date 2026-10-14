--!strict
-- Builds the windowsill (scripts/habitat/windowsill.gd), the drawn world around it (Habitat/Scenery, from Data/Graphics) and the
-- lighting (Habitat/Lit). The spider itself is client-side (StarterPlayerScripts/Client/SpiderClient): one player, one spider,
-- nothing to replicate yet. Lighting Technology (Future) and MaterialService.Use2022Materials are authored in the Rojo projects;
-- runtime scripts cannot set them.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Habitat = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habitat")
local Scenery = require(Habitat:WaitForChild("Scenery"))
local Lit = require(Habitat:WaitForChild("Lit"))

Players.CharacterAutoLoads = false
Workspace.Gravity = 35 -- species gravity_wu_s2; used by any unanchored props

-- Lighting first: the light shafts follow the sun it picks. Depth of field is opt-in (Workspace attribute DepthOfField).
local sun = Lit.apply(Lighting, Workspace:FindFirstChild("Terrain"), { depthOfField = Workspace:GetAttribute("DepthOfField") == true })
print("[Windowsill] sun: " .. (if sun.ok then "through the window, " else "fallback, ") .. sun.reason)

local sill = Scenery.sill()
local decor = Scenery.decor(if sun.ok then sun.direction else nil)
decor.Parent = Workspace
sill.Parent = Workspace
