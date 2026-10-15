--!strict
-- One action path for keyboard, mouse, gamepad and held on-screen touch buttons, all at once.
-- Bindings follow the frozen Godot game's scripts/core/input_setup.gd wherever the action exists in the port:
--   walk WASD / left stick (D-pad too), look mouse / arrow keys / right stick / touch drag, creep Shift / LB,
--   jump Space / A (tap hop, hold aim, release leap), cancel Q / B (cancels an aim or a walk to the edge; held on the
--   line it lets go), focus right mouse / LT, spider-eye view V / Y, recenter R / middle mouse / right-stick click,
--   slow motion T / RT, lower on silk F / X (Godot: F / D-pad down; the port keeps the D-pad for walking, ROBLOX-05).
--   Esc / Menu open Roblox's own menu: the game drops every press and hold and waits (Godot's pause).
-- Port-only: reset to the start Backspace / View (Select), gait toggle G, controls card H (Godot's H is the field notes).
--
-- Every button action is held while any source holds it (InputState): a key, a controller button, a finger. Handlers hear
-- one "begin" when the first source goes down and one "end" when the last comes up, so a touch hold and a key or button
-- held at the same time never cancel each other.
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local InputState = require(Shared:WaitForChild("Movement"):WaitForChild("InputState"))
local HudLayout = require(Shared:WaitForChild("UI"):WaitForChild("HudLayout"))
local SpiderInput = {}

export type Handlers = {
	feed: (() -> ())?,
	focus: ((string) -> ())?,
	jump: (string) -> (), -- "begin", "end", or "cancel" (the engine took the input away)
	cancel: (string) -> (),
	drop: () -> (),
	clear: () -> (), -- focus loss, the Roblox menu, a text box, a lost controller
	reset: () -> (),
	gait: () -> (),
	eye: () -> (),
	recenter: () -> (),
	slow: () -> (),
	help: () -> (),
	touchLook: (Vector2) -> (),
	device: ((string) -> ())?, -- the last input's UserInputType name
}

local ONE_SHOT = { Reset = "reset", Gait = "gait", Eye = "eye", Recenter = "recenter", Slow = "slow", Help = "help" }

-- Bindings by action. Exported for tests and the controls table in README.md.
SpiderInput.BINDINGS = {
	Forward = { Enum.KeyCode.W, Enum.KeyCode.DPadUp }, Back = { Enum.KeyCode.S, Enum.KeyCode.DPadDown },
	Left = { Enum.KeyCode.A, Enum.KeyCode.DPadLeft }, Right = { Enum.KeyCode.D, Enum.KeyCode.DPadRight },
	LookLeft = { Enum.KeyCode.Left }, LookRight = { Enum.KeyCode.Right }, LookUp = { Enum.KeyCode.Up }, LookDown = { Enum.KeyCode.Down },
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }, Cancel = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
	Feed = { Enum.KeyCode.E, Enum.KeyCode.ButtonL3 },
	Drop = { Enum.KeyCode.F, Enum.KeyCode.ButtonX },
	Creep = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL1 },
	Focus = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Eye = { Enum.KeyCode.V, Enum.KeyCode.ButtonY },
	Recenter = { Enum.KeyCode.R, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3 },
	Slow = { Enum.KeyCode.T, Enum.KeyCode.ButtonR2 }, Help = { Enum.KeyCode.H },
	Reset = { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonSelect }, Gait = { Enum.KeyCode.G },
} :: { [string]: { any } }

local function sourceOf(input: InputObject?): any
	if input == nil then return "default" end
	local t = input.UserInputType
	if t == Enum.UserInputType.Touch then return input end -- each finger is its own source
	if t == Enum.UserInputType.Keyboard or string.sub(t.Name, 1, 7) == "Gamepad" then return input.KeyCode end
	return t -- a mouse button
end

function SpiderInput.bind(h: Handlers)
	local state = InputState.new()
	local handlers: { [string]: any } = h :: any
	-- One source of one action went down (down) or up; "cancel" means the engine took the input away (treated as up).
	local function act(action: string, down: boolean, source: any, cancelled: boolean?)
		local was, now = state:set(action, down, source)
		if was == now then return end
		if action == "Jump" then
			h.jump(if now then "begin" elseif cancelled then "cancel" else "end")
		elseif action == "Cancel" then
			h.cancel(if now then "begin" else "end")
		elseif action == "Focus" then
			if h.focus then h.focus(if now then "begin" elseif cancelled then "cancel" else "end") end
		elseif action == "Feed" then
			if now and h.feed then h.feed() end
		elseif action == "Drop" then
			if now then h.drop() end
		elseif ONE_SHOT[action] then
			if now then handlers[ONE_SHOT[action]]() end
		end
	end
	for action, keys in SpiderInput.BINDINGS do
		CAS:BindActionAtPriority("Spider" .. action, function(_, phase, input)
			if UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			if phase == Enum.UserInputState.Begin then
				act(action, true, sourceOf(input))
			elseif phase == Enum.UserInputState.End or phase == Enum.UserInputState.Cancel then
				act(action, false, sourceOf(input), phase == Enum.UserInputState.Cancel)
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, table.unpack(keys))
	end
	CAS:BindActionAtPriority("SpiderStick", function(_, phase, input)
		if phase == Enum.UserInputState.Cancel or UIS:GetFocusedTextBox() then state:stick(0, 0)
		else state:stick(input.Position.X, input.Position.Y) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Thumbstick1)
	CAS:BindActionAtPriority("SpiderLookStick", function(_, phase, input)
		if phase == Enum.UserInputState.Cancel or UIS:GetFocusedTextBox() then state:look(0, 0)
		else state:look(input.Position.X, input.Position.Y) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Thumbstick2)

	-- Roblox's own touch thumbstick and jump button would sit under ours: this game has its own touch controls.
	pcall(function() GuiService.TouchControlsEnabled = false end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderTouch"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of notches, the home bar and Roblox's top bar
	gui.Enabled = UIS.TouchEnabled
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local active: { [InputObject]: string } = {}
	local buttons: { [string]: TextButton } = {}
	local function clear()
		state:clear()
		table.clear(active)
		h.clear()
	end
	local function button(action: string, label: string, position: UDim2, size: number, textSize: number?)
		local b = Instance.new("TextButton")
		b.Name = action
		b.Text = label
		b.TextSize = textSize or 18
		b.TextWrapped = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.new(0.06, 0.06, 0.06)
		b.BackgroundTransparency = 0.15
		b.Size = UDim2.fromOffset(size, size)
		b.Position = position
		b.AutoButtonColor = true
		b.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				active[input] = action
				act(action, true, input)
			end
		end)
		buttons[action] = b
	end
	-- Left thumb: walking. Right thumb: jump (largest, nearest the corner), cancel / let go beside it, then creep, silk,
	-- recenter and the eye view further in. Offsets from the safe area's bottom corners (HudLayout, checked in tests).
	for _, b in HudLayout.TOUCH_BUTTONS do
		button(b.action, b.label, if b.right then UDim2.new(1, b.x, 1, b.y) else UDim2.new(0, b.x, 1, b.y), b.size, b.textSize)
	end
	UIS.InputEnded:Connect(function(input)
		local action = active[input]
		if action then
			active[input] = nil
			act(action, false, input)
		end
	end)
	-- Touch look: a drag anywhere that is not on a button turns the view (Roblox marks button touches processed).
	UIS.TouchMoved:Connect(function(input, processed)
		if not processed and not active[input] then h.touchLook(Vector2.new(input.Delta.X, input.Delta.Y)) end
	end)
	UIS.WindowFocusReleased:Connect(clear)
	UIS.TextBoxFocused:Connect(clear)
	UIS.GamepadDisconnected:Connect(clear)
	GuiService.MenuOpened:Connect(clear)
	UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(function() gui.Enabled = UIS.TouchEnabled end)
	local deviceHandler = h.device
	if deviceHandler then
		UIS.LastInputTypeChanged:Connect(function(t: Enum.UserInputType) deviceHandler(t.Name) end)
	end

	-- The client relabels and shows/hides touch buttons with the state (the Cancel button is Let go on the line).
	local api: any = state
	function api.setTouchLabel(_self: any, action: string, text: string)
		local b = buttons[action]
		if b and b.Text ~= text then b.Text = text end
	end
	function api.setTouchVisible(_self: any, action: string, visible: boolean)
		local b = buttons[action]
		if b and b.Visible ~= visible then
			b.Visible = visible
			if not visible then
				for input, a in active do
					if a == action then
						active[input] = nil
						act(action, false, input)
					end
				end
			end
		end
	end
	api.touchGui = gui
	-- The test place's playback drives the same path a key, button or finger takes (tests/client/SilkPlayback.luau).
	function api.simulate(_self: any, action: string, down: boolean, source: any?)
		act(action, down, source or "playback")
	end
	return api
end
return SpiderInput
