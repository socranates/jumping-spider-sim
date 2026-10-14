--!strict
-- The low-detail tier of the world, applied on one client: phones and tablets drop what the server built for the full tier
-- (anything carrying the attribute FullOnly: bloom, sun rays, clouds, light shafts, the small details, the busier part of the
-- view) and get a thinner dust. Only this client's copy changes; the server and other players keep theirs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Graphics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Graphics"))

local WorldDetail = {}

-- detail: "full" or "low". roots: the places the server put optional things in (Decor, Lighting, Terrain). Returns how many
-- instances it removed.
function WorldDetail.apply(detail: string, roots: { Instance }): number
	if detail ~= "low" then return 0 end
	local scale = Graphics.tiers.low.dustRate
	local doomed: { Instance } = {}
	for _, root in roots do
		if root:GetAttribute("FullOnly") == true then
			table.insert(doomed, root)
		else
			for _, d in root:GetDescendants() do
				if d:GetAttribute("FullOnly") == true then
					table.insert(doomed, d)
				elseif d:IsA("ParticleEmitter") and d:GetAttribute("Dust") == true and d:GetAttribute("Thinned") ~= true then
					d.Rate = d.Rate * scale
					d:SetAttribute("Thinned", true)
				end
			end
		end
	end
	for _, d in doomed do d:Destroy() end
	return #doomed
end

return WorldDetail
