--!strict
-- One action path for keyboard, mouse, gamepad and held on-screen touch buttons, all at once.
-- Bindings follow the frozen Godot game's scripts/core/input_setup.gd wherever the action exists in the port:
--   walk WASD / left stick (D-pad too), look mouse / arrow keys / right stick / touch drag, run Shift / LT, creep Ctrl / LB / gentle stick,
--   jump Space / A (tap hop, hold aim, release leap), cancel Q / B (cancels an aim or a walk to the edge; held on the
--   line it lets go), focus right mouse / RT, spider-eye view V / Y, recenter R / middle mouse / right-stick click,
--   slow motion T, lower on silk F / X (Godot: F / D-pad down; the port keeps the D-pad for walking, ROBLOX-05).
--   Esc / Menu open Roblox's own menu: the game drops every press and hold and waits (Godot's pause).
-- Port-only: reset to the start Backspace / View (Select), gait toggle G, controls card H (Godot's H is the field notes).
-- The peacock spider (ROBLOX-31): C changes spider in the crack (RB / R1 on a controller, the touch Change button); X, or the same RB / R1
-- outside the crack, starts and stops the courtship dance (the touch Dance button).
-- Inspect mode (ROBLOX-90): the same C / RB / Change held for 0.6 s in the crack starts the close look (a tap changes spider when it is let go, as before); in the look,
-- Cancel (Q / B), the same button again or the touch Back leave, Eye (V / Y / the touch View) cycles the framings, the left stick or W and S zoom.
-- The naturalist's notebook (ROBLOX-37): N opens it. Godot's D-pad up is the port's walking, so a controller reaches it through the life
-- menu (View / Touchpad, then Notebook); touch has the Notebook button beside Menu (SpiderClient).
-- The settings (ROBLOX-49): O opens them; a controller and touch reach them through the life menu (then Settings).
-- The lock (ROBLOX-110): Recentre (R / middle mouse / right-stick click / the touch Recentre) locks onto what the spider sees, lets go of a lock, or with
-- nothing to lock recentres; touch also has a small Lock button by Jump (no key: Recentre is the keys' lock), shown while something can be locked.
-- Nathan's run/lock controls: L1 / LB holds creep and takes a contextual lock on press; R2 / RT holds Focus.
-- Run is held on Shift / L2 / the touch Run button; Ctrl creeps. A gentle left-stick push creeps too.
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
	blocked: (() -> boolean)?, menu: (() -> ())?,
	feed: (() -> ())?,
	choose: (() -> ())?, -- C: change spider (in the crack); held 0.6 s, the close look (ROBLOX-90)
	chooseEnd: ((boolean?) -> ())?, -- ... and the last source of it let go (ROBLOX-90: a tap changes spider when it is let go, a hold does not); true when it did not end by the player's hand (the touch button was hidden under the finger, the engine took the input away: ROBLOX-92, nothing is changed then)
	notebook: (() -> ())?, -- N: the naturalist's notebook
	settings: (() -> ())?, -- O: the settings (ROBLOX-49)
	display: (() -> ())?, -- X / RB: the peacock spider's courtship dance
	displayEnd: ((boolean?) -> ())?, -- ... and let go (RB in the crack is a controller's choose key, ROBLOX-90), cancelled as chooseEnd
	focus: ((string) -> ())?,
	jump: (string) -> (), -- "begin", "end", or "cancel" (the engine took the input away)
	cancel: (string) -> (),
	drop: () -> (),
	clear: () -> (), -- focus loss, the Roblox menu, a text box, a lost controller
	reset: () -> (),
	gait: () -> (),
	eye: () -> (),
	recenter: () -> (),
	recentre: (() -> ())?, -- (ROBLOX-115) a controller's right-stick click: recentre only, never a lock
	lock: (() -> ())?, -- the touch Lock button (ROBLOX-110), and a controller's L1 press
	slow: () -> (),
	help: () -> (),
	touchLook: (Vector2) -> (),
	device: ((string) -> ())?, -- the last input's UserInputType name
}

local ONE_SHOT = { Menu = "menu", Notebook = "notebook", Settings = "settings", Reset = "reset", Gait = "gait", Eye = "eye", Recenter = "recenter", Slow = "slow", Help = "help", Lock = "lock",
	PadRecenter = "recentre" }

-- Bindings by action. Exported for tests and the controls table in README.md.
SpiderInput.BINDINGS = {
	Forward = { Enum.KeyCode.W, Enum.KeyCode.DPadUp }, Back = { Enum.KeyCode.S, Enum.KeyCode.DPadDown },
	Left = { Enum.KeyCode.A, Enum.KeyCode.DPadLeft }, Right = { Enum.KeyCode.D, Enum.KeyCode.DPadRight },
	LookLeft = { Enum.KeyCode.Left }, LookRight = { Enum.KeyCode.Right }, LookUp = { Enum.KeyCode.Up }, LookDown = { Enum.KeyCode.Down },
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }, Cancel = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
	Feed = { Enum.KeyCode.E, Enum.KeyCode.ButtonL3 },
	Drop = { Enum.KeyCode.F, Enum.KeyCode.ButtonX },
	Creep = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL1 },
	Focus = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR2 },
	Run = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL2 },
	Eye = { Enum.KeyCode.V, Enum.KeyCode.ButtonY },
	Recenter = { Enum.KeyCode.R, Enum.UserInputType.MouseButton3 }, PadRecenter = { Enum.KeyCode.ButtonR3 }, -- (ROBLOX-115: R3 recentres only)
	Slow = { Enum.KeyCode.T }, Help = { Enum.KeyCode.H },
	Reset = { Enum.KeyCode.Backspace }, Menu = { Enum.KeyCode.M, Enum.KeyCode.ButtonSelect }, Gait = { Enum.KeyCode.G },
	Choose = { Enum.KeyCode.C }, Notebook = { Enum.KeyCode.N }, Settings = { Enum.KeyCode.O }, Display = { Enum.KeyCode.X, Enum.KeyCode.ButtonR1 },
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
		local blocked: boolean = if h.blocked then h.blocked() else false
		if down and blocked and action ~= tostring("Menu") then return end
		local hadSource = state.sources[action] ~= nil and state.sources[action][source] == true
		local was, now = state:set(action, down, source)
		-- L1 still locks when another source is already holding Creep; repeated Begin is not another press.
		if action == "Creep" and down and not hadSource and source == Enum.KeyCode.ButtonL1 and h.lock then h.lock() end
		if was == now then return end
		if action == "Jump" then
			h.jump(if now then "begin" elseif cancelled then "cancel" else "end")
		elseif action == "Cancel" then
			h.cancel(if now then "begin" else "end")
		elseif action == "Focus" then
			if h.focus then h.focus(if now then "begin" elseif cancelled then "cancel" else "end") end
		elseif action == "Feed" then
			if now and h.feed then h.feed() end
		elseif action == "Choose" then
			if now and h.choose then h.choose() elseif not now and h.chooseEnd then h.chooseEnd(cancelled == true) end
		elseif action == "Display" then
			if now and h.display then h.display() elseif not now and h.displayEnd then h.displayEnd(cancelled == true) end
		elseif action == "Drop" then
			if now then h.drop() end
		elseif ONE_SHOT[action] then
			local fn = if now then handlers[ONE_SHOT[action]] else nil
			if fn then fn() end
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
		if phase == Enum.UserInputState.Cancel or UIS:GetFocusedTextBox() or (h.blocked and h.blocked()) then state:stick(0, 0)
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
	-- The fingers that are down on the screen and not on a button, and whether a pinch is under way (ROBLOX-92): a pinch zooms the close look and must not also turn it.
	local free: { [InputObject]: boolean } = {}
	local freeCount, pinching = 0, false
	local function clear()
		state:clear()
		table.clear(active)
		table.clear(free)
		freeCount, pinching = 0, false
		h.clear()
	end
	local function button(action: string, label: string, position: UDim2, size: number, textSize: number?)
		local b = Instance.new("TextButton")
		b.Name = action
		b.Text = label
		b.TextSize = textSize or 18
		b.Font = Enum.Font.GothamMedium
		b.TextWrapped = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.new(0.06, 0.06, 0.06)
		b.BackgroundTransparency = 0.15
		b.Size = UDim2.fromOffset(size, size)
		b.Position = position
		b.AutoButtonColor = true
		b.Visible = action ~= "Run" and action ~= "Lock" -- The HUD reveals acquired abilities after their moults.
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
	local function layoutTouch()
		local size = gui.AbsoluteSize
		for _, spec in HudLayout.TOUCH_BUTTONS do
			local b = HudLayout.layoutButton(spec, size.X, size.Y)
			local control = buttons[b.action]
			control.Position = UDim2.new(if b.right then 1 else 0, b.x, 1, b.y)
			control.Size = UDim2.fromOffset(b.size, b.size)
			control.TextSize = b.textSize or 18
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTouch)
	layoutTouch()
	UIS.InputEnded:Connect(function(input)
		local action = active[input]
		if action then
			active[input] = nil
			act(action, false, input)
		end
	end)
	-- Touch look: a drag anywhere that is not on a button turns the view (Roblox marks button touches processed). Not while a pinch is under way or a second finger is down (ROBLOX-92:
	-- both fingers of a pinch are moving, and each would have turned the view as well as zooming it).
	UIS.TouchStarted:Connect(function(input, processed)
		if not processed and not active[input] and not free[input] then free[input] = true; freeCount += 1 end
	end)
	UIS.TouchEnded:Connect(function(input)
		if free[input] then free[input] = nil; freeCount -= 1 end
		if freeCount <= 0 then pinching = false end -- (a pinch that never said it ended)
	end)
	UIS.TouchPinch:Connect(function(_touches: any, _scale: number, _velocity: number, state2: Enum.UserInputState)
		pinching = state2 == Enum.UserInputState.Begin or state2 == Enum.UserInputState.Change
	end)
	UIS.TouchMoved:Connect(function(input, processed)
		if not processed and not active[input] and not pinching and freeCount <= 1 then h.touchLook(Vector2.new(input.Delta.X, input.Delta.Y)) end
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
						act(action, false, input, true) -- (a button hidden under a finger is a press that was taken away, not one let go: ROBLOX-92)
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
