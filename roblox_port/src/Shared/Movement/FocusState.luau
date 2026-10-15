--!strict
-- D-041: toggle is optional, grounded only, and Cancel belongs to other actions first.
local Focus = {}
Focus.__index = Focus
function Focus.new(): any return setmetatable({latched=false}, Focus) end
function Focus.press(self: any, toggle: boolean, grounded: boolean)
	if toggle and grounded then self.latched = not self.latched end
end
function Focus.active(self: any, held: boolean, toggle: boolean, grounded: boolean): boolean
	if not grounded or not toggle then self.latched = false end
	return grounded and (if toggle then self.latched else held)
end
function Focus.cancel(self: any, busy: boolean)
	if not busy then self.latched = false end
end
function Focus.clear(self: any) self.latched = false end
return Focus
