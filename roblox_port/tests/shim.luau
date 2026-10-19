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

-- Number and colour sequences (particles, beams, effects): plain tables with the fields the code reads.
local NumberRange = {}
function NumberRange.new(a, b) return { Min = a, Max = if b == nil then a else b } end
local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end
local NumberSequence = {}
function NumberSequence.new(a, b)
	if type(a) == "table" then return { Keypoints = a } end
	return { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, if b == nil then a else b) } }
end
local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, c) return { Time = t, Value = c } end
local ColorSequence = {}
function ColorSequence.new(a, b)
	if getmetatable(a) == Color3 then return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } } end
	return { Keypoints = a }
end

local Enum = setmetatable({}, { __index = function(enums, typeName)
	local items = setmetatable({}, { __index = function(list, itemName)
		local item = { Name = itemName, EnumType = typeName, Value = 0 }
		rawset(list, itemName, item)
		return item
	end })
	rawset(enums, typeName, items)
	return items
end })

-- ---------------------------------------------------------------- Instances: folders and parts
local Instance = {}
local Object = {}
-- What the engine would be asked to do, counted for the tests that measure the drawn rigs' cost: parts' Size writes, and BulkMoveTo calls and the parts they move.
local counters = { sizeWrites = 0, bulkCalls = 0, bulkParts = 0 }
local BASE_PARTS = { Part = true, WedgePart = true, MeshPart = true }
local HAS_CFRAME = { Part = true, WedgePart = true, MeshPart = true, Camera = true }
local function children(o) return rawget(o, "_children") end
local function newSignal()
	local sig = { handlers = {} }
	function sig.Connect(self, fn) table.insert(self.handlers, fn) return { Disconnect = function() end } end
	function sig.Fire(self, ...) for _, h in table.clone(self.handlers) do h(...) end end
	function sig.Wait(_self) return 0 end
	return sig
end
local EVENTS = { InputBegan = true, InputEnded = true, InputChanged = true, Activated = true, MouseButton1Click = true, Changed = true }
Object.__index = function(o, k)
	if k == "Size" then
		local s = rawget(o, "_size")
		if s ~= nil then return s end
	end
	if EVENTS[k] then
		local sig = newSignal()
		rawset(o, k, sig)
		return sig
	end
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
	elseif k == "Position" and rawget(o, "_cframe") then -- a part's position; a GUI object's Position is a plain UDim2
		local c = rawget(o, "_cframe")
		rawset(o, "_cframe", cf(v, c._x, c._y, c._z))
	elseif k == "CFrame" then
		rawset(o, "_cframe", v)
	elseif k == "Size" and rawget(o, "_size") ~= nil then -- a part's size: every write is counted (shim.counters, for tests that prove a frame writes none)
		counters.sizeWrites += 1
		rawset(o, "_size", v)
	else
		rawset(o, k, v)
	end
end
function Instance.new(className: string)
	local o = setmetatable({ ClassName = className, Name = className, _children = {}, _attrs = {} }, Object)
	rawset(o, "AbsolutePosition", {X=0,Y=0})
	if className == "ScreenGui" then rawset(o, "AbsoluteSize", { X = 1280, Y = 720 }) end
	if className == "TextLabel" or className == "Frame" or className == "TextButton" or className == "ScrollingFrame" then rawset(o, "AbsoluteSize", { X = 0, Y = 0 }) end -- nothing is laid out here: the engine's size before its first layout
	if className == "ScrollingFrame" then rawset(o, "AbsoluteWindowSize", { X = 0, Y = 0 }); rawset(o, "AbsoluteCanvasSize", { X = 0, Y = 0 }) end
	if HAS_CFRAME[className] then
		rawset(o, "_cframe", CFrame.new())
	end
	if BASE_PARTS[className] then
		rawset(o, "_size", new(4, 1, 2))
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
function Object.SetAttribute(o, k, v)
	local attrs = rawget(o, "_attrs")
	local old = attrs[k]
	attrs[k] = v
	if old ~= v then
		local sig = rawget(o, "_attr_" .. k)
		if sig then sig:Fire() end
	end
end
function Object.GetAttributeChangedSignal(o, name)
	local key = "_attr_" .. name
	local sig = rawget(o, key)
	if not sig then sig = newSignal(); rawset(o, key, sig) end
	return sig
end
-- Sound transport only; the shim cannot verify asset loading or audible output.
function Object.Play(o) o.Playing = true; o.TimePosition = 0; rawset(o, "plays", (rawget(o, "plays") or 0) + 1) end
function Object.Pause(o) o.Playing = false end
function Object.Resume(o) o.Playing = true; rawset(o, "plays", (rawget(o, "plays") or 0) + 1) end -- (`plays` counts the asks to play, ROBLOX-100)
function Object.Stop(o) o.Playing = false; o.TimePosition = 0 end
function Object.GetAttribute(o, k) return rawget(o, "_attrs")[k] end
function Object.Destroy(o)
	o.Parent = nil
	for _, c in table.clone(children(o)) do c:Destroy() end
end
function Object.GetPropertyChangedSignal(o, name)
	local key = "_changed_" .. name
	local sig = rawget(o, key)
	if not sig then sig = newSignal(); rawset(o, key, sig) end
	return sig
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

function workspace.BulkMoveTo(_self, parts, cframes)
	counters.bulkCalls += 1
	counters.bulkParts += #parts
	for i, p in parts do p.CFrame = cframes[i] end
end

-- Vector2, UDim, UDim2 and the services the client scripts touch. The client smoke test fires their signals.
local Vector2 = {}
Vector2.__index = function(v,k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end
	if k == "Unit" then local m=math.sqrt(v.X*v.X+v.Y*v.Y); return Vector2.new(v.X/m,v.Y/m) end
	return Vector2[k]
end
function Vector2.__eq(a,b) return a.X==b.X and a.Y==b.Y end
function Vector2.__add(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
function Vector2.__sub(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
function Vector2.__mul(a,b) return Vector2.new(a.X*b,a.Y*b) end
function Vector2.__div(a,b) return Vector2.new(a.X/b,a.Y/b) end
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, Vector2) end
Vector2.zero = Vector2.new(0, 0)
local UDim, UDim2 = {}, {}
local Font = {}
function Font.new(family, weight, style) return { Family = family, Weight = weight or Enum.FontWeight.Regular, Style = style or Enum.FontStyle.Normal } end
function UDim.new(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end
function UDim2.new(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(1280,720)
function camera.WorldToViewportPoint(self, at)
	local p = self.CFrame:PointToObjectSpace(at)
	local z = -p.Z
	local focal = 360/math.tan(math.rad(self.FieldOfView or 70)/2)
	local safe = if math.abs(z)<1e-6 then 1e-6 else z
	return new(640+p.X*focal/safe,360-p.Y*focal/safe,z), z>0
end
rawset(workspace, "CurrentCamera", camera)
local localPlayer = Instance.new("Player")
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
-- What the smoke test drives: bound actions, render steps, and the client's test-place driver (its SilkPlayback hook).
local client = { actions = {}, renderSteps = {}, studio = true, driver = nil :: any }
client.scriptFolder = Instance.new("Folder")
local playback = Instance.new("ModuleScript")
playback.Name = "SilkPlayback"
rawset(playback, "run", function(driver) client.driver = driver end)
playback.Parent = client.scriptFolder
local uis = { MouseBehavior = nil, MouseIconEnabled = true, TouchEnabled = false, KeyboardEnabled = true, GamepadEnabled = false }
for _, name in { "InputChanged", "InputEnded", "TouchMoved", "TouchPinch", "TouchStarted", "TouchEnded", "WindowFocusReleased", "TextBoxFocused", "GamepadDisconnected", "LastInputTypeChanged" } do
	uis[name] = newSignal()
end
function uis.GetMouseDelta(_self) return Vector2.zero end
function uis.GetFocusedTextBox(_self) return nil end
function uis.GetPropertyChangedSignal(_self, _name) return newSignal() end
local services = {
 -- Approximation only for structural CLI tests; real text metrics are tested in Studio.
 TextService={GetTextSize=function(_self,text,size,_font,bounds)
  local lines=0
  for line in (text.."\n"):gmatch("([^\n]*)\n") do lines+=math.max(1,math.ceil(#line*size*.6/math.max(1,bounds.X))) end
  return Vector2.new(bounds.X,lines*size*1.2)
 end},
	Workspace = workspace,
	ReplicatedStorage = Instance.new("Folder"),
	Lighting = Instance.new("Folder"),
	Players = { LocalPlayer = localPlayer },
	GuiService = { MenuIsOpen = false, MenuOpened = newSignal(), MenuClosed = newSignal(), TouchControlsEnabled = true },
	UserInputService = uis,
	ContextActionService = { BindActionAtPriority = function(_self, name, fn) client.actions[name] = fn end,
		UnbindAction = function(_self, name) client.actions[name] = nil end },
	RunService = { IsStudio = function() return client.studio end, Heartbeat = newSignal(),
		BindToRenderStep = function(_self, name, _priority, fn) client.renderSteps[name] = fn end },
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
	OverlapParams = OverlapParams, workspace = workspace, BoxWorld = BoxWorld, Vector2 = Vector2, game = game, UDim = UDim, UDim2 = UDim2,
	client = client, services = services, counters = counters, NumberRange = NumberRange, NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint, Font = Font }
