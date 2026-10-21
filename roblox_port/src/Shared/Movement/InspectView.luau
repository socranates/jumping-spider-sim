--!strict
-- Inspect mode's view, as numbers (ROBLOX-90): an orbit of the spider by yaw, elevation and distance in body-lengths, the auto-orbit when the player is
-- idle, the zoom (wheel, stick, pinch), the three preset framings and the 0.8 s ease. Pure, so tests/inspect.luau checks the numbers without Roblox; Client/SpiderCamera turns a
-- state into a camera (it adds the spider's position, up, heading and drawn length, and casts the boom against the sill).
--
-- Yaw is measured round the spider's own up, from its forward direction: 0 is the camera in front of the spider (the face), 90 on its right,
-- 180 behind it, 270 on its left. A look to the right (dx > 0) moves the camera toward the spider's right, as the game's own orbit does,
-- and a look down (dy > 0) lifts it, so the inversion settings mean what they always have.
local InspectView = {}

InspectView.HOLD_SECONDS = 0.6 -- holding the choose key or button this long (while resting awake in the crack) starts the view
InspectView.EASE_SECONDS = 0.8 -- into the view, and back out of it (the mating two-shot's own)
InspectView.DISTANCE = 1.6 -- body-lengths from the spider where the view begins
InspectView.ELEVATION_DEG = 20 -- ... and how far above the surface's plane ("slightly above")
InspectView.AUTO_DEG_S = 10 -- the slow orbit, when the player is idle
InspectView.AUTO_AFTER_SECONDS = 3 -- ... which is to say, once this long has gone by without a turn or a zoom (a new view counts as idle, so it begins at once)
InspectView.ZOOM_MIN, InspectView.ZOOM_MAX = 1.1, 3.0 -- body-lengths
InspectView.ZOOM_PER_SECOND = 1.0 -- body-lengths a second at a full push of the left stick (or W and S)
InspectView.WHEEL_STEP = 0.88 -- one notch of the wheel is this share of the distance (the third-person camera's own)
InspectView.ELEVATION_MIN_DEG, InspectView.ELEVATION_MAX_DEG = 4, 88
InspectView.PRESET_EASE_SECONDS = 0.35 -- a preset framing is reached in about this long (an exponential approach, 95 percent of the way)

-- The three preset framings, in the order the button cycles them: the face (in front, a little above, close, on the head), the side (on the
-- right, low, the whole body) and from above (the top of the body, the head up the screen). `ahead` is how far in front of the body's middle the
-- focus is, in body-lengths; every distance is within the zoom's range.
InspectView.PRESETS = {
	{ id = "face", yawDeg = 0, elevDeg = 10, distance = 1.25, ahead = 0.3 },
	{ id = "side", yawDeg = 90, elevDeg = 6, distance = 1.8, ahead = 0 },
	{ id = "top", yawDeg = 180, elevDeg = 84, distance = 2.0, ahead = 0 },
} :: { { id: string, yawDeg: number, elevDeg: number, distance: number, ahead: number } }

export type Goal = { yaw: number, elev: number, dist: number, ahead: number }
export type State = {
	yaw: number, elev: number, dist: number, ahead: number, -- degrees, degrees, body-lengths, body-lengths
	auto: boolean, -- the slow orbit may run (a framing held still, or the player's own view, switches it off until the player turns the view)
	idle: number, -- seconds since the player last turned, zoomed or pinched the view (the auto-orbit runs once this is AUTO_AFTER_SECONDS)
	preset: number, -- 0 or the index of the preset last chosen
	goal: Goal?, -- a preset still being reached
}

local function wrap(deg: number): number
	return (deg + 180) % 360 - 180
end

-- A view at this yaw: 1.6 body-lengths away, 20 degrees up, orbiting slowly (nobody has touched it yet).
function InspectView.new(yawDeg: number): State
	return { yaw = wrap(yawDeg), elev = InspectView.ELEVATION_DEG, dist = InspectView.DISTANCE, ahead = 0, auto = true, idle = InspectView.AUTO_AFTER_SECONDS, preset = 0, goal = nil }
end

-- The yaw (degrees) of a camera at `offset` from the focus, for a spider whose forward and right are given (any length, in its plane).
function InspectView.yawOf(offset: Vector3, forward: Vector3, right: Vector3): number
	return math.deg(math.atan2(offset:Dot(right), offset:Dot(forward)))
end

-- The player's own turn of the view, in degrees (dx right, dy down): the auto-orbit waits AUTO_AFTER_SECONDS after the last of it (and is allowed again if a framing
-- had stopped it), and a preset on its way is cancelled.
function InspectView.orbit(s: State, dxDeg: number, dyDeg: number)
	if dxDeg == 0 and dyDeg == 0 then return end
	s.auto, s.idle, s.goal = true, 0, nil
	s.yaw = wrap(s.yaw + dxDeg)
	s.elev = math.clamp(s.elev + dyDeg, InspectView.ELEVATION_MIN_DEG, InspectView.ELEVATION_MAX_DEG)
end

local function clampZoom(d: number): number
	return math.clamp(d, InspectView.ZOOM_MIN, InspectView.ZOOM_MAX)
end

-- A step of the distance in body-lengths (negative: closer). The player is not idle while zooming, so the auto-orbit waits, but a framing's hold is not lifted.
function InspectView.zoomBy(s: State, delta: number)
	if delta == 0 then return end
	s.goal, s.idle = nil, 0
	s.dist = clampZoom(s.dist + delta)
end

-- One notch of the wheel: `up` is a wheel turned away from the player (closer).
function InspectView.wheel(s: State, up: boolean)
	s.goal, s.idle = nil, 0
	s.dist = clampZoom(s.dist * (if up then InspectView.WHEEL_STEP else 1 / InspectView.WHEEL_STEP))
end

-- A pinch on a touch screen: `ratio` is how much further apart the two fingers are than a moment ago (above 1: spread, so closer; below 1: pinched, so further).
function InspectView.pinch(s: State, ratio: number)
	if not (ratio > 0) or ratio == math.huge or ratio == 1 then return end
	s.goal, s.idle = nil, 0
	s.dist = clampZoom(s.dist / ratio)
end

-- The button: the next preset framing (face, side, top, face ...). The auto-orbit stops (a framing is held still until the player turns the view), and the view goes there. Returns its id.
function InspectView.cycle(s: State): string
	s.preset = s.preset % #InspectView.PRESETS + 1
	local p = InspectView.PRESETS[s.preset]
	s.auto, s.idle = false, 0
	s.goal = { yaw = p.yawDeg, elev = p.elevDeg, dist = p.distance, ahead = p.ahead }
	return p.id
end

function InspectView.presetId(s: State): string?
	local p = InspectView.PRESETS[s.preset]
	return if p then p.id else nil
end

-- One frame: the auto-orbit, or a preset being reached. Reduced motion: no auto-orbit, and a preset is a cut.
function InspectView.step(s: State, dt: number, reduced: boolean)
	local g = s.goal
	if g ~= nil then
		if reduced then
			s.yaw, s.elev, s.dist, s.ahead, s.goal = wrap(g.yaw), g.elev, g.dist, g.ahead, nil
			return
		end
		-- 95 percent of the way in PRESET_EASE_SECONDS: exp(-k * seconds) = 0.05
		local k = 1 - math.exp(-3 * math.max(dt, 0) / InspectView.PRESET_EASE_SECONDS)
		local dyaw = wrap(g.yaw - s.yaw)
		s.yaw = wrap(s.yaw + dyaw * k)
		s.elev += (g.elev - s.elev) * k
		s.dist += (g.dist - s.dist) * k
		s.ahead += (g.ahead - s.ahead) * k
		if math.abs(dyaw) < 0.05 and math.abs(g.elev - s.elev) < 0.05 and math.abs(g.dist - s.dist) < 0.002 and math.abs(g.ahead - s.ahead) < 0.002 then
			s.yaw, s.elev, s.dist, s.ahead, s.goal = wrap(g.yaw), g.elev, g.dist, g.ahead, nil
		end
	elseif s.auto and not reduced then
		s.idle += math.max(dt, 0)
		if s.idle >= InspectView.AUTO_AFTER_SECONDS then
			s.yaw = wrap(s.yaw + InspectView.AUTO_DEG_S * math.max(dt, 0))
		end
	end
end

-- The unit vector from the focus to the camera, for the spider's forward, right and up (unit vectors; right = forward x up).
function InspectView.direction(s: State, forward: Vector3, right: Vector3, up: Vector3): Vector3
	local yaw, elev = math.rad(s.yaw), math.rad(s.elev)
	return (forward * math.cos(yaw) * math.cos(elev) + right * math.sin(yaw) * math.cos(elev) + up * math.sin(elev)).Unit
end

-- The ease between the player's own camera and this view, 0 to 1: it moves toward 1 while the view is wanted and toward 0 when it is not,
-- in EASE_SECONDS (0.8 s) from end to end. Reduced motion is a cut.
function InspectView.ease(t: number, dt: number, wanted: boolean, reduced: boolean): number
	if reduced then return if wanted then 1 else 0 end
	local step = math.max(dt, 0) / InspectView.EASE_SECONDS
	local want = if wanted then 1 else 0
	return math.clamp(t + math.clamp(want - t, -step, step), 0, 1)
end

function InspectView.smooth(k: number): number
	return k * k * (3 - 2 * k)
end

return InspectView
