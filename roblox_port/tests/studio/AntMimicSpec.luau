--!strict
-- The ant-mimicking spider on real Roblox parts (ROBLOX-64): the drawn female builds inside its budget, every part is display only,
-- legs I rise as antennae and fall again, the drawn walk wobbles only the picture (the root does not move), and all eight feet
-- find the floor. Cosmetic only: nothing here touches a collider or a sense.
return function(check: (string, () -> ()) -> ())
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Rig = require(Shared.Rig.SpiderRig)
	local AntMimicPose = require(Shared.Rig.AntMimicPose)
	local folder = Instance.new("Folder")
	folder.Name = "AntMimicTestWorld"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(20, 1, 20)
	floor.Position = Vector3.new(300, -0.5, 0)
	floor.Parent = folder
	local body = CFrame.new(300, 0.2, 0)
	local ID = "myrmarachne_formicaria_female"
	local function parts(rig: any, name: string): { BasePart }
		local out = {}
		for _, p in rig.model:GetChildren() do
			if p:IsA("BasePart") and p.Name == name then table.insert(out, p) end
		end
		return out
	end
	local function maxY(list: { BasePart }): number
		local best = -math.huge
		for _, p in list do best = math.max(best, p.Position.Y) end
		return best
	end
	local function settle(rig: any, frames: number)
		for _ = 1, frames do rig:update(body, 1 / 60, true, false) end
	end
	check("the ant-mimicking spider builds in the engine inside its part budget, display only", function()
		for _, detail in { "full", "low" } do
			local rig = Rig.new(folder, folder, ID, detail)
			local count = 0
			for _, part in rig.model:GetChildren() do
				if part:IsA("BasePart") then
					count += 1
					assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch, `{part.Name} is not display only`)
				end
			end
			assert(count <= (if detail == "full" then 100 else 70), `{detail}: {count} parts`)
			assert(rig.model:GetAttribute("AppearanceId") == ID)
			rig:destroy()
		end
	end)
	check("legs I go up as antennae and come down again; the root never moves", function()
		local rig = Rig.new(folder, folder, ID, "full")
		settle(rig, 60)
		local down = maxY(parts(rig, "Tarsus1"))
		local pose = table.clone(AntMimicPose.NONE)
		pose.antennae = 1
		rig.ant = pose
		settle(rig, 10)
		local up = maxY(parts(rig, "Tarsus1"))
		assert(up > down + 0.05, `legs I did not rise ({down} to {up})`)
		assert((rig.root.Position - body.Position).Magnitude < 1e-6, "the root moved")
		assert(maxY(parts(rig, "Tarsus3")) < up, "legs III rose with the antennae")
		rig.ant = nil
		settle(rig, 10)
		assert(maxY(parts(rig, "Tarsus1")) < down + 0.02, "legs I did not come down")
		rig:destroy()
	end)
	check("the drawn walk turns the picture a little and nothing else", function()
		local rig = Rig.new(folder, folder, ID, "full")
		settle(rig, 60)
		local before = parts(rig, "Abdomen")[1].CFrame.LookVector
		local pose = table.clone(AntMimicPose.NONE)
		pose.yaw = math.rad(10)
		pose.lateral = 0.03
		pose.walking = true
		rig.ant = pose
		settle(rig, 5)
		local after = parts(rig, "Abdomen")[1].CFrame.LookVector
		assert(before:Dot(after) < 0.999, "the drawn body did not turn")
		assert((rig.root.Position - body.Position).Magnitude < 1e-6, "the root moved")
		rig:destroy()
	end)
	check("a small body stands low and all eight feet find the floor", function()
		local rig = Rig.new(folder, folder, ID, "full")
		settle(rig, 60)
		for _, leg in rig._legs do
			assert(leg.planted ~= nil and math.abs(leg.planted.Y) < 0.01, "a foot is not on the floor")
		end
		assert(parts(rig, "Abdomen")[1].Position.Y < 0.3, "the body is not low")
		rig:destroy()
	end)
	folder:Destroy()
end
