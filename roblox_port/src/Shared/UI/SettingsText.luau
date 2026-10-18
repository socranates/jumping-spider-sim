--!strict
-- The settings panel's words for the device in use, and its layout rules for the screen (ROBLOX-49): sizes by kind, how a row is laid out
-- (the label beside its control, or the control underneath on a narrow screen or with large text), and how much room the panel has.
-- Pure, so tests/settings.luau checks the layout at phone, tablet and desktop sizes without Roblox; Client/SettingsPanel only places what
-- this says. Button names come from ControlText (PlayStation names on a PlayStation controller).
local ControlText = require(script.Parent.ControlText)
local NotebookText = require(script.Parent.NotebookText)

local SettingsText = {}

-- Text sizes by kind at normal text; LARGE is the large-text option's factor (the same one the notebook and menus use).
SettingsText.SIZES = { heading = 26, section = 20, label = 18, value = 16, note = 14, controls = 14, button = 18 }
SettingsText.LARGE = NotebookText.LARGE
-- A button, a row and a bar's hit area are at least this tall at normal text (touch targets; scaled with the text).
SettingsText.MIN_TARGET = 44
-- The widest control cluster of each kind at normal text: a toggle's button; a choice's two arrows and its word; a slider's minus, bar,
-- number and plus.
SettingsText.CONTROL = { toggle = 96, choice = 240, slider = 360 } :: { [string]: number }
-- A label needs at least this much width beside its control; otherwise the control goes underneath.
SettingsText.MIN_LABEL = 170
SettingsText.PAD = 10
SettingsText.GAP = 6
SettingsText.VALUE_WIDTH = 104 -- a slider's number (e.g. "100%", "65 degrees")
SettingsText.SCROLLBAR = 8
SettingsText.MIN_BODY = 120
SettingsText.MAX_PANEL = { w = 900, h = 820 }
-- Holding Left or Right on a slider: the pause before it repeats and the seconds between repeats; the right stick's scroll speed in pixels a
-- second at full tilt; a key press that scrolls this many pixels.
SettingsText.REPEAT_DELAY = 0.4
SettingsText.REPEAT_RATE = 0.08
SettingsText.SCROLL_PX_S = 520
SettingsText.STEP_PX = 120

function SettingsText.scale(large: boolean): number
	return if large then SettingsText.LARGE else 1
end

-- The line under the list: what the controls do, on the device in use.
function SettingsText.controls(device: ControlText.Device): string
	if device == "gamepad" then
		local n = function(action: string): string return ControlText.name("gamepad", action) end
		return `Stick or D-pad: choose and change    {n("jump")}: switch    {n("creep")} and {n("choose")}: sections    {n("cancel")}: back`
	elseif device == "touch" then
		return "Tap a setting to switch it. Use - and + or drag a bar."
	end
	return `Up/Down: choose    Left/Right: change    Enter: switch    PageUp/PageDown: sections    {ControlText.name("keyboard", "settings")} or {ControlText.name("keyboard", "cancel")}: back`
end

-- How to open the settings, on the device in use.
function SettingsText.openHint(device: ControlText.Device): string
	if device == "gamepad" then
		return `{ControlText.name("gamepad", "menu")}, then Settings`
	elseif device == "touch" then
		return "Menu, then Settings"
	end
	return `{ControlText.name("keyboard", "settings")}, or {ControlText.name("keyboard", "menu")} then Settings`
end

export type Metrics = { paperW: number, paperH: number, head: number, hint: number, foot: number, body: number, bodyW: number }

-- Pixel sizes for a safe area of this size: the paper (97% by 95%, at most MAX_PANEL), the heading band, the controls line (two lines, three on a narrow phone; 0 when
-- the list would be left with less than MIN_BODY px), the footer's buttons and the height left for the list.
function SettingsText.metrics(width: number, height: number, scale: number): Metrics
	local paperW, paperH = math.min(width * 0.97, SettingsText.MAX_PANEL.w), math.min(height * 0.95, SettingsText.MAX_PANEL.h)
	local head = math.floor((SettingsText.SIZES.heading + 10) * scale)
	local foot = math.floor((SettingsText.MIN_TARGET + 8) * scale)
	local lines = if paperW < 500 then (if scale > 1 then 4 else 3) else 2 -- (a narrow phone wraps the line to a third row, or a fourth in large text)
	local hint = math.ceil(lines * SettingsText.SIZES.controls * scale * 1.25) + 4
	local body = paperH - 20 - head - foot - 12
	if body - hint >= SettingsText.MIN_BODY then body -= hint else hint = 0 end
	return { paperW = paperW, paperH = paperH, head = head, hint = hint, foot = foot, body = body, bodyW = paperW - 28 - SettingsText.SCROLLBAR }
end

export type RowLayout = { stacked: boolean, labelW: number, controlW: number, valueTop: boolean }

-- A row's layout for a list this wide: the label beside the control, or (a narrow screen, large text) the control underneath, full width.
-- A stacked slider keeps its number on the label's line (top right) so the bar has room between its - and +.
function SettingsText.controlWidth(kind: string, scale: number): number
	return math.floor(SettingsText.CONTROL[kind] * scale)
end
function SettingsText.rowLayout(bodyW: number, kind: string, scale: number): RowLayout
	local pad = SettingsText.PAD * scale
	local cw = SettingsText.controlWidth(kind, scale)
	local labelW = bodyW - cw - 3 * pad
	if labelW >= SettingsText.MIN_LABEL * scale then
		return { stacked = false, labelW = labelW, controlW = cw, valueTop = false }
	end
	local full = bodyW - 2 * pad
	if kind == "slider" then
		return { stacked = true, labelW = full - math.floor(SettingsText.VALUE_WIDTH * scale) - SettingsText.GAP * scale, controlW = full, valueTop = true }
	end
	return { stacked = true, labelW = full, controlW = math.min(full, math.max(cw, math.floor(bodyW * 0.7))), valueTop = false }
end

-- A row's height from its measured label and note heights (0 for no note).
function SettingsText.rowHeight(layout: RowLayout, labelH: number, noteH: number, scale: number): number
	local pad = SettingsText.PAD * scale
	local target = math.floor(SettingsText.MIN_TARGET * scale)
	local text = labelH + (if noteH > 0 then noteH + 2 else 0)
	if layout.stacked then
		return math.ceil(pad + math.max(text, if layout.valueTop then target * 0.6 else 0) + SettingsText.GAP * scale + target + pad)
	end
	return math.ceil(math.max(target + pad, text + 2 * pad))
end

-- The largest text size (at most `wanted`, at least 10) at which `word` fits a button `width` px wide and `height` tall: the word wraps, so
-- the lines it needs (an estimate a little wider than Gotham's real letters) must fit the height.
function SettingsText.buttonTextSize(word: string, width: number, height: number, wanted: number): number
	local size = wanted
	while size > 10 do
		local lines = math.ceil(#word * size * 0.58 / math.max(1, width - 10))
		if lines * size * 1.2 <= height then return size end
		size -= 1
	end
	return 10
end

return SettingsText
