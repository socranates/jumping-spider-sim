--!strict
-- The peacock spider on real Roblox parts (ROBLOX-29 to 31): the drawn male builds inside its budget, the folded fan opens with the
-- dance pose, legs III go up, every part is display only, and the dance is only a pose (nothing here touches a collider or a sense).
return function(check: (string, () -> ()) -> ())
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Rig = require(Shared.Rig.SpiderRig)
	local Dance = require(Shared.Rig.PeacockDance)
	local folder = Instance.new("Folder")
	folder.Name = "PeacockTestWorld"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(20, 1, 20)
	floor.Position = Vector3.new(200, -0.5, 0)
	floor.Parent = folder
	local body = CFrame.new(200, 0.31, 0)
	local function parts(rig: any, name: string): { BasePart }
		local out = {}
		for _, p in rig.model:GetChildren() do
			if p:IsA("BasePart") and p.Name == name then table.insert(out, p) end
		end
		return out
	end
	check("the peacock spider builds in the engine inside its part budget, display only", function()
		for _, detail in { "full", "low" } do
			local rig = Rig.new(folder, folder, "maratus_volans_male", detail)
			local count = 0
			for _, part in rig.model:GetChildren() do
				if part:IsA("BasePart") then
					count += 1
					assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch, `{part.Name} is not display only`)
				end
			end
			assert(count <= (if detail == "full" then 130 else 80), `{detail}: {count} parts`)
			assert(rig.model:GetAttribute("AppearanceId") == "maratus_volans_male")
			rig:destroy()
		end
	end)
	check("the dance pose opens the fan and raises legs III; no pose folds it", function()
		local rig = Rig.new(folder, folder, "maratus_volans_male", "full")
		for _ = 1, 30 do rig:update(body, 1 / 60, true, false) end
		local field = parts(rig, "FanField")[1]
		local folded = field.Size.X
		rig.dance = Dance.rawPose(5.2, false)
		for _ = 1, 5 do rig:update(body, 1 / 60, true, false) end
		assert(field.Size.X > folded * 1.6, "the fan did not open")
		assert(field.CFrame.UpVector.Z < -0.9, "the raised fan does not face forward")
		assert(parts(rig, "Tarsus3")[1].Position.Y > 0.2, "legs III did not go up")
		assert((rig.root.Position - body.Position).Magnitude < 1e-6, "the root moved")
		rig.dance = nil
		for _ = 1, 5 do rig:update(body, 1 / 60, true, false) end
		assert(field.Size.X < folded * 1.05, "the fan did not fold")
		rig:destroy()
	end)
	check("a small body stands low and all eight feet find the floor", function()
		local rig = Rig.new(folder, folder, "maratus_volans_male", "full")
		for _ = 1, 60 do rig:update(body, 1 / 60, true, false) end
		for _, leg in rig._legs do
			assert(leg.planted ~= nil and math.abs(leg.planted.Y) < 0.01, "a foot is not on the floor")
		end
		assert(parts(rig, "Abdomen")[1].Position.Y < 0.2, "the body is not low")
		rig:destroy()
	end)
	folder:Destroy()
end
