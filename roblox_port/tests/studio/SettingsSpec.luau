--!strict
-- The settings in the engine (ROBLOX-49 to ROBLOX-52): the table through Roblox's own JSON, the saved envelope that carries it, every word
-- measured with TextService at the screens and text sizes the panel supports (labels, notes, values, the controls line, the buttons), and the
-- panel built with real property names. The pure rules, the navigation, the live consumers and the layout matrix are in tests/settings.luau
-- (SETTINGS). What a player sees and does on a phone, a tablet and a controller is the Studio checklist in docs/HANDOFF-roblox-settings.md.
return function(check: (string, () -> ()) -> ())
	local HttpService = game:GetService("HttpService")
	local TextService = game:GetService("TextService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local SettingsSpec = require(Shared.Data.SettingsSpec)
	local SettingsModel = require(Shared.UI.SettingsModel)
	local SettingsText = require(Shared.UI.SettingsText)
	local ControlText = require(Shared.UI.ControlText)
	local SaveProgress = require(Shared.Persistence.SaveProgress)
	local SaveEnvelope = require(Shared.Persistence.SaveEnvelope)
	local HudLayout = require(Shared.UI.HudLayout)
	local NotebookText = require(Shared.UI.NotebookText)
	local Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local SettingsPanel = require(Client:WaitForChild("SettingsPanel")) :: any
	local devices: { any } = { "keyboard", "gamepad", "touch" }
	local screens = { Vector2.new(568, 320), Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(360, 640), Vector2.new(390, 844), Vector2.new(768, 1024), Vector2.new(1024, 768), Vector2.new(1280, 720), Vector2.new(1920, 1080) }
	local scales = { 1.0, SettingsText.LARGE }
	local S = SettingsText.SIZES
	local function size(text: string, textSize: number, font: Enum.Font, width: number): Vector2
		return TextService:GetTextSize(text, math.round(textSize), font, Vector2.new(width, 100000))
	end

	check("settings: the table, its defaults and a full set of changes survive the engine's JSON and the saved envelope unchanged", function()
		assert(#SettingsSpec.LIST == 23, `{#SettingsSpec.LIST} settings`)
		local changed: { [string]: any } = {}
		for _, s in SettingsSpec.LIST do
			local v: any = s.default
			if s.kind == "toggle" then v = not (s.default :: boolean)
			elseif s.kind == "slider" then v = s.max
			else
				local opts: { SettingsSpec.Option } = s.options :: any
				v = opts[#opts].id
			end
			changed[s.id] = v
		end
		local round = HttpService:JSONDecode(HttpService:JSONEncode(changed))
		local problems, clean = SettingsModel.cleanAll(round)
		assert(#problems == 0, "problems after the round trip: " .. table.concat(problems, "; "))
		for id, v in changed do assert(clean[id] == v, `{id}: {clean[id]} is not {v}`) end
		local progress = SaveProgress.snapshot({ opened = { "bold_jumper" }, eye_seconds = 3 }, false, nil, changed)
		local problems2 = SaveProgress.sanitize(progress)
		assert(#problems2 == 0, "the progress was refused: " .. table.concat(problems2, "; "))
		local env = SaveEnvelope.make(SaveProgress.SPEC, progress, 3000, nil, { lock = { session = "S", beat = 3000 } })
		local back = HttpService:JSONDecode(HttpService:JSONEncode(env))
		local opened = SaveEnvelope.open(SaveProgress.SPEC, back)
		assert(opened.status == "ok", "the envelope did not open: " .. tostring(opened.status))
		local problems3, again = SettingsModel.cleanAll((opened.payload :: any).settings)
		assert(#problems3 == 0, "problems in the stored settings")
		for id, v in changed do assert(again[id] == v, `{id}: stored as {again[id]}, not {v}`) end
	end)

	check("settings: every label, note, value and button fits its place at every supported screen and both text sizes", function()
		for _, screen in screens do
			for _, scale in scales do
				local m = SettingsText.metrics(screen.X, screen.Y, scale)
				local pad = SettingsText.PAD * scale
				for _, s in SettingsSpec.LIST do
					local rl = SettingsText.rowLayout(m.bodyW, s.kind, scale)
					local label = size(s.label, S.label * scale, Enum.Font.GothamMedium, rl.labelW)
					assert(label.Y <= 5 * S.label * scale * 1.3, `{s.id} at {screen.X}x{screen.Y} x{scale}: the label is {label.Y} tall in {rl.labelW}`)
					if s.note then
						local note = size(s.note, S.note * scale, Enum.Font.GothamMedium, rl.labelW)
						assert(note.Y <= 6 * S.note * scale * 1.3, `{s.id}: the note is {note.Y} tall`)
					end
					-- the words of the value, widest first
					local words: { string } = {}
					if s.kind == "choice" then
						local opts: { SettingsSpec.Option } = s.options :: any
						for _, o in opts do table.insert(words, o.label) end
					elseif s.kind == "toggle" then
						words = { SettingsSpec.WORDS.on, SettingsSpec.WORDS.off }
					else
						for _, v in { s.min :: any, s.max :: any, s.default :: any } do table.insert(words, SettingsModel.valueText(s.id, v)) end
					end
					local room = if s.kind == "choice" then rl.controlW - 2 * math.floor(SettingsText.MIN_TARGET * scale) - 2 * SettingsText.GAP * scale
						elseif s.kind == "toggle" then rl.controlW else math.floor(SettingsText.VALUE_WIDTH * scale)
					for _, wd in words do
						local one = size(wd, S.value * scale, Enum.Font.GothamMedium, 100000)
						assert(one.X <= room - 6, `{s.id}: "{wd}" is {one.X} wide in {room} at {screen.X}x{screen.Y} x{scale}`)
					end
				end
				for _, device in devices do
					for _, pad2 in { "xbox", "playstation" } do
						ControlText.setPadStyle(pad2)
						-- (a keyboard on a phone-sized screen is not a case: the long keyboard line is for windows 700 px wide or more)
						if m.hint > 0 and (device ~= "keyboard" or screen.X >= 700) then
							local line = size(SettingsText.controls(device), S.controls * scale, Enum.Font.GothamMedium, m.bodyW)
							assert(line.Y <= m.hint, `the controls line is {line.Y} tall in {m.hint} ({device}, {pad2}, {screen.X}x{screen.Y} x{scale})`)
						end
					end
				end
				ControlText.setPadStyle("xbox")
				local bw = math.floor(math.min(260 * scale, (m.paperW - 28 - 16) / 2))
				for _, word in { SettingsSpec.WORDS.reset, SettingsSpec.WORDS.resetSure, SettingsSpec.WORDS.close } do
					-- (a button's word may wrap, and shrinks as far as it must: SettingsText.buttonTextSize, which the panel uses)
					local fit = SettingsText.buttonTextSize(word, bw, m.foot - 8, S.button * scale)
					local one = size(word, fit, Enum.Font.GothamMedium, bw - 10)
					assert(fit >= 12 and one.Y <= m.foot - 8, `"{word}" is {one.Y} tall at {fit} in a {m.foot - 8} button of {bw} (screen {screen.X}x{screen.Y} x{scale})`)
				end
				assert(pad > 0)
			end
		end
	end)

	check("settings: the Menu and Notebook buttons' words fit them at their sizes", function()
		local t = HudLayout.topLayout(1280, 720)
		local menu = size("Menu", 18, Enum.Font.GothamMedium, 1000)
		local book = size(NotebookText.BUTTON, 16, Enum.Font.GothamMedium, 1000)
		assert(menu.X <= t.menu.x1 - t.menu.x0 - 8 and menu.Y <= t.menu.y1 - t.menu.y0, `Menu is {menu}`)
		assert(book.X <= t.notebook.x1 - t.notebook.x0 - 8 and book.Y <= t.notebook.y1 - t.notebook.y0, `Notebook is {book}`)
	end)

	check("settings: the panel is built with real property names and one row per setting", function()
		local host = Instance.new("Folder")
		host.Name = "SettingsSpecHost"
		host.Parent = workspace
		local values: { [string]: any } = {}
		local closed: { string } = {}
		local io = {
			get = function(id: string): any
				if SettingsModel.live(id) then return "first_spider" end -- (the Spider row reads the client's live appearance, not a setting)
				return SettingsModel.get(function(k: string): any return values[k] end, id)
			end,
			set = function(id: string, v: any): string?
				if not SettingsModel.live(id) then values[id] = v end
				return nil
			end,
			reset = function() for _, id in SettingsModel.ids() do values[id] = SettingsModel.default(id) end end,
			status = function(): string? return "saved" end,
		}
		local panel = SettingsPanel.new(host, io, function(to: string?) table.insert(closed, to or "nil") end)
		-- Server construction checks must not bind client-only ContextActionService.
		-- Opening and actual input binding are exercised by SilkPlayback on the client.
		panel.showing, panel.returnTo = true, "game"
		panel.gui.Enabled = true
		panel:refresh()
		panel:layout()
		local rows, headers = 0, 0
		for _, w in panel.widgets do
			if w.kind == "header" then headers += 1 elseif w.kind == "setting" then rows += 1 end
		end
		assert(headers == 5 and rows == 23 + #SettingsSpec.LIVE, `{headers} headers, {rows} rows`)
		assert(panel.list.ScrollingDirection == Enum.ScrollingDirection.Y and panel.list.AutomaticCanvasSize ~= Enum.AutomaticSize.X, "the list scrolls up and down")
		assert(panel.hint.TextTruncate == Enum.TextTruncate.AtEnd, "the controls line truncates")
		local target = SettingsText.MIN_TARGET
		for _, w in panel.widgets do
			if w.kind == "setting" then
				assert(w.frame.Size.Y.Offset >= target, `{w.id}: the row is {w.frame.Size.Y.Offset} tall`)
				for _, part in { w.value, w.minus, w.plus, w.prev, w.next } do
					if part and part.Size.Y.Offset > 0 then assert(part.Size.Y.Offset >= target, `{w.id}: a control is {part.Size.Y.Offset} tall`) end
				end
			end
		end
		assert(panel.resetButton.Size.Y.Offset < 0 or panel.resetButton.Size.Y.Offset > 0, "the Reset button has a size")
		panel:_apply("SoundMuted", true)
		assert(values.SoundMuted == true, "a toggle writes through the io")
		panel:close()
		assert(#closed == 1 and closed[1] == "game" and not panel:isShowing(), "closing says where it was opened from")
		panel.gui:Destroy()
		host:Destroy()
	end)
end
