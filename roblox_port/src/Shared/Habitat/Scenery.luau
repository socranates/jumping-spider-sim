--!strict
-- Builds the drawn world from Data/Graphics: the sill's physical pieces (looks only), and a "Decor" model (a persistent one, ROBLOX-94) with the window wall,
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
	local all: { [string]: boolean } = {}
	for _, id in W.hidden do all[id] = true end
	for _, id in Plants.pieceIds() do all[id] = true end
	return all
end

-- The box the drawn window wall stands in for: the union of the back frame's pieces (one box until ROBLOX-95, four around the raised sash since). `min, max`.
function Scenery.wallBox(): (Vector3, Vector3)
	local first = piece(W.hidden[1])
	local x0, y0, z0, x1, y1, z1 = first.lo.X, first.lo.Y, first.lo.Z, first.hi.X, first.hi.Y, first.hi.Z
	for _, id in W.hidden do
		local p = piece(id)
		x0, y0, z0 = math.min(x0, p.lo.X), math.min(y0, p.lo.Y), math.min(z0, p.lo.Z)
		x1, y1, z1 = math.max(x1, p.hi.X), math.max(y1, p.hi.Y), math.max(z1, p.hi.Z)
	end
	return Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)
end

-- The physical parts of some pieces, one anchored Part for each, into `parent` (ROBLOX-94: the part-making the sill always had, for any region's pieces; World/WorldBuild builds
-- each region with it). `hide`: the ids of the pieces whose look is replaced by a drawing; those turn invisible but stay solid and climbable.
function Scenery.parts(parent: Instance, pieces: { Layout.Piece }, hide: { [string]: boolean })
	for _, spec in pieces do
		assert(Surfaces[spec.profile], "unknown surface profile " .. spec.profile)
		local p = Instance.new("Part")
		p.Name = spec.id
		p.Anchored = true
		p.Size = spec.hi - spec.lo
		p.Position = (spec.lo + spec.hi) * 0.5
		local paint = Graphics.paint[spec.id]
		p.Color = if paint then hex(paint.color) else spec.color
		if paint and paint.reflectance then p.Reflectance = paint.reflectance end
		p.Material = Materials.get(M.pieces[spec.id] or (spec :: any).material or M.fallback) -- (a garden piece names its own, ROBLOX-95: World/Garden)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("SurfaceId", spec.id)
		p:SetAttribute("ProfileId", spec.profile)
		if hide[spec.id] then
			-- still solid and climbable; the decor draws it in its place (the wall with a see-through opening, the leaves and stems)
			p.Transparency = 1
			p.CastShadow = false
		end
		p.Parent = parent
	end
end

-- `replaced`: the ids of the pieces whose drawn version exists (Scenery.decor's second result); those turn invisible but stay solid
-- and climbable. A piece whose drawing could not be built stays visible instead of leaving a hole. nil means all the pieces that
-- the decor can replace (the wall and the Pilea's leaves and stems). `pieces`: the sill's boxes (the layout's own unless World/WorldBuild hands in its region's, which are the same).
function Scenery.sill(replaced: { [string]: boolean }?, pieces: { Layout.Piece }?): Folder
	local hide = replaced or replaceable()
	local sill = Instance.new("Folder")
	sill.Name = "Windowsill"
	sill:SetAttribute("ContentRevision", Layout.CONTENT_REVISION)
	Scenery.parts(sill, pieces or Layout.PIECES, hide)
	return sill
end

-- ---------------------------------------------------------------- a drawn look from records (ROBLOX-95)
-- One drawn-only part for each record of a region's look (World/Garden.Drawn: Region.decor of every kind but the sill's): anchored, nothing collides with it, no
-- ray sees it, built into a folder per `group` under `parent`; `full` records carry FullOnly (Client/WorldDetail drops them on the low tier). Returns how many.
-- ROBLOX-108: `first` and `last` build only that slice of the list (a client spreads a look over a few frames, Client/LookStream), and `folders`, kept by the
-- caller between slices, holds the group folders already made under `parent`, so a look built in slices is the one built at once.
export type Drawn = {
	id: string, size: Vector3, at: Vector3, color: Color3, transparency: number?,
	material: string?, shape: string?, turn: Vector3?, full: boolean?, group: string?, shadow: boolean?,
	far: boolean?, reflectance: number?, -- (ROBLOX-115: the preserve's backdrop: in the zone's far look; a shine)
	dew: number?, -- (ROBLOX-117: a dew drop's lag)
}
function Scenery.look(parent: Instance, list: { Drawn }, first: number?, last: number?, folders: { [string]: Instance }?): number
	local groups: { [string]: Instance } = folders or {}
	local i0, i1 = first or 1, math.min(last or #list, #list)
	for i = i0, i1 do
		local d = list[i]
		local name = d.group or ""
		local into: Instance? = groups[name]
		if into == nil then
			local made = if name == "" then parent else folder(parent, name)
			groups[name] = made
			into = made
		end
		local cframe = CFrame.new(d.at)
		if d.turn ~= nil then cframe *= CFrame.Angles(math.rad(d.turn.X), math.rad(d.turn.Y), math.rad(d.turn.Z)) end
		local p = drawn(into :: Instance, d.id, d.size, cframe, d.color, d.material or "SmoothPlastic")
		p.Transparency = d.transparency or 0
		if d.reflectance ~= nil then p.Reflectance = d.reflectance end
		p.CastShadow = d.shadow == true
		if d.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif d.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		elseif d.shape == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		if d.full then p:SetAttribute("FullOnly", true) end
		-- (ROBLOX-117) a dew drop: hidden until Habitat/DayLight.applyDew shows it by the hour, from its lag to its transparency at full dew
		if d.dew ~= nil then
			p:SetAttribute("Lag", d.dew)
			p:SetAttribute("Base", d.transparency or 0.35)
			p.Transparency = 1
		end
	end
	return math.max(0, i1 - i0 + 1)
end

-- ---------------------------------------------------------------- the window wall
-- ROBLOX-95: the middle lower sash is raised 6 cm (Graphics.window.opening, the layout's own gap between the back frame's four pieces). The wall below the
-- window is cut there down to the sill rail, the jambs line the cut, the glass over the gap is gone, and the raised sash's bottom rail runs across its top;
-- the upper part of the middle pane is the raised sash's glass and the side panes are as they were. Everything drawn stays behind the climbable faces
-- (`slabGap`) or flush with them, as the wall always has.
function Scenery.window(parent: Instance): Folder
	local wall = folder(parent, "Wall")
	local lo, hi = Scenery.wallBox()
	local plane = hi.Z -- the climbable face
	local slabFront = plane - W.slabGap
	local zMid = (slabFront + lo.Z) / 2
	local depth = slabFront - lo.Z
	local head = math.max(hi.Y, W.head) -- (ROBLOX-112: the frame goes on up over the back frame to the window's head, over World/Garden's window box)
	local plaster, wood = hex(W.wallColor), hex(W.trimColor)
	local O, jamb, gap = W.opening, W.jambWidth, W.slabGap
	local function slab(name: string, x0: number, x1: number, y0: number, y1: number)
		drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, depth), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, zMid), plaster, M.wall)
	end
	slab("ApronWest", lo.X, O.left - jamb, lo.Y, W.bottom)
	slab("ApronEast", O.right + jamb, hi.X, lo.Y, W.bottom)
	slab("Header", lo.X, hi.X, W.top, head)
	slab("StileWest", lo.X, W.left, W.bottom, W.top)
	slab("StileEast", W.right, hi.X, W.bottom, W.top)
	local function bar(name: string, x0: number, x1: number, y0: number, y1: number)
		local trim = drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, W.trimDepth), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, plane - W.trimDepth / 2), wood, M.trim)
		trim.Reflectance = W.trimReflectance
	end
	local t0, t1 = W.transom, W.transom + W.transomH
	bar("TrimBottomWest", W.left, O.left - jamb, W.bottom, W.bottom + W.trimWidth)
	bar("TrimBottomEast", O.right + jamb, W.right, W.bottom, W.bottom + W.trimWidth)
	bar("TrimTop", W.left, W.right, W.top - W.trimWidth, W.top)
	bar("TrimWest", W.left, W.left + W.trimWidth, W.bottom, W.top)
	bar("TrimEast", W.right - W.trimWidth, W.right, W.bottom, W.top)
	for i, x in W.mullions do
		bar("Mullion" .. i, x - W.mullionWidth / 2, x + W.mullionWidth / 2, W.bottom, W.top)
	end
	-- (ROBLOX-112) the transom across the side lights and the upper sash's bottom rail across the middle one, where the sashes meet
	bar("TransomWest", W.left, O.left - jamb, t0, t1)
	bar("TransomEast", O.right + jamb, W.right, t0, t1)
	bar("MeetingRail", O.left - jamb, O.right + jamb, t0, t1)
	-- the way out: the sill rail (trim, its top a hair under the rail's walkable top), the jambs through the wall's depth either side, and the raised
	-- sash's bottom rail across the top, set back in the frame
	local function block(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): Part
		local p = drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), wood, M.trim)
		p.Reflectance = W.trimReflectance
		return p
	end
	block("SillRail", O.left - jamb, O.right + jamb, lo.Y, O.bottom - gap, lo.Z + gap, slabFront)
	block("JambWest", O.left - jamb, O.left - gap, O.bottom - gap, O.top + W.sashRail, lo.Z + gap, slabFront)
	block("JambEast", O.right + gap, O.right + jamb, O.bottom - gap, O.top + W.sashRail, lo.Z + gap, slabFront)
	block("SashRail", O.left - jamb, O.right + jamb, O.top + gap, O.top + W.sashRail, plane - W.sashSetback - W.sashDepth, plane - W.sashSetback)
	-- (ROBLOX-112) the raised lower sash's top rail, as far over the transom as the sash is raised, set back as its bottom rail is
	block("SashTop", O.left - jamb, O.right + jamb, t0 + W.sashLift, t1 + W.sashLift, plane - W.sashSetback - W.sashDepth, plane - W.sashSetback)
	local g = W.glass
	local gz = plane - g.setback - g.thickness / 2
	local function pane(name: string, x0: number, x1: number, y0: number, y1: number)
		local glass = drawn(wall, name, Vector3.new(x1 - x0, y1 - y0, g.thickness), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, gz), hex(g.color), M.glass)
		glass.Transparency = g.transparency
		glass.Reflectance = g.reflectance
		glass.CastShadow = false
	end
	pane("GlassWest", W.left, O.left - jamb, W.bottom, t0)
	pane("GlassEast", O.right + jamb, W.right, W.bottom, t0)
	pane("Glass", O.left - jamb, O.right + jamb, O.top + W.sashRail, t0 + W.sashLift) -- the raised sash's pane, up behind the upper sash's rail to its own
	-- (ROBLOX-112) the upper lights over the transom
	pane("GlassUpperWest", W.left, O.left - jamb, t1, W.top)
	pane("GlassUpperEast", O.right + jamb, W.right, t1, W.top)
	pane("GlassUpper", O.left - jamb, O.right + jamb, t1 + W.sashLift, W.top)
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
	local _, wallHi = Scenery.wallBox()
	local plane = wallHi.Z
	local reach = eye.Z - plane
	local k = (reach + depth) / reach
	return Vector3.new(eye.X + (u - eye.X) * k, eye.Y + (v - eye.Y) * k, plane - depth), k
end

Scenery.MAX_PART = 2048 -- (ROBLOX-114) the largest a part may be along any axis in Roblox

function Scenery.view(parent: Instance): Folder
	local V = Graphics.view
	local view = folder(parent, "View")
	local ground = drawn(view, "Ground", Vector3.new(V.ground.size, 2, V.ground.size),
		CFrame.new(0, V.ground.y - 1, -V.ground.size * 0.5 + 300), hex(V.ground.color), M.ground)
	ground.CastShadow = false
	if V.ground.beyond then -- (ROBLOX-114: the same again past its far edge, under the gardens and the houses across the way)
		local far = drawn(view, "GroundBeyond", Vector3.new(V.ground.size, 2, V.ground.size),
			CFrame.new(0, V.ground.y - 1, -V.ground.size * 1.5 + 300), hex(V.ground.color), M.ground)
		far.CastShadow = false
	end
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
		elseif item.kind == "trunk" then -- (ROBLOX-103: a round upright rod)
			part = drawn(view, item.id, Vector3.new((item.h or item.w) * k, item.w * k, item.w * k), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), hex(item.color), "Wood")
			part.Shape = Enum.PartType.Cylinder
		elseif item.kind == "hill" then -- (ROBLOX-103)
			-- (ROBLOX-114: a part is at most 2,048 studs; a bigger hill is a part of at most that with its sphere mesh scaled up to the hill's size)
			local size = Vector3.new(item.w * k, (item.h or item.w) * k, t)
			local most = math.max(size.X, size.Y, size.Z)
			local shrink = if most > Scenery.MAX_PART then Scenery.MAX_PART / most else 1
			part = drawn(view, item.id, size * shrink, CFrame.new(at), hex(item.color), M.view)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.one / shrink
			mesh.Parent = part
		else
			part = drawn(view, item.id, Vector3.new(item.w * k, (item.h or item.w) * k, t), CFrame.new(at), hex(item.color), M.view)
		end
		part.CastShadow = false
		if item.full then part:SetAttribute("FullOnly", true) end
	end
	Scenery.across(view)
	return view
end

-- ROBLOX-103: the bungalows across the way and the garden's fences (Graphics.view.across, Graphics.view.fence), in the garden's own studs, into the view's folder:
-- for each house its rendered wall, the front slope of its roof up to the ridge (both tiers), a ridge cap, a row of windows, a door and a chimney (full tier);
-- the back fence and the two side fences (both tiers) and the back fence's posts (full tier). Nothing casts a shadow (the view never has), so the light is the light.
function Scenery.across(view: Instance)
	local A, F = Graphics.view.across, Graphics.view.fence
	local ground = Graphics.view.ground.y
	local function part(name: string, size: Vector3, cframe: CFrame, color: string, material: string, full: boolean): Part
		local p = drawn(view, name, size, cframe, hex(color), material)
		p.CastShadow = false
		if full then p:SetAttribute("FullOnly", true) end
		return p
	end
	local pitch = math.rad(A.pitch)
	local run = A.depth / 2 + A.overhang -- from the eave out front to the ridge over the middle, flat
	local slope = run / math.cos(pitch)
	local eaveY = ground + A.wall -- (the eave stands `overhang` out from the front wall, toward the garden, +z)
	for _, h in A.houses do
		local backZ = A.front - A.depth
		part(h.id .. "_wall", Vector3.new(h.w, A.wall, A.depth), CFrame.new(h.x, ground + A.wall / 2, (A.front + backZ) / 2), h.wall, A.wallMaterial, false)
		-- the roof's front slope: from the eave (over the overhang, in front of the wall) up and back to the ridge over the middle
		local mid = Vector3.new(h.x, eaveY + run * math.tan(pitch) / 2, A.front + A.overhang - run / 2)
		part(h.id .. "_roof", Vector3.new(h.w + 2 * A.overhang, 6, slope), CFrame.new(mid) * CFrame.Angles(pitch, 0, 0), h.roof, A.roofMaterial, false)
		local ridgeY = eaveY + run * math.tan(pitch)
		local ridgeZ = A.front + A.overhang - run
		part(h.id .. "_ridge", Vector3.new(h.w + 2 * A.overhang, A.ridgeCap, A.ridgeCap * 1.6), CFrame.new(h.x, ridgeY + 2, ridgeZ), h.roof, A.roofMaterial, true)
		-- one row of windows (and a door), evenly along the front, a hair proud of the wall
		local W, D = A.window, A.door
		local slots = h.windows + (if h.door then 1 else 0)
		for k = 1, slots do
			local x = h.x - h.w / 2 + h.w * (k - 0.5) / slots
			if h.door and k == math.ceil(slots / 2) then
				part(`{h.id}_door`, Vector3.new(D.w, D.h, 3), CFrame.new(x, ground + D.h / 2, A.front + 1.4), D.color, A.wallMaterial, true)
			else
				part(`{h.id}_window{k}`, Vector3.new(W.w, W.h, 3), CFrame.new(x, ground + W.sill + W.h / 2, A.front + 1.4), W.color, "SmoothPlastic", true).Reflectance = 0.08
			end
		end
		if h.chimney ~= nil then
			local C = A.chimney
			local cx = h.x + h.chimney * h.w
			part(h.id .. "_chimney", Vector3.new(C.w, C.h + 60, C.t), CFrame.new(cx, ridgeY + C.h / 2 - 30, ridgeZ + 40), C.color, "Brick", true)
		end
	end
	-- the fences: the back one across the garden's end, the sides from the house to it
	local depthOf = F.near - F.back
	part("fence_back", Vector3.new(F.x1 - F.x0, F.height, F.thick), CFrame.new((F.x0 + F.x1) / 2, ground + F.height / 2, F.back), F.color, F.material, false)
	for i, x in { F.x0, F.x1 } do
		part("fence_side" .. i, Vector3.new(F.thick, F.height, depthOf), CFrame.new(x, ground + F.height / 2, (F.near + F.back) / 2), F.color, F.material, false)
	end
	for k = 1, F.posts do
		local x = F.x0 + (F.x1 - F.x0) * (k - 0.5) / F.posts
		part("fence_post" .. k, Vector3.new(F.post, F.height + 6, F.post), CFrame.new(x, ground + (F.height + 6) / 2, F.back + F.thick / 2 + F.post / 2), F.postColor, "Wood", true)
	end
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
	local _, wallHi = Scenery.wallBox()
	local plane = wallHi.Z
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

-- ROBLOX-115: `world` (World/Worlds' id; the test garden when nil) is the world outside the window. The preserve's sill is the same sill in the ranger hut's window,
-- but what it looks out on is the preserve's backdrop (World/PreserveLook, streamed on each client by Client/LookStream), so its Decor draws neither the test
-- garden's view (the lawn, the trees, the bungalows, the fences, the hills) nor its window box on the outer sill.
function Scenery.decor(sun: Vector3?, world: string?): (Model, { [string]: boolean })
	local garden = world == nil or world == "test_garden"
	-- ROBLOX-94: a Model, and a persistent one, so that with instance streaming on (Workspace.StreamingEnabled) the whole drawn sill, and the far view out of the window above
	-- all, reaches every client at once and never streams out; a Folder would be streamed part by part around the replication focus, and the view is hundreds of studs away.
	-- (Without streaming it is exactly the container the Folder was.) The client's one-time reads of it (Breakaway, WorldDetail, DayLight) depend on it being whole.
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local replaced: { [string]: boolean } = {}
	for _, d in Layout.DECOR do
		if not W.replaces[d.id] then
			local p = drawn(decor, d.id, d.size, CFrame.new(d.at), if d.id == "soil" then hex(Flora.planter.soil) else d.color, if d.id == "soil" then M.soil else "SmoothPlastic")
			p.Transparency = d.transparency or 0
		end
	end
	Scenery.window(decor)
	for _, id in W.hidden do replaced[id] = true end
	replaced[W.upper] = true -- (ROBLOX-112: the window above the back frame, World/Garden's box in the region wall_upper, drawn with the rest of it here)
	local uv = Shapes.folder(decor, "UVLayer") -- the ultraviolet pattern of the flowers (the eye-view helper fades it in); always present
	attempt(decor, "dust", function() return Scenery.dust(decor) end)
	if garden then attempt(decor, "view", function() return Scenery.view(decor) end) end
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
	-- (the window box's halves stand on the outer sill, solid: World/Garden's pieces, hidden once drawn here, ROBLOX-95)
	if garden and attempt(decor, "garden", function() return Plants.garden(decor, uv, Scenery.viewPosition) end) then
		for _, id in Plants.windowBoxIds() do replaced[id] = true end
	end
	return decor, replaced
end

return Scenery
