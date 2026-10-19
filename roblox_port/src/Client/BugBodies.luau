--!strict
-- The drawn woodlice (ROBLOX-96, Prey/Woodlouse): a grey segmented body about a centimetre long, made of seven overlapping plates over the back, a small head
-- with two antennae and seven pairs of short legs (woodlice are isopods: seven pairs of walking legs), each louse PARTS parts under the fly's budget, all
-- anchored, never colliding, never seen by a ray and casting no shadow (Habitat/Shapes), placed with one Workspace:BulkMoveTo each frame like the flies. A louse
-- under cover (state "hidden") is drawn a stud and a half under the soil, inside the solid ground, so nothing of it shows; it comes back up where it went under.
-- Display only: the sim decides where each louse is and whether it is hiding; nothing here feeds back.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))

local BugBodies = {}
BugBodies.__index = BugBodies

-- The most parts a woodlouse may be drawn with (the sheet below makes exactly this many).
BugBodies.PARTS = 24
-- How far under the soil a hidden louse is kept.
BugBodies.UNDER = 1.5

-- The sheet: body frame -Z forward, +Y up, the origin the body's centre at Woodlouse.HOVER above the soil, the feet at y = -0.12.
BugBodies.look = {
	colors = { plate = "6b6d6a", plateDark = "5c5e5b", head = "55575a", antenna = "4a4c4f", leg = "7a7c78" },
	plates = 7, plateLength = 0.17, plateWidth = 0.5, plateHeight = 0.26, from = -0.33, pitch = 0.12, -- seven plates from z -0.33 back, every 0.12: a 1.0 long body
	head = { at = { 0, -0.02, -0.44 }, size = { 0.3, 0.2, 0.16 } },
	antenna = { from = { 0.08, 0.02, -0.5 }, to = { 0.22, 0.06, -0.72 }, d = 0.016 },
	leg = { hipX = 0.2, hipY = -0.02, footX = 0.32, footY = -0.12, d = 0.018, from = -0.33, pitch = 0.12 },
}

type Spec = { name: string, rod: boolean, color: Color3, size: Vector3, frame: CFrame }

local function rodBetween(a: Vector3, b: Vector3, diameter: number): (Vector3, CFrame)
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
end

local function build(): { Spec }
	local L = BugBodies.look
	local specs: { Spec } = {}
	local function color(name: string): Color3
		return Color3.fromHex(L.colors[name])
	end
	for i = 1, L.plates do
		local z = L.from + (i - 1) * L.pitch
		local arch = 1 - 0.18 * math.abs((i - (L.plates + 1) / 2) / ((L.plates - 1) / 2)) -- the back is highest and widest in the middle
		table.insert(specs, { name = "Plate" .. i, rod = false, color = color(if i % 2 == 0 then "plateDark" else "plate"),
			size = Vector3.new(L.plateWidth * arch, L.plateHeight * arch, L.plateLength), frame = CFrame.new(0, 0.01, z) })
	end
	table.insert(specs, { name = "Head", rod = false, color = color("head"), size = Vector3.new(L.head.size[1], L.head.size[2], L.head.size[3]), frame = CFrame.new(L.head.at[1], L.head.at[2], L.head.at[3]) })
	for _, side in { -1, 1 } do
		local word = if side < 0 then "Left" else "Right"
		local a = Vector3.new(L.antenna.from[1] * side, L.antenna.from[2], L.antenna.from[3])
		local b = Vector3.new(L.antenna.to[1] * side, L.antenna.to[2], L.antenna.to[3])
		local size, frame = rodBetween(a, b, L.antenna.d)
		table.insert(specs, { name = word .. "Antenna", rod = true, color = color("antenna"), size = size, frame = frame })
		for i = 1, 7 do
			local z = L.leg.from + (i - 1) * L.leg.pitch
			local hip, foot = Vector3.new(L.leg.hipX * side, L.leg.hipY, z), Vector3.new(L.leg.footX * side, L.leg.footY, z + 0.02)
			local ls, lf = rodBetween(hip, foot, L.leg.d)
			table.insert(specs, { name = `{word}Leg{i}`, rod = true, color = color("leg"), size = ls, frame = lf })
		end
	end
	return specs
end

function BugBodies.new(parent: Instance): any
	local folder = Instance.new("Folder")
	folder.Name = "Bugs"
	folder.Parent = parent
	return setmetatable({ folder = folder, rigs = {}, template = build(), parts = {}, frames = {} }, BugBodies)
end

-- One louse's parts.
function BugBodies.spawn(self: any, id: string): any
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = self.folder
	local parts: { Part } = {}
	for i, spec in self.template do
		local part: Part
		if spec.rod then
			part = Shapes.block(folder, spec.name, spec.size, spec.frame, spec.color, "SmoothPlastic")
			part.Shape = Enum.PartType.Cylinder
		else
			part = Shapes.ellipsoid(folder, spec.name, spec.size, spec.frame, spec.color, "SmoothPlastic")
		end
		parts[i] = part
	end
	local rig = { folder = folder, parts = parts }
	self.rigs[id] = rig
	return rig
end

-- Places every louse's parts: `lice` are the sim's (id, position, heading, state).
function BugBodies.draw(self: any, lice: { any })
	local parts: { BasePart } = self.parts
	local frames: { CFrame } = self.frames
	table.clear(parts)
	table.clear(frames)
	local present: { [string]: boolean } = {}
	for _, w in lice do
		present[w.id] = true
		local rig = self.rigs[w.id] or self:spawn(w.id)
		local heading: Vector3 = w.heading
		if heading.Magnitude < 1e-6 then heading = -Vector3.zAxis end
		local position: Vector3 = w.position
		if w.state == "hidden" then position -= Vector3.new(0, BugBodies.UNDER, 0) end
		local body = CFrame.lookAt(position, position + heading, Vector3.yAxis)
		for i, part in rig.parts do
			table.insert(parts, part)
			table.insert(frames, body * self.template[i].frame)
		end
	end
	for id, rig in self.rigs do
		if not present[id] then
			rig.folder:Destroy()
			self.rigs[id] = nil
		end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
end

return BugBodies
