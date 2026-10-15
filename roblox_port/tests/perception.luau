-- Perception port checks, part 1 (pure logic): Observation, PerceptionMath, ObservationMemory and the sensor's bookkeeping (SensorCore)
-- against (a) the hand-written expectations of Godot's own unit tests (tests/unit/test_observation.gd, test_perception_math.gd,
-- test_observation_memory.gd) and (b) values exported from the frozen Godot modules (tests/perception_reference.json, made by
-- tools/export_perception_reference.gd; never regenerated from the port). The world half of the sensor (rays, gaze) is not here.
-- Run with the other suites:  python3 tests/run.py path/to/luau perception.luau
local shim = require("./shim")
_G.Vector3 = shim.Vector3
_G.CFrame = shim.CFrame
local Observation = require("../src/Shared/Perception/Observation")
local PerceptionMath = require("../src/Shared/Perception/PerceptionMath")
local ref = require("./perception_reference")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end
local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end
-- Scalars computed in doubles on both sides agree to rounding; Godot's vectors are single precision, so anything made from them to ~1e-5.
local function scalarNear(a: number, b: number): boolean
	return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end
local F32 = 2e-5

-- JSON has no infinity or NaN: the export writes them as strings.
local function num(x: any): number
	if x == "inf" then return math.huge elseif x == "-inf" then return -math.huge elseif x == "nan" then return 0 / 0 end
	return x
end
local function vec(a: { any }): Vector3
	return Vector3.new(num(a[1]), num(a[2]), num(a[3]))
end
local function vnear(v: Vector3, a: { any }, eps: number): boolean
	return math.abs(v.X - a[1]) <= eps and math.abs(v.Y - a[2]) <= eps and math.abs(v.Z - a[3]) <= eps
end
local function sameOut(got: any, want: any): boolean
	if type(want) == "number" then return type(got) == "number" and scalarNear(got, want) end
	if want == "inf" then return got == math.huge end
	return got == want
end
-- Godot's Vector3.rotated(Vector3.UP, a) for the directions the tests turn.
local function rotateY(v: Vector3, deg: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(v.X * math.cos(a) + v.Z * math.sin(a), v.Y, -v.X * math.sin(a) + v.Z * math.cos(a))
end
local FORWARD, UP, RIGHT, LEFT = Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)

-- =============================================================================================== Observation

local function inspection(): any
	return Observation.new({ observerId = "spider", trackId = "trk_1", modality = Observation.INSPECTION, hasPosition = true,
		estimatedPosition = Vector3.new(1, 2, 3), direction = FORWARD, confidence = 0.6, observedTick = 120, category = Observation.POSSIBLE_PREY })
end
local function cue(): any
	return Observation.new({ observerId = "spider", trackId = "trk_2", modality = Observation.PERIPHERAL, direction = LEFT, confidence = 0.2, observedTick = 30 })
end

do
	check(Observation.isValid(inspection()) and Observation.isValid(cue()), "good records have no problems")
	local rules: { [string]: (any) -> () } = {
		["no observer"] = function(o) o.observerId = "" end,
		["no track"] = function(o) o.trackId = "" end,
		["unknown modality"] = function(o) o.modality = "telepathy" end,
		["unknown category"] = function(o) o.category = "housefly" end,
		["confidence above 1"] = function(o) o.confidence = 1.2 end,
		["negative confidence"] = function(o) o.confidence = -0.1 end,
		["nan confidence"] = function(o) o.confidence = 0 / 0 end,
		["negative tick"] = function(o) o.observedTick = -1 end,
		["direction not a unit vector"] = function(o) o.direction = Vector3.new(2, 0, 0) end,
		["infinite position"] = function(o) o.estimatedPosition = Vector3.new(math.huge, 0, 0) end,
		["an inspection without a position"] = function(o) o.hasPosition = false end,
		["a negative speed"] = function(o) o.speedWuS = -0.5 end,
		["an infinite speed"] = function(o) o.speedWuS = math.huge end,
	}
	for label, mutate in rules do
		local o = inspection()
		mutate(o)
		check(not Observation.isValid(o), "refused: " .. label)
		check(#Observation.problems(o) > 0, "and described: " .. label)
	end
	local o = cue(); o.hasPosition = true
	check(not Observation.isValid(o), "a cue with a position is refused")
	o = cue(); o.category = Observation.POSSIBLE_PREY
	check(not Observation.isValid(o), "a cue with a category beyond movement is refused")
	o = cue(); o.targetId = "test_target"
	check(not Observation.isValid(o), "a cue that resolved a target is refused")
	check(Observation.toDict(cue()).estimatedPosition == nil, "and a cue's record has no position to read")
	check(Observation.toDict(inspection()).estimatedPosition == Vector3.new(1, 2, 3), "an inspection's has one")
	local d = Observation.toDict(inspection())
	for _, key in { "observerId", "targetId", "estimatedPosition", "modality", "confidence", "observedTick", "category" } do
		check(d[key] ~= nil or key == "targetId", "spec 21.3 field: " .. key)
	end
	check(d.observedTick == 120 and math.floor(d.observedTick) == d.observedTick, "the tick is an integer action tick")
	-- the method spelling works too (the record carries the module as its metatable)
	check((inspection() :: any):isValid() and #(cue() :: any):problems() == 0, "o:isValid() and o:problems()")

	check(#Observation.CATEGORIES == 3, "movement, possible prey, fly-like prey (A-004)")
	check(Observation.rank(Observation.MOVEMENT) < Observation.rank(Observation.POSSIBLE_PREY), "movement is coarser than possible prey")
	check(Observation.rank(Observation.POSSIBLE_PREY) < Observation.rank(Observation.FLY_LIKE_PREY), "which is coarser than fly-like prey")
	check(Observation.rank("housefly") == -1, "an unknown category has no place (-1, as Godot's find)")
	for _, c in Observation.CATEGORIES do
		check(not (string.find(c, "house") or string.find(c, "musca") or string.find(c, "drosophila")), "no species in '" .. c .. "'")
	end
end

-- The exported cases: validity and the list of problems (numbers in the messages are not compared; Godot and Luau print them differently).
local function camel(s: string): string
	return (string.gsub(s, "_(%a)", function(c: string) return string.upper(c) end))
end
local function normalizeMessage(msg: string): string
	local m = string.gsub(msg, "%-?nan", "#")
	m = string.gsub(m, "%-?inf", "#")
	m = string.gsub(m, "%-?%d[%d%.e%+%-]*", "#")
	return m
end
do
	local strings = { modality = true, category = true, observer_id = true, track_id = true, target_id = true }
	for _, row in ref.observation do
		local o: any = if row.kind == "inspection" then inspection() else cue()
		for k, v in row.set do
			if type(v) == "table" then o[camel(k)] = vec(v)
			elseif type(v) == "string" and not strings[k] then o[camel(k)] = num(v)
			else o[camel(k)] = v end
		end
		check(Observation.isValid(o) == row.valid, `observation '{row.label}': valid == {row.valid}`)
		local got, want = Observation.problems(o), row.problems
		local same = #got == #want
		if same then for i, w in want do if normalizeMessage(got[i]) ~= normalizeMessage(w) then same = false end end end
		check(same, `observation '{row.label}': problems {table.concat(got, "; ")} == {table.concat(want, "; ")}`)
		check((Observation.toDict(o).estimatedPosition ~= nil) == row.dict_has_position, `observation '{row.label}': the record's position`)
	end
end

-- ============================================================================================ PerceptionMath

local EASY_S, FLY_S, EASY_DEG, MIN_DEG = 0.4, 1.0, 3.0, 0.6

do
	check(near(PerceptionMath.apparentSizeDeg(1.0, 10.0), 5.725, 0.01), "1 WU across at 10 WU covers 5.7 degrees")
	check(near(PerceptionMath.apparentSizeDeg(0.9, 5.0), 10.28, 0.02), "the test marker (0.9 WU) at 5 WU")
	check(PerceptionMath.apparentSizeDeg(1.0, 20.0) < PerceptionMath.apparentSizeDeg(1.0, 10.0), "farther looks smaller")
	check(near(PerceptionMath.apparentSizeDeg(1.0, 0.0), 180.0, 1e-9), "from no distance it fills the view")

	check(near(PerceptionMath.angleBetween(FORWARD, RIGHT), math.pi / 2, 1e-6), "a right angle")
	check(near(PerceptionMath.angleBetween(Vector3.zero, RIGHT), 0.0, 1e-9), "a zero vector has no angle")
	local half = math.rad(15.0)
	check(PerceptionMath.inCone(FORWARD, rotateY(FORWARD, 14.9), half), "14.9 degrees off is inside a 15 degree half angle")
	check(not PerceptionMath.inCone(FORWARD, rotateY(FORWARD, 15.5), half), "15.5 degrees off is outside")
	check(not PerceptionMath.inCone(FORWARD, Vector3.zero, half), "no direction is never in a cone")

	check(near(PerceptionMath.requiredExposure(EASY_S, 5.0, EASY_DEG), 0.4, 1e-9), "an easy target needs the base time")
	check(near(PerceptionMath.requiredExposure(EASY_S, 3.0, EASY_DEG), 0.4, 1e-9), "at the easy size exactly")
	check(near(PerceptionMath.requiredExposure(EASY_S, 1.5, EASY_DEG), 0.8, 1e-9), "half the easy size needs twice as long")
	check(PerceptionMath.requiredExposure(EASY_S, 0.0, EASY_DEG) == math.huge, "something with no size can never be refined")

	local cases = { { 0.0, "movement" }, { 0.39, "movement" }, { 0.4, "possible_prey" }, { 0.9, "possible_prey" }, { 1.0, "fly_like_prey" }, { 5.0, "fly_like_prey" } }
	for _, c in cases do
		check(PerceptionMath.classify(c[1], 8.0, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == c[2], `{c[1]} s of an easy target is {c[2]}`)
	end
	check(PerceptionMath.classify(9.0, 0.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == "movement", "below the minimum apparent size nothing is ever refined")
	check(PerceptionMath.classify(0.5, 1.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == "movement", "a small target needs twice the time: 0.5 s is not enough")
	check(PerceptionMath.classify(0.8, 1.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == "possible_prey", "0.8 s is")
	check(PerceptionMath.classify(1.9, 1.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == "possible_prey", "and 2 s are needed for fly-like")
	check(PerceptionMath.classify(2.0, 1.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG) == "fly_like_prey", "which it then is")

	local lo = PerceptionMath.inspectionConfidence(0.0, 1.0, 1.0)
	local mid = PerceptionMath.inspectionConfidence(0.5, 1.0, 1.0)
	local hi = PerceptionMath.inspectionConfidence(1.0, 1.0, 1.0)
	check(lo < mid and mid < hi, "more exposure, more confidence")
	check(near(hi, 1.0, 1e-9), "fully refined and fully seen is certain")
	check(PerceptionMath.inspectionConfidence(1.0, 1.0, 0.2) < hi, "a thing mostly hidden is less certain")
	local worst = PerceptionMath.inspectionConfidence(0.0, 1.0, 0.2)
	check(worst > 0.26 and worst < 0.28, "the least it can be with one point seen is 0.27")
	check(near(PerceptionMath.inspectionConfidence(5.0, 1.0, 1.0), 1.0, 1e-9), "never above 1")
	check(PerceptionMath.inspectionConfidence(0.5, math.huge, 1.0) > 0.0, "a thing that cannot be refined still has a confidence")

	local near1, far1 = PerceptionMath.peripheralConfidence(1.0, 40.0), PerceptionMath.peripheralConfidence(39.0, 40.0)
	check(near1 > far1, "a cue is a little stronger when near")
	check(near1 <= 0.3 and far1 >= 0.1, "between 0.1 and 0.3")
	check(PerceptionMath.peripheralConfidence(1000.0, 40.0) >= 0.1, "and never below 0.1")

	-- a cue gives a sector and a band and no more
	local sector = 22.5
	local function angleDifference(a: number, b: number): number
		return (b - a + math.pi) % (2 * math.pi) - math.pi
	end
	for _, deg in { 0.0, 5.0, 10.0, 30.0, 47.0, 90.0, -100.0, 140.0, -171.0 } do
		local q = PerceptionMath.quantizeDirection(rotateY(FORWARD, deg), FORWARD, UP, sector)
		check(near(q.Magnitude, 1.0, 1e-6), `a unit vector ({deg} degrees)`)
		local flat = Vector3.new(q.X, 0, q.Z)
		local c = FORWARD:Cross(flat)
		local shown = math.deg(math.atan2(c.Magnitude, FORWARD:Dot(flat)) * (if c:Dot(UP) < 0 then -1 else 1))
		local snapped = math.round(deg / sector) * sector
		check(near(math.abs(angleDifference(math.rad(shown), math.rad(snapped))), 0.0, math.rad(0.5)), `{deg} degrees is given as the sector {snapped} (got {shown})`)
		check(math.abs(angleDifference(math.rad(shown), math.rad(deg))) <= math.rad(sector * 0.5 + 0.5), `never off by more than half a sector ({deg})`)
	end
	local up30 = (FORWARD + UP * math.tan(math.rad(28.0))).Unit
	check(near(math.deg(math.asin(PerceptionMath.quantizeDirection(up30, FORWARD, UP, sector).Y)), 30.0, 0.5), "28 degrees up is given as the 30 degree band")
	local up10 = (FORWARD + UP * math.tan(math.rad(10.0))).Unit
	check(near(PerceptionMath.quantizeDirection(up10, FORWARD, UP, sector).Y, 0.0, 1e-6), "10 degrees up is given as level")
	check(near(PerceptionMath.quantizeDirection(UP, FORWARD, UP, sector).Y, 1.0, 1e-6), "straight up has no bearing to round")
	local a = PerceptionMath.quantizeDirection(rotateY(FORWARD, 15.0), FORWARD, UP, 22.5)
	local b = PerceptionMath.quantizeDirection(rotateY(FORWARD, 31.0), FORWARD, UP, 22.5)
	check((a - b).Magnitude < 1e-6, "15 and 31 degrees are the same sector: a cue cannot tell them apart")
	check((a - PerceptionMath.quantizeDirection(rotateY(FORWARD, 40.0), FORWARD, UP, 22.5)).Magnitude > 0.1, "40 degrees is the next sector")

	check(near(PerceptionMath.decayedConfidence(0.8, 0.0, 6.0), 0.8, 1e-9), "at the loss it has what it had")
	check(near(PerceptionMath.decayedConfidence(0.8, 3.0, 6.0), 0.4, 1e-9), "half way, half")
	check(near(PerceptionMath.decayedConfidence(0.8, 6.0, 6.0), 0.0, 1e-9), "gone at the decay time")
	check(near(PerceptionMath.decayedConfidence(0.8, 60.0, 6.0), 0.0, 1e-9), "and not negative")
	check(near(PerceptionMath.decayedConfidence(0.8, 1.0, 0.0), 0.0, 1e-9), "no decay time means no memory")
	check(near(PerceptionMath.staleness(0.0, 6.0), 0.0, 1e-9) and near(PerceptionMath.staleness(1.5, 6.0), 0.25, 1e-9) and near(PerceptionMath.staleness(7.0, 6.0), 1.0, 1e-9), "staleness: fresh, a quarter, at most 1")

	-- A-024: the sight allowance follows the size of the thing and never hides a whole speck
	check(near(PerceptionMath.sightTolerance(0.01, 1.0), 0.00101, 1e-6), "a speck 0.02 WU across, 1 WU away: a tenth of its radius and the float error of the cast")
	check(PerceptionMath.sightTolerance(0.01, 1.0) < 0.01, "far less than the speck's own radius")
	check(PerceptionMath.sightTolerance(0.01, 1.0) < PerceptionMath.sightTolerance(0.1, 1.0) and PerceptionMath.sightTolerance(0.1, 1.0) < PerceptionMath.sightTolerance(0.45, 1.0), "it grows with the size of the thing")
	check(near(PerceptionMath.sightTolerance(0.45, 5.0), 0.04505, 1e-6), "the 0.9 WU test marker keeps close to what it had")
	check(near(PerceptionMath.sightTolerance(5.0, 5.0), PerceptionMath.SIGHT_CEILING, 1e-9), "and nothing is ever allowed more than the old flat 0.05")
	check(PerceptionMath.sightTolerance(0.0, 0.0) == 0.0 and PerceptionMath.sightTolerance(-1.0, -1.0) == 0.0, "a thing of no size, or nonsense, is allowed nothing")
	for _, r in { 0.005, 0.01, 0.02, 0.05, 0.1, 0.3 } do
		check(PerceptionMath.sightTolerance(r, 1.0) < 0.02 + r, `a sphere of radius {r} behind a barrier 0.02 thick is never forgiven`)
	end

	-- A-027: the region a lost contact's thing could be in
	check(near(PerceptionMath.plausibleRadius(0.5, 0.5, 0.0, 2.0, 0.0), 0.5, 1e-9), "at once, only the size of what was seen")
	check(near(PerceptionMath.plausibleRadius(0.5, 0.5, 3.0, 2.0, 0.0), 6.5, 1e-9), "it grows by the speed bound each second")
	check(near(PerceptionMath.plausibleRadius(0.5, 0.5, 3.0, 2.0, 5.0), 15.5, 1e-9), "or by the speed it was seen moving at, when that was more")
	check(near(PerceptionMath.plausibleRadius(0.5, 0.5, -4.0, 2.0, 0.0), 0.5, 1e-9), "time does not run backwards")
	check(PerceptionMath.plausibleRadius(0.4, 0.6, 1.5, 2.0, 0.8) == PerceptionMath.plausibleRadius(0.4, 0.6, 1.5, 2.0, 0.8), "the same sightings give the same region")
	check(PerceptionMath.sizesCompatible(0.5, 0.5, 1.5) and PerceptionMath.sizesCompatible(0.5, 0.74, 1.5) and PerceptionMath.sizesCompatible(0.74, 0.5, 1.5), "sizes within the ratio, either way round")
	check(not PerceptionMath.sizesCompatible(0.5, 0.8, 1.5) and not PerceptionMath.sizesCompatible(0.8, 0.5, 1.5), "beyond it they are two things")
	check(PerceptionMath.sizesCompatible(0.0, 0.9, 1.5) and PerceptionMath.sizesCompatible(0.9, 0.0, 1.5), "a size that was not known is compatible with any")
	check(PerceptionMath.sizesCompatible(1.0, 1.0, 0.2), "a ratio under 1 is taken as 1")
	check(PerceptionMath.categoriesCompatible("movement", "movement") and PerceptionMath.categoriesCompatible("possible_prey", "fly_like_prey"), "what was learned can be a thing that can look at least as fine")
	check(not PerceptionMath.categoriesCompatible("fly_like_prey", "movement") and not PerceptionMath.categoriesCompatible("possible_prey", "movement"), "but not one that never looks finer than movement")
end

-- The exported tables: each row is {in = inputs, out = Godot's answer}.
do
	local m = ref.math
	for _, r in m.sight_tolerance do check(sameOut(PerceptionMath.sightTolerance(r["in"][1], r["in"][2]), r.out), `sight_tolerance {r["in"][1]}, {r["in"][2]}`) end
	for _, r in m.plausible_radius do local i = r["in"]; check(sameOut(PerceptionMath.plausibleRadius(i[1], i[2], i[3], i[4], i[5]), r.out), `plausible_radius {table.concat(i, ", ")}`) end
	for _, r in m.sizes_compatible do local i = r["in"]; check(PerceptionMath.sizesCompatible(i[1], i[2], i[3]) == r.out, `sizes_compatible {table.concat(i, ", ")}`) end
	for _, r in m.categories_compatible do local i = r["in"]; check(PerceptionMath.categoriesCompatible(i[1], i[2]) == r.out, `categories_compatible {i[1]}, {i[2]}`) end
	for _, r in m.rank do check(Observation.rank(r["in"][1]) == r.out, `rank {r["in"][1]}`) end
	for i, r in m.angle_between do check(near(PerceptionMath.angleBetween(vec(r["in"][1]), vec(r["in"][2])), r.out, 1e-6), `angle_between case {i}`) end
	for i, r in m.in_cone do check(PerceptionMath.inCone(vec(r["in"][1]), vec(r["in"][2]), r["in"][3]) == r.out, `in_cone case {i}`) end
	for _, r in m.apparent_size_deg do check(sameOut(PerceptionMath.apparentSizeDeg(r["in"][1], r["in"][2]), r.out), `apparent_size_deg {r["in"][1]}, {r["in"][2]}`) end
	for _, r in m.required_exposure do local i = r["in"]; check(sameOut(PerceptionMath.requiredExposure(i[1], i[2], i[3]), r.out), `required_exposure {table.concat(i, ", ")}`) end
	for _, r in m.classify do local i = r["in"]; check(PerceptionMath.classify(i[1], i[2], i[3], i[4], i[5], i[6]) == r.out, `classify {table.concat(i, ", ")}`) end
	for _, r in m.inspection_confidence do local i = r["in"]; check(sameOut(PerceptionMath.inspectionConfidence(i[1], num(i[2]), i[3]), r.out), `inspection_confidence {i[1]}, {i[2]}, {i[3]}`) end
	for _, r in m.peripheral_confidence do check(sameOut(PerceptionMath.peripheralConfidence(r["in"][1], r["in"][2]), r.out), `peripheral_confidence {r["in"][1]}, {r["in"][2]}`) end
	for i, r in m.quantize_direction do
		local q = PerceptionMath.quantizeDirection(vec(r["in"][1]), vec(r["in"][2]), vec(r["in"][3]), r["in"][4])
		check(vnear(q, r.out, F32), `quantize_direction case {i}: {q} vs {table.concat(r.out, ", ")}`)
	end
	for _, r in m.decayed_confidence do local i = r["in"]; check(sameOut(PerceptionMath.decayedConfidence(i[1], i[2], i[3]), r.out), `decayed_confidence {table.concat(i, ", ")}`) end
	for _, r in m.staleness do check(sameOut(PerceptionMath.staleness(r["in"][1], r["in"][2]), r.out), `staleness {r["in"][1]}, {r["in"][2]}`) end
end

-- SECTIONS GO ABOVE THIS LINE
print(`PERCEPTION passed={passed} failed={failed}`)
if failed > 0 then error("perception check failed") end
