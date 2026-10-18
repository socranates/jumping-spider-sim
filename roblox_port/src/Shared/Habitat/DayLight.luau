--!strict
-- The light of the hour on the sill (ROBLOX-24, after Godot's LIFE-06 set_daylight): the life clock's daylight, 0 (night) to 1
-- (day), blends the daytime lighting of Data/Graphics toward Graphics.dayNight. Pure apart from `apply`, so tests/life.luau
-- checks it without an engine.
--   * Full daylight is exactly the daytime look (Lit.apply's values, and SunPick's through-the-window clock).
--   * The sun: dusk runs the picked morning backwards toward dayNight.nightClock (before sunrise), so the sun sinks on the
--     window's side and the sky turns to night; dawn runs it forwards again.
--   * The room's light, the haze, the sun rays, the light shafts and the dust motes dim with it; a low sun is warmer
--     (Godot: the sun's colour whitens by daylight 0.6).
-- The light is only what the screen shows. How far the spider sees comes from the clock (LifeLoop.rangeScale), never from here.
-- It owns: Lighting's ClockTime, Brightness, Ambient, OutdoorAmbient, ColorShift_Top and ExposureCompensation; the Atmosphere's
-- Color and Decay; SunRays.Intensity; the Shafts beams' Brightness and Enabled; the Motes' Brightness; and (ROBLOX-74, applyDew) the
-- Transparency of the morning dew's drops. Never the eye view's effects (EyeGrade, EyeBlur, MacroDOF: SpiderEyes) or the world's Grade.
local Graphics = require(script.Parent.Parent.Data.Graphics)
local Flora = require(script.Parent.Parent.Data.Flora)

local DayLight = {}

export type Targets = {
	daylight: number, clock: number, brightness: number, exposure: number,
	ambient: { number }, outdoorAmbient: { number }, colorShiftTop: { number },
	atmosphereColor: { number }, atmosphereDecay: { number },
	sunRays: number, shafts: number, motes: number,
}

local function mix(night: number, day: number, t: number): number
	if t >= 1 then return day end
	if t <= 0 then return night end
	return night + (day - night) * t
end

local function mixRgb(night: { number }, day: { number }, t: number): { number }
	return { mix(night[1], day[1], t), mix(night[2], day[2], t), mix(night[3], day[3], t) }
end

local function smoothstep(from: number, to: number, x: number): number
	local s = math.clamp((x - from) / (to - from), 0, 1)
	return s * s * (3 - 2 * s)
end

-- What every light should be at `daylight` (clamped to [0, 1]). `dayClock` is the ClockTime of the day (SunPick's choice).
function DayLight.targets(daylight: number, dayClock: number): Targets
	local d = math.clamp(if daylight == daylight then daylight else 1, 0, 1)
	local L, N, A = Graphics.lighting, Graphics.dayNight, Graphics.atmosphere
	return {
		daylight = d,
		clock = mix(N.nightClock, dayClock, d),
		brightness = mix(N.brightness, L.brightness, d),
		exposure = mix(N.exposureCompensation, L.exposureCompensation, d),
		ambient = mixRgb(N.ambient, L.ambient, d),
		outdoorAmbient = mixRgb(N.outdoorAmbient, L.outdoorAmbient, d),
		colorShiftTop = mixRgb(N.lowSunColorShiftTop, L.colorShiftTop, smoothstep(0, N.warmFrom, d)),
		atmosphereColor = mixRgb(N.atmosphereColor, A.color, d),
		atmosphereDecay = mixRgb(N.atmosphereDecay, A.decay, d),
		sunRays = Graphics.sunRays.intensity * d,
		shafts = d,
		motes = mix(N.motesAtNight, 1, d),
	}
end

-- Whether the light needs setting again: it changed by applyStep, or it reached night or day.
function DayLight.due(last: number?, daylight: number): boolean
	if last == nil then return true end
	if daylight ~= last and (daylight <= 0 or daylight >= 1) then return true end
	return math.abs(daylight - last) >= Graphics.dayNight.applyStep
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(math.floor(t[1] + 0.5), math.floor(t[2] + 0.5), math.floor(t[3] + 0.5))
end

-- Sets the lights. `decor` is Workspace.Decor (for the shafts and the motes), when it exists. Anything missing (the low tier
-- has no sun rays or shafts) is skipped.
function DayLight.apply(lighting: any, t: Targets, decor: Instance?)
	lighting.ClockTime = t.clock
	lighting.Brightness = t.brightness
	lighting.ExposureCompensation = t.exposure
	lighting.Ambient = rgb(t.ambient)
	lighting.OutdoorAmbient = rgb(t.outdoorAmbient)
	lighting.ColorShift_Top = rgb(t.colorShiftTop)
	local atmosphere = lighting:FindFirstChild("Atmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Color = rgb(t.atmosphereColor)
		atmosphere.Decay = rgb(t.atmosphereDecay)
	end
	local rays = lighting:FindFirstChild("SunRays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Intensity = t.sunRays
	end
	if decor then
		local shafts = decor:FindFirstChild("Shafts")
		if shafts then
			for _, b in shafts:GetDescendants() do
				if b:IsA("Beam") then
					b.Brightness = t.shafts
					b.Enabled = t.shafts > 0.01
				end
			end
		end
		local motes = decor:FindFirstChild("Motes", true)
		if motes and motes:IsA("ParticleEmitter") then
			motes.Brightness = t.motes
		end
	end
end

-- ---------------------------------------------------------------- the morning dew (ROBLOX-74)
-- How much dew there is at an hour of the day (0 to 1): it gathers through the night from Flora.dew.formFrom (20:00) to fullBy (05:00),
-- holds until burnFrom (07:30) and is gone by goneBy (09:30), smoothly. It follows the hour, not the daylight, which is already full by 08:00.
function DayLight.dewAt(hour: number): number
	if hour ~= hour or hour == math.huge or hour == -math.huge then return 0 end
	local D = Flora.dew
	local h = hour % 24
	if h >= D.goneBy and h < D.formFrom then return 0 end
	if h >= D.burnFrom and h < D.goneBy then return 1 - smoothstep(D.burnFrom, D.goneBy, h) end
	return smoothstep(D.formFrom, D.fullBy + 24, if h >= D.formFrom then h else h + 24)
end

-- Sets the dew for `hour` on Workspace.Decor's folder "Dew" (Habitat/Dressing): each drop is shown from its Lag (the share of the dew at
-- which it appears) to full at a dew of 1, with the transparency Base it carries. Nothing is touched unless the dew changed by Flora.dew.step
-- (or reached 0 or 1); the last level is kept in the folder's attribute Level, so no one else holds state. Returns whether it set the drops.
function DayLight.applyDew(decor: Instance?, hour: number): boolean
	local dew = if decor then decor:FindFirstChild("Dew") else nil
	if not dew then return false end
	local level = DayLight.dewAt(hour)
	local last = dew:GetAttribute("Level")
	if type(last) == "number" then
		if last == level then return false end
		if level > 0 and level < 1 and math.abs(level - last) < Flora.dew.step then return false end
	end
	dew:SetAttribute("Level", level)
	for _, drop in dew:GetDescendants() do
		local lag, base = drop:GetAttribute("Lag"), drop:GetAttribute("Base")
		if drop:IsA("BasePart") and type(lag) == "number" and type(base) == "number" then
			local seen = math.clamp((level - lag) / (1 - lag), 0, 1)
			drop.Transparency = 1 - seen * (1 - base)
		end
	end
	return true
end

return DayLight
