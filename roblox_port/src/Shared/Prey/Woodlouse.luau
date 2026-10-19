--!strict
-- Woodlice (ROBLOX-96, W3): the garden's first ambient bugs, a seeded few in the bed that walk slowly about the soil, go under the big stone, the other stones' feet
-- or the litter when the spider comes near, and come back out when it has gone. They are not prey: nothing here can be struck, caught or eaten (Prey/PreyWorld never
-- sweeps them), and to the spider's senses they are movement and nothing finer (`percepts` caps them at "movement", as the wasp's, the rival's and the mate's are;
-- the perception modules are untouched). A colony is one plain object, pure and seeded (a Prey/PreyRandom stream of its own from the region's seed), with no
-- raycast: the soil is flat and the standing boxes (the mounds, the stones, the plants) are footprints it steers round. A checkpoint records it with the region's
-- prey (Persistence/Checkpoint's `garden` root) and puts it back where it was.
-- Sources for the rules (docs/NOTEBOOK_SOURCES.md, the ground-life page): woodlice are isopod crustaceans with seven pairs of walking legs that live in damp dark
-- places under stones and litter and come out mostly at night (Hopkin 1991; Sutton 1972); their tegumental glands give a secretion that repels spiders and other
-- predators (Gorvett 1956), which is why a jumping spider here leaves them alone. The numbers below (speeds, distances, waits) are the game's.
local R = require(script.Parent.PreyRandom)

local Woodlice = {}
Woodlice.__index = Woodlice

Woodlice.HOVER = 0.12 -- the body's centre above the soil (half its height)
Woodlice.LENGTH = 1.0 -- studs; a common woodlouse is about a centimetre long
Woodlice.RADIUS = 0.35 -- as the senses see it
Woodlice.HIDE_WU = 4.0 -- the spider this near sends a woodlouse to cover
Woodlice.OUT_WU = 6.0 -- it stays under cover until the spider is this far
Woodlice.WALK = { 0.35, 0.65 } -- studs a second, each louse its own
Woodlice.FLEE = 1.2
Woodlice.RETURN_S = { 8, 15 } -- how long it waits under cover once the spider has gone
Woodlice.EDGE = 1.0 -- how far inside the soil's edge it keeps

export type Louse = {
	id: string, position: Vector3, prevPosition: Vector3, heading: Vector3, speed: number,
	state: string, -- walk | pause | hiding | hidden | emerging
	hide: number, -- the hide spot it is making for or under (an index into `hides`), 0 for none
	until_: number, -- when the pause, the wait under cover or the emerging ends
	nextTurn: number,
}

-- `spec`: World/Garden.bugs (the starting places, the hide spots, the seed); `soil` the soil's top box { min, max }; `boxes` the standing boxes' footprints
-- ({ min, max }, their y ignored).
function Woodlice.new(spec: any, soil: { min: Vector3, max: Vector3 }, boxes: { { min: Vector3, max: Vector3 } }): any
	local self: any = setmetatable({
		rng = R.new(spec.seed + 1013), now = 0, hides = {}, boxes = {}, lice = {},
		soilMin = soil.min, soilMax = soil.max, top = soil.max.Y,
	}, Woodlice)
	for _, h in spec.hides do table.insert(self.hides, { pos = h.pos, kind = h.kind }) end
	for _, b in boxes do table.insert(self.boxes, { min = b.min, max = b.max }) end
	for i, w in spec.woodlice do
		local pos = Vector3.new(w.pos.X, self.top + Woodlice.HOVER, w.pos.Z)
		table.insert(self.lice, {
			id = "louse_" .. i, position = pos, prevPosition = pos, heading = w.heading, speed = self.rng:draw(Woodlice.WALK),
			state = "walk", hide = 0, until_ = 0, nextTurn = self.rng:draw({ 1, 3 }),
		})
	end
	return self
end

-- Whether a point on the soil is free to stand on: inside the soil's edge and in no standing box's footprint (grown by `margin`).
function Woodlice.free(self: any, p: Vector3, margin: number): boolean
	if p.X < self.soilMin.X + Woodlice.EDGE or p.X > self.soilMax.X - Woodlice.EDGE or p.Z < self.soilMin.Z + Woodlice.EDGE or p.Z > self.soilMax.Z - Woodlice.EDGE then return false end
	for _, b in self.boxes do
		if p.X > b.min.X - margin and p.X < b.max.X + margin and p.Z > b.min.Z - margin and p.Z < b.max.Z + margin then return false end
	end
	return true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The hide spot nearest the louse.
function Woodlice.nearestHide(self: any, p: Vector3): number
	local best, bestD = 0, math.huge
	for i, h in self.hides do
		local d = (flat(h.pos) - flat(p)).Magnitude
		if d < bestD then best, bestD = i, d end
	end
	return best
end

local function turned(heading: Vector3, degrees: number): Vector3
	local a = math.atan2(heading.Z, heading.X) + math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- One fixed tick. `spider`: where the spider is.
function Woodlice.step(self: any, dt: number, spider: Vector3)
	self.now += dt
	local now = self.now
	for _, w in self.lice do
		w.prevPosition = w.position
		local d = (flat(spider) - flat(w.position)).Magnitude
		local near = d <= Woodlice.HIDE_WU and math.abs(spider.Y - w.position.Y) < 6
		if w.state == "walk" or w.state == "pause" or w.state == "emerging" then
			if near and #self.hides > 0 then
				w.state = "hiding"
				w.hide = self:nearestHide(w.position)
			end
		end
		if w.state == "hiding" then
			local goal = self.hides[w.hide].pos
			local to = flat(goal) - flat(w.position)
			if to.Magnitude <= 0.25 then
				w.position = Vector3.new(goal.X, w.position.Y, goal.Z)
				w.state = "hidden"
				w.until_ = math.huge
			else
				w.heading = to.Unit
				local step = math.min(to.Magnitude, Woodlice.FLEE * dt)
				w.position += w.heading * step
			end
		elseif w.state == "hidden" then
			if d >= Woodlice.OUT_WU or (spider - w.position).Magnitude >= Woodlice.OUT_WU then
				if w.until_ == math.huge then w.until_ = now + self.rng:draw(Woodlice.RETURN_S) end
				if now >= w.until_ then
					w.state = "emerging"
					w.heading = turned(w.heading, self.rng:draw({ 120, 240 }))
					w.until_ = now + 1.5
				end
			else
				w.until_ = math.huge -- (the spider came back: the wait starts again once it goes)
			end
		elseif w.state == "pause" then
			if now >= w.until_ then w.state = "walk"; w.nextTurn = now + self.rng:draw({ 1, 3 }) end
		elseif w.state == "walk" or w.state == "emerging" then
			if w.state == "emerging" and now >= w.until_ then w.state = "walk" end
			local paused = false
			if now >= w.nextTurn then
				w.heading = turned(w.heading, self.rng:draw({ -50, 50 }))
				w.nextTurn = now + self.rng:draw({ 1, 3 })
				if self.rng:next() < 0.25 then w.state = "pause"; w.until_ = now + self.rng:draw({ 1, 4 }); paused = true end
			end
			if not paused then
				local nextPos = w.position + w.heading * (w.speed * dt)
				if self:free(nextPos, 0.3) then
					w.position = nextPos
				else
					w.heading = turned(w.heading, self.rng:draw({ 90, 180 }))
				end
			end
		end
	end
end

-- The woodlice the spider could see: movement to its senses, never prey.
function Woodlice.percepts(self: any): { any }
	local out = {}
	for _, w in self.lice do
		if w.state ~= "hidden" then
			table.insert(out, { id = w.id, position = w.position, radius = Woodlice.RADIUS, velocity = Vector3.zero, maxCategory = "movement" })
		end
	end
	return out
end

-- How many are under cover now.
function Woodlice.hiddenCount(self: any): number
	local n = 0
	for _, w in self.lice do if w.state == "hidden" then n += 1 end end
	return n
end

-- What is wrong with a colony put back from a record (an empty list for a good one): the states, finite places inside the box given.
function Woodlice.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { walk = true, pause = true, hiding = true, hidden = true, emerging = true }
	if type(self.lice) ~= "table" then return { "woodlice: no list" } end
	for i, w in self.lice do
		if type(w) ~= "table" or not states[w.state] then table.insert(out, `woodlice: louse {i} is in no known state`); continue end
		local p = w.position
		if typeof(p) ~= "Vector3" and type(p) ~= "table" then table.insert(out, `woodlice: louse {i} has no position`); continue end
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then table.insert(out, `woodlice: louse {i} is outside its region`) end
		if w.hide ~= 0 and (type(self.hides) ~= "table" or self.hides[w.hide] == nil) then table.insert(out, `woodlice: louse {i} hides in no known spot`) end
	end
	return out
end

return Woodlice
