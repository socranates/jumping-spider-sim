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
--                     linings to WALL_TOP (a metre and a third over the floor; ROBLOX-118: the upper walls and the ceiling are the hut_up_* cells over them). The apron
--                     under the sill in hut_floor_b: the sill's front face goes on down to the floor.
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
-- ROBLOX-117 (Phase B round 2: the garden rich at the spider's eye, its life, the path round the east end):
--   path_s1..path_e6 .. the gravel path round the hut's east end, from the door's gravel to the garden's path (Hut.WALK), 60 cm wide.
--   the plants ......... a second milkweed, coneflower, bee balm and goldenrod (MORE_PLANTS), every plant drawn whole over its walkable boxes (the leaves as blades
--                        with midribs, the umbels, rays and cone, whorled heads and arching plumes); the bed's mulch mottled and chipped in the cells' looks.
--   the patches ........ each garden cell and length of path cut into patches of PATCH studs, drawn-only looks (kind "patch") of what the spider sees close: grass
--                        blades at true size in tufts, seed heads and clover, layered shredded bark, leaf bits, twigs, seeds and soil, gravel stones, the husks and a
--                        cardinal's feather under the feeder, petals under the flowers, and the morning's dew; World/LookPlan draws them only near the spider.
--   the life ............ the hoverflies on the bed's flowers, the fruit flies at a compost caddy by the door, a moth at the desk lamp from dusk; and where the rival
--                        and the mate come into the garden and the cells they roam (CREATURES, ROAM: never the hut).
-- ROBLOX-118 (Phase B round 3: the ceiling, the back room, the eaves, the meadow path):
--   hut_up_a..i, room_up_a..i .. over each floor cell of both rooms, the walls' linings from WALL_TOP to the ceiling and the ceiling's boards on their joists (CEIL, JOISTS);
--                        the house spider's web drawn in hut_up_a's corner.
--   hut_door_up ........ the front door's leaf and jambs above DOOR.top to its head, and the wall over it to the ceiling.
--   hut_doorway(_up) ... the doorway cut through the hut's old east logs into the back room (DOORWAY), in two at WALL_TOP.
--   room_floor_a..i .... the volunteers' back room's floor (BACK), its linings, skirting, rug, the radiator under the window, the cables and sockets.
--   room_sofa_w/e, room_tv, room_games, room_window .. its sofa (the gap under it, room_sofa_under, is room_floor_h's home), the television's unit, the board games' shelf,
--                        the east window and its deep sill.
--   hut_wall_x1..x3, hut_eave_w2..x4 .. the back room's north logs outside, and the whole north face from OUT_TOP to the soffit, the fascia and the gutter (EAVE, EAVES).
--   path_s3..s5, path_e1..e5 (moved), path_n1..n3, path_m1..m4 .. the path round the back room's east end, and on north toward the meadow (WALK).
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
	dew: number?, -- (ROBLOX-117: a dew drop's lag, Habitat/DayLight.applyDew; its `transparency` is the one it has at full dew)
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
-- (ROBLOX-117) The gravel path round the hut's east end: from the door's gravel (hut_door, x -60..60) east along the south wall's foot (z 287..347, the hut's base
-- lip at 284..287 is the backdrop's), north past the east end 57 cm out from the logs (x 235..295), and west into the garden's own path at the core's edge (x 200,
-- z -196..-146). 60 cm wide, fine gravel at true size (2 to 10 mm stones: the patches' look). Each region whole inside the streaming radius from anywhere on it.
-- (ROBLOX-118) The volunteers' back room stands against the hut's east end, so the path goes round the back room's east end instead: along the south wall's foot to
-- x 590, north 57 cm out from the back room's east logs (x 530..590), and west along z -196..-146 to the garden's path (path_e6, where it always met it). The lengths
-- path_e1..e5 keep their ids at their new place (WorldMap's preserve revision moved: preserve-2). And the meadow path, path_m1..m4: the garden's own north-south
-- gravel path goes on north out of the core (x -90..-30) to the herb border's gap and the mown loop at z 13 m, so the world visibly goes on toward the meadow.
Hut.WALK = table.freeze({
	table.freeze({ id = "path_s1", x0 = 60, x1 = 178, z0 = 287, z1 = 347 }),
	table.freeze({ id = "path_s2", x0 = 178, x1 = 295, z0 = 287, z1 = 347 }),
	table.freeze({ id = "path_s3", x0 = 295, x1 = 412, z0 = 287, z1 = 347 }),
	table.freeze({ id = "path_s4", x0 = 412, x1 = 530, z0 = 287, z1 = 347 }),
	table.freeze({ id = "path_s5", x0 = 530, x1 = 590, z0 = 287, z1 = 347 }),
	table.freeze({ id = "path_e1", x0 = 530, x1 = 590, z0 = 200, z1 = 287 }),
	table.freeze({ id = "path_e2", x0 = 530, x1 = 590, z0 = 113, z1 = 200 }),
	table.freeze({ id = "path_e3", x0 = 530, x1 = 590, z0 = 26, z1 = 113 }),
	table.freeze({ id = "path_e4", x0 = 530, x1 = 590, z0 = -60, z1 = 26 }),
	table.freeze({ id = "path_e5", x0 = 530, x1 = 590, z0 = -146, z1 = -60 }),
	table.freeze({ id = "path_n3", x0 = 530, x1 = 590, z0 = -196, z1 = -146 }),
	table.freeze({ id = "path_n2", x0 = 412, x1 = 530, z0 = -196, z1 = -146 }),
	table.freeze({ id = "path_n1", x0 = 295, x1 = 412, z0 = -196, z1 = -146 }),
	table.freeze({ id = "path_e6", x0 = 200, x1 = 295, z0 = -196, z1 = -146 }),
	table.freeze({ id = "path_m1", x0 = -90, x1 = -30, z0 = -516, z1 = -416 }),
	table.freeze({ id = "path_m2", x0 = -90, x1 = -30, z0 = -616, z1 = -516 }),
	table.freeze({ id = "path_m3", x0 = -90, x1 = -30, z0 = -716, z1 = -616 }),
	table.freeze({ id = "path_m4", x0 = -90, x1 = -30, z0 = -816, z1 = -716 }),
})

-- (ROBLOX-118) The ceiling, the back room and the hut's outside to its eaves.
-- The ceiling: boards whose underside is CEIL (2.2 m over the floor), on joists 4.5 by 14 cm every 60 cm across the short span (north to south), in both rooms.
Hut.CEIL = 150
Hut.JOISTS = table.freeze({ hut = table.freeze({ -90, -30, 30, 90 }), back = table.freeze({ 220, 280, 340, 400 }), w = 4.5, d = 14 })
-- The volunteers' back room: a log room built on against the hut's east end, 2.7 by 2.43 m between its linings (its east logs' outer face at x 473.5), the same floor
-- and ceiling as the hut's; the doorway cut through the hut's old east logs (x 146.5..175) at z 180..250, its head 2.05 m over the floor.
Hut.BACK = table.freeze({ x0 = 175, x1 = 445, z0 = 12.5, z1 = 255.5, east = 473.5 })
Hut.BACK_COLS = table.freeze({ 175, 265, 355, 445 })
Hut.DOORWAY = table.freeze({ x0 = 146.5, x1 = 175, z0 = 180, z1 = 250, head = 135, core = table.freeze({ 156.5, 165 }) })
-- What is in it, true sizes: a two-seat sofa 2 m long against the south wall (its seat 45 cm over the floor, its back 85, its arms 70, on legs 8 cm tall: the gap under it
-- is the darkest place in the hut, and a home); a low unit against the north wall with a 32-inch television on it and a games console on its shelf (the controller lies
-- on the sofa's cushion); a shelf of board games in the north-east corner, 1.2 m tall; a rug; the window in the east wall over an oil-filled radiator (a space heater
-- on its feet, its fins 7 cm apart); the cables along the skirting to their sockets.
Hut.SOFA = table.freeze({ x0 = 225, x1 = 425, z0 = 165.5, z1 = 254, arm = 20, leg = -62, frame = -38, seat = -25, back = 15, armTop = 0, split = 325,
	under = table.freeze({ min = v(275, -70, 195), max = v(315, -68.6, 235), door = v(295, -69.5, 163.5) }) })
Hut.TV = table.freeze({ x0 = 185, x1 = 275, z0 = 14, z1 = 52.5, top = -20, screen = table.freeze({ x0 = 193.5, x1 = 266.5, y0 = -14, y1 = 29, z0 = 25, z1 = 29 }) })
Hut.GAMES = table.freeze({ x0 = 360, x1 = 440, z0 = 14, z1 = 44, top = 50 })
Hut.HEATER = table.freeze({ x0 = 425, x1 = 441, z0 = 100, z1 = 158, top = -7, fins = 7 })
Hut.RUG = table.freeze({ x0 = 230, x1 = 400, z0 = 96, z1 = 164, top = 1 })
Hut.ROOM_WINDOW = table.freeze({ z0 = 98, z1 = 170, glass = 459, sill = 429, head = 112.5, top = 115 })
-- The north face outside, to the eaves: the logs to the soffit's underside (EAVE.soffit, 2.18 m over the ground), the boxed soffit under the roof's overhang, the
-- fascia board and the gutter hung on it (its floor 2.06 m over the ground): the roof's walkable edge. The roof's slope (35 degrees) is drawn only.
Hut.BUILDING = table.freeze({ x0 = -175, x1 = 473.5 })
Hut.EAVE = table.freeze({ x0 = -205, x1 = 503.5, soffit = 133, soffitTop = 135, out = -46, fascia = table.freeze({ out = -48, bottom = 124 }),
	gutter = table.freeze({ floor = 121, thick = 1.5, out = -60, wall = 1.5, lip = 131, cap = 2 }) })

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
	-- (ROBLOX-118) the ceiling and the back room
	ceiling = "cdb08a", joist = "a88a62", rug = "7a3b32", cable = "1e1e1e", heater = "e6e2d8", heaterDark = "8f8b84", sofa = "4f6170", sofaDark = "3f4e5a",
	controller = "26282b", unit = "8e6a45", unitDark = "6f5235", console = "f0f0ee", screen = "16181b", gutter = "6f7377",
	games = { "b8322a", "2f5f8a", "e0b23a", "3e7a4a", "e8e2d0", "6a3d7a", "d97a2b", "2b2b2b", "9fb8c8", "c7a27c" },
}

-- (ROBLOX-117) The rival and the mate in the preserve: they come into the hut garden, the rival along the gravel path from the north (it arrives at the path's end in
-- garden_d2) and the mate along the path round the east end (at the garden's path where it comes in, garden_b4), and roam its sixteen cells (ROAM: Predator/RivalDrive's
-- `roam`), never the hut: while the nursery is shut the spider is in it, and it is the spider's alone. The mate leaves the way it came.
Hut.CREATURES = table.freeze({
	rival = table.freeze({ region = "garden_d2", at = v(-60, GT + 0.31, -380) }),
	mate = table.freeze({ region = "garden_b4", at = v(185, GT + 0.31, -171), exit = v(192, GT + 0.31, -171) }),
})
local ROAM: { [string]: boolean } = {}
for _, row in { "a", "b", "c", "d" } do for c = 1, 4 do ROAM[`garden_{row}{c}`] = true end end
Hut.ROAM = table.freeze(ROAM)

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
local PLANTS: { [string]: { kind: string, x: number, z: number, scale: number? } } = {
	garden_c3 = { kind = "milkweed", x = 50, z = -266 },
	garden_c4 = { kind = "coneflower", x = 150, z = -266 },
	garden_d3 = { kind = "beebalm", x = 70, z = -380 },
	garden_d4 = { kind = "goldenrod", x = 150, z = -362 },
}
Hut.PLANTS = PLANTS
-- (ROBLOX-117) A second plant of the same kind in each of the bed's cells, younger and a little shorter, so the bed is a stand and not four stems: a milkweed
-- sucker beside the first (milkweed spreads by its roots into colonies), a second coneflower, bee balm and goldenrod. Walkable as the first; the life keeps to
-- the first (its perches, its highway).
local MORE_PLANTS: { [string]: { kind: string, x: number, z: number, scale: number? } } = {
	garden_c3 = { kind = "milkweed", x = 22, z = -290, scale = 0.8 },
	garden_c4 = { kind = "coneflower", x = 128, z = -296, scale = 0.9 },
	garden_d3 = { kind = "beebalm", x = 40, z = -340, scale = 0.9 },
	garden_d4 = { kind = "goldenrod", x = 122, z = -392, scale = 0.85 },
}
Hut.MORE_PLANTS = MORE_PLANTS

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
	-- (ROBLOX-118) the gap under the back room's sofa, deep in from its front edge: the darkest place in the hut (the floor's: the sofa's own region starts at its frame)
	room_floor_h = { id = "room_sofa_under", min = Hut.SOFA.under.min, max = Hut.SOFA.under.max, door = Hut.SOFA.under.door },
}

-- (ROBLOX-118) The upper cells (the walls from WALL_TOP to the ceiling, the ceiling and its joists over each floor cell of both rooms): their room and rectangle.
local UPPER: { [string]: { room: string, x0: number, x1: number, z0: number, z1: number } } = {}
local UPPER_IDS: { string } = {}
for r = 1, 3 do
	for c = 1, 3 do
		local letter = FLOOR_IDS[(r - 1) * 3 + c]
		for _, room in { "hut", "back" } do
			local cols = if room == "hut" then Hut.COLS else Hut.BACK_COLS
			local id = (if room == "hut" then "hut_up_" else "room_up_") .. letter
			UPPER[id] = { room = room, x0 = cols[c], x1 = cols[c + 1], z0 = Hut.ROWS[r], z1 = Hut.ROWS[r + 1] }
		end
	end
end
for _, room in { "hut", "back" } do
	for _, letter in FLOOR_IDS do table.insert(UPPER_IDS, (if room == "hut" then "hut_up_" else "room_up_") .. letter) end
end
Hut.UPPER = UPPER
-- The outside regions of the north face from WALL_TOP's outside height (OUT_TOP) to the eaves, west to east: x0..x1 of their logs and of their share of the eaves.
-- (each about 72 to 100 studs along the wall, so a region is whole inside the streaming radius from anywhere on it: the logs are a metre high)
local EAVES: { { id: string, x0: number, x1: number, ex0: number, ex1: number } } = {
	{ id = "hut_eave_w2", x0 = -175, x1 = -103, ex0 = -205, ex1 = -103 },
	{ id = "hut_eave_w1", x0 = -103, x1 = -31, ex0 = -103, ex1 = -31 },
	{ id = "hut_eave_mid", x0 = -31, x1 = 31, ex0 = -31, ex1 = 31 },
	{ id = "hut_eave_e1", x0 = 31, x1 = 103, ex0 = 31, ex1 = 103 },
	{ id = "hut_eave_e2", x0 = 103, x1 = 175, ex0 = 103, ex1 = 175 },
	{ id = "hut_eave_x1", x0 = 175, x1 = 250, ex0 = 175, ex1 = 250 },
	{ id = "hut_eave_x2", x0 = 250, x1 = 325, ex0 = 250, ex1 = 325 },
	{ id = "hut_eave_x3", x0 = 325, x1 = 400, ex0 = 325, ex1 = 400 },
	{ id = "hut_eave_x4", x0 = 400, x1 = 473.5, ex0 = 400, ex1 = 503.5 },
}
Hut.EAVES = EAVES

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
	-- (ROBLOX-118) the door's leaf and jambs above WALL_TOP's door height to its head, and the wall over it to the ceiling; the doorway to the back room; the back room's
	-- window over the radiator, the television's unit, the shelf of board games and the sofa (in two halves, each whole inside the streaming radius)
	local D, DW, B, SO = Hut.DOOR, Hut.DOORWAY, Hut.BACK, Hut.SOFA
	region("hut_door_up", "hut_door_up", v(-D.jamb, D.top, R.z1), v(D.jamb, Hut.CEIL, D.outer), v(0, 80, D.leaf[1]), v(0, 1, 0), 1.0)
	region("hut_doorway", "hut_doorway", v(DW.x0, FL - 3, 174.5), v(DW.x1, Hut.WALL_TOP, B.z1), v((DW.x0 + DW.x1) / 2, FL, (DW.z0 + DW.z1) / 2), v(1, 0, 0), 1.0)
	region("hut_doorway_up", "hut_doorway", v(DW.x0, Hut.WALL_TOP, 174.5), v(DW.x1, Hut.CEIL, B.z1), v((DW.core[1] + DW.core[2]) / 2, 100, DW.z0), v(0, 1, 0), 1.0)
	region("room_window", "room_window", v(B.x1 - 20, -5, 93.5), v(Hut.ROOM_WINDOW.glass + 1, Hut.ROOM_WINDOW.top + 3, 174.5), v(437, 0, 134), v(1, 0, 0), 1.0)
	region("room_tv", "room_tv", v(Hut.TV.x0, FL + 1, Hut.TV.z0), v(Hut.TV.x1, Hut.TV.screen.y1 + 3, Hut.TV.z1 + 3), v(230, Hut.TV.top, 45), v(0, 0, 1), 1.0)
	region("room_games", "room_games", v(Hut.GAMES.x0, FL + 1, Hut.GAMES.z0), v(Hut.GAMES.x1, Hut.GAMES.top + 5, Hut.GAMES.z1 + 4), v(400, Hut.GAMES.top, 30), v(0, 0, 1), 1.0)
	region("room_sofa_w", "room_sofa", v(SO.x0 - 5, FL + 0.9, SO.z0 - 5), v(SO.split, SO.back + 3, SO.z1), v(262, SO.seat, 215), v(0, 0, -1), 1.0)
	region("room_sofa_e", "room_sofa", v(SO.split, FL + 0.9, SO.z0 - 5), v(SO.x1 + 5, SO.back + 3, SO.z1), v(365, SO.seat, 200), v(0, 0, -1), 1.0)
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = Hut.COLS[c], Hut.COLS[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
			region(floorCell(c, r), "hut_floor", v(x0, FL - 3, z0), v(x1, Hut.WALL_TOP, z1), v((x0 + x1) / 2, FL, (z0 + z1) / 2), v(0, 0, -1), 1.0)
		end
	end
	-- (ROBLOX-118) the back room's floor in nine cells, as the hut's
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = Hut.BACK_COLS[c], Hut.BACK_COLS[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
			local spawn = v((x0 + x1) / 2, FL + (if (x0 + x1) / 2 > Hut.RUG.x0 and (x0 + x1) / 2 < Hut.RUG.x1 and (z0 + z1) / 2 > Hut.RUG.z0 and (z0 + z1) / 2 < Hut.RUG.z1 then Hut.RUG.top else 0), (z0 + z1) / 2)
			if r == 3 and c == 2 then spawn = v(340, FL, 215) end -- (under the sofa, beside its gap)
			if r == 2 and c == 3 then spawn = v(415, FL, 134) end -- (off the rug's edge, short of the radiator)
			region("room_floor_" .. FLOOR_IDS[(r - 1) * 3 + c], "room_floor", v(x0, FL - 3, z0), v(x1, Hut.WALL_TOP, z1), spawn, v(0, 0, -1), 1.0)
		end
	end
	-- (ROBLOX-118) the upper walls and the ceiling over every floor cell of both rooms: the spider walks them all, head down on the ceiling
	for _, id in UPPER_IDS do
		local U = UPPER[id]
		-- (the cells by the doorway reach into the old logs to the doorway's cut, where their lining meets it)
		local bx0 = if id == "room_up_g" then Hut.DOORWAY.core[2] - 0.5 else U.x0
		local bx1 = if id == "hut_up_i" then Hut.DOORWAY.core[1] + 0.5 else U.x1
		-- (its spawn on the east face of its joist, part way up: a place a body can be put, where the ceiling's underside cannot)
		local J = Hut.JOISTS
		local jx = U.x0
		for _, x in (if U.room == "hut" then J.hut else J.back) :: { number } do if x > U.x0 and x < U.x1 then jx = x; break end end
		region(id, "hut_upper", v(bx0, Hut.WALL_TOP, U.z0), v(bx1, Hut.CEIL + 2, U.z1), v(jx + J.w / 2, Hut.CEIL - J.d / 2, (U.z0 + U.z1) / 2), v(0, 0, -1), 1.0)
	end
	region("hut_wall_mid", "hut_wall", v(-31, -71, -24), v(31, -4, -16), v(0, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_w", "hut_wall", v(-185, -71, -26), v(-31, Hut.OUT_TOP, -16), v(-120, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_e", "hut_wall", v(31, -71, -26), v(175, Hut.OUT_TOP, -16), v(120, -20, -16), v(0, 1, 0), 1.0)
	-- (ROBLOX-118) the back room's north logs outside, and the north face from OUT_TOP to the eaves, its soffit, fascia and gutter
	region("hut_wall_x1", "hut_wall", v(175, GT - 0.5, -26), v(275, Hut.OUT_TOP, -16), v(225, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_x2", "hut_wall", v(275, GT - 0.5, -26), v(375, Hut.OUT_TOP, -16), v(325, -20, -16), v(0, 1, 0), 1.0)
	region("hut_wall_x3", "hut_wall", v(375, GT - 0.5, -26), v(483.5, Hut.OUT_TOP, -16), v(425, -20, -16), v(0, 1, 0), 1.0)
	local EV = Hut.EAVE
	for _, e in EAVES do
		region(e.id, "hut_eave", v(e.ex0 - (if e.id == "hut_eave_mid" then 6 else 0), Hut.OUT_TOP, EV.gutter.out - 3), v(e.ex1 + (if e.id == "hut_eave_mid" then 6 else 0), EV.soffitTop + 4, Hut.WALL_SPLIT),
			v((e.x0 + e.x1) / 2, EV.gutter.floor + EV.gutter.thick, (EV.gutter.out + EV.fascia.out) / 2), v(1, 0, 0), 1.0)
	end
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
	-- (ROBLOX-117) the gravel path round the hut's east end, from the door's gravel to the garden's path
	for _, w in Hut.WALK do
		region(w.id, "hut_path", v(w.x0, -87, w.z0), v(w.x1, GT + 40, w.z1), v((w.x0 + w.x1) / 2, GT, (w.z0 + w.z1) / 2), v(0, 0, -1), 0.33)
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
	-- (ROBLOX-117) the path round the east end: out of the door's gravel, along the south wall, round the corner, north and into the garden's path
	seam("hut_door", "path_s1", v(60, GT, 290), v(60, GT, 338))
	seam("path_s1", "path_s2", v(178, GT, 290), v(178, GT, 344))
	-- (ROBLOX-118) on round the back room's east end
	seam("path_s2", "path_s3", v(295, GT, 290), v(295, GT, 344))
	seam("path_s3", "path_s4", v(412, GT, 290), v(412, GT, 344))
	seam("path_s4", "path_s5", v(530, GT, 290), v(530, GT, 344))
	seam("path_s5", "path_e1", v(533, GT, 287), v(587, GT, 287))
	seam("path_e1", "path_e2", v(533, GT, 200), v(587, GT, 200))
	seam("path_e2", "path_e3", v(533, GT, 113), v(587, GT, 113))
	seam("path_e3", "path_e4", v(533, GT, 26), v(587, GT, 26))
	seam("path_e4", "path_e5", v(533, GT, -60), v(587, GT, -60))
	seam("path_e5", "path_n3", v(533, GT, -146), v(587, GT, -146))
	seam("path_n3", "path_n2", v(530, GT, -193), v(530, GT, -149))
	seam("path_n2", "path_n1", v(412, GT, -193), v(412, GT, -149))
	seam("path_n1", "path_e6", v(295, GT, -193), v(295, GT, -149))
	seam("path_e6", "garden_b4", v(200, GT, -193), v(200, GT, -149))
	-- (ROBLOX-118) the meadow path out of the garden's north edge
	seam("garden_d2", "path_m1", v(-88, GT, -416), v(-32, GT, -416))
	seam("path_m1", "path_m2", v(-88, GT, -516), v(-32, GT, -516))
	seam("path_m2", "path_m3", v(-88, GT, -616), v(-32, GT, -616))
	seam("path_m3", "path_m4", v(-88, GT, -716), v(-32, GT, -716))
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
	-- (ROBLOX-118) the ceiling, the back room and the outside to the eaves
	local CE, DW, D = Hut.CEIL, Hut.DOORWAY, Hut.DOOR
	seam("hut_door", "hut_door_up", v(-44, D.top, D.leaf[1]), v(44, D.top, D.leaf[1]))
	seam("hut_floor_i", "hut_doorway", v(DW.x0, FL, DW.z0 + 2), v(DW.x0, FL, DW.z1 - 2))
	seam("hut_doorway", "room_floor_g", v(DW.x1, FL, DW.z0 + 2), v(DW.x1, FL, DW.z1 - 2))
	-- the upper cells: to one another flat on the ceiling's underside, and each to what is under it along a wall at WALL_TOP
	for _, room in { "hut", "back" } do
		local cols = if room == "hut" then Hut.COLS else Hut.BACK_COLS
		local pre = if room == "hut" then "hut_up_" else "room_up_"
		for r = 1, 3 do
			for c = 1, 3 do
				local x0, x1, z0, z1 = cols[c], cols[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
				local here = pre .. FLOOR_IDS[(r - 1) * 3 + c]
				if c < 3 then seam(here, pre .. FLOOR_IDS[(r - 1) * 3 + c + 1], v(x1, CE, z0 + 4), v(x1, CE, z1 - 4)) end
				if r < 3 then seam(here, pre .. FLOOR_IDS[r * 3 + c], v(x0 + 4, CE, z1), v(x1 - 4, CE, z1)) end
			end
		end
	end
	local T = Hut.WALL_TOP
	seam("hut_up_a", "hut_floor_a", v(R.x0, T, 16.5), v(R.x0, T, 89.5))
	seam("hut_up_a", "hut_board", v(-142, T, R.z0), v(-53, T, R.z0))
	seam("hut_up_b", "hut_board", v(-46, T, R.z0), v(-33, T, R.z0))
	seam("hut_up_b", "hut_desk", v(33, T, R.z0), v(46, T, R.z0))
	seam("hut_up_b", "hut_window", v(-29, 113.5, R.z0), v(29, 113.5, R.z0))
	seam("hut_up_c", "hut_desk", v(53, T, R.z0), v(142, T, R.z0))
	seam("hut_up_c", "hut_floor_c", v(R.x1, T, 16.5), v(R.x1, T, 89.5))
	seam("hut_up_d", "hut_floor_d", v(R.x0, T, 97.5), v(R.x0, T, 170.5))
	seam("hut_up_f", "hut_floor_f", v(R.x1, T, 97.5), v(R.x1, T, 170.5))
	seam("hut_up_g", "hut_floor_g", v(R.x0, T, 178.5), v(R.x0, T, 251.5))
	seam("hut_up_i", "hut_floor_i", v(64, T, R.z1), v(142, T, R.z1))
	seam("hut_up_h", "hut_door_up", v(-44, CE, R.z1), v(44, CE, R.z1))
	seam("hut_up_g", "hut_door_up", v(-D.jamb, T + 4, R.z1), v(-D.jamb, DW.head - 4, R.z1))
	seam("hut_up_i", "hut_door_up", v(D.jamb, T + 4, R.z1), v(D.jamb, DW.head - 4, R.z1))
	seam("hut_up_i", "hut_doorway_up", v(DW.core[1], T + 4, DW.z0), v(DW.core[1], DW.head - 4, DW.z0))
	seam("room_up_g", "hut_doorway_up", v(DW.core[2], T + 4, DW.z0), v(DW.core[2], DW.head - 4, DW.z0))
	seam("hut_doorway", "hut_doorway_up", v(DW.core[1] + 0.5, T, DW.z0), v(DW.core[2] - 0.5, T, DW.z0))
	local B = Hut.BACK
	seam("room_up_a", "room_floor_a", v(B.x0, T, 16.5), v(B.x0, T, 89.5))
	seam("room_up_b", "room_floor_b", v(269, T, B.z0), v(351, T, B.z0))
	seam("room_up_c", "room_floor_c", v(B.x1, T, 16.5), v(B.x1, T, 89.5))
	seam("room_up_d", "room_floor_d", v(B.x0, T, 97.5), v(B.x0, T, 170.5))
	seam("room_up_f", "room_window", v(B.x1, Hut.ROOM_WINDOW.top, 120), v(B.x1, Hut.ROOM_WINDOW.top, 148))
	seam("room_up_g", "room_floor_g", v(179, T, B.z1), v(261, T, B.z1))
	seam("room_up_h", "room_floor_h", v(269, T, B.z1), v(351, T, B.z1))
	seam("room_up_i", "room_floor_i", v(B.x1, T, 178.5), v(B.x1, T, 251.5))
	-- the back room's floor cells to one another: on the boards, or on the rug where it lies across the line, clear of the television's unit
	local G = Hut.RUG
	local function floorLine(a: string, b: string, p: Vector3, q: Vector3)
		-- (a line along x or z on the floor: the part of it on the rug, if the rug covers some of it, else the boards short of the rug)
		local alongX = math.abs(q.X - p.X) > math.abs(q.Z - p.Z)
		local fixed = if alongX then p.Z else p.X
		local across = if alongX then fixed > G.z0 and fixed < G.z1 else fixed > G.x0 and fixed < G.x1
		local lo, hi = if alongX then p.X else p.Z, if alongX then q.X else q.Z
		local r0, r1 = if alongX then G.x0 else G.z0, if alongX then G.x1 else G.z1
		if across and math.min(hi, r1) > math.max(lo, r0) then
			local a0, a1 = math.max(lo, r0 + 4), math.min(hi, r1 - 4)
			if a1 - a0 >= 10 then
				seam(a, b, if alongX then v(a0, FL + G.top, fixed) else v(fixed, FL + G.top, a0), if alongX then v(a1, FL + G.top, fixed) else v(fixed, FL + G.top, a1))
				return
			end
			-- (the boards' longer part off the rug)
			if r0 - lo >= hi - r1 then hi = math.min(hi, r0 - 3) else lo = math.max(lo, r1 + 3) end
		end
		seam(a, b, if alongX then v(lo, FL, fixed) else v(fixed, FL, lo), if alongX then v(hi, FL, fixed) else v(fixed, FL, hi))
	end
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = Hut.BACK_COLS[c], Hut.BACK_COLS[c + 1], Hut.ROWS[r], Hut.ROWS[r + 1]
			local here = "room_floor_" .. FLOOR_IDS[(r - 1) * 3 + c]
			if c < 3 then
				local za, zb = z0 + 4, z1 - 4
				if r == 1 then za = Hut.TV.z1 + 3 end -- (clear of the television's unit)
				floorLine(here, "room_floor_" .. FLOOR_IDS[(r - 1) * 3 + c + 1], v(x1, FL, za), v(x1, FL, zb))
			end
			if r < 3 then floorLine(here, "room_floor_" .. FLOOR_IDS[r * 3 + c], v(x0 + 4, FL, z1), v(x1 - 4, FL, z1)) end
		end
	end
	local TV, GA, SO = Hut.TV, Hut.GAMES, Hut.SOFA
	seam("room_tv", "room_floor_a", v(TV.x0 + 4, FL, TV.z1), v(261, FL, TV.z1))
	seam("room_tv", "room_floor_b", v(267, FL, TV.z1), v(TV.x1 - 2, FL, TV.z1))
	seam("room_games", "room_floor_c", v(GA.x0 + 4, FL, GA.z1), v(GA.x1 - 4, FL, GA.z1))
	seam("room_window", "room_floor_f", v(B.x1, -3, Hut.ROOM_WINDOW.z0 + 1), v(B.x1, -3, Hut.ROOM_WINDOW.z1 - 1))
	seam("room_sofa_w", "room_floor_d", v(SO.x0 + 3.5, FL, SO.z0 + 2.5), v(SO.x0 + 8.5, FL, SO.z0 + 2.5))
	seam("room_sofa_w", "room_floor_g", v(SO.x0 + 3.5, FL, SO.z1 - 8), v(SO.x0 + 8.5, FL, SO.z1 - 8))
	seam("room_sofa_e", "room_floor_f", v(SO.x1 - 8.5, FL, SO.z0 + 2.5), v(SO.x1 - 3.5, FL, SO.z0 + 2.5))
	seam("room_sofa_e", "room_floor_i", v(SO.x1 - 8.5, FL, SO.z1 - 8), v(SO.x1 - 3.5, FL, SO.z1 - 8))
	seam("room_sofa_w", "room_sofa_e", v(SO.split, SO.leg + 1, SO.z0), v(SO.split, SO.frame - 1, SO.z0))
	-- outside: the logs at OUT_TOP to the eaves' logs, the back room's north logs to the hut's, and the eaves to one another along the soffit's underside
	local OT, EV = Hut.OUT_TOP, Hut.EAVE
	seam("hut_wall_w", "hut_eave_w2", v(-160, OT, -16), v(-108, OT, -16))
	seam("hut_wall_w", "hut_eave_w1", v(-98, OT, -16), v(-40, OT, -16))
	seam("hut_wall_e", "hut_eave_e1", v(40, OT, -16), v(98, OT, -16))
	seam("hut_wall_e", "hut_eave_e2", v(108, OT, -16), v(170, OT, -16))
	seam("hut_wall_x1", "hut_eave_x1", v(180, OT, -16), v(245, OT, -16))
	seam("hut_wall_x2", "hut_eave_x2", v(280, OT, -16), v(320, OT, -16))
	seam("hut_wall_x2", "hut_eave_x3", v(330, OT, -16), v(370, OT, -16))
	seam("hut_wall_x3", "hut_eave_x4", v(405, OT, -16), v(460, OT, -16))
	seam("hut_wall_e", "hut_wall_x1", v(175, -50, -16), v(175, OT - 10, -16))
	seam("hut_wall_x1", "hut_wall_x2", v(275, -50, -16), v(275, OT - 10, -16))
	seam("hut_wall_x2", "hut_wall_x3", v(375, -50, -16), v(375, OT - 10, -16))
	for k = 1, #EAVES - 1 do
		local x = EAVES[k].ex1
		seam(EAVES[k].id, EAVES[k + 1].id, v(x, EV.soffit, EV.out + 2), v(x, EV.soffit, -18))
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
		-- (ROBLOX-118: the doorway to the back room is cut through the east wall at z 180..250)
		local DW = Hut.DOORWAY
		local runs: { { number } } = if z0 < DW.z0 and z1 > DW.z1 then { { z0, DW.z0 }, { DW.z1, z1 } } else { { z0, z1 } }
		local s0, s1 = if north then z0 + sk else z0, if south then z1 - sk else z1
		for k, run in runs do
			local tag = if #runs > 1 then tostring(k) else ""
			P(out, id .. "_wall_e" .. tag, R.x1, R.x1 + W, FL, top, run[1], run[2], "painted_wood_dry", C.lining, "WoodPlanks")
			local a, b = math.max(run[1], s0), math.min(run[2], s1)
			if b - a >= 10 then P(out, id .. "_skirting_e" .. tag, R.x1 - sk, R.x1, FL, st, a, b, "painted_wood_dry", C.skirting, "Wood") end
		end
	end
	if north then
		P(out, id .. "_skirting_n", x0, x1, FL, st, R.z0, R.z0 + sk, "painted_wood_dry", C.skirting, "Wood")
		if x0 < 0 and x1 > 0 then
			-- the apron: the sill's front face goes on down to the floor
			P(out, id .. "_apron", -31, 31, FL, -1, Hut.WALL_SPLIT, R.z0, "painted_wood_dry", C.lining, "WoodPlanks")
		end
	end
	if id == "hut_floor_i" then
		local K = Hut.CADDY
		P(out, id .. "_caddy", K.x0, K.x1, FL, FL + K.h, K.z0, K.z1, "painted_metal_smooth", "4f7d4a", "SmoothPlastic")
		P(out, id .. "_caddy_lid", K.x0 - 0.5, K.x1 + 0.5, FL + K.h, FL + K.h + K.lid, K.z0 - 0.5, K.z1 + 0.5, "painted_metal_smooth", "3f6a3c", "SmoothPlastic")
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
	if region.id == "hut_wall_e" then
		-- (ROBLOX-118: in two along the wall, so what meets the back room's logs at x 175 is near the seam)
		for k, span in { { 31, 103 }, { 103, 175 } } do
			local a = if k == 1 then 37 else 103
			box(`{region.id}_logs_low{k}`, span[1], span[2], FL, -4, z0, z1, "bare_wood_rough", C.log, "Wood")
			box(`{region.id}_logs_side{k}`, a, span[2], -4, 0, z0, z1, "bare_wood_rough", C.log, "Wood")
			box(`{region.id}_logs_high{k}`, span[1], span[2], 0, top, z0, z1, "bare_wood_rough", C.log, "Wood")
		end
		return out
	end
	box(region.id .. "_logs_low", 31, 175, FL, -4, z0, z1, "bare_wood_rough", C.log, "Wood")
	box(region.id .. "_logs_side", 37, 175, -4, 0, z0, z1, "bare_wood_rough", C.log, "Wood")
	box(region.id .. "_logs_high", 31, 175, 0, top, z0, z1, "bare_wood_rough", C.log, "Wood")
	-- (the corner's log ends, proud of the face; ROBLOX-118: the east end's are the back room's now, Hut.BUILDING.x1)
	if region.id == "hut_wall_w" then box(region.id .. "_corner", 166, 184, FL, top, -25, -16, "bare_wood_rough", C.logDark, "Wood") end
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
		head = { w = 3, h = 16, d = 3 }, color = "6f7f45", leaf = C.goldenLeaf, flower = C.goldenrod },
}
Hut.PLANT_SPECS = PLANT_SPECS

-- (ROBLOX-117: a second plant of a kind in a cell is `tag` "2" and may stand `scale` of the first's height; its ids `<cell>_<kind>2_...`)
local function plantPieces(out: { Piece }, id: string, plant: { kind: string, x: number, z: number, scale: number? }, y0: number, tag: string?)
	local spec = PLANT_SPECS[plant.kind]
	local half = spec.stem / 2
	local k = plant.scale or 1
	local sx0, sx1, sz0, sz1 = plant.x - half, plant.x + half, plant.z - half, plant.z + half
	local base = `{id}_{plant.kind}{tag or ""}`
	P(out, base .. "_stem", sx0, sx1, y0, y0 + spec.height * k, sz0, sz1, "leaf_dry_prototype", spec.color)
	for i, leaf in spec.leaves :: { Leaf } do
		local ya, yb = y0 + leaf.h * k, y0 + leaf.h * k + spec.thick
		local w = leaf.w / 2
		if leaf.dir == "x+" then P(out, `{base}_leaf_{i}`, sx1, sx1 + leaf.l, ya, yb, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		elseif leaf.dir == "x-" then P(out, `{base}_leaf_{i}`, sx0 - leaf.l, sx0, ya, yb, plant.z - w, plant.z + w, "leaf_dry_prototype", spec.leaf)
		elseif leaf.dir == "z+" then P(out, `{base}_leaf_{i}`, plant.x - w, plant.x + w, ya, yb, sz1, sz1 + leaf.l, "leaf_dry_prototype", spec.leaf)
		else P(out, `{base}_leaf_{i}`, plant.x - w, plant.x + w, ya, yb, sz0 - leaf.l, sz0, "leaf_dry_prototype", spec.leaf) end
	end
	local top = y0 + spec.height * k
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
	if spec.pod ~= nil and tag == nil then
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
	local more = MORE_PLANTS[id]
	if more ~= nil then plantPieces(out, id, more, S, "2") end
	local herbs = HERBS[id]
	if herbs ~= nil then for _, h in herbs do herbPieces(out, id, h.kind, h.x, h.z, S) end end
	return out
end

-- (ROBLOX-117) A length of the path round the east end: its gravel, one box (the stones are the patches' look).
local function pathPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local lo, hi = region.bounds[1], region.bounds[2]
	P(out, region.id .. "_gravel", lo.X, hi.X, -87, GT, lo.Z, hi.Z, "brick_rough", C.gravel, "Pebble")
	return out
end

-- ---------------------------------------------------------------- (ROBLOX-118) the ceiling, the back room and the outside to the eaves
local LINING_W = 10 -- a lining's box depth into its wall (the hut's floor cells' W)
-- An upper cell: the ceiling's boards over it, the joists under them, and the walls' linings from WALL_TOP to the ceiling on its sides (cut round the window's head,
-- the door's head and the doorway).
local function upperPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local U = UPPER[region.id]
	local id = region.id
	local hut = U.room == "hut"
	local Rm = if hut then Hut.ROOM else Hut.BACK
	local T, CE, W = Hut.WALL_TOP, Hut.CEIL, LINING_W
	local DW = Hut.DOORWAY
	P(out, id .. "_ceiling", U.x0, U.x1, CE, CE + 2, U.z0, U.z1, "painted_wood_dry", C.ceiling, "WoodPlanks")
	local J = Hut.JOISTS
	for k, x in (if hut then J.hut else J.back) :: { number } do
		if x - J.w / 2 > U.x0 and x + J.w / 2 < U.x1 then P(out, `{id}_joist_{k}`, x - J.w / 2, x + J.w / 2, CE - J.d, CE, U.z0, U.z1, "bare_wood_rough", C.joist, "Wood") end
	end
	-- a wall's lining from T to the ceiling along z (x a..b) with the doorway's opening cut out of it where it is
	local function alongZ(tag: string, a: number, b: number, cut: boolean, y0: number?)
		if cut then
			if DW.z0 > U.z0 then P(out, `{id}_{tag}1`, a, b, T, CE, U.z0, DW.z0, "painted_wood_dry", C.lining, "WoodPlanks") end
			if DW.z1 < U.z1 then P(out, `{id}_{tag}2`, a, b, T, CE, DW.z1, U.z1, "painted_wood_dry", C.lining, "WoodPlanks") end
		else
			P(out, `{id}_{tag}`, a, b, y0 or T, CE, U.z0, U.z1, "painted_wood_dry", C.lining, "WoodPlanks")
		end
	end
	if U.x0 == Rm.x0 then alongZ("wall_w", Rm.x0 - W, Rm.x0, not hut and U.z0 < DW.z0 and U.z1 > DW.z1) end
	if U.x1 == Rm.x1 then
		local window = not hut and U.z0 <= Hut.ROOM_WINDOW.z0 and U.z1 >= Hut.ROOM_WINDOW.z1
		alongZ("wall_e", Rm.x1, Rm.x1 + W, hut and U.z0 < DW.z0 and U.z1 > DW.z1, if window then Hut.ROOM_WINDOW.top else nil)
	end
	if U.z0 == Rm.z0 then
		local z0 = if hut then Hut.WALL_SPLIT else Rm.z0 - W
		if hut then
			-- (beside the window to the ceiling, and over its head)
			if U.x0 < -31 then P(out, id .. "_wall_n", U.x0, math.min(U.x1, -31), T, CE, z0, Rm.z0, "painted_wood_dry", C.lining, "WoodPlanks") end
			if U.x1 > 31 then P(out, id .. "_wall_n2", math.max(U.x0, 31), U.x1, T, CE, z0, Rm.z0, "painted_wood_dry", C.lining, "WoodPlanks") end
			local a, b = math.max(U.x0, -31), math.min(U.x1, 31)
			if b > a then P(out, id .. "_over_window", a, b, 113.5, CE, z0, Rm.z0, "painted_wood_dry", C.lining, "WoodPlanks") end
		else
			P(out, id .. "_wall_n", U.x0, U.x1, T, CE, z0, Rm.z0, "painted_wood_dry", C.lining, "WoodPlanks")
		end
	end
	if U.z1 == Rm.z1 then
		local D = Hut.DOOR
		local runs = { { U.x0, U.x1 } }
		if hut then
			runs = {}
			if U.x0 < -D.jamb then table.insert(runs, { U.x0, math.min(U.x1, -D.jamb) }) end
			if U.x1 > D.jamb then table.insert(runs, { math.max(U.x0, D.jamb), U.x1 }) end
		end
		for k, run in runs do P(out, `{id}_wall_s{k}`, run[1], run[2], T, CE, Rm.z1, Rm.z1 + W, "painted_wood_dry", C.lining, "WoodPlanks") end
	end
	return out
end

-- The back room's floor in a cell: the boards, the linings to WALL_TOP and the skirting (the doorway cut out of the west wall's, the window's sill and reveals over
-- the east wall's in its row), the rug, the radiator under the window, the cables along the skirting and their sockets.
local function roomFloorPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local B, DW, T, W, sk = Hut.BACK, Hut.DOORWAY, Hut.WALL_TOP, LINING_W, 1.5
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0, x1, z0, z1 = lo.X, hi.X, lo.Z, hi.Z
	local st = FL + 10
	P(out, id .. "_boards", x0, x1, FL - 2, FL, z0, z1, "varnished_wood_smooth", C.floor, "WoodPlanks")
	local west, east, north, south = x0 == B.x0, x1 == B.x1, z0 == B.z0, z1 == B.z1
	local s0, s1 = if north then z0 + sk else z0, if south then z1 - sk else z1
	if west then
		local door = z0 < DW.z0 and z1 > DW.z1
		local runs: { { number } } = if door then { { z0, DW.z0 }, { DW.z1, z1 } } else { { z0, z1 } }
		for k, run in runs do
			P(out, `{id}_wall_w{k}`, B.x0 - W, B.x0, FL, T, run[1], run[2], "painted_wood_dry", C.lining, "WoodPlanks")
			local a, b = math.max(run[1], s0), math.min(run[2], s1)
			if b - a >= 10 then P(out, `{id}_skirting_w{k}`, B.x0, B.x0 + sk, FL, st, a, b, "painted_wood_dry", C.skirting, "Wood") end
		end
	end
	if east then
		local window = z0 <= Hut.ROOM_WINDOW.z0 and z1 >= Hut.ROOM_WINDOW.z1
		P(out, id .. "_wall_e", B.x1, B.x1 + W, FL, if window then -3 else T, z0, z1, "painted_wood_dry", C.lining, "WoodPlanks")
		P(out, id .. "_skirting_e", B.x1 - sk, B.x1, FL, st, s0, s1, "painted_wood_dry", C.skirting, "Wood")
	end
	if north then
		P(out, id .. "_wall_n", x0, x1, FL, T, B.z0 - W, B.z0, "painted_wood_dry", C.lining, "WoodPlanks")
		P(out, id .. "_skirting_n", x0, x1, FL, st, B.z0, B.z0 + sk, "painted_wood_dry", C.skirting, "Wood")
	end
	if south then
		P(out, id .. "_wall_s", x0, x1, FL, T, B.z1, B.z1 + W, "painted_wood_dry", C.lining, "WoodPlanks")
		local a, b = math.max(x0, B.x0 + sk), math.min(x1, B.x1 - sk)
		P(out, id .. "_skirting_s", a, b, FL, st, B.z1 - sk, B.z1, "painted_wood_dry", C.skirting, "Wood")
	end
	-- the rug, where it lies in this cell
	local G = Hut.RUG
	local a, b, c, d = clip(G.x0, G.x1, G.z0, G.z1, x0, x1, z0, z1)
	if a ~= nil then P(out, id .. "_rug", a, b :: number, FL, FL + G.top, c :: number, d :: number, "painted_wood_dry", C.rug, "Fabric") end
	if id == "room_floor_a" then
		-- the television's cable: from its unit along the floor to the skirting, along it, up to the socket on the west wall
		P(out, id .. "_socket", B.x0, B.x0 + 0.8, -55, -47, 56, 64, "painted_metal_smooth", "e8e4da", "SmoothPlastic")
		P(out, id .. "_plug", B.x0 + 0.8, B.x0 + 1.5, -53, -49, 58, 62, "painted_metal_smooth", "2a2724", "SmoothPlastic")
		P(out, id .. "_cable_up", B.x0 + 1.5, B.x0 + 2.1, FL, -53, 59.7, 60.3, "painted_metal_smooth", C.cable, "SmoothPlastic")
		P(out, id .. "_cable_run", B.x0 + 1.5, B.x0 + 2.1, FL, FL + 0.6, 30, 59.7, "painted_metal_smooth", C.cable, "SmoothPlastic")
		P(out, id .. "_cable_in", B.x0 + 2.1, Hut.TV.x0, FL, FL + 0.6, 30, 30.6, "painted_metal_smooth", C.cable, "SmoothPlastic")
	elseif id == "room_floor_f" then
		-- the oil-filled radiator under the window: its fins on a spine on two feet, its control box at the south end; its cord to the skirting
		local H = Hut.HEATER
		for k, z in { 106, 148 } do P(out, `{id}_heater_foot{k}`, H.x0 - 2, H.x1 + 2, FL, FL + 4, z, z + 2, "painted_metal_smooth", C.heaterDark, "Metal") end
		P(out, id .. "_heater_spine", 431, 435, FL + 4, FL + 8, 102, 155.4, "painted_metal_smooth", C.heater, "Metal")
		for k = 0, H.fins - 1 do
			local z = 102 + k * 8.5
			P(out, `{id}_heater_fin{k + 1}`, H.x0, H.x1, FL + 8, H.top, z, z + 2.4, "painted_metal_smooth", C.heater, "Metal")
		end
		P(out, id .. "_heater_box", 427, 439, -60, -12, 157, 163, "painted_metal_smooth", C.heater, "Metal")
		P(out, id .. "_heater_cord", 439, B.x1 - sk - 0.6, FL, FL + 0.6, 159.7, 160.3, "painted_metal_smooth", C.cable, "SmoothPlastic")
		P(out, id .. "_heater_cord2", B.x1 - sk - 0.6, B.x1 - sk, FL, FL + 0.6, 160.3, 169.7, "painted_metal_smooth", C.cable, "SmoothPlastic")
		P(out, id .. "_heater_cord_up", B.x1 - sk - 0.6, B.x1 - sk, FL, -53, 169.7, 170.3, "painted_metal_smooth", C.cable, "SmoothPlastic")
		P(out, id .. "_plug", B.x1 - sk, B.x1 - 0.8, -53, -49, 168, 172, "painted_metal_smooth", "2a2724", "SmoothPlastic")
		P(out, id .. "_socket", B.x1 - 0.8, B.x1, -55, -47, 166, 174, "painted_metal_smooth", "e8e4da", "SmoothPlastic")
	end
	return out
end

-- The doorway through the hut's old east logs: its threshold, the logs' cut ends either side (between the two rooms' linings) and its head to the ceiling.
local function doorwayPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local DW, B, T = Hut.DOORWAY, Hut.BACK, Hut.WALL_TOP
	local id = region.id
	if id == "hut_doorway" then
		P(out, id .. "_threshold", DW.x0, DW.x1, FL - 2, FL, DW.z0, DW.z1, "varnished_wood_smooth", C.boardDark, "Wood")
		P(out, id .. "_log_n", DW.core[1], DW.core[2], FL, T, Hut.ROWS[3], DW.z0, "bare_wood_rough", C.log, "Wood")
		P(out, id .. "_log_s", DW.core[1], DW.core[2], FL, T, DW.z1, B.z1, "bare_wood_rough", C.log, "Wood")
	else
		P(out, id .. "_log_n", DW.core[1], DW.core[2], T, Hut.CEIL, Hut.ROWS[3], DW.z0, "bare_wood_rough", C.log, "Wood")
		P(out, id .. "_log_s", DW.core[1], DW.core[2], T, Hut.CEIL, DW.z1, B.z1, "bare_wood_rough", C.log, "Wood")
		P(out, id .. "_head", DW.x0, DW.x1, DW.head, Hut.CEIL, DW.z0, DW.z1, "painted_wood_dry", C.lining, "WoodPlanks")
	end
	return out
end

-- The front door above the height its region below keeps (Hut.DOOR.top): its leaf, its jambs to its head, and the wall over it to the ceiling.
local function doorUpPieces(): { Piece }
	local out: { Piece } = {}
	local D, R = Hut.DOOR, Hut.ROOM
	local head = Hut.DOORWAY.head
	P(out, "hut_door_up_leaf", -D.x, D.x, D.top, head, D.leaf[1], D.leaf[2], "painted_wood_dry", C.trim, "WoodPlanks")
	P(out, "hut_door_up_jamb_w", -D.jamb, -D.x, D.top, head, R.z1, D.outer, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_door_up_jamb_e", D.x, D.jamb, D.top, head, R.z1, D.outer, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "hut_door_up_head", -D.jamb, D.jamb, head, Hut.CEIL, R.z1, D.outer, "painted_wood_dry", C.lining, "WoodPlanks")
	return out
end

-- The sofa, a half of it (`west`): its legs, its frame, its arm, its seat cushion, its back and the back's cushion; on the west half's cushion, the controller.
local function sofaPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local S0 = Hut.SOFA
	local west = region.id == "room_sofa_w"
	local id = region.id
	local xa, xb = if west then S0.x0 else S0.split, if west then S0.split else S0.x1
	local lx = if west then S0.x0 + 3 else S0.x1 - 9
	for k, z in { S0.z0 + 2.5, S0.z1 - 8 } do P(out, `{id}_leg{k}`, lx, lx + 6, FL, S0.leg, z, z + 6, "varnished_wood_smooth", C.chair, "Wood") end
	P(out, id .. "_frame", xa, xb, S0.leg, S0.frame, S0.z0, S0.z1, "painted_wood_dry", C.sofaDark, "Fabric")
	local ax0, ax1 = if west then S0.x0 else S0.x1 - S0.arm, if west then S0.x0 + S0.arm else S0.x1
	P(out, id .. "_arm", ax0, ax1, S0.frame, S0.armTop, S0.z0, S0.z1, "painted_wood_dry", C.sofa, "Fabric")
	local ia, ib = if west then S0.x0 + S0.arm else S0.split, if west then S0.split else S0.x1 - S0.arm
	P(out, id .. "_cushion", if west then ia else ia + 0.5, if west then ib - 0.5 else ib, S0.frame, S0.seat, S0.z0 + 2.5, 236, "painted_wood_dry", C.sofa, "Fabric")
	P(out, id .. "_back", ia, ib, S0.frame, S0.back, 236, S0.z1, "painted_wood_dry", C.sofaDark, "Fabric")
	P(out, id .. "_back_cushion", if west then ia + 2 else ia + 0.5, if west then ib - 0.5 else ib - 2, S0.seat, S0.back - 5, 228, 236, "painted_wood_dry", C.sofa, "Fabric")
	if west then P(out, id .. "_controller", 280, 295, S0.seat, S0.seat + 4, 196, 206, "painted_metal_smooth", C.controller, "SmoothPlastic") end
	return out
end

-- The low unit against the north wall with the television on its stand on it, and the games console on the unit's lower shelf.
local function tvPieces(): { Piece }
	local out: { Piece } = {}
	local V = Hut.TV
	local Sc = V.screen
	P(out, "room_tv_base", V.x0, V.x1, FL, -66, V.z0, V.z1, "varnished_wood_smooth", C.unitDark, "Wood")
	P(out, "room_tv_side_w", V.x0, V.x0 + 2, -66, V.top - 2, V.z0, V.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_tv_side_e", V.x1 - 2, V.x1, -66, V.top - 2, V.z0, V.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_tv_back", V.x0 + 2, V.x1 - 2, -66, V.top - 2, V.z0, V.z0 + 1.5, "varnished_wood_smooth", C.unitDark, "Wood")
	P(out, "room_tv_shelf", V.x0 + 2, V.x1 - 2, -46, -44, V.z0 + 1.5, V.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_tv_top", V.x0, V.x1, V.top - 2, V.top, V.z0, V.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_tv_console", 195, 225, -66, -60, 22, 47, "painted_metal_smooth", C.console, "SmoothPlastic")
	P(out, "room_tv_foot", 215, 245, V.top, V.top + 1, 22, 36, "painted_metal_smooth", C.screen, "Metal")
	P(out, "room_tv_neck", 228, 232, V.top + 1, Sc.y0, 26, 29, "painted_metal_smooth", C.screen, "Metal")
	P(out, "room_tv_screen", Sc.x0, Sc.x1, Sc.y0, Sc.y1, Sc.z0, Sc.z1, "painted_metal_smooth", C.screen, "SmoothPlastic")
	return out
end

-- The shelf of board games in the north-east corner: its carcass and two shelves, and the games lying in piles on each, from the shelf's own stream.
local function gamesPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local G = Hut.GAMES
	P(out, "room_games_side_w", G.x0, G.x0 + 2, FL, G.top - 2, G.z0, G.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_games_side_e", G.x1 - 2, G.x1, FL, G.top - 2, G.z0, G.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_games_back", G.x0 + 2, G.x1 - 2, FL, G.top - 2, G.z0, G.z0 + 1, "varnished_wood_smooth", C.unitDark, "Wood")
	P(out, "room_games_top", G.x0, G.x1, G.top - 2, G.top, G.z0, G.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_games_bottom", G.x0 + 2, G.x1 - 2, FL, -66, G.z0 + 1, G.z1, "varnished_wood_smooth", C.unitDark, "Wood")
	local shelves = { { y = -66, top = -30 }, { y = -28, top = 8 }, { y = 10, top = G.top - 2 } }
	P(out, "room_games_shelf_1", G.x0 + 2, G.x1 - 2, -30, -28, G.z0 + 1, G.z1, "varnished_wood_smooth", C.unit, "Wood")
	P(out, "room_games_shelf_2", G.x0 + 2, G.x1 - 2, 8, 10, G.z0 + 1, G.z1, "varnished_wood_smooth", C.unit, "Wood")
	local rand = rng(region.seed, 7)
	for s, shelf in shelves do
		for pile, px in { G.x0 + 4, G.x0 + 42 } do
			local y = shelf.y
			local w, dz = between(rand, 26, 30), between(rand, 25, 28)
			for k = 1, 4 do
				local h = between(rand, 4, 8)
				if y + h > shelf.top - 3 then break end
				local ww, dd = w - between(rand, 0, 4), dz - between(rand, 0, 3)
				P(out, `room_games_box_{s}_{pile}_{k}`, px, px + ww, y, y + h, G.z1 - 1 - dd, G.z1 - 1, "painted_wood_dry", pick(C.games, rand), "SmoothPlastic")
				y += h
				w, dz = ww, dd
			end
		end
	end
	P(out, "room_games_cards", G.x0 + 30, G.x0 + 39, G.top, G.top + 2.2, G.z0 + 12, G.z0 + 18.5, "painted_wood_dry", "b8322a", "SmoothPlastic")
	return out
end

-- The back room's window in its east wall: its sill board (30 cm deep, wide enough for a cat), the reveals either side, the glass and the head.
local function roomWindowPieces(): { Piece }
	local out: { Piece } = {}
	local Wn, B = Hut.ROOM_WINDOW, Hut.BACK
	P(out, "room_window_sill", Wn.sill, Wn.glass, -3, 0, Wn.z0, Wn.z1, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "room_window_reveal_s", B.x1, Wn.glass, -3, Wn.top, 93.5, Wn.z0, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "room_window_reveal_n", B.x1, Wn.glass, -3, Wn.top, Wn.z1, 174.5, "painted_wood_dry", C.lining, "WoodPlanks")
	P(out, "room_window_glass", Wn.glass, Wn.glass + 1, 0, Wn.head, Wn.z0, Wn.z1, "glass_clean", "c9d6d8", "Glass")
	P(out, "room_window_head", B.x1, Wn.glass, Wn.head, Wn.top, Wn.z0, Wn.z1, "painted_wood_dry", C.lining, "WoodPlanks")
	return out
end

-- The north face outside from OUT_TOP (or the window's head) to the soffit, its corners' log ends, the window's casing, and the eaves: the boxed soffit, the fascia,
-- the gutter's floor and lip, an end cap at each end of the run.
local function eavePieces(region: Region): { Piece }
	local out: { Piece } = {}
	local e: { id: string, x0: number, x1: number, ex0: number, ex1: number }? = nil
	for _, x in EAVES do if x.id == region.id then e = x end end
	local E = e :: any
	local id = region.id
	local EV, OT, z1 = Hut.EAVE, Hut.OUT_TOP, Hut.WALL_SPLIT
	local Gu = EV.gutter
	if id == "hut_eave_mid" then
		P(out, id .. "_logs", E.x0, E.x1, 113.5, EV.soffit, -16, z1, "bare_wood_rough", C.log, "Wood")
		P(out, id .. "_casing", -37, 37, 112.5, 118.5, -17.2, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	else
		P(out, id .. "_logs", E.x0, E.x1, OT, EV.soffit, -16, z1, "bare_wood_rough", C.log, "Wood")
	end
	if id == "hut_eave_w1" then
		P(out, id .. "_casing", -37, -31, OT, 112.5, -17.2, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	elseif id == "hut_eave_w2" then
		P(out, id .. "_corner", -184, -166, OT, EV.soffit, -25, -16, "bare_wood_rough", C.logDark, "Wood")
	elseif id == "hut_eave_e1" then
		P(out, id .. "_casing", 31, 37, OT, 112.5, -17.2, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	elseif id == "hut_eave_x4" then
		P(out, id .. "_corner", Hut.BUILDING.x1 - 9, Hut.BUILDING.x1 + 9, OT, EV.soffit, -25, -16, "bare_wood_rough", C.logDark, "Wood")
	end
	P(out, id .. "_soffit", E.ex0, E.ex1, EV.soffit, EV.soffitTop, EV.out, -16, "painted_wood_dry", C.trim, "WoodPlanks")
	P(out, id .. "_fascia", E.ex0, E.ex1, Gu.floor, EV.soffitTop, EV.fascia.out, EV.out, "painted_wood_dry", C.trim, "WoodPlanks")
	P(out, id .. "_gutter", E.ex0, E.ex1, Gu.floor, Gu.floor + Gu.thick, Gu.out, EV.fascia.out, "painted_metal_smooth", C.gutter, "Metal")
	P(out, id .. "_gutter_lip", E.ex0, E.ex1, Gu.floor, Gu.lip, Gu.out - Gu.wall, Gu.out, "painted_metal_smooth", C.gutter, "Metal")
	if E.ex0 == EV.x0 then P(out, id .. "_gutter_cap", EV.x0 - Gu.cap, EV.x0, Gu.floor, Gu.lip, Gu.out - Gu.wall, EV.fascia.out, "painted_metal_smooth", C.gutter, "Metal") end
	if E.ex1 == EV.x1 then P(out, id .. "_gutter_cap", EV.x1, EV.x1 + Gu.cap, Gu.floor, Gu.lip, Gu.out - Gu.wall, EV.fascia.out, "painted_metal_smooth", C.gutter, "Metal") end
	return out
end

-- The back room's north logs outside (west and east of x 325) to OUT_TOP, the base's lip at their foot, and the room's north-east corner's log ends.
local function wallXPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0 = lo.X
	local x1 = math.min(hi.X, Hut.BUILDING.x1)
	P(out, region.id .. "_logs", x0, x1, FL, Hut.OUT_TOP, -16, Hut.WALL_SPLIT, "bare_wood_rough", C.log, "Wood")
	P(out, region.id .. "_base", math.max(x0, 178), if region.id == "hut_wall_x3" then x1 + 3 else x1, GT, FL, -19, -16, "brick_rough", C.concrete, "Concrete")
	if region.id == "hut_wall_x3" then
		P(out, region.id .. "_corner", Hut.BUILDING.x1 - 9, Hut.BUILDING.x1 + 9, FL, Hut.OUT_TOP, -25, -16, "bare_wood_rough", C.logDark, "Wood")
	end
	return out
end

local KINDS: { [string]: boolean } = {
	hut_window = true, hut_outer_sill = true, hut_floor = true, hut_desk = true, hut_board = true, hut_shelf = true, hut_chair = true, hut_door = true,
	hut_wall = true, hut_bench = true, hut_butt = true, garden_pole = true, garden_bed = true, hut_path = true,
	-- (ROBLOX-118)
	hut_upper = true, hut_doorway = true, hut_door_up = true, hut_eave = true, room_floor = true, room_sofa = true, room_tv = true, room_games = true, room_window = true,
}
-- Whether a kind is the hut's (or its garden's).
function Hut.knows(kind: string): boolean
	return KINDS[kind] == true
end
-- The kinds inside the hut (Life/Nature: the night's ground hunters never come in; the hut keeps the sill's day).
Hut.INDOORS = table.freeze({ hut_window = true, hut_floor = true, hut_desk = true, hut_board = true, hut_shelf = true, hut_chair = true,
	-- (ROBLOX-118) the ceiling and the upper walls, the doorway, the front door's head, and the volunteers' back room
	hut_upper = true, hut_doorway = true, hut_door_up = true, room_floor = true, room_sofa = true, room_tv = true, room_games = true, room_window = true })

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
	elseif k == "hut_wall" then out = if string.sub(region.id, 1, 10) == "hut_wall_x" then wallXPieces(region) else wallPieces(region)
	elseif k == "hut_bench" then out = benchPieces()
	elseif k == "hut_butt" then out = buttPieces()
	elseif k == "garden_pole" then out = polePieces(region)
	elseif k == "garden_bed" then out = gardenPieces(region)
	elseif k == "hut_path" then out = pathPieces(region)
	elseif k == "hut_upper" then out = upperPieces(region)
	elseif k == "room_floor" then out = roomFloorPieces(region)
	elseif k == "hut_doorway" then out = doorwayPieces(region)
	elseif k == "hut_door_up" then out = doorUpPieces()
	elseif k == "room_sofa" then out = sofaPieces(region)
	elseif k == "room_tv" then out = tvPieces()
	elseif k == "room_games" then out = gamesPieces(region)
	elseif k == "room_window" then out = roomWindowPieces()
	elseif k == "hut_eave" then out = eavePieces(region)
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
	hut_floor = { full = 15, low = 2 }, hut_desk = { full = 22, low = 1 }, hut_board = { full = 16, low = 4 }, hut_shelf = { full = 10, low = 0 }, hut_chair = { full = 2, low = 0 },
	hut_door = { full = 14, low = 1 }, hut_window = { full = 0, low = 0 }, hut_outer_sill = { full = 6, low = 0 }, hut_wall = { full = 0, low = 0 },
	hut_bench = { full = 4, low = 0 }, hut_butt = { full = 3, low = 0 }, garden_pole = { full = 4, low = 2 }, garden_bed = { full = 124, low = 8 },
	-- (ROBLOX-117: the path round the east end, and the patches: the near detail of the garden's cells and the path's lengths, World/LookPlan.PATCH_RADIUS)
	hut_path = { full = 8, low = 2 }, patch = { full = 90, low = 10 },
	-- (ROBLOX-118: the ceiling and the upper walls, the doorway, the front door's head, the eaves, and the back room)
	hut_upper = { full = 26, low = 0 }, hut_doorway = { full = 0, low = 0 }, hut_door_up = { full = 0, low = 0 }, hut_eave = { full = 4, low = 0 },
	room_floor = { full = 12, low = 1 }, room_sofa = { full = 8, low = 0 }, room_tv = { full = 4, low = 1 }, room_games = { full = 20, low = 0 }, room_window = { full = 4, low = 0 },
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
	if region.id == "hut_floor_g" then
		-- (ROBLOX-118) the cat's bowls by the door: its biscuits and its water
		add(rec("FoodBowl", v(4, 13, 13), v(-98, FL + 2, 232), "b8bcc0", "Metal", true, "Cylinder", v(0, 0, 90)))
		add(rec("Biscuits", v(0.6, 10, 10), v(-98, FL + 3.8, 232), "8a5a2e", "Sand", true, "Cylinder", v(0, 0, 90)))
		add(rec("WaterBowl", v(4, 14, 14), v(-76, FL + 2, 238), "b8bcc0", "Metal", true, "Cylinder", v(0, 0, 90)))
		add(rec("Water", v(0.3, 11.5, 11.5), v(-76, FL + 3.7, 238), "9fb6bd", "Glass", true, "Cylinder", v(0, 0, 90)))
	end
	if region.id == "hut_floor_i" then
		-- (ROBLOX-117) the caddy's handle and the banana peel over its rim
		local K = Hut.CADDY
		local top = FL + K.h + K.lid
		add(rec("CaddyHandle", v(16, 0.8, 0.8), v((K.x0 + K.x1) / 2, top + 0.4, (K.z0 + K.z1) / 2), "2f4f2c", "SmoothPlastic", false))
		add(rec("Peel", v(9, 0.8, 3.2), v(K.x0 + 4, top + 0.3, K.z0 + 2), "c9a83a", "SmoothPlastic", false, "Ellipsoid", v(0, 30, -8)))
		add(rec("PeelEnd", v(4, 0.8, 2.6), v(K.x0 + 0.4, top - 1.3, K.z0 + 0.6), "a07a2a", "SmoothPlastic", true, "Ellipsoid", v(0, 30, -70)))
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

-- A region's pieces by id.
local function piecesById(region: Region): { [string]: Piece }
	local out: { [string]: Piece } = {}
	for _, p in Hut.pieces(region) do out[p.id] = p end
	return out
end

-- ---------------------------------------------------------------- the garden's look (ROBLOX-117: rich at the spider's eye)
-- A cell's own look is what reads from a metre or two off and what stands in for the plants' boxes' shapes: the surfaces (the path's gravel, the drip strip, the
-- seed under the feeder), the herbs' mounds, the plants drawn whole over their walkable boxes (World/Hut.PLANTS and MORE_PLANTS: the milkweed's broad leaves with
-- their pale midribs, its umbels of florets and a second umbel on a peduncle, its pod; the coneflower's drooping rays and spiky cone; the bee balm's whorled head
-- of tubes over its bracts; the goldenrod's arching plume of one-sided sprays; every leaf a blade over its box), the lawn's clumps and the dew on the leaves. What
-- the spider sees close (the blades, the chips, the stones) is the patches' (below), drawn only near it.

-- A dew drop on a surface at `at` (its top): a flat glass bead in the "Dew" group, shown by the hour (Habitat/DayLight.applyDew: it appears from `dew`, its lag,
-- to its `transparency` at full dew). Full tier only.
local function drop(id: string, at: Vector3, size: number, rand: () -> number): Drawn
	local d = rec(id, v(size, size * 0.62, size), at + v(0, size * 0.25, 0), "dfeaee", "Glass", true, "Ellipsoid")
	d.group = "Dew"
	d.dew = rand() * 0.6
	d.transparency = between(rand, 0.3, 0.45)
	d.reflectance = 0.3
	return d
end

-- A leaf box's middle, its length along its long axis, its width, and which axis is long.
local function leafShape(box: Piece): (Vector3, number, number, string)
	local size = box.hi - box.lo
	local c = (box.lo + box.hi) * 0.5
	if size.X >= size.Z then return c, size.X, size.Z, "x" end
	return c, size.Z, size.X, "z"
end
-- A size along a leaf's long axis `ax`: `l` along it, `w` across, `t` thick.
local function along(ax: string, l: number, t: number, w: number): Vector3
	return if ax == "x" then v(l, t, w) else v(w, t, l)
end
-- The yaw (degrees) that turns a record's +X onto (dx, dz) in plan.
local function yawTo(dx: number, dz: number): number
	return math.deg(math.atan2(-dz, dx))
end

-- A plant's drawn form over its walkable boxes (`tag` "" for a cell's first plant, "2" for its second).
local function plantDecor(region: Region, plant: { kind: string, x: number, z: number, scale: number? }, tag: string, add: (Drawn) -> boolean, rand: () -> number)
	local spec = PLANT_SPECS[plant.kind]
	local k = plant.scale or 1
	local byId = piecesById(region)
	local base = `{region.id}_{plant.kind}{tag}`
	local top = S + spec.height * k
	local kind = plant.kind
	-- the leaves: each a blade over its box (a little longer and wider, so the box's corners hardly show), the milkweed's with its pale midrib
	local leafColor = if kind == "milkweed" then C.milkweedLeaf elseif kind == "goldenrod" then C.goldenLeaf else C.leaf
	local tones = { leafColor, C.leafPale, leafColor }
	for i = 1, #spec.leaves do
		local box = byId[`{base}_leaf_{i}`]
		if box ~= nil then
			local c, l, w, ax = leafShape(box)
			local wide = if kind == "goldenrod" then 1.7 elseif kind == "beebalm" then 1.5 else 1.3
			add(rec(`Leaf{tag}_{i}`, along(ax, l * 1.22, 0.5, w * wide), c + v(0, 0.05, 0), if i % 3 == 0 then tones[2] else leafColor, "SmoothPlastic", true, "Ellipsoid"))
			if kind == "milkweed" then add(rec(`Midrib{tag}_{i}`, along(ax, l * 1.05, 0.08, 0.32), c + v(0, 0.27, 0), C.milkweedUnder, "SmoothPlastic", true)) end
			if tag == "" and i <= 3 then add(drop(`LeafDew{i}`, c + v(between(rand, -1.5, 1.5), box.hi.Y - c.Y, between(rand, -1.5, 1.5)), between(rand, 0.35, 0.6), rand)) end
		end
	end
	local head = byId[base .. "_head"]
	if head == nil then return end
	local hc = (head.lo + head.hi) * 0.5
	if kind == "milkweed" then
		-- the umbel: florets over a dome (the golden angle spreads them), pink to mauve; and a second umbel on a peduncle from the third node
		local n = if tag == "" then 26 else 18
		for i = 1, n do
			local t = (i - 0.5) / n
			local el = math.asin(t) * 1.15 - 0.2 -- (from just under the dome's rim up to its crown: the umbel droops a little)
			local a = i * 2.39996
			local r = 4.2
			add(rec(`Floret{tag}_{i}`, v(1.6, 1.4, 1.6), hc + v(math.cos(a) * r * math.cos(el), 0.3 + r * 0.75 * math.sin(el) - 0.6, math.sin(a) * r * math.cos(el)),
				pick({ C.umbel, "d9a1ab", "b47a86", "c995a0" }, rand), "SmoothPlastic", true, "Ball"))
		end
		if tag == "" then
			local node = S + spec.leaves[5].h * k
			local from = v(plant.x + 0.6, node, plant.z)
			local to = from + v(7, 5, 2)
			local mid = (from + to) * 0.5
			local d = to - from
			add(rec("Peduncle", v(d.Magnitude, 0.35, 0.35), mid, spec.color, "SmoothPlastic", true, "Cylinder", v(0, yawTo(d.X, d.Z), math.deg(math.asin(d.Y / d.Magnitude)))))
			for i = 1, 8 do
				local a = i * 2.39996
				add(rec(`Floret2_{i}`, v(1.2, 1.1, 1.2), to + v(math.cos(a) * 2.6, between(rand, -0.6, 0.9), math.sin(a) * 2.6), pick({ C.umbel, "d9a1ab", "b47a86" }, rand), "SmoothPlastic", true, "Ball"))
			end
			local pod = byId[base .. "_pod"]
			if pod ~= nil then
				local pc = (pod.lo + pod.hi) * 0.5
				local ps = pod.hi - pod.lo
				add(rec("Pod", v(ps.X * 1.5, ps.Y * 1.08, ps.Z * 1.5), pc, C.pod, "SmoothPlastic", true, "Ellipsoid"))
				add(rec("PodTip", v(0.9, 1.6, 0.9), pc + v(0.4, ps.Y * 0.55, 0), "8aa86a", "SmoothPlastic", true, "Ellipsoid"))
			end
		end
	elseif kind == "coneflower" then
		-- the rays droop from the cone's foot; the cone is a dome of spiny orange-brown florets
		for i = 1, 13 do
			local a = i / 13 * TAU + between(rand, -0.08, 0.08)
			add(rec(`Ray{tag}_{i}`, v(4.6, 0.12, 1.15), v(plant.x + math.cos(a) * 5.4, top + 0.1 - 1.1, plant.z + math.sin(a) * 5.4), pick({ C.petal, "c27a9c", "a85f84" }, rand),
				"SmoothPlastic", true, nil, v(0, -math.deg(a), -28)))
		end
		local cone = byId[base .. "_cone"]
		if cone ~= nil then
			local cc = (cone.lo + cone.hi) * 0.5
			add(rec(`Cone{tag}`, v(4.2, 4.0, 4.2), cc + v(0, 0.3, 0), "9a4b1c", "Sand", true, "Ball"))
			for i = 1, 6 do
				local a = i / 6 * TAU
				add(rec(`Spine{tag}_{i}`, v(0.7, 0.7, 0.7), cc + v(math.cos(a) * 1.7, 1.2 + (i % 2) * 0.6, math.sin(a) * 1.7), "c0702a", "SmoothPlastic", true, "Ball"))
			end
		end
		for i = 1, 3 do
			local box = byId[`{base}_basal_{i}`]
			if box ~= nil then
				local c, l, w, ax = leafShape(box)
				add(rec(`Basal{tag}_{i}`, along(ax, l * 1.2, 0.35, w * 1.25), c + v(0, 0.05, 0), C.leaf, "SmoothPlastic", true, "Ellipsoid"))
			end
		end
	elseif kind == "beebalm" then
		-- the head: a whorl of lavender tubes curving out and up from a green button, over a ring of pale bracts
		add(rec(`Button{tag}`, v(5.2, 4.4, 5.2), hc, "7a7a52", "SmoothPlastic", true, "Ellipsoid"))
		for i = 1, 16 do
			local a = i / 16 * TAU + between(rand, -0.1, 0.1)
			local up = between(rand, 15, 60)
			local len = between(rand, 2.6, 3.4)
			local out = v(math.cos(a), 0, math.sin(a))
			local dir = (out * math.cos(math.rad(up)) + v(0, math.sin(math.rad(up)), 0))
			add(rec(`Tube{tag}_{i}`, v(len, 0.45, 0.45), hc + out * 2.3 + dir * (len / 2) + v(0, 0.6 + (i % 3) * 0.5, 0), pick({ C.monarda, "b79cc0", "9a7aa6" }, rand), "SmoothPlastic", true, nil,
				v(0, yawTo(out.X, out.Z), up)))
		end
		for i = 1, 5 do
			local a = i / 5 * TAU + 0.3
			add(rec(`Bract{tag}_{i}`, v(3.0, 0.15, 1.4), hc + v(math.cos(a) * 2.6, -1.6, math.sin(a) * 2.6), "c9b8a6", "SmoothPlastic", true, "Ellipsoid", v(0, -math.deg(a), -18)))
		end
	elseif kind == "goldenrod" then
		-- the many narrow leaves up the stem between the walkable ones (drawn only: 6 to 8 cm, too narrow to stand on)
		for i = 1, 10 do
			local y = S + (14 + i * 6.3) * k
			local a = i * 2.39996
			local l = between(rand, 6, 8)
			local out = v(math.cos(a), 0, math.sin(a))
			add(rec(`Narrow{tag}_{i}`, v(l, 0.2, 1.1), v(plant.x, y, plant.z) + out * (l / 2 + 0.4) + v(0, l * 0.15, 0), C.goldenLeaf, "SmoothPlastic", true, "Ellipsoid",
				v(0, yawTo(out.X, out.Z), 16)))
		end
		-- the plume: the axis on up through the head, branches arching out to one side and the other, each with its sprays of florets along its upper side
		add(rec(`Axis{tag}`, v(0.5, (head.hi.Y - head.lo.Y) + 4, 0.5), hc + v(0, 2, 0), spec.color, "SmoothPlastic", true))
		for i = 1, 11 do
			local t = (i - 0.5) / 11
			local y = head.lo.Y + t * (head.hi.Y - head.lo.Y)
			local a = i * 2.39996
			local reach = 8 * (1 - t * 0.6)
			local out = v(math.cos(a), 0, math.sin(a))
			local tip = v(plant.x, y + 2.2, plant.z) + out * reach
			local root = v(plant.x, y, plant.z)
			local d = tip - root
			add(rec(`Branch{tag}_{i}`, v(d.Magnitude, 0.25, 0.25), (root + tip) * 0.5, spec.color, "SmoothPlastic", true, "Cylinder",
				v(0, yawTo(d.X, d.Z), math.deg(math.asin(d.Y / d.Magnitude)))))
			add(rec(`Spray{tag}_{i}`, v(reach * 0.95, 1.8, 2.0), (root + tip) * 0.5 + v(0, 1.0, 0) + out * 0.8, pick({ C.goldenrod, "e2c24a", "c9a22e" }, rand), "SmoothPlastic", true,
				"Ellipsoid", v(0, yawTo(d.X, d.Z), 14)))
		end
		add(rec(`Crown{tag}`, v(3.6, 6, 3.6), v(plant.x, head.hi.Y + 1.0, plant.z), C.goldenrod, "SmoothPlastic", true, "Ellipsoid"))
		add(rec(`Core{tag}`, v(4.2, (head.hi.Y - head.lo.Y) * 0.9, 4.2), hc, "c9a830", "SmoothPlastic", true, "Ellipsoid"))
	end
end

-- Whether (x, z) lies on the garden's gravel path (with a margin `m`).
local function onPath(x: number, z: number, m: number): boolean
	local Pa = Hut.PATH
	return (x > Pa.ew.x0 - m and x < Pa.ew.x1 + m and z > Pa.ew.z0 - m and z < Pa.ew.z1 + m) or (x > Pa.ns.x0 - m and x < Pa.ns.x1 + m and z > Pa.ns.z0 - m and z < Pa.ns.z1 + m)
end

-- Whether (x, z) is clear of every box standing on the surface at `top` (by `m`).
local function clear(standing: { Box }, x: number, z: number, m: number): boolean
	for _, b in standing do
		if x > b.min.X - m and x < b.max.X + m and z > b.min.Z - m and z < b.max.Z + m then return false end
	end
	return true
end

-- The standing boxes of a region at or near a surface (`top`: the ground or the beds' soil): what a drawn thing on that surface keeps clear of.
local function standingNear(region: Region, top: number): { Box }
	local out: { Box } = {}
	if region.kind == "garden_bed" and top == GT then
		-- (and what stands on the lawn from the regions beside it: the bench's legs, the water butt's stand, the feeder's pole)
		for _, p in benchPieces() do if p.lo.Y <= GT + 0.6 then table.insert(out, { min = p.lo, max = p.hi }) end end
		for _, p in buttPieces() do if p.lo.Y <= GT + 0.6 then table.insert(out, { min = p.lo, max = p.hi }) end end
		local Q = Hut.POLE
		table.insert(out, { min = v(Q.x - Q.half, GT, Q.z - Q.half), max = v(Q.x + Q.half, GT + Q.split, Q.z + Q.half) })
	end
	for _, p in Hut.pieces(region) do
		if p.lo.Y <= top + 0.6 and p.hi.Y > top + 0.05 and not string.find(p.id, "_soil", 1, true) and not string.find(p.id, "_bed", 1, true)
			and not string.find(p.id, "_gravel", 1, true) then
			table.insert(out, { min = p.lo, max = p.hi })
		end
	end
	return out
end

-- A blade of grass from its foot at `at`: `h` tall, `w` wide, leaning `lean` degrees toward the yaw `yaw` (degrees); `bend`, if given, the upper half leans that much
-- more (a second segment). Returns how many records it took.
local function blade(add: (Drawn) -> boolean, id: string, at: Vector3, h: number, w: number, yaw: number, lean: number, bend: number?, color: string, full: boolean): number
	local function seg(sid: string, from: Vector3, len: number, l: number): Vector3
		local r = math.rad(l)
		local dir = v(-math.sin(r) * math.cos(math.rad(yaw)), math.cos(r), math.sin(r) * math.sin(math.rad(yaw)))
		add(rec(sid, v(w, len, 0.06), from + dir * (len / 2), color, "SmoothPlastic", full, nil, v(0, yaw, l)))
		return from + dir * len
	end
	if bend == nil then
		seg(id, at, h, lean)
		return 1
	end
	local knee = seg(id .. "a", at, h * 0.55, lean)
	seg(id .. "b", knee, h * 0.45, lean + bend)
	return 2
end

-- The part of the pollinator bed's soil inside a cell, { x0, x1, z0, z1 }.
local function bedArea(region: Region): { number }?
	local b, E = Hut.POLLINATOR, Hut.EDGING.thick
	local lo, hi = region.bounds[1], region.bounds[2]
	local a, bb, c, d = clip(b.x0 + E, b.x1 - E, b.z0 + E, b.z1 - E, lo.X, hi.X, lo.Z, hi.Z)
	if a == nil then return nil end
	return { a, bb :: number, c :: number, d :: number }
end
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
	-- the lawn's clumps (two at the low tier): what the lawn is from further off, the patches' blades standing among them close up
	local rand = rng(region.seed, 29)
	local standing = standingNear(region, GT)
	local placed = 0
	for _ = 1, 60 do
		if placed >= 8 then break end
		local x, z = between(rand, cx0 + 4, cx1 - 4), between(rand, cz0 + 4, cz1 - 4)
		if bedAt(x, z) == nil and not onPath(x, z, 5) and z < -50 and clear(standing, x, z, 6) and not (bedAt(x - 6, z) or bedAt(x + 6, z) or bedAt(x, z - 6) or bedAt(x, z + 6)) then
			placed += 1
			local spin = between(rand, 0, 360)
			for b = 1, 3 do
				local yaw = spin + b * 120 + between(rand, -20, 20)
				blade(add, `Clump{placed}_{b}`, v(x, GT, z), between(rand, 6, 13), between(rand, 0.35, 0.5), yaw, between(rand, 4, 16), nil, pick(C.lawnColors, rand), placed > 2 or b > 1)
			end
		end
	end
	-- the mulch from further off: its layers of shredded bark in their tones and the bigger pieces over them (the patches' chips stand among them close up)
	local bed = bedArea(region)
	if bed ~= nil then
		local onBed = standingNear(region, S)
		local n = 0
		for _ = 1, 60 do
			if n >= 22 then break end
			local x, z = between(rand, bed[1] + 3, bed[2] - 3), between(rand, bed[3] + 3, bed[4] - 3)
			if clear(onBed, x, z, 2) then
				n += 1
				if n % 2 == 1 then
					local w = between(rand, 6, 14)
					add(rec(`Mottle{n}`, v(w, 0.1, w * between(rand, 0.4, 0.8)), v(x, S + between(rand, 0.03, 0.1), z), pick({ "3f2a1b", "4a3220", "5a3c26", "553826", "61442e", "6b5040" }, rand),
						"Ground", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
				else
					local l = between(rand, 1.5, 3.5)
					add(rec(`Bark{n}`, v(l, between(rand, 0.15, 0.3), l * between(rand, 0.3, 0.6)), v(x, S + 0.2, z), pick({ "5a3c26", "6b4a30", "4a3220", "3f2a1b", "6e5a48" }, rand), "Wood", true, nil,
						v(between(rand, -10, 10), between(rand, 0, 180), between(rand, -8, 8))))
				end
			end
		end
	end
	-- the plants, drawn whole over their boxes
	local plant = PLANTS[id]
	if plant ~= nil then plantDecor(region, plant, "", add, rand) end
	local more = MORE_PLANTS[id]
	if more ~= nil then plantDecor(region, more, "2", add, rand) end
end

-- The path round the east end: the lawn's edge leaning over the gravel either side (its own stones are the patches').
local function pathDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local rand = rng(region.seed, 37)
	local alongX = hi.X - lo.X > hi.Z - lo.Z
	for i = 1, 3 do
		local side = if i % 2 == 0 then 1 else -1
		local x, z
		if alongX then x, z = between(rand, lo.X + 5, hi.X - 5), if side > 0 then hi.Z + 1 else lo.Z - 1
		else x, z = if side > 0 then hi.X + 1 else lo.X - 1, between(rand, lo.Z + 5, hi.Z - 5) end
		-- (a tuft of the lawn's edge, its blades leaning out over the gravel)
		local out = if alongX then (if side > 0 then 90 else 270) else (if side > 0 then 180 else 0)
		for b = 1, 3 do
			blade(add, `Edge{i}_{b}`, v(x + between(rand, -0.6, 0.6), GT, z + between(rand, -0.6, 0.6)), between(rand, 6, 13), between(rand, 0.35, 0.5), out + between(rand, -35, 35),
				between(rand, 8, 25), nil, pick(C.lawnColors, rand), i > 1 or b > 1)
		end
	end
end

-- ---------------------------------------------------------------- the patches (ROBLOX-117): what the spider sees close
-- Each garden cell and each length of the path is cut into patches of about PATCH studs square, drawn-only looks of their own (kind "patch", World/WorldMap.patches)
-- that World/LookPlan draws only near the spider (LookPlan.PATCH_RADIUS): the dense detail of the ground at true size where the eye is, and nothing beyond it.
--   the lawn ........ tufts of grass blades 3 to 5 mm wide and 5 to 15 cm tall, leaning and bending, each round a clump; seed heads on taller stalks; white clover;
--   the mulch ....... shredded bark in layers (chips of 1 to 6 cm in reds, browns and weathered greys, tilted over one another), shredded leaf, twigs, seeds, the
--                     soil showing between, and now and then a seedling;
--   the gravel ...... stones of 2 to 12 mm in the path's tones;
-- and where they fall, the petals and florets under the flowers, the husks and millet under the feeder and a cardinal's feather, and the morning's dew on blades
-- and chips (the "Dew" group, shown by the hour).
Hut.PATCH = 25
local PATCHED: { [string]: boolean } = { garden_bed = true, hut_path = true }
local patchParent: { [string]: Region } = {}

-- The patches of the hut's regions, for a world seed: region-shaped records of kind "patch", their bounds the patch's footprint from the ground to 30 studs over the beds.
function Hut.patches(regions: { Region }, worldSeed: number, seedOf: (number, string) -> number): { Region }
	local out: { Region } = {}
	for _, r in regions do
		if PATCHED[r.kind] then
			local lo, hi = r.bounds[1], r.bounds[2]
			local nx = math.max(1, math.ceil((hi.X - lo.X) / Hut.PATCH - 1e-6))
			local nz = math.max(1, math.ceil((hi.Z - lo.Z) / Hut.PATCH - 1e-6))
			local dx, dz = (hi.X - lo.X) / nx, (hi.Z - lo.Z) / nz
			for i = 1, nx do
				for j = 1, nz do
					local pid = `{r.id}~{i}_{j}`
					local plo, phi = v(lo.X + (i - 1) * dx, GT - 2, lo.Z + (j - 1) * dz), v(lo.X + i * dx, S + 30, lo.Z + j * dz)
					local mid = (plo + phi) * 0.5
					local p = table.freeze({
						id = pid, kind = "patch", origin = mid, bounds = table.freeze({ plo, phi }), seed = seedOf(worldSeed, pid), neighbors = table.freeze({}),
						retreats = table.freeze({}), spawn = table.freeze({ pos = mid, heading = v(0, 0, -1) }), clockScale = r.clockScale,
					}) :: any
					patchParent[pid] = r
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

-- The region a patch belongs to.
function Hut.patchParent(patch: Region): Region?
	return patchParent[patch.id]
end

-- What the ground is at (x, z) of a region: "lawn", "mulch", "soil" (the herb bed), "gravel" (a path), "drip" (the strip along the hut's foot), and its top.
local function surfaceAt(region: Region, x: number, z: number): (string, number)
	if region.kind == "hut_path" then return "gravel", GT end
	local bed = bedAt(x, z)
	if bed == "pollinator" then return "mulch", S end
	if bed == "herbs" then return "soil", S end
	if onPath(x, z, 0) then return "gravel", GT end
	if z > -46 then return "drip", GT end
	return "lawn", GT
end

local GRASS = { "5c8a3a", "6f9a46", "4f7a33", "86a85a", "7d8f48", "668f3e", "93a860", "a8a066" }
local CHIPS = { "5a3c26", "6b4a30", "4a3220", "7a5536", "3f2a1b", "6e5a48", "5e4434", "4d3a2c", "7e6650" }
local LAYERS = { "3f2a1b", "4a3220", "5a3c26", "553826", "3a2a20", "61442e" }
local STONES = { "b3a68a", "938870", "c9bfa8", "8f8676", "a69a80", "d1c7b0", "7d7466", "bfae92" }

-- The patch's look: low records first (the few the low tier keeps), then the full tier's, to its budget.
local function patchDecor(patch: Region, add: (Drawn) -> boolean)
	local parent = patchParent[patch.id]
	if parent == nil then return end
	local lo, hi = patch.bounds[1], patch.bounds[2]
	local rand = rng(patch.seed, 41)
	local onGround = standingNear(parent, GT)
	local onBed = standingNear(parent, S)
	local Q = Hut.POLE
	local feeder = parent.id == "garden_b1" or parent.id == "garden_a1" or parent.id == "garden_b2" or parent.id == "garden_a2"
	-- the spots: a jittered grid of 5 by 5, in a seeded order
	local spots: { Vector3 } = {}
	local n = 5
	for i = 1, n do
		for j = 1, n do
			local x = lo.X + (i - 1 + between(rand, 0.15, 0.85)) * (hi.X - lo.X) / n
			local z = lo.Z + (j - 1 + between(rand, 0.15, 0.85)) * (hi.Z - lo.Z) / n
			table.insert(spots, v(x, 0, z))
		end
	end
	for i = #spots, 2, -1 do
		local j = 1 + math.floor(rand() * i) % i
		spots[i], spots[j] = spots[j], spots[i]
	end
	local function free(kind: string, x: number, z: number, m: number): boolean
		if kind == "mulch" or kind == "soil" then return clear(onBed, x, z, m) end
		return clear(onGround, x, z, m)
	end
	local k = 0
	-- a tuft of grass: blades from one crown, each leaning out from it (its yaw away from the crown), a few bent over at the knee; `low` of them the low tier keeps
	local function tuft(x: number, z: number, low: number, bladesN: number)
		k += 1
		local tone = pick(GRASS, rand)
		local spin = between(rand, 0, 360)
		for b = 1, bladesN do
			local yaw = spin + b / bladesN * 360 + between(rand, -25, 25)
			local r = between(rand, 0.15, 0.7)
			local foot = v(x + math.cos(math.rad(yaw)) * r, GT, z - math.sin(math.rad(yaw)) * r)
			blade(add, `Blade{k}_{b}`, foot, between(rand, 5, 15), between(rand, 0.3, 0.5), yaw + 180, between(rand, 3, 18),
				if rand() < 0.3 then between(rand, 15, 45) else nil, if rand() < 0.5 then tone else pick(GRASS, rand), b > low)
		end
	end
	-- shredded bark: mostly strips (2 to 5 cm long, 4 to 10 mm wide, thin), some chunks; each tilted over the ones under it, in layers
	local function chip(x: number, z: number, y: number, full: boolean, big: boolean)
		k += 1
		local strip = not big and rand() < 0.65
		local l = if big then between(rand, 2.0, 3.5) elseif strip then between(rand, 1.5, 4) else between(rand, 0.8, 2.0)
		local w = if strip then between(rand, 0.3, 0.8) else l * between(rand, 0.45, 0.75)
		local t = if strip then between(rand, 0.1, 0.18) else between(rand, 0.18, 0.35)
		add(rec(`Chip{k}`, v(l, t, w), v(x, y + t / 2 + between(rand, 0, 0.25), z), pick(CHIPS, rand), "Wood", full, nil,
			v(between(rand, -14, 14), between(rand, 0, 180), between(rand, -12, 12))))
	end
	-- a layer of the mulch: a broad, flat, irregular patch of one tone over the bed's own, so the mulch reads mottled and layered
	local function layer(x: number, z: number, y: number, full: boolean)
		k += 1
		local w = between(rand, 4, 8)
		add(rec(`Layer{k}`, v(w, 0.12, w * between(rand, 0.5, 0.85)), v(x, y + between(rand, 0.04, 0.14), z), pick(LAYERS, rand), "Ground", full, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	local function stone(x: number, z: number, y: number, full: boolean, dark: boolean)
		k += 1
		local s = between(rand, 0.2, 0.9)
		add(rec(`Stone{k}`, v(s, s * between(rand, 0.55, 0.85), s * between(rand, 0.75, 1.15)), v(x, y + s * 0.2, z), if dark then pick({ "7d7466", "938870", "6e665a" }, rand) else pick(STONES, rand),
			"Pebble", full, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	-- the low tier's few: a clump on the lawn, the bigger chips on the mulch, the bigger stones on the gravel
	for s = 1, 4 do
		local p = spots[s]
		local kind, top = surfaceAt(parent, p.X, p.Z)
		if free(kind, p.X, p.Z, 2) then
			if kind == "lawn" then
				if s <= 2 then tuft(p.X, p.Z, 5, 5) end
			elseif kind == "mulch" then
				layer(p.X, p.Z, top, false)
				chip(p.X + between(rand, -2, 2), p.Z + between(rand, -2, 2), top, false, s == 1)
			elseif kind == "gravel" or kind == "drip" then
				for _ = 1, 2 do stone(p.X + between(rand, -2, 2), p.Z + between(rand, -2, 2), top, false, kind == "drip") end
			end
		end
	end
	-- what falls where: the husks and millet under the feeder and a cardinal's feather; petals and florets under the flowers
	local function near(x: number, z: number, r: number): boolean
		local cx, cz = math.clamp(x, lo.X, hi.X), math.clamp(z, lo.Z, hi.Z)
		return (cx - x) ^ 2 + (cz - z) ^ 2 <= r * r
	end
	if feeder and near(Q.x, Q.z, 30) then
		for i = 1, 9 do
			local x, z = between(rand, lo.X + 1, hi.X - 1), between(rand, lo.Z + 1, hi.Z - 1)
			if (v(x, 0, z) - v(Q.x, 0, Q.z)).Magnitude < 32 and free("lawn", x, z, 0.8) then
				if i % 3 == 0 then
					add(rec(`Millet{i}`, v(0.25, 0.2, 0.25), v(x, GT + 0.1, z), "d8c08a", "SmoothPlastic", true, "Ball"))
				else
					add(rec(`Husk{i}`, v(1.0, 0.16, 0.5), v(x, GT + 0.12, z), pick({ "2a2420", "3a3430", "4a4440" }, rand), "SmoothPlastic", true, "Ellipsoid",
						v(between(rand, -20, 20), between(rand, 0, 180), 0)))
				end
			end
		end
		if near(Q.x + 14, Q.z - 12, 0.1) then
			-- a cardinal's contour feather, 5 cm, lying where it fell under the feeder
			local at = v(Q.x + 14, GT + 0.15, Q.z - 12)
			add(rec("FeatherShaft", v(5.2, 0.12, 0.12), at, "e6dcd2", "SmoothPlastic", true, "Cylinder", v(0, 35, 2)))
			add(rec("FeatherVane1", v(4.2, 0.03, 0.9), at + v(-0.2, 0.05, -0.45), "b2242a", "Fabric", true, "Ellipsoid", v(0, 35, 4)))
			add(rec("FeatherVane2", v(3.8, 0.03, 0.8), at + v(0.1, 0.05, 0.45), "9c1f26", "Fabric", true, "Ellipsoid", v(0, 35, -3)))
		end
	end
	for _, list in { { PLANTS[parent.id] }, { MORE_PLANTS[parent.id] } } :: { { any } } do
		local plant = list[1]
		if plant ~= nil and near(plant.x, plant.z, 16) then
			for i = 1, 4 do
				local a, r = between(rand, 0, TAU), between(rand, 3, 14)
				local x, z = plant.x + math.cos(a) * r, plant.z + math.sin(a) * r
				if x > lo.X and x < hi.X and z > lo.Z and z < hi.Z and free("mulch", x, z, 0.5) then
					if plant.kind == "coneflower" then
						add(rec(`Petal{i}`, v(4.2, 0.06, 1.0), v(x, S + 0.45, z), pick({ C.petal, "9c6a84", "c79bb2" }, rand), "SmoothPlastic", true, nil, v(between(rand, -8, 8), between(rand, 0, 180), 0)))
					elseif plant.kind == "milkweed" then
						add(rec(`Fallen{i}`, v(1.0, 0.7, 1.0), v(x, S + 0.6, z), pick({ "b88a8e", "a07a7e", C.umbel }, rand), "SmoothPlastic", true, "Ball"))
					elseif plant.kind == "goldenrod" then
						add(rec(`Fleck{i}`, v(0.5, 0.3, 0.5), v(x, S + 0.5, z), "c9a22e", "SmoothPlastic", true, "Ball"))
					end
				end
			end
		end
	end
	-- the rest of the full tier's detail, spot by spot, to the patch's budget
	local dews = 0
	for pass = 1, 5 do
		for s, p in spots do
			local x, z = p.X + between(rand, -2.2, 2.2) * (pass - 1), p.Z + between(rand, -2.2, 2.2) * (pass - 1)
			local kind, top = surfaceAt(parent, x, z)
			if free(kind, x, z, 1.5) then
				if kind == "lawn" then
					if (s + pass) % 3 ~= 0 then tuft(x, z, 0, 8)
					elseif pass == 1 and s % 5 == 0 then
						-- a seed head on a taller stalk
						k += 1
						local h = between(rand, 14, 20)
						local lean = between(rand, 3, 12)
						local yaw = between(rand, 0, 360)
						local r = math.rad(lean)
						local dir = v(-math.sin(r) * math.cos(math.rad(yaw)), math.cos(r), math.sin(r) * math.sin(math.rad(yaw)))
						add(rec(`Stalk{k}`, v(0.18, h, 0.18), v(x, GT, z) + dir * (h / 2), "a8a066", "SmoothPlastic", true, nil, v(0, yaw, lean)))
						add(rec(`Seedhead{k}`, v(0.7, 2.6, 0.7), v(x, GT, z) + dir * (h + 1.0), pick({ "b5a36a", "9a8a5a", "c2b27a" }, rand), "SmoothPlastic", true, "Ellipsoid", v(0, yaw, lean)))
					elseif pass == 1 and s % 7 == 1 then
						-- white clover: three round leaflets on a stalk
						k += 1
						local hh = between(rand, 2, 4)
						add(rec(`CloverStalk{k}`, v(0.12, hh, 0.12), v(x, GT + hh / 2, z), "7a9a52", "SmoothPlastic", true))
						for q = 1, 3 do
							local a = q / 3 * TAU + between(rand, 0, 0.5)
							add(rec(`Clover{k}_{q}`, v(1.3, 0.1, 1.1), v(x + math.cos(a) * 0.65, GT + hh, z + math.sin(a) * 0.65), "4f7d3a", "SmoothPlastic", true, "Ellipsoid", v(0, -math.deg(a), 0)))
						end
					elseif dews < 3 then
						dews += 1
						add(drop(`Dew{dews}`, v(x, GT + between(rand, 3, 8), z), between(rand, 0.3, 0.55), rand))
					end
				elseif kind == "mulch" then
					local roll = rand()
					if pass == 1 and s % 4 == 0 then layer(x, z, top, true)
					elseif roll < 0.7 then
						chip(x, z, top, true, rand() < 0.15)
						for _ = 1, 2 do chip(x + between(rand, -2, 2), z + between(rand, -2, 2), top, true, false) end
					elseif roll < 0.74 then
						k += 1
						add(rec(`LeafBit{k}`, v(between(rand, 1, 2.5), 0.05, between(rand, 0.5, 1.2)), v(x, top + 0.45, z), pick({ "6b5a32", "7a6a3a", "5a5a2e", "8a6a3a" }, rand), "Fabric", true, nil,
							v(between(rand, -10, 10), between(rand, 0, 180), 0)))
					elseif roll < 0.8 then
						k += 1
						add(rec(`Twig{k}`, v(between(rand, 3, 8), between(rand, 0.18, 0.32), between(rand, 0.18, 0.32)), v(x, top + 0.4, z), pick({ "6e5e4e", "5a4a3a", "7e6e5a" }, rand), "Wood", true,
							"Cylinder", v(0, between(rand, 0, 180), between(rand, -4, 4))))
					elseif roll < 0.86 then
						k += 1
						add(rec(`Seed{k}`, v(0.55, 0.3, 0.35), v(x, top + 0.35, z), pick({ "2e2620", "c9b48a", "6a4a2a" }, rand), "SmoothPlastic", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
					elseif roll < 0.93 then
						k += 1
						local w = between(rand, 3, 6)
						add(rec(`Earth{k}`, v(w, 0.08, w * between(rand, 0.5, 0.9)), v(x, top + 0.03, z), C.soilDark, "Ground", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
					elseif pass == 1 then
						-- a seedling coming up through the mulch: a stem and its first two leaves
						k += 1
						local h = between(rand, 2, 4)
						add(rec(`Seedling{k}`, v(0.15, h, 0.15), v(x, top + h / 2, z), "7a9a52", "SmoothPlastic", true))
						add(rec(`SeedLeaf{k}a`, v(1.4, 0.08, 0.7), v(x + 0.7, top + h, z), "6f9a46", "SmoothPlastic", true, "Ellipsoid", v(0, 0, 12)))
						add(rec(`SeedLeaf{k}b`, v(1.4, 0.08, 0.7), v(x - 0.7, top + h, z), "6f9a46", "SmoothPlastic", true, "Ellipsoid", v(0, 0, -12)))
					elseif dews < 2 then
						dews += 1
						add(drop(`Dew{dews}`, v(x, top + 0.6, z), between(rand, 0.25, 0.45), rand))
					end
				elseif kind == "soil" then
					if rand() < 0.5 then chip(x, z, top, true, false) else
						k += 1
						add(rec(`Crumb{k}`, v(1.2, 0.4, 0.9), v(x, top + 0.15, z), C.soilDark, "Ground", true, "Ellipsoid"))
					end
				else
					for _ = 1, 4 do stone(x + between(rand, -2.4, 2.4), z + between(rand, -2.4, 2.4), top, true, kind == "drip") end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- (ROBLOX-118) the looks of the ceiling, the back room and the eaves
-- A thread from a to b, `dia` across (a web's silk, a cable): a Cylinder turned onto the line (World/PreserveLook's rod).
local function thread(add: (Drawn) -> boolean, id: string, a: Vector3, b: Vector3, dia: number, color: string, full: boolean, transparency: number?)
	local d = b - a
	local len = d.Magnitude
	local u = d / len
	local d0 = rec(id, v(len, dia, dia), (a + b) * 0.5, color, "SmoothPlastic", full, "Cylinder", v(0, math.deg(math.atan2(-u.Z, u.X)), math.deg(math.asin(math.clamp(u.Y, -1, 1)))))
	d0.transparency = transparency
	return add(d0)
end

-- The ceiling over a cell: the boards' joints (they run east and west across the joists); in the hut's north-west corner over the notice board, a house spider's web:
-- the American house spider (Parasteatoda tepidariorum) hangs a tangle of threads in a ceiling's corner, sits in it head down, and wraps what it catches.
local function upperDecor(region: Region, add: (Drawn) -> boolean)
	local U = UPPER[region.id]
	local CE = Hut.CEIL
	local z = math.ceil(U.z0 / 12) * 12
	local k = 0
	while z < U.z1 - 1 do
		k += 1
		add(rec(`Joint{k}`, v(U.x1 - U.x0, 0.02, 0.2), v((U.x0 + U.x1) / 2, CE - 0.01, z), "a88a62", "WoodPlanks", true))
		z += 12
	end
	if region.id == "hut_up_a" then
		local R = Hut.ROOM
		local corner = v(R.x0, CE, R.z0)
		local rand = rng(region.seed, 11)
		local hub = corner + v(9, -10, 8) -- (where the spider waits, in the tangle's heart)
		for i = 1, 14 do
			-- (from the ceiling, the west wall or the north wall near the corner to a point in the tangle)
			local face = i % 3
			local a = if face == 0 then corner + v(between(rand, 2, 24), 0, between(rand, 2, 22))
				elseif face == 1 then corner + v(0, between(rand, -22, -2), between(rand, 2, 24)) else corner + v(between(rand, 2, 24), between(rand, -22, -2), 0)
			local b = hub + v(between(rand, -6, 6), between(rand, -6, 5), between(rand, -6, 6))
			thread(add, `Silk{i}`, a, b, 0.08, "e9e6de", true, 0.2)
		end
		-- two gumfooted lines down toward the wall's lining, and the spider: its round abdomen and small cephalothorax, head down; a wrapped fly hanging by it
		thread(add, "SilkFoot1", hub, corner + v(3, -46, 26), 0.08, "e9e6de", true, 0.2)
		thread(add, "SilkFoot2", hub, corner + v(24, -50, 2), 0.08, "e9e6de", true, 0.2)
		add(rec("HouseSpider", v(0.55, 0.6, 0.55), hub + v(0, -0.2, 0), "6b5a44", "SmoothPlastic", true, "Ball"))
		add(rec("HouseSpiderHead", v(0.25, 0.3, 0.25), hub + v(0, -0.65, 0), "8a6a46", "SmoothPlastic", true, "Ball"))
		add(rec("Wrapped", v(0.4, 0.7, 0.4), hub + v(3, -2, 2), "d9d3c6", "SmoothPlastic", true, "Ellipsoid"))
	end
end

-- The back room's floor: the boards' joints (north and south, as the hut's), a knot or two, the rug's border and its pattern's bands where it lies.
local function roomFloorDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local x = math.ceil(lo.X / 14) * 14
	local k = 0
	while x < hi.X - 1 do
		k += 1
		add(rec(`Joint{k}`, v(0.18, 0.02, hi.Z - lo.Z), v(x, FL + 0.01, (lo.Z + hi.Z) / 2), C.floorDark, "WoodPlanks", true))
		x += 14
	end
	local rand = rng(region.seed, 5)
	for i = 1, 2 do
		add(rec(`Knot{i}`, v(1.2, 0.02, 2.2), v(between(rand, lo.X + 4, hi.X - 4), FL + 0.012, between(rand, lo.Z + 4, hi.Z - 4)), "5e4430", "Wood", true, "Ellipsoid"))
	end
	local G = Hut.RUG
	local a, b, c, d = clip(G.x0 + 6, G.x1 - 6, G.z0 + 6, G.z1 - 6, lo.X, hi.X, lo.Z, hi.Z)
	if a ~= nil then
		-- (a border band 6 cm in from the rug's edge, and its middle field a shade darker)
		add(rec("RugField", v((b :: number) - a, 0.03, (d :: number) - (c :: number)), v((a + (b :: number)) / 2, FL + G.top + 0.015, ((c :: number) + (d :: number)) / 2), "6a3029", "Fabric", false))
	end
	for side, zz in { G.z0 + 3, G.z1 - 3 } do
		local a2, b2 = math.max(G.x0 + 2, lo.X), math.min(G.x1 - 2, hi.X)
		if b2 > a2 and zz > lo.Z and zz < hi.Z then add(rec(`RugBand{side}`, v(b2 - a2, 0.03, 1.4), v((a2 + b2) / 2, FL + G.top + 0.015, zz), "c9a45a", "Fabric", true)) end
	end
end

-- The sofa: the piping along the cushions' fronts and the back's top, a throw folded over the east arm; the controller's sticks and buttons.
local function sofaDecor(region: Region, add: (Drawn) -> boolean)
	local S0 = Hut.SOFA
	local west = region.id == "room_sofa_w"
	local ia, ib = if west then S0.x0 + S0.arm else S0.split, if west then S0.split else S0.x1 - S0.arm
	add(rec("Piping", v(ib - ia - 1, 0.5, 0.5), v((ia + ib) / 2, S0.seat - 0.2, S0.z0 + 2.4), C.sofaDark, "Fabric", true))
	add(rec("BackPiping", v(ib - ia, 0.5, 0.5), v((ia + ib) / 2, S0.back + 0.2, 245), C.sofaDark, "Fabric", true))
	local ax = if west then S0.x0 + S0.arm / 2 else S0.x1 - S0.arm / 2
	add(rec("ArmTop", v(S0.arm + 1, 2.5, S0.z1 - S0.z0 + 1), v(ax, S0.armTop - 0.5, (S0.z0 + S0.z1) / 2), C.sofa, "Fabric", true, "Cylinder", v(90, 90, 0)))
	if west then
		add(rec("StickL", v(1.4, 0.8, 1.4), v(284, S0.seat + 4.3, 200), "3a3c40", "SmoothPlastic", true, "Cylinder", v(0, 0, 90)))
		add(rec("StickR", v(1.4, 0.8, 1.4), v(291, S0.seat + 4.3, 203), "3a3c40", "SmoothPlastic", true, "Cylinder", v(0, 0, 90)))
		for i, c in { "3f8f5a", "c0392b", "2e86c1", "e0b23a" } do
			add(rec(`Button{i}`, v(0.7, 0.3, 0.7), v(292 + (i % 2) * 1.2, S0.seat + 4.1, 199 + math.floor((i - 1) / 2) * 1.2), c, "SmoothPlastic", true, "Ball"))
		end
	else
		add(rec("Throw", v(S0.arm + 3, 12, 40), v(S0.x1 - S0.arm / 2, S0.armTop - 4, 200), "b9a27a", "Fabric", true))
	end
end

-- The television: its screen's glass (low: the dark face that tells it is a screen), its maker's light; the console's light and its cable to the television.
local function tvDecor(_region: Region, add: (Drawn) -> boolean)
	local Sc = Hut.TV.screen
	local glass = rec("Screen", v(Sc.x1 - Sc.x0 - 2, Sc.y1 - Sc.y0 - 2, 0.05), v((Sc.x0 + Sc.x1) / 2, (Sc.y0 + Sc.y1) / 2, Sc.z1 + 0.03), "0b0c0e", "Glass", false)
	glass.reflectance = 0.25
	add(glass)
	add(rec("TvLight", v(0.4, 0.4, 0.1), v(230, Sc.y0 + 0.6, Sc.z1 + 0.06), "d23a2a", "Neon", true))
	add(rec("ConsoleLight", v(4, 0.3, 0.1), v(210, -62, 47.06), "6fb7ff", "Neon", true))
	add(rec("Hdmi", v(0.6, 18, 0.6), v(224, -54, 24), "1e1e1e", "SmoothPlastic", true))
end

-- The board games: a label band on the front edge of each box, its own colour lighter or darker.
local function gamesDecor(region: Region, add: (Drawn) -> boolean)
	local k = 0
	for _, p in Hut.pieces(region) do
		if string.find(p.id, "_box_", 1, true) ~= nil and k < 20 then
			k += 1
			local h = p.hi.Y - p.lo.Y
			add(rec(`Label{k}`, v((p.hi.X - p.lo.X) * 0.6, h * 0.45, 0.05), v((p.lo.X + p.hi.X) / 2, (p.lo.Y + p.hi.Y) / 2, p.hi.Z + 0.03), if k % 2 == 0 then "f2eee2" else "1f1f1f", "SmoothPlastic", true))
		end
	end
end

-- The back room's window: the sash's frame round its glass inside, and its catch.
local function roomWindowDecor(_region: Region, add: (Drawn) -> boolean)
	local Wn = Hut.ROOM_WINDOW
	local gx = Wn.glass - 0.4
	add(rec("FrameLow", v(0.8, 4, Wn.z1 - Wn.z0), v(gx, 2, (Wn.z0 + Wn.z1) / 2), "efe9da", "Wood", true))
	add(rec("FrameHigh", v(0.8, 4, Wn.z1 - Wn.z0), v(gx, Wn.head - 2, (Wn.z0 + Wn.z1) / 2), "efe9da", "Wood", true))
	add(rec("FrameRail", v(0.8, 3, Wn.z1 - Wn.z0), v(gx, Wn.head / 2, (Wn.z0 + Wn.z1) / 2), "efe9da", "Wood", true))
	add(rec("Catch", v(1.2, 1.2, 3), v(gx - 0.8, Wn.head / 2 + 2, (Wn.z0 + Wn.z1) / 2), C.brass, "Metal", true))
end

-- The eaves: the gutter's hangers over it every 60 cm.
local function eaveDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local Gu = Hut.EAVE.gutter
	local k = 0
	local x = math.ceil((lo.X + 10) / 60) * 60
	while x < hi.X - 5 and k < 4 do
		k += 1
		add(rec(`Hanger{k}`, v(1.2, 0.3, Hut.EAVE.fascia.out - Gu.out + Gu.wall), v(x, Gu.lip - 0.4, (Gu.out - Gu.wall + Hut.EAVE.fascia.out) / 2), C.gutter, "Metal", true))
		x += 60
	end
end

local decorCache: { [string]: { Drawn } } = {}
-- The drawn look of a region of the hut or its garden, at the full tier (the low tier is the records without `full`). (ROBLOX-117: and of a patch.)
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
	elseif k == "garden_bed" then gardenDecor(region, add)
	elseif k == "hut_path" then pathDecor(region, add)
	elseif k == "patch" then patchDecor(region, add)
	elseif k == "hut_upper" then upperDecor(region, add)
	elseif k == "room_floor" then roomFloorDecor(region, add)
	elseif k == "room_sofa" then sofaDecor(region, add)
	elseif k == "room_tv" then tvDecor(region, add)
	elseif k == "room_games" then gamesDecor(region, add)
	elseif k == "room_window" then roomWindowDecor(region, add)
	elseif k == "hut_eave" then eaveDecor(region, add) end
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
	-- (ROBLOX-117) the hoverflies on the bed's flowers; the hut's own prey: fruit flies at the compost caddy by the door, a moth at the desk lamp from dusk
	hoverflies = { garden_c4 = { full = 1, low = 1 }, garden_d4 = { full = 1, low = 1 }, garden_c3 = { full = 1, low = 1 } },
	fruitflies = { hut_floor_i = { full = 4, low = 2 }, room_floor_g = { full = 2, low = 1 } },
	moths = { hut_desk = { full = 1, low = 1 }, room_window = { full = 1, low = 1 } },
})
-- (ROBLOX-117) The compost caddy by the door, on the floor east of the doorway against the south wall: a kitchen caddy of green plastic, its lid down, a banana peel over
-- its rim; the fruit flies' home in the hut.
Hut.CADDY = table.freeze({ x0 = 68, x1 = 90, z0 = 228, z1 = 246, h = 19, lid = 1.5 })

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
	local hover, fruit, moth = Hut.LIFE.hoverflies[region.id], Hut.LIFE.fruitflies[region.id], Hut.LIFE.moths[region.id]
	if spring == nil and hopper == nil and hover == nil and fruit == nil and moth == nil then return nil end
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
	-- (ROBLOX-117) a perch list of `kind` with these spots ({ position, normal, shelter, food }), the first `starts` of them starting perches
	local function spot(p: Vector3, n: Vector3, sh: number, fo: number): { any }
		return { p, n, sh, fo }
	end
	local function spots(kind: string, list: { { any } }, starts: number): { Perch }
		local perches: { Perch } = {}
		for i, sp in list do
			table.insert(perches, { id = `{region.id}_{kind}_{i}`, position = sp[1], normal = sp[2], shelter = sp[3], food = sp[4], start = i <= starts, kind = "leaf" })
		end
		return perches
	end
	if hover ~= nil then
		-- the hoverflies: on the flowers' heads and the plants' upper leaves (the cell's two plants), coming in out of sight over the bed
		local byId = piecesById(region)
		local list: { { any } } = {}
		for _, pl in { { PLANTS[region.id], "" }, { MORE_PLANTS[region.id], "2" } } :: { { any } } do
			local plant = pl[1]
			if plant ~= nil then
				local base = `{region.id}_{plant.kind}{pl[2]}`
				local head = byId[base .. "_cone"] or byId[base .. "_head"]
				if head ~= nil then table.insert(list, spot(v((head.lo.X + head.hi.X) / 2, head.hi.Y, (head.lo.Z + head.hi.Z) / 2), Vector3.yAxis, 0.2, 0.9)) end
				local spec = PLANT_SPECS[plant.kind]
				for i = #spec.leaves, math.max(1, #spec.leaves - 2), -1 do
					local leaf = byId[`{base}_leaf_{i}`]
					if leaf ~= nil then table.insert(list, spot(v((leaf.lo.X + leaf.hi.X) / 2 + (leaf.hi.X - leaf.lo.X) * 0.25, leaf.hi.Y, (leaf.lo.Z + leaf.hi.Z) / 2), Vector3.yAxis, 0.3, 0.5)) end
				end
			end
		end
		local plant = PLANTS[region.id] :: any
		local vents: { Vent } = { { id = `{region.id}_vent_hoverfly`, position = v(plant.x, S + PLANT_SPECS[plant.kind].height + 14, plant.z), normal = Vector3.yAxis, appear = true, reach = 80 } }
		local salt = 113
		table.insert(out, { kind = "hoverfly", profile = "hoverfly_prototype", perches = spots("hoverfly", list, hover.full), vents = vents, target = hover.full, low = hover.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_hoverfly_fly_` })
	end
	if fruit ~= nil then
		local list: { { any } }
		local vents: { Vent }
		if region.id == "room_floor_g" then
			-- (ROBLOX-118) the caddy's fruit flies drifting through the doorway into the back room: on the boards inside it, the skirting, the wall's lining by it
			local B = Hut.BACK
			list = {
				spot(v(B.x0 + 8, FL, 195), Vector3.yAxis, 0.1, 0.3), spot(v(B.x0 + 16, FL, 232), Vector3.yAxis, 0.1, 0.3), spot(v(B.x0 + 30, FL, 212), Vector3.yAxis, 0.1, 0.3),
				spot(v(B.x0 + 4, FL, 186), Vector3.yAxis, 0.1, 0.3), spot(v(B.x0, -40, 177), Vector3.xAxis, 0.3, 0.1), spot(v(B.x0, -30, 252), Vector3.xAxis, 0.3, 0.1),
			}
			vents = { { id = `{region.id}_vent_fruit_fly`, position = v(B.x0 + 6, FL + 14, 215), normal = Vector3.yAxis, appear = true, reach = 40 } }
		else
			-- the fruit flies: on the caddy's lid and its sides, the peel, and the floor in front of it
			local K = Hut.CADDY
			local top = FL + K.h + K.lid
			list = {
				spot(v(K.x0 + 5, top, K.z0 + 6), Vector3.yAxis, 0.3, 0.9), spot(v(K.x1 - 5, top, K.z0 + 10), Vector3.yAxis, 0.3, 0.9), spot(v(K.x0 + 11, top, K.z1 - 5), Vector3.yAxis, 0.3, 0.8),
				spot(v(K.x1 - 4, top, K.z1 - 4), Vector3.yAxis, 0.3, 0.8), spot(v(K.x0 + 6, FL + 12, K.z0), -Vector3.zAxis, 0.2, 0.6), spot(v(K.x1 - 7, FL + 8, K.z0), -Vector3.zAxis, 0.2, 0.6),
				spot(v(K.x1, FL + 10, K.z0 + 8), Vector3.xAxis, 0.2, 0.6), spot(v(K.x0 - 6, FL, K.z0 - 5), Vector3.yAxis, 0.1, 0.4), spot(v(K.x0 + 14, FL, K.z0 - 8), Vector3.yAxis, 0.1, 0.4),
			}
			vents = { { id = `{region.id}_vent_fruit_fly`, position = v((K.x0 + K.x1) / 2, top + 6, (K.z0 + K.z1) / 2), normal = Vector3.yAxis, appear = true, reach = 40 } }
		end
		local salt = 127
		table.insert(out, { kind = "fruit_fly", profile = "fruit_fly_prototype", perches = spots("fruit_fly", list, fruit.full), vents = vents, target = fruit.full, low = fruit.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_fruit_fly_fly_` })
	end
	if moth ~= nil then
		local list: { { any } }
		local vents: { Vent }
		if region.id == "room_window" then
			-- (ROBLOX-118) a moth at the back room's window at night: on the glass, the sill, the reveals and under the head
			local Wn = Hut.ROOM_WINDOW
			list = {
				spot(v(Wn.glass, 60, 120), -Vector3.xAxis, 0.2, 0.2), spot(v(Wn.glass, 85, 150), -Vector3.xAxis, 0.2, 0.2), spot(v(440, 0, 108), Vector3.yAxis, 0.2, 0.1),
				spot(v(452, 70, Wn.z0), Vector3.zAxis, 0.3, 0.1), spot(v(452, 40, Wn.z1), -Vector3.zAxis, 0.3, 0.1), spot(v(452, Wn.head, 140), -Vector3.yAxis, 0.3, 0.1),
			}
			vents = { { id = `{region.id}_vent_moth`, position = v(445, 70, 134), normal = -Vector3.xAxis, appear = true, reach = 40 } }
		else
			-- the moth: on the lamp's shade, the wall's lining behind the lamp and the desk by its base; restless from dusk, when the lamp is lit
			local R = Hut.ROOM
			list = {
				spot(v(110, 44, 24), Vector3.yAxis, 0.2, 0.2), spot(v(118, 39, 24), Vector3.xAxis, 0.2, 0.2), spot(v(100, 50, R.z0), Vector3.zAxis, 0.3, 0.1),
				spot(v(126, 42, R.z0), Vector3.zAxis, 0.3, 0.1), spot(v(88, 30, R.z0), Vector3.zAxis, 0.3, 0.1), spot(v(96, 4, 26), Vector3.yAxis, 0.2, 0.1),
			}
			vents = { { id = `{region.id}_vent_moth`, position = v(110, 52, 34), normal = Vector3.yAxis, appear = true, reach = 40 } }
		end
		local salt = 131
		table.insert(out, { kind = "moth", profile = "moth_prototype", perches = spots("moth", list, moth.full), vents = vents, target = moth.full, low = moth.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_moth_fly_`, dusk = { from = 18.0, to = 6.0 } })
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
