--!strict
-- The drawn spider for Roblox: a port of scripts/presentation/spider_body.gd and surface_legs.gd (VISUAL-01 look), made cuter in
-- ROBLOX-13. Every part is anchored, non-colliding and non-queryable, and is placed each frame with one Workspace:BulkMoveTo call.
-- Display only: the controller owns the body's CFrame; nothing here feeds back into movement.
-- Body frame: +Y support-up, -Z forward, about 1 stud long (1 Godot WU = 1 cm = 1 stud). Every look number is in
-- Data/Appearances; where things sit comes from Rig/Anatomy, the hairs from Rig/Setae, the idle motion from Rig/Idle.

local Workspace = game:GetService("Workspace")
local Appearances = require(script.Parent.Parent.Data.Appearances)
local Anatomy = require(script.Parent.Anatomy)
local Setae = require(script.Parent.Setae)
local Idle = require(script.Parent.Idle)
local v3 = Anatomy.v3

local SpiderRig = {}
SpiderRig.__index = SpiderRig

export type GaitMode = "Tetrapod" | "Unilateral"

local STEP_ERROR = 0.24
local SWING_SECONDS = 0.10
local STEP_HEIGHT = 0.12
local ANKLE_SHARE = 0.62
-- The groups a fixed part follows: the body, the head (tilts about the neck) or the abdomen (breathes).
local G_BODY, G_HEAD, G_ABDOMEN = 0, 1, 2

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
	pad: Part?,
	bands: {Part},
	hairs: { { part: Part, spec: Setae.LegHair } },
}

type Fixed = { part: Part, offset: CFrame, group: number, palp: number? }

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
		_calm: number,
		_spots: { Part },
		_appearance: any,
		_layout: Anatomy.Layout,
		_cfg: any,
		_detail: string,
		_palpBase: { Vector3 },
		_setae: { Part },
		_eyeView: boolean,
		_bodyHidden: boolean,
		_highlight: Highlight?,
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

-- A hair's "up" for lookAt: its surface normal, unless that is (nearly) along the hair.
local function upFor(dir: Vector3, normal: Vector3): Vector3
	if math.abs(dir:Dot(normal)) < 0.97 then return normal end
	return if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.zAxis
end

local GROUP_OF: { [string]: number } = { head = G_HEAD, abdomen = G_ABDOMEN }

-- detail "low" is for phones and tablets: fewer hairs, one fur shell, no foot balls, half the speckles, no outline, no
-- breathing or head tilt (Appearances.detail). Anything else is the full look.
function SpiderRig.new(parent: Instance, worldFolder: Instance, appearanceId: string?, detail: string?): Rig
	local look = Appearances.profiles[appearanceId or Appearances.default]
	assert(look, "Unknown spider appearance")
	local detailName = if detail == "low" then "low" else "full"
	local cfg = look.detail[detailName]
	local A = Anatomy.layout(look)
	local function color(rgb): Color3 return Color3.new(rgb[1], rgb[2], rgb[3]) end
	local BODY, LEG = color(look.body), color(look.legs)
	local JOINT, EYE, FANG = color(look.white), color(look.eyes), color(look.fangs)
	local WHITE = color(look.white)
	local model = Instance.new("Model")
	model.Name = "Spider"
	model:SetAttribute("AppearanceId", look.id)
	model:SetAttribute("Detail", detailName)
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
		_calm = 0,
		_spots = {} :: { Part },
		_appearance = look,
		_layout = A,
		_cfg = cfg,
		_detail = detailName,
		_palpBase = { A.palps[1].base, A.palps[2].base },
		_setae = {} :: { Part },
		_eyeView = false,
		_bodyHidden = false,
		_highlight = nil :: Highlight?,
		_params = params,
		_parts = {} :: { BasePart },
		_cframes = {} :: { CFrame },
	}, SpiderRig)

	local function fixed(part: Part, at: Vector3, rot: CFrame?, group: number, palp: number?)
		table.insert(self._fixed, { part = part, offset = CFrame.new(at) * (rot or CFrame.identity), group = group, palp = palp })
	end
	local fabric = Enum.Material.SmoothPlastic -- clean high-contrast silhouette
	fixed(ellipsoid(model, "Cephalothorax", A.headRadii, BODY, fabric), A.headCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "EyeFace", A.faceRadii, BODY, fabric), A.faceCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "Pedicel", A.pedicelRadii, BODY, fabric), A.pedicelCenter, nil, G_BODY)
	fixed(ellipsoid(model, "Abdomen", A.abdomenRadii, BODY, fabric), A.abdomenCenter, nil, G_ABDOMEN)

	-- The daughter's pattern: markings are fractions of the abdomen's radii.
	local ar, ac = A.abdomenRadii, A.abdomenCenter
	local function marking(name: string, x: number, z: number, rx: number, rz: number, angle: number)
		local y = ar.Y * math.sqrt(math.max(0, 1 - x*x - z*z))
		local spot = ellipsoid(model, name, Vector3.new(rx, 0.012, rz), WHITE, fabric)
		spot.CastShadow = false
		fixed(spot, Vector3.new(x * ar.X, ac.Y + 0.007 + y, ac.Z + z * ar.Z), CFrame.Angles(0, angle, 0), G_ABDOMEN)
		table.insert(self._spots, spot)
	end
	-- A curved pale band across the front of the abdomen.
	local band = look.band
	for i = 0, band.count - 1 do
		marking("FrontBand", (i - (band.count - 1) / 2) * band.step, band.z, band.rx, band.rz, 0)
	end
	for _, spot in look.spots do
		marking("AbdomenSpot", spot.x, spot.z, spot.rx, spot.rz, spot.angle)
	end
	-- Fixed deterministic stippling: no per-frame RNG or extra updates.
	local sp = look.speckle
	for i = 1, look.speckleCount do
		if i % cfg.speckleEvery ~= 0 then continue end
		local angle = i * 2.399963229728653
		local radius = sp.from + (i % 5) * sp.step
		marking("Speckle", math.cos(angle) * radius, math.sin(angle) * radius, sp.rx, sp.rz, angle)
	end

	-- Head: pale cheeks, big glossy eyes with their catchlights, jaws.
	for _, c in A.cheeks do
		local cheek = ellipsoid(model, "PaleCheek", c.radii, WHITE, fabric)
		cheek.CastShadow = false
		fixed(cheek, c.at, nil, G_HEAD)
	end
	local SOCKET = color(look.eye.ame.socket.color)
	for _, e in A.eyes do
		local eye = ellipsoid(model, e.name, e.radii, EYE, Enum.Material.Glass)
		eye.Reflectance = e.reflectance
		eye.CastShadow = false
		fixed(eye, e.at, nil, G_HEAD)
		if e.principal and cfg.sockets then
			local socket = ellipsoid(model, "EyeSocket", e.radii * look.eye.ame.socket.scale, SOCKET, fabric)
			socket.CastShadow = false
			fixed(socket, e.at + Vector3.new(0, 0, 0.03), nil, G_HEAD)
		end
	end
	local GLINT = color(look.eye.glintColor)
	for _, g in A.glints do
		local glint = ellipsoid(model, "Catchlight", g.radii, GLINT, Enum.Material.Neon)
		glint.CastShadow = false
		fixed(glint, g.at, nil, G_HEAD)
	end
	local cl = look.chelicerae
	for _, j in A.jaws do
		local fang = ellipsoid(model, "Chelicera", j.radii, FANG, Enum.Material.Foil)
		fang.Reflectance = cl.reflectance
		fixed(fang, j.at, CFrame.Angles(cl.pitch, 0, j.side * cl.splay), G_HEAD)
	end
	-- Pedipalps: stalk, pale band, club and pale tip, rotating about a pivot at the base (they drum when the spider stands).
	local pl = look.palp
	for index, palp in A.palps do
		local base, tip = palp.base, palp.tip
		local len = (tip - base).Magnitude
		local toBase = CFrame.new(base):Inverse()
		local stalk = rod(model, "PalpStalk", pl.stalk, LEG)
		stalk.Size = Vector3.new(len, pl.stalk, pl.stalk)
		fixed(stalk, Vector3.zero, toBase * rodCFrame(base, tip), G_HEAD, index)
		local ring = rod(model, "PalpBand", pl.stalk * 1.05, WHITE)
		ring.Size = Vector3.new(len * look.bandFraction, pl.stalk * 1.05, pl.stalk * 1.05)
		fixed(ring, Vector3.zero, toBase * rodCFrame(base, tip), G_HEAD, index)
		fixed(ellipsoid(model, "PalpClub", v3(pl.club), LEG, fabric), tip + Vector3.new(0, -0.005, -0.02) - base, nil, G_HEAD, index)
		fixed(ellipsoid(model, "PalpTip", v3(pl.tipRadii), JOINT, fabric), tip + Vector3.new(0, 0.004, -0.05) - base, nil, G_HEAD, index)
	end

	-- Fuzz: flat locks over the head and abdomen, tufts, a cheek ruff and palp fluff (Rig/Setae), moved with the part they grow from.
	local fuzz = look.fuzz
	local DARK = if fuzz then color(fuzz.dark) else BODY
	local GREY = if fuzz then color(fuzz.grey) else BODY
	local FROST = if fuzz then color(fuzz.frost) else BODY
	local function seta(tone: string, width: number, thick: number, length: number, transparency: number): Part
		local h = newPart(model, "Seta", if tone == "white" then WHITE elseif tone == "frost" then FROST elseif tone == "grey" then GREY else DARK, Enum.Material.SmoothPlastic)
		h.Size = Vector3.new(width, thick, length)
		h.CastShadow = false
		h.Transparency = transparency
		table.insert(self._setae, h)
		return h
	end
	if fuzz and fuzz.enabled then
		local SHELL = color(fuzz.shellColor)
		local hr, hs = A.headRadii, fuzz.headShell
		for k, shell in fuzz.shells do
			if k > cfg.shells then break end
			local a = ellipsoid(model, "FuzzShell", A.abdomenRadii * shell.scale, SHELL, fabric)
			a.Transparency, a.CastShadow = shell.transparency, false
			fixed(a, A.abdomenCenter, nil, G_ABDOMEN)
			local h = ellipsoid(model, "FuzzShell", Vector3.new(hr.X * shell.scale, hr.Y * shell.scale, hr.Z * hs.zScale), SHELL, fabric)
			h.Transparency, h.CastShadow = shell.transparency, false
			fixed(h, A.headCenter + Vector3.new(0, 0, hs.shift + 0.01 * k), nil, G_HEAD)
		end
		local seen: { [string]: number } = {}
		local function keep(kind: string): boolean
			local n = (seen[kind] or 0) + 1
			seen[kind] = n
			return n % (cfg.every[kind] or 1) == 0
		end
		for _, hair in Setae.body(look) do
			if not keep(hair.kind) then continue end
			local h = seta(hair.tone, hair.width, hair.thick, hair.length, hair.transparency)
			local mid = hair.at + hair.dir * (hair.length * 0.5)
			fixed(h, mid, CFrame.lookAt(Vector3.zero, hair.dir, upFor(hair.dir, hair.normal)), GROUP_OF[hair.group] or G_BODY)
		end
		for _, hair in Setae.palp(look) do
			if not keep("palp") then continue end
			local index = if hair.side < 0 then 1 else 2
			local h = seta(hair.tone, hair.width, hair.thick, hair.length, hair.transparency)
			local mid = hair.at + hair.dir * (hair.length * 0.5)
			local rest = CFrame.lookAt(mid, mid + hair.dir, upFor(hair.dir, hair.normal))
			fixed(h, Vector3.zero, CFrame.new(self._palpBase[index]):Inverse() * rest, G_HEAD, index)
		end
	end

	-- Legs: plump, with rounded joints and (at full detail) round feet.
	local L = look.limbs
	for i = 1, 8 do
		local side = if i <= 4 then -1 else 1
		local pair = (i - 1) % 4 + 1
		local raw = L.diameters[pair]
		local factor = (if pair == 1 then look.frontLegScale else 1) * L.thickness
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
			pad = if cfg.pads then ball(model, "Foot" .. i, d[2] * 0.6 * L.pad, LEG) else nil,
			bands = {rod(model, "FemurBand" .. i, d[1], WHITE), rod(model, "TibiaBand" .. i, d[2], WHITE), rod(model, "TarsusBand" .. i, d[2] * 0.6, WHITE)},
			hairs = {},
		})
		local leg = self._legs[#self._legs]
		if fuzz and fuzz.enabled then
			for n, spec in Setae.leg(look, i) do
				if n % cfg.every.leg ~= 0 then continue end
				table.insert(leg.hairs, { part = seta(spec.tone, fuzz.legWidth, fuzz.legWidth, spec.length, fuzz.legTransparency), spec = spec })
			end
		end
	end
	if cfg.highlight then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = WHITE
		hl.OutlineTransparency = 0.82
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
		self._highlight = hl
	end
	model.Parent = parent
	self:setGrowthStage(0)
	return self
end

-- The selected appearance stays black and white at every life stage.
-- Growth is a separate display scale when LIFE is ported; it must not recolor this design.
function SpiderRig.setGrowthStage(self: Rig, stage: number)
	self.model:SetAttribute("GrowthStage", math.clamp(stage, 0, 3))
end

-- How many parts the drawn spider is made of (the model's direct parts), for budgets and the docs.
function SpiderRig.count(self: Rig): { total: number, hairs: number, shells: number, body: number }
	local total, hairs, shells = 0, 0, 0
	for _, part in self.model:GetChildren() do
		if part:IsA("BasePart") then
			total += 1
			if part.Name == "Seta" then hairs += 1 elseif part.Name == "FuzzShell" then shells += 1 end
		end
	end
	return { total = total, hairs = hairs, shells = shells, body = total - hairs - shells }
end

local function legGroup(self: Rig, i: number): number
	if self.gaitMode == "Unilateral" then
		return if i <= 4 then 0 else 1
	end
	-- Godot's (i % 4 + i / 4) % 2 with 0-based i: L1 R2 L3 R4 against R1 L2 R3 L4.
	local j = i - 1
	return (j % 4 + j // 4) % 2
end

local function restLocal(self: Rig, leg: Leg): Vector3
	local s = self._appearance.limbs.stance
	return Vector3.new(leg.side * s.x * s.reach, s.y, self._appearance.limbs.tipZ[leg.pair] * s.reach)
end

-- Display-only foothold: retract toward the body at a narrow edge; never invents a platform.
local function target(self: Rig, body: CFrame, leg: Leg): RaycastResult?
	local up = body.UpVector
	local rest = restLocal(self, leg)
	for _, reach in { 1.0, 0.65, 0.35, 0.12 } do
		local point = body:PointToWorldSpace(Vector3.new(rest.X * reach, 0, rest.Z * reach))
		local hit = Workspace:Raycast(point + up * 0.35, -up * 1.0, self._params)
		if hit and hit.Normal:Dot(up) > 0.35 then
			return hit
		end
	end
	return nil
end

-- body: the drawn body's CFrame. grounded: standing on a surface. moving: walking speed > 0 (for palp drumming and idle motion).
function SpiderRig.update(self: Rig, body: CFrame, dt: number, grounded: boolean, moving: boolean)
	self._t += dt
	local up = body.UpVector
	local look, cfg, A = self._appearance, self._cfg, self._layout
	local parts, cframes = self._parts, self._cframes
	table.clear(parts)
	table.clear(cframes)
	local function put(p: BasePart, cf: CFrame)
		table.insert(parts, p)
		table.insert(cframes, cf)
	end
	put(self.root, body)

	-- Palps drum in bursts while the spider stands still; breathing and a curious head tilt ease in after a moment. All of
	-- it is full detail only (cfg.idle), and reducedMotion turns it off too.
	local standing = cfg.idle and grounded and not moving and not self.reducedMotion
	self._drum = math.clamp(self._drum + (if standing then 3 else -3) * dt, 0, 1)
	local palpAngle = Idle.palps(self._t, self._drum, look.palp)
	local bodyBase, headBase, abdomenBase = body, body, body
	if cfg.idle then
		local idle = look.idle
		self._calm = math.clamp(self._calm + (if standing then dt / idle.riseSeconds else -dt / idle.fallSeconds), 0, 1)
		if self._calm > 0 then
			local c = self._calm * self._calm * (3 - 2 * self._calm)
			local pose = Idle.pose(self._t, c, idle)
			bodyBase = body * CFrame.new(0, pose.bodyLift, 0)
			headBase = bodyBase * CFrame.new(A.neck) * CFrame.Angles(pose.headPitch, pose.headYaw, pose.headRoll) * CFrame.new(-A.neck)
			abdomenBase = bodyBase * CFrame.new(0, pose.abdomenLift, 0) * CFrame.new(A.pedicelCenter)
				* CFrame.Angles(-pose.abdomenPitch, 0, 0) * CFrame.new(-A.pedicelCenter)
		end
	end
	local pivots = {
		CFrame.new(self._palpBase[1]) * CFrame.Angles(palpAngle[1], 0, 0),
		CFrame.new(self._palpBase[2]) * CFrame.Angles(palpAngle[2], 0, 0),
	}
	for _, f in self._fixed do
		local base = if f.group == G_HEAD then headBase elseif f.group == G_ABDOMEN then abdomenBase else bodyBase
		local palp = f.palp
		if palp then
			put(f.part, base * pivots[palp] * f.offset)
		else
			put(f.part, base * f.offset)
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
				local err = (body:PointToWorldSpace(restLocal(self, leg)) - leg.planted :: Vector3).Magnitude
				if err > worst then
					worst = err
					self._group = legGroup(self, i)
				end
			end
		end
	end
	local L = look.limbs
	local started = false
	for i, leg in self._legs do
		local rest = body:PointToWorldSpace(restLocal(self, leg))
		if not grounded then
			leg.planted = nil
			leg.swing = -1
			leg.foot = body:PointToWorldSpace(Vector3.new(leg.side * 0.47, -0.12, L.tipZ[leg.pair] * 0.72))
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
	local kneeUp = if grounded then L.kneeLift else L.kneeLiftAir
	for _, leg in self._legs do
		local hip = bodyBase:PointToWorldSpace(Vector3.new(leg.side * L.hipX, L.hipY, L.hipZ[leg.pair]))
		local foot = leg.foot
		local knee = hip:Lerp(foot, 0.48) + up * kneeUp
		local ankle = knee:Lerp(foot, ANKLE_SHARE) + up * L.ankleLift
		local function segment(index: number, p: Part, band: Part, a: Vector3, b: Vector3)
			local len = math.max((b - a).Magnitude, 0.01)
			if math.abs(p.Size.X - len) > 1e-3 then
				p.Size = Vector3.new(len, p.Size.Y, p.Size.Z)
			end
			local rc = rodCFrame(a, b) -- local +X runs from a toward b (toward the foot)
			put(p, rc)
			band.Size = Vector3.new(len * look.bandFraction, p.Size.Y * 1.035, p.Size.Z * 1.035)
			put(band, rc)
			-- Leg setae stand out from the segment and lean toward the foot.
			local r = p.Size.Y * 0.5
			for _, hair in leg.hairs do
				local spec = hair.spec
				if spec.segment == index then
					local c, s = math.cos(spec.theta), math.sin(spec.theta)
					local base = Vector3.new((spec.t - 0.5) * len, r * 0.8 * c, r * 0.8 * s)
					local dir = Vector3.new(1.3, c, s).Unit
					put(hair.part, rc * CFrame.lookAt(base + dir * (spec.length * 0.5), base + dir * spec.length, Vector3.xAxis))
				end
			end
		end
		segment(1, leg.femur, leg.bands[1], hip, knee)
		segment(2, leg.tibia, leg.bands[2], knee, ankle)
		segment(3, leg.tarsus, leg.bands[3], ankle, foot)
		put(leg.knee, CFrame.new(knee))
		put(leg.ankle, CFrame.new(ankle))
		if leg.pad then put(leg.pad :: Part, CFrame.new(foot)) end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Spider-eye view (Godot SpiderBody.set_eye_view + SurfaceLegs.eye_view): the body, head and palps are hidden and only the
-- front legs' lower segments stay, reaching into the view. Client-only (LocalTransparencyModifier).
local function applyVisibility(self: Rig)
	local function show(p: BasePart, visible: boolean)
		p.LocalTransparencyModifier = if visible then 0 else 1
	end
	local hideBody = self._eyeView or self._bodyHidden
	if self._highlight then (self._highlight :: Highlight).Enabled = not hideBody end
	for _, f in self._fixed do
		show(f.part, not hideBody)
	end
	for _, leg in self._legs do
		local frontReach = self._eyeView and leg.pair == 1
		local all = not hideBody
		show(leg.femur, all); show(leg.bands[1], all); show(leg.knee, all)
		show(leg.tibia, all or frontReach); show(leg.bands[2], all or frontReach)
		show(leg.tarsus, all or frontReach); show(leg.bands[3], all or frontReach); show(leg.ankle, all or frontReach)
		if leg.pad then show(leg.pad :: Part, all or frontReach) end
		for _, hair in leg.hairs do
			show(hair.part, all or (frontReach and hair.spec.segment >= 2))
		end
	end
end

function SpiderRig.setEyeView(self: Rig, on: boolean)
	self._eyeView = on
	applyVisibility(self)
end

-- The orbit camera hides the spider when its boom is squeezed shorter than BODY_HIDE_LENGTH.
function SpiderRig.setBodyHidden(self: Rig, hidden: boolean)
	self._bodyHidden = hidden
	applyVisibility(self)
end

-- Where the dragline leaves the body.
function SpiderRig.spinneretPoint(self: Rig, body: CFrame): Vector3
	return body:PointToWorldSpace(self._layout.spinneret)
end

function SpiderRig.destroy(self: Rig)
	self.model:Destroy()
end

return SpiderRig
