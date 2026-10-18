--!strict
-- The fly-catch struggle as the game plays it (ROBLOX-72). Game tuning, not measurements; Godot's values (Prey/Feeding's defaults, checked
-- by the goldens) are untouched and a Feeding that is never given these replays them. Prey/Feeding:useGameRules() applies this table.
-- The struggle: the grip starts at startGrip, drains 0.32 x the fly's strength a second plus a jerk (0.12 x strength x jerkScale) every
-- 0.35 to 0.75 s, each tap adds tapGain, and the fly is subdued at a grip of 1 or after 12 s. Drain, the jerk's timing and the 12 s cap are
-- not changed here.
local Catch = {}

-- Nathan: "make the tapping a bit easier when catching the fly." Godot: startGrip 0.4, tapGain 0.085, jerkScale 1.0.
Catch.game = {
	startGrip = 0.5,
	tapGain = 0.12,
	jerkScale = 0.8, -- a jerk takes 0.096 x strength of the grip, not 0.12
}

return Catch
