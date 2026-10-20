-- Fly checks: the drawn house fly (Client/FlyBodies, every number in Data/FlyLook) under the shim (tests/shim.luau): the part budget,
-- parts that never collide and no ray ever sees, the body's proportions and colours, six two-segment legs standing on the surface,
-- wings folded back in a shallow V, a soft blur instead of flaps in flight, a shadow oval only while the fly stands, and where the
-- parts land on a floor, a wall and a ceiling. Says nothing about how the fly LOOKS in Roblox (tools/preview/scene.py draws it, with
-- the shim, in Godot; only Studio shows the real thing).
local FlyBodies = require("../src/Client/FlyBodies")
local FlyLook = require("../src/Shared/Data/FlyLook")
local Fly = require("../src/Shared/Prey/Fly")
local Species = require("../src/Shared/Data/Species")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL flies: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local function colour(p: any, hex: string): boolean
	local want = Color3.fromHex(hex)
	return near(p.Color.R, want.R, 1e-6) and near(p.Color.G, want.G, 1e-6) and near(p.Color.B, want.B, 1e-6)
end
local function brightness(p: any): number return p.Color.R * 0.3 + p.Color.G * 0.59 + p.Color.B * 0.11 end
local function finite(v: Vector3): boolean return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6 end

local profile = Species.fly_like_prototype
local HOVER = profile.body.hover_wu

-- A fly as the prey simulation hands it over: the real Fly methods (alive, airborne) on a table with the fields the drawing reads.
local function fly(id: string, state: string, position: Vector3, heading: Vector3, normal: Vector3): any
	return setmetatable({ id = id, state = state, position = position, heading = heading, normal = normal }, { __index = Fly })
end
-- One fly standing on a floor at the origin, nose toward -Z: the body frame is the world frame, moved up by the hover.
local ORIGIN = Vector3.new(0, HOVER, 0)
local function standing(): any return fly("f1", "PERCHED", ORIGIN, -Vector3.zAxis, Vector3.yAxis) end

local function named(rig: any, name: string): any
	for _, p in rig.parts do if p.Name == name then return p end end
	error("no part " .. name)
end
-- How far a part reaches from its centre along the unit vector `dir`: an ellipsoid's support, or a rod's (long along its axis X, round across).
local function reach(p: any, dir: Vector3): number
	local c = p.CFrame
	local x, y, z = c.RightVector:Dot(dir), c.UpVector:Dot(dir), c.LookVector:Dot(dir)
	if p.Shape == Enum.PartType.Cylinder then
		return math.abs(x) * p.Size.X / 2 + (p.Size.Y / 2) * math.sqrt(math.max(0, 1 - x * x))
	end
	return math.sqrt((x * p.Size.X / 2) ^ 2 + (y * p.Size.Y / 2) ^ 2 + (z * p.Size.Z / 2) ^ 2)
end
-- The two ends of a rod, and the one that lies farther along `dir`.
local function ends(p: any): (Vector3, Vector3)
	local axis = p.CFrame.RightVector * (p.Size.X / 2)
	return p.Position + axis, p.Position - axis
end
local function endAlong(p: any, dir: Vector3): Vector3
	local a, b = ends(p)
	return if a:Dot(dir) >= b:Dot(dir) then a else b
end
local SIDES, PAIRS = { "Left", "Right" }, { "Front", "Middle", "Hind" }

-- ---------------------------------------------------------------- the look data
check(FlyLook.hover == HOVER, "the fly hovers where the prey profile says (body.hover_wu)")
for name, hex in FlyLook.colors do
	check(string.match(hex, "^%x%x%x%x%x%x$") ~= nil, `colour {name} is six hex digits`)
end
check(FlyLook.colors.eye == "8a2f1c" and FlyLook.colors.thorax == "5b5d58" and FlyLook.colors.wing == "d8e4ea" and FlyLook.colors.film == "f0c8ff",
	"red-brown eyes, a grey thorax, glass wings and a faint iridescent film")

-- ---------------------------------------------------------------- the parts
local holder = Instance.new("Folder")
holder.Name = "Holder"
holder.Parent = workspace
local bodies = FlyBodies.new(holder)
check(bodies.folder.Name == "Flies" and bodies.folder.Parent == holder, "the flies live in one folder named Flies")
local rig = bodies:spawn("f1")
local count = #rig.parts
check(count >= 20 and count <= 40, `a fly is {count} parts (at most about 40)`)
check(#rig.folder:GetChildren() == count and rig.folder.Name == "f1" and rig.folder.Parent == bodies.folder, "its parts are all in the folder named for the fly")
local names, unique = {}, 0
for _, p in rig.parts do
	if not names[p.Name] then names[p.Name] = true; unique += 1 end
end
check(unique == count, "no two parts of a fly share a name")
local solid, rods, balls, ellipsoids, sized = 0, 0, 0, 0, 0
for _, p in rig.parts do
	if p:IsA("BasePart") and p.Anchored == true and p.CanCollide == false and p.CanQuery == false and p.CanTouch == false and p.CastShadow == false then solid += 1 end
	if p.Shape == Enum.PartType.Ball then balls += 1 end
	if p.Shape == Enum.PartType.Cylinder then
		rods += 1
		if near(p.Size.Y, p.Size.Z, 1e-9) and p.Size.X > p.Size.Y then sized += 1 end
	else
		local mesh = p:FindFirstChildWhichIsA("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then ellipsoids += 1 end
	end
end
check(solid == count, "every part is anchored, never collides, is never touched, is never seen by a ray and casts no shadow")
check(balls == 0, "no Ball part (Roblox forces a Ball to be a sphere): the ellipsoids are Parts with a sphere mesh")
check(rods + ellipsoids == count and rods == sized, `{rods} rods (Cylinders along X, round, longer than wide) and {ellipsoids} ellipsoids make all {count} parts`)
local sane = 0
for _, p in rig.parts do
	if finite(p.Size) and p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0 and finite(p.Position) then sane += 1 end
end
check(sane == count, "every part has a real size and place")
for _, name in { "Thorax", "Abdomen", "Head", "EyeL", "EyeR", "Face", "Proboscis", "ThoraxStripe1", "ThoraxStripe2", "ThoraxStripe3", "ThoraxStripe4", "DorsalStripe",
	"LeftFrontFemur", "LeftFrontTibia", "RightMiddleFemur", "RightMiddleTibia", "LeftHindFemur", "RightHindTibia", "LeftWing", "RightWing", "LeftVein", "RightVein", "LeftFilm", "RightFilm", "Shadow" } do
	check(names[name] == true, "the fly has a part named " .. name)
end
-- a fly the engine cannot see: a ray straight through it meets nothing; the same ray meets a part that is made queryable
do
	local params = RaycastParams.new()
	local from, down = ORIGIN + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0)
	rig.parts[1].CFrame = CFrame.new(ORIGIN)
	check(workspace:Raycast(from, down, params) == nil and #workspace:GetPartBoundsInRadius(ORIGIN, 0.5, params) == 0, "no ray or overlap query meets a fly")
	rig.parts[1].CanQuery = true
	check(workspace:Raycast(from, down, params) ~= nil, "(the probe does see a queryable part)")
	rig.parts[1].CanQuery = false
end

-- ---------------------------------------------------------------- the body, standing
bodies:draw({ standing() }, 0)
local thorax, abdomen, head = named(rig, "Thorax"), named(rig, "Abdomen"), named(rig, "Head")
local eyeL, eyeR, face, proboscis = named(rig, "EyeL"), named(rig, "EyeR"), named(rig, "Face"), named(rig, "Proboscis")
local length = (abdomen.Position.Z + abdomen.Size.Z / 2) - (head.Position.Z - head.Size.Z / 2)
check(near(length, profile.body.length_wu, 0.05), `the body is about {profile.body.length_wu} cm long (head to abdomen: {string.format("%.3f", length)})`)
check(thorax.Position.Z > head.Position.Z and abdomen.Position.Z > thorax.Position.Z, "head, thorax, abdomen from front to back (-Z is forward)")
check(colour(eyeL, "8a2f1c") and colour(eyeR, "8a2f1c") and eyeL.Reflectance > 0 and eyeR.Reflectance > 0, "two glossy red-brown compound eyes")
check(near(eyeL.Position.X, -eyeR.Position.X, 1e-9) and eyeL.Position.Y == eyeR.Position.Y and eyeL.Position.Z == eyeR.Position.Z and eyeL.Position.X < 0, "the eyes mirror each other")
check(eyeR.Position.X + eyeR.Size.X / 2 > head.Size.X / 2 and eyeR.Size.Y >= head.Size.Y and eyeR.Position.Z < thorax.Position.Z, "the eyes are big: wider than the head they sit on, in front of the thorax")
check(face.Position.Z < head.Position.Z and brightness(face) > brightness(head) * 2 and brightness(face) > brightness(eyeL) * 2 and near(face.Position.X, 0, 1e-9)
	and face.Size.X <= 2 * (eyeR.Position.X - eyeR.Size.X / 2) + 0.01, "a pale silver stripe on the face, no wider than the gap between the eyes")
check(proboscis.Position.Z < head.Position.Z and proboscis.Position.Y < head.Position.Y and proboscis.Size.Z < 0.2 and brightness(proboscis) < 0.2, "a short dark proboscis, forward and down")
check(colour(thorax, "5b5d58") and thorax.Size.Y > abdomen.Size.Y and thorax.Size.Z < abdomen.Size.Z, "a grey thorax, taller than the abdomen and shorter")
check(colour(abdomen, "7b7266") and abdomen.Size.Z > thorax.Size.Z, "a grey-brown abdomen")
local stripeX = {}
for i = 1, 4 do
	local s = named(rig, "ThoraxStripe" .. i)
	table.insert(stripeX, s.Position.X)
	local across = (s.Position.X - thorax.Position.X) / (thorax.Size.X / 2) -- where across the thorax, -1 to 1
	local share = math.sqrt(1 - across * across)
	check(colour(s, "23211e") and s.Size.X <= 0.03 and math.abs(across) < 1 and brightness(s) < brightness(thorax) * 0.5, `thorax stripe {i} is a thin dark slice across the thorax`)
	check(s.Size.Y > thorax.Size.Y * share and s.Size.Y < thorax.Size.Y * share + 0.01 and s.Size.Z > thorax.Size.Z * share and s.Size.Z < thorax.Size.Z * share + 0.01
		and s.Position.Y == thorax.Position.Y and s.Position.Z == thorax.Position.Z, `thorax stripe {i} follows the thorax's curve, a hair proud of it`)
end
check(stripeX[1] < stripeX[2] and stripeX[2] < stripeX[3] and stripeX[3] < stripeX[4] and near(stripeX[1], -stripeX[4], 1e-9) and near(stripeX[2], -stripeX[3], 1e-9)
	and near(stripeX[4] - stripeX[3], stripeX[2] - stripeX[1], 0.02), "four stripes in a mirrored row")
local dorsal = named(rig, "DorsalStripe")
check(colour(dorsal, "35302a") and brightness(dorsal) < brightness(abdomen) and near(dorsal.Position.X, 0, 1e-9) and dorsal.Position.Z == abdomen.Position.Z
	and dorsal.Size.Y > abdomen.Size.Y and dorsal.Size.X < abdomen.Size.X / 3, "a darker stripe down the middle of the abdomen's back")
local bristles = 0
for _, p in rig.parts do
	if string.sub(p.Name, 1, 7) == "Bristle" then
		bristles += 1
		check(p.Shape == Enum.PartType.Cylinder and p.Size.Y <= 0.01 and p.Size.X < 0.12 and brightness(p) < 0.2, p.Name .. " is a tiny dark bristle")
	end
end
check(bristles >= 8 and bristles % 2 == 0, `{bristles} bristles, in mirrored pairs`)

-- ---------------------------------------------------------------- the legs, standing
local restFootOut: { [string]: number } = {}
local feet: { Vector3 } = {}
local legCount = 0
for _, side in SIDES do
	for _, pair in PAIRS do
		local femur, tibia = named(rig, side .. pair .. "Femur"), named(rig, side .. pair .. "Tibia")
		legCount += 1
		check(femur.Shape == Enum.PartType.Cylinder and tibia.Shape == Enum.PartType.Cylinder and femur.Size.Y > tibia.Size.Y and tibia.Size.Y >= 0.012, `{side} {pair} leg: a thicker femur and a thinner tibia`)
		check(femur.Size.X >= 0.09 and femur.Size.X <= 0.25 and tibia.Size.X >= 0.09 and tibia.Size.X <= 0.25, `{side} {pair} leg: segments about a tenth to a quarter of a stud`)
		check(brightness(tibia) < 0.2 and brightness(femur) < 0.25, `{side} {pair} leg is dark`)
		local fa, fb = ends(femur)
		local ta, tb = ends(tibia)
		local gap = math.min((fa - ta).Magnitude, (fa - tb).Magnitude, (fb - ta).Magnitude, (fb - tb).Magnitude)
		check(gap < 0.03, `{side} {pair} leg: femur and tibia meet at the knee`)
		local foot = endAlong(tibia, -Vector3.yAxis)
		table.insert(feet, foot)
		restFootOut[side .. pair] = math.abs(foot.X)
		check(math.abs(foot.X) > 0.15 and (foot.X < 0) == (side == "Left"), `{side} {pair} foot is out to its own side`)
	end
end
check(legCount == 6, "six legs")
local lowest, highest = math.huge, -math.huge
for _, foot in feet do
	lowest = math.min(lowest, foot.Y)
	highest = math.max(highest, foot.Y)
end
check(near(lowest, 0, 0.01) and highest - lowest < 0.01, `the six feet stand on the surface (lowest {string.format("%.4f", lowest)}, highest {string.format("%.4f", highest)}; the surface is y = 0)`)
local below = 0
for _, p in rig.parts do
	if p.Name ~= "Shadow" and p.Position.Y - reach(p, Vector3.yAxis) < -0.01 then below += 1 end
end
check(below == 0, "no part dips into the surface")
check(named(rig, "LeftFrontTibia").Position.Z < thorax.Position.Z and named(rig, "LeftHindTibia").Position.Z > thorax.Position.Z
	and near(named(rig, "LeftFrontTibia").Position.Z, named(rig, "RightFrontTibia").Position.Z, 1e-9)
	and near(named(rig, "LeftHindTibia").Position.Z, named(rig, "RightHindTibia").Position.Z, 1e-9), "front legs forward, hind legs back, left and right alike")

-- ---------------------------------------------------------------- the wings, folded
local wingL, wingR = named(rig, "LeftWing"), named(rig, "RightWing")
local veinL, veinR, filmL, filmR = named(rig, "LeftVein"), named(rig, "RightVein"), named(rig, "LeftFilm"), named(rig, "RightFilm")
for _, wing in { wingL, wingR } do
	check(wing.Material == Enum.Material.Glass and colour(wing, "d8e4ea") and near(wing.Transparency, 0.55, 0.02) and wing.Size.Y <= 0.01, `{wing.Name} is thin glass, see-through`)
	check(near(wing.Size.Z, 0.6, 0.05) and wing.Size.X >= 0.15 and wing.Size.X <= 0.3, `{wing.Name} is about as long as the body and a third as wide`)
end
local axisL, axisR = -wingL.CFrame.LookVector, -wingR.CFrame.LookVector -- the wings' long axes (local +Z), root to tip
check(axisL.Z > 0.95 and axisR.Z > 0.95, "the wings point back along the body")
check(axisL.X < 0 and axisR.X > 0 and near(axisL.X, -axisR.X, 1e-9) and near(axisL.Y, axisR.Y, 1e-9), "folded in a V, mirrored")
local splay = math.deg(math.acos(math.clamp(axisL:Dot(axisR), -1, 1)))
check(splay > 8 and splay < 30, `the V is shallow ({string.format("%.1f", splay)} degrees between the wings)`)
check(wingL.Position.Y - abdomen.Position.Y > abdomen.Size.Y / 2 and wingR.Position.Y - abdomen.Position.Y > abdomen.Size.Y / 2 and axisL.Y > 0, "the wings lie over the back, clear of the abdomen")
check(wingL.Position.Z > thorax.Position.Z and wingL.Position.Z + wingL.Size.Z / 2 > abdomen.Position.Z + abdomen.Size.Z / 2, "from the thorax back past the end of the abdomen")
for _, set in { { wingL, veinL, filmL }, { wingR, veinR, filmR } } do
	local wing, vein, film = set[1], set[2], set[3]
	local inWing = wing.CFrame:PointToObjectSpace(vein.Position) -- the vein's middle in the wing's own frame
	local outward = Vector3.new(wing.Position.X, 0, 0).Unit
	check(vein.Shape == Enum.PartType.Cylinder and colour(vein, "56463a") and vein.Size.Y <= 0.012 and near(vein.Transparency, 0.2, 0.01) and vein.Size.X > wing.Size.Z * 0.5, `{vein.Name} is a long thin dark rod`)
	check(math.abs(vein.CFrame.RightVector:Dot(-wing.CFrame.LookVector)) > 0.999 and math.abs(inWing.X) < wing.Size.X / 2 and inWing.Y > 0 and inWing.Y < 0.02
		and (vein.Position - wing.Position):Dot(outward) > 0.03, `{vein.Name} runs the length of its wing, on the upper face, near the outer front edge`)
	check(colour(film, "f0c8ff") and film.Transparency > wing.Transparency and film.Transparency >= 0.7 and film.Transparency < 1, `{film.Name} is a faint pink-violet film`)
	check(near(film.Size.Z, wing.Size.Z, 0.01) and near(film.Size.X, wing.Size.X, 0.01) and film.Position.Y > wing.Position.Y, `{film.Name} lies just above its glass`)
end
local shadow = named(rig, "Shadow")
check(shadow.Size.Y <= 0.005 and near(shadow.Position.Y - shadow.Size.Y / 2, 0.003, 0.0015) and shadow.Transparency < 1 and shadow.Transparency > 0.5, "a soft dark oval just above the surface under the fly")
check(shadow.Size.Z > thorax.Size.Z + 0.2 and shadow.Size.X < 0.5, "the oval is about the size of the body")

-- ---------------------------------------------------------------- in flight
local rest: { [string]: { size: Vector3, transparency: number, position: Vector3 } } = {}
for _, p in rig.parts do rest[p.Name] = { size = p.Size, transparency = p.Transparency, position = p.Position } end
local air = fly("f1", "FLEE", ORIGIN, -Vector3.zAxis, Vector3.yAxis)
bodies:draw({ air }, 0)
check(rig.flying == true, "an airborne fly takes its flying pose")
for _, wing in { wingL, wingR } do
	check(near(wing.Transparency, FlyLook.wing.fan.transparency, 1e-9) and wing.Transparency >= 0.7 and wing.Transparency < 1, `{wing.Name} is a soft, see-through blur in flight`)
	check(wing.Size.X > wing.Size.Z * 0.9 and wing.Size.Y <= 0.01, `{wing.Name} blur is a flat fan reaching out sideways`)
	check(math.abs(wing.Position.X) > math.abs(rest[wing.Name].position.X) + 0.05, `{wing.Name} blur is out at its side of the body`)
end
for _, film in { filmL, filmR } do
	check(near(film.Transparency, FlyLook.wing.fan.film.transparency, 1e-9) and film.Transparency > wingL.Transparency and film.Size.X > wingL.Size.X, `{film.Name} is a fainter blur out to the tips`)
end
check(veinL.Transparency == 1 and veinR.Transparency == 1 and shadow.Transparency == 1, "no veins and no shadow oval in the air")
check(wingL.Position.X < 0 and wingR.Position.X > 0 and near(wingL.Position.X, -wingR.Position.X, 1e-9) and near(wingL.Position.Y, wingR.Position.Y, 1e-9) and near(wingL.Position.Z, wingR.Position.Z, 1e-9), "the two blurs mirror each other")
local tucked = 0
for _, side in SIDES do
	for _, pair in PAIRS do
		local foot = endAlong(named(rig, side .. pair .. "Tibia"), -Vector3.yAxis)
		if math.abs(foot.X) > 0.02 and math.abs(foot.X) < restFootOut[side .. pair] * 0.7 and (foot.X < 0) == (side == "Left") then tucked += 1 end
	end
end
check(tucked == 6, "in flight the legs are drawn in toward the body")
for _, p in rig.parts do
	local still = rest[p.Name]
	if string.sub(p.Name, 1, 7) == "Thorax" or p.Name == "Abdomen" or p.Name == "Head" or p.Name == "EyeL" or p.Name == "EyeR" then
		check(p.Size == still.size and p.Position == still.position, p.Name .. " is the same in the air and on the surface")
	end
end
-- the blur trembles a little, never flaps: the fan's tilt stays within a tenth of a radian and changes by under 2 degrees from one frame (60 a
-- second) to the next, so nothing strobes; the body does not move with it
local widest, worstStep, thoraxMoves = 0, 0, 0
local tilt0 = wingR.CFrame.UpVector
local lastTilt = tilt0
local thoraxAt = thorax.Position
for step = 1, 120 do
	bodies:draw({ air }, step / 60)
	local tilt = wingR.CFrame.UpVector
	widest = math.max(widest, math.acos(math.clamp(tilt:Dot(tilt0), -1, 1)))
	worstStep = math.max(worstStep, math.acos(math.clamp(tilt:Dot(lastTilt), -1, 1)))
	lastTilt = tilt
	thoraxMoves = math.max(thoraxMoves, (thorax.Position - thoraxAt).Magnitude)
end
check(widest > 0.001 and widest <= 0.1, `the blur trembles by at most a tenth of a radian (seen {string.format("%.3f", widest)})`)
check(worstStep > 0 and worstStep < 0.03, `from one frame to the next the blur changes very little ({string.format("%.4f", worstStep)} rad at most: no strobing flaps)`)
check(thoraxMoves == 0, "and the body stays where it is")
-- a fly grabbed by the spider still buzzes; landing and standing again bring the wings back
bodies:draw({ fly("f1", "CAPTURED", ORIGIN, -Vector3.zAxis, Vector3.yAxis) }, 0)
check(rig.flying == true and near(wingL.Transparency, FlyLook.wing.fan.transparency, 1e-9), "a captured fly is drawn flying (its wings buzz)")
for _, state in { "TAKEOFF", "SEEK_PERCH" } do
	bodies:draw({ fly("f1", state, ORIGIN, -Vector3.zAxis, Vector3.yAxis) }, 0)
	check(rig.flying == true, state .. " is flying")
end
for _, state in { "PERCHED", "ALERT" } do
	bodies:draw({ fly("f1", "FLEE", ORIGIN, -Vector3.zAxis, Vector3.yAxis) }, 0)
	bodies:draw({ fly("f1", state, ORIGIN, -Vector3.zAxis, Vector3.yAxis) }, 0)
	check(rig.flying == false, state .. " is standing")
	local same = 0
	for _, p in rig.parts do
		local before = rest[p.Name]
		if p.Size == before.size and p.Transparency == before.transparency and (p.Position - before.position).Magnitude < 1e-9 then same += 1 end
	end
	check(same == count, `after {state} again every part is exactly as it was before the flight`)
end

-- ---------------------------------------------------------------- where the parts land
do
	local floorFly = fly("f1", "PERCHED", Vector3.new(3, HOVER, -2), Vector3.new(1, 0, 1), Vector3.yAxis)
	bodies:draw({ floorFly }, 0)
	local heading = floorFly.heading.Unit
	check((head.Position - thorax.Position):Dot(heading) > 0.15 and (abdomen.Position - thorax.Position):Dot(heading) < -0.1, "on a floor the head points the way the fly heads")
	check(near((thorax.Position - floorFly.position):Dot(Vector3.yAxis), 0.02, 1e-9), "the thorax sits a little above the fly's point")
	local lowestFoot = math.huge
	for _, side in SIDES do
		for _, pair in PAIRS do lowestFoot = math.min(lowestFoot, endAlong(named(rig, side .. pair .. "Tibia"), -Vector3.yAxis).Y) end
	end
	check(near(lowestFoot, 0, 0.01), "on a floor the feet reach y = 0")
	check(near(shadow.Position.Y - shadow.Size.Y / 2, 0.003, 0.0015), "and the shadow oval lies on it")
	local sideways = eyeR.Position - eyeL.Position
	check(near(sideways:Dot(heading), 0, 1e-6) and near(sideways:Dot(Vector3.yAxis), 0, 1e-6) and sideways.Magnitude > 0.1, "the eyes are side by side across the heading")
	check((wingL.Position - thorax.Position):Dot(Vector3.yAxis) > 0.05, "the wings are on the fly's back")

	local wallNormal = Vector3.xAxis -- a wall whose surface is x = 0, the fly walking up it
	bodies:draw({ fly("f1", "PERCHED", Vector3.new(HOVER, 5, 1), Vector3.yAxis, wallNormal) }, 0)
	check((head.Position - thorax.Position):Dot(Vector3.yAxis) > 0.15, "on a wall the head points up when the fly walks up")
	check((wingL.Position - thorax.Position):Dot(wallNormal) > 0.05 and (wingR.Position - thorax.Position):Dot(wallNormal) > 0.05, "its back is away from the wall")
	local nearest = math.huge
	for _, side in SIDES do
		for _, pair in PAIRS do nearest = math.min(nearest, endAlong(named(rig, side .. pair .. "Tibia"), -wallNormal):Dot(wallNormal)) end
	end
	check(near(nearest, 0, 0.01), "the feet stand on the wall")

	bodies:draw({ fly("f1", "PERCHED", Vector3.new(0, 10 - HOVER, 0), Vector3.xAxis, -Vector3.yAxis) }, 0)
	check((wingL.Position - thorax.Position):Dot(-Vector3.yAxis) > 0.05 and thorax.Position.Y < 10 and thorax.Position.Y > 9, "under a ceiling it hangs with its back to the ceiling's normal")
	local highestFoot = -math.huge
	for _, side in SIDES do
		for _, pair in PAIRS do highestFoot = math.max(highestFoot, endAlong(named(rig, side .. pair .. "Tibia"), Vector3.yAxis).Y) end
	end
	check(near(highestFoot, 10, 0.01), "and its feet reach the ceiling")
end

-- ---------------------------------------------------------------- the back is up in the air
do
	-- a fly that took off from a wall still carries the wall's normal: in the air it keeps its back to the sky anyway
	local gone = fly("f1", "FLEE", Vector3.new(2, 4, 1), Vector3.xAxis, Vector3.zAxis)
	bodies:draw({ gone }, 0)
	check((wingL.Position - thorax.Position):Dot(Vector3.yAxis) > 0.05 and (wingR.Position - thorax.Position):Dot(Vector3.yAxis) > 0.05, "a fly in the air has its back up, whatever surface it left")
	check((head.Position - thorax.Position):Dot(Vector3.xAxis) > 0.15, "and flies head first")
	local belly = 0
	for _, side in SIDES do
		for _, pair in PAIRS do
			if (endAlong(named(rig, side .. pair .. "Tibia"), -Vector3.yAxis) - thorax.Position).Y < -0.1 then belly += 1 end
		end
	end
	check(belly == 6, "its legs hang below it")
	-- a fly the spider holds follows the spider's grip, not the sky
	bodies:draw({ fly("f1", "CAPTURED", Vector3.new(2, 4, 1), Vector3.yAxis, Vector3.xAxis) }, 0)
	check((wingL.Position - thorax.Position):Dot(Vector3.xAxis) > 0.05 and (head.Position - thorax.Position):Dot(Vector3.yAxis) > 0.15, "a held fly's back is along the normal it is given")
end

-- ---------------------------------------------------------------- awkward headings, many flies, one move
do
	local bad = 0
	for _, heading in { Vector3.yAxis, -Vector3.yAxis, Vector3.new(0, 1e-5, 1), Vector3.new(0, 1, 1e-4), Vector3.new(0.02, 1, 0.02) } do
		bodies:draw({ fly("f1", "PERCHED", ORIGIN, heading, Vector3.yAxis), fly("f2", "FLEE", ORIGIN, heading, Vector3.yAxis) }, 0.5)
		for _, id in { "f1", "f2" } do
			for _, p in bodies.rigs[id].parts do
				local c = p.CFrame
				if not (finite(p.Position) and finite(c.RightVector) and finite(c.UpVector) and finite(c.LookVector)) then bad += 1 end
			end
		end
	end
	check(bad == 0, "a heading along the surface normal (and nearly along it) gives no NaN in any frame")
	bodies:draw({}, 0)
	check(#bodies.folder:GetChildren() == 0, "no flies: nothing left")

	local moved, calls = 0, 0
	local original = workspace.BulkMoveTo
	workspace.BulkMoveTo = function(self: any, parts: { any }, frames: { any }, mode: any)
		calls += 1
		moved += #parts
		check(#parts == #frames, "BulkMoveTo gets one frame for each part")
		original(self, parts, frames, mode)
	end
	local three = {
		fly("a", "PERCHED", Vector3.new(0, HOVER, 0), Vector3.xAxis, Vector3.yAxis),
		fly("b", "FLEE", Vector3.new(4, 3, 1), Vector3.new(1, 0.3, 0), Vector3.yAxis),
		fly("c", "PERCHED", Vector3.new(-3, HOVER, 5), Vector3.zAxis, Vector3.yAxis),
	}
	bodies:draw(three, 0.25)
	check(calls == 1 and moved == 3 * count, `all the flies' parts move in one BulkMoveTo ({moved} parts, {calls} call)`)
	check(#bodies.folder:GetChildren() == 3 and bodies.rigs.a.folder.Name == "a" and bodies.rigs.b.flying == true and bodies.rigs.a.flying == false, "each fly has its own folder and its own pose")
	check(bodies.rigs.a.parts[1] ~= bodies.rigs.b.parts[1] and (bodies.rigs.a.parts[1].Position - bodies.rigs.c.parts[1].Position).Magnitude > 1, "and its own parts, each where its fly is")
	local before = #bodies.folder:GetDescendants()
	bodies:draw(three, 0.3)
	check(#bodies.folder:GetDescendants() == before and calls == 2, "drawing again adds nothing")
	local first = bodies.rigs.a.folder
	bodies:draw({ three[2], three[3] }, 0.35)
	check(#bodies.folder:GetChildren() == 2 and bodies.rigs.a == nil and first.Parent == nil and bodies.rigs.b ~= nil, "a fly that is gone loses its parts")
	bodies:draw({}, 0.4)
	check(calls == 3 and #bodies.folder:GetChildren() == 0 and next(bodies.rigs) == nil, "no flies, no BulkMoveTo, no parts")
	workspace.BulkMoveTo = original
	local total = 4 * count -- PreyDirector.engine(sill, Species.fly_like_prototype, 914, 4): four flies at once
	check(total <= 200, `four flies are {total} parts`)
end

do
 local Species=require("../src/Shared/Data/Species")
 local bodies=FlyBodies.new(workspace)
 local small=fly("fruit","PERCHED",Vector3.new(0,HOVER,0),Vector3.xAxis,Vector3.yAxis)
 small.profile=Species.fruit_fly_prototype
 bodies:draw({small},0)
 local rig=bodies.rigs.fruit
 check(rig.scale==.6,"fruit fly has its own smaller scale")
 for i,p in rig.parts do
  check((p.Size-bodies.template.specs[i].rest.size*.6).Magnitude<1e-6,"fruit parts scaled")
 end
 local first=rig.parts[1]
 check(colour(first,"b28441"),"fruit thorax is warm tan")
 small.profile=Species.fly_like_prototype
 bodies:draw({small},0)
 check(rig.scale==1 and (first.Size-bodies.template.specs[1].rest.size).Magnitude<1e-6,"restored identity returns original size")
 bodies:draw({},0)
end
-- ---------------------------------------------------------------- the bed's prey (ROBLOX-96): the gnat and the aphid under the fly's budget
do
 local Species=require("../src/Shared/Data/Species")
 local bodies=FlyBodies.new(workspace)
 local g=fly("gnat","PERCHED",Vector3.new(0,HOVER,0),-Vector3.zAxis,Vector3.yAxis);g.profile=Species.fungus_gnat_prototype
 local a=fly("aphid","PERCHED",Vector3.new(2,HOVER,0),-Vector3.zAxis,Vector3.yAxis);a.profile=Species.aphid_prototype
 bodies:draw({g,a},0)
 local gr,ar=bodies.rigs.gnat,bodies.rigs.aphid
 check(#gr.parts==22 and #ar.parts==15 and #gr.parts<=40 and #ar.parts<=40,`a gnat is {#gr.parts} parts and an aphid {#ar.parts}, under the fly's forty`)
 check(gr.scale==.45 and ar.scale==.4,"at their own scales")
 local wings,aWings=0,0
 for _,p in gr.parts do if string.find(p.Name,"Wing",1,true) then wings+=1 end end
 for _,p in ar.parts do if string.find(p.Name,"Wing",1,true) then aWings+=1 end end
 check(wings==2 and aWings==0,"one pair of wings on the gnat, none on the aphid")
 for _,rig in {gr,ar} do
  for _,p in rig.parts do check(p.Anchored and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.CastShadow==false,"a bed prey's part is as a fly's: anchored, never solid, never seen, no shadow") end
 end
 -- a gnat in the air: its wings become the fan, its legs tuck; the aphid has no flight pose to go to, but a captured one is still drawn
 g.state="FLEE"
 bodies:draw({g,a},0.5)
 local fan=named(gr,"RightWing")
 check(gr.flying and fan.Transparency>=.75,"in the air the gnat's wing is a blur")
 a.state="CAPTURED"
 bodies:draw({g,a},0.6)
 check(ar.flying and #ar.parts==15,"a captured aphid is drawn still")
 bodies:draw({},0)
end

-- ---------------------------------------------------------------- ROBLOX-103 (W3c): the bodies move, pose only
do
 local function rel(rig: any, ref: string): { [string]: CFrame }
  local base = named(rig, ref).CFrame
  local out = {}
  for _, p in rig.parts do out[p.Name] = base:Inverse() * p.CFrame end
  return out
 end
 local function diff(a: { [string]: CFrame }, b: { [string]: CFrame }, word: string): number
  local worst = 0
  for name, f in a do
   if string.find(name, word, 1, true) then
    local g = b[name]
    worst = math.max(worst, (f.Position - g.Position).Magnitude, (f.LookVector - g.LookVector).Magnitude, (f.UpVector - g.UpVector).Magnitude)
   end
  end
  return worst
 end
 local function finiteRig(rig: any): boolean
  for _, p in rig.parts do
   local c = p.CFrame
   if not (finite(p.Position) and finite(c.RightVector) and finite(c.UpVector) and finite(c.LookVector)) then return false end
  end
  return true
 end
 -- a gnat walks 0.24 studs in a second, then stands for a second
 local bodies = FlyBodies.new(workspace)
 local g = fly("walker", "PERCHED", Vector3.new(0, HOVER, 0), -Vector3.zAxis, Vector3.yAxis); g.profile = Species.fungus_gnat_prototype
 local t = 0
 bodies:draw({ g }, t)
 local rig = bodies.rigs.walker
 local restPose = rel(rig, "Head")
 local partsBefore = #rig.parts
 local walkMoves, lowest, last = 0, math.huge, rel(rig, "Head")
 for _ = 1, 60 do
  t += 1 / 60
  g.position += Vector3.new(0, 0, -0.004)
  bodies:draw({ g }, t)
  local now = rel(rig, "Head")
  if diff(now, last, "Femur") > 1e-4 then walkMoves += 1 end
  last = now
  for _, p in rig.parts do if string.find(p.Name, "Tibia", 1, true) then lowest = math.min(lowest, endAlong(p, -Vector3.yAxis).Y) end end
 end
 check(walkMoves >= 55 and rig.gait > 0.9, `walking, the gnat's legs step (they moved in {walkMoves} of 60 frames; the stepping at {string.format("%.2f", rig.gait)})`)
 check(lowest > -0.03, `no foot goes through the surface while stepping (lowest {string.format("%.3f", lowest)})`)
 local cycles = rig.stride
 for _ = 1, 60 do t += 1 / 60; bodies:draw({ g }, t) end
 local a = rel(rig, "Head")
 t += 1 / 60; bodies:draw({ g }, t)
 local b = rel(rig, "Head")
 check(diff(a, b, "Femur") < 1e-9 and diff(a, b, "Tibia") < 1e-9 and rig.gait == 0 and rig.stride == cycles, "standing still, its legs do not move")
 check(diff(a, restPose, "Femur") < 1e-9 and diff(a, restPose, "Tibia") < 1e-9, "and they are back in the standing pose")
 check(#rig.parts == partsBefore and partsBefore == 22, "and no part was added (22)")
 -- the antennae sway a little when not in Reduced Motion, and are still in it; the legs step in it all the same
 local a1 = rel(rig, "Head"); t += 0.2; bodies:draw({ g }, t); local a2 = rel(rig, "Head")
 check(diff(a1, a2, "Antenna") > 1e-4 and diff(a1, a2, "Antenna") < 0.45, `the antennae sway ({string.format("%.4f", diff(a1, a2, "Antenna"))})`)
 local r1 = rel(rig, "Head"); t += 0.2; bodies:draw({ g }, t, nil, true); local r2 = rel(rig, "Head"); t += 0.2; bodies:draw({ g }, t, nil, true); local r3 = rel(rig, "Head")
 check(diff(r2, r3, "Antenna") < 1e-9, "in Reduced Motion the antennae are still")
 local stepsReduced = 0
 for _ = 1, 20 do
  local before = rel(rig, "Head"); t += 1 / 60; g.position += Vector3.new(0.004, 0, 0); bodies:draw({ g }, t, nil, true)
  if diff(rel(rig, "Head"), before, "Femur") > 1e-4 then stepsReduced += 1 end
 end
 check(stepsReduced >= 15 and r1 ~= nil, `in Reduced Motion the legs still step ({stepsReduced} of 20 frames)`)
 -- the wing's phase runs in flight and not at rest
 g.state = "FLEE"
 bodies:draw({ g }, t)
 local w0 = rig.wing
 t += 1 / 60; bodies:draw({ g }, t)
 local w1 = rig.wing
 g.state = "PERCHED"
 bodies:draw({ g }, t); t += 1 / 60; bodies:draw({ g }, t)
 local w2 = rig.wing; t += 1 / 60; bodies:draw({ g }, t)
 check(w1 ~= w0 and rig.wing == w2, "the wing's phase changes in flight and holds at rest")
 -- the house fly's legs go in two tripods: the right front and right middle swing opposite ways
 local hf = fly("house", "PERCHED", Vector3.new(5, HOVER, 0), -Vector3.zAxis, Vector3.yAxis)
 local opposite, same, kicked = 0, 0, 0
 bodies:draw({ hf }, t)
 local hrig = bodies.rigs.house
 local still = rel(hrig, "Head")
 for _ = 1, 90 do
  t += 1 / 60; hf.position += Vector3.new(0, 0, -0.01); bodies:draw({ hf }, t)
  local now = rel(hrig, "Head")
  local front = now.RightFrontTibia.Position.Z - still.RightFrontTibia.Position.Z
  local middle = now.RightMiddleTibia.Position.Z - still.RightMiddleTibia.Position.Z
  if math.abs(front) > 0.002 and math.abs(middle) > 0.002 then if (front > 0) ~= (middle > 0) then opposite += 1 else same += 1 end end
 end
 check(opposite > 40 and same <= opposite / 10, `the house fly walks on two tripods (front and middle of a side opposite in {opposite} frames, together in {same})`)
 -- in the jaws the legs kick
 hf.state = "CAPTURED"
 bodies:draw({ hf }, t)
 for _ = 1, 30 do
  local before = rel(hrig, "Head"); t += 1 / 60; bodies:draw({ hf }, t)
  if diff(rel(hrig, "Head"), before, "Femur") > 1e-4 then kicked += 1 end
 end
 check(kicked >= 25, `held in the jaws the legs kick ({kicked} of 30 frames)`)
 -- the house fly's blur in Reduced Motion is still
 hf.state = "FLEE"
 bodies:draw({ hf }, t, nil, true)
 local b1 = named(hrig, "RightWing").CFrame; t += 1 / 60; bodies:draw({ hf }, t, nil, true)
 check((named(hrig, "RightWing").CFrame.UpVector - b1.UpVector).Magnitude < 1e-9, "in Reduced Motion the flight blur does not tremble")
 -- nothing goes NaN: every kind of the sill and the bed walking, flying and held, on awkward headings and normals
 local bad = 0
 for _, prof in { Species.fly_like_prototype, Species.fruit_fly_prototype, Species.fungus_gnat_prototype, Species.aphid_prototype } do
  local f = fly("n", "PERCHED", Vector3.new(0, HOVER, 0), Vector3.yAxis, Vector3.yAxis); f.profile = prof
  for k = 1, 40 do
   t += 1 / 60
   f.state = if k % 13 == 0 then "CAPTURED" elseif k % 7 == 0 then "FLEE" else "PERCHED"
   f.heading = if k % 5 == 0 then Vector3.new(0, 1, 1e-5) else Vector3.new(math.cos(k), 0, math.sin(k))
   f.normal = if k % 3 == 0 then Vector3.xAxis else Vector3.yAxis
   f.position += Vector3.new(0.003, 0, 0.002)
   bodies:draw({ f }, t, Vector3.new(0, 30, 0), k % 2 == 0)
   if not finiteRig(bodies.rigs.n) then bad += 1 end
  end
  bodies:draw({}, t)
 end
 check(bad == 0, "no NaN in any frame of any kind, walking, flying or held")
 -- the far rule: beyond 25 studs of the camera a body is placed ten times a second; near, every frame
 local nearFly = fly("near", "PERCHED", Vector3.new(0, HOVER, 0), -Vector3.zAxis, Vector3.yAxis)
 local farFly = fly("far", "PERCHED", Vector3.new(60, HOVER, 0), -Vector3.zAxis, Vector3.yAxis)
 local moved: { [any]: number } = {}
 local original = workspace.BulkMoveTo
 workspace.BulkMoveTo = function(self: any, ps: { any }, frames: { any }, mode: any)
  for _, part in ps do moved[part] = (moved[part] or 0) + 1 end
  original(self, ps, frames, mode)
 end
 bodies:draw({ nearFly, farFly }, t, Vector3.new(0, 1, 2))
 table.clear(moved)
 for _ = 1, 60 do t += 1 / 60; bodies:draw({ nearFly, farFly }, t, Vector3.new(0, 1, 2)) end
 workspace.BulkMoveTo = original
 local nearN, farN = moved[bodies.rigs.near.parts[1]] or 0, moved[bodies.rigs.far.parts[1]] or 0
 check(nearN == 60 and farN >= 9 and farN <= 11, `a near body is placed every frame ({nearN} of 60), a far one ten times a second ({farN})`)
 bodies:draw({}, t)
 check(next(bodies.rigs) == nil, "gone when not drawn")
end
-- ROBLOX-108: the low tier is lighter for the house fly too: no bristles and no films over the wings (29 parts, not 39); its walk and flight are the same
do
	local lowBodies = FlyBodies.new(holder, "low")
	local lowRig = lowBodies:spawn("low1")
	local fullRig = FlyBodies.new(holder, "full"):spawn("full1")
	local has = function(r: any, prefix: string): boolean
		for _, p in r.parts do if string.sub(p.Name, 1, #prefix) == prefix then return true end end
		return false
	end
	check(#fullRig.parts == 39 and #lowRig.parts == 29, `the house fly is {#fullRig.parts} parts at full and {#lowRig.parts} at low`)
	check(has(fullRig, "Bristle") and has(fullRig, "LeftFilm") and not has(lowRig, "Bristle") and not has(lowRig, "LeftFilm") and has(lowRig, "LeftWing") and has(lowRig, "LeftVein") and has(lowRig, "Shadow"),
		"at low it keeps its body, stripes, legs, wings, veins and shadow, and leaves out the bristles and the films")
	local fly = { id = "low1", state = "PERCHED", position = Vector3.new(0, 0.16, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, airborne = function() return false end }
	local ok = pcall(function()
		for k = 0, 30 do fly.position = Vector3.new(0, 0.16, -0.02 * k); lowBodies:draw({ fly } :: { any }, k / 60) end
		fly.airborne = function() return true end
		for k = 31, 60 do lowBodies:draw({ fly } :: { any }, k / 60) end
	end)
	local finite = true
	for _, p in lowRig.parts do local q = p.Position; if q.X ~= q.X or q.Y ~= q.Y or q.Z ~= q.Z then finite = false end end
	check(ok and finite and lowRig.flying == true, "and it walks and flies as the full one does")
end
print(`FLIES passed={passed} failed={failed}`)
if failed > 0 then error("fly checks failed") end
