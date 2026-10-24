--!strict
-- Every setting the player can change (ROBLOX-49): its id, words, kind, default and range. One table, no logic: Shared/UI/SettingsModel
-- checks and steps the values, Client/SettingsPanel shows them, Shared/Persistence/SaveProgress keeps them, and each one is read live by
-- the part of the client it belongs to (tests/settings.luau lists who reads which).
--
-- An id is also the name of the Player attribute that holds the value at run time (the older toggles already were: FocusToggle, ReducedMotion,
-- ShowLastSeen, AutomaticGrip, NotebookNotes, LargeText, SoundMuted), so a setting nobody has changed is an attribute nobody has set.
--
-- Kinds: "toggle" (true or false), "slider" (a number from min to max in steps), "choice" (one of the listed options, by id), and, for a live row only,
-- "action" (a button that does something when it is switched: Inspect your spider, ROBLOX-90; it has no value).
-- The words follow the frozen Godot game's settings (scripts/presentation/settings.gd and pause_menu.gd) where a setting matches; the ones
-- Godot had that the port has no part for (stalk and jump-aim toggles, the jump arc, strike assist, headphones, rumble, slow-motion speed,
-- remapping keys) are left out on purpose and listed in docs/HANDOFF-roblox-settings.md.
local SettingsSpec = {}

-- The version of this table's meaning. Raise it when an id is renamed or a value changes its meaning, and add a step to
-- SettingsModel.MIGRATIONS (the saved settings are carried forward from the version they were written at).
SettingsSpec.VERSION = 1

export type Option = { id: string, label: string }
export type Setting = {
	id: string, section: string, label: string, kind: string, default: boolean | number | string,
	min: number?, max: number?, step: number?, unit: string?, options: { Option }?,
	note: string?, -- a short line under the setting
}

SettingsSpec.SECTIONS = {
	{ id = "sound", title = "Sound" },
	{ id = "camera", title = "Camera" },
	{ id = "comfort", title = "Comfort and accessibility" },
	{ id = "help", title = "Help and hints" },
	{ id = "spider", title = "Your spider" },
} :: { { id: string, title: string } }

-- Units name how a slider's number is shown (SettingsModel.valueText): percent of 1, a plain multiplier, degrees, studs.
SettingsSpec.LIST = {
	-- ---------------------------------------------------------------- sound (Client/Soundscape)
	{ id = "SoundMuted", section = "sound", label = "Mute all sound", kind = "toggle", default = false },
	{ id = "MasterVolume", section = "sound", label = "Volume", kind = "slider", default = 1.0, min = 0.0, max = 1.0, step = 0.05, unit = "percent" },
	{ id = "AmbienceVolume", section = "sound", label = "Room sounds and birds", kind = "slider", default = 1.0, min = 0.0, max = 1.0, step = 0.05, unit = "percent" },
	{ id = "CreatureVolume", section = "sound", label = "Flies and the wasp", kind = "slider", default = 1.0, min = 0.0, max = 1.0, step = 0.05, unit = "percent" },
	{ id = "MusicVolume", section = "sound", label = "Ambient music", kind = "slider", default = 1.0, min = 0.0, max = 1.0, step = 0.05, unit = "percent" },
	{ id = "Captions", section = "sound", label = "Captions for sounds and vibrations", kind = "choice", default = "normal",
		options = { { id = "off", label = "Off" }, { id = "normal", label = "Normal" }, { id = "large", label = "Large" } },
		note = "A line for the wasp's hum and the buzz felt through the feet, with its direction." },
	-- ---------------------------------------------------------------- camera (Client/SpiderCamera)
	{ id = "LookSensitivityMouse", section = "camera", label = "Mouse look speed", kind = "slider", default = 1.0, min = 0.2, max = 3.0, step = 0.05, unit = "times" },
	{ id = "LookSensitivityStick", section = "camera", label = "Stick look speed", kind = "slider", default = 1.0, min = 0.2, max = 3.0, step = 0.05, unit = "times" },
	{ id = "LookSensitivityTouch", section = "camera", label = "Touch drag look speed", kind = "slider", default = 1.0, min = 0.2, max = 3.0, step = 0.05, unit = "times" },
	{ id = "InvertY", section = "camera", label = "Invert look up and down", kind = "toggle", default = false },
	{ id = "InvertX", section = "camera", label = "Invert look left and right", kind = "toggle", default = false },
	{ id = "CameraDistance", section = "camera", label = "Camera distance", kind = "slider", default = 5.0, min = 4.0, max = 7.0, step = 0.1, unit = "studs" },
	{ id = "FieldOfView", section = "camera", label = "Field of view", kind = "slider", default = 65.0, min = 50.0, max = 90.0, step = 1.0, unit = "degrees",
		note = "The spider-eye view keeps its own." },
	{ id = "FrameLine", section = "camera", label = "Frame the line after a catch", kind = "toggle", default = true,
		note = "The view may turn to show the line while the spider hangs on it." },
	-- ---------------------------------------------------------------- comfort and accessibility
	{ id = "ReducedMotion", section = "comfort", label = "Reduced motion (a calmer spider body)", kind = "toggle", default = false },
	{ id = "HungerDisplay", section = "comfort", label = "Hunger display", kind = "choice", default = "veil",
		options = { { id = "veil", label = "Closing red edges" }, { id = "bar", label = "Small bar" } },
		note = "The red edges slowly draw inward as food runs low. Choose the bar for a clear screen." },
	{ id = "LargeText", section = "comfort", label = "Large text", kind = "toggle", default = false, note = "Menus, panels and the notebook." },
	{ id = "FocusToggle", section = "comfort", label = "Focus toggles (press to start and stop)", kind = "toggle", default = false },
	{ id = "AutomaticGrip", section = "comfort", label = "Hold prey and eat automatically", kind = "toggle", default = false,
  note = "Keeps your grip and takes bites without repeated taps. Moving still pauses eating." },
	{ id = "ShowNoticed", section = "comfort", label = "Show what the spider notices", kind = "toggle", default = true,
		note = "The rings, marks and words over what it sees. A lock (R or L1) still follows it." }, -- L1 locks on a controller
	{ id = "ShowLastSeen", section = "comfort", label = "Show the last-seen mark", kind = "toggle", default = true },
	{ id = "EyeLevelHorizon", section = "comfort", label = "Spider-eye view: level horizon (no roll on walls)", kind = "toggle", default = false },
	{ id = "EyeGrey", section = "comfort", label = "Spider-eye view: grey instead of green", kind = "toggle", default = false },
	-- ---------------------------------------------------------------- help and hints
	{ id = "ControlHints", section = "help", label = "Show control hints", kind = "toggle", default = true,
		note = "Feeding and dusk/rest prompts, every catch and night. Menu, Controls opens the full controls card." },
	{ id = "NotebookNotes", section = "help", label = "Say when a new notebook page opens", kind = "toggle", default = true },
} :: { Setting }

-- Rows that show and drive something the game already keeps elsewhere, so they are not saved settings (ROBLOX-71): no Player attribute of the
-- id, nothing in the save's settings, nothing in Reset to defaults. The spider is kept in the save as `appearance` (Player attribute
-- `Appearance`), and the client drives it through the panel's Io. `default` is only what an unknown reading says. The options and the words of
-- a live row come from the part that owns it (the Spider row's from Rig/SpiderChoice and UI/PeacockText, through SettingsModel), not from here.
SettingsSpec.LIVE = {
	{ id = "Spider", section = "spider", label = "Spider", kind = "choice", default = "first_spider",
		note = "Change it anywhere you stand safely. Not while jumping, on silk, moulting or holding prey." },
	-- ROBLOX-90: a button, not a value. It closes the panel into Inspect mode (a slow, close look at the spider), when the spider stands safely.
	{ id = "Inspect", section = "spider", label = "Inspect your spider", kind = "action", default = false,
		note = "A slow, close look from every side. Only while you stand safely. Cancel leaves." },
} :: { Setting }

-- How big the caption text is for each Captions option, as a multiple of the HUD's caption size (0: no captions of sounds at all).
SettingsSpec.CAPTION_SCALE = { off = 0, normal = 1, large = 1.5 } :: { [string]: number }

SettingsSpec.WORDS = {
	title = "Settings",
	reset = "Reset to defaults",
	resetSure = "Press again to reset",
	resetDone = "Settings are back to their defaults.",
	close = "Back",
	menuChoice = "Settings",
	on = "On",
	off = "Off",
	savedLine = "Your settings are kept with your saved game.",
	sessionLine = "Saving is off for this visit, so these settings last only until you leave.",
}

return SettingsSpec
