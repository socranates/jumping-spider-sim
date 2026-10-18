--!strict
-- The spider-eye picture (ROBLOX-20): what the eye view looks like, drawn on this client from the pure rules of Shared/UI/EyeOptics
-- and the numbers, with the science and its citations, of Shared/Data/Eyes. Two ways of seeing, blended by k:
--   k = 0, the side eyes: wide (90 degrees), soft, nearly one colour (green), a little blurred, loosely focused, and they catch
--     movement (a ring where the sensor's sight-line checks found something moving, an arc at the edge when it is out of view);
--   k = 1, the principal eyes (Focus held, or toggled on): a narrow telephoto view (24 degrees), sharp, in green and ultraviolet,
--     only the looked-at distance in focus (depth from defocus), the UV layer of the decor showing.
-- Two retina strips at their true angular size scan the view, a vignette darkens the edges and a caption explains the first time.
-- Each frame in the eye view, after the camera is placed (SpiderCamera.render) and before the perception HUD draws: the camera's
-- field of view and SpiderCamera.lookScale, the colour grade and blur (ColorCorrectionEffect EyeGrade and BlurEffect EyeBlur in
-- Lighting), the depth of field (MacroDOF, if the world has one: this module owns it in the eye view and puts back what it
-- borrowed), the overlay (a ScreenGui under the HUD), and the transparency of the UV layer's parts. Outside the eye view it draws
-- nothing and has put everything back; the camera's field of view then belongs to SpiderCamera again.
-- Presentation only: it reads the sensor's motionSeen (never a fly), the camera and the player's attributes (ReducedMotion,
-- FocusToggle, EyeGrey) and moves nothing in the game: the senses, the motor, the jump planner, the aim ray and where the camera stands
-- are as they were.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Eyes = require(Shared.Data.Eyes)
local EyeOptics = require(Shared.UI.EyeOptics)
local ControlText = require(Shared.UI.ControlText)
local Sensor = require(Shared.Perception.Sensor)
local SettingsModel = require(Shared.UI.SettingsModel)

local SpiderEyes = {}
SpiderEyes.__index = SpiderEyes

export type Options = {
	parent: Instance, -- the PlayerGui the overlay goes in
	camera: Camera,
	player: Player,
	cam: any, -- SpiderCamera: eyeView, aimRay(), lookScale
	sensor: any, -- Sensor: motionSeen, lastEye, core.tick
	params: RaycastParams, -- world-only casts (the sill), as the sensor's
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function sequence(points: { { number } }): NumberSequence
	local keys: { NumberSequenceKeypoint } = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

-- A transparent frame centred on its position.
local function box(name: string, parent: Instance, zIndex: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = zIndex
	f.Visible = false
	f.Parent = parent
	return f
end

local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end

local function outline(f: GuiObject, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end

local function gradient(f: Instance, rotation: number, points: { { number } }): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = sequence(points)
	g.Parent = f
	return g
end

local function vignetteEdge(parent: Instance, name: string, anchor: Vector2, position: UDim2, size: UDim2, rotation: number): Frame
	local f = box("Vignette" .. name, parent, 1)
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = rgb(Eyes.vignette.color)
	f.BackgroundTransparency = 1 - Eyes.side.vignette
	f.Visible = true
	gradient(f, rotation, Eyes.vignette.ramp)
	return f
end

function SpiderEyes.new(o: Options): any
	local gui = Instance.new("ScreenGui")
	gui.Name = Eyes.overlay.name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the middle of this screen is the middle of the camera's view, where the aim ray goes
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = Eyes.overlay.displayOrder
	gui.Enabled = false
	gui.Parent = o.parent

	-- The telephoto vignette: four edge frames, darkest at the screen's edge. The gradient's start is the edge.
	local V = Eyes.vignette
	local vignette: { Frame } = {
		vignetteEdge(gui, "Top", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.fromScale(1, V.topBottom), 90),
		vignetteEdge(gui, "Bottom", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.fromScale(1, V.topBottom), -90),
		vignetteEdge(gui, "Left", Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.fromScale(V.leftRight, 1), 0),
		vignetteEdge(gui, "Right", Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), UDim2.fromScale(V.leftRight, 1), 180),
	}

	-- The two retina strips: a faint filled capsule with a thin outline, each with a fill that fades toward its ends.
	local R = Eyes.retina
	local strips: { { frame: Frame, stroke: UIStroke } } = {}
	for i = 1, 2 do
		local f = box("Retina" .. i, gui, 2)
		f.BackgroundColor3 = rgb(R.fillColor)
		f.BackgroundTransparency = Eyes.side.fillTransparency
		round(f)
		gradient(f, 90, R.fillRamp)
		strips[i] = { frame = f, stroke = outline(f, rgb(R.strokeColor), R.strokeThickness) }
	end

	local effects = Eyes.effects
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = effects.grade
	grade.Enabled = false
	grade.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = effects.blur
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	return setmetatable({
		camera = o.camera, player = o.player, cam = o.cam, sensor = o.sensor, params = o.params,
		gui = gui, vignette = vignette, vignetteShown = -1, strips = strips,
		rings = {} :: { any }, arcs = {} :: { any },
		grade = grade, blur = blur,
		on = false,
		phase = 0, k = 0, clock = 0,
		focusDistance = nil :: number?,
		dofSaved = nil :: any,
		uv = { folder = nil :: Instance?, parts = {} :: { any }, wait = 0, scan = true },
		captionAge = 0,
		moversShown = 0, -- how many movement rings and edge arcs the last frame drew (the notebook's "shimmer" reads it)
	}, SpiderEyes)
end

-- ---------------------------------------------------------------- entering and leaving the eye view
function SpiderEyes._enter(self: any)
	self.on = true
	self.phase, self.k = 0, 0
	self.focusDistance = nil
	self.gui.Enabled = true
	self.grade.Enabled = true
	self.uv.scan = true
end

function SpiderEyes._leave(self: any)
	self.on = false
	self.phase, self.k = 0, 0
	self.gui.Enabled = false
	self.grade.Enabled = false
	self.blur.Enabled = false
	self.cam.lookScale = 1
	self:_restoreDepthOfField()
	self:_setUv(0)
	self:_hideMovers(0, 0)
	self.moversShown = 0
end

-- Puts the world's depth of field back as the third person had it.
function SpiderEyes._restoreDepthOfField(self: any)
	local saved = self.dofSaved
	self.dofSaved = nil
	if saved ~= nil and saved.effect.Parent ~= nil then
		saved.effect.FarIntensity = saved.far
		saved.effect.NearIntensity = saved.near
		saved.effect.InFocusRadius = saved.radius
	end
end

-- ---------------------------------------------------------------- depth of field
-- The world's own MacroDOF, if there is one (the low tier has none): in the eye view its sharp zone follows what is looked at.
function SpiderEyes._depthOfField(self: any, p: EyeOptics.Profile)
	local dof = Lighting:FindFirstChild(Eyes.effects.dof)
	if dof == nil or not dof:IsA("DepthOfFieldEffect") or dof.Enabled == false then
		return
	end
	local saved = self.dofSaved
	if saved == nil or saved.effect ~= dof then
		self.dofSaved = { effect = dof, far = dof.FarIntensity, near = dof.NearIntensity, radius = dof.InFocusRadius }
	end
	dof.FocusDistance = self.focusDistance
	dof.FarIntensity = p.dofFar
	dof.NearIntensity = p.dofNear
	dof.InFocusRadius = p.dofRadius
end

-- ---------------------------------------------------------------- the UV layer
local function findUvFolder(): Instance?
	local node: Instance? = Workspace
	for _, name in Eyes.uv.folder do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end

-- Every part of the folder with the opacity it asks for (its own attribute, else the folder's, else none).
function SpiderEyes._collectUv(self: any, folder: Instance)
	local U = Eyes.uv
	local parts: { any } = {}
	local fallback = folder:GetAttribute(U.opacityAttribute)
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			local own = d:GetAttribute(U.opacityAttribute)
			local opacity = if type(own) == "number" then own elseif type(fallback) == "number" then fallback else 0
			table.insert(parts, { part = d, opacity = opacity, last = 1 })
		end
	end
	self.uv.parts = parts
end

-- Sets the layer for k, looking the folder up first if need be (at most every lookupSeconds until it exists).
function SpiderEyes._updateUv(self: any, k: number, dt: number)
	local uv = self.uv
	if uv.folder == nil or uv.folder.Parent == nil then
		uv.wait -= dt
		if uv.wait > 0 then
			return
		end
		uv.wait = Eyes.uv.lookupSeconds
		uv.folder = findUvFolder()
		uv.scan = true
		if uv.folder == nil then
			return
		end
	end
	if uv.scan then
		uv.scan = false
		self:_collectUv(uv.folder)
	end
	self:_setUv(k)
end

function SpiderEyes._setUv(self: any, k: number)
	for _, e in self.uv.parts do
		local t = EyeOptics.uvTransparency(k, e.opacity)
		if t ~= e.last and e.part.Parent ~= nil then
			e.part.Transparency = t
			e.last = t
		end
	end
end

-- ---------------------------------------------------------------- the overlay
function SpiderEyes._drawVignette(self: any, p: EyeOptics.Profile)
	if p.vignette == self.vignetteShown then
		return
	end
	self.vignetteShown = p.vignette
	for _, f in self.vignette do
		f.BackgroundTransparency = 1 - p.vignette
	end
end

function SpiderEyes._drawStrips(self: any, strips: { EyeOptics.Strip }, p: EyeOptics.Profile)
	for i, s in strips do
		local w = self.strips[i]
		local f = w.frame
		f.Position = UDim2.fromOffset(s.x, s.y)
		f.Size = UDim2.fromOffset(s.w, s.h)
		f.Rotation = s.rotation
		f.BackgroundTransparency = p.fillTransparency
		f.Visible = true
		w.stroke.Transparency = p.strokeTransparency
	end
end

local function newRing(parent: Instance): any
	local S = Eyes.shimmer
	local f = box("Ring", parent, 3)
	round(f)
	local shadow = box("RingShadow", f, 3)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.Size = UDim2.new(1, S.shadowGrowPx * 2, 1, S.shadowGrowPx * 2)
	shadow.Visible = true
	round(shadow)
	return {
		frame = f, stroke = outline(f, rgb(S.ringColor), S.ringThickness),
		shadow = shadow, shadowStroke = outline(shadow, rgb(S.shadowColor), S.shadowThickness),
	}
end

local function newArc(parent: Instance): any
	local S, A = Eyes.shimmer, Eyes.shimmer.arc
	local bars: { any } = {}
	for i = 1, A.segments do
		local f = box("ArcBar", parent, 3)
		f.BackgroundColor3 = rgb(S.ringColor)
		f.Size = UDim2.fromOffset(A.length, A.thickness)
		round(f)
		bars[i] = { frame = f, stroke = outline(f, rgb(S.shadowColor), 1) }
	end
	return { bars = bars }
end

-- Hides the rings and arcs from the given counts on (everything when both are 0).
function SpiderEyes._hideMovers(self: any, rings: number, arcs: number)
	for i = rings + 1, #self.rings do
		self.rings[i].frame.Visible = false
	end
	for i = arcs + 1, #self.arcs do
		for _, b in self.arcs[i].bars do
			b.frame.Visible = false
		end
	end
end

-- The lateral eyes' movement sense. Only what the sensor's sight-line checks found moving is drawn (Sensor.motionSeen): the
-- point is where the sensor put the thing (the eye, along the sensed direction, at the sensed distance), never where a fly is.
function SpiderEyes._drawMovers(self: any, strips: { EyeOptics.Strip }, p: EyeOptics.Profile, size: Vector2, reduced: boolean)
	local S, sensor, camera = Eyes.shimmer, self.sensor, self.camera
	local now: number = sensor.core.tick
	local pulse = EyeOptics.pulse(self.clock, reduced)
	local look: CFrame = camera.CFrame
	local rings, arcs = 0, 0
	for _, m in EyeOptics.pickMovers(sensor.motionSeen, S.maxMovers) do
		local fresh = EyeOptics.freshness(now, m.tick, Sensor.MOTION_HOLD_TICKS)
		if fresh <= 0 then
			continue
		end
		local world: Vector3 = sensor.lastEye + m.direction * m.distance
		local v = camera:WorldToViewportPoint(world)
		if v.Z > 0 and EyeOptics.onScreen(v.X, v.Y, size.X, size.Y, 0) then
			rings += 1
			local ring = self.rings[rings]
			if ring == nil then
				ring = newRing(self.gui)
				self.rings[rings] = ring
			end
			local d = EyeOptics.ringDiameter(m.apparent, p.fovDeg, size.Y, pulse)
			local alpha = EyeOptics.ringAlpha(fresh, EyeOptics.insideAnyStrip(v.X, v.Y, strips))
			ring.frame.Position = UDim2.fromOffset(v.X, v.Y)
			ring.frame.Size = UDim2.fromOffset(d, d)
			ring.stroke.Transparency = 1 - alpha
			ring.shadowStroke.Transparency = 1 - alpha * S.shadowAlpha
			ring.frame.Visible = true
		else
			arcs += 1
			local arc = self.arcs[arcs]
			if arc == nil then
				arc = newArc(self.gui)
				self.arcs[arcs] = arc
			end
			local towards = look:VectorToObjectSpace(world - look.Position)
			local x, y, dx, dy = EyeOptics.edgeMark(towards.X, towards.Y, size.X, size.Y, S.arc.inset)
			local alpha = EyeOptics.arcAlpha(fresh, pulse)
			for i, seg in EyeOptics.arcSegments(x, y, dx, dy) do
				local bar = arc.bars[i]
				bar.frame.Position = UDim2.fromOffset(seg.x, seg.y)
				bar.frame.Rotation = seg.rotation
				bar.frame.BackgroundTransparency = 1 - alpha
				bar.stroke.Transparency = 1 - alpha * S.shadowAlpha
				bar.frame.Visible = true
			end
		end
	end
	self:_hideMovers(rings, arcs)
	self.moversShown = rings + arcs
end

-- ---------------------------------------------------------------- the words
-- The caption for the status area (SpiderHud shows it under the status lines): {text, alpha}, or nil when there is none. It is
-- shown the first time the eye view is open, for Eyes.caption.seconds of it, and not again.
function SpiderEyes.captionView(self: any, device: ControlText.Device): { text: string, alpha: number }?
	if not self.cam.eyeView then
		return nil
	end
	local alpha = EyeOptics.captionAlpha(self.captionAge)
	if alpha <= 0 then
		return nil
	end
	return { text = EyeOptics.captionText(ControlText.name(device, "focus"), self.player:GetAttribute("FocusToggle") == true), alpha = alpha }
end

-- ---------------------------------------------------------------- the frame
-- Once a render frame, after SpiderCamera.render. dt: real seconds (looking runs in real time, slow motion or not). focusing: the
-- client's own notion of Focus (held, or toggled on, on a surface), the same that the perception HUD gets.
function SpiderEyes.update(self: any, dt: number, focusing: boolean)
	local on = self.cam.eyeView == true
	if on ~= self.on then
		if on then
			self:_enter()
		else
			self:_leave()
		end
	end
	if not on then
		return
	end
	local reduced = self.player:GetAttribute("ReducedMotion") == true
	self.phase = EyeOptics.stepPhase(self.phase, focusing, dt)
	local k = EyeOptics.engagement(self.phase)
	self.k = k
	self.clock += dt
	if self.captionAge < Eyes.caption.seconds then
		self.captionAge += dt
	end

	-- What is looked at: along the view, to the world only, at most 40 studs; the focus racks toward it.
	local origin, direction = self.cam:aimRay()
	local hit = Workspace:Raycast(origin, direction * Eyes.focus.maxDistance, self.params)
	local target = EyeOptics.focusTarget(if hit ~= nil then hit.Distance else nil)
	local focus: number? = self.focusDistance
	focus = if focus == nil then target else EyeOptics.focusStep(focus, target, dt)
	self.focusDistance = focus
	local p = EyeOptics.profile(k, focus :: number, reduced)

	self.camera.FieldOfView = p.fovDeg
	self.cam.lookScale = EyeOptics.lookScale(p.fovDeg)
	local grade = self.grade
	grade.Saturation, grade.TintColor, grade.Contrast, grade.Brightness = p.saturation, p.tint, p.contrast, p.brightness
	-- The comfort switch "grey instead of green" (T13a, ROBLOX-49): the same picture and brightness without the tint or any colour.
	if SettingsModel.get(function(id: string): any return self.player:GetAttribute(id) end, "EyeGrey") == true then
		grade.Saturation, grade.TintColor = -1, Color3.new(1, 1, 1)
	end
	self.blur.Size = p.blur
	self.blur.Enabled = p.blur > 0.05
	self:_depthOfField(p)
	self:_updateUv(k, dt)

	local size = self.camera.ViewportSize
	if size.Y < 1 then
		return
	end
	self:_drawVignette(p)
	local strips = EyeOptics.retinaStrips(self.clock, p, size.X, size.Y)
	self:_drawStrips(strips, p)
	self:_drawMovers(strips, p, size, reduced)
end

-- Puts everything back and removes what this made (tests; the client keeps it for the session).
function SpiderEyes.destroy(self: any)
	if self.on then
		self:_leave()
	end
	self.gui:Destroy()
	self.grade:Destroy()
	self.blur:Destroy()
end

return SpiderEyes
