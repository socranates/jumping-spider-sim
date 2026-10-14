-- Minimal Roblox stand-ins so the shared modules run under the plain `luau` CLI (no Roblox engine): Vector3, CFrame
-- (rotation and position), Color3, Enum, Instance (parts and folders), RaycastParams, OverlapParams, and a `workspace`
-- whose Raycast, Spherecast and GetPartsInPart test axis-aligned boxes: the "box world". The box world exists to run the
-- motor and silk code paths deterministically in tests/scenarios.luau; it is an emulation, not the Roblox engine, and
-- Studio specs (tests/studio) remain the engine evidence. Like the engine, a ray ignores a box it starts inside and a
-- sphere cast ignores a box it starts overlapping; CanQuery = false parts are invisible to queries.

-- ---------------------------------------------------------------- Vector3
local Vector3 = {}
local function new(x: number?, y: number?, z: number?)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.new = new
Vector3.__add = function(a, b) return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__unm = function(a) return new(-a.X, -a.Y, -a.Z) end
Vector3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return new(a.X * b, a.Y * b, a.Z * b) end
	return new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then return new(a.X / b, a.Y / b, a.Z / b) end
	return new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__tostring = function(v) return string.format("%.4f, %.4f, %.4f", v.X, v.Y, v.Z) end
Vector3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return new(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(Vector3, k)
end
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b) return new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function Vector3.Lerp(a, b, t) return new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function Vector3.Min(a, b) return new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function Vector3.Max(a, b) return new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
Vector3.zero = new(0, 0, 0)
Vector3.one = new(1, 1, 1)
Vector3.xAxis = new(1, 0, 0)
Vector3.yAxis = new(0, 1, 0)
Vector3.zAxis = new(0, 0, 1)

-- ---------------------------------------------------------------- CFrame: rotation columns X, Y, Z and a position
local CFrame = {}
local function cf(p, x, y, z)
	return setmetatable({ _p = p, _x = x, _y = y, _z = z }, CFrame)
end
CFrame.__index = function(c, k)
	if k == "Position" or k == "p" then return c._p end
	if k == "X" then return c._p.X end
	if k == "Y" then return c._p.Y end
	if k == "Z" then return c._p.Z end
	if k == "LookVector" then return -c._z end
	if k == "RightVector" or k == "XVector" then return c._x end
	if k == "UpVector" or k == "YVector" then return c._y end
	if k == "ZVector" then return c._z end
	if k == "Rotation" then return cf(Vector3.zero, c._x, c._y, c._z) end
	return rawget(CFrame, k)
end
local function rot(c, v) return c._x * v.X + c._y * v.Y + c._z * v.Z end
CFrame.__mul = function(a, b)
	if getmetatable(b) == Vector3 then return a._p + rot(a, b) end
	return cf(a._p + rot(a, b._p), rot(a, b._x), rot(a, b._y), rot(a, b._z))
end
CFrame.__add = function(a, v) return cf(a._p + v, a._x, a._y, a._z) end
CFrame.__sub = function(a, v) return cf(a._p - v, a._x, a._y, a._z) end
function CFrame.new(x, y, z)
	local p = if type(x) == "number" then new(x, y, z) elseif x then x else Vector3.zero
	return cf(p, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
CFrame.identity = CFrame.new()
function CFrame.fromMatrix(p, x, y, z)
	z = z or x:Cross(y).Unit
	return cf(p, x, y, z)
end
-- Rodrigues: the rotation about unit axis k by angle a.
local function rotate(v, k, a)
	local c, s = math.cos(a), math.sin(a)
	return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c))
end
function CFrame.fromAxisAngle(axis, angle)
	local k = axis.Unit
	return cf(Vector3.zero, rotate(Vector3.xAxis, k, angle), rotate(Vector3.yAxis, k, angle), rotate(Vector3.zAxis, k, angle))
end
local function rx(a) return cf(Vector3.zero, Vector3.xAxis, new(0, math.cos(a), math.sin(a)), new(0, -math.sin(a), math.cos(a))) end
local function ry(a) return cf(Vector3.zero, new(math.cos(a), 0, -math.sin(a)), Vector3.yAxis, new(math.sin(a), 0, math.cos(a))) end
local function rz(a) return cf(Vector3.zero, new(math.cos(a), math.sin(a), 0), new(-math.sin(a), math.cos(a), 0), Vector3.zAxis) end
function CFrame.Angles(a, b, c) return rx(a) * ry(b) * rz(c) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-9 then right = look:Cross(Vector3.zAxis) end
	right = right.Unit
	local u = right:Cross(look).Unit
	return cf(at, right, u, -look)
end
function CFrame.Inverse(c)
	local x, y, z = c._x, c._y, c._z
	local tx, ty, tz = new(x.X, y.X, z.X), new(x.Y, y.Y, z.Y), new(x.Z, y.Z, z.Z)
	local r = cf(Vector3.zero, tx, ty, tz)
	return cf(-rot(r, c._p), tx, ty, tz)
end
function CFrame.PointToWorldSpace(c, v) return c._p + rot(c, v) end
function CFrame.VectorToWorldSpace(c, v) return rot(c, v) end
function CFrame.PointToObjectSpace(c, v) local d = v - c._p return new(d:Dot(c._x), d:Dot(c._y), d:Dot(c._z)) end
function CFrame.VectorToObjectSpace(c, v) return new(v:Dot(c._x), v:Dot(c._y), v:Dot(c._z)) end

-- ---------------------------------------------------------------- Color3, Enum
local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(s)
	s = string.gsub(s, "#", "")
	return Color3.fromRGB(tonumber(string.sub(s, 1, 2), 16), tonumber(string.sub(s, 3, 4), 16), tonumber(string.sub(s, 5, 6), 16))
end
function Color3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end

local Enum = setmetatable({}, { __index = function(enums, typeName)
	local items = setmetatable({}, { __index = function(list, itemName)
		local item = { Name = itemName, EnumType = typeName }
		rawset(list, itemName, item)
		return item
	end })
	rawset(enums, typeName, items)
	return items
end })

-- ---------------------------------------------------------------- Instances: folders and parts
local Instance = {}
local Object = {}
local BASE_PARTS = { Part = true, WedgePart = true, MeshPart = true }
local HAS_CFRAME = { Part = true, WedgePart = true, MeshPart = true, Camera = true }
local function children(o) return rawget(o, "_children") end
Object.__index = function(o, k)
	if k == "Parent" then return rawget(o, "_parent") end
	if k == "Position" then local c = rawget(o, "_cframe") return c and c.Position end
	if k == "CFrame" then return rawget(o, "_cframe") end
	return rawget(Object, k)
end
Object.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			local list = children(old)
			for i, c in list do if c == o then table.remove(list, i) break end end
		end
		rawset(o, "_parent", v)
		if v then table.insert(children(v), o) end
	elseif k == "Position" then
		local c = rawget(o, "_cframe")
		rawset(o, "_cframe", cf(v, c._x, c._y, c._z))
	elseif k == "CFrame" then
		rawset(o, "_cframe", v)
	else
		rawset(o, k, v)
	end
end
function Instance.new(className: string)
	local o = setmetatable({ ClassName = className, Name = className, _children = {}, _attrs = {} }, Object)
	if HAS_CFRAME[className] then
		rawset(o, "_cframe", CFrame.new())
	end
	if BASE_PARTS[className] then
		rawset(o, "Size", new(4, 1, 2))
		rawset(o, "CanQuery", true)
		rawset(o, "CanCollide", true)
		rawset(o, "Anchored", false)
		rawset(o, "Transparency", 0)
	end
	return o
end
function Object.IsA(o, cls) return o.ClassName == cls or (cls == "BasePart" and BASE_PARTS[o.ClassName] == true) or cls == "Instance" end
function Object.IsDescendantOf(o, ancestor)
	local p = rawget(o, "_parent")
	while p do
		if p == ancestor then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function Object.GetChildren(o) return table.clone(children(o)) end
function Object.GetDescendants(o)
	local out = {}
	local function walk(x) for _, c in children(x) do table.insert(out, c) walk(c) end end
	walk(o)
	return out
end
function Object.FindFirstChild(o, name) for _, c in children(o) do if c.Name == name then return c end end return nil end
function Object.FindFirstChildWhichIsA(o, cls, recursive)
	for _, c in (if recursive then o:GetDescendants() else children(o)) do if c:IsA(cls) then return c end end
	return nil
end
function Object.WaitForChild(o, name) return o:FindFirstChild(name) or o end
function Object.SetAttribute(o, k, v) rawget(o, "_attrs")[k] = v end
function Object.GetAttribute(o, k) return rawget(o, "_attrs")[k] end
function Object.Destroy(o)
	o.Parent = nil
	for _, c in table.clone(children(o)) do c:Destroy() end
end
function Object.ClearAllChildren(o) for _, c in table.clone(children(o)) do c:Destroy() end end

local RaycastParams, OverlapParams = {}, {}
function RaycastParams.new() return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {} } end
function OverlapParams.new() return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {} } end

-- ---------------------------------------------------------------- the box world
local workspace = Instance.new("Workspace")
workspace.Name = "Workspace"

-- The queryable boxes a query sees (Include or Exclude filters, as the engine): {part, lo, hi}.
local function boxes(params)
	local roots = params and params.FilterDescendantsInstances or {}
	local include = params and params.FilterType == Enum.RaycastFilterType.Include
	local out = {}
	for _, o in workspace:GetDescendants() do
		if o:IsA("BasePart") and o.CanQuery ~= false then
			local inside = false
			for _, r in roots do if o == r or o:IsDescendantOf(r) then inside = true break end end
			if inside == include then
				local half = o.Size / 2
				local p = o.Position
				table.insert(out, { part = o, lo = p - half, hi = p + half })
			end
		end
	end
	return out
end

local AXES = { "X", "Y", "Z" }
local function axisVector(a, s)
	return if a == "X" then new(s, 0, 0) elseif a == "Y" then new(0, s, 0) else new(0, 0, s)
end
local function inside(p, b, eps)
	return p.X > b.lo.X + eps and p.X < b.hi.X - eps and p.Y > b.lo.Y + eps and p.Y < b.hi.Y - eps and p.Z > b.lo.Z + eps and p.Z < b.hi.Z - eps
end
local function closest(p, b)
	return new(math.clamp(p.X, b.lo.X, b.hi.X), math.clamp(p.Y, b.lo.Y, b.hi.Y), math.clamp(p.Z, b.lo.Z, b.hi.Z))
end

-- Ray against an axis-aligned box: entry distance and normal, or nil.
local function rayBox(o, d, b)
	local tmin, tmax, normal = -math.huge, math.huge, nil
	for _, a in AXES do
		local oa, da, lo, hi = o[a], d[a], b.lo[a], b.hi[a]
		if math.abs(da) < 1e-12 then
			if oa < lo or oa > hi then return nil end
		else
			local t1, t2 = (lo - oa) / da, (hi - oa) / da
			local n1 = axisVector(a, -1)
			if t1 > t2 then t1, t2 = t2, t1; n1 = axisVector(a, 1) end
			if t1 > tmin then tmin, normal = t1, n1 end
			if t2 < tmax then tmax = t2 end
			if tmin > tmax then return nil end
		end
	end
	if tmax < 0 or tmin < 0 or normal == nil then return nil end
	return tmin, normal
end

function workspace.Raycast(_self, origin, direction, params)
	local length = direction.Magnitude
	if length < 1e-12 then return nil end
	local d = direction / length
	local best = nil
	for _, b in boxes(params) do
		if not inside(origin, b, 1e-9) then
			local t, n = rayBox(origin, d, b)
			if t and t <= length and (not best or t < best.Distance) then
				best = { Position = origin + d * t, Normal = n, Instance = b.part, Distance = t, Material = Enum.Material.Plastic }
			end
		end
	end
	return best
end

-- Ray (unit d) against a sphere (centre c, radius r): first t >= 0.
local function raySphere(o, d, c, r)
	local m = o - c
	local bq = m:Dot(d)
	local cq = m:Dot(m) - r * r
	local disc = bq * bq - cq
	if disc < 0 then return nil end
	local t = -bq - math.sqrt(disc)
	return if t >= 0 then t else nil
end
-- Ray against an infinite cylinder around the axis through a along unit u, radius r, limited to the segment [0, len].
local function rayCylinder(o, d, a, u, len, r)
	local m = o - a
	local dd = d - u * d:Dot(u)
	local mm = m - u * m:Dot(u)
	local A = dd:Dot(dd)
	if A < 1e-14 then return nil end
	local B = mm:Dot(dd)
	local C = mm:Dot(mm) - r * r
	local disc = B * B - A * C
	if disc < 0 then return nil end
	local t = (-B - math.sqrt(disc)) / A
	if t < 0 then return nil end
	local s = (o + d * t - a):Dot(u)
	if s < 0 or s > len then return nil end
	return t
end
-- Sphere of radius r swept from o along unit d against a box (the box grown by r with rounded edges): first contact t.
local function sphereBox(o, d, r, b)
	local best = nil
	for _, a in AXES do
		for _, s in { -1, 1 } do
			local plane = if s > 0 then b.hi[a] + r else b.lo[a] - r
			local da = d[a]
			if (s > 0 and da < 0) or (s < 0 and da > 0) then
				local t = (plane - o[a]) / da
				if t >= 0 then
					local q = o + d * t
					local ok = true
					for _, other in AXES do
						if other ~= a and (q[other] < b.lo[other] or q[other] > b.hi[other]) then ok = false end
					end
					if ok and (not best or t < best) then best = t end
				end
			end
		end
	end
	local lo, hi = b.lo, b.hi
	local corners = {}
	for _, x in { lo.X, hi.X } do for _, y in { lo.Y, hi.Y } do for _, z in { lo.Z, hi.Z } do table.insert(corners, new(x, y, z)) end end end
	for _, c in corners do
		local t = raySphere(o, d, c, r)
		if t and (not best or t < best) then best = t end
		for _, a in AXES do
			local u = axisVector(a, 1)
			if c[a] == lo[a] then
				local t2 = rayCylinder(o, d, c, u, hi[a] - lo[a], r)
				if t2 and (not best or t2 < best) then best = t2 end
			end
		end
	end
	return best
end

function workspace.Spherecast(_self, origin, radius, direction, params)
	local length = direction.Magnitude
	if length < 1e-12 then return nil end
	local d = direction / length
	local best = nil
	for _, b in boxes(params) do
		if (closest(origin, b) - origin).Magnitude >= radius then -- a box the sphere starts in is not seen
			local t = sphereBox(origin, d, radius, b)
			if t and t <= length and (not best or t < best.Distance) then
				local centre = origin + d * t
				local contact = closest(centre, b)
				local n = centre - contact
				best = { Position = contact, Normal = if n.Magnitude > 1e-9 then n.Unit else -d, Instance = b.part, Distance = t, Material = Enum.Material.Plastic }
			end
		end
	end
	return best
end

function workspace.GetPartsInPart(_self, part, params)
	local r = part.Size.X / 2
	local centre = part.Position
	local out = {}
	for _, b in boxes(params) do
		if b.part ~= part and (closest(centre, b) - centre).Magnitude < r then table.insert(out, b.part) end
	end
	return out
end

function workspace.GetPartBoundsInRadius(_self, centre, r, params)
	local out = {}
	for _, b in boxes(params) do
		if (closest(centre, b) - centre).Magnitude < r then table.insert(out, b.part) end
	end
	return out
end

-- Vector2 and the services the client modules touch (no input, no menu).
local Vector2 = {}
Vector2.__index = Vector2
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, Vector2) end
Vector2.zero = Vector2.new(0, 0)
local function signal() return { Connect = function() return { Disconnect = function() end } end } end
local services = {
	Workspace = workspace,
	ReplicatedStorage = Instance.new("Folder"),
	GuiService = { MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal() },
	UserInputService = { InputChanged = signal(), MouseBehavior = nil, MouseIconEnabled = true, TouchEnabled = false, KeyboardEnabled = true,
		GetMouseDelta = function() return Vector2.zero end },
}
local game = { GetService = function(_self, name) return services[name] end }

-- Builds axis-aligned parts from {lo, hi, profile, name} pieces into a folder in the workspace.
local BoxWorld = {}
function BoxWorld.folder(name: string, pieces)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	for _, piece in pieces do
		local p = Instance.new("Part")
		p.Name = piece.name or piece.id or "Box"
		p.Size = piece.hi - piece.lo
		p.Position = (piece.hi + piece.lo) / 2
		p.Anchored = true
		p:SetAttribute("ProfileId", piece.profile)
		p.Parent = folder
	end
	return folder
end

return { Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum, Instance = Instance, RaycastParams = RaycastParams,
	OverlapParams = OverlapParams, workspace = workspace, BoxWorld = BoxWorld, Vector2 = Vector2, game = game }
