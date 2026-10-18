-- Port check: the Luau JumpMath and SupportMath against values produced by the Godot game's own jump_math.gd.
-- Run from roblox_port/:  luau tests/run.luau
local shim = require("./shim")
_G.Vector3 = shim.Vector3
_G.CFrame = shim.CFrame
local JumpMath = require("../src/Shared/Movement/JumpMath")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local ref = require("./jump_reference")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end
local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end
local function v(t) return Vector3.new(t[1], t[2], t[3]) end

-- Godot's Vector3 is single precision, so values agree to float32 rounding (about 1e-7 relative), not bit for bit.
local F32 = 2e-5
local g = Vector3.new(0, ref.gravity, 0)
for i, c in ref.cases do
	local r = JumpMath.solve(v(c.p0), v(c.seat), v(c.ln), v(c.tn), g, ref.dt, ref.t_min, ref.t_max, ref.max_speed)
	check(r.reason == c.reason, `case {i}: reason {r.reason} == {c.reason}`)
	check(#r.valid == c.count, `case {i}: {#r.valid} solutions == {c.count}`)
	if c.minSpeed >= 0 then
		check(near(r.minSpeed, c.minSpeed, F32 * c.minSpeed), `case {i}: min speed {r.minSpeed} == {c.minSpeed}`)
	end
	if c.steps > 0 then
		local s = r.valid[1]
		check(s.steps == c.steps, `case {i}: steps {s.steps} == {c.steps}`)
		check(near(s.speed, c.speed, F32 * c.speed), `case {i}: speed {s.speed} == {c.speed}`)
		check((s.velocity - v(c.v)).Magnitude < F32 * c.speed, `case {i}: launch velocity matches`)
		-- Flying the discrete tick loop lands exactly on the seat.
		local path = JumpMath.path(v(c.p0), s.velocity, g, ref.dt, s.steps)
		check((path[#path] - v(c.seat)).Magnitude < 1e-9, `case {i}: tick loop lands on the seat`)
	end
end

local up = Vector3.new(0, 1, 0)
check(JumpMath.isStanding(up) and not JumpMath.isStanding(Vector3.new(1, 0, 0)), "floor stands, wall does not")
check(JumpMath.minApproach(Vector3.new(1, 0, 0)) == 0.3, "walls need 0.3 approach")
local t = SupportMath.tangentDir(Vector3.new(1, 1, 0), up)
check((t - Vector3.new(1, 0, 0)).Magnitude < 1e-12, "tangentDir drops the normal part")
local r = SupportMath.rotateToward(Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), math.rad(30))
check(near(SupportMath.angleTo(Vector3.new(1, 0, 0), r), math.rad(30), 1e-9), "rotateToward caps the turn")
check(SupportMath.filterNormal(up, Vector3.new(0.01, 1, 0).Unit, 2) == up, "filterNormal ignores tiny changes")

local Appearance = require("../src/Shared/Data/Appearances")
local InputState = require("../src/Shared/Movement/InputState")
local look = Appearance.profiles[Appearance.default]
check(look.body[1] == 0 and look.body[2] == 0 and look.body[3] == 0, "first spider is black")
check(#look.spots == 5 and look.spots[1].rx > look.spots[2].rx * 3, "five spots with large centre")
check(look.spots[2].z < 0 and look.spots[3].z < 0 and look.spots[4].z > 0 and look.spots[5].z > 0, "two front and two rear spots")
check(look.frontLegScale > 1 and look.speckleCount <= 24, "stout front legs and bounded speckles")
local input = InputState.new()
input:set("Forward", true); input:set("Right", true)
local x,y = input:axes()
check(near(x*x+y*y,1,1e-9), "diagonal input normalized")
input:clear(); input:stick(0.1,0)
x,y = input:axes(); check(x == 0 and y == 0, "stick deadzone")
input:stick(0,1); x,y=input:axes(); check(x == 0 and y == 1, "stick full forward")
input:set("Creep", true); input:clear(); x,y=input:axes()
check(x == 0 and y == 0 and not input.held.Creep, "focus loss clears movement and creep")


-- Camera and stick math against values exported from the frozen Godot rig (tools/export_camera_reference.gd).
local CameraMath = require("../src/Shared/Movement/CameraMath")
local cam = require("./camera_reference")
local function vnear(a: Vector3, b, eps: number): boolean
	return math.abs(a.X - b[1]) <= eps and math.abs(a.Y - b[2]) <= eps and math.abs(a.Z - b[3]) <= eps
end
local axesOk, mapOk = true, true
for _, c in cam.axes do
	local right, forward = CameraMath.tangentAxes(c.yaw, c.elev, v(c.n))
	if not (vnear(right, c.right, 1e-5) and vnear(forward, c.forward, 1e-5)) then axesOk = false; print("axes", c.yaw, c.elev, c.n[1], c.n[2], c.n[3]) end
	for k, st in cam.sticks do
		if not vnear(CameraMath.mapStick(st[1], st[2], c.yaw, c.elev, v(c.n)), c.mapped[k], 1e-5) then mapOk = false end
	end
end
check(axesOk, `surface axes match Godot SurfaceInput ({#cam.axes} views and normals)`)
check(mapOk, "stick mapping matches Godot SurfaceInput on floors, walls and undersides")
local backOk = true
for _, c in cam.backs do
	backOk = backOk and vnear(CameraMath.backDirection(c.yaw, c.elev), c.back, 1e-6)
		and vnear(CameraMath.cameraRight(c.yaw, c.elev), c.x, 1e-6) and vnear(CameraMath.cameraUp(c.yaw, c.elev), c.y, 1e-6)
end
check(backOk, "orbit basis matches Godot BoomMath")
local lenOk = true
for _, c in cam.next_length do lenOk = lenOk and near(CameraMath.nextLength(c["in"][1], c["in"][2], c["in"][3], c["in"][4], c["in"][5]), c.out, 1e-6) end
check(lenOk, "boom retracts at once and recovers at the Godot rate")
local easeOk = true
for _, c in cam.ease do easeOk = easeOk and near(CameraMath.easeOffset(c["in"][1], c["in"][2], c["in"][3], c["in"][4], c["in"][5]), c.out, 1e-6) end
check(easeOk, "eased offsets match Godot BoomMath")
local pickOk = true
for _, c in cam.pick do pickOk = pickOk and near(CameraMath.pickPitchOffset(c.offsets, c.lengths, 2.5), c.out, 1e-9) end
check(pickOk, "auto-pitch pick matches Godot BoomMath")
local clampOk = true
for _, c in cam.aim_clamp do clampOk = clampOk and near(CameraMath.clampAimPitch(c["in"][1], c["in"][2]), c.out, 1e-6) end
check(clampOk, "aim free-look clamp matches Godot camera rig")
local effOk = true
for _, c in cam.effective do effOk = effOk and near(CameraMath.effectiveElevation(c["in"][1], c["in"][2]), c.out, 1e-6) end
check(effOk, "effective elevation matches Godot camera rig")
local gazeOk = true
for _, c in cam.gaze_clamp do gazeOk = gazeOk and vnear(CameraMath.clampGaze(v(c.g), v(c.up), Vector3.new(0, 0, -1)), c.out, 1e-5) end
check(gazeOk, "spider-eye gaze clamp matches Godot camera rig")
local lookOk = true
for _, c in cam.look_eye do lookOk = lookOk and vnear(CameraMath.lookEye(v(c.g), v(c.up), c.yaw, c.pitch, Vector3.new(0, 0, -1)), c.out, 1e-5) end
check(lookOk, "spider-eye look turns match Godot camera rig")
check(near(CameraMath.recenterYaw(Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), 0), -math.pi / 2, 1e-9), "recenter puts the camera behind the heading on a floor")
check(near(CameraMath.recenterYaw(Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), 0), 0, 1e-9), "recenter faces the wall when climbing")

-- Input: V/Y view toggle and look axes.
input:clear(); input:look(0.1, 0); local lx, ly = input:lookAxes()
check(lx == 0 and ly == 0, "look deadzone")
input:set("LookRight", true); lx, ly = input:lookAxes(); check(lx == 1 and ly == 0, "arrow keys look")
input:clear(); lx, ly = input:lookAxes(); check(lx == 0 and ly == 0, "focus loss clears look")
input:stick(1, 0); lx, ly = input:lookAxes(false); check(lx == 0 and ly == 0, "left stick does not turn normal camera")
lx, ly = input:lookAxes(true); check(lx == 1 and ly == 0, "left stick aims a held jump")
input:stick(0, 1); lx, ly = input:lookAxes(true); check(lx == 0 and ly == -1, "left-stick up aims up")
input:look(0, -1); lx, ly = input:lookAxes(true); check(ly == 0, "both sticks combine without doubling the rate")
input:clear(); lx, ly = input:lookAxes(true); check(lx == 0 and ly == 0, "focus loss clears jump aim too")

-- Fuzz layout (pure): enough hairs to read as fuzzy, bounded for the frame budget, white over the white pattern, eyes clear.
local Setae = require("../src/Shared/Rig/Setae")
local hairs = Setae.body(look)
local whites, overEyes, finiteOk = 0, 0, true
for _, h in hairs do
	if h.white then whites += 1 end
	finiteOk = finiteOk and h.at.X == h.at.X and math.abs(h.dir.Magnitude - 1) < 1e-9 and h.length > 0.02 and h.length < 0.1
	if (h.at - Vector3.new(-0.075, 0.09, -0.455)).Magnitude < 0.06 or (h.at - Vector3.new(0.075, 0.09, -0.455)).Magnitude < 0.06 then overEyes += 1 end
end
local legHairs = 0
for i = 1, 8 do legHairs += #Setae.leg(look, i) end
check(#hairs >= 300 and #hairs + legHairs <= 700, `fuzz is dense and bounded ({#hairs} body + {legHairs} leg hairs)`)
print(`fuzz: {#hairs} body hairs, {legHairs} leg hairs, {whites} white`)
check(whites >= 15 and whites < #hairs / 2, `white hairs follow the white pattern ({whites})`)
check(overEyes == 0, "no hairs over the principal eyes")
check(finiteOk, "every hair is finite, unit-directed and short")
local again = Setae.body(look)
check(#again == #hairs and again[17].at == hairs[17].at, "fuzz layout is deterministic")


local Tether = require("../src/Shared/Movement/TetherMath")
local golden = require("./tether_reference")
local function vector(a) return Vector3.new(a[1],a[2],a[3]) end
for i,case in golden.cases do
    local got=Tether.constrain(Vector3.zero,case.length,vector(case.target),vector(case.velocity))
    local expected=case.result
    check((got.position-vector(expected.position)).Magnitude<1e-5,`tether {i} position`)
    check((got.velocity-vector(expected.velocity)).Magnitude<1e-5,`tether {i} velocity`)
    check(got.acted==expected.acted,`tether {i} unilateral`)
    check(near(got.radial_after,expected.radial_after,1e-5),`tether {i} radial`)
    check(got.velocity.Magnitude<=vector(case.velocity).Magnitude+1e-6,`tether {i} no speed added`)
end
check(near(Tether.energy(Vector3.new(0,3,0),Vector3.new(3,4,0),35),golden.energy,1e-6),"Godot energy")
check(near(Tether.reelWorkBound(0.025,35,4,2),golden.work,1e-6),"Godot reel work")
check(near(Tether.sagDepth(3,4),golden.sag,1e-6),"Godot sag")
local paid,rest=Tether.lock(4,3,20,0.25)
check(paid==4 and rest==4.25,"lock keeps paid line and braking extension")
paid,rest=Tether.lock(19.9,20.5,20,0.25)
check(paid==20 and rest==20,"maximum length bounds lock")
check(near(Tether.reel(4,0,20,1,1.5),3.975,1e-9),"reel is species speed at fixed tick")
check(Tether.reel(0.4,0,20,1,1.5)==0.4,"shortest line")
check(Tether.reel(20,0,20,-1,1.5)==20,"lowering capped")
local release=Tether.newRelease()
local accidental=false
for _=1,180 do accidental=accidental or Tether.releaseTick(release,true,true) end
check(not accidental,"held before catch never releases")
Tether.releaseTick(release,true,false)
for _=1,35 do accidental=accidental or Tether.releaseTick(release,true,true) end
check(not accidental,"short hold does not release")
check(Tether.releaseTick(release,true,true),"36-tick deliberate hold releases")
release=Tether.newRelease()
for _=1,30 do Tether.releaseTick(release,true,false) end
for _=1,12 do Tether.releaseTick(release,true,true) end
Tether.releaseTick(release,true,false)
check(release.progress==0,"tap release resets progress")

-- ---------------------------------------------------------------- ROBLOX-08: one control scheme for every device
-- InputState: a key, a controller button and a finger can hold the same action; each press and release is heard once.
do
	local st = InputState.new()
	local w1, n1 = st:set("Cancel", true, "KeyQ")
	local w2, n2 = st:set("Cancel", true, "touch1")
	local w3, n3 = st:set("Cancel", false, "KeyQ")
	check(not w1 and n1 and w2 and n2 and w3 and n3 and st.held.Cancel == true, "a key and a finger hold one action together; releasing one keeps it held")
	local w4, n4 = st:set("Cancel", false, "touch1")
	check(w4 and not n4 and st.held.Cancel == nil, "releasing the last source releases the action")
	local a, b = st:set("Jump", true, "Space")
	local c, d = st:set("Jump", true, "Space")
	check(not a and b and c and d and st:count("Jump") == 1, "a repeated down from one source is still one press")
	st:set("Focus", true, "MouseButton2"); st:set("Creep", true, "ButtonL1")
	st:clear()
	local e, f = st:set("Focus", false, "MouseButton2")
	check(not e and not f and st.held.Creep == nil and st:count("Focus") == 0, "focus loss drops every source of every action")
	st:set("Forward", true); st:stick(-1, 0)
	local x, y = st:axes()
	check(near(x * x + y * y, 1, 1e-9) and x < 0 and y > 0, "keys and the stick combine, within unit length")
end

-- JumpInput (port of jump_controller.gd, hold mode) against a stand-in motor.
local JumpInput = require("../src/Shared/Movement/JumpInput")
local function fakeMotor()
	local m = { attached = true, preparing = false, commits = {}, aims = 0,
		hop = { kind = "reachable", reason = "ok", name = "hop" }, aim = { kind = "reachable", reason = "ok", name = "aim" } }
	function m.canPrepare(self) return self.attached end
	function m.beginPrepare(self) if not self.attached then return false end self.preparing = true return true end
	function m.cancelPrepare(self) self.preparing = false end
	function m.isPreparing(self) return self.preparing and self.attached end
	function m.clearAimTarget(_self) end
	function m.hopPlan(self) return self.hop end
	function m.aimPlan(self) self.aims += 1 return self.aim end
	function m.commit(self, plan)
		if plan.kind ~= "reachable" or not self.attached then return false end
		table.insert(self.commits, plan); self.preparing = false; self.attached = false
		return true
	end
	return m
end
local function jumpWith(m)
	local j = JumpInput.new()
	local aims = {}
	j.onAim = function(on) table.insert(aims, on) end
	return j, aims
end
do
	local m = fakeMotor(); local j, aims = jumpWith(m)
	j:press(); for _ = 1, 3 do j:step(m) end; j:release(); j:step(m)
	check(#m.commits == 1 and m.commits[1].name == "hop" and #aims == 0 and j.last.kind == "launched", "a tap is a hop, planned like a leap, with no aim")
	m = fakeMotor(); j, aims = jumpWith(m)
	j:press(); for _ = 1, 8 do j:step(m) end
	local before = j.phase
	j:step(m)
	check(JumpInput.HOLD_TICKS == math.max(1, math.ceil(0.15 * 60 - 1e-6)) and before == "pressed" and j.phase == "aiming" and m.preparing
		and aims[1] == true and #aims == 1, "held for 9 ticks (Godot's 0.15 s) it aims and the spider holds still")
	j:release(); j:step(m)
	check(#m.commits == 1 and m.commits[1].name == "aim" and j.phase == "idle" and aims[2] == false, "release on a reachable patch leaps with the plan the patch showed")
	m = fakeMotor(); j, aims = jumpWith(m)
	m.aim = { kind = "unreachable", reason = "too_far" }
	j:press(); for _ = 1, 12 do j:step(m) end; j:release(); j:step(m)
	local flashed = j.flash == m.aim and j.last.kind == "refused"
	for _ = 1, JumpInput.FLASH_TICKS - 2 do j:step(m) end
	local still = j.flash ~= nil
	j:step(m)
	check(#m.commits == 0 and flashed and still and j.flash == nil and not m.preparing, "release off a reachable patch launches nothing and shows why for 60 ticks")
	m = fakeMotor(); j, aims = jumpWith(m)
	j:press(); for _ = 1, 12 do j:step(m) end; j:cancel(); j:step(m); j:release(); j:step(m)
	check(#m.commits == 0 and j.phase == "idle" and j.last.kind == "cancelled" and not m.preparing and aims[#aims] == false, "Q cancels an aim with no penalty and the later release does nothing")
	m = fakeMotor(); j = jumpWith(m)
	j:press(); for _ = 1, 3 do j:step(m) end; j:cancel(); j:step(m); j:release(); j:step(m)
	check(#m.commits == 0 and j.last.kind == "cancelled", "Q during a press, before the aim, cancels the hop too")
	m = fakeMotor(); j, aims = jumpWith(m)
	j:press(); for _ = 1, 12 do j:step(m) end
	j:drop(m); j:release(); j:step(m); j:press(); j:step(m)
	check(#m.commits == 0 and j.last == nil and not m.preparing and aims[#aims] == false and j.phase == "pressed", "focus loss ends an aim quietly; a release afterwards never leaps; the next press works")
	m = fakeMotor(); j = jumpWith(m)
	m.attached = false
	j:press(); for _ = 1, 12 do j:step(m) end; j:release(); j:step(m)
	check(#m.commits == 0 and j.phase == "idle" and j.last == nil, "a press in the air or on the line does nothing")
	m = fakeMotor(); j, aims = jumpWith(m)
	j:press(); for _ = 1, 12 do j:step(m) end
	m.attached = false; j:step(m)
	check(j.phase == "idle" and aims[#aims] == false, "losing the surface during an aim ends it")
	m = fakeMotor(); j = jumpWith(m)
	j:press(); j:release(); j:step(m)
	check(#m.commits == 1 and m.commits[1].name == "hop", "a press and release inside one tick still hop (events apply in order)")
	m = fakeMotor(); j = jumpWith(m)
	m.hop = { kind = "obstructed", reason = "hop_blocked", point = Vector3.zero }
	j:press(); j:step(m); j:release(); j:step(m)
	check(#m.commits == 0 and j.last.kind == "hop_refused" and j.flash == m.hop and not m.preparing, "a refused hop says why and leaves the spider standing")
end

-- ControlText: the words name only the device in use; texts are Godot's.
local ControlText = require("../src/Shared/UI/ControlText")
do
	check(ControlText.deviceFor("Touch", "keyboard") == "touch" and ControlText.deviceFor("Gamepad1", "touch") == "gamepad"
		and ControlText.deviceFor("MouseMovement", "gamepad") == "keyboard" and ControlText.deviceFor("Keyboard", "touch") == "keyboard"
		and ControlText.deviceFor("Focus", "gamepad") == "gamepad", "the last input decides the device; window focus keeps it")
	check(ControlText.initialDevice(true, false, false) == "touch" and ControlText.initialDevice(false, false, true) == "gamepad"
		and ControlText.initialDevice(true, true, true) == "keyboard", "before any input: touch-only shows touch, a console the controller")
	local function has(s, part) return string.find(s, part, 1, true) ~= nil end
	local _, kb = ControlText.linePanel({ reeling = false, progress = 0, snagged = false, block = "" }, "keyboard")
	local _, pad = ControlText.linePanel({ reeling = false, progress = 0, snagged = false, block = "" }, "gamepad")
	local _, touch = ControlText.linePanel({ reeling = false, progress = 0, snagged = false, block = "" }, "touch")
	check(kb == "W: reel in    S: lower    hold Q: let go" and pad == "Stick up: reel in    Stick down: lower    hold B: let go"
		and touch == "↑: reel in    ↓: lower    hold Let go: let go", "the line's prompts name each device's own controls")
	local title, hint = ControlText.describe({ kind = "reachable", reason = "ok" }, "keyboard")
	local _, padHint = ControlText.describe({ kind = "reachable", reason = "ok" }, "gamepad")
	check(title == "Reachable" and hint == "release to leap    Q: cancel the jump" and padHint == "release to leap    Left stick: aim    B: cancel the jump",
		"Q / B cancels an aim (the same button lets go of the line only when held)")
	local t1 = ControlText.describe({ kind = "obstructed", reason = "no_room" }, "keyboard")
	local t2, h2 = ControlText.describe({ kind = "unreachable", reason = "too_far" }, "touch")
	local t3 = ControlText.describe({ kind = "ineligible", reason = "ineligible_surface" }, "keyboard")
	local t4 = ControlText.describe(nil, "keyboard")
	check(t1 == "Blocked: no room to land" and t2 == "Out of reach: too far or too high" and h2 == "release to cancel    Cancel: cancel the jump"
		and t3 == "Can't land there: the spider cannot hold on there" and t4 == "No surface in view", "the patch's titles and reasons are Godot's")
	check(ControlText.toast("refused", { reason = "graze" }) == "Jump cancelled: it would only graze the surface"
		and ControlText.toast("hop_refused", { reason = "no_ground" }) == "No hop: nothing to land on ahead"
		and ControlText.toast("cancelled", nil) == "Jump cancelled" and ControlText.toast("launched", nil) == "", "jump toasts are Godot's")
	check(ControlText.lineToast("caught", "", true, false, "keyboard") == "Caught by your line" and ControlText.lineToast("caught", "", false, true, "keyboard") == ""
		and ControlText.lineToast("completed", "", true, false, "keyboard") == "Holding on again. The line stays behind for a moment"
		and ControlText.lineToast("completed", "", false, false, "keyboard") == ""
		and ControlText.lineToast("dropped", "", false, true, "keyboard") == "Letting yourself down: hold F to lower, W to climb"
		and ControlText.lineToast("dropped", "", false, true, "gamepad") == "Letting yourself down: hold X to lower, Stick up to climb"
		and ControlText.lineToast("drop_refused", "no_silk", false, false, "touch") == "This surface won't hold your silk"
		and ControlText.lineToast("released", "", true, false, "touch") == "You let go of the line", "line toasts are Godot's, with the device's keys")
	local _, _, c1 = ControlText.linePanel({ progress = 0.4, snagged = true, block = "blocked" }, "keyboard")
	local _, _, c2 = ControlText.linePanel({ progress = 0, snagged = true, block = "" }, "keyboard")
	local _, _, c3 = ControlText.linePanel({ progress = 0, snagged = false, block = "blocked" }, "keyboard")
	local t5 = ControlText.linePanel({ reeling = true, progress = 0, block = "" }, "keyboard")
	check(c1 == "Letting go... 40%" and has(c2, "caught on a second edge") and has(c3, "something is in the way") and t5 == "On your line: reeling in",
		"the line panel's cue: the let-go hold first, then a snag, then a blocked reel")
	check(ControlText.touchCancelLabel(true) == "Let go\n(hold)" and ControlText.touchCancelLabel(false) == "Cancel", "the touch Cancel button is Let go on the line")
	check(has(ControlText.helpCard("keyboard"), "Hold Space") and has(ControlText.helpCard("gamepad"), "Hold A") and has(ControlText.helpCard("touch"), "Hold Jump")
		and has(ControlText.walkHint("gamepad"), "X: let yourself down") and has(ControlText.edgeWalkHint("touch"), "Cancel or move: stop"),
		"the controls card and reminders are written for each device")
end

-- HudLayout: prompts never under a touch button, wide enough to read, at phone, tablet and desktop sizes.
local HudLayout = require("../src/Shared/UI/HudLayout")
do
	local sizes = { { 568, 320 }, { 667, 375 }, { 844, 390 }, { 932, 430 }, { 1024, 768 }, { 1180, 820 }, { 1366, 1024 }, { 390, 844 }, { 768, 1024 } }
	local clear, wide, inside, apart, panelInside = true, true, true, true, true
	for _, sz in sizes do
		local w, h = sz[1], sz[2]
		local rects = {}
		for _, b in HudLayout.TOUCH_BUTTONS do table.insert(rects, HudLayout.buttonRect(b, w, h)) end
		local x0, x1, bottom = HudLayout.promptSpan(w, h, "touch")
		local panel = { x0 = x0, y0 = bottom - 120, x1 = x1, y1 = bottom } -- three wrapped lines and a title
		if panel.y0 < 0 or panel.y1 > h then panelInside = false end
		for i, r in rects do
			if HudLayout.overlaps(panel, r) then clear = false; print("overlap", w, h, i) end
			if r.x0 < 0 or r.y0 < 0 or r.x1 > w or r.y1 > h then inside = false end
			for k = i + 1, #rects do if HudLayout.overlaps(r, rects[k]) then apart = false end end
		end
		if x1 - x0 < 260 then wide = false; print("narrow", w, h, x1 - x0) end
	end
	check(clear and wide, "touch prompts sit between or above the thumb buttons, at least 260 px wide, at phone and tablet sizes")
	check(inside and apart, "touch buttons stay inside the safe area and never overlap")
	check(panelInside, "touch prompt stays vertically inside the safe area, including short landscape phones")
	local x0, x1, bottom = HudLayout.promptSpan(1920, 1080, "keyboard")
	check(near(x1 - x0, 760, 1e-9) and near((x0 + x1) / 2, 960, 1e-9) and bottom == 1064, "keyboard and controller prompts are centred, at most 760 px wide")
end

-- ROBLOX-50: touch targets and the top strip. Every touch button is at least 48 px each way and a few pixels from the next; the Menu and
-- Notebook buttons are touch targets too, on screen, clear of each other, of the touch buttons, of the prompt panel and of the status column.
do
	local sizes = { { 360, 640 }, { 390, 844 }, { 568, 320 }, { 667, 375 }, { 844, 390 }, { 932, 430 }, { 768, 1024 }, { 1024, 768 }, { 1180, 820 }, { 1280, 720 }, { 1366, 1024 }, { 1920, 1080 }, { 1100, 500 } }
	local small, close, bad, gaps = {}, {}, {}, {}
	for _, sz in sizes do
		local w, h = sz[1], sz[2]
		local name = `{w}x{h}`
		local rects = {}
		for _, b in HudLayout.TOUCH_BUTTONS do
			local laid = HudLayout.layoutButton(b, w, h)
			if laid.size < HudLayout.MIN_TARGET then table.insert(small, `{name} {b.action} {laid.size}`) end
			rects[b.action] = HudLayout.buttonRect(b, w, h)
		end
		for a, ra in rects do
			for b2, rb in rects do
				if a < b2 then
					local gx = math.max(rb.x0 - ra.x1, ra.x0 - rb.x1)
					local gy = math.max(rb.y0 - ra.y1, ra.y0 - rb.y1)
					if math.max(gx, gy) < 4 then table.insert(close, `{name} {a}/{b2} {math.max(gx, gy)}`) end
				end
			end
		end
		local t = HudLayout.topLayout(w, h)
		local x0, x1, bottom = HudLayout.promptSpan(w, h, "touch")
		local short = h < 450 -- a landscape phone has about four lines in all for the status lines and the prompt
		local panel = { x0 = x0, y0 = bottom - (if short then 66 else 120), x1 = x1, y1 = bottom }
		local column = { x0 = t.columnX0, y0 = t.columnY, x1 = t.columnX1, y1 = t.columnY + (if short then 50 else 110) } -- a day line, a notice and a toast (two lines on a short screen)
		for label, r in { Menu = t.menu, Notebook = t.notebook } do
			if r.x1 - r.x0 < HudLayout.MIN_TARGET or r.y1 - r.y0 < HudLayout.MIN_TARGET then table.insert(bad, `{name} {label} too small`) end
			if r.x0 < 0 or r.y0 < 0 or r.x1 > w or r.y1 > h then table.insert(bad, `{name} {label} off screen`) end
			if HudLayout.overlaps(r, column) then table.insert(bad, `{name} {label} covers the status column`) end
			if HudLayout.overlaps(r, panel) then table.insert(bad, `{name} {label} covers the prompts`) end
			for action, rb in rects do
				local gx = math.max(rb.x0 - r.x1, r.x0 - rb.x1)
				local gy = math.max(rb.y0 - r.y1, r.y0 - rb.y1)
				if math.max(gx, gy) < 4 then table.insert(bad, `{name} {label} is within 4 px of {action}`) end
			end
		end
		if HudLayout.overlaps(t.menu, t.notebook) then table.insert(bad, `{name} Menu and Notebook overlap`) end
		if HudLayout.overlaps(column, panel) then table.insert(bad, `{name} the status column meets the prompts`) end
		if t.columnX1 - t.columnX0 < 260 then table.insert(bad, `{name} the status column is only {t.columnX1 - t.columnX0} wide`) end
		if math.abs((t.columnX0 + t.columnX1) / 2 - w / 2) > 1e-6 then table.insert(bad, `{name} the status column is not centred`) end
	end
	for _, m in small do print("  small touch button: " .. m) end
	for _, m in close do print("  touch buttons too close: " .. m) end
	for _, m in bad do print("  top strip: " .. m) end
	check(#small == 0, "every touch button is at least 48 px each way, at every screen size")
	check(#close == 0, "and at least 4 px from the next one")
	check(#bad == 0, "Menu and Notebook are touch targets, on screen, and clear of each other, the touch buttons, the prompts and the status lines")
	check(HudLayout.topLayout(390, 844).stacked == false and HudLayout.topLayout(1280, 720).stacked == true, "a narrow phone has the buttons in a row, a wide screen in a stack")
end


-- ---------------------------------------------------------------- ROBLOX-09: the catch camera's line framing
-- Against values exported from the frozen Godot camera rig (tools/export_framing_reference.gd -> tests/framing_reference.json):
-- BoomMath.smooth_damp, the turn search with a capped 45-degree turn, and tick-by-tick take-overs.
local LineFraming = require("../src/Shared/Movement/LineFraming")
local F = require("./framing_reference")
do
	local damped = true
	for _, c in F.smooth_damp do
		local v, vel = CameraMath.smoothDamp(c["in"][1], c["in"][2], c["in"][3], c["in"][4], c["in"][5])
		damped = damped and near(v, c.out[1], 1e-12) and near(vel, c.out[2], 1e-12)
	end
	check(damped, `the framing turn eases exactly as Godot's BoomMath.smooth_damp ({#F.smooth_damp} cases)`)
	local decided, capped = true, true
	for _, c in F.decisions do
		local good = c.good
		local turn = LineFraming.wantedTurn(c.held, math.rad(c.cap_deg), function(t)
			for _, g in good do if math.abs(t - g) < 1e-6 then return true end end
			return false
		end)
		if not near(turn, c.out, 1e-12) then decided = false; print("decision", c.cap_deg, turn, c.out) end
		if c.cap_deg == 45 and math.abs(turn) > math.rad(45) + 1e-9 then capped = false end
	end
	check(decided, `the turn search matches Godot's _wanted_yaw_assist ({#F.decisions} cases: smallest step, + before -, held turn kept, nothing past the cap)`)
	check(capped and LineFraming.FRAMING_MAX_TURN_DEG == 45 and near(LineFraming.new().maxTurn, math.rad(45), 1e-15), "the turn is capped at 45 degrees")
	local function angleDiff(a, b) return (b - a + math.pi) % (2 * math.pi) - math.pi end
	local function rig(yaw0, turns)
		local r = { yaw = yaw0, framing = LineFraming.new(), onLine = true, aiming = false, good = {}, rows = {} }
		for _, t in turns do table.insert(r.good, yaw0 + t) end
		return r
	end
	local function tick(r)
		r.yaw += r.framing:tick(r.onLine, r.aiming, function()
			return LineFraming.wantedTurn(r.framing.target, r.framing.maxTurn, function(turn)
				for _, g in r.good do if math.abs(angleDiff(r.yaw + turn, g)) < 1e-6 then return true end end
				return false
			end)
		end, F.dt)
	end
	local function row(r) table.insert(r.rows, { r.yaw, r.framing.assist, r.framing.target, if r.framing.off then 1 else 0 }) end
	local function ticks(r, n) for _ = 1, n do tick(r); row(r) end end
	local function matches(r, expected)
		if #r.rows ~= #expected then print("rows", #r.rows, #expected) return false end
		for i, e in expected do
			for k = 1, 4 do
				if not near(r.rows[i][k], e[k], 1e-9) then print("row", i, k, r.rows[i][k], e[k]) return false end
			end
		end
		return true
	end
	local d30 = math.rad(30)
	local r = rig(-0.5235987755982988, { d30 })
	ticks(r, 40)
	r.yaw += r.framing:playerTurns(r.onLine); r.yaw -= math.rad(1); row(r)
	ticks(r, 20)
	r.onLine = false; ticks(r, 1)
	check(matches(r, F.sequences.look_takes_over), "a one-degree look takes a held turn over at once, nothing jumps, and the framing stays off while the line is out")
	r = rig(0.1, { d30 })
	ticks(r, 3)
	r.yaw += r.framing:takeOver(); r.aiming = true; row(r)
	ticks(r, 5)
	r.aiming = false
	ticks(r, 10)
	check(matches(r, F.sequences.aim_takes_over), "aiming takes a turn in progress over (preparation wins)")
	r = rig(0, { d30 })
	ticks(r, 30)
	r.yaw += r.framing:playerTurns(r.onLine); row(r)
	check(matches(r, F.sequences.recenter_takes_over), "a recenter takes the turn over before it turns (recenter wins)")
	r = rig(0.7, { math.rad(-45) })
	ticks(r, 30)
	r.onLine = false
	ticks(r, 2)
	check(matches(r, F.sequences.line_end_keeps_view), "when the line ends the view stays where the framing put it")
	r = rig(0, { d30 })
	r.framing.enabled = false
	ticks(r, 10)
	check(matches(r, F.sequences.setting_off), "with 'Frame the line after a catch' off nothing turns")
	local f = LineFraming.new()
	f.assist, f.target = 0.4, 0.5
	check(near(f:setEnabled(false), 0.4, 1e-15) and f.assist == 0 and f:setEnabled(true) == 0, "switching the framing off with a turn held hands it to the player")
end


-- ---------------------------------------------------------------- ROBLOX-11: the stick's carry over an edge (player_controller._carry)
local StickCarry = require("../src/Shared/Movement/StickCarry")
do
	local up, down, fwd = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, 1)
	local c = StickCarry.new()
	local d = c:step(0, 1, fwd, 0, fwd, false)
	check(d == fwd and not c.carrying, "without a sharp turn the stick follows the view")
	d = c:step(0, 1, up, 1, down, false)
	check(c.carrying and (d - down).Magnitude < 1e-12, "a sharp turn with the stick held keeps the motor's own direction (down the face), not the view's (up)")
	d = c:step(0.3, 1, up, 1, down, false)
	check(c.carrying and (d - down).Magnitude < 1e-12, "turning the stick less than 30 degrees keeps carrying")
	d = c:step(1, 0.3, Vector3.xAxis, 1, down, false)
	check(not c.carrying and d == Vector3.xAxis, "turning the stick more than 30 degrees hands back to the view")
	c:step(0, 1, up, 2, down, false)
	d = c:step(0, 0, up, 2, down, false)
	check(not c.carrying and d == Vector3.zero, "releasing the stick ends the carry")
	c:step(0, 1, up, 3, down, false)
	local nearly = Vector3.new(0, -0.95, 0.31).Unit
	d = c:step(0, 1, nearly, 3, down, false)
	check(not c.carrying and d == nearly, "the view agreeing again (within 25 degrees) ends the carry")
	c:step(0, 1, up, 4, down, false)
	d = c:step(0, 1, nearly, 4, down, true)
	check(c.carrying and (d - down).Magnitude < 1e-12, "not while rounding an edge")
	c = StickCarry.new()
	d = c:step(0, 0.5, up, 1, down, false)
	check((d - down * 0.5).Magnitude < 1e-12, "the carried direction keeps the stick's strength")
	d = c:step(0, 1, up, 2, Vector3.zero, false)
	check(not c.carrying and d == up, "nothing to carry: the view's mapping")
end


ControlText.setPadStyle(ControlText.padStyleFor("ButtonCross"))
check(ControlText.padStyle() == "playstation" and ControlText.name("gamepad", "jump") == "Cross" and ControlText.name("gamepad", "focus") == "L2"
	and ControlText.name("gamepad", "eye") == "Triangle" and ControlText.name("gamepad", "walk") == "Left stick" and ControlText.name("keyboard", "jump") == "Space"
	and string.find(ControlText.helpCard("gamepad"), "Hold Cross", 1, true) ~= nil, "a PlayStation controller gets its own button names")
ControlText.setPadStyle(ControlText.padStyleFor("ButtonA"))
check(ControlText.padStyle() == "xbox" and ControlText.name("gamepad", "jump") == "A" and string.find(ControlText.helpCard("gamepad"), "Hold A", 1, true) ~= nil, "back to Xbox names")
print(`SUMMARY passed={passed} failed={failed}`)
if failed > 0 then error("port check failed") end
