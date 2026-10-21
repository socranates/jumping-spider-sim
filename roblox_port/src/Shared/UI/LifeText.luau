--!strict
-- The words of the life clock and the retreat for the screen (ROBLOX-24), from Godot's habitat_loop.gd caption(): the day and
-- the part of it, the one line for the time of day or hunger, and the retreat's prompt. Button names come from ControlText for
-- the device in use (Godot's interact is the port's feed button, E; cancel is Q). Pure, checked in tests/life.luau.
local ControlText = require(script.Parent.ControlText)
local MateText = require(script.Parent.MateText)

local LifeText = {}

export type Prompt = { title: string, hint: string }

-- ROBLOX-106 (W4): the night in the garden (Life/Nature) and the end of a life in the standard rules. Nothing tells the dusk but the light.
LifeText.NIGHT_LINE = "The night found the spider."
LifeText.NIGHT_SUB = "Out on the ground after dark, something that hunts there found it."
LifeText.NIGHT_COLD = "A cold night in the open, and something passed close by. You are stiff and slow until the morning warms."
-- The end screen's last line in the standard rules (Easy and Free play keep theirs): what "Back to your last rest" costs, and what another spider is.
LifeText.DAY_LOST = "In Normal a death loses the day: back at your last rest, the meals, the growth and what you saw since then are gone (the notebook keeps its pages). Another spider is a new life from the start."
LifeText.NO_REST = "There is no rest to go back to. Another spider is a new life from the start."
function LifeText.dayLost(hasRest: boolean): string
	return if hasRest then LifeText.DAY_LOST else LifeText.NO_REST
end

-- "Day 2, evening".
function LifeText.day(day: number, part: string): string
	return `Day {day}, {part}`
end

-- The line under the day (Godot's precedence, among the lines this port has): starving, hungry, night, evening; nil otherwise.
-- `gentle` rules never say starving (Godot: is_starving() and not gentle).
function LifeText.line(part: string, energy: number, starving: boolean, gentle: boolean, hungryAt: number, weak: boolean?): string?
	if weak and not gentle then return "Starving: your spider will not last another day. Too hungry to sleep; find food." end
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

-- The HUD bar's label (ROBLOX-78), the Minecraft way: the bar is the spider's hunger, FULL when it is fed and emptying as it grows hungry, and
-- eating fills it. `fed` is the reserve, 0 to 1; the word after it is the same one the line under the day uses.
function LifeText.hunger(fed: number, gentle: boolean): string
	local v = math.clamp(fed, 0, 1)
	return string.format("Hunger %d%%", math.floor(v * 100 + 0.5)) .. (if gentle then " · gentle" elseif v <= 0 then " · starving" elseif v <= 0.25 then " · hungry" else "")
end

-- ROBLOX-96: the homes, by the retreat's id on the map (World/WorldMap): what each is called in the prompts, how a rest there is told, and where it is. The crack
-- is the default and every word of it is as it was; the gap under the bed's stone is the first garden home. A retreat this table does not know reads as the crack.
LifeText.HOMES = {
	sill_crevice = {
		name = "the silk-lined crack", -- "Asleep in the silk-lined crack", "Resting in the silk-lined crack"
		title = "The silk-lined crack", -- the prompt when the spider can rest
		home = "Home: the silk-lined crack", -- the line near home
		way = "Walk through the silk-framed opening under the wooden roof, then stop to rest.",
		kept = "Last rest kept.", -- (CheckpointStore's own words, kept as they were)
	},
	bed_a_stone = {
		name = "under the stone",
		title = "Under the stone",
		home = "Home: under the stone",
		way = "Walk into the gap under the big stone in the bed, then stop to rest.",
		kept = "Last rest kept, under the stone.",
	},
	-- ROBLOX-112: the first home inside, the gap under the toaster on the kitchen's counter
	kitchen_toaster = {
		name = "under the toaster",
		title = "Under the toaster",
		home = "Home: under the toaster",
		way = "Walk into the gap under the toaster on the counter, then stop to rest.",
		kept = "Last rest kept, under the toaster.",
	},
	-- ROBLOX-116: the ranger hut's homes, inside and in its garden
	hut_desk_drawer = {
		name = "under the drawer",
		title = "Under the drawer",
		home = "Home: under the desk's drawer",
		way = "Walk into the gap under the desk's drawer, then stop to rest.",
		kept = "Last rest kept, under the drawer.",
	},
	hut_board_gap = {
		name = "behind the notice board",
		title = "Behind the notice board",
		home = "Home: behind the notice board",
		way = "Walk into the gap behind the notice board, then stop to rest.",
		kept = "Last rest kept, behind the notice board.",
	},
	garden_a1_trough = {
		name = "under the trough",
		title = "Under the trough",
		home = "Home: under the trough",
		way = "Walk into the gap under the trough by the hut, then stop to rest.",
		kept = "Last rest kept, under the trough.",
	},
	garden_a3_stone = {
		name = "under the stone",
		title = "Under the stone",
		home = "Home: under the stone",
		way = "Walk into the gap under the flat stone in the grass, then stop to rest.",
		kept = "Last rest kept, under the stone.",
	},
	garden_d3_mulch = {
		name = "under the bark chip",
		title = "Under the bark chip",
		home = "Home: under the bark chip",
		way = "Walk into the gap under the bark chip in the mulch, then stop to rest.",
		kept = "Last rest kept, under the bark chip.",
	},
	-- ROBLOX-118: the darkest place in the hut, the gap under the back room's sofa
	room_sofa_under = {
		name = "under the sofa",
		title = "Under the sofa",
		home = "Home: under the sofa",
		way = "Walk in under the sofa in the back room, deep into the dark, then stop to rest.",
		kept = "Last rest kept, under the sofa.",
	},
	-- ROBLOX-119: the meadow's edge and the bench patch
	meadow_b2_leaf = {
		name = "under the curled leaf",
		title = "Under the curled leaf",
		home = "Home: under the curled leaf",
		way = "Walk in under the curled dead leaf in the meadow's grass, then stop to rest.",
		kept = "Last rest kept, under the curled leaf.",
	},
	bench_slats = {
		name = "the gap in the bench's slats",
		title = "The gap in the bench's slats",
		home = "Home: the gap in the bench's slats",
		way = "Climb down into the gap between the bench's seat slats, then stop to rest.",
		kept = "Last rest kept, in the bench's slats.",
	},
	bin_lip = {
		name = "under the bin's lip",
		title = "Under the bin's lip",
		home = "Home: under the bin's lip",
		way = "Walk in under the litter bin's base, between its feet, then stop to rest.",
		kept = "Last rest kept, under the bin's lip.",
	},
} :: { [string]: { name: string, title: string, home: string, way: string, kept: string } }
LifeText.DEFAULT_HOME = "sill_crevice"
local function homeOf(retreat: string?): { name: string, title: string, home: string, way: string, kept: string }
	return LifeText.HOMES[retreat or LifeText.DEFAULT_HOME] or LifeText.HOMES[LifeText.DEFAULT_HOME]
end
local function inWords(name: string): string
	return if string.sub(name, 1, 6) == "under " then name else "in " .. name
end

-- The retreat's prompt: asleep, resting, or able to rest (sleep in the evening and at night); nil when none of these. `extra` (the crack's
-- way to change spider, ROBLOX-31) is added to the resting hint. `retreat` (ROBLOX-96): which home, by its id; the crack when nil.
function LifeText.prompt(asleep: boolean, resting: boolean, canRest: boolean, sleepTime: boolean, device: ControlText.Device, extra: string?, retreat: string?): Prompt?
	local feed, cancel = ControlText.name(device, "feed"), ControlText.name(device, "cancel")
	local h = homeOf(retreat)
	if asleep then
		return { title = `Asleep {inWords(h.name)}`, hint = `The night passes. Move, {feed} or {cancel} to wake.` }
	end
	if resting then
		return { title = `Resting {inWords(h.name)}`, hint = `Move, {feed} or {cancel} to leave.` .. (if extra and extra ~= "" then "    " .. extra else "") }
	end
	if canRest then
		return { title = h.title, hint = if sleepTime then `{feed}: sleep until morning` else `{feed}: rest` }
	end
	return nil
end

-- The line near a home when there is no prompt (ROBLOX-96): "Home: the silk-lined crack" and how to get in, or, inside it, how to rest. `retreat` is the home's id.
function LifeText.homeLine(retreat: string?, inside: boolean, device: ControlText.Device): Prompt
	local h = homeOf(retreat)
	return { title = h.home, hint = if inside then `Keep still on a surface, then {ControlText.name(device, "feed")}: rest` else h.way }
end

-- What a kept rest says (ROBLOX-96): the store's own words for the crack, and the place for any other home. `message` is what the store said.
function LifeText.restKept(retreat: string?, message: string): string
	if retreat == nil or retreat == LifeText.DEFAULT_HOME or LifeText.HOMES[retreat] == nil then return message end
	return homeOf(retreat).kept
end

-- What the touch feed button says when it is the retreat's (nil: it is the meal's, or hidden).
function LifeText.touchLabel(asleep: boolean, resting: boolean, canRest: boolean, sleepTime: boolean): string?
	if asleep then return "Wake" end
	if resting then return "Leave" end
	if canRest then return if sleepTime then "Sleep" else "Rest" end
	return nil
end

-- Why a rest is not kept as the last rest (ROBLOX-92), in the game's own words. The keys are the reasons Persistence/Checkpoint.boundaryProblem gives (engineering words, never
-- shown); a reason this table does not know says LifeText.REST_FALLBACK, and tests/checkpoint.luau checks that every reason the sim can give is known.
LifeText.REST_FALLBACK = "Not now"
LifeText.KEEP_FAILED = "This rest could not be kept"
LifeText.REST_REFUSALS = {
	["the spider is not standing on a surface"] = "Not now — stand still on a surface first",
	["the spider is moving"] = "Not now — keep still first",
	["the rival in the jaws is still struggling"] = "Not while a fight is on",
	["the spider is eating its rival"] = "Not while you are feeding",
	["the two spiders are together"] = MateText.REST_TOGETHER,
	["the brood is hatching"] = MateText.REST_HATCHING,
	["the spider is feeding"] = "Not while you are feeding",
	["the prey in the jaws is still struggling"] = "Not while a fight is on",
	["a strike is still in progress"] = "Not now — wait for the strike to finish",
} :: { [string]: string }
function LifeText.restRefusal(reason: string): string
	return LifeText.REST_REFUSALS[reason] or LifeText.REST_FALLBACK
end

-- ROBLOX-96: what the meal line says of the prey in the jaws, by its kind (Species body.prey_kind): how many of it make a housefly meal, and how finely the count is
-- shown (halves for the sill's prey, as always; tenths for the bed's smaller ones, so a gnat's third shows).
LifeText.MEALS = {
	fruit_fly = { rule = "2 small prey = 1 housefly", step = 2 },
	fungus_gnat = { rule = "3 gnats = 1 housefly", step = 10 },
	aphid = { rule = "6 aphids = 1 housefly", step = 10 },
	-- ROBLOX-101: the bestiary's
	springtail = { rule = "8 springtails = 1 housefly", step = 10 },
	leafhopper = { rule = "2 leafhoppers = 1 housefly", step = 2 },
	moth = { rule = "1 moth = 1 housefly", step = 2 },
	crane_fly = { rule = "1 crane fly = 2 houseflies", step = 2 },
	hoverfly = { rule = "2 hoverflies = 3 houseflies", step = 2 }, -- (ROBLOX-117)
} :: { [string]: { rule: string, step: number } }
local DEFAULT_MEAL = { rule = "2 small prey = 1 housefly", step = 2 }

-- Housefly-equivalent meals: a small prey counts as half. Partial feeding is retained. `kind` (ROBLOX-96): the prey in the jaws, for the rule it says.
function LifeText.growth(g: any, required: number, meal: number, kind: string?): string
 if g:isAdult() then return "Adult: keep your hunger bar full." end
 if g:isMoulting() then return "Moulting: stay in the crack." end
 if g.ready then return "Ready to moult: rest in the crack." end
 -- (ROBLOX-88: the goal is the growth's own, 3 by Godot's rule and 5 in the game; `required` and `meal` serve a growth that cannot say.)
 local goal = if g.mealGoal ~= nil then g:mealGoal() else math.ceil(required / meal)
 required = if g.readyAt ~= nil then g:readyAt() else required
 local rule = LifeText.MEALS[kind or ""] or DEFAULT_MEAL
 local count = math.min(goal, math.floor(g.fedSinceMoult / required * goal * rule.step + 1e-8) / rule.step)
 return `Next moult: {count} of {goal} meals · {rule.rule}`
end
-- ROBLOX-113 (W5, Shared/UI/QuietHud): the growth line in Normal after the first day: the count without the prey's rule ("Next moult: 2 of 5 meals"), "Ready to moult",
-- or nothing (moulting: the prompt's title says it; an adult: the day line's stage says it). The arguments are growth's.
function LifeText.growthQuiet(g: any, required: number, meal: number, kind: string?): string?
	if g:isAdult() or g:isMoulting() then return nil end
	if g.ready then return "Ready to moult" end
	local full = LifeText.growth(g, required, meal, kind)
	return string.match(full, "^(.-) · ") or full
end
return LifeText
