--!strict
-- Ladybirds (ROBLOX-105, W3b part B): ambient beetles, not food, that walk the bed's plants among the aphids (World/Garden.plants: one on the dock, one on the
-- dandelion at the full tier). Each walks its plant's faces from one place to the next (Prey/PlantWalk over Garden.plantPath), pauses, and now and then, when its
-- appetite has come back, walks to a perch where an aphid sits and eats it there in plain view: it stands over the aphid for 8 to 14 s and the aphid is gone
-- (the aphid's director tidies it away and its population owes another, as after the spider's own meal). Struck by the spider it is refused (Prey/PreyWorld,
-- UI/PreyText) and reflex-bleeds: a drop of the fluid shows at its front leg joints for a while and it keeps still. The spider does not otherwise trouble it.
-- Pure and seeded (a Prey/PreyRandom stream of its own from the region's ambient seed), no raycast; a checkpoint records the colony with the region's prey and
-- puts it back where it was (Persistence/Checkpoint's `garden` root, the region's `ambient`).
-- Sources (docs/NOTEBOOK_SOURCES.md, the ladybird page): adults and larvae eat aphids and other small soft-bodied insects; the colours are a warning; disturbed,
-- they release a noxious fluid from the leg joints. The speeds, waits and how often it eats are the game's.
local R = require(script.Parent.PreyRandom)
local PlantWalk = require(script.Parent.PlantWalk)
local Garden = require(script.Parent.Parent.World.Garden)

local Ladybirds = {}
Ladybirds.__index = Ladybirds

Ladybirds.HOVER = 0.17 -- the body's centre above the surface it walks on
Ladybirds.LENGTH = 0.6 -- studs: a seven-spot ladybird is 5 to 8 mm long
Ladybirds.RADIUS = 0.3 -- what a strike must come within
Ladybirds.WALK = { 0.35, 0.6 } -- studs a second
Ladybirds.PAUSE = { 2, 7 }
Ladybirds.EAT = { 8, 14 } -- seconds over an aphid
Ladybirds.APPETITE = { 50, 120 } -- seconds before it goes after another aphid
Ladybirds.REACH = 0.8 -- an aphid this near when it arrives is the one it eats
Ladybirds.BLEED_S = 6 -- how long the drop shows and it keeps still, struck

export type Beetle = {
	id: string, kind: string, plant: string, node: string, walk: PlantWalk.Walk?, surface: Vector3, position: Vector3, prevPosition: Vector3, normal: Vector3,
	heading: Vector3, speed: number, state: string, -- walk | pause | eat | still
	until_: number, target: string?, -- the aphid's perch it is making for
	prey: string?, -- the aphid it is eating
	nextMeal: number, bleedUntil: number, eaten: number, hidden: boolean,
}

-- `spec`: one of World/Garden.ambient's (kind "ladybird"); `count`: how many (the tier's); `plants`: the region's World/Garden.plants.
function Ladybirds.new(spec: any, count: number, plants: { [string]: any }): any
	local self: any = setmetatable({ kind = "ladybird", rng = R.new(spec.seed + 2027), now = 0, beetles = {} }, Ladybirds)
	for i, s in spec.starts do
		if i > count then break end
		local plant = plants[s.plant]
		local node = plant and plant.nodes[s.node]
		if node ~= nil then
			local p = if #node.route > 0 then node.route[#node.route] else plant.highway[node.hub]
			local a = self.rng:next() * math.pi * 2
			local h = Vector3.new(math.cos(a), 0, math.sin(a))
			local t = h - p.normal * h:Dot(p.normal)
			if t.Magnitude < 1e-3 then t = Vector3.yAxis - p.normal * p.normal.Y end
			if t.Magnitude < 1e-3 then t = Vector3.zAxis end
			local pos = p.pos + p.normal * Ladybirds.HOVER
			table.insert(self.beetles, {
				id = (spec.prefix or "") .. "ladybird_" .. i, kind = "ladybird", plant = s.plant, node = s.node, walk = nil, surface = p.pos, position = pos, prevPosition = pos,
				normal = p.normal, heading = t.Unit, speed = self.rng:draw(Ladybirds.WALK), state = "pause", until_ = self.rng:draw(Ladybirds.PAUSE),
				target = nil, prey = nil, nextMeal = self.rng:draw(Ladybirds.APPETITE), bleedUntil = -1, eaten = 0, hidden = false,
			})
		end
	end
	return self
end

-- The aphid (a fly of the bed's director) with this id, or nil.
local function aphidById(flies: { any }, id: string?): any
	if id == nil then return nil end
	for _, f in flies do if f.id == id then return f end end
	return nil
end

-- An aphid that can be eaten: alive, sitting (not in the jaws, not on its way between perches, not another's meal).
local function edible(f: any, by: string?): boolean
	return f ~= nil and (f.state == "PERCHED" or f.state == "ALERT") and f.creep == nil and (f.heldBy == nil or f.heldBy == by)
		and f.profile ~= nil and f.profile.body ~= nil and f.profile.body.prey_kind == "aphid"
end

-- Sets off for a node of its plant: an aphid's perch on it when its appetite is back and one sits there, else a seeded place of the plant.
local function setOff(self: any, b: any, plant: any, flies: { any })
	local to: string? = nil
	b.target = nil
	if self.now >= b.nextMeal then
		for _, f in flies do
			if edible(f, nil) and f.perch ~= nil and plant.nodes[f.perch.id] ~= nil and f.perch.id ~= b.node then to = f.perch.id; b.target = f.perch.id; break end
		end
	end
	if to == nil then
		local list = {}
		for _, id in plant.order do if id ~= b.node then table.insert(list, id) end end
		if #list == 0 then return end
		to = list[1 + math.floor(self.rng:next() * #list) % #list]
	end
	local path = Garden.plantPath(plant, b.node, to :: string)
	if path == nil then return end
	b.walk = PlantWalk.new(path, b.surface, b.normal)
	if b.target ~= nil then (b.walk :: any).length = math.max(0, (b.walk :: any).length - 0.35) end -- (it stops just short of the aphid, facing it)
	b.node = to :: string
	b.state = "walk"
end

-- One fixed tick. `ctx`: { plants = the region's Garden.plants, flies = the bed's prey director's flies (the aphids among them), hour = the life clock's hour? }.
function Ladybirds.step(self: any, dt: number, _spider: Vector3, ctx: any)
	self.now += dt
	local now = self.now
	local plants = ctx.plants or {}
	local flies = ctx.flies or {}
	for _, b in self.beetles do
		b.prevPosition = b.position
		local plant = plants[b.plant]
		if plant == nil then continue end
		if b.state == "still" then
			if now >= b.until_ then b.state = "pause"; b.until_ = now + self.rng:draw(Ladybirds.PAUSE) end
		elseif b.state == "pause" then
			if now >= b.until_ then setOff(self, b, plant, flies) end
		elseif b.state == "eat" then
			local f = aphidById(flies, b.prey)
			if not edible(f, b.id) or (f.position - b.position).Magnitude > Ladybirds.REACH + 0.4 then
				if f ~= nil and f.heldBy == b.id then f.heldBy = nil end
				b.prey = nil; b.state = "pause"; b.until_ = now + self.rng:draw(Ladybirds.PAUSE)
			elseif now >= b.until_ then
				-- the meal is over: the aphid is gone (its director tidies it away; its population owes another)
				f.heldBy = nil
				if f.perch ~= nil and f.perch.occupant == f.id then f.perch.occupant = "" end
				f.state = "CONSUMED"
				b.eaten += 1
				b.prey = nil
				b.nextMeal = now + self.rng:draw(Ladybirds.APPETITE)
				b.state = "pause"; b.until_ = now + self.rng:draw(Ladybirds.PAUSE)
			end
		elseif b.state == "walk" and b.walk ~= nil then
			local p, n, dir, done = PlantWalk.advance(b.walk, b.speed * dt)
			b.surface, b.normal = p, n
			if dir.Magnitude > 0.5 then b.heading = dir end
			b.position = p + n * Ladybirds.HOVER
			if done then
				b.walk = nil
				local f: any = nil
				if b.target ~= nil then
					for _, x in flies do
						if edible(x, nil) and x.perch ~= nil and x.perch.id == b.target and (x.position - b.position).Magnitude <= Ladybirds.REACH + 0.4 then f = x; break end
					end
				end
				b.target = nil
				if f ~= nil then
					f.heldBy = b.id
					b.prey = f.id
					b.state = "eat"; b.until_ = now + self.rng:draw(Ladybirds.EAT)
					local to = f.position - b.position
					local t = to - n * to:Dot(n)
					if t.Magnitude > 1e-3 then b.heading = t.Unit end
				else
					b.state = "pause"; b.until_ = now + self.rng:draw(Ladybirds.PAUSE)
				end
			end
		end
	end
end

-- What a strike may hit: { creature, position, radius }.
function Ladybirds.targets(self: any): { any }
	local out = {}
	for _, b in self.beetles do table.insert(out, { creature = b, position = b.position, radius = Ladybirds.RADIUS }) end
	return out
end

-- Struck by the spider: it bleeds from its leg joints and keeps still (a meal under way is left).
function Ladybirds.struck(self: any, b: any)
	b.bleedUntil = self.now + Ladybirds.BLEED_S
	if b.prey ~= nil then b.prey = nil end
	b.walk = nil
	b.state = "still"; b.until_ = self.now + Ladybirds.BLEED_S
end

-- The drawn creatures.
function Ladybirds.creatures(self: any): { any }
	return self.beetles
end

-- What is wrong with a colony put back from a record.
function Ladybirds.problems(self: any, lo: Vector3, hi: Vector3): { string }
	local out: { string } = {}
	local states = { walk = true, pause = true, eat = true, still = true }
	if type(self.beetles) ~= "table" then return { "ladybirds: no list" } end
	for i, b in self.beetles do
		if type(b) ~= "table" or not states[b.state] then table.insert(out, `ladybirds: beetle {i} is in no known state`); continue end
		local p = b.position
		if (typeof(p) ~= "Vector3" and type(p) ~= "table") or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.X < lo.X or p.X > hi.X or p.Y < lo.Y or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			table.insert(out, `ladybirds: beetle {i} is outside its region`)
		end
		if b.plant ~= "dock" and b.plant ~= "dandelion" then table.insert(out, `ladybirds: beetle {i} is on no plant`) end
		if b.walk ~= nil then
			local why = PlantWalk.problem(b.walk)
			if why ~= nil then table.insert(out, `ladybirds: beetle {i}: {why}`) end
		end
	end
	return out
end

return Ladybirds
