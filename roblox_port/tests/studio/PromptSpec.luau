--!strict
-- Device-aware prompts with Roblox's own text metrics (TextService): every prompt the HUD can show wraps inside the
-- narrowest prompt panel HudLayout allows, and the touch buttons' words fit their buttons. The live panel's placement and
-- TextFits are checked in the real client by tests/client/SilkPlayback.luau.
return function(check: (string, () -> ()) -> ())
	local TextService = game:GetService("TextService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ControlText = require(Shared.UI.ControlText)
	local PeacockText = require(Shared.UI.PeacockText)
	local AntMimicText = require(Shared.UI.AntMimicText)
	local HudLayout = require(Shared.UI.HudLayout)
	local FONT = Enum.Font.GothamMedium
	local devices: { any } = { "keyboard", "gamepad", "touch" }
	local width = HudLayout.MIN_PROMPT_WIDTH - 20 -- the panel's narrowest span less the label's padding
	local function size(text: string, textSize: number, w: number): Vector2
		return TextService:GetTextSize(text, textSize, FONT, Vector2.new(w, 10000))
	end
	check("every device's prompts wrap inside the narrowest prompt panel in at most four lines", function()
		for _, device in devices do
			local title, hint, cue = ControlText.linePanel({ reeling = true, progress = 0, snagged = true, block = "" }, device)
			local texts = { title, hint, cue, ControlText.walkHint(device), ControlText.edgeWalkHint(device),
				ControlText.lineToast("dropped", "", false, true, device), ControlText.describe({ kind = "unreachable", reason = "no_launch" }, device) }
			for _, text in texts do
				local s = size(text, 17, width)
				assert(s.X <= width + 0.5, `{device}: "{text}" is {s.X} px wide in {width}`)
				assert(s.Y <= 4 * 17 * 1.35, `{device}: "{text}" needs {s.Y} px (over four lines)`)
			end
		end
	end)
	check("the controls card fits a phone's width in landscape for every device", function()
		for _, device in devices do
			for _, kind in { "dance", "antennae", "threat" } do -- with the peacock spider's two lines, with the ant mimic's and with the tarantulas'
				local s = size(ControlText.helpCard(device) .. PeacockText.helpExtra(device, kind), 15, 568 - 32 - 20)
				assert(s.Y <= 10 * 15 * 1.35, `{device}: the card ({kind}) needs {s.Y} px`)
			end
		end
	end)
	check("touch buttons' words fit their buttons", function()
		for _, b in HudLayout.TOUCH_BUTTONS do
			local labels = { b.label }
			if b.action == "Cancel" then labels = { ControlText.touchCancelLabel(false), ControlText.touchCancelLabel(true) } end
			if b.action == "Display" then labels = { b.label, PeacockText.touchDisplay(true), AntMimicText.touchDisplay(false), AntMimicText.touchDisplay(true) } end
			for _, label in labels do
				local s = size(label, b.textSize or 18, b.size - 6)
				assert(s.X <= b.size - 6 + 0.5 and s.Y <= b.size - 6, `{b.action}: "{label}" is {s.X}x{s.Y} in {b.size}`)
			end
		end
	end)
	check("compact landscape touch labels fit and the prompt stays on screen", function()
		for _, wh in { Vector2.new(568,320), Vector2.new(667,375), Vector2.new(844,390) } do
			local _, _, bottom = HudLayout.promptSpan(wh.X, wh.Y, "touch")
			assert(bottom >= 120, "prompt top would be off screen")
			for _, spec in HudLayout.TOUCH_BUTTONS do
				local b = HudLayout.layoutButton(spec, wh.X, wh.Y)
				local text = size(b.label, b.textSize or 18, b.size-6)
				assert(text.X <= b.size-6+.5 and text.Y <= b.size-6, `compact {b.action} does not fit`)
			end
		end
	end)
end
