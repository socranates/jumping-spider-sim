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
RivalRules.reachWu = 3.2 -- the windup begins this close, on the same face or one that meets it (ROBLOX-73: it was 2.5)
RivalRules.rememberSeconds = 5.0 -- it keeps stalking where it last saw the spider this long after losing sight of it (it was 3)
-- How long it must see the spider before it stalks it: the notice (0 to 1, rising one a second while it sees the spider) at which a patrolling
-- rival starts to stalk. It was 0.6 in Godot's rule; the game's rival is quicker to take an interest (ROBLOX-73).
RivalRules.stalkNotice = 0.45
RivalRules.legSeconds = 240.0 -- a patrol leg that has not arrived by now is dropped for the next
RivalRules.stuckSeconds = 4.0 -- no progress for this long: the route is made again
-- ROBLOX-73: striking a rival that has seen the spider coming is a contest, not a sure catch. A rival is aware when it is stalking or winding up,
-- or patrolling with a notice of at least awareNotice; a recovering rival or a patrolling one that has not noticed is still caught outright. The
-- draw is from a stream of its own (RivalSpider.contest, by the world's seed, the day and how many contests this rival has had): the rival is
-- caught (contestCaptured), springs clear of the strike (contestSprang) or, for the rest, bites back and costs counterCost of the spider's energy
-- (about half of a day's; nothing in the gentle modes). ROBLOX-88: harder to take down: 40 caught, 32 sprang clear, 28 bit back (it was 55/25/20), and a
-- bite costs 0.30 (it was 0.25; a day costs about 0.61 at the game's hunger drain).
RivalRules.awareNotice = 0.3
RivalRules.contestCaptured = 0.40
RivalRules.contestSprang = 0.32 -- (and 0.28 is left for the counter-bite)
RivalRules.counterCost = 0.30
-- ROBLOX-91: the gentle modes (Easy, Free play) keep ROBLOX-73's contest, 55 caught / 25 sprang clear / 20 a bite that costs nothing: ROBLOX-88's harder rival is for
-- the standard rules (the draw is the same stream; only the thresholds differ). The gentle grip (Catch.forRival) and the free bite are as they were.
RivalRules.contestGentle = { captured = 0.55, sprang = 0.25 }
-- Nothing the rival does goes in here: the retreat grown by half a stud (the crack itself is also a hard check).
RivalRules.keepOutMin = Vector3.new(-30.0, -0.5, 2.5)
RivalRules.keepOutMax = Vector3.new(-22.8, 2.0, 9.5)
-- The sill the rival may walk (the frames' outer faces and the underside of the floor are outside it).
RivalRules.sillMin = Vector3.new(-31.05, -0.05, -13.55)
RivalRules.sillMax = Vector3.new(31.05, 40.0, 12.55)

return RivalRules
