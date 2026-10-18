-- Preview-only Roblox stand-ins: enough Vector3/CFrame/Instance/Workspace for SpiderRig to build and pose itself.
local V = {}
local function vnew(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return vnew(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vnew(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vnew(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b) if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vnew(a.X * b, a.Y * b, a.Z * b) end
	return vnew(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V.__div = function(a, b) return vnew(a.X / b, a.Y / b, a.Z / b) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
local methods = {}
function methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function methods.Cross(a, b) return vnew(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function methods.Lerp(a, b, t) return a + (b - a) * t end
V.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return vnew(v.X / m, v.Y / m, v.Z / m) end
	return methods[k]
end
Vector3 = { new = vnew, zero = vnew(0, 0, 0), one = vnew(1, 1, 1), xAxis = vnew(1, 0, 0), yAxis = vnew(0, 1, 0), zAxis = vnew(0, 0, 1) }

local C = {}
local function cnew(p, x, y, z) return setmetatable({ p = p, x = x, y = y, z = z }, C) end
local function rot(c, v) return c.x * v.X + c.y * v.Y + c.z * v.Z end
C.__mul = function(a, b)
	if getmetatable(b) == C then return cnew(rot(a, b.p) + a.p, rot(a, b.x), rot(a, b.y), rot(a, b.z)) end
	return rot(a, b) + a.p
end
local cm = {}
function cm.PointToWorldSpace(c, v) return rot(c, v) + c.p end
function cm.VectorToWorldSpace(c, v) return rot(c, v) end
function cm.VectorToObjectSpace(c, v) return vnew(v:Dot(c.x), v:Dot(c.y), v:Dot(c.z)) end
function cm.PointToObjectSpace(c, v) local d = v - c.p; return vnew(d:Dot(c.x), d:Dot(c.y), d:Dot(c.z)) end
function cm.Inverse(c)
	local x, y, z = vnew(c.x.X, c.y.X, c.z.X), vnew(c.x.Y, c.y.Y, c.z.Y), vnew(c.x.Z, c.y.Z, c.z.Z)
	local r = cnew(vnew(0, 0, 0), x, y, z)
	return cnew(-rot(r, c.p), x, y, z)
end
C.__index = function(c, k)
	if k == "Position" then return c.p end
	if k == "UpVector" then return c.y end
	if k == "LookVector" then return -c.z end
	if k == "RightVector" then return c.x end
	if k == "Rotation" then return cnew(vnew(0, 0, 0), c.x, c.y, c.z) end
	return cm[k]
end
local I = cnew(vnew(0, 0, 0), vnew(1, 0, 0), vnew(0, 1, 0), vnew(0, 0, 1))
local function axisAngle(k, a)
	k = k.Unit
	local function r(v) local c, s = math.cos(a), math.sin(a); return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c)) end
	return cnew(vnew(0, 0, 0), r(vnew(1, 0, 0)), r(vnew(0, 1, 0)), r(vnew(0, 0, 1)))
end
CFrame = {
	identity = I,
	new = function(a, b, c) if a == nil then return I end; if type(a) == "number" then return cnew(vnew(a, b, c), I.x, I.y, I.z) end; return cnew(a, I.x, I.y, I.z) end,
	fromMatrix = function(p, x, y, z) return cnew(p, x, y, z or x:Cross(y)) end,
	fromAxisAngle = axisAngle,
	Angles = function(rx, ry, rz) return axisAngle(vnew(1, 0, 0), rx) * axisAngle(vnew(0, 1, 0), ry) * axisAngle(vnew(0, 0, 1), rz) end,
	lookAt = function(at, target, up)
		up = up or vnew(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		local u = right:Cross(look)
		return cnew(at, right, u, -look)
	end,
}
Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
local function enumTable(name) return setmetatable({}, { __index = function(_, k) return name .. "." .. k end }) end
Enum = setmetatable({}, { __index = function(_, k) return enumTable(k) end })
PARTS = {}
local Inst = {}
Inst.__index = function(t, k)
	if k == "SetAttribute" then return function(self, a, v) rawset(self, "attr_" .. a, v) end end
	if k == "GetAttribute" then return function(self, a) return rawget(self, "attr_" .. a) end end
	if k == "Destroy" then return function() end end
	if k == "GetChildren" then return function(self) return rawget(self, "_kids") or {} end end -- the rig sizes and colours its parts for growth
	if k == "IsA" then return function(self, cls) return rawget(self, "ClassName") == cls or (cls == "BasePart" and rawget(self, "ClassName") == "Part") end end
	return nil
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" and v ~= nil and rawget(t, "ClassName") == "SpecialMesh" then rawset(v, "Mesh", t) end
	if k == "Parent" and v ~= nil then
		local kids = rawget(v, "_kids")
		if kids == nil then kids = {}; rawset(v, "_kids", kids) end
		table.insert(kids, t)
	end
	rawset(t, k, v)
end
Instance = { new = function(cls)
	local o = setmetatable({ ClassName = cls, Size = vnew(1, 1, 1), Transparency = 0, LocalTransparencyModifier = 0, Shape = "Enum.PartType.Block" }, Inst)
	if cls == "Part" then table.insert(PARTS, o) end
	return o
end }
RaycastParams = { new = function() return {} end }
local floorY = 0
Workspace = {
	Raycast = function(_, origin, dir)
		if dir.Y >= 0 then return nil end
		local t = (floorY - origin.Y) / dir.Y
		if t < 0 or t > 1 then return nil end
		return { Position = origin + dir * t, Normal = vnew(0, 1, 0) }
	end,
	BulkMoveTo = function(_, parts, cfs) for i, p in parts do p.CFrame = cfs[i] end end,
}
game = { GetService = function(_, n) return Workspace end }
