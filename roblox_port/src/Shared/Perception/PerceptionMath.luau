--!strict
-- Pure helpers for the perception layer (spec 7): angles, apparent size, the exposure a classification needs, the evidence's
-- confidence, the coarse direction a peripheral cue is given, how a remembered contact fades. A port of the frozen Godot
-- scripts/perception/perception_math.gd (c87ce00), function for function, with the same numbers. Nothing here touches the scene.
-- Checked against values exported from Godot (tests/perception_reference.json) and against the hand-written expectations of Godot's
-- own unit tests (tests/unit/test_perception_math.gd), both in tests/perception.luau.
local Observation = require(script.Parent.Observation)

local PerceptionMath = {}

local EPS = 1e-6
PerceptionMath.EPS = EPS
-- A peripheral cue is given a direction in sectors of the observer's own bearing, and in coarse bands of elevation.
PerceptionMath.PITCH_BAND_DEG = 30.0
-- Visibility of a sample point (A-024, D-039). A ray the world stops short of its sample point has not seen it: the world is in front of
-- it. The only allowance is for a sample that lies in the skin of the surface the thing rests on or against and for the float error of a
-- long cast: SIGHT_SHARE of the thing's own radius plus SIGHT_FLOAT_PER_WU for each WU of ray, and never more than SIGHT_CEILING.
PerceptionMath.SIGHT_SHARE = 0.1
PerceptionMath.SIGHT_FLOAT_PER_WU = 1.0e-5
PerceptionMath.SIGHT_CEILING = 0.05

local function isFinite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

-- Godot's Vector3.normalized(): a vector with no length stays zero.
local function normalized(v: Vector3): Vector3
	local m = v.Magnitude
	if m == 0 then
		return Vector3.zero
	end
	return v / m
end

-- How far short of its sample point a ray may be stopped by the world and still count as having seen it (A-024). The sample points sit up
-- to 0.8 of the radius off the centre, so for a thing of radius r the allowance is a tenth of r: a speck's whole body is never inside it,
-- and a large thing resting on a wall still has the points that lie in the wall's face counted.
function PerceptionMath.sightTolerance(radius: number, rayLength: number): number
	return math.min(
		PerceptionMath.SIGHT_CEILING,
		PerceptionMath.SIGHT_SHARE * math.max(radius, 0.0) + PerceptionMath.SIGHT_FLOAT_PER_WU * math.max(rayLength, 0.0)
	)
end

-- The furthest a lost contact's thing can be from where it was last observed when something is seen `elapsedS` later (A-027, D-040).
-- Three parts, each an observation or an explicit assumption and none of them the truth about where the thing went: the sizes of the two
-- sightings (a position is only good to about the size of what it was taken from), and the distance the thing could have covered in the
-- time at the conservative speed bound, or at the speed it was last seen moving at if that was greater.
function PerceptionMath.plausibleRadius(oldSizeWu: number, newSizeWu: number, elapsedS: number, speedBound: number, observedSpeed: number): number
	return 0.5 * (math.max(oldSizeWu, 0.0) + math.max(newSizeWu, 0.0)) + math.max(speedBound, observedSpeed) * math.max(elapsedS, 0.0)
end

-- Whether two size estimates can belong to one thing: neither is more than `ratio` times the other. A size that is not known (zero) is
-- compatible with anything.
function PerceptionMath.sizesCompatible(a: number, b: number, ratio: number): boolean
	if a <= EPS or b <= EPS then
		return true
	end
	return math.max(a, b) <= math.min(a, b) * math.max(ratio, 1.0) + EPS
end

-- Whether a lost contact refined to `oldCategory` can be a thing whose appearance can be refined no further than `cap`: what was learned
-- about the one cannot be finer than the other can ever look.
function PerceptionMath.categoriesCompatible(oldCategory: string, cap: string): boolean
	return Observation.rank(oldCategory) <= Observation.rank(cap)
end

-- Angle between two vectors (Godot's Vector3.angle_to, which needs no unit length), radians.
function PerceptionMath.angleTo(a: Vector3, b: Vector3): number
	return math.atan2(a:Cross(b).Magnitude, a:Dot(b))
end

-- Angle between two directions, radians; 0 when either has no length.
function PerceptionMath.angleBetween(a: Vector3, b: Vector3): number
	if a:Dot(a) < EPS * EPS or b:Dot(b) < EPS * EPS then
		return 0.0
	end
	return PerceptionMath.angleTo(normalized(a), normalized(b))
end

-- True when `to` lies within `halfAngle` (radians) of `axis`.
function PerceptionMath.inCone(axis: Vector3, to: Vector3, halfAngle: number): boolean
	return to:Dot(to) > EPS * EPS and PerceptionMath.angleBetween(axis, to) <= halfAngle + 1e-9
end

-- How large a thing of `sizeWu` across looks from `distance`, degrees of angle.
function PerceptionMath.apparentSizeDeg(sizeWu: number, distance: number): number
	if distance <= EPS then
		return 180.0
	end
	return math.deg(2.0 * math.atan(sizeWu * 0.5 / distance))
end

-- Continuous exposure a refinement needs: `baseS` for an easy target (one that looks at least `easyDeg` across), and proportionally
-- longer the smaller it looks. Infinite for something with no apparent size.
function PerceptionMath.requiredExposure(baseS: number, apparentDeg: number, easyDeg: number): number
	if apparentDeg <= EPS then
		return math.huge
	end
	return baseS * math.max(1.0, easyDeg / apparentDeg)
end

-- The category continuous exposure supports. Nothing smaller than `minDeg` is refined at all.
function PerceptionMath.classify(exposureS: number, apparentDeg: number, easyS: number, flyS: number, easyDeg: number, minDeg: number): string
	if apparentDeg < minDeg then
		return Observation.MOVEMENT
	end
	if exposureS + EPS >= PerceptionMath.requiredExposure(flyS, apparentDeg, easyDeg) then
		return Observation.FLY_LIKE_PREY
	end
	if exposureS + EPS >= PerceptionMath.requiredExposure(easyS, apparentDeg, easyDeg) then
		return Observation.POSSIBLE_PREY
	end
	return Observation.MOVEMENT
end

-- Confidence of an inspection: it rises with exposure (to the fly-like refinement) and falls with how much of the thing is hidden. From
-- 0.4 x 0.68 = 0.27 (one of five sample points seen, no exposure yet) to 1.
function PerceptionMath.inspectionConfidence(exposureS: number, flyNeededS: number, visibleFraction: number): number
	local progress = 0.0
	if isFinite(flyNeededS) then
		progress = math.clamp(exposureS / math.max(flyNeededS, EPS), 0.0, 1.0)
	end
	return math.clamp((0.4 + 0.6 * progress) * (0.6 + 0.4 * math.clamp(visibleFraction, 0.0, 1.0)), 0.0, 1.0)
end

-- Confidence of a peripheral cue: low, and a little higher the nearer it is. In [0.1, 0.3].
function PerceptionMath.peripheralConfidence(distance: number, rangeWu: number): number
	return math.clamp(0.1 + 0.2 * (1.0 - distance / math.max(rangeWu, EPS)), 0.1, 0.3)
end

-- The direction of a peripheral cue, coarse: its bearing about `up` from `forward` rounded to a sector, its elevation to a band of
-- PITCH_BAND_DEG. Returns a unit vector. This is all a peripheral observation says about where.
function PerceptionMath.quantizeDirection(dir: Vector3, forward: Vector3, up: Vector3, sectorDeg: number): Vector3
	local d = normalized(dir)
	local u = normalized(up)
	local f = forward - u * forward:Dot(u)
	if f:Dot(f) < EPS then
		f = d - u * d:Dot(u)
	end
	if f:Dot(f) < EPS then
		return d -- straight up or down: there is no bearing to round
	end
	f = normalized(f)
	local right = normalized(f:Cross(u))
	local yaw = math.atan2(d:Dot(right), d:Dot(f))
	local pitch = math.asin(math.clamp(d:Dot(u), -1.0, 1.0))
	local sector = math.rad(math.max(sectorDeg, 0.5))
	local band = math.rad(PerceptionMath.PITCH_BAND_DEG)
	local yq = math.round(yaw / sector) * sector
	local pq = math.round(pitch / band) * band
	return normalized(f * (math.cos(pq) * math.cos(yq)) + right * (math.cos(pq) * math.sin(yq)) + u * math.sin(pq))
end

-- Confidence of a contact that is no longer sensed: it falls straight to nothing over `decayS`, from the confidence it had when it was lost.
function PerceptionMath.decayedConfidence(confidenceAtLoss: number, ageS: number, decayS: number): number
	if decayS <= EPS then
		return 0.0
	end
	return math.clamp(confidenceAtLoss * (1.0 - ageS / decayS), 0.0, 1.0)
end

-- 0 when a contact has only just been lost, 1 when its memory is gone.
function PerceptionMath.staleness(ageS: number, decayS: number): number
	if decayS <= EPS then
		return 1.0
	end
	return math.clamp(ageS / decayS, 0.0, 1.0)
end

return PerceptionMath
