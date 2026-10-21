--!strict
-- The notebook's words and its layout rules for the screen (ROBLOX-37), from Godot's notebook_panel.gd: the heading, the empty
-- page, "In this game:" and the sources, the note that a page opened, and how to open and use the book on the device in use. Pure,
-- so tests/notebook.luau checks them (and the layout at phone, tablet and desktop sizes) without Roblox. Button names come from
-- ControlText (PlayStation names on a PlayStation controller).
local ControlText = require(script.Parent.ControlText)
local TarantulaText = require(script.Parent.TarantulaText)

local NotebookText = {}

NotebookText.HEADING = "Field notebook"
NotebookText.EMPTY = "Pages appear here as you play."
NotebookText.GAME = "In this game: "
NotebookText.CLOSE = "Close"
NotebookText.PAGES = "Pages"
NotebookText.MENU_CHOICE = "Notebook"
NotebookText.BUTTON = "Notebook"

-- Fills {reel}, {letGo}, {drop}, {focus}, {display} (any ControlText action name) in a page's "In this game" line with the device's name for it. {display} is the
-- display key (ROBLOX-92: the tarantula page's rear-up); on touch its button is the tarantulas' own, "Rear up", not the peacock's "Dance".
function NotebookText.fill(text: string, device: ControlText.Device): string
	local out = string.gsub(text, "{(%w+)}", function(action: string): string
		local name = if action == "display" and device == "touch" then TarantulaText.touchDisplay(false) else ControlText.name(device, action)
		return if name ~= "" then name else "{" .. action .. "}"
	end)
	return out
end

-- The page's "In this game: ..." line, or nil when the page has none (Godot: an empty `game` shows nothing).
function NotebookText.gameLine(game: string, device: ControlText.Device): string?
	if game == "" then
		return nil
	end
	
	return NotebookText.GAME .. NotebookText.fill(game, device)
end

-- ROBLOX-89: the lines the game has added to a page ("Day 4: ..."), under the page's "In this game" line, or nil when there are none.
NotebookText.SEEN = "Things you saw:"
function NotebookText.seenText(entries: { { day: number, text: string } }): string?
	if #entries == 0 then return nil end
	local lines = { NotebookText.SEEN }
	for _, e in entries do table.insert(lines, e.text) end
	return table.concat(lines, "\n")
end

-- "Source: x" for one source, "Sources:\nx\ny" for several. The links stay in the text as they are.
function NotebookText.sourcesText(sources: { string }): string
	return (if #sources == 1 then "Source: " else "Sources:\n") .. table.concat(sources, "\n")
end

-- How to open the notebook, on the device in use: N on a keyboard; the Notebook button on touch; a controller has no spare button (the
-- D-pad walks), so it is the life menu (View, or the Touchpad on a PlayStation controller) and then Notebook.
function NotebookText.openHint(device: ControlText.Device): string
	if device == "gamepad" then
		return `{ControlText.name("gamepad", "menu")}, then {NotebookText.MENU_CHOICE},`
	elseif device == "touch" then
		return `the {NotebookText.BUTTON} button`
	end
	return ControlText.name("keyboard", "notebook")
end

-- The note when a page opens during play (Godot: "New in your notebook: %s\n(%s to read)").
function NotebookText.note(title: string, device: ControlText.Device): string
	return `New in your notebook: {title}\n({NotebookText.openHint(device)} to read)`
end

-- The line under the page: what the controls do, on the device in use. `stacked`: one pane at a time (small screens).
function NotebookText.controls(device: ControlText.Device, stacked: boolean): string
	local back = ControlText.name(device, "cancel")
	if device == "gamepad" then
		local a = ControlText.name("gamepad", "jump")
		return `Stick or D-pad: pages    {a}: open    Right stick: scroll    {back}: {if stacked then "back / close" else "close"}`
	elseif device == "touch" then
		return `Tap a page. Drag to scroll.`
	end
	return `Up and Down: pages    {if stacked then "Enter: open    Left and Right: previous and next    " else ""}Wheel, PageUp or PageDown: scroll    N or {back}: close`
end

-- ---------------------------------------------------------------- layout

-- Text sizes by kind at normal text, and the large-text option's factor (the life menu's switch: the Player attribute LargeText).
NotebookText.SIZES = { heading = 26, title = 24, body = 19, game = 17, sources = 14, button = 18, controls = 14 }
NotebookText.LARGE = 1.5
-- A touch target is at least this tall (before the text scale).
NotebookText.MIN_TARGET = 44

export type Layout = { sideBySide: boolean, listFraction: number }

-- Side by side (the pages on the left, the page on the right) needs room; a phone held sideways, a portrait phone or large text
-- show one pane at a time instead. `width` and `height` are the safe area's, `scale` the text scale (1 to LARGE).
function NotebookText.layout(width: number, height: number, scale: number): Layout
	local sideBySide = width >= 640 * scale and height >= 340
	return { sideBySide = sideBySide, listFraction = if sideBySide then 0.34 else 1.0 }
end

export type Metrics = { paperW: number, paperH: number, head: number, hint: number, foot: number, body: number }

-- Pixel sizes of the panel for a safe area of this size: the paper (97% by 95%, at most 1040 by 820), the heading band, the controls
-- line (two lines of text; 0 when the pages would be left with less than MIN_BODY px without it), the footer's buttons and the height
-- left for the pages (what scrolls). Pure, so a short screen can be checked: a phone held sideways is 568 by 320.
NotebookText.MIN_BODY = 120
function NotebookText.metrics(width: number, height: number, scale: number): Metrics
	local paperW, paperH = math.min(width * 0.97, 1040), math.min(height * 0.95, 820)
	local head = math.floor((NotebookText.SIZES.heading + 10) * scale)
	local foot = math.floor((NotebookText.MIN_TARGET + 8) * scale)
	local hint = math.floor(5 * NotebookText.SIZES.controls * scale) + 4
	local body = paperH - 20 - head - foot - 12
	if body - hint >= NotebookText.MIN_BODY then
		body -= hint
	else
		hint = 0
	end
	return { paperW = paperW, paperH = paperH, head = head, hint = hint, foot = foot, body = body }
end


-- Nathan requested an optional checklist on 2026-10-17 (ROBLOX-38).
-- These are invitations, not all possible pages or a completion gate. No task asks a child to starve or get caught.
NotebookText.TRY = {
 {id="bold_jumper",text="Meet your spider and explore the sill."},
 {id="dragline",text="Make a jump and see the safety silk."},
 {id="eight_eyes",text="Switch to the spider-eye view."},
 {id="moving_retinas",text="Spend a little time looking through its eyes."},
 {id="hunting_by_sight",text="Focus on a fly until you recognise it."},
 {id="venom",text="Catch a fly."},
 {id="drinking",text="Finish a meal."},
 {id="retreat",text="Rest inside the silk-lined crack."},
 {id="home_before_dark",text="Sleep in the crack through a night."},
 {id="new_skin",text="Eat, then rest when ready to moult."},
 {id="grown_up",text="Grow through three moults."},
 {id="peacock_dance",text="Change to the peacock (in Settings, or while resting), then dance outside."},
 {id="walking_like_an_ant",text="Change to the ant mimic (in Settings, or while resting), then stand still."},
 {id="eggs_and_wind",text="Raise a family: court a mate, guard the sac, watch the hatching."},
 {id="tarantula_cousins",text="Change to a tarantula (in Settings, or while resting), then rear up outside."},
}
function NotebookText.checklist(book:any):string
 local lines={}
 for _,entry in NotebookText.TRY do
  table.insert(lines,(if book:isOpen(entry.id) then "[x] " else "[ ] ")..entry.text)
 end
 return table.concat(lines,"\n\n")
end

return NotebookText
