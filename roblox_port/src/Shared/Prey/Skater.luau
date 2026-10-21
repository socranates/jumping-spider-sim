--!strict
-- Water striders (ROBLOX-122, the pond's edge): ambient, not the spider's food here. Common water striders (Gerridae) on the open water of the pond's margin
-- (World/Pond.LIFE.skaters): they stand on the surface on their long water-repellent middle and hind legs, row with the middle pair in a quick stroke and glide,
-- turn, rest, and keep to the open water between the pads and the stems. They are predators of what falls onto the water and struggles there, the sources say, a
-- spider among it, and they find it by its ripples: while the spider is struggling in the water (`ctx.ripple`, Life/Water through Prey/PreyWorld) the ones within
-- RIPPLE turn and skate toward it, a few studs off. They do not harm it here (the struggle is the water's). By night they rest where they are. A strike at one is
-- refused (Prey/PreyWorld, UI/PreyText): it skates off. Pure and seeded, no raycast; a checkpoint records the colony with the region's prey. The speeds are the game's.
local R = require(script.Parent.PreyRandom)

local Skaters = {}
Skaters.__index = Skaters

Skaters.HOVER = 0.15 -- the body's middle over the surface: up on its legs
Skaters.BODY = 1.2 -- studs long: a strider of about 12 mm (the sources: 1/2 to 3/4 inch for the large one, Gerris under 1/2 inch)
Skaters.RADIUS = 0.4
Skaters.STROKE = { 18, 36 } -- studs a second at a stroke's start
Skaters.DRAG = 3.2 -- how fast a glide slows (a second's share)
Skaters.REST = { 0.4, 2.5 } -- seconds between strokes
Skaters.EDGE = 2.0
Skaters.RIPPLE = 60 -- studs: how far a struggling thing's ripples draw them
Skaters.CLOSE = 5 -- and how near they come
Skaters.NIGHT = { from = 20.5, to = 6.5 }

-- `spec`: World/Pond.ambient's (kind "skater", `water` the open water's rectangle, `boxes` the stems, pads and stones it skates round); `count`: the tier's.
function Skaters.new(spec: any, count: number): any
	local self: any = setmetatable({ kind = "skater", rng = R.new(spec.seed + 6011), now = 0, items = {}, boxes = {}, waterMin = spec.water.min, waterMax = spec.water.max }, Skaters)
	self.top = spec.water.max.Y
	for _, b in (spec.boxes or {}) :: { any } do table.insert(self.boxes, { min = b.min, max = b.max }) end
	for i, s in spec.starts do
		if i > count then break end
		local surf = Vector3.new(s.pos.X, self.top, s.pos.Z)
		local pos = surf + Vector3.yAxis * Skaters.HOVER
		table.insert(self.items, {
			id = (spec.prefix or "") .. "skater_" .. i, kind = "skater", surface = surf, position = pos, prevPosition = pos, normal = Vector3.yAxis, heading = s.heading,
			speed = 0, state = "rest", until_ = self.rng:draw(Skaters.REST), hidden = false,
		})
	end
	return self
end

-- Whether a point of the surface is open water to skate: inside the rectangle, clear of what stands in it.
function Skaters.free(self: any, p: Vector3): boolean
	if p.X < self.waterMin.X + Skaters.EDGE or p.X > self.waterMax.X - Skaters.EDGE or p.Z < self.waterMin.Z + Skaters.EDGE or p.Z > self.waterMax.Z - Skaters.EDGE then return false end
	for _, b in self.boxes do
		if b.max.Y >= self.top - 0.5 and p.X > b.min.X - 0.8 and p.X < b.max.X + 0.8 and p.Z > b.min.Z - 0.8 and p.Z < b.max.Z + 0.8 then return false end
	end
	return true
end

local function turned(h: Vector3, degrees: number): Vector3
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(h).Unit
end
local function night(hour: number?): boolean
	return hour ~= nil and (hour >= Skaters.NIGHT.from or hour < Skaters.NIGHT.to)
end

-- One fixed tick. `ctx.hour`: the life clock's hour (nil: day); `ctx.ripple`: where something struggles in the water now (nil: nothing).
function Skaters.step(self: any, dt: number, _spider: Vector3, ctx: any)
	self.now += dt
	local now = self.now
	local ripple: any = if ctx ~= nil then ctx.ripple else nil
	local resting = night(if ctx ~= nil then ctx.hour else nil)
	for _, a in self.items do
		a.prevPosition = a.position
		local toward: any = nil
		if ripple ~= nil then
			local d = Vector3.new(ripple.X - a.surface.X, 0, ripple.Z - a.surface.Z)
			if d.Magnitude < Skaters.RIPPLE and d.Magnitude > Skaters.CLOSE then toward = d.Unit end
		end
		if a.state == "glide" then
			a.speed *= math.max(0, 1 - Skaters.DRAG * dt)
			local nextPos = a.surface + a.heading * (a.speed * dt)
			if self:free(nextPos) then
				a.surface = nextPos
			else
				a.heading = turned(-a.heading, self.rng:draw({ -40, 40 }))
				a.speed *= 0.4
			end
			if a.speed < 1.0 then
				a.state, a.speed = "rest", 0
				a.until_ = now + (if toward ~= nil then 0.2 else self.rng:draw(Skaters.REST))
			end
		elseif now >= a.until_ and not resting or (toward ~= nil and now >= a.until_) then
			-- a stroke: a turn now and then, or toward the ripples
			if toward ~= nil then a.heading = toward
			elseif self.rng:next() < 0.6 then a.heading = turned(a.heading, self.rng:draw({ -120, 120 })) end
			a.state, a.speed = "glide", self.rng:draw(Skaters.STROKE)
			a.strokeAt = now
		end
		a.position = a.surface + Vector3.yAxis * Skaters.HOVER
	end
end

-- What a strike may hit: a strider on the water.
function Skaters.targets(self: any): { any }
	local out = {}
	for _, a in self.items do table.insert(out, { creature = a, position = a.position, radius = Skaters.RADIUS }) end
	return out
end

-- Struck: it skates off at once, away.
function Skaters.struck(self: any, a: any)
	a.heading = -a.heading
	a.state, a.speed = "glide", Skaters.STROKE[2]
end

function Skaters.creatures(self: any): { any } return self.items end

function Skaters.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { rest = true, glide = true }
	if type(self.items) ~= "table" then return { "skaters: no list" } end
	for i, a in self.items do
		if type(a) ~= "table" or not states[a.state] then table.insert(out, `skaters: {i} is in no known state`); continue end
		local p = a.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `skaters: {i} is outside its region`)
		end
	end
	return out
end

return Skaters
