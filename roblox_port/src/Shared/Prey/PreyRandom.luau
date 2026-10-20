--!strict
-- A repeatable port stream (Park-Miller); Godot's random inputs are exported for parity fixtures.
local R={};R.__index=R
function R.new(seed: number): any return setmetatable({state=math.max(1,math.floor(seed)%2147483647)},R) end
function R.next(self: any): number self.state=(self.state*16807)%2147483647;return self.state/2147483647 end
function R.draw(self: any,pair: {number}): number return pair[1]+(pair[2]-pair[1])*self:next() end
-- ROBLOX-106: a stream whose seed is a hash of whole numbers (FNV-1a, 32 bits, exact in doubles), drawn twice before use. The draws of W4's rules use it so that the
-- streams of neighbouring days, nights, visits or legs are not fixed offsets of one another (a plain Park-Miller seed made from a linear mix gives first draws that step
-- round the unit interval by a constant, which reads as a schedule).
function R.mixed(...: number): any
	local h = 2166136261
	for i = 1, select("#", ...) do
		local v = math.floor((select(i, ...))) % 4294967296
		for k = 0, 3 do
			h = bit32.bxor(h, bit32.band(bit32.rshift(v, 8 * k), 255))
			h = (h * 403 + bit32.lshift(h, 24)) % 4294967296 -- (h x 16777619, the FNV prime, mod 2^32: 16777619 = 2^24 + 403)
		end
	end
	local r = R.new(h % 2147483646 + 1)
	r:next()
	r:next()
	return r
end
return R
