--!strict
-- One action path for keyboard, mouse, gamepad and held on-screen touch buttons.
-- Bindings follow the frozen Godot game's scripts/core/input_setup.gd wherever the action exists in the port:
--   walk WASD / left stick (D-pad too), look mouse / arrow keys / right stick, creep Shift / LB,
--   jump Space / A (tap hop, hold aim, release leap), cancel Q / B (cancels an aim or a walk to the edge; held on the
--   line it lets go, ROBLOX-05), focus right mouse / LT, spider-eye view V / Y, recenter R / middle mouse / right-stick
--   click, slow motion T / RT, lower on silk F / X (Godot: F / D-pad down; the port keeps the D-pad for walking).
-- Port-only: reset to the start Backspace / View (Select), gait toggle G, controls card H (Godot's H is the field notes).
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local InputState = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Movement"):WaitForChild("InputState"))
local SpiderInput = {}

export type Handlers = {
	jump: (string) -> (),
	cancel: (string) -> (),
	drop: () -> (),
	clear: () -> (),
	reset: () -> (),
	gait: () -> (),
	eye: () -> (),
	recenter: () -> (),
	slow: () -> (),
	help: () -> (),
	touchLook: (Vector2) -> (),
}

local function phaseName(phase: Enum.UserInputState): string
	return if phase == Enum.UserInputState.Begin then "begin" elseif phase == Enum.UserInputState.End then "end" else "cancel"
end

function SpiderInput.bind(h: Handlers)
	local state = InputState.new()
	local function act(action: string, phase: Enum.UserInputState)
		local down = phase == Enum.UserInputState.Begin
		if action == "Jump" then
			h.jump(phaseName(phase))
		elseif action == "Cancel" then
			state:set(action, down)
			h.cancel(phaseName(phase))
		elseif action == "Drop" then
			state:set(action, down)
			if down then h.drop() end
		elseif action == "Reset" then if down then h.reset() end
		elseif action == "Gait" then if down then h.gait() end
		elseif action == "Eye" then if down then h.eye() end
		elseif action == "Recenter" then if down then h.recenter() end
		elseif action == "Slow" then if down then h.slow() end
		elseif action == "Help" then if down then h.help() end
		else state:set(action, down) end
	end
	local bindings: {[string]: {any}} = {
		Forward = {Enum.KeyCode.W, Enum.KeyCode.DPadUp}, Back = {Enum.KeyCode.S, Enum.KeyCode.DPadDown},
		Left = {Enum.KeyCode.A, Enum.KeyCode.DPadLeft}, Right = {Enum.KeyCode.D, Enum.KeyCode.DPadRight},
		LookLeft = {Enum.KeyCode.Left}, LookRight = {Enum.KeyCode.Right}, LookUp = {Enum.KeyCode.Up}, LookDown = {Enum.KeyCode.Down},
		Jump = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA}, Cancel = {Enum.KeyCode.Q, Enum.KeyCode.ButtonB},
		Drop = {Enum.KeyCode.F, Enum.KeyCode.ButtonX},
		Creep = {Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL1},
		Focus = {Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2},
		Eye = {Enum.KeyCode.V, Enum.KeyCode.ButtonY},
		Recenter = {Enum.KeyCode.R, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3},
		Slow = {Enum.KeyCode.T, Enum.KeyCode.ButtonR2}, Help = {Enum.KeyCode.H},
		Reset = {Enum.KeyCode.Backspace, Enum.KeyCode.ButtonSelect}, Gait = {Enum.KeyCode.G},
	}
	for action, keys in bindings do
		CAS:BindActionAtPriority("Spider" .. action, function(_, phase)
			if UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			act(action, phase)
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

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderTouch"
	gui.ResetOnSpawn = false
	gui.Enabled = UIS.TouchEnabled
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local active: {[InputObject]: string} = {}
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
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.new(0.06, 0.06, 0.06)
		b.BackgroundTransparency = 0.15
		b.Size = UDim2.fromOffset(size, size)
		b.Position = position
		b.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				active[input] = action
				act(action, Enum.UserInputState.Begin)
			end
		end)
	end
	button("Forward", "↑", UDim2.new(0, 78, 1, -188), 52)
	button("Left", "←", UDim2.new(0, 22, 1, -132), 52)
	button("Back", "↓", UDim2.new(0, 78, 1, -76), 52)
	button("Right", "→", UDim2.new(0, 134, 1, -132), 52)
	button("Jump", "Jump\n(hold)", UDim2.new(1, -92, 1, -102), 72)
	button("Creep", "Creep", UDim2.new(1, -86, 1, -172), 60)
	button("Drop", "Silk", UDim2.new(1, -86, 1, -242), 60)
	button("Cancel", "Cancel\nLet go", UDim2.new(1, -166, 1, -92), 60, 14)
	button("Eye", "Eye", UDim2.new(1, -156, 1, -242), 60)
	UIS.InputEnded:Connect(function(input)
		local action = active[input]
		if action then active[input] = nil; act(action, Enum.UserInputState.End) end
	end)
	-- Touch look: a drag anywhere that is not on a button turns the view (Roblox marks button touches processed).
	UIS.TouchMoved:Connect(function(input, processed)
		if not processed and not active[input] then h.touchLook(Vector2.new(input.Delta.X, input.Delta.Y)) end
	end)
	UIS.WindowFocusReleased:Connect(clear)
	UIS.TextBoxFocused:Connect(clear)
	UIS.GamepadDisconnected:Connect(clear)
	UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(function() gui.Enabled = UIS.TouchEnabled end)
	return state
end
return SpiderInput
