--!strict
-- How the world looks, apart from the spider (whose look is Data/Appearances). Numbers and names only, so the whole look can
-- be tuned in one place: Habitat/Scenery builds the parts from it, Habitat/Lit sets up the lighting and the sky, Habitat/SunPick
-- finds a sun that shines in through the window, and Client/WorldDetail strips what the low tier does without.
-- Studs: 1 stud = 1 cm. Colours are hex. Materials are Roblox's own (Habitat/Materials), which carry PBR textures once
-- MaterialService.Use2022Materials is on (both Rojo projects set it). Nothing here has been seen in Roblox Studio (ROBLOX-14).

local Graphics = {}

-- ---------------------------------------------------------------- materials
-- Looks only: a surface's grip is its profile in Data/Surfaces, never its material.
Graphics.materials = {
	-- the physical pieces of the sill (Habitat/WindowsillLayout.PIECES), by id
	pieces = {
		sill_floor = "WoodPlanks", front_lip = "Wood",
		back_frame = "Plaster", left_frame = "Plaster", right_frame = "Plaster",
		planter = "Brick", planter_rim = "Brick",
		leaf_west = "LeafyGrass", leaf_middle = "LeafyGrass", leaf_east = "LeafyGrass", leaf_tip = "Cardboard",
		stem_west = "Grass", stem_middle = "Grass", stem_east = "Grass",
		crevice_back = "Wood", crevice_roof = "Wood", crevice_north = "Wood", crevice_south = "Wood",
	} :: { [string]: string },
	soil = "Ground",
	wall = "Plaster", trim = "Wood", glass = "Glass",
	view = "SmoothPlastic", ground = "Grass",
	chip = "Plaster", crack = "SmoothPlastic", crumb = "Sand",
	fallback = "SmoothPlastic",
}

-- ---------------------------------------------------------------- the window
-- The back wall is a solid, climbable box (WindowsillLayout back_frame), so the window is drawn: the physical wall turns
-- invisible (still solid, still climbable) and Scenery draws a plaster wall behind its face with an opening for the glass.
Graphics.window = {
	hidden = "back_frame", -- the piece that turns invisible
	slabGap = 0.02, -- the drawn wall sits this far behind the climbable face, so the spider's feet never sink into it
	left = -27.5, right = 27.5, bottom = 3, top = 13, -- the opening: x from/to, y from/to
	trimWidth = 0.5, trimDepth = 0.10, -- the frame bars around the opening, flush with the climbable face
	wallColor = "ded7c3", trimColor = "e2dbc7",
	glass = { color = "a9c2c1", transparency = 0.8, reflectance = 0.08, thickness = 0.04, setback = 0.05 },
	mullions = { -10, 10 }, mullionWidth = 0.7, -- bars between the panes
	-- WindowsillLayout.DECOR entries Scenery draws itself
	replaces = { window_glass = true, mullion_w = true, mullion_e = true } :: { [string]: boolean },
}

-- ---------------------------------------------------------------- the view out of the window
-- Items are placed as seen from a reference eye (the camera's usual spot over the middle of the sill): u, v are where the
-- item's centre appears on the glass (studs across and up), `depth` how far beyond the glass it really is; Scenery turns
-- that into world positions and sizes, so every item shows where it should whatever the depth. kind "block": a box w x h
-- on the glass, `t` deep; "ball": a sphere of diameter w; "roof": a gable (a square turned 45 degrees) w wide with its
-- eave line at v. `full`: dropped in the low tier.
Graphics.view = {
	eye = Vector3.new(0, 2.5, 5),
	ground = { y = -46, size = 2048, color = "7d8f62" },
	sky = true,
	items = {
		-- far hills
		{ id = "hill_w", kind = "ball", u = -20, v = -7.0, depth = 320, w = 22, color = "88a08d", full = false },
		{ id = "hill_m", kind = "ball", u = 3, v = -6.2, depth = 330, w = 24, color = "92a898", full = true },
		{ id = "hill_e", kind = "ball", u = 24, v = -6.6, depth = 320, w = 22, color = "8aa28f", full = false },
		-- roofs of the houses across the way
		{ id = "house_1", kind = "block", u = -24, v = -2.7, depth = 120, w = 6.0, h = 14, t = 5, color = "d8c9a8", full = false },
		{ id = "roof_1", kind = "roof", u = -24, v = 4.3, depth = 120, w = 6.5, t = 5.4, color = "8d4a3a", full = false },
		{ id = "house_2", kind = "block", u = -16.5, v = -3.1, depth = 120, w = 5.0, h = 14, t = 5, color = "c9bba0", full = true },
		{ id = "roof_2", kind = "roof", u = -16.5, v = 3.9, depth = 120, w = 5.5, t = 5.4, color = "5f6a73", full = true },
		{ id = "house_3", kind = "block", u = -8.5, v = -2.4, depth = 120, w = 6.4, h = 14, t = 5, color = "e0d3b5", full = false },
		{ id = "roof_3", kind = "roof", u = -8.5, v = 4.6, depth = 120, w = 7.0, t = 5.4, color = "9a5642", full = false },
		{ id = "house_4", kind = "block", u = 0.5, v = -3.0, depth = 120, w = 5.3, h = 14, t = 5, color = "cdbfa4", full = true },
		{ id = "roof_4", kind = "roof", u = 0.5, v = 4.0, depth = 120, w = 5.8, t = 5.4, color = "6a5a52", full = true },
		{ id = "house_5", kind = "block", u = 9, v = -2.2, depth = 120, w = 6.6, h = 14, t = 5, color = "d6c6a6", full = false },
		{ id = "roof_5", kind = "roof", u = 9, v = 4.8, depth = 120, w = 7.2, t = 5.4, color = "7b4a3d", full = false },
		{ id = "house_6", kind = "block", u = 17.5, v = -2.9, depth = 120, w = 5.5, h = 14, t = 5, color = "c4b99f", full = true },
		{ id = "roof_6", kind = "roof", u = 17.5, v = 4.1, depth = 120, w = 6.0, t = 5.4, color = "58626b", full = true },
		{ id = "house_7", kind = "block", u = 25, v = -2.5, depth = 120, w = 6.2, h = 14, t = 5, color = "dccfb0", full = false },
		{ id = "roof_7", kind = "roof", u = 25, v = 4.5, depth = 120, w = 6.8, t = 5.4, color = "93513f", full = false },
		{ id = "chimney_3", kind = "block", u = -7.3, v = 6.7, depth = 119, w = 0.6, h = 2.4, t = 0.8, color = "8c5a48", full = true },
		{ id = "chimney_5", kind = "block", u = 10.3, v = 6.85, depth = 119, w = 0.6, h = 2.5, t = 0.8, color = "86553f", full = true },
		-- a tree on the left, a smaller one on the right
		{ id = "trunk_a", kind = "block", u = -17, v = -3.2, depth = 72, w = 1.3, h = 23.5, t = 1.3, color = "4a3e30", full = false },
		{ id = "canopy_a1", kind = "ball", u = -17, v = 10.5, depth = 72, w = 11, color = "3f6238", full = false },
		{ id = "canopy_a2", kind = "ball", u = -23.5, v = 8.5, depth = 72, w = 8.5, color = "496f40", full = false },
		{ id = "canopy_a3", kind = "ball", u = -10.5, v = 9.0, depth = 72, w = 8, color = "35552f", full = true },
		{ id = "canopy_a4", kind = "ball", u = -19.5, v = 13.5, depth = 72, w = 7, color = "446a3b", full = true },
		{ id = "canopy_a5", kind = "ball", u = -13.5, v = 13.2, depth = 72, w = 6.5, color = "3a5c34", full = true },
		{ id = "canopy_a6", kind = "ball", u = -26, v = 12, depth = 72, w = 6, color = "4d7544", full = true },
		{ id = "trunk_b", kind = "block", u = 18.5, v = 1.5, depth = 100, w = 0.9, h = 14, t = 0.9, color = "50443a", full = true },
		{ id = "canopy_b1", kind = "ball", u = 18.5, v = 7.2, depth = 100, w = 6.5, color = "47703e", full = true },
		{ id = "canopy_b2", kind = "ball", u = 22, v = 6.2, depth = 100, w = 5, color = "3d6336", full = true },
		{ id = "canopy_b3", kind = "ball", u = 15, v = 6.0, depth = 100, w = 4.5, color = "4f7746", full = true },
	} :: { { id: string, kind: string, u: number, v: number, depth: number, w: number, h: number?, t: number?, color: string, full: boolean } },
}

-- ---------------------------------------------------------------- small details on the sill (full tier only)
-- Flat or tiny, away from the spawn and the silk practice spot, so the landing patch, the silk lines and the prompts stay clear.
Graphics.details = {
	-- paint chips: where (x, z), size (w across, d deep), turn in degrees, colour
	chips = {
		{ x = -8.6, z = 10.5, w = 0.62, d = 0.40, turn = 20, color = "f1ead8" }, { x = -7.7, z = 10.9, w = 0.34, d = 0.27, turn = -35, color = "e8dfc9" }, { x = -6.6, z = 10.2, w = 0.45, d = 0.30, turn = 70, color = "f1ead8" },
		{ x = 11.6, z = 9.8, w = 0.55, d = 0.38, turn = -15, color = "f1ead8" }, { x = 12.5, z = 10.3, w = 0.30, d = 0.22, turn = 50, color = "dcd3bc" }, { x = 24.6, z = 7.9, w = 0.50, d = 0.33, turn = 35, color = "f1ead8" },
		{ x = -3.8, z = 5.4, w = 0.36, d = 0.26, turn = -60, color = "e8dfc9" }, { x = -14.9, z = 8.6, w = 0.58, d = 0.36, turn = 10, color = "f1ead8" }, { x = -15.6, z = 8.1, w = 0.28, d = 0.20, turn = -25, color = "dcd3bc" },
		{ x = 27.0, z = 11.0, w = 0.70, d = 0.45, turn = 0, color = "f1ead8" }, { x = 20.5, z = 5.0, w = 0.40, d = 0.30, turn = 80, color = "e8dfc9" }, { x = 0.5, z = 8.8, w = 0.32, d = 0.24, turn = -10, color = "f1ead8" },
	},
	chipThickness = 0.012,
	-- cracks in the sill: polylines of x, z points; the first is the main crack, the others branch off it
	cracks = {
		{ { -11.0, 9.9 }, { -9.4, 8.9 }, { -8.3, 9.3 }, { -6.5, 7.9 }, { -5.7, 8.2 }, { -3.2, 6.6 } },
		{ { -6.5, 7.9 }, { -5.9, 6.7 }, { -6.3, 5.9 } },
	},
	crackWidth = 0.05, crackColor = "3b2f24", crackHeight = 0.004,
	-- crumbs: centre (x, y, z), size (sx, sy, sz), turn in degrees, colour
	crumbs = {
		{ x = 14.6, y = 0.11, z = 8.6, sx = 0.34, sy = 0.22, sz = 0.27, turn = 25, color = "d6b684" },
		{ x = 14.95, y = 0.07, z = 8.75, sx = 0.20, sy = 0.14, sz = 0.16, turn = -40, color = "c9a56f" },
		{ x = 14.3, y = 0.045, z = 8.3, sx = 0.12, sy = 0.09, sz = 0.10, turn = 70, color = "e0c493" },
	},
}

-- ---------------------------------------------------------------- lighting
Graphics.lighting = {
	brightness = 2.6,
	ambient = { 70, 66, 58 }, outdoorAmbient = { 150, 146, 132 },
	colorShiftTop = { 255, 240, 214 }, -- a soft warm sun
	environmentDiffuse = 1, environmentSpecular = 1,
	shadowSoftness = 0.2, exposureCompensation = 0.1,
	clockTime = 9.6, latitude = 40.7, -- used when no through-window sun can be found (SunPick)
}
-- SunPick looks for a time of day whose sun stands behind the window and low enough to shine in across the sill.
Graphics.sun = {
	elevationDeg = 30, minElevationDeg = 18, maxElevationDeg = 48,
	azimuthDeg = 30, maxAzimuthDeg = 65, -- angle between straight out of the window (-Z) and the sun's heading
	clockFrom = 7, clockTo = 17, clockStep = 0.25,
}
Graphics.atmosphere = { density = 0.30, offset = 0.25, color = { 199, 215, 232 }, decay = { 232, 196, 150 }, glare = 0.3, haze = 1.0 }
Graphics.sky = { sunAngularSize = 12, moonAngularSize = 11, starCount = 3000 }
Graphics.clouds = { cover = 0.45, density = 0.5, color = { 250, 248, 240 } }
Graphics.bloom = { intensity = 0.3, size = 18, threshold = 1.6 }
Graphics.grade = { contrast = 0.06, saturation = 0.05, tint = { 255, 248, 236 }, brightness = 0 }
Graphics.sunRays = { intensity = 0.05, spread = 0.7 }
-- Depth of field is off unless the Workspace attribute DepthOfField is true (it blurs the sill the player is reading).
Graphics.depthOfField = { far = 0.55, near = 0.35, focus = 6, radius = 3.5 }

-- ---------------------------------------------------------------- dust motes and light shafts
Graphics.dust = {
	at = Vector3.new(0, 6.1, -1), size = Vector3.new(56, 11, 22),
	rate = 7, lifetime = { 14, 18 }, speed = { 0.04, 0.16 }, particle = { 0.05, 0.11 },
	transparency = 0.55, lightEmission = 0.55, lightInfluence = 0.35, color = "fff0d2",
	texture = "rbxasset://textures/particles/smoke_main.dds",
}
-- Soft shafts of light from the window along the sun, a few stacked translucent ribbons each (full tier only).
Graphics.shafts = {
	x = { -18.75, 0, 18.75 }, -- where along the window each starts (the middle of each pane)
	startY = 11.5, -- height on the glass where a shaft starts
	grow = 1.25, -- how much wider a shaft is where it reaches the floor
	layers = { { 2.4, 0.972 }, { 4.0, 0.982 }, { 6.0, 0.99 } }, -- width, transparency
	lightEmission = 0.5, color = "fff0d2",
}

-- ---------------------------------------------------------------- detail tiers
Graphics.tiers = {
	full = { dustRate = 1.0 },
	low = { dustRate = 0.4 }, -- also drops everything built with FullOnly: bloom, sun rays, clouds, shafts, details, the busier view
}

return Graphics
