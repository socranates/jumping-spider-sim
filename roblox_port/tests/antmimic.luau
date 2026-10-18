-- Ant-mimic checks (ROBLOX-54): the documented numbers are Shamble, Hoy, Cohen & Beatus 2017 (Proc. R. Soc. B 284: 20170308), the
-- legs-I antennae go up and wave in phase when the spider stands, the drawn walk follows the distance walked on a sine of ten body
-- lengths, a stop shorter than the mimic's mean stop is not drawn as a pause, slow motion and frame rate change nothing but speed,
-- ReducedMotion halves the wobble and stops the waving. Pure Luau: this says nothing about how Roblox draws the pose (tests/look.luau
-- checks the drawn spider; Studio is the judge of the look).
local AntMimic = require("../src/Shared/Data/AntMimic")
local Pose = require("../src/Shared/Rig/AntMimicPose")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL antmimic: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

-- ---------------------------------------------------------------- the data
check(AntMimic.id == "myrmarachne_formicaria_female", "the appearance id")
check(string.find(AntMimic.citation, "Shamble, Hoy, Cohen & Beatus 2017", 1, true) ~= nil and string.find(AntMimic.citation, "284: 20170308", 1, true) ~= nil and string.find(AntMimic.citation, "10.1098/rspb.2017.0308", 1, true) ~= nil, "the citation is in the data, exactly")
check(AntMimic.stops.meanMs == 83.3 and AntMimic.stops.sdMs == 82.6, "the mimic's stops are 83.3 +- 82.6 ms")
check(AntMimic.stationaryShare.nonMimicSpider == 0.55 and AntMimic.stationaryShare.antLow == 0.05 and AntMimic.stationaryShare.antHigh == 0.10, "stationary about 55 % (S. scenicus) against 5 to 10 % (ants)")
check(AntMimic.path.wavelengthBodyLengths.min == 5 and AntMimic.path.wavelengthBodyLengths.max == 10 and AntMimic.path.wavelengthBodyLengths.used == 10 and AntMimic.path.amplitudeBodyLengths == 5, "the real path: wavelength 5 to 10 body lengths (ten used), amplitude about five")
check(AntMimic.playback.predator == "Phidippus audax" and AntMimic.playback.nonMimicVsAnt == 4.5 and AntMimic.playback.nonMimicVsMimic == 3.0, "the playback result: non-mimics attacked 4.5 times as often as ants and 3 times as often as mimics")
check(AntMimic.bodyLengthMm == 5 and AntMimic.bodyLengthStuds == 0.5 and AntMimic.walkingLegs == 8, "5 mm body (0.5 studs at 1 stud = 1 cm), eight walking legs")
check(AntMimic.walk.stopHoldSeconds == 0.0833, "a stop shorter than the mimic's mean stop is not drawn as a pause")
local a, w = AntMimic.antennae, AntMimic.walk
check(a.waveHz <= 3 and a.highWaveHz <= 3 and a.waveHz > 0 and a.highWaveHz > a.waveHz, "waving stays at or under 3 Hz (nothing flashes) and the display key waves faster")
check(a.waveAmount > 0 and a.waveAmount < a.highWaveAmount and a.highWaveAmount <= 1 and a.highRaise == 1, "the display key waves wider and lifts to the highest")
check(w.yawDeg > 0 and w.yawDeg <= 20 and w.lateralStuds > 0 and w.lateralStuds <= 0.06, "the drawn wobble is small (the real path cannot change)")
check(AntMimic.reducedMotion == 0.5, "reduced motion halves")
check(AntMimic.noticeSeconds > 0 and AntMimic.noticeSeconds <= 3, "the notebook waits a moment with the antennae up")

-- ---------------------------------------------------------------- standing: the antennae
local function new(reduced: boolean?): Pose.State
	local p = Pose.new()
	p.reduced = reduced == true
	return p
end
local function run(p: Pose.State, seconds: number, dt: number, standing: boolean, moving: boolean, speed: number?): Pose.Pose
	local out = Pose.NONE
	for _ = 1, math.floor(seconds / dt + 0.5) do out = p:step(dt, standing, moving, if moving then (speed or 6) * dt else 0) end
	return out
end
local p0 = new()
local rest = p0:step(1 / 60, true, false, 0)
check(rest.antennae == 0 and rest.wave == 0 and rest.yaw == 0 and rest.lateral == 0 and rest.walking == false, "no pose at first")
local early = run(p0, a.delaySeconds - 0.1, 1 / 60, true, false)
check(early.antennae == 0, "legs I stay down until the spider has kept still a moment")
local mid = run(p0, 0.2, 1 / 60, true, false)
check(mid.antennae > 0 and mid.antennae < 1, "then they rise")
local up = run(p0, 0.6, 1 / 60, true, false)
check(up.antennae > 0.999 and up.walking == false, "and settle all the way up")
check(up.shownSeconds > 0.3, "the pose counts how long the antennae have been up")

-- The wave: both legs share one value, and it runs at the artistic rate.
local STEP = 1 / 240
local function wavesPerSecond(p: Pose.State, seconds: number, mid: number): number
	local n, prev = 0, nil :: number?
	for _ = 1, math.floor(seconds / STEP) do
		local v = p:step(STEP, true, false, 0).wave - mid
		if prev ~= nil and prev < 0 and v >= 0 then n += 1 end
		prev = v
	end
	return n / seconds
end
local settled = new()
run(settled, 1.0, 1 / 60, true, false)
check(near(wavesPerSecond(settled, 6, a.waveAmount * 0.5), a.waveHz, 0.2), `the antennae wave at {a.waveHz} Hz resting`)
local lo, hi = 1, 0
local tmp = new()
run(tmp, 1.0, 1 / 60, true, false)
for _ = 1, 480 do local v = tmp:step(STEP, true, false, 0).wave; lo, hi = math.min(lo, v), math.max(hi, v) end
check(near(hi, a.waveAmount, 0.02) and lo >= 0 and lo < 0.02, `a wave covers {a.waveAmount} of the way (0..{string.format("%.2f", hi)})`)

-- The display key: up at once, higher, faster and wider; refused unless standing still; any move ends it.
local d = new()
check(not d:start(false, false) and not d:start(true, true) and not d:displaying(), "the display key is refused in the air and while walking")
check(d:start(true, false) and d:displaying() and not d:start(true, false), "it starts once, standing still")
local quick = run(d, a.riseSeconds + 0.02, 1 / 60, true, false)
check(quick.antennae > 0.999 and quick.high > 0.99, "with the display key the legs are up and high within the rise time, with no wait")
check(near(wavesPerSecond(d, 6, 0.5 * a.highWaveAmount), a.highWaveHz, 0.3), `and wave at {a.highWaveHz} Hz`)
local loHigh, hiHigh = 1, 0
for _ = 1, 480 do local v = d:step(STEP, true, false, 0).wave; loHigh, hiHigh = math.min(loHigh, v), math.max(hiHigh, v) end
check(hiHigh > 0.98 and hiHigh > hi + 0.3, "and wider")
d:step(1 / 60, true, true, 0.1)
check(not d:displaying(), "walking ends the display pose at once")
local e = new()
e:start(true, false)
run(e, 1, 1 / 60, true, false)
e:step(1 / 60, false, false, 0)
check(not e:displaying(), "leaving the surface ends it")
local f = new()
f:start(true, false)
f:stop()
check(not f:displaying(), "stop() ends it")

-- Walking or leaving the surface brings the legs down fast and never back by themselves.
local g = new()
run(g, 1.2, 1 / 60, true, false)
local frames, gone, mono, last = 0, -1, true, 1
for i = 1, 20 do
	local q = g:step(1 / 60, true, true, 0.1)
	mono = mono and q.antennae <= last + 1e-12
	last = q.antennae
	if gone < 0 and q.antennae == 0 then gone = i end
end
check(mono and gone >= 6 and gone <= 9, `the legs come down over {a.fallSeconds} s of walking (frame {gone})`)
local air = new()
run(air, 1.2, 1 / 60, true, false)
local airLast = run(air, 0.5, 1 / 60, false, false)
check(airLast.antennae == 0 and airLast.wave == 0 and airLast.yaw == 0 and airLast.walking == false, "in the air there is no pose")

-- ---------------------------------------------------------------- walking: a sine of the distance walked
local bodyLength = AntMimic.bodyLengthStuds
local wavelength = AntMimic.path.wavelengthBodyLengths.used * bodyLength
check(near(wavelength, 5.0, 1e-9), "ten body lengths of 0.5 studs: a wavelength of 5 studs")
local walkP = new()
run(walkP, 1.0, 1 / 60, true, true) -- 6 studs: the wobble is fully in
local maxYaw, maxLat, crossings, prevYaw, distance = 0, 0, {}, nil :: number?, 6.0
local lastDistance = 0
for _ = 1, 600 do
	local q = walkP:step(1 / 60, true, true, 0.1)
	distance += 0.1
	maxYaw, maxLat = math.max(maxYaw, math.abs(q.yaw)), math.max(maxLat, math.abs(q.lateral))
	if prevYaw ~= nil and prevYaw * q.yaw < 0 then table.insert(crossings, distance) end
	prevYaw = q.yaw
end
check(near(maxYaw, math.rad(w.yawDeg), 1e-3) and near(maxLat, w.lateralStuds, 1e-3), `the drawn body turns {w.yawDeg} degrees and sways {w.lateralStuds} studs either side`)
local spacingOk = #crossings >= 20
for i = 2, #crossings do spacingOk = spacingOk and near(crossings[i] - crossings[i - 1], wavelength / 2, 0.11) end
check(spacingOk, `the yaw changes sign every half wavelength ({wavelength / 2} studs): {#crossings} crossings`)
-- The sway is a sine and the yaw its slope: the yaw is at its peak where the sway crosses the middle.
local peakOk, peakN = true, 0
local ph = new()
run(ph, 1.0, 1 / 60, true, true)
local pPrev, pPrev2 = ph:step(1 / 240, true, true, 0.01), ph:step(1 / 240, true, true, 0.01)
for _ = 1, 3000 do
	local q = ph:step(1 / 240, true, true, 0.01)
	if math.abs(pPrev.yaw) > math.abs(pPrev2.yaw) and math.abs(pPrev.yaw) >= math.abs(q.yaw) and math.abs(pPrev.yaw) > math.rad(w.yawDeg) * 0.99 then
		peakN += 1
		peakOk = peakOk and math.abs(pPrev.lateral) < w.lateralStuds * 0.05
	end
	pPrev2, pPrev = pPrev, q
end
check(peakOk and peakN >= 4, `the body points furthest off where the sway crosses the middle ({peakN} peaks)`)

-- Frame rate and slow motion: the pose is a function of the distance walked.
local function yawAfter(dt: number, speed: number, total: number): number
	local q = new()
	local out = Pose.NONE
	for _ = 1, math.floor(total / (speed * dt) + 0.5) do out = q:step(dt, true, true, speed * dt) end
	return out.yaw
end
local y60, y20, ySlow = yawAfter(1 / 60, 6, 12.0), yawAfter(1 / 20, 6, 12.0), yawAfter(1 / 60, 3, 12.0)
check(near(y60, y20, 1e-6) and near(y60, ySlow, 1e-6) and math.abs(y60) > 0.01, `60 and 20 steps a second, and half speed, give the same yaw at the same distance ({string.format("%.5f", y60)})`)
-- Growth makes the wavelength shorter with the body.
local small = new()
small.bodyLength = bodyLength * 0.5
run(small, 1.0, 1 / 60, true, true)
local sc, sprev, sd2 = {}, nil :: number?, 6.0
for _ = 1, 400 do
	local q = small:step(1 / 60, true, true, 0.1)
	sd2 += 0.1
	if sprev ~= nil and sprev * q.yaw < 0 then table.insert(sc, sd2) end
	sprev = q.yaw
end
check(#sc > 10 and near(sc[3] - sc[2], wavelength * 0.5 / 2, 0.11), "a smaller body has a shorter wavelength (ten of its own lengths)")
-- A respawn or a return is not a walk.
local tele, still = new(), new()
run(tele, 1.0, 1 / 60, true, true)
run(still, 1.0, 1 / 60, true, true)
local afterTele, afterStill = tele:step(1 / 60, true, true, 40), still:step(1 / 60, true, true, 0)
check(w.teleportStuds < 40 and near(afterTele.yaw, afterStill.yaw, 1e-12) and near(afterTele.lateral, afterStill.lateral, 1e-12), "a step of 40 studs in one frame moves no phase")

-- Smooth: no jump larger than a few degrees a frame at walking speed, in or out.
local smoothP = new()
local prev = smoothP:step(1 / 60, true, false, 0)
local worst = 0
local plan: { { number | boolean } } = { { 120, 0 }, { 90, 1 }, { 30, 0 }, { 60, 1 }, { 120, 0 } }
for _, seg in plan do
	for _ = 1, seg[1] :: number do
		local moving = seg[2] == 1
		local q = smoothP:step(1 / 60, true, moving, if moving then 0.1 else 0)
		worst = math.max(worst, math.abs(q.yaw - prev.yaw), math.abs(q.wave - prev.wave), math.abs(q.antennae - prev.antennae) * 0.25, math.abs(q.lateral - prev.lateral) * 4)
		prev = q
	end
end
check(worst < 0.15, `no jumps (largest step in 1/60 s: {string.format("%.4f", worst)})`)

-- ---------------------------------------------------------------- the short stops
-- A stop shorter than 83.3 ms is not drawn: the walk goes on and the legs stay down.
local tap = new()
run(tap, 1.0, 1 / 240, true, true)
local stayed, tapAntennae = true, 0
for _ = 1, 20 do -- 83 ms at 240 Hz is 19.9 steps: 20 steps is 83.3 ms; stop one step short
	local q = tap:step(1 / 240, true, false, 0)
	if _ < 20 then stayed = stayed and q.walking end
	tapAntennae = math.max(tapAntennae, q.antennae)
end
check(stayed and tapAntennae == 0, "a stop shorter than 83.3 ms is drawn as walking, legs I down")
local longer = new()
run(longer, 1.0, 1 / 240, true, true)
local flipped, flipAt = false, 0
for i = 1, 60 do
	local q = longer:step(1 / 240, true, false, 0)
	if not flipped and not q.walking then flipped, flipAt = true, i / 240 end
end
check(flipped and near(flipAt, AntMimic.walk.stopHoldSeconds, 0.01), `a longer stop is a pause from 83.3 ms on ({string.format("%.3f", flipAt)} s)`)
local pause = new()
run(pause, 1.0, 1 / 240, true, true)
local atDelay = run(pause, a.delaySeconds - 0.02, 1 / 240, true, false)
check(atDelay.antennae == 0, "but the legs wait for the antennae delay")
local afterDelay = run(pause, 0.08, 1 / 240, true, false)
check(afterDelay.antennae > 0, "and then rise")

-- A walker who stops for the mimic's own stop durations is drawn as paused for a few percent of the time, ants' 5 to 10 % and far under a
-- plain spider's 55 %: the paper's mean (83.3 ms) with a spread (40 quantiles of a lognormal with the paper's mean and sd).
local STOPS_MS = { 9.4, 13.8, 16.9, 19.6, 22.0, 24.4, 26.6, 28.9, 31.1, 33.3, 35.5, 37.8, 40.1, 42.5, 44.9, 47.5, 50.1, 52.8, 55.6, 58.6, 61.7, 65.0, 68.5, 72.2, 76.2, 80.5, 85.1, 90.1, 95.6, 101.8, 108.6, 116.4, 125.3, 135.8, 148.4, 164.1, 184.7, 214.0, 262.4, 384.3 }
local sum = 0
for _, ms in STOPS_MS do sum += ms end
check(near(sum / #STOPS_MS, AntMimic.stops.meanMs, 0.05), `the stop list has the paper's mean ({string.format("%.1f", sum / #STOPS_MS)} ms)`)
local walker = new()
local rawStill, drawnStill, total = 0, 0, 0
for _, ms in STOPS_MS do
	local dt = 1 / 1000
	for _ = 1, 600 do -- 0.6 s of walking
		local q = walker:step(dt, true, true, 6 * dt)
		total += dt
		if not q.walking then drawnStill += dt end
	end
	for _ = 1, math.floor(ms + 0.5) do
		local q = walker:step(dt, true, false, 0)
		total += dt
		rawStill += dt
		if not q.walking then drawnStill += dt end
	end
end
check(rawStill / total > 0.09 and drawnStill / total < rawStill / total * 0.5 and drawnStill / total <= AntMimic.stationaryShare.antHigh, `drawn paused {string.format("%.1f", drawnStill / total * 100)} % of the time against {string.format("%.1f", rawStill / total * 100)} % of real stillness (ants 5 to 10 %, a plain spider 55 %)`)

-- ---------------------------------------------------------------- reduced motion
local nPose, rPose = new(), new(true)
run(nPose, 1.0, 1 / 60, true, true)
run(rPose, 1.0, 1 / 60, true, true)
local ny, nl, ry, rl = 0, 0, 0, 0
for _ = 1, 600 do
	local qn, qr = nPose:step(1 / 60, true, true, 0.1), rPose:step(1 / 60, true, true, 0.1)
	ny, nl, ry, rl = math.max(ny, math.abs(qn.yaw)), math.max(nl, math.abs(qn.lateral)), math.max(ry, math.abs(qr.yaw)), math.max(rl, math.abs(qr.lateral))
end
check(near(ry / ny, 0.5, 0.01) and near(rl / nl, 0.5, 0.01), "reduced motion halves the yaw and the sway")
local rStand = new(true)
local rs = run(rStand, 1.5, 1 / 60, true, false)
local maxWave = 0
for _ = 1, 240 do maxWave = math.max(maxWave, rStand:step(1 / 60, true, false, 0).wave) end
check(rs.antennae > 0.999 and maxWave == 0, "reduced motion stops the waving; the legs still go up")

print(`ANTMIMIC passed={passed} failed={failed}`)
if failed > 0 then error("antmimic checks failed") end
