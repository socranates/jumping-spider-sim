--!strict
-- What age and use have done to the sill, the glass and the retreat, and the few small things left lying about: numbers and names
-- only; Habitat/Patina builds them. Colours are hex, lengths studs (1 stud = 1 cm). All of it is flat, tiny or thin, away from the
-- spawn (-22, 0, 6), the silk practice lines and the landing patch, and nothing here is solid or queryable.

local Wear = {}

-- ---------------------------------------------------------------- the sill's paint
-- The sill is cream enamel over wood (Graphics.paint); where the paint has gone the wood shows.
Wear.bare = { color = "9b7650", material = "Wood" }

-- A worn strip along the front lip's top front edge: runs of bare wood between gaps, from x0 to x1 (z from `z0` to the edge).
Wear.lip = {
	y = 0.7, z0 = 12.24, z1 = 12.5, height = 0.012, x0 = -29, x1 = 29,
	runs = { 1.2, 5.5 }, gaps = { 0.6, 3.2 }, -- length ranges
	colors = { "9b7650", "8e6a46", "a58058" }, seed = 31,
}

-- Grime where the floor meets the walls: thin, translucent lines from (x0, z0) to (x1, z1), this wide.
Wear.grime = {
	color = "6e6252", transparency = 0.55, height = 0.003,
	lines = {
		{ -30.0, -12.36, -11.0, -12.36, 0.28 }, { -13.0, -12.40, 9.0, -12.40, 0.22 }, { 6.0, -12.34, 30.0, -12.34, 0.32 },
		{ -30.0, -12.20, 30.0, -12.20, 0.07 },
		{ -29.88, -12.5, -29.88, 11.9, 0.22 }, { -29.70, -9.0, -29.70, 6.0, 0.07 },
		{ 29.88, -12.5, 29.88, 11.9, 0.22 }, { 29.70, -5.0, 29.70, 10.0, 0.07 },
		{ -30.0, 11.93, 30.0, 11.93, 0.09 },
	},
}

-- Dust bunnies in the corners (the two at the back and one at the front right): a cluster of tiny, translucent grey spheres each.
Wear.bunnies = {
	items = {
		{ x = -29.1, z = -11.6, count = 9, spread = 0.55, seed = 11 },
		{ x = 29.0, z = -11.8, count = 7, spread = 0.5, seed = 12 },
		{ x = 29.0, z = 11.3, count = 6, spread = 0.42, seed = 13 }, -- the front right corner, where the lip meets the frame
	},
	color = "b4afa5", transparency = 0.6, radius = { 0.07, 0.17 }, lift = 0.7, -- lift: how flat the spheres are
}

-- ---------------------------------------------------------------- the window glass (full tier)
-- Condensation on the lower panes: tiny flattened Glass spheres. Panes: x ranges clear of the mullions (the glass runs from -27.5
-- to 27.5 with bars at -10 and 10).
Wear.drops = {
	count = 26, size = { 0.1, 0.4 }, seed = 7,
	y = { 3.75, 7.2 }, panes = { { -27.0, -10.5 }, { -9.5, 9.5 }, { 10.5, 27.0 } },
	color = "e8f3f5", transparency = 0.35, reflectance = 0.3, flat = 0.018,
}
Wear.smudges = {
	items = {
		{ x = -16.0, y = 5.0, w = 7.0, h = 3.5, turn = 18 },
		{ x = 15.5, y = 8.8, w = 6.0, h = 3.0, turn = -24 },
	},
	color = "f6f4ee", transparency = 0.93,
}

-- ---------------------------------------------------------------- the silk retreat in the crevice
-- Salticids rest in silk retreats: a few overlapping translucent shells at the back and threads across the opening.
Wear.silk = {
	color = "f4f4ee", shellTransparency = 0.82, threadTransparency = 0.62, thread = 0.022,
	-- shells: centre x, y, z and radii (flattened domes lying on the floor, inside the crevice)
	shells = {
		{ -27.0, 0.0, 4.4, 1.7, 0.95, 1.5 }, { -26.2, 0.0, 6.6, 1.9, 1.05, 1.7 }, { -26.9, 0.0, 8.1, 1.6, 0.85, 1.2 },
		{ -25.4, 0.0, 5.3, 1.4, 0.75, 1.1 }, { -27.3, 0.0, 6.0, 1.3, 0.7, 2.1 },
	},
	-- threads across the opening (x = -23): from x, y, z to x, y, z. The middle of the opening is left clear for the camera that
	-- looks out of the retreat when the game starts.
	threads = {
		{ -23.15, 2.55, 2.8, -23.05, 0.02, 3.4 }, { -23.15, 2.55, 3.7, -23.0, 0.3, 4.1 }, { -23.15, 2.55, 8.9, -23.05, 0.02, 8.4 },
		{ -23.15, 2.55, 8.1, -23.0, 0.3, 7.8 }, { -23.1, 2.45, 2.7, -23.1, 2.35, 9.3 }, { -23.1, 1.2, 2.7, -23.1, 1.3, 4.0 },
		{ -23.1, 1.3, 8.0, -23.1, 1.2, 9.3 },
	},
}

-- ---------------------------------------------------------------- small things on the floor
-- A copper coin lying flat, plain faces, and a few fallen brown Pilea leaves.
Wear.coin = { x = 25.5, z = 9.5, diameter = 1.9, thickness = 0.12, color = "b5764f", material = "Metal" }
Wear.fallen = {
	items = {
		{ x = -11.6, z = 3.2, diameter = 1.7, color = "a07a45" },
		{ x = 4.8, z = 4.1, diameter = 1.3, color = "c49a5b" },
		{ x = 19.6, z = 2.9, diameter = 2.0, color = "a07a45" },
	},
	thickness = 0.03, material = "Fabric",
}

return Wear
