--!strict
-- The ranger hut and its garden, walkable (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B round 1): the preserve's first home ranges at full spider detail. Pure
-- data and pure generators, as World/Garden's are for the test garden: the regions (`author`), their physical boxes (`pieces`), their drawn looks (`decor`), and
-- the life the garden's cells hold (`prey`, `bugs`, `bestiary`, `ambient`, `plants`), all from the region and its seed, so the server, every client and the CLI
-- tests get the same hut. Nothing here requires World/WorldMap or World/Garden (they require this, through World/Region and World/WorldMap): its types are its own,
-- shaped as theirs.
--
-- Studs, the sill's frame (World/Preserve: x east, -z north out of the window, +z into the hut; the sill's floor at y 0, the hut's floor FLOOR, the garden's
-- ground GROUND). True scale: a stud is a centimetre.
--
-- The hut inside (3.5 by 3 m outside, 2.93 by 2.43 m between its linings, x -146.5..146.5, z 12.5..255.5, its floor 70 cm under the sill):
--   hut_floor_a..i .. the floorboards in nine cells of about a metre (a region whole inside the streaming radius from anywhere on it), the skirting, and the walls'
--                     linings to WALL_TOP (a metre and a third over the floor: what the regions hold; the upper walls and the ceiling are drawn only, Phase B round 3
--                     with the volunteers' back room). The apron under the sill in hut_floor_b: the sill's front face goes on down to the floor.
--   hut_desk ........ a desk east of the window against the north wall (90 by 60 cm, its top 74 cm over the floor), its drawer and the runner under it (the gap between
--                     them is a retreat, hut_desk_drawer), a lamp, a notebook, a mug, three specimen jars and a hand lens; and the north wall's lining east of the window.
--   hut_board ....... the notice board on two battens west of the window (the gap behind it is a retreat, hut_board_gap), and the lining west of the window.
--   hut_shelf ....... a low bookcase of field guides against the west wall.
--   hut_chair ....... the chair at the desk.
--   hut_door ........ the door in the south wall, shut, with a gap of DOOR_GAP under its leaf (a way out for a spider), the threshold, the step outside and the gravel
--                     at its foot (the path on round the hut is the next round's corridor).
--   hut_window ...... the window over the sill (its glass, drawn by the sill's Decor, and its reveal and head).
-- The way out (the window, propped open after the nursery, Client/HutLife):
--   hut_outer_sill .. the window's outer sill board, level with the sill, and the green casing on it.
--   hut_wall_w, hut_wall_mid, hut_wall_e .. the hut's log wall outside under and beside the window (walkable to OUT_TOP) and the corners' log ends; the base's lip
--                     at its foot is the garden's (row a's cells).
--   hut_bench ....... the bench under the window (its seat 44 cm over the ground, 40 under the sill: a short line drop from the outer sill's edge, or a walk down the logs).
--   hut_butt ........ the water butt on its stand east of the window.
-- The hut garden's core (home range 2, 4 by 4 m in front of the north window, x -200..200, z -16..-416), an American garden in late summer:
--   garden_a1..d4 ... sixteen cells of a metre (rows a to d out from the wall, columns 1 to 4 west to east): the lawn, the gravel drip strip along the hut's foot,
--                     the gravel path in from the east and on north, its brick edging, a raised pollinator bed (common milkweed, purple coneflower, wild bergamot
--                     (bee balm) and Canada goldenrod at true size, under shredded-bark mulch), a raised herb bed (chives, sage, thyme), a planter trough under the
--                     window raised on two bricks (the gap under it, garden_a1_trough), a flat stone on two rests in the lawn (garden_a3_stone) and a bark chip lying
--                     on two others in the mulch (garden_d3_mulch).
--   garden_pole, garden_feeder .. the bird feeder's pole, climbable, in two regions split at 90 cm, and its tray, hopper and roof at 1.6 m; its seed spilled
--                     on the lawn round its foot (garden_b1's look).
local Preserve = require(script.Parent.Preserve)

local Hut = {}

-- (Shapes as World/WorldMap's and World/Garden's: the modules that require this one check them against their own.)
export type Region = {
	id: string, kind: string, origin: Vector3, bounds: { Vector3 }, seed: number,
	neighbors: { { id: string, a: Vector3, b: Vector3 } }, retreats: { { id: string, min: Vector3, max: Vector3, door: Vector3? } },
	spawn: { pos: Vector3, heading: Vector3 }, clockScale: number,
}
export type Piece = { id: string, lo: Vector3, hi: Vector3, profile: string, color: Color3, material: string? }
export type Drawn = {
	id: string, size: Vector3, at: Vector3, color: Color3, transparency: number?,
	material: string?, shape: string?, turn: Vector3?, full: boolean?, group: string?, shadow: boolean?, far: boolean?, reflectance: number?,
}
export type Box = { min: Vector3, max: Vector3 }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function hex(s: string): Color3
	return Color3.fromHex(s)
end
local MOD = 2147483647
local TAU = 2 * math.pi
-- A Park-Miller stream from a seed and a salt (World/Garden's, Habitat/Shapes.rng's).
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

-- ---------------------------------------------------------------- the numbers
Hut.FLOOR = Preserve.FLOOR_Y -- the hut's floor, 70 cm under the sill
Hut.GROUND = Preserve.GROUND_Y + 0.4 -- the garden's ground, 84.6 cm under the sill: 4 mm over the backdrop's mown grass, so the two never fight
Hut.ROOM = table.freeze({ x0 = -146.5, x1 = 146.5, z0 = 12.5, z1 = 255.5 }) -- between the linings (World/PreserveLook's hut: walls 28.5 cm)
Hut.WALL_TOP = 60 -- the walls inside are walkable this high (1.3 m over the floor): the regions' ceiling; above it the linings are drawn only
Hut.OUT_TOP = 30 -- and outside, beside the window, this high
Hut.WALL_SPLIT = -1.75 -- the north wall's depth is split here: the outside's logs to the south of it are the outside regions', the lining the inside's
Hut.COLS = table.freeze({ -146.5, -48.5, 48.5, 146.5 }) -- the floor's cells
Hut.ROWS = table.freeze({ 12.5, 93.5, 174.5, 255.5 })
Hut.DOOR = table.freeze({ x = 45, jamb = 60, outer = 284, base = 287, leaf = { 258, 262 }, gap = 1.5, step = { top = -77.5, to = 317 }, gravel = 340, top = 30 })
Hut.DOOR_GAP = Hut.DOOR.gap -- 1.5 cm under the leaf: a spider passes, a hand does not
Hut.CORE = table.freeze({ x0 = -200, x1 = 200, z0 = -416, z1 = -16 }) -- the garden's core (x 43.75..47.75 m, z 5..9 m)
Hut.CELL = 100
Hut.BED_TOP = 10 -- the raised beds' soil, over the ground
Hut.EDGING = table.freeze({ top = 12, thick = 2.5 })
Hut.POLLINATOR = table.freeze({ x0 = -20, x1 = 190, z0 = -406, z1 = -220 })
Hut.HERBS = table.freeze({ x0 = -190, x1 = -100, z0 = -406, z1 = -220 })
Hut.PATH = table.freeze({ ew = { x0 = -90, x1 = 200, z0 = -196, z1 = -146 }, ns = { x0 = -90, x1 = -30, z0 = -416, z1 = -146 }, brick = 4, brickH = 4 })
-- The bird feeder: its pole, 4 cm square, from the lawn to `top` (1.6 m), in two regions split at `split` (a region whole inside the streaming radius from anywhere
-- on it); the hopper on its tray at the top under a little roof (the feeder's region).
Hut.POLE = table.freeze({ x = -150, z = -150, half = 2, split = 90, top = 160, tray = { half = 8, thick = 2 }, hopper = { half = 5, h = 16 }, roof = { half = 9, thick = 2 } })
Hut.SASH = table.freeze({ min = v(-8, 0.7, -13.5), max = v(8, 6, -12.5) }) -- the lower sash's gap (the sill's own opening, WindowsillLayout back_frame_*)

local GT = Hut.GROUND
local FL = Hut.FLOOR
local S = GT + Hut.BED_TOP -- the beds' soil

-- The palette (hex by what it is).
local C = {
	floor = "9c7650", floorDark = "7d5c3e", lining = "c8a77a", skirting = "8a6a48", log = "5c4531", logDark = "3f2e20", trim = "3f5a43",
	board = "8a7458", boardDark = "6f5d47", desk = "8e6a45", deskTop = "a67f55", drawer = "86643f", metal = "5a5d60", brass = "b08a3c",
	cork = "b48a5a", batten = "8a6a48", paper = { "f1ece0", "e8e2cf", "f6f1e4", "dfe6e8", "f3e3a8", "cfe3c8" },
	books = { "3e5b46", "7b3b2e", "2f4a6a", "8a6b3a", "5d3f5c", "a0522d", "355e5e", "6b6b3a", "40466e", "8c2f39" },
	lamp = "2f4f3a", mug = "e9e4d8", jar = "cfe0dc", lid = "c9b48a", notebook = "3b4f6b", lens = "dfe8ea", handle = "2a2724",
	chair = "7a5a3c", concrete = "8a867d", gravel = "b3a68a", gravelDark = "938870", soil = "4a3b2c", soilDark = "3d3024", mulch = "4e3524",
	mulchColors = { "5a3c26", "6b4a30", "4a3220", "7a5536", "3f2a1b" }, lawn = "5f7f3f", lawnColors = { "5c8a3a", "6f9a46", "4f7a33", "86a85a", "7d8f48" },
	brick = { "9c4a32", "a65538", "8f4430", "b0603e" }, stone = { "a9a294", "b8ae9c", "9e9482" }, edging = "8a6f4e",
	stem = "5d8a3e", leaf = "4d7a36", leafPale = "6f9a52", milkweedLeaf = "6d8f5a", milkweedUnder = "a8b89a", umbel = "c48a96", pod = "7a9a5a",
	goldenrod = "d4b23a", goldenLeaf = "5a7a3a", petal = "b36a8f", cone = "a5531f", monarda = "a88bb0", sage = "8a9a7a", thyme = "6d7f55", chive = "4f7d35",
	chiveFlower = "b48ac0", butt = "3e5d44", buttLid = "2f4734", seed = { "2a2420", "d8c8a0", "3a3028", "c9b48a" },
}

-- ---------------------------------------------------------------- the regions
local function freeze(r: Region): Region
	table.freeze(r.bounds)
	for _, n in r.neighbors do table.freeze(n) end
	table.freeze(r.neighbors)
	for _, t in r.retreats do table.freeze(t) end
	table.freeze(r.retreats)
	table.freeze(r.spawn)
	return table.freeze(r)
end

-- The seams, by pair: the line where the two regions' walkable surfaces meet (both list it).
type Seam = { a: string, b: string, p: Vector3, q: Vector3 }
local SEAMS: { Seam } = {}
local function seam(a: string, b: string, p: Vector3, q: Vector3)
	table.insert(SEAMS, { a = a, b = b, p = p, q = q })
end

-- The floor's cells: a..i row by row from the north-west.
local FLOOR_IDS = { "a", "b", "c", "d", "e", "f", "g", "h", "i" }
local function floorCell(c: number, r: number): string
	return "hut_floor_" .. FLOOR_IDS[(r - 1) * 3 + c]
end
-- The garden's cells: rows a..d out from the wall, columns 1..4 west to east.
local GARDEN_ROWS = { "a", "b", "c", "d" }
local function gardenCell(r: number, c: number): string
	return `garden_{GARDEN_ROWS[r]}{c}`
end
local function gardenBox(r: number, c: number): (number, number, number, number) -- x0, x1, z0, z1
	local K = Hut.CORE
	return K.x0 + (c - 1) * Hut.CELL, K.x0 + c * Hut.CELL, K.z1 - r * Hut.CELL, K.z1 - (r - 1) * Hut.CELL
end
Hut.gardenBox = gardenBox

-- Whether a garden cell has a tall plant (its region goes higher), and its plant.
local PLANTS: { [string]: { kind: string, x: number, z: number } } = {
	garden_c3 = { kind = "milkweed", x = 50, z = -266 },
	garden_c4 = { kind = "coneflower", x = 150, z = -266 },
	garden_d3 = { kind = "beebalm", x = 70, z = -380 },
	garden_d4 = { kind = "goldenrod", x = 150, z = -362 },
}
Hut.PLANTS = PLANTS

-- Whether a point (x, z) is in a bed (the soil's top is then S), and which.
local function bedAt(x: number, z: number): string?
	for name, b in { pollinator = Hut.POLLINATOR, herbs = Hut.HERBS } :: { [string]: any } do
		if x > b.x0 and x < b.x1 and z > b.z0 and z < b.z1 then return name end
	end
	return nil
end

-- The surface a spider stands on in a garden cell at (x, z): the bed's soil or the ground.
local function groundAt(x: number, z: number): number
	return if bedAt(x, z) ~= nil then S else GT
end

local SPAWNS: { [string]: { number } } = {
	garden_a1 = { -150, -90 }, garden_a2 = { -50, -75 }, garden_a3 = { 20, -90 }, garden_a4 = { 150, -100 },
	garden_b1 = { -130, -185 }, garden_b2 = { -60, -170 }, garden_b3 = { 50, -170 }, garden_b4 = { 150, -170 },
	garden_c1 = { -170, -240 }, garden_c2 = { -60, -260 }, garden_c3 = { 20, -240 }, garden_c4 = { 120, -240 },
	garden_d1 = { -170, -392 }, garden_d2 = { -60, -360 }, garden_d3 = { 10, -340 }, garden_d4 = { 120, -340 },
}

-- The retreats outside: under the trough, under the stone, under the bark chip.
Hut.TROUGH = table.freeze({ x0 = -164, x1 = -100, z0 = -62, z1 = -22, feet = 1.4, foot = 10, top = 30, rim = 2 })
Hut.STONE = table.freeze({ x0 = 57, x1 = 73, z0 = -96, z1 = -80, rest = 2, gap = 1.4, thick = 1.6 })
Hut.CHIP = table.freeze({ x0 = 26, x1 = 40, z0 = -376, z1 = -362, rest = 1.5, gap = 1.4, thick = 0.6 })

local RETREATS: { [string]: { id: string, min: Vector3, max: Vector3, door: Vector3 } } = {
	hut_desk = { id = "hut_desk_drawer", min = v(52, -11.4, 30), max = v(64, -10, 42), door = v(58, -11.1, 72.5) },
	hut_board = { id = "hut_board_gap", min = v(-128, 4, 12.5), max = v(-112, 20, 14.5), door = v(-135.5, 12, 13.5) },
	garden_a1 = { id = "garden_a1_trough", min = v(-140, GT, -48), max = v(-128, GT + 1.4, -36), door = v(-134, GT + 0.5, -63.5) },
	garden_a3 = { id = "garden_a3_stone", min = v(61, GT, -92), max = v(69, GT + 1.4, -84), door = v(65, GT + 0.5, -78) },
	garden_d3 = { id = "garden_d3_mulch", min = v(29, S, -372), max = v(37, S + 1.4, -366), door = v(33, S + 0.5, -360.5) },
}

-- The authored regions of the hut and its garden, for a world seed (`seedOf`: World/WorldMap.seed), in priority order (after the sill, which World/WorldMap
-- authors as it always has: the sill's neighbours are `Hut.SILL_SEAMS`).
function Hut.author(worldSeed: number, seedOf: (number, string) -> number): { Region }
	local list: { Region } = {}
	local byId: { [string]: Region } = {}
	local function region(id: string, kind: string, lo: Vector3, hi: Vector3, spawn: Vector3, heading: Vector3, clock: number)
		local t = RETREATS[id]
		local r = {
			-- (a garden cell's origin is on its ground: its woodlice's)
			id = id, kind = kind, origin = v((lo.X + hi.X) / 2, if kind == "garden_bed" then GT else spawn.Y, (lo.Z + hi.Z) / 2), bounds = { lo, hi }, seed = seedOf(worldSeed, id),
			neighbors = {}, retreats = if t ~= nil then { table.clone(t) } else {}, spawn = { pos = spawn, heading = heading }, clockScale = clock,
		}
		table.insert(list, r :: any)
		byId[id] = r :: any
	end
	local R = Hut.ROOM
	region("hut_window", "hut_window", v(-31, 14, -13.6), v(31, 113.5, 13), v(0, 60, -12.5), v(0, 1, 0), 1.0)
	region("hut_outer_sill", "hut_outer_sill", v(-40, -5, -25.5), v(40, 35, -13.5), v(0, 0, -18), v(0, 0, -1), 1.0)
	region("hut_desk", "hut_desk", v(31, -69, 12.5), v(R.x1, Hut.WALL_TOP, 80), v(80, 4, 45), v(0, 0, -1), 1.0)
	region("hut_board", "hut_board", v(R.x0, -69, 12.5), v(-31, Hut.WALL_TOP, 30), v(-90, 20, 16.5), v(0, 1, 0), 1.0)
	region("hut_shelf", "hut_shelf", v(R.x0, -69, 114), v(-116, 30, 206), v(-132, 10, 160), v(0, 0, -1), 1.0)
	region("hut_chair", "hut_chair", v(64, -69, 86), v(108, 20, 130), v(86, -24, 108), v(0, 0, -1), 1.0)
	region("hut_door", "hut_door", v(-Hut.DOOR.jamb, -88, R.z1), v(Hut.DOOR.jamb, Hut.DOOR.top, Hut.DOOR.gravel), v(0, FL, 272), v(0, 0, 1), 1.0)
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = Hut.COLS[c], Hut.COLS[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
			region(floorCell(c, r), "hut_floor", v(x0, FL - 3, z0), v(x1, Hut.WALL_TOP, z1), v((x0 + x1) / 2, FL, (z0 + z1) / 2), v(0, 0, -1), 1.0)
		end
	end
	region("hut_wall_mid", "hut_wall", v(-31, -71, -24), v(31, -4, -16), v(0, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_w", "hut_wall", v(-185, -71, -26), v(-31, Hut.OUT_TOP, -16), v(-120, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_e", "hut_wall", v(31, -71, -26), v(185, Hut.OUT_TOP, -16), v(120, -20, -16), v(0, 1, 0), 1.0)
	-- (the bench's and the butt's reach down to the ground: a spider at their feet is theirs)
	region("hut_bench", "hut_bench", v(-88, GT - 0.5, -61), v(48, -30, -16), v(-20, -40, -37), v(0, 0, -1), 0.33)
	region("hut_butt", "hut_butt", v(95, GT - 0.5, -82), v(165, 32, -17), v(130, 28.5, -49), v(0, 0, -1), 0.33)
	local P = Hut.POLE
	region("garden_feeder", "garden_pole", v(P.x - 10, GT + P.split, P.z - 10), v(P.x + 10, GT + P.top + P.tray.thick + P.hopper.h + P.roof.thick + 4, P.z + 10),
		v(P.x + P.half, GT + 120, P.z), v(0, 1, 0), 0.33)
	region("garden_pole", "garden_pole", v(P.x - 8, GT + 0.5, P.z - 8), v(P.x + 8, GT + P.split, P.z + 8), v(P.x + P.half, GT + 40, P.z), v(0, 1, 0), 0.33)
	for r = 1, 4 do
		for c = 1, 4 do
			local id = gardenCell(r, c)
			local x0, x1, z0, z1 = gardenBox(r, c)
			local top = if PLANTS[id] ~= nil then GT + 140 else GT + 60
			local s = SPAWNS[id]
			region(id, "garden_bed", v(x0, -87, z0), v(x1, top, z1), v(s[1], groundAt(s[1], s[2]), s[2]), v(0, 0, -1), 0.33)
		end
	end
	-- the seams, both ways
	-- the sill's seams (World/WorldMap lists them on the sill), listed on this side too
	for _, n in Hut.SILL_SEAMS do table.insert(byId[n.id].neighbors, { id = "sill", a = n.a, b = n.b }) end
	for _, s in SEAMS do
		local a, b = byId[s.a], byId[s.b]
		assert(a ~= nil and b ~= nil, `a seam of {s.a} and {s.b}`)
		table.insert(a.neighbors, { id = s.b, a = s.p, b = s.q })
		table.insert(b.neighbors, { id = s.a, a = s.p, b = s.q })
	end
	for _, r in list do freeze(r) end
	return list
end

-- The sill's seams in the preserve (World/WorldMap's sill lists these): out through the sash's gap onto the outer sill, up the window's glass, down its front face
-- to the floor (the apron under it), and along the north wall's lining east to the desk and west to the notice board.
Hut.SILL_SEAMS = table.freeze({
	table.freeze({ id = "hut_outer_sill", a = v(-8, 0, -13.5), b = v(8, 0, -13.5) }),
	table.freeze({ id = "hut_window", a = v(-30, 14, -12.5), b = v(30, 14, -12.5) }),
	table.freeze({ id = "hut_floor_b", a = v(-30, -1, 12.5), b = v(30, -1, 12.5) }),
	table.freeze({ id = "hut_desk", a = v(31, 0, 12.5), b = v(31, 14, 12.5) }),
	table.freeze({ id = "hut_board", a = v(-31, 0, 12.5), b = v(-31, 14, 12.5) }),
})

do
	local R = Hut.ROOM
	-- inside: the floor's cells to one another (flat on the boards, clear of the skirting)
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = Hut.COLS[c], Hut.COLS[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
			if c < 3 then seam(floorCell(c, r), floorCell(c + 1, r), v(x1, FL, z0 + 4), v(x1, FL, z1 - 4)) end
			if r < 3 then seam(floorCell(c, r), floorCell(c, r + 1), v(x0 + 4, FL, z1), v(x1 - 4, FL, z1)) end
		end
	end
	-- the furniture on the floor, and the north wall's linings over the skirting
	seam("hut_desk", "hut_floor_c", v(55, -60, 12.5), v(140, -60, 12.5))
	seam("hut_desk", "hut_floor_b", v(37, FL, 67), v(37, FL, 71)) -- (the front west leg's foot on the floor)
	seam("hut_board", "hut_floor_a", v(-140, -60, 12.5), v(-55, -60, 12.5))
	seam("hut_board", "hut_floor_b", v(-46, -60, 12.5), v(-33, -60, 12.5))
	seam("hut_shelf", "hut_floor_d", v(-145, FL, 116), v(-120, FL, 116))
	seam("hut_shelf", "hut_floor_g", v(-145, FL, 204), v(-120, FL, 204))
	seam("hut_chair", "hut_floor_c", v(67, FL, 89), v(70, FL, 89))
	seam("hut_chair", "hut_floor_f", v(67, FL, 127), v(70, FL, 127))
	seam("hut_door", "hut_floor_h", v(-44, FL, R.z1), v(44, FL, R.z1))
	seam("hut_window", "hut_desk", v(31, 20, 12.5), v(31, Hut.WALL_TOP, 12.5))
	seam("hut_window", "hut_board", v(-31, 20, 12.5), v(-31, Hut.WALL_TOP, 12.5))
	-- outside: the outer sill to the logs under and beside it, the logs to one another, the bench and the butt
	seam("hut_outer_sill", "hut_wall_mid", v(-30, -4, -16), v(30, -4, -16))
	seam("hut_outer_sill", "hut_wall_w", v(-37, -3, -16), v(-37, Hut.OUT_TOP, -16)) -- (the board's end and the casing's side meet the logs beside them)
	seam("hut_outer_sill", "hut_wall_e", v(37, -3, -16), v(37, Hut.OUT_TOP, -16))
	seam("hut_wall_w", "hut_wall_mid", v(-31, -70, -16), v(-31, -4, -16))
	seam("hut_wall_mid", "hut_wall_e", v(31, -70, -16), v(31, -4, -16))
	seam("hut_bench", "hut_wall_mid", v(-30, -40, -16), v(30, -40, -16))
	seam("hut_bench", "garden_a2", v(-80, GT, -55), v(-74, GT, -55))
	seam("hut_bench", "garden_a3", v(33, GT, -55), v(39, GT, -55))
	seam("hut_butt", "garden_a4", v(105, GT, -75), v(155, GT, -75))
	-- the logs' foot onto the base's lip (the garden's)
	seam("hut_wall_w", "garden_a1", v(-160, FL, -16), v(-104, FL, -16))
	seam("hut_wall_w", "garden_a2", v(-95, FL, -16), v(-35, FL, -16))
	seam("hut_wall_mid", "garden_a2", v(-28, FL, -16), v(-2, FL, -16))
	seam("hut_wall_mid", "garden_a3", v(2, FL, -16), v(28, FL, -16))
	seam("hut_wall_e", "garden_a3", v(35, FL, -16), v(95, FL, -16))
	seam("hut_wall_e", "garden_a4", v(104, FL, -16), v(160, FL, -16))
	local P = Hut.POLE
	seam("garden_pole", "garden_b1", v(P.x - P.half, GT, P.z - P.half), v(P.x + P.half, GT, P.z - P.half))
	seam("garden_pole", "garden_feeder", v(P.x + P.half, GT + P.split, P.z - P.half), v(P.x + P.half, GT + P.split, P.z + P.half))
	-- the garden's cells to one another: flat on the ground, or on a bed's soil where a bed lies across the line
	for r = 1, 4 do
		for c = 1, 4 do
			local x0, x1, z0, z1 = gardenBox(r, c)
			if c < 4 then
				local zm = (z0 + z1) / 2
				local y = groundAt(x1, zm)
				-- (row a's line between columns 1 and 2 runs where the trough does not stand; the lines keep 8 studs from the corners, clear of the beds' edging)
				local za, zb = z0 + 8, z1 - 8
				if r == 1 and c == 1 then za, zb = z0 + 8, -70 end
				if r == 1 and c == 3 then za, zb = z0 + 8, -80 end -- (and between columns 3 and 4 where the water butt's stand does not)
				seam(gardenCell(r, c), gardenCell(r, c + 1), v(x1, y, za), v(x1, y, zb))
			end
			if r < 4 then
				local xm = (x0 + x1) / 2
				local y = groundAt(xm, z0)
				local xa, xb = x0 + 8, x1 - 8
				if c == 2 and r >= 2 then xb = Hut.POLLINATOR.x0 - 5 end -- (column 2's line runs on the path and the lawn, short of the pollinator bed's edge)
				seam(gardenCell(r, c), gardenCell(r + 1, c), v(xa, y, z0), v(xb, y, z0))
			end
		end
	end
end

-- ---------------------------------------------------------------- the pieces
local function P(out: { Piece }, id: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, profile: string, color: string, material: string?)
	table.insert(out, { id = id, lo = v(x0, y0, z0), hi = v(x1, y1, z1), profile = profile, color = hex(color), material = material })
end

-- The parts of an axis-aligned box inside a cell's rectangle (x0..x1, z0..z1), or nil when none.
local function clip(x0: number, x1: number, z0: number, z1: number, cx0: number, cx1: number, cz0: number, cz1: number): (number?, number?, number?, number?)
	local a, b, c, d = math.max(x0, cx0), math.min(x1, cx1), math.max(z0, cz0), math.min(z1, cz1)
	if b - a <= 1e-6 or d - c <= 1e-6 then return nil, nil, nil, nil end
	return a, b, c, d
end

local function floorPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local R = Hut.ROOM
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0, x1, z0, z1 = lo.X, hi.X, lo.Z, hi.Z
	local W, top, sk, st = 10, Hut.WALL_TOP, 1.5, FL + 10
	P(out, id .. "_boards", x0, x1, FL - 2, FL, z0, z1, "varnished_wood_smooth", C.floor, "WoodPlanks")
	local west, east, north, south = x0 == R.x0, x1 == R.x1, z0 == R.z0, z1 == R.z1
	-- the linings (the walls' room faces) and the skirting along them
	if west then
		P(out, id .. "_wall_w", R.x0 - W, R.x0, FL, top, z0, z1, "painted_wood_dry", C.lining, "WoodPlanks")
		-- (the skirting stops at the bookcase, x -146.5..-118.5 from z 116 to 204, and at the corners' other skirting)
		local s0, s1 = if north then z0 + sk else z0, if south then z1 - sk else z1
		local runs = { { s0, s1 } }
		if s0 < 204 and s1 > 116 then
			runs = {}
			if s0 < 116 then table.insert(runs, { s0, 116 }) end
			if s1 > 204 then table.insert(runs, { 204, s1 }) end
		end
		for k, run in runs do P(out, `{id}_skirting_w{k}`, R.x0, R.x0 + sk, FL, st, run[1], run[2], "painted_wood_dry", C.skirting, "Wood") end
	end
	if east then
		P(out, id .. "_wall_e", R.x1, R.x1 + W, FL, top, z0, z1, "painted_wood_dry", C.lining, "WoodPlanks")
		P(out, id .. "_skirting_e", R.x1 - sk, R.x1, FL, st, if north then z0 + sk else z0, if south then z1 - sk else z1, "painted_wood_dry", C.skirting, "Wood")
	end
	if north then
		P(out, id .. "_skirting_n", x0, x1, FL, st, R.z0, R.z0 + sk, "painted_wood_dry", C.skirting, "Wood")
		if x0 < 0 and x1 > 0 then
			-- the apron: the sill's front face goes on down to the floor
			P(out, id .. "_apron", -31, 31, FL, -1, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
		end
	end
	if south then
		local D = Hut.DOOR
		local a, b = math.max(x0, R.x0 + sk), math.min(x1, R.x1 - sk)
		-- the south wall beside the door (the doorway's jambs are hut_door's)
		local walls: { { number } } = {}
		if x1 <= -D.jamb then walls = { { x0, x1 } } elseif x0 >= D.jamb then walls = { { x0, x1 } }
		elseif x0 < -D.jamb then walls = { { x0, -D.jamb } } elseif x1 > D.jamb then walls = { { D.jamb, x1 } } end
		for k, w in walls do
			P(out, `{id}_wall_s{k}`, w[1], w[2], FL, top, R.z1, R.z1 + W, "painted_wood_dry", C.lining, "WoodPlanks")
			local s0, s1 = math.max(w[1], a), math.min(w[2], b)
			if s1 > s0 then P(out, `{id}_skirting_s{k}`, s0, s1, FL, st, R.z1 - sk, R.z1, "painted_wood_dry", C.skirting, "Wood") end
		end
	end
	return out
end

local function deskPieces(): { Piece }
	local out: { Piece } = {}
	local R, top = Hut.ROOM, Hut.WALL_TOP
	P(out, "hut_desk_wall_low", 31, R.x1, FL, 14, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_desk_wall_high", 31, R.x1, 14, top, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_desk_top", 36, 126, 1, 4, R.z0, 72.5, "varnished_wood_smooth", C.deskTop, "Wood")
	for i, leg in { { 37, 14 }, { 121, 14 }, { 37, 67 }, { 121, 67 } } do
		P(out, `hut_desk_leg_{i}`, leg[1], leg[1] + 4, FL, 1, leg[2], leg[2] + 4, "varnished_wood_smooth", C.desk, "Wood")
	end
	P(out, "hut_desk_drawer", 46, 96, -10, 1, 13, 68, "varnished_wood_smooth", C.drawer, "Wood")
	P(out, "hut_desk_knob", 69, 73, -6.5, -3.5, 68, 69.5, "painted_metal_smooth", C.brass, "Metal")
	P(out, "hut_desk_runner", 41, 96, -12.4, -11.4, 14, 71, "varnished_wood_smooth", C.desk, "Wood")
	-- on the desk: the lamp, the notebook, the mug, the specimen jars and the hand lens
	P(out, "hut_desk_lamp_base", 104, 116, 4, 5.5, 18, 30, "painted_metal_smooth", C.lamp, "Metal")
	P(out, "hut_desk_lamp_stem", 109.2, 110.8, 5.5, 34, 23.2, 24.8, "painted_metal_smooth", C.lamp, "Metal")
	P(out, "hut_desk_lamp_shade", 102, 118, 34, 44, 16, 32, "painted_metal_smooth", C.lamp, "Metal")
	P(out, "hut_desk_notebook", 52, 73, 4, 5.2, 34, 63.7, "painted_wood_dry", C.notebook, "Fabric")
	P(out, "hut_desk_mug", 84, 92, 4, 13.5, 50, 58, "glass_clean", C.mug, "SmoothPlastic")
	for i, j in { { 44, 9 }, { 52, 11 }, { 60, 7 } } do
		P(out, `hut_desk_jar_{i}`, j[1], j[1] + 6, 4, 4 + j[2], 14.5, 20.5, "glass_clean", C.jar, "Glass")
	end
	P(out, "hut_desk_lens", 78, 83, 4, 4.6, 26, 31, "glass_clean", C.lens, "Glass")
	P(out, "hut_desk_lens_handle", 83, 91, 4, 4.8, 27.8, 29.2, "varnished_wood_smooth", C.handle, "Wood")
	return out
end

local function boardPieces(): { Piece }
	local out: { Piece } = {}
	local R, top = Hut.ROOM, Hut.WALL_TOP
	P(out, "hut_board_wall_low", R.x0, -31, FL, 14, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_board_wall_high", R.x0, -31, 14, top, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_board_batten_top", -132, -48, 44, 48, R.z0, R.z0 + 2, "bare_wood_rough", C.batten, "Wood")
	P(out, "hut_board_batten_bottom", -132, -48, -6, -2, R.z0, R.z0 + 2, "bare_wood_rough", C.batten, "Wood")
	P(out, "hut_board_cork", -134, -46, -8, 50, R.z0 + 2, R.z0 + 4, "bare_wood_rough", C.cork, "Fabric")
	return out
end

-- The bookcase's field guides: each a box standing on its shelf, its spine to the room, from the shelf's own stream (the same books forever).
local function shelfPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local x0, x1, z0, z1 = Hut.ROOM.x0, -118.5, 116, 204
	P(out, "hut_shelf_side_n", x0, x1, FL, 10, z0, z0 + 2, "varnished_wood_smooth", C.desk, "Wood")
	P(out, "hut_shelf_side_s", x0, x1, FL, 10, z1 - 2, z1, "varnished_wood_smooth", C.desk, "Wood")
	P(out, "hut_shelf_top", x0, x1, 8, 10, z0 + 2, z1 - 2, "varnished_wood_smooth", C.deskTop, "Wood")
	P(out, "hut_shelf_back", x0, x0 + 1, -66, 8, z0 + 2, z1 - 2, "varnished_wood_smooth", C.drawer, "Wood")
	P(out, "hut_shelf_middle", x0 + 1, x1, -32, -30, z0 + 2, z1 - 2, "varnished_wood_smooth", C.deskTop, "Wood")
	P(out, "hut_shelf_bottom", x0 + 1, x1, -66, -64, z0 + 2, z1 - 2, "varnished_wood_smooth", C.deskTop, "Wood")
	P(out, "hut_shelf_plinth", x1 - 2, x1, FL, -66, z0 + 2, z1 - 2, "varnished_wood_smooth", C.desk, "Wood")
	local rand = rng(region.seed, 3)
	for s, shelf in { { y = -30, top = 8, n = 0 }, { y = -64, top = -32, n = 0 } } do
		local z = z0 + 2.5
		local k = 0
		while true do
			local thick = between(rand, 1.6, 3.8)
			local tall = math.min(between(rand, 18, 26), shelf.top - shelf.y - 2)
			local deep = between(rand, 13, 21)
			if z + thick > z1 - 2.5 or k >= 14 then break end
			k += 1
			P(out, `hut_shelf_book_{s}_{k}`, x0 + 1, x0 + 1 + deep, shelf.y, shelf.y + tall, z, z + thick, "painted_wood_dry", pick(C.books, rand), "Fabric")
			z += thick + (if rand() < 0.15 then between(rand, 2, 6) else 0.05)
		end
	end
	-- two lying on the top
	P(out, "hut_shelf_book_top_1", x0 + 4, x0 + 23, 10, 12.5, 150, 166, "painted_wood_dry", C.books[3], "Fabric")
	P(out, "hut_shelf_book_top_2", x0 + 6, x0 + 20, 12.5, 14.2, 152, 163, "painted_wood_dry", C.books[6], "Fabric")
	return out
end

local function chairPieces(): { Piece }
	local out: { Piece } = {}
	P(out, "hut_chair_seat", 66, 106, -27, -24, 88, 128, "varnished_wood_smooth", C.chair, "Wood")
	for i, leg in { { 67, 89 }, { 102, 89 }, { 67, 124 }, { 102, 124 } } do
		P(out, `hut_chair_leg_{i}`, leg[1], leg[1] + 3, FL, -27, leg[2], leg[2] + 3, "varnished_wood_smooth", C.chair, "Wood")
	end
	P(out, "hut_chair_post_w", 67, 70, -24, 18, 124, 127, "varnished_wood_smooth", C.chair, "Wood")
	P(out, "hut_chair_post_e", 102, 105, -24, 18, 124, 127, "varnished_wood_smooth", C.chair, "Wood")
	P(out, "hut_chair_rail_top", 70, 102, 6, 16, 124.5, 126.5, "varnished_wood_smooth", C.chair, "Wood")
	P(out, "hut_chair_rail_low", 70, 102, -12, -6, 124.5, 126.5, "varnished_wood_smooth", C.chair, "Wood")
	return out
end

local function doorPieces(): { Piece }
	local out: { Piece } = {}
	local D, R = Hut.DOOR, Hut.ROOM
	P(out, "hut_door_jamb_w", -D.jamb, -D.x, FL, D.top, R.z1, D.outer, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_door_jamb_e", D.x, D.jamb, FL, D.top, R.z1, D.outer, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_door_threshold", -D.jamb, D.jamb, FL - 2, FL, R.z1, D.base, "varnished_wood_smooth", C.boardDark, "Wood")
	P(out, "hut_door_leaf", -D.x, D.x, FL + D.gap, D.top, D.leaf[1], D.leaf[2], "painted_wood_dry", C.trim, "WoodPlanks")
	P(out, "hut_door_base", -D.jamb, D.jamb, GT, FL - 2, D.outer, D.base, "brick_rough", C.concrete, "Concrete")
	P(out, "hut_door_step", -D.jamb, D.jamb, GT, D.step.top, D.base, D.step.to, "brick_rough", C.concrete, "Concrete")
	P(out, "hut_door_soil", -D.jamb, D.jamb, -87, GT, D.outer, D.gravel, "brick_rough", C.gravel, "Pebble")
	return out
end

local function windowPieces(): { Piece }
	local out: { Piece } = {}
	P(out, "hut_window_glass", -31, 31, 14, 112.5, -13.5, -12.5, "glass_clean", "ded7c3", "SmoothPlastic")
	P(out, "hut_window_reveal_w", -31, -30, 14, 112.5, -12.5, Hut.ROOM.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_window_reveal_e", 30, 31, 14, 112.5, -12.5, Hut.ROOM.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_window_head", -31, 31, 112.5, 113.5, -13.5, Hut.ROOM.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	return out
end

local function outerPieces(): { Piece }
	local out: { Piece } = {}
	P(out, "hut_outer_sill_board", -37, 37, -4, 0, -22, -13.5, "painted_wood_dry", C.board, "Wood")
	P(out, "hut_outer_sill_casing_w", -37, -31, 0, Hut.OUT_TOP, -17.2, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	P(out, "hut_outer_sill_casing_e", 31, 37, 0, Hut.OUT_TOP, -17.2, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	return out
end

-- The logs outside: under the outer sill (mid), and west and east of the window to OUT_TOP, standing on the base's lip (the garden's: its row a's cells).
local function wallPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local z0, z1, top = -16, Hut.WALL_SPLIT, Hut.OUT_TOP
	if region.id == "hut_wall_mid" then
		P(out, "hut_wall_mid_logs", -31, 31, FL, -4, z0, z1, "bare_wood_rough", C.log, "Wood")
		return out
	end
	local s = if region.id == "hut_wall_w" then -1 else 1
	local function box(id: string, a: number, b: number, y0: number, y1: number, za: number, zb: number, profile: string, color: string, material: string)
		P(out, id, math.min(s * a, s * b), math.max(s * a, s * b), y0, y1, za, zb, profile, color, material)
	end
	box(region.id .. "_logs_low", 31, 175, FL, -4, z0, z1, "bare_wood_rough", C.log, "Wood")
	box(region.id .. "_logs_side", 37, 175, -4, 0, z0, z1, "bare_wood_rough", C.log, "Wood")
	box(region.id .. "_logs_high", 31, 175, 0, top, z0, z1, "bare_wood_rough", C.log, "Wood")
	box(region.id .. "_corner", 166, 184, FL, top, -25, -16, "bare_wood_rough", C.logDark, "Wood") -- (the corner's log ends, proud of the face)
	return out
end

local function benchPieces(): { Piece }
	local out: { Piece } = {}
	P(out, "hut_bench_seat", -85, 45, -44, -40, -58, -16, "painted_wood_dry", C.board, "WoodPlanks")
	P(out, "hut_bench_leg_w", -80, -74, GT, -44, -55, -22, "painted_wood_dry", C.boardDark, "Wood")
	P(out, "hut_bench_leg_e", 33, 39, GT, -44, -55, -22, "painted_wood_dry", C.boardDark, "Wood")
	return out
end

local function buttPieces(): { Piece }
	local out: { Piece } = {}
	P(out, "hut_butt_stand", 100, 160, GT, -66, -75, -21, "brick_rough", C.concrete, "Concrete")
	P(out, "hut_butt_drum", 101, 159, -66, 26, -77, -19, "painted_metal_smooth", C.butt, "SmoothPlastic")
	P(out, "hut_butt_lid", 99, 161, 26, 28.5, -79, -19, "painted_metal_smooth", C.buttLid, "SmoothPlastic")
	return out
end

local function polePieces(region: Region): { Piece }
	local out: { Piece } = {}
	local Q = Hut.POLE
	if region.id == "garden_pole" then
		P(out, "garden_pole", Q.x - Q.half, Q.x + Q.half, GT, GT + Q.split, Q.z - Q.half, Q.z + Q.half, "painted_metal_smooth", "2a2c2e", "Metal")
		return out
	end
	local y = GT + Q.top
	P(out, "garden_feeder_pole", Q.x - Q.half, Q.x + Q.half, GT + Q.split, y, Q.z - Q.half, Q.z + Q.half, "painted_metal_smooth", "2a2c2e", "Metal")
	P(out, "garden_feeder_tray", Q.x - Q.tray.half, Q.x + Q.tray.half, y, y + Q.tray.thick, Q.z - Q.tray.half, Q.z + Q.tray.half, "painted_wood_dry", "8a6f4e", "Wood")
	y += Q.tray.thick
	P(out, "garden_feeder_hopper", Q.x - Q.hopper.half, Q.x + Q.hopper.half, y, y + Q.hopper.h, Q.z - Q.hopper.half, Q.z + Q.hopper.half, "glass_clean", "c9b48a", "Glass")
	y += Q.hopper.h
	P(out, "garden_feeder_roof", Q.x - Q.roof.half, Q.x + Q.roof.half, y, y + Q.roof.thick, Q.z - Q.roof.half, Q.z + Q.roof.half, "painted_wood_dry", "3f5a43", "WoodPlanks")
	return out
end

-- A plant's walkable boxes, standing on the soil at `y0`: its stem, its leaves (each a box out from the stem's face, as the dock's), its flowers. Ids `<cell>_<kind>_...`.
type Leaf = { h: number, dir: string, l: number, w: number }
local PLANT_SPECS: { [string]: any } = {
	-- common milkweed (Asclepias syriaca): 0.6 to 1.5 m, broad opposite leaves 10 to 20 by 5 to 9 cm, pink umbels; a pod by late summer
	milkweed = { stem = 1.2, height = 95, thick = 0.4, leaves = { { h = 22, dir = "x+", l = 16, w = 7 }, { h = 22, dir = "x-", l = 16, w = 7 }, { h = 40, dir = "z+", l = 17, w = 7.5 },
		{ h = 40, dir = "z-", l = 17, w = 7.5 }, { h = 56, dir = "x+", l = 15, w = 6.5 }, { h = 56, dir = "x-", l = 15, w = 6.5 }, { h = 72, dir = "z+", l = 13, w = 6 }, { h = 72, dir = "z-", l = 13, w = 6 } },
		head = { w = 7, h = 5 }, pod = { h = 38, l = 10, w = 2.4 }, color = C.stem, leaf = C.milkweedLeaf, flower = C.umbel },
	-- purple coneflower (Echinacea purpurea): 0.6 to 1.2 m, basal leaves to 15 cm, a head 7 to 12 cm across round an orange-brown cone
	coneflower = { stem = 0.8, height = 70, thick = 0.3, leaves = { { h = 24, dir = "x+", l = 10, w = 3 }, { h = 44, dir = "z-", l = 9, w = 2.8 } }, basal = { l = 14, w = 5 },
		head = { w = 9, h = 0.6 }, cone = { w = 3.5, h = 3 }, color = C.stem, leaf = C.leaf, flower = C.petal },
	-- wild bergamot, bee balm (Monarda fistulosa): 0.6 to 1.2 m, square stems, opposite leaves 5 to 10 cm, a lavender head 3 to 5 cm
	beebalm = { stem = 0.7, height = 80, thick = 0.3, leaves = { { h = 20, dir = "x+", l = 8, w = 3 }, { h = 20, dir = "x-", l = 8, w = 3 }, { h = 36, dir = "z+", l = 8, w = 3 },
		{ h = 36, dir = "z-", l = 8, w = 3 }, { h = 52, dir = "x+", l = 7, w = 2.6 }, { h = 52, dir = "x-", l = 7, w = 2.6 }, { h = 66, dir = "z+", l = 6, w = 2.4 }, { h = 66, dir = "z-", l = 6, w = 2.4 } },
		head = { w = 4.5, h = 4 }, color = "6a7a4a", leaf = C.leaf, flower = C.monarda },
	-- Canada goldenrod (Solidago canadensis): 0.6 to 1.5 m, narrow alternate leaves 8 to 12 cm, a yellow plume
	goldenrod = { stem = 0.8, height = 85, thick = 0.25, leaves = { { h = 18, dir = "x+", l = 11, w = 1.6 }, { h = 27, dir = "z-", l = 11, w = 1.6 }, { h = 36, dir = "x-", l = 11, w = 1.6 },
		{ h = 45, dir = "z+", l = 10, w = 1.5 }, { h = 54, dir = "x+", l = 10, w = 1.5 }, { h = 63, dir = "z-", l = 9, w = 1.4 }, { h = 72, dir = "x-", l = 9, w = 1.4 } },
		head = { w = 12, h = 20, d = 10 }, color = "6f7f45", leaf = C.goldenLeaf, flower = C.goldenrod },
}
Hut.PLANT_SPECS = PLANT_SPECS

local function plantPieces(out: { Piece }, id: string, plant: { kind: string, x: number, z: number }, y0: number)
	local spec = PLANT_SPECS[plant.kind]
	local half = spec.stem / 2
	local sx0, sx1, sz0, sz1 = plant.x - half, plant.x + half, plant.z - half, plant.z + half
	local base = `{id}_{plant.kind}`
	P(out, base .. "_stem", sx0, sx1, y0, y0 + spec.height, sz0, sz1, "leaf_dry_prototype", spec.color)
	for i, leaf in spec.leaves :: { Leaf } do
		local ya, yb = y0 + leaf.h, y0 + leaf.h + spec.thick
		local w = leaf.w / 2
		if leaf.dir == "x+" then P(out, `{base}_leaf_{i}`, sx1, sx1 + leaf.l, ya, yb, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		elseif leaf.dir == "x-" then P(out, `{base}_leaf_{i}`, sx0 - leaf.l, sx0, ya, yb, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		elseif leaf.dir == "z+" then P(out, `{base}_leaf_{i}`, plant.x - w, plant.x + w, ya, yb, sz1, sz1 + leaf.l, "leaf_dry_prototype", spec.leaf)
		else P(out, `{base}_leaf_{i}`, plant.x - w, plant.x + w, ya, yb, sz0 - leaf.l, sz0, "leaf_dry_prototype", spec.leaf) end
	end
	local top = y0 + spec.height
	local H = spec.head
	if plant.kind == "coneflower" then
		-- the basal rosette on the soil (clear of the stem, as the dandelion's), the ray of petals and the cone over it
		local B = spec.basal
		local gap = B.w / 2 + 0.3 -- (each clear of the others' ends)
		local w = B.w / 2
		P(out, base .. "_basal_1", sx1 + gap, sx1 + gap + B.l, y0, y0 + 0.3, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		P(out, base .. "_basal_2", sx0 - gap - B.l, sx0 - gap, y0, y0 + 0.3, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		P(out, base .. "_basal_3", plant.x - w, plant.x + w, y0, y0 + 0.3, sz1 + gap, sz1 + gap + B.l, "leaf_dry_prototype", spec.leaf)
		P(out, base .. "_head", plant.x - H.w / 2, plant.x + H.w / 2, top, top + H.h, plant.z - H.w / 2, plant.z + H.w / 2, "leaf_dry_prototype", spec.flower)
		P(out, base .. "_cone", plant.x - spec.cone.w / 2, plant.x + spec.cone.w / 2, top + H.h, top + H.h + spec.cone.h, plant.z - spec.cone.w / 2, plant.z + spec.cone.w / 2, "leaf_dry_prototype", C.cone)
	elseif plant.kind == "goldenrod" then
		P(out, base .. "_head", plant.x - H.w / 2, plant.x + H.w / 2, top, top + H.h, plant.z - H.d / 2, plant.z + H.d / 2, "leaf_dry_prototype", spec.flower)
	else
		P(out, base .. "_head", plant.x - H.w / 2, plant.x + H.w / 2, top, top + H.h, plant.z - H.w / 2, plant.z + H.w / 2, "leaf_dry_prototype", spec.flower)
	end
	if spec.pod ~= nil then
		-- the milkweed's pod, against the stem's east face between the first and second pairs of leaves
		local Q = spec.pod
		P(out, base .. "_pod", sx1, sx1 + Q.w, y0 + Q.h - Q.l, y0 + Q.h, sz0, sz0 + Q.w, "leaf_dry_prototype", C.pod)
	end
end

-- A low herb of the herb bed: chives (a clump of stalks and two flower heads), sage (a mound), thyme (a mat).
local function herbPieces(out: { Piece }, id: string, kind: string, x: number, z: number, y0: number)
	local base = `{id}_{kind}`
	if kind == "chives" then
		for i, o in { { 0, 0 }, { 3, 1.2 }, { -2.6, 2 }, { 1, -3 }, { -2, -2.4 } } do
			local h = 22 + i * 1.5
			P(out, `{base}_stalk_{i}`, x + o[1] - 0.25, x + o[1] + 0.25, y0, y0 + h, z + o[2] - 0.25, z + o[2] + 0.25, "leaf_dry_prototype", C.chive)
			if i <= 2 then P(out, `{base}_flower_{i}`, x + o[1] - 1.1, x + o[1] + 1.1, y0 + h, y0 + h + 2.2, z + o[2] - 1.1, z + o[2] + 1.1, "leaf_dry_prototype", C.chiveFlower) end
		end
	elseif kind == "sage" then
		P(out, base, x - 12, x + 12, y0, y0 + 16, z - 10, z + 10, "leaf_dry_prototype", C.sage)
	else
		P(out, base, x - 15, x + 15, y0, y0 + 4, z - 14, z + 14, "leaf_dry_prototype", C.thyme)
	end
end
local HERBS: { [string]: { { kind: string, x: number, z: number } } } = {
	garden_c1 = { { kind = "chives", x = -150, z = -262 }, { kind = "sage", x = -128, z = -292 } },
	garden_d1 = { { kind = "thyme", x = -165, z = -345 }, { kind = "sage", x = -125, z = -372 } },
}

local EDGING_RUN = 25 -- the path's brick edging, laid in lengths of this many studs at most
local function gardenPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local lo, hi = region.bounds[1], region.bounds[2]
	local cx0, cx1, cz0, cz1 = lo.X, hi.X, lo.Z, hi.Z
	P(out, id .. "_soil", cx0, cx1, -87, GT, cz0, cz1, "brick_rough", C.lawn, "Grass") -- (the lawn: the path and the drip strip are drawn on it)
	-- the hut's concrete base where it shows under the logs (x -178..178, the north face's lip 3 cm proud)
	do
		local a, b = clip(-178, 178, -19, -16, cx0, cx1, cz0, cz1)
		if a ~= nil then P(out, id .. "_hut_base", a, b :: number, GT, FL, -19, -16, "brick_rough", C.concrete, "Concrete") end
	end
	-- the raised beds: their timber edging and their soil, the part of each inside this cell
	local E = Hut.EDGING
	for name, b in { pollinator = Hut.POLLINATOR, herbs = Hut.HERBS } :: { [string]: any } do
		local sides = {
			{ b.x0, b.x1, b.z0, b.z0 + E.thick }, { b.x0, b.x1, b.z1 - E.thick, b.z1 },
			{ b.x0, b.x0 + E.thick, b.z0 + E.thick, b.z1 - E.thick }, { b.x1 - E.thick, b.x1, b.z0 + E.thick, b.z1 - E.thick },
		}
		for k, s in sides do
			local a, bb, c, d = clip(s[1], s[2], s[3], s[4], cx0, cx1, cz0, cz1)
			if a ~= nil then P(out, `{id}_{name}_edge_{k}`, a, bb :: number, GT, GT + E.top, c :: number, d :: number, "bare_wood_rough", C.edging, "Wood") end
		end
		local a, bb, c, d = clip(b.x0 + E.thick, b.x1 - E.thick, b.z0 + E.thick, b.z1 - E.thick, cx0, cx1, cz0, cz1)
		if a ~= nil then P(out, `{id}_{name}_bed`, a, bb :: number, GT, S, c :: number, d :: number, "brick_rough", if name == "pollinator" then C.mulch else C.soil, "Ground") end
	end
	-- the path's brick edging: along the east-west path's north side and its south side east of the north-south path, and the north-south path's sides
	local Pa = Hut.PATH
	local runs = {
		{ Pa.ew.x0 + Pa.brick, Pa.ew.x1, Pa.ew.z1, Pa.ew.z1 + Pa.brick }, -- the north side (toward the hut), from the corner east
		{ Pa.ns.x1, Pa.ew.x1, Pa.ew.z0 - Pa.brick, Pa.ew.z0 }, -- the south side, east of the north-south path
		{ Pa.ns.x0 - Pa.brick, Pa.ns.x0, Pa.ns.z0, Pa.ew.z1 + Pa.brick }, -- the north-south path's west side, from the north edge to the corner
		{ Pa.ns.x1, Pa.ns.x1 + Pa.brick, Pa.ns.z0, Pa.ew.z0 - Pa.brick }, -- and its east side, to the east-west path's south side
	}
	-- (laid in lengths of at most EDGING_RUN, each a box of its own: a region whole in the streaming radius has no long box reaching across its neighbour's)
	for k, s in runs do
		local a, bb, c, d = clip(s[1], s[2], s[3], s[4], cx0, cx1, cz0, cz1)
		if a ~= nil then
			local x1, z1 = bb :: number, d :: number
			local alongX = x1 - a >= z1 - (c :: number)
			local from, to = if alongX then a else c :: number, if alongX then x1 else z1
			local n = math.ceil((to - from) / EDGING_RUN - 1e-9)
			for j = 1, n do
				local t0, t1 = from + (to - from) * (j - 1) / n, from + (to - from) * j / n
				if alongX then P(out, `{id}_edging_{k}_{j}`, t0, t1, GT, GT + Pa.brickH, c :: number, z1, "brick_rough", C.brick[1 + (j % #C.brick)], "Brick")
				else P(out, `{id}_edging_{k}_{j}`, a, x1, GT, GT + Pa.brickH, t0, t1, "brick_rough", C.brick[1 + (j % #C.brick)], "Brick") end
			end
		end
	end
	-- what stands in this cell
	if id == "garden_a1" then
		local T = Hut.TROUGH
		P(out, id .. "_trough_foot_w", T.x0, T.x0 + T.foot, GT, GT + T.feet, T.z0, T.z1, "brick_rough", C.brick[2], "Brick")
		P(out, id .. "_trough_foot_e", T.x1 - T.foot, T.x1, GT, GT + T.feet, T.z0, T.z1, "brick_rough", C.brick[3], "Brick")
		P(out, id .. "_trough", T.x0, T.x1, GT + T.feet, GT + T.top, T.z0, T.z1, "bare_wood_rough", C.board, "Wood")
		local r = T.rim
		P(out, id .. "_trough_rim_n", T.x0, T.x1, GT + T.top, GT + T.top + r, T.z0, T.z0 + r, "bare_wood_rough", C.boardDark, "Wood")
		P(out, id .. "_trough_rim_s", T.x0, T.x1, GT + T.top, GT + T.top + r, T.z1 - r, T.z1, "bare_wood_rough", C.boardDark, "Wood")
		P(out, id .. "_trough_rim_w", T.x0, T.x0 + r, GT + T.top, GT + T.top + r, T.z0 + r, T.z1 - r, "bare_wood_rough", C.boardDark, "Wood")
		P(out, id .. "_trough_rim_e", T.x1 - r, T.x1, GT + T.top, GT + T.top + r, T.z0 + r, T.z1 - r, "bare_wood_rough", C.boardDark, "Wood")
		-- a parsley and a basil in it
		P(out, id .. "_trough_herb_1", -156, -142, GT + T.top, GT + T.top + 12, -50, -36, "leaf_dry_prototype", C.leafPale)
		P(out, id .. "_trough_herb_2", -126, -110, GT + T.top, GT + T.top + 9, -48, -32, "leaf_dry_prototype", C.leaf)
	elseif id == "garden_a3" then
		local St = Hut.STONE
		P(out, id .. "_stone_rest_w", St.x0, St.x0 + St.rest, GT, GT + St.gap, St.z0, St.z1, "brick_rough", "8f887b", "Slate")
		P(out, id .. "_stone_rest_e", St.x1 - St.rest, St.x1, GT, GT + St.gap, St.z0, St.z1, "brick_rough", "8f887b", "Slate")
		P(out, id .. "_stone_top", St.x0, St.x1, GT + St.gap, GT + St.gap + St.thick, St.z0, St.z1, "brick_rough", C.stone[2], "Slate")
	elseif id == "garden_d3" then
		local Ch = Hut.CHIP
		P(out, id .. "_chip_rest_w", Ch.x0, Ch.x0 + Ch.rest, S, S + Ch.gap, Ch.z0, Ch.z1, "bare_wood_rough", C.mulchColors[3], "Wood")
		P(out, id .. "_chip_rest_e", Ch.x1 - Ch.rest, Ch.x1, S, S + Ch.gap, Ch.z0, Ch.z1, "bare_wood_rough", C.mulchColors[5], "Wood")
		P(out, id .. "_chip", Ch.x0, Ch.x1, S + Ch.gap, S + Ch.gap + Ch.thick, Ch.z0, Ch.z1, "bare_wood_rough", C.mulchColors[2], "Wood")
		P(out, id .. "_stone_a", 20, 32, S, S + 2.4, -330, -320, "brick_rough", C.stone[1], "Slate") -- (a stone half sunk in the mulch)
	elseif id == "garden_c3" then
		P(out, id .. "_stone_a", 5, 17, S, S + 1.8, -300, -290, "brick_rough", C.stone[3], "Slate")
	end
	local plant = PLANTS[id]
	if plant ~= nil then plantPieces(out, id, plant, S) end
	local herbs = HERBS[id]
	if herbs ~= nil then for _, h in herbs do herbPieces(out, id, h.kind, h.x, h.z, S) end end
	return out
end

local KINDS: { [string]: boolean } = {
	hut_window = true, hut_outer_sill = true, hut_floor = true, hut_desk = true, hut_board = true, hut_shelf = true, hut_chair = true, hut_door = true,
	hut_wall = true, hut_bench = true, hut_butt = true, garden_pole = true, garden_bed = true,
}
-- Whether a kind is the hut's (or its garden's).
function Hut.knows(kind: string): boolean
	return KINDS[kind] == true
end
-- The kinds inside the hut (Life/Nature: the night's ground hunters never come in; the hut keeps the sill's day).
Hut.INDOORS = table.freeze({ hut_window = true, hut_floor = true, hut_desk = true, hut_board = true, hut_shelf = true, hut_chair = true })

local piecesCache: { [string]: { Piece } } = {}
function Hut.pieces(region: Region): { Piece }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = piecesCache[key]
	if cached ~= nil then return cached end
	local k, out = region.kind, nil :: { Piece }?
	if k == "hut_floor" then out = floorPieces(region)
	elseif k == "hut_desk" then out = deskPieces()
	elseif k == "hut_board" then out = boardPieces()
	elseif k == "hut_shelf" then out = shelfPieces(region)
	elseif k == "hut_chair" then out = chairPieces()
	elseif k == "hut_door" then out = doorPieces()
	elseif k == "hut_window" then out = windowPieces()
	elseif k == "hut_outer_sill" then out = outerPieces()
	elseif k == "hut_wall" then out = wallPieces(region)
	elseif k == "hut_bench" then out = benchPieces()
	elseif k == "hut_butt" then out = buttPieces()
	elseif k == "garden_pole" then out = polePieces(region)
	elseif k == "garden_bed" then out = gardenPieces(region)
	else error("no generator for the region kind " .. k) end
	local list = out :: { Piece }
	for _, p in list do table.freeze(p) end
	piecesCache[key] = table.freeze(list)
	return list
end

-- The pieces a region's drawing stands in for (they turn invisible, still solid): the window's glass, which the sill's Decor draws with the rest of the window.
-- Everything else of the hut is its own look (its material and colour), with the drawn detail beside it.
function Hut.drawnPieces(region: Region): { string }
	if region.kind == "hut_window" then return { "hut_window_glass" } end
	-- (and the herbs' mounds, drawn as leafy masses over their boxes: Hut.decor)
	local out: { string } = {}
	for _, p in Hut.pieces(region) do
		if string.find(p.id, "_trough_herb_", 1, true) ~= nil or string.sub(p.id, -5) == "_sage" or string.sub(p.id, -6) == "_thyme" then table.insert(out, p.id) end
	end
	return out
end

-- The boxes a region's creatures keep out of: each retreat grown by half a stud (World/Garden's rule).
function Hut.keepOut(region: Region): { Box }
	local out: { Box } = {}
	for _, t in region.retreats do table.insert(out, { min = t.min - v(0.5, 0.5, 0.5), max = t.max + v(0.5, 0.5, 0.5) }) end
	return out
end

-- ---------------------------------------------------------------- the drawn looks
-- The hut's boxes are their own look (their materials and colours, visible: World/WorldBuild builds them), so a look here is only the detail beside them, and
-- nearly all of it is the full tier's: the floorboards' joints, the leaflets on the board, the pencil and the jars' lids, the grass, the gravel's stones, the
-- mulch's chips, the flowers' florets. What the low tier keeps is what tells a surface from another (the gravel path on the lawn, the drip strip, the seed under
-- the feeder) and the lamp's bulb. (The hut's shell seen from afar, and its walls above what the regions hold, are World/PreserveLook's hut, drawn behind these
-- boxes by a hair so that the two never fight where both are drawn: it stands in for them where streaming has not sent them yet.)
-- The ceilings each kind keeps to at both tiers (a placer stops at them, keeping what it placed first; tests/preserve.luau holds the counts).
Hut.BUDGETS = table.freeze({
	hut_floor = { full = 12, low = 0 }, hut_desk = { full = 22, low = 1 }, hut_board = { full = 16, low = 4 }, hut_shelf = { full = 10, low = 0 }, hut_chair = { full = 2, low = 0 },
	hut_door = { full = 14, low = 1 }, hut_window = { full = 0, low = 0 }, hut_outer_sill = { full = 6, low = 0 }, hut_wall = { full = 0, low = 0 },
	hut_bench = { full = 4, low = 0 }, hut_butt = { full = 3, low = 0 }, garden_pole = { full = 4, low = 2 }, garden_bed = { full = 72, low = 8 },
}) :: { [string]: { full: number, low: number } }

local function sheet(budget: { full: number, low: number })
	local list: { Drawn } = {}
	local full, low = 0, 0
	local function add(d: Drawn): boolean
		if full + 1 > budget.full or (not d.full and low + 1 > budget.low) then return false end
		full += 1
		if not d.full then low += 1 end
		table.insert(list, d)
		return true
	end
	return list, add
end
-- A record: `at` its middle, `size`, colour by hex, material; `full` the low tier drops it.
local function rec(id: string, size: Vector3, at: Vector3, color: string, material: string, full: boolean, shape: string?, turn: Vector3?): Drawn
	return { id = id, size = size, at = at, color = hex(color), material = material, full = full, shape = shape, turn = turn }
end

local function floorDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	-- the boards run north and south, 14 cm wide: the joints between them
	local x = math.ceil(lo.X / 14) * 14
	local k = 0
	while x < hi.X - 1 do
		k += 1
		add(rec(`Joint{k}`, v(0.18, 0.02, hi.Z - lo.Z), v(x, FL + 0.01, (lo.Z + hi.Z) / 2), C.floorDark, "WoodPlanks", true))
		x += 14
	end
	local rand = rng(region.seed, 5)
	for i = 1, 3 do
		add(rec(`Knot{i}`, v(1.2, 0.02, 2.2), v(between(rand, lo.X + 4, hi.X - 4), FL + 0.012, between(rand, lo.Z + 4, hi.Z - 4)), "5e4430", "Wood", true, "Ellipsoid"))
	end
end

local function deskDecor(_region: Region, add: (Drawn) -> boolean)
	-- the lamp's bulb under its shade (it glows at night: Client/HutLife lights it)
	add(rec("Bulb", v(4, 4, 4), v(110, 32, 24), "fff1c8", "Neon", false, "Ball"))
	add(rec("ShadeRim", v(1, 17, 17), v(110, 34.5, 24), "24392b", "Metal", true, "Cylinder", v(0, 0, 90)))
	add(rec("Pencil", v(17, 0.7, 0.7), v(66, 5.55, 66.5), "e0b23a", "Wood", true, "Cylinder", v(0, 8, 0)))
	add(rec("PencilTip", v(1.4, 0.5, 0.5), v(75, 5.55, 65.3), "2a2724", "SmoothPlastic", true, "Cylinder", v(0, 8, 0)))
	add(rec("Pages", v(0.6, 1.0, 29.3), v(73.25, 4.55, 48.85), "efe9d8", "SmoothPlastic", true))
	add(rec("Band", v(21.2, 1.25, 0.5), v(62.5, 4.62, 58), "1f1f1f", "Fabric", true))
	add(rec("MugHandle", v(1, 6, 4.5), v(92.4, 8.5, 54), C.mug, "SmoothPlastic", true))
	add(rec("Coffee", v(7.4, 0.1, 7.4), v(88, 12.8, 54), "3a2416", "SmoothPlastic", true))
	for i, j in { { 44, 9 }, { 52, 11 }, { 60, 7 } } do
		add(rec(`Lid{i}`, v(6.4, 1.2, 6.4), v(j[1] + 3, 4 + j[2] + 0.6, 17.5), C.lid, "Metal", true))
		add(rec(`Specimen{i}`, v(2.2, 1.4, 1.6), v(j[1] + 3, 4.8, 17.5), if i == 2 then "5a3a22" else "2e2a24", "SmoothPlastic", true, "Ellipsoid"))
	end
	add(rec("LensRim", v(0.8, 5.4, 5.4), v(80.5, 4.3, 28.5), C.brass, "Metal", true, "Cylinder", v(0, 0, 90)))
	add(rec("Grain1", v(88, 0.02, 0.25), v(81, 4.01, 40), "8a6440", "Wood", true))
	add(rec("Grain2", v(70, 0.02, 0.2), v(90, 4.01, 26), "8a6440", "Wood", true))
	add(rec("Grain3", v(60, 0.02, 0.2), v(70, 4.01, 68), "8a6440", "Wood", true))
end

local function boardDecor(region: Region, add: (Drawn) -> boolean)
	-- the leaflets: the preserve's map, the volunteers' rota, the birds of the feeder, a lost cat, the bioblitz's date, a pressed leaf (low: the largest four)
	local face = Hut.ROOM.z0 + 4
	local sheets: { { id: string, w: number, h: number, x: number, y: number, color: string } } = {
		{ id = "Map", w = 34, h = 24, x = -112, y = 34, color = "dfe9d0" }, { id = "Rota", w = 21, h = 29.7, x = -72, y = 30, color = C.paper[1] },
		{ id = "Birds", w = 21, h = 14.8, x = -118, y = 6, color = C.paper[4] }, { id = "Cat", w = 14.8, h = 21, x = -90, y = 4, color = C.paper[5] },
		{ id = "Bioblitz", w = 14.8, h = 10.5, x = -62, y = 2, color = C.paper[6] }, { id = "Leaf", w = 10, h = 12, x = -60, y = 14, color = C.paper[3] },
	}
	local rand = rng(region.seed, 9)
	for i, sh in sheets do
		add(rec(sh.id, v(sh.w, sh.h, 0.05), v(sh.x, sh.y, face + 0.03), sh.color, "SmoothPlastic", i > 4, nil, v(0, 0, between(rand, -3, 3))))
	end
	for i, sh in sheets do
		add(rec(`Pin{i}`, v(0.9, 0.9, 0.9), v(sh.x, sh.y + sh.h / 2 - 1.5, face + 0.5), pick({ "c0392b", "2e86c1", "f1c40f", "27ae60" }, rand), "SmoothPlastic", true, "Ball"))
	end
end

local function shelfDecor(region: Region, add: (Drawn) -> boolean)
	-- gold bands on some of the field guides' spines
	local k = 0
	for _, p in Hut.pieces(region) do
		if string.find(p.id, "_book_", 1, true) ~= nil and k < 10 and (#p.id % 2 == 0) then
			k += 1
			add(rec(`Band{k}`, v(0.05, 0.6, p.hi.Z - p.lo.Z), v(p.hi.X + 0.03, p.hi.Y - 3, (p.lo.Z + p.hi.Z) / 2), "c9a23d", "Metal", true))
		end
	end
end

local function doorDecor(region: Region, add: (Drawn) -> boolean)
	local D = Hut.DOOR
	-- the light under the door: a bright strip on the threshold's far side, and the gravel's stones
	add(rec("Gap", v(90, 0.02, 4), v(0, FL + 0.01, D.leaf[2] + 2), "d8c7a0", "SmoothPlastic", false))
	local rand = rng(region.seed, 13)
	for i = 1, 12 do
		local s = between(rand, 0.4, 1.2)
		add(rec(`Pebble{i}`, v(s, s * 0.6, s * between(rand, 0.7, 1.2)), v(between(rand, -55, 55), GT + s * 0.2, between(rand, D.step.to + 2, D.gravel - 2)), pick({ C.gravel, C.gravelDark, "c9bfa8", "8f8676" }, rand), "Pebble", true, "Ellipsoid"))
	end
end

local function outerDecor(region: Region, add: (Drawn) -> boolean)
	local rand = rng(region.seed, 17)
	for i = 1, 6 do
		local s = between(rand, 0.3, 0.9)
		add(rec(`Grit{i}`, v(s, 0.05, s), v(between(rand, -33, 33), 0.02, between(rand, -21, -17)), pick({ "7d7466", "9b9284", "c9b48a" }, rand), "SmoothPlastic", true))
	end
end

local function benchDecor(_region: Region, add: (Drawn) -> boolean)
	for k = 1, 3 do add(rec(`Slat{k}`, v(130, 0.05, 0.4), v(-20, -39.97, -58 + k * 10.5), C.boardDark, "WoodPlanks", true)) end
end

local function buttDecor(_region: Region, add: (Drawn) -> boolean)
	add(rec("Tap", v(3, 3, 4), v(130, -55, -78.5), C.brass, "Metal", true))
	add(rec("Overflow", v(30, 2, 2), v(160, 18, -48), "2f3133", "SmoothPlastic", true, "Cylinder"))
end

local function poleDecor(region: Region, add: (Drawn) -> boolean)
	if region.id ~= "garden_feeder" then return end
	local Q = Hut.POLE
	local y = GT + Q.top + Q.tray.thick
	add(rec("Seed", v(9.6, Q.hopper.h * 0.6, 9.6), v(Q.x, y + Q.hopper.h * 0.3, Q.z), "c9b48a", "Sand", false))
	add(rec("TraySeed", v(14, 0.3, 14), v(Q.x, y + 0.15, Q.z), "a8875a", "Sand", false))
end

-- The garden: the surfaces (the path's gravel, the drip strip), the lawn's grass, the mulch, the seed under the feeder, the flowers' detail.
local function gardenDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local cx0, cx1, cz0, cz1 = lo.X, hi.X, lo.Z, hi.Z
	local id = region.id
	-- the surfaces (low): the gravel path and the drip strip along the hut's foot
	local Pa = Hut.PATH
	for k, r in { Pa.ew, Pa.ns } :: { any } do
		local a, b, c, d = clip(r.x0, r.x1, r.z0, r.z1, cx0, cx1, cz0, cz1)
		if a ~= nil then add(rec(`Path{k}`, v((b :: number) - a, 0.04, (d :: number) - (c :: number)), v((a + (b :: number)) / 2, GT + 0.02, ((c :: number) + (d :: number)) / 2), C.gravel, "Pebble", false)) end
	end
	do
		local a, b, c, d = clip(cx0, cx1, -46, -19, cx0, cx1, cz0, cz1)
		if a ~= nil then add(rec("Drip", v((b :: number) - a, 0.04, (d :: number) - (c :: number)), v((a + (b :: number)) / 2, GT + 0.02, ((c :: number) + (d :: number)) / 2), C.gravelDark, "Pebble", false)) end
	end
	-- the herbs' mounds over their boxes (low: they stand in for the boxes): sage grey-green, thyme low and fine, the trough's parsley and basil
	for _, p in Hut.pieces(region) do
		local herb = string.find(p.id, "_trough_herb_", 1, true) ~= nil or string.sub(p.id, -5) == "_sage" or string.sub(p.id, -6) == "_thyme"
		if herb then
			local size = p.hi - p.lo
			local color = if string.sub(p.id, -5) == "_sage" then C.sage elseif string.sub(p.id, -6) == "_thyme" then C.thyme elseif string.sub(p.id, -1) == "1" then C.leafPale else C.leaf
			add(rec(p.id .. "_mass", v(size.X, size.Y * 2, size.Z), v((p.lo.X + p.hi.X) / 2, p.lo.Y, (p.lo.Z + p.hi.Z) / 2), color, "LeafyGrass", false, "Ellipsoid"))
		end
	end
	if id == "garden_b1" then
		local Q = Hut.POLE
		add(rec("Spill", v(34, 0.05, 26), v(Q.x + 3, GT + 0.025, Q.z - 4), "8f7d5a", "Sand", false, "Ellipsoid"))
	end
	local rand = rng(region.seed, 29)
	-- the plants' flowers: the milkweed's florets, the coneflower's drooping rays, the bergamot's tubes, the goldenrod's sprays
	local plant = PLANTS[id]
	if plant ~= nil then
		local spec = PLANT_SPECS[plant.kind]
		local top = S + spec.height
		if plant.kind == "milkweed" then
			for i = 1, 7 do
				local a = i / 7 * TAU
				add(rec(`Floret{i}`, v(1.3, 1.3, 1.3), v(plant.x + math.cos(a) * 3.2, top + 5 + between(rand, -0.6, 0.8), plant.z + math.sin(a) * 3.2), pick({ C.umbel, "d9a1ab", "b47a86" }, rand), "SmoothPlastic", true, "Ball"))
			end
		elseif plant.kind == "coneflower" then
			for i = 1, 10 do
				local a = i / 10 * TAU
				add(rec(`Ray{i}`, v(4.2, 0.12, 1.1), v(plant.x + math.cos(a) * 5.6, top + 0.1 - 0.9, plant.z + math.sin(a) * 5.6), C.petal, "SmoothPlastic", true, nil, v(0, -math.deg(a), -24)))
			end
		elseif plant.kind == "beebalm" then
			for i = 1, 8 do
				local a = i / 8 * TAU
				add(rec(`Tube{i}`, v(0.4, 2.6, 0.4), v(plant.x + math.cos(a) * 2.4, top + 3.6, plant.z + math.sin(a) * 2.4), C.monarda, "SmoothPlastic", true, nil, v(math.sin(a) * 30, 0, -math.cos(a) * 30)))
			end
		else
			for i = 1, 6 do
				local a = i / 6 * TAU
				add(rec(`Spray{i}`, v(7, 1.6, 2), v(plant.x + math.cos(a) * 5, top + 6 + i * 1.6, plant.z + math.sin(a) * 4), C.goldenrod, "SmoothPlastic", true, nil, v(0, -math.deg(a), -30)))
			end
		end
	end
	-- the lawn's grass: tufts of blades on the open ground, and the mulch's chips on the pollinator bed (full)
	local placed = 0
	for _ = 1, 80 do
		if placed >= 34 then break end
		local x, z = between(rand, cx0 + 3, cx1 - 3), between(rand, cz0 + 3, cz1 - 3)
		local onPath = (x > Pa.ew.x0 - 4 and x < Pa.ew.x1 and z > Pa.ew.z0 - 4 and z < Pa.ew.z1 + 4) or (x > Pa.ns.x0 - 4 and x < Pa.ns.x1 + 4 and z > Pa.ns.z0 and z < Pa.ns.z1 + 4)
		local bed = bedAt(x, z)
		local free = true
		for _, p in Hut.pieces(region) do
			if p.id ~= id .. "_soil" and not string.find(p.id, "_bed", 1, true) and x > p.lo.X - 1.5 and x < p.hi.X + 1.5 and z > p.lo.Z - 1.5 and z < p.hi.Z + 1.5 then free = false; break end
		end
		if free and not onPath and z < -48 then
			placed += 1
			if bed == "pollinator" then
				local w = between(rand, 0.8, 2.2)
				add(rec(`Chip{placed}`, v(w, 0.25, w * between(rand, 0.4, 0.8)), v(x, S + 0.12, z), pick(C.mulchColors, rand), "Wood", true, nil, v(0, between(rand, 0, 180), 0)))
			elseif bed == nil then
				local h = between(rand, 5, 10)
				add(rec(`Tuft{placed}`, v(0.4, h, 0.4), v(x, GT + h / 2, z), pick(C.lawnColors, rand), "Grass", true, nil, v(between(rand, -14, 14), 0, between(rand, -14, 14))))
			end
		end
	end
end

local decorCache: { [string]: { Drawn } } = {}
-- The drawn look of a region of the hut or its garden, at the full tier (the low tier is the records without `full`).
function Hut.decor(region: Region): { Drawn }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = decorCache[key]
	if cached ~= nil then return cached end
	local budget = Hut.BUDGETS[region.kind]
	assert(budget ~= nil, "no budget for the region kind " .. region.kind)
	local list, add = sheet(budget)
	local k = region.kind
	if k == "hut_floor" then floorDecor(region, add)
	elseif k == "hut_desk" then deskDecor(region, add)
	elseif k == "hut_board" then boardDecor(region, add)
	elseif k == "hut_shelf" then shelfDecor(region, add)
	elseif k == "hut_door" then doorDecor(region, add)
	elseif k == "hut_outer_sill" then outerDecor(region, add)
	elseif k == "hut_bench" then benchDecor(region, add)
	elseif k == "hut_butt" then buttDecor(region, add)
	elseif k == "garden_pole" then poleDecor(region, add)
	elseif k == "garden_bed" then gardenDecor(region, add) end
	for _, d in list do table.freeze(d) end
	decorCache[key] = table.freeze(list)
	return list
end

-- ---------------------------------------------------------------- the garden's life
-- Species of the bestiary in the hut garden (docs/GARDEN_BESTIARY.md, the rows already sourced): fungus gnats over the beds' soil and oleander aphids on the
-- milkweed (World/Garden's W3 pair: one director), springtails in the mulch, leafhoppers on the goldenrod and the coneflower; woodlice under the trough and the
-- stone; a harvestman by the trough, a millipede under the stone and a ladybird on the milkweed among the aphids. From each cell's own seed by streams of their
-- own, so the same garden lives the same way.
export type Perch = { id: string, position: Vector3, normal: Vector3, shelter: number, food: number, start: boolean, walker: boolean?, kind: string,
	hop: boolean?, behind: string?, round: Vector3? }
export type Vent = { id: string, position: Vector3, normal: Vector3, walker: boolean?, reach: number?, appear: boolean? }
local SHELTER = { soil = 0.2, stone = 0.1, under = 0.6, leaf = 0.3, stem = 0.35 }
local FOOD = { soil = 0.1, stone = 0.05, under = 0.5, leaf = 0.5, stem = 0.5 }
Hut.LIFE = table.freeze({
	prey = { garden_c3 = { target = 6, soil = 8, plant = "milkweed" }, garden_c4 = { target = 4, soil = 6 } },
	springtails = { garden_d3 = { full = 4, low = 2, perches = 12 } },
	leafhoppers = { garden_d4 = { full = 2, low = 1 }, garden_c4 = { full = 1, low = 1 } },
	woodlice = { garden_a1 = 3, garden_a3 = 3 },
	ambient = { garden_a1 = { harvestman = { full = 1, low = 1, salt = 109 } }, garden_a3 = { millipede = { full = 1, low = 1, salt = 103 } },
		garden_c3 = { ladybird = { full = 1, low = 1, salt = 101 } } },
})

-- The standing boxes of a cell on a surface at `top` (their footprints), and a free spot on that surface inside `area` clear of them.
local function standingOn(region: Region, top: number): { Box }
	local out: { Box } = {}
	for _, p in Hut.pieces(region) do
		if math.abs(p.lo.Y - top) < 0.01 then table.insert(out, { min = p.lo, max = p.hi }) end
	end
	return out
end
local function freeSpot(rand: () -> number, area: { number }, top: number, standing: { Box }, taken: { Vector3 }, margin: number, apart: number): Vector3?
	for _ = 1, 50 do
		local x, z = between(rand, area[1] + 2, area[2] - 2), between(rand, area[3] + 2, area[4] - 2)
		local ok = true
		for _, b in standing do
			if x > b.min.X - margin and x < b.max.X + margin and z > b.min.Z - margin and z < b.max.Z + margin then ok = false; break end
		end
		if ok then for _, t in taken do if (Vector3.new(x, 0, z) - Vector3.new(t.X, 0, t.Z)).Magnitude < apart then ok = false; break end end end
		if ok then
			local p = v(x, top, z)
			table.insert(taken, p)
			return p
		end
	end
	return nil
end
-- The part of the pollinator bed's soil inside a cell, { x0, x1, z0, z1 }.
local function bedArea(region: Region): { number }?
	local b, E = Hut.POLLINATOR, Hut.EDGING.thick
	local lo, hi = region.bounds[1], region.bounds[2]
	local a, bb, c, d = clip(b.x0 + E, b.x1 - E, b.z0 + E, b.z1 - E, lo.X, hi.X, lo.Z, hi.Z)
	if a == nil then return nil end
	return { a, bb :: number, c :: number, d :: number }
end
local function byIdOf(region: Region): { [string]: Piece }
	local out: { [string]: Piece } = {}
	for _, p in Hut.pieces(region) do out[p.id] = p end
	return out
end

local preyCache: { [string]: any } = {}
-- The cell's gnats and aphids (one director, as the test garden's bed's): the gnats' perches on the bed's soil and under the plant's leaves, the aphids' on its
-- leaves and stem (walkers), the gnats' vents on the soil and the aphids' at the stem's foot. Nil for a cell without.
function Hut.prey(region: Region): any?
	local L = Hut.LIFE.prey[region.id]
	if L == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if preyCache[key] ~= nil then return preyCache[key] end
	-- (the gnats' soil perches lie round the plant, within a gnat's flight of one another: Data/Species, ten studs)
	local whole = bedArea(region) :: { number }
	local plant0 = PLANTS[region.id] :: any
	local area = { math.max(whole[1], plant0.x - 18), math.min(whole[2], plant0.x + 18), math.max(whole[3], plant0.z - 18), math.min(whole[4], plant0.z + 18) }
	local perches: { Perch } = {}
	local vents: { Vent } = {}
	local function perch(id: string, pos: Vector3, normal: Vector3, kind: string, start: boolean, walker: boolean?)
		table.insert(perches, { id = id, position = pos, normal = normal, shelter = (SHELTER :: any)[kind], food = (FOOD :: any)[kind], start = start, walker = walker, kind = kind })
	end
	local standing = standingOn(region, S)
	local taken: { Vector3 } = {}
	local rand = rng(region.seed, 61)
	local soilSpots: { Vector3 } = {}
	for i = 1, L.soil do
		local spot = freeSpot(rand, area, S, standing, taken, 1.0, 3)
		if spot then perch(`{region.id}_soil_{i}`, spot, Vector3.yAxis, "soil", i <= 2); table.insert(soilSpots, spot) end
	end
	local plant = PLANTS[region.id]
	local byId = byIdOf(region)
	if plant ~= nil then
		local base = `{region.id}_{plant.kind}`
		local spec = PLANT_SPECS[plant.kind]
		for i = 1, #spec.leaves do
			local leaf = byId[`{base}_leaf_{i}`]
			if leaf ~= nil then
				local cx, cz = (leaf.lo.X + leaf.hi.X) / 2, (leaf.lo.Z + leaf.hi.Z) / 2
				perch(leaf.id .. "_under", v(cx, leaf.lo.Y, cz), -Vector3.yAxis, "under", i == 1)
				if L.plant == plant.kind then perch(leaf.id .. "_top", v(cx, leaf.hi.Y, cz), Vector3.yAxis, "leaf", i <= 2, true) end
			end
		end
		local stem = byId[base .. "_stem"]
		if L.plant == plant.kind and stem ~= nil then
			perch(stem.id .. "_side", v(stem.hi.X, S + 12, (stem.lo.Z + stem.hi.Z) / 2), Vector3.xAxis, "stem", true, true)
			table.insert(vents, { id = region.id .. "_vent_" .. plant.kind, position = v(stem.hi.X + 1.2, S, (stem.lo.Z + stem.hi.Z) / 2), normal = Vector3.yAxis, walker = true, reach = 60 })
		end
	end
	for i = 1, 2 do
		local spot: Vector3? = nil
		for _ = 1, 12 do
			local try = freeSpot(rand, area, S, standing, taken, 1.0, 3)
			if try == nil then break end
			for _, sp in soilSpots do
				local d = (sp - try).Magnitude
				if d >= 4 and d <= 12 then spot = try; break end
			end
			if spot ~= nil then break end
		end
		if spot then table.insert(vents, math.min(1 + (i - 1) * 2, #vents + 1), { id = `{region.id}_vent_soil_{i}`, position = spot, normal = Vector3.yAxis }) end
	end
	local out = { perches = perches, vents = vents, target = L.target, seed = region.seed, prefix = region.id .. "_fly_" }
	preyCache[key] = out
	return out
end

local bugsCache: { [string]: any } = {}
-- The cell's woodlice: their starting places on the lawn and the spots they hide in (the mouths of the gap under the trough or the stone, the feet beside them).
function Hut.bugs(region: Region): any?
	local count = Hut.LIFE.woodlice[region.id]
	if count == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if bugsCache[key] ~= nil then return bugsCache[key] end
	local hides = {}
	for _, t in region.retreats do
		local cx = (t.min.X + t.max.X) / 2
		table.insert(hides, { pos = v(cx, GT, t.max.Z + 0.6), kind = "stone" })
		table.insert(hides, { pos = v(cx, GT, t.min.Z - 0.6), kind = "stone" })
	end
	local lo, hi = region.bounds[1], region.bounds[2]
	local standing = standingOn(region, GT)
	local taken: { Vector3 } = {}
	local rand = rng(region.seed, 67)
	local lice = {}
	for _ = 1, count do
		local spot = freeSpot(rand, { lo.X, hi.X, lo.Z, -50 }, GT, standing, taken, 1.0, 6)
		if spot then
			local a = rand() * TAU
			table.insert(lice, { pos = spot, heading = v(math.cos(a), 0, math.sin(a)) })
		end
	end
	local out = { woodlice = lice, hides = hides, seed = region.seed, prefix = region.id .. "_" }
	bugsCache[key] = out
	return out
end

local bestiaryCache: { [string]: any } = {}
-- The cell's bestiary prey, a spec per kind (World/Garden.bestiary's shape): springtails in the mulch round the bark chip and the stone; leafhoppers in pairs
-- either side of the plant's stem, low and high, and its leaves.
function Hut.bestiary(region: Region): { any }?
	local spring, hopper = Hut.LIFE.springtails[region.id], Hut.LIFE.leafhoppers[region.id]
	if spring == nil and hopper == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if bestiaryCache[key] ~= nil then return bestiaryCache[key] end
	local out = {}
	if spring ~= nil then
		local salt = 71
		local rand = rng(region.seed, salt)
		local area = bedArea(region) :: { number }
		local standing = standingOn(region, S)
		for _, t in region.retreats do table.insert(standing, { min = t.min - v(0.5, 0, 0.5), max = t.max + v(0.5, 0, 0.5) }) end
		local centres: { Vector3 } = {}
		for _, t in region.retreats do table.insert(centres, v((t.min.X + t.max.X) / 2, S, t.max.Z + 1.2)) end
		for _, p in Hut.pieces(region) do if string.find(p.id, "_stone_", 1, true) ~= nil then table.insert(centres, v((p.lo.X + p.hi.X) / 2, S, p.hi.Z + 1.2)) end end
		local perches: { Perch } = {}
		local taken: { Vector3 } = {}
		for i = 1, spring.perches do
			local c = centres[(i - 1) % #centres + 1]
			local spot = freeSpot(rand, { math.max(area[1], c.X - 8), math.min(area[2], c.X + 8), math.max(area[3], c.Z - 6), math.min(area[4], c.Z + 6) }, S, standing, taken, 0.3, 1.0)
			if spot then table.insert(perches, { id = `{region.id}_springtail_{#perches + 1}`, position = spot, normal = Vector3.yAxis, shelter = 0.5, food = 0.4, start = #perches < spring.full, kind = "soil", hop = true }) end
		end
		local vents: { Vent } = {}
		for i, c in centres do if i <= 2 then table.insert(vents, { id = `{region.id}_vent_springtail_{i}`, position = c, normal = Vector3.yAxis, appear = true, reach = 6 }) end end
		table.insert(out, { kind = "springtail", profile = "springtail_prototype", perches = perches, vents = vents, target = spring.full, low = spring.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_springtail_fly_` })
	end
	if hopper ~= nil then
		local salt = 73
		local plant = PLANTS[region.id] :: any
		local byId = byIdOf(region)
		local stem = byId[`{region.id}_{plant.kind}_stem`] :: Piece
		local perches: { Perch } = {}
		local n = 0
		local function pair(a: Vector3, na: Vector3, b: Vector3, nb: Vector3, round: Vector3, kind: string, start: boolean)
			n += 1
			local ia, ib = `{region.id}_leafhopper_{n}a`, `{region.id}_leafhopper_{n}b`
			table.insert(perches, { id = ia, position = a, normal = na, shelter = 0.4, food = 0.6, start = start, kind = kind, hop = true, behind = ib, round = round })
			table.insert(perches, { id = ib, position = b, normal = nb, shelter = 0.4, food = 0.6, start = false, kind = kind, hop = true, behind = ia, round = round })
		end
		local mx, mz = (stem.lo.X + stem.hi.X) / 2, (stem.lo.Z + stem.hi.Z) / 2
		for k, h in { 9, 31, 49 } do
			local y = S + h
			if k % 2 == 1 then pair(v(stem.hi.X, y, mz), Vector3.xAxis, v(stem.lo.X, y, mz), -Vector3.xAxis, v(mx, y, stem.hi.Z + 0.35), "stem", k == 1)
			else pair(v(mx, y, stem.hi.Z), Vector3.zAxis, v(mx, y, stem.lo.Z), -Vector3.zAxis, v(stem.hi.X + 0.35, y, mz), "stem", false) end
		end
		local vents: { Vent } = { { id = `{stem.id}_vent_leafhopper`, position = v(mx, S, stem.lo.Z - 0.8), normal = Vector3.yAxis, appear = true, reach = 60 } }
		table.insert(out, { kind = "leafhopper", profile = "leafhopper_prototype", perches = perches, vents = vents, target = hopper.full, low = hopper.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_leafhopper_fly_` })
	end
	bestiaryCache[key] = out
	return out
end

-- The milkweed as walks over its faces, for the aphids that creep from leaf to leaf and the ladybird among them (World/Garden.plants' shape): its highway the
-- stem's north face from its foot to its top, a node on each leaf's top (an aphid's perch) and at the stem's foot and top.
export type PlantPoint = { pos: Vector3, normal: Vector3 }
export type Plant = { id: string, loop: boolean, highway: { PlantPoint }, nodes: { [string]: { hub: number, route: { PlantPoint } } }, order: { string } }
local plantsCache: { [string]: { [string]: Plant } } = {}
local plantOfPerch: { [string]: string } = {}
local function unit(a: Vector3, b: Vector3): Vector3 return (a + b).Unit end
function Hut.plants(region: Region): { [string]: Plant }?
	if Hut.LIFE.ambient[region.id] == nil or Hut.LIFE.ambient[region.id].ladybird == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if plantsCache[key] ~= nil then return plantsCache[key] end
	local plant = PLANTS[region.id] :: any
	local spec = PLANT_SPECS[plant.kind]
	local byId = byIdOf(region)
	local base = `{region.id}_{plant.kind}`
	local stem = byId[base .. "_stem"] :: Piece
	local s0, s1 = stem.lo, stem.hi
	local mx, mz = (s0.X + s1.X) / 2, (s0.Z + s1.Z) / 2
	local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	local function pt(pos: Vector3, normal: Vector3): PlantPoint return { pos = pos, normal = normal } end
	local heights: { number } = {}
	local pending: { { id: string, y: number, route: { PlantPoint } } } = {}
	local function add(id: string, y: number, route: { PlantPoint })
		table.insert(pending, { id = id, y = y, route = route })
		if table.find(heights, y) == nil then table.insert(heights, y) end
	end
	add(base .. "_foot", S + 0.5, {})
	for i, leaf in spec.leaves :: { Leaf } do
		local box = byId[`{base}_leaf_{i}`]
		if box ~= nil then
			local y1 = box.hi.Y
			local centre = pt(v((box.lo.X + box.hi.X) / 2, y1, (box.lo.Z + box.hi.Z) / 2), Y)
			local route: { PlantPoint }
			if leaf.dir == "x+" then route = { pt(v(s1.X, y1, s0.Z), unit(X, -Z)), pt(v(s1.X, y1, mz), unit(X, Y)), centre }
			elseif leaf.dir == "x-" then route = { pt(v(s0.X, y1, s0.Z), unit(-X, -Z)), pt(v(s0.X, y1, mz), unit(-X, Y)), centre }
			elseif leaf.dir == "z+" then route = { pt(v(s0.X, y1, s0.Z), unit(-X, -Z)), pt(v(s0.X, y1, s1.Z), unit(-X, Z)), pt(v(mx, y1, s1.Z), unit(Z, Y)), centre }
			else route = { pt(v(mx, y1, s0.Z), unit(-Z, Y)), centre } end
			add(box.id .. "_top", y1, route)
		end
	end
	add(base .. "_top", s1.Y - 0.6, {})
	table.sort(heights)
	local highway: { PlantPoint } = {}
	for _, y in heights do table.insert(highway, pt(v(mx, y, s0.Z), -Z)) end
	local nodes = {}
	local order = {}
	for _, n in pending do
		nodes[n.id] = { hub = table.find(heights, n.y) :: number, route = n.route }
		table.insert(order, n.id)
		plantOfPerch[n.id] = plant.kind
	end
	local out = { [plant.kind] = { id = plant.kind, loop = false, highway = highway, nodes = nodes, order = order } :: Plant }
	plantsCache[key] = out
	return out
end
-- The plant a perch is on, and its cell's plants (nil for none): every cell with plants is made the first time it is asked (`regions`: the active world's).
function Hut.plantOf(perchId: string, regions: { Region }): (string?, { [string]: Plant }?)
	local name = plantOfPerch[perchId]
	if name == nil then
		for _, r in regions do if Hut.knows(r.kind) then Hut.plants(r) end end
		name = plantOfPerch[perchId]
	end
	if name == nil then return nil, nil end
	for _, r in regions do
		if Hut.knows(r.kind) then
			local plants = Hut.plants(r)
			if plants ~= nil and plants[name] ~= nil and plants[name].nodes[perchId] ~= nil then return name, plants end
		end
	end
	return nil, nil
end

local ambientCache: { [string]: any } = {}
-- The cell's ambient bugs, a spec per kind in World/Garden.AMBIENT.order (Garden.ambient's shape): the harvestman on the lawn by the trough, its corner the
-- trough's gap by day; the millipede on the lawn, under the stone by turns; the ladybird on the milkweed.
function Hut.ambient(region: Region): { any }?
	local rows = Hut.LIFE.ambient[region.id]
	if rows == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if ambientCache[key] ~= nil then return ambientCache[key] end
	local out = {}
	local lo, hi = region.bounds[1], region.bounds[2]
	for _, kind in { "ladybird", "millipede", "snail", "harvestman" } do
		local row = (rows :: any)[kind]
		if row ~= nil then
			local rand = rng(region.seed, row.salt)
			local spec: any = { kind = kind, seed = (region.seed + row.salt * 104729) % MOD, full = row.full, low = row.low, starts = {}, prefix = region.id .. "_" }
			if kind == "ladybird" then
				local plants = Hut.plants(region) :: { [string]: Plant }
				for name, plant in plants do
					for _ = 1, row.full do table.insert(spec.starts, { plant = name, node = plant.order[1 + math.floor(rand() * #plant.order)] }) end
				end
			else
				local standing = standingOn(region, GT)
				for _, t in region.retreats do table.insert(standing, { min = t.min - v(0.5, 0, 0.5), max = t.max + v(0.5, 0, 0.5) }) end
				local taken: { Vector3 } = {}
				for _ = 1, row.full do
					local spot = freeSpot(rand, { lo.X, hi.X, lo.Z, -50 }, GT, standing, taken, 1.2, 6)
					if spot then
						local a = rand() * TAU
						table.insert(spec.starts, { pos = spot, heading = v(math.cos(a), 0, math.sin(a)) })
					end
				end
				local hides = (Hut.bugs(region) or { hides = {} }).hides
				if kind == "millipede" then spec.hides = hides end
				if kind == "harvestman" then spec.home = if #hides > 0 then hides[1].pos else v((lo.X + hi.X) / 2, GT, (lo.Z + hi.Z) / 2) end
			end
			spec.surface = "soil"
			table.insert(out, spec)
		end
	end
	ambientCache[key] = out
	return out
end

return Hut
