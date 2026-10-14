--!strict
-- Pure input state: test without Studio. +Y is forward on the control pad; look +X is right, +Y is down
-- (the Godot camera rig's convention: look(dx, dy) with dy > 0 looking down).
local InputState = {}
InputState.__index = InputState

local MOVE_DEAD = 0.2
local LOOK_DEAD = 0.15

function InputState.new()
	return setmetatable({ held = {} :: {[string]: boolean}, x = 0, y = 0, lx = 0, ly = 0 }, InputState)
end
function InputState.set(self: any, action: string, down: boolean)
	self.held[action] = down
end
local function radial(x: number, y: number, dead: number): (number, number)
	local length = math.sqrt(x*x + y*y)
	local strength = math.clamp((length - dead) / (1 - dead), 0, 1)
	if length <= 0 then return 0, 0 end
	return x / length * strength, y / length * strength
end
function InputState.stick(self: any, x: number, y: number)
	self.x, self.y = radial(x, y, MOVE_DEAD)
end
-- Right stick: Roblox reports +Y up; store it as look-down positive.
function InputState.look(self: any, x: number, y: number)
	local rx, ry = radial(x, y, LOOK_DEAD)
	self.lx, self.ly = rx, -ry
end
function InputState.axes(self: any): (number, number)
	local x = self.x + (if self.held.Right then 1 else 0) - (if self.held.Left then 1 else 0)
	local y = self.y + (if self.held.Forward then 1 else 0) - (if self.held.Back then 1 else 0)
	local length = math.max(1, math.sqrt(x*x + y*y))
	return x / length, y / length
end
-- Look rate in -1..1 per axis: right stick plus arrow keys.
function InputState.lookAxes(self: any): (number, number)
	local x = self.lx + (if self.held.LookRight then 1 else 0) - (if self.held.LookLeft then 1 else 0)
	local y = self.ly + (if self.held.LookDown then 1 else 0) - (if self.held.LookUp then 1 else 0)
	return math.clamp(x, -1, 1), math.clamp(y, -1, 1)
end
function InputState.clear(self: any)
	table.clear(self.held)
	self.x, self.y, self.lx, self.ly = 0, 0, 0, 0
end
return InputState
