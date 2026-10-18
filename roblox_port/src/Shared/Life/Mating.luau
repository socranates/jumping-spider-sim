--!strict
-- The mating cycle and the new generation (ROBLOX-79). One plain record, life.mating, in LifeLoop's checkpoint graph beside life.mate (the mate's body,
-- Predator/Mate) and life.generation (how many families the sill has had); nothing here knows the clock, the engine or the player but through the snapshot
-- the caller hands in, so the CLI tests drive whole cycles. Absent fields mean the old game: a record from before this change restores as stage "none",
-- generation 0, and nothing in it is ever rerolled (the mate's size, the brood and every arrival are pure functions of the world's seed, the day and the
-- numbers kept in the record).
--
-- The cycle, in stages:
--   none ....... nothing going on. A rest in the crack by a full-grown spider with energy of at least 0.6 sets `ready_day`, the morning of the next 07:00:
--                from then a mate comes on mornings (Predator/Mate) until the player has courted it.
--   courted .... the courtship meter is full and the pair are together for the pause (Mate state "pair").
--   mated ...... the pause is over and the mate is walking off. The next sleep in the crack that reaches the morning makes the egg sac.
--   sac ........ the morning the sac is there: guard day 1.
--   guarding ... guard day 2. (Guarding is surviving: nothing in v1 can harm the sac, the wasp and the rival never enter the crack.)
--   hatched .... the morning after the last guard day: the brood is out. The hatching scene and the ending card belong to the client; carryOn() makes
--                the next generation when the player takes it.
-- carryOn: generation += 1, growth back to the first stage, a fresh energy, the day count goes on (it is the clock's), the mating state is none again,
-- so the cycle can happen again in the next generation.
local Rules = require(script.Parent.Parent.Data.MatingRules)
local Mate = require(script.Parent.Parent.Predator.Mate)
local Growth = require(script.Parent.Growth)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)

local Mating = {}

Mating.STAGES = { "none", "courted", "mated", "sac", "guarding", "hatched" }
local STAGE: { [string]: boolean } = {}
for _, name in Mating.STAGES do STAGE[name] = true end

local COUNTERS = { "ready_day", "guard_day", "sac_day", "hatch_day", "brood", "mates", "visits", "visit_day", "away_day", "drive_offs" }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function whole(x: any): boolean
	return finite(x) and x >= 0 and x <= 1e9 and x % 1 == 0
end

function Mating.new(): any
	return {
		stage = "none",
		ready_day = 0, -- the morning (day) from which a mate may come; 0: not yet eligible
		guard_day = 0, -- 1 or 2 while the sac is guarded
		sac_day = 0, -- the morning the sac appeared
		hatch_day = 0, hatch_hour = 0.0, brood = 0, -- when the eggs hatched, and how many spiderlings came out
		mates = 0, visits = 0, visit_day = 0, away_day = 0, drive_offs = 0, -- the mate's bookkeeping: which mate, how many days it has come, the last day it came and left
	}
end

-- Fills any field an older or shorter record does not have (so absent means the old behaviour), in place. Returns the record.
function Mating.normalize(m: any): any
	for _, k in COUNTERS do
		if m[k] == nil then m[k] = 0 end
	end
	if m.hatch_hour == nil then m.hatch_hour = 0.0 end
	if m.stage == nil then m.stage = "none" end
	return m
end

-- The sex of the played spider: the peacock spider is the male and the ant mimic the female; the first spider has no sex in its design and is the game's
-- female (its mate is a male, as the rival is). The mate is the opposite.
function Mating.sexOf(appearanceId: string): string
	if appearanceId == "maratus_volans_male" then return "male" end
	return "female"
end

-- Is the spider ready to mate: full-grown (Growth's last stage) and well fed.
function Mating.eligible(growth: any, energy: number): boolean
	return growth ~= nil and growth:isAdult() and energy >= Rules.energyMin - 1e-9
end

-- The brood: a seeded number of spiderlings, from the world's seed, the family's number and the day the eggs hatched (so a return never rerolls it).
function Mating.broodSize(seed: number, generation: number, day: number): number
	local g = PreyRandom.new((seed * 83492791 + generation * 19349663 + day * 73856093 + 4093) % 2147483647)
	g:next()
	g:next()
	return Rules.broodMin + math.floor(g:next() * (Rules.broodMax - Rules.broodMin + 1))
end

-- Is there an egg sac in the crack to draw: from the morning it is made until the family has carried on (the hatching scene draws it too).
function Mating.hasSac(m: any): boolean
	return m ~= nil and (m.stage == "sac" or m.stage == "guarding" or m.stage == "hatched")
end

-- The generation of a life (0 for a record that has none).
function Mating.generation(life: any): number
	return if type(life.generation) == "number" then life.generation else 0
end

-- The day of the 07:00 morning the clock is in (the hours before it belong to the day before).
local function morningOf(day: number, hour: number): number
	return if hour >= Rules.arriveHour then day else day - 1
end

-- Called when the spider rests in the crack (the caller makes it before the rest's checkpoint, so the checkpoint has it): a full-grown, well-fed spider
-- makes the next 07:00 the morning from which a mate comes. It sets and never clears, and does nothing during a cycle already going. Returns whether it set it.
function Mating.atRest(life: any, day: number, hour: number): boolean
	local m = Mating.normalize(life.mating or Mating.new())
	life.mating = m
	if m.stage ~= "none" or m.ready_day > 0 then return false end
	if not Mating.eligible(life.growth, life.needs.energy) then return false end
	m.ready_day = if hour >= Rules.arriveHour then day + 1 else day
	return true
end

-- A night's sleep in the crack reached the morning of `day` (LifeLoop's "woke"): after mating, that sleep made the egg sac. Returns "sac" or "".
function Mating.woke(life: any, day: number): string
	local m = Mating.normalize(life.mating or Mating.new())
	life.mating = m
	if m.stage ~= "mated" then return "" end
	m.stage, m.sac_day, m.guard_day = "sac", day, 1
	return "sac"
end

-- One fixed tick of the whole cycle. `s` is the player's snapshot (see Predator/Mate.step) with day, hour, seed and `sex`, `needsDance`, `dancing`. Returns
-- the events of the tick, in order: "arrived" (with "new_mate" before it when it is another mate), "noticed", "driven", "courted", "mated", "gone",
-- "guard_day" (the second guard day began) and "hatched".
function Mating.tick(life: any, dt: number, s: any): { string }
	local events: { string } = {}
	local m = Mating.normalize(life.mating or Mating.new())
	life.mating = m
	local mate = life.mate
	if mate == nil then
		mate = Mate.new()
		life.mate = mate
	end
	-- The guard days, by the clock: the morning of the 07:00 the sac was made is day 1.
	if (m.stage == "sac" or m.stage == "guarding") and m.sac_day > 0 then
		local d = morningOf(s.day, s.hour) - m.sac_day + 1
		if d > Rules.guardDays and s.hour >= Rules.arriveHour then
			m.stage, m.hatch_day, m.hatch_hour = "hatched", s.day, s.hour
			m.brood = Mating.broodSize(s.seed or 0, Mating.generation(life), s.day)
			table.insert(events, "hatched")
		elseif d >= 2 and m.guard_day < 2 then
			m.stage, m.guard_day = "guarding", math.min(d, Rules.guardDays)
			table.insert(events, "guard_day")
		end
	end
	-- The mate.
	s.mayArrive = m.stage == "none" and m.ready_day > 0 and s.day >= m.ready_day and s.day > m.away_day
	local event = Mate.step(mate, dt, s)
	if event == "arrived" then
		-- One mate at a time, for at most visitsMax mornings; then another one.
		if m.mates == 0 or m.visits >= Rules.visitsMax then
			m.mates += 1
			m.visits = 0
			table.insert(events, "new_mate")
		end
		m.visits += 1
		m.visit_day = s.day
		mate.sex = Mate.opposite(s.sex or "female")
		mate.scale = Mate.scaleFor(s.seed or 0, m.mates, mate.sex)
		table.insert(events, "arrived")
	elseif event == "courted" then
		m.stage = "courted"
		table.insert(events, "courted")
	elseif event == "mated" then
		m.stage = "mated"
		table.insert(events, "mated")
	elseif event == "driven" then
		m.drive_offs += 1
		m.away_day = s.day
		table.insert(events, "driven")
	elseif event == "gone" then
		m.away_day = s.day
		table.insert(events, "gone")
	elseif event ~= "" then
		table.insert(events, event)
	end
	return events
end

-- The next generation (after the hatching scene and the ending card). The spider is a spiderling again: the first growth stage and a fresh energy, rested;
-- the days of the sill go on; the mating state and the mate are new, so the cycle can happen again. Notebook, appearance and the world are not touched.
-- Returns the new generation number and the day it hatched.
function Mating.carryOn(life: any, needs: any): (number, number)
	local m = Mating.normalize(life.mating or Mating.new())
	local day = m.hatch_day
	local generation = Mating.generation(life) + 1
	life.generation = generation
	life.growth = Growth.new()
	life.grantedSeen = needs.grantedTotal
	life.mealFood = nil
	life.lifeOver = false
	needs.energy = Rules.freshEnergy
	needs.rest = 1.0
	needs.starvingHours, needs.starvingStreakH = 0.0, 0.0
	life.mating = Mating.new()
	life.mate = Mate.new()
	return generation, day
end

-- What is wrong with a mating record (an empty list for a good one; nil is a good one: a life with no cycle yet). Absent fields are good.
function Mating.problems(m: any): { string }
	local e: { string } = {}
	local function bad(t: string) table.insert(e, "mating: " .. t) end
	if m == nil then return e end
	if type(m) ~= "table" then bad("not a record"); return e end
	if m.stage ~= nil and (type(m.stage) ~= "string" or not STAGE[m.stage]) then bad("unknown stage") end
	for _, k in COUNTERS do
		if m[k] ~= nil and not whole(m[k]) then bad(`'{k}' is not a whole number`) end
	end
	if m.hatch_hour ~= nil and (not finite(m.hatch_hour) or m.hatch_hour < 0 or m.hatch_hour >= 24) then bad("the hatch hour is not in [0, 24)") end
	if #e > 0 then return e end
	if (m.visits or 0) > Rules.visitsMax then bad("a mate has come on more days than it may") end
	if (m.guard_day or 0) > Rules.guardDays then bad("more guard days than there are") end
	if (m.brood or 0) > 64 then bad("a brood that large") end
	local stage = m.stage or "none"
	if stage == "sac" and ((m.sac_day or 0) < 1 or m.guard_day ~= 1) then bad("a new sac with no morning, or not on its first guard day") end
	if stage == "guarding" and ((m.sac_day or 0) < 1 or (m.guard_day or 0) < 2) then bad("a guarded sac with no morning, or before its second guard day") end
	if stage == "hatched" and ((m.hatch_day or 0) < 1 or (m.brood or 0) < 1) then bad("a hatching with no day or no brood") end
	return e
end

-- The checks that need the mate beside the record: a mate on the sill belongs to a cycle that wants one, and the pause together is the stage courted.
function Mating.problemsWith(m: any, mate: any): { string }
	local e = Mating.problems(m)
	if #e > 0 or mate == nil then return e end
	local stage = if m ~= nil and m.stage ~= nil then m.stage else "none"
	if mate.state ~= "away" and stage ~= "none" and stage ~= "courted" and stage ~= "mated" then
		table.insert(e, "mating: a mate is on the sill during the sac and the guarding")
	end
	if stage == "courted" and mate.state ~= "pair" then table.insert(e, "mating: courted, but the pair are not together") end
	if mate.state == "pair" and stage ~= "courted" then table.insert(e, "mating: together, but not courted") end
	return e
end

return Mating
