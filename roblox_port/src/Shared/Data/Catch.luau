--!strict
-- The catch struggle as the game plays it (ROBLOX-72, ROBLOX-77). Game tuning, not measurements; Godot's values (Prey/Feeding's defaults, checked
-- by the goldens) are untouched and a Feeding that is never given these replays them. Prey/Feeding:useGameRules() and :useRivalRules() apply them.
-- The struggle: the grip starts at startGrip, drains 0.32 x drainScale x the prey's strength a second plus a jerk (0.12 x jerkScale x strength)
-- every 0.35 to 0.75 s, each tap adds tapGain, the strength falls from 1 by `tire` over the venom's 6 to 8 s, and the prey is subdued at a grip
-- of 1 or after `cap` seconds (12; the rival has none).
local Species = require(script.Parent.Species)

local Catch = {}

-- Nathan: "make the tapping a bit easier when catching the fly." Godot: startGrip 0.4, tapGain 0.085, jerkScale 1.0.
Catch.game = {
	startGrip = 0.5,
	tapGain = 0.12,
	jerkScale = 0.8, -- a jerk takes 0.096 x strength of the grip, not 0.12
}

-- ROBLOX-77: "the smaller prey should be easier." The struggle scales with the prey's size: the factor is how hard the catch is against the house
-- fly (1.0, ROBLOX-72's numbers exactly). It is read from the caught profile's body.nutrition (the prey's meal, the one mass-like number a
-- profile has) against the house fly's, so any future prey profile gets its struggle for free. A factor below 1 is easier: the drain and the
-- jerks are that much smaller and a tap is worth that much more. The fruit fly (half a meal) is 0.7.
Catch.size = {
	slope = 0.6, -- the factor falls this much for each whole house fly of meal the prey lacks
	min = 0.5, -- (the smallest prey is never a free meal)
	max = 1.6, -- (nor the largest an impossible one)
}

-- How hard catching `profile` is against the house fly: 1.0 for the house fly, 0.7 for the fruit fly.
function Catch.factorFor(profile: any): number
	local base = Species.fly_like_prototype.body.nutrition
	local ratio = profile.body.nutrition / base
	local z = Catch.size
	return math.clamp(1 - z.slope * (1 - ratio), z.min, z.max)
end

-- The struggle's numbers for a catch of difficulty `factor` (a number from factorFor): Catch.game's startGrip, a tap worth tapGain / factor, a
-- drain and jerks of factor times as much.
function Catch.scaled(factor: number): { [string]: number }
	local g = Catch.game
	return {
		startGrip = g.startGrip, tapGain = g.tapGain / factor, jerkScale = g.jerkScale * factor,
		drainScale = factor, tire = 0.5, cap = 12,
	}
end

-- ROBLOX-77: "the rival spider should be harder to eat than normal prey, harder tapping mechanic." A rival that has been caught (ROBLOX-73's
-- contest decided that) must still be subdued with the same tapping, and it can tear free. The fly's numbers scaled the other way, by a
-- factor of 1.8 (taps worth 0.067 against a drain of about 0.9 a second at the start), would take 10 or more taps a second and tear free in
-- 0.64 s untouched (a simulation outside the suite), so the rival has
-- numbers of its own, chosen for how it plays: a firmer start (0.6) but each tap worth less than a house fly's (0.085, Godot's, not 0.12), a
-- drain half the fly's that eases only a little (the rival tires to 0.75 of its strength, not 0.5) and no cap, so it is never subdued by waiting.
-- It takes about 3.3 taps a second to hold it (the house fly: 2.5, and it is subdued at 12 s whatever); 4 a second wins in 5.7 to 8.4 s
-- (the fly: 4.6 s); with no taps it tears free in about 2 s (the fly: 1.15 s); a pause of 3 s loses it.
Catch.rival = {
	startGrip = 0.6,
	tapGain = 0.085,
	jerkScale = 0.8,
	drainScale = 0.5,
	tire = 0.25,
	cap = math.huge,
}

-- The rival's numbers: the gentle modes get the house fly's struggle (it can still be lost by not tapping, and never harms the player) and, like
-- the full rival, no cap.
function Catch.forRival(gentle: boolean): { [string]: number }
	if gentle then
		local g = Catch.scaled(1)
		g.cap = math.huge
		return g
	end
	local r = Catch.rival
	return {
		startGrip = r.startGrip, tapGain = r.tapGain, jerkScale = r.jerkScale, drainScale = r.drainScale, tire = r.tire, cap = r.cap,
	}
end

return Catch
