-- Living-motion checks (ROBLOX-87): the abdomen's breath, grooming's seeded schedule, the attention yaw and the eyes' glance, the alarm and a tarantula's
-- stretch. Part one steps the pure stepper (Rig/Living) alone: the bouts' times from a seeded stream over a minute, only while standing, cut short by a move,
-- the meal's cleaning, the alarm's timing, the yaw's limit and ease, Reduced Motion as no motion. Part two runs the real SpiderRig under the shim: the breath's
-- size and period (first spider 0.4 Hz, tarantulas 0.25 Hz), the planted feet, the root and the part counts untouched, the low tier still, the mate's and the
-- rival's rigs unharmed. Judged by eye in tools/preview (--cue, --focus, --idle); this says nothing about how Roblox draws it, and Studio has not seen it.
local Appearances = require("../src/Shared/Data/Appearances")
local Living = require("../src/Shared/Rig/Living")
local Idle = require("../src/Shared/Rig/Idle")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local SpiderRig = require("../src/Shared/Rig/SpiderRig")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL idle: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local DT = 1 / 60
local RED, BLUE = "brachypelma_hamorii", "chromatopelma_cyaneopubescens"
local first = Appearances.profiles.first_spider
local I = first.idle

-- ---------------------------------------------------------------- the knobs
local function knobChecks()
	check(I.breathe.period == 2.5 and I.breathe.scale >= 0.02 and I.breathe.scale <= 0.03 and I.breathe.movingShare < 0.5, "the first spider breathes at 0.4 Hz with a 2 to 3 percent pulse of the abdomen, less while it moves")
	check(I.groom.after == 4.0 and I.groom.gap[1] == 8 and I.groom.gap[2] == 20 and I.groom.strokes == 3 and I.groom.palpSeconds == 2.0 and I.groom.legSeconds == 2.5, "grooming: after 4 seconds of standing, a bout every 8 to 20 seconds, 3 strokes over 2 s, a leg 2.5 s")
	check(I.attention.maxDeg == 20 and I.attention.easeSeconds == 0.4 and I.attention.glance > 0, "attention: at most 20 degrees, eased over 0.4 s, and the eyes glance")
	check(I.alarm.seconds == 1.2, "the alarm lasts 1.2 seconds")
	local red, blue = Appearances.profiles[RED].idle, Appearances.profiles[BLUE].idle
	check(red.breathe.period == 4.0 and blue.breathe.period == 4.0 and red.breathe.period > I.breathe.period, "a tarantula breathes at 0.25 Hz")
	check(red.groom == nil and blue.groom == nil and red.attention == nil, "a tarantula never grooms and does not turn to what is watched")
	check(red.stretch ~= nil and red.stretch.seconds == 3.0 and red.stretch.gap[1] >= 8 and red.alarm ~= nil, "a tarantula stretches a leg over 3 seconds now and then, and keeps the alarm")
	check(Appearances.profiles.maratus_volans_male.idle.groom == nil and Appearances.profiles.maratus_volans_male.idle.breathe.scale == nil, "the peacock spider and the ant mimic neither groom nor pulse")
end
knobChecks()

-- ---------------------------------------------------------------- the stepper
local function drive(l: any, seconds: number, standing: boolean, focusYaw: number?, focusPitch: number?)
	local pose
	for _ = 1, math.floor(seconds * 60 + 0.5) do pose = Living.step(l, DT, standing, false, focusYaw, focusPitch, true) end
	return pose
end
local function scheduleChecks()
	local a, b, c = Living.new(I, 4242), Living.new(I, 4242), Living.new(I, 99)
	drive(a, 60, true); drive(b, 60, true); drive(c, 60, true)
	local same = #a.log == #b.log and #a.log > 0
	for i, e in a.log do same = same and b.log[i] ~= nil and e.t == b.log[i].t and e.kind == b.log[i].kind end
	check(same, `the same seed gives the same bouts over a minute ({#a.log} of them)`)
	local differs = #c.log ~= #a.log
	for i, e in a.log do differs = differs or (c.log[i] ~= nil and math.abs(c.log[i].t - e.t) > 0.01) end
	check(differs, "another seed gives another schedule")
	check(#a.log >= 3 and #a.log <= 6, `a minute of standing holds {#a.log} bouts (3 to 6)`)
	check(a.log[1].t >= I.groom.after - 1e-9 and a.log[1].t <= I.groom.after + I.groom.firstWait[2] + 0.1, `the first bout comes after the 4 seconds of standing ({string.format("%.2f", a.log[1].t)} s)`)
	-- the gaps between the end of one bout and the start of the next are 8 to 20 seconds
	local gapsOk, worstLow, worstHigh = true, math.huge, 0
	for i = 2, #a.log do
		local lengthOf = if a.log[i - 1].kind == "palp" then I.groom.palpSeconds else I.groom.legSeconds
		local gap = a.log[i].t - (a.log[i - 1].t + lengthOf)
		worstLow, worstHigh = math.min(worstLow, gap), math.max(worstHigh, gap)
		gapsOk = gapsOk and gap >= 8 - 0.1 and gap <= 20 + 0.1
	end
	check(gapsOk, `bouts are 8 to 20 seconds apart ({string.format("%.1f", worstLow)} to {string.format("%.1f", worstHigh)}), not a metronome`)
	-- both kinds happen over many seeds
	local kinds: { [string]: number } = {}
	for seed = 1, 20 do
		local l = Living.new(I, seed * 977)
		drive(l, 120, true)
		for _, e in l.log do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
	end
	check((kinds.palp or 0) > 10 and (kinds.leg or 0) > 10 and kinds.meal == nil and kinds.stretch == nil, `a palp bout and a leg bout both happen ({kinds.palp or 0}, {kinds.leg or 0})`)
	-- never while it does not stand still for long enough: stands of 3 seconds with a step between
	local d = Living.new(I, 4242)
	for _ = 1, 30 do drive(d, 3, true); drive(d, 0.2, false) end
	check(#d.log == 0, "no bout when it never stands still for 4 seconds")
	-- a bout is cut short by a move: it gives way within the abort time and is not begun again at once
	local e = Living.new(I, 4242)
	local began = 0.0
	for frame = 1, 60 * 30 do
		Living.step(e, DT, true, false, nil, nil, true)
		if e.bout ~= nil and e.weight > 0.9 then began = frame / 60; break end
	end
	check(began > 0 and e.bout ~= nil, "a bout begins")
	local pose = drive(e, 0.1, false)
	local fading = pose.bout ~= nil
	pose = drive(e, 0.3, false)
	local legsDown = true
	for _, leg in pose.legs do legsDown = legsDown and leg.w == 0 end
	check(fading and e.bout == nil and pose.palpYaw[1] == 0 and pose.palpYaw[2] == 0 and legsDown, "moving cuts a bout short within 0.3 seconds and puts everything down")
	local sinceEnd = #e.log
	drive(e, 5, true)
	check(#e.log == sinceEnd, "and the next one waits a fresh 8 to 20 seconds")
end
scheduleChecks()

local function mealChecks()
	local l = Living.new(I, 11)
	drive(l, 1.0, true)
	Living.cue(l, "groom")
	local order: { string } = {}
	local legOrder: { number } = {}
	local startedAt, endedAt = -1.0, -1.0
	for frame = 1, 60 * 20 do
		local pose = Living.step(l, DT, true, false, nil, nil, true)
		if pose.bout == "meal" then
			if startedAt < 0 then startedAt = frame / 60 end
			endedAt = frame / 60
			if order[#order] ~= pose.act then table.insert(order, pose.act :: string) end
			for index, leg in pose.legs do
				if leg.w > 0.9 and legOrder[#legOrder] ~= index then table.insert(legOrder, index) end
			end
		end
	end
	check(table.concat(order, ",") == "palps,leg" and table.concat(legOrder :: any, ",") == "1,5,2,6", `after a meal: both palps, then legs I and II ({table.concat(order, ",")}; legs {table.concat(legOrder :: any, ",")})`)
	check(near(startedAt, 0.5, 0.1), `the cleaning begins once it has stood still for 1.5 seconds ({string.format("%.2f", startedAt)} s after the cue, a second in)`)
	local length = endedAt - startedAt
	check(near(length, I.groom.mealPalpSeconds + 4 * I.groom.legSeconds, 0.4) and length > I.groom.legSeconds * 2, `the cleaning is longer than an ordinary bout ({string.format("%.1f", length)} s)`)
	local meals = 0
	for _, e in l.log do if e.kind == "meal" then meals += 1 end end
	check(meals == 1, "one meal is one cleaning")
	-- with no groom table (a tarantula) the cue does nothing
	local t = Living.new(Appearances.profiles[RED].idle, 5)
	Living.cue(t, "groom")
	drive(t, 3, true)
	check(t.pendingMeal == nil and #t.log == 0, "a tarantula ignores the cue to groom")
end
mealChecks()

local function alarmChecks()
	local l = Living.new(I, 7)
	drive(l, 1.0, true)
	Living.cue(l, "alarm")
	local upFrom, upTo, freezeFrom, freezeTo, peakLeg, peakFreeze = -1.0, -1.0, -1.0, -1.0, 0, 0
	for frame = 1, 60 * 3 do
		local pose = Living.step(l, DT, true, false, nil, nil, true)
		local t = frame / 60
		if pose.freeze > 0 then
			if freezeFrom < 0 then freezeFrom = t end
			freezeTo = t
		end
		if pose.legs[1].w > 0.5 then
			if upFrom < 0 then upFrom = t end
			upTo = t
		end
		peakLeg, peakFreeze = math.max(peakLeg, pose.legs[1].w), math.max(peakFreeze, pose.freeze)
		check(pose.legs[1].w == pose.legs[5].w and pose.legs[2].w == 0 and pose.legs[3].w == 0, "both legs I, no others, go up together")
	end
	check(peakLeg > 0.99 and peakFreeze > 0.99, "the alarm raises legs I fully and freezes fully")
	check(near(freezeTo - freezeFrom, I.alarm.seconds, 0.1) and freezeFrom < 0.1, `the freeze lasts 1.2 seconds, from the cue ({string.format("%.2f", freezeTo - freezeFrom)} s)`)
	check(upFrom > 0.05 and upFrom < 0.3 and upTo > 0.9 and upTo < 1.2, `legs I are up from {string.format("%.2f", upFrom)} to {string.format("%.2f", upTo)} s, then normal`)
	-- the alarm cuts a bout short; nothing is drawn raised when the legs are not free (airborne) or in Reduced Motion
	local g = Living.new(I, 13)
	local frames = 0
	while g.bout == nil and frames < 60 * 40 do Living.step(g, DT, true, false, nil, nil, true); frames += 1 end
	check(g.bout ~= nil, "a bout began")
	Living.cue(g, "alarm")
	drive(g, 0.5, true)
	check(g.bout == nil, "an alarm ends a grooming bout")
	local h = Living.new(I, 13)
	Living.cue(h, "alarm")
	local pose = Living.step(h, DT, true, false, nil, nil, false)
	pose = Living.step(h, 0.2, true, false, nil, nil, false)
	check(pose.freeze > 0 and pose.legs[1].w == 0, "legs that are not free stay as they are")
	local r = Living.new(I, 13)
	Living.cue(r, "alarm")
	pose = Living.step(r, 0.2, true, true, nil, nil, true)
	check(pose.freeze == 0 and pose.legs[1].w == 0 and r.alarmT == nil, "Reduced Motion: no alarm")
end
alarmChecks()

local function attentionChecks()
	local l = Living.new(I, 21)
	local limit = math.rad(I.attention.maxDeg)
	local worst = 0
	for deg = -180, 180, 15 do
		local m = Living.new(I, 21)
		local pose = drive(m, 2.0, true, math.rad(deg), 0)
		worst = math.max(worst, math.abs(pose.yaw))
		local want = math.clamp(math.rad(deg), -limit, limit)
		if deg ~= 0 then check(near(pose.yaw, want, math.rad(0.5)), `watching {deg} degrees away turns the body {string.format("%.1f", math.deg(pose.yaw))} degrees`) end
	end
	check(worst <= limit + 1e-9, "the body never turns more than 20 degrees")
	-- eased over 0.4 seconds: most of the way by then, not at once
	local pose = Living.step(l, DT, true, false, math.rad(60), 0, true)
	local first = pose.yaw
	pose = drive(l, 0.4, true, math.rad(60), 0)
	check(first < limit * 0.15 and pose.yaw > limit * 0.9 and pose.yaw <= limit, `the turn eases in over 0.4 seconds ({string.format("%.1f", math.deg(first))} degrees after a frame, {string.format("%.1f", math.deg(pose.yaw))} after 0.4 s)`)
	check(pose.glanceX < -0.9 and pose.glanceX >= -1, "and the eyes glance toward the point, as far as they go")
	-- a small angle is followed exactly (the body leaves the rest to the eyes)
	local s = Living.new(I, 21)
	pose = drive(s, 2, true, math.rad(8), math.rad(10))
	check(near(pose.yaw, math.rad(8), math.rad(0.2)) and math.abs(pose.glanceX) < 0.05 and pose.glanceY > 0.2, "a point 8 degrees off: the body turns all of it, the eyes only look up for what is above")
	-- back to the heading when it moves
	pose = drive(l, 1.2, false, math.rad(60), 0)
	check(math.abs(pose.yaw) < math.rad(0.5), "walking returns the body to the motor's heading")
	pose = drive(l, 1.0, true, math.rad(60), 0)
	pose = drive(l, 1.5, true, nil, nil)
	check(math.abs(pose.yaw) < math.rad(0.5) and math.abs(pose.glanceX) < 0.05, "and so does letting go of the focus")
	-- Reduced Motion
	local r = Living.new(I, 21)
	pose = Living.step(r, 1.0, true, true, math.rad(60), 0, true)
	check(pose.yaw == 0 and pose.glanceX == 0 and pose.glanceY == 0, "Reduced Motion: no turn and no glance")
	-- a tarantula does not turn
	local t = Living.new(Appearances.profiles[RED].idle, 21)
	pose = drive(t, 2, true, math.rad(60), 0)
	check(pose.yaw == 0 and pose.glanceX == 0, "a tarantula does not turn to what is watched")
end
attentionChecks()

local function stretchChecks()
	local l = Living.new(Appearances.profiles[RED].idle, 3)
	local st = Appearances.profiles[RED].idle.stretch
	local peak, ups, lastUp, rises = 0, 0, -1.0, {}
	local legsSeen: { [number]: boolean } = {}
	for frame = 1, 60 * 90 do
		local pose = Living.step(l, DT, true, false, nil, nil, true)
		for index, leg in pose.legs do
			if leg.w > 0 then
				peak = math.max(peak, leg.w)
				legsSeen[index] = true
				if lastUp < 0 or frame / 60 - lastUp > 1 then table.insert(rises, frame / 60) end
				lastUp = frame / 60
			end
		end
		check(pose.palpYaw[1] == 0 and pose.palpYaw[2] == 0 and pose.bout ~= "palp" and pose.bout ~= "leg" and pose.bout ~= "meal", "a tarantula's palps stay as they are: no grooming bursts")
	end
	check(#l.log >= 3 and #l.log <= 8, `a tarantula stretches {#l.log} times in 90 seconds`)
	local oneLeg = true
	for _, e in l.log do oneLeg = oneLeg and e.kind == "stretch" end
	check(oneLeg and peak > 0.99, "only stretches, each one reaching its full extent")
	local gapsOk = true
	for i = 2, #l.log do
		local gap = l.log[i].t - (l.log[i - 1].t + st.seconds)
		gapsOk = gapsOk and gap >= st.gap[1] - 0.1 and gap <= st.gap[2] + 0.1
	end
	check(gapsOk, "stretches are 10 to 24 seconds apart")
	-- one leg at a time, up and settled again within 3 seconds
	local m = Living.new(Appearances.profiles[RED].idle, 3)
	local live, longest, firstT = 0, 0.0, -1.0
	local start = -1.0
	for frame = 1, 60 * 30 do
		local pose = Living.step(m, DT, true, false, nil, nil, true)
		local up = 0
		for _, leg in pose.legs do if leg.w > 0 then up += 1 end end
		live = math.max(live, up)
		if up > 0 and start < 0 then start = frame / 60 end
		if up == 0 and start >= 0 then longest = math.max(longest, frame / 60 - start); firstT = firstT < 0 and start or firstT; start = -1.0 end
	end
	check(live == 1 and longest > 2.5 and longest <= st.seconds + 0.05, `one leg reaches out and settles over 3 seconds ({string.format("%.2f", longest)} s)`)
end
stretchChecks()

-- ---------------------------------------------------------------- the real rig
local floor = BoxWorld.folder("IdleFloor", { { name = "floor", lo = Vector3.new(-5, -1, -5), hi = Vector3.new(5, 0, 5), profile = "painted_wood_dry" } })
local body = SupportMath.bodyCFrame(Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(0, 0, -1))
local function build(id: string?, detail: string): any return SpiderRig.new(floor, floor, id, detail) end
local function part(r: any, name: string): BasePart return r.model:FindFirstChild(name) :: BasePart end
local function stand(r: any, seconds: number, moving: boolean?, each: ((number) -> ())?)
	for frame = 1, math.floor(seconds * 60 + 0.5) do
		r:update(body, DT, true, moving or false)
		if each then each(frame) end
	end
end
local function snapshot(r: any): { Vector3 }
	local out = {}
	for _, p in r.model:GetChildren() do if p:IsA("BasePart") then table.insert(out, p.Position) end end
	return out
end
local function moved(a: { Vector3 }, b: { Vector3 }): number
	local most = 0
	for i, v in a do most = math.max(most, (v - b[i]).Magnitude) end
	return most
end
local function median(list: { number }): number
	table.sort(list)
	return list[(#list + 1) // 2]
end

-- the abdomen's breath: its size over twenty seconds
local function breath(r: any, seconds: number, moving: boolean): (number, number, number) -- amplitude as a share of the mean, the mean period, crossings
	local abdomen = part(r, "Abdomen")
	local sizes: { number } = {}
	stand(r, 1.0, moving) -- (the breath ramps in)
	stand(r, seconds, moving, function() table.insert(sizes, abdomen.Size.X) end)
	local lo, hi, sum = math.huge, -math.huge, 0
	for _, v in sizes do lo, hi, sum = math.min(lo, v), math.max(hi, v), sum + v end
	local mean = sum / #sizes
	local ups: { number } = {}
	for i = 2, #sizes do
		if sizes[i - 1] < mean and sizes[i] >= mean then table.insert(ups, i / 60) end
	end
	local period = if #ups >= 2 then (ups[#ups] - ups[1]) / (#ups - 1) else 0
	return (hi - lo) / 2 / mean, period, #ups
end
local function breathChecks()
	local f = build(nil, "full")
	local amp, period = breath(f, 16, false)
	check(amp >= 0.020 and amp <= 0.0255, `the first spider's abdomen pulses by {string.format("%.2f", amp * 100)} percent`)
	check(near(period, 2.5, 0.1), `at 0.4 Hz: a breath every {string.format("%.2f", period)} s`)
	-- the shells and the hairs breathe with it: the shell is resized, a hair's place moves in and out with the abdomen
	local shells, hairMoved = 0, 0
	local before = {}
	for _, p in f.model:GetChildren() do
		if p.Name == "FuzzShell" then shells += 1 end
	end
	check(shells >= 4, "the abdomen's fur shells are drawn")
	local seta: BasePart? = nil
	for _, p in f.model:GetChildren() do
		if p.Name == "Seta" and (p.Position - part(f, "Abdomen").Position).Magnitude > part(f, "Abdomen").Size.X * 0.4 and (p.Position - part(f, "Abdomen").Position).Magnitude < part(f, "Abdomen").Size.X * 0.7 then seta = p; break end
	end
	local abdomen = part(f, "Abdomen")
	local far, near2 = 0.0, math.huge
	if seta ~= nil then
		stand(f, 5, false, function()
			local d = ((seta :: BasePart).Position - abdomen.Position).Magnitude
			far, near2 = math.max(far, d), math.min(near2, d)
		end)
	end
	check(seta ~= nil and far / near2 > 1.03, `a hair on the abdomen moves in and out with it ({if seta then string.format("%.3f", far / near2) else "none"})`)
	-- the shells' size follows
	local shellSizes: { number } = {}
	local shellPart: BasePart? = nil
	for _, p in f.model:GetChildren() do if p.Name == "FuzzShell" and p.Size.Z > abdomen.Size.Z * 0.95 then shellPart = p end end
	if shellPart ~= nil then stand(f, 3, false, function() table.insert(shellSizes, (shellPart :: BasePart).Size.Z) end) end
	local lo, hi = math.huge, -math.huge
	for _, v in shellSizes do lo, hi = math.min(lo, v), math.max(hi, v) end
	check(#shellSizes > 0 and hi / lo > 1.02, "and so does the abdomen's fur shell")
	f:destroy()
	-- subtler while it walks: about a third, never none
	local w = build(nil, "full")
	local walk = breath(w, 12, true)
	check(walk > amp * 0.25 and walk < amp * 0.45, `walking: a share of that, not none ({string.format("%.2f", walk * 100)} percent)`)
	w:destroy()
	-- Reduced Motion and the low tier: still
	local r = build(nil, "full")
	r.reducedMotion = true
	local still = breath(r, 5, false)
	check(still < 1e-9, "Reduced Motion: the abdomen does not pulse")
	r:destroy()
	local low = build(nil, "low")
	check(breath(low, 5, false) < 1e-9 and low._living == nil, "the low tier does not pulse and has no living motion")
	low:destroy()
	-- the tarantulas: 0.25 Hz, about 2 percent
	for _, id in { RED, BLUE } do
		local t = build(id, "full")
		local a, p = breath(t, 17, false)
		check(a >= 0.016 and a <= 0.0205 and near(p, 4.0, 0.15), `{id}: {string.format("%.2f", a * 100)} percent every {string.format("%.2f", p)} s (0.25 Hz)`)
		t:destroy()
	end
	-- the peacock spider does not pulse
	local pc = build("maratus_volans_male", "full")
	check(breath(pc, 5, false) < 1e-9 and pc._living == nil, "the peacock spider's fan does not pulse")
	pc:destroy()
end
breathChecks()

local function yawOf(r: any): number
	local look = part(r, "Pedicel").CFrame.LookVector
	return math.deg(math.atan2(-look.X, -look.Z))
end
local function attentionRig()
	local r = build(nil, "full")
	stand(r, 1.5)
	r.focusPoint = Vector3.new(3, 0.6, -1) -- up and away to the right: 72 degrees from straight ahead
	local samples: { number } = {}
	local worst = 0
	stand(r, 3, false, function(frame)
		local y = yawOf(r)
		worst = math.max(worst, math.abs(y))
		if frame > 90 then table.insert(samples, y) end
	end)
	local steady = median(samples)
	check(near(steady, -20, 1.0), `watching a point to the right turns the drawn body 20 degrees toward it ({string.format("%.1f", steady)}; the sign is the body frame's)`)
	check(worst <= 20 + 5.2, `with the snap accents it never exceeds 25 degrees ({string.format("%.1f", worst)})`)
	-- the glance: the principal eyes and their catchlights shift toward it, the other eyes do not
	local face = part(r, "EyeFace")
	local function across(p: BasePart): number return (p.Position - face.Position):Dot(face.CFrame.RightVector) end
	local lens = r.model:GetChildren()
	local principal: { BasePart } = {}
	local side: { BasePart } = {}
	for _, p in lens do
		if p.Name == "PrincipalEye" then table.insert(principal, p :: BasePart) elseif p.Name == "Eye" then table.insert(side, p :: BasePart) end
	end
	local withFocus = {}
	for _, p in principal do table.insert(withFocus, across(p)) end
	local sideWith = {}
	for _, p in side do table.insert(sideWith, across(p)) end
	r.focusPoint = nil
	stand(r, 2)
	local shifts, sideShift = 0.0, 0.0
	for i, p in principal do shifts = math.max(shifts, math.abs(withFocus[i] - across(p))) end
	for i, p in side do sideShift = math.max(sideShift, math.abs(sideWith[i] - across(p))) end
	check(#principal == 2 and shifts > 0.012 and shifts <= I.attention.glance + 0.004, `the principal eyes shift toward what is watched ({string.format("%.3f", shifts)} studs)`)
	check(sideShift < 0.003, "and no other eye does")
	-- back to the heading when it walks, and when the focus is let go
	local back: { number } = {}
	stand(r, 2.0, false, function(frame) if frame > 60 then table.insert(back, yawOf(r)) end end)
	check(math.abs(median(back)) < 1.0, "letting go of the focus returns the body to its heading")
	r.focusPoint = Vector3.new(3, 0.6, -1)
	stand(r, 2)
	local walking: { number } = {}
	stand(r, 2.0, true, function(frame) if frame > 70 then table.insert(walking, yawOf(r)) end end)
	check(math.abs(median(walking)) < 1.5, "walking returns it to the motor's heading, whatever is watched")
	check((r.root.Position - body.Position).Magnitude < 1e-9, "the root part (the camera and the collider's) is never turned")
	r:destroy()
	-- a tarantula and the low tier do not turn
	for _, spec in { { RED, "full" }, { nil, "low" } } do
		local t = build(spec[1] :: string?, spec[2] :: string)
		stand(t, 1)
		t.focusPoint = Vector3.new(3, 0.6, -1)
		local ys: { number } = {}
		stand(t, 3, false, function(frame) if frame > 60 then table.insert(ys, yawOf(t)) end end)
		check(math.abs(median(ys)) < 1.0, `{spec[1] or "first spider"} {spec[2]}: does not turn to what is watched`)
		t:destroy()
	end
end
attentionRig()

-- grooming, alarm and the stretch drawn: only drawn parts move; the planted feet, the root and the part count do not
local function legsRig()
	local r = build(nil, "full")
	stand(r, 1)
	local planted: { Vector3 } = {}
	for i, leg in r._legs do planted[i] = leg.planted :: Vector3 end
	local total = r:count().total
	local rest: { Vector3 } = {}
	for i, leg in r._legs do rest[i] = (leg.pad :: Part).Position end -- (the pad sits a little above the planted point)
	local function lift(i: number): number return (r._legs[i].pad :: Part).Position.Y - rest[i].Y end
	local function away(i: number): number return ((r._legs[i].pad :: Part).Position - rest[i]).Magnitude end
	-- the alarm
	r:cue("alarm")
	local up, upFrom, upTo = 0.0, -1.0, -1.0
	local feetStill = true
	stand(r, 2.5, false, function(frame)
		local t = frame / 60
		up = math.max(up, lift(1), lift(5))
		if lift(1) > 0.1 then if upFrom < 0 then upFrom = t end; upTo = t end
		for i, leg in r._legs do feetStill = feetStill and leg.planted ~= nil and ((leg.planted :: Vector3) - planted[i]).Magnitude < 1e-9 end
	end)
	check(up > 0.2 and upFrom < 0.4 and upTo > 0.8 and upTo < 1.4, `the alarm: legs I are raised ({string.format("%.2f", up)} studs) from {string.format("%.2f", upFrom)} to {string.format("%.2f", upTo)} s`)
	check(feetStill and away(1) < 0.01 and away(5) < 0.01 and away(2) < 0.01, "then down again, and the planted feet were never moved")
	check(r:count().total == total and (r.root.Position - body.Position).Magnitude < 1e-9, "the part count and the root are untouched")
	-- the meal's cleaning: legs I and II are drawn up to the palps in turn
	local firstSeen: { [number]: number } = {}
	r:cue("groom")
	local palpMoved = 0.0
	local palpRest = part(r, "PalpTip").Position - part(r, "Cephalothorax").Position
	stand(r, 15, false, function(frame)
		for _, i in { 1, 5, 2, 6 } do
			if away(i) > 0.2 and firstSeen[i] == nil then firstSeen[i] = frame / 60 end
		end
		palpMoved = math.max(palpMoved, ((part(r, "PalpTip").Position - part(r, "Cephalothorax").Position) - palpRest).Magnitude)
		for i, leg in r._legs do feetStill = feetStill and leg.planted ~= nil and ((leg.planted :: Vector3) - planted[i]).Magnitude < 1e-9 end
	end)
	check(firstSeen[1] ~= nil and firstSeen[5] ~= nil and firstSeen[2] ~= nil and firstSeen[6] ~= nil and firstSeen[1] < firstSeen[5] and firstSeen[5] < firstSeen[2] and firstSeen[2] < firstSeen[6], "after a meal legs I (left, right) and then II (left, right) are cleaned in turn")
	check(palpMoved > 0.03, `the palps are drawn through the jaws ({string.format("%.3f", palpMoved)} studs)`)
	check(feetStill and away(1) < 0.01 and away(6) < 0.01, "the planted feet never moved, and every leg is down at the end")
	-- moving cuts it short
	r:cue("groom")
	stand(r, 4.5)
	check(away(1) > 0.1 or away(5) > 0.1 or away(2) > 0.1 or away(6) > 0.1 or r._living.bout ~= nil, "a second cleaning has begun")
	stand(r, 0.4, true)
	check(r._living.bout == nil, "and walking cuts it short")
	-- noteMeals: the first count is a baseline, a rise is a cue
	local n = build(nil, "full")
	n:noteMeals(7)
	stand(n, 6)
	local cleaned = false
	for _, e in n._living.log do cleaned = cleaned or e.kind == "meal" end
	check(n._living.pendingMeal == nil and not cleaned, "a spider loaded with meals already behind it does not clean itself")
	n:noteMeals(8)
	check(n._living.pendingMeal ~= nil, "a meal finished is the cue to clean")
	n:destroy()
	r:destroy()
	-- Reduced Motion: nothing moves, whatever is cued or watched
	local q = build(nil, "full")
	q.reducedMotion = true
	stand(q, 1)
	local before = snapshot(q)
	q:cue("alarm"); q:cue("groom")
	q.focusPoint = Vector3.new(3, 0.6, -1)
	stand(q, 8)
	check(moved(before, snapshot(q)) < 1e-9, "Reduced Motion: no alarm, no cleaning, no turn, no breath")
	q:destroy()
end
legsRig()

local function tarantulaRig()
	local t = build(RED, "full")
	stand(t, 1)
	local planted: { Vector3 } = {}
	for i, leg in t._legs do planted[i] = leg.planted :: Vector3 end
	local total = t:count().total
	local reach, gone = 0.0, true
	local seen: { [number]: boolean } = {}
	stand(t, 50, false, function()
		for i, leg in t._legs do
			local d = ((leg.pad :: Part).Position - planted[i]).Magnitude
			if d > 0.08 then seen[i] = true end
			reach = math.max(reach, d)
		end
	end)
	local used = 0
	for _ in seen do used += 1 end
	check(reach > 0.08 and used >= 1 and #t._living.log >= 2, `a tarantula stretches a leg now and then ({#t._living.log} times in 50 seconds, {string.format("%.2f", reach)} studs out)`)
	local clean = true
	for _, e in t._living.log do clean = clean and e.kind == "stretch" end
	check(clean and t:count().total == total, "and only stretches: no cleaning, no bursts")
	stand(t, 4)
	check(#t._living.log >= 1, "it keeps standing calmly")
	t:destroy()
end
tarantulaRig()

-- the mate's and the rival's rigs, and the other looks, stay as they were
local function otherRigs()
	local rival = build("rival_spider", "low")
	local count = rival:count().total
	stand(rival, 3)
	rival:cue("alarm"); rival:cue("groom"); rival:noteMeals(1); rival:noteMeals(2)
	stand(rival, 3)
	check(rival._living == nil and rival:count().total == count, "the rival's low-tier rig has no living motion and no new parts")
	rival:destroy()
	local mate = build(nil, "full")
	mate:setScale(0.8)
	stand(mate, 8)
	check(mate._living ~= nil and (mate.root.Position - body.Position).Magnitude < 1e-9, "the mate's rig (the played spider's look, smaller) lives like the first spider's, its own stream")
	mate:destroy()
	local other = build(nil, "full")
	check(other._living ~= nil and other._living.rng ~= build(nil, "full")._living.rng, "each rig draws from a stream of its own")
	local ant = build("myrmarachne_formicaria_female", "full")
	local pc = build("maratus_volans_male", "full")
	check(ant._living == nil and pc._living == nil, "the ant mimic and the peacock spider have none")
	ant:cue("alarm"); pc:cue("groom")
	local antCount, pcCount = ant:count().total, pc:count().total
	stand(ant, 2); stand(pc, 2)
	check(ant:count().total == antCount and pc:count().total == pcCount, "cues to a rig without living motion are ignored")
	other:destroy(); ant:destroy(); pc:destroy()
end
otherRigs()

print(`IDLE passed={passed} failed={failed}`)
if failed > 0 then error("idle checks failed") end
