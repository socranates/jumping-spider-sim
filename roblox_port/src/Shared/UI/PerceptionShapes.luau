--!strict
-- PerceptionShapes: the geometry the perception HUD draws with (ROBLOX-20, the drawer's polish), pure. A last-seen ring is 12 short
-- bars along a circle, an off-screen cue's chevron is two bars, the Focus ticks are four, and a label hangs under the ring it
-- names. Client/PerceptionHud draws each bar as a thin rounded Frame; nothing here reads the engine, so tests/hud.luau checks every
-- rule. What is drawn, its words, opacities and timings are PerceptionView's and are not touched here.
-- Pixels, screen y down; a rotation is in degrees, clockwise, as GuiObject.Rotation.
local Shapes = {}

-- A thin bar: centred on (x, y), `length` long. `rotation` turns a horizontal bar clockwise to lie along it (a bar looks the same
-- turned half a turn, so it is kept in -90 to 90).
export type Bar = { x: number, y: number, length: number, rotation: number }

local function axis(deg: number): number
	return (deg + 90) % 180 - 90
end

-- A last-seen ring (PerceptionView kind "mark") is DASHES dashes at equal steps, the first at the top. `dash` (PerceptionView: 1
-- when the sighting is fresh, 0.3 when it is as stale as it gets) says how much of its step each dash covers, up to DASH_FILL, so
-- the gaps grow as the sighting ages. A dash is straight with both ends on the circle, never shorter than MIN_DASH pixels.
Shapes.DASHES = 12
Shapes.DASH_FILL = 0.85
Shapes.MIN_DASH = 2

function Shapes.dashRing(cx: number, cy: number, radius: number, dash: number): { Bar }
	local step = 2 * math.pi / Shapes.DASHES
	local half = step * Shapes.DASH_FILL * math.clamp(dash, 0, 1) * 0.5 -- half the angle a dash covers
	local length = math.max(2 * radius * math.sin(half), Shapes.MIN_DASH)
	local reach = radius * math.cos(half) -- the middle of a chord lies a little inside the circle
	local out: { Bar } = {}
	for i = 0, Shapes.DASHES - 1 do
		local a = -math.pi / 2 + i * step
		out[i + 1] = { x = cx + math.cos(a) * reach, y = cy + math.sin(a) * reach, length = length, rotation = axis(math.deg(a) + 90) }
	end
	return out
end

-- An off-screen cue's chevron, pointing along the unit direction (dx, dy) from the middle of the screen out to the edge: two arms of
-- CHEVRON_ARM pixels meeting at the tip, each lying CHEVRON_SPREAD degrees back from that direction. It is centred on (x, y)
-- along its direction, which is where the mark sits on the edge.
Shapes.CHEVRON_ARM = 15
Shapes.CHEVRON_SPREAD = 40

function Shapes.chevron(x: number, y: number, dx: number, dy: number): { Bar }
	local arm, spread = Shapes.CHEVRON_ARM, math.rad(Shapes.CHEVRON_SPREAD)
	local heading = math.atan2(dy, dx)
	local depth = arm * math.cos(spread) -- how far the arms reach back from the tip
	local tx, ty = x + math.cos(heading) * depth * 0.5, y + math.sin(heading) * depth * 0.5
	local out: { Bar } = {}
	for i, side in { -1, 1 } do
		local back = heading + math.pi + side * spread
		out[i] = { x = tx + math.cos(back) * arm * 0.5, y = ty + math.sin(back) * arm * 0.5, length = arm, rotation = axis(math.deg(back)) }
	end
	return out
end

-- The Focus ticks around the middle (cx, cy): four short bars, each lying along the line out from the middle, FOCUS_RADIUS pixels
-- out (their middles) and FOCUS_LENGTH long.
Shapes.FOCUS_RADIUS = 11
Shapes.FOCUS_LENGTH = 10

function Shapes.focusTicks(cx: number, cy: number): { Bar }
	local out: { Bar } = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		out[i + 1] = { x = cx + math.cos(a) * Shapes.FOCUS_RADIUS, y = cy + math.sin(a) * Shapes.FOCUS_RADIUS, length = Shapes.FOCUS_LENGTH, rotation = axis(math.deg(a)) }
	end
	return out
end

-- The lock's cue (ROBLOX-110): four short ticks on the diagonals round the locked thing's place on screen, fainter and wider than Focus's, so
-- the two never read as one. The only thing the lock draws.
Shapes.LOCK_RADIUS = 22
Shapes.LOCK_LENGTH = 7
Shapes.LOCK_ALPHA = 0.6 -- (0.45 all but vanished on the sunlit floor in the mock of ROBLOX-110; the dark edge at 0.6 reads on light and dark ground)
function Shapes.lockTicks(cx: number, cy: number): { Bar }
	local out: { Bar } = {}
	for i = 0, 3 do
		local a = math.pi / 4 + i * math.pi / 2
		out[i + 1] = { x = cx + math.cos(a) * Shapes.LOCK_RADIUS, y = cy + math.sin(a) * Shapes.LOCK_RADIUS, length = Shapes.LOCK_LENGTH, rotation = axis(math.deg(a)) }
	end
	return out
end

-- Where a label's top middle goes. (px, py) is the middle of the ring it names and `offset` PerceptionView's gap from there to the
-- label (the ring's radius and 8). Under the ring, unless the screen has no room for LABEL_HEIGHT pixels there, then above it. When
-- the label's width is known (> 0) it is kept LABEL_MARGIN pixels inside the screen sideways. Returns x, y and whether it is below.
Shapes.LABEL_HEIGHT = 28
Shapes.LABEL_MARGIN = 8

function Shapes.labelAt(px: number, py: number, offset: number, width: number, viewportW: number, viewportH: number): (number, number, boolean)
	local below = py + offset + Shapes.LABEL_HEIGHT <= viewportH - Shapes.LABEL_MARGIN
	local y = if below then py + offset else py - offset - Shapes.LABEL_HEIGHT
	local x = px
	if width > 0 then
		local half = width * 0.5 + Shapes.LABEL_MARGIN
		x = math.clamp(px, math.min(half, viewportW * 0.5), math.max(viewportW - half, viewportW * 0.5))
	end
	return x, y, below
end

return Shapes
