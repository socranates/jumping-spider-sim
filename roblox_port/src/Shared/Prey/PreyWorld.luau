--!strict
-- The prey of the whole world (ROBLOX-96, W3): one Prey/PreyDirector per region that has prey, run only where the spider is. The sill's director is the one the
-- client always had (`home`: its flies, its seed 914, its Feeding, which is the jaws and the only one that advances the reserves); the bed's is made from
-- World/Garden.prey(region) with the region's own seed (WorldMap.seed) when the bed has first arrived whole and the spider is in it or beside it, and it keeps
-- its own PreyRandom streams and its own clock ever after: crossing a seam rerolls nothing, and a region the spider has left simply waits (its clock stops) with its
-- flies where they were. The gate is Client/WorldClient:regionReady (`world`): a region's director is never made, and never steps, while a box of the region may
-- be missing, since every perch and every flight is a raycast. A neighbour's prey runs only when the farthest of its perches is inside ACTIVE_RADIUS (the
-- streaming radius always sent) of the spider. The woodlice (Prey/Woodlouse) run beside the bed's director under the same gate, and are never swept.
-- The directors share one set of casts (PreyDirector.casts: one probe, one set of closures) so a checkpoint names them once; the bed's director and its woodlice
-- live in `garden` (the table Persistence/Checkpoint records as its `garden` root), so a rest under the stone keeps the bed's prey and puts it back where it was.
local PreyDirector = require(script.Parent.PreyDirector)
local Woodlouse = require(script.Parent.Woodlouse)
local Species = require(script.Parent.Parent.Data.Species)
local Garden = require(script.Parent.Parent.World.Garden)
local Region = require(script.Parent.Parent.World.Region)

local PreyWorld = {}
PreyWorld.__index = PreyWorld

-- A neighbouring region's prey runs while its farthest perch is inside this many studs of the spider (Workspace.StreamingMinRadius, 96: what is always sent).
PreyWorld.ACTIVE_RADIUS = 96

-- `home`: the sill's director; `world`: the client's world (WorldClient: `region`, `home`, `map`, `regionReady`); `garden`: the table the checkpoint records
-- ({ [regionId] = { prey = director?, bugs = woodlice? } }); `root`: the folder the casts include (nil: no engine, no director is ever made); `casts`: the home's
-- casts, when it has them (PreyDirector.casts), else new ones.
function PreyWorld.new(home: any, world: any, garden: { [string]: any }, root: Instance?, casts: any?): any
	return setmetatable({
		home = home, world = world, garden = garden, root = root,
		casts = casts or (if root ~= nil then PreyDirector.casts(root) else nil),
		clock = 0, -- a running clock for the drawing (the directors' own stop while they wait)
		active = {} :: { string }, -- the regions whose prey ran this tick
		view = { flies = {}, feeding = home.feeding }, -- what the sound and the drawing read: the active flies and the jaws
		made = 0, -- directors made so far
	}, PreyWorld)
end

-- The farthest a region's prey can be from the spider: over the perches and vents of its director when it has one, else of its spec.
local function reach(self: any, region: any, pos: Vector3): number
	local far = 0
	local d = if region.id == self.world.home then self.home else (self.garden[region.id] or {}).prey
	if d ~= nil then
		for _, p in d.graph.perches do far = math.max(far, (p.position - pos).Magnitude) end
		for _, p in d.vents do far = math.max(far, (p.position - pos).Magnitude) end
		return far
	end
	local spec = Garden.prey(region)
	if spec == nil then return math.huge end
	for _, p in spec.perches do far = math.max(far, (p.position - pos).Magnitude) end
	for _, p in spec.vents do far = math.max(far, (p.position - pos).Magnitude) end
	return far
end

-- Whether a region has prey at all: the sill's (the home), or a kind Garden places prey in.
function PreyWorld.hasPrey(self: any, region: any): boolean
	return region.id == self.world.home or Garden.prey(region) ~= nil
end

-- The ids of the regions whose prey runs at this place: the spider's own, and each neighbour with prey whose farthest perch is within ACTIVE_RADIUS.
function PreyWorld.activeAt(self: any, pos: Vector3): { string }
	local here = self.world.region
	local out: { string } = {}
	if self:hasPrey(here) then table.insert(out, here.id) end
	for _, n in here.neighbors do
		local r = self.world.map.region(n.id)
		if r ~= nil and self:hasPrey(r) and reach(self, r, pos) <= PreyWorld.ACTIVE_RADIUS then table.insert(out, r.id) end
	end
	return out
end

-- The region's director, made now if the region is whole and it has none yet (nil for a region with no prey, or one not yet whole). The sill's is the home.
function PreyWorld.director(self: any, id: string): any
	if id == self.world.home then return self.home end
	local entry = self.garden[id]
	if entry ~= nil and entry.prey ~= nil then
		entry.prey.feeding = self.home.feeding -- (a return to a rest rebuilds the jaws: every director eats with the home's)
		return entry.prey
	end
	if self.root == nil or not self.world:regionReady(id) then return nil end
	local region = self.world.map.region(id)
	local spec = if region ~= nil then Garden.prey(region) else nil
	if spec == nil then return nil end
	local d = PreyDirector.engine(self.root, Species.fungus_gnat_prototype, spec.seed, spec.target, false, spec, self.casts)
	d.feeding = self.home.feeding -- one jaws, one reserve
	entry = entry or {}
	entry.prey = d
	self.garden[id] = entry
	self.made += 1
	return d
end

-- The region's woodlice, made with its director's gate (nil for a region without any, or one not yet whole).
function PreyWorld.bugs(self: any, id: string): any
	if id == self.world.home then return nil end
	local entry = self.garden[id]
	if entry ~= nil and entry.bugs ~= nil then return entry.bugs end
	if not self.world:regionReady(id) then return nil end
	local region = self.world.map.region(id)
	local spec = if region ~= nil then Garden.bugs(region) else nil
	if spec == nil then return nil end
	local soil: any, boxes = nil, {}
	for _, p in Region.pieces(region) do
		if p.id == region.id .. "_soil" then soil = { min = p.lo, max = p.hi }
		elseif p.lo.Y <= region.origin.Y + 0.01 then table.insert(boxes, { min = p.lo, max = p.hi }) end
	end
	if soil == nil then return nil end
	local w = Woodlouse.new(spec, soil, boxes)
	entry = entry or {}
	entry.bugs = w
	self.garden[id] = entry
	return w
end

-- Every percept of the active regions: their flies, and their woodlice as movement.
function PreyWorld.percepts(self: any): { any }
	local out = {}
	for _, id in self.active do
		local d = self:director(id)
		if d ~= nil then for _, p in d:percepts() do table.insert(out, p) end end
		local w = self:bugs(id)
		if w ~= nil then for _, p in w:percepts() do table.insert(out, p) end end
	end
	return out
end

-- Before the motor (the client's order): which regions are active at this place, then each active director's `before` and its woodlice.
function PreyWorld.before(self: any, dt: number, position: Vector3, observer: any, sensor: any, cast: any, camera: any)
	self.clock += dt
	self.active = self:activeAt(position)
	for _, id in self.active do
		local d = self:director(id)
		if d ~= nil then d:before(dt, position, observer, sensor, cast, camera) end
		local w = self:bugs(id)
		if w ~= nil then w:step(dt, position) end
	end
end

-- Whether the home's prey ran this tick.
function PreyWorld.homeActive(self: any): boolean
	return table.find(self.active, self.world.home) ~= nil
end

-- A fly that tore free goes back to the director it belongs to.
function PreyWorld.escape(self: any, f: any)
	if not self.home:owns(f) then
		for _, entry in self.garden do
			if entry.prey ~= nil and entry.prey:owns(f) then entry.prey:escape(f); return end
		end
	end
	self.home:escape(f)
end

-- After the motor: the home's `after` always (the jaws, the reserves, once a tick; with no sweep where its prey did not run), every other active director's
-- `afterShared`. Then the view the sound and the drawing read.
function PreyWorld.after(self: any, dt: number, motor: any, sensor: any, cast: any)
	if not self:homeActive() then self.home.previousPosition = motor.pos end
	self.home:after(dt, motor, sensor, cast, function(f) self:escape(f) end)
	for _, id in self.active do
		if id ~= self.world.home then
			local d = self:director(id)
			if d ~= nil then d:afterShared(motor, sensor, cast) end
		end
	end
	local flies = {}
	for _, id in self.active do
		local d = self:director(id)
		if d ~= nil then for _, f in d.flies do table.insert(flies, f) end end
	end
	self.view.flies = flies
	self.view.feeding = self.home.feeding
end

-- The active regions' flies, for the drawing and the notebook's watcher.
function PreyWorld.flies(self: any): { any }
	return self.view.flies
end

-- The active regions' woodlice, for the drawing.
function PreyWorld.woodlice(self: any): { any }
	local out = {}
	for _, id in self.active do
		local w = self:bugs(id)
		if w ~= nil then for _, l in w.lice do table.insert(out, l) end end
	end
	return out
end

-- Every capture made, in every region.
function PreyWorld.captures(self: any): number
	local n = self.home.captures
	for _, entry in self.garden do
		if entry.prey ~= nil then n += entry.prey.captures end
	end
	return n
end

return PreyWorld
