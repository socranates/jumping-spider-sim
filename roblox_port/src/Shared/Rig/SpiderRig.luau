--!strict
-- The drawn spider for Roblox: a port of scripts/presentation/spider_body.gd and surface_legs.gd (VISUAL-01 look), made cuter in
-- ROBLOX-13. Every part is anchored, non-colliding and non-queryable, and is placed each frame with one Workspace:BulkMoveTo call.
-- Display only: the controller owns the body's CFrame; nothing here feeds back into movement.
-- Body frame: +Y support-up, -Z forward, about 1 stud long (1 Godot WU = 1 cm = 1 stud). Every look number is in
-- Data/Appearances; where things sit comes from Rig/Anatomy, the hairs from Rig/Setae, the idle motion from Rig/Idle.
-- The peacock spider (ROBLOX-30) is a second appearance drawn by the same code: a small body (look.scale) standing low (look.bodyDrop),
-- legs III in their own colours, and a fan of flat discs that the courtship dance (Rig/PeacockDance, set as rig.dance) opens.
-- The ant-mimicking spider (ROBLOX-64) is a third: extra body segments (look.extras), glossy cuticle (look.gloss), and a pose (Rig/AntMimicPose,
-- set as rig.ant) that raises legs I as antennae when it stands and turns the drawn body a little as it walks.
-- The two tarantulas (ROBLOX-81) are two more: a broad low carapace with a rim (look.extras), an ocular tubercle with eight tiny eyes
-- (Anatomy's tubercle), markings on the abdomen (look.marks), legs coloured segment by segment (look.legColors, look.legBands) and, for the
-- Greenbottle blue, leg bristles only (fuzz.legsOnly) and bars that soften at the last growth stage (look.barFade). A pose (Rig/TarantulaPose, set as
-- rig.threat, ROBLOX-82) rears the prosoma, lifts legs I and the pedipalps, turns the drawn body about and swings the spinnerets.
-- ROBLOX-84 draws the legs, feet, fangs and palps of the first spider and the two tarantulas as the segments they have (look.legForm,
-- look.fang, look.palpForm): the same three-link chain and the same targets, each link now one or two rods, a patella at the knee, a break in
-- the tarsus, a pad (and claws or scopula bristles) at the foot. An appearance without those tables is drawn exactly as it was.

local Workspace = game:GetService("Workspace")
local Appearances = require(script.Parent.Parent.Data.Appearances)
local Anatomy = require(script.Parent.Anatomy)
local Setae = require(script.Parent.Setae)
local Idle = require(script.Parent.Idle)
local Growth = require(script.Parent.Parent.Life.Growth)
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
	femurTip: Part?, -- the thinner distal rod of a tapered femur or tibia, the thinner distal rod of the tarsus and the ball on its break (look.legForm;
	tibiaTip: Part?, -- all nil for an appearance without one), and the foot's claws or scopula bristles
	tarsusTip: Part?,
	joint: Part?,
	toes: {Part},
	bands: {Part}, -- empty for a pair drawn without pale bands (the peacock spider's legs III)
	hairs: { { part: Part, spec: Setae.LegHair } },
}

type Fixed = { part: Part, offset: CFrame, group: number, palp: number?, sweep: number? }

-- The peacock spider's fan: flat ellipsoid discs on the abdomen's back face, stacked fringe first, their size set each frame by how far the fan is open.
type FanDisc = { part: Part, inset: number, y: number }
type FanFigure = { part: Part, x: number, z: number, rx: number, rz: number, angle: number }
type Fan = { front: { FanDisc }, back: { FanDisc }, figure: { FanFigure }, flaps: { { part: Part, side: number } }, cfg: any, parts: { Part } }

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
		_k: number,
  _growth: number,
  _softness: number,
  _condition: number,
  _shownCondition: number,
  hangDirection: Vector3?,
  _hang: number,
  _spinneret: Vector3?,
  jumpLoad: number,
  jumpPush: number,
  _shownLoad: number,
  _sizes: {[BasePart]: Vector3},
  _colors: {[BasePart]: Color3},
  _bars: { Part }, -- the Greenbottle blue's diagonal bars, which soften at the last growth stage
		_drop: number,
		_fan: Fan?,
		dance: any, -- a PeacockDance.Pose, or nil: the peacock spider's display (ignored by an appearance without a fan)
		ant: any, -- an AntMimicPose.Pose, or nil: the ant-mimicking spider's antennae and walk (ignored by an appearance without look.antennae)
		threat: any, -- a TarantulaPose.Pose, or nil: a tarantula's threat display and silk mat (ignored by an appearance without look.threat)
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

local function disc(model: Model, name: string, color: Color3, reflectance: number): Part
	local p = ellipsoid(model, name, Vector3.new(0.05, 0.002, 0.05), color, Enum.Material.SmoothPlastic)
	p.CastShadow = false
	p.Reflectance = reflectance
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
	local JOINT, EYE, FANG = color(look.joint or look.white), color(look.eyes), color(look.fangs)
	local ABDOMEN = if look.abdomenColor then color(look.abdomenColor) else BODY
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
		_k = look.scale or 1,
  _growth = 1, _softness = 0, _condition = 0.55, _shownCondition = 0.55, jumpLoad = 0, jumpPush = 0, _shownLoad = 0,
  hangDirection=nil :: Vector3?, _hang=0, _spinneret=nil :: Vector3?,
  _sizes = {} :: {[BasePart]: Vector3}, _colors = {} :: {[BasePart]: Color3}, _bars = {} :: { Part },
		_drop = look.bodyDrop or 0,
		_fan = nil :: Fan?,
		dance = nil :: any,
		ant = nil :: any,
		threat = nil :: any,
	}, SpiderRig)

	local function fixed(part: Part, at: Vector3, rot: CFrame?, group: number, palp: number?): Fixed
		local entry: Fixed = { part = part, offset = CFrame.new(at) * (rot or CFrame.identity), group = group, palp = palp, sweep = nil }
		table.insert(self._fixed, entry)
		return entry
	end
	local fabric = Enum.Material.SmoothPlastic -- clean high-contrast silhouette
	fixed(ellipsoid(model, "Cephalothorax", A.headRadii, BODY, fabric), A.headCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "EyeFace", A.faceRadii, BODY, fabric), A.faceCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "Pedicel", A.pedicelRadii, BODY, fabric), A.pedicelCenter, nil, G_BODY)
	fixed(ellipsoid(model, "Abdomen", A.abdomenRadii, ABDOMEN, fabric), A.abdomenCenter, nil, G_ABDOMEN)
	-- More segments (the ant-mimicking spider's thorax and the node on its waist), and a glossy cuticle where the look asks for one.
	-- (`fullOnly` extras are left out at low detail; `sweep` marks a spinneret segment that the silk-mat pose swings.)
	for _, ex in look.extras or {} do
		if ex.fullOnly and detailName == "low" then continue end
		local seg = ellipsoid(model, ex.name, v3(ex.radii), if ex.color then color(ex.color) else BODY, fabric)
		fixed(seg, v3(ex.center), nil, GROUP_OF[ex.group] or G_BODY).sweep = ex.sweep
	end
	-- A tarantula's ocular tubercle, the mound that carries its eyes (the eyes themselves are below).
	local tubercle = A.tubercle
	if tubercle then
		local mound = ellipsoid(model, "OcularTubercle", tubercle.radii, color(look.tubercle.color), fabric)
		mound.Reflectance = look.tubercle.reflectance
		fixed(mound, tubercle.center, nil, G_HEAD)
	end
	if look.gloss then
		for _, f in self._fixed do
			local name = f.part.Name
			if name == "Cephalothorax" or name == "EyeFace" or name == "Pedicel" or name == "Abdomen" or name == "Thorax" or name == "PetioleNode" or name == "CarapaceRim" then
				f.part.Reflectance = look.gloss
			end
		end
	end

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

	-- A tarantula's markings on the abdomen (look.marks): flat dabs in their own colours lying on the back, each tilted to the slope under it.
	-- x and z are fractions of the abdomen's radii, rx and rz the dab's half sizes in studs. `mirror` also draws the other side, `fullOnly`
	-- leaves it out at low detail, `bar` lists it among the bars that soften with growth (look.barFade).
	for _, m in look.marks or {} do
		if m.fullOnly and detailName == "low" then continue end
		local sides: { number } = if m.mirror then { 1, -1 } else { 1 }
		for _, side in sides do
			local x, z = side * m.x, m.z
			local q = math.sqrt(math.max(1 - x * x - z * z, 0.05))
			local pitch = math.atan(ar.Y * z / (ar.Z * q))
			local roll = math.atan(-ar.Y * x / (ar.X * q))
			local dab = ellipsoid(model, m.name, Vector3.new(m.rx, 0.010, m.rz), color(m.color), fabric)
			dab.CastShadow = false
			fixed(dab, Vector3.new(x * ar.X, ac.Y + ar.Y * q + 0.002, ac.Z + z * ar.Z), CFrame.Angles(pitch, 0, roll) * CFrame.Angles(0, side * m.angle, 0), G_ABDOMEN)
			if m.bar then table.insert(self._bars, dab) end
		end
	end

	-- Head: pale cheeks, big glossy eyes with their catchlights, jaws.
	for _, c in A.cheeks do
		local cheek = ellipsoid(model, "PaleCheek", c.radii, WHITE, fabric)
		cheek.CastShadow = false
		fixed(cheek, c.at, nil, G_HEAD)
	end
	-- The peacock spider's red-orange carapace stripes: flat dabs lying on the head's dome, tilted to the slope under them.
	local stripes = look.stripes
	if stripes then
		local STRIPE = color(stripes.color)
		for n = 1, #stripes do
			local st = stripes[n]
			local dx, dz = st.x, st.z - A.headCenter.Z
			local q = math.sqrt(math.max(1 - (dx / A.headRadii.X) ^ 2 - (dz / A.headRadii.Z) ^ 2, 0.05))
			local y = A.headCenter.Y + A.headRadii.Y * q
			local pitch = -math.atan(-A.headRadii.Y * (dz / A.headRadii.Z) / (A.headRadii.Z * q))
			local roll = math.atan(-A.headRadii.Y * (dx / A.headRadii.X) / (A.headRadii.X * q))
			local dab = ellipsoid(model, "CarapaceStripe", Vector3.new(st.rx, 0.006, st.rz), STRIPE, fabric)
			dab.CastShadow = false
			fixed(dab, Vector3.new(st.x, y + 0.002, st.z), CFrame.Angles(pitch, 0, roll) * CFrame.Angles(0, st.angle, 0), G_HEAD)
		end
	end
	local SOCKET = if look.eye.ame then color(look.eye.ame.socket.color) else EYE -- (a tarantula has no big front eyes to frame)
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
	-- Fangs (look.fang): chains of dark, glossy ellipsoids hanging from the chelicerae's lower front, each segment turned along its own direction.
	for _, f in A.fangs do
		if f.index > (cfg.fangSegments or 0) then continue end
		local tooth = ellipsoid(model, "Fang", f.radii, if look.fang.color then color(look.fang.color) else FANG, Enum.Material.Foil)
		tooth.Reflectance = look.fang.reflectance
		tooth.CastShadow = false
		fixed(tooth, f.at, CFrame.lookAt(Vector3.zero, f.dir), G_HEAD)
	end
	-- Pedipalps: stalk, pale band, club and pale tip, rotating about a pivot at the base (they drum when the spider stands).
	local pl = look.palp
	local pc = look.palpColors
	local PALP_STALK, PALP_CLUB, PALP_TIP = if pc then color(pc.stalk) else LEG, if pc then color(pc.club) else LEG, if pc then color(pc.tip) else JOINT
	for index, palp in A.palps do
		local base, tip = palp.base, palp.tip
		local len = (tip - base).Magnitude
		local toBase = CFrame.new(base):Inverse()
		local stalk = rod(model, "PalpStalk", pl.stalk, PALP_STALK)
		local pf = look.palpForm -- a leg-like palp tapers like a femur: a thick rod, then a thinner one out to the club
		local reach = if pf then len * pf.split else len
		stalk.Size = Vector3.new(reach, pl.stalk, pl.stalk)
		fixed(stalk, Vector3.zero, toBase * rodCFrame(base, base:Lerp(tip, reach / len)), G_HEAD, index)
		if pf then
			local thin = rod(model, "PalpStalkTip", pl.stalk * pf.taper, PALP_STALK)
			thin.Size = Vector3.new(len - reach, pl.stalk * pf.taper, pl.stalk * pf.taper)
			fixed(thin, Vector3.zero, toBase * rodCFrame(base:Lerp(tip, reach / len), tip), G_HEAD, index)
		end
		local ring = rod(model, "PalpBand", pl.stalk * 1.05, WHITE)
		ring.Size = Vector3.new(len * look.bandFraction, pl.stalk * 1.05, pl.stalk * 1.05)
		fixed(ring, Vector3.zero, toBase * rodCFrame(base, tip), G_HEAD, index)
		local os = pl.offsetScale or 1 -- the club and tip sit a little past the stalk's end; a very small spider scales that down
		fixed(ellipsoid(model, "PalpClub", v3(pl.club), PALP_CLUB, fabric), tip + Vector3.new(0, -0.005, -0.02) * os - base, nil, G_HEAD, index)
		fixed(ellipsoid(model, "PalpTip", v3(pl.tipRadii), PALP_TIP, fabric), tip + Vector3.new(0, 0.004, -0.05) * os - base, nil, G_HEAD, index)
	end

	-- Fuzz: flat locks over the head and abdomen, tufts, a cheek ruff and palp fluff (Rig/Setae), moved with the part they grow from.
	local fuzz = look.fuzz
	local BLACKEST = if fuzz then color(fuzz.black) else BODY
	local DARK = if fuzz then color(fuzz.dark) else BODY
	local GREY = if fuzz then color(fuzz.grey) else BODY
	local FROST = if fuzz then color(fuzz.frost) else BODY
	local function seta(tone: string, width: number, thick: number, length: number, transparency: number): Part
		local h = newPart(model, "Seta", if tone == "white" then WHITE elseif tone == "frost" then FROST elseif tone == "grey" then GREY elseif tone == "black" then BLACKEST else DARK, Enum.Material.SmoothPlastic)
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
			local every = cfg.every[kind] or 1
			if every <= 0 then return false end -- 0 drops the whole class
			local n = (seen[kind] or 0) + 1
			seen[kind] = n
			return n % every == 0
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

	-- A leg's pale bands: white on the femur, tibia and tarsus unless the look lists its own (look.legBands: a colour for each segment that has
	-- one, so the redknee's single band is { tibia = ... } and the greenbottle's none is {}).
	local function legBands(i: number, d: { number }): { Part }
		local lb = look.legBands
		if lb == nil then
			return {rod(model, "FemurBand" .. i, d[1], WHITE), rod(model, "TibiaBand" .. i, d[2], WHITE), rod(model, "TarsusBand" .. i, d[2] * 0.6, WHITE)}
		end
		local out: { Part } = {}
		if lb.femur then out[1] = rod(model, "FemurBand" .. i, d[1], color(lb.femur)) end
		if lb.tibia then out[2] = rod(model, "TibiaBand" .. i, d[2], color(lb.tibia)) end
		if lb.tarsus then out[3] = rod(model, "TarsusBand" .. i, d[2] * 0.6, color(lb.tarsus)) end
		return out
	end
	-- Legs: plump, with rounded joints and (at full detail) round feet.
	local L = look.limbs
	for i = 1, 8 do
		local side = if i <= 4 then -1 else 1
		local pair = (i - 1) % 4 + 1
		local raw = L.diameters[pair]
		local factor = (if pair == 1 then look.frontLegScale else 1) * L.thickness
		local d = {raw[1] * factor, raw[2] * factor}
		-- A pair with its own look (the peacock spider's legs III): a colour and a thickness per segment, and no pale bands.
		local own = if look.pairs then look.pairs[pair] else nil
		local cFemur, cTibia, cTarsus = LEG, LEG, LEG
		local tF, tT, tTar = 1, 1, 1
		local kneeColor, ankleColor = JOINT, JOINT
		local lc = look.legColors -- a tarantula's legs are coloured segment by segment: the patella is the knee, the metatarsus and tarsus the foot
		if lc then
			cFemur, cTibia, cTarsus, kneeColor, ankleColor = color(lc.femur), color(lc.tibia), color(lc.tarsus), color(lc.knee), color(lc.ankle)
		end
		local withBands = true
		if own then
			cFemur, cTibia, cTarsus = color(own.colors[1]), color(own.colors[2]), color(own.colors[3])
			tF, tT, tTar = own.thick[1], own.thick[2], own.thick[3]
			kneeColor, ankleColor = cFemur, cTibia
			withBands = own.bands ~= false
		end
		if cfg.legBands == false then withBands = false end -- the low tier of the peacock spider draws no pale bands
		-- The shape of the leg (look.legForm, ROBLOX-84): a tapered femur and tibia, a patella for a knee, a break in the tarsus, a pad and its toes.
		local form = look.legForm
		local D1, D2, DT = d[1] * tF, d[2] * tT, d[2] * 0.6 * tTar -- the femur's, tibia's and tarsus' diameters
		local knee: Part
		local pad: Part? = nil
		local toes: {Part} = {}
		if form then
			local pt = form.patella
			knee = ellipsoid(model, "Knee" .. i, Vector3.new(D1 * pt.length, D1 * pt.width, D1 * pt.width) * 0.5, kneeColor, fabric)
			knee.CastShadow = false
			if cfg.pads then
				local ft = form.foot
				local sole = ellipsoid(model, "Foot" .. i, Vector3.new(ft.rx, ft.ry, ft.rz) * DT, cTarsus, fabric)
				sole.CastShadow = false
				pad = sole
				local cw, st = form.claws, form.strands
				for _ = 1, if cw then cfg.claws or 0 else 0 do
					local claw = rod(model, "Claw", cw.radius * 2, FANG)
					claw.Size, claw.CastShadow = Vector3.new(cw.length, cw.radius * 2, cw.radius * 2), false
					table.insert(toes, claw)
				end
				for _ = 1, if st then cfg.strands or 0 else 0 do
					local bristle = rod(model, "FootBristle", st.radius * 2, cTarsus)
					bristle.Size, bristle.CastShadow = Vector3.new(st.length, st.radius * 2, st.radius * 2), false
					table.insert(toes, bristle)
				end
			end
		else
			knee = ball(model, "Knee" .. i, D1 * 0.95, kneeColor)
			pad = if cfg.pads then ball(model, "Foot" .. i, DT * L.pad, cTarsus) else nil
		end
		table.insert(self._legs, {
			side = side,
			pair = pair,
			planted = nil :: Vector3?,
			swing = -1,
			from = Vector3.zero,
			to = Vector3.zero,
			up = Vector3.yAxis,
			foot = Vector3.zero,
			femur = rod(model, "Femur" .. i, d[1] * tF, cFemur),
			tibia = rod(model, "Tibia" .. i, d[2] * tT, cTibia),
			tarsus = rod(model, "Tarsus" .. i, d[2] * 0.6 * tTar, cTarsus),
			knee = knee,
			ankle = ball(model, "Ankle" .. i, d[2] * tT * 0.95, ankleColor),
			pad = pad,
			femurTip = if form and cfg.taper then rod(model, "FemurTip" .. i, D1 * form.femur.taper, cFemur) else nil,
			tibiaTip = if form and form.tibia and cfg.tibiaTaper then rod(model, "TibiaTip" .. i, D2 * form.tibia.taper, cTibia) else nil,
			tarsusTip = if form and form.tarsus.tip and cfg.jointBreak then rod(model, "TarsusTip" .. i, DT * form.tarsus.tip, cTarsus) else nil,
			joint = if form and cfg.jointBreak then ball(model, "TarsalJoint" .. i, DT * form.tarsus.joint, ankleColor) else nil,
			toes = toes,
			bands = if not withBands then {} else legBands(i, d),
			hairs = {},
		})
		local leg = self._legs[#self._legs]
		if fuzz and fuzz.enabled then
			for n, spec in Setae.leg(look, i) do
				if cfg.every.leg <= 0 or n % cfg.every.leg ~= 0 then continue end
				table.insert(leg.hairs, { part = seta(spec.tone, fuzz.legWidth, fuzz.legWidth, spec.length, fuzz.legTransparency), spec = spec })
			end
		end
	end
	if look.legGloss then -- the Greenbottle blue's legs are a little glossy
		for _, leg in self._legs do
			leg.femur.Reflectance, leg.tibia.Reflectance, leg.tarsus.Reflectance = look.legGloss, look.legGloss, look.legGloss
			if leg.femurTip then leg.femurTip.Reflectance = look.legGloss end
			if leg.tibiaTip then leg.tibiaTip.Reflectance = look.legGloss end
			if leg.tarsusTip then leg.tarsusTip.Reflectance = look.legGloss end
		end
	end
	-- The peacock spider's fan (look.fan): the discs of the front face, the figure on them, the repeat on the back and the folded flaps.
	local fc = look.fan
	if fc then
		local fan: Fan = { front = {}, back = {}, figure = {}, flaps = {}, cfg = fc, parts = {} }
		local function add(list: { FanDisc }, spec: any, y: number)
			local part = disc(model, spec.name, color(spec.color), if spec.name == "FanField" then fc.sheen else 0)
			table.insert(list, { part = part, inset = spec.inset, y = y })
			table.insert(fan.parts, part)
		end
		for k = 1, math.min(cfg.fanLayers or #fc.layers, #fc.layers) do
			add(fan.front, fc.layers[k], (k - 1) * fc.layerStep)
		end
		if cfg.fanBack then
			for j, k in fc.back.layers do add(fan.back, fc.layers[k], fc.back.plane - (j - 1) * fc.layerStep) end
		end
		for _, f in fc.figure do
			if f.fullOnly and detailName == "low" then continue end
			local part = disc(model, if f.color then "FanGlint" else "FanFigure", color(f.color or fc.figureColor), 0)
			table.insert(fan.figure, { part = part, x = f.x, z = f.z, rx = f.rx, rz = f.rz, angle = f.angle })
			table.insert(fan.parts, part)
		end
		for _, side in { -1, 1 } do
			local flap = ellipsoid(model, "FanFlap", v3(fc.flaps.radii), color(fc.flaps.color), fabric)
			flap.CastShadow = false
			table.insert(fan.flaps, { part = flap, side = side })
			table.insert(fan.parts, flap)
		end
		self._fan = fan
	end
	if cfg.highlight then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = if look.outline then color(look.outline) else WHITE
		hl.OutlineTransparency = 0.82
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
		self._highlight = hl
	end
 for _,p in model:GetChildren() do
  if p:IsA("BasePart") and p~=root then self._sizes[p]=p.Size;self._colors[p]=p.Color end
 end
 model.Parent = parent
	self:setGrowthStage(0)
	return self
end

-- Scale about the support plane, not the collider centre. Planted contacts remain world-space points.
function SpiderRig.setGrowthStage(self: Rig, stage: number)
 local index=math.clamp(math.floor(stage),0,3)
 self.model:SetAttribute("GrowthStage",index)
 local fade=self._appearance.barFade -- the Greenbottle blue's juvenile bars soften at the last stage
 if fade then for _,bar in self._bars do bar.Transparency=fade[index+1] end end
 self:setScale(Growth.SCALES[index+1])
end
-- Any size, not only a growth stage's (ROBLOX-80: the mate is the played spider's look at the adult scale times its own factor). The same scaling as a stage.
function SpiderRig.setScale(self: Rig, g: number)
 if self._growth==g then return end
 self._growth=g
 self._k=(self._appearance.scale or 1)*g
 self._drop=0.31-(0.31-(self._appearance.bodyDrop or 0))*g
 for p,size in self._sizes do p.Size=size*g end
end
function SpiderRig.setSoftness(self: Rig, value: number)
 local s=math.clamp(value,0,1)
 if math.abs(s-self._softness)<0.001 then return end
 self._softness=s
 for p,c in self._colors do
  -- The eyes stay dark and readable; pigment returns as the skin hardens.
  if p.Material~=Enum.Material.Glass and p.Name~="Catchlight" then p.Color=c:Lerp(Color3.new(0.88,0.82,0.69),s*0.72) end
 end
end
function SpiderRig.setCondition(self: Rig, energy: number)
 self._condition=math.clamp(energy,0,1)
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
	local longer = self._appearance.limbs.pairReach
	local r = s.reach * (if longer then longer[leg.pair] else 1) -- the peacock spider's legs III are the longest
	return Vector3.new(leg.side * s.x * r, s.y, self._appearance.limbs.tipZ[leg.pair] * r) * self._growth
end

-- Display-only foothold: retract toward the body at a narrow edge; never invents a platform.
local function target(self: Rig, body: CFrame, leg: Leg): RaycastResult?
	local up = body.UpVector
	local rest = restLocal(self, leg)
	local k = self._k
	for _, reach in { 1.0, 0.65, 0.35, 0.12 } do
		local point = body:PointToWorldSpace(Vector3.new(rest.X * reach, 0, rest.Z * reach))
		local hit = Workspace:Raycast(point + up * (0.35 * k), -up * (1.0 * k), self._params)
		if hit and hit.Normal:Dot(up) > 0.35 then
			return hit
		end
	end
	return nil
end

-- body: the drawn body's CFrame. grounded: standing on a surface. moving: walking speed > 0 (for palp drumming and idle motion).
function SpiderRig.update(self: Rig, collider: CFrame, dt: number, grounded: boolean, moving: boolean)
	self._t += dt
	-- The root part (what the camera and tests read) stays at the collider's frame; the drawn body of a small appearance sits lower.
	local body = if self._drop ~= 0 then collider * CFrame.new(0, -self._drop, 0) else collider
	-- The ant-mimicking spider's drawn walk: the body yaws and sways a little along a sine of the distance walked (the collider and the path
	-- are untouched; the root part stays at the collider's frame).
	local antPose = if self._appearance.antennae ~= nil then self.ant else nil
	if antPose ~= nil and (antPose.yaw ~= 0 or antPose.lateral ~= 0) then
		body = body * CFrame.new(antPose.lateral * self._growth, 0, 0) * CFrame.Angles(0, antPose.yaw, 0)
	end
	-- A tarantula's threat display and silk mat (ROBLOX-82): the drawn body pivots about its up axis (the root and the collider do not); what else
	-- the pose does (rears the prosoma, raises legs I and the palps, swings the spinnerets) is further down.
	local threatPose = if self._appearance.threat ~= nil then self.threat else nil
	local threatening = threatPose ~= nil and threatPose.presence > 0
	if threatening and threatPose.yaw ~= 0 then
		body = body * CFrame.Angles(0, threatPose.yaw, 0)
	end
	local up = body.UpVector
	local look, cfg, A = self._appearance, self._cfg, self._layout
	local k, g = self._k, self._growth
 self._shownCondition += math.clamp(self._condition-self._shownCondition,-0.12*dt,0.12*dt)
 local conditionValue=self._shownCondition
 local condition=Vector3.new(0.84+0.30*conditionValue,0.84+0.30*conditionValue,0.93+0.12*conditionValue)
 -- Suspension tilts the drawn body about its rear silk outlet, never the motor/camera.
 local hanging=not grounded and self.hangDirection~=nil
 local wanted=if hanging then 1 else 0
 self._hang+=math.clamp(wanted-self._hang,-5*dt,5*dt)
 if grounded then self._hang=0 end
 if self._hang>0 then
  local direction=body:VectorToObjectSpace(self.hangDirection or Vector3.yAxis)
  local pitch=-math.clamp(math.atan2(direction.Y,math.max(.05,direction.Z)),0,math.rad(80))*self._hang
  local roll=math.clamp(-direction.X*.25,-.2,.2)*self._hang
  local tail=(A.abdomenCenter+(A.spinneret-A.abdomenCenter)*condition)*g
  body=body*CFrame.new(tail)*CFrame.Angles(pitch,0,roll)*CFrame.new(-tail)
  up=body.UpVector
 end
 local function scaledFrame(cf: CFrame): CFrame return if g==1 then cf else CFrame.new(cf.Position*g)*cf.Rotation end
	local parts, cframes = self._parts, self._cframes
	table.clear(parts)
	table.clear(cframes)
	local function put(p: BasePart, cf: CFrame)
		table.insert(parts, p)
		table.insert(cframes, cf)
	end
	put(self.root, collider)
	-- The courtship display (rig.dance, a PeacockDance pose), for an appearance that has a fan.
	local display = self.dance
	local fan = self._fan
	local dancing = fan ~= nil and display ~= nil and display.presence > 0
	local posed = dancing or threatening -- a display pose is on: no idle motion, twitch or jump brace on top of it

	-- Palps drum in bursts while the spider stands still; breathing and a curious head tilt ease in after a moment. All of
	-- it is full detail only (cfg.idle), and reducedMotion turns it off too.
	local loading = grounded and self.jumpLoad > 0
 local push = if self.reducedMotion then 0 else math.clamp(self.jumpPush,0,1)
 local desiredLoad = if loading and not self.reducedMotion then math.clamp(self.jumpLoad,0,1) else 0
 self._shownLoad += math.clamp(desiredLoad-self._shownLoad,-12*dt,6*dt)
 local load = if self.reducedMotion then 0 else self._shownLoad
 local standing = cfg.idle and grounded and not moving and not self.reducedMotion and not posed and not loading
	self._drum = math.clamp(self._drum + (if standing then 3 else -3) * dt, 0, 1)
	local palpAngle = Idle.palps(self._t, self._drum, look.palp)
	local bodyBase, headBase, abdomenBase = body, body, body
	if cfg.idle then
		local idle = look.idle
		self._calm = math.clamp(self._calm + (if standing then dt / idle.riseSeconds else -dt / idle.fallSeconds), 0, 1)
		if self._calm > 0 then
			local c = self._calm * self._calm * (3 - 2 * self._calm)
			local pose = Idle.pose(self._t, c, idle)
			bodyBase = body * CFrame.new(0, pose.bodyLift*g, 0)
			headBase = bodyBase * CFrame.new(A.neck*g) * CFrame.Angles(pose.headPitch, pose.headYaw, pose.headRoll) * CFrame.new(-A.neck*g)
			abdomenBase = bodyBase * CFrame.new(0, pose.abdomenLift*g, 0) * CFrame.new(A.pedicelCenter*g)
				* CFrame.Angles(-pose.abdomenPitch, 0, 0) * CFrame.new(-A.pedicelCenter*g)
		end
	end
	-- Display-only snaps also run on low-detail devices. Camera/root, foot anchors and motor stay unchanged.
	if grounded and not self.reducedMotion and not posed and not loading then
		local yaw, lift = Idle.snap(self._t, moving)
		local accent = body * CFrame.new(0, lift * g, 0) * CFrame.Angles(0, yaw, 0) * body:Inverse()
		bodyBase, headBase, abdomenBase = accent * bodyBase, accent * headBase, accent * abdomenBase
	end
 -- A visible preparation and extension, not a pressure gauge or an inflated body. Hydraulic
 -- extension and muscle action both matter; their jump contribution varies among species
 -- (Nabawy et al. 2018, doi:10.1038/s41598-018-25227-9). Timings are display tuning.
 if not posed and (load > 0 or push > 0) then
  local brace = body * CFrame.new(0,(-0.065*load+0.025*push)*k,0)
   * CFrame.Angles(-0.07*load+0.05*push,0,0) * body:Inverse()
  bodyBase,headBase,abdomenBase=brace*bodyBase,brace*headBase,brace*abdomenBase
 end
	if dancing then
		-- The abdomen pitches up about the pedicel and sways side to side (about the body's long axis), the palps flick in unison.
		abdomenBase = bodyBase * CFrame.new(A.pedicelCenter*g) * CFrame.Angles(0, 0, display.abdomenSway + display.shiver)
			* CFrame.Angles(-display.abdomenPitch, 0, 0) * CFrame.new(-A.pedicelCenter*g)
		palpAngle = { palpAngle[1] + display.palp, palpAngle[2] + display.palp }
	end
	-- The threat display: the prosoma (the head with the palps, and every leg's hip) pitches up about the waist; the palps lift at their bases.
	local prosoma = bodyBase
	if threatening and threatPose.rear ~= 0 then
		local waist = A.pedicelCenter * g
		prosoma = bodyBase * CFrame.new(waist) * CFrame.Angles(threatPose.rear, 0, 0) * CFrame.new(-waist)
		headBase = prosoma * (bodyBase:Inverse() * headBase) -- (keeps any head tilt the idle motion still has)
	end
	if threatening then
		palpAngle = { palpAngle[1] + threatPose.palps, palpAngle[2] + threatPose.palps }
	end
 self._spinneret=abdomenBase:PointToWorldSpace((A.abdomenCenter+(A.spinneret-A.abdomenCenter)*condition)*g)
	local pivots = {
		CFrame.new(self._palpBase[1]) * CFrame.Angles(palpAngle[1], 0, 0),
		CFrame.new(self._palpBase[2]) * CFrame.Angles(palpAngle[2], 0, 0),
	}
	for _, f in self._fixed do
		local base = if f.group == G_HEAD then headBase elseif f.group == G_ABDOMEN then abdomenBase else bodyBase
		local palp = f.palp
		if palp then
			put(f.part, base * scaledFrame(pivots[palp] * f.offset))
		else
			local offset=f.offset
			if threatening and f.sweep ~= nil and threatPose.sweep ~= 0 then
				-- A spinneret segment swings side to side about a point just inside the abdomen's rear tip (the second segment farther).
				local tc = look.threat
				local at = A.spinneret - Vector3.new(0, 0, tc.sweepBack)
				offset = CFrame.new(at) * CFrame.Angles(0, threatPose.sweep * (if f.sweep > 1 then tc.tipSweep else 1), 0) * CFrame.new(-at) * offset
			end
    if f.group==G_ABDOMEN then
     local p=A.abdomenCenter+(offset.Position-A.abdomenCenter)*condition
     offset=CFrame.new(p)*offset.Rotation
     local size=self._sizes[f.part]*g*condition
     if (f.part.Size-size).Magnitude>1e-5 then f.part.Size=size end
    end
    put(f.part, base * scaledFrame(offset))
		end
	end

	if fan then
		self:_drawFan(abdomenBase, if dancing then display.fanOpen else 0, put)
	end

	-- Legs: planted feet stay put in the world; a leg too far from its rest spot steps, in alternating groups.
	local swinging = false
	for _, leg in self._legs do
		swinging = swinging or leg.swing >= 0
	end
	if grounded and not swinging then
		local worst = STEP_ERROR * k
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
   local free=Vector3.new(leg.side*.47*k,-.12*k,L.tipZ[leg.pair]*.72*g)
   local adjust=if self.reducedMotion then 0 else math.sin(self._t*3.2+leg.pair*1.7+leg.side)*.025*k
   local suspended=Vector3.new(leg.side*(if leg.pair<=2 then .43 else .31)*k,-.22*k+adjust,L.tipZ[leg.pair]*.52*g)
   leg.foot=body:PointToWorldSpace(free:Lerp(suspended,self._hang))
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
					leg.swing = math.min(1, leg.swing + dt / (SWING_SECONDS * math.sqrt(k)))
					local s = leg.swing
					local smooth = s * s * (3 - 2 * s)
					leg.foot = leg.from:Lerp(anchor, smooth) + leg.up * math.sin(math.pi * s) * (STEP_HEIGHT * k)
					if leg.swing >= 1 then
						leg.swing = -1
						leg.foot = anchor
					end
				else
					leg.foot = anchor
					local err = (rest - anchor).Magnitude
					if err > STEP_ERROR * k and ((not swinging and legGroup(self, i) == self._group) or err > 0.60 * k) then
						local hit = target(self, body, leg)
						if hit and (anchor - hit.Position).Magnitude > 0.12 * k then
							leg.from = anchor
							leg.planted = hit.Position
							leg.up = hit.Normal
							leg.swing = 0
							started = true
						end
					end
					if body:PointToObjectSpace(leg.foot).Magnitude > 1.4 * k then
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
	local kneeUp = (if grounded then L.kneeLift else L.kneeLiftAir)*g
	for _, leg in self._legs do
		local hip = prosoma:PointToWorldSpace(Vector3.new(leg.side * L.hipX, L.hipY, L.hipZ[leg.pair])*g)
		local foot = leg.foot
  local rear = leg.pair >= 3
  if not grounded and rear and push > 0 then
   foot += body:VectorToWorldSpace(Vector3.new(leg.side*.05,-.25,.18)*k*push)
  end
		local knee = hip:Lerp(foot, 0.48) + up * (if rear then kneeUp*(1-.7*push)+.035*k*load else kneeUp)
		local own = if dancing and look.pairs then look.pairs[leg.pair] else nil
		if own and display.legsRaise > 0 then
			-- Legs III go up in a V beside the fan and wave: down and forward over the carapace, and back up (the planted foot below is untouched).
			local raise = display.legsRaise
			local upAt = Vector3.new(leg.side * own.up.x, own.up.y, own.up.z)
			local sweptAt = Vector3.new(leg.side * own.swept.x, own.swept.y, own.swept.z)
			local raised = bodyBase:PointToWorldSpace(upAt:Lerp(sweptAt, display.legsWave)*g)
			foot = foot:Lerp(raised, raise)
			local raisedKnee = hip:Lerp(raised, 0.5) + bodyBase.RightVector * (leg.side * own.kneeOut*g) + up * look.dance.kneeUp*g
			knee = knee:Lerp(raisedKnee, raise)
		end
		-- The antennal illusion: legs I go up above the head, both in phase (one wave value), and the planted foot below is untouched.
		local antCfg = look.antennae
		if antPose ~= nil and antCfg ~= nil and leg.pair == antCfg.pair and antPose.antennae > 0 then
			local highShift = Vector3.new(0, antCfg.high.y - antCfg.up.y, antCfg.high.z - antCfg.up.z) * antPose.high
			local upAt = Vector3.new(leg.side * antCfg.up.x, antCfg.up.y, antCfg.up.z)
				+ Vector3.new(leg.side * (antCfg.high.x - antCfg.up.x) * antPose.high, 0, 0) + highShift
			local sweptAt = Vector3.new(leg.side * antCfg.swept.x, antCfg.swept.y, antCfg.swept.z) + highShift
			local raised = bodyBase:PointToWorldSpace(upAt:Lerp(sweptAt, antPose.wave) * g)
			foot = foot:Lerp(raised, antPose.antennae)
			local raisedKnee = hip:Lerp(raised, 0.5) + bodyBase.RightVector * (leg.side * antCfg.kneeOut * g) + up * (antCfg.kneeUp * g)
			knee = knee:Lerp(raisedKnee, antPose.antennae)
		end
		-- The threat posture: legs I go up and out in front of the reared prosoma, trembling a little; the planted foot below is untouched.
		local tc = look.threat
		if threatening and tc ~= nil and leg.pair == tc.pair and threatPose.legs > 0 then
			local upAt = Vector3.new(leg.side * tc.up.x, tc.up.y + threatPose.tremor * tc.tremor, tc.up.z)
			local raised = prosoma:PointToWorldSpace(upAt * g)
			foot = foot:Lerp(raised, threatPose.legs)
			local raisedKnee = hip:Lerp(raised, 0.5) + prosoma.RightVector * (leg.side * tc.kneeOut * g) + up * (tc.kneeUp * g)
			knee = knee:Lerp(raisedKnee, threatPose.legs)
		end
		local ankle = knee:Lerp(foot, ANKLE_SHARE) + up * (L.ankleLift*g)
		local form = look.legForm
		-- One link of the leg: its rod runs from a to b; with a thinner `tip` rod the first runs a to m and the tip m to b (a tapered femur or tibia,
		-- the break in the tarsus). The pale band (one `bandFraction` of the whole link) and the setae follow the link, not the pieces.
		local function segment(index: number, p: Part, tip: Part?, band: Part?, a: Vector3, m: Vector3, b: Vector3)
			local len = math.max((b - a).Magnitude, 0.01)
			local ends = if tip then m else b
			local plen = math.max((ends - a).Magnitude, 0.01)
			if math.abs(p.Size.X - plen) > 1e-3 then
				p.Size = Vector3.new(plen, p.Size.Y, p.Size.Z)
			end
			local rc = rodCFrame(a, b) -- local +X runs from a toward b (toward the foot)
			put(p, if tip then rodCFrame(a, m) else rc)
			local share = plen / len
			if tip then
				local tlen = math.max((b - m).Magnitude, 0.01)
				if math.abs(tip.Size.X - tlen) > 1e-3 then
					tip.Size = Vector3.new(tlen, tip.Size.Y, tip.Size.Z)
				end
				put(tip, rodCFrame(m, b))
			end
			if band then
				band.Size = Vector3.new(len * look.bandFraction, p.Size.Y * 1.035, p.Size.Z * 1.035)
				put(band, rc)
			end
			-- Leg setae stand out from the segment and lean toward the foot.
			for _, hair in leg.hairs do
				local spec = hair.spec
				if spec.segment == index then
					local r = (if tip and spec.t > share then tip.Size.Y else p.Size.Y) * 0.5
					local c, s = math.cos(spec.theta), math.sin(spec.theta)
					local base = Vector3.new((spec.t - 0.5) * len, r * 0.8 * c, r * 0.8 * s)
					local dir = Vector3.new(1.3, c, s).Unit
					put(hair.part, rc * CFrame.lookAt(base + dir * (spec.length * g * 0.5), base + dir * spec.length*g, Vector3.xAxis))
				end
			end
		end
		local femurMid = if form and leg.femurTip then hip:Lerp(knee, form.femur.split) else knee
		local tibiaMid = if form and form.tibia and leg.tibiaTip then knee:Lerp(ankle, form.tibia.split) else ankle
		local tarsusMid = if form and leg.joint then ankle:Lerp(foot, form.tarsus.split) + up * (if leg.tarsusTip then form.tarsus.bend * g else 0) else foot
		segment(1, leg.femur, leg.femurTip, leg.bands[1], hip, femurMid, knee)
		segment(2, leg.tibia, leg.tibiaTip, leg.bands[2], knee, tibiaMid, ankle)
		segment(3, leg.tarsus, leg.tarsusTip, leg.bands[3], ankle, tarsusMid, foot)
		if form then
			-- The knee is a patella: a short stout ellipsoid lying along the bend of the leg there.
			local bend = (knee - hip).Unit + (ankle - knee).Unit
			local along = if bend.Magnitude > 1e-3 then bend.Unit else (knee - hip).Unit
			put(leg.knee, rodCFrame(knee - along, knee + along))
		else
			put(leg.knee, CFrame.new(knee))
		end
		put(leg.ankle, CFrame.new(ankle))
		if leg.joint then put(leg.joint, CFrame.new(tarsusMid)) end
		local pad = leg.pad
		if pad and form then
			-- The tarsal pad lies on the surface under the foot, flattened, its long side along the way the foot points; the toes (claws, or a
			-- scopula's bristles) leave its rim. All of it is display: the planted foot is where it was.
			local into = foot - (if leg.joint then tarsusMid else ankle)
			local flat = into - up * into:Dot(up)
			local heading = if flat.Magnitude > 1e-4 then flat.Unit else body.LookVector
			local center = foot + up * (pad.Size.Y * 0.35)
			put(pad, CFrame.lookAt(center, center + heading, up) * CFrame.Angles(0, math.pi / 2, 0))
			local right = heading:Cross(up)
			for n, toe in leg.toes do
				local first = (n - 1) % 2 == 0
				local sideways = if first then -1 else 1
				if toe.Name == "Claw" then
					-- two claws: from the pad's front, forward and down, splayed apart
					local from = center + heading * (pad.Size.X * 0.42)
					local aim = (heading * 0.85 - up * 0.45 + right * (sideways * form.claws.splay)).Unit
					put(toe, rodCFrame(from, from + aim * (toe.Size.X)))
				else
					-- scopula bristles: short rods out of the pad's sides, swept forward and a little down
					local sway = if (cfg.strands or 0) > 1 then sideways else 0 -- (one bristle points straight ahead)
					local from = center + right * (sway * pad.Size.Z * 0.40) + heading * (pad.Size.X * (if sway == 0 then 0.38 else 0.1))
					local aim = (right * sway * 0.9 + heading * (if sway == 0 then 1.0 else 0.5) - up * 0.25).Unit
					put(toe, rodCFrame(from, from + aim * (toe.Size.X)))
				end
			end
		elseif pad then
			put(pad, CFrame.new(foot))
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Sets the fan's discs for how far it is open (0: folded on the abdomen, 1: a near-round disc) in the abdomen's frame. The discs grow from
-- Appearances.fan.folded to full size; the figure and the repeat on the back follow; the folded flaps swing out from the flanks and end
-- under the discs. Flat ellipsoids: only their size and place change.
function SpiderRig._drawFan(self: Rig, abdomen: CFrame, open: number, put: (BasePart, CFrame) -> ())
	local fan = self._fan :: Fan
	local fc, A = fan.cfg, self._layout
 local g=self._growth
 local c=self._shownCondition
 local condition=Vector3.new(.84+.30*c,.84+.30*c,.93+.12*c)
 local output=put
 local inverse=abdomen:Inverse()
 put=function(p: BasePart,cf: CFrame)
  local relative=inverse*cf
  local at=A.abdomenCenter+(relative.Position-A.abdomenCenter)*condition
  p.Size=p.Size*condition
  output(p,abdomen*CFrame.new(at*g)*relative.Rotation)
 end
	local sx = fc.folded[1] + (1 - fc.folded[1]) * open
	local sz = fc.folded[2] + (1 - fc.folded[2]) * open
	local fold = 1 - open
	local top = A.abdomenCenter.Y + A.abdomenRadii.Y + fc.plane - fc.foldedSink * fold
	local z = A.abdomenCenter.Z + fc.zShift * open
	local thick = fc.thickness + (fc.foldedThickness - fc.thickness) * fold
	local function place(d: FanDisc, y: number, t: number)
		local rx, rz = math.max((fc.radii[1] - d.inset) * sx, 0.002), math.max((fc.radii[2] - d.inset) * sz, 0.002)
		local size = Vector3.new(rx * 2, t, rz * 2)*g
		if (d.part.Size - size).Magnitude > 1e-5 then d.part.Size = size end
		put(d.part, abdomen * CFrame.new(0, y, z))
	end
	for _, d in fan.front do place(d, top + d.y, thick) end
	local mid = A.abdomenCenter.Y - A.abdomenRadii.Y
	for _, d in fan.back do place(d, mid + d.y, fc.thickness) end
	local figureY = top + #fan.front * fc.layerStep + (thick - fc.thickness) * 0.5
	local show = open * open * (3 - 2 * open) -- the black figure shows as the fan opens, and is gone when it is folded
	for _, f in fan.figure do
		local size = Vector3.new(math.max(f.rx * fc.radii[1] * sx * 2 * show, 0.002), fc.thickness, math.max(f.rz * fc.radii[2] * sz * 2 * show, 0.002))*g
		if (f.part.Size - size).Magnitude > 1e-5 then f.part.Size = size end
		put(f.part, abdomen * CFrame.new(f.x * fc.radii[1] * sx, figureY, z + f.z * fc.radii[2] * sz) * CFrame.Angles(0, f.angle, 0))
	end
	local fl = fc.flaps
	local angle = math.rad(fl.foldedDeg) * (1 - open)
	for _, f in fan.flaps do
		f.part.Size=self._sizes[f.part]*g
		local hinge = Vector3.new(f.side * fl.hingeX, A.abdomenCenter.Y + fl.hingeY, A.abdomenCenter.Z + fc.zShift * open)
		put(f.part, abdomen * CFrame.new(hinge) * CFrame.Angles(0, 0, f.side * angle) * CFrame.new(f.side * fl.radii[1], 0, 0))
	end
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
	local fan = self._fan
	if fan then
		for _, part in fan.parts do show(part, not hideBody) end
	end
	for _, leg in self._legs do
		local frontReach = self._eyeView and leg.pair == 1
		local all = not hideBody
		show(leg.femur, all); show(leg.knee, all)
		if leg.femurTip then show(leg.femurTip, all) end
		show(leg.tibia, all or frontReach)
		if leg.tibiaTip then show(leg.tibiaTip, all or frontReach) end
		show(leg.tarsus, all or frontReach); show(leg.ankle, all or frontReach)
		if leg.tarsusTip then show(leg.tarsusTip, all or frontReach) end
		if leg.joint then show(leg.joint, all or frontReach) end
		for _, toe in leg.toes do show(toe, all or frontReach) end
		for n, band in leg.bands do show(band, all or (frontReach and n >= 2)) end
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
	return self._spinneret or body:PointToWorldSpace(self._layout.spinneret*self._growth - Vector3.new(0, self._drop, 0))
end

function SpiderRig.destroy(self: Rig)
	self.model:Destroy()
end

return SpiderRig
