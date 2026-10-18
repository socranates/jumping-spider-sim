-- Peacock dance checks (ROBLOX-29): the documented rates are the paper's (Girard, Kasumovic & Elias 2011), the phases add up
-- to the loop and come in the paper's order, the pose really oscillates at those rates, slow motion and frame rate change nothing
-- but speed, a stop eases out over 0.2 s, ReducedMotion halves the movement and stops the tremble. Pure Luau: this says nothing about
-- how Roblox draws the pose (tests/look.luau checks the drawn spider; Studio is the judge of the look).
local Peacock = require("../src/Shared/Data/Peacock")
local Dance = require("../src/Shared/Rig/PeacockDance")
local Choice = require("../src/Shared/Rig/SpiderChoice")
local Text = require("../src/Shared/UI/PeacockText")
local ControlText = require("../src/Shared/UI/ControlText")
local LifeText = require("../src/Shared/UI/LifeText")
local HudLayout = require("../src/Shared/UI/HudLayout")
local Appearances = require("../src/Shared/Data/Appearances")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL peacock: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

-- ---------------------------------------------------------------- the data
local r = Peacock.rates
check(r.palpFlicker.hz == 3.5 and r.palpFlicker.sd == 1.6, "palp flicker 3.5 +- 1.6 flicks a second (Girard et al. 2011)")
check(r.fanDance.hz == 3.2 and r.fanDance.sd == 1.5, "fan dance 3.2 +- 1.5 cycles a second")
check(r.legWave.hz == 3.2 and r.legWave.sd == 0.6, "leg III waving 3.2 +- 0.6 waves a second")
check(r.fanFlap.hz == 2.5 and r.fanFlap.sd == 1.8, "fan-flapping 2.5 +- 1.8 flaps a second")
check(Peacock.rumble.seconds == 2.44 and Peacock.rumble.sd == 0.28 and Peacock.rumble.bumpsHz == 12.1 and Peacock.rumble.bumpsSd == 2.9, "rumble-rump 2.44 +- 0.28 s at 12.1 +- 2.9 bumps a second")
check(Peacock.fanArcDeg.min == 19 and Peacock.fanArcDeg.max == 35 and Peacock.fanArcDeg.used >= 19 and Peacock.fanArcDeg.used <= 35, "the fan dance arc is 19 to 35 degrees")
check(Peacock.courtshipMinutes.min == 6 and Peacock.courtshipMinutes.max == 51 and Peacock.courtshipMinutes.mean == 24.35, "real courtship 6 to 51 minutes, mean 24.35")
check(string.find(Peacock.citation, "PLoS ONE 6(9): e25390", 1, true) ~= nil, "the citation is in the data")
check(Peacock.id == "maratus_volans_male", "the appearance id")

local total, levelsOk = 0, true
for _, p in Peacock.phases do
	total += p.seconds
	for _, name in { "pitch", "open", "legs", "sway", "wave", "flap", "bob", "palp" } do
		local v = (p :: any)[name]
		levelsOk = levelsOk and type(v) == "number" and v >= 0 and v <= 1
	end
	levelsOk = levelsOk and (p.ease or Peacock.ease) > 0 and (p.ease or Peacock.ease) <= p.seconds
end
check(near(total, Peacock.loopSeconds, 1e-9), `the phases add up to the loop ({total} s)`)
check(levelsOk, "every phase has all its levels, 0..1, and an ease that fits inside it")
check(Peacock.loopSeconds >= 8 and Peacock.loopSeconds <= 20, "the loop is a short showcase, not a real 24-minute courtship")
local ids = {}
for _, p in Peacock.phases do table.insert(ids, p.id) end
check(table.concat(ids, ",") == "approach,raise,dance,freeze,dance_again,fold", "approach, raise, dance, freeze, second dance, fold")
check(Peacock.phases[1].rumble ~= nil and Peacock.phases[1].rumble + Peacock.rumble.seconds <= Peacock.phases[1].seconds, "a whole rumble-rump fits in the approach")
check(Peacock.phases[1].bob == 1 and Peacock.phases[1].pitch == 0 and Peacock.phases[1].open == 0, "bobbing on the approach, fan still folded")
check(Peacock.reducedMotion == 0.5 and Peacock.fadeOutSeconds == 0.2, "reduced motion halves, a stop fades in 0.2 s")
local forbidden = { "mount", "copulat", "pre_mount", "premount" }
local clean = true
for _, id in ids do for _, bad in forbidden do if string.find(id, bad) then clean = false end end end
check(clean, "no pre-mount display or mounting attempt (a family game)")

-- ---------------------------------------------------------------- the pose through the loop
local STEP = 1 / 240
local function startOf(id: string): number
	local t = 0
	for _, p in Peacock.phases do
		if p.id == id then return t end
		t += p.seconds
	end
	return -1
end
local function lengthOf(id: string): number
	for _, p in Peacock.phases do if p.id == id then return p.seconds end end
	return 0
end
-- Rising crossings of `value` through `mid` per second, over loop time [from, to].
local function rate(value: (number) -> number, mid: number, from: number, to: number): number
	local n, prev = 0, value(from) - mid
	local t = from + STEP
	while t <= to do
		local v = value(t) - mid
		if prev < 0 and v >= 0 then n += 1 end
		prev = v
		t += STEP
	end
	return n / (to - from)
end
local function pose(t: number, reduced: boolean?): Dance.Pose return Dance.rawPose(t, reduced == true) end

local d0, d1 = startOf("dance") + 0.6, startOf("dance") + lengthOf("dance") - 0.1
check(near(rate(function(t) return pose(t).abdomenSway end, 0, d0, d1), 3.2, 0.35), "the fan sways at 3.2 cycles a second")
check(near(rate(function(t) return pose(t).legsWave end, 0.5, d0, d1), 3.2, 0.35), "legs III wave at 3.2 waves a second")
check(near(rate(function(t) return pose(t).palp end, 0.5 * math.rad(Peacock.amplitude.palpDeg), d0, d1), 3.5, 0.4), "the palps flicker at 3.5 flicks a second")
local f0, f1 = startOf("freeze") + 0.5, startOf("freeze") + lengthOf("freeze") - 0.05
local flapMid = 1 - 0.5 * Peacock.amplitude.flapDepth
check(near(rate(function(t) return pose(t).fanOpen end, flapMid, f0, f1), 2.5, 0.5), "the fan flaps at 2.5 flaps a second in the pause")
local rumbleFrom, rumbleTo = math.huge, -math.huge
local t = 0
while t < Peacock.loopSeconds do
	if pose(t).rumble > 0.001 then rumbleFrom, rumbleTo = math.min(rumbleFrom, t), math.max(rumbleTo, t) end
	t += STEP
end
check(near(rumbleTo - rumbleFrom, Peacock.rumble.seconds, 0.03), `the rumble-rump lasts 2.44 s (measured {string.format("%.3f", rumbleTo - rumbleFrom)})`)
check(near(rate(function(t) return pose(t).shiver end, 0, rumbleFrom + 0.3, rumbleTo - 0.3), 12.1, 0.8), "the tremble runs at 12.1 bumps a second")

-- The order of the display, read off the pose.
local first = { rumble = -1, bob = -1, raise = -1, sway = -1, flap = -1, again = -1 }
local swayEnded = false
t = 0
while t < Peacock.loopSeconds do
	local p = pose(t)
	if first.rumble < 0 and p.rumble > 0.5 then first.rumble = t end
	if first.bob < 0 and p.phase == "approach" and math.abs(p.abdomenPitch) > math.rad(3) then first.bob = t end
	if first.raise < 0 and p.fanOpen > 0.5 then first.raise = t end
	if first.sway < 0 and math.abs(p.abdomenSway) > math.rad(10) then first.sway = t end
	if first.sway >= 0 and first.flap < 0 and p.fanOpen < 0.8 then first.flap = t end
	if first.flap >= 0 and first.again < 0 and p.phase == "dance_again" and math.abs(p.abdomenSway) > math.rad(10) then first.again = t end
	t += STEP
end
check(first.rumble >= 0 and first.bob >= 0 and first.rumble < first.raise and first.bob < first.raise, "rumble-rump and bobbing come before the fan goes up")
check(first.raise < first.sway and first.sway < first.flap and first.flap < first.again, "the fan dance, then flapping in the pause, then another dance")
local folded = pose(startOf("fold") + lengthOf("fold") - 0.01)
check(folded.fanOpen < 0.05 and folded.legsRaise < 0.05 and math.abs(folded.abdomenPitch) < 0.05, "the loop ends folded, and starts folded")
check(pose(0).fanOpen < 0.05 and near(pose(3.3).abdomenPitch, pose(3.3 + Peacock.loopSeconds).abdomenPitch, 1e-9), "the loop repeats")

-- Bounds and smoothness.
local maxPitch, maxSway, maxStep, maxOpen, minOpen = 0, 0, 0, 0, 1
local prev = pose(0)
t = STEP
while t < 2 * Peacock.loopSeconds do
	local p = pose(t)
	maxPitch, maxSway = math.max(maxPitch, math.abs(p.abdomenPitch)), math.max(maxSway, math.abs(p.abdomenSway))
	maxOpen, minOpen = math.max(maxOpen, p.fanOpen), math.min(minOpen, p.fanOpen)
	maxStep = math.max(maxStep, math.abs(p.abdomenPitch - prev.abdomenPitch), math.abs(p.abdomenSway - prev.abdomenSway), math.abs(p.fanOpen - prev.fanOpen) * 0.5, math.abs(p.legsWave - prev.legsWave) * 0.5)
	prev = p
	t += STEP
end
check(maxPitch <= math.rad(Peacock.amplitude.raiseDeg + Peacock.amplitude.bobDeg) + 1e-9 and maxPitch >= math.rad(Peacock.amplitude.raiseDeg) * 0.99, "the abdomen rises to the raise angle and no further than the bob adds")
check(maxSway <= math.rad(Peacock.fanArcDeg.used / 2) + 1e-9 and maxSway >= math.rad(Peacock.fanArcDeg.used / 2) * 0.95, "the sway fills the arc (27 degrees: 13.5 either side)")
check(maxOpen <= 1 + 1e-9 and minOpen >= 0 and maxOpen > 0.99, "the fan opens fully and never past it")
check(maxStep < 0.05, `the pose has no jumps (largest step in 1/240 s: {string.format("%.4f", maxStep)})`)

-- ---------------------------------------------------------------- the dance object
local idle = Dance.new()
local nothing = idle:step(1 / 60, true, false)
check(nothing.presence == 0 and nothing.phase == "none" and nothing.fanOpen == 0 and nothing.abdomenPitch == 0 and nothing.rumble == 0, "no pose until a dance starts")
check(not idle:start(false, false) and not idle:start(true, true) and not idle:showing(), "a dance will not start in the air or while walking")
check(idle:start(true, false) and idle.active and not idle:start(true, false), "it starts once, standing still")

-- Frame rate and slow motion change only speed.
local function danceTo(seconds: number, dt: number): Dance.Pose
	local d = Dance.new()
	d:start(true, false)
	local p = d:step(0, true, false)
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do p = d:step(dt, true, false) end
	return p
end
local a, b = danceTo(7.05, 1 / 60), danceTo(7.05, 1 / 20)
check(a.phase == b.phase and near(a.abdomenSway, b.abdomenSway, 1e-6) and near(a.fanOpen, b.fanOpen, 1e-6) and near(a.legsWave, b.legsWave, 1e-6), "60 and 20 steps a second give the same pose at the same time")
local slow = Dance.new()
slow:start(true, false)
local sp = slow:step(0, true, false)
for _ = 1, 14 * 60 do sp = slow:step(0.5 / 60, true, false) end -- 14 frames-seconds at half speed: 7 s of dance
local fast = danceTo(7, 1 / 60)
check(near(sp.abdomenSway, fast.abdomenSway, 1e-6) and near(sp.fanOpen, fast.fanOpen, 1e-6) and sp.phase == fast.phase, "slow motion (half the dt) is the same dance at half speed")

-- Stopping: at once, and the pose fades over 0.2 s.
local function dancing(seconds: number): Dance.Dance
	local d = Dance.new()
	d:start(true, false)
	for _ = 1, math.floor(seconds * 60) do d:step(1 / 60, true, false) end
	return d
end
for _, how in { "walk", "air", "stop" } do
	local d = dancing(5.5)
	local before = d:step(1 / 60, true, false)
	check(before.presence > 0.99 and before.fanOpen > 0.9, "(" .. how .. ") mid-dance the fan is open")
	local lastOpen, monotonic, gone = before.fanOpen, true, -1
	for i = 1, 20 do
		local p
		if how == "walk" then p = d:step(1 / 60, true, true)
		elseif how == "air" then p = d:step(1 / 60, false, false)
		else
			if i == 1 then d:stop() end
			p = d:step(1 / 60, true, false)
		end
		if i == 1 then check(not d.active, "(" .. how .. ") the dance is over at once") end
		monotonic = monotonic and p.fanOpen <= lastOpen + 1e-12
		lastOpen = p.fanOpen
		if gone < 0 and p.presence == 0 then gone = i end
	end
	check(monotonic, "(" .. how .. ") the pose eases out, never back")
	check(gone >= 11 and gone <= 13, `({how}) it is gone after 0.2 s (frame {gone})`)
	check(not d:showing(), "(" .. how .. ") nothing shows afterwards")
	check(d:step(1 / 60, true, false).phase == "none", "(" .. how .. ") and no new dance starts by itself")
end

-- ReducedMotion: half the movement, no tremble; the raised fan itself stays.
local peakNormal, peakReduced, shiverNormal, shiverReduced, rumbleReduced = 0, 0, 0, 0, 0
local waveNormal, waveReduced, flapNormal, flapReduced, palpNormal, palpReduced = 0, 0, 1, 1, 0, 0
t = 0
while t < Peacock.loopSeconds do
	local n, q = pose(t, false), pose(t, true)
	peakNormal, peakReduced = math.max(peakNormal, math.abs(n.abdomenSway)), math.max(peakReduced, math.abs(q.abdomenSway))
	shiverNormal, shiverReduced = math.max(shiverNormal, math.abs(n.shiver)), math.max(shiverReduced, math.abs(q.shiver))
	rumbleReduced = math.max(rumbleReduced, q.rumble)
	waveNormal, waveReduced = math.max(waveNormal, n.legsWave), math.max(waveReduced, q.legsWave)
	if t >= f0 and t <= f1 then flapNormal, flapReduced = math.min(flapNormal, n.fanOpen), math.min(flapReduced, q.fanOpen) end
	palpNormal, palpReduced = math.max(palpNormal, n.palp), math.max(palpReduced, q.palp)
	t += STEP
end
check(near(peakReduced / peakNormal, 0.5, 0.02), "reduced motion halves the sway")
check(near(waveReduced / waveNormal, 0.5, 0.02) and near(palpReduced / palpNormal, 0.5, 0.02), "reduced motion halves the leg wave and the palp flick")
check(near((1 - flapReduced) / (1 - flapNormal), 0.5, 0.03), "reduced motion halves the fan-flapping depth")
check(shiverNormal > 0 and shiverReduced == 0 and rumbleReduced > 0.99, "reduced motion stops the tremble but the rumble is still felt")
local rd = Dance.new()
rd.reduced = true
rd:start(true, false)
local rp = rd:step(0, true, false)
for _ = 1, math.floor(5.0 * 60) do rp = rd:step(1 / 60, true, false) end
check(rp.fanOpen > 0.9 and rp.abdomenPitch > math.rad(Peacock.amplitude.raiseDeg) * 0.9, "with reduced motion the fan still goes up and opens")
local sees = false
for i = 1, 120 do if rd:step(1 / 60, true, false).shiver ~= 0 then sees = true end end
check(not sees, "the dance object passes the setting on (no tremble)")

-- ---------------------------------------------------------------- choosing the spider, and the words
check(Choice.start(nil, nil) == "first_spider" and Choice.start("nonsense", 5) == "first_spider", "no choice, or an unknown one, is the first spider")
check(Choice.start("maratus_volans_male", nil) == "maratus_volans_male" and Choice.start(nil, "maratus_volans_male") == "maratus_volans_male", "the Player or Workspace attribute can preselect the peacock spider")
check(Choice.start("first_spider", "maratus_volans_male") == "first_spider", "the Player's attribute (kept for the session) wins over the Workspace's")
check(Choice.next("first_spider") == "maratus_volans_male" and Choice.next("maratus_volans_male") == "myrmarachne_formicaria_female" and Choice.next("myrmarachne_formicaria_female") == "first_spider" and Choice.next("junk") == "first_spider", "C cycles first spider, peacock spider, ant-mimicking spider, and round again")
check(Choice.canDance("maratus_volans_male") and not Choice.canDance("first_spider") and not Choice.canDance("junk"), "only the peacock spider has a dance")
local allKnown = true
for _, id in Choice.ORDER do allKnown = allKnown and Appearances.profiles[id] ~= nil end
check(allKnown and #Choice.ORDER == 3 and Appearances.default == "first_spider" and Choice.ORDER[1] == "first_spider", "all three spiders are real appearances and the default is still the first")

check(ControlText.name("keyboard", "choose") == "C" and ControlText.name("keyboard", "display") == "X", "keyboard: C changes spider, X dances")
check(ControlText.name("gamepad", "choose") == "RB" and ControlText.name("gamepad", "display") == "RB" and ControlText.name("touch", "choose") == "Change" and ControlText.name("touch", "display") == "Dance", "controller RB, touch Change and Dance")
ControlText.setPadStyle("playstation")
check(ControlText.name("gamepad", "choose") == "R1" and ControlText.name("gamepad", "display") == "R1", "a PlayStation controller says R1")
check(Text.change("gamepad", "first_spider") == "R1: become the peacock spider" and Text.displayHint("gamepad", false) == "R1: courtship dance", "PlayStation words in the prompts")
check(string.find(Text.helpExtra("gamepad", true), "R1 courtship dance", 1, true) ~= nil, "PlayStation words on the controls card")
ControlText.setPadStyle("xbox")
check(Text.change("keyboard", "first_spider") == "C: become the peacock spider" and Text.change("keyboard", "maratus_volans_male") == "C: become the ant-mimicking spider" and Text.change("keyboard", "myrmarachne_formicaria_female") == "C: become the first spider", "the crack's hint names the next spider")
check(Text.change("touch", "first_spider") == "Change: become the peacock spider" and Text.touchChange() == "Change" and Text.touchDisplay(false) == "Dance" and Text.touchDisplay(true) == "Stop", "touch words")
check(Text.displayHint("keyboard", false) == "X: courtship dance" and Text.displayHint("keyboard", true) == "X: stop dancing" and Text.dancingLine("keyboard") == "COURTSHIP DANCE    X or move: stop", "the dance's prompt and status line")
check(Text.changed("maratus_volans_male") == "You are the peacock spider now" and Text.changed("first_spider") == "You are the first spider now", "the toast after a change")
check(string.find(Text.helpExtra("keyboard", false), "courtship", 1, true) == nil and string.find(Text.helpExtra("keyboard", true), "X courtship dance", 1, true) ~= nil
	and string.find(Text.helpExtra("keyboard", false), "C change spider", 1, true) ~= nil, "the controls card says nothing of the dance for the first spider")
check(Text.caption(0) == nil and Text.caption(0.01) == nil and (Text.caption(1) :: any).text == "[a fine buzzing through your feet]" and (Text.caption(0.4) :: any).alpha == 0.4, "the felt caption while a rumble-rump is on")
local prompt = LifeText.prompt(false, true, false, false, "keyboard", Text.change("keyboard", "first_spider")) :: any
check(prompt.hint == "Move, E or Q to leave.    C: become the peacock spider", "the resting hint carries the choice")
check((LifeText.prompt(false, true, false, false, "keyboard") :: any).hint == "Move, E or Q to leave." and (LifeText.prompt(true, true, false, true, "keyboard", "C: x") :: any).hint == "The night passes. Move, E or Q to wake.", "no choice before it is offered, none while asleep")
local buttons = {}
for _, b in HudLayout.TOUCH_BUTTONS do buttons[b.action] = b end
check(buttons.Choose ~= nil and buttons.Display ~= nil and not buttons.Choose.right and buttons.Display.right, "touch Change and Dance buttons exist")

print(`PEACOCK passed={passed} failed={failed}`)
if failed > 0 then error("peacock checks failed") end
