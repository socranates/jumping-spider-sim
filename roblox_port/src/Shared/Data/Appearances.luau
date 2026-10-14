--!strict
-- Artist-directed appearance, independent of species tuning, growth and physics.
-- Nathan's daughter's pick: docs/art/first-spider-reference.jpg (2026-10-14).
-- Coordinates for markings are fractions of the abdomen's X/Z radii; -Z is front.
local first = {
	id = "first_spider",
	name = "First spider",
	body = { 0, 0, 0 },
	legs = { 0, 0, 0 },
	white = { 0.94, 0.94, 0.92 },
	eyes = { 0.008, 0.008, 0.008 },
	fangs = { 0.025, 0.025, 0.025 },
	headRadii = { 0.245, 0.18, 0.255 },
	abdomenRadii = { 0.25, 0.205, 0.285 },
	frontLegScale = 1.28,
	bandFraction = 0.23,
	speckleCount = 24,
	-- Large centre, two small elongated anterior spots, two posterior ovals.
	spots = {
		{ x = 0, z = 0.10, rx = 0.080, rz = 0.074, angle = 0 },
		{ x = -0.34, z = -0.46, rx = 0.018, rz = 0.034, angle = -0.35 },
		{ x = 0.34, z = -0.46, rx = 0.018, rz = 0.034, angle = 0.35 },
		{ x = -0.35, z = 0.67, rx = 0.025, rz = 0.035, angle = 0.4 },
		{ x = 0.35, z = 0.67, rx = 0.025, rz = 0.035, angle = -0.4 },
	},
	-- Fuzz: setae (hairs) as thin display parts. Jumping spiders are densely hairy; the hairs lie back toward the abdomen's tip,
	-- are white where the pattern is white (spots, front band, cheeks), and Phidippus has a tuft above each side of the eyes.
	-- Counts are budgets, not exact: points on the belly, the eye face and over the eyes get none.
	fuzz = {
		enabled = true,
		abdomenSamples = 520, -- Fibonacci points on the abdomen ellipsoid before the belly is skipped
		headSamples = 340,
		length = { 0.022, 0.042 }, -- studs; body radius is about 0.25
		width = 0.0065,
		lieBack = 1.7, -- how far a body hair leans toward the rear (0 stands straight out, 1.7 is about 60 degrees)
		dark = { 0.13, 0.13, 0.13 }, -- a touch lighter than the black body so the fuzz reads in the light
		grey = { 0.52, 0.52, 0.50 }, -- the soft grey hairs mixed through the coat, a halo against the sill
		greyShare = 0.3,
		transparency = 0.25, -- hairs are a little see-through, so the coat looks soft rather than spiky
		-- Fur shells: see-through layers just outside the body, so the outline goes soft (a classic cheap fur trick).
		shellColor = { 0.30, 0.30, 0.29 },
		shells = { { scale = 1.06, transparency = 0.78 }, { scale = 1.13, transparency = 0.9 } },
		tuftHairs = 8,
		tuftLength = 0.085,
		legHairs = { 9, 8, 4 }, -- femur, tibia, tarsus, per leg
		legLength = 0.04,
	},
}

return { default = "first_spider", profiles = { first_spider = first } }
