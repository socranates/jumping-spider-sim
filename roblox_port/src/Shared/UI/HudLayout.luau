--!strict
-- Where the on-screen controls and the prompt panel go, in the safe area (ScreenInsets.CoreUISafeInsets: clear of notches,
-- the home bar and Roblox's top bar). Pure, so tests/run.luau checks that prompts never sit under a touch button and stay
-- wide enough to read, at phone, tablet and desktop sizes. SpiderInput builds the touch buttons from TOUCH_BUTTONS.
local HudLayout = {}

export type Button = { action: string, label: string, x: number, y: number, size: number, right: boolean, textSize: number? }
export type Rect = { x0: number, y0: number, x1: number, y1: number }

-- x, y: the button's top-left corner as an offset from the safe area's bottom-left (right = false) or bottom-right corner.
HudLayout.TOUCH_BUTTONS = {
	{ action = "Forward", label = "↑", x = 78, y = -188, size = 52, right = false },
	{ action = "Left", label = "←", x = 22, y = -132, size = 52, right = false },
	{ action = "Back", label = "↓", x = 78, y = -76, size = 52, right = false },
	{ action = "Right", label = "→", x = 134, y = -132, size = 52, right = false },
	{ action = "Jump", label = "Jump\n(hold)", x = -92, y = -102, size = 72, right = true },
	{ action = "Cancel", label = "Cancel", x = -166, y = -92, size = 60, right = true, textSize = 16 },
	{ action = "Creep", label = "Creep", x = -86, y = -172, size = 60, right = true },
	{ action = "Drop", label = "Silk", x = -86, y = -242, size = 60, right = true },
	{ action = "Recenter", label = "Re-\ncentre", x = -160, y = -168, size = 52, right = true, textSize = 14 },
	{ action = "Feed", label = "Eat", x = 22, y = -242, size = 52, right = false, textSize = 14 },
	{ action = "Focus", label = "Focus", x = -236, y = -242, size = 60, right = true, textSize = 14 },
	{ action = "Eye", label = "Eye", x = -156, y = -242, size = 60, right = true },
	-- The peacock spider (ROBLOX-31): Change (in the crack) beside Eat, Dance (the peacock spider, standing still) above Silk. Both start hidden.
	{ action = "Choose", label = "Change", x = 82, y = -252, size = 56, right = false, textSize = 13 },
	{ action = "Display", label = "Dance", x = -86, y = -306, size = 56, right = true, textSize = 14 },
} :: { Button }

HudLayout.GAP = 12
HudLayout.MIN_PROMPT_WIDTH = 260
HudLayout.MAX_PROMPT_WIDTH = 760

-- Short landscape safe areas need three rows rather than a tall stack: leave
-- room for the prompt above them, including when Dance/Change are visible.
local COMPACT = {
	Feed={16,-180}, Forward={76,-180}, Choose={136,-180},
	Left={16,-120}, Right={136,-120}, Back={76,-60},
	Focus={-188,-180}, Display={-128,-180}, Drop={-68,-180},
	Eye={-188,-120}, Recenter={-128,-120}, Creep={-68,-120},
	Cancel={-128,-60}, Jump={-68,-60},
}
-- A short screen (under 450 px tall: a phone held sideways, whatever its width, ROBLOX-92: it was 568 px and wider only, so a 480 px phone had the tall stack) is laid out in three rows.
function HudLayout.isShort(width: number, height: number): boolean
	return width > 0 and height > 0 and height < 450
end
function HudLayout.layoutButton(b: Button, width: number, height: number): Button
	local short = HudLayout.isShort(width, height)
	-- A narrow phone (under 400 px) has no room for Focus beside the left thumb's cluster: it goes one row up.
	if b.action == "Focus" and width < 400 and not short then
		local copy = table.clone(b)
		copy.y = -320
		return copy
	end
	if short then
		local slot = COMPACT[b.action]
		if slot then
			local copy = table.clone(b)
			copy.x, copy.y, copy.size = slot[1], slot[2], 52
			copy.textSize = math.min(b.textSize or 18, 14)
			return copy
		end
	end
	return b
end

function HudLayout.buttonRect(b: Button, width: number, height: number): Rect
	b = HudLayout.layoutButton(b, width, height)
	local x0 = if b.right then width + b.x else b.x
	local y0 = height + b.y
	return { x0 = x0, y0 = y0, x1 = x0 + b.size, y1 = y0 + b.size }
end

-- The touch buttons' combined top edge and the inner edges of the two thumb clusters.
local function clusters(width: number, height: number): (number, number, number)
	local leftEdge, rightEdge, top = 0, width, height
	for _, b in HudLayout.TOUCH_BUTTONS do
		local r = HudLayout.buttonRect(b, width, height)
		if b.right then rightEdge = math.min(rightEdge, r.x0) else leftEdge = math.max(leftEdge, r.x1) end
		top = math.min(top, r.y0)
	end
	return leftEdge, rightEdge, top
end

-- The prompt panel's horizontal span and its bottom edge (it grows upward as it wraps) for a safe area of this size.
-- Keyboard and controller: centred near the bottom. Touch: between the thumb clusters when that leaves room to read,
-- otherwise above them.
function HudLayout.promptSpan(width: number, height: number, device: string): (number, number, number)
	local gap = HudLayout.GAP
	local x0, x1, bottom
	if device == "touch" then
		local leftEdge, rightEdge, top = clusters(width, height)
		if rightEdge - leftEdge - 2 * gap >= HudLayout.MIN_PROMPT_WIDTH then
			x0, x1, bottom = leftEdge + gap, rightEdge - gap, height - gap
		else
			x0, x1, bottom = gap, width - gap, top - gap
			-- (above the clusters on a short screen the panel reaches the top: keep it out of the Menu and Notebook stack)
			local strip = HudLayout.topLayout(width, height)
			if strip.stacked then x1 = math.min(x1, strip.notebook.x0 - gap) end
		end
	else
		x0, x1, bottom = 24, width - 24, height - 16
	end
	local extra = (x1 - x0) - HudLayout.MAX_PROMPT_WIDTH
	if extra > 0 then
		x0 += extra / 2
		x1 -= extra / 2
	end
	return x0, x1, bottom
end

-- The Menu and Notebook buttons (ROBLOX-50) and the HUD's top column of status lines (day, notices, toasts, captions), laid out together so none
-- covers another and every button is a touch target (at least MIN_TARGET px each way). Where the screen is wide enough the two buttons stack at
-- the top right and the column gives up that strip on both sides (it stays centred); on a narrow phone they sit side by side in a row at the
-- top and the column starts under them. Rects are offsets from the safe area's top-left corner.
HudLayout.MIN_TARGET = 48
HudLayout.TOP = { menuW = 80, notebookW = 104, h = 48, margin = 12, gap = 8, columnY = 8, columnInset = 16, minColumn = 300 }
HudLayout.TOP_SHORT = { menuW = 64, notebookW = 92, h = 48, margin = 8, gap = 6, columnY = 8, columnInset = 16, minColumn = 260 }
export type Top = { menu: Rect, notebook: Rect, columnX0: number, columnX1: number, columnY: number, stacked: boolean }
function HudLayout.topLayout(width: number, height: number): Top
	local t = HudLayout.TOP
	-- (ROBLOX-92) A short, narrow landscape phone (480 x 320) cannot spare a strip of 124 px on each side, and the column under a row of buttons would meet the prompts above the thumbs:
	-- there the buttons are a little narrower (still 48 px tall, wider than their words) and the stack fits.
	if HudLayout.isShort(width, height) and width - 2 * (t.margin + t.notebookW + t.gap) < t.minColumn then t = HudLayout.TOP_SHORT end
	local x1 = width - t.margin
	local side = t.margin + t.notebookW + t.gap -- the strip the buttons take on each side of a centred column
	if width - 2 * side >= t.minColumn then
		local menu = { x0 = x1 - t.menuW, y0 = t.columnY, x1 = x1, y1 = t.columnY + t.h }
		local notebook = { x0 = x1 - t.notebookW, y0 = menu.y1 + t.gap, x1 = x1, y1 = menu.y1 + t.gap + t.h }
		return { menu = menu, notebook = notebook, columnX0 = side, columnX1 = width - side, columnY = t.columnY, stacked = true }
	end
	local menu = { x0 = x1 - t.menuW, y0 = t.columnY, x1 = x1, y1 = t.columnY + t.h }
	local notebook = { x0 = menu.x0 - t.gap - t.notebookW, y0 = t.columnY, x1 = menu.x0 - t.gap, y1 = t.columnY + t.h }
	return { menu = menu, notebook = notebook, columnX0 = t.columnInset, columnX1 = width - t.columnInset, columnY = menu.y1 + t.gap, stacked = false }
end

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

return HudLayout
