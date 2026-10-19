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
MateText.SAC = "An egg sac, made in the night, hangs in the crack. Rest in the crack to pass the nights."
MateText.GUARD_DAY = "Second day with the eggs. They hatch tomorrow morning."
MateText.HATCHING = "The eggs are hatching!"
-- ROBLOX-91: the mating gate (a full-grown spider with energy of at least 0.6, at a rest) said nothing when it was the hunger that was missing.
MateText.TOO_HUNGRY = "Too hungry for a visitor to come. Eat well, then rest in the crack again."

-- ROBLOX-92: the mating scene can be skipped after four seconds and said nothing of it. From then on the scene shows what ends it (its status line, not a sound
-- caption: the Captions setting does not hide it), by the device in use; on touch the Jump button is relabelled Skip for the scene, as it is Grip for a struggle.
MateText.TOUCH_SKIP = "Skip"
function MateText.skipLine(device: ControlText.Device): string
	local jump = if device == "touch" then MateText.TOUCH_SKIP else ControlText.name(device, "jump")
	return `{jump} or {ControlText.name(device, "cancel")}: part`
end

-- ROBLOX-92: why a rest is not kept as the last rest, in the game's own words (LifeText.restRefusal maps the rest of the reasons).
MateText.REST_TOGETHER = "Not now — the two of you are together"
MateText.REST_HATCHING = "Not while the brood is hatching"

-- The end screen's choice to go on as a new spider (ROBLOX-91): a new life, not the family's: the sac and the generation are left behind. While there is an egg sac (or a
-- hatched brood not yet carried on) it says so; "Back to your last rest" keeps them (the rest has them).
MateText.ANOTHER = "Continue as another spider"
MateText.ANOTHER_BROOD = "Continue as another spider (a new life: the brood is lost)"
function MateText.another(hasSac: boolean): string
	return if hasSac then MateText.ANOTHER_BROOD else MateText.ANOTHER
end

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

-- The captions of the mating scene (ROBLOX-89; Settings: Captions), by the scene's seconds. Device-neutral (nothing here names a button). `playerSex` is the played spider's:
-- the first spider is the game's female ("She turns to face him."), the peacock spider the male ("She turns to face you."). The last beat is the mirror when the player is
-- the male: the female turns away and stays, and the player goes on. The game is for children and about nature: they touch, they settle, one goes.
MateText.SCENE_TURN_FEMALE = "She turns to face him."
MateText.SCENE_TURN_MALE = "She turns to face you."
MateText.SCENE_TOUCH = "They touch, very lightly, with their front legs and palps."
MateText.SCENE_SETTLE = "They settle together, still."
MateText.SCENE_GOES = "He goes. The sill is yours again."
MateText.SCENE_STAYS = "She stays. You go on."
function MateText.matingCaption(seconds: number, playerSex: string): { text: string, alpha: number }?
	if seconds < 0 then return nil end
	local text: string
	if seconds < 3 then text = if playerSex == "male" then MateText.SCENE_TURN_MALE else MateText.SCENE_TURN_FEMALE
	elseif seconds < 7 then text = MateText.SCENE_TOUCH
	elseif seconds < 11 then text = MateText.SCENE_SETTLE
	elseif seconds < 15 then text = if playerSex == "male" then MateText.SCENE_STAYS else MateText.SCENE_GOES
	else return nil end
	return { text = text, alpha = 1 }
end

-- The notebook's dated line for the page "Eggs, silk and wind" (a thing the player saw; ROBLOX-89): the day, and who came.
function MateText.entry(day: number, mateSex: string): string
	if mateSex == "female" then
		return `Day {day}: A female was on the sill. The two spiders stayed together a while, and then you went on.`
	end
	return `Day {day}: A male came to the sill. The two spiders stayed together a while, and then he went.`
end
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
