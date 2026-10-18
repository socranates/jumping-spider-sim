--!strict
-- The settings on screen (ROBLOX-49): a list of sections (Sound, Camera, Comfort and accessibility, Help and hints), each setting a row with
-- its control (a toggle's On/Off button, a slider's bar with - and +, a choice's arrows), then Reset to defaults and Back. It is modal
-- like the notebook and the life menu: while it is open the world waits (the client's render step stops the fixed ticks) and it owns the
-- input (a Context Action above the game's bindings) so nothing it uses reaches the spider. The panel holds no values: it asks
-- `io.get(id)` and tells `io.set(id, value)` (the client keeps them as Player attributes, where every consumer reads them live).
-- Keyboard: Up and Down choose a row, Left and Right change it (hold to run a slider), Enter or Space switches, PageUp and PageDown go from
-- section to section, O or Q or Backspace go back. Controller: stick or D-pad choose and change, A (Cross) switches, LB and RB (L1 and R1)
-- jump sections, the right stick scrolls, B (Circle) goes back. Mouse and touch: tap a row to switch it, - and + or drag a bar, scroll the list.
-- Large text (the LargeText setting) takes effect at once, here too; short screens lose the controls line before the list loses room.
-- Words and sizes are Shared/UI/SettingsText and Data/SettingsSpec; movement through the rows is Shared/UI/SettingsNav.
local TextService = game:GetService("TextService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local ControlText = require(UI:WaitForChild("ControlText"))
local SettingsModel = require(UI:WaitForChild("SettingsModel"))
local SettingsNav = require(UI:WaitForChild("SettingsNav"))
local SettingsText = require(UI:WaitForChild("SettingsText"))
local SettingsSpec = require(Shared:WaitForChild("Data"):WaitForChild("SettingsSpec"))

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

export type Io = {
	get: (string) -> SettingsModel.Value, -- the setting's clean value (or its default)
	set: (string, SettingsModel.Value) -> (), -- the player's change: the client keeps it and everything reads it live
	reset: () -> (), -- every setting back to its default
	status: () -> string?, -- "saved" | "saving" | "session" | nil (not known yet)
}

local PRIORITY = 4000 -- above the game's bindings (3000) and level with the notebook's and the life menu's
local ACTION = "WindowsillSettings"
local INK = Color3.new(0.95, 0.93, 0.88)
local FAINT = Color3.new(0.68, 0.70, 0.76)
local PAPER = Color3.new(0.09, 0.10, 0.12)
local ROW = Color3.new(0.15, 0.16, 0.19)
local PICK = Color3.new(0.24, 0.29, 0.38)
local BUTTON = Color3.new(0.22, 0.24, 0.29)
local BUTTON_PICK = Color3.new(0.34, 0.42, 0.56)
local ACCENT = Color3.new(0.62, 0.82, 0.66)
local KEYS = {
	Enum.KeyCode.Q, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace, Enum.KeyCode.O,
	Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
	Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.PageUp, Enum.KeyCode.PageDown,
	Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2,
}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function text(class: string, name: string, parent: Instance, bold: boolean?): any
	local l: any = Instance.new(class)
	l.Name = name
	l.Text = ""
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextColor3 = INK
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

local function pressable(name: string, label: string, parent: Instance): any
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = label
	b.Font = Enum.Font.GothamMedium
	b.TextColor3 = INK
	b.BackgroundColor3 = BUTTON
	b.AutoButtonColor = true
	b.Selectable = false
	b.TextWrapped = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function measure(label: string, size: number, width: number): number
	local ok, v = pcall(function(): Vector2 return TextService:GetTextSize(label, size, Enum.Font.GothamMedium, Vector2.new(math.max(1, width), 100000)) end)
	if ok then return math.ceil(v.Y) end
	return math.ceil(size * 1.25)
end

-- `io` is the client's side (Io); `onClose(returnTo)` is called when the panel closes, with what open() was given.
function SettingsPanel.new(playerGui: Instance, io: Io, onClose: (string?) -> ()): any
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderSettings"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 56
	gui.Enabled = false
	gui.Parent = playerGui
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0.02, 0.02, 0.03)
	dim.BackgroundTransparency = 0.2
	dim.BorderSizePixel = 0
	dim.Active = true
	dim.Parent = gui
	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.fromScale(0.97, 0.95)
	paper.BackgroundColor3 = PAPER
	paper.BorderSizePixel = 0
	paper.Parent = dim
	corner(paper, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(SettingsText.MAX_PANEL.w, SettingsText.MAX_PANEL.h)
	limit.Parent = paper
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(14, 10)
	inner.Size = UDim2.new(1, -28, 1, -20)
	inner.Parent = paper
	local heading = text("TextLabel", "Heading", inner, true)
	heading.Text = SettingsSpec.WORDS.title
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = SettingsText.SCROLLBAR - 2
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = inner
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local hint = text("TextLabel", "Controls", inner)
	hint.TextColor3 = FAINT
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Parent = inner
	local resetButton = pressable("Reset", SettingsSpec.WORDS.reset, footer)
	local backButton = pressable("Back", SettingsSpec.WORDS.close, footer)

	local self = setmetatable({
		gui = gui, paper = paper, heading = heading, list = list, hint = hint, footer = footer, resetButton = resetButton, backButton = backButton,
		io = io, onClose = onClose, nav = SettingsNav.new(), widgets = {} :: { any }, status = nil :: any,
		showing = false, bound = false, returnTo = nil :: string?, device = "keyboard" :: ControlText.Device, scale = 1.0,
		confirming = false, stickDown = false, stickSide = false, scrollAxis = 0.0, repeatDir = 0, repeatT = 0.0, drag = nil :: any,
		rowTop = {} :: { number }, rowHeight = {} :: { number }, message = "",
	}, SettingsPanel)
	self:_build()
	resetButton.Activated:Connect(function() self.nav:select(#self.nav.rows - 1); self:_activate() end)
	backButton.Activated:Connect(function() self.nav:select(#self.nav.rows); self:_activate() end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	UIS.InputChanged:Connect(function(input: InputObject)
		local d = self.drag
		if d ~= nil and self.showing and (input == d.input or input.UserInputType == Enum.UserInputType.MouseMovement) then
			self:_dragTo(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input: InputObject)
		local d = self.drag
		if d ~= nil and (input == d.input or (d.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			self.drag = nil
			self.list.ScrollingEnabled = true
		end
	end)
	return self
end

-- ---------------------------------------------------------------- building
function SettingsPanel._build(self: any)
	local status = text("TextLabel", "Status", self.list)
	status.TextColor3 = FAINT
	status.LayoutOrder = 0
	self.status = status
	for i, row in self.nav.rows do
		if row.kind == "header" then
			local h = text("TextLabel", "Header_" .. tostring(row.id), self.list, true)
			h.Text = row.title or ""
			h.TextColor3 = ACCENT
			h.LayoutOrder = i
			self.widgets[i] = { kind = "header", frame = h }
		elseif row.kind == "setting" then
			self.widgets[i] = self:_buildRow(i, row.id :: string)
		end
	end
end

function SettingsPanel._buildRow(self: any, index: number, id: string): any
	local spec = SettingsModel.spec(id) :: SettingsSpec.Setting
	local frame = Instance.new("TextButton")
	frame.Name = "Row_" .. id
	frame.Text = ""
	frame.AutoButtonColor = false
	frame.Selectable = false
	frame.BackgroundColor3 = ROW
	frame.BorderSizePixel = 0
	frame.LayoutOrder = index
	frame.Parent = self.list
	corner(frame, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = frame
	local w: any = { kind = "setting", id = id, spec = spec, frame = frame, stroke = stroke }
	w.label = text("TextLabel", "Label", frame)
	w.label.Text = spec.label
	w.note = text("TextLabel", "Note", frame)
	w.note.Text = spec.note or ""
	w.note.TextColor3 = FAINT
	w.note.Visible = spec.note ~= nil
	local function pick() self:_pickRow(index) end
	if spec.kind == "toggle" then
		w.value = pressable("Value", "", frame)
		w.value.Activated:Connect(function() pick(); self:_change(id, 1) end)
	elseif spec.kind == "choice" then
		w.prev = pressable("Prev", "<", frame)
		w.next = pressable("Next", ">", frame)
		w.value = pressable("Value", "", frame)
		w.prev.Activated:Connect(function() pick(); self:_change(id, -1) end)
		w.next.Activated:Connect(function() pick(); self:_change(id, 1) end)
		w.value.Activated:Connect(function() pick(); self:_change(id, 1) end)
	else
		w.minus = pressable("Minus", "-", frame)
		w.plus = pressable("Plus", "+", frame)
		w.value = text("TextLabel", "Value", frame)
		w.value.TextXAlignment = Enum.TextXAlignment.Center
		local bar = Instance.new("Frame") -- the hit area: as tall as a button, so a finger finds it
		bar.Name = "Bar"
		bar.BackgroundTransparency = 1
		bar.Active = true
		bar.Parent = frame
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.fromScale(0, 0.5)
		track.BackgroundColor3 = BUTTON
		track.BorderSizePixel = 0
		track.Parent = bar
		corner(track, 6)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = track
		corner(fill, 6)
		w.bar, w.track, w.fill = bar, track, fill
		w.minus.Activated:Connect(function() pick(); self:_change(id, -1) end)
		w.plus.Activated:Connect(function() pick(); self:_change(id, 1) end)
		bar.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pick()
				self.drag = { id = id, input = input, bar = bar }
				self.list.ScrollingEnabled = false
				self:_dragTo(input.Position.X)
			end
		end)
	end
	frame.Activated:Connect(function()
		pick()
		if spec.kind ~= "slider" then self:_change(id, 1) end
	end)
	return w
end

-- ---------------------------------------------------------------- values
function SettingsPanel._pickRow(self: any, index: number)
	if self.nav:select(index) then
		self.confirming = false
		self:_paint()
	end
end

-- One setting's widgets from its value now.
function SettingsPanel.refreshRow(self: any, id: string)
	local w
	for _, x in self.widgets do
		if x.kind == "setting" and x.id == id then w = x end
	end
	if w == nil then return end
	local value = self.io.get(id)
	local spec: SettingsSpec.Setting = w.spec
	w.value.Text = SettingsModel.valueText(id, value)
	if spec.kind == "toggle" then
		w.value.BackgroundColor3 = if value == true then BUTTON_PICK else BUTTON
	elseif spec.kind == "slider" then
		w.fill.Size = UDim2.fromScale(SettingsModel.fraction(id, value), 1)
		w.minus.TextTransparency = if SettingsModel.fraction(id, value) <= 0 then 0.6 else 0
		w.plus.TextTransparency = if SettingsModel.fraction(id, value) >= 1 then 0.6 else 0
	end
end

-- Every row, and the line about saving, from the values now (opening; saved settings arriving while it is open).
function SettingsPanel.refresh(self: any)
	for _, w in self.widgets do
		if w.kind == "setting" then self:refreshRow(w.id) end
	end
	self:_statusLine()
	if self.showing then self:layout() end
end

function SettingsPanel._statusLine(self: any)
	local line = self.message
	if line == "" then
		local s = self.io.status()
		if s == "session" then line = SettingsSpec.WORDS.sessionLine elseif s ~= nil then line = SettingsSpec.WORDS.savedLine end
	end
	self.status.Text = line
end

local function largeNow(self: any): boolean
	return self.io.get("LargeText") == true
end

-- The player's change to one setting: kept, shown, and (large text) the panel itself grows or shrinks at once.
function SettingsPanel._apply(self: any, id: string, value: SettingsModel.Value)
	self.io.set(id, value)
	self.message = ""
	self.confirming = false
	self:refreshRow(id)
	self:_statusLine()
	if id == "LargeText" then
		self.scale = SettingsText.scale(largeNow(self))
		self:layout()
	end
	self:_paint()
end

function SettingsPanel._change(self: any, id: string, dir: number)
	self:_apply(id, SettingsModel.step(id, self.io.get(id), dir))
end

function SettingsPanel._dragTo(self: any, x: number)
	local d = self.drag
	if d == nil then return end
	local bar: GuiObject = d.bar
	local frac = (x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X)
	local v = SettingsModel.fromFraction(d.id, frac)
	if v ~= nil and v ~= self.io.get(d.id) then self:_apply(d.id, v) end
end

-- ---------------------------------------------------------------- drawing
function SettingsPanel._screen(self: any): (number, number)
	local size = self.gui.AbsoluteSize
	return if size.X > 0 then size.X else 1280, if size.Y > 0 then size.Y else 720
end

function SettingsPanel.isShowing(self: any): boolean
	return self.showing
end

-- Highlights the chosen row or footer button.
function SettingsPanel._paint(self: any)
	local at = self.nav.at
	for i, w in self.widgets do
		if w.kind == "setting" then
			local on = i == at
			w.frame.BackgroundColor3 = if on then PICK else ROW
			w.stroke.Enabled = on
		end
	end
	local rows = #self.nav.rows
	self.resetButton.BackgroundColor3 = if at == rows - 1 then BUTTON_PICK else BUTTON
	self.backButton.BackgroundColor3 = if at == rows then BUTTON_PICK else BUTTON
	self.resetButton.Text = if self.confirming then SettingsSpec.WORDS.resetSure else SettingsSpec.WORDS.reset
end

-- Sizes and positions for the screen's size and the text scale. A row's height comes from its measured label and note.
function SettingsPanel.layout(self: any)
	local s: number = self.scale
	local sizes = SettingsText.SIZES
	local w, h = self:_screen()
	local m = SettingsText.metrics(w, h, s)
	local pad = SettingsText.PAD * s
	local gap = SettingsText.GAP * s
	local target = math.floor(SettingsText.MIN_TARGET * s)
	self.heading.Size = UDim2.new(1, 0, 0, m.head)
	self.heading.TextSize = math.round(sizes.heading * s)
	self.list.Position = UDim2.fromOffset(0, m.head + 4)
	self.list.Size = UDim2.new(1, 0, 0, m.body)
	self.hint.Visible = m.hint > 0
	self.hint.Position = UDim2.fromOffset(0, m.head + 4 + m.body + 4)
	self.hint.Size = UDim2.new(1, 0, 0, m.hint)
	self.hint.TextSize = math.round(sizes.controls * s)
	self.hint.Text = SettingsText.controls(self.device)
	self.footer.Position = UDim2.fromScale(0, 1)
	self.footer.Size = UDim2.new(1, 0, 0, m.foot)
	local bw = math.floor(math.min(260 * s, (m.paperW - 28 - 16) / 2))
	local btext = math.round(sizes.button * s)
	self.resetButton.Position, self.resetButton.Size, self.resetButton.TextSize = UDim2.fromOffset(0, 4), UDim2.new(0, bw, 1, -8), math.min(btext, math.max(10, math.floor(bw / 8)))
	self.backButton.Position, self.backButton.Size, self.backButton.TextSize = UDim2.new(1, -bw, 0, 4), UDim2.new(0, bw, 1, -8), btext
	local statusH = measure(self.status.Text ~= "" and self.status.Text or " ", math.round(sizes.note * s), m.bodyW)
	self.status.TextSize = math.round(sizes.note * s)
	self.status.Size = UDim2.new(1, -SettingsText.SCROLLBAR, 0, statusH + 4)
	local y = statusH + 4 + 6
	for i, wd in self.widgets do
		if wd.kind == "header" then
			local hh = math.ceil(sizes.section * s * 1.3) + math.floor(8 * s)
			wd.frame.TextSize = math.round(sizes.section * s)
			wd.frame.Size = UDim2.new(1, -SettingsText.SCROLLBAR, 0, hh)
			self.rowTop[i], self.rowHeight[i] = y, hh
			y += hh + 6
		else
			local kind: string = wd.spec.kind
			local rl = SettingsText.rowLayout(m.bodyW, kind, s)
			local labelSize, noteSize = math.round(sizes.label * s), math.round(sizes.note * s)
			local labelH = measure(wd.label.Text, labelSize, rl.labelW)
			local noteH = if wd.spec.note ~= nil then measure(wd.note.Text, noteSize, rl.labelW) else 0
			local rowH = SettingsText.rowHeight(rl, labelH, noteH, s)
			wd.frame.Size = UDim2.new(1, -SettingsText.SCROLLBAR, 0, rowH)
			local textH = labelH + (if noteH > 0 then noteH + 2 else 0)
			local ty = if rl.stacked then pad else math.floor((rowH - textH) / 2)
			wd.label.TextSize, wd.note.TextSize = labelSize, noteSize
			wd.label.Position, wd.label.Size = UDim2.fromOffset(pad, ty), UDim2.fromOffset(rl.labelW, labelH)
			wd.note.Position, wd.note.Size = UDim2.fromOffset(pad, ty + labelH + 2), UDim2.fromOffset(rl.labelW, noteH)
			local cw = rl.controlW
			local cx = if rl.stacked then pad else m.bodyW - pad - cw
			local cy = if rl.stacked then rowH - pad - target else math.floor((rowH - target) / 2)
			local vtext = math.round(sizes.value * s)
			if kind == "toggle" then
				wd.value.Position, wd.value.Size, wd.value.TextSize = UDim2.fromOffset(cx, cy), UDim2.fromOffset(cw, target), vtext
			elseif kind == "choice" then
				wd.prev.Position, wd.prev.Size, wd.prev.TextSize = UDim2.fromOffset(cx, cy), UDim2.fromOffset(target, target), btext
				wd.next.Position, wd.next.Size, wd.next.TextSize = UDim2.fromOffset(cx + cw - target, cy), UDim2.fromOffset(target, target), btext
				wd.value.Position, wd.value.Size, wd.value.TextSize = UDim2.fromOffset(cx + target + gap, cy), UDim2.fromOffset(cw - 2 * target - 2 * gap, target), vtext
			else
				local vw = math.floor(SettingsText.VALUE_WIDTH * s)
				wd.minus.Position, wd.minus.Size, wd.minus.TextSize = UDim2.fromOffset(cx, cy), UDim2.fromOffset(target, target), btext
				wd.plus.Position, wd.plus.Size, wd.plus.TextSize = UDim2.fromOffset(cx + cw - target, cy), UDim2.fromOffset(target, target), btext
				local barW
				if rl.valueTop then -- the number on the label's line, the bar between - and + underneath
					wd.value.Position, wd.value.Size, wd.value.TextSize = UDim2.fromOffset(cx + cw - vw, ty), UDim2.fromOffset(vw, math.max(labelH, math.floor(target * 0.6))), vtext
					barW = cw - 2 * target - 2 * gap
				else
					wd.value.Position, wd.value.Size, wd.value.TextSize = UDim2.fromOffset(cx + cw - target - gap - vw, cy), UDim2.fromOffset(vw, target), vtext
					barW = cw - 2 * target - vw - 3 * gap
				end
				wd.bar.Position, wd.bar.Size = UDim2.fromOffset(cx + target + gap, cy), UDim2.fromOffset(barW, target)
				wd.track.Size = UDim2.new(1, 0, 0, math.max(8, math.floor(10 * s)))
			end
			self.rowTop[i], self.rowHeight[i] = y, rowH
			y += rowH + 6
		end
	end
	self:_paint()
end

-- Scrolls the chosen row into view (the footer's buttons are always in view).
function SettingsPanel._reveal(self: any)
	local at = self.nav.at
	local top, hgt = self.rowTop[at], self.rowHeight[at]
	if top == nil or hgt == nil then
		return
	end
	local view = self.list.AbsoluteSize.Y
	if view <= 0 then
		local _, h = self:_screen()
		view = SettingsText.metrics(1, h, self.scale).body
	end
	local at0 = self.list.CanvasPosition.Y
	local goal = at0
	if top < at0 then goal = top - 6 elseif top + hgt > at0 + view then goal = top + hgt - view + 6 end
	-- the first row shows the line above it
	if at == 2 then goal = 0 end
	self.list.CanvasPosition = Vector2.new(0, math.max(0, goal))
end

-- ---------------------------------------------------------------- opening, closing
-- Opens at the first setting. `returnTo` comes back to onClose; `device` names the controls; `scale` is the text scale (1 or the large factor).
function SettingsPanel.open(self: any, returnTo: string?, device: ControlText.Device, scale: number)
	self.returnTo, self.device, self.scale = returnTo, device, math.clamp(scale, 1, SettingsText.LARGE)
	self.showing = true
	self.message, self.confirming = "", false
	self.stickDown, self.stickSide, self.scrollAxis, self.repeatDir, self.repeatT, self.drag = false, false, 0, 0, 0, nil
	self.list.ScrollingEnabled = true
	self.nav:first()
	self.gui.Enabled = true
	self:refresh()
	self:layout()
	self.list.CanvasPosition = Vector2.zero
	self:_reveal()
	if not self.bound then
		self.bound = true
		CAS:BindActionAtPriority(ACTION, function(_, state, input)
			if GuiService.MenuIsOpen then self.scrollAxis = 0; self.repeatDir = 0; return Enum.ContextActionResult.Pass end
			self:_input(state, input)
			return Enum.ContextActionResult.Sink
		end, false, PRIORITY, table.unpack(KEYS))
	end
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true end)
	pcall(function() GuiService.SelectedObject = nil end)
end

function SettingsPanel.close(self: any)
	if not self.showing then return end
	self.showing = false
	self.gui.Enabled = false
	self.drag, self.repeatDir, self.confirming = nil, 0, false
	self.list.ScrollingEnabled = true
	if self.bound then
		self.bound = false
		CAS:UnbindAction(ACTION)
	end
	pcall(function() GuiService.SelectedObject = nil end)
	local to = self.returnTo
	self.returnTo = nil
	self.onClose(to)
end

-- The controls change with the device in use.
function SettingsPanel.setDevice(self: any, device: ControlText.Device)
	if device == self.device then return end
	self.device = device
	if self.showing then self:layout() end
end

-- ---------------------------------------------------------------- input
-- Enter, Space, E, A on the chosen row: switch a toggle, step a choice on, reset (twice), go back.
function SettingsPanel._activate(self: any)
	local row = self.nav:current()
	if row.kind == "setting" then
		local spec = SettingsModel.spec(row.id :: string) :: SettingsSpec.Setting
		if spec.kind ~= "slider" then self:_change(row.id :: string, 1) end
	elseif row.kind == "reset" then
		if not self.confirming then
			self.confirming = true
			self:_paint()
		else
			self.confirming = false
			self.io.reset()
			self.message = SettingsSpec.WORDS.resetDone
			self.scale = SettingsText.scale(largeNow(self))
			self:refresh()
			self:layout()
		end
	elseif row.kind == "back" then
		self:close()
	end
end

function SettingsPanel._vertical(self: any, dir: number)
	self.nav:move(dir)
	self.confirming = false
	self:_paint()
	self:_reveal()
end

-- Left and Right: change the chosen setting, or move between the footer's two buttons.
function SettingsPanel._horizontal(self: any, dir: number)
	local row = self.nav:current()
	if row.kind == "setting" then
		self:_change(row.id :: string, dir)
	elseif row.kind == "reset" or row.kind == "back" then
		self.nav:select(#self.nav.rows - (if dir < 0 then 1 else 0))
		self.confirming = false
		self:_paint()
	end
end

function SettingsPanel._section(self: any, dir: number)
	self.nav:section(dir)
	self.confirming = false
	self:_paint()
	self:_reveal()
end

function SettingsPanel.scrollBy(self: any, pixels: number)
	local p: ScrollingFrame = self.list
	local max = math.max(p.AbsoluteCanvasSize.Y - p.AbsoluteSize.Y, 0)
	p.CanvasPosition = Vector2.new(0, math.clamp(p.CanvasPosition.Y + pixels, 0, max))
end

local function sideOf(k: Enum.KeyCode): number
	if k == Enum.KeyCode.Left or k == Enum.KeyCode.A or k == Enum.KeyCode.DPadLeft then return -1 end
	if k == Enum.KeyCode.Right or k == Enum.KeyCode.D or k == Enum.KeyCode.DPadRight then return 1 end
	return 0
end

-- One input the Context Action got.
function SettingsPanel._input(self: any, state: Enum.UserInputState, input: InputObject?)
	local k = if input then input.KeyCode else nil
	if k == Enum.KeyCode.Thumbstick2 then
		local y = if input and state ~= Enum.UserInputState.Cancel then input.Position.Y else 0
		self.scrollAxis = if math.abs(y) < 0.25 then 0 else -y -- stick up scrolls up
		return
	end
	if k == Enum.KeyCode.Thumbstick1 then
		local x = if input and state ~= Enum.UserInputState.Cancel then input.Position.X else 0
		local y = if input and state ~= Enum.UserInputState.Cancel then input.Position.Y else 0
		if math.abs(y) < 0.3 then
			self.stickDown = false
		elseif math.abs(y) > 0.6 and not self.stickDown then
			self.stickDown = true
			self:_vertical(if y > 0 then -1 else 1)
		end
		if math.abs(x) < 0.3 then
			if self.stickSide then self.stickSide, self.repeatDir = false, 0 end
		elseif math.abs(x) > 0.6 and not self.stickSide then
			self.stickSide = true
			local dir = if x > 0 then 1 else -1
			self:_horizontal(dir)
			self.repeatDir, self.repeatT = dir, -SettingsText.REPEAT_DELAY
		end
		return
	end
	if k == nil then return end
	local side = sideOf(k)
	if side ~= 0 then
		if state == Enum.UserInputState.Begin then
			self:_horizontal(side)
			self.repeatDir, self.repeatT = side, -SettingsText.REPEAT_DELAY
		elseif self.repeatDir == side then
			self.repeatDir = 0
		end
		return
	end
	if state ~= Enum.UserInputState.Begin then return end
	if k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Backspace or k == Enum.KeyCode.O then
		self:close()
	elseif k == Enum.KeyCode.Up or k == Enum.KeyCode.W or k == Enum.KeyCode.DPadUp then
		self:_vertical(-1)
	elseif k == Enum.KeyCode.Down or k == Enum.KeyCode.S or k == Enum.KeyCode.DPadDown then
		self:_vertical(1)
	elseif k == Enum.KeyCode.ButtonL1 or k == Enum.KeyCode.PageUp then
		self:_section(-1)
	elseif k == Enum.KeyCode.ButtonR1 or k == Enum.KeyCode.PageDown then
		self:_section(1)
	else -- Return, Space, E, A
		self:_activate()
	end
end

-- Each rendered frame while open: the right stick scrolls the list; a held Left or Right runs a slider.
function SettingsPanel.update(self: any, dt: number)
	if not self.showing or GuiService.MenuIsOpen then return end
	if self.scrollAxis ~= 0 then
		self:scrollBy(self.scrollAxis * SettingsText.SCROLL_PX_S * math.min(dt, 0.1))
	end
	if self.repeatDir ~= 0 then
		local row = self.nav:current()
		local spec = if row.kind == "setting" then SettingsModel.spec(row.id :: string) else nil
		if spec ~= nil and spec.kind == "slider" then
			self.repeatT += math.min(dt, 0.1)
			while self.repeatT >= SettingsText.REPEAT_RATE do
				self.repeatT -= SettingsText.REPEAT_RATE
				self:_change(row.id :: string, self.repeatDir)
			end
		end
	end
end

return SettingsPanel
