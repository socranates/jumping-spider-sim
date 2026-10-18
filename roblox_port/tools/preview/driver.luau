local rig = SpiderRig.new({}, {}, if APPEARANCE ~= "" then APPEARANCE else nil, DETAIL)
local body = SupportMath.bodyCFrame(Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(0, 0, -1))
for i = 1, 30 do rig:update(body, 1/60, true, false) end
if DANCE_T >= 0 then
	rig.dance = PEACOCKDANCE.rawPose(DANCE_T, false)
	for i = 1, 4 do rig:update(body, 1/60, true, false) end
end
if ANT_MODE ~= "" then
	-- The ant-mimicking spider: standing with legs I up (or the display pose), or walking toward the origin at 6 studs a second.
	local pose = ANTMIMICPOSE.new()
	local dt = 1 / 60
	if ANT_MODE == "walk" then
		local steps = math.floor(ANT_SECONDS * 60 + 0.5)
		for i = 1, steps do
			local z = (steps - i) * 6 * dt
			local b = SupportMath.bodyCFrame(Vector3.new(0, 0.31, z), Vector3.yAxis, Vector3.new(0, 0, -1))
			rig.ant = pose:step(dt, true, true, 6 * dt)
			rig:update(b, dt, true, true)
		end
	else
		if ANT_MODE == "display" then pose:start(true, false) end
		for i = 1, math.floor(ANT_SECONDS * 60 + 0.5) do
			rig.ant = pose:step(dt, true, false, 0)
			rig:update(body, dt, true, false)
		end
	end
end
for i = 1, math.floor(IDLE_SECONDS * 60) do rig:update(body, 1/60, true, false) end
if HANG_MODE ~= "" then
	-- The spider on its dragline (ROBLOX-59, ROBLOX-86): the collider is HANG_HEIGHT studs up, the line leaves its spinneret toward a point a little off
	-- the vertical (lean 4 degrees toward +X, 2 toward +Z), and the rig is drawn suspended (grounded = false) for HANG_SECONDS. "drop": hanging from the
	-- first frame (the sway starts with it). "climb": the body also rises along the line at 0.6 studs a second (the rig tells the climb from that).
	local lineUp = Vector3.new(0.07, 1, 0.035).Unit
	local steps = math.max(1, math.floor(HANG_SECONDS * 60 + 0.5))
	rig.hangDirection = lineUp
	for i = 1, steps do
		local rise = if HANG_MODE == "climb" then ((i - steps) / 60) * 0.6 else 0 -- (it ends at HANG_HEIGHT)
		local b = SupportMath.bodyCFrame(Vector3.new(0, HANG_HEIGHT, 0) + lineUp * rise, Vector3.yAxis, Vector3.new(0, 0, -1))
		rig:update(b, 1/60, false, false)
	end
	-- the dragline itself, so the pose reads against it: a thin pale strand from the spinneret up the line
	local top = rig._spinneret
	local strand = Instance.new("Part")
	strand.Name = "Silk"; strand.Size = Vector3.new(0.012, 1.6, 0.012); strand.Color = Color3.new(0.93, 0.93, 0.9)
	strand.Material = "Enum.Material.SmoothPlastic"; strand.Reflectance = 0
	local mid = top + lineUp * 0.8
	local side = lineUp:Cross(Vector3.new(0, 0, 1)).Unit
	strand.CFrame = CFrame.fromMatrix(mid, side, lineUp, side:Cross(lineUp))
end
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
