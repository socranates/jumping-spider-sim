-- Minimal Vector3 / CFrame stand-ins so the pure shared modules run under the plain `luau` CLI (no Roblox engine).
local Vector3 = {}
Vector3.__index = Vector3
local function new(x: number?, y: number?, z: number?)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.new = new
Vector3.__add = function(a, b) return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__unm = function(a) return new(-a.X, -a.Y, -a.Z) end
Vector3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return new(a.X * b, a.Y * b, a.Z * b)
end
Vector3.__div = function(a, b) return new(a.X / b, a.Y / b, a.Z / b) end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return new(v.X / m, v.Y / m, v.Z / m) end
	return rawget(Vector3, k)
end
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b) return new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
Vector3.zero = new(0, 0, 0)
Vector3.one = new(1, 1, 1)
Vector3.yAxis = new(0, 1, 0)

-- Rodrigues rotation; enough for SupportMath.rotateToward.
local CFrame = {}
function CFrame.fromAxisAngle(axis, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return setmetatable({}, { __mul = function(_, v)
		return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
	end })
end
return { Vector3 = Vector3, CFrame = CFrame }
