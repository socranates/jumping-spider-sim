-- The naturalist's notebook (LEARN-01, ported as ROBLOX-37). NOTEBOOK passed=N failed=M.
-- Which expectations come from where: Godot's own hand-written tests (tests/integration/test_learn01_notebook.gd) are hand-ported
-- below, one block each, named for the Godot test. The Godot model could not be exported as goldens here (no Godot in this
-- environment), so the pages themselves are checked word for word against a copy of the frozen data/notebook/pages.json
-- (tests/notebook_reference.json, copied by tools/gen_notebook_pages.py), and nothing is generated from the port under test.
local NotebookPages = require("../src/Shared/Data/NotebookPages")
local AntMimic = require("../src/Shared/Data/AntMimic")
local FieldNotebook = require("../src/Shared/Learning/FieldNotebook")
local NotebookWatch = require("../src/Shared/Learning/NotebookWatch")
local NotebookText = require("../src/Shared/UI/NotebookText")
local TarantulaText = require("../src/Shared/UI/TarantulaText")
local ControlText = require("../src/Shared/UI/ControlText")
local HudLayout = require("../src/Shared/UI/HudLayout")
local SpiderInput = require("../src/Client/SpiderInput")
local ref = require("./notebook_reference")
local passed, failed = 0, 0
local stubs = ClientStubs
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
local ADAPTED = { "bold_jumper", "dragline", "legs_push", "hearing", "green_uv", "home_before_dark", "hungry_at_home", "new_skin", "grown_up", "mud_dauber", "what_the_wasp_does", "going_without_food" }
-- The audit of 2026-10-19 corrected one sentence of each of these four texts (the generator's TEXT_FIXES; docs/NOTEBOOK_SOURCES.md says why). Godot's whole text stays as godotText.
local REVISED = { "grown_up", "mud_dauber", "getting_away", "going_without_food" }
local STABLE = {
	"bold_jumper", "dragline", "legs_push", "eight_eyes", "moving_retinas", "motion_first", "hunting_by_sight", "venom", "drinking",
	"felt", "hearing", "retreat", "depth_blur", "green_uv", "home_before_dark", "hungry_at_home", "full_abdomen", "outgrowing_a_skin",
	"new_skin", "grown_up", "mud_dauber", "what_the_wasp_does", "getting_away", "going_without_food", "peacock_dance", "walking_like_an_ant", "eggs_and_wind", "tarantula_cousins",
	"ground_life", "springtails", "leafhoppers", "small_moths", "crane_flies",
	"ladybirds", "millipedes", "garden_snails", "harvestmen", -- (ROBLOX-105)
	"hoverflies", -- (ROBLOX-117)
	"the_cat", -- (ROBLOX-118)
	"crab_spider", -- (ROBLOX-119)
	"robin", "field_crickets", -- (ROBLOX-120)
}
do
	local book = FieldNotebook.new()
	check(#book.dropped == 0, "no page was left out for a missing field or an unknown trigger")
	check(#book.pages == #ref.pages + 18 and #ref.pages == 24, `all of Godot's {#ref.pages} pages are here, then the peacock page, the ant-mimic page, the eggs-and-wind page, the tarantula page, the ground-life page, the bestiary's four (ROBLOX-101), its ambient four (ROBLOX-105), the hoverflies (ROBLOX-117), the cat (ROBLOX-118), the crab spider (ROBLOX-119), the robin and the field cricket (ROBLOX-120) ({#book.pages})`)
	check(#book.pages >= 12, "there is a first set of pages")
	check(same(ids((function() local l = {} for _, p in book.pages do table.insert(l, { id = p.id, title = p.title }) end return l end)()), STABLE), "the page ids are the stable ones, in Godot's order")
	local seen: { [string]: boolean } = {}
	local adapted: { string } = {}
	local revised: { string } = {}
	local urls, refUrls = 0, 0
	for i, p in book.pages do
		local g: any = ref.pages[i] or p
		check(#FieldNotebook.problems(p) == 0, `page {p.id} is complete`)
		check(not seen[p.id], `page ids are unique ({p.id})`)
		seen[p.id] = true
		check(#p.text <= 520, `page {p.id} is short enough to read in a moment ({#p.text} characters)`)
		local godotText: string = (string.gsub(g.text, "You are a bold jumping spider,", "The first spider is inspired by the bold jumping spider,"))
		check(p.id == g.id and p.trigger == g.trigger and p.title == g.title, `page {p.id}: id, trigger and title are Godot's, word for word`)
		if p.text ~= godotText then
			table.insert(revised, p.id)
			check(p.godotText == godotText and p.text ~= "", `page {p.id}: Godot's own text is kept as godotText where the game's corrects it`)
		else
			check(p.godotText == nil, `page {p.id}: the text is Godot's, word for word, and there is no godotText`)
		end
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
	check(same(revised, REVISED), "exactly these pages have a corrected text: " .. table.concat(revised, ", "))
	-- Every trigger a page names is one the notebook has; Godot's list is whole.
	local triggers = { "start", "jump", "jump_far", "jump_long", "eye_view", "eye_time_20", "eye_time_60", "shimmer", "fly_recognised", "catch", "meal", "felt", "buzz", "rest", "sleep", "hungry", "well_fed", "moult_ready", "moulted", "adult", "wasp", "wasp_escaped", "wasp_caught", "starving", "dance", "antennae", "hatched", "tarantula", "garden_bed", "look_springtail", "look_leafhopper", "look_moth", "look_crane_fly", "look_ladybird", "look_millipede", "look_snail", "look_harvestman", "look_hoverfly", "cat", "crab_spider", "robin", "look_cricket" }
	check(same(NotebookPages.triggers, triggers), "the trigger list is Godot's, then the eighteen the Roblox game added (dance, antennae, hatched, tarantula, garden_bed, the ten close looks, the cat, the crab spider and the robin)")
	for _, p in book.pages do check(table.find(NotebookPages.triggers, p.trigger) ~= nil, `page {p.id} names a trigger the notebook has`) end
	-- The eggs-and-wind page (ROBLOX-80): its own trigger, honest sources, and the peacock page no longer says there is no mating simulation.
	do
		local page: any
		for _, p in book.pages do if p.id == "eggs_and_wind" then page = p end end
		check(page ~= nil and page.trigger == "hatched" and page.godotGame == nil, "the eggs-and-wind page opens when the eggs hatch, and is the game's own (no Godot line)")
		check(page ~= nil and #page.sources == 4 and string.find(page.sources[1], "Journal of Arachnology 6: 1-29", 1, true) ~= nil and string.find(page.sources[3], "10.1079/BER2004350", 1, true) ~= nil and string.find(page.sources[4], "Current Biology 28(14)", 1, true) ~= nil, "its four sources are named in the notebook's style")
		check(page ~= nil and string.find(page.game, "male", 1, true) ~= nil and string.find(page.game, "fifteen minutes", 1, true) ~= nil and string.find(page.game, "mottled grey-brown", 1, true) ~= nil and string.find(page.game, "plain brown", 1, true) == nil, "the game note says where the game departs from the spiders")
		local fresh = FieldNotebook.new()
		check(#fresh:notice("hatched") == 1 and fresh:isOpen("eggs_and_wind") and #fresh:notice("hatched") == 0, "the trigger opens the page, once")
		for _, p in book.pages do
			if p.id == "peacock_dance" then check(string.find(p.game, "no mating simulation", 1, true) == nil and string.find(p.game, "court a mate", 1, true) ~= nil, "the peacock page's game note says the dance courts a mate") end
		end
	end
	-- The tarantula page (ROBLOX-83): its own trigger, two sources in the notebook's style, an honest game note, and no claim about the greenbottle's hairs.
	do
		local page: any
		for _, p in book.pages do if p.id == "tarantula_cousins" then page = p end end
		check(page ~= nil and page.trigger == "tarantula" and page.title == "Velvet cousins (Theraphosidae)" and page.godotGame == nil, "the tarantula page opens on the tarantula trigger, has its title, and is the game's own (no Godot line)")
		check(page ~= nil and #page.sources == 2 and string.find(page.sources[1], "Foelix, R. F. (2011). Biology of Spiders, 3rd edition. Oxford University Press.", 1, true) == 1 and string.find(page.sources[2], "Bertani, R. & Guadanucci, J. P. L. (2013)", 1, true) == 1 and string.find(page.sources[2], "Zoologia 30(4): 403-418", 1, true) ~= nil and string.find(page.sources[2], "10.1590/S1984-46702013000400006", 1, true) ~= nil, "its two sources are named in the notebook's style")
		check(page ~= nil and string.find(page.text, "not jumping spiders", 1, true) ~= nil and string.find(page.text, "urticating", 1, true) ~= nil and string.find(page.text, "rears up", 1, true) ~= nil, "the page says tarantulas are not jumping spiders, and what they do")
		check(page ~= nil and string.find(page.game, "costumes", 1, true) ~= nil and string.find(page.game, "invented angles", 1, true) ~= nil and string.find(page.game, "no silk mat", 1, true) ~= nil and string.find(page.game, "no hairs are cast", 1, true) ~= nil and string.find(page.game, "small cluster of hairs", 1, true) ~= nil and string.find(page.game, "only a colour", 1, true) == nil and string.find(page.game, "five or more centimetres", 1, true) ~= nil, "the game note says where the game departs from the spiders (the redknee's patch is drawn as hairs, none are cast)")
		local fresh = FieldNotebook.new()
		check(#fresh:notice("tarantula") == 1 and fresh:isOpen("tarantula_cousins") and #fresh:notice("tarantula") == 0, "the trigger opens the page, once")
		check(not FieldNotebook.new():isOpen("tarantula_cousins"), "the page is not open at the start")
	end
	-- The ground-life page (ROBLOX-96): the bed's gnats, aphids and woodlice, opened by the first step onto a garden bed; five sources in the notebook's style; a game note
	-- that says what is the game's own; no claim beyond the sources (docs/NOTEBOOK_SOURCES.md).
	do
		local page: any
		for _, p in book.pages do if p.id == "ground_life" then page = p end end
		check(page ~= nil and page.trigger == "garden_bed" and page.title == "Life on the ground" and page.godotGame == nil and page.godotText == nil, "the ground-life page opens on the garden_bed trigger, has its title, and is the game's own")
		-- (ROBLOX-101 checked the five: the gnats' fact sheet is of 2003, reviewed 2025, and the woodlice's sentence gains the Kentucky fact sheet it was checked against)
		check(page ~= nil and #page.sources == 6 and string.find(page.sources[1], "Cranshaw, W. S. & Cloyd, R. A. (2003, reviewed 2025)", 1, true) == 1 and string.find(page.sources[2], "Warren, P. & Schalau, J. (2014)", 1, true) == 1
			and string.find(page.sources[3], "Jackson, R. R. (1977)", 1, true) == 1 and string.find(page.sources[3], "Journal of Arachnology 5: 145-149", 1, true) ~= nil
			and string.find(page.sources[4], "Hopkin, S. P. (1991)", 1, true) == 1 and string.find(page.sources[5], "ENTFACT-439", 1, true) ~= nil and string.find(page.sources[6], "10.1098/rsif.2025.0260", 1, true) ~= nil, "its six sources are named in the notebook's style")
		local function has(s: string, part: string): boolean return string.find(s, part, 1, true) ~= nil end
		check(page ~= nil and has(page.text, "Fungus gnats") and has(page.text, "damp soil") and has(page.text, "Aphids") and has(page.text, "sap") and has(page.text, "Phidippus johnsoni takes aphids")
			and has(page.text, "crustaceans, not insects") and has(page.text, "seven pairs of legs") and has(page.text, "puts spiders off") and #page.text <= 520, "the page says what each is and why the spider hunts two and leaves the third")
		check(page ~= nil and has(page.text, "live in colonies") and not has(page.text, "feed in groups") and has(page.text, "glands on the sides of the body") and not has(page.text, "in their armour"), "ROBLOX-101's corrections: the aphids' colonies, the woodlice's glands where the source puts them")
		check(page ~= nil and has(page.game, "a third of a housefly meal") and has(page.game, "an aphid a sixth") and has(page.game, "only walk") and has(page.game, "cannot be caught") and has(page.game, "no measured numbers"), "the game note says what is the game's own")
		local fresh = FieldNotebook.new()
		check(#fresh:notice("garden_bed") == 1 and fresh:isOpen("ground_life") and #fresh:notice("garden_bed") == 0, "the trigger opens the page, once")
		check(not FieldNotebook.new():isOpen("ground_life"), "the page is not open at the start")
	end
	-- The bestiary's four pages (ROBLOX-101): each the game's own, opened by its close look, with its sources in the notebook's style, under 520 characters, its game
	-- note saying the numbers are the game's.
	do
		local function has(s: string, part: string): boolean return string.find(s, part, 1, true) ~= nil end
		local want = {
			{ "springtails", "look_springtail", 3, { "furcula", "Collembola", "10 cm", "spiders" }, { "an eighth of a housefly meal", "the game's" } },
			{ "leafhoppers", "look_leafhopper", 4, { "Cicadellidae", "sidestep", "other side of the stem or leaf", "3 to 5 thousandths" }, { "half a housefly meal", "the game's" } },
			{ "small_moths", "look_moth", 4, { "scale-winged", "back toward the light", "sticky silk", "Phidippus johnsoni" }, { "a housefly meal", "the game's borrowing" } },
			{ "crane_flies", "look_crane_fly", 3, { "Tipulidae", "do not bite", "break off easily", "a quarter to three quarters" }, { "two housefly meals", "leave a leg" } },
			-- (ROBLOX-105: the ambient four)
			{ "ladybirds", "look_ladybird", 2, { "warning", "leg joints", "reflex bleeding", "aphids", "alligator" }, { "let it go", "the game's" } },
			{ "millipedes", "look_millipede", 1, { "two pairs of legs on each segment", "decaying vegetation", "coil", "body armour" }, { "coils", "the game's" } },
			{ "garden_snails", "look_snail", 2, { "28 to 32 mm", "upper pair bears the eyes", "slimy trail", "nocturnal" }, { "eye stalks", "the game's" } },
			{ "harvestmen", "look_harvestman", 2, { "not spiders", "two eyes", "no silk or venom glands", "twitching" }, { "takes no notice", "the game's" } },
			-- (ROBLOX-117: the hoverflies)
			{ "hoverflies", "look_hoverfly", 2, { "Syrphidae", "do not bite or sting", "single pair of wings", "nectar and pollen", "400" }, { "housefly meal and a half", "the game's" } },
			{ "the_cat", "cat", 4, { "23 to 25 cm", "1.3 to 4.0 billion birds", "about half as many mammals", "airborne sound" }, { "bell", "the game's" } }, -- (ROBLOX-118)
			{ "crab_spider", "crab_spider", 3, { "Misumena vatia", "first two pairs of legs held open", "10 to 25 days", "goldenrod" }, { "yarrow", "drop clear", "the game's" } }, -- (ROBLOX-119)
			{ "robin", "robin", 3, { "20 to 28 cm", "head cocked to one side", "by sight", "spiders", "pick! tut-tut-tut" }, { "shadow", "keeping still", "the game's" } }, -- (ROBLOX-120)
			{ "field_crickets", "look_cricket", 3, { "Gryllus pennsylvanicus", "15 to 25 mm", "mostly at night", "ears are on its front legs" }, { "three houseflies", "kicks hard", "the game's" } }, -- (ROBLOX-120)
		}
		for _, w in want do
			local page: any
			for _, p in book.pages do if p.id == w[1] then page = p end end
			check(page ~= nil and page.trigger == w[2] and page.godotGame == nil and page.godotText == nil and #page.sources == w[3] and #page.text <= 520, `{w[1]}: its trigger, the game's own, {w[3]} sources, {if page then #page.text else 0} characters`)
			for _, part in w[4] :: { string } do check(page ~= nil and has(page.text, part), `{w[1]} says "{part}"`) end
			for _, part in w[5] :: { string } do check(page ~= nil and has(page.game, part), `{w[1]}'s game note says "{part}"`) end
			local fresh = FieldNotebook.new()
			check(not fresh:isOpen(w[1]) and #fresh:notice(w[2]) == 1 and fresh:isOpen(w[1]) and #fresh:notice(w[2]) == 0, `{w[1]}: closed at the start, opened once`)
		end
		check(NotebookPages.lookWu == 4 and NotebookPages.looks.springtail == "look_springtail" and NotebookPages.looks.crane_fly == "look_crane_fly", "a close look is four studs")
	end
	-- The audit of 2026-10-19 (docs/NOTEBOOK_SOURCES.md): what each corrected page now says, and the claim it no longer makes.
	do
		local by: { [string]: any } = {}
		for _, p in book.pages do by[p.id] = p end
		local function has(s: string, part: string): boolean return string.find(s, part, 1, true) ~= nil end
		check(has(by.grown_up.text, "In the lab, males of the related Phidippus johnsoni matured after 5 to 7 moults and females after 6 to 8.") and not has(by.grown_up.text, "In the field") and not has(by.grown_up.text, "six to eight"), "Grown up gives Jackson's counts as laboratory counts")
		check(has(by.going_without_food.text, "In the lab, jumping spiders have survived weeks without food, longer when cold and still.") and not has(by.going_without_food.text, "25 to 31") and not has(by.going_without_food.text, "kept for"), "Going without food claims no figure the cited paper does not give")
		check(has(by.mud_dauber.text, "It searches by sight, then checks a spider with its antennae before it stings.") and not has(by.mud_dauber.text, "finds a spider by sight"), "A hunter of spiders: sight searches, the antennae check")
		check(has(by.getting_away.text, "The mud dauber searches by sight and then checks with its antennae, so a spider that stays out of sight is safer.") and not has(by.getting_away.text, "finds its prey by sight") and not has(by.getting_away.text, "matters most"), "Getting away: staying out of sight is safer, not all that matters")
		check(has(by.legs_push.game, "In this game the spider braces and crouches before a jump, then pushes off with its back legs.") and not has(by.legs_push.game, "does not yet") and by.legs_push.godotGame == "Watch the back legs straighten as the spider leaves the surface.", "Legs that push: the game does show the back legs pushing off")
		check(has(by.bold_jumper.game, "four growth stages (three moults)") and not has(by.bold_jumper.game, "three growth stages") and has(by.bold_jumper.game, "The peacock spider, the ant mimic and the two tarantulas are costumes on the same body"), "The first page names every costume and the four stages")
		check(has(by.walking_like_an_ant.text, "about a tenth of a second") and not has(by.walking_like_an_ant.text, "83") and has(by.walking_like_an_ant.game, "83 milliseconds"), "Walking like an ant: the page says a tenth of a second (the paper's abstract), the game note keeps its own 83 ms rule")
		check(has(by.eggs_and_wind.text, "court mostly by sight, and often by vibration too") and not has(by.eggs_and_wind.text, "court by sight") and #by.eggs_and_wind.text <= 520, "Eggs, silk and wind: courtship is mostly by sight and often by vibration")
		local tries = 0
		for _, entry in NotebookText.TRY do
			if string.sub(entry.text, 1, 9) == "Change to" then
				tries += 1
				check(has(entry.text, "(in Settings, or while resting)"), `To try "{entry.id}" names both ways of changing spider`)
			end
		end
		check(tries == 3, "the three spiders' invitations (peacock, ant mimic, tarantula) all say so")
	end
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
	-- ROBLOX-96: the first step onto a garden bed opens the ground-life page; the sill, the wall and a world without regions do not
	local nb, w = fresh()
	w:step(view({ region = "sill" }))
	w:step(view({ region = "house_wall" }))
	w:step(view())
	check(not nb:isOpen("ground_life"), "the sill, the wall and no region open nothing")
	w:step(view({ region = "bed" }))
	check(nb:isOpen("ground_life"), "the first step onto a bed opens the ground-life page")
	w:step(view({ region = "bed" }))
	check(#nb.opened == 2, "once (with the start page)")
end
do
	-- ROBLOX-101: a close look at a bestiary prey opens its kind's page; farther off, or a kind without a page, nothing
	local nb, w = fresh()
	local function kindFly(id: string, kind: string?, at: Vector3): any
		local f = fly(id, at, false)
		f.profile = { body = { prey_kind = kind } }
		return f
	end
	w:step(view({ spider = Vector3.zero, flies = {} }))
	w:step(view({ spider = Vector3.zero, flies = { kindFly("s", "springtail", Vector3.new(4.5, 0, 0)), kindFly("g", "fungus_gnat", Vector3.new(1, 0, 0)), kindFly("h", nil, Vector3.new(1, 0, 0)) } }))
	check(not nb:isOpen("springtails") and #nb.opened == 1, "a springtail four and a half studs off, a gnat and a house fly close by: nothing")
	w:step(view({ spider = Vector3.zero, flies = { kindFly("s", "springtail", Vector3.new(3.9, 0, 0)), kindFly("c", "crane_fly", Vector3.new(0, 2, 0)) } }))
	check(nb:isOpen("springtails") and nb:isOpen("crane_flies") and not nb:isOpen("small_moths") and not nb:isOpen("leafhoppers"), "within four studs: the springtail's page and the crane fly's")
	w:step(view({ spider = Vector3.zero, flies = { kindFly("m", "moth", Vector3.new(0, 0, 4)), kindFly("l", "leafhopper", Vector3.new(0, 0, -1)) } }))
	check(nb:isOpen("small_moths") and nb:isOpen("leafhoppers") and #nb.opened == 5, "the moth's and the leafhopper's, each once")
end
do
	-- ROBLOX-105: a close look at an ambient bug out in the open opens its kind's page; a hidden one, a far one or a woodlouse (no kind) opens nothing
	local nb, w = fresh()
	local function bug(kind: string?, at: Vector3, hidden: boolean?): any return { id = "b", kind = kind, position = at, hidden = hidden == true } end
	w:step(view({ spider = Vector3.zero }))
	w:step(view({ spider = Vector3.zero, bugs = { bug("snail", Vector3.new(4.5, 0, 0)), bug("millipede", Vector3.new(1, 0, 0), true), bug(nil, Vector3.new(0.5, 0, 0)) } }))
	check(#nb.opened == 1, "a snail four and a half studs off, a millipede under a stone, a woodlouse close by: nothing")
	w:step(view({ spider = Vector3.zero, bugs = { bug("snail", Vector3.new(3.5, 0, 0)), bug("ladybird", Vector3.new(0, 1, 0)), bug("millipede", Vector3.new(1, 0, 0)), bug("harvestman", Vector3.new(0, 0, 2)) } }))
	check(nb:isOpen("garden_snails") and nb:isOpen("ladybirds") and nb:isOpen("millipedes") and nb:isOpen("harvestmen") and #nb.opened == 5, "within four studs and in the open: each kind's page, once")
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
	w:onCat() -- (ROBLOX-118: the ranger's cat noticed the spider)
	w:onCrab() -- (ROBLOX-119: the spider came close to a crab spider)
	w:onBird() -- (ROBLOX-120: the robin was told to the spider)
	w:antennae(AntMimic.noticeSeconds)
	w:step(view({ captures = 1, taken = 0.3, energy = 0.0, flies = { flyA }, region = "bed" })) -- (ROBLOX-96: the first step onto a garden bed)
	do -- (ROBLOX-101: a close look at each of the bestiary's four)
		local near = {}
		for i, kind in { "springtail", "leafhopper", "moth", "crane_fly", "hoverfly", "cricket" } do
			local f = fly("k" .. i, Vector3.new(1, 0, 0), false)
			f.profile = { body = { prey_kind = kind } }
			table.insert(near, f)
		end
		w:step(view({ captures = 1, taken = 0.3, energy = 0.0, flies = near, region = "bed" }))
	end
	do -- (ROBLOX-105: and at each of the ambient four)
		local bugs = {}
		for i, kind in { "ladybird", "millipede", "snail", "harvestman" } do table.insert(bugs, { id = "a" .. i, kind = kind, position = Vector3.new(1, 0, 0), hidden = false }) end
		w:step(view({ captures = 1, taken = 0.3, energy = 0.0, flies = { flyA }, region = "bed", bugs = bugs }))
	end
	local unopened: { string } = {}
	for _, p in nb.pages do if not nb:isOpen(p.id) then table.insert(unopened, p.trigger) end end
	local unwired: { string } = {}
	for trigger in NotebookWatch.UNWIRED do table.insert(unwired, trigger) end
	check(same(unopened, { "felt", "dance", "hatched", "tarantula" }) and same(unwired, { "felt" }), "watcher covers all pages except unwired felt and the client-owned dance, hatching and tarantula: left over: " .. table.concat(unopened, ", "))
	check(#nb.opened == 38, `the long game opened 38 pages, the bestiary's eight, the hoverflies, the cat, the crab spider, the robin and the cricket with them ({#nb.opened})`)
end

-- ---------------------------------------------------------------- the words and the layout (pure)
do
	check(NotebookText.fill("{reel} up, {drop} down", "keyboard") == "W up, F down", "a control is named for the keyboard")
	check(NotebookText.fill("{reel} up, {drop} down", "touch") == "↑ up, Silk down", "and for touch")
	ControlText.setPadStyle("xbox")
	check(NotebookText.fill("{letGo} {drop} {focus}", "gamepad") == "B X LT", "and for an Xbox controller")
	ControlText.setPadStyle("playstation")
	check(NotebookText.fill("{letGo} {drop} {focus}", "gamepad") == "Circle Square L2", "and for a PlayStation controller")
	check(NotebookText.fill("{nonsense} stays", "keyboard") == "{nonsense} stays", "a name nothing knows is left as it was")
	-- ROBLOX-92: the tarantula page named its key "(X)" for every device; it says {display}, filled with the device's own key (on touch the tarantulas' button, Rear up, not the peacock's Dance)
	ControlText.setPadStyle("xbox")
	check(NotebookText.fill("({display})", "keyboard") == "(X)" and NotebookText.fill("({display})", "gamepad") == "(RB)" and NotebookText.fill("({display})", "touch") == "(Rear up)", "{display} is the display key by device")
	ControlText.setPadStyle("playstation")
	check(NotebookText.fill("({display})", "gamepad") == "(R1)", "and on a PlayStation controller")
	do
		local page: any = nil
		for _, p in NotebookPages.pages do if p.id == "tarantula_cousins" then page = p end end
		check(page ~= nil and string.find(page.game, "({display})", 1, true) ~= nil and string.find(page.game, "(X)", 1, true) == nil, "the tarantula page no longer hardcodes the key")
		check(page ~= nil and string.find(page.game, "no silk mat is laid", 1, true) ~= nil and string.find(TarantulaText.helpLine("keyboard"), "rear up and turn", 1, true) ~= nil and string.find(TarantulaText.helpLine("keyboard"), "silk mat", 1, true) == nil,
			"the page and the controls card say the same thing: a rear-up and a turn, no silk mat is laid")
		for _, device in { "keyboard", "gamepad", "touch" } do
			check(string.find(NotebookText.fill(page.game, device), "{", 1, true) == nil, `{device}: every name on the page is filled`)
		end
	end
	check(NotebookText.gameLine("", "keyboard") == nil, "a page with nothing to say about the game shows no line (Godot)")
	check(NotebookText.gameLine("Hello.", "keyboard") == "In this game: Hello.", "a line starts 'In this game: '")
	local dragline = FieldNotebook.new():view("dragline")
	check(dragline == nil, "(not before it is found)")
	local all = NotebookPages.pages
	local line: string = NotebookText.gameLine(all[2].game, "keyboard") :: string
	check(string.find(line, "{", 1, true) == nil and string.find(line, "W reels in", 1, true) ~= nil and string.find(line, "holding Q lets go", 1, true) ~= nil and string.find(line, "F lets it down", 1, true) ~= nil, "the dragline page names the keyboard's keys: " .. line)
	line = NotebookText.gameLine(all[2].game, "gamepad") :: string
	check(string.find(line, "Square lets it down", 1, true) ~= nil and string.find(line, "holding Circle lets go", 1, true) ~= nil and string.find(line, "Stick up reels in", 1, true) ~= nil, "and a PlayStation controller's: " .. line)
	line = NotebookText.gameLine(all[14].game, "keyboard") :: string
	check(string.find(line, "(Right mouse)", 1, true) ~= nil, "the colour page names the Focus control: " .. line)
	for _, p in all do
		for _, device in { "keyboard", "gamepad", "touch" } do
			local text = NotebookText.gameLine(p.game, device :: any)
			check(text == nil or string.find(text, "{", 1, true) == nil, `page {p.id}: every control name is filled in on {device}`)
		end
	end
	check(NotebookText.sourcesText({ "A (2000)." }) == "Source: A (2000).", "one source")
	check(NotebookText.sourcesText({ "A (2000).", "B (2001). https://doi.org/x" }) == "Sources:\nA (2000).\nB (2001). https://doi.org/x", "several sources, links in the text")
	check(string.find(NotebookText.sourcesText(all[2].sources), "https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/", 1, true) ~= nil, "a page's link is kept")
	-- how to open it, per device (a controller has no spare button: the D-pad walks)
	ControlText.setPadStyle("xbox")
	check(NotebookText.openHint("keyboard") == "N", "N on a keyboard")
	check(NotebookText.openHint("touch") == "the Notebook button", "the button on touch")
	check(NotebookText.openHint("gamepad") == "View, then Notebook,", "the menu on a controller")
	ControlText.setPadStyle("playstation")
	check(NotebookText.openHint("gamepad") == "Touchpad, then Notebook,", "and the Touchpad on a PlayStation controller")
	check(NotebookText.note("The bite", "keyboard") == "New in your notebook: The bite\n(N to read)", "Godot's words for the note")
	check(NotebookText.note("The bite", "gamepad") == "New in your notebook: The bite\n(Touchpad, then Notebook, to read)", "the note on a PlayStation controller")
	check(string.find(NotebookText.controls("gamepad", true), "Circle: back / close", 1, true) ~= nil and string.find(NotebookText.controls("gamepad", false), "Circle: close", 1, true) ~= nil, "the controller's controls line uses PlayStation names")
	ControlText.setPadStyle("xbox")
	check(string.find(NotebookText.controls("gamepad", true), "B: back / close", 1, true) ~= nil and string.find(NotebookText.controls("gamepad", true), "A: open", 1, true) ~= nil, "and the Xbox one's")
	check(string.find(NotebookText.controls("keyboard", false), "N or Q: close", 1, true) ~= nil and string.find(NotebookText.controls("keyboard", true), "Enter: open", 1, true) ~= nil, "the keyboard's")
	check(string.find(NotebookText.controls("touch", true), "Tap a page", 1, true) ~= nil, "touch's")
	-- Godot says "N / D-pad up"; the port's D-pad walks, and nothing may promise it
	for _, device in { "keyboard", "gamepad", "touch" } do
		local text = NotebookText.note("T", device :: any) .. NotebookText.controls(device :: any, true) .. NotebookText.controls(device :: any, false)
		check(string.find(text, "D-pad up", 1, true) == nil, `nothing on {device} promises D-pad up`)
	end

	-- layout: side by side needs room; a phone held sideways, a portrait phone and large text get one pane at a time
	check(NotebookText.layout(1280, 720, 1).sideBySide, "a laptop screen shows both panes")
	check(NotebookText.layout(1024, 768, 1).sideBySide, "so does a tablet")
	check(not NotebookText.layout(568, 320, 1).sideBySide, "a phone held sideways shows one")
	check(not NotebookText.layout(360, 640, 1).sideBySide, "a portrait phone shows one")
	check(NotebookText.layout(1024, 768, 1.5).sideBySide and not NotebookText.layout(900, 600, 1.5).sideBySide, "large text needs more width for two panes")
	check(NotebookText.layout(1280, 720, 1).listFraction == 0.34 and NotebookText.layout(568, 320, 1).listFraction == 1.0, "the list takes a third, or everything")
	-- short screens: what scrolls still has room
	for _, size in { { 568, 320 }, { 640, 360 }, { 360, 640 }, { 1280, 720 }, { 1920, 1080 } } do
		for _, scale in { 1.0, NotebookText.LARGE } do
			local m = NotebookText.metrics(size[1], size[2], scale)
			check(m.body >= 100 or (size[2] < 340 and scale > 1 and m.body >= 80), `{size[1]}x{size[2]} at {scale}x text keeps {math.floor(m.body)} px for the pages`)
			check(m.paperW <= size[1] and m.paperH <= size[2] and m.paperW <= 1040 and m.paperH <= 820, `{size[1]}x{size[2]}: the paper fits the safe area`)
		end
	end
	check(NotebookText.metrics(568, 320, 1).body >= 140 and NotebookText.metrics(568, 320, 1).hint == 0, "a short phone hides long control hints to preserve at least 140 px for reading")
	check(NotebookText.metrics(568, 320, NotebookText.LARGE).hint == 0 and NotebookText.metrics(568, 320, NotebookText.LARGE).body >= 130, "and with large text drops the controls line to keep the page")
	for _, size in { { 568, 320 }, { 1280, 720 }, { 360, 640 } } do
		local m = NotebookText.metrics(size[1], size[2], 1)
		check(m.head + 4 + m.body + 4 + m.hint + m.foot <= m.paperH - 20, `{size[1]}x{size[2]}: heading, pages, controls line and footer fit the paper`)
	end
	check(NotebookText.SIZES.body >= 18 and NotebookText.SIZES.sources >= 14 and NotebookText.SIZES.controls >= 14 and NotebookText.MIN_TARGET >= 44, "text is readable and touch targets are 44 px")

	-- the key: N is free and N alone; D-pad up is the port's walking, so a controller has no notebook button of its own
	local count = 0
	for action, keys in SpiderInput.BINDINGS do
		for _, k in keys do
			if k == Enum.KeyCode.N then count += 1; check(action == "Notebook", "N belongs to the notebook alone") end
		end
	end
	check(count == 1 and #SpiderInput.BINDINGS.Notebook == 1, "N is bound once, to Notebook")
	local seen: { [any]: string } = {}
	for action, keys in SpiderInput.BINDINGS do
		for _, k in keys do
			check(seen[k] == nil, `{tostring(k)} is bound twice: {tostring(seen[k])} and {action}`)
			seen[k] = action
		end
	end
	check(not table.find(SpiderInput.BINDINGS.Forward, Enum.KeyCode.DPadUp) == false, "(the D-pad is still the port's walking)")
end

-- ---------------------------------------------------------------- the panel on its own
local NotebookPanel = require("../src/Client/NotebookPanel")
local GuiService = game:GetService("GuiService")
-- A key or button the open notebook hears (its own Context Action, above the game's).
local function nbKey(code: string, position: any?)
	local fn = stubs.actions["WindowsillNotebook"]
	assert(fn, "the notebook is not listening")
	fn("WindowsillNotebook", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = position or Vector3.zero })
end
local function descendantsText(root: any): { string }
	local out = {}
	for _, x in root:GetDescendants() do
		if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and x.Text then table.insert(out, x.Text) end
	end
	return out
end
local function named(root: any, name: string): any
	for _, x in root:GetDescendants() do if x.Name == name then return x end end
	return nil
end
local function buildPanel(triggers: { string }, width: number, height: number): (any, any, { string })
	local book = FieldNotebook.new()
	for _, t in triggers do book:notice(t) end
	local host = Instance.new("Folder")
	local closed: { string } = {}
	local panel = NotebookPanel.new(host, book, function(to: string?) table.insert(closed, if to then to else "nil") end)
	panel.gui.AbsoluteSize = { X = width, Y = height }
	for _, pane in { panel.page, panel.list } do
		pane.AbsoluteSize = { X = 400, Y = 200 }
		pane.AbsoluteCanvasSize = { X = 400, Y = 900 }
	end
	return panel, book, closed
end
do
	-- an empty book: Godot's words, no page, nothing to count
	local panel, book, closed = buildPanel({}, 1280, 720)
	check(not panel:isShowing() and not panel.gui.Enabled, "closed at first")
	panel:open("game", "keyboard", 1)
	check(panel:isShowing() and panel.gui.Enabled and stubs.actions["WindowsillNotebook"] ~= nil, "open: it is listening")
	check(panel.empty.Visible and panel.empty.Text == "Pages appear here as you play." and not panel.title.Visible and not panel.sources.Visible, "an empty notebook says pages appear as you play")
	check(#panel.buttons == 0, "and lists nothing")
	nbKey("N")
	check(not panel:isShowing() and #closed == 1 and closed[1] == "game" and stubs.actions["WindowsillNotebook"] == nil and GuiService.SelectedObject == nil, "N closes it, tells the game where it was opened from, and it stops listening")
	panel:close() -- (a stray close does nothing twice)
	check(#closed == 1, "closing twice tells the game once")
	panel:open("menu", "keyboard", 1)
	panel:close()
	check(closed[2] == "menu", "closing goes back to where it was opened from")

	-- three pages, side by side: only found pages are listed, newest shown, no count of pages left
	panel, book, closed = buildPanel({ "start", "jump", "catch" }, 1280, 720)
	panel:open("game", "keyboard", 1)
	check(#panel.buttons == 3 and panel.list.Visible and panel.page.Visible and not panel.backButton.Visible, "the three found pages are listed beside the page")
	check(panel.buttons[1].Text == "The bold jumping spider" and panel.buttons[2].Text == "A line before every leap" and panel.buttons[3].Text == "The bite", "in the order they were found")
	check(panel.shown == "venom" and panel.title.Text == "The bite" and panel.title.Visible, "it opens at the newest page")
	check(panel.text.Text == book:view("venom").text and panel.sources.Text == "Source: Foelix, R. F. (2011). Biology of Spiders, 3rd edition. Oxford University Press.", "with its text and source")
	check(panel.game.Visible and panel.game.Text == "In this game: In this game the fly weakens over several seconds as the venom works.", "and the line about the game")
	local everything = table.concat(descendantsText(panel.gui), "\n")
	for _, p in NotebookPages.pages do
		local found = book:isOpen(p.id)
		check((string.find(everything, p.title, 1, true) ~= nil) == found, `page {p.id} {if found then "is" else "is not"} on screen`)
		if not found then check(string.find(everything, p.text, 1, true) == nil, `page {p.id}: no spoiler of its text`) end
	end
	check(string.find(everything, "%d+ of %d+") == nil and string.find(everything, "/24", 1, true) == nil and string.find(string.lower(everything), "remaining", 1, true) == nil and string.find(string.lower(everything), "left to find", 1, true) == nil and string.find(string.lower(everything), "not yet", 1, true) == nil, "no count or hint of pages left to find (spec 4)")
	-- keys
	nbKey("Up")
	check(panel.shown == "dragline" and panel.title.Text == "A line before every leap", "Up chooses the page before")
	check(string.find(panel.sources.Text, "https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/", 1, true) ~= nil and panel.sources.Text:sub(1, 8) == "Source: ", "its source link is on the page")
	nbKey("W"); nbKey("DPadUp"); nbKey("Up")
	check(panel.shown == "bold_jumper", "the first page is as far as Up goes")
	nbKey("Down"); nbKey("S")
	check(panel.shown == "venom", "Down chooses the next")
	nbKey("Down")
	check(panel.shown == "venom", "and stops at the last")
	nbKey("Left"); nbKey("A")
	check(panel.shown == "bold_jumper", "Left and A go to the previous page")
	nbKey("ButtonR1"); nbKey("Right"); nbKey("D")
	check(panel.shown == "venom", "R1, Right and D go to the next")
	nbKey("ButtonL1")
	check(panel.shown == "dragline", "L1 the previous")
	nbKey("Return")
	check(panel.shown == "dragline" and panel.list.Visible and panel.page.Visible, "Enter changes nothing with two panes")
	-- a mouse click and a tap
	panel.buttons[1].Activated:Fire()
	check(panel.shown == "bold_jumper" and panel.title.Text == "The bold jumping spider", "a click chooses a page")
	check(panel.buttons[1].BackgroundColor3 ~= panel.buttons[2].BackgroundColor3, "and marks it in the list")
	panel.closeButton.Activated:Fire()
	check(not panel:isShowing() and closed[1] == "game", "the Close button closes")
	-- Q closes with two panes
	panel:open("game", "keyboard", 1)
	nbKey("Q")
	check(not panel:isShowing(), "Q closes with two panes")
	panel:open("game", "keyboard", 1)
	nbKey("ButtonB")
	check(not panel:isShowing(), "so does B")
	panel:open("game", "keyboard", 1)
	nbKey("Backspace")
	check(not panel:isShowing(), "and Backspace")

	-- scrolling the page (the keyboard, the wheel is the engine's, the right stick)
	panel:open("game", "keyboard", 1)
	panel.page.CanvasPosition = Vector2.zero
	nbKey("PageDown")
	check(math.abs(panel.page.CanvasPosition.Y - 160) < 1e-9, "PageDown scrolls four fifths of the page")
	nbKey("PageDown"); nbKey("PageDown"); nbKey("PageDown"); nbKey("PageDown")
	check(math.abs(panel.page.CanvasPosition.Y - 700) < 1e-9, "and stops at the end of the page")
	nbKey("PageUp")
	check(math.abs(panel.page.CanvasPosition.Y - 540) < 1e-9, "PageUp goes back")
	nbKey("Up")
	check(panel.page.CanvasPosition.Y == 0, "a new page starts at its top")
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, -1, 0) })
	for _ = 1, 5 do panel:update(0.1) end
	check(panel.page.CanvasPosition.Y > 200 and panel.page.CanvasPosition.Y < 300, `the right stick pulled down scrolls the page ({panel.page.CanvasPosition.Y})`)
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, 0.1, 0) })
	local at = panel.page.CanvasPosition.Y
	panel:update(0.5)
	check(panel.page.CanvasPosition.Y == at, "a stick back in its dead zone stops it")
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, 1, 0) })
	panel:update(10) -- (a long frame is capped at a tenth of a second)
	check(panel.page.CanvasPosition.Y < at and panel.page.CanvasPosition.Y >= at - 53, "up scrolls back, and one long frame does not fling the page")
	-- the left stick chooses pages like the D-pad, one step a push
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick1, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, 1, 0) })
	check(panel.shown == "dragline" or panel.shown == "bold_jumper", "the left stick pushed up chooses the page before")
	local stickAt = panel.shown
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick1, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, 0.9, 0) })
	check(panel.shown == stickAt, "held there it does not run on")
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick1, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, 0, 0) })
	stubs.actions["WindowsillNotebook"]("WindowsillNotebook", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick1, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0, -1, 0) })
	check(panel.shown ~= stickAt, "released and pushed down it chooses the next")
	panel:close()

	-- a page opening while the book is open: the list grows, the page on show stays
	panel, book, closed = buildPanel({ "start", "jump" }, 1280, 720)
	panel:open("game", "keyboard", 1)
	nbKey("Up")
	book:notice("rest")
	panel:refresh()
	check(#panel.buttons == 3 and panel.shown == "bold_jumper" and panel.buttons[3].Text == "A silk retreat", "a page found while open joins the list at the end and the page on show stays")
	panel:close()

	-- one pane at a time on a phone held sideways: the page, Pages for the list, Q back
	panel, book, closed = buildPanel({ "start", "jump", "catch" }, 568, 320)
	panel:open("game", "touch", 1)
	check(panel:stacked() and panel.page.Visible and not panel.list.Visible and panel.backButton.Visible and panel.shown == "venom", "568 x 320: the newest page fills the panel, with a Pages button")
	check(panel.closeButton.Visible ~= false and NotebookText.metrics(568, 320, 1).foot + panel.closeButton.Size.Y.Offset >= 44, "a Close button a thumb can hit")
	panel.backButton.Activated:Fire()
	check(panel.list.Visible and not panel.page.Visible and not panel.backButton.Visible, "Pages shows the list")
	check(panel.buttons[1].Size.Y.Offset >= 44, "its entries are touch targets (44 px)")
	panel.buttons[2].Activated:Fire()
	check(panel.page.Visible and not panel.list.Visible and panel.shown == "dragline" and panel.title.Text == "A line before every leap", "a tap on a page opens it")
	panel:close()
	panel:open("game", "keyboard", 1)
	check(panel.page.Visible and panel.shown == "venom", "opened again at the newest page")
	nbKey("Q")
	check(panel:isShowing() and panel.list.Visible and not panel.page.Visible, "Q goes back to the list")
	nbKey("Up")
	check(panel.shown == "dragline" and panel.list.Visible, "Up chooses in the list")
	nbKey("Return")
	check(panel.page.Visible and not panel.list.Visible, "Enter opens it")
	nbKey("Right")
	check(panel.shown == "venom", "Right goes to the next page")
	panel.page.CanvasPosition = Vector2.zero
	nbKey("Down")
	check(math.abs(panel.page.CanvasPosition.Y - 120) < 1e-9 and panel.shown == "venom", "Down scrolls the page when it has the whole panel")
	nbKey("Up")
	check(panel.page.CanvasPosition.Y == 0, "Up scrolls back")
	nbKey("Q"); nbKey("Q")
	check(not panel:isShowing(), "Q twice closes")
	-- a portrait phone
	panel, book, closed = buildPanel({ "start" }, 360, 640)
	panel:open("game", "touch", 1)
	check(panel:stacked() and panel.page.Visible and panel.controls.Text == NotebookText.controls("touch", true), "360 x 640: one pane, and touch's own words")
	panel:close()

	-- large text
	panel, book, closed = buildPanel({ "start", "jump" }, 900, 600)
	panel:open("game", "keyboard", 1.5)
	check(panel:stacked() and panel.title.TextSize == 36 and panel.text.TextSize == 29 and panel.heading.TextSize == 39, "large text (1.5x) is 36 pt titles and 29 px text, in one pane")
	check(panel.buttons[1].Size.Y.Offset == 66 and panel.closeButton.TextSize == 27, "with bigger targets")
	panel:close()
	panel:open("game", "keyboard", 7)
	check(panel.scale == 1.5, "the scale is capped")
	panel:close()
	panel:open("game", "keyboard", 0.2)
	check(panel.scale == 1, "and never smaller")
	panel:close()
	panel, book, closed = buildPanel({ "start", "jump" }, 1280, 720)
	panel:open("game", "keyboard", 1.5)
	check(not panel:stacked() and panel.title.TextSize == 36, "a wide screen keeps two panes at large text")
	panel:close()

	-- a controller: the controls change with the device, PlayStation names, the selection shows
	ControlText.setPadStyle("playstation")
	panel, book, closed = buildPanel({ "start", "jump" }, 1280, 720)
	panel:open("game", "gamepad", 1)
	check(string.find(panel.controls.Text, "Cross: open", 1, true) ~= nil and string.find(panel.controls.Text, "Circle: close", 1, true) ~= nil, "a PlayStation controller's own words: " .. panel.controls.Text)
	check(string.find(panel.game.Text, "Square lets it down", 1, true) ~= nil, "and on the page: " .. panel.game.Text)
	check(GuiService.SelectedObject == nil and not panel.buttons[2].Selectable, "the chosen page shows as selected for the controller")
	nbKey("DPadUp")
	check(GuiService.SelectedObject == nil and panel.shown == "bold_jumper", "and the selection moves with the D-pad")
	panel:setDevice("keyboard")
	check(string.find(panel.controls.Text, "N or Q: close", 1, true) ~= nil, "picking up the keyboard changes the words at once")
	panel:close()
	check(GuiService.SelectedObject == nil, "closing clears the selection")
	ControlText.setPadStyle("xbox")
end

-- ---------------------------------------------------------------- the client: the real loop wires the watcher, the panel and the menus
-- The client scripts themselves under stub services (as tests/client_smoke.luau): keys go through the same Context Action callbacks
-- the engine calls, frames through the bound render step. Wiring and runtime errors, not rendering or an input device.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
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

	-- the Notebook button beside Menu: for touch, a mouse and a controller's pointer; clear of Menu and of the touch controls
	local noteButton, menuButton = find("SpiderPrompts", "NotebookButton"), find("SpiderPrompts", "LifeMenu")
	check(noteButton ~= nil and menuButton ~= nil and noteButton.Text == "Notebook", "there is a Notebook button beside the Menu button")
	-- (where the two buttons go at every screen size, and that they are touch targets clear of everything else, is checked in tests/run.luau
	-- with HudLayout.topLayout; here, that the real buttons sit where it says for this screen)
	local t = HudLayout.topLayout(1280, 720)
	local function rect(b: any): any
		return { x0 = b.Position.X.Offset, y0 = b.Position.Y.Offset, x1 = b.Position.X.Offset + b.Size.X.Offset, y1 = b.Position.Y.Offset + b.Size.Y.Offset }
	end
	local n, m = rect(noteButton), rect(menuButton)
	check(n.x0 == t.notebook.x0 and n.y0 == t.notebook.y0 and n.x1 == t.notebook.x1 and n.y1 == t.notebook.y1, "the Notebook button is where the layout puts it")
	check(m.x0 == t.menu.x0 and m.y0 == t.menu.y0 and m.x1 == t.menu.x1 and m.y1 == t.menu.y1 and not HudLayout.overlaps(n, m), "and Menu, clear of it")
	check(n.y1 - n.y0 >= 48 and n.x1 - n.x0 >= 80 and m.y1 - m.y0 >= 48 and m.x1 - m.x0 >= 48, "both big enough to tap")
	noteButton.Activated:Fire()
	check(panel:isShowing(), "the button opens the notebook")
	nbKey("N")
	check(not panel:isShowing(), "N closes it")
	menuButton.Activated:Fire()
	check(d.menu:isShowing(), "(the Menu button still opens the life menu)")
	key("Menu", true); key("Menu", false); frames(1)
	check(d.menu:isShowing() == false or d.session.started == true, "M while the menu is up closes it, as before")
	d.menu:hide(); frames(2)
	tap("Notebook")
	key("Menu", true); key("Menu", false)
	check(not panel:isShowing() and gui:FindFirstChild("SpiderPrompts").Enabled and not d.menu:isShowing(), "M with the notebook open closes the notebook")

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
	d.needs:grantEnergy(0.9, "test_meal")
 d.life.mealFood=.9 -- three consumed meals: Godot's moult, no longer the game's (ROBLOX-88)
	frames(3)
	check(not d.life.growth.ready and d.life.growth.gameRules == true, "three houseflies do not ready a moult in the game: it asks for five")
	local line = find("SpiderPrompts", "DayLine")
	check(line ~= nil and string.find(line.Text, "Next moult: 3 of 5 meals", 1, true) ~= nil, `the screen counts the moult out of five ({if line then line.Text else "no line"})`)
	d.life.mealFood=.6 -- two more: five consumed meals in all, independent of reserve capacity
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

-- Independent frozen-engine export and the Windows integration regressions.
do
 local b=FieldNotebook.new()
 for i,row in require("./notebook_godot") do
  local a=row.action
  if a.kind=="notice" then b:notice(a.value) elseif a.kind=="jump" then b:noticeJump(a.value) else b:addEyeTime(a.value) end
  check(same(b.opened,row.opened),"Godot transition order "..i)
  check(math.abs(b.eyeSeconds-row.eye_seconds)<1e-8,"Godot transition eye time "..i)
 end
 local n=#b.opened;local t=b.eyeSeconds
 b:addEyeTime(math.huge);b:addEyeTime(0/0);b:noticeJump(math.huge)
 check(b.eyeSeconds==t and #b.opened==n,"nonfinite observations rejected")
 local panel,book=buildPanel({"start"},360,640)
 panel:open("game","gamepad",1.5);nbKey("ButtonY")
 check(panel.shown=="_checklist" and panel.page.Visible,"controller opens optional checklist")
 check(string.find(panel.text.Text,"[x] Meet",1,true)~=nil and string.find(panel.text.Text,"[ ] Catch",1,true)~=nil,"observed and unobserved invitations differ")
 check(book:view("venom")==nil,"checklist doesn't reveal biology page or grant discovery")
 book:notice("dance");panel:refresh()
 check(string.find(panel.text.Text,"[x] Change",1,true)~=nil,"dance marks checklist")
 check(panel.tryButton.Size.X.Offset*3+16<=NotebookText.metrics(360,640,1.5).paperW-28,"three footer buttons fit portrait large text")
 GuiService.MenuIsOpen=true
 local result=stubs.actions.WindowsillNotebook("WindowsillNotebook",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.N})
 check(panel:isShowing() and result==Enum.ContextActionResult.Pass,"Roblox menu keeps input ownership")
 GuiService.MenuIsOpen=false;panel:close()
end
-- ---------------------------------------------------------------- ROBLOX-89: the lines the game adds to a page ("things you saw")
do
	local book = FieldNotebook.new()
	check(not book:addEntry("no_such_page", 3, "Day 3: x") and #book:entriesFor("no_such_page") == 0, "a line for a page the book does not have is nothing")
	check(not book:addEntry("eggs_and_wind", 3, "   ") and not book:addEntry("eggs_and_wind", -1, "Day -1: x") and not book:addEntry("eggs_and_wind", 0 / 0, "Day nan: x"), "an empty line, a day before the first and a day that is not a number are nothing")
	check(book:addEntry("eggs_and_wind", 3, "Day 3: A male came to the sill."), "a line for a page the book has is kept, found or not")
	check(#book:entriesFor("eggs_and_wind") == 0, "but shows nothing until the page is found")
	check(not book:isOpen("eggs_and_wind"), "(and does not find it)")
	book:notice("hatched")
	check(book:isOpen("eggs_and_wind") and #book:entriesFor("eggs_and_wind") == 1 and book:entriesFor("eggs_and_wind")[1].day == 3 and book:entriesFor("eggs_and_wind")[1].text == "Day 3: A male came to the sill.", "once the page is found the line is there")
	check(not book:addEntry("eggs_and_wind", 3, "Day 3: A male came to the sill."), "the same line twice is once")
	check(book:addEntry("eggs_and_wind", 3, "Day 3: A second visitor."), "another line the same day is another")
	for day = 4, 12 do book:addEntry("eggs_and_wind", day, `Day {day}: seen.`) end
	local list = book:entriesFor("eggs_and_wind")
	check(#list == FieldNotebook.MAX_ENTRIES and FieldNotebook.MAX_ENTRIES == 6 and list[1].day == 7 and list[#list].day == 12, "at most six to a page, the oldest dropped")
	list[1].text = "changed"
	check(book:entriesFor("eggs_and_wind")[1].text ~= "changed", "what is handed out is a copy")
	local rec = book:toRecord()
	local again = FieldNotebook.new()
	again:load(rec)
	check(#again:entriesFor("eggs_and_wind") == 0 and (rec :: any).entries == nil and (rec :: any).entry == nil, "the lines are the session's: the record does not carry them, and a loaded book has none")
	check(NotebookText.seenText({}) == nil, "no lines, no words")
	check(NotebookText.seenText({ { day = 3, text = "Day 3: A." }, { day = 4, text = "Day 4: B." } }) == "Things you saw:\nDay 3: A.\nDay 4: B.", "the words: a heading and the lines")
	-- on the page
	local panel, pbook = buildPanel({ "hatched" }, 1280, 720)
	panel:open("game", "keyboard", 1)
	check(panel.shown == "eggs_and_wind" and not string.find(panel.game.Text, "Things you saw", 1, true), "a page with no lines shows only the game's note")
	panel:close()
	pbook:addEntry("eggs_and_wind", 5, "Day 5: A male came to the sill. The two spiders stayed together a while, and then he went.")
	panel:open("game", "keyboard", 1)
	check(panel.game.Visible and string.find(panel.game.Text, "In this game:", 1, true) == 1 and string.find(panel.game.Text, "Things you saw:\nDay 5: A male came to the sill.", 1, true) ~= nil, "the page shows them under the note about the game")
	check(string.find(panel.game.Text, "In this game:", 1, true) < string.find(panel.game.Text, "Things you saw", 1, true), "after it")
	panel:close()
	-- the page's own words are untouched (the reference file pins them)
	local page
	for _, pg in NotebookPages.pages do if pg.id == "eggs_and_wind" then page = pg end end
	check(page ~= nil and not string.find(page.game, "Things you saw", 1, true), "the data holds no lines of its own")
end
print(`NOTEBOOK passed={passed} failed={failed}`)
if failed > 0 then error("notebook failed") end
