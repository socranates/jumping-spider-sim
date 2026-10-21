--!strict
-- Ants (ROBLOX-119, the meadow's edge): ambient, not food. Small brown field ants of a hill in the meadow (World/Meadow.HILL, meadow_b4), out on its floor by day on a
-- seeded wander that keeps within `range` of the hill and turns back to it now and then, and in their nest from dusk to morning (not drawn). They pay the spider no heed.
-- Jumping spiders leave ants alone, and the ant-mimicking spider's page says why; here a strike at one is refused (Prey/PreyWorld, UI/PreyText) and it runs on. Pure and
-- seeded, no raycast; a checkpoint records the colony with the region's prey (Persistence/Checkpoint). The speeds and the sizes are the game's.
local R = require(script.Parent.PreyRandom)

local Ants = {}
Ants.__index = Ants

Ants.HOVER = 0.12 -- the body's middle over the floor: low on its legs
Ants.BODY = 0.4 -- studs long: an ant of about 4 mm
Ants.RADIUS = 0.2
Ants.WALK = { 1.6, 2.6 } -- studs a second: brisk
Ants.EDGE = 1.5
Ants.NIGHT = { from = 19.5, to = 7.5 } -- in the nest

-- `spec`: World/Meadow.ambient's (kind "ant", `home` the hill's way in, `range` round the hill's `centre`); `count`: the tier's; `soil` and `boxes` as the woodlice's.
function Ants.new(spec: any, count: number, soil: { min: Vector3, max: Vector3 }?, boxes: { { min: Vector3, max: Vector3 } }?): any
	local self: any = setmetatable({ kind = "ant", rng = R.new(spec.seed + 6007), now = 0, items = {}, boxes = {}, home = spec.home, centre = spec.centre or spec.home, range = spec.range or 40 }, Ants)
	if soil ~= nil then self.soilMin, self.soilMax, self.top = soil.min, soil.max, soil.max.Y else self.top = spec.home.Y end
	for _, b in (boxes or {}) :: { any } do table.insert(self.boxes, { min = b.min, max = b.max }) end
	for i, s in spec.starts do
		if i > count then break end
		local surf = Vector3.new(s.pos.X, self.top, s.pos.Z)
		local pos = surf + Vector3.yAxis * Ants.HOVER
		table.insert(self.items, {
			id = (spec.prefix or "") .. "ant_" .. i, kind = "ant", surface = surf, position = pos, prevPosition = pos, normal = Vector3.yAxis, heading = s.heading,
			speed = self.rng:draw(Ants.WALK), state = "walk", until_ = 0, nextTurn = self.rng:draw({ 0.4, 1.4 }), hidden = false,
		})
	end
	return self
end

-- Whether a point of the floor is free to walk: on the soil, within its range of the hill, clear of what stands there.
function Ants.free(self: any, p: Vector3): boolean
	if self.soilMin ~= nil and (p.X < self.soilMin.X + Ants.EDGE or p.X > self.soilMax.X - Ants.EDGE or p.Z < self.soilMin.Z + Ants.EDGE or p.Z > self.soilMax.Z - Ants.EDGE) then return false end
	if (Vector3.new(p.X - self.centre.X, 0, p.Z - self.centre.Z)).Magnitude > self.range then return false end
	for _, b in self.boxes do
		if p.X > b.min.X - 0.4 and p.X < b.max.X + 0.4 and p.Z > b.min.Z - 0.4 and p.Z < b.max.Z + 0.4 then return false end
	end
	return true
end

local function turned(h: Vector3, degrees: number): Vector3
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(h).Unit
end
local function night(hour: number?): boolean
	return hour ~= nil and (hour >= Ants.NIGHT.from or hour < Ants.NIGHT.to)
end

-- One fixed tick. The spider is ignored. `ctx.hour`: the life clock's hour (nil: day).
function Ants.step(self: any, dt: number, _spider: Vector3, ctx: any)
	self.now += dt
	local now = self.now
	local home = Vector3.new(self.home.X, self.top, self.home.Z)
	local inNest = night(if ctx ~= nil then ctx.hour else nil)
	for _, a in self.items do
		a.prevPosition = a.position
		if a.state == "away" then
			if not inNest then
				-- out of the nest at its way in
				a.state, a.hidden = "walk", false
				a.surface = home
				a.position = home + Vector3.yAxis * Ants.HOVER
				a.prevPosition = a.position
			end
			continue
		end
		if inNest then
			-- back to the way in, and in
			local to = home - a.surface
			if to.Magnitude <= 0.4 then a.state, a.hidden = "away", true; continue end
			a.heading = to.Unit
			a.surface += a.heading * math.min(to.Magnitude, a.speed * dt)
			a.position = a.surface + Vector3.yAxis * Ants.HOVER
			continue
		end
		if a.state == "pause" then
			if now >= a.until_ then a.state = "walk" end
			continue
		end
		if now >= a.nextTurn then
			-- a turn, now and then back toward the hill (the trail home)
			local back = home - a.surface
			if self.rng:next() < 0.25 and back.Magnitude > 2 then a.heading = Vector3.new(back.X, 0, back.Z).Unit
			else a.heading = turned(a.heading, self.rng:draw({ -50, 50 })) end
			a.nextTurn = now + self.rng:draw({ 0.4, 1.4 })
			if self.rng:next() < 0.12 then a.state = "pause"; a.until_ = now + self.rng:draw({ 0.3, 1.2 }); continue end
		end
		local nextPos = a.surface + a.heading * (a.speed * dt)
		if self:free(nextPos) then
			a.surface = nextPos
			a.position = nextPos + Vector3.yAxis * Ants.HOVER
		else
			a.heading = turned(a.heading, self.rng:draw({ 100, 200 }))
		end
	end
end

-- What a strike may hit: an ant out of the nest.
function Ants.targets(self: any): { any }
	local out = {}
	for _, a in self.items do
		if not a.hidden then table.insert(out, { creature = a, position = a.position, radius = Ants.RADIUS }) end
	end
	return out
end

-- Struck: it turns and runs on, faster for a while.
function Ants.struck(self: any, a: any)
	a.heading = -a.heading
	a.speed = Ants.WALK[2] * 1.3
	a.state = "walk"
	a.nextTurn = self.now + 1.5
end

function Ants.creatures(self: any): { any } return self.items end

function Ants.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { away = true, walk = true, pause = true }
	if type(self.items) ~= "table" then return { "ants: no list" } end
	for i, a in self.items do
		if type(a) ~= "table" or not states[a.state] then table.insert(out, `ants: {i} is in no known state`); continue end
		local p = a.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `ants: {i} is outside its region`)
		end
	end
	return out
end

return Ants
