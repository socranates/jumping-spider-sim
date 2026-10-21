--!strict
-- The drawn looks of the regions outside the window, built on this client near the spider and destroyed far from it (ROBLOX-108).
--
-- Until ROBLOX-107 the server built every region's look as a persistent model and every client held all of them wherever the spider was: 3,647 parts at the
-- full tier, 1,215 at the low. A look is a pure function of its region's seed (World/Region.decor), so a client can build the very same parts itself: nothing is
-- replicated, no streaming decides when a look arrives or leaves, the low tier never builds what it would throw away, and the CLI tests run the same code. Which
-- looks, at what detail, is World/LookPlan's plan (at most LookPlan.BUDGET parts: the region the spider is in and the regions it meets always, the house's shell
-- far, the rest nearest first); this module follows it.
--
-- A look is a Model named for its region under `WorldDecor` in the workspace, in up to three parts of its own: `Base` (the records the low tier keeps), `Full`
-- (the records only the full tier draws) and `Far` (the far look of a wall: LookPlan.records(region, "far")). Full detail is Base and Full, low is Base, far is
-- Far. A part is built into a folder that is parented only when it is whole, and what it replaces (the Far under a Base, the Base under a Far) is destroyed in
-- that same frame, so a look is never missing where the plan had one and never doubled from one frame to the next.
-- The work is spread: at most PARTS_PER_FRAME parts are made in a frame, nearest region first, except that a region the spider is in or beside which has
-- nothing drawn at all (the first frame, a return to a rest far away) is built whole at once: a look the spider can see close must not be missing.
-- A look whose records fail to build is warned about once and its region's drawn pieces are made visible on this client (their own colours), as the server did
-- when a look failed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))
local LookPlan = require(Shared:WaitForChild("World"):WaitForChild("LookPlan"))
local Scenery = require(Shared:WaitForChild("Habitat"):WaitForChild("Scenery"))
local DayLight = require(Shared:WaitForChild("Habitat"):WaitForChild("DayLight"))

local LookStream = {}
LookStream.__index = LookStream

-- A region or (ROBLOX-115) a drawn zone of the backdrop, by id, from the stream's map.
local function regionOf(self: any, id: string): WorldMap.Region?
	return LookPlan.lookup(self.map, id)
end

-- The most parts made in one frame (a whole look the spider is beside and cannot see is made at once regardless).
LookStream.PARTS_PER_FRAME = 120
-- The plan is asked again when the spider has moved this many studs since it was last asked, or its region changed.
LookStream.REPLAN_MOVE = 2

type Job = { id: string, set: string, records: { any }, at: number, folder: Folder, groups: { [string]: Instance } }

-- `ws`: where the WorldDecor folder goes (the workspace); `tier`: "full" or "low" (Data/Detail); `root`: the World folder of the regions' boxes (for a look that
-- fails: its drawn pieces are shown); `map`: WorldMap unless a test hands in another with the same functions.
function LookStream.new(ws: Instance, tier: string, root: Instance?, map: any?): any
	local folder = Instance.new("Folder")
	folder.Name = Region.LOOKS_FOLDER
	folder.Parent = ws
	return setmetatable({
		folder = folder, tier = if tier == "low" then "low" else "full", root = root, map = map or WorldMap,
		plan = {} :: LookPlan.Plan, planned = 0, -- the plan being followed and its parts
		looks = {} :: { [string]: { model: Model, sets: { [string]: Folder } } }, -- what is built: per region, its whole parts
		jobs = {} :: { Job }, -- what is being built, in order
		at = nil :: Vector3?, here = nil :: any, failed = {} :: { [string]: boolean },
		dewHour = nil :: number?, dewDirty = false, -- (ROBLOX-117: the hour the looks' dew was last set for, and whether a look has been made since)
		made = 0, destroyed = 0, plans = 0, -- (counts, for the tests and the self-test's INFO line)
	}, LookStream)
end

-- The sets a level is made of.
local function setsOf(level: string?): { [string]: boolean }
	if level == "full" then return { Base = true, Full = true } end
	if level == "low" then return { Base = true } end
	if level == "far" then return { Far = true } end
	return {}
end

-- The records of one set of a region's look.
local function recordsOf(region: WorldMap.Region, set: string, tier: string): { any }
	if set == "Far" then return LookPlan.records(region, "far", tier) end
	if set == "Base" then return LookPlan.records(region, "low") end
	local out = {}
	for _, d in LookPlan.records(region, "full") do if d.full then table.insert(out, d) end end
	return out
end

-- Whether the region's look has every set its planned level needs.
function LookStream.complete(self: any, id: string): boolean
	local look = self.looks[id]
	for set in setsOf(self.plan[id]) do
		if look == nil or look.sets[set] == nil then return false end
	end
	return true
end

-- Destroys what the region's look holds that its planned level does not need, once everything it does need is whole (so a far wall stays until its bricks are
-- up), or at once when the plan has no look for it.
function LookStream.settle(self: any, id: string)
	local look = self.looks[id]
	if look == nil then return end
	local level = self.plan[id]
	if level ~= nil and not self:complete(id) then return end
	local need = setsOf(level)
	for set, f in look.sets do
		if not need[set] then
			for _, d in f:GetDescendants() do if d:IsA("BasePart") then self.destroyed += 1 end end
			f:Destroy()
			look.sets[set] = nil
		end
	end
	if next(look.sets) == nil then
		look.model:Destroy()
		self.looks[id] = nil
	end
end

-- A look failed: said once, the region's drawn pieces shown on this client, and never tried again.
function LookStream.fail(self: any, region: WorldMap.Region, err: any)
	if self.failed[region.id] then return end
	self.failed[region.id] = true
	local say: any = warn -- (the engine's warn; the CLI tests have none unless they collect them)
	if say ~= nil then say(`[Windowsill] decor: the look of {region.id} failed on this client: {tostring(err)}`) end
	local folder = if self.root ~= nil then self.root:FindFirstChild(Region.folderName(region)) else nil
	if folder ~= nil then
		for _, id in Region.drawnPieces(region) do
			local p = folder:FindFirstChild(id)
			if p ~= nil and p:IsA("BasePart") then p.Transparency = 0 end
		end
	end
end

-- Asks the plan again at this place and queues what it changes: what the plan drops is destroyed at once, what it adds is queued (nearest first, the regions the
-- spider is in or beside first of all).
function LookStream.replan(self: any, pos: Vector3, here: any?)
	self.plans += 1
	local held: LookPlan.Plan = {}
	for id, look in self.looks do
		if look.sets.Far ~= nil then held[id] = "far" end
		if look.sets.Base ~= nil then held[id] = if look.sets.Full ~= nil then "full" else "low" end
	end
	local plan, total = LookPlan.plan(pos, self.tier, here, held, self.map)
	for id in self.failed do plan[id] = nil end
	self.plan, self.planned = plan, total
	-- the jobs no longer wanted are dropped (their unparented folders with them)
	local keep: { Job } = {}
	for _, job in self.jobs do
		if setsOf(plan[job.id])[job.set] then table.insert(keep, job) else job.folder:Destroy() end
	end
	self.jobs = keep
	-- what is held and not planned goes now; what is held beyond its level goes once the level is whole
	for id in self.looks do self:settle(id) end
	-- what is planned and neither held nor queued is queued, nearest first
	local required = LookPlan.required(pos, here, self.map)
	local adds: { { id: string, set: string, d: number } } = {}
	for id, level in plan do
		local region = regionOf(self, id)
		if region ~= nil then
			for set in setsOf(level) do
				local look = self.looks[id]
				local queued = false
				for _, job in self.jobs do if job.id == id and job.set == set then queued = true; break end end
				if not queued and (look == nil or look.sets[set] == nil) then
					local d = LookPlan.distance(region, pos)
					if required[id] then d = -1 end
					table.insert(adds, { id = id, set = set, d = d + (if set == "Full" then 0.5 else 0) })
				end
			end
		end
	end
	table.sort(adds, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		if a.id ~= b.id then return a.id < b.id end
		return a.set < b.set
	end)
	for _, a in adds do
		local region = regionOf(self, a.id) :: WorldMap.Region
		local ok, records = pcall(recordsOf, region, a.set, self.tier)
		if not ok then
			self:fail(region, records)
			self.plan[a.id] = nil
		else
			local f = Instance.new("Folder")
			f.Name = a.set
			table.insert(self.jobs, { id = a.id, set = a.set, records = records, at = 1, folder = f, groups = {} })
		end
	end
	-- the regions the spider is in or beside go first, each kind in the order it had
	local first, rest = {}, {}
	for _, job in self.jobs do table.insert(if required[job.id] then first else rest, job) end
	for _, job in rest do table.insert(first, job) end
	self.jobs = first
end

-- Makes up to `allowance` parts of the jobs in order (a job whose region has nothing drawn and is in reach is made whole); returns how many were made.
function LookStream.work(self: any, required: { [string]: boolean }): number
	local allowance = LookStream.PARTS_PER_FRAME
	local made = 0
	local i = 1
	while i <= #self.jobs do
		local job: Job = self.jobs[i]
		local urgent = required[job.id] == true and self.looks[job.id] == nil
		if allowance <= 0 and not urgent then break end
		local region = regionOf(self, job.id) :: WorldMap.Region
		local last = if urgent then #job.records else math.min(#job.records, job.at + allowance - 1)
		local ok, err = pcall(Scenery.look, job.folder, job.records, job.at, last, job.groups)
		if not ok then
			table.remove(self.jobs, i)
			job.folder:Destroy()
			self:fail(region, err)
			self.plan[job.id] = nil
			self:settle(job.id)
		else
			local n = math.max(0, last - job.at + 1)
			made += n
			if not urgent then allowance -= n end
			job.at = last + 1
			if job.at > #job.records then
				table.remove(self.jobs, i)
				local look = self.looks[job.id]
				if look == nil then
					local model = Instance.new("Model")
					model.Name = job.id
					model.Parent = self.folder
					look = { model = model, sets = {} }
					self.looks[job.id] = look
				end
				job.folder.Parent = look.model
				look.sets[job.set] = job.folder
				if (job.groups :: any).Dew ~= nil then self.dewDirty = true end
				self:settle(job.id)
			else
				i += 1
			end
		end
	end
	self.made += made
	return made
end

-- Each frame: the plan asked again when the spider has moved REPLAN_MOVE studs or changed region (`here`: the region it is in, as WorldClient keeps it), then up to
-- PARTS_PER_FRAME parts made. Returns how many were made.
function LookStream.update(self: any, pos: Vector3, here: any?): number
	local last = self.at
	if last == nil or (pos - last).Magnitude >= LookStream.REPLAN_MOVE or here ~= self.here then
		self.at, self.here = pos, here
		self:replan(pos, here)
	end
	if #self.jobs == 0 then return 0 end
	return self:work(LookPlan.required(self.at :: Vector3, self.here, self.map))
end

-- (ROBLOX-117) The morning's dew on the looks (the patches' drops on the blades and the chips, the leaves' drops): each set's "Dew" group shown by the hour as the
-- sill's is (Habitat/DayLight.applyDew, which keeps its own level on each group). Asked each frame; it does anything only when the hour has moved a little or a
-- look with dew has been made since. Returns whether it touched the drops.
function LookStream.dew(self: any, hour: number): boolean
	if not self.dewDirty and self.dewHour ~= nil and math.abs(hour - self.dewHour) < 0.05 then return false end
	self.dewHour, self.dewDirty = hour, false
	local any = false
	for _, look in self.looks do
		for _, f in look.sets do
			if DayLight.applyDew(f, hour) then any = true end
		end
	end
	return any
end

-- How many look parts this client holds now (whole sets only: a set being made is not in the workspace yet).
function LookStream.parts(self: any): number
	local n = 0
	for _, look in self.looks do
		for _, f in look.sets do
			for _, d in f:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
		end
	end
	return n
end

-- Builds everything the plan wants now, at once (a test's, or the self-test's, way to wait for the looks to settle). Returns how many parts were made.
function LookStream.finish(self: any): number
	local saved = LookStream.PARTS_PER_FRAME
	LookStream.PARTS_PER_FRAME = math.huge
	local ok, made = pcall(function() return self:work({}) end)
	LookStream.PARTS_PER_FRAME = saved
	if not ok then error(made) end
	return made
end

return LookStream
