--!strict
-- When the brown rival spider arrives (ROBLOX-67). Game tuning, not measurements. Predator/RivalSpider reads these; nothing else decides it.
-- One rival at a time on the eastern sill: it arrives, and when it is eaten a new one arrives on a later morning.
local RivalRules = {}

-- The protections of a brand-new life, as the wasp has them: no rival on the first day, and none before the first meal is finished.
RivalRules.firstDay = 2
RivalRules.firstMeals = 1
-- A rival (the first, or the one after an eaten rival) arrives from this hour of the life clock: the morning, when the spider wakes (LifeClock.WAKE_H).
RivalRules.arriveHour = 7.0
-- It does not arrive on top of the spider: it waits while the spider is closer than this to the east end of the sill (WU).
RivalRules.arriveDistance = 8.0
-- Where it arrives, at the east end of the sill (WU).
RivalRules.arriveAt = Vector3.new(25, 0.31, 8)

return RivalRules
