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
	gloss = 0.04, -- ROBLOX-85: a touch of sheen on the carapace and abdomen (Reflectance; SmoothPlastic as before); the eyes are as they were
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
		fluff = { hairs = 5, length = 0.048, width = 0.0085, flat = 0.7, transparency = 0.15 }, -- finer in ROBLOX-85 (was 0.055 long, 0.012 wide)
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
	-- ---------------------------------------------------------------- the shape of a leg and a fang (ROBLOX-84)
	-- The three links of a leg (femur, tibia, tarsus: the solver, the targets and the gait are untouched) are drawn as the segments a spider
	-- really has, each a part, so a leg is no longer a tube with ball joints. All numbers are ART. Shares are of the link's length (`split`:
	-- where the thick rod ends and the thinner one starts) and of the rod's diameter (`taper`, `tip`, `joint`, `patella`). `bend` is how far
	-- (studs) the break in the tarsus is lifted, so the foot reads as two segments. The knee is the patella: a short stout ellipsoid, its
	-- long axis along the bend. `foot` is the tarsal pad: radii as multiples of the tarsus' diameter, a flattened ellipsoid lying on the
	-- surface under the foot; `claws` are two tiny dark rods splayed from its front (`splay` is the share of sideways in the direction).
	-- Which of these a tier draws is in `detail` (taper, tibiaTaper, jointBreak, claws, strands, fangSegments).
	legForm = {
		femur = { split = 0.62, taper = 0.74 },
		tibia = { split = 0.62, taper = 0.86 },
		patella = { length = 1.30, width = 1.10 },
		tarsus = { split = 0.55, tip = 0.78, joint = 1.15, bend = 0.012 },
		foot = { rx = 0.85, ry = 0.50, rz = 0.72 },
		claws = { count = 2, length = 0.036, radius = 0.0045, splay = 0.40 },
	},
	-- Two small curved fangs under the chelicerae, tucked: each is a chain of ellipsoids from the lower front of its chelicera (Anatomy.layout);
	-- `dir` is the segment's direction (x is mirrored; -Z forward, -Y down). Foil, a little glossy, so a highlight finds them.
	fang = {
		x = 0.052, y = -0.140, z = -0.466, reflectance = 0.25, color = { 0.11, 0.05, 0.035 }, -- dark mahogany, so it reads against the black jaw
		segments = { { dir = { -0.10, -0.75, -0.65 }, length = 0.040, radius = 0.011 }, { dir = { -0.55, -0.80, -0.10 }, length = 0.032, radius = 0.008 } },
	},

	-- ---------------------------------------------------------------- fuzz (ROBLOX-07, retuned for the real camera in ROBLOX-13)
	-- The camera sits 5 studs away (CameraMath.CAMERA_DISTANCE), 1 stud is about 170 px on a 1080p screen, so a hair is a few
	-- pixels at most. The first coat answered that with big stiff hairs, and they stood off the body like a hedgehog's and
	-- covered the white spots; the second coat (this one) is short, thin and combed flat, and leaves the softness to the shells.
	fuzz = {
		enabled = true,
		-- ROBLOX-85: fur that lies along the body. The third coat (the second, ROBLOX-13's, was short and combed flat but its hairs were wide, flat
		-- chips, 0.018 across for 0.03 long, and read as scales or splinters) is finer, shorter and denser, and every hair of the coat lies at a low
		-- angle off the surface (15 to 25 degrees, not 3 to 13 and not standing) pointing backward and a little outward: toward the abdomen's tip on
		-- the abdomen and the head's dome, down the leg toward the foot on a leg. It takes its colour from the pattern it grows on: black hairs on the black
		-- areas, white hairs only inside the white spots and the band, and a few (`tip`) with a greyer, paler cast, which is what a dark coat does
		-- where it catches the light; nothing white is off the white. The softness still comes from the fur shells.
		-- `abdomen` and `head` are Fibonacci sample points before the belly is skipped (about 60 % of them become hairs).
		-- `length` and `lift` are ranges (studs; degrees off the surface: 0 lies flat, 90 stands up); `yaw` scatters the combing (degrees either
		-- side of straight back) and `out` turns it away from the midline (degrees, at most, per hair: the abdomen's fur flows back and out);
		-- `flat` is the thickness as a share of the width; `black` is the share of the blackest tone (the rest is `dark`); `tip` the share of the
		-- greyer tone; `transparency` keeps the coat a little see-through.
		-- Locks: the pelt, lying at a low angle and combed toward the rear.
		locks = { abdomen = 440, head = 250, length = { 0.022, 0.036 }, width = 0.0075, flat = 0.8, lift = { 15, 25 }, yaw = 12, out = 16, black = 0.45, tip = 0.07, transparency = 0.10 },
		-- Guard hairs: a few short, fine hairs that stand up from the pelt (the only ones that do).
		guard = { abdomen = 24, head = 12, length = { 0.026, 0.038 }, width = 0.0055, flat = 1.0, lift = { 42, 56 }, yaw = 30, black = 0.5, transparency = 0.20 },
		-- The fringe: finer hairs along the sides (`side`: how far round to the side, as a share of the radius, a hair has to be), lifted a little more
		-- and leaning out, so the outline is soft by a pixel or two and not ragged by a chip.
		fringe = { abdomen = 220, head = 80, side = 0.78, length = { 0.024, 0.034 }, width = 0.0065, flat = 0.8, lift = { 20, 30 }, yaw = 14, out = 24, black = 0.5, tip = 0.07, transparency = 0.20 },
		-- White hairs inside the white spots and the band: `density` per square stud of marking, lying on it (14 to 22 degrees), kept only when the
		-- whole hair stays `margin` studs inside the edge, so the white keeps its edge.
		pale = { density = 800, length = { 0.021, 0.027 }, width = 0.0085, flat = 0.6, lift = { 14, 22 }, yaw = 12, margin = 0.004, transparency = 0.05 },
		clear = 0.006, -- black hairs stay this far (studs) from any white marking
		black = { 0.03, 0.03, 0.03 },
		dark = { 0.13, 0.13, 0.13 },
		grey = { 0.50, 0.50, 0.48 }, -- grey and frost: the pale tips of the coat, the face (tufts, ruff) and the palps' fluff
		frost = { 0.76, 0.76, 0.73 },
		-- Fur shells: see-through layers outside the body, strongest nearest it, so the outline goes soft. Four at full detail, one at low. A shell
		-- tints what is under it as well as what is around it, so they are dark and faint: the white of the pattern must stay white.
		shellColor = { 0.08, 0.08, 0.08 },
		shells = { { scale = 1.05, transparency = 0.86 }, { scale = 1.10, transparency = 0.92 }, { scale = 1.16, transparency = 0.955 }, { scale = 1.23, transparency = 0.975 } },
		headShell = { zScale = 0.80, shift = 0.05 }, -- the head's shells sit back from the eye row so the eyes stay clear
		-- Little tufts that bold jumping spiders have above the eyes, at the upper sides of the head: a fan of dark and silvery hairs that sweeps
		-- up and out, finer than before. Not eyebrows: they sit behind the eyes at the sides, not over them.
		tuftHairs = 7, -- per side
		tuftLength = 0.058,
		tuft = { at = { 0.52, 0.80, -0.28 }, lean = { 0.60, 1.0, 0.05 }, fan = 0.46, spread = 0.02, width = 0.0075, flat = 0.8, transparency = 0.1 },
		-- A soft ruff of pale hair low on each cheek, beside the jaws (not a moustache: it sits at the sides).
		ruff = { hairs = 4, length = 0.042, width = 0.0075, flat = 0.7, at = { 0.52, -0.36, -0.74 }, lean = { 0.65, -0.55, -0.30 }, whiteShare = 0.6, transparency = 0.15 },
		legHairs = { 4, 4, 1 }, -- femur, tibia, tarsus, per leg (front legs carry 1.6 x as many on femur and tibia)
		legLength = 0.040,
		legWidth = 0.0075,
		legTransparency = 0.2,
		legBlack = 0.4, -- the share of the blackest tone on the legs (the rest is dark; white over the pale bands)
		legLift = { 15, 26 }, -- a leg's hairs lie at this angle off the leg, pointing down it toward the foot
		legTip = 0.08, -- the share of the legs' hairs with the greyer cast
		hipBare = { 0.6, 0.6, 0, 0 }, -- ROBLOX-93: the share of each pair's femur, from the hip, that has no hair (the hairs are spread over the rest): legs I and II start at the face, where the anterior lateral eyes are, and a walking leg I swings past them
	},

	-- ---------------------------------------------------------------- idle motion (drawn rig only, ROBLOX-13)
	-- Eased in after the spider has stood still for a moment; off while walking, in the air, in low detail and with reducedMotion
	-- (the palps' drumming follows the same rule).
	idle = {
		riseSeconds = 1.0, fallSeconds = 0.25,
		-- A breath (ROBLOX-87: 0.4 Hz, was 0.3): the body's lift and the abdomen's pitch as before, and the abdomen's scale `scale` (2.5%) with it, hairs and shell
		-- moving with it; `movingShare` of it while the spider walks, hangs or is posed.
		breathe = { period = 2.5, bodyLift = 0.006, lift = 0.016, pitchDeg = 2.4, scale = 0.025, movingShare = 0.35 },
		-- A small, slow, curious head tilt: sums of sines (periods in seconds), always inside these angles.
		tilt = { rollDeg = 7, yawDeg = 6, pitchDeg = 3.5, periods = { 9.1, 5.3, 11.3, 6.7, 8.3 } },
		-- Living motion (ROBLOX-87, Rig/Living; every number ART). Grooming: after `after` seconds of standing, a bout `firstWait` seconds later and then every `gap` seconds
		-- after the last one ended (a seeded stream), either a palp drawn through the jaws (`strokes` of them over `palpSeconds`, the palp turning `palpYawDeg` toward
		-- the midline and `palpPitchDeg` down) or a leg I pulled forward to where `legs[1]` says (the body frame, studs; kneeOut and kneeUp bend the knee) and wiped
		-- `sweep` studs to and fro through the palps (which close `legPalpYawDeg`) for `legSeconds`; after a meal (the "groom" cue), `mealDelay` seconds into a stand, both
		-- palps (`mealPalpSeconds`) then legs I and II, each leg `legSeconds`. A bout fades over `fade` of its act and gives way in `abortSeconds` when the spider moves.
		groom = {
			after = 4.0, firstWait = { 0.3, 3.0 }, gap = { 8, 20 }, mealDelay = 1.5, strokes = 3,
			palpSeconds = 2.0, legSeconds = 2.5, mealPalpSeconds = 2.2, palpYawDeg = 30, palpPitchDeg = 20, legPalpYawDeg = 24, fade = 0.18, abortSeconds = 0.25,
			legs = {
				{ x = 0.12, y = -0.16, z = -0.64, sweep = 0.06, kneeOut = 0.22, kneeUp = 0.20 },
				{ x = 0.15, y = -0.18, z = -0.56, sweep = 0.06, kneeOut = 0.22, kneeUp = 0.20 },
				{ x = 0.15, y = -0.18, z = -0.56, sweep = 0.06, kneeOut = 0.22, kneeUp = 0.20 },
				{ x = 0.15, y = -0.18, z = -0.56, sweep = 0.06, kneeOut = 0.22, kneeUp = 0.20 },
			},
		},
		-- Attention: the drawn body turns toward the focus point (at most `maxDeg`, eased over `easeSeconds`); the principal eyes shift `glance` studs toward it,
		-- all of it across `glanceSpanDeg` of the angle that is left.
		attention = { maxDeg = 20, easeSeconds = 0.4, glance = 0.02, glanceSpanDeg = 28 },
		-- Alarm: legs I go to `raise` (body frame, studs) and the idle motion freezes for `seconds`, in `riseSeconds` and out over `fallSeconds`.
		alarm = { seconds = 1.2, riseSeconds = 0.15, fallSeconds = 0.35, raise = { x = 0.20, y = 0.30, z = -0.52, kneeOut = 0.10, kneeUp = 0.22 } },
		-- The mating scene's two cues (ROBLOX-89; both spiders, ART). Meet: legs I go to `reach` (the body frame, studs: out in front of the head and a little off the floor, the
		-- knee out and up) and the palps lift `palpLiftDeg` and turn `palpYawDeg` toward the midline, in `riseSeconds`, held, and out over `fallSeconds`, for the cue's `seconds`. Settle:
		-- the body sinks `lower` studs and the breath is `breath` times as deep, the same way. Grooming and the accents give way to both (the breath goes on).
		meet = { seconds = 4.0, riseSeconds = 0.8, fallSeconds = 0.8, reach = { x = 0.14, y = -0.02, z = -0.74, kneeOut = 0.12, kneeUp = 0.16 }, palpLiftDeg = 12, palpYawDeg = 8 }, -- (ROBLOX-93: kneeOut 0.08 to 0.12, the knees stand out wide enough for the legs to clear the face)
		settle = { seconds = 4.0, riseSeconds = 0.8, fallSeconds = 0.8, lower = 0.035, breath = 1.6 },
	},

	-- ---------------------------------------------------------------- hanging on a dragline (ROBLOX-59, ROBLOX-86; drawn rig only)
	-- The body hangs with its long axis along the line, head down, tail (the spinneret) up at the line. `rate` is how fast the pose blends in (per
	-- second); `leanDeg` the static angle the long axis stands off the line; `sway` a damped pendulum about the spinneret (degrees, seconds; `across` is
	-- the share of it that swings sideways, a quarter turn out of phase) that the drop starts; `spin` a slow damped turn about the line (degrees a second,
	-- seconds); `climb` the head-up pose on the way up the line (the speed along the line that counts as climbing, studs a second, the blend in seconds,
	-- and how far the body stands off the line, as a share of the carapace's half height). `legs` are, for each pair, the directions of the femur,
	-- tibia and tarsus in the body frame (x is mirrored for the left; +Z toward the tail and the line, -Z toward the head): each link keeps the length it
	-- has standing, so legs I and II curl forward and back up toward the line and legs III and IV fold back along the body. `asym` is a fixed per-leg
	-- scatter and `wiggle` a small slow tremble of the feet (not with Reduced Motion); `palpTuckDeg` draws the palps in. All ART.
	hang = {
		rate = 3.5,
		leanDeg = 3.0,
		sway = { deg = 4.5, period = 2.5, decay = 4.0, across = 0.45 },
		spin = { degPerS = 8.0, decay = 7.0 },
		climb = { speed = 0.35, seconds = 0.5, shift = 0.8 },
		palpTuckDeg = 30,
		asym = 0.10, wiggle = 0.08,
		legs = {
			{ femur = { 0.65, -0.20, -0.25 }, tibia = { -0.10, -0.25, 0.90 }, tarsus = { -0.45, -0.30, 0.50 } },
			{ femur = { 0.65, -0.20, -0.05 }, tibia = { -0.05, -0.25, 0.90 }, tarsus = { -0.50, -0.30, 0.50 } },
			{ femur = { 0.60, -0.15, 0.55 }, tibia = { 0.00, -0.20, 0.80 }, tarsus = { -0.55, -0.30, -0.35 } },
			{ femur = { 0.40, -0.15, 0.85 }, tibia = { 0.15, -0.20, 0.35 }, tarsus = { -0.50, -0.30, -0.20 } },
		},
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
			taper = true, tibiaTaper = true, jointBreak = true, claws = 2, fangSegments = 2,
		},
		low = {
			every = { lock = 4, guard = 0, fringe = 3, pale = 2, tuft = 2, ruff = 2, palp = 2, leg = 4 },
			shells = 1, speckleEvery = 2, pads = false, sockets = false, idle = false, highlight = false,
			taper = true, tibiaTaper = false, jointBreak = false, claws = 0, fangSegments = 1,
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
	cameraScale = 0.62, -- closer framing for the small appearance; user zoom still applies
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
		foldedThickness = 0.042, foldedSink = 0.021, -- folded, the discs are thick and sunk into the dome (a lens on the abdomen) and flatten as the fan opens
		layers = {
			{ name = "FanFringe", color = { 0.95, 0.94, 0.88 }, inset = 0.0 },
			{ name = "FanArch", color = { 0.96, 0.30, 0.065 }, inset = 0.015 },
			{ name = "FanField", color = { 0.025, 0.48, 0.82 }, inset = 0.046 },
			{ name = "FanArch", color = { 0.88, 0.25, 0.06 }, inset = 0.078 },
			{ name = "FanField", color = { 0.02, 0.65, 0.67 }, inset = 0.092 },
		},
		figureColor = { 0.02, 0.02, 0.03 },
		-- A black trident on the blue: a long bar and two slanting prongs (fractions of the radii; angle in radians). Never a face.
		figure = { { x = 0, z = 0.05, rx = 0.07, rz = 0.50, angle = 0 }, { x = -0.30, z = -0.18, rx = 0.07, rz = 0.30, angle = 0.55 }, { x = 0.30, z = -0.18, rx = 0.07, rz = 0.30, angle = -0.55 } },
		back = { plane = -0.004, layers = { 1, 2, 3 } }, -- the layers (by number) the back repeats, and where (this far under the abdomen's belly)
		flaps = { color = { 0.88, 0.25, 0.06 }, radii = { 0.030, 0.006, 0.085 }, hingeX = 0.080, hingeY = 0.040, foldedDeg = -80 }, -- the folded flaps on the flanks
		sheen = 0.18,
	},
	-- Legs III in a dance: how the pose's raise and wave move them (ART).
	dance = { kneeUp = 0.03 },

	-- ---------------------------------------------------------------- no fuzz: at this size the coat would be sub-pixel
	fuzz = nil,

	idle = {
		riseSeconds = 1.0, fallSeconds = 0.25,
		breathe = { period = 3.0, bodyLift = 0.003, lift = 0.008, pitchDeg = 2.4 },
		tilt = { rollDeg = 7, yawDeg = 6, pitchDeg = 3.5, periods = { 9.1, 5.3, 11.3, 6.7, 8.3 } },
		-- The mating scene's cues (ROBLOX-89): the first spider's, at this spider's size (0.47): no grooming, no alarm, but the reach and the settle.
		meet = { seconds = 4.0, riseSeconds = 0.8, fallSeconds = 0.8, reach = { x = 0.066, y = -0.01, z = -0.35, kneeOut = 0.056, kneeUp = 0.075 }, palpLiftDeg = 12, palpYawDeg = 8 }, -- (the first spider's kneeOut 0.12 at this size)
		settle = { seconds = 4.0, riseSeconds = 0.8, fallSeconds = 0.8, lower = 0.016, breath = 1.6 },
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

-- ART: six fine teal scale streaks catch light on the open fan. Full detail only; mobile keeps its 80-part budget.
for _,side in {-1,1} do
 for _,z in {-0.36,0,0.36} do
  table.insert(volans.fan.figure,{x=side*0.49,z=z,rx=0.018,rz=0.10,angle=side*z*0.65,
   color={0.30,0.80,0.86},fullOnly=true})
 end
end

-- A brown rival, distinct from the player; illustrative salticid, no species identification.
local rival: any=table.clone(first)
-- The rival keeps the coat the first spider had before ROBLOX-85 (ROBLOX-13's second coat, whose numbers are below), as it was drawn.
local rivalFuzz: any = {
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
	hipBare = { 0.6, 0.6, 0, 0 }, -- ROBLOX-93: as the first spider's
}
rival.fuzz=rivalFuzz;rival.gloss=nil
rival.palp=table.clone(first.palp);rival.palp.fluff={ hairs = 7, length = 0.055, width = 0.012, flat = 0.7, transparency = 0.15 } -- (ROBLOX-85 made the first spider's palp fluff finer)
rival.id="rival_spider";rival.body={.22,.14,.08};rival.legs={.27,.18,.10};rival.white={.64,.48,.29}
-- ROBLOX-84 gave the first spider shaped legs and fangs; the rival (a clone of it) keeps the plain tubes and balls, as it was drawn.
rival.legForm=nil;rival.fang=nil
rival.detail={
 full={every={lock=1,guard=1,fringe=1,pale=1,tuft=1,ruff=1,palp=1,leg=1},shells=4,speckleEvery=1,pads=true,sockets=true,idle=true,highlight=true},
 low={every={lock=3,guard=0,fringe=3,pale=2,tuft=2,ruff=2,palp=2,leg=4},shells=1,speckleEvery=2,pads=false,sockets=false,idle=false,highlight=false},
}

-- ================================================================ the ant-mimicking spider (ROBLOX-64)
-- Myrmarachne formicaria, the female: a third profile beside the daughter's and the peacock's, chosen from the crack (Client/SpiderClient).
-- A jumping spider that looks like an ant (Shamble, Hoy, Cohen & Beatus 2017, Proc. R. Soc. B 284: 20170308; see Data/AntMimic): a slender,
-- glossy dark brown-black body (DOC), the cephalothorax pinched into a "head" and a "thorax" (DOC), the abdomen joined by a narrow waist
-- like an ant's petiole, with an oval "gaster" behind it (DOC), and long thin legs (DOC). It keeps a jumping spider's eight eyes with the big
-- pair in front: take away the ant's body and it is a salticid. The playbacks' body length was 5 mm (DOC), so the drawn spider is 0.5 studs
-- (1 stud = 1 cm). The exact colours, proportions, thicknesses and angles are ART. The male (huge forward chelicerae) is a possible later variant.
-- Collider, senses and physics are the first spider's: this is a drawn appearance, an antennae pose and a drawn wobble, nothing more.
local ant = {
	id = "myrmarachne_formicaria_female",
	name = "Ant-mimicking spider (female)",
	scale = 0.5, -- SpiderRig scales its own distances (foot search, stepping) by this
	cameraScale = 0.6, -- closer framing for the small appearance; user zoom still applies
	bodyDrop = 0.19, -- the drawn body sits this far (studs) below the collider's centre (0.31 over the surface): long legs, the body well off the floor

	-- ---------------------------------------------------------------- colours (ART)
	body = { 0.050, 0.030, 0.022 }, -- the head: glossy dark brown-black
	legs = { 0.20, 0.115, 0.055 }, -- amber-brown legs
	white = { 0.50, 0.36, 0.18 }, -- palp bands: a dull amber (no white on this spider)
	eyes = { 0.008, 0.008, 0.008 },
	fangs = { 0.12, 0.060, 0.030 },
	joint = { 0.11, 0.065, 0.035 },
	palpColors = { stalk = { 0.18, 0.10, 0.05 }, club = { 0.30, 0.18, 0.08 }, tip = { 0.42, 0.28, 0.12 } },
	abdomenColor = { 0.068, 0.040, 0.027 }, -- the gaster: a shade warmer than the head, so the three segments read apart
	gloss = 0.16, -- glossy cuticle (Reflectance on the body segments)

	-- ---------------------------------------------------------------- proportions: head, thorax, waist, gaster (body frame: -Z forward)
	headCenter = { 0, 0, -0.165 },
	headRadii = { 0.072, 0.062, 0.080 },
	abdomenCenter = { 0, 0.004, 0.145 },
	abdomenRadii = { 0.058, 0.052, 0.105 },
	pedicel = { center = { 0, 0.0, 0.041 }, radii = { 0.021, 0.021, 0.024 } },
	face = { center = { 0, -0.012, -0.205 }, radii = { 0.050, 0.040, 0.040 } },
	neck = { 0, 0, -0.095 }, -- the head tilts about this point
	-- More body segments the first spiders do not have: the thorax behind the head (the pinch between them is the "neck" of an ant's silhouette)
	-- and the node on the waist (the petiole). group: "body", "head" or "abdomen" (what they move with).
	extras = {
		{ name = "Thorax", center = { 0, 0.004, -0.040 }, radii = { 0.056, 0.052, 0.074 }, group = "body", color = { 0.125, 0.070, 0.038 } },
		{ name = "PetioleNode", center = { 0, 0.020, 0.046 }, radii = { 0.016, 0.019, 0.015 }, group = "body", color = { 0.085, 0.048, 0.028 } },
	},
	chelicerae = { x = 0.016, y = -0.040, z = -0.234, radii = { 0.013, 0.019, 0.013 }, pitch = -0.35, splay = 0.12, reflectance = 0.1 }, -- the female's are small
	-- Eyes, as a jumping spider's: the big principal pair in front (a second look shows a spider), two smaller pairs at the sides and on the dome.
	eye = {
		ame = {
			x = 0.032, y = 0.012, radii = { 0.029, 0.029, 0.025 }, out = 0.30, reflectance = 0.5,
			socket = { scale = 1.12, color = { 0.20, 0.115, 0.05 } },
			glints = { { dx = 0.009, dy = 0.011, r = 0.0075 }, { dx = -0.009, dy = -0.011, r = 0.0033 } },
		},
		ale = { x = 0.055, y = 0.020, r = 0.014, out = 0.15, reflectance = 0.3 },
		ple = { x = 0.050, z = -0.130, r = 0.016, out = 0.10, reflectance = 0.3 },
		pme = { x = 0.036, z = -0.190, r = 0.006, out = 0.10, reflectance = 0.3 },
		glintColor = { 1, 1, 1 },
	},
	palp = {
		x = 0.030, y = -0.030,
		drop = 0.022, reach = 0.004, spread = 0.008, offsetScale = 0.25, -- the club and tip sit closer to the stalk at this size
		stalk = 0.011, club = { 0.013, 0.012, 0.016 }, tipRadii = { 0.0085, 0.0075, 0.0085 },
		fluff = { hairs = 0, length = 0, width = 0, flat = 1, transparency = 0 },
		drumHz = 3.2, drumDeg = 13,
	},
	-- Legs (display only): long and thin, standing the body well off the floor, spread like an ant's.
	limbs = {
		hipX = 0.040, hipY = -0.010,
		hipZ = { -0.115, -0.070, -0.025, 0.020 },
		tipZ = { -0.27, -0.13, 0.09, 0.27 },
		diameters = { { 0.020, 0.014 }, { 0.019, 0.013 }, { 0.019, 0.013 }, { 0.020, 0.014 } },
		thickness = 1.0,
		stance = { x = 0.24, y = -0.12, reach = 1.0 }, -- the rest foot spot (the drop of 0.19 puts it on the surface)
		kneeLift = 0.15, kneeLiftAir = 0.10, ankleLift = 0.02,
		pad = 1.6,
		pairReach = { 1.0, 1.0, 1.0, 1.1 },
	},
	frontLegScale = 1.0,
	bandFraction = 0.12, -- the amber band on each palp
	speckleCount = 0,
	spots = {},
	band = { count = 0, step = 0.1, z = 0, rx = 0.01, rz = 0.01 },
	speckle = { from = 0.4, step = 0.1, rx = 0.004, rz = 0.005 },
	-- The antennal illusion (DOC: when stationary, legs I are raised above head height and move in phase like ant antennae): where the foot goes
	-- (body frame, studs, x mirrored for the left leg) when they are up, when they are up and high (the display key) and at the end of a wave
	-- sweep (down and forward). `kneeOut` pushes the knee outward and `kneeUp` lifts it. All ART; Rig/AntMimicPose says how far and how fast.
	antennae = {
		pair = 1,
		up = { x = 0.075, y = 0.175, z = -0.285 },
		high = { x = 0.085, y = 0.225, z = -0.300 },
		swept = { x = 0.095, y = 0.130, z = -0.335 },
		kneeOut = 0.030, kneeUp = 0.020,
	},

	-- ---------------------------------------------------------------- no fuzz (sub-pixel at this size), no fan, no idle motion: when still it waves its legs I
	fuzz = nil,
	idle = {
		riseSeconds = 1.0, fallSeconds = 0.25,
		breathe = { period = 3.0, bodyLift = 0, lift = 0, pitchDeg = 0 },
		tilt = { rollDeg = 0, yawDeg = 0, pitchDeg = 0, periods = { 9.1, 5.3, 11.3, 6.7, 8.3 } },
	},
	-- Full is for PCs; low is for phones and tablets: no foot balls, no eye sockets, no outline. No leg bands, no hairs at either tier.
	detail = {
		full = {
			every = { lock = 0, guard = 0, fringe = 0, pale = 0, tuft = 0, ruff = 0, palp = 0, leg = 0 },
			shells = 0, speckleEvery = 1, pads = true, sockets = true, idle = false, highlight = true, legBands = false,
		},
		low = {
			every = { lock = 0, guard = 0, fringe = 0, pale = 0, tuft = 0, ruff = 0, palp = 0, leg = 0 },
			shells = 0, speckleEvery = 1, pads = false, sockets = false, idle = false, highlight = false, legBands = false,
		},
	},
}

-- ================================================================ the tarantula pack (ROBLOX-81)
-- Two tarantula costumes on the jumping spider's own body and senses: the Mexican redknee (Brachypelma hamorii) and the Greenbottle blue
-- (Chromatopelma cyaneopubescens). Perplexity's design (Nathan, 2026-10-18), adapted to the rig: the colours are hers; the shapes are the
-- first spider's size and build (a real tarantula is five or six centimetres of body, five times the first spider, and would not fit the
-- crack or the collider, which a costume must not change), so this is a drawn appearance at the first spider's scale and nothing more:
-- the collider, the motor, the jump, the senses, the silk, the wasp and the rival are the first spider's (SpiderChoice, ROBLOX-81).
-- Both belong to `pack = "tarantula_pack"` and are free, like the peacock spider and the ant mimic (ROBLOX-66): SpiderChoice.locked is the
-- one place a sale would go. What makes a tarantula in the rig: a broad low carapace (a dark core with a lighter rim, "CarapaceRim"), an
-- ocular tubercle with eight tiny clustered eyes instead of the salticid's big front pair (`tubercle`, Anatomy), thick parallel chelicerae,
-- leg-like pedipalps, a plump abdomen with its own markings (`marks`), two two-segment spinnerets (extras), stocky legs coloured segment by
-- segment (`legColors`, `legBands`). Colours are Perplexity's hex values; every size and angle is ART.
local function hex(h: number): { number }
	return { math.floor(h / 65536) / 255, math.floor(h / 256) % 256 / 255, h % 256 / 255 }
end

-- The parts both share. `o` is what differs between the species (see the two calls below). The first spider is the base so that anything
-- a tarantula does not say (idle motion, the palp's drum, the body's fuzz knobs) is the first spider's.
-- A tarantula hangs through the same code as the others (a stretch for the animal: it dangles on silk only when it falls, see ROBLOX-86) but
-- heavier: a shorter, slower swing and a slower turn.
local tarantulaHang = table.clone(first.hang)
tarantulaHang.leanDeg = 3.0
tarantulaHang.sway = { deg = 3.5, period = 2.5, decay = 3.0, across = 0.45 }
tarantulaHang.spin = { degPerS = 5.0, decay = 6.0 }

-- A tarantula's idle is calm and heavy (ROBLOX-87): a slower breath (0.25 Hz, 2%), no grooming and no turning toward what the player watches, but every
-- `gap` seconds (after `after` seconds of standing, the first `firstWait` into it) one leg reaches out `out` studs and `lift` up and `along` along the body and
-- settles again over `seconds`. It keeps the first spider's alarm.
local tarantulaIdle: any = table.clone(first.idle)
tarantulaIdle.breathe = { period = 4.0, bodyLift = 0.004, lift = 0.010, pitchDeg = 1.6, scale = 0.02, movingShare = 0.35 }
tarantulaIdle.groom = nil
tarantulaIdle.attention = nil
tarantulaIdle.stretch = { after = 4.0, firstWait = { 2, 6 }, gap = { 10, 24 }, seconds = 3.0, out = 0.16, lift = 0.05, along = 0.16, kneeUp = 0.07 }

local function tarantula(o: any): any
	local apex = 0.285 + o.abdomenRadii[3] -- the abdomen's rear tip (its centre is at z = 0.285)
	local limbs = table.clone(first.limbs)
	limbs.hipX, limbs.hipZ, limbs.tipZ = 0.20, { -0.30, -0.20, -0.10, -0.01 }, { -0.76, -0.50, 0.10, 0.58 }
	limbs.thickness = o.legThickness
	limbs.stance = { x = 0.80, y = -0.22, reach = 0.92 } -- the body sits 0.09 under the collider's centre, so the rest foot spot is this far under it
	limbs.kneeLift, limbs.kneeLiftAir, limbs.ankleLift, limbs.pad = 0.22, 0.18, 0.04, 1.5
	local p = {
		id = o.id, name = o.name, pack = "tarantula_pack", gloss = o.gloss, legGloss = o.legGloss, outline = hex(0xE8E4DA),
		bodyDrop = 0.09, -- the drawn body sits this far (studs) under the collider's centre: low to the floor
		body = hex(o.core), legs = hex(o.leg), white = hex(o.palpBand), eyes = { 0.006, 0.006, 0.006 }, fangs = hex(o.fangs), joint = hex(o.leg),
		abdomenColor = hex(o.abdomen),
		palpColors = { stalk = hex(o.leg), club = hex(o.leg), tip = hex(o.palpTip) },
		legColors = { femur = hex(o.femur), tibia = hex(o.tibia), tarsus = hex(o.tarsus), knee = hex(o.knee), ankle = hex(o.ankle) },
		-- A broad low carapace: the dark core (Cephalothorax) with a wider, flatter rim under it (CarapaceRim, an extra) that shows round its edge.
		headCenter = { 0, 0, -0.18 }, headRadii = o.headRadii,
		abdomenCenter = { 0, 0.035, 0.285 }, abdomenRadii = o.abdomenRadii,
		pedicel = { center = { 0, -0.02, 0.04 }, radii = { 0.07, 0.06, 0.07 } },
		face = { center = { 0, -0.02, -0.36 }, radii = { 0.20, 0.09, 0.12 } },
		neck = { 0, 0, -0.04 },
		-- The ocular tubercle: a small mound on the carapace with eight tiny glossy eyes clustered on it. `eyes` are x (to the right), z (from
		-- the mound's centre) and the bead's radius, for the right side; the left is the mirror. The first of each side carries a catchlight.
		tubercle = {
			center = { 0, 0.125, -0.29 }, radii = { 0.085, 0.060, 0.075 }, color = hex(o.tubercle), reflectance = 0.12,
			eyes = { { x = 0.020, z = -0.040, r = 0.021 }, { x = 0.050, z = -0.022, r = 0.018 }, { x = 0.022, z = -0.008, r = 0.015 }, { x = 0.052, z = 0.016, r = 0.017 } },
			glint = { dx = 0.006, dy = 0.007, r = 0.0075 }, eyeReflectance = 0.5,
		},
		-- Thick, parallel, forward-and-down fangs (about 1.3 times the first spider's), set wide, not splayed.
		chelicerae = { x = 0.075, y = -0.10, z = -0.49, radii = { 0.065, 0.094, 0.058 }, pitch = 0.30, splay = 0, reflectance = 0.1 },
		eye = { glintColor = { 1, 1, 1 } },
		-- Leg-like pedipalps: about 1.45 times the first spider's palp in length, thick, with a patella band (the palp band is the `white`).
		palp = {
			x = 0.12, y = -0.03, drop = 0.147, reach = 0.152, spread = 0.049, stalk = 0.062, club = { 0.050, 0.048, 0.060 }, tipRadii = { 0.035, 0.030, 0.035 },
			fluff = { hairs = 0, length = 0, width = 0, flat = 1, transparency = 0 }, drumHz = 3.2, drumDeg = 13,
		},
		limbs = limbs,
		-- ROBLOX-84: the legs and palps are drawn as the segments a tarantula has (see `legForm` on the first spider). The femur tapers, the knee is
		-- a stout patella (the redknee's orange lives on it), the tarsus has a break (a ball on the rod, no second rod: the budget is 150 parts),
		-- and each foot is a broad, rounder scopula pad of dark velvet (ROBLOX-85: its bristles are the legs' own, on the tarsus, and the pad has none
		-- of its own). The palps, which are drawn 1.45 times as long, taper the same way.
		legForm = {
			femur = { split = 0.58, taper = 0.74 },
			patella = { length = 1.30, width = 1.20 },
			tarsus = { split = 0.55, joint = 1.20, bend = 0 },
			foot = { rx = 0.80, ry = 0.58, rz = 0.92 },
		},
		palpForm = { split = 0.58, taper = 0.78 },
		-- Larger fangs than the first spider's, one segment each, under the chelicerae and pointing forward (and a little down).
		fang = { x = 0.075, y = -0.175, z = -0.525, reflectance = 0.2, color = hex(0x2B1A12), segments = { { dir = { -0.04, -0.34, -0.94 }, length = 0.105, radius = 0.019 } } },
		frontLegScale = o.frontLegScale or 1.1, -- (the greenbottle's first legs are a tenth heavier again: ROBLOX-93)
		bandFraction = o.bandFraction,
		speckleCount = 0, spots = {}, band = { count = 0, step = 0.1, z = 0, rx = 0.01, rz = 0.01 }, speckle = { from = 0.4, step = 0.1, rx = 0.004, rz = 0.005 },
		-- Bodies in addition to the first spider's four: the rim, and two spinnerets of two segments behind the abdomen (the second segment is full
		-- detail only). `sweep` names the segment: the silk-mat pose (ROBLOX-82) swings them about the abdomen's rear.
		extras = {
			{ name = "CarapaceRim", center = { 0, -0.035 + o.rimUp, -0.18 }, radii = o.rimRadii, group = "head", color = hex(o.rim) },
			{ name = "Spinneret", center = { -0.045, 0.02, apex + 0.01 }, radii = { 0.022, 0.020, 0.055 }, group = "abdomen", color = hex(o.spinneret), sweep = 1 },
			{ name = "Spinneret", center = { 0.045, 0.02, apex + 0.01 }, radii = { 0.022, 0.020, 0.055 }, group = "abdomen", color = hex(o.spinneret), sweep = 1 },
			{ name = "SpinneretTip", center = { -0.045, 0.01, apex + 0.085 }, radii = { 0.016, 0.015, 0.045 }, group = "abdomen", color = hex(o.spinneret), sweep = 2, fullOnly = true },
			{ name = "SpinneretTip", center = { 0.045, 0.01, apex + 0.085 }, radii = { 0.016, 0.015, 0.045 }, group = "abdomen", color = hex(o.spinneret), sweep = 2, fullOnly = true },
		},
		marks = o.marks,
		-- The threat display and silk mat (Rig/TarantulaPose says how far and how fast; Data/Tarantula has the numbers): where legs I go when
		-- they are raised (body frame of the reared prosoma, studs, x mirrored for the left leg), how far the knee goes out and up, how much
		-- the raised feet tremble, how much farther the second spinneret segment swings than the first, and how far inside the abdomen's rear
		-- tip the spinnerets swing from. All ART.
		threat = { pair = 1, up = { x = 0.42, y = 0.28, z = -0.60 }, kneeOut = 0.10, kneeUp = 0.12, tremor = 0.015, tipSweep = 1.4, sweepBack = 0.05 },
		-- ROBLOX-85: a tarantula IS its velvet. A fur shell per body mass: a slightly larger, partly transparent copy of the carapace and of the abdomen
		-- in the Fabric material, in the colour of the fur (`velvet`; the head's shell stops short of the tubercle's eyes). `cluster` is the redknee's
		-- urticating patch drawn as a denser tuft of ginger-rust hairs. The bristles are the legs' fringe: short rods standing out from the sides of
		-- each segment and leaning toward the foot (`lift`: degrees off the leg; `edge`: where round the leg, degrees from the top), `legPairs` of
		-- them on the femur, tibia and tarsus of each pair of legs, the front pair's the most; full detail only. All ART.
		velvet = { head = { color = hex(o.velvetHead), scale = 1.07, transparency = o.velvetShade }, abdomen = { color = hex(o.velvetAbdomen), scale = 1.075, transparency = o.velvetShade } },
		cluster = o.cluster,
		fuzz = {
			enabled = true, legsOnly = true, legTone = "frost",
			black = { 0.03, 0.03, 0.03 }, dark = { 0.13, 0.13, 0.13 }, grey = { 0.5, 0.5, 0.48 }, frost = hex(o.bristle), shellColor = { 0.08, 0.08, 0.08 }, shells = {},
			legHairs = { 0, 0, 0 }, legPairs = o.legPairs, legLength = 0.080, legWidth = 0.009, legTransparency = 0.1, legBlack = 0,
			legLift = { 32, 48 }, legEdge = { 50, 115 }, legSpan = { 0.12, 0.74 },
		},
		idle = tarantulaIdle,
		hang = tarantulaHang,
		detail = {
			full = {
				every = { lock = 1, guard = 1, fringe = 1, pale = 1, tuft = 1, ruff = 1, palp = 1, leg = 1 },
				shells = 0, speckleEvery = 1, pads = true, sockets = false, idle = true, highlight = true,
				taper = true, jointBreak = true, fangSegments = 1, velvet = true, cluster = true,
			},
			low = {
				every = { lock = 0, guard = 0, fringe = 0, pale = 0, tuft = 0, ruff = 0, palp = 0, leg = 0 },
				shells = 0, speckleEvery = 1, pads = false, sockets = false, idle = false, highlight = false,
				fangSegments = 1, velvet = true, cluster = false,
			},
		},
	}
	return p
end

-- Brachypelma hamorii, the Mexican redknee: velvet black-brown with copper-orange on the carapace's rim, flame-orange patellae (the "knees"), a
-- warm pale-orange band on each tibia, dark feet, and a ginger-rust patch of urticating hair at the abdomen's dorsal rear. Stocky.
local redknee = tarantula({
	id = "brachypelma_hamorii", name = "Mexican redknee (Brachypelma hamorii)",
	core = 0x1A1614, rim = 0xD67638, tubercle = 0x1A1614, abdomen = 0x161312, spinneret = 0x1E1816, fangs = 0x1C1310,
	leg = 0x181413, femur = 0x0E0C0B, tibia = 0x181413, tarsus = 0x181413, knee = 0xEE5E22, ankle = 0x181413, palpBand = 0xEE5E22, palpTip = 0x181413,
	gloss = nil, legGloss = nil, legThickness = 1.12 * 1.35, bandFraction = 0.30,
	headRadii = { 0.285, 0.140, 0.270 }, rimRadii = { 0.335, 0.122, 0.318 }, rimUp = 0.018, -- the rim stands up a little round the carapace's edge (ROBLOX-85)
	abdomenRadii = { 0.290, 0.230, 0.320 },
	marks = {
		{ name = "UrticatingPatch", color = hex(0xBA5028), x = 0, z = 0.42, rx = 0.115, rz = 0.100, angle = 0, height = 0.012, raise = 0.014 }, -- stands out of the velvet shell, not under it
	} :: { any },
	-- Velvet black-brown shells; the legs' bristles a warm ginger-brown, thinner behind than before; the patch's hairs ginger-rust, a third paler.
	velvetHead = 0x2A211C, velvetAbdomen = 0x231B18, velvetShade = 0.45, bristle = 0xA8683C,
	legPairs = { { 3, 2, 1 }, { 2, 2, 0 }, { 1, 1, 0 }, { 1, 1, 0 } },
	cluster = { mark = "UrticatingPatch", hairs = 8, length = { 0.045, 0.065 }, lift = { 28, 42 }, yaw = 20, width = 0.009, flat = 0.9, transparency = 0.05, color = hex(0xB5532A), light = hex(0xD9803F), paler = 0.35 },
})
redknee.legBands = { tibia = hex(0xE08642) }

-- Chromatopelma cyaneopubescens, the Greenbottle blue: a teal-green carapace with a sheen and a lighter turquoise rim, deep metallic cobalt legs with
-- brighter azure joint rings and pale blue-white bristles, and a burnt-orange abdomen with a dark raised midline and four pairs of softened diagonal
-- bars. Sleeker than the redknee. The bars fade at the last growth stage (barFade), as a juvenile's pattern does. ROBLOX-85 darkened and
-- desaturated the legs from the first costume's pure cobalt (#204AA8) to #1E3F8F (Reflectance 0.10), greened the carapace, burnt the abdomen and
-- softened the bars (see ROBLOX-81 for the first palette and ROBLOX-85 for why).
local greenbottle = tarantula({
    id = "chromatopelma_cyaneopubescens", name = "Greenbottle blue (Chromatopelma cyaneopubescens)",
    core = 0x1E8062, rim = 0x2A9A7E, tubercle = 0x16285C, abdomen = 0xC4551C, spinneret = 0x3A2418, fangs = 0x308E94,
    leg = 0x1E3F8F, femur = 0x1E3F8F, tibia = 0x1E3F8F, tarsus = 0x1E3F8F, knee = 0x2E62C4, ankle = 0x2E62C4, palpBand = 0x2E62C4, palpTip = 0x2E62C4,
    gloss = 0.14, legGloss = 0.10, legThickness = 1.12 * 1.15, frontLegScale = 1.1 * 1.1, bandFraction = 0.24,
    headRadii = { 0.280, 0.120, 0.270 }, rimRadii = { 0.322, 0.105, 0.316 }, rimUp = 0.010,
    abdomenRadii = { 0.245, 0.195, 0.300 },
    marks = {
        -- The dark midline: three raised ridges along the back (thin rod-shaped ellipsoids), a little proud of the fur shell (the middle one alone at low detail), then
        -- four pairs of diagonal bars (x mirrored), a warm brown now and not near-black, so they are softer on the orange.
        { name = "AbdomenMidline", color = hex(0x2A1C18), x = 0, z = -0.48, rx = 0.0085, rz = 0.080, angle = 0, fullOnly = true, height = 0.010, raise = 0.0065 },
        { name = "AbdomenMidline", color = hex(0x2A1C18), x = 0, z = 0.0, rx = 0.0085, rz = 0.080, angle = 0, height = 0.010, raise = 0.0065 },
        { name = "AbdomenMidline", color = hex(0x2A1C18), x = 0, z = 0.48, rx = 0.0085, rz = 0.080, angle = 0, fullOnly = true, height = 0.010, raise = 0.0065 },
        { name = "AbdomenBar", color = hex(0x5A2A14), x = 0.50, z = -0.36, rx = 0.017, rz = 0.070, angle = 0.70, bar = true, mirror = true },
        { name = "AbdomenBar", color = hex(0x5A2A14), x = 0.54, z = -0.10, rx = 0.017, rz = 0.070, angle = 0.70, bar = true, mirror = true },
        { name = "AbdomenBar", color = hex(0x5A2A14), x = 0.52, z = 0.18, rx = 0.017, rz = 0.070, angle = 0.70, bar = true, mirror = true },
        { name = "AbdomenBar", color = hex(0x5A2A14), x = 0.44, z = 0.44, rx = 0.017, rz = 0.065, angle = 0.70, bar = true, mirror = true },
    } :: { any },
    -- Light-teal fuzz on the carapace, burnt-orange fuzz on the abdomen (the shells), and pale blue-white bristles on the legs (not the golden-tan
    -- of ROBLOX-81: the real animal's long leg hairs read pale blue).
    velvetHead = 0x35A07F, velvetAbdomen = 0xE0782C, velvetShade = 0.62, bristle = 0xC9DCF2,
    legPairs = { { 4, 3, 0 }, { 3, 2, 1 }, { 2, 1, 0 }, { 1, 1, 0 } },
    cluster = nil,
})
greenbottle.legBands = {} -- no pale bands on its legs: the joint rings are its markings
greenbottle.barFade = { 0, 0, 0, 0.6 } -- the bars' transparency at each growth stage: the juvenile pattern softens in the adult

-- The peacock spider, the ant-mimicking spider and the rival hang as the first spider does (the rival is a clone of it, as it is; the legs keep
-- their own lengths, so a small spider hangs as a small one).
volans.hang = first.hang
ant.hang = first.hang

return { default = "first_spider", profiles = { first_spider = first, maratus_volans_male = volans, myrmarachne_formicaria_female = ant, rival_spider = rival, brachypelma_hamorii = redknee, chromatopelma_cyaneopubescens = greenbottle } }

