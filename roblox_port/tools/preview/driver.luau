local rig = SpiderRig.new({}, {}, nil, DETAIL)
local body = SupportMath.bodyCFrame(Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(0, 0, -1))
for i = 1, 30 do rig:update(body, 1/60, true, false) end
for i = 1, math.floor(IDLE_SECONDS * 60) do rig:update(body, 1/60, true, false) end
if MODE == "eye" then rig:setEyeView(true) end
local function f(x) return string.format("%.5f", x) end
local function v(a) return "[" .. f(a.X) .. "," .. f(a.Y) .. "," .. f(a.Z) .. "]" end
local rows = {}
local counts = { total = #PARTS, setae = 0, shells = 0, other = 0 }
for _, p in PARTS do
	if p.Name == "Seta" then counts.setae += 1 elseif p.Name == "FuzzShell" then counts.shells += 1 else counts.other += 1 end
	if p.CFrame and p.Transparency < 0.99 and p.LocalTransparencyModifier < 1 then
		local shape = if p.Mesh then "sphere" elseif p.Shape == "PartType.Ball" then "ball" elseif p.Shape == "PartType.Cylinder" then "cyl" else "block"
		local c = p.CFrame
		table.insert(rows, string.format('{"n":"%s","s":"%s","size":%s,"p":%s,"x":%s,"y":%s,"z":%s,"c":[%s,%s,%s],"m":"%s","r":%s,"t":%s}',
			p.Name, shape, v(p.Size), v(c.p), v(c.x), v(c.y), v(c.z), f(p.Color.R), f(p.Color.G), f(p.Color.B), tostring(p.Material), f(p.Reflectance or 0), f(p.Transparency)))
	end
end
print(string.format("parts_total=%d setae=%d shells=%d other=%d", counts.total, counts.setae, counts.shells, counts.other))
print("[" .. table.concat(rows, ",\n") .. "]")
