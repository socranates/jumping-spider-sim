--!strict
-- The ranger hut's own life on this client (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B): the window's sash, shut through the nursery and propped open by the
-- ranger when the spider is ready (Life/Nursery), and the desk lamp at night. Made with the looks, in the preserve only (Client/WorldClient.streamLooks).
--
-- The sash. While the window is shut a box fills the lower sash's gap (World/Hut.SASH, the sill's own opening between the back frame's pieces): a part of this
-- client's, in the World folder the sim's rays include, so the spider cannot pass; it is drawn as the lowered sash's glass and its bottom rail, and the sill's
-- Decor's raised sash (its rail and top) is hidden on this client while it is down. When the rule says the window opens, the moment is told by the world and by
-- nothing on the screen: a ranger's hand comes up outside the glass, lifts the sash the six centimetres the sill's window has always been open, sets a wedge of
-- wood under it at its east end and goes. From then on the window stays open (`open`), the wedge a box of the world (the gap beside it is the way out), and the
-- progress record keeps it (Persistence/SaveProgress hut_window, through Client/SpiderClient). A save that has it opens the window at once, without the moment.
--
-- The lamp. A warm point light under the desk lamp's shade (World/Hut's look draws the bulb), lit while the light of the hour is low (the life clock's daylight).
-- (ROBLOX-119) And the lamppost by the bench at the meadow's edge: its lantern (World/Meadow.LANTERN) lit by the same rule, a wider, whiter light; its moths are the
-- bestiary's at the lantern (World/Meadow.LIFE), restless from dusk.
-- Nothing here has run in Studio: the hand's motion, the light's look and the sash's feel are untested in the engine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hut = require(Shared:WaitForChild("World"):WaitForChild("Hut"))
local Meadow = require(Shared:WaitForChild("World"):WaitForChild("Meadow"))
local Nursery = require(Shared:WaitForChild("Life"):WaitForChild("Nursery"))

local HutLife = {}
HutLife.__index = HutLife

-- The moment's beats (seconds from its start): the hand comes up, lifts, sets the wedge, goes.
HutLife.BEATS = table.freeze({ arrive = 1.4, lift = 3.2, wedge = 4.2, leave = 5.8 })
-- The wedge under the raised sash, at the gap's east end (studs, the sill's frame), and how far the sash goes up.
HutLife.WEDGE = table.freeze({ min = Vector3.new(6.2, 0.7, -13.5), max = Vector3.new(8, 6, -12.5) })
HutLife.LIFT = 5.3
-- The lamp: lit below this daylight (Life/LifeClock.daylight), its light's colour, brightness and range (studs).
HutLife.LAMP = table.freeze({ below = 0.35, at = Vector3.new(110, 31, 24), brightness = 1.6, range = 90, color = Color3.fromRGB(255, 214, 160) })
HutLife.STREET = table.freeze({ at = Meadow.LANTERN.at, brightness = 2.2, range = 60, color = Color3.fromRGB(255, 226, 190) }) -- (ROBLOX-119: the lamppost's lantern)
-- The folder this client's parts of the hut go in, in the World folder (the rays see the sash and the wedge; the drawn ones are never queried).
HutLife.FOLDER = "HutLife"

local SKIN = Color3.fromRGB(196, 150, 120)
local SLEEVE = Color3.fromRGB(70, 92, 66)

local function part(parent: Instance, name: string, lo: Vector3, hi: Vector3, color: Color3, transparency: number, solid: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = hi - lo
	p.Position = (lo + hi) * 0.5
	p.Color = color
	p.Transparency = transparency
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = solid -- (the sim's rays see only what is solid)
	p.CastShadow = false
	p.Material = if transparency > 0 then Enum.Material.Glass else Enum.Material.Wood
	if solid then
		p:SetAttribute("SurfaceId", name)
		p:SetAttribute("ProfileId", if transparency > 0 then "glass_clean" else "bare_wood_rough")
	end
	p.Parent = parent
	return p
end

-- `root`: the World folder (the rays' root); `decor`: the sill's Decor (its raised sash is hidden while the window is shut), or nil; `seed`: the world's seed for
-- the ranger's hour; `ws`: where the lamp goes (the workspace).
function HutLife.new(root: Instance, decor: Instance?, seed: number, ws: Instance): any
	local folder = Instance.new("Folder")
	folder.Name = HutLife.FOLDER
	folder.Parent = root
	local self = setmetatable({
		folder = folder, decor = decor, seed = seed, open = false, opened = 0, -- (`opened`: how many times the window opened this session, for the tests)
		trial = false, -- (the self-test's own opening: the progress record never keeps it, HutLife.reshut puts the window back)
		moment = nil :: number?, -- when the ranger's moment began (the clock's), while it runs
		sash = nil :: BasePart?, rail = nil :: BasePart?, wedge = nil :: BasePart?, hand = nil :: { BasePart }?,
		lamp = nil :: Instance?, lit = false, hidden = {} :: { [Instance]: number }, street = nil :: Instance?, -- (ROBLOX-119: the lamppost's light, lit with the lamp)
	}, HutLife)
	self:shut()
	local holder = Instance.new("Part")
	holder.Name = "HutLamp"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = HutLife.LAMP.at
	local light = Instance.new("PointLight")
	light.Name = "Light"
	;(light :: any).Brightness = HutLife.LAMP.brightness
	;(light :: any).Range = HutLife.LAMP.range
	;(light :: any).Color = HutLife.LAMP.color
	;(light :: any).Shadows = true
	;(light :: any).Enabled = false
	light.Parent = holder
	holder.Parent = ws
	self.lamp = holder
	-- (ROBLOX-119) the lamppost's lantern
	local street = Instance.new("Part")
	street.Name = "StreetLamp"
	street.Anchored = true
	street.CanCollide = false
	street.CanQuery = false
	street.CanTouch = false
	street.Transparency = 1
	street.Size = Vector3.new(1, 1, 1)
	street.Position = HutLife.STREET.at
	local sl = Instance.new("PointLight")
	sl.Name = "Light"
	;(sl :: any).Brightness = HutLife.STREET.brightness
	;(sl :: any).Range = HutLife.STREET.range -- (a PointLight reaches 60 studs at most: 60 cm round the lantern)
	;(sl :: any).Color = HutLife.STREET.color
	;(sl :: any).Shadows = true
	;(sl :: any).Enabled = false
	sl.Parent = street
	street.Parent = ws
	self.street = street
	return self
end

-- The sill's Decor's raised sash (its bottom rail and its top), hidden while the sash is down and shown again when it is up.
local function raisedSash(self: any, show: boolean)
	local decor = self.decor
	local wall = if decor then decor:FindFirstChild("Wall") else nil
	local rail = if wall then wall:FindFirstChild("SashRail") else nil
	local top = if wall then wall:FindFirstChild("SashTop") else nil
	-- Streamed-out/replaced visuals must not retain a hidden-state reference.
	for p, transparency in self.hidden do
		if p ~= rail and p ~= top then (p :: BasePart).Transparency = transparency; self.hidden[p] = nil end
	end
	if wall == nil then return end
	for _, name in { "SashRail", "SashTop" } do
		local p = wall:FindFirstChild(name)
		if p ~= nil and p:IsA("BasePart") then
			if show then
				local was = self.hidden[p]
				if was ~= nil then (p :: BasePart).Transparency = was; self.hidden[p] = nil end
			elseif self.hidden[p] == nil then
				self.hidden[p] = (p :: BasePart).Transparency
				;(p :: BasePart).Transparency = 1
			end
		end
	end
end

-- Decor (and its two sash parts) may arrive after construction or be replaced.
-- Reconcile only the visual state; never recreate collision or replay opening.
function HutLife.bindDecor(self: any, decor: Instance?)
	self.decor = decor
	raisedSash(self, self.open)
end

-- The sash down: the gap filled, drawn as the lowered sash's glass over its bottom rail.
function HutLife.shut(self: any)
	if self.sash ~= nil then return end
	local S = Hut.SASH
	self.sash = part(self.folder, "hut_sash", S.min, S.max, Color3.fromHex("a9c2c1"), 0.55, true)
	self.rail = part(self.folder, "SashBottomRail", Vector3.new(S.min.X - 0.5, S.min.Y, S.min.Z + 0.12), Vector3.new(S.max.X + 0.5, S.min.Y + 0.8, S.min.Z + 0.57), Color3.fromHex("ded7c3"), 0, false)
	raisedSash(self, false)
end

-- The sash up and wedged (at once: a save that has it, the moment's end).
function HutLife.propped(self: any)
	if self.sash ~= nil then self.sash:Destroy(); self.sash = nil end
	if self.rail ~= nil then self.rail:Destroy(); self.rail = nil end
	if self.hand ~= nil then for _, p in self.hand do p:Destroy() end; self.hand = nil end
	if self.wedge == nil then self.wedge = part(self.folder, "hut_sash_wedge", HutLife.WEDGE.min, HutLife.WEDGE.max, Color3.fromHex("9c7650"), 0, true) end
	raisedSash(self, true)
	if not self.open then self.opened += 1 end
	self.open = true
	self.moment = nil
end

-- (the self-test's) The window put back as it was before a trial opening (`trial`: an opening the self-test made, which the progress record never keeps).
function HutLife.reshut(self: any)
	if self.hand ~= nil then for _, p in self.hand do p:Destroy() end; self.hand = nil end
	if self.wedge ~= nil then self.wedge:Destroy(); self.wedge = nil end
	if self.sash ~= nil then self.sash:Destroy(); self.sash = nil end
	if self.rail ~= nil then self.rail:Destroy(); self.rail = nil end
	self.open, self.moment, self.trial = false, nil, false
	self:shut()
end

-- A save says the window is open: open it now, without the moment.
function HutLife.restore(self: any, open: boolean)
	if open and not self.open then self:propped() end
end

local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return a + (b - a) * math.clamp(t, 0, 1)
end
local function ease(t: number): number
	local s = math.clamp(t, 0, 1)
	return s * s * (3 - 2 * s)
end

-- The ranger's hand: a sleeve, a forearm and a hand with its thumb, outside the glass; placed at `at` (the fingers' grip on the sash's bottom rail).
local function placeHand(self: any, at: Vector3)
	if self.hand == nil then
		local hand = {}
		for _, spec in { { name = "Sleeve", color = SLEEVE }, { name = "Forearm", color = SKIN }, { name = "Hand", color = SKIN }, { name = "Thumb", color = SKIN } } do
			table.insert(hand, part(self.folder, spec.name, Vector3.zero, Vector3.one, spec.color, 0, false))
		end
		self.hand = hand
	end
	local h = self.hand :: { BasePart }
	-- the hand flat under the rail, the forearm down and out from it toward the outer sill's edge, the sleeve beyond
	h[3].Size, h[3].Position = Vector3.new(9, 2.6, 9), at + Vector3.new(0, -1.3, -4.5)
	h[4].Size, h[4].Position = Vector3.new(2.2, 2.2, 5), at + Vector3.new(5.4, -0.6, -3.2)
	h[2].Size, h[2].CFrame = Vector3.new(7, 7, 26), CFrame.new(at + Vector3.new(0, -9, -18)) * CFrame.Angles(math.rad(-40), 0, 0)
	h[1].Size, h[1].CFrame = Vector3.new(10, 10, 20), CFrame.new(at + Vector3.new(0, -24, -33)) * CFrame.Angles(math.rad(-40), 0, 0)
end

-- Each frame (Client/WorldClient.update): the rule, the moment while it runs, and the lamp. `life`: the client's life loop (its growth, its clock and its
-- daylight); `now`: a clock in seconds.
function HutLife.update(self: any, life: any, now: number)
	if life ~= nil and not self.open and self.moment == nil then
		local g, c = life.growth, life.clock
		if g ~= nil and c ~= nil and Nursery.opens(self.seed, g.stage, g:isMoulting(), g:isSoft(), c.day, c.hour) then
			self.moment = now
		end
	end
	local t0 = self.moment
	if t0 ~= nil then
		local t = now - t0
		local B = HutLife.BEATS
		local S = Hut.SASH
		local grip = Vector3.new(0, S.min.Y + 0.4, S.min.Z - 0.6)
		if t < B.arrive then
			placeHand(self, lerp(grip + Vector3.new(0, -30, -30), grip, ease(t / B.arrive)))
		elseif t < B.lift then
			local u = ease((t - B.arrive) / (B.lift - B.arrive))
			if self.sash ~= nil then self.sash.CanQuery = false end -- (the gap is the spider's from the moment the sash moves)
			local up = Vector3.yAxis * HutLife.LIFT * u
			if self.sash ~= nil then self.sash.Position = (S.min + S.max) * 0.5 + up end
			if self.rail ~= nil then self.rail.Position = Vector3.new(0, S.min.Y + 0.4, S.min.Z + 0.345) + up end
			placeHand(self, grip + up)
		elseif t < B.wedge then
			if self.wedge == nil then self.wedge = part(self.folder, "hut_sash_wedge", HutLife.WEDGE.min, HutLife.WEDGE.max, Color3.fromHex("9c7650"), 0, true) end
			placeHand(self, grip + Vector3.yAxis * HutLife.LIFT + Vector3.new(6, -2, 0))
		elseif t < B.leave then
			local u = ease((t - B.wedge) / (B.leave - B.wedge))
			placeHand(self, lerp(grip + Vector3.new(6, HutLife.LIFT - 2, 0), grip + Vector3.new(6, -30, -30), u))
		else
			self:propped()
		end
	end
	-- the lamp at night
	if self.lamp ~= nil and life ~= nil then
		local lit = (life.daylight or 1) < HutLife.LAMP.below
		if lit ~= self.lit then
			self.lit = lit
			local light = self.lamp:FindFirstChild("Light")
			if light ~= nil then (light :: any).Enabled = lit end
			local street = if self.street ~= nil then self.street:FindFirstChild("Light") else nil
			if street ~= nil then (street :: any).Enabled = lit end
		end
	end
end

-- Whether the window's gap is the spider's (the sash up, or on its way up).
function HutLife.passable(self: any): boolean
	return self.open or (self.sash ~= nil and self.sash.CanQuery == false)
end

return HutLife
