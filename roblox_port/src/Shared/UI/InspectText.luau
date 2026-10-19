--!strict
-- The words of Inspect mode (ROBLOX-90): the Settings row's button (its label and note are in Data/SettingsSpec), the refusal, the name line on entering it, the name line and the controls line on screen, the toast for a
-- framing, what the touch buttons say, and the controls card's one line. Button names come from ControlText for the device in use (PlayStation
-- names on a PlayStation controller). Pure: checked in tests/inspect.luau.
local ControlText = require(script.Parent.ControlText)
local PeacockText = require(script.Parent.PeacockText)

local InspectText = {}

InspectText.BUTTON = "Look closely"
-- The touch buttons while looking: Cancel becomes Back, Eye becomes View (the framings).
InspectText.TOUCH_BACK = "Back"
InspectText.TOUCH_VIEW = "View"
InspectText.NOT_NOW = "You cannot look closely now. Stand safely on a surface first"
InspectText.DANGER = "The close look ends: something is coming"
InspectText.ENDED = "The close look ends"
InspectText.FRAMINGS = { face = "Face", side = "Side", top = "From above" } :: { [string]: string }

-- The name line on screen: the spider being looked at, with a capital.
function InspectText.nameLine(appearance: string): string
	return PeacockText.title(appearance)
end

-- The one line of controls on screen, for the device in use.
function InspectText.hint(device: ControlText.Device): string
	local n = function(action: string): string return ControlText.name(device, action) end
	if device == "gamepad" then
		return `{n("look")}: orbit    {n("walk")}: zoom    {n("eye")}: face, side, top    {n("cancel")} or {n("choose")}: back`
	elseif device == "touch" then
		return `{n("look")}: orbit    Pinch or {n("reel")} {n("lower")}: zoom    {InspectText.TOUCH_VIEW}: face, side, top    {InspectText.TOUCH_BACK}: leave`
	end
	return `{n("look")}: orbit    {n("zoom")} or {n("reel")} {n("lower")}: zoom    {n("eye")}: face, side, top    {n("cancel")} or {n("choose")}: back`
end

-- The toast when the framing changes.
function InspectText.framing(id: string): string
	return `Framing: {InspectText.FRAMINGS[id] or id}`
end

-- The crack's prompt, after the change-spider hint.
function InspectText.holdHint(device: ControlText.Device): string
	return `hold {ControlText.name(device, "choose")}: look closely`
end

-- The controls card's line.
function InspectText.helpLine(device: ControlText.Device): string
	local n = function(action: string): string return ControlText.name(device, action) end
	if device == "touch" then
		return "Look closely: Settings, or hold Change in the crack. Drag orbits, pinch or ↑ ↓ zoom, View frames, Back leaves"
	end
	return `Look closely at your spider: Settings, or hold {n("choose")} in the crack. {n("look")} orbits, {n("eye")} frames it, {n("cancel")} leaves`
end

return InspectText
