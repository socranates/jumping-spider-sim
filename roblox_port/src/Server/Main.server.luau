--!strict
-- Builds the windowsill (scripts/habitat/windowsill.gd) and the macro-lens lighting. The spider itself is client-side
-- (StarterPlayerScripts/Client/SpiderClient): one player, one spider, nothing to replicate yet.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Habitat"):WaitForChild("WindowsillLayout"))
local Surfaces = require(Shared:WaitForChild("Data"):WaitForChild("Surfaces"))

Players.CharacterAutoLoads = false
Workspace.Gravity = 35 -- species gravity_wu_s2; used by any unanchored props

local MATERIAL: { [string]: Enum.Material } = {
	painted_wood_dry = Enum.Material.Wood,
	bare_wood_rough = Enum.Material.WoodPlanks,
	brick_rough = Enum.Material.Brick,
	leaf_dry_prototype = Enum.Material.SmoothPlastic,
}

local sill = Instance.new("Folder")
sill.Name = "Windowsill"
sill:SetAttribute("ContentRevision", Layout.CONTENT_REVISION)

for _, piece in Layout.PIECES do
	assert(Surfaces[piece.profile], "unknown surface profile " .. piece.profile)
	local p = Instance.new("Part")
	p.Name = piece.id
	p.Anchored = true
	p.Size = piece.hi - piece.lo
	p.Position = (piece.lo + piece.hi) * 0.5
	p.Color = piece.color
	p.Material = MATERIAL[piece.profile] or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("SurfaceId", piece.id)
	p:SetAttribute("ProfileId", piece.profile)
	p.Parent = sill
end

local decorFolder = Instance.new("Folder")
decorFolder.Name = "Decor"
for _, d in Layout.DECOR do
	local p = Instance.new("Part")
	p.Name = d.id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- drawn only: the spider's rays never see it
	p.CanTouch = false
	p.Size = d.size
	p.Position = d.at
	p.Color = d.color
	p.Material = if d.id == "window_glass" then Enum.Material.Glass elseif d.id == "soil" then Enum.Material.Ground else Enum.Material.SmoothPlastic
	p.Transparency = d.transparency or 0
	p.CastShadow = d.id ~= "window_glass"
	p.Parent = decorFolder
end

-- Dust motes drifting in the window light (drawn only).
local dust = Instance.new("Part")
dust.Name = "DustVolume"
dust.Anchored = true
dust.CanCollide = false
dust.CanQuery = false
dust.CanTouch = false
dust.Transparency = 1
dust.Size = Vector3.new(56, 11, 22)
dust.Position = Vector3.new(0, 6.1, -1)
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/smoke_main.dds"
motes.Rate = 5
motes.Lifetime = NumberRange.new(14, 18)
motes.Speed = NumberRange.new(0.05, 0.2)
motes.SpreadAngle = Vector2.new(180, 180)
motes.Size = NumberSequence.new(0.05)
motes.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.55),
	NumberSequenceKeypoint.new(0.8, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
motes.LightEmission = 0.6
motes.LightInfluence = 0.4
motes.Color = ColorSequence.new(Color3.fromRGB(255, 238, 205))
motes.Drag = 0.5
motes.Acceleration = Vector3.new(0, 0.01, 0)
motes.Shape = Enum.ParticleEmitterShape.Box
motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
motes.Parent = dust
dust.Parent = decorFolder

decorFolder.Parent = Workspace
sill.Parent = Workspace

-- Macro-lens lighting: morning sun through the window, soft shadows, warm grade, a shallow depth of field
-- (the client keeps the focus on the spider).
-- Technology is authored in the Rojo place; runtime scripts cannot set it.
Lighting.ClockTime = 9.6
Lighting.GeographicLatitude = 40.7
Lighting.Brightness = 2.6
Lighting.Ambient = Color3.fromRGB(70, 66, 58)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 146, 132)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.ShadowSoftness = 0.12
Lighting.ExposureCompensation = 0.1

local function effect(className: string, name: string): Instance
	local e = Lighting:FindFirstChild(name) or Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e
end
local cc = effect("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
cc.Contrast = 0.06
cc.Saturation = 0.04
cc.TintColor = Color3.fromRGB(255, 248, 236)
local bloom = effect("BloomEffect", "Bloom") :: BloomEffect
bloom.Intensity = 0.3
bloom.Size = 18
bloom.Threshold = 1.6
local rays = effect("SunRaysEffect", "SunRays") :: SunRaysEffect
rays.Intensity = 0.06
rays.Spread = 0.7
local dof = effect("DepthOfFieldEffect", "MacroDOF") :: DepthOfFieldEffect
dof.FarIntensity = 0.55
dof.NearIntensity = 0.35
dof.FocusDistance = 6
dof.InFocusRadius = 3.5
