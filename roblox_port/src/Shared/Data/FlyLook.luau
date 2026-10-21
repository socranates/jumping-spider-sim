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
		-- (ROBLOX-128: the head's, the thorax's rear and the abdomen's pairs gave their six parts to the wings' veins, which show far more at the spider's eye)
		{ from = { 0.047, 0.124, -0.022 }, to = { 0.066, 0.176, 0.011 }, mirror = true }, -- on the thorax's back
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
	-- (ROBLOX-128) the venation inside the leading vein, full tier only, at rest only (hidden in the blur): R4+5 out toward the tip, and M1+2 down the middle of the
	-- wing with the house fly's sharp bend up toward R4+5 near the margin (BugGuide's Musca note: "sharply bent vein M1+2 that almost touches vein R4+5 at the wing
	-- margin"). Each a rod on the wing's upper face from (x, z) to (x, z): x across the wing as a share of its half-width (+ toward the leading edge), z along it as a
	-- share of its length from the middle (+ toward the tip).
	veins = {
		diameter = 0.006, transparency = 0.35,
		items = {
			{ name = "VeinR45", from = { 0.05, -0.36 }, to = { 0.12, 0.47 } },
			{ name = "VeinM1", from = { -0.22, -0.30 }, to = { -0.30, 0.32 } },
			{ name = "VeinM2", from = { -0.30, 0.32 }, to = { 0.07, 0.465 } }, -- the bend
		},
	},
	film = { rise = 0.004, grow = 0.004, transparency = 0.82 },
	fan = {
		reach = 0.36, span = 0.34, roll = 8, yaw = 20, back = 0.02, rise = 0.01, transparency = 0.80, -- the denser blur near the root
		film = { reach = 0.56, span = 0.54, transparency = 0.92 }, -- the fainter blur out to the tips
		shimmer = { 19, 0.05 }, -- radians per second, radians: the fan trembles a little
	},
}

-- A soft dark oval on the surface under a standing fly stands in for its shadow (the parts cast none): size, how far above the surface.
FlyLook.shadow = { size = { 0.34, 0.004, 0.70 }, lift = 0.003, transparency = 0.78 }

-- ROBLOX-103 (W3c): how a body moves, pose only (Client/FlyBodies turns the parts it already has; nothing is added). Every sheet may carry a `motion` table;
-- the house fly's is this one. Lengths are in the body's own units (before the profile's visual_scale), angles radians, rates per second.
--   gait ...... the legs step while the body walks on a surface: each leg swings about its hip (`swing`, forward and back) and lifts its foot on the forward
--               stroke (`lift`); a full cycle per `stride` of ground covered, so a slow walker steps slowly and a still one does not step at all. Six legs go
--               in two tripods (front and hind of one side with the middle of the other); `wave` (the woodlouse's) is a metachronal wave instead, each
--               pair `wave` behind the one in front. `settle`: how fast the stepping fades in and out (1/s). `jump`: a move longer than this between two
--               drawings is a hop or a teleport, not a step.
--   kick ...... in the jaws the legs kick at this rate (Hz).
--   antenna ... the antennae sway a little about their bases (`amp`, at `hz`).
--   flap ...... wings that beat visibly (the moth's): the flight fans swing up and down about their roots at `hz`, `amp` either side; without it the fans are
--               the fly's soft blur that trembles (FlyLook.wing.fan.shimmer).
--   resettle .. after landing the resting wings shiver for `seconds`, dying away (the moth settling its wings).
--   wobble .... the body rocks in flight (`roll`, `pitch` at `hz`: the crane fly's unsteady flight); `dangle`: its hanging legs swing fore and aft.
--   crouch .... a hopper about to leap (startled, its reaction pending) sinks `depth` and tips `pitch` (nose up for the leafhopper's hind-leg spring).
--   tumble .... turns end over end in a hop (the springtail's somersault), this many turns per hop.
-- Reduced Motion (the player's setting, as the spider's rig reads it) keeps the stepping, which is how a body gets anywhere, and stills the rest: no sway,
-- no trembling or beating fan (a still blur), no shiver, no rocking, no crouch, no somersault.
--   groom ..... (ROBLOX-128) standing calm and still, it grooms in bouts: after `after` seconds and then every `every` (each wait drawn from a hash of the body's id
--               and the bout's number, never math.random), a bout of `bout` seconds: the front legs drawn in under the head and rubbed together, or the hind
--               legs drawn back under the abdomen's tip and rubbed together (the drawing's short legs cannot sweep over the wings), the front first (Seeds et al. 2014, eLife 3:e02951: the front legs clean the head, the
--               hind legs the abdomen and wings, rubbing bouts between; the order of priority front to back). `hz` the rub. A walk, a flight, an alarm or a
--               scheduled take-off ends a bout at once. The timing is the game's.
--   ready ..... (ROBLOX-128) a take-off scheduled (its reaction pending), it readies: the body raised `lift` on its legs and tipped `pitch` nose up, the middle legs
--               swung forward `legs` (Card & Dickinson 2008, Current Biology: a fly sets its middle legs and leans in the 100 ms or so before its escape jump).
FlyLook.groom = { after = { 2.5, 5 }, every = { 3, 7 }, bout = { 1.2, 2.4 }, hz = 5, amp = 0.16 }
FlyLook.ready = { lift = 0.03, pitch = 0.16, legs = 0.35 }
FlyLook.motion = { gait = { stride = 0.36, swing = 0.30, lift = 0.32, settle = 9, jump = 0.6 }, kick = 6, groom = FlyLook.groom, ready = FlyLook.ready }
-- (ROBLOX-128) The fastest wingbeat drawn as a beat: a fly's wings beat 190 to 330 times a second, a mosquito's 600 and some midges' 1,000 (hypertextbook's
-- table of wingbeat frequencies, after Chapman and Wigglesworth), and at 60 frames a second anything over half that, 30 Hz, steps backward or stands still on the
-- screen (it strobes). A sheet's `flap` above BLUR_HZ is drawn as the blur that trembles (FlyLook.wing.fan.shimmer), as the house fly's always was; the moth's 5 Hz
-- is drawn as a beat.
FlyLook.BLUR_HZ = 12
-- ROBLOX-114 (everything to scale): the scale a prey is drawn at. A profile's `visual_scale` is Godot's (golden, never changed here); a kind listed in `trueScale`
-- is drawn at that instead, because the golden one draws it at a size it is not: the fruit fly at 0.6 is the house fly's 7.3 mm body made 4.4 mm, and Drosophila
-- melanogaster is about 2.5 mm long (BioNumbers 100750), so it is drawn at 0.4, 2.9 mm. Only the drawing: its collider, its senses and its meal are the profile's.
FlyLook.trueScale = { fruit_fly = 0.4 } :: { [string]: number }
function FlyLook.drawnScale(profile: any): number
	if profile == nil then return 1 end
	local kind = profile.body.prey_kind
	return (if kind ~= nil then FlyLook.trueScale[kind] else nil) or profile.body.visual_scale or 1
end

-- The far rule (as the rival's and the mate's rigs, Rig/SpiderRig FAR_STUDS and FAR_SECONDS): a body farther than `studs` from the camera is drawn once every
-- `seconds` with all the time since; the simulation steps it every tick regardless.
FlyLook.far = { studs = 25, seconds = 0.1 }

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
		motion = { gait = { stride = 0.42, swing = 0.32, lift = 0.30, settle = 9, jump = 0.6 }, kick = 7, antenna = { amp = 0.14, hz = 1.6 }, groom = FlyLook.groom, ready = FlyLook.ready },
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
		motion = { gait = { stride = 0.3, swing = 0.28, lift = 0.30, settle = 9, jump = 0.6 }, kick = 4, antenna = { amp = 0.12, hz = 0.9 } },
	},
} :: { [string]: any }

-- ROBLOX-101 (W3b part A): the bestiary's four, drawn at their true sizes (visual_scale 1: the springtail 0.15 long, the leafhopper 0.4, the moth 0.8 with wings
-- about 1.5 across, the crane fly about 1.9 with legs near 4), on the same plan with three more words: an item marked `full` is drawn only at the full detail
-- tier, one marked `low` only at the low tier (the crane fly's legs there are one rod each, hip to foot); `wings` is a list of pairs (each mirrored; `hide`: drawn
-- at rest only, as the moth's dark bands; `material`, `color` per pair); `shed` names the leg a crane fly leaves behind (the parts whose names begin with it are
-- not drawn once it has). Colours from the field guides' descriptions the pages cite (docs/NOTEBOOK_SOURCES.md): a grey-blue soil springtail, a green
-- leafhopper, a mottled grey-brown moth, a grey-brown crane fly with smoky wings.
FlyLook.small.springtail = {
	colors = { body = "5b6170", abdomen = "666c7a", head = "555a68", eye = "1c1d22", leg = "8a8f99", antenna = "4d525e", furcula = "9a9fa8", shadow = "2a241c" },
	body = {
		{ name = "Thorax", color = "body", at = { 0, -0.11, -0.02 }, size = { 0.04, 0.035, 0.06 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, -0.112, 0.04 }, size = { 0.045, 0.04, 0.08 } },
		{ name = "Head", color = "head", at = { 0, -0.11, -0.065 }, size = { 0.035, 0.03, 0.032 } },
		{ name = "EyeL", color = "eye", at = { -0.014, -0.1, -0.07 }, size = { 0.012, 0.012, 0.012 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.014, -0.1, -0.07 }, size = { 0.012, 0.012, 0.012 }, full = true },
	} :: { any },
	rods = {
		{ name = "Antenna", color = "antenna", d = 0.006, from = { 0.008, -0.1, -0.078 }, to = { 0.03, -0.085, -0.13 }, mirror = true },
		{ name = "FrontLeg", color = "leg", d = 0.006, from = { 0.015, -0.12, -0.035 }, to = { 0.035, -0.16, -0.05 }, mirror = true },
		{ name = "MiddleLeg", color = "leg", d = 0.006, from = { 0.018, -0.12, -0.01 }, to = { 0.04, -0.16, -0.005 }, mirror = true },
		{ name = "HindLeg", color = "leg", d = 0.006, from = { 0.018, -0.12, 0.015 }, to = { 0.04, -0.16, 0.03 }, mirror = true },
		-- the furcula, the spring: folded forward under the abdomen at rest, swung down and back in the leap
		{ name = "Furcula", color = "furcula", d = 0.008, from = { 0, -0.13, 0.075 }, to = { 0, -0.135, 0.02 }, fly = { { 0, -0.13, 0.075 }, { 0, -0.17, 0.13 } }, full = true },
	} :: { any },
	shadow = { size = { 0.05, 0.004, 0.14 }, lift = 0.003, transparency = 0.8, full = true },
	-- (ROBLOX-103) quick little steps, a crouch before the spring and a somersault in the air (springtails tumble as they go)
	motion = { gait = { stride = 0.07, swing = 0.35, lift = 0.35, settle = 12, jump = 0.4 }, kick = 8, antenna = { amp = 0.16, hz = 2.2 },
		crouch = { depth = 0.012, pitch = -0.12 }, tumble = 1 },
}
FlyLook.small.leafhopper = {
	colors = { head = "7cb342", eye = "6b5a3a", pronotum = "6fae3c", scutellum = "8bc34a", abdomen = "9ccc65", wing = "6aa636", leg = "8fbf5a", spine = "d6e8b0", antenna = "5e8f30", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, -0.065, -0.16 }, size = { 0.11, 0.05, 0.06 } },
		{ name = "EyeL", color = "eye", at = { -0.05, -0.055, -0.155 }, size = { 0.03, 0.035, 0.035 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.05, -0.055, -0.155 }, size = { 0.03, 0.035, 0.035 }, full = true },
		{ name = "Pronotum", color = "pronotum", at = { 0, -0.05, -0.11 }, size = { 0.11, 0.05, 0.07 } },
		{ name = "Scutellum", color = "scutellum", at = { 0, -0.045, -0.065 }, size = { 0.06, 0.03, 0.05 }, full = true },
		{ name = "Abdomen", color = "abdomen", at = { 0, -0.075, 0.02 }, size = { 0.08, 0.055, 0.2 } },
	} :: { any },
	rods = {
		{ name = "FrontFemur", color = "leg", d = 0.016, from = { 0.03, -0.09, -0.1 }, to = { 0.07, -0.08, -0.13 }, fly = { { 0.03, -0.09, -0.1 }, { 0.04, -0.12, -0.13 } }, mirror = true },
		{ name = "FrontTibia", color = "leg", d = 0.012, from = { 0.07, -0.08, -0.13 }, to = { 0.08, -0.16, -0.15 }, fly = { { 0.04, -0.12, -0.13 }, { 0.04, -0.15, -0.1 } }, mirror = true, full = true },
		{ name = "MiddleFemur", color = "leg", d = 0.016, from = { 0.035, -0.09, -0.06 }, to = { 0.08, -0.08, -0.05 }, fly = { { 0.035, -0.09, -0.06 }, { 0.05, -0.12, -0.05 } }, mirror = true },
		{ name = "MiddleTibia", color = "leg", d = 0.012, from = { 0.08, -0.08, -0.05 }, to = { 0.1, -0.16, -0.04 }, fly = { { 0.05, -0.12, -0.05 }, { 0.05, -0.15, -0.01 } }, mirror = true, full = true },
		{ name = "HindFemur", color = "leg", d = 0.016, from = { 0.035, -0.09, -0.02 }, to = { 0.1, -0.07, 0.02 }, fly = { { 0.035, -0.09, -0.02 }, { 0.06, -0.11, 0.04 } }, mirror = true },
		{ name = "HindTibia", color = "leg", d = 0.012, from = { 0.1, -0.07, 0.02 }, to = { 0.11, -0.16, 0.14 }, fly = { { 0.06, -0.11, 0.04 }, { 0.05, -0.12, 0.2 } }, mirror = true },
		-- the rows of spines along the hind tibiae, a pale line beside each
		{ name = "Spines", color = "spine", d = 0.008, from = { 0.112, -0.075, 0.03 }, to = { 0.122, -0.15, 0.13 }, fly = { { 0.064, -0.105, 0.05 }, { 0.056, -0.115, 0.19 } }, mirror = true, full = true },
		{ name = "Antenna", color = "antenna", d = 0.005, from = { 0.025, -0.06, -0.19 }, to = { 0.04, -0.05, -0.22 }, mirror = true, full = true },
	} :: { any },
	-- the forewings held over the back like a roof, opaque green; a blur of a fan in flight
	wings = {
		{ name = "Wing", color = "wing", material = "SmoothPlastic", root = { 0.02, -0.03, -0.08 }, length = 0.3, width = 0.09, thick = 0.012, yaw = 4, pitch = -6, roll = 35,
			transparency = 0, reflectance = 0.05, fan = { reach = 0.24, span = 0.2, roll = 8, yaw = 20, back = 0.02, rise = 0.01, transparency = 0.7 } },
	} :: { any },
	shadow = { size = { 0.14, 0.004, 0.36 }, lift = 0.003, transparency = 0.8, full = true },
	-- (ROBLOX-103) it sidesteps round its stem on these legs, and sinks and tips its nose up on its hind legs before the jump
	motion = { gait = { stride = 0.14, swing = 0.30, lift = 0.30, settle = 10, jump = 0.6 }, kick = 6, antenna = { amp = 0.10, hz = 1.2 },
		crouch = { depth = 0.03, pitch = 0.18 } },
}
FlyLook.small.moth = {
	colors = { head = "7a6e5c", eye = "2a2018", thorax = "7a6e5c", abdomen = "8a7f6c", forewing = "8c8170", hindwing = "a39a88", band = "4f4639", antenna = "5e5446", leg = "6b604f", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, -0.04, -0.36 }, size = { 0.12, 0.11, 0.1 } },
		{ name = "EyeL", color = "eye", at = { -0.05, -0.035, -0.37 }, size = { 0.06, 0.07, 0.06 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.05, -0.035, -0.37 }, size = { 0.06, 0.07, 0.06 }, full = true },
		{ name = "Thorax", color = "thorax", at = { 0, -0.03, -0.22 }, size = { 0.18, 0.15, 0.22 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, -0.05, 0.1 }, size = { 0.13, 0.11, 0.5 } },
	} :: { any },
	rods = {
		{ name = "Antenna", color = "antenna", d = 0.012, from = { 0.03, 0.0, -0.4 }, to = { 0.22, 0.0, -0.55 }, mirror = true },
		{ name = "FrontLeg", color = "leg", d = 0.02, from = { 0.05, -0.08, -0.27 }, to = { 0.13, -0.16, -0.34 }, fly = { { 0.05, -0.08, -0.27 }, { 0.07, -0.16, -0.3 } }, mirror = true, full = true },
		{ name = "MiddleLeg", color = "leg", d = 0.02, from = { 0.06, -0.08, -0.2 }, to = { 0.16, -0.16, -0.18 }, fly = { { 0.06, -0.08, -0.2 }, { 0.08, -0.17, -0.15 } }, mirror = true, full = true },
		{ name = "HindLeg", color = "leg", d = 0.02, from = { 0.05, -0.08, -0.13 }, to = { 0.15, -0.16, -0.03 }, fly = { { 0.05, -0.08, -0.13 }, { 0.07, -0.17, -0.02 } }, mirror = true, full = true },
	} :: { any },
	-- at rest the four wings lie flat and spread (the forewings out to the sides, the hindwings behind and under them, a dark band across each forewing); in
	-- flight each is a blurred fan
	wings = {
		{ name = "Forewing", color = "forewing", material = "SmoothPlastic", root = { 0.06, 0.0, -0.24 }, length = 0.74, width = 0.42, thick = 0.01, yaw = 70, pitch = -3, roll = 0,
			transparency = 0, reflectance = 0, fan = { reach = 0.7, span = 0.5, roll = 10, yaw = 70, back = 0.0, rise = 0.02, transparency = 0.55 } },
		{ name = "Hindwing", color = "hindwing", material = "SmoothPlastic", root = { 0.05, -0.008, -0.12 }, length = 0.55, width = 0.4, thick = 0.01, yaw = 40, pitch = -3, roll = 0,
			transparency = 0, reflectance = 0, fan = { reach = 0.55, span = 0.42, roll = 10, yaw = 35, back = 0.05, rise = 0.01, transparency = 0.6 } },
		{ name = "Band", color = "band", material = "SmoothPlastic", root = { 0.341, 0.004, -0.138 }, length = 0.2, width = 0.4, thick = 0.006, yaw = 70, pitch = -3, roll = 0,
			transparency = 0, reflectance = 0, hide = true, full = true },
	} :: { any },
	shadow = { size = { 1.3, 0.004, 0.6 }, lift = 0.003, transparency = 0.82, full = true },
	-- (ROBLOX-103) a slow, visible flap in the air; on landing the wings shiver and settle flat
	motion = { gait = { stride = 0.28, swing = 0.25, lift = 0.25, settle = 8, jump = 0.6 }, kick = 5, antenna = { amp = 0.08, hz = 0.7 },
		flap = { hz = 5, amp = 0.75 }, resettle = { seconds = 0.9, hz = 6, amp = 0.32 } },
}
-- ROBLOX-117: the hoverfly (Syrphidae) of the hut garden's flowers, drawn at its true size (about 1 cm long, as the spider): a fly dressed as a bee, its abdomen banded
-- black and yellow, big red-brown eyes, short antennae and one pair of clear wings (docs/NOTEBOOK_SOURCES.md, the hoverflies' page), the wings a blur in its hover.
FlyLook.small.hoverfly = {
	colors = { head = "2a2620", eye = "8a3a24", thorax = "3a3326", yellow = "e0b62a", black = "1f1c18", wing = "d8dde0", leg = "5a4a2e", antenna = "3a3020", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, 0.0, -0.4 }, size = { 0.2, 0.16, 0.12 } },
		{ name = "EyeL", color = "eye", at = { -0.07, 0.01, -0.41 }, size = { 0.1, 0.14, 0.1 } },
		{ name = "EyeR", color = "eye", at = { 0.07, 0.01, -0.41 }, size = { 0.1, 0.14, 0.1 } },
		{ name = "Thorax", color = "thorax", at = { 0, 0.02, -0.22 }, size = { 0.22, 0.2, 0.26 } },
		{ name = "Abdomen", color = "black", at = { 0, -0.01, 0.12 }, size = { 0.24, 0.1, 0.48 } },
		{ name = "Band1", color = "yellow", at = { 0, -0.008, -0.01 }, size = { 0.252, 0.106, 0.07 }, full = true },
		{ name = "Band2", color = "yellow", at = { 0, -0.008, 0.11 }, size = { 0.252, 0.106, 0.075 } },
		{ name = "Band3", color = "yellow", at = { 0, -0.008, 0.24 }, size = { 0.22, 0.09, 0.06 }, full = true },
	} :: { any },
	rods = {
		{ name = "Antenna", color = "antenna", d = 0.012, from = { 0.02, 0.03, -0.46 }, to = { 0.04, 0.06, -0.52 }, mirror = true, full = true },
		{ name = "FrontLeg", color = "leg", d = 0.018, from = { 0.05, -0.06, -0.27 }, to = { 0.12, -0.13, -0.33 }, fly = { { 0.05, -0.06, -0.27 }, { 0.06, -0.15, -0.25 } }, mirror = true, full = true },
		{ name = "MiddleLeg", color = "leg", d = 0.018, from = { 0.06, -0.06, -0.2 }, to = { 0.15, -0.13, -0.17 }, fly = { { 0.06, -0.06, -0.2 }, { 0.07, -0.16, -0.16 } }, mirror = true, full = true },
		{ name = "HindLeg", color = "leg", d = 0.018, from = { 0.05, -0.06, -0.12 }, to = { 0.14, -0.13, -0.02 }, fly = { { 0.05, -0.06, -0.12 }, { 0.06, -0.16, -0.05 } }, mirror = true },
	} :: { any },
	-- one pair of clear wings, held out over the abdomen at rest; a blur in the hover
	wings = {
		{ name = "Wing", color = "wing", material = "Glass", root = { 0.06, 0.07, -0.24 }, length = 0.62, width = 0.2, thick = 0.008, yaw = 28, pitch = 2, roll = 0,
			transparency = 0.5, reflectance = 0.08, fan = { reach = 0.55, span = 0.4, roll = 6, yaw = 30, back = 0.02, rise = 0.02, transparency = 0.82 } },
	} :: { any },
	shadow = { size = { 0.4, 0.004, 0.9 }, lift = 0.003, transparency = 0.82, full = true },
	motion = { gait = { stride = 0.25, swing = 0.25, lift = 0.25, settle = 10, jump = 0.6 }, kick = 6, antenna = { amp = 0.06, hz = 1.0 }, flap = { hz = 30, amp = 0.4 }, groom = FlyLook.groom, ready = FlyLook.ready },
}
-- (the crane fly's legs: hip, knee, ankle and foot of the right front, middle and hind leg, standing splayed and dangling in flight)
local craneLegs = {
	{ name = "Front", stand = { { 0.1, 0.08, -0.5 }, { 0.55, 0.75, -1.1 }, { 0.95, 0.25, -1.9 }, { 1.3, -0.16, -3.5 } }, fly = { { 0.1, 0.08, -0.5 }, { 0.35, -0.3, -0.4 }, { 0.5, -1.25, -0.1 }, { 0.6, -2.4, 0.3 } } },
	{ name = "Middle", stand = { { 0.12, 0.06, -0.38 }, { 0.95, 0.75, -0.45 }, { 1.85, 0.25, -0.4 }, { 3.0, -0.16, -0.3 } }, fly = { { 0.12, 0.06, -0.38 }, { 0.4, -0.3, -0.25 }, { 0.55, -1.25, 0.1 }, { 0.65, -2.4, 0.5 } } },
	{ name = "Hind", stand = { { 0.1, 0.06, -0.25 }, { 0.75, 0.75, 0.4 }, { 1.35, 0.25, 1.4 }, { 1.9, -0.16, 2.7 } }, fly = { { 0.1, 0.06, -0.25 }, { 0.35, -0.3, -0.05 }, { 0.5, -1.25, 0.35 }, { 0.6, -2.4, 0.8 } } },
}
local craneRods: { any } = {
	{ name = "Antenna", color = "antenna", d = 0.015, from = { 0.03, 0.17, -0.68 }, to = { 0.1, 0.22, -0.95 }, mirror = true, full = true },
	{ name = "Haltere", color = "haltere", d = 0.03, from = { 0.08, 0.25, -0.22 }, to = { 0.18, 0.28, -0.1 }, mirror = true, full = true },
}
for _, leg in craneLegs do
	local st, fl = leg.stand, leg.fly
	table.insert(craneRods, { name = leg.name .. "Femur", color = "leg", d = 0.03, from = st[1], to = st[2], fly = { fl[1], fl[2] }, mirror = true, full = true })
	table.insert(craneRods, { name = leg.name .. "Tibia", color = "leg", d = 0.022, from = st[2], to = st[3], fly = { fl[2], fl[3] }, mirror = true, full = true })
	table.insert(craneRods, { name = leg.name .. "Tarsus", color = "tarsus", d = 0.016, from = st[3], to = st[4], fly = { fl[3], fl[4] }, mirror = true, full = true })
	table.insert(craneRods, { name = leg.name .. "Leg", color = "leg", d = 0.026, from = st[1], to = st[4], fly = { fl[1], fl[4] }, mirror = true, low = true })
end
FlyLook.small.crane_fly = {
	colors = { head = "6f6350", rostrum = "5f5444", eye = "2b2b2b", thorax = "7c705c", abdomen = "8a7a5a", wing = "c8c3b4", haltere = "b5a98e", antenna = "5a4e3e",
		leg = "5a4e3e", tarsus = "4a4033", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, 0.15, -0.62 }, size = { 0.14, 0.14, 0.14 } },
		{ name = "Rostrum", color = "rostrum", at = { 0, 0.12, -0.73 }, size = { 0.07, 0.07, 0.14 }, full = true },
		{ name = "EyeL", color = "eye", at = { -0.06, 0.16, -0.62 }, size = { 0.07, 0.09, 0.09 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.06, 0.16, -0.62 }, size = { 0.07, 0.09, 0.09 }, full = true },
		{ name = "Thorax", color = "thorax", at = { 0, 0.18, -0.38 }, size = { 0.3, 0.32, 0.42 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, 0.13, 0.42 }, size = { 0.17, 0.17, 1.25 } },
	} :: { any },
	rods = craneRods,
	-- one pair of long narrow smoky wings, held out in a V at rest
	wings = {
		{ name = "Wing", color = "wing", material = "Glass", root = { 0.1, 0.3, -0.4 }, length = 1.25, width = 0.22, thick = 0.008, yaw = 40, pitch = 2, roll = 0,
			transparency = 0.45, reflectance = 0.06, fan = { reach = 1.0, span = 0.5, roll = 8, yaw = 10, back = 0.02, rise = 0.01, transparency = 0.8 } },
	} :: { any },
	shadow = { size = { 0.4, 0.004, 1.8 }, lift = 0.003, transparency = 0.82, full = true },
	shed = "RightHind", -- the leg left in the jaws (ROBLOX-101): the right hind leg's parts, at either tier
	-- (ROBLOX-103) long slow steps on its stilts; in the air it rocks and its legs dangle and swing
	motion = { gait = { stride = 1.3, swing = 0.14, lift = 0.12, settle = 6, jump = 1.0 }, kick = 4, antenna = { amp = 0.10, hz = 1.1 },
		wobble = { roll = 0.14, pitch = 0.08, hz = 2.1 }, dangle = { amp = 0.18, hz = 1.7 } },
}

-- ROBLOX-120: the fall field cricket (Gryllus pennsylvanicus) of the meadow's thatch and the hut garden's mulch, drawn at its true size (about 2.2 cm, the sources' 15 to
-- 25 mm): shiny black to dark brown, a big round head, the saddle of its pronotum, its forewings lying flat over the abdomen, two cerci at the tail, antennae longer
-- than the body, thin front and middle legs and the stout, long hind legs it jumps and kicks with (docs/NOTEBOOK_SOURCES.md, the field cricket's page).
FlyLook.small.cricket = {
	colors = { head = "1c1714", eye = "0b0908", pronotum = "221c18", abdomen = "2a221c", tegmen = "2e241c", leg = "2e2620", femur = "3a2f26", antenna = "2a231d",
		cercus = "3a3028", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, 0.22, -0.85 }, size = { 0.5, 0.48, 0.45 } },
		{ name = "EyeL", color = "eye", reflectance = 0.06, at = { -0.2, 0.32, -0.92 }, size = { 0.14, 0.16, 0.14 }, full = true },
		{ name = "EyeR", color = "eye", reflectance = 0.06, at = { 0.2, 0.32, -0.92 }, size = { 0.14, 0.16, 0.14 }, full = true },
		{ name = "Pronotum", color = "pronotum", at = { 0, 0.26, -0.52 }, size = { 0.6, 0.42, 0.38 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, 0.18, 0.25 }, size = { 0.6, 0.38, 1.2 } },
		{ name = "Forewings", color = "tegmen", at = { 0, 0.35, 0.12 }, size = { 0.58, 0.1, 1.0 }, full = true, hinge = { 0, 0.33, -0.36 } },
	} :: { any },
	rods = {
		{ name = "Antenna", color = "antenna", d = 0.025, from = { 0.08, 0.36, -1.05 }, to = { 0.75, 0.42, -2.7 }, mirror = true },
		{ name = "Cercus", color = "cercus", d = 0.04, from = { 0.1, 0.2, 0.82 }, to = { 0.24, 0.24, 1.38 }, mirror = true, full = true },
		{ name = "FrontFemur", color = "leg", d = 0.06, from = { 0.18, 0.1, -0.62 }, to = { 0.36, 0.12, -0.86 }, fly = { { 0.18, 0.1, -0.62 }, { 0.26, 0.0, -0.8 } }, mirror = true },
		{ name = "FrontTibia", color = "leg", d = 0.045, from = { 0.36, 0.12, -0.86 }, to = { 0.45, -0.16, -1.02 }, fly = { { 0.26, 0.0, -0.8 }, { 0.24, -0.1, -0.6 } }, mirror = true, full = true },
		{ name = "MiddleFemur", color = "leg", d = 0.06, from = { 0.24, 0.1, -0.36 }, to = { 0.5, 0.12, -0.3 }, fly = { { 0.24, 0.1, -0.36 }, { 0.36, 0.0, -0.25 } }, mirror = true },
		{ name = "MiddleTibia", color = "leg", d = 0.045, from = { 0.5, 0.12, -0.3 }, to = { 0.64, -0.16, -0.24 }, fly = { { 0.36, 0.0, -0.25 }, { 0.32, -0.08, -0.05 } }, mirror = true, full = true },
		-- the hind legs: a stout femur up along the abdomen's side, the tibia folded back under it to the foot
		{ name = "HindFemur", color = "femur", d = 0.17, from = { 0.24, 0.14, -0.02 }, to = { 0.42, 0.44, 0.74 }, fly = { { 0.24, 0.14, -0.02 }, { 0.36, 0.2, 0.8 } }, mirror = true },
		{ name = "HindTibia", color = "leg", d = 0.07, from = { 0.42, 0.44, 0.74 }, to = { 0.38, -0.16, 1.24 }, fly = { { 0.36, 0.2, 0.8 }, { 0.36, -0.05, 1.5 } }, mirror = true },
	} :: { any },
	shadow = { size = { 0.8, 0.004, 2.0 }, lift = 0.003, transparency = 0.8, full = true },
	-- quick bursts of steps, a crouch on its hind legs before the jump, the antennae always moving
	motion = { gait = { stride = 0.5, swing = 0.3, lift = 0.3, settle = 9, jump = 1.0 }, kick = 7, antenna = { amp = 0.18, hz = 1.3 },
		crouch = { depth = 0.06, pitch = 0.16 },
		-- (ROBLOX-128) singing (Prey/PreyKinds.chirping), a male raises his forewings over the abdomen to about 45 degrees (`raise`) and closes them a little in each
		-- chirp, a scraper on one wing drawn over the file on the other, a pulse a closing stroke (UF/IFAS's field crickets, EENY/IN222). The game's sound is five chirps
		-- of four pulses in 2 s, so a chirp every `period` s lasting `chirp` s; the pulses themselves are too quick to draw, so the wings dip by `dip` through each chirp.
		sing = { raise = 0.75, period = 0.4, chirp = 0.18, dip = 0.12, ease = 6 } },
}

-- ROBLOX-122: the pond's prey, drawn at their true sizes (docs/NOTEBOOK_SOURCES.md, their pages). A non-biting midge (Chironomidae): about 5.5 mm, a slender pale
-- green body, a humped thorax, the male's feathery antennae, long front legs held up in front, one pair of clear wings shorter than the abdomen.
FlyLook.small.midge = {
	colors = { thorax = "7a8a5a", abdomen = "8a9a62", head = "5a6a44", eye = "1a1a14", leg = "6a7450", antenna = "8a8a6a", plume = "b8b89a", wing = "dfe4e6", shadow = "2a241c" },
	body = {
		{ name = "Thorax", color = "thorax", at = { 0, 0.0, -0.1 }, size = { 0.11, 0.12, 0.15 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, -0.02, 0.12 }, size = { 0.055, 0.055, 0.34 } },
		{ name = "Head", color = "head", at = { 0, -0.01, -0.2 }, size = { 0.06, 0.06, 0.05 } },
		{ name = "EyeL", color = "eye", at = { -0.028, 0.0, -0.205 }, size = { 0.03, 0.04, 0.03 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.028, 0.0, -0.205 }, size = { 0.03, 0.04, 0.03 }, full = true },
		{ name = "PlumeL", color = "plume", at = { -0.05, 0.03, -0.27 }, size = { 0.07, 0.07, 0.1 }, full = true },
		{ name = "PlumeR", color = "plume", at = { 0.05, 0.03, -0.27 }, size = { 0.07, 0.07, 0.1 }, full = true },
	} :: { any },
	rods = {
		{ name = "Antenna", color = "antenna", d = 0.008, from = { 0.015, 0.0, -0.22 }, to = { 0.05, 0.04, -0.32 }, mirror = true },
		-- the long front legs held up and forward, the others splayed
		{ name = "FrontLeg", color = "leg", d = 0.008, from = { 0.03, -0.04, -0.13 }, to = { 0.08, 0.06, -0.36 }, fly = { { 0.03, -0.04, -0.13 }, { 0.05, -0.14, -0.2 } }, mirror = true },
		{ name = "MiddleFemur", color = "leg", d = 0.008, from = { 0.035, -0.04, -0.08 }, to = { 0.14, 0.03, -0.06 }, fly = { { 0.035, -0.04, -0.08 }, { 0.06, -0.1, -0.05 } }, mirror = true },
		{ name = "MiddleTibia", color = "leg", d = 0.006, from = { 0.14, 0.03, -0.06 }, to = { 0.24, -0.16, -0.04 }, fly = { { 0.06, -0.1, -0.05 }, { 0.05, -0.2, 0.02 } }, mirror = true, full = true },
		{ name = "HindFemur", color = "leg", d = 0.008, from = { 0.03, -0.04, -0.04 }, to = { 0.13, 0.04, 0.06 }, fly = { { 0.03, -0.04, -0.04 }, { 0.05, -0.1, 0.06 } }, mirror = true },
		{ name = "HindTibia", color = "leg", d = 0.006, from = { 0.13, 0.04, 0.06 }, to = { 0.22, -0.16, 0.16 }, fly = { { 0.05, -0.1, 0.06 }, { 0.04, -0.2, 0.16 } }, mirror = true, full = true },
	} :: { any },
	wings = {
		{ name = "Wing", color = "wing", material = "Glass", root = { 0.03, 0.05, -0.1 }, length = 0.28, width = 0.08, thick = 0.004, yaw = 20, pitch = 2, roll = 0,
			transparency = 0.55, reflectance = 0.08, fan = { reach = 0.24, span = 0.2, roll = 6, yaw = 25, back = 0.02, rise = 0.01, transparency = 0.85 } },
	} :: { any },
	shadow = { size = { 0.14, 0.004, 0.4 }, lift = 0.003, transparency = 0.82, full = true },
	motion = { gait = { stride = 0.18, swing = 0.3, lift = 0.3, settle = 10, jump = 0.6 }, kick = 6, antenna = { amp = 0.1, hz = 1.4 }, flap = { hz = 40, amp = 0.35 }, groom = FlyLook.groom, ready = FlyLook.ready },
}
-- A mosquito (Culicidae): about 5 mm of body, a brown-grey thorax and a banded abdomen, a long straight proboscis, long thin legs, one pair of scaled wings laid
-- over the back.
FlyLook.small.mosquito = {
	colors = { thorax = "5a5248", abdomen = "4a443c", band = "a8a090", head = "3a342e", eye = "141210", leg = "4a4440", proboscis = "2e2a26", antenna = "4a4440", wing = "c8c4bc", shadow = "2a241c" },
	body = {
		{ name = "Thorax", color = "thorax", at = { 0, 0.02, -0.08 }, size = { 0.1, 0.11, 0.14 } },
		{ name = "Abdomen", color = "abdomen", at = { 0, 0.0, 0.14 }, size = { 0.06, 0.055, 0.32 } },
		{ name = "Band1", color = "band", at = { 0, 0.0, 0.08 }, size = { 0.064, 0.058, 0.025 }, full = true },
		{ name = "Band2", color = "band", at = { 0, 0.0, 0.16 }, size = { 0.062, 0.056, 0.025 }, full = true },
		{ name = "Head", color = "head", at = { 0, 0.0, -0.18 }, size = { 0.055, 0.055, 0.05 } },
		{ name = "EyeL", color = "eye", at = { -0.025, 0.01, -0.185 }, size = { 0.03, 0.04, 0.03 }, full = true },
		{ name = "EyeR", color = "eye", at = { 0.025, 0.01, -0.185 }, size = { 0.03, 0.04, 0.03 }, full = true },
	} :: { any },
	rods = {
		{ name = "Proboscis", color = "proboscis", d = 0.009, from = { 0, -0.01, -0.2 }, to = { 0, -0.05, -0.4 } },
		{ name = "Antenna", color = "antenna", d = 0.006, from = { 0.012, 0.01, -0.2 }, to = { 0.05, 0.04, -0.33 }, mirror = true, full = true },
		{ name = "FrontLeg", color = "leg", d = 0.007, from = { 0.03, -0.03, -0.1 }, to = { 0.16, -0.16, -0.3 }, fly = { { 0.03, -0.03, -0.1 }, { 0.05, -0.2, -0.15 } }, mirror = true },
		{ name = "MiddleLeg", color = "leg", d = 0.007, from = { 0.035, -0.03, -0.06 }, to = { 0.3, -0.16, -0.02 }, fly = { { 0.035, -0.03, -0.06 }, { 0.06, -0.22, -0.02 } }, mirror = true },
		-- the hind legs curved up behind, as a resting mosquito holds them
		{ name = "HindFemur", color = "leg", d = 0.007, from = { 0.03, -0.03, -0.03 }, to = { 0.16, -0.12, 0.12 }, fly = { { 0.03, -0.03, -0.03 }, { 0.05, -0.15, 0.1 } }, mirror = true },
		{ name = "HindTibia", color = "leg", d = 0.006, from = { 0.16, -0.12, 0.12 }, to = { 0.2, 0.08, 0.34 }, fly = { { 0.05, -0.15, 0.1 }, { 0.04, -0.25, 0.25 } }, mirror = true, full = true },
	} :: { any },
	wings = {
		{ name = "Wing", color = "wing", material = "Glass", root = { 0.02, 0.06, -0.08 }, length = 0.3, width = 0.06, thick = 0.004, yaw = 6, pitch = 2, roll = 0,
			transparency = 0.45, reflectance = 0.06, fan = { reach = 0.26, span = 0.2, roll = 6, yaw = 25, back = 0.02, rise = 0.01, transparency = 0.85 } },
	} :: { any },
	shadow = { size = { 0.3, 0.004, 0.45 }, lift = 0.003, transparency = 0.82, full = true },
	motion = { gait = { stride = 0.2, swing = 0.3, lift = 0.3, settle = 10, jump = 0.6 }, kick = 6, antenna = { amp = 0.08, hz = 1.2 }, flap = { hz = 40, amp = 0.35 }, groom = FlyLook.groom, ready = FlyLook.ready },
}
-- The eastern forktail (Ischnura verticalis), a damselfly about 2.8 cm long: wide-set eyes, a green and black striped thorax, a slender black abdomen ringed pale
-- with blue on its tip (the male), four clear wings held together over the back at rest; short spiny legs.
FlyLook.small.damselfly = {
	colors = { head = "2a3a24", eye = "6a9a3a", thorax = "2a3424", stripe = "7ab04a", abdomen = "1e221c", ring = "8a9a7a", tip = "3a7ac8", leg = "2a2a24", wing = "e2e8ea",
		stigma = "3a3a34", shadow = "2a241c" },
	body = {
		{ name = "Head", color = "head", at = { 0, 0.16, -0.62 }, size = { 0.34, 0.14, 0.12 } },
		{ name = "EyeL", color = "eye", at = { -0.15, 0.18, -0.62 }, size = { 0.12, 0.13, 0.12 } },
		{ name = "EyeR", color = "eye", at = { 0.15, 0.18, -0.62 }, size = { 0.12, 0.13, 0.12 } },
		{ name = "Thorax", color = "thorax", at = { 0, 0.16, -0.38 }, size = { 0.16, 0.2, 0.34 } },
		{ name = "Stripe", color = "stripe", at = { 0, 0.2, -0.38 }, size = { 0.166, 0.08, 0.3 }, full = true },
		{ name = "Abdomen", color = "abdomen", at = { 0, 0.15, 0.62 }, size = { 0.075, 0.075, 1.75 } },
		{ name = "Ring1", color = "ring", at = { 0, 0.15, 0.1 }, size = { 0.08, 0.08, 0.03 }, full = true },
		{ name = "Ring2", color = "ring", at = { 0, 0.15, 0.4 }, size = { 0.08, 0.08, 0.03 }, full = true },
		{ name = "Ring3", color = "ring", at = { 0, 0.15, 0.7 }, size = { 0.08, 0.08, 0.03 }, full = true },
		{ name = "Tip", color = "tip", at = { 0, 0.15, 1.38 }, size = { 0.085, 0.085, 0.16 } },
	} :: { any },
	rods = {
		{ name = "FrontLeg", color = "leg", d = 0.02, from = { 0.05, 0.08, -0.48 }, to = { 0.14, -0.16, -0.55 }, fly = { { 0.05, 0.08, -0.48 }, { 0.06, -0.06, -0.5 } }, mirror = true },
		{ name = "MiddleLeg", color = "leg", d = 0.02, from = { 0.06, 0.08, -0.4 }, to = { 0.18, -0.16, -0.36 }, fly = { { 0.06, 0.08, -0.4 }, { 0.07, -0.06, -0.38 } }, mirror = true },
		{ name = "HindLeg", color = "leg", d = 0.02, from = { 0.06, 0.08, -0.32 }, to = { 0.17, -0.16, -0.18 }, fly = { { 0.06, 0.08, -0.32 }, { 0.07, -0.06, -0.24 } }, mirror = true },
	} :: { any },
	-- the four wings held together over the abdomen at rest (two pairs, a dark stigma near each tip), a blur in flight
	wings = {
		{ name = "Forewing", color = "wing", material = "Glass", root = { 0.02, 0.27, -0.42 }, length = 1.55, width = 0.17, thick = 0.006, yaw = 4, pitch = 3, roll = 70,
			transparency = 0.6, reflectance = 0.1, fan = { reach = 1.3, span = 0.6, roll = 6, yaw = 80, back = 0.0, rise = 0.02, transparency = 0.8 } },
		{ name = "Hindwing", color = "wing", material = "Glass", root = { 0.02, 0.27, -0.34 }, length = 1.5, width = 0.17, thick = 0.006, yaw = 2, pitch = 3, roll = 72,
			transparency = 0.6, reflectance = 0.1, fan = { reach = 1.25, span = 0.6, roll = 6, yaw = 100, back = 0.05, rise = 0.02, transparency = 0.8 } },
		{ name = "Stigma", color = "stigma", material = "SmoothPlastic", root = { 0.026, 0.27, 0.95 }, length = 0.08, width = 0.05, thick = 0.008, yaw = 4, pitch = 3, roll = 70,
			transparency = 0, reflectance = 0, hide = true, full = true },
	} :: { any },
	shadow = { size = { 0.5, 0.004, 2.6 }, lift = 0.003, transparency = 0.84, full = true },
	motion = { gait = { stride = 0.2, swing = 0.25, lift = 0.25, settle = 8, jump = 0.8 }, kick = 5, antenna = { amp = 0.02, hz = 0.5 }, flap = { hz = 25, amp = 0.5 }, ready = FlyLook.ready },
}

return FlyLook
