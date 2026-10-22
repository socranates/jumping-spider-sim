local awaitReturn=require("./studio/AwaitReturn")
-- Inspect mode (ROBLOX-90): a slow, close look at the drawn spider. The pure numbers first (Movement/InspectView: the orbit, the zoom, the three framings, the
-- ease, Reduced Motion) and the words (UI/InspectText), then the real client on the box world with stub Roblox services (tests/shim.luau): the entry from the Settings
-- row and by holding the choose key or button (and a tap still changing spider), the refusals, the camera's ease in, orbit, zoom and framings, the lock on the
-- controls, the HUD, hanging on the line, the reasons it ends (Cancel, a jump, the choose key again, a menu, a wasp, the rival's windup, an unsafe spider), the restore of the camera and the
-- eye view, the pinch, and Reduced Motion. Not evidence of how it looks, feels or runs on a device: nothing here has run in Studio.
local InspectView = require("../src/Shared/Movement/InspectView")
local InspectText = require("../src/Shared/UI/InspectText")
local ControlText = require("../src/Shared/UI/ControlText")
local PeacockText = require("../src/Shared/UI/PeacockText")
local SpiderChoice = require("../src/Shared/Rig/SpiderChoice")
local SpiderRig = require("../src/Shared/Rig/SpiderRig")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")

local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL inspect: " .. name .. "\n    " .. tostring(err)) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

-- ---------------------------------------------------------------- the numbers
check("the numbers: 0.8 s eases, 1.6 body-lengths and 20 degrees up to begin, 10 degrees a second after 3 s idle, a zoom of 1.1 to 3, a hold of 0.6 s", function()
	assert(InspectView.EASE_SECONDS == 0.8 and InspectView.HOLD_SECONDS == 0.6 and InspectView.DISTANCE == 1.6 and InspectView.ELEVATION_DEG == 20 and InspectView.AUTO_DEG_S == 10 and InspectView.AUTO_AFTER_SECONDS == 3, "the brief's numbers")
	assert(InspectView.ZOOM_MIN == 1.1 and InspectView.ZOOM_MAX == 3.0, "the zoom's ends")
	local s = InspectView.new(200)
	assert(s.yaw == -160 and s.elev == 20 and s.dist == 1.6 and s.ahead == 0 and s.auto and s.idle == InspectView.AUTO_AFTER_SECONDS and s.preset == 0 and s.goal == nil, "a new view begins where it is told, 1.6 away and 20 up, already idle (so orbiting)")
end)

check("the yaw: 0 is in front of the spider, 90 on its right, 180 behind; the direction is a unit vector from the focus, lifted by the elevation", function()
	local f, up = Vector3.new(0, 0, -1), Vector3.yAxis
	local r = f:Cross(up)
	assert((r - Vector3.new(1, 0, 0)).Magnitude < 1e-9, "(right is +X for a spider facing -Z)")
	local s = InspectView.new(0)
	s.elev = 0.0001
	local d0 = InspectView.direction(s, f, r, up)
	assert((d0 - f).Magnitude < 1e-3, "yaw 0: in front")
	s.yaw = 90
	assert((InspectView.direction(s, f, r, up) - r).Magnitude < 1e-3, "yaw 90: on its right")
	s.yaw = 180
	assert((InspectView.direction(s, f, r, up) + f).Magnitude < 1e-3, "yaw 180: behind")
	s.elev = 30
	s.yaw = 45
	local d = InspectView.direction(s, f, r, up)
	assert(near(d.Magnitude, 1, 1e-9) and near(math.deg(math.asin(d:Dot(up))), 30, 1e-6), "a unit vector, 30 degrees up")
	assert(near(InspectView.yawOf(r * 2 + f * 0.0001, f, r), 90, 0.01) and near(InspectView.yawOf(-f, f, r), 180, 1e-6) and near(InspectView.yawOf(-r, f, r), -90, 1e-6), "yawOf reads a camera's offset back")
end)

check("the auto-orbit: 10 degrees a second once the player has been idle for 3 s (a new view is idle already), none in Reduced Motion, and the player's own turn holds it off for 3 s", function()
	local s = InspectView.new(180)
	for _ = 1, 180 do InspectView.step(s, 1 / 60, false) end
	assert(near(s.yaw, -180 + 30, 1e-6), `a new view orbits at once: three seconds is 30 degrees ({s.yaw})`)
	local r = InspectView.new(90)
	for _ = 1, 180 do InspectView.step(r, 1 / 60, true) end
	assert(r.yaw == 90 and r.auto, "Reduced Motion: no orbit of its own (the view is still ready for the player's)")
	local y = s.yaw
	InspectView.orbit(s, 10, 0)
	assert(s.idle == 0 and near(s.yaw, y + 10, 1e-6), "a turn to the right moves the camera to the spider's right (and the player is not idle)")
	for _ = 1, 178 do InspectView.step(s, 1 / 60, false) end -- 2.97 s
	assert(near(s.yaw, y + 10, 1e-6), `the orbit waits ({s.yaw})`)
	for _ = 1, 62 do InspectView.step(s, 1 / 60, false) end -- 4 s in all, 1 s of it orbiting
	assert(near(s.yaw, y + 10 + 10, 0.2), `and after 3 s idle it goes on at 10 degrees a second ({s.yaw - y})`)
	-- each turn starts the wait again; a frame's length does not change the rate
	local w = InspectView.new(0)
	for _ = 1, 10 do InspectView.orbit(w, 1, 0); for _ = 1, 100 do InspectView.step(w, 1 / 60, false) end end
	assert(near(w.yaw, 10, 1e-6), "turns less than 3 s apart never let it start")
	local slow, fast = InspectView.new(0), InspectView.new(0)
	for _ = 1, 30 do InspectView.step(slow, 1 / 30, false) end
	for _ = 1, 240 do InspectView.step(fast, 1 / 240, false) end
	assert(near(slow.yaw, 10, 1e-6) and near(fast.yaw, 10, 1e-6), "10 degrees in a second at any frame rate")
	-- the wrap, and the elevation limits
	local v = InspectView.new(175)
	InspectView.orbit(v, 20, 0)
	assert(near(v.yaw, -165, 1e-6), "the yaw wraps")
	InspectView.orbit(v, 0, 200)
	assert(v.elev == InspectView.ELEVATION_MAX_DEG, "and the elevation stops at 88")
	InspectView.orbit(v, 0, -500)
	assert(v.elev == InspectView.ELEVATION_MIN_DEG, "and at 4")
	InspectView.orbit(v, 0, 0)
	local idle = v.idle
	InspectView.orbit(v, 0, 0)
	assert(v.idle == idle, "a turn of nothing is not a turn")
	-- a reduced-motion view that gets a frame of dt 0 or a negative one does nothing odd
	local z = InspectView.new(10)
	InspectView.step(z, 0, false); InspectView.step(z, -1, false)
	assert(z.yaw == 10, "no time, no orbit")
end)

check("the zoom: a step of the left stick, a notch of the wheel, a pinch, always between 1.1 and 3 body-lengths; zooming is not idle, but it does not stop the auto-orbit's turn once it is going", function()
	local s = InspectView.new(0)
	InspectView.zoomBy(s, -0.25)
	assert(near(s.dist, 1.35, 1e-9) and s.auto and s.idle == 0, "closer by 0.25; the player is not idle")
	InspectView.zoomBy(s, -5)
	assert(s.dist == 1.1, "stops at 1.1")
	InspectView.zoomBy(s, 9)
	assert(s.dist == 3.0, "and at 3")
	InspectView.wheel(s, true)
	assert(near(s.dist, 3.0 * 0.88, 1e-9), "a wheel notch toward the screen is 12 percent closer")
	InspectView.wheel(s, false)
	assert(near(s.dist, 3.0, 1e-9), "and one the other way is 12 percent further (and the end is the end)")
	for _ = 1, 40 do InspectView.wheel(s, true) end
	assert(s.dist == 1.1, "and cannot go in past 1.1")
	for _ = 1, 40 do InspectView.wheel(s, false) end
	assert(s.dist == 3.0, "or out past 3")
	-- the pinch: fingers spreading by a ratio is that much closer, pinched together is further
	InspectView.pinch(s, 1.5)
	assert(near(s.dist, 2.0, 1e-9), "spreading by half again: a third closer")
	InspectView.pinch(s, 0.5)
	assert(near(s.dist, 3.0, 1e-9) , "pinching to half: twice as far, to the end")
	InspectView.pinch(s, 100)
	assert(s.dist == 1.1, "a huge spread stops at 1.1")
	local keep = s.dist
	for _, bad in { 0, -1, 1, 0 / 0, math.huge } do InspectView.pinch(s, bad) end
	assert(s.dist == keep, "a ratio of nothing, a negative one, no change, not a number or infinity do nothing")
	-- a framing's trip is cancelled by any zoom, but the framing's hold on the auto-orbit is not lifted
	local f = InspectView.new(90)
	InspectView.cycle(f)
	InspectView.zoomBy(f, -0.1)
	assert(f.goal == nil and not f.auto, "a zoom ends the trip but the framing is still held still")
	-- a zoom delays a running auto-orbit
	local o = InspectView.new(0)
	for _ = 1, 60 do InspectView.step(o, 1 / 60, false) end
	InspectView.zoomBy(o, 0.1)
	local y = o.yaw
	for _ = 1, 120 do InspectView.step(o, 1 / 60, false) end
	assert(o.yaw == y, "zooming makes the view wait 3 s for the orbit as a turn does")
end)

check("the three framings: face, side, top, then face again; each is reached in about a third of a second, a cut in Reduced Motion, and the player's turn ends the trip", function()
	assert(#InspectView.PRESETS == 3 and InspectView.PRESETS[1].id == "face" and InspectView.PRESETS[2].id == "side" and InspectView.PRESETS[3].id == "top", "face, side, top")
	for _, p in InspectView.PRESETS do
		assert(p.distance >= InspectView.ZOOM_MIN and p.distance <= InspectView.ZOOM_MAX and p.elevDeg >= InspectView.ELEVATION_MIN_DEG and p.elevDeg <= InspectView.ELEVATION_MAX_DEG, `{p.id} is inside the limits`)
	end
	local s = InspectView.new(180)
	assert(InspectView.cycle(s) == "face" and not s.auto and s.goal ~= nil and InspectView.presetId(s) == "face", "the first press: the face; the auto-orbit stops")
	for _ = 1, 21 do InspectView.step(s, 1 / 60, false) end -- 0.35 s: 95 percent of a trip of 180 degrees
	assert(near(math.abs(s.yaw), 9, 1) and near(s.elev, 10.5, 0.1) and near(s.dist, 1.26, 0.01), `the face after 0.35 s is 95 percent of the way ({s.yaw}, {s.elev}, {s.dist}, {s.ahead})`)
	for _ = 1, 9 do InspectView.step(s, 1 / 60, false) end -- half a second
	assert(near(s.yaw, 0, 3) and near(s.elev, 10, 0.2) and near(s.dist, 1.25, 0.01) and near(s.ahead, 0.3, 0.01), `and nearly there at half a second ({s.yaw}, {s.elev}, {s.dist}, {s.ahead})`)
	for _ = 1, 120 do InspectView.step(s, 1 / 60, false) end
	assert(s.goal == nil and s.yaw == 0 and s.elev == 10 and s.dist == 1.25 and s.ahead == 0.3, "and then exactly")
	assert(InspectView.cycle(s) == "side" and InspectView.cycle(s) == "top" and InspectView.cycle(s) == "face", "side, top, face")
	local r = InspectView.new(180)
	InspectView.cycle(r)
	InspectView.step(r, 1 / 60, true)
	assert(r.goal == nil and r.yaw == 0 and r.dist == 1.25, "Reduced Motion: a cut")
	-- the shortest way round
	local w = InspectView.new(170)
	InspectView.cycle(w) -- face: yaw 0 ... a trip of 170 degrees; side next from -170 goes the short way
	for _ = 1, 200 do InspectView.step(w, 1 / 60, false) end
	w.yaw = -170
	InspectView.cycle(w) -- side: 90, from -170 the short way is through 180 (100 degrees), not through 0 (260)
	InspectView.step(w, 1 / 60, false)
	assert(w.yaw > 170 or w.yaw < -170, `the short way round, away from 0 ({w.yaw})`)
	local t = InspectView.new(0)
	InspectView.cycle(t)
	InspectView.step(t, 1 / 60, false)
	InspectView.orbit(t, 5, 0)
	assert(t.goal == nil, "the player's turn ends the trip")
	-- a framing holds still (no auto-orbit for ever); the player's turn gives the orbit back, after the 3 s
	local h = InspectView.new(0)
	InspectView.cycle(h)
	for _ = 1, 600 do InspectView.step(h, 1 / 60, false) end
	local at = h.yaw
	for _ = 1, 600 do InspectView.step(h, 1 / 60, false) end
	assert(h.yaw == at and h.yaw == 0, "ten more seconds and the framing has not moved")
	InspectView.orbit(h, 5, 0)
	for _ = 1, 240 do InspectView.step(h, 1 / 60, false) end
	assert(near(h.yaw, 5 + 10, 0.2), `after a turn of its own and 3 s, the orbit is back ({h.yaw})`)
	assert(InspectView.presetId(h) == "face", "(the cycle still remembers where it was)")
	assert(InspectView.cycle(h) == "side", "(and goes on to the next)")
end)

check("the ease: 0.8 s in, 0.8 s out, from end to end, and a cut in Reduced Motion; a reversal part-way turns back from where it is", function()
	local t = 0
	for _ = 1, 24 do t = InspectView.ease(t, 1 / 60, true, false) end
	assert(near(t, 0.5, 1e-9), `half in 0.4 s ({t})`)
	for _ = 1, 26 do t = InspectView.ease(t, 1 / 60, true, false) end
	assert(t == 1, "whole by 0.8 s")
	for _ = 1, 24 do t = InspectView.ease(t, 1 / 60, false, false) end
	assert(near(t, 0.5, 1e-9), "and half out in 0.4 s")
	for _ = 1, 26 do t = InspectView.ease(t, 1 / 60, false, false) end
	assert(t == 0, "back by 0.8 s")
	assert(InspectView.ease(0, 1 / 60, true, true) == 1 and InspectView.ease(1, 1 / 60, false, true) == 0, "Reduced Motion: cuts")
	local u = InspectView.ease(0.3, 1 / 60, false, false)
	assert(near(u, 0.3 - 1 / 48, 1e-9), "turning back at 0.3 goes down from 0.3, not from 1")
	assert(InspectView.ease(0.5, 0.4, true, false) == 1 and InspectView.ease(0.5, 5, false, false) == 0 and InspectView.ease(0.5, 0, true, false) == 0.5 and InspectView.ease(0.5, -1, true, false) == 0.5, "a long frame does not overshoot; none, or a negative one, does not move it")
	local half, whole = 0, 0
	for _ = 1, 12 do half = InspectView.ease(half, 1 / 30, true, false) end
	for _ = 1, 24 do whole = InspectView.ease(whole, 1 / 30, true, false) end
	assert(near(half, 0.5, 1e-9) and near(whole, 1, 1e-9), "the same 0.8 s at 30 frames a second")
	assert(InspectView.smooth(0) == 0 and InspectView.smooth(1) == 1 and near(InspectView.smooth(0.5), 0.5, 1e-9), "smoothstep")
	local last = 0
	for k = 1, 100 do
		local v = InspectView.smooth(k / 100)
		assert(v >= last and v <= 1, "and it only rises")
		last = v
	end
end)

check("any run of turns, zooms, pinches, framings and frames keeps the view inside its limits and the direction a unit vector (400 seeded runs)", function()
	local seed = 20261018
	local function rnd(): number
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local f, up = Vector3.new(0, 0, -1), Vector3.yAxis
	local r = f:Cross(up)
	for run = 1, 400 do
		local s = InspectView.new(rnd() * 720 - 360)
		for _ = 1, 60 do
			local k = math.floor(rnd() * 7)
			if k == 0 then InspectView.orbit(s, (rnd() - 0.5) * 500, (rnd() - 0.5) * 500)
			elseif k == 1 then InspectView.zoomBy(s, (rnd() - 0.5) * 8)
			elseif k == 2 then InspectView.wheel(s, rnd() < 0.5)
			elseif k == 3 then InspectView.pinch(s, rnd() * 3)
			elseif k == 4 then InspectView.cycle(s)
			else InspectView.step(s, rnd() * 0.1, rnd() < 0.2) end
			assert(s.dist >= InspectView.ZOOM_MIN and s.dist <= InspectView.ZOOM_MAX, `run {run}: the distance {s.dist}`)
			assert(s.elev >= InspectView.ELEVATION_MIN_DEG - 1e-9 and s.elev <= InspectView.ELEVATION_MAX_DEG + 1e-9, `run {run}: the elevation {s.elev}`)
			assert(s.yaw >= -180 and s.yaw < 180, `run {run}: the yaw {s.yaw}`)
			assert(s.idle >= 0 and s.ahead >= 0 and s.ahead <= 0.3 + 1e-9, `run {run}: idle {s.idle}, ahead {s.ahead}`)
			assert(near(InspectView.direction(s, f, r, up).Magnitude, 1, 1e-9), "a unit direction")
		end
	end
end)

check("who may look closely: standing or hanging on a locked line, and not winding up, in the air, seized, moulting or holding a struggling fly (the change of spider still refuses a line)", function()
	local function st(o: any): SpiderChoice.Standing
		local s = { mode = "attached", seized = false, preparing = false, jumping = false, onLine = false, moulting = false, struggling = false }
		for k, v in o do (s :: any)[k] = v end
		return s
	end
	assert(SpiderChoice.safeToInspect(st({})), "standing")
	assert(SpiderChoice.safeToInspect(st({ mode = "air", onLine = true })), "hanging on the line (the motor is in its air mode)")
	assert(not SpiderChoice.safeToInspect(st({ mode = "air" })), "in the air, with no line")
	assert(not SpiderChoice.safeToInspect(st({ mode = "air", onLine = true, jumping = true })), "a jump in flight with a safety line is not hanging")
	assert(not SpiderChoice.safeToInspect(st({ preparing = true })) and not SpiderChoice.safeToInspect(st({ jumping = true })), "winding up, or jumping")
	assert(not SpiderChoice.safeToInspect(st({ seized = true })) and not SpiderChoice.safeToInspect(st({ seized = true, mode = "air", onLine = true })), "seized")
	assert(not SpiderChoice.safeToInspect(st({ moulting = true })) and not SpiderChoice.safeToInspect(st({ struggling = true })), "moulting, or in the struggle")
	assert(SpiderChoice.safeToChange(st({})) and not SpiderChoice.safeToChange(st({ mode = "air", onLine = true })), "(and a change of spider is as it was)")
end)

-- ---------------------------------------------------------------- the words
check("the words: the name line, one line of controls for each device (PlayStation names too), the hold hint, the framings, the card's line", function()
	for _, id in SpiderChoice.ORDER do
		assert(InspectText.nameLine(id) == PeacockText.title(id) and string.sub(InspectText.nameLine(id), 1, 4) == "The ", `{id}: its name`)
	end
	assert(InspectText.nameLine("first_spider") == "The first spider" and InspectText.nameLine("maratus_volans_male") == "The peacock spider", "the names")
	assert(InspectText.hint("keyboard") == "Mouse: orbit    Wheel or W S: zoom    V: face, side, top    Q or C: back", InspectText.hint("keyboard"))
	assert(InspectText.hint("gamepad") == "Right stick: orbit    Left stick: zoom    Y: face, side, top    B or RB: back", InspectText.hint("gamepad"))
	assert(InspectText.hint("touch") == "Drag: orbit    Pinch or ↑ ↓: zoom    View: face, side, top    Back: leave", InspectText.hint("touch"))
	ControlText.setPadStyle("playstation")
	assert(InspectText.hint("gamepad") == "Right stick: orbit    Left stick: zoom    Triangle: face, side, top    Circle or R1: back", InspectText.hint("gamepad"))
	assert(InspectText.holdHint("gamepad") == "hold R1: look closely", "the hold hint on a PlayStation controller")
	ControlText.setPadStyle("xbox")
	assert(InspectText.holdHint("keyboard") == "hold C: look closely" and InspectText.holdHint("gamepad") == "hold RB: look closely" and InspectText.holdHint("touch") == "hold Change: look closely", "the hold hint by device")
	assert(InspectText.framing("face") == "Framing: Face" and InspectText.framing("side") == "Framing: Side" and InspectText.framing("top") == "Framing: From above", "the framings")
	assert(InspectText.BUTTON == "Look closely" and InspectText.TOUCH_BACK == "Back" and InspectText.TOUCH_VIEW == "View", "the button and the touch words")
	for _, d in { "keyboard", "gamepad", "touch" } do
		-- (ROBLOX-92: the controls card has no line of its own for the close look; the crack's line says how, with the device's own name for the key)
		local line = PeacockText.crackLine(d :: any)
		assert(string.find(line, "look closely", 1, true) and not string.find(line, "\n", 1, true), `{d}: the crack's line says it, in one line`)
		assert(string.find(line, ControlText.name(d :: any, "choose"), 1, true), `{d}: with the device's name for the key`)
		assert(InspectText.helpLine == nil, "the old card line is gone")
	end
	local all = { InspectText.NOT_NOW, InspectText.DANGER, InspectText.ENDED, InspectText.hint("keyboard"), PeacockText.crackLine("keyboard") }
	for _, text in all do
		local lower = string.lower(text)
		assert(not string.find(lower, "kill") and not string.find(lower, "die") and not string.find(lower, "dead") and not string.find(lower, "blood"), "child-safe: " .. text)
	end
end)

check("the drawn body's length in studs, for the camera's body-lengths: 0.97 at the first stage on every tier (1.455 as an adult), smaller for the small spiders, and it grows with the stage", function()
	local floor = BoxWorld.folder("InspectFloor", { { name = "floor", lo = Vector3.new(-5, -1, -5), hi = Vector3.new(5, 0, 5), profile = "painted_wood_dry" } })
	local full = SpiderRig.new(floor, floor, nil, "full")
	local low = SpiderRig.new(floor, floor, nil, "low")
	assert(near(full:bodyLength(), 0.97, 1e-9) and near(low:bodyLength(), 0.97, 1e-9), `the first spider: {full:bodyLength()}, {low:bodyLength()} (the low tier is the same size, with fewer parts)`)
	full:setGrowthStage(3)
	assert(near(full:bodyLength(), 0.97 * 1.5, 1e-9), `an adult is 1.5 times it ({full:bodyLength()})`)
	full:setGrowthStage(1)
	assert(near(full:bodyLength(), 0.97 * 1.15, 1e-9), "and a stage between")
	full:setGrowthStage(0)
	local peacock = SpiderRig.new(floor, floor, "maratus_volans_male", "full")
	local ant = SpiderRig.new(floor, floor, "myrmarachne_formicaria_female", "full")
	-- (ROBLOX-114: at their first stage's own growth, 0.74 and 0.82, so that their adults are the real 5 and 6 mm)
	assert(near(peacock:bodyLength(), 0.97 * 0.47 * 0.74, 1e-9) and near(ant:bodyLength(), 0.97 * 0.5 * 0.82, 1e-9), `smaller bodies for the small spiders ({peacock:bodyLength()}, {ant:bodyLength()})`)
	for _, r in { full, low, peacock, ant } do r:destroy() end
end)

-- ---------------------------------------------------------------- the real client
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local services = ClientStubs
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local player = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function seconds(s: number) frames(math.floor(s * 60 + 0.5)) end
local KEYS = { Feed = "E", Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Eye = "V", Recenter = "R", Choose = "C", Display = "X", Slow = "T", Focus = "Q", Help = "H" }
local function key(action: string, down: boolean)
	local fn = services.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function tap(action: string) key(action, true); frames(2); key(action, false); frames(2) end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
local function words(name: string): string
	local d = find("SpiderPrompts", name)
	return if d and d.Visible then d.Text else ""
end
local CRACK = Vector3.new(-25.5, 0.31, 6.0)
local OPEN = Vector3.new(-5, 0.31, -9)
-- (ROBLOX-110: the start's save status is settled first. With no server it turns "offline" after SaveRules.CLIENT_WAIT_REMOTES seconds of the wall clock, and its
-- toast landed on whichever check was running then; since the shim got fast (ROBLOX-108) that was the choose key's refusal, whose toast it covered. Settled here,
-- before any check, the run no longer depends on how fast the machine is.)
do
	local t0 = os.clock()
	while ClientStubs.driver ~= nil and ClientStubs.driver.saveState.status == nil and os.clock() - t0 < 10 do frame(1 / 60) end
	frame(1 / 60)
end
-- The settings panel's own input (a Context Action above the game's).
local function panelKey(code: string, state: any?)
	local fn = services.actions["WindowsillSettings"]
	assert(fn, "the settings are not listening")
	fn("WindowsillSettings", state or Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end

-- Where the camera is round the spider, in the units of the view: distance in body-lengths from the focus, the yaw from its heading (degrees, right positive), the
-- elevation above its surface (degrees).
local function view(d: any): (number, number, number)
	local up = d.motor.up
	local f = d.motor.heading - up * d.motor.heading:Dot(up)
	f = f.Unit
	local r = f:Cross(up)
	local len = d.rig():bodyLength()
	local focus = d.motor.pos - up * d.rig()._drop + f * (d.cam.inspect.ahead * len)
	local off = d.cam.camera.CFrame.Position - focus
	return off.Magnitude / len, InspectView.yawOf(off, f, r), math.deg(math.asin(off.Unit:Dot(up)))
end
local function angleBetween(a: number, b: number): number return math.abs((b - a + 180) % 360 - 180) end

check("the client loads and runs 120 frames, and is not looking closely", function()
	assert(loaded, "SpiderClient did not load")
	frames(120)
	local d = ClientStubs.driver
	assert(d.spiderPick ~= nil and d.spiderPick.inspecting == false and d.cam.inspect == nil and not d.cam:inspectActive(), "the close look is idle")
end)

local function rest(d: any, where: Vector3?)
	d.place(where or CRACK)
	frames(30)
	d.life.clock.hour = 12
	frames(2)
	if not d.life.resting then tap("Feed") end
	assert(d.life.resting and not d.life.asleep, "E did not rest")
end
local function unrest(d: any)
	if d.life.resting then tap("Feed") end
	assert(not d.life.resting, "E did not end the rest")
end
local function leave(d: any)
	if d.spiderPick.inspecting then d.spiderPick.finish(nil, true) end
	frames(2)
end

check("the choose key: a tap still changes spider (when it is let go), a hold of 0.6 s starts the close look and changes nothing", function()
	local d = ClientStubs.driver
	local startAs = d.appearance()
	rest(d)
	assert(string.find(words("PromptHint"), "hold C: look closely", 1, true), words("PromptHint"))
	-- A tap: 0.1 s down. Changed when let go, not before.
	key("Choose", true); frames(6)
	assert(d.appearance() == startAs and not d.spiderPick.inspecting, "nothing happens while it is down")
	key("Choose", false); frames(2)
	assert(d.appearance() == SpiderChoice.next(startAs) and not d.spiderPick.inspecting and d.life.resting, "a tap changes spider when it is let go, and the rest goes on")
	-- Just under 0.6 s is still a tap.
	local second = d.appearance()
	key("Choose", true); frames(33)
	assert(not d.spiderPick.inspecting and d.appearance() == second, "0.55 s is not yet a hold")
	key("Choose", false); frames(2)
	assert(d.appearance() == SpiderChoice.next(second) and not d.spiderPick.inspecting, "and let go it is a tap")
	local third = d.appearance()
	-- A hold.
	key("Choose", true); frames(40)
	assert(d.spiderPick.inspecting and d.cam.inspect ~= nil, "0.67 s down: the close look begins")
	key("Choose", false); frames(2)
	assert(d.appearance() == third and d.spiderPick.inspecting, "and letting go changes nothing")
	assert(d.life.resting and d.motor.mode == "attached", "the spider is where it was, resting")
	-- The same key again leaves.
	tap("Choose")
	assert(not d.spiderPick.inspecting and d.cam.inspect == nil and d.appearance() == third, "the choose key again leaves it, and does not also change spider")
	seconds(1)
	assert(not d.cam:inspectActive(), "(and the camera is back after its ease)")
	-- Back to the first spider for the tests that follow.
	for _ = 1, 5 do if d.appearance() ~= startAs then tap("Choose") end end
	assert(d.appearance() == startAs, "(the first spider again)")
	unrest(d)
end)

check("the choose key refuses when it is not safe: outside the crack a press says so at once; seized, preparing a jump, moulting or in the struggle, a hold says it will not now", function()
	local d = ClientStubs.driver
	d.place(OPEN)
	frames(30)
	key("Choose", true); frames(40); key("Choose", false); frames(2)
	assert(not d.spiderPick.inspecting and words("Toast") == PeacockText.NOT_RESTING, `outside the crack: "{words("Toast")}"`)
	rest(d)
	local function refuses(name: string, on: () -> (), off: () -> ())
		on()
		key("Choose", true); frames(40)
		assert(not d.spiderPick.inspecting and d.cam.inspect == nil, name .. ": it began")
		assert(words("Toast") == InspectText.NOT_NOW or d.life.growth:isMoulting(), `{name}: the toast is "{words("Toast")}"`)
		key("Choose", false); frames(2)
		off()
		assert(d.appearance() == "first_spider", name .. ": and it changed spider")
	end
	refuses("seized", function() d.motor.seized = true end, function() d.motor.seized = false end)
	refuses("preparing a jump", function() d.motor.preparing = true end, function() d.motor.preparing = false end)
	assert(d.spiderPick.refusal() == nil, "(safe again)")
	d.prey.feeding.struggling = true
	assert(d.spiderPick.refusal() == InspectText.NOT_NOW, "in the fly struggle it is refused")
	d.prey.feeding.struggling = false
	assert(d.spiderPick.refusal() == nil, "(safe again)")
	-- moulting (pretended for one check with no frames in between: the life loop would act on it)
	local real = d.life.growth.isMoulting
	d.life.growth.isMoulting = function(): boolean return true end
	assert(d.spiderPick.refusal() == InspectText.NOT_NOW, "moulting: refused")
	d.life.growth.isMoulting = nil
	assert(d.life.growth.isMoulting == real and d.spiderPick.refusal() == nil, "(and the class's own again)")
	unrest(d)
end)

check("from the Settings: the Inspect your spider row is a button; Enter closes the panel into the close look, anywhere the spider stands safely", function()
	local d = ClientStubs.driver
	d.place(OPEN)
	frames(30)
	assert(not d.spiderPick.inspecting, "(not yet)")
	d.openSettings("game")
	assert(d.settingsPanel:isShowing(), "the panel is open")
	d.settingsPanel.nav:selectId("Inspect")
	local w
	for _, x in d.settingsPanel.widgets do if x.kind == "setting" and x.id == "Inspect" then w = x end end
	assert(w ~= nil and w.label.Text == "Inspect your spider" and w.value.Text == "Look closely", "the row is there")
	-- Left and Right do nothing to it.
	panelKey("Right"); panelKey("Right", Enum.UserInputState.End)
	assert(d.settingsPanel:isShowing() and not d.spiderPick.inspecting, "Right does nothing")
	panelKey("Return")
	assert(not d.settingsPanel:isShowing(), "Enter closes the panel")
	assert(d.spiderPick.inspecting and d.cam.inspect ~= nil, "and the close look begins")
	assert(d.settingsPanel.returnTo == nil, "(nothing left to return to)")
	frames(2)
	assert(find("SpiderPrompts", "PromptTitle").Visible and words("PromptTitle") == "The first spider", `the name line: "{words("PromptTitle")}"`)
	d.spiderPick.finish(nil, true)
	frames(2)
end)

check("from the Settings, opened from the life menu: it closes the panel into the game, not back to the menu", function()
	local d = ClientStubs.driver
	d.place(OPEN)
	frames(30)
	d.openMenu()
	assert(d.menu:isShowing(), "the menu is open")
	d.openSettings("menu")
	assert(d.settingsPanel:isShowing() and not d.menu:isShowing(), "the settings, from the menu")
	d.settingsPanel.nav:selectId("Inspect")
	panelKey("Return")
	assert(not d.settingsPanel:isShowing() and not d.menu:isShowing() and d.spiderPick.inspecting, "the close look, and no menu")
	leave(d)
end)

check("from the Settings, not now: the panel stays open and says why; the spider does not change", function()
	local d = ClientStubs.driver
	d.place(OPEN)
	frames(30)
	d.motor.seized = true
	d.openSettings("game")
	d.settingsPanel.nav:selectId("Inspect")
	panelKey("Return")
	assert(d.settingsPanel:isShowing() and not d.spiderPick.inspecting and d.settingsPanel.status.Text == InspectText.NOT_NOW, `refused: "{d.settingsPanel.status.Text}"`)
	assert(words("Toast") == InspectText.NOT_NOW, "and a toast says it too")
	d.settingsPanel:close()
	d.motor.seized = false
	frames(2)
	-- a rival about to jump, a wasp, the mating scene and the hatching scene are refused too
	local function refusedNow(name: string)
		assert(d.spiderPick.refusal() == InspectText.NOT_NOW, name .. ": not refused")
	end
	d.mateLegs.couple.active = true
	refusedNow("the mating scene")
	d.mateLegs.couple.active = false
	d.mateLegs.phase = "scene"
	refusedNow("the hatching scene")
	d.mateLegs.phase = ""
	assert(d.spiderPick.refusal() == nil, "(and safe again)")
end)


-- ---------------------------------------------------------------- the view
local function enter(d: any)
	d.openSettings("game")

	d.settingsPanel.nav:selectId("Inspect")
	panelKey("Return")
	assert(d.spiderPick.inspecting and not d.settingsPanel:isShowing(), "(the close look began)")
end
local cleanLook = Vector3.new(0, 0, 0)
local function stick(x: number, y: number)
	services.actions["SpiderLookStick"]("SpiderLookStick", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(x, y, 0) })
end

local beforeEntry: CFrame? = nil
check("the view: eased in over 0.8 s to 1.6 body-lengths, slightly above, the body shown and the eye view off, orbiting 10 degrees a second", function()
	local d = ClientStubs.driver
	local cam = d.cam
	d.place(OPEN)
	frames(60)
	beforeEntry = cam.camera.CFrame
	local pos0 = d.motor.pos
	enter(d)
	assert(cam.inspect ~= nil and cam.inspectT == 0 and cam:inspectActive() and not cam.eyeView, "just begun: the ease has not moved yet")
	frames(24)
	assert(near(cam.inspectT, 0.5, 0.03), `half the ease in 0.4 s ({cam.inspectT})`)
	frames(26)
	assert(cam.inspectT == 1, "all of it by 0.8 s")
	frames(24)
	local dist, yaw0, elev = view(d)
	assert(near(dist, 1.6, 0.02), `1.6 body-lengths away ({dist})`)
	assert(near(elev, 20, 0.7), `20 degrees above its surface ({elev})`)
	assert(cam.bodyHidden == false and d.rig()._bodyHidden == false, "the body is shown")
	assert(not cam.eyeView and not d.rig()._eyeView, "the eye view is off")
	-- The auto-orbit: 10 degrees a second.
	frames(60)
	local _, yaw1 = view(d)
	seconds(3)
	local _, yaw2 = view(d)
	assert(near((yaw2 - yaw1 + 540) % 360 - 180, 30, 1.5), `30 degrees in 3 s ({(yaw2 - yaw1 + 540) % 360 - 180})`)
	assert((d.motor.pos - pos0).Magnitude < 1e-6, "the spider has not moved")
	local cf = cam.camera.CFrame
	assert(cf.LookVector:Dot((d.motor.pos - cf.Position).Unit) > 0.97, "and it looks at the spider")
end)

check("taking over: the right stick, a touch drag, the wheel and a pinch turn and zoom the view, and the auto-orbit waits for 3 s of idle", function()
	local d = ClientStubs.driver
	local cam = d.cam
	local _, yaw0, elev0 = view(d)
	stick(1, 0)
	frames(20) -- a third of a second at 150 degrees a second
	stick(0, 0)
	frames(2)
	local _, yaw1 = view(d)
	local turned = (yaw1 - yaw0 + 540) % 360 - 180
	assert(turned > 40 and turned < 60, `a right push moved the camera to the spider's right by {turned} degrees`)
	assert(cam.inspect.idle < 0.1, "and the auto-orbit waits")
	seconds(2)
	local _, yaw2 = view(d)
	assert(near(yaw2, yaw1, 0.5), `which it does (2 s later: {yaw1} then {yaw2})`)
	cam:touchLook(Vector2.new(-40, 0)) -- a drag left: 10 degrees the other way
	frames(3)
	local _, yaw3 = view(d)
	assert(near((yaw3 - yaw2 + 540) % 360 - 180, -10, 0.5), `a touch drag turns it by 10 degrees ({(yaw3 - yaw2 + 540) % 360 - 180})`)
	local _, _, e3 = view(d)
	cam:touchLook(Vector2.new(0, 40)) -- a drag down lifts the camera
	frames(3)
	local _, _, e4 = view(d)
	assert(near(e4 - e3, 10, 0.7), `a drag down lifts it by 10 degrees ({e4 - e3})`)
	-- the wheel: one notch is 12 percent closer
	local d0 = view(d)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, 1) }, false)
	frames(30)
	local d1 = view(d)
	assert(near(d1 / d0, 0.88, 0.02), `a wheel notch is 12 percent closer ({d1 / d0})`)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, -1) }, false)
	frames(30)
	assert(near(view(d), d0, 0.02), "and back out")
	-- a pinch on a touch screen: the fingers spreading by a quarter is a fifth closer; a pinch the interface took, or one with no view, is nothing
	local before = view(d)
	UIS.TouchPinch:Fire({}, 1, 0, Enum.UserInputState.Begin, false)
	UIS.TouchPinch:Fire({}, 1.1, 0, Enum.UserInputState.Change, false)
	UIS.TouchPinch:Fire({}, 1.25, 0, Enum.UserInputState.Change, false)
	UIS.TouchPinch:Fire({}, 1.25, 0, Enum.UserInputState.End, false)
	frames(30)
	assert(near(view(d) / before, 0.8, 0.03), `a pinch spread by 1.25 is 0.8 of the distance ({view(d) / before})`)
	local pinched = view(d)
	UIS.TouchPinch:Fire({}, 1, 0, Enum.UserInputState.Begin, true)
	UIS.TouchPinch:Fire({}, 2, 0, Enum.UserInputState.Change, true)
	frames(30)
	assert(near(view(d), pinched, 0.01), "a pinch the interface took does nothing")
	-- ... and the auto-orbit comes back 3 s after the last of the player's input
	local _, yawA = view(d)
	seconds(5)
	local _, yawB = view(d)
	assert(near((yawB - yawA + 540) % 360 - 180, 30, 3), `5 s on, 1 s since the last pinch: 4 s of idle is 3 s of orbit, 30 degrees ({(yawB - yawA + 540) % 360 - 180})`)
	-- ROBLOX-92: the two fingers of a pinch are moving, and neither turns the view as well as zooming it; one finger dragging does
	local function finger(dx: number): any return { UserInputType = Enum.UserInputType.Touch, Delta = Vector2.new(dx, 0) } end
	local _, yawP0 = view(d)
	local f1, f2 = finger(60), finger(-60)
	UIS.TouchStarted:Fire(f1, false); UIS.TouchStarted:Fire(f2, false)
	UIS.TouchPinch:Fire({}, 1, 0, Enum.UserInputState.Begin, false)
	UIS.TouchMoved:Fire(f1, false); UIS.TouchMoved:Fire(f2, false)
	UIS.TouchPinch:Fire({}, 1.0, 0, Enum.UserInputState.Change, false)
	UIS.TouchMoved:Fire(f1, false); UIS.TouchMoved:Fire(f2, false)
	frames(10)
	local _, yawP1 = view(d)
	assert(near(angleBetween(yawP0, yawP1), 0, 2.0), `a pinch does not also orbit (a drag of 60 px is 15 degrees; the idle drift is 10 degrees a second) ({yawP0} then {yawP1})`)
	UIS.TouchPinch:Fire({}, 1.0, 0, Enum.UserInputState.End, false)
	UIS.TouchMoved:Fire(f1, false) -- (two fingers are still down: still not a drag)
	frames(10)
	local _, yawP2 = view(d)
	assert(near(angleBetween(yawP0, yawP2), 0, 4.0), "nor with both fingers still down after the pinch ended")
	UIS.TouchEnded:Fire(f2, false)
	UIS.TouchMoved:Fire(f1, false) -- one finger: a drag
	frames(10)
	local _, yawP3 = view(d)
	assert(angleBetween(yawP2, yawP3) > 5, `one finger dragging orbits ({yawP2} then {yawP3})`)
	UIS.TouchEnded:Fire(f1, false)
end)

check("zooming: W and S (the left stick) go in and out between 1.1 and 3 body-lengths, and the spider does not walk", function()
	local d = ClientStubs.driver
	local cam = d.cam
	local p0 = d.motor.pos
	key("Forward", true); seconds(4); key("Forward", false)
	frames(30)
	assert(near(view(d), 1.1, 0.02), `closest is 1.1 body-lengths ({view(d)})`)
	key("Forward", true); seconds(2); key("Forward", false)
	assert(near(view(d), 1.1, 0.02), "and no closer")
	key("Back", true); seconds(1); key("Back", false)
	frames(30)
	assert(near(view(d), 2.1, 0.12), `one second out is a body-length further ({view(d)})`)
	key("Back", true); seconds(5); key("Back", false)
	frames(60)
	assert(near(view(d), 3.0, 0.03), `furthest is 3 ({view(d)})`)
	assert((d.motor.pos - p0).Magnitude < 1e-6 and d.motor.mode == "attached", "the spider stayed where it was")
	assert(cam.inspect.dist == 3.0, "(and the state agrees)")
end)

check("the framings: the Eye key cycles face, side, top and round, with a toast, and holds the picture still", function()
	local d = ClientStubs.driver
	local cam = d.cam
	tap("Eye")
	assert(words("Toast") == "Framing: Face" and not cam.eyeView, `the first: "{words("Toast")}"`)
	seconds(1)
	local dist, yaw, elev = view(d)
	assert(angleBetween(yaw, 0) < 1 and near(elev, 10, 0.5) and near(dist, 1.25, 0.02), `the face: in front, 10 up, 1.25 away ({yaw}, {elev}, {dist})`)
	local head = d.motor.pos + d.motor.heading * 0.3 * d.rig():bodyLength()
	assert((cam.camera.CFrame.Position - head).Magnitude < (cam.camera.CFrame.Position - d.motor.pos).Magnitude, "close to the head")
	tap("Eye")
	assert(words("Toast") == "Framing: Side", words("Toast"))
	seconds(1)
	dist, yaw, elev = view(d)
	assert(angleBetween(yaw, 90) < 1 and near(elev, 6, 0.5) and near(dist, 1.8, 0.02), `the side: on its right, low, 1.8 away ({yaw}, {elev}, {dist})`)
	tap("Eye")
	assert(words("Toast") == "Framing: From above", words("Toast"))
	seconds(1)
	dist, yaw, elev = view(d)
	assert(near(elev, 84, 0.5) and near(dist, 2.0, 0.02), `the top: nearly straight down, 2 away ({elev}, {dist})`)
	local still = cam.camera.CFrame.Position
	seconds(2)
	assert((cam.camera.CFrame.Position - still).Magnitude < 1e-4, "and a framing does not orbit")
	tap("Eye")
	assert(words("Toast") == "Framing: Face", "and round again")
	seconds(1)
end)

check("the controls are the look's: walking, resting, feeding, dropping, jumping, focus, the gait and slow motion are nothing, and the spider stays", function()
	local d = ClientStubs.driver
	local p0 = d.motor.pos
	local gait = d.rig().gaitMode
	key("Forward", true); key("Back", true); frames(20); key("Forward", false); key("Back", false)
	tap("Feed")
	tap("Drop")
	key("Focus", true); frames(10); key("Focus", false)
	tap("Slow")
	tap("Recenter")
	services.actions["SpiderGait"]("SpiderGait", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.G, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero }); frames(2)
	services.actions["SpiderGait"]("SpiderGait", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.G, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	frames(30)
	assert((d.motor.pos - p0).Magnitude < 1e-6 and d.motor.mode == "attached" and not d.jump:isBusy() and d.motor.silk.mode == "none", "the spider has not moved, jumped or let down a line")
	assert(d.rig().gaitMode == gait and not d.life.resting and d.spiderPick.inspecting and not d.cam.eyeView, "no gait, no rest, still looking")
	assert(not d.focusState.latched and d.rig().focusPoint == nil, "no focus")
end)

check("the screen: the spider's name and one line of controls, and nothing else (no hunger, no day, no notices, no status); H still shows the card, with its line", function()
	local d = ClientStubs.driver
	d.life:showNotice("A notice that should not show")
	frames(3)
	assert(words("PromptTitle") == "The first spider" and words("PromptHint") == InspectText.hint("keyboard"), `"{words("PromptTitle")}" / "{words("PromptHint")}"`)
	assert(not find("SpiderPrompts", "HungerBar").Visible, "no hunger bar")
	assert(words("Day") == "" and words("DayLine") == "" and words("Status") == "" and words("Notice") == "" and words("Caption") == "", "no day, no status, no notice, no caption")
	assert(words("PromptCue") == "", "no cue")
	-- (ROBLOX-113: the start's card is up for 20 s of the wall clock, and since the shim got faster this check can come inside them; put away first, so H shows it)
	if words("Controls") ~= "" then tap("Help") end
	tap("Help")
	assert(string.find(words("Controls"), PeacockText.crackLine("keyboard"), 1, true) ~= nil, `the card has the crack's line, with the close look in it: "{words("Controls")}"`)
	tap("Help")
	-- The device in use names the controls.
	d.setDevice("gamepad")
	frames(3)
	assert(words("PromptHint") == InspectText.hint("gamepad") and string.find(words("PromptHint"), "Right stick: orbit", 1, true), words("PromptHint"))
	d.setDevice("keyboard")
	frames(3)
	assert(words("PromptHint") == InspectText.hint("keyboard"), "(keyboard again)")
end)

check("the living motion and the simulation run on: the abdomen breathes and the world's clock goes on", function()
	local d = ClientStubs.driver
	local rig = d.rig()
	local clock0, now0 = d.life.clock.hour, d.prey.now
	local abdomen = workspace:FindFirstChild("Spider"):FindFirstChild("Abdomen")
	local t0, sizes = rig._living.t, {}
	for _ = 1, 8 do
		frames(10)
		table.insert(sizes, abdomen.Size.X)
	end
	local lo, hi = math.huge, -math.huge
	for _, s in sizes do lo, hi = math.min(lo, s), math.max(hi, s) end
	assert(rig._living.t - t0 > 1.2 and hi / lo > 1.01 and hi / lo < 1.06, `the abdomen breathes by a couple of percent ({hi / lo}), the living clock runs ({rig._living.t - t0} s)`)
	assert(d.prey.now > now0 + 0.5 and d.life.clock.hour ~= clock0, "the simulation's time goes on")
	assert(rig._living ~= nil, "it has its living motion")
end)

check("leaving with Cancel: the camera eases back over 0.8 s to where it was, and the screen is the game's again", function()
	local d = ClientStubs.driver
	local cam = d.cam
	key("Cancel", true); key("Cancel", false)
	assert(not d.spiderPick.inspecting and cam.inspect == nil and cam:inspectActive() and cam.inspectT == 1, "Cancel leaves at once: the camera is still to ease")
	frames(24)
	assert(near(cam.inspectT, 0.5, 0.06), `half of the way back in 0.4 s ({cam.inspectT})`)
	frames(26)
	assert(cam.inspectT == 0 and not cam:inspectActive(), "all of it in 0.8 s")
	frames(10)
	local was: CFrame = beforeEntry :: CFrame
	assert((cam.camera.CFrame.Position - was.Position).Magnitude < 0.05 and cam.camera.CFrame.LookVector:Dot(was.LookVector) > 0.999, `the camera is where it was ({(cam.camera.CFrame.Position - was.Position).Magnitude})`)
	assert(not find("SpiderPrompts", "PromptTitle").Visible or words("PromptTitle") ~= "The first spider", "the name line is gone")
	assert(find("SpiderPrompts", "HungerBar").Visible, "and the hunger bar is back")
	assert(d.rig().focusPoint == nil, "(no stale focus)")
end)

check("the eye view is given back as it was: entered from it, it goes off, and returns on leaving, with the camera back where it was", function()
	local d = ClientStubs.driver
	local cam = d.cam
	tap("Eye")
	assert(cam.eyeView and d.rig()._eyeView, "(the eye view is on)")
	frames(30)
	local eyeAt = cam.camera.CFrame
	enter(d)
	assert(not cam.eyeView and not d.rig()._eyeView and cam.inspectWasEye, "the close look turns it off")
	seconds(2)
	local dist = view(d)
	assert(near(dist, 1.6, 0.05), `(the same view from the eye: {dist})`)
	tap("Eye") -- the framings, not the eye view
	assert(not cam.eyeView, "V cycles framings, it does not bring the eye view back")
	d.spiderPick.press("Choose") -- the choose key again leaves
	assert(not d.spiderPick.inspecting and cam.eyeView and d.rig()._eyeView, "leaving gives the eye view back")
	d.spiderPick.release("Choose")
	seconds(1)
	assert((cam.camera.CFrame.Position - eyeAt.Position).Magnitude < 0.05, "and the camera is the eye's again")
	tap("Eye")
	assert(not cam.eyeView, "(and V turns it off as ever)")
	seconds(1)
end)

-- ---------------------------------------------------------------- the routes in, on each device
check("in the crack, by holding C: the camera finds a way in against the sill (never inside the body) and Cancel leaves", function()
	local d = ClientStubs.driver
	local cam = d.cam
	rest(d)
	frames(30)
	local rested = cam.camera.CFrame
	key("Choose", true); frames(40); key("Choose", false); frames(2)
	assert(d.spiderPick.inspecting and d.life.resting, "looking, still resting")
	seconds(2)
	local dist = view(d)
	local len = d.rig():bodyLength()
	assert(dist >= 0.85 and dist <= 1.62, `the boom is cast against the crack's walls: {dist} body-lengths`)
	assert((cam.camera.CFrame.Position - d.motor.pos).Magnitude > 0.7 * len, "and the camera is never inside the body")
	assert(words("PromptTitle") == "The first spider", "the name")
	key("Cancel", true); key("Cancel", false)
	seconds(1)
	assert(not cam:inspectActive() and d.life.resting and (cam.camera.CFrame.Position - rested.Position).Magnitude < 0.1, "back where it was, still resting")
	unrest(d)
end)

check("a controller: RB held in the crack is the close look, a tap is a change of spider; RB again leaves; the hint says so", function()
	local d = ClientStubs.driver
	d.setDevice("gamepad")
	rest(d)
	frames(3)
	assert(string.find(words("PromptHint"), "RB: become the peacock spider    hold RB: look closely", 1, true), words("PromptHint"))
	key("Display", true); frames(6)
	assert(d.appearance() == "first_spider", "(nothing while it is down)")
	key("Display", false); frames(2)
	assert(d.appearance() == "maratus_volans_male" and not d.spiderPick.inspecting, "a tap of RB changed spider when it was let go")
	key("Display", true); frames(40)
	assert(d.spiderPick.inspecting, "held 0.6 s: the close look")
	key("Display", false); frames(2)
	assert(d.appearance() == "maratus_volans_male" and d.spiderPick.inspecting, "let go: nothing changes")
	frames(3)
	assert(words("PromptTitle") == "The peacock spider" and words("PromptHint") == "Right stick: orbit    Left stick: zoom    Y: face, side, top    B or RB: back", `the screen for the peacock spider on a controller: "{words("PromptTitle")}" / "{words("PromptHint")}"`)
	assert(d.cam.inspect ~= nil and d.rig():bodyLength() < 0.5, `(the smaller spider is looked at in its own body-lengths: {d.rig():bodyLength()} studs)`)
	seconds(1.5)
	local dist = view(d)
	assert(dist > 0.8 and dist <= 1.62, `the peacock spider at its own scale ({dist})`)
	tap("Display")
	assert(not d.spiderPick.inspecting and d.appearance() == "maratus_volans_male", "RB again leaves, and does not also change spider")
	-- B leaves too, and the controller's Y cycles framings
	key("Display", true); frames(40); key("Display", false); frames(2)
	assert(d.spiderPick.inspecting, "(again)")
	tap("Eye")
	assert(words("Toast") == "Framing: Face", "Y cycles the framings")
	tap("Cancel")
	assert(not d.spiderPick.inspecting, "B leaves")
	-- round to the first spider again
	for _ = 1, 5 do if d.appearance() ~= "first_spider" then tap("Display") end end
	assert(d.appearance() == "first_spider", "(the first spider again)")
	unrest(d)
	d.setDevice("keyboard")
end)

check("touch: a long press on Change is the close look, a short one changes spider; only Back, View and the arrows are left, and Back leaves", function()
	local d = ClientStubs.driver
	d.setDevice("touch")
	rest(d)
	frames(3)
	local touch = gui:FindFirstChild("SpiderTouch")
	local function visible(name: string): boolean return touch:FindFirstChild(name).Visible ~= false end
	assert(visible("Choose"), "the Change button is there in the crack")
	local finger = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Choose").InputBegan:Fire(finger); frames(10)
	UIS.InputEnded:Fire(finger); frames(2)
	assert(d.appearance() == "maratus_volans_male" and not d.spiderPick.inspecting, "a short press changed spider")
	local long = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Choose").InputBegan:Fire(long); frames(40)
	assert(d.spiderPick.inspecting, "a long press (0.67 s): the close look")
	UIS.InputEnded:Fire(long); frames(3)
	assert(d.appearance() == "maratus_volans_male" and d.spiderPick.inspecting, "and lifting the finger changes nothing")
	assert(touch:FindFirstChild("Cancel").Text == "Back" and touch:FindFirstChild("Eye").Text == "View", "Cancel says Back, Eye says View")
	for _, name in { "Jump", "Creep", "Drop", "Recenter", "Focus", "Feed", "Choose", "Display", "Left", "Right" } do
		assert(not visible(name), name .. " is hidden")
	end
	for _, name in { "Cancel", "Eye", "Forward", "Back" } do assert(visible(name), name .. " is there") end
	assert(words("PromptHint") == "Drag: orbit    Pinch or ↑ ↓: zoom    View: face, side, top    Back: leave", words("PromptHint"))
	-- View cycles the framings
	local view1 = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Eye").InputBegan:Fire(view1); frames(2); UIS.InputEnded:Fire(view1); frames(2)
	assert(words("Toast") == "Framing: Face", "View cycles the framings")
	-- the arrow zooms
	local arrow = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Back").InputBegan:Fire(arrow); seconds(3); UIS.InputEnded:Fire(arrow); frames(30)
	assert(d.cam.inspect.dist > 2.9, `the down arrow zooms out ({d.cam.inspect.dist})`)
	-- Back leaves; the buttons come back
	local back = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Cancel").InputBegan:Fire(back); frames(2); UIS.InputEnded:Fire(back); frames(3)
	assert(not d.spiderPick.inspecting, "Back leaves")
	assert(touch:FindFirstChild("Cancel").Text == "Cancel" and touch:FindFirstChild("Eye").Text == "Eye", "the labels are back")
	for _, name in { "Jump", "Creep", "Drop", "Recenter", "Focus", "Left", "Right", "Choose" } do assert(visible(name), name .. " is back") end
	assert(not visible("Display"), "(the first spider has no Dance button)")
	-- round to the first spider again
	for _ = 1, 5 do
		if d.appearance() ~= "first_spider" then
			local f = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
			touch:FindFirstChild("Choose").InputBegan:Fire(f); frames(3); UIS.InputEnded:Fire(f); frames(3)
		end
	end
	assert(d.appearance() == "first_spider", "(the first spider again)")
	unrest(d)
	d.setDevice("keyboard")
end)

check("touch: Change hidden under the finger mid-hold takes the press away; nothing is changed and nothing is said (ROBLOX-92)", function()
	local d = ClientStubs.driver
	d.setDevice("touch")
	rest(d)
	frames(3)
	local touch = gui:FindFirstChild("SpiderTouch")
	local startAs = d.appearance()
	local finger = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
	touch:FindFirstChild("Choose").InputBegan:Fire(finger); frames(8)
	assert(d.spiderPick.hold ~= nil and touch:FindFirstChild("Choose").Visible ~= false, "(the finger is down on Change)")
	tap("Feed") -- the rest ends under the finger: the Change button is hidden
	frames(3)
	assert(not d.life.resting and touch:FindFirstChild("Choose").Visible == false, "(the button is hidden)")
	assert(d.appearance() == startAs and d.spiderPick.hold == nil, "no change of spider, and no hold left")
	assert(words("Toast") ~= PeacockText.NOT_RESTING, `and no 'not resting' toast either ("{words("Toast")}")`)
	UIS.InputEnded:Fire(finger); frames(3)
	assert(d.appearance() == startAs and not d.spiderPick.inspecting, "the finger lifting later does nothing")
	d.setDevice("keyboard")
end)

check("losing the key mid-hold changes nothing: focus lost, the menu opened or the spider moved away", function()
	local d = ClientStubs.driver
	rest(d)
	key("Choose", true); frames(10)
	d.input:clear() -- focus loss, the Roblox menu, a text box
	frames(40)
	assert(not d.spiderPick.inspecting and d.appearance() == "first_spider" and d.spiderPick.hold == nil, "the hold is dropped, with no change and no close look")
	key("Choose", false); frames(2)
	assert(d.appearance() == "first_spider", "and the late let-go is nothing")
	-- the rest ends under the hold (the spider moves): no close look
	key("Choose", true); frames(10)
	tap("Feed")
	frames(40)
	assert(not d.life.resting and not d.spiderPick.inspecting, "leaving the crack under the hold: no close look")
	key("Choose", false); frames(2)
end)

-- ---------------------------------------------------------------- the ways out
check("a wasp's warning ends it at once, with its notice: the camera is cut back, the controls and the screen are the game's", function()
	local d = ClientStubs.driver
	local cam = d.cam
	d.place(OPEN)
	frames(30)
	enter(d)
	seconds(1)
	assert(cam.inspectT == 1, "(settled in)")
	d.wasp.enabled = true
	assert(d.wasp:force(d.life.clock.day, "floor_middle"), "the wasp could not be brought")
	frames(2)
	assert(d.wasp:isVisiting(), "(visiting)")
	assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectT == 0 and not cam:inspectActive(), "ended at once, and the camera was cut back (no ease)")
	assert(words("Toast") == InspectText.DANGER, `the toast: "{words("Toast")}"`)
	assert(find("SpiderPrompts", "HungerBar").Visible and words("PromptTitle") ~= "The first spider", "the game's screen is back")
	local p0 = d.motor.pos
	key("Forward", true); frames(30); key("Forward", false)
	assert((d.motor.pos - p0).Magnitude > 0.2 or d.life.lifeOver, "and the spider can move")
	-- and it will not begin while the wasp is there
	d.openSettings("game")
	d.settingsPanel.nav:selectId("Inspect")
	panelKey("Return")
	assert(d.settingsPanel:isShowing() and not d.spiderPick.inspecting and d.settingsPanel.status.Text == InspectText.NOT_NOW, "refused while it visits")
	d.settingsPanel:close()
	d.wasp:clearVisit()
	d.wasp.enabled = false
	frames(10)
	if d.caughtPanel:isShowing() then -- (a visit that was not dodged ends at the catch screen: back to the last rest)
		assert(d.caughtPanel:choose("Back"), "the catch screen's Back")
		awaitReturn(d,function() frame(0) end)
		frames(5)
	end
	assert(not d.caughtPanel:isShowing(), "(the game goes on)")
	d.motor.seized = false
end)

check("the rival's windup ends it at once, as does anything that makes the spider unsafe (seized, a line, a jump, the struggle, a scene or a screen)", function()
	local d = ClientStubs.driver
	local cam = d.cam
	d.place(OPEN)
	frames(60)
	d.life.clock.hour = 12
	local function begin()
		enter(d)
		seconds(1)
		assert(d.spiderPick.inspecting, "(looking)")
	end
	local function ended(why: string)
		d.spiderPick.update(1 / 60) -- (the check alone: the simulation would act on a pretended state)
		assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectT == 0, why .. ": it ended, with a cut")
	end
	local rival = d.life.rival
	assert(rival ~= nil, "(there is a rival, asleep)")
	local state = rival.state
	begin()
	rival.state = "windup"
	ended("the rival's windup")
	assert(words("Toast") == InspectText.DANGER, `the toast: "{words("Toast")}"`)
	seconds(3) -- (a danger is kept on the screen for its seconds over any plainer toast, ROBLOX-92)
	rival.state = state
	begin()
	d.motor.seized = true
	ended("seized")
	assert(words("Toast") == InspectText.ENDED, `the toast: "{words("Toast")}"`)
	d.motor.seized = false
	begin()
	d.prey.feeding.struggling = true
	ended("the fly struggle")
	d.prey.feeding.struggling = false
	begin()
	d.mateLegs.phase = "scene"
	ended("the hatching scene")
	d.mateLegs.phase = ""
	begin()
	d.mateLegs.couple.active = true
	ended("the mating scene")
	d.mateLegs.couple.active = false
	begin()
	d.motor.preparing = true
	ended("preparing a jump")
	d.motor.preparing = false
	-- Backspace (back to the last rest) ends it too, whatever it is
	begin()
	services.actions["SpiderReset"]("SpiderReset", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Backspace, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	services.actions["SpiderReset"]("SpiderReset", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.Backspace, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	awaitReturn(ClientStubs.driver,function() frame(0) end)
	assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectT == 0, "Backspace: ended, with a cut")
	frames(10)
end)

check("Reduced Motion: no orbit of its own, cuts in place of eases, and the framings are cuts", function()
	local d = ClientStubs.driver
	local cam = d.cam
	player:SetAttribute("ReducedMotion", true)
	d.place(OPEN)
	frames(60)
	enter(d)
	frame(1 / 60)
	assert(cam.inspectT == 1, "in at once: a cut")
	local _, yaw0 = view(d)
	seconds(3)
	local _, yaw1 = view(d)
	assert(near(yaw1, yaw0, 0.01), `no auto-orbit ({yaw0} then {yaw1})`)
	stick(1, 0)
	frames(20)
	stick(0, 0)
	frames(2)
	local _, yaw2 = view(d)
	assert(angleBetween(yaw0, yaw2) > 40, `but the player's turn works ({yaw0} then {yaw2})`)
	tap("Eye")
	local dist, yaw, elev = view(d)
	assert(angleBetween(yaw, 0) < 0.5 and near(elev, 10, 0.5) and near(dist, 1.25, 0.02), `a framing is a cut ({yaw}, {elev}, {dist})`)
	key("Cancel", true); key("Cancel", false)
	frame(1 / 60)
	assert(not d.spiderPick.inspecting and cam.inspectT == 0 and not cam:inspectActive(), "and leaving is a cut")
	player:SetAttribute("ReducedMotion", nil)
	frames(2)
end)

check("a jump leaves it, and is nothing else: no hop, and what is left of the press is swallowed", function()
	local d = ClientStubs.driver
	d.place(OPEN)
	frames(60)
	enter(d)
	seconds(1)
	local p0 = d.motor.pos
	key("Jump", true)
	assert(not d.spiderPick.inspecting and d.cam.inspect == nil and d.cam:inspectActive(), "Space leaves at once, with the camera still to ease back")
	frames(20)
	key("Jump", false)
	frames(60)
	assert((d.motor.pos - p0).Magnitude < 1e-6 and d.motor.mode == "attached" and not d.jump:isBusy(), "the spider did not hop")
	-- (a tap afterwards is a hop as ever)
	key("Jump", true); frames(1); key("Jump", false); frames(90)
	assert((d.motor.pos - p0).Magnitude > 1.0, "the next tap hops")
	d.place(OPEN)
	frames(30)
	-- a controller's A is the same action; the touch Back is the cancel
	enter(d)
	d.setDevice("gamepad")
	key("Jump", true); key("Jump", false)
	assert(not d.spiderPick.inspecting, "A leaves")
	d.setDevice("keyboard")
	seconds(1)
end)

check("a menu, the notebook, the settings or Roblox's own menu ends it quietly: the camera is cut back, with nothing said", function()
	local d = ClientStubs.driver
	local cam = d.cam
	d.place(OPEN)
	frames(60)
	seconds(4) -- (the toasts of the earlier checks have gone)
	local function ends(name: string, open: () -> (), close: () -> ())
		enter(d)
		seconds(1)
		open()
		frames(2)
		assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectT == 0 and not cam:inspectActive(), name .. ": it did not end, with a cut")
		assert(words("Toast") ~= InspectText.ENDED and words("Toast") ~= InspectText.DANGER, `{name}: a toast "{words("Toast")}"`)
		close()
		frames(3)
	end
	ends("the life menu", function() d.openMenu() end, function() assert(d.menu:choose("Resume")) end)
	assert(not d.menu:isShowing(), "(the menu is closed)")
	ends("the notebook", function() d.openNotebook("game") end, function() d.notebookPanel:close() end)
	local gs = game:GetService("GuiService")
	ends("Roblox's own menu", function() gs.MenuIsOpen = true; gs.MenuOpened:Fire() end, function() gs.MenuIsOpen = false; gs.MenuClosed:Fire() end)
	-- the Settings opened over it ends it too (the panel is another way into the game's menus)
	enter(d)
	seconds(1)
	d.openSettings("game")
	frames(2)
	assert(not d.spiderPick.inspecting and cam.inspectT == 0, "the settings: ended")
	d.settingsPanel:close()
	frames(3)
	assert(d.spiderPick.inspecting == false and not d.cam:inspectActive(), "(and nothing came back with the panel closed)")
end)

check("hanging on the line: the close look works there too, the line holds, a jump or Cancel leaves and the line is still held", function()
	local d = ClientStubs.driver
	local cam = d.cam
	d.place(Vector3.new(0.5, 4.51, -3.0))
	frames(5)
	key("Drop", true); frames(2); frames(150); key("Drop", false)
	assert(d.get().line == "locked" and d.motor:onLine(), "(on the line)")
	frames(40)
	assert(d.spiderPick.refusal() == nil, "a close look is not refused on a line")
	enter(d)
	local p0 = d.motor.pos
	seconds(3)
	assert(d.spiderPick.inspecting and d.motor:onLine() and d.get().line == "locked", "still looking, still on the line")
	assert((d.motor.pos - p0).Magnitude < 0.8, `the spider has not gone anywhere ({(d.motor.pos - p0).Magnitude})`)
	assert(cam.inspectT == 1 and cam.bodyHidden == false, "the view is in, and the body is shown")
	local len = d.rig():bodyLength()
	local body = workspace:FindFirstChild("Spider"):FindFirstChild("Abdomen")
	local cf = cam.camera.CFrame
	local toBody = body.Position - cf.Position
	assert(toBody.Magnitude > 0.5 * len and toBody.Magnitude < 3.2 * len, `the camera is a body-length or two from the hanging body ({toBody.Magnitude / len})`)
	assert(cf.LookVector:Dot(toBody.Unit) > 0.9, "and looks at it")
	assert(words("PromptTitle") == "The first spider", "the name line (not the line's prompt)")
	-- the controls are the look's: W does not reel it in, Q held is not a let go
	key("Forward", true); seconds(1); key("Forward", false)
	assert(d.motor:onLine() and d.spiderPick.inspecting, "W zooms and does not reel")
	-- a framing there
	tap("Eye")
	seconds(1)
	assert(d.spiderPick.inspecting and words("Toast") == "Framing: Face", "the framings work on the line")
	-- Cancel leaves, the line is held
	tap("Cancel")
	assert(not d.spiderPick.inspecting, "Cancel leaves")
	seconds(1)
	assert(d.motor:onLine() and find("SpiderPrompts", "PromptTitle").Text == "On your line", "and the line's prompt is back")
	-- a jump leaves it too
	enter(d)
	seconds(1)
	key("Jump", true); key("Jump", false)
	assert(not d.spiderPick.inspecting, "a jump leaves")
	seconds(1)
	assert(d.motor:onLine() and not d.jump:isBusy(), "and is not a jump from the line")
	-- ROBLOX-92: a Cancel that left the look and is still held does not also let go of the line (it is swallowed until it is released, like the jump's); a fresh hold does
	enter(d)
	seconds(1)
	key("Cancel", true)
	assert(not d.spiderPick.inspecting and d.spiderPick.cancelSwallow == true, "Cancel leaves, and the rest of its press is swallowed")
	seconds(1.5)
	assert(d.motor:onLine() and d.get().line == "locked", "held on for 1.5 s after it left the look: the line is still held")
	key("Cancel", false)
	frames(3)
	assert(d.spiderPick.cancelSwallow == false, "released: nothing is swallowed")
	-- ... and the touch Back button, which is Cancel, the same
	enter(d)
	seconds(1)
	key("Cancel", true); key("Cancel", false)
	assert(not d.spiderPick.inspecting and d.spiderPick.cancelSwallow == false, "a tap leaves and leaves nothing swallowed")
	-- a plain hold of Cancel on the line, outside the look, lets go as before
	-- from the hold in the crack there is no line, and from a jump in flight it is refused
	key("Cancel", true); seconds(1.3); key("Cancel", false)
	frames(60)
	assert(d.get().line == "none", "(let go of the line)")
	d.place(OPEN)
	frames(60)
end)

check("nothing is kept: no attribute, no choice of spider; it is idle again", function()
	local d = ClientStubs.driver
	for _, id in { "Inspect", "InspectView", "Inspecting", "InspectFraming" } do
		assert(player:GetAttribute(id) == nil, `no attribute {id}`)
	end
	assert(d.appearance() == "first_spider" and player:GetAttribute("Appearance") == "first_spider", "the spider is the one that was chosen, and the close look chose nothing")
	assert(d.spiderPick.inspecting == false and d.spiderPick.hold == nil, "(idle again)")
end)

print(`INSPECT passed={passed} failed={failed}`)
if failed > 0 then error("inspect checks failed") end
