--!strict
-- The screen after the wasp has carried the spider off (Godot's scripts/presentation/caught_panel.gd, LIFE rounds 4 and 5; LIFE-01 "death
-- can be real and jarring, not sensationalized"): the world goes quiet and dim for a moment, one plain line says what happened, then a
-- short summary of the life and one way on: back to the last rest (the checkpoint), or the start when there is none. No gore, no score.
-- The game waits while it is up (the client skips its ticks) and it takes the keys and buttons first, so a press of Space, E or A is
-- the choice and never a jump. The words and timing are Shared/UI/WaspText and Data/Wasp. A mouse or a finger presses the button; a
-- controller selects it (GuiService.SelectedObject) so A presses it. Not ported: "Continue as another spider" and the notebook.
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaspText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("WaspText"))

local CaughtPanel = {}
CaughtPanel.__index = CaughtPanel

local ACTION = "WaspCaughtChoice"
-- The keys and buttons that choose (Godot: ui_accept, interact, prepare_jump).
local KEYS: { any } = { Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA }

local function label(parent: Instance, name: string, size: number, order: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextWrapped = true
	l.TextStrokeTransparency = 0.4
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

-- `onChoose` is called once when the player chooses; the client puts the world back and calls `hide`.
function CaughtPanel.new(playerGui: Instance, onChoose: () -> ()): any
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderCaught"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = playerGui
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0.02, 0.02, 0.03)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true -- takes the mouse
	dim.Parent = gui
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(0.9, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(880, 10000)
	constraint.Parent = box
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 14)
	list.Parent = box
	box.Parent = dim
	local text = Color3.new(0.95, 0.93, 0.88)
	local line = label(box, "Line", 28, 1, text)
	local sub = label(box, "Sub", 18, 2, Color3.new(0.8, 0.79, 0.74))
	local summary = label(box, "Summary", 18, 3, Color3.new(0.88, 0.86, 0.8))
	local button = Instance.new("TextButton")
	button.Name = "Back"
	button.BackgroundColor3 = Color3.new(0.16, 0.16, 0.18)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 20
	button.AutoButtonColor = true
	button.Selectable = true
	button.Size = UDim2.fromOffset(320, 48)
	button.LayoutOrder = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = box
	local self = setmetatable({
		gui = gui, dim = dim, line = line, sub = sub, summary = summary, button = button, onChoose = onChoose,
		showing = false, seconds = 0.0, bound = false, chosen = false,
	}, CaughtPanel)
	button.Activated:Connect(function() self:choose() end)
	return self
end

function CaughtPanel.isShowing(self: any): boolean
	return self.showing
end

-- The catch screen begins: `summary` is WaspText.summary's text, `hasRest` whether there is a rest to go back to.
function CaughtPanel.show(self: any, summary: string, hasRest: boolean)
	self.showing, self.seconds, self.chosen = true, 0.0, false
	self.line.Text, self.sub.Text, self.summary.Text = WaspText.LINE, WaspText.SUB, summary
	self.button.Text = WaspText.choice(hasRest)
	self.gui.Enabled = true
	self:_apply()
	if not self.bound then
		self.bound = true
		-- Above the game's own bindings (3000): Space, E and A choose here and never jump or eat.
		CAS:BindActionAtPriority(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then self:choose() end
			return Enum.ContextActionResult.Sink
		end, false, 4000, table.unpack(KEYS))
	end
	pcall(function()
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end)
end

function CaughtPanel.hide(self: any)
	self.showing = false
	self.gui.Enabled = false
	if self.bound then
		self.bound = false
		pcall(function() CAS:UnbindAction(ACTION) end)
	end
	pcall(function() GuiService.SelectedObject = nil end)
end

-- Presses the button, if the choices are up and nothing has been chosen yet (a key, A, a click, a tap, and the tests all come here).
function CaughtPanel.choose(self: any): boolean
	if not self.showing or self.chosen or not WaspText.panel(self.seconds).choices then return false end
	self.chosen = true
	self.onChoose()
	return true
end

function CaughtPanel._apply(self: any)
	local stage = WaspText.panel(self.seconds)
	self.dim.BackgroundTransparency = 1 - stage.dim
	self.line.Visible = stage.line
	self.sub.Visible = stage.line
	self.summary.Visible = stage.choices and self.summary.Text ~= ""
	self.button.Visible = stage.choices
end

-- Real seconds, not game seconds: the screen does not wait for itself.
function CaughtPanel.update(self: any, dt: number)
	if not self.showing then return end
	local before = WaspText.panel(self.seconds).choices
	self.seconds += dt
	self:_apply()
	if not before and WaspText.panel(self.seconds).choices then
		pcall(function() GuiService.SelectedObject = self.button end)
	end
end

return CaughtPanel
