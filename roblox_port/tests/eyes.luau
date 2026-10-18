-- Eyes checks (ROBLOX-20): the spider-eye picture. First the numbers of Data/Eyes (the spec's values, ranges, citations) and the pure
-- rules of Shared/UI/EyeOptics (the blend of the two ways of seeing, the field of view and look scale, the depth of field, the
-- retina strips in pixels and how they scan, the movement rings and edge arcs, the caption, the UV layer); then the real SpiderEyes
-- under the shim (tests/shim.luau) with a stand-in camera rig and sensor: what it sets in the eye view, what Focus changes, what it
-- puts back and what it never draws; and last the real client: V, Focus, the caption in the HUD and who owns the depth of field.
-- It says nothing about how any of it LOOKS in Roblox (colour, blur, depth of field, rings and strips can only be judged in Studio).
-- Run with the other suites:  python3 tests/run.py path/to/luau eyes.luau
local Eyes = require("../src/Shared/Data/Eyes")
local EyeOptics = require("../src/Shared/UI/EyeOptics")
local ControlText = require("../src/Shared/UI/ControlText")
local Sensor = require("../src/Shared/Perception/Sensor")
local SpiderCamera = require("../src/Client/SpiderCamera")
local SpiderEyes = require("../src/Client/SpiderEyes")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL eyes: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local function rad(d: number): number return math.rad(d) end
local function tan(d: number): number return math.tan(math.rad(d)) end

local S, P = Eyes.side, Eyes.principal

-- ---------------------------------------------------------------- the numbers
check(S.fovDeg == 90 and P.fovDeg == 24, "the side eyes see 90 degrees (vertical), the principal eyes 24")
check(P.fovDeg >= Eyes.retina.heightDeg and P.fovDeg < 2 * Eyes.retina.heightDeg, "the telephoto view is just wider than a 20 degree retina is tall")
check(S.saturation == 0.15 and P.saturation == 0.15, "central colour remains during both wide and Focus views")
check(S.tint[1] == 115 and S.tint[2] == 255 and S.tint[3] == 236, "the wide view retains the principal-eye colour impression")
check(P.tint[1] == 115 and P.tint[2] == 255 and P.tint[3] == 236, "the principal eyes' tint cuts the red: (115, 255, 236)")
check(P.tint[1] < P.tint[2] and P.tint[1] < P.tint[3] and P.tint[3] > 0.8 * P.tint[2], "red is the cut channel, blue stands in for the short-wave one")
check(S.contrast == 0.12 and P.contrast == 0.16 and S.brightness == 0.03 and P.brightness == 0.02, "contrast 0.12 / 0.16, brightness 0.03 / 0.02")
check(S.blur == 0 and P.blur == 0, "neither view blurs the clear centre")
check(S.dofFar == 0.35 and S.dofNear == 0.25 and P.dofFar == 0.75 and P.dofNear == 0.6, "depth of field intensities 0.35 / 0.25 and 0.75 / 0.6")
check(S.dofRadiusMin == 6 and S.dofRadiusPerStud == 0.6 and P.dofRadiusMin == 0.6 and P.dofRadiusPerStud == 0.12, "in-focus radius max(6, 0.6 d) and max(0.6, 0.12 d)")
check(S.strokeTransparency == 0.82 and P.strokeTransparency == 0.68, "the retina outline: transparency 0.82 and 0.68")
check(S.sweepDeg == 4 and P.sweepDeg == 0.6 and S.torsionDeg == 12 and P.torsionDeg == 3, "scanning: sway 4 and 0.6 degrees, turn 12 and 3")
check(S.vignette == 0.65 and P.vignette == 0.75 and Eyes.vignette.color[1] == 48 and Eyes.vignette.color[2] == 52 and Eyes.vignette.color[3] == 48, "neutral surround at 0.65 and 0.75")
local R = Eyes.retina
check(R.widthDeg == 5 and R.heightDeg == 20 and R.offsetDeg == 3 and R.tiltDeg == 10, "each retina is 5 x 20 degrees, 3 degrees either side of the middle, tilted 10")
check(R.sweepSeconds == 1.7 and R.lagSeconds == 0.3 and R.torsionSeconds == 2.6, "sway period 1.7 s, the second strip 0.3 s behind, turn period 2.6 s")
check(R.strokeColor[1] == 200 and R.strokeColor[2] == 255 and R.strokeColor[3] == 220 and R.strokeThickness == 1.5, "the outline is (200, 255, 220), 1.5 px")
check(Eyes.timing.engageSeconds == 0.35 and Eyes.timing.releaseSeconds == 0.5, "the principal eyes come in in 0.35 s and go out in 0.5 s")
check(Eyes.focus.maxDistance == 40 and Eyes.focus.tauSeconds == 0.15, "focus looks at most 40 studs out and racks with a 0.15 s time constant")
check(Eyes.reducedMotion.minFovDeg == 45, "reduced motion stops the zoom at 45 degrees")
local H = Eyes.shimmer
check(H.hz == 3 and H.scaleMin == 1.0 and H.scaleMax == 1.6 and H.minPx == 14 and H.insideStripFactor == 0.3 and H.maxMovers == 8, "rings: 3 Hz, 1.0 to 1.6 times, 14 px, 0.3 inside a strip, at most 8")
check(H.hz <= 3, "the pulse is at or under the 3 Hz flash guideline")
check(Eyes.overlay.displayOrder < 0 and Eyes.overlay.name == "EyeOverlay", "the overlay sits under SpiderHud (order 0) and the perception HUD (order 4)")
check(Eyes.effects.grade == "EyeGrade" and Eyes.effects.blur == "EyeBlur" and Eyes.effects.dof == "MacroDOF", "the effect names")
check(Eyes.uv.folder[1] == "Decor" and Eyes.uv.folder[2] == "UVLayer" and Eyes.uv.opacityAttribute == "UVOpacity" and Eyes.uv.lookupSeconds == 1, "the UV layer is Decor.UVLayer, UVOpacity, looked up at most once a second")
check(Eyes.caption.seconds == 6 and string.find(Eyes.caption.side, "Spider-eye impression: a clear colour centre, muted edges that still catch movement.", 1, true) ~= nil, "the caption's first line and 6 seconds")
local ranges = true
for _, v in { S, P } do
	ranges = ranges and v.fovDeg >= 1 and v.fovDeg <= 120 and math.abs(v.saturation) <= 1 and math.abs(v.contrast) <= 1 and math.abs(v.brightness) <= 1
		and v.blur >= 0 and v.blur <= 56 and v.dofFar >= 0 and v.dofFar <= 1 and v.dofNear >= 0 and v.dofNear <= 1 and v.dofRadiusMin > 0 and v.dofRadiusPerStud > 0
		and v.strokeTransparency >= 0 and v.strokeTransparency <= 1 and v.fillTransparency >= 0 and v.fillTransparency <= 1 and v.vignette >= 0 and v.vignette <= 1
		and v.sweepDeg >= 0 and v.torsionDeg >= 0
	for _, c in v.tint do ranges = ranges and c >= 0 and c <= 255 end
end
check(ranges, "every look is in the range the engine's effects take")
local cited = true
for _, name in { "land1969", "shepeleva2022", "nagata2012", "devoe1975", "glenszczyk2022", "zurek2010" } do
	local text = (Eyes.sources :: any)[name]
	cited = cited and type(text) == "string" and string.find(text, "%d%d%d%d") ~= nil
end
check(cited, "the sources the notes cite are listed, each with a year")
check(S.sweepDeg > P.sweepDeg and S.torsionDeg > P.torsionDeg and S.blur == P.blur and S.fovDeg > P.fovDeg and S.vignette < P.vignette, "the side eyes scan more, the principal eyes zoom and darken the edges more")

-- ---------------------------------------------------------------- how much the principal eyes are in use
local function runPhase(wanted: boolean, seconds: number, hz: number, from: number): number
	local phase = from
	for _ = 1, math.floor(seconds * hz + 0.5) do phase = EyeOptics.stepPhase(phase, wanted, 1 / hz) end
	return phase
end
for _, hz in { 40, 80, 120, 200 } do
	check(near(runPhase(true, 0.175, hz, 0), 0.5, 1e-9), `half way in after 0.175 s at {hz} Hz, whatever the frame rate`)
end
for _, hz in { 20, 60, 120 } do
	check(near(runPhase(true, 0.35, hz, 0), 1, 1e-9) and runPhase(true, 1, hz, 0) == 1, `all the way in after 0.35 s at {hz} Hz, and no further`)
end
for _, hz in { 40, 60, 100, 120 } do
	check(near(runPhase(false, 0.25, hz, 1), 0.5, 1e-9), `half way out after 0.25 s at {hz} Hz`)
end
check(near(runPhase(false, 0.5, 60, 1), 0, 1e-9) and runPhase(false, 2, 60, 1) == 0, "all the way out after 0.5 s, and no further")
check(EyeOptics.stepPhase(0.4, true, -1) == 0.4 and EyeOptics.stepPhase(0.4, false, 0) == 0.4, "no time, no change")
check(near(runPhase(false, 0.1, 100, runPhase(true, 0.2, 100, 0)), 0.2 / 0.35 - 0.1 / 0.5, 1e-9), "a change of mind turns the phase round where it is")
check(EyeOptics.engagement(0) == 0 and EyeOptics.engagement(1) == 1 and near(EyeOptics.engagement(0.5), 0.5, 1e-12), "k is 0, 0.5 and 1 at those phases")
local eased = true
local last = -1
for i = 0, 100 do
	local k = EyeOptics.engagement(i / 100)
	eased = eased and k >= last and k >= 0 and k <= 1
	last = k
end
check(eased and EyeOptics.engagement(0.1) < 0.1 and EyeOptics.engagement(0.9) > 0.9, "k rises steadily, gently at both ends")
check(EyeOptics.engagement(-1) == 0 and EyeOptics.engagement(2) == 1, "k stays in 0 to 1")

-- ---------------------------------------------------------------- the field of view and the look
check(EyeOptics.fovDeg(0, false) == 90 and EyeOptics.fovDeg(1, false) == 24 and EyeOptics.fovDeg(-1, false) == 90 and EyeOptics.fovDeg(2, false) == 24, "the field of view is exactly 90 and 24 at the ends")
local mid = EyeOptics.fovDeg(0.5, false)
check(near(tan(mid / 2), (tan(45) + tan(12)) / 2, 1e-12), "half way, tan(fov / 2) is half way between those of 90 and 24 (tangent space)")
check(mid > (90 + 24) / 2 and mid < 90, `which is wider than the plain average ({mid})`)
local fovMonotone = true
local lastFov = 1000
for i = 0, 50 do
	local f = EyeOptics.fovDeg(i / 50, false)
	fovMonotone = fovMonotone and f < lastFov and f >= 24 and f <= 90
	lastFov = f
end
check(fovMonotone, "the field narrows steadily as k rises")
check(EyeOptics.principalFovDeg(false) == 24 and EyeOptics.principalFovDeg(true) == 45, "reduced motion caps the zoom at 45 degrees")
check(EyeOptics.fovDeg(1, true) == 45 and EyeOptics.fovDeg(0, true) == 90 and near(tan(EyeOptics.fovDeg(0.5, true) / 2), (tan(45) + tan(22.5)) / 2, 1e-12), "and the zoom with it, still in tangent space")
check(near(EyeOptics.lookScale(90), 1, 1e-12) and near(EyeOptics.lookScale(24), tan(12), 1e-12) and near(EyeOptics.lookScale(45), tan(22.5), 1e-12), "look scale is tan(fov / 2) over tan(45)")
check(near(EyeOptics.lookScale(24) * EyeOptics.pixelsPerTan(24, 1000), EyeOptics.lookScale(90) * EyeOptics.pixelsPerTan(90, 1000), 1e-9) and near(EyeOptics.lookScale(45) * EyeOptics.pixelsPerTan(45, 1000), 500, 1e-9), "the look scale keeps the picture's speed across the screen the same at any zoom (500 px per radian at 1000 px high)")

-- ---------------------------------------------------------------- the blend
local function rgbOf(c: Color3): (number, number, number) return c.R * 255, c.G * 255, c.B * 255 end
local p0, p1 = EyeOptics.profile(0, 10, false), EyeOptics.profile(1, 10, false)
check(p0.fovDeg == 90 and p0.saturation == 0.15 and p0.contrast == 0.12 and p0.brightness == 0.03 and p0.blur == 0, "k = 0: the side eyes' look")
check(p1.fovDeg == 24 and p1.saturation == 0.15 and p1.contrast == 0.16 and p1.brightness == 0.02 and p1.blur == 0, "k = 1: the principal eyes' look")
local r0, g0, b0 = rgbOf(p0.tint)
local r1, g1, b1 = rgbOf(p1.tint)
check(near(r0, 115, 1e-9) and near(g0, 255, 1e-9) and near(b0, 236, 1e-9) and near(r1, 115, 1e-9) and near(g1, 255, 1e-9) and near(b1, 236, 1e-9), "the tint at both ends")
check(p0.dofFar == 0.35 and p0.dofNear == 0.25 and p1.dofFar == 0.75 and p1.dofNear == 0.6, "the depth of field at both ends")
check(p0.strokeTransparency == 0.82 and p1.strokeTransparency == 0.68 and p0.vignette == 0.65 and p1.vignette == 0.75, "the outline and the vignette at both ends")
local ph = EyeOptics.profile(0.5, 10, false)
local rh, gh, bh = rgbOf(ph.tint)
check(near(ph.saturation, 0.15, 1e-12) and near(ph.contrast, 0.14, 1e-12) and near(ph.brightness, 0.025, 1e-12) and near(ph.blur, 0, 1e-12), "half way, every number is the average")
check(near(rh, 115, 1e-9) and near(gh, 255, 1e-9) and near(bh, 236, 1e-9), "half way, the tint is the average")
check(near(ph.dofFar, 0.55, 1e-12) and near(ph.dofNear, 0.425, 1e-12) and near(ph.strokeTransparency, 0.75, 1e-12) and near(ph.vignette, 0.7, 1e-12), "half way, the depth of field, outline and vignette too")
check(near(ph.fovDeg, mid, 1e-12), "and the field of view is the tangent-space blend")
check(near(EyeOptics.profile(0, 5, false).dofRadius, 6, 1e-12) and near(EyeOptics.profile(0, 20, false).dofRadius, 12, 1e-12), "side eyes: in focus within max(6, 0.6 x distance)")
check(near(EyeOptics.profile(1, 2, false).dofRadius, 0.6, 1e-12) and near(EyeOptics.profile(1, 10, false).dofRadius, 1.2, 1e-12) and near(EyeOptics.profile(1, 40, false).dofRadius, 4.8, 1e-12), "principal eyes: within max(0.6, 0.12 x distance)")
check(near(EyeOptics.profile(0.5, 20, false).dofRadius, (12 + 2.4) / 2, 1e-12), "half way, the radius is the average of the two")
check(EyeOptics.profile(1, -3, false).dofRadius == 0.6, "a negative distance counts as none")
check(EyeOptics.profile(0.3, 7, false).k == 0.3 and EyeOptics.profile(5, 7, false).k == 1 and EyeOptics.profile(-5, 7, false).k == 0, "k is kept within 0 to 1")
local pr = EyeOptics.profile(1, 10, true)
check(pr.fovDeg == 45 and pr.sweepDeg == 0 and pr.torsionDeg == 0, "reduced motion: the zoom stops at 45 and the retinae hold still")
check(EyeOptics.profile(0, 10, true).fovDeg == 90 and EyeOptics.profile(0, 10, true).saturation == 0.15, "reduced motion leaves the colour and the side eyes' field alone")

-- ---------------------------------------------------------------- where the eyes are focused
check(EyeOptics.focusTarget(nil) == 40 and EyeOptics.focusTarget(12.5) == 12.5 and EyeOptics.focusTarget(100) == 40 and EyeOptics.focusTarget(0) == 0, "focus lands where the ray ends: at most 40, 40 when it hit nothing")
check(near(EyeOptics.focusStep(0, 10, 0.15), 10 * (1 - math.exp(-1)), 1e-12), "after one time constant it has gone 63 per cent of the way")
check(EyeOptics.focusStep(5, 5, 1) == 5 and EyeOptics.focusStep(5, 9, 0) == 5 and EyeOptics.focusStep(5, 9, -1) == 5, "no distance or no time, no move")
local stepped, once = 0, 0
for _ = 1, 60 do stepped = EyeOptics.focusStep(stepped, 10, 1 / 60) end
once = EyeOptics.focusStep(0, 10, 1)
local at30 = 0
for _ = 1, 30 do at30 = EyeOptics.focusStep(at30, 10, 1 / 30) end
check(near(stepped, once, 1e-9) and near(at30, once, 1e-9), "the same distance after the same time at any frame rate")
check(EyeOptics.focusStep(0, 10, 10) > 9.99 and EyeOptics.focusStep(0, 10, 10) <= 10, "it settles on the target without passing it")

-- ---------------------------------------------------------------- sizes on the screen
check(near(EyeOptics.extentPx(20, 24, 1080), 1080 * tan(10) / tan(12), 1e-9), "a 20 degree strip at a 24 degree field is tan(10) / tan(12) of the screen's height")
check(near(EyeOptics.extentPx(5, 24, 1080), 1080 * tan(2.5) / tan(12), 1e-9) and near(EyeOptics.extentPx(90, 90, 1000), 1000, 1e-9), "and a 5 degree one; a view's own field fills the height")
check(near(EyeOptics.extentPx(20, 90, 1080), 1080 * tan(10), 1e-9), "the same strip at the side eyes' field is small")
check(EyeOptics.extentPx(1000, 24, 1080) > 0 and EyeOptics.extentPx(1000, 24, 1080) < 1e6, "a huge angle does not blow up")
check(near(EyeOptics.offsetPx(3, 24, 1080), 540 * tan(3) / tan(12), 1e-9) and EyeOptics.offsetPx(0, 24, 1080) == 0 and near(EyeOptics.offsetPx(-3, 24, 1080), -EyeOptics.offsetPx(3, 24, 1080), 1e-12), "an angle off the axis lands tan(angle) times pixelsPerTan from the middle")
check(near(EyeOptics.pixelsPerTan(90, 1000), 500, 1e-9) and near(EyeOptics.pixelsPerTan(24, 1000), 500 / tan(12), 1e-9), "a 90 degree field: 500 px for one unit of tangent at 1000 px high; 24 degrees: 1 / tan(12) times that")

-- ---------------------------------------------------------------- the retina strips
check(near(select(1, EyeOptics.scanPose(1, 0, 4, 12)), 0, 1e-12) and near(select(2, EyeOptics.scanPose(1, 0, 4, 12)), 0, 1e-12), "the first strip starts at rest")
check(near(select(1, EyeOptics.scanPose(1, 1.7 / 4, 4, 12)), 4, 1e-12) and near(select(1, EyeOptics.scanPose(1, 3 * 1.7 / 4, 4, 12)), -4, 1e-12), "the sway reaches 4 degrees each way every 1.7 s")
check(near(select(2, EyeOptics.scanPose(1, 2.6 / 4, 4, 12)), 12, 1e-12) and near(select(2, EyeOptics.scanPose(1, 3 * 2.6 / 4, 4, 12)), -12, 1e-12), "the turn reaches 12 degrees each way every 2.6 s")
check(near(select(1, EyeOptics.scanPose(1, 5 + 1.7, 4, 12)), select(1, EyeOptics.scanPose(1, 5, 4, 12)), 1e-9) and near(select(2, EyeOptics.scanPose(1, 5 + 2.6, 4, 12)), select(2, EyeOptics.scanPose(1, 5, 4, 12)), 1e-9), "both repeat")
local lagOk = true
for i = 0, 20 do
	local t = i * 0.37
	local a1, a2 = EyeOptics.scanPose(2, t, 4, 12)
	local b1, b2 = EyeOptics.scanPose(1, t - 0.3, 4, 12)
	lagOk = lagOk and near(a1, b1, 1e-12) and near(a2, b2, 1e-12)
end
check(lagOk, "the second strip is the first one 0.3 s later, in the sway and the turn")
local sway0 = select(1, EyeOptics.scanPose(2, 0.3 + 1.7 / 4, 0.6, 3))
check(near(sway0, 0.6, 1e-12) and near(select(2, EyeOptics.scanPose(1, 2.6 / 4, 0.6, 3)), 3, 1e-12), "with the principal eyes: 0.6 degrees of sway, 3 of turn")
check(select(1, EyeOptics.scanPose(1, 0.7, 0, 0)) == 0 and select(2, EyeOptics.scanPose(2, 0.7, 0, 0)) == 0, "no amplitude, no movement")

local reducedStill = EyeOptics.profile(0, 10, true)
local function strips(t: number, k: number, w: number, h: number, reduced: boolean)
	return EyeOptics.retinaStrips(t, EyeOptics.profile(k, 10, reduced), w, h)
end
-- the strips at rest at the telephoto field (reduced motion would also stop the zoom at 45 degrees, so take the swing out by hand)
local function atRest(k: number, w: number, h: number)
	local p = EyeOptics.profile(k, 10, false)
	p.sweepDeg, p.torsionDeg = 0, 0
	return EyeOptics.retinaStrips(0, p, w, h)
end
local still = atRest(0, 1920, 1080)
check(#still == 2 and near(still[1].x, 960 - 540 * tan(3), 1e-9) and near(still[2].x, 960 + 540 * tan(3), 1e-9) and still[1].y == 540 and still[2].y == 540, "side eyes, at rest: 3 degrees either side of the middle (540 x tan 3 px at a 90 degree field and 1080 px high)")
check(still[1].rotation == -10 and still[2].rotation == 10, "tilted into a V: the left strip leans out to the left at the top, the right one to the right")
check(near(still[1].w, 1080 * tan(2.5), 1e-9) and near(still[1].h, 1080 * tan(10), 1e-9) and still[1].w == still[2].w and still[1].h == still[2].h, "the side eyes' strips are 5 x 20 degrees on a 90 degree field")
local tele = atRest(1, 1920, 1080)
check(near(tele[1].w, 1080 * tan(2.5) / tan(12), 1e-9) and near(tele[1].h, 1080 * tan(10) / tan(12), 1e-9), "the principal eyes' strips fill most of the screen's height at a 24 degree field")
check(near(tele[1].h / 1080, tan(10) / tan(12), 1e-12) and tele[1].h < 1080, "a 20 degree strip is tan(10) / tan(12) of the screen's height at 24 degrees, and fits")
check(near(tele[1].x, 960 - 540 * tan(3) / tan(12), 1e-9) and near(tele[2].x, 960 + 540 * tan(3) / tan(12), 1e-9), "and sits 3 degrees off the middle, tangent-correct")
check(near((tele[1].x + tele[2].x) / 2, 960, 1e-9) and near(tele[1].x + tele[2].x, 1920, 1e-9), "symmetrical about the middle")
local gap = (tele[2].x - tele[2].w / 2) - (tele[1].x + tele[1].w / 2)
check(gap > 0, "the strips do not overlap, and the middle (the reticle) is between them")
local moving0 = strips(0.5, 0, 1920, 1080, false)
local moving1 = strips(0.5, 1, 1920, 1080, false)
check(math.abs(moving0[1].x - still[1].x) > 1 and math.abs(moving1[1].x - tele[1].x) < math.abs(moving0[1].x - still[1].x), "the side eyes sweep, the principal eyes only track")
local sweepMax0, sweepMax1, turnMax0, turnMax1 = 0, 0, 0, 0
for i = 0, 400 do
	local t = i * 0.025
	local a, b = strips(t, 0, 1920, 1080, false), strips(t, 1, 1920, 1080, false)
	sweepMax0 = math.max(sweepMax0, math.abs(math.atan((a[1].x - 960) / 540) - math.atan(-tan(3))))
	turnMax0 = math.max(turnMax0, math.abs(a[1].rotation + 10))
	turnMax1 = math.max(turnMax1, math.abs(b[1].rotation + 10))
	sweepMax1 = math.max(sweepMax1, math.abs((b[1].x - 960) / (540 / tan(12)) + tan(3)))
end
check(near(math.deg(sweepMax0), 4, 0.05) and near(turnMax0, 12, 0.01), `side eyes: sway up to 4 degrees, turn up to 12 ({math.deg(sweepMax0)}, {turnMax0})`)
check(near(turnMax1, 3, 0.01) and sweepMax1 < tan(3.7) - tan(3) + 1e-3 and sweepMax1 > 0.0, "principal eyes: turn up to 3 degrees, only a little sway")
local fits = true
for _, size in { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 844, 390 } } do
	for _, k in { 0, 0.5, 1 } do
		for i = 0, 200 do
			for _, s in strips(i * 0.05, k, size[1], size[2], false) do
				local a = rad(s.rotation)
				local hx = (s.w / 2) * math.abs(math.cos(a)) + (s.h / 2) * math.abs(math.sin(a))
				local hy = (s.w / 2) * math.abs(math.sin(a)) + (s.h / 2) * math.abs(math.cos(a))
				fits = fits and s.x - hx >= 0 and s.x + hx <= size[1] and s.y - hy >= 0 and s.y + hy <= size[2]
			end
		end
	end
end
check(fits, "the strips stay on the screen at every k and moment, on wide, tablet and phone screens")
check(reducedStill.sweepDeg == 0 and reducedStill.torsionDeg == 0, "a still profile")
local a1, a2 = strips(0, 0.7, 1280, 720, true), strips(3.3, 0.7, 1280, 720, true)
check(a1[1].x == a2[1].x and a1[2].x == a2[2].x and a1[1].rotation == a2[1].rotation and a1[2].rotation == a2[2].rotation, "with reduced motion the strips do not move at all")

local strip: EyeOptics.Strip = { x = 100, y = 100, w = 20, h = 80, rotation = 0 }
check(EyeOptics.insideStrip(100, 100, strip) and EyeOptics.insideStrip(100, 139, strip) and EyeOptics.insideStrip(109, 100, strip), "inside a strip: its middle, near its ends and edges")
check(not EyeOptics.insideStrip(100, 141, strip) and not EyeOptics.insideStrip(111, 100, strip) and not EyeOptics.insideStrip(0, 0, strip), "outside it: past its ends, its sides, far away")
check(not EyeOptics.insideStrip(108, 138, strip) and EyeOptics.insideStrip(100, 130, strip), "the ends are round: a corner of the box is outside")
local turned: EyeOptics.Strip = { x = 100, y = 100, w = 20, h = 80, rotation = 90 }
check(EyeOptics.insideStrip(135, 100, turned) and not EyeOptics.insideStrip(100, 135, turned) and not EyeOptics.insideStrip(145, 100, turned), "turned a quarter clockwise it lies along x")
local tilted: EyeOptics.Strip = { x = 100, y = 100, w = 20, h = 80, rotation = 45 }
check(EyeOptics.insideStrip(100 + 28, 100 - 28, tilted) and EyeOptics.insideStrip(100 - 28, 100 + 28, tilted) and not EyeOptics.insideStrip(100 + 28, 100 + 28, tilted), "turned 45 degrees clockwise (the top end goes to the right) its long axis runs from bottom-left to top-right")
check(EyeOptics.insideAnyStrip(100, 100, { turned, strip }) and not EyeOptics.insideAnyStrip(300, 300, { turned, strip }) and not EyeOptics.insideAnyStrip(1, 1, {}), "inside any of a list")

-- ---------------------------------------------------------------- the movement rings and arcs
check(EyeOptics.pulse(0, false) == 0 and near(EyeOptics.pulse(1 / 6, false), 1, 1e-12) and near(EyeOptics.pulse(1 / 3, false), 0, 1e-12), "the pulse goes 0 to 1 and back three times a second")
check(EyeOptics.pulse(0.123, true) == 0.5 and EyeOptics.pulse(9, true) == 0.5, "with reduced motion it holds steady")
local pulseOk = true
for i = 0, 100 do
	local v = EyeOptics.pulse(i * 0.0137, false)
	pulseOk = pulseOk and v >= 0 and v <= 1
end
check(pulseOk, "and stays in 0 to 1")
local base = EyeOptics.extentPx(3, 90, 720)
check(near(EyeOptics.ringDiameter(3, 90, 720, 0), base, 1e-9) and near(EyeOptics.ringDiameter(3, 90, 720, 1), base * 1.6, 1e-9) and near(EyeOptics.ringDiameter(3, 90, 720, 0.5), base * 1.3, 1e-9), "a ring pulses between 1.0 and 1.6 times its apparent size")
check(EyeOptics.ringDiameter(0.1, 90, 720, 0) == 14 and near(EyeOptics.ringDiameter(0.1, 90, 720, 1), 22.4, 1e-9), "never under 14 px at rest, 22.4 px at the top of the pulse")
check(EyeOptics.ringDiameter(3, 24, 720, 0) > 3 * EyeOptics.ringDiameter(3, 90, 720, 0) - 1e-6 or EyeOptics.ringDiameter(3, 90, 720, 0) <= 14, "the same thing looks bigger through the telephoto field")
check(near(EyeOptics.ringDiameter(4, 90, 720, 5), EyeOptics.ringDiameter(4, 90, 720, 1), 1e-12), "the pulse is kept in range")
check(EyeOptics.freshness(1000, 1000, 15) == 1 and near(EyeOptics.freshness(1015, 1000, 15), 0, 1e-12) and near(EyeOptics.freshness(1006, 1000, 15), 0.6, 1e-12) and EyeOptics.freshness(1100, 1000, 15) == 0, "a ring fades over the sensor's 15 tick hold")
check(Sensor.MOTION_HOLD_TICKS == 15 and near(EyeOptics.freshness(1000 + Sensor.MOTION_HOLD_TICKS, 1000, Sensor.MOTION_HOLD_TICKS), 0, 1e-12), "which is the hold the sensor keeps")
check(near(EyeOptics.ringAlpha(1, false), 0.9, 1e-12) and near(EyeOptics.ringAlpha(1, true), 0.27, 1e-12) and near(EyeOptics.ringAlpha(0.5, false), 0.45, 1e-12) and EyeOptics.ringAlpha(0, false) == 0, "ring opacity: fresh, a third of that inside a strip, gone when stale")
check(EyeOptics.arcAlpha(1, 1) == 0.85 and near(EyeOptics.arcAlpha(1, 0), 0.85 * 0.75, 1e-12) and EyeOptics.arcAlpha(0, 0.5) == 0, "an arc breathes a little and fades the same way")

local seen: { [string]: EyeOptics.Moving } = {}
for i = 1, 12 do seen["fly" .. i] = { direction = Vector3.new(0, 0, -1), distance = i, apparent = 1, tick = 100 + (i % 5) } end
local picked = EyeOptics.pickMovers(seen, 8)
local pickOk = #picked == 8
for i = 2, #picked do
	pickOk = pickOk and (picked[i - 1].tick > picked[i].tick or (picked[i - 1].tick == picked[i].tick and picked[i - 1].id < picked[i].id))
end
check(pickOk and picked[1].tick == 104, "at most 8, the freshest first, ties by id")
local again = EyeOptics.pickMovers(seen, 8)
local sameList = true
for i = 1, 8 do sameList = sameList and again[i].id == picked[i].id end
check(sameList and #EyeOptics.pickMovers({}, 8) == 0 and #EyeOptics.pickMovers(seen, 20) == 12, "the same record gives the same list; nothing in, nothing out")

check(EyeOptics.onScreen(0, 0, 1280, 720, 0) and EyeOptics.onScreen(1280, 720, 1280, 720, 0) and not EyeOptics.onScreen(-1, 10, 1280, 720, 0) and not EyeOptics.onScreen(10, 721, 1280, 720, 0) and EyeOptics.onScreen(-1, 10, 1280, 720, 5), "on the screen")
local function edge(cx: number, cy: number, w: number, h: number, inset: number): (number, number, number, number) return EyeOptics.edgeMark(cx, cy, w, h, inset) end
local ex, ey, edx, edy = edge(1, 0, 1280, 720, 34)
check(near(ex, 1280 - 34, 1e-9) and near(ey, 360, 1e-9) and edx == 1 and near(edy, 0, 1e-12), "straight right: the right edge, the middle, 34 px in")
ex, ey, edx, edy = edge(0, 1, 1280, 720, 34)
check(near(ex, 640, 1e-9) and near(ey, 34, 1e-9) and near(edx, 0, 1e-12) and edy == -1, "straight up: the top edge")
ex, ey, edx, edy = edge(-1, -1, 1280, 720, 20)
check(near(ey, 720 - 20, 1e-9) and ex < 640 and ex > 20 and near(edx, -math.sqrt(0.5), 1e-12) and near(edy, math.sqrt(0.5), 1e-12), "down and to the left: the bottom edge, left of the middle")
ex, ey, edx, edy = edge(0, 0, 1280, 720, 34)
check(near(ex, 640, 1e-9) and near(ey, 34, 1e-9) and edy == -1, "straight behind goes to the top, as the perception HUD's marks do")
local edgeOk = true
for i = 0, 71 do
	local a = i * math.pi / 36
	local x, y, dx, dy = edge(math.cos(a), math.sin(a), 1920, 1080, 20)
	edgeOk = edgeOk and x >= 20 - 1e-9 and x <= 1900 + 1e-9 and y >= 20 - 1e-9 and y <= 1060 + 1e-9 and near(dx * dx + dy * dy, 1, 1e-9)
	edgeOk = edgeOk and (near(x, 20, 1e-6) or near(x, 1900, 1e-6) or near(y, 20, 1e-6) or near(y, 1060, 1e-6))
end
check(edgeOk, "the edge point is always on the inset rectangle, with a unit direction")
-- the perception HUD's rule, written out as it is in Client/PerceptionHud (adapter.edge), must agree
local function hudEdge(d: Vector3, w: number, h: number): (number, number)
	local v = Vector2.new(d.X, -d.Y)
	if v.Magnitude < 0.03 then v = Vector2.new(0, -1) end
	v = v.Unit
	local half = Vector2.new(w * 0.5 - 34, h * 0.5 - 34)
	local t = math.min(half.X / math.max(math.abs(v.X), 1e-6), half.Y / math.max(math.abs(v.Y), 1e-6))
	return w * 0.5 + v.X * t, h * 0.5 + v.Y * t
end
local agree = true
for i = 0, 40 do
	local a = i * 0.17
	local d = Vector3.new(math.cos(a), math.sin(a * 1.3), 0.4)
	local hx, hy = hudEdge(d, 1280, 720)
	local ox, oy = edge(d.X, d.Y, 1280, 720, 34)
	agree = agree and near(hx, ox, 1e-9) and near(hy, oy, 1e-9)
end
check(agree, "the edge rule gives the perception HUD's own points at its inset")
local segs = EyeOptics.arcSegments(1246, 360, 1, 0)
check(#segs == 5 and near(segs[3].x, 1246, 1e-9) and near(segs[3].y, 360, 1e-9), "an arc is 5 short bars with the middle one at the edge point")
check(near(math.abs(segs[3].rotation), 90, 1e-9) and near(segs[1].y, 720 - segs[5].y, 1e-9) and near(segs[1].x, segs[5].x, 1e-9), "on the right edge the bars run up and down, and the arc is symmetrical")
check(segs[1].x < 1246 and segs[5].x < 1246 and segs[1].y < 360 and segs[5].y > 360, "it curves back toward the middle at both ends")
check(near((segs[2].x - segs[1].x) ^ 2 + (segs[2].y - segs[1].y) ^ 2, (56 * rad(8)) ^ 2, 0.5), "its bars are 8 degrees apart on a 56 px circle")
local top = EyeOptics.arcSegments(640, 20, 0, -1)
check(near(top[3].x, 640, 1e-9) and near(top[3].y, 20, 1e-9) and (near(top[3].rotation, 0, 1e-9) or near(math.abs(top[3].rotation), 180, 1e-9)), "on the top edge the middle bar lies along x")

-- ---------------------------------------------------------------- the vignette, the caption, the UV layer
check(EyeOptics.captionAlpha(-1) == 0 and EyeOptics.captionAlpha(0) == 0 and EyeOptics.captionAlpha(6) == 0 and EyeOptics.captionAlpha(7) == 0, "the caption is not there before it fades in or after 6 s")
check(EyeOptics.captionAlpha(0.4) == 1 and EyeOptics.captionAlpha(3) == 1 and EyeOptics.captionAlpha(4.5) == 1, "it holds at full opacity")
check(EyeOptics.captionAlpha(0.2) > 0 and EyeOptics.captionAlpha(0.2) < 1 and EyeOptics.captionAlpha(5.2) > 0 and EyeOptics.captionAlpha(5.2) < 1 and EyeOptics.captionAlpha(5.9) < EyeOptics.captionAlpha(5.2), "it fades in at the start and out toward 6 s")
check(EyeOptics.captionText("Right mouse", false) == "Spider-eye impression: a clear colour centre, muted edges that still catch movement.\nHold Right mouse for the principal eyes: narrow, sharp, telephoto, in green and ultraviolet (shown as violet).", "the caption, with the Focus key")
check(string.find(EyeOptics.captionText("LT", true), "Press LT for the principal eyes", 1, true) ~= nil and string.find(EyeOptics.captionText("", false), "Hold Focus for", 1, true) ~= nil, "a toggled Focus is pressed, not held; no key name falls back to Focus")
check(EyeOptics.uvTransparency(0, 0.8) == 1 and near(EyeOptics.uvTransparency(1, 0.8), 0.2, 1e-12) and near(EyeOptics.uvTransparency(0.5, 0.8), 0.6, 1e-12) and EyeOptics.uvTransparency(1, 0) == 1, "UV parts: 1 - k x UVOpacity")
check(EyeOptics.uvTransparency(2, 3) == 0 and EyeOptics.uvTransparency(-1, 1) == 1, "kept in 0 to 1")

-- ---------------------------------------------------------------- SpiderEyes under the shim
local Lighting = game:GetService("Lighting")
local camera = workspace.CurrentCamera
local VIEW_W, VIEW_H = camera.ViewportSize.X, camera.ViewportSize.Y

local function scene(): any
	local sc: any = {}
	sc.gui = Instance.new("Folder")
	sc.player = Instance.new("Player")
	camera.FieldOfView = 65
	camera.CFrame = CFrame.new(0, 5, 0)
	local cam: any = { eyeView = true, lookScale = 1 }
	function cam.aimRay(_self: any): (Vector3, Vector3)
		local cf = camera.CFrame
		return cf.Position, cf.LookVector
	end
	sc.cam = cam
	sc.sensor = { motionSeen = {}, lastEye = Vector3.new(0, 5, 0), core = { tick = 1000 } }
	sc.world = Instance.new("Folder")
	sc.world.Parent = workspace
	sc.params = RaycastParams.new()
	sc.params.FilterType = Enum.RaycastFilterType.Include
	sc.params.FilterDescendantsInstances = { sc.world }
	sc.eyes = SpiderEyes.new({ parent = sc.gui, camera = camera, player = sc.player, cam = cam, sensor = sc.sensor, params = sc.params })
	function sc.run(seconds: number, hz: number, focusing: boolean)
		for _ = 1, math.floor(seconds * hz + 0.5) do sc.eyes:update(1 / hz, focusing) end
	end
	function sc.finish()
		sc.eyes:destroy()
		sc.world:Destroy()
	end
	return sc
end
local function named(root: any, name: string): { any }
	local out = {}
	for _, d in root:GetDescendants() do if d.Name == name then table.insert(out, d) end end
	return out
end
local function shown(list: { any }): number
	local n = 0
	for _, d in list do if d.Visible then n += 1 end end
	return n
end
local function ringsOf(sc: any): { any } return named(sc.gui, "Ring") end
local function barsOf(sc: any): { any } return named(sc.gui, "ArcBar") end
local function wallAt(sc: any, z: number)
	local wall = Instance.new("Part")
	wall.Size = Vector3.new(40, 40, 0.5)
	wall.Position = Vector3.new(0, 5, z)
	wall.Anchored = true
	wall.Parent = sc.world
end

-- outside the eye view
do
	local sc = scene()
	sc.cam.eyeView = false
	sc.run(0.5, 60, true)
	local overlay = sc.gui:FindFirstChild("EyeOverlay")
	check(overlay ~= nil and overlay.Enabled == false and overlay.DisplayOrder < 0 and overlay.IgnoreGuiInset == true, "the overlay is made, off, under the HUD, and ignores the inset (its middle is the camera's middle)")
	check(sc.eyes.grade.Enabled == false and sc.eyes.blur.Enabled == false and sc.eyes.grade.Parent == Lighting and sc.eyes.blur.Parent == Lighting, "EyeGrade and EyeBlur are in Lighting and off")
	check(camera.FieldOfView == 65 and sc.cam.lookScale == 1, "outside the eye view the field of view and the look scale are not touched")
	check(shown(ringsOf(sc)) == 0 and sc.eyes:captionView("keyboard") == nil, "nothing is drawn and there is no caption")
	check(overlay ~= nil and #named(overlay, "Retina1") == 1 and #named(overlay, "Retina2") == 1, "the two retina strips exist")
	local edges = 0
	for _, d in overlay:GetDescendants() do if string.sub(d.Name, 1, 8) == "Vignette" then edges += 1 end end
	check(edges == 4, "and the four vignette edges")
	sc.finish()
end

-- in the eye view: the side eyes, then Focus
do
	local sc = scene()
	sc.run(1 / 60, 60, false)
	local overlay = sc.gui:FindFirstChild("EyeOverlay")
	check(camera.FieldOfView == 90 and overlay.Enabled == true and sc.eyes.grade.Enabled == true, "in the eye view: 90 degrees, the overlay and the grade on")
	local g = sc.eyes.grade
	check(g.Saturation == 0.15 and g.Contrast == 0.12 and g.Brightness == 0.03 and near(g.TintColor.R * 255, 115, 1e-6) and near(g.TintColor.G * 255, 255, 1e-6) and near(g.TintColor.B * 255, 236, 1e-6), "the side eyes' grade")
	check(sc.eyes.blur.Size == 0 and sc.eyes.blur.Enabled == false and near(sc.cam.lookScale, 1, 1e-9), "and blur, with the look scale 1")
	local r1, r2 = named(overlay, "Retina1")[1], named(overlay, "Retina2")[1]
	check(r1.Visible and r2.Visible and r1.Size.Y.Offset == r2.Size.Y.Offset and near(r1.Size.Y.Offset, VIEW_H * tan(10), 1e-6) and near(r1.Size.X.Offset, VIEW_H * tan(2.5), 1e-6), "the strips are 5 x 20 degrees on the 90 degree field")
	local rot1, rot2, samples = 0, 0, 156 -- one whole turn of 2.6 s at 60 Hz
	for _ = 1, samples do
		sc.eyes:update(1 / 60, false)
		rot1 += r1.Rotation
		rot2 += r2.Rotation
	end
	check(near(rot1 / samples, -10, 0.05) and near(rot2 / samples, 10, 0.05), `tilted into a V (10 degrees either way, on average over a turn: {rot1 / samples}, {rot2 / samples})`)
	local stroke = named(r1, "UIStroke")
	check(#stroke == 0 or stroke[1].Transparency == 0.82, "with a faint outline")
	local strokes = {}
	for _, d in r1:GetChildren() do if d.ClassName == "UIStroke" then table.insert(strokes, d) end end
	check(#strokes == 1 and strokes[1].Transparency == 0.82 and strokes[1].Thickness == 1.5, "the outline is a 1.5 px UIStroke at transparency 0.82")
	local gradient, corner = nil, nil
	for _, d in r1:GetChildren() do
		if d.ClassName == "UIGradient" then gradient = d elseif d.ClassName == "UICorner" then corner = d end
	end
	check(gradient ~= nil and corner ~= nil and corner.CornerRadius.Scale == 0.5, "a faint gradient fill and fully rounded ends")
	local top = named(overlay, "VignetteTop")[1]
	check(near(top.BackgroundTransparency, 0.35, 1e-12) and top.Size.Y.Scale == Eyes.vignette.topBottom, "the muted surround at 0.65 opacity")
	-- Focus in
	local fovs, falling = {}, true
	local previous = 90
	for _ = 1, 21 do
		sc.eyes:update(1 / 60, true)
		table.insert(fovs, camera.FieldOfView)
		falling = falling and camera.FieldOfView <= previous
		previous = camera.FieldOfView
	end
	check(falling and fovs[1] < 90 and fovs[10] > 24 and camera.FieldOfView == 24, "Focus: the field narrows steadily to 24 degrees in 0.35 s")
	check(g.Saturation == 0.15 and g.Contrast == 0.16 and g.Brightness == 0.02 and near(g.TintColor.R * 255, 115, 1e-6) and near(g.TintColor.B * 255, 236, 1e-6), "the principal eyes' grade")
	check(sc.eyes.blur.Size == 0 and sc.eyes.blur.Enabled == false, "no blur")
	check(near(sc.cam.lookScale, tan(12), 1e-9), "the look scale follows the zoom")
	local telephoto = named(overlay, "Retina1")[1]
	check(near(telephoto.Size.Y.Offset, VIEW_H * tan(10) / tan(12), 1e-6) and telephoto.Size.Y.Offset < VIEW_H, "the strips grow to tan(10) / tan(12) of the screen's height")
	local ts = {}
	for _, d in telephoto:GetChildren() do if d.ClassName == "UIStroke" then table.insert(ts, d) end end
	check(ts[1].Transparency == 0.68 and near(top.BackgroundTransparency, 0.25, 1e-12), "the outline and the vignette are stronger")
	-- release
	local rising = true
	previous = 24
	for _ = 1, 30 do
		sc.eyes:update(1 / 60, false)
		rising = rising and camera.FieldOfView >= previous
		previous = camera.FieldOfView
	end
	check(rising and camera.FieldOfView == 90 and g.Saturation == 0.15, "release: back to the side eyes in 0.5 s")
	-- leave
	sc.cam.eyeView = false
	camera.FieldOfView = 65 -- what SpiderCamera does
	sc.eyes:update(1 / 60, false)
	check(overlay.Enabled == false and g.Enabled == false and sc.eyes.blur.Enabled == false and sc.cam.lookScale == 1 and camera.FieldOfView == 65, "leaving: everything off, the look scale back to 1, the field of view not touched")
	sc.finish()
end

-- any frame rate gives the same picture
do
	local fovAt: { number } = {}
	for _, hz in { 30, 60, 120 } do
		local sc = scene()
		sc.run(0.2, hz, true)
		table.insert(fovAt, camera.FieldOfView)
		sc.finish()
	end
	check(near(fovAt[1], fovAt[2], 1e-9) and near(fovAt[2], fovAt[3], 1e-9) and fovAt[1] < 90 and fovAt[1] > 24, `the same field after 0.2 s at 30, 60 and 120 Hz ({fovAt[1]})`)
end

-- reduced motion
do
	local sc = scene()
	sc.player:SetAttribute("ReducedMotion", true)
	sc.run(1, 60, true)
	check(camera.FieldOfView == 45 and near(sc.cam.lookScale, tan(22.5), 1e-9), "reduced motion: the zoom stops at 45 degrees")
	local r1 = named(sc.gui, "Retina1")[1]
	local x0, rot0 = r1.Position.X.Offset, r1.Rotation
	sc.run(0.7, 60, true)
	check(r1.Position.X.Offset == x0 and r1.Rotation == rot0, "and the strips hold still")
	sc.player:SetAttribute("ReducedMotion", nil)
	sc.run(0.3, 60, true)
	check(camera.FieldOfView == 24, "without it the zoom goes all the way")
	sc.finish()
end

-- depth of field: this module owns it in the eye view and puts back what it borrowed
do
	local sc = scene()
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "MacroDOF"
	dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius, dof.FocusDistance = 0.2, 0.1, 9, 3
	dof.Parent = Lighting
	wallAt(sc, -8.5) -- the wall's near face is 8.25 from the camera
	sc.run(2, 60, false)
	check(dof.FarIntensity == 0.35 and dof.NearIntensity == 0.25 and near(dof.InFocusRadius, 6, 1e-9), "side eyes: loose focus, in focus within 6 studs")
	check(near(dof.FocusDistance, 8.25, 1e-3), `it focuses on what is looked at ({dof.FocusDistance})`)
	sc.run(1, 60, true)
	check(dof.FarIntensity == 0.75 and dof.NearIntensity == 0.6 and near(dof.InFocusRadius, 0.12 * 8.25, 1e-3), "principal eyes: tight, in focus within 0.12 of the distance")
	-- looking at the open: far
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(0, 5, 10))
	sc.run(2, 60, true)
	check(near(dof.FocusDistance, 40, 1e-3) and near(dof.InFocusRadius, 4.8, 1e-3), "looking at nothing: 40 studs")
	camera.CFrame = CFrame.new(0, 5, 0)
	sc.cam.eyeView = false
	sc.eyes:update(1 / 60, false)
	check(dof.FarIntensity == 0.2 and dof.NearIntensity == 0.1 and dof.InFocusRadius == 9, "leaving puts back the third person's depth of field")
	-- a world with no depth of field (the low tier, or off): nothing to do, nothing to break
	dof:Destroy()
	sc.cam.eyeView = true
	sc.run(0.3, 60, true)
	check(camera.FieldOfView < 90, "with no MacroDOF the rest still works")
	-- one that is switched off is left alone
	local off = Instance.new("DepthOfFieldEffect")
	off.Name = "MacroDOF"
	off.Enabled = false
	off.FarIntensity = 0.2
	off.Parent = Lighting
	sc.run(0.3, 60, true)
	check(off.FarIntensity == 0.2, "a depth of field that is off stays off and untouched")
	off:Destroy()
	sc.finish()
end

-- the UV layer
do
	local sc = scene()
	sc.run(0.5, 60, false) -- no folder yet: nothing happens
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = workspace
	local layer = Instance.new("Folder")
	layer.Name = "UVLayer"
	layer.Parent = decor
	local function petal(opacity: number?): any
		local p = Instance.new("Part")
		p.Transparency = 1
		if opacity then p:SetAttribute("UVOpacity", opacity) end
		p.Parent = layer
		return p
	end
	local a, b, c = petal(0.8), petal(0.5), petal(nil)
	sc.run(0.4, 60, false) -- the folder is looked up at most once a second: not found yet
	check(a.Transparency == 1 and b.Transparency == 1, "the folder is looked up lazily")
	sc.run(1, 60, false)
	check(a.Transparency == 1 and b.Transparency == 1 and c.Transparency == 1, "found: with the side eyes the layer is clear")
	sc.run(0.35, 60, true)
	check(near(a.Transparency, 0.2, 1e-9) and near(b.Transparency, 0.5, 1e-9) and c.Transparency == 1, "with the principal eyes each part shows as much as its UVOpacity; one without shows nothing")
	sc.run(0.1, 60, false)
	check(a.Transparency > 0.2 and a.Transparency < 1, "and it fades with k")
	sc.run(0.6, 60, false)
	check(a.Transparency == 1 and b.Transparency == 1, "back to clear")
	sc.run(0.35, 60, true)
	check(a.Transparency < 1, "shown again")
	sc.cam.eyeView = false
	sc.eyes:update(1 / 60, false)
	check(a.Transparency == 1 and b.Transparency == 1, "outside the eye view it is 1 again")
	sc.finish()
	decor:Destroy()
end

-- the lateral eyes' movement rings
do
	local sc = scene()
	sc.player:SetAttribute("ReducedMotion", true) -- still strips, a steady pulse: positions can be asserted
	local function aim(px: number, py: number, distance: number): Vector3
		-- the direction that lands at screen pixel (px, py) on the 90 degree field, from the eye straight ahead
		return Vector3.new((px - VIEW_W / 2) / (VIEW_H / 2), -(py - VIEW_H / 2) / (VIEW_H / 2), -1).Unit * 1 * (distance / distance)
	end
	local function mover(px: number, py: number, distance: number, apparent: number, tick: number): any
		return { direction = aim(px, py, distance), distance = distance, apparent = apparent, tick = tick }
	end
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0 and shown(barsOf(sc)) == 0, "nothing moving in sight: nothing drawn (and a fly the sensor did not find is not a mover)")
	-- a ring out in the open
	sc.sensor.motionSeen = { fly = mover(900, 200, 6, 3, 1000) }
	sc.eyes:update(1 / 60, false)
	local rings = ringsOf(sc)
	check(shown(rings) == 1 and shown(barsOf(sc)) == 0, "one mover on screen: one ring")
	local ring = rings[1]
	check(near(ring.Position.X.Offset, 900, 0.01) and near(ring.Position.Y.Offset, 200, 0.01), `the ring is where the thing is on screen ({ring.Position.X.Offset}, {ring.Position.Y.Offset})`)
	local diameter = EyeOptics.ringDiameter(3, 90, VIEW_H, 0.5)
	check(near(ring.Size.X.Offset, diameter, 1e-6) and ring.Size.X.Offset == ring.Size.Y.Offset and ring.Size.X.Offset >= 14, "sized by its apparent size, steady with reduced motion")
	local strokes = {}
	for _, d in ring:GetChildren() do if d.ClassName == "UIStroke" then table.insert(strokes, d) end end
	check(#strokes == 1 and near(strokes[1].Transparency, 1 - 0.9, 1e-9) and strokes[1].Thickness == 2, "a 2 px ring at 0.9 opacity when fresh")
	local shadow = ring:FindFirstChild("RingShadow")
	check(shadow ~= nil and shadow.Size.X.Offset == 4 and shadow.Size.X.Scale == 1, "with a dark ring just outside it")
	-- fading with age
	sc.sensor.core.tick = 1006
	sc.eyes:update(1 / 60, false)
	check(near(strokes[1].Transparency, 1 - 0.9 * (1 - 6 / 15), 1e-9), "six ticks on: fading")
	sc.sensor.core.tick = 1015
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0, "after the 15 tick hold: gone")
	sc.sensor.core.tick = 1000
	-- inside a retina strip: a third as strong
	local r1 = named(sc.gui, "Retina1")[1]
	sc.sensor.motionSeen = { fly = mover(r1.Position.X.Offset, r1.Position.Y.Offset, 5, 3, 1000) }
	sc.eyes:update(1 / 60, false)
	local inRing = ringsOf(sc)[1]
	local inStrokes = {}
	for _, d in inRing:GetChildren() do if d.ClassName == "UIStroke" then table.insert(inStrokes, d) end end
	check(near(inStrokes[1].Transparency, 1 - 0.9 * 0.3, 1e-9), "inside a retina strip the ring is 0.3 times as strong")
	-- behind: an arc at the edge, no ring
	sc.sensor.motionSeen = { fly = { direction = Vector3.new(1, 0, 0.3).Unit, distance = 5, apparent = 2, tick = 1000 } }
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0 and shown(barsOf(sc)) == 5, "off screen (to the right, behind the line of the screen): no ring, an arc of five bars")
	local mid = barsOf(sc)[3]
	check(near(mid.Position.X.Offset, VIEW_W - 20, 1.5) and near(mid.Position.Y.Offset, VIEW_H / 2, 1.5), "at the right edge, in the direction of the thing")
	sc.sensor.motionSeen = { fly = { direction = Vector3.new(0, 0, 1), distance = 5, apparent = 2, tick = 1000 } }
	sc.eyes:update(1 / 60, false)
	local behind = barsOf(sc)[3]
	check(shown(barsOf(sc)) == 5 and near(behind.Position.Y.Offset, 20, 1.5), "straight behind: at the top")
	-- the arc comes back to a ring when it comes into view, and clears when it goes
	sc.sensor.motionSeen = { fly = mover(300, 500, 4, 2, 1000) }
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 1 and shown(barsOf(sc)) == 0, "back in view: a ring and no arc")
	sc.sensor.motionSeen = {}
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0 and shown(barsOf(sc)) == 0, "no longer found moving: nothing drawn")
	-- many: at most eight
	local crowd = {}
	for i = 1, 12 do crowd["m" .. i] = mover(100 + i * 60, 300, 5, 2, 1000 - (i % 4)) end
	sc.sensor.motionSeen = crowd
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 8, "twelve movers: eight rings")
	-- only motionSeen is read: a world full of flies changes nothing
	sc.sensor.motionSeen = {}
	local fly = Instance.new("Part")
	fly.Name = "Fly"
	fly.Position = Vector3.new(0, 5, -3)
	fly.Parent = workspace
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0 and shown(barsOf(sc)) == 0, "a fly in the world that the sensor did not find moving is never drawn")
	fly:Destroy()
	-- leaving hides it all
	sc.sensor.motionSeen = crowd
	sc.eyes:update(1 / 60, false)
	sc.cam.eyeView = false
	sc.eyes:update(1 / 60, false)
	check(shown(ringsOf(sc)) == 0 and shown(barsOf(sc)) == 0, "outside the eye view no ring is shown")
	sc.finish()
end

-- the pulse and the telephoto field
do
	local sc = scene()
	sc.sensor.motionSeen = { fly = { direction = Vector3.new(0.3, 0.1, -1).Unit, distance = 6, apparent = 3, tick = 1000 } }
	local smallest, largest = math.huge, 0
	for _ = 1, 40 do
		sc.eyes:update(1 / 120, false)
		local ring = ringsOf(sc)[1]
		smallest, largest = math.min(smallest, ring.Size.X.Offset), math.max(largest, ring.Size.X.Offset)
	end
	local base3 = EyeOptics.extentPx(3, 90, VIEW_H)
	check(near(smallest, base3, base3 * 0.02) and near(largest, base3 * 1.6, base3 * 0.02), `the ring pulses between 1.0 and 1.6 times its size ({smallest}, {largest})`)
	sc.run(0.35, 60, true)
	local ring = ringsOf(sc)[1]
	check(ring ~= nil and ring.Visible, "and is still drawn through the telephoto field when the thing is in view")
	sc.finish()
end

-- the caption
do
	local sc = scene()
	sc.cam.eyeView = false
	sc.run(0.5, 60, false)
	check(sc.eyes:captionView("keyboard") == nil, "no caption outside the eye view")
	sc.cam.eyeView = true
	sc.run(1, 60, false)
	local c = sc.eyes:captionView("keyboard")
	check(c ~= nil and c.alpha == 1 and string.find(c.text, "Spider-eye impression: a clear colour centre, muted edges that still catch movement.", 1, true) ~= nil and string.find(c.text, "Hold Right mouse for the principal eyes", 1, true) ~= nil, "the first time: both lines, the key of the device")
	check(string.find(sc.eyes:captionView("gamepad").text, "Hold LT for", 1, true) ~= nil and string.find(sc.eyes:captionView("touch").text, "Hold Focus for", 1, true) ~= nil, "and the controller's and the screen's own words")
	sc.player:SetAttribute("FocusToggle", true)
	check(string.find(sc.eyes:captionView("keyboard").text, "Press Right mouse for", 1, true) ~= nil, "a toggled Focus is pressed")
	sc.player:SetAttribute("FocusToggle", nil)
	-- leaving pauses it
	sc.cam.eyeView = false
	sc.run(10, 60, false)
	sc.cam.eyeView = true
	sc.run(1, 60, false)
	check(sc.eyes:captionView("keyboard") ~= nil, "time outside the eye view does not use it up")
	sc.run(3.2, 60, false) -- 2 s used so far, so 5.2 of the 6
	local fading = sc.eyes:captionView("keyboard")
	check(fading ~= nil and fading.alpha < 1 and fading.alpha > 0, "it fades toward the end")
	sc.run(1.5, 60, false)
	check(sc.eyes:captionView("keyboard") == nil, "after 6 seconds of the eye view it is gone")
	sc.cam.eyeView = false
	sc.run(0.5, 60, false)
	sc.cam.eyeView = true
	sc.run(0.5, 60, false)
	check(sc.eyes:captionView("keyboard") == nil, "and does not come back")
	local fresh = scene()
	fresh.run(0.2, 60, false)
	local early = fresh.eyes:captionView("keyboard")
	check(early ~= nil and early.alpha < 1, "it fades in")
	fresh.finish()
	sc.finish()
end

-- destroy puts everything away
do
	local before = #Lighting:GetChildren()
	local sc = scene()
	sc.run(0.5, 60, true)
	sc.finish()
	check(#Lighting:GetChildren() == before and sc.gui:FindFirstChild("EyeOverlay") == nil, "destroying removes the effects and the overlay")
end

-- ---------------------------------------------------------------- SpiderCamera's look scale
do
	local world = BoxWorld.folder("EyesFloor", { { name = "floor", lo = Vector3.new(-5, -1, -5), hi = Vector3.new(5, 0, 5), profile = "wood" } })
	local cam2 = Instance.new("Camera")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	local sc = SpiderCamera.new(cam2, params, function()
		return { pos = Vector3.new(0, 0.3, 0), drawnUp = Vector3.yAxis, heading = Vector3.new(0, 0, -1) }
	end, function(_on: boolean) end) :: any
	sc.mouse = false
	check(sc.lookScale == 1, "a camera starts with a look scale of 1")
	sc:setEyeView(true)
	local g0 = sc.gaze
	sc:look(10, 0)
	local full = math.acos(math.clamp(g0:Dot(sc.gaze), -1, 1))
	sc.gaze = g0
	sc.lookScale = EyeOptics.lookScale(24)
	sc:look(10, 0)
	local scaled = math.acos(math.clamp(g0:Dot(sc.gaze), -1, 1))
	check(near(math.deg(full), 10, 1e-6) and near(math.deg(scaled), 10 * tan(12), 1e-6), `in the eye view a turn of the look is scaled ({math.deg(full)} and {math.deg(scaled)} degrees)`)
	sc.gaze = g0
	sc:look(0, 10)
	local down = math.acos(math.clamp(g0:Dot(sc.gaze), -1, 1))
	check(near(math.deg(down), 10 * tan(12), 1e-6), "up and down too")
	sc:setEyeView(false)
	local yaw0 = sc.yaw
	sc:look(10, 0)
	check(near(sc.yaw - yaw0, -rad(10), 1e-9), "the orbit view is not scaled")
	world:Destroy()
	cam2:Destroy()
end

-- ---------------------------------------------------------------- the real client
do
	local pieces = {}
	for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
	BoxWorld.folder("Windowsill", pieces)
	local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
	if not loaded then print("LOAD ERROR", loadError) end
	local stubs = ClientStubs
	local frame = stubs.renderSteps.SpiderSim
	local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
	local KEYS = { Eye = "V", Focus = "ButtonL2" }
	local function key(action: string, down: boolean)
		local fn = stubs.actions["Spider" .. action]
		assert(fn, "no binding for " .. action)
		fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
			{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	end
	local function find(screen: string, name: string): any
		local g = gui:FindFirstChild(screen)
		for _, d in g:GetDescendants() do if d.Name == name then return d end end
		return nil
	end
	local cam: any = workspace.CurrentCamera
	check(loaded, "the client loads with SpiderEyes in it")
	frames(60)
	local overlay = gui:FindFirstChild("EyeOverlay")
	check(overlay ~= nil and overlay.Enabled == false and cam.FieldOfView == 65 and not find("SpiderPrompts", "Caption").Visible, "third person: no overlay, the usual field of view, no caption")
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "MacroDOF"
	dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius, dof.FocusDistance = 0.55, 0.35, 3.5, -1
	dof.Parent = Lighting
	frames(2)
	local spiderModel = workspace:FindFirstChild("Spider")
	local root = spiderModel:FindFirstChild("Root")
	local thirdPersonFocus = (cam.CFrame.Position - root.Position).Magnitude
	check(near(dof.FocusDistance, thirdPersonFocus, 0.5) and dof.FocusDistance > 1 and dof.FarIntensity == 0.55, `third person: the depth of field is on the spider ({dof.FocusDistance})`)
	key("Eye", true); key("Eye", false); frames(5)
	overlay = gui:FindFirstChild("EyeOverlay")
	check(overlay.Enabled == true and cam.FieldOfView == 90, "V: the overlay is on and the field is 90 degrees")
	local caption = find("SpiderPrompts", "Caption")
	local status = find("SpiderPrompts", "Status")
	check(caption.Visible and string.find(caption.Text, "Spider-eye impression: a clear colour centre", 1, true) ~= nil and string.find(caption.Text, "Hold Right mouse for the principal eyes", 1, true) ~= nil, "the caption shows in the top column")
	check(caption.LayoutOrder > status.LayoutOrder and caption.LayoutOrder < find("SpiderPrompts", "Toast").LayoutOrder and caption.Parent == status.Parent, "right under the status lines, before the toast and the controls card")
	check(dof.FarIntensity == 0.35 and dof.NearIntensity == 0.25, "the eye view owns the depth of field")
	local seenByEyes = dof.FocusDistance
	check(seenByEyes > 0 and seenByEyes <= 40 and seenByEyes ~= thirdPersonFocus, `and focuses on what is looked at, not on the spider ({seenByEyes})`)
	frames(5)
	check(near(dof.FocusDistance, seenByEyes, 3), "the third person's code does not take it back")
	key("Focus", true); frames(25)
	check(cam.FieldOfView == 24 and find("SpiderHud", "Reticle").Visible == true, "Focus held: the telephoto field")
	check(overlay.Enabled and (gui:FindFirstChild("PerceptionHud").DisplayOrder or 0) > overlay.DisplayOrder and (gui:FindFirstChild("SpiderHud").DisplayOrder or 0) > overlay.DisplayOrder, "the overlay is under the HUD and the perception HUD")
	check(dof.FarIntensity == 0.75 and dof.NearIntensity == 0.6, "with the tight depth of field")
	key("Focus", false); frames(35)
	check(cam.FieldOfView == 90, "Focus released: the side eyes again")
	frames(400)
	check(not find("SpiderPrompts", "Caption").Visible, "the caption is gone after its 6 seconds")
	key("Eye", true); key("Eye", false); frames(3)
	check(overlay.Enabled == false and cam.FieldOfView == 65 and dof.FarIntensity == 0.55 and dof.NearIntensity == 0.35 and dof.InFocusRadius == 3.5, "V again: third person, the overlay off and the depth of field put back")
	frames(2)
	check(near(dof.FocusDistance, (cam.CFrame.Position - root.Position).Magnitude, 0.5), "and the depth of field is on the spider again")
	key("Eye", true); key("Eye", false); frames(3)
	check(not find("SpiderPrompts", "Caption").Visible, "the caption does not come back")
	local lighting = game:GetService("Lighting")
	check(lighting:FindFirstChild("EyeGrade") ~= nil and lighting:FindFirstChild("EyeBlur") ~= nil, "the grade and blur live in Lighting")
	key("Eye", true); key("Eye", false); frames(2)
end

print(`EYES passed={passed} failed={failed}`)
if failed > 0 then error("eyes checks failed") end
