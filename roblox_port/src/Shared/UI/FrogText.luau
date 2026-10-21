--!strict
-- The green frog in words (ROBLOX-122; the frog is Predator/Frog): its death card and the notice when its tongue misses (the gentle rules). Pure: tests/preserve.luau
-- checks the words, tests/quiet.luau their classes.
local FrogText = {}

FrogText.LINE = "The frog's tongue was quicker."
FrogText.SUB = "It sat still at the water's edge and struck at what moved within its reach. Keeping still, or keeping clear of it, the spider would have lived."
FrogText.MISSED = "A frog's tongue slapped down beside you. You jumped clear."
FrogText.CAUSE = "frog" -- (the end of a life's cause, LifeSession; Predator/Frog.CAUSE)

return table.freeze(FrogText)
