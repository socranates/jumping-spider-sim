--!strict
-- A repeatable port stream (Park-Miller); Godot's random inputs are exported for parity fixtures.
local R={};R.__index=R
function R.new(seed: number): any return setmetatable({state=math.max(1,math.floor(seed)%2147483647)},R) end
function R.next(self: any): number self.state=(self.state*16807)%2147483647;return self.state/2147483647 end
function R.draw(self: any,pair: {number}): number return pair[1]+(pair[2]-pair[1])*self:next() end
return R
