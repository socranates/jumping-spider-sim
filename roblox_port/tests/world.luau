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

-- ---------------------------------------------------------------- the graphics table
local unknown = {}
local function mat(name: string) if not Materials.known(name) then table.insert(unknown, name) end end
for _, name in M.pieces do mat(name) end
for _, key in { "soil", "wall", "trim", "glass", "view", "ground", "chip", "crack", "crumb", "fallback" } do mat(M[key]) end
check(#unknown == 0, "every material name in the graphics table is one Materials knows (unknown: " .. table.concat(unknown, ", ") .. ")")
local unmapped = {}
for _, p in Layout.PIECES do if not M.pieces[p.id] then table.insert(unmapped, p.id) end end
check(#unmapped == 0, "every sill piece has a material (" .. table.concat(unmapped, ", ") .. ")")
check(M.pieces.sill_floor == "WoodPlanks" and M.pieces.planter == "Brick" and M.wall == "Plaster" and M.glass == "Glass" and M.soil == "Ground"
	and M.pieces.leaf_west == "LeafyGrass", "wood planks sill, brick planter, plaster wall, glass window, ground soil, leafy leaves")
check(rgb(Color3.fromHex(W.wallColor)) == rgb(piece("back_frame").color), "the drawn wall keeps the old wall colour")
local mullion
for _, d in Layout.DECOR do if d.id == "mullion_w" then mullion = d end end
check(rgb(Color3.fromHex(W.trimColor)) == rgb(mullion.color) and rgb(Color3.fromHex(W.glass.color)) == rgb(Color3.fromHex("a9c2c1")), "trim and glass keep their old colours")
check(Graphics.bloom.threshold >= 1.2 and Graphics.bloom.intensity <= 0.5 and Graphics.sunRays.intensity <= 0.1
	and math.abs(Graphics.grade.contrast) <= 0.15 and math.abs(Graphics.grade.saturation) <= 0.15, "bloom, sun rays and grade are gentle")
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
	sillOk = sillOk and p ~= nil and (p.Size - (spec.hi - spec.lo)).Magnitude < 1e-9 and (p.Position - (spec.lo + spec.hi) * 0.5).Magnitude < 1e-9
		and p.Anchored and p.CanQuery ~= false and p.CanCollide ~= false
		and p:GetAttribute("SurfaceId") == spec.id and p:GetAttribute("ProfileId") == spec.profile and rgb(p.Color) == rgb(spec.color)
end
check(sillOk and #sill:GetChildren() == #Layout.PIECES, "the sill's pieces keep their geometry, colour, profile, solidity and queryability")
check(listed.back_frame.Transparency == 1 and listed.back_frame.CastShadow == false and listed.sill_floor.Transparency == 0, "only the back wall turns invisible (still solid)")

-- ---------------------------------------------------------------- the decor
local sun = Vector3.new(0.35, 0.5, -0.8).Unit
local decor = Scenery.decor(sun)
local parts, bad = {}, 0
for _, d in decor:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		if d.CanQuery ~= false or d.CanCollide ~= false or d.CanTouch ~= false or not d.Anchored then bad += 1 end
	end
end
check(bad == 0, "every decor part is anchored, non-colliding, not touchable and invisible to rays")
check(#parts >= 70 and #parts <= 140, `decor part count is modest ({#parts})`)
for _, name in { "Wall", "View", "Details", "Shafts", "DustVolume", "soil", "silk_0", "silk_6" } do
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
local details = decor:FindFirstChild("Details")
local clear, lowest, count = true, 0, 0
local SPAWN = Layout.SPAWN
for _, p in details:GetChildren() do
	count += 1
	local c, h = p.Position, p.Size
	lowest = math.max(lowest, c.Y + h.Y / 2)
	local nearSpawn = (Vector3.new(c.X, 0, c.Z) - Vector3.new(SPAWN.X, 0, SPAWN.Z)).Magnitude < 4
	local inRetreat = c.X > Layout.RETREAT_MIN.X - 1.5 and c.X < Layout.RETREAT_MAX.X + 1.5 and c.Z > Layout.RETREAT_MIN.Z - 1.5 and c.Z < Layout.RETREAT_MAX.Z + 1.5
	clear = clear and not nearSpawn and not inRetreat and math.abs(c.X) < 30 and c.Z > -12.5 and c.Z < 12.5
end
check(clear and count >= 18, `paint chips, cracks and crumbs sit on the sill, clear of the spawn and the silk lines ({count})`)
check(lowest <= 0.25, "details are low enough not to hide the landing patch")

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
local rate = motes.Rate
check(WorldDetail.apply("full", roots) == 0 and census(decor) == fullParts and motes.Rate == rate, "the full tier removes nothing")
local removed = WorldDetail.apply("low", roots)
local lowParts = census(decor)
check(removed >= 8 and lowParts < fullParts * 0.6 and lowParts >= 30, `the low tier drops the optional parts (decor {fullParts} -> {lowParts} parts, {removed} things removed)`)
check(lighting:FindFirstChild("Bloom") == nil and lighting:FindFirstChild("SunRays") == nil and terrain:FindFirstChild("Clouds") == nil, "no bloom, sun rays or clouds in the low tier")
check(lighting:FindFirstChild("Atmosphere") ~= nil and lighting:FindFirstChild("Sky") ~= nil and lighting:FindFirstChild("Grade") ~= nil, "the sky, haze and grade stay")
check(decor:FindFirstChild("Details") == nil and decor:FindFirstChild("Shafts") == nil and decor:FindFirstChild("Wall") ~= nil and decor:FindFirstChild("View"):FindFirstChild("Ground") ~= nil, "the wall, glass and a simple view stay")
check(near(motes.Rate, rate * Graphics.tiers.low.dustRate, 1e-9), "the dust is thinner")
WorldDetail.apply("low", roots)
check(near(motes.Rate, rate * Graphics.tiers.low.dustRate, 1e-9), "applying the low tier twice does not thin the dust again")
print(`world: decor {fullParts} parts at full detail, {lowParts} at low (view {viewCount} items at full), dust {rate} -> {string.format("%.1f", motes.Rate)} per second`)

print(`WORLD passed={passed} failed={failed}`)
if failed > 0 then error("world checks failed") end
