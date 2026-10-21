--!strict
-- The water in words (ROBLOX-122; the water is Life/Water): the caption while the spider struggles at the surface, its death card, and the notices when it gets out
-- or is pulled out (the gentle rules). Pure: tests/preserve.luau checks the words, tests/quiet.luau their classes.
local WaterText = {}

WaterText.STRUGGLE = "[splashing at the surface]"
WaterText.LINE = "The water held on."
WaterText.SUB = "A jumping spider cannot walk on water. Nothing it could reach stood out of the pond, and the struggle wore it out."
WaterText.OUT = "You scrambled out of the water."
WaterText.PULLED = "The ripples carried you to something to climb. You hauled yourself out."
WaterText.CAUSE = "drowned" -- (the end of a life's cause, LifeSession; Life/Water.CAUSE)

return table.freeze(WaterText)
