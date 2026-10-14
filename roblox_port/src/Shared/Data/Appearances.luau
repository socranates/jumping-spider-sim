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
		-- they stand out of the head, as a share of their depth. Two catchlights, both toward +X (one light, one reflection).
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
	-- The camera sits 5 studs away (CameraMath.CAMERA_DISTANCE), 1 stud is about 170 px on a 1080p screen, so a hair has to
	-- be a couple of hundredths of a stud wide to show at all. Hairs are flat locks lying back along the body; the grey and
	-- frosted ones give the coat a silvery sheen against the black; white ones cover the white markings.
	fuzz = {
		enabled = true,
		-- The pelt: wide flat locks lying back over the head and abdomen like shingles. `abdomen` and `head` are Fibonacci
		-- sample points before the belly is skipped (the hairs kept are about 60 % of them). `flat`: a lock's thickness as a
		-- share of its width. `lieBack`: 0 stands straight out, 1.0 leans about 45 degrees toward the rear. `dark` and `grey`
		-- are the shares of those tones, the rest is frosted; hairs over the white markings are white. `transparency`: a little
		-- see-through, so the coat looks soft rather than spiky.
		locks = { abdomen = 190, head = 105, length = { 0.050, 0.085 }, width = 0.040, flat = 0.17, lieBack = 0.9, dark = 0.55, grey = 0.30, transparency = 0.12 },
		-- Guard hairs: longer, finer hairs that stand off the pelt and make the fuzzy edge you see against the sill.
		guard = { abdomen = 250, head = 140, length = { 0.060, 0.098 }, width = 0.0115, flat = 1.0, lieBack = 0.45, dark = 0.25, grey = 0.40, transparency = 0.28 },
		dark = { 0.13, 0.13, 0.13 },
		grey = { 0.50, 0.50, 0.48 },
		frost = { 0.76, 0.76, 0.73 },
		-- Fur shells: see-through layers outside the body so the outline goes soft. Three at full detail, one at low.
		shellColor = { 0.34, 0.34, 0.33 },
		shells = { { scale = 1.07, transparency = 0.86 }, { scale = 1.14, transparency = 0.93 }, { scale = 1.22, transparency = 0.965 } },
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
		legDark = 0.4, legGrey = 0.35, -- tone shares on the legs (the rest is frosted)
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
	-- hairs (keep one in `every`), a single fur shell, no foot balls, half the speckles, no outline and no idle motion at all
	-- (no breathing, head tilt or palp drumming). The pattern, eyes, catchlights and tufts stay.
	detail = {
		full = {
			every = { lock = 1, guard = 1, tuft = 1, ruff = 1, palp = 1, leg = 1 },
			shells = 3, speckleEvery = 1, pads = true, sockets = true, idle = true, highlight = true,
		},
		low = {
			every = { lock = 3, guard = 5, tuft = 2, ruff = 2, palp = 2, leg = 4 },
			shells = 1, speckleEvery = 2, pads = false, sockets = false, idle = false, highlight = false,
		},
	},
}

return { default = "first_spider", profiles = { first_spider = first } }
