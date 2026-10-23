--!strict
-- The drawn mud dauber wasp (Data/WaspLook has every number): about 2.5 cm long, built from ellipsoids and rods as the fly is
-- (Client/FlyBodies, ROBLOX-22): a black head with big dark eyes and yellow mandibles, a black thorax with a yellow collar and
-- scutellum, a very long thin yellow petiole and a black gaster, six long legs (black femurs, a yellow band at each knee, yellow
-- tibias and feet), two smoky dark wings each side and two curled antennae that flick while it searches. Every part is anchored, never
-- collides, is never seen by a ray and casts no shadow (Habitat/Shapes). One Workspace:BulkMoveTo places all its parts each frame.
-- Poses: flying (legs trailing, wings a soft translucent blur of the stroke), walking (legs striding at 3 Hz, wings folded back),
-- holding (flying, with the front legs clutching what hangs under it). Display only: where it is, which way it faces, its mode and how
-- busily it searches come from the WaspDirector; nothing here feeds back. Godot's WaspBody (wasp_body.gd) is the source of the joints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WaspLook = require(Shared:WaitForChild("Data"):WaitForChild("WaspLook"))
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))

local WaspBody = {}
WaspBody.__index = WaspBody

local TAU = math.pi * 2
local PHASE = 0.37 -- Godot builds the wasp with this phase for its beat

type Spec = { name: string, rod: boolean, color: Color3, reflectance: number }

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function mirrored(t: { number }, side: number): Vector3
	return Vector3.new(t[1] * side, t[2], t[3])
end

-- The size and frame of a rod (a Cylinder part: its axis is X) from a to b.
local function rodBetween(a: Vector3, b: Vector3, diameter: number, grow: number?): (Vector3, CFrame)
	local d = b - a
	local length = math.max(d.Magnitude, 1e-4)
	local dir = d / length
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local g = grow or 0
	return Vector3.new(length, diameter + g, diameter + g), CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
end

-- Euler turns as Godot applies them: about y, then x, then z.
local function euler(rx: number, ry: number, rz: number): CFrame
	return CFrame.Angles(0, ry, 0) * CFrame.Angles(rx, 0, 0) * CFrame.Angles(0, 0, rz)
end

-- The parts, in a fixed order: the static ones, then the antennae, the legs, the wings. `index` finds a part by name.
local function build(): ({ Spec }, { [string]: number })
	local C, G = WaspLook.colors, WaspLook.gloss
	local specs: { Spec } = {}
	local index: { [string]: number } = {}
	local function add(name: string, rod: boolean, colorName: string, gloss: number?)
		table.insert(specs, { name = name, rod = rod, color = Color3.fromHex(C[colorName]), reflectance = gloss or G[colorName] or 0 })
		index[name] = #specs
	end
	for _, item in WaspLook.body do add(item.name, false, item.color) end
	add("Petiole", true, WaspLook.petiole.color)
	local A = WaspLook.antenna
	for _, side in { "L", "R" } do
		for i = 1, #A.diameters do add(`Antenna{side}{i}`, true, A.colors[i]) end
	end
	local L = WaspLook.legs
	for _, side in { "L", "R" } do
		for pair = 1, #L.hips do
			add(`Leg{side}{pair}Femur`, true, "black")
			add(`Leg{side}{pair}Tibia`, true, "yellow")
			add(`Leg{side}{pair}Tarsus`, true, "yellow")
			add(`Leg{side}{pair}Band`, true, "yellow")
		end
	end
	local W = WaspLook.wing
	for _, side in { "L", "R" } do
		for k = 1, 2 do
			add(`Wing{side}{k}`, false, "wing", W.reflectance)
			add(`Wing{side}{k}Vein`, true, "vein", 0)
			add(`Wing{side}{k}Blur`, false, "blur", 0)
		end
	end
	return specs, index
end

function WaspBody.new(parent: Instance): any
	local folder = Instance.new("Folder")
	folder.Name = "Wasp"
	local specs, index = build()
	local parts: { Part } = {}
	for i, spec in specs do
		local part: Part
		if spec.rod then
			part = Shapes.block(folder, spec.name, Vector3.one * 0.05, CFrame.new(), spec.color, "SmoothPlastic")
			part.Shape = Enum.PartType.Cylinder
		else
			part = Shapes.ellipsoid(folder, spec.name, Vector3.one * 0.1, CFrame.new(), spec.color, "SmoothPlastic")
		end
		part.Reflectance = spec.reflectance
		parts[i] = part
	end
	local self = setmetatable({
		parent = parent, folder = folder, specs = specs, index = index, parts = parts, shown = false,
		sizes = {} :: { Vector3 }, frames = {} :: { CFrame }, transparency = {} :: { number }, world = {} :: { CFrame }, moved = {} :: { Part },
		bob = 0.0,
	}, WaspBody)
	self:pose("flying", 0, 0)
	return self
end

-- The pose of every part in the torso's frame, for this mode ("flying", "walking" or "holding"), time `beat` (seconds) and how busily
-- the antennae flick (0 to 1): fills self.sizes, self.frames and self.transparency (indexed as the parts), and self.bob (the torso's rise).
function WaspBody.pose(self: any, mode: string, beat: number, search: number)
	local sizes, frames, trans, index = self.sizes, self.frames, self.transparency, self.index
	local walking, holding = mode == "walking", mode == "holding"
	local function set(name: string, size: Vector3, frame: CFrame, transparency: number?)
		local i = index[name]
		sizes[i], frames[i], trans[i] = size, frame, transparency or 0
	end
	-- Body geometry is invariant for the lifetime of this rig.
	if not self.bodyReady then
	-- the body
	for _, item in WaspLook.body do
		set(item.name, vec(item.size), CFrame.new(vec(item.at)), 0)
	end
	local P = WaspLook.petiole
	local psize, pframe = rodBetween(vec(P.from), vec(P.to), P.diameter)
	set("Petiole", psize, pframe, 0)
	self.bodyReady=true
	end
	-- the antennae
	local A = WaspLook.antenna
	for i, word in { "L", "R" } do
		local side = if i == 1 then -1 else 1
		local flick = math.clamp(search, 0, 1) * math.sin(TAU * (A.hertz[1] + A.hertz[2] * (i - 1)) * beat + PHASE) * A.flick
		local node = CFrame.new(mirrored(A.base, side)) * euler(A.rest[1] + flick, side * A.rest[2] + flick * 0.5, 0)
		for s = 1, #A.diameters do
			local size, frame = rodBetween(node * mirrored(A.points[s], side), node * mirrored(A.points[s + 1], side), A.diameters[s])
			set(`Antenna{word}{s}`, size, frame, 0)
		end
	end
	-- Flying/holding legs have no time-dependent motion. Walking always steps.
	local legMode=if walking then "walking" elseif holding then "holding" else "flying"
	if walking or self.legMode~=legMode then
	-- the legs
	local L, walk = WaspLook.legs, WaspLook.walk
	for sideIndex, word in { "L", "R" } do
		local side = if sideIndex == 1 then -1 else 1
		for pair = 0, #L.hips - 1 do
			local hip = Vector3.new(side * L.hips[pair + 1][1], L.hips[pair + 1][2], L.hips[pair + 1][3])
			local knee = Vector3.new(side * (0.35 + 0.05 * pair), -0.25, 0.04 + 0.15 * pair)
			local ankle = Vector3.new(side * (0.52 + 0.09 * pair), -0.58, 0.10 + 0.23 * pair)
			local tip = ankle + Vector3.new(side * 0.03, -0.12, 0.12)
			if walking then
				-- the actor stands 0.35 above its surface: the feet reach it
				knee, ankle, tip = Vector3.new(knee.X, -0.08, knee.Z), Vector3.new(ankle.X, -0.20, ankle.Z), Vector3.new(tip.X, -0.23, tip.Z)
				local cycle = TAU * walk.hertz * beat + PHASE + math.pi * ((pair + (sideIndex - 1)) % 2)
				local stride = Vector3.new(0, math.max(0, math.sin(cycle)) * walk.lift, math.cos(cycle) * walk.reach)
				ankle += stride
				tip += stride
			elseif holding and pair < 2 then
				knee, ankle, tip = Vector3.new(side * 0.30, -0.26, -0.05), Vector3.new(side * 0.18, -0.58, -0.07), Vector3.new(side * 0.08, -0.60, -0.16)
			else
				ankle += Vector3.new(0, 0, 0.25 + 0.14 * pair)
				tip = ankle + Vector3.new(0, -0.11, 0.14)
			end
			local name = `Leg{word}{pair + 1}`
			local s1, f1 = rodBetween(hip, hip + knee, L.femur)
			local s2, f2 = rodBetween(hip + knee, hip + ankle, L.tibia)
			local s3, f3 = rodBetween(hip + ankle, hip + tip, L.tarsus)
			local along = knee.Unit
			local s4, f4 = rodBetween(hip + knee - along * L.band.length, hip + knee, L.femur, L.band.grow)
			set(name .. "Femur", s1, f1, 0)
			set(name .. "Tibia", s2, f2, 0)
			set(name .. "Tarsus", s3, f3, 0)
			set(name .. "Band", s4, f4, 0)
		end
	end
	self.legMode=legMode
	end
	-- Folded wings stay fixed; flight wings still shimmer on every draw.
	if not walking or not self.wingsFolded then
	-- the wings: folded back on the ground; in the air a soft translucent blur of the stroke, a little unsteady
	local W = WaspLook.wing
	for sideIndex, word in { "L", "R" } do
		local side = if sideIndex == 1 then -1 else 1
		for k = 1, 2 do
			local share = if k == 1 then 1.0 else W.hindShare
			local pivotAt = Vector3.new(side * W.root[1], W.root[2], W.root[3] + (k - 1) * W.hindStep)
			local yaw, roll = W.folded.yaw, W.folded.roll
			local transparency = W.transparency
			if not walking then
				yaw, roll = W.flight.yaw, W.flight.roll + W.flight.shimmerRoll * math.sin(TAU * W.flight.shimmerHertz * beat + PHASE + k)
				transparency = W.flightTransparency
			end
			local pivot = CFrame.new(pivotAt) * euler(0, math.rad(side * yaw), math.rad(-side * roll))
			local blade = CFrame.new(side * W.centre[1] * share, 0, W.centre[3] * share) * CFrame.Angles(0, math.rad(side * W.sweep), 0)
			local size = Vector3.new(W.width * share, W.thick, W.length * share)
			set(`Wing{word}{k}`, size, pivot * blade, transparency)
			local vsize, vframe = rodBetween(pivot * Vector3.new(0, W.thick, 0.02), pivot * Vector3.new(side * W.vein.tipX * share, W.thick, W.vein.to * W.length * share), W.vein.diameter)
			set(`Wing{word}{k}Vein`, vsize, vframe, transparency * 0.4)
			local widen = if walking then 1.0 else W.blur.widen
			set(`Wing{word}{k}Blur`, Vector3.new(W.width * share * widen, W.thick * 2, W.length * share), pivot * blade, if walking then 1.0 else W.blur.transparency)
		end
	end
	end
	self.wingsFolded=walking
	self.bob = if walking then 0.0 else WaspLook.bob.height * math.sin(TAU * WaspLook.bob.hertz * beat + PHASE)
end

-- Draws it as the director has it: `wasp` = { position, heading, mode, search, visible }, `now` the time in seconds. Hidden (taken out of
-- the world) while it is away.
function WaspBody.draw(self: any, wasp: any, now: number)
	if not wasp.visible then
		if self.shown then
			self.shown = false
			self.folder.Parent = nil
		end
		return
	end
	if not self.shown then
		self.shown = true
		self.folder.Parent = self.parent
	end
	self:pose(wasp.mode, now, wasp.search)
	local body = CFrame.lookAt(wasp.position, wasp.position + wasp.heading, Vector3.yAxis) * CFrame.new(0, self.bob, 0)
	local moved, world = self.moved, self.world
	table.clear(moved)
	for i, part in self.parts do
		local size = self.sizes[i]
		if part.Size ~= size then part.Size = size end
		if part.Transparency ~= self.transparency[i] then part.Transparency = self.transparency[i] end
		moved[i] = part
		world[i] = body * self.frames[i]
	end
	Workspace:BulkMoveTo(moved, world, Enum.BulkMoveMode.FireCFrameChanged)
end

function WaspBody.destroy(self: any)
	self.folder:Destroy()
end

return WaspBody
