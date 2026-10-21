-- ROBLOX-113 (W5): the quiet HUD. The pure rules first (Shared/UI/QuietHud: every kind classified, the context, the notices line by line, the perception labels
-- calmed, the growth line's quiet form), then through the real client on the sill's boxes (tests/shim.luau): what Normal says on the first day, what it says
-- after it, and that Easy keeps every word.
local QuietHud = require("../src/Shared/UI/QuietHud")
local LifeText = require("../src/Shared/UI/LifeText")
local MateText = require("../src/Shared/UI/MateText")
local RivalText = require("../src/Shared/UI/RivalText")
local WaspText = require("../src/Shared/UI/WaspText")
local Growth = require("../src/Shared/Life/Growth")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")

local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL quiet: " .. name .. "\n    " .. tostring(err)) end
end

local NORMAL1 = QuietHud.context("standard", 1, 0)
local NORMAL2 = QuietHud.context("standard", 2, 0)
local EASY = QuietHud.context("gentle", 5, 0)

-- ---------------------------------------------------------------- the rules
check("every kind has a class and a place, and none is removed outright (the gentle modes keep every word)", function()
	local n, by = 0, { needed = 0, day_one = 0, gentle = 0, removed = 0 }
	for name, k in QuietHud.KINDS do
		n += 1
		assert(by[k.class] ~= nil, name .. ": " .. tostring(k.class))
		by[k.class] += 1
		assert(type(k.where) == "string" and k.where ~= "" and type(k.what) == "string" and k.what ~= "", name)
	end
	assert(by.removed == 0, "a kind removed in every mode")
	assert(n >= 50 and by.needed > 0 and by.day_one > 0 and by.gentle > 0, `{n} kinds: {by.needed} needed, {by.day_one} day one, {by.gentle} gentle`)
	print(`  quiet: {n} kinds, {by.needed} needed, {by.day_one} on the first day only, {by.gentle} in the gentle modes only; {#QuietHud.NOTICES} notice lines classified`)
end)

check("the context: Normal is the standard rules; the first day is the life's or the generation's first", function()
	assert(NORMAL1.normal and NORMAL1.dayOne and NORMAL2.normal and not NORMAL2.dayOne, "Normal, day 1 and day 2")
	assert(QuietHud.context("standard", 5, 4).dayOne and not QuietHud.context("standard", 6, 4).dayOne, "a spiderling hatched on day 5 has day 5 as its first")
	assert(not EASY.normal and not QuietHud.quiet(EASY) and QuietHud.quiet(NORMAL2) and not QuietHud.quiet(NORMAL1), "quiet only in Normal after the first day")
end)

check("what shows: needed always, the first day's only on it, the gentle modes' never in Normal, every kind in Easy and Free play", function()
	for name, k in QuietHud.KINDS do
		assert(QuietHud.shows(name, EASY), name .. " hidden in Easy")
		assert(QuietHud.shows(name, NORMAL1) == (k.class ~= "gentle"), name .. " on Normal's first day")
		assert(QuietHud.shows(name, NORMAL2) == (k.class == "needed"), name .. " after Normal's first day")
	end
	assert(QuietHud.shows("a kind nobody classified", NORMAL2), "an unknown kind shows (a new string is never hidden by accident)")
	for _, name in { "hunger", "day", "growth_count", "starving_weak", "sound_captions", "aim_title", "anchor_warning", "controls_card_asked", "rest_state", "line_cue", "toast:out_of_bounds", "toast:lost", "save_broken" } do
		assert(QuietHud.KINDS[name].class == "needed", name)
	end
	for _, name in { "walk_hint", "controls_card_start", "line_panel", "rest_prompt", "home_line", "aim_hint", "hunger_words", "dusk_words", "toast:refused", "toast:released" } do
		assert(QuietHud.KINDS[name].class == "day_one", name)
	end
	for _, name in { "wasp_line", "court_line", "guard_line", "soft_skin" } do assert(QuietHud.KINDS[name].class == "gentle", name) end
end)

check("the notices, line by line: the morning's line goes after the first day and the rest kept stays; the visitor and the rival lose their how-to", function()
	local morning = "Morning, day 3. Rested through the night in the crack.\nLast rest kept."
	assert(QuietHud.notice(morning, NORMAL2) == "Last rest kept." and QuietHud.notice(morning, EASY) == morning, "the morning")
	assert(QuietHud.notice("Morning, day 1. Rested through the night in the crack.", NORMAL1) ~= nil, "(a first day shows it)")
	local arrived = MateText.arrived("female", true, "keyboard")
	assert(QuietHud.notice(arrived, NORMAL2) == "A visitor: a female spider has come onto the sill.", tostring(QuietHud.notice(arrived, NORMAL2)))
	assert(QuietHud.notice(arrived, EASY) == arrived and QuietHud.notice(arrived, NORMAL1) == arrived, "the whole arrival in Easy and on a first day")
	assert(QuietHud.notice(RivalText.CAPTURED, NORMAL2) == "Caught the rival! It fights back.", tostring(QuietHud.notice(RivalText.CAPTURED, NORMAL2)))
	assert(QuietHud.notice(RivalText.SUBDUED, NORMAL2) == "The rival goes still.", "subdued")
	assert(QuietHud.notice(RivalText.COUNTER, NORMAL2) == "It bit back!" and QuietHud.notice(RivalText.COUNTER_GENTLE, EASY) == RivalText.COUNTER_GENTLE, "the counter-bite")
	assert(QuietHud.notice("The other spider crouches to jump. Dodge, drop or jump away!", NORMAL2) == nil and QuietHud.notice("The other spider crouches to jump. Dodge, drop or jump away!", NORMAL1) == nil, "the crouch is told by the crouch in Normal")
	assert(QuietHud.notice("Ready to moult. Rest in the silk-lined crack.", NORMAL2) == "Ready to moult.", "ready")
	assert(QuietHud.notice("Moulting in the crack. The spider slowly pulls free of its old skin.", NORMAL1) == nil, "moulting: the prompt's title says it")
	assert(QuietHud.notice("Returned to your last rest: the sill as it was when you rested in the crack. This is a return to the rest, not an exact resume.", NORMAL2) == nil, "the return's explanation")
	assert(QuietHud.notice("Awake before morning: it is still night.", NORMAL2) == nil, "awake before morning")
	-- what stays, word for word
	for _, line in { "Last rest kept.", "Last rest kept, under the stone.", "Moulted: now a Juvenile. The new skin is soft for a while.", "The new skin has hardened. Full-length jumps again.",
		LifeText.NIGHT_COLD, MateText.SAC, MateText.NOTICED, MateText.DRIVEN, MateText.COURTED, MateText.MATED, MateText.CUT, MateText.TOO_HUNGRY, MateText.rejected("female", "thin"),
		WaspText.RIVAL_TAKEN, RivalText.TORE, RivalText.SPRANG, "Your spider is an adult! Easy is now available in the life menu for this session.",
		"Resting, but this is not kept as your last rest. Not now — keep still first.",
		"Returned to your last rest, but the world has changed since you rested, so you stand where a life begins in it. Everything else is as you left it." } do
		assert(QuietHud.notice(line, NORMAL2) == line, "changed in Normal: " .. line)
	end
	assert(QuietHud.notice("", NORMAL2) == nil and QuietHud.notice(nil, NORMAL2) == nil, "nothing")
end)

check("the perception labels, calmed: one to an area, the live before the lost, the newest lost first, and lost sight gone in a breath", function()
	local LOST = "lost sight"
	local out = {}
	local function lost(x: number, y: number, age: number) return { pos = Vector2.new(x, y), offset = 20, text = LOST, alpha = math.clamp(1 - age / 2.5, 0, 1) } end
	-- Nathan's three on the soil: one drawn, the newest
	local three = { lost(400, 300, 0.6), lost(430, 310, 0.1), lost(380, 320, 0.3) }
	local r = QuietHud.calmLabels(three, LOST, out)
	assert(r == out and #r == 1 and math.abs(r[1].pos.X - 430) < 1e-9 and math.abs(r[1].alpha - 0.9) < 1e-9, `three piled: {#r}, {r[1] and r[1].alpha}`)
	-- a live one in the same area wins over them
	table.insert(three, { pos = Vector2.new(410, 290), offset = 20, text = "fly-like prey", alpha = 1 })
	r = QuietHud.calmLabels(three, LOST, out)
	assert(#r == 1 and r[1].text == "fly-like prey", "the live label wins")
	-- apart, both
	r = QuietHud.calmLabels({ lost(100, 100, 0.2), lost(500, 100, 0.2) }, LOST, out)
	assert(#r == 2, "two areas, two labels")
	-- the fade: a breath (1 s) where the view's is 2.5 s
	assert(#QuietHud.calmLabels({ lost(100, 100, 1.05) }, LOST, out) == 0 and math.abs(QuietHud.calmLabels({ lost(100, 100, 0.25) }, LOST, out)[1].alpha - 0.75) < 1e-9, "gone in a breath")
	assert(three[1].alpha == math.clamp(1 - 0.6 / 2.5, 0, 1), "the view's labels are not changed")
end)

check("the growth line's quiet form: the count without the prey's rule, ready, nothing while moulting or for an adult", function()
	local g = Growth.new()
	local full = LifeText.growth(g, Growth.READY_FOOD, 1, "fungus_gnat")
	local quiet = LifeText.growthQuiet(g, Growth.READY_FOOD, 1, "fungus_gnat")
	assert(string.find(full, " · 3 gnats = 1 housefly", 1, true) and quiet == string.match(full, "^(.-) · "), `{full} / {quiet}`)
	assert(quiet ~= nil and string.find(quiet, "^Next moult: ") ~= nil and not string.find(quiet, "·", 1, true), tostring(quiet))
	g.ready = true
	assert(LifeText.growthQuiet(g, Growth.READY_FOOD, 1) == "Ready to moult", "ready")
end)

-- ---------------------------------------------------------------- through the real client
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local services = ClientStubs
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local KEYS = { Feed = "E", Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Help = "H" }
local function key(action: string, down: boolean)
	local fn = services.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function press(action: string) key(action, true); frames(2); key(action, false); frames(2) end
local function words(name: string): string
	local g = gui:FindFirstChild("SpiderPrompts")
	for _, d in g:GetDescendants() do if d.Name == name then return if d.Visible then d.Text else "" end end
	return ""
end
-- (the start's save status settled first, as in tests/inspect.luau: its offline toast must not land on a check)
do
	frames(2)
	local t0 = os.clock()
	while ClientStubs.driver ~= nil and ClientStubs.driver.saveState.status == nil and os.clock() - t0 < 10 do frame(1 / 60) end
	frames(170)
end
local driver = ClientStubs.driver
local CRACK = Vector3.new(-25.5, 0.31, 6.0)
local OPEN = Vector3.new(-5, 0.31, -9)

check("Normal, the first day: the walk's hint, the controls card at the start, the crack's prompt and the aim's words are there", function()
	assert(loaded and driver ~= nil, "the client did not load: " .. tostring(loadError))
	local life = driver.life
	assert(driver.session.rules == "standard" and life.clock.day == 1, `rules {driver.session.rules}, day {life.clock.day}`)
	driver.place(OPEN); frames(10)
	assert(string.find(words("PromptHint"), "hop", 1, true) ~= nil, "no walk hint: " .. words("PromptHint"))
	assert(words("Controls") ~= "", "no controls card at the start")
	driver.place(CRACK); frames(30)
	life.clock.hour = 12; frames(2)
	assert(words("PromptTitle") == "The silk-lined crack" and string.find(words("PromptHint"), "E: rest", 1, true) ~= nil, `the crack: {words("PromptTitle")} / {words("PromptHint")}`)
	driver.place(OPEN); frames(10)
	key("Jump", true); frames(30)
	assert(string.find(words("AimHint") .. (function()
		for _, d in gui:FindFirstChild("SpiderHud"):GetDescendants() do if d.Name == "AimHint" and d.Visible then return d.Text end end
		return ""
	end)(), "cancel the jump", 1, true) ~= nil, "no aim hint on the first day")
	press("Cancel"); key("Jump", false); frames(2)
end)

check("Normal after the first day: no walk hint, no card, no crack how-to, no aim hint, the day box without its advice; H still brings the card", function()
	local life, needs = driver.life, driver.needs
	frames(170) -- (the first day's last toast has had its seconds)
	life.clock.day, life.clock.hour = 2, 12
	driver.place(OPEN); frames(10)
	key("Forward", true); frames(20); key("Forward", false); frames(2)
	assert(words("PromptHint") == "" and words("PromptTitle") == "", `a prompt: {words("PromptTitle")} / {words("PromptHint")}`)
	assert(words("Controls") == "", "the card at the start after the first day")
	press("Help")
	assert(words("Controls") ~= "", "H did not bring the card")
	press("Help")
	assert(words("Controls") == "", "H did not put it away")
	-- the day box: the count, without the prey's rule; hungry and evening say nothing (the bar and the light do)
	needs.energy = 0.2
	life.clock.hour = 19; frames(3)
	local box = words("DayLine")
	assert(string.find(box, "Next moult: ", 1, true) ~= nil and not string.find(box, "housefly", 1, true) and not string.find(box, "Hungry", 1, true) and not string.find(box, "Evening", 1, true), "the day box: " .. box)
	local bar = (function() for _, d in gui:FindFirstChild("SpiderPrompts"):GetDescendants() do if d.Name == "HungerText" then return d.Text end end return "" end)()
	assert(string.find(bar, "hungry", 1, true) ~= nil, "the bar says hungry: " .. bar)
	-- the crack: nothing while it could rest; the title only while resting
	driver.place(CRACK); frames(30)
	life.clock.hour = 12; frames(3)
	assert(words("PromptTitle") == "" and words("PromptHint") == "", `the crack's how-to: {words("PromptTitle")} / {words("PromptHint")}`)
	press("Feed")
	assert(life.resting and string.find(words("PromptTitle"), "Resting", 1, true) ~= nil and words("PromptHint") == "", `resting: {words("PromptTitle")} / {words("PromptHint")}`)
	assert(words("Notice") == "Last rest kept.", "the rest kept: " .. words("Notice"))
	press("Feed")
	-- a notice line by line: ready to moult, short
	life:showNotice("Ready to moult. Rest in the silk-lined crack."); frames(2)
	assert(words("Notice") == "Ready to moult.", words("Notice"))
	-- the aim: the title, not the hint
	driver.place(OPEN); frames(10)
	key("Jump", true); frames(30)
	local hint, title = "", ""
	for _, d in gui:FindFirstChild("SpiderHud"):GetDescendants() do
		if d.Name == "AimHint" and d.Visible then hint = d.Text end
		if d.Name == "AimTitle" and d.Visible then title = d.Text end
	end
	assert(title ~= "" and hint == "", `aim: {title} / {hint}`)
	press("Cancel"); key("Jump", false); frames(2)
	assert(not string.find(words("Toast"), "Jump cancelled", 1, true), "the cancel's toast: " .. words("Toast"))
	needs.energy = 1
end)

check("the wasp after the first day in Normal: the hum's caption, and no status line telling what to do", function()
	local life, wasp, prey = driver.life, driver.wasp, driver.prey
	driver.place(Vector3.new(2.0, 0.31, 6.0))
	life.clock.day, life.clock.hour = 3, 12.0
	prey.feeding.mealsFinished = 1
	frames(10)
	workspace:SetAttribute("WaspForce", "floor_middle")
	frames(30)
	assert(wasp:isVisiting() and wasp.phase == "arriving", `no visit: {wasp.phase}`)
	assert(string.find(words("Caption"), "[a deep, heavy hum outside, ", 1, true) ~= nil, "no hum: " .. words("Caption"))
	assert(not string.find(words("Status"), "wasp", 1, true), "a wasp line: " .. words("Status"))
	-- Easy keeps it
	driver.session.rules = "gentle"; frames(2)
	assert(string.find(words("Status"), "a wasp is coming", 1, true) ~= nil, "Easy lost the wasp's line: " .. words("Status"))
	driver.session.rules = "standard"
	wasp:clearVisit()
	frames(2)
end)

check("Easy after the first day: every word as before (the walk hint, the crack's how-to, the day box's advice)", function()
	local life, needs = driver.life, driver.needs
	driver.session.rules = "gentle"
	life.clock.day, life.clock.hour = 4, 12
	driver.place(CRACK); frames(30)
	assert(words("PromptTitle") == "The silk-lined crack" and string.find(words("PromptHint"), "rest", 1, true) ~= nil, `the crack in Easy: {words("PromptTitle")} / {words("PromptHint")}`)
	needs.energy = 0.2; frames(3)
	assert(string.find(words("DayLine"), "Hungry", 1, true) ~= nil, "Easy's day box: " .. words("DayLine"))
	needs.energy = 1
	driver.session.rules = "standard"
	frames(2)
end)

print(`QUIET passed={passed} failed={failed}`)
