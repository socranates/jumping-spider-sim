--!strict
-- The words of the life clock and the retreat for the screen (ROBLOX-24), from Godot's habitat_loop.gd caption(): the day and
-- the part of it, the one line for the time of day or hunger, and the retreat's prompt. Button names come from ControlText for
-- the device in use (Godot's interact is the port's feed button, E; cancel is Q). Pure, checked in tests/life.luau.
local ControlText = require(script.Parent.ControlText)

local LifeText = {}

export type Prompt = { title: string, hint: string }

-- "Day 2, evening".
function LifeText.day(day: number, part: string): string
	return `Day {day}, {part}`
end

-- The line under the day (Godot's precedence, among the lines this port has): starving, hungry, night, evening; nil otherwise.
-- `gentle` rules never say starving (Godot: is_starving() and not gentle).
function LifeText.line(part: string, energy: number, starving: boolean, gentle: boolean, hungryAt: number): string?
	if starving and not gentle then
		return "Starving: your spider's reserve is gone. It must eat soon."
	end
	if energy <= hungryAt then
		return "Hungry: time to hunt."
	end
	if part == "night" then
		return "It is dark, and your eyes reach only a little way. Home is the silk-lined crack at the west end."
	end
	if part == "evening" then
		return "Evening. Jumping spiders go into their silk retreat before dark."
	end
	return nil
end

-- The retreat's prompt: asleep, resting, or able to rest (sleep in the evening and at night); nil when none of these.
function LifeText.prompt(asleep: boolean, resting: boolean, canRest: boolean, sleepTime: boolean, device: ControlText.Device): Prompt?
	local feed, cancel = ControlText.name(device, "feed"), ControlText.name(device, "cancel")
	if asleep then
		return { title = "Asleep in the silk-lined crack", hint = `The night passes. Move, {feed} or {cancel} to wake.` }
	end
	if resting then
		return { title = "Resting in the silk-lined crack", hint = `Move, {feed} or {cancel} to leave.` }
	end
	if canRest then
		return { title = "The silk-lined crack", hint = if sleepTime then `{feed}: sleep until morning` else `{feed}: rest` }
	end
	return nil
end

-- What the touch feed button says when it is the retreat's (nil: it is the meal's, or hidden).
function LifeText.touchLabel(asleep: boolean, resting: boolean, canRest: boolean, sleepTime: boolean): string?
	if asleep then return "Wake" end
	if resting then return "Leave" end
	if canRest then return if sleepTime then "Sleep" else "Rest" end
	return nil
end

return LifeText
