-- Settings checks (ROBLOX-49): the table (Data/SettingsSpec) and the model (UI/SettingsModel). Pure Luau. The saving, the panel, the live
-- wiring and the touch layout are checked below in the same suite as they are built (see the section headings).
local Spec = require("../src/Shared/Data/SettingsSpec")
local Model = require("../src/Shared/UI/SettingsModel")

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
check(#Spec.SECTIONS == 4 and Spec.SECTIONS[1].id == "sound" and Spec.SECTIONS[2].id == "camera" and Spec.SECTIONS[3].id == "comfort" and Spec.SECTIONS[4].id == "help",
	"four sections in order: Sound, Camera, Comfort and accessibility, Help and hints")
check(Spec.SECTIONS[3].title == "Comfort and accessibility" and Spec.SECTIONS[4].title == "Help and hints", "the section titles")

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
check(#Spec.LIST == 22, `22 settings in the table (found {#Spec.LIST})`)
check(perSection.sound == 5 and perSection.camera == 8 and perSection.comfort == 7 and perSection.help == 2, "5 sound, 8 camera, 7 comfort, 2 help")
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
check(nSections == 4 and nItems == #Spec.LIST, "sections() holds every setting once")

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

print(`SETTINGS passed={passed} failed={failed}`)
if failed > 0 then error("settings checks failed") end
