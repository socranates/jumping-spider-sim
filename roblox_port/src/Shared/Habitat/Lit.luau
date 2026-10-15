--!strict
-- The lighting, sky and screen effects (Data/Graphics): a soft warm sun picked by SunPick so that it shines in through the
-- window, Atmosphere haze for the view, a gentle bloom, grade and sun rays, clouds, and (full tier) a macro depth of field that
-- keeps the sill sharp and melts the garden outside the window. Depth of field is only added when asked for (Server/Main asks
-- for it unless the Workspace attribute DepthOfField is false).
-- Technology (Future) cannot be set from a script; the Rojo projects author it. Idempotent: effects are reused by name.
local Graphics = require(script.Parent.Parent.Data.Graphics)
local SunPick = require(script.Parent.SunPick)

local Lit = {}

export type Options = {
	sample: ((number, number) -> Vector3)?, -- the sun at (clock, latitude); default: ask the Lighting service
	depthOfField: boolean?, -- true adds the macro depth of field (full tier) that the client keeps focused on the spider
}

local L = Graphics.lighting

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- The child of `parent` with this name and class, made if missing (a wrong class under that name is replaced).
local function child(parent: Instance, className: string, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found and found.ClassName == className then return found end
	if found then found:Destroy() end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

function Lit.apply(lighting: Lighting, terrain: Instance?, options: Options?): SunPick.Result
	local opts: Options = options or {}
	lighting.Brightness = L.brightness
	lighting.Ambient = rgb(L.ambient)
	lighting.OutdoorAmbient = rgb(L.outdoorAmbient)
	lighting.ColorShift_Top = rgb(L.colorShiftTop)
	lighting.EnvironmentDiffuseScale = L.environmentDiffuse
	lighting.EnvironmentSpecularScale = L.environmentSpecular
	lighting.ShadowSoftness = L.shadowSoftness
	lighting.ExposureCompensation = L.exposureCompensation
	lighting.GlobalShadows = true

	-- A sun that comes in through the window; if none can be found the old morning light stays.
	local sample = opts.sample or function(clock: number, latitude: number): Vector3
		lighting.GeographicLatitude = latitude
		lighting.ClockTime = clock
		return lighting:GetSunDirection()
	end
	local picked: SunPick.Result? = nil
	local ok, outcome = pcall(function(): SunPick.Result
		return SunPick.choose(sample, L.clockTime, L.latitude, Graphics.sun)
	end)
	if ok then picked = outcome :: any end
	local sun: SunPick.Result = picked or {
		ok = false, clock = L.clockTime, latitude = L.latitude, direction = Vector3.new(0, 1, 0),
		elevationDeg = 90, azimuthDeg = 0, reason = "the sun could not be sampled",
	}
	lighting.ClockTime = sun.clock
	lighting.GeographicLatitude = sun.latitude
	lighting:SetAttribute("SunPick", (if sun.ok then "ok: " else "fallback: ") .. sun.reason)

	local A = Graphics.atmosphere
	local atmosphere = child(lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = A.density
	atmosphere.Offset = A.offset
	atmosphere.Color = rgb(A.color)
	atmosphere.Decay = rgb(A.decay)
	atmosphere.Glare = A.glare
	atmosphere.Haze = A.haze

	local S = Graphics.sky
	local sky = child(lighting, "Sky", "Sky") :: Sky
	sky.SunAngularSize = S.sunAngularSize
	sky.MoonAngularSize = S.moonAngularSize
	sky.StarCount = S.starCount
	sky.CelestialBodiesShown = true

	local G = Graphics.grade
	local grade = child(lighting, "ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	grade.Contrast = G.contrast
	grade.Saturation = G.saturation
	grade.Brightness = G.brightness
	grade.TintColor = rgb(G.tint)

	local B = Graphics.bloom
	local bloom = child(lighting, "BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = B.intensity
	bloom.Size = B.size
	bloom.Threshold = B.threshold
	bloom:SetAttribute("FullOnly", true)

	local R = Graphics.sunRays
	local rays = child(lighting, "SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = R.intensity
	rays.Spread = R.spread
	rays:SetAttribute("FullOnly", true)

	local stale = lighting:FindFirstChild("MacroDOF")
	if opts.depthOfField then
		local D = Graphics.depthOfField
		local dof = child(lighting, "DepthOfFieldEffect", "MacroDOF") :: DepthOfFieldEffect
		dof.FarIntensity = D.far
		dof.NearIntensity = D.near
		dof.FocusDistance = D.focus
		dof.InFocusRadius = D.radius
		dof:SetAttribute("FullOnly", true) -- phones and tablets go without it (Client/WorldDetail)
	elseif stale then
		stale:Destroy()
	end

	if terrain then
		local C = Graphics.clouds
		local clouds = child(terrain, "Clouds", "Clouds") :: Clouds
		clouds.Cover = C.cover
		clouds.Density = C.density
		clouds.Color = rgb(C.color)
		clouds:SetAttribute("FullOnly", true)
	end
	return sun
end

return Lit
