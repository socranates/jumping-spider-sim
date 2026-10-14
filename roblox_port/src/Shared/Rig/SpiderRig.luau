--!strict
-- The drawn spider for Roblox: a port of scripts/presentation/spider_body.gd and surface_legs.gd (VISUAL-01 look).
-- Every part is anchored, non-colliding and non-queryable, and is placed each frame with one Workspace:BulkMoveTo call.
-- Display only: the controller owns the body's CFrame; nothing here feeds back into movement.
-- Body frame: +Y support-up, -Z forward, about 1 stud long (1 Godot WU = 1 cm = 1 stud).

local Workspace = game:GetService("Workspace")
local Appearances = require(script.Parent.Parent.Data.Appearances)

local SpiderRig = {}
SpiderRig.__index = SpiderRig

export type GaitMode = "Tetrapod" | "Unilateral"

local HIP_Z = { -0.36, -0.24, -0.12, 0.0 }
local TIP_Z = { -0.82, -0.52, 0.12, 0.62 }
-- Stout front legs, slimmer back legs: { femur, tibia } diameters per pair.
local LEG_D = { { 0.078, 0.064 }, { 0.065, 0.053 }, { 0.057, 0.045 }, { 0.059, 0.047 } }
local STEP_ERROR = 0.24
local SWING_SECONDS = 0.10
local STEP_HEIGHT = 0.12
local ANKLE_SHARE = 0.62
local ANKLE_LIFT = 0.045
local PALP_DRUM_HZ = 3.2
local PALP_DRUM_DEG = 11


type Leg = {
	side: number,
	pair: number,
	planted: Vector3?,
	swing: number, -- < 0 planted, 0..1 swinging
	from: Vector3,
	to: Vector3,
	up: Vector3,
	foot: Vector3,
	femur: Part,
	tibia: Part,
	tarsus: Part,
	knee: Part,
	ankle: Part,
	bands: {Part},
}

type Fixed = { part: Part, offset: CFrame, palp: number? }

export type Rig = typeof(setmetatable(
	{} :: {
		model: Model,
		root: Part,
		gaitMode: GaitMode,
		reducedMotion: boolean,
		_fixed: { Fixed },
		_legs: { Leg },
		_group: number,
		_t: number,
		_drum: number,
		_spots: { Part },
	_appearance: any,
		_params: RaycastParams,
		_parts: { BasePart },
		_cframes: { CFrame },
	},
	SpiderRig
))

local function newPart(model: Model, name: string, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = model
	return p
end

local function ellipsoid(model: Model, name: string, radii: Vector3, color: Color3, material: Enum.Material): Part
	local p = newPart(model, name, color, material)
	p.Size = radii * 2
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function rod(model: Model, name: string, d: number, color: Color3): Part
	local p = newPart(model, name, color, Enum.Material.SmoothPlastic)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(1, d, d)
	return p
end

local function ball(model: Model, name: string, d: number, color: Color3): Part
	local p = newPart(model, name, color, Enum.Material.SmoothPlastic)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.CastShadow = false
	return p
end

-- A cylinder's axis is its local X: aim it from a to b.
local function rodCFrame(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) * 0.5, b) * CFrame.Angles(0, math.pi / 2, 0)
end

function SpiderRig.new(parent: Instance, worldFolder: Instance, appearanceId: string?): Rig
	local look = Appearances.profiles[appearanceId or Appearances.default]
	assert(look, "Unknown spider appearance")
	local function color(rgb): Color3 return Color3.new(rgb[1], rgb[2], rgb[3]) end
	local BODY, LEG = color(look.body), color(look.legs)
	local JOINT, EYE, FANG = color(look.white), color(look.eyes), color(look.fangs)
	local WHITE = color(look.white)
	local model = Instance.new("Model")
	model.Name = "Spider"
	model:SetAttribute("AppearanceId", look.id)
	local root = newPart(model, "Root", BODY, Enum.Material.SmoothPlastic)
	root.Size = Vector3.new(1, 0.5, 1)
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { worldFolder }

	local self = setmetatable({
		model = model,
		root = root,
		gaitMode = "Tetrapod" :: GaitMode,
		reducedMotion = false,
		_fixed = {} :: { Fixed },
		_legs = {} :: { Leg },
		_group = 0,
		_t = 0,
		_drum = 0,
		_spots = {} :: { Part },
		_appearance = look,
		_params = params,
		_parts = {} :: { BasePart },
		_cframes = {} :: { CFrame },
	}, SpiderRig)

	local function fixed(part: Part, at: Vector3, rot: CFrame?, palp: number?)
		table.insert(self._fixed, { part = part, offset = CFrame.new(at) * (rot or CFrame.identity), palp = palp })
	end
	local fabric = Enum.Material.SmoothPlastic -- clean high-contrast silhouette
	fixed(ellipsoid(model, "Cephalothorax", Vector3.new(table.unpack(look.headRadii)), BODY, fabric), Vector3.new(0, 0.02, -0.20))
	fixed(ellipsoid(model, "EyeFace", Vector3.new(0.205, 0.165, 0.125), BODY, fabric), Vector3.new(0, 0.055, -0.355))
	fixed(ellipsoid(model, "Pedicel", Vector3.new(0.05, 0.05, 0.06), BODY, fabric), Vector3.new(0, -0.035, -0.06))
	fixed(ellipsoid(model, "Abdomen", Vector3.new(table.unpack(look.abdomenRadii)), BODY, fabric), Vector3.new(0, 0.04, 0.20))
	local ar = look.abdomenRadii
	local function marking(name: string, x: number, z: number, rx: number, rz: number, angle: number)
		local y = ar[2] * math.sqrt(math.max(0, 1 - x*x - z*z))
		local spot = ellipsoid(model, name, Vector3.new(rx, 0.012, rz), WHITE, fabric)
		fixed(spot, Vector3.new(x * ar[1], 0.047 + y, 0.20 + z * ar[3]), CFrame.Angles(0, angle, 0))
		table.insert(self._spots, spot)
	end
	-- A curved pale band across the front of the abdomen.
	for i = -4, 4 do
		marking("FrontBand", i * 0.16, -0.66, 0.031, 0.018, 0)
	end
	for _, spot in look.spots do
		marking("AbdomenSpot", spot.x, spot.z, spot.rx, spot.rz, spot.angle)
	end
	-- Fixed deterministic stippling: no per-frame RNG or extra updates.
	for i = 1, look.speckleCount do
		local angle = i * 2.399963229728653
		local radius = 0.40 + (i % 5) * 0.10
		marking("Speckle", math.cos(angle) * radius, math.sin(angle) * radius, 0.0035, 0.005, angle)
	end
	for _, side in { -1, 1 } do
		fixed(ellipsoid(model, "PaleCheek", Vector3.new(0.018, 0.066, 0.105), WHITE, fabric), Vector3.new(side * 0.235, 0.055, -0.23))
		local ame = Vector3.new(side * 0.075, 0.09, -0.455)
		local eye = ellipsoid(model, "PrincipalEye", Vector3.new(0.080, 0.080, 0.063), EYE, Enum.Material.Glass)
		eye.Reflectance = 0.35
		fixed(eye, ame)
		local glint = ellipsoid(model, "Catchlight", Vector3.new(0.013, 0.013, 0.006), Color3.new(1, 1, 1), Enum.Material.Neon)
		glint.CastShadow = false
		fixed(glint, ame + Vector3.new(side * -0.018, 0.03, -0.052))
		local secondary: { { at: Vector3, r: number } } = {
			{ at = Vector3.new(side * 0.165, 0.10, -0.40), r = 0.042 }, -- anterior lateral
			{ at = Vector3.new(side * 0.13, 0.17, -0.14), r = 0.048 }, -- posterior lateral
			{ at = Vector3.new(side * 0.11, 0.185, -0.27), r = 0.018 }, -- posterior median
		}
		for _, e in secondary do
			local small = ellipsoid(model, "Eye", Vector3.one * e.r, EYE, Enum.Material.Glass)
			small.Reflectance = 0.3
			fixed(small, e.at)
		end
		local fang = ellipsoid(model, "Chelicera", Vector3.new(0.045, 0.08, 0.04), FANG, Enum.Material.Foil)
		fang.Reflectance = 0.15
		fixed(fang, Vector3.new(side * 0.052, -0.075, -0.445), CFrame.Angles(-0.35, 0, side * 0.12))
		-- Pedipalp: stalk and pale-tipped club, rotating about a pivot at its base.
		local palpIndex = if side < 0 then 1 else 2
		local base = Vector3.new(side * 0.10, -0.035, -0.43)
		local tip = base + Vector3.new(side * 0.03, -0.10, -0.09)
		local stalk = rod(model, "PalpStalk", 0.042, LEG)
		stalk.Size = Vector3.new((tip-base).Magnitude, 0.042, 0.042)
		fixed(stalk, Vector3.zero, CFrame.new(base):Inverse() * rodCFrame(base, tip), palpIndex)
		local ring = rod(model, "PalpBand", 0.044, WHITE)
		ring.Size = Vector3.new((tip-base).Magnitude * look.bandFraction, 0.044, 0.044)
		fixed(ring, Vector3.zero, CFrame.new(base):Inverse() * rodCFrame(base, tip), palpIndex)
		fixed(ellipsoid(model, "PalpClub", Vector3.new(0.03, 0.03, 0.045), LEG, fabric), tip + Vector3.new(0, -0.005, -0.02) - base, nil, palpIndex)
		fixed(ellipsoid(model, "PalpTip", Vector3.new(0.022, 0.018, 0.022), JOINT, fabric), tip + Vector3.new(0, 0.006, -0.045) - base, nil, palpIndex)
	end
	for i = 1, 8 do
		local side = if i <= 4 then -1 else 1
		local pair = (i - 1) % 4 + 1
		local raw = LEG_D[pair]
		local factor = if pair == 1 then look.frontLegScale else 1
		local d = {raw[1] * factor, raw[2] * factor}
		table.insert(self._legs, {
			side = side,
			pair = pair,
			planted = nil :: Vector3?,
			swing = -1,
			from = Vector3.zero,
			to = Vector3.zero,
			up = Vector3.yAxis,
			foot = Vector3.zero,
			femur = rod(model, "Femur" .. i, d[1], LEG),
			tibia = rod(model, "Tibia" .. i, d[2], LEG),
			tarsus = rod(model, "Tarsus" .. i, d[2] * 0.6, LEG),
			knee = ball(model, "Knee" .. i, d[1] * 0.95, JOINT),
			ankle = ball(model, "Ankle" .. i, d[2] * 0.95, JOINT),
			bands = {rod(model, "FemurBand" .. i, d[1], WHITE), rod(model, "TibiaBand" .. i, d[2], WHITE), rod(model, "TarsusBand" .. i, d[2] * 0.6, WHITE)},
		})
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = WHITE
	hl.OutlineTransparency = 0.82
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	model.Parent = parent
	self:setGrowthStage(0)
	return self
end

-- The selected appearance stays black and white at every life stage.
-- Growth is a separate display scale when LIFE is ported; it must not recolor this design.
function SpiderRig.setGrowthStage(self: Rig, stage: number)
	self.model:SetAttribute("GrowthStage", math.clamp(stage, 0, 3))
end

local function legGroup(self: Rig, i: number): number
	if self.gaitMode == "Unilateral" then
		return if i <= 4 then 0 else 1
	end
	-- Godot's (i % 4 + i / 4) % 2 with 0-based i: L1 R2 L3 R4 against R1 L2 R3 L4.
	local j = i - 1
	return (j % 4 + j // 4) % 2
end

local function restLocal(leg: Leg): Vector3
	return Vector3.new(leg.side * 0.78, -0.30, TIP_Z[leg.pair])
end

-- Display-only foothold: retract toward the body at a narrow edge; never invents a platform.
local function target(self: Rig, body: CFrame, leg: Leg): RaycastResult?
	local up = body.UpVector
	local rest = restLocal(leg)
	for _, reach in { 1.0, 0.65, 0.35, 0.12 } do
		local point = body:PointToWorldSpace(Vector3.new(rest.X * reach, 0, rest.Z * reach))
		local hit = Workspace:Raycast(point + up * 0.35, -up * 1.0, self._params)
		if hit and hit.Normal:Dot(up) > 0.35 then
			return hit
		end
	end
	return nil
end

-- body: the drawn body's CFrame. grounded: standing on a surface. moving: walking speed > 0 (for palp drumming).
function SpiderRig.update(self: Rig, body: CFrame, dt: number, grounded: boolean, moving: boolean)
	self._t += dt
	local up = body.UpVector
	local parts, cframes = self._parts, self._cframes
	table.clear(parts)
	table.clear(cframes)
	local function put(p: BasePart, cf: CFrame)
		table.insert(parts, p)
		table.insert(cframes, cf)
	end
	put(self.root, body)

	-- Palps drum in bursts while the spider stands still.
	self._drum = math.clamp(self._drum + (if grounded and not moving and not self.reducedMotion then 3 else -3) * dt, 0, 1)
	local palpAngle = {}
	for k = 1, 2 do
		local burst = math.clamp((math.sin(self._t * 1.3 + 0.7 * k) - 0.55) / 0.3, 0, 1)
		local beat = math.max(0, math.sin(self._t * 2 * math.pi * PALP_DRUM_HZ + math.pi * k))
		palpAngle[k] = math.rad(PALP_DRUM_DEG) * self._drum * burst * beat
	end
	for _, f in self._fixed do
		if f.palp then
			local side = if f.palp == 1 then -1 else 1
			local pivot = CFrame.new(side * 0.10, -0.035, -0.43) * CFrame.Angles(palpAngle[f.palp], 0, 0)
			put(f.part, body * pivot * f.offset)
		else
			put(f.part, body * f.offset)
		end
	end

	-- Legs: planted feet stay put in the world; a leg too far from its rest spot steps, in alternating groups.
	local swinging = false
	for _, leg in self._legs do
		swinging = swinging or leg.swing >= 0
	end
	if grounded and not swinging then
		local worst = STEP_ERROR
		for i, leg in self._legs do
			if leg.planted then
				local err = (body:PointToWorldSpace(restLocal(leg)) - leg.planted :: Vector3).Magnitude
				if err > worst then
					worst = err
					self._group = legGroup(self, i)
				end
			end
		end
	end
	local started = false
	for i, leg in self._legs do
		local rest = body:PointToWorldSpace(restLocal(leg))
		if not grounded then
			leg.planted = nil
			leg.swing = -1
			leg.foot = body:PointToWorldSpace(Vector3.new(leg.side * 0.47, -0.12, TIP_Z[leg.pair] * 0.72))
		else
			if leg.planted == nil then
				local hit = target(self, body, leg)
				leg.planted = if hit then hit.Position else nil
				leg.foot = if hit then hit.Position else rest + up * 0.16
				leg.swing = -1
			end
			local anchor = leg.planted
			if anchor then
				if leg.swing >= 0 then
					leg.swing = math.min(1, leg.swing + dt / SWING_SECONDS)
					local s = leg.swing
					local smooth = s * s * (3 - 2 * s)
					leg.foot = leg.from:Lerp(anchor, smooth) + leg.up * math.sin(math.pi * s) * STEP_HEIGHT
					if leg.swing >= 1 then
						leg.swing = -1
						leg.foot = anchor
					end
				else
					leg.foot = anchor
					local err = (rest - anchor).Magnitude
					if err > STEP_ERROR and ((not swinging and legGroup(self, i) == self._group) or err > 0.60) then
						local hit = target(self, body, leg)
						if hit and (anchor - hit.Position).Magnitude > 0.12 then
							leg.from = anchor
							leg.planted = hit.Position
							leg.up = hit.Normal
							leg.swing = 0
							started = true
						end
					end
					if body:PointToObjectSpace(leg.foot).Magnitude > 1.4 then
						leg.planted = nil
						leg.foot = rest
					end
				end
			end
		end
	end
	if started then
		self._group = 1 - self._group
	end
	for _, leg in self._legs do
		local hip = body:PointToWorldSpace(Vector3.new(leg.side * 0.16, 0.02, HIP_Z[leg.pair]))
		local foot = leg.foot
		local knee = hip:Lerp(foot, 0.48) + up * (if grounded then 0.30 else 0.24)
		local ankle = knee:Lerp(foot, ANKLE_SHARE) + up * ANKLE_LIFT
		local function segment(p: Part, band: Part, a: Vector3, b: Vector3)
			local len = math.max((b - a).Magnitude, 0.01)
			if math.abs(p.Size.X - len) > 1e-3 then
				p.Size = Vector3.new(len, p.Size.Y, p.Size.Z)
			end
			put(p, rodCFrame(a, b))
			band.Size = Vector3.new(len * self._appearance.bandFraction, p.Size.Y * 1.035, p.Size.Z * 1.035)
			put(band, rodCFrame(a, b))
		end
		segment(leg.femur, leg.bands[1], hip, knee)
		segment(leg.tibia, leg.bands[2], knee, ankle)
		segment(leg.tarsus, leg.bands[3], ankle, foot)
		put(leg.knee, CFrame.new(knee))
		put(leg.ankle, CFrame.new(ankle))
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Where the dragline leaves the body.
function SpiderRig.spinneretPoint(_self: Rig, body: CFrame): Vector3
	return body:PointToWorldSpace(Vector3.new(0, 0.06, 0.48))
end

function SpiderRig.destroy(self: Rig)
	self.model:Destroy()
end

return SpiderRig
