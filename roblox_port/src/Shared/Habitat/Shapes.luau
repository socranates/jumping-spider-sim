--!strict
-- Drawn-only parts for the decor builders (Habitat/Scenery, Plants, Patina) and the fly (Client/FlyBodies): every part is anchored, nothing collides with it, no
-- ray sees it and nothing touches it, so the spider's rays, the camera's casts and the jump planner never meet it. Round things are
-- Cylinder parts (their axis is local X, as in Roblox) or SpecialMesh ellipsoids (Roblox forces a Ball part to be a sphere), as the
-- spider rig does. A flat leaf is a rounded slab: a cross of two boxes and four discs.
local Layout = require(script.Parent.WindowsillLayout)
local Materials = require(script.Parent.Materials)

local Shapes = {}

-- The sill piece with this id (WindowsillLayout.PIECES): the physical box that a drawn shape stands in for or sits on.
function Shapes.piece(id: string): Layout.Piece
	for _, p in Layout.PIECES do
		if p.id == id then return p end
	end
	error("no piece " .. id)
end

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Shapes.hex = hex

-- A drawn-only block: anchored; nothing collides with it, no ray sees it. Small things cast no shadow (callers switch it on).
function Shapes.block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Materials.get(material)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- An ellipsoid with these full diameters (x, y, z of `cframe`).
function Shapes.ellipsoid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: string): Part
	local p = Shapes.block(parent, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A flat disc whose axis points up: diameter and thickness, centred at `at`.
function Shapes.disc(parent: Instance, name: string, diameter: number, thickness: number, at: Vector3, color: Color3, material: string): Part
	local p = Shapes.block(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round rod from a to b (a Cylinder part: its axis is X, so Size is length, diameter, diameter).
function Shapes.rod(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: string): Part
	local up = if math.abs((b - a).Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis -- a rod along the up vector has no turn to give
	local p = Shapes.block(parent, name, Vector3.new((b - a).Magnitude, diameter, diameter),
		CFrame.lookAt((a + b) * 0.5, b, up) * CFrame.Angles(0, math.pi / 2, 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A thin square-edged strand or line from a to b: `width` across, `height` tall, as long as a to b.
function Shapes.strip(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, height: number, color: Color3, material: string): Part
	local up = if math.abs((b - a).Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Shapes.block(parent, name, Vector3.new(width, height, (b - a).Magnitude), CFrame.lookAt((a + b) * 0.5, b, up), color, material)
end

-- A slab with rounded corners in plan, between `lo` and `hi`: two boxes in a cross and a disc in each corner, all the same
-- colour. The boxes' tops are the slab's top; the discs and the second box sit a hair lower so no two faces share a plane.
function Shapes.roundedSlab(parent: Instance, name: string, lo: Vector3, hi: Vector3, radius: number, color: Color3, material: string): { Part }
	local width, depth, height = hi.X - lo.X, hi.Z - lo.Z, hi.Y - lo.Y
	local r = math.min(radius, width / 2, depth / 2)
	local centre = (lo + hi) * 0.5
	local out: { Part } = {}
	table.insert(out, Shapes.block(parent, name .. "A", Vector3.new(width, height, depth - 2 * r), CFrame.new(centre), color, material))
	local lower = 0.0008
	table.insert(out, Shapes.block(parent, name .. "B", Vector3.new(width - 2 * r, height - lower, depth), CFrame.new(centre - Vector3.new(0, lower / 2, 0)), color, material))
	local dh = height - 0.0016
	for i, corner in { { lo.X + r, lo.Z + r }, { hi.X - r, lo.Z + r }, { lo.X + r, hi.Z - r }, { hi.X - r, hi.Z - r } } do
		table.insert(out, Shapes.disc(parent, name .. "C" .. i, 2 * r, dh, Vector3.new(corner[1], lo.Y + dh / 2, corner[2]), color, material))
	end
	return out
end

-- Whether a drawn thing may stand at (x, z) on a surface at height `y` (ROBLOX-74): not inside the footprint of a piece that rises from that
-- height (grown by `margin`), not within SPAWN_CLEAR of the spawn and not in or by the silk retreat. Reads the layout and changes nothing in it.
Shapes.SPAWN_CLEAR = 4.5
Shapes.RETREAT_CLEAR = 1.5
function Shapes.clearAt(x: number, y: number, z: number, margin: number): boolean
	local spawn = Layout.SPAWN
	if (x - spawn.X) ^ 2 + (z - spawn.Z) ^ 2 < Shapes.SPAWN_CLEAR ^ 2 then return false end
	local lo, hi, k = Layout.RETREAT_MIN, Layout.RETREAT_MAX, Shapes.RETREAT_CLEAR
	if x > lo.X - k and x < hi.X + k and z > lo.Z - k and z < hi.Z + k then return false end
	for _, p in Layout.PIECES do
		if p.lo.Y < y + 0.5 and p.hi.Y > y + 0.05 and x > p.lo.X - margin and x < p.hi.X + margin and z > p.lo.Z - margin and z < p.hi.Z + margin then
			return false
		end
	end
	return true
end

-- A small deterministic random stream (Park-Miller): the same seed always scatters the same way, in Roblox and under the tests.
function Shapes.rng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then state += 2147483646 end
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

-- Uniform random number in [a, b] from a stream.
function Shapes.between(rand: () -> number, a: number, b: number): number
	return a + (b - a) * rand()
end

-- Marks a part (or folder) as optional detail: Client/WorldDetail drops it on phones and tablets.
function Shapes.fullOnly(item: Instance)
	item:SetAttribute("FullOnly", true)
end

-- A folder under `parent`; `optional` marks all of it as full-tier detail.
function Shapes.folder(parent: Instance, name: string, optional: boolean?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if optional then f:SetAttribute("FullOnly", true) end
	f.Parent = parent
	return f
end

-- The frame at `at` whose X axis is `along` and whose Y axis is as close to `up` as it can be (the second axis of a leaf, a petal).
function Shapes.frame(at: Vector3, along: Vector3, up: Vector3): CFrame
	local x = along.Unit
	local y = up - x * up:Dot(x)
	if y.Magnitude < 1e-6 then y = if math.abs(x.Y) < 0.9 then Vector3.yAxis - x * x.Y else Vector3.xAxis - x * x.X end
	return CFrame.fromMatrix(at, x, y.Unit)
end

return Shapes
