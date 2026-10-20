--!strict
-- The preserve's backdrop (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4, 7 and 10): every zone of World/Preserve drawn, and nothing of it walkable. Pure data
-- (World/Garden's drawn records, one part each, built by Habitat/Scenery.look on each client by Client/LookStream), placed from the zone's own seed by
-- Park-Miller streams, so a zone is the same forever on the server, on every client and in the CLI tests.
--
-- An American preserve in late summer (design section 10): a bur oak as the veteran, red and sugar maples and a black cherry at the woodland's edge, a meadow of
-- big bluestem, switchgrass and goldenrod with coneflower, milkweed and black-eyed Susan, cattails at the pond, bramble and scrub on the railway bank, a stone
-- retaining wall in the sun, a log ranger hut by the gate, chain-link along the railway, iron railings on the street, the backs of brick apartment blocks to the
-- east and the canal's towpath beyond a hedge to the west. True scale: every size is the real thing's (metres in the data, studs drawn, World/Preserve.at).
--
-- Levels (World/LookPlan): a record with `far` is in the zone's far look, the cheap masses a client holds for every zone wherever its spider is; `full` records
-- the low tier never draws (a far record that is also `full` is in the far look at the full tier only). Near the spider a zone is drawn whole at its tier: at the
-- full tier every record, at the low tier every record without `full`. So the far preserve is its masses (the ground, the trees' crowns, the meadow's grass and
-- drifts of flowers, the water, the hut, the city's blocks) and a zone close by gains its detail (the log courses, the slats, the posts, the heads of the
-- cattails). BUDGETS are the ceilings each zone keeps to (tests/worldmap.luau holds them).
--
-- Precision: every record lies within World/Preserve.LIMIT of the origin (tests/worldmap.luau checks every corner), so the city stops at the edge; its towers
-- are impostors there, each drawn the size a real tower about 600 m off would look from the hut (a 100 m tower drawn 12 m tall 60 m away): honest from the hut
-- and the meadow, and said so here because from the railway bank they would read as nearer and smaller than they are.
local Preserve = require(script.Parent.Preserve)

local PreserveLook = {}

export type Drawn = {
	id: string, size: Vector3, at: Vector3, color: Color3, transparency: number?,
	material: string?, shape: string?, turn: Vector3?, full: boolean?, group: string?, shadow: boolean?,
	far: boolean?, reflectance: number?,
}

-- The ceilings per zone: every record (`full`), the low tier's (`low`), the far look at the full tier (`far`) and at the low tier (`farLow`).
PreserveLook.BUDGETS = table.freeze({
	hut = { full = 170, low = 80, far = 50, farLow = 44 },
	hut_garden = { full = 230, low = 50, far = 30, farLow = 24 },
	bench = { full = 24, low = 14, far = 8, farLow = 6 },
	ground = { full = 90, low = 64, far = 64, farLow = 62 },
	meadow = { full = 140, low = 70, far = 110, farLow = 64 },
	pond = { full = 110, low = 40, far = 30, farLow = 24 },
	compost = { full = 40, low = 26, far = 16, farLow = 16 },
	woodland = { full = 90, low = 70, far = 64, farLow = 52 },
	wall = { full = 70, low = 40, far = 30, farLow = 30 },
	scrub = { full = 46, low = 30, far = 34, farLow = 30 },
	city_south = { full = 190, low = 96, far = 80, farLow = 80 },
	city_west = { full = 40, low = 34, far = 26, farLow = 24 },
	city_east = { full = 130, low = 30, far = 40, farLow = 30 },
	railway = { full = 60, low = 52, far = 40, farLow = 40 },
	towers = { full = 24, low = 14, far = 16, farLow = 12 },
}) :: { [string]: { full: number, low: number, far: number, farLow: number } }

-- The palette: hex colours by what they are.
local C = {
	mown = "6c8a45", mownStripe = "7f9c52", meadowFloor = "8f8a55", woodFloor = "5d5438", scrubFloor = "566238", gravel = "b9ab8c", mud = "5a4a36",
	grass = { "8d8a4f", "9a9156", "7c7a52", "8a6f4a", "a0955c", "77804a", "6f8248", "93864e" }, -- big bluestem bronze, switchgrass straw, green
	flowers = { goldenrod = "d4b23a", coneflower = "b36a8f", milkweed = "c48a96", susan = "e0a92a", lace = "e8e4d4", bergamot = "a88bb0" },
	oakBark = "5a5046", oakCrown = { "4a6a34", "3f5d2f", "557a3c", "46663a" },
	mapleBark = "6b6258", mapleCrown = { "5f8a3e", "6a9446", "56803a", "6e8f40" },
	cherryBark = "3c302b", cherryCrown = { "41612f", "4b6b35" },
	shrub = { "4c6a35", "567a3c", "3f5a2e" },
	bramble = { "3d5a2c", "4a6533", "34482a", "44602f", "52693a" }, ivy = "2f4a2a",
	water = "3e5a5a", reed = { "6d7a43", "7c8650", "667242" }, cattail = "5a3d27", lily = "4f7a3a",
	limestone = { "b8ae9c", "a69c8a", "c4baa7", "b0a592", "9e9482" },
	log = "5c4531", logDark = "3f2e20", lining = "c8a77a", floor = "a07c55", ceiling = "cdb08a", trim = "3f5a43", roof = "3b4f40", glass = "26323a",
	concrete = "8a867d", board = "8a7458", boardDark = "6f5d47", soil = "4a3b2c",
	herbs = { "8a9a7a", "6d7f55", "5c8a45", "7a8f5e", "5f7d3a" }, herbFlowers = { "8a7fa8", "a88bb0", "b04a5c", "e6dfcf" },
	ballast = "7c776e", rail = "5a5651", sleeper = "4a3d33", bank = "748a4b",
	brick = { "8f5a46", "a06b52", "7d6a5c", "94604a" }, window = "2f3a44", balcony = "b9b4ab",
	asphalt = "4a4b4d", pavement = "a9a69e", railing = "1f2224", shop = { "b38e6a", "8c7f74", "9a5b48", "a99a86", "7f6a5a", "b5a48c" },
	tower = { "9aa6b4", "a8b2bd", "8e9aab", "b3b9c0", "97a3ae", "a2acb6" }, hedge = "3f5a31", canal = "455c5c", coping = "9c978c",
	metal = "8d9196", black = "2a2c2e", bin = "3d4a3e", lamp = "f1e3b8",
}

local MOD = 2147483647
local function rng(seed: number, salt: number): () -> number
	local state = (seed + salt * 7919) % MOD
	if state <= 0 then state += MOD - 1 end
	return function(): number
		state = (state * 16807) % MOD
		return (state - 1) / (MOD - 1)
	end
end
local function between(rand: () -> number, a: number, b: number): number
	return a + (b - a) * rand()
end
local function pick<T>(list: { T }, rand: () -> number): T
	return list[1 + math.floor(rand() * #list)]
end

local M = Preserve.at
local GROUND = Preserve.GROUND_Y

-- ---------------------------------------------------------------- the record makers
-- Each appends to a zone's list. Flags: `far` (in the far look), `full` (the low tier drops it), and a few looks (transparency, reflectance, shadow).
type Flags = { far: boolean?, full: boolean?, transparency: number?, reflectance: number?, shadow: boolean?, group: string? }
type List = { Drawn }

local function add(out: List, id: string, size: Vector3, at: Vector3, color: string, material: string, f: Flags?, shape: string?, turn: Vector3?)
	local flags: Flags = f or {}
	table.insert(out, {
		id = id, size = size, at = at, color = Color3.fromHex(color), material = material, shape = shape, turn = turn,
		far = flags.far, full = flags.full, transparency = flags.transparency, reflectance = flags.reflectance, shadow = flags.shadow, group = flags.group,
	})
end

-- An upright box from a rectangle in metres and heights in metres over the ground.
local function block(out: List, id: string, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, color: string, material: string, f: Flags?)
	local lo, hi = Preserve.box(x0, x1, z0, z1, y0, y1)
	add(out, id, hi - lo, (lo + hi) * 0.5, color, material, f)
end

-- An upright box in studs (the hut's own frame: the sill's studs).
local function sblock(out: List, id: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: string, material: string, f: Flags?)
	add(out, id, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, f)
end

-- An ellipsoid at (x, z) metres, its middle `y` metres over the ground, `w` across (east-west), `h` tall and `d` deep (north-south), metres.
local function blob(out: List, id: string, x: number, z: number, y: number, w: number, h: number, d: number, color: string, f: Flags?, yaw: number?)
	add(out, id, Vector3.new(w * 100, h * 100, d * 100), M(x, z, y), color, "LeafyGrass", f, "Ellipsoid", if yaw then Vector3.new(0, yaw, 0) else nil)
end

-- An upright cylinder at (x, z) metres from `y0` to `y1` metres over the ground, `dia` metres across.
local function post(out: List, id: string, x: number, z: number, y0: number, y1: number, dia: number, color: string, material: string, f: Flags?)
	local a = M(x, z, (y0 + y1) / 2)
	add(out, id, Vector3.new((y1 - y0) * 100, dia * 100, dia * 100), a, color, material, f, "Cylinder", Vector3.new(0, 0, 90))
end

-- A rod (a cylinder) from a to b in studs, `dia` studs across: logs, limbs, rails.
local function rod(out: List, id: string, a: Vector3, b: Vector3, dia: number, color: string, material: string, f: Flags?)
	local d = b - a
	local len = d.Magnitude
	local u = d / len
	local theta = math.deg(math.asin(math.clamp(u.Y, -1, 1)))
	local phi = math.deg(math.atan2(-u.Z, u.X))
	add(out, id, Vector3.new(len, dia, dia), (a + b) * 0.5, color, material, f, "Cylinder", Vector3.new(0, phi, theta))
end

-- A flat strip along the ground from (x0, z0) to (x1, z1) metres, `w` metres wide, `t` studs thick, its top `top` studs over the ground.
local function strip(out: List, id: string, x0: number, z0: number, x1: number, z1: number, w: number, top: number, t: number, color: string, material: string, f: Flags?)
	local a, b = M(x0, z0), M(x1, z1)
	local d = b - a
	local len = d.Magnitude
	local yaw = math.deg(math.atan2(-d.Z, d.X)) -- (about Y: the strip's length along X turned onto the segment)
	local mid = (a + b) * 0.5
	add(out, id, Vector3.new(len + w * 100 * 0.5, t, w * 100), Vector3.new(mid.X, GROUND + top - t / 2, mid.Z), color, material, f, nil, Vector3.new(0, yaw, 0))
end

-- A tree: a trunk and a crown of overlapping masses. `crown` metres across, `height` metres to the crown's top, `bole` metres of clear trunk; `n` crown masses.
local function tree(out: List, id: string, rand: () -> number, x: number, z: number, height: number, crown: number, bole: number, trunk: number, bark: string,
	leaves: { string }, n: number, nFar: number, lowKeeps: number)
	post(out, id .. "_trunk", x, z, 0, bole + (height - bole) * 0.45, trunk, bark, "Wood", { far = true })
	local mid = bole + (height - bole) * 0.5
	for k = 1, n do
		local ang = (k - 1) / n * 2 * math.pi + between(rand, -0.4, 0.4)
		local r = if k == 1 then 0 else crown * between(rand, 0.18, 0.34)
		local w = crown * (if k == 1 then 0.62 else between(rand, 0.42, 0.56))
		local h = (height - bole) * (if k == 1 then 0.78 else between(rand, 0.48, 0.66))
		local y = if k == 1 then mid + (height - bole) * 0.06 else mid + between(rand, -0.16, 0.24) * (height - bole)
		y = math.min(y, height - h / 2)
		blob(out, `{id}_crown{k}`, x + math.cos(ang) * r, z + math.sin(ang) * r, y, w, h, w * between(rand, 0.85, 1.1), pick(leaves, rand),
			{ far = k <= nFar, full = k > lowKeeps })
	end
end

-- ---------------------------------------------------------------- the ranger hut (studs: the hut is built round the sill, whose frame is the origin)
-- A log hut 3.5 by 3 m (x -175..175, z -16..284), its walls 28.5 cm thick (the sill's reveal: the cladding's face at z -16, the lining's at 12.5), its floor
-- 15 cm over the ground on a sleeper base, its eaves 2.4 m over the ground, a gable roof of green standing-seam metal at 35 degrees with its ridge east-west,
-- 30 cm of overhang; the window with the sill in its north wall (drawn by the sill's Decor: its frame, glass and reveal to the frame's 14), a door in the south
-- wall to the gate, a small window in each end wall. Under the north window, a bench and a water butt fed from the gutter (the design's steps up to the sill).
local HX, HZ0, HZ1, HT = 175, -16, 284, 28.5 -- the hut's half width, its north and south faces, its walls' thickness
local FLOOR, EAVES, CEIL = Preserve.FLOOR_Y, Preserve.EAVES_Y, 150
local PITCH = 35
local OVER = 30
local WIN = { x = 31, top = 112.5 } -- the sill's window: x -31..31, the sill (y 0) to its head
local function hutDecor(out: List, rand: () -> number)
	local CL = 2.5 -- cladding and lining thickness
	local ix, iz0, iz1 = HX - HT, HZ0 + HT, HZ1 - HT -- the inside: x -146.5..146.5, z 12.5..255.5
	-- the base and the floor
	sblock(out, "Base", -HX - 3, HX + 3, GROUND, FLOOR, HZ0 - 3, HZ1 + 3, C.concrete, "Concrete", { far = true })
	sblock(out, "Floor", -ix, ix, FLOOR - 2, FLOOR, iz0, iz1, C.floor, "WoodPlanks")
	sblock(out, "Ceiling", -ix, ix, CEIL, CEIL + 2, iz0, iz1, C.ceiling, "WoodPlanks")
	-- the north wall: the cladding round the window and the lining inside it
	sblock(out, "NorthWest", -HX, -WIN.x, FLOOR, EAVES, HZ0, HZ0 + CL, C.log, "Wood", { far = true, shadow = true })
	sblock(out, "NorthEast", WIN.x, HX, FLOOR, EAVES, HZ0, HZ0 + CL, C.log, "Wood", { far = true, shadow = true })
	sblock(out, "NorthBelow", -WIN.x, WIN.x, FLOOR, -4, HZ0, HZ0 + CL, C.log, "Wood", { far = true })
	sblock(out, "NorthAbove", -WIN.x, WIN.x, WIN.top, EAVES, HZ0, HZ0 + CL, C.log, "Wood", { far = true })
	sblock(out, "OuterSill", -36, 36, -4, 0, -22, HZ0 + CL, C.board, "Wood", { far = true }) -- the window's outer sill, its top level with the sill's
	sblock(out, "LiningWest", -ix, -WIN.x, FLOOR, CEIL, iz0 - CL, iz0, C.lining, "WoodPlanks")
	sblock(out, "LiningEast", WIN.x, ix, FLOOR, CEIL, iz0 - CL, iz0, C.lining, "WoodPlanks")
	sblock(out, "LiningBelow", -WIN.x, WIN.x, FLOOR, -1, iz0 - CL, iz0, C.lining, "WoodPlanks")
	sblock(out, "LiningAbove", -WIN.x, WIN.x, WIN.top + 1, CEIL, iz0 - CL, iz0, C.lining, "WoodPlanks")
	-- the window's reveal over the sill's side frames (they stop at y 14) and its head
	sblock(out, "RevealWest", -31, -30, 14, WIN.top, -12.5, iz0, C.lining, "WoodPlanks")
	sblock(out, "RevealEast", 30, 31, 14, WIN.top, -12.5, iz0, C.lining, "WoodPlanks")
	sblock(out, "RevealHead", -31, 31, WIN.top, WIN.top + 1, -13.5, iz0, C.lining, "WoodPlanks")
	-- the green casing round the window outside
	sblock(out, "CasingWest", -37, -31, -4, WIN.top + 6, HZ0 - 1.2, HZ0, C.trim, "WoodPlanks", { far = true, full = true })
	sblock(out, "CasingEast", 31, 37, -4, WIN.top + 6, HZ0 - 1.2, HZ0, C.trim, "WoodPlanks", { far = true, full = true })
	sblock(out, "CasingHead", -37, 37, WIN.top, WIN.top + 6, HZ0 - 1.2, HZ0, C.trim, "WoodPlanks", { far = true, full = true })
	-- the other walls: cladding outside, lining inside
	sblock(out, "South", -HX, HX, FLOOR, EAVES, HZ1 - CL, HZ1, C.log, "Wood", { far = true })
	sblock(out, "West", -HX, -HX + CL, FLOOR, EAVES, HZ0, HZ1, C.log, "Wood", { far = true })
	sblock(out, "East", HX - CL, HX, FLOOR, EAVES, HZ0, HZ1, C.log, "Wood", { far = true })
	sblock(out, "LiningSouth", -ix, ix, FLOOR, CEIL, iz1, iz1 + CL, C.lining, "WoodPlanks")
	sblock(out, "LiningWestWall", -ix - CL, -ix, FLOOR, CEIL, iz0, iz1, C.lining, "WoodPlanks")
	sblock(out, "LiningEastWall", ix, ix + CL, FLOOR, CEIL, iz0, iz1, C.lining, "WoodPlanks")
	-- the door (south, toward the gate) and the end walls' small windows, both faces
	sblock(out, "Door", -45, 45, FLOOR, 135, HZ1, HZ1 + 1.5, C.trim, "WoodPlanks", { far = true })
	sblock(out, "DoorInside", -45, 45, FLOOR, 135, iz1 - 1, iz1, C.trim, "WoodPlanks")
	sblock(out, "DoorHandle", 30, 36, 60, 64, HZ1 + 1.5, HZ1 + 4, C.black, "Metal", { full = true })
	for i, sx in { -1, 1 } do
		local face, inner = sx * HX, sx * ix
		sblock(out, "EndWindow" .. i, math.min(face, face + sx * 1), math.max(face, face + sx * 1), 30, 100, 105, 165, C.glass, "SmoothPlastic", { far = true, reflectance = 0.2 })
		sblock(out, "EndWindowIn" .. i, math.min(inner, inner - sx * 1), math.max(inner, inner - sx * 1), 30, 100, 105, 165, C.glass, "SmoothPlastic", { reflectance = 0.15 })
		sblock(out, "EndCasing" .. i, math.min(face, face + sx * 1.5), math.max(face, face + sx * 1.5), 24, 106, 99, 171, C.trim, "WoodPlanks", { full = true })
	end
	-- the gable ends: each half a box turned to the roof's pitch, its corner at the eave (it stays inside the wall's outline and under the roof)
	local p = math.rad(PITCH)
	local run = (HZ1 - HZ0) / 2
	local L, D = run / math.cos(p), run * math.sin(p) + 2
	for i, sx in { -1, 1 } do
		local x = sx * (HX - CL / 2)
		for j, side in { 1, -1 } do -- the north half (rising southward from the north eave) and the south half
			local ez = if side == 1 then HZ0 else HZ1
			local uy, uz = math.sin(p), side * math.cos(p)
			local vy, vz = -math.cos(p), side * math.sin(p)
			local cy = EAVES + uy * L / 2 + vy * D / 2
			local cz = ez + uz * L / 2 + vz * D / 2
			add(out, `Gable{i}_{j}`, Vector3.new(CL - 0.4, D, L), Vector3.new(x, cy, cz), C.log, "Wood", { far = true }, nil, Vector3.new(-side * PITCH, 0, 0))
		end
	end
	-- the roof: two slopes of green standing-seam metal, the ridge cap, the north gutter and its downpipe into the water butt
	local ridgeY = EAVES + run * math.tan(p)
	for j, side in { 1, -1 } do
		local ez = if side == 1 then HZ0 else HZ1
		local slope = (run + OVER) / math.cos(p)
		local nY, nZ = math.cos(p), -side * math.sin(p) -- the slope's outward normal
		local midRun = (run - OVER) / 2 -- from the eave line toward the ridge, flat
		local cy = EAVES + midRun * math.tan(p) + nY * 4
		local cz = ez + side * midRun + nZ * 4
		add(out, "Roof" .. j, Vector3.new(2 * HX + 2 * OVER, 5, slope), Vector3.new(0, cy, cz), C.roof, "Metal", { far = true, shadow = true }, nil, Vector3.new(-side * PITCH, 0, 0))
	end
	sblock(out, "Ridge", -HX - OVER, HX + OVER, ridgeY + 4, ridgeY + 10, (HZ0 + HZ1) / 2 - 7, (HZ0 + HZ1) / 2 + 7, C.roof, "Metal", { far = true })
	local gutterY, gutterZ = EAVES - OVER * math.tan(p) - 4, HZ0 - OVER - 4
	add(out, "Gutter", Vector3.new(2 * HX + 2 * OVER, 12, 12), Vector3.new(0, gutterY, gutterZ), C.metal, "Metal", { far = true }, "Cylinder")
	add(out, "Downpipe", Vector3.new(gutterY - 30, 7, 7), Vector3.new(130, (gutterY + 30) / 2, gutterZ), C.metal, "Metal", { full = true }, "Cylinder", Vector3.new(0, 0, 90))
	-- the water butt on its stand of blocks, and the bench under the window
	sblock(out, "ButtStand", 98, 162, GROUND, GROUND + 20, -78, -22, C.concrete, "Concrete")
	add(out, "WaterButt", Vector3.new(92, 62, 62), Vector3.new(130, GROUND + 20 + 46, -50), "3e5d44", "SmoothPlastic", { far = true }, "Cylinder", Vector3.new(0, 0, 90))
	add(out, "ButtLid", Vector3.new(3, 64, 64), Vector3.new(130, GROUND + 20 + 93.5, -50), "2f4734", "SmoothPlastic", { full = true }, "Cylinder", Vector3.new(0, 0, 90))
	sblock(out, "BenchSeat", -85, 45, GROUND + 41, GROUND + 45, -58, -20, C.board, "WoodPlanks", { far = true })
	sblock(out, "BenchLegWest", -78, -70, GROUND, GROUND + 41, -55, -23, C.boardDark, "Wood")
	sblock(out, "BenchLegEast", 30, 38, GROUND, GROUND + 41, -55, -23, C.boardDark, "Wood")
	-- the log courses: a shadow line every 20 cm on the four faces (the window and the door break theirs); the corners' log ends
	local y = FLOOR + 18
	local row = 0
	while y < EAVES - 4 do
		row += 1
		local function line(id: string, x0: number, x1: number, z0: number, z1: number)
			sblock(out, id, x0, x1, y - 0.6, y + 0.6, z0, z1, C.logDark, "Wood", { full = true })
		end
		if y > -4 and y < WIN.top + 6 then
			line(`CourseN{row}a`, -HX, -37, HZ0 - 0.4, HZ0)
			line(`CourseN{row}b`, 37, HX, HZ0 - 0.4, HZ0)
		else
			line(`CourseN{row}`, -HX, HX, HZ0 - 0.4, HZ0)
		end
		if y < 135 then
			line(`CourseS{row}a`, -HX, -45, HZ1, HZ1 + 0.4)
			line(`CourseS{row}b`, 45, HX, HZ1, HZ1 + 0.4)
		else
			line(`CourseS{row}`, -HX, HX, HZ1, HZ1 + 0.4)
		end
		line(`CourseW{row}`, -HX - 0.4, -HX, HZ0, HZ1)
		line(`CourseE{row}`, HX, HX + 0.4, HZ0, HZ1)
		y += 20
	end
	for i, c in { { -1, HZ0 }, { 1, HZ0 }, { -1, HZ1 }, { 1, HZ1 } } do
		local cx, cz = c[1] * HX, c[2]
		sblock(out, "Corner" .. i, cx - 9, cx + 9, FLOOR, EAVES, cz - 9, cz + 9, C.logDark, "Wood", { full = true })
	end
	-- by the gate: the information board on two posts under its own little roof, and the bike rack's hoops
	post(out, "BoardPostWest", 49.0, 1.2, 0, 1.9, 0.1, C.boardDark, "Wood", { far = true })
	post(out, "BoardPostEast", 50.4, 1.2, 0, 1.9, 0.1, C.boardDark, "Wood", { far = true })
	block(out, "Board", 48.9, 50.5, 1.15, 1.25, 0.9, 1.8, "e8e0cc", "SmoothPlastic", { far = true })
	block(out, "BoardRoof", 48.8, 50.6, 1.0, 1.45, 1.92, 1.98, C.roof, "Metal", { full = true })
	for k = 1, 3 do
		local x = 41.6 + (k - 1) * 0.6
		rod(out, "RackHoop" .. k .. "a", M(x, 1.0, 0), M(x, 1.0, 0.8), 5, C.metal, "Metal", { full = true })
		rod(out, "RackHoop" .. k .. "b", M(x, 1.6, 0), M(x, 1.6, 0.8), 5, C.metal, "Metal", { full = true })
		rod(out, "RackHoop" .. k .. "c", M(x, 1.0, 0.8), M(x, 1.6, 0.8), 5, C.metal, "Metal", { full = true })
	end
	local _ = rand
end

-- ---------------------------------------------------------------- the hut garden (x 38..52, z 6..14)
local function gardenDecor(out: List, rand: () -> number)
	-- three beds edged in timber: two either side of the path, a long herb border along the north
	local beds = { { 39, 43.6, 7, 8.4 }, { 47.6, 51.6, 7, 8.4 }, { 38.6, 51.6, 12.4, 13.6 } }
	for i, b in beds do
		block(out, "Edging" .. i, b[1], b[2], b[3], b[4], 0, 0.22, C.board, "WoodPlanks", { far = true })
		block(out, "BedSoil" .. i, b[1] + 0.05, b[2] - 0.05, b[3] + 0.05, b[4] - 0.05, 0.22, 0.24, C.soil, "Ground")
		local n = math.floor((b[2] - b[1]) / 0.55)
		for k = 1, n do
			local x = b[1] + (k - 0.5) * (b[2] - b[1]) / n + between(rand, -0.12, 0.12)
			local z = between(rand, b[3] + 0.3, b[4] - 0.3)
			local w = between(rand, 0.4, 0.75)
			local h = w * between(rand, 0.45, 0.8) -- (low mounds: sage, thyme, mint and chives spread wider than they stand)
			local leaf = pick(C.herbs, rand)
			blob(out, `Herb{i}_{k}`, x, z, 0.22 + h * 0.25, w, h, w * between(rand, 0.8, 1.1), leaf, { far = k % 3 == 1, full = k % 2 == 0 })
			-- (near) two tufts off its shoulders, so a clump is a plant and not a stone, and a few flower heads over the ones in flower
			for t = 1, 2 do
				local a = between(rand, 0, 2 * math.pi)
				blob(out, `Tuft{i}_{k}_{t}`, x + math.cos(a) * w * 0.3, z + math.sin(a) * w * 0.3, 0.22 + h * 0.45, w * 0.5, h * 0.75, w * 0.45, pick(C.herbs, rand), { full = true })
			end
			if rand() < 0.45 then
				local flower = pick(C.herbFlowers, rand)
				for f = 1, 3 do
					local a = between(rand, 0, 2 * math.pi)
					local r = between(rand, 0, w * 0.35)
					blob(out, `HerbFlower{i}_{k}_{f}`, x + math.cos(a) * r, z + math.sin(a) * r, 0.22 + h * 0.7 + between(rand, 0, 0.08), 0.07, 0.09, 0.07, flower, { full = true })
				end
			end
		end
	end
	-- the pallet planters either side of the garden, with their own plants
	for i, x in { 40.4, 50.2 } do
		block(out, "Pallet" .. i, x - 0.6, x + 0.6, 10.1, 10.9, 0, 0.45, "b09a77", "WoodPlanks", { far = true })
		for k = 1, 3 do
			block(out, `Slat{i}_{k}`, x - 0.62, x + 0.62, 10.08, 10.1, 0.06 + (k - 1) * 0.14, 0.12 + (k - 1) * 0.14, "8f7a5a", "WoodPlanks", { full = true })
		end
		blob(out, "PalletPlants" .. i, x, 10.5, 0.62, 1.1, 0.5, 0.7, pick(C.herbs, rand), { far = true })
		blob(out, "PalletFlowers" .. i, x + 0.2, 10.4, 0.82, 0.5, 0.14, 0.4, pick(C.herbFlowers, rand), { full = true })
	end
	-- the bird feeder on its pole by the path, its seed spilled under it
	post(out, "FeederPole", 44.2, 10.4, 0, 1.75, 0.04, C.black, "Metal", { far = true })
	block(out, "Feeder", 44.08, 44.32, 10.28, 10.52, 1.55, 1.8, "c9b48a", "WoodPlanks", { far = true })
	block(out, "FeederRoof", 44.0, 44.4, 10.2, 10.6, 1.8, 1.84, C.trim, "WoodPlanks", { full = true })
	blob(out, "Spill", 44.2, 10.4, 0, 0.7, 0.02, 0.5, "b8a27a", { full = true })
	-- the split-rail fence along the garden's north side, a gap for the path
	for i, span in { { 38, 44.6 }, { 46.4, 52 } } do
		post(out, `RailPost{i}a`, span[1], 14.3, 0, 1.1, 0.14, "7a6a55", "Wood", { far = true })
		post(out, `RailPost{i}b`, span[2], 14.3, 0, 1.1, 0.14, "7a6a55", "Wood", { far = true })
		post(out, `RailPost{i}c`, (span[1] + span[2]) / 2, 14.3, 0, 1.1, 0.14, "7a6a55", "Wood", { full = true })
		for k, h in { 0.45, 0.9 } do
			rod(out, `Rail{i}_{k}`, M(span[1], 14.3, h), M(span[2], 14.3, h), 9, "8a7a62", "Wood", { far = k == 2 })
		end
	end
end

-- ---------------------------------------------------------------- the bench, the bin and the lamppost (x 40, z 16)
local function benchDecor(out: List, _rand: () -> number)
	local bx, bz = Preserve.BENCH.x, Preserve.BENCH.z
	block(out, "Seat", bx - 0.8, bx + 0.8, bz + 0.62, bz + 1.02, 0.42, 0.46, C.board, "WoodPlanks", { far = true })
	block(out, "Back", bx - 0.8, bx + 0.8, bz + 1.02, bz + 1.06, 0.55, 0.85, C.board, "WoodPlanks", { far = true })
	for i, x in { bx - 0.7, bx + 0.7 } do
		block(out, "Leg" .. i, x - 0.03, x + 0.03, bz + 0.62, bz + 1.06, 0, 0.42, C.black, "Metal")
		block(out, "Arm" .. i, x - 0.03, x + 0.03, bz + 0.62, bz + 1.04, 0.62, 0.66, C.black, "Metal", { full = true })
	end
	for k = 1, 3 do
		block(out, "SeatSlat" .. k, bx - 0.81, bx + 0.81, bz + 0.62 + (k - 1) * 0.135, bz + 0.62 + (k - 1) * 0.135 + 0.01, 0.461, 0.465, C.boardDark, "WoodPlanks", { full = true })
	end
	post(out, "Bin", bx + 1.3, bz + 0.9, 0, 0.8, 0.5, C.bin, "Metal", { far = true })
	post(out, "BinLid", bx + 1.3, bz + 0.9, 0.8, 0.86, 0.54, "2c372d", "Metal", { full = true })
	post(out, "LampPole", bx - 1.4, bz + 1.0, 0, 4.2, 0.1, C.black, "Metal", { far = true })
	block(out, "LampArm", bx - 1.4, bx - 1.0, bz + 0.98, bz + 1.02, 4.1, 4.16, C.black, "Metal", { full = true })
	block(out, "LampHead", bx - 1.12, bx - 0.88, bz + 0.88, bz + 1.12, 3.86, 4.1, C.black, "Metal", { far = true })
	block(out, "LampGlass", bx - 1.08, bx - 0.92, bz + 0.92, bz + 1.08, 3.8, 3.86, C.lamp, "SmoothPlastic", { full = true })
	blob(out, "Worn", bx, bz + 0.4, 0, 2.4, 0.02, 1.2, "8a8358", { full = true }) -- the grass worn thin in front of it
end

-- ---------------------------------------------------------------- the ground: the mown grass, the meadow's, the wood's and the scrub's floors, the paths, the fences
local function groundDecor(out: List, rand: () -> number)
	-- the mown grass under everything: 5 by 3 tiles of 20 m (a part is at most 2,048 studs), their tops at the ground
	for i = 0, 4 do
		for j = 0, 2 do
			block(out, `Grass{i}_{j}`, i * 20, i * 20 + 20, j * 20, j * 20 + 20, -0.02, 0, if (i + j) % 2 == 0 then C.mown else "698743", "Grass", { far = true })
		end
	end
	-- the floors laid over it (4 mm up): the meadow's tawny ground, the wood's leaf litter, the scrub's
	for i = 0, 1 do
		for j = 0, 1 do
			block(out, `MeadowFloor{i}_{j}`, 25 + i * 17.5, 25 + (i + 1) * 17.5, 18 + j * 15, 18 + (j + 1) * 15, 0, 0.004, C.meadowFloor, "Grass", { far = true })
		end
	end
	for j = 0, 2 do
		block(out, "WoodFloor" .. j, 0, 18, 5 + j * 50 / 3, 5 + (j + 1) * 50 / 3, 0, 0.004, C.woodFloor, "Ground", { far = true })
	end
	for i = 0, 3 do
		block(out, "ScrubFloor" .. i, 18 + i * 18.5, 18 + (i + 1) * 18.5, 50, 60, 0, 0.004, C.scrubFloor, "Ground", { far = true })
	end
	-- the paths (World/Preserve.CORRIDORS): mown strips and fine gravel, a segment longer than 20 m drawn in two
	local n = 0
	for _, c in Preserve.CORRIDORS do
		if c.kind == "mown" or c.kind == "gravel" then
			for k = 1, #c.points - 1 do
				local a, b = c.points[k], c.points[k + 1]
				local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				local parts = if len > 20 then 2 else 1
				for s = 1, parts do
					local t0, t1 = (s - 1) / parts, s / parts
					n += 1
					strip(out, `Path{n}`, a[1] + (b[1] - a[1]) * t0, a[2] + (b[2] - a[2]) * t0, a[1] + (b[1] - a[1]) * t1, a[2] + (b[2] - a[2]) * t1, c.width,
						0.6, 1, if c.kind == "gravel" then C.gravel else C.mownStripe, if c.kind == "gravel" then "Pebble" else "Grass", { far = true })
				end
			end
		end
	end
	-- the chain-link along the railway (z 60), a mesh you can see through, its top rail and posts
	for i = 0, 4 do
		block(out, "ChainLink" .. i, i * 20, i * 20 + 20, 59.99, 60.01, 0, 1.8, C.metal, "Metal", { far = true, transparency = 0.72 })
		rod(out, "TopRail" .. i, M(i * 20, 60, 1.8), M(i * 20 + 20, 60, 1.8), 4, C.metal, "Metal", { far = true })
	end
	for k = 0, 20 do
		post(out, "FencePost" .. k, k * 5, 60, 0, 1.85, 0.06, C.metal, "Metal", { full = true })
	end
	local _ = rand
end

-- ---------------------------------------------------------------- the meadow (x 25..60, z 18..48)
local function meadowDecor(out: List, rand: () -> number)
	local mx, mz = Preserve.MEADOW.x, Preserve.MEADOW.z
	local cols, rows = 9, 8
	local k = 0
	for i = 1, cols do
		for j = 1, rows do
			k += 1
			local x = mx[1] + (i - 0.5) * (mx[2] - mx[1]) / cols + between(rand, -1.2, 1.2)
			local z = mz[1] + (j - 0.5) * (mz[2] - mz[1]) / rows + between(rand, -1.1, 1.1)
			local w, d = between(rand, 4.2, 5.6), between(rand, 3.6, 5.0)
			local h = between(rand, 1.2, 1.9) -- big bluestem and switchgrass stand 0.9 to 1.5 m in late summer; the masses' tops reach 0.8 to 1.2
			blob(out, `Grass{k}`, x, z, h * 0.22, w, h, d, pick(C.grass, rand), { far = true, full = k % 3 == 0 }, between(rand, 0, 180))
		end
	end
	-- drifts of flowers over the grass: goldenrod, coneflower, milkweed, black-eyed Susan, Queen Anne's lace, bergamot
	local kinds = { "goldenrod", "goldenrod", "coneflower", "milkweed", "susan", "lace", "bergamot", "goldenrod" }
	for d = 1, 40 do
		local x = between(rand, mx[1] + 1, mx[2] - 1)
		local z = between(rand, mz[1] + 1, mz[2] - 1)
		local w = between(rand, 1.0, 2.6)
		local kind = pick(kinds, rand)
		blob(out, `Drift{d}`, x, z, between(rand, 0.86, 1.08), w, 0.22, w * between(rand, 0.5, 0.9), (C.flowers :: any)[kind], { far = d <= 30, full = d % 2 == 0 }, between(rand, 0, 180))
	end
	-- a few milkweed clumps' broad leaves, the ant hills by the path and the bee hotel on its post (near detail)
	for a = 1, 4 do
		local x, z = between(rand, mx[1] + 2, mx[1] + 8), between(rand, mz[1] + 1, mz[2] - 2)
		blob(out, "AntHill" .. a, x, z, 0, 0.5, 0.24, 0.5, "7a6448", { full = true })
	end
	post(out, "HotelPost", 26.2, 33, 0, 1.3, 0.1, C.boardDark, "Wood", { full = true })
	block(out, "BeeHotel", 25.95, 26.45, 32.85, 33.15, 1.3, 1.75, "a5865d", "WoodPlanks", { far = true, full = true })
end

-- ---------------------------------------------------------------- the pond (x 62..78, z 30..44) and the boardwalk along its south (z 30)
local function pondDecor(out: List, rand: () -> number)
	local P = Preserve.POND
	-- the mud margin, the water's surface (flat lenses whose tops lie a few millimetres over the grass), the lily rafts
	add(out, "Margin", Vector3.new((P.rx * 2 + 1.6) * 100, 6, (P.rz * 2 + 1.6) * 100), M(P.x, P.z, -0.024), C.mud, "Mud", { far = true }, "Ellipsoid")
	add(out, "Water", Vector3.new(P.rx * 2 * 100, 6, P.rz * 2 * 100), M(P.x, P.z, -0.018), C.water, "SmoothPlastic", { far = true, reflectance = 0.32 }, "Ellipsoid")
	for i = 1, 3 do
		local a = between(rand, 0, 2 * math.pi)
		local r = between(rand, 0.25, 0.6)
		blob(out, "LilyRaft" .. i, P.x + math.cos(a) * P.rx * r, P.z + math.sin(a) * P.rz * r, 0.013, between(rand, 1.2, 2.4), 0.02, between(rand, 0.9, 1.8), C.lily, { far = true })
	end
	for i = 1, 10 do
		local a = between(rand, 0, 2 * math.pi)
		local r = between(rand, 0.2, 0.75)
		local s = between(rand, 0.18, 0.3)
		add(out, "Lily" .. i, Vector3.new(1.2, s * 100, s * 100), M(P.x + math.cos(a) * P.rx * r, P.z + math.sin(a) * P.rz * r, 0.016), "56833f", "SmoothPlastic",
			{ full = true }, "Cylinder", Vector3.new(0, 0, 90))
	end
	-- the cattails and reeds round the north and east margins (none along the boardwalk), their brown heads near
	local m = 0
	for i = 1, 18 do
		local a = math.rad(between(rand, -35, 215)) -- from the east round the north to the west
		local x = P.x + math.cos(a) * (P.rx - 0.4)
		local z = P.z + math.sin(a) * (P.rz - 0.4)
		if z > P.z - P.rz * 0.6 then
			m += 1
			local h = between(rand, 1.5, 2.3)
			blob(out, "Reeds" .. m, x, z, h * 0.42, between(rand, 1.0, 1.9), h, between(rand, 0.8, 1.4), pick(C.reed, rand), { far = m <= 12, full = m > 9 })
			for c = 1, 2 do
				post(out, `Cattail{m}_{c}`, x + between(rand, -0.4, 0.4), z + between(rand, -0.3, 0.3), h * 0.62, h * 0.62 + 0.22, 0.03, C.cattail, "Fabric", { full = true })
			end
		end
	end
	-- the boardwalk: a deck 1.5 m wide 40 cm over the ground on posts, its boards' seams near; the dipping platform out over the water with rails on three sides
	block(out, "Boardwalk", 61, 79, 29.25, 30.75, 0.34, 0.4, C.board, "WoodPlanks", { far = true })
	for k = 0, 6 do
		local x = 61.2 + k * 2.93
		post(out, `WalkPost{k}a`, x, 29.3, 0, 0.34, 0.12, C.boardDark, "Wood")
		post(out, `WalkPost{k}b`, x, 30.7, 0, 0.34, 0.12, C.boardDark, "Wood", { full = true })
	end
	for k = 1, 14 do
		local x = 61 + k * 18 / 15
		block(out, "Seam" .. k, x - 0.006, x + 0.006, 29.26, 30.74, 0.4, 0.402, "5a4a38", "WoodPlanks", { full = true })
	end
	block(out, "Platform", 68, 71, 30.75, 33.25, 0.34, 0.4, C.board, "WoodPlanks", { far = true })
	block(out, "RailWest", 68, 68.06, 30.75, 33.25, 0.4, 1.0, C.boardDark, "Wood")
	block(out, "RailEast", 70.94, 71, 30.75, 33.25, 0.4, 1.0, C.boardDark, "Wood")
	block(out, "RailNorth", 68, 71, 33.19, 33.25, 0.85, 0.95, C.boardDark, "Wood", { far = true })
	for k, x in { 68.1, 70.9 } do post(out, "PlatformPost" .. k, x, 33.1, -0.3, 0.34, 0.12, C.boardDark, "Wood", { full = true }) end
end

-- ---------------------------------------------------------------- the woodland (x 0..18, z 5..55): the bur oak, the maples, the black cherry, the log pile
local function woodlandDecor(out: List, rand: () -> number)
	local O = Preserve.OAK
	-- the veteran bur oak: a short massive bole, its root flare, five great limbs and a broad crown
	post(out, "OakBole", O.x, O.z, 0, 5.2, O.trunk, C.oakBark, "Wood", { far = true, shadow = true })
	for k = 1, 3 do
		local a = (k - 1) * 2.1 + 0.4
		rod(out, "OakFlare" .. k, M(O.x + math.cos(a) * 1.1, O.z + math.sin(a) * 1.1, 0.05), M(O.x, O.z, 1.2), 70, C.oakBark, "Wood", { far = k == 1 })
	end
	for k = 1, 5 do
		local a = (k - 1) / 5 * 2 * math.pi + between(rand, -0.3, 0.3)
		local reach = between(rand, 3.0, 4.8) -- (each ends inside the crown's masses: a bur oak's great limbs spread low and wide under its crown)
		rod(out, "OakLimb" .. k, M(O.x, O.z, 4.4), M(O.x + math.cos(a) * reach, O.z + math.sin(a) * reach, between(rand, 8.6, 10.4)), between(rand, 38, 55), C.oakBark, "Wood",
			{ far = k <= 3, full = k > 4 })
	end
	for k = 1, 10 do
		local a = (k - 1) / 9 * 2 * math.pi + between(rand, -0.3, 0.3)
		local r = if k == 1 then 0 else between(rand, 4.5, 7.8)
		local w = if k == 1 then 13 else between(rand, 7.0, 10.0)
		local h = if k == 1 then 8.5 else between(rand, 4.6, 6.8)
		local y = if k == 1 then 14.6 else between(rand, 11.5, 15.8)
		blob(out, "OakCrown" .. k, O.x + math.cos(a) * r, O.z + math.sin(a) * r, math.min(y, O.height - h / 2), w, h, w * between(rand, 0.85, 1.1), pick(C.oakCrown, rand),
			{ far = true, full = k > 7 })
	end
	-- the maples and the black cherry at the wood's edge
	tree(out, "Maple1", rand, 5.5, 18, 15, 10, 4.5, 0.48, C.mapleBark, C.mapleCrown, 5, 4, 4)
	tree(out, "Maple2", rand, 11, 10.5, 13, 9, 3.8, 0.42, C.mapleBark, C.mapleCrown, 4, 4, 3)
	tree(out, "Maple3", rand, 6, 49, 16, 11, 5, 0.52, C.mapleBark, C.mapleCrown, 5, 4, 4)
	tree(out, "Maple4", rand, 3.5, 33, 14, 9.5, 4.2, 0.45, C.mapleBark, C.mapleCrown, 4, 4, 3)
	tree(out, "Cherry", rand, 17.5, 27.5, 12, 7, 4.2, 0.36, C.cherryBark, C.cherryCrown, 4, 3, 3)
	-- the understorey: spicebush and dogwood masses along the edge
	for k = 1, 10 do
		local x, z = between(rand, 1.5, 19.5), between(rand, 7, 54)
		local w = between(rand, 1.6, 3.2)
		local h = between(rand, 1.4, 2.6)
		blob(out, "Shrub" .. k, x, z, h * 0.4, w, h, w * between(rand, 0.8, 1.2), pick(C.shrub, rand), { far = k <= 6, full = k > 7 })
	end
	-- the log pile (x 8..12, z 28..31): cut lengths of oak and maple lying east-west, the lower course and two above it
	local L = Preserve.LOG_PILE
	local logs = 0
	for course = 1, 3 do
		local count = 4 - course
		for k = 1, count do
			logs += 1
			local z = L.z[1] + 0.5 + (k - 0.5) * (L.z[2] - L.z[1] - 1) / count + (course - 1) * 0.15
			local dia = between(rand, 0.26, 0.42)
			local y = dia / 2 + (course - 1) * 0.3
			rod(out, "Log" .. logs, M(L.x[1] + between(rand, 0, 0.4), z, y), M(L.x[2] - between(rand, 0, 0.4), z + between(rand, -0.2, 0.2), y), dia * 100,
				if logs % 2 == 0 then C.oakBark else C.mapleBark, "Wood", { far = course == 1, full = course == 3 })
		end
	end
end

-- ---------------------------------------------------------------- the stone retaining wall (x 92..94, z 5..55) and the bank it holds
local function wallDecor(out: List, rand: () -> number)
	local W = Preserve.WALL
	local n = 20
	for k = 1, n do
		local z0 = W.z[1] + (k - 1) * (W.z[2] - W.z[1]) / n
		local z1 = z0 + (W.z[2] - W.z[1]) / n
		local h = W.height + between(rand, -0.08, 0.1)
		block(out, "Wall" .. k, W.x[1], W.x[2], z0, z1, 0, h, pick(C.limestone, rand), "Limestone", { far = true, shadow = true })
		if k % 2 == 1 then
			block(out, "Cap" .. k, W.x[1] - 0.06, W.x[2] + 0.02, z0, z0 + (W.z[2] - W.z[1]) / n * 2, h, h + 0.1, pick(C.limestone, rand), "Rock")
		end
	end
	-- the stones of its sunny west face (near detail): proud, odd-sized, in rough courses
	for k = 1, 30 do
		local z = between(rand, W.z[1] + 0.5, W.z[2] - 0.5)
		local y = between(rand, 0.12, W.height - 0.12)
		local w, h = between(rand, 0.3, 0.6), between(rand, 0.14, 0.26)
		block(out, "Stone" .. k, W.x[1] - 0.03, W.x[1] + 0.02, z - w / 2, z + w / 2, y - h / 2, y + h / 2, pick(C.limestone, rand), "Rock", { full = true })
	end
	-- the bank it holds: the ground east of it stands 1.2 m up, to the apartments' fence
	for j = 0, 2 do
		block(out, "Bank" .. j, W.x[2], 100, W.z[1] + j * 50 / 3, W.z[1] + (j + 1) * 50 / 3, 0, W.height, C.bank, "Grass", { far = true })
	end
end

-- ---------------------------------------------------------------- the bramble and the scrub on the railway bank's foot (x 18..92, z 50..60)
local function scrubDecor(out: List, rand: () -> number)
	local S = Preserve.SCRUB
	local k = 0
	for row = 1, 2 do
		local count = if row == 1 then 16 else 14
		for i = 1, count do
			k += 1
			local x = S.x[1] + (i - 0.5) * (S.x[2] - S.x[1]) / count + between(rand, -1.5, 1.5)
			local z = if row == 1 then between(rand, 52.5, 55.5) else between(rand, 56, 58.6)
			local w = between(rand, 3.2, 5.6)
			local h = between(rand, 1.5, 3.1)
			blob(out, "Bramble" .. k, x, z, h * 0.4, w, h, between(rand, 2.4, 3.6), pick(C.bramble, rand), { far = true, full = k % 4 == 0 }, between(rand, 0, 180))
		end
	end
	for i = 1, 8 do
		local x = between(rand, S.x[1] + 2, S.x[2] - 2)
		block(out, "Ivy" .. i, x - between(rand, 0.8, 1.6), x + between(rand, 0.8, 1.6), 59.9, 59.98, 0, between(rand, 1.0, 1.75), C.ivy, "LeafyGrass", { full = true })
	end
end

-- ---------------------------------------------------------------- the compost bays and the tool shed (x 2..8, z 3..9)
local function compostDecor(out: List, rand: () -> number)
	-- the shed: 2.4 by 3 m, a pent roof falling to the west, its door facing east
	block(out, "Shed", 2, 4.4, 5.6, 8.6, 0, 2.05, "7a6046", "WoodPlanks", { far = true, shadow = true })
	block(out, "ShedRoof", 1.8, 4.6, 5.4, 8.8, 2.05, 2.15, "3a3d3f", "Slate", { far = true })
	block(out, "ShedDoor", 4.4, 4.44, 6.5, 7.4, 0, 1.85, C.trim, "WoodPlanks", { far = true })
	block(out, "ShedWindow", 2.6, 3.6, 8.6, 8.62, 1.1, 1.6, C.glass, "SmoothPlastic", { full = true, reflectance = 0.1 })
	block(out, "Cobweb", 2.65, 3.3, 8.62, 8.625, 1.35, 1.58, "d9d6cc", "SmoothPlastic", { full = true, transparency = 0.55 }) -- Nathan's shed: its window cobwebbed
	-- three bays of pallets: the back, four sides, and three heaps of rot from fresh to crumbled
	block(out, "BayBack", 4.8, 7.9, 3.4, 3.5, 0, 1.0, "a08b69", "WoodPlanks", { far = true })
	for k = 0, 3 do
		local x = 4.8 + k * 1.03
		block(out, "BaySide" .. k, x, x + 0.06, 3.5, 4.7, 0, 1.0, "9a8564", "WoodPlanks", { far = true })
	end
	for k = 1, 3 do
		local x = 4.8 + (k - 0.5) * 1.03
		blob(out, "Heap" .. k, x, 4.05, 0.25, 0.9, 0.5 + k * 0.1, 1.0, ({ "6b5a3a", "4f3f2c", "3b2f24" })[k], { far = true })
		for s = 1, 3 do
			block(out, `BaySlat{k}_{s}`, x - 0.5, x + 0.5, 3.48, 3.5, 0.15 + s * 0.24, 0.2 + s * 0.24, "7d6a50", "WoodPlanks", { full = true })
		end
	end
	-- a wheelbarrow by the bays
	block(out, "Barrow", 6.4, 7.4, 5.4, 6.0, 0.35, 0.65, "4f6a7a", "Metal", { full = true })
	post(out, "BarrowWheel", 7.5, 5.7, 0, 0.36, 0.36, C.black, "Fabric", { full = true })
	local _ = rand
end

-- ---------------------------------------------------------------- the railway embankment (z 60..64.4)
local function railwayDecor(out: List, rand: () -> number)
	local R = Preserve.RAILWAY
	local x0, x1 = R.x[1], R.x[2]
	local n = 6
	local p = math.atan2(R.height, R.crest - R.foot)
	local slopeLen = math.sqrt(R.height ^ 2 + (R.crest - R.foot) ^ 2)
	for k = 1, n do
		local a = x0 + (k - 1) * (x1 - x0) / n
		local b = a + (x1 - x0) / n
		-- the bank's face, rising northward from the fence to the crest (a slab turned to its slope)
		local mid = M((a + b) / 2, (R.foot + R.crest) / 2, R.height / 2)
		add(out, "Bank" .. k, Vector3.new((b - a) * 100, 30, slopeLen * 100), mid + Vector3.new(0, -15 * math.cos(p), -15 * math.sin(p)), if k % 2 == 0 then C.bank else "6f8547",
			"Grass", { far = true }, nil, Vector3.new(math.deg(p), 0, 0))
		block(out, "Crest" .. k, a, b, R.crest, 64.4, 0, R.height, C.bank, "Grass", { far = true })
		block(out, "Ballast" .. k, a, b, R.track - 1.6, 64.4, R.height, R.height + 0.3, C.ballast, "Pebble", { far = true }) -- (to the edge of the world, LIMIT, on its north)
		block(out, "Sleepers" .. k, a, b, R.track - 1.3, R.track + 0.95, R.height + 0.3, R.height + 0.42, C.sleeper, "Wood", { far = true })
		for r, side in { -1, 1 } do
			local z = R.track + side * R.gauge / 2
			block(out, `Rail{k}_{r}`, a, b, z - 0.035, z + 0.035, R.height + 0.42, R.height + 0.57, C.rail, "Metal")
		end
	end
	-- the covered ways at each end of the line, where it runs under the streets beyond the preserve (16 m each: a train comes and goes inside them, never at
	-- the edge of the world, Client/TrainPass): the deck, the wall on the preserve's side and the portal's face round the opening
	for i, span in { { x0, x0 + 16 }, { x1 - 16, x1 } } do
		local inner = if i == 1 then span[2] else span[1]
		block(out, "CoverDeck" .. i, span[1], span[2], 61.8, 64.4, R.height + 5.0, R.height + 5.6, "8b877e", "Concrete", { far = true, shadow = true })
		block(out, "CoverWall" .. i, span[1], span[2], 61.8, 62.2, R.height, R.height + 5.0, "8f8a80", "Concrete", { far = true })
		block(out, "PortalDark" .. i, inner - 0.02, inner + 0.02, 62.2, 64.4, R.height, R.height + 5.0, "1d1f20", "SmoothPlastic", { far = true, transparency = 0.25 })
		block(out, "Parapet" .. i, span[1], span[2], 61.8, 62.1, R.height + 5.6, R.height + 6.6, "8b877e", "Concrete", { full = true })
	end
	-- a signal by the line
	post(out, "SignalPost", 88, 62.4, R.height, R.height + 4.0, 0.12, C.black, "Metal", { full = true })
	block(out, "SignalHead", 87.8, 88.2, 62.3, 62.5, R.height + 3.2, R.height + 3.9, C.black, "Metal", { full = true })
	local _ = rand
end

-- ---------------------------------------------------------------- the city: the street to the south, the canal to the west, the apartments to the east
local function southDecor(out: List, rand: () -> number)
	local G = Preserve.GATE
	-- the railings along the street (z 0), black iron you can see through, with the gate's two leaves and its piers
	local spans = { { 0, 14 }, { 14, 28 }, { 28, G.x[1] - 0.25 }, { G.x[2] + 0.25, 66 }, { 66, 86 }, { 86, 100 } } -- (each under 20.48 m: a part is at most 2,048 studs)
	for i, s in spans do
		block(out, "Railing" .. i, s[1], s[2], -0.01, 0.01, 0, 1.6, C.railing, "Metal", { far = true, transparency = 0.6 })
		block(out, "RailTop" .. i, s[1], s[2], -0.025, 0.025, 1.55, 1.62, C.railing, "Metal")
	end
	block(out, "PierWest", G.x[1] - 0.25, G.x[1], -0.15, 0.15, 0, 1.9, "8d8478", "Brick", { far = true })
	block(out, "PierEast", G.x[2], G.x[2] + 0.25, -0.15, 0.15, 0, 1.9, "8d8478", "Brick", { far = true })
	block(out, "GateWest", G.x[1], (G.x[1] + G.x[2]) / 2 - 0.02, -0.02, 0.02, 0.05, 1.6, C.railing, "Metal", { transparency = 0.45 })
	block(out, "GateEast", (G.x[1] + G.x[2]) / 2 + 0.02, G.x[2], -0.02, 0.02, 0.05, 1.6, C.railing, "Metal", { transparency = 0.45 })
	-- the pavements and the road between them, in lengths of 20 m
	for k = 0, 5 do
		local a, b = -12 + k * 19.5, -12 + (k + 1) * 19.5
		block(out, "Pavement" .. k, a, b, -2.2, 0, -0.02, 0.12, C.pavement, "Concrete", { far = true })
		block(out, "Road" .. k, a, b, -9.2, -2.2, -0.04, 0, C.asphalt, "Concrete", { far = true })
		block(out, "PavementFar" .. k, a, b, -11, -9.2, -0.02, 0.12, C.pavement, "Concrete", { far = true })
		for d = 0, 2 do
			local x = a + d * 6.5 + 1
			block(out, `Dash{k}_{d}`, x, x + 3, -5.75, -5.65, 0, 0.004, "d8d2b8", "SmoothPlastic", { full = true })
		end
	end
	-- the terrace across the street: shops under two or three storeys, one row of windows a storey
	local x = -12
	local i = 0
	while x < 104 do
		i += 1
		local w = between(rand, 8, 14)
		local x1 = math.min(x + w, 105)
		local h = between(rand, 7, 11.5)
		block(out, "Terrace" .. i, x, x1, -14.8, -11.4, 0, h, pick(C.shop, rand), "Brick", { far = true })
		block(out, "Cornice" .. i, x, x1, -11.6, -11.4, h - 0.5, h - 0.3, "d8d0c0", "Concrete", { far = true })
		block(out, "Shopfront" .. i, x + 0.4, x1 - 0.4, -11.42, -11.38, 0.4, 3.0, C.window, "SmoothPlastic", { far = true, reflectance = 0.15 })
		block(out, "Sign" .. i, x + 0.4, x1 - 0.4, -11.46, -11.4, 3.05, 3.55, ({ "2f4f6f", "7a2e2e", "2e5a3a", "c9a227", "3a3a3a" })[1 + math.floor(rand() * 5)], "SmoothPlastic", { full = true })
		local storeys = math.floor((h - 3.4) / 3)
		for s = 1, storeys do
			block(out, `Windows{i}_{s}`, x + 0.8, x1 - 0.8, -11.42, -11.38, 3.6 + (s - 1) * 3, 3.6 + (s - 1) * 3 + 1.5, C.window, "SmoothPlastic", { full = s > 1, reflectance = 0.1 })
		end
		-- (near) the brick piers that divide each band into windows, up through every storey
		if storeys > 0 then
			local panes = math.max(2, math.floor((x1 - x) / 2.6))
			for k = 1, panes - 1 do
				local px = x + 0.8 + k * (x1 - x - 1.6) / panes
				block(out, `Pier{i}_{k}`, px - 0.3, px + 0.3, -11.44, -11.36, 3.5, 3.6 + storeys * 3, pick(C.shop, rand), "Brick", { full = true })
			end
		end
		x = x1
	end
	-- honey locusts along the near pavement, and its street lamps
	for k, tx in { 8, 30, 62, 84 } do
		post(out, "StreetTreeTrunk" .. k, tx, -1.4, 0, 3.4, 0.24, "4a4038", "Wood", { far = true })
		blob(out, "StreetTree" .. k, tx, -1.4, 5.2, 5.5, 4.2, 5.0, "7b9a48", { far = true })
	end
	for k, lx in { 18, 52, 76 } do
		post(out, "StreetLamp" .. k, lx, -1.9, 0, 5.5, 0.14, C.black, "Metal", { full = true })
	end
end

local function westDecor(out: List, rand: () -> number)
	-- the hedge on the preserve's west boundary, in six lengths, 2.2 m tall
	for k = 0, 5 do
		block(out, "Hedge" .. k, -0.2, 1.1, k * 10, k * 10 + 10, 0, between(rand, 2.0, 2.4), C.hedge, "LeafyGrass", { far = true })
	end
	-- beyond it the towpath, the canal (its water 1.2 m down between stone copings) and the warehouses on the far side
	for k = 0, 3 do
		local z0, z1 = -14 + k * 19.5, -14 + (k + 1) * 19.5
		block(out, "Towpath" .. k, -3.2, -0.2, z0, z1, -0.03, 0, C.gravel, "Pebble", { far = true })
		block(out, "Canal" .. k, -10, -3.4, z0, z1, -1.25, -1.2, C.canal, "SmoothPlastic", { far = true, reflectance = 0.25 })
		block(out, "CopingNear" .. k, -3.4, -3.2, z0, z1, -1.2, 0.02, C.coping, "Concrete")
		block(out, "CopingFar" .. k, -10.2, -10, z0, z1, -1.2, 0.3, C.coping, "Concrete")
	end
	local z = -14
	local i = 0
	while z < 64 do
		i += 1
		local d = between(rand, 12, 20)
		local z1 = math.min(z + d, 64)
		local h = between(rand, 7, 10.5)
		block(out, "Warehouse" .. i, -14.2, -10.4, z, z1, 0, h, pick(C.brick, rand), "Brick", { far = true })
		block(out, "WarehouseWindows" .. i, -10.42, -10.38, z + 1, z1 - 1, h * 0.55, h * 0.55 + 1.4, C.window, "SmoothPlastic", { full = true })
		z = z1
	end
end

local function eastDecor(out: List, rand: () -> number)
	-- the apartments' fence (x 100) on the bank's top, and the backs of four blocks behind it: brick, a storey every 3 m, a band of windows a storey, balconies
	for k = 0, 2 do
		block(out, "AptFence" .. k, 99.99, 100.01, 5 + k * 50 / 3, 5 + (k + 1) * 50 / 3, 1.2, 3.0, C.metal, "Metal", { far = true, transparency = 0.72 })
	end
	local blocks = { { -4, 14, 15 }, { 16, 33, 18 }, { 35, 50, 12 }, { 52, 59.6, 15 } } -- (the last stops short of the railway's embankment at z 60)
	for b, B in blocks do
		local z0, z1, h = B[1], B[2], B[3]
		local base = if z0 >= 5 and z1 <= 55 then 1.2 else 0
		local brick = pick(C.brick, rand)
		block(out, "Apartment" .. b, 101, 105.7, z0, z1, 0, base + h, brick, "Brick", { far = true, shadow = true })
		for k = 1, math.floor((z1 - z0) / 3) - 1 do -- (near) the piers between the windows
			local zc = z0 + 0.8 + k * (z1 - z0 - 1.6) / math.floor((z1 - z0) / 3)
			block(out, `AptPier{b}_{k}`, 100.95, 101.0, zc - 0.25, zc + 0.25, base + 0.8, base + h - 0.4, brick, "Brick", { full = true })
		end
		block(out, "Parapet" .. b, 100.9, 105.7, z0, z1, base + h, base + h + 0.5, "6f6a64", "Concrete")
		local floors = math.floor(h / 3)
		for f = 1, floors do
			local y = base + (f - 1) * 3 + 0.9
			block(out, `AptWindows{b}_{f}`, 100.97, 101.0, z0 + 0.8, z1 - 0.8, y, y + 1.45, C.window, "SmoothPlastic", { far = true, full = f % 2 == 0, reflectance = 0.12 })
			if f > 1 then
				for s = 1, 2 do
					local zc = z0 + (z1 - z0) * (if s == 1 then 0.3 else 0.72)
					block(out, `Balcony{b}_{f}_{s}`, 99.9, 101, zc - 1.4, zc + 1.4, y - 0.95, y - 0.85, C.balcony, "Concrete", { full = true })
					block(out, `BalconyRail{b}_{f}_{s}`, 99.88, 99.92, zc - 1.4, zc + 1.4, y - 0.85, y - 0.05, C.railing, "Metal", { full = true, transparency = 0.5 })
				end
			end
		end
	end
end

local function towersDecor(out: List, rand: () -> number)
	-- the city's towers beyond the railway: impostors at the edge (see the header), hazy, one with its own water tower on the roof's line
	local spots = { -9, 6, 21, 58, 77, 96 }
	for i, x in spots do
		local w = between(rand, 2.4, 5.0)
		local h = between(rand, 12, 20) -- (a part is at most 2,048 studs)
		block(out, "Tower" .. i, x - w / 2, x + w / 2, 64.4, 64.8, 0, h, pick(C.tower, rand), "Concrete", { far = true })
		block(out, "TowerBands" .. i, x - w / 2 + 0.2, x + w / 2 - 0.2, 64.39, 64.4, h * 0.2, h * 0.92, "7f8a98", "SmoothPlastic", { full = true, transparency = 0.35, reflectance = 0.2 })
	end
	-- (an impostor too: a rooftop water tank on its building, drawn at the towers' scale)
	post(out, "WaterTowerTank", 40, 64.42, 6.6, 7.5, 0.72, "8a6e55", "WoodPlanks", { far = true })
	block(out, "WaterTowerLegs", 39.75, 40.25, 64.4, 64.6, 4.2, 6.6, "4a4642", "Metal", { far = true, transparency = 0.4 })
	block(out, "WaterTowerRoof", 39.6, 40.4, 64.4, 64.8, 7.5, 7.75, "4a4642", "Metal")
	block(out, "WaterTowerBlock", 38.4, 41.6, 64.4, 64.8, 0, 4.2, pick(C.tower, rand), "Concrete", { far = true })
end

-- ---------------------------------------------------------------- the zones' lists
local MAKERS: { [string]: (List, () -> number) -> () } = {
	hut = hutDecor, hut_garden = gardenDecor, bench = benchDecor, ground = groundDecor, meadow = meadowDecor, pond = pondDecor, compost = compostDecor,
	woodland = woodlandDecor, wall = wallDecor, scrub = scrubDecor, city_south = southDecor, city_west = westDecor, city_east = eastDecor, railway = railwayDecor,
	towers = towersDecor,
}
local SALT: { [string]: number } = {
	hut = 1, hut_garden = 2, bench = 3, ground = 4, meadow = 5, pond = 6, compost = 7, woodland = 8, wall = 9, scrub = 10, city_south = 11, city_west = 12,
	city_east = 13, railway = 14, towers = 15,
}

-- Whether a zone has a look here.
function PreserveLook.knows(zoneId: string): boolean
	return MAKERS[zoneId] ~= nil
end

local cache: { [string]: { Drawn } } = {}

-- The zone's drawn records for a seed (the zone's own: WorldMap.seed(world seed, zone id)): the same list for the same zone and seed; do not change it.
function PreserveLook.records(zoneId: string, seed: number): { Drawn }
	local key = zoneId .. "/" .. tostring(seed)
	local cached = cache[key]
	if cached ~= nil then return cached end
	local make = MAKERS[zoneId]
	assert(make ~= nil, "no look for the preserve's zone " .. zoneId)
	local out: List = {}
	make(out, rng(seed, SALT[zoneId]))
	for _, d in out do table.freeze(d) end
	cache[key] = out
	return out
end

-- How many records a zone has at each level: every record, the low tier's, the far look at the full tier and at the low tier.
function PreserveLook.counts(zoneId: string, seed: number): (number, number, number, number)
	local full, low, far, farLow = 0, 0, 0, 0
	for _, d in PreserveLook.records(zoneId, seed) do
		full += 1
		if not d.full then low += 1 end
		if d.far then
			far += 1
			if not d.full then farLow += 1 end
		end
	end
	return full, low, far, farLow
end

return table.freeze(PreserveLook)
