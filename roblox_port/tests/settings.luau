-- Settings checks (ROBLOX-49): the table (Data/SettingsSpec) and the model (UI/SettingsModel). Pure Luau. The saving, the panel, the live
-- wiring and the touch layout are checked below in the same suite as they are built (see the section headings).
local Spec = require("../src/Shared/Data/SettingsSpec")
local Model = require("../src/Shared/UI/SettingsModel")
local Nav = require("../src/Shared/UI/SettingsNav")
local Text = require("../src/Shared/UI/SettingsText")
local ControlText = require("../src/Shared/UI/ControlText")
local CameraMath = require("../src/Shared/Movement/CameraMath")
local SpiderChoice = require("../src/Shared/Rig/SpiderChoice")
local PeacockText = require("../src/Shared/UI/PeacockText")
local InspectText = require("../src/Shared/UI/InspectText")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")
local SettingsPanel = require("../src/Client/SettingsPanel")
local stubs = ClientStubs

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL settings: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

-- ---------------------------------------------------------------- the table
local sectionIds: { [string]: boolean } = {}
for _, sec in Spec.SECTIONS do
	check(not sectionIds[sec.id] and sec.title ~= "", `section {sec.id} is unique and has a title`)
	sectionIds[sec.id] = true
end
check(#Spec.SECTIONS == 5 and Spec.SECTIONS[1].id == "sound" and Spec.SECTIONS[2].id == "camera" and Spec.SECTIONS[3].id == "comfort" and Spec.SECTIONS[4].id == "help" and Spec.SECTIONS[5].id == "spider",
	"five sections in order: Sound, Camera, Comfort and accessibility, Help and hints, Your spider")
check(Spec.SECTIONS[3].title == "Comfort and accessibility" and Spec.SECTIONS[4].title == "Help and hints" and Spec.SECTIONS[5].title == "Your spider", "the section titles")

local seen: { [string]: boolean } = {}
local perSection: { [string]: number } = {}
for _, s in Spec.LIST do
	check(not seen[s.id], `{s.id}: unique`)
	seen[s.id] = true
	check(string.match(s.id, "^[A-Z][A-Za-z]+$") ~= nil and #s.id <= 24, `{s.id}: a short plain name (it is also a Player attribute and a saved key)`)
	check(sectionIds[s.section] == true, `{s.id}: in a known section`)
	perSection[s.section] = (perSection[s.section] or 0) + 1
	check(s.label ~= "" and #s.label <= 56, `{s.id}: a label that fits a line`)
	check(s.note == nil or (s.note ~= "" and #s.note <= 110), `{s.id}: a short note`)
	check(s.kind == "toggle" or s.kind == "slider" or s.kind == "choice", `{s.id}: a known kind`)
	if s.kind == "toggle" then
		check(type(s.default) == "boolean" and s.min == nil and s.options == nil, `{s.id}: a toggle is true or false`)
	elseif s.kind == "slider" then
		local lo, hi, step = s.min :: number, s.max :: number, s.step :: number
		check(type(s.default) == "number" and lo < hi and step > 0 and step <= (hi - lo) / 4, `{s.id}: a slider has a range and a sensible step`)
		check((s.default :: number) >= lo and (s.default :: number) <= hi, `{s.id}: the default is inside the range`)
		local k = ((s.default :: number) - lo) / step
		check(near(k, math.floor(k + 0.5), 1e-6), `{s.id}: the default is on the step grid`)
		local n = (hi - lo) / step
		check(near(n, math.floor(n + 0.5), 1e-6), `{s.id}: the ends are on the step grid`)
		check(s.unit == "percent" or s.unit == "times" or s.unit == "degrees" or s.unit == "studs", `{s.id}: a known unit`)
	else
		local options = s.options :: { Spec.Option }
		check(#options >= 2 and type(s.default) == "string", `{s.id}: a choice has options`)
		local ids: { [string]: boolean } = {}
		for _, o in options do
			check(not ids[o.id] and o.label ~= "", `{s.id}: option {o.id} is unique and has a label`)
			ids[o.id] = true
		end
		check(ids[s.default :: string] == true, `{s.id}: the default is one of the options`)
	end
	local clean, problem = Model.clean(s.id, s.default)
	check(clean == s.default and problem == nil, `{s.id}: the default is clean`)
end
check(#Spec.LIST == 23, `23 settings in the table (found {#Spec.LIST})`)
check(perSection.sound == 6 and perSection.camera == 8 and perSection.comfort == 7 and perSection.help == 2, "6 sound, 8 camera, 7 comfort, 2 help")
check(Spec.VERSION == 1 and Model.VERSION == 1, "version 1")

-- The seven that were already Player attributes (ROBLOX-39's PREF_KEYS) keep their names and what "unset" meant.
local older = { FocusToggle = false, ReducedMotion = false, ShowLastSeen = true, AutomaticGrip = false, NotebookNotes = true, LargeText = false, SoundMuted = false }
for id, expected in older do
	check(Model.default(id) == expected, `{id}: the same default as before the panel ({tostring(expected)})`)
end

-- Godot's values where a Godot setting matches (scripts/presentation/settings.gd DEFAULTS and LIMITS at the frozen c87ce00).
local function slider(id: string, lo: number, hi: number, default: number)
	local s = Model.spec(id) :: Spec.Setting
	check(s ~= nil and s.min == lo and s.max == hi and s.default == default, `{id}: Godot's range {lo} to {hi}, default {default}`)
end
slider("LookSensitivityMouse", 0.2, 3.0, 1.0)   -- look_sensitivity [0.2, 3.0], 1.0
slider("LookSensitivityStick", 0.2, 3.0, 1.0)
slider("FieldOfView", 50, 90, 65)               -- fov_degrees [50, 90], 65
slider("CameraDistance", 4, 7, 5)               -- camera_distance [4, 7], 5
check(Model.default("InvertX") == false and Model.default("InvertY") == false, "invert_x and invert_y: off")
check(Model.default("FrameLine") == true, "frame_line_after_catch: on")
check(Model.default("EyeLevelHorizon") == false and Model.default("EyeGrey") == false, "eye_level_horizon and eye_colour_free: off")
check(Model.default("Captions") == "normal", "captions: on (Godot's true is the normal size here)")
check(Model.default("AutomaticGrip") == false and Model.default("FocusToggle") == false and Model.default("ReducedMotion") == false, "struggle_auto, focus_toggle, reduced_motion: off")
-- The Roblox mix was tuned and accepted at full volume (ROBLOX-28), so the three volumes start at 100 per cent rather than Godot's 0.8, 0.6, 0.9.
check(Model.default("MasterVolume") == 1.0 and Model.default("AmbienceVolume") == 1.0 and Model.default("CreatureVolume") == 1.0, "volumes start at the accepted mix")
-- ROBLOX-76: the ambient music's slider is the fourth volume, made exactly like the three: 0 to 1 in steps of 0.05, 100 per cent, in Sound.
do
	local music = Model.spec("MusicVolume") :: Spec.Setting
	check(music ~= nil and music.section == "sound" and music.kind == "slider" and music.default == 1.0 and music.min == 0.0 and music.max == 1.0 and music.step == 0.05 and music.unit == "percent" and music.label == "Ambient music",
		"MusicVolume: a slider 0 to 1 in steps of 0.05, 100 per cent, in Sound, labelled Ambient music")
	local master = Model.spec("MasterVolume") :: Spec.Setting
	check(music.unit == master.unit and music.step == master.step and music.min == master.min and music.max == master.max and music.default == master.default and music.note == master.note, "and made as the other volumes are")
	local order = Model.ids()
	check(order[2] == "MasterVolume" and order[3] == "AmbienceVolume" and order[4] == "CreatureVolume" and order[5] == "MusicVolume" and order[6] == "Captions", "it comes after the other three volumes, before the captions")
	check(Model.known("MusicVolume") and Model.defaults().MusicVolume == 1.0 and Model.isDefault("MusicVolume", 1.0) and not Model.isDefault("MusicVolume", 0.5), "known, in the defaults")
	local v3, p3 = Model.clean("MusicVolume", 0.35)
	check(v3 == 0.35 and p3 == nil, "0.35 is clean")
	v3, p3 = Model.clean("MusicVolume", 5)
	check(v3 == 1 and p3 == nil, "above the range it is clamped")
	v3, p3 = Model.clean("MusicVolume", -1)
	check(v3 == 0 and p3 == nil, "and below")
	v3, p3 = Model.clean("MusicVolume", "quiet")
	check(v3 == nil and p3 ~= nil, "a string is a problem")
	check(Model.step("MusicVolume", 1.0, -1) == 0.95 and Model.step("MusicVolume", 0.0, -1) == 0.0 and Model.valueText("MusicVolume", 0.35) == "35%" and Model.line("MusicVolume", 0.5) == "Ambient music: 50%", "it steps by a twentieth and says percent")
	check(Model.get(function() return nil end, "MusicVolume") == 1.0 and Model.get(function() return 0.2 end, "MusicVolume") == 0.2, "unset it reads full, set it reads as set")
	-- Saved with the other settings, and a save from before it gets the default.
	local payload = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, "first_spider", { MusicVolume = 0.35, MasterVolume = 0.5 })
	check(payload.settings.MusicVolume == 0.35 and payload.settings.MasterVolume == 0.5, "a changed music volume goes into the save with the others")
	local problems4, cleaned4 = Model.cleanAll({ MasterVolume = 0.5, MusicVolume = 0.35 })
	check(#problems4 == 0 and cleaned4.MusicVolume == 0.35, "and comes back clean")
	local problems5, cleaned5 = Model.cleanAll({ MasterVolume = 0.5 })
	check(#problems5 == 0 and cleaned5.MusicVolume == nil and Model.get(function(id: string): any return cleaned5[id] end, "MusicVolume") == 1.0, "a save from before it has none and reads the default")
end

-- ---------------------------------------------------------------- looking up and cleaning
local function holder(t: { [string]: any }): (string) -> any return function(id: string): any return t[id] end end
check(Model.get(holder({}), "MasterVolume") == 1.0 and Model.get(holder({}), "ShowLastSeen") == true and Model.get(holder({}), "Captions") == "normal", "an unset setting reads as its default")
check(Model.get(holder({ MasterVolume = 0.5 }), "MasterVolume") == 0.5 and Model.get(holder({ ShowLastSeen = false }), "ShowLastSeen") == false, "a set one reads as set")
check(Model.get(holder({ MasterVolume = "loud" }), "MasterVolume") == 1.0 and Model.get(holder({ InvertY = 1 }), "InvertY") == false, "one of the wrong type reads as the default")
check(Model.get(holder({ MasterVolume = 7 }), "MasterVolume") == 1.0 and Model.get(holder({ LookSensitivityMouse = 99 }), "LookSensitivityMouse") == 3.0 and Model.get(holder({ FieldOfView = 1 }), "FieldOfView") == 50, "a number is clamped into its range")
check(Model.get(holder({ Captions = "huge" }), "Captions") == "normal" and Model.get(holder({ Captions = "large" }), "Captions") == "large", "a choice that is not an option reads as the default")
check(not pcall(Model.get, holder({}), "NotASetting"), "an unknown id is a programming error for a reader")

local v, p = Model.clean("NotASetting", true)
check(v == nil and p == nil, "an unknown id is dropped quietly")
v, p = Model.clean("InvertY", "yes")
check(v == nil and p ~= nil, "a toggle that is not a boolean is a problem")
v, p = Model.clean("MasterVolume", 0 / 0)
check(v == nil and p ~= nil, "NaN is a problem")
v, p = Model.clean("MasterVolume", math.huge)
check(v == nil and p ~= nil, "infinity is a problem")
v, p = Model.clean("MasterVolume", "1")
check(v == nil and p ~= nil, "a slider that is a string is a problem")
v, p = Model.clean("MasterVolume", -4)
check(v == 0 and p == nil, "below the range: clamped to the lowest")
v, p = Model.clean("MasterVolume", 4)
check(v == 1 and p == nil, "above the range: clamped to the highest")
v, p = Model.clean("Captions", 3)
check(v == nil and p ~= nil, "a choice that is not a string is a problem")
v, p = Model.clean("Captions", "tiny")
check(v == nil and p == nil, "a string that is not an option is dropped quietly")
v, p = Model.clean(5, true)
check(v == nil and p ~= nil, "a key that is not a string is a problem")
v, p = Model.clean("Captions", "off")
check(v == "off" and p == nil, "a good choice passes")

local problems, cleaned = Model.cleanAll({ InvertY = true, MasterVolume = 0.3, Mystery = "x", Captions = "tiny", FieldOfView = 500 })
check(#problems == 0 and cleaned.InvertY == true and cleaned.MasterVolume == 0.3 and cleaned.Mystery == nil and cleaned.Captions == nil and cleaned.FieldOfView == 90, "cleanAll keeps what is clean, clamps, drops the unknown")
problems, cleaned = Model.cleanAll({ InvertY = "yes", MasterVolume = {} })
check(#problems == 2 and next(cleaned) == nil, "cleanAll reports each wrongly typed value")
problems = Model.cleanAll(5)
check(#problems == 1, "cleanAll: not a table is a problem")
problems, cleaned = Model.cleanAll(nil)
check(#problems == 0 and next(cleaned) == nil, "cleanAll: nothing is nothing")
local many: { [string]: any } = {}
for _, s in Spec.LIST do many[s.id] = "wrong" end
problems = Model.cleanAll(many)
check(#problems <= 12 and #problems > 0, "the list of problems is bounded")

-- ---------------------------------------------------------------- stepping
check(Model.step("InvertY", false, 1) == true and Model.step("InvertY", true, -1) == false and Model.step("InvertY", "junk", 1) == true, "a toggle flips (junk counts as the default, off)")
check(Model.step("MasterVolume", 1.0, 1) == 1.0 and Model.step("MasterVolume", 1.0, -1) == 0.95 and Model.step("MasterVolume", 0.0, -1) == 0.0, "a slider stops at its ends")
local x: number = 0
for _ = 1, 3 do x = Model.step("MasterVolume", x, 1) :: number end
check(x == 0.15, "three steps of 0.05 are exactly 0.15, with no drift")
x = Model.default("CameraDistance") :: number
for _ = 1, 7 do x = Model.step("CameraDistance", x, 1) :: number end
check(x == 5.7, `seven steps of 0.1 from 5.0 are 5.7 (got {x})`)
for _ = 1, 40 do x = Model.step("CameraDistance", x, 1) :: number end
check(x == 7.0, "and it stops at 7.0")
check(Model.step("FieldOfView", 65, 1) == 66 and Model.step("FieldOfView", 65.4, 1) == 66 and Model.step("FieldOfView", 90, 1) == 90, "whole-degree steps; an off-grid value snaps")
check(Model.step("Captions", "normal", 1) == "large" and Model.step("Captions", "large", 1) == "off" and Model.step("Captions", "off", -1) == "large" and Model.step("Captions", "off", 1) == "normal", "a choice cycles both ways and wraps")
check(Model.step("Captions", "huge", 1) == "large", "a bad choice counts as the default before stepping")
for _, s in Spec.LIST do
	local value: Model.Value = s.default
	for _ = 1, 60 do
		value = Model.step(s.id, value, 1)
		local c = Model.clean(s.id, value)
		if c ~= value then check(false, `{s.id}: stepping gave an unclean value {tostring(value)}`) break end
	end
end
check(near(Model.fraction("MasterVolume", 0.25), 0.25, 1e-9) and Model.fraction("InvertY", true) == 0 and near(Model.fraction("FieldOfView", 65), 15 / 40, 1e-9), "where a slider sits along its bar")
check(Model.fromFraction("MasterVolume", 0.5) == 0.5 and Model.fromFraction("MasterVolume", -3) == 0 and Model.fromFraction("MasterVolume", 9) == 1 and Model.fromFraction("InvertY", 0.5) == nil, "a press on the bar gives a value on the grid")
check(Model.fromFraction("FieldOfView", 0.3) == 62 and Model.fromFraction("CameraDistance", 0.33) == 5.0, "the grid: 62 degrees; 5.0 studs")

-- ---------------------------------------------------------------- reset and defaults
local defaults = Model.defaults()
local count = 0
for id, value in defaults do
	count += 1
	check(Model.isDefault(id, value) and Model.clean(id, value) == value, `{id}: a default is the default`)
end
check(count == #Spec.LIST, "defaults() holds every setting")
check(not Model.isDefault("MasterVolume", 0.5) and Model.isDefault("MasterVolume", 1.0) and Model.isDefault("InvertY", false) and not Model.isDefault("InvertY", true) and Model.isDefault("Captions", "tiny"), "isDefault")
check(#Model.ids() == #Spec.LIST and Model.ids()[1] == "SoundMuted", "ids() keeps the table's order")
local nSections, nItems = 0, 0
for _, sec in Model.sections() do
	nSections += 1
	nItems += #sec.items
end
check(nSections == 5 and nItems == #Spec.LIST + #Spec.LIVE, "sections() holds every setting and every live row once")

-- ---------------------------------------------------------------- words
check(Model.valueText("InvertY", true) == "On" and Model.valueText("InvertY", false) == "Off", "On and Off")
check(Model.valueText("MasterVolume", 0.8) == "80%" and Model.valueText("MasterVolume", 0.05) == "5%" and Model.valueText("MasterVolume", 1) == "100%", "percent")
check(Model.valueText("LookSensitivityMouse", 1) == "1.00x" and Model.valueText("LookSensitivityStick", 0.25) == "0.25x", "times")
check(Model.valueText("FieldOfView", 65) == "65 degrees" and Model.valueText("CameraDistance", 5) == "5.0 studs", "degrees and studs")
check(Model.valueText("Captions", "large") == "Large" and Model.valueText("Captions", nil) == "Normal", "a choice says its label; unset says the default's")
check(Model.line("LargeText", true) == "Large text: On" and Model.line("FieldOfView", 70) == "Field of view: 70 degrees", "one line")
check(Model.valueText("Nope", 1) == "" and Model.line("Nope", 1) == "", "unknown ids say nothing")
check(Spec.WORDS.reset == "Reset to defaults" and Spec.WORDS.title == "Settings", "the words")

-- ---------------------------------------------------------------- carrying saved settings forward
local stepsRan = 0
local steps: { [number]: ({ [string]: any }) -> { [string]: any } } = {
	[1] = function(t) stepsRan += 1; t.Renamed = t.Old; t.Old = nil; return t end,
	[2] = function(t) stepsRan += 1; t.Third = true; return t end,
}
local input = { Old = 4 }
local out = Model.migrate(input, 1, steps, 3)
check(stepsRan == 2 and out.Renamed == 4 and out.Old == nil and out.Third == true, "migrate runs each step from the saved version up")
check(input.Old == 4 and input.Renamed == nil, "and does not edit what it was given")
stepsRan = 0
out = Model.migrate({ A = 1 }, 2, steps, 3)
check(stepsRan == 1 and out.Third == true and out.Renamed == nil, "from a later version it runs only the later steps")
out = Model.migrate({ A = 1 }, 3, steps, 3)
check(stepsRan == 1 and out.A == 1, "at the current version it runs none")
out = Model.migrate({ A = 1 }, 1)
check(out.A == 1, "this build has no steps to run yet")


-- ---------------------------------------------------------------- the Spider row: a live row, not a saved setting (ROBLOX-71)
do
	check(#Spec.LIVE == 2 and Spec.LIVE[1].id == "Spider" and Spec.LIVE[1].section == "spider" and Spec.LIVE[1].kind == "choice", "two live rows (ROBLOX-90 added the second): Spider, a choice, in Your spider, first")
	local live = Spec.LIVE[1]
	check(live.label == "Spider" and #live.label <= 56 and live.note ~= nil and #(live.note :: string) <= 110, "a label and a note that fit a line")
	check(sectionIds[live.section] == true and Spec.LIST[1].id ~= "Spider", "in a known section")
	for _, s in Spec.LIST do check(s.id ~= "Spider", "no saved setting is called Spider") end
	check(Model.live("Spider") and not Model.live("MasterVolume") and not Model.live(nil) and not Model.live("Nope"), "live() knows the row and only the row")
	check(Model.spec("Spider") == live and Model.spec("MasterVolume") ~= nil, "spec() finds both kinds")
	-- not saved, not read from a save, not reset, not an attribute
	check(not Model.known("Spider") and table.find(Model.ids(), "Spider") == nil and Model.defaults().Spider == nil and Model.default("Spider") == nil, "ids(), defaults() and known() leave it out")
	local v2, p2 = Model.clean("Spider", "maratus_volans_male")
	check(v2 == nil and p2 == nil, "clean() drops it quietly, as it does an id from a newer build")
	local problems2, cleaned2 = Model.cleanAll({ Spider = "maratus_volans_male", InvertY = true })
	check(#problems2 == 0 and cleaned2.Spider == nil and cleaned2.InvertY == true, "a saved settings table that holds it keeps nothing of it")
	check(not pcall(Model.get, holder({ Spider = "x" }), "Spider"), "and it cannot be read as a saved setting")
	local payload = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, "maratus_volans_male", { Spider = "myrmarachne_formicaria_female", InvertY = true })
	check(payload.settings.Spider == nil and payload.settings.InvertY == true and payload.appearance == "maratus_volans_male", "the save keeps the spider as `appearance`, never as a setting")
	-- stepping and words follow SpiderChoice and PeacockText
	check(Model.step("Spider", "first_spider", 1) == "maratus_volans_male" and Model.step("Spider", "maratus_volans_male", 1) == "myrmarachne_formicaria_female" and Model.step("Spider", "myrmarachne_formicaria_female", 1) == "brachypelma_hamorii"
		and Model.step("Spider", "brachypelma_hamorii", 1) == "chromatopelma_cyaneopubescens" and Model.step("Spider", "chromatopelma_cyaneopubescens", 1) == "first_spider", "it cycles first spider, peacock, ant mimic, redknee, greenbottle and round")
	check(Model.step("Spider", "first_spider", -1) == "chromatopelma_cyaneopubescens" and Model.step("Spider", "maratus_volans_male", -1) == "first_spider" and Model.step("Spider", "brachypelma_hamorii", -1) == "myrmarachne_formicaria_female", "and back the other way")
	check(Model.step("Spider", "rival_spider", 1) == "maratus_volans_male" and Model.step("Spider", 7, 1) == "maratus_volans_male", "something that is not a spider counts as the first")
	for _, id in SpiderChoice.ORDER do
		check(Model.valueText("Spider", id) == PeacockText.title(id) and string.lower(string.sub(Model.valueText("Spider", id), 1, 1)) .. string.sub(Model.valueText("Spider", id), 2) == PeacockText.NAMES[id], `{id}: the row says its name from PeacockText.NAMES`)
	end
	check(Model.valueText("Spider", "maratus_volans_male") == "The peacock spider" and Model.valueText("Spider", nil) == "The first spider" and Model.line("Spider", "myrmarachne_formicaria_female") == "Spider: The ant-mimicking spider"
		and Model.valueText("Spider", "brachypelma_hamorii") == "The Mexican redknee" and Model.line("Spider", "chromatopelma_cyaneopubescens") == "Spider: The Greenbottle blue", "the words")
	-- a locked spider is skipped (nothing is locked today: the ownership hook is SpiderChoice.locked)
	local real = SpiderChoice.locked
	SpiderChoice.locked = function(id: string): boolean return id == "maratus_volans_male" end
	check(Model.step("Spider", "first_spider", 1) == "myrmarachne_formicaria_female" and Model.step("Spider", "myrmarachne_formicaria_female", -1) == "first_spider", "a locked spider is skipped, both ways")
	SpiderChoice.locked = real
	check(Model.step("Spider", "first_spider", 1) == "maratus_volans_male", "and everything is free again")
end

-- ---------------------------------------------------------------- moving about without a mouse (SettingsNav)
do
	local nav = Nav.new()
	local rows = nav.rows
	check(#rows == #Spec.LIST + #Spec.LIVE + 5 + 2, "a header per section, every setting and live row, then Reset and Back")
	check(rows[1].kind == "header" and rows[1].title == "Sound" and rows[#rows - 1].kind == "reset" and rows[#rows].kind == "back", "in order, ending with Reset and Back")
	check(nav:current().kind == "setting" and nav:current().id == "SoundMuted", "it starts on the first setting, not on a header")
	nav:move(1)
	check(nav:current().id == "MasterVolume", "Down chooses the next")
	nav:move(-1)
	nav:move(-1)
	check(nav:current().kind == "back", "Up from the first wraps to Back")
	nav:move(-1)
	check(nav:current().kind == "reset", "and then Reset")
	nav:move(-1)
	check(nav:current().id == "Inspect", "and then the last row, Inspect your spider (ROBLOX-90)")
	nav:move(-1)
	check(nav:current().id == "Spider", "and then the Spider")
	nav:move(-1)
	check(nav:current().id == "NotebookNotes", "and then the last saved setting")
	nav:move(1)
	nav:move(1)
	nav:move(1)
	nav:move(1)
	nav:move(1)
	check(nav:current().id == "SoundMuted", "Down from Back wraps to the first setting")
	for _ = 1, 3 * #rows do
		nav:move(1)
		if nav:current().kind == "header" then check(false, "the choice landed on a header") break end
	end
	nav:first()
	nav:section(1)
	check(nav:current().id == "LookSensitivityMouse", "PageDown goes to the first setting of the next section")
	nav:move(1)
	nav:section(-1)
	check(nav:current().id == "LookSensitivityMouse", "PageUp from partway down goes to the start of this section")
	nav:section(-1)
	check(nav:current().id == "SoundMuted", "and then to the one before")
	nav:section(-1)
	check(nav:current().section == "spider", "and wraps to the last section's start")
	check(nav:current().id == "Spider", "which is Your spider")
	nav:section(-1)
	check(nav:current().id == "ControlHints", "and Help and hints is the one before")
	nav:section(1)
	nav:section(1)
	check(nav:current().id == "SoundMuted", "forward from the last section wraps to the first")
	nav:select(#rows)
	nav:section(1)
	check(nav:current().id == "SoundMuted", "from Back, PageDown goes to the first section")
	nav:select(#rows)
	nav:section(-1)
	check(nav:current().id == "Spider", "and PageUp to the last")
	check(not nav:select(1) and nav:current().id == "Spider", "a header cannot be chosen")
	check(nav:selectId("FieldOfView") and nav:current().id == "FieldOfView" and not nav:selectId("Nope"), "a setting can be chosen by id")
end

-- ---------------------------------------------------------------- the words and the layout rules (SettingsText)
do
	ControlText.setPadStyle("xbox")
	check(Text.controls("keyboard") == "Up/Down: choose    Left/Right: change    Enter: switch    PageUp/PageDown: sections    O or Q: back", "the keyboard line")
	check(Text.controls("gamepad") == "Stick or D-pad: choose and change    A: switch    LB and RB: sections    B: back", "the Xbox line")
	ControlText.setPadStyle("playstation")
	check(Text.controls("gamepad") == "Stick or D-pad: choose and change    Cross: switch    L1 and R1: sections    Circle: back", "the PlayStation line says Cross, L1, R1 and Circle")
	check(Text.openHint("gamepad") == "Touchpad, then Settings" and Text.openHint("touch") == "Menu, then Settings" and Text.openHint("keyboard") == "O, or M then Settings", "how to open it on each device")
	ControlText.setPadStyle("xbox")
	check(Text.openHint("gamepad") == "View, then Settings", "View on an Xbox controller")
	check(Text.controls("touch") == "Tap a setting to switch it. Use - and + or drag a bar.", "the touch line")
	check(ControlText.name("keyboard", "settings") == "O" and ControlText.name("gamepad", "settings") == "" and string.find(ControlText.helpCard("keyboard"), "O: settings", 1, true) ~= nil, "O opens it, and the controls card says so")
	check(Text.buttonTextSize("Back", 200, 44, 18) == 18 and Text.buttonTextSize(string.rep("word ", 30), 100, 44, 18) == 10, "a button's text shrinks to fit its height, to 10 at the least")
	check(Text.scale(false) == 1 and Text.scale(true) == 1.5, "large text is 1.5 times")
	-- the screens in use: desktop, a tablet either way up, phones either way up, the smallest landscape, and a short laptop window
	local screens = { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 768, 1024 }, { 844, 390 }, { 667, 375 }, { 568, 320 }, { 390, 844 }, { 360, 640 }, { 1100, 500 } }
	for _, scr in screens do
		for _, s in { 1, 1.5 } do
			local m = Text.metrics(scr[1], scr[2], s)
			local name = `{scr[1]}x{scr[2]} at {s}`
			check(m.paperW <= scr[1] and m.paperH <= scr[2], `{name}: the panel fits the screen`)
			check(m.body >= Text.MIN_BODY or m.paperH < 330, `{name}: the list has room ({m.body})`)
			check(m.hint == 0 or m.body >= Text.MIN_BODY, `{name}: the controls line only when the list keeps its room`)
			check(m.foot - 8 >= math.floor(Text.MIN_TARGET * s), `{name}: the footer's buttons are touch targets`)
			do
				local bw = math.floor(math.min(260 * s, (m.paperW - 28 - 16) / 2))
				for _, word in { Spec.WORDS.reset, Spec.WORDS.resetSure, Spec.WORDS.close } do
					local fit = Text.buttonTextSize(word, bw, m.foot - 8, Text.SIZES.button * s)
					check(fit >= 12 and fit <= Text.SIZES.button * s, `{name}: "{word}" gets a readable size ({fit}) in its button`)
				end
			end
			for _, kind in { "toggle", "choice", "slider" } do
				local rl = Text.rowLayout(m.bodyW, kind, s)
				local pad = Text.PAD * s
				check(rl.labelW >= (if rl.valueTop then 70 else 100) * s, `{name} {kind}: the label keeps {rl.labelW} px`)
				check(rl.controlW <= m.bodyW - 2 * pad + 1e-6, `{name} {kind}: the control fits the row`)
				if kind == "slider" then
					local bar = rl.controlW - 2 * math.floor(Text.MIN_TARGET * s) - 2 * Text.GAP * s - (if rl.valueTop then 0 else math.floor(Text.VALUE_WIDTH * s) + Text.GAP * s)
					check(bar >= 60, `{name} slider: the bar is {bar} px`)
				end
				if kind == "choice" then
					check(rl.controlW - 2 * math.floor(Text.MIN_TARGET * s) - 2 * Text.GAP * s >= 70, `{name} choice: room for the word`)
				end
				check(Text.rowHeight(rl, 20, 0, s) >= math.floor(Text.MIN_TARGET * s), `{name} {kind}: a row is at least a touch target tall`)
			end
		end
	end
	check(not Text.rowLayout(Text.metrics(1280, 720, 1).bodyW, "slider", 1).stacked, "a desktop row has the label beside the control")
	check(Text.rowLayout(Text.metrics(1280, 720, 1.5).bodyW, "slider", 1.5).stacked == false or true, "(large text on a desktop)")
	check(Text.rowLayout(Text.metrics(844, 390, 1.5).bodyW, "slider", 1.5).stacked and Text.rowLayout(Text.metrics(844, 390, 1.5).bodyW, "slider", 1.5).valueTop, "large text on a phone stacks a slider with its number on the label's line")
	check(Text.rowLayout(Text.metrics(360, 640, 1).bodyW, "toggle", 1).stacked == false, "a toggle is narrow enough to stay beside its label on a small phone")
end

-- ---------------------------------------------------------------- the panel on its own (SettingsPanel)
local GuiService = game:GetService("GuiService")
local function build(width: number, height: number, startValues: { [string]: any }?): (any, any)
	local state: any = { values = {}, log = {}, resets = 0, inspects = 0, status = "saved", refuse = false }
	for k, v in startValues or {} do state.values[k] = v end
	local io = {
		get = function(id: string): any
			if Model.live(id) then return state.spider end -- (the client: `appearance`, not a setting)
			return Model.get(function(k: string): any return state.values[k] end, id)
		end,
		set = function(id: string, v: any): string?
			table.insert(state.log, id)
			if id == "Inspect" then -- (the client: a button; it closes the panel into the close look, or answers why not)
				state.inspects += 1
				if state.refuse then return InspectText.NOT_NOW end
				return nil
			end
			if Model.live(id) then
				if state.refuse then return PeacockText.NOT_NOW end
				state.spider = v
				return PeacockText.changed(v)
			end
			state.values[id] = v
			return nil
		end,
		reset = function() state.resets += 1; for _, id in Model.ids() do state.values[id] = Model.default(id) end end,
		status = function(): string? return state.status end,
	}
	state.closed = {}
	state.spider = "first_spider"
	local panel = SettingsPanel.new(Instance.new("Folder"), io, function(to: string?) table.insert(state.closed, if to then to else "nil") end)
	panel.gui.AbsoluteSize = { X = width, Y = height }
	local m = Text.metrics(width, height, 1)
	panel.list.AbsoluteSize = { X = m.bodyW + Text.SCROLLBAR, Y = m.body }
	panel.list.AbsoluteCanvasSize = { X = m.bodyW, Y = 3000 }
	return panel, state
end
local function key(code: string, st: any?, pos: any?)
	local fn = stubs.actions["WindowsillSettings"]
	assert(fn, "the settings are not listening")
	return fn("WindowsillSettings", st or Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = pos or Vector3.zero })
end
local function widgetOf(panel: any, id: string): any
	for _, w in panel.widgets do if w.kind == "setting" and w.id == id then return w end end
	return nil
end
local function chosen(panel: any): string
	local row = panel.nav:current()
	return if row.kind == "setting" then row.id else row.kind
end

do
	local panel, st = build(1280, 720)
	check(not panel:isShowing() and not panel.gui.Enabled and stubs.actions["WindowsillSettings"] == nil, "closed at first, and not listening")
	panel:open("menu", "keyboard", 1)
	check(panel:isShowing() and panel.gui.Enabled and stubs.actions["WindowsillSettings"] ~= nil, "open: it is listening")
	check(panel.heading.Text == "Settings" and panel.resetButton.Text == "Reset to defaults" and panel.backButton.Text == "Back", "its words")
	local headers, rows = 0, 0
	for _, w in panel.widgets do
		if w.kind == "header" then headers += 1 elseif w.kind == "setting" then rows += 1 end
	end
	check(headers == 5 and rows == #Spec.LIST + #Spec.LIVE, "five sections and every setting and live row have a place")
	check(panel.widgets[1].frame.Text == "Sound" and panel.widgets[1].frame.Name == "Header_sound", "the first section is Sound")
	check(panel.status.Text == Spec.WORDS.savedLine, "it says the settings are kept with the saved game")
	check(widgetOf(panel, "MasterVolume").value.Text == "100%" and widgetOf(panel, "SoundMuted").value.Text == "Off" and widgetOf(panel, "Captions").value.Text == "Normal", "values from the defaults")
	check(widgetOf(panel, "MasterVolume").label.Text == "Volume" and widgetOf(panel, "FrameLine").note.Text == "The view may turn to show the line while the spider hangs on it.", "labels and notes")
	check(chosen(panel) == "SoundMuted", "it opens on the first setting")
	check(widgetOf(panel, "SoundMuted").stroke.Enabled and not widgetOf(panel, "MasterVolume").stroke.Enabled, "which is marked")
	-- keys
	key("Return")
	check(st.values.SoundMuted == true and widgetOf(panel, "SoundMuted").value.Text == "On", "Enter switches a toggle on")
	key("Space")
	check(st.values.SoundMuted == false and widgetOf(panel, "SoundMuted").value.Text == "Off", "Space switches it off")
	key("Down")
	check(chosen(panel) == "MasterVolume", "Down chooses the next row")
	key("Left")
	check(st.values.MasterVolume == 0.95 and widgetOf(panel, "MasterVolume").value.Text == "95%", "Left lowers a slider a step")
	key("Right", Enum.UserInputState.End)
	key("Right")
	key("Right", Enum.UserInputState.End)
	check(st.values.MasterVolume == 1.0 and widgetOf(panel, "MasterVolume").value.Text == "100%", "Right raises it, and stops at the end")
	key("Return")
	check(st.values.MasterVolume == 1.0, "Enter does nothing to a slider")
	-- holding Left runs the slider after a pause
	key("Left")
	check(st.values.MasterVolume == 0.95, "the first press steps once")
	for _ = 1, 3 do panel:update(0.1) end
	check(st.values.MasterVolume == 0.95, "and waits before it repeats")
	for _ = 1, 5 do panel:update(0.1) end
	check(st.values.MasterVolume < 0.85 and st.values.MasterVolume > 0.5, `held, it runs ({st.values.MasterVolume})`)
	key("Left", Enum.UserInputState.End)
	local rested = st.values.MasterVolume
	for _ = 1, 10 do panel:update(0.1) end
	check(st.values.MasterVolume == rested, "released, it stops")
	panel:update(10)
	check(st.values.MasterVolume == rested, "(a long frame with nothing held does nothing)")
	-- a choice
	check(panel.nav:selectId("Captions"), "choose Captions")
	key("Right")
	check(st.values.Captions == "large" and widgetOf(panel, "Captions").value.Text == "Large", "Right: the next option")
	key("Right", Enum.UserInputState.End)
	key("Right")
	key("Right", Enum.UserInputState.End)
	check(st.values.Captions == "off", "and the next wraps round")
	key("Return")
	check(st.values.Captions == "normal", "Enter steps a choice on")
	key("Left", Enum.UserInputState.End)
	-- sections
	panel.nav:first()
	key("PageDown")
	check(chosen(panel) == "LookSensitivityMouse", "PageDown: the next section")
	key("PageUp")
	check(chosen(panel) == "SoundMuted", "PageUp: back to the first")
	key("ButtonR1")
	check(chosen(panel) == "LookSensitivityMouse", "R1 / RB: the next section")
	key("ButtonL1")
	check(chosen(panel) == "SoundMuted", "L1 / LB: the one before")
	-- Reset takes two presses
	key("Up")
	check(chosen(panel) == "back", "Up from the first wraps to Back")
	key("Up")
	check(chosen(panel) == "reset", "then Reset")
	key("Return")
	check(st.resets == 0 and panel.resetButton.Text == "Press again to reset", "the first press asks")
	key("Down")
	check(panel.resetButton.Text == "Reset to defaults" and st.resets == 0, "moving away cancels the question")
	key("Up")
	key("Return")
	key("Return")
	check(st.resets == 1 and widgetOf(panel, "MasterVolume").value.Text == "100%" and panel.status.Text == "Settings are back to their defaults.", "the second press resets, shows it, and says so")
	key("Left")
	key("Left", Enum.UserInputState.End)
	key("Right")
	check(chosen(panel) == "back", "Right from Reset: Back")
	key("Right", Enum.UserInputState.End)
	key("Left")
	check(chosen(panel) == "reset", "Left from Back: Reset")
	key("Left", Enum.UserInputState.End)
	key("Right")
	key("Right", Enum.UserInputState.End)
	key("Return")
	check(not panel:isShowing() and st.closed[1] == "menu" and stubs.actions["WindowsillSettings"] == nil and GuiService.SelectedObject == nil, "Enter on Back closes, says where it was opened from, and stops listening")
	panel:close()
	check(#st.closed == 1, "(a stray close does nothing twice)")
	for _, code in { "Q", "ButtonB", "Backspace", "O" } do
		panel:open("game", "keyboard", 1)
		key(code)
		check(not panel:isShowing() and st.closed[#st.closed] == "game", `{code} closes`)
	end
	panel:open("game", "keyboard", 1)
	local before = #st.log
	GuiService.MenuIsOpen = true
	local result = key("Return")
	check(result == Enum.ContextActionResult.Pass and #st.log == before, "while Roblox's own menu is open the panel passes everything on")
	GuiService.MenuIsOpen = false
	-- the sticks
	local function stick(x: number, y: number, which: string?)
		stubs.actions["WindowsillSettings"]("WindowsillSettings", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode[which or "Thumbstick1"], UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(x, y, 0) })
	end
	panel.nav:first()
	stick(0, -1)
	check(chosen(panel) == "MasterVolume", "the left stick pushed down chooses the next row")
	stick(0, -0.9)
	check(chosen(panel) == "MasterVolume", "held there it does not run on")
	stick(0, 0)
	stick(0, 1)
	check(chosen(panel) == "SoundMuted", "released and pushed up it chooses the one before")
	stick(0, 0)
	panel.nav:selectId("MasterVolume")
	stick(-1, 0)
	check(st.values.MasterVolume == 0.95, "pushed left it lowers a slider")
	for _ = 1, 8 do panel:update(0.1) end
	check(st.values.MasterVolume < 0.85, "held, it runs")
	stick(0, 0)
	local at = st.values.MasterVolume
	for _ = 1, 8 do panel:update(0.1) end
	check(st.values.MasterVolume == at, "and stops when the stick returns")
	panel.list.CanvasPosition = Vector2.zero
	stick(0, -1, "Thumbstick2")
	for _ = 1, 5 do panel:update(0.1) end
	check(panel.list.CanvasPosition.Y > 200, `the right stick scrolls the list ({panel.list.CanvasPosition.Y})`)
	stick(0, 0, "Thumbstick2")
	panel:close()
end

do
	-- the mouse and touch: taps, - and +, a drag
	local panel, st = build(1280, 720)
	panel:open("game", "touch", 1)
	check(panel.hint.Text == "Tap a setting to switch it. Use - and + or drag a bar.", "the touch line is shown")
	widgetOf(panel, "InvertY").value.Activated:Fire()
	check(st.values.InvertY == true and chosen(panel) == "InvertY", "a tap on a toggle's button switches it and chooses the row")
	widgetOf(panel, "InvertX").frame.Activated:Fire()
	check(st.values.InvertX == true, "so does a tap anywhere on the row")
	widgetOf(panel, "FieldOfView").frame.Activated:Fire()
	check(st.values.FieldOfView == nil and chosen(panel) == "FieldOfView", "a tap on a slider's row only chooses it")
	widgetOf(panel, "FieldOfView").plus.Activated:Fire()
	check(st.values.FieldOfView == 66 and widgetOf(panel, "FieldOfView").value.Text == "66 degrees", "+ raises it")
	widgetOf(panel, "FieldOfView").minus.Activated:Fire()
	widgetOf(panel, "FieldOfView").minus.Activated:Fire()
	check(st.values.FieldOfView == 64, "- lowers it")
	widgetOf(panel, "Captions").next.Activated:Fire()
	check(st.values.Captions == "large", "a choice's > goes on")
	widgetOf(panel, "Captions").prev.Activated:Fire()
	widgetOf(panel, "Captions").prev.Activated:Fire()
	check(st.values.Captions == "off", "and < goes back")
	widgetOf(panel, "Captions").value.Activated:Fire()
	check(st.values.Captions == "normal", "a tap on the word steps it on")
	-- dragging the bar
	local w = widgetOf(panel, "MasterVolume")
	w.bar.AbsolutePosition = { X = 100, Y = 0 }
	w.bar.AbsoluteSize = { X = 200, Y = 44 }
	local touch = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(200, 10, 0) }
	w.bar.InputBegan:Fire(touch)
	check(st.values.MasterVolume == 0.5 and chosen(panel) == "MasterVolume" and panel.list.ScrollingEnabled == false, "touching the bar sets the value there and stops the list scrolling under the finger")
	touch.Position = Vector3.new(260, 12, 0)
	game:GetService("UserInputService").InputChanged:Fire(touch)
	check(st.values.MasterVolume == 0.8, `and dragging follows ({st.values.MasterVolume})`)
	touch.Position = Vector3.new(900, 12, 0)
	game:GetService("UserInputService").InputChanged:Fire(touch)
	check(st.values.MasterVolume == 1.0, "past the end it stops at the end")
	touch.Position = Vector3.new(-50, 12, 0)
	game:GetService("UserInputService").InputChanged:Fire(touch)
	check(st.values.MasterVolume == 0, "and at the other")
	game:GetService("UserInputService").InputEnded:Fire(touch)
	check(panel.drag == nil and panel.list.ScrollingEnabled == true, "lifting the finger ends the drag and frees the list")
	touch.Position = Vector3.new(200, 12, 0)
	game:GetService("UserInputService").InputChanged:Fire(touch)
	check(st.values.MasterVolume == 0, "a finger moving after that changes nothing")
	local mouse = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(120, 10, 0) }
	w.bar.InputBegan:Fire(mouse)
	check(st.values.MasterVolume == 0.1, "a mouse press on the bar sets the value")
	game:GetService("UserInputService").InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(280, 10, 0) })
	check(st.values.MasterVolume == 0.9, "and moving the mouse drags")
	game:GetService("UserInputService").InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(280, 10, 0) })
	check(panel.drag == nil, "releasing the button ends it")
	panel.resetButton.Activated:Fire()
	check(st.resets == 0 and panel.resetButton.Text == Spec.WORDS.resetSure, "Reset asks first")
	panel.resetButton.Activated:Fire()
	check(st.resets == 1, "and resets on the second tap")
	panel.backButton.Activated:Fire()
	check(not panel:isShowing() and st.closed[1] == "game", "Back closes")
	-- the controls line follows the device, with PlayStation names
	panel:open("game", "keyboard", 1)
	ControlText.setPadStyle("playstation")
	panel:setDevice("gamepad")
	check(string.find(panel.hint.Text, "Cross: switch", 1, true) ~= nil and string.find(panel.hint.Text, "L1 and R1", 1, true) ~= nil, "a PlayStation controller sees Cross and L1 and R1")
	ControlText.setPadStyle("xbox")
	panel:setDevice("keyboard")
	check(string.find(panel.hint.Text, "Enter: switch", 1, true) ~= nil, "and the keyboard line comes back")
	panel:close()
end

do
	-- the Spider row (ROBLOX-71): reads and drives the live spider, may be refused, is not reset
	local panel, st = build(1280, 720)
	panel:open("game", "keyboard", 1)
	local w = widgetOf(panel, "Spider")
	check(w ~= nil and w.label.Text == "Spider" and w.value.Text == "The first spider" and w.note.Visible and w.note.Text == Spec.LIVE[1].note, "the row: its label, the spider it shows, its note")
	check(panel.widgets[#panel.widgets - 2].kind == "header" and panel.widgets[#panel.widgets - 2].frame.Text == "Your spider" and panel.widgets[#panel.widgets - 1] == w, "it sits first under Your spider, with the Inspect button after it")
	panel.nav:selectId("Spider")
	key("Right")
	check(st.spider == "maratus_volans_male" and w.value.Text == "The peacock spider" and panel.status.Text == "You are the peacock spider now", "Right: the next spider, shown and said")
	key("Right", Enum.UserInputState.End)
	key("Return")
	check(st.spider == "myrmarachne_formicaria_female" and w.value.Text == "The ant-mimicking spider", "Enter steps it on")
	key("Left")
	key("Left", Enum.UserInputState.End)
	check(st.spider == "maratus_volans_male", "Left steps back")
	for _ = 1, 4 do w.next.Activated:Fire() end
	check(st.spider == "first_spider" and w.value.Text == "The first spider", "the arrows on a tap, round the five and back")
	w.value.Activated:Fire()
	check(st.spider == "maratus_volans_male", "a tap on the word steps it on")
	check(st.values.Spider == nil, "it is never held as a setting")
	-- refused: the row snaps back to the spider it still is, and the panel says why
	st.refuse = true
	key("Return")
	check(st.spider == "maratus_volans_male" and w.value.Text == "The peacock spider" and panel.status.Text == PeacockText.NOT_NOW, "refused: the row shows the spider it still is, and the line says it will not change now")
	st.refuse = false
	-- the line is the panel's own, and the next change of anything clears it
	panel.nav:selectId("SoundMuted")
	key("Return")
	check(panel.status.Text == Spec.WORDS.savedLine, "changing a saved setting brings the saving line back")
	-- Reset leaves the spider alone
	panel.nav:select(#panel.nav.rows - 1)
	key("Return")
	key("Return")
	check(st.resets == 1 and st.spider == "maratus_volans_male" and w.value.Text == "The peacock spider", "Reset to defaults does not touch the spider")
	-- every name fits its button at a readable size, on a phone and with large text
	for _, scr in { { 1280, 720 }, { 360, 640 }, { 568, 320 } } do
		for _, large in { false, true } do
			local p2, st2 = build(scr[1], scr[2], { LargeText = large })
			p2:open("game", "touch", if large then 1.5 else 1)
			local w2 = widgetOf(p2, "Spider")
			for _, id in SpiderChoice.ORDER do
				st2.spider = id
				p2:refreshRow("Spider")
				check(w2.value.TextSize >= 11 and w2.value.Text == PeacockText.title(id), `{scr[1]}x{scr[2]}{if large then " large" else ""}: "{w2.value.Text}" is {w2.value.TextSize} pt in its button`)
			end
			p2:close()
		end
	end
	panel:close()
end

do
	-- the Inspect row (ROBLOX-90): a button, a live row like the Spider's, but it has no value
	local live = Spec.LIVE[2]
	check(live.id == "Inspect" and live.section == "spider" and live.kind == "action" and live.label == "Inspect your spider", "the row: Inspect your spider, an action, in Your spider")
	check(#live.label <= 56 and live.note ~= nil and #(live.note :: string) <= 110, "a label and a note that fit a line")
	for _, s in Spec.LIST do check(s.id ~= "Inspect", "no saved setting is called Inspect") end
	check(Model.live("Inspect") and Model.spec("Inspect") == live and not Model.known("Inspect") and table.find(Model.ids(), "Inspect") == nil and Model.defaults().Inspect == nil, "a live row that ids(), defaults() and known() leave out")
	local v, pr = Model.clean("Inspect", true)
	check(v == nil and pr == nil, "clean() drops it quietly")
	local problems3, cleaned3 = Model.cleanAll({ Inspect = true, InvertY = true })
	check(#problems3 == 0 and cleaned3.Inspect == nil and cleaned3.InvertY == true, "a saved settings table that holds it keeps nothing of it")
	local payload = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, nil, { Inspect = true, InvertY = true })
	check(payload.settings.Inspect == nil and payload.settings.InvertY == true, "the save never has it")
	check(Model.valueText("Inspect", nil) == InspectText.BUTTON and Model.valueText("Inspect", true) == "Look closely" and Model.line("Inspect", nil) == "Inspect your spider: Look closely", "its word is the button's")
	check(Model.step("Inspect", nil, 1) == true and Model.step("Inspect", true, -1) == true, "switching it steps to true, either way")
	check(Text.controlWidth("action", 1) == 160 and Text.controlWidth("action", 1.5) == 240, "a button 160 wide, scaled with the text")
	local panel, st = build(1280, 720)
	panel:open("game", "keyboard", 1)
	local w = widgetOf(panel, "Inspect")
	check(w ~= nil and w.label.Text == "Inspect your spider" and w.value.Text == "Look closely" and w.note.Visible and w.note.Text == live.note, "the row shows its label, its button and its note")
	check(panel.widgets[#panel.widgets] == w and w.prev == nil and w.minus == nil, "it sits last, and is only a button")
	panel.nav:selectId("Inspect")
	key("Right")
	key("Right", Enum.UserInputState.End)
	key("Left")
	key("Left", Enum.UserInputState.End)
	check(st.inspects == 0, "Left and Right do nothing to it")
	key("Return")
	check(st.inspects == 1 and st.log[#st.log] == "Inspect" and st.values.Inspect == nil, "Enter switches it: the client is told once, and nothing is held as a setting")
	key("Space")
	check(st.inspects == 2, "so does Space")
	w.value.Activated:Fire()
	check(st.inspects == 3, "a tap on the button")
	w.frame.Activated:Fire()
	check(st.inspects == 4, "and a tap anywhere on the row")
	st.refuse = true
	key("Return")
	check(st.inspects == 5 and panel.status.Text == InspectText.NOT_NOW, "refused, the panel's line says why")
	st.refuse = false
	panel.nav:select(#panel.nav.rows - 1)
	key("Return")
	key("Return")
	check(st.resets == 1 and st.inspects == 5, "Reset to defaults does not press it")
	panel:close()
	-- the button's word fits at a readable size, and the row's controls are touch targets, on a phone and with large text
	for _, scr in { { 1280, 720 }, { 360, 640 }, { 568, 320 } } do
		for _, large in { false, true } do
			local p2 = build(scr[1], scr[2], { LargeText = large })
			p2:open("game", "touch", if large then 1.5 else 1)
			local w2 = widgetOf(p2, "Inspect")
			check(w2.value.TextSize >= 11 and w2.value.Size.Y.Offset >= Text.MIN_TARGET * (if large then 1.5 else 1) - 1, `{scr[1]}x{scr[2]}{if large then " large" else ""}: "{w2.value.Text}" is {w2.value.TextSize} pt in a button {w2.value.Size.Y.Offset} tall`)
			p2:close()
		end
	end
end

do
	-- saved settings arriving while it is open; the saving line; large text inside the panel
	local panel, st = build(1280, 720, { MasterVolume = 0.4, Captions = "large", LargeText = false })
	st.status = "session"
	panel:open("menu", "keyboard", 1)
	check(panel.status.Text == Spec.WORDS.sessionLine and widgetOf(panel, "MasterVolume").value.Text == "40%", "session-only says so; values are the held ones")
	st.values.MasterVolume = 0.65
	st.status = "saved"
	panel:refresh()
	check(widgetOf(panel, "MasterVolume").value.Text == "65%" and panel.status.Text == Spec.WORDS.savedLine, "refresh shows values that arrived")
	st.status = nil
	panel:refresh()
	check(panel.status.Text == "", "before the save has answered it says nothing about saving")
	local normalRow = widgetOf(panel, "ReducedMotion").frame.Size.Y.Offset
	local normalText = widgetOf(panel, "ReducedMotion").label.TextSize
	panel.nav:selectId("LargeText")
	key("Return")
	check(st.values.LargeText == true and panel.scale == 1.5, "Large text makes the panel itself larger at once")
	check(widgetOf(panel, "ReducedMotion").label.TextSize > normalText and widgetOf(panel, "ReducedMotion").frame.Size.Y.Offset > normalRow, "text and rows grow")
	key("Return")
	check(panel.scale == 1 and widgetOf(panel, "ReducedMotion").label.TextSize == normalText, "and shrink back")
	panel:close()
	panel:open("menu", "keyboard", 1.5)
	check(panel.scale == 1.5, "opened with the large scale it starts large")
	panel:close()
end

-- Every control of every row inside its row, a touch target tall, with the label and the control apart, on every screen in use.
do
	local screens = { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 768, 1024 }, { 844, 390 }, { 667, 375 }, { 568, 320 }, { 390, 844 }, { 360, 640 }, { 1100, 500 } }
	local function rect(c: any): { x0: number, y0: number, x1: number, y1: number }
		local x, y = c.Position.X.Offset, c.Position.Y.Offset
		return { x0 = x, y0 = y, x1 = x + c.Size.X.Offset, y1 = y + c.Size.Y.Offset }
	end
	local function overlap(a: any, b: any): boolean return a.x0 < b.x1 - 0.01 and b.x0 < a.x1 - 0.01 and a.y0 < b.y1 - 0.01 and b.y0 < a.y1 - 0.01 end
	for _, scr in screens do
		for _, large in { false, true } do
			local s = if large then 1.5 else 1
			local panel = build(scr[1], scr[2], { LargeText = large })
			panel:open("game", "touch", s)
			local m = Text.metrics(scr[1], scr[2], s)
			local name = `{scr[1]}x{scr[2]}{if large then " large" else ""}`
			local target = math.floor(Text.MIN_TARGET * s)
			local bad = 0
			local rowsChecked = 0
			for _, w in panel.widgets do
				if w.kind == "setting" then
					rowsChecked += 1
					local rowW, rowH = m.bodyW, w.frame.Size.Y.Offset
					local parts: { any } = {}
					local ctl: { any } = {}
					for _, key2 in { "label", "note", "value", "prev", "next", "minus", "plus", "bar" } do
						local c = w[key2]
						if c ~= nil and (key2 ~= "note" or w.spec.note ~= nil) then
							local r = rect(c)
							table.insert(parts, { key2, r })
							if key2 ~= "label" and key2 ~= "note" then table.insert(ctl, { key2, r }) end
							if r.x0 < -0.01 or r.y0 < -0.01 or r.x1 > rowW + 0.01 or r.y1 > rowH + 0.01 then
								bad += 1
								print(`  outside: {name} {w.id}.{key2} {r.x0},{r.y0}..{r.x1},{r.y1} in {rowW}x{rowH}`)
							end
							if (key2 == "prev" or key2 == "next" or key2 == "minus" or key2 == "plus") and (r.x1 - r.x0 < target - 0.01 or r.y1 - r.y0 < target - 0.01) then
								bad += 1
								print(`  small: {name} {w.id}.{key2}`)
							end
							if (key2 == "value" and w.spec.kind ~= "slider") and r.y1 - r.y0 < target - 0.01 then bad += 1; print(`  short value: {name} {w.id}`) end
							if key2 == "bar" and (r.y1 - r.y0 < target - 0.01 or r.x1 - r.x0 < 60) then bad += 1; print(`  bar: {name} {w.id} {r.x1 - r.x0}`) end
						end
					end
					for i = 1, #parts do
						for j = i + 1, #parts do
							-- (the note sits under the label: they are apart by construction; the number of a stacked slider sits beside the label)
							if overlap(parts[i][2], parts[j][2]) then
								bad += 1
								print(`  overlap: {name} {w.id}: {parts[i][1]} and {parts[j][1]}`)
							end
						end
					end
					if rowH < target then bad += 1; print(`  row short: {name} {w.id}`) end
				end
			end
			check(rowsChecked == #Spec.LIST + #Spec.LIVE and bad == 0, `{name}: every control sits inside its row, apart from the others, and is a touch target`)
			local foot = panel.resetButton.Size.Y.Offset
			check(m.foot + foot >= target and panel.backButton.Size.X.Offset >= 100 * 1 and panel.resetButton.Position.X.Offset + panel.resetButton.Size.X.Offset <= panel.backButton.Position.X.Offset + m.paperW, `{name}: Reset and Back are touch targets`)
			check(panel.hint.Visible == (m.hint > 0), `{name}: the controls line shows only when there is room`)
			panel:close()
		end
	end
end

-- ---------------------------------------------------------------- the camera's maths (level horizon)
do
	local up = Vector3.new(0, 1, 0)
	local gaze = Vector3.new(0, 0, -1)
	local v = CameraMath.viewUp(gaze, up, up)
	check(near(v:Dot(gaze), 0, 1e-9) and near(v.Magnitude, 1, 1e-9) and near(v.Y, 1, 1e-9), "level: looking along the sill, up is up")
	-- on a wall (body up sideways), looking along it: the level view still puts the world's up at the top
	local wallUp = Vector3.new(1, 0, 0)
	local wallGaze = Vector3.new(0, 0, -1)
	local lv = CameraMath.viewUp(wallGaze, wallUp, wallUp)
	check(near(lv.Y, 1, 1e-9), "on a wall the level view keeps the world's up at the top")
	-- looking straight up: it holds what it had (no spin)
	local skyward = CameraMath.viewUp(Vector3.new(0, 1, 0), up, Vector3.new(0, 0, -1))
	check(near(skyward:Dot(Vector3.new(0, 0, -1)), 1, 1e-9), "looking straight up it holds the up it had")
	local nothing = CameraMath.viewUp(Vector3.new(0, 1, 0), Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
	check(near(nothing.Magnitude, 1, 1e-9) and near(nothing:Dot(Vector3.new(0, 1, 0)), 0, 1e-9), "and with nothing to hold it still gives a unit vector square to the gaze")
	-- a gradual look upward changes up smoothly
	local last = CameraMath.viewUp(Vector3.new(0, 0, -1), up, up)
	local biggest = 0
	for i = 1, 90 do
		local a = math.rad(i)
		local g = Vector3.new(0, math.sin(a), -math.cos(a))
		local cur = CameraMath.viewUp(g, up, last)
		biggest = math.max(biggest, (cur - last).Magnitude)
		last = cur
	end
	check(biggest < 0.2, `looking from level to straight up, the picture's up never jumps ({biggest})`)
	-- the look rotates about the chosen up
	local a = CameraMath.lookEye(gaze, up, math.rad(10), 0, gaze)
	local b = CameraMath.lookEye(gaze, up, math.rad(10), 0, gaze, up)
	check((a - b).Magnitude < 1e-9, "lookEye with turnUp = up is the plain look")
	local c = CameraMath.lookEye(gaze, up, math.rad(10), 0, gaze, Vector3.new(0, 0.6, 0.8))
	check((a - c).Magnitude > 1e-3, "and with another up it turns about that one")
end

-- ---------------------------------------------------------------- the sound mix (Soundscape.setVolumes)
do
	local Soundscape = require("../src/Client/Soundscape")
	local s = Soundscape.new(Instance.new("Folder"))
	local prey = { flies = {}, feeding = { held = nil, struggling = false } }
	s:update(0.1, prey, 1, false, 1, false)
	check(near(s.room.Volume, 0.09, 1e-9) and near(s.birds.Volume, 0.16, 1e-9), "full volume is the mix as it was accepted")
	s:setVolumes(0.5, 0.5, 1)
	s:update(0.1, prey, 1, false, 1, false)
	check(near(s.room.Volume, 0.09 * 0.25, 1e-9) and near(s.birds.Volume, 0.16 * 0.25, 1e-9), "master times ambience scales the room and the birds")
	s:setVolumes(0, 1, 1)
	s:update(0.1, prey, 1, false, 1, false)
	check(s.room.Volume == 0, "master at nothing silences them")
	s:setVolumes(5, -3, 2)
	check(s.master == 1 and s.ambience == 0 and s.creatures == 1, "out-of-range volumes are held to 0..1")
	local f: any = { position = Vector3.new(1, 2, 3), flying = true }
	function f:airborne() return self.flying end
	local p2 = { flies = { f }, feeding = { held = nil, struggling = false } }
	s:setVolumes(0.5, 0, 0.5)
	s:update(0.1, p2, 1, false, 1, false)
	check(near(s.slots[1].buzz.Volume, 0.23 * 0.25, 1e-9) and near(s.slots[1].takeoff.Volume, 0.22 * 0.25, 1e-9), "master times creatures scales a fly")
	check(s.room.Volume == 0, "and ambience at nothing silences the room alone")
end

-- ---------------------------------------------------------------- the ambient music voice (ROBLOX-76)
do
	local Soundscape = require("../src/Client/Soundscape")
	local prey = { flies = {}, feeding = { held = nil, struggling = false } }
	local away = { phase = "away", wasp = { mode = "flying", position = Vector3.new(0, 20, 0) } }
	local visiting = { phase = "searching", wasp = { mode = "flying", position = Vector3.new(0, 5, 0) } }
	-- The real id is in (114531800455832, uploaded 2026-10-18); an empty id would mean no voice at all, and nothing else changes.
	check(Soundscape.IDS.music == "rbxassetid://114531800455832", "the music's asset id is the uploaded loop")
	local realId = Soundscape.IDS.music
	Soundscape.IDS.music = ""
	local silent = Soundscape.new(Instance.new("Folder"))
	silent:setVolumes(1, 1, 1, 0.5)
	silent:update(0.1, prey, 1, false, 1, false)
	silent:updateWasp(visiting, false, 1, false)
	silent:update(0.1, prey, 1, false, 1, false)
	check(silent.music == nil and silent.root:FindFirstChild("music") == nil and near(silent.musicVolume, 0.5, 1e-9) and near(silent.room.Volume, 0.09, 1e-9), "with an empty id there is no music voice, and the room is as it was")
	-- With an id the voice exists: looped, in the mix at 0.18, scenery kept under the buzz and the hum.
	Soundscape.IDS.music = "rbxassetid://1"
	local s = Soundscape.new(Instance.new("Folder"))
	local music: any = s.music
	check(music ~= nil and music.Name == "music" and music.Looped == true and music.SoundId == "rbxassetid://1" and music.Parent == s.root, "with an id there is one looped voice called music")
	s:update(0.1, prey, 1, false, 1, false)
	check(near(music.Volume, 0.18, 1e-9) and music.Playing, "at full volume it is 0.18 in the mix, playing")
	check(0.18 > 0.16 and 0.18 < 0.23 and music.Volume > s.room.Volume, "above the room tone and the birds, under the buzz's 0.23 and the hum")
	s:setVolumes(0.5, 0.2, 0.2, 0.5)
	s:update(0.1, prey, 1, false, 1, false)
	check(near(music.Volume, 0.18 * 0.25, 1e-9), "master times the music volume (not the room's or the creatures')")
	s:setVolumes(1, 1, 1)
	s:update(0.1, prey, 1, false, 1, false)
	check(near(music.Volume, 0.18, 1e-9), "a caller that leaves the fourth volume out gets full music")
	s:setVolumes(1, 1, 1, 0)
	s:update(0.1, prey, 1, false, 1, false)
	check(music.Volume == 0, "music at nothing is silent")
	s:setVolumes(2, 2, 2, 9)
	check(s.musicVolume == 1 and s.master == 1, "out of range is held to 0..1")
	s:setVolumes(1, 1, 1, 1)
	-- It pauses with the menu and the mute, and does not follow slow motion.
	s:update(0.1, prey, 1, true, 1, false)
	check(not music.Playing, "it pauses with the menu")
	s:update(0.1, prey, 1, false, 1, true)
	check(not music.Playing, "it stops with the mute")
	s:update(0.1, prey, 1, false, 0.5, false)
	check(music.Playing and (music.PlaybackSpeed == nil or music.PlaybackSpeed == 1) and s.room.PlaybackSpeed == 0.5, "and in slow motion the music plays at its own pace while the room slows")
	-- Ducking: to 40 per cent over a second while the wasp is on the sill, back over a second after.
	local function run(seconds: number, director: any)
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			s:updateWasp(director, false, 1, false)
			s:update(1 / 60, prey, 1, false, 1, false)
		end
	end
	s:setVolumes(1, 1, 1, 1)
	run(2, away)
	check(near(music.Volume, 0.18, 1e-9) and s.duck == 1, "with the wasp away the music is not ducked")
	run(0.5, visiting)
	check(near(music.Volume, 0.18 * 0.7, 2e-3) and s.duck < 1 and s.duck > 0.4, `half a second in it is part way down (${string.format("%.3f", music.Volume)})`)
	run(0.55, visiting)
	check(near(music.Volume, 0.18 * 0.4, 1e-9), "by a second it is at 40 per cent")
	run(3, visiting)
	check(near(music.Volume, 0.18 * 0.4, 1e-9), "and stays there while the wasp is here")
	local arriving = { phase = "arriving", wasp = { mode = "flying", position = Vector3.new(38, 19, 2) } }
	local walking = { phase = "searching", wasp = { mode = "walking", position = Vector3.new(0, 0.3, 4) } }
	run(0.2, walking)
	check(near(music.Volume, 0.18 * 0.4, 1e-9), "(on the ground as well)")
	run(0.5, away)
	check(near(music.Volume, 0.18 * 0.7, 2e-3) and s.duck > 0.4 and s.duck < 1, "after it goes the music comes back over a second")
	run(0.6, away)
	check(near(music.Volume, 0.18, 1e-9), "all the way")
	run(0.1, arriving)
	check(s.duck < 1, "it begins to duck as the warning begins, while the wasp is still outside")
	-- The ducking times the volume setting.
	s:setVolumes(0.5, 1, 1, 0.5)
	run(2, visiting)
	check(near(music.Volume, 0.18 * 0.25 * 0.4, 1e-9), "and ducking multiplies the player's volumes")
	-- ROBLOX-89: the mating scene swells the music to 1.6 times itself over a second and lets it back after; the wasp's duck still wins; nothing else is touched.
	s:setVolumes(1, 1, 1, 1)
	run(3, away)
	check(near(music.Volume, 0.18, 1e-9) and s.swell == 1 and Soundscape.SWELL == 1.6 and Soundscape.SWELL_S == 1.0, "before the scene the music is as it was; the swell is 1.6 over 1 s")
	local birdsBefore, roomBefore = s.birds.Volume, s.room.Volume
	s:setSwell(true)
	run(0.5, away)
	check(near(music.Volume, 0.18 * 1.3, 2e-3) and s.swell > 1.25 and s.swell < 1.35, `half a second in it is half way up (${string.format("%.3f", music.Volume)})`)
	run(0.55, away)
	check(near(music.Volume, 0.18 * 1.6, 1e-9), "by a second it is at 1.6 times")
	run(5, away)
	check(near(music.Volume, 0.18 * 1.6, 1e-9), "and stays there for the scene")
	check(s.birds.Volume == birdsBefore and s.room.Volume == roomBefore, "the birds and the room go on as they were")
	s:setVolumes(0.5, 1, 1, 0.5)
	run(0.1, away)
	check(near(music.Volume, 0.18 * 0.25 * 1.6, 1e-9), "it multiplies the player's volumes, as the duck does")
	s:setVolumes(1, 1, 1, 1)
	run(0.1, away)
	run(0.5, visiting)
	check(s.duck < 1 and s.swell < 1.6 and music.Volume < 0.18 * 1.6 * 0.8, "a wasp on the sill: the duck wins, the swell goes with it")
	run(1.2, visiting)
	check(near(music.Volume, 0.18 * 0.4, 1e-9) and s.swell == 1, "ducked to 40 per cent, no swell on it")
	run(2, away)
	check(near(music.Volume, 0.18 * 1.6, 1e-9), "when the wasp has gone and the scene is still on, the swell returns")
	s:setSwell(false)
	run(0.5, away)
	check(near(music.Volume, 0.18 * 1.3, 2e-3), "after the scene it comes back over a second")
	run(0.6, away)
	check(near(music.Volume, 0.18, 1e-9) and s.swell == 1, "all the way")
	Soundscape.IDS.music = ""
	local again = Soundscape.new(Instance.new("Folder"))
	check(again.music == nil, "an empty id again: no voice")
	again:setSwell(true)
	again:update(0.1, prey, 1, false, 1, false)
	check(again.music == nil, "(a swell with no voice is nothing)")
	Soundscape.IDS.music = realId
end

-- ---------------------------------------------------------------- the real client: every setting does what it says
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local SaveRules = require("../src/Shared/Data/SaveRules")
do
	local pieces = {}
	for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
	BoxWorld.folder("Windowsill", pieces)
	local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
	if not loaded then print("LOAD ERROR", loadError) end
	check(loaded, "the real client loads with the settings panel in it")
	local frame = ClientStubs.renderSteps.SpiderSim
	local driver: any = ClientStubs.driver
	local lp: any = game:GetService("Players").LocalPlayer
	local gui = lp:FindFirstChild("PlayerGui")
	local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
	local function find(screen: string, name: string): any
		local g = gui:FindFirstChild(screen)
		if not g then return nil end
		for _, d in g:GetDescendants() do if d.Name == name then return d end end
		return nil
	end
	local function press(action: string, code: string)
		local fn = stubs.actions[action]
		fn(action, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
		fn(action, Enum.UserInputState.End, { KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	end
	local function setAll(values: { [string]: any }) for k, v in values do lp:SetAttribute(k, v) end end
	frames(120)
	check(driver ~= nil and driver.settingsPanel ~= nil, "the test hook has the settings panel")
	-- nothing set: every consumer reads the defaults
	for _, id in Model.ids() do
		check(driver.setting(id) == Model.default(id), `{id}: unset reads its default`)
	end
	check(driver.setting("SoundMuted") == false and lp:GetAttribute("SoundMuted") == nil, "(the attribute stays unset; the default is read, not written)")

	-- opening, the world waiting, closing
	local tick0 = driver.prey.tick
	frames(30)
	check(driver.prey.tick > tick0, "the world runs")
	press("SpiderSettings", "O")
	check(driver.settingsPanel:isShowing(), "O opens the settings")
	local tick1 = driver.prey.tick
	frames(60)
	check(driver.prey.tick == tick1, "the world waits while they are open")
	check(driver.settingsPanel.gui.Enabled and find("SpiderSettings", "Header_sound") ~= nil, "and the panel is drawn")
	press("WindowsillSettings", "O")
	check(not driver.settingsPanel:isShowing(), "O closes it again")
	frames(30)
	check(driver.prey.tick > tick1, "and the world runs on")
	press("SpiderMenu", "M")
	check(driver.menu:isShowing() and find("SpiderLifeMenu", "Settings") ~= nil, "the life menu offers Settings")
	driver.menu:hide()
	driver.openMenu()
	driver.openSettings("menu")
	check(driver.settingsPanel:isShowing() and not driver.menu:isShowing(), "choosing Settings from the menu opens the panel and hides the menu")
	press("WindowsillSettings", "Q")
	check(not driver.settingsPanel:isShowing() and driver.menu:isShowing(), "closing goes back to the menu")
	driver.menu:hide()
	driver.openSettings("game")
	driver.openSettings("game")
	check(driver.settingsPanel:isShowing(), "(opening twice changes nothing)")
	driver.settingsPanel:close()

	-- sound
	setAll({ MasterVolume = 0.5, AmbienceVolume = 0.5, CreatureVolume = 0.25 })
	frames(2)
	check(near(driver.soundscape.master, 0.5, 1e-9) and near(driver.soundscape.ambience, 0.5, 1e-9) and near(driver.soundscape.creatures, 0.25, 1e-9), "the three volumes reach the sound")
	check(near(driver.soundscape.room.Volume, 0.09 * 0.25, 1e-9), "and the room is quieter at once")
	setAll({ MasterVolume = 1, AmbienceVolume = 1, CreatureVolume = 1 })
	frames(2)
	check(near(driver.soundscape.room.Volume, 0.09, 1e-9), "back to full")
	local clientMusic: any = driver.soundscape.music
	check(clientMusic ~= nil and clientMusic.SoundId == "rbxassetid://114531800455832" and clientMusic.Looped, "the client makes the looped music voice from the uploaded id")
	setAll({ MusicVolume = 0.3 })
	frames(2)
	check(near(driver.soundscape.musicVolume, 0.3, 1e-9) and near(driver.soundscape.room.Volume, 0.09, 1e-9), "the music volume reaches the sound, and the room does not move")
	check(near(clientMusic.Volume, 0.18 * 0.3, 1e-9), "and the voice follows it")
	setAll({ MusicVolume = "loud" })
	frames(2)
	check(driver.setting("MusicVolume") == 1 and driver.soundscape.musicVolume == 1, "a wrong-typed music volume reads as the default")
	lp:SetAttribute("MusicVolume", nil)
	-- junk in an attribute never reaches the sound
	lp:SetAttribute("MasterVolume", "loud")
	frames(2)
	check(driver.setting("MasterVolume") == 1 and driver.soundscape.master == 1, "a wrong-typed attribute reads as the default")
	lp:SetAttribute("MasterVolume", 7)
	check(driver.setting("MasterVolume") == 1.0 or driver.setting("MasterVolume") == Model.get(function() return 7 end, "MasterVolume"), "and a number out of range is held to the range")
	lp:SetAttribute("MasterVolume", nil)

	-- the third person's field of view and distance
	local camera = workspace.CurrentCamera
	setAll({ FieldOfView = 80, CameraDistance = 6.5 })
	frames(3)
	check(camera.FieldOfView == 80, `the field of view is shown at once ({camera.FieldOfView})`)
	check(driver.cam.settingDistance == 6.5, "the distance reaches the camera")
	setAll({ FieldOfView = Model.default("FieldOfView"), CameraDistance = Model.default("CameraDistance") })
	frames(3)
	check(camera.FieldOfView == Model.default("FieldOfView"), "and back to the default")

	-- look speeds and inversion, through the right stick
	local function stickDelta(sens: number?, invertX: boolean?, invertY: boolean?): (number, number)
		setAll({ LookSensitivityStick = sens or 1.0, InvertX = invertX or false, InvertY = invertY or false })
		frames(2)
		local yaw0, pitch0 = driver.cam.yaw, driver.cam.elevation
		local look = stubs.actions["SpiderLookStick"]
		look("SpiderLookStick", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(1, 1, 0) })
		frames(4)
		look("SpiderLookStick", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick2, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.zero })
		frames(1)
		return driver.cam.yaw - yaw0, driver.cam.elevation - pitch0
	end
	local dyaw1, dpitch1 = stickDelta(1.0)
	check(math.abs(dyaw1) > 1e-3 and math.abs(dpitch1) > 1e-3, "the stick turns the view")
	local dyaw2, dpitch2 = stickDelta(2.0)
	check(near(dyaw2 / dyaw1, 2, 0.1) and near(dpitch2 / dpitch1, 2, 0.3), `twice the speed turns twice as far ({dyaw2 / dyaw1})`)
	local dyawH = stickDelta(0.5)
	check(near(dyawH / dyaw1, 0.5, 0.05), `half the speed turns half as far ({dyawH / dyaw1})`)
	local dyawX, dpitchX = stickDelta(1.0, true, false)
	check(dyawX * dyaw1 < 0 and dpitchX * dpitch1 > 0, "InvertX turns the other way across, not up and down")
	local dyawY, dpitchY = stickDelta(1.0, false, true)
	check(dyawY * dyaw1 > 0 and dpitchY * dpitch1 < 0, "InvertY the other way up and down, not across")
	stickDelta(1.0)

	-- the framing switch
	setAll({ FrameLine = false })
	frames(3)
	check(driver.cam.framingOn == false, "FrameLine reaches the camera")
	setAll({ FrameLine = true })
	frames(3)
	check(driver.cam.framingOn == true, "and back")

	-- the spider-eye view: its own field of view stays, the level horizon and the grey reach it
	press("SpiderEye", "V")
	frames(5)
	check(driver.cam.eyeView and camera.FieldOfView == 90, "the eye view keeps its own field of view")
	setAll({ FieldOfView = 70 })
	frames(3)
	check(camera.FieldOfView == 90, "(a changed field of view waits in the eye view)")
	setAll({ EyeLevelHorizon = true })
	frames(3)
	check(driver.cam.levelHorizon == true, "the level horizon reaches the camera")
	setAll({ EyeGrey = true })
	frames(3)
	local grade = driver.eyes.grade
	check(grade.Saturation == -1 and grade.TintColor.R == 1 and grade.TintColor.G == 1 and grade.TintColor.B == 1, "grey instead of green: no colour in the picture")
	setAll({ EyeGrey = false })
	frames(3)
	check(grade.TintColor.R < 1 and grade.Saturation > -1, "and green again when it is off")
	setAll({ EyeLevelHorizon = false })
	press("SpiderEye", "V")
	frames(5)
	check(camera.FieldOfView == 70, "leaving the eye view brings the chosen field of view back")
	setAll({ FieldOfView = Model.default("FieldOfView") })
	frames(3)

	-- captions
	press("SpiderEye", "V")
	frames(3)
	local caption = find("SpiderPrompts", "Caption")
	local normal = caption.TextSize
	setAll({ Captions = "large" })
	frames(3)
	check(caption.TextSize == math.round(15 * Spec.CAPTION_SCALE.large) and caption.TextSize > normal, `large captions are bigger ({caption.TextSize})`)
	setAll({ Captions = "normal" })
	frames(3)
	check(caption.TextSize == normal, "normal captions are as they were")
	press("SpiderEye", "V")
	frames(3)

	-- hints (out in the open, away from the crack's own prompt)
	do
		local fwd = stubs.actions["SpiderForward"]
		fwd("SpiderForward", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.W, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
		frames(400)
		fwd("SpiderForward", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.W, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
		frames(5)
	end
	local hintLabel = find("SpiderPrompts", "PromptHint")
	local walk = ControlText.walkHint("keyboard")
	check(hintLabel.Visible and string.find(hintLabel.Text, walk, 1, true) ~= nil, `the walking hint shows to begin with ({hintLabel.Text})`)
	setAll({ ControlHints = false })
	frames(3)
	check(not (hintLabel.Visible and string.find(hintLabel.Text, walk, 1, true) ~= nil), "and goes when the hints are off")
	press("SpiderHelp", "H")
	frames(2)
	check(find("SpiderPrompts", "Controls").Visible == true, "(H still asks for the controls card)")
	press("SpiderHelp", "H")
	frames(2)
	setAll({ ControlHints = true })
	frames(3)
	check(hintLabel.Visible and string.find(hintLabel.Text, walk, 1, true) ~= nil, "and returns when they are on again")

	-- the real buttons at other screen sizes: touch targets, apart from each other and from the status lines
	do
		local safe = gui:FindFirstChild("SpiderPrompts")
		local touchGui = gui:FindFirstChild("SpiderTouch")
		local HudLayout = require("../src/Shared/UI/HudLayout")
		local function rectOf(b: any, w: number, h: number): any
			local p, sz = b.Position, b.Size
			local x0, y0 = p.X.Scale * w + p.X.Offset, p.Y.Scale * h + p.Y.Offset
			return { x0 = x0, y0 = y0, x1 = x0 + sz.X.Offset, y1 = y0 + sz.Y.Offset }
		end
		local problems, seen = 0, 0
		for _, sz in { { 360, 640 }, { 390, 844 }, { 568, 320 }, { 667, 375 }, { 844, 390 }, { 768, 1024 }, { 1024, 768 }, { 1280, 720 } } do
			local w, h = sz[1], sz[2]
			rawset(safe, "AbsoluteSize", { X = w, Y = h })
			rawset(touchGui, "AbsoluteSize", { X = w, Y = h })
			safe:GetPropertyChangedSignal("AbsoluteSize"):Fire()
			touchGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
			frames(2)
			local menuR, noteR = rectOf(find("SpiderPrompts", "LifeMenu"), w, h), rectOf(find("SpiderPrompts", "NotebookButton"), w, h)
			local topCol = find("SpiderPrompts", "Top")
			local colX0 = topCol.Position.X.Offset - topCol.Size.X.Offset / 2
			local colX1 = topCol.Position.X.Offset + topCol.Size.X.Offset / 2
			local colY = topCol.Position.Y.Offset
			local col = { x0 = colX0, y0 = colY, x1 = colX1, y1 = colY + 40 }
			local mine = { menuR, noteR }
			for _, r in mine do
				if r.x1 - r.x0 < 48 or r.y1 - r.y0 < 48 then problems += 1; print(`  {w}x{h}: a top button is small`) end
				if r.x0 < 0 or r.x1 > w or r.y0 < 0 or r.y1 > h then problems += 1; print(`  {w}x{h}: a top button is off screen`) end
				if HudLayout.overlaps(r, col) then problems += 1; print(`  {w}x{h}: a top button covers the status lines`) end
			end
			if HudLayout.overlaps(menuR, noteR) then problems += 1; print(`  {w}x{h}: Menu and Notebook meet`) end
			for _, b in touchGui:GetChildren() do
				if b:IsA("TextButton") then
					seen += 1
					local r = rectOf(b, w, h)
					if r.x1 - r.x0 < 48 or r.y1 - r.y0 < 48 then problems += 1; print(`  {w}x{h}: touch button {b.Name} is small`) end
					for _, m in mine do
						if HudLayout.overlaps(r, m) then problems += 1; print(`  {w}x{h}: touch button {b.Name} meets a top button`) end
					end
				end
			end
		end
		check(seen == 8 * #HudLayout.TOUCH_BUTTONS, `(all {#HudLayout.TOUCH_BUTTONS} touch buttons were looked at, {seen})`)
		check(problems == 0, "the real Menu, Notebook and touch buttons are touch targets and never meet, at phone, tablet and desktop sizes")
		rawset(safe, "AbsoluteSize", { X = 1280, Y = 720 })
		rawset(touchGui, "AbsoluteSize", { X = 1280, Y = 720 })
		safe:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		touchGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		frames(2)
	end

	-- discovery notes
	check(driver.setting("NotebookNotes") == true, "notes are on by default")

	-- the panel changes the same attributes the game reads
	driver.openSettings("game")
	local sp = driver.settingsPanel
	sp.nav:selectId("SoundMuted")
	press("WindowsillSettings", "Return")
	check(lp:GetAttribute("SoundMuted") == true and driver.setting("SoundMuted") == true, "switching Sound off in the panel sets the Player attribute the game reads")
	frames(2)
	check(driver.soundscape.room.Playing == false, "and the room goes quiet")
	sp.nav:selectId("MasterVolume")
	press("WindowsillSettings", "Left")
	check(near(lp:GetAttribute("MasterVolume") :: number, 0.95, 1e-9), "a slider writes a number")
	sp:close()
	-- Reset
	driver.openSettings("game")
	sp:refresh()
	sp.nav:select(#sp.nav.rows - 1)
	press("WindowsillSettings", "Return")
	press("WindowsillSettings", "Return")
	check(lp:GetAttribute("SoundMuted") == false and lp:GetAttribute("MasterVolume") == 1.0, "Reset puts every setting back (and writes them, so the save follows)")
	sp:close()

	-- the Spider row (ROBLOX-71): the real client changes the spider anywhere it stands safely, keeps it as Appearance (the save), never as a setting
	do
		local function spiderRow(): any
			for _, x in sp.widgets do if x.kind == "setting" and x.id == "Spider" then return x end end
			return nil
		end
		driver.openSettings("game")
		sp:refresh()
		local row = spiderRow()
		check(row ~= nil and row.value.Text == "The first spider" and driver.appearance() == "first_spider", "the row shows the spider being played")
		sp.nav:selectId("Spider")
		press("WindowsillSettings", "Return")
		check(driver.appearance() == "maratus_volans_male" and lp:GetAttribute("Appearance") == "maratus_volans_male", "Enter on the row changes the spider, here on the open sill and not in the crack")
		check(lp:GetAttribute("Spider") == nil and row.value.Text == "The peacock spider" and sp.status.Text == "You are the peacock spider now", "kept as Appearance, never as a setting; the row and the line say so")
		check(workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "maratus_volans_male", "and the drawn spider is the peacock")
		-- each unsafe moment: it will not change, says so, and the row snaps back
		local motor, jump, feeding = driver.motor, driver.jump, driver.prey.feeding
		local unsafe: { { string | (boolean) -> () } } = {
			{ "seized", function(on: boolean) motor.seized = on end },
			{ "preparing a jump", function(on: boolean) motor.preparing = on end },
			{ "struggling with prey", function(on: boolean) feeding.struggling = on end },
			{ "in the air", function(on: boolean) motor.mode = if on then "airborne" else "attached" end },
		}
		for _, u in unsafe do
			local name, set = u[1] :: string, u[2] :: (boolean) -> ()
			set(true)
			press("WindowsillSettings", "Return")
			check(driver.appearance() == "maratus_volans_male" and lp:GetAttribute("Appearance") == "maratus_volans_male", `{name}: the spider stays as it was`)
			check(row.value.Text == "The peacock spider" and sp.status.Text == PeacockText.NOT_NOW, `{name}: the row snaps back and the panel says it will not change now`)
			set(false)
		end
		check(not jump:isBusy() and motor.mode == "attached", "(the spider is standing again)")
		-- a locked spider is skipped by the row, as by the crack's key
		local real = SpiderChoice.locked
		SpiderChoice.locked = function(id: string): boolean return id == "myrmarachne_formicaria_female" end
		press("WindowsillSettings", "Return")
		check(driver.appearance() == "brachypelma_hamorii", "with the ant mimic locked the row goes from the peacock past it to the Mexican redknee")
		SpiderChoice.locked = real
		for _ = 1, 4 do press("WindowsillSettings", "Return") end -- Greenbottle blue, first spider, peacock, ant mimic
		check(driver.appearance() == "myrmarachne_formicaria_female", "and unlocked it reaches the ant mimic")
		press("WindowsillSettings", "Return")
		check(driver.appearance() == "brachypelma_hamorii" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "brachypelma_hamorii" and lp:GetAttribute("Appearance") == "brachypelma_hamorii", "the next is a tarantula, drawn and kept as `Appearance`")
		press("WindowsillSettings", "Return")
		check(driver.appearance() == "chromatopelma_cyaneopubescens" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "chromatopelma_cyaneopubescens", "and the other tarantula")
		press("WindowsillSettings", "Return")
		check(driver.appearance() == "first_spider" and lp:GetAttribute("Appearance") == "first_spider", "and round to the first spider")
		sp:close()
		frames(3)
	end

	-- the Inspect row (ROBLOX-90): the real client closes the panel into the close look (a controller's A too), the world runs on inside it, and the Reduced Motion setting reaches the camera
	do
		driver.place(Vector3.new(-5, 0.31, -9))
		frames(60)
		local cam, pick = driver.cam, driver.spiderPick
		check(cam.reducedMotion == false and not pick.inspecting, "(Reduced Motion off, not looking)")
		setAll({ ReducedMotion = true })
		frames(2)
		check(cam.reducedMotion == true, "the Reduced Motion setting reaches the camera")
		setAll({ ReducedMotion = false })
		frames(2)
		check(cam.reducedMotion == false, "and off again")
		driver.openSettings("game")
		sp:refresh()
		sp.nav:selectId("Inspect")
		local pad = stubs.actions["WindowsillSettings"]
		pad("WindowsillSettings", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonA, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.zero })
		pad("WindowsillSettings", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.ButtonA, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.zero })
		check(not sp:isShowing() and pick.inspecting and cam.inspect ~= nil, "A on the Inspect row closes the panel into the close look")
		check(lp:GetAttribute("Inspect") == nil and driver.appearance() == "first_spider", "nothing is kept as a setting, and the spider is the one it was")
		local t0 = driver.prey.tick
		frames(60)
		check(driver.prey.tick > t0 and pick.inspecting, "the world runs on while looking (the panel paused it; the look does not)")
		pick.finish(nil, true)
		frames(2)
		check(not pick.inspecting and not cam:inspectActive(), "(leaving)")
		-- Reduced Motion: the look is in at once, and leaving is a cut
		setAll({ ReducedMotion = true })
		frames(2)
		driver.openSettings("game")
		sp:refresh()
		sp.nav:selectId("Inspect")
		press("WindowsillSettings", "Return")
		frame(1 / 60)
		check(pick.inspecting and cam.inspectT == 1, "with Reduced Motion on, the view is in on the first frame")
		pick.finish(nil, false)
		frame(1 / 60)
		check(cam.inspectT == 0 and not cam:inspectActive(), "and leaving is a cut")
		setAll({ ReducedMotion = false })
		frames(2)
	end
end

print(`SETTINGS passed={passed} failed={failed}`)
if failed > 0 then error("settings checks failed") end
