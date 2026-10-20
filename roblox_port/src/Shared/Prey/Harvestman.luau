--!strict
-- Harvestmen (ROBLOX-105, W3b part B): ambient, not food, not spiders: a small oval body high on eight very long legs. One walks the bed's soil and litter and one
-- the house wall's brick, from dusk through the night (the life clock's hour, as the moths'); by day each is away in its corner (the bed's first litter hide
-- spot, the wall's foot at its west end) and is not drawn. It walks its surface on a seeded wander, round what stands on the soil, and pays the spider no heed:
-- it neither hides nor hurries. Struck, the strike is refused (Prey/PreyWorld, UI/PreyText) and it walks on. Pure and seeded, no raycast; a checkpoint records
-- it with the region's prey.
-- Sources (docs/NOTEBOOK_SOURCES.md, the harvestman page): one oval body, two eyes, no silk and no venom glands; a foul odour when disturbed; legs that come off
-- easily and twitch; mostly active at night or in shade. The speeds and the leg lengths drawn are the game's.
local R = require(script.Parent.PreyRandom)

local Harvestmen = {}
Harvestmen.__index = Harvestmen

Harvestmen.HOVER = 0.9 -- the body's centre above the surface: it rides high on its legs
Harvestmen.BODY = 0.5 -- studs long: a body about 5 mm
Harvestmen.RADIUS = 0.35
Harvestmen.WALK = { 0.8, 1.4 } -- studs a second
Harvestmen.EDGE = 1.5
Harvestmen.DUSK = { from = 18, to = 6 }

-- `spec`: one of World/Garden.ambient's (kind "harvestman", surface "soil" or "wall"); `count`: the tier's; for the soil, `soil` and `boxes` as the woodlice's.
function Harvestmen.new(spec: any, count: number, soil: { min: Vector3, max: Vector3 }?, boxes: { { min: Vector3, max: Vector3 } }?): any
	local self: any = setmetatable({ kind = "harvestman", rng = R.new(spec.seed + 5059), now = 0, items = {}, boxes = {}, surface = spec.surface or "soil",
		home = spec.home, rect = spec.rect }, Harvestmen)
	if soil ~= nil then self.soilMin, self.soilMax, self.top = soil.min, soil.max, soil.max.Y end
	for _, b in (boxes or {}) :: { any } do table.insert(self.boxes, { min = b.min, max = b.max }) end
	local normal = if self.surface == "wall" then -Vector3.zAxis else Vector3.yAxis
	for i, s in spec.starts do
		if i > count then break end
		local surf = if self.surface == "wall" then s.pos else Vector3.new(s.pos.X, self.top, s.pos.Z)
		local pos = surf + normal * Harvestmen.HOVER
		table.insert(self.items, {
			id = (spec.prefix or "") .. "harvestman_" .. i, kind = "harvestman", surface = surf, position = pos, prevPosition = pos, normal = normal, heading = s.heading,
			speed = self.rng:draw(Harvestmen.WALK), state = "away", until_ = 0, nextTurn = self.rng:draw({ 1, 3 }), hidden = true,
		})
	end
	return self
end

-- Whether a point of its surface is free to stand over.
function Harvestmen.free(self: any, p: Vector3): boolean
	if self.surface == "wall" then
		local r = self.rect
		return p.X >= r.x[1] and p.X <= r.x[2] and p.Y >= r.y[1] and p.Y <= r.y[2]
	end
	if p.X < self.soilMin.X + Harvestmen.EDGE or p.X > self.soilMax.X - Harvestmen.EDGE or p.Z < self.soilMin.Z + Harvestmen.EDGE or p.Z > self.soilMax.Z - Harvestmen.EDGE then return false end
	for _, b in self.boxes do
		if p.X > b.min.X - 0.6 and p.X < b.max.X + 0.6 and p.Z > b.min.Z - 0.6 and p.Z < b.max.Z + 0.6 then return false end
	end
	return true
end

-- The heading turned by `degrees` about the surface's normal.
local function turned(self: any, h: Vector3, degrees: number): Vector3
	local n = if self.surface == "wall" then -Vector3.zAxis else Vector3.yAxis
	return CFrame.fromAxisAngle(n, math.rad(degrees)):VectorToWorldSpace(h).Unit
end

local function dusk(hour: number?): boolean
	return hour ~= nil and (hour >= Harvestmen.DUSK.from or hour < Harvestmen.DUSK.to)
end

-- One fixed tick. The spider is ignored. `ctx.hour`: the life clock's hour (nil: day).
function Harvestmen.step(self: any, dt: number, _spider: Vector3, ctx: any)
	self.now += dt
	local now = self.now
	local out = dusk(if ctx ~= nil then ctx.hour else nil)
	for _, h in self.items do
		h.prevPosition = h.position
		if h.state == "away" then
			if out then
				-- out from its corner
				h.state = "walk"; h.hidden = false
				local home = self.home
				if home ~= nil then
					h.surface = if self.surface == "wall" then home else Vector3.new(home.X, self.top, home.Z)
					h.position = h.surface + h.normal * Harvestmen.HOVER
					h.prevPosition = h.position
				end
			end
			continue
		end
		if not out and self.home ~= nil then
			-- day: back to its corner
			local home = if self.surface == "wall" then self.home else Vector3.new(self.home.X, self.top, self.home.Z)
			local to = home - h.surface
			if to.Magnitude <= 0.3 then h.state = "away"; h.hidden = true; continue end
			h.heading = to.Unit
			h.surface += h.heading * math.min(to.Magnitude, h.speed * dt)
			h.position = h.surface + h.normal * Harvestmen.HOVER
			continue
		end
		if h.state == "pause" then
			if now >= h.until_ then h.state = "walk" end
			continue
		end
		if now >= h.nextTurn then
			h.heading = turned(self, h.heading, self.rng:draw({ -60, 60 }))
			h.nextTurn = now + self.rng:draw({ 1, 3 })
			if self.rng:next() < 0.2 then h.state = "pause"; h.until_ = now + self.rng:draw({ 1, 5 }); continue end
		end
		local nextPos = h.surface + h.heading * (h.speed * dt)
		if self:free(nextPos) then
			h.surface = nextPos
			h.position = nextPos + h.normal * Harvestmen.HOVER
		else
			h.heading = turned(self, h.heading, self.rng:draw({ 100, 200 }))
		end
	end
end

-- What a strike may hit: the body, while it is out.
function Harvestmen.targets(self: any): { any }
	local out = {}
	for _, h in self.items do
		if not h.hidden then table.insert(out, { creature = h, position = h.position, radius = Harvestmen.RADIUS }) end
	end
	return out
end

-- Struck: it walks on.
function Harvestmen.struck(_self: any, _h: any) end

function Harvestmen.creatures(self: any): { any } return self.items end

function Harvestmen.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { away = true, walk = true, pause = true }
	if type(self.items) ~= "table" then return { "harvestmen: no list" } end
	if self.surface ~= "soil" and self.surface ~= "wall" then table.insert(out, "harvestmen: on no known surface") end
	for i, h in self.items do
		if type(h) ~= "table" or not states[h.state] then table.insert(out, `harvestmen: {i} is in no known state`); continue end
		local p = h.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `harvestmen: {i} is outside its region`)
		end
	end
	return out
end

return Harvestmen
