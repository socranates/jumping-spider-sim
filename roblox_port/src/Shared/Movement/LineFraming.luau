--!strict
-- The camera's line framing at a catch: a port of the frozen Godot camera_rig.gd (c87ce00; A-017, chunk 6A, capped in 6B).
-- While the spider hangs on its line and the player's own view has no room where the spider will hang (the line's rest
-- point, so the view does not chase the swing), the view turns by the smallest turn, in 15-degree steps either way, that
-- gives a comfortable boom with a clear sight of the spider and of the lip the line leaves its support at. The turn is
-- added to the player's yaw (the view yaw); the player's own yaw is untouched. It never exceeds 45 degrees
-- (FRAMING_MAX_TURN_DEG), eases in over about 0.12 s, never rolls the view, and is cast like any other boom.
-- The player always wins: any look input, a recenter or aiming takes the turn over at once (it becomes the player's own
-- yaw, so nothing moves on screen) and the framing stays off until the line ends. When the line ends the view stays where
-- the framing left it. Pure: the world queries are behind `good(turn)`, so tests check the decisions against values
-- exported from Godot (tests/framing_reference.json) and Studio checks the geometry (tests/studio/CameraSpec.luau).
local CameraMath = require(script.Parent.CameraMath)

local LineFraming = {}
LineFraming.__index = LineFraming

LineFraming.ASSIST_STEP_DEG = 15.0
LineFraming.FRAMING_MAX_TURN_DEG = 45.0 -- Chet's cap (chunk 6B): was a half turn in 6A
LineFraming.ASSIST_SMOOTH_SECONDS = 0.12
LineFraming.SIGHT_TOLERANCE = 0.06 -- a ray that stops this short of its end still saw it

function LineFraming.new(): any
	return setmetatable({
		assist = 0, -- the turn added to the player's yaw now, radians
		prev = 0,
		target = 0, -- the turn wanted at the last tick
		velocity = 0,
		off = false, -- the player turned the view since the line caught: no framing until it ends
		enabled = true, -- Godot's setting "Frame the line after a catch" (default on)
		maxTurn = math.rad(LineFraming.FRAMING_MAX_TURN_DEG),
	}, LineFraming)
end

-- camera_rig._wanted_yaw_assist: the turn already held while it still works (so the view does not flip as the rest point
-- moves), else none when the player's own view works, else the smallest working step within the cap (+ before -),
-- else none (nowhere works: the view is left to the pitch search).
function LineFraming.wantedTurn(held: number, maxTurn: number, good: (number) -> boolean): number
	if held ~= 0 and good(held) then return held end
	if good(0) then return 0 end
	local step = math.rad(LineFraming.ASSIST_STEP_DEG)
	local k = 1
	while k * step <= maxTurn + 1e-6 do
		for _, side in { 1, -1 } do
			local turn = k * step * side
			if good(turn) then return turn end
		end
		k += 1
	end
	return 0
end

-- The player takes the view: returns the turn to add to the player's own yaw, so nothing moves on screen.
function LineFraming.takeOver(self: any): number
	if self.assist == 0 and self.prev == 0 and self.target == 0 then return 0 end
	local delta = self.assist
	self.assist, self.prev, self.target, self.velocity = 0, 0, 0, 0
	return delta
end

-- A look or a recenter: the turn is taken over and, on the line, the framing stays off until the line ends.
function LineFraming.playerTurns(self: any, onLine: boolean): number
	local delta = self:takeOver()
	if onLine then self.off = true end
	return delta
end

-- One fixed tick (camera_rig._update_assist). Returns a change for the player's yaw: the held turn when the line has just
-- ended (the view stays where it is), otherwise 0.
function LineFraming.tick(self: any, onLine: boolean, aiming: boolean, wanted: () -> number, dt: number): number
	self.prev = self.assist
	if not onLine then
		self.off = false
		return self:takeOver()
	end
	local w = 0
	if self.enabled and not self.off and not aiming then w = wanted() end
	self.target = w
	self.assist, self.velocity = CameraMath.smoothDamp(self.assist, w, self.velocity, LineFraming.ASSIST_SMOOTH_SECONDS, dt)
	return 0
end

-- The setting: switched off while a turn is held, the view stays where it is (the turn becomes the player's).
function LineFraming.setEnabled(self: any, on: boolean): number
	self.enabled = on
	return if on then 0 else self:takeOver()
end

-- A snap (spawn, reset, leaving the eye view): no turn at all.
function LineFraming.reset(self: any)
	self.assist, self.prev, self.target, self.velocity, self.off = 0, 0, 0, 0, false
end

return LineFraming
