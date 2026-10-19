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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlyLook = require(Shared:WaitForChild("Data"):WaitForChild("FlyLook"))
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))

local FlyBodies = {}
FlyBodies.__index = FlyBodies

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
type Template = {
	specs: { Spec },
	restFrames: { CFrame },
	flightFrames: { CFrame },
	changing: { number }, -- the parts that differ between the poses: legs, wings, veins, films, the shadow
	fans: { [number]: boolean }, -- the wing parts, which tremble a little as a blur in flight
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

local function build(): Template
	local C = FlyLook.colors
	local specs: { Spec } = {}
	local fans: { [number]: boolean } = {}
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
				add(`{word}{stand.name}{label}`, true, color(tint), "SmoothPlastic", 0,
					{ size = size0, frame = frame0, transparency = 0 }, { size = size1, frame = frame1, transparency = 0 })
			end
			segment("Femur", L.femur, "femur", 1, 2, 0, L.overlap)
			segment("Tibia", L.tibia, "tibia", 2, 3, L.overlap, 0)
		end
	end

	-- bristles
	local B = FlyLook.bristles
	local n = 0
	for _, item in B.items do
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

		fans[add(`{word}Wing`, false, color("wing"), "Glass", W.reflectance,
			{ size = restSize, frame = wing, transparency = W.transparency }, { size = fanSize, frame = fan, transparency = W.fan.transparency })] = true
		local V = W.vein
		local from, to = wing * Vector3.new(side * V.offset, W.thick, V.from * W.length), wing * Vector3.new(side * V.offset, W.thick, V.to * W.length)
		local veinSize, veinFrame = rodBetween(from, to, V.diameter, 0, 0)
		add(`{word}Vein`, true, color("vein"), "SmoothPlastic", 0,
			{ size = veinSize, frame = veinFrame, transparency = V.transparency }, { size = veinSize, frame = veinFrame, transparency = 1 })
		local F = W.film
		fans[add(`{word}Film`, false, color("film"), "SmoothPlastic", 0,
			{ size = restSize + Vector3.new(F.grow, 0, F.grow), frame = wing * CFrame.new(0, F.rise, 0), transparency = F.transparency },
			{ size = filmFanSize, frame = filmFan * CFrame.new(0, F.rise, 0), transparency = W.fan.film.transparency })] = true
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
	return { specs = specs, restFrames = restFrames, flightFrames = flightFrames, changing = changing, fans = fans }
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
		add(item.name, false, color(item.color), "SmoothPlastic", item.reflectance or 0, { size = size, frame = frame, transparency = 0 })
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
			add(word .. item.name, true, color(item.color), "SmoothPlastic", 0, { size = size0, frame = frame0, transparency = 0 }, flight)
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
	return { specs = specs, restFrames = restFrames, flightFrames = flightFrames, changing = changing, fans = fans }
end

-- `detail` (ROBLOX-101): the client's detail tier, "full" (the default) or "low", for the sheets that draw fewer parts at low.
function FlyBodies.new(parent: Instance, detail: string?): any
	local folder = Instance.new("Folder")
	folder.Name = "Flies"
	folder.Parent = parent
	return setmetatable({ folder = folder, rigs = {}, template = build(), templates = {} :: { [string]: Template }, parts = {}, frames = {}, detail = detail or "full" }, FlyBodies)
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
	local rig = { folder = folder, parts = parts, flying = false, kind = kind, template = template }
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
		rig.parts[i].Transparency = if rig.scale == 0.6 and string.find(spec.name, "Stripe") then 1 else pose.transparency
		local name = spec.name
		rig.parts[i].Color = if rig.scale == 0.6 and (name == "Head" or name == "Thorax" or name == "Abdomen" or name == "Face") then Color3.fromRGB(178, 132, 65)
			elseif rig.scale == 0.6 and (name == "EyeL" or name == "EyeR") then Color3.fromRGB(176, 39, 24) else spec.color
	end
end

function FlyBodies.draw(self: any, flies: { any }, now: number)
	local parts: { BasePart } = self.parts
	local frames: { CFrame } = self.frames
	table.clear(parts)
	table.clear(frames)
	local present: { [string]: boolean } = {}
	local shimmer = FlyLook.wing.fan.shimmer
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
		local flying = fly:airborne() or fly.state == "CAPTURED"
		local scale = if fly.profile then fly.profile.body.visual_scale or 1 else 1
		if flying ~= rig.flying or rig.scale ~= scale then rig.scale = scale; self:pose(rig, flying) end
		local heading = fly.heading
		-- the back is up: a fly in the air has no surface (the normal it carries is the one it last stood on, which would roll it sideways after
		-- a take-off from a wall), so it keeps its back to the sky; a held fly follows the spider's grip
		local normal = if fly:airborne() then Vector3.yAxis else fly.normal
		local up = if math.abs(heading.Unit:Dot(normal)) > 0.999 then Vector3.zAxis else normal -- a heading along the normal has no turn to give
		local position = fly.position - normal * (if flying then 0 else FlyLook.hover * (1 - scale))
		local body = CFrame.lookAt(position, position + heading, up)
		local poses = if flying then template.flightFrames else template.restFrames
		for i, part in rig.parts do
			local localFrame = poses[i]
			local frame = body * (CFrame.new(localFrame.Position * scale) * localFrame.Rotation)
			if flying and template.fans[i] then frame *= CFrame.Angles(math.sin(now * shimmer[1] + i) * shimmer[2], 0, 0) end
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
end

return FlyBodies
