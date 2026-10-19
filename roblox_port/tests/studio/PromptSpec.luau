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
	local TarantulaText = require(Shared.UI.TarantulaText)
	local InspectText = require(Shared.UI.InspectText)
	local MateText = require(Shared.UI.MateText)
	local LifeText = require(Shared.UI.LifeText)
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
	check("the controls card fits a phone's width in landscape for every device, every display key and both pad styles, in at most ten lines (the very string the HUD shows)", function()
		for _, style in { "xbox", "playstation" } do
			ControlText.setPadStyle(style :: any)
			for _, device in devices do
				for _, kind in { "none", "dance", "antennae", "threat" } do -- the first spider, with the peacock spider's lines, with the ant mimic's and with the tarantulas'
					-- (ROBLOX-92: this measured ControlText.helpCard .. helpExtra, which was not what the screen showed once the close look's line was added; PeacockText.card is the screen's string)
					local card = PeacockText.card(device, if kind == "none" then nil else kind)
					local s = size(card, 15, 568 - 32 - 20)
					assert(s.Y <= 10 * 15 * 1.35, `{device}: the card ({kind}, {style}) needs {s.Y} px`)
				end
			end
		end
		ControlText.setPadStyle("xbox")
	end)
	-- Every word a touch button can carry (the labels the client sets each frame: Grip for a struggle, Skip in the mating scene, Back and View in the close look, Rest, Sleep, Leave and Wake
	-- on the feed button, the three display keys' words), by action: the layout's own label first.
	local function labelsFor(b: HudLayout.Button): { string }
		local labels = { b.label }
		if b.action == "Cancel" then labels = { ControlText.touchCancelLabel(false), ControlText.touchCancelLabel(true), InspectText.TOUCH_BACK } end
		if b.action == "Display" then labels = { b.label, PeacockText.touchDisplay(true), AntMimicText.touchDisplay(false), AntMimicText.touchDisplay(true), TarantulaText.touchDisplay(false), TarantulaText.touchDisplay(true) } end
		if b.action == "Jump" then labels = { b.label, "Grip", MateText.TOUCH_SKIP } end
		if b.action == "Feed" then
			labels = { b.label, "Grip", "Eat" }
			for _, st in { { true, true, false, false }, { false, true, false, false }, { false, false, true, true }, { false, false, true, false } } do
				local word = LifeText.touchLabel(st[1], st[2], st[3], st[4]) -- (Wake, Leave, Sleep, Rest)
				if word ~= nil then table.insert(labels, word) end
			end
		end
		if b.action == "Eye" then labels = { b.label, InspectText.TOUCH_VIEW } end
		if b.action == "Choose" then labels = { b.label, PeacockText.touchChange() } end
		return labels
	end
	check("touch buttons' words fit their buttons, the relabels too (Rear up, Grip, Back, View, Leave, Sleep, Wake, Skip)", function()
		local seen: { [string]: boolean } = {}
		for _, b in HudLayout.TOUCH_BUTTONS do
			for _, label in labelsFor(b) do
				seen[label] = true
				local s = size(label, b.textSize or 18, b.size - 6)
				assert(s.X <= b.size - 6 + 0.5 and s.Y <= b.size - 6, `{b.action}: "{label}" is {s.X}x{s.Y} in {b.size}`)
			end
		end
		for _, word in { "Rear up", "Grip", "Back", "View", "Leave", "Sleep", "Wake", "Skip" } do
			assert(seen[word], `("{word}" is a word the spec measures)`)
		end
	end)
	check("compact landscape touch labels fit and the prompt stays on screen (480 x 320 and 640 x 360 too), the relabels included", function()
		for _, wh in { Vector2.new(480, 320), Vector2.new(568, 320), Vector2.new(640, 360), Vector2.new(667, 375), Vector2.new(844, 390) } do
			local _, _, bottom = HudLayout.promptSpan(wh.X, wh.Y, "touch")
			assert(bottom >= 120, `{wh.X}x{wh.Y}: the prompt top would be off screen`)
			for _, spec in HudLayout.TOUCH_BUTTONS do
				local b = HudLayout.layoutButton(spec, wh.X, wh.Y)
				for _, label in labelsFor(spec) do
					local text = size(label, b.textSize or 18, b.size - 6)
					assert(text.X <= b.size - 6 + .5 and text.Y <= b.size - 6, `{wh.X}x{wh.Y}: compact {b.action} "{label}" does not fit ({text.X}x{text.Y} in {b.size})`)
				end
			end
			-- the top buttons keep their words too (the narrower pair of a short, narrow screen)
			local t = HudLayout.topLayout(wh.X, wh.Y)
			local menu, book = size("Menu", 18, 1000), size("Notebook", 16, 1000)
			assert(menu.X <= t.menu.x1 - t.menu.x0 - 8 and book.X <= t.notebook.x1 - t.notebook.x0 - 8, `{wh.X}x{wh.Y}: Menu is {menu.X}, Notebook {book.X} in ({t.menu.x1 - t.menu.x0}, {t.notebook.x1 - t.notebook.x0})`)
		end
	end)
end
