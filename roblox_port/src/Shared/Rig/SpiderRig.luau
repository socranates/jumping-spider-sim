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
-- the tarsus, a pad (and claws) at the foot. An appearance without those tables is drawn exactly as it was.

local Workspace = game:GetService("Workspace")
local Appearances = require(script.Parent.Parent.Data.Appearances)
local Anatomy = require(script.Parent.Anatomy)
local Setae = require(script.Parent.Setae)
local Idle = require(script.Parent.Idle)
local Living = require(script.Parent.Living)
local Growth = require(script.Parent.Parent.Life.Growth)
local v3 = Anatomy.v3

local SpiderRig = {}
SpiderRig.__index = SpiderRig

export type GaitMode = "Tetrapod" | "Unilateral"

local STEP_ERROR = 0.24
local SWING_SECONDS = 0.10
local STEP_HEIGHT = 0.12
local made = 0 -- rigs made so far: each one's living motion draws from its own seeded stream
local ANKLE_SHARE = 0.62
-- The groups a fixed part follows: the body, the head (tilts about the neck) or the abdomen (breathes).
local G_BODY, G_HEAD, G_ABDOMEN = 0, 1, 2
-- Drawing only what moved (ROBLOX-93). The hairs follow one frame each (the head's, the abdomen's, a palp's, a leg link's) and are sent to the engine in a second
-- batch, after the body's: a kind of hair is placed again only when its frame has moved by more than MOVE_STUDS (a place, studs) or MOVE_RADIANS (a turn) since it
-- was last placed, or when the abdomen's scale (its condition, its breath) has moved by more than SCALE_STEP. The tolerance is measured from where the hairs were last
-- placed, not from the last frame, so a slow drift cannot hide: it is placed again once it has added up. (The body's batch is every frame as it was.)
local MOVE_STUDS, MOVE_RADIANS, SCALE_STEP = 1e-4, 1e-3, 1e-4
-- A leg's pale band is given a new length only when it is more than BAND_STEP off (the rods' own tolerance), so a leg that stands still writes none.
local BAND_STEP = 1e-3
local MOVE_TURN = MOVE_RADIANS * MOVE_RADIANS -- (3 minus the trace of the relative rotation is about the turn's square)
-- A rival or a mate farther than FAR_STUDS from the camera is drawn once every FAR_SECONDS (SpiderRig.drawStep).
local FAR_STUDS, FAR_SECONDS = 25, 0.1
-- The lengths of a reach to a foothold, tried in turn (a narrow edge takes the shorter ones).
local REACHES = { 1.0, 0.65, 0.35, 0.12 }
local LEG_NAMES = { "femur", "tibia", "tarsus" }

-- One leg hair: its part and where it grows (spec), with what the drawing needs of it worked out once (ROBLOX-93): the angle round the leg as a cosine and a sine,
-- how far out of the leg it grows (k: 0.8 of the radius, or 1 for a coat that lies along the leg) and its direction in the link's frame.
type LegHair = { part: Part, spec: Setae.LegHair, c: number, s: number, k: number, dir: Vector3 }
-- One link of a leg (femur, tibia, tarsus): its rod, the thinner tip rod and the pale band it may have, the length each is drawn at and the diameters of the rods (what
-- the part's Size holds; kept here so a frame reads no property), the hairs on it, and where they were last placed (its frame and length).
type Seg = {
	rod: Part, tip: Part?, band: Part?, hairs: { LegHair },
	x: number, tipX: number, bandX: number, dy: number, dz: number, tipDy: number, tipDz: number,
	rc: CFrame, len: number,
}

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
	tibiaTip: Part?, -- all nil for an appearance without one), and the foot's claws
	tarsusTip: Part?,
	joint: Part?,
	toes: {Part},
	bands: {Part}, -- empty for a pair drawn without pale bands (the peacock spider's legs III)
	hangKnee: Vector3?, -- where the hanging pose puts the knee and the ankle this frame (world space), or nil off the line (ROBLOX-86)
	hangAnkle: Vector3?,
	hairs: { LegHair },
	segs: { Seg }, -- the femur, the tibia, the tarsus
	rest: Vector3, hip: Vector3, -- where the foot rests and where the hip is, in the body frame at the rig's scale (worked out when the scale changes, not every frame)
	noise: { number }?, -- the hanging pose's fixed scatter for this leg (six numbers), made the first time it hangs
}

-- (glance: a principal eye or its catchlight, which shifts toward what is watched; big: an abdomen mass that is resized as it breathes.) `pos` and `rot` are the offset's
-- two halves, `scaled` the offset at the rig's scale, `size0` the part's size at scale 1 and `size` the size it has now (ROBLOX-93: kept here, so a frame reads no property).
type Fixed = {
	part: Part, offset: CFrame, group: number, palp: number?, sweep: number?, glance: boolean?, big: boolean?,
	pos: Vector3, rot: CFrame, scaled: CFrame, size0: Vector3, size: Vector3,
	jaw: number?, pivot: Vector3?, -- (ROBLOX-127) a chelicera or a fang: its side, and the point at the chelicera's base it swings out about in the rival's display
}

-- The parts of one BulkMoveTo and where each goes: a rig makes two a frame, the body's and the hairs' (the hairs' only when they moved).
type Batch = { parts: { BasePart }, frames: { CFrame }, n: number }

-- Where each group of hairs, and each size that follows the abdomen's condition, was last placed (see MOVE_STUDS): the frame it followed, the abdomen's breath then,
-- the condition its sizes were made for and the scale epoch they were made at.
type Seen = {
	body: CFrame, head: CFrame, abdomen: CFrame, palpHead: { CFrame }, pivot: { CFrame },
	breath: number, sizeKey: Vector3, epoch: number,
}

-- The peacock spider's fan: flat ellipsoid discs on the abdomen's back face, stacked fringe first, their size set each frame by how far the fan is open.
-- (`sizes`: what each part's Size holds, kept here so that a frame reads none and writes only what changed.)
type FanDisc = { part: Part, inset: number, y: number }
type FanFigure = { part: Part, x: number, z: number, rx: number, rz: number, angle: number, turn: CFrame } -- (turn: the angle as a CFrame, made once: ROBLOX-113)
type Fan = { front: { FanDisc }, back: { FanDisc }, figure: { FanFigure }, flaps: { { part: Part, side: number } }, cfg: any, parts: { Part }, sizes: { [BasePart]: Vector3 } }

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
		_bodyBatch: Batch, -- the body's parts and where they go this frame
		_hairBatch: Batch, -- the hairs that moved this frame (none when nothing did)
		_bodyFixed: { Fixed }, -- _fixed without the hairs; the hairs by the frame they follow (the head, the body, each palp, the abdomen)
		_headHairs: { Fixed },
		_bodyHairs: { Fixed },
		_palpHairs: { { Fixed } },
		_abdomenHairs: { Fixed },
		_seen: Seen,
		_pose: Idle.Pose, -- the idle pose, made again in place each frame
		_epoch: number, -- counts the scale changes: what was placed for an earlier scale is placed again
		_exact: boolean, -- tests: place every hair again every frame, with no tolerance (what the drawing is compared with)
		_stage: number, -- the growth stage last applied (-1 before the first)
		_owed: number, _drawn: boolean, -- drawStep: the time not yet drawn, and whether the rig has been drawn at all
		placed: number?, -- the parts the last drawing placed (ROBLOX-113, for the self-test's profile)
		_k: number,
  _growth: number,
  _softness: number,
  _condition: number,
  _shownCondition: number,
  hangDirection: Vector3?,
  _hang: number,
  focusPoint: Vector3?, -- the point the player watches (world space), or nil: the drawn body turns toward it a little and the eyes glance at it (ROBLOX-87)
  _living: Living.State?, -- the living motion (attention, grooming, alarm, a tarantula's stretch), or nil below the full tier
  _breath: number, -- how much the abdomen breathes now, 0..1
  _mealsSeen: number?,
  _lineDir: Vector3, -- the last direction up the line (it stays while the pose blends out)
  _hangT: number, -- seconds since the drop: the sway's clock
  _spin: number, _spinVel: number, -- the slow turn about the line (radians, radians a second)
  _hangCount: number, -- drops so far (the turn alternates its direction)
  _lastPos: Vector3?, _lineSpeed: number, _climbing: boolean, _climb: number, -- the climb: speed along the line, whether it counts, the head-up blend 0..1
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

-- A cylinder's axis is its local X: aim it from a to b. (ROBLOX-113: the quarter turn is made once, not with every rod of every frame; the frames are the same to the bit.)
local QUARTER = CFrame.Angles(0, math.pi / 2, 0)
local function rodCFrame(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) * 0.5, b) * QUARTER
end

-- A hair's "up" for lookAt: its surface normal, unless that is (nearly) along the hair.
local function upFor(dir: Vector3, normal: Vector3): Vector3
	if math.abs(dir:Dot(normal)) < 0.97 then return normal end
	return if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.zAxis
end

local GROUP_OF: { [string]: number } = { head = G_HEAD, abdomen = G_ABDOMEN }

-- ---------------------------------------------------------------- what a frame is made of: module functions, so that nothing is made again every frame (ROBLOX-93)

-- Adds a part and its place to a batch.
local function put(batch: Batch, p: BasePart, cf: CFrame)
	local n = batch.n + 1
	batch.n = n
	batch.parts[n] = p
	batch.frames[n] = cf
end

local function emptyBatch(): Batch
	return { parts = {}, frames = {}, n = 0 }
end

local function clearBatch(batch: Batch)
	table.clear(batch.parts)
	table.clear(batch.frames)
	batch.n = 0
end

-- An offset at the rig's scale: its place is scaled about the body's origin, its turn is not.
-- (ROBLOX-113: a rotation moved to a place is `rotation + place`, one CFrame where CFrame.new(place) * rotation made two; the same frame to the bit, since the
-- product with the identity adds only zeros. A frame of the full rig made about 1,700 CFrames for 690 parts; this and the like below are most of the difference.)
local function scaled(cf: CFrame, g: number): CFrame
	return if g == 1 then cf else cf.Rotation + cf.Position * g
end

-- Has `now` moved from `was` by more than MOVE_STUDS in place or MOVE_RADIANS in turn? The turn comes from the trace of the relative rotation, the sum of the dot
-- products of the two frames' three axes (no angle is worked out): it is 3 for no turn and 3 - 2 (1 - cos a) for a turn of a.
local function moved(was: CFrame, now: CFrame): boolean
	if (now.Position - was.Position).Magnitude > MOVE_STUDS then return true end
	local trace = now.RightVector:Dot(was.RightVector) + now.UpVector:Dot(was.UpVector) + now.LookVector:Dot(was.LookVector)
	return 3 - trace > MOVE_TURN
end

-- Gives an abdomen part the size it should have, if it differs from what it has (a part's size is kept in `f.size`; the property is written, never read).
local function resize(f: Fixed, size: Vector3)
	if (f.size - size).Magnitude > 1e-5 then
		f.size = size
		f.part.Size = size
	end
end

-- A link of a leg that has not been drawn yet: refreshScale fills in its sizes, and bandX and len at -1 mean "write the band's size, place the hairs" at the first drawing.
local function newSeg(rod: Part, tip: Part?, band: Part?): Seg
	return {
		rod = rod, tip = tip, band = band, hairs = {},
		x = 0, tipX = 0, bandX = -1, dy = 0, dz = 0, tipDy = 0, tipDz = 0,
		rc = CFrame.identity, len = -1,
	}
end

-- Works out what the rig's scale fixes (ROBLOX-93), when the rig is made and whenever the scale changes: each fixed part's offset and size at that scale (the size
-- setScale has just given every part), each leg's hip and rest in the body frame, the lengths and diameters its links hold, and the fan's sizes. A frame only reads these.
local function refreshScale(self: Rig)
	local g, sizes = self._growth, self._sizes
	for _, f in self._fixed do
		f.scaled = scaled(f.offset, g)
		f.size0 = sizes[f.part]
		f.size = f.size0 * g
	end
	local L = self._appearance.limbs
	local stance, longer = L.stance, L.pairReach
	for _, leg in self._legs do
		local r = stance.reach * (if longer then longer[leg.pair] else 1) -- (the peacock spider's legs III are the longest)
		leg.rest = Vector3.new(leg.side * stance.x * r, stance.y, L.tipZ[leg.pair] * r) * g
		leg.hip = Vector3.new(leg.side * L.hipX, L.hipY, L.hipZ[leg.pair]) * g
		for _, seg in leg.segs do
			local size = sizes[seg.rod]
			seg.x, seg.dy, seg.dz = size.X * g, size.Y * g, size.Z * g
			local tip = seg.tip
			if tip then
				local tipSize = sizes[tip]
				seg.tipX, seg.tipDy, seg.tipDz = tipSize.X * g, tipSize.Y * g, tipSize.Z * g
			end
			seg.bandX, seg.len = -1, -1 -- the band is given its size, and the hairs their places, at the next drawing
		end
	end
	local fan = self._fan
	if fan then
		for _, part in fan.parts do fan.sizes[part] = sizes[part] * g end
	end
end

-- detail "low" is for phones and tablets: fewer hairs, one fur shell, no foot balls, half the speckles, no outline, no
-- breathing or head tilt (Appearances.detail). Anything else is the full look. `living` (ROBLOX-89: the mate, which has to breathe and take the mating scene's cues
-- at the low tier) turns the living motion on at a tier that has none, for the same parts.
function SpiderRig.new(parent: Instance, worldFolder: Instance, appearanceId: string?, detail: string?, living: boolean?): Rig
	local look = Appearances.profiles[appearanceId or Appearances.default]
	assert(look, "Unknown spider appearance")
	local detailName = if detail == "low" then "low" else "full"
	local cfg = look.detail[detailName]
	if living == true and not cfg.idle then
		cfg = table.clone(cfg)
		cfg.idle = true
	end
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
		_bodyBatch = emptyBatch(),
		_hairBatch = emptyBatch(),
		_bodyFixed = {} :: { Fixed },
		_headHairs = {} :: { Fixed },
		_bodyHairs = {} :: { Fixed },
		_palpHairs = { {}, {} } :: { { Fixed } },
		_abdomenHairs = {} :: { Fixed },
		_seen = {
			body = CFrame.identity, head = CFrame.identity, abdomen = CFrame.identity, palpHead = { CFrame.identity, CFrame.identity }, pivot = { CFrame.identity, CFrame.identity },
			breath = 0, sizeKey = Vector3.zero, epoch = 0,
		} :: Seen,
		_pose = { bodyLift = 0, abdomenLift = 0, abdomenPitch = 0, headRoll = 0, headYaw = 0, headPitch = 0 } :: Idle.Pose,
		_epoch = 1,
		_exact = false,
		_stage = -1,
		_owed = 0,
		_drawn = false,
		_k = look.scale or 1,
  _growth = 1, _softness = 0, _condition = 0.55, _shownCondition = 0.55, jumpLoad = 0, jumpPush = 0, _shownLoad = 0,
  hangDirection=nil :: Vector3?, _hang=0, _spinneret=nil :: Vector3?,
  focusPoint = nil :: Vector3?, _living = nil :: Living.State?, _breath = 0, _mealsSeen = nil :: number?,
  _lineDir = Vector3.yAxis, _hangT = 0, _spin = 0, _spinVel = 0, _hangCount = 0, _lastPos = nil :: Vector3?, _lineSpeed = 0, _climbing = false, _climb = 0,
  _sizes = {} :: {[BasePart]: Vector3}, _colors = {} :: {[BasePart]: Color3}, _bars = {} :: { Part },
		_drop = look.bodyDrop or 0,
		_fan = nil :: Fan?,
		dance = nil :: any,
		ant = nil :: any,
		threat = nil :: any,
	}, SpiderRig)

	made += 1
	local idleLook = look.idle
	if cfg.idle and (idleLook.groom or idleLook.attention or idleLook.alarm or idleLook.stretch or idleLook.meet or idleLook.settle) then
		self._living = Living.new(idleLook, Living.hash(look.id) + 7919 * made)
	end
	local function fixed(part: Part, at: Vector3, rot: CFrame?, group: number, palp: number?): Fixed
		local offset = CFrame.new(at) * (rot or CFrame.identity)
		local entry: Fixed = {
			part = part, offset = offset, group = group, palp = palp, sweep = nil, glance = nil, big = nil,
			pos = offset.Position, rot = offset.Rotation, scaled = offset, size0 = Vector3.zero, size = Vector3.zero, jaw = nil, pivot = nil,
		}
		table.insert(self._fixed, entry)
		return entry
	end
	local fabric = Enum.Material.SmoothPlastic -- clean high-contrast silhouette
	fixed(ellipsoid(model, "Cephalothorax", A.headRadii, BODY, fabric), A.headCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "EyeFace", A.faceRadii, BODY, fabric), A.faceCenter, nil, G_HEAD)
	fixed(ellipsoid(model, "Pedicel", A.pedicelRadii, BODY, fabric), A.pedicelCenter, nil, G_BODY)
	fixed(ellipsoid(model, "Abdomen", A.abdomenRadii, ABDOMEN, fabric), A.abdomenCenter, nil, G_ABDOMEN).big = true
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
	-- A tarantula's velvet (look.velvet, ROBLOX-85): a fur shell per body mass, a little larger than the carapace and the abdomen it covers, partly
	-- transparent, in Fabric and in the fur's colour. The head's stops short of the tubercle's eyes by being no taller than the carapace's dome.
	local velvet = look.velvet
	if velvet and cfg.velvet then
		local cover = ellipsoid(model, "FuzzShell", A.headRadii * velvet.head.scale, color(velvet.head.color), Enum.Material.Fabric)
		cover.Transparency, cover.CastShadow = velvet.head.transparency, false
		fixed(cover, A.headCenter, nil, G_HEAD)
		local coat = ellipsoid(model, "FuzzShell", A.abdomenRadii * velvet.abdomen.scale, color(velvet.abdomen.color), Enum.Material.Fabric)
		coat.Transparency, coat.CastShadow = velvet.abdomen.transparency, false
		fixed(coat, A.abdomenCenter, nil, G_ABDOMEN).big = true
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
			-- (`height`: a ridge, a thin rod-shaped ellipsoid that stands that many studs half-height out of the surface, centred `raise` above it,
			-- instead of a flat dab, ROBLOX-85; its pointed ends dive into the fur shell, so it follows the dome where a straight cylinder would float)
			local dab = ellipsoid(model, m.name, Vector3.new(m.rx, m.height or 0.010, m.rz), color(m.color), fabric)
			dab.CastShadow = false
			fixed(dab, Vector3.new(x * ar.X, ac.Y + ar.Y * q + (m.raise or 0.002), ac.Z + z * ar.Z), CFrame.Angles(pitch, 0, roll) * CFrame.Angles(0, side * m.angle, 0), G_ABDOMEN)
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
		fixed(eye, e.at, nil, G_HEAD).glance = e.principal
		-- (ROBLOX-127) depth: the lens lets a little light through onto a dark retina set back in the eye (look.eye.ame.lens; the full tier's `retina`)
		local lens = if e.principal and look.eye.ame then look.eye.ame.lens else nil
		if lens and cfg.retina then
			eye.Transparency = lens.transparency
			local rt = lens.retina
			local retina = ellipsoid(model, "Retina", e.radii * rt.scale, color(rt.color), fabric)
			retina.CastShadow = false
			fixed(retina, e.at + Vector3.new(0, 0, e.radii.Z * rt.depth), nil, G_HEAD).glance = true
		end
		if e.principal and cfg.sockets then
			local socket = ellipsoid(model, "EyeSocket", e.radii * look.eye.ame.socket.scale, SOCKET, fabric)
			socket.CastShadow = false
			fixed(socket, e.at + Vector3.new(0, 0, 0.03), nil, G_HEAD).glance = true
		end
	end
	local GLINT = color(look.eye.glintColor)
	for _, g in A.glints do
		local glint = ellipsoid(model, "Catchlight", g.radii, GLINT, Enum.Material.Neon)
		glint.CastShadow = false
		fixed(glint, g.at, nil, G_HEAD).glance = tubercle == nil -- (the catchlights of the big front eyes; a tarantula's are on its tubercle's beads)
	end
	local cl = look.chelicerae
	local jawPivot: { [number]: Vector3 } = {}
	for _, j in A.jaws do
		local fang = ellipsoid(model, "Chelicera", j.radii, if cl.color then color(cl.color) else FANG, Enum.Material.Foil) -- (ROBLOX-127: a colour of their own, the bold jumper's green)
		fang.Reflectance = cl.reflectance
		local entry = fixed(fang, j.at, CFrame.Angles(cl.pitch, 0, j.side * cl.splay), G_HEAD)
		jawPivot[j.side] = j.at + Vector3.new(0, j.radii.Y * 0.75, j.radii.Z * 0.3) -- the chelicera's base, high at the back, where it joins the face
		entry.jaw, entry.pivot = j.side, jawPivot[j.side]
	end
	-- Fangs (look.fang): chains of dark, glossy ellipsoids hanging from the chelicerae's lower front, each segment turned along its own direction.
	for _, f in A.fangs do
		if f.index > (cfg.fangSegments or 0) then continue end
		local tooth = ellipsoid(model, "Fang", f.radii, if look.fang.color then color(look.fang.color) else FANG, Enum.Material.Foil)
		tooth.Reflectance = look.fang.reflectance
		tooth.CastShadow = false
		local entry = fixed(tooth, f.at, CFrame.lookAt(Vector3.zero, f.dir), G_HEAD)
		entry.jaw, entry.pivot = f.side, jawPivot[f.side] -- (a fang goes where its chelicera goes)
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
			fixed(a, A.abdomenCenter, nil, G_ABDOMEN).big = true
			local h = ellipsoid(model, "FuzzShell", Vector3.new(hr.X * shell.scale, hr.Y * shell.scale, hr.Z * hs.zScale), SHELL, fabric)
			h.Transparency, h.CastShadow = shell.transparency, false
			fixed(h, A.headCenter + Vector3.new(0, 0, hs.shift + 0.01 * k), nil, G_HEAD)
		end
		-- (A tier keeps one hair in `every` of each class: Setae.thin, which counts the two sides of a mirrored pair each by itself.)
		for _, hair in Setae.thin(Setae.body(look), cfg.every) do
			local h = seta(hair.tone, hair.width, hair.thick, hair.length, hair.transparency)
			local mid = hair.at + hair.dir * (hair.length * 0.5)
			fixed(h, mid, CFrame.lookAt(Vector3.zero, hair.dir, upFor(hair.dir, hair.normal)), GROUP_OF[hair.group] or G_BODY)
		end
		for _, hair in Setae.thin(Setae.palp(look), cfg.every) do
			local index = if hair.side < 0 then 1 else 2
			local h = seta(hair.tone, hair.width, hair.thick, hair.length, hair.transparency)
			local mid = hair.at + hair.dir * (hair.length * 0.5)
			local rest = CFrame.lookAt(mid, mid + hair.dir, upFor(hair.dir, hair.normal))
			fixed(h, Vector3.zero, CFrame.new(self._palpBase[index]):Inverse() * rest, G_HEAD, index)
		end
	end

	-- The redknee's urticating patch (look.cluster, ROBLOX-85): a tuft of ginger-rust hairs standing out of the patch, combed toward the rear.
	if look.cluster and cfg.cluster then
		local tuftLook = look.cluster
		for _, hair in Setae.cluster(look) do
			local h = newPart(model, "Seta", color(if hair.tone == "frost" then tuftLook.light else tuftLook.color), fabric)
			h.Size, h.CastShadow, h.Transparency = Vector3.new(hair.width, hair.thick, hair.length), false, hair.transparency
			table.insert(self._setae, h)
			fixed(h, hair.at + hair.dir * (hair.length * 0.5), CFrame.lookAt(Vector3.zero, hair.dir, upFor(hair.dir, hair.normal)), G_ABDOMEN)
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
				local cw = form.claws
				for _ = 1, if cw then cfg.claws or 0 else 0 do
					local claw = rod(model, "Claw", cw.radius * 2, FANG)
					claw.Size, claw.CastShadow = Vector3.new(cw.length, cw.radius * 2, cw.radius * 2), false
					table.insert(toes, claw)
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
			hangKnee = nil :: Vector3?,
			hangAnkle = nil :: Vector3?,
			hairs = {},
			segs = {},
			rest = Vector3.zero, hip = Vector3.zero,
			noise = nil :: { number }?,
		})
		local leg = self._legs[#self._legs]
		leg.segs = { newSeg(leg.femur, leg.femurTip, leg.bands[1]), newSeg(leg.tibia, leg.tibiaTip, leg.bands[2]), newSeg(leg.tarsus, leg.tarsusTip, leg.bands[3]) }
		if fuzz and fuzz.enabled then
			for n, spec in Setae.leg(look, i) do
				if cfg.every.leg <= 0 or n % cfg.every.leg ~= 0 then continue end
				-- (what the drawing needs of a hair is worked out here, once: see LegHair)
				local c, sn, lie = math.cos(spec.theta), math.sin(spec.theta), spec.lift
				local entry: LegHair = {
					part = seta(spec.tone, fuzz.legWidth, fuzz.legWidth, spec.length, fuzz.legTransparency), spec = spec, c = c, s = sn,
					k = if lie then 1.0 else 0.8,
					dir = if lie then Vector3.new(math.cos(lie), math.sin(lie) * c, math.sin(lie) * sn) else Vector3.new(1.3, c, sn).Unit,
				}
				table.insert(leg.hairs, entry)
				table.insert(leg.segs[spec.segment].hairs, entry)
			end
			-- (ROBLOX-127) the fringe: longer hairs of their own width standing out from the link's sides (look.fuzz.legFringe), one in `every.legFringe` kept
			local keepFringe = cfg.every.legFringe or 1
			for n, spec in Setae.legFringe(look, i) do
				if keepFringe <= 0 or n % keepFringe ~= 0 then continue end
				local c, sn, lie = math.cos(spec.theta), math.sin(spec.theta), spec.lift or 1
				local width = spec.width or fuzz.legWidth
				local entry: LegHair = {
					part = seta(spec.tone, width, width, spec.length, spec.transparency or fuzz.legTransparency), spec = spec, c = c, s = sn, k = 0.9,
					dir = Vector3.new(math.cos(lie), math.sin(lie) * c, math.sin(lie) * sn),
				}
				table.insert(leg.hairs, entry)
				table.insert(leg.segs[spec.segment].hairs, entry)
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
		local fan: Fan = { front = {}, back = {}, figure = {}, flaps = {}, cfg = fc, parts = {}, sizes = {} }
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
			table.insert(fan.figure, { part = part, x = f.x, z = f.z, rx = f.rx, rz = f.rz, angle = f.angle, turn = CFrame.Angles(0, f.angle, 0) })
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
	-- The body's parts are placed every frame; the hairs, by the frame each follows (ROBLOX-93), only when that frame has moved.
	for _, f in self._fixed do
		local palp = f.palp
		if f.part.Name ~= "Seta" then
			table.insert(self._bodyFixed, f)
		elseif palp ~= nil then
			table.insert(self._palpHairs[palp], f)
		elseif f.group == G_HEAD then
			table.insert(self._headHairs, f)
		elseif f.group == G_ABDOMEN then
			table.insert(self._abdomenHairs, f)
		else
			table.insert(self._bodyHairs, f)
		end
	end
	refreshScale(self)
	model.Parent = parent
	self:setGrowthStage(0)
	return self
end

-- Scale about the support plane, not the collider centre. Planted contacts remain world-space points.
-- (ROBLOX-93: a stage already applied writes nothing again, and setScale returns at once for the scale it has: the mate stage asks every frame.)
function SpiderRig.setGrowthStage(self: Rig, stage: number)
 local index=math.clamp(math.floor(stage),0,3)
 if index~=self._stage then
  self._stage=index
  self.model:SetAttribute("GrowthStage",index)
  local fade=self._appearance.barFade -- the Greenbottle blue's juvenile bars soften at the last stage
  if fade then for _,bar in self._bars do bar.Transparency=fade[index+1] end end
 end
 self:setScale(self:growthScale(index))
end
-- (ROBLOX-114) The scale a growth stage is drawn at: Growth.SCALES (golden), or the appearance's own `growth` where it has one (a costume whose species' adult is
-- smaller than Growth's adult would draw it: the peacock spider and the ant mimic grow to their real adults' size, 5 and 6 mm). The collider is never touched.
function SpiderRig.growthScale(self: Rig, stage: number): number
 local index=math.clamp(math.floor(stage),0,3)
 local scales=self._appearance.growth or Growth.SCALES
 return scales[index+1]
end
-- Any size, not only a growth stage's (ROBLOX-80: the mate is the played spider's look at the adult scale times its own factor). The same scaling as a stage.
function SpiderRig.setScale(self: Rig, g: number)
 if self._growth==g then return end
 self._growth=g
 self._k=(self._appearance.scale or 1)*g
 self._drop=0.31-(0.31-(self._appearance.bodyDrop or 0))*g
 self._epoch+=1 -- what was placed for the old scale is placed again
 for p,size in self._sizes do p.Size=size*g end
 refreshScale(self)
end
function SpiderRig.setSoftness(self: Rig, value: number)
 local s=math.clamp(value,0,1)
 if math.abs(s-self._softness)<0.001 then return end
 self._softness=s
 for p,c in self._colors do
  -- The eyes stay dark and readable; pigment returns as the skin hardens.
  if p.Material~=Enum.Material.Glass and p.Name~="Catchlight" and p.Name~="Retina" then p.Color=c:Lerp(Color3.new(0.88,0.82,0.69),s*0.72) end
 end
end
function SpiderRig.setCondition(self: Rig, energy: number)
 self._condition=math.clamp(energy,0,1)
end

-- A cue from the host for the living motion (ROBLOX-87): "groom" (a meal has just ended: a longer cleaning once it stands still) or "alarm" (the wasp's
-- warning or the rival's windup: legs I up and the idle motion frozen for a moment). Anything else, or a rig below the full tier, ignores it.
-- ROBLOX-89: "meet" (reach out to the other spider) and "settle" (sink and breathe deeper) for the mating scene, each for `seconds` (default the look's own), and
-- "release" to let both go; a rig without the living motion (the ant mimic, the low tier unless made `living`) ignores them.
function SpiderRig.cue(self: Rig, name: string, seconds: number?)
	local living = self._living
	if living ~= nil then Living.cue(living, name, seconds) end
end

-- The host's count of meals finished so far: a rise cues the "groom". (The first count only sets the baseline: a spider loaded from a save does not clean itself.)
function SpiderRig.noteMeals(self: Rig, count: number)
	local seen = self._mealsSeen
	self._mealsSeen = count
	if seen ~= nil and count > seen then self:cue("groom") end
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


-- Display-only foothold: retract toward the body at a narrow edge; never invents a platform.
local function target(self: Rig, body: CFrame, leg: Leg): RaycastResult?
	local up = body.UpVector
	local rest = leg.rest
	local k = self._k
	for _, reach in REACHES do
		local point = body:PointToWorldSpace(Vector3.new(rest.X * reach, 0, rest.Z * reach))
		local hit = Workspace:Raycast(point + up * (0.35 * k), -up * (1.0 * k), self._params)
		if hit and hit.Normal:Dot(up) > 0.35 then
			return hit
		end
	end
	return nil
end

-- The hanging pose of one leg (ROBLOX-86): the knee, the ankle and the foot in world space, from the directions in look.hang.legs. Each link keeps
-- the length it has standing (hip to knee, knee to ankle, ankle to foot, as the walking pose draws them), so legs I and II curl forward and back up
-- toward the line, III and IV fold back along the body, and nothing reaches for the ground. A fixed scatter per leg keeps the pair from mirroring
-- exactly; the feet tremble a little (not with Reduced Motion); going up the line the legs' directions along the body turn over (`_climb`), so legs I
-- reach up the line and legs IV trail.
function SpiderRig._hangLeg(self: Rig, leg: Leg, body: CFrame): (Vector3, Vector3, Vector3)
	local look, L, g = self._appearance, self._appearance.limbs, self._growth
	local hang = look.hang
	local hip, rest = leg.hip, leg.rest
	local knee0 = hip:Lerp(rest, 0.48) + Vector3.yAxis * (L.kneeLift * g)
	local ankle0 = knee0:Lerp(rest, ANKLE_SHARE) + Vector3.yAxis * (L.ankleLift * g)
	local len1, len2, len3 = (knee0 - hip).Magnitude, (ankle0 - knee0).Magnitude, (rest - ankle0).Magnitude
	local spec = hang.legs[leg.pair]
	-- (ROBLOX-93: the scatter of each link is a fixed pair of numbers, worked out the first time the leg hangs and kept, and no table is made of the lengths or the joints)
	local scatter: { number } = leg.noise or {}
	if leg.noise == nil then
		local made = scatter
		for n = 1, 3 do
			made[2 * n - 1] = math.sin(leg.pair * 12.9898 + leg.side * 78.233 + n * 37.719)
			made[2 * n] = math.sin(leg.pair * 39.346 + leg.side * 11.135 + n * 83.155)
		end
		leg.noise = made
	end
	local climb = self._climb
	local tremble = if self.reducedMotion then 0 else math.sin(self._t * 3.2 + leg.pair * 1.7 + leg.side) * hang.wiggle
	local j1, j2, j3 = hip, hip, hip
	local at = hip
	for n = 1, 3 do
		local d = spec[LEG_NAMES[n]]
		local noise, noise2 = scatter[2 * n - 1], scatter[2 * n]
		local dz = d[3] * (1 - (if leg.pair <= 2 then 2.0 else 1.2) * climb) -- going up, legs I and II reach up the line and III and IV go out to grip it
		local dir = Vector3.new(leg.side * d[1] + noise * hang.asym, d[2] + noise2 * hang.asym + (if n == 3 then tremble else 0), dz + noise * noise2 * hang.asym).Unit
		at = at + dir * (if n == 1 then len1 elseif n == 2 then len2 else len3)
		if n == 1 then j1 = at elseif n == 2 then j2 = at else j3 = at end
	end
	return body:PointToWorldSpace(j1), body:PointToWorldSpace(j2), body:PointToWorldSpace(j3)
end

-- One link of a leg (ROBLOX-93: a function of the module, so that a frame makes no closure of it): its rod runs from a to b; with a thinner `tip` rod the first runs a to m
-- and the tip m to b (a tapered femur or tibia, the break in the tarsus). The pale band (one `bandFraction` of the whole link) and the hairs follow the link, not the
-- pieces. A size is written only when it is more than its step from the one the part has (kept in `seg`, so nothing is read from the part), and the hairs, which
-- go to the second batch, are placed again only when the link has moved.
local function drawSegment(seg: Seg, bandFraction: number, g: number, a: Vector3, m: Vector3, b: Vector3, bodyBatch: Batch, hairBatch: Batch, exact: boolean)
	local rod, tip, band = seg.rod, seg.tip, seg.band
	local len = math.max((b - a).Magnitude, 0.01)
	local ends = if tip then m else b
	local plen = math.max((ends - a).Magnitude, 0.01)
	if math.abs(seg.x - plen) > 1e-3 then
		seg.x = plen
		rod.Size = Vector3.new(plen, seg.dy, seg.dz)
	end
	local rc = rodCFrame(a, b) -- local +X runs from a toward b (toward the foot)
	put(bodyBatch, rod, if tip then rodCFrame(a, m) else rc)
	local share = plen / len
	if tip then
		local tlen = math.max((b - m).Magnitude, 0.01)
		if math.abs(seg.tipX - tlen) > 1e-3 then
			seg.tipX = tlen
			tip.Size = Vector3.new(tlen, seg.tipDy, seg.tipDz)
		end
		put(bodyBatch, tip, rodCFrame(m, b))
	end
	if band then
		local blen = len * bandFraction
		if math.abs(seg.bandX - blen) > BAND_STEP then
			seg.bandX = blen
			band.Size = Vector3.new(blen, seg.dy * 1.035, seg.dz * 1.035)
		end
		put(bodyBatch, band, rc)
	end
	-- Leg setae stand out from the segment and lean toward the foot (or, for a coat that lies along the leg, lie at their own angle).
	if exact or moved(seg.rc, rc) or math.abs(len - seg.len) > MOVE_STUDS then
		seg.rc, seg.len = rc, len
		local radius, tipRadius = seg.dy * 0.5, seg.tipDy * 0.5
		for _, hair in seg.hairs do
			local spec = hair.spec
			local r = if tip and spec.t > share then tipRadius else radius
			local base = Vector3.new((spec.t - 0.5) * len, r * hair.k * hair.c, r * hair.k * hair.s)
			local dir = hair.dir
			put(hairBatch, hair.part, rc * CFrame.lookAt(base + dir * (spec.length * g * 0.5), base + dir * spec.length*g, Vector3.xAxis))
		end
	end
end

-- Writes the size a fan part should have, if it differs from what it has (the fan keeps what each part holds; nothing is read from the part).
local function fanSize(fan: Fan, part: BasePart, size: Vector3)
	local was: Vector3? = fan.sizes[part]
	if was == nil or (was - size).Magnitude > 1e-5 then
		fan.sizes[part] = size
		part.Size = size
	end
end

-- Sets the fan's discs for how far it is open (0: folded on the abdomen, 1: a near-round disc) in the abdomen's frame. The discs grow from
-- Appearances.fan.folded to full size; the figure and the repeat on the back follow; the folded flaps swing out from the flanks and end
-- under the discs. Flat ellipsoids: only their size and place change. Each part lies on the abdomen, so its place (about the abdomen's centre) and its size go with the
-- abdomen's `condition`; ROBLOX-93: both are worked out once, from the part's own size, and a size is written once or not at all.
local function drawFan(self: Rig, fan: Fan, abdomen: CFrame, open: number, condition: Vector3, batch: Batch)
	local fc, A, g = fan.cfg, self._layout, self._growth
	local center = A.abdomenCenter
	local sx = fc.folded[1] + (1 - fc.folded[1]) * open
	local sz = fc.folded[2] + (1 - fc.folded[2]) * open
	local fold = 1 - open
	local top = center.Y + A.abdomenRadii.Y + fc.plane - fc.foldedSink * fold
	local z = center.Z + fc.zShift * open
	local thick = fc.thickness + (fc.foldedThickness - fc.thickness) * fold
	local mid = center.Y - A.abdomenRadii.Y
	for pass = 1, 2 do
		local discs: { FanDisc } = if pass == 1 then fan.front else fan.back
		local y0, t = if pass == 1 then top else mid, if pass == 1 then thick else fc.thickness
		for _, d in discs do
			local rx, rz = math.max((fc.radii[1] - d.inset) * sx, 0.002), math.max((fc.radii[2] - d.inset) * sz, 0.002)
			fanSize(fan, d.part, Vector3.new(rx * 2, t, rz * 2) * g * condition)
			put(batch, d.part, abdomen * CFrame.new((center + (Vector3.new(0, y0 + d.y, z) - center) * condition) * g))
		end
	end
	local figureY = top + #fan.front * fc.layerStep + (thick - fc.thickness) * 0.5
	local show = open * open * (3 - 2 * open) -- the black figure shows as the fan opens, and is gone when it is folded
	for _, f in fan.figure do
		fanSize(fan, f.part, Vector3.new(math.max(f.rx * fc.radii[1] * sx * 2 * show, 0.002), fc.thickness, math.max(f.rz * fc.radii[2] * sz * 2 * show, 0.002)) * g * condition)
		local at = Vector3.new(f.x * fc.radii[1] * sx, figureY, z + f.z * fc.radii[2] * sz)
		put(batch, f.part, abdomen * CFrame.new((center + (at - center) * condition) * g) * f.turn)
	end
	local fl = fc.flaps
	local angle = math.rad(fl.foldedDeg) * (1 - open)
	for _, f in fan.flaps do
		fanSize(fan, f.part, self._sizes[f.part] * g * condition)
		local hinge = Vector3.new(f.side * fl.hingeX, center.Y + fl.hingeY, center.Z + fc.zShift * open)
		local cf = (CFrame.Angles(0, 0, f.side * angle) + hinge) * CFrame.new(f.side * fl.radii[1], 0, 0)
		put(batch, f.part, abdomen * CFrame.new((center + (cf.Position - center) * condition) * g) * cf.Rotation)
	end
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
	-- (ROBLOX-127) the rival's contest display (look.contest, a RivalDisplay pose) goes the same way, with a sideways step of the drawn body (`lateral`, studs at scale 1:
	-- the zigzag), legs I between three places (`reach`, `hook`), the chelicerae spread (`spread`) and a crouch (`lower`).
	local tc = self._appearance.threat or self._appearance.contest
	local threatPose = if tc ~= nil then self.threat else nil
	local threatening = threatPose ~= nil and threatPose.presence > 0
	if threatening and (threatPose.lateral or 0) ~= 0 then
		body = body * CFrame.new(threatPose.lateral * self._growth, 0, 0)
	end
	if threatening and threatPose.yaw ~= 0 then
		body = body * CFrame.Angles(0, threatPose.yaw, 0)
	end
	local up = body.UpVector
	local look, cfg, A = self._appearance, self._cfg, self._layout
	local k, g = self._k, self._growth
 self._shownCondition += math.clamp(self._condition-self._shownCondition,-0.12*dt,0.12*dt)
 local conditionValue=self._shownCondition
 local condition=Vector3.new(0.84+0.30*conditionValue,0.84+0.30*conditionValue,0.93+0.12*conditionValue)
	-- Suspension (ROBLOX-59; hung properly in ROBLOX-86). The drawn body turns about its middle until its long axis, from the face to the spinneret,
	-- runs along the line (the shortest turn: no angle limit), so the tail lands on the line and the silk leaves the spinneret tip; the root, the camera,
	-- the collider and the tether never move. Then a small lean, a damped pendulum sway (about the spinneret, started by the drop) and a slow damped turn
	-- about the line, none of it with Reduced Motion. Going up the line (the collider travelling toward the anchor) the body turns head-up (`_climb`).
	local hang = look.hang
	local hanging = not grounded and self.hangDirection ~= nil and hang ~= nil
	if hanging then
		local d = (self.hangDirection :: Vector3)
		if d.Magnitude > 1e-6 then self._lineDir = d.Unit end
	end
	local lineUp = self._lineDir
	local blend = if hang ~= nil then hang.rate * dt else 5 * dt
	local before = self._hang
	self._hang += math.clamp((if hanging then 1 else 0) - self._hang, -blend, blend)
	if grounded then self._hang = 0 end
	if hang ~= nil then
		if hanging and dt > 1e-6 and self._lastPos ~= nil then
			local speed = (collider.Position - (self._lastPos :: Vector3)):Dot(lineUp) / dt
			self._lineSpeed += (speed - self._lineSpeed) * math.min(1, dt / 0.25)
			if self._lineSpeed > hang.climb.speed then self._climbing = true elseif self._lineSpeed < hang.climb.speed * 0.4 then self._climbing = false end
		elseif not hanging then
			self._lineSpeed, self._climbing = 0, false
		end
		self._lastPos = collider.Position
		local step = if self.reducedMotion then 1 else math.max(dt, 1e-6) / hang.climb.seconds
		self._climb += math.clamp((if self._climbing and hanging then 1 else 0) - self._climb, -step, step)
		if not hanging and self._hang <= 0 then self._climb = 0 end
	end
	if self._hang > 0 and hang ~= nil then
		local h = self._hang
		if before <= 0 then -- the drop: the swing and the turn start now (the turn goes one way, then the other, drop by drop)
			self._hangT, self._spin = 0, 0
			self._spinVel = math.rad(hang.spin.degPerS) * (if self._hangCount % 2 == 0 then 1 else -1)
			self._hangCount += 1
		end
		self._hangT += dt
		local calm = not self.reducedMotion
		if calm then
			self._spinVel *= math.exp(-dt / hang.spin.decay)
			self._spin += self._spinVel * dt
		end
		local c = self._climb
		-- the long axis: the face's centre to the spinneret tip, turned (about the middle) onto the line
		local nose = Vector3.new(0, A.faceCenter.Y, A.faceCenter.Z) * g
		local tail = (A.abdomenCenter + (A.spinneret - A.abdomenCenter) * condition) * g
		local middle = body:PointToWorldSpace((nose + tail) * 0.5)
		local axis = body:VectorToWorldSpace((tail - nose).Unit)
		local turn = axis:Cross(lineUp)
		local offLine = math.acos(math.clamp(axis:Dot(lineUp), -1, 1))
		local align = CFrame.identity
		if turn.Magnitude > 1e-5 then align = CFrame.fromAxisAngle(turn.Unit, offLine * h)
		elseif axis:Dot(lineUp) < 0 then align = CFrame.fromAxisAngle(body.UpVector, math.pi * h) end
		body = CFrame.new(middle) * align * CFrame.new(-middle) * body
		if c > 0 then -- head up: end over end about the middle, the body standing off the line toward its back so the silk runs along the belly
			body = CFrame.new(middle) * CFrame.fromAxisAngle(body.RightVector, math.pi * c * h) * CFrame.new(-middle) * body
			body = CFrame.new(body.UpVector * (A.headRadii.Y * hang.climb.shift * g * c * h)) * body
		end
		local pivot = body:PointToWorldSpace(tail)
		local side = body.RightVector
		local forward = lineUp:Cross(side)
		if forward.Magnitude > 1e-6 then forward = forward.Unit end
		local rest = (1 - c) * h
		local swing = if calm then math.exp(-self._hangT / hang.sway.decay) * math.sin(math.pi * 2 * self._hangT / hang.sway.period) else 0
		local swingAcross = if calm then math.exp(-self._hangT / hang.sway.decay) * math.cos(math.pi * 2 * self._hangT / hang.sway.period) * (1 - math.exp(-self._hangT / 0.3)) else 0
		local sway = math.rad(hang.sway.deg) * swing
		local sideways = math.rad(hang.sway.deg) * hang.sway.across * swingAcross
		local lean = CFrame.fromAxisAngle(side, (math.rad(hang.leanDeg) + sway) * rest) * CFrame.fromAxisAngle(forward, sideways * rest)
		body = CFrame.new(pivot) * CFrame.fromAxisAngle(lineUp, self._spin * rest) * lean * CFrame.new(-pivot) * body
		up = body.UpVector
	end
	-- The drawing is two batches (ROBLOX-93): the body's parts every frame, then the hairs that moved (see MOVE_STUDS). Both are tables the rig keeps.
	local bodyBatch, hairBatch = self._bodyBatch, self._hairBatch
	clearBatch(bodyBatch)
	clearBatch(hairBatch)
	put(bodyBatch, self.root, collider)
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
	-- Living motion (ROBLOX-87), full detail only: the watched point as an angle from the drawn body's heading, then the pose of attention, grooming, alarm and
	-- a tarantula's stretch. It only ever turns and bends drawn parts: the planted feet, the root, the motor and the camera do not know it.
	local lp: Living.Pose? = nil
	local living = self._living
	if living ~= nil then
		local focusYaw: number?, focusPitch: number? = nil, nil
		local watched = self.focusPoint
		if watched ~= nil and grounded and not posed and self._hang <= 0 then
			local d = body:PointToObjectSpace(watched)
			local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
			if flat > 0.25 * k then
				focusYaw, focusPitch = math.atan2(-d.X, -d.Z), math.atan2(d.Y - A.faceCenter.Y * g, flat)
			end
		end
		lp = Living.step(living, dt, standing == true, self.reducedMotion, focusYaw, focusPitch, grounded and not posed and self._hang <= 0)
	end
	local freeze = if lp ~= nil then lp.freeze else 0
	-- The abdomen breathes: all of it at a stand, `movingShare` of it otherwise (and none with Reduced Motion or below the full tier).
	local breathing = 0
	if cfg.idle and not self.reducedMotion then breathing = if standing then 1 else (look.idle.breathe.movingShare or 0) end
	self._breath += math.clamp(breathing - self._breath, -dt / 0.6, dt / 0.6)
	local gain = if lp ~= nil then lp.breath else 1 -- (the mating scene's settle: a deeper breath, ROBLOX-89)
	local breathScale = if cfg.idle then Idle.abdomenScale(self._t, self._breath * (1 - 0.8 * freeze) * gain, look.idle) else 1
	self._drum = math.clamp(self._drum + (if standing then 3 else -3) * dt, 0, 1)
	local drum = self._drum * (1 - freeze)
	local palp1, palp2 = Idle.palp(self._t, drum, look.palp, 1), Idle.palp(self._t, drum, look.palp, 2) -- (the palps' angles)
	local bodyBase, headBase, abdomenBase = body, body, body
	if cfg.idle then
		local idle = look.idle
		self._calm = math.clamp(self._calm + (if standing then dt / idle.riseSeconds else -dt / idle.fallSeconds), 0, 1)
		if self._calm > 0 then
			local c = self._calm * self._calm * (3 - 2 * self._calm) * (1 - freeze)
			local pose = Idle.pose(self._t, c, idle, self._pose)
			bodyBase = body * CFrame.new(0, pose.bodyLift*g*gain, 0)
			headBase = bodyBase * CFrame.new(A.neck*g) * CFrame.Angles(pose.headPitch, pose.headYaw, pose.headRoll) * CFrame.new(-A.neck*g)
			abdomenBase = bodyBase * CFrame.new(0, pose.abdomenLift*g*gain, 0) * CFrame.new(A.pedicelCenter*g)
				* CFrame.Angles(-pose.abdomenPitch*gain, 0, 0) * CFrame.new(-A.pedicelCenter*g)
		end
	end
	-- Display-only snaps also run on low-detail devices. Camera/root, foot anchors and motor stay unchanged.
	if grounded and not self.reducedMotion and not posed and not loading then
		local yaw, lift = Idle.snap(self._t, moving)
		yaw, lift = yaw * (1 - freeze), lift * (1 - freeze)
		local accent = body * CFrame.new(0, lift * g, 0) * CFrame.Angles(0, yaw, 0) * body:Inverse()
		bodyBase, headBase, abdomenBase = accent * bodyBase, accent * headBase, accent * abdomenBase
	end
	-- Attention: the whole drawn body turns toward what is watched (the hips go with it; the planted feet stay where they are).
	if lp ~= nil and lp.yaw ~= 0 then
		local turn = body * CFrame.Angles(0, lp.yaw, 0) * body:Inverse()
		bodyBase, headBase, abdomenBase = turn * bodyBase, turn * headBase, turn * abdomenBase
	end
	-- The mating scene's settle (ROBLOX-89): the whole drawn body sinks a little toward the surface (the planted feet stay where they are).
	if lp ~= nil and lp.settle > 0 and look.idle.settle ~= nil then
		local sink = body * CFrame.new(0, -look.idle.settle.lower * g * lp.settle, 0) * body:Inverse()
		bodyBase, headBase, abdomenBase = sink * bodyBase, sink * headBase, sink * abdomenBase
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
		palp1, palp2 = palp1 + display.palp, palp2 + display.palp
	end
	-- The threat display: the prosoma (the head with the palps, and every leg's hip) pitches up about the waist; the palps lift at their bases.
	local prosoma = bodyBase
	if threatening and threatPose.rear ~= 0 then
		local waist = A.pedicelCenter * g
		prosoma = bodyBase * CFrame.new(waist) * CFrame.Angles(threatPose.rear, 0, 0) * CFrame.new(-waist)
		headBase = prosoma * (bodyBase:Inverse() * headBase) -- (keeps any head tilt the idle motion still has)
	end
	if threatening then
		palp1, palp2 = palp1 + threatPose.palps, palp2 + threatPose.palps
		local sink = (threatPose.lower or 0) * (if tc.lower then tc.lower else 0)
		if sink ~= 0 then -- backing off: the whole drawn body low to the surface (the planted feet stay where they are)
			local down = body * CFrame.new(0, -sink * g, 0) * body:Inverse()
			bodyBase, headBase, abdomenBase, prosoma = down * bodyBase, down * headBase, down * abdomenBase, down * prosoma
		end
	end
	local spreadAngle = if threatening and tc.spreadDeg then math.rad(tc.spreadDeg) * (threatPose.spread or 0) else 0
 if self._hang > 0 and hang ~= nil then -- hanging: the palps are drawn in toward the jaws
  local tuck = -math.rad(hang.palpTuckDeg) * self._hang
  palp1, palp2 = palp1 + tuck, palp2 + tuck
 end
 self._spinneret=abdomenBase:PointToWorldSpace((A.abdomenCenter+(A.spinneret-A.abdomenCenter)*condition)*g)
	-- Grooming: a palp is drawn in toward the jaws (turned toward the midline and tipped down) about its base.
	local palpYaw1, palpYaw2 = 0, 0
	if lp ~= nil then
		palp1, palp2 = palp1 - lp.palpPitch[1], palp2 - lp.palpPitch[2]
		palpYaw1, palpYaw2 = lp.palpYaw[1], lp.palpYaw[2]
	end
	local glanceAt = Vector3.zero -- the principal eyes' shift in the head's frame, studs, toward what is watched
	if lp ~= nil and look.idle.attention ~= nil then
		local reach = look.idle.attention.glance
		glanceAt = Vector3.new(lp.glanceX * reach, lp.glanceY * reach * 0.6, 0)
	end
	local pivot1 = CFrame.Angles(palp1, palpYaw1, 0) + self._palpBase[1]
	local pivot2 = CFrame.Angles(palp2, palpYaw2, 0) + self._palpBase[2]
	-- What has changed since the hairs were last placed: after a change of scale (a new epoch) everything, otherwise the abdomen's condition (its parts' sizes and places)
	-- and, below, the frame each kind of hair follows.
	local seen, epoch = self._seen, self._epoch
	local fresh = seen.epoch ~= epoch or self._exact
	local abdomenAt = A.abdomenCenter
	local sizesDue = fresh or (condition - seen.sizeKey).Magnitude > SCALE_STEP
	local glanced = glanceAt ~= Vector3.zero
	local sweeping = threatening and threatPose.sweep ~= 0
	for _, f in self._bodyFixed do
		local group = f.group
		local base = if group == G_HEAD then headBase elseif group == G_ABDOMEN then abdomenBase else bodyBase
		local palp = f.palp
		if palp then
			put(bodyBatch, f.part, base * scaled((if palp == 1 then pivot1 else pivot2) * f.offset, g))
		else
			local offset, edited = f.offset, false
			if f.glance == true and glanced then offset, edited = CFrame.new(glanceAt) * offset, true end
			if spreadAngle ~= 0 and f.jaw ~= nil and f.pivot ~= nil then
				-- The rival's display: each chelicera (and its fang) swings out about its base, the tip outward and a little apart (ROBLOX-127).
				local side, at = f.jaw, f.pivot
				offset, edited = CFrame.new(at) * CFrame.Angles(0, -side * spreadAngle * 0.35, side * spreadAngle) * CFrame.new(-at) * offset, true
			end
			if sweeping and f.sweep ~= nil then
				-- A spinneret segment swings side to side about a point just inside the abdomen's rear tip (the second segment farther).
				local at = A.spinneret - Vector3.new(0, 0, tc.sweepBack)
				offset, edited = CFrame.new(at) * CFrame.Angles(0, threatPose.sweep * (if f.sweep > 1 then tc.tipSweep else 1), 0) * CFrame.new(-at) * offset, true
			end
			if group == G_ABDOMEN then
				-- (the whole abdomen, its hairs and its shells, breathes; only the big masses are resized every frame, the rest when the condition has changed)
				local pos, rot = f.pos, f.rot
				if edited then pos, rot = offset.Position, offset.Rotation end
				local p = abdomenAt + (pos - abdomenAt) * condition * breathScale
				put(bodyBatch, f.part, base * (rot + (if g == 1 then p else p * g)))
				if f.big == true then
					resize(f, f.size0 * g * condition * breathScale)
				elseif sizesDue then
					resize(f, f.size0 * g * condition)
				end
			else
				put(bodyBatch, f.part, base * (if edited then scaled(offset, g) else f.scaled))
			end
		end
	end

	-- The hairs, in the second batch: a kind is placed again only if the frame it follows has moved since it was last placed (fresh: after a change of scale, all).
	if fresh or moved(seen.head, headBase) then
		seen.head = headBase
		for _, f in self._headHairs do put(hairBatch, f.part, headBase * f.scaled) end
	end
	if fresh or moved(seen.body, bodyBase) then
		seen.body = bodyBase
		for _, f in self._bodyHairs do put(hairBatch, f.part, bodyBase * f.scaled) end
	end
	for index = 1, 2 do
		local pivot = if index == 1 then pivot1 else pivot2
		if fresh or moved(seen.palpHead[index], headBase) or moved(seen.pivot[index], pivot) then
			seen.palpHead[index], seen.pivot[index] = headBase, pivot
			for _, f in self._palpHairs[index] do put(hairBatch, f.part, headBase * scaled(pivot * f.offset, g)) end
		end
	end
	if sizesDue or math.abs(breathScale - seen.breath) > SCALE_STEP or moved(seen.abdomen, abdomenBase) then
		seen.abdomen, seen.breath = abdomenBase, breathScale
		for _, f in self._abdomenHairs do
			local p = abdomenAt + (f.pos - abdomenAt) * condition * breathScale
			put(hairBatch, f.part, abdomenBase * (f.rot + (if g == 1 then p else p * g)))
			if sizesDue then resize(f, f.size0 * g * condition) end
		end
	end
	if sizesDue then seen.sizeKey = condition end
	seen.epoch = epoch

	if fan then
		drawFan(self, fan, abdomenBase, if dancing then display.fanOpen else 0, condition, bodyBatch)
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
				local err = (body:PointToWorldSpace(leg.rest) - leg.planted :: Vector3).Magnitude
				if err > worst then
					worst = err
					self._group = legGroup(self, i)
				end
			end
		end
	end
	local L = look.limbs
	local bandFraction = look.bandFraction
	local exact = self._exact
	local started = false
	for i, leg in self._legs do
		local rest = body:PointToWorldSpace(leg.rest)
		if not grounded then
			leg.planted = nil
			leg.swing = -1
   local free=Vector3.new(leg.side*.47*k,-.12*k,L.tipZ[leg.pair]*.72*g)
   leg.foot=body:PointToWorldSpace(free)
   leg.hangKnee, leg.hangAnkle = nil, nil
   if self._hang>0 then
    local knee,ankle,foot=self:_hangLeg(leg,body)
    leg.hangKnee,leg.hangAnkle=knee,ankle
    leg.foot=leg.foot:Lerp(foot,self._hang)
   end
		else
			leg.hangKnee, leg.hangAnkle = nil, nil
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
	for index, leg in self._legs do
		local hip = prosoma:PointToWorldSpace(leg.hip)
		local foot = leg.foot
  local rear = leg.pair >= 3
  if not grounded and rear and push > 0 then
   foot += body:VectorToWorldSpace(Vector3.new(leg.side*.05,-.25,.18)*k*push)
  end
		local knee = hip:Lerp(foot, 0.48) + up * (if rear then kneeUp*(1-.7*push)+.035*k*load else kneeUp)
		-- A leg of the living motion (ROBLOX-87): pulled forward to be groomed, raised in an alarm, or reaching out in a tarantula's stretch. The planted foot below is untouched.
		local alive = if lp ~= nil then lp.legs[index] else nil
		if alive ~= nil and alive.w > 0 then
			local spot = Vector3.new(leg.side * alive.x, alive.y, alive.z) * g
			local reached = if alive.rel then foot + bodyBase:VectorToWorldSpace(spot) else bodyBase:PointToWorldSpace(spot)
			foot = foot:Lerp(reached, alive.w)
			local bent = hip:Lerp(reached, 0.5) + bodyBase.RightVector * (leg.side * alive.kneeOut * g) + up * (alive.kneeUp * g)
			knee = knee:Lerp(bent, alive.w)
		end
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
		if threatening and tc ~= nil and leg.pair == tc.pair and threatPose.legs > 0 then
			local upAt = Vector3.new(leg.side * tc.up.x, tc.up.y + threatPose.tremor * tc.tremor, tc.up.z)
			local reach, hook = threatPose.reach or 0, threatPose.hook or 0
			if reach > 0 and tc.wide then upAt = upAt:Lerp(Vector3.new(leg.side * tc.wide.x, tc.wide.y + threatPose.tremor * tc.tremor, tc.wide.z), reach) end -- (ROBLOX-127: high and spread)
			if hook > 0 and tc.hook then upAt = upAt:Lerp(Vector3.new(leg.side * tc.hook.x, tc.hook.y, tc.hook.z), hook) end -- (forward and down, grappling)
			local raised = prosoma:PointToWorldSpace(upAt * g)
			foot = foot:Lerp(raised, threatPose.legs)
			local raisedKnee = hip:Lerp(raised, 0.5) + prosoma.RightVector * (leg.side * tc.kneeOut * g) + up * (tc.kneeUp * g)
			knee = knee:Lerp(raisedKnee, threatPose.legs)
		end
		local hangKnee, hangAnkle = leg.hangKnee, leg.hangAnkle
		if hangKnee ~= nil and hangAnkle ~= nil then knee = knee:Lerp(hangKnee, self._hang) end
		local ankle = knee:Lerp(foot, ANKLE_SHARE) + up * (L.ankleLift*g)
		if hangKnee ~= nil and hangAnkle ~= nil then ankle = ankle:Lerp(hangAnkle, self._hang) end
		local form = look.legForm
		local femurMid = if form and leg.femurTip then hip:Lerp(knee, form.femur.split) else knee
		local tibiaMid = if form and form.tibia and leg.tibiaTip then knee:Lerp(ankle, form.tibia.split) else ankle
		local tarsusMid = if form and leg.joint then ankle:Lerp(foot, form.tarsus.split) + up * (if leg.tarsusTip then form.tarsus.bend * g else 0) else foot
		drawSegment(leg.segs[1], bandFraction, g, hip, femurMid, knee, bodyBatch, hairBatch, exact)
		drawSegment(leg.segs[2], bandFraction, g, knee, tibiaMid, ankle, bodyBatch, hairBatch, exact)
		drawSegment(leg.segs[3], bandFraction, g, ankle, tarsusMid, foot, bodyBatch, hairBatch, exact)
		if form then
			-- The knee is a patella: a short stout ellipsoid lying along the bend of the leg there.
			local bend = (knee - hip).Unit + (ankle - knee).Unit
			local along = if bend.Magnitude > 1e-3 then bend.Unit else (knee - hip).Unit
			put(bodyBatch, leg.knee, rodCFrame(knee - along, knee + along))
		else
			put(bodyBatch, leg.knee, CFrame.new(knee))
		end
		put(bodyBatch, leg.ankle, CFrame.new(ankle))
		if leg.joint then put(bodyBatch, leg.joint, CFrame.new(tarsusMid)) end
		local pad = leg.pad
		if pad and form then
			-- The tarsal pad lies on the surface under the foot, flattened, its long side along the way the foot points; the first spider's claws leave
			-- its front. All of it is display: the planted foot is where it was.
			local into = foot - (if leg.joint then tarsusMid else ankle)
			local flat = into - up * into:Dot(up)
			local heading = if flat.Magnitude > 1e-4 then flat.Unit else body.LookVector
			local center = foot + up * (pad.Size.Y * 0.35)
			put(bodyBatch, pad, CFrame.lookAt(center, center + heading, up) * QUARTER)
			local right = heading:Cross(up)
			for n, claw in leg.toes do
				-- two claws: from the pad's front, forward and down, splayed apart
				local from = center + heading * (pad.Size.X * 0.42)
				local aim = (heading * 0.85 - up * 0.45 + right * ((if n % 2 == 1 then -1 else 1) * form.claws.splay)).Unit
				put(bodyBatch, claw, rodCFrame(from, from + aim * claw.Size.X))
			end
		elseif pad then
			put(bodyBatch, pad, CFrame.new(foot))
		end
	end
	self.placed = bodyBatch.n + hairBatch.n -- (ROBLOX-113: the parts this drawing placed, for the self-test's profile)
	Workspace:BulkMoveTo(bodyBatch.parts, bodyBatch.frames, Enum.BulkMoveMode.FireCFrameChanged)
	if hairBatch.n > 0 then
		Workspace:BulkMoveTo(hairBatch.parts, hairBatch.frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Draws the rig for a frame (ROBLOX-93): an update when the rig has not been drawn yet or is within FAR_STUDS of the camera (`distance`, studs), otherwise once every
-- FAR_SECONDS with all the time since the last drawing. The sim goes on stepping every tick; a rival or a mate too far off to show its legs need not be redrawn sixty
-- times a second. (A caller that must have the full rate, a lunge or a windup, gives a distance of 0.) Returns whether it drew.
-- (Six frames of 1/60 add up to a hair under 0.1, so the interval is met a millionth of a second early: ten drawings a second at 60 Hz, not eight and a half.)
function SpiderRig.drawStep(self: Rig, collider: CFrame, dt: number, grounded: boolean, moving: boolean, distance: number): boolean
	local owed = self._owed + dt
	if self._drawn and distance > FAR_STUDS and owed < FAR_SECONDS - 1e-6 then
		self._owed = owed
		return false
	end
	self._owed, self._drawn = 0, true
	self:update(collider, owed, grounded, moving)
	return true
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

-- The drawn body's length in studs now, head to abdomen: 0.97 for the first spider at its first stage and 1.455 as an adult (0.455 and 0.68 for the peacock spider,
-- 0.485 and 0.73 for the ant mimic), times the growth stage. Inspect mode (ROBLOX-90) measures its distances in these.
SpiderRig.BODY_STUDS = 0.97
function SpiderRig.bodyLength(self: Rig): number
	return SpiderRig.BODY_STUDS * self._k
end

-- Where the dragline leaves the body.
function SpiderRig.spinneretPoint(self: Rig, body: CFrame): Vector3
	return self._spinneret or body:PointToWorldSpace(self._layout.spinneret*self._growth - Vector3.new(0, self._drop, 0))
end

function SpiderRig.destroy(self: Rig)
	self.model:Destroy()
end

return SpiderRig
