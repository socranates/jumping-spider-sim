-- Tarantula checks (ROBLOX-82): the threat display and silk mat of the Mexican redknee and the Greenbottle blue. Unlike the peacock's dance and the ant
-- mimic's walk there is no paper behind the numbers (they are all artistic: Data/Tarantula), so what is checked is the shape the data documents: a
-- 6 second loop in order (rear up, hold 2.2 s, settle, turn about while the spinnerets sweep, hold, turn back) that begins and ends at rest, the angles
-- and rates it says, ending at once when the spider moves, jumps, leaves the surface or is told to stop, a pose that is a function of the time it is
-- handed (slow motion slows it, frame rate changes nothing) and ReducedMotion halving every angle and stopping the tremble. Pure Luau: this says
-- nothing about how Roblox draws the pose (tests/look.luau checks the drawn spider; Studio is the judge of the look).
local Tarantula = require("../src/Shared/Data/Tarantula")
local Pose = require("../src/Shared/Rig/TarantulaPose")
local Choice = require("../src/Shared/Rig/SpiderChoice")
local Text = require("../src/Shared/UI/TarantulaText")
local PeacockText = require("../src/Shared/UI/PeacockText")
local ControlText = require("../src/Shared/UI/ControlText")
local Appearances = require("../src/Shared/Data/Appearances")
local Mating = require("../src/Shared/Life/Mating")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL tarantula: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

local RED, BLUE = "brachypelma_hamorii", "chromatopelma_cyaneopubescens"
local function deg(r: number): number return math.deg(r) end

-- ---------------------------------------------------------------- the data
check(Tarantula.pack == "tarantula_pack" and Tarantula.ids[1] == RED and Tarantula.ids[2] == BLUE and #Tarantula.ids == 2, "the pack and its two tarantulas")
check(Appearances.profiles[RED].pack == Tarantula.pack and Appearances.profiles[BLUE].pack == Tarantula.pack, "the profiles say they are in the pack")
check(Tarantula.loopSeconds == 6.0, "the loop is 6 seconds")
local ids, total = {}, 0
for _, p in Tarantula.phases do
	table.insert(ids, p.id)
	total += p.seconds
	check(p.seconds > 0, `phase {p.id} takes time`)
end
check(table.concat(ids, ",") == "rear,threat,settle,turn,mat,return" and near(total, Tarantula.loopSeconds, 1e-12), "the phases in order: rear up, threat, settle, turn, mat, return; they add up to the loop")
check(Tarantula.phases[2].seconds == 2.2, "the threat posture is held 2.2 seconds")
check(Tarantula.rearDeg == 32 and Tarantula.pivotDeg == 180 and Tarantula.sweepDeg > 0 and Tarantula.sweepDeg <= 45 and Tarantula.palpDeg > 0 and Tarantula.palpDeg <= 90, "the prosoma rears 32 degrees and the body turns 180")
check(Tarantula.sweepHz > 0 and Tarantula.sweepHz <= 3 and Tarantula.tremorHz > 0 and Tarantula.tremorHz <= 3, "the sweep and the tremble stay at or under 3 Hz (nothing flashes)")
check(Tarantula.reducedMotion == 0.5 and Tarantula.fadeOutSeconds > 0 and Tarantula.fadeOutSeconds <= 0.3, "reduced motion halves; an ended pose eases out in a quarter of a second at most")

-- ---------------------------------------------------------------- the loop, at known times
local function at(t: number, reduced: boolean?): Pose.Pose return Pose.rawPose(t, reduced == true) end
local z = at(0)
check(z.rear == 0 and z.legs == 0 and z.palps == 0 and z.yaw == 0 and z.sweep == 0 and z.tremor == 0 and z.phase == "rear", "the loop begins at rest")
check(near(deg(at(0.25).rear), 16, 1e-9) and near(at(0.25).legs, 0.5, 1e-9), "half way up after half the rise")
for _, t in { 0.5, 1.0, 1.6, 2.2, 2.69 } do
	local p = at(t)
	check(near(deg(p.rear), 32, 1e-9) and near(p.legs, 1, 1e-9) and near(deg(p.palps), Tarantula.palpDeg, 1e-9) and p.yaw == 0 and p.sweep == 0, `the threat posture at {t} s: rear 32 degrees, legs I and the palps up, no turn, no sweep`)
	check(p.phase == (if t < 0.5 then "rear" else "threat"), `phase at {t} s`)
end
check(near(deg(at(2.95).rear), 16, 1e-9) and at(2.95).phase == "settle", "half way down in the settle")
check(at(3.2).rear == 0 and at(3.2).legs == 0 and at(3.2).palps == 0 and at(3.2).yaw == 0 and at(3.2).phase == "turn", "settled: the prosoma and legs I are down before the turn")
check(near(deg(at(3.8).yaw), 90, 1e-9) and near(deg(at(4.4).yaw), 180, 1e-9) and near(deg(at(4.6).yaw), 180, 1e-9) and at(4.6).phase == "mat", "the body pivots to 180 degrees through the turn and holds it")
check(near(deg(at(5.4).yaw), 90, 1e-9) and at(5.4).phase == "return" and deg(at(5.999999).yaw) < 0.001, "and pivots back to 0 by the end of the loop")
-- Levels never overlap: the posture and the turn are different parts of the loop.
local overlap, legsInTurn = false, false
for i = 0, 6000 do
	local p = at(i * 0.001)
	if p.rear > 1e-9 and p.yaw > 1e-9 then overlap = true end
	if i * 0.001 >= 3.2 and (p.legs > 0 or p.palps > 0 or p.rear > 0) then legsInTurn = true end
end
check(not overlap and not legsInTurn, "the body never turns while it is reared, and legs I and the palps are legs again for the turn")
-- The loop closes.
local a0, a6, aWrap = at(0), at(6.0), at(6.0 + 1.6)
local b = at(1.6)
check(a0.rear == a6.rear and a0.yaw == a6.yaw and a0.sweep == a6.sweep and a0.legs == a6.legs and a0.tremor == a6.tremor and a0.phase == a6.phase, "the loop ends where it began")
check(near(aWrap.rear, b.rear, 1e-9) and near(aWrap.legs, b.legs, 1e-9) and near(aWrap.yaw, b.yaw, 1e-9), "and repeats")
local lastEnd = at(5.9999)
check(math.abs(lastEnd.rear) < 1e-9 and math.abs(lastEnd.yaw) < 0.001 and math.abs(lastEnd.sweep) < 0.001 and math.abs(lastEnd.tremor) < 1e-9, "(so the repeat has no jump: rest at the end)")
-- The hold lasts as long as it says.
local held, maxRear, maxYaw, maxSweep, maxPalps = 0, 0, 0, 0, 0
for i = 0, 5999 do
	local p = at(i * 0.001)
	if near(p.rear, math.rad(32), 1e-9) then held += 0.001 end
	maxRear, maxYaw, maxSweep, maxPalps = math.max(maxRear, p.rear), math.max(maxYaw, p.yaw), math.max(maxSweep, math.abs(p.sweep)), math.max(maxPalps, p.palps)
end
check(near(held, 2.2, 0.01) or near(held, 2.2 + 0.001, 0.01), `the full rear lasts the 2.2 seconds ({string.format("%.3f", held)} s)`)
check(near(deg(maxRear), 32, 1e-9) and near(deg(maxYaw), 180, 1e-9) and near(deg(maxPalps), Tarantula.palpDeg, 1e-9), "the largest angles are the documented ones")
check(maxSweep <= math.rad(Tarantula.sweepDeg) + 1e-9 and maxSweep > math.rad(Tarantula.sweepDeg) * 0.95, `the spinnerets swing {string.format("%.1f", deg(maxSweep))} degrees at most, either side`)
-- The spinnerets sweep only while the body turns (and holds at the far side), at the stated rate.
local sweepOutside, sweepInside, crossings, prev = false, false, 0, nil :: number?
for i = 0, 5999 do
	local t = i * 0.001
	local s = at(t).sweep
	if t < 3.2 and s ~= 0 then sweepOutside = true end
	if t >= 3.2 and math.abs(s) > 1e-6 then sweepInside = true end
	if t >= 3.8 and t <= 5.6 then
		if prev ~= nil and prev < 0 and s >= 0 then crossings += 1 end
		prev = s
	end
end
check(not sweepOutside and sweepInside, "the spinnerets only sweep from the turn on")
check(near(crossings / 1.8, Tarantula.sweepHz, 0.6), `the sweep runs at about {Tarantula.sweepHz} Hz ({crossings} strokes in 1.8 s)`)
local swingLeft, swingRight = false, false
for i = 0, 5999 do
	local s = at(i * 0.001).sweep
	if s < -0.05 then swingLeft = true elseif s > 0.05 then swingRight = true end
end
check(swingLeft and swingRight, "side to side: it swings both ways")
-- The tremble: only in the hold, small, bounded.
local trembleOutside, trembleMax, trembleSeen = false, 0, false
for i = 0, 5999 do
	local t = i * 0.001
	local tr = at(t).tremor
	if (t < 0.5 or t >= 2.7) and tr ~= 0 then trembleOutside = true end
	trembleMax = math.max(trembleMax, math.abs(tr))
	if t > 0.9 and t < 2.3 and math.abs(tr) > 0.5 then trembleSeen = true end
end
check(not trembleOutside and trembleSeen and trembleMax <= 1, "the raised legs tremble only in the hold")

-- ---------------------------------------------------------------- the pose over time: start, step, end
local function new(reduced: boolean?): Pose.State
	local p = Pose.new()
	p.reduced = reduced == true
	return p
end
local function run(p: Pose.State, secs: number, dt: number, standing: boolean, moving: boolean): Pose.Pose
	local out = Pose.NONE
	for _ = 1, math.floor(secs / dt + 0.5) do out = p:step(dt, standing, moving) end
	return out
end
local p0 = new()
local idle = p0:step(1 / 60, true, false)
check(idle.presence == 0 and idle.rear == 0 and idle.legs == 0 and idle.yaw == 0 and not p0:displaying() and not p0:showing(), "no pose until the key")
check(not p0:start(false, false) and not p0:start(true, true) and not p0:displaying(), "the display key is refused in the air and while walking")
check(p0:start(true, false) and p0:displaying() and p0:showing() and not p0:start(true, false), "it starts once, standing still")
local early = run(p0, 0.3, 1 / 60, true, false)
check(early.rear > 0 and early.rear < math.rad(32) and early.presence > 0.99, "it rears up from the first moment")
local holding = run(p0, 1.0, 1 / 60, true, false) -- 1.3 s in
check(near(holding.rear, math.rad(32), 1e-6) and holding.legs > 0.99 and holding.phase == "threat", "and holds the posture")
local through = run(p0, 2.8, 1 / 60, true, false) -- 4.1 s in
check(through.yaw > 0 and through.phase == "turn", "and turns about once it has settled")
local roundAgain = run(p0, 6.0 - 4.1 + 1.0, 1 / 60, true, false) -- 7.0 s in: the second loop
check(roundAgain.phase == "threat" and roundAgain.legs > 0.99 and p0:displaying(), "the loop goes round again by itself")

-- Ending it: a step, a jump (not standing), the key (stop) and the pose eases out in a moment; legs go back to the motor.
local function endBy(how: string): (Pose.State, Pose.Pose)
	local p = new()
	p:start(true, false)
	run(p, 1.5, 1 / 60, true, false)
	local first: Pose.Pose
	if how == "move" then first = p:step(1 / 60, true, true)
	elseif how == "air" then first = p:step(1 / 60, false, false)
	else p:stop(); first = p:step(1 / 60, true, false) end
	return p, first
end
for _, how in { "move", "air", "stop" } do
	local p, first = endBy(how)
	check(not p:displaying(), `{how}: the pose is ended at once`)
	check(first.rear > 0 and first.rear < math.rad(32) and first.presence < 1, `{how}: and eases out, not a pop (rear {string.format("%.1f", deg(first.rear))} degrees the first frame)`)
	local frames, last, mono = 0, first.legs, true
	local q = first
	while p:showing() and frames < 60 do
		q = p:step(1 / 60, true, false)
		mono = mono and q.legs <= last + 1e-12
		last = q.legs
		frames += 1
	end
	check(mono and frames <= math.ceil(Tarantula.fadeOutSeconds * 60) + 1 and not p:showing() and q.legs == 0 and q.rear == 0 and q.yaw == 0 and q.sweep == 0, `{how}: legs I go back to the motor within {Tarantula.fadeOutSeconds} s ({frames} frames), the body is straight again`)
end
-- Ended mid-turn, the body comes back from where it was.
local turnEnd = new()
turnEnd:start(true, false)
run(turnEnd, 4.0, 1 / 60, true, false)
local turning = turnEnd:step(1 / 60, true, true)
check(turning.yaw > 0 and turning.yaw < math.rad(180) and turnEnd:showing() and not turnEnd:displaying(), "ended in the middle of the turn, it eases back from the angle it had")
run(turnEnd, 0.5, 1 / 60, true, false)
check(not turnEnd:showing() and turnEnd:step(1 / 60, true, false).yaw == 0, "and is gone")
-- After a stop the key starts a fresh loop from the beginning, even if the last one is still easing out.
local again = new()
again:start(true, false)
run(again, 1.0, 1 / 60, true, false)
again:stop()
again:step(1 / 60, true, false)
check(again:start(true, false) and again:displaying(), "the key again, a moment after, starts it")
check(near(again:step(0, true, false).rear, near(again.t, 0, 1e-12) and again:step(0, true, false).rear or 0, 1e-12), "(and from the first moment of the loop)")

-- ---------------------------------------------------------------- slow motion and frame rate
-- The pose is a function of the time it is handed: 60 steps a second, 20 and 240 give the same pose at the same time; half the step is half the speed.
local function after(dt: number, secs: number): Pose.Pose
	local p = new()
	p:start(true, false)
	return run(p, secs, dt, true, false)
end
for _, secs in { 1.0, 2.5, 4.0, 5.5 } do
	local a, b2, c = after(1 / 60, secs), after(1 / 20, secs), after(1 / 240, secs)
	check(near(a.rear, b2.rear, 1e-6) and near(a.yaw, b2.yaw, 1e-6) and near(a.sweep, b2.sweep, 1e-6) and near(a.rear, c.rear, 1e-6) and near(a.sweep, c.sweep, 1e-6), `60, 20 and 240 steps a second give the same pose at {secs} s`)
end
local slowA, normalB = new(), new()
slowA:start(true, false); normalB:start(true, false)
local slowPose, normalPose
for _ = 1, 180 do slowPose = slowA:step(1 / 120, true, false) end -- 3 s of frames in slow motion (half speed): 1.5 s of pose
for _ = 1, 90 do normalPose = normalB:step(1 / 60, true, false) end -- 1.5 s of pose
check(near(slowPose.rear, normalPose.rear, 1e-6) and near(slowPose.legs, normalPose.legs, 1e-6) and slowPose.phase == normalPose.phase, "slow motion (half the time each frame) slows the pose as it slows everything else")
local held2 = new()
held2:start(true, false)
run(held2, 1.0, 1 / 60, true, false)
local before = held2:step(0, true, false)
local frozen = true
for _ = 1, 30 do
	local q = held2:step(0, true, false)
	frozen = frozen and near(q.rear, before.rear, 1e-12) and near(q.sweep, before.sweep, 1e-12) and near(q.yaw, before.yaw, 1e-12)
end
check(frozen and held2:displaying(), "a menu or the catch screen holds it (no time given, no change, and it is not ended)")

-- No jumps in a whole loop at 60 frames a second, in or out.
local smoothP = new()
smoothP:start(true, false)
local prevP = smoothP:step(1 / 60, true, false)
local worst = 0
for _ = 1, 600 do
	local q = smoothP:step(1 / 60, true, false)
	worst = math.max(worst, math.abs(q.rear - prevP.rear), math.abs(q.yaw - prevP.yaw), math.abs(q.sweep - prevP.sweep), math.abs(q.palps - prevP.palps), math.abs(q.legs - prevP.legs) * 0.5)
	prevP = q
end
check(worst < 0.1, `no jumps (largest step in 1/60 s: {string.format("%.4f", worst)})`)

-- ---------------------------------------------------------------- reduced motion
local nP, rP = new(), new(true)
nP:start(true, false); rP:start(true, false)
local nMax = { rear = 0, yaw = 0, sweep = 0, palps = 0, tremor = 0 }
local rMax = { rear = 0, yaw = 0, sweep = 0, palps = 0, tremor = 0 }
local rLegs = 0
for _ = 1, 360 do
	local qn, qr = nP:step(1 / 60, true, false), rP:step(1 / 60, true, false)
	nMax.rear, nMax.yaw, nMax.sweep, nMax.palps, nMax.tremor = math.max(nMax.rear, qn.rear), math.max(nMax.yaw, qn.yaw), math.max(nMax.sweep, math.abs(qn.sweep)), math.max(nMax.palps, qn.palps), math.max(nMax.tremor, math.abs(qn.tremor))
	rMax.rear, rMax.yaw, rMax.sweep, rMax.palps, rMax.tremor = math.max(rMax.rear, qr.rear), math.max(rMax.yaw, qr.yaw), math.max(rMax.sweep, math.abs(qr.sweep)), math.max(rMax.palps, qr.palps), math.max(rMax.tremor, math.abs(qr.tremor))
	rLegs = math.max(rLegs, qr.legs)
end
check(near(rMax.rear / nMax.rear, 0.5, 1e-6) and near(rMax.yaw / nMax.yaw, 0.5, 1e-6) and near(rMax.palps / nMax.palps, 0.5, 1e-6) and near(rMax.sweep / nMax.sweep, 0.5, 0.01), "reduced motion halves the rear, the turn, the palps and the sweep")
check(nMax.tremor > 0.5 and rMax.tremor == 0, "and stops the tremble")
check(rLegs > 0.99, "the posture still shows: legs I still go all the way up")

-- ---------------------------------------------------------------- choosing the spider, and the words
check(Choice.hasThreat(RED) and Choice.hasThreat(BLUE) and not Choice.hasThreat("first_spider") and not Choice.hasThreat("maratus_volans_male") and not Choice.hasThreat("myrmarachne_formicaria_female") and not Choice.hasThreat("rival_spider") and not Choice.hasThreat("junk"), "only the two tarantulas have the threat display")
check(Choice.displayKind(RED) == "threat" and Choice.displayKind(BLUE) == "threat" and Choice.displayKind("myrmarachne_formicaria_female") == "antennae" and Choice.displayKind("maratus_volans_male") == "dance" and Choice.displayKind("first_spider") == nil, "the display key: a threat display for the tarantulas, the others as before")
check(not Choice.canDance(RED) and not Choice.hasAntennae(RED) and not Choice.canDance(BLUE) and not Choice.hasAntennae(BLUE), "a tarantula has neither a fan nor antennae")
check(Choice.start(RED, nil) == RED and Choice.start(nil, BLUE) == BLUE and Choice.start("first_spider", BLUE) == "first_spider", "the Player or Workspace attribute can preselect a tarantula")
check(PeacockText.NAMES[RED] == "the Mexican redknee" and PeacockText.NAMES[BLUE] == "the Greenbottle blue" and PeacockText.changed(BLUE) == "You are the Greenbottle blue now", "their names and the toast")
for _, id in { RED, BLUE } do
	local th = Appearances.profiles[id].threat
	check(th.pair == 1 and th.up.y > 0.1 and th.up.z < -0.3 and th.up.x > 0.2 and th.tipSweep > 1 and th.tremor > 0 and th.tremor < 0.05 and th.sweepBack > 0, `{id}: legs I go up and forward, the tremble is small, the second spinneret segment swings farther`)
end
check(Text.displayHint("keyboard", false) == "X: rear up" and Text.displayHint("keyboard", true) == "X: stop" and Text.statusLine("keyboard") == "THREAT DISPLAY    X or move: stop", "the display key's words on a keyboard")
ControlText.setPadStyle("playstation")
check(Text.displayHint("gamepad", false) == "R1: rear up" and string.find(PeacockText.helpExtra("gamepad", "threat"), "R1 rear up", 1, true) ~= nil, "PlayStation words")
ControlText.setPadStyle("xbox")
check(Text.displayHint("gamepad", false) == "RB: rear up" and Text.displayHint("touch", false) == "Rear up: rear up" and Text.touchDisplay(false) == "Rear up" and Text.touchDisplay(true) == "Stop", "controller and touch words")
local card = PeacockText.helpExtra("keyboard", "threat")
check(string.find(card, "C change spider", 1, true) ~= nil and string.find(card, "rear up", 1, true) ~= nil and string.find(card, "rear up and turn", 1, true) ~= nil and string.find(card, "silk mat", 1, true) == nil and string.find(card, "courtship", 1, true) == nil and string.find(card, "antennae", 1, true) == nil, "the controls card has the crack's line and the threat line, not the dance or the antennae")
check(string.find(PeacockText.helpExtra("keyboard", "dance"), "rear up", 1, true) == nil and string.find(PeacockText.helpExtra("keyboard", "antennae"), "rear up", 1, true) == nil and string.find(PeacockText.helpExtra("keyboard", nil), "rear up", 1, true) == nil, "nobody else's card mentions it")
check(#card <= #PeacockText.helpExtra("keyboard", "dance") + 25 and #Text.helpLine("gamepad") < 100, "the card's new line is about as long as the peacock's")
check(string.find(Text.STAND, "Stand still", 1, true) == 1, "the refusal says to stand still")
-- A tarantula is a costume: it is the game's female, as the first spider is (Mating.sexOf), so its mate is a male.
check(Mating.sexOf(RED) == "female" and Mating.sexOf(BLUE) == "female" and Mating.sexOf("first_spider") == "female", "a tarantula's sex for the mate is the first spider's (a costume on the same body)")

print(`TARANTULA passed={passed} failed={failed}`)
if failed > 0 then error("tarantula checks failed") end
