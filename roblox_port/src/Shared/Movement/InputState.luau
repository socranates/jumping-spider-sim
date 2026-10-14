--!strict
-- Pure input state: test without Studio. +Y is forward on the control pad.
local InputState = {}
InputState.__index = InputState
function InputState.new()
	return setmetatable({ held = {} :: {[string]: boolean}, x = 0, y = 0 }, InputState)
end
function InputState.set(self, action: string, down: boolean)
	self.held[action] = down
end
function InputState.stick(self, x: number, y: number)
	local length = math.sqrt(x*x + y*y)
	local strength = math.clamp((length - 0.2) / 0.8, 0, 1)
	self.x = if length > 0 then x / length * strength else 0
	self.y = if length > 0 then y / length * strength else 0
end
function InputState.axes(self): (number, number)
	local x = self.x + (if self.held.Right then 1 else 0) - (if self.held.Left then 1 else 0)
	local y = self.y + (if self.held.Forward then 1 else 0) - (if self.held.Back then 1 else 0)
	local length = math.max(1, math.sqrt(x*x + y*y))
	return x / length, y / length
end
function InputState.clear(self)
	table.clear(self.held)
	self.x, self.y = 0, 0
end
return InputState
