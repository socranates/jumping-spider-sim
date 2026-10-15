--!strict
-- Builds what age and use have done to the sill, the glass and the retreat, from Data/Wear: a worn strip along the front lip, grime
-- in the corners, dust bunnies, condensation and smudges on the glass, the silk retreat in the crevice, and a copper coin and some
-- fallen Pilea leaves on the floor. All flat, tiny or thin and drawn only (Habitat/Shapes: nothing collides with it and no ray
-- sees it); each builder returns a folder, and the optional ones are marked FullOnly for Client/WorldDetail.
local Graphics = require(script.Parent.Parent.Data.Graphics)
local Wear = require(script.Parent.Parent.Data.Wear)
local Shapes = require(script.Parent.Shapes)

local Patina = {}

local hex, folder, between = Shapes.hex, Shapes.folder, Shapes.between
local TAU = 2 * math.pi

-- ---------------------------------------------------------------- the sill (full tier)
-- Bare wood along the lip's top front edge, grime where the floor meets the walls, dust bunnies in the corners.
function Patina.sill(parent: Instance): Folder
	local wear = folder(parent, "Wear", true)
	local L = Wear.lip
	local rand = Shapes.rng(L.seed)
	local x, n = L.x0, 0
	while x < L.x1 do
		local length = math.min(between(rand, L.runs[1], L.runs[2]), L.x1 - x)
		local z0 = L.z0 + between(rand, 0, 0.04)
		n += 1
		Shapes.block(wear, "LipWear" .. n, Vector3.new(length, L.height, L.z1 - z0), CFrame.new(x + length / 2, L.y + L.height / 2, (z0 + L.z1) / 2),
			hex(L.colors[1 + math.floor(rand() * #L.colors)]), Wear.bare.material)
		x += length + between(rand, L.gaps[1], L.gaps[2])
	end
	local G = Wear.grime
	local grime = folder(wear, "Grime")
	local y = G.height / 2 + 0.001
	for i, line in G.lines do
		local p = Shapes.strip(grime, "Grime" .. i, Vector3.new(line[1], y, line[2]), Vector3.new(line[3], y, line[4]), line[5], G.height, hex(G.color), "SmoothPlastic")
		p.Transparency = G.transparency
	end
	local B = Wear.bunnies
	for i, bunny in B.items do
		local cluster = folder(wear, "DustBunny" .. i)
		local brand = Shapes.rng(bunny.seed)
		for j = 1, bunny.count do
			local a, d = brand() * TAU, bunny.spread * math.sqrt(brand())
			local r = between(brand, B.radius[1], B.radius[2])
			local fluff = Shapes.ellipsoid(cluster, `Fluff{j}`, Vector3.new(2 * r, 2 * r * B.lift, 2 * r),
				CFrame.new(bunny.x + math.cos(a) * d, r * B.lift, bunny.z + math.sin(a) * d) * CFrame.Angles(0, brand() * TAU, 0), hex(B.color), "Fabric")
			fluff.Transparency = B.transparency + brand() * 0.12
		end
	end
	return wear
end

-- ---------------------------------------------------------------- the glass (full tier)
-- Condensation on the lower panes (tiny flattened Glass spheres) and two faint smudges, on the room side of the glass.
function Patina.glass(parent: Instance): (Folder, Folder)
	local W = Graphics.window
	local face = Shapes.piece(W.hidden).hi.Z - W.glass.setback -- the glass's room-side face
	local D = Wear.drops
	local drops = folder(parent, "Condensation", true)
	local rand = Shapes.rng(D.seed)
	for i = 1, D.count do
		local pane = D.panes[1 + math.floor(rand() * #D.panes)]
		local d = D.size[1] + (D.size[2] - D.size[1]) * rand() ^ 2.2
		local run = 1.15 + (d - D.size[1]) / (D.size[2] - D.size[1]) * 0.9 -- bigger drops are longer: they have started to run
		local drop = Shapes.ellipsoid(drops, "Drop" .. i, Vector3.new(d, math.min(d * run, D.size[2]), 2 * D.flat),
			CFrame.new(between(rand, pane[1], pane[2]), D.y[1] + (D.y[2] - D.y[1]) * rand() ^ 1.8, face + D.flat), hex(D.color), "Glass")
		drop.Transparency = D.transparency
		drop.Reflectance = D.reflectance
	end
	local S = Wear.smudges
	local smudges = folder(parent, "Smudges", true)
	for i, m in S.items do
		local smudge = Shapes.ellipsoid(smudges, "Smudge" .. i, Vector3.new(m.w, m.h, 0.01),
			CFrame.new(m.x, m.y, face + 0.006) * CFrame.Angles(0, 0, math.rad(m.turn)), hex(S.color), "SmoothPlastic")
		smudge.Transparency = S.transparency
	end
	return drops, smudges
end

-- ---------------------------------------------------------------- the silk retreat in the crevice
-- A few overlapping, translucent shells at the back and threads across the opening: salticids rest in silk retreats.
function Patina.retreat(parent: Instance): Folder
	local S = Wear.silk
	local retreat = folder(parent, "Retreat")
	local silk = hex(S.color)
	for i, shell in S.shells do
		local piece = Shapes.ellipsoid(retreat, "Shell" .. i, Vector3.new(2 * shell[4], 2 * shell[5], 2 * shell[6]), CFrame.new(shell[1], shell[2], shell[3]), silk, "SmoothPlastic")
		piece.Transparency = S.shellTransparency
	end
	for i, thread in S.threads do
		local strand = Shapes.strip(retreat, "Thread" .. i, Vector3.new(thread[1], thread[2], thread[3]), Vector3.new(thread[4], thread[5], thread[6]), S.thread, S.thread, silk, "SmoothPlastic")
		strand.Transparency = S.threadTransparency
	end
	return retreat
end

-- ---------------------------------------------------------------- small things on the floor (full tier)
-- A copper coin lying flat, plain faces, and a few fallen brown Pilea leaves, each with a stub of stalk.
function Patina.floor(parent: Instance)
	local C = Wear.coin
	Shapes.disc(parent, "Coin", C.diameter, C.thickness, Vector3.new(C.x, C.thickness / 2, C.z), hex(C.color), C.material).CastShadow = true
	local F = Wear.fallen
	for i, leaf in F.items do
		Shapes.disc(parent, "FallenLeaf" .. i, leaf.diameter, F.thickness, Vector3.new(leaf.x, F.thickness / 2, leaf.z), hex(leaf.color), F.material)
		local a = i * 2.1
		local from = Vector3.new(leaf.x + math.cos(a) * leaf.diameter * 0.45, F.thickness / 2, leaf.z + math.sin(a) * leaf.diameter * 0.45)
		local to = from + Vector3.new(math.cos(a), 0, math.sin(a)) * 0.55
		Shapes.strip(parent, `FallenStalk{i}`, from, to, 0.08, F.thickness, hex("7d5c30"), F.material)
	end
end

return Patina
