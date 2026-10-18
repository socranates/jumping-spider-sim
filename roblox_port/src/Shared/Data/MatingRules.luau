--!strict
-- The mating cycle's numbers (ROBLOX-79). Game tuning, not measurements: Predator/Mate and Life/Mating read these and nothing else decides them.
-- The cycle: a full-grown, well-fed spider rests; the next morning a mate comes onto the sill; courting it fills a meter; they mate and the male leaves;
-- the next night's sleep in the crack makes the egg sac; two days of guarding; the eggs hatch and the player carries on as one of the spiderlings.
local MatingRules = {}

-- Eligibility, tested at a rest in the crack: the spider is full-grown (Growth's last stage) and has at least this much energy (the hunger bar at 60%).
MatingRules.energyMin = 0.6
-- The mate arrives by the rival's rules (Data/RivalRules, ROBLOX-68): not on the first day, from the morning (the spider's waking hour), not while the
-- spider rests or the wasp visits, not while the spider is within arriveDistance of where it would arrive. It is also not brought in the afternoon: from
-- arriveUntil a visit that has not begun is not begun (it comes tomorrow). The mate goes at leaveHour, the evening (LifeClock.EVENING_H).
MatingRules.firstDay = 2
MatingRules.arriveHour = 7.0
MatingRules.arriveUntil = 16.0
MatingRules.leaveHour = 18.0
MatingRules.arriveDistance = 8.0
MatingRules.arriveAt = Vector3.new(26.0, 0.31, 3.0) -- the east end of the floor, away from the crack at the west end
-- One mate at a time, for at most this many days (mornings it comes); then a new mate, the next morning.
MatingRules.visitsMax = 3

-- Courtship. The player is near the mate (within nearWu), standing still, facing it (the mate within faceDeg of where the player looks) and, for the
-- peacock spider, dancing. The meter then fills over courtSeconds; moving, leaving, turning away or being airborne drains it at decayPerSecond (twice
-- as fast as it fills). While the dance is the only thing missing the meter holds. Jumping at the mate (airborne within jumpAtWu) or striking it
-- (the strike's sweep within strikeWu) drives it off for the day.
MatingRules.courtSeconds = 8.0
MatingRules.decayPerSecond = 0.25
MatingRules.nearWu = 3.0
MatingRules.attendWu = 2.0 -- an interested mate walks up to the spider and stops this far from it
MatingRules.loseWu = 6.0 -- the spider is gone from its attention beyond this (or out of sight for loseSeconds)
MatingRules.loseSeconds = 3.0
MatingRules.faceDeg = 40.0
MatingRules.strikeWu = 0.65
MatingRules.jumpAtWu = 2.0
-- The pause together, in which the one caption of the mating is shown; then the mate walks off the sill and is not seen again.
MatingRules.pairSeconds = 5.0
-- A mate that leaves (driven off, at dusk, after mating) walks to the edge of the sill, the back corner of the east end of the floor (the waypoint
-- there); it is gone within exitRadius of it, or after leaveSeconds, whichever is first.
MatingRules.leaveSeconds = 120.0
MatingRules.exitAt = Vector3.new(26.4, 0.31, -10.84)
MatingRules.exitRadius = 1.5

-- The mate is drawn with the played spider's look, scaled: a male mate slimmer and smaller, a female mate larger; each mate varies by up to +-scaleSpread
-- about it (a seeded draw from the mate's number).
MatingRules.scale = { male = 0.9, female = 1.15 } :: { [string]: number }
MatingRules.scaleSpread = 0.05

-- After mating: the egg sac is made by the next sleep that reaches the morning. It is guarded for guardDays full days (surviving is guarding; nothing can
-- harm the sac), and the eggs hatch on the morning after the last. The brood is a seeded handful for the hatching scene.
MatingRules.guardDays = 2
MatingRules.broodMin = 8
MatingRules.broodMax = 12
-- Where the sac hangs in the retreat, and its size (the crack's interior is x -27.8 to -23.3, z 3 to 9).
MatingRules.sacAt = Vector3.new(-27.1, 0.5, 8.4)
MatingRules.sacRadius = 0.42
-- A new generation starts like a new life: the first growth stage and this much energy (NeedsModel.ENERGY_START); the day count goes on.
MatingRules.freshEnergy = 0.55

return MatingRules
