--!strict
-- The crab spiders of the meadow's edge (ROBLOX-119, docs/PARK_WORLD_DESIGN.md zone 3; the notebook's page "The crab spider on the flower" says what is known of them):
-- the goldenrod crab spider, Misumena vatia, sits still on a flower in the flower's colour with its first two pairs of legs held open, and grabs what comes in reach.
-- Here two of them live on the meadow's flowers (World/Meadow.CRAB_SITES): a yellow one on a goldenrod's plume and a white one on a yarrow's head, each on one of its two
-- flowers a day (a seeded draw per day: where it is at a day is a pure function of the seed and the day, so a return to a rest finds it where it was).
--
-- What it does to a jumping spider is what it does to anything that comes to its flower: one that walks or lands within its reach (REACH, from its body's middle) and
-- stays there LATENCY seconds is grabbed. In the standard rules that is a death with its own card (UI/CrabText); in the gentle rules (Easy, Free play) it lunges and the
-- spider drops clear (a "nudged" signal: Client/SpiderClient knocks it off the flower) and it waits COOLDOWN seconds. The honest tell, for a careful player, is how it is
-- drawn (Client/CrabBody): its front legs held wide, its colour a shade off the flower's, and a crab spider's shape. A spider in a retreat is never in reach. Its first
-- close look (within SEEN) opens its page ("seen"). Nothing of it is saved: its day is the seed's, and a grab under way is not kept, as a wasp's visit is not.
-- Simplifications, said here: it never leaves its flower in a day, and it does not hunt the flies of the meadow (it is drawn with a caught one some days).
local WorldMap = require(script.Parent.Parent.World.WorldMap)
local Meadow = require(script.Parent.Parent.World.Meadow)

local CrabSpider = {}
CrabSpider.__index = CrabSpider

CrabSpider.REACH = 2.2 -- studs from its body's middle to the jumping spider's: its open front legs (a female's are about as long as her body) and the spider's own body
CrabSpider.LATENCY = 0.3 -- seconds in reach before the legs close
CrabSpider.SEEN = 9 -- studs: the first close look opens its page
CrabSpider.COOLDOWN = 8 -- seconds after a lunge in the gentle rules before it can lunge again
CrabSpider.LIFT = 0.25 -- its body's middle over the flower's top (its legs on the florets)
CrabSpider.HOLDING = 0.3 -- the share of days it is drawn holding a caught fly
CrabSpider.CAUSE = "crab_spider"

export type Crab = { site: number, form: string, region: string, pos: Vector3, top: Vector3, heading: Vector3, touch: number, cooldown: number, strike: number, holding: boolean }
export type Signal = { kind: string, at: Vector3?, away: Vector3? }
export type Spider = { pos: Vector3, hidden: boolean }

local MOD = 2147483647
-- The day's draw for crab spider `k` (in [0, 1)): a Park-Miller step from the seed, the crab and the day.
local function draw(seed: number, k: number, day: number, salt: number): number
	local s = (seed + k * 7919 + day * 104729 + salt * 15485863) % MOD
	if s <= 0 then s += MOD - 1 end
	for _ = 1, 3 do s = (s * 48271) % MOD end
	return (s - 1) / (MOD - 1)
end

-- Which of its two flowers crab spider `k` sits on, on `day` (1 or 2), and whether it holds a caught fly.
function CrabSpider.siteOf(seed: number, k: number, day: number): (number, boolean)
	return 1 + math.floor(draw(seed, k, day, 1) * 2), draw(seed, k, day, 2) < CrabSpider.HOLDING
end

-- The top of a site's flower head (the active world's map: the preserve's; nil where there is none).
local tops: { [string]: Vector3 } = {}
function CrabSpider.topOf(site: Meadow.CrabSite): Vector3?
	local key = site.piece
	local known = tops[key]
	if known then return known end
	local region = WorldMap.region(site.region)
	if region == nil then return nil end
	for _, p in Meadow.pieces(region :: any) do
		if p.id == site.piece then
			local top = Vector3.new((p.lo.X + p.hi.X) / 2, p.hi.Y, (p.lo.Z + p.hi.Z) / 2)
			tops[key] = top
			return top
		end
	end
	return nil
end

function CrabSpider.new(seed: number): any
	return setmetatable({
		seed = seed, gentle = false, enabled = true, day = -1, crabs = {} :: { Crab }, signals = {} :: { Signal }, met = false,
		grabs = 0, lunges = 0, now = 0, -- (this session's: the self-test reads them)
	}, CrabSpider)
end

-- Start another life without invalidating references held by the client/presentation.
-- Seeded schedules and enable/rule configuration survive; reactions and signals do not.
function CrabSpider.reset(self: any)
	local clean = CrabSpider.new(self.seed)
	clean.enabled, clean.gentle = self.enabled, self.gentle
	table.clear(self)
	for key, value in clean do self[key] = value end
end

-- Puts each crab spider on its flower for `day`.
function CrabSpider.place(self: any, day: number)
	self.day = day
	table.clear(self.crabs)
	for k, sites in Meadow.CRAB_SITES do
		local i, holding = CrabSpider.siteOf(self.seed, k, day)
		local site = sites[i]
		local top = CrabSpider.topOf(site)
		if top ~= nil then
			local a = draw(self.seed, k, day, 3) * 2 * math.pi
			table.insert(self.crabs, {
				site = i, form = site.form, region = site.region, top = top, pos = top + Vector3.yAxis * CrabSpider.LIFT, heading = Vector3.new(math.cos(a), 0, math.sin(a)),
				touch = 0, cooldown = 0, strike = -1, holding = holding,
			})
		end
	end
end

local function signal(self: any, kind: string, at: Vector3?, away: Vector3?)
	table.insert(self.signals, { kind = kind, at = at, away = away })
end

-- One tick: `spider` nil while there is no life to touch (the end screen, a menu).
function CrabSpider.step(self: any, dt: number, day: number, _hour: number, spider: Spider?)
	self.now += dt
	if day ~= self.day then self:place(day) end
	for _, c in self.crabs do
		if c.strike >= 0 then c.strike += dt; if c.strike > 0.6 then c.strike = -1 end end
		if c.cooldown > 0 then c.cooldown = math.max(0, c.cooldown - dt) end
		if spider == nil or not self.enabled or spider.hidden then c.touch = 0; continue end
		local d = (spider.pos - c.pos).Magnitude
		if d <= CrabSpider.SEEN and not self.met then
			self.met = true
			signal(self, "seen", c.pos)
		end
		if d <= CrabSpider.REACH and c.cooldown <= 0 then
			c.touch += dt
			if c.touch >= CrabSpider.LATENCY then
				c.touch = 0
				c.strike = 0
				if self.gentle then
					local away = Vector3.new(spider.pos.X - c.pos.X, 0, spider.pos.Z - c.pos.Z)
					away = if away.Magnitude > 1e-3 then away.Unit else -c.heading
					c.cooldown = CrabSpider.COOLDOWN
					self.lunges += 1
					signal(self, "nudged", c.pos, away)
				else
					self.grabs += 1
					c.cooldown = CrabSpider.COOLDOWN
					signal(self, "struck", c.pos)
				end
			end
		else
			c.touch = 0
		end
	end
end

-- Takes the signals since the last call.
function CrabSpider.drainSignals(self: any): { Signal }
	local out = self.signals
	self.signals = {}
	return out
end

-- The nearest crab spider to a point, and how far (nil when none is placed).
function CrabSpider.nearest(self: any, at: Vector3): (Crab?, number)
	local best, bd = nil, math.huge
	for _, c in self.crabs do
		local d = (c.pos - at).Magnitude
		if d < bd then best, bd = c, d end
	end
	return best, bd
end

return CrabSpider
