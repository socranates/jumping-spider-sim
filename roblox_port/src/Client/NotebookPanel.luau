--!strict
-- The naturalist's notebook on screen (ROBLOX-37), from Godot's notebook_panel.gd: the pages found so far on the left, in the order they
-- were found, and the page on the right: a few true sentences, "In this game:" where the game simplifies, and the sources with their
-- links as text. No count of pages left to find (spec 4). On a small or narrow screen, or with large text, one pane shows at a time:
-- the pages, then the page, with a Pages button to go back (Shared/UI/NotebookText.layout). It is modal like the life menu: while it is
-- open the world waits (the client's render step stops the fixed ticks), and it owns the input (a Context Action at a priority above the
-- game's bindings) so nothing it uses reaches the spider. Keyboard: Up and Down choose a page, Left and Right go to the previous or next
-- page, Enter opens (one pane), PageUp and PageDown scroll, N or Q closes. Controller: stick or D-pad choose, A opens, LB and RB go to the
-- previous or next page, the right stick scrolls, B goes back or closes. Mouse and touch: tap a page, drag or use the wheel to scroll.
-- The client opens it (N, the Notebook button, or from the life menu or the end screen) and is told when it closes.
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local ControlText = require(UI:WaitForChild("ControlText"))
local NotebookText = require(UI:WaitForChild("NotebookText"))

local NotebookPanel = {}
NotebookPanel.__index = NotebookPanel

local PAPER = Color3.new(0.93, 0.90, 0.82)
local PAPER_DARK = Color3.new(0.84, 0.79, 0.68)
local PAPER_LIT = Color3.new(0.99, 0.95, 0.80)
local BORDER = Color3.new(0.45, 0.38, 0.28)
local INK = Color3.new(0.20, 0.16, 0.10)
local BODY = Color3.new(0.15, 0.13, 0.10)
local GREEN = Color3.new(0.18, 0.32, 0.22)
local FAINT = Color3.new(0.35, 0.30, 0.24)
local PRIORITY = 4000 -- above the game's bindings (3000) and level with the life menu's
local SCROLL_PX_S = 520 -- right stick: pixels a second at full tilt
local STEP_PX = 120 -- a key press that scrolls
local ACTION = "WindowsillNotebook"
local KEYS = {
	Enum.KeyCode.N, Enum.KeyCode.Q, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace,
	Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
	Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.PageUp, Enum.KeyCode.PageDown,
	Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2,
}

local function label(parent: Instance, name: string, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Size = UDim2.new(1, -14, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

local function scroller(parent: Instance, name: string, padding: number): ScrollingFrame
	local f = Instance.new("ScrollingFrame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ScrollBarThickness = 6
	f.CanvasSize = UDim2.new()
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.ScrollingDirection = Enum.ScrollingDirection.Y
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding)
	list.Parent = f
	f.Parent = parent
	return f
end

local function button(parent: Instance, name: string, text: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextColor3 = INK
	b.BackgroundColor3 = PAPER_DARK
	b.AutoButtonColor = true
	b.Selectable = false
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	return b
end

-- `book` is the FieldNotebook; `onClose(returnTo)` is called when the panel closes, with what open() was given.
function NotebookPanel.new(playerGui: Instance, book: any, onClose: (string?) -> ()): any
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderNotebook"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 55
	gui.Enabled = false
	gui.Parent = playerGui
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0.02, 0.02, 0.03)
	dim.BackgroundTransparency = 0.35
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
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = paper
	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER
	stroke.Thickness = 2
	stroke.Parent = paper
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1040, 820)
	limit.Parent = paper
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(14, 10)
	inner.Size = UDim2.new(1, -28, 1, -20)
	inner.Parent = paper
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextColor3 = INK
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = NotebookText.HEADING
	heading.Parent = inner
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Parent = inner
	local list = scroller(body, "Pages", 6)
	local page = scroller(body, "Page", 12)
	local title = label(page, "Title", 1)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = INK
	local text = label(page, "Text", 2)
	text.TextColor3 = BODY
	local game = label(page, "InThisGame", 3)
	game.TextColor3 = GREEN
	local sources = label(page, "Sources", 4)
	sources.TextColor3 = FAINT
	local empty = label(page, "Empty", 5)
	empty.TextColor3 = FAINT
	empty.Text = NotebookText.EMPTY
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Parent = inner
	local controls = Instance.new("TextLabel")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.Font = Enum.Font.Gotham
	controls.TextColor3 = FAINT
	controls.TextWrapped = true
	controls.TextXAlignment = Enum.TextXAlignment.Left
	controls.TextYAlignment = Enum.TextYAlignment.Center
	controls.Parent = footer
	local close = button(footer, "Close", NotebookText.CLOSE)
	local back = button(footer, "Back", NotebookText.PAGES)
	back.Visible = false
	local self = setmetatable({
		gui = gui, paper = paper, heading = heading, body = body, list = list, page = page, title = title, text = text, game = game,
		sources = sources, empty = empty, footer = footer, controls = controls, closeButton = close, backButton = back,
		book = book, onClose = onClose,
		showing = false, bound = false, returnTo = nil :: string?, device = "keyboard" :: ControlText.Device, scale = 1.0,
		view = "list", shown = "", buttons = {} :: { TextButton }, ids = {} :: { string },
		stickDown = false, scrollAxis = 0.0,
	}, NotebookPanel)
	close.Activated:Connect(function() self:close() end)
	back.Activated:Connect(function() self:back() end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	return self
end

function NotebookPanel.isShowing(self: any): boolean
	return self.showing
end

-- Whether one pane shows at a time (a small screen, or large text).
function NotebookPanel.stacked(self: any): boolean
	local size = self.gui.AbsoluteSize
	return not NotebookText.layout(size.X, size.Y, self.scale).sideBySide
end

-- Sizes, positions and which pane shows, for the screen's size, the text scale and the view.
function NotebookPanel.layout(self: any)
	local s: number = self.scale
	local sizes = NotebookText.SIZES
	local size = self.gui.AbsoluteSize
	local lay = NotebookText.layout(size.X, size.Y, s)
	local head, foot = math.floor((sizes.heading + 10) * s), math.floor(58 * s)
	self.heading.Size = UDim2.new(1, 0, 0, head)
	self.heading.TextSize = sizes.heading * s
	self.body.Position = UDim2.fromOffset(0, head + 4)
	self.body.Size = UDim2.new(1, 0, 1, -(head + foot + 12))
	self.footer.Position = UDim2.fromScale(0, 1)
	self.footer.Size = UDim2.new(1, 0, 0, foot)
	local buttonW = math.floor(112 * s)
	local backShown = not lay.sideBySide and self.view == "page"
	self.closeButton.Size = UDim2.new(0, buttonW, 1, -8)
	self.closeButton.Position = UDim2.new(1, -buttonW, 0, 4)
	self.closeButton.TextSize = sizes.button * s
	self.backButton.Visible = backShown
	self.backButton.Size = UDim2.new(0, buttonW, 1, -8)
	self.backButton.Position = UDim2.new(1, -(buttonW * 2 + 8), 0, 4)
	self.backButton.TextSize = sizes.button * s
	local reserve = buttonW * (if backShown then 2 else 1) + 16
	self.controls.Size = UDim2.new(1, -reserve, 1, 0)
	self.controls.TextSize = sizes.controls * s
	self.controls.Text = NotebookText.controls(self.device, not lay.sideBySide)
	if lay.sideBySide then
		self.list.Position, self.list.Size = UDim2.fromOffset(0, 0), UDim2.new(lay.listFraction, -8, 1, 0)
		self.page.Position, self.page.Size = UDim2.new(lay.listFraction, 8, 0, 0), UDim2.new(1 - lay.listFraction, -8, 1, 0)
		self.list.Visible, self.page.Visible = true, true
	else
		self.list.Position, self.list.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
		self.page.Position, self.page.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
		self.list.Visible, self.page.Visible = self.view == "list", self.view == "page"
	end
	self.title.TextSize = sizes.title * s
	self.text.TextSize = sizes.body * s
	self.game.TextSize = sizes.game * s
	self.sources.TextSize = sizes.sources * s
	self.empty.TextSize = sizes.body * s
	for _, b in self.buttons do
		b.TextSize = sizes.button * s
		b.Size = UDim2.new(1, -10, 0, math.floor(NotebookText.MIN_TARGET * s))
	end
end

-- The list of found pages, in the order they were found.
function NotebookPanel._rebuildList(self: any)
	for _, b in self.buttons do b:Destroy() end
	self.buttons, self.ids = {}, {}
	for i, entry in self.book:list() do
		local b = button(self.list, "Page_" .. entry.id, entry.title)
		b.LayoutOrder = i
		b.Selectable = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextWrapped = true
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 6)
		pad.Parent = b
		local id = entry.id
		b.Activated:Connect(function() self:choose(id) end)
		table.insert(self.buttons, b)
		table.insert(self.ids, id)
	end
end

-- Shows one found page on the right (nothing about a page that is not found: view() gives nil for it).
function NotebookPanel.showPage(self: any, id: string)
	local p = if id ~= "" then self.book:view(id) else nil
	self.shown = if p then id else ""
	self.empty.Visible = p == nil
	self.title.Visible, self.text.Visible, self.sources.Visible = p ~= nil, p ~= nil, p ~= nil
	local gameLine = if p then NotebookText.gameLine(p.game, self.device) else nil
	self.game.Visible = gameLine ~= nil
	if p then
		self.title.Text, self.text.Text = p.title, p.text
		self.game.Text = gameLine or ""
		self.sources.Text = NotebookText.sourcesText(p.sources)
	end
	self.page.CanvasPosition = Vector2.zero
	for i, b in self.buttons do
		local on = self.ids[i] == self.shown
		b.BackgroundColor3 = if on then PAPER_LIT else PAPER_DARK
		if on and self.device == "gamepad" and self.view == "list" then pcall(function() GuiService.SelectedObject = b end) end
	end
end

-- Opens the notebook at its newest page. `returnTo` comes back to onClose; `device` names the controls; `scale` is the text scale.
function NotebookPanel.open(self: any, returnTo: string?, device: ControlText.Device, scale: number)
	self.returnTo, self.device, self.scale = returnTo, device, math.clamp(scale, 1, NotebookText.LARGE)
	self.showing = true
	self.stickDown, self.scrollAxis = false, 0
	self.gui.Enabled = true
	self:_rebuildList()
	self.view = "page"
	self:layout()
	self:showPage(self.book:newest() or "")
	if #self.ids > 0 and not self:stacked() then self.view = "list" end
	self:layout()
	if not self.bound then
		self.bound = true
		CAS:BindActionAtPriority(ACTION, function(_, state, input)
			self:_input(state, input)
			return Enum.ContextActionResult.Sink
		end, false, PRIORITY, table.unpack(KEYS))
	end
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true end)
end

-- A page opened while the book is open (the list grows; the page on show stays).
function NotebookPanel.refresh(self: any)
	if not self.showing then return end
	local keep = self.shown
	self:_rebuildList()
	self:layout()
	self:showPage(keep)
end

function NotebookPanel.close(self: any)
	if not self.showing then return end
	self.showing = false
	self.gui.Enabled = false
	if self.bound then
		self.bound = false
		CAS:UnbindAction(ACTION)
	end
	pcall(function() GuiService.SelectedObject = nil end)
	local to = self.returnTo
	self.returnTo = nil
	self.onClose(to)
end

-- Chooses a page: it shows on the right; with one pane it takes the whole panel.
function NotebookPanel.choose(self: any, id: string)
	self:showPage(id)
	if self:stacked() then
		self.view = "page"
		pcall(function() GuiService.SelectedObject = nil end)
	end
	self:layout()
end

-- Back from a page to the list when one pane shows; otherwise close.
function NotebookPanel.back(self: any)
	if self:stacked() and self.view == "page" then
		self.view = "list"
		self:layout()
		self:showPage(self.shown)
	else
		self:close()
	end
end

-- Moves the chosen page by `delta` in the list (wraps neither way).
function NotebookPanel.step(self: any, delta: number)
	local n = #self.ids
	if n == 0 then return end
	local at = table.find(self.ids, self.shown) or 1
	local to = math.clamp(at + delta, 1, n)
	self:showPage(self.ids[to])
	if self.device == "gamepad" and self.view == "list" then pcall(function() GuiService.SelectedObject = self.buttons[to] end) end
end

function NotebookPanel.scrollBy(self: any, pixels: number)
	local p: ScrollingFrame = self.page
	local max = math.max(p.AbsoluteCanvasSize.Y - p.AbsoluteSize.Y, 0)
	p.CanvasPosition = Vector2.new(0, math.clamp(p.CanvasPosition.Y + pixels, 0, math.max(max, 0)))
end

-- One input the Context Action got.
function NotebookPanel._input(self: any, state: Enum.UserInputState, input: InputObject?)
	local k = if input then input.KeyCode else nil
	if k == Enum.KeyCode.Thumbstick2 then
		local y = if input and state ~= Enum.UserInputState.Cancel then input.Position.Y else 0
		self.scrollAxis = if math.abs(y) < 0.25 then 0 else -y -- stick up scrolls up the page
		return
	end
	if k == Enum.KeyCode.Thumbstick1 then
		local y = if input and state ~= Enum.UserInputState.Cancel then input.Position.Y else 0
		if math.abs(y) < 0.3 then
			self.stickDown = false
		elseif math.abs(y) > 0.6 and not self.stickDown then
			self.stickDown = true
			self:_vertical(if y > 0 then -1 else 1)
		end
		return
	end
	if state ~= Enum.UserInputState.Begin then return end
	if k == Enum.KeyCode.N then
		self:close()
	elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Backspace then
		self:back()
	elseif k == Enum.KeyCode.Up or k == Enum.KeyCode.W or k == Enum.KeyCode.DPadUp then
		self:_vertical(-1)
	elseif k == Enum.KeyCode.Down or k == Enum.KeyCode.S or k == Enum.KeyCode.DPadDown then
		self:_vertical(1)
	elseif k == Enum.KeyCode.Left or k == Enum.KeyCode.A or k == Enum.KeyCode.DPadLeft or k == Enum.KeyCode.ButtonL1 then
		self:step(-1)
	elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.D or k == Enum.KeyCode.DPadRight or k == Enum.KeyCode.ButtonR1 then
		self:step(1)
	elseif k == Enum.KeyCode.PageUp then
		self:scrollBy(-self.page.AbsoluteSize.Y * 0.8)
	elseif k == Enum.KeyCode.PageDown then
		self:scrollBy(self.page.AbsoluteSize.Y * 0.8)
	else -- Return, Space, E, A: open the chosen page (one pane), or nothing to do (two panes)
		if self:stacked() and self.view == "list" and self.shown ~= "" then self:choose(self.shown) end
	end
end

-- Up and Down: choose a page in the list, or scroll the page when it has the whole panel.
function NotebookPanel._vertical(self: any, dir: number)
	if self:stacked() and self.view == "page" then
		self:scrollBy(dir * STEP_PX)
	else
		self:step(dir)
	end
end

-- Each rendered frame while open: the right stick scrolls the page.
function NotebookPanel.update(self: any, dt: number)
	if self.showing and self.scrollAxis ~= 0 then
		self:scrollBy(self.scrollAxis * SCROLL_PX_S * math.min(dt, 0.1))
	end
end

-- The controls change with the device in use (a controller picked up while the book is open).
function NotebookPanel.setDevice(self: any, device: ControlText.Device)
	if device == self.device then return end
	self.device = device
	if self.showing then
		self:layout()
		self:showPage(self.shown)
	end
end

return NotebookPanel
