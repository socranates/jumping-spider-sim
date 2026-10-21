--!strict
-- Thin drawer for the pure memory view (Shared/UI/PerceptionView). Reuses widgets rather than creating Instances every frame.
-- ROBLOX-20, the drawer's polish: a circle is a rounded Frame with a UIStroke, the dashed last-seen ring is 12 short rounded bars,
-- an off-screen cue is a chevron of two bars, the Focus ticks are four bars, and a label is white Builder Sans on a dark pill under
-- the ring it names (above it only when the screen has no room below, so a world billboard over a marker no longer lies on it). The
-- geometry is Shared/UI/PerceptionShapes. What is drawn, and its words, opacities and timings, are PerceptionView's: this changes
-- how it looks, not what it says. ROBLOX-113 (W5) is the one exception: the labels are calmed before they are drawn (Shared/UI/QuietHud.calmLabels), one to an area
-- of the screen with the newest winning and "lost sight" gone in a breath, since Nathan saw three of them piled on the soil; `view` is still the pure view.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local View = require(Shared.UI.PerceptionView)
local Shapes = require(Shared.UI.PerceptionShapes)
local Text = require(Shared.UI.PerceptionText)
local QuietHud = require(Shared.UI.QuietHud)
local Hud = {}
Hud.__index = Hud

local WHITE, DARK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local PILL = Color3.fromRGB(10, 14, 12)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)
local TEXT_SIZE = 18
local THICKNESS = { dash = 2, chevron = 3, tick = 2 }

local function rounded(f: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end

local function outline(f: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode): UIStroke
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.ApplyStrokeMode = color, thickness, mode
	s.Transparency = 1
	s.Parent = f
	return s
end

local function box(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = parent
	return f
end

-- A thin rounded bar with a dark edge: a dash of a last-seen ring, an arm of a chevron, a Focus tick.
local function newBar(parent: Instance): any
	local f = box("Bar", parent)
	f.BackgroundColor3 = WHITE
	rounded(f)
	return { frame = f, edge = outline(f, DARK, 1, Enum.ApplyStrokeMode.Border) }
end

-- A circle: a see-through rounded Frame with a 2 px white stroke and, just outside it, a dark one so it reads on light and dark ground.
local function newCircle(parent: Instance): any
	local f = box("Circle", parent)
	f.BackgroundTransparency = 1
	rounded(f)
	local line = outline(f, WHITE, 2, Enum.ApplyStrokeMode.Border)
	local halo = box("Halo", f)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.new(1, 4, 1, 4)
	halo.BackgroundTransparency = 1
	halo.Visible = true
	rounded(halo)
	return { frame = f, line = line, halo = outline(halo, DARK, 1.5, Enum.ApplyStrokeMode.Border) }
end

-- A label: text with a dark edge on a dark pill that grows to fit it.
local function newLabel(parent: Instance): any
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.BackgroundColor3 = PILL
	l.BorderSizePixel = 0
	l.FontFace = FONT
	l.TextSize = TEXT_SIZE
	l.TextColor3 = WHITE
	l.TextWrapped = false
	l.ZIndex = 2
	l.Visible = false
	l.Parent = parent
	rounded(l)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
	pad.Parent = l
	return { frame = l, edge = outline(l, DARK, 1.5, Enum.ApplyStrokeMode.Contextual) }
end

local MAKE: { [string]: (Instance) -> any } = { bar = newBar, circle = newCircle, label = newLabel }

function Hud.new(parent: Instance): any
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn = "PerceptionHud", true, false
	gui.DisplayOrder = 4
	gui.Parent = parent
	return setmetatable({
		gui = gui,
		pools = { bar = {}, circle = {}, label = {} }, -- every widget made, by kind
		used = { bar = 0, circle = 0, label = 0 }, -- how many this frame has taken
		shown = { bar = 0, circle = 0, label = 0 }, -- how many were showing after the last frame
		labels = {}, -- (ROBLOX-113) the labels drawn this frame: the view's, calmed (UI/QuietHud.calmLabels: one to an area of the screen, "lost sight" gone in a breath)
	}, Hud)
end

function Hud._take(self: any, kind: string): any
	local n = self.used[kind] + 1
	self.used[kind] = n
	local w = self.pools[kind][n]
	if w == nil then
		w = MAKE[kind](self.gui)
		self.pools[kind][n] = w
	end
	return w
end

function Hud._bar(self: any, b: Shapes.Bar, thickness: number, alpha: number)
	local w = self:_take("bar")
	local f = w.frame
	f.Position = UDim2.fromOffset(b.x, b.y)
	f.Size = UDim2.fromOffset(b.length, thickness)
	f.Rotation = b.rotation
	f.BackgroundTransparency = 1 - alpha
	w.edge.Transparency = 1 - alpha * 0.9
	f.Visible = true
end

function Hud._circle(self: any, at: Vector2, radius: number, alpha: number)
	local w = self:_take("circle")
	local f = w.frame
	f.Position = UDim2.fromOffset(at.X, at.Y)
	f.Size = UDim2.fromOffset(radius * 2, radius * 2)
	w.line.Transparency = 1 - alpha
	w.halo.Transparency = 1 - alpha * 0.6
	f.Visible = true
end

-- `offset` is PerceptionView's gap from the ring's middle to the label. The pill's width is whatever it measured last frame.
function Hud._label(self: any, text: string, at: Vector2, offset: number, alpha: number, viewport: Vector2)
	local w = self:_take("label")
	local l = w.frame
	local x, y = Shapes.labelAt(at.X, at.Y, offset, l.AbsoluteSize.X, viewport.X, viewport.Y)
	if l.Text ~= text then
		l.Text = text
	end
	l.Position = UDim2.fromOffset(x, y)
	l.TextTransparency = 1 - alpha
	l.BackgroundTransparency = 1 - 0.55 * alpha
	w.edge.Transparency = 1 - alpha * 0.9
	l.Visible = true
end

-- Hides the widgets the last frame used and this one did not.
function Hud._hideSpare(self: any)
	for kind, pool in self.pools do
		for i = self.used[kind] + 1, self.shown[kind] do
			pool[i].frame.Visible = false
		end
		self.shown[kind] = self.used[kind]
	end
end

-- ROBLOX-110: `showNoticed` false (the setting "Show what the spider notices") draws none of the memory's rings, marks, labels or edge cues (the
-- view is still built, for tests); `lock`, the locked thing's place, gets the lock's only cue: four faint ticks round it where it is on screen.
function Hud.draw(self: any, memory: any, camera: Camera, cast: any, focusing: boolean, showMark: boolean?, showNoticed: boolean?, lock: Vector3?)
	local used = self.used
	used.bar, used.circle, used.label = 0, 0, 0
	local viewport = camera.ViewportSize
	local adapter = {
		project = function(at: Vector3, size: number)
			local p = camera:WorldToViewportPoint(at)
			local q = camera:WorldToViewportPoint(at+camera.CFrame.RightVector*math.max(size,0.2)*0.5)
			return Vector2.new(p.X,p.Y), p.Z > 0 and p.X > -40 and p.Y > -40 and p.X < viewport.X+40 and p.Y < viewport.Y+40,
				math.clamp((Vector2.new(p.X,p.Y)-Vector2.new(q.X,q.Y)).Magnitude,10,36)
		end,
		edge = function(dir: Vector3)
			local d = camera.CFrame:VectorToObjectSpace(dir)
			local v = Vector2.new(d.X,-d.Y)
			if v.Magnitude < 0.03 then v = Vector2.new(0,-1) end
			v = v.Unit
			local half = viewport*0.5-Vector2.new(34,34)
			local t = math.min(half.X/math.max(math.abs(v.X),1e-6),half.Y/math.max(math.abs(v.Y),1e-6))
			return {pos=viewport*0.5+v*t, dir=v}
		end,
		covered = function(at: Vector3, slack: number)
			local eye = camera.CFrame.Position
			local hit = cast(eye,at)
			return hit ~= nil and (hit-eye).Magnitude < (at-eye).Magnitude-slack
		end,
	}
	local view = View.build(memory,adapter,showMark)
	local shown = showNoticed ~= false
	for _, e in (if shown then view.edges else {}) do
		for _, b in Shapes.chevron(e.pos.X, e.pos.Y, e.dir.X, e.dir.Y) do
			self:_bar(b, THICKNESS.chevron, e.alpha)
		end
	end
	for _, r in (if shown then view.rings else {}) do
		if r.kind == "mark" then
			-- Twelve dashes; the gaps grow as the sighting ages (r.dash falls from 1 to 0.3).
			for _, b in Shapes.dashRing(r.pos.X, r.pos.Y, r.radius, r.dash) do
				self:_bar(b, THICKNESS.dash, r.alpha)
			end
		else
			self:_circle(r.pos, r.radius, r.alpha)
		end
	end
	local labels = QuietHud.calmLabels(if shown then view.labels else {}, Text.LOST, self.labels)
	for _, l in labels do
		self:_label(l.text, l.pos, l.offset, l.alpha, viewport)
	end
	if focusing then
		for _, b in Shapes.focusTicks(viewport.X * 0.5, viewport.Y * 0.5) do
			self:_bar(b, THICKNESS.tick, 0.8)
		end
	end
	self.lockShown = false
	if lock ~= nil then
		local p = camera:WorldToViewportPoint(lock)
		if p.Z > 0 and p.X >= 0 and p.Y >= 0 and p.X <= viewport.X and p.Y <= viewport.Y then
			for _, b in Shapes.lockTicks(p.X, p.Y) do
				self:_bar(b, THICKNESS.tick, Shapes.LOCK_ALPHA)
			end
			self.lockShown = true
		end
	end
	self:_hideSpare()
	self.view = view
end
return Hud
