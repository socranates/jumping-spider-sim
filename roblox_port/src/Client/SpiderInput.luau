--!strict
-- One action path for keyboard, gamepad and held on-screen touch buttons.
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local InputState = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Movement"):WaitForChild("InputState"))
local SpiderInput = {}

function SpiderInput.bind(jump: (string) -> (), reset: () -> (), gait: () -> (), silkAction: (string,string) -> ())
	local state = InputState.new()
	local function act(action: string, phase: Enum.UserInputState)
		local down = phase == Enum.UserInputState.Begin
		if action == "Jump" then
			if down then jump("begin") elseif phase == Enum.UserInputState.End then jump("end") else jump("cancel") end
		elseif action=="Drop" or action=="Release" then
			state:set(action,down)
			silkAction(action,if down then "begin" elseif phase==Enum.UserInputState.End then "end" else "cancel")
		elseif action == "Reset" then if down then reset() end
		elseif action == "Gait" then if down then gait() end
		else state:set(action, down) end
	end
	local bindings = {
		Forward = {Enum.KeyCode.W, Enum.KeyCode.DPadUp}, Back = {Enum.KeyCode.S, Enum.KeyCode.DPadDown},
		Left = {Enum.KeyCode.A, Enum.KeyCode.DPadLeft}, Right = {Enum.KeyCode.D, Enum.KeyCode.DPadRight},
		Jump = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA}, Creep = {Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1},
		Drop={Enum.KeyCode.F,Enum.KeyCode.ButtonX}, Release={Enum.KeyCode.Q,Enum.KeyCode.ButtonB},
		Reset = {Enum.KeyCode.R, Enum.KeyCode.ButtonY}, Gait = {Enum.KeyCode.G},
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
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiderTouch"
	gui.ResetOnSpawn = false
	gui.Enabled = UIS.TouchEnabled
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local active: {[InputObject]: string} = {}
	local function clear()
		state:clear()
		table.clear(active)
		jump("cancel")
		silkAction("Release","clear")
	end
	local function button(action: string, label: string, position: UDim2, size: number)
		local b = Instance.new("TextButton")
		b.Name = action
		b.Text = label
		b.TextSize = 18
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
	button("Drop", "Silk", UDim2.new(1,-86,1,-242),60)
	button("Release", "Let go\n(hold)", UDim2.new(1,-156,1,-242),60)
	UIS.InputEnded:Connect(function(input)
		local action = active[input]
		if action then active[input] = nil; act(action, Enum.UserInputState.End) end
	end)
	UIS.WindowFocusReleased:Connect(clear)
	UIS.TextBoxFocused:Connect(clear)
	UIS.GamepadDisconnected:Connect(clear)
	UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(function() gui.Enabled = UIS.TouchEnabled end)
	return state
end
return SpiderInput
