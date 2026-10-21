--!strict
-- The meadow's edge and the bench, bin and lamppost, walkable (ROBLOX-119, docs/PARK_WORLD_DESIGN.md Phase C round 1): home ranges 3 and 8 at full spider detail, where
-- the hut garden's gravel path (World/Hut's path_m1..m4) comes out at z 13 m. Pure data and pure generators, as World/Hut's are: the regions (`author`), their physical
-- boxes (`pieces`), their drawn looks (`decor`), their near detail (`patches`), and the life they hold (`bestiary`, `ambient`) and the crab spiders' flowers (`CRABS`),
-- all from the region and its seed, so the server, every client and the CLI tests get the same meadow. Nothing here requires World/WorldMap or World/Garden.
--
-- Studs, the sill's frame (World/Preserve: x east, -z north, a stud a centimetre; the ground GROUND as the hut garden's, World/Hut.GROUND). True scale.
--
-- The bench patch (home range 8, 3 by 3 m: x -210..90, z -816..-1116, that is x 43.65..46.65 m, z 13..16 m), where the path widens at the meadow's edge:
--   pad_a1..c3 ...... nine cells of a metre of fine gravel (rows a to c north from the path's end, columns 1 to 3 west to east); along the north a concrete slab under
--                     the furniture (SLAB, 2 cm proud of the gravel); in pad_b3 a cast-iron drain grate over its pit (GRATE: bars 2 cm with 2 cm slots, the pit
--                     10 cm deep, a spider can go down through a slot).
--   bench_w, bench_e .. a park bench facing south over the path (BENCH: 1.64 m long, its seat of four slats 45 cm over the slab, three back slats, cast-iron ends), in
--                     two halves split at x -70 (each whole inside the streaming radius); the gap between its second and third seat slats is a home (bench_slats).
--   bin ............. a steel litter bin (BIN: 40 by 40 cm, 90 cm to its lid) on a flared base raised on four feet over the slab: the gap under the base's lip is a
--                     home (bin_lip); a drinks can and a crisp packet dropped on the gravel by it.
--   lamp_1..4 ....... the lamppost (LAMP: a pole 10 cm square on a cast base, a lantern on top 3.4 m up), in four regions up the pole (each whole in the radius); its
--                     lantern lights at dusk (Client/HutLife) and the moths come to it at night.
-- The meadow's edge (home range 3, 5 by 5 m: x -310..190, z -1116..-1616, that is x 42.65..47.65 m, z 16..21 m), north of the bench patch, late summer:
--   meadow_a1..e5 ... twenty-five cells of a metre (rows a to e north from the bench patch, columns 1 to 5 west to east) of an American tallgrass meadow at true size:
--                     big bluestem (Andropogon gerardii: culms to 1.13 m here, the turkey-foot heads) and little bluestem (Schizachyrium scoparium: 50 to 70 cm, its
--                     silvery tufts) in clumps, common milkweed, purple coneflower, black-eyed Susan, wild bergamot, Canada goldenrod and yarrow; the thatch, bare
--                     soil and an ant hill between them; the south edge along the gravel mown short. Every culm, leaf and flower head a spider can climb is a box; the
--                     blades, racemes, rays and florets are drawn over them (World/Hut.drawPlant for the hut garden's kinds). A curled dead leaf lying on two old
--                     stems in meadow_b2 is a home (meadow_b2_leaf).
-- The life (`bestiary`, `ambient`): leafhoppers on the bluestem's culms, house flies and hoverflies on the flower heads, small moths on the grass heads from dusk; ants
-- at their hill (Prey/Ant: not food, and a strike at one is refused); house flies at the bin; moths at the lamp's lantern. The crab spiders (Predator/CrabSpider) sit on
-- the goldenrod's plumes and the yarrow's heads (CRABS).
local Hut = require(script.Parent.Hut)

local Meadow = {}

export type Region = Hut.Region
export type Piece = Hut.Piece
export type Drawn = Hut.Drawn
export type Box = Hut.Box

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function hex(s: string): Color3
	return Color3.fromHex(s)
end
local MOD = 2147483647
local TAU = 2 * math.pi
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
local GT = Hut.GROUND
Meadow.GROUND = GT
Meadow.CELL = 100
-- The bench patch's pad and the meadow's core (studs).
Meadow.PAD = table.freeze({ x0 = -210, x1 = 90, z0 = -1116, z1 = -816 })
Meadow.CORE = table.freeze({ x0 = -310, x1 = 190, z0 = -1616, z1 = -1116 })
-- The concrete slab under the furniture, its top SL (2 cm over the gravel).
Meadow.SLAB = table.freeze({ x0 = -200, x1 = 86, z0 = -1106, z1 = -1030, top = GT + 2 })
local SL = Meadow.SLAB.top
-- The bench, facing south: its ends' frames, its seat's four slats (front to back, `w` deep with `gap` between), its back's three slats, true size (a seat 45 cm over the
-- slab and 42 deep, its back to 81 cm; 1.64 m long). Split at `mid` into two regions.
Meadow.BENCH = table.freeze({ x0 = -152, x1 = 12, mid = -70, ends = table.freeze({ -144, 0 }), frame = 4, front = -1048, w = 9, gap = 1.8, thick = 3, seat = 45,
	legTop = 38, railZ = table.freeze({ -1092, -1048 }), post = table.freeze({ -1096, -1092 }), back = table.freeze({ { 50, 59 }, { 61, 70 }, { 72, 81 } }), backZ = table.freeze({ -1092, -1089 }),
	armZ = table.freeze({ -1092, -1046 }), arm = table.freeze({ 62, 65 }), armPost = table.freeze({ -1050, -1047 }) })
-- The litter bin: its body, its base plate (the lip) on four feet 1.4 cm tall, its rolled rim and its lid; the can and the crisp packet by it on the gravel.
Meadow.BIN = table.freeze({ x0 = 40, x1 = 80, z0 = -1094, z1 = -1054, feet = 1.4, base = 4, lip = 3, top = 80, rim = 83, lid = 88 })
Meadow.CAN = table.freeze({ x0 = 52, x1 = 64, z0 = -1028, z1 = -1021.4 }) -- a 12 oz can (12.2 cm by 6.6 cm) lying on its side
Meadow.PACKET = table.freeze({ x0 = 18, x1 = 32, z0 = -1026, z1 = -1017, h = 2.2 }) -- a crisp packet, crumpled flat
-- The lamppost: a cast base, the pole 10 cm square to `top`, the lantern on it (its plate, glass, cap and finial); the regions split up the pole at `splits`.
Meadow.LAMP = table.freeze({ x = -180, z = -1068, half = 5, base = table.freeze({ half = 10, h = 14 }), top = 340, splits = table.freeze({ 90, 180, 270 }),
	plate = table.freeze({ half = 12, h = 3 }), glass = table.freeze({ half = 10, h = 26 }), cap = table.freeze({ half = 15, h = 4 }), finial = table.freeze({ half = 2, h = 6 }) })
-- The drain grate in pad_b3: its hole, its bars across it (x-long), the pit's floor `deep` under the gravel.
Meadow.GRATE = table.freeze({ x0 = 20, x1 = 50, z0 = -960, z1 = -930, wall = 2, bars = 6, bar = 2.0, deep = 12 })
local LAMP_TOP = SL + Meadow.LAMP.top
Meadow.LANTERN = table.freeze({ at = v(Meadow.LAMP.x, LAMP_TOP + Meadow.LAMP.plate.h + Meadow.LAMP.glass.h * 0.5, Meadow.LAMP.z) }) -- the light (Client/HutLife)

-- The palette.
local C = {
	gravel = "b3a68a", gravelDark = "938870", concrete = "9a958b", concreteDark = "817c72", iron = "26292b", ironDark = "1b1d1f", slat = "8a6440", slatDark = "6e4f33",
	bin = "3d4a3e", binDark = "2c372d", can = "b8242a", canTop = "c9cdd0", packet = "d9a227", packetFoil = "c7cbcf", lamp = "1f2224", glass = "e6e0c8",
	soil = "6e5a3e", meadow = "76693f", thatch = { "b8a77a", "a89766", "c2b38a", "9c8b5e", "b09f70" }, mown = { "6f9a46", "7d9a4e", "5f8a3e" },
	big = { "8a6a4a", "7d6a52", "6f7a52", "8f7650", "6a7a5a", "9a7a56" }, bigLeaf = { "6f8a5a", "7a8a62", "8a7a5a", "5f7a52", "9a7a5a" }, raceme = { "6a4a5a", "7a5a4a", "5e4a52" },
	little = { "9a8a62", "b08a5a", "8a8a5e", "a07a52" }, littleLeaf = { "8a9a6a", "9aa070", "a89a6a", "7a8a5a" }, tuft = { "e6e2d6", "dcd8cc", "efece2" },
	susan = "e8a21e", susanCone = "3a2418", susanLeaf = "5a7a3a", yarrow = "ece8dc", yarrowLeaf = "6f8a52", hill = "8a7050", hillDark = "6e5a40", leaf = "8a6a3a", leafDark = "6a4a28",
	stem = "6a7a48",
}

-- ---------------------------------------------------------------- the meadow's plants (true sizes; the hut garden's kinds keep World/Hut.PLANT_SPECS)
-- black-eyed Susan (Rudbeckia hirta): 30 to 90 cm, a few rough leaves up the stem, a head 5 to 7 cm of yellow rays round a dark brown cone.
-- yarrow (Achillea millefolium): 30 to 90 cm, feathery leaves, a flat-topped head 5 to 10 cm of tiny white florets.
type Leaf = { h: number, dir: string, l: number, w: number }
local SPECS: { [string]: any } = {
	susan = { stem = 0.5, height = 58, thick = 0.25, leaves = { { h = 10, dir = "x+", l = 9, w = 3 }, { h = 24, dir = "z-", l = 7, w = 2.4 }, { h = 38, dir = "x-", l = 6, w = 2 } },
		head = { w = 6, h = 0.5 }, cone = { w = 2.2, h = 2 }, color = C.stem, leaf = C.susanLeaf, flower = C.susan },
	yarrow = { stem = 0.4, height = 52, thick = 0.2, leaves = { { h = 12, dir = "x-", l = 8, w = 1.6 }, { h = 26, dir = "z+", l = 7, w = 1.4 }, { h = 40, dir = "x+", l = 6, w = 1.2 } },
		head = { w = 6.5, h = 1.6 }, color = C.stem, leaf = C.yarrowLeaf, flower = C.yarrow },
}
Meadow.SPECS = SPECS
-- The grasses: a clump's culms (offsets from its crown, studs), their heights (studs; big bluestem's culms to 1.2 m here, little bluestem's 50 to 70 cm), how thick, the
-- two tallest headed; one blade bent over flat at `bent` (a bridge between clumps), `blade` long.
local GRASS = {
	big = { at = { { 0, 0 }, { 3, 1 }, { -2, 2.5 }, { 1, -3 } }, h = { 113, 100, 92, 106 }, half = 0.25, head = { half = 0.8, h = 7 }, bent = 38, blade = 12 },
	little = { at = { { 0, 0 }, { 2.4, 0.8 }, { -1.6, 2 }, { 0.8, -2.4 } }, h = { 66, 58, 52, 62 }, half = 0.18, head = { half = 0.6, h = 5 }, bent = 22, blade = 9 },
}
Meadow.GRASS = GRASS
-- Each cell's plants: its forb (in the first slot) and its clumps (the others), by row (a, south by the gravel, to e) and column (1, west, to 5). Slots: offsets (east of the
-- cell's west edge, north of its south edge) of a forb or a clump's crown.
local SLOTS = { { 32, 36 }, { 68, 64 }, { 68, 32 }, { 32, 68 } }
local PLAN: { [string]: { forb: string?, clumps: { string }, hill: boolean?, leaf: boolean? } } = {
	a1 = { forb = "susan", clumps = { "little", "big", "little" } }, a2 = { forb = "yarrow", clumps = { "little", "big" } }, a3 = { forb = "coneflower", clumps = { "big", "little", "big" } },
	a4 = { forb = "susan", clumps = { "little", "big", "little" } }, a5 = { clumps = { "big", "little", "big" } },
	b1 = { clumps = { "big", "big", "little" } }, b2 = { forb = "yarrow", clumps = { "little", "big" }, leaf = true }, b3 = { forb = "milkweed", clumps = { "big", "little", "big" } },
	b4 = { clumps = { "little", "big", "little" }, hill = true }, b5 = { forb = "goldenrod", clumps = { "big", "little", "big" } },
	c1 = { forb = "coneflower", clumps = { "little", "big", "little" } }, c2 = { forb = "beebalm", clumps = { "big", "little", "big" } }, c3 = { forb = "goldenrod", clumps = { "little", "big", "little" } },
	c4 = { forb = "susan", clumps = { "big", "little", "big" } }, c5 = { forb = "yarrow", clumps = { "little", "big", "little" } },
	d1 = { forb = "goldenrod", clumps = { "big", "little", "big" } }, d2 = { forb = "milkweed", clumps = { "little", "big", "little" } }, d3 = { clumps = { "big", "big", "little" } },
	d4 = { forb = "yarrow", clumps = { "little", "big", "little" } }, d5 = { forb = "coneflower", clumps = { "big", "little", "big" } },
	e1 = { forb = "beebalm", clumps = { "little", "big", "little" } }, e2 = { forb = "susan", clumps = { "big", "little", "big" } }, e3 = { forb = "goldenrod", clumps = { "big", "little", "big" } },
	e4 = { clumps = { "big", "little", "big" } }, e5 = { forb = "milkweed", clumps = { "little", "big", "little" } },
}
Meadow.PLAN = PLAN
-- The ant hill (in meadow_b4's first slot): a low mound of fine soil in steps, its top 7 cm over the meadow's floor.
Meadow.HILL = table.freeze({ steps = table.freeze({ { 15, 2 }, { 11, 2 }, { 7, 2 }, { 3, 1 } }) })
-- The curled dead leaf in meadow_b2 (a cottonwood leaf blown in, curled and dry), lying on two old stems: the gap under it is a home.
Meadow.LEAF = table.freeze({ dx = 43, dz = 44, l = 14, w = 12, rest = 1.5, gap = 1.4, thick = 0.6 })

local ROWS = { "a", "b", "c", "d", "e" }
local PAD_ROWS = { "a", "b", "c" }
-- A meadow cell's rectangle (x0, x1, z0, z1) from its row (1..5) and column (1..5).
local function meadowBox(r: number, c: number): (number, number, number, number)
	local K = Meadow.CORE
	return K.x0 + (c - 1) * 100, K.x0 + c * 100, K.z1 - r * 100, K.z1 - (r - 1) * 100
end
local function padBox(r: number, c: number): (number, number, number, number)
	local K = Meadow.PAD
	return K.x0 + (c - 1) * 100, K.x0 + c * 100, K.z1 - r * 100, K.z1 - (r - 1) * 100
end
Meadow.meadowBox = meadowBox
Meadow.padBox = padBox

-- The place of a slot in a cell (x0, its south edge z1), with the cell's own jitter.
local function slotAt(x0: number, z1: number, k: number, rand: () -> number): (number, number)
	local s = SLOTS[k]
	return x0 + s[1] + between(rand, -3, 3), z1 - s[2] + between(rand, -3, 3)
end

-- A cell's plants placed: its forb { kind, x, z } and its clumps { kind, x, z, dir } (the bent blade's way: out from the cell's middle along x), from its seed.
type Placed = { forb: { kind: string, x: number, z: number, scale: number? }?, clumps: { { kind: string, x: number, z: number, dir: number } }, hill: { x: number, z: number }?,
	leaf: { x: number, z: number }? }
local placedCache: { [string]: Placed } = {}
local function placed(region: Region): Placed
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = placedCache[key]
	if cached ~= nil then return cached end
	local plan = PLAN[string.sub(region.id, 8)]
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0, z1 = lo.X, hi.Z
	local rand = rng(region.seed, 3)
	local out: Placed = { clumps = {} }
	local fx, fz = slotAt(x0, z1, 1, rand)
	if plan.forb ~= nil then out.forb = { kind = plan.forb, x = fx, z = fz } end
	if plan.hill then out.hill = { x = x0 + SLOTS[1][1], z = z1 - SLOTS[1][2] } end
	for i, kind in plan.clumps do
		local x, z = slotAt(x0, z1, i + 1, rand)
		table.insert(out.clumps, { kind = kind, x = x, z = z, dir = if x > x0 + 50 then 1 else -1 })
	end
	if plan.leaf then out.leaf = { x = x0 + Meadow.LEAF.dx, z = z1 - Meadow.LEAF.dz } end
	placedCache[key] = out
	return out
end
Meadow.placed = placed

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

type Seam = { a: string, b: string, p: Vector3, q: Vector3 }
local SEAMS: { Seam } = {}
local function seam(a: string, b: string, p: Vector3, q: Vector3)
	table.insert(SEAMS, { a = a, b = b, p = p, q = q })
end

local B = Meadow.BENCH
-- The seat's slats, front (1) to back (4): z0..z1 of each.
local SLATS: { { number } } = {}
for k = 1, 4 do
	local z1 = B.front - (k - 1) * (B.w + B.gap)
	table.insert(SLATS, { z1 - B.w, z1 })
end
Meadow.SLATS = SLATS

local RETREATS: { [string]: { id: string, min: Vector3, max: Vector3, door: Vector3 } } = {
	-- the slot between the seat's second and third slats, in the west half: a spider tucks in against a slat's side, out of the wind
	bench_w = { id = "bench_slats", min = v(-132, SL + B.seat - B.thick, SLATS[3][2]), max = v(-88, SL + B.seat, SLATS[2][1]), door = v(-110, SL + B.seat + 0.5, (SLATS[3][2] + SLATS[2][1]) / 2) },
	-- under the bin's base, between its feet: the gap under the lip
	bin = { id = "bin_lip", min = v(Meadow.BIN.x0 + 5, SL, Meadow.BIN.z0 + 5), max = v(Meadow.BIN.x1 - 5, SL + Meadow.BIN.feet, Meadow.BIN.z1 - 5),
		door = v((Meadow.BIN.x0 + Meadow.BIN.x1) / 2, SL + 0.5, Meadow.BIN.z1 + 4.5) },
}
do
	-- under the curled leaf in meadow_b2
	local x0, _, _, z1 = meadowBox(2, 2)
	local L = Meadow.LEAF
	local lx, lz = x0 + L.dx, z1 - L.dz
	RETREATS.meadow_b2 = { id = "meadow_b2_leaf", min = v(lx - L.l / 2 + L.rest, GT, lz - L.w / 2 + 1), max = v(lx + L.l / 2 - L.rest, GT + L.gap, lz + L.w / 2 - 1),
		door = v(lx, GT + 0.5, lz + L.w / 2 + 3) }
end
Meadow.RETREATS = RETREATS

-- The authored regions, for a world seed (`seedOf`: World/WorldMap.seed), in priority order (after the hut's: World/WorldMap.authorPreserve).
function Meadow.author(worldSeed: number, seedOf: (number, string) -> number): { Region }
	local list: { Region } = {}
	local byId: { [string]: Region } = {}
	local function region(id: string, kind: string, lo: Vector3, hi: Vector3, spawn: Vector3, heading: Vector3)
		local t = RETREATS[id]
		local r = {
			id = id, kind = kind, origin = v((lo.X + hi.X) / 2, if kind == "meadow" or kind == "pad" then GT else spawn.Y, (lo.Z + hi.Z) / 2), bounds = { lo, hi },
			seed = seedOf(worldSeed, id), neighbors = {}, retreats = if t ~= nil then { table.clone(t) } else {}, spawn = { pos = spawn, heading = heading }, clockScale = 0.33,
		}
		table.insert(list, r :: any)
		byId[id] = r :: any
	end
	-- the furniture first (its bounds reach down over the pad's cells: a spider at their feet is theirs)
	region("bench_w", "park_bench", v(B.x0, SL - 0.5, -1098), v(B.mid, SL + 88, -1044), v(-110, SL + B.seat, (SLATS[1][1] + SLATS[1][2]) / 2), v(0, 0, 1))
	region("bench_e", "park_bench", v(B.mid, SL - 0.5, -1098), v(B.x1, SL + 88, -1044), v(-30, SL + B.seat, (SLATS[1][1] + SLATS[1][2]) / 2), v(0, 0, 1))
	local N = Meadow.BIN
	region("bin", "park_bin", v(14, GT - 0.5, -1100), v(88, SL + N.lid + 4, -1016.5), v(60, SL + N.lid, -1074), v(0, 0, 1))
	local L = Meadow.LAMP
	local cuts = { 0, L.splits[1], L.splits[2], L.splits[3], L.top + L.plate.h + L.glass.h + L.cap.h + L.finial.h + 3 }
	for k = 1, 4 do
		local y0, y1 = SL + cuts[k] - (if k == 1 then 0.5 else 0), SL + cuts[k + 1]
		local spawn = if k == 1 then v(L.x - 8, SL + L.base.h, L.z) elseif k == 4 then v(L.x - 12, LAMP_TOP + L.plate.h + L.glass.h + L.cap.h, L.z)
			else v(L.x + L.half, SL + (cuts[k] + cuts[k + 1]) / 2, L.z)
		region(`lamp_{k}`, "lamppost", v(L.x - 20, y0, L.z - 20), v(L.x + 20, y1, L.z + 20), spawn, if k == 2 or k == 3 then v(0, 1, 0) else v(0, 0, 1))
	end
	-- the pad's cells: rows a..c north from the path's end, columns 1..3
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, z0, z1 = padBox(r, c)
			local id = `pad_{PAD_ROWS[r]}{c}`
			local sx, sz = (x0 + x1) / 2, (z0 + z1) / 2
			if r == 3 then sz = -1022; if c == 3 then sx = 0 end end -- (on the gravel south of the slab, clear of the furniture's bounds)
			if r == 2 and c == 3 then sx, sz = 75, -985 end -- (clear of the grate)
			region(id, "pad", v(x0, GT - Meadow.GRATE.deep - 3, z0), v(x1, GT + 40, z1), v(sx, GT, sz), v(0, 0, -1))
		end
	end
	-- the meadow's cells
	for r = 1, 5 do
		for c = 1, 5 do
			local x0, x1, z0, z1 = meadowBox(r, c)
			region(`meadow_{ROWS[r]}{c}`, "meadow", v(x0, -88, z0), v(x1, GT + 140, z1), v(x0 + 50, GT, z1 - 12), v(0, 0, -1))
		end
	end
	-- (a seam with World/Hut's path_m4 is listed on this side only: Hut lists it on its own)
	for _, s in SEAMS do
		local a, b = byId[s.a], byId[s.b]
		if a ~= nil then table.insert(a.neighbors, { id = s.b, a = s.p, b = s.q }) end
		if b ~= nil then table.insert(b.neighbors, { id = s.a, a = s.p, b = s.q }) end
	end
	for _, r in list do freeze(r) end
	return list
end

-- The seams that meet World/Hut's regions (the path's end): World/WorldMap adds these to path_m4's neighbours.
Meadow.HUT_SEAMS = table.freeze({
	table.freeze({ hut = "path_m4", id = "pad_a2", a = v(-88, GT, -816), b = v(-32, GT, -816) }),
})
for _, s in Meadow.HUT_SEAMS do seam(s.hut, s.id, s.a, s.b) end

do
	-- the pad's cells to one another, flat on the gravel (row c's lines between columns on the gravel south of the slab)
	for r = 1, 3 do
		for c = 1, 3 do
			local x0, x1, _, z1 = padBox(r, c)
			local here = `pad_{PAD_ROWS[r]}{c}`
			if c < 3 then
				local za, zb = z1 - 92, z1 - 8
				if r == 3 then za, zb = -1027, -1019 end
				seam(here, `pad_{PAD_ROWS[r]}{c + 1}`, v(x1, GT, za), v(x1, GT, zb))
			end
			if r < 3 then
				local xa, xb = x0 + 8, x1 - 8
				if r == 2 and c == 3 then xa, xb = x0 + 8, x0 + 24 end -- (clear of the packet by the bin)
				seam(here, `pad_{PAD_ROWS[r + 1]}{c}`, v(xa, GT, z1 - 100), v(xb, GT, z1 - 100))
			end
		end
	end
	-- the pad's north edge onto the meadow (columns 2..4 of row a): the gravel north of the slab meets the meadow's floor
	for c = 1, 3 do
		local x0, x1 = padBox(3, c)
		seam(`pad_c{c}`, `meadow_a{c + 1}`, v(x0 + 8, GT, Meadow.PAD.z0), v(x1 - 8, GT, Meadow.PAD.z0))
	end
	-- the furniture on the slab: a foot's face at the slab
	seam("bench_w", "pad_c1", v(B.ends[1], SL, B.front), v(B.ends[1] + B.frame, SL, B.front))
	seam("bench_e", "pad_c3", v(B.ends[2], SL, B.front), v(B.ends[2] + B.frame, SL, B.front))
	seam("bench_w", "bench_e", v(B.mid, SL + B.seat, SLATS[1][1] + 1), v(B.mid, SL + B.seat, SLATS[1][2] - 1)) -- (along the front slat's top)
	local N = Meadow.BIN
	seam("bin", "pad_c3", v(N.x0 - 1, SL, N.z1 - 1), v(N.x0 + 4, SL, N.z1 - 1)) -- (the south-west foot's face at the slab)
	local L = Meadow.LAMP
	seam("lamp_1", "pad_c1", v(L.x - L.base.half, SL, L.z + L.base.half), v(L.x + L.base.half, SL, L.z + L.base.half)) -- (the base's south face at the slab)
	for k = 1, 3 do
		local y = SL + L.splits[k]
		seam(`lamp_{k}`, `lamp_{k + 1}`, v(L.x + L.half, y, L.z - L.half), v(L.x + L.half, y, L.z + L.half)) -- (across the pole's east face)
	end
	-- the meadow's cells to one another, flat on its floor (the plants stand well in from the edges)
	for r = 1, 5 do
		for c = 1, 5 do
			local x0, x1, z0, z1 = meadowBox(r, c)
			local here = `meadow_{ROWS[r]}{c}`
			if c < 5 then seam(here, `meadow_{ROWS[r]}{c + 1}`, v(x1, GT, z0 + 8), v(x1, GT, z1 - 8)) end
			if r < 5 then seam(here, `meadow_{ROWS[r + 1]}{c}`, v(x0 + 8, GT, z0), v(x1 - 8, GT, z0)) end
		end
	end
end

-- ---------------------------------------------------------------- the pieces
local function P(out: { Piece }, id: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, profile: string, color: string, material: string?)
	table.insert(out, { id = id, lo = v(x0, y0, z0), hi = v(x1, y1, z1), profile = profile, color = hex(color), material = material })
end
local function clip(x0: number, x1: number, z0: number, z1: number, cx0: number, cx1: number, cz0: number, cz1: number): (number?, number?, number?, number?)
	local a, b, c, d = math.max(x0, cx0), math.min(x1, cx1), math.max(z0, cz0), math.min(z1, cz1)
	if b - a <= 1e-6 or d - c <= 1e-6 then return nil, nil, nil, nil end
	return a, b, c, d
end

local function padPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local lo, hi = region.bounds[1], region.bounds[2]
	local cx0, cx1, cz0, cz1 = lo.X, hi.X, lo.Z, hi.Z
	local G = Meadow.GRATE
	if id == "pad_b3" then
		-- the gravel round the grate's hole, the pit's walls and floor, the bars across it
		-- (either side in two along z, so no box's middle is far from where the spider steps in from the next cell)
		P(out, id .. "_gravel_wn", cx0, G.x0, -87, GT, cz0, G.z0, "brick_rough", C.gravel, "Pebble")
		P(out, id .. "_gravel_ws", cx0, G.x0, -87, GT, G.z0, cz1, "brick_rough", C.gravel, "Pebble")
		P(out, id .. "_gravel_en", G.x1, cx1, -87, GT, cz0, G.z0, "brick_rough", C.gravel, "Pebble")
		P(out, id .. "_gravel_es", G.x1, cx1, -87, GT, G.z0, cz1, "brick_rough", C.gravel, "Pebble")
		P(out, id .. "_gravel_n", G.x0, G.x1, -87, GT, cz0, G.z0, "brick_rough", C.gravel, "Pebble")
		P(out, id .. "_gravel_s", G.x0, G.x1, -87, GT, G.z1, cz1, "brick_rough", C.gravel, "Pebble")
		local floor = GT - G.deep
		P(out, id .. "_pit_floor", G.x0 + G.wall, G.x1 - G.wall, floor - 2, floor, G.z0 + G.wall, G.z1 - G.wall, "brick_rough", "3a3631", "Concrete")
		P(out, id .. "_pit_w", G.x0, G.x0 + G.wall, floor - 2, -87, G.z0, G.z1, "brick_rough", C.concreteDark, "Concrete")
		P(out, id .. "_pit_e", G.x1 - G.wall, G.x1, floor - 2, -87, G.z0, G.z1, "brick_rough", C.concreteDark, "Concrete")
		P(out, id .. "_pit_n", G.x0 + G.wall, G.x1 - G.wall, floor - 2, -87, G.z0, G.z0 + G.wall, "brick_rough", C.concreteDark, "Concrete")
		P(out, id .. "_pit_s", G.x0 + G.wall, G.x1 - G.wall, floor - 2, -87, G.z1 - G.wall, G.z1, "brick_rough", C.concreteDark, "Concrete")
		-- the frame at the top (its lip on the walls, flush with the gravel) and the bars across the hole
		P(out, id .. "_frame_w", G.x0, G.x0 + G.wall, -87, GT, G.z0, G.z1, "painted_metal_smooth", C.iron, "Metal")
		P(out, id .. "_frame_e", G.x1 - G.wall, G.x1, -87, GT, G.z0, G.z1, "painted_metal_smooth", C.iron, "Metal")
		local span = (G.z1 - G.z0) - 2 * G.wall
		local slot = (span - G.bars * G.bar) / (G.bars + 1)
		for k = 1, G.bars do
			local z0 = G.z0 + G.wall + slot * k + G.bar * (k - 1)
			P(out, `{id}_bar_{k}`, G.x0 + G.wall, G.x1 - G.wall, GT - 3, GT, z0, z0 + G.bar, "painted_metal_smooth", C.iron, "Metal")
		end
		return out
	end
	P(out, id .. "_gravel", cx0, cx1, -87, GT, cz0, cz1, "brick_rough", C.gravel, "Pebble")
	local S = Meadow.SLAB
	local a, b, c, d = clip(S.x0, S.x1, S.z0, S.z1, cx0, cx1, cz0, cz1)
	if a ~= nil then P(out, id .. "_slab", a, b :: number, GT, SL, c :: number, d :: number, "brick_rough", C.concrete, "Concrete") end
	return out
end

-- The bench's half (`s` -1 the west, 1 the east): its end frame, its share of the seat's and back's slats.
local function benchPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local west = id == "bench_w"
	local x0, x1 = if west then B.x0 else B.mid, if west then B.mid else B.x1
	local fx = if west then B.ends[1] else B.ends[2]
	local f0, f1 = fx, fx + B.frame
	-- the cast-iron end: the front leg, the rail under the seat, the rear post up to the back's top, the arm and its post
	P(out, id .. "_leg", f0, f1, SL, SL + B.legTop, B.front - 4, B.front, "painted_metal_smooth", C.iron, "Metal")
	P(out, id .. "_rail", f0, f1, SL + B.legTop, SL + B.seat - B.thick, B.railZ[1], B.railZ[2], "painted_metal_smooth", C.iron, "Metal")
	P(out, id .. "_post", f0, f1, SL, SL + B.back[3][2] + 2, B.post[1], B.post[2], "painted_metal_smooth", C.iron, "Metal")
	P(out, id .. "_arm_post", f0, f1, SL + B.seat, SL + B.arm[1], B.armPost[1], B.armPost[2], "painted_metal_smooth", C.iron, "Metal")
	P(out, id .. "_arm", f0 - 0.5, f1 + 0.5, SL + B.arm[1], SL + B.arm[2], B.backZ[2], B.armPost[2] + 1, "painted_metal_smooth", C.ironDark, "Metal")
	for k, s in SLATS do
		P(out, `{id}_slat_{k}`, x0, x1, SL + B.seat - B.thick, SL + B.seat, s[1], s[2], "varnished_wood_smooth", if k % 2 == 0 then C.slatDark else C.slat, "Wood")
	end
	for k, h in B.back do
		P(out, `{id}_back_{k}`, x0, x1, SL + h[1], SL + h[2], B.backZ[1], B.backZ[2], "varnished_wood_smooth", if k == 2 then C.slatDark else C.slat, "Wood")
	end
	return out
end

local function binPieces(): { Piece }
	local out: { Piece } = {}
	local N = Meadow.BIN
	for k, f in { { N.x0 - 1, N.z1 - 6 }, { N.x1 - 4, N.z1 - 6 }, { N.x0 - 1, N.z0 + 1 }, { N.x1 - 4, N.z0 + 1 } } do
		P(out, `bin_foot_{k}`, f[1], f[1] + 5, SL, SL + N.feet, f[2], f[2] + 5, "painted_metal_smooth", C.binDark, "Metal")
	end
	P(out, "bin_base", N.x0 - N.lip, N.x1 + N.lip, SL + N.feet, SL + N.base, N.z0 - N.lip, N.z1 + N.lip, "painted_metal_smooth", C.binDark, "Metal")
	P(out, "bin_body", N.x0, N.x1, SL + N.base, SL + N.top, N.z0, N.z1, "painted_metal_smooth", C.bin, "Metal")
	P(out, "bin_rim", N.x0 - 1, N.x1 + 1, SL + N.top, SL + N.rim, N.z0 - 1, N.z1 + 1, "painted_metal_smooth", C.binDark, "Metal")
	P(out, "bin_lid", N.x0 + 2, N.x1 - 2, SL + N.rim, SL + N.lid, N.z0 + 2, N.z1 - 2, "painted_metal_smooth", C.bin, "Metal")
	local K, Q = Meadow.CAN, Meadow.PACKET
	P(out, "bin_can", K.x0, K.x1, GT, GT + (K.z1 - K.z0), K.z0, K.z1, "painted_metal_smooth", C.can, "Metal")
	P(out, "bin_packet", Q.x0, Q.x1, GT, GT + Q.h, Q.z0, Q.z1, "painted_metal_smooth", C.packet, "SmoothPlastic")
	return out
end

local function lampPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local L = Meadow.LAMP
	local k = tonumber(string.sub(region.id, 6)) :: number
	local cuts = { 0, L.splits[1], L.splits[2], L.splits[3], L.top }
	local y0 = SL + cuts[k]
	if k == 1 then
		P(out, "lamp_base", L.x - L.base.half, L.x + L.base.half, SL, SL + L.base.h, L.z - L.base.half, L.z + L.base.half, "painted_metal_smooth", C.iron, "Metal")
		y0 = SL + L.base.h
	end
	P(out, region.id .. "_pole", L.x - L.half, L.x + L.half, y0, SL + cuts[k + 1], L.z - L.half, L.z + L.half, "painted_metal_smooth", C.lamp, "Metal")
	if k == 4 then
		local y = LAMP_TOP
		P(out, "lamp_plate", L.x - L.plate.half, L.x + L.plate.half, y, y + L.plate.h, L.z - L.plate.half, L.z + L.plate.half, "painted_metal_smooth", C.iron, "Metal")
		y += L.plate.h
		P(out, "lamp_glass", L.x - L.glass.half, L.x + L.glass.half, y, y + L.glass.h, L.z - L.glass.half, L.z + L.glass.half, "glass_clean", C.glass, "Glass")
		y += L.glass.h
		P(out, "lamp_cap", L.x - L.cap.half, L.x + L.cap.half, y, y + L.cap.h, L.z - L.cap.half, L.z + L.cap.half, "painted_metal_smooth", C.iron, "Metal")
		y += L.cap.h
		P(out, "lamp_finial", L.x - L.finial.half, L.x + L.finial.half, y, y + L.finial.h, L.z - L.finial.half, L.z + L.finial.half, "painted_metal_smooth", C.iron, "Metal")
	end
	return out
end

-- A forb of the meadow's own kinds (black-eyed Susan, yarrow): its stem, leaves out from the stem's faces, its head. Ids `<cell>_<kind>_...`.
local function forbPieces(out: { Piece }, id: string, plant: { kind: string, x: number, z: number, scale: number? }, y0: number)
	local spec = SPECS[plant.kind]
	if spec == nil then
		Hut.plantPieces(out :: any, id, plant, y0, nil) -- (the hut garden's kinds: milkweed, coneflower, bee balm, goldenrod)
		return
	end
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
	P(out, base .. "_head", plant.x - H.w / 2, plant.x + H.w / 2, top, top + H.h, plant.z - H.w / 2, plant.z + H.w / 2, "leaf_dry_prototype", spec.flower)
	if spec.cone ~= nil then
		local Q = spec.cone
		P(out, base .. "_cone", plant.x - Q.w / 2, plant.x + Q.w / 2, top + H.h, top + H.h + Q.h, plant.z - Q.w / 2, plant.z + Q.w / 2, "leaf_dry_prototype", C.susanCone)
	end
end

-- A grass clump's culms (each a thin box from the floor to its height), the heads on the two tallest, and one blade bent over flat from the first culm.
local function clumpPieces(out: { Piece }, id: string, k: number, clump: { kind: string, x: number, z: number, dir: number }, rand: () -> number)
	local G = GRASS[clump.kind]
	local base = `{id}_{clump.kind}{k}`
	for i, o in G.at do
		local x, z = clump.x + o[1], clump.z + o[2]
		local h = G.h[i] * between(rand, 0.92, 1.0)
		P(out, `{base}_culm_{i}`, x - G.half, x + G.half, GT, GT + h, z - G.half, z + G.half, "leaf_dry_prototype", pick(if clump.kind == "big" then C.big else C.little, rand))
		if i == 1 or i == 4 then
			P(out, `{base}_head_{i}`, x - G.head.half, x + G.head.half, GT + h, GT + h + G.head.h, z - G.head.half, z + G.head.half, "leaf_dry_prototype",
				if clump.kind == "big" then pick(C.raceme, rand) else pick(C.tuft, rand))
		end
	end
	-- the bent blade: a leaf arched over and lying flat, out from the first culm's face, away from the cell's middle
	local x, z = clump.x, clump.z
	local y = GT + G.bent
	if clump.dir > 0 then P(out, base .. "_blade", x + G.half, x + G.half + G.blade, y, y + 0.25, z - 0.45, z + 0.45, "leaf_dry_prototype", pick(if clump.kind == "big" then C.bigLeaf else C.littleLeaf, rand))
	else P(out, base .. "_blade", x - G.half - G.blade, x - G.half, y, y + 0.25, z - 0.45, z + 0.45, "leaf_dry_prototype", pick(if clump.kind == "big" then C.bigLeaf else C.littleLeaf, rand)) end
end

local function meadowPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local lo, hi = region.bounds[1], region.bounds[2]
	P(out, id .. "_soil", lo.X, hi.X, -87, GT, lo.Z, hi.Z, "brick_rough", C.meadow, "Grass") -- (the floor under the thatch)
	local at = placed(region)
	local rand = rng(region.seed, 5)
	if at.forb ~= nil then forbPieces(out, id, at.forb, GT) end
	for k, clump in at.clumps do clumpPieces(out, id, k, clump, rand) end
	if at.hill ~= nil then
		local y = GT
		for k, s in Meadow.HILL.steps do
			P(out, `{id}_hill_{k}`, at.hill.x - s[1], at.hill.x + s[1], y, y + s[2], at.hill.z - s[1], at.hill.z + s[1], "brick_rough", if k % 2 == 0 then C.hillDark else C.hill, "Ground")
			y += s[2]
		end
	end
	if at.leaf ~= nil then
		local L = Meadow.LEAF
		local x0, x1, z0, z1 = at.leaf.x - L.l / 2, at.leaf.x + L.l / 2, at.leaf.z - L.w / 2, at.leaf.z + L.w / 2
		P(out, id .. "_stem_w", x0, x0 + L.rest, GT, GT + L.gap, z0, z1, "leaf_dry_prototype", C.thatch[4])
		P(out, id .. "_stem_e", x1 - L.rest, x1, GT, GT + L.gap, z0, z1, "leaf_dry_prototype", C.thatch[2])
		P(out, id .. "_leaf", x0, x1, GT + L.gap, GT + L.gap + L.thick, z0, z1, "leaf_dry_prototype", C.leaf)
	end
	return out
end

local KINDS: { [string]: boolean } = { pad = true, park_bench = true, park_bin = true, lamppost = true, meadow = true }
-- Whether a kind is the meadow's or the bench patch's.
function Meadow.knows(kind: string): boolean
	return KINDS[kind] == true
end

local piecesCache: { [string]: { Piece } } = {}
function Meadow.pieces(region: Region): { Piece }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = piecesCache[key]
	if cached ~= nil then return cached end
	local k, out = region.kind, nil :: { Piece }?
	if k == "pad" then out = padPieces(region)
	elseif k == "park_bench" then out = benchPieces(region)
	elseif k == "park_bin" then out = binPieces()
	elseif k == "lamppost" then out = lampPieces(region)
	elseif k == "meadow" then out = meadowPieces(region)
	else error("no generator for the region kind " .. k) end
	local list = out :: { Piece }
	for _, p in list do table.freeze(p) end
	piecesCache[key] = table.freeze(list)
	return list
end
local function byIdOf(region: Region): { [string]: Piece }
	local out: { [string]: Piece } = {}
	for _, p in Meadow.pieces(region) do out[p.id] = p end
	return out
end

-- Nothing of the meadow's is drawn in place of its boxes: each is its own look (its material and colour), with the drawn detail over and beside it.
function Meadow.drawnPieces(_region: Region): { string }
	return {}
end

-- The boxes a region's creatures keep out of: each retreat grown by half a stud.
function Meadow.keepOut(region: Region): { Box }
	local out: { Box } = {}
	for _, t in region.retreats do table.insert(out, { min = t.min - v(0.5, 0.5, 0.5), max = t.max + v(0.5, 0.5, 0.5) }) end
	return out
end

-- ---------------------------------------------------------------- the drawn looks
-- The ceilings each kind keeps to at both tiers (tests/preserve.luau holds them). A meadow cell's look is what reads from a metre or two off: its clumps' masses and the
-- forb's colour at the low tier; at the full tier the grasses whole (every clump's arching blades, the bluestem's turkey-foot racemes and the little bluestem's silver
-- tufts), the forbs drawn whole over their boxes, the thatch and the mown edge. What the spider sees close (the thatch's blades, the new growth, the crumbs and the dew)
-- is the patches'.
Meadow.BUDGETS = table.freeze({
	meadow = { full = 160, low = 8 }, pad = { full = 24, low = 3 }, park_bench = { full = 14, low = 2 }, park_bin = { full = 12, low = 4 }, lamppost = { full = 10, low = 2 },
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
local function rec(id: string, size: Vector3, at: Vector3, color: string, material: string, full: boolean, shape: string?, turn: Vector3?): Drawn
	return { id = id, size = size, at = at, color = hex(color), material = material, full = full, shape = shape, turn = turn }
end
local function drop(id: string, at: Vector3, size: number, rand: () -> number): Drawn
	local d = rec(id, v(size, size * 0.62, size), at + v(0, size * 0.25, 0), "dfeaee", "Glass", true, "Ellipsoid")
	d.group = "Dew"
	d.dew = rand() * 0.6
	d.transparency = between(rand, 0.3, 0.45)
	d.reflectance = 0.3
	return d
end
-- A blade from its foot at `at`: `h` tall, `w` wide, leaning `lean` degrees toward the yaw `yaw`; `bend`, if given, its upper part leans that much more.
local function blade(add: (Drawn) -> boolean, id: string, at: Vector3, h: number, w: number, yaw: number, lean: number, bend: number?, color: string, full: boolean)
	local function seg(sid: string, from: Vector3, len: number, l: number): Vector3
		local r = math.rad(l)
		local dir = v(-math.sin(r) * math.cos(math.rad(yaw)), math.cos(r), math.sin(r) * math.sin(math.rad(yaw)))
		add(rec(sid, v(w, len, 0.06), from + dir * (len / 2), color, "SmoothPlastic", full, nil, v(0, yaw, l)))
		return from + dir * len
	end
	if bend == nil then seg(id, at, h, lean); return end
	local knee = seg(id .. "a", at, h * 0.55, lean)
	seg(id .. "b", knee, h * 0.45, lean + bend)
end
local function yawTo(dx: number, dz: number): number
	return math.deg(math.atan2(-dz, dx))
end
-- A rod from a to b (a raceme, a culm's tip).
local function rod(add: (Drawn) -> boolean, id: string, a: Vector3, b: Vector3, dia: number, color: string, full: boolean, material: string?)
	local d = b - a
	local len = d.Magnitude
	local u = d / len
	add(rec(id, v(len, dia, dia), (a + b) * 0.5, color, material or "SmoothPlastic", full, "Cylinder", v(0, yawTo(u.X, u.Z), math.deg(math.asin(math.clamp(u.Y, -1, 1))))))
end

-- The meadow's own forbs drawn over their boxes.
local function forbDecor(byId: { [string]: Piece }, id: string, plant: { kind: string, x: number, z: number, scale: number? }, add: (Drawn) -> boolean, rand: () -> number)
	local spec = SPECS[plant.kind]
	if spec == nil then
		Hut.drawPlant(byId :: any, id, plant, "", add, rand, GT)
		return
	end
	local base = `{id}_{plant.kind}`
	for i = 1, #spec.leaves do
		local box = byId[`{base}_leaf_{i}`]
		if box ~= nil then
			local size = box.hi - box.lo
			local c = (box.lo + box.hi) * 0.5
			if plant.kind == "yarrow" then
				-- the feathery leaf: a midrib and its fine segments
				local alongX = size.X >= size.Z
				local l = if alongX then size.X else size.Z
				add(rec(`Rachis{i}`, if alongX then v(l * 1.1, 0.12, 0.2) else v(0.2, 0.12, l * 1.1), c + v(0, 0.1, 0), spec.leaf, "SmoothPlastic", true))
				for s = 1, 5 do
					local t = (s - 0.5) / 5 - 0.5
					local off = if alongX then v(t * l, 0.12, 0) else v(0, 0.12, t * l)
					add(rec(`Pinna{i}_{s}`, if alongX then v(0.25, 0.06, 2.6) else v(2.6, 0.06, 0.25), c + off, spec.leaf, "SmoothPlastic", true))
				end
			else
				add(rec(`Leaf_{i}`, if size.X >= size.Z then v(size.X * 1.25, 0.4, size.Z * 1.4) else v(size.X * 1.4, 0.4, size.Z * 1.25), c + v(0, 0.05, 0), spec.leaf, "SmoothPlastic", true, "Ellipsoid"))
			end
		end
	end
	local head = byId[base .. "_head"]
	if head == nil then return end
	local hc = (head.lo + head.hi) * 0.5
	if plant.kind == "susan" then
		-- the rays: thirteen drooping a little round the cone
		for i = 1, 13 do
			local a = i / 13 * TAU + between(rand, -0.08, 0.08)
			add(rec(`Ray{i}`, v(2.9, 0.12, 0.95), v(plant.x + math.cos(a) * 2.6, head.hi.Y - 0.4, plant.z + math.sin(a) * 2.6), pick({ C.susan, "f0b22a", "dc9618" }, rand),
				"SmoothPlastic", true, nil, v(0, -math.deg(a), -16)))
		end
		local cone = byId[base .. "_cone"]
		if cone ~= nil then add(rec("Cone", v(2.6, 2.2, 2.6), (cone.lo + cone.hi) * 0.5 + v(0, -0.1, 0), C.susanCone, "Sand", true, "Ball")) end -- (its top at the box's)
	else
		-- the flat head: florets packed over the box, white with a cream eye
		for i = 1, 22 do
			local r = math.sqrt((i - 0.5) / 22) * 3.1
			local a = i * 2.39996
			add(rec(`Floret{i}`, v(0.75, 0.55, 0.75), v(plant.x + math.cos(a) * r, head.hi.Y + 0.15 - r * 0.05, plant.z + math.sin(a) * r), pick({ C.yarrow, "f2efe6", "e0dccd" }, rand),
				"SmoothPlastic", true, "Ball"))
		end
	end
	if rand() < 0.5 then add(drop("HeadDew", hc + v(between(rand, -1, 1), head.hi.Y - hc.Y + 0.1, between(rand, -1, 1)), 0.4, rand)) end
end

-- A grass clump drawn: its blades arching out from the crown, its culms' heads (the bluestem's three racemes, the little bluestem's silver tufts along the culm's top).
local function clumpDecor(byId: { [string]: Piece }, id: string, k: number, clump: { kind: string, x: number, z: number, dir: number }, add: (Drawn) -> boolean, rand: () -> number)
	local G = GRASS[clump.kind]
	local big = clump.kind == "big"
	local base = `{id}_{clump.kind}{k}`
	local n = if big then 13 else 11
	local spin = between(rand, 0, 360)
	for b = 1, n do
		local yaw = spin + b / n * 360 + between(rand, -20, 20)
		local r = between(rand, 0.4, 2.2)
		local foot = v(clump.x + math.cos(math.rad(yaw)) * r, GT, clump.z - math.sin(math.rad(yaw)) * r)
		local h = if big then between(rand, 32, 62) else between(rand, 22, 40)
		blade(add, `Blade{k}_{b}`, foot, h, if big then between(rand, 0.6, 0.9) else between(rand, 0.3, 0.45), yaw + 180, between(rand, 6, 22),
			if b % 2 == 0 then between(rand, 25, 55) else nil, pick(if big then C.bigLeaf else C.littleLeaf, rand), true)
	end
	-- the bent blade's drawing over its box
	local bentBox = byId[base .. "_blade"]
	if bentBox ~= nil then
		local c = (bentBox.lo + bentBox.hi) * 0.5
		add(rec(`Bent{k}`, v((bentBox.hi.X - bentBox.lo.X) * 1.15, 0.2, 1.2), c + v(0, 0.05, 0), pick(if big then C.bigLeaf else C.littleLeaf, rand), "SmoothPlastic", true, "Ellipsoid"))
	end
	for i = 1, #G.at do
		local head = byId[`{base}_head_{i}`]
		if head ~= nil then
			local top = v((head.lo.X + head.hi.X) / 2, head.lo.Y, (head.lo.Z + head.hi.Z) / 2)
			if big then
				-- the turkey foot: three racemes splayed from the culm's top
				for q = 1, 3 do
					local a = math.rad(spin + q * 120 + i * 40)
					local tip = top + v(math.cos(a) * 1.6, between(rand, 6, 8), math.sin(a) * 1.6)
					rod(add, `Raceme{k}_{i}_{q}`, top, tip, 0.35, pick(C.raceme, rand), true)
				end
			else
				for q = 1, 4 do
					add(rec(`Tuft{k}_{i}_{q}`, v(0.9, 1.3, 0.9), top + v(between(rand, -0.5, 0.5), q * 1.1, between(rand, -0.5, 0.5)), pick(C.tuft, rand), "Fabric", true, "Ellipsoid"))
				end
			end
		end
	end
end

local function meadowDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local id = region.id
	local at = placed(region)
	local byId = byIdOf(region)
	local rand = rng(region.seed, 29)
	local south = string.sub(id, 8, 8) == "a"
	-- the low tier's few: the mown edge, each clump's crown (the dense foot of a bunchgrass, its leaves' bases; the full tier arches the blades out of it) and the ant
	-- hill's mound (the forbs' heads are their own boxes' colours)
	if south then add(rec("Mown", v(hi.X - lo.X, 0.1, 20), v((lo.X + hi.X) / 2, GT + 0.05, hi.Z - 10), C.mown[1], "Grass", false)) end
	for k, clump in at.clumps do
		local big = clump.kind == "big"
		add(rec(`Crown{k}`, v(if big then 20 else 14, if big then 14 else 9, if big then 20 else 14), v(clump.x, GT + (if big then 3.5 else 2.2), clump.z),
			pick(if big then C.bigLeaf else C.littleLeaf, rand), "LeafyGrass", false, "Ellipsoid"))
	end
	if at.hill ~= nil then add(rec("Hill", v(34, 9, 34), v(at.hill.x, GT + 2.5, at.hill.z), C.hill, "Ground", false, "Ellipsoid")) end
	if at.leaf ~= nil then
		local L = Meadow.LEAF
		add(rec("CurledLeaf", v(L.l + 1, 3.2, L.w + 1), v(at.leaf.x, GT + L.gap + 0.9, at.leaf.z), C.leaf, "Fabric", false, "Ellipsoid", v(0, 15, 0)))
		add(rec("LeafCurl", v(L.l, 1.2, 2.2), v(at.leaf.x, GT + L.gap + 2.0, at.leaf.z - L.w / 2 + 0.6), C.leafDark, "Fabric", true, "Cylinder", v(0, 15, 0)))
		add(rec("LeafVein", v(L.l * 0.9, 0.1, 0.25), v(at.leaf.x, GT + L.gap + L.thick + 0.1, at.leaf.z), "a08454", "Fabric", true, nil, v(0, 15, 0)))
	end
	-- the full tier: the forb and the grasses whole, then the thatch and the floor's mottle
	if at.forb ~= nil then forbDecor(byId, id, at.forb, add, rand) end
	for k, clump in at.clumps do clumpDecor(byId, id, k, clump, add, rand) end
	if south then
		for i = 1, 6 do
			add(rec(`MownTuft{i}`, v(between(rand, 4, 8), between(rand, 1.5, 3), between(rand, 3, 6)), v(between(rand, lo.X + 4, hi.X - 4), GT + 1, between(rand, hi.Z - 18, hi.Z - 2)),
				pick(C.mown, rand), "Grass", true, "Ellipsoid"))
		end
	end
	for i = 1, 12 do
		local x, z = between(rand, lo.X + 3, hi.X - 3), between(rand, lo.Z + 3, hi.Z - 3)
		local w = between(rand, 8, 18)
		add(rec(`Thatch{i}`, v(w, 0.25, w * between(rand, 0.4, 0.8)), v(x, GT + 0.1, z), pick(C.thatch, rand), "Grass", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	for i = 1, 6 do
		local x, z = between(rand, lo.X + 5, hi.X - 5), between(rand, lo.Z + 5, hi.Z - 5)
		add(rec(`Bare{i}`, v(between(rand, 4, 9), 0.08, between(rand, 3, 7)), v(x, GT + 0.04, z), C.soil, "Ground", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	-- a few dead stems of last year leaning in the grass
	for i = 1, 3 do
		local x, z = between(rand, lo.X + 15, hi.X - 15), between(rand, lo.Z + 15, hi.Z - 15)
		local h = between(rand, 40, 80)
		blade(add, `Dead{i}`, v(x, GT, z), h, 0.35, between(rand, 0, 360), between(rand, 15, 35), nil, pick(C.thatch, rand), true)
	end
end

local function padDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local rand = rng(region.seed, 7)
	local id = region.id
	if id == "pad_b3" then
		local G = Meadow.GRATE
		add(rec("PitDark", v(G.x1 - G.x0 - 4.2, 0.1, G.z1 - G.z0 - 4.2), v((G.x0 + G.x1) / 2, GT - G.deep + 0.05, (G.z0 + G.z1) / 2), "1e1c19", "Mud", false))
		add(rec("PitLeaf", v(5, 0.1, 3), v(G.x0 + 10, GT - G.deep + 0.2, G.z0 + 9), C.leafDark, "Fabric", true, "Ellipsoid", v(0, 30, 0)))
		add(rec("PitWater", v(14, 0.06, 10), v(G.x0 + 18, GT - G.deep + 0.1, G.z0 + 18), "3e4a4a", "Glass", true, "Ellipsoid"))
	end
	-- the slab's joints and a lichen spot or two
	local S = Meadow.SLAB
	local a, b, c, d = clip(S.x0, S.x1, S.z0, S.z1, lo.X, hi.X, lo.Z, hi.Z)
	if a ~= nil then
		local x = math.ceil((a :: number) / 60) * 60
		local k = 0
		while x < (b :: number) - 1 do
			k += 1
			add(rec(`Joint{k}`, v(0.4, 0.04, (d :: number) - (c :: number)), v(x, SL + 0.02, ((c :: number) + (d :: number)) / 2), C.concreteDark, "Concrete", false))
			x += 60
		end
		for i = 1, 2 do
			add(rec(`Lichen{i}`, v(between(rand, 1.5, 3), 0.05, between(rand, 1.2, 2.6)), v(between(rand, a :: number, b :: number), SL + 0.03, between(rand, c :: number, d :: number)),
				pick({ "b8b88a", "9aa078", "c9c49a" }, rand), "SmoothPlastic", true, "Ellipsoid"))
		end
	end
	-- the city in the gravel: a bottle cap, a ring-pull, a cigarette end, a few bigger stones and a fallen leaf
	local things: { { any } } = {
		{ "Cap", v(2.6, 0.6, 2.6), "c9302a", "Metal", "Cylinder" }, { "RingPull", v(2.2, 0.1, 1.2), "c9cdd0", "Metal", false }, { "Butt", v(2.8, 0.75, 0.75), "e8dcc0", "Fabric", "Cylinder" },
	}
	if rand() < 0.6 then
		local t = pick(things, rand)
		local s = t[2] :: Vector3
		local x, z = between(rand, lo.X + 8, hi.X - 8), between(rand, lo.Z + 8, hi.Z - 8)
		local top = if x > S.x0 and x < S.x1 and z > S.z0 and z < S.z1 then SL else GT
		add(rec(t[1] :: string, s, v(x, top + s.Y / 2, z), t[3] :: string, t[4] :: string, true, if t[5] then t[5] :: string else nil,
			if t[5] == "Cylinder" then v(0, between(rand, 0, 180), 90) else v(0, between(rand, 0, 180), 0)))
	end
	for i = 1, 6 do
		local s = between(rand, 0.8, 2.2)
		local x, z = between(rand, lo.X + 3, hi.X - 3), between(rand, lo.Z + 3, hi.Z - 3)
		local top = if x > S.x0 and x < S.x1 and z > S.z0 and z < S.z1 then SL else GT
		add(rec(`Stone{i}`, v(s, s * 0.6, s * between(rand, 0.7, 1.2)), v(x, top + s * 0.2, z),
			pick({ C.gravel, C.gravelDark, "c9bfa8", "8f8676" }, rand), "Pebble", i > 1, "Ellipsoid"))
	end
	local lx, lz = between(rand, lo.X + 10, hi.X - 10), between(rand, lo.Z + 10, hi.Z - 10)
	add(rec("FallenLeaf", v(5, 0.08, 3.5), v(lx, (if lx > S.x0 and lx < S.x1 and lz > S.z0 and lz < S.z1 then SL else GT) + 0.05, lz), pick({ "b0702a", "8a6a3a", "c09a3a" }, rand), "Fabric", true, "Ellipsoid",
		v(0, between(rand, 0, 180), 0)))
end

local function benchDecor(region: Region, add: (Drawn) -> boolean)
	local west = region.id == "bench_w"
	local x0, x1 = if west then B.x0 else B.mid, if west then B.mid else B.x1
	-- the arm's scroll and the leg's foot, cast iron (low: the arm), the slats' grain and their screws
	local fx = (if west then B.ends[1] else B.ends[2]) + B.frame / 2
	add(rec("Scroll", v(B.frame + 0.6, 8, 8), v(fx, SL + B.arm[1] - 2, B.armPost[2] + 2), C.ironDark, "Metal", false, "Ellipsoid"))
	add(rec("Foot", v(B.frame + 1, 1.5, 8), v(fx, SL + 0.75, B.front - 2), C.ironDark, "Metal", true, "Ellipsoid"))
	for k, s in SLATS do
		add(rec(`Grain{k}`, v(x1 - x0 - 2, 0.03, 0.25), v((x0 + x1) / 2, SL + B.seat + 0.015, (s[1] + s[2]) / 2 + 1.5), "6a4a2a", "Wood", true))
		add(rec(`Screw{k}`, v(0.8, 0.12, 0.8), v(fx, SL + B.seat + 0.06, (s[1] + s[2]) / 2), "4a4a48", "Metal", true, "Cylinder", v(0, 0, 90)))
	end
	if not west then add(rec("Plaque", v(12, 3.2, 0.2), v(-60, SL + (B.back[2][1] + B.back[2][2]) / 2, B.backZ[2] + 0.1), "b08a3c", "Metal", true)) end
end

local function binDecor(_region: Region, add: (Drawn) -> boolean)
	local N, K, Q = Meadow.BIN, Meadow.CAN, Meadow.PACKET
	add(rec("Slot", v(30, 0.1, 8), v((N.x0 + N.x1) / 2, SL + N.lid + 0.05, N.z1 - 8), "101010", "SmoothPlastic", false))
	add(rec("Can", v(K.x1 - K.x0, K.z1 - K.z0, K.z1 - K.z0), v((K.x0 + K.x1) / 2, GT + (K.z1 - K.z0) / 2, (K.z0 + K.z1) / 2), C.can, "Metal", false, "Cylinder"))
	add(rec("CanEnd", v(0.3, 6.2, 6.2), v(K.x1 + 0.1, GT + (K.z1 - K.z0) / 2, (K.z0 + K.z1) / 2), C.canTop, "Metal", true, "Cylinder"))
	add(rec("Packet", v(Q.x1 - Q.x0 + 1, Q.h * 1.3, Q.z1 - Q.z0 + 1), v((Q.x0 + Q.x1) / 2, GT + Q.h / 2, (Q.z0 + Q.z1) / 2), C.packet, "SmoothPlastic", false, "Ellipsoid", v(0, 12, 0)))
	add(rec("PacketFoil", v(5, 0.6, 4), v(Q.x0 + 4, GT + Q.h + 0.1, Q.z0 + 3), C.packetFoil, "Metal", true, "Ellipsoid", v(0, 30, 8)))
	add(rec("PacketFold", v(Q.x1 - Q.x0 - 2, 0.6, 1), v((Q.x0 + Q.x1) / 2, GT + Q.h + 0.2, Q.z1 - 2), "b8861e", "SmoothPlastic", true, nil, v(0, 12, 6)))
	add(rec("Band", v(N.x1 - N.x0 + 0.4, 3, N.z1 - N.z0 + 0.4), v((N.x0 + N.x1) / 2, SL + 60, (N.z0 + N.z1) / 2), "c9a227", "Metal", true))
end

local function lampDecor(region: Region, add: (Drawn) -> boolean)
	local L = Meadow.LAMP
	if region.id == "lamp_4" then
		-- the bulb inside the glass (it glows; Client/HutLife lights the lantern at dusk) and the glass's corner bars
		add(rec("Bulb", v(5, 7, 5), Meadow.LANTERN.at, "fff1c8", "Neon", false, "Ball"))
		for k, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			add(rec(`Bar{k}`, v(0.8, L.glass.h, 0.8), v(L.x + c[1] * L.glass.half, LAMP_TOP + L.plate.h + L.glass.h / 2, L.z + c[2] * L.glass.half), C.iron, "Metal", true))
		end
		add(rec("CapRoof", v(L.cap.half * 2, 5, L.cap.half * 2), v(L.x, LAMP_TOP + L.plate.h + L.glass.h + L.cap.h + 1.5, L.z), C.iron, "Metal", true, "Ellipsoid"))
	elseif region.id == "lamp_1" then
		add(rec("Door", v(0.2, 18, 6), v(L.x + L.half + 0.1, SL + 40, L.z), "2a2d2f", "Metal", true))
		add(rec("Sticker", v(0.15, 5, 4), v(L.x - L.half - 0.08, SL + 60, L.z + 1), "e8e2d0", "SmoothPlastic", false))
	end
end

-- ---------------------------------------------------------------- the patches: what the spider sees close
-- Each meadow cell and each pad cell is cut into patches of World/Hut.PATCH studs (kind "patch", drawn only near the spider, World/LookPlan): in the meadow the thatch at
-- true size (dead blades lying in layers, 2 to 8 cm), the new growth coming up through it (short green blades), crumbs of soil, seeds, fallen florets under the flowers and
-- the morning's dew; on the mown edge, short cut tufts; on the gravel, its stones; on the slab, its grit.
local PATCHED: { [string]: boolean } = { meadow = true, pad = true }
local patchParent: { [string]: Region } = {}
function Meadow.patches(regions: { Region }, worldSeed: number, seedOf: (number, string) -> number): { Region }
	local out: { Region } = {}
	local size = Hut.PATCH
	for _, r in regions do
		if PATCHED[r.kind] then
			local lo, hi = r.bounds[1], r.bounds[2]
			local nx = math.max(1, math.ceil((hi.X - lo.X) / size - 1e-6))
			local nz = math.max(1, math.ceil((hi.Z - lo.Z) / size - 1e-6))
			local dx, dz = (hi.X - lo.X) / nx, (hi.Z - lo.Z) / nz
			for i = 1, nx do
				for j = 1, nz do
					local pid = `{r.id}~{i}_{j}`
					local plo, phi = v(lo.X + (i - 1) * dx, GT - 2, lo.Z + (j - 1) * dz), v(lo.X + i * dx, GT + 40, lo.Z + j * dz)
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
-- The region a patch of the meadow's belongs to (nil for one that is not the meadow's: World/Hut's).
function Meadow.patchParent(patch: Region): Region?
	return patchParent[patch.id]
end

local THATCH = { "b8a77a", "a89766", "c2b38a", "9c8b5e", "b09f70", "8f7f56", "c9b98e" }
local GREEN = { "6f9a46", "5f8a3e", "7d9a4e", "86a85a", "6a8a4a" }
local STONES = { "b3a68a", "938870", "c9bfa8", "8f8676", "a69a80", "d1c7b0", "7d7466", "bfae92" }

-- The standing boxes on a cell's floor (what the near detail keeps clear of).
local function standing(region: Region): { Box }
	local out: { Box } = {}
	for _, p in Meadow.pieces(region) do
		if p.lo.Y <= GT + 0.6 and p.hi.Y > GT + 0.05 and not string.find(p.id, "_soil", 1, true) and not string.find(p.id, "_gravel", 1, true) then
			table.insert(out, { min = p.lo, max = p.hi })
		end
	end
	return out
end
local function clear(boxes: { Box }, x: number, z: number, m: number): boolean
	for _, b in boxes do
		if x > b.min.X - m and x < b.max.X + m and z > b.min.Z - m and z < b.max.Z + m then return false end
	end
	return true
end

local function patchDecor(patch: Region, add: (Drawn) -> boolean)
	local parent = patchParent[patch.id]
	if parent == nil then return end
	local lo, hi = patch.bounds[1], patch.bounds[2]
	local rand = rng(patch.seed, 43)
	local boxes = standing(parent)
	local pad = parent.kind == "pad"
	local mownTo = if string.sub(parent.id, 1, 8) == "meadow_a" then parent.bounds[2].Z - 20 else math.huge -- (the mown edge: z over this)
	local spots: { Vector3 } = {}
	for i = 1, 5 do
		for j = 1, 5 do
			table.insert(spots, v(lo.X + (i - 1 + between(rand, 0.15, 0.85)) * (hi.X - lo.X) / 5, 0, lo.Z + (j - 1 + between(rand, 0.15, 0.85)) * (hi.Z - lo.Z) / 5))
		end
	end
	for i = #spots, 2, -1 do
		local j = 1 + math.floor(rand() * i) % i
		spots[i], spots[j] = spots[j], spots[i]
	end
	local S = Meadow.SLAB
	local k = 0
	local function onSlab(x: number, z: number): boolean
		return x > S.x0 and x < S.x1 and z > S.z0 and z < S.z1
	end
	local function stone(x: number, z: number, full: boolean)
		k += 1
		local s = between(rand, 0.2, 0.9)
		local top = if onSlab(x, z) then SL else GT
		add(rec(`Stone{k}`, v(s, s * between(rand, 0.55, 0.85), s * between(rand, 0.75, 1.15)), v(x, top + s * 0.2, z), pick(STONES, rand), "Pebble", full, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	local function thatchBlade(x: number, z: number, full: boolean)
		k += 1
		local l = between(rand, 2, 8)
		add(rec(`Thatch{k}`, v(l, 0.06, between(rand, 0.25, 0.55)), v(x, GT + between(rand, 0.05, 0.6), z), pick(THATCH, rand), "SmoothPlastic", full, nil,
			v(between(rand, -8, 8), between(rand, 0, 180), between(rand, -6, 6))))
	end
	local function sprout(x: number, z: number, full: boolean, short: boolean)
		k += 1
		local spin = between(rand, 0, 360)
		for b = 1, 3 do
			blade(add, `Sprout{k}_{b}`, v(x + between(rand, -0.4, 0.4), GT, z + between(rand, -0.4, 0.4)), if short then between(rand, 2, 4) else between(rand, 4, 12),
				between(rand, 0.25, 0.45), spin + b * 120, between(rand, 4, 20), nil, pick(GREEN, rand), full or b > 1)
		end
	end
	-- the low tier's few
	for s = 1, 3 do
		local p = spots[s]
		if clear(boxes, p.X, p.Z, 1.5) then
			if pad then stone(p.X, p.Z, false); stone(p.X + 1.5, p.Z - 1, false)
			elseif p.Z > mownTo then sprout(p.X, p.Z, false, true)
			else thatchBlade(p.X, p.Z, false); if s == 1 then sprout(p.X + 1, p.Z, false, false) end end
		end
	end
	-- under the forb: what falls from it
	local at = if pad then nil else placed(parent)
	if at ~= nil and at.forb ~= nil then
		local f = at.forb
		for i = 1, 5 do
			local a, r = between(rand, 0, TAU), between(rand, 3, 12)
			local x, z = f.x + math.cos(a) * r, f.z + math.sin(a) * r
			if x > lo.X and x < hi.X and z > lo.Z and z < hi.Z and clear(boxes, x, z, 0.5) then
				local colors = { susan = "e0a020", yarrow = "e8e4d8", coneflower = "a85f84", milkweed = "b88a8e", goldenrod = "c9a22e", beebalm = "9a7aa6" } :: { [string]: string }
				add(rec(`Fallen{i}`, v(0.7, 0.3, 0.6), v(x, GT + 0.3, z), colors[f.kind] or "c9a22e", "SmoothPlastic", true, "Ball"))
			end
		end
	end
	-- the rest, spot by spot, to the budget
	local dews = 0
	for pass = 1, 5 do
		for s, p in spots do
			local x, z = p.X + between(rand, -2.2, 2.2) * (pass - 1), p.Z + between(rand, -2.2, 2.2) * (pass - 1)
			if clear(boxes, x, z, 1.2) then
				if pad then
					for _ = 1, 3 do stone(x + between(rand, -2.4, 2.4), z + between(rand, -2.4, 2.4), true) end
				elseif z > mownTo then
					if (s + pass) % 2 == 0 then sprout(x, z, true, true) else thatchBlade(x, z, true) end
				else
					local roll = rand()
					if roll < 0.45 then
						for _ = 1, 2 do thatchBlade(x + between(rand, -1.5, 1.5), z + between(rand, -1.5, 1.5), true) end
					elseif roll < 0.75 then sprout(x, z, true, false)
					elseif roll < 0.85 then
						k += 1
						add(rec(`Crumb{k}`, v(1.0, 0.4, 0.8), v(x, GT + 0.15, z), "5a4a34", "Ground", true, "Ellipsoid"))
					elseif roll < 0.92 then
						k += 1
						add(rec(`Seed{k}`, v(0.5, 0.25, 0.3), v(x, GT + 0.3, z), pick({ "6a5a3a", "8a7a52", "3a3024" }, rand), "SmoothPlastic", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
					elseif dews < 3 then
						dews += 1
						add(drop(`Dew{dews}`, v(x, GT + between(rand, 1, 5), z), between(rand, 0.3, 0.55), rand))
					end
				end
			end
		end
	end
end

local decorCache: { [string]: { Drawn } } = {}
-- The region's drawn records (or a patch of the meadow's), within its kind's budget at both tiers; the same list for the same region.
function Meadow.decor(region: Region): { Drawn }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = decorCache[key]
	if cached ~= nil then return cached end
	local budget = if region.kind == "patch" then Hut.BUDGETS.patch else Meadow.BUDGETS[region.kind]
	assert(budget ~= nil, "no budget for the region kind " .. region.kind)
	local list, add = sheet(budget)
	local k = region.kind
	if k == "meadow" then meadowDecor(region, add)
	elseif k == "pad" then padDecor(region, add)
	elseif k == "park_bench" then benchDecor(region, add)
	elseif k == "park_bin" then binDecor(region, add)
	elseif k == "lamppost" then lampDecor(region, add)
	elseif k == "patch" then patchDecor(region, add) end
	for _, d in list do table.freeze(d) end
	decorCache[key] = table.freeze(list)
	return list
end

-- ---------------------------------------------------------------- the life
-- The bestiary's kinds where they live here (the hut garden's profiles, Data/Species): leafhoppers on the bluestem's culms (Hut's pairs either side of a culm), house flies
-- (the sill's own profile) and hoverflies on the flower heads, small moths resting on the grass heads by day and restless from dusk, house flies at the bin, and moths
-- at the lamp's lantern. The ants at their hill (ambient, Prey/Ant). From each region's own seed by streams of their own.
Meadow.LIFE = table.freeze({
	leafhoppers = { meadow_a3 = { full = 2, low = 1 }, meadow_c2 = { full = 2, low = 1 }, meadow_d3 = { full = 2, low = 1 }, meadow_e4 = { full = 1, low = 1 } },
	hoverflies = { meadow_a3 = { full = 1, low = 1 }, meadow_b5 = { full = 1, low = 1 }, meadow_c4 = { full = 1, low = 1 }, meadow_d2 = { full = 1, low = 1 } },
	houseflies = { meadow_c1 = { full = 1, low = 1 }, meadow_e5 = { full = 1, low = 1 }, meadow_a1 = { full = 1, low = 1 }, bin = { full = 2, low = 1 } },
	moths = { meadow_d1 = { full = 1, low = 1 }, meadow_e2 = { full = 1, low = 1 }, lamp_4 = { full = 2, low = 1 } },
	ants = { meadow_b4 = { full = 6, low = 3, salt = 151 } },
})

export type Perch = Hut.Perch
local function spot(p: Vector3, n: Vector3, sh: number, fo: number): { any }
	return { p, n, sh, fo }
end
local function spots(region: Region, kind: string, list: { { any } }, starts: number): { Perch }
	local out: { Perch } = {}
	for i, sp in list do
		table.insert(out, { id = `{region.id}_{kind}_{i}`, position = sp[1], normal = sp[2], shelter = sp[3], food = sp[4], start = i <= starts, kind = "leaf" } :: any)
	end
	return out
end
-- A head's top middle, of a piece.
local function topOf(p: Piece): Vector3
	return v((p.lo.X + p.hi.X) / 2, p.hi.Y, (p.lo.Z + p.hi.Z) / 2)
end

local bestiaryCache: { [string]: any } = {}
function Meadow.bestiary(region: Region): { any }?
	local L = Meadow.LIFE
	local hopper, hover, house, moth = L.leafhoppers[region.id], L.hoverflies[region.id], L.houseflies[region.id], L.moths[region.id]
	if hopper == nil and hover == nil and house == nil and moth == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if bestiaryCache[key] ~= nil then return bestiaryCache[key] end
	local out = {}
	local byId = byIdOf(region)
	local at = if region.kind == "meadow" then placed(region) else nil
	-- the flowers' heads and the forb's upper leaves, the grasses' heads: where flies and moths sit
	local function flowerSpots(): { { any } }
		local list: { { any } } = {}
		if at ~= nil and at.forb ~= nil then
			local base = `{region.id}_{at.forb.kind}`
			local head = byId[base .. "_cone"] or byId[base .. "_head"]
			if head ~= nil then table.insert(list, spot(topOf(head), Vector3.yAxis, 0.2, 0.9)) end
			for i = 8, 1, -1 do
				local leaf = byId[`{base}_leaf_{i}`]
				if leaf ~= nil and #list < 4 then table.insert(list, spot(topOf(leaf), Vector3.yAxis, 0.3, 0.5)) end
			end
		end
		return list
	end
	local function grassHeads(): { { any } }
		local list: { { any } } = {}
		for _, p in Meadow.pieces(region) do
			if string.find(p.id, "_head_", 1, true) ~= nil and #list < 5 then table.insert(list, spot(topOf(p), Vector3.yAxis, 0.3, 0.3)) end
		end
		for _, p in Meadow.pieces(region) do
			if string.sub(p.id, -6) == "_blade" and #list < 7 then table.insert(list, spot(topOf(p) + v(0, 0, 0), Vector3.yAxis, 0.4, 0.2)) end
		end
		return list
	end
	if hopper ~= nil and at ~= nil then
		-- in pairs either side of the first big clump's first culm, low and high (Hut's leafhoppers: a hop round the culm to its far side)
		local salt = 73
		local k = 0
		for i, c in at.clumps do if c.kind == "big" and k == 0 then k = i end end
		local culm = byId[`{region.id}_big{k}_culm_1`]
		if culm ~= nil then
			local perches: { Perch } = {}
			local n = 0
			local function pair(a: Vector3, na: Vector3, b: Vector3, nb: Vector3, round: Vector3, start: boolean)
				n += 1
				local ia, ib = `{region.id}_leafhopper_{n}a`, `{region.id}_leafhopper_{n}b`
				table.insert(perches, { id = ia, position = a, normal = na, shelter = 0.4, food = 0.6, start = start, kind = "stem", hop = true, behind = ib, round = round } :: any)
				table.insert(perches, { id = ib, position = b, normal = nb, shelter = 0.4, food = 0.6, start = false, kind = "stem", hop = true, behind = ia, round = round } :: any)
			end
			local mx, mz = (culm.lo.X + culm.hi.X) / 2, (culm.lo.Z + culm.hi.Z) / 2
			for q, h in { 14, 36, 62 } do
				local y = GT + h
				if q % 2 == 1 then pair(v(culm.hi.X, y, mz), Vector3.xAxis, v(culm.lo.X, y, mz), -Vector3.xAxis, v(mx, y, culm.hi.Z + 0.35), q == 1)
				else pair(v(mx, y, culm.hi.Z), Vector3.zAxis, v(mx, y, culm.lo.Z), -Vector3.zAxis, v(culm.hi.X + 0.35, y, mz), false) end
			end
			local vents = { { id = `{culm.id}_vent_leafhopper`, position = v(mx, GT, culm.lo.Z - 1.5), normal = Vector3.yAxis, appear = true, reach = 60 } }
			table.insert(out, { kind = "leafhopper", profile = "leafhopper_prototype", perches = perches, vents = vents, target = hopper.full, low = hopper.low,
				seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_leafhopper_fly_` })
		end
	end
	if hover ~= nil then
		local list = flowerSpots()
		if #list > 0 then
			local salt = 113
			local first = list[1][1] :: Vector3
			table.insert(out, { kind = "hoverfly", profile = "hoverfly_prototype", perches = spots(region, "hoverfly", list, hover.full),
				vents = { { id = `{region.id}_vent_hoverfly`, position = first + v(0, 16, 0), normal = Vector3.yAxis, appear = true, reach = 80 } }, target = hover.full, low = hover.low,
				seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_hoverfly_fly_` })
		end
	end
	if house ~= nil then
		local list: { { any } }
		local vent: Vector3
		if region.id == "bin" then
			-- at the bin: on its lid round the slot, its rim, the can and the packet
			local N, K, Q = Meadow.BIN, Meadow.CAN, Meadow.PACKET
			list = {
				spot(v(N.x0 + 8, SL + N.lid, N.z0 + 8), Vector3.yAxis, 0.2, 0.6), spot(v(N.x1 - 8, SL + N.lid, N.z0 + 12), Vector3.yAxis, 0.2, 0.6),
				spot(v(N.x0 - 1, SL + N.top + 1.5, (N.z0 + N.z1) / 2), -Vector3.xAxis, 0.2, 0.5), spot(v(N.x1 + 1, SL + N.top + 1.5, N.z0 + 10), Vector3.xAxis, 0.2, 0.5),
				spot(v(58, GT + (K.z1 - K.z0), (K.z0 + K.z1) / 2), Vector3.yAxis, 0.1, 0.8), spot(v(K.x1, GT + 3.3, (K.z0 + K.z1) / 2), Vector3.xAxis, 0.1, 0.8),
				spot(v(25, GT + Q.h, -1021), Vector3.yAxis, 0.1, 0.8),
			}
			vent = v(60, SL + N.lid + 12, -1074)
		else
			list = flowerSpots()
			vent = (if #list > 0 then list[1][1] :: Vector3 else region.origin) + v(0, 16, 0)
			-- (a house fly starts on a leaf and comes to the head later: some heads' perches have no clear flight to the leaves under them)
			if #list > 1 then table.insert(list, table.remove(list, 1) :: any) end
		end
		if #list > 0 then
			local salt = 137
			table.insert(out, { kind = "housefly", profile = "fly_like_prototype", perches = spots(region, "housefly", list, house.full),
				vents = { { id = `{region.id}_vent_housefly`, position = vent, normal = Vector3.yAxis, appear = true, reach = 80 } }, target = house.full, low = house.low,
				seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_housefly_fly_` })
		end
	end
	if moth ~= nil then
		local list: { { any } }
		local vent: Vector3
		if region.id == "lamp_4" then
			-- at the lantern: on its glass, under its cap, on the pole under it
			local Lm = Meadow.LAMP
			local g0 = LAMP_TOP + Lm.plate.h
			-- (in pairs on a face of the glass: a flight round the lantern's corner or over its cap is not clear, one along a face is)
			list = {
				spot(v(Lm.x + Lm.glass.half, g0 + 14, Lm.z - 3), Vector3.xAxis, 0.2, 0.2), spot(v(Lm.x + Lm.glass.half, g0 + 7, Lm.z + 5), Vector3.xAxis, 0.2, 0.2),
				spot(v(Lm.x + 2, g0 + 18, Lm.z + Lm.glass.half), Vector3.zAxis, 0.2, 0.2), spot(v(Lm.x - 5, g0 + 9, Lm.z + Lm.glass.half), Vector3.zAxis, 0.2, 0.2),
				spot(v(Lm.x - Lm.glass.half, g0 + 9, Lm.z + 4), -Vector3.xAxis, 0.2, 0.2), spot(v(Lm.x - Lm.glass.half, g0 + 17, Lm.z - 5), -Vector3.xAxis, 0.2, 0.2),
			}
			vent = Meadow.LANTERN.at + v(0, 4, 24)
		else
			list = grassHeads()
			vent = region.origin + v(0, 90, 0)
		end
		if #list > 0 then
			local salt = 131
			table.insert(out, { kind = "moth", profile = "moth_prototype", perches = spots(region, "moth", list, moth.full),
				vents = { { id = `{region.id}_vent_moth`, position = vent, normal = Vector3.yAxis, appear = true, reach = 60 } }, target = moth.full, low = moth.low,
				seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_moth_fly_`, dusk = { from = 18.0, to = 6.0 } })
		end
	end
	-- (the band each kind's flights climb in: from under its lowest perch to 11 cm over its highest, PerchGraph.plan; the sill's 0 to 11 would send them down to it)
	for _, k in out do
		local lo, hi = math.huge, -math.huge
		for _, p in k.perches do lo, hi = math.min(lo, p.position.Y), math.max(hi, p.position.Y) end
		k.floor, k.ceiling = lo - 2, hi + 11
	end
	bestiaryCache[key] = out
	return out
end

local ambientCache: { [string]: any } = {}
-- The ants of the hill (Prey/Ant): their starts round the hill on the meadow's floor, the hill's foot their way in (`home`), the boxes they walk round.
function Meadow.ambient(region: Region): { any }?
	local row = Meadow.LIFE.ants[region.id]
	if row == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if ambientCache[key] ~= nil then return ambientCache[key] end
	local at = placed(region)
	local hill = at.hill :: { x: number, z: number }
	local foot = Meadow.HILL.steps[1][1]
	local rand = rng(region.seed, row.salt)
	local spec: any = { kind = "ant", seed = (region.seed + row.salt * 104729) % MOD, full = row.full, low = row.low, starts = {}, prefix = region.id .. "_", surface = "soil",
		home = v(hill.x, GT, hill.z + foot + 0.8), centre = v(hill.x, GT, hill.z), range = 45 }
	local boxes = standing(region)
	for i = 1, row.full do
		for _ = 1, 30 do
			local a, r = between(rand, 0, TAU), between(rand, foot + 3, foot + 30)
			local x, z = hill.x + math.cos(a) * r, hill.z + math.sin(a) * r
			if clear(boxes, x, z, 1.0) then
				local h = between(rand, 0, TAU)
				table.insert(spec.starts, { pos = v(x, GT, z), heading = v(math.cos(h), 0, math.sin(h)) })
				break
			end
		end
		local _ = i
	end
	local out = { spec }
	ambientCache[key] = out
	return out
end

-- The regions the rival roams here beyond the hut garden's (Predator/RivalSpider.roam): the garden's path north (World/Hut's path_m1..m4), the bench patch's gravel
-- (not the drain's cell, nor the furniture) and the meadow's first row along the gravel. The mate keeps to the garden.
local ROAM: { [string]: boolean } = { path_m1 = true, path_m2 = true, path_m3 = true, path_m4 = true }
for _, id in { "pad_a1", "pad_a2", "pad_a3", "pad_b1", "pad_b2", "pad_c1", "pad_c2", "pad_c3" } do ROAM[id] = true end
for c = 1, 5 do ROAM[`meadow_a{c}`] = true end
Meadow.ROAM = table.freeze(ROAM)

-- ---------------------------------------------------------------- the crab spiders' flowers (Predator/CrabSpider)
-- Each crab spider has two flowers it may sit on, one a day (its own seeded draw): the goldenrod spider's two goldenrod plumes (it is yellow), the yarrow spider's two yarrow
-- heads (it is white): `form` its colour.
export type CrabSite = { region: string, piece: string, form: string }
local function crabSite(cell: string, kind: string, form: string): CrabSite
	return table.freeze({ region = "meadow_" .. cell, piece = `meadow_{cell}_{kind}_head`, form = form })
end
Meadow.CRAB_SITES = table.freeze({
	table.freeze({ crabSite("c3", "goldenrod", "yellow"), crabSite("e3", "goldenrod", "yellow") }),
	table.freeze({ crabSite("d4", "yarrow", "white"), crabSite("a2", "yarrow", "white") }),
})
-- A site's place, from its region's boxes: the head's top middle.
function Meadow.crabAt(site: CrabSite, regions: { Region }): (Vector3, Piece?)
	for _, r in regions do
		if r.id == site.region then
			for _, p in Meadow.pieces(r) do
				if p.id == site.piece then return topOf(p), p end
			end
		end
	end
	return Vector3.zero, nil
end

return Meadow
