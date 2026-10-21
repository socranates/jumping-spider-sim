--!strict
-- The walkable boxes' shadows, kept to the ones an eye at the spider could see (ROBLOX-121).
--
-- Every region's boxes are parts in the server's `World` folder, and every one of them that is not hidden under a drawing casts a shadow, as a part does by default.
-- Since ROBLOX-119 the preserve has 1,410 of them, 1,393 casting (the meadow's edge alone 708: every culm, leaf and head a box), and v41's Studio self-test measured
-- the sill at 38 fps where v39's (before the meadow and the bench) had 54 to 60; the client's own Lua costs the same in both trees on the sill (tests/selftest_preserve.luau's
-- profile), so the frame went to what the engine is given. A box casts its shadow into the sun's shadow map wherever the camera is; a culm 1 cm across 12 m away
-- throws a shadow a hundredth of a pixel wide. So this client turns off the shadow of a box whose shadow would be narrower than about two pixels on a 1080p screen
-- from where the spider is (CAST: the box's middle extent, the width of the shadow a box throws, under 1/500 of its distance from the spider), and turns it on again
-- when the spider comes near. Nothing else of the box changes (it is seen, walked and raycast as before), a box hidden under a drawing (Transparency 1, CastShadow off,
-- World/WorldBuild) is never touched, and the sill's own folder (the home: the spider is always within a few studs of it there) is left as the server built it.
--
-- The rule is asked again when the spider has moved PASS_MOVE studs since the last time (a box's distance changes by no more than that, so its shadow is at most a
-- shade early or late), and only a box whose answer changed is written. With instance streaming the server sends a region's boxes as the spider comes near, so a
-- region whose folder does not yet hold all its pieces is looked at again every BIND_EVERY seconds for the ones that have arrived (each is given the rule's answer at
-- once); a box streamed out and back is a new part, found by the slow check of every box's parent (CHECK_SLICE a time).
-- These are this client's own changes to the server's parts: nothing is sent, nothing is saved, another player's client keeps its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))

local WorldShadows = {}
WorldShadows.__index = WorldShadows

-- A box casts while its middle extent is at least this share of its distance from the spider: 1/500 of a radian is 1.8 pixels on a 1080p screen at the
-- camera's 65 degrees, 2.3 at the Settings' narrowest 50.
WorldShadows.CAST = 1 / 500
-- The rule is asked again when the spider has moved this many studs.
WorldShadows.PASS_MOVE = 32
-- A region not yet whole is looked at again for its arrived boxes this often (seconds); and this many bound boxes have their parent checked each time.
WorldShadows.BIND_EVERY = 2
WorldShadows.CHECK_SLICE = 100

type Entry = { part: BasePart, folder: Instance, lo: Vector3, hi: Vector3, mid: number, on: boolean }
type Holder = { id: string, folder: Instance?, expected: number, bound: { [Instance]: boolean }, count: number }

-- The middle of a box's three extents: the width of the shadow it throws (a culm's 1 of 1 by 40, a slat's 10 of 164 by 2 by 10).
function WorldShadows.middle(size: Vector3): number
	local a, b, c = size.X, size.Y, size.Z
	if a > b then a, b = b, a end
	if b > c then b, c = c, b end
	if a > b then a, b = b, a end
	return b
end

-- The distance from a point to a box (0 inside it).
function WorldShadows.distance(lo: Vector3, hi: Vector3, pos: Vector3): number
	local dx = math.max(lo.X - pos.X, 0, pos.X - hi.X)
	local dy = math.max(lo.Y - pos.Y, 0, pos.Y - hi.Y)
	local dz = math.max(lo.Z - pos.Z, 0, pos.Z - hi.Z)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The rule: whether a box (its corners, and its middle extent) casts its shadow with the spider at `pos`.
function WorldShadows.casts(lo: Vector3, hi: Vector3, mid: number, pos: Vector3): boolean
	return mid >= WorldShadows.CAST * WorldShadows.distance(lo, hi, pos)
end

-- `root`: the World folder; `map`: the world map (WorldMap or a test's); `home`: the id of the region whose folder is left alone (the sill).
function WorldShadows.new(root: Instance, map: any, home: string?): any
	local holders: { Holder } = {}
	local regions: { any } = if map.regions ~= nil then map.regions() else {} -- (a test's stand-in map may have no list: then there is nothing to keep)
	for _, region in regions do
		if region.id ~= home then
			local n = #Region.pieces(region)
			if n > 0 then table.insert(holders, { id = Region.folderName(region), folder = nil, expected = n, bound = {}, count = 0 }) end
		end
	end
	return setmetatable({
		root = root, holders = holders, entries = {} :: { Entry }, at = nil :: Vector3?, boundAt = -math.huge, checkAt = 1,
		passes = 0, writes = 0, -- (counts, for the tests and the self-test's INFO line)
	}, WorldShadows)
end

-- Takes in the boxes of the regions not yet whole that have arrived: a visible box casting its shadow (as the server builds every box not under a drawing) is kept,
-- and given the rule's answer now if the spider's place is known; a hidden one is never touched.
function WorldShadows.bind(self: any)
	for _, h: Holder in self.holders do
		if h.count < h.expected then
			if h.folder == nil or h.folder.Parent ~= self.root then h.folder = self.root:FindFirstChild(h.id) end
			local folder = h.folder
			if folder ~= nil then
				for _, p in folder:GetChildren() do
					if h.bound[p] == nil and p:IsA("BasePart") then
						h.bound[p] = true
						h.count += 1
						local part = p :: BasePart
						if part.Transparency < 1 and part.CastShadow ~= false then
							local size, at = part.Size, part.Position
							local e: Entry = { part = part, folder = folder, lo = at - size * 0.5, hi = at + size * 0.5, mid = WorldShadows.middle(size), on = true }
							table.insert(self.entries, e)
							local pos = self.at
							if pos ~= nil and not WorldShadows.casts(e.lo, e.hi, e.mid, pos) then
								part.CastShadow = false
								e.on = false
								self.writes += 1
							end
						end
					end
				end
			end
		end
	end
end

-- Lets go of a box that is no longer in its folder (streamed out): its region is looked at again for it.
local function release(self: any, i: number)
	local e: Entry = self.entries[i]
	for _, h: Holder in self.holders do
		if h.bound[e.part] then h.bound[e.part] = nil; h.count -= 1; break end
	end
	self.entries[i] = self.entries[#self.entries]
	self.entries[#self.entries] = nil
end

-- Asks the rule of every box with the spider at `pos` and writes the ones whose answer changed. Returns how many it wrote.
function WorldShadows.pass(self: any, pos: Vector3): number
	self.at = pos
	self.passes += 1
	local wrote = 0
	local entries = self.entries
	local i = 1
	while i <= #entries do
		local e: Entry = entries[i]
		local want = WorldShadows.casts(e.lo, e.hi, e.mid, pos)
		if want ~= e.on then
			if e.part.Parent ~= e.folder then
				release(self, i)
				continue
			end
			e.part.CastShadow = want
			e.on = want
			wrote += 1
		end
		i += 1
	end
	self.writes += wrote
	return wrote
end

-- Each frame (`now`: the clock): a pass when the spider has moved PASS_MOVE studs since the last (or there has been none), and every BIND_EVERY seconds the boxes
-- that have arrived taken in and a slice of the bound ones checked.
function WorldShadows.update(self: any, pos: Vector3, now: number)
	if now - self.boundAt >= WorldShadows.BIND_EVERY then
		self.boundAt = now
		local entries = self.entries
		local n = math.min(WorldShadows.CHECK_SLICE, #entries)
		for _ = 1, n do
			if self.checkAt > #entries then self.checkAt = 1 end
			local e: Entry = entries[self.checkAt]
			if e.part.Parent ~= e.folder then release(self, self.checkAt) else self.checkAt += 1 end
		end
		self:bind()
	end
	local last = self.at
	if last == nil or (pos - last).Magnitude >= WorldShadows.PASS_MOVE then self:pass(pos) end
end

-- How many boxes it keeps (visible ones that may cast), and how many of them cast now.
function WorldShadows.counts(self: any): (number, number)
	local on = 0
	for _, e: Entry in self.entries do if e.on then on += 1 end end
	return #self.entries, on
end

return WorldShadows
