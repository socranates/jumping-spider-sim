--!strict
-- Pure camera and stick math, ported from the frozen Godot reference (c87ce00):
--   scripts/movement/boom_math.gd    (orbit basis, boom recovery, eased offsets, pitch pick)
--   scripts/movement/surface_input.gd (camera-relative walking on floors, walls and undersides)
--   scripts/movement/camera_rig.gd   (aim free-look clamp, spider-eye gaze clamp, recenter yaw)
-- Vector3 only, no Instances, so tests/run.luau checks it against values exported from Godot itself.
-- Conventions match Godot and Roblox alike: right-handed, -Z forward, yaw about world up,
-- elevation positive puts the camera above the pivot.

local CameraMath = {}

CameraMath.PIVOT_HEIGHT = 0.45
CameraMath.BOOM_RADIUS = 0.15
CameraMath.DEFAULT_ELEVATION_DEG = 18.0
CameraMath.MIN_ELEVATION_DEG = -20.0
CameraMath.MAX_ELEVATION_DEG = 80.0
CameraMath.MOUSE_DEG_PER_PIXEL = 0.1
CameraMath.STICK_DEG_PER_SECOND = 150.0
CameraMath.RECOVER_SPEED = 6.0
CameraMath.RECENTER_SECONDS = 0.25
CameraMath.BODY_HIDE_LENGTH = 0.8
CameraMath.COMFORT_BOOM = 2.5
CameraMath.AUTO_PITCH_STEP_DEG = 10.0
CameraMath.MIN_AUTO_ELEVATION_DEG = -45.0
CameraMath.AUTO_PITCH_IN_SECONDS = 0.08
CameraMath.AUTO_PITCH_OUT_SECONDS = 0.35
CameraMath.AIM_PITCH_MIN_DEG = -20.0
CameraMath.AIM_PITCH_MAX_DEG = 50.0
CameraMath.AIM_VIEW_LIMIT_DEG = 85.0
CameraMath.AIM_RETURN_SECONDS = 0.25
CameraMath.EYE_FOV_DEG = 80.0
CameraMath.EYE_AHEAD = 0.53
CameraMath.EYE_HEIGHT = 0.09
CameraMath.EYE_PITCH_LIMIT_DEG = 80.0
CameraMath.EYE_ROLL_DEG_S = 240.0
CameraMath.PRINCIPAL_SCAN_DEG = 30.0
CameraMath.EYE_SETTLE_DEG = 4.0
CameraMath.FOV_DEG = 65.0
CameraMath.CAMERA_DISTANCE = 5.0

local SETTLE = 2e-4
local TIE = 1e-3
local FLOOR_BLEND_START = 0.5
local FLOOR_BLEND_END = 0.8660254

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function smoothstep(a: number, b: number, x: number): number
	if a == b then
		return if x < a then 0 else 1
	end
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
CameraMath.smoothstep = smoothstep

local function dirOn(v: Vector3, n: Vector3): Vector3
	local t = v - n * v:Dot(n)
	local length = t.Magnitude
	return if length > 1e-6 then t / length else Vector3.new(0, 0, 0)
end

-- BoomMath.next_length: a shorter allowed length is taken at once; growth is rate limited.
function CameraMath.nextLength(current: number, allowed: number, desired: number, recoverSpeed: number, dt: number): number
	if not (finite(current) and finite(allowed) and finite(desired) and finite(recoverSpeed) and finite(dt)) then
		return 0
	end
	local target = math.max(0, math.min(allowed, desired))
	if target <= current then
		return target
	end
	return math.min(current + math.max(recoverSpeed, 0) * math.max(dt, 0), target)
end

-- BoomMath.ease_offset: exponential ease, faster away from zero than back toward it.
function CameraMath.easeOffset(current: number, target: number, dt: number, inSeconds: number, outSeconds: number): number
	if not (finite(current) and finite(target) and finite(dt) and finite(inSeconds) and finite(outSeconds)) then
		return 0
	end
	local seconds = math.max(if math.abs(target) >= math.abs(current) then inSeconds else outSeconds, 1e-4)
	local nextValue = current + (target - current) * (1 - math.exp(-math.max(dt, 0) / seconds))
	return if math.abs(target - nextValue) < SETTLE then target else nextValue
end

-- BoomMath.pick_pitch_offset: the first comfortable boom, else the longest.
function CameraMath.pickPitchOffset(offsets: { number }, lengths: { number }, comfort: number): number
	if #offsets == 0 or #offsets ~= #lengths or not finite(comfort) then
		return 0
	end
	local best = 1
	for i = 1, #offsets do
		if lengths[i] >= comfort then
			return offsets[i]
		end
		if lengths[i] > lengths[best] + TIE then
			best = i
		end
	end
	return offsets[best]
end

-- BoomMath.back_direction: unit vector from the pivot toward the camera.
function CameraMath.backDirection(yaw: number, elevation: number): Vector3
	local ce = math.cos(elevation)
	return Vector3.new(math.sin(yaw) * ce, math.sin(elevation), math.cos(yaw) * ce)
end

-- The orbit camera's right and up vectors (SurfaceInput.camera_basis x and y columns).
function CameraMath.cameraRight(yaw: number, _elevation: number): Vector3
	return Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
end
function CameraMath.cameraUp(yaw: number, elevation: number): Vector3
	local se = math.sin(elevation)
	return Vector3.new(-se * math.sin(yaw), math.cos(elevation), -se * math.cos(yaw))
end

-- SurfaceInput.tangent_axes: camera-relative right and forward on the plane with normal n.
function CameraMath.tangentAxes(yaw: number, elevation: number, n: Vector3): (Vector3, Vector3)
	local normal = if n.Magnitude > 1e-5 then n.Unit else Vector3.new(0, 1, 0)
	local camRight = CameraMath.cameraRight(yaw, elevation)
	local camUp = CameraMath.cameraUp(yaw, elevation)
	local flatForward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local pf = dirOn(flatForward, normal)
	local pu = dirOn(camUp, normal)
	local w = smoothstep(FLOOR_BLEND_START, FLOOR_BLEND_END, math.abs(normal.Y))
	local forward = pf * w + pu * (1 - w)
	if forward:Dot(forward) < 1e-6 then
		local pr = dirOn(camRight, normal)
		if pr.Magnitude == 0 then
			pr = dirOn(Vector3.new(1, 0, 0), normal)
		end
		forward = normal:Cross(pr)
	end
	forward = dirOn(forward, normal)
	local right = forward:Cross(normal)
	right = if right.Magnitude > 1e-9 then right.Unit else right
	if right:Dot(camRight) < 0 then
		right = -right
	end
	return right, forward
end

-- SurfaceInput.map_stick: x right, y forward, length kept (at most 1).
function CameraMath.mapStick(x: number, y: number, yaw: number, elevation: number, n: Vector3): Vector3
	local length = math.sqrt(x * x + y * y)
	if not finite(length) or length < 1e-6 then
		return Vector3.new(0, 0, 0)
	end
	if length > 1 then
		x, y = x / length, y / length
	end
	local right, forward = CameraMath.tangentAxes(yaw, elevation, n)
	return right * x + forward * y
end

-- Spider-eye walking: forward is the gaze laid on the surface, right is its right on it.
function CameraMath.mapStickEye(x: number, y: number, gaze: Vector3, bodyForward: Vector3, n: Vector3): Vector3
	local length = math.sqrt(x * x + y * y)
	if not finite(length) or length < 1e-6 then
		return Vector3.new(0, 0, 0)
	end
	if length > 1 then
		x, y = x / length, y / length
	end
	local forward = gaze - n * gaze:Dot(n)
	if forward:Dot(forward) < 1e-6 then
		forward = bodyForward - n * bodyForward:Dot(n)
	end
	if forward:Dot(forward) < 1e-6 then
		return Vector3.new(0, 0, 0)
	end
	forward = forward.Unit
	local right = forward:Cross(n).Unit
	return right * x + forward * y
end

-- camera_rig._clamp_aim_pitch: the aim free-look range, and the whole view short of straight up or down.
function CameraMath.clampAimPitch(value: number, elevation: number): number
	local limit = math.rad(CameraMath.AIM_VIEW_LIMIT_DEG)
	local low = math.max(math.rad(CameraMath.AIM_PITCH_MIN_DEG), elevation - limit)
	local high = math.min(math.rad(CameraMath.AIM_PITCH_MAX_DEG), elevation + limit)
	return math.clamp(value, low, math.max(low, high))
end

-- camera_rig._effective_elevation: the player's pitch plus the auto-pitch, inside the automatic range.
function CameraMath.effectiveElevation(elevation: number, offset: number): number
	local low = math.min(elevation, math.rad(CameraMath.MIN_AUTO_ELEVATION_DEG))
	local high = math.max(elevation, math.rad(CameraMath.MAX_ELEVATION_DEG))
	return math.clamp(elevation + offset, low, high)
end

-- The yaw whose flat forward (-sin, 0, -cos) points along v.
function CameraMath.yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

-- SpiderMotor.get_recenter_yaw: behind the heading on floors and undersides, toward the surface on walls.
function CameraMath.recenterYaw(heading: Vector3, visualUp: Vector3, fallback: number): number
	local w = visualUp.Y * visualUp.Y
	local v = Vector3.new(heading.X, 0, heading.Z) * w + Vector3.new(-visualUp.X, 0, -visualUp.Z) * (1 - w)
	if v.Magnitude < 1e-3 then
		return fallback
	end
	return math.atan2(-v.X, -v.Z)
end

local function anyPerpendicular(v: Vector3): Vector3
	local other = if math.abs(v.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	return v:Cross(other).Unit
end

-- camera_rig._clamp_gaze: unit, and at least EYE_PITCH_LIMIT_DEG from the surface normal either way.
function CameraMath.clampGaze(g: Vector3, up: Vector3, bodyForward: Vector3): Vector3
	if not (finite(g.X) and finite(g.Y) and finite(g.Z)) or g:Dot(g) < 1e-10 then
		g = bodyForward
	end
	g = g.Unit
	local tangent = g - up * g:Dot(up)
	if tangent:Dot(tangent) < 1e-8 then
		tangent = bodyForward - up * bodyForward:Dot(up)
		if tangent:Dot(tangent) < 1e-8 then
			tangent = anyPerpendicular(up)
		end
	end
	tangent = tangent.Unit
	local limit = math.rad(CameraMath.EYE_PITCH_LIMIT_DEG)
	local elev = math.clamp(math.asin(math.clamp(g:Dot(up), -1, 1)), -limit, limit)
	return (tangent * math.cos(elev) + up * math.sin(elev)).Unit
end

-- Rodrigues rotation of v about unit axis k by angle a (right-handed).
function CameraMath.rotate(v: Vector3, k: Vector3, a: number): Vector3
	local c, s = math.cos(a), math.sin(a)
	return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c))
end

-- camera_rig._look_eye (no level-horizon switch): yaw about the view's up (positive looks right),
-- pitch about the view's right (positive looks down).
function CameraMath.lookEye(gaze: Vector3, up: Vector3, yawRad: number, pitchRad: number, bodyForward: Vector3): Vector3
	local g = CameraMath.rotate(gaze, up, -yawRad)
	local right = g:Cross(up)
	if right:Dot(right) > 1e-10 then
		g = CameraMath.rotate(g, right.Unit, -pitchRad)
	end
	return CameraMath.clampGaze(g, up, bodyForward)
end

return CameraMath
