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
	{ action = "Recenter", label = "Re-\ncenter", x = -160, y = -168, size = 52, right = true, textSize = 14 },
	{ action = "Focus", label = "Focus", x = -236, y = -242, size = 60, right = true, textSize = 14 },
	{ action = "Eye", label = "Eye", x = -156, y = -242, size = 60, right = true },
} :: { Button }

HudLayout.GAP = 12
HudLayout.MIN_PROMPT_WIDTH = 260
HudLayout.MAX_PROMPT_WIDTH = 760

function HudLayout.buttonRect(b: Button, width: number, height: number): Rect
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

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

return HudLayout
