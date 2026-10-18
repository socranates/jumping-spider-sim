-- World checks: the graphics table, the sun pick, the scenery the server builds, the lighting set-up and the low-detail tier
-- on the client. The real Graphics, Materials, SunPick, Scenery, Lit, Detail and WorldDetail modules run under the shim
-- (tests/shim.luau); the sun is an invented one, not Roblox's. This says nothing about how any of it LOOKS in Roblox: lighting,
-- materials, haze and shafts can only be judged in Studio (tests/studio/GraphicsSpec.luau checks what the engine can).
local Graphics = require("../src/Shared/Data/Graphics")
local Detail = require("../src/Shared/Data/Detail")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Materials = require("../src/Shared/Habitat/Materials")
local SunPick = require("../src/Shared/Habitat/SunPick")
local Scenery = require("../src/Shared/Habitat/Scenery")
local Flora = require("../src/Shared/Data/Flora")
local Wear = require("../src/Shared/Data/Wear")
local Plants = require("../src/Shared/Habitat/Plants")
local Shapes = require("../src/Shared/Habitat/Shapes")
local Dressing = require("../src/Shared/Habitat/Dressing")
local DayLight = require("../src/Shared/Habitat/DayLight")
local Lit = require("../src/Shared/Habitat/Lit")
local WorldDetail = require("../src/Client/WorldDetail")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL world: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local function rgb(c: Color3): string return string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B) end

local W, M = Graphics.window, Graphics.materials
local function piece(id: string)
	for _, p in Layout.PIECES do if p.id == id then return p end end
	error("no piece " .. id)
end

-- The expansion is additive and climbable, with a continuous old-wall route to the upper shelf.
check(piece("upper_ledge").lo.Y < piece("back_frame").hi.Y and piece("upper_ledge").lo.Z == piece("back_frame").hi.Z,
 "upper garden shelf touches the climbable back wall")
check(piece("stem_garden").lo.Y == piece("garden_step").hi.Y and piece("stem_garden").hi.Y == piece("leaf_garden").lo.Y,
 "new terracotta step and plant form a continuous climbing route")
check(piece("stem_high").lo.Y == 0 and piece("stem_high").hi.Y == piece("leaf_high").lo.Y,
 "high leaf has a climbable route from the sill")
-- ---------------------------------------------------------------- the graphics table
local unknown = {}
local function mat(name: string) if not Materials.known(name) then table.insert(unknown, name) end end
for _, name in M.pieces do mat(name) end
for _, key in { "soil", "wall", "trim", "glass", "view", "ground", "chip", "crack", "crumb", "fallback" } do mat(M[key]) end
check(#unknown == 0, "every material name in the graphics table is one Materials knows (unknown: " .. table.concat(unknown, ", ") .. ")")
local unmapped = {}
for _, p in Layout.PIECES do if not M.pieces[p.id] then table.insert(unmapped, p.id) end end
check(#unmapped == 0, "every sill piece has a material (" .. table.concat(unmapped, ", ") .. ")")
check(M.pieces.sill_floor == "SmoothPlastic" and M.pieces.front_lip == "SmoothPlastic" and M.pieces.planter == "Plaster" and M.wall == "Plaster"
	and M.glass == "SmoothPlastic" and M.soil == "Ground" and M.pieces.leaf_west == "SmoothPlastic" and M.pieces.leaf_tip == "Plaster" and M.chip == "Wood",
	"cream enamel sill, plaster planter and walls, non-refracting transparent window for UV visibility, ground soil, glossy leaves, bare wood under the chips")
local paint = Graphics.paint
check(paint.sill_floor.color == "e8dfcb" and paint.front_lip.color == "e8dfcb" and paint.sill_floor.reflectance == 0.03 and paint.front_lip.reflectance == 0.03
	and paint.planter.color == "b8653f" and paint.planter_rim.color == "c97a52" and paint.left_frame.color == "efe8d8" and paint.right_frame.color == "efe8d8",
	"the sill is cream enamel, the trough terracotta, the side walls plaster")
check(W.wallColor == "efe8d8" and W.trimColor == "f4efe3" and W.trimReflectance > 0 and W.glass.color == "cfe3e6" and W.glass.transparency == 0.86 and W.glass.reflectance == 0.12,
	"plaster wall, glossy cream trim, pale blue-green glass")
check(Graphics.bloom.threshold >= 1.2 and Graphics.bloom.intensity <= 0.5 and Graphics.sunRays.intensity <= 0.1
	and math.abs(Graphics.grade.contrast) <= 0.15 and math.abs(Graphics.grade.saturation) <= 0.15, "bloom, sun rays and grade are gentle")
check(Graphics.bloom.intensity == 0.45 and Graphics.bloom.size == 24 and Graphics.bloom.threshold == 1.4 and Graphics.grade.contrast == 0.1 and Graphics.grade.saturation == 0.1
	and rgb(Color3.fromRGB(Graphics.grade.tint[1], Graphics.grade.tint[2], Graphics.grade.tint[3])) == rgb(Color3.fromRGB(255, 246, 232)), "the morning grade: warm tint, a touch of contrast and colour, soft bloom")
local DOF = Graphics.depthOfField
check(DOF.far == 0.3 and DOF.near == 0 and DOF.radius == 18, "the macro depth of field blurs only what is far")
check(Graphics.lighting.shadowSoftness >= 0.1 and Graphics.lighting.shadowSoftness <= 0.4 and math.abs(Graphics.lighting.exposureCompensation) <= 0.3
	and Graphics.atmosphere.density <= 0.5 and Graphics.atmosphere.offset >= 0 and Graphics.atmosphere.offset <= 1, "soft shadows, mild exposure and haze")
check(Graphics.tiers.low.dustRate < Graphics.tiers.full.dustRate and Graphics.tiers.low.dustRate > 0, "the low tier thins the dust rather than removing it")

-- ---------------------------------------------------------------- which detail tier
check(Detail.choose(true, nil) == "low" and Detail.choose(false, nil) == "full", "touch-only devices get the low tier")
check(Detail.choose(true, "full") == "full" and Detail.choose(false, "low") == "low", "the Detail attribute overrides the guess")
check(Detail.choose(false, "bogus") == "full" and Detail.choose(true, 42) == "low", "a bad Detail attribute is ignored")

-- ---------------------------------------------------------------- the sun pick, with invented suns
-- Declination 0: the sun's (east, up, north) at a clock time and latitude. The world axes are not known, so try both
-- directions of Z (the sun at noon is in the south: -north).
local function astronomical(flipZ: number): (number, number) -> Vector3
	return function(clock: number, latitude: number): Vector3
		local h, phi = math.rad((clock - 12) * 15), math.rad(latitude)
		return Vector3.new(-math.sin(h), math.cos(phi) * math.cos(h), -math.sin(phi) * math.cos(h) * flipZ).Unit
	end
end
for _, flip in { 1, -1 } do
	local pick = SunPick.choose(astronomical(flip), 9.6, 40.7, Graphics.sun)
	local why = `flip {flip}: {pick.reason}`
	print(`world: invented sun, z flip {flip}: picks clock {pick.clock}, latitude {pick.latitude}, {string.format("%.0f", pick.elevationDeg)} degrees high, {string.format("%.0f", pick.azimuthDeg)} degrees off straight-out-of-the-window`)
	check(pick.ok and pick.direction.Z < -0.3 and pick.direction.Y > 0.3, "a sun behind the window is found (" .. why .. ")")
	check(math.abs(pick.elevationDeg - Graphics.sun.elevationDeg) <= 10 and pick.azimuthDeg <= Graphics.sun.maxAzimuthDeg, "it is middling high and not along the wall (" .. why .. ")")
	check((pick.latitude == 40.7) == (flip == 1), "the latitude's sign flips when the sun runs the other way (" .. why .. ")")
end
local fixed = SunPick.choose(function(_c, _l) return Vector3.new(0.3, 0.5, -0.8).Unit end, 9.6, 40.7, Graphics.sun)
check(not fixed.ok and fixed.clock == 9.6 and fixed.latitude == 40.7, "a sun that ignores the clock is not 'picked'")
local front = SunPick.choose(function(clock, _l) return Vector3.new(math.sin(clock), 0.5, 0.8).Unit end, 9.6, 40.7, Graphics.sun)
check(not front.ok and front.clock == 9.6, "no sun behind the window: the old morning light stays")
local midday = SunPick.choose(function(clock, l) return Vector3.new(0.3, 1 + 0.01 * clock, -0.2).Unit end, 9.6, 40.7, Graphics.sun)
check(not midday.ok, "a sun that is never in the allowed height range is not picked")

-- ---------------------------------------------------------------- the sill's pieces: looks only
local sill = Scenery.sill()
local sillOk, listed = true, {}
for _, spec in Layout.PIECES do
	local p = sill:FindFirstChild(spec.id)
	listed[spec.id] = p
	local painted = Graphics.paint[spec.id]
	sillOk = sillOk and p ~= nil and (p.Size - (spec.hi - spec.lo)).Magnitude < 1e-9 and (p.Position - (spec.lo + spec.hi) * 0.5).Magnitude < 1e-9
		and p.Anchored and p.CanQuery ~= false and p.CanCollide ~= false
		and p:GetAttribute("SurfaceId") == spec.id and p:GetAttribute("ProfileId") == spec.profile
		and rgb(p.Color) == rgb(if painted then Color3.fromHex(painted.color) else spec.color) and (p.Reflectance or 0) == (painted and painted.reflectance or 0)
end
check(sillOk and #sill:GetChildren() == #Layout.PIECES, "the sill's pieces keep their geometry, profile, solidity and queryability, and wear the painted colours")
-- The back wall and the Pilea's leaves and stems are drawn in their place (still solid and climbable, no shadow); nothing else is hidden.
local expectHidden: { [string]: boolean } = { [W.hidden] = true }
for _, id in Plants.pieceIds() do expectHidden[id] = true end
local hiddenOk, hiddenCount = true, 0
for _, spec in Layout.PIECES do
	local p = listed[spec.id]
	if expectHidden[spec.id] then
		hiddenCount += 1
		hiddenOk = hiddenOk and p.Transparency == 1 and p.CastShadow == false and p.CanCollide ~= false and p.CanQuery ~= false
	else
		hiddenOk = hiddenOk and p.Transparency == 0 and p.CastShadow ~= false
	end
end
check(hiddenOk and hiddenCount == 12, `only the back wall and the Pilea's pieces turn invisible, and they stay solid ({hiddenCount})`)
-- If a drawing could not be built (Main.server.luau catches that), what it replaces must not be left invisible.
local plain = Scenery.sill({})
local plainBack = plain:FindFirstChild("back_frame") :: Part
local plainLeaf = plain:FindFirstChild("leaf_west") :: Part
check(plainBack.Transparency == 0 and plainBack.CastShadow ~= false and plainLeaf.Transparency == 0 and #plain:GetChildren() == #Layout.PIECES, "without the drawings the wall and the leaves stay visible")

-- ---------------------------------------------------------------- the decor
local sun = Vector3.new(0.35, 0.5, -0.8).Unit
local decor, drawnIds = Scenery.decor(sun)
local parts, bad = {}, 0
for _, d in decor:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		if d.CanQuery ~= false or d.CanCollide ~= false or d.CanTouch ~= false or not d.Anchored then bad += 1 end
	end
end
check(bad == 0, "every decor part is anchored, non-colliding, not touchable and invisible to rays")
local sameSet = true
for id in expectHidden do sameSet = sameSet and drawnIds[id] == true end
for id in drawnIds do sameSet = sameSet and expectHidden[id] == true end
check(sameSet, "the decor reports exactly the pieces it drew: the wall and the Pilea's leaves, stems and tip")

-- An optional piece that fails is left out with a warning; the wall and the other pieces stay.
do
	local warned = {}
	warn = function(message: string) table.insert(warned, message) end
	local realDetails = Scenery.details
	Scenery.details = function() error("boom") end
	local partial = Scenery.decor(sun)
	Scenery.details = realDetails
	check(#warned == 1 and string.find(warned[1], "details", 1, true) ~= nil and partial:FindFirstChild("Wall") ~= nil
		and partial:FindFirstChild("Shafts") ~= nil and partial:FindFirstChild("View") ~= nil and partial:FindFirstChild("Details") == nil,
		"an optional piece that fails is left out with a warning, and the rest of the decor is kept")
end

-- If the Pilea fails halfway, what it had built is removed and its pieces stay visible (nothing is hidden for a drawing that is not there).
do
	local warned = {}
	warn = function(message: string) table.insert(warned, message) end
	local realPilea = Plants.pilea
	Plants.pilea = function(parent: Instance): Folder
		local half = Instance.new("Folder")
		half.Name = "Pilea"
		half.Parent = parent
		error("boom")
	end
	local partial, partialDrawn = Scenery.decor(sun)
	Plants.pilea = realPilea
	local stand = Scenery.sill(partialDrawn)
	local leaf, stem, wall = stand:FindFirstChild("leaf_west") :: Part, stand:FindFirstChild("stem_east") :: Part, stand:FindFirstChild(W.hidden) :: Part
	check(#warned == 1 and string.find(warned[1], "pilea", 1, true) ~= nil and partial:FindFirstChild("Pilea") == nil and partialDrawn.leaf_west == nil and partialDrawn.leaf_tip == nil
		and partialDrawn[W.hidden] == true and leaf.Transparency == 0 and leaf.CastShadow ~= false and stem.Transparency == 0 and wall.Transparency == 1
		and partial:FindFirstChild("Garden") ~= nil and partial:FindFirstChild("Planter") ~= nil,
		"if the Pilea fails, its half-built parts are removed, its pieces stay visible, and the rest of the decor is kept")
end
check(#parts >= 400 and #parts < 1500, `decor part count stays inside the full-tier budget ({#parts})`)
for _, name in { "Wall", "View", "Details", "Shafts", "DustVolume", "soil", "silk_0", "silk_6", "Pilea", "Planter", "Garden", "Wear", "Condensation", "Smudges", "Retreat", "UVLayer" } do
	check(decor:FindFirstChild(name) ~= nil, "decor has " .. name)
end
check(decor:FindFirstChild("window_glass") == nil and decor:FindFirstChild("mullion_w") == nil, "the old glass and mullions are replaced by the new wall")
-- Rays see the physical sill only.
workspace:ClearAllChildren()
sill.Parent = workspace
decor.Parent = workspace
local ray = workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, 0, -30), RaycastParams.new())
check(ray ~= nil and ray.Instance.Name == "back_frame" and near(ray.Position.Z, -12.5, 1e-6), "a ray across the sill lands on the solid back wall, through the glass")
local onlyDecor = RaycastParams.new()
onlyDecor.FilterType = Enum.RaycastFilterType.Include
onlyDecor.FilterDescendantsInstances = { decor }
check(workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, 0, -30), onlyDecor) == nil and workspace:Raycast(Vector3.new(5, 5, -30), Vector3.new(0, -9, 0), onlyDecor) == nil, "no ray ever hits a decor part")

-- The drawn wall covers the solid wall's face except the opening, and stays behind the climbable face.
local plane = piece("back_frame").hi.Z
local wall = decor:FindFirstChild("Wall")
local wallParts = wall:GetChildren()
local maxFront = -math.huge
for _, p in wallParts do maxFront = math.max(maxFront, p.Position.Z + p.Size.Z / 2) end
check(near(maxFront, plane, 1e-9), "the trim is flush with the climbable face and nothing of the wall stands in front of it")
local gaps, samples = 0, 0
local back = piece("back_frame")
for xi = 0, 60 do
	for yi = 0, 28 do
		local x = back.lo.X + (back.hi.X - back.lo.X) * (xi + 0.5) / 61
		local y = back.lo.Y + (back.hi.Y - back.lo.Y) * (yi + 0.5) / 29
		local covered = false
		for _, p in wallParts do
			local h = p.Size / 2
			local c = p.Position
			if math.abs(x - c.X) <= h.X and math.abs(y - c.Y) <= h.Y then covered = true break end
		end
		samples += 1
		if not covered then gaps += 1 end
	end
end
check(gaps == 0, `the drawn wall and glass cover the whole back wall ({gaps} of {samples} points bare)`)
local glass = wall:FindFirstChild("Glass")
check(glass.Transparency >= 0.6 and glass.Position.Z + glass.Size.Z / 2 < plane - 0.02 and near(glass.Size.X, W.right - W.left, 1e-9)
	and near(glass.Size.Y, W.top - W.bottom, 1e-9), "the glass fills the opening, a little behind the climbable face, mostly clear")
local opening = 0
for _, p in wallParts do
	local inset = W.trimWidth + 0.01 -- the trim bars frame the opening's edge
	if p.Name ~= "Glass" and p.Position.X > W.left + inset and p.Position.X < W.right - inset and p.Position.Y > W.bottom + inset and p.Position.Y < W.top - inset then
		if not string.find(p.Name, "Mullion") then opening += 1 end
	end
end
check(opening == 0, "nothing but mullions crosses the opening")

-- The view: beyond the wall, placed so that it shows through the glass from the reference eye.
local view = decor:FindFirstChild("View")
local nearest, shown, fullOnly = math.huge, 0, 0
local viewCount = #view:GetChildren()
for _, p in view:GetChildren() do
	if p.Name ~= "Ground" then nearest = math.min(nearest, -(p.Position.Z + p.Size.Z / 2)) end -- the ground runs on under the sill, far below
	if p:GetAttribute("FullOnly") then fullOnly += 1 end
end
check(nearest > -piece("back_frame").lo.Z, `the whole view is outside, beyond the wall (nearest {string.format("%.1f", nearest)})`)
for _, item in Graphics.view.items do
	local at, k = Scenery.viewPosition(item.u, item.v, item.depth)
	local eye = Graphics.view.eye
	local u, v = eye.X + (at.X - eye.X) / k, eye.Y + (at.Y - eye.Y) / k
	if near(u, item.u, 1e-9) and near(v, item.v, 1e-9) and at.Z == plane - item.depth then
		if item.u > W.left and item.u < W.right and item.v > W.bottom and item.v < W.top then shown += 1 end
	end
end
check(shown >= 14, `the roofs, chimneys and treetops appear inside the glass from the reference eye ({shown})`)
check(fullOnly >= 8 and fullOnly < viewCount - 8, `the view keeps a simple core for the low tier ({fullOnly} of {viewCount} are full-only)`)

-- Small details: low and flat, clear of the spawn, the retreat and the silk practice lines.
local function extent(p: any): Vector3 -- half the size of a part's bounding box along the world axes (a turned part is wider than its Size says)
	local c, s = p.CFrame, p.Size / 2
	local x, y, z = c.RightVector, c.UpVector, c.LookVector
	return Vector3.new(
		math.abs(x.X) * s.X + math.abs(y.X) * s.Y + math.abs(z.X) * s.Z,
		math.abs(x.Y) * s.X + math.abs(y.Y) * s.Y + math.abs(z.Y) * s.Z,
		math.abs(x.Z) * s.X + math.abs(y.Z) * s.Y + math.abs(z.Z) * s.Z)
end
local details = decor:FindFirstChild("Details")
local clear, lowest, count = true, 0, 0
local SPAWN = Layout.SPAWN
for _, p in details:GetChildren() do
	count += 1
	local c, h = p.Position, extent(p)
	lowest = math.max(lowest, c.Y + h.Y)
	local nearSpawn = (Vector3.new(c.X, 0, c.Z) - Vector3.new(SPAWN.X, 0, SPAWN.Z)).Magnitude < 4
	local inRetreat = c.X > Layout.RETREAT_MIN.X - 1.5 and c.X < Layout.RETREAT_MAX.X + 1.5 and c.Z > Layout.RETREAT_MIN.Z - 1.5 and c.Z < Layout.RETREAT_MAX.Z + 1.5
	clear = clear and not nearSpawn and not inRetreat and math.abs(c.X) < 30 and c.Z > -12.5 and c.Z < 12.5
end
check(clear and count >= 18, `paint chips, cracks and crumbs sit on the sill, clear of the spawn and the silk lines ({count})`)
check(lowest <= 0.25, "details are low enough not to hide the landing patch")

-- ---------------------------------------------------------------- the look of the sill's things (Data/Flora, Data/Wear)
local function luminance(c: Color3): number return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
local function same(c: Color3, hex: string): boolean return rgb(c) == rgb(Color3.fromHex(hex)) end
local function find(root: any, ...: string): any -- a descendant by path; nil if a step is missing
	local at: any = root
	for _, name in { ... } do
		if at == nil then return nil end
		at = at:FindFirstChild(name)
	end
	return at
end
local function named(root: any, prefix: string): { any } -- the children whose names start with `prefix`
	local out = {}
	for _, c in root:GetChildren() do
		if string.sub(c.Name, 1, #prefix) == prefix then table.insert(out, c) end
	end
	return out
end
local Mat = Materials.get

-- The Pilea: pancake leaves whose tops are their pieces' tops and whose footprints fill the pieces (the corners rounded), petioles
-- inscribed in the stem pieces, pale dots and 7 to 9 veins on each leaf, a darker rim and a lighter underside, a curled dry leaf.
local pilea = find(decor, "Pilea")
local topsOk, footOk, rodsOk, veinsOk, dotsOk, coloursOk = true, true, true, true, true, true
local veinCounts = {}
local function blade(group: any, lo: Vector3, hi: Vector3): (boolean, boolean)
	local x0, x1, z0, z1, top, bottom = math.huge, -math.huge, math.huge, -math.huge, -math.huge, math.huge
	for _, part in named(group, "Blade") do
		local e = extent(part)
		x0, x1 = math.min(x0, part.Position.X - e.X), math.max(x1, part.Position.X + e.X)
		z0, z1 = math.min(z0, part.Position.Z - e.Z), math.max(z1, part.Position.Z + e.Z)
		top, bottom = math.max(top, part.Position.Y + e.Y), math.min(bottom, part.Position.Y - e.Y)
	end
	return near(top, hi.Y, 1e-9) and near(bottom, lo.Y, 1e-9), near(x0, lo.X, 1e-9) and near(x1, hi.X, 1e-9) and near(z0, lo.Z, 1e-9) and near(z1, hi.Z, 1e-9)
end
for _, plant in Flora.pilea.plants do
	local leaf, stem = piece(plant.leaf), piece(plant.stem)
	local group = find(pilea, plant.leaf)
	local topOk, footprint = blade(group, leaf.lo, leaf.hi)
	topsOk, footOk = topsOk and topOk, footOk and footprint
	local rod = find(group, "Petiole")
	local cx, cz = (stem.lo.X + stem.hi.X) / 2, (stem.lo.Z + stem.hi.Z) / 2
	rodsOk = rodsOk and rod ~= nil and rod.Shape == Enum.PartType.Cylinder and near(rod.Size.Y, rod.Size.Z, 1e-9) and near(rod.Size.X, stem.hi.Y - stem.lo.Y, 1e-9)
		and rod.Size.Y <= math.min(stem.hi.X - stem.lo.X, stem.hi.Z - stem.lo.Z) + 1e-9 and math.abs(rod.CFrame.RightVector.Y) > 0.999
		and near(rod.Position.X, cx, 1e-9) and near(rod.Position.Z, cz, 1e-9) and near(rod.Position.Y, (stem.lo.Y + stem.hi.Y) / 2, 1e-9)
		and same(rod.Color, Flora.pilea.petiole)
	local detail = find(group, "Detail")
	local veins = named(detail, "Vein")
	table.insert(veinCounts, #veins)
	for _, vein in veins do
		veinsOk = veinsOk and near(vein.Position.Y - vein.Size.Y / 2, leaf.hi.Y, 1e-9) and vein.Size.Y <= 0.01 and vein.Size.X <= 0.06 and luminance(vein.Color) > luminance(Color3.fromHex(Flora.pilea.top))
	end
	local dot = find(detail, "Dot")
	dotsOk = dotsOk and dot ~= nil and near(dot.Position.X, cx, 1e-9) and near(dot.Position.Z, cz, 1e-9) and near(dot.Position.Y - dot.Size.X / 2, leaf.hi.Y, 1e-9)
	local top, rim, under = find(group, "BladeA"), find(detail, "RimA"), find(detail, "UnderA")
	coloursOk = coloursOk and same(top.Color, Flora.pilea.top) and top.Material == Mat("SmoothPlastic") and luminance(rim.Color) < luminance(top.Color) and luminance(under.Color) > luminance(top.Color)
		and rim.Position.Y + extent(rim).Y < leaf.hi.Y and under.Position.Y - extent(under).Y < leaf.lo.Y
end
check(topsOk, "each drawn leaf's top is exactly its piece's top (and its underside the piece's underside)")
check(footOk and Flora.pilea.radius * (math.sqrt(2) - 1) <= 0.7, "each drawn leaf fills its piece's footprint, with corners rounded by less than 0.7")
check(rodsOk, "each petiole is a Cylinder part inscribed in its stem's box, upright, with Size (length, d, d)")
check(veinsOk and dotsOk and #veinCounts == #Flora.pilea.plants and veinCounts[1] >= 7 and veinCounts[1] <= 9 and veinCounts[2] >= 7 and veinCounts[2] <= 9 and veinCounts[3] >= 7 and veinCounts[3] <= 9,
	`each leaf has a pale dot where the stalk joins and 7 to 9 thin, lighter veins ({table.concat(veinCounts, ", ")})`)
check(coloursOk, "leaves are glossy green with a darker rim band and a lighter underside")
do
	local tip = piece(Flora.pilea.tip)
	local group = find(pilea, Flora.pilea.tip)
	local topOk, footprint = blade(group, tip.lo, tip.hi)
	check(topOk and footprint and same(find(group, "BladeA").Color, "c9a66b") and #named(find(group, "Detail"), "Edge") == 4 and #named(find(group, "Detail"), "Curl") == #Flora.pilea.dry.curls
		and find(group, "Detail"):GetAttribute("FullOnly") == true, "the dry leaf is a tan plate with darker edges and curled corners, on its piece")
end
do -- cracks and crumbled soil at the stem bases (full tier)
	local base = find(pilea, "leaf_west", "Base")
	local cracks, crumbs = named(base, "Crack"), named(base, "Crumb")
	check(base:GetAttribute("FullOnly") == true and #cracks >= 6 and #crumbs >= 5, `cracks and crumbled soil at the stem base ({#cracks} crack strips, {#crumbs} crumbs)`)
end

-- The trough: terracotta with a darker water-stain band, dark soil, pebbles, moss, tiny seedlings.
do
	local planter = find(decor, "Planter")
	local T = Flora.planter
	local stainFaces = find(planter, "Stain"):GetChildren()
	check(#stainFaces == 4 and luminance(Color3.fromHex(T.stain.color)) < luminance(Color3.fromHex(Graphics.paint.planter.color)) and find(planter, "Stain"):GetAttribute("FullOnly") == true,
		"a darker water-stain band on all four faces of the trough")
	check(same(find(decor, "soil").Color, "4a3a2c") and find(decor, "soil").Material == Mat("Ground"), "the soil is dark ground")
	local pebbles = find(planter, "Pebbles"):GetChildren()
	local pebbleOk = #pebbles == T.pebbles.count
	for _, pebble in pebbles do
		pebbleOk = pebbleOk and pebble.Size.X >= 0.3 - 1e-9 and pebble.Size.X <= 0.8 + 1e-9 and pebble.Size.Y < pebble.Size.X and pebble.Position.X > 4 and pebble.Position.X < 16
			and pebble.Position.Z > -7 and pebble.Position.Z < -1 and pebble:FindFirstChild("Mesh") == nil and pebble:FindFirstChildWhichIsA("SpecialMesh") ~= nil
	end
	check(pebbleOk, `pebbles are flattened ellipsoids 0.3 to 0.8 long, on the soil ({#pebbles})`)
	local mossOk, mossCount = true, 0
	for _, bit in find(planter, "Moss"):GetChildren() do
		mossCount += 1
		mossOk = mossOk and bit.Position.X > 4 and bit.Position.X < 16 and bit.Position.Z > -7 and bit.Position.Z < -1 and bit.Color.G > bit.Color.R
	end
	check(mossOk and mossCount >= 15, `moss patches are green and on the soil ({mossCount})`)
	local seedlings = find(planter, "Seedlings")
	local tallest = 0
	for _, bit in seedlings:GetChildren() do tallest = math.max(tallest, bit.Position.Y + extent(bit).Y - T.area.y) end
	check(#T.seedlings >= 2 and #T.seedlings <= 3 and tallest > 0.3 and tallest < 1, `2 or 3 seedlings, each under a centimetre tall (tallest {string.format("%.2f", tallest)})`)
end

-- The garden outside the window: a window box whose top hides behind the apron, nine black-eyed Susans turned toward the room, shrubs.
local garden = find(decor, "Garden")
local uvLayer = find(decor, "UVLayer")
local totalPetals = 0
do
	local box = find(garden, "WindowBox")
	local G = Flora.garden
	check(same(find(box, "Body").Color, "6f8796") and G.box.top <= W.bottom and G.box.z1 < piece(W.hidden).lo.Z and G.box.x0 > W.left - 4 and G.box.x1 < W.right + 4,
		"the window box is blue-grey, outside the wall, and its top is behind the apron")
	local heads, petalsOk, headsOk, stemsOk, golden = 0, true, true, true, { f2b705 = true, f6c112 = true, eaa900 = true }
	for i = 1, #G.flowers do
		local flower = find(garden, "Flower" .. i)
		if flower then
			heads += 1
			local petals = find(flower, "Petals"):GetChildren()
			totalPetals += #petals
			petalsOk = petalsOk and #petals >= 12 and #petals <= 14 and find(flower, "Petals"):GetAttribute("FullOnly") == true
			for _, petal in petals do
				local mesh = petal:FindFirstChildWhichIsA("SpecialMesh")
				petalsOk = petalsOk and mesh ~= nil and mesh.MeshType == Enum.MeshType.Sphere and petal.Shape ~= Enum.PartType.Ball and petal.Size.X > petal.Size.Z and petal.Size.Z > petal.Size.Y * 4
					and (golden[string.lower(string.format("%02x%02x%02x", math.floor(petal.Color.R * 255 + 0.5), math.floor(petal.Color.G * 255 + 0.5), math.floor(petal.Color.B * 255 + 0.5)))] == true)
			end
			local dome = find(flower, "Dome")
			headsOk = headsOk and same(dome.Color, "3b2414") and dome.Position.Y >= 4.5 and dome.Position.Y <= 8 and dome.CFrame.UpVector.Z > 0.3 -- toward the room
				and dome.Position.Z < G.box.z1 and dome.Position.X > W.left and dome.Position.X < W.right
			for _, stem in { find(flower, "StemLow"), find(flower, "StemHigh") } do
				stemsOk = stemsOk and stem.Shape == Enum.PartType.Cylinder and stem.Color.G > stem.Color.R and stem.Color.G > stem.Color.B and near(stem.Size.Y, stem.Size.Z, 1e-9)
			end
			stemsOk = stemsOk and #find(flower, "Leaves"):GetChildren() >= 2
		end
	end
	check(heads == 9 and #G.flowers == 9, "nine black-eyed Susans")
	check(petalsOk, "each has 12 to 14 golden petals, flattened ellipsoids (SpecialMesh spheres, never non-uniform Ball parts)")
	check(headsOk and stemsOk, "dark brown domes at heights 4.5 to 8, turned toward the room, on green cylinder stems with leaves")
	local shrubCores, pink, white = 0, 0, 0
	for _, bit in find(garden, "Shrubs"):GetChildren() do
		if string.match(bit.Name, "^Shrub%d+$") then shrubCores += 1 end
		if string.match(bit.Name, "Bloom") then
			local c = bit.Color
			if c.R > 0.85 and c.B > 0.6 and c.G < 0.85 then pink += 1 elseif c.R > 0.85 and c.G > 0.85 and c.B > 0.8 then white += 1 end
			check(bit.Shape == Enum.PartType.Ball and near(bit.Size.X, bit.Size.Y, 1e-9) and near(bit.Size.X, bit.Size.Z, 1e-9), "blossoms are round balls")
		end
	end
	check(shrubCores == #G.shrubs and pink > 20 and white > 20, `flowering shrubs with pink and white blossoms ({shrubCores} shrubs, {pink} pink, {white} white)`)
end
-- The ultraviolet layer: invisible Neon patches (one per petal), faded in by the eye-view helper through the UVOpacity attribute.
do
	local uvOk, uvCount = true, 0
	for _, part in uvLayer:GetChildren() do
		uvCount += 1
		uvOk = uvOk and part.Material == Mat("Neon") and same(part.Color, "b98cff") and part.Transparency == 1 and part:GetAttribute("UVOpacity") == 0.85
			and part:GetAttribute("FullOnly") == true and part.CastShadow == false
	end
	check(uvOk and uvCount == totalPetals and uvLayer.Parent == decor, `the UV layer: one invisible Neon patch b98cff per petal, with UVOpacity 0.85 ({uvCount} patches)`)
end

-- Wear: a bare-wood strip along the lip's front edge, grime in the corners, dust bunnies, condensation, smudges, silk, a coin, leaves.
local wear = find(decor, "Wear")
check(wear:GetAttribute("FullOnly") == true, "the wear on the sill is full-tier detail")
do
	local lip = piece("front_lip")
	local runs = named(wear, "LipWear")
	local lipOk = #runs >= 8
	for _, run in runs do
		local e = extent(run)
		lipOk = lipOk and near(run.Position.Y - e.Y, lip.hi.Y, 1e-9) and run.Position.X - e.X >= lip.lo.X - 1e-9 and run.Position.X + e.X <= lip.hi.X + 1e-9
			and run.Position.Z - e.Z >= lip.lo.Z and run.Position.Z + e.Z <= lip.hi.Z + 1e-9 and run.Position.Z + e.Z > lip.hi.Z - 0.05
			and run.Material == Mat("Wood") and run.Color.R > run.Color.G and run.Color.G > run.Color.B
	end
	check(lipOk, `a worn strip of bare wood runs along the lip's top front edge, in broken runs ({#runs})`)
	local grime = find(wear, "Grime"):GetChildren()
	local back, left, right, grimeOk = 0, 0, 0, true
	for _, line in grime do
		grimeOk = grimeOk and same(line.Color, "6e6252") and near(line.Transparency, 0.55, 1e-9) and line.Size.Y <= 0.01 and line.Position.Y - line.Size.Y / 2 > -1e-9 and line.Position.Y < 0.01
		if line.Position.Z < -12.1 then back += 1 end
		if line.Position.X < -29.5 then left += 1 end
		if line.Position.X > 29.5 then right += 1 end
	end
	check(grimeOk and back >= 3 and left >= 2 and right >= 2, `grime lines along the back corner and the side frames ({back} back, {left} left, {right} right)`)
	local bunnies, bunnyOk = named(wear, "DustBunny"), true
	for _, cluster in bunnies do
		local fluff = cluster:GetChildren()
		local cx, cz = 0, 0
		bunnyOk = bunnyOk and #fluff >= 6 and #fluff <= 10
		for _, ball in fluff do
			cx, cz = cx + ball.Position.X / #fluff, cz + ball.Position.Z / #fluff
			bunnyOk = bunnyOk and ball.Size.X <= 0.4 and ball.Size.Y < ball.Size.X and ball.Transparency >= 0.4 and ball.Transparency <= 0.85 and math.abs(ball.Color.R - ball.Color.B) < 0.1
				and ball.Color.R > 0.55 and ball:FindFirstChildWhichIsA("SpecialMesh") ~= nil and ball.Position.Y < 0.2
		end
		bunnyOk = bunnyOk and math.abs(cx) > 27 and math.abs(cz) > 10 -- in a corner
	end
	check(#bunnies >= 2 and #bunnies <= 3 and bunnyOk, `2 or 3 dust bunnies in the corners, each 6 to 10 tiny translucent grey spheres ({#bunnies})`)
end
do
	local W2 = Graphics.window
	local face = piece(W2.hidden).hi.Z - W2.glass.setback
	local drops = find(decor, "Condensation")
	local list, dropOk = drops:GetChildren(), true
	for _, drop in list do
		dropOk = dropOk and drop.Material == Mat("Glass") and drop.Size.X >= 0.1 - 1e-9 and drop.Size.X <= 0.4 + 1e-9 and drop.Size.Y >= 0.1 - 1e-9 and drop.Size.Y <= 0.4 + 1e-9
			and drop.Size.Z <= 0.05 and drop:FindFirstChildWhichIsA("SpecialMesh") ~= nil and drop.Transparency > 0.2
			and drop.Position.Y > W2.bottom + W2.trimWidth and drop.Position.Y < (W2.bottom + W2.top) / 2 and drop.Position.Z - drop.Size.Z / 2 >= face - 1e-9 and drop.Position.Z < face + 0.05
		for _, x in W2.mullions do dropOk = dropOk and math.abs(drop.Position.X - x) > W2.mullionWidth / 2 + drop.Size.X / 2 end
		dropOk = dropOk and drop.Position.X > W2.left + W2.trimWidth and drop.Position.X < W2.right - W2.trimWidth
	end
	check(#list >= 20 and #list <= 30 and dropOk and drops:GetAttribute("FullOnly") == true, `20 to 30 condensation droplets (Glass, 0.1 to 0.4, flat) on the lower panes, clear of the bars ({#list})`)
	local smudges = find(decor, "Smudges"):GetChildren()
	local smudgeOk = true
	for _, smudge in smudges do smudgeOk = smudgeOk and smudge.Transparency >= 0.9 and smudge.Size.Z <= 0.02 and smudge.Position.Z < face + 0.05 end
	check(#smudges == 2 and smudgeOk and find(decor, "Smudges"):GetAttribute("FullOnly") == true, "two faint smudges on the glass")
end
do
	local retreat = find(decor, "Retreat")
	local shells, threads, silkOk = named(retreat, "Shell"), named(retreat, "Thread"), true
	for _, shell in shells do
		silkOk = silkOk and shell.Transparency >= 0.75 and shell.Transparency <= 0.9 and same(shell.Color, "f4f4ee") and shell:FindFirstChildWhichIsA("SpecialMesh") ~= nil
			and shell.Position.X > Layout.RETREAT_MIN.X - 1 and shell.Position.X < Layout.RETREAT_MAX.X and shell.Position.Z > Layout.RETREAT_MIN.Z and shell.Position.Z < Layout.RETREAT_MAX.Z
	end
	for _, thread in threads do silkOk = silkOk and thread.Size.X <= 0.05 and thread.Size.Y <= 0.05 and thread.Transparency >= 0.5 end
	check(#shells >= 4 and #threads >= 4 and silkOk, `a silk retreat: overlapping translucent shells and threads across the opening ({#shells} shells, {#threads} threads)`)
	check(same(piece("crevice_back").color, "655640") and luminance(Color3.fromHex(Graphics.paint.crevice_roof.color)) < 0.25 and M.pieces.crevice_roof == "Wood", "the crevice is weathered dark wood")
end
do
	local coin = find(details, "Coin")
	local C = Wear.coin
	check(coin ~= nil and coin.Material == Mat("Metal") and same(coin.Color, "b5764f") and coin.Shape == Enum.PartType.Cylinder and near(coin.Size.Y, 1.9, 1e-9) and near(coin.Size.Z, 1.9, 1e-9)
		and near(coin.Size.X, 0.12, 1e-9) and math.abs(coin.CFrame.RightVector.Y) > 0.999 and near(coin.Position.X, C.x, 1e-9) and near(coin.Position.Z, C.z, 1e-9)
		and near(coin.Position.Y - coin.Size.X / 2, 0, 1e-9) and #coin:GetChildren() == 0 and math.abs(C.x - 25.5) <= 1 and math.abs(C.z - 9.5) <= 1,
		"a copper coin 1.9 across and 0.12 thick lies flat near (25.5, 9.5), plain faces")
	local leaves, leafOk = named(details, "FallenLeaf"), true
	for _, leaf in leaves do
		leafOk = leafOk and leaf.Shape == Enum.PartType.Cylinder and leaf.Size.Y >= 1.2 and leaf.Size.Y <= 2.0 and leaf.Size.X <= 0.05 and (same(leaf.Color, "a07a45") or same(leaf.Color, "c49a5b"))
			and math.abs(leaf.CFrame.RightVector.Y) > 0.999
	end
	check(#leaves >= 2 and #leaves <= 3 and leafOk and #named(details, "Crumb") == #Graphics.details.crumbs, `{#leaves} fallen brown Pilea discs 1.2 to 2 across, and the crumbs stay`)
	local lipOk = true
	for _, run in named(wear, "LipWear") do lipOk = lipOk and run.Material == Mat("Wood") end
	local chipsOk = #named(details, "PaintChip") == #Graphics.details.chips
	for _, chip in named(details, "PaintChip") do chipsOk = chipsOk and chip.Material == Mat("Wood") and chip.Color.R > chip.Color.B end
	check(lipOk and chipsOk, "where the paint has chipped the bare wood shows")
end

-- Shafts follow the sun and stay faint; none without a sun behind the window.
local shafts = decor:FindFirstChild("Shafts")
local beams, faint, aligned = 0, true, true
for _, anchor in shafts:GetChildren() do
	for _, b in anchor:GetChildren() do
		if b.ClassName == "Beam" then
			beams += 1
			faint = faint and b.Transparency.Keypoints[1].Value >= 0.95 and b.Width1 >= b.Width0
			local from = anchor.CFrame.Position
			local to = from + anchor.CFrame:VectorToWorldSpace(b.Attachment1.Position)
			aligned = aligned and ((to - from).Unit + sun).Magnitude < 1e-6 and near(to.Y, 0.05, 1e-6)
		end
	end
end
check(beams == #Graphics.shafts.x * #Graphics.shafts.layers and faint and aligned, `light shafts: {beams} faint ribbons run from the glass to the floor along the sun (faint {faint}, aligned {aligned})`)
check(Scenery.shafts(Instance.new("Folder"), Vector3.new(0, 0.5, 0.8).Unit) == nil and Scenery.shafts(Instance.new("Folder"), Vector3.new(0, 0.05, -1).Unit) == nil, "no shafts without a sun behind the window")
check(Scenery.decor(nil):FindFirstChild("Shafts") == nil, "no sun, no shafts")
local motes = decor:FindFirstChild("DustVolume"):FindFirstChild("Motes")
check(motes ~= nil and motes.Rate == Graphics.dust.rate and motes:GetAttribute("Dust") == true, "dust motes drift in the room")

-- ---------------------------------------------------------------- the lighting
local lighting = Instance.new("Folder")
local terrain = Instance.new("Folder")
local result = Lit.apply(lighting :: any, terrain, { sample = astronomical(1) })
check(result.ok and lighting.ClockTime == result.clock and lighting.GeographicLatitude == result.latitude, "the lighting takes the picked time of day")
check(string.sub(lighting:GetAttribute("SunPick") :: string, 1, 3) == "ok:", "the pick is recorded on the lighting")
for _, name in { "Atmosphere", "Sky", "Grade", "Bloom", "SunRays" } do check(lighting:FindFirstChild(name) ~= nil, "lighting has " .. name) end
check(terrain:FindFirstChild("Clouds") ~= nil, "clouds are on the terrain")
check(lighting:FindFirstChild("MacroDOF") == nil, "no depth of field by default")
local before = #lighting:GetChildren()
Lit.apply(lighting :: any, terrain, { sample = astronomical(1) })
check(#lighting:GetChildren() == before and #terrain:GetChildren() == 1, "setting up twice adds nothing")
local dofLighting = Instance.new("Folder")
Lit.apply(dofLighting :: any, nil, { sample = astronomical(1), depthOfField = true })
local dof = dofLighting:FindFirstChild("MacroDOF")
check(dof ~= nil and dof.FocusDistance == Graphics.depthOfField.focus, "depth of field only when asked for")
check(dof.FarIntensity == 0.3 and dof.NearIntensity == 0 and dof.InFocusRadius == 18 and dof:GetAttribute("FullOnly") == true, "the macro depth of field: far blur 0.3, no near blur, sharp within 18, full tier only")
Lit.apply(dofLighting :: any, nil, { sample = astronomical(1) })
check(dofLighting:FindFirstChild("MacroDOF") == nil, "and gone again when not asked")
local broken = Instance.new("Folder")
local fallback = Lit.apply(broken :: any, nil, { sample = function(_c, _l): Vector3 error("no sun") end })
check(not fallback.ok and broken.ClockTime == Graphics.lighting.clockTime and string.sub(broken:GetAttribute("SunPick") :: string, 1, 9) == "fallback:", "if the sun cannot be asked, the old morning light stays")
check(lighting.Brightness == Graphics.lighting.brightness and lighting.ShadowSoftness == Graphics.lighting.shadowSoftness, "the lighting values come from the table")

-- ---------------------------------------------------------------- the low tier, on a client
local function census(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	return n
end
local roots: { Instance } = { lighting, decor, terrain }
local fullParts = census(decor)
local fullUv = #uvLayer:GetChildren()
local rate = motes.Rate
check(WorldDetail.apply("full", roots) == 0 and census(decor) == fullParts and motes.Rate == rate, "the full tier removes nothing")
local removed = WorldDetail.apply("low", roots)
local lowParts = census(decor)
check(removed >= 8 and lowParts < fullParts * 0.6 and lowParts >= 30, `the low tier drops the optional parts (decor {fullParts} -> {lowParts} parts, {removed} things removed)`)
check(fullParts < 1500 and lowParts < 450, `part budgets: full {fullParts} < 1500, low {lowParts} < 450`)
-- What replaces a piece's look exists in both tiers; the optional detail goes.
check(find(decor, "Pilea", "leaf_west", "BladeA") ~= nil and find(decor, "Pilea", "leaf_east", "Petiole") ~= nil and find(decor, "Pilea", "leaf_tip", "BladeA") ~= nil
	and find(decor, "Pilea", "leaf_west", "Detail") == nil and find(decor, "Pilea", "leaf_west", "Base") == nil and find(decor, "Pilea", "leaf_tip", "Detail") == nil,
	"the drawn Pilea (blades, petioles, the dry leaf) stays in the low tier; veins, rims, undersides and cracks go")
check(find(decor, "Wear") == nil and find(decor, "Condensation") == nil and find(decor, "Smudges") == nil and find(decor, "Planter", "Pebbles") == nil and find(decor, "Planter", "Stain") == nil
	and find(decor, "Garden", "WindowBox") ~= nil and find(decor, "Garden", "Flower1", "Dome") ~= nil and find(decor, "Garden", "Flower1", "Petals") == nil
	and find(decor, "Garden", "Shrubs", "Shrub1") ~= nil and find(decor, "Retreat") ~= nil, "wear, condensation and the finer planting go; the window box, flower heads, shrubs and the silk stay")
check(fullUv > 0 and #uvLayer:GetChildren() == 0 and uvLayer.Parent == decor, "the UV patches go with the petals they sit on; the layer's folder stays")
local dofRoot = Instance.new("Folder")
Lit.apply(dofRoot :: any, nil, { sample = astronomical(1), depthOfField = true })
check(dofRoot:FindFirstChild("MacroDOF") ~= nil and WorldDetail.apply("low", { dofRoot }) >= 1 and dofRoot:FindFirstChild("MacroDOF") == nil, "no macro depth of field in the low tier")
check(lighting:FindFirstChild("Bloom") == nil and lighting:FindFirstChild("SunRays") == nil and terrain:FindFirstChild("Clouds") == nil, "no bloom, sun rays or clouds in the low tier")
check(lighting:FindFirstChild("Atmosphere") ~= nil and lighting:FindFirstChild("Sky") ~= nil and lighting:FindFirstChild("Grade") ~= nil, "the sky, haze and grade stay")
check(decor:FindFirstChild("Details") == nil and decor:FindFirstChild("Shafts") == nil and decor:FindFirstChild("Wall") ~= nil and decor:FindFirstChild("View"):FindFirstChild("Ground") ~= nil, "the wall, glass and a simple view stay")
check(near(motes.Rate, rate * Graphics.tiers.low.dustRate, 1e-9), "the dust is thinner")
WorldDetail.apply("low", roots)
check(near(motes.Rate, rate * Graphics.tiers.low.dustRate, 1e-9), "applying the low tier twice does not thin the dust again")
print(`world: decor {fullParts} parts at full detail, {lowParts} at low (view {viewCount} items at full), dust {rate} -> {string.format("%.1f", motes.Rate)} per second`)

local Breakaway=require("../src/Shared/Habitat/Breakaway")
local b=Breakaway.new(sill,decor)
local blade=find(decor,"Pilea","leaf_tip","BladeA")
local home=blade.Position
local tip=sill:FindFirstChild("leaf_tip")
local hit={kind="launched",plan={point=Vector3.new(27,5.35,-3)}}
b:step(1/60,hit,Vector3.zero,false);b:step(.35,hit,Vector3.zero,false)
check(blade.Position.Y<home.Y-1 and not tip.CanQuery and tip.Transparency==1,"drawn tip falls; hidden collider stays hidden and unavailable")
b:apply(nil)
check((blade.Position-home).Magnitude<1e-6 and tip.CanQuery and tip.Transparency==1,"drawn tip returns without showing collision box")
local grass=decor:FindFirstChild("GrassTufts")
check(grass~=nil and #grass:GetChildren()==34,"Chet's 14 grass patches and the 20 added tufts survive low detail")
local safe=true;local count=0
for _,p in grass:GetDescendants() do if p:IsA("BasePart") then count+=1;safe=safe and not p.CanQuery and not p.CanCollide and not p.CanTouch end end
check(safe and count==82,`low grass is bounded (14 x 3 + 20 x 2 = 82 blades, {count}) and cannot block any gameplay query`)
local coverParams=RaycastParams.new();coverParams.FilterType=Enum.RaycastFilterType.Include;coverParams.FilterDescendantsInstances={sill}
for _,id in {"cover_bark_west","cover_bark_east","cover_leaf_front","cover_rim"} do
 local p=sill:FindFirstChild(id)
 check(p~=nil and p.CanQuery~=false and p.CanCollide~=false and p.Transparency<1,"stalking cover stays visible and solid: "..id)
end

-- ---------------------------------------------------------------- ROBLOX-74: more grass and detail, and the morning dew
-- Pure visual density. The nav graph of the rival and the player's walkable surfaces come from Layout.PIECES alone, so what is pinned here is that
-- those boxes are byte for byte the ones they were, and that none of the new parts can be walked on, hit by a ray or touched.
do
	local sum = 0
	for i, p in Layout.PIECES do
		sum += i * (p.lo.X + 2 * p.lo.Y + 3 * p.lo.Z + 5 * p.hi.X + 7 * p.hi.Y + 11 * p.hi.Z)
	end
	check(#Layout.PIECES == 28 and near(sum, 25445.9, 1e-6) and Layout.CONTENT_REVISION == "windowsill-v1" and #Layout.DECOR == 11, `Layout.PIECES is the 28 boxes it was (checksum {sum})`)

	local sunFull = Vector3.new(0.35, 0.5, -0.8).Unit
	local fresh = Scenery.decor(sunFull)
	local again = Scenery.decor(sunFull)
	local function newParts(root: any): { any } -- everything ROBLOX-74 added: the four folders and the added tufts' blades
		local out = {}
		for _, name in { "Moss", "Litter", "Windfall", "Dew" } do
			for _, d in find(root, name):GetDescendants() do if d:IsA("BasePart") then table.insert(out, d) end end
		end
		for _, t in find(root, "GrassTufts"):GetChildren() do
			if tonumber(string.sub(t.Name, 5)) > #Flora.grass.patches then
				for _, d in t:GetDescendants() do if d:IsA("BasePart") then table.insert(out, d) end end
			end
		end
		return out
	end
	local function census(root: any): number
		local n = 0
		for _, d in root:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
		return n
	end
	local added = newParts(fresh)
	local solid = 0
	for _, p in added do
		if p.CanCollide ~= false or p.CanQuery ~= false or p.CanTouch ~= false or not p.Anchored then solid += 1 end
	end
	check(#added > 0 and solid == 0, `none of the {#added} new parts can collide, be queried or be touched`)

	-- Part budgets: the full tier adds at most about 250 parts, the low tier fewer than half of them.
	local fullAdded = #added
	local fullTotal = census(fresh)
	local grassFull = 0
	for _, t in find(fresh, "GrassTufts"):GetChildren() do
		if tonumber(string.sub(t.Name, 5)) > #Flora.grass.patches then for _, d in t:GetDescendants() do if d:IsA("BasePart") then grassFull += 1 end end end
	end
	local counts = { Moss = census(find(fresh, "Moss")), Litter = census(find(fresh, "Litter")), Windfall = census(find(fresh, "Windfall")), Dew = census(find(fresh, "Dew")) }
	check(fullAdded == grassFull + counts.Moss + counts.Litter + counts.Windfall + counts.Dew and fullAdded <= 250 and fullAdded >= 150,
		`the full tier adds {fullAdded} parts (grass {grassFull}, moss {counts.Moss}, pebbles and bark {counts.Litter}, fallen leaves {counts.Windfall}, dew {counts.Dew}), at most 250`)
	check(grassFull == 80 and counts.Moss == 28 and counts.Litter == 22 and counts.Windfall == 6 and counts.Dew == 56,
		"the counts per kind: 80 blades in 20 tufts, 28 moss mounds, 14 pebbles and 8 bark chips, 6 leaf parts, 56 drops")

	local fullGrass = 0
	for _, d in find(fresh, "GrassTufts"):GetDescendants() do if d:IsA("BasePart") then fullGrass += 1 end end
	check(fullGrass == 150 and #find(fresh, "GrassTufts"):GetChildren() == 34, "the grass is 150 blades in 34 tufts at full detail (it was 70 in 14)")

	WorldDetail.apply("low", { fresh })
	local lowAdded = #newParts(fresh)
	local lowTotal = census(fresh)
	check(lowAdded < fullAdded * 0.55 and lowAdded >= 60 and lowTotal < 450,
		`the low tier keeps {lowAdded} of the {fullAdded} added parts (decor {lowTotal} parts, under 450)`)
	local lowCounts = { Moss = census(find(fresh, "Moss")), Litter = census(find(fresh, "Litter")), Windfall = census(find(fresh, "Windfall")), Dew = census(find(fresh, "Dew")) }
	check(lowCounts.Moss == 12 and lowCounts.Litter == 10 and lowCounts.Windfall == 4 and lowCounts.Dew == 19, `low: 12 moss, 6 pebbles and 4 bark chips, 4 leaf parts, 19 drops ({lowCounts.Moss}, {lowCounts.Litter}, {lowCounts.Windfall}, {lowCounts.Dew})`)

	-- Rays and navigation: a grid of rays through the whole sill hits exactly the same physical piece at exactly the same point with the new decor
	-- in the world as with no decor at all.
	do
		local function shoot(withDecor: boolean): { string }
			workspace:ClearAllChildren()
			Scenery.sill().Parent = workspace
			if withDecor then Scenery.decor(sunFull).Parent = workspace end
			local out = {}
			for x = -29, 29, 1.5 do
				for z = -11.5, 11.5, 1.5 do
					local hit = workspace:Raycast(Vector3.new(x, 20, z), Vector3.new(0, -25, 0), RaycastParams.new())
					table.insert(out, if hit then `{hit.Instance.Name}@{string.format("%.5f,%.5f,%.5f", hit.Position.X, hit.Position.Y, hit.Position.Z)}` else "none")
				end
			end
			return out
		end
		local bare, dressed = shoot(false), shoot(true)
		local same = #bare == #dressed
		for i = 1, #bare do
			same = same and bare[i] == dressed[i]
		end
		check(same and #bare > 500, `{#bare} rays down through the sill hit the same piece at the same point with and without the decor`)
		workspace:ClearAllChildren()
	end

	-- Seeded placement: the same sill every time, a different one for another seed, and a pinned fingerprint.
	local function fingerprint(root: any): number
		local total = 0
		for _, p in newParts(root) do total += p.Position.X + 2 * p.Position.Y + 3 * p.Position.Z end
		return total
	end
	local full2 = Scenery.decor(sunFull)
	local a, b = fingerprint(full2), fingerprint(again)
	check(a == b and near(a, -129.1926, 1e-3), `every build places the same sill (fingerprint {string.format("%.4f", a)})`)
	local firstPebble = find(full2, "Litter", "Pebbles", "Pebble1")
	local seed = Flora.worldSeed
	Flora.worldSeed = seed + 1
	local other = Scenery.decor(sunFull)
	Flora.worldSeed = seed
	local movedPebble = find(other, "Litter", "Pebbles", "Pebble1")
	check(firstPebble ~= nil and movedPebble ~= nil and (firstPebble.Position - movedPebble.Position).Magnitude > 0.01 and fingerprint(other) ~= a, "another world seed scatters it differently")
	local back = Scenery.decor(sunFull)
	check(fingerprint(back) == a, "and the seed restored gives the sill back")
end

-- The grass: Chet's tufts are as they were; the added ones vary in height and hue and stand clear of the pieces, the spawn and the retreat.
do
	local blades = Plants.grassBlades()
	local old, new = {}, {}
	for _, b in blades do table.insert(if b.tuft <= #Flora.grass.patches then old else new, b) end
	local heights, hues, dry = {}, {}, 0
	for _, b in new do
		table.insert(heights, b.size.Y)
		hues[string.format("%.2f,%.2f,%.2f", b.color.R, b.color.G, b.color.B)] = true
		if b.color.R > b.color.G * 0.95 then dry += 1 end
	end
	table.sort(heights)
	local hueCount = 0
	for _ in hues do hueCount += 1 end
	check(#old == 70 and #new == 80 and heights[1] >= Flora.grass.more.height[1] - 1e-9 and heights[#heights] <= Flora.grass.more.height[2] + 1e-9 and heights[#heights] > 2 * heights[1],
		`the added tufts' blades are {string.format("%.2f", heights[1])} to {string.format("%.2f", heights[#heights])} tall, more than twofold`)
	check(hueCount >= 40 and dry >= 3, `the added blades have {hueCount} different colours, {dry} of them dry`)
	local first = blades[1]
	check(near(first.size.Y, 0.25 + (7 + 3) % 9 * 0.035, 1e-12) and near(first.size.X, 0.065, 1e-12) and near(old[#old].foot.X, 18, 1e-12), "Chet's blades are built as they were")
	local clearOk, tufts = true, {}
	for _, b in new do
		clearOk = clearOk and Shapes.clearAt(b.foot.X, b.foot.Y, b.foot.Z, 0.3) and near(b.tip.Y - b.foot.Y, b.size.Y * math.cos(math.acos(b.direction.Y)), 1e-9)
		tufts[b.tuft] = b.foot
	end
	local nTufts = 0
	for _ in tufts do nTufts += 1 end
	check(clearOk and nTufts == 20, `all 20 added tufts stand clear of every piece, the spawn and the retreat ({nTufts})`)
end

-- Moss, pebbles and bark, the fallen leaves: where they lie.
do
	local d = Scenery.decor(Vector3.new(0.35, 0.5, -0.8).Unit)
	local mossOk, mossN, lowest = true, 0, math.huge
	for _, bit in find(d, "Moss"):GetDescendants() do
		if bit:IsA("BasePart") then
			mossN += 1
			local c = bit.Position
			local onTrough = c.Z > 0 and c.Z < 0.4 and c.X > 3.4 and c.X < 16.6 and c.Y > 0
			local onWall = c.Z > -12.5 and c.Z < -12.1 and c.Y > 0
			mossOk = mossOk and (onTrough or onWall) and bit.Color.G > bit.Color.R and bit.Size.Y < bit.Size.X and c.Y - extent(bit).Y > -0.01
		end
	end
	check(mossOk and mossN == 28, `moss lies on the shaded faces only: the trough's room side and the back wall's foot, green and above the floor ({mossN} mounds)`)
	local litterOk, litterTop, pebbles, chips = true, 0, 0, 0
	for _, bit in find(d, "Litter"):GetDescendants() do
		if bit:IsA("BasePart") then
			local c = bit.Position
			if string.sub(bit.Name, 1, 6) == "Pebble" then pebbles += 1 elseif string.sub(bit.Name, 1, 4) == "Chip" then chips += 1 end
			litterOk = litterOk and Shapes.clearAt(c.X, 0.02, c.Z, 0.3) and c.Y - extent(bit).Y > -0.05 and c.Y > 0 -- a pebble sits a fifth into the floor
			litterTop = math.max(litterTop, c.Y + extent(bit).Y)
		end
	end
	check(litterOk and pebbles == 14 and chips == 8 and litterTop <= 0.35, `14 pebbles and 8 bark chips lie on the floor clear of pieces, spawn and retreat, none over 3.5 mm high ({string.format("%.2f", litterTop)})`)
	local leafOk = true
	for i, leaf in Flora.windfall.items do
		local blade = find(d, "Windfall", "Leaf" .. i, "Blade")
		local e = extent(blade)
		leafOk = leafOk and Shapes.clearAt(leaf.x, 0.02, leaf.z, 1.2) and near(blade.Position.Y - e.Y, 0, 0.012) and find(d, "Windfall", "Leaf" .. i, "Stalk") ~= nil
			and find(d, "Windfall", "Leaf" .. i, "Detail"):GetAttribute("FullOnly") == true
	end
	check(#Flora.windfall.items == 2 and leafOk, "two fallen leaves lie on the floor, a lower edge touching it, each with a stalk and a full-tier midrib")
end

-- The dew follows the clock: it gathers through the night, is there at 06:00, burns off between 07:30 and 09:30 and is gone by 10:00.
do
	local decorDew = Scenery.decor(Vector3.new(0.35, 0.5, -0.8).Unit)
	local dew = find(decorDew, "Dew")
	local drops = {}
	for _, p in dew:GetDescendants() do if p:IsA("BasePart") then table.insert(drops, p) end end
	local function visible(): number
		local n = 0
		for _, p in drops do if p.Transparency < 1 then n += 1 end end
		return n
	end
	local function allAt(t: (number) -> boolean): boolean
		for _, p in drops do if not t(p.Transparency) then return false end end
		return true
	end
	check(#drops == 56 and visible() == 0, "the dew is built unseen: 56 drops, all transparent until the clock says")
	check(DayLight.dewAt(6.0) == 1 and DayLight.dewAt(7.5) == 1 and DayLight.dewAt(10.0) == 0 and DayLight.dewAt(9.5) == 0 and DayLight.dewAt(14.0) == 0 and DayLight.dewAt(20.0) == 0
		and DayLight.dewAt(5.0) == 1 and DayLight.dewAt(0 / 0) == 0, "the dew is full from 05:00 to 07:30, gone from 09:30 to 20:00")
	local rising, burning, last = true, true, -1
	for h = 20, 29, 0.25 do
		local level = DayLight.dewAt(h % 24)
		rising = rising and level >= last
		last = level
	end
	last = 2
	for h = 7.5, 9.5, 0.05 do
		local level = DayLight.dewAt(h)
		burning = burning and level <= last
		last = level
	end
	check(rising and burning and DayLight.dewAt(0.0) > 0.2 and DayLight.dewAt(0.0) < 0.9 and DayLight.dewAt(8.5) > 0.2 and DayLight.dewAt(8.5) < 0.8,
		"it gathers steadily through the night from 20:00 and fades steadily from 07:30 to 09:30")
	check(DayLight.applyDew(decorDew, 6.0) and visible() == 56 and allAt(function(t) return t >= 0.28 - 1e-9 and t <= 0.45 + 1e-9 end),
		"at 06:00 all 56 drops show, translucent (0.28 to 0.45)")
	check(not DayLight.applyDew(decorDew, 6.0) and not DayLight.applyDew(decorDew, 6.05) and not DayLight.applyDew(nil, 6.0) and not DayLight.applyDew(Instance.new("Folder"), 6.0),
		"nothing is set again for the same dew, or when there is no dew")
	check(not DayLight.applyDew(decorDew, 7.5) and visible() == 56, "at 07:30 they are all still there (the level has not moved)")
	DayLight.applyDew(decorDew, 8.5)
	local mid = visible()
	check(mid > 0 and mid < 56, `at 08:30 some have gone, some remain ({mid} of 56)`)
	DayLight.applyDew(decorDew, 9.4)
	local late = visible()
	check(late < mid, `fewer at 09:24 still ({late})`)
	check(DayLight.applyDew(decorDew, 10.0) and visible() == 0 and allAt(function(t) return t == 1 end), "by 10:00 every drop is fully transparent")
	DayLight.applyDew(decorDew, 20.0)
	check(visible() == 0, "at 20:00 there is none yet")
	DayLight.applyDew(decorDew, 21.0)
	check(visible() < 10, `at 21:00 the first few are forming ({visible()})`)
	DayLight.applyDew(decorDew, 2.0)
	local night = visible()
	check(night > 0, `at 02:00 the dew has gathered ({night} drops)`)
	local before = visible()
	check(DayLight.applyDew(decorDew, 2.0) == false and visible() == before, "the same hour sets nothing again")

	-- Where the drops stand: on a grass tip, around a Pilea leaf's rim or on a fallen leaf.
	local blades = Plants.grassBlades()
	local onTips, onLeaves, onFallen = 0, 0, 0
	local standOk = true
	for _, p in find(dew, "Grass"):GetChildren() do
		local nearest = math.huge
		for _, b in blades do nearest = math.min(nearest, (b.tip - p.Position).Magnitude) end
		standOk = standOk and nearest < 0.2
		onTips += 1
	end
	for i, plant in Flora.pilea.plants do
		local leaf = piece(plant.leaf)
		for k = 1, Flora.dew.pilea.perLeaf do
			local p = find(dew, "Leaves", `Drop{i}_{k}`)
			if p then
				onLeaves += 1
				standOk = standOk and p.Position.X > leaf.lo.X and p.Position.X < leaf.hi.X and p.Position.Z > leaf.lo.Z and p.Position.Z < leaf.hi.Z
					and near(p.Position.Y, leaf.hi.Y, 0.1) and p.Material == Mat("Glass")
			end
		end
	end
	for _ in find(dew, "Windfall"):GetChildren() do onFallen += 1 end
	check(standOk and onTips == 25 and onLeaves == 25 and onFallen == 6, `drops: {onTips} on grass tips, {onLeaves} on the Pilea's leaves, {onFallen} on the fallen leaves`)

	-- On a phone: the grass and leaf drops that stand on something the low tier keeps stay, the rest go; those that stay still follow the clock.
	WorldDetail.apply("low", { decorDew })
	local keptDrops = {}
	for _, p in find(decorDew, "Dew"):GetDescendants() do if p:IsA("BasePart") then table.insert(keptDrops, p) end end
	local lowBlades = {}
	for _, d in find(decorDew, "GrassTufts"):GetDescendants() do if d:IsA("BasePart") then table.insert(lowBlades, d) end end
	local supported = true
	for _, p in find(decorDew, "Dew", "Grass"):GetChildren() do
		local nearest = math.huge
		for _, blade in lowBlades do nearest = math.min(nearest, (blade.CFrame * Vector3.new(0, blade.Size.Y / 2, 0) - p.Position).Magnitude) end
		supported = supported and nearest < 0.2
	end
	check(#keptDrops == 19 and supported and find(decorDew, "Dew", "Windfall") == nil, `on a phone {#keptDrops} drops stay, each on a blade or leaf that stays, and none on the fallen leaves`)
	DayLight.applyDew(decorDew, 6.0)
	local shown = 0
	for _, p in keptDrops do if p.Transparency < 1 then shown += 1 end end
	DayLight.applyDew(decorDew, 10.0)
	local hidden = 0
	for _, p in keptDrops do if p.Transparency == 1 then hidden += 1 end end
	check(shown == 19 and hidden == 19, "and they come with 06:00 and go by 10:00")
end

print(`WORLD passed={passed} failed={failed}`)
if failed > 0 then error("world checks failed") end
