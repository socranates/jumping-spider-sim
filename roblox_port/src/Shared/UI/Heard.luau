--!strict
-- What the player can hear or see of something that is not at the spider (ROBLOX-92): a creature on the sill is told of (a notice, a caption, a status line) only to a spider
-- that could perceive it, within earshot, or in clear sight of it and not too far. The rule is the one the wasp's taking of the rival has always used (Data/Wasp.rival,
-- ROBLOX-70); the mate's arrival, notice and leaving (ROBLOX-80) use it too. Pure: checked in tests/wasp.luau and tests/client_mating.luau.
local Data = require(script.Parent.Parent.Data.Wasp)

local Heard = {}

-- `distance` is the studs between the spider and the thing; `seen` whether the spider has a clear line of sight to it.
function Heard.within(distance: number, seen: boolean): boolean
	return distance <= Data.rival.earshotWu or (seen and distance <= Data.rival.sightWu)
end

-- The farthest distance at which anything can be perceived (the sight limit): beyond it a sight test is not needed.
function Heard.farthest(): number
	return math.max(Data.rival.earshotWu, Data.rival.sightWu)
end

return Heard
