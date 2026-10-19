--!strict
-- The world outside the glass (ROBLOX-95, docs/OPEN_WORLD_DESIGN.md W2): the generators of the three regions under the window, as pure data. Region asks here for every
-- kind that is not the sill; nothing here builds a part or knows the engine, so the server, the client and the CLI tests all get the same boxes from the same region.
--   outer_sill .. the stone slab the raised sash opens onto (top y 0, x -30..30, z -24..-13.5) and the window box's two halves that stand on it (Data/Flora's
--                 garden box, drawn by the sill's Decor and solid here); its look is worn paint over stone, moss in the corners, grit and rain streaks down its face.
--   house_wall ... the brick wall under it, face at z -24 from y 0 to the lawn at y -90.4, x -40..40: one box below the slab and two shoulders beside it, all
--                 drawn as brick courses over recessed mortar (the boxes turn invisible once the bricks exist), with the house going on above the outer sill
--                 around the window (drawn only).
--   bed .......... the soil under the window (top y -90, x -25..25, z -24..-74): soil mounds, three stones (one raised on two rests over a gap, the bed's
--                 retreat, World/WorldMap's bed_a_stone), two plants whose stems and leaves are boxes as the Pilea's are, and drawn soil, leaf litter, grass,
--                 twigs, pebbles, lichen and moss.
-- Everything placed is placed from the region's own seed (WorldMap.seed), by a Park-Miller stream of its own for each kind of thing, so the same region is the
-- same garden forever, and a drawn thing that the low tier drops (`full`) never moves what the low tier keeps. The physical pieces are the walkable world: the
-- motor walks their faces, RivalRoute builds the region's graph from them. A drawn record is one part (Habitat/Scenery.look builds them); the region's budget
-- (Region.budget) is a ceiling the placer keeps to at both tiers, and tests/world.luau holds the counts.
local Flora = require(script.Parent.Parent.Data.Flora)
local WorldMap = require(script.Parent.WorldMap)

local Garden = {}

-- A physical box (WindowsillLayout.Piece) with the material it is drawn in when nothing draws it instead.
export type Piece = { id: string, lo: Vector3, hi: Vector3, profile: string, color: Color3, material: string? }
-- A drawn-only part: centred `at`, `size`, turned by `turn` (degrees about X, Y and Z, in that order, as CFrame.Angles), `shape` "Block" (the default),
-- "Ball", "Cylinder" (its axis along X) or "Ellipsoid" (a sphere mesh); `full`: the low tier drops it (FullOnly); `group`: the folder it is built into.
export type Drawn = {
	id: string, size: Vector3, at: Vector3, color: Color3, transparency: number?,
	material: string?, shape: string?, turn: Vector3?, full: boolean?, group: string?, shadow: boolean?,
}
export type Box = { min: Vector3, max: Vector3 }

local TAU = 2 * math.pi
local MOD = 2147483647

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
-- A Park-Miller stream from the region's seed and a salt for the kind of thing it places (the same stream as Habitat/Shapes.rng).
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
local function overlaps(a: Box, b: Box, margin: number): boolean
	return a.min.X < b.max.X + margin and a.max.X > b.min.X - margin and a.min.Z < b.max.Z + margin and a.max.Z > b.min.Z - margin
end

-- ---------------------------------------------------------------- the outer sill
Garden.OUTER = {
	slab = { lo = v(-30, -3, -24), hi = v(30, 0, -13.5), color = "ddd5c3", material = "Concrete" }, -- painted stone, the paint gone dull
	stone = { "a29d92", "948f85", "aaa497" }, -- where the paint has gone
	moss = { "5f7d3a", "6d8c45", "53703a", "7a9450" },
	grit = { "7d7466", "6a6358", "9b9284", "57514a", "b0a898" },
	streak = "8e8a80",
}

-- ---------------------------------------------------------------- the house wall
Garden.WALL = {
	face = -24, foot = -90.4, under = -3, top = 0, west = -40, east = 40, back = -13.5,
	brick = { length = 21.5, height = 6.5, joint = 1.0, depth = 0.6, recess = 0.28, gap = 0.02 },
	bricks = { "9c4a32", "a65538", "8f4430", "b0603e", "974d36", "a2573c", "7e3c2b" },
	burnt = "5e3428", pale = "c08a64", mortar = "b8b1a3", plaster = "efe8d8", coping = "c9c2b3",
	above = 30, window = { x0 = -31, x1 = 31, y1 = 14 }, -- the house above the outer sill goes up to y 30, round the window's frame
	brickMaterial = "Concrete", mortarMaterial = "Plaster",
}

-- ---------------------------------------------------------------- the bed
Garden.BED = {
	x0 = -25, x1 = 25, z0 = -74, z1 = -24, top = -90, bottom = -92,
	soil = "4a3a2c", soilMaterial = "Ground",
	landing = 5.0, -- the strip along the wall's foot kept flat for whatever comes down the wall
	mounds = { count = 6, w = { 4, 9 }, d = { 3, 7 }, h = { 0.4, 1.3 }, colors = { "4f3e2f", "574433", "45362a", "5c4a39" } },
	stones = { count = 2, w = { 3.2, 6.0 }, d = { 2.6, 4.8 }, h = { 1.0, 2.2 }, colors = { "8d8a83", "7e7b74", "9a968d" }, material = "Slate" },
	retreatStone = { over = 1.6, thick = 1.6, rest = 1.4, color = "85827a", rests = "77746d", material = "Slate" }, -- round the map's retreat box
	-- the plants: a dock seedling (one stem, three leaves along it) and a dandelion (a rosette of four leaves on the soil and a flower stalk)
	dock = { stem = 0.8, height = 18, leaves = { { y = 6, dir = "x+", l = 6.5, w = 4.4 }, { y = 11, dir = "z+", l = 5.5, w = 3.8 }, { y = 15, dir = "x-", l = 4.5, w = 3.2 } }, thick = 0.3 },
	dandelion = { leaf = { l = 4.6, w = 2.0, h = 0.25, gap = 0.75 }, stalk = 0.6, height = 12 }, -- (gap: the leaves start clear of the stalk and of each other)
	leaf = { top = "4d7a36", rim = "3c6630", under = "8fb36a", rib = "a7c98a", stem = "5d8a3e", material = "SmoothPlastic", rimOut = 0.12, underOut = 0.03, underThick = 0.1 },
	flower = { head = "f2c40c", disc = "d99a06", sepals = "4f7d35" },
	litter = { count = 70, size = { 0.9, 2.8 }, colors = { "8a6239", "a07445", "6e4d2e", "b88c52", "5b4129", "c4a061" }, lowEvery = 3 },
	grass = { tufts = 16, blades = 5, keep = 2, height = { 1.4, 3.2 }, colors = { "5c8a3a", "6f9a46", "4f7a33", "86a85a" }, dry = "b8a46a" },
	twigs = { count = 9, length = { 2, 6 }, width = 0.18, colors = { "5a4632", "6b5640", "4a3a2a" } },
	pebbles = { count = 24, size = { 0.25, 0.8 }, colors = { "a9a59c", "938f87", "bdb8ad", "7f7b74" } },
	mottle = { count = 12, size = { 3, 8 }, colors = { "3f3126", "54412f", "463729" } },
}

-- ---------------------------------------------------------------- the pieces
local function outerPieces(): { Piece }
	local O = Garden.OUTER
	local out: { Piece } = {
		{ id = "outer_sill_slab", lo = O.slab.lo, hi = O.slab.hi, profile = "brick_rough", color = hex(O.slab.color), material = O.slab.material },
	}
	local B = Flora.garden.box
	for _, half in B.boxes do
		table.insert(out, { id = half.id, lo = v(half.x0, B.bottom, B.z0), hi = v(half.x1, B.top, B.z1), profile = "painted_wood_dry", color = hex(B.color), material = "Wood" })
	end
	return out
end

local function wallPieces(): { Piece }
	local W = Garden.WALL
	local brick = hex(W.bricks[1])
	return {
		{ id = "house_wall", lo = v(W.west, W.foot, W.face), hi = v(W.east, W.under, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
		{ id = "house_wall_west", lo = v(W.west, W.under, W.face), hi = v(Garden.OUTER.slab.lo.X, W.top, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
		{ id = "house_wall_east", lo = v(Garden.OUTER.slab.hi.X, W.under, W.face), hi = v(W.east, W.top, W.back), profile = "brick_rough", color = brick, material = W.brickMaterial },
	}
end

-- The bed's stone over its retreat: a slab on two rests, the gap between them the map's retreat box (WorldMap bed_a_stone) and a little more.
local function stoneOver(retreat: WorldMap.Retreat): { Piece }
	local S = Garden.BED.retreatStone
	local lo, hi = retreat.min, retreat.max
	local top = lo.Y + S.over
	local x0, x1 = lo.X - 0.2 - S.rest, hi.X + 0.2 + S.rest
	local z0, z1 = lo.Z - 0.8, hi.Z + 0.8
	return {
		{ id = "bed_a_stone_top", lo = v(x0, top, z0), hi = v(x1, top + S.thick, z1), profile = "brick_rough", color = hex(S.color), material = S.material },
		{ id = "bed_a_stone_west", lo = v(x0, lo.Y, z0), hi = v(x0 + S.rest, top, z1), profile = "brick_rough", color = hex(S.rests), material = S.material },
		{ id = "bed_a_stone_east", lo = v(x1 - S.rest, lo.Y, z0), hi = v(x1, top, z1), profile = "brick_rough", color = hex(S.rests), material = S.material },
	}
end

-- The bed: the soil, the stone over the retreat, then from the region's seed the two plants, two more stones and the mounds, each where it overlaps nothing
-- placed before it (a stride apart), off the landing strip under the wall and clear of the spawn.
local function bedPieces(region: WorldMap.Region): { Piece }
	local B = Garden.BED
	local out: { Piece } = {
		{ id = "bed_a_soil", lo = v(B.x0, B.bottom, B.z0), hi = v(B.x1, B.top, B.z1), profile = "brick_rough", color = hex(B.soil), material = B.soilMaterial },
	}
	local taken: { Box } = {}
	for _, t in region.retreats do
		for _, p in stoneOver(t) do table.insert(out, p) end
		table.insert(taken, { min = t.min - v(2.4, 0, 2.6), max = t.max + v(2.4, 0, 2.6) })
	end
	local spawn = region.spawn.pos
	table.insert(taken, { min = spawn - v(2.5, 0, 2.5), max = spawn + v(2.5, 0, 2.5) })
	-- somewhere free for a footprint w x d, or nil after sixty tries
	local function spot(rand: () -> number, w: number, d: number, margin: number): (number?, number?)
		for _ = 1, 60 do
			local x = between(rand, B.x0 + 1.5, B.x1 - 1.5 - w)
			local z = between(rand, B.z0 + 1.5, B.z1 - B.landing - d)
			local box = { min = v(x, 0, z), max = v(x + w, 0, z + d) }
			local free = true
			for _, other in taken do
				if overlaps(box, other, margin) then free = false; break end
			end
			if free then
				table.insert(taken, box)
				return x, z
			end
		end
		return nil, nil
	end
	-- the dock: a stem and three leaves along it, each leaf's underside on the stem's side (a spider climbing the stem meets it from below and walks out under it)
	local prand = rng(region.seed, 23)
	local D = B.dock
	local reachX, reachZ = 0.0, 0.0
	for _, leaf in D.leaves do
		if leaf.dir == "x+" or leaf.dir == "x-" then reachX = math.max(reachX, leaf.l) else reachZ = math.max(reachZ, leaf.l) end
	end
	local dx, dz = spot(prand, D.stem + 2 * reachX, D.stem + 2 * reachZ, 1.5)
	if dx ~= nil and dz ~= nil then
		local sx, sz = dx + reachX, dz + reachZ
		local s0, s1 = v(sx, B.top, sz), v(sx + D.stem, B.top + D.height, sz + D.stem)
		table.insert(out, { id = "bed_a_dock_stem", lo = s0, hi = s1, profile = "leaf_dry_prototype", color = hex(B.leaf.stem) })
		for i, leaf in D.leaves do
			local y0, y1 = B.top + leaf.y, B.top + leaf.y + D.thick
			local half = leaf.w / 2
			local mz, mx = sz + D.stem / 2, sx + D.stem / 2
			local lo, hi
			if leaf.dir == "x+" then lo, hi = v(s1.X, y0, mz - half), v(s1.X + leaf.l, y1, mz + half)
			elseif leaf.dir == "x-" then lo, hi = v(s0.X - leaf.l, y0, mz - half), v(s0.X, y1, mz + half)
			elseif leaf.dir == "z+" then lo, hi = v(mx - half, y0, s1.Z), v(mx + half, y1, s1.Z + leaf.l)
			else lo, hi = v(mx - half, y0, s0.Z - leaf.l), v(mx + half, y1, s0.Z) end
			table.insert(out, { id = `bed_a_dock_leaf_{i}`, lo = lo, hi = hi, profile = "leaf_dry_prototype", color = hex(B.leaf.top) })
		end
	end
	-- the dandelion: four leaves lying on the soil round a flower stalk
	local L = B.dandelion
	local span = 2 * (L.leaf.gap + L.leaf.l) + L.stalk
	local fx, fz = spot(prand, span, span, 1.2)
	if fx ~= nil and fz ~= nil then
		local cx, cz = fx + span / 2, fz + span / 2
		local h, r = L.stalk / 2, L.stalk / 2 + L.leaf.gap
		local w = L.leaf.w / 2
		table.insert(out, { id = "bed_a_dandelion_stalk", lo = v(cx - h, B.top, cz - h), hi = v(cx + h, B.top + L.height, cz + h), profile = "leaf_dry_prototype", color = hex(B.leaf.stem) })
		local y1 = B.top + L.leaf.h
		local rosette = {
			{ v(cx + r, B.top, cz - w), v(cx + r + L.leaf.l, y1, cz + w) },
			{ v(cx - w, B.top, cz + r), v(cx + w, y1, cz + r + L.leaf.l) },
			{ v(cx - r - L.leaf.l, B.top, cz - w), v(cx - r, y1, cz + w) },
			{ v(cx - w, B.top, cz - r - L.leaf.l), v(cx + w, y1, cz - r) },
		}
		for i, box in rosette do
			table.insert(out, { id = `bed_a_dandelion_leaf_{i}`, lo = box[1], hi = box[2], profile = "leaf_dry_prototype", color = hex(B.leaf.top) })
		end
	end
	-- two more stones
	local S = B.stones
	local srand = rng(region.seed, 11)
	for i = 1, S.count do
		local w, d, h = between(srand, S.w[1], S.w[2]), between(srand, S.d[1], S.d[2]), between(srand, S.h[1], S.h[2])
		local color = pick(S.colors, srand)
		local x, z = spot(srand, w, d, 1.2)
		if x ~= nil and z ~= nil then
			table.insert(out, { id = `bed_a_stone_{string.char(97 + i)}`, lo = v(x, B.top, z), hi = v(x + w, B.top + h, z + d), profile = "brick_rough", color = hex(color), material = S.material })
		end
	end
	-- the mounds: low heaps of soil
	local M = B.mounds
	local mrand = rng(region.seed, 37)
	for i = 1, M.count do
		local w, d, h = between(mrand, M.w[1], M.w[2]), between(mrand, M.d[1], M.d[2]), between(mrand, M.h[1], M.h[2])
		local color = pick(M.colors, mrand)
		local x, z = spot(mrand, w, d, 1.0)
		if x ~= nil and z ~= nil then
			table.insert(out, { id = `bed_a_mound_{i}`, lo = v(x, B.top, z), hi = v(x + w, B.top + h, z + d), profile = "brick_rough", color = hex(color), material = B.soilMaterial })
		end
	end
	return out
end

-- ---------------------------------------------------------------- the drawn look
-- A list of drawn records, and a ceiling for each tier: `add` keeps a record only while the tier it shows in has room (a full-only record counts against the
-- full ceiling, any other against both), so what is placed first is what a tight budget keeps.
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

-- A leaf over its box, the Pilea's way (Habitat/Plants): a blade with rounded ends whose top is the box's top, a darker rim band round it and a lighter
-- underside (full tier), and a midrib along it (full tier).
local function leafOver(add: (Drawn) -> boolean, name: string, lo: Vector3, hi: Vector3, group: string)
	local L = Garden.BED.leaf
	local function rounded(id: string, a: Vector3, b: Vector3, r: number, color: Color3, full: boolean)
		local width, depth, height = b.X - a.X, b.Z - a.Z, b.Y - a.Y
		local rr = math.min(r, width * 0.45, depth * 0.45)
		local c = (a + b) * 0.5
		add({ id = id .. "A", size = v(width, height, depth - 2 * rr), at = c, color = color, material = L.material, full = full, group = group, shadow = not full })
		add({ id = id .. "B", size = v(width - 2 * rr, height - 0.0008, depth), at = c - v(0, 0.0004, 0), color = color, material = L.material, full = full, group = group, shadow = not full })
		local dh = height - 0.0016
		for i, corner in { { a.X + rr, a.Z + rr }, { b.X - rr, a.Z + rr }, { a.X + rr, b.Z - rr }, { b.X - rr, b.Z - rr } } do
			add({ id = `{id}C{i}`, size = v(dh, 2 * rr, 2 * rr), at = v(corner[1], a.Y + dh / 2, corner[2]), color = color, material = L.material, shape = "Cylinder", turn = v(0, 0, 90), full = full, group = group })
		end
	end
	local r = math.min(hi.X - lo.X, hi.Z - lo.Z) * 0.45
	rounded(name .. "Blade", lo, hi, r, hex(L.top), false)
	rounded(name .. "Under", v(lo.X - L.underOut, lo.Y - 0.012, lo.Z - L.underOut), v(hi.X + L.underOut, lo.Y + L.underThick, hi.Z + L.underOut), r + L.underOut, hex(L.under), true)
	rounded(name .. "Rim", v(lo.X - L.rimOut, lo.Y + 0.05, lo.Z - L.rimOut), v(hi.X + L.rimOut, hi.Y - 0.06, hi.Z + L.rimOut), r + L.rimOut, hex(L.rim), true)
	local along = if hi.X - lo.X >= hi.Z - lo.Z then "x" else "z"
	local c = (lo + hi) * 0.5
	local length = (if along == "x" then hi.X - lo.X else hi.Z - lo.Z) * 0.82
	add({ id = name .. "Rib", size = if along == "x" then v(length, 0.008, 0.07) else v(0.07, 0.008, length), at = v(c.X, hi.Y + 0.004, c.Z), color = hex(L.rib), material = L.material, full = true, group = group })
end

local function outerDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local O = Garden.OUTER
	local list, add = sheet(budget)
	local slab = O.slab
	local top, front = slab.hi.Y, slab.lo.Z
	-- where the paint has worn through to the stone: patches on the top, worst along the front edge (both tiers: it is the stone's look)
	local wrand = rng(region.seed, 3)
	for i = 1, 12 do
		local w, d = between(wrand, 1.2, 4.6), between(wrand, 0.7, 2.6)
		local x = between(wrand, slab.lo.X + w / 2 + 0.2, slab.hi.X - w / 2 - 0.2)
		local edge = i <= 5 -- along the front edge, square to it; the others anywhere, turned a little
		local z = if edge then front + d / 2 + 0.02 else between(wrand, front + 1.6, slab.hi.Z - 1.6)
		local turn = between(wrand, -25, 25)
		add({ id = "Worn" .. i, size = v(w, 0.008, d), at = v(x, top + 0.004, z), turn = v(0, if edge then 0 else turn, 0), color = hex(pick(O.stone, wrand)), material = "Concrete", group = "Weather" })
	end
	-- rain has run down the front face: dark streaks below the edge (a hair proud of the face, which is walkable)
	for i = 1, 6 do
		local x, w, l = between(wrand, slab.lo.X + 2, slab.hi.X - 2), between(wrand, 0.25, 0.7), between(wrand, 1.4, 2.9)
		add({ id = "Streak" .. i, size = v(w, l, 0.006), at = v(x, top - l / 2 - 0.05, front - 0.004), color = hex(O.streak), material = "Concrete", transparency = 0.35, group = "Weather" })
	end
	-- moss in the corners: where the slab meets the frame and the window box's ends, and at its front corners
	local mrand = rng(region.seed, 5)
	local corners = { { slab.lo.X + 0.9, slab.hi.Z - 0.8 }, { slab.hi.X - 0.9, slab.hi.Z - 0.8 }, { slab.lo.X + 0.9, front + 0.9 }, { slab.hi.X - 0.9, front + 0.9 },
		{ -9.1, -21.2 }, { 9.1, -21.2 } }
	for i, c in corners do
		for j = 1, 8 do
			local a, d = mrand() * TAU, 0.9 * math.sqrt(mrand())
			local size = between(mrand, 0.25, 0.7)
			add({ id = `Moss{i}_{j}`, size = v(size, size * 0.45, size * between(mrand, 0.7, 1.0)), at = v(c[1] + math.cos(a) * d, top + size * 0.09, c[2] + math.sin(a) * d),
				turn = v(0, mrand() * 360, 0), shape = "Ellipsoid", color = hex(pick(O.moss, mrand)), material = "Grass", full = j > 3, group = "Moss" })
		end
	end
	-- grit blown onto the stone
	local grand = rng(region.seed, 7)
	for i = 1, 28 do
		local s = between(grand, 0.07, 0.24)
		add({ id = "Grit" .. i, size = v(s, s * 0.6, s * between(grand, 0.6, 1.0)), at = v(between(grand, slab.lo.X + 0.5, slab.hi.X - 0.5), top + s * 0.25, between(grand, front + 0.4, slab.hi.Z - 0.4)),
			turn = v(between(grand, -20, 20), grand() * 360, 0), color = hex(pick(O.grit, grand)), material = "Pebble", full = true, group = "Grit" })
	end
	return list
end

local function wallDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local W = Garden.WALL
	local K = W.brick
	local list, add = sheet(budget)
	local face = W.face + K.gap -- the bricks' face, a hair behind the walkable face
	local mortarFace = W.face + K.recess
	local slab = Garden.OUTER.slab
	-- the mortar: the wall behind the bricks, recessed; under the slab only (the slab covers the top), up to the shoulders' tops beside it, and the house above
	add({ id = "Mortar", size = v(W.east - W.west, W.under - W.foot, W.back - mortarFace), at = v(0, (W.under + W.foot) / 2, (W.back + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Mortar" })
	for i, x in { { W.west, slab.lo.X }, { slab.hi.X, W.east } } do
		add({ id = "MortarShoulder" .. i, size = v(x[2] - x[1], W.top - 0.6 - W.under, W.back - mortarFace), at = v((x[1] + x[2]) / 2, (W.top - 0.6 + W.under) / 2, (W.back + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Mortar" })
		add({ id = "Coping" .. i, size = v(x[2] - x[1], 0.58, W.back - W.face - K.gap), at = v((x[1] + x[2]) / 2, W.top - 0.31, (W.back + W.face + K.gap) / 2), color = hex(W.coping), material = "Concrete", group = "Mortar" })
	end
	local win = W.window
	local skin = 1.0 -- the room's plaster on the inside of the house above the window
	for i, b in { { W.west, win.x0, W.top, W.above }, { win.x1, W.east, W.top, W.above }, { win.x0, win.x1, win.y1, W.above } } do
		add({ id = "Above" .. i, size = v(b[2] - b[1], b[4] - b[3], W.back - skin - mortarFace), at = v((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (W.back - skin + mortarFace) / 2), color = hex(W.mortar), material = W.mortarMaterial, group = "Above" })
		add({ id = "AboveSkin" .. i, size = v(b[2] - b[1], b[4] - b[3], skin), at = v((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, W.back - skin / 2), color = hex(W.plaster), material = "Plaster", group = "Above" })
	end
	-- the courses: stretcher bond, a half brick's offset every other course, from under the coping down to the lawn and up round the window
	local brand = rng(region.seed, 13)
	local pitch, course = K.length + K.joint, K.height + K.joint
	local n = 0
	local spalled: { { at: Vector3, size: Vector3 } } = {}
	local function lay(y0: number, y1: number, x0: number, x1: number, offset: number, group: string)
		local x = W.west - offset
		while x < W.east do
			local a, b = math.max(x + K.joint / 2, x0), math.min(x + pitch - K.joint / 2, x1)
			if b - a >= 2.0 then
				n += 1
				local burnt, pale = brand() < 0.08, brand() < 0.06
				local color = if burnt then hex(W.burnt) elseif pale then hex(W.pale) else hex(pick(W.bricks, brand))
				local sink = brand() * 0.05
				local at = v((a + b) / 2, (y0 + y1) / 2, face + sink + K.depth / 2)
				local size = v(b - a, y1 - y0, K.depth)
				add({ id = "Brick" .. n, size = size, at = at, color = color, material = W.brickMaterial, group = group })
				if brand() < 0.1 then table.insert(spalled, { at = at, size = size }) end
			end
			x += pitch
		end
	end
	local c = 0
	local y = W.under - K.joint / 2
	while y - K.height > W.foot - K.height do -- below the slab
		local y0 = math.max(y - K.height, W.foot)
		lay(y0, y, W.west, W.east, (c % 2) * pitch / 2, "Bricks")
		y -= course
		c += 1
	end
	-- the shoulders beside the slab: a short course under the coping
	lay(W.under + K.joint / 2, W.top - 0.6 - K.joint / 2, W.west, slab.lo.X, pitch / 2, "Bricks")
	lay(W.under + K.joint / 2, W.top - 0.6 - K.joint / 2, slab.hi.X, W.east, pitch / 2, "Bricks")
	-- above the outer sill, round the window
	c = 1
	y = W.top + K.joint / 2
	while y + K.height <= W.above do
		local y1 = y + K.height
		if y1 <= win.y1 + 0.5 then
			lay(y, y1, W.west, win.x0, (c % 2) * pitch / 2, "Above")
			lay(y, y1, win.x1, W.east, (c % 2) * pitch / 2, "Above")
		elseif y >= win.y1 then
			lay(y, y1, W.west, W.east, (c % 2) * pitch / 2, "Above")
		else
			lay(y, y1, W.west, win.x0, (c % 2) * pitch / 2, "Above")
			lay(y, y1, win.x1, W.east, (c % 2) * pitch / 2, "Above")
		end
		y += course
		c += 1
	end
	-- weathering (full tier): salt bloom on a few bricks, green algae along the foot where the soil splashes, and the spalled faces
	local erand = rng(region.seed, 17)
	for i, s in spalled do
		add({ id = "Spall" .. i, size = v(s.size.X * between(erand, 0.3, 0.6), s.size.Y * between(erand, 0.3, 0.6), 0.006), at = v(s.at.X + between(erand, -3, 3), s.at.Y + between(erand, -1, 1), face - 0.002),
			color = hex(W.burnt), material = "Concrete", transparency = 0.25, full = true, group = "Weather" })
	end
	for i = 1, 8 do
		add({ id = "Bloom" .. i, size = v(between(erand, 2, 5), between(erand, 1, 2.5), 0.006), at = v(between(erand, W.west + 5, W.east - 5), between(erand, -60, -10), face - 0.002),
			color = hex("d9d2c4"), material = "Plaster", transparency = 0.78, full = true, group = "Weather" })
	end
	for i = 1, 10 do
		local w = between(erand, 4, 11)
		add({ id = "Algae" .. i, size = v(w, between(erand, 1.5, 5), 0.006), at = v(W.west + (i - 0.5) * (W.east - W.west) / 10 + between(erand, -2, 2), W.foot + between(erand, 1, 3), face - 0.002),
			color = hex("4f6a36"), material = "Grass", transparency = 0.4, full = true, group = "Weather" })
	end
	return list
end

local function bedDecor(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	local B = Garden.BED
	local list, add = sheet(budget)
	local pieces = Garden.pieces(region)
	local top = B.top
	-- what stands on the soil, so the litter, the grass and the pebbles go round it
	local standing: { Box } = {}
	for _, p in pieces do
		if p.lo.Y <= top + 0.01 and p.id ~= "bed_a_soil" then table.insert(standing, { min = p.lo, max = p.hi }) end
	end
	local function free(x: number, z: number, margin: number): boolean
		for _, b in standing do
			if x > b.min.X - margin and x < b.max.X + margin and z > b.min.Z - margin and z < b.max.Z + margin then return false end
		end
		return true
	end
	local function onSoil(rand: () -> number, margin: number): (number, number)
		local x, z = 0.0, 0.0
		for _ = 1, 30 do
			x, z = between(rand, B.x0 + 0.6, B.x1 - 0.6), between(rand, B.z0 + 0.6, B.z1 - 0.6)
			if free(x, z, margin) then break end
		end
		return x, z
	end
	-- the plants first (their leaves are what the spider walks on: the blades are kept at both tiers)
	for _, p in pieces do
		if string.find(p.id, "_leaf_", 1, true) ~= nil then
			leafOver(add, p.id, p.lo, p.hi, "Plants")
		elseif string.find(p.id, "_stem", 1, true) ~= nil or string.find(p.id, "_stalk", 1, true) ~= nil then
			local c = (p.lo + p.hi) * 0.5
			local d = math.min(p.hi.X - p.lo.X, p.hi.Z - p.lo.Z)
			add({ id = p.id .. "Rod", size = v(p.hi.Y - p.lo.Y, d, d), at = c, turn = v(0, 0, 90), shape = "Cylinder", color = hex(B.leaf.stem), material = B.leaf.material, group = "Plants", shadow = true })
			if string.find(p.id, "_stalk", 1, true) ~= nil then
				local F = B.flower
				local head = v(c.X, p.hi.Y + 0.35, c.Z)
				add({ id = "FlowerSepals", size = v(1.6, 0.5, 1.6), at = head - v(0, 0.3, 0), shape = "Ellipsoid", color = hex(F.sepals), material = "SmoothPlastic", group = "Plants" })
				add({ id = "FlowerHead", size = v(2.6, 0.9, 2.6), at = head, shape = "Ellipsoid", color = hex(F.head), material = "SmoothPlastic", group = "Plants" })
				add({ id = "FlowerDisc", size = v(1.3, 0.3, 1.3), at = head + v(0, 0.42, 0), shape = "Ellipsoid", color = hex(F.disc), material = "SmoothPlastic", full = true, group = "Plants" })
			end
		end
	end
	-- the mounds' slopes: a flattened heap of the same soil round each, rising to just under its top, so a mound reads as a heap (the walkable top is the box's)
	for _, p in pieces do
		if string.find(p.id, "mound", 1, true) ~= nil then
			local h = p.hi.Y - p.lo.Y
			add({ id = p.id .. "Slope", size = v((p.hi.X - p.lo.X) * 1.35, h * 1.9, (p.hi.Z - p.lo.Z) * 1.35), at = v((p.lo.X + p.hi.X) / 2, top, (p.lo.Z + p.hi.Z) / 2),
				shape = "Ellipsoid", color = p.color, material = B.soilMaterial, group = "Soil" })
		end
	end
	-- lichen on the stones and moss at their feet
	local lrand = rng(region.seed, 41)
	for _, p in pieces do
		if string.find(p.id, "stone", 1, true) ~= nil then
			for j = 1, 2 do
				local s = between(lrand, 0.5, 1.4)
				add({ id = `{p.id}Lichen{j}`, size = v(0.01, s, s * between(lrand, 0.6, 1.0)), at = v(between(lrand, p.lo.X + s, p.hi.X - s), p.hi.Y + 0.005, between(lrand, p.lo.Z + s, p.hi.Z - s)),
					turn = v(0, lrand() * 360, 90), shape = "Cylinder", color = hex(pick({ "b8b48a", "c9c3a0", "9aa77a" }, lrand)), material = "Plaster", full = true, group = "Stones" })
			end
			for j = 1, 3 do
				local side = lrand() < 0.5
				local x = if side then pick({ p.lo.X - 0.15, p.hi.X + 0.15 }, lrand) else between(lrand, p.lo.X, p.hi.X)
				local z = if side then between(lrand, p.lo.Z, p.hi.Z) else pick({ p.lo.Z - 0.15, p.hi.Z + 0.15 }, lrand)
				local s = between(lrand, 0.35, 0.8)
				add({ id = `{p.id}Moss{j}`, size = v(s, s * 0.5, s), at = v(x, top + s * 0.12, z), shape = "Ellipsoid", turn = v(0, lrand() * 360, 0), color = hex(pick(Garden.OUTER.moss, lrand)), material = "Grass", full = true, group = "Stones" })
			end
		end
	end
	-- the soil: damper and drier patches (full tier)
	local srand = rng(region.seed, 43)
	for i = 1, B.mottle.count do
		local x, z = onSoil(srand, 0.2)
		local w = between(srand, B.mottle.size[1], B.mottle.size[2])
		add({ id = "Mottle" .. i, size = v(w, 0.006, w * between(srand, 0.5, 0.9)), at = v(x, top + 0.003, z), turn = v(0, srand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(B.mottle.colors, srand)), material = B.soilMaterial, full = true, group = "Soil" })
	end
	-- the grass: tufts along the bed's edges and by the stones, each blade a long thin leaf leaning out from the tuft's foot
	local grand = rng(region.seed, 47)
	local G = B.grass
	for i = 1, G.tufts do
		local x, z
		if i % 2 == 0 then
			local edge = math.floor(grand() * 3)
			x = if edge == 0 then B.x0 + between(grand, 0.4, 1.6) elseif edge == 1 then B.x1 - between(grand, 0.4, 1.6) else between(grand, B.x0 + 1, B.x1 - 1)
			z = if edge == 2 then B.z0 + between(grand, 0.4, 1.6) else between(grand, B.z0 + 1, B.z1 - B.landing)
		else
			x, z = onSoil(grand, 0.5)
		end
		local height = between(grand, G.height[1], G.height[2])
		for j = 1, G.blades do
			local a = grand() * TAU
			local lean = between(grand, 12, 34)
			local l = height * between(grand, 0.7, 1.0)
			local color = if grand() < 0.15 then hex(G.dry) else hex(pick(G.colors, grand))
			local foot = v(x + math.cos(a) * 0.12, top, z + math.sin(a) * 0.12)
			local out = math.sin(math.rad(lean)) * l / 2
			add({ id = `Tuft{i}Blade{j}`, size = v(0.05, l, between(grand, 0.14, 0.24)), at = foot + v(math.cos(a) * out, math.cos(math.rad(lean)) * l / 2, math.sin(a) * out),
				turn = v(0, -math.deg(a), -lean), shape = "Ellipsoid", color = color, material = "SmoothPlastic", full = j > G.keep, group = "Grass" })
		end
	end
	-- the leaf litter: fallen leaves, flat or a little curled, one in `lowEvery` kept at the low tier
	local frand = rng(region.seed, 53)
	local F = B.litter
	for i = 1, F.count do
		local x, z = onSoil(frand, 0.3)
		local s = between(frand, F.size[1], F.size[2])
		local curl = if frand() < 0.3 then between(frand, 8, 22) else between(frand, 0, 4)
		add({ id = "Litter" .. i, size = v(s, 0.04, s * between(frand, 0.45, 0.7)), at = v(x, top + 0.03 + math.sin(math.rad(curl)) * s * 0.2, z), turn = v(curl, frand() * 360, 0),
			shape = "Ellipsoid", color = hex(pick(F.colors, frand)), material = "SmoothPlastic", full = i % F.lowEvery ~= 0, group = "Litter" })
	end
	-- twigs and pebbles (full tier)
	local trand = rng(region.seed, 59)
	local T = B.twigs
	for i = 1, T.count do
		local x, z = onSoil(trand, 0.4)
		local l = between(trand, T.length[1], T.length[2])
		add({ id = "Twig" .. i, size = v(l, T.width, T.width), at = v(x, top + T.width / 2, z), turn = v(0, trand() * 360, 0), shape = "Cylinder", color = hex(pick(T.colors, trand)), material = "Wood", full = true, group = "Litter" })
	end
	local P = B.pebbles
	for i = 1, P.count do
		local x, z = onSoil(trand, 0.2)
		local s = between(trand, P.size[1], P.size[2])
		add({ id = "Pebble" .. i, size = v(s, s * 0.55, s * between(trand, 0.6, 0.9)), at = v(x, top + s * 0.18, z), turn = v(between(trand, -15, 15), trand() * 360, 0), shape = "Ellipsoid",
			color = hex(pick(P.colors, trand)), material = "Pebble", full = true, group = "Litter" })
	end
	return list
end

-- ---------------------------------------------------------------- the questions Region asks
-- The budgets: the most drawn parts a region of the kind may carry at each tier. They are what the generators place now (tests/world.luau builds the looks and
-- holds each tier to them exactly, so a look that grows says so here); the placers stop at them (`sheet`), keeping what they place first. All three together
-- are 551 parts at full and 216 at low, beside the sill's 1,178 and 314.
Garden.BUDGETS = {
	outer_sill = { full = 94, low = 36 },
	house_wall = { full = 93, low = 73 },
	bed = { full = 364, low = 107 },
} :: { [string]: { full: number, low: number } }

local piecesCache: { [string]: { Piece } } = {}
local decorCache: { [string]: { Drawn } } = {}

-- Whether a kind is one of the garden's.
function Garden.knows(kind: string): boolean
	return kind == "outer_sill" or kind == "house_wall" or kind == "bed"
end

-- The physical boxes of a region of one of the garden's kinds (the same list for the same region; do not change it).
function Garden.pieces(region: WorldMap.Region): { Piece }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = piecesCache[key]
	if cached ~= nil then return cached end
	local out: { Piece }
	if region.kind == "outer_sill" then out = outerPieces()
	elseif region.kind == "house_wall" then out = wallPieces()
	elseif region.kind == "bed" then out = bedPieces(region)
	else error("no generator for the region kind " .. region.kind) end
	piecesCache[key] = out
	return out
end

-- The drawn look of a region of one of the garden's kinds, at the full tier (the low tier is the records without `full`).
function Garden.decor(region: WorldMap.Region): { Drawn }
	local key = region.id .. "/" .. tostring(region.seed)
	local cached = decorCache[key]
	if cached ~= nil then return cached end
	local budget = Garden.BUDGETS[region.kind]
	local out: { Drawn }
	if region.kind == "outer_sill" then out = outerDecor(region, budget)
	elseif region.kind == "house_wall" then out = wallDecor(region, budget)
	elseif region.kind == "bed" then out = bedDecor(region, budget)
	else error("no generator for the region kind " .. region.kind) end
	decorCache[key] = out
	return out
end

-- The drawn look of a region placed under another budget than its kind's (not kept): what a tighter ceiling leaves out, for the tests.
function Garden.decorWith(region: WorldMap.Region, budget: { full: number, low: number }): { Drawn }
	if region.kind == "outer_sill" then return outerDecor(region, budget) end
	if region.kind == "house_wall" then return wallDecor(region, budget) end
	if region.kind == "bed" then return bedDecor(region, budget) end
	error("no generator for the region kind " .. region.kind)
end

-- The pieces of a region that its drawn look stands in for: those turn invisible (still solid) once the look is built. The wall's boxes are drawn as bricks and
-- the plants' as leaves and stems; the slab, the stones and the soil are their own look.
function Garden.drawnPieces(region: WorldMap.Region): { string }
	local out: { string } = {}
	for _, p in Garden.pieces(region) do
		if region.kind == "house_wall" or string.find(p.id, "_leaf_", 1, true) ~= nil or string.find(p.id, "_stem", 1, true) ~= nil or string.find(p.id, "_stalk", 1, true) ~= nil then
			table.insert(out, p.id)
		end
	end
	return out
end

-- The pieces of a region that the sill's drawn world stands in for: the window box's halves on the outer sill, drawn with the flowers in them by the sill's Decor
-- (Habitat/Plants.garden), and solid here.
function Garden.drawnBySill(region: WorldMap.Region): { string }
	local out: { string } = {}
	if region.kind == "outer_sill" then
		for _, half in Flora.garden.box.boxes do table.insert(out, half.id) end
	end
	return out
end

-- The boxes a region's creatures keep out of: each retreat grown by half a stud (the sill's are its own, Region.keepOut).
function Garden.keepOut(region: WorldMap.Region): { Box }
	if not Garden.knows(region.kind) then error("no generator for the region kind " .. region.kind) end
	local out: { Box } = {}
	for _, t in region.retreats do
		table.insert(out, { min = t.min - v(0.5, 0.5, 0.5), max = t.max + v(0.5, 0.5, 0.5) })
	end
	return out
end

return table.freeze(Garden)
