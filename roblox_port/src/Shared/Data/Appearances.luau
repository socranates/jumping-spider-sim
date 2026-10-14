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
}

return { default = "first_spider", profiles = { first_spider = first } }
