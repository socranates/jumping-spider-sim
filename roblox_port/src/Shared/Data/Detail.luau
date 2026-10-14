--!strict
-- Which detail tier a device runs: "full" for computers and consoles, "low" for touch-only phones and tablets. The tier
-- decides the spider's fuzz and idle motion (Data/Appearances.detail) and which optional parts of the world stay
-- (Data/Graphics, Client/WorldDetail). A Workspace attribute `Detail` = "low" or "full" overrides the device guess, so a
-- low-powered laptop or a fast tablet can be tried either way without a code change.
local Detail = {}

export type Tier = "full" | "low"

function Detail.choose(touchOnly: boolean, override: unknown): Tier
	if override == "low" then return "low" end
	if override == "full" then return "full" end
	return if touchOnly then "low" else "full"
end

return Detail
