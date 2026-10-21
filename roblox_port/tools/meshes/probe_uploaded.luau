-- Run in the signed-in owner's Studio Command Bar (edit mode).
-- Loads an unparented copy; creates no Workspace content and publishes nothing.
local expected = {
	bark_chip = { id = "90087253428470", size = Vector3.new(4.599804, 0.684588, 9) },
	bench_slat_end = { id = "109006316168913", size = Vector3.new(14, 3.2, 10) },
	coneflower_head = { id = "136400030278193", size = Vector3.new(10.344988, 3.975, 10.288317) },
	grass_clump = { id = "93421946013090", size = Vector3.new(9.739530, 26.041445, 11.812691) },
	milkweed_leaf = { id = "128470594939908", size = Vector3.new(7, 2.125, 19.5) },
	stone = { id = "93673725524671", size = Vector3.new(5.345497, 1.815153, 3.794619) },
}
local model = game:GetService("InsertService"):LoadAsset(105970842890511)
assert(model.Parent == nil, "library model must remain unparented")
local probes, count = {}, 0
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		local spec = expected[part.Name]
		assert(spec, "unexpected mesh " .. part.Name)
		assert(part.MeshId == "rbxassetid://" .. spec.id, "wrong mesh ID for " .. part.Name)
		assert((part.MeshSize - spec.size).Magnitude < 0.00002, "wrong native scale for " .. part.Name)
		assert(part.TextureID == "rbxassetid://116765351721069", "wrong atlas for " .. part.Name)
		local holder, mesh = Instance.new("Part"), Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId, mesh.TextureId = part.MeshId, part.TextureID
		mesh.Parent = holder
		table.insert(probes, mesh)
		count += 1
		print("[MESH_LIBRARY]", part.Name, part.MeshId, part.MeshSize)
	end
end
assert(count == 6, "expected six library meshes")
local failed = 0
game:GetService("ContentProvider"):PreloadAsync(probes, function(id, status)
	print("[MESH_LIBRARY_FETCH]", id, status.Name)
	if status ~= Enum.AssetFetchStatus.Success then failed += 1 end
end)
assert(failed == 0, "a library asset could not load")
print("[MESH_LIBRARY_END]", count, "meshes verified; no Workspace content added")
