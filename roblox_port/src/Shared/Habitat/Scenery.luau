--!strict
-- Builds the drawn world from Data/Graphics: the sill's physical pieces (looks only), and a "Decor" folder with the window wall,
-- glass and trim, the view out of the window, the dust, the small details, the light shafts, and (Habitat/Plants, Habitat/Patina,
-- from Data/Flora and Data/Wear) the Pilea, the planting, the garden outside the window, the wear on the sill and the glass and
-- the silk retreat, and (Habitat/Dressing, ROBLOX-74) the shaded moss, the floor's pebbles and bark, the fallen leaves and the morning dew.
-- Gameplay never reads any of the decor: every decor part is CanQuery = false, CanCollide = false, CanTouch =
-- false, so the spider's rays, the camera's casts and the jump planner see only the physical pieces. Parts and emitters that
-- only the full tier keeps carry the attribute FullOnly, which Client/WorldDetail removes on phones and tablets. A piece whose
-- look is replaced by a drawing (the back wall, the Pilea's leaves and stems) turns invisible only once that drawing exists.
local Graphics = require(script.Parent.Parent.Data.Graphics)
local Flora = require(script.Parent.Parent.Data.Flora)
local Surfaces = require(script.Parent.Parent.Data.Surfaces)
local Layout = require(script.Parent.WindowsillLayout)
local Materials = require(script.Parent.Materials)
local Dressing = require(script.Parent.Dressing)
local Patina = require(script.Parent.Patina)
local Plants = require(script.Parent.Plants)
local Shapes = require(script.Parent.Shapes)

local Scenery = {}

local W = Graphics.window
local M = Graphics.materials

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A drawn-only part: anchored, nothing collides with it, no ray sees it.
local function drawn(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Materials.get(material)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function piece(id: string): Layout.Piece
	for _, p in Layout.PIECES do
		if p.id == id then return p end
	end
	error("no piece " .. id)
end

-- ---------------------------------------------------------------- the physical sill
-- The set of piece ids that drawn decor stands in for: the back wall and the Pilea (Scenery.decor returns the ones it built).
local function replaceable(): { [string]: boolean }
	local all: { [string]: boolean } = { [W.hidden] = true }
	for _, id in Plants.pieceIds() do all[id] = true end
	return all
end

-- `replaced`: the ids of the pieces whose drawn version exists (Scenery.decor's second result); those turn invisible but stay solid
-- and climbable. A piece whose drawing could not be built stays visible instead of leaving a hole. nil means all the pieces that
-- the decor can replace (the wall and the Pilea's leaves and stems).
function Scenery.sill(replaced: { [string]: boolean }?): Folder
	local hide = replaced or replaceable()
	local sill = Instance.new("Folder")
	sill.Name = "Windowsill"
	sill:SetAttribute("ContentRevision", Layout.CONTENT_REVISION)
	for _, spec in Layout.PIECES do
		assert(Surfaces[spec.profile], "unknown surface profile " .. spec.profile)
		local p = Instance.new("Part")
		p.Name = spec.id
		p.Anchored = true
		p.Size = spec.hi - spec.lo
		p.Position = (spec.lo + spec.hi) * 0.5
		local paint = Graphics.paint[spec.id]
		p.Color = if paint then hex(paint.color) else spec.color
		if paint and paint.reflectance then p.Reflectance = paint.reflectance end
		p.Material = Materials.get(M.pieces[spec.id] or M.fallback)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("SurfaceId", spec.id)
		p:SetAttribute("ProfileId", spec.profile)
		if hide[spec.id] then
			-- still solid and climbable; the decor draws it in its place (the wall with a see-through opening, the leaves and stems)
			p.Transparency = 1
			p.CastShadow = false
		end
		p.Parent = sill
	end
	return sill
end

-- ---------------------------------------------------------------- the window wall
function Scenery.window(parent: Instance): Folder
	local wall = folder(parent, "Wall")
	local back = piece(W.hidden)
	local plane = back.hi.Z -- the climbable face
	local slabFront = plane - W.slabGap
	local zMid = (slabFront + back.lo.Z) / 2
	local depth = slabFront - back.lo.Z
	local plaster, wood = hex(W.wallColor), hex(W.trimColor)
	local function slab(name: string, x0: number, x1: number, y0: number, y1: number)
		drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, depth), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, zMid), plaster, M.wall)
	end
	slab("Apron", back.lo.X, back.hi.X, back.lo.Y, W.bottom)
	slab("Header", back.lo.X, back.hi.X, W.top, back.hi.Y)
	slab("StileWest", back.lo.X, W.left, W.bottom, W.top)
	slab("StileEast", W.right, back.hi.X, W.bottom, W.top)
	local function bar(name: string, x0: number, x1: number, y0: number, y1: number)
		local trim = drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, W.trimDepth), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, plane - W.trimDepth / 2), wood, M.trim)
		trim.Reflectance = W.trimReflectance
	end
	bar("TrimBottom", W.left, W.right, W.bottom, W.bottom + W.trimWidth)
	bar("TrimTop", W.left, W.right, W.top - W.trimWidth, W.top)
	bar("TrimWest", W.left, W.left + W.trimWidth, W.bottom, W.top)
	bar("TrimEast", W.right - W.trimWidth, W.right, W.bottom, W.top)
	for i, x in W.mullions do
		bar("Mullion" .. i, x - W.mullionWidth / 2, x + W.mullionWidth / 2, W.bottom, W.top)
	end
	local g = W.glass
	local glass = drawn(wall, "Glass", Vector3.new(W.right - W.left, W.top - W.bottom, g.thickness),
		CFrame.new(0, (W.bottom + W.top) / 2, plane - g.setback - g.thickness / 2), hex(g.color), M.glass)
	glass.Transparency = g.transparency
	glass.Reflectance = g.reflectance
	glass.CastShadow = false
	return wall
end

-- ---------------------------------------------------------------- dust motes in the window light
function Scenery.dust(parent: Instance): Part
	local D = Graphics.dust
	local volume = drawn(parent, "DustVolume", D.size, CFrame.new(D.at), Color3.new(1, 1, 1), "SmoothPlastic")
	volume.Transparency = 1
	volume.CastShadow = false
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = D.texture
	motes.Rate = D.rate
	motes.Lifetime = NumberRange.new(D.lifetime[1], D.lifetime[2])
	motes.Speed = NumberRange.new(D.speed[1], D.speed[2])
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-20, 20)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, D.particle[1]),
		NumberSequenceKeypoint.new(0.5, D.particle[2]),
		NumberSequenceKeypoint.new(1, D.particle[1]),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, D.transparency),
		NumberSequenceKeypoint.new(0.8, D.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.LightEmission = D.lightEmission
	motes.LightInfluence = D.lightInfluence
	motes.Color = ColorSequence.new(hex(D.color))
	motes.Drag = 0.5
	motes.Acceleration = Vector3.new(0, 0.01, 0)
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes:SetAttribute("Dust", true) -- WorldDetail thins it out in the low tier
	motes.Parent = volume
	return volume
end

-- ---------------------------------------------------------------- the view out of the window
-- Where an item that should appear at (u, v) on the glass, `depth` beyond it, really goes, and how much bigger it is than
-- it looks. The reference eye is the camera's usual spot (Graphics.view.eye).
function Scenery.viewPosition(u: number, v: number, depth: number): (Vector3, number)
	local eye = Graphics.view.eye
	local plane = piece(W.hidden).hi.Z
	local reach = eye.Z - plane
	local k = (reach + depth) / reach
	return Vector3.new(eye.X + (u - eye.X) * k, eye.Y + (v - eye.Y) * k, plane - depth), k
end

function Scenery.view(parent: Instance): Folder
	local V = Graphics.view
	local view = folder(parent, "View")
	local ground = drawn(view, "Ground", Vector3.new(V.ground.size, 2, V.ground.size),
		CFrame.new(0, V.ground.y - 1, -V.ground.size * 0.5 + 300), hex(V.ground.color), M.ground)
	ground.CastShadow = false
	for _, item in V.items do
		local at, k = Scenery.viewPosition(item.u, item.v, item.depth)
		local t = (item.t or item.w) * k
		local part: Part
		if item.kind == "ball" then
			part = drawn(view, item.id, Vector3.one * item.w * k, CFrame.new(at), hex(item.color), M.view)
			part.Shape = Enum.PartType.Ball
		elseif item.kind == "roof" then
			local side = item.w * k / math.sqrt(2)
			part = drawn(view, item.id, Vector3.new(side, side, t), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(45)), hex(item.color), M.view)
		else
			part = drawn(view, item.id, Vector3.new(item.w * k, (item.h or item.w) * k, t), CFrame.new(at), hex(item.color), M.view)
		end
		part.CastShadow = false
		if item.full then part:SetAttribute("FullOnly", true) end
	end
	return view
end

-- ---------------------------------------------------------------- chips in the paint, cracks, a crumb, a coin and fallen leaves (full tier)
function Scenery.details(parent: Instance): Folder
	local D = Graphics.details
	local details = folder(parent, "Details")
	details:SetAttribute("FullOnly", true)
	for i, c in D.chips do
		local chip = drawn(details, "PaintChip" .. i, Vector3.new(c.w, D.chipThickness, c.d),
			CFrame.new(c.x, D.chipThickness / 2 + 0.001, c.z) * CFrame.Angles(0, math.rad(c.turn), 0), hex(c.color), M.chip)
		chip.CastShadow = false
	end
	for n, line in D.cracks do
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dz * dz)
			local seg = drawn(details, `Crack{n}_{i}`, Vector3.new(D.crackWidth, D.crackHeight, length + D.crackWidth * 0.6),
				CFrame.new((a[1] + b[1]) / 2, D.crackHeight / 2 + 0.001, (a[2] + b[2]) / 2) * CFrame.Angles(0, math.atan2(dx, dz), 0), hex(D.crackColor), M.crack)
			seg.CastShadow = false
		end
	end
	for i, c in D.crumbs do
		drawn(details, "Crumb" .. i, Vector3.new(c.sx, c.sy, c.sz), CFrame.new(c.x, c.y, c.z) * CFrame.Angles(0, math.rad(c.turn), 0), hex(c.color), M.crumb)
	end
	Patina.floor(details) -- a copper coin and some fallen Pilea leaves
	return details
end

-- ---------------------------------------------------------------- soft shafts of light from the window (full tier)
-- `sun`: the unit vector toward the sun. Nothing is built if the sun is not behind the window and above the horizon.
function Scenery.shafts(parent: Instance, sun: Vector3): Folder?
	local S = Graphics.shafts
	if sun.Y < 0.15 or sun.Z > -0.05 then return nil end
	local shafts = folder(parent, "Shafts")
	shafts:SetAttribute("FullOnly", true)
	local plane = piece(W.hidden).hi.Z
	for i, x in S.x do
		local start = Vector3.new(x, S.startY, plane - 0.05)
		local stop = start - sun * ((start.Y - 0.05) / sun.Y) -- along the sun's rays down to just above the floor
		local anchor = drawn(shafts, "ShaftAnchor" .. i, Vector3.one * 0.1, CFrame.new(start), Color3.new(1, 1, 1), "SmoothPlastic")
		anchor.Transparency = 1
		anchor.CastShadow = false
		local a0 = Instance.new("Attachment")
		a0.Name = "Start"
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Name = "End"
		a1.Position = anchor.CFrame:PointToObjectSpace(stop)
		a1.Parent = anchor
		for j, layer in S.layers do
			local beam = Instance.new("Beam")
			beam.Name = `Shaft{i}_{j}`
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Width0 = layer[1]
			beam.Width1 = layer[1] * S.grow
			beam.Transparency = NumberSequence.new(layer[2])
			beam.Color = ColorSequence.new(hex(S.color))
			beam.LightEmission = S.lightEmission
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Parent = anchor
		end
	end
	return shafts
end

-- ---------------------------------------------------------------- everything drawn that is not the sill
-- `sun`: the unit vector toward the sun (Lit.apply's result), for the shafts; nil builds none. Returns the Decor folder and the
-- ids of the sill pieces whose look it replaced (Scenery.sill hides exactly those).
-- The looks are best effort: a piece that fails (nothing here has run in Roblox Studio yet) is warned about, whatever it had
-- already built is removed, and the rest is kept. The wall and the old decor entries are not optional: if they fail,
-- Scenery.decor fails and the server keeps the plain back wall (Server/Main).
local function attempt(decor: Instance, what: string, build: () -> unknown): boolean
	local before: { [Instance]: boolean } = {}
	for _, d in decor:GetDescendants() do before[d] = true end
	local ok, err = pcall(build)
	if not ok then
		warn(`[Windowsill] decor: {what} failed: {tostring(err)}`)
		for _, d in decor:GetDescendants() do
			if not before[d] then d:Destroy() end
		end
	end
	return ok
end

function Scenery.decor(sun: Vector3?): (Folder, { [string]: boolean })
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	local replaced: { [string]: boolean } = {}
	for _, d in Layout.DECOR do
		if not W.replaces[d.id] then
			local p = drawn(decor, d.id, d.size, CFrame.new(d.at), if d.id == "soil" then hex(Flora.planter.soil) else d.color, if d.id == "soil" then M.soil else "SmoothPlastic")
			p.Transparency = d.transparency or 0
		end
	end
	Scenery.window(decor)
	replaced[W.hidden] = true
	local uv = Shapes.folder(decor, "UVLayer") -- the ultraviolet pattern of the flowers (the eye-view helper fades it in); always present
	attempt(decor, "dust", function() return Scenery.dust(decor) end)
	attempt(decor, "view", function() return Scenery.view(decor) end)
	attempt(decor, "details", function() return Scenery.details(decor) end)
	if sun then attempt(decor, "shafts", function() return Scenery.shafts(decor, sun) end) end
	attempt(decor, "wear", function() return Patina.sill(decor) end)
	attempt(decor, "glass details", function() return Patina.glass(decor) end)
	attempt(decor, "retreat", function() return Patina.retreat(decor) end)
	if attempt(decor, "pilea", function() return Plants.pilea(decor) end) then
		for _, id in Plants.pieceIds() do replaced[id] = true end
	end
	attempt(decor, "grass", function() return Plants.grass(decor) end)
	attempt(decor, "planting", function() return Plants.planter(decor) end)
	attempt(decor, "moss", function() return Dressing.moss(decor) end) -- ROBLOX-74: moss, pebbles and bark, two fallen leaves and the dew
	attempt(decor, "litter", function() return Dressing.litter(decor) end)
	attempt(decor, "windfall", function() return Dressing.windfall(decor) end)
	attempt(decor, "dew", function() return Dressing.dew(decor) end)
	attempt(decor, "garden", function() return Plants.garden(decor, uv, Scenery.viewPosition) end)
	return decor, replaced
end

return Scenery
