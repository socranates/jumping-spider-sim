--!strict
-- The water (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "water (drowning)"): the pond's surface is not a place a jumping spider can live on. The sources the notebook's
-- page "Spiders and water" cites say why: most spiders are not built for it (of 166 species outside the wolf and fishing spiders tested on water, only two jumping
-- spiders rowed at all, and the jumping spiders that walked or rowed on it got no clear good of it); a fishing spider runs on the water's film, a jumping spider
-- that falls in struggles. Here the water has no box (World/Pond: nothing to stand on), and a spider whose body goes under its surface (World/Pond.inWater) is in it.
-- Pure: the client seizes the motor and holds the body at the surface while the struggle lasts, then puts it where this says or ends the life.
--
-- The struggle (`fall`, `step`): STRUGGLE seconds at the surface, thrashing (the water striders feel the ripples: Prey/Skater). Then the outcome, a seeded draw (a
-- hash of the world's seed, the life's day and the falls counted so far, kept in the rest: restores never reroll) against the chance of getting out:
--   a way out within REACH of where it went in (a stem, a leaf, a stone, a pad, the bank, a post: any box that comes up through the surface or lies on it) gives a
--   chance that falls from NEAR_CHANCE at the stem's foot to FAR_CHANCE at REACH; a LONG fall (from higher than LONG studs over the water, a plunge that takes the
--   spider under) halves it. In the standard rules the spider that does not get out drowns (a death with its own card, UI/WaterText), and a long fall into open
--   water with nothing in reach drowns, honestly. In the gentle rules (Easy, Free play) it is always pulled out: onto the way out in reach, or, with none, washed to
--   the nearest one (within RESCUE) with a notice.
-- `out` signals carry where to put the spider: on the way out's top, or on its side face just over the water.
local WorldMap = require(script.Parent.Parent.World.WorldMap)

local Water = {}
Water.__index = Water

Water.STRUGGLE = 3.0 -- seconds at the surface before the outcome
Water.REACH = 4.0 -- studs from where it went in to a way out it can reach (its legs' span and a short scramble)
Water.NEAR_CHANCE = 0.9
Water.FAR_CHANCE = 0.4
Water.LONG = 20 -- a fall from higher than this over the water is a plunge
Water.RESCUE = 120 -- how far the gentle rules look for a way out
Water.UP = 0.6 -- a way out must stand at least this far over the water to climb onto, or lie on it (a pad)
Water.CAUSE = "drowned"
Water.MOD = 2147483647

export type Box = { lo: Vector3, hi: Vector3, id: string? }
export type Record = { falls: number, out: number }

function Water.new(seed: number): any
	return setmetatable({ seed = seed, gentle = false, falls = 0, out = 0, active = nil :: any, signals = {} :: { any } }, Water)
end

-- The draw for the `n`th fall of the life's `day` (in [0, 1)): the world's seed hashed with the day and the count (World/WorldMap.seed, as a region's).
function Water.draw(seed: number, day: number, n: number): number
	local s = WorldMap.seed(seed, `water:{math.floor(day)}:{math.floor(n)}`)
	return (s - 1) / (Water.MOD - 1)
end

-- The nearest way out of the water from `at` (a point at the surface) among `boxes`: a box that comes up through the surface (its top at least UP over it) or lies on
-- it (a pad), its distance in plan, and where a spider gets onto it (its top if it is low, else its side face just over the water, the side nearest).
function Water.wayOut(at: Vector3, surface: number, boxes: { Box }, limit: number): (Box?, number, Vector3?, Vector3?)
	local best, bd, bp, bn = nil :: Box?, math.huge, nil :: Vector3?, nil :: Vector3?
	for _, b in boxes do
		if b.hi.Y < surface + 0.25 or b.lo.Y > surface + 0.5 then continue end -- (it must reach the surface and stand at or over it)
		local cx, cz = math.clamp(at.X, b.lo.X, b.hi.X), math.clamp(at.Z, b.lo.Z, b.hi.Z)
		local d = Vector3.new(at.X - cx, 0, at.Z - cz).Magnitude
		if d < bd and d <= limit then
			local low = b.hi.Y - surface < 6
			local p: Vector3, n: Vector3
			if low or d < 1e-6 then
				p, n = Vector3.new(math.clamp(at.X, b.lo.X + 0.3, b.hi.X - 0.3), b.hi.Y, math.clamp(at.Z, b.lo.Z + 0.3, b.hi.Z - 0.3)), Vector3.yAxis
			else
				-- the side face nearest, a little over the water
				local dx0, dx1, dz0, dz1 = math.abs(at.X - b.lo.X), math.abs(at.X - b.hi.X), math.abs(at.Z - b.lo.Z), math.abs(at.Z - b.hi.Z)
				local m = math.min(dx0, dx1, dz0, dz1)
				local y = surface + 1.5
				if m == dx0 then p, n = Vector3.new(b.lo.X, y, cz), -Vector3.xAxis
				elseif m == dx1 then p, n = Vector3.new(b.hi.X, y, cz), Vector3.xAxis
				elseif m == dz0 then p, n = Vector3.new(cx, y, b.lo.Z), -Vector3.zAxis
				else p, n = Vector3.new(cx, y, b.hi.Z), Vector3.zAxis end
			end
			best, bd, bp, bn = b, d, p, n
		end
	end
	return best, bd, bp, bn
end

-- The chance of getting out onto a way out `d` studs off after a fall from `drop` studs over the water.
function Water.chance(d: number, drop: number): number
	if d > Water.REACH then return 0 end
	local c = Water.NEAR_CHANCE + (Water.FAR_CHANCE - Water.NEAR_CHANCE) * math.clamp(d / Water.REACH, 0, 1)
	if drop > Water.LONG then c *= 0.5 end
	return c
end

-- The spider went in at `at` (its body at the surface), having fallen from `drop` studs over the water (0 walking in), on the life's `day`; `boxes` the world's boxes
-- near it (its region's and its neighbours'), `surface` the water's level. Decides the outcome now (it is told when the struggle ends).
function Water.fall(self: any, at: Vector3, drop: number, day: number, boxes: { Box }, surface: number)
	if self.active ~= nil then return end
	self.falls += 1
	local draw = Water.draw(self.seed, day, self.falls)
	local box, d, p, n = Water.wayOut(at, surface, boxes, Water.REACH)
	local chance = if box ~= nil then Water.chance(d, drop) else 0
	local outcome: string
	if box ~= nil and draw < chance then outcome = "out"
	elseif self.gentle then
		outcome = "pulled"
		if box == nil then box, d, p, n = Water.wayOut(at, surface, boxes, Water.RESCUE) end
		if box == nil then outcome = "lost" end
	else outcome = "drowned" end
	self.active = { at = Vector3.new(at.X, surface, at.Z), t = 0, outcome = outcome, to = p, normal = n, drop = drop, chance = chance, draw = draw, reach = d }
	table.insert(self.signals, { kind = "fell", at = self.active.at, drop = drop })
end

-- One tick. Ends the struggle with "out" or "pulled" (the place and its normal) or "drowned"; "lost" (gentle, and nothing in RESCUE) is told as "pulled" to the
-- spot it went in from, the client's own safe place.
function Water.step(self: any, dt: number)
	local a = self.active
	if a == nil then return end
	a.t += dt
	if a.t < Water.STRUGGLE then return end
	self.active = nil
	if a.outcome == "out" or a.outcome == "pulled" then self.out += 1 end
	table.insert(self.signals, { kind = a.outcome, at = a.at, to = a.to, normal = a.normal })
end

-- Where the body is held while it struggles: at the surface, bobbing a little.
function Water.heldAt(self: any): Vector3?
	local a = self.active
	if a == nil then return nil end
	return a.at + Vector3.new(0, 0.05 + 0.08 * math.sin(a.t * 9), 0)
end

function Water.struggling(self: any): boolean
	return self.active ~= nil
end

function Water.drainSignals(self: any): { any }
	local out = self.signals
	self.signals = {}
	return out
end

-- The record a rest keeps (Persistence/Checkpoint's optional `water`): the falls counted (the draws' counter) and how many got out.
function Water.defaultRecord(): Record
	return { falls = 0, out = 0 }
end
function Water.toRecord(self: any): Record
	return { falls = self.falls, out = self.out }
end
function Water.problems(d: any): { string }
	local out: { string } = {}
	if type(d) ~= "table" then return { "water: not a record" } end
	for _, k in { "falls", "out" } do
		local x = d[k]
		if type(x) ~= "number" or x ~= x or x < 0 or x > 1e9 or math.floor(x) ~= x then table.insert(out, `water: {k} is not a count`) end
	end
	if #out == 0 and d.out > d.falls then table.insert(out, "water: more got out than fell in") end
	return out
end
function Water.load(self: any, d: Record)
	self.falls, self.out, self.active = d.falls, d.out, nil
	self.signals = {}
end

return Water
