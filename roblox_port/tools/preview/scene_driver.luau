-- Preview-only driver for tools/preview/scene.py: builds the real sill and decor (Habitat/Scenery, as Server/Main does), the real
-- spider (Rig/SpiderRig, at the places scene.py asks for) and the real fly bodies (Client/FlyBodies) under the test shim, then prints
-- every visible part for scene.gd to draw. The shim is not Roblox: this is a layout and colour preview, never Roblox rendering.
-- scene.py puts these globals in front of the bundle: DETAIL ("full" or "low"), SUN_ELEVATION_DEG, SUN_AZIMUTH_DEG, SPIDERS (a list
-- of { name, x, z, hx, hz }), FLIES (a list of { id, x, y, z, hx, hy, hz, flying }), WASPS (a list of { id, x, y, z, hx, hz, mode, search, beat }).
local Scenery = require("../src/Shared/Habitat/Scenery")
local WorldDetail = require("../src/Client/WorldDetail")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local SpiderRig = require("../src/Shared/Rig/SpiderRig")
local FlyBodies = require("../src/Client/FlyBodies")
local WaspBody = require("../src/Client/WaspBody")

-- ---------------------------------------------------------------- the world, as Server/Main builds it
local el, az = math.rad(SUN_ELEVATION_DEG), math.rad(SUN_AZIMUTH_DEG)
local sun = Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)) -- unit vector toward the sun
local built, decor, drawn = pcall(Scenery.decor, sun)
assert(built, tostring(decor))
local sill = Scenery.sill(drawn)
decor.Parent = workspace
sill.Parent = workspace
if DETAIL == "low" then WorldDetail.apply("low", { decor }) end

-- ---------------------------------------------------------------- the spider, standing at each asked-for place
local rigs = {}
for _, s in SPIDERS do
	local rig = SpiderRig.new(workspace, sill, nil, DETAIL)
	local up = Vector3.yAxis
	local body = SupportMath.bodyCFrame(Vector3.new(s.x, 0.31, s.z), up, Vector3.new(s.hx, 0, s.hz))
	for _ = 1, 40 do rig:update(body, 1 / 60, true, false) end
	rigs[s.name] = rig
end

-- ---------------------------------------------------------------- flies
local flyFolder = Instance.new("Folder")
flyFolder.Name = "FlyHolder"
flyFolder.Parent = workspace
local bodies = FlyBodies.new(flyFolder)
local flies = {}
for _, f in FLIES do
	table.insert(flies, {
		id = f.id, position = Vector3.new(f.x, f.y, f.z), heading = Vector3.new(f.hx, f.hy, f.hz).Unit, normal = Vector3.yAxis,
		state = if f.flying then "FLYING" else "PERCHED",
		airborne = function(self: any): boolean return self.state ~= "PERCHED" end,
	})
end
bodies:draw(flies, 0.37)

-- ---------------------------------------------------------------- wasps (scene.py's WASPS: id, x, y, z, hx, hz, mode, search, beat)
local waspHolder = Instance.new("Folder")
waspHolder.Name = "WaspHolder"
waspHolder.Parent = workspace
for _, w in WASPS do
	local body = WaspBody.new(waspHolder)
	body.folder.Name = w.id
	body:draw({ position = Vector3.new(w.x, w.y, w.z), heading = Vector3.new(w.hx, 0, w.hz).Unit, mode = w.mode, search = w.search, visible = true }, w.beat)
end

-- ---------------------------------------------------------------- the dump
local function f5(x: number): string return string.format("%.5f", x) end
local function vec(a: any): string
	if a == nil then error("a part has no size or position") end
	return "[" .. f5(a.X) .. "," .. f5(a.Y) .. "," .. f5(a.Z) .. "]"
end
local function pathOf(o: any): string
	local names = {}
	local p = o
	while p and p ~= workspace do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, "/")
end
local function dump(root: any, group: string, rows: { string })
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and ((p.Transparency or 0) < 0.995 or p:GetAttribute("UVOpacity") ~= nil) then
			local c = p.CFrame
			if c == nil or p.Size == nil then error("part " .. pathOf(p) .. " has no CFrame or Size") end
			for _, axis in { "Position", "RightVector", "UpVector", "ZVector" } do
				if (c :: any)[axis] == nil then error("part " .. pathOf(p) .. " CFrame has no " .. axis) end
			end
			local mesh = nil
			for _, ch in p:GetChildren() do
				if ch.ClassName == "SpecialMesh" then mesh = ch end
			end
			local color = p.Color or Color3.fromRGB(163, 162, 165)
			local shape = if p.Shape then p.Shape.Name else "Block"
			local meshJson = ""
			if mesh then
				meshJson = string.format(',"mesh":"%s","ms":%s', if mesh.MeshType then mesh.MeshType.Name else "Brick", vec(mesh.Scale or Vector3.one))
			end
			local uv = p:GetAttribute("UVOpacity")
			table.insert(rows, string.format(
				'{"g":"%s","n":"%s","path":"%s","k":"%s","size":%s,"p":%s,"x":%s,"y":%s,"z":%s,"c":[%s,%s,%s],"m":"%s","r":%s,"t":%s,"cs":%s,"fo":%s,"uv":%s%s}',
				group, p.Name, pathOf(p), shape, vec(p.Size), vec(c.Position), vec(c.RightVector), vec(c.UpVector), vec(c.ZVector),
				f5(color.R), f5(color.G), f5(color.B), if p.Material then p.Material.Name else "Plastic", f5(p.Reflectance or 0), f5(p.Transparency or 0),
				tostring(p.CastShadow ~= false), tostring(p:GetAttribute("FullOnly") == true), if typeof(uv) == "number" then f5(uv) else "null", meshJson))
		end
	end
end
local rows: { string } = {}
dump(sill, "world", rows)
dump(decor, "world", rows)
local counts = { world = #rows }
for name, rig in rigs do
	local before = #rows
	dump(rig.model, name, rows)
	counts[name] = #rows - before
end
local before = #rows
dump(flyFolder, "flies", rows)
counts.flies = #rows - before
before = #rows
dump(waspHolder, "wasps", rows)
counts.wasps = #rows - before
local keys = {}
for k in counts do table.insert(keys, k) end
table.sort(keys)
local summary = {}
for _, k in keys do table.insert(summary, k .. "=" .. counts[k]) end
print("parts " .. table.concat(summary, " ") .. " total=" .. #rows)
print("[" .. table.concat(rows, ",\n") .. "]")
