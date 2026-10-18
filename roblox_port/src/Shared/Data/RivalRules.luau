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

-- ROBLOX-69: the rival roams the whole sill with its own motor. How often it decides (the motor itself steps every tick), how far and how it moves.
RivalRules.thinkSeconds = 0.1
RivalRules.sightWu = 8.0 -- it perceives the player up to here with a clear line (as before)
RivalRules.patrolSpeed = 0.8 -- WU per second (it was 0.45 on its small territory)
RivalRules.stalkSpeed = 1.1
RivalRules.reachWu = 2.5 -- the windup begins this close, on the same face or one that meets it
RivalRules.rememberSeconds = 3.0 -- it keeps stalking where it last saw the spider this long after losing sight of it
RivalRules.legSeconds = 240.0 -- a patrol leg that has not arrived by now is dropped for the next
RivalRules.stuckSeconds = 4.0 -- no progress for this long: the route is made again
-- Nothing the rival does goes in here: the retreat grown by half a stud (the crack itself is also a hard check).
RivalRules.keepOutMin = Vector3.new(-30.0, -0.5, 2.5)
RivalRules.keepOutMax = Vector3.new(-22.8, 2.0, 9.5)
-- The sill the rival may walk (the frames' outer faces and the underside of the floor are outside it).
RivalRules.sillMin = Vector3.new(-31.05, -0.05, -13.55)
RivalRules.sillMax = Vector3.new(31.05, 40.0, 12.55)

return RivalRules
