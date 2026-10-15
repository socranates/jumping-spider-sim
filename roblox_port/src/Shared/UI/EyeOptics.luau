--!strict
-- EyeOptics: the pure half of the spider-eye picture (ROBLOX-20). From k (how much the principal eyes are in use, 0 to 1) and the
-- time it works out the field of view, the colour grade, the blur and the depth of field, where the two retina strips are and how
-- they swing, how big a movement ring is and where an edge arc goes, the vignette's strength, the caption's fade and the UV layer's
-- transparency. Client/SpiderEyes draws what this says; nothing here touches the engine, so tests/eyes.luau checks every rule. The
-- numbers, and what they rest on, are in Shared/Data/Eyes. Angles are degrees, sizes pixels, times seconds. Screen y runs down.
local Eyes = require(script.Parent.Parent.Data.Eyes)

local EyeOptics = {}

-- What the picture looks like at one k (see EyeOptics.profile).
export type Profile = {
	k: number,
	fovDeg: number, -- vertical
	saturation: number,
	tint: Color3,
	contrast: number,
	brightness: number,
	blur: number, -- BlurEffect.Size
	dofFar: number,
	dofNear: number,
	dofRadius: number, -- InFocusRadius, studs
	strokeTransparency: number, -- of the retina strips
	fillTransparency: number,
	sweepDeg: number, -- how far each strip swings side to side
	torsionDeg: number, -- and how far it turns about its middle
	vignette: number, -- opacity at the screen's edge
}
-- A retina strip as a rounded box on the screen: its middle, its size and its turn (clockwise, as GuiObject.Rotation).
export type Strip = { x: number, y: number, w: number, h: number, rotation: number }
-- A thing the lateral eyes saw moving (a Sensor.motionSeen entry with the id it is filed under).
export type Moving = { direction: Vector3, distance: number, apparent: number, tick: number }
export type Mover = { id: string, direction: Vector3, distance: number, apparent: number, tick: number }
-- One short bar of an edge arc.
export type Segment = { x: number, y: number, rotation: number }

-- a(1 - t) + bt, not a + (b - a)t: exactly a at 0 and exactly b at 1 (the looks at k = 0 and k = 1 are the spec's numbers to the digit).
local function lerp(a: number, b: number, t: number): number
	return a * (1 - t) + b * t
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-- Smoothstep.
function EyeOptics.smooth(x: number): number
	local t = clamp01(x)
	return t * t * (3 - 2 * t)
end

-- ---------------------------------------------------------------- how much the principal eyes are in use
-- One step of the engagement clock. `phase` runs 0 to 1 in Eyes.timing.engageSeconds while the principal eyes are wanted (Focus
-- held, or toggled on) and back in releaseSeconds otherwise. It is linear in time, so every frame rate gives the same phase after
-- the same time; a change of mind part-way simply turns it round.
function EyeOptics.stepPhase(phase: number, wanted: boolean, dt: number): number
	local T = Eyes.timing
	local step = math.max(dt, 0)
	return clamp01(phase + (if wanted then step / T.engageSeconds else -step / T.releaseSeconds))
end

-- k: the phase, eased, so the picture starts and settles gently.
function EyeOptics.engagement(phase: number): number
	return EyeOptics.smooth(phase)
end

-- ---------------------------------------------------------------- the field of view and the look
-- The principal eyes' vertical field: 24 degrees, or no narrower than 45 with reduced motion.
function EyeOptics.principalFovDeg(reduced: boolean): number
	if reduced then
		return math.max(Eyes.principal.fovDeg, Eyes.reducedMotion.minFovDeg)
	end
	return Eyes.principal.fovDeg
end

-- The vertical field at k, blended in tangent space (the half-angle's tangent is the screen's half-height at unit distance), so
-- the zoom looks even instead of rushing at the end. Exactly the side eyes' at 0 and the principal eyes' at 1.
function EyeOptics.fovDeg(k: number, reduced: boolean): number
	local far, near = Eyes.side.fovDeg, EyeOptics.principalFovDeg(reduced)
	if k <= 0 then
		return far
	elseif k >= 1 then
		return near
	end
	return math.deg(2 * math.atan(lerp(math.tan(math.rad(far) / 2), math.tan(math.rad(near) / 2), k)))
end

-- How much of the player's look a turn of the view gets at this field of view, so the picture moves as fast across the screen
-- whatever the zoom: tan(fov / 2) against the side eyes' tan(90 / 2) = 1.
function EyeOptics.lookScale(fovDeg: number): number
	return math.tan(math.rad(fovDeg) / 2) / math.tan(math.rad(Eyes.side.fovDeg) / 2)
end

local function mix3(a: { number }, b: { number }, k: number): Color3
	return Color3.new(lerp(a[1], b[1], k) / 255, lerp(a[2], b[2], k) / 255, lerp(a[3], b[3], k) / 255)
end

-- Everything that depends on k, blended: every number is the side eyes' at 0 and the principal eyes' at 1, the field of view in
-- tangent space. focusDistance (studs, what is looked at) sets how deep the sharp zone of the depth of field is.
function EyeOptics.profile(k: number, focusDistance: number, reduced: boolean): Profile
	local t = clamp01(k)
	local s, p = Eyes.side, Eyes.principal
	local distance = math.max(focusDistance, 0)
	local sideRadius = math.max(s.dofRadiusMin, s.dofRadiusPerStud * distance)
	local principalRadius = math.max(p.dofRadiusMin, p.dofRadiusPerStud * distance)
	return {
		k = t,
		fovDeg = EyeOptics.fovDeg(t, reduced),
		saturation = lerp(s.saturation, p.saturation, t),
		tint = mix3(s.tint, p.tint, t),
		contrast = lerp(s.contrast, p.contrast, t),
		brightness = lerp(s.brightness, p.brightness, t),
		blur = lerp(s.blur, p.blur, t),
		dofFar = lerp(s.dofFar, p.dofFar, t),
		dofNear = lerp(s.dofNear, p.dofNear, t),
		dofRadius = lerp(sideRadius, principalRadius, t),
		strokeTransparency = lerp(s.strokeTransparency, p.strokeTransparency, t),
		fillTransparency = lerp(s.fillTransparency, p.fillTransparency, t),
		sweepDeg = if reduced then 0 else lerp(s.sweepDeg, p.sweepDeg, t),
		torsionDeg = if reduced then 0 else lerp(s.torsionDeg, p.torsionDeg, t),
		vignette = lerp(s.vignette, p.vignette, t),
	}
end

-- ---------------------------------------------------------------- where the eyes are focused
-- The distance to focus on: how far the looked-along ray ran before it hit the world (nil when it hit nothing), at most the
-- limit.
function EyeOptics.focusTarget(hitDistance: number?): number
	local limit = Eyes.focus.maxDistance
	if hitDistance == nil then
		return limit
	end
	return math.min(hitDistance, limit)
end

-- One step of the focus racking from one distance to the next: an exponential approach with Eyes.focus.tauSeconds as its time
-- constant. Any frame rate gives the same distance after the same time.
function EyeOptics.focusStep(current: number, target: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-math.max(dt, 0) / Eyes.focus.tauSeconds))
end

-- ---------------------------------------------------------------- sizes on the screen
-- Pixels for one unit of tangent at this vertical field of view: the screen's half-height over tan(fov / 2).
function EyeOptics.pixelsPerTan(fovDeg: number, viewportH: number): number
	return viewportH * 0.5 / math.tan(math.rad(fovDeg) * 0.5)
end

-- How long, in pixels, something that spans `angleDeg` about the middle of the view looks: tangent-correct, so a 20 degree strip
-- at a 24 degree field is tan(10) / tan(12) of the screen's height. Square pixels, so it serves for width and height alike.
function EyeOptics.extentPx(angleDeg: number, fovDeg: number, viewportH: number): number
	return 2 * math.tan(math.rad(math.min(angleDeg, 170)) * 0.5) * EyeOptics.pixelsPerTan(fovDeg, viewportH)
end

-- How far from the middle of the screen, in pixels, a direction `angleDeg` off the view's axis lands.
function EyeOptics.offsetPx(angleDeg: number, fovDeg: number, viewportH: number): number
	return math.tan(math.rad(angleDeg)) * EyeOptics.pixelsPerTan(fovDeg, viewportH)
end

-- ---------------------------------------------------------------- the retinae
-- Strip `index` (1 the left one, 2 the right) at time t: how far it has swayed from its place and turned from its tilt, in
-- degrees. The second strip runs lagSeconds behind the first in both (the retinae do not move as one). The amplitudes come from
-- the profile (large with the side eyes, small tracking with the principal eyes, none with reduced motion).
function EyeOptics.scanPose(index: number, t: number, sweepDeg: number, torsionDeg: number): (number, number)
	local R = Eyes.retina
	local at = t - (index - 1) * R.lagSeconds
	return sweepDeg * math.sin(2 * math.pi * at / R.sweepSeconds), torsionDeg * math.sin(2 * math.pi * at / R.torsionSeconds)
end

-- The two strips as the player sees them, for a profile (its field of view and its swing), the time and the screen's size: each
-- at its true angular size (widthDeg x heightDeg), offsetDeg either side of the middle plus its sway, tilted tiltDeg into a V (the
-- left one leaning out to the left at the top) plus its turn.
function EyeOptics.retinaStrips(t: number, p: Profile, viewportW: number, viewportH: number): { Strip }
	local R = Eyes.retina
	local w = EyeOptics.extentPx(R.widthDeg, p.fovDeg, viewportH)
	local h = EyeOptics.extentPx(R.heightDeg, p.fovDeg, viewportH)
	local out: { Strip } = {}
	for i = 1, 2 do
		local side = if i == 1 then -1 else 1
		local sway, turn = EyeOptics.scanPose(i, t, p.sweepDeg, p.torsionDeg)
		out[i] = {
			x = viewportW * 0.5 + EyeOptics.offsetPx(side * R.offsetDeg + sway, p.fovDeg, viewportH),
			y = viewportH * 0.5,
			w = w,
			h = h,
			rotation = side * R.tiltDeg + turn,
		}
	end
	return out
end

-- True when the screen point lies inside the strip: the rounded box (a stadium, the strip being taller than wide), turned as it
-- is drawn.
function EyeOptics.insideStrip(px: number, py: number, s: Strip): boolean
	local dx, dy = px - s.x, py - s.y
	local a = math.rad(s.rotation)
	local c, sn = math.cos(a), math.sin(a)
	local lx, ly = dx * c + dy * sn, -dx * sn + dy * c
	local r = s.w * 0.5
	local reach = math.max(s.h * 0.5 - r, 0)
	local oy = ly - math.clamp(ly, -reach, reach)
	return lx * lx + oy * oy <= r * r
end

function EyeOptics.insideAnyStrip(px: number, py: number, strips: { Strip }): boolean
	for _, s in strips do
		if EyeOptics.insideStrip(px, py, s) then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- the lateral eyes' movement rings
-- 0 to 1 and back, Eyes.shimmer.hz times a second, from time t; a steady half with reduced motion.
function EyeOptics.pulse(t: number, reduced: boolean): number
	if reduced then
		return 0.5
	end
	return 0.5 - 0.5 * math.cos(2 * math.pi * Eyes.shimmer.hz * t)
end

-- A ring's diameter in pixels: the thing's apparent size (degrees across, as the sensor measured it) at this field of view, at
-- least minPx, times scaleMin to scaleMax as the pulse goes 0 to 1.
function EyeOptics.ringDiameter(apparentDeg: number, fovDeg: number, viewportH: number, pulse: number): number
	local S = Eyes.shimmer
	local base = math.max(S.minPx, EyeOptics.extentPx(apparentDeg, fovDeg, viewportH))
	return base * lerp(S.scaleMin, S.scaleMax, clamp01(pulse))
end

-- 1 when the thing was just seen moving, 0 when the sensor's hold (holdTicks, Sensor.MOTION_HOLD_TICKS) has run out.
function EyeOptics.freshness(nowTick: number, seenTick: number, holdTicks: number): number
	return 1 - clamp01((nowTick - seenTick) / math.max(holdTicks, 1))
end

-- A ring's opacity: the base alpha, as fresh as the sighting, a third of that (insideStripFactor) inside a retina strip.
function EyeOptics.ringAlpha(fresh: number, inside: boolean): number
	local S = Eyes.shimmer
	return S.alpha * clamp01(fresh) * (if inside then S.insideStripFactor else 1)
end

-- An edge arc's opacity: as fresh as the sighting, breathing a little with the pulse.
function EyeOptics.arcAlpha(fresh: number, pulse: number): number
	local A = Eyes.shimmer.arc
	return A.alpha * clamp01(fresh) * lerp(1 - A.breath, 1, clamp01(pulse))
end

-- The things to draw: the freshest first, at most maxCount, ties broken by id so the same record always gives the same list.
function EyeOptics.pickMovers(seen: { [string]: Moving }, maxCount: number): { Mover }
	local list: { Mover } = {}
	for id, e in seen do
		table.insert(list, { id = id, direction = e.direction, distance = e.distance, apparent = e.apparent, tick = e.tick })
	end
	table.sort(list, function(a: Mover, b: Mover): boolean
		if a.tick ~= b.tick then
			return a.tick > b.tick
		end
		return a.id < b.id
	end)
	while #list > maxCount do
		table.remove(list)
	end
	return list
end

-- True when a point (pixels) is inside the screen, give or take `margin`.
function EyeOptics.onScreen(x: number, y: number, viewportW: number, viewportH: number, margin: number): boolean
	return x >= -margin and x <= viewportW + margin and y >= -margin and y <= viewportH + margin
end

-- Where the screen's edge is in the direction of something off screen: (cx, cy) is its direction in the camera's own axes (x
-- right, y up). The same rule as the perception HUD's edge marks: a direction straight behind goes to the top, and the point is
-- `inset` pixels inside the edge. Returns the point's x and y and the unit direction (x, y; y down) from the screen's middle to it.
function EyeOptics.edgeMark(cx: number, cy: number, viewportW: number, viewportH: number, inset: number): (number, number, number, number)
	local vx, vy = cx, -cy
	local m = math.sqrt(vx * vx + vy * vy)
	if m < 0.03 then
		vx, vy, m = 0, -1, 1
	end
	vx, vy = vx / m, vy / m
	local hx, hy = viewportW * 0.5 - inset, viewportH * 0.5 - inset
	local t = math.min(hx / math.max(math.abs(vx), 1e-6), hy / math.max(math.abs(vy), 1e-6))
	return viewportW * 0.5 + vx * t, viewportH * 0.5 + vy * t, vx, vy
end

-- The short bars that make an edge arc: `segments` of them, stepDeg apart along a circle of `radius` pixels whose outermost point
-- is (x, y), where `d` (dx, dy) points out of the screen. Each bar's rotation lays it along the circle there.
function EyeOptics.arcSegments(x: number, y: number, dx: number, dy: number): { Segment }
	local A = Eyes.shimmer.arc
	local cx, cy = x - dx * A.radius, y - dy * A.radius
	local nx, ny = -dy, dx
	local out: { Segment } = {}
	local middle = (A.segments + 1) / 2
	for i = 1, A.segments do
		local phi = math.rad((i - middle) * A.stepDeg)
		local c, s = math.cos(phi), math.sin(phi)
		out[i] = {
			x = cx + A.radius * (c * dx + s * nx),
			y = cy + A.radius * (c * dy + s * ny),
			rotation = math.deg(math.atan2(-s * dy + c * ny, -s * dx + c * nx)),
		}
	end
	return out
end

-- ---------------------------------------------------------------- the words, the UV layer
-- The caption's opacity `age` seconds into the eye view: it fades in, holds and fades out, and is gone after Eyes.caption.seconds.
function EyeOptics.captionAlpha(age: number): number
	local C = Eyes.caption
	if age < 0 or age >= C.seconds then
		return 0
	end
	return EyeOptics.smooth(age / C.fadeInSeconds) * EyeOptics.smooth((C.seconds - age) / C.fadeOutSeconds)
end

-- The caption: what the side eyes do, then how to use the principal eyes. `key` is the device's Focus control (ControlText);
-- `toggled` when Focus is a toggle, which is pressed and not held.
function EyeOptics.captionText(key: string, toggled: boolean): string
	local C = Eyes.caption
	return C.side .. "\n" .. string.format(C.principal, if toggled then C.toggle else C.hold, if key ~= "" then key else "Focus")
end

-- A UV layer part's transparency: clear with the side eyes, as visible as its UVOpacity with the principal eyes.
function EyeOptics.uvTransparency(k: number, opacity: number): number
	return 1 - clamp01(k) * clamp01(opacity)
end

return EyeOptics
