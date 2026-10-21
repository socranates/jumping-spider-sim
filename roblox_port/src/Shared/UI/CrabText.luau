--!strict
-- The crab spider in words (ROBLOX-119; the crab spider is Predator/CrabSpider): its death card and the notice when its lunge only knocks the spider off the flower (the
-- gentle rules). Pure: tests/preserve.luau checks the words, tests/quiet.luau their classes.
local CrabText = {}

CrabText.LINE = "The crab spider's legs closed."
CrabText.SUB = "It sat still on the flower in the flower's colour, its front legs held open. A careful look before landing would have shown it."
CrabText.NUDGED = "A crab spider lunged from the flower. You dropped clear."
CrabText.CAUSE = "crab_spider" -- (the end of a life's cause, LifeSession; Predator/CrabSpider.CAUSE)

return table.freeze(CrabText)
