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
	local sill = workspace:WaitForChild("Windowsill", 15) :: Folder
	local decor = workspace:WaitForChild("Decor", 15) :: Folder

	check("lighting is Future and the 2022 materials are on", function()
		assert(Lighting.Technology == Enum.Technology.Future, "Technology " .. tostring(Lighting.Technology))
		assert(MaterialService.Use2022Materials == true, "Use2022Materials is off")
	end)
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
		local back = sill:FindFirstChild(Graphics.window.hidden) :: BasePart
		assert(back.Transparency == 1 and back.CanCollide and back.CanQuery, "the back wall must stay solid and climbable")
		local hit = workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, 0, -30))
		assert(hit and hit.Instance == back and math.abs(hit.Position.Z + 12.5) < 1e-3, "a ray across the sill must land on the solid back wall")
	end)
	check("decor is drawn only: no collisions, no rays, no touches", function()
		local n = 0
		for _, d in decor:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				assert(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch, d:GetFullName())
			end
		end
		assert(n >= 70 and n <= 140, `decor has {n} parts`)
	end)
	check("the sun shines in through the window", function()
		local sun = Lighting:GetSunDirection()
		local status = tostring(Lighting:GetAttribute("SunPick"))
		assert(string.sub(status, 1, 3) == "ok:", "SunPick: " .. status)
		assert(sun.Z < -0.2 and sun.Y > 0.25, "sun direction " .. tostring(sun))
		assert(Graphics.window.hidden == "back_frame" and decor:FindFirstChild("Shafts") ~= nil, "no light shafts built")
	end)
	check("the wall casts shadows, the glass does not", function()
		local wall = decor:FindFirstChild("Wall") :: Folder
		assert((wall:FindFirstChild("Apron") :: BasePart).CastShadow and (wall:FindFirstChild("Mullion1") :: BasePart).CastShadow)
		local glass = wall:FindFirstChild("Glass") :: BasePart
		assert(not glass.CastShadow and glass.Transparency >= 0.6 and glass.Material == Enum.Material.Glass)
		assert(not (sill:FindFirstChild(Graphics.window.hidden) :: BasePart).CastShadow, "the invisible wall must not shade the room")
	end)
	check("atmosphere, sky, grade, bloom, sun rays and clouds are in place; no depth of field unless asked", function()
		for _, name in { "Atmosphere", "Sky", "Grade", "Bloom", "SunRays" } do assert(Lighting:FindFirstChild(name), "missing " .. name) end
		assert(workspace.Terrain:FindFirstChildOfClass("Clouds"), "missing clouds")
		assert((Lighting:FindFirstChild("MacroDOF") ~= nil) == (workspace:GetAttribute("DepthOfField") == true), "depth of field must be opt-in")
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
