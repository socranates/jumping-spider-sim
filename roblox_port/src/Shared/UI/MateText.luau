--!strict
-- The words of the mating cycle for the screen (ROBLOX-80): the notices for each beat Life/Mating reports, the status line while courting and while
-- guarding the sac, the captions, the ending card of the hatching and the toast of the next generation. Button names come from ControlText for the device in
-- use. The game is for children and about nature: nothing is shown or said about the mating but that the two spiders stay together a moment.
-- Pure: checked in tests/client_mating.luau.
local ControlText = require(script.Parent.ControlText)

local MateText = {}

MateText.TITLE = "The sill continues"
MateText.BUTTON = "Carry on"
MateText.METER = "Courtship"

-- The words for the mate: "male" or "female".
local function kind(sex: string): string
	return if sex == "male" then "a male spider" else "a female spider"
end

-- A mate came onto the sill. The peacock spider is told that its dance is the way to court it.
function MateText.arrived(sex: string, needsDance: boolean, device: ControlText.Device): string
	local line = `A visitor: {kind(sex)} has come onto the sill. Walk close, face it and keep still.`
	if needsDance then line ..= ` Dance for it ({ControlText.name(device, "display")}).` end
	return line
end

MateText.NOTICED = "It has seen you."
MateText.DRIVEN = "You frightened it. It leaves the sill for today."
MateText.COURTED = "The two spiders stay together for a moment."
MateText.MATED = "They have parted. The visitor walks away and will not come again."
MateText.SAC = "An egg sac, made in the night, hangs in the crack. Stay near it for two days."
MateText.GUARD_DAY = "Second day with the eggs. They hatch tomorrow morning."
MateText.HATCHING = "The eggs are hatching!"

-- Why the mate left the sill, as a notice (the reasons Predator/Mate gives); "mated" is said by MATED already.
function MateText.gone(reason: string): string?
	if reason == "dusk" then return "The visitor has gone for the evening. It may come back in the morning." end
	if reason == "rest" then return "The visitor wandered off while you rested." end
	if reason == "sex" then return "The visitor is not interested and leaves." end
	if reason == "driven" then return nil end
	return nil
end

-- The notice for an event of Mating.tick (and "sac" from Mating.woke), or nil when the event has no words. `ctx`: sex (the mate's), needsDance, device, reason.
function MateText.notice(event: string, ctx: { sex: string?, needsDance: boolean?, device: ControlText.Device?, reason: string? }): string?
	if event == "arrived" then return MateText.arrived(ctx.sex or "male", ctx.needsDance == true, ctx.device or "keyboard") end
	if event == "noticed" then return MateText.NOTICED end
	if event == "driven" then return MateText.DRIVEN end
	if event == "courted" then return MateText.COURTED end
	if event == "mated" then return MateText.MATED end
	if event == "gone" then return MateText.gone(ctx.reason or "") end
	if event == "sac" then return MateText.SAC end
	if event == "guard_day" then return MateText.GUARD_DAY end
	if event == "hatched" then return MateText.HATCHING end
	return nil
end

-- The status line while a mate is on the sill and courtable: what the meter wants. `near`: within courting range; `dancing`: the peacock spider's dance is up.
function MateText.courtLine(device: ControlText.Device, near: boolean, needsDance: boolean, dancing: boolean, percent: number): string
	if not near then return "A visitor is on the sill. Walk close to it." end
	if needsDance and not dancing then
		return `Courting: dance in front of it ({ControlText.name(device, "display")})`
	end
	local p = math.floor(math.clamp(percent, 0, 1) * 100 + 0.5)
	return `Courting {p}%: face it and keep still`
end

-- The status line while the sac is guarded: guard day `day` of `days`.
function MateText.guardLine(day: number, days: number): string
	return `Guarding the eggs: day {day} of {days}. Rest in the crack to pass the nights.`
end

-- The one caption of the pause together: a quiet sound, read as words (Settings: Captions).
MateText.PAIR_CAPTION = { text = "[a faint tremble in the silk]", alpha = 1 }
-- The captions of the hatching scene, by the seconds since it began.
function MateText.sceneCaption(seconds: number): { text: string, alpha: number }?
	if seconds < 0 then return nil end
	if seconds < 9 then return { text = "[tiny rustling from the egg sac]", alpha = 1 } end
	if seconds < 24 then return { text = "[silk threads lift the spiderlings away]", alpha = 1 } end
	return nil
end

-- The ending card: the title, the line about the generation and the body (the brood, the day). `brood` is the number of spiderlings that hatched.
function MateText.card(brood: number, day: number, generation: number): (string, string, string)
	local sub = `{brood} spiderlings hatched on day {day}, climbed into the light and floated away on silk, one by one.`
	local body = `You were generation {generation + 1}. You carry on as one of them, small again, in the same crack on the same sill.`
	return MateText.TITLE, sub, body
end

-- The toast of the new generation. `generation` is the number carryOn returns (1 for the first carry on); the first spider is generation 1.
function MateText.generationToast(generation: number, day: number): string
	return `Generation {generation + 1} — hatched on day {day}`
end

-- The day line's tag ("" while the family is the first).
function MateText.dayTag(generation: number): string
	return if generation > 0 then ` | Generation {generation + 1}` else ""
end

return MateText
