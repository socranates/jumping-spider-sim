--!strict
-- The spider's screen: the centre dot and Focus ticks, the aim's words under them (Godot jump_hud.gd), a status line and
-- short toasts at the top, the controls card, and the prompt panel at the bottom (the line's own prompts while hanging,
-- what stops a walk to the edge, or a small reminder while walking). Words come from Shared/UI/ControlText for the device
-- in use. Everything but the centre dot sits in the safe area (ScreenInsets.CoreUISafeInsets) and wraps; the prompt panel
-- keeps clear of the touch buttons (Shared/UI/HudLayout).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("HudLayout"))

local Hud = {}
Hud.__index = Hud

local TOAST_SECONDS = 2.6
local OK_COLOR = Color3.new(0.92, 0.94, 0.98)
local WARN_COLOR = Color3.new(1.0, 0.72, 0.1)

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function pad(parent: Instance, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, x), UDim.new(0, x)
	p.PaddingTop, p.PaddingBottom = UDim.new(0, y), UDim.new(0, y)
	p.Parent = parent
end

-- A label that keeps its width and wraps, growing downward (the safe way to wrap with AutomaticSize).
local function wrapLabel(name: string, parent: Instance, textSize: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.4
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextWrapped = true
	l.RichText = false
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.Visible = false
	pad(l, 10, 5)
	corner(l, 8)
	l.Parent = parent
	return l
end

-- A short label sized to its text (single lines broken by hand), for the aim words at the centre.
local function pill(name: string, parent: Instance, textSize: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.45
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextWrapped = false
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.LayoutOrder = order
	l.Visible = false
	pad(l, 10, 4)
	corner(l, 8)
	l.Parent = parent
	return l
end

local function column(name: string, parent: Instance, anchor: Vector2, position: UDim2, align: Enum.VerticalAlignment): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = UDim2.new(1, -32, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = align
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = f
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(HudLayout.MAX_PROMPT_WIDTH, math.huge)
	limit.Parent = f
	f.Parent = parent
	return f
end

function Hud.new(playerGui: Instance): any
	-- The centre dot must be at the true viewport centre (the camera's aim ray), so this layer ignores the insets.
	local centre = Instance.new("ScreenGui")
	centre.Name = "SpiderHud"
	centre.ResetOnSpawn = false
	centre.IgnoreGuiInset = true
	centre.ScreenInsets = Enum.ScreenInsets.None
	centre.Parent = playerGui
	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	reticle.Size = UDim2.fromOffset(6, 6)
	reticle.BackgroundColor3 = Color3.new(1, 1, 1)
	reticle.Visible = false
	corner(reticle, 3)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = reticle
	reticle.Parent = centre
	local ticks: { Frame } = {}
	for i, off in { Vector2.new(-16, 0), Vector2.new(16, 0), Vector2.new(0, -16), Vector2.new(0, 16) } do
		local t = Instance.new("Frame")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.new(0.5, off.X, 0.5, off.Y)
		t.Size = if i <= 2 then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8)
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.BorderSizePixel = 0
		t.Visible = false
		t.Parent = centre
		ticks[i] = t
	end
	local aimBox = Instance.new("Frame")
	aimBox.Name = "AimBox"
	aimBox.BackgroundTransparency = 1
	aimBox.AnchorPoint = Vector2.new(0.5, 0)
	aimBox.Position = UDim2.new(0.5, 0, 0.5, 24)
	aimBox.Size = UDim2.fromOffset(0, 0)
	aimBox.AutomaticSize = Enum.AutomaticSize.XY
	local aimList = Instance.new("UIListLayout")
	aimList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	aimList.SortOrder = Enum.SortOrder.LayoutOrder
	aimList.Padding = UDim.new(0, 3)
	aimList.Parent = aimBox
	aimBox.Parent = centre
	local aimTitle = pill("AimTitle", aimBox, 18, 1)
	local aimHint = pill("AimHint", aimBox, 15, 2)
	local anchorLabel = pill("Anchor", aimBox, 14, 3)

	-- Everything else: inside the safe area.
	local safe = Instance.new("ScreenGui")
	safe.Name = "SpiderPrompts"
	safe.ResetOnSpawn = false
	safe.IgnoreGuiInset = false
	safe.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	safe.Parent = playerGui
	local top = column("Top", safe, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), Enum.VerticalAlignment.Top)
	local grip = Instance.new("Frame")
 grip.Name="GripBar";grip.Size=UDim2.new(.65,0,0,12);grip.LayoutOrder=0;grip.BackgroundColor3=Color3.fromRGB(45,12,12);grip.Visible=false;grip.Parent=top
 local gripFill=Instance.new("Frame");gripFill.Name="Grip";gripFill.Size=UDim2.fromScale(.4,1);gripFill.BackgroundColor3=Color3.fromRGB(245,35,38);gripFill.BorderSizePixel=0;gripFill.Parent=grip
 local status = wrapLabel("Status", top, 16, 1)
	-- The spider-eye view's explanation, the first time (ROBLOX-20): right under the status lines, in the column, so it never covers
	-- the aim words or the prompts. Shown from view.caption = { text, alpha }.
	local caption = wrapLabel("Caption", top, 15, 2)
	local toast = wrapLabel("Toast", top, 17, 3)
	local help = wrapLabel("Controls", top, 15, 4)
	help.TextXAlignment = Enum.TextXAlignment.Left
	local panel = Instance.new("Frame")
	panel.Name = "PromptPanel"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	local plist = Instance.new("UIListLayout")
	plist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	plist.VerticalAlignment = Enum.VerticalAlignment.Bottom
	plist.SortOrder = Enum.SortOrder.LayoutOrder
	plist.Padding = UDim.new(0, 4)
	plist.Parent = panel
	panel.Parent = safe
	local promptTitle = wrapLabel("PromptTitle", panel, 17, 1)
	promptTitle.Font = Enum.Font.GothamBold
	local promptHint = wrapLabel("PromptHint", panel, 16, 2)
	local promptCue = wrapLabel("PromptCue", panel, 16, 3)
	promptCue.TextColor3 = WARN_COLOR
	local self = setmetatable({
		grip = grip, gripFill = gripFill, centre = centre, safe = safe, reticle = reticle, ticks = ticks,
		aimTitle = aimTitle, aimHint = aimHint, anchorLabel = anchorLabel,
		status = status, caption = caption, toastLabel = toast, help = help,
		panel = panel, promptTitle = promptTitle, promptHint = promptHint, promptCue = promptCue,
		toastLeft = 0, device = "keyboard", lastSpan = "",
	}, Hud)
	return self
end

function Hud.toast(self: any, text: string, warn: boolean?)
	if text == "" then return end
	self.toastLabel.Text = text
	self.toastLabel.TextColor3 = if warn then WARN_COLOR else OK_COLOR
	self.toastLabel.Visible = true
	self.toastLeft = TOAST_SECONDS
end

local function show(label: TextLabel, text: string?)
	local t = text or ""
	if label.Text ~= t then label.Text = t end
	label.Visible = t ~= ""
end

-- Places the prompt panel for the safe area's size and the device (HudLayout.promptSpan).
function Hud._place(self: any)
	local size = self.safe.AbsoluteSize
	local x0, x1, bottom = HudLayout.promptSpan(size.X, size.Y, self.device)
	local key = string.format("%.1f,%.1f,%.1f", x0, x1, bottom)
	if key == self.lastSpan then return end
	self.lastSpan = key
	-- Anchored to the safe area's bottom edge (scale 1), so the panel's gap above the bottom holds even if the reported size
	-- and the children's origin disagree about an inset.
	self.panel.Position = UDim2.new(0, x0, 1, bottom - size.Y)
	self.panel.Size = UDim2.fromOffset(math.max(x1 - x0, 0), 0)
end

-- view: device, aiming, focus, eyeView, aimTitle, aimHint, aimColor, anchorText, anchorOk, status ({string}),
-- caption ({text, alpha} or nil), prompt ({title, hint, cue} or nil), helpVisible, helpText.
function Hud.update(self: any, view: any, dt: number)
	self.grip.Visible = view.grip ~= nil
 if view.grip then self.gripFill.Size = UDim2.fromScale(math.clamp(view.grip,0,1),1) end
 self.device = view.device
	self:_place()
	self.reticle.Visible = view.aiming or view.focus or view.eyeView
	for _, t in self.ticks do t.Visible = view.focus == true end
	show(self.aimTitle, view.aimTitle)
	if view.aimColor then self.aimTitle.TextColor3 = view.aimColor end
	show(self.aimHint, view.aimHint)
	show(self.anchorLabel, view.anchorText)
	self.anchorLabel.TextColor3 = if view.anchorOk then OK_COLOR else WARN_COLOR
	show(self.status, table.concat(view.status or {}, "\n"))
	local caption = view.caption
	if caption then
		if self.caption.Text ~= caption.text then self.caption.Text = caption.text end
		self.caption.TextTransparency = 1 - caption.alpha
		self.caption.BackgroundTransparency = 1 - 0.6 * caption.alpha
		self.caption.Visible = true
	else
		self.caption.Visible = false
	end
	local prompt = view.prompt
	show(self.promptTitle, if prompt then prompt.title else nil)
	show(self.promptHint, if prompt then prompt.hint else nil)
	show(self.promptCue, if prompt then prompt.cue else nil)
	if view.helpVisible then show(self.help, view.helpText) else show(self.help, nil) end
	if self.toastLeft > 0 then
		self.toastLeft -= dt
		if self.toastLeft <= 0 then self.toastLabel.Visible = false end
	end
end

return Hud
