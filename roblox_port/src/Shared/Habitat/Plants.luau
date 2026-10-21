--!strict
-- Builds the plants of the drawn world from Data/Flora: the Pilea that replaces the leaf and stem pieces of the sill, the trough's
-- planting (water stain, soil, pebbles, moss, seedlings) and the garden outside the window (a window box, black-eyed Susans with
-- their ultraviolet layer, flowering shrubs). Everything is drawn only (Habitat/Shapes: anchored, non-colliding, unqueryable,
-- untouchable); optional detail is marked FullOnly, which Client/WorldDetail removes on phones and tablets. A drawn leaf's top is
-- its piece's top and a drawn stem stands inside its piece's box, so what the spider walks on is what the player sees.
local Flora = require(script.Parent.Parent.Data.Flora)
local Graphics = require(script.Parent.Parent.Data.Graphics)
local Layout = require(script.Parent.WindowsillLayout)
local Shapes = require(script.Parent.Shapes)

local Plants = {}

local hex, folder, between = Shapes.hex, Shapes.folder, Shapes.between
local TAU = 2 * math.pi

local piece = Shapes.piece

local function pick<T>(list: { T }, rand: () -> number): T
	return list[1 + math.floor(rand() * #list)]
end

-- ---------------------------------------------------------------- the Pilea
local P = Flora.pilea

-- The ids of the sill pieces the Pilea draws instead: Scenery hides exactly these, and only once they are drawn.
function Plants.pieceIds(): { string }
	local ids = { P.tip }
	for _, plant in P.plants do
		table.insert(ids, plant.leaf)
		table.insert(ids, plant.stem)
	end
	return ids
end

local function insideRounded(x: number, z: number, x0: number, x1: number, z0: number, z1: number, r: number): boolean
	local dx = math.max(math.abs(x - (x0 + x1) / 2) - ((x1 - x0) / 2 - r), 0)
	local dz = math.max(math.abs(z - (z0 + z1) / 2) - ((z1 - z0) / 2 - r), 0)
	return dx * dx + dz * dz <= r * r
end

-- How far one can go from (sx, sz) along the angle `a` and stay inside the rounded rectangle shrunk by `margin`.
local function reach(sx: number, sz: number, a: number, lo: Vector3, hi: Vector3, r: number, margin: number): number
	local near, far = 0, math.max(hi.X - lo.X, hi.Z - lo.Z) * 2
	local c, s = math.cos(a), math.sin(a)
	for _ = 1, 24 do
		local mid = (near + far) / 2
		if insideRounded(sx + c * mid, sz + s * mid, lo.X + margin, hi.X - margin, lo.Z + margin, hi.Z - margin, math.max(r - margin, 0.05)) then
			near = mid
		else
			far = mid
		end
	end
	return near
end

-- Dark cracks radiating from a stem's foot and a pinch of crumbled soil: the pups rooted in a crack of the old sill.
local function base(parent: Instance, cx: number, cz: number, rand: () -> number)
	local C, K = P.cracks, P.crumbs
	local color = hex(C.color)
	for i = 1, C.count do
		local a = TAU * (i - 1 + rand() * 0.6) / C.count
		local length = between(rand, C.length[1], C.length[2])
		local turn = a + (rand() - 0.5) * 0.9
		local y = C.height / 2 + 0.001
		local p0 = Vector3.new(cx + math.cos(a) * 0.45, y, cz + math.sin(a) * 0.45)
		local p1 = Vector3.new(cx + math.cos(a) * length * 0.6, y, cz + math.sin(a) * length * 0.6)
		local p2 = Vector3.new(p1.X + math.cos(turn) * length * 0.4, y, p1.Z + math.sin(turn) * length * 0.4)
		for j, seg in { { p0, p1 }, { p1, p2 } } do
			Shapes.strip(parent, `Crack{i}_{j}`, seg[1], seg[2], C.width, C.height, color, "SmoothPlastic").Transparency = C.transparency
		end
	end
	for i = 1, K.count do
		local a, d = rand() * TAU, 0.5 + rand() * K.spread
		local size = between(rand, K.size[1], K.size[2])
		Shapes.ellipsoid(parent, "Crumb" .. i, Vector3.new(size, size * 0.55, size * 0.8),
			CFrame.new(cx + math.cos(a) * d, size * 0.2, cz + math.sin(a) * d) * CFrame.Angles(0, rand() * TAU, 0), hex(pick(K.colors, rand)), "Plaster")
	end
end

-- One pancake leaf over its hidden piece, and the petiole over its stem piece.
local function drawPlant(parent: Instance, leaf: Layout.Piece, stem: Layout.Piece, rand: () -> number)
	local lo, hi, r = leaf.lo, leaf.hi, P.radius
	local plant = folder(parent, leaf.id)
	for _, part in Shapes.roundedSlab(plant, "Blade", lo, hi, r, hex(P.top), P.material) do part.CastShadow = true end
	-- the petiole: a round rod inscribed in the stem's box, joining the blade from below, at the stem's x and z
	local cx, cz = (stem.lo.X + stem.hi.X) / 2, (stem.lo.Z + stem.hi.Z) / 2
	local rod = Shapes.rod(plant, "Petiole", Vector3.new(cx, stem.lo.Y, cz), Vector3.new(cx, stem.hi.Y, cz),
		math.min(stem.hi.X - stem.lo.X, stem.hi.Z - stem.lo.Z), hex(P.petiole), P.material)
	rod.CastShadow = true
	local detail = folder(plant, "Detail", true)
	Shapes.roundedSlab(detail, "Under", Vector3.new(lo.X - P.underOut, lo.Y - P.underBelow, lo.Z - P.underOut),
		Vector3.new(hi.X + P.underOut, lo.Y + P.underThick, hi.Z + P.underOut), r + P.underOut, hex(P.under), P.material)
	Shapes.roundedSlab(detail, "Rim", Vector3.new(lo.X - P.rimOut, lo.Y + P.rimFoot, lo.Z - P.rimOut),
		Vector3.new(hi.X + P.rimOut, hi.Y - P.rimDrop, hi.Z + P.rimOut), r + P.rimOut, hex(P.rim), P.material)
	-- peltate: a pale dot where the stalk joins, and the veins fan out from it
	Shapes.disc(detail, "Dot", P.dotDiameter, P.dotHeight, Vector3.new(cx, hi.Y + P.dotHeight / 2, cz), hex(P.dot), P.material)
	local V = P.veins
	local y = hi.Y + V.height / 2
	for i = 1, V.count do
		local a = TAU * (i - 1 + (rand() * 2 - 1) * V.jitter) / V.count
		local far = reach(cx, cz, a, lo, hi, r, V.margin) * V.reach
		if far > V.start + 0.3 then
			local c, s = math.cos(a), math.sin(a)
			Shapes.strip(detail, "Vein" .. i, Vector3.new(cx + c * V.start, y, cz + s * V.start), Vector3.new(cx + c * far, y, cz + s * far),
				V.width, V.height, hex(P.vein), P.material)
		end
	end
	Shapes.disc(detail, "Foot", P.foot.diameter, P.foot.height, Vector3.new(cx, stem.lo.Y + P.foot.height / 2, cz), hex(P.foot.color), P.material)
	base(folder(plant, "Base", true), cx, cz, rand)
end

-- The dry leaf: a curled tan fragment with darker edges.
local function drawTip(parent: Instance, leaf: Layout.Piece)
	local D = P.dry
	local lo, hi = leaf.lo, leaf.hi
	local tip = folder(parent, leaf.id)
	for _, part in Shapes.roundedSlab(tip, "Blade", lo, hi, D.radius, hex(D.color), "Plaster") do part.CastShadow = true end
	local detail = folder(tip, "Detail", true)
	local edge, w, h = hex(D.edge), D.edgeWidth, D.edgeHeight
	local y = hi.Y + h / 2
	local x0, x1, z0, z1 = lo.X + D.edgeInset + w / 2, hi.X - D.edgeInset - w / 2, lo.Z + D.edgeInset + w / 2, hi.Z - D.edgeInset - w / 2
	local r = D.radius
	Shapes.strip(detail, "EdgeN", Vector3.new(x0 + r, y, z0), Vector3.new(x1 - r, y, z0), w, h, edge, "Plaster")
	Shapes.strip(detail, "EdgeS", Vector3.new(x0 + r, y, z1), Vector3.new(x1 - r, y, z1), w, h, edge, "Plaster")
	Shapes.strip(detail, "EdgeW", Vector3.new(x0, y, z0 + r), Vector3.new(x0, y, z1 - r), w, h, edge, "Plaster")
	Shapes.strip(detail, "EdgeE", Vector3.new(x1, y, z0 + r), Vector3.new(x1, y, z1 - r), w, h, edge, "Plaster")
	for i, c in D.curls do
		Shapes.block(detail, "Curl" .. i, Vector3.new(D.curlSize[1], D.curlSize[2], D.curlSize[3]),
			CFrame.new(c.x, hi.Y + 0.07, c.z) * CFrame.Angles(0, math.rad(c.turn), 0) * CFrame.Angles(math.rad(c.tip), 0, 0), hex(D.curl), "Plaster")
	end
end

-- Draws the Pilea: leaves, petioles and the dry leaf, into a folder "Pilea" under `parent`.
function Plants.pilea(parent: Instance): Folder
	local pilea = folder(parent, "Pilea")
	local rand = Shapes.rng(P.seed)
	for _, plant in P.plants do
		drawPlant(pilea, piece(plant.leaf), piece(plant.stem), rand)
	end
	drawTip(pilea, piece(P.tip))
	return pilea
end

-- ---------------------------------------------------------------- the trough's planting
local T = Flora.planter

type Face = { name: string, along: string, fixed: number, outward: number, from: number, to: number }

-- A flat sheet on the trough's face: from, to as fractions along the face, y0 to y1 up it; `layer` stacks sheets without z-fighting.
local function sheet(parent: Instance, face: Face, from: number, to: number, y0: number, y1: number, layer: number, color: Color3, transparency: number)
	local th = T.stain.thickness
	local a, b = face.from + (face.to - face.from) * from, face.from + (face.to - face.from) * to
	local off = face.fixed + face.outward * (0.002 + layer * 0.003 + th / 2)
	local size = if face.along == "x" then Vector3.new(b - a, y1 - y0, th) else Vector3.new(th, y1 - y0, b - a)
	local at = if face.along == "x" then Vector3.new((a + b) / 2, (y0 + y1) / 2, off) else Vector3.new(off, (y0 + y1) / 2, (a + b) / 2)
	Shapes.block(parent, "Sheet", size, CFrame.new(at), color, "SmoothPlastic").Transparency = transparency
end

-- A flattened ellipsoid lying on the soil with a random turn: used for pebbles, moss and the damp patches.
local function lump(parent: Instance, name: string, at: Vector3, size: Vector3, color: Color3, material: string, rand: () -> number, tilt: number)
	local frame = CFrame.new(at) * CFrame.Angles(0, rand() * TAU, 0) * CFrame.Angles((rand() - 0.5) * tilt, 0, (rand() - 0.5) * tilt)
	return Shapes.ellipsoid(parent, name, size, frame, color, material)
end

function Plants.planter(parent: Instance): Folder
	local trough = piece("planter")
	local planter = folder(parent, "Planter")
	local stain = folder(planter, "Stain", true)
	local S = T.stain
	local rand = Shapes.rng(T.pebbles.seed)
	local faces: { Face } = {
		{ name = "Front", along = "x", fixed = trough.hi.Z, outward = 1, from = trough.lo.X, to = trough.hi.X },
		{ name = "Back", along = "x", fixed = trough.lo.Z, outward = -1, from = trough.lo.X, to = trough.hi.X },
		{ name = "West", along = "z", fixed = trough.lo.X, outward = -1, from = trough.lo.Z, to = trough.hi.Z },
		{ name = "East", along = "z", fixed = trough.hi.X, outward = 1, from = trough.lo.Z, to = trough.hi.Z },
	}
	for _, face in faces do
		local group = folder(stain, face.name)
		local scale = between(rand, 0.85, 1.15)
		sheet(group, face, 0, 1, 0, S.height, 0, hex(S.color), S.transparency)
		for _, tide in S.tide do
			sheet(group, face, tide[1], tide[2], 0, tide[3] * scale, 1, hex(S.tideColor), S.tideTransparency)
		end
		for _, salt in S.salt do
			local middle = (salt[1] + salt[2]) / 2
			local top = S.height
			for _, tide in S.tide do
				if middle >= tide[1] and middle <= tide[2] then top = tide[3] * scale end
			end
			sheet(group, face, salt[1], salt[2], top + S.saltGap, top + S.saltGap + S.saltHeight, 2, hex(S.saltColor), S.saltTransparency)
		end
	end

	local area = T.area
	local mottle = folder(planter, "Damp", true)
	for i, m in T.mottle do
		local patch = Shapes.ellipsoid(mottle, "Damp" .. i, Vector3.new(m.w, 0.006, m.d), CFrame.new(m.x, area.y, m.z), hex(m.color), "Plaster")
		patch.Transparency = 0.3
	end

	local B = T.pebbles
	local pebbles = folder(planter, "Pebbles", true)
	local placed: { Vector3 } = {}
	for i = 1, B.count do
		local at = Vector3.zero
		for _ = 1, 12 do
			at = Vector3.new(between(rand, area.x0, area.x1), 0, between(rand, area.z0, area.z1))
			local clear = true
			for _, other in placed do
				if (other - at).Magnitude < 0.8 then clear = false end
			end
			if clear then break end
		end
		table.insert(placed, at)
		local length = between(rand, B.length[1], B.length[2])
		local height = length * B.flat
		lump(pebbles, "Pebble" .. i, Vector3.new(at.X, area.y + height * 0.3, at.Z), Vector3.new(length, height, length * between(rand, 0.6, 0.9)),
			hex(pick(B.colors, rand)), "Plaster", rand, 0.25)
	end

	local M = T.moss
	local moss = folder(planter, "Moss", true)
	local mrand = Shapes.rng(M.seed)
	for i, patch in M.patches do
		for j = 1, patch.n do
			local a, d = mrand() * TAU, patch.r * math.sqrt(mrand())
			local size = between(mrand, M.size[1], M.size[2])
			lump(moss, `Moss{i}_{j}`, Vector3.new(patch.x + math.cos(a) * d, area.y + size * M.tall * 0.25, patch.z + math.sin(a) * d),
				Vector3.new(size, size * M.tall, size * between(mrand, 0.7, 1.0)), hex(pick(M.colors, mrand)), "Plaster", mrand, 0.2)
		end
	end

	local seedlings = folder(planter, "Seedlings", true)
	local C = T.cotyledon
	for i, s in T.seedlings do
		local foot = Vector3.new(s.x, area.y, s.z)
		local top = foot + Vector3.new(0, T.stalk, 0)
		Shapes.rod(seedlings, `Seedling{i}Stalk`, foot, top, T.stalkWidth, hex(T.stalkColor), "SmoothPlastic")
		local heading = math.rad(s.turn)
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		for side = 1, 2 do
			local sign = if side == 1 then 1 else -1
			local lift = math.rad(T.cotyledonTip)
			local along = dir * (sign * math.cos(lift)) + Vector3.yAxis * math.sin(lift)
			Shapes.ellipsoid(seedlings, `Seedling{i}Leaf{side}`, Vector3.new(C[1], C[2], C[3]),
				Shapes.frame(top + dir * (sign * C[1] * 0.42) + Vector3.new(0, T.cotyledonRise, 0), along, Vector3.yAxis), hex(T.cotyledonColor), "SmoothPlastic")
		end
	end
	return planter
end

-- ---------------------------------------------------------------- the garden outside the window
local G = Flora.garden

-- The ids of the outer sill's pieces the window box draws instead (World/Garden's window_box_west and window_box_east): Scenery hides exactly these, and
-- only once the garden is drawn (ROBLOX-95).
function Plants.windowBoxIds(): { string }
	local ids = {}
	for _, half in G.box.boxes do table.insert(ids, half.id) end
	return ids
end

-- ROBLOX-95: two halves either side of the raised sash, standing on the stone outer sill; each half is drawn as the one box was.
local function windowBox(parent: Instance)
	local B = G.box
	local box = folder(parent, "WindowBox")
	local d = B.z1 - B.z0
	local cz = (B.z0 + B.z1) / 2
	local rimBottom = B.soilTop - 0.1
	local rim = hex(B.rim)
	local rimHeight = B.top - rimBottom
	local ry = (B.top + rimBottom) / 2
	for _, span in B.boxes do
		local half = folder(box, if span.x1 <= 0 then "West" else "East")
		local w, cx = span.x1 - span.x0, (span.x0 + span.x1) / 2
		Shapes.block(half, "Body", Vector3.new(w, rimBottom - B.bottom, d), CFrame.new(cx, (rimBottom + B.bottom) / 2, cz), hex(B.color), "Wood")
		Shapes.block(half, "Soil", Vector3.new(w - 2 * B.rimWidth, 0.4, d - 2 * B.rimWidth), CFrame.new(cx, B.soilTop - 0.2, cz), hex(B.soil), "Ground")
		Shapes.block(half, "RimFar", Vector3.new(w, rimHeight, B.rimWidth), CFrame.new(cx, ry, B.z0 + B.rimWidth / 2), rim, "Wood")
		Shapes.block(half, "RimNear", Vector3.new(w, rimHeight, B.rimWidth), CFrame.new(cx, ry, B.z1 - B.rimWidth / 2), rim, "Wood")
		Shapes.block(half, "RimWest", Vector3.new(B.rimWidth, rimHeight, d - 2 * B.rimWidth), CFrame.new(span.x0 + B.rimWidth / 2, ry, cz), rim, "Wood")
		Shapes.block(half, "RimEast", Vector3.new(B.rimWidth, rimHeight, d - 2 * B.rimWidth), CFrame.new(span.x1 - B.rimWidth / 2, ry, cz), rim, "Wood")
		for i, peel in B.peel do
			if peel[1] > span.x0 and peel[1] < span.x1 then
				Shapes.block(half, "Peel" .. i, Vector3.new(peel[3], 0.01, peel[4]), CFrame.new(peel[1], B.top + 0.006, peel[2]), hex(B.paint), "SmoothPlastic")
			end
		end
	end
end

type FlowerSpec = { x: number, z: number, y: number, nod: number, turn: number, size: number }

-- One black-eyed Susan: golden petals round a dark dome, a bent stem and two leaves; its head nods and turns toward the room. The
-- ultraviolet pattern is a layer of Neon parts, invisible until the eye-view helper fades them in: the outer half of each petal
-- reflects ultraviolet, the base and the centre absorb it.
local function rudbeckia(parent: Instance, uv: Instance, index: number, spec: FlowerSpec, rand: () -> number)
	local F = G.rudbeckia
	local s = spec.size
	local flower = folder(parent, "Flower" .. index)
	local nod, turn = math.rad(spec.nod), math.rad(spec.turn)
	local facing = Vector3.new(math.sin(turn) * math.cos(nod), math.sin(nod), math.cos(turn) * math.cos(nod)).Unit
	local right = Vector3.yAxis:Cross(facing).Unit
	local up = facing:Cross(right)
	local head = Vector3.new(spec.x, spec.y, spec.z)
	local centre = F.centre * s
	-- the stem and the head's golden disc and dark dome (both tiers)
	local soil = Vector3.new(spec.x, G.box.soilTop, spec.z)
	local back = head - facing * 0.3
	local side = if rand() < 0.5 then right else -right
	local bend = back:Lerp(soil, 0.55) + side * (F.stemBend * s)
	Shapes.rod(flower, "StemLow", soil, bend, F.stemWidth * s, hex(F.stem), "SmoothPlastic")
	Shapes.rod(flower, "StemHigh", bend, back, F.stemWidth * s * 0.85, hex(F.stem), "SmoothPlastic")
	local discR = centre + F.discOut * s
	Shapes.ellipsoid(flower, "Disc", Vector3.new(2 * discR, 0.1, 2 * discR), CFrame.fromMatrix(head - facing * 0.04, right, facing), hex(F.disc), "SmoothPlastic")
	Shapes.ellipsoid(flower, "Dome", Vector3.new(2 * centre, 2 * F.centreHeight * s, 2 * centre), CFrame.fromMatrix(head, right, facing), hex(F.centreColor), "Plaster")
	-- the petals (full tier) and their ultraviolet halves
	local petals = folder(flower, "Petals", true)
	local count = math.floor(between(rand, F.petals[1], F.petals[2] + 0.999))
	for i = 1, count do
		local angle = TAU * (i - 1 + (rand() - 0.5) * 0.35) / count
		local dir = right * math.cos(angle) + up * math.sin(angle)
		local droop = math.rad(F.droop) * between(rand, 0.7, 1.3)
		local long = dir * math.cos(droop) - facing * math.sin(droop)
		local thin = facing * math.cos(droop) + dir * math.sin(droop)
		local length = F.petalLength * s * between(rand, 0.92, 1.08)
		local width, thick = F.petalWidth * s, F.petalThick
		local base = centre * 0.9
		Shapes.ellipsoid(petals, "Petal" .. i, Vector3.new(length, thick, width), CFrame.fromMatrix(head + long * (base + length / 2), long, thin),
			hex(F.petalColors[1 + (i - 1) % #F.petalColors]), "SmoothPlastic")
		local U = F.uv
		local patch = Shapes.ellipsoid(uv, `Flower{index}Petal{i}`, Vector3.new(length * 0.5 * 0.95, U.thick, width * 0.85),
			CFrame.fromMatrix(head + long * (base + length * 0.75) + thin * (thick / 2 + U.rise), long, thin), hex(U.color), "Neon")
		patch.Transparency = 1
		patch:SetAttribute("UVOpacity", U.opacity)
		patch:SetAttribute("FullOnly", true)
	end
	-- two leaves low on the stem (full tier)
	local leaves = folder(flower, "Leaves", true)
	for i = 1, 2 do
		local from = soil:Lerp(bend, 0.22 + 0.25 * i)
		local yaw = rand() * TAU
		local out = Vector3.new(math.cos(yaw), 0.5, math.sin(yaw)).Unit
		local size = Vector3.new(F.leafSize[1] * s, F.leafSize[2], F.leafSize[3] * s)
		Shapes.ellipsoid(leaves, "Leaf" .. i, size, Shapes.frame(from + out * (size.X / 2), out, Vector3.yAxis), hex(F.leaf), "SmoothPlastic")
	end
end

-- A flowering bush to the ground (ROBLOX-103: the shrubs were standards on stems): a rounded core of leaves whose underside is a little above the lawn, lumps of
-- leaves over its top and sides (the lowest touching the lawn), a woody frame of stems from the lawn up into the crown, and blossoms on the side facing the
-- house. Each where Flora.garden.shrubs puts it, in the garden's own studs; the low tier keeps the core, a few lumps, two stems and two blossoms. `place` (the
-- view's projection, Scenery.viewPosition) is no longer needed: the bushes are where they are.
local function shrubs(parent: Instance, _place: (number, number, number) -> (Vector3, number))
	local S = G.shrub
	local rand = Shapes.rng(S.seed)
	local group = folder(parent, "Shrubs")
	local function ball(name: string, at: Vector3, diameter: number, color: Color3, material: string, optional: boolean)
		local p = Shapes.block(group, name, Vector3.one * diameter, CFrame.new(at), color, material)
		p.Shape = Enum.PartType.Ball
		if optional then Shapes.fullOnly(p) end
	end
	local ground = Graphics.view.ground.y
	for i, spec in G.shrubs do
		local h, w = spec.h, spec.w
		local base = Vector3.new(spec.x, ground, spec.z)
		-- the core: a rounded mass of leaves from just above the lawn to the top
		local bottom = ground + h * S.skirt
		local core = Shapes.ellipsoid(group, `Shrub{i}`, Vector3.new(w * 0.94, (h - h * S.skirt) * 0.98, w * 0.88), CFrame.new(spec.x, (bottom + ground + h) / 2, spec.z)
			* CFrame.Angles(0, rand() * TAU, 0), hex(pick(S.foliage, rand)), S.material)
		core.CastShadow = false
		-- the frame: stems from the lawn splaying up into the crown (the low tier keeps the first two)
		local F = S.frame
		for k = 1, F.stems do
			local a = (k - 1) / F.stems * TAU + rand() * 0.8
			local foot = base + Vector3.new(math.cos(a) * w * 0.06, 0, math.sin(a) * w * 0.06)
			local top = Vector3.new(spec.x + math.cos(a) * w * F.reach * 0.5, ground + h * between(rand, 0.35, 0.5), spec.z + math.sin(a) * w * F.reach * 0.5)
			local stem = Shapes.rod(group, `Shrub{i}Stem{k}`, foot, top, w * F.width * (if k == 1 then 1.2 else 0.85), hex(F.color), F.material)
			stem.CastShadow = false
			if k > F.keepStems then Shapes.fullOnly(stem) end
		end
		-- the crown's lumps: the first `keep` on top (sunlit), the rest round the sides down to the lawn
		for k = 1, S.clusters do
			local top = k <= S.keep
			local a = rand() * TAU
			local tilt = if top then between(rand, 0, 0.55) else between(rand, 0.9, 1.75) -- from straight up
			local dir = Vector3.new(math.cos(a) * math.sin(tilt), math.cos(tilt), math.sin(a) * math.sin(tilt))
			local size = w * between(rand, S.clusterSize[1], S.clusterSize[2])
			local centre = Vector3.new(spec.x, ground + h * 0.5, spec.z) + Vector3.new(dir.X * w * 0.36, dir.Y * h * 0.36, dir.Z * w * 0.33)
			if centre.Y - size / 2 < ground then centre = Vector3.new(centre.X, ground + size / 2 - size * 0.08, centre.Z) end -- down to the lawn, not under it
			ball(`Shrub{i}Leaf{k}`, centre, size, hex(if top then pick(S.sunlit, rand) else pick(S.foliage, rand)), S.material, not top)
		end
		-- the blossoms, on the side facing the house (+z) and upward
		local colors = if spec.bloom == "pink" then S.pink else S.white
		for k = 1, S.blooms do
			local a = between(rand, 0.15, math.pi - 0.15)
			local tilt = between(rand, 0.35, 1.35)
			local dir = Vector3.new(math.cos(a) * math.sin(tilt), math.cos(tilt), math.sin(a) * math.sin(tilt))
			local at = Vector3.new(spec.x, ground + h * 0.5, spec.z) + Vector3.new(dir.X * w * 0.47, dir.Y * h * 0.47, dir.Z * w * 0.44)
			ball(`Shrub{i}Bloom{k}`, at, between(rand, S.bloomSize[1], S.bloomSize[2]) * w, hex(pick(colors, rand)), "SmoothPlastic", k > S.bloomKeep)
		end
	end
end

-- Builds the garden (window box, flowers, shrubs) into a folder "Garden" under `parent`; the UV pattern goes into `uv`.
function Plants.garden(parent: Instance, uv: Instance, place: (number, number, number) -> (Vector3, number)): Folder
	local garden = folder(parent, "Garden")
	windowBox(garden)
	local rand = Shapes.rng(G.rudbeckia.seed)
	for i, spec in G.flowers do
		rudbeckia(garden, uv, i, spec, rand)
	end
	shrubs(garden, place)
	return garden
end

-- ---------------------------------------------------------------- the grass
-- One blade of grass. `foot` is where it stands, `tip` its upper end, `direction` the way it points, `size` the ellipsoid's diameters.
export type Blade = { tuft: number, index: number, fine: boolean, size: Vector3, frame: CFrame, foot: Vector3, tip: Vector3, direction: Vector3, color: Color3 }

local GR = Flora.grass

local function shaded(c: Color3, shade: number): Color3
	return Color3.new(math.min(c.R * shade, 1), math.min(c.G * shade, 1), math.min(c.B * shade, 1))
end

-- A free place for a tuft in a region (Shapes.clearAt, and `apart` from every foot in `taken` on the same surface), or nil after forty tries.
local function tuftSpot(rand: () -> number, region: { x0: number, x1: number, z0: number, z1: number, y: number }, taken: { Vector3 }, apart: number): Vector3?
	for _ = 1, 40 do
		local x, z = between(rand, region.x0, region.x1), between(rand, region.z0, region.z1)
		if Shapes.clearAt(x, region.y, z, 0.35) then
			local clear = true
			for _, other in taken do
				if math.abs(other.Y - region.y) < 1 and (other.X - x) ^ 2 + (other.Z - z) ^ 2 < apart * apart then
					clear = false
					break
				end
			end
			if clear then return Vector3.new(x, region.y, z) end
		end
	end
	return nil
end

-- Every blade of grass on the sill, tuft by tuft: Chet's 14 patches first (five blades each, built exactly as before) and then the tufts of
-- ROBLOX-74, placed from the world's seed in Flora.grass.more.regions. Pure: the same blades every time, so the dew can stand on their tips.
function Plants.grassBlades(): { Blade }
	local out: { Blade } = {}
	local feet: { Vector3 } = {}
	for i, xyz in GR.patches do
		local origin = Vector3.new(xyz[1], xyz[2], xyz[3])
		table.insert(feet, origin)
		for j = 1, 5 do
			local turn = i * 2.399 + j * 1.257
			local height = 0.25 + ((i * 7 + j * 3) % 9) * 0.035
			local lean = Vector3.new(math.cos(turn) * 0.14, 0, math.sin(turn) * 0.14)
			local frame = CFrame.new(origin + Vector3.new(0, height * 0.5, 0) + lean * 0.5) * CFrame.Angles(0, turn, 0.22)
			table.insert(out, {
				tuft = i, index = j, fine = j > 3, size = Vector3.new(0.065, height, 0.025), frame = frame, foot = origin,
				tip = frame:PointToWorldSpace(Vector3.new(0, height * 0.5, 0)), direction = frame.UpVector, color = hex(GR.colors[1 + (i + j) % 3]),
			})
		end
	end
	local M = GR.more
	local rand = Shapes.rng(Flora.worldSeed * 100 + M.salt)
	local tuft = #GR.patches
	for _, region in M.regions do
		for _ = 1, region.n do
			local origin = tuftSpot(rand, region, feet, M.apart)
			if origin then
				tuft += 1
				table.insert(feet, origin)
				local growth = between(rand, 0.15, 1)
				local offset = rand() * TAU
				for j = 1, M.blades do
					local height = M.height[1] + (M.height[2] - M.height[1]) * math.min(growth * between(rand, 0.5, 1), 1)
					local width = between(rand, M.width[1], M.width[2])
					local turn = offset + (j - 1) * TAU / M.blades + (rand() - 0.5) * 0.9
					local tilt = between(rand, M.tilt[1], M.tilt[2])
					local frame = CFrame.new(origin) * CFrame.Angles(0, turn, tilt) * CFrame.new(0, height * 0.5, 0)
					local shade = between(rand, M.shade[1], M.shade[2])
					local a = 1 + math.floor(rand() * #GR.colors)
					local b = 1 + math.floor(rand() * #GR.colors)
					local color = shaded(hex(GR.colors[a]):Lerp(hex(GR.colors[b]), rand()), shade)
					if rand() < M.dryShare then color = shaded(hex(M.dry), shade) end
					table.insert(out, {
						tuft = tuft, index = j, fine = j > M.blades - M.fine, size = Vector3.new(width, height, width * 0.4), frame = frame, foot = origin,
						tip = frame:PointToWorldSpace(Vector3.new(0, height * 0.5, 0)), direction = frame.UpVector, color = color,
					})
				end
			end
		end
	end
	return out
end

-- Builds the grass: a folder "GrassTufts" with one folder per tuft; its fine blades sit in their own full-tier folders.
function Plants.grass(parent: Instance): Folder
	local group = folder(parent, "GrassTufts")
	local tufts: { [number]: Folder } = {}
	for _, blade in Plants.grassBlades() do
		local tuft = tufts[blade.tuft]
		if not tuft then
			tuft = folder(group, "Tuft" .. blade.tuft)
			tufts[blade.tuft] = tuft
		end
		local into: Instance = if blade.fine then folder(tuft, "Fine" .. blade.index, true) else tuft
		Shapes.ellipsoid(into, "GrassBlade", blade.size, blade.frame, blade.color, "SmoothPlastic").CastShadow = false
	end
	return group
end

-- A point on the top of the drawn leaf of the piece `id` (its blade is the piece's footprint with rounded corners): in the direction `angle`
-- (radians, in plan) from the leaf's middle, `inset` in from the edge. Used by the dew.
function Plants.leafEdge(id: string, angle: number, inset: number): Vector3
	local leaf = piece(id)
	local cx, cz = (leaf.lo.X + leaf.hi.X) / 2, (leaf.lo.Z + leaf.hi.Z) / 2
	local far = reach(cx, cz, angle, leaf.lo, leaf.hi, P.radius, inset)
	return Vector3.new(cx + math.cos(angle) * far, leaf.hi.Y, cz + math.sin(angle) * far)
end

return Plants
