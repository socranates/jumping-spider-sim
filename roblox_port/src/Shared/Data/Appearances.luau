--!strict
-- Artist-directed appearance, independent of species tuning, growth and physics.
-- Nathan's daughter's pick: docs/art/first-spider-reference.jpg (2026-10-14). ROBLOX-13 made it cuter without changing it:
-- proportions, eyes, fuzz and a little idle motion. Every number the look needs is in this table.
-- Body frame: +Y up, -Z forward. Lengths are studs (1 stud = 1 Godot WU = 1 cm). Markings are fractions of the abdomen's X/Z radii.
local first = {
	id = "first_spider",
	name = "First spider",

	-- ---------------------------------------------------------------- the daughter's design: colours and pattern
	-- tests/look.luau pins every value in this block. Change them only if she does.
	body = { 0, 0, 0 },
	legs = { 0, 0, 0 },
	white = { 0.94, 0.94, 0.92 },
	eyes = { 0.008, 0.008, 0.008 },
	fangs = { 0.025, 0.025, 0.025 },
	abdomenRadii = { 0.25, 0.205, 0.285 },
	frontLegScale = 1.28,
	bandFraction = 0.23, -- the pale band on each leg and palp segment
	speckleCount = 24,
	-- Large centre, two small elongated anterior spots, two posterior ovals.
	spots = {
		{ x = 0, z = 0.10, rx = 0.080, rz = 0.074, angle = 0 },
		{ x = -0.34, z = -0.46, rx = 0.018, rz = 0.034, angle = -0.35 },
		{ x = 0.34, z = -0.46, rx = 0.018, rz = 0.034, angle = 0.35 },
		{ x = -0.35, z = 0.67, rx = 0.025, rz = 0.035, angle = 0.4 },
		{ x = 0.35, z = 0.67, rx = 0.025, rz = 0.035, angle = -0.4 },
	},
	-- The pale band across the front of the abdomen: `count` dabs, `step` apart, at z.
	band = { count = 9, step = 0.16, z = -0.66, rx = 0.031, rz = 0.018 },
	-- Fine speckles on a spiral: radius `from` + (i % 5) * `step`.
	speckle = { from = 0.40, step = 0.10, rx = 0.0035, rz = 0.005 },

	-- ---------------------------------------------------------------- cuter proportions (ROBLOX-13)
	-- A slightly bigger, rounder head than the abdomen (head volume about 1.07 x the abdomen's; it was 0.77).
	headCenter = { 0, 0.03, -0.21 },
	headRadii = { 0.27, 0.215, 0.27 },
	abdomenCenter = { 0, 0.04, 0.20 },
	pedicel = { center = { 0, -0.035, -0.06 }, radii = { 0.05, 0.05, 0.06 } },
	face = { center = { 0, 0.05, -0.37 }, radii = { 0.225, 0.18, 0.12 } }, -- the rounded muzzle under the eyes
	neck = { 0, 0.0, -0.06 }, -- the head tilts about this point
	-- Pale side patches (the daughter's "cheeks"): placed on the head's side at height y, depth z (body frame).
	cheek = { y = 0.055, z = -0.235, radii = { 0.02, 0.07, 0.115 }, inset = 0.006 },
	chelicerae = { x = 0.055, y = -0.085, z = -0.447, radii = { 0.05, 0.072, 0.045 }, pitch = -0.35, splay = 0.12, reflectance = 0.1 },
	-- Eyes. Never a human face: no brows, no mouth. Big glossy front eyes read as an animal's.
	eye = {
		-- Principal (front) eyes: large, glossy, set low in a big forehead. x, y: where on the head they sit; `out`: how far
		-- they stand out of the head, as a share of their depth. Two catchlights on each, the same on both eyes: a larger one
		-- high toward +X (the light) and a smaller one low toward -X (its reflection).
		ame = {
			x = 0.115, y = 0.095, radii = { 0.100, 0.100, 0.082 }, out = 0.30, reflectance = 0.5,
			socket = { scale = 1.13, color = { 0.11, 0.11, 0.11 } }, -- a dark-grey rim so the black eye reads against the black head
			glints = { { dx = 0.030, dy = 0.036, r = 0.022 }, { dx = -0.028, dy = -0.034, r = 0.010 } },
		},
		ale = { x = 0.235, y = 0.085, r = 0.050, out = 0.15, reflectance = 0.3 }, -- anterior lateral, at the sides of the face
		ple = { x = 0.150, z = -0.150, r = 0.052, out = 0.10, reflectance = 0.3 }, -- posterior lateral, on the dome
		pme = { x = 0.115, z = -0.270, r = 0.019, out = 0.10, reflectance = 0.3 }, -- posterior median, a tiny dot
		glintColor = { 1, 1, 1 },
	},
	-- Pedipalps: stout, pale-banded, pale-tipped, with a fluffy club.
	palp = {
		x = 0.115, y = -0.045, -- where it leaves the face
		drop = 0.105, reach = 0.10, spread = 0.035, -- tip: this far down, forward and out from the base
		stalk = 0.05, club = { 0.042, 0.040, 0.052 }, tipRadii = { 0.030, 0.026, 0.030 },
		fluff = { hairs = 7, length = 0.055, width = 0.012, flat = 0.7, transparency = 0.15 },
		drumHz = 3.2, drumDeg = 13,
	},
	-- Legs (display only): plump, a little shorter and more crouched than before; round feet.
	limbs = {
		hipX = 0.17, hipY = 0.02,
		hipZ = { -0.36, -0.24, -0.12, 0.0 },
		tipZ = { -0.82, -0.52, 0.12, 0.62 },
		-- femur and tibia diameters per pair, stout front legs to slim back legs; `thickness` scales them all.
		diameters = { { 0.078, 0.064 }, { 0.065, 0.053 }, { 0.057, 0.045 }, { 0.059, 0.047 } },
		thickness = 1.12,
		stance = { x = 0.78, y = -0.30, reach = 0.93 }, -- rest foot spot: reach scales x and the pairs' z
		kneeLift = 0.28, kneeLiftAir = 0.22, ankleLift = 0.045,
		pad = 1.6, -- foot ball diameter as a multiple of the tarsus' (full detail)
	},

	-- ---------------------------------------------------------------- fuzz (ROBLOX-07, retuned for the real camera in ROBLOX-13)
	-- The camera sits 5 studs away (CameraMath.CAMERA_DISTANCE), 1 stud is about 170 px on a 1080p screen, so a hair is a few
	-- pixels at most. The first coat answered that with big stiff hairs, and they stood off the body like a hedgehog's and
	-- covered the white spots; the second coat (this one) is short, thin and combed flat, and leaves the softness to the shells.
	fuzz = {
		enabled = true,
		-- The coat is short and sleek, like a real jumping spider's, and it takes its colour from the pattern it grows on:
		-- black hairs on the black areas, white hairs only inside the white spots and the band, nothing grey or frosted on the
		-- body (the daughter's white stays crisp, and a hair is never a pale shard). The softness comes from the fur shells.
		-- `abdomen` and `head` are Fibonacci sample points before the belly is skipped (about 60 % of them become hairs).
		-- `length` and `lift` are ranges (studs; degrees off the surface: 0 lies flat, 90 stands up); `yaw` scatters the
		-- combing (degrees either side of straight back); `flat` is the thickness as a share of the width; `black` is the share
		-- of the blackest tone (the rest is `dark`); `transparency` keeps the coat a little see-through.
		-- Locks: the pelt, lying nearly flat and combed toward the rear.
		locks = { abdomen = 340, head = 130, length = { 0.024, 0.040 }, width = 0.018, flat = 0.22, lift = { 3, 13 }, yaw = 18, black = 0.45, transparency = 0.10 },
		-- Guard hairs: a few short, fine hairs that stand up from the pelt.
		guard = { abdomen = 50, head = 24, length = { 0.030, 0.046 }, width = 0.0085, flat = 1.0, lift = { 50, 75 }, yaw = 35, black = 0.5, transparency = 0.20 },
		-- The fringe: short hairs along the sides (`side`: how far round to the side, as a share of the radius, a hair has to
		-- be), lifted a little, so the outline is ragged by a pixel or two and not by a spike.
		fringe = { abdomen = 170, head = 60, side = 0.78, length = { 0.026, 0.040 }, width = 0.011, flat = 0.5, lift = { 14, 32 }, yaw = 22, black = 0.5, transparency = 0.20 },
		-- White hairs inside the white spots and the band: `density` per square stud of marking, lying on it, kept only when the
		-- whole hair stays `margin` studs inside the edge, so the white keeps its edge.
		pale = { density = 600, length = { 0.021, 0.028 }, width = 0.013, flat = 0.3, lift = { 3, 10 }, yaw = 14, margin = 0.004, transparency = 0.05 },
		clear = 0.006, -- black hairs stay this far (studs) from any white marking
		black = { 0.03, 0.03, 0.03 },
		dark = { 0.13, 0.13, 0.13 },
		grey = { 0.50, 0.50, 0.48 }, -- grey and frost: the face (tufts, ruff) and the palps' fluff only
		frost = { 0.76, 0.76, 0.73 },
		-- Fur shells: see-through layers outside the body, strongest nearest it, so the outline goes soft. Four at full detail,
		-- one at low. A shell tints what is under it as well as what is around it, so they are dark and faint: the white of the
		-- pattern must stay white.
		shellColor = { 0.08, 0.08, 0.08 },
		shells = { { scale = 1.05, transparency = 0.86 }, { scale = 1.10, transparency = 0.92 }, { scale = 1.16, transparency = 0.955 }, { scale = 1.23, transparency = 0.975 } },
		headShell = { zScale = 0.80, shift = 0.05 }, -- the head's shells sit back from the eye row so the eyes stay clear
		-- Little tufts that bold jumping spiders have above the eyes, at the upper sides of the head: a fan of dark and
		-- silvery hairs that sweeps up and out. Not eyebrows: they sit behind the eyes at the sides, not over them.
		tuftHairs = 10, -- per side
		tuftLength = 0.078,
		tuft = { at = { 0.52, 0.80, -0.28 }, lean = { 0.60, 1.0, -0.22 }, fan = 0.46, spread = 0.02, width = 0.0165, flat = 0.8, transparency = 0.1 },
		-- A soft ruff of pale hair low on each cheek, beside the jaws (not a moustache: it sits at the sides).
		ruff = { hairs = 5, length = 0.052, width = 0.0135, flat = 0.7, at = { 0.52, -0.36, -0.74 }, lean = { 0.65, -0.55, -0.45 }, whiteShare = 0.6, transparency = 0.15 },
		legHairs = { 7, 6, 3 }, -- femur, tibia, tarsus, per leg (front legs carry 1.6 x as many on femur and tibia)
		legLength = 0.052,
		legWidth = 0.0125,
		legTransparency = 0.2,
		legBlack = 0.4, -- the share of the blackest tone on the legs (the rest is dark; white over the pale bands)
	},

	-- ---------------------------------------------------------------- idle motion (drawn rig only, ROBLOX-13)
	-- Eased in after the spider has stood still for a moment; off while walking, in the air, in low detail and with reducedMotion
	-- (the palps' drumming follows the same rule).
	idle = {
		riseSeconds = 1.0, fallSeconds = 0.25,
		breathe = { period = 3.3, bodyLift = 0.006, lift = 0.016, pitchDeg = 2.4 },
		-- A small, slow, curious head tilt: sums of sines (periods in seconds), always inside these angles.
		tilt = { rollDeg = 7, yawDeg = 6, pitchDeg = 3.5, periods = { 9.1, 5.3, 11.3, 6.7, 8.3 } },
	},

	-- ---------------------------------------------------------------- detail modes
	-- Full is for PCs. Low is for phones and tablets (touch-only devices, or Workspace attribute Detail = "low"): fewer
	-- hairs (keep one in `every`; 0 drops the whole class, so the low tier has no standing guard hairs), a single fur shell,
	-- no foot balls, half the speckles, no outline and no idle motion at all (no breathing, head tilt or palp drumming).
	-- The pattern, eyes, catchlights and tufts stay.
	detail = {
		full = {
			every = { lock = 1, guard = 1, fringe = 1, pale = 1, tuft = 1, ruff = 1, palp = 1, leg = 1 },
			shells = 4, speckleEvery = 1, pads = true, sockets = true, idle = true, highlight = true,
		},
		low = {
			every = { lock = 3, guard = 0, fringe = 3, pale = 2, tuft = 2, ruff = 2, palp = 2, leg = 4 },
			shells = 1, speckleEvery = 2, pads = false, sockets = false, idle = false, highlight = false,
		},
	},
}

-- ================================================================ the peacock spider (ROBLOX-30)
-- Maratus volans, the male in courtship colours: a second profile beside the daughter's, chosen from the crack (Client/SpiderClient).
-- Morphology after Otto & Hill 2011 (Peckhamia 96.1): a male about 4 to 5 mm long (DOC); a dark carapace with three red-orange
-- stripes and a pale margin (DOC); white palp brushes (DOC); legs III longer and darker than the rest, with black brushes and white
-- tips (DOC); an abdominal fan whose lateral flaps lie folded round the abdomen until the display and then show as a near-round
-- disc: an iridescent blue-green field with a black central figure, red-orange arches and a white fringe (DOC). The exact
-- colours, proportions, stripe sizes and the angles below are ART. 1 stud = 1 cm, so the male is 0.45 studs long: the drawn
-- body is the default spider's face and build at SCALE, with its own colours, a fan and legs III. Collider, senses and physics are
-- the default spider's: this is a drawn appearance only (ROBLOX-30).
local SCALE = 0.47 -- body length 0.455 studs against the default spider's 0.97 (ART, from 4.5 mm and 1 stud = 1 cm)

-- A copy of a table with every number in it multiplied by k, except under the keys in `skip` (angles, shares, counts, colours).
local function scaled(node: any, k: number, skip: { [string]: boolean }): any
	if type(node) == "number" then return node * k end
	if type(node) ~= "table" then return node end
	local out: { [any]: any } = {}
	for key, value in node do
		out[key] = if skip[key] then value else scaled(value, k, skip)
	end
	return out
end
local FACE_SKIP = { out = true, reflectance = true, scale = true, color = true, glintColor = true, pitch = true, splay = true }
local LIMB_SKIP = { thickness = true, pad = true, reach = true }
local PALP_SKIP = { hairs = true, drumHz = true, drumDeg = true, flat = true, transparency = true }
local limbs = scaled(first.limbs, SCALE, LIMB_SKIP)
limbs.thickness = 1.0
limbs.stance = { x = limbs.stance.x, y = -0.10, reach = 0.62 } -- ART: low and compact, the legs not much longer than the body
limbs.pairReach = { 1.0, 1.0, 1.2, 1.0 } -- legs III are the longest (DOC)
local eye = scaled(first.eye, SCALE, FACE_SKIP)
eye.ame.socket = { scale = 1.12, color = { 0.50, 0.31, 0.14 } } -- tan and orange ocular setae frame the big eyes (DOC)
local palp = scaled(first.palp, SCALE, PALP_SKIP)
palp.club = { 0.021, 0.019, 0.026 } -- the white brushes clothe the palps (DOC; sizes ART)
palp.tipRadii = { 0.014, 0.012, 0.014 }
palp.fluff = { hairs = 0, length = 0, width = 0, flat = 1, transparency = 0 }

local volans = {
	id = "maratus_volans_male",
	name = "Peacock spider (male)",
	scale = SCALE, -- SpiderRig scales its own distances (foot search, stepping) by this
	bodyDrop = 0.21, -- the drawn body sits this far (studs) below the collider's centre, so it stands on the surface (the collider is 0.31 high)

	-- ---------------------------------------------------------------- colours (ART, after the photographs in Otto & Hill 2011)
	body = { 0.09, 0.05, 0.04 }, -- carapace: dark brown-black
	legs = { 0.34, 0.22, 0.12 }, -- legs I, II and IV: brown
	white = { 0.93, 0.90, 0.80 }, -- cream: the pale margin, palp brushes, leg bands, the fan's fringe
	eyes = { 0.01, 0.01, 0.01 },
	fangs = { 0.14, 0.08, 0.04 },
	joint = { 0.20, 0.12, 0.07 }, -- knees and ankles
	palpColors = { stalk = { 0.20, 0.12, 0.07 }, club = { 0.93, 0.90, 0.80 }, tip = { 0.97, 0.96, 0.90 } },
	abdomenColor = { 0.05, 0.34, 0.68 }, -- the abdomen is the blue field's colour under the fan's pattern
	stripes = { -- three red-orange stripes down the carapace behind the eyes (DOC); x, z, half widths in studs, body frame
		color = { 0.86, 0.26, 0.07 },
		{ x = 0, z = -0.030, rx = 0.011, rz = 0.050, angle = 0 },
		{ x = -0.050, z = -0.026, rx = 0.009, rz = 0.040, angle = 0.18 },
		{ x = 0.050, z = -0.026, rx = 0.009, rz = 0.040, angle = -0.18 },
	},

	-- ---------------------------------------------------------------- proportions: the default spider's face and build at SCALE
	headCenter = { 0, 0.014, -0.099 },
	headRadii = { 0.125, 0.100, 0.125 }, -- the carapace is boxy and high: a little taller than the scaled default
	abdomenCenter = { 0, 0.019, 0.094 },
	abdomenRadii = { 0.104, 0.088, 0.125 }, -- an oval, narrower than the default's
	pedicel = scaled(first.pedicel, SCALE, {}),
	face = scaled(first.face, SCALE, {}),
	neck = scaled(first.neck, SCALE, {}),
	-- The pale margin along the lower edge of the carapace (DOC): the rig draws these as the "cheek" patches.
	cheek = { y = -0.012, z = -0.075, radii = { 0.010, 0.020, 0.075 }, inset = 0.003 },
	chelicerae = scaled(first.chelicerae, SCALE, FACE_SKIP),
	eye = eye,
	palp = palp,
	limbs = limbs,
	frontLegScale = 1.0,
	bandFraction = 0.12, -- the pale bands on legs I, II and IV
	speckleCount = 0,
	spots = {},
	band = { count = 0, step = 0.1, z = 0, rx = 0.01, rz = 0.01 },
	speckle = { from = 0.4, step = 0.1, rx = 0.004, rz = 0.005 },
	-- Legs III (DOC): dark femur, a thick jet-black brush on the tibia, a snow-white tip, no pale bands. `up` and `swept` are
	-- where the foot goes when they are raised in a V and when a wave sweeps them down and forward (body frame, studs, x mirrored
	-- for the left leg); `kneeOut` pushes the knee outward. All ART.
	pairs = {
		[3] = {
			colors = { { 0.13, 0.08, 0.05 }, { 0.02, 0.02, 0.025 }, { 0.96, 0.95, 0.90 } },
			thick = { 1.0, 1.7, 1.9 },
			bands = false,
			up = { x = 0.21, y = 0.23, z = -0.015 },
			swept = { x = 0.10, y = 0.12, z = -0.12 },
			kneeOut = 0.05,
		},
	},

	-- ---------------------------------------------------------------- the fan (DOC: blue-green field, black figure, red-orange arches, white fringe; ART: sizes)
	-- Flat discs on the abdomen's back (dorsal) face, stacked from the fringe in. `radii` are the open fan's half width and half
	-- length (a near-round disc, a little wider than long), `folded` the share of that it shows folded; each layer is `inset` studs
	-- smaller than the one under it. `plane` is the fan's height over the abdomen's top (it floats a hair above the dome), `zShift` moves
	-- its centre toward the rear so the raised fan stands clear of the head. The figure is three black dabs (two lobes in front, a bar
	-- behind), given as fractions of the radii. The back (ventral) side repeats the rim and the field so the fan is a fan from behind.
	fan = {
		radii = { 0.165, 0.150 }, folded = { 0.42, 0.55 }, plane = 0.004, zShift = 0.018, layerStep = 0.0022, thickness = 0.004,
		foldedThickness = 0.06, foldedSink = 0.030, -- folded, the discs are thick and sunk into the dome (a lens on the abdomen) and flatten as the fan opens
		layers = {
			{ name = "FanFringe", color = { 0.95, 0.94, 0.88 }, inset = 0.0 },
			{ name = "FanArch", color = { 0.88, 0.25, 0.06 }, inset = 0.024 },
			{ name = "FanField", color = { 0.05, 0.38, 0.72 }, inset = 0.046 },
			{ name = "FanArch", color = { 0.88, 0.25, 0.06 }, inset = 0.078 },
			{ name = "FanField", color = { 0.04, 0.46, 0.66 }, inset = 0.092 },
		},
		figureColor = { 0.02, 0.02, 0.03 },
		-- A black trident on the blue: a long bar and two slanting prongs (fractions of the radii; angle in radians). Never a face.
		figure = { { x = 0, z = 0.05, rx = 0.07, rz = 0.50, angle = 0 }, { x = -0.30, z = -0.18, rx = 0.07, rz = 0.30, angle = 0.55 }, { x = 0.30, z = -0.18, rx = 0.07, rz = 0.30, angle = -0.55 } },
		back = { plane = -0.004, layers = { 1, 2, 3 } }, -- the layers (by number) the back repeats, and where (this far under the abdomen's belly)
		flaps = { color = { 0.88, 0.25, 0.06 }, radii = { 0.030, 0.006, 0.085 }, hingeX = 0.080, hingeY = 0.040, foldedDeg = -80 }, -- the folded flaps on the flanks
		sheen = 0.12,
	},
	-- Legs III in a dance: how the pose's raise and wave move them (ART).
	dance = { kneeUp = 0.03 },

	-- ---------------------------------------------------------------- no fuzz: at this size the coat would be sub-pixel
	fuzz = nil,

	idle = {
		riseSeconds = 1.0, fallSeconds = 0.25,
		breathe = { period = 3.0, bodyLift = 0.003, lift = 0.008, pitchDeg = 2.4 },
		tilt = { rollDeg = 7, yawDeg = 6, pitchDeg = 3.5, periods = { 9.1, 5.3, 11.3, 6.7, 8.3 } },
	},

	-- Full is for PCs; low is for phones and tablets: no foot balls, no eye sockets, no leg bands, no idle motion, no outline, no back to the fan, a plainer fan.
	detail = {
		full = {
			every = { lock = 1, guard = 1, fringe = 1, pale = 1, tuft = 1, ruff = 1, palp = 1, leg = 1 },
			shells = 0, speckleEvery = 1, pads = true, sockets = true, idle = true, highlight = true, fanBack = true, fanLayers = 5, legBands = true,
		},
		low = {
			every = { lock = 0, guard = 0, fringe = 0, pale = 0, tuft = 0, ruff = 0, palp = 0, leg = 0 },
			shells = 0, speckleEvery = 1, pads = false, sockets = false, idle = false, highlight = false, fanBack = false, fanLayers = 3, legBands = false,
		},
	},
}

return { default = "first_spider", profiles = { first_spider = first, maratus_volans_male = volans } }
