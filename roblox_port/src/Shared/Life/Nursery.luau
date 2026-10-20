--!strict
-- The nursery rule (ROBLOX-116, docs/PARK_WORLD_DESIGN.md: Nathan's "born on the sill, the sash shut until ready"). In the preserve's first life the ranger hut's
-- window is shut and the hut's door is shut: the spider has the sill, the desk and the hut's inside. The window opens once, when the spider has grown past its
-- first moult and its new cuticle has hardened, on the first morning after that the ranger comes in (a seeded hour of the morning, `arrival`), and it stays
-- open from then on: the save remembers it (Persistence/SaveProgress `hut_window`), every later life finds it open, and nothing ever shuts it again.
--
-- Why the moult and not a number of days: the moult is the life's own proof that the spider can hunt (it has eaten what a moult asks for: five houseflies'
-- worth in Normal, three in the gentle modes, Life/Growth), and a jumping spider leaves the place it hatched as a juvenile, not after a calendar. A spider that
-- starves in the nursery has not been let out early: the next life is born in it again. The hardening (Growth.SOFT_HOURS) keeps the open window from meeting a
-- soft spider: the garden's wasp and its night are no place for one.
-- Pure: the client asks (Client/HutLife); tests/preserve.luau holds it.
local Nursery = {}

-- The ranger comes in between these hours of the morning (the life clock's); the window can be propped until noon of that day, and on any later morning.
Nursery.ARRIVAL = table.freeze({ 7.5, 9.5 })
Nursery.NOON = 12.0
-- The stage the spider must have reached (Life/Growth: 0 the young juvenile, 1 after the first moult).
Nursery.STAGE = 1

local MOD = 2147483647

-- The hour the ranger comes in on a day (the life clock's day, from 1), from the world's seed: the same hour for the same day forever (a restore never rerolls it).
function Nursery.arrival(seed: number, day: number): number
	local h = (math.floor(seed) % MOD + math.floor(day) * 104729) % MOD
	if h <= 0 then h += MOD - 1 end
	for _ = 1, 4 do h = (h * 48271) % MOD end
	local u = (h - 1) / (MOD - 1)
	return Nursery.ARRIVAL[1] + (Nursery.ARRIVAL[2] - Nursery.ARRIVAL[1]) * u
end

-- Whether the spider is ready to leave: past the stage, not moulting, its cuticle hard.
function Nursery.ready(stage: number, moulting: boolean, soft: boolean): boolean
	return stage >= Nursery.STAGE and not moulting and not soft
end

-- Whether the window is propped now: the spider ready and the ranger in (from the morning's arrival until noon).
function Nursery.opens(seed: number, stage: number, moulting: boolean, soft: boolean, day: number, hour: number): boolean
	if not Nursery.ready(stage, moulting, soft) then return false end
	return hour >= Nursery.arrival(seed, day) and hour < Nursery.NOON
end

return table.freeze(Nursery)
