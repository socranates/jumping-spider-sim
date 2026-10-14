--!strict
-- Real Roblox values, raycasts and BulkMoveTo. No headless shim here.
return function(check)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local JumpMath = require(Shared.Movement.JumpMath)
	local Rig = require(Shared.Rig.SpiderRig)
	local Appearance = require(Shared.Data.Appearances)
	local folder = Instance.new("Folder")
	folder.Name = "PortTestWorld"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(20, 1, 20)
	floor.Position = Vector3.new(100, -0.5, 0)
	floor.Parent = folder
	local rig = Rig.new(folder, folder)
	local function run()
		check("real engine jump reaches seat", function()
			local from, seat = Vector3.new(100, 0.31, 0), Vector3.new(103, 0.31, 0)
			local result = JumpMath.solve(from, seat, Vector3.yAxis, Vector3.yAxis, Vector3.new(0,-35,0), 1/60, 0.1, 1.2, 20)
			assert(#result.valid > 0)
			local solution = result.valid[1]
			local path = JumpMath.path(from, solution.velocity, Vector3.new(0,-35,0), 1/60, solution.steps)
			assert((path[#path] - seat).Magnitude < 0.001)
		end)
		check("raycast planted foot stays in world space", function()
			rig:update(CFrame.new(100, 0.31, 0), 1/60, true, false)
			local foot = rig._legs[1].foot
			assert(rig._legs[1].planted ~= nil, "must hit real floor")
			rig:update(CFrame.new(100.02, 0.31, 0), 1/60, true, true)
			assert((rig._legs[1].foot - foot).Magnitude < 0.001)
		end)
		check("appearance stays white when stage changes", function()
			local before = rig._spots[1].Color
			rig:setGrowthStage(3)
			local c = Appearance.profiles[Appearance.default].white
			for _, spot in rig._spots do
				assert(spot.Color == before, "stage recolored the markings")
				assert(math.abs(spot.Color.R-c[1]) < 1/255 and math.abs(spot.Color.G-c[2]) < 1/255 and math.abs(spot.Color.B-c[3]) < 1/255)
			end
			assert(rig.model:GetAttribute("AppearanceId") == "first_spider")
		end)
		check("all rig parts are display only and bounded", function()
			local count, fuzz = 0, 0
			for _, part in rig.model:GetChildren() do
				if part:IsA("BasePart") then
					if part.Name == "Seta" or part.Name == "FuzzShell" then fuzz += 1 else count += 1 end
					assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch)
					assert(part.Position.X == part.Position.X)
				end
			end
			assert(count <= 160, `part budget exceeded: {count}`)
			assert(fuzz >= 300 and fuzz <= 720, `fuzz budget: {fuzz}`)
		end)
		check("spider-eye view hides the body and keeps the front legs", function()
			rig:setEyeView(true)
			local eye = rig.model:FindFirstChild("PrincipalEye") :: BasePart
			assert(eye.LocalTransparencyModifier == 1, "head still drawn in the eye view")
			assert(rig._legs[1].tibia.LocalTransparencyModifier == 0, "front leg hidden")
			assert(rig._legs[2].femur.LocalTransparencyModifier == 1, "back leg drawn")
			rig:setEyeView(false)
			assert(eye.LocalTransparencyModifier == 0 and rig._legs[2].femur.LocalTransparencyModifier == 0)
		end)
		check("low detail keeps about a third of the fuzz", function()
			local low = Rig.new(folder, folder, nil, "low")
			local n = 0
			for _, part in low.model:GetChildren() do if part.Name == "Seta" then n += 1 end end
			low:destroy()
			assert(n >= 100 and n <= 260, `low fuzz: {n}`)
		end)
		check("air and underside poses are finite", function()
			for _, up in {Vector3.yAxis, Vector3.xAxis, -Vector3.yAxis} do
				local body = CFrame.lookAt(Vector3.new(100,2,0), Vector3.new(100,2,-1), up)
				rig:update(body,1/60,false,false)
				for _, foot in rig._legs do assert(foot.foot.Magnitude < 110) end
			end
		end)
	end
	local ok, err = pcall(run)
	rig:destroy()
	folder:Destroy()
	if not ok then error(err) end
end
