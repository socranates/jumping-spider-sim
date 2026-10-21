--!strict
-- The preserve's first meshes (ROBLOX-126; docs/MESHES.md, assets/meshes/manifest.json): original Blender studies by Chet, uploaded by socranates and verified
-- in Studio at their authored size (1 stud = 1 cm). A drawn record whose shape is "Mesh:<name>" is drawn with one of these (Habitat/Scenery.look): a
-- SpecialMesh FileMesh on a drawn-only part, scaled to the record's size, its long horizontal axis turned onto the record's. Visual only: nothing walks on
-- them, the walkable boxes under them are as they were.
local Meshes = {}

export type Mesh = { id: string, size: Vector3, triangles: number }

Meshes.TEXTURE = "rbxassetid://116765351721069" -- the shared colour atlas

Meshes.list = {
	grass_clump = { id = "rbxassetid://93421946013090", size = Vector3.new(9.739530, 26.041445, 11.812691), triangles = 1400 },
	milkweed_leaf = { id = "rbxassetid://128470594939908", size = Vector3.new(7, 2.125, 19.5), triangles = 1466 },
	coneflower_head = { id = "rbxassetid://136400030278193", size = Vector3.new(10.344988, 3.975, 10.288317), triangles = 4948 },
	bark_chip = { id = "rbxassetid://90087253428470", size = Vector3.new(4.599804, 0.684588, 9), triangles = 1496 },
	stone = { id = "rbxassetid://93673725524671", size = Vector3.new(5.345497, 1.815153, 3.794619), triangles = 320 },
	bench_slat_end = { id = "rbxassetid://109006316168913", size = Vector3.new(14, 3.2, 10), triangles = 188 },
} :: { [string]: Mesh }

-- The mesh a record's shape names, or nil ("Mesh:milkweed_leaf" -> the leaf).
function Meshes.of(shape: string?): Mesh?
	if shape == nil or string.sub(shape, 1, 5) ~= "Mesh:" then return nil end
	return Meshes.list[string.sub(shape, 6)]
end

-- How a mesh fits a record's box: whether to turn it a quarter (its long horizontal axis onto the box's) and the SpecialMesh's Scale (box / native, axis by axis,
-- after the turn). The part keeps the record's size and place; only the mesh is scaled.
function Meshes.fit(mesh: Mesh, size: Vector3): (boolean, Vector3)
	local n = mesh.size
	local turn = (n.Z > n.X) ~= (size.Z > size.X) and math.abs(n.Z - n.X) > 1e-6 and math.abs(size.Z - size.X) > 1e-6
	local sx, sz = if turn then size.Z else size.X, if turn then size.X else size.Z
	return turn, Vector3.new(sx / n.X, size.Y / n.Y, sz / n.Z)
end

return Meshes
