--!strict
-- Temporary D-038 stage, away from spawn, crevice and recovery routes. Physical screen/ledge belong to WORLD.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Target = require(Shared.Habitat.TestTarget)
local Stage = {}
function Stage.new(sill: Instance): any
	local folder = Instance.new("Folder")
	folder.Name = "PerceptionStage"
	folder.Parent = sill
	local function part(name: string, at: Vector3, size: Vector3, solid: boolean): Part
		local p = Instance.new("Part")
		p.Name, p.Position, p.Size = name, at, size
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, solid, solid, false
		p.Color = Color3.fromRGB(116, 100, 91)
		if solid then p:SetAttribute("ProfileId", "bare_wood_rough"); p:SetAttribute("SurfaceId", name) end
		p.Parent = folder
		return p
	end
	part("watch_ledge", Vector3.new(-25,1,-3.5), Vector3.new(4,2,3), true)
	part("stage_screen", Vector3.new(-25,1.5,-7), Vector3.new(2,3,0.2), true)
	local marker = part("TestMarker", Vector3.new(-29,2.8,-10), Vector3.one*0.9, false)
	marker.Shape = Enum.PartType.Ball
	marker.Color = Color3.fromRGB(220,31,158)
	local sign = Instance.new("BillboardGui")
	sign.Name, sign.Size, sign.StudsOffset = "TargetSign", UDim2.fromOffset(220,55), Vector3.new(0,1,0)
	sign.AlwaysOnTop = false
	sign.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1,1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1,1,1)
	label.TextStrokeTransparency = 0
	label.TextSize = 15
	label.Text = "TEST TARGET\nmoving marker, not a fly"
	label.Parent = sign
	local target = Target.new({Vector3.new(-29,2.8,-10), Vector3.new(-21,2.8,-10)})
	return {target=target, marker=marker, folder=folder}
end
return Stage
