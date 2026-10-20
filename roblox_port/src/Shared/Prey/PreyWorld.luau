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
-- ROBLOX-101 (W3b part A): the bestiary's prey, a director per kind per region (World/Garden.bestiary: springtails and leafhoppers in the bed, moths and crane
-- flies on the wall and the outer sill), kept in the region's entry as `kinds` ({ [kind] = director }) and run in the spec's order beside W3's director, under the
-- same gate. Each is made with its kind's profile, its own seed and the tier's target (`tier`: "full" or "low", the client's detail tier, read when a director is
-- made). The moths and the crane flies follow the life clock's hour (`before`'s `hour`): restless from dusk through the night (Prey/PreyKinds.light). A moth's
-- slip and a crane fly's shed leg are decided here, on the jaws, before their step (PreyKinds.grip), and the last of them is kept as `event` for the screen.
-- The prey outside the sill never runs while the spider is on the sill itself (its neighbour the outer sill has prey now): the sill plays as it always did.
-- ROBLOX-105 (W3b part B): the garden's ambient bugs that are not food (World/Garden.ambient: ladybirds on the bed's plants, millipedes and a snail on its soil
-- and a harvestman in its litter, a harvestman on the house wall), a colony per kind per region (Prey/Ladybird, Millipede, Snail, Harvestman), kept in the
-- region's entry as `ambient` ({ [kind] = colony }), made under the same gate and stepped beside the woodlice. None of them, and no longer the woodlice, is
-- shown to the spider's senses: the perception modules know only movement, possible prey and fly-like prey, and a movement contact carries no name the HUD
-- could caption "not food", so (Nathan's W3 call) they are left out of `percepts` rather than shown as movement the player might hunt. A strike that comes
-- within one of them is refused (`event` { kind = "refused", prey = kind }, UI/PreyText) and the creature answers (a ladybird bleeds, a millipede coils, the
-- snail withdraws, a woodlouse runs for cover); nothing of theirs is ever held.
local PreyDirector = require(script.Parent.PreyDirector)
local PreyKinds = require(script.Parent.PreyKinds)
local Woodlouse = require(script.Parent.Woodlouse)
local Ladybird = require(script.Parent.Ladybird)
local Millipede = require(script.Parent.Millipede)
local Snail = require(script.Parent.Snail)
local Harvestman = require(script.Parent.Harvestman)
local Species = require(script.Parent.Parent.Data.Species)
local Garden = require(script.Parent.Parent.World.Garden)
local Region = require(script.Parent.Parent.World.Region)

local PreyWorld = {}
PreyWorld.__index = PreyWorld

-- (ROBLOX-105) The ambient colonies' classes by kind.
PreyWorld.AMBIENT = { ladybird = Ladybird, millipede = Millipede, snail = Snail, harvestman = Harvestman } :: { [string]: any }
-- (ROBLOX-105) Whether the woodlice and the ambient bugs are shown to the spider's senses (see the head of this file: they are not).
PreyWorld.SENSED = false

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
		tier = "full", -- (ROBLOX-101) the detail tier, for how many of the bestiary's prey a region holds
		hour = nil :: number?, -- (ROBLOX-101) the life clock's hour, when the client gives it
		event = nil :: any, -- (ROBLOX-101) the last prey that got out of the jaws by its own trick: { kind = "slip" | "shed", prey = prey kind }; (ROBLOX-105) or a strike refused
		strikeEnd = -1, -- (ROBLOX-105) the ambient strike's window: open until this clock time
		strikeMode = "attached", -- the motor's mode last tick
		strikeFrom = nil :: Vector3?, -- where the spider was last tick
		refused = 0, -- strikes refused so far
	}, PreyWorld)
end

-- The farthest a region's prey can be from the spider: over the perches and vents of its directors where it has them, else of its specs (W3's and the
-- bestiary's).
local function reach(self: any, region: any, pos: Vector3): number
	local far = 0
	local function over(list: { any }) for _, p in list do far = math.max(far, (p.position - pos).Magnitude) end end
	if region.id == self.world.home then
		over(self.home.graph.perches); over(self.home.vents)
		return far
	end
	local entry = self.garden[region.id] or {}
	local any = false
	local spec = Garden.prey(region)
	if entry.prey ~= nil then over(entry.prey.graph.perches); over(entry.prey.vents); any = true
	elseif spec ~= nil then over(spec.perches); over(spec.vents); any = true end
	for _, k in (Garden.bestiary(region) or {}) :: { any } do
		local d = if entry.kinds ~= nil then entry.kinds[k.kind] else nil
		if d ~= nil then over(d.graph.perches); over(d.vents) else over(k.perches); over(k.vents) end
		any = true
	end
	return if any then far else math.huge
end

-- Whether a region has prey at all: the sill's (the home), or a kind Garden places prey in (W3's or the bestiary's).
function PreyWorld.hasPrey(self: any, region: any): boolean
	return region.id == self.world.home or Garden.prey(region) ~= nil or Garden.bestiary(region) ~= nil
end

-- The ids of the regions whose prey runs at this place: the spider's own, and each neighbour with prey whose farthest perch is within ACTIVE_RADIUS (none while
-- the spider is on the sill itself: ROBLOX-101 keeps the sill as it was now that the outer sill has prey).
function PreyWorld.activeAt(self: any, pos: Vector3): { string }
	local here = self.world.region
	local out: { string } = {}
	if self:hasPrey(here) then table.insert(out, here.id) end
	if here.id == self.world.home then return out end
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

-- The region's bestiary directors in the spec's order, each made now if the region is whole and it has none yet (an empty list for a region without any).
function PreyWorld.kinds(self: any, id: string): { any }
	local out = {}
	if id == self.world.home then return out end
	local region = self.world.map.region(id)
	local specs = if region ~= nil then Garden.bestiary(region) else nil
	if specs == nil then return out end
	local entry = self.garden[id]
	for _, spec in specs do
		local d = if entry ~= nil and entry.kinds ~= nil then entry.kinds[spec.kind] else nil
		if d == nil and self.root ~= nil and self.world:regionReady(id) then
			local target = if self.tier == "low" then spec.low else spec.target
			d = PreyDirector.engine(self.root, (Species :: any)[spec.profile], spec.seed, target, false, spec, self.casts)
			entry = entry or {}
			entry.kinds = entry.kinds or {}
			entry.kinds[spec.kind] = d
			self.garden[id] = entry
			self.made += 1
		end
		if d ~= nil then
			d.feeding = self.home.feeding -- (one jaws: a return to a rest rebuilds them)
			table.insert(out, d)
		end
	end
	return out
end

-- Every director of a region: W3's (the bed's gnats and aphids), then the bestiary's.
function PreyWorld.directors(self: any, id: string): { any }
	local out = {}
	local d = self:director(id)
	if d ~= nil then table.insert(out, d) end
	for _, k in self:kinds(id) do table.insert(out, k) end
	return out
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

-- The region's ambient colonies in Garden.AMBIENT's order, each made now if the region is whole and it has none yet (an empty list for a region without any).
-- A colony on the soil needs the soil and the standing boxes, as the woodlice do.
function PreyWorld.ambient(self: any, id: string): { any }
	local out = {}
	if id == self.world.home then return out end
	local region = self.world.map.region(id)
	local specs = if region ~= nil then Garden.ambient(region) else nil
	if specs == nil then return out end
	local entry = self.garden[id]
	local soil: any, boxes: { any }? = nil, nil
	for _, spec in specs do
		local c = if entry ~= nil and entry.ambient ~= nil then entry.ambient[spec.kind] else nil
		if c == nil and self.world:regionReady(id) then
			local count = if self.tier == "low" then spec.low else spec.full
			if spec.surface == "soil" and soil == nil then
				boxes = {}
				for _, p in Region.pieces(region) do
					if p.id == region.id .. "_soil" then soil = { min = p.lo, max = p.hi }
					elseif p.lo.Y <= region.origin.Y + 0.01 then table.insert(boxes :: any, { min = p.lo, max = p.hi }) end
				end
			end
			if spec.kind == "ladybird" then c = Ladybird.new(spec, count, Garden.plants(region) or {})
			elseif spec.kind == "millipede" and soil ~= nil then c = Millipede.new(spec, count, soil, boxes :: any)
			elseif spec.kind == "snail" and soil ~= nil then c = Snail.new(spec, count, soil, boxes :: any)
			elseif spec.kind == "harvestman" then c = Harvestman.new(spec, count, soil, boxes) end
			if c ~= nil then
				entry = entry or {}
				entry.ambient = entry.ambient or {}
				entry.ambient[spec.kind] = c
				self.garden[id] = entry
			end
		end
		if c ~= nil then table.insert(out, c) end
	end
	return out
end

-- Every percept of the active regions: their flies (the woodlice and the ambient bugs only if SENSED, as movement).
function PreyWorld.percepts(self: any): { any }
	local out = {}
	for _, id in self.active do
		for _, d in self:directors(id) do for _, p in d:percepts() do table.insert(out, p) end end
		local w = if PreyWorld.SENSED then self:bugs(id) else nil
		if w ~= nil then for _, p in w:percepts() do table.insert(out, p) end end
	end
	return out
end

-- Before the motor (the client's order): which regions are active at this place, then each active director's `before` and its woodlice.
-- `hour` (ROBLOX-101): the life clock's hour, for the kinds that fly from dusk (nil: the last one given, or day).
function PreyWorld.before(self: any, dt: number, position: Vector3, observer: any, sensor: any, cast: any, camera: any, hour: number?)
	self.clock += dt
	if hour ~= nil then self.hour = hour end
	self.active = self:activeAt(position)
	for _, id in self.active do
		for _, d in self:directors(id) do
			local dusk = Garden.BESTIARY.dusk
			if PreyKinds.counterpart(d.p, true) ~= nil or PreyKinds.counterpart(d.p, false) ~= nil then
				PreyKinds.light(d, self.hour ~= nil and PreyKinds.isDusk(self.hour, dusk.from, dusk.to))
			end
			d:before(dt, position, observer, sensor, cast, camera)
		end
		local w = self:bugs(id)
		if w ~= nil then w:step(dt, position) end
		local list = self:ambient(id)
		if #list > 0 then
			local region = self.world.map.region(id)
			local aphids = {}
			local d = self:director(id)
			if d ~= nil then for _, f in d.flies do table.insert(aphids, f) end end
			local ctx = { hour = self.hour, flies = aphids, plants = if region ~= nil then Garden.plants(region) else nil }
			for _, c in list do c:step(dt, position, ctx) end
		end
	end
end

-- Whether the home's prey ran this tick.
function PreyWorld.homeActive(self: any): boolean
	return table.find(self.active, self.world.home) ~= nil
end

-- A fly that tore free goes back to the director it belongs to (returned).
function PreyWorld.escape(self: any, f: any): any
	if not self.home:owns(f) then
		for _, entry in self.garden do
			if entry.prey ~= nil and entry.prey:owns(f) then entry.prey:escape(f); return entry.prey end
			for _, d in entry.kinds or {} do
				if d:owns(f) then d:escape(f); return d end
			end
		end
	end
	self.home:escape(f)
	return self.home
end

-- (ROBLOX-101) A prey that got out of the jaws by its own trick cannot be struck again for this long (seconds): it leaves from the spider's mouth while the
-- strike that took it may still be open, and a slip that is caught again on the same tick would be no slip.
PreyWorld.FREE_S = 0.5

-- After the motor: the home's `after` always (the jaws, the reserves, once a tick; with no sweep where its prey did not run), every other active director's
-- `afterShared`. Then the view the sound and the drawing read.
function PreyWorld.after(self: any, dt: number, motor: any, sensor: any, cast: any)
	if not self:homeActive() then self.home.previousPosition = motor.pos end
	-- (ROBLOX-101) a moth's slip, a crane fly's shed leg: out of the jaws before they step
	local held = self.home.feeding.held
	local trick = PreyKinds.grip(self.home.feeding, function(f)
		local d = self:escape(f)
		f.freeUntil = d.now + PreyWorld.FREE_S
	end)
	if trick ~= nil then self.event = { kind = trick, prey = held.profile.body.prey_kind } end
	self.home:after(dt, motor, sensor, cast, function(f) self:escape(f) end)
	for _, id in self.active do
		if id ~= self.world.home then
			for _, d in self:directors(id) do d:afterShared(motor, sensor, cast) end
		end
	end
	self:strikeAmbient(motor)
	local flies = {}
	for _, id in self.active do
		for _, d in self:directors(id) do for _, f in d.flies do table.insert(flies, f) end end
	end
	self.view.flies = flies
	self.view.feeding = self.home.feeding
end

-- The active regions' flies, for the drawing and the notebook's watcher.
function PreyWorld.flies(self: any): { any }
	return self.view.flies
end

-- (ROBLOX-105) The strike against what is not food: a window opened by a leap (the motor's `launched` as it leaves the ground, as the directors' own) and closed
-- just after it lands; while it is open and the jaws are empty, a sweep of the spider's body from last tick's place to this one against every woodlouse and
-- ambient bug of the active regions. The first one within its radius (and the directors' 0.3) is refused: `event`, the creature's answer, the window shut.
function PreyWorld.strikeAmbient(self: any, motor: any)
	local mode = motor.mode
	if mode == "air" and self.strikeMode ~= "air" then
		for _, e in motor.events or {} do if e.kind == "launched" then self.strikeEnd = self.clock + 4; break end end
	end
	if self.strikeMode == "air" and mode ~= "air" then self.strikeEnd = math.min(self.strikeEnd, self.clock + 0.05) end
	self.strikeMode = mode
	local from = self.strikeFrom or motor.pos
	self.strikeFrom = motor.pos
	if self.clock > self.strikeEnd or self.home.feeding.held ~= nil then return end
	local seg = motor.pos - from
	local len2 = seg:Dot(seg)
	for _, id in self.active do
		local colonies = {}
		local w = self:bugs(id)
		if w ~= nil then table.insert(colonies, { c = w, kind = "woodlouse" }) end
		for _, c in self:ambient(id) do table.insert(colonies, { c = c, kind = c.kind }) end
		for _, e in colonies do
			for _, t in e.c:targets() do
				local u = if len2 > 1e-12 then math.clamp((t.position - from):Dot(seg) / len2, 0, 1) else 0
				if ((from + seg * u) - t.position).Magnitude <= t.radius + 0.3 then
					e.c:struck(t.creature)
					self.event = { kind = "refused", prey = e.kind }
					self.refused += 1
					self.strikeEnd = -1
					return
				end
			end
		end
	end
end

-- (ROBLOX-105) Every woodlouse and ambient bug of the active regions, for the drawing (Client/BugBodies: a creature with no `kind` is a woodlouse) and the
-- notebook's close look.
function PreyWorld.crawlers(self: any): { any }
	local out = {}
	for _, id in self.active do
		local w = self:bugs(id)
		if w ~= nil then for _, l in w.lice do table.insert(out, l) end end
		for _, c in self:ambient(id) do for _, b in c:creatures() do table.insert(out, b) end end
	end
	return out
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
		for _, d in entry.kinds or {} do n += d.captures end
	end
	return n
end

return PreyWorld
