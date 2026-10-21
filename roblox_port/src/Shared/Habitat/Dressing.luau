--!strict
-- Dresses the sill (ROBLOX-74, "more grass and detail"), from Data/Flora, on top of what Plants and Patina already draw: moss on the shaded
-- faces, pebbles and bark chips on the floor, two fallen leaves, and the morning dew. Pure visual density: every part is a drawn-only part
-- (Habitat/Shapes: anchored, CanCollide, CanQuery and CanTouch all false), nothing here touches Layout.PIECES, and the places it uses are
-- chosen by Shapes.clearAt, which only reads them. The dew's drops carry the attributes Lag and Base; Habitat/DayLight.applyDew sets their
-- Transparency from the hour. Everything is placed from the world's seed with a salt of its own, so every player sees the same sill. Optional
-- parts are marked FullOnly, which Client/WorldDetail removes on phones and tablets.
local Flora = require(script.Parent.Parent.Data.Flora)
local Wear = require(script.Parent.Parent.Data.Wear)
local Graphics = require(script.Parent.Parent.Data.Graphics)
local Plants = require(script.Parent.Plants)
local Shapes = require(script.Parent.Shapes)

local Dressing = {}

local hex, folder, between = Shapes.hex, Shapes.folder, Shapes.between
local TAU = 2 * math.pi

local function pick<T>(list: { T }, rand: () -> number): T
	return list[1 + math.floor(rand() * #list)]
end

local function stream(salt: number): () -> number
	return Shapes.rng(Flora.worldSeed * 100 + salt)
end

-- ---------------------------------------------------------------- moss on the shaded faces
-- The sun is behind the window, so the trough's room-side face and the foot of the back wall's room-side face are in shade. Each patch is a
-- scatter of flattened mounds lying on the face (Flora.moss); the first `core` of a patch stay in the low tier, the rest are full-tier.
function Dressing.moss(parent: Instance): Folder
	local M = Flora.moss
	local group = folder(parent, "Moss")
	local rand = stream(M.salt)
	for i, patch in M.patches do
		local normal = Vector3.new(patch.normal[1], patch.normal[2], patch.normal[3])
		local centre = Vector3.new(patch.x, patch.y, patch.z)
		local across = normal:Cross(if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
		local up = normal:Cross(across)
		local cluster = folder(group, "Patch" .. i)
		local fine = folder(cluster, "Fine", true)
		for j = 1, patch.n do
			local angle, dist = rand() * TAU, patch.r * math.sqrt(rand())
			local size = between(rand, M.size[1], M.size[2])
			local thick = size * M.mound
			local at = centre + across * (math.cos(angle) * dist) + up * (math.sin(angle) * dist)
			at = Vector3.new(at.X, math.max(at.Y, size * 0.7), at.Z) + normal * (thick * 0.35 + 0.02) -- not below the floor; sunk a third into the face
			local turn = rand() * TAU
			local along = across * math.cos(turn) + up * math.sin(turn)
			Shapes.ellipsoid(if j <= patch.core then cluster else fine, `Moss{j}`, Vector3.new(size, thick, size * between(rand, 0.7, 1)),
				Shapes.frame(at, along, normal), hex(pick(M.colors, rand)), M.material)
		end
	end
	return group
end

-- ---------------------------------------------------------------- pebbles and bark chips on the floor
-- The feet already taken on the floor (grass, the details, the coin and the Pilea's fallen leaves, the added windfall), so nothing lies on them.
local function occupied(): { Vector3 }
	local out: { Vector3 } = {}
	for _, blade in Plants.grassBlades() do table.insert(out, blade.foot) end
	for _, c in Graphics.details.chips do table.insert(out, Vector3.new(c.x, 0, c.z)) end
	for _, c in Graphics.details.crumbs do table.insert(out, Vector3.new(c.x, 0, c.z)) end
	table.insert(out, Vector3.new(Wear.coin.x, 0, Wear.coin.z))
	for _, leaf in Wear.fallen.items do table.insert(out, Vector3.new(leaf.x, 0, leaf.z)) end
	for _, leaf in Flora.windfall.items do -- a leaf is long: its middle and a point toward each end (its X runs at `turn` about the vertical)
		local turn = math.rad(leaf.turn)
		for _, along in { -0.35, 0, 0.35 } do
			table.insert(out, Vector3.new(leaf.x + math.cos(turn) * leaf.length * along, 0, leaf.z - math.sin(turn) * leaf.length * along))
		end
	end
	return out
end

-- How high the middle of a box of `size` turned by `turned` must be for its lowest point to touch the floor.
local function restHeight(turned: CFrame, size: Vector3): number
	return math.abs(turned.RightVector.Y) * size.X / 2 + math.abs(turned.UpVector.Y) * size.Y / 2 + math.abs(turned.LookVector.Y) * size.Z / 2
end

-- Pebbles first, then bark chips, in the order of Flora.litter; the first `core` of each stay in the low tier.
function Dressing.litter(parent: Instance): Folder
	local L = Flora.litter
	local group = folder(parent, "Litter")
	local rand = stream(L.salt)
	local taken = occupied()
	local function spot(margin: number): Vector3?
		for _ = 1, 40 do
			local x, z = between(rand, L.area.x0, L.area.x1), between(rand, L.area.z0, L.area.z1)
			if Shapes.clearAt(x, 0.02, z, margin) then
				local free = true
				for _, other in taken do
					if (other.X - x) ^ 2 + (other.Z - z) ^ 2 < L.apart * L.apart then
						free = false
						break
					end
				end
				if free then return Vector3.new(x, 0, z) end
			end
		end
		return nil
	end
	local B = L.pebbles
	local pebbles, loose = folder(group, "Pebbles"), folder(group, "FinePebbles", true)
	for i = 1, B.count do
		local at = spot(0.5)
		if at then
			table.insert(taken, at)
			local length = between(rand, B.length[1], B.length[2])
			local height = length * B.flat
			local size = Vector3.new(length, height, length * between(rand, 0.6, 0.9))
			local turned = CFrame.Angles(0, rand() * TAU, 0) * CFrame.Angles((rand() - 0.5) * 0.25, 0, (rand() - 0.5) * 0.25)
			Shapes.ellipsoid(if i <= B.core then pebbles else loose, "Pebble" .. i, size, CFrame.new(at.X, restHeight(turned, size) * 0.8, at.Z) * turned,
				hex(pick(B.colors, rand)), B.material) -- a fifth of its height sunk into the floor
		end
	end
	local K = L.bark
	local chips, fineChips = folder(group, "Bark"), folder(group, "FineBark", true)
	for i = 1, K.count do
		local at = spot(0.5)
		if at then
			table.insert(taken, at)
			local length, width, thick = between(rand, K.length[1], K.length[2]), between(rand, K.width[1], K.width[2]), between(rand, K.thick[1], K.thick[2])
			local size = Vector3.new(length, thick, width)
			local turned = CFrame.Angles(0, rand() * TAU, 0) * CFrame.Angles((rand() - 0.5) * K.tilt, 0, (rand() - 0.5) * K.tilt)
			Shapes.block(if i <= K.core then chips else fineChips, "Chip" .. i, size, CFrame.new(at.X, restHeight(turned, size), at.Z) * turned, hex(pick(K.colors, rand)), K.material)
		end
	end
	return group
end

-- ---------------------------------------------------------------- two fallen leaves
type Leaf = { x: number, z: number, length: number, width: number, turn: number, curl: number, color: string, rib: string }

-- The frame of a fallen leaf's blade (an ellipsoid whose X runs along the leaf and Y is its thickness), turned about the vertical and with one
-- edge lifted; the lower edge touches the floor.
function Dressing.windfallFrame(leaf: Leaf): CFrame
	local W = Flora.windfall
	local curl = math.rad(leaf.curl)
	return CFrame.new(leaf.x, W.thick * 0.5 + math.sin(curl) * leaf.width * 0.5, leaf.z) * CFrame.Angles(0, math.rad(leaf.turn), 0) * CFrame.Angles(curl, 0, 0)
end

-- The blade and a stub of stalk (both tiers) and the lighter midrib (full tier).
function Dressing.windfall(parent: Instance): Folder
	local W = Flora.windfall
	local group = folder(parent, "Windfall")
	for i, leaf in W.items do
		local frame = Dressing.windfallFrame(leaf)
		local one = folder(group, "Leaf" .. i)
		Shapes.ellipsoid(one, "Blade", Vector3.new(leaf.length, W.thick, leaf.width), frame, hex(leaf.color), W.material)
		local half = leaf.length * 0.5
		local from, to = frame:PointToWorldSpace(Vector3.new(-half * 0.95, 0, 0)), frame:PointToWorldSpace(Vector3.new(-half - W.stalk, 0, 0))
		Shapes.strip(one, "Stalk", from, to, 0.08, W.thick, hex(W.stalkColor), W.material)
		local rib = folder(one, "Detail", true)
		Shapes.strip(rib, "Rib", frame:PointToWorldSpace(Vector3.new(-half * 0.9, W.thick * 0.5, 0)), frame:PointToWorldSpace(Vector3.new(half * 0.85, W.thick * 0.5, 0)),
			0.05, 0.01, hex(leaf.rib), W.material)
	end
	return group
end

-- ---------------------------------------------------------------- the morning dew
-- Small translucent Glass droplets. Each starts fully transparent (nothing shows until DayLight.applyDew is given an hour) and carries `Lag`, the
-- share of the dew at which it appears and is gone, and `Base`, the transparency it has when it is there. Where a drop stands on something
-- that the low tier removes, it is full-tier too.
local function bead(parent: Instance, name: string, centre: Vector3, rand: () -> number, keep: boolean)
	local D = Flora.dew
	local d = between(rand, D.size[1], D.size[2])
	local drop = Shapes.ellipsoid(parent, name, Vector3.new(d, d * D.flat, d), CFrame.new(centre + Vector3.new(0, d * D.flat * 0.4, 0)), hex(D.color), D.material)
	drop.Transparency = 1
	drop.Reflectance = D.reflectance
	drop:SetAttribute("Lag", rand() * D.lag)
	drop:SetAttribute("Base", between(rand, D.transparency[1], D.transparency[2]))
	if not keep then drop:SetAttribute("FullOnly", true) end
end

-- Drops on the tallest blade of most tufts (at the tip), around the rim of each green Pilea leaf and on the fallen leaves' edges, in a folder
-- "Dew". The Pilea and fallen-leaf drops stand on the top of the leaf. Returns the folder.
function Dressing.dew(parent: Instance): Folder
	local D = Flora.dew
	local group = folder(parent, "Dew")
	local rand = stream(D.salt)

	local grass = folder(group, "Grass")
	local tallest: { [number]: Plants.Blade } = {}
	local order: { number } = {}
	for _, blade in Plants.grassBlades() do
		local best = tallest[blade.tuft]
		if not best then table.insert(order, blade.tuft) end
		if not best or blade.size.Y > best.size.Y then tallest[blade.tuft] = blade end
	end
	local n = 0
	for _, tuft in order do
		if rand() < D.grass.chance then
			local blade = tallest[tuft]
			n += 1
			bead(grass, "Drop" .. n, blade.tip - blade.direction * 0.08, rand, not blade.fine and n % D.grass.keepEvery == 1)
		end
	end

	local leaves = folder(group, "Leaves")
	for i, plant in Flora.pilea.plants do
		local kept = 0
		for k = 1, D.pilea.perLeaf do
			local angle = TAU * (k - 1 + (rand() - 0.5) * 0.4) / D.pilea.perLeaf + i
			local keep = k % 2 == 1 and kept < D.pilea.keep
			if keep then kept += 1 end
			bead(leaves, `Drop{i}_{k}`, Plants.leafEdge(plant.leaf, angle, D.pilea.inset), rand, keep)
		end
	end

	local fallen = folder(group, "Windfall", true)
	for i, leaf in Flora.windfall.items do
		local frame = Dressing.windfallFrame(leaf)
		for k = 1, D.windfall.perLeaf do
			local angle = TAU * (k - 1 + (rand() - 0.5) * 0.4) / D.windfall.perLeaf + i
			local at = frame:PointToWorldSpace(Vector3.new(math.cos(angle) * leaf.length * 0.36, Flora.windfall.thick * 0.3, math.sin(angle) * leaf.width * 0.36))
			bead(fallen, `Drop{i}_{k}`, at, rand, true)
		end
	end
	return group
end

return Dressing
