--!strict
-- Words on the screen, written for the device the player is using now: keyboard and mouse, a controller, or touch.
-- The texts are the frozen Godot game's (scripts/presentation/jump_feedback.gd, key_names.gd and jump_hud.gd at c87ce00);
-- where Godot wrote both keys ("Q / B"), each device here names only its own key or button. Pure: tests/run.luau checks
-- every prompt without Roblox.
local ControlText = {}

export type Device = "keyboard" | "gamepad" | "touch"

ControlText.TITLES = {
	reachable = "Reachable",
	obstructed = "Blocked",
	unreachable = "Out of reach",
	ineligible = "Can't land there",
	none = "No surface in view",
}
ControlText.REASONS = {
	ok = "",
	no_target = "no surface in view",
	ineligible_surface = "the spider cannot hold on there",
	too_far = "too far or too high",
	no_launch = "no way to leave this surface toward there",
	no_arrival = "it can't land from that angle",
	no_durations = "out of range",
	no_room = "no room to land",
	path_blocked = "something is in the way",
	graze = "it would only graze the surface",
	hop_blocked = "something is in the way",
	no_ground = "nothing to land on ahead",
}
ControlText.ANCHOR_TEXT = {
	ok = "Safety line: anchored here",
	no_silk = "No safety line: this surface won't hold silk",
	too_long = "No safety line: this jump needs more line than you have",
	no_support = "",
}
ControlText.LINE_TITLE = "On your line"
ControlText.LINE_TITLE_REELING = "On your line: reeling in"
ControlText.LINE_BLOCKED = {
	blocked = "Can't reel in: something is in the way. Lower, or let go",
	shortest = "Reeled in as far as it goes",
	snagged = "The line is caught on a second edge and can't be reeled in. Lower, or let go",
}
ControlText.DROP_REFUSED = {
	no_edge = "Nothing below to let yourself down into from here",
	no_silk = "This surface won't hold your silk",
	no_support = "",
	stuck = "Couldn't get to the edge",
}
ControlText.DROP_WALK = "To the edge, to let yourself down"

-- What each device calls the controls. Godot's input_setup.gd bindings; the port keeps the D-pad for walking, so lowering on
-- silk is X on a controller (ROBLOX-05). Touch names are the on-screen buttons.
local NAMES: { [string]: { [string]: string } } = {
	keyboard = {
		feed = "E", jump = "Space", cancel = "Q", letGo = "Q", drop = "F", reel = "W", lower = "S", walk = "WASD", look = "Mouse",
		creep = "Shift", focus = "Right mouse", eye = "V", recenter = "R", lock = "R", slow = "T", reset = "Backspace", help = "H", zoom = "Wheel",
		choose = "C", display = "X", menu = "M", notebook = "N", settings = "O",
	},
	gamepad = {
		feed = "Left-stick click", jump = "A", cancel = "B", letGo = "B", drop = "X", reel = "Stick up", lower = "Stick down", walk = "Left stick",
		look = "Right stick", creep = "LB", focus = "LT", eye = "Y", recenter = "Right-stick click", lock = "Right-stick click", slow = "RT", reset = "View",
		help = "", zoom = "", choose = "RB", display = "RB", menu = "View", notebook = "View",
	},
	touch = {
		feed = "Eat", jump = "Jump", cancel = "Cancel", letGo = "Let go", drop = "Silk", reel = "↑", lower = "↓", walk = "Arrows",
		look = "Drag", creep = "Creep", focus = "Focus", eye = "Eye", recenter = "Recentre", lock = "Lock", slow = "", reset = "", help = "", zoom = "", choose = "Change", display = "Dance", menu = "Menu", notebook = "Notebook",
	},
}

-- A PlayStation controller has the same buttons under other names (Roblox reports "ButtonCross" for ButtonA there). The client
-- calls setPadStyle from UserInputService:GetStringForKeyCode(ButtonA) at start and after each controller input; names not listed
-- here (sticks) are the same on both.
local PLAYSTATION: { [string]: string } = {
	feed = "L3", jump = "Cross", cancel = "Circle", letGo = "Circle", drop = "Square", creep = "L1", focus = "L2", eye = "Triangle",
	recenter = "R3", lock = "R3", slow = "R2", reset = "Touchpad", choose = "R1", display = "R1", menu = "Touchpad", notebook = "Touchpad",
}
local padStyle = "xbox"

-- "xbox" or "playstation", from what Roblox calls ButtonA on this controller.
function ControlText.padStyleFor(buttonAString: string?): string
	return if buttonAString == "ButtonCross" then "playstation" else "xbox"
end

function ControlText.setPadStyle(style: string)
	padStyle = if style == "playstation" then "playstation" else "xbox"
end

function ControlText.padStyle(): string
	return padStyle
end

function ControlText.name(device: Device, action: string): string
	if device == "gamepad" and padStyle == "playstation" and PLAYSTATION[action] then
		return PLAYSTATION[action]
	end
	return (NAMES[device] or NAMES.keyboard)[action] or ""
end

-- The device whose names to show after an input of this UserInputType (its Enum name). Anything else keeps the previous one.
function ControlText.deviceFor(inputType: string, previous: Device): Device
	if inputType == "Touch" then return "touch" end
	if string.sub(inputType, 1, 7) == "Gamepad" then return "gamepad" end
	if inputType == "Keyboard" or inputType == "TextInput" or string.sub(inputType, 1, 5) == "Mouse" then return "keyboard" end
	return previous
end

-- Before any input: a touch-only device shows touch, a controller without a keyboard (a console) shows the controller.
function ControlText.initialDevice(touch: boolean, keyboard: boolean, gamepad: boolean): Device
	if touch and not keyboard then return "touch" end
	if gamepad and not keyboard then return "gamepad" end
	return "keyboard"
end

function ControlText.reason(plan: any): string
	if plan == nil then return "" end
	return ControlText.REASONS[plan.reason] or tostring(plan.reason or "")
end

-- The two lines at the reticle while aiming (JumpFeedback.describe, hold mode) and Godot's cancel hint beside the second.
function ControlText.describe(plan: any, device: Device): (string, string)
	local cancel = (if device == "gamepad" then "Left stick: aim    " else "") .. ControlText.name(device, "cancel") .. ": cancel the jump"
	if plan == nil then
		return ControlText.TITLES.none, "release to cancel    " .. cancel
	end
	local kind = plan.kind
	local valid = kind == "reachable"
	local title = ControlText.TITLES[kind] or kind
	if not valid and kind ~= "none" then
		local why = ControlText.reason(plan)
		if why ~= "" then title = title .. ": " .. why end
	end
	return title, (if valid then "release to leap" else "release to cancel") .. "    " .. cancel
end

function ControlText.anchorText(reason: string): string
	return ControlText.ANCHOR_TEXT[reason] or ""
end

-- The toast for a jump outcome (JumpFeedback.toast): "" for outcomes that need none.
function ControlText.toast(kind: string, plan: any): string
	local why = ControlText.reason(plan)
	if kind == "refused" then
		return "Jump cancelled: " .. (if why ~= "" then why else "nothing to land on")
	elseif kind == "hop_refused" then
		return "No hop: " .. (if why ~= "" then why else "nowhere to land")
	elseif kind == "cancelled" then
		return "Jump cancelled"
	elseif kind == "out_of_bounds" then
		return "Out of bounds: back to the last safe spot"
	end
	return ""
end

-- The toast for a line event (JumpFeedback.line_toast). afterMiss: the line had been locked by a miss; dropped: the spider
-- let itself down on this line (the line taking its weight is no surprise then).
function ControlText.lineToast(kind: string, detail: string, afterMiss: boolean, dropped: boolean, device: Device): string
	if kind == "caught" then
		return if dropped then "" else "Caught by your line"
	elseif kind == "drop_walk" then
		return ControlText.DROP_WALK
	elseif kind == "dropped" then
		return `Letting yourself down: hold {ControlText.name(device, "drop")} to lower, {ControlText.name(device, "reel")} to climb`
	elseif kind == "drop_refused" then
		return ControlText.DROP_REFUSED[detail] or ""
	elseif kind == "completed" then
		return if afterMiss then "Holding on again. The line stays behind for a moment" else ""
	elseif kind == "released" then
		return "You let go of the line"
	elseif kind == "lost" then
		return "Your line came loose: its anchor is gone"
	elseif kind == "blocked" then
		return ControlText.LINE_BLOCKED[detail] or ""
	elseif kind == "snagged" then
		return ControlText.LINE_BLOCKED.snagged
	end
	return ""
end

-- The panel at the bottom while on the line: its title, the line's own prompts (distinct from cancelling an aim) and a cue.
-- ctx: reeling, progress (0..1 of a deliberate let-go hold), snagged, block ("", "blocked", "shortest").
function ControlText.linePanel(ctx: any, device: Device): (string, string, string)
	local title = if ctx.reeling then ControlText.LINE_TITLE_REELING else ControlText.LINE_TITLE
	local hint = `{ControlText.name(device, "reel")}: reel in    {ControlText.name(device, "lower")}: lower    hold {ControlText.name(device, "letGo")}: let go`
	local cue = ""
	if (ctx.progress or 0) > 0 then
		cue = `Letting go... {math.floor(ctx.progress * 100 + 0.5)}%`
	elseif ctx.snagged then
		cue = ControlText.LINE_BLOCKED.snagged
	elseif ctx.block and ctx.block ~= "" then
		cue = ControlText.LINE_BLOCKED[ctx.block] or ""
	end
	return title, hint, cue
end

-- Walking (port-only reminder, shown small): how to jump and how to let down on silk.
function ControlText.walkHint(device: Device): string
	local j = ControlText.name(device, "jump")
	return `Tap {j}: hop    hold {j}: aim a leap    {ControlText.name(device, "drop")}: let yourself down on silk`
end

-- Walking to an edge to let down: what stops it.
function ControlText.edgeWalkHint(device: Device): string
	return `{ControlText.DROP_WALK}    {ControlText.name(device, "cancel")} or move: stop`
end

-- The touch Lock button's words (ROBLOX-110): Lock, or Unlock while a lock holds.
ControlText.LOCK_LABEL, ControlText.UNLOCK_LABEL = "Lock", "Unlock"
function ControlText.touchLockLabel(locked: boolean): string
	return if locked then ControlText.UNLOCK_LABEL else ControlText.LOCK_LABEL
end

-- The touch Cancel button's words: on the line it is the let-go button (held), elsewhere it cancels.
function ControlText.touchCancelLabel(onLine: boolean): string
	return if onLine then "Let go\n(hold)" else "Cancel"
end

-- The controls card (H): the device's own bindings, one group of actions to a line. The whole card the player reads is PeacockText.card (this, then the crack's line,
-- the pointer to the Settings row and the display key's line), and it is at most ten lines at the width the HUD gives it (tests/peacock.luau, the Studio PromptSpec);
-- each line here is at most 61 characters (the card's width at its text size) so that, on a keyboard or a controller, none wraps. The touch card has the room to wrap.
function ControlText.helpCard(device: Device): string
	if device == "gamepad" then
		local function n(action: string): string return ControlText.name("gamepad", action) end
		return table.concat({
			`Left stick walk   Right stick look   {n("creep")} creep   {n("slow")} slow-mo`,
			`Tap {n("jump")} hop   Hold {n("jump")} aim, release to leap   {n("focus")} focus`,
			`{n("drop")} lower on silk   {n("cancel")} cancel   {n("eye")} eye view`,
			`On the line: up reel, down lower, hold {n("letGo")} let go`,
			`{n("lock")}: lock on (stick circles it) or recentre`,
			`In the crack: {n("feed")} rest (sleep from evening)`,
			`{n("menu")}: menu, then last rest, notebook, settings`,
		}, "\n")
	elseif device == "touch" then
		return table.concat({
			"Arrows walk   Drag to look   Creep (hold)   Focus   Eye view",
			"Tap Jump hop   Hold Jump aim, release to leap   Cancel",
			"Silk: lower on a line   On it: ↑ reel, ↓ lower, hold Let go",
			"Lock follows what you see (← → circle it)   Recentre",
			"In the crack: Rest (Sleep from evening)",
			"Menu: last rest, notebook, settings, this card",
		}, "\n")
	end
	return table.concat({
		"WASD walk   Mouse look   Shift creep   Wheel zoom   G gait",
		"Tap Space hop   Hold Space aim, release to leap   Q cancel",
		"F lower on silk   On the line: W reel, S lower, hold Q let go",
		"V eye view   Right mouse focus   T slow motion   H: hide this",
		"R lock on or recentre   Locked: A/D circle, W/S close in",
		"In the crack: E rest (sleep from evening)",
		"Backspace: last rest   M: menu   N: notebook   O: settings",
	}, "\n")
end

return ControlText
