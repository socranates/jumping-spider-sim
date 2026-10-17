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

print(`NOTEBOOK passed={passed} failed={failed}`)
if failed > 0 then error("notebook failed") end
