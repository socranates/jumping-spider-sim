--!strict
-- The drawn fly: a house fly (Data/FlyLook has every number) 0.7 cm long, made of ellipsoids and rods: a head with two big red-brown
-- compound eyes and a pale silver face, a grey thorax with four dark stripes, a grey-brown abdomen with a darker dorsal stripe, a short
-- dark proboscis, a few bristles, six two-segment legs, and two thin glass wings with a dark leading vein and a faint iridescent film,
-- folded back in a shallow V at rest. In flight the wings are a soft translucent blur on each side (no strobing flaps) and the legs
-- trail. Every part is anchored, never collides, is never seen by a ray and casts no shadow (Habitat/Shapes); a soft dark oval on the
-- surface under a standing fly stands in for its shadow. One Workspace:BulkMoveTo places all the flies' parts each frame.
-- Display only: the fly's position, heading and normal come from the prey simulation (in the air its back is up); nothing here feeds back.
-- ROBLOX-96: the bed's prey are drawn from FlyLook.small by `buildSmall`, a template per prey kind (Species body.prey_kind: the fungus gnat, the aphid), each
-- under the fly's part budget; a fly whose kind has no sheet (the house fly, the fruit fly) is the house fly's template at its visual_scale, as before.
-- ROBLOX-101: the bestiary's four (the springtail, the leafhopper, the moth, the crane fly) from the same sheets with the detail tier (`new`'s `detail`: a sheet's
-- `full` items are drawn only at "full", its `low` items only at "low"), wings in pairs of several kinds (`wings`), and the crane fly's shed leg (a fly with
-- `legsLost` is drawn from the template without the sheet's `shed` parts). A template is built per kind, tier and shed leg, when first asked for.
-- ROBLOX-103 (W3c): the bodies move, pose only (no part is added: each part's frame in the body is turned before the one BulkMoveTo). The legs step while a body
-- walks (two tripods; a full cycle per stride of ground covered, so they stop when it stops) and kick in the jaws; the antennae sway; the flight fans tremble as
-- the fly's always have, or beat visibly where the sheet says (the moth); a landed moth's wings shiver and settle; a crane fly rocks in the air with its legs
-- dangling; a hopper crouches before its leap and a springtail somersaults through it. Every number is the sheet's `motion` (Data/FlyLook). `draw` takes the
-- camera's place (a body farther than FlyLook.far.studs is drawn ten times a second, as the rival's rig is) and the Reduced Motion setting (the steps stay,
-- everything else is still). Phases come from the clock `draw` is given and from distance walked, so a paused game is a still one.
-- ROBLOX-128 (the small lives): a wingbeat too fast to draw at 60 frames (a sheet's `flap` over FlyLook.BLUR_HZ: the hoverfly's, the midge's, the mosquito's, the
-- damselfly's) is the trembling blur, never a strobing flap; a fly standing calm and still grooms in seeded bouts (its front legs rubbed together under its
-- head, or its hind legs drawn back under its abdomen and rubbed); a fly whose take-off is scheduled readies itself (raised, nose up, its middle legs forward); a singing
-- field cricket holds its forewings raised and dips them through each chirp; the house fly's wings carry two more veins each at the full tier, M1+2 with its
-- bend (six of its eight bristles gave up their parts: still 39). No part is added to any body; nothing feeds back to the sim.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlyLook = require(Shared:WaitForChild("Data"):WaitForChild("FlyLook"))
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))

local FlyBodies = {}
FlyBodies.__index = FlyBodies

local TAU = 2 * math.pi

-- (ROBLOX-103) a small seeded offset per body from its id, so a crowd does not sway in step
local function offsetOf(id: string): number
	local h = 0
	for k = 1, #id do h = (h * 31 + string.byte(id, k)) % 9973 end
	return h / 9973 * TAU
end


-- How a part looks and sits in one pose (at rest or in flight), in the body frame.
type Pose = { size: Vector3, frame: CFrame, transparency: number }
type Spec = {
	name: string,
	rod: boolean, -- a Cylinder part; otherwise an ellipsoid
	color: Color3,
	material: string,
	reflectance: number,
	rest: Pose,
	flight: Pose,
}
type Leg = { name: string, hip: { number }, knee: { number }, foot: { number } }
-- (ROBLOX-103) how a part moves: a leg segment turns about its leg's hip (`pair` 1 front to 3 hind, `side` -1 left, +1 right); an antenna about its base; a wing
-- about its root at rest (`rest`) and in flight (`root`); the furcula is left to its two poses.
type Anim = { what: string, hip: Vector3, side: number, pair: number, root: Vector3?, rest: Vector3? }

-- (ROBLOX-128) A number in [0, 1) from a body's seed and a count: the grooming schedule's draws (a pure hash, so the same body grooms the same way every time).
local function hash01(seed: number, n: number): number
	local x = math.sin(seed * 12.9898 + n * 78.233) * 43758.5453
	return x - math.floor(x)
end
local function between(range: { number }, u: number): number
	return range[1] + (range[2] - range[1]) * u
end
-- (ROBLOX-128) Whether a sheet's flap is drawn as a beat (slow enough for 60 frames) or as the blur.
local function beats(M: any): boolean
	return M.flap ~= nil and M.flap.hz <= FlyLook.BLUR_HZ
end
-- (ROBLOX-128) Whether a fly sings now (Prey/PreyKinds.chirping's rule, read here so the drawing needs nothing of the sim's modules).
local function singing(fly: any): boolean
	local p = fly.profile
	return p ~= nil and p.body.chirp == true and (fly.serial or 0) % 2 == 1 and fly.state == "PERCHED" and fly.hop == nil and fly.hushed ~= true
end
type Template = {
	specs: { Spec },
	restFrames: { CFrame },
	flightFrames: { CFrame },
	changing: { number }, -- the parts that differ between the poses: legs, wings, veins, films, the shadow
	fans: { [number]: boolean }, -- the wing parts, which tremble a little as a blur in flight
	anim: { [number]: Anim }, -- (ROBLOX-103) the parts that move within a pose
	motion: any, -- the sheet's `motion` (FlyLook.motion for the house fly)
}

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function mirrored(p: Vector3, side: number): Vector3
	return Vector3.new(p.X * side, p.Y, p.Z)
end

-- The size and frame of a rod (a Cylinder part: its axis is X) from a to b, `extraA` and `extraB` longer at the ends.
local function rodBetween(a: Vector3, b: Vector3, diameter: number, extraA: number, extraB: number): (Vector3, CFrame)
	local dir = (b - a).Unit
	local from, to = a - dir * extraA, b + dir * extraB
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Vector3.new((to - from).Magnitude, diameter, diameter), CFrame.lookAt((from + to) / 2, to, up) * CFrame.Angles(0, math.pi / 2, 0)
end

-- `detail` (ROBLOX-108): at "low" the house fly leaves out its eight bristles and the two iridescent films over its wings (29 parts, not 39): a phone's screen
-- shows neither at a fly's size, and four flies on the sill are 40 parts fewer to place every frame.
local function build(detail: string?): Template
	local low = detail == "low"
	local C = FlyLook.colors
	local specs: { Spec } = {}
	local fans: { [number]: boolean } = {}
	local anim: { [number]: Anim } = {}
	local function color(name: string): Color3
		return Color3.fromHex(C[name])
	end
	local function same(pose: Pose): Pose
		return { size = pose.size, frame = pose.frame, transparency = pose.transparency }
	end
	local function add(name: string, rod: boolean, tint: Color3, material: string, reflectance: number, rest: Pose, flight: Pose?): number
		table.insert(specs, { name = name, rod = rod, color = tint, material = material, reflectance = reflectance, rest = rest, flight = flight or same(rest) })
		return #specs
	end

	-- head, thorax, abdomen, eyes, face, proboscis
	local ellipsoids: { [string]: { centre: Vector3, radii: Vector3 } } = {}
	for _, item in FlyLook.body do
		local centre, size = vec(item.at), vec(item.size)
		ellipsoids[item.name] = { centre = centre, radii = size / 2 }
		local frame = CFrame.new(centre)
		if item.turn then frame *= CFrame.Angles(math.rad(item.turn[1]), math.rad(item.turn[2]), math.rad(item.turn[3])) end
		add(item.name, false, color(item.color), "SmoothPlastic", item.reflectance or 0, { size = size, frame = frame, transparency = 0 })
	end
	-- the stripes: slices of the ellipsoid they lie on, a little proud of it
	for _, slice in FlyLook.slices do
		local body = ellipsoids[slice.on]
		local share = math.sqrt(1 - (slice.x / body.radii.X) ^ 2)
		local size = Vector3.new(slice.width, 2 * (body.radii.Y * share + FlyLook.proud), 2 * (body.radii.Z * share + FlyLook.proud))
		add(slice.name, false, color(slice.color), "SmoothPlastic", 0, { size = size, frame = CFrame.new(body.centre + Vector3.new(slice.x, 0, 0)), transparency = 0 })
	end

	-- legs: a femur from the hip to the knee and a tibia from the knee to the foot, standing and in flight
	local L = FlyLook.legs
	for _, side in { -1, 1 } do
		local word = if side < 0 then "Left" else "Right"
		for pair = 1, #L.stand do
			local stand, fly = L.stand[pair], L.fly[pair]
			local function segment(label: string, diameter: number, tint: string, a: number, b: number, extraA: number, extraB: number)
				local function joint(leg: Leg, which: number): Vector3 -- 1 the hip, 2 the knee, 3 the foot
					return mirrored(vec(if which == 1 then leg.hip elseif which == 2 then leg.knee else leg.foot), side)
				end
				local size0, frame0 = rodBetween(joint(stand, a), joint(stand, b), diameter, extraA, extraB)
				local size1, frame1 = rodBetween(joint(fly, a), joint(fly, b), diameter, extraA, extraB)
				local i = add(`{word}{stand.name}{label}`, true, color(tint), "SmoothPlastic", 0,
					{ size = size0, frame = frame0, transparency = 0 }, { size = size1, frame = frame1, transparency = 0 })
				anim[i] = { what = "leg", hip = joint(stand, 1), side = side, pair = pair }
			end
			segment("Femur", L.femur, "femur", 1, 2, 0, L.overlap)
			segment("Tibia", L.tibia, "tibia", 2, 3, L.overlap, 0)
		end
	end

	-- bristles
	local B = FlyLook.bristles
	local n = 0
	local items: { any } = if low then {} else B.items
	for _, item in items do
		local sides: { number } = if item.mirror then { 1, -1 } else { 1 }
		for _, side in sides do
			n += 1
			local size, frame = rodBetween(mirrored(vec(item.from), side), mirrored(vec(item.to), side), B.diameter, 0, 0)
			add("Bristle" .. n, true, color("bristle"), "SmoothPlastic", 0, { size = size, frame = frame, transparency = 0 })
		end
	end

	-- wings: folded back in a V at rest, a fan of blur each side in flight
	local W = FlyLook.wing
	for _, side in { -1, 1 } do
		local word = if side < 0 then "Left" else "Right"
		local pitch, yaw = math.rad(W.pitch), math.rad(W.yaw)
		local along = Vector3.new(side * math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)).Unit
		local root = mirrored(vec(W.root), side)
		local centre = root + along * (W.length / 2)
		local up = (Vector3.yAxis - along * along.Y).Unit
		local wing = CFrame.fromMatrix(centre, up:Cross(along), up) * CFrame.Angles(0, 0, -side * math.rad(W.roll))
		local restSize = Vector3.new(W.width, W.thick, W.length)
		-- in flight: a flat fan from the root outward, the outer edge up
		local yawBack = math.rad(W.fan.yaw)
		local reachDir = Vector3.new(side * math.cos(yawBack), 0, math.sin(yawBack))
		local fanRoot = Vector3.new(side * W.root[1], W.root[2] + W.fan.rise, W.root[3] + W.fan.back)
		local function fanFrame(reach: number): CFrame -- a fan reaching `reach` out from the root
			return CFrame.new(fanRoot + reachDir * (reach / 2)) * CFrame.Angles(0, -side * yawBack, 0) * CFrame.Angles(0, 0, side * math.rad(W.fan.roll))
		end
		local fan, fanSize = fanFrame(W.fan.reach), Vector3.new(W.fan.reach, W.thick, W.fan.span)
		local filmFan, filmFanSize = fanFrame(W.fan.film.reach), Vector3.new(W.fan.film.reach, W.thick, W.fan.film.span)

		local wi = add(`{word}Wing`, false, color("wing"), "Glass", W.reflectance,
			{ size = restSize, frame = wing, transparency = W.transparency }, { size = fanSize, frame = fan, transparency = W.fan.transparency })
		fans[wi] = true
		anim[wi] = { what = "wing", hip = root, side = side, pair = 0, root = fanRoot, rest = root }
		local V = W.vein
		local from, to = wing * Vector3.new(side * V.offset, W.thick, V.from * W.length), wing * Vector3.new(side * V.offset, W.thick, V.to * W.length)
		local veinSize, veinFrame = rodBetween(from, to, V.diameter, 0, 0)
		add(`{word}Vein`, true, color("vein"), "SmoothPlastic", 0,
			{ size = veinSize, frame = veinFrame, transparency = V.transparency }, { size = veinSize, frame = veinFrame, transparency = 1 })
		if not low then
			-- (ROBLOX-128) R4+5 and M1+2 with its bend, on the upper face, hidden in the blur
			local VS = W.veins
			for _, item in VS.items do
				local a = wing * Vector3.new(side * item.from[1] * W.width / 2, W.thick, item.from[2] * W.length)
				local b = wing * Vector3.new(side * item.to[1] * W.width / 2, W.thick, item.to[2] * W.length)
				local size, frame = rodBetween(a, b, VS.diameter, 0, 0)
				add(`{word}{item.name}`, true, color("vein"), "SmoothPlastic", 0,
					{ size = size, frame = frame, transparency = VS.transparency }, { size = size, frame = frame, transparency = 1 })
			end
		end
		if not low then
			local F = W.film
			local fi = add(`{word}Film`, false, color("film"), "SmoothPlastic", 0,
				{ size = restSize + Vector3.new(F.grow, 0, F.grow), frame = wing * CFrame.new(0, F.rise, 0), transparency = F.transparency },
				{ size = filmFanSize, frame = filmFan * CFrame.new(0, F.rise, 0), transparency = W.fan.film.transparency })
			fans[fi] = true
			anim[fi] = { what = "wing", hip = root, side = side, pair = 0, root = fanRoot, rest = root }
		end
	end

	-- the shadow: a dark oval on the surface, only while the fly stands
	local S = FlyLook.shadow
	local shadowSize = vec(S.size)
	local shadowFrame = CFrame.new(0, -FlyLook.hover + S.lift + shadowSize.Y / 2, 0.005)
	add("Shadow", false, color("shadow"), "SmoothPlastic", 0, { size = shadowSize, frame = shadowFrame, transparency = S.transparency }, { size = shadowSize, frame = shadowFrame, transparency = 1 })

	local restFrames: { CFrame } = {}
	local flightFrames: { CFrame } = {}
	local changing: { number } = {}
	for i, spec in specs do
		restFrames[i], flightFrames[i] = spec.rest.frame, spec.flight.frame
		if spec.rest.size ~= spec.flight.size or spec.rest.transparency ~= spec.flight.transparency then table.insert(changing, i) end
	end
	return { specs = specs, restFrames = restFrames, flightFrames = flightFrames, changing = changing, fans = fans, anim = anim, motion = FlyLook.motion }
end

-- ROBLOX-96: a smaller prey from one of FlyLook.small's sheets: its ellipsoids, its rods (mirrored where the sheet says, with a flight pose where it differs),
-- one pair of plain wings when it has any (folded at rest, a fan in flight, as the fly's without the vein and the film), and the shadow.
local function buildSmall(L: any, tier: string?, shed: boolean?): Template
	local specs: { Spec } = {}
	-- (ROBLOX-101) whether an item of the sheet is drawn at this tier, and not a part of the shed leg
	local low = tier == "low"
	local function shown(item: any, name: string): boolean
		if item.full and low then return false end
		if item.low and not low then return false end
		if shed and L.shed ~= nil and string.sub(name, 1, #L.shed) == L.shed then return false end
		return true
	end
	local fans: { [number]: boolean } = {}
	local anim: { [number]: Anim } = {}
	-- (ROBLOX-103) a leg's hip: the `from` of its first rod (the femur, or the one-rod leg); legs are named for their pair (Front, Middle, Hind)
	local PAIRS = { Front = 1, Middle = 2, Hind = 3 }
	local hips: { [string]: { number } } = {}
	for _, item in L.rods do
		local pair = string.match(item.name, "^(%u%l+)")
		if pair ~= nil and PAIRS[pair] ~= nil and hips[pair] == nil then hips[pair] = item.from end
	end
	local function color(name: string): Color3
		return Color3.fromHex(L.colors[name])
	end
	local function same(pose: Pose): Pose
		return { size = pose.size, frame = pose.frame, transparency = pose.transparency }
	end
	local function add(name: string, rod: boolean, tint: Color3, material: string, reflectance: number, rest: Pose, flight: Pose?): number
		table.insert(specs, { name = name, rod = rod, color = tint, material = material, reflectance = reflectance, rest = rest, flight = flight or same(rest) })
		return #specs
	end
	for _, item in L.body do
		if not shown(item, item.name) then continue end
		local centre, size = vec(item.at), vec(item.size)
		local frame = CFrame.new(centre)
		if item.turn then frame *= CFrame.Angles(math.rad(item.turn[1]), math.rad(item.turn[2]), math.rad(item.turn[3])) end
		local index = add(item.name, false, color(item.color), "SmoothPlastic", item.reflectance or 0, { size = size, frame = frame, transparency = 0 })
		if item.hinge ~= nil then anim[index] = { what = "sing", hip = vec(item.hinge), side = 0, pair = 0 } end -- (ROBLOX-128: the cricket's forewings)
	end
	for _, item in L.rods do
		local sides: { number } = if item.mirror then { -1, 1 } else { 1 }
		for _, side in sides do
			local word = if not item.mirror then "" elseif side < 0 then "Left" else "Right"
			if not shown(item, word .. item.name) then continue end
			local size0, frame0 = rodBetween(mirrored(vec(item.from), side), mirrored(vec(item.to), side), item.d, 0, 0)
			local flight: Pose? = nil
			if item.fly then
				local size1, frame1 = rodBetween(mirrored(vec(item.fly[1]), side), mirrored(vec(item.fly[2]), side), item.d, 0, 0)
				flight = { size = size1, frame = frame1, transparency = 0 }
			end
			local index = add(word .. item.name, true, color(item.color), "SmoothPlastic", 0, { size = size0, frame = frame0, transparency = 0 }, flight)
			local pair = string.match(item.name, "^(%u%l+)")
			if pair ~= nil and PAIRS[pair] ~= nil then
				anim[index] = { what = "leg", hip = mirrored(vec(hips[pair]), side), side = side, pair = PAIRS[pair] }
			elseif item.name == "Spines" then -- (the leafhopper's spine rows ride on the hind tibiae)
				anim[index] = { what = "leg", hip = mirrored(vec(hips.Hind or item.from), side), side = side, pair = 3 }
			elseif item.name == "Antenna" then
				anim[index] = { what = "antenna", hip = mirrored(vec(item.from), side), side = if item.mirror then side else 0, pair = 0 }
			end
		end
	end
	local pairs_: { any } = L.wings or (if L.wing ~= nil then { L.wing } else {})
	for _, W in pairs_ do
		local label = W.name or "Wing"
		for _, side in { -1, 1 } do
			local word = if side < 0 then "Left" else "Right"
			if not shown(W, word .. label) then continue end
			local pitch, yaw = math.rad(W.pitch), math.rad(W.yaw)
			local along = Vector3.new(side * math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)).Unit
			local root = mirrored(vec(W.root), side)
			local centre = root + along * (W.length / 2)
			local up = (Vector3.yAxis - along * along.Y).Unit
			local wing = CFrame.fromMatrix(centre, up:Cross(along), up) * CFrame.Angles(0, 0, -side * math.rad(W.roll))
			local F = W.fan or { reach = W.length, span = W.width, roll = 0, yaw = W.yaw, back = 0, rise = 0, transparency = 1 }
			local yawBack = math.rad(F.yaw)
			local reachDir = Vector3.new(side * math.cos(yawBack), 0, math.sin(yawBack))
			local fanRoot = Vector3.new(side * W.root[1], W.root[2] + F.rise, W.root[3] + F.back)
			local fan = CFrame.new(fanRoot + reachDir * (F.reach / 2)) * CFrame.Angles(0, -side * yawBack, 0) * CFrame.Angles(0, 0, side * math.rad(F.roll))
			local restPose = { size = Vector3.new(W.width, W.thick, W.length), frame = wing, transparency = W.transparency }
			local index = add(`{word}{label}`, false, color(W.color or "wing"), W.material or "Glass", W.reflectance,
				restPose,
				if W.hide then { size = restPose.size, frame = wing, transparency = 1 } else { size = Vector3.new(F.reach, W.thick, F.span), frame = fan, transparency = F.transparency })
			if not W.hide then fans[index] = true end
			-- (a band drawn on a wing at rest turns with the first pair's root)
			local restRoot = if W.hide and pairs_[1] ~= nil then mirrored(vec(pairs_[1].root), side) else root
			anim[index] = { what = "wing", hip = restRoot, side = side, pair = 0, root = fanRoot, rest = restRoot }
		end
	end
	local S = L.shadow
	if shown(S, "Shadow") then
		local shadowSize = vec(S.size)
		local shadowFrame = CFrame.new(0, -FlyLook.hover + S.lift + shadowSize.Y / 2, 0.005)
		add("Shadow", false, color("shadow"), "SmoothPlastic", 0, { size = shadowSize, frame = shadowFrame, transparency = S.transparency }, { size = shadowSize, frame = shadowFrame, transparency = 1 })
	end
	local restFrames: { CFrame } = {}
	local flightFrames: { CFrame } = {}
	local changing: { number } = {}
	for i, spec in specs do
		restFrames[i], flightFrames[i] = spec.rest.frame, spec.flight.frame
		if spec.rest.size ~= spec.flight.size or spec.rest.transparency ~= spec.flight.transparency then table.insert(changing, i) end
	end
	return { specs = specs, restFrames = restFrames, flightFrames = flightFrames, changing = changing, fans = fans, anim = anim, motion = L.motion or FlyLook.motion }
end

-- `detail` (ROBLOX-101): the client's detail tier, "full" (the default) or "low", for the sheets that draw fewer parts at low.
function FlyBodies.new(parent: Instance, detail: string?): any
	local folder = Instance.new("Folder")
	folder.Name = "Flies"
	folder.Parent = parent
	return setmetatable({ folder = folder, rigs = {}, template = build(detail), templates = {} :: { [string]: Template }, parts = {}, frames = {}, detail = detail or "full",
		present = {} :: { [string]: boolean } }, FlyBodies)
end

-- The template a prey kind is drawn from (Species body.prey_kind): one of FlyLook.small's, built when first asked for, or the house fly's. `kind` may end in
-- "+shed" (ROBLOX-101: the crane fly that left a leg).
function FlyBodies.templateFor(self: any, kind: string?): Template
	if kind == nil then return self.template end
	local base = string.gsub(kind, "%+shed$", "")
	if FlyLook.small[base] == nil then return self.template end
	local key = kind .. "|" .. self.detail
	local t = self.templates[key]
	if t == nil then
		t = buildSmall(FlyLook.small[base], self.detail, base ~= kind)
		self.templates[key] = t
	end
	return t
end

-- One fly's parts, standing. `kind`: its prey kind (nil: the house fly's template).
function FlyBodies.spawn(self: any, id: string, kind: string?): any
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = self.folder
	local template = self:templateFor(kind)
	local parts: { Part } = {}
	for i, spec in template.specs do
		local pose = spec.rest
		local part: Part
		if spec.rod then
			part = Shapes.block(folder, spec.name, pose.size, pose.frame, spec.color, spec.material)
			part.Shape = Enum.PartType.Cylinder
		else
			part = Shapes.ellipsoid(folder, spec.name, pose.size, pose.frame, spec.color, spec.material)
		end
		part.Reflectance = spec.reflectance
		part.Transparency = pose.transparency
		parts[i] = part
	end
	local rig = { folder = folder, parts = parts, flying = false, kind = kind, template = template,
		-- (ROBLOX-103) the motion: stride phase, stepping envelope, wing phase, the rig's clock, take-off and landing, the crouch, the far rule's owed time
		stride = 0, gait = 0, wing = 0, t = 0, crouch = 0, owed = 0, drawn = false, wasFlying = false, seed = offsetOf(id),
		-- (ROBLOX-128) grooming: seconds still and calm, the bout's number, when it begins and ends (in seconds still), its kind; the song's raise
		still = 0, groomN = 0, groomAt = 0, groomEnd = 0, groomKind = "front", sing = 0 }
	self.rigs[id] = rig
	return rig
end

-- Switches a fly's parts that differ between the poses (the legs' reach, the wings, their veins and films, the shadow).
function FlyBodies.pose(self: any, rig: any, flying: boolean)
	rig.flying = flying
	local template: Template = rig.template or self.template
	for i, spec in template.specs do
		local pose = if flying then spec.flight else spec.rest
		rig.parts[i].Size = pose.size * (rig.scale or 1)
		-- (the fruit fly: the house fly's template in a fruit fly's colours; ROBLOX-114: known by its kind, not by its golden visual_scale 0.6, which it is no longer drawn at)
		local fruit = rig.fruit == true
		rig.parts[i].Transparency = if (rig.captured and spec.name == "Shadow") or (fruit and string.find(spec.name, "Stripe")) then 1 else pose.transparency
		local name = spec.name
		rig.parts[i].Color = if fruit and (name == "Head" or name == "Thorax" or name == "Abdomen" or name == "Face") then Color3.fromRGB(178, 132, 65)
			elseif fruit and (name == "EyeL" or name == "EyeR") then Color3.fromRGB(176, 39, 24) else spec.color
	end
end

-- (ROBLOX-103) The rig's motion for this drawing: the stride (from the ground covered on the surface since the last drawing), the stepping's envelope, the wing's
-- phase, the rig's own clock and the moments it took off and landed. `dt` is the time since the last drawing (0 when the clock has not moved: nothing advances).
function FlyBodies.advance(self: any, rig: any, fly: any, dt: number, flying: boolean, normal: Vector3)
	local M = rig.template.motion
	local G = M.gait
	local pos: Vector3 = fly.position
	local moved = 0
	if rig.lastPos ~= nil then
		local d: Vector3 = pos - rig.lastPos
		d -= normal * d:Dot(normal)
		moved = d.Magnitude
	end
	rig.lastPos = pos
	if dt <= 0 then return end
	local scale = rig.scale or 1
	if moved > G.jump * scale or moved ~= moved then moved = 0 end -- a hop's landing or a teleport is not a step
	local captured = fly.state == "CAPTURED"
	local walking = not flying and moved > 1e-5
	if captured then
		rig.stride = (rig.stride + dt * M.kick * TAU) % TAU
	elseif walking then
		rig.stride = (rig.stride + moved / (G.stride * scale) * TAU) % TAU
	end
	local want = if walking or captured then 1 else 0
	rig.gait += (want - rig.gait) * math.min(1, dt * G.settle)
	if want == 0 and rig.gait < 0.02 then rig.gait = 0 end
	rig.t += dt
	if flying then
		if not rig.wasFlying then rig.tookOff = rig.t end
		local hz = if beats(M) then M.flap.hz else 19 / TAU
		rig.wing = (rig.wing + dt * hz * TAU) % TAU
	elseif rig.wasFlying then
		rig.landed = rig.t
	end
	rig.wasFlying = flying
	local hop = (M.crouch ~= nil or M.ready ~= nil) and fly.pending ~= nil and not flying
	rig.crouch += ((if hop then 1 else 0) - rig.crouch) * math.min(1, dt * 14)
	-- (ROBLOX-128) grooming: only standing calm (perched, not alarmed, nothing pending, not walking); anything else starts the count again
	local Gr = M.groom
	if Gr ~= nil and not flying and fly.state == "PERCHED" and fly.pending == nil and not walking and rig.gait == 0 then
		if rig.still == 0 then
			rig.groomN = 1
			rig.groomAt = between(Gr.after, hash01(rig.seed, 1))
			rig.groomEnd = rig.groomAt + between(Gr.bout, hash01(rig.seed, 2))
			rig.groomKind = "front"
		end
		rig.still += dt
		if rig.still >= rig.groomEnd then
			rig.groomN += 1
			local n = rig.groomN
			rig.groomAt = rig.still + between(Gr.every, hash01(rig.seed, n * 3))
			rig.groomEnd = rig.groomAt + between(Gr.bout, hash01(rig.seed, n * 3 + 1))
			-- the front first, and mostly; the hind legs over the wings now and then
			rig.groomKind = if n % 2 == 1 or hash01(rig.seed, n * 3 + 2) < 0.35 then "front" else "hind"
		end
	else
		rig.still = 0
	end
	-- (ROBLOX-128) the song: the forewings rise and settle
	if M.sing ~= nil then
		rig.sing += ((if singing(fly) and not flying then 1 else 0) - rig.sing) * math.min(1, dt * M.sing.ease)
		if rig.sing < 1e-3 then rig.sing = 0 end
	end
end

-- (ROBLOX-128) How far into a grooming bout the rig is (0 outside one, easing in and out over a fifth of a second), and the bout's own clock.
local function grooming(rig: any): (number, number)
	if rig.still <= 0 or rig.still < rig.groomAt or rig.still >= rig.groomEnd then return 0, 0 end
	local into, left = rig.still - rig.groomAt, rig.groomEnd - rig.still
	return math.clamp(math.min(into, left) / 0.2, 0, 1), into
end

-- (ROBLOX-103) How a part moves within its pose, in the body frame (before the profile's scale), or nil for not at all.
local function moveOf(a: Anim, rig: any, M: any, flying: boolean, reduced: boolean, seed: number): CFrame?
	if a.what == "leg" then
		local G = M.gait
		if flying and not rig.captured then
			if M.dangle == nil or reduced then return nil end
			local swing = M.dangle.amp * math.sin(rig.t * M.dangle.hz * TAU + a.pair * 1.9 + a.side * 0.7 + seed)
			return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.xAxis, swing) * CFrame.new(-a.hip)
		end
		if not flying and not reduced and rig.gait <= 0 then
			-- (ROBLOX-128) readying for take-off: the middle legs swung forward
			if M.ready ~= nil and rig.crouch > 1e-3 and M.crouch == nil and a.pair == 2 then
				return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.yAxis, a.side * M.ready.legs * rig.crouch) * CFrame.new(-a.hip)
			end
			-- (ROBLOX-128) grooming: the front legs in under the head, raised, rubbing against each other; or the hind legs drawn back and rubbed together
			local Gr = M.groom
			local k, into = grooming(rig)
			if Gr ~= nil and k > 0 then
				local rub = math.sin(into * Gr.hz * TAU)
				if rig.groomKind == "front" and a.pair == 1 then
					local inward = k * (0.55 + Gr.amp * rub * a.side)
					return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.yAxis, a.side * inward) * CFrame.fromAxisAngle(Vector3.zAxis, a.side * k * (0.55 + 0.5 * Gr.amp * rub)) * CFrame.new(-a.hip)
				elseif rig.groomKind == "hind" and a.pair == 3 then
					-- drawn back under the abdomen's tip and rubbed against each other, a little raised (a short leg cannot reach over a fat abdomen in a drawing)
					local back = k * (0.45 + Gr.amp * rub * a.side)
					return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.yAxis, -a.side * back) * CFrame.fromAxisAngle(Vector3.zAxis, a.side * k * 0.2) * CFrame.new(-a.hip)
				end
			end
		end
		if rig.gait <= 0 then return nil end
		local offset = if G.wave ~= nil then -a.pair * G.wave + (if a.side < 0 then math.pi else 0)
			elseif (a.pair % 2 == 1) == (a.side > 0) then 0 else math.pi
		local phase = rig.stride + offset
		local swing = rig.gait * G.swing * math.sin(phase)
		local lift = rig.gait * G.lift * math.max(0, math.cos(phase))
		return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.yAxis, a.side * swing) * CFrame.fromAxisAngle(Vector3.zAxis, a.side * lift) * CFrame.new(-a.hip)
	elseif a.what == "antenna" then
		if reduced or M.antenna == nil then return nil end
		local A = M.antenna
		local busy = 1 + rig.gait
		local up = A.amp * math.sin(rig.t * A.hz * TAU * busy + seed + a.side)
		local out = A.amp * 0.6 * math.sin(rig.t * A.hz * 0.7 * TAU + seed * 1.3) * (if a.side == 0 then 1 else a.side)
		return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.xAxis, up) * CFrame.fromAxisAngle(Vector3.yAxis, out) * CFrame.new(-a.hip)
	elseif a.what == "wing" then
		if reduced then return nil end
		if flying then
			if not beats(M) or a.root == nil then return nil end
			local stroke = a.side * M.flap.amp * math.sin(rig.wing)
			return CFrame.new(a.root) * CFrame.fromAxisAngle(Vector3.zAxis, stroke) * CFrame.new(-(a.root :: Vector3))
		end
		local R = M.resettle
		if R == nil or rig.landed == nil or a.rest == nil then return nil end
		local since = rig.t - rig.landed
		if since >= R.seconds then return nil end
		local stroke = a.side * R.amp * (1 - since / R.seconds) * math.sin(since * R.hz * TAU)
		return CFrame.new(a.rest) * CFrame.fromAxisAngle(Vector3.zAxis, stroke) * CFrame.new(-(a.rest :: Vector3))
	elseif a.what == "sing" then
		local S = M.sing
		if reduced or S == nil or rig.sing <= 0 or flying then return nil end
		local into = (rig.t % S.period) / S.chirp
		local dip = if into < 1 then S.dip * math.sin(into * math.pi) else 0
		return CFrame.new(a.hip) * CFrame.fromAxisAngle(Vector3.xAxis, -rig.sing * (S.raise - dip)) * CFrame.new(-a.hip)
	end
	return nil
end

-- (ROBLOX-103) How the whole body is tipped within its frame this drawing (the crouch, the crane fly's rocking, the springtail's somersault), or nil.
local function bodyMove(rig: any, fly: any, M: any, flying: boolean, reduced: boolean, seed: number): CFrame?
	if reduced then return nil end
	if flying and M.wobble ~= nil and fly.state ~= "CAPTURED" then
		local W = M.wobble
		local w = rig.t * W.hz * TAU + seed
		return CFrame.fromAxisAngle(Vector3.zAxis, W.roll * (math.sin(w) + 0.4 * math.sin(w * 2.3)))
			* CFrame.fromAxisAngle(Vector3.xAxis, W.pitch * math.sin(w * 0.8 + 1.1))
	end
	if flying and M.tumble ~= nil and fly.hop ~= nil and rig.tookOff ~= nil then
		local s = math.clamp((rig.t - rig.tookOff) / math.max(fly.hop.time or 0.2, 1e-3), 0, 1)
		return CFrame.fromAxisAngle(Vector3.xAxis, -M.tumble * TAU * s)
	end
	if not flying and M.crouch ~= nil and rig.crouch > 1e-3 then
		local C = M.crouch
		return CFrame.new(0, -C.depth * rig.crouch, 0) * CFrame.fromAxisAngle(Vector3.xAxis, C.pitch * rig.crouch)
	end
	if not flying and M.ready ~= nil and rig.crouch > 1e-3 then -- (ROBLOX-128) raised on its legs, leaning back, about to go
		local R = M.ready
		return CFrame.new(0, R.lift * rig.crouch, 0) * CFrame.fromAxisAngle(Vector3.xAxis, R.pitch * rig.crouch)
	end
	return nil
end

-- Places every fly's parts. `now`: the prey's clock (the time of this drawing); `cameraAt` (ROBLOX-103): where the camera is, for the far rule (nil: every body
-- is near); `reduced`: the player's Reduced Motion setting.
function FlyBodies.draw(self: any, flies: { any }, now: number, cameraAt: Vector3?, reduced: boolean?, heldView: any?)
	local parts: { BasePart } = self.parts
	local frames: { CFrame } = self.frames
	table.clear(parts)
	table.clear(frames)
	local still = reduced == true
	local dtAll = if self.lastNow ~= nil then math.clamp(now - self.lastNow, 0, 0.25) else 0
	self.lastNow = now
	local present: { [string]: boolean } = self.present -- (ROBLOX-128: kept, not made anew each frame)
	table.clear(present)
	local shimmer = FlyLook.wing.fan.shimmer
	local FAR = FlyLook.far
	for _, fly in flies do
		present[fly.id] = true
		local kind: string? = if fly.profile and FlyLook.small[fly.profile.body.prey_kind or ""] ~= nil then fly.profile.body.prey_kind else nil
		if kind ~= nil and fly.legsLost ~= nil and fly.legsLost > 0 then kind = kind .. "+shed" end -- (ROBLOX-101)
		local rig = self.rigs[fly.id]
		if rig ~= nil and rig.kind ~= kind then
			rig.folder:Destroy()
			rig = nil
		end
		rig = rig or self:spawn(fly.id, kind)
		local template: Template = rig.template or self.template
		local meal=if heldView and heldView.id==fly.id then heldView else nil
  local captured=fly.state=="CAPTURED"
  local poseChanged=rig.captured~=captured
  rig.captured=captured
  local flying = fly:airborne() or (captured and (meal==nil or meal.struggling))
  local scale = FlyLook.drawnScale(fly.profile)*(if meal then meal.scale else 1)
		rig.fruit = fly.profile ~= nil and fly.profile.body.prey_kind == "fruit_fly"
		if flying ~= rig.flying or rig.scale ~= scale or poseChanged then rig.scale = scale; self:pose(rig, flying) end
		-- the far rule: drawn ten times a second beyond FAR.studs of the camera, with all the time since
		rig.owed += dtAll
		if rig.drawn and cameraAt ~= nil and (cameraAt - fly.position).Magnitude > FAR.studs and rig.owed < FAR.seconds - 1e-6 then continue end
		local dt = rig.owed
		rig.owed = 0
		rig.drawn = true
		local heading = fly.heading
		-- the back is up: a fly in the air has no surface (the normal it carries is the one it last stood on, which would roll it sideways after
		-- a take-off from a wall), so it keeps its back to the sky; a held fly follows the spider's grip
		local normal = if fly:airborne() then Vector3.yAxis else fly.normal
		rig.captured = fly.state == "CAPTURED"
		self:advance(rig, fly, dt, flying, normal)
		local up = if math.abs(heading.Unit:Dot(normal)) > 0.999 then Vector3.zAxis else normal -- a heading along the normal has no turn to give
		local position = fly.position - normal * (if flying then 0 else FlyLook.hover * (1 - scale))
		local body = if meal then meal.frame else CFrame.lookAt(position, position + heading, up)
		local M = template.motion
		local tip = bodyMove(rig, fly, M, flying, still, rig.seed)
		if tip ~= nil and meal==nil then body *= CFrame.new(tip.Position * scale) * tip.Rotation end
		local poses = if flying then template.flightFrames else template.restFrames
		for i, part in rig.parts do
			local localFrame = poses[i]
			local a = template.anim[i]
			if a ~= nil then
				local move = moveOf(a, rig, M, flying, still, rig.seed)
				if move ~= nil then localFrame = move * localFrame end
			end
			local frame = body * (CFrame.new(localFrame.Position * scale) * localFrame.Rotation)
			if flying and template.fans[i] and not still and not beats(M) then frame *= CFrame.Angles(math.sin(now * shimmer[1] + i) * shimmer[2], 0, 0) end
			table.insert(parts, part)
			table.insert(frames, frame)
		end
	end
	for id, rig in self.rigs do
		if not present[id] then
			rig.folder:Destroy()
			self.rigs[id] = nil
		end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	self.moved = #parts -- (ROBLOX-111: the parts placed this frame, for the self-test's frame profile)
end

return FlyBodies
