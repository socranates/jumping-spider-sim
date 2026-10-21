-- Perception HUD checks (ROBLOX-20, the drawer's polish): first the pure shapes of Shared/UI/PerceptionShapes (the 12-dash last-seen
-- ring, the chevron, the Focus ticks, where a label hangs), then the real Client/PerceptionHud under the shim (tests/shim.luau) with a
-- stand-in memory: circles are rounded Frames, a last-seen ring is 12 bars, a cue is a chevron, a label is Builder Sans on a pill
-- under its ring, widgets are reused, and what the view says (PerceptionView) is what gets drawn. It says nothing about how any of it
-- LOOKS in Roblox (the strokes, the pill's fit to its text, the font) which only Studio can show.
-- Run with the other suites:  python3 tests/run.py path/to/luau hud.luau
local Shapes = require("../src/Shared/UI/PerceptionShapes")
local View = require("../src/Shared/UI/PerceptionView")
local PerceptionHud = require("../src/Client/PerceptionHud")
local SpiderHud = require("../src/Client/SpiderHud")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL hud: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local function rad(d: number): number return math.rad(d) end

-- ---------------------------------------------------------------- the dashed last-seen ring
local function ends(b: any): (number, number, number, number)
	local a = rad(b.rotation)
	return b.x - math.cos(a) * b.length / 2, b.y - math.sin(a) * b.length / 2, b.x + math.cos(a) * b.length / 2, b.y + math.sin(a) * b.length / 2
end
local function angleOf(cx: number, cy: number, x: number, y: number): number return math.deg(math.atan2(y - cy, x - cx)) end

local ring = Shapes.dashRing(100, 80, 20, 1)
check(#ring == 12 and Shapes.DASHES == 12, "a last-seen ring is 12 dashes")
check(near(ring[1].x, 100, 1e-9) and ring[1].y < 80 and near(ring[1].rotation, 0, 1e-9), "the first is at the top, lying along x")
local onCircle = true
for _, b in ring do
	local x1, y1, x2, y2 = ends(b)
	onCircle = onCircle and near(math.sqrt((x1 - 100) ^ 2 + (y1 - 80) ^ 2), 20, 1e-9) and near(math.sqrt((x2 - 100) ^ 2 + (y2 - 80) ^ 2), 20, 1e-9)
end
check(onCircle, "each dash is a chord: both its ends are on the circle")
local tangent = true
for i, b in ring do
	local a = math.deg(-math.pi / 2 + (i - 1) * math.pi / 6)
	local off = (b.rotation - (a + 90)) % 180
	tangent = tangent and (near(off, 0, 1e-9) or near(off, 180, 1e-9)) and b.rotation >= -90 and b.rotation < 90
end
check(tangent, "each lies along the circle there (tangent), turned within -90 to 90")
local mirrored = true
for i = 2, 12 do
	local m = ring[14 - i]
	mirrored = mirrored and near(m.x, 200 - ring[i].x, 1e-9) and near(m.y, ring[i].y, 1e-9) and near(m.length, ring[i].length, 1e-12)
end
check(mirrored, "the ring is the same left and right")
local gapDeg = function(dash: number): number
	local r = Shapes.dashRing(0, 0, 30, dash)
	local x1, y1, x2, y2 = ends(r[1])
	local a1, a2 = angleOf(0, 0, x1, y1), angleOf(0, 0, x2, y2)
	local covered = math.abs(a2 - a1)
	return 30 - covered
end
check(near(gapDeg(1), 30 - 25.5, 1e-9) and near(gapDeg(0.3), 30 - 7.65, 1e-9), "at 1 a dash covers 0.85 of its 30 degrees (4.5 degrees of gap), at 0.3 it covers 7.65 (22.35 of gap)")
local gaps, growing = {}, true
for i = 0, 10 do gaps[i] = gapDeg(1 - i * 0.07) end
for i = 1, 10 do growing = growing and gaps[i] > gaps[i - 1] end
check(growing and gaps[0] > 0, "the gaps grow as the sighting ages, and are never closed")
check(Shapes.dashRing(0, 0, 10, 0.01)[1].length == Shapes.MIN_DASH and Shapes.dashRing(0, 0, 10, 0)[5].length == 2, "never shorter than 2 px")
check(near(Shapes.dashRing(0, 0, 20, 5)[1].length, Shapes.dashRing(0, 0, 20, 1)[1].length, 1e-12) and near(Shapes.dashRing(0, 0, 20, -1)[1].length, 2, 1e-12), "dash is kept within 0 to 1")
check(near(Shapes.dashRing(0, 0, 36, 1)[1].length, 2 * 36 * math.sin(rad(12.75)), 1e-9), "a dash is a chord of 12.75 degrees either side of its middle")

-- ---------------------------------------------------------------- the chevron
local function chevronOk(x: number, y: number, dx: number, dy: number): (boolean, string)
	local arms = Shapes.chevron(x, y, dx, dy)
	if #arms ~= 2 then return false, "two arms" end
	local a1x1, a1y1, a1x2, a1y2 = ends(arms[1])
	local a2x1, a2y1, a2x2, a2y2 = ends(arms[2])
	-- the tip is the end the arms share
	local best, tipX, tipY, far1x, far1y, far2x, far2y = math.huge, 0, 0, 0, 0, 0, 0
	for _, p in { { a1x1, a1y1, a1x2, a1y2 }, { a1x2, a1y2, a1x1, a1y1 } } do
		for _, q in { { a2x1, a2y1, a2x2, a2y2 }, { a2x2, a2y2, a2x1, a2y1 } } do
			local d = math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2)
			if d < best then best, tipX, tipY, far1x, far1y, far2x, far2y = d, p[1], p[2], p[3], p[4], q[3], q[4] end
		end
	end
	if best > 1e-9 then return false, "the arms meet" end
	local reach = Shapes.CHEVRON_ARM
	if not (near(math.sqrt((far1x - tipX) ^ 2 + (far1y - tipY) ^ 2), reach, 1e-9) and near(math.sqrt((far2x - tipX) ^ 2 + (far2y - tipY) ^ 2), reach, 1e-9)) then return false, "arm length" end
	-- both free ends lie behind the tip, 40 degrees to each side of the direction
	local backX, backY = -dx, -dy
	local a1 = math.deg(math.acos(math.clamp(((far1x - tipX) * backX + (far1y - tipY) * backY) / reach, -1, 1)))
	local a2 = math.deg(math.acos(math.clamp(((far2x - tipX) * backX + (far2y - tipY) * backY) / reach, -1, 1)))
	if not (near(a1, 40, 1e-6) and near(a2, 40, 1e-6)) then return false, "40 degrees back" end
	local cross1 = (far1x - tipX) * dy - (far1y - tipY) * dx
	local cross2 = (far2x - tipX) * dy - (far2y - tipY) * dx
	if not (cross1 * cross2 < 0 and near(math.abs(cross1), math.abs(cross2), 1e-9)) then return false, "one to each side" end
	-- centred on (x, y) along the direction: the tip as far ahead as the free ends are behind
	local ahead = (tipX - x) * dx + (tipY - y) * dy
	local behind = (x - (far1x + far2x) / 2) * dx + (y - (far1y + far2y) / 2) * dy
	if not (near(ahead, behind, 1e-9) and ahead > 0) then return false, "centred" end
	-- and on the line through (x, y) along the direction
	if not near((tipX - x) * dy - (tipY - y) * dx, 0, 1e-9) then return false, "on the line" end
	return true, ""
end
for _, d in { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 }, { 0.6, -0.8 }, { -math.sqrt(0.5), math.sqrt(0.5) } } do
	local ok, why = chevronOk(640, 360, d[1], d[2])
	check(ok, `a chevron pointing ({d[1]}, {d[2]}): {why}`)
end
local right = Shapes.chevron(1246, 360, 1, 0)
check(near(right[1].rotation, -40, 1e-9) and near(right[2].rotation, 40, 1e-9), "pointing right the arms lie at -40 and 40 degrees: a > ")
check(right[1].length == 15 and right[2].length == 15, "arms are 15 px long")

-- ---------------------------------------------------------------- the Focus ticks
local ticks = Shapes.focusTicks(640, 360)
local ticksOk = #ticks == 4
for i, t in ticks do
	local a = (i - 1) * 90
	ticksOk = ticksOk and near(math.sqrt((t.x - 640) ^ 2 + (t.y - 360) ^ 2), 11, 1e-9) and t.length == 10 and near((t.rotation - a) % 180, 0, 1e-9)
end
check(ticksOk, "four ticks, 11 px out, 10 long, lying along the line out from the middle")
check(near(ticks[1].x, 651, 1e-9) and near(ticks[3].x, 629, 1e-9) and near(ticks[2].y, 371, 1e-9) and near(ticks[4].y, 349, 1e-9), "right, below, left, above")

-- ---------------------------------------------------------------- where a label hangs
local lx, ly, below = Shapes.labelAt(640, 360, 20, 0, 1280, 720)
check(lx == 640 and ly == 380 and below == true, "under the ring by default: its top is `offset` below the ring's middle")
lx, ly, below = Shapes.labelAt(640, 700, 20, 0, 1280, 720)
check(lx == 640 and ly == 700 - 20 - 28 and below == false, "above it when the screen has no room below")
lx, ly, below = Shapes.labelAt(640, 720 - 8 - 28 - 20, 20, 0, 1280, 720)
check(below == true, "just enough room below still counts as below")
lx = Shapes.labelAt(1270, 360, 20, 200, 1280, 720)
check(lx == 1280 - 100 - 8, "a measured label is kept inside the screen on the right")
lx = Shapes.labelAt(10, 360, 20, 200, 1280, 720)
check(lx == 100 + 8, "and on the left")
lx = Shapes.labelAt(300, 360, 20, 200, 1280, 720)
check(lx == 300, "and left alone in the middle")
lx = Shapes.labelAt(30, 360, 20, 200, 100, 720)
check(lx == 50, "a label wider than the screen is centred")

-- ---------------------------------------------------------------- the real drawer under the shim
local camera = workspace.CurrentCamera
camera.FieldOfView = 65
camera.CFrame = CFrame.new(0, 5, 0) -- looking along -z
local VIEW = camera.ViewportSize

local function contact(o: any): any
	local c: any = {
		trackId = o.id or "t1", cueCount = o.cueCount or 0, cueDirection = o.cueDirection or Vector3.zero,
		hasPosition = o.position ~= nil, position = o.position or Vector3.zero, sizeWu = o.size or 0.4, category = o.category or "fly_like_prey",
		inspected = o.inspected == true, mark = o.mark == true, age = o.age or 0, stale = o.stale or 0, cueAge = o.cueAge or 0,
	}
	function c.isInspectedNow(self: any): boolean return self.inspected end
	function c.hasMark(self: any): boolean return self.mark end
	return c
end
local function memoryOf(list: { any }): any
	local m: any = {}
	function m.contacts(_self: any): { any } return list end
	function m.cueAgeS(_self: any, c: any): number return c.cueAge end
	function m.ageS(_self: any, c: any): number return c.age end
	function m.stalenessOf(_self: any, c: any): number return c.stale end
	return m
end
local function noCover(_eye: Vector3, _at: Vector3): Vector3? return nil end
local function newHud(): (any, any)
	local parent = Instance.new("Folder")
	return PerceptionHud.new(parent), parent
end
local function named(root: any, name: string): { any }
	local out = {}
	for _, d in root:GetDescendants() do if d.Name == name then table.insert(out, d) end end
	return out
end
local function shown(root: any, name: string): { any }
	local out = {}
	for _, d in named(root, name) do if d.Visible then table.insert(out, d) end end
	return out
end
local function children(f: any, className: string): { any }
	local out = {}
	for _, d in f:GetChildren() do if d.ClassName == className then table.insert(out, d) end end
	return out
end
local function draw(hud: any, list: { any }, focusing: boolean?, showMark: boolean?)
	hud:draw(memoryOf(list), camera, noCover, focusing == true, showMark)
end

-- the gui itself
do
	local hud = newHud()
	check(hud.gui.Name == "PerceptionHud" and hud.gui.DisplayOrder == 4 and hud.gui.IgnoreGuiInset == true and hud.gui.ResetOnSpawn == false, "the same screen as before: PerceptionHud, order 4, ignoring the inset")
end

-- a live (inspected) contact: a real circle and a label under it
do
	local hud, parent = newHud()
	draw(hud, { contact({ position = Vector3.new(0, 5, -10), inspected = true }) })
	local view = hud.view
	check(#view.rings == 1 and view.rings[1].kind == "live" and #view.labels == 1 and #view.edges == 0, "an inspected contact: one live ring and one label in the view")
	local circles = shown(parent, "Circle")
	check(#circles == 1 and #shown(parent, "Bar") == 0 and #shown(parent, "Label") == 1, "drawn as one circle and one label, no bars")
	local c = circles[1]
	local r = view.rings[1]
	check(near(c.Position.X.Offset, 640, 1e-6) and near(c.Position.Y.Offset, 360, 1e-6), "the circle is where the contact is")
	check(near(c.Size.X.Offset, r.radius * 2, 1e-9) and c.Size.X.Offset == c.Size.Y.Offset, "and as wide as the view says (twice the radius)")
	check(c.BackgroundTransparency == 1 and #children(c, "UICorner") == 1 and children(c, "UICorner")[1].CornerRadius.Scale == 0.5, "a see-through Frame with fully rounded corners: a circle")
	local strokes = children(c, "UIStroke")
	check(#strokes == 1 and strokes[1].Thickness == 2 and near(strokes[1].Transparency, 1 - 0.85, 1e-9), "with a 2 px stroke at the view's opacity (0.85)")
	local halo = c:FindFirstChild("Halo")
	local hs = halo and children(halo, "UIStroke")[1]
	check(halo ~= nil and hs ~= nil and hs.Thickness == 1.5 and hs.Color.R == 0 and hs.Transparency > strokes[1].Transparency, "and a fainter dark one just outside it")
	local label = shown(parent, "Label")[1]
	check(label.Text == "fly-like prey" and label.TextTransparency == 0, "the label says what the view says")
	check(label.FontFace.Family == "rbxasset://fonts/families/BuilderSans.json" and label.FontFace.Weight == Enum.FontWeight.SemiBold and label.TextSize == 18, "in Builder Sans SemiBold at 18")
	local ls = children(label, "UIStroke")
	check(#ls == 1 and ls[1].ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual and ls[1].Thickness == 1.5 and ls[1].Transparency < 1, "with a stroke on the text")
	check(#children(label, "UICorner") == 1 and children(label, "UICorner")[1].CornerRadius.Scale == 0.5 and label.BackgroundTransparency < 1 and label.BackgroundTransparency > 0, "on a dark rounded pill")
	check(label.AutomaticSize == Enum.AutomaticSize.XY and #children(label, "UIPadding") == 1, "that grows to fit the text")
	local view1 = view.labels[1]
	check(near(label.Position.X.Offset, 640, 1e-6) and near(label.Position.Y.Offset, 360 + view1.offset, 1e-6) and label.AnchorPoint.Y == 0 and label.AnchorPoint.X == 0.5, "the label hangs below the ring: top middle `offset` under its middle")
	check(label.Position.Y.Offset > c.Position.Y.Offset + c.Size.Y.Offset / 2, "clear of the ring")
	local glyphs = false
	for _, d in parent:GetDescendants() do
		if d.ClassName == "TextLabel" and (string.find(d.Text or "", "—", 1, true) or string.find(d.Text or "", "›", 1, true)) then glyphs = true end
	end
	check(not glyphs, "no glyph is used for the shapes any more")
end

-- a last-seen mark: twelve dashes, gaps by age, and "lost sight" under it
do
	local hud, parent = newHud()
	local fresh = contact({ position = Vector3.new(0, 5, -10), mark = true, stale = 0, age = 0.5 })
	draw(hud, { fresh })
	local view = hud.view
	local bars = shown(parent, "Bar")
	check(#view.rings == 1 and view.rings[1].kind == "mark" and #bars == 12 and #shown(parent, "Circle") == 0, "a last-seen mark: twelve bars and no circle")
	local lengthFresh = bars[1].Size.X.Offset
	check(bars[1].Size.Y.Offset == 2 and near(bars[1].BackgroundTransparency, 1 - view.rings[1].alpha, 1e-9), "2 px thick, at the view's opacity")
	local label = shown(parent, "Label")[1]
	-- (ROBLOX-113: the drawn label is the calmed one, UI/QuietHud.calmLabels: half a second into its one-second fade, where the view's own is a fifth into 2.5 s)
	check(label ~= nil and label.Text == "lost sight" and near(view.labels[1].alpha, 0.8, 1e-9) and near(hud.labels[1].alpha, 0.5, 1e-9) and near(label.TextTransparency, 1 - hud.labels[1].alpha, 1e-9) and label.Position.Y.Offset > 360, "and 'lost sight' under it, faded by the calm's breath (0.5 at half a second; the view's 0.8)")
	-- the same mark, older: the same twelve bars, shorter
	local old = contact({ position = Vector3.new(0, 5, -10), mark = true, stale = 0.9, age = 2.0 })
	draw(hud, { old })
	local oldBars = shown(parent, "Bar")
	check(#oldBars == 12 and oldBars[1].Size.X.Offset < lengthFresh and near(hud.view.rings[1].dash, 1 - 0.7 * 0.9, 1e-9), "older: still twelve, with shorter dashes (bigger gaps)")
	local dashes = Shapes.dashRing(hud.view.rings[1].pos.X, hud.view.rings[1].pos.Y, hud.view.rings[1].radius, hud.view.rings[1].dash)
	local sameAsShape = true
	for i, b in oldBars do
		sameAsShape = sameAsShape and near(b.Position.X.Offset, dashes[i].x, 1e-9) and near(b.Position.Y.Offset, dashes[i].y, 1e-9) and near(b.Rotation, dashes[i].rotation, 1e-9) and near(b.Size.X.Offset, dashes[i].length, 1e-9)
	end
	check(sameAsShape, "each bar is where the shape says")
	local bs = children(oldBars[1], "UIStroke")
	check(#children(oldBars[1], "UICorner") == 1 and #bs == 1 and bs[1].Thickness == 1 and bs[1].Transparency < 1, "rounded, with a thin dark edge")
	-- hidden marks (the ShowLastSeen switch): no dashes, the words stay
	check(#hud.view.labels == 1 and #shown(parent, "Label") == 0, "two seconds after sight was lost the view still has its words, the screen not: gone in a breath (ROBLOX-113)")
	draw(hud, { old }, false, false)
	check(#shown(parent, "Bar") == 0 and #hud.view.rings == 0, "with the last-seen marks switched off there are no dashes")
	draw(hud, { fresh }, false, false)
	check(#shown(parent, "Bar") == 0 and #shown(parent, "Label") == 1 and shown(parent, "Label")[1].Text == "lost sight", "and the words stay, as in the view")
	-- a mark that is covered is fainter
	local covered: any = function(_eye: Vector3, _at: Vector3): Vector3? return Vector3.new(0, 5, -3) end
	hud:draw(memoryOf({ fresh }), camera, covered, false, nil)
	check(near(hud.view.rings[1].alpha, 0.6 * 0.6, 1e-9) and near(shown(parent, "Bar")[1].BackgroundTransparency, 1 - 0.36, 1e-9), "behind something the dashes are fainter by the view's factor")
end

-- an off-screen cue: a chevron at the edge
do
	local hud, parent = newHud()
	draw(hud, { contact({ cueCount = 1, cueDirection = Vector3.new(1, 0, 0), cueAge = 0.5 }) })
	local view = hud.view
	check(#view.edges == 1 and #view.rings == 0 and #view.labels == 0, "a cue off to the right: one edge mark in the view")
	local bars = shown(parent, "Bar")
	check(#bars == 2 and #shown(parent, "Circle") == 0 and #shown(parent, "Label") == 0, "drawn as two bars")
	local e = view.edges[1]
	local arms = Shapes.chevron(e.pos.X, e.pos.Y, e.dir.X, e.dir.Y)
	local ok = true
	for i, b in bars do
		ok = ok and near(b.Position.X.Offset, arms[i].x, 1e-9) and near(b.Position.Y.Offset, arms[i].y, 1e-9) and near(b.Rotation, arms[i].rotation, 1e-9) and b.Size.Y.Offset == 3 and near(b.BackgroundTransparency, 1 - e.alpha, 1e-9)
	end
	check(ok, "the arms are where the shape says, 3 px thick, at the view's opacity")
	local y1, y2 = bars[1].Position.Y.Offset, bars[2].Position.Y.Offset
	check(bars[1].Position.X.Offset > VIEW.X - 60 and bars[1].Position.X.Offset < VIEW.X and math.min(y1, y2) < VIEW.Y / 2 and math.max(y1, y2) > VIEW.Y / 2 and near(y1 + y2, VIEW.Y, 1e-9), "at the right edge, the two arms either side of the middle's line")
end

-- the Focus ticks
do
	local hud, parent = newHud()
	draw(hud, {}, true)
	local bars = shown(parent, "Bar")
	local at = Shapes.focusTicks(VIEW.X / 2, VIEW.Y / 2)
	local ok = #bars == 4
	for i, b in bars do
		ok = ok and near(b.Position.X.Offset, at[i].x, 1e-9) and near(b.Position.Y.Offset, at[i].y, 1e-9) and b.Size.X.Offset == 10 and b.Size.Y.Offset == 2 and near(b.BackgroundTransparency, 0.2, 1e-9)
	end
	check(ok, "Focus: four ticks around the middle of the screen, at 0.8")
	draw(hud, {}, false)
	check(#shown(parent, "Bar") == 0, "and gone when Focus is not held")
end

-- reuse: nothing is made twice, and what is not used is hidden
do
	local hud, parent = newHud()
	local list = {
		contact({ id = "a", position = Vector3.new(0, 5, -10), inspected = true }),
		contact({ id = "b", position = Vector3.new(2, 5, -10), mark = true, stale = 0.2, age = 1 }),
		contact({ id = "c", cueCount = 1, cueDirection = Vector3.new(-1, 0, 0), cueAge = 0.3 }),
	}
	draw(hud, list, true)
	local made = #parent:GetDescendants()
	-- (ROBLOX-113: the live label and the mark's are in one area of the screen, so one label is drawn: the live one, what the principal eyes hold now)
	check(#shown(parent, "Circle") == 1 and #shown(parent, "Bar") == 12 + 2 + 4 and #hud.view.labels == 2 and #shown(parent, "Label") == 1 and shown(parent, "Label")[1].Text == "fly-like prey", "a live circle, a dashed mark, a cue and Focus together: 1 circle, 18 bars, and of the 2 labels the live one")
	for _ = 1, 30 do draw(hud, list, true) end
	check(#parent:GetDescendants() == made, "thirty more frames make nothing new")
	draw(hud, { list[1] })
	check(#shown(parent, "Circle") == 1 and #shown(parent, "Bar") == 0 and #shown(parent, "Label") == 1, "with less to show, the rest is hidden")
	draw(hud, {})
	check(#shown(parent, "Circle") == 0 and #shown(parent, "Bar") == 0 and #shown(parent, "Label") == 0, "with nothing to show, nothing is")
	draw(hud, list, true)
	check(#parent:GetDescendants() == made and #shown(parent, "Bar") == 18, "and showing it all again makes nothing new")
	check(hud.view ~= nil and hud.view.rings ~= nil, "the view is kept, as the playback tests read it")
end

-- where the label goes when the ring is low on the screen, and sideways
do
	local hud, parent = newHud()
	draw(hud, { contact({ position = Vector3.new(0, 5 - 6, -10), inspected = true }) })
	local c, label = shown(parent, "Circle")[1], shown(parent, "Label")[1]
	check(c ~= nil and c.Position.Y.Offset > 650 and label.Position.Y.Offset < c.Position.Y.Offset, "a ring near the bottom: the label goes above it instead")
	local hud2, parent2 = newHud()
	draw(hud2, { contact({ position = Vector3.new(0, 5, -10), inspected = true }) })
	local l2 = shown(parent2, "Label")[1]
	l2.AbsoluteSize = { X = 200, Y = 28 } -- what the engine measures after the first frame
	draw(hud2, { contact({ position = Vector3.new(0, 5, -10), inspected = true }) })
	check(l2.Position.X.Offset == 640, "a measured label in the middle stays under its ring")
	local hud3, parent3 = newHud()
	local edgeContact = contact({ position = Vector3.new(11.2, 5, -10), inspected = true }) -- 1273 px across
	draw(hud3, { edgeContact })
	local l3 = shown(parent3, "Label")[1]
	l3.AbsoluteSize = { X = 200, Y = 28 }
	draw(hud3, { edgeContact })
	local c3 = shown(parent3, "Circle")[1]
	check(c3.Position.X.Offset > VIEW.X - 20 and l3.Position.X.Offset == VIEW.X - 100 - 8, "a measured label near the right edge is kept on the screen, 8 px in")
end

-- what the view says is what is drawn, however the view comes about
do
	local hud, parent = newHud()
	local direct = View.build(memoryOf({ contact({ position = Vector3.new(0, 5, -10), inspected = true }) }), {
		project = function(_at: Vector3, _size: number) return Vector2.new(640, 360), true, 12 end,
		edge = function(_dir: Vector3) return { pos = Vector2.new(0, 0), dir = Vector2.new(1, 0) } end,
		covered = function(_at: Vector3, _slack: number) return false end,
	}, true)
	check(#direct.rings == 1 and direct.rings[1].alpha == 0.85 and direct.labels[1].text == "fly-like prey" and direct.labels[1].offset == 20, "the pure view is as it was: alpha 0.85, the label's words, the gap radius + 8")
	draw(hud, { contact({ position = Vector3.new(0, 5, -10), inspected = true }) })
	check(hud.view.labels[1].text == shown(parent, "Label")[1].Text and hud.view.rings[1].alpha == 0.85, "and the drawer follows it")
end

-- the hunger bar (ROBLOX-78): the old food bar, renamed; full when fed, emptying as the spider grows hungry
do
	local parent = Instance.new("Folder")
	local hud = SpiderHud.new(parent)
	local function bar(v: number?, gentle: boolean?, large: boolean?): (any, any, any)
		hud:update({ device = "keyboard", food = v, foodGentle = gentle, largeText = large }, 0.016)
		return named(parent, "HungerBar")[1], named(parent, "HungerFill")[1], named(parent, "HungerText")[1]
	end
	local b, f, t = bar(1)
	check(b ~= nil and f ~= nil and t ~= nil and #named(parent, "FoodBar") == 0 and #named(parent, "FoodText") == 0, "the bar is the Hunger bar; no FoodBar is left")
	check(b.Visible and f.Size.X.Scale == 1 and t.Text == "Hunger 100%", "a fed spider: a full bar that says Hunger 100%")
	b, f, t = bar(0.55)
	check(f.Size.X.Scale == 0.55 and t.Text == "Hunger 55%", "the fill is the reserve")
	b, f, t = bar(0.2)
	check(t.Text == "Hunger 20% · hungry" and f.BackgroundColor3.R > f.BackgroundColor3.G, "hungry at a quarter, and the fill turns amber-brown")
	b, f, t = bar(0)
	check(f.Size.X.Scale == 0 and t.Text == "Hunger 0% · starving", "empty is starving")
	b, f, t = bar(0, true)
	check(t.Text == "Hunger 0% · gentle", "gentle play never says starving")
	b, f, t = bar(0.5, false, true)
	check(t.TextSize == 24, "large text")
	-- the quiet screen (ROBLOX-125): a thin line without a plate, settling once read, never while hungry
	b, f, t = bar(0.8)
	check(b.BackgroundTransparency == 1 and f.Parent.Size.Y.Offset == 5 and b.Size.X.Offset == 220, "a 5 px line, 220 px wide, no plate")
	check(t.TextTransparency == 0, "new words at full strength")
	for _ = 1, 500 do bar(0.8) end
	check(t.TextTransparency > 0.7 and f.BackgroundTransparency > 0.5, "after eight seconds unchanged the line has settled to a trace")
	bar(0.75)
	check(t.TextTransparency == 0, "a change brings it back")
	bar(0.3); for _ = 1, 500 do bar(0.3) end
	check(t.TextTransparency == 0, "hungry: it never settles")
	check(SpiderHud.settle(0) == 0 and SpiderHud.settle(4.9) == 0 and math.abs(SpiderHud.settle(99) - 0.8) < 1e-9, "settle: full, then 0.8 at rest")
	b = bar(nil)
	check(not b.Visible, "no reserve in the view: the bar is hidden")
	for _, d in parent:GetDescendants() do
		if d.ClassName == "TextLabel" and type(d.Text) == "string" and d.Text ~= "" then check(not string.find(string.lower(d.Text), "food"), "no word 'food' on the screen: " .. d.Text) end
	end
end

-- the courtship meter (ROBLOX-80): the grip bar's style, in its own colour, shown only while the view carries a courtship level
do
	local parent = Instance.new("Folder")
	local hud = SpiderHud.new(parent)
	local function bar(v: number?): (any, any)
		hud:update({ device = "keyboard", court = v }, 0.016)
		return named(parent, "CourtshipBar")[1], named(parent, "Courtship")[1]
	end
	local b, f = bar(nil)
	check(b ~= nil and f ~= nil and not b.Visible, "the courtship bar exists and is hidden while there is nothing to court")
	b, f = bar(0)
	check(b.Visible and f.Size.X.Scale == 0, "empty: shown, nothing in it")
	b, f = bar(0.4)
	check(b.Visible and f.Size.X.Scale == 0.4, "the fill is the meter")
	b, f = bar(1.7)
	check(f.Size.X.Scale == 1, "clamped to 1")
	b, f = bar(-1)
	check(f.Size.X.Scale == 0, "and to 0")
	local grip = named(parent, "GripBar")[1]
	check(b.Size.X.Scale == grip.Size.X.Scale and b.Size.Y.Offset == grip.Size.Y.Offset and b.LayoutOrder == grip.LayoutOrder, "the grip bar's width, height and place in the column")
	check(f.BackgroundColor3 ~= named(parent, "Grip")[1].BackgroundColor3, "in a colour of its own, not the grip's red")
	b = bar(nil)
	check(not b.Visible and not grip.Visible, "gone again, and the grip bar is not the one that shows")
end

-- the one toast label has priorities (ROBLOX-92): danger over warning over information; a lower one waits out the higher and is dropped, an equal or higher one replaces it,
-- and once the seconds are over anything may show again
do
	local parent = Instance.new("Folder")
	local hud = SpiderHud.new(parent)
	local function toast(): any return named(parent, "Toast")[1] end
	hud:toast("A plain thing", false)
	check(toast().Text == "A plain thing" and toast().Visible, "information shows")
	hud:toast("A warning", true)
	check(toast().Text == "A warning", "a warning replaces information")
	hud:toast("More information", false)
	check(toast().Text == "A warning", "information does not replace a warning")
	hud:toast("Something is coming", "danger")
	check(toast().Text == "Something is coming", "a danger replaces a warning")
	local dangerColor = toast().TextColor3
	hud:toast("A warning again", true)
	hud:toast("Plain again", false)
	hud:toast("", "danger")
	check(toast().Text == "Something is coming", "neither a warning nor information replaces a danger, and an empty text is nothing")
	for _ = 1, 100 do hud:update({ device = "keyboard" }, 0.016) end -- 1.6 s
	check(toast().Visible and toast().Text == "Something is coming", "a danger is still there before its seconds are over")
	hud:toast("Another danger", "danger")
	check(toast().Text == "Another danger" and toast().TextColor3 == dangerColor, "an equal one replaces it, in the danger colour")
	for _ = 1, 200 do hud:update({ device = "keyboard" }, 0.016) end -- 3.2 s
	check(not toast().Visible, "it goes when its seconds are over")
	hud:toast("Plain at last", false)
	check(toast().Visible and toast().Text == "Plain at last" and toast().TextColor3 ~= dangerColor, "and then the plainest toast shows again, in its own colour")
	local warnColor
	hud:toast("A warning", true)
	warnColor = toast().TextColor3
	check(warnColor ~= dangerColor, "a warning and a danger differ in colour")
end

print(`HUD passed={passed} failed={failed}`)
if failed > 0 then error("hud checks failed") end
