--!strict
-- The pond's edge and the boardwalk, walkable (ROBLOX-122, docs/PARK_WORLD_DESIGN.md Phase D round 1): home range 4 at full spider detail where the boardwalk runs
-- along the pond's south side, and the corridor that joins it to the meadow: the mown path from the bench patch's gravel east and north to the boardwalk's west end,
-- and the boardwalk on to the pond. Pure data and pure generators, as World/Hut's and World/Meadow's are: the regions (`author`), their physical boxes (`pieces`),
-- their drawn looks (`decor`), their near detail (`patches`), the water (`WATER`, `waterline`, `inWater`), the life they hold (`bestiary`, `ambient`), the frog's
-- seats (`FROG_SITES`) and the dragonfly's beat (`darner`), all from the region and its seed, so the server, every client and the CLI tests get the same pond.
-- Nothing here requires World/WorldMap or World/Garden.
--
-- Studs, the sill's frame (World/Preserve: x east, -z north, a stud a centimetre; the ground GROUND as the meadow's and the hut garden's). True scale.
--
-- The corridor (walkable at a coarser detail, docs/PARK_WORLD_DESIGN.md section 3):
--   mown_e1..e2 ...... two metres east from the bench patch's gravel (pad_b3), x 90..290, z -730..-630.
--   mown_n1 .......... 86 cm north from there, x 190..290, to the boardwalk's south face at z -816.
--   walk_s1..s4, ..... the boardwalk from its west end (x 190) to the core (x 525): a deck 1.5 m wide of boards 14 cm wide laid along it with gaps between, 40 cm
--   walk_n1..n4        over the ground on its fascia, beams and posts, a low kerb rail along each edge on spacer blocks; in two rows (the south five boards and the north
--                      five), each whole inside the streaming radius. A spider climbs its south fascia from the path.
-- The pond's edge (home range 4, 4 by 4 m: x 525..925, z -816..-1216), the boardwalk on its south side and the margin north
-- of it, where the pond's south shore (World/Preserve.POND's ellipse) runs from the north-west to the south-east, so the west is bank and the east is water:
--   deck_s1..s4, ..... the boardwalk on over the bank and the water's edge (the same deck), its posts down to the mud or the pond's bed.
--   deck_n1..n4
--   pond_a1..c4 ...... twelve cells of the margin (rows a to c north from the boardwalk, 100, 100 and 50 deep; columns 1 to 4 west to east): the mud bank in strips
--                      (STRIP wide) stepping down to the waterline (GROUND, then damp mud 3 cm lower, then the wet margin a centimetre over the water), the water
--                      (WATER, 6 cm under the lawn: no box, a spider cannot stand on it; Life/Water), the pond's bed under it; wet stones at the margin, sedge and soft
--                      rush, two stands of cattails, lily pads (they float: a pad is walkable) and a water lily's flower.
--   cattail_1a..2b ... the cattails' upper parts, each stand's in two regions up its leaves (each whole in the radius), as the lamppost's are.
-- Homes: the gap between two boards of the boardwalk (deck_s2: `deck_gap`), under a flat stone resting on two others on the bank (pond_a2: `pond_stone`), and
-- under a dead cattail leaf lying curled on the bank (pond_a1: `cattail_leaf`).
-- The life (`bestiary`, `ambient`): non-biting midges and mosquitoes on the rushes and the cattails, restless and swarming from dusk; eastern forktail damselflies
-- perched on the cattails by day; water striders skating the open water (Prey/Skater, ambient); the green frog on a stone or a pad (Predator/Frog); a green darner
-- over the pond by day (drawn only, Client/PondBodies).
local Hut = require(script.Parent.Hut)
local Preserve = require(script.Parent.Preserve)

local Pond = {}

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
Pond.GROUND = GT
Pond.WATER = GT - 6 -- the pond's surface: 6 cm under the lawn
Pond.BED = Pond.WATER - 20 -- the margin's bed, 20 cm under the surface
Pond.FLOOR = -126 -- the bottom of the bed's box
Pond.DECK = -45 -- the boardwalk's top, 40 cm over the lawn (the backdrop's)
Pond.BOARD = table.freeze({ w = 14, gap = 1.11, thick = 4, count = 10, wide = 1.6 })
Pond.CUT = table.freeze({ GT + 70, GT + 150 }) -- where a cattail stand's leaves pass into its upper regions
Pond.STRIP = 20 -- the bank's strips, along x
local WATER, BED, FLOOR, DECK = Pond.WATER, Pond.BED, Pond.FLOOR, Pond.DECK
-- the corridor and the core (studs)
Pond.PATH_E = table.freeze({ x0 = 90, x1 = 290, z0 = -730, z1 = -630, n = 2 })
Pond.PATH_N = table.freeze({ x0 = 190, x1 = 290, z0 = -816, z1 = -730, n = 1 })
Pond.WALK_X = table.freeze({ 190, 275, 360, 445, 525 })
Pond.CORE_X = table.freeze({ 525, 625, 725, 825, 925 })
Pond.DECK_Z = table.freeze({ s = table.freeze({ -891, -816 }), n = table.freeze({ -966, -891 }) })
Pond.ROW_Z = table.freeze({ a = table.freeze({ -1066, -966 }), b = table.freeze({ -1166, -1066 }), c = table.freeze({ -1216, -1166 }) })
Pond.CORE = table.freeze({ x0 = 525, x1 = 925, z0 = -1216, z1 = -816 })
local CUT1, CUT2 = Pond.CUT[1], Pond.CUT[2]

-- The palette.
local C = {
	mown = { "6f9a46", "7d9a4e", "5f8a3e", "6a8f42" }, board = "8a7458", boardDark = "6f5d47", boardGrey = "8f8676", post = "5e4f3c", mud = "4f4031", mudDark = "3e3226",
	mudWet = "38302a", bed = "2f2a22", water = "3c5650", stone = { "8a8478", "7a756b", "6f6a60", "938c7e" }, stoneWet = "5a564e",
	cattailLeaf = { "6f7f45", "7a8a4e", "667745", "84904f" }, cattailDead = "a08a5a", spike = "5a3d27", spikeMale = "8a7a52", sedge = { "6f8248", "7a8a50", "5f7442" },
	sedgeHead = "6a5a3a", rush = { "4f7a3e", "5a8445", "47703a" }, rushHead = "7a6240", pad = { "4f7a3a", "56833f", "4a7036", "5e8a44" }, padUnder = "8a4a4a",
	lily = "f2f0e8", lilyEye = "e8c23a", duckweed = "7fb04a",
}

-- ---------------------------------------------------------------- the water
-- The pond's south shore at a stud x: the waterline's z for the bank's strip that x is in (each STRIP wide, from the core's west edge), from the backdrop's ellipse
-- (World/Preserve.POND) at the strip's middle; nil where the ellipse does not reach. The boxes and the water's own question use the same line, so a bank's strip ends
-- exactly where the water begins.
function Pond.waterline(x: number): number?
	local K = Pond.CORE
	local mid = K.x0 + Pond.STRIP * math.floor((x - K.x0) / Pond.STRIP) + Pond.STRIP / 2
	local P = Preserve.POND
	local xm = mid / 100 + Preserve.ORIGIN_X_M
	local dx = (xm - P.x) / P.rx
	if math.abs(dx) >= 1 then return nil end
	local zm = P.z - P.rz * math.sqrt(1 - dx * dx)
	return Preserve.NORTH_FACE_Z - (zm - Preserve.NORTH_FACE_M) * 100
end
-- The shore as the backdrop draws it (World/PreserveLook's lens, the ellipse itself) at a stud x: its z, or nil.
function Pond.shore(x: number): number?
	local P = Preserve.POND
	local dx = (x / 100 + Preserve.ORIGIN_X_M - P.x) / P.rx
	if math.abs(dx) >= 1 then return nil end
	return Preserve.NORTH_FACE_Z - (P.z - P.rz * math.sqrt(1 - dx * dx) - Preserve.NORTH_FACE_M) * 100
end
-- Whether a spider's body (its middle) at `p` is in the water: over the water's plan (north of the waterline, inside the pond's ellipse) and under its surface (a
-- spider stands on the surface of nothing; on a pad or a stone its middle is over it).
Pond.SURFACE_TOL = 0.2
function Pond.inWater(p: Vector3): boolean
	if p.Y >= WATER + Pond.SURFACE_TOL or p.Y < FLOOR then return false end
	local zw = Pond.waterline(p.X)
	if zw == nil or p.Z >= zw then return false end
	local P = Preserve.POND
	local xm, zm = Preserve.metres(p)
	return ((xm - P.x) / P.rx) ^ 2 + ((zm - P.z) / P.rz) ^ 2 < 1
end

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

-- The boards across the deck, south (1) to north (10): each { z0, z1 }, 14 cm wide with a gap of a centimetre and a bit; in deck_s2 the third is narrower, so the gap
-- between it and the fourth is BOARD.wide (a home).
local BOARDS: { { number } } = {}
do
	local B = Pond.BOARD
	for k = 1, B.count do
		local z1 = -816 - (k - 1) * (B.w + B.gap)
		table.insert(BOARDS, { z1 - B.w, z1 })
	end
end
Pond.BOARDS = BOARDS
local GAP_REGION = "deck_s2"
local function boardsOf(id: string, k: number): (number, number)
	local b = BOARDS[k]
	if id == GAP_REGION and k == 3 then return b[1] + (Pond.BOARD.wide - Pond.BOARD.gap), b[2] end
	return b[1], b[2]
end

-- The terrain of a rectangle (the bank in strips stepping down to the water, the bed under the water): its land's pieces `{ x0, x1, z0, z1, top, band }` and whether
-- any of it is water. Bands: "bank" (GROUND), "damp" (3 cm lower) and "wet" (a centimetre over the water).
Pond.BANDS = table.freeze({ { from = 30, top = GT, name = "bank" }, { from = 10, top = GT - 3, name = "damp" }, { from = 0, top = WATER + 1, name = "wet" } })
type Land = { x0: number, x1: number, z0: number, z1: number, top: number, band: string }
local function terrain(x0: number, x1: number, z0: number, z1: number): ({ Land }, boolean)
	local out: { Land } = {}
	local wet = false
	local x = x0
	while x < x1 - 1e-6 do
		local K = Pond.CORE
		local nextEdge = K.x0 + Pond.STRIP * (math.floor((x - K.x0) / Pond.STRIP + 1e-9) + 1)
		local xb = math.min(x1, nextEdge)
		local zw = Pond.waterline(x + 1e-3)
		local prevZ = z1
		for _, band in Pond.BANDS do
			local zFrom = if zw == nil then -math.huge else zw + band.from -- (north edge of this band)
			local a, b = math.max(z0, zFrom), prevZ
			if b - a > 1e-6 then table.insert(out, { x0 = x, x1 = xb, z0 = a, z1 = b, top = band.top, band = band.name }) end
			prevZ = math.min(prevZ, math.max(z0, zFrom))
		end
		if prevZ > z0 + 1e-6 then wet = true end
		x = xb
	end
	-- (strips of the same bands side by side become one box)
	local merged: { Land } = {}
	for _, l in out do
		local m: Land? = nil
		for _, o in merged do
			if math.abs(o.x1 - l.x0) < 1e-6 and o.z0 == l.z0 and o.z1 == l.z1 and o.top == l.top then m = o end
		end
		if m ~= nil then (m :: Land).x1 = l.x1 else table.insert(merged, table.clone(l)) end
	end
	-- (and none longer than 40 studs or deeper than 50, so a box's middle is never far from where a spider steps onto it: World/LookPlan's streaming)
	local chunks: { Land } = {}
	for _, l in merged do
		local nx, nz = math.ceil((l.x1 - l.x0) / 40 - 1e-6), math.ceil((l.z1 - l.z0) / 50 - 1e-6)
		for i = 1, nx do
			for j = 1, nz do
				table.insert(chunks, { x0 = l.x0 + (l.x1 - l.x0) * (i - 1) / nx, x1 = l.x0 + (l.x1 - l.x0) * i / nx, z0 = l.z0 + (l.z1 - l.z0) * (j - 1) / nz,
					z1 = l.z0 + (l.z1 - l.z0) * j / nz, top = l.top, band = l.band })
			end
		end
	end
	return chunks, wet
end
Pond.terrain = terrain
-- The top of the ground (or the bed) at a point of the core.
local function groundAt(x: number, z: number): number
	local lands = terrain(x - 0.01, x + 0.01, z - 0.01, z + 0.01)
	return if #lands > 0 then lands[1].top else BED
end
Pond.groundAt = groundAt

-- ---------------------------------------------------------------- the margin's plan
-- Each cell's things, from its plan and its seed: `stones` (in the water by the waterline, or on the bank), `sedge` and `rush` clumps, lily `pads` and a `flower`,
-- a cattail `stand` (its number), and the homes. Offsets east of the cell's west edge (dx) and north of its south edge (dz).
type CellPlan = { sedge: { { number } }?, rush: { { number } }?, stones: { { number } }?, pads: { { number } }?, flower: { number }?, stand: number?, leaf: { number }?,
	shelter: { number }?, flat: { number }? }
local PLAN: { [string]: CellPlan } = {
	a1 = { leaf = { 38, 34 }, sedge = { { 72, 64 } }, rush = { { 18, 78 } }, stones = { { 88, 0 } } },
	a2 = { shelter = { 30, 15 }, sedge = { { 70, 8 } }, rush = { { 58, 0 } }, flat = { 14, 0 }, stones = { { 88, 0 } } },
	a3 = { stand = 1, stones = { { 15, 0 } }, pads = { { 78, 62, 18 } } },
	a4 = { pads = { { 30, 40, 22 }, { 74, 74, 16 } }, rush = { { 82, 20 } } },
	b1 = { sedge = { { 12, 15 } }, rush = { { 62, 30 } }, stones = { { 82, 14 } } },
	b2 = { stand = 2, pads = { { 80, 80, 17 } } },
	b3 = { pads = { { 25, 30, 24 }, { 70, 62, 20 }, { 34, 82, 15 } }, flower = { 52, 46 } },
	b4 = { pads = { { 40, 46, 27 }, { 80, 16, 17 } } },
	c1 = { rush = { { 30, 22 } }, pads = { { 70, 26, 18 } } },
	c2 = { pads = { { 28, 24, 21 }, { 72, 30, 16 } } },
	c3 = { pads = { { 50, 25, 15 } } },
	c4 = { pads = { { 34, 22, 19 }, { 76, 30, 23 } } },
}
Pond.PLAN = PLAN
-- The cattail stands: each three shoots of leaves in a fan and one flowering stalk with its brown spike, in the shallow water (centres, studs).
Pond.STANDS = table.freeze({
	table.freeze({ cell = "a3", x = 775, z = -1027 }),
	table.freeze({ cell = "b2", x = 672, z = -1117 }),
})
-- True sizes (studs = cm). Common cattail (Typha latifolia): leaves flat, 1 to 2 cm wide (1.5 here), 1.5 to 2.5 m tall; the brown female spike 15 to 20 cm long on its
-- stalk, the thin male spike above it. Sedge and soft rush: 45 to 75 cm.
Pond.CATTAIL = table.freeze({ leafW = 1.5, leafT = 0.35, leafGap = 1, leaves = table.freeze({ 150, 172, 196, 214, 186, 160, 205, 178, 220 }), stalk = 0.8, spike = table.freeze({ w = 2.6, from = 150, to = 168 }),
	male = table.freeze({ w = 0.6, to = 182 }), shoots = table.freeze({ { 0, 0, "x" } :: { any }, { 6.5, 3.5, "z" }, { -4.5, 6, "x" } }) :: any }) :: any
Pond.SEDGE = table.freeze({ at = table.freeze({ { 0, 0 }, { 2.2, 1 }, { -1.6, 1.8 }, { 1, -2.2 }, { -2, -1.2 } }), h = table.freeze({ 62, 55, 48, 58, 44 }), half = 0.25 })
Pond.RUSH = table.freeze({ at = table.freeze({ { 0, 0 }, { 1.4, 0.6 }, { -1.1, 1.2 }, { 0.7, -1.5 }, { -1.4, -0.9 }, { 2, -1 }, { -0.4, 2.4 } }),
	h = table.freeze({ 74, 66, 70, 61, 68, 58, 64 }), half = 0.13 })
Pond.LEAF = table.freeze({ l = 20, w = 2.6, rest = 1.4, gap = 1.4, thick = 0.5 }) -- the dead cattail leaf, broad at its base, lying curled on two old stems
Pond.SHELTER = table.freeze({ l = 11, w = 9, rest = 2, gap = 1.4, thick = 2.2 }) -- the flat stone on two others
Pond.FLAT = table.freeze({ l = 16, w = 11, top = 4.5 }) -- the flat stone at the water's edge (the frog's seat)

local ROWS = { "a", "b", "c" }
local function cellBox(r: number, c: number): (number, number, number, number)
	local X = Pond.CORE_X
	local Z = Pond.ROW_Z[ROWS[r]]
	return X[c], X[c + 1], Z[1], Z[2]
end
Pond.cellBox = cellBox

-- The point of a cell's plan entry: (dx, dz), or with dz 0 the place just in the water off the waterline at dx (a stone's middle `half` north of it).
local function planPoint(x0: number, z1: number, e: { number }, half: number): (number, number)
	local x = x0 + e[1]
	if e[2] == 0 then
		local zw = Pond.waterline(x) or z1
		return x, math.min(zw - half - 1.5, z1 - half - 1)
	end
	return x, z1 - e[2]
end

local RETREATS: { [string]: { id: string, min: Vector3, max: Vector3, door: Vector3 } } = {}
do
	-- between the boards in deck_s2: the wide gap between its third and fourth
	local x0, x1 = Pond.CORE_X[2], Pond.CORE_X[3]
	local za, zb = BOARDS[4][2], BOARDS[3][1] + (Pond.BOARD.wide - Pond.BOARD.gap)
	RETREATS.deck_s2 = { id = "deck_gap", min = v(x0 + 12, DECK - Pond.BOARD.thick, za), max = v(x1 - 12, DECK, zb), door = v((x0 + x1) / 2, DECK + 0.5, (za + zb) / 2) }
	-- under the curled leaf in pond_a1
	local cx0, _, _, cz1 = cellBox(1, 1)
	local L = Pond.LEAF
	local leafAt = PLAN.a1.leaf :: { number }
	local lx, lz = cx0 + leafAt[1], cz1 - leafAt[2]
	RETREATS.pond_a1 = { id = "cattail_leaf", min = v(lx - L.l / 2 + L.rest, GT, lz - L.w / 2 + 0.3), max = v(lx + L.l / 2 - L.rest, GT + L.gap, lz + L.w / 2 - 0.3),
		door = v(lx, GT + 0.5, lz + L.w / 2 + 3) }
	-- under the flat stone on the damp mud in pond_a2
	local sx0, _, _, sz1 = cellBox(1, 2)
	local S = Pond.SHELTER
	local shelterAt = PLAN.a2.shelter :: { number }
	local hx, hz = sx0 + shelterAt[1], sz1 - shelterAt[2]
	local top = groundAt(hx, hz)
	RETREATS.pond_a2 = { id = "pond_stone", min = v(hx - S.l / 2 + S.rest, top, hz - S.w / 2 + 1), max = v(hx + S.l / 2 - S.rest, top + S.gap, hz + S.w / 2 - 1),
		door = v(hx, top + 0.5, hz + S.w / 2 + 3) }
end
Pond.RETREATS = RETREATS

-- The authored regions, for a world seed (`seedOf`: World/WorldMap.seed), in priority order (after the meadow's: World/WorldMap.authorPreserve).
function Pond.author(worldSeed: number, seedOf: (number, string) -> number): { Region }
	local list: { Region } = {}
	local byId: { [string]: Region } = {}
	local function region(id: string, kind: string, lo: Vector3, hi: Vector3, spawn: Vector3, heading: Vector3)
		local t = RETREATS[id]
		local r = {
			id = id, kind = kind, origin = v((lo.X + hi.X) / 2, GT, (lo.Z + hi.Z) / 2), bounds = { lo, hi }, seed = seedOf(worldSeed, id), neighbors = {},
			retreats = if t ~= nil then { table.clone(t) } else {}, spawn = { pos = spawn, heading = heading }, clockScale = 0.33,
		}
		table.insert(list, r :: any)
		byId[id] = r :: any
	end
	-- the cattails' upper regions first (their bounds stand over the cells')
	for k, st in Pond.STANDS do
		local T = Pond.CATTAIL
		local face = v(st.x + T.leafW + T.leafGap, 0, st.z + T.leafT / 2)
		region(`cattail_{k}a`, "cattail", v(st.x - 30, CUT1, st.z - 30), v(st.x + 30, CUT2, st.z + 30), v(face.X, (CUT1 + CUT2) / 2, face.Z), v(0, 1, 0))
		region(`cattail_{k}b`, "cattail", v(st.x - 30, CUT2, st.z - 30), v(st.x + 30, WATER + 240, st.z + 30), v(face.X, CUT2 + 20, face.Z), v(0, 1, 0))
	end
	-- the boardwalk: the corridor's and the core's, the south row and the north
	local function deck(prefix: string, xs: { number })
		for c = 1, #xs - 1 do
			for _, row in { "s", "n" } do
				local Z = Pond.DECK_Z[row]
				local x0, x1 = xs[c], xs[c + 1]
				local k = if row == "s" then 2 else 9
				local b = BOARDS[k]
				region(`{prefix}_{row}{c}`, "boardwalk", v(x0, FLOOR, Z[1]), v(x1, DECK + 20, Z[2]), v((x0 + x1) / 2, DECK, (b[1] + b[2]) / 2), v(1, 0, 0))
			end
		end
	end
	deck("walk", Pond.WALK_X)
	deck("deck", Pond.CORE_X)
	-- the margin's cells
	for r = 1, 3 do
		for c = 1, 4 do
			local x0, x1, z0, z1 = cellBox(r, c)
			local id = `pond_{ROWS[r]}{c}`
			region(id, "pond", v(x0, FLOOR, z0), v(x1, CUT1, z1), Pond.spawnOf(id, x0, x1, z0, z1), v(0, 0, -1))
		end
	end
	-- the mown path
	local E, N = Pond.PATH_E, Pond.PATH_N
	for k = 1, E.n do
		local x0 = E.x0 + (k - 1) * 100
		region(`mown_e{k}`, "mown_path", v(x0, -88, E.z0), v(x0 + 100, GT + 40, E.z1), v(x0 + 50, GT, (E.z0 + E.z1) / 2), v(1, 0, 0))
	end
	for k = 1, N.n do
		local z1 = N.z1 - (k - 1) * 100
		local z0 = if k == N.n then N.z0 else z1 - 100
		region(`mown_n{k}`, "mown_path", v(N.x0, -88, z0), v(N.x1, GT + 40, z1), v((N.x0 + N.x1) / 2, GT, (z0 + z1) / 2), v(0, 0, -1))
	end
	-- (a seam with World/Meadow's pad_b3 is listed on this side only: Meadow lists it on its own)
	for _, s in SEAMS do
		local a, b = byId[s.a], byId[s.b]
		if a ~= nil then table.insert(a.neighbors, { id = s.b, a = s.p, b = s.q }) end
		if b ~= nil then table.insert(b.neighbors, { id = s.a, a = s.p, b = s.q }) end
	end
	for _, r in list do freeze(r) end
	return list
end

-- The seam that meets World/Meadow's regions (the bench patch's east edge): World/Meadow lists it on pad_b3's side.
Pond.MEADOW_SEAMS = table.freeze({
	table.freeze({ meadow = "pad_b3", id = "mown_e1", a = v(90, GT, -711), b = v(90, GT, -635) }),
})
for _, s in Pond.MEADOW_SEAMS do seam(s.meadow, s.id, s.a, s.b) end

do
	-- the mown path, cell to cell, flat on the lawn
	local E, N = Pond.PATH_E, Pond.PATH_N
	for k = 1, E.n - 1 do
		local x = E.x0 + k * 100
		seam(`mown_e{k}`, `mown_e{k + 1}`, v(x, GT, E.z0 + 8), v(x, GT, E.z1 - 8))
	end
	-- (the east leg's last cell is the corner: the north leg leaves its north edge)
	seam(`mown_e{E.n}`, "mown_n1", v(N.x0 + 8, GT, E.z0), v(N.x1 - 8, GT, E.z0))
	for k = 1, N.n - 1 do
		local z = N.z1 - k * 100
		seam(`mown_n{k}`, `mown_n{k + 1}`, v(N.x0 + 8, GT, z), v(N.x1 - 8, GT, z))
	end
	-- up the boardwalk's south fascia: its foot on the lawn
	seam(`mown_n{N.n}`, "walk_s1", v(N.x0 + 8, GT, N.z0), v(Pond.WALK_X[2] - 8, GT, N.z0))
	-- the boardwalk, region to region along its boards (on the deck's top), and its two rows across the gap between the fifth and sixth boards (the boards' ends)
	local function deckSeams(prefix: string, xs: { number })
		for c = 1, #xs - 1 do
			local x1 = xs[c + 1]
			if c < #xs - 1 then
				seam(`{prefix}_s{c}`, `{prefix}_s{c + 1}`, v(x1, DECK, BOARDS[2][1] + 1), v(x1, DECK, BOARDS[2][2] - 1))
				seam(`{prefix}_n{c}`, `{prefix}_n{c + 1}`, v(x1, DECK, BOARDS[9][1] + 1), v(x1, DECK, BOARDS[9][2] - 1))
			end
		end
	end
	deckSeams("walk", Pond.WALK_X)
	deckSeams("deck", Pond.CORE_X)
	seam("walk_s4", "deck_s1", v(525, DECK, BOARDS[2][1] + 1), v(525, DECK, BOARDS[2][2] - 1))
	seam("walk_n4", "deck_n1", v(525, DECK, BOARDS[9][1] + 1), v(525, DECK, BOARDS[9][2] - 1))
	-- under the boardwalk across its two rows, and off its north edge to the margin's ground, and the margin's cells to one another: flat across the ground (the
	-- bank's strips or the bed under the water) along the longest stretch of their shared edge where both sides' ground is at one height
	local function across(a: string, b: string, alongX: boolean, at: number, s0: number, s1: number)
		local bestY, bestA, bestB = 0, 0, -1
		local runY, runA = nil :: number?, 0
		local s = s0
		while s <= s1 + 1e-6 do
			local ya = if alongX then groundAt(s, at + 0.5) else groundAt(at - 0.5, s)
			local yb = if alongX then groundAt(s, at - 0.5) else groundAt(at + 0.5, s)
			local y: number? = if math.abs(ya - yb) < 1e-6 then ya else nil
			if y ~= nil and runY ~= nil and math.abs(y - (runY :: number)) < 1e-6 then
				if s - runA > bestB - bestA then bestY, bestA, bestB = y, runA, s end
			elseif y ~= nil then
				runY, runA = y, s
			else
				runY = nil
			end
			s += 1
		end
		assert(bestB - bestA >= 6, `no stretch of shared ground between {a} and {b}`)
		-- (at most 40 studs of it, its middle: what the spider steps onto is then within the radius always sent from anywhere along it)
		if bestB - bestA > 40 then
			local m = (bestA + bestB) / 2
			bestA, bestB = m - 20, m + 20
		end
		if alongX then seam(a, b, v(bestA + 1, bestY, at), v(bestB - 1, bestY, at))
		else seam(a, b, v(at, bestY, bestA + 1), v(at, bestY, bestB - 1)) end
	end
	Pond.across = across
	for _, prefix in { "walk", "deck" } do
		local xs: { number } = if prefix == "walk" then Pond.WALK_X else Pond.CORE_X
		for c = 1, #xs - 1 do
			across(`{prefix}_s{c}`, `{prefix}_n{c}`, true, -891, xs[c] + 4, xs[c + 1] - 4)
		end
	end
	for c = 1, 4 do
		across(`deck_n{c}`, `pond_a{c}`, true, -966, Pond.CORE_X[c] + 16, Pond.CORE_X[c + 1] - 4)
	end
	for r = 1, 3 do
		for c = 1, 4 do
			local x0, x1, z0, z1 = cellBox(r, c)
			local here = `pond_{ROWS[r]}{c}`
			if c < 4 then across(here, `pond_{ROWS[r]}{c + 1}`, false, x1, z0 + 4, z1 - 4) end
			if r < 3 then across(here, `pond_{ROWS[r + 1]}{c}`, true, z0, x0 + 4, x1 - 4) end
		end
	end
	-- the cattails' upper regions: up the first shoot's middle leaf, across its face
	for k, st in Pond.STANDS do
		local cell = `pond_{st.cell}`
		local T = Pond.CATTAIL
		local mid = st.x + (T.leafW + T.leafGap)
		local fz = st.z + T.leafT / 2
		seam(cell, `cattail_{k}a`, v(mid - T.leafW / 2, CUT1, fz), v(mid + T.leafW / 2, CUT1, fz))
		seam(`cattail_{k}a`, `cattail_{k}b`, v(mid - T.leafW / 2, CUT2, fz), v(mid + T.leafW / 2, CUT2, fz))
	end
end

-- ---------------------------------------------------------------- the pieces
local function P(out: { Piece }, id: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, profile: string, color: string, material: string?)
	table.insert(out, { id = id, lo = v(x0, y0, z0), hi = v(x1, y1, z1), profile = profile, color = hex(color), material = material })
end

-- The terrain's boxes of a rectangle: the bed under any water and each land strip from the bed (or the corridor's floor) to its top.
local function terrainPieces(out: { Piece }, id: string, x0: number, x1: number, z0: number, z1: number)
	local lands, wet = terrain(x0, x1, z0, z1)
	local base = if wet then BED else -100
	if wet then P(out, id .. "_bed", x0, x1, FLOOR, BED, z0, z1, "brick_rough", C.bed, "Mud") end
	for i, l in lands do
		local color = if l.band == "bank" then C.mud elseif l.band == "damp" then C.mudDark else C.mudWet
		P(out, `{id}_{l.band}_{i}`, l.x0, l.x1, base, l.top, l.z0, l.z1, "brick_rough", color, if l.band == "bank" then "Ground" else "Mud")
	end
end

-- A cattail stand's boxes whole (before they are cut into its regions): three shoots of three leaves in a fan, the flowering stalk, its spike and the male spike.
local function standPieces(k: number): { Piece }
	local st = Pond.STANDS[k]
	local T = Pond.CATTAIL
	local out: { Piece } = {}
	local n = 0
	for s, sh in T.shoots do
		local cx, cz = st.x + sh[1], st.z + sh[2]
		for i = -1, 1 do
			n += 1
			local h = T.leaves[n]
			local off = i * (T.leafW + T.leafGap)
			local name = `cattail_{k}_leaf_{s}_{i + 2}`
			if sh[3] == "x" then P(out, name, cx + off - T.leafW / 2, cx + off + T.leafW / 2, BED, WATER + h, cz - T.leafT / 2, cz + T.leafT / 2, "leaf_dry_prototype", C.cattailLeaf[1 + n % 4])
			else P(out, name, cx - T.leafT / 2, cx + T.leafT / 2, BED, WATER + h, cz + off - T.leafW / 2, cz + off + T.leafW / 2, "leaf_dry_prototype", C.cattailLeaf[1 + n % 4]) end
		end
	end
	-- the flowering stalk, a little apart, its spike and the male spike over it
	local sx, sz = st.x - 3, st.z - 4.5
	P(out, `cattail_{k}_stalk`, sx - T.stalk / 2, sx + T.stalk / 2, BED, WATER + T.spike.from, sz - T.stalk / 2, sz + T.stalk / 2, "leaf_dry_prototype", "6a7a48")
	P(out, `cattail_{k}_spike`, sx - T.spike.w / 2, sx + T.spike.w / 2, WATER + T.spike.from, WATER + T.spike.to, sz - T.spike.w / 2, sz + T.spike.w / 2, "leaf_dry_prototype", C.spike)
	P(out, `cattail_{k}_male`, sx - T.male.w / 2, sx + T.male.w / 2, WATER + T.spike.to, WATER + T.male.to, sz - T.male.w / 2, sz + T.male.w / 2, "leaf_dry_prototype", C.spikeMale)
	return out
end
-- The part of a stand's boxes between two heights (its cell's below CUT1, its regions' above), each cut piece keeping its id with the part's suffix.
local function cutStand(out: { Piece }, k: number, y0: number, y1: number, tag: string)
	for _, p in standPieces(k) do
		local a, b = math.max(p.lo.Y, y0), math.min(p.hi.Y, y1)
		if b - a > 1e-6 then
			table.insert(out, { id = p.id .. tag, lo = v(p.lo.X, a, p.lo.Z), hi = v(p.hi.X, b, p.hi.Z), profile = p.profile, color = p.color, material = p.material })
		end
	end
end
Pond.standPieces = standPieces

-- A clump of culms (sedge or rush) from its base at `y0`, ids `<base>_culm_<i>`, and its heads.
local function clumpPieces(out: { Piece }, base: string, kind: string, x: number, z: number, y0: number, rand: () -> number)
	local S: any = if kind == "sedge" then Pond.SEDGE else Pond.RUSH
	for i, o in S.at :: { { number } } do
		local cx, cz = x + o[1], z + o[2]
		local top = y0 + S.h[i] * between(rand, 0.93, 1)
		if kind == "rush" then top = math.min(top, CUT1 - 1) end
		P(out, `{base}_culm_{i}`, cx - S.half, cx + S.half, y0, top, cz - S.half, cz + S.half, "leaf_dry_prototype", pick(if kind == "sedge" then C.sedge else C.rush, rand))
		if kind == "sedge" and (i == 1 or i == 4) then
			P(out, `{base}_head_{i}`, cx - 0.6, cx + 0.6, top, top + 4, cz - 0.6, cz + 0.6, "leaf_dry_prototype", C.sedgeHead)
		elseif kind == "rush" and (i == 2 or i == 5) then
			-- the soft rush's flower cluster, out from the stem's side a little under its tip
			P(out, `{base}_head_{i}`, cx + S.half, cx + S.half + 1.2, top - 14, top - 11, cz - 0.6, cz + 0.6, "leaf_dry_prototype", C.rushHead)
		end
	end
end

-- A lily pad: three boxes across its round (a middle band and its two caps), floating; the drawn pad covers them (Pond.drawnPieces).
local function padPieces(out: { Piece }, base: string, x: number, z: number, d: number)
	local y0, y1 = WATER - 0.1, WATER + 0.3
	P(out, base .. "_mid", x - 0.47 * d, x + 0.47 * d, y0, y1, z - 0.27 * d, z + 0.27 * d, "leaf_dry_prototype", C.pad[1])
	P(out, base .. "_n", x - 0.36 * d, x + 0.36 * d, y0, y1, z - 0.44 * d, z - 0.27 * d, "leaf_dry_prototype", C.pad[1])
	P(out, base .. "_s", x - 0.36 * d, x + 0.36 * d, y0, y1, z + 0.27 * d, z + 0.44 * d, "leaf_dry_prototype", C.pad[1])
end

-- The base of a plant at a point: the bank's top, or the bed in the water.
local function baseAt(x: number, z: number): number
	return groundAt(x, z)
end

local function pondPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local key = string.sub(id, 6)
	local plan = PLAN[key]
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0, x1, z0, z1 = lo.X, hi.X, lo.Z, hi.Z
	local rand = rng(region.seed, 5)
	terrainPieces(out, id, x0, x1, z0, z1)
	for i, s in (plan.stones or {}) :: { { number } } do
		local size = between(rand, 6, 10)
		local x, z = planPoint(x0, z1, s, size / 2)
		local top = WATER + between(rand, 2.5, 4.5)
		P(out, `{id}_stone_{i}`, x - size / 2, x + size / 2, BED, top, z - size * 0.35, z + size * 0.35, "brick_rough", pick(C.stone, rand), "Slate")
	end
	if plan.flat ~= nil then
		local F = Pond.FLAT
		local x, z = planPoint(x0, z1, plan.flat, F.w / 2)
		x = x + F.l / 2
		P(out, id .. "_flat", x - F.l / 2, x + F.l / 2, BED, WATER + F.top, z - F.w / 2, z + F.w / 2, "brick_rough", C.stone[2], "Slate")
	end
	if plan.shelter ~= nil then
		local S = Pond.SHELTER
		local hx, hz = x0 + plan.shelter[1], z1 - plan.shelter[2]
		local top = groundAt(hx, hz)
		P(out, id .. "_rest_w", hx - S.l / 2, hx - S.l / 2 + S.rest, top, top + S.gap, hz - S.w / 2, hz + S.w / 2, "brick_rough", C.stone[3], "Slate")
		P(out, id .. "_rest_e", hx + S.l / 2 - S.rest, hx + S.l / 2, top, top + S.gap, hz - S.w / 2, hz + S.w / 2, "brick_rough", C.stone[3], "Slate")
		P(out, id .. "_slab", hx - S.l / 2, hx + S.l / 2, top + S.gap, top + S.gap + S.thick, hz - S.w / 2, hz + S.w / 2, "brick_rough", C.stone[1], "Slate")
	end
	if plan.leaf ~= nil then
		local L = Pond.LEAF
		local lx, lz = x0 + plan.leaf[1], z1 - plan.leaf[2]
		P(out, id .. "_old_w", lx - L.l / 2, lx - L.l / 2 + L.rest, GT, GT + L.gap, lz - L.w / 2, lz + L.w / 2, "leaf_dry_prototype", C.cattailDead)
		P(out, id .. "_old_e", lx + L.l / 2 - L.rest, lx + L.l / 2, GT, GT + L.gap, lz - L.w / 2, lz + L.w / 2, "leaf_dry_prototype", "8a7448")
		P(out, id .. "_leaf", lx - L.l / 2, lx + L.l / 2, GT + L.gap, GT + L.gap + L.thick, lz - L.w / 2, lz + L.w / 2, "leaf_dry_prototype", C.cattailDead)
	end
	for i, e in (plan.sedge or {}) :: { { number } } do
		local x, z = x0 + e[1], z1 - e[2]
		clumpPieces(out, `{id}_sedge{i}`, "sedge", x, z, baseAt(x, z), rand)
	end
	for i, e in (plan.rush or {}) :: { { number } } do
		local x, z = planPoint(x0, z1, e, 3)
		clumpPieces(out, `{id}_rush{i}`, "rush", x, z, baseAt(x, z), rand)
	end
	for i, e in (plan.pads or {}) :: { { number } } do padPieces(out, `{id}_pad_{i}`, x0 + e[1], z1 - e[2], e[3]) end
	if plan.flower ~= nil then
		local fx, fz = x0 + plan.flower[1], z1 - plan.flower[2]
		P(out, id .. "_lily", fx - 3, fx + 3, WATER - 0.2, WATER + 3.5, fz - 3, fz + 3, "leaf_dry_prototype", C.lily)
	end
	if plan.stand ~= nil then cutStand(out, plan.stand, -math.huge, CUT1, "") end
	return out
end

-- Where a life (or a rest from another revision) is put back in a cell: on its bank if it has one, else on its first pad.
function Pond.spawnOf(id: string, x0: number, x1: number, z0: number, z1: number): Vector3
	local lands = terrain(x0, x1, z0, z1)
	local best: Land? = nil
	for _, l in lands do if l.band == "bank" and (best == nil or (l.x1 - l.x0) * (l.z1 - l.z0) > ((best :: Land).x1 - (best :: Land).x0) * ((best :: Land).z1 - (best :: Land).z0)) then best = l end end
	if best == nil then for _, l in lands do if (l.x1 - l.x0) >= 10 and (l.z1 - l.z0) >= 6 then best = l end end end
	if best ~= nil then
		local b = best :: Land
		local x, z = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
		local plan = PLAN[string.sub(id, 6)]
		-- (clear of what stands there: the curled leaf, the stone shelter, the clumps)
		for _, e in { plan.leaf, plan.shelter } do
			if e ~= nil and math.abs(x - (x0 + e[1])) < 14 and math.abs(z - (z1 - e[2])) < 14 then x = if e[1] > 50 then x0 + 15 else x1 - 15 end
		end
		for _, e in (plan.sedge or {}) :: { { number } } do
			if math.abs(x - (x0 + e[1])) < 6 and math.abs(z - (z1 - e[2])) < 6 then x += 10 end
		end
		return v(x, b.top, z)
	end
	local pads = PLAN[string.sub(id, 6)].pads
	local p = (pads :: { { number } })[1]
	return v(x0 + p[1], WATER + 0.3, z1 - p[2])
end

-- The boardwalk's boxes in a region: its boards (cut at the region's ends), the fascia or the north beam, the middle beam's half, a post, the kerb rail on its blocks,
-- and the ground under it.
local function deckPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local id = region.id
	local lo, hi = region.bounds[1], region.bounds[2]
	local x0, x1, z0, z1 = lo.X, hi.X, lo.Z, hi.Z
	local south = string.sub(id, 6, 6) == "s"
	local B = Pond.BOARD
	local rand = rng(region.seed, 7)
	local first, last = if south then 1 else 6, if south then 5 else 10
	for k = first, last do
		local a, b = boardsOf(id, k)
		P(out, `{id}_board_{k}`, x0, x1, DECK - B.thick, DECK, a, b, "bare_wood_rough", pick({ C.board, C.boardDark, C.boardGrey, "7f6b52" }, rand), "WoodPlanks")
	end
	local under = DECK - B.thick
	if south then
		-- the fascia board on the south face, from the lawn to under the boards
		P(out, id .. "_fascia", x0, x1, GT, under, z1 - 3, z1, "bare_wood_rough", C.boardDark, "Wood")
		P(out, id .. "_beam", x0, x1, under - 15, under, -891, -888, "bare_wood_rough", C.post, "Wood")
	else
		P(out, id .. "_beam", x0, x1, under - 15, under, z0, z0 + 5, "bare_wood_rough", C.post, "Wood")
		P(out, id .. "_beam_mid", x0, x1, under - 15, under, -894, -891, "bare_wood_rough", C.post, "Wood")
		local px = x0 + 8
		local foot = -math.huge
		for _, l in (terrain(px - 5, px + 5, z0, z0 + 10)) do foot = math.max(foot, l.top) end
		if foot == -math.huge then foot = BED end
		P(out, id .. "_post", px - 5, px + 5, foot, under - 15, z0, z0 + 10, "bare_wood_rough", C.post, "Wood")
	end
	-- the kerb rail along the edge on its spacer blocks: a gap of 2 cm under it between the blocks
	local kz0, kz1 = if south then z1 - 8 else z0, if south then z1 else z0 + 8
	P(out, id .. "_kerb", x0, x1, DECK + 2, DECK + 10, kz0, kz1, "bare_wood_rough", C.boardDark, "Wood")
	local w = x1 - x0
	for i, f in { 0.2, 0.7 } do
		local bx = x0 + f * w
		P(out, `{id}_block_{i}`, bx - 3, bx + 3, DECK, DECK + 2, kz0, kz1, "bare_wood_rough", C.post, "Wood")
	end
	-- the ground under it (fascia's foot to the north edge), clear of the post
	terrainPieces(out, id, x0, x1, z0, if south then z1 - 3 else z1)
	if not south then
		-- (the post stands on the ground: the terrain's boxes are cut round its footprint by lowering nothing; the post's foot is the ground's top there)
	end
	return out
end

-- The mown path's cell: its lawn, cut short.
local function pathPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local lo, hi = region.bounds[1], region.bounds[2]
	P(out, region.id .. "_lawn", lo.X, hi.X, -87, GT, lo.Z, hi.Z, "brick_rough", C.mown[1], "Grass")
	return out
end

local function cattailPieces(region: Region): { Piece }
	local out: { Piece } = {}
	local k = tonumber(string.sub(region.id, 9, 9)) :: number
	local upper = string.sub(region.id, 10, 10) == "b"
	if upper then cutStand(out, k, CUT2, math.huge, "_b") else cutStand(out, k, CUT1, CUT2, "_a") end
	return out
end

local KINDS: { [string]: boolean } = { mown_path = true, boardwalk = true, pond = true, cattail = true }
-- Whether a kind is the pond's or its corridor's.
function Pond.knows(kind: string): boolean
	return KINDS[kind] == true
end

local piecesCache: { [string]: { Piece } } = {}
function Pond.pieces(region: Region): { Piece }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = piecesCache[key]
	if cached ~= nil then return cached end
	local k, out = region.kind, nil :: { Piece }?
	if k == "mown_path" then out = pathPieces(region)
	elseif k == "boardwalk" then out = deckPieces(region)
	elseif k == "pond" then out = pondPieces(region)
	elseif k == "cattail" then out = cattailPieces(region)
	else error("no generator for the region kind " .. k) end
	local list = out :: { Piece }
	for _, p in list do table.freeze(p) end
	piecesCache[key] = table.freeze(list)
	return list
end

-- The lily pads' boxes are drawn as round pads over them (the decor's), and the water lily's box as its flower, so those boxes are not drawn themselves.
local drawnCache: { [string]: { string } } = {}
function Pond.drawnPieces(region: Region): { string }
	local cached = drawnCache[region.id]
	if cached ~= nil then return cached end
	local out: { string } = {}
	if region.kind == "pond" then
		for _, p in Pond.pieces(region) do
			if string.find(p.id, "_pad_", 1, true) ~= nil or string.sub(p.id, -5) == "_lily" or p.id == "pond_a1_leaf" then table.insert(out, p.id) end
		end
	end
	drawnCache[region.id] = table.freeze(out)
	return out
end

-- The boxes a region's creatures keep out of: each retreat grown by half a stud.
function Pond.keepOut(region: Region): { Box }
	local out: { Box } = {}
	for _, t in region.retreats do table.insert(out, { min = t.min - v(0.5, 0.5, 0.5), max = t.max + v(0.5, 0.5, 0.5) }) end
	return out
end

-- ---------------------------------------------------------------- the drawn looks
-- The ceilings each kind keeps to at both tiers (tests/preserve.luau holds them). A margin cell's look: the water's surface (translucent, at its true level; Roblox's
-- own reflections), the pads drawn round, the cattails' and the rushes' drawn blades and heads, the mud's wet sheen and the waterline's scum; what reads from a metre or
-- two off at the low tier (the water, the pads, the stands' masses). The corridor's mown path is coarse: its cut tufts at the full tier. The spider's close view (the
-- duckweed, the mud's crumbs, the floating seeds, the dew) is the patches'.
Pond.BUDGETS = table.freeze({
	pond = { full = 170, low = 22 }, boardwalk = { full = 28, low = 3 }, mown_path = { full = 24, low = 2 }, cattail = { full = 40, low = 12 },
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
local function blade(add: (Drawn) -> boolean, id: string, at: Vector3, h: number, w: number, yaw: number, lean: number, bend: number?, color: string, full: boolean, thick: number?)
	local function seg(sid: string, from: Vector3, len: number, l: number): Vector3
		local r = math.rad(l)
		local dir = v(-math.sin(r) * math.cos(math.rad(yaw)), math.cos(r), math.sin(r) * math.sin(math.rad(yaw)))
		add(rec(sid, v(w, len, thick or 0.06), from + dir * (len / 2), color, "SmoothPlastic", full, nil, v(0, yaw, l)))
		return from + dir * len
	end
	if bend == nil then seg(id, at, h, lean); return end
	local knee = seg(id .. "a", at, h * 0.55, lean)
	seg(id .. "b", knee, h * 0.45, lean + bend)
end
-- The water's surface over a rectangle: the backdrop's lens (World/PreserveLook) is the pond's water, a hair under the surface; where a bank's strip ends north of the
-- lens's own shore (the strips are straight, the shore is not), the water between is drawn here the same way, translucent, its tint the pond's, shining.
local function waterSheet(add: (Drawn) -> boolean, id: string, x0: number, x1: number, z0: number, z1: number)
	local x = x0
	local k = 0
	while x < x1 - 1e-6 do
		local K = Pond.CORE
		local xb = math.min(x1, K.x0 + Pond.STRIP * (math.floor((x - K.x0) / Pond.STRIP + 1e-9) + 1))
		local zw = Pond.waterline(x + 1e-3)
		local za, zb = Pond.shore(x), Pond.shore(xb)
		if zw ~= nil then
			local north = math.min(za or zw, zb or zw)
			local s0, s1 = math.max(z0, north), math.min(z1, zw)
			if s1 - s0 > 0.2 then
				k += 1
				local d = rec(`{id}{k}`, v(xb - x, 0.2, s1 - s0), v((x + xb) / 2, WATER - 0.4, (s0 + s1) / 2), C.water, "Glass", false)
				d.transparency = 0.35
				d.reflectance = 0.25
				add(d)
			end
		end
		x = xb
	end
end

-- A cattail stand drawn (the part between two heights): each leaf a blade over its box, the upper third arching over and away, the spike's velvet and the male spike.
local function standDecor(add: (Drawn) -> boolean, k: number, y0: number, y1: number, rand: () -> number)
	local T = Pond.CATTAIL
	for _, p in standPieces(k) do
		local a, b = math.max(p.lo.Y, y0), math.min(p.hi.Y, y1)
		if b - a <= 1e-6 then continue end
		local c = (p.lo + p.hi) * 0.5
		if string.find(p.id, "_leaf_", 1, true) ~= nil then
			local alongX = (p.hi.X - p.lo.X) > (p.hi.Z - p.lo.Z)
			local w = T.leafW * 1.1
			local top = p.hi.Y
			local bendAt = top - (top - WATER) * 0.3
			-- the straight part over the box (a little wider so its corners hardly show)
			local s0, s1 = a, math.min(b, bendAt)
			if s1 - s0 > 1e-3 then
				add(rec(p.id .. "_Blade", if alongX then v(w, s1 - s0, T.leafT * 0.8) else v(T.leafT * 0.8, s1 - s0, w), v(c.X, (s0 + s1) / 2, c.Z), pick(C.cattailLeaf, rand), "SmoothPlastic", false))
			end
			-- the arch: drawn only (it would not hold a spider in a box), out from where the box ends
			if b >= top - 1e-3 then
				local yaw = (if alongX then 90 else 0) + between(rand, -30, 30) + (if rand() < 0.5 then 180 else 0)
				blade(add, p.id .. "_Arch", v(c.X, top - 1, c.Z), (top - WATER) * between(rand, 0.18, 0.28), w * 0.9, yaw, between(rand, 18, 30), between(rand, 25, 45),
					pick(C.cattailLeaf, rand), true, T.leafT * 0.6)
			end
		elseif string.find(p.id, "_spike", 1, true) ~= nil then
			add(rec(p.id .. "_Velvet", v(b - a + 0.6, T.spike.w * 1.25, T.spike.w * 1.25), v(c.X, (a + b) / 2, c.Z), C.spike, "Fabric", false, "Cylinder", v(0, 0, 90)))
		elseif string.find(p.id, "_male", 1, true) ~= nil then
			add(rec(p.id .. "_Fluff", v(b - a, T.male.w * 2.2, T.male.w * 2.2), v(c.X, (a + b) / 2, c.Z), C.spikeMale, "Fabric", true, "Cylinder", v(0, 0, 90)))
		end
	end
end

local function pondDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local id = region.id
	local plan = PLAN[string.sub(id, 6)]
	local rand = rng(region.seed, 29)
	-- the low tier: the water, the pads, the lily, the stands' masses
	local _, wet = terrain(lo.X, hi.X, lo.Z, hi.Z)
	if wet then waterSheet(add, "Water", lo.X, hi.X, lo.Z, hi.Z) end
	for i, e in (plan.pads or {}) :: { { number } } do
		local x, z, d = lo.X + e[1], hi.Z - e[2], e[3]
		add(rec(`Pad{i}`, v(0.5, d, d), v(x, WATER + 0.12, z), pick(C.pad, rand), "SmoothPlastic", false, "Cylinder", v(0, 0, 90)))
		-- the notch to its middle, its veins, its red underside's rim where it curls (the full tier)
		local notch = between(rand, 0, 360)
		add(rec(`Notch{i}`, v(d * 0.5, 0.44, 0.3), v(x + math.cos(math.rad(notch)) * d * 0.25, WATER + 0.12, z - math.sin(math.rad(notch)) * d * 0.25), C.water, "SmoothPlastic", true, nil,
			v(0, notch, 0)))
		for vk = 1, 5 do
			local a = notch + vk * 60
			add(rec(`Vein{i}_{vk}`, v(d * 0.44, 0.04, 0.18), v(x + math.cos(math.rad(a)) * d * 0.22, WATER + 0.33, z - math.sin(math.rad(a)) * d * 0.22), "6f9a52", "SmoothPlastic", true, nil, v(0, a, 0)))
		end
		add(rec(`Rim{i}`, v(0.3, d * 1.01, d * 1.01), v(x, WATER + 0.02, z), C.padUnder, "SmoothPlastic", true, "Cylinder", v(0, 0, 90)))
		if rand() < 0.6 then add(drop(`PadDrop{i}`, v(x + between(rand, -d * 0.2, d * 0.2), WATER + 0.3, z + between(rand, -d * 0.2, d * 0.2)), between(rand, 0.4, 0.9), rand)) end
	end
	if plan.flower ~= nil then
		local fx, fz = lo.X + plan.flower[1], hi.Z - plan.flower[2]
		add(rec("LilyCup", v(7, 3, 7), v(fx, WATER + 1.5, fz), C.lily, "SmoothPlastic", false, "Ellipsoid"))
		for i = 1, 16 do
			local a = i / 16 * TAU + (if i % 2 == 0 then 0.2 else 0)
			local r = if i % 2 == 0 then 3.4 else 4.2
			add(rec(`Petal{i}`, v(4.6, 0.4, 1.6), v(fx + math.cos(a) * r, WATER + 1.2 + (if i % 2 == 0 then 1.2 else 0.4), fz + math.sin(a) * r), C.lily, "SmoothPlastic", true, "Ellipsoid",
				v(0, -math.deg(a), if i % 2 == 0 then 28 else 12)))
		end
		for i = 1, 10 do
			local a = i / 10 * TAU
			add(rec(`Stamen{i}`, v(0.4, 1.4, 0.4), v(fx + math.cos(a) * 1.3, WATER + 3.4, fz + math.sin(a) * 1.3), C.lilyEye, "SmoothPlastic", true))
		end
	end
	if plan.stand ~= nil then standDecor(add, plan.stand, -math.huge, CUT1, rand) end
	-- the stones wet at the waterline, the flat stone's lichen and the shelter's slab
	for _, p in Pond.pieces(region) do
		if string.find(p.id, "_stone_", 1, true) ~= nil or string.sub(p.id, -5) == "_flat" or string.sub(p.id, -5) == "_slab" then
			local c = (p.lo + p.hi) * 0.5
			local s = p.hi - p.lo
			add(rec(p.id .. "_Round", v(s.X * 1.08, math.min(s.Y, 4) * 1.1, s.Z * 1.08), v(c.X, p.hi.Y - math.min(s.Y, 4) * 0.5, c.Z), pick(C.stone, rand), "Slate", true, "Ellipsoid"))
			if p.lo.Y < WATER then
				add(rec(p.id .. "_Wet", v(s.X * 1.1, 1.2, s.Z * 1.1), v(c.X, WATER + 0.5, c.Z), C.stoneWet, "Slate", true, "Ellipsoid"))
			end
			if rand() < 0.5 then add(rec(p.id .. "_Lichen", v(2.2, 0.06, 1.6), v(c.X + between(rand, -1, 1), p.hi.Y + 0.03, c.Z + between(rand, -1, 1)), "9aa078", "SmoothPlastic", true, "Ellipsoid")) end
		end
	end
	-- the curled leaf drawn
	if plan.leaf ~= nil then
		local L = Pond.LEAF
		local lx, lz = lo.X + plan.leaf[1], hi.Z - plan.leaf[2]
		-- a long dead blade lying arched over the gap, its edges curled up
		add(rec("CurledLeaf", v(L.l + 0.6, L.thick, L.w * 0.6), v(lx, GT + L.gap + L.thick / 2, lz), C.cattailDead, "Fabric", false))
		add(rec("LeafCurlN", v(L.l + 0.6, L.thick * 0.8, L.w * 0.42), v(lx, GT + L.gap + 0.55, lz - L.w * 0.38), "a8925e", "Fabric", false, nil, v(-40, 0, 0)))
		add(rec("LeafCurlS", v(L.l + 0.6, L.thick * 0.8, L.w * 0.42), v(lx, GT + L.gap + 0.55, lz + L.w * 0.38), "a8925e", "Fabric", false, nil, v(40, 0, 0)))
		add(rec("LeafVein", v(L.l * 0.9, 0.05, 0.2), v(lx, GT + L.gap + L.thick + 0.03, lz), "b8a070", "Fabric", true))
	end
	-- the clumps drawn: each culm's blade over its box, the sedge's leaves arching from its crown, the heads
	for _, p in Pond.pieces(region) do
		if string.find(p.id, "_culm_", 1, true) ~= nil then
			local c = (p.lo + p.hi) * 0.5
			local rush = string.find(p.id, "_rush", 1, true) ~= nil
			add(rec(p.id .. "_Draw", if rush then v(p.hi.Y - p.lo.Y, 0.32, 0.32) else v(0.5, p.hi.Y - p.lo.Y, 0.5), c, pick(if rush then C.rush else C.sedge, rand), "SmoothPlastic", true,
				if rush then "Cylinder" else nil, if rush then v(0, 0, 90) else nil))
		elseif string.find(p.id, "_head_", 1, true) ~= nil then
			local c = (p.lo + p.hi) * 0.5
			for q = 1, 3 do
				add(rec(`{p.id}_Spikelet{q}`, v(0.8, 1.6, 0.8), c + v(between(rand, -0.5, 0.5), (q - 2) * 1.1, between(rand, -0.5, 0.5)), C.sedgeHead, "Fabric", true, "Ellipsoid"))
			end
		end
	end
	for i, e in (plan.sedge or {}) :: { { number } } do
		local x, z = lo.X + e[1], hi.Z - e[2]
		local base = groundAt(x, z)
		add(rec(`SedgeCrown{i}`, v(7, 3.5, 7), v(x, base + 1.2, z), pick(C.sedge, rand), "LeafyGrass", false, "Ellipsoid"))
		for b = 1, 10 do
			local yaw = b / 10 * 360 + between(rand, -15, 15)
			blade(add, `Sedge{i}_{b}`, v(x + math.cos(math.rad(yaw)) * 1.2, base, z - math.sin(math.rad(yaw)) * 1.2), between(rand, 25, 45), between(rand, 0.4, 0.6), yaw + 180,
				between(rand, 6, 16), if b % 2 == 0 then between(rand, 12, 30) else nil, pick(C.sedge, rand), true)
		end
	end
	for i, e in (plan.rush or {}) :: { { number } } do
		local x, z = planPoint(lo.X, hi.Z, e, 3)
		local base = groundAt(x, z)
		add(rec(`RushCrown{i}`, v(5, 4, 5), v(x, base + 1.5, z), pick(C.rush, rand), "LeafyGrass", false, "Ellipsoid"))
		for b = 1, 6 do
			blade(add, `RushStem{i}_{b}`, v(x + between(rand, -2.4, 2.4), base, z + between(rand, -2.4, 2.4)), between(rand, 40, 60), 0.28, between(rand, 0, 360), between(rand, 4, 14), nil,
				pick(C.rush, rand), true, 0.28)
		end
	end
	-- the waterline: a dark wet band along the bank's edge and a scum of pollen and duckweed against it; the bank's mud mottled, a footprint of a bird
	local lands = terrain(lo.X, hi.X, lo.Z, hi.Z)
	for i, l in lands do
		local xc, w = (l.x0 + l.x1) / 2, l.x1 - l.x0
		-- the step down toward the water rounded off: a lip of mud along each land box's north edge where the ground beyond it is lower (the next band, or the water)
		local beyond = groundAt(xc, l.z0 - 0.5)
		if l.z0 > lo.Z + 0.5 and beyond < l.top - 0.5 then
			local drop = l.top - beyond
			add(rec(`Lip{i}`, v(w + 0.4, drop * 1.15, math.min(4, drop * 1.4)), v(xc, l.top - drop * 0.6, l.z0), if l.band == "bank" then C.mudDark else C.mudWet,
				"Mud", true, "Ellipsoid"))
		end
		if l.band == "wet" then
			add(rec(`Sheen{i}`, v(w, 0.06, l.z1 - l.z0), v(xc, l.top + 0.03, (l.z0 + l.z1) / 2), "2c2722", "Mud", true))
			if beyond <= WATER then add(rec(`Scum{i}`, v(w, 0.06, 3), v(xc, WATER + 0.04, l.z0 - 1.5), C.duckweed, "SmoothPlastic", true)) end
		elseif l.band == "bank" and (l.z1 - l.z0) > 10 then
			-- the bank's grass, short and patchy, and the mud between
			for t = 1, 2 do
				add(rec(`BankTuft{i}_{t}`, v(between(rand, 3, 7), between(rand, 1.5, 3.5), between(rand, 3, 6)), v(between(rand, l.x0 + 3, l.x1 - 3), l.top + 0.9, between(rand, l.z0 + 3, l.z1 - 3)),
					pick({ "6f8a46", "7d8a4e", "5f7a3e" }, rand), "Grass", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
			end
			if rand() < 0.5 then
				add(rec(`Mottle{i}`, v(between(rand, 6, 14), 0.06, between(rand, 4, 10)), v(between(rand, l.x0 + 4, l.x1 - 4), l.top + 0.03, between(rand, l.z0 + 4, l.z1 - 4)), "5a4a36", "Mud", true,
					"Ellipsoid", v(0, between(rand, 0, 180), 0)))
			end
		end
	end
	-- under the water: the bed's dark, a sunken leaf, a few stems of last year
	if wet then
		for i = 1, 3 do
			add(rec(`Sunk{i}`, v(between(rand, 4, 8), 0.1, between(rand, 2.5, 5)), v(between(rand, lo.X + 6, hi.X - 6), BED + 0.1, between(rand, lo.Z + 6, hi.Z - 6)), pick({ "4a3a28", "3a2e20", "5a4630" }, rand),
				"Fabric", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
		end
		for i = 1, 2 do
			add(rec(`Stem{i}`, v(0.4, between(rand, 8, 16), 0.4), v(between(rand, lo.X + 6, hi.X - 6), BED + 6, between(rand, lo.Z + 6, hi.Z - 6)), "4a4630", "SmoothPlastic", true, nil,
				v(between(rand, -20, 20), 0, between(rand, -30, 30))))
		end
	end
end

local function deckDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local rand = rng(region.seed, 11)
	local south = string.sub(region.id, 6, 6) == "s"
	-- the low tier: the dark between the boards (so the gaps read), the post's shadow
	add(rec("Under", v(hi.X - lo.X, 0.2, hi.Z - lo.Z), v((lo.X + hi.X) / 2, DECK - Pond.BOARD.thick - 0.4, (lo.Z + hi.Z) / 2), "1e1a14", "SmoothPlastic", false))
	-- the full tier: each board's grain, its nails at the ends over the beams, a knot or two, lichen and grit
	for _, p in Pond.pieces(region) do
		if string.find(p.id, "_board_", 1, true) ~= nil then
			local zc = (p.lo.Z + p.hi.Z) / 2
			add(rec(p.id .. "_Grain", v(p.hi.X - p.lo.X - 1, 0.03, 0.3), v((p.lo.X + p.hi.X) / 2, DECK + 0.015, zc + between(rand, -4, 4)), "6a5640", "Wood", true))
			for _, nx in { p.lo.X + 4, p.hi.X - 4 } do
				for _, dz in { -4, 4 } do add(rec(`{p.id}_Nail{nx}_{dz}`, v(0.06, 0.5, 0.5), v(nx, DECK + 0.03, zc + dz), "4a4a48", "Metal", true, "Cylinder", v(0, 0, 90))) end
			end
			if rand() < 0.35 then add(rec(p.id .. "_Knot", v(1.6, 0.04, 1.1), v(between(rand, p.lo.X + 8, p.hi.X - 8), DECK + 0.02, zc), "4a3a28", "Wood", true, "Ellipsoid")) end
		end
	end
	for i = 1, 2 do
		add(rec(`Lichen{i}`, v(between(rand, 1.5, 3), 0.05, between(rand, 1.2, 2.6)), v(between(rand, lo.X + 4, hi.X - 4), DECK + 0.03, between(rand, lo.Z + 10, hi.Z - 10)),
			pick({ "b8b88a", "9aa078", "c9c49a" }, rand), "SmoothPlastic", true, "Ellipsoid"))
	end
	if rand() < 0.5 then
		add(rec("Leaf", v(5, 0.08, 3.4), v(between(rand, lo.X + 10, hi.X - 10), DECK + 0.05, between(rand, lo.Z + 12, hi.Z - 12)), pick({ "b0702a", "8a6a3a", "c09a3a" }, rand), "Fabric", true,
			"Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	-- the water or the mud under its north edge (the core's)
	local _, wet = terrain(lo.X, hi.X, lo.Z, hi.Z)
	if wet then waterSheet(add, "Water", lo.X, hi.X, lo.Z, hi.Z) end
	if not south then add(rec("PostCap", v(10.4, 0.4, 10.4), v(lo.X + 8, DECK - Pond.BOARD.thick - 15.2, lo.Z + 5), "4a3e30", "Wood", true)) end
end

local function pathDecor(region: Region, add: (Drawn) -> boolean)
	local lo, hi = region.bounds[1], region.bounds[2]
	local rand = rng(region.seed, 13)
	add(rec("Stripe", v(hi.X - lo.X, 0.06, hi.Z - lo.Z), v((lo.X + hi.X) / 2, GT + 0.03, (lo.Z + hi.Z) / 2), pick(C.mown, rand), "Grass", false))
	-- cut tufts, a clover, a plantain's rosette, a dandelion's, a fallen leaf
	for i = 1, 14 do
		local x, z = between(rand, lo.X + 3, hi.X - 3), between(rand, lo.Z + 3, hi.Z - 3)
		add(rec(`Tuft{i}`, v(between(rand, 3, 7), between(rand, 1.2, 2.6), between(rand, 2.5, 6)), v(x, GT + 0.8, z), pick(C.mown, rand), "Grass", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	for i = 1, 3 do
		local x, z = between(rand, lo.X + 8, hi.X - 8), between(rand, lo.Z + 8, hi.Z - 8)
		local kind = rand()
		if kind < 0.4 then
			for l = 1, 3 do add(rec(`Clover{i}_{l}`, v(1.1, 0.1, 1.1), v(x + math.cos(l * 2.1) * 0.7, GT + 0.3, z + math.sin(l * 2.1) * 0.7), "5f8a3e", "SmoothPlastic", true, "Ellipsoid")) end
		elseif kind < 0.75 then
			for l = 1, 5 do
				local a = l / 5 * 360
				add(rec(`Plantain{i}_{l}`, v(7, 0.15, 2.6), v(x + math.cos(math.rad(a)) * 3.2, GT + 0.2, z - math.sin(math.rad(a)) * 3.2), "4f7a3a", "SmoothPlastic", true, "Ellipsoid", v(0, a, 0)))
			end
		else
			add(rec(`Leaf{i}`, v(5, 0.08, 3.4), v(x, GT + 0.1, z), pick({ "b0702a", "8a6a3a", "c09a3a" }, rand), "Fabric", true, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
		end
	end
end

local function cattailDecor(region: Region, add: (Drawn) -> boolean)
	local k = tonumber(string.sub(region.id, 9, 9)) :: number
	local upper = string.sub(region.id, 10, 10) == "b"
	local rand = rng(region.seed, 17)
	if upper then standDecor(add, k, CUT2, math.huge, rand) else standDecor(add, k, CUT1, CUT2, rand) end
end

-- ---------------------------------------------------------------- the patches: what the spider sees close
-- Each margin cell is cut into patches of World/Hut.PATCH studs (kind "patch", drawn only near the spider, World/LookPlan): on the water duckweed (a frond of 2 to 4
-- mm, in rafts against the bank and the stems), floating seeds and fluff from the cattails, a midge's shuck, bubbles; on the wet mud crumbs, a snail's shell, a
-- bird's print, grit and the dew; on the bank short grass and a seedling.
local patchParent: { [string]: Region } = {}
function Pond.patches(regions: { Region }, worldSeed: number, seedOf: (number, string) -> number): { Region }
	local out: { Region } = {}
	local size = Hut.PATCH
	for _, r in regions do
		if r.kind == "pond" then
			local lo, hi = r.bounds[1], r.bounds[2]
			local nx = math.max(1, math.ceil((hi.X - lo.X) / size - 1e-6))
			local nz = math.max(1, math.ceil((hi.Z - lo.Z) / size - 1e-6))
			local dx, dz = (hi.X - lo.X) / nx, (hi.Z - lo.Z) / nz
			for i = 1, nx do
				for j = 1, nz do
					local pid = `{r.id}~{i}_{j}`
					local plo, phi = v(lo.X + (i - 1) * dx, WATER - 2, lo.Z + (j - 1) * dz), v(lo.X + i * dx, GT + 40, lo.Z + j * dz)
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
-- The region a patch of the pond's belongs to (nil for one that is not the pond's).
function Pond.patchParent(patch: Region): Region?
	return patchParent[patch.id]
end

-- The standing boxes of a cell (what the near detail keeps clear of): everything but the terrain.
local function standing(region: Region): { Box }
	local out: { Box } = {}
	for _, p in Pond.pieces(region) do
		if not (string.find(p.id, "_bank_", 1, true) or string.find(p.id, "_damp_", 1, true) or string.find(p.id, "_wet_", 1, true) or string.sub(p.id, -4) == "_bed") then
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
	local k = 0
	local function surface(x: number, z: number): (string, number)
		local lands = terrain(x - 0.01, x + 0.01, z - 0.01, z + 0.01)
		if #lands == 0 then return "water", WATER end
		return lands[1].band, lands[1].top
	end
	local function frond(x: number, z: number, full: boolean)
		k += 1
		local s = between(rand, 0.25, 0.45)
		add(rec(`Frond{k}`, v(s, 0.05, s * 0.75), v(x, WATER + 0.03, z), pick({ C.duckweed, "8cc050", "6fa040" }, rand), "SmoothPlastic", full, "Ellipsoid", v(0, between(rand, 0, 180), 0)))
	end
	local dews = 0
	for pass = 1, 6 do
		for _ = 1, 8 do
			local x, z = between(rand, lo.X + 1, hi.X - 1), between(rand, lo.Z + 1, hi.Z - 1)
			if not clear(boxes, x, z, 0.8) then continue end
			local kind, top = surface(x, z)
			local full = pass > 1
			if kind == "water" then
				-- duckweed in little rafts, thicker by the bank (a wet band's edge near) and round the stems
				local roll = rand()
				if roll < 0.6 then
					for _ = 1, 3 do frond(x + between(rand, -1.2, 1.2), z + between(rand, -1.2, 1.2), full) end
				elseif roll < 0.75 then
					k += 1
					add(rec(`Fluff{k}`, v(0.6, 0.3, 0.6), v(x, WATER + 0.15, z), "e8e2d0", "Fabric", true, "Ball")) -- (a cattail's seed on its down)
				elseif roll < 0.85 then
					k += 1
					add(rec(`Shuck{k}`, v(0.5, 0.08, 0.12), v(x, WATER + 0.04, z), "c8c0a8", "SmoothPlastic", true, nil, v(0, between(rand, 0, 180), 0))) -- (a midge's pupal skin)
				elseif roll < 0.92 then
					k += 1
					local b = rec(`Bubble{k}`, v(0.35, 0.2, 0.35), v(x, WATER + 0.08, z), "e6eef0", "Glass", true, "Ball")
					b.transparency = 0.5
					add(b)
				else
					k += 1
					add(rec(`Float{k}`, v(between(rand, 1.5, 3), 0.06, between(rand, 0.8, 1.6)), v(x, WATER + 0.04, z), pick({ "8a6a3a", "a08a5a", "6a5a3a" }, rand), "Fabric", true, "Ellipsoid",
						v(0, between(rand, 0, 180), 0)))
				end
			elseif kind == "wet" or kind == "damp" then
				local roll = rand()
				if roll < 0.45 then
					k += 1
					add(rec(`Crumb{k}`, v(between(rand, 0.6, 1.4), 0.35, between(rand, 0.5, 1.1)), v(x, top + 0.12, z), pick({ "3a3024", "4a3c2c", "2e261e" }, rand), "Mud", full, "Ellipsoid"))
				elseif roll < 0.65 then
					k += 1
					add(rec(`Grit{k}`, v(0.4, 0.25, 0.35), v(x, top + 0.1, z), pick(C.stone, rand), "Pebble", true, "Ellipsoid"))
				elseif roll < 0.72 then
					k += 1
					add(rec(`Shell{k}`, v(0.9, 0.7, 0.9), v(x, top + 0.35, z), "c8b89a", "SmoothPlastic", true, "Ball")) -- (a pond snail's empty shell)
				elseif roll < 0.8 then
					-- a bird's print in the mud: three toes
					k += 1
					local a = between(rand, 0, 360)
					for t = -1, 1 do
						add(rec(`Toe{k}_{t}`, v(2.4, 0.05, 0.3), v(x + math.cos(math.rad(a + t * 35)) * 1.2, top + 0.02, z - math.sin(math.rad(a + t * 35)) * 1.2), "2a221a", "Mud", true, nil,
							v(0, a + t * 35, 0)))
					end
				elseif dews < 3 then
					dews += 1
					add(drop(`Dew{dews}`, v(x, top + 0.2, z), between(rand, 0.3, 0.5), rand))
				end
			else
				-- the bank: short grass and a seedling
				k += 1
				local spin = between(rand, 0, 360)
				for b = 1, 3 do
					blade(add, `Grass{k}_{b}`, v(x + between(rand, -0.4, 0.4), top, z + between(rand, -0.4, 0.4)), between(rand, 2, 6), between(rand, 0.25, 0.4), spin + b * 120,
						between(rand, 4, 20), nil, pick(C.mown, rand), full or b > 1)
				end
			end
		end
	end
end

local decorCache: { [string]: { Drawn } } = {}
-- The region's drawn records (or a patch of the pond's), within its kind's budget at both tiers; the same list for the same region.
function Pond.decor(region: Region): { Drawn }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = decorCache[key]
	if cached ~= nil then return cached end
	local budget = if region.kind == "patch" then Hut.BUDGETS.patch else Pond.BUDGETS[region.kind]
	assert(budget ~= nil, "no budget for the region kind " .. region.kind)
	local list, add = sheet(budget)
	local k = region.kind
	if k == "pond" then pondDecor(region, add)
	elseif k == "boardwalk" then deckDecor(region, add)
	elseif k == "mown_path" then pathDecor(region, add)
	elseif k == "cattail" then cattailDecor(region, add)
	elseif k == "patch" then patchDecor(region, add) end
	for _, d in list do table.freeze(d) end
	decorCache[key] = table.freeze(list)
	return list
end

-- ---------------------------------------------------------------- the life
-- Non-biting midges (Chironomidae) and mosquitoes (Culicidae) resting on the rushes' stems and the cattails' leaves by day and restless from dusk, holding in the
-- air over the water as a swarm does as far as the flight model allows (their profiles' hover); eastern forktail damselflies perched on the cattails by day; water
-- striders skating the open water (Prey/Skater, ambient). From each region's own seed by streams of their own.
Pond.LIFE = table.freeze({
	midges = { pond_a3 = { full = 4, low = 2 }, pond_c1 = { full = 3, low = 1 } },
	mosquitoes = { pond_b1 = { full = 2, low = 1 }, pond_a2 = { full = 1, low = 1 } },
	damselflies = { pond_b2 = { full = 2, low = 1 } },
	skaters = { pond_b3 = { full = 4, low = 2, salt = 163 }, pond_c2 = { full = 3, low = 1, salt = 167 } },
})

export type Perch = Hut.Perch
local function spot(p: Vector3, n: Vector3, sh: number, fo: number): { any }
	return { p, n, sh, fo }
end
local function spots(region: Region, kind: string, list: { { any } }, starts: number): { Perch }
	local out: { Perch } = {}
	for i, sp in list do
		table.insert(out, { id = `{region.id}_{kind}_{i}`, position = sp[1], normal = sp[2], shelter = sp[3], food = sp[4], start = i <= starts, kind = "stem" } :: any)
	end
	return out
end

-- Perches on the stems and leaves of a cell (its culms and the cattails' lower leaves), on their faces at heights from `y0` to `y1` over the water: spots a short flight
-- apart, each on a face looking out east or west.
local function stemSpots(region: Region, y0: number, y1: number, n: number, rand: () -> number): { { any } }
	local list: { { any } } = {}
	local stems: { Piece } = {}
	for _, p in Pond.pieces(region) do
		if (string.find(p.id, "_culm_", 1, true) ~= nil or string.find(p.id, "_leaf_", 1, true) ~= nil) and p.hi.Y > WATER + y0 + 4 then table.insert(stems, p) end
	end
	if #stems == 0 then return list end
	for i = 1, n do
		local p = stems[1 + (i * 3 + math.floor(rand() * 2)) % #stems]
		local y = math.min(p.hi.Y - 2, WATER + between(rand, y0, y1))
		-- (the east and west faces: a fly's resting heading is along -z, which a north or south face would leave pointing out of it)
		local faces = { { v(p.hi.X, y, (p.lo.Z + p.hi.Z) / 2), Vector3.xAxis }, { v(p.lo.X, y, (p.lo.Z + p.hi.Z) / 2), -Vector3.xAxis } }
		local f = faces[1 + (i - 1) % 2]
		table.insert(list, spot(f[1] :: Vector3, f[2] :: Vector3, 0.3, 0.4))
	end
	return list
end

local bestiaryCache: { [string]: any } = {}
function Pond.bestiary(region: Region): { any }?
	local L = Pond.LIFE
	local midge, mosquito, damsel = L.midges[region.id], L.mosquitoes[region.id], L.damselflies[region.id]
	if midge == nil and mosquito == nil and damsel == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if bestiaryCache[key] ~= nil then return bestiaryCache[key] end
	local out = {}
	local function kind(name: string, profile: string, row: { full: number, low: number }, salt: number, y0: number, y1: number, n: number, dusk: boolean)
		local rand = rng(region.seed, salt)
		local list = stemSpots(region, y0, y1, n, rand)
		if #list == 0 then return end
		local first = list[1][1] :: Vector3
		local spec: any = { kind = name, profile = profile, perches = spots(region, name, list, row.full),
			vents = { { id = `{region.id}_vent_{name}`, position = first + v(0, 14, 0), normal = Vector3.yAxis, appear = true, reach = 60 } }, target = row.full, low = row.low,
			seed = (region.seed + salt * 104729) % MOD, prefix = `{region.id}_{name}_fly_` }
		if dusk then spec.dusk = { from = 18.5, to = 6 } end
		table.insert(out, spec)
	end
	if midge ~= nil then kind("midge", "midge_prototype", midge, 173, 10, 45, 7, true) end
	if mosquito ~= nil then kind("mosquito", "mosquito_prototype", mosquito, 179, 8, 40, 6, true) end
	if damsel ~= nil then kind("damselfly", "damselfly_prototype", damsel, 181, 20, 60, 5, false) end
	-- (the band each kind's flights climb in: from under its lowest perch to 11 cm over its highest, PerchGraph.plan)
	for _, k in out do
		local lo, hi = math.huge, -math.huge
		for _, p in k.perches do lo, hi = math.min(lo, p.position.Y), math.max(hi, p.position.Y) end
		k.floor, k.ceiling = lo - 2, hi + 11
	end
	bestiaryCache[key] = out
	return out
end

local ambientCache: { [string]: any } = {}
-- The water striders (Prey/Skater): their starts on the open water of the cell, the water's rectangle they skate (`water`), the stems and pads they skate round.
function Pond.ambient(region: Region): { any }?
	local row = Pond.LIFE.skaters[region.id]
	if row == nil then return nil end
	local key = region.id .. "/" .. tostring(region.seed)
	if ambientCache[key] ~= nil then return ambientCache[key] end
	local lo, hi = region.bounds[1], region.bounds[2]
	local boxes = standing(region)
	local rand = rng(region.seed, row.salt)
	local spec: any = { kind = "skater", seed = (region.seed + row.salt * 104729) % MOD, full = row.full, low = row.low, starts = {}, prefix = region.id .. "_", surface = "water",
		water = { min = v(lo.X, WATER - 1, lo.Z), max = v(hi.X, WATER, hi.Z) }, boxes = boxes }
	for _ = 1, row.full do
		for _ = 1, 40 do
			local x, z = between(rand, lo.X + 6, hi.X - 6), between(rand, lo.Z + 6, hi.Z - 6)
			local zw = Pond.waterline(x)
			if zw ~= nil and z < zw - 4 and clear(boxes, x, z, 2) then
				local h = between(rand, 0, TAU)
				table.insert(spec.starts, { pos = v(x, WATER, z), heading = v(math.cos(h), 0, math.sin(h)) })
				break
			end
		end
	end
	local out = { spec }
	ambientCache[key] = out
	return out
end

-- The regions the rival roams here (Predator/RivalSpider.roam): none yet; the boardwalk and the pond are the spider's own this round.
Pond.ROAM = table.freeze({}) :: { [string]: boolean }

-- ---------------------------------------------------------------- the frog's seats (Predator/Frog)
-- The green frog sits on one of these a day (its seeded draw): the flat stone at the water's edge in pond_a2, or the big lily pad in pond_b4. `facing`: where it faces
-- from it (toward the open margin).
export type FrogSite = { region: string, piece: string, facing: Vector3 }
Pond.FROG_SITES = table.freeze({
	table.freeze({ region = "pond_a2", piece = "pond_a2_flat", facing = v(0.6, 0, 0.8).Unit }),
	table.freeze({ region = "pond_b4", piece = "pond_b4_pad_1_mid", facing = v(-0.7, 0, 0.7).Unit }),
}) :: { FrogSite }
-- A site's seat, from its region's boxes: the top middle of its piece.
function Pond.frogSeat(site: FrogSite, regions: { Region }): Vector3?
	for _, r in regions do
		if r.id == site.region then
			for _, p in Pond.pieces(r) do
				if p.id == site.piece then return v((p.lo.X + p.hi.X) / 2, p.hi.Y, (p.lo.Z + p.hi.Z) / 2) end
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the dragonfly's beat (drawn only: Client/PondBodies)
-- A green darner (Anax junius) patrols over the open pond by day: a loop over the water east and north of the core 0.8 to 1.6 m up, at about 2 m a second, with a
-- seeded weave, darting now and then. A pure function of the seed and the time: where it is, which way it faces, and whether it is out (by day, 8:00 to 19:00).
Pond.DARNER = table.freeze({ x = 1125, z = -1516, rx = 420, rz = 300, speed = 200, from = 8, to = 19 })
function Pond.darner(seed: number, t: number, hour: number): (Vector3?, Vector3)
	local D = Pond.DARNER
	if hour < D.from or hour >= D.to then return nil, Vector3.xAxis end
	local s = (seed % 997) / 997
	local perimeter = TAU * math.sqrt((D.rx * D.rx + D.rz * D.rz) / 2)
	local a = (t * D.speed / perimeter) * TAU + s * TAU
	local weave = math.sin(a * 3.1 + s * 9) * 40
	local x = D.x + math.cos(a) * (D.rx + weave)
	local z = D.z + math.sin(a) * (D.rz + weave * 0.6)
	local y = WATER + 110 + math.sin(a * 2.3 + s * 5) * 35
	local dx, dz = -math.sin(a) * D.rx, math.cos(a) * D.rz
	local h = v(dx, 0, dz)
	return v(x, y, z), if h.Magnitude > 1e-6 then h.Unit else Vector3.xAxis
end

return Pond
