--!strict
-- How the mud dauber wasp looks: numbers and names only; Client/WaspBody builds the parts and poses them each frame. A black-and-yellow
-- mud dauber (Sceliphron caementarium) about 2.5 cm long, 1 stud = 1 cm: a black head with big dark eyes and yellow mandibles, a black
-- thorax with a yellow collar and a yellow scutellum, a very long thin yellow petiole (the thread waist) and a black gaster, six long legs
-- with black femurs, a yellow band at each knee, and yellow tibias and feet, two smoky dark wings each side, and two curled antennae.
-- The proportions, joints and walking and hanging poses are Godot's WaspBody (scripts/predator/wasp_body.gd, WASP-01), drawn here from
-- Roblox parts (the fly's pattern, ROBLOX-22): ellipsoids are Parts with a SpecialMesh sphere, rods are Cylinder parts. Where Godot drew
-- wings at 23 Hz (which a 60 Hz screen cannot show), the wing here is a soft translucent blur in flight, as the fly's.
-- Body frame: -Z forward, +Y up, the origin the petiole's base, which is where the wasp's position is. Lengths are studs, colours hex,
-- angles degrees. Ellipsoid `size` is the full diameters (Godot gave radii).

local WaspLook = {}

WaspLook.colors = {
	black = "191919", yellow = "d9af26", eye = "302b24", wing = "4a3b2b", vein = "5b4a31", blur = "3a2e22",
} :: { [string]: string }

-- Reflectance (a glossy black chitin; the eyes a little more).
WaspLook.gloss = { black = 0.05, yellow = 0.02, eye = 0.08 } :: { [string]: number }

-- The ellipsoids that never move relative to the torso. `color` names WaspLook.colors.
WaspLook.body = {
	{ name = "Head", color = "black", at = { 0, 0.04, -1.05 }, size = { 0.46, 0.40, 0.34 } },
	{ name = "Thorax", color = "black", at = { 0, 0.02, -0.63 }, size = { 0.48, 0.48, 0.70 } },
	{ name = "Scutellum", color = "yellow", at = { 0, 0.25, -0.52 }, size = { 0.26, 0.09, 0.17 } },
	{ name = "Collar", color = "yellow", at = { 0, 0.20, -0.85 }, size = { 0.40, 0.08, 0.11 } },
	{ name = "Gaster", color = "black", at = { 0, 0.025, 0.76 }, size = { 0.49, 0.44, 0.78 } },
	{ name = "AbdomenTip", color = "black", at = { 0, -0.01, 1.02 }, size = { 0.30, 0.30, 0.46 } },
	{ name = "AbdomenBase", color = "yellow", at = { 0, 0.04, 0.40 }, size = { 0.24, 0.23, 0.26 } },
	{ name = "EyeL", color = "eye", at = { -0.185, 0.075, -1.075 }, size = { 0.17, 0.30, 0.23 } },
	{ name = "EyeR", color = "eye", at = { 0.185, 0.075, -1.075 }, size = { 0.17, 0.30, 0.23 } },
	{ name = "MandibleL", color = "yellow", at = { -0.055, -0.10, -1.19 }, size = { 0.07, 0.14, 0.13 } },
	{ name = "MandibleR", color = "yellow", at = { 0.055, -0.10, -1.19 }, size = { 0.07, 0.14, 0.13 } },
} :: { { name: string, color: string, at: { number }, size: { number } } }

-- The thread waist: a thin yellow rod from the thorax to the gaster, a little narrower toward the gaster.
WaspLook.petiole = { from = { 0, 0, -0.32 }, to = { 0, 0.04, 0.39 }, diameter = 0.062, color = "yellow" }

-- The antennae: a base on the head, then a scape and a curled flagellum of three segments, in the antenna's own frame (right side; the
-- left mirrors it). `rest` is its turn about x and y at rest, `flick` how far a searching wasp swings it (Godot: 0.20 and 0.12 rad, 0.32 rad).
WaspLook.antenna = {
	base = { 0.075, 0.13, -1.15 },
	points = { { 0, 0, 0 }, { 0.055, 0.10, -0.17 }, { 0.19, 0.06, -0.53 }, { 0.27, 0.02, -0.71 }, { 0.30, -0.06, -0.80 } },
	diameters = { 0.04, 0.026, 0.020, 0.016 },
	colors = { "yellow", "black", "black", "black" },
	rest = { 0.20, 0.12 }, flick = 0.32, hertz = { 3.0, 0.7 },
} :: { base: { number }, points: { { number } }, diameters: { number }, colors: { string }, rest: { number }, flick: number, hertz: { number } }

-- A leg: where its hip sits on the torso (right side, front to hind), and the lengths of its parts. The joints come from WaspPose.
WaspLook.legs = {
	hips = { { 0.17, -0.12, -0.82 }, { 0.17, -0.12, -0.64 }, { 0.17, -0.12, -0.46 } },
	femur = 0.062, tibia = 0.046, tarsus = 0.026,
	band = { length = 0.09, grow = 0.016 }, -- the yellow band at the knee end of the femur
} :: { hips: { { number } }, femur: number, tibia: number, tarsus: number, band: { length: number, grow: number } }

-- Wings: a fore and a hind wing each side. The membrane is a flat ellipse from the root back and out; in flight it is a soft blur of the
-- whole stroke. root: where the wing's pivot sits (right side); sizes are the share of the forewing.
WaspLook.wing = {
	root = { 0.14, 0.20, -0.68 }, hindStep = 0.17, hindShare = 0.68,
	length = 1.15, width = 0.44, thick = 0.012, centre = { 0.20, 0, 0.56 }, sweep = 10,
	-- the angles (Godot): folded at rest on the ground, and the mean of the flap in the air
	folded = { yaw = 12, roll = 6 }, flight = { yaw = 58, roll = 25, shimmerRoll = 7, shimmerHertz = 5.5 },
	transparency = 0.45, flightTransparency = 0.62,
	blur = { widen = 1.55, transparency = 0.86 },
	vein = { diameter = 0.014, tipX = 0.30, to = 0.96 }, -- the dark edge from the root to near the tip
	reflectance = 0.04,
} :: any

-- The torso's gentle bob in the air and while it holds the spider (Godot: 0.025 at 1.3 Hz).
WaspLook.bob = { height = 0.025, hertz = 1.3 }

-- The walking pose is a stride at 3 Hz; the feet reach the surface 0.35 below the position (the wasp lands 0.35 above it).
WaspLook.walk = { hertz = 3.0, lift = 0.13, reach = 0.18 }

return WaspLook
