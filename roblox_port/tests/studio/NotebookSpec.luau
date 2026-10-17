--!strict
-- The naturalist's notebook in the engine (ROBLOX-37): the pages and the panel's words with Roblox's own text metrics (TextService),
-- and the panel's instances built with real property names. The pure rules are in tests/notebook.luau (NOTEBOOK). What a player sees and
-- does with the live client (a real ScreenGui, the world waiting, text inside its boxes) is checked by tests/client/SilkPlayback.luau.
return function(check: (string, () -> ()) -> ())
	local TextService = game:GetService("TextService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FieldNotebook = require(Shared.Learning.FieldNotebook)
	local NotebookPages = require(Shared.Data.NotebookPages)
	local NotebookText = require(Shared.UI.NotebookText)
	local HudLayout = require(Shared.UI.HudLayout)
	local ControlText = require(Shared.UI.ControlText)
	local Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local NotebookPanel = require(Client:WaitForChild("NotebookPanel")) :: any
	local devices: { any } = { "keyboard", "gamepad", "touch" }
	local screens = { Vector2.new(568, 320), Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(360, 640), Vector2.new(768, 1024), Vector2.new(1024, 768), Vector2.new(1280, 720), Vector2.new(1920, 1080) }
	local scales = { 1.0, NotebookText.LARGE }
	local S = NotebookText.SIZES
	local function size(text: string, textSize: number, font: Enum.Font, width: number): Vector2
		return TextService:GetTextSize(text, textSize, font, Vector2.new(width, 100000))
	end
	local function everything(): FieldNotebook.Notebook
		local book: any = FieldNotebook.new()
		for _, p in book.pages do book:notice(p.trigger) end
		return book
	end

	check("notebook: the book in the engine is Godot's 24 pages, found once each, with no unfound page readable", function()
		local book: any = FieldNotebook.new()
		assert(#book.pages == 24 and #book.dropped == 0, `{#book.pages} pages, {#book.dropped} dropped`)
		for _, p in book.pages do assert(book:view(p.id) == nil, p.id .. " readable before it is found") end
		local all = everything() :: any
		assert(#all.opened == 24, `{#all.opened} found`)
		assert(#all:notice("jump") == 0, "a page opened twice")
	end)

	check("notebook: every page fits every screen the panel supports, one pane or two, normal and large text", function()
		local book: any = everything()
		for _, screen in screens do
			for _, scale in scales do
				local m = NotebookText.metrics(screen.X, screen.Y, scale)
				local lay = NotebookText.layout(screen.X, screen.Y, scale)
				-- the page pane: the paper less the padding, less the list when two panes show, less the scroll bar and the label's inset
				local inner = m.paperW - 28
				local width = (if lay.sideBySide then inner * (1 - lay.listFraction) - 8 else inner) - 6 - 14
				for _, p in book.pages do
					local total, widest = 0, 0
					local parts = {
						{ p.title, S.title * scale, Enum.Font.GothamBold }, { p.text, S.body * scale, Enum.Font.Gotham },
						{ NotebookText.gameLine(p.game, "keyboard") or "", S.game * scale, Enum.Font.Gotham },
						{ NotebookText.sourcesText(p.sources), S.sources * scale, Enum.Font.Gotham },
					}
					for _, part in parts do
						if part[1] ~= "" then
							local s = size(part[1], part[2], part[3], width)
							total += s.Y + 12
							widest = math.max(widest, s.X)
						end
					end
					assert(widest <= width + 0.5, `{p.id} at {screen.X}x{screen.Y} x{scale}: a line is {widest} px in {width}`)
					assert(total <= 12 * m.body, `{p.id} at {screen.X}x{screen.Y} x{scale}: {math.floor(total)} px of page for {math.floor(m.body)} px of pane`)
				end
			end
		end
	end)

	check("notebook: page titles fit the list in at most three lines, and the heading and buttons fit their bands", function()
		local book: any = everything()
		for _, screen in screens do
			for _, scale in scales do
				local m = NotebookText.metrics(screen.X, screen.Y, scale)
				local lay = NotebookText.layout(screen.X, screen.Y, scale)
				local width = (m.paperW - 28) * lay.listFraction - (if lay.sideBySide then 8 else 0) - 10 - 16 - 6 -- the list, the button's inset and padding, the scroll bar
				for _, p in book.pages do
					local s = size(p.title, S.button * scale, Enum.Font.GothamMedium, width)
					assert(s.Y <= 3 * S.button * scale * 1.3, `{p.id} at {screen.X}x{screen.Y} x{scale}: title needs {s.Y} px`)
				end
				local h = size(NotebookText.HEADING, S.heading * scale, Enum.Font.GothamBold, m.paperW - 28)
				assert(h.Y <= m.head and h.X <= m.paperW - 28, `heading {h} in {m.head} at {screen.X}x{screen.Y} x{scale}`)
				for _, label in { NotebookText.CLOSE, NotebookText.PAGES } do
					local b = size(label, S.button * scale, Enum.Font.GothamMedium, 112 * scale)
					assert(b.X <= 112 * scale - 8 and b.Y <= m.foot - 8, `button "{label}" is {b} in {112 * scale}x{m.foot - 8}`)
				end
			end
		end
	end)

	check("notebook: the controls line fits its two lines, where it is shown, for every device", function()
		for _, screen in screens do
			for _, scale in scales do
				local m = NotebookText.metrics(screen.X, screen.Y, scale)
				if m.hint > 0 then
					local lay = NotebookText.layout(screen.X, screen.Y, scale)
					for _, device in devices do
						for _, pad in { "xbox", "playstation" } do
							ControlText.setPadStyle(pad)
							local text = NotebookText.controls(device, not lay.sideBySide)
							local s = size(text, S.controls * scale, Enum.Font.Gotham, m.paperW - 28)
							assert(s.Y <= m.hint, `{device}/{pad} at {screen.X}x{screen.Y} x{scale}: "{text}" needs {s.Y} px for {m.hint}`)
						end
					end
				end
			end
		end
		ControlText.setPadStyle("xbox")
	end)

	check("notebook: the note that a page opened wraps inside the narrowest label, and the Notebook button's word fits its button", function()
		local book: any = everything()
		local width = HudLayout.MIN_PROMPT_WIDTH - 20
		for _, p in book.pages do
			for _, device in devices do
				for _, pad in { "xbox", "playstation" } do
					ControlText.setPadStyle(pad)
					local s = size(NotebookText.note(p.title, device), 15, Enum.Font.GothamMedium, width)
					assert(s.X <= width + 0.5 and s.Y <= 5 * 15 * 1.35, `{p.id}/{device}: the note is {s}`)
				end
			end
		end
		ControlText.setPadStyle("xbox")
		local b = size(NotebookText.BUTTON, 14, Enum.Font.GothamMedium, 1000)
		assert(b.X <= 88 - 6 and b.Y <= 36, `the button's word is {b} in 88x36`)
	end)

	check("notebook: the panel is built with real property names, shows each found page and nothing else", function()
		local book: any = FieldNotebook.new()
		book:notice("start"); book:notice("jump"); book:notice("buzz")
		local host = Instance.new("Folder")
		host.Name = "NotebookSpecHost"
		host.Parent = workspace
		local closed = 0
		local panel = NotebookPanel.new(host, book, function() closed += 1 end)
		panel:layout()
		panel:_rebuildList()
		assert(#panel.buttons == 3, `{#panel.buttons} list entries`)
		for _, id in { "bold_jumper", "dragline", "hearing" } do
			panel:showPage(id)
			assert(panel.title.Text == book:view(id).title and panel.title.Visible and not panel.empty.Visible, id)
		end
		panel:showPage("legs_push") -- not found: nothing shows
		assert(panel.shown == "" and panel.empty.Visible and not panel.title.Visible and not panel.sources.Visible, "an unfound page showed")
		local seen = ""
		for _, d in panel.gui:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then seen ..= d.Text .. "\n" end
		end
		for _, p in book.pages do
			assert((string.find(seen, p.title, 1, true) ~= nil) == book:isOpen(p.id) or p.id == "hearing", p.id .. " on screen wrongly")
		end
		assert(panel.page.ScrollingDirection == Enum.ScrollingDirection.Y and panel.list.AutomaticCanvasSize == Enum.AutomaticSize.Y, "the panes scroll")
		assert(panel.controls.TextTruncate == Enum.TextTruncate.AtEnd, "the controls line truncates")
		panel.gui:Destroy()
		host:Destroy()
		assert(NotebookPages.noteSeconds == 6.0)
	end)
end
