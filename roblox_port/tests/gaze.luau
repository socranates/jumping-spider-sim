-- Gaze checks (D-036, Godot spider_motor.gd get_eye_position, get_gaze_direction, get_body_gaze_direction, set_scan_direction, _update_gaze):
-- the observer the senses read is the body's, never the camera's. The real SpiderMotor on the windowsill's own boxes (box world of tests/shim.luau),
-- tick by tick: where the eyes are, the gaze pitch that follows Focus within the species' limit and settles at half the rate, the retinas' scan
-- direction held within 30 degrees of the body's gaze, and the camera going round without moving the cone. The Godot cases are
-- test_sensor.gd (focus tilts the gaze within its limit) and test_t10a_eye_view.gd (the retinas, the head tilting toward the gaze).
-- Run with the other suites:  python3 tests/run.py path/to/luau gaze.luau
local shim = require("./shim")
_G.Vector3 = shim.Vector3
_G.CFrame = shim.CFrame
local Motor = require("../src/Shared/Movement/SpiderMotor")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local SpiderCamera = require("../src/Client/SpiderCamera")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function near(got: number, want: number, eps: number, what: string)
	check(math.abs(got - want) <= eps, `{what} (got {got}, wanted {want})`)
end
local function vnear(a: Vector3, b: Vector3, eps: number, what: string)
	check((a - b).Magnitude <= eps, `{what} (off by {(a - b).Magnitude}: {a} against {b})`)
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end

local DT = Motor.DT
local DEG = math.deg
local sill = BoxWorld.folder("GazeSill", Layout.PIECES)

local function newMotor(profile: any?): any
	return Motor.new({ world = sill, surfaces = Surfaces, profile = profile or Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = sill })
end
local function input(t: any?): any
	local i: any = Motor.idleInput()
	for k, v in t or {} do i[k] = v end
	return i
end
local function ticks(m: any, n: number, t: any?)
	for _ = 1, n do
		m:tick(input(t))
	end
end
-- A point `dist` out from the eyes along a direction: where the camera's centre ray meets something.
local function pointAlong(m: any, dir: Vector3): Vector3
	return m:eyePosition() + dir.Unit * 20
end
-- The unit direction `right` degrees to the right of the body's heading (on the floor) and `down` degrees below the horizon.
local function lookAt(m: any, right: number, down: number): Vector3
	local f = m.heading
	local r = f:Cross(m.up).Unit
	local flat = (f * math.cos(math.rad(right)) + r * math.sin(math.rad(right))).Unit
	return (flat * math.cos(math.rad(down)) - m.up * math.sin(math.rad(down))).Unit
end
local function angleDeg(a: Vector3, b: Vector3): number
	return DEG(SupportMath.angleTo(a, b))
end

-- =============================================================================================== the eyes

case("eyes: a standing spider's eyes sit ahead of and above the body, and the gaze is level", function()
	local m = newMotor()
	ticks(m, 10)
	check(m.mode == "attached", "it stands")
	vnear(m:eyePosition(), m.pos + m.heading * 0.18 + m.up * 0.08, 1e-9, "the eyes are 0.18 along the facing and 0.08 along the body's up")
	near(m.gazePitch, 0, 1e-12, "the gaze starts level")
	vnear(m:bodyGazeDirection(), m.heading, 1e-9, "level, the body's gaze is the facing")
	vnear(m:gazeDirection(), m:bodyGazeDirection(), 1e-12, "and with no scan direction the cone's axis is the body's gaze")
	check(m:scanDirection() == nil, "no scan direction")
	check(not m:isFocusing(), "Focus is off")
	local o = m:observer()
	vnear(o.eye, m:eyePosition(), 0, "the observer's eye")
	vnear(o.gaze, m:gazeDirection(), 0, "its gaze")
	vnear(o.up, m.up, 0, "its up")
	vnear(o.heading, m.heading, 0, "its heading")
	near(o.gaze.Magnitude, 1, 1e-9, "the gaze is a unit vector")
	near(o.heading:Dot(o.up), 0, 1e-9, "the heading lies on the support plane")
	m:destroy()
end)

case("eyes: on a wall and an underside the eyes follow the body's up and facing", function()
	local m = newMotor()
	m:place(Vector3.new(10, 5, 10), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)) -- a wall facing +x, walking up it
	vnear(m:eyePosition(), Vector3.new(10.08, 5.18, 10), 1e-9, "on a wall: ahead is up the wall and above is out from it")
	m:place(Vector3.new(10, 5, 10), Vector3.new(0, -1, 0), Vector3.new(0, 0, -1)) -- hanging under a ceiling
	vnear(m:eyePosition(), Vector3.new(10, 4.92, 9.82), 1e-9, "under a ceiling: the eyes are below the body centre")
	m.gazePitch = math.rad(30)
	local g = m:bodyGazeDirection()
	vnear(g, Vector3.new(0, -math.sin(math.rad(30)), -math.cos(math.rad(30))), 1e-9, "a pitch of 30 degrees tilts the gaze toward the body's up, which is down there")
	m:destroy()
end)

case("eyes: placing the spider levels the gaze", function()
	local m = newMotor()
	m.gazePitch = 0.5
	m:respawn()
	near(m.gazePitch, 0, 1e-12, "a teleport (Godot teleport_to) puts the gaze back level")
	m:destroy()
end)

-- =============================================================================================== Focus tilts the gaze

case("focus: the gaze tilts toward what the camera aims at, within the species' limit, at the focus rate", function()
	local m = newMotor()
	ticks(m, 3)
	near(m.gazePitch, 0, 1e-9, "the gaze starts level")
	local down = Vector3.new(0, -1, -1).Unit
	m:tick(input({ focusPoint = pointAlong(m, down) }))
	near(DEG(m.gazePitch), -3.0, 1e-6, "one tick of Focus tilts it 3 degrees (180 degrees a second)")
	check(m:isFocusing(), "Focus is on")
	m:tick(input({ focusPoint = pointAlong(m, down) }))
	near(DEG(m.gazePitch), -6.0, 1e-6, "and 3 more")
	for _ = 1, 60 do
		m:tick(input({ focusPoint = pointAlong(m, down) }))
	end
	near(DEG(m.gazePitch), -35.0, 0.01, "looking steeply down it stops at the limit")
	check(m:gazeDirection().Y < -0.5, "and the cone's axis points down")
	near(m:gazeDirection().Y, -math.sin(math.rad(35)), 1e-3, "at that angle")
	m:tick(input())
	near(DEG(m.gazePitch), -33.5, 1e-6, "released, it comes back at half the rate: 1.5 degrees a tick")
	check(not m:isFocusing(), "Focus is off")
	ticks(m, 90)
	near(m.gazePitch, 0, 1e-9, "and in time the gaze is level again")
	m:destroy()
end)

case("focus: looking up tilts the gaze up, and a level look keeps it level", function()
	local m = newMotor()
	ticks(m, 3)
	for _ = 1, 40 do
		m:tick(input({ focusPoint = pointAlong(m, Vector3.new(0, 1, -1)) }))
	end
	near(DEG(m.gazePitch), 35.0, 0.01, "looking up it stops at the limit the other way")
	check(m:gazeDirection().Y > 0.5, "and the cone's axis points up")
	local m2 = newMotor()
	ticks(m2, 3)
	for _ = 1, 40 do
		m2:tick(input({ focusPoint = pointAlong(m2, m2.heading) }))
	end
	near(m2.gazePitch, 0, 1e-6, "aiming along the support plane keeps the gaze level")
	-- A modest look tilts exactly as far as it looks: 20 degrees below the horizon.
	local m3 = newMotor()
	ticks(m3, 3)
	for _ = 1, 30 do
		m3:tick(input({ focusPoint = pointAlong(m3, lookAt(m3, 0, 20)) }))
	end
	near(DEG(m3.gazePitch), -20.0, 0.05, "20 degrees below the horizon is 20 degrees of tilt")
	m:destroy()
	m2:destroy()
	m3:destroy()
end)

case("focus: the limit is the species' gaze_pitch_limit_deg when it has one, 35 degrees when it has none", function()
	local short = table.clone(Species.phidippus_audax_prototype)
	short.perception = { gaze_pitch_limit_deg = 20.0 }
	local m = newMotor(short)
	ticks(m, 3)
	for _ = 1, 40 do
		m:tick(input({ focusPoint = pointAlong(m, Vector3.new(0, -1, -1)) }))
	end
	near(DEG(m.gazePitch), -20.0, 0.01, "a profile that says 20 degrees stops there")
	local bare = table.clone(Species.phidippus_audax_prototype)
	bare.perception = nil
	local m2 = newMotor(bare)
	ticks(m2, 3)
	for _ = 1, 40 do
		m2:tick(input({ focusPoint = pointAlong(m2, Vector3.new(0, -1, -1)) }))
	end
	near(DEG(m2.gazePitch), -35.0, 0.01, "a profile with no perception section falls back to 35 degrees")
	local real = newMotor()
	near(DEG(real.gazeLimit), Species.phidippus_audax_prototype.perception.gaze_pitch_limit_deg, 1e-9, "the shipped profile's number is used")
	m:destroy()
	m2:destroy()
	real:destroy()
end)

case("focus: a point within 0.2 WU of the eyes aims along the ray, as Godot does", function()
	local m = newMotor()
	ticks(m, 3)
	for _ = 1, 20 do
		m:tick(input({ focusPoint = m:eyePosition() + Vector3.new(0, 0, 0.05), focusDir = Vector3.new(0, -1, -1).Unit }))
	end
	near(DEG(m.gazePitch), -35.0, 0.01, "the ray's direction decides")
	local m2 = newMotor()
	ticks(m2, 3)
	for _ = 1, 20 do
		m2:tick(input({ focusPoint = m2:eyePosition() + Vector3.new(0, 0, 0.05) }))
	end
	near(m2.gazePitch, 0, 1e-9, "with no ray to go by it stays level")
	m:destroy()
	m2:destroy()
end)

case("focus: off a surface the gaze settles level whatever Focus asks", function()
	local m = newMotor()
	ticks(m, 3)
	for _ = 1, 20 do
		m:tick(input({ focusPoint = pointAlong(m, Vector3.new(0, -1, -1)) }))
	end
	near(DEG(m.gazePitch), -35.0, 0.01, "tilted down on the floor")
	m:place(Vector3.new(Layout.SPAWN.X, Layout.SPAWN.Y + 4, Layout.SPAWN.Z), Vector3.yAxis, Layout.SPAWN_HEADING)
	m.gazePitch = math.rad(-35)
	m.mode = "air" -- falling: Focus cannot turn or tilt a spider that is not on a surface
	local before = m.gazePitch
	m:tick(input({ focusPoint = pointAlong(m, Vector3.new(0, -1, -1)) }))
	near(DEG(m.gazePitch - before), 1.5, 1e-6, "in the air it settles toward level at half the rate, 1.5 degrees a tick")
	check(not m:isFocusing() or m.mode == "air", "the body is not on a surface")
	m:destroy()
end)

-- =============================================================================================== the spider-eye view

case("eye view: the retinas point the inspection without turning the body within their reach", function()
	local m = newMotor()
	ticks(m, 3)
	local heading0 = m.heading
	local gaze20 = lookAt(m, 20, 0)
	ticks(m, 30, { gaze = gaze20 })
	check(angleDeg(m.heading, heading0) < 0.5, "20 degrees aside: the body did not turn")
	check(not m.eyeTurning, "nor began to")
	vnear(m:gazeDirection(), gaze20, 1e-9, "the inspection points where the eyes look")
	near(angleDeg(m:gazeDirection(), m:bodyGazeDirection()), 20, 1e-6, "20 degrees off the body's own gaze")
	vnear(m:scanDirection() :: Vector3, gaze20, 1e-9, "the scan direction is the view's")
	m:tick(input())
	check(m:scanDirection() == nil, "off: the retinas are centred again")
	vnear(m:gazeDirection(), m:bodyGazeDirection(), 1e-12, "and the cone is the body's")
	m:destroy()
end)

case("eye view: beyond the retinas' reach the cone is held at 30 degrees while the body turns to face the gaze", function()
	local m = newMotor()
	ticks(m, 3)
	local gaze = lookAt(m, 70, 0)
	m:tick(input({ gaze = gaze }))
	check(m.eyeTurning, "70 degrees aside, standing still: the body turns to face it")
	check(m:isFocusing(), "which is Focus")
	local away = angleDeg(m:gazeDirection(), m:bodyGazeDirection())
	check(away <= Motor.PRINCIPAL_SCAN_DEG + 0.001, `meanwhile the retinas point no further than they can ({away} degrees)`)
	near(away, 30, 0.2, "they point as far as they can")
	check(angleDeg(m:gazeDirection(), gaze) < 70, "toward the view")
	for i = 1, 200 do
		m:tick(input({ gaze = gaze }))
		local off = angleDeg(m:gazeDirection(), m:bodyGazeDirection())
		if off > Motor.PRINCIPAL_SCAN_DEG + 0.001 then
			check(false, `tick {i}: the cone left the retinas' reach ({off})`)
			break
		end
		if not m.eyeTurning then
			break
		end
	end
	check(not m.eyeTurning, "the turn ended")
	local flat = SupportMath.tangentDir(gaze, m.up)
	check(angleDeg(m.heading, flat) < 4.5, "it turned to face the gaze, then stopped")
	vnear(m:gazeDirection(), gaze, 1e-9, "and now the cone is the view's")
	m:destroy()
end)

case("eye view: the head tilts toward the gaze, at half the rate (full while the body turns to it)", function()
	local m = newMotor()
	ticks(m, 3)
	local gaze = lookAt(m, 0, 45)
	m:tick(input({ gaze = gaze }))
	near(DEG(m.gazePitch), -1.5, 1e-6, "looking down ahead: 1.5 degrees a tick, half the Focus rate")
	check(not m:isFocusing(), "that is not Focus")
	ticks(m, 59, { gaze = gaze })
	check(DEG(m.gazePitch) < -20, `the head tilted down toward where the eyes look ({DEG(m.gazePitch)} degrees)`)
	near(DEG(m.gazePitch), -35, 0.01, "as far as the species allows")
	check(angleDeg(m:gazeDirection(), gaze) < 1e-6, "so the floor ahead is within the principal eyes' reach")
	m:tick(input())
	near(DEG(m.gazePitch), -33.5, 1e-6, "off, it settles back at half the rate")
	-- Down and far aside, standing still: the body turns to the gaze, and the head follows at the full rate.
	local m2 = newMotor()
	ticks(m2, 3)
	local aside = lookAt(m2, 70, 40)
	m2:tick(input({ gaze = aside }))
	check(m2.eyeTurning, "the body turns to a gaze 70 degrees aside")
	near(DEG(m2.gazePitch), -3.0, 1e-6, "while it does the head tilts at the Focus rate")
	m:destroy()
	m2:destroy()
end)

case("eye view: walking never turns the body to the gaze and the head still tilts", function()
	local m = newMotor()
	ticks(m, 3)
	local gaze = lookAt(m, 80, 0)
	local wish = SupportMath.tangentDir(m.heading:Cross(m.up), m.up) * -1
	local heading0 = m.heading
	ticks(m, 5, { gaze = gaze, wish = wish })
	check(not m.eyeTurning, "while walking the body is not turned to the gaze")
	check(m.moving, "it walks")
	check(angleDeg(m.heading, heading0) > 1, "it turns to walk where the stick says")
	m:destroy()
end)

-- =============================================================================================== the camera is not the eyes

case("camera: the camera going round never moves the cone", function()
	local m = newMotor()
	local camera = Instance.new("Camera")
	camera.Parent = sill
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { sill }
	local drawnUp = Vector3.yAxis
	local cam = SpiderCamera.new(camera, params, function()
		drawnUp = drawnUp:Lerp(m.up, 0.33).Unit
		return { pos = m.pos, drawnUp = drawnUp, heading = m.heading, onLine = m:onLine(), rest = m:lineRestPoint(), lip = m:lineLip() }
	end, function(_on: boolean) end)
	cam.mouse = false
	ticks(m, 5)
	local o0 = m:observer()
	local worst = 0
	for i = 1, 180 do
		cam:look(3.0, 0.4 * math.sin(i * 0.1)) -- a full turn of the camera round the spider, and half a turn more
		m:tick(input())
		cam:tick(DT)
		cam:render(DT, 0, 0)
		local o = m:observer()
		worst = math.max(worst, (o.gaze - o0.gaze).Magnitude, (o.heading - o0.heading).Magnitude, (o.eye - o0.eye).Magnitude, (o.up - o0.up).Magnitude)
	end
	near(worst, 0, 1e-9, "the gaze, heading, eyes and up never moved while the camera went round")
	check(not m:isFocusing(), "Focus was never on")
	m:destroy()
	camera:Destroy()
end)

print(`GAZE passed={passed} failed={failed}`)
if failed > 0 then error("gaze checks failed") end
