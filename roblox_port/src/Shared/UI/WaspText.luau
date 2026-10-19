--!strict
-- The words of the wasp's visit for the screen (ROBLOX-26): the sound captions, the status line while it visits and the plain screen
-- after a catch. The texts are Godot's (scripts/habitat/habitat_loop.gd _wasp_line, scripts/audio/soundscape.gd WASP_CAPTIONS,
-- scripts/presentation/caught_panel.gd); where they differ it is said here. Button names come from ControlText for the device in use.
-- Pure: checked in tests/wasp.luau.
--
-- Differences from Godot: the captions say where the hum is, as the flies' "[buzzing, ahead-left]" does (Godot's wasp captions did
-- not); the second line after a catch does not point to a notebook, which the port does not have yet; with no rest to go back to the
-- one choice is "Back to the start"; with one, the screen also offers another spider as a new life (the client's presentEnd, ROBLOX-91: the sac and the generation are left behind).
local ControlText = require(script.Parent.ControlText)
local Data = require(script.Parent.Parent.Data.Wasp)

local WaspText = {}

WaspText.LINE = "A mud dauber wasp stung the spider and carried it away."
WaspText.SUB = "Its sting does not kill: it paralyses."
WaspText.RIVAL_TAKEN = "The wasp seized the other spider and carried it off. It is gone for today."
WaspText.BACK = "Back to your last rest"
WaspText.START = "Back to the start"

local NAMES = { "ahead", "ahead-left", "left", "behind-left", "behind", "behind-right", "right", "ahead-right" }

local function roundHalfAway(x: number): number
	return if x >= 0 then math.floor(x + 0.5) else -math.floor(-x + 0.5)
end

-- Where `point` is from the spider (Godot VibrationSense.direction_word): the eighth of the compass round its heading, counted
-- counter-clockwise seen from its up, then "above" or "below" when it is more than 35 degrees off the plane the spider stands on.
function WaspText.directionWord(spider: Vector3, heading: Vector3, up: Vector3, point: Vector3): string
	local n = up
	local to = point - spider
	local rise = to:Dot(n)
	local flat = to - n * rise
	local word = ""
	if flat:Dot(flat) > 1.0e-6 then
		local f = flat.Unit
		local angle = math.deg(math.atan2(n:Dot(heading:Cross(f)), heading:Dot(f)))
		word = NAMES[(roundHalfAway(angle / 45.0) % 8) + 1]
	end
	local elevation = math.deg(math.atan2(rise, math.max(flat.Magnitude, 1.0e-6)))
	if elevation > 35.0 then
		word = if word == "" then "above" else "above, " .. word
	elseif elevation < -35.0 then
		word = if word == "" then "below" else "below, " .. word
	end
	return if word ~= "" then word else "here"
end

-- The caption of the visit now: { text, alpha }, or nil when there is none. While it arrives (the whole warning), when it has seen the
-- spider (inspecting, striking), and for a few seconds as it leaves. None begins "[buzzing", which is the flies'.
function WaspText.caption(phase: string, phaseS: number, direction: string): { text: string, alpha: number }?
	if phase == "arriving" then
		return { text = `[a deep, heavy hum outside, {direction}, coming closer]`, alpha = 1.0 }
	elseif phase == "inspecting" or phase == "striking" then
		return { text = `[the deep hum turns toward you, {direction}]`, alpha = 1.0 }
	elseif phase == "taking" or phase == "seizing" then
		-- (The wasp going for the rival male, ROBLOX-70; the host shows these only when it is near, WaspText.heardRival.)
		return { text = `[the deep hum drops toward something on the sill, {direction}]`, alpha = 1.0 }
	elseif phase == "bearing" then
		return { text = `[a short scuffle, then the deep hum rising away with something, {direction}]`, alpha = 1.0 }
	elseif phase == "leaving" and phaseS < Data.captionTailS then
		local left = Data.captionTailS - phaseS
		return { text = `[the deep hum fades away, {direction}]`, alpha = math.clamp(left / Data.captionFadeS, 0.0, 1.0) }
	end
	return nil
end

-- Whether the player hears or sees the wasp take the rival: it is within earshot of the spider, or in clear sight of it (`seen`) and not too far.
function WaspText.heardRival(distance: number, seen: boolean): boolean
	return distance <= Data.rival.earshotWu or (seen and distance <= Data.rival.sightWu)
end

-- What the status says while the wasp visits (nil when it is away). The first visit says what wasps do and how to get away.
function WaspText.line(phase: string, confused: boolean, visits: number, spared: boolean, device: ControlText.Device): string?
	if phase == "arriving" then
		if visits <= 1 then
			return `A deep hum outside: a wasp is coming, and wasps hunt spiders. Hide in the crack, keep still, or let yourself down on your line ({ControlText.name(device, "drop")}).`
		end
		return "A deep hum outside: a wasp is coming. Hide in the crack, keep still, or drop on your line."
	elseif phase == "searching" then
		if confused then return "The wasp has lost you. Get out of sight." end
		return "A wasp is searching the sill. Keep still, keep out of sight, or get home to the crack."
	elseif phase == "inspecting" or phase == "striking" then
		return "The wasp has seen you! Get away: jump, drop on your line, or reach the crack."
	elseif phase == "taking" or phase == "seizing" then
		return "The wasp is after something else on the sill. Keep still or keep out of sight until it goes."
	elseif phase == "bearing" then
		return "The wasp has taken something and is leaving with it."
	elseif phase == "carrying" then
		return "Stung, the spider cannot move. The wasp carries it away."
	elseif phase == "leaving" then
		if spared then return "The wasp touched you with its antennae, gave up, and is leaving." end
		return "The wasp is leaving."
	end
	return nil
end

-- The life in a few plain lines: how long it lived, its meals, the wasp. Never a score. `hours` of life, `meals` finished, and the
-- wasp's visits and escapes.
function WaspText.summary(hours: number, meals: number, visits: number, escapes: number): string
	local lived = "less than a day"
	if hours >= 24.0 then
		local days = math.floor(hours / 24.0)
		lived = `{days} day{if days == 1 then "" else "s"}`
	end
	local out = { `It lived {lived}.`, `It ate {meals} meal{if meals == 1 then "" else "s"}.` }
	if visits > 0 then
		table.insert(out, `The wasp came {visits} time{if visits == 1 then "" else "s"}; it got away from it {escapes} time{if escapes == 1 then "" else "s"}.`)
	end
	return table.concat(out, "\n")
end

-- The catch screen `seconds` after it began: how dim the world is, and whether the line, then the summary and the choices, show.
function WaspText.panel(seconds: number): { dim: number, line: boolean, choices: boolean }
	return {
		dim = math.clamp(seconds / Data.caughtQuietS, 0.0, 1.0) * Data.caughtDim,
		line = seconds >= Data.caughtQuietS,
		choices = seconds >= Data.caughtQuietS + Data.caughtLineS,
	}
end

-- The button's words: back to the last rest when there is one, else back to the start.
function WaspText.choice(hasRest: boolean): string
	return if hasRest then WaspText.BACK else WaspText.START
end

return WaspText
