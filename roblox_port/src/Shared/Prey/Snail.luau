--!strict
-- The garden snail (ROBLOX-105, W3b part B): ambient, not food, three times the spider's length. It crawls very slowly over the bed's soil and up the foot of the
-- house wall (World/Garden.AMBIENT.wallFoot) from one seeded goal to the next (Prey/PlantWalk over a straight leg on the soil, the corner where the soil meets
-- the brick, and up the brick), resting between; it is a night animal, so by day it mostly rests and from dusk it mostly crawls (the life clock's hour, as the
-- moths'). It leaves a slime trail (`trail`, points dropped as it goes, drawn by Client/BugBodies fading over FADE_S). Its eye stalks draw in when the spider
-- comes within EYES_WU and stay in until it has gone past CALM_WU; it does not crawl with them in. Struck, it withdraws into its shell for a while and the strike
-- is refused (Prey/PreyWorld, UI/PreyText). Pure and seeded, no raycast; a checkpoint records it with the region's prey.
-- Sources (docs/NOTEBOOK_SOURCES.md, the snail page): the shell 28 to 32 mm across; the eyes on the longer upper tentacles, which are retractable; mucus from
-- the foot that aids its movement and leaves a slimy trail; mostly nocturnal, out by day after rain. The speeds, waits and distances are the game's.
local R = require(script.Parent.PreyRandom)
local PlantWalk = require(script.Parent.PlantWalk)

local Snails = {}
Snails.__index = Snails

Snails.SHELL = 3.0 -- studs across: 28 to 32 mm
Snails.RADIUS = 1.5
Snails.CRAWL = { 0.07, 0.12 } -- studs a second: about a millimetre a second
Snails.EYES_WU = 5.0 -- the spider this near: the eye stalks draw in
Snails.CALM_WU = 7.0 -- and come out again once it is this far
Snails.IN_RATE = 3.0 -- the stalks' travel a second, in and out
Snails.OUT_RATE = 0.25
Snails.SHELL_S = { 25, 45 } -- in its shell this long, struck
Snails.REST_DAY = { 90, 240 }
Snails.REST_NIGHT = { 8, 30 }
Snails.DROP = 0.5 -- a trail point every this many studs crawled
Snails.TRAIL = 25 -- trail points kept (the drawing shows the newest 24 legs at the full tier)
Snails.FADE_S = 240 -- seconds for a trail to fade
Snails.EDGE = 2.0
Snails.WALL = -24 -- the house wall's face (z)

-- `spec`: one of World/Garden.ambient's (kind "snail"); `count`: the tier's; `soil` the soil's top box; `boxes` the standing boxes' footprints.
function Snails.new(spec: any, count: number, soil: { min: Vector3, max: Vector3 }, boxes: { { min: Vector3, max: Vector3 } }): any
	local self: any = setmetatable({ kind = "snail", rng = R.new(spec.seed + 4057), now = 0, boxes = {}, items = {}, rect = spec.rect,
		soilMin = soil.min, soilMax = soil.max, top = soil.max.Y }, Snails)
	for _, b in boxes do table.insert(self.boxes, { min = b.min, max = b.max }) end
	for i, s in spec.starts do
		if i > count then break end
		local surf = Vector3.new(s.pos.X, self.top, s.pos.Z)
		table.insert(self.items, {
			id = (spec.prefix or "") .. "snail_" .. i, kind = "snail", surface = surf, position = surf, prevPosition = surf, normal = Vector3.yAxis, heading = s.heading,
			speed = self.rng:draw(Snails.CRAWL), state = "rest", until_ = self.rng:draw({ 3, 12 }), walk = nil, eyes = 1.0, trail = {}, lastDrop = surf,
			crawled = 0, hidden = false,
		})
	end
	return self
end

-- Whether a point on the soil is clear for the shell (inside the soil's edge, in no standing box's footprint grown by `margin`).
function Snails.free(self: any, p: Vector3, margin: number): boolean
	if p.X < self.soilMin.X + Snails.EDGE or p.X > self.soilMax.X - Snails.EDGE or p.Z < self.soilMin.Z + Snails.EDGE or p.Z > self.soilMax.Z - 0.6 then return false end
	for _, b in self.boxes do
		if p.X > b.min.X - margin and p.X < b.max.X + margin and p.Z > b.min.Z - margin and p.Z < b.max.Z + margin then return false end
	end
	return true
end

-- Whether a straight leg over the soil is clear all the way.
local function clearLeg(self: any, a: Vector3, b: Vector3): boolean
	local n = math.max(1, math.ceil((b - a).Magnitude / 0.5))
	for i = 0, n do
		if not self:free(a:Lerp(b, i / n), 1.0) then return false end
	end
	return true
end

-- A new goal and the walk to it: a seeded spot on the soil, or (a third of the time) on the wall's foot, by way of the corner. False when no clear leg was found.
local function setOff(self: any, s: any): boolean
	local Y, Z = Vector3.yAxis, -Vector3.zAxis
	local onWall = s.normal.Z < -0.5
	for _ = 1, 8 do
		local path: { any }
		if self.rng:next() < 0.33 and self.rect ~= nil then
			-- the wall's foot: up the brick from the corner below the goal
			local x = self.rng:draw(self.rect.x)
			local y = self.top + self.rng:draw(self.rect.y)
			local foot = Vector3.new(x, self.top, Snails.WALL)
			local goal = Vector3.new(x, y, Snails.WALL)
			if onWall then
				path = { { pos = goal, normal = Z } }
			else
				local approach = Vector3.new(x, self.top, Snails.WALL - 2.0)
				if not clearLeg(self, s.surface, approach) then continue end
				path = { { pos = approach, normal = Y }, { pos = foot, normal = (Y + Z).Unit }, { pos = goal, normal = Z } }
			end
		else
			local goal = Vector3.new(self.rng:draw({ self.soilMin.X + Snails.EDGE, self.soilMax.X - Snails.EDGE }), self.top,
				self.rng:draw({ self.soilMin.Z + Snails.EDGE, self.soilMax.Z - 2.5 }))
			if onWall then
				local foot = Vector3.new(s.surface.X, self.top, Snails.WALL)
				local away = Vector3.new(s.surface.X, self.top, Snails.WALL - 2.0)
				if not self:free(away, 1.0) or not clearLeg(self, away, goal) then continue end
				path = { { pos = foot, normal = (Y + Z).Unit }, { pos = away, normal = Y }, { pos = goal, normal = Y } }
			else
				if not self:free(goal, 1.0) or not clearLeg(self, s.surface, goal) then continue end
				path = { { pos = goal, normal = Y } }
			end
		end
		s.walk = PlantWalk.new(path, s.surface, s.normal)
		s.state = "crawl"
		return true
	end
	return false
end

local function night(hour: number?): boolean
	return hour ~= nil and (hour >= 18 or hour < 6)
end

-- One fixed tick. `ctx.hour`: the life clock's hour (nil: day).
function Snails.step(self: any, dt: number, spider: Vector3, ctx: any)
	self.now += dt
	local now = self.now
	local hour = if ctx ~= nil then ctx.hour else nil
	-- the trail dries
	for _, s in self.items do
		s.prevPosition = s.position
		while #s.trail > 0 and now - s.trail[#s.trail].t > Snails.FADE_S do table.remove(s.trail) end
		local d = (spider - s.position).Magnitude
		if s.state ~= "shell" then
			if d <= Snails.EYES_WU then s.eyes = math.max(0, s.eyes - Snails.IN_RATE * dt)
			elseif d >= Snails.CALM_WU then s.eyes = math.min(1, s.eyes + Snails.OUT_RATE * dt) end
		end
		if s.state == "shell" then
			if now >= s.until_ then
				-- out again: a crawl it was on goes on (once its eyes are out), else it rests a little
				if s.walk ~= nil then s.state = "crawl" else s.state = "rest"; s.until_ = now + self.rng:draw({ 4, 10 }) end
			end
		elseif s.state == "rest" then
			if now >= s.until_ and s.eyes >= 0.6 then
				if not setOff(self, s) then s.until_ = now + self.rng:draw({ 5, 15 }) end
			end
		elseif s.state == "crawl" and s.walk ~= nil then
			if s.eyes >= 0.6 then
				local p, n, dir, done = PlantWalk.advance(s.walk, s.speed * dt)
				s.crawled += (p - s.surface).Magnitude
				s.surface, s.normal = p, n
				if dir.Magnitude > 0.5 then s.heading = dir end
				s.position = p
				if (p - s.lastDrop).Magnitude >= Snails.DROP then
					table.insert(s.trail, 1, { p = p, n = n, t = now })
					while #s.trail > Snails.TRAIL do table.remove(s.trail) end
					s.lastDrop = p
				end
				if done then
					s.walk = nil
					s.state = "rest"
					s.until_ = now + self.rng:draw(if night(hour) then Snails.REST_NIGHT else Snails.REST_DAY)
				end
			end
		end
	end
end

-- What a strike may hit: the shell.
function Snails.targets(self: any): { any }
	local out = {}
	for _, s in self.items do
		table.insert(out, { creature = s, position = s.position + s.normal * (Snails.SHELL * 0.5), radius = Snails.RADIUS })
	end
	return out
end

-- Struck by the spider: into its shell.
function Snails.struck(self: any, s: any)
	s.state = "shell"
	s.eyes = 0
	s.until_ = self.now + self.rng:draw(Snails.SHELL_S) -- (a crawl under way is kept and taken up again once it is out)
end

function Snails.creatures(self: any): { any } return self.items end

function Snails.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { rest = true, crawl = true, shell = true }
	if type(self.items) ~= "table" then return { "snails: no list" } end
	for i, s in self.items do
		if type(s) ~= "table" or not states[s.state] then table.insert(out, `snails: {i} is in no known state`); continue end
		local p = s.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `snails: {i} is outside its region`)
		end
		if type(s.trail) ~= "table" or #s.trail > Snails.TRAIL then table.insert(out, `snails: {i} has a trail beyond belief`) end
		if type(s.eyes) ~= "number" or s.eyes < 0 or s.eyes > 1 then table.insert(out, `snails: {i}'s eyes are nowhere`) end
		if s.state == "crawl" and s.walk == nil then table.insert(out, `snails: {i} crawls nowhere`) end
		if s.walk ~= nil then
			local why = PlantWalk.problem(s.walk)
			if why ~= nil then table.insert(out, `snails: {i}: {why}`) end
		end
	end
	return out
end

return Snails
