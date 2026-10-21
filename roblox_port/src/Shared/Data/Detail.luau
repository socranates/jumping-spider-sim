--!strict
-- Which detail tier a device runs: "full" for computers and consoles, "low" for touch-only phones and tablets. The tier
-- decides the spider's fuzz and idle motion (Data/Appearances.detail) and which optional parts of the world stay
-- (Data/Graphics, Client/WorldDetail). A Workspace attribute `Detail` = "low" or "full" overrides the device guess, so a
-- low-powered laptop or a fast tablet can be tried either way without a code change.
local Detail = {}

export type Tier = "full" | "low"

-- ROBLOX-108: `console` (GuiService:IsTenFootInterface(): a PlayStation or an Xbox on a television) is the full tier, whatever else the device reports. A console
-- is no phone: Nathan plays the game on a PlayStation, and the look was judged on that television. A console has no touch screen, so this was already the answer
-- the touch rule gave; it is said here so that a console reporting touch (a controller with a touch pad) is never taken for a phone. The Detail attribute still wins.
function Detail.choose(touchOnly: boolean, override: unknown, console: boolean?): Tier
	if override == "low" then return "low" end
	if override == "full" then return "full" end
	if console == true then return "full" end
	return if touchOnly then "low" else "full"
end

return Detail
