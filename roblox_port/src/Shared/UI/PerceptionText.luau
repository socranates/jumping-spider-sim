--!strict
-- Frozen perception_text.gd: words belong to presentation, never the sensor.
local Text = {}
local names = {movement="movement", possible_prey="possible prey", fly_like_prey="fly-like prey"}
function Text.category(category: string): string
	return (names :: {[string]: string})[category] or "movement"
end
function Text.hasNumber(text: string): boolean return string.find(text, "[%d%%]") ~= nil end
Text.LOST = "lost sight"
return table.freeze(Text)
