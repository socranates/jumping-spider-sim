--!strict
-- How a fly looks: numbers and names only; Client/FlyBodies builds the parts and places them each frame. A house fly (Musca
-- domestica) about 0.7 cm long, 1 stud = 1 cm. The prey profile (Data/Species fly_like_prototype) makes no species claim: this is
-- only how the prototype is drawn. Body frame: -Z forward, +Y up the surface normal, the origin the body's centre, which is where the
-- fly's position is, `hover` above the surface: the feet stand on y = -hover. Lengths are studs, colours hex, angles degrees. Ellipsoids
-- are Parts with a SpecialMesh sphere (Roblox forces a Ball part to be a sphere); rods are Cylinder parts, whose axis is X, so their Size
-- is (length, diameter, diameter).

local FlyLook = {}

FlyLook.hover = 0.16 -- the prey profile's body.hover_wu

FlyLook.colors = {
	eye = "8a2f1c", face = "cfd2cc", head = "4a4640", proboscis = "3a2b23",
	thorax = "5b5d58", stripe = "23211e", abdomen = "7b7266", dorsal = "35302a",
	femur = "3a332b", tibia = "2b2621", bristle = "1d1a17",
	wing = "d8e4ea", vein = "56463a", film = "f0c8ff", shadow = "2a241c",
} :: { [string]: string }

-- The ellipsoids that are always in place: centre, diameters, turn about x, y, z. The eyes are glossy.
FlyLook.body = {
	{ name = "Thorax", color = "thorax", at = { 0, 0.02, -0.05 }, size = { 0.27, 0.25, 0.30 } },
	{ name = "Abdomen", color = "abdomen", at = { 0, -0.002, 0.19 }, size = { 0.25, 0.21, 0.35 } },
	{ name = "Head", color = "head", at = { 0, -0.005, -0.28 }, size = { 0.19, 0.16, 0.15 } },
	{ name = "EyeL", color = "eye", reflectance = 0.07, at = { -0.079, 0.012, -0.275 }, size = { 0.12, 0.16, 0.14 } },
	{ name = "EyeR", color = "eye", reflectance = 0.07, at = { 0.079, 0.012, -0.275 }, size = { 0.12, 0.16, 0.14 } },
	{ name = "Face", color = "face", reflectance = 0.06, at = { 0, -0.015, -0.345 }, size = { 0.042, 0.13, 0.045 } }, -- the pale silver stripe between the eyes
	{ name = "Proboscis", color = "proboscis", at = { 0, -0.088, -0.335 }, size = { 0.045, 0.045, 0.12 }, turn = { -30, 0, 0 } }, -- short, pointing forward and down
} :: { { name: string, color: string, reflectance: number?, at: { number }, size: { number }, turn: { number }? } }

-- Thin dark slices that follow the curve of the ellipsoid `on`, `proud` of it: the thorax's four stripes and the abdomen's dorsal stripe.
-- x: where across the body, width: how wide.
FlyLook.proud = 0.002
FlyLook.slices = {
	{ name = "ThoraxStripe1", on = "Thorax", color = "stripe", x = -0.065, width = 0.024 },
	{ name = "ThoraxStripe2", on = "Thorax", color = "stripe", x = -0.025, width = 0.02 },
	{ name = "ThoraxStripe3", on = "Thorax", color = "stripe", x = 0.025, width = 0.02 },
	{ name = "ThoraxStripe4", on = "Thorax", color = "stripe", x = 0.065, width = 0.024 },
	{ name = "DorsalStripe", on = "Abdomen", color = "dorsal", x = 0, width = 0.045 },
} :: { { name: string, on: string, color: string, x: number, width: number } }

-- Six legs of two segments, a femur and a tibia with its foot: hip, knee and foot of the right front, middle and hind leg (the left
-- ones mirror them), standing and in flight (tucked and trailing). A rod runs `overlap` past the knee at each end so the joint has no gap.
FlyLook.legs = {
	femur = 0.024, tibia = 0.017, overlap = 0.01,
	stand = {
		{ name = "Front", hip = { 0.055, -0.09, -0.16 }, knee = { 0.135, -0.04, -0.24 }, foot = { 0.20, -0.16, -0.31 } },
		{ name = "Middle", hip = { 0.075, -0.09, -0.06 }, knee = { 0.175, -0.035, -0.07 }, foot = { 0.265, -0.16, -0.085 } },
		{ name = "Hind", hip = { 0.07, -0.09, 0.04 }, knee = { 0.155, -0.04, 0.17 }, foot = { 0.225, -0.16, 0.31 } },
	},
	fly = {
		{ name = "Front", hip = { 0.055, -0.09, -0.16 }, knee = { 0.10, -0.115, -0.24 }, foot = { 0.07, -0.20, -0.29 } },
		{ name = "Middle", hip = { 0.075, -0.09, -0.06 }, knee = { 0.13, -0.13, -0.03 }, foot = { 0.12, -0.21, 0.04 } },
		{ name = "Hind", hip = { 0.07, -0.09, 0.04 }, knee = { 0.105, -0.125, 0.14 }, foot = { 0.085, -0.215, 0.30 } },
	},
} :: { femur: number, tibia: number, overlap: number, stand: { { name: string, hip: { number }, knee: { number }, foot: { number } } }, fly: { { name: string, hip: { number }, knee: { number }, foot: { number } } } }

-- Tiny bristles on the head, the thorax and the abdomen: from a point just inside the body to the tip. Right side; `mirror` adds the left.
FlyLook.bristles = {
	diameter = 0.007,
	items = {
		{ from = { 0.027, 0.061, -0.284 }, to = { 0.043, 0.119, -0.319 }, mirror = true }, -- on the head, pointing up and forward
		{ from = { 0.047, 0.124, -0.022 }, to = { 0.066, 0.176, 0.011 }, mirror = true }, -- on the thorax's back
		{ from = { 0.037, 0.098, 0.044 }, to = { 0.05, 0.132, 0.103 }, mirror = true }, -- at the thorax's rear, pointing back
		{ from = { 0.078, 0.051, 0.267 }, to = { 0.111, 0.084, 0.317 }, mirror = true }, -- on the abdomen's side
	},
} :: { diameter: number, items: { { from: { number }, to: { number }, mirror: boolean } } }

-- The wings: thin ellipsoids (Glass), each with a dark leading-edge vein (a thin rod along the front, near the edge) and a faint
-- iridescent film (thin-film interference colours, Shevtsova et al. 2011, PNAS 108:668-673) just above the glass. At rest they are
-- folded back over the abdomen in a shallow V: from a root on the thorax, `yaw` turned outward from straight back, `pitch` up, `roll`
-- with the outer edge down. In flight they are replaced by a soft blur: a fan each side, flat, from the root outward and a little
-- back (`yaw`) for `reach`, `span` across, the outer edge `roll` up, two layers of translucent glass and film; the veins hide.
FlyLook.wing = {
	root = { 0.078, 0.112, -0.10 }, length = 0.60, width = 0.22, thick = 0.006,
	yaw = 9, pitch = 4, roll = 5,
	transparency = 0.55, reflectance = 0.1,
	vein = { diameter = 0.008, offset = 0.055, from = -0.42, to = 0.40, transparency = 0.2 }, -- from, to: along the wing, as shares of its length from the middle
	film = { rise = 0.004, grow = 0.004, transparency = 0.82 },
	fan = {
		reach = 0.36, span = 0.34, roll = 8, yaw = 20, back = 0.02, rise = 0.01, transparency = 0.80, -- the denser blur near the root
		film = { reach = 0.56, span = 0.54, transparency = 0.92 }, -- the fainter blur out to the tips
		shimmer = { 19, 0.05 }, -- radians per second, radians: the fan trembles a little
	},
}

-- A soft dark oval on the surface under a standing fly stands in for its shadow (the parts cast none): size, how far above the surface.
FlyLook.shadow = { size = { 0.34, 0.004, 0.70 }, lift = 0.003, transparency = 0.78 }

-- ROBLOX-96: the bed's prey, drawn from simpler sheets (Client/FlyBodies.buildSmall) in the same body frame (feet at y = -hover, the whole scaled by the profile's
-- visual_scale: the gnat at 0.45 is about 3 mm, the aphid at 0.4 under 3 mm). `body`: ellipsoids; `rods`: legs, antennae and the like, a rod from `from` to `to`
-- on the right side, mirrored when `mirror`, with `fly` endpoints for the flight pose where they differ; `wing`: one pair of plain glass wings (folded flat at rest,
-- a fan in flight), none for the aphid, which never flies; `shadow` as the fly's.
FlyLook.small = {
	-- a fungus gnat (Sciaridae, the small dark flies of damp soil): a thin grey body, long legs, long antennae, one pair of wings over the back
	fungus_gnat = {
		colors = { thorax = "3b3a38", abdomen = "4a4744", head = "2f2d2b", eye = "1a1816", leg = "2d2a27", antenna = "2a2725", wing = "cfd6dc", shadow = "2a241c" },
		body = {
			{ name = "Thorax", color = "thorax", at = { 0, 0.02, -0.06 }, size = { 0.16, 0.17, 0.22 } },
			{ name = "Abdomen", color = "abdomen", at = { 0, -0.01, 0.2 }, size = { 0.12, 0.12, 0.42 } },
			{ name = "Head", color = "head", at = { 0, 0, -0.24 }, size = { 0.11, 0.11, 0.1 } },
			{ name = "EyeL", color = "eye", reflectance = 0.05, at = { -0.05, 0.01, -0.25 }, size = { 0.05, 0.06, 0.05 } },
			{ name = "EyeR", color = "eye", reflectance = 0.05, at = { 0.05, 0.01, -0.25 }, size = { 0.05, 0.06, 0.05 } },
		},
		rods = {
			{ name = "FrontFemur", color = "leg", d = 0.012, from = { 0.05, -0.06, -0.15 }, to = { 0.16, 0.06, -0.26 }, fly = { { 0.05, -0.06, -0.15 }, { 0.09, -0.1, -0.24 } }, mirror = true },
			{ name = "FrontTibia", color = "leg", d = 0.009, from = { 0.16, 0.06, -0.26 }, to = { 0.26, -0.16, -0.36 }, fly = { { 0.09, -0.1, -0.24 }, { 0.08, -0.2, -0.3 } }, mirror = true },
			{ name = "MiddleFemur", color = "leg", d = 0.012, from = { 0.06, -0.06, -0.04 }, to = { 0.18, 0.07, -0.02 }, fly = { { 0.06, -0.06, -0.04 }, { 0.1, -0.11, 0.0 } }, mirror = true },
			{ name = "MiddleTibia", color = "leg", d = 0.009, from = { 0.18, 0.07, -0.02 }, to = { 0.3, -0.16, 0.0 }, fly = { { 0.1, -0.11, 0.0 }, { 0.09, -0.21, 0.06 } }, mirror = true },
			{ name = "HindFemur", color = "leg", d = 0.012, from = { 0.05, -0.06, 0.05 }, to = { 0.17, 0.08, 0.18 }, fly = { { 0.05, -0.06, 0.05 }, { 0.09, -0.11, 0.16 } }, mirror = true },
			{ name = "HindTibia", color = "leg", d = 0.009, from = { 0.17, 0.08, 0.18 }, to = { 0.27, -0.16, 0.34 }, fly = { { 0.09, -0.11, 0.16 }, { 0.07, -0.21, 0.32 } }, mirror = true },
			{ name = "Antenna", color = "antenna", d = 0.008, from = { 0.03, 0.04, -0.28 }, to = { 0.07, 0.16, -0.42 }, mirror = true } :: any,
		},
		wing = { root = { 0.05, 0.1, -0.06 }, length = 0.5, width = 0.16, thick = 0.005, yaw = 6, pitch = 2, roll = 0, transparency = 0.5, reflectance = 0.08,
			fan = { reach = 0.34, span = 0.3, roll = 8, yaw = 20, back = 0.02, rise = 0.01, transparency = 0.8 } },
		shadow = { size = { 0.2, 0.004, 0.55 }, lift = 0.003, transparency = 0.8 },
	},
	-- an aphid: a pear-shaped green body, a small head, two cornicles at the rear, short legs, long antennae, no wings
	aphid = {
		colors = { abdomen = "7fb04c", head = "6f9e42", eye = "3a2a1a", leg = "5f8a3a", antenna = "567f33", cornicle = "4f7a2e", shadow = "2a241c" },
		body = {
			{ name = "Abdomen", color = "abdomen", at = { 0, 0.02, 0.1 }, size = { 0.34, 0.3, 0.46 } },
			{ name = "Head", color = "head", at = { 0, 0, -0.2 }, size = { 0.14, 0.14, 0.14 } },
			{ name = "EyeL", color = "eye", reflectance = 0.05, at = { -0.065, 0.02, -0.21 }, size = { 0.04, 0.04, 0.04 } },
			{ name = "EyeR", color = "eye", reflectance = 0.05, at = { 0.065, 0.02, -0.21 }, size = { 0.04, 0.04, 0.04 } },
		},
		rods = {
			{ name = "FrontLeg", color = "leg", d = 0.014, from = { 0.1, -0.04, -0.12 }, to = { 0.2, -0.16, -0.24 }, mirror = true },
			{ name = "MiddleLeg", color = "leg", d = 0.014, from = { 0.12, -0.04, 0.0 }, to = { 0.23, -0.16, 0.02 }, mirror = true },
			{ name = "HindLeg", color = "leg", d = 0.014, from = { 0.11, -0.04, 0.12 }, to = { 0.21, -0.16, 0.26 }, mirror = true },
			{ name = "Antenna", color = "antenna", d = 0.008, from = { 0.04, 0.06, -0.24 }, to = { 0.1, 0.1, -0.5 }, mirror = true },
			{ name = "Cornicle", color = "cornicle", d = 0.02, from = { 0.07, 0.1, 0.26 }, to = { 0.1, 0.17, 0.36 }, mirror = true },
		},
		shadow = { size = { 0.3, 0.004, 0.46 }, lift = 0.003, transparency = 0.8 },
	},
} :: { [string]: any }

return FlyLook
