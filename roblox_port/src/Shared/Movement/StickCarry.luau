--!strict
-- The carry over an edge: a port of the frozen Godot scripts/movement/player_controller.gd _carry (c87ce00).
-- On a wall, forward is up; on a floor, away from the camera. So holding the stick forward over a sharp edge would flip
-- the camera mapping and walk the spider straight back (it would oscillate at the edge). When the support turns sharply
-- (the motor's transitionSerial changes) while the stick is held, the motor's own direction, which it turned with the
-- support, is kept instead of the fresh mapping. The carry ends when the stick is released or turned by more than
-- CARRY_STICK_DEG, or when the fresh mapping agrees with the carried direction again (within CARRY_AGREE_DEG). Pure.
local StickCarry = {}
StickCarry.__index = StickCarry

StickCarry.CARRY_STICK_DEG = 30.0
StickCarry.CARRY_AGREE_DEG = 25.0

function StickCarry.new(): any
	return setmetatable({ carrying = false, sx = 0, sy = 0, lastSerial = 0 }, StickCarry)
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.atan2(a:Cross(b).Magnitude, a:Dot(b))
end

-- stick x right, y forward; fresh: the camera mapping on the support now; serial: the motor's transition count;
-- carried: the motor's own walking direction (turned with the support); inTransition: rounding an edge.
function StickCarry.step(self: any, sx: number, sy: number, fresh: Vector3, serial: number, carried: Vector3, inTransition: boolean): Vector3
	local turned = serial ~= self.lastSerial
	self.lastSerial = serial
	local length = math.sqrt(sx * sx + sy * sy)
	if length * length < 1e-8 then
		self.carrying = false
		return Vector3.zero
	end
	local nx, ny = sx / length, sy / length
	if turned and not self.carrying then
		self.carrying = true
		self.sx, self.sy = nx, ny
	end
	if not self.carrying then return fresh end
	if math.acos(math.clamp(nx * self.sx + ny * self.sy, -1, 1)) > math.rad(StickCarry.CARRY_STICK_DEG) then
		self.carrying = false
		return fresh
	end
	if carried:Dot(carried) < 1e-8 then
		self.carrying = false
		return fresh
	end
	local dir = carried.Unit
	if not inTransition and fresh:Dot(fresh) > 1e-8 and angleBetween(fresh.Unit, dir) < math.rad(StickCarry.CARRY_AGREE_DEG) then
		self.carrying = false
		return fresh
	end
	return dir * math.min(length, 1)
end

return StickCarry
