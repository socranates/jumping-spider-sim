--!strict
-- Nature's rules (ROBLOX-106, W4 of docs/OPEN_WORLD_DESIGN.md; the design called it "ROBLOX-97", a number never used). Nathan: "Normal mode should feel like it doesn't
-- want you to survive"; "movement expends more energy"; "being perched up high avoiding predators and hiding under leaves"; "scared I won't make it home at night".
-- The game's own rules, in the standard rules (Normal) only: Easy and Free play keep ROBLOX-91's gentleness untouched, and nothing here touches Godot's defaults (the
-- needs, the wasp's and the rival's numbers, the clock's rates, perception). Pure: the client hands in what it knows each tick (Client/SpiderClient), the CLI tests
-- drive it alone (tests/nature.luau).
--
-- * Movement (`Nature.moved`): which movement the spider made this tick, for NeedsModel.move (NeedsModel.game.moveCost): walking on a surface, a jump as it leaves
--   the surface, letting down or reeling in on the line. Standing, hanging still and resting cost nothing extra.
-- * Cover (`Nature.cover`): how much faster or slower a predator's notice grows: halved under a leaf (something solid overhead within `coverWu`, a ray straight up
--   from the spider) and halved again when still; doubled when moving in the open. The wasp's notice (WaspDirector, `spider.cover`) and the rival's
--   (RivalSpider, `s.noticeScale`) take it; their own rules are as they were.
-- * The night (`Nature.night`): out of every retreat after dark anywhere but the sill (the nursery, behind the glass), the ground hunters pass three times a night at
--   hours drawn from the world's seed and the night; a spider exposed when one passes is found (death: the card says so) or, if the draw spares it, passes a cold
--   night and is slow until the morning warms. A spider in any retreat, or on the sill, is never drawn against. Dusk is told by the light alone: no notice comes
--   before it. Restores never reroll: the hours and the draws are pure functions of the seed, the night and the pass, and a return to a rest starts the night's
--   count again from the restored hour (the passes already behind it are behind it; the spider was in its retreat for them).
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)

local Nature = {}

Nature.game = {
	-- Cover: the ray straight up that finds a leaf (or anything solid) over the spider, and the factors.
	coverWu = 6.0, covered = 0.5, still = 0.5, openMoving = 2.0,
	-- The night: the passes' windows in hours of the night (an hour after midnight is 24 + it), the chance a pass finds an exposed spider, and the cold morning.
	passes = { { 20.5, 23.5 }, { 23.5, 26.5 }, { 26.5, 29.5 } },
	foundChance = 0.25,
	coldUntilH = 10.0, -- the cold morning lasts until this hour of the day after the night
	coldSpeed = 0.6, -- the walk's speed while it lasts
	nightFromH = 18.0, -- (LifeClock.EVENING_H: an hour from here belongs to the night of its own day)
	morningH = 7.0, -- (LifeClock.WAKE_H: an hour before this belongs to the night of the day before)
}

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- ------------------------------------------------------------------------------------------------------------------- cover

-- The factor on a predator's notice for a spider `covered` (something overhead) and `still`. 1 is the old rule; the standard rules only (the caller asks).
function Nature.cover(covered: boolean, still: boolean): number
	local g = Nature.game
	if covered or still then
		return (if covered then g.covered else 1.0) * (if still then g.still else 1.0)
	end
	return g.openMoving
end

-- Whether something solid is over the point within the cover ray. `ray(from, dir)` is the world's cast (nil: nothing).
function Nature.overhead(at: Vector3, ray: (Vector3, Vector3) -> any): boolean
	return ray(at + Vector3.new(0, 0.05, 0), Vector3.new(0, Nature.game.coverWu, 0)) ~= nil
end

-- ------------------------------------------------------------------------------------------------------------------- movement

-- What the spider did this tick, from the motor (its mode, whether it walks, whether it was dropped, its line's length) and the last tick's `st` (kept by the
-- caller, updated here): "jump" on the tick it leaves a surface by a jump or hop, "walk" while it walks a surface, "line" while the line's length changes
-- (letting down, reeling in), else "". A drop off an edge onto the line is not a jump; a seized spider does nothing.
function Nature.moved(st: { [string]: any }, mode: string, moving: boolean, dropped: boolean, seized: boolean, onLine: boolean, lineLength: number?): string
	local was = st.mode
	local rest = st.rest
	st.mode = mode
	st.rest = if onLine then lineLength else nil
	if seized then return "" end
	if mode == "air" and was == "attached" and not dropped then return "jump" end
	if mode == "attached" and moving then return "walk" end
	if onLine and lineLength ~= nil and rest ~= nil and math.abs(lineLength - rest) > 1e-5 then return "line" end
	return ""
end

-- ------------------------------------------------------------------------------------------------------------------- the night

-- The night an hour belongs to (the day it began), and the hour counted in that night (after midnight, 24 + the hour); nil by day.
function Nature.nightOf(day: number, hour: number): (number?, number)
	local g = Nature.game
	if hour >= g.nightFromH then return day, hour end
	if hour < g.morningH then return day - 1, hour + 24 end
	return nil, hour
end

-- One stream a night (the world's seed and the night), drawn in order: the first pass's hour, whether it finds, the second's hour, ... (one stream, so the passes of a
-- night are independent draws, not offsets of one another).
local function draws(seed: number, night: number): ({ number }, { boolean })
	local r = PreyRandom.mixed(seed, night, 71)
	local hours: { number }, found: { boolean } = {}, {}
	for i, w in Nature.game.passes do
		hours[i] = w[1] + (w[2] - w[1]) * r:next()
		found[i] = r:next() < Nature.game.foundChance
	end
	return hours, found
end

-- The hours (in the night's count) at which the ground hunters pass on night `night`, one in each window.
function Nature.passHours(seed: number, night: number): { number }
	return (draws(seed, night))
end

-- Whether pass `pass` of night `night` finds an exposed spider.
function Nature.found(seed: number, night: number, pass: number): boolean
	local _, found = draws(seed, night)
	return found[pass] == true
end

-- The kinds of region inside the house, where the garden's night (its ground hunters, its cold) does not reach: the sill, and (ROBLOX-112) the kitchen's counter and floor.
-- The inside's own night (the house spider, the lamp's moths) is the inside's round (docs/WORLD_MAP_PLAN.md).
Nature.INDOORS = table.freeze({ sill = true, counter = true, kitchen_floor = true })

-- Whether a spider is exposed to the night where it is: in the standard rules, anywhere outside the house (ROBLOX-106: anywhere but the sill), out of every retreat.
function Nature.exposed(standard: boolean, regionKind: string, inRetreat: boolean): boolean
	return standard and not Nature.INDOORS[regionKind] and not inRetreat
end

-- One tick of the night. `st` is the caller's (never saved; cleared on a return to a rest and a new life); `life` the LifeLoop (its clock; `cold_day` is set on it,
-- an optional field the checkpoint keeps). `ctx`: seed, exposed. Returns "found" (death), "cold" (a pass spared an exposed spider) or "".
function Nature.night(st: { [string]: any }, life: any, ctx: { seed: number, exposed: boolean }): string
	local night, h = Nature.nightOf(life.clock.day, life.clock.hour)
	if night == nil then
		st.night, st.done = nil, nil
		return ""
	end
	local hours = Nature.passHours(ctx.seed, night)
	if st.night ~= night then
		-- A night met for the first time here: the passes already behind this hour are behind it (a new night at 18:00 has none; a restored rest has the spider in
		-- its retreat for them).
		local done = 0
		for i, ph in hours do if ph <= h then done = i end end
		st.night, st.done = night, done
		return ""
	end
	local event = ""
	for i = (st.done or 0) + 1, #hours do
		if hours[i] > h then break end
		st.done = i
		if ctx.exposed and event == "" then
			if Nature.found(ctx.seed, night, i) then
				event = "found"
			else
				life.cold_day = night + 1
				event = "cold"
			end
		end
	end
	return event
end

-- The cold after an exposed night: the factor on the walk's speed now (1 when there is none; a cold that is over is cleared).
function Nature.coldSpeed(life: any): number
	local d = life.cold_day
	if d == nil then return 1.0 end
	local day, hour = life.clock.day, life.clock.hour
	if day < d or (day == d and hour < Nature.game.coldUntilH) then return Nature.game.coldSpeed end
	life.cold_day = nil
	return 1.0
end

-- Whether a record's `cold_day` is good (nil is).
function Nature.validCold(v: any): boolean
	return v == nil or (finite(v) and v >= 1 and v <= 1e9 and v % 1 == 0)
end

return Nature
