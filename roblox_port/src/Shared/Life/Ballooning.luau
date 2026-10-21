--!strict
-- Ballooning, the lineage moves (ROBLOX-120, docs/PARK_WORLD_DESIGN.md section 5: "the spiderlings balloon. The player chooses one to follow: where it lands is drawn from
-- the wind (seeded, honest: mostly nearby zones, rarely far), and the next life starts in that zone"). The notebook's page "Eggs, silk and wind" says what is known: many
-- young spiders travel by climbing high, letting out a thread of silk and being carried off by the air. Pure: the client plays the ride (Client/MateStage's rider and the
-- camera's shot) and starts the next generation where it lands; the CLI suites and the self-test ask the same draw.
--
-- The draw (`land`): a pure function of the world's seed, the family's number and the day the eggs hatched, so a choice seen again lands in the same place and a
-- restore never rerolls it. Each zone of ZONES has a weight that falls off with its distance from the hut (WEIGHT_M metres: exp(-d / WEIGHT_M)), so the near zones are
-- the likely ones and the far ones rare; only a zone that is built (`built`, walkable in the preserve: World/Hut, World/Meadow) can be landed in, the others are listed
-- for when they are, and drop out of the draw. In a built zone the landing is one of its `landings`, regions whose spawn is a place to stand (a spiderling's thread
-- snags on what stands up, and it comes down there). Now: the hut garden (about three quarters of draws), the meadow's edge (most of the rest) and (ROBLOX-122) the
-- pond's edge, 34 m off, rarely (1 of 200 families).
--
-- The ride (`ride`, `at`): RIDE_S seconds from the egg sac in the sill's crack out through the window's sash and up over the garden on the wind, its thread streaming
-- ahead and above it, then down onto the landing; a seeded drift and a sway, never the same twice for two families and always the same for one.
-- `life.start_zone` (optional in a rest, Persistence/Checkpoint: absent is "hut", the generation that began in the crack) and `life.start_region` keep where this
-- generation began; the ending card, the toast and the notebook's dated line say it (UI/MateText). The nursery's shut window (Life/Nursery) is the hut's inside: a
-- generation that lands outside is in the wild, and nothing puts it back.
local Preserve = require(script.Parent.Parent.World.Preserve)

local Ballooning = {}

Ballooning.RIDE_S = 12.0
Ballooning.WEIGHT_M = 10.0
Ballooning.HUT = "hut" -- (the start of a generation that stayed in the crack)
Ballooning.SAC = Vector3.new(-27.1, 0.5, 8.4) -- (Data/MatingRules.sacAt: the egg sac in the sill's crack)
Ballooning.SASH = Vector3.new(0, 4, -16) -- the window's lower sash, out of which the threads go (World/Hut.SASH, just outside it)
Ballooning.UP = 260 -- how high over the garden's ground a ride climbs (studs), at most

export type Zone = { zone: string, name: string, built: boolean, landings: { string } }
local function zone(id: string, name: string, built: boolean, landings: { string }): Zone
	return table.freeze({ zone = id, name = name, built = built, landings = table.freeze(landings) })
end
Ballooning.ZONES = table.freeze({
	zone("hut_garden", "the hut garden", true, { "garden_a2", "garden_a4", "garden_b1", "garden_c2", "garden_d2" }),
	zone("meadow", "the meadow's edge", true, { "meadow_b1", "meadow_b3", "meadow_c3", "meadow_d2", "meadow_d5", "meadow_e3" }),
	zone("pond_edge", "the pond's edge", true, { "pond_a1", "pond_b1", "deck_n2", "deck_s3" }), -- (ROBLOX-122: built; its threads snag on the sedge, the rushes and the boardwalk's rail)
	zone("log_pile", "the log pile", false, {}),
	zone("veteran_oak", "the old oak", false, {}),
	zone("stone_wall", "the stone wall", false, {}),
	zone("bramble", "the bramble by the railway", false, {}),
	zone("compost", "the compost bays", false, {}),
}) :: { Zone }
local BY_ZONE: { [string]: Zone } = {}
for _, z in Ballooning.ZONES do BY_ZONE[z.zone] = z end
function Ballooning.zone(id: string): Zone?
	return BY_ZONE[id]
end

-- A zone's distance from the hut (metres, home range to home range: World/Preserve.HOME_RANGES).
function Ballooning.distance(id: string): number
	local hut, here = nil :: Preserve.HomeRange?, nil :: Preserve.HomeRange?
	for _, h in Preserve.HOME_RANGES do
		if h.id == "ranger_hut" then hut = h end
		if h.id == id then here = h end
	end
	if hut == nil or here == nil then return math.huge end
	return math.sqrt((here.at[1] - hut.at[1]) ^ 2 + (here.at[2] - hut.at[2]) ^ 2)
end
-- A zone's weight in the draw (0 for one not built).
function Ballooning.weight(z: Zone): number
	if not z.built or #z.landings == 0 then return 0 end
	return math.exp(-Ballooning.distance(z.zone) / Ballooning.WEIGHT_M)
end

local MOD = 2147483647
local function stream(seed: number, generation: number, day: number, salt: number): () -> number
	local s = (math.floor(seed) * 83492791 + generation * 19349663 + day * 73856093 + salt * 2654435) % MOD
	if s <= 0 then s += MOD - 1 end
	return function(): number
		s = (s * 48271) % MOD
		return (s - 1) / (MOD - 1)
	end
end

-- Where the followed spiderling lands: its zone and its landing region.
function Ballooning.land(seed: number, generation: number, day: number): (string, string)
	local rand = stream(seed, generation, day, 41)
	rand()
	local total = 0
	for _, z in Ballooning.ZONES do total += Ballooning.weight(z) end
	local x = rand() * total
	local pick = Ballooning.ZONES[1]
	for _, z in Ballooning.ZONES do
		local w = Ballooning.weight(z)
		if w > 0 then
			pick = z
			x -= w
			if x <= 0 then break end
		end
	end
	local i = 1 + math.floor(rand() * #pick.landings) % #pick.landings
	return pick.zone, pick.landings[i]
end

-- Whether a start zone is one a rest may name: the hut, or a zone that can be landed in.
function Ballooning.valid(id: any): boolean
	if id == Ballooning.HUT then return true end
	local z = if type(id) == "string" then BY_ZONE[id] else nil
	return z ~= nil and z.built
end
-- Whether a landing region belongs to a start zone.
function Ballooning.landsIn(zoneId: string, region: any): boolean
	local z = BY_ZONE[zoneId]
	return z ~= nil and type(region) == "string" and table.find(z.landings, region) ~= nil
end

-- The ride from the sac to `to` (the landing region's spawn): its seconds and the seeded drift.
export type Ride = { from: Vector3, sash: Vector3, apex: Vector3, over: Vector3, to: Vector3, seconds: number, sway: number, phase: number, wind: Vector3 }
function Ballooning.ride(seed: number, generation: number, day: number, to: Vector3): Ride
	local rand = stream(seed, generation, day, 43)
	rand()
	local mid = Ballooning.SASH:Lerp(to, 0.5)
	local wind = Vector3.new(rand() - 0.5, 0, rand() - 0.5)
	local up = math.min(Ballooning.UP, 120 + (to - Ballooning.SASH).Magnitude * 0.18)
	return table.freeze({
		from = Ballooning.SAC, sash = Ballooning.SASH,
		apex = Vector3.new(mid.X + wind.X * 120, Preserve.GROUND_Y + up + rand() * 40, mid.Z + wind.Z * 60),
		over = to + Vector3.new(wind.X * 20, 40, wind.Z * 20), to = to,
		seconds = Ballooning.RIDE_S, sway = 6 + rand() * 6, phase = rand() * 2 * math.pi, wind = wind,
	})
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end
-- Where the rider is `t` seconds into the ride, and the thread's far end (ahead of it and above, downwind). Done at `seconds`: on the landing.
function Ballooning.at(r: Ride, t: number, reduced: boolean?): (Vector3, Vector3)
	local k = math.clamp(t / r.seconds, 0, 1)
	local p: Vector3
	if k < 0.12 then
		local e = k / 0.12
		p = r.from:Lerp(r.sash, e * e * (3 - 2 * e))
	elseif k < 0.86 then
		local e = (k - 0.12) / 0.74
		p = bezier(r.sash, r.apex, r.over, e)
		if not reduced then
			local s = math.sin(e * math.pi) -- (the sway is nothing at either end)
			p += Vector3.new(math.sin(t * 1.3 + r.phase) * r.sway * s, math.sin(t * 0.9 + r.phase) * r.sway * 0.4 * s, math.cos(t * 1.1 + r.phase) * r.sway * 0.6 * s)
		end
	else
		local e = (k - 0.86) / 0.14
		p = r.over:Lerp(r.to, e * e * (3 - 2 * e))
	end
	local ahead = (r.over - r.sash)
	local dir = Vector3.new(ahead.X, 0, ahead.Z)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else -Vector3.zAxis
	local thread = p + (dir * 0.6 + Vector3.yAxis).Unit * (if k < 0.95 then 30 else 30 * (1 - (k - 0.95) / 0.05))
	return p, thread
end

return table.freeze(Ballooning)
