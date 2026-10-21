--!strict
-- Millipedes (ROBLOX-105, W3b part B): ambient, not food. A seeded few in the bed walk the soil slowly round what stands on it, as the woodlice do (Prey/Woodlouse),
-- and now and then go under the stones for a while (the hide spots by the stones the woodlice use). The body follows the head: the head's track is kept as a
-- trail of points (`trail`), and Client/BugBodies lays the rings along it. When the spider comes within COIL_WU it stops and coils, head in the middle; it stays
-- coiled until the spider has been gone a while, then uncoils and walks on. Struck, it coils at once and the strike is refused (Prey/PreyWorld, UI/PreyText).
-- Pure and seeded, no raycast; a checkpoint records it with the region's prey (Persistence/Checkpoint's `garden` root, the region's `ambient`).
-- Sources (docs/NOTEBOOK_SOURCES.md, the millipede page): two pairs of legs on each segment; most feed on decaying vegetation and live in soil and leaf mould and
-- beneath stones; threatened, most roll into a coil with the legs inside, and some release foul-tasting or foul-smelling substances. Speeds and waits are the game's.
local R = require(script.Parent.PreyRandom)

local Millipedes = {}
Millipedes.__index = Millipedes

Millipedes.HOVER = 0.12 -- the rings' centres above the soil
Millipedes.RINGS = 12 -- body rings drawn behind the head
Millipedes.SPACING = 0.19 -- studs from ring to ring: a body about 2.4 cm long
Millipedes.RADIUS = 0.3
Millipedes.WALK = { 0.15, 0.28 } -- studs a second
Millipedes.COIL_WU = 2.5 -- the spider this near makes it coil
Millipedes.CALM_WU = 5.0 -- it uncoils once the spider is this far, and has been for CALM_S
Millipedes.CALM_S = { 6, 12 }
Millipedes.COIL_S = 1.0 -- seconds to coil
Millipedes.UNCOIL_S = 2.5
Millipedes.UNDER_EVERY = { 60, 140 } -- how often it goes under a stone
Millipedes.UNDER_S = { 20, 45 } -- and how long it stays
Millipedes.EDGE = 1.0
Millipedes.TURN = 90 -- degrees a second it turns at, walking on: it steers round in an arc, never folds back on itself
Millipedes.AHEAD = 0.8 -- how far ahead it feels for what stands in its way

-- `spec`: one of World/Garden.ambient's (kind "millipede"); `count`: the tier's; `soil` the soil's top box; `boxes` the standing boxes' footprints.
function Millipedes.new(spec: any, count: number, soil: { min: Vector3, max: Vector3 }, boxes: { { min: Vector3, max: Vector3 } }): any
	local self: any = setmetatable({ kind = "millipede", rng = R.new(spec.seed + 3041), now = 0, hides = {}, boxes = {}, items = {},
		soilMin = soil.min, soilMax = soil.max, top = soil.max.Y }, Millipedes)
	for _, h in spec.hides or {} do table.insert(self.hides, { pos = h.pos, kind = h.kind }) end
	for _, b in boxes do table.insert(self.boxes, { min = b.min, max = b.max }) end
	for i, s in spec.starts do
		if i > count then break end
		local pos = Vector3.new(s.pos.X, self.top + Millipedes.HOVER, s.pos.Z)
		local trail = {}
		for k = 1, Millipedes.RINGS do table.insert(trail, pos - s.heading * (k * Millipedes.SPACING)) end
		table.insert(self.items, {
			id = (spec.prefix or "") .. "millipede_" .. i, kind = "millipede", position = pos, prevPosition = pos, heading = s.heading, normal = Vector3.yAxis,
			speed = self.rng:draw(Millipedes.WALK), state = "walk", coil = 0, until_ = 0, nextTurn = self.rng:draw({ 2, 5 }),
			nextUnder = self.rng:draw(Millipedes.UNDER_EVERY), hide = 0, trail = trail, hidden = false, turn = 0,
		})
	end
	return self
end

-- Whether a point on the soil is free to stand on (inside the soil's edge, in no standing box's footprint grown by `margin`).
function Millipedes.free(self: any, p: Vector3, margin: number): boolean
	if p.X < self.soilMin.X + Millipedes.EDGE or p.X > self.soilMax.X - Millipedes.EDGE or p.Z < self.soilMin.Z + Millipedes.EDGE or p.Z > self.soilMax.Z - Millipedes.EDGE then return false end
	for _, b in self.boxes do
		if p.X > b.min.X - margin and p.X < b.max.X + margin and p.Z > b.min.Z - margin and p.Z < b.max.Z + margin then return false end
	end
	return true
end

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function turned(heading: Vector3, degrees: number): Vector3
	local a = math.atan2(heading.Z, heading.X) + math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- The head moved: drop a trail point once it is a ring's spacing from the last.
local function track(m: any)
	local last = m.trail[1]
	if last == nil or (m.position - last).Magnitude >= Millipedes.SPACING then
		table.insert(m.trail, 1, m.position)
		while #m.trail > Millipedes.RINGS + 1 do table.remove(m.trail) end
	end
end

-- One fixed tick. `spider`: where the spider is.
function Millipedes.step(self: any, dt: number, spider: Vector3, _ctx: any)
	self.now += dt
	local now = self.now
	for _, m in self.items do
		m.prevPosition = m.position
		local d = (flat(spider) - flat(m.position)).Magnitude
		local near = d <= Millipedes.COIL_WU and math.abs(spider.Y - m.position.Y) < 4
		if near and (m.state == "walk" or m.state == "pause" or m.state == "going") then m.state = "coiled"; m.until_ = math.huge end
		if m.state == "coiled" then
			m.coil = math.min(1, m.coil + dt / Millipedes.COIL_S)
			if d >= Millipedes.CALM_WU then
				if m.until_ == math.huge then m.until_ = now + self.rng:draw(Millipedes.CALM_S) end
				if now >= m.until_ then m.state = "walk"; m.nextTurn = now + self.rng:draw({ 2, 5 }) end
			else
				m.until_ = math.huge
			end
		elseif m.coil > 0 then
			m.coil = math.max(0, m.coil - dt / Millipedes.UNCOIL_S) -- (uncoiling: it does not walk until it is straight)
		elseif m.state == "under" then
			if now >= m.until_ then m.state = "walk"; m.hidden = false; m.heading = turned(m.heading, self.rng:draw({ 120, 240 })); m.nextUnder = now + self.rng:draw(Millipedes.UNDER_EVERY) end
		elseif m.state == "going" then
			local goal = self.hides[m.hide].pos
			local to = flat(goal) - flat(m.position)
			if to.Magnitude <= 0.25 then
				m.state = "under"; m.hidden = true; m.until_ = now + self.rng:draw(Millipedes.UNDER_S)
			else
				m.heading = to.Unit
				m.position += m.heading * math.min(to.Magnitude, m.speed * dt)
				track(m)
			end
		elseif m.state == "pause" then
			if now >= m.until_ then m.state = "walk"; m.nextTurn = now + self.rng:draw({ 2, 5 }) end
		elseif m.state == "walk" then
			if now >= m.nextUnder and #self.hides > 0 then
				local best, bestD = 0, math.huge
				for i, h in self.hides do
					local dd = (flat(h.pos) - flat(m.position)).Magnitude
					if dd < bestD then best, bestD = i, dd end
				end
				m.hide = best
				m.state = "going"
			else
				local paused = false
				if now >= m.nextTurn then
					m.turn = self.rng:draw({ -40, 40 })
					m.nextTurn = now + self.rng:draw({ 2, 5 })
					if self.rng:next() < 0.2 then m.state = "pause"; m.until_ = now + self.rng:draw({ 2, 6 }); paused = true end
				end
				if not paused then
					-- something ahead: steer away in an arc (the turn is drawn once, then taken a little each tick)
					if math.abs(m.turn or 0) < 1 and not self:free(m.position + m.heading * Millipedes.AHEAD, 0.3) then
						m.turn = (if self.rng:next() < 0.5 then -1 else 1) * self.rng:draw({ 90, 180 })
					end
					local turn = m.turn or 0
					if math.abs(turn) > 1e-6 then
						local by = math.clamp(turn, -Millipedes.TURN * dt, Millipedes.TURN * dt)
						m.heading = turned(m.heading, by)
						m.turn = turn - by
					end
					local nextPos = m.position + m.heading * (m.speed * dt)
					if self:free(nextPos, 0.3) then
						m.position = nextPos
						track(m)
					elseif math.abs(m.turn or 0) < 1 then
						m.turn = (if self.rng:next() < 0.5 then -1 else 1) * self.rng:draw({ 90, 180 })
					end
				end
			end
		end
	end
end

-- What a strike may hit: the head and the body's middle.
function Millipedes.targets(self: any): { any }
	local out = {}
	for _, m in self.items do
		if not m.hidden then
			table.insert(out, { creature = m, position = m.position, radius = Millipedes.RADIUS })
			local mid = m.trail[math.max(1, math.floor(#m.trail / 2))]
			if mid ~= nil and m.coil < 0.5 then table.insert(out, { creature = m, position = mid, radius = Millipedes.RADIUS }) end
		end
	end
	return out
end

-- Struck by the spider: it coils at once.
function Millipedes.struck(self: any, m: any)
	m.state = "coiled"
	m.until_ = math.huge
	m.coil = math.max(m.coil, 0.5)
end

function Millipedes.creatures(self: any): { any } return self.items end

function Millipedes.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { walk = true, pause = true, coiled = true, going = true, under = true }
	if type(self.items) ~= "table" then return { "millipedes: no list" } end
	for i, m in self.items do
		if type(m) ~= "table" or not states[m.state] then table.insert(out, `millipedes: {i} is in no known state`); continue end
		local p = m.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `millipedes: {i} is outside its region`)
		end
		if type(m.trail) ~= "table" or #m.trail > Millipedes.RINGS + 1 then table.insert(out, `millipedes: {i} has no body trail`) end
		if type(m.coil) ~= "number" or m.coil < 0 or m.coil > 1 then table.insert(out, `millipedes: {i} is coiled beyond belief`) end
		if (m.state == "going" or m.state == "under") and (type(self.hides) ~= "table" or self.hides[m.hide] == nil) then table.insert(out, `millipedes: {i} hides in no known spot`) end
	end
	return out
end

return Millipedes
