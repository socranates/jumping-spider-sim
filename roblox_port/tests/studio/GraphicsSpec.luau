--!strict
-- Real Roblox values: what the place holds once Main.server has built the world. Included only in tests.project.json and run
-- by Runner.server.luau in Studio (it needs the engine); the CLI cannot run it. It checks what an engine can check: that the
-- settings took, that materials and the sun are what the table asks for, that nothing drawn is solid or queryable. Whether it
-- LOOKS right (materials, haze, light shafts, the view out of the window) is for eyes in Studio: HANDOFF "Cuter spider and graphics".
return function(check)
	local Lighting = game:GetService("Lighting")
	local MaterialService = game:GetService("MaterialService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Graphics = require(Shared.Data.Graphics)
	local Materials = require(Shared.Habitat.Materials)
	local Flora = require(Shared.Data.Flora)
	local Plants = require(Shared.Habitat.Plants)
	local sill = (workspace:WaitForChild("World", 15) :: Folder):WaitForChild("Windowsill", 15) :: Folder -- (ROBLOX-94: the sill is region 0, inside the World folder)
	local decor = workspace:WaitForChild("Decor", 15) :: Model -- (a persistent model since ROBLOX-94)

	-- Protected Technology/Use2022Materials are checked by tools/build.py.
	check("every material name in the graphics table is a real Roblox material", function()
		for _, name in Materials.names() do
			assert(Enum.Material:FromName(name) ~= nil, "no Enum.Material." .. name)
		end
	end)
	check("sill pieces use the table's materials and the back wall is invisible but solid", function()
		for _, part in sill:GetChildren() do
			local want = Graphics.materials.pieces[part.Name]
			assert(want, "no material for " .. part.Name)
			assert((part :: BasePart).Material == Enum.Material:FromName(want), `{part.Name}: {tostring((part :: BasePart).Material)}`)
		end
		for _, id in Graphics.window.hidden do
			local back = sill:FindFirstChild(id) :: BasePart
			assert(back.Transparency == 1 and back.CanCollide and back.CanQuery, id .. ": the back wall must stay solid and climbable")
		end
		local hit = workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, 0, -30))
		assert(hit and hit.Instance == sill:FindFirstChild("back_frame_head") and math.abs(hit.Position.Z + 12.5) < 1e-3, "a ray across the sill must land on the solid back wall")
		-- ROBLOX-95: the raised sash: a ray low across the middle of the sill goes out through the opening and meets the outer sill's world, not the back wall
		local low = workspace:Raycast(Vector3.new(0, 3, 0), Vector3.new(0, 0, -30))
		assert(low == nil or not low.Instance:IsDescendantOf(sill), "the opening in the back frame must be open")
	end)
	check("a piece is invisible only where its drawing exists, and then it stays solid; every drawn leaf's top is its piece's top", function()
		local pilea = decor:FindFirstChild("Pilea")
		assert(pilea, "the drawn Pilea is missing")
		local hidden: { [string]: boolean } = {}
		for _, id in Graphics.window.hidden do hidden[id] = true end
		for _, id in Plants.pieceIds() do hidden[id] = true end
		for _, part in sill:GetChildren() do
			local p = part :: BasePart
			if hidden[p.Name] then
				assert(p.Transparency == 1 and not p.CastShadow and p.CanCollide and p.CanQuery, p.Name .. " must be invisible but solid")
			else
				assert(p.Transparency == 0, p.Name .. " must stay visible")
			end
		end
		for _, plant in Flora.pilea.plants do
			local leaf = sill:FindFirstChild(plant.leaf) :: BasePart
			local blade = (pilea:FindFirstChild(plant.leaf) :: Folder):FindFirstChild("BladeA") :: BasePart
			assert(math.abs((blade.Position.Y + blade.Size.Y / 2) - (leaf.Position.Y + leaf.Size.Y / 2)) < 1e-3, plant.leaf .. ": the drawn top is not the walkable top")
		end
	end)
	check("decor is drawn only: no collisions, no rays, no touches", function()
		local n = 0
		for _, d in decor:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				assert(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch, d:GetFullName())
			end
		end
		assert(n >= 400 and n < 1500, `decor has {n} parts`)
	end)
	check("the flowers' UV layer is invisible Neon until the eye view fades it in", function()
		local uv = decor:FindFirstChild("UVLayer")
		assert(uv and #uv:GetChildren() >= 100, "no UV layer")
		for _, d in uv:GetChildren() do
			local p = d :: BasePart
			assert(p.Transparency == 1 and p.Material == Enum.Material.Neon and p:GetAttribute("UVOpacity") == 0.85 and p.Color == Color3.fromHex("b98cff"), p.Name)
		end
	end)
	check("the sun shines in through the window", function()
		local sun = Lighting:GetSunDirection()
		local status = tostring(Lighting:GetAttribute("SunPick"))
		assert(string.sub(status, 1, 3) == "ok:", "SunPick: " .. status)
		assert(sun.Z < -0.2 and sun.Y > 0.25, "sun direction " .. tostring(sun))
		assert(Graphics.window.hidden[1] == "back_frame_west" and decor:FindFirstChild("Shafts") ~= nil, "no light shafts built")
	end)
	check("the wall casts shadows, the glass does not", function()
		local wall = decor:FindFirstChild("Wall") :: Folder
		assert((wall:FindFirstChild("ApronWest") :: BasePart).CastShadow and (wall:FindFirstChild("Mullion1") :: BasePart).CastShadow)
		local glass = wall:FindFirstChild("Glass") :: BasePart
		assert(not glass.CastShadow and glass.Transparency >= 0.6 and glass.Material == Enum.Material.SmoothPlastic, "window must not refract away translucent UV petals")
		assert(not (sill:FindFirstChild(Graphics.window.hidden[1]) :: BasePart).CastShadow, "the invisible wall must not shade the room")
	end)
	check("atmosphere, sky, grade, bloom, sun rays and clouds are in place; the macro depth of field is on unless switched off", function()
		for _, name in { "Atmosphere", "Sky", "Grade", "Bloom", "SunRays" } do assert(Lighting:FindFirstChild(name), "missing " .. name) end
		assert(workspace.Terrain:FindFirstChildOfClass("Clouds"), "missing clouds")
		local dof = Lighting:FindFirstChild("MacroDOF") :: DepthOfFieldEffect?
		assert((dof ~= nil) == (workspace:GetAttribute("DepthOfField") ~= false), "depth of field must be on unless the DepthOfField attribute is false")
		if dof then
			-- Roblox stores effect intensities as float32 (0.3 reads back as 0.3000000119).
			assert(math.abs(dof.FarIntensity - Graphics.depthOfField.far) < 1e-6 and dof.NearIntensity == 0 and math.abs(dof.InFocusRadius - Graphics.depthOfField.radius) < 1e-6, "depth of field blurs only the far")
			assert(dof:GetAttribute("FullOnly") == true, "depth of field is a full-tier effect")
		end
		local bloom = Lighting:FindFirstChild("Bloom") :: BloomEffect
		assert(bloom.Threshold >= 1.2 and bloom.Intensity <= 0.5, "bloom is not gentle")
	end)
	check("dust motes are emitting and the light shafts are faint", function()
		local motes = (decor:FindFirstChild("DustVolume") :: Instance):FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
		assert(motes.Enabled and motes.Rate > 0)
		local beams = 0
		for _, d in decor:GetDescendants() do
			if d:IsA("Beam") then
				beams += 1
				assert(d.Transparency.Keypoints[1].Value >= 0.95, "a shaft is too strong")
			end
		end
		assert(beams == #Graphics.shafts.x * #Graphics.shafts.layers, `{beams} beams`)
	end)
end
