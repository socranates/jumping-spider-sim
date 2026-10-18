--!strict
-- Pure input state: test without Studio. +Y is forward on the control pad; look +X is right, +Y is down
-- (the Godot camera rig's convention: look(dx, dy) with dy > 0 looking down).
-- A button action can be held by several sources at once: a key, a controller button, a finger on a touch button. It is
-- held while any of them is down, so keyboard, controller and touch work together and releasing one never cancels another
-- (ROBLOX-08). set() returns the held state before and after, so callers act once per press and once per release.
local InputState = {}
InputState.__index = InputState

local MOVE_DEAD = 0.2
local LOOK_DEAD = 0.15

export type InputState = typeof(setmetatable({} :: {
	held: { [string]: boolean? },
	sources: { [string]: { [any]: boolean } },
	x: number,
	y: number,
	lx: number,
	ly: number,
}, InputState))

function InputState.new(): InputState
	return setmetatable({ held = {}, sources = {}, x = 0, y = 0, lx = 0, ly = 0 }, InputState)
end

-- One source's state of an action (source nil: a single default source). Returns (held before, held now).
function InputState.set(self: InputState, action: string, down: boolean, source: any?): (boolean, boolean)
	local key: any = if source == nil then "default" else source
	local was = self.held[action] == true
	local set = self.sources[action]
	if down then
		if not set then
			set = {}
			self.sources[action] = set
		end
		set[key] = true
	elseif set then
		set[key] = nil
	end
	local now = set ~= nil and next(set) ~= nil
	self.held[action] = if now then true else nil
	return was, now
end

-- How many sources hold the action now.
function InputState.count(self: InputState, action: string): number
	local n = 0
	local set: { [any]: boolean } = self.sources[action] or {}
	for _ in set do
		n += 1
	end
	return n
end

local function radial(x: number, y: number, dead: number): (number, number)
	local length = math.sqrt(x * x + y * y)
	local strength = math.clamp((length - dead) / (1 - dead), 0, 1)
	if length <= 0 then return 0, 0 end
	return x / length * strength, y / length * strength
end
function InputState.stick(self: InputState, x: number, y: number)
	self.x, self.y = radial(x, y, MOVE_DEAD)
end
-- Right stick: Roblox reports +Y up; store it as look-down positive.
function InputState.look(self: InputState, x: number, y: number)
	local rx, ry = radial(x, y, LOOK_DEAD)
	self.lx, self.ly = rx, -ry
end
function InputState.axes(self: InputState): (number, number)
	local x = self.x + (if self.held.Right then 1 else 0) - (if self.held.Left then 1 else 0)
	local y = self.y + (if self.held.Forward then 1 else 0) - (if self.held.Back then 1 else 0)
	local length = math.max(1, math.sqrt(x * x + y * y))
	return x / length, y / length
end
-- Look rate in -1..1 per axis: right stick plus arrow keys.
function InputState.lookAxes(self: InputState, aiming: boolean?): (number, number)
	local x = self.lx + (if aiming then self.x else 0) + (if self.held.LookRight then 1 else 0) - (if self.held.LookLeft then 1 else 0)
	local y = self.ly - (if aiming then self.y else 0) + (if self.held.LookDown then 1 else 0) - (if self.held.LookUp then 1 else 0)
	return math.clamp(x, -1, 1), math.clamp(y, -1, 1)
end
-- Focus loss, the Roblox menu, a text box, a lost controller: nothing stays held.
function InputState.clear(self: InputState)
	table.clear(self.held)
	table.clear(self.sources)
	self.x, self.y, self.lx, self.ly = 0, 0, 0, 0
end
return InputState
