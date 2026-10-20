-- (the mating cycle's part of the client smoke run, in a file of its own: the whole smoke run is close to the time one check may take)
-- The mate on the sill and drawn, the courtship meter in the hud, the egg sac, the hatching scene, the ending card and the next generation, through the real
-- client scripts on the box world with stub Roblox services (tests/shim.luau); the words (Shared/UI/MateText) and the stage's pure plan and pose first.
-- Not evidence of rendering, input devices or the engine's physics: nothing here has run in Studio.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local MateText = require("../src/Shared/UI/MateText")
local ControlText = require("../src/Shared/UI/ControlText")
local MateStage = require("../src/Client/MateStage")
local Rules = require("../src/Shared/Data/MatingRules")
local Mating = require("../src/Shared/Life/Mating")
local NotebookPages = require("../src/Shared/Data/NotebookPages")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL client_mating: " .. name .. "\n    " .. tostring(err)) end
end

-- ---------------------------------------------------------------- the words
check("the words: a notice for every beat, the button names of the device in use, the card, the toast, the day tag", function()
	assert(MateText.TITLE == "The sill continues" and MateText.BUTTON == "Carry on", "the card's title and its one button")
	local ctx = { sex = "male", needsDance = false, device = "keyboard" :: ControlText.Device, reason = "" }
	for _, e in { "arrived", "noticed", "driven", "courted", "mated", "sac", "guard_day", "hatched" } do
		local text = MateText.notice(e, ctx)
		assert(text ~= nil and #text > 10, "no words for " .. e)
		local lower = string.lower(text)
		assert(not string.find(lower, "food") and not string.find(lower, "energy"), "the old words in: " .. text)
	end
	assert(MateText.notice("new_mate", ctx) == nil and MateText.notice("nonsense", ctx) == nil, "an event with no words says nothing")
	assert(string.find(MateText.notice("arrived", ctx) :: string, "a male spider", 1, true), "the mate's sex is told")
	assert(string.find(MateText.notice("arrived", { sex = "female", device = "keyboard" }) :: string, "a female spider", 1, true), "female too")
	assert(not string.find(MateText.notice("arrived", ctx) :: string, "Dance", 1, true), "the first spider is not told to dance")
	-- The peacock spider is told its dance key, by device.
	assert(string.find(MateText.arrived("female", true, "keyboard"), "Dance for it (X)", 1, true), MateText.arrived("female", true, "keyboard"))
	assert(string.find(MateText.arrived("female", true, "gamepad"), "(RB)", 1, true), MateText.arrived("female", true, "gamepad"))
	assert(string.find(MateText.arrived("female", true, "touch"), "(Dance)", 1, true), MateText.arrived("female", true, "touch"))
	ControlText.setPadStyle("playstation")
	assert(string.find(MateText.arrived("female", true, "gamepad"), "(R1)", 1, true), MateText.arrived("female", true, "gamepad"))
	assert(string.find(MateText.courtLine("gamepad", true, true, false, 0), "R1", 1, true), "and the courting line")
	ControlText.setPadStyle("xbox")
	-- Why it left.
	assert(MateText.notice("gone", { reason = "dusk" }) ~= nil and MateText.notice("gone", { reason = "rest" }) ~= nil and MateText.notice("gone", { reason = "sex" }) ~= nil, "dusk, rest and sex have words")
	assert(MateText.notice("gone", { reason = "driven" }) == nil and MateText.notice("gone", { reason = "mated" }) == nil, "driven and mated were said already")
	-- The status lines.
	assert(MateText.courtLine("keyboard", false, false, false, 0) == "A visitor is on the sill. Walk close to it.", "far")
	assert(MateText.courtLine("keyboard", true, false, false, 0.4) == "Courting 40%: face it and keep still", MateText.courtLine("keyboard", true, false, false, 0.4))
	assert(MateText.courtLine("keyboard", true, true, false, 0.4) == "Courting: dance in front of it (X)", "the peacock spider must dance")
	assert(MateText.courtLine("keyboard", true, true, true, 0.4) == "Courting 40%: face it and keep still", "and is told the percent once it does")
	assert(MateText.guardLine(1, 2) == "Guarding the eggs: day 1 of 2. Rest in the crack to pass the nights.", MateText.guardLine(1, 2))
	-- The scene's captions.
	assert(MateText.sceneCaption(2) ~= nil and MateText.sceneCaption(12) ~= nil and MateText.sceneCaption(25) == nil and MateText.sceneCaption(-1) == nil, "captions through the scene")
	-- The mating scene's captions (ROBLOX-89): by the beat, device-neutral, the mirror for the male player; nothing before it or after it.
	local function cap(t: number, sex: string): string? local c = MateText.matingCaption(t, sex); return if c then c.text else nil end
	assert(cap(-0.1, "female") == nil and cap(15, "female") == nil and cap(40, "male") == nil, "no caption outside the scene")
	assert(cap(0, "female") == "She turns to face him." and cap(2.99, "female") == "She turns to face him.", "0 to 3 s: she turns to face him")
	assert(cap(0, "male") == "She turns to face you.", "(you, for the male player)")
	assert(cap(3, "female") == "They touch, very lightly, with their front legs and palps." and cap(6.99, "male") == cap(3, "female"), "3 to 7 s: they touch")
	assert(cap(7, "female") == "They settle together, still." and cap(10.99, "male") == "They settle together, still.", "7 to 11 s: they settle together, still")
	assert(cap(11, "female") == "He goes. The sill is yours again." and cap(14.99, "female") == "He goes. The sill is yours again.", "11 to 15 s: he goes")
	assert(cap(11, "male") == "She stays. You go on." and cap(14.99, "male") == "She stays. You go on.", "(she stays, you go on, for the male player)")
	for _, t in { 0, 4, 8, 12 } do
		for _, sex in { "male", "female" } do
			local c = MateText.matingCaption(t, sex) :: any
			assert(c.alpha == 1 and not string.find(c.text, "press", 1, true) and not string.find(string.lower(c.text), "button"), "device-neutral: " .. c.text)
			for _, bad in { "mate", "mating", "sex", "breed", "egg" } do assert(not string.find(string.lower(c.text), bad, 1, true), "child-safe: " .. c.text) end
		end
	end
	assert(MateText.entry(4, "male") == "Day 4: A male came to the sill. The two spiders stayed together a while, and then he went.", MateText.entry(4, "male"))
	assert(MateText.entry(9, "female") == "Day 9: A female was on the sill. The two spiders stayed together a while, and then you went on.", MateText.entry(9, "female"))
	-- The card, the toast, the tag.
	local title, sub, body = MateText.card(9, 6, 0)
	assert(title == "The sill continues", title)
	assert(sub == "9 spiderlings hatched on day 6, climbed into the light and floated away on silk, one by one.", sub)
	assert(string.find(body, "You were generation 1", 1, true) and string.find(body, "carry on as one of them", 1, true), body)
	assert(select(3, MateText.card(9, 6, 2)) ~= body and string.find(select(3, MateText.card(9, 6, 2)), "generation 3", 1, true), "the generation counts up")
	assert(MateText.generationToast(1, 6) == "Generation 2 — hatched on day 6", MateText.generationToast(1, 6))
	assert(MateText.generationToast(2, 11) == "Generation 3 — hatched on day 11", "the toast of the second carry on")
	assert(MateText.dayTag(0) == "" and MateText.dayTag(1) == " | Generation 2", "the day line says nothing of the first family")
end)

-- ---------------------------------------------------------------- the stage's plan and pose: pure
check("the plan: a seeded handful, one by one, deterministic, capped by the tier", function()
	for brood = Rules.broodMin, Rules.broodMax do
		local a = MateStage.plan(914, 0, 6, brood)
		local b = MateStage.plan(914, 0, 6, brood)
		assert(#a == brood and #b == brood, "one plan for each spiderling")
		for i, p in a do
			local q = b[i]
			assert(p.emerge == q.emerge and p.balloon == q.balloon and p.angle == q.angle and p.reach == q.reach and p.speed == q.speed and p.wx == q.wx, "the same seed, the same plan")
			assert(p.emerge >= 0.6 and p.emerge <= 4.3, `out of the sac early: {p.emerge}`)
			assert(p.balloon >= 8.0 and p.balloon <= 20.5 and p.balloon - p.emerge >= 3.5, `balloons between 8 and 20.5 s, after a walk: {p.balloon}`)
			assert(p.balloon + MateStage.TIPTOE_SECONDS + MateStage.LIFT_SECONDS < MateStage.SCENE_SECONDS, "and is gone before the scene ends")
			if i > 1 then
				assert(p.emerge > a[i - 1].emerge - 0.0001 and p.balloon > a[i - 1].balloon, "they come out and go in order, one by one")
			end
		end
	end
	local base = MateStage.plan(914, 0, 6, 9)
	local other = MateStage.plan(914, 0, 7, 9)
	local family = MateStage.plan(914, 1, 6, 9)
	assert(base[1].angle ~= other[1].angle and base[1].angle ~= family[1].angle, "another day or another family: another handful")
	assert(MateStage.countFor(12, "full") == 12 and MateStage.countFor(8, "full") == 8 and MateStage.countFor(12, "low") == 4 and MateStage.countFor(3, "low") == 3, "the tier caps the count: 12 full, 4 low")
	assert(MateStage.SCENE_SECONDS >= 20 and MateStage.SCENE_SECONDS <= 30, "about 20 to 30 seconds")
end)
check("the pose: in the sac, walking on the crack's floor, standing with the thread out, rising and fading, gone", function()
	for _, reduced in { false, true } do
		for _, p in MateStage.plan(914, 0, 6, 12) do
			local first = MateStage.pose(p, 0, reduced)
			assert(first.state == "sac" and first.alpha == 0, "not out yet")
			local seen = { sac = false, walk = false, tiptoe = false, lift = false, gone = false }
			local lastY, lastAlpha, rising = -1, 1, true
			for k = 0, 2600 do
				local t = k * 0.01
				local pose = MateStage.pose(p, t, reduced)
				seen[pose.state] = true
				assert(pose.alpha >= 0 and pose.alpha <= 1, "alpha in range")
				assert(pose.position.X == pose.position.X and pose.heading.Magnitude > 0.5, "finite and facing somewhere")
				if pose.state == "walk" or pose.state == "tiptoe" then
					assert(Layout.inRetreat(pose.position) and pose.position.Y < 0.2, `it stays on the crack's floor: {pose.position}`)
					assert((pose.position - Rules.sacAt).Magnitude < 2.6, "and near the sac")
				end
				if pose.state == "tiptoe" then
					assert(pose.thread ~= nil and pose.thread.Y > pose.position.Y, "the thread goes up from it")
				end
				if pose.state == "lift" then
					assert(pose.position.Y >= lastY - 1e-9, "it only rises")
					assert(pose.alpha <= lastAlpha + 1e-9, "and only fades")
					lastY, lastAlpha = pose.position.Y, pose.alpha
				end
				if pose.state == "gone" then assert(pose.alpha == 0 and pose.thread == nil, "gone is not drawn") end
				if t > MateStage.SCENE_SECONDS then break end
			end
			assert(seen.sac and seen.walk and seen.tiptoe and seen.lift and seen.gone, "every part of the story is told")
			local tail = MateStage.pose(p, MateStage.SCENE_SECONDS, reduced)
			assert(tail.state == "gone", "all gone by the end of the scene")
			local top = MateStage.pose(p, p.balloon + MateStage.TIPTOE_SECONDS + MateStage.LIFT_SECONDS * 0.99, reduced)
			assert(top.position.Y - 0.05 > MateStage.LIFT_HEIGHT * 0.9, `it rose about {MateStage.LIFT_HEIGHT}: {top.position.Y}`)
			local early = MateStage.pose(p, p.balloon + MateStage.TIPTOE_SECONDS + 0.4, reduced)
			assert(early.position.Y - 0.05 < MateStage.LIFT_HEIGHT * 0.1, "and starts gently")
		end
	end
	-- A pure function of the seed and the clock: a scene seen again is the same scene.
	local p = MateStage.plan(914, 0, 6, 9)[4]
	local a, b = MateStage.pose(p, 13.37, false), MateStage.pose(p, 13.37, false)
	assert(a.position == b.position and a.state == b.state and a.alpha == b.alpha, "pose(t) is a function of t")
	-- Reduced motion walks straight: no bend.
	local r1, r2 = MateStage.pose(p, p.emerge + 0.2, true), MateStage.pose(p, p.emerge + 0.4, true)
	local d1 = (r2.position - r1.position)
	assert(d1.Magnitude > 0 and math.abs(r1.heading:Dot(r2.heading) - 1) < 1e-6, "reduced motion: a straight walk")
end)
check("the stage: the sac and the spiderlings are plain display parts, few, and the tiers differ", function()
	for _, detail in { "full", "low" } do
		local stage = MateStage.new(workspace, workspace, detail)
		stage:drawSac(true)
		stage:drawSac(true)
		assert(stage.sac ~= nil and #stage.sacThreads == 3 and stage:partCount() == 4, "one sac and three threads, however often it is asked for")
		assert(math.abs(stage.sac.Size.X - Rules.sacRadius * 2) < 1e-9 and (stage.sac.Position - Rules.sacAt).Magnitude < 1e-9, "where and as big as the numbers say")
		stage:begin(914, 0, 6, 12)
		local want = if detail == "low" then 4 else 12
		assert(#stage.bodies == want and stage:partCount() == 4 + 3 * want, `{detail}: {#stage.bodies} spiderlings`)
		for _, d in workspace:FindFirstChild("Family"):GetDescendants() do
			if d.ClassName == "Part" then
				assert(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch and not d.CastShadow, "a display part: " .. d.Name)
			end
		end
		-- Nothing is drawn for a spiderling that is not out; one that is, is seen; at the end none is.
		stage:step(0.2, false)
		for _, parts in stage.bodies do assert(parts.body.Transparency == 1, "not out yet") end
		stage:step(3.0, false)
		local seen = 0
		for _, parts in stage.bodies do if parts.body.Transparency < 1 then seen += 1 end end
		assert(seen >= 1, "some are out by 3 s")
		-- (ROBLOX-93) A spiderling's head overlaps its abdomen by 0.08 of the abdomen's width (0.011 studs) and is not buried in it: the two balls were 0.014 studs apart, a head floating in front.
		local function overlaps(): (number, number, number)
			local count, least, most = 0, math.huge, -math.huge
			for _, parts in stage.bodies do
				if parts.body.Transparency < 1 then
					count += 1
					local depth = (parts.body.Size.X + parts.head.Size.X) / 2 - (parts.head.Position - parts.body.Position).Magnitude
					least, most = math.min(least, depth), math.max(most, depth)
				end
			end
			return count, least, most
		end
		local count, least, most = overlaps()
		assert(count >= 1 and least > 0.008 and most < 0.015, `{detail}: the head overlaps the abdomen by {least} studs, no gap and not buried ({count} out)`)
		assert(most < (MateStage.BODY * MateStage.HEAD) / 2, "and the head is not swallowed")
		assert(MateStage.BODY_AT < 0 and MateStage.HEAD_AT > 0 and MateStage.HEAD_AT - MateStage.BODY_AT < (1 + MateStage.HEAD) / 2, "(the numbers: the centres are nearer than the radii add up to)")
		for _, more in { 4.0, 3.0, 4.0 } do
			stage:step(more, false)
			count, least, most = overlaps()
			assert(count == 0 or (least > 0.008 and most < 0.015), `{detail}: at {stage.t} s the head still overlaps the abdomen ({least} to {most})`)
		end
		assert(stage.running, "still playing at 14 s")
		local more = stage:step(20.0, false)
		assert(more == false and stage.finished and #stage.bodies == 0 and stage:partCount() == 4, "the scene ends and takes its spiderlings away; the sac stays")
		assert(stage:step(1.0, false) == false, "a finished stage plays nothing")
		stage:reset()
		assert(stage:partCount() == 0 and stage.sac == nil, "reset takes it all away")
		assert(workspace:FindFirstChild("Family"):FindFirstChild("EggSac") == nil, "and the sac is out of the world")
		workspace:FindFirstChild("Family"):Destroy()
	end
end)

check("the mate's drawing (ROBLOX-93): its size is set when it is made and when its factor changes (kept to 0.5 to 2), not every frame; far from the camera it is drawn ten times a second", function()
	local stage = MateStage.new(workspace, workspace, "low")
	local counters = shim.counters
	local at = Vector3.new(0, 0.31, 0)
	local mate = { state = "wander", position = at, previous = at, up = Vector3.yAxis, heading = Vector3.new(0, 0, -1), scale = 0.9 }
	local function draw(cameraAt: Vector3?, focus: Vector3?) stage:drawMate(mate, "first_spider", 1 / 60, true, focus, nil, cameraAt) end
	draw(nil)
	assert(stage.rig ~= nil and math.abs(stage.rig._growth - 1.5 * 0.9) < 1e-9, "made at the adult size times its own factor")
	for _ = 1, 20 do draw(nil) end
	local written = counters.sizeWrites
	for _ = 1, 120 do draw(nil) end
	assert(counters.sizeWrites == written, `a mate standing still (Reduced Motion) has no Size written in 120 frames ({counters.sizeWrites - written} written)`)
	local function factorOf(value: any): number
		mate.scale = value
		draw(nil)
		return stage.rig._growth / 1.5
	end
	written = counters.sizeWrites
	assert(math.abs(factorOf(1.3) - 1.3) < 1e-9 and counters.sizeWrites > written, "a new factor sizes the rig")
	written = counters.sizeWrites
	for _ = 1, 30 do draw(nil) end
	assert(counters.sizeWrites == written, "and then it does not again")
	assert(math.abs(factorOf(3.0) - 2) < 1e-9 and math.abs(factorOf(0.1) - 0.5) < 1e-9 and factorOf(math.huge) == 2 and factorOf(-math.huge) == 0.5, "a factor above 2 is 2 and one below 0.5 is 0.5 (Mate.valid refuses a saved one outside them)")
	assert(factorOf(0 / 0) == 1 and factorOf(nil) == 1 and factorOf("big") == 1, "and one that is missing, not a number or not a number at all is 1")
	-- The drawing: every frame near the camera, in the mating scene or about to be; ten times a second beyond 25 studs.
	mate.scale = 1
	draw(nil)
	local updates = 0
	local real = stage.rig.update
	stage.rig.update = function(self, ...) updates += 1; return real(self, ...) end
	local function run(n: number, cameraAt: Vector3?, focus: Vector3?): number
		updates = 0
		for _ = 1, n do draw(cameraAt, focus) end
		return updates
	end
	local nearBy, farOff = at + Vector3.new(8, 3, 0), at + Vector3.new(60, 3, 0)
	local every = run(120, nearBy)
	assert(every == 120, `near the camera every frame is drawn ({every} of 120)`)
	local tenth = run(120, farOff)
	assert(tenth >= 19 and tenth <= 21, `beyond 25 studs ten times a second ({tenth} of 120 frames, two seconds)`)
	assert(run(120, farOff, at + Vector3.new(1, 0, 0)) == 120, "in the mating scene (it looks at the played spider) every frame, however far")
	mate.state = "attend"
	assert(run(60, farOff) == 60, "as it comes to court")
	mate.state = "pair"
	assert(run(60, farOff) == 60, "and when they are together")
	mate.state = "wander"
	assert(run(60, nil) == 60, "and with no camera to measure from")
	stage.rig.update = nil
	stage:reset()
	local family = workspace:FindFirstChild("Family") -- (the stage's folder: the real client makes its own below)
	if family ~= nil then family:Destroy() end
end)

-- ---------------------------------------------------------------- the real client
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local services = ClientStubs
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
-- The long waits (nights, the courting, the scene) go in frames of 0.1 s (six fixed ticks each, the rate a slow machine gives): the same simulation, a third of the time.
local function wait(seconds: number) for _ = 1, math.ceil(seconds * 10) do frame(0.1) end end
local KEYS = { Feed = "E", Forward = "W", Display = "X", Jump = "Space", Cancel = "Q", Drop = "F", Eye = "V", Choose = "C" }
local function key(action: string, down: boolean)
	local fn = services.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
-- (ROBLOX-113: in Normal after the first day the courtship's and the guard days' status lines are the gentle modes' only: the meter, the notices and the sac say it.
-- Their words are read for a frame with the HUD in the gentle rules: session.rules is what the quiet HUD reads, the sim's own rules are needs.gentle. `normal` is the
-- status Normal shows meanwhile, which must not have them.)
local function gentleStatus(): (string, string)
	local d = ClientStubs.driver
	local normal = find("SpiderPrompts", "Status").Text
	if not find("SpiderPrompts", "Status").Visible then normal = "" end
	local was = d.session.rules
	d.session.rules = "gentle"; frame(1 / 60)
	local text = find("SpiderPrompts", "Status").Text
	d.session.rules = was; frame(1 / 60)
	return text, normal
end
local CRACK = Vector3.new(-25.5, 0.31, 6.0)
local OPEN = Vector3.new(-5, 0.31, -9)

check("the client loads and runs 120 frames", function()
	assert(loaded, "SpiderClient did not load")
	frames(120)
	local d = ClientStubs.driver
	assert(d.mateLegs ~= nil and d.mateLegs.phase == "", "the mating cycle's table is handed over, idle")
	assert(find("SpiderPrompts", "CourtshipBar") ~= nil and find("SpiderPrompts", "CourtshipBar").Visible == false, "the courtship bar is in the hud, hidden")
	assert(workspace:FindFirstChild("MateSpider") == nil and workspace:FindFirstChild("Family") ~= nil and workspace:FindFirstChild("Family"):FindFirstChild("EggSac") == nil, "no mate and no sac yet")
end)

local function sleepThrough(d: any)
	-- From the crack: top up, evening, rest (E), sleep until the morning. Returns when the spider has woken (still resting).
	d.place(CRACK)
	frames(10)
	d.needs.energy = 0.8
	d.life.clock.hour = 19.0
	frames(2)
	if not d.life.resting then key("Feed", true); frames(2); key("Feed", false); frames(2) end
	assert(d.life.resting, "E did not rest")
	local day = d.life.clock.day
	for _ = 1, 160 do
		wait(0.1)
		if d.life.clock.day > day and not d.life.asleep then break end
	end
	assert(d.life.clock.day == day + 1 and not d.life.asleep, `no morning: day {d.life.clock.day}`)
	d.needs.energy = 0.8
	frames(3) -- (the morning's own tick: the guard day and the hatching are the clock's, read once the hour has come)
end

check("a rest by a full-grown, well-fed spider makes a mate come in the morning: it is drawn on the sill, the notice says who", function()
	local d = ClientStubs.driver
	local life = d.life
	life.growth.stage = 3
	d.needs.energy = 0.8
	d.place(CRACK)
	frames(30)
	life.clock.day, life.clock.hour = 2, 12.0
	frames(2)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "E did not rest")
	assert(life.mating ~= nil and life.mating.ready_day == 3 and life.mating.stage == "none", `the rest set the cycle going: {life.mating and life.mating.ready_day}`)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	sleepThrough(d)
	assert(life.clock.day == 3 and life.mate ~= nil and life.mate.state == "away", "morning of day 3; nothing on the sill while the spider rests")
	assert(workspace:FindFirstChild("MateSpider") == nil, "and nothing drawn")
	-- Out of the crack, far from the east end: the mate comes.
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	d.place(OPEN)
	frames(10)
	assert(life.mate.state == "wander", `the mate did not arrive: {life.mate.state} (hour {life.clock.hour})`)
	assert(life.mate.sex == "male", "the first spider is the game's female: its mate is male")
	assert(d.mateLegs.drive ~= nil, "it has legs")
	-- (ROBLOX-92: it arrived at the east end, 30 studs and more from the spider: out of earshot, so not announced; the notice is held until the spider is near)
	assert(not string.find(life.notice, "A visitor", 1, true) and string.find(d.mateLegs.pending or "", "A visitor: a male spider", 1, true), `the arrival is held, not told: "{life.notice}" / "{tostring(d.mateLegs.pending)}"`)
	d.place(life.mate.position + Vector3.new(-9, 0, 0))
	frames(4)
	assert(string.find(life.notice, "A visitor: a male spider", 1, true) and d.mateLegs.pending == nil, `the arrival's notice, told when it came within earshot: "{life.notice}"`)
	d.place(OPEN)
	frames(10)
	local rig = workspace:FindFirstChild("MateSpider")
	assert(rig ~= nil, "the mate is drawn")
	local root = rig:FindFirstChild("Root") or rig:FindFirstChildWhichIsA("BasePart")
	assert(root and (root.Position - life.mate.position).Magnitude < 1.0, "where it stands")
	assert(rig:GetAttribute("GrowthStage") == 3, "at the adult size, scaled by its own factor")
	assert(math.abs(d.mateLegs.stage.rig._growth - 1.5 * life.mate.scale) < 1e-9 and life.mate.scale > 0.85 and life.mate.scale < 0.95, `a male is 0.9 of the look (scale {life.mate.scale})`)
	local walked = 0.0
	local at = life.mate.position
	for _ = 1, 10 do
		frames(30)
		walked = math.max(walked, (life.mate.position - at).Magnitude)
		life.clock.hour = 9
		assert(not Layout.inRetreat(life.mate.position), "the mate went into the retreat")
	end
	assert(walked > 1.5, `it walks the sill ({walked})`)
	assert(find("SpiderPrompts", "CourtshipBar").Visible == false, "and the bar is hidden while it is far away")
end)

-- ROBLOX-106: from here to the second generation the chain after a mating is followed (the courtship, the sac, the guard days, the hatching, carrying on), so the
-- mate's own decision on a full meter (Normal's rule, Life/Mating.accepts) is set aside: with it off a full meter is a mating, as in Easy and Free play. The refusal
-- itself is checked through the client after the chain, and on its own in tests/nature.luau.
Rules.game.on = false
check("courting: close, facing, still, the meter fills in the hud for eight seconds, then the pair are together for a moment and the mate walks off", function()
	local d = ClientStubs.driver
	local life = d.life
	d.place(OPEN)
	frames(5)
	life.clock.hour = 9.0
	local mate = life.mate
	-- The mate stands 1.5 studs in front of the spider (the place heading is +Z).
	local function bring()
		mate.state, mate.elapsed, mate.meter, mate.lost = "attend", 0, 0, 0
		mate.position = d.motor.pos + Vector3.new(0, 0, 1.5)
		mate.previous = mate.position
	end
	bring()
	frames(60)
	life.clock.hour = 9.0
	assert(find("SpiderPrompts", "CourtshipBar").Visible == true, "the courtship bar shows")
	local courting, normalCourting = gentleStatus()
	assert(string.find(courting, "Courting", 1, true) and not string.find(normalCourting, "Courting", 1, true), `the status line: "{courting}" (Normal: "{normalCourting}")`)
	assert(mate.meter > 0.05, `the meter fills ({mate.meter})`)
	local fill = find("SpiderPrompts", "Courtship")
	assert(math.abs(fill.Size.X.Scale - mate.meter) < 0.15, `the bar is the meter ({fill.Size.X.Scale} vs {mate.meter})`)
	-- Moving drains it.
	local before = mate.meter
	key("Forward", true); frames(15); key("Forward", false)
	frames(2)
	assert(mate.meter < before or mate.state ~= "attend", "walking away drains the meter")
	bring()
	d.place(OPEN)
	bring()
	local n = 0
	while life.mating.stage ~= "courted" and n < 10 * 14 do
		wait(0.1)
		n += 1
		life.clock.hour = 9.0
		if mate.state ~= "attend" and mate.state ~= "approach" and mate.state ~= "pair" then bring() end
	end
	assert(life.mating.stage == "courted" and mate.state == "pair", `courted: {life.mating.stage} / {mate.state} after {n / 10} s`)
	assert(n / 10 > 7 and n / 10 < 13, `about eight seconds of courting ({n / 10})`)
	assert(life.notice == MateText.COURTED, `the notice: "{life.notice}"`)
	frames(2)
	assert(find("SpiderPrompts", "Caption").Text == MateText.SCENE_TURN_FEMALE, `the scene's first caption: "{find("SpiderPrompts", "Caption").Text}"`)
	local m = 0
	while life.mating.stage == "courted" and m < 10 * 16 do wait(0.1); m += 1; life.clock.hour = 9.0 end
	assert(life.mating.stage == "mated" and mate.state == "leaving" and m / 10 > 10 and m / 10 < 12, `together about eleven seconds ({m / 10}): {life.mating.stage}`)
	assert(life.notice ~= MateText.MATED and mate.scene == true, `the parting is told when the scene is over, not before: "{life.notice}"`)
	-- It walks off the sill and does not come again.
	local from = mate.position
	local k = 0
	local farthest = 0.0
	local toldAt = nil
	while mate.state == "leaving" and k < 10 * 20 do
		wait(0.1)
		k += 1
		life.clock.hour = 9.0
		farthest = math.max(farthest, (mate.position - from).Magnitude)
		assert(not Layout.inRetreat(mate.position), "the mate went into the retreat")
		if toldAt == nil and mate.scene == false then toldAt = k / 10; assert(life.notice == MateText.MATED, `the notice at the scene's end: "{life.notice}"`) end
	end
	assert(toldAt ~= nil and toldAt > 2.5 and toldAt < 4.6, `the scene's last beat is the walk off: about four seconds ({toldAt})`)
	assert(mate.state == "leaving" and farthest > 3, `the mate is walking off the sill ({farthest} studs in {k / 10} s)`)
	mate.elapsed = Rules.leaveSeconds -- (the rest of the walk is not waited for: Predator/Mate is tested on its own, tests/mating.luau)
	frames(2)
	assert(mate.state == "away", `the mate left the sill: {mate.state}`)
	frames(3)
	assert(workspace:FindFirstChild("MateSpider") == nil, "and is no longer drawn")
	life.clock.hour = 12.0
	frames(60)
	assert(mate.state == "away", "it does not come back")
end)

check("the night's sleep in the crack makes the egg sac: drawn in the crack, in the checkpoint, with the guard days in the hud; the second day, then the hatching", function()
	local d = ClientStubs.driver
	local life = d.life
	assert(life.clock.day == 3 and life.mating.stage == "mated", `{life.clock.day} {life.mating.stage}`)
	sleepThrough(d)
	assert(life.clock.day == 4 and life.mating.stage == "sac" and life.mating.sac_day == 4 and life.mating.guard_day == 1, `the sac: {life.mating.stage}`)
	assert(string.find(life.notice, "egg sac", 1, true) or string.find(life.notice, "Morning", 1, true), `the notice: "{life.notice}"`)
	frames(3)
	local sac = workspace:FindFirstChild("Family"):FindFirstChild("EggSac")
	assert(sac ~= nil, "the sac is drawn")
	assert((sac.Position - Rules.sacAt).Magnitude < 1e-9 and Layout.inRetreat(sac.Position), "in the crack")
	assert(not sac.CanCollide and not sac.CanQuery and not sac.CanTouch and sac.Anchored, "non-collidable, non-queryable decor")
	local guarding, normalGuarding = gentleStatus()
	assert(string.find(guarding, "Guarding the eggs: day 1 of 2", 1, true) and not string.find(normalGuarding, "Guarding", 1, true), `the guard line: "{guarding}" (Normal: "{normalGuarding}")`)
	-- The morning's checkpoint kept the sac (the sleep that made it is in the record).
	local rec = d.currentStore():loadBest()
	assert(rec.ok, "a checkpoint exists")
	local Json = require("../src/Shared/Persistence/Json")
	local text = Json.canonical(rec.record)
	assert(string.find(text, '"sac"', 1, true) ~= nil, "the checkpoint holds the sac stage")
	sleepThrough(d)
	assert(life.clock.day == 5 and life.mating.stage == "guarding" and life.mating.guard_day == 2, `second guard day: {life.mating.stage}`)
	assert(life.notice == MateText.GUARD_DAY or string.find(life.notice, "Morning", 1, true), `the notice: "{life.notice}"`)
	frames(3)
	local second = gentleStatus()
	assert(string.find(second, "day 2 of 2", 1, true), `the guard line: "{second}"`)
	assert(find("SpiderPrompts", "Day").Text:find("Day 5", 1, true) ~= nil and not string.find(find("SpiderPrompts", "Day").Text, "Generation", 1, true), "no generation tag in the first family")
end)

check("the hatching: a scene of about 26 seconds in the crack, spiderlings out of the sac, ballooning away one by one; the camera and the controls are free", function()
	local d = ClientStubs.driver
	local life = d.life
	local legs = d.mateLegs
	sleepThrough(d)
	for _ = 1, 4 do if life.mating.stage ~= "hatched" then frames(2) end end
	assert(life.clock.day == 6 and life.mating.stage == "hatched", `the eggs hatched: {life.mating.stage} on day {life.clock.day}`)
	assert(life.mating.hatch_day == 6 and life.mating.brood >= Rules.broodMin and life.mating.brood <= Rules.broodMax, `a brood of {life.mating.brood}`)
	assert(legs.phase == "scene", `the scene plays: "{legs.phase}"`)
	assert(d.notebook:isOpen("eggs_and_wind"), "the notebook page opened")
	assert(#legs.stage.bodies == life.mating.brood, "a spiderling for each of the brood (full detail)")
	assert(not d.caughtPanel:isShowing(), "no screen has the game: the scene does not trap input")
	assert(life.notice == MateText.HATCHING or string.find(life.notice, "hatching", 1, true) or string.find(life.notice, "checkpoint", 1, true), `the notice: "{life.notice}"`)
	-- The scene's first seconds: some are out, walking on the crack's floor, near the sac.
	wait(4)
	local out, drawn = 0, 0
	for _, parts in legs.stage.bodies do
		if parts.body.Transparency < 1 then
			out += 1
			assert(Layout.inRetreat(parts.body.Position), "in the crack")
		end
	end
	for _, dd in workspace:FindFirstChild("Family"):GetDescendants() do if dd.ClassName == "Part" and dd.Transparency < 1 then drawn += 1 end end
	assert(out >= 2, `spiderlings are out ({out})`)
	assert(find("SpiderPrompts", "Caption").Text == "[tiny rustling from the egg sac]", `the first caption: "{find("SpiderPrompts", "Caption").Text}"`)
	-- The controls are free: W walks the spider (and ends its rest); the scene goes on.
	local p0 = d.motor.pos
	key("Forward", true); frames(40); key("Forward", false); frames(2)
	assert((d.motor.pos - p0).Magnitude > 0.3 and not life.resting, "the spider can walk during the scene")
	assert(legs.phase == "scene", "and the scene goes on")
	d.place(CRACK)
	-- Balloons: later some are lifting on threads.
	local lifted, threads = 0, 0
	local overlapLeast, overlapMost, seenBalls = math.huge, -math.huge, 0
	for _ = 1, 10 * 16 do
		wait(0.1)
		for _, parts in legs.stage.bodies do
			if parts.thread.Transparency < 1 then threads += 1 end
			if parts.body.Position.Y > 0.5 and parts.body.Transparency < 1 then lifted += 1 end
			if parts.body.Transparency < 1 then
				-- (ROBLOX-93) every drawn spiderling, in every beat of the scene: its head overlaps its abdomen a little, no gap and not buried
				local depth = (parts.body.Size.X + parts.head.Size.X) / 2 - (parts.head.Position - parts.body.Position).Magnitude
				overlapLeast, overlapMost, seenBalls = math.min(overlapLeast, depth), math.max(overlapMost, depth), seenBalls + 1
			end
		end
		life.clock.hour = 8.0
	end
	assert(lifted > 0 and threads > 0, `spiderlings rose on their threads ({lifted}, {threads})`)
	assert(seenBalls > 100 and overlapLeast > 0.008 and overlapMost < 0.015, `each spiderling's head overlaps its abdomen throughout ({overlapLeast} to {overlapMost} studs over {seenBalls} sightings)`)
	assert(legs.stage.t > 19 and legs.stage.t < 24, `about 20 s into the scene ({legs.stage.t})`)
	assert(find("SpiderPrompts", "Caption").Text == "[silk threads lift the spiderlings away]", `the second caption: "{find("SpiderPrompts", "Caption").Text}"`)
	assert(not d.caughtPanel:isShowing(), "still no card")
	-- The end of the scene: the card.
	local k = 0
	while legs.phase == "scene" and k < 10 * 12 do wait(0.1); k += 1; life.clock.hour = 8.0 end
	assert(legs.phase == "card" and d.caughtPanel:isShowing(), `the ending card comes ({legs.phase}) after {legs.stage.t} s`)
	assert(legs.stage.t >= MateStage.SCENE_SECONDS - 0.05 and legs.stage.t < MateStage.SCENE_SECONDS + 0.1, "when the scene is over")
	assert(#legs.stage.bodies == 0, "the spiderlings are gone")
	assert(workspace:FindFirstChild("Family"):FindFirstChild("EggSac") ~= nil, "the sac stays, empty, behind the card")
	d.caughtPanel:update(10.0)
	local title = find("SpiderCaught", "Title")
	local carry = find("SpiderCaught", "Carry")
	assert(carry ~= nil and carry.Text == "Carry on", "one button: Carry on")
	local buttons = 0
	for _, dd in gui:FindFirstChild("SpiderCaught"):GetDescendants() do if dd.ClassName == "TextButton" then buttons += 1 end end
	assert(buttons == 1, `only one choice ({buttons})`)
	local texts = {}
	for _, dd in gui:FindFirstChild("SpiderCaught"):GetDescendants() do if dd.ClassName == "TextLabel" then table.insert(texts, dd.Text) end end
	local all = table.concat(texts, "\n")
	assert(string.find(all, "The sill continues", 1, true) and string.find(all, "spiderlings hatched on day 6", 1, true) and string.find(all, "You were generation 1", 1, true), all)
	local _ = title
end)

check("Carry on: the next generation is a spiderling again in the crack, the days go on, the toast says so, the notebook and the look are kept, saves work", function()
	local d = ClientStubs.driver
	local life = d.life
	local legs = d.mateLegs
	local look = d.appearance()
	local oldRig = d.rig()
	assert(d.caughtPanel:choose("Carry"), "the button works")
	frames(3)
	assert(life.generation == 1 and life.growth.stage == 0 and not life.growth:isAdult(), `generation 1, a young juvenile again: {life.generation}`)
	assert(life.mating.stage == "none" and life.mate.state == "away" and legs.phase == "", "the cycle is new")
	assert(life.clock.day == 6, "the days of the sill go on")
	assert(math.abs(d.needs.energy - Rules.freshEnergy) < 0.05, `a fresh reserve ({d.needs.energy})`)
	assert(d.rig() ~= oldRig and d.rig().model:GetAttribute("GrowthStage") == 0 and d.rig()._growth == 1, "the rig is built again at the first stage")
	assert(d.appearance() == look, "the same look")
	assert(Layout.inRetreat(d.motor.pos), "in the crack")
	assert(not d.caughtPanel:isShowing(), "the card is gone")
	assert(find("SpiderPrompts", "Toast").Text == "Generation 2 — hatched on day 6", `the toast: "{find("SpiderPrompts", "Toast").Text}"`)
	assert(find("SpiderPrompts", "Toast").Visible, "and it shows")
	assert(string.find(find("SpiderPrompts", "Day").Text, "Generation 2", 1, true) ~= nil, `the day line: "{find("SpiderPrompts", "Day").Text}"`)
	assert(workspace:FindFirstChild("Family"):FindFirstChild("EggSac") == nil, "the old sac is gone")
	assert(d.notebook:isOpen("eggs_and_wind") and d.notebook:isOpen("bold_jumper"), "the notebook is the player's own: kept")
	-- The sill goes on: it moves, saves, and a rest keeps this generation.
	local p0 = d.motor.pos
	key("Forward", true); frames(30); key("Forward", false); frames(2)
	assert((d.motor.pos - p0).Magnitude > 0.2, "the spiderling walks")
	d.place(CRACK)
	frames(20)
	life.clock.hour = 12.0
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "and rests")
	assert(life.checkpointResult ~= nil and life.checkpointResult.ok, "the rest was kept")
	local rec = d.currentStore():loadBest()
	assert(rec.ok and rec.record ~= nil, "a checkpoint of the new generation")
	-- Returning to it brings the generation back, with no mate or sac.
	life.generation = 7
	d.returnToCheckpoint()
	frames(3)
	assert(life.generation == 1 and life.mating.stage == "none", `the checkpoint holds generation 1 (got {life.generation})`)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
end)

check("a record restored into the hatching goes straight to the ending card, and carrying on again counts the generation up", function()
	local d = ClientStubs.driver
	local life = d.life
	local legs = d.mateLegs
	if d.caughtPanel:isShowing() then d.caughtPanel:hide() end
	life.growth.stage = 3
	life.mating = Mating.normalize({ stage = "hatched", sac_day = 4, guard_day = 2, hatch_day = 9, hatch_hour = 7.0, brood = 11, mates = 1 })
	life.mate = nil
	life.clock.day = 9
	d.place(CRACK)
	frames(3)
	assert(legs.phase == "card" and d.caughtPanel:isShowing(), `at the card at once ({legs.phase})`)
	assert(legs.stage.running == false and #legs.stage.bodies == 0, "with no scene")
	d.caughtPanel:update(10.0)
	local texts = {}
	for _, dd in gui:FindFirstChild("SpiderCaught"):GetDescendants() do if dd.ClassName == "TextLabel" then table.insert(texts, dd.Text) end end
	assert(string.find(table.concat(texts, "\n"), "11 spiderlings hatched on day 9", 1, true), "the brood and the day are the record's")
	assert(d.caughtPanel:choose("Carry"), "carry on")
	frames(3)
	assert(life.generation == 2 and life.growth.stage == 0 and life.mating.stage == "none", "the next generation after that")
	assert(find("SpiderPrompts", "Toast").Text == "Generation 3 — hatched on day 9", find("SpiderPrompts", "Toast").Text)
	assert(string.find(find("SpiderPrompts", "Day").Text, "Generation 3", 1, true) ~= nil, "and the day line")
end)

-- ---------------------------------------------------------------- the mating scene (ROBLOX-89)
-- The scene itself through the real client: the camera's two-shot and its quarter-orbit, the locked controls and the skip, the cues to both rigs, the music's swell, the
-- captions, the held parting notice, the notebook's line, the refused rest, the wasp, the female mate's mirror and Reduced Motion. Not evidence of how it looks or sounds.
local Mate = require("../src/Shared/Predator/Mate")
local MatingScene = require("../src/Shared/Life/MatingScene")
local player: any = game:GetService("Players").LocalPlayer

Rules.game.on = true -- (ROBLOX-106: Normal's rule again, see above)
check("in Normal a full meter is the mate's to decide (ROBLOX-106): a thin spider is refused in MateText's words, the mate walks off for the day, the cycle waits", function()
	local d = ClientStubs.driver
	local life = d.life
	if d.caughtPanel:isShowing() then d.caughtPanel:hide() end
	assert(d.session.rules == "standard", "Normal")
	life.growth.stage = 3
	life.clock.day += 1
	d.place(OPEN)
	frames(5)
	life.clock.hour = 9.0
	local mate = Mate.new()
	mate.sex, mate.scale = "male", 1
	mate.state, mate.elapsed, mate.meter, mate.lost = "attend", 0, 0, 0
	mate.position = d.motor.pos + Vector3.new(0, 0, 1.5)
	mate.previous, mate.heading, mate.up = mate.position, -Vector3.zAxis, Vector3.yAxis
	life.mate = mate
	d.mateLegs.drive = nil
	life.mating = Mating.normalize({ stage = "none", ready_day = 1, mates = 1, visits = 1, visit_day = life.clock.day })
	local base = Rules.game.base
	Rules.game.base = 1e-9 -- (the draw always refuses; which words is the spider's condition against the court's quality)
	local n = 0
	while mate.state ~= "leaving" and life.mating.stage == "none" and n < 10 * 16 do
		wait(0.1)
		n += 1
		life.clock.hour = 9.0
		d.needs.energy = 0.5 -- (condition 0.33: thin)
	end
	Rules.game.base = base
	assert(life.mating.stage == "none" and mate.state == "leaving" and mate.reason == "rejected", `refused: {life.mating.stage} / {mate.state} / {mate.reason} after {n / 10} s`)
	assert(n / 10 > 4 and n / 10 < 13, `on a full meter ({n / 10} s)`)
	assert(life.mating.courts == 1 and life.mating.rejections == 1 and life.mating.away_day == life.clock.day, "counted, and away for the day")
	assert(life.notice == MateText.rejected("male", "thin"), `the words: "{life.notice}"`)
	mate.elapsed = Rules.leaveSeconds
	frames(3)
	assert(mate.state == "away" and life.mating.stage == "none", `gone, and the cycle waits for another day: {mate.state}`)
	assert(find("SpiderPrompts", "CourtshipBar").Visible == false, "the bar is hidden")
	life.mate = nil
	life.mating = Mating.normalize({ stage = "none" })
end)

-- A fresh courtship set up on the open floor and played to the moment the pair are together. `sex`: the mate's; `dance`: the player owes a dance (the peacock spider).
local function court(d: any, sex: string, dance: boolean): any
	local life = d.life
	life.growth.stage = 3
	life.clock.day += 1
	d.place(OPEN)
	frames(5)
	life.clock.hour = 9.0
	local mate = Mate.new()
	mate.sex, mate.scale = sex, 1
	local function bring()
		mate.state, mate.elapsed, mate.meter, mate.lost = "attend", 0, 0, 0
		mate.position = d.motor.pos + Vector3.new(0, 0, 1.5)
		mate.previous = mate.position
		mate.heading, mate.up = -Vector3.zAxis, Vector3.yAxis
	end
	bring()
	life.mate = mate
	d.mateLegs.drive = nil
	life.mating = Mating.normalize({ stage = "none", ready_day = 1, mates = 1, visits = 1, visit_day = life.clock.day })
	local n = 0
	while mate.scene ~= true and n < 10 * 20 do
		if dance and not d.dance().active then key("Display", true); frames(1); key("Display", false) end
		wait(0.1)
		n += 1
		life.clock.hour = 9.0
		if mate.scene ~= true and mate.state ~= "attend" and mate.state ~= "approach" and mate.state ~= "pair" then bring() end
	end
	assert(mate.scene == true and mate.state == "pair" and life.mating.stage == "courted", `courted: {mate.state} {life.mating.stage} after {n / 10} s (resting {tostring(life.resting)}, asleep {tostring(life.asleep)}, meter {mate.meter})`)
	return mate
end

-- Plays on (in tenths of a second) until the scene's own clock reaches `t`.
local function untilScene(d: any, t: number)
	local k = 0
	while d.mateLegs.couple.active and d.mateLegs.couple.t < t and k < 10 * 20 do wait(0.1); k += 1; d.life.clock.hour = 9.0 end
end
local function caption(): string local c = find("SpiderPrompts", "Caption"); return if c.Visible then c.Text else "" end
local function flatAngle(a: Vector3, b: Vector3): number
	local fa, fb = Vector3.new(a.X, 0, a.Z).Unit, Vector3.new(b.X, 0, b.Z).Unit
	return math.deg(math.acos(math.clamp(fa:Dot(fb), -1, 1)))
end

local runMusic: any = nil
check("the scene: the camera eases into a two-shot and orbits a quarter, the controls are locked, a skip after four seconds parts them and everything goes back", function()
	local d = ClientStubs.driver
	local life, legs, cam, snd = d.life, d.mateLegs, d.cam, d.soundscape
	runMusic = snd.music
	assert(not legs.couple.active and cam.shot == nil and not cam:shotActive() and snd.swell == 1, "before: nothing of the scene")
	local entriesBefore = #d.notebook:entriesFor("eggs_and_wind")
	local mate = court(d, "male", false)
	local day = life.clock.day
	assert(legs.couple.active and legs.couple.mateSex == "male" and legs.couple.plan ~= nil and legs.couple.plan.day == day, "the scene began at the courted event")
	assert(legs.couple.plan.playerSex == "female" and legs.couple.plan.mateSex == "male", "the first spider is the game's female")
	local t0 = legs.couple.t
	assert(t0 >= 0 and t0 < 1, `scene seconds from the simulation ({t0})`)
	assert(life.notice == MateText.COURTED, `the courted notice: "{life.notice}"`)
	assert(not cam.eyeView, "the eye view is off")
	-- The camera: easing in over 0.8 s from where it was.
	assert(cam.shot ~= nil and cam:shotActive() and cam.shotT < 0.5, `easing in (shotT {cam.shotT})`)
	local before = cam.camera.CFrame.Position
	local k0 = cam.shotT
	frames(24) -- 0.4 s
	assert(cam.shotT - k0 > 0.45 and cam.shotT - k0 < 0.55 and cam.shotT < 1, `it eases in over 0.8 s: half of it in 0.4 s ({k0} then {cam.shotT})`)
	frames(30) -- 0.9 s in all
	assert(cam.shotT == 1, `held after 0.8 s ({cam.shotT})`)
	local mid = (d.motor.pos + mate.position) * 0.5
	local cf = cam.camera.CFrame
	local toMid = (mid - cf.Position)
	assert(toMid.Unit:Dot(cf.LookVector) > 0.93, `looking at the pair ({toMid.Unit:Dot(cf.LookVector)})`)
	assert(cf.Position.Y > mid.Y + 1.0 and toMid.Magnitude > 3.5 and toMid.Magnitude < 14, `from slightly above, at a distance of {toMid.Magnitude}`)
	assert((cf.Position - before).Magnitude > 0.5, "and it moved")
	assert(caption() == "She turns to face him.", `the first caption: "{caption()}"`)
	-- The controls are the scene's: walking, feeding, dropping, the eye view, the dance and a jump are nothing.
	local p0 = d.motor.pos
	key("Forward", true); frames(40); key("Forward", false)
	key("Feed", true); frames(2); key("Feed", false)
	key("Drop", true); frames(2); key("Drop", false)
	key("Eye", true); frames(2); key("Eye", false)
	key("Display", true); frames(2); key("Display", false)
	key("Jump", true); frames(3); key("Jump", false); frames(2)
	key("Cancel", true); frames(3); key("Cancel", false); frames(2)
	assert((d.motor.pos - p0).Magnitude < 0.05 and not life.resting and not cam.eyeView and d.motor.mode == "attached", "the spider did not move, rest, drop or look through its eyes")
	assert(mate.state == "pair" and legs.couple.active and legs.couple.t < 4, `a skip before four seconds is nothing (scene {legs.couple.t})`)
	-- Cues: the touch at three seconds, on both rigs.
	untilScene(d, 3.4)
	local mine, theirs = d.rig()._living, legs.stage.rig._living
	assert(mine ~= nil and theirs ~= nil, "both rigs have living motion (the mate's for the same parts as the player's)")
	assert(mine.meetT ~= nil and theirs.meetT ~= nil and mine.meetLen == 4 and theirs.meetLen == 4, "the meet cue reached both rigs, four seconds long")
	assert(caption() == MateText.SCENE_TOUCH, `the second caption: "{caption()}"`)
	untilScene(d, 4.6)
	assert(mine.meetW > 0.5 and theirs.meetW > 0.5, `the reach is under way ({mine.meetW}, {theirs.meetW})`)
	-- The orbit, and the music.
	local first = cam.camera.CFrame.Position - mid
	assert(snd.swell > 1.59 and snd.swell < 1.61, `the music has swelled to 1.6 ({snd.swell})`)
	if runMusic ~= nil then assert(math.abs(runMusic.Volume - 0.32 * 1.6) < 0.01, `and the music voice is at 1.6 of its level ({runMusic.Volume})`) end -- (ROBLOX-102 raised the music to 0.32; this pin was left at 0.18)
	untilScene(d, 7.3)
	assert(mine.settleT ~= nil and theirs.settleT ~= nil and mine.settleLen == 8 and theirs.settleLen == 4, "the settle cue: the male's four seconds, the female's eight")
	assert(caption() == MateText.SCENE_SETTLE, `the third caption: "{caption()}"`)
	untilScene(d, 9.0)
	assert(mine.pose.breath > 1.2 and theirs.pose.breath > 1.2 and mine.pose.settle > 0.3, `the abdomens are breathing deeper ({mine.pose.breath}, {theirs.pose.breath})`)
	local later = cam.camera.CFrame.Position - ((d.motor.pos + mate.position) * 0.5)
	local turned = flatAngle(first, later)
	assert(turned > 25 and turned < 80, `the camera has gone round the pair by {turned} degrees between 4.6 s and 9 s`)
	assert(d.mateLegs.stage.rig ~= nil and legs.couple.focus ~= nil, "the pair look at each other")
	-- A rest cannot land inside it.
	local why = life.save()
	assert(not why.ok and string.find(why.message, "together", 1, true) ~= nil, `a rest is refused: {why.message}`)
	-- A skip after four seconds.
	assert(legs.couple.t > 4, "(past four seconds)")
	local entries = #d.notebook:entriesFor("eggs_and_wind")
	key("Jump", true); frames(2); key("Jump", false)
	assert(mate.state == "leaving" and mate.reason == "mated" and life.mating.stage == "mated" and mate.scene == false, "the pair part at once: the mate walks off")
	assert(not legs.couple.active and cam.shot == nil, "the scene is over")
	assert(life.notice == MateText.MATED, `the parting is told: "{life.notice}"`)
	assert(mine.meetT == nil and mine.settleT == nil and theirs.meetT == nil and theirs.settleT == nil, "both rigs let go of their poses")
	local list = d.notebook:entriesFor("eggs_and_wind")
	assert(#list == entries + 1 and list[#list].day == day and list[#list].text == MateText.entry(day, "male"), `the notebook has its line ({#list} entries)`)
	-- Everything goes back: the camera over 0.8 s, the music over 1 s; the controls are free.
	frames(24)
	assert(cam.shotT > 0.4 and cam.shotT < 0.6 and cam:shotActive(), `the camera eases out ({cam.shotT})`)
	frames(30)
	assert(cam.shotT == 0 and not cam:shotActive(), "and is the player's again")
	wait(1.2)
	assert(snd.swell == 1, `the music is back ({snd.swell})`)
	local p1 = d.motor.pos
	key("Forward", true); frames(40); key("Forward", false)
	assert((d.motor.pos - p1).Magnitude > 0.3, "the controls are free")
	assert(caption() ~= MateText.SCENE_GOES, "(no scene caption left)")
	-- The departure still happens.
	local from = mate.position
	local farthest = 0.0
	for _ = 1, 30 do wait(0.1); life.clock.hour = 9.0; farthest = math.max(farthest, (mate.position - from).Magnitude) end
	assert(mate.state == "leaving" and farthest > 2, `the mate walks off the sill ({farthest} studs)`)
	mate.elapsed = Rules.leaveSeconds
	frames(3)
	assert(mate.state == "away" and entriesBefore + 1 == #d.notebook:entriesFor("eggs_and_wind"), "and is gone; one line in the notebook")
end)

check("the scene played to its end: the notice is held, the walk off is the last beat, the camera and music go back; Reduced Motion is a static two-shot", function()
	local d = ClientStubs.driver
	local life, legs, cam, snd = d.life, d.mateLegs, d.cam, d.soundscape
	player:SetAttribute("ReducedMotion", true)
	frames(3)
	local mate = court(d, "male", false)
	local day = life.clock.day
	untilScene(d, 2.0)
	local cf2 = cam.camera.CFrame.Position
	assert(cam.shotT == 1, "in the shot")
	untilScene(d, 3.4)
	local mine, theirs = d.rig()._living, legs.stage.rig._living
	frames(3)
	assert(mine.meetW == 1 and theirs.meetW == 1, `Reduced Motion: the reach is a held pose, at once ({mine.meetW}, {theirs.meetW})`)
	untilScene(d, 7.3)
	frames(3)
	assert(mine.settleW == 1 and theirs.settleW == 1, "and so is the settle")
	untilScene(d, 10.5)
	local cf10 = cam.camera.CFrame.Position
	assert((cf10 - cf2).Magnitude < 0.05, `Reduced Motion: no orbit, the two-shot is static (moved {(cf10 - cf2).Magnitude})`)
	-- the walk off
	untilScene(d, 11.5)
	assert(mate.state == "leaving" and mate.scene == true and legs.couple.active, "the pause is over and the mate is walking: the last beat")
	assert(caption() == MateText.SCENE_GOES, `the last caption: "{caption()}"`)
	assert(life.notice ~= MateText.MATED, "the parting is not told over the scene")
	local why = life.save()
	assert(not why.ok and string.find(why.message, "together", 1, true), "a rest is refused in the walk off too")
	local k = 0
	while legs.couple.active and k < 10 * 8 do wait(0.1); k += 1; life.clock.hour = 9.0 end
	assert(not legs.couple.active and mate.scene == false and mate.state == "leaving", `the scene ends with the walk off ({k / 10} s later)`)
	assert(life.notice == MateText.MATED, `and the parting is told: "{life.notice}"`)
	assert(caption() == "", "the caption goes")
	wait(1.0)
	assert(not cam:shotActive() and cam.shotT == 0, "the camera is back")
	wait(0.5)
	assert(snd.swell == 1, "and the music")
	local lines = d.notebook:entriesFor("eggs_and_wind")
	assert(#lines >= 2 and lines[#lines].day == day and lines[#lines - 1].day ~= day, `a second line in the notebook, another day ({#lines} lines, last day {lines[#lines] and lines[#lines].day} of {day})`)
	mate.elapsed = Rules.leaveSeconds
	frames(3)
	player:SetAttribute("ReducedMotion", nil)
	frames(3)
end)

check("the scene and a wasp: the controls are the player's the moment it comes, the duck wins over the swell", function()
	local d = ClientStubs.driver
	local life, legs, cam, snd = d.life, d.mateLegs, d.cam, d.soundscape
	local mate = court(d, "male", false)
	untilScene(d, 1.5)
	wait(1.2)
	assert(snd.swell > 1.5, "swelling")
	d.wasp.enabled = true
	assert(d.wasp:force(life.clock.day, "floor_middle"), "the wasp could not be brought")
	frames(3)
	assert(not legs.couple.active and mate.scene == false and mate.state == "leaving" and life.mating.stage == "mated", "a wasp's visit ends the scene at once, whatever the scene's clock")
	assert(d.wasp:isVisiting(), "(it is visiting)")
	local p0 = d.motor.pos
	key("Forward", true); frames(30); key("Forward", false)
	assert((d.motor.pos - p0).Magnitude > 0.2 or d.life.lifeOver, "the player can move again")
	wait(1.2)
	assert(snd.swell == 1 and snd.duck < 0.99, `the music is ducked and not swelled (swell {snd.swell}, duck {snd.duck})`)
	d.wasp:clearVisit()
	wait(1.2)
	mate.elapsed = Rules.leaveSeconds
	frames(3)
end)

-- ---------------------------------------------------------------- the audit, part two (ROBLOX-92)
local PeacockText = require("../src/Shared/UI/PeacockText")
local LifeText = require("../src/Shared/UI/LifeText")
local function statusText(): string return find("SpiderPrompts", "Status").Text end
local function skipScene(d: any)
	key("Jump", true); frames(2); key("Jump", false); frames(2)
end

check("the scene says how to leave it: from four seconds a status line and the touch Skip button, by device; the Captions setting does not hide it; a snap clears the two-shot's ease", function()
	local d = ClientStubs.driver
	local legs, cam = d.mateLegs, d.cam
	local touch = gui:FindFirstChild("SpiderTouch")
	assert(touch ~= nil and touch:FindFirstChild("Jump") ~= nil, "(the touch buttons are there)")
	local mate = court(d, "male", false)
	untilScene(d, 1.5)
	frames(3)
	assert(not string.find(statusText(), "part", 1, true), `nothing to say before four seconds: "{statusText()}"`)
	assert(touch:FindFirstChild("Jump").Text == "Jump", "and the Jump button is the Jump button")
	untilScene(d, 4.3)
	frames(3)
	assert(MateText.skipLine("keyboard") == "Space or Q: part" and string.find(statusText(), "Space or Q: part", 1, true), `from four seconds: "{statusText()}"`)
	d.setDevice("gamepad")
	frames(3)
	assert(MateText.skipLine("gamepad") == "A or B: part" and string.find(statusText(), "A or B: part", 1, true), `a controller: "{statusText()}"`)
	ControlText.setPadStyle("playstation")
	assert(MateText.skipLine("gamepad") == "Cross or Circle: part", MateText.skipLine("gamepad"))
	ControlText.setPadStyle("xbox")
	d.setDevice("touch")
	frames(3)
	assert(MateText.skipLine("touch") == "Skip or Cancel: part" and string.find(statusText(), "Skip or Cancel: part", 1, true), `touch: "{statusText()}"`)
	assert(touch:FindFirstChild("Jump").Text == MateText.TOUCH_SKIP and MateText.TOUCH_SKIP == "Skip", "and the Jump button says Skip")
	assert(touch:FindFirstChild("Cancel").Text == "Cancel", "(Cancel is Cancel)")
	player:SetAttribute("Captions", "off")
	frames(3)
	assert(string.find(statusText(), "Skip or Cancel: part", 1, true), "turning the captions off does not hide it: it is a status line, not a sound")
	player:SetAttribute("Captions", nil)
	d.setDevice("keyboard")
	frames(3)
	skipScene(d)
	assert(not legs.couple.active and mate.state == "leaving", "(skipped)")
	assert(not string.find(statusText(), "part", 1, true), `the line goes with the scene: "{statusText()}"`)
	d.setDevice("touch")
	frames(3)
	assert(touch:FindFirstChild("Jump").Text == "Jump", "and so does the Skip label")
	d.setDevice("keyboard")
	-- the two-shot is easing out; a snap (a return to a rest, a respawn) ends the ease for good
	frames(6)
	assert(cam.shotT > 0 and cam.shotT < 1 and cam.lastShot ~= nil, `(easing out: {cam.shotT})`)
	cam:snap()
	assert(cam.shotT == 0 and cam.lastShot == nil and cam.inspectT == 0 and cam.inspectLast == nil, "a snap zeroes the shot's and the close look's eases")
	frames(3)
	assert(not cam:shotActive(), "nothing of the two-shot is left")
	mate.elapsed = Rules.leaveSeconds
	frames(3)
end)

check("Reduced Motion cuts the two-shot in and out (ROBLOX-92), where it eased over 0.8 s", function()
	local d = ClientStubs.driver
	local legs, cam = d.mateLegs, d.cam
	player:SetAttribute("ReducedMotion", true)
	frames(3)
	local mate = court(d, "male", false)
	frames(2)
	assert(legs.couple.active and cam.shotT == 1 and cam:shotActive(), `in at once ({cam.shotT})`)
	untilScene(d, 4.3)
	skipScene(d)
	assert(not legs.couple.active and cam.shot == nil, "(skipped)")
	assert(cam.shotT == 0 and not cam:shotActive(), `and out at once ({cam.shotT})`)
	player:SetAttribute("ReducedMotion", nil)
	frames(3)
	mate.elapsed = Rules.leaveSeconds
	frames(3)
end)

check("a close look begun from the eye view gives way to the mating scene: the two-shot plays, the skip frees the controls, and the eye view stays off", function()
	local d = ClientStubs.driver
	local legs, cam = d.mateLegs, d.cam
	d.place(OPEN)
	frames(30)
	d.life.clock.hour = 9.0
	cam:setEyeView(true)
	assert(cam.eyeView, "(the eye view is on)")
	assert(d.spiderPick.begin() == nil and d.spiderPick.inspecting and cam.inspectWasEye == true, "(a close look from the eye view)")
	local mate = court(d, "male", false)
	assert(legs.couple.active, "the scene began")
	assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectWasEye == false, "the close look ended first, and will not give the eye view back")
	frames(60)
	assert(not cam.eyeView and cam.shot ~= nil and cam.shotT == 1, `the two-shot plays, not the eye view (eye view {tostring(cam.eyeView)}, shot {cam.shotT})`)
	local toMid = ((d.motor.pos + mate.position) * 0.5) - cam.camera.CFrame.Position
	assert(toMid.Unit:Dot(cam.camera.CFrame.LookVector) > 0.9, "the camera is looking at the pair")
	untilScene(d, 4.3)
	skipScene(d)
	assert(not legs.couple.active and not cam.eyeView, "skipped: the scene is over")
	frames(60)
	local p0 = d.motor.pos
	key("Forward", true); frames(40); key("Forward", false)
	assert((d.motor.pos - p0).Magnitude > 0.3, "the controls are free at once, not after 15 s")
	wait(1.0)
	assert(not cam.eyeView and not cam:shotActive(), "and the eye view is still off afterwards (it is the player's to turn on again)")
	mate.elapsed = Rules.leaveSeconds
	frames(3)
end)

check("a close look begun from the eye view gives way to the hatching, which cancels the eye view's return too", function()
	local d = ClientStubs.driver
	local life, legs, cam = d.life, d.mateLegs, d.cam
	local savedMating, savedMate = life.mating, life.mate
	d.place(CRACK)
	frames(30)
	life.clock.hour = 12.0
	cam:setEyeView(true)
	assert(d.spiderPick.begin() == nil and d.spiderPick.inspecting and cam.inspectWasEye == true, "(a close look from the eye view in the crack)")
	life.mating = Mating.normalize({ stage = "hatched", hatch_day = life.clock.day, brood = 6, mates = 1, visits = 1 })
	legs.begin(true)
	assert(legs.phase == "scene", "the hatching plays")
	assert(not d.spiderPick.inspecting and cam.inspect == nil and cam.inspectWasEye == false and not cam.eyeView, "the close look is over and gives no eye view back")
	frames(30)
	assert(not cam.eyeView, "and the eye view stays off")
	legs.reset()
	life.mating, life.mate = savedMating, savedMate
	frames(3)
end)

check("the Spider settings row is refused during the mating scene and the hatching, in its own words, like the close look; it works again after (ROBLOX-92)", function()
	local d = ClientStubs.driver
	local life, legs = d.life, d.mateLegs
	local mate = court(d, "male", false)
	local before = d.appearance()
	assert(not d.spiderPick.safe(), "(not safe to change in the scene)")
	local said = d.spiderPick.fromSettings("maratus_volans_male")
	assert(said == PeacockText.NOT_NOW and d.appearance() == before, `refused in the mating scene: "{tostring(said)}"`)
	assert(find("SpiderPrompts", "Toast").Text == PeacockText.NOT_NOW, "and the toast says it")
	untilScene(d, 4.3)
	skipScene(d)
	frames(30)
	assert(not legs.couple.active and mate.state == "leaving", "(the scene is over)")
	legs.phase = "scene" -- the hatching
	assert(d.spiderPick.fromSettings("maratus_volans_male") == PeacockText.NOT_NOW and d.appearance() == before, "refused in the hatching")
	legs.phase = ""
	frames(3)
	d.motor:cancelWalk()
	assert(d.spiderPick.safe(), "(safe again)")
	assert(d.spiderPick.fromSettings("maratus_volans_male") == PeacockText.changed("maratus_volans_male") and d.appearance() == "maratus_volans_male", "allowed after")
	assert(d.spiderPick.fromSettings(before) == PeacockText.changed(before) and d.appearance() == before, "(back to the first spider)")
	-- asleep and a wasp's visit are refused the same way
	life.asleep = true
	assert(d.spiderPick.fromSettings("maratus_volans_male") == PeacockText.NOT_NOW, "refused asleep")
	life.asleep = false
	mate.elapsed = Rules.leaveSeconds
	frames(3)
end)

check("a visitor far off is not announced, and one that arrives out of earshot is told when it comes near; the courting line is the same rule (ROBLOX-92)", function()
	local d = ClientStubs.driver
	local life, legs = d.life, d.mateLegs
	local Heard = require("../src/Shared/UI/Heard")
	assert(Heard.within(10, false) and Heard.within(18, false) and not Heard.within(19, false) and Heard.within(24, true) and not Heard.within(25, true), "the rival's rule: 18 studs by ear, 24 in sight")
	d.place(CRACK)
	frames(10)
	life.clock.hour = 12.0
	life.mating = Mating.normalize({ stage = "none" })
	local mate = Mate.new()
	mate.sex, mate.scale, mate.state, mate.elapsed, mate.meter, mate.lost = "male", 1, "attend", 0, 0, 0
	mate.position = d.motor.pos + Vector3.new(60, 0, 0)
	mate.previous, mate.heading, mate.up = mate.position, -Vector3.xAxis, Vector3.yAxis
	life.mate = mate
	legs.drive = nil
	life.notice, life.noticeSeconds, legs.pending = "", 0, nil
	legs.event("arrived", { needsDance = false })
	assert(life.notice == "" and legs.pending ~= nil, `a far arrival is not announced ({life.notice})`)
	legs.event("noticed", {})
	assert(life.notice == "", "nor its noticing the spider")
	frames(3)
	assert(not string.find(statusText(), "visitor", 1, true), `no courting line for a visitor too far to hear: "{statusText()}"`)
	-- it comes near: the arrival is told, and the line shows
	mate.position = d.motor.pos + Vector3.new(0, 0, 9)
	mate.previous = mate.position
	frames(3)
	assert(string.find(life.notice, "male spider", 1, true) ~= nil and legs.pending == nil, `told when near: "{life.notice}"`)
	local near = gentleStatus()
	assert(string.find(near, "visitor", 1, true) or string.find(near, "Courting", 1, true), `and the courting line: "{near}"`)
	-- leaving unheard says nothing; leaving heard does
	life.notice, life.noticeSeconds = "", 0
	mate.reason = "dusk"
	legs.event("gone", {})
	assert(life.notice == MateText.gone("dusk"), `a heard leaving is told: "{life.notice}"`)
	life.notice, life.noticeSeconds = "", 0
	mate.position = d.motor.pos + Vector3.new(60, 0, 0)
	legs.event("gone", {})
	assert(life.notice == "" and legs.pending == nil, "an unheard one is not")
	legs.event("arrived", { needsDance = false })
	legs.event("gone", {})
	assert(legs.pending == nil, "and a visitor that has gone is no longer waiting to be told of")
	-- the mate's snapshot of the spider is one table filled again each tick, not a clone of the rival's every tick (ROBLOX-92)
	local snap = legs.state
	frames(3)
	assert(legs.state == snap and snap.position == d.motor.pos and snap.seed == 914 and snap.heading == d.motor.heading, "the same table, filled with this tick's spider")
	life.mate = nil
	legs.drive = nil
	frames(3)
end)

check("a rest that is refused says so in the game's words, and does not set the mate's morning (ROBLOX-92)", function()
	local d = ClientStubs.driver
	local life = d.life
	assert(LifeText.restRefusal("the spider is moving") == "Not now — keep still first", "moving")
	assert(LifeText.restRefusal("the two spiders are together") == MateText.REST_TOGETHER and MateText.REST_TOGETHER == "Not now — the two of you are together", "together")
	assert(LifeText.restRefusal("the brood is hatching") == "Not while the brood is hatching", "hatching")
	assert(LifeText.restRefusal("the rival in the jaws is still struggling") == "Not while a fight is on", "a fight")
	assert(LifeText.restRefusal("something the sim never says") == LifeText.REST_FALLBACK, "an unknown reason has a plain fallback")
	d.place(OPEN)
	frames(30)
	life.growth.stage = 3
	d.needs.energy = 0.9
	life.clock.hour = 12.0
	life.mating = Mating.normalize({ stage = "none" })
	d.motor.vel = Vector3.new(2, 0, 0) -- (a walking spider's speed is not in `vel`; the checkpoint tests set it the same way)
	local refused = life.save()
	d.motor.vel = Vector3.zero
	assert(not refused.ok and refused.message == "Not now — keep still first", `refused while moving: "{refused.message}"`)
	assert(life.mating.ready_day == 0, `a refused rest sets no morning for a visitor ({life.mating.ready_day})`)
	assert(not string.find(string.lower(refused.message), "checkpoint") and not string.find(refused.message, "spider is moving", 1, true), "no engineer's words")
	wait(1.0)
	local kept = life.save()
	assert(kept.ok and life.mating.ready_day > 0, `a rest that is kept does ({kept.message}, ready {life.mating.ready_day})`)
	assert(not string.find(string.lower(kept.message), "checkpoint"), `and says "rest", not "checkpoint": "{kept.message}"`)
	life.mating = Mating.normalize({ stage = "none" })
end)

check("the mirror: a male player's female mate turns to face him, stays and turns away; the captions, the cues, the pause and the entry follow", function()
	local d = ClientStubs.driver
	local life, legs, cam, snd = d.life, d.mateLegs, d.cam, d.soundscape
	-- become the peacock spider: in the crack, resting, C
	life.growth.stage = 3
	d.needs.energy = 0.8
	d.place(CRACK)
	frames(30)
	life.clock.hour = 12.0
	frames(2)
	if not life.resting then key("Feed", true); frames(2); key("Feed", false); frames(2) end
	assert(life.resting and not life.asleep, "resting")
	key("Choose", true); frames(2); key("Choose", false); frames(2)
	assert(d.appearance() == "maratus_volans_male", "the peacock spider")
	key("Forward", true); frames(30); key("Forward", false); frames(2)
	assert(not life.resting, "out of the crack")
	local mate = court(d, "female", true)
	local day = life.clock.day
	assert(legs.couple.active and legs.couple.plan.playerSex == "male" and legs.couple.plan.mateSex == "female" and mate.sex == "female", "the peacock spider is the male: its mate is a female")
	assert(not d.dance().active, "the dance ends when the scene begins")
	frames(3)
	assert(caption() == MateText.SCENE_TURN_MALE and caption() == "She turns to face you.", `the first caption: "{caption()}"`)
	assert(Mate.pairLength(mate) == 15, "the pause is the whole scene")
	untilScene(d, 3.5)
	local mine, theirs = d.rig()._living, legs.stage.rig._living
	assert(mine ~= nil and theirs ~= nil and mine.meetT ~= nil and theirs.meetT ~= nil, "the cue reaches the peacock spider and the female")
	untilScene(d, 7.3)
	assert(mine.settleLen == 4 and theirs.settleLen == 8, "the player is the male now: its settle is the four seconds, hers eight")
	untilScene(d, 11.4)
	assert(caption() == MateText.SCENE_STAYS and caption() == "She stays. You go on.", `the last caption: "{caption()}"`)
	assert(mate.state == "pair" and legs.couple.turn ~= nil and legs.couple.turn ~= 0, "she is turning away")
	untilScene(d, 13.0)
	assert(math.abs(legs.couple.turn :: number - 0) > math.rad(109) and math.abs(legs.couple.turn :: number) < math.rad(111), `she has turned away by 110 degrees ({math.deg(legs.couple.turn)})`)
	assert(mate.state == "pair", "she stays where she is")
	local k = 0
	while legs.couple.active and k < 10 * 6 do wait(0.1); k += 1; life.clock.hour = 9.0 end
	assert(not legs.couple.active and mate.state == "leaving" and mate.scene == false, "at fifteen seconds the scene and the pause end together")
	assert(life.notice == MateText.MATED, "the parting is told")
	local list = d.notebook:entriesFor("eggs_and_wind")
	assert(list[#list].text == MateText.entry(day, "female") and string.find(list[#list].text, "you went on", 1, true), `the line: "{list[#list].text}"`)
	frames(40)
	assert(legs.couple.turn == nil or math.abs(legs.couple.turn) < 0.01, "the drawn turn lets go")
	-- Skipping by the cancel button, at about five seconds, with a second mate.
	mate.elapsed = Rules.leaveSeconds
	frames(3)
	local second = court(d, "female", true)
	untilScene(d, 2.0)
	key("Cancel", true); frames(2); key("Cancel", false); frames(2)
	assert(legs.couple.active and second.state == "pair", "cancel before four seconds is nothing")
	untilScene(d, 4.3)
	key("Cancel", true); frames(2); key("Cancel", false); frames(2)
	assert(not legs.couple.active and second.state == "leaving" and second.reason == "mated", "cancel after four seconds skips")
	assert(cam.shot == nil and not life.resting, "(and it does not rest)")
	second.elapsed = Rules.leaveSeconds
	frames(3)
end)

check("a record returned to during the scene's world, a reset and a new life leave nothing of the scene behind", function()
	local d = ClientStubs.driver
	local life, legs, cam, snd = d.life, d.mateLegs, d.cam, d.soundscape
	local mate = court(d, "female", true)
	untilScene(d, 2.0)
	assert(legs.couple.active and snd.swell > 1, "mid-scene")
	d.returnToCheckpoint()
	frames(3)
	assert(not legs.couple.active and cam.shot == nil and legs.couple.turn == nil and legs.couple.focus == nil, "a return to the last rest ends the scene's presentation")
	wait(1.2)
	assert(snd.swell == 1 and not cam:shotActive(), "the camera and the music are back")
	assert(life.mate == nil or life.mate.scene ~= true, "and the mate is the record's")
	-- with no rest to return to the spider is put back at the start: the pair part first, and the scene does not play on round it
	local third = court(d, "female", true) -- (the player is still the peacock spider of the test before: a male, whose mate is a female and who owes the dance)
	untilScene(d, 1.5)
	assert(legs.couple.active, "mid-scene again")
	local store = d.currentStore()
	local loadBest = store.loadBest
	store.loadBest = function() return { ok = false, message = "no last rest to return to" } end
	d.returnToCheckpoint()
	store.loadBest = loadBest
	frames(3)
	assert(not legs.couple.active and cam.shot == nil and third.state == "leaving" and third.scene == false and life.mating.stage == "mated", "back to the start: the pair part, the scene is over")
	wait(1.2)
	assert(snd.swell == 1 and not cam:shotActive(), "and the camera and the music are back")
	third.elapsed = Rules.leaveSeconds
	frames(3)
	local _ = mate
end)

check("the rival keeps away from the courting pair and the scene (ROBLOX-91): it recovers, unaware, and a lunge in progress is not carried into the scene", function()
	local d = ClientStubs.driver
	local life = d.life
	local r = life.rival
	assert(r ~= nil, "a rival")
	local function setRival(state: string)
		r.state, r.elapsed, r.notice, r.contests, r.spared, r.shaken = state, 0, 0.8, 0, nil, nil
		r.position = Vector3.new(-12, 0.31, -9)
		r.previous = r.position
	end
	setRival("patrol")
	-- the courting range alone (the mate near, the meter not yet filled)
	d.place(OPEN)
	frames(5)
	life.clock.hour = 9.0
	local mate = Mate.new()
	mate.sex, mate.scale = "female", 1
	local function bring()
		mate.state, mate.elapsed, mate.meter, mate.lost = "attend", 0, 0, 0
		mate.position = d.motor.pos + Vector3.new(0, 0, 1.5)
		mate.previous = mate.position
		mate.heading, mate.up = -Vector3.zAxis, Vector3.yAxis
	end
	bring()
	life.mate = mate
	life.mating = Mating.normalize({ stage = "none", ready_day = 1, mates = 1, visits = 1, visit_day = life.clock.day })
	setRival("stalk")
	frames(1)
	assert(r.state == "recover" and r.notice == 0, `a pair in courting range: the rival recovers, unaware ({r.state}, notice {r.notice})`)
	bring()
	setRival("windup")
	frames(1)
	assert(r.state == "recover" and r.notice == 0, `and a windup does not go on ({r.state})`)
	-- the scene itself
	mate = court(d, "female", true)
	setRival("lunge")
	frames(2)
	assert(mate.scene == true and r.state == "recover" and r.notice == 0, `in the scene: the rival keeps away ({r.state})`)
	untilScene(d, 3.0)
	assert(d.mateLegs.couple.active and r.state == "recover", "and through it")
	mate.elapsed = Rules.leaveSeconds
	for _ = 1, 10 * 20 do
		if not d.mateLegs.couple.active and not mate.scene then break end
		wait(0.1)
		life.clock.hour = 9.0
	end
	mate.elapsed = Rules.leaveSeconds
	frames(3)
	-- afterwards it goes about its business again (it is no longer held in recover)
	setRival("patrol")
	frames(30)
	assert(r.state ~= "recover", `the rival goes about its business again once the pair have parted ({r.state})`)
end)

check("a rest too hungry for a visitor says so (ROBLOX-91), and no visitor is set going", function()
	local d = ClientStubs.driver
	local life = d.life
	life.mate = nil
	life.mating = Mating.normalize({ stage = "none", ready_day = 0, mates = 0, visits = 0 })
	life.growth.stage = 3
	d.place(CRACK)
	frames(30)
	life.clock.hour = 12.0
	d.needs.energy = 0.4
	life.notice, life.noticeSeconds = "", 0
	frames(2)
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting, "E did not rest")
	assert(string.find(life.notice, "Too hungry for a visitor to come", 1, true), `the notice: "{life.notice}"`)
	assert(life.mating.ready_day == 0 and life.mating.stage == "none", "and no morning was set")
	-- fed, the same rest sets the cycle going and says nothing of hunger
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	d.needs.energy = 0.8
	life.notice, life.noticeSeconds = "", 0
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	assert(life.resting and life.mating.ready_day > 0 and not string.find(life.notice, "Too hungry", 1, true), `a fed spider: ready day {life.mating.ready_day}, notice "{life.notice}"`)
	assert(string.find(MateText.SAC, "Rest in the crack to pass the nights", 1, true), "the sac line says to rest in the crack")
end)

check("the guard-day end card: starting over is a new life, and says the brood is lost while there is a sac (ROBLOX-91)", function()
	local d = ClientStubs.driver
	local life = d.life
	key("Feed", true); frames(2); key("Feed", false); frames(2)
	life.resting = false
	life.mating = Mating.normalize({ stage = "sac", sac_day = 4, guard_day = 1, mates = 1 })
	assert(Mating.hasSac(life.mating), "a sac")
	local function allText(): string
		local out = {}
		for _, g in gui:GetChildren() do
			for _, x in g:GetDescendants() do
				local ok, t = pcall(function() return (x :: any).Text end)
				if ok and type(t) == "string" then table.insert(out, t) end
			end
		end
		return table.concat(out, "\n")
	end
	d.endLife("starved")
	frames(3)
	local text = allText()
	assert(string.find(text, "the brood is lost", 1, true), "the new-spider choice says the brood is lost")
	assert(string.find(text, "Back to your last rest", 1, true), "and the way back is the last rest")
	assert(MateText.another(false) == MateText.ANOTHER and not string.find(MateText.another(false), "brood", 1, true), "with no sac it is the plain words")
	-- A new life is generation 0 with no sac.
	d.continueAnother()
	frames(3)
	assert(not Mating.hasSac(life.mating) and (life.generation or 0) == 0, `a new life: stage {life.mating.stage}, generation {life.generation}`)
end)

check("the notebook page is sourced and honest: the real citations, the game's departures, no 'no mating simulation' left", function()
	local page
	for _, p in NotebookPages.pages do if p.id == "eggs_and_wind" then page = p end end
	assert(page ~= nil and page.trigger == "hatched" and page.title == "Eggs, silk and wind", "the page")
	assert(#page.text <= 520 and #page.sources == 4, "short, and four sources")
	assert(string.find(page.sources[1], "Journal of Arachnology 6: 1-29", 1, true) and string.find(page.sources[4], "Current Biology 28(14): 2324-2330", 1, true), "real citations in the notebook's style")
	for _, word in { "fifteen minutes", "male", "eight to twelve", "mottled grey-brown", "carry on" } do
		assert(string.find(page.game, word, 1, true) ~= nil, "the game note says: " .. word)
	end
	for _, p in NotebookPages.pages do
		assert(not string.find(p.game, "no mating simulation", 1, true), p.id .. " still says there is no mating simulation")
	end
end)

print("CLIENT_MATING passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_MATING failed") end
