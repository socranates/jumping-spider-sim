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
	assert(MateText.PAIR_CAPTION.text ~= "" and MateText.PAIR_CAPTION.alpha == 1, "the one caption of the pause together")
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
		assert(stage:step(5.0, false) == true and stage.running, "still playing at 8 s")
		local more = stage:step(20.0, false)
		assert(more == false and stage.finished and #stage.bodies == 0 and stage:partCount() == 4, "the scene ends and takes its spiderlings away; the sac stays")
		assert(stage:step(1.0, false) == false, "a finished stage plays nothing")
		stage:reset()
		assert(stage:partCount() == 0 and stage.sac == nil, "reset takes it all away")
		assert(workspace:FindFirstChild("Family"):FindFirstChild("EggSac") == nil, "and the sac is out of the world")
		workspace:FindFirstChild("Family"):Destroy()
	end
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
local KEYS = { Feed = "E", Forward = "W", Display = "X" }
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
	assert(string.find(life.notice, "A visitor: a male spider", 1, true), `the arrival's notice: "{life.notice}"`)
	frames(2)
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
	assert(string.find(find("SpiderPrompts", "Status").Text, "Courting", 1, true), `the status line: "{find("SpiderPrompts", "Status").Text}"`)
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
	assert(find("SpiderPrompts", "Caption").Text == MateText.PAIR_CAPTION.text, `the one caption: "{find("SpiderPrompts", "Caption").Text}"`)
	local m = 0
	while life.mating.stage == "courted" and m < 10 * 8 do wait(0.1); m += 1; life.clock.hour = 9.0 end
	assert(life.mating.stage == "mated" and mate.state == "leaving" and m / 10 > 4 and m / 10 < 6.5, `together about five seconds ({m / 10}): {life.mating.stage}`)
	assert(life.notice == MateText.MATED, `the notice: "{life.notice}"`)
	-- It walks off the sill and does not come again.
	local from = mate.position
	local k = 0
	local farthest = 0.0
	while mate.state == "leaving" and k < 10 * 20 do
		wait(0.1)
		k += 1
		life.clock.hour = 9.0
		farthest = math.max(farthest, (mate.position - from).Magnitude)
		assert(not Layout.inRetreat(mate.position), "the mate went into the retreat")
	end
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
	assert(string.find(find("SpiderPrompts", "Status").Text, "Guarding the eggs: day 1 of 2", 1, true), `the guard line: "{find("SpiderPrompts", "Status").Text}"`)
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
	assert(string.find(find("SpiderPrompts", "Status").Text, "day 2 of 2", 1, true), `the guard line: "{find("SpiderPrompts", "Status").Text}"`)
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
	for _ = 1, 10 * 16 do
		wait(0.1)
		for _, parts in legs.stage.bodies do
			if parts.thread.Transparency < 1 then threads += 1 end
			if parts.body.Position.Y > 0.5 and parts.body.Transparency < 1 then lifted += 1 end
		end
		life.clock.hour = 8.0
	end
	assert(lifted > 0 and threads > 0, `spiderlings rose on their threads ({lifted}, {threads})`)
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

check("the notebook page is sourced and honest: the real citations, the game's departures, no 'no mating simulation' left", function()
	local page
	for _, p in NotebookPages.pages do if p.id == "eggs_and_wind" then page = p end end
	assert(page ~= nil and page.trigger == "hatched" and page.title == "Eggs, silk and wind", "the page")
	assert(#page.text <= 520 and #page.sources == 4, "short, and four sources")
	assert(string.find(page.sources[1], "Journal of Arachnology 6: 1-29", 1, true) and string.find(page.sources[4], "Current Biology 28(14): 2324-2330", 1, true), "real citations in the notebook's style")
	for _, word in { "fifteen minutes", "male", "eight to twelve", "plain brown", "carry on" } do
		assert(string.find(page.game, word, 1, true) ~= nil, "the game note says: " .. word)
	end
	for _, p in NotebookPages.pages do
		assert(not string.find(p.game, "no mating simulation", 1, true), p.id .. " still says there is no mating simulation")
	end
end)

print("CLIENT_MATING passed=" .. passed .. " failed=" .. failed)
if failed > 0 then error("CLIENT_MATING failed") end
