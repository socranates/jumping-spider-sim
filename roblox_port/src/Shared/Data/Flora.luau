--!strict
-- The plants of the drawn world: the Pilea on the sill, the trough's planting, and the garden outside the window. Numbers and
-- names only; Habitat/Plants builds them. Colours are hex, lengths studs (1 stud = 1 cm). Nothing here is solid or queryable, and
-- nothing here moves a physical piece: a drawn leaf's top is its piece's top, a drawn stem sits inside its piece's box.

local Flora = {}

-- ---------------------------------------------------------------- the Pilea (Chinese money plant, "pancake plant")
-- Pilea peperomioides has round, peltate leaves: the stalk joins the blade from below, away from its edge, and the veins fan out
-- from that point. These pups rooted in a crack of the old sill. Each hidden leaf piece is drawn as a pancake that fills its
-- footprint with its top at the piece's top, and each stem piece as a round petiole inscribed in its box.
Flora.pilea = {
	plants = {
		{ leaf = "leaf_garden", stem = "stem_garden" },
		{ leaf = "leaf_high", stem = "stem_high" },
		{ leaf = "leaf_west", stem = "stem_west" },
		{ leaf = "leaf_middle", stem = "stem_middle" },
		{ leaf = "leaf_east", stem = "stem_east" },
	},
	tip = "leaf_tip", -- the dry leaf, drawn as a curled fragment
	radius = 1.6, -- corner radius of the pancake, in plan
	material = "SmoothPlastic",
	top = "4f7d3a", rim = "3e6a31", under = "93b56d", dot = "bcdca0", vein = "86b567", petiole = "6a8f45",
	rimOut = 0.14, rimDrop = 0.06, rimFoot = 0.05, -- the darker rim band: how far past the blade, how far below its top, how far above its underside
	underOut = 0.02, underBelow = 0.012, underThick = 0.12, -- the lighter underside: past the blade, below it, how thick
	dotDiameter = 0.34, dotHeight = 0.012,
	veins = { count = 8, width = 0.05, height = 0.008, margin = 0.55, start = 0.22, reach = 0.94, jitter = 0.14 },
	foot = { diameter = 1.7, height = 0.2, color = "587c3a" },
	-- where each stem meets the sill: dark cracks radiating from it and a pinch of crumbled soil
	cracks = { count = 4, length = { 1.3, 3.2 }, width = 0.055, height = 0.004, color = "3b2f24", transparency = 0.1 },
	crumbs = { count = 7, size = { 0.12, 0.34 }, spread = 1.5, colors = { "4a3a2c", "5b4838", "3f3125" } },
	seed = 5,
	dry = {
		color = "c9a66b", edge = "a98250", curl = "b8935c", radius = 0.8,
		edgeWidth = 0.13, edgeHeight = 0.01, edgeInset = 0.12,
		-- curled-up corners: where (x, z), how far the plate turns about the vertical (degrees) and tips up (degrees)
		curls = { { x = 27.85, z = -4.0, turn = 35, tip = 24 }, { x = 25.9, z = -2.05, turn = -20, tip = 18 } },
		curlSize = { 0.9, 0.04, 0.55 },
	},
}

-- ROBLOX-74: the world's seed (the number the prey, the wasp and the rival draw from, Client/SpiderClient) also scatters the added greenery,
-- each part of it with a salt of its own, so every player sees the same sill and the tests can pin it.
Flora.worldSeed = 914

-- ---------------------------------------------------------------- the trough's planting
-- The soil patch (WindowsillLayout.DECOR "soil") is 12 x 6 at (10, 4.61, -4), on the rim slab's top.
-- Grass: Chet's 14 patches (x, y, z of each tuft's foot; five blades each, the last two fine) and the tufts added in ROBLOX-74. The added ones
-- are placed from the world's seed in the regions below (y is the surface they stand on; Shapes.clearAt keeps them off pieces, the spawn and the
-- retreat, and `apart` off each other and the old patches). Each has `blades` blades, the last `fine` of them full-tier only. A tuft grows
-- between short and lush (`height`), each blade leans (`tilt`, radians), a blade's colour is a mix of two of `colors` times a shade, and some
-- blades are dry. Lengths are studs (1 stud = 1 cm), so the tallest blade is 1.6 cm.
Flora.grass = {
	colors = { "668544", "7a9853", "91aa65" },
	patches = {
		{ 5.2, 4.62, -5.8 }, { 7.0, 4.62, -6.0 }, { 11.6, 4.62, -5.9 }, { 14.9, 4.62, -3.5 },
		{ 5.3, 4.62, -2.1 }, { 11.4, 4.62, -1.8 }, { -17, 0.02, -9.5 }, { -14, 0.02, 8.8 },
		{ -8, 0.02, -9.8 }, { -3, 0.02, 9.0 }, { 3, 0.02, 9.5 }, { 19, 0.02, 8.9 }, { 24, 0.02, -9.1 }, { 18, 0.02, -8.8 },
	},
	more = {
		salt = 1, blades = 4, fine = 2, apart = 0.8,
		height = { 0.35, 1.6 }, width = { 0.06, 0.1 }, tilt = { 0.08, 0.5 }, shade = { 0.84, 1.14 }, dry = "a8a468", dryShare = 0.12,
		regions = {
			{ name = "soil", x0 = 4.6, x1 = 15.4, z0 = -6.5, z1 = -1.6, y = 4.62, n = 5 }, -- the trough's soil
			{ name = "back", x0 = -28.0, x1 = 28.0, z0 = -11.9, z1 = -10.3, y = 0.02, n = 6 }, -- along the back wall
			{ name = "front", x0 = -28.0, x1 = 28.0, z0 = 10.4, z1 = 11.7, y = 0.02, n = 4 }, -- along the front lip
			{ name = "east", x0 = 24.0, x1 = 29.4, z0 = -9.0, z1 = 9.0, y = 0.02, n = 3 }, -- by the right frame
			{ name = "west", x0 = -29.4, x1 = -26.0, z0 = -11.0, z1 = 0.5, y = 0.02, n = 2 }, -- by the left frame, north of the retreat
		},
	},
}

-- Moss on the shaded side (ROBLOX-74): the sun comes in through the window behind the sill, so the trough's room-side face and the foot of the
-- back wall's room-side face stay in shade. Each patch is a scatter of flattened mounds on a face: its centre point, the face's outward normal,
-- a radius, how many mounds and how many of them are core (the rest are full-tier). The mounds lie on the face, `mound` as thick as they are wide.
Flora.moss = {
	salt = 2, size = { 0.3, 0.75 }, mound = 0.33, colors = { "4f7b34", "5f8a3a", "6b9b47", "476f30" }, material = "Plaster",
	patches = {
		{ x = 5.9, y = 0.9, z = 0.0, normal = { 0, 0, 1 }, r = 0.9, n = 7, core = 3 }, -- the trough's room-side face
		{ x = 12.8, y = 0.7, z = 0.0, normal = { 0, 0, 1 }, r = 0.8, n = 7, core = 3 },
		{ x = -5.5, y = 0.8, z = -12.5, normal = { 0, 0, 1 }, r = 0.7, n = 7, core = 3 }, -- the back wall's foot
		{ x = 21.0, y = 0.9, z = -12.5, normal = { 0, 0, 1 }, r = 0.8, n = 7, core = 3 },
	},
}

-- Pebbles and bark chips scattered on the sill floor (ROBLOX-74), clear of the pieces, the spawn and the retreat (Shapes.clearAt) and of each other
-- by `apart`. A pebble is a flattened ellipsoid, a bark chip a thin, slightly tilted slab. `core` of each kind stay in the low tier.
Flora.litter = {
	salt = 3, apart = 0.8,
	area = { x0 = -29.0, x1 = 29.0, z0 = -11.6, z1 = 11.2 },
	pebbles = { count = 14, core = 6, length = { 0.3, 0.85 }, flat = 0.34, colors = { "b9b6ae", "a9aaa6", "c8c4b9", "9c9a94", "d2cfc6" }, material = "Plaster" },
	bark = { count = 8, core = 4, length = { 0.5, 1.3 }, width = { 0.25, 0.55 }, thick = { 0.05, 0.1 }, tilt = 0.18, colors = { "6b4f36", "7d5d41", "5a432e", "86694b" }, material = "Wood" },
}

-- Two leaves blown in from the garden (ROBLOX-74), lying on the floor: a pointed oval blade with a lighter midrib and a stub of stalk. x, z where
-- the middle lies, length and width, turn about the vertical and how far one edge is lifted (degrees). The midrib is full-tier.
Flora.windfall = {
	items = {
		{ x = 8.4, z = 7.2, length = 2.7, width = 1.15, turn = 35, curl = 9, color = "b4903f", rib = "d1b366" }, -- dry gold
		{ x = -4.4, z = -9.0, length = 2.2, width = 0.95, turn = -62, curl = 12, color = "7f8f3f", rib = "a8b56a" }, -- olive, fallen last
	},
	thick = 0.04, stalk = 0.6, stalkColor = "7d5c30", material = "Fabric",
}

-- Morning dew (ROBLOX-74): small translucent Glass droplets on the tips of grass blades, on the rims of the Pilea's leaves and on the fallen
-- leaves. They are drawn from the world's seed (salt) and follow the clock of the day (Habitat/DayLight.dewAt): they gather through the night
-- from `formFrom` (20:00) to `fullBy` (05:00), stay until `burnFrom` (07:30) and are gone by `goneBy` (09:30). Each drop has a `lag`, the share
-- of the dew at which it appears and is gone (0 to `lag`), so they come and go one by one and not all at once.
Flora.dew = {
	salt = 4, formFrom = 20.0, fullBy = 5.0, burnFrom = 7.5, goneBy = 9.5, step = 0.01,
	size = { 0.07, 0.15 }, flat = 0.8, color = "eef7f5", transparency = { 0.28, 0.45 }, reflectance = 0.25, material = "Glass", lag = 0.55,
	grass = { chance = 0.8, keepEvery = 2 }, -- the tallest blade of a tuft; every second tuft's drop stays in the low tier
	pilea = { perLeaf = 5, keep = 2, inset = 0.4 }, -- around the rim of each of the five green leaves; `keep` of them stay in the low tier
	windfall = { perLeaf = 3, inset = 0.25 }, -- full tier only
}

Flora.planter = {
	soil = "4a3a2c", -- the soil's colour (the layout's own 665644 is the old look)
	area = { x0 = 4.3, x1 = 15.7, z0 = -6.7, z1 = -1.3, y = 4.615 }, -- where things may lie on the soil
	mottle = { -- damper and drier patches in the soil: x, z, width, depth, colour (full tier)
		{ x = 6.8, z = -5.3, w = 3.6, d = 1.7, color = "3d2f24" }, { x = 12.6, z = -2.6, w = 4.2, d = 1.5, color = "574433" },
		{ x = 9.6, z = -4.6, w = 2.4, d = 1.2, color = "43352a" }, { x = 14.4, z = -5.9, w = 2.8, d = 1.0, color = "534232" },
	},
	pebbles = { count = 15, length = { 0.3, 0.8 }, flat = 0.42, colors = { "b9b6ae", "a9aaa6", "c8c4b9", "9c9a94", "d2cfc6" }, seed = 21 },
	moss = {
		patches = { { x = 5.5, z = -2.2, r = 0.8, n = 8 }, { x = 14.7, z = -6.0, r = 0.9, n = 9 }, { x = 9.9, z = -1.7, r = 0.6, n = 6 } },
		size = { 0.22, 0.5 }, tall = 0.5, colors = { "5f8a3a", "6b9b47", "4f7b34" }, seed = 22,
	},
	-- tiny seedlings, under a centimetre tall: two cotyledons on a short stalk
	seedlings = { { x = 7.6, z = -4.9, turn = 20 }, { x = 12.2, z = -2.4, turn = -35 }, { x = 14.0, z = -5.2, turn = 70 } },
	stalk = 0.5, stalkWidth = 0.05, stalkColor = "b4d98a",
	cotyledon = { 0.46, 0.05, 0.22 }, cotyledonColor = "8cc466", cotyledonRise = 0.1, cotyledonTurn = 28, cotyledonTip = 14,
	-- a damp stain above the foot of the trough, and pale salt along its top edge, on all four faces of the trough
	stain = {
		color = "8a482d", transparency = 0.22, height = 0.9, thickness = 0.012,
		-- tide marks: from, to (fractions along a face) and how high
		tide = { { 0.0, 0.34, 1.3 }, { 0.34, 0.71, 1.75 }, { 0.71, 1.0, 1.1 } }, tideColor = "9a5a38", tideTransparency = 0.55,
		salt = { { 0.06, 0.22 }, { 0.46, 0.62 }, { 0.8, 0.93 } }, saltColor = "e4d6c0", saltTransparency = 0.5, saltHeight = 0.07, saltGap = 0.1,
	},
}

-- ---------------------------------------------------------------- the garden outside the window
-- A weathered window box beyond the wall (its top hides behind the wall's apron), black-eyed Susans (Rudbeckia hirta) in it, and
-- flowering shrubs further out. None of it can be reached. The view out is placed as seen from the camera's usual spot
-- (Graphics.view.eye); the box and the flowers stand where they really are.
Flora.garden = {
	box = {
		x0 = -24.5, x1 = 24.5, z0 = -21.8, z1 = -13.62, top = 2.8, bottom = -3.2,
		color = "6f8796", rim = "7f98a5", paint = "c4d0d2", soil = "392c21", soilTop = 2.55, rimWidth = 0.9,
		-- patches where the paint has lifted: x, z (on the rim and the far board), width, depth
		peel = { { -17.0, -21.6, 3.2, 0.6 }, { -2.5, -21.6, 2.4, 0.5 }, { 11.0, -21.6, 4.0, 0.6 }, { 20.5, -13.9, 3.0, 0.5 } },
	},
	-- Rudbeckia: head centre height y (above the sill), where it stands in the box (x, z), how much the head nods and turns toward the room (degrees), size
	flowers = {
		{ x = -23.2, z = -17.0, y = 5.5, nod = -8, turn = 14, size = 0.9 },
		{ x = -17.8, z = -15.8, y = 7.0, nod = -12, turn = -10, size = 1.0 },
		{ x = -12.4, z = -18.6, y = 6.0, nod = -4, turn = 22, size = 1.05 },
		{ x = -5.6, z = -16.3, y = 4.9, nod = -14, turn = -18, size = 0.95 },
		{ x = 0.8, z = -19.0, y = 7.7, nod = -9, turn = 6, size = 1.1 },
		{ x = 6.2, z = -15.9, y = 5.8, nod = -6, turn = -24, size = 1.0 },
		{ x = 12.6, z = -17.8, y = 7.2, nod = -13, turn = 16, size = 0.9 },
		{ x = 18.2, z = -16.3, y = 5.1, nod = -10, turn = -8, size = 1.05 },
		{ x = 23.0, z = -18.4, y = 6.6, nod = -5, turn = -20, size = 0.95 },
	},
	rudbeckia = {
		petals = { 12, 14 }, -- how many each head has (12 to 14)
		petalLength = 1.25, petalWidth = 0.55, petalThick = 0.07, droop = 9, -- degrees the tips sag away from the viewer
		petalColors = { "f2b705", "f6c112", "eaa900" }, disc = "e09a05", discOut = 0.45,
		centre = 0.42, centreHeight = 0.34, centreColor = "3b2414", -- the dome
		stem = "5c8a3a", stemWidth = 0.18, stemBend = 0.45,
		leaf = "4c7a33", leafSize = { 1.7, 0.05, 0.5 },
		-- the ultraviolet pattern: the outer half of each petal reflects it, the base and the centre absorb it (the classic bullseye)
		uv = { color = "b98cff", opacity = 0.85, rise = 0.03, thick = 0.02 },
		seed = 100,
	},
	-- flowering shrubs further out: where they appear on the glass (u across, v up), how far beyond it, how wide they look there
	shrubs = {
		{ u = -24, v = 3.6, depth = 30, w = 6, bloom = "pink" },
		{ u = -17, v = 3.9, depth = 44, w = 8, bloom = "white" },
		{ u = -9.5, v = 3.5, depth = 36, w = 6.5, bloom = "pink" },
		{ u = -2.5, v = 4.1, depth = 52, w = 8.5, bloom = "white" },
		{ u = 4.5, v = 3.6, depth = 32, w = 6, bloom = "pink" },
		{ u = 11.5, v = 4.0, depth = 46, w = 8, bloom = "white" },
		{ u = 18, v = 3.5, depth = 34, w = 6.5, bloom = "pink" },
		{ u = 25, v = 3.8, depth = 48, w = 8, bloom = "white" },
	},
	shrub = {
		foliage = { "4a6f3c", "56804a", "3f6334" },
		pink = { "f4c7d3", "ee9fb9", "f9dbe3", "e98fae" }, white = { "f8f4ec", "efe9de", "fbfaf5", "e6e0d2" },
		blooms = 14, bloomSize = { 0.13, 0.22 }, -- as a share of the shrub's width
		seed = 40,
	},
}

return Flora
