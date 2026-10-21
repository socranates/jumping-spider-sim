-- ROBLOX-110: lock-on and the sidestep. The pure rules of Shared/Movement/LockOn (what can be locked, which a press takes, what ends a lock, the
-- sidestep's direction, the camera's goal and follow), the real SpiderMotor circling a locked point on a box's top, side and underside, the words
-- and the touch button, and through the real client on the windowsill's boxes: a lock taken only from what the sensor has seen (never a target
-- it has not), the camera and the body turned to it, the sidestep at a creep keeping its distance and its facing, the jump's aim on it, every way
-- it ends, Recentre when there is nothing to lock, R3 on a controller, the touch Lock button, Reduced Motion, and the setting that hides the
-- perception HUD's rings and words while the lock's ticks stay. Not evidence of the engine, a device or how any of it looks.
-- Run with the other suites:  python3 tests/run.py path/to/luau lock.luau
local LockOn = require("../src/Shared/Movement/LockOn")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local CameraMath = require("../src/Shared/Movement/CameraMath")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local ControlText = require("../src/Shared/UI/ControlText")
local PeacockText = require("../src/Shared/UI/PeacockText")
local HudLayout = require("../src/Shared/UI/HudLayout")
local Shapes = require("../src/Shared/UI/PerceptionShapes")
local Spec = require("../src/Shared/Data/SettingsSpec")
local Nature = require("../src/Shared/Life/Nature")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function deg(a: Vector3, b: Vector3): number
	if a.Magnitude < 1e-9 or b.Magnitude < 1e-9 then return 180 end
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- A stand-in memory: the two calls the lock makes of ObservationMemory, over contacts shaped as its Contact.
local function memoryOf(list: { any }): any
	local m = { list = list }
	function m.contacts(self: any) return self.list end
	function m.getContact(self: any, id: string)
		for _, c in self.list do if c.trackId == id then return c end end
		return nil
	end
	return m
end
local function contact(id: string, pos: Vector3, state: string?, modality: string?, placed: boolean?, markValid: boolean?): any
	return { trackId = id, position = pos, state = state or "live", modality = modality or "forward_inspection",
		hasPosition = placed ~= false, markValid = markValid ~= false }
end

-- =============================================================================================== the rules

case("what can be locked: only a contact an inspection has placed, live or with its mark still good", function()
	check(LockOn.lockable(contact("a", Vector3.zero)), "live and placed")
	check(LockOn.lockable(contact("a", Vector3.zero, "live", "peripheral_motion")), "live, placed earlier, only cued now (its place is the last inspection's)")
	check(not LockOn.lockable(contact("a", Vector3.zero, "live", "peripheral_motion", false)), "a cue alone (a bearing, no place) cannot be locked")
	check(LockOn.lockable(contact("a", Vector3.zero, "lost")), "lost with its mark")
	check(not LockOn.lockable(contact("a", Vector3.zero, "lost", nil, true, false)), "lost and its spot found empty")
	check(not LockOn.lockable(nil), "nothing")
end)

case("which a press takes: the one in the principal eyes nearest the middle of the view, else the nearest in front within range", function()
	local eye, heading = Vector3.new(0, 0.4, 0), -Vector3.zAxis
	local camO, camD = Vector3.new(0, 2, 5), (Vector3.new(0, 0.4, -6) - Vector3.new(0, 2, 5)).Unit
	local near = contact("near", Vector3.new(1.5, 0.4, -1.5), "live", "peripheral_motion")
	local looked = contact("looked", Vector3.new(0, 0.4, -6))
	local m = memoryOf({ near, looked })
	check(LockOn.pick(m, eye, heading, camO, camD) == looked, "looked at beats nearer")
	looked.modality = "peripheral_motion"
	check(LockOn.pick(m, eye, heading, camO, camD) == near, "not in the principal eyes now: the nearest in front")
	local behind = contact("behind", Vector3.new(0, 0.4, 1), "lost") -- (seen earlier; behind it now, so not in its principal eyes)
	m = memoryOf({ behind })
	check(LockOn.pick(m, eye, heading, camO, camD) == nil, "a thing behind the spider and not looked at is not taken")
	local far = contact("far", Vector3.new(0, 0.4, -(LockOn.game.range + 0.5)))
	check(LockOn.pick(memoryOf({ far }), eye, heading, camO, (far.position - camO).Unit) == nil, "beyond range, even looked at")
	check(LockOn.pick(memoryOf({ contact("cued", Vector3.new(0, 0.4, -3), "live", "peripheral_motion", false) }), eye, heading, camO, camD) == nil, "a cue is never locked")
	check(LockOn.pick(memoryOf({}), eye, heading, camO, camD) == nil, "an empty memory: nothing")
end)

case("a press locks, a second press lets go; nothing to lock says so (the keys recentre then)", function()
	local s = LockOn.new()
	local c = contact("fly", Vector3.new(0, 0.31, -3))
	local m = memoryOf({ c })
	local pos, up = Vector3.new(0, 0.31, 0), Vector3.yAxis
	check(LockOn.press(s, m, pos, up, pos, -Vector3.zAxis, pos, -Vector3.zAxis) == "locked" and s.trackId == "fly", "locked")
	check(math.abs(s.keep - 3) < 1e-9, "the distance kept is the one it had")
	check(LockOn.update(s, m, pos) == c.position, "the place it follows is the contact's")
	c.position = Vector3.new(1, 0.31, -3)
	check(LockOn.update(s, m, pos) == c.position, "and moves when the contact is seen to move")
	check(LockOn.press(s, m, pos, up, pos, -Vector3.zAxis, pos, -Vector3.zAxis) == "released" and s.trackId == nil and s.released == "pressed", "a second press lets go")
	check(LockOn.press(s, memoryOf({}), pos, up, pos, -Vector3.zAxis, pos, -Vector3.zAxis) == "none" and s.trackId == nil, "nothing to lock: none")
	check(LockOn.press(s, m, pos, up, pos, -Vector3.zAxis, pos, -Vector3.zAxis) == "locked", "close in: the kept distance is never under minDistance")
	c.position = Vector3.new(0, 0.31, -0.2); LockOn.release(s, "test")
	LockOn.press(s, m, pos, up, pos, -Vector3.zAxis, pos, -Vector3.zAxis)
	check(s.keep == LockOn.game.minDistance, `kept {s.keep}`)
end)

case("what ends a lock: forgotten, its spot found empty, beyond range, Cancel", function()
	local pos = Vector3.new(0, 0.31, 0)
	local function locked(c: any): (any, any)
		local s, m = LockOn.new(), memoryOf({ c })
		LockOn.press(s, m, pos, Vector3.yAxis, pos, -Vector3.zAxis, pos, -Vector3.zAxis)
		return s, m
	end
	local c = contact("a", Vector3.new(0, 0.31, -3))
	local s, m = locked(c)
	c.state = "lost"
	check(LockOn.update(s, m, pos) == c.position and s.trackId == "a", "lost with a mark: it follows the mark")
	table.clear(m.list)
	check(LockOn.update(s, m, pos) == nil and s.trackId == nil and s.released == "forgotten", "the memory forgot it (sight lost for the decay time, or eaten): ended")
	c = contact("b", Vector3.new(0, 0.31, -3)); s, m = locked(c)
	c.state, c.markValid = "lost", false
	check(LockOn.update(s, m, pos) == nil and s.released == "empty", "its spot looked at and found empty: ended")
	c = contact("c", Vector3.new(0, 0.31, -3)); s, m = locked(c)
	c.position = Vector3.new(0, 0.31, -(LockOn.game.releaseRange + 0.1))
	check(LockOn.update(s, m, pos) == nil and s.released == "range", "flown beyond releaseRange: ended")
	c = contact("d", Vector3.new(0, 0.31, -3)); s, m = locked(c)
	c.position = Vector3.new(0, 0.31, -(LockOn.game.releaseRange - 0.1))
	check(LockOn.update(s, m, pos) ~= nil, "just inside releaseRange: held (it was locked within range, it may drift past it a little)")
	LockOn.release(s, "cancel")
	check(s.trackId == nil and s.point == nil and s.released == "cancel", "released by Cancel")
	check(LockOn.update(s, m, pos) == nil, "and nothing is followed after")
end)

case("the sidestep on a plane: right circles, the distance is kept and pulled back, forward closes and sets it, an idle stick stands", function()
	local up, target = Vector3.yAxis, Vector3.new(0, 0.31, -2)
	local pos = Vector3.new(0, 0.31, 0)
	local w, keep = LockOn.strafe(pos, up, target, 2, 1, 0)
	check(deg(w, Vector3.xAxis) < 1e-6 and keep == 2, "right at the kept distance: straight to the right")
	w = LockOn.strafe(pos, up, target, 2, -1, 0)
	check(deg(w, -Vector3.xAxis) < 1e-6, "left: to the left")
	w = LockOn.strafe(pos, up, target, 1.5, 1, 0)
	check(w:Dot(-Vector3.zAxis) > 0.3, "too far out: pulled in while circling")
	w = LockOn.strafe(pos, up, target, 2.5, 1, 0)
	check(w:Dot(-Vector3.zAxis) < -0.3, "too close: pushed out while circling")
	w, keep = LockOn.strafe(pos, up, target, 2, 0, 1)
	check(deg(w, -Vector3.zAxis) < 1e-6 and keep == 2, "forward: toward it")
	w, keep = LockOn.strafe(Vector3.new(0, 0.31, -1.2), up, target, 2, 0, 1)
	check(math.abs(keep - LockOn.game.minDistance) < 1e-9, "forward sets the kept distance to where it is now")
	w = LockOn.strafe(Vector3.new(0, 0.31, -1.2), up, target, 0.9, 0, 1)
	check(w == Vector3.zero, "forward at minDistance: stands")
	w, keep = LockOn.strafe(pos, up, target, 1, 0, -1)
	check(deg(w, Vector3.zAxis) < 1e-6 and keep == 2, "back: away, and the distance kept is the new one")
	w = LockOn.strafe(pos, up, target, 2, 0, 0)
	check(w == Vector3.zero, "an idle stick stands still")
	w = LockOn.strafe(pos, up, Vector3.new(0, 3, -2), 2, 1, 0)
	check(math.abs(w:Dot(up)) < 1e-9, "always on the plane the spider stands on (a target above it)")
end)

case("the camera's goal: from behind the spider at the thing, lifted by the default elevation; the follow eases, Reduced Motion cuts", function()
	local yaw, elev = LockOn.orbitGoal(Vector3.zero, Vector3.new(0, 0, -5))
	check(yaw ~= nil and math.abs(yaw :: number) < 1e-9 and math.abs((elev :: number) - math.rad(CameraMath.DEFAULT_ELEVATION_DEG)) < 1e-9, "level ahead: yaw 0, the default elevation")
	local back = CameraMath.backDirection(yaw :: number, 0)
	check(deg(-back, Vector3.new(0, 0, -5)) < 1e-6, "the orbit's back direction is behind the spider, away from the thing")
	yaw, elev = LockOn.orbitGoal(Vector3.zero, Vector3.new(5, 0, 0))
	back = CameraMath.backDirection(yaw :: number, 0)
	check(deg(-back, Vector3.xAxis) < 1e-6, "a thing to the right: the view turns right")
	local _, high = LockOn.orbitGoal(Vector3.zero, Vector3.new(0, 4, -4))
	check((high :: number) < math.rad(CameraMath.DEFAULT_ELEVATION_DEG), "a thing above: the view drops to look up at it")
	local _, steep = LockOn.orbitGoal(Vector3.zero, Vector3.new(0.01, -40, -0.1))
	check((steep :: number) <= math.rad(CameraMath.MAX_ELEVATION_DEG) + 1e-9, "never past the orbit's limits")
	check(LockOn.orbitGoal(Vector3.zero, Vector3.new(0, 5, 0)) == nil, "straight overhead: no goal (the view stays)")
	local y1, e1 = LockOn.followOrbit(0, 0, 1, 0.5, 1 / 60, false)
	check(y1 > 0 and y1 < 1 and e1 > 0 and e1 < 0.5, "eased: part of the way in a frame")
	local y2 = LockOn.followOrbit(math.pi - 0.1, 0, -math.pi + 0.1, 0, 1 / 60, false)
	check(y2 > math.pi - 0.1, "the short way round")
	local y3, e3 = LockOn.followOrbit(0, 0.3, math.rad(20), 0.3, 1 / 60, true)
	check(y3 == 0 and e3 == 0.3, "Reduced Motion: still while it is within reducedCutDeg")
	local y4 = LockOn.followOrbit(0, 0.3, math.rad(30), 0.3, 1 / 60, true)
	check(math.abs(y4 - math.rad(30)) < 1e-9, "and a cut once it is beyond")
	local g = LockOn.followGaze(-Vector3.zAxis, Vector3.xAxis, 1 / 60, false)
	check(deg(g, -Vector3.zAxis) > 0 and deg(g, -Vector3.zAxis) < 90, "the eye view's gaze turns part of the way")
	check(LockOn.followGaze(-Vector3.zAxis, Vector3.new(0.2, 0, -1).Unit, 1 / 60, true) == -Vector3.zAxis and LockOn.followGaze(-Vector3.zAxis, Vector3.xAxis, 1 / 60, true) == Vector3.xAxis, "Reduced Motion: held, then cut")
end)

-- =============================================================================================== the motor circling

-- One big box: its top a floor, its side a wall, its bottom an underside. bare_wood_rough holds the spider anywhere.
local box = BoxWorld.folder("LockBox", { { name = "Block", lo = Vector3.new(-30, 0, -30), hi = Vector3.new(30, 40, 30), profile = "bare_wood_rough" } })
local function newMotor(): any
	return Motor.new({ world = box, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Vector3.new(0, 40.31, 0),
		heading = -Vector3.zAxis, boundsMin = Vector3.new(-100, -100, -100), boundsMax = Vector3.new(100, 100, 100), probeParent = box })
end
local H = Motor.HEIGHT
for _, face in {
	{ name = "floor", pos = Vector3.new(0, 40 + H, 0), up = Vector3.yAxis, heading = -Vector3.zAxis },
	{ name = "wall", pos = Vector3.new(30 + H, 20, 0), up = Vector3.xAxis, heading = Vector3.yAxis },
	{ name = "underside", pos = Vector3.new(0, -H, 0), up = -Vector3.yAxis, heading = -Vector3.zAxis },
} do
	case(`the sidestep on the {face.name}: the real motor circles at a creep, keeps its distance and faces the thing`, function()
		local m = newMotor()
		m:place(face.pos, face.up, face.heading)
		local target = face.pos + face.heading * 2
		local keep = 2
		for _ = 1, 30 do m:tick(Motor.idleInput()) end
		local start = m.pos
		local worst, worstFace = 0, 0
		local walks = true
		for i = 1, 240 do
			local r = if i <= 180 then 1 else -1
			local wish
			wish, keep = LockOn.strafe(m.pos, m.up, target, keep, r, 0)
			local inp: any = Motor.idleInput()
			inp.wish, inp.creep, inp.face, inp.focusPoint = wish, true, target, target
			m:tick(inp)
			walks = walks and m.mode == "attached" and (m.up - face.up).Magnitude < 1e-6 and Nature.moved({ mode = "attached" }, m.mode, m.moving == true, false, false, false, nil) == "walk"
			if i > 20 then
				worst = math.max(worst, math.abs(LockOn.planar(m.pos, m.up, target) - 2))
				worstFace = math.max(worstFace, deg(m.heading, SupportMath.tangentDir(target - m.pos, m.up)))
			end
		end
		check(walks, "it stays on that face the whole time, walking (W4's walking cost applies)")
		check(worst < 0.08, `the distance stays at 2 (off by at most {worst})`)
		check(worstFace < 6, `and it faces the thing (at most {worstFace} degrees off)`)
		local around = deg(SupportMath.tangent(start - target, face.up), SupportMath.tangent(m.pos - target, face.up))
		local creep = Species.phidippus_audax_prototype.locomotion.stalk_speed_wu_s
		local arc = math.rad(around) * 2
		print(`LOCK sidestep on the {face.name}: distance off by at most {string.format("%.3f", worst)}, facing at most {string.format("%.2f", worstFace)} degrees off, {string.format("%.1f", around)} degrees round`)
		check(around > 20, `it went round ({around} degrees)`)
		check(arc < creep * 3.05 and arc > creep * 1.5, `at the creep: an arc of {arc} in 3 s of right then 1 s of left (creep {creep} WU/s)`)
	end)
end

case("without a face to keep, the motor walks as it always has (the Godot path untouched)", function()
	local a, b = newMotor(), newMotor()
	a:place(Vector3.new(0, 40 + H, 0), Vector3.yAxis, -Vector3.zAxis)
	b:place(Vector3.new(0, 40 + H, 0), Vector3.yAxis, -Vector3.zAxis)
	for _ = 1, 60 do
		local i: any = Motor.idleInput(); i.wish = Vector3.xAxis
		a:tick(i)
		local j: any = Motor.idleInput(); j.wish = Vector3.xAxis; j.face = nil
		b:tick(j)
	end
	check(a.pos == b.pos and a.heading == b.heading and deg(a.heading, Vector3.xAxis) < 1e-6, "turned to its walk, the same with and without the field")
end)

-- =============================================================================================== the words and the button

case("the words: the lock's names, the touch labels, the controls card at ten lines", function()
	-- (ROBLOX-115, Nathan: lock-on to L2: a controller's lock is LT / L2's tap, its Focus the same trigger held, and the right stick's click recentres only)
	check(ControlText.name("keyboard", "lock") == "R" and ControlText.name("gamepad", "lock") == "LB" and ControlText.name("touch", "lock") == "Lock", "R, LB and Lock")
	check(ControlText.name("gamepad", "focus") == "RT" and ControlText.name("gamepad", "recenter") == "Right-stick click", "LT is Focus too (held); the right-stick click recentres")
	check(string.find(ControlText.helpCard("gamepad"), "LB creep/lock (circle)   RT focus   LT run", 1, true) ~= nil and string.find(ControlText.helpCard("gamepad"), "click: recentre", 1, true) ~= nil, "the card: LB locks, RT focuses, LT runs, right-stick click recentres")
	check(ControlText.focusAgain("gamepad") == "RT again to stop" and ControlText.focusAgain("keyboard") == "Right mouse again to stop", "a latched Focus is held again to stop on a controller")
	ControlText.setPadStyle("playstation")
	check(ControlText.name("gamepad", "lock") == "L1" and ControlText.name("gamepad", "recenter") == "R3" and string.find(ControlText.helpCard("gamepad"), "L1 creep/lock", 1, true) ~= nil, "L1 on a PlayStation controller, R3 recentres")
	ControlText.setPadStyle("xbox")
	check(ControlText.touchLockLabel(false) == "Lock" and ControlText.touchLockLabel(true) == "Unlock", "Lock, Unlock")
	for _, device in { "keyboard", "gamepad", "touch" } do
		local card = string.lower(PeacockText.card(device :: any, "dance"))
		check(string.find(card, "lock", 1, true) ~= nil and string.find(card, "circle", 1, true) ~= nil and string.find(card, "recentre", 1, true) ~= nil, `{device}: the card says lock, circle and recentre`)
	end
	check(string.find(ControlText.helpCard("keyboard"), "A/D circle", 1, true) ~= nil, "the keyboard's card names A and D")
	local s: any = nil
	for _, row in Spec.LIST do if row.id == "ShowNoticed" then s = row end end
	check(s ~= nil and s.kind == "toggle" and s.default == true and s.label == "Show what the spider notices" and s.section == "comfort", "the setting: a toggle, on by default (as the game was), in Comfort")
end)

case("the touch Lock button: small, by Jump, apart from every other button on a phone, a tablet and a short screen", function()
	local lock: any = nil
	for _, b in HudLayout.TOUCH_BUTTONS do if b.action == "Lock" then lock = b end end
	check(lock ~= nil and lock.right and lock.size < 60, "a small right-hand button")
	for _, size in { { 360, 740 }, { 390, 844 }, { 820, 1180 }, { 1280, 720 }, { 844, 390 }, { 740, 360 } } do
		local w, h = size[1], size[2]
		local r = HudLayout.buttonRect(lock, w, h)
		local clear = r.x0 >= 0 and r.y0 >= 0 and r.x1 <= w and r.y1 <= h
		for _, other in HudLayout.TOUCH_BUTTONS do
			if other.action ~= "Lock" then
				local o = HudLayout.buttonRect(other, w, h)
				if not (r.x1 <= o.x0 or o.x1 <= r.x0 or r.y1 <= o.y0 or o.y1 <= r.y0) then clear = false; print(`  Lock meets {other.action} at {w}x{h}`) end
			end
		end
		check(clear, `{w}x{h}: on the screen and clear of the others`)
	end
end)

-- =============================================================================================== through the real client

local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local services = ClientStubs
local frame = ClientStubs.renderSteps.SpiderSim
local player = game:GetService("Players").LocalPlayer
local gui = player:FindFirstChild("PlayerGui")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local KEYS = { Recenter = "R", Cancel = "Q", Right = "D", Left = "A", Forward = "W", Back = "S", Jump = "Space", Eye = "V" }
local function key(action: string, down: boolean, code: string?)
	local fn = services.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	local c = code or KEYS[action] or action
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[c], UserInputType = if string.sub(c, 1, 6) == "Button" then Enum.UserInputType.Gamepad1 else Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function tap(action: string, code: string?) key(action, true, code); frames(1); key(action, false, code); frames(1) end
local function touchButton(name: string): any
	local g = gui:FindFirstChild("SpiderTouch")
	return g and g:FindFirstChild(name)
end
local d = ClientStubs.driver
local camera = workspace.CurrentCamera
-- The test target where the spider sees it (perception_client's set-up): on the sill's floor, 2.4 ahead.
local SPOT = Vector3.new(-26, 2.31, -3.5)
local function setUp(targetAt: Vector3, faceIt: boolean)
	d.input:clear(); d.sensor:reset(); d.memory:clear(); d.lockOn.release(d.lock, "test")
	d.stage.target.frozen = true
	d.stage.target.position = targetAt; d.stage.target.velocity = Vector3.zero
	d.place(SPOT)
	local delta = targetAt - d.motor.pos
	d.motor.heading = if faceIt then Vector3.new(delta.X, 0, delta.Z).Unit else -Vector3.new(delta.X, 0, delta.Z).Unit
	d.camera:snap()
end
local AHEAD = Vector3.new(-26, 2.8, -5.9)

check(loaded and d ~= nil and d.lock ~= nil and d.lockOn == LockOn, "the client loads and hands its lock to the hooks")

case("client: a target the spider has not seen cannot be locked; R recentres instead", function()
	setUp(AHEAD, false) -- behind the spider, still: no inspection, no cue
	frames(120)
	local placed = false
	for _, c in d.memory:contacts() do if c.hasPosition then placed = true end end
	check(not placed, "the memory has placed nothing")
	tap("Recenter")
	check(d.lock.trackId == nil and d.cam.recenterT >= 0, "no lock; the camera recentres")
	frames(30)
	check(not touchButton("Lock").Visible, "the touch Lock button is hidden: nothing to lock")
end)

case("client: seen, R locks it; the camera frames it, the body faces it, the touch button says Unlock", function()
	setUp(AHEAD, true)
	frames(240)
	local c = d.memory:getContact(d.sensor:trackIdFor("test_target"))
	check(c ~= nil and c.hasPosition, "the sensor has placed it")
	check(touchButton("Lock").Visible and touchButton("Lock").Text == "Lock", "the touch Lock button shows")
	d.cam.yaw += math.rad(70) -- the player looks well away
	frames(2)
	tap("Recenter")
	check(d.lock.trackId == d.sensor:trackIdFor("test_target") and d.lock.point ~= nil, "locked onto it")
	frames(90)
	local cf = camera.CFrame
	local off = deg(cf.LookVector, AHEAD - cf.Position)
	print(`LOCK camera: {string.format("%.2f", off)} degrees from the middle 1.5 s after a lock taken 70 degrees away`)
	check(off < 12, `the camera turned back to frame it ({off} degrees from the middle)`)
	check(deg(d.motor.heading, SupportMath.tangentDir(AHEAD - d.motor.pos, d.motor.up)) < 3, "the body faces it")
	check(touchButton("Lock").Visible and touchButton("Lock").Text == "Unlock", "the touch button says Unlock")
	check(d.perceptionHud.lockShown == true, "the lock's ticks are on the screen")
end)

case("client: the sidestep at a creep, at the same distance, still facing it; Cancel lets go", function()
	setUp(AHEAD, true)
	frames(240)
	tap("Recenter")
	frames(30)
	local keep = LockOn.planar(d.motor.pos, d.motor.up, d.lock.point)
	local start = d.motor.pos
	key("Right", true); frames(90); key("Right", false); frames(2)
	local moved = (d.motor.pos - start).Magnitude
	local creep = Species.phidippus_audax_prototype.locomotion.stalk_speed_wu_s
	print(`LOCK client sidestep: {string.format("%.3f", moved)} in 1.5 s, distance {string.format("%.3f", keep)} to {string.format("%.3f", LockOn.planar(d.motor.pos, d.motor.up, AHEAD))}, facing {string.format("%.2f", deg(d.motor.heading, SupportMath.tangentDir(AHEAD - d.motor.pos, d.motor.up)))} degrees off`)
	check(moved > creep * 0.8 and moved < creep * 1.6, `D moved it at the creep ({moved} in 1.5 s at {creep} a second)`)
	check(math.abs(LockOn.planar(d.motor.pos, d.motor.up, AHEAD) - keep) < 0.12, "at the distance it had")
	check(deg(d.motor.heading, SupportMath.tangentDir(AHEAD - d.motor.pos, d.motor.up)) < 8, "still facing it")
	check(d.lock.trackId ~= nil, "still locked (the sensor kept seeing it)")
	key("Forward", true); frames(40); key("Forward", false); frames(2)
	check(LockOn.planar(d.motor.pos, d.motor.up, AHEAD) < keep - 0.2, "W closed in")
	tap("Cancel")
	check(d.lock.trackId == nil and d.lock.released == "cancel", "Cancel let go")
	local before = d.motor.pos
	key("Right", true); frames(30); key("Right", false)
	check((d.motor.pos - before).Magnitude > 0.5, "and D walks again, at the walk")
end)

case("client: the jump's aim snaps to it; R again lets go and recentres", function()
	setUp(AHEAD, true)
	frames(240)
	tap("Recenter")
	frames(30)
	key("Jump", true); frames(20)
	local origin, dir = d.motor.aimOrigin, d.motor.aimDirection
	check(d.jump:isAiming() and deg(dir, d.lock.point - origin) < 1e-3, "aiming: the aim ray is on the locked thing")
	key("Cancel", true); frames(1); key("Cancel", false); key("Jump", false); frames(2)
	check(not d.jump:isAiming() and d.lock.trackId ~= nil, "Cancel cancelled the aim first (it had that to do) and the lock holds")
	tap("Recenter")
	check(d.lock.trackId == nil and d.cam.recenterT >= 0, "R let go and recentred")
end)

case("client: when it is gone, the lock ends by itself (the spider, turned to the mark, finds the spot empty and the memory lets it go; never later than the decay time)", function()
	setUp(AHEAD, true)
	frames(240)
	tap("Recenter")
	check(d.lock.trackId ~= nil, "locked")
	d.stage.target.position = Vector3.new(-26, 2.8, 20) -- gone from where it was, out of sight
	local frameCount = 0
	while d.lock.trackId ~= nil and frameCount < 600 do frames(1); frameCount += 1 end
	print(`LOCK lost: ended ({d.lock.released}) after {string.format("%.2f", frameCount / 60)} s`)
	check(d.lock.trackId == nil and (d.lock.released == "forgotten" or d.lock.released == "empty"), `ended ({d.lock.released}) after {frameCount / 60} s`)
	check(frameCount / 60 <= Species.phidippus_audax_prototype.perception.memory_decay_s + 0.5, "within the memory's decay time")
end)

case("client: L1 toggles lock immediately; R2 is Focus only; R3 recentres", function()
	local SpiderInput = require("../src/Client/SpiderInput")
	local B = SpiderInput.BINDINGS
	local function has(list: { any }, code: any): boolean for _, c in list do if c == code then return true end end return false end
	check(has(B.Creep, Enum.KeyCode.ButtonL1), "L1 has a single combined creep/lock binding")
	check(has(B.Focus, Enum.KeyCode.ButtonR2) and has(B.Focus, Enum.UserInputType.MouseButton2), "R2 and right mouse focus")
	check(has(B.Run, Enum.KeyCode.ButtonL2) and not has(B.Slow, Enum.KeyCode.ButtonL2), "L2 runs without slowing time")
	check(has(B.PadRecenter, Enum.KeyCode.ButtonR3) and has(B.Recenter, Enum.KeyCode.R), "R3 recentres, R keeps keyboard lock")
	setUp(AHEAD, true)
	frames(240)
	key("Creep", true, "ButtonL1"); frames(1)
	check(d.lock.trackId ~= nil and d.input.held.Creep == true, "L1 creeps and locks on press without delay")
	frames(30); key("Creep", false, "ButtonL1"); frames(1)
	check(d.lock.trackId ~= nil and d.input.held.Focus == nil, "held L1 keeps lock and never focuses; release keeps lock")
	tap("Creep", "ButtonL1")
	check(d.lock.trackId == nil, "second L1 press unlocks")
	key("Focus", true, "ButtonR2"); frames(1)
	check(d.input.held.Focus == true and d.lock.trackId == nil, "R2 focuses immediately without locking")
	key("Focus", false, "ButtonR2"); frames(1)
	check(d.input.held.Focus == nil and d.lock.trackId == nil, "R2 release ends Focus without locking")
	tap("Creep", "ButtonL1")
	check(d.lock.trackId ~= nil, "L1 locks again after Focus")
	d.lockOn.release(d.lock, "test")
	key("Creep", true, "LeftControl")
	key("Creep", true, "ButtonL1"); frames(1)
	check(d.lock.trackId ~= nil, "L1 takes its contextual lock even while Ctrl is already creeping")
	key("Creep", false, "ButtonL1")
	check(d.input.held.Creep == true, "L1 release leaves keyboard creep held")
	key("Creep", false, "LeftControl")
	d.cam.recenterT = -1
	tap("PadRecenter", "ButtonR3")
	check(d.lock.trackId == nil and d.cam.recenterT >= 0, "R3 lets go of the lock and recentres")
	tap("PadRecenter", "ButtonR3")
	check(d.lock.trackId == nil, "R3 never locks")
	d.input:simulate("Lock", true); frames(1); d.input:simulate("Lock", false); frames(1)
	check(d.lock.trackId ~= nil, "the touch button locked")
	d.cam.recenterT = -1
	d.input:simulate("Lock", true); frames(1); d.input:simulate("Lock", false)
	check(d.lock.trackId == nil and d.cam.recenterT < 0, "and let go, without recentring")
end)

case("client: Reduced Motion holds the view still while the thing stays near the middle, and cuts when it drifts", function()
	player:SetAttribute("ReducedMotion", true)
	setUp(AHEAD, true)
	frames(240)
	tap("Recenter")
	frames(5)
	local yaw0 = d.cam.yaw
	d.cam.yaw += math.rad(10); frames(3)
	check(math.abs(d.cam.yaw - (yaw0 + math.rad(10))) < 1e-6, "10 degrees off: the view stays where it is")
	d.cam.yaw += math.rad(30); frames(1)
	check(math.abs(((d.cam.yaw - yaw0 + math.pi) % (2 * math.pi)) - math.pi) < math.rad(3), "40 degrees off: one cut back to it")
	player:SetAttribute("ReducedMotion", nil)
	tap("Recenter")
end)

case("client: the eye view keeps it in the middle too", function()
	setUp(AHEAD, true)
	frames(240)
	tap("Recenter")
	tap("Eye")
	frames(5)
	d.cam.gaze = SupportMath.rotateToward(d.cam.gaze, Vector3.xAxis, math.rad(40))
	frames(60)
	local cf = camera.CFrame
	check(d.cam.eyeView and deg(cf.LookVector, AHEAD - cf.Position) < 8, `the gaze turned back to it ({deg(cf.LookVector, AHEAD - cf.Position)} degrees)`)
	tap("Eye")
	tap("Recenter")
end)

case("client: Show what the spider notices off hides the rings and words; the lock's ticks stay", function()
	setUp(AHEAD, true)
	frames(240)
	local function shown(kind: string): number
		local n = 0
		for _, w in d.perceptionHud.pools[kind] do if w.frame.Visible then n += 1 end end
		return n
	end
	check(shown("circle") + shown("label") > 0, "on (the default): the target's ring and word are drawn")
	player:SetAttribute("ShowNoticed", false)
	frames(2)
	check(d.setting("ShowNoticed") == false and shown("circle") == 0 and shown("label") == 0, "off: no ring, no word")
	tap("Recenter")
	frames(30)
	check(d.lock.trackId ~= nil and d.perceptionHud.lockShown == true and shown("bar") >= 4, "the lock works without them, and its four ticks are drawn")
	tap("Recenter")
	player:SetAttribute("ShowNoticed", nil)
	frames(2)
	check(shown("circle") + shown("label") > 0, "on again: back")
end)

print(`LOCK passed={passed} failed={failed}`)
if failed > 0 then error("lock checks failed") end
