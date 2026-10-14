local mode = MODE
local rig = SpiderRig.new({}, {})
local body = SupportMath.bodyCFrame(Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(0, 0, -1))
for i = 1, 30 do rig:update(body, 1/60, true, false) end
if mode == "eye" then rig:setEyeView(true) end
local function f(x) return string.format("%.5f", x) end
local function v(a) return "[" .. f(a.X) .. "," .. f(a.Y) .. "," .. f(a.Z) .. "]" end
local rows = {}
for _, p in PARTS do
	if p.CFrame and p.Transparency < 0.99 and p.LocalTransparencyModifier < 1 then
		local shape = if p.Mesh then "sphere" elseif p.Shape == "PartType.Ball" then "ball" elseif p.Shape == "PartType.Cylinder" then "cyl" else "block"
		local c = p.CFrame
		table.insert(rows, string.format('{"n":"%s","s":"%s","size":%s,"p":%s,"x":%s,"y":%s,"z":%s,"c":[%s,%s,%s],"m":"%s","r":%s,"t":%s}',
			p.Name, shape, v(p.Size), v(c.p), v(c.x), v(c.y), v(c.z), f(p.Color.R), f(p.Color.G), f(p.Color.B), tostring(p.Material), f(p.Reflectance or 0), f(p.Transparency)))
	end
end
print("[" .. table.concat(rows, ",\n") .. "]")
