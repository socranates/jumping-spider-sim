--!strict
-- The words and the typeface of the first minute (ROBLOX-109): the splash while the world streams in (First/SplashScreen), the title card the start
-- menu becomes (Client/CaughtPanel's "title" look), the intro of a new life (Client/TitleCard) and the death and ending cards' typeface. Every word a
-- player reads in those is here; the death and ending cards keep their own words (WaspText, LifeText, MateText). Pure: tests/title.luau checks them.
--
-- The typeface: Merriweather, a serif Roblox ships as a font family, Light for the title, Regular for the choices, Italic for the subtitle and the
-- captions (a naturalist's notebook in print). A family Roblox cannot find falls back to its default face on its own; Studio is the judge of the look.
local ControlText = require(script.Parent.ControlText)

local TitleText = {}

TitleText.TITLE = "The Windowsill"
TitleText.SUBTITLE = "A small life in a city's nature preserve." -- (ROBLOX-118: the preserve is the game; it begins on the ranger hut's windowsill)

TitleText.FAMILY = "rbxasset://fonts/families/Merriweather.json"
-- The colours: warm paper white for the words, a deep brown-black for the veil and the choices' ground.
TitleText.INK = Color3.fromRGB(244, 238, 226)
TitleText.SOFT = Color3.fromRGB(214, 205, 188)
TitleText.GROUND = Color3.fromRGB(16, 14, 12)

-- The title's size in pixels for a screen this wide: large on a monitor, still one line at a phone's width (360 px portrait).
function TitleText.titleSize(width: number): number
	return math.clamp(math.floor(width * 0.1), 30, 58)
end

-- The start menu's choices. On the title card (no life begun this visit) Continue is one word; in the life menu, beside "Resume this spider", it says
-- where it goes back to. The ids are CaughtPanel's choice ids and the buttons' names.
local START: { [string]: string } = {
	Continue = "Continue",
	ContinueEasy = "Continue the Easy life",
	New = "Begin a new life",
	Easy = "Begin a new life on Easy",
	Free = "Free play - gentle rules",
}
local IN_LIFE: { [string]: string } = {
	Resume = "Resume this spider",
	Controls = "Controls",
	Continue = "Continue from last rest",
	ContinueEasy = "Continue the Easy life from its last rest",
	New = "Begin a new life",
	Easy = "Begin a new life on Easy",
	Free = "Free play - gentle rules",
}
function TitleText.choice(id: string, started: boolean): string
	return (if started then IN_LIFE[id] else START[id]) or START[id] or id
end

-- The one line under the choices for a controller (the D-pad or the stick moves, the confirm button chooses, the back button goes back): in the
-- controller's own names (Cross and Circle on a PlayStation, A and B otherwise). The mouse, the keys and touch need no line.
function TitleText.navHint(device: ControlText.Device): string
	if device ~= "gamepad" then return "" end
	return `D-pad: move    {ControlText.name("gamepad", "jump")}: choose    {ControlText.name("gamepad", "cancel")}: back`
end

-- The intro's skip, shown once it can be skipped (after TitleShots.INTRO.skipAfter seconds): the jump key, the confirm button, or a tap.
function TitleText.skipHint(device: ControlText.Device): string
	if device == "touch" then return "Tap to skip" end
	return `{ControlText.name(device, "jump")}: skip`
end

-- The intro's captions, in the notebook's voice: what this spider is, how it hunts, and the day's one need. Each is backed by a notebook page
-- (bold_jumper, retreat, hunting_by_sight; the last by the game's own numbers: a new spider's reserve lasts under a day in the standard rules,
-- NeedsModel.ENERGY_START 0.55 at 0.612 a day, ROBLOX-88; the gentle rules drain it at 0.177 a day, ROBLOX-91).
function TitleText.captions(gentle: boolean): { string }
	return {
		"A young bold jumping spider. Home is a silk-lined crack in the sill.",
		"It spins no web to catch food. It hunts with its eyes.",
		if gentle then "Hunger is gentler in these rules. It is never gone." else "It has not eaten. It must eat today.",
	}
end

return TitleText
