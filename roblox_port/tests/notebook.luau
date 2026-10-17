-- The naturalist's notebook (LEARN-01, ported as ROBLOX-37). NOTEBOOK passed=N failed=M.
-- Which expectations come from where: Godot's own hand-written tests (tests/integration/test_learn01_notebook.gd) are hand-ported
-- below, one block each, named for the Godot test. The Godot model could not be exported as goldens here (no Godot in this
-- environment), so the pages themselves are checked word for word against a copy of the frozen data/notebook/pages.json
-- (tests/notebook_reference.json, copied by tools/gen_notebook_pages.py), and nothing is generated from the port under test.
local NotebookPages = require("../src/Shared/Data/NotebookPages")
local FieldNotebook = require("../src/Shared/Learning/FieldNotebook")
local NotebookWatch = require("../src/Shared/Learning/NotebookWatch")
local NotebookText = require("../src/Shared/UI/NotebookText")
local ControlText = require("../src/Shared/UI/ControlText")
local HudLayout = require("../src/Shared/UI/HudLayout")
local ref = require("./notebook_reference")
local passed, failed = 0, 0
local function check(ok: boolean, name: string)
	if ok then passed += 1 else failed += 1; print("FAIL NOTEBOOK " .. name) end
end
local function same(a: { string }, b: { string }): boolean
	if #a ~= #b then return false end
	for i, v in a do if v ~= b[i] then return false end end
	return true
end
local function ids(list: { { id: string, title: string } }): { string }
	local out = {}
	for _, e in list do table.insert(out, e.id) end
	return out
end

-- ---------------------------------------------------------------- the pages are Godot's, word for word
-- Godot: test_every_page_is_complete_short_and_sourced
local ADAPTED = { "bold_jumper", "dragline", "legs_push", "green_uv", "hungry_at_home", "mud_dauber", "what_the_wasp_does" }
local STABLE = {
	"bold_jumper", "dragline", "legs_push", "eight_eyes", "moving_retinas", "motion_first", "hunting_by_sight", "venom", "drinking",
	"felt", "hearing", "retreat", "depth_blur", "green_uv", "home_before_dark", "hungry_at_home", "full_abdomen", "outgrowing_a_skin",
	"new_skin", "grown_up", "mud_dauber", "what_the_wasp_does", "getting_away", "going_without_food",
}
do
	local book = FieldNotebook.new()
	check(#book.dropped == 0, "no page was left out for a missing field or an unknown trigger")
	check(#book.pages == #ref.pages and #ref.pages == 24, `all of Godot's {#ref.pages} pages are here ({#book.pages})`)
	check(#book.pages >= 12, "there is a first set of pages")
	check(same(ids((function() local l = {} for _, p in book.pages do table.insert(l, { id = p.id, title = p.title }) end return l end)()), STABLE), "the page ids are the stable ones, in Godot's order")
	local seen: { [string]: boolean } = {}
	local adapted: { string } = {}
	local urls, refUrls = 0, 0
	for i, p in book.pages do
		local g: any = ref.pages[i]
		check(#FieldNotebook.problems(p) == 0, `page {p.id} is complete`)
		check(not seen[p.id], `page ids are unique ({p.id})`)
		seen[p.id] = true
		check(#p.text <= 520, `page {p.id} is short enough to read in a moment ({#p.text} characters)`)
		check(p.id == g.id and p.trigger == g.trigger and p.title == g.title and p.text == g.text, `page {p.id}: id, trigger, title and text are Godot's, word for word`)
		check(same(p.sources, g.sources), `page {p.id}: the sources are Godot's, word for word`)
		for _, s in p.sources do
			check(#s > 20 and string.find(s, "(", 1, true) ~= nil, `page {p.id} names a full source: {s}`)
			if string.find(s, "https://", 1, true) then urls += 1 end
		end
		for _, s in g.sources do if string.find(s, "https://", 1, true) then refUrls += 1 end end
		if p.game ~= g.game then
			table.insert(adapted, p.id)
			check(p.godotGame == g.game, `page {p.id}: Godot's own 'In this game' line is kept as godotGame`)
			check(p.game ~= "", `page {p.id}: the Roblox line is not empty`)
		else
			check(p.godotGame == nil, `page {p.id}: no godotGame where the line is Godot's`)
		end
	end
	check(urls == refUrls and urls >= 12, `the source links are all kept ({urls} of {refUrls})`)
	check(same(adapted, ADAPTED), "exactly these pages have a Roblox 'In this game' line: " .. table.concat(adapted, ", "))
	-- Every trigger a page names is one the notebook has; Godot's list is whole.
	local triggers = { "start", "jump", "jump_far", "jump_long", "eye_view", "eye_time_20", "eye_time_60", "shimmer", "fly_recognised", "catch", "meal", "felt", "buzz", "rest", "sleep", "hungry", "well_fed", "moult_ready", "moulted", "adult", "wasp", "wasp_escaped", "wasp_caught", "starving" }
	check(same(NotebookPages.triggers, triggers), "the trigger list is Godot's")
	for _, p in book.pages do check(table.find(NotebookPages.triggers, p.trigger) ~= nil, `page {p.id} names a trigger the notebook has`) end
	-- The thresholds are Godot's.
	check(NotebookPages.hungryAt == 0.25 and NotebookPages.wellFedAt == 0.85 and NotebookPages.jumpFarWu == 5.0 and NotebookPages.jumpLongWu == 8.0, "Godot's thresholds")
	check(NotebookPages.eyeMarks[1] == 20 and NotebookPages.eyeMarks[2] == 60 and NotebookPages.hearWu == 10.0 and NotebookPages.noteSeconds == 6.0, "Godot's eye marks, hearing range and note time")
	-- problems(): what makes a page unfit
	check(#FieldNotebook.problems({ id = "x", trigger = "jump", title = "t", text = "t", sources = { "s" } }) == 0, "a complete page has no problem")
	check(#FieldNotebook.problems({ id = "", trigger = "jump", title = "t", text = "t", sources = { "s" } }) == 1, "no id")
	check(#FieldNotebook.problems({ id = "x", trigger = "nonsense", title = "t", text = "t", sources = { "s" } }) == 1, "an unknown trigger")
	check(#FieldNotebook.problems({ id = "x", trigger = "jump", title = "t", text = "t", sources = {} }) == 1, "no source")
	check(#FieldNotebook.problems({ id = "x", trigger = "jump", title = "  ", text = "t", sources = { "s" } }) == 1, "a blank title")
	local odd = FieldNotebook.new({ { id = "a", trigger = "jump", title = "A", text = "a", game = "", sources = { "s" } }, { id = "a", trigger = "jump", title = "again", text = "a", game = "", sources = { "s" } }, { id = "b", trigger = "nonsense", title = "B", text = "b", game = "", sources = { "s" } } })
	check(#odd.pages == 1 and #odd.dropped == 2, "a repeated id and a page with a problem are left out")
end

-- ---------------------------------------------------------------- a page opens once, and the notebook keeps them
-- Godot: test_a_page_opens_once_and_the_notebook_keeps_them
do
	local nb = FieldNotebook.new()
	local seen: { string } = {}
	nb.pageOpened:connect(function(id: string) table.insert(seen, id) end)
	check(same(nb:notice("jump"), { "dragline" }), "the first jump opens the dragline page")
	check(#nb:notice("jump") == 0, "and only once")
	nb:noticeJump(9.0)
	check(nb:isOpen("legs_push") and nb:isOpen("depth_blur"), "a long leap opens the far- and long-jump pages")
	nb:addEyeTime(19.0)
	check(not nb:isOpen("moving_retinas"), "19 s in the eye view: not yet")
	nb:addEyeTime(2.0)
	check(nb:isOpen("moving_retinas") and not nb:isOpen("green_uv"), "20 s opens the moving-retina page")
	nb:addEyeTime(40.0)
	check(nb:isOpen("green_uv"), "a minute opens the colour page")
	check(same(seen, nb.opened), "each page was announced once, in order")
	check(same(seen, { "dragline", "legs_push", "depth_blur", "moving_retinas", "green_uv" }), "in the order of discovery")
	-- the book comes back as it was
	local again = FieldNotebook.new()
	again:load(nb:toRecord())
	check(same(again.opened, nb.opened), "the notebook comes back as it was")
	check(math.abs(again.eyeSeconds - nb.eyeSeconds) < 0.01, "with the time in the eye view")
	check(again:isOpen("dragline") and again:view("green_uv") ~= nil, "and the pages are readable")
	check(#again:notice("jump") == 0, "a loaded page does not open again")
	again:load({ opened = { "dragline", "no_such_page", "dragline" }, eye_seconds = "nonsense" })
	check(same(again.opened, { "dragline" }), "unknown and repeated ids are dropped")
	check(again.eyeSeconds == 0.0, "a bad number is read as none")
	again:load({ opened = { "dragline" }, eye_seconds = -5 })
	check(again.eyeSeconds == 0.0, "a negative time is none")
	again:load("not a record")
	check(#again.opened == 0 and not again:isOpen("dragline"), "an unreadable record is an empty notebook")
	again:load({ opened = "venom" })
	check(#again.opened == 0, "a record whose list is not a list is empty")
	-- several pages on one trigger open together; a loaded book announces nothing
	local announced = 0
	again.pageOpened:connect(function() announced += 1 end)
	again:load(nb:toRecord())
	check(announced == 0, "loading announces nothing")
	-- time is only added, never taken away, and only counts real numbers
	local eye = FieldNotebook.new()
	eye:addEyeTime(-3)
	eye:addEyeTime(0 / 0)
	check(eye.eyeSeconds == 0, "negative or NaN time adds nothing")
	eye:addEyeTime(61)
	check(eye:isOpen("moving_retinas") and eye:isOpen("green_uv"), "one long stretch passes both marks")
end

-- ---------------------------------------------------------------- no spoilers, order of discovery, no checklist
do
	local nb = FieldNotebook.new()
	for _, p in nb.pages do
		check(nb:view(p.id) == nil, `page {p.id}: not readable before its observation`)
		check(not nb:isOpen(p.id), `page {p.id}: not open at first`)
	end
	check(#nb:list() == 0 and nb:newest() == nil, "an empty book lists nothing")
	check(nb:view("no_such_page") == nil and not nb:has("no_such_page") and nb:has("venom"), "has() knows ids; view() never shows an unfound page")
	nb:notice("start")
	nb:notice("catch")
	nb:notice("jump")
	check(same(ids(nb:list()), { "bold_jumper", "venom", "dragline" }), "listed in the order they were found")
	check(nb:newest() == "dragline", "the newest is the last found")
	local p = nb:view("venom")
	check(p ~= nil and p.title == "The bite" and #p.sources == 1, "a found page shows its title, text and source")
	check(nb:view("legs_push") == nil, "and an unfound one still shows nothing")
	for _, e in nb:list() do
		check(type(e.title) == "string" and next(e) ~= nil, "a list entry is an id and a title")
		check((function() local n = 0 for _ in e do n += 1 end return n end)() == 2, "and nothing else (no text, no source, no count)")
	end
	-- Godot has no count of pages left (spec 4: discovery must not become a completion checklist); neither does this book.
	local any: any = nb
	check(any.remaining == nil and any.total == nil and any.count == nil and any.size == nil, "the book exposes no count of pages left")
	-- several pages on one trigger open together
	local both = FieldNotebook.new({ { id = "a", trigger = "jump", title = "A", text = "a", game = "", sources = { "s" } }, { id = "b", trigger = "jump", title = "B", text = "b", game = "", sources = { "s" } } })
	local order: { string } = {}
	both.pageOpened:connect(function(id: string) table.insert(order, id) end)
	check(same(both:notice("jump"), { "a", "b" }) and same(order, { "a", "b" }), "two pages on one trigger both open, announced in the file's order")
end

-- ---------------------------------------------------------------- the watcher opens pages on the moments Godot's does
-- Godot: test_play_opens_pages (the start, a jump, the eye view, a catch, a meal, a buzz, ...), without the world: the events the
-- client hands the watcher and the state it shows once a fixed tick.
local function view(over: any?): any
	local v: any = { started = true, captures = 0, feeding = false, taken = 0.0, energy = 0.6, gentle = false, spider = Vector3.zero, flies = {} }
	if over then for k, x in over do v[k] = x end end
	return v
end
local function fly(id: string, at: Vector3, up: boolean): any
	return { id = id, position = at, up = up, airborne = function(self: any): boolean return self.up end }
end
local function fresh(): (any, any)
	local nb = FieldNotebook.new()
	return nb, NotebookWatch.new(nb)
end
do
	-- the start waits for a life
	local nb, w = fresh()
	w:step(view({ started = false }))
	w:step(view({ started = false }))
	check(not nb:isOpen("bold_jumper"), "no first page while the menu waits for the first life")
	w:step(view())
	check(nb:isOpen("bold_jumper") and #nb.opened == 1, "the first page opens at the start")
	w:step(view())
	check(#nb.opened == 1, "and only once")

	-- jumps: the first, a far one and a long one (Godot notice_jump), the hop is a jump too
	nb, w = fresh()
	w:onJump(3.5)
	check(nb:isOpen("dragline") and not nb:isOpen("legs_push"), "a 3.5 stud strike opens the dragline page, not the far-jump page")
	w:onJump(4.99)
	check(not nb:isOpen("legs_push"), "4.99 studs is not far")
	w:onJump(5.0)
	check(nb:isOpen("legs_push") and not nb:isOpen("depth_blur"), "5 studs is far, not long")
	w:onJump(8.0)
	check(nb:isOpen("depth_blur"), "8 studs is long")
	w:onJump(1.5)
	check(#nb.opened == 3, "a short hop afterwards opens nothing more")

	-- a contact refined to fly-like prey
	nb, w = fresh()
	w:onCategory("movement")
	w:onCategory("possible_prey")
	check(#nb.opened == 0, "movement and possible prey open nothing")
	w:onCategory("fly_like_prey")
	check(nb:isOpen("hunting_by_sight"), "a fly recognised opens the hunting page")

	-- a catch, then a meal when eating ends with something eaten; no meal if nothing was eaten
	nb, w = fresh()
	w:step(view())
	w:step(view({ captures = 1 }))
	check(nb:isOpen("venom") and not nb:isOpen("drinking"), "a catch opens the bite page")
	w:step(view({ captures = 1, feeding = true, taken = 0.0 }))
	w:step(view({ captures = 1, feeding = false, taken = 0.0 }))
	check(not nb:isOpen("drinking"), "eating that stops with nothing eaten is no meal")
	w:step(view({ captures = 1, feeding = true, taken = 0.0 }))
	w:step(view({ captures = 1, feeding = true, taken = 0.1 }))
	check(not nb:isOpen("drinking"), "a meal is not yet a meal while it goes on")
	w:step(view({ captures = 1, feeding = false, taken = 0.2 }))
	check(nb:isOpen("drinking"), "a meal opens its page when eating ends with food taken")
	nb, w = fresh()
	w:step(view({ taken = 5.0 }))
	w:step(view({ feeding = true, taken = 5.0 }))
	w:step(view({ feeding = false, taken = 5.0 }))
	check(not nb:isOpen("drinking"), "food taken before this bout does not count")

	-- the reserve changes: hungry, well fed, starving (not on Easy)
	nb, w = fresh()
	w:step(view({ started = false, energy = 0.5 }))
	w:step(view({ started = false, energy = 0.499 }))
	check(#nb.opened == 0, "a reserve in the middle opens nothing")
	w:step(view({ energy = 0.25 }))
	check(nb:isOpen("hungry_at_home") and not nb:isOpen("full_abdomen") and not nb:isOpen("going_without_food"), "a reserve at 0.25 is hungry")
	w:step(view({ energy = 0.85 }))
	check(nb:isOpen("full_abdomen"), "a reserve at 0.85 is well fed")
	w:step(view({ energy = 0.0 }))
	check(nb:isOpen("going_without_food"), "an empty reserve is starving")
	nb, w = fresh()
	w:step(view({ energy = 0.5 }))
	w:step(view({ energy = 0.0, gentle = true }))
	check(nb:isOpen("hungry_at_home") and not nb:isOpen("going_without_food"), "on Easy or in free play it is hungry but not starving")
	nb, w = fresh()
	w:step(view({ started = false, energy = 0.1 }))
	w:step(view({ started = false, energy = 0.1 }))
	check(#nb.opened == 0, "a reserve that is low from the first look and does not change opens nothing (Godot: on a change)")

	-- a fly taking off near enough to hear
	nb, w = fresh()
	local near, far = fly("fly_1", Vector3.new(6, 0, 0), false), fly("fly_2", Vector3.new(30, 0, 0), true)
	w:step(view({ flies = { near, far } }))
	near.up = true
	far.up = false
	w:step(view({ flies = { near, far } }))
	check(nb:isOpen("hearing"), "a fly taking off within 10 studs is heard")
	nb, w = fresh()
	far = fly("fly_2", Vector3.new(30, 0, 0), false)
	w:step(view({ flies = { far } }))
	far.up = true
	w:step(view({ flies = { far } }))
	check(not nb:isOpen("hearing"), "one taking off 30 studs away is not")
	local aloft = fly("fly_3", Vector3.new(2, 0, 0), true)
	nb, w = fresh()
	w:step(view({ flies = { aloft } }))
	w:step(view({ flies = { aloft } }))
	check(not nb:isOpen("hearing"), "a fly already in the air at the first look, and still there, takes off no more")
	aloft.up = false
	w:step(view({ flies = { aloft } }))
	aloft.up = true
	w:step(view({ flies = { aloft } }))
	check(nb:isOpen("hearing"), "landing and taking off again near is heard")

	-- the life loop's events
	nb, w = fresh()
	w:onLife("checkpoint", 0)
	w:onLife("slept", 0)
	w:onLife("rest_ended", 0)
	check(#nb.opened == 0, "the checkpoint, falling asleep and ending a rest open nothing")
	w:onLife("rest_started", 0)
	check(nb:isOpen("retreat"), "a rest opens the retreat page")
	w:onLife("woke", 0)
	check(nb:isOpen("home_before_dark"), "the morning after a night's sleep opens its page")
	w:onLife("moult_ready", 0)
	check(nb:isOpen("outgrowing_a_skin") and not nb:isOpen("new_skin"), "ready to moult opens its page")
	w:onLife("moulted", 1)
	check(nb:isOpen("new_skin") and not nb:isOpen("grown_up"), "a moult to a juvenile opens the new-skin page, not the adult one")
	w:onLife("moulted", 2)
	check(not nb:isOpen("grown_up"), "nor to a subadult")
	w:onLife("moulted", 3)
	check(nb:isOpen("grown_up"), "the moult to the adult opens the adult page")

	-- the wasp
	nb, w = fresh()
	w:onWasp("shake", nil)
	w:onWasp("noticed", nil)
	w:onWasp("lost", nil)
	w:onWasp("landed", nil)
	check(#nb.opened == 0, "its shakes, landing and losing the spider open nothing")
	w:onWasp("visit_started", nil)
	check(nb:isOpen("mud_dauber") and not nb:isOpen("what_the_wasp_does") and not nb:isOpen("getting_away"), "hearing the wasp opens the mud-dauber page")
	w:onWasp("left", false)
	check(not nb:isOpen("getting_away"), "a wasp that leaves without having seen the spider is no escape")
	w:onWasp("left", true)
	check(nb:isOpen("getting_away"), "a wasp that leaves after it noticed the spider is an escape")
	w:onWasp("caught", nil)
	check(nb:isOpen("what_the_wasp_does"), "a catch opens its page")

	-- the eye view, frame by frame (the game waiting is a frame of 0 seconds)
	nb, w = fresh()
	w:frame(1.0, false, 3)
	check(#nb.opened == 0 and nb.eyeSeconds == 0, "outside the eye view nothing counts, whatever moves")
	w:frame(0.0, true, 0)
	check(nb:isOpen("eight_eyes") and not nb:isOpen("motion_first") and nb.eyeSeconds == 0, "the eye view opens the eyes page; nothing has moved in the surround yet")
	w:frame(0.5, true, 2)
	check(nb:isOpen("motion_first"), "a movement ring opens the movement page")
	for _ = 1, 38 do w:frame(0.5, true, 0) end
	check(not nb:isOpen("moving_retinas") and math.abs(nb.eyeSeconds - 19.5) < 1e-9, "19.5 s in the eye view: not yet")
	w:frame(0.0, true, 0)
	w:frame(0.0, false, 0)
	check(not nb:isOpen("moving_retinas"), "a menu holding the game (frames of nothing) adds no time")
	w:frame(0.6, true, 0)
	check(nb:isOpen("moving_retinas") and not nb:isOpen("green_uv"), "20 s opens the retina page")
	for _ = 1, 80 do w:frame(0.5, true, 0) end
	check(nb:isOpen("green_uv"), "a minute opens the colour page")

	-- every event twice opens nothing twice
	nb, w = fresh()
	local announced = 0
	nb.pageOpened:connect(function() announced += 1 end)
	for _ = 1, 3 do
		w:onJump(9)
		w:onCategory("fly_like_prey")
		w:onLife("rest_started", 0)
		w:onLife("woke", 0)
		w:onLife("moult_ready", 0)
		w:onLife("moulted", 3)
		w:onWasp("visit_started", nil)
		w:onWasp("left", true)
		w:onWasp("caught", nil)
		w:frame(30, true, 1)
	end
	check(announced == #nb.opened and announced > 0, "a page is announced once however often its moment comes")

	-- a change of world (a return to a rest, a new spider) opens nothing by itself
	nb, w = fresh()
	w:step(view({ captures = 0, energy = 0.5, flies = { fly("f", Vector3.zero, false) } }))
	w:resync()
	w:step(view({ captures = 7, energy = 0.1, taken = 3.0, flies = { fly("f", Vector3.zero, true) } }))
	check(not nb:isOpen("venom") and not nb:isOpen("hungry_at_home") and not nb:isOpen("hearing"), "after a resync the first look only takes the baseline")
	w:step(view({ captures = 8, energy = 0.1, taken = 3.0 }))
	check(nb:isOpen("venom"), "and a real catch afterwards still counts")
	-- (the start is the player's, not the world's: it is not opened again, and not lost)
	local before = #nb.opened
	w:resync()
	w:step(view())
	check(#nb.opened == before, "a resync does not open the start page again")

	-- one long scripted game opens every page there is but the unwired one
	nb, w = fresh()
	w:step(view({ started = false }))
	w:step(view())
	w:onJump(9)
	w:frame(0.0, true, 1)
	w:frame(61.0, true, 1)
	w:onCategory("fly_like_prey")
	w:step(view({ captures = 1 }))
	w:step(view({ captures = 1, feeding = true, taken = 0 }))
	w:step(view({ captures = 1, feeding = false, taken = 0.3 }))
	w:step(view({ captures = 1, taken = 0.3, energy = 0.2 }))
	w:step(view({ captures = 1, taken = 0.3, energy = 0.9 }))
	w:step(view({ captures = 1, taken = 0.3, energy = 0.0 }))
	local flyA = fly("a", Vector3.new(1, 0, 0), false)
	w:step(view({ captures = 1, taken = 0.3, energy = 0.0, flies = { flyA } }))
	flyA.up = true
	w:step(view({ captures = 1, taken = 0.3, energy = 0.0, flies = { flyA } }))
	for _, kind in { "rest_started", "woke", "moult_ready", "moulted" } do w:onLife(kind, 3) end
	w:onWasp("visit_started", nil)
	w:onWasp("left", true)
	w:onWasp("caught", nil)
	local unopened: { string } = {}
	for _, p in nb.pages do if not nb:isOpen(p.id) then table.insert(unopened, p.trigger) end end
	local unwired: { string } = {}
	for trigger in NotebookWatch.UNWIRED do table.insert(unwired, trigger) end
	check(same(unopened, unwired) and same(unwired, { "felt" }), "every page but 'felt' (no vibration sense in the port) opens from a real event: left over: " .. table.concat(unopened, ", "))
	check(#nb.opened == 23, `the long game opened 23 pages ({#nb.opened})`)
end

-- ---------------------------------------------------------------- the client: the real loop wires the watcher, the panel and the menus
-- The client scripts themselves under stub services (as tests/client_smoke.luau): keys go through the same Context Action callbacks
-- the engine calls, frames through the bound render step. Wiring and runtime errors, not rendering or an input device.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local SpiderInput = require("../src/Client/SpiderInput")
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local stubs = ClientStubs
local frame = stubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	if not g then return nil end
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
local KEYS = { Feed = "E", Jump = "Space", Cancel = "Q", Drop = "F", Forward = "W", Back = "S", Eye = "V", Reset = "Backspace", Notebook = "N", Menu = "M", Slow = "T" }
local function key(action: string, down: boolean)
	local fn = stubs.actions["Spider" .. action]
	assert(fn, "no binding for " .. action)
	fn("Spider" .. action, if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		{ KeyCode = Enum.KeyCode[KEYS[action] or action], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
end
local function tap(action: string) key(action, true); frames(1); key(action, false); frames(1) end
-- A key or button the open notebook hears (its own Context Action, above the game's).
local function nbKey(code: string, position: any?)
	local fn = stubs.actions["WindowsillNotebook"]
	assert(fn, "the notebook is not listening")
	fn("WindowsillNotebook", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = position or Vector3.zero })
end
local function spider(): Vector3
	return workspace:FindFirstChild("Spider"):FindFirstChild("Root").Position
end
local d: any = stubs.driver
local function opened(): string return table.concat(d.notebook.opened, ",") end

check(loaded and d ~= nil, "the client loads and hands its test driver over")
if loaded and d then
	frames(120)
	local book = d.notebook
	check(book ~= nil and d.notebookWatch ~= nil and d.notebookPanel ~= nil, "the client has a book, a watcher and a panel")
	check(book:isOpen("bold_jumper"), "the first page opens at the start of the life")
	check(gui:FindFirstChild("SpiderNotebook") ~= nil and gui:FindFirstChild("SpiderNotebook").Enabled == false, "the notebook screen is there and closed")
	local note = find("SpiderPrompts", "NotebookNote")
	check(note ~= nil and note.Visible and string.find(note.Text, "New in your notebook: ", 1, true) ~= nil, "a note says a page opened: " .. tostring(note and note.Text))
	check(string.find(note.Text, "(N to read)", 1, true) ~= nil, "and names the key: " .. note.Text)
	print("NOTEBOOK client: after the first 120 frames the book holds: " .. opened())

	-- N opens it and the world waits
	local lifeHour = d.life.clock.hour
	local p0 = spider()
	local tick0 = d.prey.tick
	tap("Notebook")
	local panel = d.notebookPanel
	check(panel:isShowing() and gui:FindFirstChild("SpiderNotebook").Enabled, "N opens the notebook")
	check(find("SpiderPrompts", "Day") ~= nil and gui:FindFirstChild("SpiderPrompts").Enabled == false, "the game's own screen steps aside")
	check(not note.Visible, "and the note is gone")
	key("Forward", true); frames(60); key("Forward", false); frames(2)
	check((spider() - p0).Magnitude < 0.05 and d.prey.tick == tick0 and d.life.clock.hour == lifeHour, "the world waits while the notebook is open (no walking, no ticks, no time)")
	local newest: any = book:view(book:newest() or "")
	check(newest ~= nil and find("SpiderNotebook", "Title").Text == newest.title and find("SpiderNotebook", "Title").Visible, "it opens at the newest page and shows its title")
	check(find("SpiderNotebook", "Sources").Text == NotebookText.sourcesText(newest.sources), "with its source")
	check(find("SpiderNotebook", "InThisGame").Text == NotebookText.gameLine(newest.game, "keyboard"), "and where the game simplifies")
	-- (a second Jump press while it is open does not leap)
	key("Jump", true); frames(5); key("Jump", false); frames(2)
	check(not d.notebook:isOpen("dragline"), "a Space press behind the notebook leaps nowhere")
	nbKey("N")
	check(not panel:isShowing() and not gui:FindFirstChild("SpiderNotebook").Enabled and gui:FindFirstChild("SpiderPrompts").Enabled, "N closes it and the game's screen comes back")
	check(stubs.actions["WindowsillNotebook"] == nil, "and it stops listening")
	key("Forward", true); frames(30); key("Forward", false); frames(2)
	check((spider() - p0).Magnitude > 0.5 and d.prey.tick > tick0, "the game goes on")

	-- a hop opens the dragline page (real motor, real jump input), with a note that names it
	frames(20)
	tap("Jump"); frames(60)
	check(book:isOpen("dragline") and not book:isOpen("legs_push"), "a hop opens the dragline page (and not the far-jump page): " .. opened())
	note = find("SpiderPrompts", "NotebookNote")
	local latest: any = book:view(book:newest() or "")
	check(note.Visible and latest ~= nil and string.find(note.Text, "New in your notebook: " .. latest.title, 1, true) ~= nil, "the note names the newest page: " .. note.Text)
	frames(60 * 7)
	check(not note.Visible, "and goes after six seconds")

	-- the spider-eye view counts the game's time: slow motion slows it, a menu holds it
	tap("Eye"); frames(30)
	check(book:isOpen("eight_eyes"), "the spider-eye view opens the eyes page")
	local e0 = book.eyeSeconds
	frames(60)
	check(math.abs((book.eyeSeconds - e0) - 1.0) < 0.05, `a second in the eye view adds a second ({book.eyeSeconds - e0})`)
	tap("Slow"); e0 = book.eyeSeconds; frames(60)
	check(math.abs((book.eyeSeconds - e0) - 0.5) < 0.05, `slow motion counts half ({book.eyeSeconds - e0})`)
	tap("Slow")
	tap("Notebook"); e0 = book.eyeSeconds; frames(60)
	check(book.eyeSeconds == e0, "with the notebook open no time in the eye view passes")
	nbKey("N")
	tap("Eye"); frames(2)
	e0 = book.eyeSeconds; frames(60)
	check(book.eyeSeconds == e0, "back in the third person it stops counting")

	-- checkpoint recovery: a rest in the crack keeps a checkpoint; a page found afterwards survives the return, and the return opens nothing
	d.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	d.life.clock.hour = 12
	tap("Feed"); frames(2)
	check(d.life.resting and book:isOpen("retreat"), "a rest opens the retreat page")
	check(d.checkpoints:loadBest().ok, "and keeps a checkpoint")
	local before = opened()
	tap("Feed"); frames(2) -- end the rest
	d.camera.eyeView = false
	book:notice("felt") -- a page found after the checkpoint (no event of the port opens this one, so it stands for any)
	local after = opened()
	check(after ~= before, "a page found after the rest")
	key("Reset", true); frames(1); key("Reset", false); frames(2)
	check(d.lifeSpider().inRetreat and d.life.resting, "back resting in the crack")
	check(opened() == after, "a return to the rest erases no page and opens none: " .. opened())
	check(book:isOpen("felt") and book:isOpen("retreat"), "the page found after the checkpoint is still there")
	frames(30)
	check(opened() == after, "and the first look afterwards opens nothing")
	-- the checkpoint record has nothing of the book in it
	local record = d.checkpoints:loadBest().record
	check(record ~= nil, "(the checkpoint has a record)")
	local function hasKey(t: any, name: string): boolean
		if type(t) ~= "table" then return false end
		for k, v in t do if k == name or hasKey(v, name) then return true end end
		return false
	end
	check(not hasKey(record, "opened") and not hasKey(record, "notebook") and not hasKey(record, "eyeSeconds"), "a checkpoint record carries no page")

	-- a new, unrelated spider opens the same book
	local deaths0 = d.session.deaths
	d.session:endLife("starved", { hours = 5, meals = 1, wasp_visits = 0, wasp_escapes = 0 })
	local keep = opened()
	d.continueAnother(); frames(30)
	check(opened() == keep, "a new, unrelated spider keeps the book and opens nothing by being new: " .. opened())
	check(d.notebook == book and book:isOpen("bold_jumper"), "it is the same book")
	d.fresh("free", false, nil); frames(30)
	check(opened() == keep, "so does free play: " .. opened())
	d.session.mode = "main"
	d.fresh("main", false, nil); frames(30)
	check(opened() == keep, "and a new life in the main mode")

	-- the life menu offers the notebook; closing it comes back to the menu
	d.openMenu()
	check(d.menu:isShowing() and find("SpiderLifeMenu", "Notebook") ~= nil, "the life menu has a Notebook choice")
	check(d.menu:choose("Notebook"), "chosen")
	check(panel:isShowing() and not d.menu:isShowing(), "it opens the notebook over the menu")
	nbKey("Q")
	check(not panel:isShowing() and d.menu:isShowing(), "closing it goes back to the menu")
	check(find("SpiderLifeMenu", "Notebook") ~= nil and find("SpiderLifeMenu", "Resume") ~= nil, "which is whole again")
	d.menu:choose("Resume"); frames(3)
	check(not d.menu:isShowing() and gui:FindFirstChild("SpiderPrompts").Enabled, "Resume goes on")

	-- the life loop's events through the real loop: ready to moult, moulted, grown up
	d.fresh("main", false, nil); frames(5)
	d.place(Vector3.new(-25.5, 0.31, 6.0)); frames(30)
	d.life.clock.hour = 12
	check(not book:isOpen("outgrowing_a_skin") and not book:isOpen("new_skin") and not book:isOpen("grown_up"), "no moult pages yet")
	d.needs.energy = 0.05
	d.needs:grantEnergy(0.9, "test_meal") -- a meal's worth of food, booked as a real grant
	frames(3)
	check(d.life.growth.ready and book:isOpen("outgrowing_a_skin"), "being ready to moult opens its page")
	tap("Feed"); frames(3)
	check(d.life.growth:isMoulting(), "a rest in the crack begins the moult")
	d.life.growth.moultingHoursLeft = 0.01
	frames(60)
	check(d.life.growth.stage == 1 and book:isOpen("new_skin") and not book:isOpen("grown_up"), "the moult opens the new-skin page, not the adult one")
	d.life.growth.stage, d.life.growth.softHoursLeft, d.life.growth.ready = 2, 0, true
	frames(3)
	check(d.life.growth:isMoulting(), "the next moult begins")
	d.life.growth.moultingHoursLeft = 0.01
	frames(60)
	check(d.life.growth.stage == 3 and book:isOpen("grown_up"), "the moult to the adult opens the adult page")
	check(d.session.finishedMain, "(and the adult unlocks Easy, as before)")

	-- the wasp through the real loop: heard, got away from, then caught; the end screen offers the notebook
	local wasp, prey = d.wasp, d.prey
	d.fresh("main", false, nil); frames(5)
	d.place(Vector3.new(2.0, 0.31, 6.0))
	d.life.clock.day, d.life.clock.hour = 3, 12.0
	prey.feeding.mealsFinished = 1
	frames(30)
	check(not book:isOpen("mud_dauber"), "no wasp, no wasp page")
	workspace:SetAttribute("WaspForce", "floor_middle")
	frames(30)
	check(wasp:isVisiting() and book:isOpen("mud_dauber") and not book:isOpen("getting_away") and not book:isOpen("what_the_wasp_does"), "hearing the wasp opens the mud-dauber page")
	wasp.speed = 1e6
	frames(3)
	wasp.noticedThisVisit = true
	wasp:_beginLeaving()
	wasp.speed = 1e6
	frames(30)
	check(not wasp:isVisiting() and book:isOpen("getting_away") and not book:isOpen("what_the_wasp_does"), "a wasp that left after noticing the spider opens the getting-away page")
	d.life.clock.day, d.life.clock.hour = 5, 12.0
	frames(5)
	workspace:SetAttribute("WaspForce", "floor_middle")
	frames(30)
	check(wasp:isVisiting(), "a second visit")
	wasp.speed = 1e6
	frames(3)
	wasp.notice, wasp.lastSeen = 1.0, d.motor.pos
	local seized = false
	for _ = 1, 60 * 12 do
		frame(1 / 60)
		if d.motor.seized then seized = true break end
	end
	check(seized and book:isOpen("what_the_wasp_does"), "the catch opens the wasp page")
	wasp.speed = 1e6
	for _ = 1, 60 do
		frame(1 / 60)
		if d.caughtPanel:isShowing() then break end
	end
	check(d.caughtPanel:isShowing(), "the end screen comes")
	d.caughtPanel:update(10.0)
	check(find("SpiderCaught", "Notebook") ~= nil, "the end screen has a Notebook choice")
	check(d.caughtPanel:choose("Notebook"), "chosen")
	check(panel:isShowing() and not d.caughtPanel:isShowing(), "it opens the notebook over the end screen")
	check(find("SpiderNotebook", "Title").Text == book:view("what_the_wasp_does").title, "at the page the catch just opened")
	nbKey("Q")
	check(not panel:isShowing() and d.caughtPanel:isShowing() and find("SpiderCaught", "Another") ~= nil, "closing goes back to the end screen")
	check(d.session.deaths == deaths0 + 2 and d.session.ended, "without ending the life twice")
	d.caughtPanel:choose("Another"); frames(5)
	check(not d.caughtPanel:isShowing() and not d.session.ended, "and the life goes on as another spider")
	check(book:isOpen("what_the_wasp_does") and book:isOpen("grown_up"), "the book is as it was")
end

print(`NOTEBOOK passed={passed} failed={failed}`)
if failed > 0 then error("notebook failed") end
